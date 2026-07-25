local _, ns = ...
local Mail = ns.Mail

local Settings = {}
Settings.__index = Settings

local DISABLE_PROMPT_KEY = "EASYAUCTION_MAIL_DISABLE_CONFIRM"
local FEATURE_RUNTIME_IDS = { inbox = "inbox", bulk = "bulk-mail" }

function Settings.New(deps)
    return setmetatable({ deps = deps or {}, controls = nil }, Settings)
end

function Settings:_config()
    return self.deps.config or Mail.Config
end

function Settings:_controller()
    return self.deps.controller or Mail.ModuleController
end

function Settings:_detector()
    return self.deps.conflictDetector or Mail.ConflictDetector
end

function Settings:Initialize()
    local config = self:_config()
    if config then config:Initialize() end
    return true
end

function Settings:GetEnabled()
    local config = self:_config()
    return config and config:GetEnabled() or false
end

function Settings:GetFeatureEnabled(feature)
    local config = self:_config()
    return config and config:GetFeatureEnabled(feature) or false
end

function Settings:GetComposeOption(option)
    local config = self:_config()
    return config and config:GetComposeOption(option) or false
end

function Settings:SetComposeOption(option, enabled)
    if type(enabled) ~= "boolean" then
        return nil, Mail:NewError("INVALID_ENABLED_VALUE", "发件快捷开关必须是 boolean。")
    end
    local config = self:_config()
    local saved, err = config:SetComposeOption(option, enabled)
    if not saved then return nil, err end
    self:RefreshControls()
    return true
end

function Settings:SetFeatureEnabled(feature, enabled, reason)
    if type(enabled) ~= "boolean" or not FEATURE_RUNTIME_IDS[feature] then
        return nil, Mail:NewError("INVALID_ENABLED_VALUE", "邮箱子功能开关无效。")
    end
    local config = self:_config()
    local previous = config:GetFeatureEnabled(feature)
    local saved, saveError = config:SetFeatureEnabled(feature, enabled)
    if not saved then return nil, saveError end

    local controller = self:_controller()
    if controller and type(controller.SetRuntimeModuleEnabled) == "function" then
        local changed, changeError = controller:SetRuntimeModuleEnabled(
            FEATURE_RUNTIME_IDS[feature], enabled, reason or "SETTINGS")
        if not changed then
            config:SetFeatureEnabled(feature, previous)
            return nil, changeError
        end
    end
    self:RefreshControls()
    return true
end

function Settings:SetEnabled(enabled, reason)
    if type(enabled) ~= "boolean" then
        return nil, Mail:NewError("INVALID_ENABLED_VALUE", "邮箱开关必须是 boolean。")
    end
    local controller = self:_controller()
    local state = controller and controller:GetState()
    if state == Mail.RuntimeState.DISABLING or state == Mail.RuntimeState.ENABLING then
        return nil, Mail:NewError("MODULE_TRANSITION_BUSY", "邮箱模块正在切换状态，请稍后重试。")
    end
    local config = self:_config()
    local saved, saveError = config:SetEnabled(enabled)
    if not saved then return nil, saveError end
    if not controller then return true end
    if enabled then
        local runtimeState, runtimeError = controller:RequestEnable(reason or "SETTINGS")
        if not runtimeState then return nil, runtimeError end
    else
        local _, disableError = controller:Disable(reason or "SETTINGS")
        if disableError then return nil, disableError end
    end
    self:RefreshControls()
    return true
end

function Settings._registerDisablePrompt(_)
    _G.StaticPopupDialogs = _G.StaticPopupDialogs or {}
    _G.StaticPopupDialogs[DISABLE_PROMPT_KEY] = {
        text = "当前有邮件操作正在进行。关闭邮箱功能后将停止新操作，并等待当前操作得到明确结果或超时。已提交但无法确认的金币邮件可能记为“未知”，请勿直接重复发送。\n\n确定关闭 EasyAuction 邮箱功能？",
        button1 = "确认关闭",
        button2 = "取消",
        OnAccept = function(_, data)
            if data and data.settings then data.settings:SetEnabled(false, data.reason) end
        end,
        OnCancel = function(_, data)
            if data and data.settings then data.settings:RefreshControls() end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = false,
        preferredIndex = 3,
    }
end

function Settings:RequestSetEnabled(enabled, reason)
    if enabled then return self:SetEnabled(true, reason or "SETTINGS") end
    local arbiter = self.deps.arbiter or Mail.WriteArbiter
    if arbiter and arbiter:GetOwner() then
        self:_registerDisablePrompt()
        local show = self.deps.StaticPopup_Show or _G.StaticPopup_Show
        if type(show) ~= "function" then
            return nil, Mail:NewError("POPUP_UNAVAILABLE", "无法显示邮箱关闭确认。")
        end
        local popup = show(DISABLE_PROMPT_KEY, nil, nil, {
            settings = self,
            reason = reason or "SETTINGS",
        })
        if not popup then return nil, Mail:NewError("POPUP_SHOW_FAILED", "邮箱关闭确认未能显示。") end
        self:RefreshControls()
        return true
    end
    return self:SetEnabled(false, reason or "SETTINGS")
end

function Settings:GetRuntimeStatus()
    local controller = self:_controller()
    return controller and controller:GetState() or Mail.RuntimeState.UNINITIALIZED
end

function Settings:GetExternalStatus()
    local detector = self:_detector()
    return detector and detector:GetLastSnapshot() or {
        postalLoaded = false,
        inboxMailBagLoaded = false,
        anyLoaded = false,
        bothLoaded = false,
        loadedAddons = {},
        loadedAddonLabel = "",
        capturedAt = 0,
    }
end

local STATUS_TEXT = {
    UNINITIALIZED = "等待初始化",
    DISABLED_ROLLOUT = "配置已保存，当前构建未启用",
    WAITING_CONFLICT_DECISION = "等待处理邮箱插件冲突",
    ENABLING = "正在启用",
    ENABLED = "已启用",
    DISABLING = "正在停止当前邮件操作",
    DISABLED = "已禁用",
}

function Settings:RefreshControls()
    local controls = self.controls
    if not controls then return end
    if controls.toggle and controls.toggle.SetChecked then controls.toggle:SetChecked(self:GetEnabled()) end
    if controls.inboxToggle and controls.inboxToggle.SetChecked then
        controls.inboxToggle:SetChecked(self:GetFeatureEnabled("inbox"))
    end
    if controls.bulkToggle and controls.bulkToggle.SetChecked then
        controls.bulkToggle:SetChecked(self:GetFeatureEnabled("bulk"))
    end
    if controls.enableAltClickToggle and controls.enableAltClickToggle.SetChecked then
        controls.enableAltClickToggle:SetChecked(self:GetComposeOption("enableAltClick"))
    end
    if controls.autoSendToggle and controls.autoSendToggle.SetChecked then
        controls.autoSendToggle:SetChecked(self:GetComposeOption("autoSend"))
    end
    local state = self:GetRuntimeStatus()
    if controls.toggle and controls.toggle.SetEnabled then
        controls.toggle:SetEnabled(state ~= Mail.RuntimeState.ENABLING
            and state ~= Mail.RuntimeState.DISABLING
            and state ~= Mail.RuntimeState.WAITING_CONFLICT_DECISION)
    end
    local featureControlsEnabled = state ~= Mail.RuntimeState.ENABLING
        and state ~= Mail.RuntimeState.DISABLING
        and state ~= Mail.RuntimeState.WAITING_CONFLICT_DECISION
    if controls.inboxToggle and controls.inboxToggle.SetEnabled then
        controls.inboxToggle:SetEnabled(featureControlsEnabled)
    end
    if controls.bulkToggle and controls.bulkToggle.SetEnabled then
        controls.bulkToggle:SetEnabled(featureControlsEnabled)
    end
    if controls.enableAltClickToggle and controls.enableAltClickToggle.SetEnabled then
        controls.enableAltClickToggle:SetEnabled(featureControlsEnabled)
    end
    if controls.autoSendToggle and controls.autoSendToggle.SetEnabled then
        controls.autoSendToggle:SetEnabled(featureControlsEnabled
            and self:GetComposeOption("enableAltClick"))
    end
    local external = self:GetExternalStatus()
    local text = STATUS_TEXT[state] or state
    if external.anyLoaded and state ~= Mail.RuntimeState.WAITING_CONFLICT_DECISION then
        text = text .. "；已加载 " .. (external.loadedAddonLabel or "其它邮箱插件")
    end
    if controls.status and controls.status.SetText then controls.status:SetText(text) end
end

-- EasyFrame 只需把其设置页 parent 传入；视觉仍使用客户端原生控件。
function Settings:CreateControls(parent, options)
    options = options or {}
    if not parent or type(_G.CreateFrame) ~= "function" then
        return nil, Mail:NewError("SETTINGS_PARENT_UNAVAILABLE", "邮箱设置页容器不可用。")
    end
    if self.controls then return self.controls.container end
    local container = _G.CreateFrame("Frame", nil, parent, "BackdropTemplate")
    container:SetSize(options.width or 300, options.height or (options.compact and 38 or 160))
    if options.point then container:SetPoint(unpack(options.point)) end
    local title = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", options.compact and 8 or 12, options.compact and -4 or -10)
    title:SetText(options.compact and "邮箱" or "邮箱功能")
    local style = _G.EasyAuctionStyle
    if style and type(style.SkinText) == "function" then style:SkinText(title, "accent") end
    local function createToggle(labelText, compactX, expandedY, onClick)
        local button = _G.CreateFrame("CheckButton", nil, container, "UICheckButtonTemplate")
        button:SetSize(20, 20)
        if options.compact then
            button:SetPoint("TOPLEFT", container, "TOPLEFT", compactX, -1)
        else
            button:SetPoint("TOPLEFT", container, "TOPLEFT", 12, expandedY)
        end
        local label = button.Text
        if type(label) ~= "table" or type(label.SetPoint) ~= "function" then
            label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        end
        if label.ClearAllPoints then label:ClearAllPoints() end
        label:SetPoint("LEFT", button, "RIGHT", 2, 0)
        label:SetText(labelText)
        if style and type(style.SkinText) == "function" then style:SkinText(label, "text") end
        button:SetScript("OnClick", onClick)
        return button
    end
    local toggle = createToggle(options.compact and "总" or "启用邮箱功能", 44, -32,
        function(button)
            local requested = button:GetChecked() == true
            local ok = self:RequestSetEnabled(requested, "SETTINGS")
            if not ok then button:SetChecked(self:GetEnabled()) end
        end)
    local inboxToggle = createToggle(options.compact and "闪收" or "启用闪收", 82, -60, function(button)
        local requested = button:GetChecked() == true
        local ok = self:SetFeatureEnabled("inbox", requested, "SETTINGS")
        if not ok then button:SetChecked(self:GetFeatureEnabled("inbox")) end
    end)
    local bulkToggle = createToggle(options.compact and "闪寄" or "启用闪寄", 132, -88, function(button)
        local requested = button:GetChecked() == true
        local ok = self:SetFeatureEnabled("bulk", requested, "SETTINGS")
        if not ok then button:SetChecked(self:GetFeatureEnabled("bulk")) end
    end)
    local shortcutTitle
    if not options.compact then
        shortcutTitle = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        shortcutTitle:SetPoint("TOPLEFT", container, "TOPLEFT", 12, -118)
        shortcutTitle:SetText("一键发件")
        if style and type(style.SkinText) == "function" then style:SkinText(shortcutTitle, "accent") end
    end
    local enableAltClickToggle = createToggle(options.compact and "Alt附件" or "Alt+左键快速附件",
        182, -136, function(button)
        local requested = button:GetChecked() == true
        local ok = self:SetComposeOption("enableAltClick", requested)
        if not ok then button:SetChecked(self:GetComposeOption("enableAltClick")) end
    end)
    local autoSendToggle = createToggle(options.compact and "自动" or "附件后自动发送",
        238, -164, function(button)
        local requested = button:GetChecked() == true
        local ok = self:SetComposeOption("autoSend", requested)
        if not ok then button:SetChecked(self:GetComposeOption("autoSend")) end
    end)
    local function setHelp(button, titleText, bodyText)
        button:SetScript("OnEnter", function()
            if not _G.GameTooltip then return end
            _G.GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            _G.GameTooltip:SetText(titleText)
            _G.GameTooltip:AddLine(bodyText, 1, 1, 1, true)
            _G.GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function()
            if _G.GameTooltip then _G.GameTooltip:Hide() end
        end)
    end
    setHelp(enableAltClickToggle, "Alt 点击附件",
        "开启后，Alt+左键点击背包物品可将其放入当前邮件。")
    setHelp(autoSendToggle, "Alt 点击后自动发送",
        "附件确认成功且收件人不为空时，自动发送当前邮件。")
    local status = container:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    if options.compact then
        status:SetPoint("TOPLEFT", container, "TOPLEFT", 8, -24)
    else
        status:SetPoint("TOPLEFT", container, "TOPLEFT", 12, -196)
    end
    status:SetWidth((options.width or 300) - 16)
    status:SetJustifyH("LEFT")
    status:SetWordWrap(not options.compact)
    status:SetText("")
    self.controls = {
        container = container,
        toggle = toggle,
        inboxToggle = inboxToggle,
        bulkToggle = bulkToggle,
        enableAltClickToggle = enableAltClickToggle,
        autoSendToggle = autoSendToggle,
        status = status,
    }
    Mail:Subscribe("MAIL_MODULE_STATE_CHANGED", self, function() self:RefreshControls() end)
    Mail:Subscribe("MAIL_EXTERNAL_STATUS_CHANGED", self, function() self:RefreshControls() end)
    self:RefreshControls()
    return container
end

function Settings:AttachToEasyAuctionConfig()
    local frame = _G.EasyAuctionConfigFrame
    local modernPage = frame and frame.mailSettingsHost
    local page = modernPage or (frame and frame.pages and frame.pages.addon)
    if not page then return false end
    local container, err = self:CreateControls(page, {
        width = modernPage and 402 or 304,
        height = modernPage and 220 or 38,
        compact = not modernPage,
        point = { "TOPLEFT", page, "TOPLEFT", 0, modernPage and -18 or -528 },
    })
    if not container then return nil, err end
    local style = _G.EasyAuctionStyle
    if style and type(style.SkinExistingFrame) == "function" then
        style:SkinExistingFrame(container, "panel")
    end
    return true
end

function Settings:InstallConfigHook()
    if Mail.__SettingsHostHookInstalled then return true end
    if type(_G.CreateEasyAuctionConfigFrame) ~= "function"
        or type(_G.hooksecurefunc) ~= "function" then
        return false
    end
    _G.hooksecurefunc("CreateEasyAuctionConfigFrame", function()
        Mail.Settings:AttachToEasyAuctionConfig()
    end)
    Mail.__SettingsHostHookInstalled = true
    if _G.EasyAuctionConfigFrame then self:AttachToEasyAuctionConfig() end
    return true
end

Mail.MailSettings = Settings
Mail.Settings = Mail.Settings or Settings.New()
Mail.Settings:InstallConfigHook()
