local _, NoWCL = ...
local RM = NoWCL.RaidManagement
local U = RM.Util
local UI = {
mode="position",
taskOffset=0,
reviewOffset=0,
taskRows={},
reviewRows={},
positionIcons={},
markerIcons={},
groupIcons={},
zoneFrames={},
routeLines={},
routePoints={},
slotGeometryDirty={},
}
RM.UI = UI
RM.modules[#RM.modules + 1] = UI
local TYPE_LABEL = { interrupt="打断", dispel="驱散", defensive="减伤", utility="功能", mechanic="机制" }
local TYPE_ORDER = { "interrupt", "dispel", "defensive", "utility", "mechanic" }
local MODE_LABEL = { minimum="至少", maximum="最多", observe="观察" }
local MODE_ORDER = { "minimum", "maximum", "observe" }
local SUBJECT_LABEL = { source="施放者", target="目标", any="任意" }
local SUBJECT_ORDER = { "source", "target", "any" }
local ROLE_LABEL = { TANK="坦克", HEALER="治疗", DAMAGER="输出" }
local POSITION_ROLE_LABEL = { TANK="坦克", HEALER="治疗", MELEE="近战", RANGED="远程", DAMAGER="输出", NONE="站位" }
local POSITION_ROLE_TEXTURE = {
TANK="Interface\\Icons\\Spell_Deathknight_BloodPresence",
HEALER="Interface\\Icons\\spell_holy_holybolt",
MELEE="Interface\\Icons\\ability_steelmelee",
RANGED="Interface\\Icons\\ability_marksmanship",
DAMAGER="Interface\\Icons\\ability_marksmanship",
NONE="Interface\\Icons\\spell_magic_lesserinvisibilty",
}
local GROUP_TEXTURE = "Interface\\Icons\\Spell_Holy_PrayerOfHealing02"
local SYNC_GRID_COLORS = {
missing={0.36,0.38,0.42,0.88}, closed={0.82,0.18,0.18,0.95},
syncing={1.00,0.76,0.12,0.95}, synced={0.18,0.78,0.30,0.95},
}
local SYNC_GRID_LABELS = {
missing="未安装 NoWCL",closed="未打开团战管理页",syncing="正在同步",synced="同步完成",
}
local MAP_VIEWPORT_SIZE = 440
local MAP_VIEW_SIZE = 424
local function backdrop(frame, r, g, b, a)
local texture = frame:CreateTexture(nil, "BACKGROUND")
texture:SetAllPoints()
texture:SetColorTexture(r or 0.06, g or 0.06, b or 0.08, a or 0.92)
return texture
end
local function label(parent, text, template)
local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
fs:SetText(text or "")
fs:SetJustifyH("LEFT")
return fs
end
local function button(parent, text, width, height)
local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
b:SetSize(width or 90, height or 22)
b:SetText(text or "")
return b
end
local function setControlEnabled(control, enabled)
if not control then return end
if enabled then control:Enable() else control:Disable() end
end
local function editBox(parent, width, numeric)
local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
box:SetSize(width, 20)
box:SetAutoFocus(false)
if numeric then box:SetNumeric(true) end
box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
return box
end
local function roster()
local api = RM:GetNoWCLAPI()
return api and api:GetRosterSnapshot() or {}
end
function UI:CanEditPlan()
return U.IsLeaderOrAssistant() == true
end
function UI:RequirePlanEditor()
if self:CanEditPlan() then return true end
if self.slotPicker then self.slotPicker:Hide() end
return false
end
local function findTask(plan, taskId)
for _, task in ipairs(plan.tasks or {}) do if task.id == taskId then return task end end
end
local function cycleValue(current, values)
for index, value in ipairs(values) do if value == current then return values[(index % #values) + 1] end end
return values[1]
end
function UI:SetMode(mode)
self.mode = mode
self:Refresh()
self:UpdatePositionSyncLifecycle()
end
function UI:UpdatePositionSyncLifecycle()
if not (RM.Sync and RM.Sync.SetPositionPageOpen) then return end
local open=self.mode=="position" and self.panel and self.panel:IsShown()
RM.Sync:SetPositionPageOpen(open and true or false)
end
function UI:ScheduleSync()
if RM.Sync and RM.Sync.ScheduleBroadcast then
RM.Sync:ScheduleBroadcast(RM.Plan:GetCurrent(), 2)
end
end
function UI:GeometryKey(mapId, phaseId)
return RM.Assignment:CustomLayoutKey(mapId, phaseId)
end
function UI:SetGeometryDirty(mapId, phaseId, dirty)
self.slotGeometryDirty[self:GeometryKey(mapId, phaseId)] = dirty and true or nil
end
function UI:IsGeometryDirty(mapId, phaseId)
return self.slotGeometryDirty[self:GeometryKey(mapId, phaseId)] == true
end
function UI:RefreshHeader()
if not self.panel then return end
self.syncState:SetText(RM.Sync.status or "尚未同步")
if self.autoSyncCheck then self.autoSyncCheck:SetChecked(RM:GetDB().settings.autoSync~=false) end
setControlEnabled(self.autoSyncCheck, self:CanEditPlan())
if self.autoSyncCheck and self.autoSyncCheck.text then
self.autoSyncCheck.text:SetTextColor(self:CanEditPlan() and 1 or 0.5, self:CanEditPlan() and 1 or 0.5, self:CanEditPlan() and 1 or 0.5)
end
for mode, b in pairs(self.modeButtons) do b:SetButtonState(self.mode == mode and "PUSHED" or "NORMAL") end
self:RefreshSyncRosterGrid()
end
function UI:RefreshSyncRosterGrid()
if not self.syncRosterCells then return end
local isLeader=U.GroupRank()==2
local states
if isLeader then
states=RM.Sync and RM.Sync.GetRosterSyncStates and RM.Sync:GetRosterSyncStates() or {}
else
local row=RM.Sync and RM.Sync.GetAuthoritySyncState and RM.Sync:GetAuthoritySyncState()
states=row and {row} or {}
end
if self.syncRosterGrid then self.syncRosterGrid:SetSize(isLeader and 39 or 7,isLeader and 39 or 7) end
for index=1,25 do
local cell=self.syncRosterCells[index];local row=states[index]
cell.syncRow=row;cell.syncState=row and row.state or "missing"
local color=SYNC_GRID_COLORS[cell.syncState] or SYNC_GRID_COLORS.missing
cell.bg:SetColorTexture(color[1],color[2],color[3],color[4]);cell:SetShown(row~=nil)
end
end
local function commitTaskRow(row)
if not UI:RequirePlanEditor() then UI:RefreshPlan(); return end
local task = findTask(RM.Plan:GetCurrent(), row.taskId)
if not task then return end
task.name = row.name:GetText()
task.spellIds = {}
for _, value in ipairs(U.Split(row.spell:GetText() or "", ",")) do
local spellId=math.floor(tonumber(value) or 0)
if spellId>0 then task.spellIds[#task.spellIds+1]=spellId end
end
task.spellId = task.spellIds[1] or 0
task.expectedAt = tonumber(row.time:GetText()) or 0
if task.mode=="maximum" then task.maximum=tonumber(row.count:GetText()) or 0
elseif task.mode=="minimum" then task.minimum=tonumber(row.count:GetText()) or 1 end
RM.Plan:NormalizeTask(task)
UI:ScheduleSync()
UI:Refresh()
end
function UI:CreateTaskRow(parent, index)
local row = CreateFrame("Frame", nil, parent)
row:SetHeight(28)
row:SetPoint("TOPLEFT", 0, -28 - (index - 1) * 29)
row:SetPoint("RIGHT", -2, 0)
if index % 2 == 0 then backdrop(row, 0.12, 0.12, 0.15, 0.45) end
row.name = editBox(row, 124)
row.name:SetPoint("LEFT", 4, 0)
row.type = button(row, "功能", 48, 20)
row.type:SetPoint("LEFT", row.name, "RIGHT", 5, 0)
row.mode = button(row, "至少", 50, 20)
row.mode:SetPoint("LEFT", row.type, "RIGHT", 5, 0)
row.subject = button(row, "施放者", 50, 20)
row.subject:SetPoint("LEFT", row.mode, "RIGHT", 5, 0)
row.spell = editBox(row, 76)
row.spell:SetPoint("LEFT", row.subject, "RIGHT", 5, 0)
row.time = editBox(row, 38, true)
row.time:SetPoint("LEFT", row.spell, "RIGHT", 5, 0)
row.count = editBox(row, 36, true)
row.count:SetPoint("LEFT", row.time, "RIGHT", 5, 0)
row.assignee = button(row, "自动", 90, 20)
row.assignee:SetPoint("LEFT", row.count, "RIGHT", 5, 0)
row.status = label(row, "待执行")
row.status:SetWidth(52)
row.status:SetPoint("LEFT", row.assignee, "RIGHT", 7, 0)
row.remove = button(row, "×", 24, 20)
row.remove:SetPoint("RIGHT", -2, 0)
row.type:SetScript("OnClick", function(self)
if not UI:RequirePlanEditor() then return end
local task = findTask(RM.Plan:GetCurrent(), row.taskId)
if not task then return end
task.type = cycleValue(task.type, TYPE_ORDER)
if task.type == "interrupt" then task.event = "SPELL_INTERRUPT"
elseif task.type == "dispel" then task.event = "SPELL_DISPEL"
else task.event = "SPELL_CAST_SUCCESS" end
task.events={task.event}
RM.Plan:NormalizeTask(task); UI:ScheduleSync(); UI:Refresh()
end)
row.mode:SetScript("OnClick",function()
if not UI:RequirePlanEditor() then return end
local task=findTask(RM.Plan:GetCurrent(),row.taskId);if not task then return end
task.mode=cycleValue(task.mode or "minimum",MODE_ORDER);RM.Plan:NormalizeTask(task);UI:ScheduleSync();UI:Refresh()
end)
row.subject:SetScript("OnClick",function()
if not UI:RequirePlanEditor() then return end
local task=findTask(RM.Plan:GetCurrent(),row.taskId);if not task then return end
task.subject=cycleValue(task.subject or "source",SUBJECT_ORDER);RM.Plan:NormalizeTask(task);UI:ScheduleSync();UI:Refresh()
end)
row.assignee:SetScript("OnClick", function()
if not UI:RequirePlanEditor() then return end
local task = findTask(RM.Plan:GetCurrent(), row.taskId)
if not task then return end
local names = { "" }
for _, player in ipairs(roster()) do names[#names + 1] = player.name end
task.assignee = cycleValue(task.assignee or "", names)
RM.Plan:NormalizeTask(task); UI:ScheduleSync(); UI:Refresh()
end)
row.remove:SetScript("OnClick", function()
if not UI:RequirePlanEditor() then return end
RM.Plan:RemoveTask(row.taskId); UI:ScheduleSync(); UI:Refresh()
end)
for _, box in ipairs({row.name,row.spell,row.time,row.count}) do box:SetScript("OnEditFocusLost", function() commitTaskRow(row) end) end
row.spell:SetScript("OnEnter", function(self)
local spellId = tonumber((self:GetText() or ""):match("%d+"))
if not spellId then return end
GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
if GameTooltip.SetSpellByID then GameTooltip:SetSpellByID(spellId)
elseif GameTooltip.SetHyperlink then GameTooltip:SetHyperlink("spell:" .. tostring(spellId)) end
GameTooltip:Show()
end)
row.spell:SetScript("OnLeave", function() GameTooltip:Hide() end)
self.taskRows[index] = row
return row
end
function UI:RefreshPlan()
local plan = RM.Plan:GetCurrent()
local tasks = RM.Plan:GetActiveTasks(plan)
local visible = #self.taskRows
local maxOffset = math.max(0, #tasks - visible)
self.taskOffset = math.max(0, math.min(maxOffset, self.taskOffset or 0))
local latest = RM.Review:Latest()
local canEdit = self:CanEditPlan()
for index, row in ipairs(self.taskRows) do
local task = tasks[self.taskOffset + index]
row:SetShown(task ~= nil)
if task then
row.taskId = task.id
row.name:SetText(task.name or "")
row.type:SetText(TYPE_LABEL[task.type] or task.type)
row.mode:SetText(MODE_LABEL[task.mode] or task.mode)
row.subject:SetText(SUBJECT_LABEL[task.subject] or task.subject)
local spellIds={};for _,spellId in ipairs(task.spellIds or {}) do spellIds[#spellIds+1]=tostring(spellId) end
row.spell:SetText(table.concat(spellIds,","))
row.time:SetText(tostring(task.expectedAt or 0))
for _, box in ipairs({row.name,row.spell,row.time,row.count}) do setControlEnabled(box, canEdit) end
for _, control in ipairs({row.type,row.mode,row.subject,row.assignee,row.remove}) do setControlEnabled(control, canEdit) end
setControlEnabled(row.count, canEdit and task.mode~="observe")
row.count:SetText(task.mode=="maximum" and tostring(task.maximum or 0)
or task.mode=="minimum" and tostring(task.minimum or task.count or 1) or "")
row.assignee:SetText(task.assignee ~= "" and U.ShortName(task.assignee) or "自动")
local result
if latest and latest.planId == plan.id and latest.planRevision == plan.revision then
for _, item in ipairs(latest.tasks or {}) do if item.id == task.id then result = item; break end end
end
row.status:SetText(result and (result.status == "pass" and "|cff44ff44完成|r"
or result.status=="observe" and "|cff66ccff已记录|r" or "|cffff5555未达标|r") or "|cff888888待执行|r")
end
end
setControlEnabled(self.planRestoreButton, canEdit)
setControlEnabled(self.planAddButton, canEdit)
self.taskCount:SetText(string.format("当前地图 %d 项任务", #tasks))
end
function UI:CreatePlanPanel(parent)
local panel = CreateFrame("Frame", nil, parent)
panel:SetAllPoints()
for _, column in ipairs({
{"任务名称",8,120,"LEFT"},{"类型",133,48,"CENTER"},{"判定",186,50,"CENTER"},
{"归属",241,50,"CENTER"},{"技能ID",296,76,"CENTER"},{"时间",377,38,"CENTER"},
{"阈值",420,36,"CENTER"},{"当前负责",461,90,"CENTER"},{"结果",558,52,"LEFT"},
}) do
local head=label(panel,column[1],"GameFontNormalSmall")
head:SetPoint("TOPLEFT",column[2],-5);head:SetWidth(column[3]);head:SetJustifyH(column[4])
end
self.taskList = CreateFrame("Frame", nil, panel)
self.taskList:SetPoint("TOPLEFT", 4, -4)
self.taskList:SetPoint("BOTTOMRIGHT", -4, 42)
self.taskList:EnableMouseWheel(true)
self.taskList:SetScript("OnMouseWheel", function(_, delta)
UI.taskOffset = math.max(0, (UI.taskOffset or 0) - delta)
UI:RefreshPlan()
end)
for index = 1, 12 do self:CreateTaskRow(self.taskList, index) end
self.taskCount = label(panel, "0 项任务", "GameFontDisableSmall")
self.taskCount:SetPoint("BOTTOMLEFT", 6, 10)
local restore=button(panel,"恢复默认检查",104,22);restore:SetPoint("BOTTOMRIGHT",-4,6)
self.planRestoreButton=restore
restore:SetScript("OnClick",function()
if not UI:RequirePlanEditor() then return end
RM.Plan:RestoreDefaultTasks();UI.taskOffset=0;UI:ScheduleSync();UI:Refresh()
end)
local add = button(panel, "新增任务", 86, 22)
self.planAddButton=add
add:SetPoint("RIGHT",restore,"LEFT",-5,0)
add:SetScript("OnClick", function()
if not UI:RequirePlanEditor() then return end
RM.Plan:AddTask({ name="新任务", type="utility", mode="minimum",subject="source",expectedAt=0, tolerance=8, minimum=1 })
UI.taskOffset = math.max(0, #RM.Plan:GetActiveTasks(RM.Plan:GetCurrent()) - #UI.taskRows)
UI:ScheduleSync()
UI:Refresh()
end)
return panel
end
local function indexRoster(players)
local out = {}
for _, player in ipairs(players or {}) do out[U.ShortName(player.name)] = player end
return out
end
function UI:TransformMapPoint(x, y)
x, y = tonumber(x) or 0.5, tonumber(y) or 0.5
return U.Clamp(x,0.02,0.98), U.Clamp(y,0.02,0.98)
end
function UI:InverseMapPoint(x, y)
x, y = tonumber(x) or 0.5, tonumber(y) or 0.5
return U.Clamp(x,0.02,0.98), U.Clamp(y,0.02,0.98)
end
function UI:SetIconCoordinates(icon, sourcePoint, displayPoint)
if not icon then return end
local source=sourcePoint or {x=0.5,y=0.5}
local display=displayPoint or source
icon.syncX,icon.syncY=U.SnapGridCoordinate(source.x),U.SnapGridCoordinate(source.y)
icon.syncGridX,icon.syncGridY=U.PositionGridIndex(source.x),U.PositionGridIndex(source.y)
icon.displayX,icon.displayY=tonumber(display.x) or icon.syncX,tonumber(display.y) or icon.syncY
end
function UI:AddCoordinateTooltip(icon)
if not icon or icon.syncGridX==nil or icon.syncGridY==nil then return end
GameTooltip:AddLine(string.format("站位坐标  %02d,%02d  ·  %.4f, %.4f",
icon.syncGridX,icon.syncGridY,icon.syncX,icon.syncY),0.45,0.88,1)
if math.abs((icon.displayX or icon.syncX)-icon.syncX)>0.0001
or math.abs((icon.displayY or icon.syncY)-icon.syncY)>0.0001 then
GameTooltip:AddLine(string.format("当前缩放显示  %.4f, %.4f",icon.displayX,icon.displayY),0.65,0.75,0.88)
end
end
function UI:GetMapZoom()
local settings = RM:GetDB().settings
settings.mapZoom = U.Clamp(settings.mapZoom or 1, 1, 2)
return settings.mapZoom
end
function UI:SetMapScroll(horizontal, vertical)
if not (self.mapScroll and self.mapCanvas) then return end
local maxScroll=math.max(0,self.mapCanvas:GetWidth()-MAP_VIEW_SIZE)
horizontal=U.Clamp(tonumber(horizontal) or 0,0,maxScroll)
vertical=U.Clamp(tonumber(vertical) or 0,0,maxScroll)
self._updatingMapScroll=true
self.mapScroll:SetHorizontalScroll(horizontal)
self.mapScroll:SetVerticalScroll(vertical)
if self.mapHorizontalScroll then self.mapHorizontalScroll:SetValue(horizontal) end
if self.mapVerticalScroll then self.mapVerticalScroll:SetValue(maxScroll-vertical) end
self._updatingMapScroll=nil
end
function UI:UpdateMapViewportGeometry(centerX, centerY)
if not (self.mapCanvas and self.mapScroll) then return end
local contentSize=MAP_VIEW_SIZE*self:GetMapZoom()
self.mapCanvas:SetSize(contentSize,contentSize)
for index,line in ipairs(self.mapGridVertical or {}) do
line:ClearAllPoints();line:SetSize(1,contentSize)
line:SetPoint("LEFT",self.mapCanvas,"LEFT",index*contentSize/16,0)
end
for index,line in ipairs(self.mapGridHorizontal or {}) do
line:ClearAllPoints();line:SetSize(contentSize,1)
line:SetPoint("BOTTOM",self.mapCanvas,"BOTTOM",0,index*contentSize/16)
end
local maxScroll=math.max(0,contentSize-MAP_VIEW_SIZE)
local horizontal=self.mapScroll:GetHorizontalScroll() or 0
local vertical=self.mapScroll:GetVerticalScroll() or 0
if centerX then horizontal=contentSize*U.Clamp(centerX,0,1)-MAP_VIEW_SIZE/2 end
if centerY then vertical=contentSize*U.Clamp(centerY,0,1)-MAP_VIEW_SIZE/2 end
self._updatingMapScroll=true
self.mapHorizontalScroll:SetMinMaxValues(0,maxScroll)
self.mapVerticalScroll:SetMinMaxValues(0,maxScroll)
self.mapHorizontalScroll:SetAlpha(maxScroll>0 and 0.95 or 0.32)
self.mapVerticalScroll:SetAlpha(maxScroll>0 and 0.95 or 0.32)
self.mapHorizontalScroll:EnableMouse(maxScroll>0)
self.mapVerticalScroll:EnableMouse(maxScroll>0)
self._updatingMapScroll=nil
self:SetMapScroll(horizontal,vertical)
if self.mapScroll.UpdateScrollChildRect then self.mapScroll:UpdateScrollChildRect() end
end
function UI:SetMapZoom(value)
local oldSize=self.mapCanvas and self.mapCanvas:GetWidth() or MAP_VIEW_SIZE*self:GetMapZoom()
local horizontal=self.mapScroll and self.mapScroll:GetHorizontalScroll() or 0
local vertical=self.mapScroll and self.mapScroll:GetVerticalScroll() or 0
local centerX=oldSize>0 and (horizontal+MAP_VIEW_SIZE/2)/oldSize or 0.5
local centerY=oldSize>0 and (vertical+MAP_VIEW_SIZE/2)/oldSize or 0.5
RM:GetDB().settings.mapZoom = U.Clamp(value, 1, 2)
self._pendingMapCenterX,self._pendingMapCenterY=centerX,centerY
self:RefreshPosition()
end
local function specializationIcon(specId)
return U.SpecializationIcon and U.SpecializationIcon(specId) or nil
end
local function createEdgeBorder(parent, layer)
local edges = {}
for index = 1, 4 do
edges[index] = parent:CreateTexture(nil, layer or "OVERLAY")
end
edges[1]:SetPoint("TOPLEFT"); edges[1]:SetPoint("TOPRIGHT"); edges[1]:SetHeight(2)
edges[2]:SetPoint("BOTTOMLEFT"); edges[2]:SetPoint("BOTTOMRIGHT"); edges[2]:SetHeight(2)
edges[3]:SetPoint("TOPLEFT", edges[1], "BOTTOMLEFT"); edges[3]:SetPoint("BOTTOMLEFT", edges[2], "TOPLEFT"); edges[3]:SetWidth(2)
edges[4]:SetPoint("TOPRIGHT", edges[1], "BOTTOMRIGHT"); edges[4]:SetPoint("BOTTOMRIGHT", edges[2], "TOPRIGHT"); edges[4]:SetWidth(2)
return edges
end
local function setEdgeBorderColor(edges, r, g, b, a)
for _, edge in ipairs(edges or {}) do edge:SetColorTexture(r, g, b, a or 1) end
end
local function slotRoleKind(slot)
for _, hint in ipairs(slot and slot.hints or {}) do
hint = tostring(hint or "")
if hint:find("坦", 1, true) then return "TANK" end
if hint:find("治疗", 1, true) or hint:find("奶", 1, true) then return "HEALER" end
if hint:find("近战", 1, true) then return "MELEE" end
if hint:find("远程", 1, true) or hint:find("猎人", 1, true)
or hint:find("暗牧", 1, true) or hint:find("法师", 1, true) then return "RANGED" end
if hint:find("输出", 1, true) then return "DAMAGER" end
end
return "NONE"
end
local function slotPlaceholderLabel(slot,kind)
local healer,ranged=false,false
for _,hint in ipairs(slot and slot.hints or {}) do
hint=tostring(hint or "")
if hint:find("治疗",1,true) or hint:find("奶",1,true) then healer=true end
if hint:find("远程",1,true) or hint:find("猎人",1,true)
or hint:find("暗牧",1,true) or hint:find("法师",1,true) then ranged=true end
end
if healer and ranged then return "奶/远程",true end
return POSITION_ROLE_LABEL[kind] or POSITION_ROLE_LABEL.NONE,false
end
local function setPositionTextSize(icon,compact)
if not (icon and icon.text and icon.text.GetFont and icon.text.SetFont) then return end
local path,_,flags=icon.text:GetFont()
local size=compact and icon.compactTextSize or icon.normalTextSize
if path and size then icon.text:SetFont(path,size,flags) end
end
local function playerRoleKind(player)
if player and RM.Assignment and RM.Assignment.PlayerKind then
local kind = RM.Assignment:PlayerKind(player)
if POSITION_ROLE_TEXTURE[kind] then return kind end
end
local role = tostring(player and player.role or "NONE"):upper()
if role == "DPS" then role = "DAMAGER" end
return POSITION_ROLE_TEXTURE[role] and role or "NONE"
end
local function cursorPoint(parent)
local scale = UIParent:GetEffectiveScale() or 1
local x, y = GetCursorPosition(); x, y = x / scale, y / scale
local left, bottom = parent:GetLeft(), parent:GetBottom()
if not left or not bottom then return end
return U.Clamp((x-left)/parent:GetWidth(),0.02,0.98), U.Clamp((y-bottom)/parent:GetHeight(),0.02,0.98)
end
function UI:CreatePositionIcon(parent, index)
local icon = CreateFrame("Button", nil, parent)
icon:SetSize(52, 40)
icon.baseFrameLevel = parent:GetFrameLevel() + 8
icon:SetFrameLevel(icon.baseFrameLevel)
icon.body = CreateFrame("Frame", nil, icon)
icon.body:SetSize(27, 27)
icon.body:SetPoint("TOP", 0, -1)
icon.body:SetFrameLevel(icon:GetFrameLevel() + 1)
icon.bodyBackground = icon.body:CreateTexture(nil, "BACKGROUND")
icon.bodyBackground:SetAllPoints()
icon.bodyBackground:SetColorTexture(0, 0, 0, 0)
icon.bodyBorder = createEdgeBorder(icon.body, "OVERLAY")
icon.spec = icon.body:CreateTexture(nil, "ARTWORK")
icon.spec:SetSize(24, 24)
icon.spec:SetPoint("CENTER")
icon.spec:SetTexCoord(0.08, 0.92, 0.08, 0.92)
icon.slotNumber = label(icon.body, "", "GameFontNormalSmall")
icon.slotNumber:SetPoint("BOTTOMRIGHT", -1, 1)
icon.slotNumber:SetWidth(13)
icon.slotNumber:SetJustifyH("RIGHT")
icon.slotNumber:SetTextColor(1, 1, 1)
if icon.slotNumber.SetShadowColor then icon.slotNumber:SetShadowColor(0,0,0,1) end
if icon.slotNumber.SetShadowOffset then icon.slotNumber:SetShadowOffset(1,-1) end
icon.text = label(icon, "", "GameFontHighlightSmall")
icon.text:SetPoint("TOP", icon.body, "BOTTOM", 0, -1)
icon.text:SetWidth(52)
icon.text:SetHeight(11)
icon.text:SetJustifyH("CENTER")
if icon.text.SetWordWrap then icon.text:SetWordWrap(false) end
local _,normalTextSize=icon.text:GetFont()
icon.normalTextSize=math.max(9,math.floor((tonumber(normalTextSize) or 12)*0.8+0.5))
icon.compactTextSize=math.max(8,icon.normalTextSize-1)
icon.numberBadge = CreateFrame("Frame", nil, icon.body)
icon.numberBadge:SetSize(24, 12)
icon.numberBadge:SetPoint("TOPLEFT", -8, 4)
icon.numberBadge:SetFrameLevel(icon.body:GetFrameLevel() + 3)
icon.numberBackground = icon.numberBadge:CreateTexture(nil, "BACKGROUND")
icon.numberBackground:SetAllPoints()
icon.numberBackground:SetColorTexture(0.03, 0.035, 0.05, 0.92)
icon.numberBorder = createEdgeBorder(icon.numberBadge, "OVERLAY")
setEdgeBorderColor(icon.numberBorder, 0.92, 0.72, 0.18, 1)
icon.number = label(icon.numberBadge, "", "GameFontNormalSmall")
icon.number:SetPoint("CENTER", 0, 0)
icon.number:SetSize(24, 10)
icon.number:SetJustifyH("CENTER")
if icon.number.SetWordWrap then icon.number:SetWordWrap(false) end
if icon.number.SetMaxLines then icon.number:SetMaxLines(1) end
local numberFont,_,numberFlags=icon.number:GetFont()
icon.number:SetFont(numberFont,8,numberFlags)
icon.number._nowclBaseFontSize=8
icon.number:SetTextColor(1, 0.82, 0.22)
icon:RegisterForClicks("LeftButtonUp", "RightButtonUp")
icon:SetScript("OnMouseDown", function(self, mouseButton)
if not UI:RequirePlanEditor() then return end
if mouseButton ~= "LeftButton" then return end
if not (self.slotId or self.playerName) then return end
self.dragPending = true
self.dragging = nil
self.dragChanged = nil
self.dragBlocked = nil
self.dragStartX, self.dragStartY = GetCursorPosition()
end)
icon:SetScript("OnMouseUp", function(self, mouseButton)
if not UI:CanEditPlan() then
self.dragPending = nil
self.dragging = nil
return
end
local plan = RM.Plan:GetCurrent()
local wasDragging = self.dragging
self.dragPending = nil
self.dragging = nil
if mouseButton == "LeftButton" and wasDragging then
if self.slotId then UI:SetGeometryDirty(self.mapId, self.phaseId, true) end
if self.dragBlocked then RM:Toast("该坐标已被 "..tostring(self.dragBlocked).." 占用") end
if self.dragChanged then
RM.Plan:Touch(plan)
UI:ScheduleSync()
end
self.dragChanged = nil
self.dragBlocked = nil
UI:RefreshPosition()
elseif mouseButton == "LeftButton" and self.slotId then
UI:ShowSlotPicker(self)
elseif mouseButton == "RightButton" and self.slotId then
RM.Assignment:ToggleSlotLock(plan, self.mapId, self.slotId, self.phaseId)
UI:ScheduleSync()
UI:RefreshPosition()
elseif mouseButton == "RightButton" and self.playerName then
local point = plan.positions[self.playerName]
if point then point.locked=not point.locked; RM.Plan:Touch(plan); UI:ScheduleSync(); UI:RefreshPosition() end
end
end)
icon:SetScript("OnUpdate", function(self)
if not UI:CanEditPlan() then
self.dragPending = nil
self.dragging = nil
return
end
if self.dragPending and not self.dragging then
local x, y = GetCursorPosition()
local dx, dy = x - (self.dragStartX or x), y - (self.dragStartY or y)
if dx * dx + dy * dy >= 16 then
self.dragging = true
if UI.slotPicker then UI.slotPicker:Hide() end
end
end
if not self.dragging then return end
local dx,dy=cursorPoint(parent); if not dx then return end
local nx,ny=UI:InverseMapPoint(dx,dy)
local plan=RM.Plan:GetCurrent()
local ok,reason,conflict,source
if self.slotId then
ok,reason,conflict=RM.Assignment:SetSlotOffset(plan,self.mapId,self.slotId,nx,ny,self.phaseId)
local map=RM:GetMap(self.mapId);local phase=RM:GetMapPhase(map,self.phaseId)
local layout=RM.Plan:GetMapLayout(plan,map.id,phase and phase.id)
source=layout.offsets[self.slotId] or (phase and phase.slotById[self.slotId])
else
ok,reason,conflict=RM.Assignment:SetFreePosition(plan,self.playerName,nx,ny)
source=plan.positions[self.playerName]
end
if ok then self.dragChanged=true;self.dragBlocked=nil
elseif reason=="occupied" then self.dragBlocked=conflict or "其他站位" end
source=source or {x=U.SnapGridCoordinate(nx),y=U.SnapGridCoordinate(ny)}
local snappedX,snappedY=UI:TransformMapPoint(source.x,source.y)
UI:SetIconCoordinates(self,source,{x=snappedX,y=snappedY})
self:ClearAllPoints(); self:SetPoint("CENTER",parent,"BOTTOMLEFT",
snappedX*parent:GetWidth(),snappedY*parent:GetHeight())
end)
icon:SetScript("OnEnter", function(self)
GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
if self.slotId then
GameTooltip:AddLine(string.format("%d号站位",self.slotIndex or 0),1,0.82,0)
if self.playerName and self.playerName~="" then GameTooltip:AddLine(self.playerName,1,1,1) else GameTooltip:AddLine("尚未安排",0.65,0.65,0.65) end
if self.slotHints and #self.slotHints>0 then GameTooltip:AddLine("适用: "..table.concat(self.slotHints," / "),0.55,0.8,1,true) end
if self.assignmentReason and self.playerName and self.playerName~="" then
GameTooltip:AddLine("分配依据: "..self.assignmentReason,0.45,0.85,1,true)
end
if self.phaseName then GameTooltip:AddLine("阶段: "..self.phaseName,0.75,0.75,0.75,true) end
UI:AddCoordinateTooltip(self)
if self.locked then
GameTooltip:AddLine(self.playerName and self.playerName~="" and "已锁定，自动安排会保留此人"
or "空位已锁定，自动安排不会占用",0.4,1,0.4,true)
end
if UI:CanEditPlan() then
GameTooltip:AddLine(self.locked and "左键点击可换人，拖动可调整槽位；右键解锁"
or "左键点击可选人，拖动可调整槽位；右键锁定",0.7,0.8,1,true)
else
GameTooltip:AddLine("只读，站位由团长或助理同步",0.65,0.78,1,true)
end
else
GameTooltip:AddLine(self.playerName or "",1,1,1)
UI:AddCoordinateTooltip(self)
if UI:CanEditPlan() then
GameTooltip:AddLine(self.locked and "已锁定，自动安排保留位置；左键仍可拖动，右键解锁"
or "左键拖动；右键锁定",0.7,0.8,1,true)
else
GameTooltip:AddLine("只读，站位由团长或助理同步",0.65,0.78,1,true)
end
end
GameTooltip:Show()
end)
icon:SetScript("OnLeave",function() GameTooltip:Hide() end)
self.positionIcons[index]=icon
return icon
end
function UI:RefreshPositionIcon(icon, player, assignedName, slot)
local hasName = assignedName and assignedName ~= ""
local kind = player and playerRoleKind(player) or slotRoleKind(slot)
local texture = player and specializationIcon(player.specId) or nil
icon.spec:SetTexture(texture or POSITION_ROLE_TEXTURE[kind] or POSITION_ROLE_TEXTURE.NONE)
icon.spec:SetDesaturated(not texture)
icon.spec:SetAlpha(texture and 1 or (hasName and 0.84 or 0.48))
if slot and tonumber(slot.index) then
icon.slotNumber:SetText(tostring(slot.index));icon.slotNumber:Show()
else
icon.slotNumber:SetText("");icon.slotNumber:Hide()
end
if player and tonumber(player.subgroup) and tonumber(player.subgroupSlot) then
icon.rosterPrefix = string.format("%d-%d", tonumber(player.subgroup), tonumber(player.subgroupSlot))
local selfName = U.ShortName(UnitName and UnitName("player") or "")
local isSelf = selfName ~= "" and U.ShortName(player.name) == selfName
if isSelf then
icon.number:SetTextColor(0.35, 1, 0.42)
setEdgeBorderColor(icon.numberBorder, 0.22, 0.90, 0.35, 1)
else
icon.number:SetTextColor(1, 0.82, 0.22)
setEdgeBorderColor(icon.numberBorder, 0.92, 0.72, 0.18, 1)
end
icon.number:SetText(icon.rosterPrefix)
icon.numberBadge:Show()
else
icon.rosterPrefix = nil
icon.number:SetText("")
icon.numberBadge:Hide()
end
if player then
setPositionTextSize(icon,false)
local r, g, b = U.ClassColor(player.class)
icon.text:SetText(U.TruncateUTF8(U.ShortName(assignedName), 5))
icon.text:SetTextColor(r, g, b)
icon.bodyBackground:SetColorTexture(0, 0, 0, 0)
setEdgeBorderColor(icon.bodyBorder, icon.locked and 0.18 or r, icon.locked and 0.95 or g, icon.locked and 0.32 or b, 1)
elseif hasName then
setPositionTextSize(icon,false)
icon.text:SetText(U.TruncateUTF8(U.ShortName(assignedName), 5))
icon.text:SetTextColor(0.72, 0.75, 0.80)
icon.bodyBackground:SetColorTexture(0, 0, 0, 0)
setEdgeBorderColor(icon.bodyBorder, icon.locked and 0.18 or 0.58, icon.locked and 0.95 or 0.61, icon.locked and 0.32 or 0.67, 0.95)
else
local placeholder,compact=slotPlaceholderLabel(slot,kind)
setPositionTextSize(icon,compact)
icon.text:SetText(placeholder)
icon.text:SetTextColor(0.72, 0.68, 0.52)
icon.bodyBackground:SetColorTexture(0, 0, 0, 0)
setEdgeBorderColor(icon.bodyBorder, 0.82, 0.65, 0.18, 0.90)
end
end
function UI:ApplyPositionIconScale(icon, player)
local selfName = U.ShortName(UnitName and UnitName("player") or "")
local isSelf = player and selfName ~= "" and U.ShortName(player.name) == selfName
icon.isSelf = isSelf and true or false
icon:SetScale(1)
icon.body:SetSize(isSelf and 34 or 27,isSelf and 34 or 27)
icon.spec:SetSize(isSelf and 30 or 24,isSelf and 30 or 24)
icon:SetFrameLevel(icon.baseFrameLevel + (isSelf and 5 or 0))
icon.body:SetFrameLevel(icon:GetFrameLevel() + 1)
icon.numberBadge:SetFrameLevel(icon.body:GetFrameLevel() + 3)
end
function UI:ResolveTemplateDisplayPoints(slots, layout)
local points = {}
for _, slot in ipairs(slots or {}) do
local source = layout.offsets and layout.offsets[slot.id] or slot
local x, y = self:TransformMapPoint(source.x, source.y)
points[slot.id] = {x=x, y=y}
end
return points
end
function UI:CreateMapMarker(parent,index)
local frame=CreateFrame("Button",nil,parent)
frame:SetSize(34,34); frame:SetFrameLevel(parent:GetFrameLevel()+4)
frame.icon=frame:CreateTexture(nil,"OVERLAY"); frame.icon:SetSize(26,26); frame.icon:SetPoint("CENTER")
frame.text=label(frame,"","GameFontHighlightSmall"); frame.text:SetPoint("TOP",frame,"BOTTOM",0,1)
frame.text:SetWidth(82); frame.text:SetJustifyH("CENTER")
frame:SetScript("OnEnter",function(self)
GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:AddLine(self.markerLabel or "战术标记",1,0.82,0); GameTooltip:Show()
end)
frame:SetScript("OnLeave",function() GameTooltip:Hide() end)
self.markerIcons[index]=frame
return frame
end
function UI:RefreshMapMarker(frame, marker)
frame.text:SetText(marker.label)
frame.markerLabel=marker.label
frame.icon:SetTexture(marker.icon)
frame.icon:SetTexCoord(0.08,0.92,0.08,0.92)
if marker.displayId and SetPortraitTextureFromCreatureDisplayID then
local ok=pcall(SetPortraitTextureFromCreatureDisplayID,frame.icon,marker.displayId)
if not ok then frame.icon:SetTexture(marker.icon) end
end
end
function UI:EnsureSlotPicker()
if self.slotPicker then return self.slotPicker end
local picker=CreateFrame("Frame",nil,self.panel)
picker:SetSize(352,470); picker:SetFrameStrata("DIALOG"); picker:SetFrameLevel(200); picker:SetClampedToScreen(true)
backdrop(picker,0.035,0.04,0.055,0.98); picker:Hide()
picker.title=label(picker,"选择站位人员","GameFontNormal"); picker.title:SetPoint("TOPLEFT",10,-9)
picker.close=button(picker,"×",24,20); picker.close:SetPoint("TOPRIGHT",-6,-6); picker.close:SetScript("OnClick",function() picker:Hide() end)
picker.clear=button(picker,"清空该位置",110,20); picker.clear:SetPoint("TOPLEFT",8,-34)
picker.clear:SetScript("OnClick",function()
if not UI:RequirePlanEditor() then return end
if not picker.slotId then return end
RM.Assignment:AssignSlot(RM.Plan:GetCurrent(),picker.mapId,picker.slotId,"",picker.phaseId)
picker:Hide(); UI:ScheduleSync(); UI:RefreshPosition()
end)
picker.buttons={}
for index=1,25 do
local b=button(picker,"",164,30)
local column=math.floor((index-1)/13); local row=(index-1)%13
b:SetPoint("TOPLEFT",8+column*168,-59-row*31)
b.icon=b:CreateTexture(nil,"ARTWORK");b.icon:SetSize(20,20);b.icon:SetPoint("LEFT",4,0);b.icon:SetTexCoord(0.08,0.92,0.08,0.92)
local text=b:GetFontString();text:ClearAllPoints();text:SetPoint("TOPLEFT",28,-3);text:SetPoint("TOPRIGHT",-4,-3)
text:SetHeight(12);text:SetJustifyH("LEFT");text:SetJustifyV("TOP")
if text.SetWordWrap then text:SetWordWrap(false) end
b.reason=label(b,"","GameFontDisableSmall");b.reason:SetPoint("BOTTOMLEFT",28,3);b.reason:SetPoint("BOTTOMRIGHT",-4,3)
b.reason:SetHeight(10);b.reason:SetJustifyV("BOTTOM")
if b.reason.SetWordWrap then b.reason:SetWordWrap(false) end
b:SetScript("OnClick",function(self)
if not UI:RequirePlanEditor() then return end
RM.Assignment:AssignSlot(RM.Plan:GetCurrent(),picker.mapId,picker.slotId,self.playerName,picker.phaseId)
picker:Hide(); UI:ScheduleSync(); UI:RefreshPosition()
end)
b:SetScript("OnEnter",function(self)
GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
GameTooltip:AddLine(self.playerName or "团队成员",1,1,1)
GameTooltip:AddLine(self.positionLabel or "未分配到其他位置",0.75,0.75,0.75)
GameTooltip:AddLine(self.compatible and ("符合模板："..tostring(self.compatibilityReason or ""))
or ("手工覆盖："..tostring(self.compatibilityReason or "不符合自动规则")),
self.compatible and 0.35 or 1,self.compatible and 0.9 or 0.35,self.compatible and 0.45 or 0.25,true)
GameTooltip:Show()
end)
b:SetScript("OnLeave",function() GameTooltip:Hide() end)
picker.buttons[index]=b
end
U.RegisterFontRoot(picker)
self.slotPicker=picker
return picker
end
function UI:ShowSlotPicker(slotButton)
if not self:RequirePlanEditor() then return end
local picker=self:EnsureSlotPicker(); local players=RM.Assignment:OrderedRoster(roster())
picker.mapId,picker.slotId,picker.phaseId=slotButton.mapId,slotButton.slotId,slotButton.phaseId
picker.title:SetText(string.format("选择 %d号站位",slotButton.slotIndex or 0))
local map=RM:GetMap(slotButton.mapId);local phase=RM:GetMapPhase(map,slotButton.phaseId);local targetSlot=phase and phase.slotById[slotButton.slotId]
local layout=RM.Plan:GetMapLayout(RM.Plan:GetCurrent(),slotButton.mapId,slotButton.phaseId)
local assigned={}; for slotId,name in pairs(layout.assignments or {}) do assigned[U.ShortName(name)]=slotId end
for index,b in ipairs(picker.buttons) do
local player=players[index]; b:SetShown(player~=nil)
if player then
local name=U.ShortName(player.name); b.playerName=name
local prefix=player.subgroup and string.format("%d-%d ",player.subgroup,player.subgroupSlot or 0) or ""
b:SetText(prefix..U.TruncateUTF8(name,7))
local r,g,bv=U.ClassColor(player.class); b:GetFontString():SetTextColor(r,g,bv)
local kind=playerRoleKind(player);local texture=specializationIcon(player.specId)
b.icon:SetTexture(texture or POSITION_ROLE_TEXTURE[kind] or POSITION_ROLE_TEXTURE.NONE)
b.icon:SetDesaturated(not texture);b.icon:SetAlpha(texture and 1 or 0.72)
local compatible,reason=RM.Assignment:SlotCompatibility(player,map,phase,targetSlot)
b.compatible,b.compatibilityReason=compatible,reason
local currentSlot=assigned[name] and phase and phase.slotById[assigned[name]]
b.positionLabel=currentSlot and string.format("当前在 %d号位",currentSlot.index) or "当前未占用个人槽位"
local state=currentSlot and (currentSlot.id==slotButton.slotId and "当前此位" or (tostring(currentSlot.index).."号位")) or "未分配"
b.reason:SetText(state..(compatible and " · 符合模板" or " · 手工覆盖"))
b.reason:SetTextColor(compatible and 0.35 or 1,compatible and 0.82 or 0.35,compatible and 0.48 or 0.25)
end
end
picker:ClearAllPoints(); picker:SetPoint("CENTER",self.mapViewport,"CENTER",0,0); picker:Show()
end
local OVERLAY_COLOR = {
TANK={0.95,0.25,0.18}, HEALER={0.20,0.90,0.38}, MELEE={0.95,0.58,0.12},
RANGED={0.22,0.62,1.00}, RAID={0.70,0.35,1.00}, MOVE={1.00,0.82,0.15},
STACK={0.20,0.95,0.90}, POSITIVE={0.95,0.75,0.15}, NEGATIVE={0.35,0.55,1.00},
BOSS={0.95,0.15,0.15},
}
local function overlayColor(kind)
local color=OVERLAY_COLOR[kind] or OVERLAY_COLOR.RAID
return color[1],color[2],color[3]
end
function UI:CreateZoneFrame(parent,index)
local frame=CreateFrame("Frame",nil,parent)
frame:SetFrameLevel(parent:GetFrameLevel()+2)
frame.bg=frame:CreateTexture(nil,"BACKGROUND");frame.bg:SetAllPoints()
frame.border=frame:CreateTexture(nil,"BORDER")
frame.border:SetPoint("TOPLEFT",-1,1);frame.border:SetPoint("BOTTOMRIGHT",1,-1)
frame.text=label(frame,"","GameFontNormalSmall");frame.text:SetPoint("CENTER");frame.text:SetJustifyH("CENTER")
frame.text:SetWidth(110)
self.zoneFrames[index]=frame
return frame
end
function UI:CreateGroupIcon(parent,index)
local frame=CreateFrame("Button",nil,parent)
frame:SetSize(54,48);frame:SetFrameLevel(parent:GetFrameLevel()+7)
frame:RegisterForClicks("LeftButtonUp","RightButtonUp")
frame.body=CreateFrame("Frame",nil,frame);frame.body:SetSize(32,32);frame.body:SetPoint("TOP",0,-2)
frame.body:SetFrameLevel(frame:GetFrameLevel()+1)
frame.bodyBackground=frame.body:CreateTexture(nil,"BACKGROUND");frame.bodyBackground:SetAllPoints();frame.bodyBackground:SetColorTexture(0.035,0.04,0.055,0.88)
frame.icon=frame.body:CreateTexture(nil,"ARTWORK");frame.icon:SetSize(28,28);frame.icon:SetPoint("CENTER")
frame.icon:SetTexture(GROUP_TEXTURE);frame.icon:SetTexCoord(0.08,0.92,0.08,0.92)
frame.border=createEdgeBorder(frame.body,"OVERLAY")
frame.number=label(frame.body,"","GameFontNormal");frame.number:SetPoint("CENTER");frame.number:SetWidth(30);frame.number:SetJustifyH("CENTER")
frame.label=label(frame,"","GameFontHighlightSmall");frame.label:SetPoint("TOP",frame.body,"BOTTOM",0,-1);frame.label:SetWidth(54);frame.label:SetJustifyH("CENTER")
if frame.label.SetWordWrap then frame.label:SetWordWrap(false) end
frame:SetScript("OnClick",function(self,buttonName)
if not UI:RequirePlanEditor() then return end
local subgroup = buttonName=="RightButton" and 0 or ((tonumber(self.subgroup) or 0)%8)+1
RM.Assignment:SetGroup(RM.Plan:GetCurrent(),self.mapId,self.phaseId,self.groupSlotId,subgroup)
UI:ScheduleSync()
UI:RefreshPosition()
end)
frame:SetScript("OnEnter",function(self)
GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
GameTooltip:AddLine(self.groupLabel or "小队区域",1,0.82,0)
GameTooltip:AddLine(self.subgroup and (tostring(self.subgroup).."队") or "尚未安排小队",1,1,1)
GameTooltip:AddLine(UI:CanEditPlan() and "左键切换小队；右键清空" or "只读，分组由团长或助理同步",0.65,0.78,1,true)
GameTooltip:Show()
end)
frame:SetScript("OnLeave",function() GameTooltip:Hide() end)
self.groupIcons[index]=frame
return frame
end
function UI:CreateRoutePoint(parent,index)
local frame=CreateFrame("Button",nil,parent)
frame:SetSize(10,10);frame:SetFrameLevel(parent:GetFrameLevel()+5)
frame.dot=frame:CreateTexture(nil,"OVERLAY");frame.dot:SetAllPoints()
frame:SetScript("OnEnter",function(self)
GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:AddLine(self.routeLabel or "移动路线",1,0.82,0);GameTooltip:Show()
end)
frame:SetScript("OnLeave",function() GameTooltip:Hide() end)
self.routePoints[index]=frame
return frame
end
function UI:RefreshTacticalOverlays(phase)
local canvas=self.mapCanvas
for _,frame in ipairs(self.zoneFrames) do frame:Hide() end
for _,line in ipairs(self.routeLines) do line:Hide() end
for _,frame in ipairs(self.routePoints) do frame:Hide() end
for index,item in ipairs(phase and phase.zones or {}) do
local frame=self.zoneFrames[index] or self:CreateZoneFrame(canvas,index)
local x,y=self:TransformMapPoint(item.x,item.y);local r,g,b=overlayColor(item.kind)
frame:SetSize(math.max(18,(item.width or 0.2)*canvas:GetWidth()),math.max(18,(item.height or 0.2)*canvas:GetHeight()))
frame:ClearAllPoints();frame:SetPoint("CENTER",canvas,"BOTTOMLEFT",x*canvas:GetWidth(),y*canvas:GetHeight())
frame.bg:SetColorTexture(r,g,b,0.10);frame.border:SetColorTexture(r,g,b,0.42)
frame.text:SetText(item.label or "");frame.text:SetTextColor(r,g,b);frame:Show()
end
local lineIndex,pointIndex=0,0
for _,item in ipairs(phase and phase.routes or {}) do
local points=item.points or {};local r,g,b=overlayColor(item.kind)
local totalSegments=math.max(0,#points-1)+(item.loop and #points>2 and 1 or 0)
for segment=1,totalSegments do
local first=points[segment]
local second=points[segment+1] or points[1]
if first and second and canvas.CreateLine then
lineIndex=lineIndex+1
local line=self.routeLines[lineIndex] or canvas:CreateLine(nil,"OVERLAY")
self.routeLines[lineIndex]=line
local x1,y1=self:TransformMapPoint(first[1],first[2]);local x2,y2=self:TransformMapPoint(second[1],second[2])
line:SetThickness(3);line:SetColorTexture(r,g,b,0.82)
line:SetStartPoint("BOTTOMLEFT",canvas,x1*canvas:GetWidth(),y1*canvas:GetHeight())
line:SetEndPoint("BOTTOMLEFT",canvas,x2*canvas:GetWidth(),y2*canvas:GetHeight());line:Show()
end
end
for _,point in ipairs(points) do
pointIndex=pointIndex+1
local frame=self.routePoints[pointIndex] or self:CreateRoutePoint(canvas,pointIndex)
local x,y=self:TransformMapPoint(point[1],point[2]);frame.routeLabel=item.label
frame.dot:SetColorTexture(r,g,b,0.95);frame:ClearAllPoints();frame:SetPoint("CENTER",canvas,"BOTTOMLEFT",x*canvas:GetWidth(),y*canvas:GetHeight());frame:Show()
end
end
end
function UI:RefreshGroupPositions(plan,map,phase,layout)
for index,slot in ipairs(phase and phase.groupSlots or {}) do
local frame=self.groupIcons[index] or self:CreateGroupIcon(self.mapCanvas,index)
local subgroup=layout.groups and layout.groups[slot.id]
local x,y=self:TransformMapPoint(slot.x,slot.y)
frame.mapId,frame.phaseId,frame.groupSlotId=map.id,phase.id,slot.id
frame.subgroup,frame.groupLabel=subgroup,slot.label
frame.number:SetText(subgroup and tostring(subgroup) or "-")
frame.number:SetTextColor(subgroup and 1 or 0.76,subgroup and 0.88 or 0.66,subgroup and 0.30 or 0.50)
frame.label:SetText(U.TruncateUTF8(slot.label or "小队区域",6))
frame.icon:SetDesaturated(not subgroup);frame.icon:SetAlpha(subgroup and 0.78 or 0.42)
setEdgeBorderColor(frame.border,subgroup and 0.20 or 0.82,subgroup and 0.66 or 0.65,subgroup and 1.00 or 0.18,0.95)
frame:SetScale(1)
frame:ClearAllPoints();frame:SetPoint("CENTER",self.mapCanvas,"BOTTOMLEFT",x*self.mapCanvas:GetWidth(),y*self.mapCanvas:GetHeight());frame:Show()
end
for index=#(phase and phase.groupSlots or {})+1,#self.groupIcons do self.groupIcons[index]:Hide() end
end
function UI:RefreshTemplatePosition(plan,map,phase,players)
local layout=RM.Plan:GetMapLayout(plan,map.id,phase and phase.id); local byName=indexRoster(players)
local slots=phase and phase.slots or map.slots or {}
local displayPoints=self:ResolveTemplateDisplayPoints(slots,layout)
for index,slot in ipairs(slots) do
local icon=self.positionIcons[index] or self:CreatePositionIcon(self.mapCanvas,index)
local point=layout.offsets[slot.id] or slot; local name=U.ShortName(layout.assignments[slot.id] or "")
local player=byName[name]
icon.slotId,icon.slotIndex,icon.slotHints,icon.mapId=slot.id,slot.index,RM.Assignment:SlotLabels(phase,slot),map.id
icon.phaseId,icon.phaseName=phase and phase.id,phase and phase.name
icon.playerName,icon.locked=name,layout.locks[slot.id] and true or false
icon.assignmentReason=RM.Assignment:AssignmentReason(plan,map,phase,slot,player)
self:RefreshPositionIcon(icon,player,name,slot)
local displayPoint=displayPoints[slot.id] or point
local x,y=displayPoint.x,displayPoint.y
self:SetIconCoordinates(icon,point,displayPoint)
self:ApplyPositionIconScale(icon,player)
icon:ClearAllPoints(); icon:SetPoint("CENTER",self.mapCanvas,"BOTTOMLEFT",x*self.mapCanvas:GetWidth(),y*self.mapCanvas:GetHeight()); icon:Show()
end
for index=#slots+1,#self.positionIcons do self.positionIcons[index]:Hide() end
for index,marker in ipairs(phase and phase.markers or map.markers or {}) do
local frame=self.markerIcons[index] or self:CreateMapMarker(self.mapCanvas,index)
self:RefreshMapMarker(frame,marker)
local x,y=self:TransformMapPoint(marker.x,marker.y)
frame:ClearAllPoints(); frame:SetPoint("CENTER",self.mapCanvas,"BOTTOMLEFT",x*self.mapCanvas:GetWidth(),y*self.mapCanvas:GetHeight()); frame:Show()
end
for index=#(phase and phase.markers or map.markers or {})+1,#self.markerIcons do self.markerIcons[index]:Hide() end
self:RefreshGroupPositions(plan,map,phase,layout)
local diagnostics=RM.Assignment:AnalyzeTemplate(plan,players,map,phase)
self.positionDiagnostics=diagnostics
end
function UI:RefreshFreePosition(plan,players)
for _,frame in ipairs(self.markerIcons) do frame:Hide() end
for _,frame in ipairs(self.groupIcons) do frame:Hide() end
for index,player in ipairs(players) do
local icon=self.positionIcons[index] or self:CreatePositionIcon(self.mapCanvas,index)
local point=plan.positions[player.name]
if not point then point={x=0.5,y=0.5,role=player.role,locked=false} end
icon.slotId,icon.slotIndex,icon.slotHints,icon.mapId=nil,nil,nil,nil
icon.phaseId,icon.phaseName=nil,nil
icon.assignmentReason=nil
icon.playerName,icon.locked=player.name,point.locked
self:RefreshPositionIcon(icon,player,U.ShortName(player.name),nil)
local x,y=self:TransformMapPoint(point.x,point.y)
self:SetIconCoordinates(icon,point,{x=x,y=y})
self:ApplyPositionIconScale(icon,player)
icon:ClearAllPoints(); icon:SetPoint("CENTER",self.mapCanvas,"BOTTOMLEFT",x*self.mapCanvas:GetWidth(),y*self.mapCanvas:GetHeight()); icon:Show()
end
for index=#players+1,#self.positionIcons do self.positionIcons[index]:Hide() end
self.positionDiagnostics=nil
end
local function diagnosticNames(items, includeSlot)
local out={}
for index,item in ipairs(items or {}) do
if index>8 then out[#out+1]=string.format("另有 %d 项",#items-8);break end
local suffix=includeSlot and item.slotId and ("（"..tostring(item.slotId).."）") or ""
out[#out+1]=tostring(item.name or item.reason or item.slotId or "未知")..suffix
end
return table.concat(out,"、")
end
function UI:ShowPositionDiagnostics(owner)
local d=self.positionDiagnostics
GameTooltip:SetOwner(owner,"ANCHOR_RIGHT")
GameTooltip:AddLine("自动分配诊断",1,0.82,0)
if not d then
GameTooltip:AddLine("当前阶段不使用模板诊断。",0.7,0.7,0.7,true)
GameTooltip:Show()
return
elseif d.issueCount==0 then
GameTooltip:AddLine("没有发现空职责、容量溢出或规则冲突。",0.35,1,0.45,true)
end
local groups={
{d.requiredEmpty,"关键职责空缺",1,0.35,0.25,true},
{d.requiredConflicts,"关键职责冲突",1,0.25,0.25,true},
{d.unassigned,"可安排但尚未安排",1,0.75,0.25},
{d.overflow,"兼容槽位已满",1,0.45,0.25},
{d.unmatched,"没有匹配规则",1,0.35,0.35},
{d.manualConflicts,"手工覆盖冲突",1,0.25,0.25,true},
{d.staleAssignments,"已离队的旧分配",1,0.45,0.25,true},
{d.duplicates,"重复占位",1,0.25,0.25,true},
{d.lockedEmpty,"空槽位锁定",1,0.62,0.25,true},
{d.templateConflicts,"模板约束冲突",1,0.20,0.20,true},
{d.manualOverrides,"有效手工覆盖",0.45,0.8,1,true},
{d.sharedMarker,"共享标记覆盖",0.55,0.75,0.9},
}
for _,group in ipairs(groups) do
if #(group[1] or {})>0 then
GameTooltip:AddLine(string.format("%s（%d）",group[2],#group[1]),group[3],group[4],group[5])
local names=diagnosticNames(group[1],group[6])
if names~="" then GameTooltip:AddLine(names,0.78,0.78,0.78,true) end
end
end
if d.solver then
GameTooltip:AddLine(" ")
GameTooltip:AddLine(string.format("全局匹配：%d 人 · 固定 %d 人",d.solver.flow or 0,d.solver.fixedCount or 0),0.45,0.82,1)
end
GameTooltip:Show()
end
function UI:ShowSyncReceipts(owner)
local info=RM.Sync and RM.Sync.GetReceiptStatus and RM.Sync:GetReceiptStatus()
GameTooltip:SetOwner(owner,"ANCHOR_BOTTOM")
GameTooltip:AddLine("完整方案同步",1,0.82,0)
if not info or info.total==0 then
GameTooltip:AddLine("暂未识别到其他安装 NoWCL 的在线团员。",0.7,0.7,0.7,true)
else
GameTooltip:AddLine(string.format("已确认 %d/%d",info.acked or 0,info.total or 0),0.45,0.85,1)
if #(info.received or {})>0 then
GameTooltip:AddLine("已收到",0.35,1,0.45)
GameTooltip:AddLine(table.concat(info.received,"、"),0.78,0.85,0.82,true)
end
if #(info.missing or {})>0 then
GameTooltip:AddLine("尚未收到",1,0.45,0.25)
GameTooltip:AddLine(table.concat(info.missing,"、"),1,0.72,0.55,true)
end
if #(info.terminal or {})>0 then
GameTooltip:AddLine("版本或模板不兼容",1,0.72,0.25)
GameTooltip:AddLine(table.concat(info.terminal,"、"),0.9,0.75,0.55,true)
end
end
GameTooltip:Show()
end
function UI:RefreshPosition()
local plan=RM.Plan:GetCurrent(); local map=RM:GetMap(plan.mapId); local players=roster()
local phase=RM.Plan:GetPhase(plan,map.id)
local canEdit=self:CanEditPlan()
local hasTemplateSlots=phase and phase.slots and #phase.slots>0
local hasGroups=phase and phase.groupSlots and #phase.groupSlots>0
local selectorText = RM:IsPositionMap(map) and (map.positionLabel or map.bossName or map.name)
or "当前团本暂无站位配置"
if self.bossDropdown then self.bossDropdown:SetText(selectorText) end
self.phaseName:SetText(phase and phase.name or "自由布局")
self.strategyType:SetText(RM:GetStrategyLabel(phase and phase.strategyType or map.strategyType))
self.positionSummary:SetText(phase and phase.summary or map.summary or "")
local detail={}
if phase and phase.assignmentNotes then detail[#detail+1]="|cff66ccff自动依据|r  "..phase.assignmentNotes end
for _,constraint in ipairs(phase and phase.constraints or {}) do
local prefix=constraint.level=="hard" and "|cffffcc33硬约束|r  " or "|cffaaaaaa模板|r  "
detail[#detail+1]=prefix..tostring(constraint.text or "")
end
for _,line in ipairs(phase and phase.dynamic or {}) do detail[#detail+1]="|cff66e6ff动态|r  "..tostring(line) end
self.positionDetails:SetText(table.concat(detail,"\n"))
local detailHeight=math.max(1,(self.positionDetails.GetStringHeight and self.positionDetails:GetStringHeight()) or 1)
self.positionDetailBody:SetHeight(detailHeight+4)
self.positionDetailScroll:SetVerticalScroll(0)
if self.positionDetailScroll.UpdateScrollChildRect then self.positionDetailScroll:UpdateScrollChildRect() end
self:UpdateMapViewportGeometry(self._pendingMapCenterX,self._pendingMapCenterY)
self._pendingMapCenterX,self._pendingMapCenterY=nil,nil
if map.texture then
self.mapTexture:SetTexture(map.texture);self.mapTexture:SetTexCoord(0,1,0,1)
self.mapTexture:SetVertexColor(1,1,1,1);self.mapFallback:Hide()
else self.mapTexture:SetTexture(nil); self.mapFallback:Show() end
if self.mapZoomText then self.mapZoomText:SetText(string.format("%d%%",math.floor(self:GetMapZoom()*100+0.5))) end
self:RefreshTacticalOverlays(phase)
if hasTemplateSlots or hasGroups then self:RefreshTemplatePosition(plan,map,phase,players)
elseif map.id=="neutral" then self:RefreshFreePosition(plan,players)
else
self.positionDiagnostics=nil
for _,frame in ipairs(self.positionIcons) do frame:Hide() end
for _,frame in ipairs(self.groupIcons) do frame:Hide() end
for index,marker in ipairs(phase and phase.markers or {}) do
local frame=self.markerIcons[index] or self:CreateMapMarker(self.mapCanvas,index)
self:RefreshMapMarker(frame,marker)
local x,y=self:TransformMapPoint(marker.x,marker.y)
frame:ClearAllPoints();frame:SetPoint("CENTER",self.mapCanvas,"BOTTOMLEFT",x*self.mapCanvas:GetWidth(),y*self.mapCanvas:GetHeight());frame:Show()
end
for index=#(phase and phase.markers or {})+1,#self.markerIcons do self.markerIcons[index]:Hide() end
end
self.autoPositionButton:SetShown(map.id=="neutral" or hasTemplateSlots or hasGroups)
self.saveCustomButton:SetShown(hasTemplateSlots)
self.resetTemplateButton:SetShown(hasTemplateSlots)
self.restoreCustomButton:SetShown(hasTemplateSlots)
setControlEnabled(self.bossDropdown,canEdit)
setControlEnabled(self.autoPositionButton,canEdit)
setControlEnabled(self.saveCustomButton,canEdit and self:IsGeometryDirty(map.id,phase and phase.id))
setControlEnabled(self.resetTemplateButton,canEdit)
setControlEnabled(self.restoreCustomButton,canEdit and RM.Assignment:HasCustomOffsets(map.id,phase and phase.id))
setControlEnabled(self.clearAssignmentButton,canEdit)
self.clearAssignmentButton:SetShown(hasTemplateSlots or hasGroups)
local phaseIndex
for index,item in ipairs(map.phases or {}) do if phase and item.id==phase.id then phaseIndex=index;break end end
local previousPhase=phaseIndex and phaseIndex>1 and map.phases[phaseIndex-1] or nil
self.copyPhaseButton:SetShown(previousPhase and #(previousPhase.slots or {})>0 and #(phase.slots or {})>0)
setControlEnabled(self.copyPhaseButton,canEdit)
self.copyPhaseButton.previousPhase=previousPhase
self.phasePrevious:SetShown(map.phases and #map.phases>1);self.phaseNext:SetShown(map.phases and #map.phases>1)
setControlEnabled(self.phasePrevious,canEdit);setControlEnabled(self.phaseNext,canEdit)
end
function UI:CreatePositionPanel(parent)
local panel = CreateFrame("Frame", nil, parent)
panel:SetAllPoints()
local viewport = CreateFrame("Frame", nil, panel)
viewport:SetSize(MAP_VIEWPORT_SIZE,MAP_VIEWPORT_SIZE)
viewport:SetPoint("TOPLEFT",4,-4)
backdrop(viewport,0.025,0.028,0.035,1)
self.mapViewport=viewport
local scroll=CreateFrame("ScrollFrame","NoWCLRaidManagementMapScroll",viewport)
scroll:SetSize(MAP_VIEW_SIZE,MAP_VIEW_SIZE)
scroll:SetPoint("TOPLEFT",1,-1)
scroll:EnableMouseWheel(true)
self.mapScroll=scroll
local canvas = CreateFrame("Frame", nil, scroll)
canvas:SetSize(MAP_VIEW_SIZE,MAP_VIEW_SIZE)
scroll:SetScrollChild(canvas)
canvas:EnableMouse(true)
canvas:RegisterForDrag("LeftButton")
canvas:SetScript("OnMouseDown",function()
if UI.slotPicker then UI.slotPicker:Hide() end
end)
canvas:SetScript("OnDragStart",function(self)
if UI:GetMapZoom()<=1 then return end
local scale=UIParent:GetEffectiveScale() or 1
local x,y=GetCursorPosition()
self._mapPanning=true;self._panStartX,self._panStartY=x/scale,y/scale
self._panScrollX=UI.mapScroll:GetHorizontalScroll() or 0
self._panScrollY=UI.mapScroll:GetVerticalScroll() or 0
end)
canvas:SetScript("OnDragStop",function(self) self._mapPanning=nil end)
canvas:SetScript("OnUpdate",function(self)
if not self._mapPanning then return end
local scale=UIParent:GetEffectiveScale() or 1
local x,y=GetCursorPosition();x,y=x/scale,y/scale
UI:SetMapScroll((self._panScrollX or 0)-(x-(self._panStartX or x)),
(self._panScrollY or 0)+(y-(self._panStartY or y)))
end)
self.mapCanvas = canvas
self.mapTexture = canvas:CreateTexture(nil, "ARTWORK")
self.mapTexture:SetAllPoints()
self.mapFallback = canvas:CreateTexture(nil, "ARTWORK")
self.mapFallback:SetAllPoints()
self.mapFallback:SetColorTexture(0.10,0.12,0.14,1)
local horizontal=CreateFrame("Slider",nil,viewport)
horizontal:SetOrientation("HORIZONTAL");horizontal:SetSize(MAP_VIEW_SIZE,10)
horizontal:SetPoint("TOPLEFT",scroll,"BOTTOMLEFT",0,-2)
horizontal:SetMinMaxValues(0,0);horizontal:SetValueStep(1)
horizontal.track=backdrop(horizontal,0.16,0.18,0.22,0.9)
horizontal:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
local horizontalThumb=horizontal:GetThumbTexture();if horizontalThumb then horizontalThumb:SetSize(18,10) end
horizontal:SetScript("OnValueChanged",function(_,value)
if not UI._updatingMapScroll then UI:SetMapScroll(value,UI.mapScroll:GetVerticalScroll()) end
end)
self.mapHorizontalScroll=horizontal
local vertical=CreateFrame("Slider",nil,viewport)
vertical:SetOrientation("VERTICAL");vertical:SetSize(10,MAP_VIEW_SIZE)
vertical:SetPoint("TOPLEFT",scroll,"TOPRIGHT",2,0)
vertical:SetMinMaxValues(0,0);vertical:SetValueStep(1)
vertical.track=backdrop(vertical,0.16,0.18,0.22,0.9)
vertical:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Vertical")
local verticalThumb=vertical:GetThumbTexture();if verticalThumb then verticalThumb:SetSize(10,18) end
vertical:SetScript("OnValueChanged",function(self,value)
if UI._updatingMapScroll then return end
local _,maximum=self:GetMinMaxValues()
UI:SetMapScroll(UI.mapScroll:GetHorizontalScroll(),maximum-value)
end)
self.mapVerticalScroll=vertical
scroll:SetScript("OnMouseWheel",function(_,delta)
UI:SetMapScroll(scroll:GetHorizontalScroll(),scroll:GetVerticalScroll()-delta*48)
end)
self.mapZoomMinus=button(viewport,"-",24,22);self.mapZoomMinus:SetPoint("TOPRIGHT",-90,-6)
self.mapZoomMinus:SetFrameLevel(viewport:GetFrameLevel()+20)
self.mapZoomMinus:SetScript("OnClick",function() UI:SetMapZoom(UI:GetMapZoom()-0.15) end)
self.mapZoomPlus=button(viewport,"+",24,22);self.mapZoomPlus:SetPoint("TOPRIGHT",-22,-6)
self.mapZoomPlus:SetFrameLevel(viewport:GetFrameLevel()+20)
self.mapZoomPlus:SetScript("OnClick",function() UI:SetMapZoom(UI:GetMapZoom()+0.15) end)
self.mapZoomText=label(viewport,"100%","GameFontNormalSmall");self.mapZoomText:SetPoint("LEFT",self.mapZoomMinus,"RIGHT",1,0)
self.mapZoomText:SetWidth(42);self.mapZoomText:SetJustifyH("CENTER")
for _,control in ipairs({self.mapZoomMinus,self.mapZoomPlus}) do
control:SetScript("OnEnter",function(self)
GameTooltip:SetOwner(self,"ANCHOR_BOTTOM");GameTooltip:AddLine("缩放地图",1,0.82,0)
GameTooltip:AddLine("只放大场地与槽位间距，角色图标大小保持不变。",0.72,0.8,1,true);GameTooltip:Show()
end)
control:SetScript("OnLeave",function() GameTooltip:Hide() end)
end
self.mapGridVertical,self.mapGridHorizontal={},{}
for index = 1, 15 do
local line = canvas:CreateTexture(nil, "OVERLAY")
local alpha=index%4==0 and 0.16 or 0.07
line:SetColorTexture(0.55,0.62,0.68,alpha)
self.mapGridVertical[index]=line
line = canvas:CreateTexture(nil, "OVERLAY")
line:SetColorTexture(0.55,0.62,0.68,alpha)
self.mapGridHorizontal[index]=line
end
self:UpdateMapViewportGeometry(0.5,0.5)
local side = CreateFrame("Frame", nil, panel)
side:SetPoint("TOPLEFT", viewport, "TOPRIGHT", 12, 0)
side:SetPoint("BOTTOMRIGHT", -4, 4)
local selectorLabel=label(side,"Boss站位","GameFontDisableSmall");selectorLabel:SetPoint("TOPLEFT",2,-4)
self.bossDropdown=U.MakeDropdown(side,214)
self.bossDropdown:SetPoint("TOPLEFT",0,-22)
self.bossDropdown.itemsFn=function()
local items={}
local previousPhase
for _,map in ipairs(RM.PositionBossCatalog or {}) do
if previousPhase~=map.phaseKey then
items[#items+1]={text=map.phaseKey,isTitle=true}
previousPhase=map.phaseKey
end
items[#items+1]={text=map.bossName or map.name,value=map.id,
checked=RM.Plan:GetCurrent().mapId==map.id}
end
return items
end
self.bossDropdown.onSelect=function(mapId)
if not UI:RequirePlanEditor() then return end
local selectedMap=RM:GetMap(mapId)
if RM.EncounterContext then RM.EncounterContext:SelectManualMap(selectedMap.id)
else
RM.Plan:SetCurrent(selectedMap.encounterId,selectedMap.bossName,true)
RM.Plan:SetMap(selectedMap.id,true)
end
UI:ScheduleSync()
UI:Refresh()
end
self.phaseName=label(side,"自由布局","GameFontNormal");self.phaseName:SetPoint("TOPLEFT",2,-70);self.phaseName:SetWidth(138)
self.phasePrevious=button(side,"<",28,20);self.phasePrevious:SetPoint("TOPLEFT",144,-66)
self.phaseNext=button(side,">",28,20);self.phaseNext:SetPoint("LEFT",self.phasePrevious,"RIGHT",4,0)
local function cyclePhase(delta)
if not UI:RequirePlanEditor() then return end
local plan=RM.Plan:GetCurrent();local map=RM:GetMap(plan.mapId);local phases=map.phases or {}
if #phases<2 then return end
local currentId=RM.Plan:GetPhaseId(plan,map.id);local current=1
for index,item in ipairs(phases) do if item.id==currentId then current=index;break end end
current=((current-1+delta)%#phases)+1;RM.Plan:SetPhase(phases[current].id);UI:ScheduleSync();UI:RefreshPosition()
end
self.phasePrevious:SetScript("OnClick",function() cyclePhase(-1) end)
self.phaseNext:SetScript("OnClick",function() cyclePhase(1) end)
self.strategyType=label(side,"自由布局","GameFontDisableSmall");self.strategyType:SetPoint("TOPLEFT",2,-94);self.strategyType:SetWidth(210)
local phaseInfo=CreateFrame("Button",nil,side);phaseInfo:SetPoint("TOPLEFT",0,-64);phaseInfo:SetSize(138,52)
phaseInfo:SetScript("OnEnter",function(self)
local plan=RM.Plan:GetCurrent();local map=RM:GetMap(plan.mapId);local phase=RM.Plan:GetPhase(plan,map.id)
GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:AddLine((phase and phase.name) or map.name,1,0.82,0)
GameTooltip:AddLine("可信度: "..RM:GetConfidenceLabel(map.confidence),0.7,0.8,1)
for _,source in ipairs(map.sources or {}) do GameTooltip:AddLine("• "..tostring(source.label or source),0.8,0.8,0.8,true) end
GameTooltip:Show()
end)
phaseInfo:SetScript("OnLeave",function() GameTooltip:Hide() end)
local auto = button(side, "一键自动安排", 214, 24); auto:SetPoint("TOPLEFT", 0, -118)
self.autoPositionButton=auto
auto:SetScript("OnClick", function()
if not UI:RequirePlanEditor() then return end
RM.Assignment:Run(RM.Plan:GetCurrent(), roster()); UI:ScheduleSync(); UI:Refresh()
end)
self.saveCustomButton=button(side,"保存自定义槽位",104,22); self.saveCustomButton:SetPoint("TOPLEFT",0,-150)
self.saveCustomButton:SetScript("OnClick",function()
if not UI:RequirePlanEditor() then return end
local plan=RM.Plan:GetCurrent();local phaseId=RM.Plan:GetPhaseId(plan,plan.mapId)
if RM.Assignment:SaveCustomOffsets(plan,plan.mapId,phaseId) then
UI:SetGeometryDirty(plan.mapId,phaseId,false)
RM:Toast("已保存为自定义槽位")
end
UI:RefreshPosition()
end)
self.resetTemplateButton=button(side,"恢复模版槽位",104,22); self.resetTemplateButton:SetPoint("LEFT",self.saveCustomButton,"RIGHT",6,0)
self.resetTemplateButton:SetScript("OnClick",function()
if not UI:RequirePlanEditor() then return end
local plan=RM.Plan:GetCurrent();local phaseId=RM.Plan:GetPhaseId(plan,plan.mapId)
RM.Assignment:ResetAllOffsets(plan,plan.mapId,phaseId);UI:SetGeometryDirty(plan.mapId,phaseId,false)
UI:ScheduleSync();UI:RefreshPosition()
end)
self.restoreCustomButton=button(side,"恢复自定义槽位",104,22);self.restoreCustomButton:SetPoint("TOPLEFT",0,-180)
self.restoreCustomButton:SetScript("OnClick",function()
if not UI:RequirePlanEditor() then return end
local plan=RM.Plan:GetCurrent();local phaseId=RM.Plan:GetPhaseId(plan,plan.mapId)
if RM.Assignment:RestoreCustomOffsets(plan,plan.mapId,phaseId) then
UI:SetGeometryDirty(plan.mapId,phaseId,false);UI:ScheduleSync()
end
UI:RefreshPosition()
end)
self.clearAssignmentButton=button(side,"清空人员分配",104,22);self.clearAssignmentButton:SetPoint("LEFT",self.restoreCustomButton,"RIGHT",6,0)
self.clearAssignmentButton:SetScript("OnClick",function()
if not UI:RequirePlanEditor() then return end
local plan=RM.Plan:GetCurrent();RM.Assignment:ClearAssignments(plan,plan.mapId,RM.Plan:GetPhaseId(plan,plan.mapId));UI:ScheduleSync();UI:RefreshPosition()
end)
self.copyPhaseButton=button(side,"复制上阶段",104,22);self.copyPhaseButton:SetPoint("TOPLEFT",0,-210)
self.copyPhaseButton:SetScript("OnClick",function(self)
if not UI:RequirePlanEditor() then return end
local plan=RM.Plan:GetCurrent();local map=RM:GetMap(plan.mapId);local current=RM.Plan:GetPhase(plan,map.id)
local previous=self.previousPhase
if not previous or not current then return end
local ok=RM.Plan:CopyPhaseLayout(plan,map.id,previous.id,current.id)
if ok then RM:Print("已将“"..tostring(previous.name).."”的人员、锁定和槽位微调复制到当前阶段。") end
if ok then UI:ScheduleSync() end
UI:RefreshPosition()
end)
self.copyPhaseButton:SetScript("OnEnter",function(self)
GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
GameTooltip:AddLine("复制上一阶段",1,0.82,0)
GameTooltip:AddLine("把上一阶段的人员、锁定和坐标微调显式复制到当前阶段；两个阶段仍独立保存。",0.75,0.82,1,true)
GameTooltip:Show()
end)
self.copyPhaseButton:SetScript("OnLeave",function() GameTooltip:Hide() end)
self.positionSummary=label(side,"","GameFontHighlightSmall"); self.positionSummary:SetPoint("TOPLEFT",2,-240); self.positionSummary:SetWidth(215)
self.positionSummary:SetJustifyH("LEFT"); self.positionSummary:SetJustifyV("TOP")
if self.positionSummary.SetSpacing then self.positionSummary:SetSpacing(3) end
self.positionDetailScroll=CreateFrame("ScrollFrame","NoWCLRaidManagementPositionDetailScroll",side,"UIPanelScrollFrameTemplate")
self.positionDetailScroll:SetPoint("TOPLEFT",self.positionSummary,"BOTTOMLEFT",0,-8)
self.positionDetailScroll:SetPoint("BOTTOMRIGHT",side,"BOTTOMRIGHT",-24,2)
self.positionDetailBody=CreateFrame("Frame",nil,self.positionDetailScroll)
self.positionDetailBody:SetSize(190,1)
self.positionDetailScroll:SetScrollChild(self.positionDetailBody)
self.positionDetailScroll:SetScript("OnSizeChanged",function(scroll,width)
UI.positionDetailBody:SetWidth(math.max(1,width))
if not UI.positionDetails then return end
local height=math.max(1,(UI.positionDetails.GetStringHeight and UI.positionDetails:GetStringHeight()) or 1)
UI.positionDetailBody:SetHeight(height+4)
if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
end)
self.positionDetails=label(self.positionDetailBody,"","GameFontDisableSmall")
self.positionDetails:SetPoint("TOPLEFT",0,0);self.positionDetails:SetPoint("TOPRIGHT",0,0)
self.positionDetails:SetJustifyH("LEFT");self.positionDetails:SetJustifyV("TOP")
if self.positionDetails.SetSpacing then self.positionDetails:SetSpacing(2) end
return panel
end
function UI:CreateReviewRow(parent, index)
local row = CreateFrame("Frame", nil, parent)
row:SetHeight(27); row:SetPoint("TOPLEFT", 0, -(index-1)*28); row:SetPoint("RIGHT",0,0)
if index%2==0 then backdrop(row,0.12,0.12,0.15,0.45) end
row.name=label(row,""); row.name:SetPoint("LEFT",6,0); row.name:SetWidth(170)
row.assignee=label(row,""); row.assignee:SetPoint("LEFT",180,0); row.assignee:SetWidth(110)
row.expected=label(row,""); row.expected:SetPoint("LEFT",300,0); row.expected:SetWidth(90)
row.observed=label(row,""); row.observed:SetPoint("LEFT",400,0); row.observed:SetWidth(90)
row.status=label(row,""); row.status:SetPoint("LEFT",500,0); row.status:SetWidth(80)
row:EnableMouse(true)
row:SetScript("OnEnter",function(self)
local task=self.reviewTask;if not task then return end
GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
GameTooltip:AddLine(task.name or "任务证据",1,0.82,0)
GameTooltip:AddLine(task.reason or "",task.status=="miss" and 1 or 0.65,task.status=="miss" and 0.35 or 0.85,0.45,true)
if #(task.evidence or {})==0 then
GameTooltip:AddLine("本场没有匹配事件",0.65,0.65,0.65)
else
for evidenceIndex,event in ipairs(task.evidence) do
if evidenceIndex>8 then GameTooltip:AddLine(string.format("另有 %d 条证据",#task.evidence-8),0.65,0.65,0.65);break end
local spellName=U.SpellLabel(event.spellId)
GameTooltip:AddLine(string.format("%.1fs  %s  %s → %s",event.at or 0,spellName,
U.ShortName(event.source),U.ShortName(event.target)),0.78,0.85,1)
end
end
GameTooltip:Show()
end)
row:SetScript("OnLeave",function() GameTooltip:Hide() end)
self.reviewRows[index]=row
return row
end
function UI:RefreshReview()
local review = RM.Review:Latest()
if not review then
self.reviewSummary:SetText("还没有可复盘的首领战。完成一场使用当前方案的战斗后，这里会生成执行对账。")
self.reviewPreparation:SetText("")
for _, row in ipairs(self.reviewRows) do row:Hide() end
self.deathSummary:SetText("")
self.reviewPage:SetText("")
return
end
local taskCount = #(review.tasks or {})
local visible = #self.reviewRows
local maxOffset = math.max(0, taskCount - visible)
self.reviewOffset = math.max(0, math.min(maxOffset, self.reviewOffset or 0))
local scoreText=review.score and string.format("评分 %.0f%%",review.score*100) or "仅观察，无评分项"
self.reviewSummary:SetText(string.format("%s  ·  %s  ·  达标 %d/%d  ·  %s",
tostring(review.encounterName or "首领战"), review.success and "|cff44ff44击杀|r" or "|cffffaa00未击杀|r",
review.passed or 0, review.total or 0,scoreText))
local audit=review.assignmentAudit
if not audit then
self.reviewPreparation:SetText("|cff888888本场没有开怪方案完整性快照|r")
elseif audit.status=="complete" then
self.reviewPreparation:SetText(string.format("|cff44ff44开怪方案完整|r  ·  固定站位 %d  ·  共享覆盖 %d",
audit.assigned or 0,audit.shared or 0))
elseif audit.status=="dynamic" then
self.reviewPreparation:SetText("|cff66ccff动态阶段|r  ·  本阶段不使用固定个人槽位")
else
self.reviewPreparation:SetText(string.format("|cffffaa33开怪前方案有 %d 项待处理|r  ·  移动查看详情",audit.issueCount or 0))
end
for index, row in ipairs(self.reviewRows) do
local task = review.tasks and review.tasks[self.reviewOffset + index]
row:SetShown(task ~= nil)
if task then
row.reviewTask=task
local spellName = U.SpellLabel(task.spellId)
row.name:SetText((task.name or "任务") .. (task.spellId and task.spellId>0 and ("  |cff888888"..spellName.."|r") or ""))
row.assignee:SetText(task.assignee and task.assignee~="" and U.ShortName(task.assignee) or "全团")
row.expected:SetText(task.mode=="maximum" and ("最多 "..tostring(task.maximum or 0).." 次")
or task.mode=="observe" and "仅观察" or ("至少 "..tostring(task.minimum or task.expected or 1).." 次"))
row.observed:SetText("实际 "..tostring(task.observed or 0).." 次")
row.status:SetText(task.status=="pass" and "|cff44ff44达标|r"
or task.status=="observe" and "|cff66ccff已记录|r" or "|cffff5555未达标|r")
else row.reviewTask=nil end
end
local deaths = {}
for _, death in ipairs(review.deaths or {}) do deaths[#deaths+1]=string.format("%s %.1fs",U.ShortName(death.name),death.at or 0) end
self.deathSummary:SetText(#deaths>0 and ("死亡时间: "..table.concat(deaths,"，")) or "本场未记录到团队成员死亡")
local first = taskCount > 0 and self.reviewOffset + 1 or 0
local last = math.min(taskCount, self.reviewOffset + visible)
self.reviewPage:SetText(string.format("任务 %d-%d / %d  ·  滚轮查看更多",first,last,taskCount))
end
function UI:CreateReviewPanel(parent)
local panel=CreateFrame("Frame",nil,parent); panel:SetAllPoints()
self.reviewSummary=label(panel,"","GameFontNormalLarge"); self.reviewSummary:SetPoint("TOPLEFT",6,-8); self.reviewSummary:SetWidth(680)
local preparation=CreateFrame("Button",nil,panel);preparation:SetPoint("TOPLEFT",6,-28);preparation:SetSize(680,18)
self.reviewPreparation=label(preparation,"","GameFontDisableSmall");self.reviewPreparation:SetAllPoints();self.reviewPreparation:SetJustifyH("LEFT")
preparation:SetScript("OnEnter",function(self)
local review=RM.Review:Latest();local audit=review and review.assignmentAudit
if not audit then return end
GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:AddLine("开怪方案快照",1,0.82,0)
GameTooltip:AddLine((audit.phaseName or "当前阶段").."  ·  修订随本场锁定",0.65,0.8,1)
if #(audit.issues or {})==0 then
GameTooltip:AddLine(audit.status=="dynamic" and "本阶段没有固定槽位要求。" or "开怪时没有发现空职责或分配冲突。",0.4,1,0.5,true)
else
for _,issue in ipairs(audit.issues) do
local target=issue.name and issue.name~="" and issue.name or issue.slotId or "未指定"
GameTooltip:AddLine(string.format("%s  %s  %s",issue.category or "问题",target,issue.reason or ""),1,0.55,0.35,true)
end
if (audit.issueCount or 0)>#audit.issues then
GameTooltip:AddLine(string.format("另有 %d 项",audit.issueCount-#audit.issues),0.65,0.65,0.65)
end
end
GameTooltip:Show()
end)
preparation:SetScript("OnLeave",function() GameTooltip:Hide() end)
for _,column in ipairs({{"任务",10,170,"LEFT"},{"负责人",184,110,"LEFT"},
{"计划",304,90,"LEFT"},{"实际",404,90,"LEFT"},{"结论",504,80,"LEFT"}}) do
local head=label(panel,column[1],"GameFontNormalSmall")
head:SetPoint("TOPLEFT",column[2],-46);head:SetWidth(column[3]);head:SetJustifyH(column[4])
end
local list=CreateFrame("Frame",nil,panel); list:SetPoint("TOPLEFT",4,-66); list:SetPoint("BOTTOMRIGHT",-4,48)
list:EnableMouseWheel(true)
list:SetScript("OnMouseWheel",function(_,delta)
UI.reviewOffset=math.max(0,(UI.reviewOffset or 0)-delta)
UI:RefreshReview()
end)
for index=1,12 do self:CreateReviewRow(list,index) end
self.deathSummary=label(panel,"","GameFontDisableSmall"); self.deathSummary:SetPoint("BOTTOMLEFT",6,14); self.deathSummary:SetWidth(680)
self.reviewPage=label(panel,"","GameFontDisableSmall");self.reviewPage:SetPoint("BOTTOMRIGHT",-6,14);self.reviewPage:SetWidth(220);self.reviewPage:SetJustifyH("RIGHT")
return panel
end
function UI:Refresh()
if not (self.panel and self.panel:IsShown()) then return end
self:RefreshHeader()
if self.planPanel then self.planPanel:Hide() end
if self.reviewPanel then self.reviewPanel:Hide() end
self.positionPanel:Show()
self:RefreshPosition()
end
function UI:CreatePanel(host, context)
local panel=CreateFrame("Frame",nil,host)
panel:SetPoint("TOPLEFT",host,"TOPLEFT",8,-72)
panel:SetPoint("BOTTOMRIGHT",host,"BOTTOMRIGHT",-8,30)
self.panel=panel; self.context=context
self.autoSyncCheck=CreateFrame("CheckButton",nil,panel,"UICheckButtonTemplate")
self.autoSyncCheck:SetSize(22,22);self.autoSyncCheck:SetPoint("TOPRIGHT",-76,-4)
self.autoSyncCheck:SetHitRectInsets(0,-72,0,0)
self.autoSyncCheck.text=label(panel,"同步全团","GameFontHighlightSmall")
self.autoSyncCheck.text:SetPoint("LEFT",self.autoSyncCheck,"RIGHT",1,0)
self.autoSyncCheck.text:SetWidth(70)
self.autoSyncCheck:SetChecked(RM:GetDB().settings.autoSync~=false)
self.autoSyncCheck:SetScript("OnClick",function(self)
RM:GetDB().settings.autoSync=self:GetChecked() and true or false
UI:UpdatePositionSyncLifecycle()
end)
self.autoSyncCheck:SetScript("OnEnter",function(self)
GameTooltip:SetOwner(self,"ANCHOR_BOTTOM")
GameTooltip:AddLine("同步全团",1,0.82,0)
GameTooltip:AddLine("每次发送当前 Boss 的完整压缩方案；未确认的 NoWCL 团员每 3 秒补发一次，全员确认后自动停止。",0.72,0.8,1,true)
GameTooltip:Show()
end)
self.autoSyncCheck:SetScript("OnLeave",function() GameTooltip:Hide() end)
self.syncRosterGrid=CreateFrame("Frame",nil,panel);self.syncRosterGrid:SetSize(39,39)
self.syncRosterGrid:SetPoint("TOPRIGHT",-8,-25);self.syncRosterCells={}
for index=1,25 do
local cell=CreateFrame("Button",nil,self.syncRosterGrid);cell:SetSize(7,7)
cell:SetPoint("TOPLEFT",((index-1)%5)*8,-math.floor((index-1)/5)*8)
cell.bg=cell:CreateTexture(nil,"ARTWORK");cell.bg:SetAllPoints()
cell:SetScript("OnUpdate",function(self)
if self.syncState=="syncing" then
self.bg:SetAlpha(0.45+0.55*((math.sin((GetTime and GetTime() or 0)*5)+1)/2))
else self.bg:SetAlpha(1) end
end)
cell:SetScript("OnEnter",function(self)
local row=self.syncRow;if not row then return end
local raidIndex=tonumber(row.raidIndex) or index
local subgroup=tonumber(row.subgroup) or math.floor((raidIndex-1)/5)+1
local subgroupSlot=tonumber(row.subgroupSlot) or ((raidIndex-1)%5)+1
GameTooltip:SetOwner(self,"ANCHOR_BOTTOM")
GameTooltip:AddLine(string.format("%d-%d  %s",subgroup,subgroupSlot,row.name or "未知"),1,1,1)
GameTooltip:AddLine(SYNC_GRID_LABELS[self.syncState] or "未知状态",unpack(SYNC_GRID_COLORS[self.syncState] or SYNC_GRID_COLORS.missing))
GameTooltip:Show()
end)
cell:SetScript("OnLeave",function() GameTooltip:Hide() end)
self.syncRosterCells[index]=cell
end
self.syncState=label(panel,"尚未同步","GameFontDisableSmall"); self.syncState:SetPoint("TOPRIGHT",-55,-31); self.syncState:SetWidth(205); self.syncState:SetJustifyH("RIGHT")
self.syncStateHit=CreateFrame("Button",nil,panel);self.syncStateHit:SetPoint("TOPRIGHT",-55,-25);self.syncStateHit:SetSize(205,20)
self.syncStateHit:SetScript("OnEnter",function(self) UI:ShowSyncReceipts(self) end)
self.syncStateHit:SetScript("OnLeave",function() GameTooltip:Hide() end)
self.modeButtons={}
local modeTitle=label(panel,"站位与同步","GameFontNormal")
modeTitle:SetPoint("TOPLEFT",8,-39)
local content=CreateFrame("Frame",nil,panel); content:SetPoint("TOPLEFT",4,-64); content:SetPoint("BOTTOMRIGHT",-4,2)
self.positionPanel=self:CreatePositionPanel(content)
panel:SetScript("OnShow",function()
UI:UpdatePositionSyncLifecycle()
end)
panel:SetScript("OnHide",function()
if RM.Sync then RM.Sync:SetPositionPageOpen(false) end
end)
U.RegisterFontRoot(panel)
self:Refresh()
return panel
end
function UI:RegisterPrimaryPage()
if self.primaryPageRegistered then return true end
local api=RM:GetNoWCLAPI()
if not (api and api.RegisterPrimaryPage) then return false end
local registered=api:RegisterPrimaryPage({
id="raid_management", label="团战管理", order=30,
title="NoWCL  |cff66ccff团战管理|r",
subtitle="Boss 站位安排与全团同步",
Create=function(_,host,context) return UI:CreatePanel(host,context) end,
Refresh=function() UI:Refresh() end,
OnShow=function()
if RM.EncounterContext then RM.EncounterContext:ApplyPreferred(false) end
UI:Refresh()
end,
})
self.primaryPageRegistered=registered and true or self.primaryPageRegistered
return self.primaryPageRegistered == true
end
function UI:OnLogin()
local api=RM:GetNoWCLAPI()
if not api then return end
if api.Subscribe then
api:Subscribe("SESSION_FEATURE_UNLOCKED",self,function(payload)
if payload and payload.key=="author_credit" then UI:RegisterPrimaryPage() end
end)
end
if api.IsSessionFeatureUnlocked and api:IsSessionFeatureUnlocked("author_credit") then
self:RegisterPrimaryPage()
end
end
