local _, ns = ...
local Mail = ns.Mail

local Bootstrap = {}
Bootstrap.__index = Bootstrap

function Bootstrap.New(deps)
    return setmetatable({
        deps = deps or {},
        initialized = false,
        addonInitialized = false,
        playerLoggedIn = false,
        frame = nil,
    }, Bootstrap)
end

function Bootstrap:_config()
    return self.deps.config or Mail.Config
end

function Bootstrap:_settings()
    return self.deps.settings or Mail.Settings
end

function Bootstrap:_controller()
    return self.deps.controller or Mail.ModuleController
end

function Bootstrap:_detector()
    return self.deps.conflictDetector or Mail.ConflictDetector
end

function Bootstrap:OnAddonLoaded(addonName)
    if addonName == Mail.ADDON_NAME and not self.addonInitialized then
        self:_config():Initialize()
        self:_settings():Initialize()
        self:_controller():Initialize()
        self.addonInitialized = true
        return true
    end
    if addonName == "Postal" or addonName == "InboxMailBag" then
        local retry = function()
            local config = self:_config()
            if config and type(config.RetryLegacyMigrations) == "function" then
                config:RetryLegacyMigrations()
            end
            if self.playerLoggedIn then
                self:_detector():UpdateSnapshot("ADDON_LOADED:" .. addonName)
            end
        end
        local after = self.deps.After or (_G.C_Timer and _G.C_Timer.After)
        if type(after) == "function" then after(0, retry) else retry() end
    end
    if addonName == "NDui" then
        local skinCompat = Mail.SkinCompat
        if skinCompat and type(skinCompat.Refresh) == "function" then
            local after = self.deps.After or (_G.C_Timer and _G.C_Timer.After)
            local refresh = function() skinCompat:Refresh() end
            if type(after) == "function" then after(1, refresh) else refresh() end
        end
    end
    return false
end

function Bootstrap:_showConflictPrompt()
    local detector = self:_detector()
    local snapshot = detector:GetLastSnapshot()
    local popup, promptError = detector:ShowPrompt(snapshot,
        function()
            self:_controller():ResolveConflict("ignore")
        end,
        function()
            local saved, err = self:_settings():SetEnabled(false, "LOGIN_CONFLICT")
            if not saved and err then
                local message = err.message or "禁用邮箱模块失败。"
                if type(_G.print) == "function" then
                    _G.print("|cffff4040[EasyAuction 邮箱]|r " .. message)
                end
                return
            end
            detector:ShowDisabledNotice(snapshot)
        end,
        function()
            local disabled, err = detector:DisableExternalAddons(snapshot)
            if disabled then return false end
            local message = err and err.message or "禁用外部邮箱插件失败。"
            if type(_G.print) == "function" then
                _G.print("|cffff4040[EasyAuction 邮箱]|r " .. message)
            end
            return true
        end)
    if not popup then
        local settings = self:_settings()
        if settings and type(settings.SetEnabled) == "function" then
            settings:SetEnabled(false, "CONFLICT_PROMPT_FAILED")
        end
        if type(_G.print) == "function" then
            _G.print("|cffff4040[EasyAuction 邮箱]|r 无法显示冲突选择框，已安全禁用自身邮箱模块。可在 EasyAuction 设置中重新启用。")
        end
        return nil, promptError or Mail:NewError("POPUP_SHOW_FAILED", "邮箱冲突提示未能显示。")
    end
    return popup
end

function Bootstrap:OnPlayerLogin()
    if self.playerLoggedIn then return false end
    if not self.addonInitialized then self:OnAddonLoaded(Mail.ADDON_NAME) end
    self.playerLoggedIn = true
    local config = self:_config()
    if config and type(config.RetryLegacyMigrations) == "function" then
        config:RetryLegacyMigrations()
    end
    local controller = self:_controller()
    local state, err = controller:RequestEnable("PLAYER_LOGIN")
    if not state then return nil, err end
    if state == Mail.RuntimeState.WAITING_CONFLICT_DECISION then
        return self:_showConflictPrompt()
    end
    return true
end

function Bootstrap:Initialize()
    if self.initialized then return true end
    self.initialized = true
    local createFrame = self.deps.CreateFrame or _G.CreateFrame
    if type(createFrame) ~= "function" then return false end
    self.frame = createFrame("Frame")
    self.frame:RegisterEvent("ADDON_LOADED")
    self.frame:RegisterEvent("PLAYER_LOGIN")
    self.frame:SetScript("OnEvent", function(_, event, ...)
        if event == "ADDON_LOADED" then
            self:OnAddonLoaded(...)
        elseif event == "PLAYER_LOGIN" then
            self.frame:UnregisterEvent("PLAYER_LOGIN")
            local after = self.deps.After or (_G.C_Timer and _G.C_Timer.After)
            if type(after) == "function" then
                after(0, function() self:OnPlayerLogin() end)
            else
                self:OnPlayerLogin()
            end
        end
    end)
    return true
end

Mail.MailBootstrap = Bootstrap
Mail.Bootstrap = Mail.Bootstrap or Bootstrap.New()
Mail.Bootstrap:Initialize()
