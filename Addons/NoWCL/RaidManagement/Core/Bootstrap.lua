local addonName, NoWCL = ...
local RM = NoWCL.RaidManagement or {}
NoWCL.RaidManagement = RM
RM.addonName = addonName
RM.version = "1.2.0.224"
RM.modules = RM.modules or {}
function RM:GetDB()
NoWCLRaidManagementDB = NoWCLRaidManagementDB or {}
local db = NoWCLRaidManagementDB
db.schema = math.max(2, tonumber(db.schema) or 1)
db.plans = type(db.plans) == "table" and db.plans or {}
db.reviews = type(db.reviews) == "table" and db.reviews or {}
db.settings = type(db.settings) == "table" and db.settings or {}
db.customSlotLayouts = type(db.customSlotLayouts) == "table" and db.customSlotLayouts or {}
db.positionProbe = nil
if db.settings.acceptLeaderPlans == nil then db.settings.acceptLeaderPlans = true end
if db.settings.autoSync == nil then db.settings.autoSync = true end
if db.settings.maxReviews == nil then db.settings.maxReviews = 30 end
db.settings.maxReviews = math.max(5, math.min(60, tonumber(db.settings.maxReviews) or 30))
db.settings.mapZoom = math.max(1, math.min(2, tonumber(db.settings.mapZoom) or 1))
db.settings.mapIconScale = nil
self.db = db
return db
end
function RM:GetNoWCLAPI()
return _G.NoWCL_API
end
function RM:Print(message)
DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff团战管理|r: " .. tostring(message))
end
function RM:Toast(message)
local api = self:GetNoWCLAPI()
if api and api.ShowToast and api:ShowToast(message, 3) then return true end
self:Print(message)
return false
end
function RM:Refresh()
if self.UI and self.UI.Refresh then self.UI:Refresh() end
end
local lifecycle = CreateFrame("Frame")
lifecycle:RegisterEvent("ADDON_LOADED")
lifecycle:RegisterEvent("PLAYER_LOGIN")
lifecycle:RegisterEvent("PLAYER_LOGOUT")
lifecycle:SetScript("OnEvent", function(_, event, arg1)
if event == "ADDON_LOADED" and arg1 == addonName then
RM:GetDB()
for _, module in ipairs(RM.modules) do
if module.OnLoad then module:OnLoad() end
end
elseif event == "PLAYER_LOGIN" then
local api = RM:GetNoWCLAPI()
if not api then
RM:Print("NoWCL 公共接口不可用，模块未启动。")
return
end
for _, module in ipairs(RM.modules) do
if module.OnLogin then module:OnLogin() end
end
elseif event == "PLAYER_LOGOUT" then
for _, module in ipairs(RM.modules) do
if module.OnLogout then module:OnLogout() end
end
end
end)
SLASH_NOWCLRAIDMANAGEMENT1 = "/nclraid"
SlashCmdList["NOWCLRAIDMANAGEMENT"] = function()
local api = RM:GetNoWCLAPI()
if api and api.OpenPrimaryPage then api:OpenPrimaryPage("raid_management") end
end
