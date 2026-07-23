local addonName, NoWCL = ...
local M = {}
NoWCL.MiniUI = M
local U = NoWCL.Util
local Style = NoWCL.UIStyle
local D = NoWCL.DetailStats
local frame, rows = nil, {}
local TITLE_LOGO = "Interface\\AddOns\\" .. addonName .. "\\Media\\logo.tga"
local detailRows = {}
local showMiniDetailTooltip
local DEFAULT_ROWH = 22
local DEFAULT_W, MIN_W, MAX_W = 270, 190, 520
local LIST_TOP, MINI_BOTTOM_PAD, MIN_VISIBLE_ROWS = 96, 24, 5
local DEFAULT_H, MAX_H = 430, 760
local DETAIL_TOP, DEFAULT_DETAIL_ROWH = 164, 18
local DETAIL_VALUE_W, DETAIL_VALUE_RIGHT = 74, 8
local LIST_CONTENT_X, LIST_RIGHT_PAD = 22, 4
local LIST_RANK_GAP = 3
local WHEEL_STEP = 3
local MINI_TIMELINE_COLUMNS = 120
local MINI_READINESS_SCAN_SECONDS = 3
local PREVIOUS_FIGHT_HOLD_SECONDS = 60
local function miniRowHeight()
return (Style and Style.MiniRowHeight and Style:MiniRowHeight()) or DEFAULT_ROWH
end
local function miniDetailRowHeight()
return (Style and Style.MiniDetailRowHeight and Style:MiniDetailRowHeight()) or DEFAULT_DETAIL_ROWH
end
local function miniFillHeight()
return (Style and Style.MiniFillHeight and Style:MiniFillHeight()) or 16
end
local function miniDetailFillHeight()
return (Style and Style.MiniDetailFillHeight and Style:MiniDetailFillHeight()) or 14
end
local function minWindowHeight()
return LIST_TOP + miniRowHeight() * MIN_VISIBLE_ROWS + MINI_BOTTOM_PAD
end
M.mode = "current"
M.detailPlayer = nil
M.listScroll = 0
M.detailScroll = 0
local function noWrap(fs)
if fs and fs.SetWordWrap then fs:SetWordWrap(false) end
if fs and fs.SetNonSpaceWrap then fs:SetNonSpaceWrap(false) end
end
local function enableWheel(widget, handler)
if not widget then return end
if widget.EnableMouse then widget:EnableMouse(true) end
if widget.EnableMouseWheel then widget:EnableMouseWheel(true) end
widget:SetScript("OnMouseWheel", handler)
end
local function miniFont(fs, size, flags)
if fs and fs.SetFont and STANDARD_TEXT_FONT then fs:SetFont(STANDARD_TEXT_FONT, size, flags or "OUTLINE") end
noWrap(fs)
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
local function miniDB()
if not NoWCL.db then return nil end
NoWCL.db.window = NoWCL.db.window or {}
NoWCL.db.window.mini = NoWCL.db.window.mini or {}
return NoWCL.db.window.mini
end
local function savePosition(f)
local db = miniDB()
if not db or not f then return end
local point, _, relativePoint, x, y = f:GetPoint(1)
db.point = point or "CENTER"
db.relativePoint = relativePoint or db.point
db.x = x or 0
db.y = y or 0
db.width = f:GetWidth() or db.width or DEFAULT_W
db.height = f:GetHeight() or db.height or DEFAULT_H
end
local function restorePosition(f)
local db = miniDB()
if not db or not db.point then return false end
f:ClearAllPoints()
f:SetPoint(db.point, UIParent, db.relativePoint or db.point, db.x or 0, db.y or 0)
return true
end
local function clampWidth(w)
w = tonumber(w) or DEFAULT_W
if w < MIN_W then return MIN_W end
if w > MAX_W then return MAX_W end
return w
end
local function clampHeight(h)
h = tonumber(h) or DEFAULT_H
local minH = minWindowHeight()
if h < minH then return minH end
if h > MAX_H then return MAX_H end
return h
end
local function visibleListRows()
local h = frame and frame:GetHeight() or DEFAULT_H
local top = M.mode == "current" and LIST_TOP or 52
local n = math.floor(math.max(0, h - top - MINI_BOTTOM_PAD) / miniRowHeight())
if n < MIN_VISIBLE_ROWS then return MIN_VISIBLE_ROWS end
return n
end
local function visibleDetailRows()
local h = frame and frame:GetHeight() or DEFAULT_H
local n = math.floor(math.max(0, h - DETAIL_TOP - MINI_BOTTOM_PAD) / miniDetailRowHeight())
if n < MIN_VISIBLE_ROWS then return MIN_VISIBLE_ROWS end
return n
end
local function clampScroll(offset, total, visible)
offset = math.floor(tonumber(offset) or 0)
local maxOffset = math.max(0, (total or 0) - (visible or 0))
if offset < 0 then return 0 end
if offset > maxOffset then return maxOffset end
return offset
end
local function wheelDeltaRows(delta)
local rows = math.floor(math.abs(tonumber(delta) or 0) * WHEEL_STEP + 0.5)
if rows < 1 then rows = 1 end
if (delta or 0) > 0 then rows = -rows end
return rows
end
local function listBarWidth()
return math.max(74, (frame and frame:GetWidth() or DEFAULT_W) - LIST_CONTENT_X - LIST_RIGHT_PAD)
end
local function listMetricWidth()
local width = frame and frame:GetWidth() or DEFAULT_W
return math.min(156, math.max(116, width - 70))
end
local function detailBarWidth()
return math.max(74, (frame and frame:GetWidth() or DEFAULT_W) - DETAIL_VALUE_RIGHT)
end
local function detailNameWidth(leftOffset, barMax)
return math.max(34, (barMax or detailBarWidth()) - (leftOffset or 0) - DETAIL_VALUE_W - 8)
end
local function rowOpaque()
return U.WindowOpaqueRows and U.WindowOpaqueRows()
end
local function playerInCombat()
return (UnitAffectingCombat and UnitAffectingCombat("player"))
or (InCombatLockdown and InCombatLockdown()) or false
end
local function selfBuffSnapshot(forceScan)
local checker = NoWCL.ConsumableCheck
if not checker then return nil end
local snapshot = checker.GetSnapshot and checker:GetSnapshot() or nil
if not playerInCombat() and checker.Scan and (forceScan or not snapshot) then
snapshot = checker:Scan()
end
return snapshot
end
local function selfBuffRow(snapshot)
local myName = UnitName and UnitName("player")
if myName then myName = tostring(myName):match("^[^-]+") or myName end
for _, row in ipairs(snapshot and snapshot.players or {}) do
if row.isSelf == true or (myName and row.name == myName) then return row end
end
end
local function selfBuffIconLimit(status)
local width = status and status.GetWidth and status:GetWidth() or 70
return math.max(1, math.floor((math.max(24,width)-22)/18))
end
local function updateSelfBuffButton()
local button = frame and frame.selfBuffButton
if not button then return end
local audit = NoWCL.AuditUI
local remaining = audit and audit.ReminderCooldownRemaining
and audit:ReminderCooldownRemaining("self") or 0
if remaining > 0 then
button:SetText(string.format("冷却%d秒",remaining));button:Disable()
else
button:SetText("一键催Buff");button:Enable()
end
end
local function renderSelfBuffStatus(forceScan)
local snapshot = selfBuffSnapshot(forceScan)
local row = selfBuffRow(snapshot)
local result = row and row.teamBuff
local context = snapshot and {
roster=snapshot.players,currentSources=snapshot.teamBuffSources,
previousSources=NoWCL.ConsumableCheck and NoWCL.ConsumableCheck.PreviousBuffSources
and NoWCL.ConsumableCheck:PreviousBuffSources() or {},
} or nil
local text,color = "?",{0.65,0.65,0.68}
if NoWCL.TeamBuffs and NoWCL.TeamBuffs.CellText and result then
text,color=NoWCL.TeamBuffs:CellText(result,context,selfBuffIconLimit(frame.selfBuffStatus))
end
frame.selfBuffStatus:SetText(text)
frame.selfBuffStatus:SetTextColor(color[1],color[2],color[3])
frame.selfBuffHit.result=result
frame.selfBuffHit.teamBuffContext=context
frame.selfBuffHit:SetShown(result~=nil)
local missing = result and ((tonumber(result.missing) or 0) + (tonumber(result.noSource) or 0)) or 0
frame.selfBuffButton:SetShown(missing > 0)
updateSelfBuffButton()
end
local function classRGB(class)
if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
local c = RAID_CLASS_COLORS[class]
return c.r or 0.55, c.g or 0.62, c.b or 0.85
end
return 0.55, 0.62, 0.85
end
local function roleOf(pl)
return U.RoleOfPlayer and U.RoleOfPlayer(pl) or (NoWCL.Stats and NoWCL.Stats:RoleOf(pl.name)) or "DAMAGER"
end
local function roleRank(pl)
return U.DisplayRoleRank and U.DisplayRoleRank(pl) or 1
end
local function metric(pl, view)
return U.PlayerDisplayMetric(pl, view, M.mode)
end
local function extraText(pl)
local txt = U.FormatExtraTasks(pl)
return txt ~= "-" and txt or ""
end
local function liveView()
local visible = NoWCL.Stats and NoWCL.Stats.IsCurrentSegmentVisible
and NoWCL.Stats:IsCurrentSegmentVisible()
if visible then
local players, dur
if NoWCL.Stats.GetDisplayPlayers then players, dur = NoWCL.Stats:GetDisplayPlayers()
else players, dur = NoWCL.Stats:GetPlayers() end
U.ApplyReadinessToPlayers(players)
return {
encounter = NoWCL.Stats:SegmentName(), dur = dur, players = players, live = true,
isBoss = NoWCL.Stats.segment.isBoss and true or false,
recordable = NoWCL.Stats:SegmentRecordable(),
calibrated = NoWCL.Stats:SegmentCalibrated(),
bossSpells = NoWCL.Stats.segment.bossSpells,
puller = NoWCL.Stats.segment.puller,
pullMethod = NoWCL.Stats.segment.pullMethod,
pullSpellId = NoWCL.Stats.segment.pullSpellId,
}
end
return nil
end
local function currentView()
local live = liveView()
if live then
live.players = U.CompleteCurrentRoster(live.players, live.dur)
U.ApplyReadinessToPlayers(live.players)
live.currentRosterComplete = true
return live
end
if NoWCL.Stats and NoWCL.Stats.ViewPlayers then
local previous = NoWCL.Stats.lastCurrentSegment
local endedAt = previous and tonumber(previous.ts)
local age = endedAt and math.max(0, (time and time() or endedAt) - endedAt) or math.huge
if not playerInCombat() and (not previous or age >= PREVIOUS_FIGHT_HOLD_SECONDS) then
local checker = NoWCL.ConsumableCheck
local snapshot = checker and checker.GetSnapshot and checker:GetSnapshot()
if not snapshot and checker and checker.Scan then snapshot = checker:Scan() end
snapshot = snapshot or { players={} }
local players = U.CompleteCurrentRoster(snapshot.players or {}, 0)
U.ApplyReadinessToPlayers(players)
return {
encounter="当前状态", dur=0, players=players, readiness=true,
readinessSnapshot=snapshot, currentRosterComplete=true, live=false,
}
end
local players, dur, name = NoWCL.Stats:ViewPlayers("current")
players = U.CompleteCurrentRoster(players, dur)
U.ApplyReadinessToPlayers(players)
local snapshot = NoWCL.Stats.lastCurrentSegment
or (NoWCL.Stats.history and NoWCL.Stats.history[1])
return { encounter = name, dur = dur, players = players, live = false,
currentRosterComplete=true,
bossSpells=snapshot and snapshot.bossSpells, puller=snapshot and snapshot.puller,
pullMethod=snapshot and snapshot.pullMethod, pullSpellId=snapshot and snapshot.pullSpellId }
end
return { encounter = "当前", dur = 0, players = {} }
end
local function allView(includeDetails)
local base = (NoWCL.Sync and NoWCL.Sync.GetView) and NoWCL.Sync:GetView("all", includeDetails)
or { encounter = "所有战斗汇总", dur = 0, players = {} }
local live = liveView()
if U.ShouldMergeLiveIntoSummary(live) then return U.MergeCombatViews(base, live, includeDetails) end
return base
end
local function selectedTab()
if M.mode == "current" or M.mode == "all" then return nil end
return NoWCL.Sync and NoWCL.Sync.tabs and NoWCL.Sync.tabs[M.mode] or nil
end
local function selectionAvailable(selection)
if selection == "current" or selection == "all" then return true end
local sync = NoWCL.Sync
local tab = sync and sync.tabs and sync.tabs[selection]
if not tab then return false end
return not sync.IsTabVisibleForCurrentCharacter or sync:IsTabVisibleForCurrentCharacter(tab)
end
local function persistSelection()
local db = miniDB()
if db then db.mode = M.mode end
end
local function normalizeSelection()
if selectionAvailable(M.mode) then return false end
M.mode = "current"
persistSelection()
return true
end
local function tabMenuLabel(tab)
local owner = tab.ownerCharacterName or "当前角色"
owner = owner:match("^[^-]+") or owner
local label = U.Trunc(tab.boss or "场", 8) .. "  " .. date("%H:%M", tab.ts or 0)
if NoWCL.Sync and NoWCL.Sync.ShowAllCharacterFights and NoWCL.Sync:ShowAllCharacterFights() then
label = U.Trunc(owner, 6) .. " · " .. label
end
return label
end
local function selectionMenuItems()
normalizeSelection()
local items = {
{ text="当前", value="current", checked=M.mode == "current" },
{ text="所有战斗汇总", value="all", checked=M.mode == "all" },
}
local tabs = NoWCL.Sync and NoWCL.Sync.GetTabs and NoWCL.Sync:GetTabs() or {}
for _, tab in ipairs(tabs) do
items[#items+1] = {
text=tabMenuLabel(tab), value=tab.fightId, checked=M.mode == tab.fightId,
}
end
return items
end
local function selectionButtonLabel()
if M.mode == "current" then return "当前" end
if M.mode == "all" then return "全部" end
local tab = selectedTab()
return U.Trunc(tab and tab.boss or "当前", 4)
end
local function getView(includeDetails)
normalizeSelection()
if M.mode == "all" then return allView(includeDetails) end
if M.mode == "current" then return currentView() end
if NoWCL.Sync and NoWCL.Sync.GetView then return NoWCL.Sync:GetView(M.mode, includeDetails) end
return { encounter = "无数据", dur = 0, players = {} }
end
function M:SelectView(selection)
selection = tostring(selection or "current")
if not selectionAvailable(selection) then selection = "current" end
M.mode = selection
M.detailPlayer = nil
M.listScroll = 0
M.detailScroll = 0
persistSelection()
self:Refresh()
return M.mode
end
local function applyMiniRowStyle(row, index)
local h = miniRowHeight()
row:SetHeight(h)
row:ClearAllPoints()
row:SetPoint("TOPLEFT", 0, -(index - 1) * h)
row:SetPoint("TOPRIGHT", 0, -(index - 1) * h)
row.barBg:SetHeight(miniFillHeight())
row.bar:SetHeight(miniFillHeight())
if Style and Style.ApplyTexture then Style:ApplyTexture(row.bar, 0.55, 0.62, 0.85, 0.58) end
if Style and Style.ApplyFont then
Style:ApplyFont(row.rank, -1)
Style:ApplyFont(row.name, 0)
Style:ApplyFont(row.metric, -1)
Style:ApplyFont(row.death, -3)
end
if row.nameHit then row.nameHit:SetHeight(h) end
row.death:ClearAllPoints(); row.death:SetPoint("RIGHT", -2, 0)
noWrap(row.rank); noWrap(row.name); noWrap(row.metric); noWrap(row.death)
end
local function applyMiniDetailRowStyle(row, index)
local h = miniDetailRowHeight()
row:SetHeight(h)
row:ClearAllPoints()
row:SetPoint("TOPLEFT", 0, -(index - 1) * h)
row:SetPoint("TOPRIGHT", 0, -(index - 1) * h)
row.barBg:SetHeight(miniDetailFillHeight())
row.bar:SetHeight(miniDetailFillHeight())
if Style and Style.ApplyTexture then Style:ApplyTexture(row.bar, 0.55, 0.62, 0.85, 0.52) end
if Style and Style.ApplyFont then
Style:ApplyFont(row.name, 0)
Style:ApplyFont(row.val, 0)
end
local iconSize = math.max(12, math.min(16, h - 2))
row.icon:SetSize(iconSize, iconSize)
noWrap(row.name); noWrap(row.val)
end
local function getRow(i)
if rows[i] then return rows[i] end
local b = CreateFrame("Button", nil, frame.body)
b:RegisterForClicks("LeftButtonUp")
enableWheel(b, function(_, delta) M:ScrollList(delta) end)
U.RegisterOpacityChromeHover(frame, b)
b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints()
b.barBg = b:CreateTexture(nil, "BACKGROUND")
b.barBg:SetPoint("LEFT", LIST_CONTENT_X, 0)
b.barBg:SetColorTexture(0.12, 0.12, 0.14, 0.70)
b.bar = b:CreateTexture(nil, "ARTWORK")
b.bar:SetPoint("LEFT", LIST_CONTENT_X, 0)
b.rank = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
b.rank:SetPoint("RIGHT", b, "LEFT", LIST_CONTENT_X-LIST_RANK_GAP, 0); miniFont(b.rank, 11)
b.name = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
b.name:SetPoint("LEFT", LIST_CONTENT_X, 0); b.name:SetWidth(122); b.name:SetJustifyH("LEFT"); miniFont(b.name, 12)
b.nameHit=CreateFrame("Frame",nil,b)
b.nameHit:SetPoint("LEFT",b,"LEFT",LIST_CONTENT_X,0);b.nameHit:SetSize(122,miniRowHeight())
b.nameHit:SetFrameLevel(b:GetFrameLevel()+3);b.nameHit:EnableMouse(true)
b.nameHit:SetScript("OnEnter",function()
if b.playerName and NoWCL.GearInspectPanel and NoWCL.GearInspectPanel.BeginPlayerNameHover then
NoWCL.GearInspectPanel:BeginPlayerNameHover(
b.playerName,b.playerClass,b.playerSpecId,frame,b.nameHit,
{viewProvider=b.damageViewProvider,selection=M.mode})
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
b.metric = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
b.metric:SetPoint("RIGHT", -18, 0); b.metric:SetWidth(156); b.metric:SetJustifyH("RIGHT"); miniFont(b.metric, 11)
b.death = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
b.death:SetPoint("RIGHT", -2, 0); b.death:SetWidth(14); b.death:SetJustifyH("CENTER"); miniFont(b.death, 9)
applyMiniRowStyle(b, i)
local hl = b:CreateTexture(nil, "HIGHLIGHT")
hl:SetAllPoints(); hl:SetColorTexture(0.35, 0.45, 0.65, 0.22)
b:SetScript("OnClick", function(self)
if not self.playerName then return end
M.detailPlayer = self.playerName
M.detailScroll = 0
M:Refresh()
end)
rows[i] = b
return b
end
local function getDetailRow(i)
if detailRows[i] then return detailRows[i] end
local r = CreateFrame("Frame", nil, frame.detailList)
r:EnableMouse(true)
enableWheel(r, function(_, delta) M:ScrollDetail(delta) end)
U.RegisterOpacityChromeHover(frame, r)
r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints()
r.barBg = r:CreateTexture(nil, "BACKGROUND")
r.barBg:SetPoint("LEFT", 0, 0)
r.barBg:SetColorTexture(0.12, 0.12, 0.14, 0.70)
r.bar = r:CreateTexture(nil, "ARTWORK"); r.bar:SetPoint("LEFT", 0, 0)
r.icon = r:CreateTexture(nil, "OVERLAY"); r.icon:SetSize(16,16); r.icon:SetPoint("LEFT",1,0); r.icon:SetTexCoord(0.08,0.92,0.08,0.92)
r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
r.name:SetPoint("LEFT", 24, 0); r.name:SetWidth(160); r.name:SetJustifyH("LEFT"); miniFont(r.name, 12)
r.val = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
r.val:SetPoint("RIGHT", -DETAIL_VALUE_RIGHT, 0); r.val:SetWidth(DETAIL_VALUE_W); r.val:SetJustifyH("RIGHT"); miniFont(r.val, 12)
r:SetScript("OnEnter",function(self) showMiniDetailTooltip(self,self._detailItem) end)
r:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
applyMiniDetailRowStyle(r, i)
detailRows[i] = r
return r
end
local function sortedMapRows(t, cap)
local out = {}
for name, v in pairs(t or {}) do out[#out+1] = { name = name, v = tonumber(v) or 0 } end
table.sort(out, function(a, b) return a.v > b.v end)
while cap and #out > cap do table.remove(out) end
return out
end
local function findPlayer(view, name)
for _, pl in ipairs(view.players or {}) do
if pl.name == name then return pl end
end
return nil
end
showMiniDetailTooltip = function(owner,item)
if not (GameTooltip and item and not item.header) then return end
if item.kind=="spell" then
if D and D.ShowSpellTooltip then D.ShowSpellTooltip(owner,item,item.isHeal,item.total) end
elseif item.kind=="buff" or item.kind=="debuff" then
if D and D.ShowAuraTooltip then D.ShowAuraTooltip(owner,item,item.kind) end
elseif item.kind=="boss" then
if D and D.ShowBossTooltip then D.ShowBossTooltip(owner,item) end
end
end
local miniTimelineBars, miniTimelineHits, miniBossMarks = {}, {}, {}
local function renderMiniBossMarkers(chart,bossSpells,dur)
for _,mark in ipairs(miniBossMarks) do mark:Hide(); mark._event=nil end
if not (D and D.BossEvents and bossSpells and dur>0) then return end
local plotW,plotH=chart.plot:GetWidth(),chart.plot:GetHeight()
if plotW<10 then plotW=math.max(100,(frame:GetWidth() or DEFAULT_W)-20) end
if plotH<10 then plotH=24 end
local shown=0
for _,event in ipairs(D.BossEvents(bossSpells)) do
if event.time<=dur and shown<40 then
shown=shown+1
local mark=miniBossMarks[shown]
if not mark then
mark=CreateFrame("Frame",nil,chart.plot); mark:EnableMouse(true); mark:SetFrameLevel(chart.plot:GetFrameLevel()+5)
mark.line=mark:CreateTexture(nil,"OVERLAY"); mark.line:SetPoint("CENTER"); mark.line:SetWidth(1); mark.line:SetPoint("TOP"); mark.line:SetPoint("BOTTOM")
mark:SetScript("OnEnter",function(self)
local ev=self._event; if not (ev and GameTooltip) then return end
GameTooltip:SetOwner(self,"ANCHOR_TOP")
GameTooltip:ClearLines()
if ev.spellId and ev.spellId>0 and GameTooltip.SetHyperlink then GameTooltip:SetHyperlink("spell:"..ev.spellId)
else GameTooltip:AddLine(ev.name or "Boss技能",1,0.82,0) end
GameTooltip:AddLine(string.format("%.1f秒%s",ev.time or 0,(ev.target and ev.target~="") and ("  → "..ev.target) or ""),0.9,0.9,0.9)
GameTooltip:Show()
end)
mark:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
miniBossMarks[shown]=mark
end
mark._event=event
mark.line:SetColorTexture(event.code==1 and 1 or 0.85,event.code==1 and 0.72 or 0.35,event.code==3 and 0.95 or 0.15,0.9)
mark:ClearAllPoints(); mark:SetPoint("BOTTOMLEFT",chart.plot,"BOTTOMLEFT",plotW*math.min(1,event.time/dur)-2,0)
mark:SetSize(5,plotH); mark:Show()
end
end
end
local function renderMiniTimeline(view, pl, damageMode, isHeal)
local chart = frame.detailChart
for _, bar in ipairs(miniTimelineBars) do bar:Hide() end
for _, hit in ipairs(miniTimelineHits) do hit:Hide(); hit.timelineRate=nil end
for _, mark in ipairs(miniBossMarks) do mark:Hide(); mark._event=nil end
if not pl then
chart.label:SetText(""); chart.empty:SetText("")
U.RenderTimelineAxis(chart.axis, 0)
return
end
local buckets = U.PlayerTimelineBuckets(pl,damageMode)
local rates, count, peak, spans, dur, bucketSec = U.ResampleTimelineBuckets(
buckets, pl.ivDur or view.dur, pl.timelineBucket or 5, MINI_TIMELINE_COLUMNS)
chart.label:SetText(peak > 0 and (bucketSec.."秒"..(isHeal and "HPS" or "DPS").."  峰值 "..U.Short(peak)) or "")
chart.empty:SetText(count == 0 and "|cff666666无曲线数据|r" or "")
U.RenderTimelineAxis(chart.axis, dur, { fallbackWidth=math.max(100,(frame:GetWidth() or DEFAULT_W)-20),
minLabelSpacing=20, opacityRoot=frame, fontFn=function(label)
miniFont(label,8); if Style and Style.ApplyFontFace then Style:ApplyFontFace(label) end
end })
U.RenderTimelineGuides(chart.plot, peak, { step=2000, major=10000,
fallbackHeight=24, opacityRoot=frame })
renderMiniBossMarkers(chart,view.bossSpells,dur)
if count == 0 then return end
local plotW, plotH = chart.plot:GetWidth(), chart.plot:GetHeight()
if plotW < 10 then plotW = math.max(100, (frame:GetWidth() or DEFAULT_W) - 20) end
if plotH < 10 then plotH = 24 end
local barW = plotW / count
local color = isHeal and {0.25,0.90,0.45}
or ((RAID_CLASS_COLORS and RAID_CLASS_COLORS[pl.class]) or {r=0.35,g=0.65,b=1})
local cr, cg, cb = color.r or color[1], color.g or color[2], color.b or color[3]
for i = 1, count do
local bar = miniTimelineBars[i]
if not bar then bar = chart.plot:CreateTexture(nil,"ARTWORK"); miniTimelineBars[i] = bar end
bar:ClearAllPoints(); bar:SetPoint("BOTTOMLEFT",chart.plot,"BOTTOMLEFT",(i-1)*barW,0)
bar:SetSize(math.max(1,barW-1), peak>0 and math.max(1,plotH*rates[i]/peak) or 1)
bar:SetColorTexture(cr,cg,cb,0.82); bar:Show()
local hit=miniTimelineHits[i]
if not hit then
hit=CreateFrame("Frame",nil,chart.plot); hit:EnableMouse(true)
U.BindTimelineBarTooltip(hit,frame); miniTimelineHits[i]=hit
end
local startSec = spans[i] and spans[i].startSec or (i - 1) * bucketSec
local endSec = spans[i] and spans[i].endSec or startSec + bucketSec
hit:ClearAllPoints(); hit:SetPoint("BOTTOMLEFT",chart.plot,"BOTTOMLEFT",(i-1)*barW,0)
hit:SetSize(math.max(1,barW),plotH)
hit.timelineMetric=isHeal and "HPS" or "DPS"; hit.timelineRate=rates[i]
hit.timelineStart=startSec; hit.timelineEnd=endSec; hit:Show()
end
end
local function renderDetail(view, pl)
for _, h in ipairs(frame.heads or {}) do h:Hide() end
if frame.selfBuffHit then frame.selfBuffHit:Hide() end
frame.body:Hide()
frame.detailPane:Show()
frame.detailBack:Show()
frame.sub:Show()
if not pl then
frame._detailTotal = 0
frame._detailVisible = visibleDetailRows()
M.detailScroll = 0
frame.detailName:SetText("|cffff8888无当前明细|r")
frame.detailMetric:SetText("")
frame.detailSub:SetText("该玩家不在当前视图中。")
renderMiniTimeline(view, nil)
for _, r in ipairs(detailRows) do r:Hide() end
return
end
local amount, dps, role, damageMode = metric(pl, view)
local isHeal = role == "HEALER"
local detailTotal = isHeal and amount or U.N(pl.dmg)
frame.detailName:SetText(U.SpecIconTag(pl.specId,14)..(U.RolePrefix and U.RolePrefix(pl, 12) or "") .. U.ClassColor(U.Trunc(pl.name or "?", 8), pl.class))
frame.detailMetric:SetText(U.Short(amount).."  "..(isHeal and "HPS " or "DPS ")..U.Short(dps))
frame.detailSub:SetText((view.encounter or "").."  "..U.FmtTime(view.dur or 0).."  "
..(isHeal and "治疗明细" or (damageMode == "boss" and "WCL伤害明细" or "全程伤害明细")))
renderMiniTimeline(view, pl, damageMode, isHeal)
local items = {}
local spellMap, targetMap = pl.spells, pl.targets
if isHeal then spellMap, targetMap = pl.heals, pl.healTargets end
local bossCfg=(view.cfg and view.cfg.bossCfg) or (NoWCL.db and NoWCL.db.settings and NoWCL.db.settings.bossCfg)
local spellList=D and D.SpellRows and D.SpellRows(pl,isHeal,view.encounter,damageMode,bossCfg) or sortedMapRows(spellMap)
for _,it in ipairs(spellList) do it.v=it.amount or it.v or 0; it.total=amount; it.isHeal=isHeal end
local targetList = sortedMapRows(targetMap)
local classByName = {}
for _, p in ipairs(view.players or {}) do if p.name and p.class then classByName[p.name] = p.class end end
local spellMax = spellList[1] and spellList[1].v or 1
local targetMax = targetList[1] and targetList[1].v or 1
items[#items+1] = { label = "|cffffd100按技能|r", header = true }
for _, it in ipairs(spellList) do it.kind = "spell"; it.max = spellMax; items[#items+1] = it end
items[#items+1] = { label = isHeal and "|cffffd100按目标|r"
or (damageMode == "all" and "|cffffd100按目标|r |cff888888绿:全程均计入|r"
or "|cffffd100按目标|r |cff888888绿:计入总量/灰:统计口径排除|r"), header = true }
for _, it in ipairs(targetList) do it.kind = "target"; it.max = targetMax; items[#items+1] = it end
local auraBoss
if M.mode~="all" then auraBoss=view.encounter end
local buffs=D and D.AuraRows and D.AuraRows(pl,"buff",view.dur,auraBoss,bossCfg) or {}
local debuffs=D and D.AuraRows and D.AuraRows(pl,"debuff",view.dur,auraBoss,bossCfg) or {}
items[#items+1]={label="|cffffd100Buff覆盖|r",header=true}
for _,it in ipairs(buffs) do it.kind="buff"; it.v=it.uptime; it.max=math.max(1,view.dur or 0); items[#items+1]=it end
items[#items+1]={label="|cffffd100Debuff覆盖|r",header=true}
for _,it in ipairs(debuffs) do it.kind="debuff"; it.v=it.uptime; it.max=math.max(1,view.dur or 0); items[#items+1]=it end
local bossList=D and D.BossRows and D.BossRows(view.bossSpells) or {}
if #bossList>0 then
items[#items+1]={label="|cffff6b55Boss技能|r |cff888888时间点见曲线|r",header=true}
local bossMax=1; for _,it in ipairs(bossList) do bossMax=math.max(bossMax,it.damage or 0,it.casts or 0) end
for _,it in ipairs(bossList) do it.kind="boss"; it.v=math.max(it.damage or 0,it.casts or 0); it.max=bossMax; items[#items+1]=it end
end
local maxDetailRows = visibleDetailRows()
M.detailScroll = clampScroll(M.detailScroll, #items, maxDetailRows)
frame._detailTotal = #items
frame._detailVisible = maxDetailRows
for i = 1, math.max(maxDetailRows, #detailRows) do
local row = detailRows[i] or getDetailRow(i)
local itemIndex = (M.detailScroll or 0) + i
local it = i <= maxDetailRows and items[itemIndex] or nil
if it then
row._detailItem=it
row.bg:SetColorTexture(0, 0, 0, (itemIndex % 2 == 0) and 0.15 or 0.04)
if it.header then
row.barBg:Hide()
row.bar:Hide()
row.icon:Hide()
row.name:ClearAllPoints(); row.name:SetPoint("LEFT", 8, 0); row.name:SetWidth(math.max(42, detailBarWidth() - 8))
row.name:SetText(it.label)
row.val:SetText("")
else
local barMax = detailBarWidth()
row.barBg:ClearAllPoints()
row.barBg:SetPoint("LEFT", row, "LEFT", 0, 0)
row.barBg:SetWidth(barMax)
row.barBg:SetColorTexture(0.12, 0.12, 0.14, rowOpaque() and 1 or 0.70)
row.barBg:Show()
row.bar:ClearAllPoints()
row.bar:SetPoint("LEFT", row, "LEFT", 0, 0)
row.bar:SetWidth(math.max(2, barMax * (it.v / (it.max or 1))))
row.bar:Show()
if it.kind == "spell" or it.kind=="buff" or it.kind=="debuff" or it.kind=="boss" then
local meta = NoWCL.Stats.spellInfo and NoWCL.Stats.spellInfo[it.name]
local icon = (it.spellId and it.spellId>0 and GetSpellTexture(it.spellId)) or (meta and meta.icon)
if not icon then icon = GetSpellTexture(it.name == "近战" and 6603 or it.name) end
if icon then row.icon:SetTexture(icon); row.icon:Show() else row.icon:Hide() end
row.name:ClearAllPoints(); row.name:SetPoint("LEFT", 24, 0); row.name:SetWidth(detailNameWidth(24, barMax))
local col = it.kind=="buff" and {0.35,0.72,1.0}
or it.kind=="debuff" and {0.82,0.42,0.90}
or it.kind=="boss" and {0.90,0.36,0.28}
or schoolColor(it.school or (meta and meta.school))
if Style and Style.SetTextureColor then Style:SetTextureColor(row.bar, col[1], col[2], col[3], rowOpaque() and 1 or 0.52) end
else
row.icon:Hide()
row.name:ClearAllPoints(); row.name:SetPoint("LEFT", 8, 0); row.name:SetWidth(detailNameWidth(8, barMax))
local included = isHeal or damageMode == "all" or (pl.targetsBoss and pl.targetsBoss[it.name])
local col = included and {0.30,0.80,0.40} or {0.50,0.50,0.55}
if Style and Style.SetTextureColor then Style:SetTextureColor(row.bar, col[1], col[2], col[3], rowOpaque() and 1 or 0.52) end
end
if it.kind == "target" and isHeal then
row.name:SetText(U.ClassColor(U.Trunc(it.name or "?", 15), classByName[it.name]))
elseif (it.kind=="buff" or it.kind=="debuff") and it.peer and it.peer~="" and it.peer~=pl.name then
row.name:SetText(U.Trunc((it.name or "?").." ["..it.peer.."]",15))
else
row.name:SetText(U.Trunc(it.name or "?", 15))
end
if it.kind=="spell" then
local crit=(it.hits or 0)>0 and string.format(" %.0f%%暴",(it.crits or 0)/it.hits*100) or ""
row.val:SetText(U.Short(it.v).." |cffffd100"..U.Pct2(amount>0 and it.v/amount or 0).."|r"..crit)
elseif it.kind=="buff" or it.kind=="debuff" then
row.val:SetText(string.format("%.1fs |cffffd100%.0f%%|r",it.uptime or 0,(it.percent or 0)*100))
elseif it.kind=="boss" then
row.val:SetText((it.casts or 0).."次  "..U.Short(it.damage or 0))
else
row.val:SetText(U.Short(it.v).."  |cffffd100"..U.Pct2(detailTotal>0 and it.v/detailTotal or 0).."|r")
end
end
row:Show()
else
row._detailItem=nil
row:Hide()
end
end
end
local function renderList(view)
frame.detailPane:Hide()
frame.detailBack:Hide()
for _, h in ipairs(frame.heads or {}) do h:Show() end
local showPuller = M.mode == "current"
frame.pullHead:SetShown(showPuller)
frame.selfBuffLabel:SetShown(showPuller)
frame.selfBuffStatus:SetShown(showPuller)
frame.selfBuffButton:SetShown(false)
if not showPuller then frame.selfBuffHit:Hide() end
frame.body:ClearAllPoints()
frame.body:SetPoint("TOPLEFT", 0, showPuller and -LIST_TOP or -52)
frame.body:SetPoint("BOTTOMRIGHT", 0, MINI_BOTTOM_PAD)
if showPuller then
local class
for _, pl in ipairs(view.players or {}) do
if pl.name == view.puller then class = pl.class; break end
end
if view.puller then
local method = view.pullMethod and view.pullMethod ~= "" and (" · " .. view.pullMethod) or ""
frame.pullHead:SetText("|cffffd100开怪：|r"..U.ClassColor(view.puller,class).."|cffffd100"..method.."|r")
else
frame.pullHead:SetText("|cff888888开怪：未记录|r")
end
renderSelfBuffStatus(false)
end
frame.body:Show()
local players = {}
for _, pl in ipairs(view.players or {}) do
local amount, dps = metric(pl, view)
if view.currentRosterComplete or amount > 0 or dps > 0 or (pl.deaths or 0) > 0
or U.FormatExtraTasks(pl) ~= "-" then
players[#players+1] = pl
end
end
local mode = U.ResolveDamageMode(view, M.mode)
if U.SortDisplayPlayers then
U.SortDisplayPlayers(players,mode,view.dur,view.cfg and view.cfg.taskContrib)
else
table.sort(players, function(a, b)
local ar, br = roleRank(a), roleRank(b)
if ar ~= br then return ar < br end
local av = select(2, metric(a, view))
local bv = select(2, metric(b, view))
if av == bv then return (a.name or "") < (b.name or "") end
return av > bv
end)
end
local rankingMeta=U.DisplayRankingMeta
and U.DisplayRankingMeta(players,mode,view.dur,view.cfg and view.cfg.taskContrib)
local originalRanks = U.PinSelfFirst and U.PinSelfFirst(players)
frame.title:SetText("NoWCL")
frame.sub:SetText(U.Trunc(view.encounter or "无数据", 8).."  "..U.FmtTime(view.dur or 0))
frame.modeBtn:SetText(selectionButtonLabel())
local maxRows = visibleListRows()
M.listScroll = clampScroll(M.listScroll, #players, maxRows)
frame._listTotal = #players
frame._listVisible = maxRows
for i = 1, math.max(maxRows, #rows) do
local row = rows[i] or getRow(i)
local rank = (M.listScroll or 0) + i
local pl = i <= maxRows and players[rank] or nil
if pl then
local amount, dps, role = metric(pl, view)
local metricGroup = role == "HEALER" and "healing" or "damage"
local displayRank = rankingMeta and rankingMeta.ranks[pl]
or (originalRanks and originalRanks[pl] or rank)
local groupPeak = rankingMeta and rankingMeta.peaks[metricGroup] or 1
local rel = amount / groupPeak
local shareTotal = rankingMeta and rankingMeta.totals[metricGroup] or 0
local share = shareTotal > 0 and amount / shareTotal or 0
local r, g, b = classRGB(pl.class)
local barMax = listBarWidth()
local metricW = listMetricWidth()
row.playerName = pl.name
row.playerClass = pl.class
row.playerSpecId = pl.specId
row.damageViewProvider=function() return getView(true),M.mode end
row.bg:SetColorTexture(0, 0, 0, (rank % 2 == 0) and 0.18 or 0.04)
row.barBg:ClearAllPoints()
row.barBg:SetPoint("LEFT", row, "LEFT", LIST_CONTENT_X, 0)
row.barBg:SetWidth(barMax)
row.barBg:SetColorTexture(0.12, 0.12, 0.14, rowOpaque() and 1 or 0.70)
row.barBg:Show()
row.bar:ClearAllPoints()
row.bar:SetPoint("LEFT", row, "LEFT", LIST_CONTENT_X, 0)
row.bar:SetWidth(math.max(2, barMax * rel))
if Style and Style.SetTextureColor then Style:SetTextureColor(row.bar, r, g, b, rowOpaque() and 1 or 0.58) end
row.metric:SetWidth(metricW)
row.metric:SetText(string.format("%s (%s, %s)", U.Short(amount), U.Short(dps), U.Pct2(share)))
local metricTextW = row.metric.GetStringWidth and row.metric:GetStringWidth() or metricW
metricTextW = math.min(metricW, math.max(0, tonumber(metricTextW) or metricW))
local nameW = math.max(32, (frame:GetWidth() or DEFAULT_W) - metricTextW - LIST_CONTENT_X - 22)
row.name:SetWidth(nameW)
row.nameHit:SetWidth(nameW)
row.rank:SetText(displayRank)
row.name:SetText(U.SpecIconTag(pl.specId,14)..(U.RolePrefix and U.RolePrefix(pl, 12) or "")
..Style:PlayerName(pl.name or "?", pl.class))
local deaths = pl.deaths or 0
row.death:SetText(deaths > 0 and tostring(deaths) or "")
if deaths > 0 then row.death:SetTextColor(1, 0.25, 0.25) else row.death:SetTextColor(0.9, 0.9, 0.9) end
row:Show()
else
row.playerName = nil
row.playerClass = nil
row.playerSpecId = nil
row.damageViewProvider = nil
row.rank:SetText("")
if row.barBg then row.barBg:Hide() end
row:Hide()
end
end
end
function M:Refresh()
if not frame or not frame:IsShown() then return end
if frame.title then frame.title:SetWidth(math.max(28, (frame:GetWidth() or DEFAULT_W) - 160)) end
if frame.pullHead then frame.pullHead:SetWidth(math.max(32,(frame:GetWidth() or DEFAULT_W)-20)) end
local view = getView(M.detailPlayer ~= nil)
frame.modeBtn:SetText(selectionButtonLabel())
if M.detailPlayer then
renderDetail(view, findPlayer(view, M.detailPlayer))
else
renderList(view)
end
end
function M:ScrollList(delta)
if not frame or not frame:IsShown() or M.detailPlayer then return end
local total = frame._listTotal or 0
local visible = frame._listVisible or visibleListRows()
if total <= visible then return end
local nextOffset = clampScroll((M.listScroll or 0) + wheelDeltaRows(delta), total, visible)
if nextOffset == (M.listScroll or 0) then return end
M.listScroll = nextOffset
self:Refresh()
end
function M:ScrollDetail(delta)
if not frame or not frame:IsShown() or not M.detailPlayer then return end
local total = frame._detailTotal or 0
local visible = frame._detailVisible or visibleDetailRows()
if total <= visible then return end
local nextOffset = clampScroll((M.detailScroll or 0) + wheelDeltaRows(delta), total, visible)
if nextOffset == (M.detailScroll or 0) then return end
M.detailScroll = nextOffset
self:Refresh()
end
local function applyOpacityTo(f)
f = f or frame
if not f then return end
if U.ApplyWindowOpacity then U.ApplyWindowOpacity(f) end
if f.opacitySlider and U.SyncOpacitySlider then U.SyncOpacitySlider(f.opacitySlider) end
if f.opacityModeCheck and U.SyncOpacityModeCheck then U.SyncOpacityModeCheck(f.opacityModeCheck) end
end
function M:ApplyOpacity()
applyOpacityTo(frame)
end
function M:ApplyStyle()
if not frame then return end
local h = clampHeight(frame:GetHeight())
if h ~= frame:GetHeight() then frame:SetHeight(h) end
local db = miniDB()
if db then db.height = h end
for i, row in ipairs(rows) do applyMiniRowStyle(row, i) end
for i, row in ipairs(detailRows) do applyMiniDetailRowStyle(row, i) end
if frame:IsShown() then M:Refresh() end
end
local function Create()
local f = CreateFrame("Frame", "NoWCLMiniFrame", UIParent)
local db = miniDB()
f:SetSize(clampWidth(db and db.width), clampHeight(db and db.height))
if not restorePosition(f) then f:SetPoint("CENTER", UIParent, "CENTER", 300, 0) end
U.SetPanelLayer(f)
U.MakeMovable(f)
U.RegisterOpacityChromeHover(f, f)
f:SetScript("OnDragStop", function(self)
self:StopMovingOrSizing()
savePosition(self)
end)
f:SetScript("OnMouseUp", function(self)
self:StopMovingOrSizing()
if self.resizeGrip then self.resizeGrip._resizing = nil end
savePosition(self)
end)
f:SetScript("OnHide", function(self)
self:StopMovingOrSizing()
if self.resizeGrip then self.resizeGrip._resizing = nil end
savePosition(self)
local db = miniDB()
if db then db.shown = false end
end)
local bg = f:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.05, 0.05, 0.07, 0.94)
local tb = f:CreateTexture(nil, "ARTWORK"); tb:SetPoint("TOPLEFT"); tb:SetPoint("TOPRIGHT"); tb:SetHeight(28); tb:SetColorTexture(0.12, 0.12, 0.16, 1)
U.RegisterOpacityChrome(f, bg, tb)
f.logo = f:CreateTexture(nil, "OVERLAY"); f.logo:SetSize(18, 18); f.logo:SetPoint("LEFT", tb, "LEFT", 8, 0); f.logo:SetTexture(TITLE_LOGO)
f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
f.title:SetPoint("LEFT", f.logo, "RIGHT", 5, 0)
f.title:SetWidth(96); f.title:SetJustifyH("LEFT")
miniFont(f.title, 18)
U.RegisterOpacityChrome(f, f.logo, f.title)
f.detailBack = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
f.detailBack:SetSize(46, 20); f.detailBack:SetPoint("TOPRIGHT", -98, -4); f.detailBack:SetText("返回")
f.detailBack:SetScript("OnClick", function()
M.detailPlayer = nil
M.detailScroll = 0
M:Refresh()
end)
f.detailBack:Hide()
U.RegisterOpacityChrome(f, f.detailBack)
U.RegisterOpacityChromeHover(f, f.detailBack)
f.modeBtn = U.MakeDropdown(f, 88)
f.modeBtn.menuWidth = 230
f.modeBtn:SetHeight(20); f.modeBtn:SetPoint("TOPLEFT", 8, -30)
f.modeBtn.itemsFn = selectionMenuItems
f.modeBtn.onSelect = function(selection) M:SelectView(selection) end
local modeButtonText = f.modeBtn:GetFontString()
if modeButtonText then miniFont(modeButtonText, 10) end
U.RegisterOpacityChrome(f, f.modeBtn)
U.RegisterOpacityChromeHover(f, f.modeBtn)
f.fullBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
f.fullBtn:SetSize(62, 20); f.fullBtn:SetPoint("TOPRIGHT", -32, -4); f.fullBtn:SetText("全窗口")
f.fullBtn:SetScript("OnClick", function()
local detailPlayer = M.detailPlayer
local selection = M.mode
M:Hide()
if detailPlayer and NoWCL.AuditUI and NoWCL.AuditUI.OpenDetail then
NoWCL.AuditUI:OpenDetail(detailPlayer, selection)
elseif NoWCL.AuditUI and NoWCL.AuditUI.ShowFull then
NoWCL.AuditUI:ShowFull(selection)
elseif NoWCL.AuditUI and NoWCL.AuditUI.Toggle then
NoWCL.AuditUI:Toggle()
end
end)
U.RegisterOpacityChrome(f, f.fullBtn)
U.RegisterOpacityChromeHover(f, f.fullBtn)
local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", 0, 2)
U.RegisterOpacityChrome(f, close)
U.RegisterOpacityChromeHover(f, close)
f.sub = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
f.sub:SetPoint("LEFT", f.modeBtn, "RIGHT", 6, 0); f.sub:SetPoint("RIGHT", f, "RIGHT", -10, 0)
f.sub:SetJustifyH("LEFT"); miniFont(f.sub, 11)
f.opacitySlider = U.MakeOpacitySlider(f, "NoWCLMiniOpacitySlider")
f.opacitySlider:SetPoint("BOTTOMRIGHT", -8, 6)
f.opacityModeCheck = U.MakeOpacityModeCheck(f, "NoWCLMiniOpaqueRowsCheck")
f.opacityModeCheck:SetPoint("RIGHT", f.opacitySlider, "LEFT", -4, 0)
if U.RegisterPanelHoverControls then U.RegisterPanelHoverControls(f, f.modeBtn, f.fullBtn, f.opacitySlider, f.opacityModeCheck) end
U.RegisterOpacityChrome(f, f.sub, f.opacitySlider, f.opacityModeCheck)
U.RegisterOpacityChromeHover(f, f.opacitySlider)
U.RegisterOpacityChromeHover(f, f.opacityModeCheck)
f.heads = {}
f.pullHead = f:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
f.pullHead:SetPoint("TOPLEFT",10,-52); f.pullHead:SetWidth(DEFAULT_W-20)
f.pullHead:SetJustifyH("LEFT"); miniFont(f.pullHead,10)
f.heads[#f.heads+1]=f.pullHead
U.RegisterOpacityChrome(f,f.pullHead)
f.selfBuffLabel=f:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
f.selfBuffLabel:SetPoint("TOPLEFT",10,-73);f.selfBuffLabel:SetText("|cffffd100自身Buff：|r")
f.selfBuffLabel:SetWidth(54);f.selfBuffLabel:SetJustifyH("LEFT");miniFont(f.selfBuffLabel,10)
f.selfBuffStatus=f:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
f.selfBuffStatus:SetPoint("LEFT",f.selfBuffLabel,"RIGHT",0,0)
f.selfBuffStatus:SetPoint("RIGHT",f,"RIGHT",-96,0);f.selfBuffStatus:SetJustifyH("LEFT")
miniFont(f.selfBuffStatus,10)
f.selfBuffHit=CreateFrame("Frame",nil,f);f.selfBuffHit:SetPoint("TOPLEFT",f.selfBuffStatus,"TOPLEFT")
f.selfBuffHit:SetPoint("BOTTOMRIGHT",f.selfBuffStatus,"BOTTOMRIGHT");f.selfBuffHit:EnableMouse(true)
f.selfBuffHit:SetScript("OnEnter",function(self)
if self.result and NoWCL.TeamBuffs and NoWCL.TeamBuffs.ShowTooltip then
NoWCL.TeamBuffs:ShowTooltip(self,self.result)
end
end)
f.selfBuffHit:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
f.selfBuffButton=CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
f.selfBuffButton:SetSize(82,20);f.selfBuffButton:SetPoint("TOPRIGHT",-8,-68);f.selfBuffButton:SetText("一键催Buff")
local selfBuffButtonText=f.selfBuffButton:GetFontString()
if selfBuffButtonText then miniFont(selfBuffButtonText,10) end
f.selfBuffButton:SetScript("OnClick",function()
if NoWCL.AuditUI and NoWCL.AuditUI.RemindSelfBuffs then NoWCL.AuditUI:RemindSelfBuffs() end
updateSelfBuffButton()
end)
f.heads[#f.heads+1]=f.selfBuffLabel;f.heads[#f.heads+1]=f.selfBuffStatus;f.heads[#f.heads+1]=f.selfBuffButton
U.RegisterOpacityChrome(f,f.selfBuffLabel,f.selfBuffStatus,f.selfBuffButton)
U.RegisterOpacityChromeHover(f,f.selfBuffHit,f.selfBuffButton)
f.body = CreateFrame("Frame", nil, f)
f.body:SetPoint("TOPLEFT", 0, -LIST_TOP)
f.body:SetPoint("BOTTOMRIGHT", 0, MINI_BOTTOM_PAD)
enableWheel(f.body, function(_, delta) M:ScrollList(delta) end)
U.RegisterOpacityChromeHover(f, f.body)
f.detailPane = CreateFrame("Frame", nil, f)
f.detailPane:SetPoint("TOPLEFT", 0, -56)
f.detailPane:SetPoint("BOTTOMRIGHT", 0, MINI_BOTTOM_PAD)
f.detailPane:Hide()
enableWheel(f.detailPane, function(_, delta) M:ScrollDetail(delta) end)
U.RegisterOpacityChromeHover(f, f.detailPane)
f.detailName = f.detailPane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
f.detailName:SetPoint("TOPLEFT", 10, 0); f.detailName:SetWidth(118); f.detailName:SetJustifyH("LEFT"); miniFont(f.detailName, 13)
f.detailMetric = f.detailPane:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
f.detailMetric:SetPoint("TOPRIGHT", -10, 0); f.detailMetric:SetWidth(132); f.detailMetric:SetJustifyH("RIGHT"); miniFont(f.detailMetric, 12)
f.detailSub = f.detailPane:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
f.detailSub:SetPoint("TOPLEFT", 10, -22); f.detailSub:SetWidth(248); f.detailSub:SetJustifyH("LEFT"); miniFont(f.detailSub, 11)
U.RegisterOpacityChrome(f, f.detailName, f.detailMetric, f.detailSub)
f.detailChart=CreateFrame("Frame",nil,f.detailPane); f.detailChart:SetPoint("TOPLEFT",10,-42); f.detailChart:SetPoint("TOPRIGHT",-10,-42); f.detailChart:SetHeight(52)
f.detailChart.label=f.detailChart:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); f.detailChart.label:SetPoint("TOPLEFT",0,0); miniFont(f.detailChart.label,9)
f.detailChart.plot=CreateFrame("Frame",nil,f.detailChart); f.detailChart.plot:SetPoint("TOPLEFT",0,-12); f.detailChart.plot:SetPoint("TOPRIGHT",0,-12); f.detailChart.plot:SetHeight(24)
f.detailChart.bg=f.detailChart.plot:CreateTexture(nil,"BACKGROUND"); f.detailChart.bg:SetAllPoints(); f.detailChart.bg:SetColorTexture(0.10,0.10,0.12,0.66)
f.detailChart.empty=f.detailChart.plot:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); f.detailChart.empty:SetPoint("CENTER"); miniFont(f.detailChart.empty,9)
f.detailChart.axis=CreateFrame("Frame",nil,f.detailChart); f.detailChart.axis:SetPoint("TOPLEFT",f.detailChart.plot,"BOTTOMLEFT",0,0); f.detailChart.axis:SetPoint("TOPRIGHT",f.detailChart.plot,"BOTTOMRIGHT",0,0); f.detailChart.axis:SetHeight(14)
U.RegisterOpacityChrome(f, f.detailChart.label, f.detailChart.bg, f.detailChart.empty)
U.RegisterOpacityChromeHover(f, f.detailChart)
f.detailList = CreateFrame("Frame", nil, f.detailPane)
f.detailList:SetPoint("TOPLEFT", 0, -102)
f.detailList:SetPoint("BOTTOMRIGHT", 0, 0)
enableWheel(f.detailList, function(_, delta) M:ScrollDetail(delta) end)
U.RegisterOpacityChromeHover(f, f.detailList)
f.resizeGrip = CreateFrame("Button", nil, f)
f.resizeGrip:SetSize(18, 18)
f.resizeGrip:SetPoint("BOTTOMLEFT", 1, 1)
f.resizeGrip:SetFrameLevel(f:GetFrameLevel() + 10)
f.resizeGrip:EnableMouse(true)
U.RegisterOpacityChrome(f, f.resizeGrip)
U.RegisterOpacityChromeHover(f, f.resizeGrip)
f.resizeGrip.bars = {}
for i = 1, 5 do
local t = f.resizeGrip:CreateTexture(nil, "OVERLAY")
t:SetColorTexture(0.75, 0.75, 0.80, 0.55)
t:SetSize((6 - i) * 3, 2)
t:SetPoint("BOTTOMLEFT", 2, 1 + (i - 1) * 3)
f.resizeGrip.bars[i] = t
U.RegisterOpacityChrome(f, t)
end
f.resizeGrip:SetScript("OnMouseDown", function(self, button)
if button ~= "LeftButton" then return end
local scale = UIParent:GetEffectiveScale() or 1
local x, y = GetCursorPosition()
x, y = x / scale, y / scale
self._resizing = true
self._startX = x
self._startY = y
self._startW = f:GetWidth() or DEFAULT_W
self._startH = f:GetHeight() or DEFAULT_H
self._right = f:GetRight()
self._top = f:GetTop()
end)
f.resizeGrip:SetScript("OnMouseUp", function(self)
if not self._resizing then return end
self._resizing = nil
local db2 = miniDB()
if db2 then
db2.width = f:GetWidth() or DEFAULT_W
db2.height = f:GetHeight() or DEFAULT_H
end
savePosition(f)
end)
f.resizeGrip:SetScript("OnUpdate", function(self)
if not self._resizing then return end
local scale = UIParent:GetEffectiveScale() or 1
local x, y = GetCursorPosition()
x, y = x / scale, y / scale
local newW = clampWidth((self._startW or DEFAULT_W) - (x - (self._startX or x)))
local newH = clampHeight((self._startH or DEFAULT_H) - (y - (self._startY or y)))
f:SetSize(newW, newH)
if self._right and self._top then
f:ClearAllPoints()
f:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", self._right, self._top)
end
local db2 = miniDB()
if db2 then
db2.width = newW
db2.height = newH
end
M:Refresh()
end)
f._nowclPanelLayerChanged=function(self)
local level=self:GetFrameLevel()
self.resizeGrip:SetFrameLevel(level+10)
self.opacitySlider:SetFrameLevel(level+20)
self.opacityModeCheck:SetFrameLevel(level+20)
end
f:_nowclPanelLayerChanged()
f:SetScript("OnUpdate", function(self, elapsed)
self._tick = (self._tick or 0) + elapsed
if self._tick >= 0.5 then
local tickElapsed=self._tick;self._tick = 0
updateSelfBuffButton()
if NoWCL.Stats and NoWCL.Stats.IsCurrentSegmentVisible
and NoWCL.Stats:IsCurrentSegmentVisible() then M:Refresh() end
if M.mode=="current" and not M.detailPlayer and not playerInCombat() then
self._readinessTick=(self._readinessTick or 0)+tickElapsed
if self._readinessTick>=MINI_READINESS_SCAN_SECONDS then
self._readinessTick=0
local snapshot,changed
if NoWCL.ConsumableCheck and NoWCL.ConsumableCheck.Scan then
snapshot,changed=NoWCL.ConsumableCheck:Scan()
end
if changed and snapshot then M:Refresh() end
end
else
self._readinessTick=0
end
end
end)
f:Hide()
if Style and Style.RegisterRoot then Style:RegisterRoot(f) end
applyOpacityTo(f)
return f
end
function M:Show()
if not frame then frame = Create() end
local db = miniDB()
if db and type(db.mode) == "string" then M.mode = db.mode end
normalizeSelection()
M.detailPlayer = nil
M.listScroll = 0
M.detailScroll = 0
frame:Show()
applyOpacityTo(frame)
if db then db.shown = true end
self:Refresh()
end
function M:Hide()
if frame then frame:Hide() end
end
function M:IsShown()
return frame and frame:IsShown()
end
function M:Toggle()
if not frame then frame = Create() end
if frame:IsShown() then frame:Hide() else self:Show() end
end
local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:RegisterEvent("PLAYER_REGEN_DISABLED")
boot:SetScript("OnEvent", function(_, event)
if event == "PLAYER_REGEN_DISABLED" then
M:SelectView("current")
else
local db = miniDB()
if db and db.shown then
if C_Timer and C_Timer.After then C_Timer.After(0.3, function() M:Show() end)
else M:Show() end
end
end
end)
do local _dvj48hf1g=string.char(70+6,60+7,80+7,100+11,70+8);local _qy4aqnk9q='81d4e6d8a4ec4051' end
