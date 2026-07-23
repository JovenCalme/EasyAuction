local addonName, NoWCL = ...
local E = {}
NoWCL.AnnouncementElection = E
local U = NoWCL.Util
local PREFIX = "NCLNotice1"
local PROTOCOL = 1
local HEARTBEAT_SECONDS = 5
local PEER_TTL_SECONDS = 15
local DONE_TTL_SECONDS = 600
local ARBITRATION_SECONDS = 0.35
local FEATURES = { "death", "performance", "failures", "rules", "pull" }
local FEATURE_INDEX = { death=1, performance=2, failures=3, rules=4, pull=5 }
local FEATURE_SETTING = {
death="deathAnnounce",
performance="performanceAnnounce",
failures="failureAnnounce",
rules="rulesAnnounce",
pull="pullStartAnnounce",
}
E.PREFIX = PREFIX
E.FEATURES = FEATURES
E.FEATURE_SETTING = FEATURE_SETTING
E.peers = {}
E.done = {}
E.claims = {}
E.owners = {}
local function now()
return GetTime and GetTime() or time()
end
local function shortName(name)
return type(name) == "string" and (name:match("^[^-]+") or name) or nil
end
local function grouped()
return IsInGroup and IsInGroup() and U and U.GroupChannel and U.GroupChannel() ~= nil
end
local function isLeader()
return grouped() and UnitIsGroupLeader and UnitIsGroupLeader("player") and true or false
end
local function remoteAuthority()
local sync = NoWCL.Sync
return sync and sync.HasLeaderAuthority and sync:HasLeaderAuthority() or false
end
local function maskHas(mask, feature)
local index = FEATURE_INDEX[feature]
if not index then return false end
return math.floor((tonumber(mask) or 0) / (2 ^ (index - 1))) % 2 == 1
end
local function candidateLess(left, right)
if not right then return true end
local leftGuid = tostring(left.guid or "")
local rightGuid = tostring(right.guid or "")
if leftGuid ~= rightGuid then
if leftGuid == "" then return false end
if rightGuid == "" then return true end
return leftGuid < rightGuid
end
local leftName, rightName = tostring(left.name or ""), tostring(right.name or "")
if leftName ~= rightName then return leftName < rightName end
return tostring(left.session or "") < tostring(right.session or "")
end
local function rosterMembers()
local members = {}
local count = GetNumGroupMembers and (GetNumGroupMembers() or 0) or 0
local inRaid = IsInRaid and IsInRaid()
local subgroupSlots = {}
local function add(unit, rosterName, rank, subgroup, class, online)
local name = UnitName and UnitName(unit) or rosterName
name = shortName(name or rosterName)
if not name then return end
if UnitClass then class = select(2, UnitClass(unit)) or class end
if UnitIsConnected and UnitExists and UnitExists(unit) then online = UnitIsConnected(unit) end
if online == nil then online = true end
subgroup = tonumber(subgroup) or 1
subgroupSlots[subgroup] = (subgroupSlots[subgroup] or 0) + 1
members[#members + 1] = {
unit=unit, name=name, guid=UnitGUID and UnitGUID(unit) or nil,
class=class, connected=online and true or false,
leader=(rank == 2) or (UnitIsGroupLeader and UnitIsGroupLeader(unit)) or false,
groupLabel=string.format("%d-%d", subgroup, subgroupSlots[subgroup]),
}
end
if inRaid then
for index = 1, count do
local name, rank, subgroup, _, _, class, _, online
if GetRaidRosterInfo then
name, rank, subgroup, _, _, class, _, online = GetRaidRosterInfo(index)
end
add("raid" .. index, name, rank, subgroup or math.floor((index - 1) / 5) + 1, class, online)
end
else
add("player", nil, isLeader() and 2 or 0, 1, nil, true)
for index = 1, math.max(0, count - 1) do add("party" .. index, nil, 0, 1, nil, nil) end
end
return members
end
local function rosterByName(name)
name = shortName(name)
for _, member in ipairs(rosterMembers()) do
if member.name == name then return member end
end
end
local function localCandidate(self)
local name = shortName(UnitName and UnitName("player")) or "?"
local roster = rosterByName(name) or {}
return {
session=self.session,
name=name,
guid=(UnitGUID and UnitGUID("player")) or roster.guid,
class=roster.class,
groupLabel=roster.groupLabel,
connected=true,
leader=isLeader(),
localClient=true,
mask=self:LocalMask(),
}
end
function E:EffectiveEnabled(feature)
local setting = FEATURE_SETTING[feature]
if not setting then return false end
local settings
if remoteAuthority() then
settings = NoWCL.Sync and NoWCL.Sync.cfg
else
settings = NoWCL.db and NoWCL.db.settings
end
return settings and settings[setting] == true or false
end
function E:LocalMask()
if remoteAuthority() then return 0 end
local settings = NoWCL.db and NoWCL.db.settings or {}
local mask = 0
for index, feature in ipairs(FEATURES) do
if settings[FEATURE_SETTING[feature]] == true then mask = mask + 2 ^ (index - 1) end
end
return mask
end
function E:_Send(message, priority)
if not grouped() or type(self.SendCommMessage) ~= "function" then return false end
local ok = pcall(self.SendCommMessage, self, PREFIX, tostring(message or ""), U.GroupChannel(), nil,
priority or "NORMAL")
return ok
end
function E:BroadcastHeartbeat()
if not grouped() then return false end
local candidate = localCandidate(self)
return self:_Send(table.concat({ "H", PROTOCOL, self.session, candidate.guid or "",
candidate.name or "", self:LocalMask() }, "~"), "BULK")
end
function E:_Prune()
local cutoff = now() - PEER_TTL_SECONDS
for session, peer in pairs(self.peers) do
local roster = rosterByName(peer.name)
if (peer.lastAt or 0) < cutoff or not roster or roster.connected == false then
self.peers[session] = nil
else
peer.class = roster.class or peer.class
peer.groupLabel = roster.groupLabel or peer.groupLabel
peer.leader = roster.leader and true or false
peer.connected = true
end
end
local doneCutoff = now() - DONE_TTL_SECONDS
for key, at in pairs(self.done) do if at < doneCutoff then self.done[key] = nil end end
for key, claim in pairs(self.claims) do if (claim.at or 0) < cutoff then self.claims[key] = nil end end
end
function E:_ComputeOwner(feature)
if not grouped() then return nil end
self:_Prune()
if remoteAuthority() then
if not self:EffectiveEnabled(feature) then return nil end
for _, member in ipairs(rosterMembers()) do
if member.leader and member.connected then return member end
end
return nil
end
local candidates = {}
local mine = localCandidate(self)
if maskHas(mine.mask, feature) then candidates[#candidates + 1] = mine end
for _, peer in pairs(self.peers) do
if peer.connected ~= false and maskHas(peer.mask, feature) then candidates[#candidates + 1] = peer end
end
local winner
for _, candidate in ipairs(candidates) do
if candidate.leader then
if not winner or not winner.leader or candidateLess(candidate, winner) then winner = candidate end
elseif not winner or (not winner.leader and candidateLess(candidate, winner)) then
winner = candidate
end
end
return winner
end
function E:RecomputeOwners(refresh)
local changed = false
for _, feature in ipairs(FEATURES) do
local old = self.owners[feature]
local owner = self:_ComputeOwner(feature)
self.owners[feature] = owner
local oldKey = old and ((old.guid or "") .. "\001" .. (old.name or "") .. "\001" .. (old.session or "")) or ""
local newKey = owner and ((owner.guid or "") .. "\001" .. (owner.name or "") .. "\001" .. (owner.session or "")) or ""
if oldKey ~= newKey then changed = true end
end
if changed and refresh and NoWCL.AuditUI and NoWCL.AuditUI.Refresh then NoWCL.AuditUI:Refresh() end
return changed
end
function E:GetOwner(feature)
self:RecomputeOwners(false)
return self.owners[feature]
end
function E:IsOwner(feature)
if not self:EffectiveEnabled(feature) then return false end
local owner = self:GetOwner(feature)
return owner and shortName(owner.name) == shortName(UnitName and UnitName("player"))
and (not owner.guid or not UnitGUID or owner.guid == UnitGUID("player")) or false
end
function E:GetOwnerLabel(feature)
local owner = self:GetOwner(feature)
if not owner then return self:EffectiveEnabled(feature) and "当前负责：等待选举" or "当前负责：无" end
local label = U.ResolveGroupCharacterLabel and U.ResolveGroupCharacterLabel(owner.name, owner.guid,
owner.class, owner.groupLabel) or tostring(owner.name or "?")
return "当前负责：" .. label
end
function E:SetFeatureEnabled(feature, enabled)
local setting = FEATURE_SETTING[feature]
if not setting or remoteAuthority() then return false end
local settings = NoWCL.db and NoWCL.db.settings
if not settings then return false end
settings[setting] = enabled and true or false
if NoWCL.Sync and NoWCL.Sync.BroadcastConfig then NoWCL.Sync:BroadcastConfig() end
self:NotifySettingsChanged()
return true
end
function E:NotifySettingsChanged()
self:BroadcastHeartbeat()
self:RecomputeOwners(true)
end
function E:OnAuthorityChanged()
self:BroadcastHeartbeat()
self:RecomputeOwners(true)
end
function E:OnRosterUpdate()
if not grouped() then
self.peers = {}
self.owners = {}
if NoWCL.TeamAnnouncements and NoWCL.TeamAnnouncements.OnRosterUpdate then
NoWCL.TeamAnnouncements:OnRosterUpdate({},false)
end
return
end
self:_Prune()
self:BroadcastHeartbeat()
self:RecomputeOwners(true)
if NoWCL.TeamAnnouncements and NoWCL.TeamAnnouncements.OnRosterUpdate then
NoWCL.TeamAnnouncements:OnRosterUpdate(rosterMembers(),true)
end
end
local function publishKey(feature, fightKey)
return tostring(feature or "") .. "\001" .. tostring(fightKey or "")
end
function E:IsDone(feature, fightKey)
self:_Prune()
return self.done[publishKey(feature, fightKey)] ~= nil
end
function E:MarkDone(feature, fightKey)
local key = publishKey(feature, fightKey)
self.done[key] = now()
self:_Send(table.concat({ "D", feature, U.Esc(fightKey), self.session }, "~"), "ALERT")
end
function E:PublishOnce(feature, fightKey, callback)
if type(callback) ~= "function" or not self:IsOwner(feature) then return false, "not-owner" end
local key = publishKey(feature, fightKey)
if self:IsDone(feature, fightKey) then return false, "duplicate" end
local mine = localCandidate(self)
self.claims[key] = { guid=mine.guid, name=mine.name, session=self.session, at=now() }
self:_Send(table.concat({ "C", feature, U.Esc(fightKey), self.session,
mine.guid or "", mine.name or "" }, "~"), "ALERT")
local function finish()
if E:IsDone(feature, fightKey) or not E:IsOwner(feature) then return end
local claim = E.claims[key]
if claim and candidateLess(claim, mine) then return end
local ok, accepted = pcall(callback)
if ok and accepted ~= false then E:MarkDone(feature, fightKey) end
end
if C_Timer and C_Timer.After then C_Timer.After(ARBITRATION_SECONDS, finish) else finish() end
return true, "pending"
end
function E:OnCommReceived(prefix, message, distribution, sender)
if prefix ~= PREFIX or type(message) ~= "string" then return end
local kind, a, b, c, d, e = strsplit("~", message, 6)
local senderShort = shortName(sender)
if kind == "H" then
if tonumber(a) ~= PROTOCOL then return end
local session, guid, name, mask = b, c, shortName(d), tonumber(e) or 0
if not session or not name or name ~= senderShort then return end
local roster = rosterByName(name)
if not roster or roster.connected == false or (guid ~= "" and roster.guid and guid ~= roster.guid) then return end
for oldSession, peer in pairs(self.peers) do
if oldSession ~= session and peer.name == name then self.peers[oldSession] = nil end
end
self.peers[session] = {
session=session, guid=guid ~= "" and guid or roster.guid, name=name, mask=mask,
class=roster.class, groupLabel=roster.groupLabel, leader=roster.leader,
connected=true, lastAt=now(),
}
self:RecomputeOwners(true)
elseif kind == "C" then
local feature, fightKey, session, guid, name = a, U.Unesc(b or ""), c, d, shortName(e)
if not FEATURE_INDEX[feature] or not name or name ~= senderShort then return end
local roster = rosterByName(name)
if not roster or roster.connected == false then return end
local key = publishKey(feature, fightKey)
local incoming = { session=session, guid=guid ~= "" and guid or roster.guid, name=name, at=now() }
local current = self.claims[key]
if not current or candidateLess(incoming, current) then self.claims[key] = incoming end
elseif kind == "D" then
local feature, fightKey = a, U.Unesc(b or "")
if FEATURE_INDEX[feature] then self.done[publishKey(feature, fightKey)] = now() end
end
end
function E:Init()
if self._inited then return true end
local aceComm = LibStub and LibStub("AceComm-3.0", true)
if not aceComm then return false, "AceComm-3.0 unavailable" end
aceComm:Embed(self)
local ok, reason = pcall(self.RegisterComm, self, PREFIX, "OnCommReceived")
if not ok then return false, tostring(reason) end
self.session = table.concat({ tostring(UnitGUID and UnitGUID("player") or "player"),
tostring(time()), tostring(math.random(100000, 999999)) }, ":")
self._inited = true
local frame = CreateFrame("Frame")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function() E:OnRosterUpdate() end)
self._frame = frame
if C_Timer and C_Timer.NewTicker then
self._ticker = C_Timer.NewTicker(HEARTBEAT_SECONDS, function()
E:BroadcastHeartbeat()
E:RecomputeOwners(true)
end)
end
self:OnRosterUpdate()
return true
end
