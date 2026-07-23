local addonName, NoWCL = ...
local A = {}
NoWCL.AuditUI = A
local U = NoWCL.Util
local Style = NoWCL.UIStyle
local D = NoWCL.DetailStats
local T = NoWCL.TeamBuffs
local TITLE_LOGO = "Interface\\AddOns\\" .. addonName .. "\\Media\\logo.tga"
A.sel = "all"
A.detailPlayer = nil
A.comparePlayer = nil
A.currentMode = nil
StaticPopupDialogs["NOWCL_CLEAR_TABS"] = {
text = "清空所有 Tab 记录?(团本前重置)\n你自己的记录会删除;团员对应页面会置灰(不删)。",
button1 = "清空", button2 = "取消",
OnAccept = function() NoWCL.Sync:ClearTabs(); A.sel = "all"; A:Refresh() end,
timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}
StaticPopupDialogs["NOWCL_CLEAR_CURRENT_TAB"] = {
text = "清空当前 Tab:%s?\n只删除你本机这个战斗页,不会影响其他人的记录。",
button1 = "清空", button2 = "取消",
OnAccept = function(self, data)
local fid = data and data.fightId
if fid then NoWCL.Sync:ClearTab(fid) end
A.sel = "all"; A.detailPlayer = nil; A.comparePlayer = nil; A:Refresh()
end,
timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}
StaticPopupDialogs["NOWCL_PRUNE_TO_30"] = {
text = "启用“保留最近30场”会立即删除最旧的 %d 场战斗记录。\n此操作不能撤销，是否继续？",
button1 = "启用并淘汰", button2 = "取消",
OnAccept = function()
NoWCL.db.settings.autoPrune30 = true
if NoWCL.Sync and NoWCL.Sync.PruneTabs then NoWCL.Sync:PruneTabs(30) end
if NoWCL.Stats and NoWCL.Stats.PruneHistory then NoWCL.Stats:PruneHistory(30) end
A:Refresh()
end,
OnCancel = function()
NoWCL.db.settings.autoPrune30 = false
A:Refresh()
end,
timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}
StaticPopupDialogs["NOWCL_REMIND_ALL_BUFFS"] = {
text = "这将向全团中需要补充自身 Buff、以及负责为他人补 Buff 的团员发送密语。是否继续？",
button1 = "确认发送", button2 = "取消",
OnAccept = function()
if NoWCL.AuditUI and NoWCL.AuditUI.ConfirmFullBuffReminder then
NoWCL.AuditUI:ConfirmFullBuffReminder()
end
end,
timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}
local COLS = {
{ "name","玩家",112,"LEFT",98,0.7 }, { "assessment","考核",58,"CENTER",54,0.2 },
{ "amount","总量",238,"LEFT",185,3.0 }, { "ilvl","装等",44,"CENTER",40,0 },
{ "lowq","蓝绿·附魔·宝石",108,"CENTER",100,0.4 }, { "consumables","食·药·爆",86,"CENTER",80,0.2 },
{ "teamBuff","团队Buff",120,"CENTER",100,1.3 }, { "active","活跃",62,"CENTER",58,0.2 },
{ "dps","DPS/HPS",88,"CENTER",78,0.7 }, { "extra","额外任务",110,"LEFT",92,1.0 },
{ "death","死亡",38,"CENTER",34,0 }, { "tag","标记",62,"LEFT",54,0.5 },
}
local COL_NAME, COL_ASSESSMENT, COL_AMOUNT, COL_ILVL = 1, 2, 3, 4
local COL_LOWQ, COL_CONSUMABLES, COL_TEAM_BUFF, COL_ACTIVE = 5, 6, 7, 8
local COL_RATE, COL_EXTRA, COL_DEATH, COL_TAG = 9, 10, 11, 12
local READY_CHECK_MISSING = "Interface\\RaidFrame\\ReadyCheck-NotReady"
local DEFAULT_ROWH = 18
local RANK_SPARK_COLUMNS = 16
local DETAIL_TIMELINE_COLUMNS = 240
local RANK_SPARK_VALUE_W = 42
local RANK_SPARK_GAP = 3
local AUDIT_BOTTOM_PAD = 24
local SCROLLBAR_GUTTER = 28
local DETAIL_LIST_FRAME_TOP = 328
local PREVIOUS_FIGHT_HOLD_SECONDS = 60
local CURRENT_READINESS_SCAN_SECONDS = 3
local REMIND_BUTTON_COOLDOWN_SECONDS = 5
local EQUIP_SLOTS = { 1,2,3,5,6,7,8,9,10,11,12,13,14,15,16,17,18 }
local frame, rows, selBtns = nil, {}, {}
local extensionPages = {}
local COLUMN_GAP = 4
local function hasLeaderAuthority()
local sync = NoWCL.Sync
return sync and sync.HasLeaderAuthority and sync:HasLeaderAuthority() or false
end
local function auditWindowState()
if not (NoWCL.db and NoWCL.db.window) then return nil end
NoWCL.db.window.audit = NoWCL.db.window.audit or {}
return NoWCL.db.window.audit
end
local function columnSum(field)
local total = 0
for _, col in ipairs(COLS) do total = total + (tonumber(col[field]) or 0) end
return total
end
local function auditWidthChrome()
return SCROLLBAR_GUTTER + 24 + (#COLS - 1) * COLUMN_GAP
end
local function clampAuditWidth(value)
local minW = columnSum(5) + auditWidthChrome()
local maxW = math.max(minW, (UIParent:GetWidth() or 1920) * 0.96)
return math.max(minW, math.min(tonumber(value) or minW, maxW))
end
local function clampAuditHeight(value)
local maxH = (UIParent:GetHeight() or 768) * 0.92
return math.max(420, math.min(tonumber(value) or 600, maxH))
end
local function fitColumnsToWidth(windowWidth)
local target = math.max(columnSum(5), clampAuditWidth(windowWidth) - auditWidthChrome())
local base, minimum = 0, 0
for _, col in ipairs(COLS) do
col._base = col._base or col[3]
base = base + col._base
minimum = minimum + col[5]
end
if target <= base then
local ratio = base > minimum and (target - minimum) / (base - minimum) or 0
for _, col in ipairs(COLS) do
col[3] = math.floor(col[5] + (col._base - col[5]) * ratio + 0.5)
end
else
local weight = 0
for _, col in ipairs(COLS) do
col[3] = col._base
weight = weight + (col[6] or 0)
end
local extra = target - base
if weight > 0 then
for _, col in ipairs(COLS) do col[3] = math.floor(col[3] + extra * (col[6] or 0) / weight + 0.5) end
end
end
local delta = target - columnSum(3)
COLS[COL_AMOUNT][3] = COLS[COL_AMOUNT][3] + delta
end
local function playerInCombat()
if InCombatLockdown and InCombatLockdown() then return true end
return UnitAffectingCombat and UnitAffectingCombat("player") and true or false
end
local function currentLiveVisible()
return NoWCL.Stats and NoWCL.Stats.IsCurrentSegmentVisible
and NoWCL.Stats:IsCurrentSegmentVisible() and true or false
end
local function currentPreviousRecord()
return NoWCL.Stats and NoWCL.Stats.lastCurrentSegment or nil
end
local function currentPreviousAge()
local previous = currentPreviousRecord()
local endedAt = previous and tonumber(previous.ts)
if not endedAt or endedAt <= 0 then return math.huge end
return math.max(0, (time and time() or endedAt) - endedAt)
end
local function syncCurrentRecordIdentity()
local previous = currentPreviousRecord()
if A._currentRecordRef ~= previous then
A._currentRecordRef = previous
local keepStatus = A.currentMode == "status"
and not (previous and (previous.isBoss or previous.isDummy))
if not keepStatus then A.currentMode = nil end
if NoWCL.ConsumableCheck then NoWCL.ConsumableCheck.snapshot = nil end
end
end
local function currentStatusActive()
syncCurrentRecordIdentity()
if currentLiveVisible() or playerInCombat() then return false end
if A.currentMode == "status" then return true end
local previous = currentPreviousRecord()
return not previous or currentPreviousAge() >= PREVIOUS_FIGHT_HOLD_SECONDS
end
local function currentSwitchRemaining()
if A.currentMode == "status" or currentLiveVisible() or playerInCombat() or not currentPreviousRecord() then return 0 end
return math.max(0, math.ceil(PREVIOUS_FIGHT_HOLD_SECONDS - currentPreviousAge()))
end
local function scanCurrentStatus()
if currentLiveVisible() or playerInCombat() then return nil end
A.currentMode = "status"
A.detailPlayer = nil
A.comparePlayer = nil
local snapshot = NoWCL.ConsumableCheck and NoWCL.ConsumableCheck:Scan() or nil
if frame and frame.listScroll then frame.listScroll:SetVerticalScroll(0) end
return snapshot
end
function A:ActivateCurrentStatus()
A.currentMode = "status"
A._currentRecordRef = currentPreviousRecord()
A.detailPlayer = nil
A.comparePlayer = nil
local checker = NoWCL.ConsumableCheck
if checker then
checker.snapshot = nil
if not currentLiveVisible() and not playerInCombat()
and A.sel == "current" and frame and frame:IsShown() then
checker:Scan()
end
end
if NoWCL.Readiness and NoWCL.Readiness.RequestRosterScan then
NoWCL.Readiness:RequestRosterScan()
end
if frame and frame.listScroll then frame.listScroll:SetVerticalScroll(0) end
A:Refresh()
end
local function auditRowHeight()
return (Style and Style.FullRowHeight and Style:FullRowHeight()) or DEFAULT_ROWH
end
local function auditFillHeight()
return (Style and Style.FullFillHeight and Style:FullFillHeight()) or 14
end
local function auditDetailFillHeight()
return (Style and Style.FullDetailFillHeight and Style:FullDetailFillHeight()) or 14
end
local function colX(idx) local x=8 for i=1,idx-1 do x=x+COLS[i][3]+COLUMN_GAP end return x end
local BASE_NAMES = { rank1="第一名", rank2="第二名", average="平均", median="中位数", tank="坦克" }
local BASE_OPTS = { {text="第一名",value="rank1"}, {text="第二名",value="rank2"}, {text="平均",value="average"}, {text="中位数",value="median"}, {text="坦克",value="tank"} }
local function ratioOpts()
if NoWCL.db.settings.dpsBaseline=="tank" then
return { {text="100%",value=1.0}, {text="150%",value=1.5}, {text="200%",value=2.0} }
end
return { {text="50%",value=0.5}, {text="60%",value=0.6}, {text="70%",value=0.7}, {text="75%",value=0.75} }
end
local function makeFS(parent, col)
local fs = parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
fs:SetPoint("LEFT", parent, "LEFT", colX(col), 0); fs:SetWidth(COLS[col][3]); fs:SetJustifyH(COLS[col][4])
return fs
end
local function classRGB(class)
if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
local c = RAID_CLASS_COLORS[class]
return c.r or 0.55, c.g or 0.62, c.b or 0.85
end
return 0.55, 0.62, 0.85
end
local function rowOpaque()
return U.WindowOpaqueRows and U.WindowOpaqueRows()
end
local function applyAuditRowStyle(row, index)
local h = auditRowHeight()
row:SetHeight(h)
row:ClearAllPoints()
row:SetPoint("TOPLEFT", 0, -(index - 1) * h)
row:SetPoint("TOPRIGHT", 0, -(index - 1) * h)
if row.amountBarBg then row.amountBarBg:SetHeight(auditFillHeight()) end
if row.amountBar then
if Style and Style.ApplyTexture then Style:ApplyTexture(row.amountBar, 0.55, 0.62, 0.85, 0.9) end
row.amountBar:SetHeight(auditFillHeight())
end
if row.sparkBars then
local sparkH = math.max(4, math.min(h - 2, auditFillHeight()))
for _, bar in ipairs(row.sparkBars) do bar:SetHeight(sparkH) end
end
if row.teamBuffHit then row.teamBuffHit:SetHeight(h) end
if row.gearAuditHit then row.gearAuditHit:SetHeight(h) end
if row.nameHit then row.nameHit:SetHeight(h) end
if Style and Style.ApplyFont then
for _, fs in ipairs(row.cells or {}) do Style:ApplyFont(fs, -1) end
Style:ApplyFont(row.amountVal, -1)
for _, fs in ipairs(row.consumableDots or {}) do Style:ApplyFont(fs, -1) end
for _, fs in ipairs(row.consumableMarks or {}) do Style:ApplyFont(fs, -1) end
end
end
local function resolveGearAudit(pl)
pl=pl or {}
local details=pl.gearKey and NoWCL.Readiness and NoWCL.Readiness.AuditGearSet
and NoWCL.Readiness:AuditGearSet(pl.gearKey) or nil
local lowQuality=pl.lowQuality
local missEnch=pl.missEnch
local emptyGems=pl.emptyGems
if details then
if lowQuality==nil then lowQuality=details.lowQuality end
missEnch=details.missEnch
emptyGems=details.emptyGems
end
return {
player=pl.name,lowQuality=lowQuality,missEnch=missEnch,emptyGems=emptyGems,
known=details~=nil or pl.gearAuditKnown==true or (missEnch~=nil and emptyGems~=nil),
lowQualityItems=details and details.lowQualityItems,
missingEnchantSlots=details and details.missingEnchantSlots,
emptyGemSlots=details and details.emptyGemSlots,
hasDetails=details~=nil,
}
end
local function showGearAuditTooltip(owner)
local audit=owner and owner.auditSummary
if not (audit and GameTooltip) then return end
GameTooltip:SetOwner(owner,"ANCHOR_RIGHT")
GameTooltip:ClearLines()
GameTooltip:AddLine((audit.player or "玩家").."  装备检查",1,0.82,0)
if audit.lowQuality==nil then
GameTooltip:AddLine("蓝绿装：等待装备快照",0.55,0.55,0.58)
else
GameTooltip:AddLine("蓝绿装："..audit.lowQuality,audit.lowQuality>0 and 1 or 0.85,
audit.lowQuality>0 and 0.67 or 0.85,audit.lowQuality>0 and 0 or 0.85)
if audit.lowQuality>0 then
for _,item in ipairs(audit.lowQualityItems or {}) do
GameTooltip:AddLine((item.name or "部位").."  "..(item.link or ""),1,1,1,true)
end
end
end
if audit.missEnch==nil then
GameTooltip:AddLine("缺失附魔：等待装备快照",0.55,0.55,0.58)
else
GameTooltip:AddLine("缺失附魔："..audit.missEnch,audit.missEnch>0 and 1 or 0.85,
audit.missEnch>0 and 0.3 or 0.85,audit.missEnch>0 and 0.3 or 0.85)
if audit.missEnch>0 and #(audit.missingEnchantSlots or {})>0 then
local names={}
for _,item in ipairs(audit.missingEnchantSlots) do names[#names+1]=item.name or "?" end
GameTooltip:AddLine(table.concat(names,"、"),1,0.55,0.55,true)
end
end
if audit.emptyGems==nil then
GameTooltip:AddLine("空宝石孔：等待装备快照",0.55,0.55,0.58)
else
GameTooltip:AddLine("空宝石孔："..audit.emptyGems,audit.emptyGems>0 and 1 or 0.85,
audit.emptyGems>0 and 0.3 or 0.85,audit.emptyGems>0 and 0.3 or 0.85)
if audit.emptyGems>0 and #(audit.emptyGemSlots or {})>0 then
local names={}
for _,item in ipairs(audit.emptyGemSlots) do
names[#names+1]=(item.name or "?")..((item.count or 0)>1 and (" "..item.count) or "")
end
GameTooltip:AddLine(table.concat(names,"、"),1,0.55,0.55,true)
end
end
if audit.known and not audit.hasDetails and ((audit.lowQuality or 0)>0 or (audit.missEnch or 0)>0 or (audit.emptyGems or 0)>0) then
GameTooltip:AddLine("本机没有该场完整装备链接，暂时无法列出全部部位。",0.55,0.55,0.58,true)
end
GameTooltip:Show()
end
local function gearMetricText(value,color)
if value==nil then return "|cff666666…|r" end
if value>0 then return color..tostring(value).."|r" end
return "0"
end
local function renderGearAudit(row,pl,dim)
local audit=resolveGearAudit(pl)
row.gearAuditHit.auditSummary=audit
row.cells[COL_LOWQ]:SetText(gearMetricText(audit.lowQuality,"|cffffaa00")
.."|cff888888·|r"..gearMetricText(audit.missEnch,"|cffff5555")
.."|cff888888·|r"..gearMetricText(audit.emptyGems,"|cffff5555"))
row.cells[COL_LOWQ]:SetTextColor(dim and 0.55 or 0.9,dim and 0.55 or 0.9,dim and 0.55 or 0.9)
end
local function getRow(i, parent)
if rows[i] then return rows[i] end
local b = CreateFrame("Button", nil, parent)
U.RegisterOpacityChromeHover(frame, b)
b.bg = b:CreateTexture(nil,"BACKGROUND"); b.bg:SetAllPoints()
b.cells = {}; for c=1,#COLS do b.cells[c]=makeFS(b,c) end
b.nameHit=CreateFrame("Frame",nil,b)
b.nameHit:SetPoint("LEFT",b,"LEFT",colX(COL_NAME),0)
b.nameHit:SetSize(COLS[COL_NAME][3],auditRowHeight())
b.nameHit:SetFrameLevel(b:GetFrameLevel()+3);b.nameHit:EnableMouse(true)
b.nameHit:SetScript("OnEnter",function()
if b.playerName and NoWCL.GearInspectPanel and NoWCL.GearInspectPanel.BeginPlayerNameHover then
NoWCL.GearInspectPanel:BeginPlayerNameHover(
b.playerName,b.playerClass,b.playerSpecId,frame,b.nameHit,
{viewProvider=b.damageViewProvider,selection=A.sel})
end
end)
b.nameHit:SetScript("OnLeave",function()
if NoWCL.GearInspectPanel and NoWCL.GearInspectPanel.EndPlayerNameHover then
NoWCL.GearInspectPanel:EndPlayerNameHover(b.nameHit)
end
end)
b.nameHit:SetScript("OnMouseUp",function(_,button)
local fn=b:GetScript("OnClick");if fn then fn(b,button) end
end)
if b.cells[COL_TEAM_BUFF].SetWordWrap then b.cells[COL_TEAM_BUFF]:SetWordWrap(false) end
if b.cells[COL_TEAM_BUFF].SetNonSpaceWrap then b.cells[COL_TEAM_BUFF]:SetNonSpaceWrap(false) end
b.amountBarBg = b:CreateTexture(nil, "BACKGROUND")
b.amountBarBg:SetColorTexture(0.12,0.12,0.14,0.9)
b.amountBar = b:CreateTexture(nil, "ARTWORK")
b.amountVal = b:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
b.amountVal:SetJustifyH("RIGHT")
b.consumableIcons = {}
for n=1,6 do
local icon=b:CreateTexture(nil,"OVERLAY"); icon:SetSize(14,14); icon:Hide()
b.consumableIcons[n]=icon
end
b.consumableDots = {}
for n=1,2 do
local dot=b:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
dot:SetWidth(7); dot:SetJustifyH("CENTER"); dot:SetText("·"); dot:Hide()
b.consumableDots[n]=dot
end
b.consumableMarks = {}
for n=1,3 do
local mark=b:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
mark:SetWidth(14); mark:SetJustifyH("CENTER"); mark:Hide()
b.consumableMarks[n]=mark
end
b.gearAuditHit=CreateFrame("Frame",nil,b)
b.gearAuditHit:SetPoint("LEFT",b,"LEFT",colX(COL_LOWQ),0)
b.gearAuditHit:SetSize(COLS[COL_LOWQ][3],auditRowHeight())
b.gearAuditHit:SetFrameLevel(b:GetFrameLevel()+3);b.gearAuditHit:EnableMouse(true)
b.gearAuditHit:SetScript("OnEnter",showGearAuditTooltip)
b.gearAuditHit:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
b.gearAuditHit:SetScript("OnMouseUp",function(_,button)
local fn=b:GetScript("OnClick");if fn then fn(b,button) end
end)
b.teamBuffHit=CreateFrame("Frame",nil,b)
b.teamBuffHit:SetPoint("LEFT",b,"LEFT",colX(COL_TEAM_BUFF),0)
b.teamBuffHit:SetSize(COLS[COL_TEAM_BUFF][3],auditRowHeight())
b.teamBuffHit:SetFrameLevel(b:GetFrameLevel()+3)
b.teamBuffHit:EnableMouse(true)
b.teamBuffHit:SetScript("OnEnter",function(self)
if T and T.ShowTooltip and self.result then T:ShowTooltip(self,self.result) end
end)
b.teamBuffHit:SetScript("OnLeave",function()
if GameTooltip then GameTooltip:Hide() end
end)
b.teamBuffHit:SetScript("OnMouseUp",function(_,button)
local fn=b:GetScript("OnClick"); if fn then fn(b,button) end
end)
b.sparkBars = {}
b.sparkHits = {}
for n=1,RANK_SPARK_COLUMNS do
local bar=b:CreateTexture(nil,"ARTWORK"); bar:Hide(); b.sparkBars[n]=bar
local hit=CreateFrame("Button",nil,b); hit:Hide(); hit:SetFrameLevel(b:GetFrameLevel()+2)
hit:RegisterForClicks("LeftButtonUp","RightButtonUp")
hit:SetScript("OnClick",function(_,button)
local fn=b:GetScript("OnClick"); if fn then fn(b,button) end
end)
U.BindTimelineBarTooltip(hit,frame)
b.sparkHits[n]=hit
end
applyAuditRowStyle(b, i)
b:RegisterForClicks("LeftButtonUp","RightButtonUp")
b:SetScript("OnClick", function(self, button)
if not self.playerName or self.readinessOnly then return end
if button == "RightButton" then
if NoWCL.Sync and not hasLeaderAuthority() then
local nowBoss = not NoWCL.Rules:IsBoss(self.playerName)
NoWCL.Rules:SetBoss(self.playerName, nowBoss)
local cn = U.ClassColor(self.playerName, self.playerClass)
if NoWCL.Toast and NoWCL.Toast.BroadcastLeaderSetting then
NoWCL.Toast:BroadcastLeaderSetting(nowBoss
and (cn.." 已设为老板，不参加排名")
or  (cn.." 已移出老板名单，恢复参加排名"))
end
A:Refresh()
end
else
A.detailPlayer = self.playerName
A.comparePlayer = nil
if frame.detailScroll then frame.detailScroll:SetVerticalScroll(0) end
A:Refresh()
end
end)
rows[i] = b; return b
end
local function teamBuffIconLimit(cell, result)
local absent = (result and result.missing or 0) + (result and result.noSource or 0)
if absent <= 0 then return nil end
local width = cell.GetWidth and cell:GetWidth() or COLS[COL_TEAM_BUFF][3]
if width <= 0 then width = COLS[COL_TEAM_BUFF][3] end
local function measuredWidth(text, fallback)
cell:SetText(text)
local measured = cell.GetStringWidth and cell:GetStringWidth() or 0
return measured > 0 and measured or fallback
end
local prefixWidth = measuredWidth("|cffff4d4d缺：|r", 22)
local spaceWidth = measuredWidth(" ", 3)
local ellipsisWidth = measuredWidth("...", 12)
local stride = 14 + spaceWidth
local fullCapacity = math.max(1, math.floor((width - prefixWidth) / stride))
if absent <= fullCapacity then return fullCapacity end
return math.max(1, math.floor((width - prefixWidth - spaceWidth - ellipsisWidth) / stride))
end
local CONSUMABLE_ICON_SIZE, CONSUMABLE_DOT_WIDTH, CONSUMABLE_ICON_GAP = 13, 5, 1
local function setConsumableIcon(icon, x, spellId, missing, dim)
icon:ClearAllPoints(); icon:SetPoint("LEFT", icon:GetParent(), "LEFT", x, 0)
icon:SetSize(CONSUMABLE_ICON_SIZE,CONSUMABLE_ICON_SIZE)
if missing then
icon:SetTexture(READY_CHECK_MISSING); icon:SetTexCoord(0,1,0,1)
else
local texture = spellId and GetSpellTexture(spellId)
if not texture then
icon:SetTexture(READY_CHECK_MISSING); icon:SetTexCoord(0,1,0,1)
else
icon:SetTexture(texture); icon:SetTexCoord(0.08,0.92,0.08,0.92)
end
end
icon:SetAlpha(dim and 0.45 or 1); icon:Show()
end
local function setConsumableMark(mark, x, text, dim)
mark:ClearAllPoints(); mark:SetPoint("LEFT",mark:GetParent(),"LEFT",x,0)
mark:SetWidth(CONSUMABLE_ICON_SIZE); mark:SetText(text or "—")
mark:SetTextColor(0.55,0.55,0.58,dim and 0.45 or 1); mark:Show()
end
local function renderConsumables(row, pl, dim)
for _, icon in ipairs(row.consumableIcons or {}) do icon:Hide() end
for _, dot in ipairs(row.consumableDots or {}) do dot:Hide() end
for _, mark in ipairs(row.consumableMarks or {}) do mark:Hide() end
row.cells[COL_CONSUMABLES]:SetText("")
if A.sel == "all" then
row.cells[COL_CONSUMABLES]:SetText("—")
row.cells[COL_CONSUMABLES]:SetTextColor(0.5,0.5,0.5)
return
end
if pl.currentRosterOnly then
row.cells[COL_CONSUMABLES]:SetText("—")
row.cells[COL_CONSUMABLES]:SetTextColor(0.5,0.5,0.5)
return
end
if pl.consumablesLive and pl.consumablesKnown ~= true then
row.cells[COL_CONSUMABLES]:SetText("?")
row.cells[COL_CONSUMABLES]:SetTextColor(0.65,0.65,0.68)
return
end
local summary = pl.consumables or (D and D.ConsumableSummary and D.ConsumableSummary(pl)) or {}
local icons, dots = row.consumableIcons, row.consumableDots
local wholeElixir = summary.flask or summary.combined
local medicine = {}
if wholeElixir then
medicine[1] = { spellId=wholeElixir }
elseif summary.battle or summary.guardian then
medicine[1] = { spellId=summary.battle, missing=not summary.battle }
medicine[2] = { spellId=summary.guardian, missing=not summary.guardian }
else
medicine[1] = { missing=true }
end
local bursts = summary.bursts or {}
local burstItems = {}
for i=1,math.min(3,#bursts) do burstItems[i] = { spellId=bursts[i] } end
if #burstItems == 0 then
burstItems[1] = pl.consumablesLive and { mark="—" } or { missing=true }
end
local function groupWidth(count)
return count * CONSUMABLE_ICON_SIZE + math.max(0,count-1) * CONSUMABLE_ICON_GAP
end
local totalWidth = CONSUMABLE_ICON_SIZE + CONSUMABLE_DOT_WIDTH + groupWidth(#medicine)
+ CONSUMABLE_DOT_WIDTH + groupWidth(#burstItems)
local cursor = colX(COL_CONSUMABLES) + math.floor((COLS[COL_CONSUMABLES][3]-totalWidth)/2)
local iconIndex, markIndex = 1, 1
setConsumableIcon(icons[iconIndex],cursor,summary.food,not summary.food,dim)
iconIndex=iconIndex+1; cursor=cursor+CONSUMABLE_ICON_SIZE
local function placeDot(dot)
dot:ClearAllPoints(); dot:SetPoint("LEFT",row,"LEFT",cursor,0)
dot:SetWidth(CONSUMABLE_DOT_WIDTH); dot:SetTextColor(0.65,0.65,0.65); dot:Show()
cursor=cursor+CONSUMABLE_DOT_WIDTH
end
local function placeGroup(items)
for i,item in ipairs(items) do
if item.mark then
setConsumableMark(row.consumableMarks[markIndex],cursor,item.mark,dim)
markIndex=markIndex+1
else
setConsumableIcon(icons[iconIndex],cursor,item.spellId,item.missing,dim)
iconIndex=iconIndex+1
end
cursor=cursor+CONSUMABLE_ICON_SIZE
if i<#items then cursor=cursor+CONSUMABLE_ICON_GAP end
end
end
placeDot(dots[1]); placeGroup(medicine)
placeDot(dots[2]); placeGroup(burstItems)
end
local function renderTeamBuff(row, pl, players, view, dim)
local cell = row.cells[COL_TEAM_BUFF]
row.teamBuffHit.result = nil
row.teamBuffHit.teamBuffContext = nil
row.teamBuffHit:EnableMouse(true)
row.teamBuffHit:Hide()
if A.sel == "all" then
cell:SetText("—"); cell:SetTextColor(0.5,0.5,0.5)
return
end
if pl.currentRosterOnly then
cell:SetText("—"); cell:SetTextColor(0.5,0.5,0.5)
return
end
local result = pl.teamBuff
local signature = T and T.MonitorSignature and T:MonitorSignature()
if result and result.monitorSignature ~= signature then result = nil end
if result and not result.items then result = nil end
if not result and T then
if view and view.readiness and T.EvaluateCurrent then
result = T:EvaluateCurrent(pl, players)
elseif T.EvaluateHistory then
result = T:EvaluateHistory(pl, players, view and view.dur or pl.fightDur)
end
pl.teamBuff = result
end
local teamBuffContext
if result and result.items and #result.items > 0 then
local snapshot = view and view.readinessSnapshot or {}
local currentSources = snapshot.teamBuffSources
if view and not view.readiness and not view.live and T and T.ObservedSourcesFromHistory then
if view.teamBuffHistoricalSources == nil then
view.teamBuffHistoricalSources = T:ObservedSourcesFromHistory(players, view.dur)
end
currentSources = view.teamBuffHistoricalSources
end
teamBuffContext = {
roster=players, currentSources=currentSources,
previousSources=view and view.teamBuffPreviousSources,
}
end
local text, color
if T and T.CellText then
text, color = T:CellText(result, teamBuffContext, teamBuffIconLimit(cell, result))
else text, color = "?", {0.65,0.65,0.68} end
cell:SetText(text)
if dim then cell:SetTextColor(0.55,0.55,0.55) else cell:SetTextColor(color[1],color[2],color[3]) end
if teamBuffContext then
row.teamBuffHit.result = result
row.teamBuffHit.teamBuffContext = teamBuffContext
row.teamBuffHit:Show()
end
end
local function renderRankSpark(row, pl, view, mode, isBoss)
for _, bar in ipairs(row.sparkBars or {}) do bar:Hide() end
for _, hit in ipairs(row.sparkHits or {}) do hit:Hide(); hit.timelineRate=nil end
local valueCell=row.cells[COL_RATE]
valueCell:ClearAllPoints(); valueCell:SetPoint("LEFT",row,"LEFT",colX(COL_RATE),0)
valueCell:SetWidth(COLS[COL_RATE][3]); valueCell:SetJustifyH("CENTER")
if A.sel=="all" then return false end
local buckets, metric = U.PlayerTimelineBuckets(pl,mode)
if type(buckets)~="table" or not next(buckets) then return false end
local dur=math.max(0,U.N(pl.ivDur or view.dur))
local bucketSec=math.max(1,U.N(pl.timelineBucket or 5))
local rates,used,_,spans=U.ResampleTimelineBuckets(buckets,dur,bucketSec,RANK_SPARK_COLUMNS)
local displayPeak=0
for i=1,used do displayPeak=math.max(displayPeak,U.N(rates[i])) end
if displayPeak<=0 then return false end
valueCell:SetWidth(RANK_SPARK_VALUE_W); valueCell:SetJustifyH("RIGHT")
local x=colX(COL_RATE)+RANK_SPARK_VALUE_W+RANK_SPARK_GAP
local w=COLS[COL_RATE][3]-RANK_SPARK_VALUE_W-RANK_SPARK_GAP-1
local barW=w/used
local plotH=math.max(4,math.min(auditRowHeight()-2,auditFillHeight()))
local cr,cg,cb
if metric=="HPS" then cr,cg,cb=0.25,0.90,0.45 else cr,cg,cb=classRGB(pl.class) end
if isBoss then cr,cg,cb=0.52,0.52,0.55 end
for i=1,used do
local bar=row.sparkBars[i]
bar:ClearAllPoints(); bar:SetPoint("BOTTOMLEFT",row,"BOTTOMLEFT",x+(i-1)*barW,(auditRowHeight()-plotH)/2)
bar:SetSize(math.max(1,barW-1),math.max(1,plotH*rates[i]/displayPeak))
bar:SetColorTexture(cr,cg,cb,isBoss and 0.18 or 0.32); bar:Show()
local hit=row.sparkHits[i]
hit:ClearAllPoints(); hit:SetPoint("BOTTOMLEFT",row,"BOTTOMLEFT",x+(i-1)*barW,(auditRowHeight()-plotH)/2)
hit:SetSize(math.max(1,barW),plotH)
hit.timelineMetric=metric; hit.timelineRate=rates[i]
hit.timelineStart=spans[i] and spans[i].startSec or 0
hit.timelineEnd=spans[i] and spans[i].endSec or hit.timelineStart+bucketSec
hit:Show()
end
return true
end
local function taskContribForView(view)
if view and view.cfg and view.cfg.taskContrib then return view.cfg.taskContrib end
return U.EffectiveTaskContrib and U.EffectiveTaskContrib()
or (NoWCL.db and NoWCL.db.settings and NoWCL.db.settings.taskContrib) or {}
end
local function effDps(pl, mode, dur, view)
return U.PlayerDisplayRate(pl,mode,dur,taskContribForView(view))
end
local function healingAmount(pl)
return (U.HealingAmount and U.HealingAmount(pl)) or (pl and (pl.heal or 0)) or 0
end
local function roleOf(pl) return U.RoleOfPlayer and U.RoleOfPlayer(pl) or NoWCL.Stats:RoleOf(pl.name) end
local function roleRank(pl)
return U.DisplayRoleRank and U.DisplayRoleRank(pl) or 1
end
local function displayAmount(pl, mode, view)
return U.PlayerDisplayAmount(pl,mode,view and view.dur,taskContribForView(view))
end
local function displayRate(pl, mode, dur, view)
return U.PlayerDisplayRate(pl,mode,dur,taskContribForView(view))
end
local function taskBonusRate(pl, view, mode)
if not (U.PlayerDisplayAmount and pl and view and (view.dur or 0)>0) then return 0 end
local _,bonus=U.PlayerDisplayAmount(pl,mode,view.dur,taskContribForView(view))
return (bonus or 0)/view.dur
end
local function formatExtraWithTaskBonus(pl, view, mode)
local txt = U.FormatExtraTasks(pl, view and view.puller == pl.name, view and view.pullMethod)
local bonus = taskBonusRate(pl, view, mode)
if bonus > 0 then
local unit = roleOf(pl) == "HEALER" and "HPS" or "DPS"
txt = (txt ~= "-" and txt or "") .. " (+" .. U.Short(bonus) .. unit .. ")"
end
return txt ~= "" and txt or "-"
end
local function sortDisplayPlayers(players, mode, dur, view)
if U.SortDisplayPlayers then return U.SortDisplayPlayers(players,mode,dur,taskContribForView(view)) end
table.sort(players, function(a, b)
local ar, br = roleRank(a), roleRank(b)
if ar ~= br then return ar < br end
local av,bv=displayRate(a,mode,dur,view),displayRate(b,mode,dur,view)
if av == bv then return (a.name or "") < (b.name or "") end
return av > bv
end)
end
local function hasVisibleContribution(pl)
if not pl then return false end
return (pl.dmg or 0) > 0 or healingAmount(pl) > 0
or (pl.deaths or 0) > 0 or (pl.interrupts or 0) > 0 or (pl.dispels or 0) > 0
or (pl.sunderApplied or 0) > 0 or U.FormatExtraTasks(pl) ~= "-"
end
local function baselineValue(players, baseline, bosses, mode, dur, view)
if U.DpsBaselineValue then
return U.DpsBaselineValue(players,baseline,bosses,mode,dur,taskContribForView(view))
end
if baseline=="tank" then
local t=0
for _,p in ipairs(players) do if not bosses[p.name] and roleOf(p)=="TANK" then t=math.max(t,effDps(p,mode,dur,view)) end end
return t
end
local vals = {}
for _,p in ipairs(players) do if not bosses[p.name] and roleOf(p)=="DAMAGER" then vals[#vals+1]=effDps(p,mode,dur,view) end end
table.sort(vals, function(a,b) return a>b end)
if baseline=="rank2" then return vals[2] or vals[1] or 0 end
if baseline=="average" then local s=0 for _,v in ipairs(vals) do s=s+v end return #vals>0 and s/#vals or 0 end
if baseline=="median" then return #vals>0 and vals[math.ceil(#vals/2)] or 0 end
return vals[1] or 0
end
local function reminderButton(kind)
local controls = frame and frame.currentControls
return controls and (kind == "self" and controls.selfRemindBtn or controls.remindBtn)
end
local function reminderCooldownRemaining(kind)
local expires = A._remindCooldownUntil and A._remindCooldownUntil[kind]
if not expires then return 0 end
local remaining = math.ceil(expires - (GetTime and GetTime() or 0))
if remaining <= 0 then
A._remindCooldownUntil[kind] = nil
return 0
end
return remaining
end
local function updateReminderButtonCooldown(kind)
local button = reminderButton(kind)
if not button then return end
local remaining = reminderCooldownRemaining(kind)
if remaining > 0 then
button:SetText(string.format("冷却%d秒", remaining))
button:Disable()
else
button:SetText(kind == "self" and "一键催自己Buff" or "一键催全团Buff")
button:Enable()
end
end
local function startReminderCooldown(kind)
A._remindCooldownUntil = A._remindCooldownUntil or {}
A._remindCooldownUntil[kind] = (GetTime and GetTime() or 0) + REMIND_BUTTON_COOLDOWN_SECONDS
if frame then
frame._remindCooldownDisplayed = frame._remindCooldownDisplayed or {}
frame._remindCooldownDisplayed[kind] = nil
end
updateReminderButtonCooldown(kind)
end
local function reminderFailureToast(reason)
if not (NoWCL.Toast and NoWCL.Toast.Show) then return end
local text = reason == "empty" and "|cff44ff44当前没有需要催补的团队 Buff|r"
or reason == "no-group" and "|cffffd100当前不在队伍或团队中|r"
or reason == "busy" and "|cffffd100上一轮消息仍在发送，请稍后再试|r"
or "|cffff6666催 Buff 消息未能加入发送队列|r"
NoWCL.Toast:Show(text, 2)
end
function A:ConfirmFullBuffReminder()
if reminderCooldownRemaining("all") > 0 then return false end
local checker = NoWCL.ConsumableCheck
local ok, result = checker and checker.RemindMissingBuffs and checker:RemindMissingBuffs()
if not ok then reminderFailureToast(result); return false, result end
startReminderCooldown("all")
return true, result
end
local function remindSelfBuffs()
if reminderCooldownRemaining("self") > 0 then return false,"cooldown" end
local checker = NoWCL.ConsumableCheck
local ok, result = checker and checker.RemindSelfBuffs and checker:RemindSelfBuffs()
if not ok then
if result ~= "empty" then reminderFailureToast(result) end
return false,result
end
startReminderCooldown("self")
return true,result
end
function A:RemindSelfBuffs()
return remindSelfBuffs()
end
function A:ReminderCooldownRemaining(kind)
return reminderCooldownRemaining(kind)
end
local function updateCurrentSwitchButton(show)
local button = frame and frame.currentControls and frame.currentControls.modeBtn
if not button then return end
button:SetShown(show and true or false)
if not show then
button._nowclPreviousHold = nil
return
end
local remaining = currentSwitchRemaining()
button._nowclPreviousHold = remaining > 0
button:SetText(string.format("%d秒后切换为当前状态", remaining))
end
local function updateCurrentControls(view)
local controls = frame and frame.currentControls
if not controls then return end
controls:Show()
local readiness = view and view.readiness == true
frame._currentStatusRendered = A.sel == "current" and readiness or false
local showMode = A.sel == "current" and not readiness
and not (view and view.live) and not currentLiveVisible()
updateCurrentSwitchButton(showMode)
local snapshot = view and view.readinessSnapshot
if readiness and snapshot then
local food = tonumber(snapshot.missingFood) or 0
local medicine = tonumber(snapshot.missingMedicine) or 0
local teamBuff = tonumber(snapshot.missingTeamBuffPlayers) or 0
local weakBuff = tonumber(snapshot.weakTeamBuffPlayers) or 0
local noSource = tonumber(snapshot.noSourceTeamBuffPlayers) or 0
local buffUnknown = tonumber(snapshot.unknownTeamBuffPlayers) or 0
local unknown = tonumber(snapshot.unknown) or 0
local color = (food == 0 and medicine == 0 and teamBuff == 0 and weakBuff == 0) and "|cff44ff44" or "|cffff8888"
local uncertain = ""
if unknown > 0 or buffUnknown > 0 then uncertain = string.format("  |cffaaaaaa未知 %d人|r",math.max(unknown,buffUnknown)) end
if noSource > 0 then uncertain = uncertain .. string.format("  |cff888888Buff无来源 %d人|r",noSource) end
if weakBuff > 0 then uncertain = uncertain .. string.format("  |cffffb826弱覆盖 %d人|r",weakBuff) end
controls.summary:SetText(string.format("%s食物缺 %d  药剂缺 %d  团队Buff缺 %d人|r%s  |cff777777每3秒检查|r",
color,food,medicine,teamBuff,uncertain))
else
controls.summary:SetText("")
end
local checker = NoWCL.ConsumableCheck
local canRemind = checker and checker.RemindMissingBuffs
local canRemindSelf = checker and checker.RemindSelfBuffs
controls.remindBtn:SetShown(canRemind and true or false)
controls.selfRemindBtn:SetShown(canRemindSelf and true or false)
if canRemind then updateReminderButtonCooldown("all") end
if canRemindSelf then updateReminderButtonCooldown("self") end
controls.summary:ClearAllPoints()
local leftControl = showMode and controls.modeBtn
if leftControl then controls.summary:SetPoint("LEFT",leftControl,"RIGHT",8,0)
else controls.summary:SetPoint("LEFT",0,0) end
if canRemindSelf then controls.summary:SetPoint("RIGHT",controls.selfRemindBtn,"LEFT",-8,0)
elseif canRemind then controls.summary:SetPoint("RIGHT",controls.remindBtn,"LEFT",-8,0)
else controls.summary:SetPoint("RIGHT",controls.teamAnnouncementBtn,"LEFT",-8,0) end
end
local function buildTabs()
for _,b in ipairs(selBtns) do b:Hide() end
local items = { { label="所有战斗汇总", sel="all", active=true } }
local hasCurrent = NoWCL.Stats and ((NoWCL.Stats.IsCurrentSegmentVisible
and NoWCL.Stats:IsCurrentSegmentVisible()) or NoWCL.Stats.lastCurrentSegment
or (IsInGroup and IsInGroup()))
for _, t in ipairs(NoWCL.Sync:GetTabs()) do
local owner = t.ownerCharacterName or "当前角色"
owner = owner:match("^[^-]+") or owner
local label = U.Trunc(t.boss or "场", 5).." "..date("%H:%M", t.ts or 0)
if NoWCL.Sync:ShowAllCharacterFights() then
label = U.Trunc(owner, 6).."·"..label
end
items[#items+1] = {
label=label, sel=t.fightId,
active=t.active, summaryIncluded=NoWCL.Sync:IsTabInSummary(t), canToggle=t.active and NoWCL.Sync:IsAuthority(),
}
end
if hasCurrent then
items[#items+1] = { label="当前", sel="current", active=true }
end
local maxW = frame:GetWidth() - 12
local x, y, rows = 6, -6, 1
for i, it in ipairs(items) do
local b = selBtns[i]
if not b then
b = CreateFrame("Button", nil, frame.audit, "UIPanelButtonTemplate")
b:SetHeight(20)
b.summaryCheck = CreateFrame("CheckButton", nil, b, "UICheckButtonTemplate")
b.summaryCheck:SetSize(18,18); b.summaryCheck:SetPoint("LEFT",1,0)
b.summaryCheck:SetFrameLevel(b:GetFrameLevel()+2)
b.summaryCheck:SetScript("OnClick", function(self)
if not self.fightId then return end
if not NoWCL.Sync:SetTabSummaryIncluded(self.fightId, self:GetChecked() and true or false) then
local tab = NoWCL.Sync.tabs and NoWCL.Sync.tabs[self.fightId]
self:SetChecked(NoWCL.Sync:IsTabInSummary(tab))
end
end)
b.summaryCheck:SetScript("OnEnter", function(self)
if not GameTooltip then return end
GameTooltip:SetOwner(self, "ANCHOR_TOP")
GameTooltip:AddLine("所有战斗汇总")
GameTooltip:AddLine("勾选时，此 Boss 战计入所有战斗汇总；取消后单场 Tab 和详情仍会保留。", 0.8, 0.8, 0.8, true)
if not NoWCL.Sync:IsAuthority() then
GameTooltip:AddLine("当前跟随团长设置，只读。", 1, 0.82, 0, true)
end
GameTooltip:Show()
end)
b.summaryCheck:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
b.selectedGold = b:CreateTexture(nil,"ARTWORK",nil,1)
b.selectedGold:SetPoint("TOPLEFT",2,-2); b.selectedGold:SetPoint("BOTTOMRIGHT",-2,2)
b.selectedGold:SetTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
b.selectedGold:SetBlendMode("ADD")
b.selectedGold:SetVertexColor(1,0.68,0.12,0.72)
b.selectedGold:Hide()
selBtns[i]=b
U.RegisterOpacityChrome(frame, b)
U.RegisterOpacityChromeHover(frame, b)
end
local hasSummaryToggle = it.sel ~= "all" and it.sel ~= "current"
b:SetText(hasSummaryToggle and ("   "..it.label) or it.label)
if Style and Style.ApplyFontFace and b:GetFontString() then Style:ApplyFontFace(b:GetFontString()) end
local fsw = b:GetFontString() and b:GetFontString():GetStringWidth() or 50
local w = math.max(50, fsw + 14 + (hasSummaryToggle and 8 or 0)); b:SetWidth(w)
if x + w > maxW then x = 6; y = y - 22; rows = rows + 1 end
b:ClearAllPoints(); b:SetPoint("TOPLEFT", frame.audit, "TOPLEFT", x, y)
b.sel = it.sel
b.summaryCheck.fightId = hasSummaryToggle and it.sel or nil
b.summaryCheck:SetShown(hasSummaryToggle)
if hasSummaryToggle then
b.summaryCheck:SetChecked(it.summaryIncluded)
if it.canToggle then b.summaryCheck:Enable() else b.summaryCheck:Disable() end
end
b:SetScript("OnClick", function(self)
A.sel = self.sel
A.comparePlayer = nil
local scroll=A.detailPlayer and frame.detailScroll or frame.listScroll
if scroll and scroll.SetVerticalScroll then scroll:SetVerticalScroll(0) end
A:Refresh()
end)
b:Show()
local selected = A.sel == it.sel
if selected then b:LockHighlight() else b:UnlockHighlight() end
local highlight = b:GetHighlightTexture()
if highlight then
if selected then highlight:SetVertexColor(1,1,1); highlight:SetAlpha(1)
else highlight:SetVertexColor(1,1,1); highlight:SetAlpha(0.75) end
end
b.selectedGold:SetShown(selected)
local fs = b:GetFontString()
if fs then
if it.active and (not hasSummaryToggle or it.summaryIncluded) then fs:SetTextColor(1,0.82,0)
else fs:SetTextColor(0.5,0.5,0.5) end
end
x = x + w + 4
end
local controlsShown = frame.currentControls and frame.currentControls:IsShown()
if controlsShown then
frame.currentControls:ClearAllPoints()
frame.currentControls:SetPoint("TOPLEFT",frame.audit,"TOPLEFT",6,-(rows*22+6))
frame.currentControls:SetPoint("TOPRIGHT",frame.audit,"TOPRIGHT",-SCROLLBAR_GUTTER,-(rows*22+6))
end
local topOff = -(rows*22 + 6 + (controlsShown and 26 or 0))
frame.header:ClearAllPoints(); frame.header:SetPoint("TOPLEFT",0,topOff); frame.header:SetPoint("TOPRIGHT",-SCROLLBAR_GUTTER,topOff)
local rowH = auditRowHeight()
frame.listScroll:ClearAllPoints()
frame.listScroll:SetPoint("TOPLEFT",0,topOff-rowH-2)
frame.listScroll:SetPoint("BOTTOMRIGHT",-SCROLLBAR_GUTTER,AUDIT_BOTTOM_PAD)
frame.detailScroll:ClearAllPoints()
frame.detailScroll:SetPoint("TOPLEFT",0,topOff)
frame.detailScroll:SetPoint("BOTTOMRIGHT",-SCROLLBAR_GUTTER,AUDIT_BOTTOM_PAD-2)
frame._tabRows = rows
end
local function setFrameHeight(h)
if not frame then return end
local state = auditWindowState()
local target = state and state.manualSize and state.height or h
frame:SetHeight(clampAuditHeight(target))
end
local function updateSettingsContentSize()
local settings = frame and frame.settings
if not settings then return end
settings:SetHeight(892)
if frame.settingsScroll and frame.settingsScroll.UpdateScrollChildRect then
frame.settingsScroll:UpdateScrollChildRect()
end
end
local function applyAuditColumnLayout()
if not frame then return end
fitColumnsToWidth(frame:GetWidth())
local contentWidth = math.max(1, frame:GetWidth() - SCROLLBAR_GUTTER)
for i, fs in ipairs(frame.headerCells or {}) do
fs:ClearAllPoints()
fs:SetPoint("LEFT", frame.header, "LEFT", colX(i), 0)
fs:SetWidth(COLS[i][3])
end
for _, row in ipairs(rows) do
for i, fs in ipairs(row.cells or {}) do
fs:ClearAllPoints()
fs:SetPoint("LEFT", row, "LEFT", colX(i), 0)
fs:SetWidth(COLS[i][3])
end
if row.teamBuffHit then
row.teamBuffHit:ClearAllPoints()
row.teamBuffHit:SetPoint("LEFT", row, "LEFT", colX(COL_TEAM_BUFF), 0)
row.teamBuffHit:SetWidth(COLS[COL_TEAM_BUFF][3])
end
if row.gearAuditHit then
row.gearAuditHit:ClearAllPoints()
row.gearAuditHit:SetPoint("LEFT",row,"LEFT",colX(COL_LOWQ),0)
row.gearAuditHit:SetWidth(COLS[COL_LOWQ][3])
end
end
if frame.rowAnchor then frame.rowAnchor:SetWidth(contentWidth) end
if frame.detailPane then
frame.detailPane:SetWidth(contentWidth)
local cmp = frame.detailPane.compare
if cmp and cmp.list then
local half = math.max(180, (contentWidth - 34) / 2)
for _, fs in ipairs({ cmp.spellLeft,cmp.spellRight,cmp.targetLeft,cmp.targetRight,
cmp.buffLeft,cmp.buffRight,cmp.debuffLeft,cmp.debuffRight }) do
if fs then fs:SetWidth(half) end
end
end
end
local settings = frame.settings
if settings then
local contentWidth = math.max(1, frame:GetWidth() - SCROLLBAR_GUTTER)
settings:SetWidth(contentWidth)
settings.hint:SetWidth(math.max(300, frame:GetWidth() - 440))
settings.credits:SetWidth(math.max(300, math.min(420, frame:GetWidth() - 32)))
settings.teamBuffSummary:SetWidth(math.max(180, frame:GetWidth() - 426))
settings.autoClearRaidState:SetWidth(math.max(180, frame:GetWidth() - 450))
for _, state in ipairs({ settings.rulesAnnounceState, settings.deathAnnounceState,
settings.performanceAnnounceState, settings.failureAnnounceState,
settings.pullStartAnnounceState }) do
if state then state:SetWidth(math.max(180, frame:GetWidth() - 450)) end
end
if settings.rulesTextEdit then
settings.rulesTextEdit:SetWidth(math.min(440,math.max(160,contentWidth-320)))
end
updateSettingsContentSize()
end
end
local function updateSyncButton()
local b = frame and frame.syncBtn
local label = frame and frame.syncLabel
if not b then return end
local st = NoWCL.Sync:GetTabSyncStatus(A.sel)
if not st then b:Hide(); if label then label:Hide() end; return end
local txt = st.text or ""
if st.leader and st.canResend then
txt = txt .. "，点击再次强制同步"
b:Enable()
b:SetScript("OnClick", function()
if A.sel and A.sel ~= "all" then NoWCL.Sync:BroadcastTab(A.sel, true) end
end)
else
b:Disable()
b:SetScript("OnClick", nil)
end
b:SetText(txt)
b:Show()
if label then label:SetText("本页信息同步:"); label:Show() end
end
local function selectedTabInfo()
local fid = A.sel
if not fid or fid == "all" or fid == "current" then return nil end
local t = NoWCL.Sync and NoWCL.Sync.tabs and NoWCL.Sync.tabs[fid]
if not t then return nil end
local label = (t.boss or "战斗") .. " " .. date("%H:%M", t.ts or 0)
return fid, label
end
local function updateClearButtons()
if not frame then return end
if frame.clearAllBtn then frame.clearAllBtn:Show() end
local fid = selectedTabInfo()
if frame.clearCurBtn then
frame.clearCurBtn:Show()
if fid then frame.clearCurBtn:Enable() else frame.clearCurBtn:Disable() end
end
end
local function applyGearToPlayers(players)
return U.ApplyReadinessToPlayers(players)
end
local function getAuditView(sel, includeDetails)
if includeDetails == nil then includeDetails = true end
local followsLeader = hasLeaderAuthority()
syncCurrentRecordIdentity()
local liveSeg = NoWCL.Stats and NoWCL.Stats.IsCurrentSegmentVisible
and NoWCL.Stats:IsCurrentSegmentVisible()
local function liveView()
if not liveSeg then return nil end
local players, dur
if NoWCL.Stats.GetDisplayPlayers then players, dur = NoWCL.Stats:GetDisplayPlayers()
else players, dur = NoWCL.Stats:GetPlayers() end
applyGearToPlayers(players)
return { encounter = NoWCL.Stats:SegmentName(), dur = dur, players = players, live = true,
isBoss = NoWCL.Stats.segment and NoWCL.Stats.segment.isBoss and true or false,
recordable = NoWCL.Stats:SegmentRecordable(),
calibrated = NoWCL.Stats:SegmentCalibrated(),
bossSpells = NoWCL.Stats.segment and NoWCL.Stats.segment.bossSpells,
puller = NoWCL.Stats.segment and NoWCL.Stats.segment.puller,
pullMethod = NoWCL.Stats.segment and NoWCL.Stats.segment.pullMethod,
pullSpellId = NoWCL.Stats.segment and NoWCL.Stats.segment.pullSpellId }
end
if sel == "current" and NoWCL.Stats and NoWCL.Stats.ViewPlayers then
if not liveSeg and currentStatusActive() then
local checker = NoWCL.ConsumableCheck
local snapshot = checker and checker:GetSnapshot()
if not snapshot and checker then snapshot = checker:Scan() end
snapshot = snapshot or { players={},known=0,unknown=0,missingFood=0,missingMedicine=0 }
local players = U.CompleteCurrentRoster(snapshot.players or {}, 0)
applyGearToPlayers(players)
return {
encounter = "当前状态", dur = 0, players = players, readiness = true,
readinessSnapshot = snapshot, leader = not followsLeader, active = true,
cfg = followsLeader and NoWCL.Sync.cfg or nil,
tabs = NoWCL.Sync:GetTabs(),
}
end
local live = liveView()
if live then
live.players = U.CompleteCurrentRoster(live.players, live.dur)
applyGearToPlayers(live.players)
return {
encounter = live.encounter, dur = live.dur, players = live.players, live = true,
isBoss = live.isBoss, recordable = live.recordable,
currentRosterComplete = true,
leader = not followsLeader, active = true,
calibrated = live.calibrated,
uncalibratedCount = live.calibrated == false and 1 or 0,
cfg = followsLeader and NoWCL.Sync.cfg or nil,
tabs = NoWCL.Sync:GetTabs(),
bossSpells = live.bossSpells,
puller = live.puller,
pullMethod = live.pullMethod,
pullSpellId = live.pullSpellId,
}
end
local players, dur, name = NoWCL.Stats:ViewPlayers("current")
players = U.CompleteCurrentRoster(players, dur)
applyGearToPlayers(players)
return {
encounter = name, dur = dur, players = players,
currentRosterComplete = true,
leader = not followsLeader, active = true,
cfg = followsLeader and NoWCL.Sync.cfg or nil,
tabs = NoWCL.Sync:GetTabs(),
puller = (NoWCL.Stats.lastCurrentSegment and NoWCL.Stats.lastCurrentSegment.puller)
or (NoWCL.Stats.history and NoWCL.Stats.history[1] and NoWCL.Stats.history[1].puller),
pullMethod = (NoWCL.Stats.lastCurrentSegment and NoWCL.Stats.lastCurrentSegment.pullMethod)
or (NoWCL.Stats.history and NoWCL.Stats.history[1] and NoWCL.Stats.history[1].pullMethod),
pullSpellId = (NoWCL.Stats.lastCurrentSegment and NoWCL.Stats.lastCurrentSegment.pullSpellId)
or (NoWCL.Stats.history and NoWCL.Stats.history[1] and NoWCL.Stats.history[1].pullSpellId),
}
end
local view = NoWCL.Sync:GetView(sel, includeDetails)
local live = sel == "all" and liveView() or nil
if U.ShouldMergeLiveIntoSummary(live) then
view = U.MergeCombatViews(view, live, includeDetails)
applyGearToPlayers(view.players)
end
return view
end
local SCHOOL_COLOR = {
[1]  = {1.00,0.94,0.78},
[2]  = {1.00,0.90,0.50},
[4]  = {1.00,0.50,0.10},
[8]  = {0.30,0.95,0.30},
[16] = {0.45,0.95,1.00},
[32] = {0.62,0.40,0.92},
[64] = {0.96,0.50,0.95},
}
local function schoolColor(s) return SCHOOL_COLOR[s or 0] or {0.55,0.60,0.85} end
local function setSpellTooltip(owner, detail, isHeal, total)
if D and D.ShowSpellTooltip then D.ShowSpellTooltip(owner,detail,isHeal,total) end
end
local function setAuraTooltip(owner, detail, kind)
if D and D.ShowAuraTooltip then D.ShowAuraTooltip(owner,detail,kind) end
end
local spellRows, targetRows, buffRows, debuffRows, bossDetailRows = {}, {}, {}, {}, {}
local SPELL_DETAIL_COLUMNS = {
{ key="amount", label="总量", width=90, right=-292 },
{ key="share", label="占比", width=58, right=-228 },
{ key="casts", label="释放", width=58, right=-164 },
{ key="hits", label="命中/跳数", width=82, right=-76 },
{ key="crit", label="暴击率", width=66, right=-4 },
}
local SPELL_DETAIL_NAME_RIGHT = 392
local AURA_DETAIL_COLUMNS = {
{ key="uptime", label="覆盖时间", width=88, right=-206 },
{ key="percent", label="覆盖率", width=58, right=-142 },
{ key="count", label="次数", width=58, right=-78 },
{ key="refreshes", label="刷新", width=68, right=-4 },
}
local AURA_DETAIL_NAME_RIGHT = 304
local function setDetailColumnsShown(row, group)
for _, col in ipairs(SPELL_DETAIL_COLUMNS) do
row.metric[col.key]:SetShown(group == "spell")
end
for _, col in ipairs(AURA_DETAIL_COLUMNS) do
row.auraMetric[col.key]:SetShown(group == "aura")
end
row.val:SetShown(group == nil)
end
local function positionDetailHeads(heads, columns, parent, y)
for i, col in ipairs(columns) do
local head=heads[i]
head:ClearAllPoints(); head:SetPoint("TOPRIGHT",parent,"TOPRIGHT",col.right,y)
head:SetWidth(col.width); head:SetJustifyH("RIGHT")
head:SetText("|cffaaaaaa"..col.label.."|r"); head:Show()
end
end
local function applyDetailRowStyle(row)
local h = auditRowHeight()
row:SetHeight(h)
row.bar:SetHeight(auditDetailFillHeight())
if Style and Style.ApplyTexture then Style:ApplyTexture(row.bar, 0.25, 0.45, 0.75, 0.5) end
if Style and Style.ApplyFont then
Style:ApplyFont(row.name, -1)
Style:ApplyFont(row.val, -1)
for _, col in ipairs(SPELL_DETAIL_COLUMNS) do Style:ApplyFont(row.metric[col.key], -1) end
for _, col in ipairs(AURA_DETAIL_COLUMNS) do Style:ApplyFont(row.auraMetric[col.key], -1) end
end
local iconSize = math.max(12, math.min(16, h - 2))
row.icon:SetSize(iconSize, iconSize)
end
local function makeRow(pool, i)
if pool[i] then return pool[i] end
local p = frame.detailPane.list
local r = CreateFrame("Frame", nil, p)
r:EnableMouse(true)
U.RegisterOpacityChromeHover(frame, r)
r.bar=r:CreateTexture(nil,"BACKGROUND"); r.bar:SetPoint("LEFT",20,0)
r.icon=r:CreateTexture(nil,"ARTWORK"); r.icon:SetSize(16,16); r.icon:SetPoint("LEFT",1,0); r.icon:SetTexCoord(0.08,0.92,0.08,0.92)
r.name=r:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); r.name:SetPoint("LEFT",24,0); r.name:SetJustifyH("LEFT")
r.val=r:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); r.val:SetPoint("RIGHT",-6,0); r.val:SetJustifyH("RIGHT")
r.metric={}
for _, col in ipairs(SPELL_DETAIL_COLUMNS) do
local fs=r:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
fs:SetPoint("RIGHT",r,"RIGHT",col.right,0); fs:SetWidth(col.width); fs:SetJustifyH("RIGHT"); fs:Hide()
r.metric[col.key]=fs
end
r.auraMetric={}
for _, col in ipairs(AURA_DETAIL_COLUMNS) do
local fs=r:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
fs:SetPoint("RIGHT",r,"RIGHT",col.right,0); fs:SetWidth(col.width); fs:SetJustifyH("RIGHT"); fs:Hide()
r.auraMetric[col.key]=fs
end
applyDetailRowStyle(r)
r:SetScript("OnEnter",function(self)
if self._bossDetail and D and D.ShowBossTooltip then D.ShowBossTooltip(self,self._bossDetail)
elseif self._spellDetail then setSpellTooltip(self,self._spellDetail,self._isHeal,self._spellTotal)
elseif self._auraDetail then setAuraTooltip(self,self._auraDetail,self._auraKind) end
end)
r:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
pool[i]=r; return r
end
local function renderRows(pool, map, total, y, opts)
opts = opts or {}
local list = {}
if map then for n,v in pairs(map) do list[#list+1]={n=n,v=v} end end
table.sort(list, function(a,b) return a.v>b.v end)
local maxv = list[1] and list[1].v or 1
local barMax = (frame:GetWidth() or 700) - 56
local cap = opts.cap or math.huge
local shown = 0
for i,it in ipairs(list) do
if i>cap then break end
local r = makeRow(pool, i); r:Show()
setDetailColumnsShown(r)
r._spellDetail=nil; r._spellTotal=nil; r._bossDetail=nil; r._auraDetail=nil; r._auraKind=nil
r:ClearAllPoints(); r:SetPoint("TOPLEFT",0,y); r:SetPoint("TOPRIGHT",0,y)
if opts.isTarget then
r.icon:Hide(); r.name:ClearAllPoints(); r.name:SetPoint("LEFT",8,0)
local included = opts.isHeal or opts.includeAll or (opts.targetsBoss and opts.targetsBoss[it.n])
local col = included and {0.30,0.80,0.40} or {0.50,0.50,0.55}
if Style and Style.SetTextureColor then Style:SetTextureColor(r.bar, col[1],col[2],col[3],rowOpaque() and 1 or 0.5) end
else
local meta = NoWCL.Stats.spellInfo and NoWCL.Stats.spellInfo[it.n]
local icon = meta and meta.icon
if not icon then icon = GetSpellTexture(it.n=="近战" and 6603 or it.n) end
if icon then r.icon:SetTexture(icon); r.icon:Show() else r.icon:Hide() end
r.name:ClearAllPoints(); r.name:SetPoint("LEFT",24,0)
local col = schoolColor(meta and meta.school)
if Style and Style.SetTextureColor then Style:SetTextureColor(r.bar, col[1],col[2],col[3],rowOpaque() and 1 or 0.5) end
end
r.bar:SetWidth(math.max(1, barMax*(it.v/maxv)))
local label = it.n
if opts.isTarget and opts.isHeal and opts.classByName then
label = U.ClassColor(it.n, opts.classByName[it.n])
end
r.name:SetText(label)
r.name:SetWidth(math.max(80,barMax-190)); r.val:SetWidth(180)
r.val:SetText(U.Short(it.v).."   |cffffd100"..U.Pct2(total>0 and it.v/total or 0).."|r")
y = y - auditRowHeight() - 1; shown = shown + 1
end
for i=shown+1,#pool do pool[i]:Hide() end
return y, #list
end
local function renderSpellDetailRows(pool, list, total, y, isHeal)
local maxv=list[1] and list[1].amount or 1
local barMax=(frame:GetWidth() or 900)-56
local shown=0
for i,it in ipairs(list or {}) do
local r=makeRow(pool,i); r:Show(); shown=i
setDetailColumnsShown(r,"spell")
r:ClearAllPoints(); r:SetPoint("TOPLEFT",0,y); r:SetPoint("TOPRIGHT",0,y)
r._spellDetail=it; r._spellTotal=total; r._bossDetail=nil; r._isHeal=isHeal; r._auraDetail=nil
local meta=NoWCL.Stats.spellInfo and NoWCL.Stats.spellInfo[it.name]
local icon=(meta and meta.icon) or (it.spellId and it.spellId>0 and GetSpellTexture(it.spellId))
if icon then r.icon:SetTexture(icon); r.icon:Show() else r.icon:Hide() end
r.name:ClearAllPoints(); r.name:SetPoint("LEFT",24,0); r.name:SetPoint("RIGHT",r,"RIGHT",-SPELL_DETAIL_NAME_RIGHT,0)
r.name:SetJustifyH("LEFT"); r.name:SetText(it.name)
local col=schoolColor(it.school or (meta and meta.school))
if Style and Style.SetTextureColor then Style:SetTextureColor(r.bar,col[1],col[2],col[3],rowOpaque() and 1 or 0.5) end
r.bar:SetWidth(math.max(1,barMax*(it.amount/math.max(1,maxv))))
local casts=(it.casts or 0)>0 and tostring(it.casts) or "-"
local hits=(it.hits or 0)>0 and tostring(it.hits) or "-"
local crit=(it.hits or 0)>0 and string.format("%.1f%%",(it.crits or 0)/it.hits*100) or "-"
r.metric.amount:SetText(U.Short(it.amount))
r.metric.share:SetText("|cffffd100"..U.Pct2(total>0 and it.amount/total or 0).."|r")
r.metric.casts:SetText(casts)
r.metric.hits:SetText(hits)
r.metric.crit:SetText(crit)
y=y-auditRowHeight()-1
end
for i=shown+1,#pool do pool[i]:Hide() end
return y,#list
end
local function samePlayerName(left,right)
local function short(name) return tostring(name or ""):match("^[^-]+") or "" end
local a,b=short(left),short(right)
return a~="" and a==b
end
local function auraLabel(it,kind,playerName)
if not it.peer or it.peer=="" or (kind=="buff" and samePlayerName(it.peer,playerName)) then return it.name end
return it.name.." |cff888888["..it.peer.."]|r"
end
local function detailSelfBuffOnly()
return NoWCL.db and NoWCL.db.settings and NoWCL.db.settings.detailSelfBuffOnly == true
end
local function detailBuffRows(rec,duration,bossName,bossCfg)
local rows=D and D.AuraRows and D.AuraRows(rec,"buff",duration,bossName,bossCfg) or {}
if detailSelfBuffOnly() and D and D.FilterAuraRowsByCaster then
return D.FilterAuraRowsByCaster(rows,rec and rec.name)
end
return rows
end
local function showDetailSelfBuffCheck(check,label)
if not check then return end
check:SetChecked(detailSelfBuffOnly())
check:Show()
if label then label:Show() end
end
local function onDetailSelfBuffClick(self)
NoWCL.db.settings.detailSelfBuffOnly=self:GetChecked() and true or false
A:Refresh()
end
local function renderAuraDetailRows(pool,list,duration,y,kind,playerName)
local shown=0; local barMax=(frame:GetWidth() or 900)-56
for i,it in ipairs(list or {}) do
local r=makeRow(pool,i); r:Show(); shown=i
setDetailColumnsShown(r,"aura")
r:ClearAllPoints(); r:SetPoint("TOPLEFT",0,y); r:SetPoint("TOPRIGHT",0,y)
r._spellDetail=nil; r._spellTotal=nil; r._bossDetail=nil; r._auraDetail=it; r._auraKind=kind
local icon=it.spellId and it.spellId>0 and GetSpellTexture(it.spellId)
if icon then r.icon:SetTexture(icon); r.icon:Show() else r.icon:Hide() end
r.name:ClearAllPoints(); r.name:SetPoint("LEFT",24,0); r.name:SetPoint("RIGHT",r,"RIGHT",-AURA_DETAIL_NAME_RIGHT,0)
r.name:SetJustifyH("LEFT"); r.name:SetText(auraLabel(it,kind,playerName))
local col=kind=="buff" and {0.35,0.72,1.0} or {0.82,0.42,0.90}
if Style and Style.SetTextureColor then Style:SetTextureColor(r.bar,col[1],col[2],col[3],rowOpaque() and 1 or 0.48) end
r.bar:SetWidth(math.max(1,barMax*math.min(1,it.percent or 0)))
r.auraMetric.uptime:SetText(string.format("%.1fs",it.uptime or 0))
r.auraMetric.percent:SetText(string.format("|cffffd100%.1f%%|r",(it.percent or 0)*100))
r.auraMetric.count:SetText(tostring(it.count or 0))
r.auraMetric.refreshes:SetText(tostring(it.refreshes or 0))
y=y-auditRowHeight()-1
end
for i=shown+1,#pool do pool[i]:Hide() end
return y,#list
end
local function renderBossDetailRows(pool,list,y)
local shown=0; local barMax=(frame:GetWidth() or 900)-56
local maxv=1; for _,it in ipairs(list or {}) do maxv=math.max(maxv,it.damage or 0,it.casts or 0) end
for i,it in ipairs(list or {}) do
local r=makeRow(pool,i); r:Show(); shown=i
setDetailColumnsShown(r)
r:ClearAllPoints(); r:SetPoint("TOPLEFT",0,y); r:SetPoint("TOPRIGHT",0,y)
r._spellDetail=nil; r._spellTotal=nil; r._bossDetail=it
r._isHeal=false; r._auraDetail=nil
local icon=it.spellId and it.spellId>0 and GetSpellTexture(it.spellId)
if icon then r.icon:SetTexture(icon); r.icon:Show() else r.icon:Hide() end
r.name:ClearAllPoints(); r.name:SetPoint("LEFT",24,0); r.name:SetWidth(math.max(90,barMax-330)); r.name:SetText(it.name)
if Style and Style.SetTextureColor then Style:SetTextureColor(r.bar,0.90,0.36,0.28,rowOpaque() and 1 or 0.48) end
r.bar:SetWidth(math.max(1,barMax*math.max(it.damage or 0,it.casts or 0)/maxv))
r.val:SetWidth(320); r.val:SetText(string.format("伤害 %s    施放 %d    命中 %d    时间点 %d",U.Short(it.damage or 0),it.casts or 0,it.hits or 0,it.events or 0))
y=y-auditRowHeight()-1
end
for i=shown+1,#pool do pool[i]:Hide() end
return y,#list
end
local function formatDeathTime(seconds)
seconds = math.max(0, tonumber(seconds) or 0)
return string.format("%d:%04.1f", math.floor(seconds / 60), seconds % 60)
end
local function deathSpellLink(hit)
local spellId = hit and tonumber(hit[2]) or 0
if spellId > 0 and GetSpellLink then
local link = GetSpellLink(spellId)
if link then return link end
end
return (hit and hit[4]) or "未知攻击"
end
local function showDeathTooltip(mark)
if not (mark and mark._deathTime and GameTooltip) then return end
GameTooltip:SetOwner(mark, "ANCHOR_TOP")
GameTooltip:ClearLines()
GameTooltip:AddLine("死亡时间  " .. formatDeathTime(mark._deathTime), 1, 0.3, 0.3)
local detail = mark._deathDetail
local hits = detail and detail[2]
if type(hits) ~= "table" or #hits == 0 then
GameTooltip:AddLine("此战斗版本未记录死亡前受击详情", 0.65, 0.65, 0.68, true)
GameTooltip:Show()
return
end
local fatal = hits[#hits]
GameTooltip:AddLine("致死攻击：" .. deathSpellLink(fatal), 1, 0.82, 0, true)
GameTooltip:AddLine("死亡前最后 " .. #hits .. " 次生命损失", 0.8, 0.8, 0.82)
for _, hit in ipairs(hits) do
local at = (tonumber(hit[1]) or 0) / 1000
local source = hit[5] or "未知来源"
GameTooltip:AddLine(string.format("%s  %s  %s", formatDeathTime(at), source, deathSpellLink(hit)), 0.9, 0.9, 0.92, true)
GameTooltip:AddLine("    |cffff6666生命 -" .. U.Short(hit[3] or 0) .. "|r", 0.78, 0.78, 0.8)
end
GameTooltip:Show()
end
local function renderActivityInto(ac, rec, viewDur)
ac._segments=ac._segments or {}
ac._deathMarks=ac._deathMarks or {}
local actSegs,deathMarks=ac._segments,ac._deathMarks
local pct = rec.activePct or 0
local dur = rec.ivDur or viewDur or 0
local active = pct*dur
local deadSec = rec.deadSec or 0
local aliveDur = math.max(1, dur - deadSec)
local pctAlive = math.min(1, active/aliveDur)
local eval, ecol
if pctAlive>=0.9 then eval,ecol="优秀","|cff44ff44"
elseif pctAlive>=0.75 then eval,ecol="正常","|cffbbff66"
elseif pctAlive>=0.5 then eval,ecol="偏低","|cffffd100"
else eval,ecol="过低 / 疑似挂机","|cffff5555" end
ac.big:SetText("活跃度 "..U.Pct2(pct)..(rec.actEst and " |cff888888~团长估算(对方无NoWCL,通道法术可能偏低)|r" or ""))
if deadSec>=1 then ac.eval:SetText(ecol..eval.."|r  |cff88ff88生存时 "..U.Pct2(pctAlive).."|r")
else ac.eval:SetText(ecol..eval.."|r") end
if deadSec>=1 then
ac.split:SetText(string.format("活跃 |cff88ddff%.0fs|r · 空闲 |cffaaaaaa%.0fs|r · 死亡 |cffff5555%.0fs|r · 战斗 %.0fs",
active, math.max(0,aliveDur-active), deadSec, dur))
else
ac.split:SetText(string.format("活跃 |cff88ddff%.0fs|r · 空闲 |cffaaaaaa%.0fs|r · 战斗 %.0fs", active, math.max(0,dur-active), dur))
end
if rec.actions and aliveDur>0 then ac.apm:SetText(string.format("主动操作 %d 次  约 %.0f 次/分", rec.actions, rec.actions/aliveDur*60))
else ac.apm:SetText("") end
for _,t in ipairs(actSegs) do t:Hide() end
for _,m in ipairs(deathMarks) do m:Hide() end
local iv = rec.iv
local barW = ac.tl:GetWidth()
if barW<10 then barW=math.max(100,(ac:GetWidth() or frame:GetWidth() or 700)-(ac._timelineInset or 44)) end
if iv and #iv>=2 and dur>0 then
local maxGap, gapN, prevEnd, si = 0, 0, 0, 0
for k=1,#iv,2 do
local s,e = iv[k], iv[k+1]
local gap = s-prevEnd
if gap>=2 then gapN=gapN+1; if gap>maxGap then maxGap=gap end end
prevEnd = e
si=si+1
local tex=actSegs[si]
if not tex then tex=ac.tl:CreateTexture(nil,"ARTWORK"); tex:SetColorTexture(0.3,0.8,0.4,0.95); actSegs[si]=tex end
tex:ClearAllPoints(); tex:SetPoint("LEFT", ac.tl, "LEFT", barW*math.min(1,s/dur), 0)
tex:SetWidth(math.max(1, barW*math.min(1,(e-s)/dur))); tex:SetHeight(14); tex:Show()
end
local tail = dur-prevEnd
if tail>=2 then gapN=gapN+1; if tail>maxGap then maxGap=tail end end
local extra = (deadSec>=1) and string.format("  |cffff5555死亡 %d 次|r", #(rec.deathTimes or {})) or ""
ac.gaps:SetText(string.format("|cff888888空闲 ≥2s 共 %d 段,最长 %.1fs|r%s", gapN, maxGap, extra))
else
ac.gaps:SetText("|cff888888(无逐段时间轴:仅本人 / 本机目击的团员有;他人仅活跃总量)|r")
end
if rec.deathTimes and dur>0 then
for di,dt in ipairs(rec.deathTimes) do
local m=deathMarks[di]
if not m then
m=CreateFrame("Frame",nil,ac.tl)
m:SetFrameLevel(ac.tl:GetFrameLevel()+6); m:EnableMouse(true)
m.line=m:CreateTexture(nil,"OVERLAY"); m.line:SetPoint("CENTER")
m.line:SetSize(2,20); m.line:SetColorTexture(1,0.15,0.15,1)
m:SetScript("OnEnter",showDeathTooltip)
m:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
deathMarks[di]=m
end
m._deathTime=dt; m._deathDetail=rec.deathDetails and rec.deathDetails[di]
m:ClearAllPoints(); m:SetPoint("CENTER", ac.tl, "LEFT", barW*math.min(1,dt/dur), 0)
m:SetSize(10,20); m:Show()
end
end
end
local function renderActivity(rec, viewDur)
renderActivityInto(frame.detailPane.act,rec,viewDur)
end
local function renderBossTimelineMarkers(chart,bossSpells,dur)
chart._bossMarks=chart._bossMarks or {}
for _,mark in ipairs(chart._bossMarks) do mark:Hide(); mark._event=nil end
if not (D and D.BossEvents and bossSpells and dur and dur>0) then return end
local events=D.BossEvents(bossSpells)
local plotW,plotH=chart.plot:GetWidth(),chart.plot:GetHeight()
if plotW<10 then plotW=(frame:GetWidth() or 900)-28 end
if plotH<10 then plotH=52 end
local shown=0
for _,event in ipairs(events) do
if event.time<=dur and shown<80 then
shown=shown+1
local mark=chart._bossMarks[shown]
if not mark then
mark=CreateFrame("Frame",nil,chart.plot); mark:EnableMouse(true); mark:SetFrameLevel(chart.plot:GetFrameLevel()+5)
mark.line=mark:CreateTexture(nil,"OVERLAY"); mark.line:SetPoint("CENTER"); mark.line:SetWidth(2); mark.line:SetPoint("TOP"); mark.line:SetPoint("BOTTOM")
mark:SetScript("OnEnter",function(self)
local ev=self._event; if not (ev and GameTooltip) then return end
GameTooltip:SetOwner(self,"ANCHOR_TOP")
GameTooltip:ClearLines()
if ev.spellId and ev.spellId>0 and GameTooltip.SetHyperlink then GameTooltip:SetHyperlink("spell:"..ev.spellId)
else GameTooltip:AddLine(ev.name or "Boss技能",1,0.82,0) end
local labels={[1]="开始施放",[2]="施放",[3]="施加Aura",[4]="移除Aura"}
GameTooltip:AddDoubleLine("时间",string.format("%.1f秒",ev.time or 0),0.8,0.8,0.8,1,1,1)
GameTooltip:AddDoubleLine("事件",labels[ev.code] or "技能",0.8,0.8,0.8,1,1,1)
if ev.target and ev.target~="" then GameTooltip:AddDoubleLine("目标",ev.target,0.8,0.8,0.8,1,1,1) end
GameTooltip:Show()
end)
mark:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
chart._bossMarks[shown]=mark
end
mark._event=event
local colors={[1]={1,0.72,0.10,0.95},[2]={1,0.42,0.18,0.85},[3]={0.82,0.35,0.95,0.85},[4]={0.55,0.55,0.60,0.65}}
mark.line:SetColorTexture(unpack(colors[event.code] or colors[2]))
mark:ClearAllPoints(); mark:SetPoint("BOTTOMLEFT",chart.plot,"BOTTOMLEFT",plotW*math.min(1,event.time/dur)-2,0)
mark:SetSize(5,plotH); mark:Show()
end
end
end
local function renderTimelineInto(chart, rec, viewDur, damageMode, isHeal, playerLabel, bossSpells)
chart._bars=chart._bars or {}
chart._hits=chart._hits or {}
local timelineBars,timelineHits=chart._bars,chart._hits
for _, bar in ipairs(timelineBars) do bar:Hide() end
for _, hit in ipairs(timelineHits) do hit:Hide(); hit.timelineRate=nil end
local buckets = U.PlayerTimelineBuckets(rec,damageMode)
local rates, count, peak, spans, dur, bucketSec = U.ResampleTimelineBuckets(
buckets, rec.ivDur or viewDur, rec.timelineBucket or 5, DETAIL_TIMELINE_COLUMNS)
local metric = isHeal and "HPS" or "DPS"
local scope = isHeal and "有效治疗" or (damageMode == "all" and "Boss战全目标" or "WCL口径")
chart.title:SetText((playerLabel and (playerLabel.."  ") or "").."每 "..bucketSec.." 秒 "..metric.." 曲线  |cff888888"..scope.."|r")
chart.peak:SetText(peak > 0 and ("峰值 "..U.Short(peak)) or "")
U.RenderTimelineAxis(chart.axis, dur, { fallbackWidth=(frame:GetWidth() or 900)-28,
minLabelSpacing=30, opacityRoot=frame,
fontFn=function(label) if Style and Style.ApplyFontFace then Style:ApplyFontFace(label) end end })
U.RenderTimelineGuides(chart.plot, peak, { step=2000, major=10000,
fallbackHeight=52, opacityRoot=frame })
renderBossTimelineMarkers(chart,bossSpells,dur)
if count == 0 then
chart.empty:SetText("|cff777777此战斗没有 5 秒曲线数据（旧记录无法从总量还原）|r")
return
end
chart.empty:SetText("")
local plotW, plotH = chart.plot:GetWidth(), chart.plot:GetHeight()
if plotW < 10 then plotW = (frame:GetWidth() or 900) - 28 end
if plotH < 10 then plotH = 52 end
local barW = plotW / count
local color = isHeal and {0.25, 0.90, 0.45}
or ((RAID_CLASS_COLORS and RAID_CLASS_COLORS[rec.class]) or {r=0.35,g=0.65,b=1})
local cr, cg, cb = color.r or color[1], color.g or color[2], color.b or color[3]
for i = 1, count do
local bar = timelineBars[i]
if not bar then
bar = chart.plot:CreateTexture(nil, "ARTWORK")
timelineBars[i] = bar
end
local h = peak > 0 and math.max(1, plotH * rates[i] / peak) or 1
bar:ClearAllPoints()
bar:SetPoint("BOTTOMLEFT", chart.plot, "BOTTOMLEFT", (i - 1) * barW, 0)
bar:SetSize(math.max(1, barW - 1), h)
bar:SetColorTexture(cr, cg, cb, 0.82)
bar:Show()
local hit=timelineHits[i]
if not hit then
hit=CreateFrame("Frame",nil,chart.plot); hit:EnableMouse(true)
U.BindTimelineBarTooltip(hit,frame); timelineHits[i]=hit
end
local startSec = spans[i] and spans[i].startSec or (i - 1) * bucketSec
local endSec = spans[i] and spans[i].endSec or startSec + bucketSec
hit:ClearAllPoints(); hit:SetPoint("BOTTOMLEFT",chart.plot,"BOTTOMLEFT",(i-1)*barW,0)
hit:SetSize(math.max(1,barW),plotH)
hit.timelineMetric=metric; hit.timelineRate=rates[i]
hit.timelineStart=startSec; hit.timelineEnd=endSec; hit:Show()
end
end
local function renderTimeline(rec, viewDur, damageMode, isHeal, bossSpells)
renderTimelineInto(frame.detailPane.chart,rec,viewDur,damageMode,isHeal,nil,bossSpells)
end
local function renderGearInto(gear,rec)
local gearItems = NoWCL.Readiness and NoWCL.Readiness.GetGearSet and NoWCL.Readiness:GetGearSet(rec and rec.gearKey)
gear.missing:SetShown(not gearItems)
for i, slot in ipairs(EQUIP_SLOTS) do
local b, link = gear.items[i], gearItems and gearItems[slot]
b.itemLink = link
if link then
local icon = GetItemInfo and select(10, GetItemInfo(link))
if not icon and GetItemInfoInstant then icon = select(5, GetItemInfoInstant(link)) end
if not icon and GetItemIcon then icon = GetItemIcon(link) end
b.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
b.icon:SetDesaturated(false); b.icon:SetVertexColor(1,1,1,1)
local q = GetItemInfo and select(3, GetItemInfo(link))
local qc = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
b.border:SetColorTexture(qc and qc.r or 0.35, qc and qc.g or 0.35, qc and qc.b or 0.38, 1)
else
b.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
b.icon:SetDesaturated(true); b.icon:SetVertexColor(0.35,0.35,0.38,0.65)
b.border:SetColorTexture(0.22,0.22,0.25,0.8)
end
end
end
local compareSpellRows,compareTargetRows,compareBuffRows,compareDebuffRows={},{},{},{}
local function applyCompareRowStyle(row)
local h=auditRowHeight(); row:SetHeight(h)
local iconSize=math.max(12,math.min(16,h-2))
for _,half in ipairs({row.left,row.right}) do
half.bar:SetHeight(auditDetailFillHeight()); half.icon:SetSize(iconSize,iconSize)
if Style and Style.ApplyTexture then Style:ApplyTexture(half.bar,0.25,0.45,0.75,0.5) end
if Style and Style.ApplyFont then Style:ApplyFont(half.name,-1); Style:ApplyFont(half.val,-1) end
end
end
local function detailRowsMap(rows,valueField,labelFn)
local values,details={},{}
for _,row in ipairs(rows or {}) do
local key=labelFn and labelFn(row) or row.name
values[key]=row[valueField] or 0; details[key]=row
end
return values,details
end
local function detailMetricData(rec,view,dpsMode)
local role=roleOf(rec)
local isHeal=role=="HEALER"
local total=displayAmount(rec,dpsMode,view)
local bossCfg=(view.cfg and view.cfg.bossCfg) or (NoWCL.db and NoWCL.db.settings and NoWCL.db.settings.bossCfg)
local detailed=D and D.SpellRows and D.SpellRows(rec,isHeal,view.encounter,dpsMode,bossCfg) or {}
local spellMap,spellDetails=detailRowsMap(detailed,"amount")
local auraBoss
if A.sel~="all" then auraBoss=view.encounter end
local buffs=detailBuffRows(rec,view.dur,auraBoss,bossCfg)
local debuffs=D and D.AuraRows and D.AuraRows(rec,"debuff",view.dur,auraBoss,bossCfg) or {}
local buffMap,buffDetails=detailRowsMap(buffs,"uptime",function(row) return auraLabel(row,"buff",rec.name) end)
local debuffMap,debuffDetails=detailRowsMap(debuffs,"uptime",function(row) return auraLabel(row,"debuff",rec.name) end)
return {
rec=rec,role=role,isHeal=isHeal,total=total,
detailTotal=isHeal and total or U.N(rec.dmg), spellTotal=total,
spells=next(spellMap) and spellMap or (isHeal and rec.heals or rec.spells), spellDetails=spellDetails,
targets=isHeal and rec.healTargets or rec.targets,
buffs=buffMap,buffDetails=buffDetails,debuffs=debuffMap,debuffDetails=debuffDetails,
metric=isHeal and "治疗" or (dpsMode=="boss" and "WCL伤害" or "全程伤害"),
}
end
local function makeCompareRow(pool,index)
if pool[index] then return pool[index] end
local list=frame.detailPane.compare.list
local row=CreateFrame("Frame",nil,list); row:SetHeight(auditRowHeight())
U.RegisterOpacityChromeHover(frame,row)
local function half(left)
local h=CreateFrame("Frame",nil,row)
h:EnableMouse(true)
if left then
h:SetPoint("TOPLEFT"); h:SetPoint("BOTTOMLEFT"); h:SetPoint("RIGHT",row,"CENTER",-7,0)
else
h:SetPoint("TOPRIGHT"); h:SetPoint("BOTTOMRIGHT"); h:SetPoint("LEFT",row,"CENTER",7,0)
end
h.bar=h:CreateTexture(nil,"BACKGROUND"); h.bar:SetPoint("LEFT",20,0); h.bar:SetHeight(auditDetailFillHeight())
h.icon=h:CreateTexture(nil,"ARTWORK"); h.icon:SetPoint("LEFT",1,0); h.icon:SetSize(16,16); h.icon:SetTexCoord(0.08,0.92,0.08,0.92)
h.name=h:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); h.name:SetPoint("LEFT",24,0); h.name:SetJustifyH("LEFT")
h.val=h:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); h.val:SetPoint("RIGHT",-5,0); h.val:SetJustifyH("RIGHT")
if Style and Style.ApplyFont then Style:ApplyFont(h.name,-1); Style:ApplyFont(h.val,-1) end
h:SetScript("OnEnter",function(self)
if self._spellDetail then setSpellTooltip(self,self._spellDetail,self._isHeal,self._spellTotal)
elseif self._auraDetail then setAuraTooltip(self,self._auraDetail,self._auraKind) end
end)
h:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
return h
end
row.left=half(true); row.right=half(false); applyCompareRowStyle(row)
pool[index]=row
return row
end
local function compareKeys(left,right)
local seen,list={},{}
for name,value in pairs(left or {}) do
seen[name]=true; list[#list+1]={name=name,sort=U.N(value)}
end
for name,value in pairs(right or {}) do
if seen[name] then
for _,it in ipairs(list) do if it.name==name then it.sort=math.max(it.sort,U.N(value)); break end end
else
list[#list+1]={name=name,sort=U.N(value)}
end
end
table.sort(list,function(a,b) if a.sort==b.sort then return tostring(a.name)<tostring(b.name) end return a.sort>b.sort end)
return list
end
local function renderCompareHalf(h,name,value,total,maxValue,opts)
h._spellDetail=nil; h._spellTotal=nil; h._auraDetail=nil; h._auraKind=nil
if value==nil then
h.bar:Hide(); h.icon:Hide(); h.name:SetText(""); h.val:SetText(""); return
end
local halfW=h:GetWidth(); if halfW<100 then halfW=((frame:GetWidth() or 900)-64)/2 end
local barMax=math.max(60,halfW-28)
h.bar:SetWidth(math.max(1,barMax*U.N(value)/math.max(1,maxValue))); h.bar:Show()
if opts.isTarget then
h.icon:Hide(); h.name:ClearAllPoints(); h.name:SetPoint("LEFT",8,0)
local included=opts.isHeal or opts.includeAll or (opts.targetsBoss and opts.targetsBoss[name])
local col=included and {0.30,0.80,0.40} or {0.50,0.50,0.55}
if Style and Style.SetTextureColor then Style:SetTextureColor(h.bar,col[1],col[2],col[3],rowOpaque() and 1 or 0.5) end
elseif opts.auraDetails and opts.auraDetails[name] then
local detail=opts.auraDetails[name]
h.name:ClearAllPoints(); h.name:SetPoint("LEFT",24,0)
local icon=detail.spellId and detail.spellId>0 and GetSpellTexture(detail.spellId)
if icon then h.icon:SetTexture(icon); h.icon:Show() else h.icon:Hide() end
local col=opts.auraKind=="debuff" and {0.82,0.42,0.90} or {0.35,0.72,1.0}
if Style and Style.SetTextureColor then Style:SetTextureColor(h.bar,col[1],col[2],col[3],rowOpaque() and 1 or 0.48) end
else
h.name:ClearAllPoints(); h.name:SetPoint("LEFT",24,0)
local meta=NoWCL.Stats.spellInfo and NoWCL.Stats.spellInfo[name]
local icon=meta and meta.icon
if not icon then icon=GetSpellTexture(name=="近战" and 6603 or name) end
if icon then h.icon:SetTexture(icon); h.icon:Show() else h.icon:Hide() end
local col=schoolColor(meta and meta.school)
if Style and Style.SetTextureColor then Style:SetTextureColor(h.bar,col[1],col[2],col[3],rowOpaque() and 1 or 0.5) end
end
local label=name
if opts.isTarget and opts.isHeal and opts.classByName then label=U.ClassColor(name,opts.classByName[name]) end
h.name:SetWidth(math.max(40,halfW-202)); h.name:SetText(label)
if opts.spellDetails and opts.spellDetails[name] then
local detail=opts.spellDetails[name]; h._spellDetail=detail; h._spellTotal=total; h._isHeal=opts.isHeal
local casts=(detail.casts or 0)>0 and tostring(detail.casts) or "-"
local crit=(detail.hits or 0)>0 and string.format("%.0f%%",(detail.crits or 0)/detail.hits*100) or "-"
h.val:SetText(U.Short(value).."  |cffffd100"..U.Pct2(total>0 and value/total or 0).."|r  "..casts.."施/"..(detail.hits or 0).."中  "..crit.."暴")
elseif opts.auraDetails and opts.auraDetails[name] then
local detail=opts.auraDetails[name]; h._auraDetail=detail; h._auraKind=opts.auraKind
h.val:SetText(string.format("%.1fs  |cffffd100%.0f%%|r  %d次",detail.uptime or 0,(detail.percent or 0)*100,detail.count or 0))
else
h.val:SetText(U.Short(value).."  |cffffd100"..U.Pct2(total>0 and value/total or 0).."|r")
end
end
local function renderCompareRows(pool,left,right,leftTotal,rightTotal,y,leftOpts,rightOpts)
local keys=compareKeys(left,right)
local maxValue=1
for _,it in ipairs(keys) do maxValue=math.max(maxValue,U.N(left and left[it.name]),U.N(right and right[it.name])) end
for index,it in ipairs(keys) do
local row=makeCompareRow(pool,index); row:Show()
row:ClearAllPoints(); row:SetPoint("TOPLEFT",0,y); row:SetPoint("TOPRIGHT",0,y)
renderCompareHalf(row.left,it.name,left and left[it.name],leftTotal,maxValue,leftOpts)
renderCompareHalf(row.right,it.name,right and right[it.name],rightTotal,maxValue,rightOpts)
y=y-auditRowHeight()-1
end
for index=#keys+1,#pool do pool[index]:Hide() end
return y
end
local function playerLabel(rec,size)
return U.SpecIconTag(rec.specId,size or 14)..U.ClassColor(rec.name,rec.class)
end
local function renderComparison(view,leftRec,rightRec,dpsMode)
local dp,cmp=frame.detailPane,frame.detailPane.compare
local left=detailMetricData(leftRec,view,dpsMode)
local right=detailMetricData(rightRec,view,dpsMode)
cmp:Show(); dp.gear:Hide(); dp.act:Hide(); dp.chart:Hide(); dp.list:Hide()
dp.header:SetText(playerLabel(leftRec,16).."  |cff888888对比|r  "..playerLabel(rightRec,16))
for i,data in ipairs({left,right}) do
local gear=cmp.gears[i]; gear.label:SetText(playerLabel(data.rec,14)); renderGearInto(gear,data.rec)
local ac=cmp.activities[i]; ac.player:SetText(playerLabel(data.rec,14)); renderActivityInto(ac,data.rec,view.dur)
renderTimelineInto(cmp.charts[i],data.rec,view.dur,dpsMode,data.isHeal,playerLabel(data.rec,13),view.bossSpells)
end
local classByName={}
for _,p in ipairs(view.players or {}) do if p.name and p.class then classByName[p.name]=p.class end end
local y=0
cmp.spellLeft:ClearAllPoints(); cmp.spellRight:ClearAllPoints()
cmp.spellLeft:SetText("|cffffd100按技能|r  "..playerLabel(leftRec,13).."  "..left.metric.." "..U.Short(left.total))
cmp.spellRight:SetText("|cffffd100按技能|r  "..playerLabel(rightRec,13).."  "..right.metric.." "..U.Short(right.total))
cmp.spellLeft:SetPoint("TOPLEFT",0,y); cmp.spellRight:SetPoint("TOPRIGHT",0,y); y=y-20
y=renderCompareRows(compareSpellRows,left.spells,right.spells,left.spellTotal,right.spellTotal,y,
{isTarget=false,isHeal=left.isHeal,spellDetails=left.spellDetails},
{isTarget=false,isHeal=right.isHeal,spellDetails=right.spellDetails})
y=y-9
cmp.targetLeft:ClearAllPoints(); cmp.targetRight:ClearAllPoints()
cmp.targetLeft:SetText("|cffffd100按目标|r  "..playerLabel(leftRec,13))
cmp.targetRight:SetText("|cffffd100按目标|r  "..playerLabel(rightRec,13))
cmp.targetLeft:SetPoint("TOPLEFT",0,y); cmp.targetRight:SetPoint("TOPRIGHT",0,y); y=y-20
y=renderCompareRows(compareTargetRows,left.targets,right.targets,left.detailTotal,right.detailTotal,y,
{isTarget=true,isHeal=left.isHeal,includeAll=dpsMode=="all",targetsBoss=leftRec.targetsBoss,classByName=classByName},
{isTarget=true,isHeal=right.isHeal,includeAll=dpsMode=="all",targetsBoss=rightRec.targetsBoss,classByName=classByName})
y=y-9
cmp.buffLeft:ClearAllPoints(); cmp.buffRight:ClearAllPoints()
cmp.buffLeft:SetText("|cffffd100Buff覆盖|r  "..playerLabel(leftRec,13))
cmp.buffRight:SetText("|cffffd100Buff覆盖|r  "..playerLabel(rightRec,13))
cmp.buffLeft:SetPoint("TOPLEFT",0,y); cmp.buffRight:SetPoint("TOPRIGHT",0,y); y=y-20
showDetailSelfBuffCheck(cmp.selfBuffCheck,cmp.selfBuffLabel)
y=renderCompareRows(compareBuffRows,left.buffs,right.buffs,view.dur,view.dur,y,
{isTarget=false,auraDetails=left.buffDetails,auraKind="buff"},
{isTarget=false,auraDetails=right.buffDetails,auraKind="buff"})
y=y-9
cmp.debuffLeft:ClearAllPoints(); cmp.debuffRight:ClearAllPoints()
cmp.debuffLeft:SetText("|cffffd100Debuff覆盖|r  "..playerLabel(leftRec,13))
cmp.debuffRight:SetText("|cffffd100Debuff覆盖|r  "..playerLabel(rightRec,13))
cmp.debuffLeft:SetPoint("TOPLEFT",0,y); cmp.debuffRight:SetPoint("TOPRIGHT",0,y); y=y-20
y=renderCompareRows(compareDebuffRows,left.debuffs,right.debuffs,view.dur,view.dur,y,
{isTarget=false,auraDetails=left.debuffDetails,auraKind="debuff"},
{isTarget=false,auraDetails=right.debuffDetails,auraKind="debuff"})
local contentH=500+(-y)+4
setFrameHeight(contentH+AUDIT_BOTTOM_PAD+(frame._tabRows or 1)*22+26)
dp:SetHeight(contentH)
if frame.detailScroll.UpdateScrollChildRect then frame.detailScroll:UpdateScrollChildRect() end
end
local function renderDetail(view)
view = view or getAuditView(A.sel, true)
local rec,compareRec,candidateCount
candidateCount=0
for _,p in ipairs(view.players or {}) do
if p.name==A.detailPlayer then rec=p end
if p.name==A.comparePlayer then compareRec=p end
end
if rec then
for _,p in ipairs(view.players or {}) do
if p.name~=rec.name and p.class==rec.class then candidateCount=candidateCount+1 end
end
end
local dp=frame.detailPane
if not rec then dp.header:SetText("无数据"); dp.roleBtn:Hide(); dp.compareBtn:Disable(); dp.compareBtn:SetText("同职业对比")
dp.compare:Hide(); dp.list:Show(); dp.act:Hide(); dp.gear:Hide(); dp.chart:Hide()
for _,r in ipairs(spellRows) do r:Hide() end; for _,r in ipairs(targetRows) do r:Hide() end
for _,pool in ipairs({buffRows,debuffRows,bossDetailRows,compareSpellRows,compareTargetRows,compareBuffRows,compareDebuffRows}) do for _,r in ipairs(pool) do r:Hide() end end
dp.spellLbl:Hide(); dp.tgtLbl:Hide(); dp.buffLbl:Hide(); dp.debuffLbl:Hide(); dp.bossLbl:Hide()
dp.selfBuffCheck:Hide(); dp.selfBuffLabel:Hide()
dp.compare.selfBuffCheck:Hide(); dp.compare.selfBuffLabel:Hide()
for _, head in ipairs(dp.spellHeads) do head:Hide() end
for _, head in ipairs(dp.buffHeads) do head:Hide() end
for _, head in ipairs(dp.debuffHeads) do head:Hide() end
local contentH=300
setFrameHeight(contentH+(frame._tabRows or 1)*22+26)
dp:SetHeight(contentH)
if frame.detailScroll.UpdateScrollChildRect then frame.detailScroll:UpdateScrollChildRect() end
return
end
if A.comparePlayer and (not compareRec or compareRec.class~=rec.class or compareRec.name==rec.name) then
A.comparePlayer=nil; compareRec=nil
end
dp.compareBtn:SetText(compareRec and ("对比: "..U.Trunc(compareRec.name,8)) or "同职业对比")
if candidateCount>0 then dp.compareBtn:Enable() else dp.compareBtn:Disable() end
dp.roleBtn:Show()
local dpsMode = U.ResolveDamageMode(view, A.sel)
if compareRec then
dp.roleBtn:Hide()
renderComparison(view,rec,compareRec,dpsMode)
return
end
dp.compare:Hide(); dp.list:Show()
dp.gear:Show(); dp.chart:Show()
renderGearInto(dp.gear,rec)
dp.act:Show(); renderActivity(rec, view.dur)
local role = roleOf(rec)
local isHeal = (role == "HEALER")
renderTimeline(rec, view.dur, dpsMode, isHeal, view.bossSpells)
local total=displayAmount(rec,dpsMode,view)
local detailTotal = isHeal and total or (rec.dmg or 0)
local classByName = {}
for _, p in ipairs(view.players or {}) do if p.name and p.class then classByName[p.name] = p.class end end
dp.roleBtn:SetText("角色: "..(role=="TANK" and "坦克" or role=="HEALER" and "治疗" or "输出"))
local metricName = isHeal and "治疗" or (dpsMode == "boss" and "WCL伤害" or "全程伤害")
dp.header:SetText(string.format("%s  —  %s总量 %s",
U.SpecIconTag(rec.specId,16)..(U.RolePrefix and U.RolePrefix(rec, 14) or "") .. U.ClassColor(rec.name, rec.class), metricName, U.Short(total)))
local y = 0
dp.spellLbl:ClearAllPoints(); dp.spellLbl:SetPoint("TOPLEFT",0,y); dp.spellLbl:Show()
dp.spellLbl:SetWidth(math.max(100,(frame:GetWidth() or 900)-SPELL_DETAIL_NAME_RIGHT-28))
dp.spellLbl:SetJustifyH("LEFT")
dp.spellLbl:SetText("|cffffd100按技能|r  |cff777777（悬停查看普通与暴击区间）|r")
positionDetailHeads(dp.spellHeads,SPELL_DETAIL_COLUMNS,dp.list,y)
y = y - 18
local detailSpells = rec.spells
local detailTargets = rec.targets
if isHeal then detailSpells = rec.heals; detailTargets = rec.healTargets end
local bossCfg=(view.cfg and view.cfg.bossCfg) or (NoWCL.db and NoWCL.db.settings and NoWCL.db.settings.bossCfg)
local detailedSpells=D and D.SpellRows and D.SpellRows(rec,isHeal,view.encounter,dpsMode,bossCfg) or {}
y = renderSpellDetailRows(spellRows, detailedSpells, total, y, isHeal)
y = y - 8
dp.tgtLbl:ClearAllPoints(); dp.tgtLbl:SetPoint("TOPLEFT",0,y); dp.tgtLbl:Show()
dp.tgtLbl:SetText(isHeal and "|cffffd100按目标|r |cff888888(对团员)|r"
or (dpsMode == "all" and "|cffffd100按目标伤害|r |cff888888(绿:全程目标均计入总量)|r"
or "|cffffd100按目标伤害|r |cff888888(绿:计入总量;灰:统计口径排除,不体现在伤害总量)|r"))
y = y - 18
y = renderRows(targetRows, detailTargets, detailTotal, y,
{isTarget=true, isHeal=isHeal, includeAll=dpsMode=="all", targetsBoss=rec.targetsBoss, classByName=classByName})
y=y-9; dp.buffLbl:ClearAllPoints(); dp.buffLbl:SetPoint("TOPLEFT",0,y); dp.buffLbl:Show()
dp.buffLbl:SetWidth(math.max(100,(frame:GetWidth() or 900)-AURA_DETAIL_NAME_RIGHT-28)); dp.buffLbl:SetJustifyH("LEFT")
dp.buffLbl:SetText("|cffffd100Buff覆盖|r")
showDetailSelfBuffCheck(dp.selfBuffCheck,dp.selfBuffLabel)
positionDetailHeads(dp.buffHeads,AURA_DETAIL_COLUMNS,dp.list,y)
y=y-18
local auraBoss
if A.sel~="all" then auraBoss=view.encounter end
local buffs=detailBuffRows(rec,view.dur,auraBoss,bossCfg)
y=renderAuraDetailRows(buffRows,buffs,view.dur,y,"buff",rec.name)
y=y-9; dp.debuffLbl:ClearAllPoints(); dp.debuffLbl:SetPoint("TOPLEFT",0,y); dp.debuffLbl:Show()
dp.debuffLbl:SetWidth(math.max(100,(frame:GetWidth() or 900)-AURA_DETAIL_NAME_RIGHT-28)); dp.debuffLbl:SetJustifyH("LEFT")
dp.debuffLbl:SetText("|cffffd100Debuff覆盖|r  |cff777777（按当前Boss目标口径；悬停查看目标）|r")
positionDetailHeads(dp.debuffHeads,AURA_DETAIL_COLUMNS,dp.list,y)
y=y-18
local debuffs=D and D.AuraRows and D.AuraRows(rec,"debuff",view.dur,auraBoss,bossCfg) or {}
y=renderAuraDetailRows(debuffRows,debuffs,view.dur,y,"debuff",rec.name)
local bossRows=D and D.BossRows and D.BossRows(view.bossSpells) or {}
if #bossRows>0 then
y=y-9; dp.bossLbl:ClearAllPoints(); dp.bossLbl:SetPoint("TOPLEFT",0,y); dp.bossLbl:Show()
dp.bossLbl:SetText("|cffff6b55Boss技能|r  |cff888888施法与关键Aura时间点已标记在上方曲线|r")
y=y-18; y=renderBossDetailRows(bossDetailRows,bossRows,y)
else
dp.bossLbl:Hide(); for _,r in ipairs(bossDetailRows) do r:Hide() end
end
local contentH=DETAIL_LIST_FRAME_TOP+(-y)+4
setFrameHeight(contentH+AUDIT_BOTTOM_PAD+(frame._tabRows or 1)*22+26)
dp:SetHeight(contentH)
if frame.detailScroll.UpdateScrollChildRect then frame.detailScroll:UpdateScrollChildRect() end
end
local function setLocalOptionTextColor(enabled, ...)
local shade = enabled and 1 or 0.5
for i=1,select("#",...) do
local widget=select(i,...)
if widget and widget.SetTextColor then widget:SetTextColor(shade,shade,shade) end
end
end
local function updateAuditHeading(view)
if view.readiness then
frame.title:SetText("NoWCL  |cff888888当前状态|r")
else
frame.title:SetText("NoWCL  |cff888888"..(view.encounter or "").."  "..U.FmtTime(view.dur or 0).."|r")
end
local profileLabel = NoWCL.StatsConfig and NoWCL.StatsConfig.ActiveLabel
and NoWCL.StatsConfig.ActiveLabel() or "自定义"
if view.readiness then
frame.sub:SetText("开战准备检查：食物、药剂与团队Buff")
else
frame.sub:SetText("口径："..profileLabel)
end
local showAllCharacters = NoWCL.Sync and NoWCL.Sync.ShowAllCharacterFights
and NoWCL.Sync:ShowAllCharacterFights() or false
local pinSelf = U.WindowPinSelf and U.WindowPinSelf() or false
local healersFirst = U.WindowHealersFirst and U.WindowHealersFirst() or false
if frame.showAllCharactersCheck then frame.showAllCharactersCheck:SetChecked(showAllCharacters) end
if frame.pinSelfCheck then frame.pinSelfCheck:SetChecked(pinSelf) end
if frame.healersFirstCheck then frame.healersFirstCheck:SetChecked(healersFirst) end
setLocalOptionTextColor(showAllCharacters,frame.showAllCharactersLabel)
setLocalOptionTextColor(pinSelf,frame.pinSelfLabel)
setLocalOptionTextColor(healersFirst,frame.healersFirstLabel)
end
local function setAuditHeaders()
for i, fs in ipairs(frame.headerCells or {}) do
fs:SetText(COLS[i][2])
end
end
local function hideCombatRowVisuals(row)
row.amountBarBg:Hide(); row.amountBar:Hide(); row.amountVal:Hide()
for _, bar in ipairs(row.sparkBars or {}) do bar:Hide() end
for _, hit in ipairs(row.sparkHits or {}) do hit:Hide(); hit.timelineRate=nil end
end
local function refreshReadinessAudit(view)
setAuditHeaders()
local checker = NoWCL.ConsumableCheck
view.teamBuffPreviousSources = checker and checker.PreviousBuffSources and checker:PreviousBuffSources() or {}
local players = {}
for _, player in ipairs(view.players or {}) do players[#players + 1] = player end
for i,pl in ipairs(players) do
local row=getRow(i,frame.rowAnchor)
row.playerName=pl.name; row.playerClass=pl.class; row.playerSpecId=pl.specId; row.readinessOnly=true
row.damageViewProvider=function() return getAuditView(A.sel,true),A.sel end
row:Show()
hideCombatRowVisuals(row)
row.bg:SetColorTexture(0,0,0,(i%2==0) and 0.15 or 0)
for _,cell in ipairs(row.cells) do cell:SetText("-"); cell:SetTextColor(0.55,0.55,0.55) end
row.cells[COL_NAME]:SetText(U.SpecIconTag(pl.specId,14)..(U.RolePrefix and U.RolePrefix(pl,12) or "")
..Style:PlayerName((pl.name or "?"):sub(1,12),pl.class))
local pending="|cff666666…|r"
row.cells[COL_ILVL]:SetText(((pl.ilvl or 0)>0) and tostring(pl.ilvl) or pending)
renderGearAudit(row,pl,false)
renderConsumables(row,pl,false)
renderTeamBuff(row,pl,players,view,false)
end
for i=#players+1,#rows do rows[i].readinessOnly=nil; rows[i]:Hide() end
local rowH=auditRowHeight()
frame.rowAnchor:SetHeight(math.max(1,#players*rowH))
setFrameHeight(90+rowH+(frame._tabRows or 1)*22+26+#players*rowH+AUDIT_BOTTOM_PAD)
if frame.listScroll.UpdateScrollChildRect then frame.listScroll:UpdateScrollChildRect() end
end
local function refreshAudit()
if A.detailPlayer then
frame.header:Hide(); for _,r in ipairs(rows) do r:Hide() end
if frame.syncBtn then frame.syncBtn:Hide() end
if frame.syncLabel then frame.syncLabel:Hide() end
local view=getAuditView(A.sel, true)
updateAuditHeading(view)
updateCurrentControls(view)
buildTabs()
frame.listScroll:Hide(); frame.detailScroll:Show(); frame.detailPane:Show(); renderDetail(view); return
end
frame.detailScroll:Hide(); frame.detailPane:Hide(); frame.listScroll:Show(); frame.header:Show()
local view = getAuditView(A.sel, false)
local players = {}
for _, pl in ipairs(view.players or {}) do
if view.currentRosterComplete or hasVisibleContribution(pl)
or (view.puller and view.puller == pl.name) then players[#players+1] = pl end
end
local baseline = (view.cfg and view.cfg.baseline) or NoWCL.db.settings.dpsBaseline or "rank1"
local ratio    = (view.cfg and view.cfg.ratio)    or NoWCL.db.settings.dpsRatio    or 0.6
local bosses   = (view.cfg and view.cfg.bosses)   or NoWCL.Rules:GetActive().bosses or {}
local dpsMode  = U.ResolveDamageMode(view, A.sel)
updateAuditHeading(view)
updateCurrentControls(view)
buildTabs()
updateSyncButton()
if view.readiness then refreshReadinessAudit(view); return end
setAuditHeaders()
local base=baselineValue(players,baseline,bosses,dpsMode,view.dur,view)
local checks = (view.cfg and view.cfg.checks) or NoWCL.db.settings.checks or {}
local function cOn(k) return checks[k] and checks[k].on end
local GREEN,RED = {0.4,0.9,0.4},{1,0.4,0.4}
sortDisplayPlayers(players,dpsMode,view.dur,view)
local rankingMeta=U.DisplayRankingMeta
and U.DisplayRankingMeta(players,dpsMode,view.dur,taskContribForView(view))
if U.PinSelfFirst then U.PinSelfFirst(players) end
for i,pl in ipairs(players) do
local row = getRow(i, frame.rowAnchor); row.playerName = pl.name; row.playerClass = pl.class; row.playerSpecId=pl.specId; row.readinessOnly=nil
row.damageViewProvider=function() return getAuditView(A.sel,true),A.sel end
row:Show()
local isBoss = bosses[pl.name]
row.bg:SetColorTexture(0,0,0,(i%2==0) and 0.15 or 0)
local function set(c,txt,col) local fs=row.cells[c]; fs:SetText(txt or ""); if col then fs:SetTextColor(col[1],col[2],col[3]) else fs:SetTextColor(0.9,0.9,0.9) end end
local grey = isBoss and {0.55,0.55,0.55} or nil
local pend = "|cff666666…|r"
local role = roleOf(pl)
set(COL_NAME, U.SpecIconTag(pl.specId,14)..(U.RolePrefix and U.RolePrefix(pl, 12) or "")
.. Style:PlayerName((pl.name or "?"):sub(1,12), pl.class))
local amount=displayAmount(pl,dpsMode,view)
local metricGroup = role == "HEALER" and "healing" or "damage"
local groupTotal = rankingMeta and rankingMeta.totals[metricGroup] or 0
local groupPeak = rankingMeta and rankingMeta.peaks[metricGroup] or 1
local share = groupTotal > 0 and amount / groupTotal or 0
local amountX, amountW = colX(COL_AMOUNT), COLS[COL_AMOUNT][3]
local pctW, valW = 50, 64
local barX, barW = amountX + pctW + 4, math.max(1, amountW - pctW - 8)
row.cells[COL_AMOUNT]:SetText(U.Pct2(share))
row.cells[COL_AMOUNT]:SetTextColor(0.9,0.9,0.9)
row.amountBarBg:ClearAllPoints(); row.amountBarBg:SetPoint("LEFT", row, "LEFT", barX, 0); row.amountBarBg:SetWidth(barW)
row.amountBarBg:SetColorTexture(0.12,0.12,0.14,rowOpaque() and 1 or 0.9); row.amountBarBg:Show()
row.amountBar:ClearAllPoints(); row.amountBar:SetPoint("LEFT", row, "LEFT", barX, 0); row.amountBar:SetWidth(math.max(1, barW * (amount / groupPeak)))
local cr, cg, cb = classRGB(pl.class)
local barAlpha = rowOpaque() and (isBoss and 0.45 or 1) or (isBoss and 0.35 or 0.92)
if Style and Style.SetTextureColor then Style:SetTextureColor(row.amountBar, cr, cg, cb, barAlpha) end
row.amountBar:Show()
row.amountVal:ClearAllPoints(); row.amountVal:SetPoint("LEFT", row, "LEFT", amountX + amountW - valW - 4, 0); row.amountVal:SetWidth(valW); row.amountVal:SetText(U.Short(amount)); row.amountVal:Show()
set(COL_ILVL, ((pl.ilvl or 0) > 0) and tostring(pl.ilvl) or pend, grey)
renderGearAudit(row,pl,isBoss)
renderConsumables(row,pl,isBoss)
renderTeamBuff(row,pl,players,view,isBoss)
local actTxt = U.Pct2(pl.activePct) .. (pl.actEst and "~" or "")
if isBoss then set(COL_ACTIVE, actTxt, grey)
elseif cOn("active") then set(COL_ACTIVE, actTxt, (pl.activePct or 0)>=(checks.active.v or 0.5) and GREEN or RED)
else set(COL_ACTIVE, actTxt) end
renderRankSpark(row,pl,view,dpsMode,isBoss)
if role=="HEALER" then
set(COL_RATE,U.Short(displayRate(pl,dpsMode,view.dur,view)),grey or {0.55,0.85,1.0})
else
local rel=base>0 and (effDps(pl,dpsMode,view.dur,view)/base) or 0
set(COL_RATE,U.Short(effDps(pl,dpsMode,view.dur,view)),grey or U.ParseColor(rel))
end
if isBoss or role ~= "DAMAGER" or base <= 0 then
set(COL_ASSESSMENT, "-", grey)
else
local rel=effDps(pl,dpsMode,view.dur,view)/base
set(COL_ASSESSMENT, U.Pct(rel), rel >= ratio and GREEN or RED)
end
set(COL_EXTRA, formatExtraWithTaskBonus(pl, view, dpsMode), grey)
set(COL_DEATH, (pl.deaths or 0)>0 and "|cffff5555"..pl.deaths.."|r" or "0", grey)
local tag12 = pl.needUpdate and "|cffff3030插件需更新|r" or ""
if pl.synced then tag12 = tag12 .. (tag12 ~= "" and " " or "") .. "|cff44ff44已同步|r" end
if isBoss then tag12 = tag12 .. (tag12 ~= "" and " " or "") .. "|cffffd100老板|r" end
set(COL_TAG, tag12)
end
for i=#players+1,#rows do rows[i]:Hide() end
local rowH = auditRowHeight()
frame.rowAnchor:SetHeight(math.max(1,#players*rowH))
setFrameHeight(90 + rowH + (frame._tabRows or 1)*22 + 26 + #players*rowH + AUDIT_BOTTOM_PAD)
if frame.listScroll.UpdateScrollChildRect then frame.listScroll:UpdateScrollChildRect() end
end
local function taskContribSummary(c)
c = c or {}
local n = 0
for _, rule in ipairs(U.TASK_CONTRIB_RULES or {}) do
if c[rule.key] then n = n + 1 end
end
return n > 0 and ("已启用 " .. n .. " 项") or "未启用"
end
local SETTINGS_QQ = "|cff88ddffNoWCL官方群：721255806，非常欢迎反馈和建议|r"
local SETTINGS_AUTHOR = "作者："..U.SpecIconTag(267,14)..U.ClassColor("紫菜叶子","WARLOCK")
local function clampAutoReminderMinutes(value)
value = math.floor(tonumber(value) or 5)
return math.max(1, math.min(10, value))
end
local function clampPerformanceTopCount(value)
value = math.floor(tonumber(value) or 3)
return math.max(1, math.min(8, value))
end
local function normalizeRulesAnnouncementText(value)
value=tostring(value or ""):gsub("[%c]+"," "):gsub("%s+"," ")
value=value:gsub("^%s+",""):gsub("%s+$","")
return U.Trunc and U.Trunc(value,60) or value:sub(1,60)
end
local function commitRulesAnnouncementText(editBox)
if not editBox or editBox._skipCommit or hasLeaderAuthority() then return end
local text=normalizeRulesAnnouncementText(editBox:GetText())
NoWCL.db.settings.rulesAnnouncementText=text
editBox:SetText(text)
editBox:ClearFocus()
if NoWCL.Sync and NoWCL.Sync.BroadcastConfig then NoWCL.Sync:BroadcastConfig() end
A:Refresh()
end
local function refreshAutoReminderTimer()
local checker = NoWCL.ConsumableCheck
if checker and checker.RefreshAutoReminderTimer then checker:RefreshAutoReminderTimer() end
end
local function setAutoReminderEnabled(enabled)
local settings = NoWCL.db and NoWCL.db.settings
if not settings then return end
settings.autoSelfBuffReminder = enabled and true or false
refreshAutoReminderTimer()
A:Refresh()
end
local function commitAutoReminderMinutes(editBox)
local settings = NoWCL.db and NoWCL.db.settings
if not settings then return end
settings.autoSelfBuffReminderMinutes = clampAutoReminderMinutes(editBox and editBox:GetText())
if editBox then
editBox:SetText(settings.autoSelfBuffReminderMinutes)
editBox:ClearFocus()
end
refreshAutoReminderTimer()
end
local function refreshSettings()
local p = frame.settings
if frame.syncBtn then frame.syncBtn:Hide() end
if frame.syncLabel then frame.syncLabel:Hide() end
local canEdit = not hasLeaderAuthority()
local amRealLeader = IsInGroup() and (UnitIsGroupLeader("player") and true or false)
local st = NoWCL.db.settings
local authorityCfg = canEdit and st or ((NoWCL.Sync and NoWCL.Sync.cfg) or st)
local editable = { p.baseLabel,p.ratioLabel,p.baseDD,p.ratioDD,p.modeLabel,p.modeAll,p.modeAll.label,p.modeBoss,p.modeBoss.label,p.ckHead,p.activeDD,p.bossBtn }
local taskCfg = authorityCfg.taskContrib or st.taskContrib or {}
local teamBuffCfg = T and T:MonitorConfig() or {}
for _,w in ipairs(editable) do w:Show() end
for _,cb in ipairs(p.checkBoxes) do cb:Show(); cb.label:Show() end
if canEdit then
if NoWCL.Rules and NoWCL.Rules.ReconcileBossSession then NoWCL.Rules:ReconcileBossSession() end
if amRealLeader then
p.hint:SetText("|cff44ff44你是团长:可编辑以下设置,改动会自动广播全团(团员只读)。|r")
elseif IsInGroup() then
p.hint:SetText("|cff44ff44团长未使用 NoWCL:口径与考核由你本端设置(本地生效,不影响他人)。|r")
else
p.hint:SetText("|cff44ff44单人:口径与考核由你本端设置。|r")
end
else
p.hint:SetText("|cffffd100团长规则全部可查看；标灰项目由团长设置，团员只读。界面外观仍可在本机调整。|r")
end
local baseline = authorityCfg.dpsBaseline or authorityCfg.baseline or st.dpsBaseline or "rank1"
local ratio = tonumber(authorityCfg.dpsRatio or authorityCfg.ratio) or tonumber(st.dpsRatio) or 0.6
local mode = authorityCfg.dpsMode or st.dpsMode or "boss"
local checks = authorityCfg.checks or st.checks or {}
local active = checks.active or {}
p.baseDD:SetText(BASE_NAMES[baseline] or baseline)
p.ratioDD:SetText(math.floor(ratio*100).."%")
p.modeAll:SetChecked(mode == "all")
p.modeBoss:SetChecked(mode ~= "all")
p.activeDD:SetText(math.floor((tonumber(active.v) or 0.5)*100).."%")
p.ckActive:SetChecked(active.on == true)
for _,control in ipairs({p.baseDD,p.ratioDD,p.modeAll,p.modeBoss,p.ckActive,p.activeDD}) do
if canEdit then control:Enable() else control:Disable() end
end
for _,label in ipairs({p.baseLabel,p.ratioLabel,p.modeLabel}) do
if canEdit then label:SetTextColor(1,0.82,0) else label:SetTextColor(0.5,0.5,0.5) end
end
for _,label in ipairs({p.modeAll.label,p.modeBoss.label,p.ckActive.label}) do
if canEdit then label:SetTextColor(1,1,1) else label:SetTextColor(0.5,0.5,0.5) end
end
p.bossBtn:SetText(canEdit and "WCL口径/自定义" or "查看WCL口径/自定义")
p.bossBtn:Enable()
p.taskBtn:SetText(canEdit and "额外任务贡献换算" or "查看任务换算设置")
p.taskBtn:Enable()
p.taskSummary:SetText("任务换算: "..taskContribSummary(taskCfg)
..(canEdit and "  |cff888888(点击按钮打开列表设置)|r" or "  |cff888888(团长设置,只读)|r"))
p.teamBuffBtn:SetText(canEdit and "团队Buff监控设置" or "查看团队Buff监控")
p.teamBuffBtn:Enable()
p.teamBuffSummary:SetText((T and T:MonitorSummary(teamBuffCfg) or "未加载")
..(canEdit and "" or "  |cff888888(团长设置,只读)|r"))
p.taskHead:Show(); p.taskBtn:Show(); p.taskSummary:Show()
p.teamBuffHead:Show(); p.teamBuffBtn:Show(); p.teamBuffSummary:Show()
local autoSelfBuff = st.autoSelfBuffReminder == true
p.autoSelfBuffCheck:SetChecked(autoSelfBuff)
if not p.autoSelfBuffMinutes:HasFocus() then
p.autoSelfBuffMinutes:SetText(clampAutoReminderMinutes(st.autoSelfBuffReminderMinutes))
end
setLocalOptionTextColor(autoSelfBuff,p.autoSelfBuffPrefix,p.autoSelfBuffMinutes,p.autoSelfBuffSuffix)
p.appearanceHead:Show(); p.appearanceBtn:Show(); p.appearanceSummary:Show()
p.appearanceSummary:SetText((Style and Style.Summary) and Style:Summary() or "默认外观")
local whisperGearPrompt = st.whisperGearPrompt == true
p.whisperGearCheck:SetChecked(whisperGearPrompt)
setLocalOptionTextColor(whisperGearPrompt,p.whisperGearCheck.label)
local numberUnits = U.NumberUnits and U.NumberUnits() or "cn"
p.unitCN:SetChecked(numberUnits == "cn")
p.unitMK:SetChecked(numberUnits == "mk")
local panelLayer = U.PanelLayerMode and U.PanelLayerMode() or "system"
p.layerDD:SetText(U.PanelLayerLabel and U.PanelLayerLabel(panelLayer) or "系统窗口优先")
local gearHoverMode=NoWCL.GearInspectPanel and NoWCL.GearInspectPanel.GetHoverMode
and NoWCL.GearInspectPanel:GetHoverMode("gear") or "disabled"
local damageHoverMode=NoWCL.GearInspectPanel and NoWCL.GearInspectPanel.GetHoverMode
and NoWCL.GearInspectPanel:GetHoverMode("damage") or "disabled"
local gearHoverLabels={hover="鼠标移动",ctrl="按住 Ctrl",alt="按住 Alt",disabled="禁止"}
p.gearHoverDD:SetText(gearHoverLabels[gearHoverMode] or gearHoverLabels.disabled)
p.damageHoverDD:SetText(gearHoverLabels[damageHoverMode] or gearHoverLabels.disabled)
local auto30 = st.autoPrune30 ~= false
p.storageCheck:SetChecked(auto30)
p.autoClearRaidCheck:SetChecked(st.autoClearNewRaidCD == true)
local announcement = NoWCL.TeamAnnouncements
local announcementCfg=canEdit and st or ((NoWCL.Sync and NoWCL.Sync.cfg) or st)
local announcementRows = {
{ feature="rules", check=p.rulesAnnounceCheck, state=p.rulesAnnounceState,
label="进团通报 NCL 考核规则" },
{ feature="death", check=p.deathAnnounceCheck, state=p.deathAnnounceState,
label="自动通告角色死亡与最后一击" },
{ feature="performance", check=p.performanceAnnounceCheck, state=p.performanceAnnounceState,
label="DPS排名通告" },
{ feature="failures", check=p.failureAnnounceCheck, state=p.failureAnnounceState,
label="不及格通告" },
{ feature="pull", check=p.pullStartAnnounceCheck, state=p.pullStartAnnounceState,
label="开怪通告" },
}
for _, row in ipairs(announcementRows) do
local enabled = announcement and announcement.IsEnabled and announcement:IsEnabled(row.feature) or false
row.check:SetChecked(enabled)
if canEdit then
row.check:Enable()
row.check.label:SetText(row.label)
else
row.check:Disable()
row.check.label:SetText(row.label .. " |cff888888(跟随团长)|r")
end
local owner = announcement and announcement.PublisherState
and announcement:PublisherState(row.feature) or "当前负责：无"
if not canEdit and not NoWCL.Sync.cfg then owner = "|cff888888等待团长设置|r" end
row.state:SetText((enabled and "|cff44ff44已开启|r；" or "|cff888888已关闭|r；") .. owner)
end
if not p.rulesTextEdit:HasFocus() then
p.rulesTextEdit:SetText(normalizeRulesAnnouncementText(announcementCfg.rulesAnnouncementText))
end
if canEdit then p.rulesTextEdit:Enable() else p.rulesTextEdit:Disable() end
p.rulesTextEdit:SetTextColor(canEdit and 1 or 0.55,canEdit and 1 or 0.55,canEdit and 1 or 0.55)
p.rulesTextLabel:SetTextColor(canEdit and 0.75 or 0.45,canEdit and 0.78 or 0.45,canEdit and 0.82 or 0.45)
local rankingMode=announcementCfg.performanceRankingMode=="all" and "all" or "split"
local rankingScope=announcementCfg.performanceScope=="summary" and "summary" or "fight"
p.performanceModeAll:SetChecked(rankingMode=="all")
p.performanceModeSplit:SetChecked(rankingMode=="split")
p.performanceScopeFight:SetChecked(rankingScope=="fight")
p.performanceScopeSummary:SetChecked(rankingScope=="summary")
if not p.performanceTopCount:HasFocus() then
p.performanceTopCount:SetText(clampPerformanceTopCount(announcementCfg.performanceTopCount))
end
local failureDps=announcementCfg.failureDps~=false
local failureActivity=announcementCfg.failureActivity~=false
local failureScope=announcementCfg.failureScope=="summary" and "summary" or "fight"
p.failureDps:SetChecked(failureDps)
p.failureActivity:SetChecked(failureActivity)
p.failureScopeFight:SetChecked(failureScope=="fight")
p.failureScopeSummary:SetChecked(failureScope=="summary")
for _,control in ipairs({p.performanceModeAll,p.performanceModeSplit,
p.performanceScopeFight,p.performanceScopeSummary,p.failureDps,p.failureActivity,
p.failureScopeFight,p.failureScopeSummary}) do
if canEdit then control:Enable();control.label:SetTextColor(1,1,1)
else control:Disable();control.label:SetTextColor(0.5,0.5,0.5) end
end
if canEdit then p.performanceTopCount:Enable() else p.performanceTopCount:Disable() end
p.performanceTopCount:SetTextColor(canEdit and 1 or 0.5,canEdit and 1 or 0.5,canEdit and 1 or 0.5)
p.performanceTopCountPrefix:SetTextColor(canEdit and 0.75 or 0.45,canEdit and 0.78 or 0.45,canEdit and 0.82 or 0.45)
p.performanceTopCountSuffix:SetTextColor(canEdit and 0.75 or 0.45,canEdit and 0.78 or 0.45,canEdit and 0.82 or 0.45)
p.performanceModeLabel:SetTextColor(canEdit and 0.75 or 0.45,canEdit and 0.78 or 0.45,canEdit and 0.82 or 0.45)
p.performanceScopeLabel:SetTextColor(canEdit and 0.75 or 0.45,canEdit and 0.78 or 0.45,canEdit and 0.82 or 0.45)
p.failureTypeLabel:SetTextColor(canEdit and 0.75 or 0.45,canEdit and 0.78 or 0.45,canEdit and 0.82 or 0.45)
p.failureScopeLabel:SetTextColor(canEdit and 0.75 or 0.45,canEdit and 0.78 or 0.45,canEdit and 0.82 or 0.45)
local tabCount = NoWCL.Sync and NoWCL.Sync.GetAllTabs and #NoWCL.Sync:GetAllTabs()
or (NoWCL.Sync and NoWCL.Sync.GetTabs and #NoWCL.Sync:GetTabs() or 0)
local limit = auto30 and 30 or 99
local bytes = NoWCL.DetailStats and NoWCL.DetailStats.EstimateCombatStorage
and NoWCL.DetailStats.EstimateCombatStorage() or 0
local sizeText = NoWCL.DetailStats and NoWCL.DetailStats.FormatBytes
and NoWCL.DetailStats.FormatBytes(bytes) or "未知"
p.storageState:SetText(string.format("已保存 %d/%d 场，估算占用 %s%s", tabCount, limit, sizeText,
auto30 and "" or "  |cffffaa00(系统最多保留99场)|r"))
p.autoClearRaidState:SetText(st.autoClearNewRaidCD == true
and "|cff44ff44已启用|r；同CD重进或/reload不会重复清空"
or "默认关闭；勾选后从下一个新团本CD开始生效")
updateSettingsContentSize()
setFrameHeight(600)
end
local function makeCheck(parent, x, y, label, onToggle)
local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
cb:SetPoint("TOPLEFT", x, y); cb:SetSize(22,22)
cb.label = parent:CreateFontString(nil,"OVERLAY","GameFontHighlight")
cb.label:SetPoint("LEFT", cb, "RIGHT", 1, 0); cb.label:SetText(label)
cb:SetScript("OnClick", function(self) onToggle(self:GetChecked() and true or false) end)
return cb
end
local showTab
local function extensionContext(host, descriptor)
return {
host = host,
id = descriptor.id,
SetHeader = function(_, title, subtitle)
host.title:SetText(title or ("NoWCL  |cff66ccff" .. descriptor.label .. "|r"))
host.sub:SetText(subtitle or "")
end,
RequestHeight = function(_, height) setFrameHeight(height or 600) end,
Refresh = function() A:Refresh() end,
}
end
local function attachExtensionPage(host, descriptor)
if not host or extensionPages[descriptor.id] then return end
local previous = host._primaryLastButton or host.tabSet
local button = CreateFrame("Button", nil, host, "UIPanelButtonTemplate")
local width = math.max(96, math.min(132, 30 + #descriptor.label * 12))
button:SetSize(width, 22)
button:SetPoint("LEFT", previous, "RIGHT", 4, 0)
button:SetText(descriptor.label)
if Style and Style.ApplyFontFace and button:GetFontString() then Style:ApplyFontFace(button:GetFontString()) end
button:SetScript("OnClick", function() showTab(descriptor.id) end)
host._primaryLastButton = button
U.RegisterOpacityChrome(host, button)
U.RegisterOpacityChromeHover(host, button)
local context = extensionContext(host, descriptor)
local ok, panel = pcall(descriptor.Create, descriptor, host, context)
if not ok or not panel then
local reason = ok and "未返回面板" or tostring(panel)
panel = CreateFrame("Frame", nil, host)
local errorText = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
errorText:SetPoint("CENTER")
errorText:SetText("页面加载失败: " .. reason)
end
if panel:GetNumPoints() == 0 then
panel:SetPoint("TOPLEFT", host, "TOPLEFT", 8, -72)
panel:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -8, 30)
end
if Style and Style.RegisterRoot then Style:RegisterRoot(panel) end
panel:Hide()
extensionPages[descriptor.id] = { descriptor=descriptor, panel=panel, button=button, context=context }
end
showTab = function(which)
frame.tab = which
frame.audit:SetShown(which=="audit")
frame.settingsViewport:SetShown(which=="settings")
if frame.showAllCharactersCheck then frame.showAllCharactersCheck:SetShown(which=="audit") end
if frame.showAllCharactersLabel then frame.showAllCharactersLabel:SetShown(which=="audit") end
if frame.pinSelfCheck then frame.pinSelfCheck:SetShown(which=="audit") end
if frame.pinSelfLabel then frame.pinSelfLabel:SetShown(which=="audit") end
if frame.healersFirstCheck then frame.healersFirstCheck:SetShown(which=="audit") end
if frame.healersFirstLabel then frame.healersFirstLabel:SetShown(which=="audit") end
if frame.azeroth then frame.azeroth:SetShown(which=="azeroth") end
for id, entry in pairs(extensionPages) do
local shown = which == id
entry.panel:SetShown(shown)
entry.button:SetButtonState(shown and "PUSHED" or "NORMAL")
if shown and entry.descriptor.OnShow then
pcall(entry.descriptor.OnShow, entry.descriptor, entry.panel, entry.context)
end
end
frame.tabAudit:SetButtonState(which=="audit" and "PUSHED" or "NORMAL")
frame.tabSet:SetButtonState(which=="settings" and "PUSHED" or "NORMAL")
if frame.tabAzeroth then frame.tabAzeroth:SetButtonState(which=="azeroth" and "PUSHED" or "NORMAL") end
A:Refresh()
end
local function applyOpacityTo(f)
f = f or frame
if not f then return end
if U.ApplyWindowOpacity then U.ApplyWindowOpacity(f) end
if f.opacitySlider and U.SyncOpacitySlider then U.SyncOpacitySlider(f.opacitySlider) end
if f.opacityModeCheck and U.SyncOpacityModeCheck then U.SyncOpacityModeCheck(f.opacityModeCheck) end
end
function A:ApplyOpacity()
applyOpacityTo(frame)
end
function A:ApplyStyle()
if not frame then return end
local rowH = auditRowHeight()
if frame.header then frame.header:SetHeight(rowH) end
for i, row in ipairs(rows) do applyAuditRowStyle(row, i) end
for _, row in ipairs(spellRows) do applyDetailRowStyle(row) end
for _, row in ipairs(targetRows) do applyDetailRowStyle(row) end
for _, row in ipairs(compareSpellRows) do applyCompareRowStyle(row) end
for _, row in ipairs(compareTargetRows) do applyCompareRowStyle(row) end
if frame:IsShown() then A:Refresh() end
end
function A:Refresh()
if not frame or not frame:IsShown() then return end
if frame.tab=="audit" then
updateClearButtons()
refreshAudit()
elseif frame.tab=="azeroth" then
if frame.clearAllBtn then frame.clearAllBtn:Hide() end
if frame.clearCurBtn then frame.clearCurBtn:Hide() end
if frame.syncBtn then frame.syncBtn:Hide() end
if frame.syncLabel then frame.syncLabel:Hide() end
frame.title:SetText("NoWCL  |cff66ccff我的艾泽拉斯|r")
frame.sub:SetText("")
setFrameHeight(600)
if NoWCL.AzerothUI and NoWCL.AzerothUI.Refresh then NoWCL.AzerothUI:Refresh() end
elseif extensionPages[frame.tab] then
if frame.clearAllBtn then frame.clearAllBtn:Hide() end
if frame.clearCurBtn then frame.clearCurBtn:Hide() end
if frame.syncBtn then frame.syncBtn:Hide() end
if frame.syncLabel then frame.syncLabel:Hide() end
local entry = extensionPages[frame.tab]
entry.context:SetHeader(entry.descriptor.title, entry.descriptor.subtitle)
setFrameHeight(600)
if entry.descriptor.Refresh then
pcall(entry.descriptor.Refresh, entry.descriptor, entry.panel, entry.context)
end
else
if frame.clearAllBtn then frame.clearAllBtn:Hide() end
if frame.clearCurBtn then frame.clearCurBtn:Hide() end
refreshSettings()
end
end
local function syncStatusTick()
if frame and frame:IsShown() and frame.tab == "audit" and not A.detailPlayer then
updateSyncButton()
end
end
local function Create()
local state = auditWindowState()
local defaultWidth = columnSum(3) + auditWidthChrome()
local width = clampAuditWidth(state and state.width or defaultWidth)
fitColumnsToWidth(width)
local contentWidth = width - SCROLLBAR_GUTTER
local initialHeight = state and state.manualSize and state.height or 600
local f = CreateFrame("Frame","NoWCLAuditFrame",UIParent); f:SetSize(width,clampAuditHeight(initialHeight)); f:SetPoint("CENTER")
U.SetPanelLayer(f); U.MakeMovable(f)
f:EnableKeyboard(true)
if f.SetPropagateKeyboardInput then f:SetPropagateKeyboardInput(true) end
f:SetScript("OnKeyDown",function(self,key)
if key~="ESCAPE" or (GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()) then
if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(true) end
return
end
if self.SetPropagateKeyboardInput then self:SetPropagateKeyboardInput(false) end
self:Hide()
if NoWCL.MiniUI and NoWCL.MiniUI.Show then NoWCL.MiniUI:Show() end
end)
U.RegisterOpacityChromeHover(f, f)
local bg=f:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.05,0.05,0.07,0.94)
local tb=f:CreateTexture(nil,"ARTWORK"); tb:SetPoint("TOPLEFT"); tb:SetPoint("TOPRIGHT"); tb:SetHeight(28); tb:SetColorTexture(0.12,0.12,0.16,1)
U.RegisterOpacityChrome(f, bg, tb)
f.logo=f:CreateTexture(nil,"OVERLAY"); f.logo:SetSize(20,20); f.logo:SetPoint("LEFT",tb,"LEFT",8,0); f.logo:SetTexture(TITLE_LOGO)
f.title=f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); f.title:SetPoint("LEFT",f.logo,"RIGHT",6,0); f.title:SetText("NoWCL")
local close=CreateFrame("Button",nil,f,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",-2,-2)
close:SetScript("OnClick",function() f:Hide() end)
U.RegisterOpacityChrome(f, f.logo, f.title, close)
U.RegisterOpacityChromeHover(f, close)
f.miniBtn=CreateFrame("Button",nil,f,"UIPanelButtonTemplate"); f.miniBtn:SetSize(90,22); f.miniBtn:SetPoint("RIGHT",close,"LEFT",-4,0); f.miniBtn:SetText("竖窗模式")
f.miniBtn:SetScript("OnClick", function()
f:Hide()
if NoWCL.MiniUI and NoWCL.MiniUI.Show then NoWCL.MiniUI:Show() end
end)
f.sub=f:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); f.sub:SetPoint("TOPLEFT",10,-32)
f.showAllCharactersCheck=CreateFrame("CheckButton",nil,f,"UICheckButtonTemplate")
f.showAllCharactersCheck:SetSize(18,18); f.showAllCharactersCheck:SetPoint("LEFT",f.sub,"RIGHT",8,0)
f.showAllCharactersCheck:SetChecked(NoWCL.Sync and NoWCL.Sync.ShowAllCharacterFights
and NoWCL.Sync:ShowAllCharacterFights())
f.showAllCharactersCheck:SetHitRectInsets(0,-132,0,0)
f.showAllCharactersCheck:SetScript("OnClick",function(self)
local enabled = self:GetChecked() and true or false
if NoWCL.Sync and NoWCL.Sync.SetShowAllCharacterFights then
NoWCL.Sync:SetShowAllCharacterFights(enabled)
end
if not enabled and A.sel ~= "all" and A.sel ~= "current" then
local tab = NoWCL.Sync and NoWCL.Sync.tabs and NoWCL.Sync.tabs[A.sel]
if not (NoWCL.Sync and NoWCL.Sync:IsTabVisibleForCurrentCharacter(tab)) then
A.sel = "all"; A.detailPlayer = nil; A.comparePlayer = nil
end
end
A:Refresh()
if NoWCL.MiniUI and NoWCL.MiniUI.Refresh then
NoWCL.MiniUI.detailPlayer = nil
NoWCL.MiniUI.listScroll = 0
NoWCL.MiniUI:Refresh()
end
end)
f.showAllCharactersLabel=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
f.showAllCharactersLabel:SetPoint("LEFT",f.showAllCharactersCheck,"RIGHT",1,0)
f.showAllCharactersLabel:SetText("显示账号所有角色战斗")
f.pinSelfCheck=CreateFrame("CheckButton",nil,f,"UICheckButtonTemplate")
f.pinSelfCheck:SetSize(18,18); f.pinSelfCheck:SetPoint("LEFT",f.showAllCharactersLabel,"RIGHT",8,0)
f.pinSelfCheck:SetChecked(U.WindowPinSelf and U.WindowPinSelf())
f.pinSelfCheck:SetHitRectInsets(0,-91,0,0)
f.pinSelfCheck:SetScript("OnClick",function(self)
if U.SetWindowPinSelf then U.SetWindowPinSelf(self:GetChecked() and true or false) end
end)
f.pinSelfLabel=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
f.pinSelfLabel:SetPoint("LEFT",f.pinSelfCheck,"RIGHT",1,0); f.pinSelfLabel:SetText("置顶本人数据条")
f.healersFirstCheck=CreateFrame("CheckButton",nil,f,"UICheckButtonTemplate")
f.healersFirstCheck:SetSize(18,18); f.healersFirstCheck:SetPoint("LEFT",f.pinSelfLabel,"RIGHT",8,0)
f.healersFirstCheck:SetChecked(U.WindowHealersFirst and U.WindowHealersFirst())
f.healersFirstCheck:SetHitRectInsets(0,-108,0,0)
f.healersFirstCheck:SetScript("OnClick",function(self)
if U.SetWindowHealersFirst then U.SetWindowHealersFirst(self:GetChecked() and true or false) end
end)
f.healersFirstLabel=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
f.healersFirstLabel:SetPoint("LEFT",f.healersFirstCheck,"RIGHT",1,0); f.healersFirstLabel:SetText("治疗职业排序优先")
U.RegisterOpacityChrome(f, f.miniBtn, f.sub, f.showAllCharactersCheck, f.showAllCharactersLabel,
f.pinSelfCheck, f.pinSelfLabel,
f.healersFirstCheck, f.healersFirstLabel)
U.RegisterOpacityChromeHover(f, f.miniBtn)
U.RegisterOpacityChromeHover(f, f.showAllCharactersCheck)
U.RegisterOpacityChromeHover(f, f.pinSelfCheck)
U.RegisterOpacityChromeHover(f, f.healersFirstCheck)
f.tabAudit=CreateFrame("Button",nil,f,"UIPanelButtonTemplate"); f.tabAudit:SetSize(90,22); f.tabAudit:SetPoint("TOPLEFT",8,-44); f.tabAudit:SetText("统计")
f.tabSet=CreateFrame("Button",nil,f,"UIPanelButtonTemplate"); f.tabSet:SetSize(90,22); f.tabSet:SetPoint("LEFT",f.tabAudit,"RIGHT",4,0); f.tabSet:SetText("设置")
f.tabAudit:SetScript("OnClick", function() showTab("audit") end)
f.tabSet:SetScript("OnClick", function() showTab("settings") end)
f._primaryLastButton=f.tabSet
f.clearAllBtn=CreateFrame("Button",nil,f,"UIPanelButtonTemplate"); f.clearAllBtn:SetSize(96,22); f.clearAllBtn:SetPoint("TOPRIGHT",-8,-44); f.clearAllBtn:SetText("|cffff5555清空全部|r")
f.clearAllBtn:SetScript("OnClick", function() StaticPopup_Show("NOWCL_CLEAR_TABS") end)
f.clearCurBtn=CreateFrame("Button",nil,f,"UIPanelButtonTemplate"); f.clearCurBtn:SetSize(96,22); f.clearCurBtn:SetPoint("RIGHT",f.clearAllBtn,"LEFT",-4,0); f.clearCurBtn:SetText("清空当前")
f.clearCurBtn:SetScript("OnClick", function()
local fid, label = selectedTabInfo()
if not fid then return end
StaticPopup_Show("NOWCL_CLEAR_CURRENT_TAB", label, nil, { fightId = fid })
end)
f.syncBtn=CreateFrame("Button",nil,f,"UIPanelButtonTemplate"); f.syncBtn:SetSize(220,22); f.syncBtn:SetPoint("RIGHT",f.clearCurBtn,"LEFT",-8,0); f.syncBtn:Hide()
f.syncLabel=f:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); f.syncLabel:SetPoint("RIGHT",f.syncBtn,"LEFT",-6,0); f.syncLabel:SetText("本页信息同步:"); f.syncLabel:Hide()
f.opacitySlider = U.MakeOpacitySlider(f, "NoWCLAuditOpacitySlider")
f.opacitySlider:SetPoint("BOTTOMRIGHT", -8, 6)
f.opacityModeCheck = U.MakeOpacityModeCheck(f, "NoWCLAuditOpaqueRowsCheck")
f.opacityModeCheck:SetPoint("RIGHT", f.opacitySlider, "LEFT", -4, 0)
local footerLevel = f:GetFrameLevel() + 20
f.opacitySlider:SetFrameLevel(footerLevel)
f.opacityModeCheck:SetFrameLevel(footerLevel)
f._nowclPanelLayerChanged=function(self)
local level=self:GetFrameLevel()+20
self.opacitySlider:SetFrameLevel(level)
self.opacityModeCheck:SetFrameLevel(level)
if self.resizeGrip then self.resizeGrip:SetFrameLevel(self:GetFrameLevel()+10) end
end
if f.opacitySlider.SetHitRectInsets then f.opacitySlider:SetHitRectInsets(-3, -3, -5, -5) end
if U.RegisterPanelHoverControls then U.RegisterPanelHoverControls(f, f.opacitySlider, f.opacityModeCheck) end
U.RegisterOpacityChrome(f, f.tabAudit, f.tabSet, f.clearAllBtn, f.clearCurBtn, f.syncBtn, f.syncLabel, f.opacitySlider, f.opacityModeCheck)
U.RegisterOpacityChromeHover(f, f.tabAudit)
U.RegisterOpacityChromeHover(f, f.tabSet)
U.RegisterOpacityChromeHover(f, f.clearAllBtn)
U.RegisterOpacityChromeHover(f, f.clearCurBtn)
U.RegisterOpacityChromeHover(f, f.syncBtn)
U.RegisterOpacityChromeHover(f, f.opacitySlider)
U.RegisterOpacityChromeHover(f, f.opacityModeCheck)
if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(1, syncStatusTick) end
f:SetScript("OnUpdate", function(self, elapsed)
self._liveTick = (self._liveTick or 0) + elapsed
if self._liveTick < 0.5 then return end
local tickElapsed = self._liveTick
self._liveTick = 0
if not (self:IsShown() and self.tab == "audit") then return end
if self.currentControls then
self._remindCooldownDisplayed = self._remindCooldownDisplayed or {}
for _, kind in ipairs({ "self", "all" }) do
local button = reminderButton(kind)
if button and button:IsShown() then
local remaining = reminderCooldownRemaining(kind)
if self._remindCooldownDisplayed[kind] ~= remaining then
self._remindCooldownDisplayed[kind] = remaining
updateReminderButtonCooldown(kind)
end
end
end
end
if self.currentControls and self.currentControls.modeBtn:IsShown() then
local remaining = currentSwitchRemaining()
if self._currentSwitchDisplayed ~= remaining then
self._currentSwitchDisplayed = remaining
updateCurrentSwitchButton(true)
end
end
local live = currentLiveVisible()
if self._currentWasLive ~= live then
self._currentWasLive = live
A:Refresh()
return
end
if A.sel == "current" and not A.detailPlayer and not live then
local status = currentStatusActive()
if self._currentStatusRendered ~= status then
A:Refresh()
return
end
if status then
self._readinessScanTick = (self._readinessScanTick or 0) + tickElapsed
if self._readinessScanTick >= CURRENT_READINESS_SCAN_SECONDS then
self._readinessScanTick = 0
local checker = NoWCL.ConsumableCheck
local changed = false
if checker then
local _, scanChanged = checker:Scan()
changed = scanChanged == true
end
if changed then A:Refresh() end
end
else
self._readinessScanTick = 0
end
else
self._readinessScanTick = 0
end
if (A.sel == "current" or A.sel == "all") and live then
A:Refresh()
end
end)
f.audit=CreateFrame("Frame",nil,f); f.audit:SetPoint("TOPLEFT",0,-70); f.audit:SetPoint("BOTTOMRIGHT",0,0)
U.RegisterOpacityChromeHover(f, f.audit)
f.currentControls=CreateFrame("Frame",nil,f.audit); f.currentControls:SetHeight(22); f.currentControls:Hide()
f.currentControls.modeBtn=CreateFrame("Button",nil,f.currentControls,"UIPanelButtonTemplate")
f.currentControls.modeBtn:SetSize(166,20); f.currentControls.modeBtn:SetPoint("LEFT",0,0)
f.currentControls.modeBtn:SetScript("OnClick",function()
scanCurrentStatus(); A:Refresh()
end)
f.currentControls.modeBtn:SetScript("OnEnter",function(self)
if not (self._nowclPreviousHold and GameTooltip) then return end
GameTooltip:SetOwner(self,"ANCHOR_TOP")
GameTooltip:AddLine("切换为当前状态",1,0.82,0)
GameTooltip:AddLine("当前仍显示上一场冻结的战斗记录；倒计时结束后会自动切换。点击可立即进入当前准备状态。",0.82,0.82,0.85,true)
GameTooltip:Show()
end)
f.currentControls.modeBtn:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
f.currentControls.teamAnnouncementBtn=CreateFrame("Button",nil,f.currentControls,"UIPanelButtonTemplate")
f.currentControls.teamAnnouncementBtn:SetSize(92,20); f.currentControls.teamAnnouncementBtn:SetPoint("RIGHT",0,0)
f.currentControls.teamAnnouncementBtn:SetText("团队通告")
f.currentControls.teamAnnouncementBtn:SetScript("OnClick",function()
if NoWCL.TeamAnnouncementPanel then NoWCL.TeamAnnouncementPanel:Toggle() end
end)
f.currentControls.remindBtn=CreateFrame("Button",nil,f.currentControls,"UIPanelButtonTemplate")
f.currentControls.remindBtn:SetSize(142,20)
f.currentControls.remindBtn:SetPoint("RIGHT",f.currentControls.teamAnnouncementBtn,"LEFT",-6,0)
f.currentControls.remindBtn:SetScript("OnClick",function()
if reminderCooldownRemaining("all") > 0 then return end
StaticPopup_Show("NOWCL_REMIND_ALL_BUFFS")
end)
f.currentControls.selfRemindBtn=CreateFrame("Button",nil,f.currentControls,"UIPanelButtonTemplate")
f.currentControls.selfRemindBtn:SetSize(136,20)
f.currentControls.selfRemindBtn:SetPoint("RIGHT",f.currentControls.remindBtn,"LEFT",-6,0)
f.currentControls.selfRemindBtn:SetScript("OnClick",remindSelfBuffs)
f.currentControls.summary=f.currentControls:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
f.currentControls.summary:SetPoint("LEFT",f.currentControls.modeBtn,"RIGHT",8,0)
f.currentControls.summary:SetPoint("RIGHT",f.currentControls.selfRemindBtn,"LEFT",-8,0)
f.currentControls.summary:SetJustifyH("LEFT")
U.RegisterOpacityChrome(f,f.currentControls.modeBtn,f.currentControls.selfRemindBtn,
f.currentControls.remindBtn,f.currentControls.teamAnnouncementBtn,f.currentControls.summary)
U.RegisterOpacityChromeHover(f,f.currentControls.modeBtn)
U.RegisterOpacityChromeHover(f,f.currentControls.selfRemindBtn)
U.RegisterOpacityChromeHover(f,f.currentControls.remindBtn)
U.RegisterOpacityChromeHover(f,f.currentControls.teamAnnouncementBtn)
f.header=CreateFrame("Frame",nil,f.audit); f.header:SetPoint("TOPLEFT",0,-30); f.header:SetPoint("TOPRIGHT",0,-30); f.header:SetHeight(auditRowHeight())
U.RegisterOpacityChromeHover(f, f.header)
local hbg=f.header:CreateTexture(nil,"ARTWORK"); hbg:SetAllPoints(); hbg:SetColorTexture(0.18,0.18,0.22,1)
U.RegisterOpacityChrome(f, hbg)
f.headerCells={}
for i,col in ipairs(COLS) do
local fs=f.header:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
fs:SetPoint("LEFT",f.header,"LEFT",colX(i),0); fs:SetWidth(col[3]); fs:SetJustifyH(col[4]); fs:SetText(col[2])
if i==COL_LOWQ then
if fs.SetWordWrap then fs:SetWordWrap(false) end
if fs.SetNonSpaceWrap then fs:SetNonSpaceWrap(false) end
if Style and Style.ApplyFont then Style:ApplyFont(fs,-2) end
end
f.headerCells[i]=fs; U.RegisterOpacityChrome(f, fs)
end
f.listScroll=CreateFrame("ScrollFrame","NoWCLAuditListScroll",f.audit,"UIPanelScrollFrameTemplate")
f.listScroll:SetPoint("TOPLEFT",0,-50); f.listScroll:SetPoint("BOTTOMRIGHT",-SCROLLBAR_GUTTER,AUDIT_BOTTOM_PAD)
f.rowAnchor=CreateFrame("Frame",nil,f.listScroll); f.rowAnchor:SetSize(contentWidth,1); f.listScroll:SetScrollChild(f.rowAnchor)
U.RegisterOpacityChromeHover(f, f.rowAnchor)
f.detailScroll=CreateFrame("ScrollFrame","NoWCLAuditDetailScroll",f.audit,"UIPanelScrollFrameTemplate")
f.detailScroll:SetPoint("TOPLEFT",0,-4); f.detailScroll:SetPoint("BOTTOMRIGHT",-SCROLLBAR_GUTTER,AUDIT_BOTTOM_PAD-2); f.detailScroll:Hide()
local dp=CreateFrame("Frame",nil,f.detailScroll); dp:SetSize(contentWidth,300); dp:Hide(); f.detailPane=dp
f.detailScroll:SetScrollChild(dp)
U.RegisterOpacityChromeHover(f, dp)
dp.back=CreateFrame("Button",nil,dp,"UIPanelButtonTemplate"); dp.back:SetSize(80,22); dp.back:SetPoint("TOPLEFT",8,0); dp.back:SetText("← 返回")
dp.back:SetScript("OnClick", function() A.detailPlayer=nil; A.comparePlayer=nil; A:Refresh() end)
dp.header=dp:CreateFontString(nil,"OVERLAY","GameFontNormal"); dp.header:SetPoint("LEFT",dp.back,"RIGHT",12,0)
dp.roleBtn=CreateFrame("Button",nil,dp,"UIPanelButtonTemplate"); dp.roleBtn:SetSize(116,22); dp.roleBtn:SetPoint("TOPRIGHT",-8,0)
dp.roleBtn:SetScript("OnClick", function()
if not A.detailPlayer then return end
local cur = roleOf({ name = A.detailPlayer })
local nxt = (cur=="DAMAGER" and "HEALER") or (cur=="HEALER" and "TANK") or "DAMAGER"
NoWCL.db.settings.roleOverride[A.detailPlayer] = nxt; A:Refresh()
end)
dp.compareBtn=U.MakeDropdown(dp,150); dp.compareBtn:SetPoint("RIGHT",dp.roleBtn,"LEFT",-6,0); dp.compareBtn:SetText("同职业对比")
dp.header:SetPoint("RIGHT",dp.compareBtn,"LEFT",-8,0); dp.header:SetJustifyH("LEFT")
dp.compareBtn.itemsFn=function()
local view=getAuditView(A.sel)
local primary
for _,p in ipairs(view.players or {}) do if p.name==A.detailPlayer then primary=p; break end end
if not primary then return {} end
local candidates={}
for _,p in ipairs(view.players or {}) do
if p.name~=primary.name and p.class==primary.class then candidates[#candidates+1]=p end
end
table.sort(candidates,function(a,b) return tostring(a.name)<tostring(b.name) end)
local items={}
if A.comparePlayer then items[#items+1]={text="退出对比",value="",checked=false} end
for _,p in ipairs(candidates) do
items[#items+1]={text=U.SpecIconTag(p.specId,13)..U.ClassColor(p.name,p.class),value=p.name,checked=A.comparePlayer==p.name}
end
return items
end
dp.compareBtn.onSelect=function(value)
A.comparePlayer=(value and value~="") and value or nil
if frame.detailScroll then frame.detailScroll:SetVerticalScroll(0) end
A:Refresh()
end
U.RegisterOpacityChrome(f, dp.back, dp.header, dp.roleBtn, dp.compareBtn)
U.RegisterOpacityChromeHover(f, dp.back)
U.RegisterOpacityChromeHover(f, dp.roleBtn)
U.RegisterOpacityChromeHover(f, dp.compareBtn)
local gear=CreateFrame("Frame",nil,dp); gear:SetPoint("TOPLEFT",10,-30); gear:SetPoint("TOPRIGHT",-10,-30); gear:SetHeight(28); dp.gear=gear
gear.items={}
for i=1,#EQUIP_SLOTS do
local b=CreateFrame("Button",nil,gear); b:SetSize(26,26); b:SetPoint("LEFT",(i-1)*28,0)
b.border=b:CreateTexture(nil,"BORDER"); b.border:SetAllPoints(); b.border:SetColorTexture(0.22,0.22,0.25,0.8)
b.bg=b:CreateTexture(nil,"BACKGROUND"); b.bg:SetPoint("TOPLEFT",1,-1); b.bg:SetPoint("BOTTOMRIGHT",-1,1); b.bg:SetColorTexture(0.04,0.04,0.05,0.9)
b.icon=b:CreateTexture(nil,"ARTWORK"); b.icon:SetPoint("TOPLEFT",2,-2); b.icon:SetPoint("BOTTOMRIGHT",-2,2); b.icon:SetTexCoord(0.08,0.92,0.08,0.92)
b:SetScript("OnEnter",function(self)
if not (self.itemLink and GameTooltip) then return end
GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
GameTooltip:SetHyperlink(self.itemLink)
GameTooltip:Show()
end)
b:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
gear.items[i]=b
U.RegisterOpacityChromeHover(f,b)
end
gear.missing=gear:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); gear.missing:SetPoint("LEFT",#EQUIP_SLOTS*28+8,0); gear.missing:SetText("装备快照未记录")
U.RegisterOpacityChromeHover(f,gear)
local ac=CreateFrame("Frame",nil,dp); ac:SetPoint("TOPLEFT",10,-64); ac:SetPoint("TOPRIGHT",-10,-64); ac:SetHeight(78); dp.act=ac
U.RegisterOpacityChromeHover(f, ac)
ac.big=ac:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); ac.big:SetPoint("TOPLEFT",2,-2)
ac.eval=ac:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); ac.eval:SetPoint("LEFT",ac.big,"RIGHT",8,-1)
ac.apm=ac:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); ac.apm:SetPoint("TOPRIGHT",-2,-2); ac.apm:SetJustifyH("RIGHT")
ac.split=ac:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); ac.split:SetPoint("TOPLEFT",2,-26)
ac.tl=CreateFrame("Frame",nil,ac); ac.tl:SetPoint("TOPLEFT",2,-44); ac.tl:SetPoint("TOPRIGHT",-2,-44); ac.tl:SetHeight(14)
ac.tlBG=ac.tl:CreateTexture(nil,"BACKGROUND"); ac.tlBG:SetAllPoints(); ac.tlBG:SetColorTexture(0.3,0.3,0.3,0.5)
ac.gaps=ac:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); ac.gaps:SetPoint("TOPLEFT",2,-62)
local chart=CreateFrame("Frame",nil,dp); chart:SetPoint("TOPLEFT",10,-148); chart:SetPoint("TOPRIGHT",-10,-148); chart:SetHeight(90); dp.chart=chart
chart.title=chart:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); chart.title:SetPoint("TOPLEFT",2,-1)
chart.peak=chart:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); chart.peak:SetPoint("TOPRIGHT",-2,-1)
chart.plot=CreateFrame("Frame",nil,chart); chart.plot:SetPoint("TOPLEFT",2,-19); chart.plot:SetPoint("TOPRIGHT",-2,-19); chart.plot:SetHeight(52)
chart.bg=chart.plot:CreateTexture(nil,"BACKGROUND"); chart.bg:SetAllPoints(); chart.bg:SetColorTexture(0.10,0.10,0.12,0.72)
chart.axis=CreateFrame("Frame",nil,chart); chart.axis:SetPoint("TOPLEFT",chart.plot,"BOTTOMLEFT",0,0); chart.axis:SetPoint("TOPRIGHT",chart.plot,"BOTTOMRIGHT",0,0); chart.axis:SetHeight(16)
chart.empty=chart.plot:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); chart.empty:SetPoint("CENTER"); chart.empty:SetWidth(600); chart.empty:SetJustifyH("CENTER")
U.RegisterOpacityChromeHover(f, chart)
local sep=dp:CreateTexture(nil,"ARTWORK"); sep:SetPoint("TOPLEFT",10,-246); sep:SetPoint("TOPRIGHT",-10,-246); sep:SetHeight(1); sep:SetColorTexture(1,1,1,0.12)
U.RegisterOpacityChrome(f, ac.big, ac.eval, ac.apm, ac.split, ac.tlBG, ac.gaps,
chart.title, chart.peak, chart.bg, chart.empty, sep)
dp.list=CreateFrame("Frame",nil,dp); dp.list:SetPoint("TOPLEFT",10,-254); dp.list:SetPoint("BOTTOMRIGHT",-10,4)
U.RegisterOpacityChromeHover(f, dp.list)
dp.spellLbl=dp.list:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
dp.spellHeads={}
for i=1,#SPELL_DETAIL_COLUMNS do
dp.spellHeads[i]=dp.list:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
end
dp.tgtLbl=dp.list:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
dp.buffLbl=dp.list:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
dp.selfBuffCheck=CreateFrame("CheckButton",nil,dp.list,"UICheckButtonTemplate")
dp.selfBuffCheck:SetSize(18,18); dp.selfBuffCheck:SetHitRectInsets(0,-132,0,0)
dp.selfBuffCheck:SetPoint("LEFT",dp.buffLbl,"LEFT",70,0)
dp.selfBuffCheck:SetFrameLevel(dp.list:GetFrameLevel()+5)
dp.selfBuffCheck:SetScript("OnClick",onDetailSelfBuffClick)
dp.selfBuffLabel=dp.list:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
dp.selfBuffLabel:SetPoint("LEFT",dp.selfBuffCheck,"RIGHT",1,0)
dp.selfBuffLabel:SetText("仅显示本人施放的buff")
U.RegisterOpacityChrome(f,dp.selfBuffCheck,dp.selfBuffLabel)
U.RegisterOpacityChromeHover(f,dp.selfBuffCheck)
dp.debuffLbl=dp.list:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
dp.buffHeads={}; dp.debuffHeads={}
for i=1,#AURA_DETAIL_COLUMNS do
dp.buffHeads[i]=dp.list:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
dp.debuffHeads[i]=dp.list:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
end
dp.bossLbl=dp.list:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
local cmp=CreateFrame("Frame",nil,dp); cmp:SetPoint("TOPLEFT",10,-30); cmp:SetPoint("BOTTOMRIGHT",-10,4); cmp:Hide(); dp.compare=cmp
U.RegisterOpacityChromeHover(f,cmp)
cmp.gears={}
local function createCompareGear(index,y)
local gear=CreateFrame("Frame",nil,cmp); gear:SetPoint("TOPLEFT",0,y); gear:SetPoint("TOPRIGHT",0,y); gear:SetHeight(28)
gear.label=gear:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); gear.label:SetPoint("LEFT",2,0); gear.label:SetWidth(104); gear.label:SetJustifyH("LEFT")
gear.items={}
for i=1,#EQUIP_SLOTS do
local b=CreateFrame("Button",nil,gear); b:SetSize(26,26); b:SetPoint("LEFT",108+(i-1)*28,0)
b.border=b:CreateTexture(nil,"BORDER"); b.border:SetAllPoints(); b.border:SetColorTexture(0.22,0.22,0.25,0.8)
b.bg=b:CreateTexture(nil,"BACKGROUND"); b.bg:SetPoint("TOPLEFT",1,-1); b.bg:SetPoint("BOTTOMRIGHT",-1,1); b.bg:SetColorTexture(0.04,0.04,0.05,0.9)
b.icon=b:CreateTexture(nil,"ARTWORK"); b.icon:SetPoint("TOPLEFT",2,-2); b.icon:SetPoint("BOTTOMRIGHT",-2,2); b.icon:SetTexCoord(0.08,0.92,0.08,0.92)
b:SetScript("OnEnter",function(self)
if not (self.itemLink and GameTooltip) then return end
GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetHyperlink(self.itemLink); GameTooltip:Show()
end)
b:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
gear.items[i]=b; U.RegisterOpacityChromeHover(f,b)
end
gear.missing=gear:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); gear.missing:SetPoint("LEFT",108+#EQUIP_SLOTS*28+7,0); gear.missing:SetText("装备快照未记录")
cmp.gears[index]=gear
end
createCompareGear(1,0); createCompareGear(2,-34)
cmp.activities={}
local function createCompareActivity(index,y)
local ac=CreateFrame("Frame",nil,cmp); ac:SetPoint("TOPLEFT",0,y); ac:SetPoint("TOPRIGHT",0,y); ac:SetHeight(78)
ac._timelineInset=110
ac.player=ac:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); ac.player:SetPoint("TOPLEFT",2,-2); ac.player:SetWidth(102); ac.player:SetJustifyH("LEFT")
ac.big=ac:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); ac.big:SetPoint("TOPLEFT",108,-2)
ac.eval=ac:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); ac.eval:SetPoint("LEFT",ac.big,"RIGHT",8,-1)
ac.apm=ac:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); ac.apm:SetPoint("TOPRIGHT",-2,-2); ac.apm:SetJustifyH("RIGHT")
ac.split=ac:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); ac.split:SetPoint("TOPLEFT",108,-26)
ac.tl=CreateFrame("Frame",nil,ac); ac.tl:SetPoint("TOPLEFT",108,-44); ac.tl:SetPoint("TOPRIGHT",-2,-44); ac.tl:SetHeight(14)
ac.tlBG=ac.tl:CreateTexture(nil,"BACKGROUND"); ac.tlBG:SetAllPoints(); ac.tlBG:SetColorTexture(0.3,0.3,0.3,0.5)
ac.gaps=ac:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); ac.gaps:SetPoint("TOPLEFT",108,-62)
U.RegisterOpacityChrome(f,ac.player,ac.big,ac.eval,ac.apm,ac.split,ac.tlBG,ac.gaps)
U.RegisterOpacityChromeHover(f,ac); cmp.activities[index]=ac
end
createCompareActivity(1,-72); createCompareActivity(2,-156)
cmp.charts={}
local function createCompareChart(index,y)
local chart=CreateFrame("Frame",nil,cmp); chart:SetPoint("TOPLEFT",0,y); chart:SetPoint("TOPRIGHT",0,y); chart:SetHeight(90)
chart.title=chart:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); chart.title:SetPoint("TOPLEFT",2,-1)
chart.peak=chart:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); chart.peak:SetPoint("TOPRIGHT",-2,-1)
chart.plot=CreateFrame("Frame",nil,chart); chart.plot:SetPoint("TOPLEFT",2,-19); chart.plot:SetPoint("TOPRIGHT",-2,-19); chart.plot:SetHeight(52)
chart.bg=chart.plot:CreateTexture(nil,"BACKGROUND"); chart.bg:SetAllPoints(); chart.bg:SetColorTexture(0.10,0.10,0.12,0.72)
chart.axis=CreateFrame("Frame",nil,chart); chart.axis:SetPoint("TOPLEFT",chart.plot,"BOTTOMLEFT",0,0); chart.axis:SetPoint("TOPRIGHT",chart.plot,"BOTTOMRIGHT",0,0); chart.axis:SetHeight(16)
chart.empty=chart.plot:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); chart.empty:SetPoint("CENTER"); chart.empty:SetWidth(600); chart.empty:SetJustifyH("CENTER")
U.RegisterOpacityChrome(f,chart.title,chart.peak,chart.bg,chart.empty); U.RegisterOpacityChromeHover(f,chart)
cmp.charts[index]=chart
end
createCompareChart(1,-242); createCompareChart(2,-338)
cmp.list=CreateFrame("Frame",nil,cmp); cmp.list:SetPoint("TOPLEFT",0,-438); cmp.list:SetPoint("BOTTOMRIGHT",0,0)
cmp.divider=cmp.list:CreateTexture(nil,"ARTWORK"); cmp.divider:SetPoint("TOP",0,0); cmp.divider:SetPoint("BOTTOM",0,0); cmp.divider:SetWidth(1); cmp.divider:SetColorTexture(1,1,1,0.18)
cmp.spellLeft=cmp.list:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); cmp.spellLeft:SetWidth((contentWidth-34)/2); cmp.spellLeft:SetJustifyH("LEFT")
cmp.spellRight=cmp.list:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); cmp.spellRight:SetWidth((contentWidth-34)/2); cmp.spellRight:SetJustifyH("LEFT")
cmp.targetLeft=cmp.list:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); cmp.targetLeft:SetWidth((contentWidth-34)/2); cmp.targetLeft:SetJustifyH("LEFT")
cmp.targetRight=cmp.list:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); cmp.targetRight:SetWidth((contentWidth-34)/2); cmp.targetRight:SetJustifyH("LEFT")
cmp.buffLeft=cmp.list:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); cmp.buffLeft:SetWidth((contentWidth-34)/2); cmp.buffLeft:SetJustifyH("LEFT")
cmp.buffRight=cmp.list:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); cmp.buffRight:SetWidth((contentWidth-34)/2); cmp.buffRight:SetJustifyH("LEFT")
cmp.selfBuffCheck=CreateFrame("CheckButton",nil,cmp.list,"UICheckButtonTemplate")
cmp.selfBuffCheck:SetSize(18,18); cmp.selfBuffCheck:SetHitRectInsets(0,-132,0,0)
cmp.selfBuffCheck:SetPoint("LEFT",cmp.buffRight,"LEFT",185,0)
cmp.selfBuffCheck:SetFrameLevel(cmp.list:GetFrameLevel()+5)
cmp.selfBuffCheck:SetScript("OnClick",onDetailSelfBuffClick)
cmp.selfBuffLabel=cmp.list:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
cmp.selfBuffLabel:SetPoint("LEFT",cmp.selfBuffCheck,"RIGHT",1,0)
cmp.selfBuffLabel:SetText("仅显示本人施放的buff")
U.RegisterOpacityChrome(f,cmp.selfBuffCheck,cmp.selfBuffLabel)
U.RegisterOpacityChromeHover(f,cmp.selfBuffCheck)
cmp.debuffLeft=cmp.list:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); cmp.debuffLeft:SetWidth((contentWidth-34)/2); cmp.debuffLeft:SetJustifyH("LEFT")
cmp.debuffRight=cmp.list:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); cmp.debuffRight:SetWidth((contentWidth-34)/2); cmp.debuffRight:SetJustifyH("LEFT")
U.RegisterOpacityChrome(f,cmp.divider,cmp.spellLeft,cmp.spellRight,cmp.targetLeft,cmp.targetRight,
cmp.buffLeft,cmp.buffRight,cmp.debuffLeft,cmp.debuffRight)
local settingsViewport=CreateFrame("Frame",nil,f)
settingsViewport:SetPoint("TOPLEFT",0,-70)
settingsViewport:SetPoint("BOTTOMRIGHT",0,0)
settingsViewport:Hide()
local settingsScroll=CreateFrame("ScrollFrame","NoWCLAuditSettingsScroll",settingsViewport,"UIPanelScrollFrameTemplate")
settingsScroll:SetPoint("TOPLEFT",0,0)
settingsScroll:SetPoint("BOTTOMRIGHT",-SCROLLBAR_GUTTER,AUDIT_BOTTOM_PAD)
local s=CreateFrame("Frame",nil,settingsScroll)
s:SetSize(contentWidth,892)
settingsScroll:SetScrollChild(s)
f.settingsViewport=settingsViewport
f.settingsScroll=settingsScroll
f.settings=s
U.RegisterOpacityChrome(f, settingsViewport)
U.RegisterOpacityChromeHover(f, settingsViewport)
s.hint=s:CreateFontString(nil,"OVERLAY","GameFontHighlight"); s.hint:SetPoint("TOPLEFT",16,-12); s.hint:SetWidth(width-440); s.hint:SetJustifyH("LEFT")
s.ver=s:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); s.ver:SetPoint("TOPRIGHT",-16,-12); s.ver:SetText("NoWCL v"..(NoWCL.version or "?"))
s.credits=s:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); s.credits:SetPoint("TOPRIGHT",-16,-30); s.credits:SetWidth(420); s.credits:SetJustifyH("RIGHT"); s.credits:SetText(SETTINGS_QQ)
s.authorUnlock=CreateFrame("Button",nil,s); s.authorUnlock:SetSize(150,18); s.authorUnlock:SetPoint("TOPRIGHT",-16,-46)
s.authorUnlock.text=s.authorUnlock:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); s.authorUnlock.text:SetAllPoints(); s.authorUnlock.text:SetJustifyH("RIGHT"); s.authorUnlock.text:SetText(SETTINGS_AUTHOR)
s.authorUnlock:SetScript("OnClick",function(self)
self.clicks=(self.clicks or 0)+1
if self.clicks>=5 then
self.clicks=0
local api=NoWCL.ExtensionAPI
if api and api.UnlockSessionFeature then api:UnlockSessionFeature("author_credit") end
end
end)
s.baseLabel=s:CreateFontString(nil,"OVERLAY","GameFontNormal"); s.baseLabel:SetPoint("TOPLEFT",16,-72); s.baseLabel:SetText("DPS 基准:")
s.ratioLabel=s:CreateFontString(nil,"OVERLAY","GameFontNormal"); s.ratioLabel:SetPoint("TOPLEFT",16,-108); s.ratioLabel:SetText("及格线:")
s.baseDD = U.MakeDropdown(s, 90); s.baseDD:SetPoint("TOPLEFT",78,-70)
s.baseDD.itemsFn = function()
local t={} for _,o in ipairs(BASE_OPTS) do t[#t+1]={text=o.text,value=o.value,checked=(NoWCL.db.settings.dpsBaseline==o.value)} end return t
end
s.baseDD.onSelect = function(value)
local previousRatio=NoWCL.db.settings.dpsRatio or 0.6
NoWCL.db.settings.dpsBaseline=value
if value=="tank" then NoWCL.db.settings.dpsRatio=1.0
elseif (NoWCL.db.settings.dpsRatio or 0)>1 then NoWCL.db.settings.dpsRatio=0.6 end
NoWCL.Sync:BroadcastConfig()
if NoWCL.Toast and NoWCL.Toast.BroadcastLeaderSetting then
local text="DPS基准改为「"..(BASE_NAMES[value] or value).."」"
if previousRatio~=NoWCL.db.settings.dpsRatio then
text=text.."，及格线自动调整为"..math.floor(NoWCL.db.settings.dpsRatio*100).."%"
end
NoWCL.Toast:BroadcastLeaderSetting(text)
end
A:Refresh()
end
s.ratioDD = U.MakeDropdown(s, 90); s.ratioDD:SetPoint("TOPLEFT",78,-106)
s.ratioDD.itemsFn = function()
local t={} for _,o in ipairs(ratioOpts()) do t[#t+1]={text=o.text,value=o.value,checked=(NoWCL.db.settings.dpsRatio==o.value)} end return t
end
s.ratioDD.onSelect = function(value)
NoWCL.db.settings.dpsRatio=value; NoWCL.Sync:BroadcastConfig()
if NoWCL.Toast and NoWCL.Toast.BroadcastLeaderSetting then
NoWCL.Toast:BroadcastLeaderSetting("DPS及格线改为"..math.floor(value*100).."%")
end
A:Refresh()
end
local function setMode(value)
NoWCL.db.settings.dpsMode=value; NoWCL.Sync:BroadcastConfig()
if NoWCL.Toast and NoWCL.Toast.BroadcastLeaderSetting then
NoWCL.Toast:BroadcastLeaderSetting("统计口径改为「"..(value=="all" and "Boss战全目标" or "官方Boss目标口径/自定义").."」")
end
A:Refresh()
end
s.modeLabel=s:CreateFontString(nil,"OVERLAY","GameFontNormal"); s.modeLabel:SetPoint("TOPLEFT",250,-72); s.modeLabel:SetText("统计口径:")
s.modeAll = makeCheck(s, 330, -70, "Boss战全目标", function() setMode("all") end)
s.modeAll.label:SetWidth(102)
s.modeAll:SetHitRectInsets(0, -104, 0, 0)
s.modeAll:SetScript("OnEnter", function(self)
if not GameTooltip then return end
GameTooltip:SetOwner(self, "ANCHOR_TOP")
GameTooltip:AddLine("Boss战全目标")
GameTooltip:AddLine("在已记录的 Boss 战内，Boss 本体、随从以及 WCL 口径原本排除的目标伤害都会计入总量。", 0.8, 0.8, 0.8, true)
GameTooltip:AddLine("路上小怪仅在“当前”中实时显示；战斗结束后不会生成 Tab，也不会进入“所有战斗汇总”。", 0.55, 0.75, 1.0, true)
GameTooltip:Show()
end)
s.modeAll:SetScript("OnLeave", function()
if GameTooltip then GameTooltip:Hide() end
end)
s.modeBoss = makeCheck(s, 460, -70, "", function() setMode("boss") end)
s.modeBoss.label:SetWidth(1)
s.bossBtn=CreateFrame("Button",nil,s,"UIPanelButtonTemplate"); s.bossBtn:SetSize(150,22); s.bossBtn:SetPoint("LEFT",s.modeBoss,"RIGHT",1,0); s.bossBtn:SetText("WCL口径/自定义")
s.bossBtn:SetScript("OnClick", function()
if NoWCL.StatsConfig then NoWCL.StatsConfig:Toggle() end
end)
s.ckHead=s:CreateFontString(nil,"OVERLAY","GameFontNormal"); s.ckHead:SetPoint("TOPLEFT",16,-138); s.ckHead:SetText("|cffffd100活跃度考核|r(勾选启用,挂机检测;DPS 及格由上方 基准/及格线 决定)")
local function setCk(key, field, val)
local c=NoWCL.db.settings.checks;c[key]=c[key] or {};c[key][field]=val
NoWCL.Sync:BroadcastConfig()
if key=="active" and NoWCL.Toast and NoWCL.Toast.BroadcastLeaderSetting then
NoWCL.Toast:BroadcastLeaderSetting(field=="on"
and ("活跃度考核已"..(val and "启用" or "关闭"))
or ("活跃度及格线改为"..math.floor((tonumber(val) or 0)*100).."%"))
end
A:Refresh()
end
s.ckActive = makeCheck(s, 16, -162, "活跃度 ≥", function(v) setCk("active","on",v) end)
s.activeDD = U.MakeDropdown(s, 60); s.activeDD:SetPoint("TOPLEFT",108,-160)
s.activeDD.itemsFn = function()
local cv=NoWCL.db.settings.checks.active and NoWCL.db.settings.checks.active.v; local t={}
for _,v in ipairs({0.3,0.4,0.5,0.6}) do t[#t+1]={text=math.floor(v*100).."%",value=v,checked=(cv==v)} end return t
end
s.activeDD.onSelect = function(value) setCk("active","v",value) end
s.checkBoxes = { s.ckActive }
s.taskHead=s:CreateFontString(nil,"OVERLAY","GameFontNormal"); s.taskHead:SetPoint("TOPLEFT",16,-198); s.taskHead:SetText("|cffffd100额外任务贡献换算|r")
s.taskBtn=CreateFrame("Button",nil,s,"UIPanelButtonTemplate"); s.taskBtn:SetSize(180,24); s.taskBtn:SetPoint("TOPLEFT",16,-220); s.taskBtn:SetText("额外任务贡献换算")
s.taskBtn:SetScript("OnClick", function() if NoWCL.TaskConfig then NoWCL.TaskConfig:Toggle() end end)
s.taskSummary=s:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); s.taskSummary:SetPoint("TOPLEFT",16,-248); s.taskSummary:SetWidth(360); s.taskSummary:SetJustifyH("LEFT")
s.teamBuffHead=s:CreateFontString(nil,"OVERLAY","GameFontNormal"); s.teamBuffHead:SetPoint("TOPLEFT",410,-198); s.teamBuffHead:SetText("|cffffd100团队Buff监控|r")
s.teamBuffBtn=CreateFrame("Button",nil,s,"UIPanelButtonTemplate"); s.teamBuffBtn:SetSize(180,24); s.teamBuffBtn:SetPoint("TOPLEFT",410,-220); s.teamBuffBtn:SetText("团队Buff监控设置")
s.teamBuffBtn:SetScript("OnClick", function() if NoWCL.TeamBuffConfig then NoWCL.TeamBuffConfig:Toggle() end end)
s.autoSelfBuffCheck=CreateFrame("CheckButton",nil,s,"UICheckButtonTemplate")
s.autoSelfBuffCheck:SetSize(22,22); s.autoSelfBuffCheck:SetPoint("LEFT",s.teamBuffBtn,"RIGHT",8,0)
s.autoSelfBuffCheck:SetScript("OnClick",function(self)
setAutoReminderEnabled(self:GetChecked() and true or false)
end)
s.autoSelfBuffPrefix=s:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
s.autoSelfBuffPrefix:SetPoint("LEFT",s.autoSelfBuffCheck,"RIGHT",1,0); s.autoSelfBuffPrefix:SetText("自动每")
s.autoSelfBuffMinutes=CreateFrame("EditBox",nil,s,"InputBoxTemplate")
s.autoSelfBuffMinutes:SetSize(30,20); s.autoSelfBuffMinutes:SetPoint("LEFT",s.autoSelfBuffPrefix,"RIGHT",5,0)
s.autoSelfBuffMinutes:SetAutoFocus(false); s.autoSelfBuffMinutes:SetNumeric(true); s.autoSelfBuffMinutes:SetMaxLetters(2)
s.autoSelfBuffMinutes:SetJustifyH("CENTER")
s.autoSelfBuffMinutes:SetScript("OnEnterPressed",function(self) self:ClearFocus() end)
s.autoSelfBuffMinutes:SetScript("OnEditFocusLost",commitAutoReminderMinutes)
s.autoSelfBuffMinutes:SetScript("OnEscapePressed",function(self)
self:ClearFocus()
local settings=NoWCL.db and NoWCL.db.settings
self:SetText(clampAutoReminderMinutes(settings and settings.autoSelfBuffReminderMinutes))
end)
s.autoSelfBuffSuffix=s:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
s.autoSelfBuffSuffix:SetPoint("LEFT",s.autoSelfBuffMinutes,"RIGHT",5,0); s.autoSelfBuffSuffix:SetText("分钟密语要自身Buff")
s.teamBuffSummary=s:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); s.teamBuffSummary:SetPoint("TOPLEFT",410,-248); s.teamBuffSummary:SetWidth(width-426); s.teamBuffSummary:SetJustifyH("LEFT")
s.appearanceHead=s:CreateFontString(nil,"OVERLAY","GameFontNormal"); s.appearanceHead:SetPoint("TOPLEFT",16,-266); s.appearanceHead:SetText("|cffffd100界面外观|r |cff888888(仅本机)|r")
s.appearanceBtn=CreateFrame("Button",nil,s,"UIPanelButtonTemplate"); s.appearanceBtn:SetSize(180,24); s.appearanceBtn:SetPoint("TOPLEFT",16,-288); s.appearanceBtn:SetText("界面外观设置")
s.appearanceBtn:SetScript("OnClick", function() if NoWCL.AppearanceConfig then NoWCL.AppearanceConfig:Toggle() end end)
s.appearanceSummary=s:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); s.appearanceSummary:SetPoint("LEFT",s.appearanceBtn,"RIGHT",10,0); s.appearanceSummary:SetWidth(width-230); s.appearanceSummary:SetJustifyH("LEFT")
s.unitLabel=s:CreateFontString(nil,"OVERLAY","GameFontNormal"); s.unitLabel:SetPoint("TOPLEFT",340,-266); s.unitLabel:SetText("伤害单位:")
s.unitCN=makeCheck(s,420,-264,"万，千",function() if U.SetNumberUnits then U.SetNumberUnits("cn") end end)
s.unitCN.label:SetWidth(58)
s.unitMK=makeCheck(s,500,-264,"M，K",function() if U.SetNumberUnits then U.SetNumberUnits("mk") end end)
s.unitMK.label:SetWidth(58)
s.layerLabel=s:CreateFontString(nil,"OVERLAY","GameFontNormal"); s.layerLabel:SetPoint("TOPLEFT",600,-266); s.layerLabel:SetText("面板层级:")
s.layerDD=U.MakeDropdown(s,130); s.layerDD:SetPoint("TOPLEFT",670,-264)
s.layerDD.itemsFn=function()
local current=U.PanelLayerMode and U.PanelLayerMode() or "system"
return {
{ text="系统窗口优先", value="system", checked=current=="system" },
{ text="插件高层", value="high", checked=current=="high" },
{ text="最高层", value="top", checked=current=="top" },
}
end
s.layerDD.onSelect=function(value)
if U.SetPanelLayerMode then U.SetPanelLayerMode(value) end
A:Refresh()
end
local function showLayerTip(owner)
if not GameTooltip then return end
GameTooltip:SetOwner(owner,"ANCHOR_TOP")
GameTooltip:AddLine("主面板层级")
GameTooltip:AddLine("系统窗口优先：背包等暴雪窗口显示在 NoWCL 上方。",0.8,0.8,0.8,true)
GameTooltip:AddLine("插件高层：提高到常见插件界面之上。",0.8,0.8,0.8,true)
GameTooltip:AddLine("最高层：用于被 WeakAuras 遮挡时，可能覆盖背包等系统窗口。",1,0.82,0,true)
GameTooltip:Show()
end
s.layerDD:SetScript("OnEnter",showLayerTip)
s.layerDD:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
s.gearHoverLabel=s:CreateFontString(nil,"OVERLAY","GameFontNormal")
s.gearHoverLabel:SetPoint("TOPLEFT",16,-320);s.gearHoverLabel:SetText("角色装备查看:")
s.gearHoverDD=U.MakeDropdown(s,140);s.gearHoverDD:SetPoint("TOPLEFT",112,-318)
s.gearHoverDD.itemsFn=function()
local current=NoWCL.GearInspectPanel and NoWCL.GearInspectPanel.GetHoverMode
and NoWCL.GearInspectPanel:GetHoverMode("gear") or "disabled"
return {
{text="鼠标移动",value="hover",checked=current=="hover"},
{text="按住 Ctrl",value="ctrl",checked=current=="ctrl"},
{text="按住 Alt",value="alt",checked=current=="alt"},
{text="禁止",value="disabled",checked=current=="disabled"},
}
end
s.gearHoverDD.onSelect=function(value)
if NoWCL.GearInspectPanel and NoWCL.GearInspectPanel.SetHoverMode then
NoWCL.GearInspectPanel:SetHoverMode("gear",value)
end
A:Refresh()
end
s.damageHoverLabel=s:CreateFontString(nil,"OVERLAY","GameFontNormal")
s.damageHoverLabel:SetPoint("TOPLEFT",280,-320);s.damageHoverLabel:SetText("技能伤害查看:")
s.damageHoverDD=U.MakeDropdown(s,140);s.damageHoverDD:SetPoint("TOPLEFT",386,-318)
s.damageHoverDD.itemsFn=function()
local current=NoWCL.GearInspectPanel and NoWCL.GearInspectPanel.GetHoverMode
and NoWCL.GearInspectPanel:GetHoverMode("damage") or "disabled"
return {
{text="鼠标移动",value="hover",checked=current=="hover"},
{text="按住 Ctrl",value="ctrl",checked=current=="ctrl"},
{text="按住 Alt",value="alt",checked=current=="alt"},
{text="禁止",value="disabled",checked=current=="disabled"},
}
end
s.damageHoverDD.onSelect=function(value)
if NoWCL.GearInspectPanel and NoWCL.GearInspectPanel.SetHoverMode then
NoWCL.GearInspectPanel:SetHoverMode("damage",value)
end
A:Refresh()
end
s.storageHead=s:CreateFontString(nil,"OVERLAY","GameFontNormal"); s.storageHead:SetPoint("TOPLEFT",16,-352); s.storageHead:SetText("|cffffd100战斗记录容量|r |cff888888(仅本机)|r")
s.storageCheck=makeCheck(s,16,-376,"自动淘汰旧战斗（保留最近30场，推荐）",function(enabled)
if enabled then
local count = NoWCL.Sync and NoWCL.Sync.GetAllTabs and #NoWCL.Sync:GetAllTabs()
or (NoWCL.Sync and NoWCL.Sync.GetTabs and #NoWCL.Sync:GetTabs() or 0)
if count > 30 then
NoWCL.db.settings.autoPrune30 = false
s.storageCheck:SetChecked(false)
StaticPopup_Show("NOWCL_PRUNE_TO_30", count - 30)
return
end
NoWCL.db.settings.autoPrune30 = true
else
NoWCL.db.settings.autoPrune30 = false
if NoWCL.Print then NoWCL:Print("已关闭30场自动淘汰；系统保底最多保留99场战斗。") end
end
A:Refresh()
end)
s.storageCheck.label:SetWidth(330); s.storageCheck:SetHitRectInsets(0,-332,0,0)
s.storageState=s:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); s.storageState:SetPoint("TOPLEFT",40,-402); s.storageState:SetWidth(350); s.storageState:SetJustifyH("LEFT")
s.autoClearRaidCheck=makeCheck(s,410,-376,"进入新团本CD时自动清空过去战斗记录",function(enabled)
if NoWCL.RaidAutoClear and NoWCL.RaidAutoClear.SetEnabled then
NoWCL.RaidAutoClear:SetEnabled(enabled)
else
NoWCL.db.settings.autoClearNewRaidCD = enabled and true or false
end
A:Refresh()
end)
s.autoClearRaidCheck.label:SetWidth(310); s.autoClearRaidCheck:SetHitRectInsets(0,-312,0,0)
s.autoClearRaidState=s:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); s.autoClearRaidState:SetPoint("TOPLEFT",434,-402); s.autoClearRaidState:SetWidth(width-450); s.autoClearRaidState:SetJustifyH("LEFT")
s.deathAnnounceHead=s:CreateFontString(nil,"OVERLAY","GameFontNormal"); s.deathAnnounceHead:SetPoint("TOPLEFT",16,-436); s.deathAnnounceHead:SetText("|cffffd100自动通报|r")
s.announcementInfo=CreateFrame("Button",nil,s)
s.announcementInfo:SetSize(18,18); s.announcementInfo:SetPoint("LEFT",s.deathAnnounceHead,"RIGHT",4,0)
s.announcementInfo.text=s.announcementInfo:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
s.announcementInfo.text:SetAllPoints(); s.announcementInfo.text:SetText("|cff66ccff i |r")
s.announcementInfo:SetScript("OnEnter",function(self)
if not GameTooltip then return end
GameTooltip:SetOwner(self,"ANCHOR_TOP")
GameTooltip:AddLine("自动通报")
GameTooltip:AddLine("密语装备提示只显示在本机，不会回复对方或发送到频道。",0.8,0.8,0.8,true)
GameTooltip:AddLine("有团长权威端时，所有安装客户端跟随团长设置并由团长负责通报。",0.8,0.8,0.8,true)
GameTooltip:AddLine("没有权威端时，每项通报会在启用该项的在线客户端中独立选出一个负责人；负责人掉线后会自动接替。",0.55,0.78,1,true)
GameTooltip:Show()
end)
s.announcementInfo:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
s.whisperGearCheck=makeCheck(s,16,-458,"收到玩家密语时在本机显示装等和蓝绿装",function(enabled)
NoWCL.db.settings.whisperGearPrompt=enabled and true or false
A:Refresh()
end)
s.whisperGearCheck.label:SetWidth(380); s.whisperGearCheck:SetHitRectInsets(0,-382,0,0)
s.rulesAnnounceCheck=makeCheck(s,16,-486,"进团通报 NCL 考核规则",function(enabled)
if NoWCL.TeamAnnouncements and NoWCL.TeamAnnouncements.SetEnabled then
NoWCL.TeamAnnouncements:SetEnabled("rules",enabled)
end
A:Refresh()
end)
s.rulesAnnounceCheck.label:SetWidth(330);s.rulesAnnounceCheck:SetHitRectInsets(0,-332,0,0)
s.rulesAnnounceState=s:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
s.rulesAnnounceState:SetPoint("TOPLEFT",40,-510);s.rulesAnnounceState:SetWidth(width-56);s.rulesAnnounceState:SetJustifyH("LEFT")
s.rulesTextLabel=s:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
s.rulesTextLabel:SetPoint("TOPLEFT",40,-540);s.rulesTextLabel:SetWidth(220);s.rulesTextLabel:SetJustifyH("LEFT")
s.rulesTextLabel:SetText("规则统一通报后的自定义文字：")
s.rulesTextEdit=CreateFrame("EditBox",nil,s,"InputBoxTemplate")
s.rulesTextEdit:SetPoint("TOPLEFT",270,-533);s.rulesTextEdit:SetSize(math.min(440,math.max(160,width-320)),22)
s.rulesTextEdit:SetAutoFocus(false);s.rulesTextEdit:SetMaxLetters(60)
s.rulesTextEdit:SetScript("OnEnterPressed",function(self) self:ClearFocus() end)
s.rulesTextEdit:SetScript("OnEditFocusLost",commitRulesAnnouncementText)
s.rulesTextEdit:SetScript("OnEscapePressed",function(self)
self._skipCommit=true;self:ClearFocus();self._skipCommit=nil
local cfg=hasLeaderAuthority() and NoWCL.Sync and NoWCL.Sync.cfg or NoWCL.db.settings
self:SetText(normalizeRulesAnnouncementText(cfg and cfg.rulesAnnouncementText))
end)
s.rulesTextHelp=s:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
s.rulesTextHelp:SetPoint("TOPLEFT",40,-564);s.rulesTextHelp:SetText("团长可填写；该文字会在统一考核规则之后单独通报。")
s.deathAnnounceCheck=makeCheck(s,16,-586,"自动通告角色死亡与最后一击",function(enabled)
if NoWCL.TeamAnnouncements and NoWCL.TeamAnnouncements.SetEnabled then
NoWCL.TeamAnnouncements:SetEnabled("death",enabled)
end
A:Refresh()
end)
s.deathAnnounceCheck.label:SetWidth(330); s.deathAnnounceCheck:SetHitRectInsets(0,-332,0,0)
s.deathAnnounceState=s:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); s.deathAnnounceState:SetPoint("TOPLEFT",40,-610); s.deathAnnounceState:SetWidth(width-56); s.deathAnnounceState:SetJustifyH("LEFT")
s.performanceAnnounceCheck=makeCheck(s,16,-636,"DPS排名通告",function(enabled)
if NoWCL.TeamAnnouncements and NoWCL.TeamAnnouncements.SetEnabled then
NoWCL.TeamAnnouncements:SetEnabled("performance",enabled)
end
A:Refresh()
end)
s.performanceAnnounceCheck.label:SetWidth(330); s.performanceAnnounceCheck:SetHitRectInsets(0,-332,0,0)
local function setAnnouncementOption(key,value)
NoWCL.db.settings[key]=value
if NoWCL.Sync and NoWCL.Sync.BroadcastConfig then NoWCL.Sync:BroadcastConfig() end
A:Refresh()
end
local function makeAnnouncementOption(x,y,text,textWidth,onToggle)
local control=makeCheck(s,x,y,text,onToggle)
control:SetSize(18,18)
control.label:ClearAllPoints();control.label:SetPoint("LEFT",control,"RIGHT",-1,0)
control.label:SetWidth(textWidth)
control:SetHitRectInsets(0,-math.max(0,textWidth-2),0,0)
return control
end
s.performanceModeLabel=s:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
s.performanceModeLabel:SetPoint("TOPLEFT",40,-664);s.performanceModeLabel:SetText("排名：")
s.performanceModeAll=makeAnnouncementOption(86,-656,"全部DPS",72,function()
setAnnouncementOption("performanceRankingMode","all")
end)
s.performanceModeSplit=makeAnnouncementOption(174,-656,"近战 + 远程",104,function()
setAnnouncementOption("performanceRankingMode","split")
end)
s.performanceTopCountPrefix=s:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
s.performanceTopCountPrefix:SetPoint("TOPLEFT",298,-664);s.performanceTopCountPrefix:SetText("前")
s.performanceTopCount=CreateFrame("EditBox",nil,s,"InputBoxTemplate")
s.performanceTopCount:SetSize(28,20);s.performanceTopCount:SetPoint("TOPLEFT",318,-657)
s.performanceTopCount:SetAutoFocus(false);s.performanceTopCount:SetNumeric(true);s.performanceTopCount:SetMaxLetters(1)
s.performanceTopCount:SetJustifyH("CENTER")
local function commitPerformanceTopCount(self)
if self._skipCommit or hasLeaderAuthority() then return end
local count=clampPerformanceTopCount(self:GetText())
self:SetText(count)
setAnnouncementOption("performanceTopCount",count)
end
s.performanceTopCount:SetScript("OnEnterPressed",function(self) self:ClearFocus() end)
s.performanceTopCount:SetScript("OnEditFocusLost",commitPerformanceTopCount)
s.performanceTopCount:SetScript("OnEscapePressed",function(self)
self._skipCommit=true;self:ClearFocus();self._skipCommit=nil
local cfg=hasLeaderAuthority() and NoWCL.Sync and NoWCL.Sync.cfg or NoWCL.db.settings
self:SetText(clampPerformanceTopCount(cfg and cfg.performanceTopCount))
end)
s.performanceTopCountSuffix=s:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
s.performanceTopCountSuffix:SetPoint("LEFT",s.performanceTopCount,"RIGHT",4,0);s.performanceTopCountSuffix:SetText("名")
s.performanceScopeLabel=s:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
s.performanceScopeLabel:SetPoint("TOPLEFT",40,-688);s.performanceScopeLabel:SetText("范围：")
s.performanceScopeFight=makeAnnouncementOption(86,-680,"本场Boss战",94,function()
setAnnouncementOption("performanceScope","fight")
end)
s.performanceScopeSummary=makeAnnouncementOption(206,-680,"所有战斗统计",112,function()
setAnnouncementOption("performanceScope","summary")
end)
s.performanceAnnounceState=s:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); s.performanceAnnounceState:SetPoint("TOPLEFT",40,-708); s.performanceAnnounceState:SetWidth(width-56); s.performanceAnnounceState:SetJustifyH("LEFT")
s.failureAnnounceCheck=makeCheck(s,16,-734,"不及格通告",function(enabled)
if NoWCL.TeamAnnouncements and NoWCL.TeamAnnouncements.SetEnabled then
NoWCL.TeamAnnouncements:SetEnabled("failures",enabled)
end
A:Refresh()
end)
s.failureAnnounceCheck.label:SetWidth(330); s.failureAnnounceCheck:SetHitRectInsets(0,-332,0,0)
s.failureTypeLabel=s:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
s.failureTypeLabel:SetPoint("TOPLEFT",40,-762);s.failureTypeLabel:SetText("项目：")
s.failureDps=makeAnnouncementOption(86,-754,"DPS不及格",94,function(enabled)
setAnnouncementOption("failureDps",enabled)
end)
s.failureActivity=makeAnnouncementOption(206,-754,"活跃度不及格",112,function(enabled)
setAnnouncementOption("failureActivity",enabled)
end)
s.failureScopeLabel=s:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
s.failureScopeLabel:SetPoint("TOPLEFT",40,-786);s.failureScopeLabel:SetText("范围：")
s.failureScopeFight=makeAnnouncementOption(86,-778,"本场Boss战",94,function()
setAnnouncementOption("failureScope","fight")
end)
s.failureScopeSummary=makeAnnouncementOption(206,-778,"所有战斗统计",112,function()
setAnnouncementOption("failureScope","summary")
end)
s.failureAnnounceState=s:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); s.failureAnnounceState:SetPoint("TOPLEFT",40,-806); s.failureAnnounceState:SetWidth(width-56); s.failureAnnounceState:SetJustifyH("LEFT")
s.pullStartAnnounceCheck=makeCheck(s,16,-834,"开怪通告",function(enabled)
if NoWCL.TeamAnnouncements and NoWCL.TeamAnnouncements.SetEnabled then
NoWCL.TeamAnnouncements:SetEnabled("pull",enabled)
end
A:Refresh()
end)
s.pullStartAnnounceCheck.label:SetWidth(330); s.pullStartAnnounceCheck:SetHitRectInsets(0,-332,0,0)
s.pullStartAnnounceState=s:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
s.pullStartAnnounceState:SetPoint("TOPLEFT",40,-858); s.pullStartAnnounceState:SetWidth(width-56); s.pullStartAnnounceState:SetJustifyH("LEFT")
if NoWCL.AzerothUI and NoWCL.AzerothUI.CreatePanel then f.azeroth=NoWCL.AzerothUI:CreatePanel(f) end
f.resizeGrip=CreateFrame("Button",nil,f)
f.resizeGrip:SetSize(18,18); f.resizeGrip:SetPoint("BOTTOMLEFT",1,1)
f.resizeGrip:EnableMouse(true); f.resizeGrip.bars={}
for i=1,5 do
local bar=f.resizeGrip:CreateTexture(nil,"OVERLAY")
bar:SetColorTexture(0.75,0.75,0.80,0.55)
bar:SetSize((6-i)*3,2); bar:SetPoint("BOTTOMLEFT",2,1+(i-1)*3)
f.resizeGrip.bars[i]=bar
U.RegisterOpacityChrome(f,bar)
end
U.RegisterOpacityChrome(f,f.resizeGrip)
U.RegisterOpacityChromeHover(f,f.resizeGrip)
f.resizeGrip:SetScript("OnMouseDown",function(self,button)
if button~="LeftButton" then return end
local scale=UIParent:GetEffectiveScale() or 1
local x,y=GetCursorPosition(); x,y=x/scale,y/scale
self._resizing=true; self._startX=x; self._startY=y
self._startW=f:GetWidth(); self._startH=f:GetHeight()
self._right=f:GetRight(); self._top=f:GetTop(); self._layoutTick=0
local db=auditWindowState(); if db then db.manualSize=true end
end)
f.resizeGrip:SetScript("OnMouseUp",function(self)
if not self._resizing then return end
self._resizing=nil
local db=auditWindowState()
if db then db.width=f:GetWidth(); db.height=f:GetHeight(); db.manualSize=true end
applyAuditColumnLayout(); A:Refresh()
end)
f.resizeGrip:SetScript("OnUpdate",function(self,elapsed)
if not self._resizing then return end
self._layoutTick=(self._layoutTick or 0)+elapsed
if self._layoutTick<0.05 then return end
self._layoutTick=0
local scale=UIParent:GetEffectiveScale() or 1
local x,y=GetCursorPosition(); x,y=x/scale,y/scale
local newW=clampAuditWidth((self._startW or width)-(x-(self._startX or x)))
local newH=clampAuditHeight((self._startH or 600)-(y-(self._startY or y)))
f:SetSize(newW,newH)
if self._right and self._top then
f:ClearAllPoints(); f:SetPoint("TOPRIGHT",UIParent,"BOTTOMLEFT",self._right,self._top)
end
local db=auditWindowState()
if db then db.width=newW; db.height=newH; db.manualSize=true end
applyAuditColumnLayout()
end)
f:SetScript("OnHide",function(self)
if self.resizeGrip then self.resizeGrip._resizing=nil end
end)
f.tab="audit"; f:Hide()
if Style and Style.RegisterRoot then Style:RegisterRoot(f) end
frame=f
if NoWCL.PrimaryPages and NoWCL.PrimaryPages.AttachHost then
f._primaryHostCallback=function(action, descriptor)
if action=="added" then
attachExtensionPage(f, descriptor)
elseif action=="removed" and extensionPages[descriptor.id] then
extensionPages[descriptor.id].panel:Hide()
extensionPages[descriptor.id].button:Hide()
extensionPages[descriptor.id]=nil
if f.tab==descriptor.id then showTab("audit") end
end
end
NoWCL.PrimaryPages:AttachHost(f._primaryHostCallback)
end
applyAuditColumnLayout()
f:_nowclPanelLayerChanged()
applyOpacityTo(f)
return f
end
function A:ShowFull(sel, detailPlayer)
if not frame then frame=Create() end
if sel then A.sel = sel end
if detailPlayer~=A.detailPlayer then A.comparePlayer=nil end
A.detailPlayer = detailPlayer
frame:Show()
applyOpacityTo(frame)
showTab("audit")
end
function A:OpenDetail(playerName, sel)
self:ShowFull(sel or A.sel or "all", playerName)
end
function A:OpenAzeroth()
if not frame then frame=Create() end
frame:Show(); applyOpacityTo(frame); showTab("azeroth")
end
function A:OpenPrimaryPage(id)
if not (NoWCL.PrimaryPages and NoWCL.PrimaryPages:Get(id)) then return false end
if not frame then frame=Create() end
frame:Show(); applyOpacityTo(frame); showTab(id)
return true
end
function A:Hide()
if frame then frame:Hide() end
end
function A:IsShown()
return frame and frame:IsShown()
end
function A:Toggle()
if not frame then frame=Create() end
if frame:IsShown() then frame:Hide() else frame:Show(); applyOpacityTo(frame); showTab(frame.tab or "audit") end
end
