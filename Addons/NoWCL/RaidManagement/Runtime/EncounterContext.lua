local _, NoWCL = ...
local RM = NoWCL.RaidManagement
local C = { defeatedByRaid = {} }
RM.EncounterContext = C
RM.modules[#RM.modules + 1] = C
local function sameDifficulty(left, right)
left, right = tonumber(left) or 0, tonumber(right) or 0
return left == 0 or right == 0 or left == right
end
local function currentInstance()
if not GetInstanceInfo then return nil end
local name, instanceType, difficultyId, _, _, _, _, instanceMapId = GetInstanceInfo()
if instanceType ~= "raid" then return nil end
local raid = RM:GetPositionRaidForInstance(name, instanceMapId)
if not raid then return nil end
return {
raid=raid, name=name, difficultyId=tonumber(difficultyId) or 0,
instanceMapId=tonumber(instanceMapId),
}
end
local function currentActiveMap(self)
local direct = RM:GetPositionMapForEncounter(self.activeEncounterId)
if direct then return direct end
local api = RM.GetNoWCLAPI and RM:GetNoWCLAPI()
local snapshot = api and api.GetActiveFightSnapshot and api:GetActiveFightSnapshot()
if snapshot and snapshot.isBoss then return RM:GetPositionMapForBossName(snapshot.encounter) end
end
local function savedDefeated(instance)
local defeated = {}
if not (instance and GetNumSavedInstances and GetSavedInstanceInfo
and GetSavedInstanceEncounterInfo) then return defeated end
for savedIndex = 1, (tonumber(GetNumSavedInstances()) or 0) do
local values = { GetSavedInstanceInfo(savedIndex) }
local savedName, savedDifficulty = values[1], values[4]
local locked, isRaid, encounterCount = values[5], values[8], tonumber(values[11]) or 0
local savedRaid = RM:GetPositionRaidForInstance(savedName, nil)
if savedRaid == instance.raid and isRaid ~= false and locked ~= false
and sameDifficulty(savedDifficulty, instance.difficultyId) then
for encounterIndex = 1, encounterCount do
local encounterName, encounterId, killed = GetSavedInstanceEncounterInfo(savedIndex, encounterIndex)
if killed then
encounterId = tonumber(encounterId)
if encounterId then defeated[encounterId] = true end
local map = RM:GetPositionMapForBossName(encounterName)
if map then
defeated[tonumber(map.encounterId)] = true
defeated[map.bossName] = true
end
end
end
end
end
return defeated
end
function C:GetDefeated(instance)
local defeated = savedDefeated(instance)
local session = instance and self.defeatedByRaid[instance.raid.key]
for encounterId in pairs(session or {}) do
defeated[tonumber(encounterId) or encounterId] = true
end
return defeated
end
local function contextKey(activeMap, instance, defeated)
if activeMap then return "boss:" .. tostring(activeMap.encounterId) end
if not instance then return "outside" end
local parts = { "raid", instance.raid.key }
for _, map in ipairs(instance.raid.maps or {}) do
if defeated[tonumber(map.encounterId)] or defeated[map.bossName] then
parts[#parts + 1] = tostring(map.encounterId)
end
end
return table.concat(parts, ":")
end
function C:ResolvePreferredMap()
local activeMap = currentActiveMap(self)
local instance = currentInstance()
if activeMap then return activeMap, "current", contextKey(activeMap, instance, {}) end
if instance then
local defeated = self:GetDefeated(instance)
local nextMap = RM:GetNextPositionMap(instance.raid.key, defeated)
return nextMap or RM:GetMap("neutral"), nextMap and "next" or "unavailable",
contextKey(nil, instance, defeated)
end
local plan = RM.Plan:GetCurrent()
local current = RM:GetMap(plan.mapId)
if RM:IsPositionMap(current) then return current, "retained", "outside" end
return RM.PositionBossCatalog[1] or RM:GetMap("neutral"), "default", "outside"
end
local function selectMap(map, manual)
local plan
if map and map.encounterId then
plan = RM.Plan:SetCurrent(map.encounterId, map.bossName or map.name, true)
RM.Plan:SetMap(map.id, manual == true)
else
plan = RM.Plan:SetCurrent(nil, "自定义战术")
if plan.mapExplicit then plan.mapExplicit = false; RM.Plan:Touch(plan) end
RM.Plan:SetMap("neutral", false)
end
return plan
end
function C:ApplyPreferred(force)
if RM.Sync and RM.Sync.IsFollowingAuthority and RM.Sync:IsFollowingAuthority(RM.Plan:GetCurrent()) then
return RM:GetMap(RM.Plan:GetCurrent().mapId)
end
local map, reason, key = self:ResolvePreferredMap()
if not map then return nil end
if not force and self.manualContextKey == key then return RM:GetMap(RM.Plan:GetCurrent().mapId) end
if not force and self.appliedContextKey == key and RM.Plan:GetCurrent().mapId == map.id then return map end
if self.appliedContextKey ~= key then self.manualContextKey = nil end
local plan = selectMap(map, false)
self.appliedContextKey = key
self.selectionReason = reason
if RM.Sync and RM.Sync.ScheduleBroadcast then RM.Sync:ScheduleBroadcast(plan, 2) end
RM:Refresh()
return map
end
function C:SelectManualMap(mapId)
local map = RM:GetMap(mapId)
if not RM:IsPositionMap(map) then return false end
local plan = selectMap(map, true)
RM.Plan:Touch(plan)
local _, _, key = self:ResolvePreferredMap()
self.manualContextKey = key
self.appliedContextKey = key
self.selectionReason = "manual"
return true
end
function C:OnEncounterStart(payload)
self.activeEncounterId = tonumber(payload and payload.encounterId)
self.manualContextKey = nil
self:ApplyPreferred(true)
end
function C:OnEncounterEnd(payload)
local encounterId = tonumber(payload and payload.encounterId) or self.activeEncounterId
if payload and payload.success and encounterId then
local map = RM:GetPositionMapForEncounter(encounterId)
if map then
self.defeatedByRaid[map.raidKey] = self.defeatedByRaid[map.raidKey] or {}
self.defeatedByRaid[map.raidKey][encounterId] = true
end
end
self.activeEncounterId = nil
self.manualContextKey = nil
self:ApplyPreferred(true)
end
function C:OnLogin()
local api = RM:GetNoWCLAPI()
if api then
api:Subscribe("ENCOUNTER_START", self, function(payload) C:OnEncounterStart(payload) end)
api:Subscribe("ENCOUNTER_END", self, function(payload) C:OnEncounterEnd(payload) end)
end
self.frame = self.frame or CreateFrame("Frame")
self.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
self.frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
self.frame:RegisterEvent("UPDATE_INSTANCE_INFO")
self.frame:SetScript("OnEvent", function()
C.manualContextKey = nil
C:ApplyPreferred(true)
end)
self:ApplyPreferred(true)
end
function C:OnLogout()
local api = RM:GetNoWCLAPI()
if api then
api:Unsubscribe("ENCOUNTER_START", self)
api:Unsubscribe("ENCOUNTER_END", self)
end
end
