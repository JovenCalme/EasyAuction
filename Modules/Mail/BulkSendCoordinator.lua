local _, ns = ...

ns = ns or {}
ns.Mail = ns.Mail or {}
local Mail = ns.Mail

local BulkSendCoordinator = {}
BulkSendCoordinator.__index = BulkSendCoordinator

local BATCH_TERMINAL = { COMPLETED = true, PARTIAL = true, STOPPED = true, INTERRUPTED = true }
local ITEM_TERMINAL = { SUCCEEDED = true, FAILED = true, UNKNOWN = true, CANCELLED = true, SKIPPED = true }
local MAX_SAFE_INTEGER = 9007199254740991

local function defaultMaximumAmount()
    local digits = tonumber(_G.MONEY_INPUT_MAX_GOLD_DIGITS) or 6
    return math.min(MAX_SAFE_INTEGER, (10 ^ digits) * 10000 - 1)
end

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

local function errorCode(err, fallback)
    return type(err) == "table" and err.code or fallback
end

local function errorMessage(err, fallback)
    return type(err) == "table" and err.message or fallback
end

local function encodeSignatureFields(...)
    local encoded = {}
    for index = 1, select("#", ...) do
        local field = select(index, ...)
        local value = field == nil and "" or tostring(field)
        encoded[index] = tostring(#value) .. ":" .. value
    end
    return table.concat(encoded)
end

local function validateHistoryRecord(record)
    if type(record) ~= "table" or type(record.id) ~= "string" or record.id == ""
        or type(record.recipients) ~= "table" then
        return nil, newError("HISTORY_CORRUPT", "批量历史记录结构损坏")
    end
    if record.retryOf ~= nil and (type(record.retryOf) ~= "string" or record.retryOf == "") then
        return nil, newError("HISTORY_CORRUPT", "批量历史重试关系损坏", { batchId = record.id })
    end
    local recipientCount = #record.recipients
    local arrayCount = 0
    for key in pairs(record.recipients) do
        if type(key) ~= "number" or key < 1 or key > recipientCount or key % 1 ~= 0 then
            return nil, newError("HISTORY_CORRUPT", "批量历史收件人列表损坏", { batchId = record.id })
        end
        arrayCount = arrayCount + 1
    end
    if arrayCount ~= recipientCount then
        return nil, newError("HISTORY_CORRUPT", "批量历史收件人列表不连续", { batchId = record.id })
    end
    local seen = {}
    for index = 1, #record.recipients do
        local item = record.recipients[index]
        if type(item) ~= "table" or type(item.itemId) ~= "string" or item.itemId == ""
            or type(item.recipientKey) ~= "string" or item.recipientKey == ""
            or type(item.sendName) ~= "string" or item.sendName == ""
            or type(item.state) ~= "string" or item.state == ""
            or seen[item.recipientKey] then
            return nil, newError("HISTORY_CORRUPT", "批量历史收件人结构损坏", {
                batchId = record.id, index = index,
            })
        end
        seen[item.recipientKey] = true
    end
    return true
end

local function retryPlanSignature(plan)
    if type(plan) ~= "table" or type(plan.recipientKeys) ~= "table"
        or type(plan.recipients) ~= "table" or #plan.recipientKeys == 0
        or #plan.recipientKeys ~= #plan.recipients then return nil end
    local parts = { encodeSignatureFields(plan.batchId, plan.retryRootId, plan.amountEach,
        plan.subject, plan.sourceKind, plan.sourceGroupId) }
    local seen = {}
    for index = 1, #plan.recipientKeys do
        local key, recipient = plan.recipientKeys[index], plan.recipients[index]
        if type(key) ~= "string" or key == "" or seen[key] or type(recipient) ~= "table"
            or recipient.recipientKey ~= key or type(recipient.sendName) ~= "string"
            or recipient.sendName == "" then return nil end
        seen[key] = true
        parts[#parts + 1] = encodeSignatureFields(key, recipient.displayName, recipient.sendName)
    end
    return table.concat(parts)
end

function BulkSendCoordinator.New(deps)
    deps = deps or {}
    return setmetatable({
        compat = deps.compat or {},
        arbiter = deps.arbiter,
        history = deps.historyRepository,
        recipientRepository = deps.recipientRepository,
        rosterService = deps.rosterService,
        transactionFactory = deps.transactionFactory,
        generation = deps.generation or function() return 0 end,
        idFactory = deps.idFactory,
        now = deps.now or _G.time or os.time,
        maxRecipients = tonumber(deps.maxRecipients) or 200,
        maxAmountEach = tonumber(deps.maxAmountEach) or defaultMaximumAmount(),
        autoContinue = deps.autoContinue ~= false,
        nextId = 0,
        batch = nil,
        lease = nil,
        activeTransaction = nil,
        stopRequested = false,
    }, BulkSendCoordinator)
end

function BulkSendCoordinator:_newId(prefix)
    if self.idFactory then return tostring(self.idFactory(prefix)) end
    local id
    repeat
        self.nextId = self.nextId + 1
        id = prefix .. "-" .. tostring(math.floor(tonumber(self.now()) or 0)) .. "-" .. self.nextId
    until prefix ~= "batch" or not self.history or not self.history:Get(id)
    return id
end

function BulkSendCoordinator:Validate(draft)
    local errors = {}
    local function reject(code, message, detail) errors[#errors + 1] = newError(code, message, detail) end
    if type(draft) ~= "table" then
        reject("INVALID_DRAFT", "批量邮寄草稿无效")
        return { ok = false, errors = errors }
    end
    local recipients = draft.recipients
    if type(recipients) ~= "table" then
        reject("INVALID_RECIPIENT", "收件人列表无效")
        recipients = {}
    end
    if #recipients == 0 then reject("INVALID_RECIPIENT", "至少选择一名收件人") end
    if #recipients > self.maxRecipients then
        reject("TOO_MANY_RECIPIENTS", "单批最多发送给 " .. self.maxRecipients .. " 人")
    end
    local seen = {}
    for index = 1, #recipients do
        local recipient = recipients[index]
        if type(recipient) ~= "table" then
            reject("INVALID_RECIPIENT", "收件人记录无效", { index = index })
        else
            local key = recipient.recipientKey
            if recipient.isSelf then reject("SELF_RECIPIENT", "不能给当前角色邮寄金币", { index = index }) end
            if self.recipientRepository and type(self.recipientRepository.IsBlacklisted) == "function"
                and self.recipientRepository:IsBlacklisted(recipient) then
                reject("RECIPIENT_BLACKLISTED", "批次中包含黑名单收件人", {
                    index = index, recipientKey = key,
                })
            end
            if type(key) ~= "string" or key == "" or type(recipient.sendName) ~= "string"
                or recipient.sendName == "" then
                reject("INVALID_RECIPIENT", "收件人记录无效", { index = index })
            elseif seen[key] then
                reject("DUPLICATE_RECIPIENT", "批次中存在重复收件人", { recipientKey = key })
            else
                seen[key] = true
            end
        end
    end
    local rawAmount = tonumber(draft.amountEach)
    local amount = rawAmount and math.floor(rawAmount) or 0
    local amountValid = rawAmount and rawAmount == rawAmount and rawAmount ~= math.huge
        and rawAmount ~= -math.huge and rawAmount == amount and amount > 0 and amount <= self.maxAmountEach
    if not amountValid then
        reject("INVALID_AMOUNT", "单人邮寄金额超出客户端可安全处理的范围", {
            maximum = self.maxAmountEach,
        })
        amount = 0
    end
    if type(draft.subject) ~= "string" or draft.subject:gsub("%s", "") == "" then reject("NO_SUBJECT", "邮件主题不能为空") end
    if type(draft.attachments) == "table" and #draft.attachments > 0 then
        reject("DRAFT_HAS_ATTACHMENTS", "批量金币邮件不能包含附件")
    end
    if tonumber(draft.cod) and tonumber(draft.cod) ~= 0 then reject("DRAFT_HAS_COD", "批量金币邮件不能使用付款取信") end
    if self.compat.IsMailOpen and not self.compat:IsMailOpen() then reject("MAIL_CLOSED", "邮箱尚未打开") end
    if self.rosterService then
        local roster = self.rosterService:GetSnapshot()
        if roster.stale or roster.loading or (draft.rosterGeneration and roster.generation ~= draft.rosterGeneration) then
            reject("ROSTER_STALE", "名单已变化，请刷新后重新确认")
        end
    end
    local postage = self.compat.GetSendPrice and math.max(0, tonumber(self.compat:GetSendPrice()) or 0) or 0
    local required = 0
    if #recipients > 0 then
        if amount > math.floor((MAX_SAFE_INTEGER - postage * #recipients) / #recipients) then
            reject("INVALID_AMOUNT", "批量金额合计超出 Lua 安全整数范围")
        else
            required = (amount + postage) * #recipients
        end
    end
    if self.compat.GetPlayerMoney and (tonumber(self.compat:GetPlayerMoney()) or 0) < required then
        reject("INSUFFICIENT_FUNDS", "余额不足以完成整个批次", { required = required })
    end
    return { ok = #errors == 0, errors = errors, postageEach = postage, required = required }
end

function BulkSendCoordinator:_historyRecord(draft, validation, batchId)
    local recipients = {}
    for index = 1, #draft.recipients do
        local recipient = draft.recipients[index]
        recipients[index] = {
            itemId = recipient.itemId or (recipient.recipientKey .. ":" .. index),
            recipientKey = recipient.recipientKey,
            displayName = recipient.displayName or recipient.sendName,
            sendName = recipient.sendName,
            state = "PENDING",
            attemptCount = 0,
            amount = math.floor(tonumber(draft.amountEach) or 0),
        }
    end
    return {
        schemaVersion = 2,
        id = batchId,
        retryOf = draft.retryOf,
        retryRootId = draft.retryRootId,
        senderKey = draft.senderKey or "",
        realmFactionKey = draft.realmFactionKey or "",
        sourceKind = draft.sourceKind or "custom",
        sourceGroupId = draft.sourceGroupId,
        startedAt = self.now(),
        state = "RUNNING",
        amountEach = math.floor(tonumber(draft.amountEach) or 0),
        postageEstimate = validation.postageEach,
        subject = draft.subject,
        recipients = recipients,
    }
end

function BulkSendCoordinator:_notify(item)
    if Mail.Publish then
        Mail:Publish("MAIL_BULK_BATCH_CHANGED", {
            batchId = self.batch and self.batch.id,
            itemId = item and item.itemId,
            state = self.batch and self.batch.state,
            progress = self:GetState(),
        })
    end
end

function BulkSendCoordinator:_updateItem(item, state, err, postage)
    item.state = state
    if state == "PREPARING" and not item.startedAt then item.startedAt = self.now() end
    if ITEM_TERMINAL[state] then item.finishedAt = self.now() end
    if postage ~= nil then item.postage = postage end
    item.errorCode = err and errorCode(err, "UNKNOWN") or nil
    item.errorMessage = err and errorMessage(err, "未知错误") or nil
    if self.history then
        self.history:UpdateItem(self.batch.id, item.itemId, {
            state = item.state, attemptCount = item.attemptCount, postage = item.postage,
            startedAt = item.startedAt, finishedAt = item.finishedAt,
            errorCode = item.errorCode, errorMessage = item.errorMessage,
        })
    end
    self:_notify(item)
end

function BulkSendCoordinator:_acquire(batchId)
    if not self.arbiter then return true end
    local lease, err = self.arbiter:Acquire("BULK_SEND", batchId, self.generation(), {
        onDrain = function(reason) self:OnDrain(reason) end,
        onDrainTimeout = function(outcome, drainError) self:OnDrainTimeout(outcome, drainError) end,
    })
    if not lease then return nil, err or newError("OUTBOUND_BUSY", "邮箱写入通道正忙") end
    self.lease = lease
    return true
end

function BulkSendCoordinator:Start(draft)
    if self.batch and not BATCH_TERMINAL[self.batch.state] then
        return nil, newError("BATCH_BUSY", "已有批量邮寄正在进行")
    end
    local validation = self:Validate(draft)
    if not validation.ok then return nil, validation.errors[1] end
    local batchId = draft.batchId or self:_newId("batch")
    local acquired, acquireError = self:_acquire(batchId)
    if not acquired then return nil, acquireError end
    local record = self:_historyRecord(draft, validation, batchId)
    if self.history then
        local saved, historyError = self.history:Create(record)
        if not saved then
            if self.lease and self.arbiter then self.arbiter:Release(self.lease, "CANCELLED", historyError) end
            self.lease = nil
            return nil, historyError
        end
    end
    self.batch = clone(record)
    self.batch.body = draft.body or ""
    self.batch.rosterGeneration = draft.rosterGeneration
    self.batch.currentIndex = 1
    self.batch.postageEach = validation.postageEach
    self.stopRequested = false
    self.activeTransaction = nil
    self:_notify()
    self:_prepareCurrent()
    return batchId
end

function BulkSendCoordinator:_newTransaction()
    local deps = {
        compat = self.compat,
        arbiter = self.arbiter,
        recipientRepository = self.recipientRepository,
        generation = self.generation,
        now = self.now,
        idFactory = function(prefix) return self:_newId(prefix) end,
        onTimeout = function(snapshot) self:_onTransactionTimeout(snapshot) end,
    }
    if self.transactionFactory then return self.transactionFactory(deps) end
    return Mail.SendTransaction and Mail.SendTransaction.New(deps) or nil
end

function BulkSendCoordinator:_onTransactionTimeout(snapshot)
    if not self.batch or BATCH_TERMINAL[self.batch.state] or not self.activeTransaction then return end
    local item = self.batch.recipients[self.batch.currentIndex]
    if item and not ITEM_TERMINAL[item.state] then
        self:_updateItem(item, "UNKNOWN", snapshot and snapshot.error
            or newError("TIMEOUT_UNKNOWN", "等待发送结果超时"))
    end
    self.activeTransaction = nil
    self:_stopAfterUnknown()
end

function BulkSendCoordinator:_prepareCurrent()
    if not self.batch or BATCH_TERMINAL[self.batch.state] then return false end
    if self.stopRequested then return self:_cancelRemainingAndFinish() end
    local item = self.batch.recipients[self.batch.currentIndex]
    if not item then return self:_finishFromResults() end
    if self.compat.IsCommandPending and self.compat:IsCommandPending() then
        self.batch.state = "PAUSED"
        self:_updateItem(item, "FAILED", newError("OUTBOUND_BUSY", "邮件服务器仍在处理上一项操作"))
        return false
    end
    self.batch.state = "RUNNING"
    self:_updateItem(item, "PREPARING")
    item.attemptCount = item.attemptCount + 1
    local transaction = self:_newTransaction()
    if not transaction then
        self:_updateItem(item, "FAILED", newError("SEND_SERVICE_UNAVAILABLE", "发件事务服务尚未初始化"))
        self.batch.state = "PAUSED"
        return false
    end
    self.activeTransaction = transaction
    local transactionId, beginError = transaction:Begin({
        mode = "MONEY_ONLY",
        recipient = { recipientKey = item.recipientKey, sendName = item.sendName, name = item.displayName },
        subject = self.batch.subject,
        body = self.batch.body,
        money = self.batch.amountEach,
        cod = 0,
        attachments = {},
    }, {
        autoSend = false,
        externalLease = self.lease,
        ownerKind = "BULK_SEND",
        batchId = self.batch.id,
        itemId = item.itemId,
        requireSubject = true,
        recordRecent = false,
    })
    if not transactionId then
        self.activeTransaction = nil
        self:_updateItem(item, "FAILED", beginError)
        self.batch.state = "PAUSED"
        return false
    end
    return self:_dispatchActive()
end

function BulkSendCoordinator:_dispatchActive()
    local item = self.batch and self.batch.recipients[self.batch.currentIndex]
    if not item or not self.activeTransaction then return false end
    local sent, err = self.activeTransaction:Send()
    if not sent then
        local code = errorCode(err, "SEND_DISPATCH_FAILED")
        if code == "PROTECTED_ACTION" or code == "HARDWARE_EVENT_REQUIRED" then
            self.batch.state = "WAITING_USER_ACTION"
            self:_updateItem(item, "WAITING_USER_ACTION", err)
            return false
        end
        local transactionState = self.activeTransaction:GetState()
        if transactionState == "UNKNOWN" then
            self:_updateItem(item, "UNKNOWN", err)
            return self:_stopAfterUnknown()
        end
        self:_updateItem(item, "FAILED", err)
        self.batch.state = "PAUSED"
        return false
    end
    self.batch.state = "RUNNING"
    self:_updateItem(item, "AWAITING_ACK", nil, self.compat.GetSendPrice and self.compat:GetSendPrice() or 0)
    return true
end

function BulkSendCoordinator:Continue()
    if not self.batch or BATCH_TERMINAL[self.batch.state] then return nil, newError("NO_ACTIVE_BATCH", "当前没有可继续的批次") end
    if self.batch.state == "WAITING_SECURE_CONFIRM" then
        return nil, newError("SECURE_CONFIRM_PENDING", "请先处理原生安全转账确认框")
    end
    if self.batch.state == "WAITING_USER_ACTION" and self.activeTransaction
        and self.activeTransaction:GetState() == "READY" then
        return self:_dispatchActive()
    end
    if self.batch.state == "PAUSED" or self.batch.state == "WAITING_USER_ACTION" then
        return self:_prepareCurrent()
    end
    return nil, newError("BATCH_NOT_PAUSED", "批次当前不需要继续操作")
end

function BulkSendCoordinator:OnSendEvent(event, ...)
    if not self.batch or not self.activeTransaction or BATCH_TERMINAL[self.batch.state] then return false end
    local item = self.batch.recipients[self.batch.currentIndex]
    self.activeTransaction:OnSendEvent(event, ...)
    local transactionState = self.activeTransaction:GetState()
    if transactionState == "WAITING_SECURE_CONFIRM" then
        self.batch.state = "WAITING_SECURE_CONFIRM"
        self:_updateItem(item, "WAITING_SECURE_CONFIRM")
        return true
    end
    if transactionState == "SUCCEEDED" then
        self:_updateItem(item, "SUCCEEDED", nil, item.postage or self.batch.postageEach)
        self.activeTransaction = nil
        self.batch.currentIndex = self.batch.currentIndex + 1
        if self.stopRequested then return self:_cancelRemainingAndFinish() end
        if not self.batch.recipients[self.batch.currentIndex] then return self:_finishFromResults() end
        if self.autoContinue then return self:_prepareCurrent() end
        self.batch.state = "WAITING_USER_ACTION"
        self:_notify()
        return true
    end
    if transactionState == "FAILED" then
        local snapshot = self.activeTransaction:GetSnapshot()
        self:_updateItem(item, "FAILED", snapshot.error)
        self.activeTransaction = nil
        self.batch.currentIndex = self.batch.currentIndex + 1
        if self.stopRequested then return self:_cancelRemainingAndFinish() end
        if not self.batch.recipients[self.batch.currentIndex] then return self:_finishFromResults() end
        self.batch.state = "PAUSED"
        self:_notify(item)
        return true
    end
    if transactionState == "UNKNOWN" then
        local snapshot = self.activeTransaction:GetSnapshot()
        self:_updateItem(item, "UNKNOWN", snapshot.error)
        self.activeTransaction = nil
        return self:_stopAfterUnknown()
    end
    return false
end

function BulkSendCoordinator:_cancelRemaining()
    if not self.batch then return end
    for index = self.batch.currentIndex, #self.batch.recipients do
        local item = self.batch.recipients[index]
        if not ITEM_TERMINAL[item.state] then
            self:_updateItem(item, "CANCELLED", newError("BATCH_CANCELLED", "批次已停止，邮件尚未提交"))
        end
    end
end

function BulkSendCoordinator:_release(outcome, err)
    if self.lease and self.arbiter then self.arbiter:Release(self.lease, outcome, err) end
    self.lease = nil
end

function BulkSendCoordinator:_finish(state, outcome, err)
    self.batch.state = state
    self.batch.finishedAt = self.now()
    if self.history then self.history:Finalize(self.batch.id, state) end
    self:_release(outcome or state, err)
    self:_notify()
    return true
end

function BulkSendCoordinator:_finishFromResults()
    local allSucceeded = true
    for index = 1, #self.batch.recipients do
        if self.batch.recipients[index].state ~= "SUCCEEDED" then allSucceeded = false break end
    end
    return self:_finish(allSucceeded and "COMPLETED" or "PARTIAL", allSucceeded and "SUCCEEDED" or "FAILED")
end

function BulkSendCoordinator:_stopAfterUnknown()
    self:_cancelRemaining()
    return self:_finish("STOPPED", "UNKNOWN", newError("BATCH_STOPPED_UNKNOWN", "存在结果未知的邮件，批次已停止"))
end

function BulkSendCoordinator:_cancelRemainingAndFinish()
    self:_cancelRemaining()
    return self:_finish("STOPPED", "CANCELLED")
end

function BulkSendCoordinator:CancelPending(reason)
    if not self.batch or BATCH_TERMINAL[self.batch.state] then return false end
    self.stopRequested = true
    local item = self.batch.recipients[self.batch.currentIndex]
    local dispatched = self.activeTransaction and self.activeTransaction:GetSnapshot().dispatched
    if dispatched then
        for index = self.batch.currentIndex + 1, #self.batch.recipients do
            local pending = self.batch.recipients[index]
            if not ITEM_TERMINAL[pending.state] then
                self:_updateItem(pending, "CANCELLED", newError("BATCH_CANCELLED", "用户停止了尚未发送的邮件", reason))
            end
        end
        return true
    end
    if self.activeTransaction then self.activeTransaction:Cancel(reason) self.activeTransaction = nil end
    if item and not ITEM_TERMINAL[item.state] then
        self:_updateItem(item, "CANCELLED", newError("BATCH_CANCELLED", "用户停止了尚未发送的邮件", reason))
    end
    return self:_cancelRemainingAndFinish()
end

function BulkSendCoordinator:OnDrain(reason)
    if not self.batch or BATCH_TERMINAL[self.batch.state] then return end
    local dispatched = self.activeTransaction and self.activeTransaction:GetSnapshot().dispatched
    if not dispatched then self:CancelPending(reason) else self.stopRequested = true end
end

function BulkSendCoordinator:OnSessionClosed(reason)
    if not self.batch or BATCH_TERMINAL[self.batch.state] then return false end
    local dispatched = self.activeTransaction and self.activeTransaction:GetSnapshot().dispatched
    if dispatched then return self:OnSendEvent("MAIL_CLOSED") end
    return self:CancelPending(reason or "MAIL_CLOSED")
end

function BulkSendCoordinator:OnDrainTimeout(_, err)
    if not self.batch or BATCH_TERMINAL[self.batch.state] then return end
    local item = self.batch.recipients[self.batch.currentIndex]
    if item and not ITEM_TERMINAL[item.state] then self:_updateItem(item, "UNKNOWN", err or newError("TIMEOUT_UNKNOWN", "关闭模块时等待发送结果超时")) end
    self.lease = nil
    self.activeTransaction = nil
    self:_cancelRemaining()
    self.batch.state = "STOPPED"
    if self.history then self.history:Finalize(self.batch.id, "STOPPED") end
    self:_notify(item)
end

function BulkSendCoordinator:GetState()
    if not self.batch then return nil end
    local state = clone(self.batch)
    state.current = clone(self.batch.recipients[self.batch.currentIndex])
    state.totalCount = #self.batch.recipients
    state.successCount, state.failedCount, state.unknownCount, state.cancelledCount = 0, 0, 0, 0
    for index = 1, #self.batch.recipients do
        local itemState = self.batch.recipients[index].state
        if itemState == "SUCCEEDED" then state.successCount = state.successCount + 1
        elseif itemState == "FAILED" then state.failedCount = state.failedCount + 1
        elseif itemState == "UNKNOWN" then state.unknownCount = state.unknownCount + 1
        elseif itemState == "CANCELLED" or itemState == "SKIPPED" then state.cancelledCount = state.cancelledCount + 1 end
    end
    state.completedCount = state.successCount + state.failedCount + state.unknownCount + state.cancelledCount
    state.pendingCount = state.totalCount - state.completedCount
    state.body = nil
    return state
end

local RETRYABLE_DESCENDANT_STATE = { FAILED = true, CANCELLED = true, SKIPPED = true }

function BulkSendCoordinator:PrepareRetryFailed(batchId, recipientKeys)
    if not self.history then return nil, newError("HISTORY_UNAVAILABLE", "批量历史不可用") end
    local source = self.history:Get(batchId)
    if not source then return nil, newError("BATCH_NOT_FOUND", "找不到原批次") end
    if self.batch and not BATCH_TERMINAL[self.batch.state] then
        return nil, newError("BATCH_BUSY", "已有批量邮寄正在进行")
    end
    local requested
    if type(recipientKeys) == "table" and #recipientKeys > 0 then
        requested = {}
        for index = 1, #recipientKeys do requested[recipientKeys[index]] = true end
    end
    local validSource, sourceError = validateHistoryRecord(source)
    if not validSource then return nil, sourceError end
    local sourceAmount = tonumber(source.amountEach)
    if not sourceAmount or sourceAmount ~= sourceAmount or sourceAmount == math.huge
        or sourceAmount == -math.huge or sourceAmount ~= math.floor(sourceAmount)
        or sourceAmount <= 0 or sourceAmount > self.maxAmountEach
        or type(source.subject) ~= "string" or source.subject:gsub("%s", "") == "" then
        return nil, newError("HISTORY_CORRUPT", "原批次的金额或主题无效", { batchId = batchId })
    end
    local candidates, candidateKeys = {}, {}
    for index = 1, #source.recipients do
        local item = source.recipients[index]
        if item.state == "FAILED" and (not requested or requested[item.recipientKey]) then
            candidates[#candidates + 1] = item
            candidateKeys[item.recipientKey] = true
        end
    end
    local records, recordsError
    if type(self.history.GetRetryRecords) == "function" then
        records, recordsError = self.history:GetRetryRecords()
    else
        records = self.history:List(0, self.history.maxBatches or 50)
    end
    if not records then return nil, recordsError or newError("HISTORY_CORRUPT", "无法读取批量历史") end
    local recordsById, sourceIndexed = {}, false
    for index = 1, #records do
        local record = records[index]
        local valid, validationError = validateHistoryRecord(record)
        if not valid then return nil, validationError end
        if recordsById[record.id] then
            return nil, newError("HISTORY_CORRUPT", "批量历史包含重复批次", { batchId = record.id })
        end
        recordsById[record.id] = record
        if record.id == batchId then sourceIndexed = true end
    end
    if not sourceIndexed then return nil, newError("HISTORY_CORRUPT", "原批次未进入历史索引") end
    local related = { [batchId] = true }
    local retryRootId = source.retryRootId or source.id
    for index = 1, #records do
        if records[index].retryRootId == retryRootId then related[records[index].id] = true end
    end
    local changed = true
    while changed do
        changed = false
        for index = 1, #records do
            local record = records[index]
            if record.retryOf and related[record.retryOf] and not related[record.id] then
                related[record.id] = true
                changed = true
            end
        end
    end
    for index = 1, #records do
        local record = records[index]
        if record.id ~= batchId and record.retryOf and not recordsById[record.retryOf]
            and (tonumber(record.startedAt) or 0) >= (tonumber(source.startedAt) or 0) then
            for itemIndex = 1, #record.recipients do
                if candidateKeys[record.recipients[itemIndex].recipientKey] then
                    return nil, newError("HISTORY_INCOMPLETE", "重试历史链不完整，无法确认是否已经发送", {
                        batchId = record.id, missingParent = record.retryOf,
                    })
                end
            end
        end
    end
    local blocked, revisionParts = {}, {}
    revisionParts[#revisionParts + 1] = encodeSignatureFields(source.id, source.retryOf,
        source.retryRootId, source.amountEach, source.subject, source.sourceKind, source.sourceGroupId)
    for index = 1, #records do
        local record = records[index]
        if related[record.id] then
            for itemIndex = 1, #(record.recipients or {}) do
                local item = record.recipients[itemIndex]
                revisionParts[#revisionParts + 1] = encodeSignatureFields(record.id, record.retryOf,
                    record.retryRootId, item.itemId, item.recipientKey, item.displayName,
                    item.sendName, item.state)
                if record.id ~= batchId and candidateKeys[item.recipientKey]
                    and not RETRYABLE_DESCENDANT_STATE[item.state] then
                    blocked[item.recipientKey] = true
                end
            end
        end
    end
    local recipients, keys = {}, {}
    for index = 1, #candidates do
        local item = candidates[index]
        if not blocked[item.recipientKey] then
            recipients[#recipients + 1] = {
                recipientKey = item.recipientKey,
                displayName = item.displayName,
                sendName = item.sendName,
            }
            keys[#keys + 1] = item.recipientKey
        end
    end
    if #recipients == 0 then
        return nil, newError("NO_RETRYABLE_RECIPIENTS", "没有可安全重试的明确失败收件人")
    end
    local plan = {
        batchId = batchId,
        retryRootId = source.retryRootId or source.id,
        recipientKeys = keys,
        recipients = recipients,
        amountEach = source.amountEach,
        subject = source.subject,
        sourceKind = source.sourceKind,
        sourceGroupId = source.sourceGroupId,
    }
    revisionParts[#revisionParts + 1] = retryPlanSignature(plan)
    table.sort(revisionParts)
    plan.revision = table.concat(revisionParts, "\n")
    return plan
end

function BulkSendCoordinator:RetryFailed(batchOrPlan, recipientKeys)
    local plan, err
    if type(batchOrPlan) == "table" then
        local frozenSignature = retryPlanSignature(batchOrPlan)
        if not frozenSignature then
            return nil, newError("RETRY_SET_CHANGED", "冻结重试计划无效，请重新确认")
        end
        plan, err = self:PrepareRetryFailed(batchOrPlan.batchId, batchOrPlan.recipientKeys)
        if not plan then
            return nil, newError("RETRY_SET_CHANGED", "可重试名单已经变化，请重新确认", {
                cause = err and err.code,
            })
        end
        if plan.revision ~= batchOrPlan.revision or retryPlanSignature(plan) ~= frozenSignature then
            return nil, newError("RETRY_SET_CHANGED", "可重试名单已经变化，请重新确认")
        end
    else
        plan, err = self:PrepareRetryFailed(batchOrPlan, recipientKeys)
        if not plan then return nil, err end
    end
    local recipients = {}
    for index = 1, #plan.recipients do
        local recipient = plan.recipients[index]
        recipients[index] = {
            itemId = self:_newId("retry-item"), recipientKey = recipient.recipientKey,
            displayName = recipient.displayName, sendName = recipient.sendName,
        }
    end
    return self:Start({
        retryOf = plan.batchId,
        retryRootId = plan.retryRootId,
        sourceKind = plan.sourceKind,
        sourceGroupId = plan.sourceGroupId,
        amountEach = plan.amountEach,
        subject = plan.subject,
        body = "",
        recipients = recipients,
    })
end

Mail.BulkSendCoordinator = BulkSendCoordinator
