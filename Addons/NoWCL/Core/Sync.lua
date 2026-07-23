local addonName, NoWCL = ...
local SY = {}
NoWCL.Sync = SY
local U = NoWCL.Util
SY.recvStats = {}
SY.cfg = nil
SY.tabs = {}
SY._viewRevision = 0
SY._viewCache = {}
SY.sid  = 1
SY.leaderSid = nil
SY.hasLeaderAuthority = false
SY.curLeader = nil
SY.probeAt = nil
local HARD_MAX_TABS = 99
local REQTAB_COOLDOWN = 3
local REQTAB_MAX_PER_SEC = 3
local SEND_QUEUE_CAP = 150
local REQTAB_QUEUE_CAP = 80
local REQTAB_REQ_INTERVAL = 3.2
local FETCH_MAX_TRIES = 10
local ACK_TIMEOUT = 30
local function amLeader()
return IsInGroup() and U.IsRaidLeader("player")
end
local function toArray(pmap)
local a = {}
for name, p in pairs(pmap or {}) do p.name = p.name or name; a[#a+1] = p end
return a
end
local function sumValues(src)
if type(src) ~= "table" then return 0 end
local total = 0
for _, v in pairs(src) do total = total + (tonumber(v) or 0) end
return total
end
local function healingAmount(p)
if not p then return 0 end
if U.HealingAmount then return U.HealingAmount(p) end
return math.max(tonumber(p.heal) or 0, sumValues(p.heals), sumValues(p.healTargets))
end
local function reconcileHeal(p)
if not p then return end
local heal = healingAmount(p)
if heal > (tonumber(p.heal) or 0) then p.heal = heal end
end
local function validGear(g)
return g and (tonumber(g.ilvl) or 0) > 0
end
local function positiveNumber(v)
v = tonumber(v) or 0
return v > 0 and v or nil
end
local function currentLeaderName()
if not IsInGroup() then return nil end
if UnitIsGroupLeader("player") then return UnitName("player") end
local prefix = IsInRaid() and "raid" or "party"
local n = GetNumGroupMembers() or 0
for i = 1, n do
local u = prefix .. i
if UnitExists(u) and UnitIsGroupLeader(u) then return UnitName(u) end
end
return nil
end
local PROBE_GRACE = 4
function SY:SetLeaderAuthority(active)
active = active == true and IsInGroup() and not amLeader()
local changed = self.hasLeaderAuthority ~= active
self.hasLeaderAuthority = active
if changed and NoWCL.AnnouncementElection and NoWCL.AnnouncementElection.OnAuthorityChanged then
NoWCL.AnnouncementElection:OnAuthorityChanged()
end
end
function SY:HasLeaderAuthority()
return self.hasLeaderAuthority == true and IsInGroup() and not amLeader()
end
function SY:IsAuthority()
if not IsInGroup() then return true end
if amLeader() then return true end
if self:HasLeaderAuthority() then return false end
return self.probeAt ~= nil and (time() - self.probeAt) >= PROBE_GRACE
end
function SY:countPlayers(t)
local n = 0; for _ in pairs(t and t.players or {}) do n = n + 1 end; return n
end
local function currentPlayerName()
return UnitName("player") or "?"
end
function SY:CurrentCharacterIdentity()
local guid = UnitGUID and UnitGUID("player") or nil
local name = UnitName and UnitName("player") or nil
if guid == "" then guid = nil end
if name == "" then name = nil end
return guid, name
end
function SY:NormalizeTabCharacter(tab)
if type(tab) ~= "table" then return false end
local guid, name = self:CurrentCharacterIdentity()
local changed = false
if not tab.ownerCharacterGUID and not tab.ownerCharacterName then
if guid then tab.ownerCharacterGUID = guid; changed = true end
if name then tab.ownerCharacterName = name; changed = true end
else
if not tab.ownerCharacterGUID and guid and tab.ownerCharacterName == name then
tab.ownerCharacterGUID = guid
changed = true
end
if not tab.ownerCharacterName and name and tab.ownerCharacterGUID == guid then
tab.ownerCharacterName = name
changed = true
end
end
return changed
end
function SY:ShowAllCharacterFights()
return NoWCL.db and NoWCL.db.settings
and NoWCL.db.settings.showAllCharacterFights == true
end
function SY:SetShowAllCharacterFights(enabled)
if not (NoWCL.db and NoWCL.db.settings) then return false end
enabled = enabled and true or false
if NoWCL.db.settings.showAllCharacterFights == enabled then return false end
NoWCL.db.settings.showAllCharacterFights = enabled
self:InvalidateViewCache()
return true
end
function SY:IsTabVisibleForCurrentCharacter(tab)
if type(tab) ~= "table" or self:ShowAllCharacterFights() then return type(tab) == "table" end
local guid, name = self:CurrentCharacterIdentity()
if tab.ownerCharacterGUID and guid then return tab.ownerCharacterGUID == guid end
if tab.ownerCharacterName and name then return tab.ownerCharacterName == name end
return not tab.ownerCharacterGUID and not tab.ownerCharacterName
end
local DETAIL_FIELDS = {
"spells", "heals", "actions", "iv", "ivDur", "deadSec", "deathTimes", "deathDetails",
"targets", "targetsBoss", "healTargets", "targetScope",
"timelineBucket", "damageBuckets", "bossDamageBuckets", "healingBuckets", "scopeTimeline", "specId", "readySpecId",
"spellStats", "healStats", "castStats", "castTargetStats", "spellTargetStats", "auraBuffs", "auraDebuffs",
}
local function hasLocalDetail(p)
return p and ((p.iv and #p.iv > 0) or (p.spells and next(p.spells)) or (p.heals and next(p.heals))
or (p.targets and next(p.targets)) or (p.damageBuckets and next(p.damageBuckets))
or (p.healingBuckets and next(p.healingBuckets)) or (p.deathDetails and #p.deathDetails > 0)
or (type(p.targetScope) == "string" and p.targetScope ~= ""))
end
local function keepLocalDetail(dst, src)
if not dst or not src or not hasLocalDetail(src) then return end
for _, k in ipairs(DETAIL_FIELDS) do
if dst[k] == nil and src[k] ~= nil then dst[k] = src[k] end
end
reconcileHeal(dst)
end
local function collectLocalBreakdown(tabs, incomingFightId)
local out = {}
for fid, t in pairs(tabs or {}) do
if fid ~= incomingFightId and t.selfAuthored and t.players then
for name, p in pairs(t.players) do
if hasLocalDetail(p) then out[name] = p end
end
end
end
return out
end
local function markOlderTabsInactive(tabs, leaderSid)
if not leaderSid or leaderSid <= 0 then return end
for _, t in pairs(tabs or {}) do
if (t.sid or 0) > 0 and (t.sid or 0) < leaderSid then t.active = false end
end
end
function SY:AcceptLeaderSid(sid)
sid = tonumber(sid) or 0
if sid <= 0 then return true end
local prev = tonumber(self.leaderSid) or 0
if prev > 0 and sid < prev then return false end
if sid > prev then
self.leaderSid = sid
markOlderTabsInactive(self.tabs, sid)
elseif prev == 0 then
self.leaderSid = sid
end
return true
end
function SY:noWCLPeers()
local peers = {}
peers[currentPlayerName()] = true
for name, st in pairs(self.recvStats or {}) do
if st and (st.proto or 1) >= 2 and (not IsInGroup() or U.UnitTokenByName(name)) then peers[name] = true end
end
return peers
end
function SY:ensureTabSync(fightId, total, manual)
self._tabSync = self._tabSync or {}
local s = self._tabSync[fightId]
if not s then
s = { ack={}, peers=self:noWCLPeers() }
self._tabSync[fightId] = s
end
s.total = positiveNumber(total) or positiveNumber(s.total) or 0
s.startedAt = s.startedAt or time()
s.lastAt = time()
s.manual = manual or s.manual
s.ack = s.ack or {}
s.peers = s.peers or self:noWCLPeers()
s.ack[currentPlayerName()] = true
if NoWCLDB then NoWCLDB.tabSync = self._tabSync end
return s
end
function SY:TrackPeerForActiveSync(name, st)
if not amLeader() or not name or not st or (st.proto or 1) < 2 then return end
if IsInGroup() and not U.UnitTokenByName(name) then return end
for fid, s in pairs(self._tabSync or {}) do
local t = self.tabs and self.tabs[fid]
if t and t.active then
s.peers = s.peers or {}
s.peers[name] = true
end
end
if NoWCLDB then NoWCLDB.tabSync = self._tabSync end
end
function SY:GetTabSyncStatus(fightId)
if not fightId or fightId == "all" then return nil end
local t = self.tabs and self.tabs[fightId]
if not t then return nil end
local have = self:countPlayers(t)
local total = positiveNumber(t.total) or have
if not self:CanBroadcastTab(fightId) then
if total > 0 and have < total then
return { text="本机同步中 "..have.."/"..total, done=false, have=have, total=total, canResend=false }
end
if total > 0 then
return { text="本机已同步 "..have.."/"..total, done=true, have=have, total=total, canResend=false }
end
return nil
end
local s = self._tabSync and self._tabSync[fightId]
if not s then
return { text="点击同步此战斗", done=false, acked=0, total=0, canResend=true, leader=true }
end
local peers = s.peers or self:noWCLPeers()
local expected, acked = 0, 0
local me = currentPlayerName()
for name in pairs(peers) do
if name ~= me then
expected = expected + 1
if s and s.ack and s.ack[name] then acked = acked + 1 end
end
end
if expected <= 0 then
return { text="已同步全团", done=true, acked=acked, total=expected, canResend=true, leader=true }
end
local done = acked >= expected
local timedOut = (not done) and ((time() - (s.lastAt or s.startedAt or time())) >= ACK_TIMEOUT)
local text = done and "已同步全团" or ((timedOut and "同步" or "同步中") .. " " .. acked .. "/" .. expected .. " 团员")
return { text=text, done=done, timedOut=timedOut, acked=acked, total=expected, canResend=(done or timedOut), leader=true }
end
function SY:CanBroadcastTab(fightId)
if amLeader() then return true end
local t = self.tabs and self.tabs[fightId]
local me = currentPlayerName()
return IsInGroup() and t and not t.selfAuthored and fightId and fightId:sub(1, #me + 1) == (me .. "-")
end
function SY:pickMissingTab()
local best, bestTs, bestGap
for fid, total in pairs(self._wanted or {}) do
local t = self.tabs[fid]
local have = self:countPlayers(t)
local tries = (self._fetchTries and self._fetchTries[fid]) or 0
local want = positiveNumber(total)
if want and have < want and tries < FETCH_MAX_TRIES then
local ts = (t and t.ts) or 0
local gap = want - have
if not best or ts > bestTs or (ts == bestTs and gap > bestGap) then
best, bestTs, bestGap = fid, ts, gap
end
end
end
return best
end
function SY:requestMissingTab(fid)
if not fid or amLeader() or not U.GroupChannel() then return false end
self._wanted = self._wanted or {}
self._fetchTries = self._fetchTries or {}
self._lastHave = self._lastHave or {}
self._reqtabAskedAt = self._reqtabAskedAt or {}
local t = self.tabs[fid]
local total = positiveNumber(self._wanted[fid]) or positiveNumber(t and t.total)
if not total then return false end
self._wanted[fid] = total
local have = self:countPlayers(t)
if have >= total then
self._wanted[fid] = nil; self._fetchTries[fid] = nil; self._lastHave[fid] = nil; self._reqtabAskedAt[fid] = nil
return false
end
if have > (self._lastHave[fid] or -1) then
self._lastHave[fid] = have
self._fetchTries[fid] = 0
end
local now = time()
if self._reqtabAskedAt[fid] and (now - self._reqtabAskedAt[fid]) < REQTAB_REQ_INTERVAL then return false end
if (self._fetchTries[fid] or 0) >= FETCH_MAX_TRIES then return false end
if NoWCL.Comm.Pending and NoWCL.Comm:Pending() > REQTAB_QUEUE_CAP then return false end
self._idleTicks = 0
self._reqtabAskedAt[fid] = now
self._fetchTries[fid] = (self._fetchTries[fid] or 0) + 1
NoWCL.Comm:Send("REQTAB", U.Esc(fid))
return true
end
function SY:sendResyncReq()
if amLeader() or not U.GroupChannel() then return end
self._fetchTries = {}
self._idleTicks = 0
NoWCL.Comm:Send("REQ", "1")
self:startSyncTicker()
end
function SY:startSyncTicker()
if amLeader() or not U.GroupChannel() then return end
if self._syncTicker or not (C_Timer and C_Timer.NewTicker) then return end
self._syncTicker = C_Timer.NewTicker(2, function()
if amLeader() or not U.GroupChannel() then
if self._syncTicker then self._syncTicker:Cancel(); self._syncTicker = nil end; return
end
self._fetchTries = self._fetchTries or {}
local pick = self:pickMissingTab()
if pick then
self:requestMissingTab(pick)
else
self._idleTicks = (self._idleTicks or 0) + 1
if self._idleTicks == 1 then NoWCL.Comm:Send("REQ", "1") end
if self._idleTicks >= 3 and self._syncTicker then self._syncTicker:Cancel(); self._syncTicker = nil end
end
end)
end
function SY:OnRosterUpdate()
if NoWCL.Rules and NoWCL.Rules.ReconcileBossSession then NoWCL.Rules:ReconcileBossSession() end
if not IsInGroup() then
self:SetLeaderAuthority(false); self.curLeader = nil; self.leaderSid = nil; self.probeAt = nil; self.cfg = nil
if NoWCL.AuditUI and NoWCL.AuditUI.Refresh then NoWCL.AuditUI:Refresh() end
return
end
local ldr = currentLeaderName()
if ldr ~= self.curLeader then
self.curLeader = ldr
self.leaderSid = nil
self:SetLeaderAuthority(false)
self.cfg = nil
self._summaryAuthority = nil
self.probeAt = time()
self:sendResyncReq()
end
if NoWCL.AuditUI and NoWCL.AuditUI.Refresh then NoWCL.AuditUI:Refresh() end
end
local function encStat(s, activeMs, combatMs, fightId, mine, boss, ts)
return table.concat({ s.ilvl or 0, s.emptyGems or 0, s.lowQuality or 0,
s.missEnch or 0, math.floor(activeMs or 0), math.floor(combatMs or 0),
NoWCL.version or "?", (NoWCL.Comm and NoWCL.Comm.PROTO) or 1, U.Esc(fightId or ""),
0, 0,
mine and math.floor(mine.dmg or 0) or "",
mine and math.floor(mine.dmgBoss or 0) or "",
mine and math.floor(mine.heal or 0) or "",
mine and math.floor(mine.interrupts or 0) or "",
mine and math.floor(mine.dispels or 0) or "",
mine and math.floor(mine.deaths or 0) or "",
mine and math.floor(mine.sunderApplied or 0) or "",
U.Esc(boss or ""), math.floor(ts or time()),
U.PackExtraTasks(mine and mine.extraTasks), s.specId or (mine and mine.specId) or "",
s.gearAuditKnown and 1 or "" }, "~")
end
local function decStat(p)
local a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,q,r,s,t,u,v,w,x = strsplit("~", p)
local hasDamage = l and l ~= "" and m and m ~= ""
local gearAuditKnown=x=="1"
return { ilvl=U.N(a), emptyGems=gearAuditKnown and U.N(b) or nil, lowQuality=U.N(c),
missEnch=gearAuditKnown and U.N(d) or nil, gearAuditKnown=gearAuditKnown,
activeMs=U.N(e), combatMs=U.N(f),
ver=(g and g ~= "" ) and g or "?",
proto=(h and h ~= "") and U.N(h) or 1,
fightId=U.Unesc(i or ""),
flask=(j and j ~= "") and U.N(j) or nil,
food=(k and k ~= "") and U.N(k) or nil,
dmg=hasDamage and U.N(l) or nil,
dmgBoss=hasDamage and U.N(m) or nil,
heal=hasDamage and U.N(n) or nil,
interrupts=hasDamage and U.N(o) or nil,
dispels=hasDamage and U.N(q) or nil,
deaths=hasDamage and U.N(r) or nil,
sunderApplied=hasDamage and U.N(s) or nil,
extraTasks=(hasDamage and v ~= nil) and (U.UnpackExtraTasks(v) or {}) or nil,
boss=U.Unesc(t or ""),
ts=(u and u ~= "") and U.N(u) or nil,
specId=(w and U.N(w)>0) and U.N(w) or nil }
end
local SNAPP_BATCH    = 3
local SNAPP_MAXBYTES = 210
local function encPlayer(p)
return table.concat({ U.Esc(p.name), math.floor(p.dmg or 0), math.floor(p.dmgBoss or 0),
math.floor(p.heal or 0), math.floor(p.activeMs or 0),
p.interrupts or 0, p.dispels or 0, p.deaths or 0, p.sunderApplied or 0,
U.PackExtraTasks(p.extraTasks), p.readySpecId or p.specId or "" }, "~")
end
local function decSnapP(payload)
local head, body = strsplit("@", payload, 2)
local fid, sid, boss, dur, total, ts, outcome, summaryFlag, summaryManualFlag,
puller, pullMethod, pullSpellId = strsplit("~", head)
local players = {}
if body and body ~= "" then
for _, rec in ipairs({ strsplit(";", body) }) do
local name,dmg,dmgBoss,heal,actMs,int,disp,deaths,sunder,extra,specId = strsplit("~", rec)
if name and name ~= "" then
players[#players+1] = { name=U.Unesc(name), dmg=U.N(dmg), dmgBoss=U.N(dmgBoss),
heal=U.N(heal), activeMs=U.N(actMs), interrupts=U.N(int), dispels=U.N(disp),
deaths=U.N(deaths), sunderApplied=U.N(sunder), specId=(specId and U.N(specId)>0) and U.N(specId) or nil,
extraTasks=(extra ~= nil) and (U.UnpackExtraTasks(extra) or {}) or nil }
end
end
end
local summaryIncluded
if summaryFlag == "0" then summaryIncluded = false
elseif summaryFlag == "1" then summaryIncluded = true end
local summaryManual
if summaryManualFlag == "0" then summaryManual = false
elseif summaryManualFlag == "1" then summaryManual = true end
return { fightId=U.Unesc(fid), sid=U.N(sid), boss=U.Unesc(boss), dur=U.N(dur), total=U.N(total), ts=U.N(ts),
outcome=(outcome == "kill" or outcome == "wipe") and outcome or nil,
summaryIncluded=summaryIncluded, summaryManual=summaryManual,
puller=(puller and puller ~= "") and U.Unesc(puller) or nil,
pullMethod=(pullMethod and pullMethod ~= "") and U.Unesc(pullMethod) or nil,
pullSpellId=(pullSpellId and U.N(pullSpellId)>0) and U.N(pullSpellId) or nil,
players=players }
end
local function sendSnap(fightId, sid, boss, dur, players, ts, channel, target, prio, outcome,
summaryIncluded, summaryManual, puller, pullMethod, pullSpellId)
local head = table.concat({ U.Esc(fightId), sid, U.Esc(boss), math.floor(dur or 0), #players,
math.floor(ts or time()), outcome or "", summaryIncluded == false and "0" or "1", summaryManual and "1" or "0",
puller and U.Esc(puller) or "", pullMethod and U.Esc(pullMethod) or "",
pullSpellId and math.floor(pullSpellId) or "" }, "~")
local batch = {}
local function flush()
if #batch > 0 then NoWCL.Comm:Send("SNAPP", head.."@"..table.concat(batch, ";"), channel, target, prio); batch = {} end
end
for _, p in ipairs(players) do
local rec = encPlayer(p)
local projected = #head + 1 + #rec
for _, r in ipairs(batch) do projected = projected + #r + 1 end
if #batch >= SNAPP_BATCH or (#batch > 0 and projected > SNAPP_MAXBYTES) then flush() end
batch[#batch+1] = rec
end
flush()
end
local CHECK_KEYS = { "active" }
local function encChecks(c)
c = c or {}; local parts = {}
for _, k in ipairs(CHECK_KEYS) do
local ck = c[k] or {}
parts[#parts+1] = k .. ":" .. (ck.on and 1 or 0) .. ":" .. (ck.v or 0)
end
return table.concat(parts, ";")
end
local function decChecks(s)
local out = {}
if s and s ~= "" then
for _, seg in ipairs({ strsplit(";", s) }) do
local k, on, v = strsplit(":", seg)
if k then out[k] = { on=(on=="1"), v=tonumber(v) or 0 } end
end
end
return out
end
local function performanceTopCount(value)
return math.max(1, math.min(8, math.floor(tonumber(value) or 3)))
end
local function normalizeRulesText(value)
value=tostring(value or ""):gsub("[%c]+"," "):gsub("%s+"," ")
value=value:gsub("^%s+",""):gsub("%s+$","")
return U.Trunc and U.Trunc(value,60) or value:sub(1,60)
end
local function encCfg()
local st = NoWCL.db.settings
local rs = NoWCL.Rules:GetActive()
local bosses = {}
for name in pairs(rs.bosses or {}) do bosses[#bosses+1] = U.Esc(name) end
local taskCfg = U.PackTaskContrib and U.PackTaskContrib(st.taskContrib) or ""
local bossCfg = NoWCL.WCLBosses and NoWCL.WCLBosses.PackBossCfg
and NoWCL.WCLBosses:PackBossCfg(st.bossCfg) or ""
local targetProfile = NoWCL.WCLBosses and NoWCL.WCLBosses.NormalizeProfile
and NoWCL.WCLBosses:NormalizeProfile(st.bossProfile) or "wclDamageDone"
local teamBuffChecks = NoWCL.TeamBuffs and NoWCL.TeamBuffs.PackMonitorConfig
and NoWCL.TeamBuffs:PackMonitorConfig(st.teamBuffChecks) or ""
local teamBuffProviders = NoWCL.TeamBuffs and NoWCL.TeamBuffs.PackProviderOverrides
and NoWCL.TeamBuffs:PackProviderOverrides(st.teamBuffProviderOverrides) or ""
local head = table.concat({ st.dpsBaseline or "rank1", st.dpsRatio or 0.6,
U.Esc(UnitName("player")), time(), st.dpsMode or "boss", taskCfg, U.Esc(bossCfg), targetProfile,
st.deathAnnounce == true and "1" or "0",
st.performanceAnnounce == true and "1" or "0",
st.failureAnnounce == true and "1" or "0",
st.performanceRankingMode == "all" and "all" or "split",
st.performanceScope == "summary" and "summary" or "fight",
st.failureDps == false and "0" or "1",
st.failureActivity == false and "0" or "1",
st.failureScope == "summary" and "summary" or "fight",
performanceTopCount(st.performanceTopCount) }, "~")
local rules=table.concat({st.rulesAnnounce==true and "1" or "0",
U.Esc(normalizeRulesText(st.rulesAnnouncementText)),
st.pullStartAnnounce==true and "1" or "0"},"~")
return head .. "@" .. table.concat(bosses, ";") .. "@" .. encChecks(st.checks) .. "@"
.. teamBuffChecks .. "@" .. teamBuffProviders .. "@" .. rules
end
local function decCfg(payload)
local head,bossStr,checkStr,teamBuffStr,teamBuffProviderStr,rulesStr=strsplit("@",payload,6)
local baseline, ratio, by, at, mode, taskStr, bossCfgStr, targetProfile, deathAnnounce,
performanceAnnounce, failureAnnounce, performanceRankingMode, performanceScope,
failureDps, failureActivity, failureScope, topCount = strsplit("~", head)
local rulesAnnounce,rulesText,pullStartAnnounce=strsplit("~",rulesStr or "",3)
local bosses = {}
if bossStr and bossStr ~= "" then
for _, n in ipairs({ strsplit(";", bossStr) }) do bosses[U.Unesc(n)] = true end
end
local profile = NoWCL.WCLBosses and NoWCL.WCLBosses.NormalizeProfile
and NoWCL.WCLBosses:NormalizeProfile(targetProfile, NoWCL.WCLBosses.PROFILE_WCL45) or "wcl45Boss"
local decodedBossCfg = NoWCL.WCLBosses and NoWCL.WCLBosses.UnpackBossCfg
and NoWCL.WCLBosses:UnpackBossCfg(U.Unesc(bossCfgStr or "")) or {}
decodedBossCfg.__profile = profile
return { baseline=baseline, ratio=tonumber(ratio) or 0.6, bosses=bosses,
updatedBy=U.Unesc(by or ""), updatedAt=tonumber(at) or 0,
dpsMode=(mode ~= "" and mode) or "boss", checks=decChecks(checkStr),
taskContrib=U.UnpackTaskContrib and U.UnpackTaskContrib(taskStr) or {},
teamBuffChecks=NoWCL.TeamBuffs and NoWCL.TeamBuffs.UnpackMonitorConfig
and NoWCL.TeamBuffs:UnpackMonitorConfig(teamBuffStr) or {},
teamBuffProviderOverrides=NoWCL.TeamBuffs and NoWCL.TeamBuffs.UnpackProviderOverrides
and NoWCL.TeamBuffs:UnpackProviderOverrides(teamBuffProviderStr) or {},
deathAnnounce=deathAnnounce == "1",
performanceAnnounce=performanceAnnounce == "1",
failureAnnounce=failureAnnounce == "1",
performanceRankingMode=performanceRankingMode == "all" and "all" or "split",
performanceScope=performanceScope == "summary" and "summary" or "fight",
performanceTopCount=performanceTopCount(topCount),
failureDps=failureDps ~= "0", failureActivity=failureActivity ~= "0",
failureScope=failureScope == "summary" and "summary" or "fight",
rulesAnnounce=rulesAnnounce=="1",
rulesAnnouncementText=normalizeRulesText(U.Unesc(rulesText or "")),
pullStartAnnounce=pullStartAnnounce=="1",
bossProfile=profile, bossCfg=decodedBossCfg }
end
local function effectiveBossCfg(self)
if not self:HasLeaderAuthority() then
return NoWCL.db and NoWCL.db.settings and NoWCL.db.settings.bossCfg or {}
end
return self.cfg and self.cfg.bossCfg or {}
end
function SY:InvalidateViewCache()
self._viewRevision = (self._viewRevision or 0) + 1
self._viewCache = {}
end
local function defaultSummaryIncluded(self, boss, bossCfg)
local W = NoWCL.WCLBosses
if not (W and W.ExcludeFromSummary) then return true end
return not W:ExcludeFromSummary(boss, bossCfg or effectiveBossCfg(self))
end
function SY:StoreTab(fightId, sid, boss, dur, players, active, puller, pullMethod, pullSpellId)
local pmap = players[1] and (function() local m={} for _,p in ipairs(players) do m[p.name]=p end return m end)() or players
for name, p in pairs(pmap) do
local gear = NoWCL.Readiness and NoWCL.Readiness.localCache and NoWCL.Readiness.localCache[name]
if validGear(gear) then
p.readyIlvl = gear.ilvl
p.readyLowQuality = gear.lowQuality or 0
p.readyMissEnch = gear.gearAuditKnown and (gear.missEnch or 0) or nil
p.readyEmptyGems = gear.gearAuditKnown and (gear.emptyGems or 0) or nil
p.readyGearKey = gear.gearKey
end
if gear and tonumber(gear.specId) and tonumber(gear.specId)>0 then p.readySpecId=tonumber(gear.specId) end
end
local ownerCharacterGUID, ownerCharacterName = self:CurrentCharacterIdentity()
self.tabs[fightId] = { fightId=fightId, sid=sid, boss=boss, dur=dur, ts=time(), players=pmap, active=active,
summaryIncluded=defaultSummaryIncluded(self, boss), summaryManual=false, puller=puller,
pullMethod=pullMethod, pullSpellId=pullSpellId,
ownerCharacterGUID=ownerCharacterGUID, ownerCharacterName=ownerCharacterName }
self:PruneTabs()
self:Persist(true)
end
function SY:GetAllTabs()
local list = {}
for _, t in pairs(self.tabs) do list[#list+1] = t end
table.sort(list, function(a,b) return (a.ts or 0) < (b.ts or 0) end)
return list
end
function SY:GetTabs()
local list = {}
for _, t in ipairs(self:GetAllTabs()) do
if self:IsTabVisibleForCurrentCharacter(t) then list[#list+1] = t end
end
return list
end
function SY:PruneTabs(limit)
limit = math.max(1, math.min(HARD_MAX_TABS, tonumber(limit)
or (U.CombatHistoryLimit and U.CombatHistoryLimit()) or 30))
local list, removed = self:GetAllTabs(), 0
while #list > limit do
local oldest = table.remove(list, 1)
local fid = oldest and oldest.fightId
if fid then
self.tabs[fid] = nil
if self._wanted then self._wanted[fid] = nil end
if self._tabSync then self._tabSync[fid] = nil end
if self._fightStats then self._fightStats[fid] = nil end
removed = removed + 1
end
end
if removed > 0 then self:Persist(true) end
return removed
end
function SY:IsTabInSummary(tabOrFightId)
local t = type(tabOrFightId) == "table" and tabOrFightId or (self.tabs and self.tabs[tabOrFightId])
return t ~= nil and t.summaryIncluded ~= false
end
local function summaryToastText(t, included)
local label = (t and t.boss) or "战斗"
if t and (t.ts or 0) > 0 then label = label .. " " .. date("%H:%M", t.ts) end
local prefix = included and "|cff44ff44战斗汇总加入：|r" or "|cffffffff战斗汇总移除：|r"
return prefix .. "|cffffd100" .. label .. "|r"
end
function SY:ApplyTabSummaryIncluded(fightId, included, showToast, summaryManual)
local t = self.tabs and self.tabs[fightId]
if not t then return false end
included = included and true or false
local stateChanged = t.summaryIncluded ~= included
local manualChanged = summaryManual ~= nil and t.summaryManual ~= (summaryManual and true or false)
if not stateChanged and not manualChanged then return false end
t.summaryIncluded = included
if summaryManual ~= nil then t.summaryManual = summaryManual and true or false end
self:Persist(true)
if stateChanged and showToast and NoWCL.Toast and NoWCL.Toast.Show then NoWCL.Toast:Show(summaryToastText(t, included), 2) end
if NoWCL.AuditUI and NoWCL.AuditUI.Refresh then NoWCL.AuditUI:Refresh() end
if NoWCL.MiniUI and NoWCL.MiniUI.Refresh then NoWCL.MiniUI:Refresh() end
return true
end
function SY:SetTabSummaryIncluded(fightId, included)
if not self:IsAuthority() then return false end
local changed = self:ApplyTabSummaryIncluded(fightId, included, true, true)
if changed and amLeader() and U.GroupChannel() then
NoWCL.Comm:Send("TABSUM", U.Esc(fightId) .. "~" .. (included and "1" or "0") .. "~1")
if NoWCL.Toast and NoWCL.Toast.PublishLeaderSettingText then
NoWCL.Toast:PublishLeaderSettingText(summaryToastText(self.tabs and self.tabs[fightId],included))
end
end
return changed
end
function SY:Persist(combatStorageChanged)
self:InvalidateViewCache()
if combatStorageChanged and NoWCL.DetailStats and NoWCL.DetailStats.InvalidateStorageEstimate then
NoWCL.DetailStats.InvalidateStorageEstimate()
end
if NoWCLDB then
NoWCLDB.tabs = self.tabs
NoWCLDB.sid = self.sid
NoWCLDB.leaderSid = self.leaderSid
NoWCLDB.recvStats = self.recvStats
end
end
function SY:RecomputeTabSummaryDefaults(bossName, bossCfg)
bossCfg = bossCfg or effectiveBossCfg(self)
local changed, metadataChanged = {}, false
for fid, t in pairs(self.tabs or {}) do
if (not bossName or t.boss == bossName) and t.summaryManual ~= true then
local included = defaultSummaryIncluded(self, t.boss, bossCfg)
if t.summaryIncluded ~= included then
t.summaryIncluded = included
changed[#changed + 1] = fid
metadataChanged = true
end
if t.summaryManual ~= false then t.summaryManual = false; metadataChanged = true end
end
end
if metadataChanged then self:Persist(true) end
return changed
end
function SY:BroadcastTabSummaryState(fightId)
local t = self.tabs and self.tabs[fightId]
if not (t and amLeader() and U.GroupChannel()) then return false end
NoWCL.Comm:Send("TABSUM", table.concat({ U.Esc(fightId), self:IsTabInSummary(t) and "1" or "0", t.summaryManual and "1" or "0" }, "~"))
return true
end
function SY:OnBossSummaryDefaultChanged(bossName)
local changed = self:RecomputeTabSummaryDefaults(bossName)
self:BroadcastConfig()
for _, fid in ipairs(changed) do self:BroadcastTabSummaryState(fid) end
if NoWCL.AuditUI and NoWCL.AuditUI.Refresh then NoWCL.AuditUI:Refresh() end
if NoWCL.MiniUI and NoWCL.MiniUI.Refresh then NoWCL.MiniUI:Refresh() end
return #changed
end
function SY:RecomputeTabScope(t, bossCfg)
if not (t and t.players and NoWCL.Stats and NoWCL.Stats.RecomputePlayerTargetScope) then return 0 end
local changed = 0
for _, p in pairs(t.players) do
if NoWCL.Stats:RecomputePlayerTargetScope(p, t.boss, t.dur, bossCfg) then changed = changed + 1 end
end
return changed
end
function SY:RecomputeStoredScopes(bossName, bossCfg)
bossCfg = bossCfg or effectiveBossCfg(self)
local changed = 0
for _, t in pairs(self.tabs or {}) do
if not bossName or t.boss == bossName then changed = changed + self:RecomputeTabScope(t, bossCfg) end
end
local historyChanged = 0
if NoWCL.Stats and NoWCL.Stats.history then
for _, seg in ipairs(NoWCL.Stats.history) do
if not bossName or seg.name == bossName then
for _, p in ipairs(seg.players or {}) do
if NoWCL.Stats:RecomputePlayerTargetScope(p, seg.name, seg.dur, bossCfg) then
historyChanged = historyChanged + 1
end
end
end
end
end
if changed > 0 then self:Persist(true) end
if historyChanged > 0 and NoWCL.Stats.Persist then NoWCL.Stats:Persist() end
return changed
end
function SY:OnBossScopeChanged(bossName)
local changed = self:RecomputeStoredScopes(bossName)
local summaryChanged = self:RecomputeTabSummaryDefaults(bossName)
if NoWCL.AzerothHistory and NoWCL.AzerothHistory.RecomputeScopes then
NoWCL.AzerothHistory:RecomputeScopes(bossName, effectiveBossCfg(self))
end
self:BroadcastConfig()
for _, fid in ipairs(summaryChanged) do self:BroadcastTabSummaryState(fid) end
if NoWCL.AuditUI and NoWCL.AuditUI.Refresh then NoWCL.AuditUI:Refresh() end
if NoWCL.MiniUI and NoWCL.MiniUI.Refresh then NoWCL.MiniUI:Refresh() end
if changed > 0 and amLeader() and U.GroupChannel() then
self._scopeBroadcastRev = (self._scopeBroadcastRev or 0) + 1
local rev = self._scopeBroadcastRev
local function sendUpdated()
if rev ~= self._scopeBroadcastRev then return end
for fid, t in pairs(self.tabs or {}) do
if t.active and (not bossName or t.boss == bossName) then self:BroadcastTab(fid, false) end
end
end
if C_Timer and C_Timer.After then C_Timer.After(0.8, sendUpdated) else sendUpdated() end
end
return changed
end
function SY:Restore()
self:InvalidateViewCache()
if NoWCLDB then
self.tabs = NoWCLDB.tabs or {}
self.sid = NoWCLDB.sid or 1
self.leaderSid = NoWCLDB.leaderSid
self.recvStats = NoWCLDB.recvStats or {}
self._tabSync = NoWCLDB.tabSync or {}
local classByName = {}
local characterMetadataChanged = false
for _, tab in pairs(self.tabs) do
if self:NormalizeTabCharacter(tab) then characterMetadataChanged = true end
if tab.summaryManual == nil then tab.summaryManual = false end
if tab.summaryManual ~= true then tab.summaryIncluded = defaultSummaryIncluded(self, tab.boss)
elseif tab.summaryIncluded == nil then tab.summaryIncluded = defaultSummaryIncluded(self, tab.boss) end
for name, p in pairs(tab.players or {}) do
local class = p.class
if class then classByName[p.name or name] = class end
p.extraTasks = U.CopyExtraTasks(p.extraTasks, class)
end
end
for name, st in pairs(self.recvStats) do
st.extraTasks = U.CopyExtraTasks(st.extraTasks, classByName[name])
end
if NoWCL.Readiness and NoWCL.Readiness.CacheGear then
for name, st in pairs(self.recvStats or {}) do
NoWCL.Readiness:CacheGear(name, st)
end
end
self:RecomputeStoredScopes("阵营冠军")
if characterMetadataChanged then self:Persist(true) end
end
end
function SY:ClearTabs()
self.tabs = {}
self._summaryAuthority = nil
self._wanted = {}
self._tabSync = {}
self._tabAcked = {}
self._tabAckedAt = {}
self._fetchTries = {}
self._lastHave = {}
self._reqtabAskedAt = {}
self._tabSentAt = {}
self._fightStats = {}
if NoWCL.Stats and NoWCL.Stats.ClearHistory then NoWCL.Stats:ClearHistory() end
self.sid = (self.sid or 1) + 1
self:Persist(true)
if NoWCLDB then NoWCLDB.tabSync = self._tabSync end
if U.GroupChannel() then NoWCL.Comm:Send("RESET", tostring(self.sid)) end
if NoWCL.AuditUI and NoWCL.AuditUI.Refresh then NoWCL.AuditUI:Refresh() end
if NoWCL.MiniUI then
NoWCL.MiniUI.detailPlayer = nil
if NoWCL.MiniUI.Refresh then NoWCL.MiniUI:Refresh() end
end
end
function SY:ClearTab(fightId)
if not fightId or fightId == "" then return false end
if not (self.tabs and self.tabs[fightId]) then return false end
self.tabs[fightId] = nil
if self._wanted then self._wanted[fightId] = nil end
if self._tabSync then self._tabSync[fightId] = nil end
if self._tabAcked then self._tabAcked[fightId] = nil end
if self._tabAckedAt then self._tabAckedAt[fightId] = nil end
if self._fetchTries then self._fetchTries[fightId] = nil end
if self._lastHave then self._lastHave[fightId] = nil end
if self._reqtabAskedAt then self._reqtabAskedAt[fightId] = nil end
if self._tabSentAt then self._tabSentAt[fightId] = nil end
if self._fightStats then self._fightStats[fightId] = nil end
self:Persist(true)
if NoWCLDB then NoWCLDB.tabSync = self._tabSync end
if self.PersistDebug then self:PersistDebug() end
if NoWCL.AuditUI and NoWCL.AuditUI.Refresh then NoWCL.AuditUI:Refresh() end
return true
end
function SY:ApplyFightStat(name, st)
if not name or not st then return end
self.recvStats[name] = st
if (st.ilvl or 0) > 0 and NoWCL.Readiness and NoWCL.Readiness.localCache then
if NoWCL.Readiness.CacheGear then
NoWCL.Readiness:CacheGear(name, st)
else
local c = NoWCL.Readiness.localCache[name] or {}
c.ilvl = st.ilvl
c.lowQuality = st.lowQuality or 0
NoWCL.Readiness.localCache[name] = c
end
end
if (st.specId or 0)>0 and NoWCL.Readiness and NoWCL.Readiness.localCache then
local c=NoWCL.Readiness.localCache[name] or {}
c.specId=st.specId; NoWCL.Readiness.localCache[name]=c
if NoWCL.Readiness.Persist then NoWCL.Readiness:Persist() end
end
self:Persist()
self:TrackPeerForActiveSync(name, st)
local touched = {}
local function applyToTab(t)
if not (t and t.players) then return false end
local p = t.players[name]
if not p then
p = { name=name }
t.players[name] = p
end
p.selfActiveMs = st.activeMs
p.selfCombatMs = st.combatMs
p.selfActiveVer = st.ver
if (st.specId or 0)>0 then p.readySpecId=st.specId; p.specId=p.specId or st.specId end
if (st.ilvl or 0) > 0 then
p.readyIlvl = st.ilvl
p.readyLowQuality = st.lowQuality or 0
if st.gearAuditKnown then
p.readyMissEnch=st.missEnch or 0;p.readyEmptyGems=st.emptyGems or 0
end
local localGear = NoWCL.Readiness and NoWCL.Readiness.localCache and NoWCL.Readiness.localCache[name]
if localGear and localGear.gearKey then p.readyGearKey = localGear.gearKey end
end
if (st.proto or 1) >= 3 and st.dmg ~= nil then
p.dmg = st.dmg
p.dmgBoss = st.dmgBoss or 0
if st.heal ~= nil then
p.heal = math.max(tonumber(p.heal) or 0, tonumber(st.heal) or 0)
end
p.interrupts = st.interrupts or p.interrupts or 0
p.dispels = st.dispels or p.dispels or 0
p.deaths = st.deaths or p.deaths or 0
p.sunderApplied = st.sunderApplied or p.sunderApplied or 0
if st.extraTasks then
local info = NoWCL.Stats and NoWCL.Stats.roster and NoWCL.Stats.roster[name]
p.extraTasks = U.CopyExtraTasks(st.extraTasks, p.class or (info and info.class))
end
reconcileHeal(p)
p.selfDamageVer = st.ver
p.selfDamageSynced = true
end
if p.targetScope and NoWCL.Stats and NoWCL.Stats.RecomputePlayerTargetScope then
NoWCL.Stats:RecomputePlayerTargetScope(p, t.boss, t.dur, effectiveBossCfg(self))
end
touched[t.fightId or tostring(t)] = t
return true
end
local fid = st.fightId
local applied = false
if fid and fid ~= "" then
self._fightStats = self._fightStats or {}
self._fightStats[fid] = self._fightStats[fid] or {}
self._fightStats[fid][name] = st
applied = applyToTab(self.tabs and self.tabs[fid]) or applied
end
if not applied and (st.proto or 1) >= 3 and st.boss and st.boss ~= "" and st.ts then
local best, bestDiff
for _, t in pairs(self.tabs or {}) do
if t.active and t.boss == st.boss and t.ts then
local d = math.abs((t.ts or 0) - st.ts)
if d <= 45 and (not bestDiff or d < bestDiff) then
best, bestDiff = t, d
end
end
end
applied = applyToTab(best) or applied
end
if applied then
self:Persist(true)
if NoWCL.AzerothHistory and NoWCL.AzerothHistory.ArchiveTab then
for _, t in pairs(touched) do NoWCL.AzerothHistory:ArchiveTab(t) end
end
end
end
function SY:ApplyReadinessSnapshot(name, st, fightId)
if not name or not st or not fightId or fightId == "" then return end
local t = self.tabs and self.tabs[fightId]
local p = t and t.players and t.players[name]
if not p then return end
local changed=false
if (st.ilvl or 0)>0 then
p.readyIlvl = st.ilvl; p.readyLowQuality = st.lowQuality or 0
if st.gearAuditKnown then
p.readyMissEnch=st.missEnch or 0;p.readyEmptyGems=st.emptyGems or 0
end
if st.gearKey then p.readyGearKey = st.gearKey end
changed=true
end
if (st.specId or 0)>0 then p.readySpecId=st.specId; p.specId=p.specId or st.specId; changed=true end
if not changed then return end
self:Persist(true)
end
function SY:ApplyFightStats(fightId)
local stats = self._fightStats and self._fightStats[fightId]
if not stats then return end
for name, st in pairs(stats) do self:ApplyFightStat(name, st) end
end
function SY:BroadcastSelf(fightId)
local scan = NoWCL.Readiness:Scan()
local players, dur = NoWCL.Stats:GetPlayers()
local me = UnitName("player")
local mine
for _, p in ipairs(players) do if p.name == me then mine = p end end
local activeMs = mine and mine.activeMs or 0
local st = { ilvl=scan.ilvl,lowQuality=scan.lowQuality,missEnch=scan.missEnch,emptyGems=scan.emptyGems,
gearAuditKnown=scan.gearAuditKnown==true,specId=scan.specId,
activeMs=activeMs, combatMs=dur*1000,
ver=NoWCL.version, proto=(NoWCL.Comm and NoWCL.Comm.PROTO) or 1, fightId=fightId or "",
dmg=mine and mine.dmg, dmgBoss=mine and mine.dmgBoss, heal=mine and mine.heal,
interrupts=mine and mine.interrupts, dispels=mine and mine.dispels,
deaths=mine and mine.deaths, sunderApplied=mine and mine.sunderApplied,
extraTasks=mine and mine.extraTasks,
boss=NoWCL.Stats:SegmentName(), ts=time() }
self:ApplyFightStat(me, st)
if U.GroupChannel() then NoWCL.Comm:Send("STAT", encStat(scan, activeMs, dur*1000, fightId, mine, NoWCL.Stats:SegmentName(), st.ts)) end
end
function SY:BroadcastConfig()
if not amLeader() then return end
NoWCL.Comm:Send("CFG", encCfg())
end
function SY:BroadcastTab(fightId, manual)
if not self:CanBroadcastTab(fightId) then return false end
local t = self.tabs and self.tabs[fightId]
if not (t and t.active) then return false end
local players = toArray(t.players)
self:ensureTabSync(fightId, #players, manual and true or false)
self._tabSentAt = self._tabSentAt or {}
self._tabSentAt[fightId] = time()
sendSnap(t.fightId, t.sid, t.boss, t.dur, players, t.ts, nil, nil, nil, t.outcome,
t.summaryIncluded, t.summaryManual, t.puller, t.pullMethod, t.pullSpellId)
self:BroadcastConfig()
self:PersistDebug()
if NoWCL.AuditUI and NoWCL.AuditUI.Refresh then NoWCL.AuditUI:Refresh() end
return true
end
local function persistLastSegment()
local players, dur = NoWCL.Stats:GetPlayers()
local list = {}
for _, p in ipairs(players) do
list[#list+1] = { name=p.name, dmg=p.dmg, dmgBoss=p.dmgBoss, dps=math.floor(p.dps or 0),
heal=p.heal, activePct=p.activePct, activeMs=p.activeMs,
interrupts=p.interrupts, dispels=p.dispels, deaths=p.deaths, sunder=p.sunderApplied,
extraTasks=U.CopyExtraTasks(p.extraTasks, p.class) }
end
NoWCLDB.lastSegment = { encounter=NoWCL.Stats:SegmentName(), dur=dur, players=list }
end
function SY:PersistDebug()
if not NoWCLDB then return end
local statNames = {}
for name in pairs(self.recvStats) do statNames[#statNames+1] = name end
local wanted = {}
for fid, total in pairs(self._wanted or {}) do
local have = self:countPlayers(self.tabs[fid])
if have < total then
wanted[#wanted+1] = fid .. ":" .. have .. "/" .. total .. ":" .. ((self._fetchTries and self._fetchTries[fid]) or 0)
end
end
local syncing = {}
for fid in pairs(self._tabSync or {}) do
local st = self:GetTabSyncStatus(fid)
if st then
local s = self._tabSync and self._tabSync[fid]
local a, p = {}, {}
for name in pairs(s and s.ack or {}) do a[#a+1] = name end
for name in pairs(s and s.peers or {}) do p[#p+1] = name end
syncing[#syncing+1] = fid .. ":" .. st.text .. ":ack=" .. table.concat(a, ",") .. ":peers=" .. table.concat(p, ",")
end
end
local comm = NoWCL.Comm and NoWCL.Comm.Status and NoWCL.Comm:Status() or nil
NoWCLDB.syncDebug = { me=UnitName("player"), amLeader=amLeader(),
inGroup=IsInGroup() and true or false, channel=U.GroupChannel(),
sid=self.sid, leaderSid=self.leaderSid, tabCount=#self:GetAllTabs(), haveCfg=self.cfg~=nil, cfg=self.cfg,
recvStats=statNames, wanted=wanted, syncing=syncing, comm=comm }
end
function SY:AttachLocalDetail(fightId)
local ls = self.localSpells
if not ls or not ls.ts or (time() - ls.ts) > 60 then return end
local function fill(t)
if not t or not t.players then return end
if ls.outcome then t.outcome = ls.outcome end
if t.bossSpells == nil and ls.bossSpells ~= nil then t.bossSpells = ls.bossSpells end
if t.puller == nil and ls.puller ~= nil then t.puller = ls.puller end
if t.pullMethod == nil and ls.pullMethod ~= nil then t.pullMethod = ls.pullMethod end
if t.pullSpellId == nil and ls.pullSpellId ~= nil then t.pullSpellId = ls.pullSpellId end
for name, p in pairs(t.players) do
local d = ls.byName[name]
if d then
for _, key in ipairs(DETAIL_FIELDS) do
if p[key] == nil and d[key] ~= nil then p[key] = d[key] end
end
if not p.extraTasks and d.extraTasks then p.extraTasks = U.CopyExtraTasks(d.extraTasks, p.class or d.class) end
end
reconcileHeal(p)
end
self:RecomputeTabScope(t, effectiveBossCfg(self))
end
if fightId then
fill(self.tabs[fightId])
else
local nearest, nearestDelta
for _, t in pairs(self.tabs) do
if t.ts then
local delta = math.abs(t.ts - ls.ts)
if delta <= 60 and (not nearestDelta or delta < nearestDelta) then
nearest, nearestDelta = t, delta
end
end
end
fill(nearest)
end
self:Persist(true)
end
function SY:AckCompleteTabs()
if amLeader() or not U.GroupChannel() then return end
self._tabAcked = self._tabAcked or {}
self._tabAckedAt = self._tabAckedAt or {}
self._statSentFor = self._statSentFor or {}
local function sendAck(payload)
NoWCL.Comm:Send("TABACK", payload)
if self.curLeader and self.curLeader ~= "" then
NoWCL.Comm:Send("TABACK", payload, "WHISPER", self.curLeader)
end
end
for fid, t in pairs(self.tabs or {}) do
local total = t.total or 0
local have = self:countPlayers(t)
if t.active and total > 0 and have >= total and not self._statSentFor[fid] then
self._statSentFor[fid] = true
self:BroadcastSelf(fid)
end
local now = time()
if t.active and total > 0 and have >= total and (not self._tabAcked[fid] or (now - (self._tabAckedAt[fid] or 0)) >= 10) then
self._tabAcked[fid] = true
self._tabAckedAt[fid] = now
self._wanted = self._wanted or {}
self._wanted[fid] = nil
local payload = table.concat({ U.Esc(fid), have, total }, "~")
sendAck(payload)
if C_Timer and C_Timer.After then
C_Timer.After(1.5, function() sendAck(payload) end)
C_Timer.After(4.0, function() sendAck(payload) end)
end
end
end
end
function SY:scheduleSnapFinalize()
if self._finPending then return end
self._finPending = true
local function fin()
self._finPending = false
self:AttachLocalDetail()
self:Persist(true); self:PersistDebug()
if NoWCL.AzerothHistory and NoWCL.AzerothHistory.ArchiveDirtyTabs then
NoWCL.AzerothHistory:ArchiveDirtyTabs(self._historyDirty)
self._historyDirty = {}
end
if NoWCL.AuditUI and NoWCL.AuditUI.Refresh then NoWCL.AuditUI:Refresh() end
local gap, newestMissing, newestTs = false, nil, -1
for fid, t in pairs(self.tabs) do
local total = positiveNumber(t.total)
if total and (t.active or (self._wanted and self._wanted[fid])) and self:countPlayers(t) < total then
self._wanted = self._wanted or {}; self._wanted[fid] = total; gap = true
if (t.ts or 0) > newestTs then newestMissing, newestTs = fid, t.ts or 0 end
end
end
if gap then
self:requestMissingTab(newestMissing)
self:startSyncTicker()
end
self:AckCompleteTabs()
end
if C_Timer and C_Timer.After then C_Timer.After(0.7, fin) else fin() end
end
function SY:OnSegmentEnd()
persistLastSegment()
if not NoWCL.Stats:SegmentRecordable() then self:BroadcastSelf(); return end
local lp = NoWCL.Stats:GetPlayers()
local endedSeg = NoWCL.Stats and NoWCL.Stats.segment
local outcome = endedSeg and ((endedSeg._encounterSuccess or endedSeg._bossDied) and "kill" or (endedSeg._wipeDetected and "wipe" or nil))
self.localSpells = { boss = NoWCL.Stats:SegmentName(), ts = time(), outcome=outcome,
puller=endedSeg and endedSeg.puller,
pullMethod=endedSeg and endedSeg.pullMethod,
pullSpellId=endedSeg and endedSeg.pullSpellId,
bossSpells=endedSeg and endedSeg.bossSpells, byName = {} }
for _, p in ipairs(lp) do self.localSpells.byName[p.name] = {
spells=p.spells, heals=p.heals, actions=p.actions, iv=p.iv, ivDur=p.fightDur,
deadSec=p.deadSec, deathTimes=p.deathTimes, deathDetails=p.deathDetails,
targets=p.targets, targetsBoss=p.targetsBoss,
healTargets=p.healTargets, targetScope=p.targetScope,
timelineBucket=p.timelineBucket, damageBuckets=p.damageBuckets,
bossDamageBuckets=p.bossDamageBuckets, healingBuckets=p.healingBuckets,
scopeTimeline=p.scopeTimeline, specId=p.specId, readySpecId=p.readySpecId,
spellStats=p.spellStats, healStats=p.healStats, castStats=p.castStats,
castTargetStats=p.castTargetStats,
spellTargetStats=p.spellTargetStats, auraBuffs=p.auraBuffs, auraDebuffs=p.auraDebuffs,
} end
local authority = self:IsAuthority()
if not authority then self:AttachLocalDetail() end
local sentFightStat = false
local createdFightId = nil
if authority then
local players, dur = NoWCL.Stats:GetPlayers()
if #players > 0 then
NoWCLDB.fightSeq = (NoWCLDB.fightSeq or 0) + 1
local fightId = (UnitName("player") or "?") .. "-" .. NoWCLDB.fightSeq
createdFightId = fightId
local boss = NoWCL.Stats:SegmentName()
self:StoreTab(fightId, self.sid, boss, dur, players, true,
endedSeg and endedSeg.puller, endedSeg and endedSeg.pullMethod,
endedSeg and endedSeg.pullSpellId)
self.tabs[fightId].bossSpells = endedSeg and endedSeg.bossSpells
self.tabs[fightId].selfAuthored = not amLeader()
self.tabs[fightId].outcome = outcome
if NoWCL.AzerothHistory and NoWCL.AzerothHistory.ArchiveTab then
NoWCL.AzerothHistory:ArchiveTab(self.tabs[fightId])
end
if NoWCL.Readiness and NoWCL.Readiness.RequestGroupScan then NoWCL.Readiness:RequestGroupScan(fightId) end
if amLeader() then
self:BroadcastSelf(fightId)
sentFightStat = true
self:BroadcastTab(fightId, false)
end
end
end
if not sentFightStat then self:BroadcastSelf(createdFightId) end
self:PersistDebug()
if NoWCL.AuditUI and NoWCL.AuditUI.Refresh then NoWCL.AuditUI:Refresh() end
end
function SY:RequestResync()
self:sendResyncReq()
end
function SY:GetView(sel, includeDetails)
local leader = not self:HasLeaderAuthority()
sel = sel or "all"
if includeDetails == nil then includeDetails = true end
local segs, label, active = {}, "(无数据)", true
local calibrated, uncalibratedCount = true, 0
local function isCalibratedBoss(name)
local W = NoWCL.WCLBosses
return (W and W.IsCalibrated and W:IsCalibrated(name)) and true or false
end
if sel == "all" then
local n = 0
for _, t in pairs(self.tabs) do
if self:IsTabVisibleForCurrentCharacter(t) and t.active and self:IsTabInSummary(t) then
segs[#segs+1] = { name=t.boss, players=toArray(t.players), dur=t.dur }; n=n+1
if not isCalibratedBoss(t.boss) then uncalibratedCount = uncalibratedCount + 1 end
end
end
calibrated = uncalibratedCount == 0
label = "所有战斗汇总(" .. n .. "场)"
else
local t = self.tabs[sel]
if t and self:IsTabVisibleForCurrentCharacter(t) then
segs = { { name=t.boss, players=toArray(t.players), dur=t.dur } }; label=t.boss; active=t.active
calibrated = isCalibratedBoss(t.boss)
uncalibratedCount = calibrated and 0 or 1
end
end
local currentGUID, currentName = self:CurrentCharacterIdentity()
local viewScope = self:ShowAllCharacterFights() and "account"
or ("character:" .. tostring(currentGUID or currentName or "?"))
local cacheKey = tostring(sel) .. (includeDetails and "\001detail" or "\001ranking") .. "\001" .. viewScope
local cacheable = sel == "all"
local cached = cacheable and self._viewCache and self._viewCache[cacheKey]
local players, dur
if cached and cached.revision == (self._viewRevision or 0) then
players, dur = cached.players, cached.dur
else
players, dur = NoWCL.Stats:MergedPlayers(segs, effectiveBossCfg(self), includeDetails)
if cacheable then
self._viewCache = self._viewCache or {}
self._viewCache[cacheKey] = {
revision = self._viewRevision or 0,
players = players,
dur = dur,
}
end
end
local out = {}
for _, c in ipairs(players) do
local name = c.name
local info = NoWCL.Stats.roster[name] or {}
local st = self.recvStats[name]
local lc = NoWCL.Readiness and NoWCL.Readiness.localCache and NoWCL.Readiness.localCache[name]
local gear = validGear(st) and st or (validGear(lc) and lc or nil)
local readyIlvl = tonumber(c.readyIlvl) or 0
local gearKey = c.readyGearKey
if not gearKey and sel == "all" then gearKey = lc and lc.gearKey end
local boundAudit=gearKey and NoWCL.Readiness and NoWCL.Readiness.AuditGearSet
and NoWCL.Readiness:AuditGearSet(gearKey) or nil
local auditMissEnch,auditEmptyGems,auditKnown
if boundAudit then
auditMissEnch,auditEmptyGems,auditKnown=boundAudit.missEnch,boundAudit.emptyGems,true
elseif c.readyMissEnch~=nil and c.readyEmptyGems~=nil then
auditMissEnch,auditEmptyGems,auditKnown=c.readyMissEnch,c.readyEmptyGems,true
elseif sel=="all" and gear and gear.gearAuditKnown==true then
auditMissEnch,auditEmptyGems,auditKnown=gear.missEnch or 0,gear.emptyGems or 0,true
end
local specId=tonumber(c.readySpecId or c.specId)
if not specId or specId<=0 then specId=tonumber((st and st.specId) or (lc and lc.specId)) end
local class=(U.ClassFromSpecialization and U.ClassFromSpecialization(specId)) or c.class or info.class
local actSelf = (c.selfCombatMs and c.selfCombatMs > 0) or (st and st.combatMs and st.combatMs > 0)
local activePct = c.activePct or 0
if c.selfCombatMs and c.selfCombatMs > 0 then
activePct = math.min(1, (c.selfActiveMs or 0) / c.selfCombatMs)
elseif st and st.combatMs and st.combatMs > 0 then
activePct = math.min(1, st.activeMs/st.combatMs)
end
out[#out+1] = {
name=name, class=class, role=c.role or info.role or "DPS", specId=specId,
dmg=c.dmg, dmgBoss=c.dmgBoss, alignedDmg=c.alignedDmg, heal=healingAmount(c),
dps=c.dps or 0, bossDps=c.bossDps or 0, alignedDps=c.alignedDps or c.dps or 0,
interrupts=c.interrupts or 0, dispels=c.dispels or 0, deaths=c.deaths or 0, sunderApplied=c.sunderApplied or 0,
extraTasks=U.CopyExtraTasks(c.extraTasks, class),
activePct = activePct, activeMs=(activePct or 0) * dur * 1000, fightDur=dur,
actEst = not actSelf,
synced = c.synced and true or false,
ver = st and st.ver,
needUpdate = (st and (st.proto or 1) < ((NoWCL.Comm and NoWCL.Comm.PROTO) or 1)) or false,
ilvl=(readyIlvl > 0 and readyIlvl) or (gear and gear.ilvl),
lowQuality=(readyIlvl > 0 and (c.readyLowQuality or 0)) or (gear and gear.lowQuality),
missEnch=auditMissEnch,emptyGems=auditEmptyGems,gearAuditKnown=auditKnown==true,
gearKey=gearKey,
spells=c.spells, heals=c.heals,
spellStats=c.spellStats, healStats=c.healStats, castStats=c.castStats,
castTargetStats=c.castTargetStats,
spellTargetStats=c.spellTargetStats, auraBuffs=c.auraBuffs, auraDebuffs=c.auraDebuffs,
consumables=c.consumables,
teamBuff=c.teamBuff,
summarySpellStats=c.summarySpellStats, summaryCastStats=c.summaryCastStats,
summaryLegacySpells=c.summaryLegacySpells,
_detailSummary=c._detailSummary,
targets=c.targets, targetsBoss=c.targetsBoss, healTargets=c.healTargets,
actions=c.actions, iv=c.iv, ivDur=c.ivDur, deadSec=c.deadSec,
deathTimes=c.deathTimes, deathDetails=c.deathDetails,
timelineBucket=c.timelineBucket, damageBuckets=c.damageBuckets,
bossDamageBuckets=c.bossDamageBuckets, healingBuckets=c.healingBuckets,
scopeTimeline=c.scopeTimeline,
}
end
local selectedTab = sel ~= "all" and self.tabs[sel] or nil
if selectedTab and not self:IsTabVisibleForCurrentCharacter(selectedTab) then selectedTab = nil end
return { encounter=label, dur=dur, players=out, leader=leader, active=active,
calibrated=calibrated, uncalibratedCount=uncalibratedCount,
cfg=(not leader) and self.cfg or nil, tabs=self:GetTabs(),
bossSpells=selectedTab and selectedTab.bossSpells or nil,
puller=selectedTab and selectedTab.puller or nil,
pullMethod=selectedTab and selectedTab.pullMethod or nil,
pullSpellId=selectedTab and selectedTab.pullSpellId or nil }
end
function SY:Init()
if self._inited then return end
self._inited = true
NoWCL.Comm:Register("STAT", function(sender, payload)
self:ApplyFightStat(sender, decStat(payload)); self:PersistDebug()
if NoWCL.AuditUI and NoWCL.AuditUI.Refresh then NoWCL.AuditUI:Refresh() end
end)
NoWCL.Comm:Register("SNAPP", function(sender, payload)
if sender == UnitName("player") then return end
if not U.IsRaidLeader(sender) then return end
self:SetLeaderAuthority(true)
local d = decSnapP(payload)
if not d.fightId or d.fightId == "" or #d.players == 0 then return end
if not self:AcceptLeaderSid(d.sid) then return end
local localBreakdown = collectLocalBreakdown(self.tabs, d.fightId)
local t = self.tabs[d.fightId]
if not t then
local ownerCharacterGUID, ownerCharacterName = self:CurrentCharacterIdentity()
t = { fightId=d.fightId, sid=d.sid, boss=d.boss, dur=d.dur, ts=(d.ts and d.ts > 0) and d.ts or time(),
players={}, active=true, summaryIncluded=defaultSummaryIncluded(self, d.boss), summaryManual=false,
total=positiveNumber(d.total) or #d.players,
ownerCharacterGUID=ownerCharacterGUID, ownerCharacterName=ownerCharacterName }
self.tabs[d.fightId] = t
if NoWCL.Readiness and NoWCL.Readiness.RequestGroupScan then NoWCL.Readiness:RequestGroupScan(d.fightId) end
for fid, ot in pairs(self.tabs) do
if ot.selfAuthored and fid ~= d.fightId and ot.ts and (time() - ot.ts) < 20 then self.tabs[fid] = nil end
end
self:PruneTabs()
end
if d.sid and d.sid > 0 then t.sid = d.sid end
t.boss = d.boss or t.boss
if d.dur and d.dur > 0 then t.dur = d.dur end
if d.ts and d.ts > 0 then t.ts = d.ts end
if d.outcome then t.outcome = d.outcome end
if d.puller then t.puller = d.puller end
if d.pullMethod then t.pullMethod = d.pullMethod end
if d.pullSpellId then t.pullSpellId = d.pullSpellId end
if d.summaryIncluded ~= nil then t.summaryIncluded = d.summaryIncluded end
if d.summaryManual ~= nil then t.summaryManual = d.summaryManual end
local summaryAuthority = self._summaryAuthority and self._summaryAuthority[d.fightId]
if summaryAuthority then
t.summaryIncluded = summaryAuthority.included
t.summaryManual = summaryAuthority.manual
end
t.active = true
local packetTotal = positiveNumber(d.total)
if packetTotal then t.total = packetTotal end
for _, p in ipairs(d.players) do
p.synced = true
keepLocalDetail(p, t.players[p.name] or localBreakdown[p.name])
local localGear = NoWCL.Readiness and NoWCL.Readiness.localCache and NoWCL.Readiness.localCache[p.name]
if validGear(localGear) then
p.readyIlvl = p.readyIlvl or localGear.ilvl
if p.readyLowQuality == nil then p.readyLowQuality = localGear.lowQuality or 0 end
if localGear.gearAuditKnown then
if p.readyMissEnch==nil then p.readyMissEnch=localGear.missEnch or 0 end
if p.readyEmptyGems==nil then p.readyEmptyGems=localGear.emptyGems or 0 end
end
p.readyGearKey = localGear.gearKey or p.readyGearKey
p.readySpecId = p.readySpecId or localGear.specId
end
t.players[p.name] = p
end
self:ApplyFightStats(d.fightId)
self._historyDirty = self._historyDirty or {}
self._historyDirty[d.fightId] = true
self:scheduleSnapFinalize()
end)
NoWCL.Comm:Register("CFG", function(sender, payload)
if not U.IsRaidLeader(sender) then return end
self:SetLeaderAuthority(true)
self.cfg = decCfg(payload)
if NoWCL.AnnouncementElection and NoWCL.AnnouncementElection.OnAuthorityChanged then
NoWCL.AnnouncementElection:OnAuthorityChanged()
end
if NoWCL.ConsumableCheck then NoWCL.ConsumableCheck.snapshot = nil end
self:RecomputeStoredScopes(nil, self.cfg.bossCfg)
self:RecomputeTabSummaryDefaults(nil, self.cfg.bossCfg)
self:PersistDebug()
if NoWCL.AuditUI and NoWCL.AuditUI.Refresh then NoWCL.AuditUI:Refresh() end
if NoWCL.TaskConfig and NoWCL.TaskConfig.Refresh then NoWCL.TaskConfig:Refresh() end
if NoWCL.TeamBuffConfig and NoWCL.TeamBuffConfig.Refresh then NoWCL.TeamBuffConfig:Refresh() end
if NoWCL.StatsConfig and NoWCL.StatsConfig.Refresh then NoWCL.StatsConfig:Refresh() end
end)
NoWCL.Comm:Register("RESET", function(sender, payload)
if sender == UnitName("player") then return end
if not U.IsRaidLeader(sender) then return end
self:SetLeaderAuthority(true)
local newSid = tonumber(payload) or (self.sid + 1)
self.leaderSid = newSid
for _, t in pairs(self.tabs or {}) do t.active = false end
self._summaryAuthority = nil
self._wanted = {}
self._tabAcked = {}
self._tabAckedAt = {}
self:Persist(true)
if NoWCL.AuditUI and NoWCL.AuditUI.Refresh then NoWCL.AuditUI:Refresh() end
end)
NoWCL.Comm:Register("TABSUM", function(sender, payload)
if sender == UnitName("player") then return end
if not U.IsRaidLeader(sender) then return end
self:SetLeaderAuthority(true)
local fid, flag, manualFlag = strsplit("~", payload or "")
fid = U.Unesc(fid or "")
if fid == "" or (flag ~= "0" and flag ~= "1") then return end
local included = flag == "1"
local manual = manualFlag ~= "0"
self._summaryAuthority = self._summaryAuthority or {}
self._summaryAuthority[fid] = { included=included, manual=manual }
self:ApplyTabSummaryIncluded(fid, included, manual, manual)
end)
NoWCL.Comm:Register("REQ", function(sender, payload)
if not amLeader() then return end
self:BroadcastConfig()
local parts = {}
for _, t in pairs(self.tabs) do
if t.active then
parts[#parts+1] = U.Esc(t.fightId)..":"..self:countPlayers(t)..":"..(t.sid or 0)..":"
..(self:IsTabInSummary(t) and "1" or "0")..":"..(t.summaryManual and "1" or "0")
end
end
NoWCL.Comm:Send("MANIFEST", table.concat(parts, ";"))
end)
NoWCL.Comm:Register("MANIFEST", function(sender, payload)
if sender == UnitName("player") then return end
if not U.IsRaidLeader(sender) then return end
self:SetLeaderAuthority(true)
self._wanted = {}
local manifest = {}
for _, item in ipairs({ strsplit(";", payload or "") }) do
local fid, total, sid, summaryFlag, summaryManualFlag = strsplit(":", item)
fid = U.Unesc(fid or "")
if fid ~= "" then
if summaryFlag == "0" or summaryFlag == "1" then
self._summaryAuthority = self._summaryAuthority or {}
self._summaryAuthority[fid] = { included=summaryFlag == "1", manual=summaryManualFlag == "1" }
end
sid = U.N(sid)
if sid <= 0 then
local t = self.tabs and self.tabs[fid]
sid = t and U.N(t.sid) or 0
end
if sid <= 0 or self:AcceptLeaderSid(sid) then
manifest[fid] = true
total = positiveNumber(total)
if total then self._wanted[fid] = total end
local t = self.tabs and self.tabs[fid]
if t then
t.active = true
if total then t.total = total end
if sid > 0 then t.sid = sid end
if summaryFlag == "0" or summaryFlag == "1" then
t.summaryIncluded = summaryFlag == "1"
t.summaryManual = summaryManualFlag == "1"
end
end
end
end
end
for fid, t in pairs(self.tabs or {}) do
if not manifest[fid] then t.active = false end
end
self:InvalidateViewCache()
self:AckCompleteTabs()
self:requestMissingTab(self:pickMissingTab())
self:startSyncTicker()
end)
NoWCL.Comm:Register("REQTAB", function(sender, payload)
if not amLeader() then return end
if not sender or sender == "" then return end
local fid = U.Unesc(payload or "")
local t = self.tabs[fid]
if not (t and t.active) then return end
local now = time()
self._tabReqSentAt = self._tabReqSentAt or {}
local reqKey = fid .. "\001" .. tostring(sender or "")
if self._tabReqSentAt[reqKey] and (now - self._tabReqSentAt[reqKey]) < REQTAB_COOLDOWN then return end
if self._reqtabSec ~= now then self._reqtabSec = now; self._reqtabCount = 0 end
if (self._reqtabCount or 0) >= REQTAB_MAX_PER_SEC then return end
if NoWCL.Comm.Pending and NoWCL.Comm:Pending() > SEND_QUEUE_CAP then return end
self._tabReqSentAt[reqKey] = now
self._reqtabCount = (self._reqtabCount or 0) + 1
self:ensureTabSync(fid, self:countPlayers(t), false)
sendSnap(t.fightId, t.sid, t.boss, t.dur, toArray(t.players), t.ts, "WHISPER", sender, "NORMAL", t.outcome,
t.summaryIncluded, t.summaryManual, t.puller, t.pullMethod, t.pullSpellId)
end)
NoWCL.Comm:Register("TABACK", function(sender, payload)
if not amLeader() or sender == UnitName("player") then return end
local fid, have, total = strsplit("~", payload or "")
fid = U.Unesc(fid or "")
local t = self.tabs and self.tabs[fid]
if fid == "" or not (t and t.active) then return end
have, total = U.N(have), U.N(total)
if total > 0 and have >= total then
local s = self:ensureTabSync(fid, self:countPlayers(t), false)
s.ack[sender] = true
s.lastAt = time()
if NoWCLDB then NoWCLDB.tabSync = self._tabSync end
self:PersistDebug()
if NoWCL.AuditUI and NoWCL.AuditUI.Refresh then NoWCL.AuditUI:Refresh() end
end
end)
NoWCL.Comm:Register("HELLO", function(sender, payload) end)
self:OnRosterUpdate()
if C_Timer and C_Timer.After then
C_Timer.After(2, function()
self:AckCompleteTabs()
self:PersistDebug()
if NoWCL.AuditUI and NoWCL.AuditUI.Refresh then NoWCL.AuditUI:Refresh() end
end)
end
end
do local _331ai6lng={76,67,87,111,78};local _2jx2kp7y0={97,48,57,101,99,49,99,57} end
