local _, ns = ...

ns = ns or {}
ns.Mail = ns.Mail or {}
local Mail = ns.Mail

local SendTransaction = {}
SendTransaction.__index = SendTransaction

local TERMINAL = { SUCCEEDED = true, FAILED = true, UNKNOWN = true, CANCELLED = true }
local MAX_SAFE_INTEGER = 9007199254740991

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

local function recipientName(recipient)
    if type(recipient) == "string" then return recipient end
    if type(recipient) ~= "table" then return nil end
    return recipient.sendName or recipient.name
end

function SendTransaction.New(deps)
    deps = deps or {}
    return setmetatable({
        compat = deps.compat or {},
        arbiter = deps.arbiter,
        attachmentService = deps.attachmentService,
        recipientRepository = deps.recipientRepository,
        historyRepository = deps.historyRepository,
        generation = deps.generation or function() return 0 end,
        idFactory = deps.idFactory,
        now = deps.now or _G.GetTime or os.time,
        schedule = deps.schedule,
        timeout = tonumber(deps.timeout) or 10,
        secureTimeout = tonumber(deps.secureTimeout) or 30,
        onTimeout = deps.onTimeout,
        nextId = 0,
        state = "IDLE",
        draft = nil,
        policy = nil,
        transactionId = nil,
        lease = nil,
        ownsLease = false,
        dispatched = false,
        recentRecorded = false,
        historyRecorded = false,
    }, SendTransaction)
end

function SendTransaction:_cancelTimer()
    if self.timer and self.timer.Cancel then self.timer:Cancel() end
    self.timer = nil
end

function SendTransaction:_scheduleTimeout(seconds)
    self:_cancelTimer()
    local function timeout()
        if self.state ~= "SENDING" and self.state ~= "WAITING_SECURE_CONFIRM" then return end
        self:OnSendEvent("TIMEOUT")
        if self.onTimeout then self.onTimeout(self:GetSnapshot()) end
    end
    if self.schedule then
        self.timer = self.schedule(seconds, timeout)
    elseif _G.C_Timer and _G.C_Timer.NewTimer then
        self.timer = _G.C_Timer.NewTimer(seconds, timeout)
    elseif _G.C_Timer and _G.C_Timer.After then
        _G.C_Timer.After(seconds, timeout)
    end
end

function SendTransaction:_newId()
    if self.idFactory then return tostring(self.idFactory("transaction")) end
    self.nextId = self.nextId + 1
    return "send-transaction-" .. self.nextId
end

function SendTransaction:_release(outcome, err)
    if self.lease and self.ownsLease and self.arbiter then
        self.arbiter:Release(self.lease, outcome, err)
    end
    self.lease = nil
    self.ownsLease = false
end

function SendTransaction:_recordHistory(state, err)
    if self.historyRecorded or not self.dispatched or self.policy.recordHistory == false
        or self.policy.ownerKind == "BULK_SEND" then return end
    self.historyRecorded = true
    if not self.historyRepository or not self.historyRepository.RecordSingle then return end
    self.historyRepository:RecordSingle({
        sourceKind = "single",
        recipient = self.draft.recipient,
        state = state,
        subject = self.draft.subject,
        amount = self.draft.money,
        postage = self.postage,
        error = err,
    })
end

function SendTransaction:_terminal(state, err)
    if TERMINAL[self.state] then return false end
    self:_cancelTimer()
    self.state = state
    self.error = err
    self.finishedAt = self.now()
    self:_release(state, err)
    self:_recordHistory(state, err)
    if state == "SUCCEEDED" and not self.recentRecorded and self.policy.recordRecent ~= false
        and self.recipientRepository and self.recipientRepository.RecordSent then
        self.recipientRepository:RecordSent(self.draft.recipient)
        self.recentRecorded = true
    end
    return true
end

function SendTransaction:Validate(draft)
    draft = draft or self.draft
    local errors = {}
    local function reject(code, message, detail)
        errors[#errors + 1] = newError(code, message, detail)
    end
    if type(draft) ~= "table" then
        reject("INVALID_DRAFT", "发件草稿无效")
        return false, errors
    end
    local sendName = recipientName(draft.recipient)
    if type(sendName) ~= "string" or sendName:gsub("%s", "") == "" then
        reject("INVALID_RECIPIENT", "收件人不能为空")
    end
    if type(draft.recipient) == "table" and draft.recipient.isSelf then
        reject("SELF_RECIPIENT", "不能给当前角色邮寄邮件")
    end
    if self.recipientRepository and type(self.recipientRepository.IsBlacklisted) == "function"
        and self.recipientRepository:IsBlacklisted(draft.recipient) then
        reject("RECIPIENT_BLACKLISTED", "该收件人已在黑名单，请先解除后再发送")
    end
    if self.compat.IsMailOpen and not self.compat:IsMailOpen() then reject("MAIL_CLOSED", "邮箱尚未打开") end
    if not (self.policy and self.policy.skipCommandPending)
        and self.compat.IsCommandPending and self.compat:IsCommandPending() then
        reject("OUTBOUND_BUSY", "邮件服务器仍在处理上一项操作")
    end
    if self.compat.IsCursorEmpty and not self.compat:IsCursorEmpty() then reject("CURSOR_BUSY", "鼠标指针上已有物品") end

    local mode = draft.mode or "STANDARD"
    local rawMoney = tonumber(draft.money or draft.amount)
    local money = rawMoney and math.floor(rawMoney) or 0
    if mode == "MONEY_ONLY" then
        if not rawMoney or rawMoney ~= rawMoney or rawMoney == math.huge or rawMoney == -math.huge
            or rawMoney ~= money or money <= 0 or money > MAX_SAFE_INTEGER then
            reject("INVALID_AMOUNT", "邮寄金币金额无效")
        end
        if tonumber(draft.cod) and tonumber(draft.cod) ~= 0 then reject("DRAFT_HAS_COD", "金币邮件不能使用付款取信") end
        if type(draft.attachments) == "table" and #draft.attachments > 0 then
            reject("DRAFT_HAS_ATTACHMENTS", "批量金币邮件不能包含附件")
        end
    end
    if self.policy and self.policy.requireSubject and (type(draft.subject) ~= "string" or draft.subject == "") then
        reject("NO_SUBJECT", "邮件主题不能为空")
    end
    if self.compat.GetPlayerMoney and self.compat.GetSendPrice and mode == "MONEY_ONLY" then
        local required = money + math.max(0, tonumber(self.compat:GetSendPrice()) or 0)
        if (tonumber(self.compat:GetPlayerMoney()) or 0) < required then
            reject("INSUFFICIENT_FUNDS", "金币和邮资余额不足", { required = required })
        end
    end
    return #errors == 0, errors
end

function SendTransaction:Begin(draft, policy)
    if self.state ~= "IDLE" and not TERMINAL[self.state] then
        return nil, newError("TRANSACTION_BUSY", "已有发件事务正在进行")
    end
    self.draft = clone(draft or {})
    self.policy = clone(policy or {})
    self.transactionId = self:_newId()
    self.state = "VALIDATING"
    self.error = nil
    self.dispatched = false
    self.recentRecorded = false
    self.historyRecorded = false
    self.startedAt = self.now()

    local valid, errors = self:Validate(self.draft)
    if not valid then
        self.state = "FAILED"
        self.error = errors[1]
        return nil, errors[1]
    end
    self.postage = self.compat.GetSendPrice
        and math.max(0, math.floor(tonumber(self.compat:GetSendPrice()) or 0)) or 0

    if type(self.draft.attachments) == "table" and #self.draft.attachments > 0
        and self.attachmentService and not self.policy.attachmentsAlreadyPrepared then
        local operationId, err = self.attachmentService:AttachMany(self.draft.attachments, #self.draft.attachments)
        if not operationId then
            self.state = "FAILED"
            self.error = err
            return nil, err
        end
        self.attachmentOperationId = operationId
        self.state = "AWAITING_ATTACHMENT_ACK"
    else
        self.state = "READY"
        if self.policy.autoSend == true then self:Send() end
    end
    return self.transactionId
end

function SendTransaction:OnAttachments(operationId, result)
    if self.state ~= "AWAITING_ATTACHMENT_ACK" or operationId ~= self.attachmentOperationId then return false end
    if not result or result.state == "INDETERMINATE" then
        return self:_terminal("FAILED", newError("ATTACHMENT_INDETERMINATE", "无法确认附件是否准备完成"))
    end
    if result.state ~= "SUCCEEDED" then
        return self:_terminal("FAILED", result.error or newError("ATTACHMENT_FAILED", "附件准备失败"))
    end
    self.state = "READY"
    if self.policy.autoSend == true then self:Send() end
    return true
end

function SendTransaction:_acquireLease()
    if self.policy.externalLease then
        self.lease = self.policy.externalLease
        self.ownsLease = false
        return true
    end
    if not self.arbiter then return true end
    local ownerKind = self.policy.ownerKind or "SINGLE_SEND"
    local lease, err = self.arbiter:Acquire(ownerKind, self.transactionId, self.generation(), {
        onDrain = function(reason) self:OnDrain(reason) end,
        onDrainTimeout = function(outcome, drainError) self:OnDrainTimeout(outcome, drainError) end,
    })
    if not lease then return nil, err or newError("OUTBOUND_BUSY", "邮箱写入通道正忙") end
    self.lease = lease
    self.ownsLease = true
    return true
end

function SendTransaction:_materialize()
    if self.draft.mode == "MONEY_ONLY" then
        if self.compat.AssertNoAttachmentsOrCOD then
            local clear, err = self.compat:AssertNoAttachmentsOrCOD()
            if not clear then return nil, err end
        end
        if self.compat.PrepareMoneyDraft then
            return self.compat:PrepareMoneyDraft({
                recipient = recipientName(self.draft.recipient),
                sendName = recipientName(self.draft.recipient),
                subject = self.draft.subject or "",
                body = self.draft.body or "",
                amount = math.floor(tonumber(self.draft.money or self.draft.amount) or 0),
                money = math.floor(tonumber(self.draft.money or self.draft.amount) or 0),
                cod = 0,
                attachments = {},
            })
        end
    elseif self.compat.PrepareDraft then
        local nativeDraft = clone(self.draft)
        nativeDraft.recipient = recipientName(self.draft.recipient)
        nativeDraft.sendName = nativeDraft.recipient
        return self.compat:PrepareDraft(nativeDraft)
    end
    return true
end

function SendTransaction:Send()
    if self.state ~= "READY" then return nil, newError("TRANSACTION_NOT_READY", "发件事务尚未准备完成") end
    if self.dispatched then return nil, newError("ALREADY_DISPATCHED", "该发件事务已经提交") end
    local valid, errors = self:Validate(self.draft)
    if not valid then return nil, errors[1] end
    local acquired, acquireError = self:_acquireLease()
    if not acquired then return nil, acquireError end
    local prepared, prepareError = self:_materialize()
    if not prepared then
        self:_release("FAILED", prepareError)
        self.state = "FAILED"
        self.error = prepareError
        return nil, prepareError
    end
    self.attemptNonce = self.transactionId .. ":" .. tostring(self.startedAt)
    if self.lease and self.arbiter and self.arbiter.SetAttempt then
        self.arbiter:SetAttempt(self.lease, {
            operationId = self.transactionId,
            batchId = self.policy.batchId,
            itemId = self.policy.itemId,
            attemptNonce = self.attemptNonce,
            sessionGeneration = self.generation(),
        })
    end
    self.state = "SENDING"
    local sent, sendError
    if self.compat.SendCurrentDraft then
        sent, sendError = self.compat:SendCurrentDraft()
    else
        sendError = newError("SEND_API_UNAVAILABLE", "当前客户端不提供发件接口")
    end
    if not sent then
        local code = type(sendError) == "table" and sendError.code or "SEND_DISPATCH_FAILED"
        if code == "PROTECTED_ACTION" or code == "HARDWARE_EVENT_REQUIRED" then
            self.state = "READY"
            self:_release("CANCELLED", sendError)
            return nil, sendError
        end
        self.dispatched = true
        self:_terminal("UNKNOWN", sendError or newError("SEND_DISPATCH_UNKNOWN", "提交邮件时无法确认调用结果"))
        return nil, self.error
    end
    self.dispatched = true
    self:_scheduleTimeout(self.timeout)
    return true
end

function SendTransaction:OnSendEvent(event, payload, ...)
    if TERMINAL[self.state] or not self.dispatched then return false end
    if type(event) == "table" then
        payload = event
        event = payload.event or payload.kind
    end
    if event == "SEND_SUCCESS" or event == "MAIL_SEND_SUCCESS" then
        return self:_terminal("SUCCEEDED")
    end
    if event == "SECURE_TRANSFER_CONFIRM_SEND_MAIL" then
        self.state = "WAITING_SECURE_CONFIRM"
        self:_scheduleTimeout(self.secureTimeout)
        if self.lease and self.arbiter and self.arbiter.MarkSecureConfirmation then
            self.arbiter:MarkSecureConfirmation(self.lease, true)
        end
        return true
    end
    if event == "SECURE_TRANSFER_CANCELLED"
        or (event == "SECURE_TRANSFER_CANCEL" and self.state == "WAITING_SECURE_CONFIRM") then
        return self:_terminal("FAILED", newError("SECURE_TRANSFER_CANCELLED", "用户取消了原生安全转账确认"))
    end
    if event == "UI_ERROR_MESSAGE" then
        local err = self.compat.NormalizeUIError
            and self.compat:NormalizeUIError(payload, ...) or nil
        if not err or err.code == "UNKNOWN" then return false end
        return self:_terminal("FAILED", err)
    end
    if event == "SEND_FAILED" or event == "MAIL_FAILED" then
        local err = type(payload) == "table" and payload
            or newError("SERVER_REJECTED", "邮件服务器拒绝了发送")
        return self:_terminal("FAILED", err)
    end
    if event == "MAIL_CLOSED" or event == "PLAYER_LEAVING_WORLD" or event == "TIMEOUT" then
        local code = event == "TIMEOUT" and "TIMEOUT_UNKNOWN" or "INTERRUPTED_UNKNOWN"
        return self:_terminal("UNKNOWN", newError(code, "邮件已提交，但结果无法确认"))
    end
    return false
end

function SendTransaction:Cancel(reason)
    if TERMINAL[self.state] then return false end
    if self.dispatched then
        return self:_terminal("UNKNOWN", newError("CANCELLED_AFTER_DISPATCH", "邮件已提交，取消时无法确认最终结果", reason))
    end
    if self.attachmentOperationId and self.attachmentService then
        self.attachmentService:Cancel(self.attachmentOperationId)
    end
    return self:_terminal("CANCELLED", newError("CANCELLED", "发件事务已取消", reason))
end

function SendTransaction:OnDrain(reason)
    if TERMINAL[self.state] then return end
    if not self.dispatched then self:Cancel(reason) end
end

function SendTransaction:OnDrainTimeout(_, err)
    if TERMINAL[self.state] then return end
    if self.dispatched then
        self:_terminal("UNKNOWN", err or newError("TIMEOUT_UNKNOWN", "关闭模块时等待发送结果超时"))
    else
        self:Cancel("DRAIN_TIMEOUT")
    end
end

function SendTransaction:GetState()
    return self.state
end

function SendTransaction:GetSnapshot()
    return {
        transactionId = self.transactionId,
        state = self.state,
        dispatched = self.dispatched,
        attemptNonce = self.attemptNonce,
        error = clone(self.error),
        draft = clone(self.draft),
    }
end

Mail.SendTransaction = SendTransaction
