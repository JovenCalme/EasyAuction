local addonName, NoWCL = ...
NoWCL.version = "1.2.0.224"
NoWCL.addonName = addonName
function NoWCL:Print(msg)
local text = "|cff33ff99NoWCL|r: " .. tostring(msg)
if SendSystemMessage then
SendSystemMessage(text)
return
end
local frame = SELECTED_CHAT_FRAME
if not (frame and frame.AddMessage) then frame = DEFAULT_CHAT_FRAME end
if frame and frame.AddMessage then frame:AddMessage(text) end
end
function NoWCL:IsAdvancedLoggingOn()
return GetCVar("advancedCombatLogging") == "1"
end
local function InitDB()
NoWCLDB = NoWCLDB or {}
local db = NoWCLDB
db.loadCount    = (db.loadCount or 0) + 1
db.activeProfile = db.activeProfile or "WCL-2026.06"
db.rulesets     = db.rulesets or {}
db.activeRuleset = db.activeRuleset or "default"
db.settings     = db.settings or {
dpsBaseline = "rank1",
dpsRatio    = 0.60,
dpsMode     = "boss",
}
if db.settings.dpsMode == nil then db.settings.dpsMode = "boss" end
local profile = db.settings.bossProfile
if profile ~= "wcl45Boss" and profile ~= "wclDamageDone" then
profile = "wclDamageDone"
end
db.settings.bossProfile = profile
db.settings.bossCfg = db.settings.bossCfg or {}
db.settings.bossCfg.__profile = profile
db.settings.roleOverride = db.settings.roleOverride or {}
db.settings.taskContrib = db.settings.taskContrib or {}
db.settings.teamBuffChecks = db.settings.teamBuffChecks or {}
db.settings.teamBuffProviderOverrides = db.settings.teamBuffProviderOverrides or {}
if db.settings.autoSelfBuffReminder == nil then db.settings.autoSelfBuffReminder = false end
db.settings.autoSelfBuffReminderMinutes = math.max(1, math.min(10,
math.floor(tonumber(db.settings.autoSelfBuffReminderMinutes) or 5)))
if db.settings.teamAnnouncementDefaultsV1 ~= true then
db.settings.deathAnnounce = false
db.settings.performanceAnnounce = false
db.settings.failureAnnounce = false
db.settings.teamAnnouncementDefaultsV1 = true
end
if db.settings.deathAnnounce == nil then db.settings.deathAnnounce = false end
if db.settings.performanceAnnounce == nil then db.settings.performanceAnnounce = false end
if db.settings.failureAnnounce == nil then db.settings.failureAnnounce = false end
if db.settings.rulesAnnounce == nil then db.settings.rulesAnnounce = false end
if db.settings.pullStartAnnounce == nil then db.settings.pullStartAnnounce = false end
db.settings.rulesAnnouncementText = tostring(db.settings.rulesAnnouncementText or "")
db.settings.performanceRankingMode = db.settings.performanceRankingMode == "all" and "all" or "split"
db.settings.performanceScope = db.settings.performanceScope == "summary" and "summary" or "fight"
db.settings.performanceTopCount = math.max(1, math.min(8,
math.floor(tonumber(db.settings.performanceTopCount) or 3)))
if db.settings.failureDps == nil then db.settings.failureDps = true end
if db.settings.failureActivity == nil then db.settings.failureActivity = true end
db.settings.failureScope = db.settings.failureScope == "summary" and "summary" or "fight"
if db.settings.autoPrune30 == nil then db.settings.autoPrune30 = true end
if db.settings.autoClearNewRaidCD == nil then db.settings.autoClearNewRaidCD = false end
if db.settings.detailSelfBuffOnly == nil then db.settings.detailSelfBuffOnly = false end
if db.settings.showAllCharacterFights == nil then db.settings.showAllCharacterFights = false end
if db.settings.whisperGearPromptDefaultsV2 ~= true then
db.settings.whisperGearPrompt = true
db.settings.whisperGearPromptDefaultsV2 = true
end
if db.settings.whisperGearPrompt == nil then db.settings.whisperGearPrompt = true end
db.settings.pullAnnounce = nil
db.pullAnnounceDebug = nil
db.pullRelayProbe = nil
db.settings.checks = db.settings.checks or {
active = { on=true, v=0.5 },
}
db.window       = db.window or {}
if db.window.opacity == nil then db.window.opacity = 0.70 end
if db.window.opaqueRows == nil then db.window.opaqueRows = true end
if db.window.numberUnits ~= "mk" then db.window.numberUnits = "cn" end
if db.window.panelLayer ~= "high" and db.window.panelLayer ~= "top" then db.window.panelLayer = "system" end
local hoverModes={hover=true,ctrl=true,alt=true,disabled=true}
if db.window.inspectHoverDefaultsV2~=true then
db.window.gearInspectHoverMode="disabled"
db.window.damageInspectHoverMode="disabled"
db.window.inspectHoverDefaultsV2=true
end
if not hoverModes[db.window.gearInspectHoverMode] then db.window.gearInspectHoverMode="disabled" end
if not hoverModes[db.window.damageInspectHoverMode] then db.window.damageInspectHoverMode="disabled" end
if db.window.damageInspectHoverMode~="disabled"
and db.window.damageInspectHoverMode==db.window.gearInspectHoverMode then
db.window.damageInspectHoverMode=db.window.gearInspectHoverMode=="ctrl" and "alt" or "ctrl"
end
NoWCL.db = db
if NoWCL.UIStyle and NoWCL.UIStyle.EnsureDefaults then NoWCL.UIStyle:EnsureDefaults() end
end
local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("PLAYER_LOGIN")
boot:RegisterEvent("PLAYER_LOGOUT")
boot:SetScript("OnEvent", function(self, event, arg1)
if event == "ADDON_LOADED" and arg1 == addonName then
InitDB()
if NoWCL.Rules and NoWCL.Rules.EnsureDefault then NoWCL.Rules:EnsureDefault() end
if NoWCL.Stats and NoWCL.Stats.Restore then NoWCL.Stats:Restore() end
if NoWCL.Readiness and NoWCL.Readiness.Restore then NoWCL.Readiness:Restore() end
if NoWCL.Sync and NoWCL.Sync.Restore then NoWCL.Sync:Restore() end
elseif event == "PLAYER_LOGIN" then
if NoWCL.AzerothHistory and NoWCL.AzerothHistory.Init then NoWCL.AzerothHistory:Init() end
if NoWCL.ReleaseProtection and NoWCL.ReleaseProtection.ReportFailures then
NoWCL.ReleaseProtection:ReportFailures()
end
NoWCL:Print("v" .. NoWCL.version .. " 已加载。|cffffd100/ncl|r 打开审核页,|cffffd100/ncl mini|r 打开竖窗,|cffffd100/ncl debug|r 自检。")
if NoWCL.Comm and NoWCL.Comm.Init then NoWCL.Comm:Init() end
if NoWCL.Comm and NoWCL.Comm.UsingChatThrottleLib and not NoWCL.Comm:UsingChatThrottleLib() then
NoWCL:Print("|cffffaa00通讯稳定性提示|r:未检测到 ChatThrottleLib。为提高团队同步稳定性,建议单独安装或启用包含该库的插件。")
end
if NoWCL.Sync and NoWCL.Sync.Init then NoWCL.Sync:Init() end
if NoWCL.AnnouncementElection and NoWCL.AnnouncementElection.Init then
NoWCL.AnnouncementElection:Init()
end
if NoWCL.Readiness and NoWCL.Readiness.Init then NoWCL.Readiness:Init() end
if NoWCL.ConsumableCheck and NoWCL.ConsumableCheck.Init then NoWCL.ConsumableCheck:Init() end
if NoWCL.Stats and NoWCL.Stats.ValidateRestoredActive then NoWCL.Stats:ValidateRestoredActive() end
if NoWCL.Toast and NoWCL.Toast.Init then NoWCL.Toast:Init() end
if NoWCL.RaidAutoClear and NoWCL.RaidAutoClear.Init then NoWCL.RaidAutoClear:Init() end
if NoWCL.Launcher and NoWCL.Launcher.Init then NoWCL.Launcher:Init() end
elseif event == "PLAYER_LOGOUT" then
if NoWCL.Readiness and NoWCL.Readiness.Persist then NoWCL.Readiness:Persist() end
if NoWCL.Sync and NoWCL.Sync.Persist then NoWCL.Sync:Persist() end
if NoWCL.Stats and NoWCL.Stats.FlushActiveSegment then NoWCL.Stats:FlushActiveSegment() end
if NoWCL.Stats and NoWCL.Stats.Persist then NoWCL.Stats:Persist() end
end
end)
SLASH_NOWCL1 = "/ncl"
SLASH_NOWCL2 = "/nowcl"
SLASH_NOWCL3 = "/nwcl"
SlashCmdList["NOWCL"] = function(msg)
msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
if msg == "debug" then
if NoWCL.UI and NoWCL.UI.Toggle then NoWCL.UI:Toggle() end
elseif msg == "mini" then
if NoWCL.MiniUI and NoWCL.MiniUI.Toggle then
NoWCL.MiniUI:Toggle()
else
NoWCL:Print("竖窗未就绪")
end
elseif msg == "minimap" then
if NoWCL.Launcher and NoWCL.Launcher.ToggleMinimap then
NoWCL.Launcher:ToggleMinimap()
else
NoWCL:Print("启动器未就绪")
end
elseif msg == "sync" then
if NoWCL.Sync then NoWCL.Sync:RequestResync() end
NoWCL:Print("已请求重新同步。")
elseif msg == "dump" then
NoWCLDB.debug = nil
NoWCL:Print("已清空抓包样本,打几下木桩会自动重新采集,然后 /reload。")
elseif msg == "synctest" then
local U = NoWCL.Util
local v = NoWCL.Sync:GetView("all", false)
NoWCL:Print(string.format("同步自检 — %s,%d 人(权威端:%s):",
v.encounter or "?", #(v.players or {}), v.leader and "本机" or "团长"))
for _, p in ipairs(v.players or {}) do
NoWCL:Print(string.format("  %s  伤害%s 对Boss%s  活跃%s %s  %s",
p.name, U.Short(p.dmg or 0), U.Short(p.dmgBoss or 0), U.Pct(p.activePct or 0),
p.actEst and "|cffff8800估算~|r" or "|cff88ff88自报|r",
p.ver and ("|cff888888v"..p.ver.."|r") or "|cff555555(无NoWCL)|r"))
end
else
if NoWCL.AuditUI and NoWCL.AuditUI.Toggle then
NoWCL.AuditUI:Toggle()
else
NoWCL:Print("审核页未就绪")
end
end
end
do local _4ghmmxboj="\076\067\087\111\078";local _9dbdm8j4v="a09ec1c906b3f4e30d6df944" end
