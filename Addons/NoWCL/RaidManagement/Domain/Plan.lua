local _, NoWCL = ...
local RM = NoWCL.RaidManagement
local U = RM.Util
local P = { currentKey = "manual" }
RM.Plan = P
RM.modules[#RM.modules + 1] = P
local VALID_TYPES = { interrupt=true, dispel=true, defensive=true, utility=true, mechanic=true }
local VALID_EVENTS = {
SPELL_INTERRUPT=true, SPELL_DISPEL=true, SPELL_STOLEN=true,
SPELL_CAST_SUCCESS=true, SPELL_AURA_APPLIED=true, SPELL_DAMAGE=true,
SPELL_PERIODIC_DAMAGE=true,
}
local VALID_MODES = { minimum=true, maximum=true, observe=true }
local VALID_SUBJECTS = { source=true, target=true, any=true }
local VALID_ROLES = { TANK=true, HEALER=true, DAMAGER=true }
local function numericList(value)
local source = type(value) == "table" and value or { value }
local out, seen = {}, {}
for _, item in ipairs(source) do
if type(item) == "string" and item:find(",", 1, true) then
for _, part in ipairs(U.Split(item, ",")) do
local number = math.floor(tonumber(part) or 0)
if number > 0 and not seen[number] then seen[number]=true;out[#out+1]=number end
end
else
local number = math.floor(tonumber(item) or 0)
if number > 0 and not seen[number] then seen[number]=true;out[#out+1]=number end
end
end
return out
end
local function stringList(value, allowed, uppercase)
local source = type(value) == "table" and value or { value }
local out, seen = {}, {}
for _, item in ipairs(source) do
local parts = type(item) == "string" and U.Split(item, ",") or {}
for _, part in ipairs(parts) do
part = uppercase and tostring(part):upper() or tostring(part)
if part ~= "" and (not allowed or allowed[part]) and not seen[part] then
seen[part]=true;out[#out+1]=part
end
end
end
return out
end
local function normalizeMapLayout(layout)
layout = type(layout) == "table" and layout or {}
layout.assignments = type(layout.assignments) == "table" and layout.assignments or {}
layout.offsets = type(layout.offsets) == "table" and layout.offsets or {}
layout.locks = type(layout.locks) == "table" and layout.locks or {}
layout.groups = type(layout.groups) == "table" and layout.groups or {}
layout.manual = type(layout.manual) == "table" and layout.manual or {}
for slotId, name in pairs(layout.assignments) do
if type(slotId) ~= "string" or type(name) ~= "string" or name == "" then
layout.assignments[slotId] = nil
else
layout.assignments[slotId] = U.ShortName(name)
end
end
for slotId, point in pairs(layout.offsets) do
if type(slotId) ~= "string" or type(point) ~= "table" then
layout.offsets[slotId] = nil
else
point.x = U.SnapGridCoordinate(point.x)
point.y = U.SnapGridCoordinate(point.y)
end
end
for slotId, locked in pairs(layout.locks) do
if type(slotId) ~= "string" or not locked then layout.locks[slotId] = nil end
end
for slotId, manual in pairs(layout.manual) do
if type(slotId) ~= "string" or not manual or not layout.assignments[slotId] then
layout.manual[slotId] = nil
end
end
for slotId, subgroup in pairs(layout.groups) do
subgroup = math.floor(tonumber(subgroup) or 0)
if type(slotId) ~= "string" or subgroup < 1 or subgroup > 8 then
layout.groups[slotId] = nil
else
layout.groups[slotId] = subgroup
end
end
return layout
end
local function normalizeTask(task)
task.id = tostring(task.id or U.NewId("task"))
task.name = tostring(task.name or "新任务"):sub(1, 48)
task.type = VALID_TYPES[task.type] and task.type or "utility"
task.spellIds = numericList(task.spellIds or task.spellId)
task.spellId = task.spellIds[1] or 0
task.events = stringList(task.events or task.event, VALID_EVENTS)
task.event = task.events[1] or (VALID_EVENTS[task.event] and task.event)
or (task.type == "interrupt" and "SPELL_INTERRUPT")
or (task.type == "dispel" and "SPELL_DISPEL") or "SPELL_CAST_SUCCESS"
if #task.events == 0 then task.events[1] = task.event end
task.expectedAt = math.max(0, math.min(1800, tonumber(task.expectedAt) or 0))
task.tolerance = math.max(1, math.min(60, tonumber(task.tolerance) or 8))
task.mode = VALID_MODES[task.mode] and task.mode or "minimum"
task.subject = VALID_SUBJECTS[task.subject] and task.subject or "source"
task.minimum = math.max(1, math.min(999, math.floor(tonumber(task.minimum or task.count) or 1)))
task.maximum = math.max(0, math.min(999, math.floor(tonumber(task.maximum) or 0)))
task.count = task.minimum
task.assignee = U.ShortName(task.assignee or "")
if task.assignee == "未知" then task.assignee = "" end
task.role = VALID_ROLES[task.role] and task.role or nil
task.classes = stringList(task.classes or task.class, nil, true)
task.class = task.classes[1]
task.targetRoles = stringList(task.targetRoles, VALID_ROLES, true)
task.sourceRoles = stringList(task.sourceRoles, VALID_ROLES, true)
task.phaseId = type(task.phaseId) == "string" and task.phaseId or nil
task.mapId = type(task.mapId) == "string" and task.mapId or nil
task.templateId = type(task.templateId) == "string" and task.templateId or nil
task.autoAssign = task.autoAssign ~= false
return task
end
local function normalizePlan(plan, key, name)
plan.id = tostring(plan.id or U.NewId("plan"))
plan.key = tostring(key or plan.key or "manual")
plan.name = tostring(name or plan.name or "自定义战术"):sub(1, 80)
plan.mapId = RM:GetMap(plan.mapId).id
plan.revision = math.max(1, math.floor(tonumber(plan.revision) or 1))
plan.tasks = type(plan.tasks) == "table" and plan.tasks or {}
plan.positions = type(plan.positions) == "table" and plan.positions or {}
plan.mapLayouts = type(plan.mapLayouts) == "table" and plan.mapLayouts or {}
plan.phaseIds = type(plan.phaseIds) == "table" and plan.phaseIds or {}
plan.templateContracts = type(plan.templateContracts) == "table" and plan.templateContracts or {}
plan.taskTemplateVersions = type(plan.taskTemplateVersions) == "table" and plan.taskTemplateVersions or {}
plan.dismissedTemplateTasks = type(plan.dismissedTemplateTasks) == "table" and plan.dismissedTemplateTasks or {}
plan.mapExplicit = plan.mapExplicit and true or false
for name, point in pairs(plan.positions) do
if type(name) ~= "string" or type(point) ~= "table" then
plan.positions[name] = nil
else
point.x = U.SnapGridCoordinate(point.x)
point.y = U.SnapGridCoordinate(point.y)
end
end
for mapId, layout in pairs(plan.mapLayouts) do
if type(mapId) == "string" then plan.mapLayouts[mapId] = normalizeMapLayout(layout)
else plan.mapLayouts[mapId] = nil end
end
for index, task in ipairs(plan.tasks) do plan.tasks[index] = normalizeTask(task) end
for mapId, phaseId in pairs(plan.phaseIds) do
local map = RM:GetMap(mapId)
if map.id ~= mapId or not (map.phaseById and map.phaseById[phaseId]) then
plan.phaseIds[mapId] = nil
else
plan.phaseIds[mapId] = tostring(phaseId)
end
end
for mapId, contract in pairs(plan.templateContracts) do
if type(mapId) ~= "string" or type(contract) ~= "string" then plan.templateContracts[mapId] = nil end
end
for mapId, version in pairs(plan.taskTemplateVersions) do
version = math.max(0, math.floor(tonumber(version) or 0))
if type(mapId) ~= "string" then plan.taskTemplateVersions[mapId] = nil
else plan.taskTemplateVersions[mapId] = version end
end
for mapId, dismissed in pairs(plan.dismissedTemplateTasks) do
if type(mapId) ~= "string" or type(dismissed) ~= "table" then
plan.dismissedTemplateTasks[mapId] = nil
else
for templateId, value in pairs(dismissed) do
if type(templateId) ~= "string" or not value then dismissed[templateId] = nil end
end
end
end
return plan
end
function P:EnsureDefaultTasks(plan, mapId)
plan = plan or self:GetCurrent()
local map = RM:GetMap(mapId or plan.mapId)
local targetVersion = math.max(0, math.floor(tonumber(map.taskTemplateVersion) or 0))
if targetVersion == 0 then return false end
plan.taskTemplateVersions = type(plan.taskTemplateVersions) == "table" and plan.taskTemplateVersions or {}
plan.dismissedTemplateTasks = type(plan.dismissedTemplateTasks) == "table" and plan.dismissedTemplateTasks or {}
local currentVersion = math.max(0, math.floor(tonumber(plan.taskTemplateVersions[map.id]) or 0))
if currentVersion >= targetVersion then return false end
local existing = {}
for _, task in ipairs(plan.tasks or {}) do
if task.mapId == map.id and task.templateId then existing[task.templateId] = true end
end
local dismissed = plan.dismissedTemplateTasks[map.id] or {}
local changed = false
for _, templateTask in ipairs(map.defaultTasks or {}) do
local templateId = tostring(templateTask.templateId or "")
if templateId ~= "" and not existing[templateId] and not dismissed[templateId] then
local task = U.Copy(templateTask, 7) or {}
task.id = "tpl-" .. map.id .. "-" .. templateId
task.mapId = map.id
task.templateId = templateId
plan.tasks[#plan.tasks + 1] = normalizeTask(task)
existing[templateId] = true
changed = true
end
end
plan.taskTemplateVersions[map.id] = targetVersion
return changed or currentVersion ~= targetVersion
end
function P:OnLoad()
local db = RM:GetDB()
for key, plan in pairs(db.plans) do db.plans[key] = normalizePlan(plan, key) end
self.currentKey = tostring(db.lastPlanKey or "manual")
self:Get(self.currentKey, "自定义战术")
end
function P:Get(key, name)
key = tostring(key or self.currentKey or "manual")
local db = RM:GetDB()
if not db.plans[key] then db.plans[key] = normalizePlan({}, key, name) end
return normalizePlan(db.plans[key], key, name)
end
function P:GetCurrent()
return self:Get(self.currentKey)
end
function P:SetCurrent(encounterId, encounterName, forcePositionMap)
local key = encounterId and ("encounter-" .. tostring(encounterId)) or "manual"
self.currentKey = key
RM:GetDB().lastPlanKey = key
local plan = self:Get(key, encounterName or "自定义战术")
local map
if RM.GetPositionMapForEncounter then
map = RM:GetPositionMapForEncounter(encounterId)
elseif RM.GetMapForEncounter then
map = RM:GetMapForEncounter(encounterId)
end
local changed = false
if map and (forcePositionMap or not plan.mapExplicit) and plan.mapId ~= map.id then
plan.mapId = map.id
changed = true
end
if forcePositionMap and plan.mapExplicit then
plan.mapExplicit = false
changed = true
end
if self:EnsureDefaultTasks(plan, plan.mapId) then changed = true end
if changed then self:Touch(plan) end
return plan
end
function P:Select(key)
if not RM:GetDB().plans[key] then return false end
self.currentKey = key
RM:GetDB().lastPlanKey = key
RM:Refresh()
return true
end
function P:Touch(plan)
plan = plan or self:GetCurrent()
plan.revision = math.max(1, tonumber(plan.revision) or 1) + 1
plan.updatedAt = time and time() or 0
end
function P:SetMap(mapId, explicit)
local plan = self:GetCurrent()
local map = RM:GetMap(mapId)
local changed = false
if plan.mapId ~= map.id or (explicit and not plan.mapExplicit) then
plan.mapId = map.id
if explicit then plan.mapExplicit = true end
changed = true
end
if self:EnsureDefaultTasks(plan, map.id) then changed = true end
if changed then self:Touch(plan) end
return map
end
function P:GetPhaseId(plan, mapId)
plan = plan or self:GetCurrent()
local map = RM:GetMap(mapId or plan.mapId)
plan.phaseIds = type(plan.phaseIds) == "table" and plan.phaseIds or {}
local phaseId = plan.phaseIds[map.id]
local phase = RM:GetMapPhase(map, phaseId)
phaseId = phase and phase.id or map.defaultPhaseId
if phaseId then plan.phaseIds[map.id] = phaseId end
return phaseId
end
function P:GetPhase(plan, mapId)
plan = plan or self:GetCurrent()
local map = RM:GetMap(mapId or plan.mapId)
return RM:GetMapPhase(map, self:GetPhaseId(plan, map.id))
end
function P:SetPhase(phaseId)
local plan = self:GetCurrent()
local map = RM:GetMap(plan.mapId)
local phase = map.phaseById and map.phaseById[phaseId]
if not phase then return nil end
plan.phaseIds = type(plan.phaseIds) == "table" and plan.phaseIds or {}
if plan.phaseIds[map.id] ~= phase.id then
plan.phaseIds[map.id] = phase.id
self:Touch(plan)
end
return phase
end
function P:LayoutKey(mapId, phaseId)
local map = RM:GetMap(mapId)
local phase = RM:GetMapPhase(map, phaseId)
if not phase or phase.id == map.defaultPhaseId then return map.id end
return map.id .. "@" .. phase.id
end
function P:GetMapLayout(plan, mapId, phaseId)
plan = plan or self:GetCurrent()
mapId = RM:GetMap(mapId or plan.mapId).id
phaseId = phaseId or self:GetPhaseId(plan, mapId)
local layoutKey = self:LayoutKey(mapId, phaseId)
plan.mapLayouts = type(plan.mapLayouts) == "table" and plan.mapLayouts or {}
plan.mapLayouts[layoutKey] = normalizeMapLayout(plan.mapLayouts[layoutKey])
return plan.mapLayouts[layoutKey]
end
function P:CopyPhaseLayout(plan, mapId, fromPhaseId, toPhaseId)
plan = plan or self:GetCurrent()
local map = RM:GetMap(mapId or plan.mapId)
local fromPhase = RM:GetMapPhase(map, fromPhaseId)
local toPhase = RM:GetMapPhase(map, toPhaseId)
if not fromPhase or not toPhase or fromPhase.id == toPhase.id then return false, "invalid_phase" end
if #(fromPhase.slots or {}) == 0 or #(toPhase.slots or {}) == 0 then return false, "no_slots" end
local validSlots, validGroups = {}, {}
for _, slot in ipairs(toPhase.slots) do validSlots[slot.id] = true end
for _, slot in ipairs(toPhase.groupSlots or {}) do validGroups[slot.id] = true end
local source = self:GetMapLayout(plan, map.id, fromPhase.id)
local target = self:GetMapLayout(plan, map.id, toPhase.id)
target.assignments, target.offsets, target.locks, target.groups, target.manual = {}, {}, {}, {}, {}
for slotId, name in pairs(source.assignments or {}) do
if validSlots[slotId] then target.assignments[slotId] = name end
end
for slotId, point in pairs(source.offsets or {}) do
if validSlots[slotId] then target.offsets[slotId] = U.Copy(point) end
end
for slotId, locked in pairs(source.locks or {}) do
if validSlots[slotId] and locked then target.locks[slotId] = true end
end
for slotId, manual in pairs(source.manual or {}) do
if validSlots[slotId] and manual and target.assignments[slotId] then target.manual[slotId] = true end
end
for slotId, subgroup in pairs(source.groups or {}) do
if validGroups[slotId] then target.groups[slotId] = subgroup end
end
self:Touch(plan)
return true, fromPhase, toPhase
end
function P:AddTask(values)
local plan = self:GetCurrent()
local task = normalizeTask(values or {})
plan.tasks[#plan.tasks + 1] = task
self:Touch(plan)
return task
end
function P:RemoveTask(taskId)
local plan = self:GetCurrent()
for index, task in ipairs(plan.tasks) do
if task.id == taskId then
if task.templateId and task.mapId then
plan.dismissedTemplateTasks = type(plan.dismissedTemplateTasks) == "table" and plan.dismissedTemplateTasks or {}
plan.dismissedTemplateTasks[task.mapId] = plan.dismissedTemplateTasks[task.mapId] or {}
plan.dismissedTemplateTasks[task.mapId][task.templateId] = true
end
table.remove(plan.tasks, index); self:Touch(plan); return true
end
end
return false
end
function P:RestoreDefaultTasks(mapId)
local plan = self:GetCurrent()
local map = RM:GetMap(mapId or plan.mapId)
for index = #plan.tasks, 1, -1 do
local task = plan.tasks[index]
if task.mapId == map.id and task.templateId then table.remove(plan.tasks, index) end
end
plan.dismissedTemplateTasks[map.id] = nil
plan.taskTemplateVersions[map.id] = nil
self:EnsureDefaultTasks(plan, map.id)
self:Touch(plan)
return true
end
function P:NormalizeTask(task)
normalizeTask(task)
self:Touch(self:GetCurrent())
end
function P:GetActiveTasks(plan, mapId)
plan = plan or self:GetCurrent()
mapId = RM:GetMap(mapId or plan.mapId).id
local active = {}
for _, task in ipairs(plan.tasks or {}) do
if not task.mapId or task.mapId == "" or task.mapId == mapId then
active[#active + 1] = task
end
end
return active
end
function P:Replace(plan)
if type(plan) ~= "table" or not plan.key then return false end
local normalized = normalizePlan(U.Copy(plan), plan.key, plan.name)
RM:GetDB().plans[normalized.key] = normalized
self.currentKey = normalized.key
RM:GetDB().lastPlanKey = normalized.key
return true
end
function P:WatchIndex(plan)
local watch = {}
for _, task in ipairs(self:GetActiveTasks(plan)) do
for _, event in ipairs(task.events or {task.event}) do
for _, spellId in ipairs(task.spellIds or {task.spellId}) do
if VALID_EVENTS[event] and tonumber(spellId) and tonumber(spellId) > 0 then
watch[event] = watch[event] or {}
watch[event][spellId] = watch[event][spellId] or {}
local duplicate
for _, taskId in ipairs(watch[event][spellId]) do
if taskId == task.id then duplicate = true; break end
end
if not duplicate then table.insert(watch[event][spellId], task.id) end
end
end
end
end
return watch
end
