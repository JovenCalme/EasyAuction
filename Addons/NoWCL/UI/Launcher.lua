local addonName, NoWCL = ...
local L = {}
NoWCL.Launcher = L
local ICON = "Interface\\AddOns\\NoWCL\\Media\\logo.tga"
local DEFAULT_ANGLE = -0.75
local RADIUS = 80
local dataObject, minimapButton
local function launcherDB()
if not NoWCL.db then return nil end
NoWCL.db.window = NoWCL.db.window or {}
NoWCL.db.window.launcher = NoWCL.db.window.launcher or {}
local db = NoWCL.db.window.launcher
if db.minimapShown == nil then db.minimapShown = true end
db.minimapAngle = db.minimapAngle or DEFAULT_ANGLE
return db
end
local function openFull()
if NoWCL.MiniUI and NoWCL.MiniUI.Hide then NoWCL.MiniUI:Hide() end
if NoWCL.AuditUI and NoWCL.AuditUI.ShowFull then
NoWCL.AuditUI:ShowFull("current")
elseif NoWCL.AuditUI and NoWCL.AuditUI.Toggle then
NoWCL.AuditUI:Toggle()
end
end
local function openMini()
if NoWCL.AuditUI and NoWCL.AuditUI.Hide then NoWCL.AuditUI:Hide() end
if NoWCL.MiniUI and NoWCL.MiniUI.Show then
NoWCL.MiniUI:Show()
elseif NoWCL.MiniUI and NoWCL.MiniUI.Toggle then
NoWCL.MiniUI:Toggle()
else
NoWCL:Print("竖窗未就绪")
end
end
local function openStatsConfig()
if NoWCL.StatsConfig and NoWCL.StatsConfig.Toggle then
NoWCL.StatsConfig:Toggle()
else
openFull()
end
end
local function handleClick(button)
if button == "RightButton" then
openMini()
elseif button == "MiddleButton" then
openStatsConfig()
else
openFull()
end
end
local function tooltip(owner)
GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
GameTooltip:AddLine("NoWCL")
GameTooltip:AddLine("左键:打开战斗记录", 0.85, 0.85, 0.85)
GameTooltip:AddLine("右键:打开竖窗", 0.85, 0.85, 0.85)
GameTooltip:AddLine("中键:统计口径设置", 0.85, 0.85, 0.85)
GameTooltip:AddLine("/ncl minimap 隐藏/显示小地图按钮", 0.55, 0.75, 1.00)
GameTooltip:Show()
end
local function placeMinimapButton()
if not minimapButton or not Minimap then return end
local db = launcherDB()
local angle = (db and db.minimapAngle) or DEFAULT_ANGLE
minimapButton:ClearAllPoints()
minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * RADIUS, math.sin(angle) * RADIUS)
end
local function saveAngleFromCursor()
if not minimapButton or not Minimap then return end
local scale = UIParent:GetEffectiveScale() or 1
local x, y = GetCursorPosition()
x, y = x / scale, y / scale
local cx, cy = Minimap:GetCenter()
if not cx or not cy then return end
local dx, dy = x - cx, y - cy
local angle
if math.atan2 then
angle = math.atan2(dy, dx)
elseif dx == 0 then
angle = dy >= 0 and (math.pi / 2) or (-math.pi / 2)
else
angle = math.atan(dy / dx)
if dx < 0 then angle = angle + math.pi end
end
local db = launcherDB()
if db then db.minimapAngle = angle end
placeMinimapButton()
end
local function createMinimapButton()
if minimapButton or not Minimap then return end
local db = launcherDB()
if db and not db.minimapShown then return end
local b = CreateFrame("Button", "NoWCLMinimapButton", Minimap)
b:SetSize(31, 31)
b:SetFrameStrata("MEDIUM")
b:SetFrameLevel((Minimap:GetFrameLevel() or 0) + 8)
b:RegisterForClicks("AnyUp")
b:RegisterForDrag("LeftButton")
b.icon = b:CreateTexture(nil, "BACKGROUND")
b.icon:SetSize(20, 20)
b.icon:SetPoint("CENTER", 0, 0)
b.icon:SetTexture(ICON)
b.border = b:CreateTexture(nil, "OVERLAY")
b.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
b.border:SetSize(52, 52)
b.border:SetPoint("TOPLEFT", 0, 0)
b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
b:SetScript("OnClick", function(self, button)
if self.suppressClick then
self.suppressClick = nil
return
end
handleClick(button)
end)
b:SetScript("OnEnter", function(self) tooltip(self) end)
b:SetScript("OnLeave", function() GameTooltip:Hide() end)
b:SetScript("OnDragStart", function(self)
self.dragging = true
self:SetScript("OnUpdate", saveAngleFromCursor)
end)
b:SetScript("OnDragStop", function(self)
self.dragging = nil
self.suppressClick = true
self:SetScript("OnUpdate", nil)
saveAngleFromCursor()
end)
b:SetScript("OnMouseUp", function(self)
if self.dragging then
self.dragging = nil
self.suppressClick = true
self:SetScript("OnUpdate", nil)
saveAngleFromCursor()
end
end)
minimapButton = b
placeMinimapButton()
end
local function ensureBroker()
if dataObject or not LibStub then return end
local broker = LibStub("LibDataBroker-1.1", true)
if not broker then return end
dataObject = broker:NewDataObject("NoWCL", {
type = "launcher",
text = "NoWCL",
icon = ICON,
OnClick = function(_, button) handleClick(button) end,
OnTooltipShow = function(tt)
tt:AddLine("NoWCL")
tt:AddLine("左键:打开战斗记录", 0.85, 0.85, 0.85)
tt:AddLine("右键:打开竖窗", 0.85, 0.85, 0.85)
tt:AddLine("中键:统计口径设置", 0.85, 0.85, 0.85)
end,
})
end
function L:Init()
if self.inited then return end
self.inited = true
ensureBroker()
createMinimapButton()
if C_Timer and C_Timer.After then
C_Timer.After(1.5, ensureBroker)
end
end
function L:ToggleMinimap()
local db = launcherDB()
if not db then return end
db.minimapShown = not db.minimapShown
if db.minimapShown then
createMinimapButton()
if minimapButton then minimapButton:Show(); placeMinimapButton() end
NoWCL:Print("已显示小地图按钮。")
else
if minimapButton then minimapButton:Hide() end
NoWCL:Print("已隐藏小地图按钮。")
end
end
