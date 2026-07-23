local addonName, NoWCL = ...
local T = {}
NoWCL.TaskConfig = T
local U = NoWCL.Util
local frame, rows = nil, {}
local FRAME_W, FRAME_H = 620, 560
local CONTENT_W = 558
local ROW_H = 44
local function canEdit()
return not (NoWCL.Sync and NoWCL.Sync.HasLeaderAuthority
and NoWCL.Sync:HasLeaderAuthority())
end
local function currentCfg()
if canEdit() then
NoWCL.db.settings.taskContrib = NoWCL.db.settings.taskContrib or {}
return NoWCL.db.settings.taskContrib
end
return (NoWCL.Sync and NoWCL.Sync.cfg and NoWCL.Sync.cfg.taskContrib) or {}
end
local function summary(cfg)
cfg = cfg or {}
local n = 0
for _, rule in ipairs(U.TASK_CONTRIB_RULES or {}) do
if cfg[rule.key] then n = n + 1 end
end
return n > 0 and ("已启用 " .. n .. " 项") or "未启用"
end
local function setEnabled(key, enabled)
if not canEdit() then return end
NoWCL.db.settings.taskContrib = NoWCL.db.settings.taskContrib or {}
NoWCL.db.settings.taskContrib[key] = enabled and true or nil
if NoWCL.Sync then NoWCL.Sync:BroadcastConfig() end
if NoWCL.Toast and NoWCL.Toast.BroadcastLeaderSetting then
local label,seconds=key,nil
for _,rule in ipairs(U.TASK_CONTRIB_RULES or {}) do
if rule.key==key then label=rule.label or key;seconds=tonumber(rule.seconds);break end
end
local detail=seconds and string.format("（等效 %.1f 秒）",seconds) or ""
NoWCL.Toast:BroadcastLeaderSetting("任务贡献换算已"..(enabled and "启用「" or "关闭「")
..label.."」"..detail)
end
T:Refresh()
if NoWCL.AuditUI and NoWCL.AuditUI.Refresh then NoWCL.AuditUI:Refresh() end
end
local function createRow(parent, index, rule)
local row = CreateFrame("Frame", nil, parent)
row:SetSize(CONTENT_W, ROW_H)
row.bg = row:CreateTexture(nil, "BACKGROUND")
row.bg:SetAllPoints()
row.bg:SetColorTexture(index % 2 == 0 and 0.09 or 0.07, index % 2 == 0 and 0.09 or 0.07, 0.11, 0.92)
row.cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
row.cb:SetPoint("TOPLEFT", 8, -7)
row.cb:SetSize(22, 22)
row.cb.key = rule.key
row.cb:SetScript("OnClick", function(self) setEnabled(self.key, self:GetChecked() and true or false) end)
row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
row.name:SetPoint("TOPLEFT", 40, -8)
row.name:SetWidth(126)
row.name:SetJustifyH("LEFT")
row.name:SetText(rule.label or rule.key)
row.sec = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
row.sec:SetPoint("TOPLEFT", 150, -9)
row.sec:SetWidth(54)
row.sec:SetJustifyH("RIGHT")
row.sec:SetText(string.format("%.1fs", rule.seconds or 0))
row.desc = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
row.desc:SetPoint("TOPLEFT", 220, -8)
row.desc:SetWidth(318)
row.desc:SetJustifyH("LEFT")
row.desc:SetText(rule.desc or "")
rows[#rows + 1] = { frame = row, cb = row.cb, name = row.name, sec = row.sec, desc = row.desc, rule = rule }
return row
end
local function Create()
local f = CreateFrame("Frame", "NoWCLTaskCfgFrame", UIParent)
f:SetSize(FRAME_W, FRAME_H)
f:SetPoint("CENTER")
U.SetPanelLayer(f,true)
NoWCL.Util.MakeMovable(f)
local bg = f:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(0.06, 0.06, 0.08, 0.97)
local tb = f:CreateTexture(nil, "ARTWORK")
tb:SetPoint("TOPLEFT")
tb:SetPoint("TOPRIGHT")
tb:SetHeight(26)
tb:SetColorTexture(0.12, 0.12, 0.16, 1)
f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
f.title:SetPoint("LEFT", tb, "LEFT", 10, 0)
f.title:SetText("额外任务贡献换算")
local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -2, -2)
f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
f.hint:SetPoint("TOPLEFT", 14, -34)
f.hint:SetWidth(FRAME_W - 28)
f.hint:SetJustifyH("LEFT")
f.warning = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
f.warning:SetPoint("TOPLEFT", 14, -58)
f.warning:SetWidth(FRAME_W - 28)
f.warning:SetJustifyH("LEFT")
f.warning:SetText("|cffffd100补偿伤害进入统计总值，勾选后和 WCL 总值会有补贴部分的差异。|r")
f.formula = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
f.formula:SetPoint("TOPLEFT", 14, -82)
f.formula:SetWidth(FRAME_W - 28)
f.formula:SetJustifyH("LEFT")
f.formula:SetText("换算:本人原始 DPS/HPS × 等效秒数；补偿量计入统计总值、排名与考核。")
f.summary = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
f.summary:SetPoint("TOPLEFT", 14, -106)
f.summary:SetWidth(FRAME_W - 28)
f.summary:SetJustifyH("LEFT")
local sf = CreateFrame("ScrollFrame", "NoWCLTaskCfgScroll", f, "UIPanelScrollFrameTemplate")
sf:SetPoint("TOPLEFT", 10, -136)
sf:SetPoint("BOTTOMRIGHT", -28, 12)
f.scroll = sf
local content = CreateFrame("Frame", nil, sf)
content:SetSize(CONTENT_W, 100)
f.content = content
sf:SetScrollChild(content)
local y = -2
for i, rule in ipairs(U.TASK_CONTRIB_RULES or {}) do
local row = createRow(content, i, rule)
row:SetPoint("TOPLEFT", 0, y)
y = y - ROW_H - 4
end
content:SetHeight(-y + 4)
tinsert(UISpecialFrames, "NoWCLTaskCfgFrame")
f:Hide()
frame = f
if NoWCL.UIStyle and NoWCL.UIStyle.RegisterRoot then NoWCL.UIStyle:RegisterRoot(f) end
return f
end
function T:Refresh()
if not frame or not frame:IsShown() then return end
local editable = canEdit()
local cfg = currentCfg()
if editable then
if IsInGroup() and UnitIsGroupLeader("player") then
frame.hint:SetText("|cff44ff44你是团长:可编辑任务贡献换算,改动会自动同步全团。|r")
elseif IsInGroup() then
frame.hint:SetText("|cff44ff44团长未使用 NoWCL:本页设置只在你本端生效。|r")
else
frame.hint:SetText("|cff44ff44单人:本页设置只在你本端生效。|r")
end
else
frame.hint:SetText("|cffffd100以下为团长设置(只读,跟随团长同步)。|r")
end
frame.summary:SetText("当前启用: " .. summary(cfg))
for _, row in ipairs(rows) do
row.cb:SetChecked(cfg and cfg[row.rule.key])
if editable then
row.cb:Enable()
row.name:SetTextColor(1.0, 0.82, 0.0)
row.sec:SetTextColor(1.0, 1.0, 1.0)
row.desc:SetTextColor(0.75, 0.75, 0.75)
else
row.cb:Disable()
row.name:SetTextColor(0.65, 0.65, 0.65)
row.sec:SetTextColor(0.65, 0.65, 0.65)
row.desc:SetTextColor(0.5, 0.5, 0.5)
end
end
end
function T:Toggle()
if not frame then Create() end
if frame:IsShown() then
frame:Hide()
else
frame:Show()
T:Refresh()
end
end
function T:Show()
if not frame then Create() end
frame:Show()
T:Refresh()
end
