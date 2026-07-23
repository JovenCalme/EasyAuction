local addonName, NoWCL = ...
local C = {}
NoWCL.TeamBuffConfig = C
local U = NoWCL.Util
local T = NoWCL.TeamBuffs
local frame, rows = nil, {}
local providerSnapshot, previousSources = nil, {}
local FRAME_W, FRAME_H = 820, 600
local CONTENT_W, ROW_H = 756, 38
local CANDIDATE_ICON_SIZE, CANDIDATE_ICON_GAP = 18, 3
local AUDIENCE_LABELS = {
all="全团", mana="法力职业", spirit="精神职业", tank="坦克",
physical="物理/坦克", spell="法系/治疗", damage="输出/坦克",
}
local function canEdit()
local sync = NoWCL.Sync
return not (sync and sync.HasLeaderAuthority and sync:HasLeaderAuthority())
end
local function config()
return T and T:MonitorConfig() or {}
end
local function providerConfig()
return T and T:ProviderOverrideConfig() or {}
end
local function refreshProviderRoster()
local checks = NoWCL.ConsumableCheck
if checks and checks.Scan then
providerSnapshot = checks:Scan()
elseif checks and checks.GetSnapshot then
providerSnapshot = checks:GetSnapshot()
end
providerSnapshot = providerSnapshot or { players={}, teamBuffSources={} }
previousSources = checks and checks.PreviousBuffSources and checks:PreviousBuffSources() or {}
end
local function shortName(name)
name = tostring(name or "")
return name:match("^[^-]+") or name
end
local function providerLabel(player)
if not player then return "本团暂无可用负责人" end
local groupLabel = player.groupLabel or "0-0"
local icon = U and U.SpecIconTag and U.SpecIconTag(player.specId or player.readySpecId, 14) or ""
return groupLabel .. " " .. icon .. "「" .. shortName(player.name) .. "」"
end
local function candidatesFor(rule)
local roster = providerSnapshot and providerSnapshot.players or {}
local current = providerSnapshot and providerSnapshot.teamBuffSources or {}
if not (T and T.ProviderCandidates) then return {} end
local minStrength = T:ProviderStatus(rule, roster, 2) == "available" and 2 or 1
return T:ProviderCandidates(rule, roster, current, previousSources, nil, minStrength, true)
end
local function selectedProvider(rule)
local candidates = candidatesFor(rule)
return candidates[1] and candidates[1].player, candidates
end
local function setProvider(key, name)
if not (canEdit() and T and T.SetProviderOverride) then return end
T:SetProviderOverride(key, name)
if NoWCL.Sync then NoWCL.Sync:BroadcastConfig() end
C:Refresh()
if NoWCL.AuditUI and NoWCL.AuditUI.Refresh then NoWCL.AuditUI:Refresh() end
end
local function candidateSpellIds(rule)
local out, seen = {}, {}
local function add(spellId)
spellId = tonumber(spellId)
if not spellId or spellId <= 0 or seen[spellId] then return end
seen[spellId] = true
out[#out + 1] = spellId
end
local function addReminder(reminder)
if type(reminder) ~= "table" then
add(reminder)
return
end
local specIds = {}
for specId, spellId in pairs(reminder) do
if type(specId) == "number" then
specIds[#specIds + 1] = { specId=specId, spellId=spellId }
end
end
table.sort(specIds, function(a, b) return a.specId < b.specId end)
for _, item in ipairs(specIds) do add(item.spellId) end
add(reminder.default)
end
for _, provider in ipairs(rule.providers or {}) do
addReminder(rule.reminderIds and rule.reminderIds[provider.class])
end
return out
end
local function spellTexture(spellId)
if GetSpellTexture then
local ok, texture = pcall(GetSpellTexture, spellId)
if ok and texture then return texture end
end
if C_Spell and C_Spell.GetSpellTexture then
local ok, texture = pcall(C_Spell.GetSpellTexture, spellId)
if ok and texture then return texture end
end
if GetSpellInfo then
local ok, _, _, texture = pcall(GetSpellInfo, spellId)
if ok and texture then return texture end
end
return "Interface\\Icons\\INV_Misc_QuestionMark"
end
local function showCandidateTooltip(owner)
if not (GameTooltip and owner and owner.spellId) then return end
GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
GameTooltip:ClearLines()
local shown = false
if GameTooltip.SetHyperlink then
shown = pcall(GameTooltip.SetHyperlink, GameTooltip, "spell:" .. owner.spellId)
end
if not shown then
local name = GetSpellInfo and GetSpellInfo(owner.spellId)
GameTooltip:AddLine(name or ("法术 " .. owner.spellId), 1, 0.82, 0)
end
GameTooltip:AddLine("效果组候选：" .. (owner.ruleLabel or "团队 Buff"), 0.65, 0.82, 1)
GameTooltip:Show()
end
local function createCandidateIcon(parent, rule, spellId, index)
local button = CreateFrame("Button", nil, parent)
button:SetSize(CANDIDATE_ICON_SIZE, CANDIDATE_ICON_SIZE)
button:SetPoint("LEFT", parent, "LEFT", 158 + (index - 1) *
(CANDIDATE_ICON_SIZE + CANDIDATE_ICON_GAP), 7)
button.spellId = spellId
button.ruleLabel = rule.label or rule.key
button.icon = button:CreateTexture(nil, "ARTWORK")
button.icon:SetPoint("TOPLEFT", 1, -1)
button.icon:SetPoint("BOTTOMRIGHT", -1, 1)
button.icon:SetTexture(spellTexture(spellId))
button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
button:SetScript("OnEnter", showCandidateTooltip)
button:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
return button
end
local function invalidateChecks()
if NoWCL.ConsumableCheck then NoWCL.ConsumableCheck.snapshot = nil end
if NoWCL.Sync and NoWCL.Sync.InvalidateViewCache then NoWCL.Sync:InvalidateViewCache() end
end
local function setEnabled(key, enabled)
if not (canEdit() and T and T.SetMonitorEnabled) then return end
T:SetMonitorEnabled(key, enabled)
invalidateChecks()
if NoWCL.Sync then NoWCL.Sync:BroadcastConfig() end
C:Refresh()
if NoWCL.AuditUI and NoWCL.AuditUI.Refresh then NoWCL.AuditUI:Refresh() end
end
local function createRow(parent, index, rule)
local row = CreateFrame("Frame", nil, parent)
row:SetSize(CONTENT_W, ROW_H)
row.bg = row:CreateTexture(nil, "BACKGROUND")
row.bg:SetAllPoints()
local shade = index % 2 == 0 and 0.09 or 0.07
row.bg:SetColorTexture(shade, shade, 0.11, 0.92)
row.cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
row.cb:SetPoint("LEFT", 7, 0)
row.cb:SetSize(22, 22)
row.cb.key = rule.key
row.cb:SetScript("OnClick", function(self)
setEnabled(self.key, self:GetChecked() and true or false)
end)
row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
row.name:SetPoint("LEFT", 38, 7)
row.name:SetWidth(116)
row.name:SetJustifyH("LEFT")
row.name:SetText(rule.label or rule.key)
row.candidateIcons = {}
for candidateIndex, spellId in ipairs(candidateSpellIds(rule)) do
row.candidateIcons[#row.candidateIcons + 1] =
createCandidateIcon(row, rule, spellId, candidateIndex)
end
row.audience = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
row.audience:SetPoint("LEFT", 226, 7)
row.audience:SetWidth(96)
row.audience:SetJustifyH("LEFT")
row.audience:SetText(AUDIENCE_LABELS[rule.audience] or rule.audience or "-")
row.provider = U.MakeDropdown(row, 210)
row.provider:SetPoint("LEFT", 330, 7)
row.provider.itemsFn = function()
local selected, candidates = selectedProvider(rule)
local out = {}
for _, candidate in ipairs(candidates) do
out[#out + 1] = {
text=providerLabel(candidate.player), value=candidate.name,
checked=selected and selected.name == candidate.name,
}
end
return out
end
row.provider.onSelect = function(name) setProvider(rule.key, name) end
row.default = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
row.default:SetPoint("LEFT", 38, -9)
row.default:SetWidth(696)
row.default:SetJustifyH("LEFT")
row.default:SetText(rule.optional and "推荐默认关闭，可按团队需要启用" or "推荐默认监控")
rows[#rows + 1] = { frame=row, cb=row.cb, name=row.name, candidateIcons=row.candidateIcons,
audience=row.audience, provider=row.provider, default=row.default, rule=rule }
return row
end
local function Create()
local f = CreateFrame("Frame", "NoWCLTeamBuffCfgFrame", UIParent)
f:SetSize(FRAME_W, FRAME_H)
f:SetPoint("CENTER")
U.SetPanelLayer(f, true)
U.MakeMovable(f)
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
f.title:SetText("团队 Buff 监控设置")
local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -2, -2)
f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
f.hint:SetPoint("TOPLEFT", 14, -34)
f.hint:SetWidth(FRAME_W - 28)
f.hint:SetJustifyH("LEFT")
f.summary = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
f.summary:SetPoint("TOPLEFT", 14, -58)
f.summary:SetWidth(430)
f.summary:SetJustifyH("LEFT")
f.reset = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
f.reset:SetSize(150, 22)
f.reset:SetPoint("TOPRIGHT", -34, -52)
f.reset:SetText("恢复推荐默认")
f.reset:SetScript("OnClick", function()
if not (canEdit() and T and T.ResetMonitorConfig) then return end
T:ResetMonitorConfig()
invalidateChecks()
if NoWCL.Sync then NoWCL.Sync:BroadcastConfig() end
C:Refresh()
if NoWCL.AuditUI and NoWCL.AuditUI.Refresh then NoWCL.AuditUI:Refresh() end
end)
local head = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
head:SetPoint("TOPLEFT", 48, -82)
head:SetText("效果组")
local iconHead = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
iconHead:SetPoint("TOPLEFT", 168, -82)
iconHead:SetText("候选 Buff")
local audienceHead = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
audienceHead:SetPoint("TOPLEFT", 236, -82)
audienceHead:SetText("适用对象")
local providerHead = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
providerHead:SetPoint("TOPLEFT", 340, -82)
providerHead:SetText("当前负责")
f.providerReset = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
f.providerReset:SetSize(112, 20)
f.providerReset:SetPoint("LEFT", providerHead, "RIGHT", 8, 0)
f.providerReset:SetText("恢复智能默认")
f.providerReset:SetScript("OnClick", function()
if not (canEdit() and T and T.ResetProviderOverrides) then return end
T:ResetProviderOverrides()
if NoWCL.Sync then NoWCL.Sync:BroadcastConfig() end
C:Refresh()
if NoWCL.AuditUI and NoWCL.AuditUI.Refresh then NoWCL.AuditUI:Refresh() end
end)
local sf = CreateFrame("ScrollFrame", "NoWCLTeamBuffCfgScroll", f, "UIPanelScrollFrameTemplate")
sf:SetPoint("TOPLEFT", 10, -102)
sf:SetPoint("BOTTOMRIGHT", -28, 12)
local content = CreateFrame("Frame", nil, sf)
content:SetSize(CONTENT_W, 100)
sf:SetScrollChild(content)
f.scroll, f.content = sf, content
local y = -2
for i, rule in ipairs(T and T.RULES or {}) do
local row = createRow(content, i, rule)
row:SetPoint("TOPLEFT", 0, y)
y = y - ROW_H - 3
end
content:SetHeight(-y + 4)
tinsert(UISpecialFrames, "NoWCLTeamBuffCfgFrame")
f:Hide()
frame = f
if NoWCL.UIStyle and NoWCL.UIStyle.RegisterRoot then NoWCL.UIStyle:RegisterRoot(f) end
return f
end
function C:Refresh(rescan)
if not frame or not frame:IsShown() then return end
if rescan or not providerSnapshot then refreshProviderRoster() end
local editable, cfg, providerCfg = canEdit(), config(), providerConfig()
if editable then
if IsInGroup() and UnitIsGroupLeader("player") then
frame.hint:SetText("|cff44ff44你是团长：勾选结果会同步全团，并立即用于战前检查与单场记录。|r")
elseif IsInGroup() then
frame.hint:SetText("|cff44ff44团长未使用 NoWCL：本页设置只在你本端生效。|r")
else
frame.hint:SetText("|cff44ff44单人：本页设置只在你本端生效。|r")
end
else
frame.hint:SetText("|cffffd100以下团队监控项跟随团长（只读）。|r")
end
frame.summary:SetText((T and T:MonitorSummary(cfg) or "未加载") .. "；关闭的效果不会判定缺失，也不会进入催 Buff 计划。")
frame.reset:SetShown(editable)
frame.providerReset:SetShown(editable and T and T:HasProviderOverrides(providerCfg) or false)
for _, row in ipairs(rows) do
row.cb:SetChecked(T and T:IsMonitorEnabled(row.rule, cfg) or false)
if editable then row.cb:Enable() else row.cb:Disable() end
local alpha = editable and 1 or 0.62
local selected, candidates = selectedProvider(row.rule)
row.provider:SetText(providerLabel(selected))
if editable and #candidates > 0 then row.provider:Enable() else row.provider:Disable() end
row.name:SetAlpha(alpha); row.audience:SetAlpha(alpha)
row.provider:SetAlpha(alpha); row.default:SetAlpha(alpha)
for _, icon in ipairs(row.candidateIcons or {}) do icon:SetAlpha(alpha) end
end
end
function C:Toggle()
if not frame then Create() end
if frame:IsShown() then frame:Hide() else frame:Show(); C:Refresh(true) end
end
function C:Show()
if not frame then Create() end
frame:Show()
C:Refresh(true)
end
function C:CanEdit()
return canEdit()
end
