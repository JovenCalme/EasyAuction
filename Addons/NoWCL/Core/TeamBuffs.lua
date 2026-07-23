local addonName, NoWCL = ...
local T = {}
NoWCL.TeamBuffs = T
local U = NoWCL.Util
local COMPLETE_THRESHOLD = 0.95
local READY_CHECK_COMPLETE = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14:14:0:0|t"
local DEFAULT_MONITOR_KEYS = {
stamina=true, maxHealth=true, wild=true, kings=true, intellect=true,
spirit=true, attackPower=true, manaRegen=true, sanctuary=true,
strengthAgility=true,
}
local function n(value) return tonumber(value) or 0 end
local function idSet(ids)
local out = {}
for _, spellId in ipairs(ids or {}) do out[spellId] = true end
return out
end
local function specs(...)
local out = {}
for i = 1, select("#", ...) do out[select(i, ...)] = true end
return out
end
local RULES = {
{ key="stamina", label="耐力", audience="all",
ids={1243,1244,1245,2791,10937,10938,25389,48161,21562,21564,25392,48162,67699,72590},
strongIds={48161,48162}, providers={{class="PRIEST"}}, reminderIds={PRIEST=48162} },
{ key="maxHealth", label="最大生命值", audience="all",
ids={469,47439,47440,6307,7804,7805,11766,11767,27268,47982},
strongIds={47440}, providers={{class="WARRIOR"},{class="WARLOCK",strength=1,autoReminder=false}},
reminderIds={WARRIOR=47440,WARLOCK=47982} },
{ key="wild", label="野性赐福", audience="all",
ids={1126,5232,5234,6756,8907,9884,9885,26990,48469,21849,21850,26991,48470},
strongIds={48469,48470}, providers={{class="DRUID"}}, reminderIds={DRUID=48470} },
{ key="kings", label="王者祝福", audience="all", ids={20217,25898,69378,72586},
strongIds={20217,25898}, providerSlots={PALADIN="blessing"}, assignmentPriority=40,
providers={{class="PALADIN"}}, reminderIds={PALADIN=25898},
convention={ [66]=10,[65]=20,[70]=30 } },
{ key="shadow", label="暗影防护", audience="all", optional=true,
ids={976,10957,10958,25433,48169,27683,39374,48170},
providers={{class="PRIEST"}}, reminderIds={PRIEST=48170} },
{ key="intellect", label="智力", audience="mana",
ids={1459,1460,1461,10156,10157,27126,42995,23028,27127,43002,61316,57567},
strongIds={42995,43002,61316}, providers={{class="MAGE"},{class="WARLOCK",strength=1,autoReminder=false}},
reminderIds={MAGE=43002,WARLOCK=57567} },
{ key="spirit", label="精神", audience="spirit",
ids={14752,14818,14819,27841,25312,48073,27681,32999,48074,57567},
strongIds={48073,48074}, providers={{class="PRIEST"},{class="WARLOCK",strength=1,autoReminder=false}},
reminderIds={PRIEST=48074,WARLOCK=57567} },
{ key="attackPower", label="攻击强度", audience="physical",
ids={19740,19834,19835,19836,19837,19838,25291,27140,48931,48932,
25782,25916,27141,48933,48934,6673,5242,6192,11549,11550,11551,
25289,2048,47436},
strongIds={48932,48934,2048,47436}, providerSlots={PALADIN="blessing"}, assignmentPriority=20,
providers={{class="PALADIN"},{class="WARRIOR"}},
reminderIds={PALADIN=48934,WARRIOR=47436}, convention={ [70]=10,[66]=20,[65]=30 } },
{ key="manaRegen", label="法力回复", audience="mana",
ids={19742,19850,19852,19853,19854,25290,27142,48935,48936,
25894,25918,27143,48937,48938,5675,10495,10496,10497,25570,58771,58773,58774},
strongIds={48936,48938,58773,58774}, providerSlots={PALADIN="blessing",SHAMAN="water"}, assignmentPriority=30,
providers={{class="PALADIN"},{class="SHAMAN",autoReminder=false}},
reminderIds={PALADIN=48938,SHAMAN=58774}, convention={ [65]=10,[264]=15,[70]=20,[66]=30 } },
{ key="sanctuary", label="庇护祝福", audience="tank", ids={20911,25899},
strongIds={20911,25899}, providerSlots={PALADIN="blessing"}, assignmentPriority=10,
providers={{class="PALADIN"}}, reminderIds={PALADIN=25899},
convention={ [66]=10,[65]=20,[70]=30 } },
{ key="armor", label="护甲", audience="tank",
ids={465,10290,643,10291,1032,10292,10293,27149,48941,48942,
8071,8154,8155,10406,10407,10408,25508,25509,58751,58753},
strongIds={48941,48942,58751,58753}, providerSlots={SHAMAN="earth"}, assignmentPriority=90,
providers={{class="PALADIN"},{class="SHAMAN"}},
reminderIds={PALADIN=48942,SHAMAN=58753}, convention={ [66]=10,[264]=20,[263]=30,[262]=40 } },
{ key="strengthAgility", label="力量敏捷", audience="physical",
ids={57623,8075,8160,8161,10442,25361,25528,57622,58643},
strongIds={57623,58643}, providerSlots={SHAMAN="earth"}, assignmentPriority=50,
providers={{class="DEATHKNIGHT"},{class="SHAMAN",autoReminder=false}},
reminderIds={DEATHKNIGHT=57623,SHAMAN=58643} },
{ key="meleeHaste", label="近战急速", audience="physical",
ids={8512,8515,10607,10611,10613,10614,25583,25585,58782,58785,55610},
strongIds={58782,58785,55610}, providerSlots={SHAMAN="air"}, assignmentPriority=60,
providers={{class="SHAMAN"},{class="DEATHKNIGHT",specs=specs(251)}},
reminderIds={SHAMAN=8512,DEATHKNIGHT=55610}, convention={ [263]=10,[251]=10,[262]=30,[264]=30 } },
{ key="meleeCrit", label="近战暴击", audience="physical", ids={24932,29801},
providers={{class="DRUID",specs=specs(103,104)},{class="WARRIOR",specs=specs(72)}},
reminderIds={DRUID=24932,WARRIOR=29801} },
{ key="spellPower", label="法术强度", audience="spell",
ids={57722,57663,48090,58656,52109,58649,58652,58654}, excludedIds={63283},
strongIds={57722,57663,48090}, providerSlots={SHAMAN="fire"}, assignmentPriority=70,
providers={{class="SHAMAN"},{class="WARLOCK",specs=specs(266),triggered=true}},
reminderIds={SHAMAN={ [262]=57722,default=58656 },WARLOCK=48090} },
{ key="spellHaste", label="法术急速", audience="spell", ids={3738},
providerSlots={SHAMAN="air"}, assignmentPriority=55,
providers={{class="SHAMAN"}}, reminderIds={SHAMAN=3738} },
{ key="spellCrit", label="法术暴击", audience="spell", ids={24907,51470,57722,57663}, excludedIds={63283},
providerSlots={SHAMAN="fire"}, assignmentPriority=65,
providers={{class="DRUID",specs=specs(102)},{class="SHAMAN",specs=specs(262)}},
reminderIds={DRUID=24907,SHAMAN=57722} },
{ key="percentAttackPower", label="10%攻击强度", audience="physical",
ids={19506,30809,53137,53138}, providers={
{class="HUNTER",specs=specs(254)},{class="SHAMAN",specs=specs(263),triggered=true},
{class="DEATHKNIGHT",specs=specs(250),triggered=true}},
reminderIds={HUNTER=19506,SHAMAN=30809,DEATHKNIGHT=53138} },
{ key="damage", label="3%伤害", audience="damage", optional=true,
ids={31869,31579,31582,31583,34455,34459,34460,75447,75593}, providers={
{class="PALADIN",specs=specs(70)},{class="MAGE",specs=specs(62)},
{class="HUNTER",specs=specs(253)}},
reminderIds={PALADIN=31869,MAGE=31583,HUNTER=75593} },
{ key="haste", label="3%急速", audience="all", optional=true, ids={48396,53648},
providers={{class="DRUID",specs=specs(102)},{class="PALADIN",specs=specs(70)}},
reminderIds={DRUID=48396,PALADIN=53648} },
{ key="healingReceived", label="6%受疗", audience="all", ids={33891,34123,20138,20139,20140},
providers={{class="DRUID",specs=specs(105)},{class="PALADIN",specs=specs(66),triggered=true}},
reminderIds={DRUID=34123,PALADIN=20140} },
{ key="damageReduction", label="3%减伤", audience="all", ids={20911,25899,63944},
providerSlots={PALADIN="blessing"}, assignmentPriority=15,
providers={{class="PALADIN",specs=specs(66)},{class="PRIEST",specs=specs(256),triggered=true}},
reminderIds={PALADIN=25899,PRIEST=63944}, convention={ [66]=10,[65]=20,[70]=30 } },
{ key="replenishment", label="团队回蓝", audience="mana", optional=true, ids={57669,61782}, sourceOnly=true,
providers={{class="PALADIN",specs=specs(70),triggered=true},{class="PRIEST",specs=specs(258),triggered=true},
{class="HUNTER",specs=specs(255),triggered=true},{class="WARLOCK",specs=specs(267),triggered=true},
{class="MAGE",specs=specs(64),triggered=true}},
reminderIds={PALADIN=57669,PRIEST=57669,HUNTER=57669,WARLOCK=57669,MAGE=57669} },
}
T.RULES = RULES
local ruleByKey = {}
local trackedAuraIds = {}
local excludedTrackedAuraIds = {}
for _, rule in ipairs(RULES) do
rule.idSet = idSet(rule.ids)
rule.strongIdSet = rule.strongIds and idSet(rule.strongIds) or nil
rule.excludedIdSet = rule.excludedIds and idSet(rule.excludedIds) or nil
for spellId in pairs(rule.idSet) do trackedAuraIds[spellId] = true end
for spellId in pairs(rule.excludedIdSet or {}) do excludedTrackedAuraIds[spellId] = true end
ruleByKey[rule.key] = rule
end
function T:GetRule(key) return ruleByKey[key] end
function T:DefaultMonitorEnabled(ruleOrKey)
local rule = type(ruleOrKey) == "table" and ruleOrKey or ruleByKey[ruleOrKey]
return rule and DEFAULT_MONITOR_KEYS[rule.key] == true or false
end
function T:MonitorConfig()
local sync = NoWCL.Sync
local followsLeader = sync and sync.HasLeaderAuthority
and sync:HasLeaderAuthority()
if followsLeader and sync.cfg then
return sync.cfg.teamBuffChecks or {}
end
local settings = NoWCL.db and NoWCL.db.settings
return settings and settings.teamBuffChecks or {}
end
function T:ProviderOverrideConfig()
local sync = NoWCL.Sync
local followsLeader = sync and sync.HasLeaderAuthority
and sync:HasLeaderAuthority()
if followsLeader and sync.cfg then
return sync.cfg.teamBuffProviderOverrides or {}
end
local settings = NoWCL.db and NoWCL.db.settings
return settings and settings.teamBuffProviderOverrides or {}
end
function T:PackProviderOverrides(config)
local out = {}
config = config or self:ProviderOverrideConfig()
for _, rule in ipairs(RULES) do
local name = type(config[rule.key]) == "string" and config[rule.key] or nil
if name and name ~= "" then
out[#out + 1] = rule.key .. "|" .. (U and U.Esc and U.Esc(name) or name)
end
end
return table.concat(out, ";")
end
function T:UnpackProviderOverrides(payload)
local out = {}
payload = tostring(payload or "")
for item in payload:gmatch("[^;]+") do
local key, name = item:match("^([^|]+)|(.+)$")
if ruleByKey[key] and name and name ~= "" then
name = U and U.Unesc and U.Unesc(name) or name
if name ~= "" then out[key] = name end
end
end
return out
end
function T:SetProviderOverride(key, name)
local settings = NoWCL.db and NoWCL.db.settings
if not (ruleByKey[key] and settings) then return false end
settings.teamBuffProviderOverrides = settings.teamBuffProviderOverrides or {}
name = type(name) == "string" and name or nil
settings.teamBuffProviderOverrides[key] = name ~= "" and name or nil
return true
end
function T:ResetProviderOverrides()
local settings = NoWCL.db and NoWCL.db.settings
if not settings then return false end
settings.teamBuffProviderOverrides = {}
return true
end
function T:HasProviderOverrides(config)
config = config or self:ProviderOverrideConfig()
for key, name in pairs(config or {}) do
if ruleByKey[key] and type(name) == "string" and name ~= "" then return true end
end
return false
end
function T:IsMonitorEnabled(ruleOrKey, config)
local rule = type(ruleOrKey) == "table" and ruleOrKey or ruleByKey[ruleOrKey]
if not rule then return false end
config = config or self:MonitorConfig()
if config[rule.key] ~= nil then return config[rule.key] and true or false end
return self:DefaultMonitorEnabled(rule)
end
function T:MonitorSignature(config)
local bits = {}
config = config or self:MonitorConfig()
for i, rule in ipairs(RULES) do bits[i] = self:IsMonitorEnabled(rule, config) and "1" or "0" end
return table.concat(bits)
end
function T:PackMonitorConfig(config)
return self:MonitorSignature(config)
end
function T:UnpackMonitorConfig(payload)
local out = {}
payload = tostring(payload or "")
if payload == "" then return out end
for i, rule in ipairs(RULES) do
local value = payload:sub(i, i)
if value == "1" then out[rule.key] = true
elseif value == "0" then out[rule.key] = false end
end
return out
end
function T:SetMonitorEnabled(key, enabled)
local rule = ruleByKey[key]
local settings = NoWCL.db and NoWCL.db.settings
if not (rule and settings) then return false end
settings.teamBuffChecks = settings.teamBuffChecks or {}
local normalized = enabled and true or false
if normalized == self:DefaultMonitorEnabled(rule) then
settings.teamBuffChecks[key] = nil
else
settings.teamBuffChecks[key] = normalized
end
return true
end
function T:ResetMonitorConfig()
local settings = NoWCL.db and NoWCL.db.settings
if not settings then return false end
settings.teamBuffChecks = {}
return true
end
function T:MonitorSummary(config)
local enabled = 0
config = config or self:MonitorConfig()
for _, rule in ipairs(RULES) do
if self:IsMonitorEnabled(rule, config) then enabled = enabled + 1 end
end
return string.format("已监控 %d/%d 项", enabled, #RULES)
end
function T:ReminderSpellId(rule, provider)
local byClass = rule and rule.reminderIds
local value = byClass and provider and byClass[provider.class]
if type(value) == "table" then
local specId = n(provider.specId or provider.readySpecId)
value = value[specId] or value.default
end
value = n(value)
return value > 0 and value or nil
end
function T:DefaultReminderSpellId(rule)
for _, provider in ipairs(rule and rule.providers or {}) do
local value = rule.reminderIds and rule.reminderIds[provider.class]
if type(value) == "table" then value = value.default end
value = n(value)
if value > 0 then return value end
end
end
local function prepareNames(rule)
if rule._namesReady then return end
rule._namesReady = true
rule.nameSet = rule.nameSet or {}
if not GetSpellInfo then return end
for _, spellId in ipairs(rule.ids or {}) do
local name = GetSpellInfo(spellId)
if name and name ~= "" then rule.nameSet[name] = true end
end
end
function T:IsTrackedAura(spellId, name)
spellId = n(spellId)
if trackedAuraIds[spellId] then return true end
if excludedTrackedAuraIds[spellId] then return false end
if not name or name == "" then return false end
for _, rule in ipairs(RULES) do
prepareNames(rule)
if rule.nameSet[name] then return true end
end
return false
end
local function auraMatches(rule, aura)
if not (rule and aura) then return false end
local spellId = n(aura.spellId)
if rule.excludedIdSet and rule.excludedIdSet[spellId] then return false end
if rule.idSet[spellId] then return true end
prepareNames(rule)
return aura.name and rule.nameSet[aura.name] and true or false
end
local function auraStrength(rule, aura)
if not (rule and aura) then return 0 end
if not rule.strongIdSet then return auraMatches(rule, aura) and 2 or 0 end
local spellId = n(aura.spellId)
if rule.strongIdSet[spellId] then return 2 end
return auraMatches(rule, aura) and 1 or 0
end
local CASTER_SPECS = specs(62,63,64,102,258,262,265,266,267)
local PHYSICAL_SPECS = specs(70,71,72,73,103,104,250,251,252,253,254,255,259,260,261,263)
local MANA_CLASSES = { PALADIN=true,HUNTER=true,PRIEST=true,SHAMAN=true,MAGE=true,WARLOCK=true,DRUID=true }
local SPIRIT_CLASSES = { PRIEST=true,MAGE=true,WARLOCK=true,DRUID=true }
local CASTER_CLASSES = { PRIEST=true,MAGE=true,WARLOCK=true }
local PHYSICAL_CLASSES = { WARRIOR=true,HUNTER=true,ROGUE=true,DEATHKNIGHT=true }
local function roleOf(player)
local role = player and player.role
if role == "DPS" or role == "NONE" then role = "DAMAGER" end
if role == "TANK" or role == "HEALER" or role == "DAMAGER" then return role end
return nil
end
local function archetype(player)
local class = player and player.class
local role = roleOf(player)
local specId = n(player and (player.specId or player.readySpecId))
if role == "TANK" then return "tank", true end
if role == "HEALER" then return "healer", true end
if CASTER_SPECS[specId] then return "caster", true end
if PHYSICAL_SPECS[specId] then return "physical", true end
if CASTER_CLASSES[class] then return "caster", true end
if PHYSICAL_CLASSES[class] then return "physical", true end
return "unknown", false
end
local function requiredFor(rule, player)
if not (rule and player and player.class) then return false end
local kind = archetype(player)
if rule.audience == "all" then return true end
if rule.audience == "mana" then return MANA_CLASSES[player.class] and true or false end
if rule.audience == "spirit" then
return SPIRIT_CLASSES[player.class] and (kind == "caster" or kind == "healer") and true or false
end
if rule.audience == "tank" then return kind == "tank" end
if rule.audience == "physical" then return kind == "physical" or kind == "tank" end
if rule.audience == "spell" then return kind == "caster" or kind == "healer" end
if rule.audience == "damage" then return kind == "caster" or kind == "physical" or kind == "tank" end
return false
end
function T:RequiredRules(player, config)
local out = {}
for _, rule in ipairs(RULES) do
if self:IsMonitorEnabled(rule, config) and requiredFor(rule, player) then out[#out + 1] = rule end
end
return out
end
local function rosterByName(roster)
local out = {}
for _, player in ipairs(roster or {}) do
if player.name then out[player.name] = player end
end
return out
end
local function providerMatch(provider, player, allowUnknownSpec)
if not (provider and player and provider.class == player.class) then return false, false end
if not provider.specs then return true, false end
local specId = n(player.specId or player.readySpecId)
if specId > 0 then return provider.specs[specId] and true or false, false end
return false, allowUnknownSpec and true or false
end
function T:ProviderStatus(rule, roster, minStrength)
local unknown, triggered = false, false
minStrength = n(minStrength); if minStrength <= 0 then minStrength = 1 end
for _, player in ipairs(roster or {}) do
if not player.class then unknown = true end
for _, provider in ipairs(rule and rule.providers or {}) do
local matched, uncertain = providerMatch(provider, player, true)
if matched and n(provider.strength or 2) >= minStrength then
if not provider.triggered then return "available" end
triggered = true
end
if uncertain then unknown = true end
end
end
if triggered then return "triggered" end
return unknown and "unknown" or "none"
end
local function newResult(player, live)
return {
player=player and player.name, live=live and true or false, items={},
monitorSignature=T:MonitorSignature(),
complete=0, partial=0, weak=0, sourceReady=0, missing=0, noSource=0, unknown=0,
}
end
local function addResult(result, item)
result.items[#result.items + 1] = item
result[item.status] = n(result[item.status]) + 1
end
local function missingItem(rule, roster)
local strong = T:ProviderStatus(rule, roster, 2)
if strong == "available" and not rule.sourceOnly then
return { rule=rule, key=rule.key, label=rule.label, status="missing" }
end
if strong == "triggered" or (strong == "available" and rule.sourceOnly) then
return { rule=rule, key=rule.key, label=rule.label, status="sourceReady" }
end
local any = T:ProviderStatus(rule, roster, 1)
if any == "available" then
return { rule=rule, key=rule.key, label=rule.label, status="missing", weakSource=true }
end
if any == "triggered" then
return { rule=rule, key=rule.key, label=rule.label, status="sourceReady", weakSource=true }
end
if strong == "unknown" or any == "unknown" then
return { rule=rule, key=rule.key, label=rule.label, status="unknown" }
end
if strong == "none" then return { rule=rule, key=rule.key, label=rule.label, status="noSource" } end
return { rule=rule, key=rule.key, label=rule.label, status="missing" }
end
function T:EvaluateCurrent(player, roster)
local result = newResult(player, true)
local known = player and player.teamBuffsKnown == true
for _, rule in ipairs(self:RequiredRules(player)) do
local found, strength
for _, aura in pairs(player.teamAuras or {}) do
local value = auraStrength(rule, aura)
if value > n(strength) then found, strength = aura, value end
end
if found then
addResult(result, {
rule=rule, key=rule.key, label=rule.label, status=strength >= 2 and "complete" or "weak",
percent=1, spellId=found.spellId, spellName=found.name,
source=found.sourceName, strength=strength,
})
elseif not known then
addResult(result, { rule=rule, key=rule.key, label=rule.label, status="unknown" })
else
addResult(result, missingItem(rule, roster))
end
end
result.isComplete = result.missing == 0 and result.noSource == 0 and result.partial == 0
and result.weak == 0 and result.unknown == 0
return result
end
function T:EvaluateHistory(player, roster, duration)
local result = newResult(player, false)
local hasAuraEvidence = type(player and player.auraBuffs) == "table" and next(player.auraBuffs) ~= nil
local required = self:RequiredRules(player)
local coverage = {}
for _, rule in ipairs(required) do coverage[rule.key] = { uptime=0, strongUptime=0, sources={} } end
if hasAuraEvidence then
for _, raw in pairs(player.auraBuffs) do
local scale = n(raw[10]); if scale <= 0 then scale = 10 end
local endUnits = math.max(0, math.floor(n(duration) * scale + 0.5))
local uptimeUnits = n(raw[4])
if raw[7] ~= nil then uptimeUnits = uptimeUnits + math.max(0, endUnits - n(raw[7])) end
local aura = { spellId=n(raw[1]), peer=raw[3], name=raw[8], uptime=uptimeUnits / scale }
for _, rule in ipairs(required) do
if auraMatches(rule, aura) then
local found = coverage[rule.key]
found.uptime = found.uptime + aura.uptime
if auraStrength(rule, aura) >= 2 then found.strongUptime = found.strongUptime + aura.uptime end
found.spellId, found.spellName = found.spellId or aura.spellId, found.spellName or aura.name
if aura.peer and aura.peer ~= "" then
found.sources[aura.peer] = n(found.sources[aura.peer]) + aura.uptime
end
end
end
end
end
for _, rule in ipairs(required) do
local found = coverage[rule.key]
local uptime, spellId, spellName = found.uptime, found.spellId, found.spellName
if uptime > 0 and n(duration) > 0 then
uptime = math.min(n(duration), uptime)
local percent = math.min(1, uptime / n(duration))
local strongPercent = math.min(1, n(found.strongUptime) / n(duration))
local source, sourceValue
for name, value in pairs(found.sources) do
if not source or value > sourceValue or (value == sourceValue and tostring(name) < tostring(source)) then
source, sourceValue = name, value
end
end
addResult(result, {
rule=rule, key=rule.key, label=rule.label,
status=strongPercent >= COMPLETE_THRESHOLD and "complete"
or (rule.strongIdSet and percent >= COMPLETE_THRESHOLD and "weak" or "partial"),
percent=percent, strongPercent=strongPercent, uptime=uptime,
spellId=spellId, spellName=spellName, source=source,
})
elseif not hasAuraEvidence then
addResult(result, { rule=rule, key=rule.key, label=rule.label, status="unknown" })
else
addResult(result, missingItem(rule, roster))
end
end
result.isComplete = result.missing == 0 and result.noSource == 0 and result.partial == 0
and result.weak == 0 and result.unknown == 0
return result
end
local function bestCountedSource(counts, rosterNames)
local best, bestCount
for name, value in pairs(counts or {}) do
if rosterNames[name] and (not best or value > bestCount or (value == bestCount and tostring(name) < tostring(best))) then
best, bestCount = name, value
end
end
return best
end
function T:EvaluateSnapshot(snapshot)
local roster = snapshot and snapshot.players or {}
local names = rosterByName(roster)
local countedSources = {}
snapshot.missingTeamBuffPlayers = 0
snapshot.weakTeamBuffPlayers = 0
snapshot.unknownTeamBuffPlayers = 0
snapshot.noSourceTeamBuffPlayers = 0
for _, player in ipairs(roster) do
player.teamBuffsKnown = player.consumablesKnown == true
player.teamBuff = self:EvaluateCurrent(player, roster)
if player.teamBuff.missing > 0 then snapshot.missingTeamBuffPlayers = snapshot.missingTeamBuffPlayers + 1 end
if player.teamBuff.weak > 0 then snapshot.weakTeamBuffPlayers = snapshot.weakTeamBuffPlayers + 1 end
if player.teamBuff.unknown > 0 then snapshot.unknownTeamBuffPlayers = snapshot.unknownTeamBuffPlayers + 1 end
if player.teamBuff.noSource > 0 then snapshot.noSourceTeamBuffPlayers = snapshot.noSourceTeamBuffPlayers + 1 end
for _, item in ipairs(player.teamBuff.items) do
if item.source and item.source ~= "" then
countedSources[item.key] = countedSources[item.key] or {}
countedSources[item.key][item.source] = n(countedSources[item.key][item.source]) + 1
end
end
end
snapshot.teamBuffSources = {}
for key, counts in pairs(countedSources) do
snapshot.teamBuffSources[key] = bestCountedSource(counts, names)
end
return snapshot
end
function T:ObservedSourcesFromHistory(players, duration)
local names = rosterByName(players)
local counts = {}
for _, player in ipairs(players or {}) do
for _, raw in pairs(player.auraBuffs or {}) do
local scale = n(raw[10]); if scale <= 0 then scale = 10 end
local endUnits = math.max(0, math.floor(n(duration) * scale + 0.5))
local uptimeUnits = n(raw[4])
if raw[7] ~= nil then uptimeUnits = uptimeUnits + math.max(0, endUnits - n(raw[7])) end
local aura = { spellId=n(raw[1]), peer=raw[3], name=raw[8], uptime=uptimeUnits / scale }
if aura.peer and names[aura.peer] then
for _, rule in ipairs(RULES) do
if auraMatches(rule, aura) then
counts[rule.key] = counts[rule.key] or {}
counts[rule.key][aura.peer] = n(counts[rule.key][aura.peer]) + n(aura.uptime)
end
end
end
end
end
local out = {}
for key, sourceCounts in pairs(counts) do out[key] = bestCountedSource(sourceCounts, names) end
return out
end
local function providerForPlayer(rule, player, minStrength)
minStrength = n(minStrength); if minStrength <= 0 then minStrength = 1 end
for _, provider in ipairs(rule and rule.providers or {}) do
local matched = providerMatch(provider, player, false)
if matched and n(provider.strength or 2) >= minStrength then return provider end
end
end
local function providerCandidates(rule, roster, currentSources, previousSources, selfName, minStrength,
castableOnly, overrideName, autoReminderOnly)
local names = rosterByName(roster)
local current = currentSources and currentSources[rule.key]
local previous = previousSources and previousSources[rule.key]
local candidates = {}
for _, player in ipairs(roster or {}) do
local provider = providerForPlayer(rule, player, minStrength)
if provider and autoReminderOnly and provider.autoReminder == false and player.name ~= overrideName then
provider = nil
end
if player.name and player.name ~= selfName and provider and not (castableOnly and provider.triggered) then
local specId = n(player.specId or player.readySpecId)
local score = (rule.convention and rule.convention[specId]) or 100
if player.name == overrideName then score = score - 4000
elseif player.name == current then score = score - 2000
elseif player.name == previous then score = score - 1000 end
candidates[#candidates + 1] = { name=player.name, score=score, player=player, provider=provider }
end
end
table.sort(candidates, function(a, b)
if a.score ~= b.score then return a.score < b.score end
return tostring(a.name) < tostring(b.name)
end)
return candidates, names
end
function T:ProviderCandidates(rule, roster, currentSources, previousSources, selfName, minStrength,
castableOnly, autoReminderOnly)
local overrides = self:ProviderOverrideConfig()
local overrideName = rule and overrides[rule.key]
return providerCandidates(rule, roster, currentSources, previousSources, selfName, minStrength,
castableOnly, overrideName, autoReminderOnly)
end
function T:SelectProvider(rule, roster, currentSources, previousSources, selfName, minStrength, castableOnly)
local candidates = self:ProviderCandidates(rule, roster, currentSources, previousSources,
selfName, minStrength, castableOnly)
return candidates[1] and candidates[1].name or nil
end
function T:CurrentDisplayInfo(item, roster, currentSources, previousSources)
if not item then return nil end
local spellId = n(item.spellId)
local provider = item.source
local player
if spellId <= 0 and item.rule then
local minStrength = self:ProviderStatus(item.rule, roster, 2) == "available" and 2 or 1
provider = self:SelectProvider(item.rule, roster, currentSources, previousSources, nil, minStrength)
local names = rosterByName(roster)
player = provider and names[provider]
spellId = n(self:ReminderSpellId(item.rule, player))
if spellId <= 0 then spellId = n(self:DefaultReminderSpellId(item.rule)) end
end
if not player and provider then player = rosterByName(roster)[provider] end
return {
spellId=spellId > 0 and spellId or nil, provider=provider,
providerClass=player and player.class, providerSpecId=player and (player.specId or player.readySpecId),
}
end
local function providerSlotKey(rule, provider, targetName)
local slot = rule and rule.providerSlots and provider and rule.providerSlots[provider.class]
if not slot then return nil end
if provider.class == "PALADIN" then return "target:" .. tostring(targetName) .. ":" .. slot end
return "raid:" .. slot
end
function T:BuildProviderAssignments(snapshot, previousSources, excludedProviderName, targetName)
local roster = snapshot and snapshot.players or {}
local names = rosterByName(roster)
local tasks = {}
for _, player in ipairs(roster) do
if not targetName or player.name == targetName then
for _, item in ipairs(player.teamBuff and player.teamBuff.items or {}) do
local strongStatus = self:ProviderStatus(item.rule, roster, 2)
local minStrength
if item.status == "missing" then
minStrength = strongStatus == "available" and 2 or 1
elseif item.status == "weak" and strongStatus == "available" then
minStrength = 2
end
if minStrength and not item.rule.sourceOnly then
tasks[#tasks + 1] = {
rule=item.rule, targetName=player.name,
reminderName=player.reminderName or player.name,
minStrength=minStrength,
}
end
end
end
end
table.sort(tasks, function(a, b)
local ap, bp = n(a.rule.assignmentPriority or 100), n(b.rule.assignmentPriority or 100)
if ap ~= bp then return ap < bp end
if a.rule.key ~= b.rule.key then return a.rule.key < b.rule.key end
return tostring(a.targetName) < tostring(b.targetName)
end)
local occupied = {}
local assignedTargets = {}
local byProvider = {}
for _, task in ipairs(tasks) do
local candidates = self:ProviderCandidates(task.rule, roster, snapshot.teamBuffSources,
previousSources, excludedProviderName, task.minStrength, true, true)
local selected, selectedSpellId
for _, candidate in ipairs(candidates) do
local spellId = self:ReminderSpellId(task.rule, candidate.player)
local slot = providerSlotKey(task.rule, candidate.provider, task.targetName)
local occupiedKey = slot and (candidate.name .. "\001" .. slot)
local oldSpellId = occupiedKey and occupied[occupiedKey]
if not oldSpellId or oldSpellId == spellId then
selected, selectedSpellId = candidate, spellId
if occupiedKey then occupied[occupiedKey] = spellId end
break
end
end
if selected then
local provider, providerPlayer = selected.name, names[selected.name]
local assignmentKey = table.concat({tostring(provider), tostring(selectedSpellId), tostring(task.targetName)}, "\001")
if not assignedTargets[assignmentKey] then
assignedTargets[assignmentKey] = true
local assignment = byProvider[provider]
if not assignment then
assignment = {
provider=provider, providerClass=providerPlayer and providerPlayer.class,
providerSpecId=providerPlayer and (providerPlayer.specId or providerPlayer.readySpecId), groups={},
}
byProvider[provider] = assignment
end
local group
for _, existing in ipairs(assignment.groups) do
if existing.rule == task.rule and existing.spellId == selectedSpellId then group = existing; break end
end
if not group then
group = { rule=task.rule, targets={}, spellId=selectedSpellId }
assignment.groups[#assignment.groups + 1] = group
end
group.targets[#group.targets + 1] = task.reminderName
end
end
end
local out = {}
for _, assignment in pairs(byProvider) do
for _, group in ipairs(assignment.groups) do table.sort(group.targets) end
table.sort(assignment.groups, function(a, b) return a.rule.label < b.rule.label end)
out[#out + 1] = assignment
end
table.sort(out, function(a, b) return tostring(a.provider) < tostring(b.provider) end)
return out
end
local function fmtTime(seconds)
seconds = math.max(0, n(seconds))
return string.format("%d:%02d", math.floor(seconds / 60), math.floor(seconds % 60))
end
local function spellLink(spellId)
spellId = n(spellId)
if spellId <= 0 then return nil end
if GetSpellLink then
local ok, link = pcall(GetSpellLink, spellId)
if ok and link then return link end
end
if C_Spell and C_Spell.GetSpellLink then
local ok, link = pcall(C_Spell.GetSpellLink, spellId)
if ok and link then return link end
end
end
local function spellIconMarkup(spellId, size, gray)
spellId = n(spellId)
if spellId <= 0 then return nil end
local texture
if GetSpellTexture then
local ok, value = pcall(GetSpellTexture, spellId)
if ok then texture = value end
end
if not texture and C_Spell and C_Spell.GetSpellTexture then
local ok, value = pcall(C_Spell.GetSpellTexture, spellId)
if ok then texture = value end
end
if not texture then return nil end
size = math.max(8, math.floor(n(size) > 0 and n(size) or 14))
local tint = gray and ":127:127:127" or ""
return string.format("|T%s:%d:%d:0:0:64:64:5:59:5:59%s|t", tostring(texture), size, size, tint)
end
local function providerClassLabels(rule)
local out, seen = {}, {}
for _, provider in ipairs(rule and rule.providers or {}) do
if not seen[provider.class] then
seen[provider.class] = true
local names = LOCALIZED_CLASS_NAMES_MALE or {}
local label = names[provider.class] or provider.class
if U and U.ClassColor then label = U.ClassColor(label, provider.class) end
out[#out + 1] = label
end
end
return table.concat(out, " / ")
end
local function tooltipDisplay(item, context)
context = context or {}
return T:CurrentDisplayInfo(item, context.roster, context.currentSources, context.previousSources) or {}
end
local function coloredProvider(display)
if not (display and display.provider) then return nil end
if U and U.ClassColor then return U.ClassColor(display.provider, display.providerClass) end
return display.provider
end
function T:ShowTooltip(owner, result)
if not (GameTooltip and owner and result) then return end
local context = owner.teamBuffContext or {}
GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
GameTooltip:ClearLines()
GameTooltip:AddLine((result.player or "角色") .. " - 团队Buff", 1, 0.82, 0)
for _, item in ipairs(result.items or {}) do
local display = tooltipDisplay(item, context)
local link = spellLink(display.spellId) or item.label or "团队Buff"
local absent = item.status == "missing" or item.status == "noSource"
local icon = spellIconMarkup(display.spellId, 14, absent)
local left = icon and (icon .. " " .. link) or link
local right, r, g, b
if item.status == "complete" then
r, g, b = 0.25, 1, 0.35
right = item.uptime and (fmtTime(item.uptime) .. "  " .. string.format("%.1f%%", n(item.percent) * 100)) or "100%"
elseif item.status == "sourceReady" then
right, r, g, b = "来源已具备", 0.35, 0.85, 1
elseif item.status == "weak" then
right, r, g, b = item.uptime and ("弱效 " .. fmtTime(item.uptime) .. "  "
.. string.format("%.1f%%", n(item.percent) * 100)) or "弱覆盖", 1, 0.72, 0.15
elseif item.status == "partial" then
r, g, b = 1, 0.82, 0.15
right = fmtTime(item.uptime) .. "  " .. string.format("%.1f%%", n(item.percent) * 100)
elseif item.status == "missing" then
right, r, g, b = "缺失", 1, 0.35, 0.25
elseif item.status == "noSource" then
right, r, g, b = "本团无来源", 0.55, 0.55, 0.58
else
right, r, g, b = "数据未知", 0.68, 0.68, 0.72
end
GameTooltip:AddDoubleLine(left, right or "", 1, 1, 1, r, g, b)
local provider = coloredProvider(display)
local providerLine
if item.status == "complete" or item.status == "partial" or item.status == "weak" then
if provider then providerLine = "    来源：" .. provider end
elseif item.status == "sourceReady" then
if provider then providerLine = "    预计战斗触发：" .. provider end
elseif item.status == "missing" then
if provider then providerLine = "    预计：" .. provider end
elseif item.status == "noSource" then
local available = providerClassLabels(item.rule)
if available ~= "" then providerLine = "    可由：" .. available end
end
if providerLine then GameTooltip:AddLine(providerLine, 0.72, 0.72, 0.75) end
end
GameTooltip:Show()
end
function T:CellText(result, context, maxIcons)
if not result or not result.items then return "?", {0.65,0.65,0.68} end
if #result.items == 0 then return "—", {0.55,0.55,0.58} end
local function labels(status)
local out = {}
for _, item in ipairs(result.items) do if item.status == status then out[#out + 1] = item.label end end
return table.concat(out, "、")
end
local function icons(statuses)
local wanted, all = {}, {}
for _, status in ipairs(statuses) do wanted[status] = true end
for _, item in ipairs(result.items) do
if wanted[item.status] then
local display = tooltipDisplay(item, context)
local icon = spellIconMarkup(display.spellId, 14, true)
if icon then all[#all + 1] = icon end
end
end
local limit = math.max(1, math.floor(n(maxIcons) > 0 and n(maxIcons) or #all))
local out = {}
for index = 1, math.min(#all, limit) do out[#out + 1] = all[index] end
return table.concat(out, " "), #all > limit
end
if n(result.missing) > 0 or n(result.noSource) > 0 then
local text, truncated = icons({"missing", "noSource"})
local fallback = labels("missing")
if fallback == "" then fallback = labels("noSource") end
local prefix = "|cffff4d4d缺：|r"
if text ~= "" then return prefix .. " " .. text .. (truncated and " ..." or ""), {1,1,1} end
return prefix .. fallback, {1,1,1}
end
if n(result.weak) > 0 then return "弱覆盖 " .. tostring(n(result.weak)) .. "项", {1,0.72,0.15} end
if n(result.partial) > 0 then
local lowest = 1
for _, item in ipairs(result.items) do
if item.status == "partial" then lowest = math.min(lowest, n(item.percent)) end
end
return "覆盖 " .. string.format("%.1f%%", lowest * 100), {1,0.82,0.15}
end
if n(result.unknown) > 0 then return "?", {0.65,0.65,0.68} end
return READY_CHECK_COMPLETE, {0.3,1,0.4}
end
