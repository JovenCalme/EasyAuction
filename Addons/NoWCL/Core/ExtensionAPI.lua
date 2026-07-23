local _, NoWCL = ...
local API = { listeners = {}, sessionFeatures = {} }
NoWCL.ExtensionAPI = API
_G.NoWCL_API = API
local function copyValue(value, depth, seen)
if type(value) ~= "table" then return value end
depth = tonumber(depth) or 0
if depth <= 0 then return nil end
seen = seen or {}
if seen[value] then return nil end
seen[value] = true
local out = {}
for key, item in pairs(value) do
if type(key) ~= "table" then out[key] = copyValue(item, depth - 1, seen) end
end
seen[value] = nil
return out
end
function API:GetVersion()
return NoWCL.version
end
function API:GetRosterSnapshot()
local roster = NoWCL.Stats and NoWCL.Stats.roster or {}
local readiness = NoWCL.Readiness and NoWCL.Readiness.localCache or {}
local group = {}
local function short(value)
return tostring(value or ""):match("^[^-]+") or tostring(value or "")
end
if IsInRaid and IsInRaid() and GetRaidRosterInfo and GetNumGroupMembers then
local subgroupSlots = {}
for index = 1, GetNumGroupMembers() do
local name, rank, subgroup, _, _, class, _, online, _, role = GetRaidRosterInfo(index)
name = short(name)
if name ~= "" then
subgroup = tonumber(subgroup) or 1
subgroupSlots[subgroup] = (subgroupSlots[subgroup] or 0) + 1
group[name] = {
name=name, class=class, role=role, unit="raid" .. index,
raidIndex=index, subgroup=subgroup, subgroupSlot=subgroupSlots[subgroup],
rank=rank, online=online,
}
end
end
elseif IsInGroup and IsInGroup() and GetNumSubgroupMembers then
local units = { "player" }
for index = 1, GetNumSubgroupMembers() do units[#units + 1] = "party" .. index end
for index, unit in ipairs(units) do
local name = short(UnitName and UnitName(unit))
if name ~= "" then
group[name] = {
name=name, class=select(2, UnitClass(unit)),
role=UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit), unit=unit,
raidIndex=index, subgroup=1, subgroupSlot=index, online=UnitIsConnected and UnitIsConnected(unit),
}
end
end
end
if not next(group) then
local name = short(UnitName and UnitName("player"))
if name ~= "" then
group[name] = {
name=name, class=UnitClass and select(2,UnitClass("player")),
role=UnitGroupRolesAssigned and UnitGroupRolesAssigned("player"), unit="player",
raidIndex=1, subgroup=1, subgroupSlot=1,
online=not UnitIsConnected or UnitIsConnected("player"),
}
end
end
local rows = {}
local names = {}
for name in pairs(group) do names[name] = true end
for name in pairs(names) do
local info = roster[name] or {}
local groupInfo = group[name] or {}
local ready = readiness[name] or {}
rows[#rows + 1] = {
name = name,
guid = info.guid or (UnitGUID and groupInfo.unit and UnitGUID(groupInfo.unit)),
class = info.class or groupInfo.class,
role = NoWCL.Stats and NoWCL.Stats.RoleOf and NoWCL.Stats:RoleOf(name)
or info.role or groupInfo.role,
specId = tonumber(ready.specId or info.specId),
unit = info.unit or groupInfo.unit,
raidIndex = groupInfo.raidIndex,
subgroup = groupInfo.subgroup,
subgroupSlot = groupInfo.subgroupSlot,
rank = groupInfo.rank,
online = groupInfo.online,
}
end
table.sort(rows, function(a, b)
local ai, bi = tonumber(a.raidIndex), tonumber(b.raidIndex)
if ai and bi and ai ~= bi then return ai < bi end
if ai ~= nil and bi == nil then return true end
if ai == nil and bi ~= nil then return false end
return tostring(a.name) < tostring(b.name)
end)
return rows
end
function API:GetAddonPeers()
local peers = NoWCL.Sync and NoWCL.Sync.noWCLPeers and NoWCL.Sync:noWCLPeers() or {}
local out = {}
for name in pairs(peers) do
name = tostring(name or ""):match("^[^-]+") or tostring(name or "")
if name ~= "" then out[#out + 1] = name end
end
table.sort(out)
return out
end
function API:GetFightSnapshot(fightId, includeDetails)
if not (NoWCL.Sync and NoWCL.Sync.GetView) then return nil end
local view = NoWCL.Sync:GetView(fightId or "all", includeDetails == true)
return copyValue(view, includeDetails and 7 or 4)
end
function API:GetActiveFightSnapshot()
local stats = NoWCL.Stats
local seg = stats and stats.segment
if not (seg and not seg._ended) then return nil end
local now = GetTime and GetTime() or 0
return {
encounter = seg.name,
isBoss = seg.isBoss and true or false,
startedAt = seg.startTime,
duration = math.max(0, now - (tonumber(seg.startTime) or now)),
puller = seg.puller,
pullMethod = seg.pullMethod,
pullSpellId = seg.pullSpellId,
}
end
function API:OpenPrimaryPage(id)
return NoWCL.AuditUI and NoWCL.AuditUI.OpenPrimaryPage
and NoWCL.AuditUI:OpenPrimaryPage(id) or false
end
function API:RegisterPrimaryPage(descriptor)
if NoWCL.PrimaryPages and NoWCL.PrimaryPages.Register then
return NoWCL.PrimaryPages:Register(descriptor)
end
return false, "registry_unavailable"
end
function API:UnregisterPrimaryPage(id)
if NoWCL.PrimaryPages and NoWCL.PrimaryPages.Unregister then
return NoWCL.PrimaryPages:Unregister(id)
end
return false
end
function API:IsSessionFeatureUnlocked(key)
return type(key) == "string" and self.sessionFeatures[key] == true
end
function API:UnlockSessionFeature(key)
if type(key) ~= "string" or key == "" then return false end
if self.sessionFeatures[key] then return true end
self.sessionFeatures[key] = true
self:Publish("SESSION_FEATURE_UNLOCKED", { key=key })
return true
end
function API:RegisterFontRoot(root)
local style = NoWCL.UIStyle
if not (root and style and style.RegisterRoot) then return false end
style:RegisterRoot(root)
return true
end
function API:ShowToast(text, duration)
local toast = NoWCL.Toast
if not (toast and toast.Show) then return false end
toast:Show(tostring(text or ""), tonumber(duration) or 3)
return true
end
function API:Subscribe(eventName, owner, callback)
if type(eventName) ~= "string" or type(callback) ~= "function" then return false end
local bucket = self.listeners[eventName]
if not bucket then bucket = {}; self.listeners[eventName] = bucket end
bucket[owner or callback] = callback
return true
end
function API:Unsubscribe(eventName, owner)
local bucket = self.listeners[eventName]
if bucket then bucket[owner] = nil end
end
function API:Publish(eventName, payload)
local bucket = self.listeners[eventName]
if not bucket then return end
for _, callback in pairs(bucket) do
local ok, err = pcall(callback, copyValue(payload, 5))
if not ok and NoWCL.Print then NoWCL:Print("扩展事件处理失败: " .. tostring(err)) end
end
end
