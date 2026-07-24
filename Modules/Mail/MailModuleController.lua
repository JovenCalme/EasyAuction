local _, ns = ...
local Mail = ns.Mail

local Controller = {}
Controller.__index = Controller

local S = Mail.RuntimeState

function Controller.New(deps)
    local self = setmetatable({
        deps = deps or {},
        state = S.UNINITIALIZED,
        generation = 0,
        enabledModules = {},
        activeDrainId = nil,
        stateReason = nil,
        conflictDecision = nil,
        beginningDrain = false,
    }, Controller)
    local arbiter = self:_arbiter()
    if arbiter and arbiter.SubscribeDrain then
        arbiter:SubscribeDrain(self, function(drainState)
            if self.beginningDrain then return end
            if self.state == S.DISABLING and drainState.phase == "COMPLETED" then
                self:_finishDisable(drainState)
            end
        end)
    end
    return self
end

function Controller:_arbiter()
    return self.deps.arbiter or Mail.WriteArbiter
end

function Controller:_runtimeModules()
    return self.deps.runtimeModules or Mail:GetRuntimeModules()
end

function Controller:_desiredEnabled()
    if type(self.deps.desiredEnabled) == "function" then return self.deps.desiredEnabled() == true end
    -- 注意：不能写成 Mail.Config and Mail.Config:GetEnabled() or true，
    -- GetEnabled() 为 false 时会被 or true 吞掉，导致已禁用的配置被当成启用。
    if not Mail.Config then return true end
    return Mail.Config:GetEnabled() == true
end

function Controller:_rolloutEnabled()
    if type(self.deps.rolloutEnabled) == "function" then return self.deps.rolloutEnabled() == true end
    return Mail.ROLLOUT_ENABLED == true
end

function Controller:_conflictDetector()
    return self.deps.conflictDetector or Mail.ConflictDetector
end

function Controller:_setState(state, reason, drainId)
    self.state = state
    self.stateReason = reason
    Mail:Publish("MAIL_MODULE_STATE_CHANGED", {
        desiredEnabled = self:_desiredEnabled(),
        runtimeState = state,
        reason = reason,
        generation = self.generation,
        drainId = drainId,
    })
end

function Controller:Initialize()
    if self.state ~= S.UNINITIALIZED then return self.state end
    self:_setState(S.DISABLED, "INITIALIZED")
    local arbiter = self:_arbiter()
    if arbiter and arbiter.BeginDrain then arbiter:BeginDrain("MODULE_DISABLED") end
    return self.state
end

function Controller:GetState()
    return self.state
end

function Controller:GetGeneration()
    return self.generation
end

function Controller:IsRuntimeEnabled()
    return self.state == S.ENABLED
end

function Controller:GetConflictDecision()
    return self.conflictDecision
end

function Controller:RequestEnable(reason)
    self:Initialize()
    if self.state == S.DISABLING or self.state == S.ENABLING then
        return nil, Mail:NewError("MODULE_TRANSITION_BUSY", "邮箱模块正在切换状态，请稍后重试。")
    end
    if not self:_desiredEnabled() then
        if self.state == S.ENABLED then self:Disable(reason or "DESIRED_DISABLED") end
        return self.state
    end
    if not self:_rolloutEnabled() then
        self:_setState(S.DISABLED_ROLLOUT, reason or "ROLLOUT_DISABLED")
        return self.state
    end
    local detector = self:_conflictDetector()
    if reason == "PLAYER_LOGIN" and detector then
        local snapshot = detector:Snapshot()
        if detector:ShouldPrompt(snapshot, true, true) then
            self:_setState(S.WAITING_CONFLICT_DECISION, reason)
            Mail:Publish("MAIL_EXTERNAL_CONFLICT_DETECTED", snapshot)
            return self.state
        end
    end
    local ok, err = self:Enable(reason or "REQUEST_ENABLE")
    if not ok then return nil, err end
    return self.state
end

local function invokeRuntime(entry, method, context)
    local module = entry and entry.module
    if not module or type(module[method]) ~= "function" then return true end
    local result = { pcall(module[method], module, context) }
    if not result[1] then
        return nil, Mail:NewError("RUNTIME_MODULE_FAILED", "邮箱运行模块执行失败。", {
            module = entry.id,
            method = method,
            cause = tostring(result[2]),
        })
    end
    if result[2] == nil and type(result[3]) == "table" and result[3].code then
        return nil, result[3]
    end
    if result[2] == false then
        return nil, result[3] or Mail:NewError("RUNTIME_MODULE_REJECTED", "邮箱运行模块拒绝切换。", {
            module = entry.id,
            method = method,
        })
    end
    return true
end

function Controller:SetRuntimeModuleEnabled(id, enabled, reason)
    if type(enabled) ~= "boolean" then
        return nil, Mail:NewError("INVALID_ENABLED_VALUE", "邮箱运行模块开关必须是 boolean。")
    end
    if not self:IsRuntimeEnabled() then return true end
    local entry
    local modules = self:_runtimeModules()
    for index = 1, #modules do
        if modules[index].id == id then entry = modules[index] break end
    end
    if not entry then
        return nil, Mail:NewError("MAIL_RUNTIME_MODULE_NOT_FOUND", "找不到邮箱运行模块。", { id = id })
    end
    local context = {
        generation = self.generation,
        reason = reason or "SETTINGS",
        controller = self,
    }
    if enabled then return invokeRuntime(entry, "Enable", context) end
    local stopped, stopError = invokeRuntime(entry, "BeginDisable", context)
    if not stopped then return nil, stopError end
    return invokeRuntime(entry, "Disable", context)
end

function Controller:Enable(reason)
    self:Initialize()
    if self.state == S.ENABLED then return true end
    if self.state == S.ENABLING or self.state == S.DISABLING then
        return nil, Mail:NewError("MODULE_TRANSITION_BUSY", "邮箱模块正在切换状态，请稍后重试。")
    end
    if not self:_rolloutEnabled() then
        self:_setState(S.DISABLED_ROLLOUT, reason or "ROLLOUT_DISABLED")
        return nil, Mail:NewError("MAIL_ROLLOUT_DISABLED", "当前构建尚未启用邮箱模块。")
    end
    if self.generation == 0 then self.generation = 1 end
    local arbiter = self:_arbiter()
    if arbiter then
        local reset, resetError = arbiter:ResetDrain()
        if not reset then return nil, resetError end
    end
    self:_setState(S.ENABLING, reason)
    self.enabledModules = {}
    local modules = self:_runtimeModules()
    local context = { generation = self.generation, reason = reason, controller = self }
    for i = 1, #modules do
        local entry = modules[i]
        local ok, err = invokeRuntime(entry, "Enable", context)
        if not ok then
            for undo = #self.enabledModules, 1, -1 do
                invokeRuntime(self.enabledModules[undo], "Disable", {
                    generation = self.generation,
                    reason = "ENABLE_ROLLBACK",
                    error = err,
                })
            end
            self.enabledModules = {}
            self.generation = self.generation + 1
            arbiter:BeginDrain("ENABLE_ROLLBACK")
            self:_setState(S.DISABLED, "ENABLE_FAILED")
            return nil, err
        end
        self.enabledModules[#self.enabledModules + 1] = entry
    end
    self:_setState(S.ENABLED, reason)
    return true
end

function Controller:_finishDisable(drainState)
    if self.state ~= S.DISABLING then return false end
    local context = {
        generation = self.generation,
        reason = self.stateReason,
        drainState = drainState,
    }
    for i = #self.enabledModules, 1, -1 do
        invokeRuntime(self.enabledModules[i], "Disable", context)
    end
    self.enabledModules = {}
    self.generation = self.generation + 1
    self.activeDrainId = nil
    self:_setState(S.DISABLED, self.stateReason or "DISABLED")
    return true
end

function Controller:Disable(reason)
    self:Initialize()
    if self.state == S.DISABLING or self.state == S.ENABLING then
        return nil, Mail:NewError("MODULE_TRANSITION_BUSY", "邮箱模块正在切换状态，请稍后重试。")
    end
    if self.state == S.DISABLED then return nil end
    if self.state == S.DISABLED_ROLLOUT or self.state == S.WAITING_CONFLICT_DECISION then
        self.conflictDecision = self.state == S.WAITING_CONFLICT_DECISION and "disable"
            or self.conflictDecision
        self:_setState(S.DISABLED, reason or "DISABLED")
        return nil
    end
    self:_setState(S.DISABLING, reason or "DISABLED")
    local context = { generation = self.generation, reason = reason or "DISABLED" }
    for i = #self.enabledModules, 1, -1 do
        invokeRuntime(self.enabledModules[i], "BeginDisable", context)
    end
    local arbiter = self:_arbiter()
    self.beginningDrain = true
    local drainId, drainState = arbiter:BeginDrain(reason or "MODULE_DISABLED")
    self.activeDrainId = drainId
    self.beginningDrain = false
    if drainState and drainState.phase == "COMPLETED" then self:_finishDisable(drainState) end
    return drainId
end

function Controller:GetDrainState(drainId)
    local arbiter = self:_arbiter()
    return arbiter and arbiter:GetDrainState(drainId) or nil
end

function Controller:ResolveConflict(decision)
    if self.state ~= S.WAITING_CONFLICT_DECISION then
        return nil, Mail:NewError("NO_PENDING_CONFLICT", "当前没有待处理的邮箱冲突提示。")
    end
    if decision == "ignore" then
        self.conflictDecision = "ignore"
        return self:Enable("CONFLICT_IGNORED")
    elseif decision == "disable" then
        self.conflictDecision = "disable"
        self:_setState(S.DISABLED, "LOGIN_CONFLICT")
        return true
    end
    return nil, Mail:NewError("INVALID_CONFLICT_DECISION", "邮箱冲突选择无效。")
end

Mail.MailModuleController = Controller
Mail.ModuleController = Mail.ModuleController or Controller.New()
