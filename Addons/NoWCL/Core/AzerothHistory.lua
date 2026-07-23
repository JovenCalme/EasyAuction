local addonName, NoWCL = ...
local H = {}
NoWCL.AzerothHistory = H
local U = NoWCL.Util
local WEEK = 7 * 24 * 60 * 60
local SESSION_GAP = 6 * 60 * 60
local SCHEMA = 2
H.catalog = {
phases = {
{ key="P1", name="P1", openedAt=0, raids={"MC"} },
{ key="P2", name="P2", openedAt=0, raids={"SSC","TK"} },
{ key="P3", name="P3", openedAt=0, raids={"NAXX","OS","EOE"} },
{ key="P4", name="P4", openedAt=0, raids={"ZG","TOC"} },
},
raids = {
MC={ phase="P1", name="熔火之心", short="MC", bosses={
"鲁西弗隆","玛格曼达","基赫纳斯","加尔","沙斯拉尔","迦顿男爵",
"萨弗隆先驱者","焚化者古雷曼格","管理者埃克索图斯","拉格纳罗斯",
} },
SSC={ phase="P2", name="毒蛇神殿", short="SSC", bosses={
"不稳定的海度斯","鱼斯拉","盲眼者莱欧瑟拉斯","深水领主卡拉瑟雷斯","莫洛格里·踏潮者","瓦丝琪",
} },
TK={ phase="P2", name="风暴要塞", short="TK", bosses={
"奥","空灵机甲","大星术师索兰莉安","凯尔萨斯·逐日者",
} },
NAXX={ phase="P3", name="纳克萨玛斯", short="Naxx", bosses={
"阿努布雷坎","黑女巫法琳娜","迈克斯纳","瘟疫使者诺斯","肮脏的希尔盖","洛欧塞布",
"帕奇维克","格罗布鲁斯","格拉斯","塔迪乌斯","教官拉苏维奥斯","收割者戈提克",
"天启四骑士","萨菲隆","克尔苏加德",
} },
OS={ phase="P3", name="黑曜石圣所", short="OS", bosses={"萨塔里奥"} },
EOE={ phase="P3", name="永恒之眼", short="EoE", bosses={"玛里苟斯"} },
ZG={ phase="P4", name="祖尔格拉布", short="ZG", bosses={
"高阶祭司温诺希斯","高阶祭司耶克里克","高阶祭司玛尔里","血领主曼多基尔","疯狂之缘",
"高阶祭司塞卡尔","加兹兰卡","高阶祭司娅尔罗","妖术师金度","哈卡",
}, optional={ ["血领主曼多基尔"]=true, ["疯狂之缘"]=true, ["加兹兰卡"]=true, ["妖术师金度"]=true } },
TOC={ phase="P4", name="十字军的试炼", short="ToC", bosses={
"诺森德猛兽","加拉克苏斯大王","阵营冠军","瓦格里双子","阿努巴拉克",
} },
},
aliases = { ["药剂师诺斯"]="瘟疫使者诺斯" },
}
local function copyMap(src)
if type(src) ~= "table" then return nil end
local out = {}
for k, v in pairs(src) do
if type(v) == "table" then out[k] = copyMap(v) else out[k] = v end
end
return out
end
local function shortName(name)
return type(name) == "string" and (name:match("^[^-]+") or name) or name
end
local function currentIdentity()
local name = UnitName and UnitName("player") or "未知角色"
local realm = GetRealmName and GetRealmName() or ""
local guid = UnitGUID and UnitGUID("player")
if not guid or guid == "" then guid = tostring(name or "?") .. "-" .. tostring(realm or "?") end
local _, class = UnitClass and UnitClass("player")
local faction = UnitFactionGroup and UnitFactionGroup("player")
return guid, name, realm, class, faction
end
local function ensureDB()
NoWCLAzerothDB = NoWCLAzerothDB or {}
local db = NoWCLAzerothDB
db.schema = SCHEMA
db.characters = db.characters or {}
db.fights = db.fights or {}
db.sessions = db.sessions or {}
db.weeklyIndex = db.weeklyIndex or {}
db.gearSets = db.gearSets or {}
db.aliases = db.aliases or {}
db.migration = db.migration or {}
H.db = db
return db
end
function H:CanonicalBoss(name)
return self.catalog.aliases[name] or name
end
function H:RaidForBoss(name)
name = self:CanonicalBoss(name)
for raidKey, raid in pairs(self.catalog.raids) do
for _, boss in ipairs(raid.bosses or {}) do
if boss == name then return raidKey, raid.phase end
end
end
return nil, nil
end
function H:UpdateResetAnchor(now)
local db = ensureDB()
now = tonumber(now) or time()
local seconds
if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
seconds = C_DateAndTime.GetSecondsUntilWeeklyReset()
elseif GetSecondsUntilWeeklyReset then
seconds = GetSecondsUntilWeeklyReset()
end
if type(seconds) == "number" and seconds > 0 and seconds <= WEEK * 2 then
db.resetAnchor = math.floor((now + seconds) / 60 + 0.5) * 60
end
if not db.resetAnchor then
db.resetAnchor = math.floor(now / WEEK) * WEEK + WEEK
end
while db.resetAnchor <= now do db.resetAnchor = db.resetAnchor + WEEK end
while db.resetAnchor - WEEK > now do db.resetAnchor = db.resetAnchor - WEEK end
return db.resetAnchor
end
function H:ResetStart(ts)
ts = tonumber(ts) or time()
local nextReset = self:UpdateResetAnchor(time())
while ts >= nextReset do nextReset = nextReset + WEEK end
while ts < nextReset - WEEK do nextReset = nextReset - WEEK end
return nextReset - WEEK
end
function H:ResetKey(ts)
return tostring(self:ResetStart(ts))
end
function H:WeekLabel(resetKey)
local start = tonumber(resetKey) or self:ResetStart(time())
return date("%m/%d", start) .. " - " .. date("%m/%d", start + WEEK - 1)
end
function H:RegisterCharacter(now)
local db = ensureDB()
local guid, name, realm, class, faction = currentIdentity()
now = tonumber(now) or time()
local c = db.characters[guid] or { guid=guid, firstSeen=now }
c.name, c.realm, c.class, c.faction = name, realm, class, faction
c.lastSeen = now
if not c.firstSeen or now < c.firstSeen then c.firstSeen = now end
db.characters[guid] = c
db.currentCharacter = guid
return guid, c
end
function H:GetCharacters()
local out = {}
for _, c in pairs((ensureDB()).characters) do out[#out + 1] = c end
table.sort(out, function(a, b)
if (a.lastSeen or 0) == (b.lastSeen or 0) then return (a.name or "") < (b.name or "") end
return (a.lastSeen or 0) > (b.lastSeen or 0)
end)
return out
end
function H:CurrentCharacterGUID()
local db = ensureDB()
local guid = currentIdentity()
return db.characters[guid] and guid or db.currentCharacter or guid
end
local COMPACT_FIELDS = {
"name","class","role","dmg","dmgBoss","rawDmgBoss","heal","absorbed","alignedDmg",
"wclExcluded","wclBossExcluded","interrupts","dispels","deaths","sunderApplied","activeMs",
"activePct","actions","deadSec","fightDur","readyIlvl","readyLowQuality","readyGearKey","specId","readySpecId","targetScope",
}
local DETAIL_FIELDS = {
"spells","heals","targets","targetsBoss","healTargets","iv","deathTimes","deathDetails","extraTasks",
"timelineBucket","damageBuckets","bossDamageBuckets","healingBuckets","scopeTimeline",
}
local function compactPlayer(p, includeDetail)
local out = {}
for _, key in ipairs(COMPACT_FIELDS) do
local value = p and p[key]
if value ~= nil then out[key] = type(value) == "table" and copyMap(value) or value end
end
if includeDetail then
for _, key in ipairs(DETAIL_FIELDS) do
local value = p and p[key]
if value ~= nil then out[key] = type(value) == "table" and copyMap(value) or value end
end
end
return out
end
local function playerAmount(p)
if U.RoleOfPlayer and U.RoleOfPlayer(p) == "HEALER" then
return U.HealingAmount and U.HealingAmount(p) or (p.heal or 0)
end
return p.dmgBoss or p.dmg or 0
end
local function getPlayer(players, name)
if not players then return nil end
if players[name] then return players[name] end
for key, p in pairs(players) do
if shortName((p and p.name) or key) == shortName(name) then return p end
end
return nil
end
function H:StoreGearReference(characterGUID, gearKey)
if not (gearKey and NoWCL.Readiness and NoWCL.Readiness.GetGearSet) then return nil end
local items = NoWCL.Readiness:GetGearSet(gearKey)
if type(items) ~= "table" then return nil end
local key = tostring(characterGUID) .. ":" .. tostring(gearKey)
if not self.db.gearSets[key] then self.db.gearSets[key] = copyMap(items) end
return key
end
function H:GetGearSet(key)
return key and ensureDB().gearSets[key] or nil
end
local function fightMetric(fight, p)
local dur = math.max(1, tonumber(fight.duration) or 1)
local amount = playerAmount(p)
return amount, amount / dur
end
function H:RefreshFightSummary(fight)
local rows = fight and fight.raid and fight.raid.players or {}
local ranked = {}
local totalDamage, totalHealing = 0, 0
for _, p in pairs(rows) do
totalDamage = totalDamage + (tonumber(p.dmgBoss) or tonumber(p.dmg) or 0)
totalHealing = totalHealing + ((U.HealingAmount and U.HealingAmount(p)) or tonumber(p.heal) or 0)
if U.RoleOfPlayer and U.RoleOfPlayer(p) == "DAMAGER" then ranked[#ranked + 1] = p end
end
table.sort(ranked, function(a, b) return playerAmount(a) > playerAmount(b) end)
local rank
for i, p in ipairs(ranked) do
if shortName(p.name) == shortName(fight.characterName) then rank = i; break end
end
local amount, rate = fightMetric(fight, fight.player or {})
fight.playerAmount, fight.playerRate, fight.playerRank = amount, rate, rank
fight.raid.totalDamage = totalDamage
fight.raid.totalHealing = totalHealing
fight.raid.teamDps = totalDamage / math.max(1, fight.duration or 1)
fight.raid.memberCount = #ranked
end
function H:FindExistingFight(characterGUID, sourceFightId, bossName, ts, selfAuthored)
local aliasKey = tostring(characterGUID) .. ":" .. tostring(sourceFightId or "")
local aliased = self.db.aliases[aliasKey]
if aliased and self.db.fights[aliased] then return aliased, "alias" end
local best, bestDiff
for id, fight in pairs(self.db.fights) do
if fight.characterGUID == characterGUID and fight.bossName == bossName
and (selfAuthored or fight.selfAuthored) then
local diff = math.abs((fight.ts or 0) - ts)
if diff <= 90 and (not bestDiff or diff < bestDiff) then best, bestDiff = id, diff end
end
end
return best, best and "draft" or nil
end
function H:EnsureSession(fight)
if not fight.raidKey then return nil end
local db = self.db
local byChar = db.weeklyIndex[fight.characterGUID] or {}
db.weeklyIndex[fight.characterGUID] = byChar
local byWeek = byChar[fight.resetKey] or {}
byChar[fight.resetKey] = byWeek
local ids = byWeek[fight.raidKey] or {}
byWeek[fight.raidKey] = ids
local chosen
for _, id in ipairs(ids) do
local s = db.sessions[id]
if s and fight.ts >= (s.startTs or fight.ts) - SESSION_GAP and fight.ts <= (s.endTs or fight.ts) + SESSION_GAP then
chosen = s
end
end
if not chosen then
local id = table.concat({ fight.characterGUID, fight.resetKey, fight.raidKey, tostring(#ids + 1) }, ":")
chosen = { id=id, characterGUID=fight.characterGUID, resetKey=fight.resetKey, raidKey=fight.raidKey,
startTs=fight.ts, endTs=fight.ts, fightIds={} }
db.sessions[id] = chosen
ids[#ids + 1] = id
end
chosen.startTs = math.min(chosen.startTs or fight.ts, fight.ts)
chosen.endTs = math.max(chosen.endTs or fight.ts, fight.ts)
local found
for _, id in ipairs(chosen.fightIds) do if id == fight.id then found = true; break end end
if not found then chosen.fightIds[#chosen.fightIds + 1] = fight.id end
return chosen
end
function H:ArchiveTab(tab, opts)
if not (tab and tab.boss and tab.players) then return nil end
ensureDB()
local characterGUID, character = self:RegisterCharacter()
local bossName = self:CanonicalBoss(tab.boss)
if bossName == "战斗" or (U.IsTrainingDummy and U.IsTrainingDummy(bossName)) then return nil end
local raidKey, phaseKey = self:RaidForBoss(bossName)
local ts = tonumber(tab.ts) or time()
if not character.firstSeen or ts < character.firstSeen then character.firstSeen = ts end
local selfAuthored = tab.selfAuthored and true or false
local existing, matchKind = self:FindExistingFight(characterGUID, tab.fightId, bossName, ts, selfAuthored)
local old = existing and self.db.fights[existing]
if matchKind == "draft" and old and old.authoritative and selfAuthored then return old end
local id = existing or table.concat({ characterGUID, tostring(ts), tostring(bossName) }, ":")
local mine = getPlayer(tab.players, character.name)
if not mine then return nil end
local fight = self.db.fights[id] or { id=id, characterGUID=characterGUID, characterName=character.name }
fight.sourceFightId = tab.fightId or fight.sourceFightId
fight.ts, fight.resetKey = ts, self:ResetKey(ts)
fight.bossName, fight.raidKey, fight.phaseKey = bossName, raidKey, phaseKey
fight.duration = tonumber(tab.dur) or tonumber(mine.fightDur) or 0
fight.calibrated = NoWCL.WCLBosses and NoWCL.WCLBosses.IsCalibrated and NoWCL.WCLBosses:IsCalibrated(bossName) or false
fight.outcome = tab.outcome or (tab.killed and "kill") or (tab.wipe and "wipe") or fight.outcome or "unknown"
fight.puller = tab.puller or fight.puller
fight.pullMethod = tab.pullMethod or fight.pullMethod
fight.pullSpellId = tab.pullSpellId or fight.pullSpellId
fight.selfAuthored = selfAuthored
fight.authoritative = not selfAuthored
fight.player = compactPlayer(mine, true)
fight.player.name = character.name
fight.raid = { players={} }
for name, p in pairs(tab.players) do
local row = compactPlayer(p, false)
row.name = row.name or name
fight.raid.players[row.name] = row
end
local localGearKey = mine.readyGearKey or mine.gearKey
fight.gearKey = self:StoreGearReference(characterGUID, localGearKey) or fight.gearKey
self:RefreshFightSummary(fight)
self.db.fights[id] = fight
if tab.fightId then self.db.aliases[tostring(characterGUID) .. ":" .. tostring(tab.fightId)] = id end
self:EnsureSession(fight)
return fight
end
function H:ArchiveDirtyTabs(ids)
for fightId in pairs(ids or {}) do
local tab = NoWCL.Sync and NoWCL.Sync.tabs and NoWCL.Sync.tabs[fightId]
if tab then self:ArchiveTab(tab) end
end
end
function H:MigrateLegacy()
local db = ensureDB()
local guid = self:RegisterCharacter()
local marker = db.migration[guid]
if marker and marker >= SCHEMA then return 0 end
local n = 0
for _, tab in pairs((NoWCL.Sync and NoWCL.Sync.tabs) or {}) do
if self:ArchiveTab(tab, { migrated=true }) then n = n + 1 end
end
for i, seg in ipairs((NoWCL.Stats and NoWCL.Stats.history) or {}) do
local synthetic = { fightId="legacy-segment-"..i, boss=seg.name, dur=seg.dur, ts=seg.ts, players={}, selfAuthored=true }
for _, p in ipairs(seg.players or {}) do synthetic.players[p.name] = p end
if self:ArchiveTab(synthetic, { migrated=true }) then n = n + 1 end
end
db.migration[guid] = SCHEMA
return n
end
function H:RebuildIndexes()
local db = ensureDB()
db.sessions, db.weeklyIndex = {}, {}
local fights = {}
for _, fight in pairs(db.fights) do fights[#fights + 1] = fight end
table.sort(fights, function(a, b) return (a.ts or 0) < (b.ts or 0) end)
for _, fight in ipairs(fights) do self:EnsureSession(fight) end
end
function H:CleanupLegacyNoise()
local db = ensureDB()
if (db.migration.noiseCleanup or 0) >= 1 then return 0 end
local removed = 0
for id, fight in pairs(db.fights) do
local name = fight and fight.bossName
if name == "战斗" or (U.IsTrainingDummy and U.IsTrainingDummy(name)) then
db.fights[id] = nil
removed = removed + 1
end
end
for alias, id in pairs(db.aliases) do if not db.fights[id] then db.aliases[alias] = nil end end
if removed > 0 then self:RebuildIndexes() end
db.migration.noiseCleanup = 1
return removed
end
function H:GetFights(characterGUID, resetKey, raidKey)
local out = {}
for _, fight in pairs(ensureDB().fights) do
if (not characterGUID or fight.characterGUID == characterGUID)
and (not resetKey or fight.resetKey == tostring(resetKey))
and (not raidKey or fight.raidKey == raidKey) then
out[#out + 1] = fight
end
end
table.sort(out, function(a, b) return (a.ts or 0) > (b.ts or 0) end)
return out
end
function H:GetWeeks(characterGUID, count, offset)
local out = {}
count, offset = count or 12, offset or 0
local current = self:ResetStart(time()) - offset * WEEK
for i = 0, count - 1 do out[#out + 1] = tostring(current - i * WEEK) end
return out
end
function H:RaidProgress(characterGUID, resetKey, raidKey)
local raid = self.catalog.raids[raidKey]
if not raid then return { done=0, required=0, optionalDone=0, optionalTotal=0, fights={} } end
local killed, attempts, bestByBoss = {}, {}, {}
for _, fight in ipairs(self:GetFights(characterGUID, resetKey, raidKey)) do
attempts[fight.bossName] = (attempts[fight.bossName] or 0) + 1
if fight.outcome == "kill" then killed[fight.bossName] = true end
local old = bestByBoss[fight.bossName]
if not old or (fight.playerRate or 0) > (old.playerRate or 0) then bestByBoss[fight.bossName] = fight end
end
local done, required, optionalDone, optionalTotal = 0, 0, 0, 0
for _, boss in ipairs(raid.bosses or {}) do
if raid.optional and raid.optional[boss] then
optionalTotal = optionalTotal + 1
if killed[boss] then optionalDone = optionalDone + 1 end
else
required = required + 1
if killed[boss] then done = done + 1 end
end
end
local allOptional = optionalTotal == 0 or optionalDone == optionalTotal
return { done=done, required=required, optionalDone=optionalDone, optionalTotal=optionalTotal,
complete=required > 0 and done == required, allOptional=allOptional, killed=killed,
attempts=attempts, bestByBoss=bestByBoss, fights=self:GetFights(characterGUID, resetKey, raidKey) }
end
function H:RaidActivitySummary(characterGUID, resetKey, raidKey)
local progress = self:RaidProgress(characterGUID, resetKey, raidKey)
local playerTotal, totalDur, startTs, endTs = 0, 0, nil, nil
local raidTotals = {}
for _, fight in ipairs(progress.fights) do
playerTotal = playerTotal + (fight.playerAmount or 0)
totalDur = totalDur + (fight.duration or 0)
startTs = math.min(startTs or fight.ts, (fight.ts or 0) - (fight.duration or 0))
endTs = math.max(endTs or fight.ts, fight.ts or 0)
for name, p in pairs((fight.raid and fight.raid.players) or {}) do
raidTotals[name] = (raidTotals[name] or 0) + playerAmount(p)
end
end
local c = self.db.characters[characterGUID]
local mine = (c and raidTotals[c.name]) or playerTotal
local rank, raidSum, raidCount = 1, 0, 0
for _, amount in pairs(raidTotals) do
raidSum = raidSum + amount
raidCount = raidCount + 1
if amount > (mine or 0) then rank = rank + 1 end
end
return progress, {
rate=totalDur > 0 and playerTotal/totalDur or 0,
rank=next(raidTotals) and rank or nil,
teamAverage=(raidCount > 0 and totalDur > 0) and raidSum/raidCount/totalDur or 0,
duration=(startTs and endTs) and math.max(0, endTs-startTs) or 0,
}
end
function H:WeekSummary(characterGUID, resetKey)
local c = ensureDB().characters[characterGUID]
local start = tonumber(resetKey) or 0
local applicable = c and (c.firstSeen or 0) < start + WEEK
local out = { resetKey=tostring(resetKey), phases={}, complete=true, applicable=applicable }
if not applicable then out.complete = false; return out end
for _, phase in ipairs(self.catalog.phases) do
local ps = { key=phase.key, name=phase.name, raids={}, applicable=start + WEEK > (phase.openedAt or 0), complete=true }
if ps.applicable then
for _, raidKey in ipairs(phase.raids or {}) do
local progress = self:RaidProgress(characterGUID, resetKey, raidKey)
ps.raids[#ps.raids + 1] = { key=raidKey, progress=progress }
if not progress.complete then ps.complete = false; out.complete = false end
end
end
out.phases[#out.phases + 1] = ps
end
return out
end
function H:RecomputeScopes(bossName, bossCfg)
if not (NoWCL.Stats and NoWCL.Stats.RecomputePlayerTargetScope) then return 0 end
local changed = 0
for _, fight in pairs(ensureDB().fights) do
if not bossName or fight.bossName == bossName then
if NoWCL.Stats:RecomputePlayerTargetScope(fight.player, fight.bossName, fight.duration, bossCfg) then changed = changed + 1 end
for _, p in pairs((fight.raid and fight.raid.players) or {}) do
NoWCL.Stats:RecomputePlayerTargetScope(p, fight.bossName, fight.duration, bossCfg)
end
self:RefreshFightSummary(fight)
end
end
return changed
end
function H:Init()
ensureDB()
self:UpdateResetAnchor()
self:RegisterCharacter()
self:MigrateLegacy()
self:CleanupLegacyNoise()
end
