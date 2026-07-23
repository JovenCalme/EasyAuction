local _, ns = ...
local Mail = ns.Mail

local Session = {}
Session.__index = Session

function Session.New(deps)
    return setmetatable({
        deps = deps or {},
        consumers = {},
        enabled = false,
        open = false,
        runtimeGeneration = 0,
        sessionGeneration = 0,
    }, Session)
end

function Session:_compat()
    return self.deps.compat or Mail.Compat
end

function Session:_publish(eventName, payload)
    if type(self.deps.publish) == "function" then
        self.deps.publish(eventName, payload)
    else
        Mail:Publish(eventName, payload)
    end
end

function Session:Register(owner, callbacks)
    if owner == nil or type(callbacks) ~= "table" then
        return nil, Mail:NewError("INVALID_SESSION_CONSUMER", "邮箱会话监听参数无效。")
    end
    self.consumers[owner] = callbacks
    if self.open and type(callbacks.OnStart) == "function" then
        Mail:SafeCall(callbacks.OnStart, {
            generation = self.sessionGeneration,
            runtimeGeneration = self.runtimeGeneration,
            reason = "REGISTER_WHILE_OPEN",
        })
    end
    return true
end

function Session:Unregister(owner)
    self.consumers[owner] = nil
end

function Session:IsOpen()
    return self.open == true
end

function Session:GetGeneration()
    return self.sessionGeneration
end

function Session:GetRuntimeGeneration()
    return self.runtimeGeneration
end

function Session:Start(reason)
    if not self.enabled then
        return nil, Mail:NewError("MAIL_SESSION_DISABLED", "邮箱会话层尚未启用。")
    end
    if self.open then return true end
    self.open = true
    self.sessionGeneration = self.sessionGeneration + 1
    local payload = {
        generation = self.sessionGeneration,
        runtimeGeneration = self.runtimeGeneration,
        reason = reason or "MAIL_OPEN",
    }
    for _, callbacks in pairs(self.consumers) do
        if type(callbacks.OnStart) == "function" then Mail:SafeCall(callbacks.OnStart, payload) end
    end
    self:_publish("MAIL_SESSION_STARTED", payload)
    return true
end

function Session:Stop(reason)
    if not self.open then return true end
    self.open = false
    local payload = {
        generation = self.sessionGeneration,
        runtimeGeneration = self.runtimeGeneration,
        reason = reason or "MAIL_CLOSED",
    }
    for _, callbacks in pairs(self.consumers) do
        if type(callbacks.OnStop) == "function" then Mail:SafeCall(callbacks.OnStop, payload) end
    end
    self:_publish("MAIL_SESSION_ENDED", payload)
    return true
end

function Session:CancelOwnedOperations(reason)
    local count = 0
    for _, callbacks in pairs(self.consumers) do
        local callback = callbacks.Cancel or callbacks.CancelOwnedOperations
        if type(callback) == "function" then
            Mail:SafeCall(callback, reason or "SESSION_STOPPED")
            count = count + 1
        end
    end
    return count
end

function Session:OnWoWEvent(event, ...)
    if not self.enabled then return end
    if event == "MAIL_INBOX_UPDATE" or event == "MAIL_SUCCESS" or event == "BAG_UPDATE_DELAYED" then
        local payload = {
            generation = self.sessionGeneration,
            runtimeGeneration = self.runtimeGeneration,
            cause = event,
        }
        self:_publish("MAIL_INBOX_DIRTY", payload)
        for _, callbacks in pairs(self.consumers) do
            if type(callbacks.OnInboxDirty) == "function" then
                Mail:SafeCall(callbacks.OnInboxDirty, payload)
            end
        end
    elseif event == "SEND_MAIL_MONEY_CHANGED" or event == "MAIL_SEND_INFO_UPDATE" then
        self:_publish("MAIL_DRAFT_CHANGED", {
            generation = self.sessionGeneration,
            runtimeGeneration = self.runtimeGeneration,
            fields = { event = event, raw = { ... } },
        })
    end
end

function Session:Enable(context)
    if self.enabled then return true end
    self.enabled = true
    self.runtimeGeneration = context and context.generation or self.runtimeGeneration
    local compat = self:_compat()
    if compat then
        compat:RegisterMailLifecycle(self,
            function(reason) self:Start(reason) end,
            function(reason) self:Stop(reason) end)
        compat:RegisterEventListener(self, function(event, ...)
            self:OnWoWEvent(event, ...)
        end)
        if compat:IsMailOpen() then self:Start("ALREADY_OPEN") end
    end
    return true
end

function Session:Disable(reason)
    if not self.enabled then return true end
    self:CancelOwnedOperations(reason or "MODULE_DISABLED")
    self:Stop(reason or "MODULE_DISABLED")
    local compat = self:_compat()
    if compat then compat:UnregisterOwner(self) end
    self.enabled = false
    return true
end

Mail.MailSession = Session
Mail.Session = Mail.Session or Session.New()
Mail:RegisterRuntimeModule("session", Mail.Session, 20)
