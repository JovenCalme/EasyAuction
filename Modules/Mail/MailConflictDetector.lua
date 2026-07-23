local _, ns = ...
local Mail = ns.Mail

local Detector = {}
Detector.__index = Detector

local PROMPT_KEY = "EASYAUCTION_MAIL_CONFLICT_PROMPT"
local NOTICE_KEY = "EASYAUCTION_MAIL_CONFLICT_DISABLED_NOTICE"

local function externalDisableButtonText(snapshot)
    if snapshot and snapshot.bothLoaded then
        return "禁用 Postal/InboxMailBag"
    end
    local label = snapshot and snapshot.loadedAddonLabel or ""
    if label ~= "" then return "禁用 " .. label end
    return "禁用外部插件"
end

function Detector.New(api)
    return setmetatable({
        api = api or {},
        promptedThisSession = false,
        conflictDecision = nil,
        lastSnapshot = nil,
    }, Detector)
end

function Detector:IsLoaded(addonName)
    local cAddOns = self.api.C_AddOns or _G.C_AddOns
    local callback = cAddOns and cAddOns.IsAddOnLoaded
    if type(callback) ~= "function" then callback = self.api.IsAddOnLoaded or _G.IsAddOnLoaded end
    if type(callback) ~= "function" then return false end
    local ok, loaded = pcall(callback, addonName)
    return ok and loaded == true
end

function Detector:Snapshot()
    local postalLoaded = self:IsLoaded("Postal")
    local inboxLoaded = self:IsLoaded("InboxMailBag")
    local loadedAddons = {}
    if postalLoaded then loadedAddons[#loadedAddons + 1] = "Postal" end
    if inboxLoaded then loadedAddons[#loadedAddons + 1] = "InboxMailBag" end
    local clock = self.api.GetTime or _G.GetTime or _G.time
    local capturedAt = type(clock) == "function" and clock() or 0
    self.lastSnapshot = {
        postalLoaded = postalLoaded,
        inboxMailBagLoaded = inboxLoaded,
        anyLoaded = #loadedAddons > 0,
        bothLoaded = postalLoaded and inboxLoaded,
        loadedAddons = loadedAddons,
        loadedAddonLabel = table.concat(loadedAddons, "、"),
        capturedAt = capturedAt,
    }
    return self.lastSnapshot
end

function Detector:ShouldPrompt(snapshot, desiredEnabled, runtimeAvailable)
    return snapshot and snapshot.anyLoaded == true
        and desiredEnabled == true
        and runtimeAvailable == true
        and not self.promptedThisSession
end

function Detector:MarkPrompted(decision)
    self.promptedThisSession = true
    if decision ~= nil then self.conflictDecision = decision end
end

function Detector:GetDecision()
    return self.conflictDecision
end

function Detector:GetLastSnapshot()
    return self.lastSnapshot or self:Snapshot()
end

function Detector:UpdateSnapshot(cause)
    local snapshot = self:Snapshot()
    Mail:Publish("MAIL_EXTERNAL_STATUS_CHANGED", { snapshot = snapshot, cause = cause })
    return snapshot
end

function Detector:DisableExternalAddons(snapshot)
    snapshot = snapshot or self:GetLastSnapshot()
    local targets = snapshot and snapshot.loadedAddons
    if not snapshot or not snapshot.anyLoaded or type(targets) ~= "table" or #targets == 0 then
        return nil, Mail:NewError("MAIL_CONFLICT_NOT_PRESENT", "当前未加载可禁用的外部邮箱插件。")
    end
    for i = 1, #targets do
        if targets[i] ~= "Postal" and targets[i] ~= "InboxMailBag" then
            return nil, Mail:NewError("INVALID_EXTERNAL_ADDON_TARGET", "外部邮箱插件禁用目标无效。", {
                addonName = tostring(targets[i]),
            })
        end
    end

    local cAddOns = self.api.C_AddOns or _G.C_AddOns
    local disable = self.api.DisableAddOn or (cAddOns and cAddOns.DisableAddOn)
    local save = self.api.SaveAddOns or (cAddOns and cAddOns.SaveAddOns)
    local reload = self.api.ReloadUI or _G.ReloadUI
    if type(disable) ~= "function" then
        return nil, Mail:NewError("ADDON_DISABLE_UNAVAILABLE", "当前客户端无法禁用外部邮箱插件。")
    end
    if type(save) ~= "function" then
        return nil, Mail:NewError("ADDON_SAVE_UNAVAILABLE", "当前客户端无法保存插件启用状态。")
    end
    if type(reload) ~= "function" then
        return nil, Mail:NewError("RELOAD_UI_UNAVAILABLE", "当前客户端无法重新载入界面，未执行禁用操作。")
    end

    for i = 1, #targets do
        local addonName = targets[i]
        local ok, cause = pcall(disable, addonName)
        if not ok then
            return nil, Mail:NewError("ADDON_DISABLE_FAILED", "禁用 " .. addonName .. " 失败。", {
                addonName = addonName,
                cause = tostring(cause),
            })
        end
    end
    local saved, saveCause = pcall(save)
    if not saved then
        return nil, Mail:NewError("ADDON_SAVE_FAILED", "保存插件启用状态失败。", {
            cause = tostring(saveCause),
        })
    end
    local reloaded, reloadCause = pcall(reload)
    if not reloaded then
        return nil, Mail:NewError("RELOAD_UI_FAILED", "外部邮箱插件已禁用，但重新载入界面失败，请手动输入 /reload。", {
            cause = tostring(reloadCause),
        })
    end
    return true
end

function Detector._registerDialogs(_)
    _G.StaticPopupDialogs = _G.StaticPopupDialogs or {}
    _G.StaticPopupDialogs[PROMPT_KEY] = {
        text = "|cffffd100检测插件冲突|r\n\n"
            .. "已加载：|cffffffff%s|r\n\n"
            .. "EasyAuction已内置邮箱助手，解决卡拍卖",
        button1 = "忽略提示",
        button2 = "禁用邮箱助手",
        button3 = "禁用外部插件",
        selectCallbackByIndex = true,
        OnAccept = function(_, data)
            if data and data.detector then data.detector:MarkPrompted("ignore") end
            if data and type(data.onIgnore) == "function" then data.onIgnore() end
        end,
        OnCancel = function(_, data)
            if data and data.detector then data.detector:MarkPrompted("disable") end
            if data and type(data.onDisable) == "function" then data.onDisable() end
        end,
        OnButton3 = function(_, data)
            if data and data.detector then
                data.detector:MarkPrompted("disable_external")
            end
            local keepOpen = data and type(data.onDisableExternal) == "function"
                and data.onDisableExternal() == true
            if keepOpen and data and data.detector then
                data.detector:MarkPrompted("pending")
            end
            return keepOpen
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = false,
        preferredIndex = 3,
    }
    _G.StaticPopupDialogs[NOTICE_KEY] = {
        text = "|cff40ff40EasyAuction 邮箱功能已禁用。|r\n\n"
            .. "%s 仍在运行。使用全局扫描或拍卖行搜索时，建议开启“极简模式”。",
        button1 = "知道了",
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

function Detector:ShowPrompt(snapshot, onIgnore, onDisable, onDisableExternal)
    if not snapshot or not snapshot.anyLoaded then
        return nil, Mail:NewError("MAIL_CONFLICT_NOT_PRESENT", "当前未加载其它邮箱插件。")
    end
    self:_registerDialogs()
    _G.StaticPopupDialogs[PROMPT_KEY].button3 = externalDisableButtonText(snapshot)
    local show = self.api.StaticPopup_Show or _G.StaticPopup_Show
    if type(show) ~= "function" then
        return nil, Mail:NewError("POPUP_UNAVAILABLE", "无法显示邮箱冲突提示。")
    end
    self.promptedThisSession = true
    self.conflictDecision = "pending"
    local popup = show(PROMPT_KEY, snapshot.loadedAddonLabel, nil, {
        detector = self,
        snapshot = snapshot,
        onIgnore = onIgnore,
        onDisable = onDisable,
        onDisableExternal = onDisableExternal,
    })
    if not popup then
        self.promptedThisSession = false
        self.conflictDecision = nil
        return nil, Mail:NewError("POPUP_SHOW_FAILED", "邮箱冲突提示未能显示。")
    end
    return popup
end

function Detector:ShowDisabledNotice(snapshot)
    self:_registerDialogs()
    local show = self.api.StaticPopup_Show or _G.StaticPopup_Show
    if type(show) ~= "function" then return false end
    snapshot = snapshot or self:GetLastSnapshot()
    local label = snapshot and snapshot.loadedAddonLabel or "其它邮箱插件"
    if label == "" then label = "其它邮箱插件" end
    return show(NOTICE_KEY, label) ~= nil
end

Mail.MailConflictDetector = Detector
Mail.ConflictDetector = Mail.ConflictDetector or Detector.New()
