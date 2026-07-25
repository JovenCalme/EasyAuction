local _, ns = ...

ns = ns or {}
ns.Mail = ns.Mail or {}
local Mail = ns.Mail

local AttachmentService = {}
AttachmentService.__index = AttachmentService

local TERMINAL = { SUCCEEDED = true, FAILED = true, CANCELLED = true, INDETERMINATE = true }

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

local function attachmentsOf(snapshot)
    if type(snapshot) ~= "table" then return {} end
    return type(snapshot.attachments) == "table" and snapshot.attachments or snapshot
end

local function sameItem(left, right)
    local leftId = tonumber(left.itemID)
    local rightId = tonumber(right.itemID)
    if leftId and rightId then return leftId == rightId end
    local leftLink = left.itemLink or left.hyperlink
    local rightLink = right.itemLink or right.hyperlink
    return leftLink and rightLink and leftLink == rightLink
end

local function matchingCount(snapshot, expected)
    local count = 0
    local attachments = attachmentsOf(snapshot)
    for index = 1, #attachments do
        if sameItem(attachments[index], expected) then count = count + 1 end
    end
    return count
end

function AttachmentService.New(deps)
    deps = deps or {}
    return setmetatable({
        compat = deps.compat or {},
        arbiter = deps.arbiter,
        generation = deps.generation or function() return 0 end,
        idFactory = deps.idFactory,
        maxAttachments = tonumber(deps.maxAttachments or _G.ATTACHMENTS_MAX_SEND) or 12,
        timeout = tonumber(deps.timeoutSeconds or deps.timeout) or 5,
        ackDelay = tonumber(deps.ackDelaySeconds or deps.ackDelay) or 0.01,
        schedule = deps.schedule,
        onComplete = deps.onComplete,
        operations = {},
        active = nil,
        nextId = 0,
    }, AttachmentService)
end

function AttachmentService:_newId()
    if self.idFactory then return tostring(self.idFactory("attachment")) end
    self.nextId = self.nextId + 1
    return "attachment-operation-" .. self.nextId
end

function AttachmentService:_release(operation, outcome, err)
    if operation.lease and self.arbiter then self.arbiter:Release(operation.lease, outcome, err) end
    operation.lease = nil
    if self.active == operation then self.active = nil end
end

function AttachmentService._cancelTimer(_, operation)
    if operation.timer and operation.timer.Cancel then operation.timer:Cancel() end
    if operation.ackTimer and operation.ackTimer.Cancel then operation.ackTimer:Cancel() end
    operation.timer = nil
    operation.ackTimer = nil
end

function AttachmentService:_scheduleTimeout(operation)
    if operation.timer and operation.timer.Cancel then operation.timer:Cancel() end
    operation.timer = nil
    local function timeout()
        if self.active ~= operation or operation.state ~= "AWAITING_ACK" then return end
        local snapshot = self.compat.GetOutgoingSnapshot and self.compat:GetOutgoingSnapshot() or nil
        if snapshot and matchingCount(snapshot, operation.current) > operation.beforeMatchCount then
            self:OnOutgoingSnapshot(snapshot)
            return
        end
        if self.compat.ClearCursor then self.compat:ClearCursor() end
        self:_finish(operation, "INDETERMINATE", newError(
            "RESULT_INDETERMINATE", "附件操作超时，无法确认物品是否进入邮件"))
    end
    if self.schedule then
        operation.timer = self.schedule(self.timeout, timeout)
    elseif _G.C_Timer and _G.C_Timer.NewTimer then
        operation.timer = _G.C_Timer.NewTimer(self.timeout, timeout)
    elseif _G.C_Timer and _G.C_Timer.After then
        _G.C_Timer.After(self.timeout, timeout)
    end
end

function AttachmentService:_scheduleAckProbe(operation)
    if operation.ackTimer and operation.ackTimer.Cancel then operation.ackTimer:Cancel() end
    operation.ackTimer = nil
    local function probe()
        operation.ackTimer = nil
        if self.active ~= operation or operation.state ~= "AWAITING_ACK" then return end
        local snapshot = self.compat.GetOutgoingSnapshot and self.compat:GetOutgoingSnapshot() or nil
        if snapshot then self:OnOutgoingSnapshot(snapshot) end
    end
    if self.schedule then
        operation.ackTimer = self.schedule(self.ackDelay, probe)
    elseif _G.C_Timer and _G.C_Timer.NewTimer then
        operation.ackTimer = _G.C_Timer.NewTimer(self.ackDelay, probe)
    elseif _G.C_Timer and _G.C_Timer.After then
        _G.C_Timer.After(self.ackDelay, probe)
    end
end

function AttachmentService:_finish(operation, state, err)
    self:_cancelTimer(operation)
    operation.state = state
    operation.error = err
    operation.finished = true
    self:_release(operation, state == "INDETERMINATE" and "INDETERMINATE" or state, err)
    if self.onComplete then pcall(self.onComplete, self:GetResult(operation.id)) end
    return state == "SUCCEEDED"
end

function AttachmentService:_fail(operation, code, message, detail)
    if self.compat.ClearCursor then self.compat:ClearCursor() end
    return self:_finish(operation, "FAILED", newError(code, message, detail))
end

function AttachmentService:_dispatchNext(operation)
    if operation.cancelRequested then return self:_finish(operation, "CANCELLED") end
    if operation.index > #operation.items then return self:_finish(operation, "SUCCEEDED") end
    local current = operation.items[operation.index]
    operation.current = current
    if current.locked then return self:_fail(operation, "ITEM_LOCKED", "物品格正在使用") end
    if current.bound then return self:_fail(operation, "ITEM_BOUND", "绑定物品不能邮寄") end
    if self.compat.IsCursorEmpty and not self.compat:IsCursorEmpty() then
        return self:_fail(operation, "CURSOR_BUSY", "鼠标指针上已有物品")
    end
    local before = self.compat.GetOutgoingSnapshot and self.compat:GetOutgoingSnapshot() or { attachments = {} }
    if #attachmentsOf(before) >= self.maxAttachments then
        return self:_fail(operation, "ATTACHMENTS_FULL", "邮件附件栏已满")
    end
    operation.beforeSnapshot = clone(before)
    operation.beforeMatchCount = matchingCount(before, current)
    operation.state = "ATTACHING"
    local ok, err = self.compat:AttachBagItem(current.bag, current.slot)
    if not ok then
        local code = type(err) == "table" and err.code or "ATTACH_API_REJECTED"
        local message = type(err) == "table" and err.message or "无法附加该物品"
        return self:_fail(operation, code, message, err)
    end
    operation.dispatched = true
    operation.state = "AWAITING_ACK"
    local after = self.compat.GetOutgoingSnapshot and self.compat:GetOutgoingSnapshot() or nil
    if after and self:OnOutgoingSnapshot(after) then return true end
    self:_scheduleAckProbe(operation)
    self:_scheduleTimeout(operation)
    return true
end

function AttachmentService:AttachMany(items, limit)
    if self.active then return nil, newError("ATTACHMENT_BUSY", "已有附件操作正在进行") end
    if type(items) ~= "table" or #items == 0 then return nil, newError("NO_ATTACHMENTS", "没有可附加物品") end
    limit = math.min(math.max(1, math.floor(tonumber(limit) or #items)), self.maxAttachments)
    local selected = {}
    for index = 1, math.min(#items, limit) do selected[index] = clone(items[index]) end
    local operation = {
        id = self:_newId(), state = "QUEUED", items = selected, index = 1,
        attachedCount = 0, dispatched = false, finished = false,
    }
    if self.arbiter then
        local lease, err = self.arbiter:Acquire("ATTACHMENT", operation.id, self.generation(), {
            onDrain = function(reason) self:Cancel(operation.id, reason) end,
            onDrainTimeout = function()
                if self.active == operation then
                    self:_finish(operation, "INDETERMINATE", newError(
                        "RESULT_INDETERMINATE", "关闭模块时无法确认附件结果"))
                end
            end,
        })
        if not lease then return nil, err or newError("OUTBOUND_BUSY", "邮箱写入通道正忙") end
        operation.lease = lease
    end
    self.operations[operation.id] = operation
    self.active = operation
    if operation.lease and self.arbiter.SetAttempt then
        self.arbiter:SetAttempt(operation.lease, { operationId = operation.id, sessionGeneration = self.generation() })
    end
    self:_dispatchNext(operation)
    return operation.id
end

function AttachmentService:AttachOne(item)
    return self:AttachMany({ item }, 1)
end

function AttachmentService:OnOutgoingSnapshot(snapshot)
    local operation = self.active
    if not operation or operation.state ~= "AWAITING_ACK" then return false end
    if matchingCount(snapshot, operation.current) <= operation.beforeMatchCount then return false end
    self:_cancelTimer(operation)
    operation.attachedCount = operation.attachedCount + 1
    operation.index = operation.index + 1
    operation.dispatched = false
    operation.state = "ATTACHING"
    self:_dispatchNext(operation)
    return true
end

function AttachmentService:OnWoWEvent(event)
    if event ~= "MAIL_SEND_INFO_UPDATE" and event ~= "BAG_UPDATE_DELAYED" then return false end
    local snapshot = self.compat.GetOutgoingSnapshot and self.compat:GetOutgoingSnapshot() or nil
    return snapshot and self:OnOutgoingSnapshot(snapshot) or false
end

function AttachmentService:Cancel(operationId)
    local operation = self.operations[operationId]
    if not operation or TERMINAL[operation.state] then return false end
    if operation.state == "AWAITING_ACK" and operation.dispatched then
        local snapshot = self.compat.GetOutgoingSnapshot and self.compat:GetOutgoingSnapshot() or nil
        if snapshot and matchingCount(snapshot, operation.current) > operation.beforeMatchCount then
            operation.attachedCount = operation.attachedCount + 1
            return self:_finish(operation, "CANCELLED")
        end
        if self.compat.ClearCursor then self.compat:ClearCursor() end
        return self:_finish(operation, "INDETERMINATE", newError(
            "RESULT_INDETERMINATE", "附件操作已发出，但无法确认物品是否进入邮件"))
    end
    operation.cancelRequested = true
    return self:_finish(operation, "CANCELLED")
end

function AttachmentService:GetResult(operationId)
    local operation = self.operations[operationId]
    if not operation then return nil end
    return {
        operationId = operation.id,
        state = operation.state,
        attachedCount = operation.attachedCount,
        requestedCount = #operation.items,
        error = clone(operation.error),
    }
end

function AttachmentService:OnSessionClosed()
    if self.active then return self:Cancel(self.active.id) end
    return false
end

Mail.AttachmentService = AttachmentService
