local _, ns = ...
local Mail = ns.Mail

local FrameHost = {}
FrameHost.__index = FrameHost

local NATIVE_TAB_COUNT = 2

local function callView(view, method, ...)
    if type(view) ~= "table" then return end
    if type(view[method]) == "function" then
        Mail:SafeCall(view[method], view, ...)
    elseif view.frame and type(view.frame[method]) == "function" then
        Mail:SafeCall(view.frame[method], view.frame, ...)
    end
end

local function viewFrame(view)
    if type(view) ~= "table" then return nil end
    return view.frame or view
end

function FrameHost.New(deps)
    return setmetatable({
        deps = deps or {},
        tabs = {},
        tabById = {},
        enabled = false,
        generation = 0,
        baseTabCount = nil,
        originalGeometry = nil,
        originalTabs = nil,
        createdTabsTable = false,
        activeTabId = nil,
        activeExternalButton = nil,
        standardHooksInstalled = false,
        standardButtonsHooked = {},
        standardFunctionHooked = false,
        lifecycleRegistered = false,
    }, FrameHost)
end

function FrameHost:_api(name)
    if self.deps[name] ~= nil then return self.deps[name] end
    return _G[name]
end

function FrameHost:RegisterTab(id, view, options)
    if type(id) ~= "string" or id == "" or type(view) ~= "table" then
        return nil, Mail:NewError("INVALID_MAIL_TAB", "邮箱标签注册参数无效。")
    end
    options = options or {}
    local entry = self.tabById[id]
    if entry then
        entry.view = view
        entry.label = options.label or entry.label
        entry.order = tonumber(options.order) or entry.order
        entry.width = tonumber(options.width) or entry.width
        entry.height = tonumber(options.height) or entry.height
        entry.registered = true
    else
        entry = {
            id = id,
            view = view,
            label = options.label or id,
            order = tonumber(options.order) or 100,
            width = tonumber(options.width),
            height = tonumber(options.height),
            registered = true,
        }
        self.tabs[#self.tabs + 1] = entry
        self.tabById[id] = entry
    end
    table.sort(self.tabs, function(left, right)
        if left.order == right.order then return left.id < right.id end
        return left.order < right.order
    end)
    if self.enabled then self:_buildTabs() end
    return true
end

function FrameHost:UnregisterTab(id)
    local entry = self.tabById[id]
    if not entry then return false end
    entry.registered = false
    if entry.button then entry.button:Hide() end
    callView(entry.view, "Hide")
    if self.activeTabId == id then self:ShowStandardTabs() end
    if self.enabled then self:_buildTabs() end
    return true
end

function FrameHost:_saveGeometry(frame)
    if self.originalGeometry then return end
    local geometry = {}
    if frame.GetWidth then geometry.width = frame:GetWidth() end
    if frame.GetHeight then geometry.height = frame:GetHeight() end
    self.originalGeometry = geometry
end

function FrameHost:_restoreGeometry(frame)
    local geometry = self.originalGeometry
    if not geometry then return end
    if geometry.width and geometry.height and frame.SetSize then frame:SetSize(geometry.width, geometry.height) end
end

function FrameHost:_hideCustomViews(exceptId, reason)
    local activeTabId = self.activeTabId
    for i = 1, #self.tabs do
        local entry = self.tabs[i]
        if entry.registered and entry.id ~= exceptId then
            if entry.id == activeTabId and reason then
                callView(entry.view, "OnDeactivated", reason)
            end
            callView(entry.view, "Hide")
        end
    end
end

function FrameHost:_baseButton(index)
    local frame = self:_api("MailFrame")
    return frame and frame.Tabs and frame.Tabs[index]
        or self:_api("MailFrameTab" .. index)
end

function FrameHost:_hideExternalViews(exceptButton)
    local baseCount = self.baseTabCount or 0
    for index = NATIVE_TAB_COUNT + 1, baseCount do
        local button = self:_baseButton(index)
        local externalView = button and button.frame
        if button ~= exceptButton and externalView and type(externalView.Hide) == "function" then
            externalView:Hide()
        end
    end
    if self.activeExternalButton ~= exceptButton then self.activeExternalButton = nil end
end

function FrameHost:_showBaseTab(index, button)
    if not self.enabled then return end
    local nativeTab = not index or index <= NATIVE_TAB_COUNT
    self:_hideCustomViews(nil, nativeTab and "NATIVE_TAB" or "EXTERNAL_TAB")
    self.activeTabId = nil
    if nativeTab then
        self:_hideExternalViews()
        local frame = self:_api("MailFrame")
        if frame then self:_restoreGeometry(frame) end
    else
        self:_hideExternalViews(button)
        self.activeExternalButton = button
    end
end

function FrameHost:ShowStandardTabs()
    self:_showBaseTab(1, self:_baseButton(1))
end

function FrameHost:ActivateTab(id)
    if not self.enabled then
        return nil, Mail:NewError("MAIL_FRAME_HOST_DISABLED", "邮箱界面宿主尚未启用。")
    end
    local entry = self.tabById[id]
    if not entry or not entry.registered then
        return nil, Mail:NewError("MAIL_TAB_NOT_FOUND", "找不到邮箱标签。", { id = id })
    end
    self:_hideCustomViews(id, "EASYAUCTION_TAB")
    self:_hideExternalViews()
    self.activeTabId = id
    local inbox = self:_api("InboxFrame")
    local send = self:_api("SendMailFrame")
    local openMail = self:_api("OpenMailFrame")
    if inbox and inbox.Hide then inbox:Hide() end
    if send and send.Hide then send:Hide() end
    if openMail and openMail.Hide then openMail:Hide() end
    local frame = self:_api("MailFrame")
    local original = self.originalGeometry or {}
    if frame and frame.SetSize and original.width and original.height then
        frame:SetSize(entry.width or original.width, entry.height or original.height)
    end
    local setTab = self:_api("PanelTemplates_SetTab")
    if frame and entry.button and type(setTab) == "function" then
        setTab(frame, entry.button:GetID())
    end
    local hideButtonBar = self:_api("ButtonFrameTemplate_HideButtonBar")
    if frame and type(hideButtonBar) == "function" then hideButtonBar(frame) end
    local inset = self:_api("MailFrameInset")
    if inset and inset.SetPoint then inset:SetPoint("TOPLEFT", 4, -58) end
    local setSendShowing = self:_api("SetSendMailShowing")
    if type(setSendShowing) == "function" then setSendShowing(false) end
    callView(entry.view, "Show")
    callView(entry.view, "OnActivated", self.generation)
    return true
end

function FrameHost:_installStandardHooks()
    local frame = self:_api("MailFrame")
    local baseCount = self.baseTabCount or (frame and tonumber(frame.numTabs)) or 2
    for index = 1, baseCount do
        local button = self:_baseButton(index)
        if button and button.HookScript and not self.standardButtonsHooked[button] then
            local tabIndex = index
            button:HookScript("OnClick", function()
                if self.enabled and Mail:IsGenerationCurrent(self.generation) then
                    self:_showBaseTab(tabIndex, button)
                end
            end)
            self.standardButtonsHooked[button] = true
        end
    end
    local hooksecurefunc = self:_api("hooksecurefunc")
    if not self.standardFunctionHooked and type(hooksecurefunc) == "function"
        and type(self:_api("MailFrameTab_OnClick")) == "function" then
        hooksecurefunc("MailFrameTab_OnClick", function(button, tabId)
            if self.enabled and Mail:IsGenerationCurrent(self.generation) then
                local index = tonumber(tabId)
                    or (button and type(button.GetID) == "function" and button:GetID())
                    or 1
                self:_showBaseTab(index, button or self:_baseButton(index))
            end
        end)
        self.standardFunctionHooked = true
    end
    self.standardHooksInstalled = true
end

function FrameHost:_captureBaseState(frame)
    if self.baseTabCount then return end
    self.baseTabCount = tonumber(frame.numTabs) or 2
    self.originalGeometry = nil
    self.originalTabs = nil
    self.createdTabsTable = false
    self:_saveGeometry(frame)
end

function FrameHost:_buildTabs()
    local frame = self:_api("MailFrame")
    local createFrame = self:_api("CreateFrame")
    if not frame or type(createFrame) ~= "function" then return false end
    self:_captureBaseState(frame)
    local baseCount = self.baseTabCount
    if self.originalTabs == nil and not self.createdTabsTable then
        self.originalTabs = frame.Tabs
        self.createdTabsTable = frame.Tabs == nil
    end
    frame.Tabs = frame.Tabs or {}
    for index = 1, baseCount do
        if not frame.Tabs[index] then
            frame.Tabs[index] = self:_api("MailFrameTab" .. index)
        end
    end
    self:_installStandardHooks()
    local previous = frame.Tabs[baseCount] or self:_api("MailFrameTab" .. baseCount)
    local activeCount = 0
    for i = 1, #self.tabs do
        local entry = self.tabs[i]
        if entry.registered and not entry.button then
            local safeId = string.gsub(entry.id, "[^%w_]", "_")
            entry.button = createFrame("Button", "EasyAuctionMailTab_" .. safeId, frame,
                "FriendsFrameTabTemplate")
            entry.button:SetScript("OnClick", function() self:ActivateTab(entry.id) end)
        end
        if entry.registered then
            activeCount = activeCount + 1
            local button = entry.button
            local tabIndex = baseCount + activeCount
            button:SetID(tabIndex)
            button:SetText(entry.label)
            button:ClearAllPoints()
            if previous then button:SetPoint("LEFT", previous, "RIGHT", -8, 0) end
            local skinCompat = self.deps.skinCompat or Mail.SkinCompat
            if skinCompat and type(skinCompat.SkinTab) == "function" then
                skinCompat:SkinTab(button)
            end
            button:Show()
            frame.Tabs[tabIndex] = button
            previous = button
            local vf = viewFrame(entry.view)
            if vf and vf.SetParent then vf:SetParent(frame) end
            callView(entry.view, "Hide")
        elseif entry.button then
            entry.button:Hide()
        end
    end
    for index = baseCount + activeCount + 1, tonumber(frame.numTabs) or baseCount do
        if frame.Tabs[index] and frame.Tabs[index].GetName
            and string.find(frame.Tabs[index]:GetName() or "", "^EasyAuctionMailTab_") then
            frame.Tabs[index] = nil
        end
    end
    frame.numTabs = baseCount + activeCount
    local setNumTabs = self:_api("PanelTemplates_SetNumTabs")
    if type(setNumTabs) == "function" then setNumTabs(frame, frame.numTabs) end
    return true
end

function FrameHost:_attachToMailFrame()
    local frame = self:_api("MailFrame")
    if not frame then return false end
    return self:_buildTabs()
end

function FrameHost:Enable(context)
    if self.enabled then return true end
    self.enabled = true
    self.generation = context and context.generation or self.generation
    local compat = self.deps.compat or Mail.Compat
    if compat and type(compat.RegisterMailLifecycle) == "function" then
        compat:RegisterMailLifecycle(self, function()
            self:ShowStandardTabs()
            self:_attachToMailFrame()
        end, function()
            self:ShowStandardTabs()
        end)
        self.lifecycleRegistered = true
    end
    self:_attachToMailFrame()
    return true
end

function FrameHost:Disable()
    if not self.enabled then return true end
    local preserveExternalGeometry = self.activeExternalButton ~= nil
    if self.activeTabId then
        local nativeTabClick = self:_api("MailFrameTab_OnClick")
        if type(nativeTabClick) == "function" then
            pcall(nativeTabClick, nil, 1)
        else
            local inbox = self:_api("InboxFrame")
            local send = self:_api("SendMailFrame")
            if inbox and inbox.Show then inbox:Show() end
            if send and send.Hide then send:Hide() end
            local setSendShowing = self:_api("SetSendMailShowing")
            if type(setSendShowing) == "function" then setSendShowing(false) end
        end
    end
    self:_hideCustomViews(nil, "MODULE_DISABLED")
    self.enabled = false
    self.activeTabId = nil
    for i = 1, #self.tabs do
        if self.tabs[i].button then self.tabs[i].button:Hide() end
    end
    local frame = self:_api("MailFrame")
    if frame then
        if not preserveExternalGeometry then self:_restoreGeometry(frame) end
        if self.baseTabCount then
            frame.numTabs = self.baseTabCount
            local setNumTabs = self:_api("PanelTemplates_SetNumTabs")
            if type(setNumTabs) == "function" then setNumTabs(frame, self.baseTabCount) end
        end
        if frame.Tabs and self.baseTabCount then
            for index = self.baseTabCount + 1, self.baseTabCount + #self.tabs do
                if frame.Tabs[index] and frame.Tabs[index].GetName
                    and string.find(frame.Tabs[index]:GetName() or "", "^EasyAuctionMailTab_") then
                    frame.Tabs[index] = nil
                end
            end
        end
        if self.createdTabsTable then
            frame.Tabs = nil
        elseif self.originalTabs then
            frame.Tabs = self.originalTabs
        end
    end
    local compat = self.deps.compat or Mail.Compat
    if self.lifecycleRegistered and compat and type(compat.UnregisterOwner) == "function" then
        compat:UnregisterOwner(self)
    end
    self.lifecycleRegistered = false
    self.baseTabCount = nil
    self.originalGeometry = nil
    self.originalTabs = nil
    self.createdTabsTable = false
    self.activeExternalButton = nil
    return true
end

Mail.MailFrameHost = FrameHost
Mail.FrameHost = Mail.FrameHost or FrameHost.New()
Mail:RegisterRuntimeModule("frame-host", Mail.FrameHost, 30)
