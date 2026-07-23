local _, ns = ...

ns = ns or {}
ns.Mail = ns.Mail or {}
local Mail = ns.Mail

local BulkHistoryRepository = {}
BulkHistoryRepository.__index = BulkHistoryRepository

local TERMINAL_BATCH = { COMPLETED = true, PARTIAL = true, STOPPED = true, INTERRUPTED = true }
local DISPATCHED_ITEM = { AWAITING_ACK = true, WAITING_SECURE_CONFIRM = true, SENDING = true }

local function newError(code, message, detail)
    if Mail.NewError then return Mail:NewError(code, message, detail) end
    return { code = code, message = message, detail = detail }
end

local function clone(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = clone(item) end
    return result
end

local function limited(value, maximum)
    value = type(value) == "string" and value or ""
    local index, characters = 1, 0
    while index <= #value and characters < maximum do
        local byte = string.byte(value, index)
        index = index + (byte < 0x80 and 1 or byte < 0xE0 and 2 or byte < 0xF0 and 3 or 4)
        characters = characters + 1
    end
    return string.sub(value, 1, index - 1)
end

local function sanitizeItem(item)
    return {
        itemId = tostring(item.itemId or item.recipientKey or ""),
        recipientKey = tostring(item.recipientKey or ""),
        displayName = limited(item.displayName or item.sendName, 96),
        sendName = limited(item.sendName, 128),
        state = item.state or "PENDING",
        attemptCount = math.max(0, math.floor(tonumber(item.attemptCount) or 0)),
        amount = math.max(0, math.floor(tonumber(item.amount) or 0)),
        postage = item.postage and math.max(0, math.floor(tonumber(item.postage) or 0)) or nil,
        startedAt = tonumber(item.startedAt),
        finishedAt = tonumber(item.finishedAt),
        errorCode = item.errorCode and limited(item.errorCode, 64) or nil,
        errorMessage = item.errorMessage and limited(item.errorMessage, 160) or nil,
    }
end

local function countStates(record)
    local success, failed, unknown, cancelled = 0, 0, 0, 0
    for index = 1, #(record.recipients or {}) do
        local state = record.recipients[index].state
        if state == "SUCCEEDED" then success = success + 1
        elseif state == "FAILED" then failed = failed + 1
        elseif state == "UNKNOWN" then unknown = unknown + 1
        elseif state == "CANCELLED" or state == "SKIPPED" then cancelled = cancelled + 1 end
    end
    record.selectedCount = #(record.recipients or {})
    record.successCount = success
    record.failedCount = failed
    record.unknownCount = unknown
    record.cancelledCount = cancelled
end

local function sanitizeRecord(record)
    local result = {
        schemaVersion = tonumber(record.schemaVersion) or 2,
        id = tostring(record.id or ""),
        retryOf = record.retryOf and tostring(record.retryOf) or nil,
        retryRootId = record.retryRootId and tostring(record.retryRootId) or nil,
        senderKey = tostring(record.senderKey or ""),
        realmFactionKey = tostring(record.realmFactionKey or ""),
        sourceKind = tostring(record.sourceKind or ""),
        sourceGroupId = record.sourceGroupId and tostring(record.sourceGroupId) or nil,
        startedAt = tonumber(record.startedAt) or 0,
        finishedAt = tonumber(record.finishedAt),
        state = record.state or "DRAFT",
        amountEach = math.max(0, math.floor(tonumber(record.amountEach) or 0)),
        postageEstimate = math.max(0, math.floor(tonumber(record.postageEstimate) or 0)),
        subject = limited(record.subject, 64),
        recipients = {},
    }
    for index = 1, #(record.recipients or {}) do result.recipients[index] = sanitizeItem(record.recipients[index]) end
    countStates(result)
    return result
end

function BulkHistoryRepository.New(deps)
    deps = deps or {}
    local storage = deps.storage or {}
    storage.order = type(storage.order) == "table" and storage.order or {}
    storage.byId = type(storage.byId) == "table" and storage.byId or {}
    return setmetatable({
        storage = storage,
        now = deps.now or _G.time or os.time,
        maxBatches = tonumber(deps.maxBatches) or 50,
        maxRecipientEntries = tonumber(deps.maxRecipientEntries) or 5000,
        maxAgeSeconds = (tonumber(deps.maxAgeDays) or 90) * 86400,
    }, BulkHistoryRepository)
end

function BulkHistoryRepository:_sort()
    table.sort(self.storage.order, function(leftId, rightId)
        local left, right = self.storage.byId[leftId], self.storage.byId[rightId]
        return (left and left.startedAt or 0) > (right and right.startedAt or 0)
    end)
end

function BulkHistoryRepository:_remove(batchId)
    self.storage.byId[batchId] = nil
    for index = #self.storage.order, 1, -1 do
        if self.storage.order[index] == batchId then table.remove(self.storage.order, index) end
    end
end

function BulkHistoryRepository:Create(record)
    local sanitized = sanitizeRecord(record or {})
    if sanitized.id == "" then return nil, newError("INVALID_BATCH_ID", "批次 ID 不能为空") end
    if self.storage.byId[sanitized.id] then return nil, newError("DUPLICATE_BATCH_ID", "批次 ID 已存在") end
    self.storage.byId[sanitized.id] = sanitized
    self.storage.order[#self.storage.order + 1] = sanitized.id
    self:_sort()
    self:Prune()
    return true
end

function BulkHistoryRepository:UpdateItem(batchId, itemId, patch)
    local record = self.storage.byId[batchId]
    if not record then return nil, newError("BATCH_NOT_FOUND", "找不到批量邮寄记录") end
    local item
    for index = 1, #record.recipients do
        if record.recipients[index].itemId == itemId then item = record.recipients[index] break end
    end
    if not item then return nil, newError("BATCH_ITEM_NOT_FOUND", "找不到批量邮寄收件人记录") end
    local allowed = {
        state = true, attemptCount = true, postage = true, startedAt = true, finishedAt = true,
        errorCode = true, errorMessage = true,
    }
    for key, value in pairs(patch or {}) do if allowed[key] then item[key] = value end end
    item.errorCode = item.errorCode and limited(item.errorCode, 64) or nil
    item.errorMessage = item.errorMessage and limited(item.errorMessage, 160) or nil
    countStates(record)
    return true
end

function BulkHistoryRepository:Finalize(batchId, state)
    local record = self.storage.byId[batchId]
    if not record then return nil, newError("BATCH_NOT_FOUND", "找不到批量邮寄记录") end
    record.state = state
    record.finishedAt = self.now()
    countStates(record)
    self:Prune()
    return true
end

function BulkHistoryRepository:Get(batchId)
    return self.storage.byId[batchId] and clone(self.storage.byId[batchId]) or nil
end

function BulkHistoryRepository:List(offset, limit)
    offset = math.max(0, math.floor(tonumber(offset) or 0))
    limit = math.max(0, math.floor(tonumber(limit) or #self.storage.order))
    local result = {}
    for index = offset + 1, math.min(#self.storage.order, offset + limit) do
        local record = self.storage.byId[self.storage.order[index]]
        if record then result[#result + 1] = clone(record) end
    end
    return result
end

function BulkHistoryRepository:GetRetryRecords()
    local storage = self.storage
    if type(storage) ~= "table" or type(storage.order) ~= "table"
        or type(storage.byId) ~= "table" then
        return nil, newError("HISTORY_CORRUPT", "批量历史索引结构损坏")
    end
    local result, seen = {}, {}
    for index = 1, #storage.order do
        local id = storage.order[index]
        local record = type(id) == "string" and storage.byId[id] or nil
        if id == "" or seen[id] or type(record) ~= "table" or record.id ~= id then
            return nil, newError("HISTORY_CORRUPT", "批量历史索引与记录不一致", { index = index })
        end
        seen[id] = true
        result[#result + 1] = clone(record)
    end
    for id, record in pairs(storage.byId) do
        if type(id) ~= "string" or type(record) ~= "table" or not seen[id] then
            return nil, newError("HISTORY_CORRUPT", "批量历史包含未索引记录")
        end
    end
    return result
end

function BulkHistoryRepository:Prune()
    local current = self.now()
    for index = #self.storage.order, 1, -1 do
        local id = self.storage.order[index]
        local record = self.storage.byId[id]
        local timestamp = record and (record.finishedAt or record.startedAt) or 0
        if record and TERMINAL_BATCH[record.state] and current - timestamp > self.maxAgeSeconds then self:_remove(id) end
    end

    while true do
        local totalItems = 0
        for _, id in ipairs(self.storage.order) do
            local record = self.storage.byId[id]
            totalItems = totalItems + (record and #record.recipients or 0)
        end
        if #self.storage.order <= self.maxBatches and totalItems <= self.maxRecipientEntries then break end
        local removable
        for index = #self.storage.order, 1, -1 do
            local record = self.storage.byId[self.storage.order[index]]
            if record and TERMINAL_BATCH[record.state] then removable = record.id break end
        end
        if not removable then break end
        self:_remove(removable)
    end
    self:_sort()
end

function BulkHistoryRepository:RecoverInterrupted()
    local recovered = 0
    for _, id in ipairs(self.storage.order) do
        local record = self.storage.byId[id]
        if record and (record.state == "RUNNING" or record.state == "PAUSED" or record.state == "DRAFT") then
            for index = 1, #record.recipients do
                local item = record.recipients[index]
                if not (item.state == "SUCCEEDED" or item.state == "FAILED" or item.state == "UNKNOWN"
                    or item.state == "CANCELLED" or item.state == "SKIPPED") then
                    if DISPATCHED_ITEM[item.state] then
                        item.state = "UNKNOWN"
                        item.errorCode = "INTERRUPTED_UNKNOWN"
                        item.errorMessage = "上次登录结束前未收到明确发送结果"
                    else
                        item.state = "CANCELLED"
                        item.errorCode = "SESSION_INTERRUPTED"
                        item.errorMessage = "上次登录结束时尚未提交"
                    end
                    item.finishedAt = self.now()
                end
            end
            record.state = "INTERRUPTED"
            record.finishedAt = self.now()
            countStates(record)
            recovered = recovered + 1
        end
    end
    self:Prune()
    return recovered
end

Mail.BulkHistoryRepository = BulkHistoryRepository
