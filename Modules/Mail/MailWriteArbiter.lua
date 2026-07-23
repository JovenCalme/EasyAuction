local _, ns = ...
local Mail = ns.Mail

local Arbiter = {}
Arbiter.__index = Arbiter

local SEND_OWNERS = { SINGLE_SEND = true, BULK_SEND = true }
local INBOX_OWNERS = { INBOX_QUEUE = true }

local function ownerFamily(ownerKind)
    if SEND_OWNERS[ownerKind] then return "SEND" end
    if INBOX_OWNERS[ownerKind] then return "INBOX" end
    if ownerKind == "ATTACHMENT" then return "ATTACHMENT" end
    return ownerKind
end

local function now(self)
    if type(self.deps.now) == "function" then return self.deps.now() end
    if type(_G.GetTime) == "function" then return _G.GetTime() end
    return 0
end

local function notifyDrain(self)
    if not self.drain or self.drain.phase ~= "COMPLETED" then return end
    if type(self.deps.onDrainComplete) == "function" then
        Mail:SafeCall(self.deps.onDrainComplete, self.drain)
    end
    for _, callback in pairs(self.drainSubscribers) do
        Mail:SafeCall(callback, self.drain)
    end
end

local function scheduleTimeout(self, callback)
    if type(self.deps.schedule) == "function" then
        return self.deps.schedule(self.drainTimeout, callback)
    end
    if _G.C_Timer and type(_G.C_Timer.NewTimer) == "function" then
        return _G.C_Timer.NewTimer(self.drainTimeout, callback)
    end
    if _G.C_Timer and type(_G.C_Timer.After) == "function" then
        _G.C_Timer.After(self.drainTimeout, callback)
    end
end

local function refreshNativeSendButton(self)
    local compat = Mail.Compat
    if compat and type(compat.RefreshNativeSendButton) == "function" then
        Mail:SafeCall(compat.RefreshNativeSendButton, compat, self)
    end
end

function Arbiter.New(deps)
    deps = deps or {}
    return setmetatable({
        deps = deps,
        accepting = true,
        leaseSequence = 0,
        drainSequence = 0,
        attemptSequence = 0,
        current = nil,
        drain = nil,
        drainTimer = nil,
        drainTimeout = tonumber(deps.drainTimeout) or 10,
        drainSubscribers = {},
        quarantines = {},
    }, Arbiter)
end

function Arbiter:IsAccepting()
    return self.accepting == true
end

function Arbiter:GetOwner()
    if not self.current then return nil end
    return {
        ownerKind = self.current.ownerKind,
        ownerId = self.current.ownerId,
        sessionGeneration = self.current.sessionGeneration,
        leaseId = self.current.id,
        phase = self.current.securePending and "WAITING_SECURE_CONFIRM" or "ACTIVE",
    }
end

function Arbiter:Acquire(ownerKind, ownerId, sessionGeneration, callbacks)
    if not self.accepting then
        return nil, Mail:NewError("MAIL_WRITE_DRAINING", "邮箱模块正在停止，暂不接受新的写操作。")
    end
    if self.current then
        return nil, Mail:NewError("MAIL_WRITE_BUSY", "另一项邮箱写操作正在进行。", self:GetOwner())
    end
    if type(ownerKind) ~= "string" or ownerId == nil or type(sessionGeneration) ~= "number" then
        return nil, Mail:NewError("INVALID_LEASE_REQUEST", "邮件写入租约参数无效。")
    end
    local family = ownerFamily(ownerKind)
    local quarantine = self.quarantines[family]
    if quarantine and quarantine.sessionGeneration == sessionGeneration then
        return nil, Mail:NewError("MAIL_ACK_QUARANTINED",
            "上一次邮件操作结果未知。为防止迟到回执误关联，请关闭并重新打开邮箱后再试。", {
                ownerFamily = family,
                sessionGeneration = sessionGeneration,
                previousOwnerId = quarantine.ownerId,
                outcome = quarantine.outcome,
            })
    elseif quarantine then
        self.quarantines[family] = nil
    end
    self.leaseSequence = self.leaseSequence + 1
    local lease = {
        id = "mail-lease-" .. self.leaseSequence,
        ownerKind = ownerKind,
        ownerId = ownerId,
        sessionGeneration = sessionGeneration,
        acquiredAt = now(self),
        callbacks = type(callbacks) == "table" and callbacks or nil,
        attempt = nil,
        securePending = false,
        released = false,
    }
    self.current = lease
    refreshNativeSendButton(self)
    return lease
end

function Arbiter:SetAttempt(lease, context)
    if lease ~= self.current or lease.released then
        return nil, Mail:NewError("INVALID_MAIL_LEASE", "邮件写入租约已失效。")
    end
    context = context or {}
    self.attemptSequence = self.attemptSequence + 1
    lease.attempt = {
        operationId = context.operationId,
        batchId = context.batchId,
        itemId = context.itemId,
        attemptNonce = context.attemptNonce or ("attempt-" .. self.attemptSequence),
        sessionGeneration = context.sessionGeneration or lease.sessionGeneration,
        dispatchedAt = now(self),
        acknowledged = false,
    }
    return lease.attempt
end

function Arbiter:MarkSecureConfirmation(lease, pending)
    if lease ~= self.current or lease.released then
        return nil, Mail:NewError("INVALID_MAIL_LEASE", "邮件写入租约已失效。")
    end
    lease.securePending = pending == true
    if self.drain then
        self.drain.phase = lease.securePending and "WAITING_SECURE_CONFIRM" or "DRAINING"
    end
    return true
end

function Arbiter:RouteEvent(event, ...)
    local lease = self.current
    local attempt = lease and lease.attempt
    if not lease or not attempt or attempt.acknowledged then return nil end
    local arguments = { ... }
    local metadata = type(arguments[1]) == "table" and arguments[1] or nil
    if metadata and metadata.sessionGeneration
        and metadata.sessionGeneration ~= lease.sessionGeneration then
        return nil
    end

    local kind
    if SEND_OWNERS[lease.ownerKind] then
        if event == "SECURE_TRANSFER_CONFIRM_SEND_MAIL" then
            self:MarkSecureConfirmation(lease, true)
            return {
                kind = "WAITING_SECURE_CONFIRM",
                event = event,
                ownerKind = lease.ownerKind,
                ownerId = lease.ownerId,
                leaseId = lease.id,
                sessionGeneration = lease.sessionGeneration,
                operationId = attempt.operationId,
                batchId = attempt.batchId,
                itemId = attempt.itemId,
                attemptNonce = attempt.attemptNonce,
            }
        elseif event == "SECURE_TRANSFER_CANCEL" and lease.securePending then
            lease.securePending = false
            kind = "SECURE_TRANSFER_CANCELLED"
        elseif event == "MAIL_SEND_SUCCESS" then
            lease.securePending = false
            kind = "SEND_SUCCESS"
        elseif event == "MAIL_FAILED" then kind = "SEND_FAILED" end
    elseif INBOX_OWNERS[lease.ownerKind] then
        if event == "MAIL_SUCCESS" then kind = "INBOX_SUCCESS"
        elseif event == "MAIL_FAILED" then kind = "INBOX_FAILED"
        elseif event == "MAIL_INBOX_UPDATE" or event == "BAG_UPDATE_DELAYED" then kind = "INBOX_CHANGED" end
    elseif lease.ownerKind == "ATTACHMENT" then
        if event == "BAG_UPDATE_DELAYED" then kind = "ATTACHMENT_CHANGED" end
    end
    if not kind then return nil end
    attempt.acknowledged = true
    return {
        kind = kind,
        event = event,
        ownerKind = lease.ownerKind,
        ownerId = lease.ownerId,
        leaseId = lease.id,
        sessionGeneration = lease.sessionGeneration,
        operationId = attempt.operationId,
        batchId = attempt.batchId,
        itemId = attempt.itemId,
        attemptNonce = attempt.attemptNonce,
        raw = arguments,
    }
end

function Arbiter:SubscribeDrain(owner, callback)
    if owner == nil or type(callback) ~= "function" then
        return nil, Mail:NewError("INVALID_DRAIN_SUBSCRIBER", "停止监听参数无效。")
    end
    self.drainSubscribers[owner] = callback
    return true
end

function Arbiter:UnsubscribeDrain(owner)
    self.drainSubscribers[owner] = nil
end

function Arbiter:GetDrainState(drainId)
    if self.drain and (drainId == nil or self.drain.drainId == drainId) then return self.drain end
    return nil
end

function Arbiter:BeginDrain(reason)
    if self.drain and self.drain.phase ~= "COMPLETED" then
        return self.drain.drainId, self.drain
    end
    self.accepting = false
    self.drainSequence = self.drainSequence + 1
    local lease = self.current
    self.drain = {
        drainId = "mail-drain-" .. self.drainSequence,
        ownerKind = lease and lease.ownerKind or nil,
        ownerId = lease and lease.ownerId or nil,
        phase = lease and (lease.securePending and "WAITING_SECURE_CONFIRM" or "DRAINING") or "COMPLETED",
        outcome = lease and nil or "SUCCEEDED",
        reason = reason,
        startedAt = now(self),
        finishedAt = lease and nil or now(self),
    }
    if not lease then
        notifyDrain(self)
        return self.drain.drainId, self.drain
    end
    if lease.callbacks and type(lease.callbacks.onDrain) == "function" then
        Mail:SafeCall(lease.callbacks.onDrain, reason, lease, self.drain)
    end
    self.drainTimer = scheduleTimeout(self, function()
        if not self.current or not self.drain or self.drain.phase == "COMPLETED" then return end
        local outcome
        if not self.current.attempt then
            outcome = "CANCELLED"
        elseif self.current.ownerKind == "INBOX_QUEUE" or self.current.ownerKind == "ATTACHMENT" then
            outcome = "INDETERMINATE"
        else
            outcome = "UNKNOWN"
        end
        local timedOutLease = self.current
        local timeoutError = Mail:NewError("DRAIN_TIMEOUT", "等待当前邮件操作结束超时。")
        if timedOutLease.callbacks and type(timedOutLease.callbacks.onDrainTimeout) == "function" then
            Mail:SafeCall(timedOutLease.callbacks.onDrainTimeout,
                outcome, timeoutError, timedOutLease, self.drain)
        end
        if self.current == timedOutLease then
            self:Release(timedOutLease, outcome, timeoutError)
        end
    end)
    return self.drain.drainId, self.drain
end

function Arbiter:Release(lease, outcome, err)
    if lease ~= self.current or lease.released then
        return nil, Mail:NewError("INVALID_MAIL_LEASE", "邮件写入租约已失效。")
    end
    lease.released = true
    self.current = nil
    if outcome == "UNKNOWN" or outcome == "INDETERMINATE" then
        local family = ownerFamily(lease.ownerKind)
        self.quarantines[family] = {
            ownerId = lease.ownerId,
            ownerKind = lease.ownerKind,
            sessionGeneration = lease.sessionGeneration,
            outcome = outcome,
            releasedAt = now(self),
        }
    end
    refreshNativeSendButton(self)
    if self.drain and self.drain.phase ~= "COMPLETED" then
        if self.drainTimer and type(self.drainTimer.Cancel) == "function" then self.drainTimer:Cancel() end
        self.drain.phase = "COMPLETED"
        self.drain.outcome = outcome or (lease.attempt and "UNKNOWN" or "CANCELLED")
        self.drain.error = err
        self.drain.finishedAt = now(self)
        notifyDrain(self)
    end
    return true
end

function Arbiter:CanResetDatabase()
    local owner = self:GetOwner()
    if owner then
        return nil, Mail:NewError("MAIL_WRITE_BUSY",
            "当前有邮件操作正在进行，请等待操作结束后再重置插件。", owner)
    end
    return true
end

function Arbiter:GetQuarantine(ownerKind)
    local quarantine = self.quarantines[ownerFamily(ownerKind)]
    if not quarantine then return nil end
    local copy = {}
    for key, value in pairs(quarantine) do copy[key] = value end
    return copy
end

function Arbiter:ResetDrain()
    if self.current then
        return nil, Mail:NewError("MAIL_WRITE_BUSY", "仍有邮件写操作，无法恢复准入。")
    end
    if self.drain and self.drain.phase ~= "COMPLETED" then
        return nil, Mail:NewError("MAIL_WRITE_DRAINING", "邮件写操作尚未完成收敛。")
    end
    self.drain = nil
    self.drainTimer = nil
    self.accepting = true
    return true
end

Mail.MailWriteArbiter = Arbiter
Mail.WriteArbiter = Mail.WriteArbiter or Arbiter.New()
