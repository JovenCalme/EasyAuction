local _, ns = ...

ns = ns or {}
ns.Mail = ns.Mail or {}
local Mail = ns.Mail

local BulkMailController = {}
BulkMailController.__index = BulkMailController

local TAB_ID = "easyauction-bulk-mail"
local ALT_SOURCE_ID = "builtin:alts"
local FRIEND_SOURCE_ID = "builtin:friends"

local function clone(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = clone(item) end
    return result
end

local function newError(code, message, detail)
    if Mail.NewError then return Mail:NewError(code, message, detail) end
    return { code = code, message = message, detail = detail }
end

function BulkMailController.New(deps)
    return setmetatable({
        deps = deps or {},
        enabled = false,
        active = false,
        generation = 0,
    }, BulkMailController)
end

function BulkMailController:_compat() return self.deps.compat or Mail.Compat end
function BulkMailController:_session() return self.deps.session or Mail.Session end
function BulkMailController:_frameHost() return self.deps.frameHost or Mail.FrameHost end
function BulkMailController:_arbiter() return self.deps.arbiter or Mail.WriteArbiter end
function BulkMailController:_sessionGeneration()
    local session = self:_session()
    return session and session.GetGeneration and session:GetGeneration() or self.generation
end

function BulkMailController:_config()
    if self.deps.config then return self.deps.config end
    return Mail.Config and Mail.Config:GetMailConfig() or nil
end

function BulkMailController:_ensureServices()
    local config = self:_config()
    if not config then return nil, newError("MAIL_CONFIG_UNAVAILABLE", "邮箱配置尚未初始化") end
    local recipients, groups = self.deps.recipientRepository, self.deps.recipientGroupRepository
    if not recipients then recipients, groups = Mail:EnsureRecipientServices() end
    self.recipients = recipients
    self.groups = groups or self.deps.recipientGroupRepository
    if not self.recipients or not self.groups then
        return nil, newError("RECIPIENT_STORE_UNAVAILABLE", "批量收件人仓储尚未初始化")
    end

    if not self.history then
        self.history = self.deps.historyRepository or Mail.BulkHistoryRepository.New({
            storage = config.bulkHistory,
            maxBatches = config.bulk.historyMaxBatches,
            maxRecipientEntries = config.bulk.historyMaxRecipientEntries,
            maxAgeDays = config.bulk.historyMaxAgeDays,
        })
        self.history:RecoverInterrupted()
    end
    if not self.groupProvider then
        local realm = Mail.GetCurrentRecipientRealm and Mail.GetCurrentRecipientRealm(_G)
            or (_G.GetRealmName and _G.GetRealmName() or "")
        self.groupProvider = Mail.BulkRosterProviders.NewGroup({ currentRealm = realm, api = _G })
        self.guildProvider = Mail.BulkRosterProviders.NewGuild({ currentRealm = realm, api = _G })
        self.customProvider = Mail.BulkRosterProviders.NewCustom({
            currentRealm = realm, recipientGroupRepository = self.groups,
            resolveMembers = function(groupId)
                if groupId == ALT_SOURCE_ID then
                    return self.recipients:ListAlts({ currentRealmOnly = true })
                end
                if groupId == FRIEND_SOURCE_ID then
                    return Mail.BulkRosterProviders.ListFriends({ currentRealm = realm, api = _G })
                end
                return self.groups:GetMembers(groupId)
            end,
        })
        self.rosterService = Mail.BulkRosterProviders.NewService({
            providers = {
                party = self.groupProvider,
                raid = self.groupProvider,
                guild = self.guildProvider,
                custom = self.customProvider,
            },
        })
    end
    if not self.selection then
        self.selection = Mail.BulkSelectionModel.New({
            maxRecipients = config.bulk.maxRecipientsPerBatch,
            isRecipientBlocked = function(member)
                return self.recipients:IsBlacklisted(member)
            end,
        })
    end
    if not self.coordinator then
        self.coordinator = Mail.BulkSendCoordinator.New({
            compat = self:_compat(), arbiter = self:_arbiter(), historyRepository = self.history,
            recipientRepository = self.recipients, rosterService = self.rosterService,
            maxRecipients = config.bulk.maxRecipientsPerBatch,
            generation = function() return self:_sessionGeneration() end,
        })
    end
    return true
end

function BulkMailController:_ensureView()
    if self.view then self:_anchorView() return self.view end
    if self.deps.view then self.view = self.deps.view self:_anchorView() return self.view end
    local config = self:_config()
    self.view = Mail.BulkMailView.New({
        selectionModel = self.selection,
        historyRepository = self.history,
        recipientGroupRepository = self.groups,
        listRecipientSources = function() return self:ListRecipientSources() end,
        validate = function(draft) return self.coordinator:Validate(draft) end,
        onStart = function(draft) return self:Start(draft) end,
        onContinue = function() return self:Continue() end,
        onPrepareRetryFailed = function(batchId) return self.coordinator:PrepareRetryFailed(batchId) end,
        onRetryFailed = function(plan) return self.coordinator:RetryFailed(plan) end,
        onSourceChanged = function(sourceKind, groupId) return self:SetSource(sourceKind, groupId) end,
        initialFilter = { rankIndices = clone(config.bulk.guildRankFilter or {}) },
        onFilterChanged = function(filter)
            config.bulk.guildRankFilter = clone(filter.rankIndices or {})
        end,
        onActivated = function() return self:RefreshRoster("TAB_ACTIVATED") end,
        onDeactivated = function(reason) return self:OnTabDeactivated(reason) end,
    })
    local parent = self.deps.parent or _G.MailFrame or _G.UIParent
    local frame = self.view:Create(parent)
    if not frame then self.view = nil return nil end
    self:_anchorView()
    return self.view
end

function BulkMailController:_anchorView()
    local frame = self.view and (self.view.frame or self.view)
    if not frame or not _G.MailFrame then return false end
    if frame.SetParent then frame:SetParent(_G.MailFrame) end
    if frame.ClearAllPoints and frame.SetPoint then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", _G.MailFrame, "TOPLEFT", 20, -32)
    end
    return true
end

function BulkMailController:ListRecipientSources()
    local result = {
        { id = "builtin:guild", label = "公会", sourceKind = "guild" },
        { id = ALT_SOURCE_ID, label = "小号", sourceKind = "custom", sourceGroupId = ALT_SOURCE_ID },
        { id = FRIEND_SOURCE_ID, label = "好友", sourceKind = "custom", sourceGroupId = FRIEND_SOURCE_ID },
    }
    local groups = self.groups and self.groups:ListGroups() or {}
    for index = 1, #groups do
        result[#result + 1] = {
            id = groups[index].id,
            label = groups[index].name,
            sourceKind = "custom",
            sourceGroupId = groups[index].id,
        }
    end
    return result
end

function BulkMailController:_registerView()
    local frameHost = self:_frameHost()
    return frameHost:RegisterTab(TAB_ID, self.view, {
        label = "闪寄", order = 40, width = 810,
    })
end

function BulkMailController:SetSource(sourceKind, groupId)
    local config = self:_config()
    if not self.rosterService:SetSource(sourceKind, groupId) then
        return nil, newError("INVALID_ROSTER_SOURCE", "不支持该名单来源")
    end
    self.selection:SetSource(sourceKind, groupId)
    local filter = self.view and self.view.filter or { rankIndices = clone(config.bulk.guildRankFilter or {}) }
    self.selection:SetFilter(filter)
    config.bulk.lastSourceKind = sourceKind
    config.bulk.lastSourceGroupId = groupId
    return self:RefreshRoster("SOURCE_CHANGED")
end

function BulkMailController:RefreshRoster(reason)
    if not self.rosterService then return nil end
    self.rosterService:Refresh(reason)
    self.selection:UpdateRoster(self.rosterService:GetSnapshot())
    if self.view then self.view:Refresh() end
    return true
end

function BulkMailController:OnWoWEvent(event)
    local sourceKind = self.selection and self.selection.sourceKind
    if event == "GUILD_ROSTER_UPDATE" then
        self.guildProvider:OnRosterUpdate()
        if sourceKind == "guild" then
            self.selection:UpdateRoster(self.guildProvider:GetSnapshot())
            if self.view then self.view:Refresh() end
        end
    elseif event == "PLAYER_GUILD_UPDATE" and sourceKind == "guild" then
        self:RefreshRoster(event)
    elseif event == "GROUP_ROSTER_UPDATE" and (sourceKind == "party" or sourceKind == "raid") then
        self:RefreshRoster(event)
    elseif event == "FRIENDLIST_UPDATE" and sourceKind == "custom"
        and self.selection.sourceGroupId == FRIEND_SOURCE_ID then
        self:RefreshRoster(event)
    end
end

function BulkMailController:OnSessionStart()
    self.active = true
    self:_anchorView()
    local config = self:_config()
    local sourceKind = config.bulk.lastSourceKind or "raid"
    local groupId = config.bulk.lastSourceGroupId
    if sourceKind == "party" then sourceKind = "raid" end
    if sourceKind == "custom" and groupId ~= ALT_SOURCE_ID and groupId ~= FRIEND_SOURCE_ID
        and (not groupId or not self.groups:Get(groupId)) then
        sourceKind, groupId = "raid", nil
    end
    self:SetSource(sourceKind, groupId)
end

function BulkMailController:OnSessionStop()
    self.active = false
    if self.view then self.view:Hide() end
    if self.coordinator then self.coordinator:OnSessionClosed("MAIL_CLOSED") end
end

function BulkMailController:Start(draft)
    local batchId, err = self.coordinator:Start(draft)
    if not batchId then
        if self.view then self.view:ShowError(err) end
        return nil, err
    end
    self:_syncBatch()
    return batchId
end

function BulkMailController:Continue()
    local ok, err = self.coordinator:Continue()
    self:_syncBatch()
    return ok, err
end

function BulkMailController:Cancel(reason)
    local result = self.coordinator and self.coordinator:CancelPending(reason)
    self:_syncBatch()
    return result
end

function BulkMailController:OnTabDeactivated(reason)
    if not self.coordinator then return false end
    local result = self.coordinator:OnSessionClosed(reason or "TAB_DEACTIVATED")
    self:_syncBatch()
    return result
end

function BulkMailController:OnSendEvent(event, ...)
    if self.coordinator then self.coordinator:OnSendEvent(event, ...) end
    self:_syncBatch()
end

function BulkMailController:_syncBatch()
    local state = self.coordinator and self.coordinator:GetState()
    if self.view and state then self.view:SetBatchState(state) end
end

function BulkMailController:Enable(context)
    if self.enabled then return true end
    local config = self:_config()
    if config and config.bulk and config.bulk.enabled == false then return true end
    self.enabled = true
    self.generation = context and context.generation or self.generation
    local ready, readyError = self:_ensureServices()
    if not ready then self.enabled = false return nil, readyError end
    local view = self:_ensureView()
    if not view then self.enabled = false return nil, newError("BULK_VIEW_UNAVAILABLE", "无法创建批量邮寄界面") end
    view.enabled = true
    local registered, registerError = self:_registerView()
    if not registered then self.enabled = false return nil, registerError end
    local session = self:_session()
    session:Register(self, {
        OnStart = function() self:OnSessionStart() end,
        OnStop = function() self:OnSessionStop() end,
        Cancel = function(reason) self:Cancel(reason) end,
    })
    local compat = self:_compat()
    compat:RegisterSendLifecycle(self, function(event, ...) self:OnSendEvent(event, ...) end)
    compat:RegisterEventListener(self, function(event, ...) self:OnWoWEvent(event, ...) end)
    self.groups:Subscribe(self, function()
        if self.selection.sourceKind == "custom" then self:RefreshRoster("CUSTOM_GROUP_CHANGED") end
    end)
    Mail:Subscribe("MAIL_BULK_BATCH_CHANGED", self, function() self:_syncBatch() end)
    if session:IsOpen() then self:OnSessionStart() else view:Hide() end
    return true
end

function BulkMailController:BeginDisable(context)
    if not self.enabled then return true end
    if self.view then self.view.enabled = false end
    if self.coordinator then self.coordinator:OnDrain(context and context.reason or "MODULE_DISABLED") end
    return true
end

function BulkMailController:Disable()
    if not self.enabled then return true end
    self.enabled = false
    self.active = false
    local session = self:_session()
    if session then session:Unregister(self) end
    local compat = self:_compat()
    if compat then compat:UnregisterOwner(self) end
    local frameHost = self:_frameHost()
    if frameHost and type(frameHost.UnregisterTab) == "function" then
        frameHost:UnregisterTab(TAB_ID)
    end
    if self.groups then self.groups:Unsubscribe(self) end
    Mail:UnsubscribeOwner(self)
    if self.view then self.view:Hide() self.view.enabled = false end
    self.generation = self.generation + 1
    return true
end

BulkMailController.TAB_ID = TAB_ID
Mail.BulkMailControllerClass = BulkMailController
Mail.BulkMailController = Mail.BulkMailController or BulkMailController.New()
if Mail.RegisterRuntimeModule then Mail:RegisterRuntimeModule("bulk-mail", Mail.BulkMailController, 60) end

return BulkMailController
