local addonName, NoWCL = ...
local UI = {}
NoWCL.UI = UI
local frame
local TITLE_LOGO = "Interface\\AddOns\\" .. addonName .. "\\Media\\logo.tga"
local function Create()
local f = CreateFrame("Frame", "NoWCLDebugFrame", UIParent)
f:SetSize(560, 360); f:SetPoint("CENTER")
NoWCL.Util.SetPanelLayer(f); f:SetMovable(true); f:EnableMouse(true)
NoWCL.Util.MakeMovable(f)
f:SetClampedToScreen(true)
local bg = f:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.05,0.05,0.07,0.92)
local tb = f:CreateTexture(nil, "ARTWORK"); tb:SetPoint("TOPLEFT"); tb:SetPoint("TOPRIGHT"); tb:SetHeight(26); tb:SetColorTexture(0.12,0.12,0.16,1)
local logo = f:CreateTexture(nil, "OVERLAY"); logo:SetSize(18,18); logo:SetPoint("LEFT", tb, "LEFT", 8, 0); logo:SetTexture(TITLE_LOGO)
local tt = f:CreateFontString(nil, "OVERLAY", "GameFontNormal"); tt:SetPoint("LEFT", logo, "RIGHT", 6, 0); tt:SetText("NoWCL 自检 (debug)")
local close = CreateFrame("Button", nil, f, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", -2, -2)
local c = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
c:SetPoint("TOPLEFT", 14, -36); c:SetPoint("BOTTOMRIGHT", -14, 14); c:SetJustifyH("LEFT"); c:SetJustifyV("TOP")
f.content = c
f.elapsed = 0
f:SetScript("OnUpdate", function(self, dt)
self.elapsed = self.elapsed + dt
if self.elapsed < 0.5 then return end
self.elapsed = 0; UI:Refresh()
end)
tinsert(UISpecialFrames, "NoWCLDebugFrame")
f:Hide()
if NoWCL.UIStyle and NoWCL.UIStyle.RegisterRoot then NoWCL.UIStyle:RegisterRoot(f) end
return f
end
function UI:Refresh()
if not frame or not frame:IsShown() then return end
local players, dur
if NoWCL.Stats.GetDisplayPlayers then players, dur = NoWCL.Stats:GetDisplayPlayers()
else players, dur = NoWCL.Stats:GetPlayers() end
local nplayers = 0; for _ in ipairs(players) do nplayers = nplayers + 1 end
local lines = {
"高级战斗记录: " .. (NoWCL:IsAdvancedLoggingOn() and "|cff44ff44开|r" or "|cffff4444关|r")
.. "   统计引擎: NoWCL 内建"
.. "   团长: " .. (NoWCL.Util.IsRaidLeader("player") and "是" or "否"),
"当前段: " .. NoWCL.Stats:SegmentName() .. "  时长: " .. NoWCL.Util.FmtTime(dur) .. "  玩家数: " .. nplayers,
"对齐档案: " .. NoWCL.Profiles:ActiveName(),
"",
"玩家            伤害      DPS    活跃  打断 驱散 死",
}
table.sort(players, function(a,b) return (a.dmg or 0) > (b.dmg or 0) end)
for i, pl in ipairs(players) do
if i > 12 then break end
lines[#lines+1] = string.format("%-14s %7s %7s  %3s   %d   %d  %d",
(pl.name or "?"):sub(1,14), NoWCL.Util.Short(pl.dmg), NoWCL.Util.Short(pl.dps),
NoWCL.Util.Pct2(pl.activePct), pl.interrupts, pl.dispels, pl.deaths)
end
frame.content:SetText(table.concat(lines, "\n"))
end
function UI:Toggle()
if not frame then frame = Create() end
if frame:IsShown() then frame:Hide() else frame:Show(); UI:Refresh() end
end
do local _9nbhxrq16=("T".."ENX".."b04=");local _kqzxlrebd="1799a51c5922a860ea63b151" end
