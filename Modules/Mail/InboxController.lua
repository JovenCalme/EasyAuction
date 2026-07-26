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

local function formatMoney(amount)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if _G and type(_G.GetCoinTextureString) == "function" then
        local ok, text = pcall(_G.GetCoinTextureString, amount, 14)
        if ok and type(text) == "string" then return text end
    end
    return tostring(amount) .. " 铜"
end

local function formatDays(days)
    days = math.max(0, tonumber(days) or 0)
    if days >= 1 then return string.format("%.1f 天", days) end
    local hours = days * 24
    if hours >= 1 then return string.format("%.1f 小时", hours) end
    return string.format("%d 分钟", math.max(0, math.floor(hours * 60 + 0.5)))
end

local function returnMailIdentity(mail)
    local key = mail and mail.key
    if type(key) ~= "table" or type(key.fingerprint) ~= "string"
        or type(key.duplicateOrdinal) ~= "number" then return nil end
    return tostring(#key.fingerprint) .. ":" .. key.fingerprint
        .. ":" .. tostring(key.duplicateOrdinal)
end

local function buildReturnPlan(snapshot)
    snapshot = snapshot or {}
    local plan = {
        mails = {}, count = 0, senderCount = 0, attachmentCount = 0,
        money = 0, codCount = 0, minDaysLeft = nil,
        current = math.max(0, tonumber(snapshot.current) or 0),
        total = math.max(0, tonumber(snapshot.total) or 0),
        byIdentity = {},
    }
    local senders = {}
    for index = 1, #(snapshot.mails or {}) do
        local mail = snapshot.mails[index]
        local canReturn = type(mail.capabilities) == "table"
            and mail.capabilities.canReturn == true
        local identity = canReturn and returnMailIdentity(mail) or nil
        if identity and not plan.byIdentity[identity] then
            plan.mails[#plan.mails + 1] = mail
            plan.byIdentity[identity] = {
                money = math.max(0, tonumber(mail.money) or 0),
                cod = math.max(0, tonumber(mail.cod) or 0),
                itemCount = math.max(0, tonumber(mail.itemCount) or 0),
            }
            plan.count = plan.count + 1
            plan.attachmentCount = plan.attachmentCount
                + math.max(0, tonumber(mail.itemCount) or 0)
            plan.money = plan.money + math.max(0, tonumber(mail.money) or 0)
            if (tonumber(mail.cod) or 0) > 0 then plan.codCount = plan.codCount + 1 end
            local days = tonumber(mail.daysLeft)
            if days and (not plan.minDaysLeft or days < plan.minDaysLeft) then
                plan.minDaysLeft = days
            end
            local sender = tostring(mail.sender or "")
            if sender ~= "" and not senders[sender] then
                senders[sender] = true
                plan.senderCount = plan.senderCount + 1
            end
        end
    end
    return plan
end

local function sameReturnPlan(expected, actual)
    if not expected or not actual or expected.count ~= actual.count then return false end
    for identity, values in pairs(expected.byIdentity or {}) do
        local current = actual.byIdentity and actual.byIdentity[identity]
        if not current or current.money ~= values.money or current.cod ~= values.cod
            or current.itemCount ~= values.itemCount then return false end
    end
    return true
end

local function ensureReturnConfirmRows(popup)
    if popup.easyAuctionReturnRows then return popup.easyAuctionReturnRows end
    local rows = {}
    for index = 1, 5 do
        local y = -58 - (index - 1) * 24
        rows[index] = {
            label = popup:CreateFontString(nil, "ARTWORK", "GameFontHighlight"),
            value = popup:CreateFontString(nil, "ARTWORK", "GameFontHighlight"),
        }
        rows[index].label:SetPoint("TOPLEFT", popup, "TOPLEFT", 20, y)
        rows[index].label:SetSize(104, 22)
        rows[index].label:SetJustifyH("CENTER")
        rows[index].value:SetPoint("TOPLEFT", popup, "TOPLEFT", 132, y)
        rows[index].value:SetSize(168, 22)
        rows[index].value:SetJustifyH("RIGHT")
    end
    popup.easyAuctionReturnWarning = popup:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    popup.easyAuctionReturnWarning:SetPoint("TOPLEFT", popup, "TOPLEFT", 20, -188)
    popup.easyAuctionReturnWarning:SetSize(280, 38)
    popup.easyAuctionReturnWarning:SetJustifyH("LEFT")
    popup.easyAuctionReturnWarning:SetWordWrap(true)
    popup.easyAuctionReturnWarning:SetTextColor(1, 0.25, 0.25)
    popup.easyAuctionReturnRows = rows
    return rows
end

local function showReturnConfirm(popup, data)
    if not popup then return end
    popup:SetHeight(270)
    local rows = ensureReturnConfirmRows(popup)
    for index = 1, #rows do
        local rowData = data and data.rows and data.rows[index] or {}
        rows[index].label:SetText(rowData.label or "")
        rows[index].value:SetText(rowData.value or "")
        rows[index].label:Show()
        rows[index].value:Show()
    end
    popup.easyAuctionReturnWarning:SetText(data and data.warning
        or "邮件、附件和金币将全部退还给发件人，操作无法撤销。")
    popup.easyAuctionReturnWarning:Show()
end

local function hideReturnConfirm(popup)
    for _, row in ipairs(popup and popup.easyAuctionReturnRows or {}) do
        row.label:Hide()
        row.value:Hide()
    end
    if popup and popup.easyAuctionReturnWarning then popup.easyAuctionReturnWarning:Hide() end
end

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
        returnCount = 0,
        returnBusy = false,
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

function Controller:_ensureNativeReturnButton()
    if self.nativeReturnButton then return self.nativeReturnButton end
    local parent = _G and (_G.InboxFrame or _G.MailFrame)
    local createFrame = self.deps.createFrame or (_G and _G.CreateFrame)
    if not parent or type(createFrame) ~= "function" then return nil end
    local button = createFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(72, 24)
    local openAll = _G and _G.OpenAllMail
    if openAll then button:SetPoint("LEFT", openAll, "RIGHT", 4, 0)
    else button:SetPoint("CENTER", parent, "BOTTOM", 65, 114) end
    button:SetText("闪退")
    button:SetScript("OnClick", function() self:RequestReturnAll() end)
    button:Disable()
    self.nativeReturnButton = button
    return button
end

function Controller:_setReturnButtons(count, busy)
    count = math.max(0, math.floor(tonumber(count) or 0))
    self.returnCount = count
    self.returnBusy = busy == true
    local view = self.view
    if view and type(view.SetReturnCount) == "function" then
        view:SetReturnCount(count, self.returnBusy)
    end
    local button = self:_ensureNativeReturnButton()
    if button then
        button:SetText("闪退")
        if self.enabled and self.active and not self.returnBusy and count > 0 then
            button:Enable()
        else
            button:Disable()
        end
    end
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
    if state and state.action == "return_mail" then
        local terminal = TERMINAL_STATES[state.state] == true
        self:_setReturnButtons(self.returnCount, not terminal)
        local openAll = _G and _G.OpenAllMail
        if openAll then
            if terminal and self.returnDisabledOpenAll then
                openAll:Enable()
                self.returnDisabledOpenAll = nil
            elseif not terminal and not self.returnDisabledOpenAll then
                self.returnDisabledOpenAll = openAll.IsEnabled == nil or openAll:IsEnabled()
                openAll:Disable()
            end
        end
        if terminal and self.lastReturnReportedId ~= state.operationId then
            self.lastReturnReportedId = state.operationId
            local message
            if state.state == "SUCCEEDED" then
                message = string.format("闪退完成：已退回 %d 封邮件。", state.completedCount or 0)
            else
                message = string.format("闪退已停止：已退回 %d/%d 封。%s",
                    state.completedCount or 0, state.totalCount or 0,
                    state.error and state.error.message or "")
                if state.error then self:_reportError(state.error) end
            end
            local chat = _G and _G.DEFAULT_CHAT_FRAME
            if chat and type(chat.AddMessage) == "function" then chat:AddMessage(message) end
        end
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
            onReturnAll = function() self:RequestReturnAll() end,
            categories = self:_categories(),
            onActivated = function() self:MarkDirty("TAB_ACTIVATED") end,
        })
        self.ownsView = true
    end
    return self.view
end

function Controller:_startReturnPlan(plan)
    local repository = self:_ensureRepository()
    if not repository or type(repository.Snapshot) ~= "function" then
        local err = newError("MISSING_DEPENDENCY", "邮件仓库尚不可用。")
        self:_reportError(err)
        return nil, err
    end
    local snapshot, snapshotError = repository:Snapshot()
    if not snapshot then
        self:_reportError(snapshotError)
        return nil, snapshotError
    end
    local current = buildReturnPlan(snapshot)
    if not sameReturnPlan(plan, current) then
        local err = newError("RETURN_PLAN_CHANGED", "邮箱内容已变化，请重新确认闪退邮件。")
        self:_reportError(err)
        self:_setReturnButtons(current.count, false)
        return nil, err
    end
    local queue = self:_ensureQueue()
    if not queue or type(queue.EnqueueReturns) ~= "function" then
        local err = newError("MISSING_DEPENDENCY", "退信队列尚不可用。")
        self:_reportError(err)
        return nil, err
    end
    local operationId, enqueueError = queue:EnqueueReturns(current.mails)
    if not operationId then self:_reportError(enqueueError) end
    return operationId, enqueueError
end

function Controller:RequestReturnAll()
    if not self.enabled or not self.active or self.returnBusy then return false end
    local openAll = _G and _G.OpenAllMail
    if openAll and type(openAll.IsEnabled) == "function" and not openAll:IsEnabled() then
        local err = newError("OUTBOUND_BUSY", "原生全部打开正在处理邮件，请稍后再试。")
        self:_reportError(err)
        return nil, err
    end
    local repository = self:_ensureRepository()
    if not repository or type(repository.Snapshot) ~= "function" then
        local err = newError("MISSING_DEPENDENCY", "邮件仓库尚不可用。")
        self:_reportError(err)
        return nil, err
    end
    local snapshot, snapshotError = repository:Snapshot()
    if not snapshot then
        self:_reportError(snapshotError)
        return nil, snapshotError
    end
    local plan = buildReturnPlan(snapshot)
    self:_setReturnButtons(plan.count, false)
    if plan.count == 0 then
        local err = newError("NO_RETURNABLE_MAIL", "当前已加载邮件中没有可退邮件。")
        self:_reportError(err)
        return nil, err
    end
    if not _G or not _G.StaticPopupDialogs or type(_G.StaticPopup_Show) ~= "function" then
        local err = newError("CONFIRMATION_UNAVAILABLE", "无法显示闪退确认窗口，操作已取消。")
        self:_reportError(err)
        return nil, err
    end
    if not _G.StaticPopupDialogs.EASYAUCTION_RETURN_ALL_CONFIRM then
        _G.StaticPopupDialogs.EASYAUCTION_RETURN_ALL_CONFIRM = {
            text = "%s", button1 = _G.ACCEPT or "确定", button2 = _G.CANCEL or "取消",
            OnAccept = function(_, data)
                if data and type(data.callback) == "function" then data.callback(data.plan) end
            end,
            OnShow = showReturnConfirm,
            OnHide = hideReturnConfirm,
            timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
        }
    end
    local codText = plan.codCount > 0 and (" / 付款取件 " .. plan.codCount .. " 封") or ""
    local rows = {
        { label = "可退邮件", value = plan.count .. " 封" },
        { label = "发件人数", value = plan.senderCount .. " 人" },
        { label = "附件合计", value = plan.attachmentCount .. " 组" .. codText },
        { label = "附带金币", value = formatMoney(plan.money) },
        { label = "最早到期", value = plan.minDaysLeft and formatDays(plan.minDaysLeft) or "未知" },
    }
    _G.StaticPopup_Show("EASYAUCTION_RETURN_ALL_CONFIRM", "|cffffd100确认闪退邮件|r", nil, {
        plan = plan,
        rows = rows,
        warning = string.format("仅处理当前已加载的 %d/%d 封邮件；附件和金币将退还，操作无法撤销。",
            plan.current, plan.total),
        callback = function(confirmedPlan) self:_startReturnPlan(confirmedPlan) end,
    })
    return true
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
    local returnPlan = buildReturnPlan(snapshot)
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
    self:_setReturnButtons(returnPlan.count, false)
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
    self:_setReturnButtons(self.returnCount, false)
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
    self:_setReturnButtons(0, false)
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
    local nativeReturnButton = self:_ensureNativeReturnButton()
    if nativeReturnButton then nativeReturnButton:Show() end
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
    if self.nativeReturnButton then self.nativeReturnButton:Hide() end
    return true
end

Controller.TAB_ID = TAB_ID

Mail.InboxController = Controller
Mail.Inbox = Mail.Inbox or Controller.New()
if type(Mail.RegisterRuntimeModule) == "function" then
    Mail:RegisterRuntimeModule("inbox", Mail.Inbox, 40)
end

return Controller
