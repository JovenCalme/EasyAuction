local addonName, NoWCL = ...
local U = {}
NoWCL.Util = U
local PANEL_FRAME_LEVEL = 10
local SUBPANEL_FRAME_LEVEL = 20
local panelFrames = setmetatable({}, { __mode = "k" })
local PANEL_LAYERS = {
system = { strata="MEDIUM", level=PANEL_FRAME_LEVEL },
high = { strata="HIGH", level=50 },
top = { strata="TOOLTIP", level=100 },
}
function U.PanelLayerMode()
local mode = NoWCL.db and NoWCL.db.window and NoWCL.db.window.panelLayer or "system"
return PANEL_LAYERS[mode] and mode or "system"
end
function U.PanelLayerLabel(mode)
mode = PANEL_LAYERS[mode] and mode or U.PanelLayerMode()
if mode == "top" then return "最高层" end
if mode == "high" then return "插件高层" end
return "系统窗口优先"
end
local function applyPanelLayer(frame, isSubpanel)
local layer = PANEL_LAYERS[U.PanelLayerMode()] or PANEL_LAYERS.system
frame:SetFrameStrata(layer.strata)
frame:SetFrameLevel(layer.level + (isSubpanel and (SUBPANEL_FRAME_LEVEL - PANEL_FRAME_LEVEL) or 0))
end
function U.SetPanelLayer(frame, isSubpanel)
if not frame then return end
panelFrames[frame] = isSubpanel and true or false
applyPanelLayer(frame, isSubpanel)
end
function U.SetPanelLayerMode(mode)
if not PANEL_LAYERS[mode] then mode = "system" end
NoWCL.db.window = NoWCL.db.window or {}
NoWCL.db.window.panelLayer = mode
for frame, isSubpanel in pairs(panelFrames) do
applyPanelLayer(frame, isSubpanel)
if frame._nowclPanelLayerChanged then frame:_nowclPanelLayerChanged() end
end
return mode
end
local CLASSIC_SPEC_ICONS = {
[62]=135932,[63]=135810,[64]=135846,
[65]=135920,[66]=135893,[70]=135873,
[71]=132355,[72]=132347,[73]=134952,
[102]=136096,[103]=132276,[104]=132276,[105]=136041,
[250]=135770,[251]=135773,[252]=135775,
[253]=132164,[254]=132222,[255]=132215,
[256]=135987,[257]=237542,[258]=136207,
[259]=132292,[260]=132090,[261]=132320,
[262]=136048,[263]=136051,[264]=136052,
[265]=136145,[266]=136172,[267]=136186,
}
local SPEC_CLASS = {
[62]="MAGE",[63]="MAGE",[64]="MAGE",
[65]="PALADIN",[66]="PALADIN",[70]="PALADIN",
[71]="WARRIOR",[72]="WARRIOR",[73]="WARRIOR",
[102]="DRUID",[103]="DRUID",[104]="DRUID",[105]="DRUID",
[250]="DEATHKNIGHT",[251]="DEATHKNIGHT",[252]="DEATHKNIGHT",
[253]="HUNTER",[254]="HUNTER",[255]="HUNTER",
[256]="PRIEST",[257]="PRIEST",[258]="PRIEST",
[259]="ROGUE",[260]="ROGUE",[261]="ROGUE",
[262]="SHAMAN",[263]="SHAMAN",[264]="SHAMAN",
[265]="WARLOCK",[266]="WARLOCK",[267]="WARLOCK",
}
local SPEC_ROLE = {
[62]="DAMAGER",[63]="DAMAGER",[64]="DAMAGER",
[65]="HEALER",[66]="TANK",[70]="DAMAGER",
[71]="DAMAGER",[72]="DAMAGER",[73]="TANK",
[102]="DAMAGER",[104]="TANK",[105]="HEALER",
[253]="DAMAGER",[254]="DAMAGER",[255]="DAMAGER",
[256]="HEALER",[257]="HEALER",[258]="DAMAGER",
[259]="DAMAGER",[260]="DAMAGER",[261]="DAMAGER",
[262]="DAMAGER",[263]="DAMAGER",[264]="HEALER",
[265]="DAMAGER",[266]="DAMAGER",[267]="DAMAGER",
}
local CLASS_LABELS = {
WARRIOR="战士", PALADIN="圣骑士", HUNTER="猎人", ROGUE="潜行者", PRIEST="牧师",
DEATHKNIGHT="死亡骑士", SHAMAN="萨满祭司", MAGE="法师", WARLOCK="术士", DRUID="德鲁伊",
}
local SPEC_BY_SIGNATURE_SPELL = {
[33831]=102,[24858]=102,[61384]=102,[53201]=102,
[48566]=103,[33876]=103,[48564]=104,[33878]=104,
[33891]=105,[18562]=105,[53251]=105,
[19574]=253,[53257]=253,[34490]=254,[19506]=254,[53209]=254,
[49012]=255,[63672]=255,[60053]=255,
[12043]=62,[12042]=62,[44781]=62,[28682]=63,[48108]=63,[42950]=63,[55360]=63,
[43039]=64,[44544]=64,[57761]=64,[31687]=64,[44572]=64,
[48825]=65,[31842]=65,[53563]=65,[48952]=66,[48827]=66,[53595]=66,
[53489]=70,[59578]=70,[20066]=70,[53385]=70,
[10060]=256,[33206]=256,[53007]=256,[53000]=256,[52985]=256,[63944]=256,
[20711]=257,[48087]=257,[48089]=257,[47788]=257,
[15286]=258,[15473]=258,[48160]=258,[47585]=258,
[58427]=259,[48666]=259,[51662]=259,[13750]=260,[51690]=260,[58683]=260,
[14183]=261,[36554]=261,[51713]=261,
[16166]=262,[57722]=262,[59159]=262,[17364]=263,[60103]=263,[30823]=263,[53817]=263,[51533]=263,
[16190]=264,[51886]=264,[49284]=264,[61301]=264,
[47843]=265,[59092]=265,[59164]=265,[30146]=266,[71165]=266,[63167]=266,[47241]=266,
[17962]=267,[47847]=267,[59172]=267,
[46857]=71,[47486]=71,[46924]=71,[29801]=72,[23881]=72,
[50720]=73,[47498]=73,[50227]=73,[46968]=73,
[53138]=250,[50452]=250,[49016]=250,[55233]=250,[55262]=250,[49028]=250,
[49203]=251,[51271]=251,[55268]=251,[51411]=251,
[51052]=252,[66803]=252,[49222]=252,[51735]=252,[55271]=252,[49206]=252,
}
local CLASS_BY_SIGNATURE_SPELL = {
[48266]="DEATHKNIGHT",
}
function U.SpecializationFromSpell(spellId, class)
local specId=SPEC_BY_SIGNATURE_SPELL[tonumber(spellId)]
if not specId or (class and SPEC_CLASS[specId]~=class) then return nil end
return specId
end
function U.ClassFromSpecialization(specId)
return SPEC_CLASS[tonumber(specId)]
end
function U.RoleFromSpecialization(specId)
return SPEC_ROLE[tonumber(specId)]
end
function U.ClassFromSpell(spellId, class)
local inferred=CLASS_BY_SIGNATURE_SPELL[tonumber(spellId)]
if not inferred or (class and inferred~=class) then return nil end
return inferred
end
function U.LocalizedClass(class)
if not class or class == "" then return "未知职业" end
return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class])
or (LOCALIZED_CLASS_NAMES_FEMALE and LOCALIZED_CLASS_NAMES_FEMALE[class])
or CLASS_LABELS[class] or tostring(class)
end
local function rosterShortName(name)
if type(name) ~= "string" or name == "" then return nil end
return name:match("^[^-]+") or name
end
local function rosterUnitName(unit)
if GetUnitName then
local full = GetUnitName(unit, true)
if full and full ~= "" then return rosterShortName(full), tostring(full) end
end
local name, realm
if UnitFullName then name, realm = UnitFullName(unit) end
if not name and UnitName then name, realm = UnitName(unit) end
if not name or name == "" then return nil, nil end
if realm and realm ~= "" and not tostring(name):find("-", 1, true) then
return rosterShortName(name), tostring(name) .. "-" .. tostring(realm)
end
return rosterShortName(name), tostring(name)
end
function U.GroupRosterMembers()
local members = {}
local count = GetNumGroupMembers and (GetNumGroupMembers() or 0) or 0
local inRaid = IsInRaid and IsInRaid() and true or false
local expected = inRaid and count or math.max(1, count)
local subgroupPositions = {}
local function add(unit, rosterName, classFile, subgroup, rosterOnline, groupLabel)
local exists = not UnitExists or UnitExists(unit)
local name, whisperName
if exists then name, whisperName = rosterUnitName(unit) end
name = name or rosterShortName(rosterName)
whisperName = whisperName or (rosterName and tostring(rosterName)) or name
if not name then return end
local class = classFile
if exists and UnitClass then class = select(2, UnitClass(unit)) or class end
local role = exists and UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) or nil
if role == "NONE" then role = nil end
local connected = rosterOnline
if exists and UnitIsConnected then connected = UnitIsConnected(unit) end
if connected == nil then connected = true end
local visible = exists and (not UnitIsVisible or UnitIsVisible(unit)) and true or false
local playerName = UnitName and rosterShortName(UnitName("player")) or nil
local isSelf = unit == "player"
or (exists and UnitIsUnit and UnitIsUnit(unit, "player"))
or (not UnitIsUnit and playerName and playerName == name) or false
members[#members + 1] = {
unit=unit, name=name, whisperName=whisperName,
guid=exists and UnitGUID and UnitGUID(unit) or nil,
class=class, role=role, subgroup=tonumber(subgroup), groupLabel=groupLabel,
exists=exists and true or false, connected=connected and true or false,
visible=visible, isSelf=isSelf,
}
end
if inRaid then
for index = 1, count do
local rosterName, subgroup, classFile, online
if GetRaidRosterInfo then
rosterName, _, subgroup, _, _, classFile, _, online = GetRaidRosterInfo(index)
end
subgroup = tonumber(subgroup) or (math.floor((index - 1) / 5) + 1)
subgroupPositions[subgroup] = (subgroupPositions[subgroup] or 0) + 1
add("raid" .. index, rosterName, classFile, subgroup, online,
string.format("%d-%d", subgroup, subgroupPositions[subgroup]))
end
else
add("player", nil, nil, 1, true, "1-1")
for index = 1, math.max(0, count - 1) do
add("party" .. index, nil, nil, 1, nil, string.format("1-%d", index + 1))
end
end
return members, expected
end
function U.CompleteCurrentRoster(players, dur)
local out, byName = {}, {}
for _, player in ipairs(players or {}) do
local copy = {}
for key, value in pairs(player) do copy[key] = value end
out[#out + 1] = copy
if copy.name then byName[copy.name] = copy end
end
local function append(name, info)
if not name or byName[name] then return end
info = info or {}
local ready = NoWCL.Readiness and NoWCL.Readiness.localCache
and NoWCL.Readiness.localCache[name]
local player = {
name=name, guid=info.guid, class=info.class, role=info.role or "DAMAGER",
specId=(ready and ready.specId) or info.specId,
groupLabel=info.groupLabel,
dmg=0, dmgBoss=0, alignedDmg=0, heal=0, absorbed=0,
interrupts=0, dispels=0, deaths=0, sunderApplied=0,
activeMs=0, activePct=0, actions=0, deadSec=0,
extraTasks={}, fightDur=tonumber(dur) or 0, currentRosterOnly=true,
}
out[#out + 1] = player
byName[name] = player
end
local members, expected = U.GroupRosterMembers()
for _, member in ipairs(members) do
local player = member.name and byName[member.name]
local ready = member.name and NoWCL.Readiness and NoWCL.Readiness.localCache
and NoWCL.Readiness.localCache[member.name]
if player then
player.guid = player.guid or member.guid
player.class = player.class or member.class
player.role = player.role or member.role
player.specId = player.specId or (ready and ready.specId)
player.groupLabel = player.groupLabel or member.groupLabel
else
append(member.name, member)
end
end
if #members < (tonumber(expected) or 0) then
for name, info in pairs((NoWCL.Stats and NoWCL.Stats.roster) or {}) do
append(name, info)
end
end
return out
end
function U.GroupPositionLabel(unit)
if not unit then return nil end
if unit == "player" and IsInRaid and IsInRaid() then
local playerGUID = UnitGUID and UnitGUID("player")
local count = GetNumGroupMembers and (GetNumGroupMembers() or 0) or 0
for index = 1, count do
local raidUnit = "raid" .. index
if (playerGUID and UnitGUID and UnitGUID(raidUnit) == playerGUID)
or (UnitIsUnit and UnitIsUnit(raidUnit, "player")) then
unit = raidUnit
break
end
end
end
local raidIndex = tonumber(tostring(unit):match("^raid(%d+)$"))
if raidIndex then
local subgroup = GetRaidRosterInfo and select(3, GetRaidRosterInfo(raidIndex))
subgroup = tonumber(subgroup) or (math.floor((raidIndex - 1) / 5) + 1)
local position = 0
for index = 1, raidIndex do
local current = GetRaidRosterInfo and select(3, GetRaidRosterInfo(index))
current = tonumber(current) or (math.floor((index - 1) / 5) + 1)
if current == subgroup then position = position + 1 end
end
return string.format("%d-%d", subgroup, math.max(1, position))
end
if unit == "player" then return "1-1" end
local partyIndex = tonumber(tostring(unit):match("^party(%d+)$"))
if partyIndex then return string.format("1-%d", partyIndex + 1) end
end
function U.GroupCharacterLabel(name, class, groupLabel)
local short = type(name) == "string" and (name:match("^[^-]+") or name) or "未知角色"
if short == "" then short = "未知角色" end
groupLabel = tostring(groupLabel or "0-0")
if not groupLabel:match("^%d+%-%d+$") then groupLabel = "0-0" end
return string.format("%s %s「%s」", groupLabel, U.LocalizedClass(class), short)
end
function U.ResolveGroupCharacterLabel(name, guid, class, groupLabel)
local short = type(name) == "string" and (name:match("^[^-]+") or name) or nil
local count = GetNumGroupMembers and (GetNumGroupMembers() or 0) or 0
local units = {}
if IsInRaid and IsInRaid() then
for index = 1, count do units[#units + 1] = "raid" .. index end
else
units[#units + 1] = "player"
for index = 1, math.max(0, count - 1) do units[#units + 1] = "party" .. index end
end
local unit
for _, candidate in ipairs(units) do
local sameGUID = guid and UnitGUID and UnitGUID(candidate) == guid
local candidateName = UnitName and UnitName(candidate)
local sameName = short and candidateName
and (tostring(candidateName):match("^[^-]+") or candidateName) == short
if sameGUID or sameName then unit = candidate; break end
end
if unit then
groupLabel = groupLabel or U.GroupPositionLabel(unit)
if not class and UnitClass then class = select(2, UnitClass(unit)) end
end
local roster = NoWCL.Stats and NoWCL.Stats.roster
local info = roster and short and roster[short]
class = class or (info and info.class)
return U.GroupCharacterLabel(short or name, class, groupLabel)
end
function U.NormalizePlayerClass(pl)
if type(pl) ~= "table" then return nil end
local specClass = U.ClassFromSpecialization(pl.specId or pl.readySpecId)
if specClass then pl.class = specClass end
return pl.class
end
function U.ClassColor(name, class)
if class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] then
local c = RAID_CLASS_COLORS[class]
return string.format("|cff%02x%02x%02x%s|r", c.r*255, c.g*255, c.b*255, name or "?")
end
return name or "?"
end
function U.SpecializationIcon(specId)
specId=tonumber(specId)
if not (specId and specId>0) then return nil end
if CLASSIC_SPEC_ICONS[specId] then return CLASSIC_SPEC_ICONS[specId] end
if GetSpecializationInfoByID then
local _,_,_,icon=GetSpecializationInfoByID(specId)
if icon then return icon end
end
end
function U.SpecIconTag(specId, size)
local icon=U.SpecializationIcon(specId)
if not icon then return "" end
size=math.max(8,math.floor(tonumber(size) or 14))
return string.format("|T%s:%d:%d:0:0:64:64:4:60:4:60|t ",tostring(icon),size,size)
end
function U.ApplyReadinessToPlayers(players)
for _,pl in ipairs(players or {}) do
local name=pl.name
local st=name and NoWCL.Sync and NoWCL.Sync.recvStats and NoWCL.Sync.recvStats[name]
local lc=name and NoWCL.Readiness and NoWCL.Readiness.localCache and NoWCL.Readiness.localCache[name]
local gear=(st and (st.ilvl or 0)>0) and st or (((lc and (lc.ilvl or 0)>0) and lc) or nil)
if gear then
if (pl.ilvl or 0)<=0 then pl.ilvl=gear.ilvl end
if pl.lowQuality==nil then pl.lowQuality=gear.lowQuality or 0 end
if gear.gearAuditKnown then
if pl.missEnch==nil then pl.missEnch=gear.missEnch or 0 end
if pl.emptyGems==nil then pl.emptyGems=gear.emptyGems or 0 end
pl.gearAuditKnown=true
end
end
if not pl.gearKey and lc and lc.gearKey then pl.gearKey=lc.gearKey end
if not pl.specId then pl.specId=(st and st.specId) or (lc and lc.specId) end
U.NormalizePlayerClass(pl)
end
return players
end
function U.FmtTime(sec)
sec = math.floor(sec or 0)
return string.format("%d:%02d", math.floor(sec/60), sec%60)
end
local function numberUnits()
local window = NoWCL.db and NoWCL.db.window
return window and window.numberUnits == "mk" and "mk" or "cn"
end
function U.NumberUnits()
return numberUnits()
end
function U.SetNumberUnits(value)
local style = value == "mk" and "mk" or "cn"
if NoWCL.db then
NoWCL.db.window = NoWCL.db.window or {}
NoWCL.db.window.numberUnits = style
end
if NoWCL.AuditUI and NoWCL.AuditUI.Refresh then NoWCL.AuditUI:Refresh() end
if NoWCL.MiniUI and NoWCL.MiniUI.Refresh then NoWCL.MiniUI:Refresh() end
return style
end
function U.Short(n)
n = tonumber(n) or 0
local abs = math.abs(n)
if numberUnits() == "mk" then
if abs >= 1e6 then return string.format("%.2fM", n/1e6) end
if abs >= 1e3 then return string.format("%.1fK", n/1e3) end
else
if abs >= 1e4 then return string.format("%.2f万", n/1e4) end
if abs >= 1e3 then return string.format("%.1f千", n/1e3) end
end
return string.format("%d", n)
end
function U.Pct(x)
return string.format("%d%%", math.floor((x or 0)*100 + 0.5))
end
function U.Pct1(x)
return string.format("%.1f%%", (tonumber(x) or 0) * 100)
end
function U.Pct2(x)
return string.format("%.2f%%", (tonumber(x) or 0) * 100)
end
function U.IsHostileNPC(flags)
if not flags then return false end
local isNPC = bit.band(flags, COMBATLOG_OBJECT_TYPE_NPC or 0x800) > 0
local isHostile = bit.band(flags, COMBATLOG_OBJECT_REACTION_HOSTILE or 0x40) > 0
return isNPC and isHostile
end
function U.IsPlayer(guid)
return type(guid) == "string" and guid:sub(1,7) == "Player-"
end
function U.IsCreature(guid)
return type(guid) == "string" and guid:sub(1,9) == "Creature-"
end
function U.IsTrainingDummy(name)
return type(name) == "string"
and (name:find("训练假人", 1, true) or name:find("Training Dummy", 1, true))
and true or false
end
function U.UnitTokenByName(name)
if not name then return nil end
local short = name:match("^[^-]+") or name
if UnitName("player") == short then return "player" end
local n = GetNumGroupMembers() or 0
if IsInRaid() then
for i = 1, n do if UnitName("raid"..i) == short then return "raid"..i end end
else
for i = 1, n do if UnitName("party"..i) == short then return "party"..i end end
end
return nil
end
function U.IsRaidLeader(unitOrName)
if not unitOrName then unitOrName = "player" end
local unit = unitOrName
if unitOrName ~= "player" and not unitOrName:match("^raid%d+$") and not unitOrName:match("^party%d+$") then
unit = U.UnitTokenByName(unitOrName)
end
if not unit then return false end
return UnitIsGroupLeader(unit) and true or false
end
function U.GroupChannel()
local instanceCategory = _G.LE_PARTY_CATEGORY_INSTANCE
if instanceCategory and IsInGroup and IsInGroup(instanceCategory) then
return "INSTANCE_CHAT"
end
if IsInRaid and IsInRaid() then return "RAID" end
if IsInGroup and IsInGroup() then return "PARTY" end
return nil
end
function U.Esc(s)
s = tostring(s or "")
return (s:gsub("[~|;\\]", { ["~"]="\\t", ["|"]="\\p", [";"]="\\s", ["\\"]="\\\\" }))
end
function U.Unesc(s)
s = tostring(s or "")
return (s:gsub("\\(.)", function(c)
if c == "t" then return "~" elseif c == "p" then return "|"
elseif c == "s" then return ";" elseif c == "\\" then return "\\" end
return c
end))
end
function U.PackTargetScope(src)
if type(src) == "string" then return src end
if type(src) ~= "table" then return "" end
local ids = {}
for npc in pairs(src) do
npc = tonumber(npc)
if npc and npc > 0 then ids[#ids + 1] = npc end
end
table.sort(ids)
local out = {}
for _, npc in ipairs(ids) do
local b = src[npc]
if type(b) == "table" then
out[#out + 1] = table.concat({
npc, U.Esc(b[1] or ""), tostring(U.N(b[2])), tostring(U.N(b[3])), tostring(U.N(b[4] or b[2])),
}, "|")
end
end
return table.concat(out, ";")
end
function U.UnpackTargetScope(payload)
if type(payload) == "table" then return payload end
local out = {}
if type(payload) ~= "string" or payload == "" then return out end
for item in payload:gmatch("[^;]+") do
local npc, name, allDamage, alignedDamage, eligibleRaw = strsplit("|", item, 5)
npc = tonumber(npc)
if npc and npc > 0 then
out[npc] = { U.Unesc(name or ""), U.N(allDamage), U.N(alignedDamage),
eligibleRaw ~= nil and U.N(eligibleRaw) or U.N(allDamage) }
end
end
return out
end
function U.PackScopeTimeline(src)
if type(src) == "string" then return src end
if type(src) ~= "table" then return "" end
local ids = {}
for npc in pairs(src) do
npc = tonumber(npc)
if npc and npc > 0 then ids[#ids + 1] = npc end
end
table.sort(ids)
local out = {}
for _, npc in ipairs(ids) do
local buckets = src[npc]
if type(buckets) == "table" then
local values = {}
for bucket, amount in pairs(buckets) do
bucket, amount = tonumber(bucket), U.N(amount)
if bucket and bucket > 0 and amount > 0 then
values[#values + 1] = { bucket=math.floor(bucket), amount=amount }
end
end
table.sort(values, function(a, b) return a.bucket < b.bucket end)
local packed = {}
for _, item in ipairs(values) do packed[#packed + 1] = item.bucket .. ":" .. item.amount end
if #packed > 0 then out[#out + 1] = npc .. "|" .. table.concat(packed, ",") end
end
end
return table.concat(out, ";")
end
function U.UnpackScopeTimeline(payload)
if type(payload) == "table" then return payload end
local out = {}
if type(payload) ~= "string" or payload == "" then return out end
for item in payload:gmatch("[^;]+") do
local npc, values = item:match("^(%d+)|(.+)$")
npc = tonumber(npc)
if npc and values then
local buckets = {}
for pair in values:gmatch("[^,]+") do
local bucket, amount = pair:match("^(%d+):([^:]+)$")
bucket, amount = tonumber(bucket), tonumber(amount)
if bucket and amount and bucket > 0 and amount > 0 then buckets[bucket] = amount end
end
if next(buckets) then out[npc] = buckets end
end
end
return out
end
function U.N(x) return tonumber(x) or 0 end
function U.SumValues(src)
if type(src) ~= "table" then return 0 end
local total = 0
for _, v in pairs(src) do total = total + U.N(v) end
return total
end
function U.HealingAmount(pl)
if type(pl) ~= "table" then return 0 end
return math.max(U.N(pl.heal), U.SumValues(pl.heals), U.SumValues(pl.healTargets))
end
local DEFAULT_WINDOW_OPACITY = 0.70
local MIN_WINDOW_OPACITY = 0.00
local MAX_WINDOW_OPACITY = 1.00
local function clampWindowOpacity(v)
v = tonumber(v) or DEFAULT_WINDOW_OPACITY
if v < MIN_WINDOW_OPACITY then return MIN_WINDOW_OPACITY end
if v > MAX_WINDOW_OPACITY then return MAX_WINDOW_OPACITY end
return v
end
function U.WindowOpacity()
local db = NoWCL.db
if not db then return DEFAULT_WINDOW_OPACITY end
db.window = db.window or {}
db.window.opacity = clampWindowOpacity(db.window.opacity)
return db.window.opacity
end
function U.WindowOpaqueRows()
local db = NoWCL.db
return db and db.window and db.window.opaqueRows and true or false
end
function U.WindowPinSelf()
local db = NoWCL.db
return db and db.window and db.window.pinSelf and true or false
end
function U.WindowHealersFirst()
local db = NoWCL.db
return db and db.window and db.window.healersFirst and true or false
end
function U.SetWindowPinSelf(value)
local db = NoWCL.db
if db then
db.window = db.window or {}
db.window.pinSelf = value and true or nil
end
if NoWCL.AuditUI and NoWCL.AuditUI.Refresh then NoWCL.AuditUI:Refresh() end
if NoWCL.MiniUI and NoWCL.MiniUI.Refresh then
NoWCL.MiniUI.listScroll = 0
NoWCL.MiniUI:Refresh()
end
end
function U.SetWindowHealersFirst(value)
local db = NoWCL.db
if db then
db.window = db.window or {}
db.window.healersFirst = value and true or nil
end
if NoWCL.AuditUI and NoWCL.AuditUI.Refresh then NoWCL.AuditUI:Refresh() end
if NoWCL.MiniUI and NoWCL.MiniUI.Refresh then
NoWCL.MiniUI.listScroll = 0
NoWCL.MiniUI:Refresh()
end
end
function U.PinSelfFirst(players)
if not U.WindowPinSelf() or type(players) ~= "table" or #players < 2 then return nil end
local me = UnitName and UnitName("player")
if not me or me == "" then return nil end
local selfIndex
for i, pl in ipairs(players) do
local name = pl and pl.name
local short = type(name) == "string" and (name:match("^[^-]+") or name) or nil
if short == me then selfIndex = i; break end
end
if not selfIndex or selfIndex == 1 then return nil end
local originalRanks = {}
for i, pl in ipairs(players) do originalRanks[pl] = i end
local selfPlayer = table.remove(players, selfIndex)
table.insert(players, 1, selfPlayer)
return originalRanks
end
local HEALER_CAPABLE_CLASS = {
DRUID = true,
PALADIN = true,
PRIEST = true,
SHAMAN = true,
}
local function healingDominates(pl)
if type(pl) ~= "table" or not HEALER_CAPABLE_CLASS[pl.class] then return false end
local heal = U.HealingAmount(pl)
if heal <= 0 then return false end
local dmg = math.max(U.N(pl.dmg), U.N(pl.dmgBoss), U.N(pl.alignedDmg))
if dmg <= 0 then return true end
return heal >= math.max(10000, dmg * 2)
end
local function roleOverrideFor(name)
local ov = NoWCL.db and NoWCL.db.settings and NoWCL.db.settings.roleOverride
and name and NoWCL.db.settings.roleOverride[name]
if ov == "TANK" or ov == "HEALER" or ov == "DAMAGER" then return ov end
return nil
end
function U.RoleInferredHealer(pl)
if type(pl) ~= "table" then return false end
local name = pl.name
if roleOverrideFor(name) then return false end
local specId=tonumber(pl.specId or pl.readySpecId)
if specId and specId>0 then return false end
local r = pl.role
if r == "TANK" or r == "HEALER" then return false end
return healingDominates(pl)
end
function U.RoleOfPlayer(pl)
local name = type(pl) == "table" and pl.name or pl
local ov = roleOverrideFor(name)
if ov then return ov end
if type(pl) == "table" then
local specRole = U.RoleFromSpecialization(pl.specId or pl.readySpecId)
if specRole then return specRole end
local r = pl.role
if r == "TANK" or r == "HEALER" then return r end
if U.RoleInferredHealer(pl) then return "HEALER" end
if r then return "DAMAGER" end
end
if NoWCL.Stats and NoWCL.Stats.RoleOf and name then return NoWCL.Stats:RoleOf(name) end
return "DAMAGER"
end
function U.ResolveDamageMode(view, selection)
local cfgMode = view and view.cfg and view.cfg.dpsMode
local localMode = NoWCL.db and NoWCL.db.settings and NoWCL.db.settings.dpsMode
local mode = cfgMode or localMode or "boss"
mode = mode == "all" and "all" or "boss"
if selection == "current" and view and view.isBoss == false then return "all" end
return mode
end
function U.EffectiveTaskContrib(explicit)
if type(explicit)=="table" then return explicit end
local sync=NoWCL.Sync
if sync and sync.HasLeaderAuthority and sync:HasLeaderAuthority()
and sync.cfg and type(sync.cfg.taskContrib)=="table" then
return sync.cfg.taskContrib
end
return (NoWCL.db and NoWCL.db.settings and NoWCL.db.settings.taskContrib) or {}
end
function U.RawPlayerDisplayAmount(pl, mode)
if U.RoleOfPlayer(pl)=="HEALER" then return U.HealingAmount(pl) end
return mode=="all" and U.N(pl and pl.dmg) or U.N(pl and pl.dmgBoss)
end
function U.PlayerDisplayAmount(pl, mode, dur, taskContrib)
local amount=U.RawPlayerDisplayAmount(pl,mode)
dur=U.N(dur or (pl and pl.fightDur))
local seconds=U.TaskContributionSeconds
and U.TaskContributionSeconds(pl,U.EffectiveTaskContrib(taskContrib)) or 0
local bonus=dur>0 and amount/dur*seconds or 0
return amount+bonus,bonus
end
function U.PlayerDisplayRate(pl, mode, dur, taskContrib)
dur=U.N(dur)
local amount=U.PlayerDisplayAmount(pl,mode,dur,taskContrib)
return dur > 0 and amount / dur or 0
end
function U.DpsBaselineValue(players, baseline, excluded, mode, dur, taskContrib)
excluded = excluded or {}
if baseline == "tank" then
local value = 0
for _, player in ipairs(players or {}) do
if not excluded[player.name] and U.RoleOfPlayer(player) == "TANK" then
value=math.max(value,U.PlayerDisplayRate(player,mode,dur,taskContrib))
end
end
return value
end
local values = {}
for _, player in ipairs(players or {}) do
if not excluded[player.name] and U.RoleOfPlayer(player) == "DAMAGER" then
values[#values+1]=U.PlayerDisplayRate(player,mode,dur,taskContrib)
end
end
table.sort(values, function(left, right) return left > right end)
if baseline == "rank2" then return values[2] or values[1] or 0 end
if baseline == "average" then
local total = 0
for _, value in ipairs(values) do total = total + value end
return #values > 0 and total / #values or 0
end
if baseline == "median" then return #values > 0 and values[math.ceil(#values / 2)] or 0 end
return values[1] or 0
end
function U.DisplayRoleRank(pl)
local role = U.RoleOfPlayer(pl)
if role == "HEALER" then return U.WindowHealersFirst() and 0 or 3 end
if role == "TANK" then return 2 end
return 1
end
function U.SortDisplayPlayers(players, mode, dur, taskContrib)
table.sort(players, function(a, b)
local ar, br = U.DisplayRoleRank(a), U.DisplayRoleRank(b)
if ar ~= br then return ar < br end
local av,bv=U.PlayerDisplayRate(a,mode,dur,taskContrib),U.PlayerDisplayRate(b,mode,dur,taskContrib)
if av == bv then return (a.name or "") < (b.name or "") end
return av > bv
end)
return players
end
function U.DisplayRankingMeta(players, mode, dur, taskContrib)
local meta = {
ranks = {},
totals = { damage=0, healing=0 },
peaks = { damage=1, healing=1 },
}
local groupRanks = { damage=0, healing=0 }
local splitRanks = U.WindowHealersFirst()
for index, pl in ipairs(players or {}) do
local group = U.RoleOfPlayer(pl) == "HEALER" and "healing" or "damage"
local amount=U.PlayerDisplayAmount(pl,mode,dur,taskContrib)
groupRanks[group] = groupRanks[group] + 1
meta.ranks[pl] = splitRanks and groupRanks[group] or index
meta.totals[group] = meta.totals[group] + amount
if amount > meta.peaks[group] then meta.peaks[group] = amount end
end
return meta
end
function U.PlayerTimelineBuckets(pl, mode)
if U.RoleOfPlayer(pl) == "HEALER" then return pl and pl.healingBuckets, "HPS" end
if mode == "all" then return pl and pl.damageBuckets, "DPS" end
return pl and pl.bossDamageBuckets, "DPS"
end
local TIMELINE_MAX_SECONDS = 6 * 60 * 60
local TIMELINE_MAX_SOURCE_BUCKETS = 4320
local TIMELINE_MAX_INSPECTED_KEYS = TIMELINE_MAX_SOURCE_BUCKETS * 2
local TIMELINE_MAX_BUCKET_SECONDS = 60
local function finiteNumber(value)
value = tonumber(value)
if not value or value ~= value or value == math.huge or value == -math.huge then return nil end
return value
end
function U.TimelineRange(buckets, duration, bucketSeconds)
bucketSeconds = finiteNumber(bucketSeconds) or 5
bucketSeconds = math.min(TIMELINE_MAX_BUCKET_SECONDS, math.max(1, bucketSeconds))
duration = math.max(0, finiteNumber(duration) or 0)
duration = math.min(duration, TIMELINE_MAX_SECONDS, TIMELINE_MAX_SOURCE_BUCKETS * bucketSeconds)
local durationCount = math.max(1, math.ceil(duration / bucketSeconds))
local allowedStored = duration > 0 and math.min(TIMELINE_MAX_SOURCE_BUCKETS, durationCount + 1)
or TIMELINE_MAX_SOURCE_BUCKETS
local lastStored, inspected = 0, 0
for key in pairs(type(buckets) == "table" and buckets or {}) do
inspected = inspected + 1
if inspected > TIMELINE_MAX_INSPECTED_KEYS then break end
local bucket = finiteNumber(key)
if bucket and bucket >= 1 and bucket == math.floor(bucket) and bucket <= allowedStored then
lastStored = math.max(lastStored, bucket)
end
end
local sourceCount = math.min(TIMELINE_MAX_SOURCE_BUCKETS, math.max(durationCount, lastStored))
if duration <= 0 and lastStored > 0 then duration = math.min(TIMELINE_MAX_SECONDS, lastStored * bucketSeconds) end
return duration, bucketSeconds, sourceCount
end
function U.ResampleTimelineBuckets(buckets, duration, bucketSeconds, maxColumns)
local sourceCount
duration, bucketSeconds, sourceCount = U.TimelineRange(buckets, duration, bucketSeconds)
if type(buckets) ~= "table" or not next(buckets) then
return {}, 0, 0, {}, duration, bucketSeconds
end
maxColumns = math.min(720, math.max(1, math.floor(U.N(maxColumns or 16))))
local used = math.min(maxColumns, sourceCount)
local amounts, seconds, rates, spans = {}, {}, {}, {}
local rawPeak, hasData = 0, false
for i=1,sourceCount do
local span = bucketSeconds
if i==sourceCount and duration>(i-1)*bucketSeconds then
span = math.min(bucketSeconds,duration-(i-1)*bucketSeconds)
end
span = math.max(0.1,span)
local amount = U.N(buckets[i] ~= nil and buckets[i] or buckets[tostring(i)])
if amount ~= 0 then hasData = true end
rawPeak = math.max(rawPeak,amount/span)
local column = math.min(used,math.floor((i-1)*used/sourceCount)+1)
amounts[column] = U.N(amounts[column])+amount
seconds[column] = U.N(seconds[column])+span
local startSec = (i-1)*bucketSeconds
local endSec = startSec+span
spans[column] = spans[column] or { startSec=startSec, endSec=endSec }
spans[column].endSec = endSec
end
if not hasData then return {}, 0, 0, {}, duration, bucketSeconds end
for i=1,used do rates[i]=U.N(amounts[i])/math.max(0.1,U.N(seconds[i])) end
return rates, used, rawPeak, spans, duration, bucketSeconds
end
function U.TimelineBucketSpan(index, duration, bucketSeconds)
index = math.max(1, math.floor(U.N(index)))
duration = math.max(0, U.N(duration))
bucketSeconds = math.max(1, U.N(bucketSeconds or 5))
local startSec = (index-1)*bucketSeconds
local endSec = index*bucketSeconds
if duration>startSec then endSec=math.min(endSec,duration) end
if endSec<=startSec then endSec=startSec+bucketSeconds end
return startSec,endSec
end
local function timelineSecond(sec)
sec=math.max(0,U.N(sec))
local whole=math.floor(sec+0.5)
if math.abs(sec-whole)<0.05 then return tostring(whole) end
return string.format("%.1f",sec)
end
function U.ShowTimelineBarTooltip(owner, metric, rate, startSec, endSec)
if not (owner and GameTooltip) then return end
GameTooltip:SetOwner(owner,"ANCHOR_TOP")
GameTooltip:AddDoubleLine(
timelineSecond(startSec).."-"..timelineSecond(endSec).."秒",
(metric or "DPS").." "..string.format("%.0f",U.N(rate)),
0.8,0.8,0.8,1,0.82,0)
GameTooltip:Show()
end
function U.BindTimelineBarTooltip(hit, opacityRoot)
if not hit then return end
hit:SetScript("OnEnter",function(self)
if self.timelineRate==nil then return end
U.ShowTimelineBarTooltip(self,self.timelineMetric,self.timelineRate,
self.timelineStart,self.timelineEnd)
end)
hit:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
if opacityRoot and U.RegisterOpacityChromeHover then U.RegisterOpacityChromeHover(opacityRoot,hit) end
end
function U.PlayerDisplayMetric(pl, view, selection)
local mode = U.ResolveDamageMode(view, selection)
local dur = U.N(view and view.dur)
local taskContrib=view and view.cfg and view.cfg.taskContrib
local amount=U.PlayerDisplayAmount(pl,mode,dur,taskContrib)
return amount, dur > 0 and amount / dur or 0, U.RoleOfPlayer(pl), mode
end
function U.ShouldMergeLiveIntoSummary(live)
return live and live.live and live.recordable and live.isBoss and true or false
end
local function mergeNumberMap(dst, src)
for key, value in pairs(src or {}) do dst[key] = (dst[key] or 0) + U.N(value) end
end
function U.MergeCombatViews(base, live, includeDetails)
if not live or not live.players or #(live.players or {}) == 0 then return base end
if includeDetails == nil then includeDetails = true end
base = base or { encounter="所有战斗汇总", dur=0, players={} }
local byName, out = {}, {}
local function acc(pl, sourceDur, sourceName)
if not (pl and pl.name) then return end
local a = byName[pl.name]
if not a then
a = {
name=pl.name, class=pl.class, role=pl.role, specId=pl.specId,
dmg=0, dmgBoss=0, alignedDmg=0, heal=0,
interrupts=0, dispels=0, deaths=0, sunderApplied=0,
activeMs=0, extraTasks={},
}
if includeDetails then
a.spells={}; a.heals={}; a.targets={}; a.targetsBoss={}; a.healTargets={}
a.spellStats={}; a.healStats={}; a.castStats={}; a.castTargetStats={}
a.spellTargetStats={}; a.auraBuffs={}; a.auraDebuffs={}
end
byName[pl.name] = a
out[#out + 1] = a
end
a.class = a.class or pl.class
a.role = a.role or pl.role
a.specId = a.specId or pl.specId
U.NormalizePlayerClass(a)
a.gearKey = a.gearKey or pl.gearKey
local ilvl, readyIlvl = U.N(pl.ilvl), U.N(pl.readyIlvl)
if U.N(a.ilvl) <= 0 then
if ilvl > 0 then a.ilvl = ilvl elseif readyIlvl > 0 then a.ilvl = readyIlvl end
end
if a.lowQuality == nil then
if ilvl > 0 then a.lowQuality = pl.lowQuality or 0
elseif readyIlvl > 0 then a.lowQuality = pl.readyLowQuality or 0 end
end
if a.missEnch==nil then
if pl.gearAuditKnown then a.missEnch=pl.missEnch or 0;a.emptyGems=pl.emptyGems or 0;a.gearAuditKnown=true
elseif pl.readyMissEnch~=nil and pl.readyEmptyGems~=nil then
a.missEnch=pl.readyMissEnch;a.emptyGems=pl.readyEmptyGems;a.gearAuditKnown=true
end
end
a.dmg = a.dmg + U.N(pl.dmg)
a.dmgBoss = a.dmgBoss + U.N(pl.dmgBoss)
a.alignedDmg = a.alignedDmg + U.N(pl.alignedDmg)
a.heal = a.heal + U.HealingAmount(pl)
a.interrupts = a.interrupts + U.N(pl.interrupts)
a.dispels = a.dispels + U.N(pl.dispels)
a.deaths = a.deaths + U.N(pl.deaths)
a.sunderApplied = a.sunderApplied + U.N(pl.sunderApplied)
U.MergeExtraTasks(a.extraTasks, pl.extraTasks, pl.class)
a.activeMs = a.activeMs + U.N(pl.activeMs or (U.N(pl.activePct) * U.N(pl.fightDur or sourceDur) * 1000))
if includeDetails then
mergeNumberMap(a.spells, pl.spells)
mergeNumberMap(a.heals, pl.heals)
mergeNumberMap(a.targets, pl.targets)
mergeNumberMap(a.healTargets, pl.healTargets)
if NoWCL.DetailStats and NoWCL.DetailStats.MergePlayerDetails then
local bossCfg = base.cfg and base.cfg.bossCfg
or (NoWCL.db and NoWCL.db.settings and NoWCL.db.settings.bossCfg)
NoWCL.DetailStats.MergePlayerDetails(a, pl, sourceName, bossCfg)
end
for key in pairs(pl.targetsBoss or {}) do a.targetsBoss[key] = true end
end
if pl.synced then a.synced = true end
if pl.needUpdate then a.needUpdate = true end
a.ver = a.ver or pl.ver
end
for _, pl in ipairs(base.players or {}) do acc(pl, base.dur, base.encounter) end
for _, pl in ipairs(live.players or {}) do acc(pl, live.dur, live.encounter) end
local dur = math.max(1, U.N(base.dur) + U.N(live.dur))
for _, pl in ipairs(out) do
pl.dps = pl.dmg / dur
pl.bossDps = pl.dmgBoss / dur
pl.alignedDps = pl.alignedDmg / dur
pl.activePct = math.min(1, (pl.activeMs / 1000) / dur)
pl.extraTasks = U.CopyExtraTasks(pl.extraTasks, pl.class)
pl.fightDur = dur
end
base.encounter = (base.encounter or "所有战斗汇总") .. "+当前Boss"
base.dur = dur
base.players = out
base.live = true
base.isBoss = live.isBoss
base.recordable = live.recordable
if live.calibrated == false then
base.calibrated = false
base.uncalibratedCount = U.N(base.uncalibratedCount) + 1
end
return base
end
function U.CombatHistoryLimit()
local settings = NoWCL.db and NoWCL.db.settings
return settings and settings.autoPrune30 == false and 99 or 30
end
local ROLE_ICON_TEXTURE = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES"
local ROLE_ICON_COORDS = {
TANK = "0:19:22:41",
HEALER = "20:39:1:20",
}
function U.RoleIcon(role, size)
local coords = ROLE_ICON_COORDS[role]
if not coords then return "" end
size = size or 14
return string.format("|T%s:%d:%d:0:0:64:64:%s|t", ROLE_ICON_TEXTURE, size, size, coords)
end
function U.RolePrefix(pl, size)
local prefix = U.RoleIcon(U.RoleOfPlayer(pl), size)
if U.RoleInferredHealer(pl) then prefix = "|cffffd100?|r" .. prefix end
return prefix
end
function U.SyncOpacitySlider(slider)
if not slider then return end
local v = U.WindowOpacity()
slider._nowclSilent = true
slider:SetValue(v)
slider._nowclSilent = nil
end
function U.SyncOpacityModeCheck(check)
if not check then return end
check._nowclSilent = true
check:SetChecked(U.WindowOpaqueRows())
check._nowclSilent = nil
end
local function applyChromeOpacity(frame, alpha)
local list = frame and frame._nowclOpacityTextures
if not list then return end
for _, tex in ipairs(list) do
if tex and tex.SetAlpha then tex:SetAlpha(alpha) end
end
end
local function updateHoverControls(frame)
local list = frame and frame._nowclHoverControls
if not list then return end
local show = frame._nowclOpacityHover and true or false
for _, widget in ipairs(list) do
if widget and widget.SetShown then widget:SetShown(show) end
end
end
function U.RegisterOpacityChrome(frame, ...)
if not frame then return end
frame._nowclOpacityTextures = frame._nowclOpacityTextures or {}
for i = 1, select("#", ...) do
local obj = select(i, ...)
if obj then frame._nowclOpacityTextures[#frame._nowclOpacityTextures + 1] = obj end
end
end
local function isMouseOverFrame(frame)
if not frame then return false end
if MouseIsOver then return MouseIsOver(frame) and true or false end
if frame.IsMouseOver then return frame:IsMouseOver() and true or false end
return false
end
local function setOpacityHover(frame, enabled)
if not frame then return end
if enabled then
if frame._nowclOpacityHover then return end
frame._nowclOpacityHover = true
updateHoverControls(frame)
U.ApplyWindowOpacity(frame)
return
end
local function clearIfOutside()
if isMouseOverFrame(frame) then return end
if not frame._nowclOpacityHover then return end
frame._nowclOpacityHover = nil
updateHoverControls(frame)
U.ApplyWindowOpacity(frame)
end
if C_Timer and C_Timer.After then C_Timer.After(0.03, clearIfOutside)
else clearIfOutside() end
end
function U.RegisterOpacityChromeHover(frame, widget)
if not frame or not widget or not widget.SetScript then return end
local oldEnter = widget.GetScript and widget:GetScript("OnEnter") or nil
local oldLeave = widget.GetScript and widget:GetScript("OnLeave") or nil
widget:SetScript("OnEnter", function(self, ...)
setOpacityHover(frame, true)
if oldEnter then oldEnter(self, ...) end
end)
widget:SetScript("OnLeave", function(self, ...)
if oldLeave then oldLeave(self, ...) end
setOpacityHover(frame, false)
end)
end
function U.RegisterPanelHoverControls(frame, ...)
if not frame then return end
frame._nowclHoverControls = frame._nowclHoverControls or {}
for i = 1, select("#", ...) do
local widget = select(i, ...)
if widget then
frame._nowclHoverControls[#frame._nowclHoverControls + 1] = widget
end
end
updateHoverControls(frame)
end
function U.ApplyWindowOpacity(frame)
if not frame or not frame.SetAlpha then return end
local opacity = U.WindowOpacity()
local chromeOpacity = frame._nowclOpacityHover and 1 or opacity
if U.WindowOpaqueRows() then
frame:SetAlpha(1)
applyChromeOpacity(frame, chromeOpacity)
else
applyChromeOpacity(frame, 1)
frame:SetAlpha(frame._nowclOpacityHover and 1 or opacity)
end
end
function U.SetWindowOpacity(value)
local v = clampWindowOpacity(value)
local db = NoWCL.db
if db then
db.window = db.window or {}
db.window.opacity = v
end
if NoWCL.AuditUI and NoWCL.AuditUI.ApplyOpacity then NoWCL.AuditUI:ApplyOpacity() end
if NoWCL.MiniUI and NoWCL.MiniUI.ApplyOpacity then NoWCL.MiniUI:ApplyOpacity() end
return v
end
function U.SetWindowOpaqueRows(value)
local db = NoWCL.db
if db then
db.window = db.window or {}
db.window.opaqueRows = value and true or false
end
if NoWCL.AuditUI and NoWCL.AuditUI.ApplyOpacity then NoWCL.AuditUI:ApplyOpacity() end
if NoWCL.MiniUI and NoWCL.MiniUI.ApplyOpacity then NoWCL.MiniUI:ApplyOpacity() end
end
function U.MakeOpacitySlider(parent, name)
local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
slider:SetSize(64, 12)
slider:SetOrientation("HORIZONTAL")
slider:SetMinMaxValues(MIN_WINDOW_OPACITY, MAX_WINDOW_OPACITY)
slider:SetValueStep(0.05)
if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
local low = _G[name.."Low"]
local high = _G[name.."High"]
local text = _G[name.."Text"]
if low then low:SetText("") end
if high then high:SetText("") end
if text then
text:SetText("")
text:Hide()
end
slider:SetScript("OnValueChanged", function(self, value)
if self._nowclSilent then return end
U.SetWindowOpacity(value)
end)
U.SyncOpacitySlider(slider)
return slider
end
function U.MakeOpacityModeCheck(parent, name)
local check = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
check:SetSize(18, 18)
check:SetScript("OnClick", function(self)
if self._nowclSilent then return end
U.SetWindowOpaqueRows(self:GetChecked() and true or false)
end)
check:SetScript("OnEnter", function(self)
if not GameTooltip then return end
GameTooltip:SetOwner(self, "ANCHOR_TOP")
GameTooltip:AddLine("数据行保持不透明")
GameTooltip:AddLine("勾选后仅面板背景跟随透明度,排名行的伤害条、名字和数字保持清晰。", 0.8, 0.8, 0.8, true)
GameTooltip:Show()
end)
check:SetScript("OnLeave", function()
if GameTooltip then GameTooltip:Hide() end
end)
U.SyncOpacityModeCheck(check)
return check
end
function U.RenderTimelineAxis(axis, duration, opts)
if not axis then return end
opts = opts or {}
axis._nowclTicks = axis._nowclTicks or {}
for _, item in ipairs(axis._nowclTicks) do
item.mark:Hide(); item.label:Hide()
end
duration = math.max(0, U.N(duration))
if duration < 30 then return end
local width = axis:GetWidth()
if width < 10 then width = opts.fallbackWidth or 240 end
local spacing = width * 30 / duration
local labelEvery = math.max(1, math.ceil((opts.minLabelSpacing or 20) / math.max(1, spacing)))
local count = math.floor(duration / 30)
local created = false
for i = 1, count do
local item = axis._nowclTicks[i]
if not item then
local mark = axis:CreateTexture(nil, "ARTWORK")
mark:SetColorTexture(0.62, 0.62, 0.66, 0.55)
mark:SetSize(1, 3)
local label = axis:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
label:SetWidth(34); label:SetJustifyH("CENTER")
if opts.fontFn then opts.fontFn(label) end
item = { mark=mark, label=label }
axis._nowclTicks[i] = item
created = true
if opts.opacityRoot then U.RegisterOpacityChrome(opts.opacityRoot, mark, label) end
end
local seconds = i * 30
local x = width * math.min(1, seconds / duration)
item.mark:ClearAllPoints(); item.mark:SetPoint("TOP", axis, "TOPLEFT", x, 0); item.mark:Show()
item.label:ClearAllPoints()
if seconds >= duration - 0.01 then
item.label:SetPoint("TOPRIGHT", axis, "TOPRIGHT", 0, -2)
else
item.label:SetPoint("TOP", axis, "TOPLEFT", x, -2)
end
item.label:SetText(seconds .. "s")
item.label:SetShown(((i - 1) % labelEvery) == 0)
end
if created and opts.opacityRoot then U.ApplyWindowOpacity(opts.opacityRoot) end
end
function U.RenderTimelineGuides(plot, peak, opts)
if not plot then return end
opts = opts or {}
plot._nowclGuides = plot._nowclGuides or {}
for _, line in ipairs(plot._nowclGuides) do line:Hide() end
peak = math.max(0, U.N(peak))
local step = math.max(1, U.N(opts.step or 2000))
if peak < step then return end
local major = math.max(step, U.N(opts.major or 10000))
local height = plot:GetHeight()
if height < 10 then height = opts.fallbackHeight or 40 end
local count = math.floor(peak / step)
local created = false
for i = 1, count do
local line = plot._nowclGuides[i]
if not line then
line = plot:CreateTexture(nil, "BORDER")
line:SetHeight(1)
plot._nowclGuides[i] = line
created = true
if opts.opacityRoot then U.RegisterOpacityChrome(opts.opacityRoot, line) end
end
local value = i * step
line:ClearAllPoints()
line:SetPoint("BOTTOMLEFT", plot, "BOTTOMLEFT", 0, height * value / peak)
line:SetPoint("BOTTOMRIGHT", plot, "BOTTOMRIGHT", 0, height * value / peak)
if value % major == 0 then line:SetColorTexture(1.00, 0.82, 0.15, 0.55)
else line:SetColorTexture(0.72, 0.72, 0.76, 0.18) end
line:Show()
end
if created and opts.opacityRoot then U.ApplyWindowOpacity(opts.opacityRoot) end
end
local EXTRA_TASK_ORDER = {
"faerieFire", "battleRes", "powerInfusion", "tricks", "misdirection", "innervate",
"tranquility", "blueHymn", "redHymn", "heroism", "unholyFrenzy",
"handProtection", "handFreedom", "divineSacrifice", "handSacrifice", "auraMastery",
}
local EXTRA_TASK_LABELS = {
faerieFire = "精灵火",
battleRes = "战复",
powerInfusion = "灌注",
tricks = "嫁祸",
misdirection = "误导",
innervate = "激活",
tranquility = "宁静",
blueHymn = "蓝歌",
redHymn = "血歌",
heroism = "嗜血",
unholyFrenzy = "狂乱",
handProtection = "保护",
handFreedom = "自由",
divineSacrifice = "大牺",
handSacrifice = "小牺",
auraMastery = "光掌",
}
U.EXTRA_TASK_ORDER = EXTRA_TASK_ORDER
U.EXTRA_TASK_LABELS = EXTRA_TASK_LABELS
local TASK_CONTRIB_RULES = {
{ key="interrupts", label="打断", seconds=1.0, countField="interrupts", desc="预留/切目标/打断占用约 1.0 秒" },
{ key="dispels", label="驱散", seconds=1.2, countField="dispels", desc="通常占 GCD 并打断输出节奏,约 1.2 秒" },
{ key="sunder", label="破甲", seconds=1.0, countField="sunderApplied", desc="按有限有效层数/次数补偿,每次约 1.0 秒" },
{ key="faerieFire", label="精灵火", seconds=1.2, extraKey="faerieFire", desc="团队增益且占 GCD/切目标,每次约 1.2 秒" },
{ key="battleRes", label="战复", seconds=4.0, extraKey="battleRes", desc="高价值救场,含施法/转目标/风险成本,每次约 4.0 秒" },
{ key="powerInfusion", label="灌注", seconds=1.5, extraKey="powerInfusion", desc="支援他人,补偿一次操作窗口,每次约 1.5 秒" },
{ key="tricks", label="嫁祸", seconds=1.5, extraKey="tricks", desc="转目标/宏执行/团队任务成本,每次约 1.5 秒" },
{ key="misdirection", label="误导", seconds=1.5, extraKey="misdirection", desc="转目标/团队任务成本,每次约 1.5 秒" },
{ key="innervate", label="激活", seconds=2.0, extraKey="innervate", desc="支援任务,含转目标与 GCD 成本,每次约 2.0 秒" },
{ key="heroism", label="嗜血/英勇", seconds=1.5, extraKey="heroism", desc="只补偿按键/GCD 成本,不把全团收益归给施放者" },
{ key="unholyFrenzy", label="邪恶狂热", seconds=0.5, extraKey="unholyFrenzy", desc="WCL 已归因主要收益,这里只保守补偿操作成本 0.5 秒" },
{ key="tranquility", label="宁静", seconds=6.0, extraKey="tranquility", nonHealerOnly=true, desc="仅输出/T 施放时折算;治疗本职治疗量不重复奖励" },
{ key="blueHymn", label="蓝歌", seconds=6.0, extraKey="blueHymn", nonHealerOnly=true, desc="仅输出/T 施放时折算;治疗本职治疗量不重复奖励" },
{ key="redHymn", label="血歌", seconds=6.0, extraKey="redHymn", nonHealerOnly=true, desc="仅输出/T 施放时折算;治疗本职治疗量不重复奖励" },
{ key="handProtection", label="保护之手", seconds=1.5, extraKey="handProtection", desc="团队救场与转目标操作,每次约 1.5 秒" },
{ key="handFreedom", label="自由之手", seconds=1.5, extraKey="handFreedom", desc="团队解控与转目标操作,每次约 1.5 秒" },
{ key="divineSacrifice", label="神圣牺牲", seconds=1.5, extraKey="divineSacrifice", desc="团队减伤按键,每次约 1.5 秒" },
{ key="handSacrifice", label="牺牲之手", seconds=1.5, extraKey="handSacrifice", desc="单体减伤与转目标操作,每次约 1.5 秒" },
{ key="auraMastery", label="光环掌握", seconds=1.5, extraKey="auraMastery", desc="团队减伤/免打断窗口,每次约 1.5 秒" },
}
U.TASK_CONTRIB_RULES = TASK_CONTRIB_RULES
function U.CopyTaskContrib(src)
local out
if type(src) == "table" then
for _, rule in ipairs(TASK_CONTRIB_RULES) do
if src[rule.key] then out = out or {}; out[rule.key] = true end
end
end
return out or {}
end
function U.PackTaskContrib(src)
local parts = {}
src = src or {}
for _, rule in ipairs(TASK_CONTRIB_RULES) do
if src[rule.key] then parts[#parts + 1] = rule.key end
end
return table.concat(parts, ",")
end
function U.UnpackTaskContrib(payload)
local out = {}
if type(payload) ~= "string" or payload == "" then return out end
local allowed = {}
for _, rule in ipairs(TASK_CONTRIB_RULES) do allowed[rule.key] = true end
for item in payload:gmatch("[^,]+") do
if allowed[item] then out[item] = true end
end
return out
end
function U.TaskContributionSeconds(pl, enabled)
if type(pl) ~= "table" or type(enabled) ~= "table" then return 0 end
local role = U.RoleOfPlayer and U.RoleOfPlayer(pl) or "DAMAGER"
local tasks = pl.extraTasks or {}
local total = 0
for _, rule in ipairs(TASK_CONTRIB_RULES) do
if enabled[rule.key] and (not rule.nonHealerOnly or role ~= "HEALER") then
local n = 0
if rule.countField then n = U.N(pl[rule.countField])
elseif rule.extraKey then n = U.N(tasks[rule.extraKey]) end
if n > 0 then total = total + n * rule.seconds end
end
end
return total
end
function U.TaskContributionRate(pl, enabled, baseRate, fightDur)
local seconds = U.TaskContributionSeconds(pl, enabled)
fightDur = tonumber(fightDur) or 0
if seconds <= 0 or fightDur <= 0 then return 0, seconds end
return (tonumber(baseRate) or 0) * seconds / fightDur, seconds
end
function U.AddExtraTask(rec, key, amount)
if not rec or not key or not EXTRA_TASK_LABELS[key] then return end
rec.extraTasks = rec.extraTasks or {}
rec.extraTasks[key] = (rec.extraTasks[key] or 0) + (amount or 1)
end
function U.CopyExtraTasks(src, class)
if type(src) ~= "table" then return nil end
local out
for _, key in ipairs(EXTRA_TASK_ORDER) do
local v = U.N(src[key])
if v > 0 and (key ~= "heroism" or not class or class == "SHAMAN") then
out = out or {}
out[key] = v
end
end
return out
end
function U.MergeExtraTasks(dst, src, class)
if type(src) ~= "table" then return dst end
dst = dst or {}
for _, key in ipairs(EXTRA_TASK_ORDER) do
local v = U.N(src[key])
if v > 0 and (key ~= "heroism" or not class or class == "SHAMAN") then
dst[key] = (dst[key] or 0) + v
end
end
return dst
end
function U.PackExtraTasks(tasks)
if type(tasks) ~= "table" then return "" end
local parts = {}
for _, key in ipairs(EXTRA_TASK_ORDER) do
local v = math.floor(U.N(tasks[key]))
if v > 0 then parts[#parts + 1] = key .. ":" .. v end
end
return table.concat(parts, ",")
end
function U.UnpackExtraTasks(payload)
if type(payload) ~= "string" or payload == "" then return nil end
local out = {}
for item in payload:gmatch("[^,]+") do
local key, value = item:match("^([%w_]+):(%d+)$")
if key and EXTRA_TASK_LABELS[key] then out[key] = U.N(value) end
end
return next(out) and out or nil
end
function U.FormatExtraTasks(pl, isPuller, pullMethod)
local extra = {}
local tasks = pl.extraTasks or {}
if (pl.sunderApplied or 0) > 0 then extra[#extra + 1] = "破甲" .. pl.sunderApplied end
if U.N(tasks.faerieFire) > 0 then extra[#extra + 1] = EXTRA_TASK_LABELS.faerieFire .. U.N(tasks.faerieFire) end
if (pl.interrupts or 0) > 0 then extra[#extra + 1] = "打断" .. pl.interrupts end
if (pl.dispels or 0) > 0 then extra[#extra + 1] = "驱散" .. pl.dispels end
for _, key in ipairs(EXTRA_TASK_ORDER) do
if key ~= "faerieFire" then
local v = U.N(tasks[key])
if v > 0 then extra[#extra + 1] = EXTRA_TASK_LABELS[key] .. v end
end
end
local text = #extra > 0 and table.concat(extra, " ") or ""
if isPuller then
local pull = "开怪"
if pullMethod and pullMethod ~= "" then pull = pull .. "：" .. tostring(pullMethod) end
text = text .. (text ~= "" and " " or "") .. "|cffffd100" .. pull .. "|r"
end
return text ~= "" and text or "-"
end
function U.Trunc(s, n)
if not s or s == "" then return "" end
local i, cnt, len = 1, 0, #s
while i <= len and cnt < n do
local b = s:byte(i)
local step = (b < 0x80 and 1) or (b < 0xE0 and 2) or (b < 0xF0 and 3) or 4
i = i + step; cnt = cnt + 1
end
return s:sub(1, i-1)
end
function U.MakeMovable(f)
f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton"); f:SetClampedToScreen(true)
f:SetScript("OnDragStart", function(self) self:StartMoving() end)
f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
f:SetScript("OnHide", function(self) self:StopMovingOrSizing() end)
f:SetScript("OnMouseUp", function(self) self:StopMovingOrSizing() end)
end
local PCT_COLORS = {
{ 0.400, 0.400, 0.400 },
{ 0.118, 1.000, 0.000 },
{ 0.000, 0.439, 1.000 },
{ 0.639, 0.208, 0.933 },
{ 1.000, 0.502, 0.000 },
{ 0.886, 0.408, 0.659 },
{ 0.898, 0.800, 0.502 },
}
function U.ParseColor(pct)
local p = (pct or 0) * 100
if p >= 100 then return PCT_COLORS[7] end
if p >= 99  then return PCT_COLORS[6] end
if p >= 95  then return PCT_COLORS[5] end
if p >= 75  then return PCT_COLORS[4] end
if p >= 50  then return PCT_COLORS[3] end
if p >= 25  then return PCT_COLORS[2] end
return PCT_COLORS[1]
end
local ddMenu
local function setDropdownExpanded(dropdown, expanded)
if dropdown and dropdown.arrow then dropdown.arrow:SetText(expanded and "▼" or "▶") end
end
local function ensureMenu()
if ddMenu then return ddMenu end
local catcher = CreateFrame("Button", nil, UIParent)
catcher:SetAllPoints(UIParent); catcher:SetFrameStrata("TOOLTIP"); catcher:SetFrameLevel(9000); catcher:Hide()
local m = CreateFrame("Frame", nil, UIParent)
m:SetFrameStrata("TOOLTIP"); m:SetFrameLevel(catcher:GetFrameLevel()+5)
local bg=m:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0,0,0,0.5)
local br=m:CreateTexture(nil,"BORDER"); br:SetPoint("TOPLEFT",-1,1); br:SetPoint("BOTTOMRIGHT",1,-1); br:SetColorTexture(0,0,0,0.85)
m.btns={}
catcher:SetScript("OnClick", function() m:Hide() end)
m:SetScript("OnHide", function()
catcher:Hide()
setDropdownExpanded(m._owner, false)
end)
m.Open = function(self, owner)
local items = owner.itemsFn and owner.itemsFn() or {}
local w = math.max(owner.menuWidth or owner:GetWidth() or 90, 90)
local y = -3
for i, it in ipairs(items) do
local b = self.btns[i]
if not b then
b = CreateFrame("Button", nil, self); b:SetHeight(18)
b.dot=b:CreateTexture(nil,"ARTWORK"); b.dot:SetSize(8,8); b.dot:SetPoint("LEFT",6,0)
b.dot:SetTexture("Interface\\COMMON\\Indicator-Green")
b.t = b:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
b.t:SetPoint("LEFT",19,0); b.t:SetPoint("RIGHT",-5,0); b.t:SetJustifyH("LEFT")
local hl=b:CreateTexture(nil,"HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1,1,1,0.12)
if NoWCL.UIStyle and NoWCL.UIStyle.ApplyFontFace then NoWCL.UIStyle:ApplyFontFace(b.t) end
self.btns[i]=b
end
b:ClearAllPoints(); b:SetPoint("TOPLEFT",2,y); b:SetWidth(w-4)
b.dot:SetShown(it.checked and true or false)
b.t:SetText(tostring(it.text or ""))
b:SetScript("OnClick", function() self:Hide(); if owner.onSelect then owner.onSelect(it.value) end end)
b:Show(); y = y - 18
end
for i=#items+1, #self.btns do self.btns[i]:Hide() end
local h = -y + 3
self:SetSize(w, h)
local uiW = UIParent.GetWidth and UIParent:GetWidth() or w
local uiH = UIParent.GetHeight and UIParent:GetHeight() or h
local x = math.max(4, math.min(owner:GetLeft() or 4, uiW - w - 4))
local top = (owner:GetBottom() or uiH) - 2
if top - h < 4 then top = math.min(uiH - 4, h + 4) end
self:ClearAllPoints(); self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, top)
catcher:Show(); self:Show()
end
m:Hide(); ddMenu = m
if NoWCL.UIStyle and NoWCL.UIStyle.RegisterRoot then NoWCL.UIStyle:RegisterRoot(m) end
return m
end
function U.MakeDropdown(parent, width)
local dd = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
dd:SetSize(width, 22)
dd.arrow=dd:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
dd.arrow:SetSize(8,8);dd.arrow:SetPoint("LEFT",7,0);dd.arrow:SetJustifyH("CENTER")
local arrowFont=select(1,dd.arrow:GetFont()) or STANDARD_TEXT_FONT or "Fonts\\ARKai_T.ttf"
dd.arrow:SetFont(arrowFont,8,"OUTLINE");dd.arrow._nowclBaseFontSize=8
dd.arrow:SetText("▶")
dd.arrow:SetTextColor(1,0.82,0.22)
local label=dd:GetFontString()
if label then
label:ClearAllPoints();label:SetPoint("LEFT",18,0);label:SetPoint("RIGHT",-5,0);label:SetJustifyH("CENTER")
end
dd:SetScript("OnClick", function(self)
local m = ensureMenu()
if m:IsShown() and m._owner == self then m:Hide()
else
setDropdownExpanded(m._owner, false)
m._owner = self
setDropdownExpanded(self, true)
m:Open(self)
end
end)
return dd
end
