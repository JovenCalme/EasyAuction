local _, ns = ...
ns = type(ns) == "table" and ns or {}
ns.Mail = type(ns.Mail) == "table" and ns.Mail or {}

local Mail = ns.Mail
local Queue = {}
Queue.__index = Queue

local TERMINAL_STATES = {
    SUCCEEDED = true,
    FAILED = true,
    CANCELLED = true,
    INDETERMINATE = true,
}

local function makeError(code, message, retryable, sourceKey, rawEvent)
    return {
        code = code,
        message = message,
        retryable = retryable == true,
        sourceKey = sourceKey,
        rawEvent = rawEvent,
    }
end

local function defaultClock()
    if _G and type(_G.GetTime) == "function" then return _G.GetTime() end
    if os and type(os.clock) == "function" then return os.clock() end
    return 0
end

local function defaultSchedule(delay, callback)
    if _G and _G.C_Timer and type(_G.C_Timer.After) == "function" then
        _G.C_Timer.After(delay, callback)
    end
end

local function copySource(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        copy[key] = value
    end
    if type(source and source.mailKey) == "table" then
        copy.mailKey = {
            fingerprint = source.mailKey.fingerprint,
            duplicateOrdinal = source.mailKey.duplicateOrdinal,
        }
    end
    return copy
end

local function compareCommands(left, right)
    local leftMail = tonumber(left.mailIndex) or 0
    local rightMail = tonumber(right.mailIndex) or 0
    if leftMail ~= rightMail then return leftMail > rightMail end
    local leftAttachment = tonumber(left.attachmentIndex) or 0
    local rightAttachment = tonumber(right.attachmentIndex) or 0
    if leftAttachment ~= rightAttachment then return leftAttachment > rightAttachment end
    return tostring(left.sourceKey) > tostring(right.sourceKey)
end

local function operationView(operation)
    if not operation then return nil end
    local current = operation.commands and operation.commands[operation.commandIndex]
    return {
        operationId = operation.id,
        state = operation.state,
        error = operation.error,
        currentSourceKey = current and current.sourceKey or nil,
        completedCount = operation.completedCount,
        totalCount = operation.commands and #operation.commands or 0,
        attemptCount = current and current.attemptCount or 0,
        dispatched = current and current.dispatched == true or false,
        createdAt = operation.createdAt,
        finishedAt = operation.finishedAt,
    }
end

local function extractSources(entryOrSources)
    if type(entryOrSources) ~= "table" then return nil end
    if type(entryOrSources.sourceKey) == "string" then return { entryOrSources } end
    if type(entryOrSources.sources) == "table" then return entryOrSources.sources end
    if #entryOrSources > 0 then return entryOrSources end
    return nil
end

local function retryableError(errorObject)
    return type(errorObject) == "table" and errorObject.retryable == true
end

function Queue.New(deps)
    deps = deps or {}
    return setmetatable({
        repository = deps.repository,
        compat = deps.compat,
        arbiter = deps.arbiter,
        clock = deps.clock or defaultClock,
        schedule = deps.schedule or defaultSchedule,
        timeoutSeconds = tonumber(deps.timeoutSeconds) or 5,
        maxRetries = math.max(0, math.floor(tonumber(deps.maxRetries) or 2)),
        sessionGeneration = deps.sessionGeneration,
        isSessionOpen = deps.isSessionOpen,
        onChanged = deps.onChanged,
        markRead = deps.markRead == true,
        operations = {},
        pendingIds = {},
        activeId = nil,
        nextId = 0,
        accepting = true,
        draining = false,
        resumeRequested = false,
        processingBlocked = false,
        timerToken = 0,
    }, Queue)
end

function Queue:Configure(deps)
    deps = deps or {}
    self.repository = deps.repository or self.repository
    self.compat = deps.compat or self.compat
    self.arbiter = deps.arbiter or self.arbiter
    self.clock = deps.clock or self.clock or defaultClock
    self.schedule = deps.schedule or self.schedule or defaultSchedule
    self.timeoutSeconds = tonumber(deps.timeoutSeconds) or self.timeoutSeconds or 5
    if deps.maxRetries ~= nil then
        self.maxRetries = math.max(0, math.floor(tonumber(deps.maxRetries) or 0))
    end
    self.sessionGeneration = deps.sessionGeneration or self.sessionGeneration
    self.isSessionOpen = deps.isSessionOpen or self.isSessionOpen
    self.onChanged = deps.onChanged or self.onChanged
    if deps.markRead ~= nil then self.markRead = deps.markRead == true end
    self.operations = self.operations or {}
    self.pendingIds = self.pendingIds or {}
    if self.accepting == nil then self.accepting = true end
    return self
end

function Queue:_repository()
    return self.repository or Mail.InboxRepository
end

function Queue:_compat()
    return self.compat or Mail.Compat
end

function Queue:_arbiter()
    return self.arbiter or Mail.WriteArbiter
end

function Queue:_now()
    return (self.clock or defaultClock)()
end

function Queue:_generation()
    if type(self.sessionGeneration) == "function" then
        return self.sessionGeneration()
    end
    return tonumber(self.sessionGeneration) or 0
end

function Queue:_sessionIsOpen()
    if type(self.isSessionOpen) == "function" then
        return self.isSessionOpen() == true
    end
    return true
end

function Queue:_commandPending()
    local compat = self:_compat()
    if type(compat) ~= "table" or type(compat.IsCommandPending) ~= "function" then
        return false
    end
    local ok, pending = pcall(compat.IsCommandPending, compat)
    if not ok then
        return nil, makeError("COMMAND_STATUS_FAILED",
            "无法确认邮件服务器命令状态", true, nil, pending)
    end
    return pending == true
end

function Queue:_notify(operation)
    local view = operationView(operation)
    if type(self.onChanged) == "function" then self.onChanged(view) end
    if type(Mail.Publish) == "function" then
        Mail:Publish("MAIL_OPERATION_CHANGED", view)
    end
end

function Queue:_newOperationId()
    self.nextId = (self.nextId or 0) + 1
    return "inbox-operation-" .. tostring(self.nextId)
end

function Queue:Enqueue(entryOrSources, mode)
    mode = mode or "all_sources"
    if mode ~= "all_sources" and mode ~= "one_source" then
        return nil, makeError("INVALID_MODE", "不支持的收件操作模式")
    end
    if self.accepting == false then
        return nil, makeError("QUEUE_NOT_ACCEPTING", "收件队列正在关闭")
    end

    local sourceList = extractSources(entryOrSources)
    if not sourceList or #sourceList == 0 then
        return nil, makeError("SOURCE_MISSING", "没有可领取的邮件来源")
    end

    local commands = {}
    for index = 1, #sourceList do
        local source = sourceList[index]
        if type(source) ~= "table" or type(source.sourceKey) ~= "string"
            or (source.kind ~= "item" and source.kind ~= "money") then
            return nil, makeError("INVALID_SOURCE", "邮件来源结构无效")
        end
        if source.isCOD == true or (tonumber(source.cod) or 0) > 0 then
            return nil, makeError("COD_REQUIRES_CONFIRMATION",
                "付款取件邮件必须在原生邮件详情中确认", false, source.sourceKey)
        end
        commands[#commands + 1] = copySource(source)
    end
    table.sort(commands, compareCommands)
    if mode == "one_source" then
        commands = { commands[1] }
    end

    local operationId = self:_newOperationId()
    local operation = {
        id = operationId,
        state = "QUEUED",
        mode = mode,
        commands = commands,
        commandIndex = 1,
        completedCount = 0,
        createdAt = self:_now(),
        error = nil,
        lease = nil,
    }
    self.operations[operationId] = operation
    self.pendingIds[#self.pendingIds + 1] = operationId
    self:_notify(operation)
    self:_processNext()
    return operationId
end

function Queue:_acquire(operation)
    local arbiter = self:_arbiter()
    if type(arbiter) ~= "table" or type(arbiter.Acquire) ~= "function" then
        return nil, makeError("MISSING_DEPENDENCY", "InboxOperationQueue 缺少 MailWriteArbiter")
    end
    local commandPending, pendingError = self:_commandPending()
    if commandPending == nil then return nil, pendingError end
    if commandPending then
        return nil, makeError("OUTBOUND_BUSY", "邮件服务器仍在处理上一项操作", true)
    end
    local repository = self:_repository()
    if type(repository) ~= "table" or type(repository.Snapshot) ~= "function" then
        return nil, makeError("MISSING_DEPENDENCY", "InboxOperationQueue 缺少 InboxRepository")
    end
    local barrier, barrierError = repository:Snapshot()
    if not barrier then return nil, barrierError end
    operation.preflightSnapshot = barrier
    return arbiter:Acquire("INBOX_QUEUE", operation.id, self:_generation(), {
        onDrain = function(reason)
            if self.operations[operation.id] == operation and not TERMINAL_STATES[operation.state] then
                self:BeginDrain(reason or "ARBITER_DRAIN")
            end
        end,
        onDrainTimeout = function(_, drainError)
            if self.operations[operation.id] == operation and not TERMINAL_STATES[operation.state] then
                self:_finish(operation, "INDETERMINATE", drainError
                    or makeError("DRAIN_TIMEOUT", "关闭邮箱模块时无法确认领取结果"))
            end
        end,
    })
end

function Queue:_release(operation)
    if not operation.lease then return end
    local arbiter = self:_arbiter()
    if type(arbiter) == "table" and type(arbiter.Release) == "function" then
        arbiter:Release(operation.lease, operation.state, operation.error)
    end
    operation.lease = nil
end

function Queue:_processNext()
    if self.processingBlocked or self.activeId then return end
    while #self.pendingIds > 0 do
        local operationId = table.remove(self.pendingIds, 1)
        local operation = self.operations[operationId]
        if operation and operation.state == "QUEUED" then
            self.activeId = operationId
            local lease, leaseError = self:_acquire(operation)
            if not lease then
                self:_finish(operation, "FAILED", leaseError
                    or makeError("MAIL_WRITE_BUSY", "无法取得邮箱写通道"))
            else
                operation.lease = lease
                self:_dispatchCurrent(operation)
            end
            return
        end
    end
end

function Queue:_setState(operation, state, errorObject)
    operation.state = state
    operation.error = errorObject
    self:_notify(operation)
end

function Queue:_finish(operation, state, errorObject)
    self.timerToken = (self.timerToken or 0) + 1
    operation.state = state
    operation.error = errorObject
    operation.finishedAt = self:_now()
    self:_release(operation)
    if self.activeId == operation.id then self.activeId = nil end
    self:_notify(operation)
    if self.draining and self.resumeRequested then
        self.accepting = true
        self.draining = false
        self.resumeRequested = false
    end
    self:_processNext()
end

function Queue:_scheduleTimeout(operation, command)
    self.timerToken = (self.timerToken or 0) + 1
    local token = self.timerToken
    local schedule = self.schedule or defaultSchedule
    schedule(self.timeoutSeconds, function()
        if token ~= self.timerToken then return end
        if self.activeId ~= operation.id or operation.commands[operation.commandIndex] ~= command then return end
        self:Tick()
    end)
end

function Queue:_resolve(command, snapshot)
    local repository = self:_repository()
    if type(repository) ~= "table" or type(repository.Snapshot) ~= "function"
        or type(repository.ResolveSource) ~= "function" then
        return nil, makeError("MISSING_DEPENDENCY", "InboxOperationQueue 缺少 InboxRepository")
    end
    if not snapshot then
        local snapshotError
        snapshot, snapshotError = repository:Snapshot()
        if not snapshot then return nil, snapshotError end
    end
    return repository:ResolveSource(command.sourceKey, snapshot)
end

local function identityMatches(expected, actual)
    if expected.kind ~= actual.kind then return false end
    if expected.kind == "item" and expected.itemKey ~= nil
        and actual.itemKey ~= expected.itemKey then
        return false
    end
    if expected.mailKey and actual.mailKey then
        if expected.mailKey.fingerprint ~= actual.mailKey.fingerprint
            or expected.mailKey.duplicateOrdinal ~= actual.mailKey.duplicateOrdinal then
            return false
        end
    end
    return true
end

function Queue:_dispatchCurrent(operation)
    if TERMINAL_STATES[operation.state] then return end
    if not self:_sessionIsOpen() then
        self:_finish(operation, "FAILED", makeError("MAIL_CLOSED", "邮箱会话已关闭"))
        return
    end

    local command = operation.commands[operation.commandIndex]
    if not command then
        self:_finish(operation, "SUCCEEDED")
        return
    end
    if command.dispatched then
        self:_setState(operation, "AWAITING_ACK")
        return
    end

    self:_setState(operation, "RESOLVING")
    local directIndex = operation.mode == "all_sources"
        and type(command.mailIndex) == "number" and command.mailIndex > 0
    local resolved, resolveError
    if directIndex then
        resolved = command
        operation.preflightSnapshot = nil
    else
        resolved, resolveError = self:_resolve(command, operation.preflightSnapshot)
        operation.preflightSnapshot = nil
        if not resolved then
            if command.dispatched and resolveError and resolveError.code == "SOURCE_MISSING" then
                self:_completeCommand(operation)
            else
                self:_finish(operation, "FAILED", resolveError
                    or makeError("SOURCE_MISSING", "邮件来源已不存在", false, command.sourceKey))
            end
            return
        end
    end
    if not directIndex and not identityMatches(command, resolved) then
        self:_finish(operation, "FAILED",
            makeError("MAIL_MOVED", "执行前复核发现邮件身份已变化", false, command.sourceKey))
        return
    end
    if resolved.isCOD == true or (tonumber(resolved.cod) or 0) > 0 then
        self:_finish(operation, "FAILED", makeError("COD_REQUIRES_CONFIRMATION",
            "付款取件邮件必须在原生邮件详情中确认", false, command.sourceKey))
        return
    end

    local compat = self:_compat()
    if type(compat) ~= "table" then
        self:_finish(operation, "FAILED", makeError("MISSING_DEPENDENCY", "缺少 MailCompat"))
        return
    end
    if operation.mode ~= "all_sources" or operation.completedCount == 0 then
        local commandPending, pendingError = self:_commandPending()
        if commandPending == nil then
            pendingError.sourceKey = command.sourceKey
            self:_finish(operation, "FAILED", pendingError)
            return
        end
        if commandPending then
            self:_finish(operation, "FAILED", makeError(
                "OUTBOUND_BUSY", "邮件服务器仍在处理上一项操作", true,
                command.sourceKey))
            return
        end
    end

    command.mailIndex = resolved.mailIndex
    command.attachmentIndex = resolved.attachmentIndex
    command.attemptCount = (command.attemptCount or 0) + 1
    command.attemptNonce = operation.id .. ":" .. tostring(operation.commandIndex)
        .. ":" .. tostring(command.attemptCount)
    self:_setState(operation, "REQUESTING")

    local arbiter = self:_arbiter()
    if type(arbiter.SetAttempt) == "function" then
        local attemptOk, attemptError = arbiter:SetAttempt(operation.lease, {
            operationId = operation.id,
            sourceKey = command.sourceKey,
            attemptNonce = command.attemptNonce,
            kind = command.kind,
        })
        if attemptOk == false or attemptOk == nil then
            self:_finish(operation, "FAILED", attemptError
                or makeError("LEASE_MISMATCH", "无法登记收件写入尝试", false, command.sourceKey))
            return
        end
    end

    if self.markRead and type(compat.MarkRead) == "function" then
        compat:MarkRead(resolved.mailIndex)
    end

    -- Titan 可能在 TakeInbox* 返回前同步派发 ITEM_PUSH/PLAYER_MONEY。
    -- 先登记已提交，才能在这个调用窗口内接住确认事件；API 明确拒绝时再撤销。
    command.dispatched = true

    local callOk, accepted, apiError
    if command.kind == "item" and type(compat.TakeItem) == "function" then
        callOk, accepted, apiError = pcall(compat.TakeItem, compat,
            resolved.mailIndex, resolved.attachmentIndex)
    elseif command.kind == "money" and type(compat.TakeMoney) == "function" then
        callOk, accepted, apiError = pcall(compat.TakeMoney, compat, resolved.mailIndex)
    else
        self:_finish(operation, "FAILED", makeError("MISSING_DEPENDENCY", "缺少收件写 API"))
        return
    end

    if self.activeId ~= operation.id or operation.commands[operation.commandIndex] ~= command then
        return
    end
    if not callOk then
        command.dispatched = false
        self:_finish(operation, "FAILED",
            makeError("API_REJECTED", "收件 API 调用异常", false, command.sourceKey, accepted))
        return
    end
    if accepted ~= true then
        command.dispatched = false
        local structured = type(apiError) == "table" and apiError
            or makeError("API_REJECTED", "收件 API 拒绝请求", false, command.sourceKey, apiError)
        if retryableError(structured) and command.attemptCount <= self.maxRetries then
            self:_setState(operation, "RETRY_WAIT", structured)
            self:_dispatchCurrent(operation)
        else
            self:_finish(operation, "FAILED", structured)
        end
        return
    end

    command.deadline = self:_now() + self.timeoutSeconds
    self:_setState(operation, "AWAITING_ACK")
    self:_scheduleTimeout(operation, command)
end

function Queue:_completeCommand(operation)
    local command = operation.commands[operation.commandIndex]
    if command then command.confirmed = true end
    operation.completedCount = operation.completedCount + 1
    operation.commandIndex = operation.commandIndex + 1
    if operation.commandIndex > #operation.commands then
        self:_finish(operation, "SUCCEEDED")
    elseif self.draining then
        self:_finish(operation, "CANCELLED",
            makeError("MODULE_DRAINED", "当前领取已确认，其余未提交来源已取消"))
    else
        self:_setState(operation, "REFRESHING")
        self:_dispatchCurrent(operation)
    end
end

function Queue:_confirmCurrent(operation)
    local command = operation.commands[operation.commandIndex]
    if not command or not command.dispatched then return false end
    local resolved, resolveError = self:_resolve(command)
    if not resolved and resolveError and resolveError.code == "SOURCE_MISSING" then
        self:_completeCommand(operation)
        return true
    end
    return false
end

function Queue:_explicitFailure(operation, errorObject)
    local command = operation.commands[operation.commandIndex]
    if not command then return end
    errorObject = errorObject or makeError("API_REJECTED", "收件操作失败")
    errorObject.sourceKey = errorObject.sourceKey or command.sourceKey
    self:_finish(operation, "FAILED", errorObject)
end

function Queue:OnWoWEvent(event, ...)
    if event == "MAIL_CLOSED" then
        self:BeginDrain("MAIL_CLOSED")
        return true
    end

    local operation = self.activeId and self.operations[self.activeId]
    if not operation or (operation.state ~= "AWAITING_ACK"
        and operation.state ~= "REQUESTING") then return false end
    local command = operation.commands[operation.commandIndex]
    if not command or not command.dispatched then return false end

    local arbiter = self:_arbiter()
    local ack
    if type(arbiter) == "table" and type(arbiter.RouteEvent) == "function" then
        ack = arbiter:RouteEvent(event, ...)
    end
    if type(ack) == "table" then
        if ack.operationId and ack.operationId ~= operation.id then return false end
        local ackFailed = ack.success == false or ack.state == "FAILED" or ack.outcome == "FAILED"
        if ackFailed then
            self:_explicitFailure(operation, ack.error
                or makeError("API_REJECTED", "收件操作收到失败确认", false, command.sourceKey, ack))
            return true
        end
    end

    if event == "UI_ERROR_MESSAGE" then
        local compat = self:_compat()
        local normalized
        if type(compat) == "table" and type(compat.NormalizeUIError) == "function" then
            normalized = compat:NormalizeUIError(...)
        end
        if normalized and normalized.code ~= "UNKNOWN" then
            self:_explicitFailure(operation, normalized)
            return true
        end
        return false
    elseif event == "MAIL_FAILED" then
        local compat = self:_compat()
        local normalized
        if type(compat) == "table" and type(compat.NormalizeUIError) == "function" then
            normalized = compat:NormalizeUIError(...)
        end
        if not normalized or normalized.code == "UNKNOWN" then
            normalized = makeError("API_REJECTED", "收件操作收到 MAIL_FAILED", false,
                command.sourceKey, { ... })
        end
        self:_explicitFailure(operation, normalized)
        return true
    elseif (event == "ITEM_PUSH" and command.kind == "item")
        or (event == "PLAYER_MONEY" and command.kind == "money") then
        -- InboxMailBag 以这两个客户端事件作为 TakeInbox* 的完成信号，
        -- 不等待邮件列表重新扫描后才确认来源消失；Titan 的刷新时序下必须如此才能连续领取。
        self:_completeCommand(operation)
        return true
    end
    return false
end

function Queue:Tick(now)
    local operation = self.activeId and self.operations[self.activeId]
    if not operation or operation.state ~= "AWAITING_ACK" then return false end
    local command = operation.commands[operation.commandIndex]
    now = tonumber(now) or self:_now()
    if not command.deadline or now < command.deadline then return false end

    if self:_confirmCurrent(operation) then return true end
    if self.activeId ~= operation.id or operation.state ~= "AWAITING_ACK" then return true end
    self:_finish(operation, "INDETERMINATE",
        makeError("RESULT_INDETERMINATE", "已提交领取请求，但无法确认最终结果",
            false, command.sourceKey))
    return true
end

function Queue:GetState(operationId)
    return operationView(self.operations and self.operations[operationId])
end

function Queue:Cancel(operationId, reason)
    local operation = self.operations and self.operations[operationId]
    if not operation or TERMINAL_STATES[operation.state] then return false end
    reason = reason or "USER_CANCELLED"

    if self.activeId ~= operationId then
        self:_finish(operation, "CANCELLED",
            makeError("CANCELLED", "收件操作已取消", false, nil, reason))
        return true
    end

    local command = operation.commands[operation.commandIndex]
    if command and command.dispatched then
        if self:_confirmCurrent(operation) then
            if TERMINAL_STATES[operation.state] then return true end
        end
        if not TERMINAL_STATES[operation.state] then
            self:_finish(operation, "INDETERMINATE",
                makeError("RESULT_INDETERMINATE", "取消时无法确认已提交领取请求的结果",
                    false, command.sourceKey, reason))
        end
    else
        self:_finish(operation, "CANCELLED",
            makeError("CANCELLED", "收件操作已取消", false, command and command.sourceKey, reason))
    end
    return true
end

function Queue:CancelAll(reason)
    self.processingBlocked = true
    local pending = self.pendingIds or {}
    self.pendingIds = {}
    for index = 1, #pending do
        local operation = self.operations[pending[index]]
        if operation and not TERMINAL_STATES[operation.state] then
            self:_finish(operation, "CANCELLED",
                makeError("CANCELLED", "收件操作已取消", false, nil, reason))
        end
    end
    local activeId = self.activeId
    if activeId then self:Cancel(activeId, reason) end
    self.processingBlocked = false
end

function Queue:BeginDrain(reason)
    self.accepting = false
    self.draining = true
    self.processingBlocked = true
    local pending = self.pendingIds or {}
    self.pendingIds = {}
    for index = 1, #pending do
        local operation = self.operations[pending[index]]
        if operation and not TERMINAL_STATES[operation.state] then
            self:_finish(operation, "CANCELLED",
                makeError("CANCELLED", "收件操作尚未提交，已在模块关闭时取消",
                    false, nil, reason))
        end
    end
    local active = self.activeId and self.operations[self.activeId]
    if active and not TERMINAL_STATES[active.state] then
        local command = active.commands[active.commandIndex]
        if command and command.dispatched then
            self:_confirmCurrent(active)
        else
            self:_finish(active, "CANCELLED",
                makeError("CANCELLED", "收件操作尚未提交，已在模块关闭时取消",
                    false, command and command.sourceKey, reason))
        end
    end
    self.processingBlocked = false
    return true
end

function Queue:BeginDisable()
    self.accepting = false
    self.resumeRequested = false
    return true
end

function Queue:SetAccepting(accepting)
    accepting = accepting == true
    if accepting and self.draining and self.activeId then
        self.resumeRequested = true
        return false
    end
    self.accepting = accepting
    if self.accepting then
        self.draining = false
        self.resumeRequested = false
    end
    if self.accepting then self:_processNext() end
end

function Queue:Enable()
    self:SetAccepting(true)
end

function Queue:Disable(reason)
    return self:BeginDrain(reason or "MODULE_DISABLED")
end

function Queue:Shutdown(reason)
    self:BeginDrain(reason or "MODULE_SHUTDOWN")
    self.timerToken = (self.timerToken or 0) + 1
end

Queue.repository = nil
Queue.compat = nil
Queue.arbiter = nil
Queue.clock = defaultClock
Queue.schedule = defaultSchedule
Queue.timeoutSeconds = 5
Queue.maxRetries = 2
Queue.operations = {}
Queue.pendingIds = {}
Queue.activeId = nil
Queue.nextId = 0
Queue.accepting = true
Queue.draining = false
Queue.resumeRequested = false
Queue.processingBlocked = false
Queue.timerToken = 0

Mail.InboxOperationQueue = Queue

return Queue
