local _, ns = ...
ns = type(ns) == "table" and ns or {}
ns.Mail = type(ns.Mail) == "table" and ns.Mail or {}

local Mail = ns.Mail
local Controller = {}
Controller.__index = Controller

local TAB_ID = "easyauction-mailbag"
local TERMINAL_STATES = {
    SUCCEEDED = true,
    FAILED = true,
    CANCELLED = true,
    INDETERMINATE = true,
}

local function newError(code, message, detail)
    if type(Mail.NewError) == "function" then
        return Mail:NewError(code, message, detail)
    end
    return { code = code, message = message, detail = detail }
end

local function scheduleNextFrame(self, callback)
    if type(self.deps.scheduleFrame) == "function" then
        self.deps.scheduleFrame(callback)
        return
    end
    if _G and _G.C_Timer and type(_G.C_Timer.After) == "function" then
        _G.C_Timer.After(0, callback)
        return
    end
    callback()
end

function Controller.New(deps)
    return setmetatable({
        deps = deps or {},
        enabled = false,
        active = false,
        generation = 0,
        dirty = false,
        refreshScheduled = false,
        query = "",
        categoryId = "all",
        rowOffset = 0,
        snapshot = nil,
        entries = {},
        searchIndex = nil,
        repository = nil,
        queue = nil,
        view = nil,
        ownsRepository = false,
        ownsQueue = false,
        ownsView = false,
    }, Controller)
end

function Controller:_compat()
    return self.deps.compat or Mail.Compat
end

function Controller:_session()
    return self.deps.session or Mail.Session
end

function Controller:_frameHost()
    return self.deps.frameHost or Mail.FrameHost
end

function Controller:_config()
    return self.deps.config or Mail.Config
end

function Controller:_settings()
    if type(self.deps.getSettings) == "function" then
        return self.deps.getSettings()
    end
    local config = self:_config()
    local mailConfig = config and type(config.GetMailConfig) == "function"
        and config:GetMailConfig() or nil
    if type(mailConfig) ~= "table" then return {} end
    mailConfig.inbox = type(mailConfig.inbox) == "table" and mailConfig.inbox or {}
    return mailConfig.inbox
end

function Controller:_aggregator()
    return self.deps.aggregator or Mail.InboxAggregator
end

function Controller:_search()
    return self.deps.search or Mail.InboxSearch
end

function Controller:_presenter()
    return self.deps.presenter or Mail.InboxPresenter
end

function Controller:_categoryRegistry()
    return self.deps.categoryRegistry or Mail.ItemCategoryRegistry
end

function Controller:_categories()
    local registry = self:_categoryRegistry()
    if registry and type(registry.List) == "function" then return registry:List() end
    return {}
end

function Controller:_ensureNativeInboxLabels()
    if self.nativeInboxLabels then return self.nativeInboxLabels end
    local labels = {}
    local pageSize = math.max(1, tonumber(_G and _G.INBOXITEMS_TO_DISPLAY) or 7)
    for row = 1, pageSize do
        local item = _G and _G["MailItem" .. row]
        if item and type(item.CreateFontString) == "function" then
            local label = item:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            label:SetSize(44, 12)
            local expireTime = _G["MailItem" .. row .. "ExpireTime"]
            if expireTime then
                label:SetPoint("RIGHT", expireTime, "RIGHT", -48, 0)
            else
                label:SetPoint("TOPRIGHT", item, "TOPRIGHT", -48, -4)
            end
            label:SetJustifyH("CENTER")
            label:Hide()
            labels[row] = label
        end
    end
    self.nativeInboxLabels = labels
    return labels
end

function Controller:_hideNativeInboxLabels()
    for _, label in pairs(self.nativeInboxLabels or {}) do label:Hide() end
end

function Controller:RefreshNativeInboxLabels()
    if not self.enabled then self:_hideNativeInboxLabels() return false end
    local labels = self:_ensureNativeInboxLabels()
    local compat = self:_compat()
    if not compat or type(compat.GetInboxCounts) ~= "function"
        or type(compat.GetHeader) ~= "function" then
        self:_hideNativeInboxLabels()
        return false
    end
    local current = compat:GetInboxCounts()
    current = tonumber(current) or 0
    local pageSize = math.max(1, tonumber(_G and _G.INBOXITEMS_TO_DISPLAY) or 7)
    local page = math.max(1, tonumber(_G and _G.InboxFrame and _G.InboxFrame.pageNum) or 1)
    for row = 1, pageSize do
        local label = labels[row]
        local mailIndex = row + (page - 1) * pageSize
        local header = mailIndex <= current and compat:GetHeader(mailIndex) or nil
        local hasMail = header and (tostring(header.sender or "") ~= ""
            or tostring(header.subject or "") ~= "" or header.packageIcon ~= nil
            or (tonumber(header.money) or 0) > 0 or (tonumber(header.itemCount) or 0) > 0)
        if label and hasMail then
            if header.canReturn == true then
                label:SetText("可退")
                label:SetTextColor(0.2, 1, 0.2)
            else
                label:SetText("转寄")
                label:SetTextColor(1, 0.2, 0.2)
            end
            label:Show()
        elseif label then
            label:SetText("")
            label:Hide()
        end
    end
    return true
end

function Controller:_installNativeInboxHook()
    if self.nativeInboxHookInstalled then return true end
    if _G and type(_G.hooksecurefunc) == "function"
        and type(_G.InboxFrame_Update) == "function" then
        _G.hooksecurefunc("InboxFrame_Update", function()
            if self.enabled then self:RefreshNativeInboxLabels() end
        end)
        self.nativeInboxHookInstalled = true
        return true
    end
    return false
end

function Controller:_ensureRepository()
    if self.repository then return self.repository end
    if self.deps.repository then
        self.repository = self.deps.repository
    elseif Mail.InboxRepository and type(Mail.InboxRepository.New) == "function" then
        self.repository = Mail.InboxRepository.New({ compat = self:_compat() })
        self.ownsRepository = true
    end
    return self.repository
end

function Controller:_onQueueChanged(state)
    local view = self.view
    if view and type(view.SetEnabled) == "function" then
        view:SetEnabled(not state or TERMINAL_STATES[state.state] == true)
    end
    if state and TERMINAL_STATES[state.state] then self:MarkDirty("QUEUE_TERMINAL") end
end

function Controller:_ensureQueue()
    if self.queue then return self.queue end
    if self.deps.queue then
        self.queue = self.deps.queue
    elseif Mail.InboxOperationQueue and type(Mail.InboxOperationQueue.New) == "function" then
        local session = self:_session()
        self.queue = Mail.InboxOperationQueue.New({
            repository = self:_ensureRepository(),
            compat = self:_compat(),
            arbiter = self.deps.arbiter or Mail.WriteArbiter,
            clock = self.deps.clock,
            schedule = self.deps.scheduleTimer,
            timeoutSeconds = self:_settings().operationTimeout,
            markRead = true,
            sessionGeneration = function()
                if session and type(session.GetGeneration) == "function" then
                    return session:GetGeneration()
                end
                return self.generation
            end,
            isSessionOpen = function()
                return session and type(session.IsOpen) == "function" and session:IsOpen()
                    or self.active
            end,
            onChanged = function(state) self:_onQueueChanged(state) end,
        })
        self.ownsQueue = true
    end
    return self.queue
end

function Controller:_handleEntryClick(entry, mouseButton)
    if type(entry) ~= "table" then return end
    if entry.kind == "cod" or entry.isCOD == true or (tonumber(entry.cod) or 0) > 0 then
        local err = newError("COD_REQUIRES_CONFIRMATION", "付款取件邮件只能在原生收件箱中查看和付款。")
        self:_reportError(err)
        return nil, err
    end
    local modified = type(self.deps.isModifiedClick) == "function"
        and self.deps.isModifiedClick() or (_G and type(_G.IsModifiedClick) == "function"
            and _G.IsModifiedClick() == true)
    if modified and entry.kind == "item" and entry.sources and entry.sources[1] then
        local link = entry.sources[1].itemLink
        local handler = self.deps.handleModifiedItemClick
            or (_G and _G.HandleModifiedItemClick)
        if link and type(handler) == "function" and handler(link) then return end
    end

    local mode = (modified or mouseButton == "RightButton") and "one_source" or "all_sources"
    local queue = self:_ensureQueue()
    if queue and type(queue.Enqueue) == "function" then
        local _, enqueueError = queue:Enqueue(entry, mode)
        if enqueueError then self:_reportError(enqueueError) end
    end
end

function Controller:_ensureView()
    local parent = self.deps.parent or (_G and _G.MailFrame)
    if self.view then
        if not self.view.root and parent and type(self.view.Create) == "function" then
            self.view:Create(parent)
        end
        return self.view
    end
    if self.deps.view then
        self.view = self.deps.view
    elseif Mail.InboxView and type(Mail.InboxView.New) == "function" then
        self.view = Mail.InboxView.New({
            parent = parent,
            createFrame = self.deps.createFrame,
            tooltipBuilder = self.deps.tooltipBuilder or Mail.InboxTooltipBuilder,
            tooltip = self.deps.tooltip,
            onEntryClick = function(entry, mouseButton)
                self:_handleEntryClick(entry, mouseButton)
            end,
            onScroll = function(offset) self:SetRowOffset(offset) end,
            onSearchChanged = function(query) self:SetQuery(query) end,
            onCategoryChanged = function(categoryId) self:SetCategory(categoryId) end,
            onGroupStacksChanged = function(enabled) self:SetGroupStacks(enabled) end,
            categories = self:_categories(),
            onActivated = function() self:MarkDirty("TAB_ACTIVATED") end,
        })
        self.ownsView = true
    end
    return self.view
end

function Controller:_reportError(errorObject)
    if type(self.deps.onError) == "function" then
        self.deps.onError(errorObject)
    elseif type(Mail.Publish) == "function" then
        Mail:Publish("MAIL_INBOX_ERROR", errorObject)
    end
end

function Controller:Refresh(reason)
    if not self.enabled or not self.active then return false end
    local repository = self:_ensureRepository()
    local aggregator = self:_aggregator()
    local search = self:_search()
    local presenter = self:_presenter()
    local view = self:_ensureView()
    if not repository or not aggregator or not search or not presenter or not view then
        local missing = newError("MISSING_DEPENDENCY", "收件视图依赖尚未加载。")
        self:_reportError(missing)
        return nil, missing
    end

    local snapshot, snapshotError = repository:Snapshot()
    if not snapshot then
        self:_reportError(snapshotError)
        return nil, snapshotError
    end
    local settings = self:_settings()
    local entries = aggregator.Build(snapshot, {
        groupStacks = settings.groupStacks,
        categoryId = self.categoryId,
        categoryRegistry = self:_categoryRegistry(),
    })
    local searchIndex = search.Build(entries, self.deps.locale or (_G and _G.GetLocale and _G.GetLocale()))
    local visibleIds = search.Filter(searchIndex, self.query)
    local visibleSet = type(search.ToSet) == "function" and search.ToSet(visibleIds) or visibleIds
    local projection = presenter.Project(entries, {
        rowOffset = self.rowOffset,
        qualityColors = true,
        visibleEntryIds = visibleSet,
        enabled = true,
    })
    projection.snapshotGeneration = snapshot.generation
    projection.mailCurrent = snapshot.current
    projection.mailTotal = snapshot.total
    projection.reason = reason

    self.snapshot = snapshot
    self.entries = entries
    self.searchIndex = searchIndex
    self.rowOffset = projection.rowOffset or 0
    if type(view.SetQuery) == "function" then view:SetQuery(self.query) end
    if type(view.SetGroupStacks) == "function" then
        view:SetGroupStacks(settings.groupStacks ~= false)
    end
    if type(view.SetCategory) == "function" then view:SetCategory(self.categoryId) end
    if type(view.SetQualityColors) == "function" then view:SetQualityColors(true) end
    if type(view.SetSummary) == "function" then
        view:SetSummary(snapshot.current, snapshot.total)
    end
    view:Bind(projection)
    self:RefreshNativeInboxLabels()
    return projection
end

function Controller:MarkDirty(reason)
    if not self.enabled or not self.active then return false end
    self.dirty = true
    self.dirtyReason = reason or self.dirtyReason
    if self.refreshScheduled then return false end

    self.refreshScheduled = true
    local generation = self.generation
    scheduleNextFrame(self, function()
        if not self.enabled or generation ~= self.generation then return end
        self.refreshScheduled = false
        if not self.dirty then return end
        local refreshReason = self.dirtyReason
        self.dirty = false
        self.dirtyReason = nil
        self:Refresh(refreshReason)
    end)
    return true
end

function Controller:SetQuery(query)
    query = tostring(query or "")
    if query == self.query then return false end
    self.query = query
    self.rowOffset = 0
    return self:MarkDirty("SEARCH_CHANGED")
end

function Controller:SetCategory(categoryId)
    categoryId = tostring(categoryId or "all")
    if categoryId == self.categoryId then return false end
    self.categoryId = categoryId
    self.rowOffset = 0
    return self:MarkDirty("CATEGORY_CHANGED")
end

function Controller:SetRowOffset(offset)
    offset = math.max(0, math.floor(tonumber(offset) or 0))
    if offset == self.rowOffset then return false end
    self.rowOffset = offset
    return self:MarkDirty("SCROLL_CHANGED")
end

function Controller:SetGroupStacks(enabled)
    local settings = self:_settings()
    enabled = enabled == true
    if settings.groupStacks == enabled then return false end
    settings.groupStacks = enabled
    self.rowOffset = 0
    return self:MarkDirty("GROUPING_CHANGED")
end

function Controller:SetAdvanced(enabled)
    local settings = self:_settings()
    enabled = enabled == true
    if settings.advanced == enabled then return false end
    settings.advanced = enabled
    self.rowOffset = 0
    return self:MarkDirty("ADVANCED_CHANGED")
end

function Controller:OnSessionStart(payload)
    if not self.enabled then return end
    self.active = true
    local queue = self:_ensureQueue()
    if queue and type(queue.SetAccepting) == "function" then queue:SetAccepting(true) end
    local view = self:_ensureView()
    if view and type(view.SetEnabled) == "function" then view:SetEnabled(true) end
    self:RefreshNativeInboxLabels()
    self:MarkDirty(payload and payload.reason or "MAIL_SESSION_STARTED")

end

function Controller:OnSessionStop(payload)
    self.active = false
    local queue = self:_ensureQueue()
    if queue and type(queue.OnWoWEvent) == "function" then
        queue:OnWoWEvent("MAIL_CLOSED", payload)
    end
    local view = self.view
    if view and type(view.Hide) == "function" then view:Hide() end
    self:_hideNativeInboxLabels()
end

function Controller:OnWoWEvent(event, ...)
    local queue = self:_ensureQueue()
    if queue and type(queue.OnWoWEvent) == "function" then
        queue:OnWoWEvent(event, ...)
    end
    if event == "MAIL_INBOX_UPDATE" or event == "MAIL_SHOW" or event == "MAIL_SUCCESS" then
        self:RefreshNativeInboxLabels()
    end
end

function Controller:Enable(context)
    if self.enabled then return true end
    if self:_settings().enabled == false then return true end
    self.enabled = true
    self.generation = context and context.generation or self.generation
    self:_ensureRepository()
    self:_ensureQueue()
    self:_installNativeInboxHook()
    local view = self:_ensureView()
    if not view then
        self.enabled = false
        return nil, newError("INBOX_VIEW_UNAVAILABLE", "无法创建收件邮包视图。")
    end

    local frameHost = self:_frameHost()
    if frameHost and type(frameHost.RegisterTab) == "function" then
        local registered, registerError = frameHost:RegisterTab(TAB_ID, view, {
            label = "闪收",
            order = 30,
        })
        if not registered then
            self.enabled = false
            return nil, registerError
        end
    end

    local session = self:_session()
    if session and type(session.Register) == "function" then
        session:Register(self, {
            OnStart = function(payload) self:OnSessionStart(payload) end,
            OnStop = function(payload) self:OnSessionStop(payload) end,
            OnInboxDirty = function(payload)
                self:MarkDirty(payload and payload.cause or "MAIL_INBOX_DIRTY")
            end,
            Cancel = function(reason) self:OnSessionStop({ reason = reason }) end,
        })
    end
    local compat = self:_compat()
    if compat and type(compat.RegisterEventListener) == "function" then
        compat:RegisterEventListener(self, function(event, ...)
            self:OnWoWEvent(event, ...)
        end)
    end
    if session and type(session.IsOpen) == "function" and session:IsOpen() then
        self:OnSessionStart({ reason = "ENABLE_WHILE_OPEN" })
    end
    return true
end

function Controller:BeginDisable(context)
    if not self.enabled then return true end
    local queue = self:_ensureQueue()
    if queue then
        if type(queue.BeginDisable) == "function" then
            queue:BeginDisable(context and context.reason or "MODULE_DISABLING")
        elseif type(queue.SetAccepting) == "function" then
            queue:SetAccepting(false)
        end
    end
    if self.view and type(self.view.SetEnabled) == "function" then
        self.view:SetEnabled(false)
    end
    return true
end

function Controller:Disable(context)
    if not self.enabled then return true end
    self.enabled = false
    self.active = false
    self.generation = self.generation + 1
    self.dirty = false
    self.refreshScheduled = false

    local session = self:_session()
    if session and type(session.Unregister) == "function" then session:Unregister(self) end
    local compat = self:_compat()
    if compat and type(compat.UnregisterOwner) == "function" then compat:UnregisterOwner(self) end
    local frameHost = self:_frameHost()
    if frameHost and type(frameHost.UnregisterTab) == "function" then
        frameHost:UnregisterTab(TAB_ID)
    end
    if self.queue and type(self.queue.Shutdown) == "function" then
        self.queue:Shutdown(context and context.reason or "MODULE_DISABLED")
    end
    if self.view then
        if type(self.view.Hide) == "function" then self.view:Hide() end
    end
    self:_hideNativeInboxLabels()
    return true
end

Controller.TAB_ID = TAB_ID

Mail.InboxController = Controller
Mail.Inbox = Mail.Inbox or Controller.New()
if type(Mail.RegisterRuntimeModule) == "function" then
    Mail:RegisterRuntimeModule("inbox", Mail.Inbox, 40)
end

return Controller
