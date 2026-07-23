local addonName, NoWCL = ...
local RD = {}
NoWCL.Readiness = RD
local EQUIP_SLOTS = { 1,2,3,5,6,7,8,9,10,11,12,13,14,15,16,17,18 }
local REQUIRED_EQUIP_SLOTS = { 1,2,3,5,6,7,8,9,10,11,12,13,14,15,16,18 }
local SLOT_NAMES = {
[1]="头部",[2]="项链",[3]="肩部",[5]="胸甲",[6]="腰带",[7]="腿部",[8]="鞋",
[9]="护腕",[10]="手套",[11]="戒指1",[12]="戒指2",[13]="饰品1",[14]="饰品2",
[15]="披风",[16]="主手",[17]="副手",[18]="远程",
}
local ENCHANT_SLOTS = { [1]=true,[3]=true,[5]=true,[7]=true,[8]=true,[9]=true,[10]=true,[15]=true,[16]=true }
local ENCHANTABLE_OFFHANDS = { INVTYPE_WEAPON=true,INVTYPE_WEAPONOFFHAND=true,INVTYPE_SHIELD=true }
local ENCHANTABLE_RANGED_SUBCLASSES = { [2]=true,[3]=true,[18]=true }
local TITAN_ENCHANT_SOURCES = {
[8636]={1266779,260710},[8640]={1271413,264198},
[8652]={1281749,268129},[8653]={1281751,268131},[8654]={1281750,268130},
[8655]={1281758,268132},[8656]={1281761,268133},[8657]={1281766,268143},
[8658]={1281767,268144},[8659]={1281810,268151},[8660]={1281812,268152},
[8661]={1281820,268156},[8662]={1281817,268155},[8663]={1281814,268153},
[8664]={1281816,268154},[8665]={1282755,268544},[8666]={24420,20078},
[8667]={1282760,268542},[8668]={24422,20077},[8669]={1282758,268543},
[8670]={1282761,268174},[8671]={1282765,268541},[8680]={1289304,271660},
[8681]={1289307,271676},[8682]={27954,38910},[8683]={1289332,271695},
}
local validGearSet
local CLASSIC_SPEC_BY_TREE = {
DruidBalance=102,DruidFeralCombat=103,DruidRestoration=105,
HunterBeastMastery=253,HunterMarksmanship=254,HunterSurvival=255,
MageArcane=62,MageFire=63,MageFrost=64,
PaladinHoly=65,PaladinProtection=66,PaladinCombat=70,
PriestDiscipline=256,PriestHoly=257,PriestShadow=258,
RogueAssassination=259,RogueCombat=260,RogueSubtlety=261,
ShamanElementalCombat=262,ShamanEnhancement=263,ShamanRestoration=264,
WarlockCurses=265,WarlockSummoning=266,WarlockDestruction=267,
WarriorArms=71,WarriorArm=71,WarriorFury=72,WarriorProtection=73,
DeathKnightBlood=250,DeathKnightFrost=251,DeathKnightUnholy=252,
}
local function validSpecId(specId)
specId=tonumber(specId)
return specId and specId>0 and math.floor(specId) or nil
end
local function classicSpecId(unit, isInspect)
if not GetTalentTabInfo then return nil end
local bestPoints,bestTree=-1,nil
local tabs=(GetNumTalentTabs and GetNumTalentTabs()) or MAX_TALENT_TABS or 3
tabs=math.max(1,math.min(tonumber(tabs) or 3,MAX_TALENT_TABS or 3))
for index=1,tabs do
local _,_,_,_,points,tree=GetTalentTabInfo(index,isInspect and true or false,false)
points=tonumber(points) or 0
if tree and points>bestPoints then bestPoints,bestTree=points,tree end
end
local specId=bestPoints>=4 and CLASSIC_SPEC_BY_TREE[bestTree] or nil
if specId==103 and UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)=="TANK" then specId=104 end
return validSpecId(specId)
end
local function unitSpecId(unit)
if unit=="player" and GetSpecialization and GetSpecializationInfo then
local index=GetSpecialization()
if index then return validSpecId(GetSpecializationInfo(index)) end
end
if GetInspectSpecialization then
local specId=validSpecId(GetInspectSpecialization(unit))
if specId then return specId end
end
return classicSpecId(unit,unit~="player")
end
local function parseItemLink(link)
local itemString = type(link)=="string" and (link:match("|Hitem:([^|]+)|h") or link:match("item:([^|%s]+)"))
if not itemString then return 0,0 end
local parts = {}
for field in (itemString .. ":"):gmatch("([^:]*):") do parts[#parts+1]=field end
local gems=0
for index=3,6 do if (tonumber(parts[index]) or 0)>0 then gems=gems+1 end end
return tonumber(parts[2]) or 0,gems
end
local function itemTypeInfo(link)
local equipLoc,classId,subClassId
if GetItemInfoInstant then
local _,_,_,instantLoc,_,instantClass,instantSubclass=GetItemInfoInstant(link)
equipLoc,classId,subClassId=instantLoc,instantClass,instantSubclass
end
if not equipLoc and GetItemInfo then equipLoc=select(9,GetItemInfo(link)) end
return equipLoc,tonumber(classId),tonumber(subClassId)
end
local function itemSocketCount(link)
if not (link and GetItemStats) then return 0 end
local ok,stats=pcall(GetItemStats,link)
if not ok or type(stats)~="table" then return 0 end
local count=0
for key,value in pairs(stats) do
if type(key)=="string" and key:find("EMPTY_SOCKET",1,true) then
count=count+(tonumber(value) or 0)
end
end
return count
end
local function needsEnchant(slot,link)
if ENCHANT_SLOTS[slot] then return true end
local equipLoc,classId,subClassId=itemTypeInfo(link)
if slot==17 then return ENCHANTABLE_OFFHANDS[equipLoc]==true end
return slot==18 and classId==2 and ENCHANTABLE_RANGED_SUBCLASSES[subClassId]==true
end
function RD:NeedsEnchant(slot, link)
return needsEnchant(tonumber(slot), link)
end
local function auditGearItems(unit,items)
local audit={ lowQuality=0,missEnch=0,emptyGems=0,lowQualityItems={},missingEnchantSlots={},emptyGemSlots={} }
for _,slot in ipairs(EQUIP_SLOTS) do
local link=items and items[slot]
if link then
local quality=(unit and GetInventoryItemQuality and GetInventoryItemQuality(unit,slot))
or (GetItemInfo and select(3,GetItemInfo(link)))
if quality and quality>=2 and quality<4 then
audit.lowQuality=audit.lowQuality+1
audit.lowQualityItems[#audit.lowQualityItems+1]={ slot=slot,name=SLOT_NAMES[slot],link=link }
end
local enchant,gems=parseItemLink(link)
if needsEnchant(slot,link) and enchant<=0 then
audit.missEnch=audit.missEnch+1
audit.missingEnchantSlots[#audit.missingEnchantSlots+1]={ slot=slot,name=SLOT_NAMES[slot] }
end
local empty=math.max(0,itemSocketCount(link)-gems)
if empty>0 then
audit.emptyGems=audit.emptyGems+empty
audit.emptyGemSlots[#audit.emptyGemSlots+1]={ slot=slot,name=SLOT_NAMES[slot],count=empty }
end
end
end
return audit
end
local function summarizeGear(unit, items, specId)
local class = unit and UnitClass and select(2, UnitClass(unit)) or nil
local out = { ilvl = 0, lowQuality = 0, items = items or {}, specId=specId, class=class }
local sum, cnt, linkCount = 0, 0, 0
for _, slot in ipairs(EQUIP_SLOTS) do
local link = out.items[slot]
if link then
linkCount = linkCount + 1
local il = GetItemInfo and select(4, GetItemInfo(link))
if il then sum=sum+il; cnt=cnt+1 end
end
end
local audit=auditGearItems(unit,out.items)
out.lowQuality=audit.lowQuality
out.missEnch=audit.missEnch
out.emptyGems=audit.emptyGems
out.gearAudit=audit
if unit == "player" and GetAverageItemLevel then
local _, equipped = GetAverageItemLevel()
out.ilvl = math.floor((equipped or GetAverageItemLevel() or 0) + 0.5)
else
if cnt > 0 then out.ilvl = math.floor(sum/cnt + 0.5) end
end
out.itemCount = linkCount
out.gearScanned = validGearSet and validGearSet(out.items) or false
out.gearAuditKnown = out.gearScanned
return out
end
function RD:ScanGear(unit)
local items = {}
if unit ~= "player" and (not UnitExists or not UnitExists(unit)) then
return summarizeGear(unit, items)
end
for _, slot in ipairs(EQUIP_SLOTS) do
local link = GetInventoryItemLink and GetInventoryItemLink(unit, slot)
if link then items[slot] = link end
end
return summarizeGear(unit, items, unitSpecId(unit))
end
function RD:Scan()
local name = UnitName and UnitName("player")
local c = name and self.localCache and self.localCache[name]
if c and (c.ilvl or 0) > 0 and c.gearKey and validSpecId(c.specId) then
return { ilvl=c.ilvl,lowQuality=c.lowQuality or 0,missEnch=c.missEnch,emptyGems=c.emptyGems,
gearAuditKnown=c.gearAuditKnown==true,specId=c.specId }
end
local g = self:ScanGear("player")
if name then self:CacheGear(name, g) end
return { ilvl=g.ilvl,lowQuality=g.lowQuality,missEnch=g.missEnch,emptyGems=g.emptyGems,
gearAuditKnown=g.gearAuditKnown==true,specId=g.specId }
end
RD.localCache = {}
RD.gearSets = {}
RD.gearAuditCache = {}
RD.gearPreview = {}
local iq, whisperIq, pending = {}, {}, nil
local INSPECT_RETRY_SEC = 30
local SCAN_RETRY_INTERVAL = 5
local SCAN_WINDOW_SEC = 180
local INSPECT_SAMPLE_DELAY = 0.20
local INSPECT_MAX_SAMPLES = 3
local INSPECT_STABLE_SAMPLES = 2
local WHISPER_PROMPT_DEDUPE_SEC = 30
local WHISPER_PROMPT_WAIT_SEC = 300
local TALENT_EMU_QUERY_TIMEOUT_SEC = 5
local TALENT_EMU_CACHE_SEC = 30
local TALENT_EMU_QUERY_INTERVAL_SEC = 1
local pumpTicker
local talentEmuQueue, talentEmuQueued, talentEmuPending = {}, {}, {}
local talentEmuRetryAt = {}
local talentEmuLastQueryAt = -math.huge
local function inspectLocked()
return InCombatLockdown and InCombatLockdown() and true or false
end
local function hasValidGear(c)
return c and (c.ilvl or 0) > 0
end
validGearSet = function(items)
if type(items) ~= "table" then return false end
for _, slot in ipairs(REQUIRED_EQUIP_SLOTS) do
if type(items[slot]) ~= "string" or items[slot] == "" then return false end
end
return true
end
local function sameGearSet(a, b)
for _, slot in ipairs(EQUIP_SLOTS) do if (a and a[slot]) ~= (b and b[slot]) then return false end end
return true
end
local function copyGearSet(items)
local out = {}
for _, slot in ipairs(EQUIP_SLOTS) do
local link = items and items[slot]
if type(link) == "string" and link ~= "" then out[slot] = link end
end
return out
end
function RD:CacheGearPreview(name, items)
local copy=copyGearSet(items)
if not name or not next(copy) then return false end
self.gearPreview=self.gearPreview or {}
self.gearPreview[name]=copy
local panel=NoWCL.GearInspectPanel
if panel and panel.OnGearUpdated then panel:OnGearUpdated(name) end
return true
end
local function mergeGearSamples(unit, old, fresh)
local items = copyGearSet(old and old.items)
for _, slot in ipairs(EQUIP_SLOTS) do
local link = fresh and fresh.items and fresh.items[slot]
if link then items[slot] = link end
end
return summarizeGear(unit, items, (fresh and fresh.specId) or (old and old.specId))
end
local function baseGearKey(items)
local hash, bytes = 5381, 0
for _, slot in ipairs(EQUIP_SLOTS) do
local value = tostring(slot) .. "=" .. tostring(items and items[slot] or "") .. ";"
bytes = bytes + #value
for i = 1, #value do hash = (hash * 33 + value:byte(i)) % 2147483647 end
end
return string.format("%08x-%d", hash, bytes)
end
function RD:StoreGearSet(items)
if not validGearSet(items) then return nil end
self.gearSets = self.gearSets or {}
local base, key, suffix = baseGearKey(items), nil, 1
repeat
key = suffix == 1 and base or (base .. "-" .. suffix)
local old = self.gearSets[key]
if not old or sameGearSet(old, items) then break end
suffix = suffix + 1
until false
if not self.gearSets[key] then self.gearSets[key] = copyGearSet(items) end
return key
end
function RD:GetGearSet(key)
return key and self.gearSets and self.gearSets[key] or nil
end
function RD:AuditGearSet(key)
if not key then return nil end
self.gearAuditCache=self.gearAuditCache or {}
if self.gearAuditCache[key] then return self.gearAuditCache[key] end
local items=self:GetGearSet(key)
if not items then return nil end
local audit=auditGearItems(nil,items)
self.gearAuditCache[key]=audit
return audit
end
local function hasFullGear(c)
return c and c.gearKey and RD:GetGearSet(c.gearKey) ~= nil
end
local function copyValidGearCache(src)
local out = {}
for name, c in pairs(src or {}) do
if type(name) == "string" and hasValidGear(c) then
out[name] = { ilvl = tonumber(c.ilvl) or 0, lowQuality = tonumber(c.lowQuality) or 0 }
if c.gearAuditKnown==true then
out[name].gearAuditKnown=true
out[name].missEnch=tonumber(c.missEnch) or 0
out[name].emptyGems=tonumber(c.emptyGems) or 0
end
if type(c.gearKey) == "string" and c.gearKey ~= "" then out[name].gearKey = c.gearKey end
if validSpecId(c.specId) then out[name].specId=validSpecId(c.specId) end
if type(c.class) == "string" and c.class ~= "" then out[name].class=c.class end
end
end
return out
end
function RD:Persist()
if not NoWCLDB then return end
NoWCLDB.readinessCache = copyValidGearCache(self.localCache)
NoWCLDB.gearSets = {}
for key, items in pairs(self.gearSets or {}) do
if type(key) == "string" and validGearSet(items) then NoWCLDB.gearSets[key] = copyGearSet(items) end
end
end
function RD:Restore()
self.gearSets = {}
self.gearAuditCache = {}
self.gearPreview = {}
for key, items in pairs(NoWCLDB and NoWCLDB.gearSets or {}) do
if type(key) == "string" and validGearSet(items) then self.gearSets[key] = copyGearSet(items) end
end
self.localCache = copyValidGearCache(NoWCLDB and NoWCLDB.readinessCache or self.localCache)
for _,c in pairs(self.localCache) do
if c.gearKey and not self.gearSets[c.gearKey] then
c.gearKey=nil
elseif c.gearKey then
local audit=self:AuditGearSet(c.gearKey)
if audit then
c.lowQuality=audit.lowQuality;c.missEnch=audit.missEnch;c.emptyGems=audit.emptyGems;c.gearAuditKnown=true
end
end
end
end
function RD:CacheGear(name, g)
if not name or not hasValidGear(g) then return false end
self.localCache = self.localCache or {}
local ilvl = tonumber(g.ilvl) or 0
local lowQuality = tonumber(g.lowQuality) or 0
local specId=validSpecId(g.specId)
local class=type(g.class)=="string" and g.class~="" and g.class or nil
local c = self.localCache[name] or {}
local gearKey = g.gearScanned and self:StoreGearSet(g.items) or nil
local auditKnown=g.gearAuditKnown==true or gearKey~=nil
local missEnch=auditKnown and (tonumber(g.missEnch) or 0) or nil
local emptyGems=auditKnown and (tonumber(g.emptyGems) or 0) or nil
local changed = c.ilvl ~= ilvl or (c.lowQuality or 0) ~= lowQuality or (gearKey and c.gearKey ~= gearKey)
or (specId and c.specId~=specId) or (class and c.class~=class)
or (auditKnown and (c.gearAuditKnown~=true or c.missEnch~=missEnch or c.emptyGems~=emptyGems))
c.ilvl = ilvl
c.lowQuality = lowQuality
if gearKey then
c.gearKey=gearKey
self:CacheGearPreview(name,g.items)
self.gearAuditCache=self.gearAuditCache or {}
self.gearAuditCache[gearKey]=g.gearAudit or auditGearItems(nil,g.items)
end
if auditKnown then c.missEnch=missEnch;c.emptyGems=emptyGems;c.gearAuditKnown=true end
if specId then c.specId=specId end
if class then c.class=class end
self.localCache[name] = c
if changed then self:Persist() end
if self.FlushWhisperGearPrompt then self:FlushWhisperGearPrompt(name) end
local panel = NoWCL.GearInspectPanel
if panel and panel.OnGearUpdated then panel:OnGearUpdated(name) end
return true
end
function RD:CacheSpecialization(name, specId)
specId=validSpecId(specId)
if not (name and specId) then return false end
self.localCache=self.localCache or {}
local c=self.localCache[name] or {}
if c.specId==specId then return false end
c.specId=specId
self.localCache[name]=c
self:Persist()
return true
end
local function groupUnits()
local units = {}
if not IsInGroup() then return units end
if IsInRaid() then
for i = 1, GetNumGroupMembers() do local u="raid"..i; if UnitExists(u) then units[#units+1]=u end end
else
units[#units+1] = "player"
for i = 1, (GetNumGroupMembers() or 1)-1 do local u="party"..i; if UnitExists(u) then units[#units+1]=u end end
end
return units
end
local function unitName(unit)
if not (unit and UnitExists and UnitExists(unit) and UnitName) then return nil end
return UnitName(unit)
end
local function whisperGearPromptEnabled()
return NoWCL.db and NoWCL.db.settings and NoWCL.db.settings.whisperGearPrompt == true
end
local function shortName(name)
return type(name) == "string" and (name:match("^[^-]+") or name) or nil
end
local WHISPER_YELLOW = "|cffffd100"
local TALENT_EMU_SPEC_IDS = {
DEATHKNIGHT={250,251,252}, DRUID={102,103,105}, HUNTER={253,254,255},
MAGE={62,63,64}, PALADIN={65,66,70}, PRIEST={256,257,258},
ROGUE={259,260,261}, SHAMAN={262,263,264}, WARLOCK={265,266,267},
WARRIOR={71,72,73},
}
local TALENT_EMU_SPEC_NAMES = {
DEATHKNIGHT={"鲜血","冰霜","邪恶"}, DRUID={"平衡","野性战斗","恢复"},
HUNTER={"野兽控制","射击","生存"}, MAGE={"奥术","火焰","冰霜"},
PALADIN={"神圣","防护","惩戒"}, PRIEST={"戒律","神圣","暗影"},
ROGUE={"刺杀","战斗","敏锐"}, SHAMAN={"元素","增强","恢复"},
WARLOCK={"痛苦","恶魔学识","毁灭"}, WARRIOR={"武器","狂怒","防护"},
}
local function whisperItemLevelColor(level)
level = tonumber(level) or 0
if level < 230 then return "|cffffffff" end
if level < 240 then return "|cff1EFF00" end
if level < 250 then return "|cff0070FF" end
if level < 260 then return "|cffA335EE" end
return "|cffFF8000"
end
local function unitMatchesPlayerName(unit, name)
if not (unit and name and UnitExists and UnitExists(unit) and UnitName) then return false end
if UnitIsPlayer and not UnitIsPlayer(unit) then return false end
return shortName(UnitName(unit)) == shortName(name)
end
local function whisperUnitByName(name)
local util = NoWCL.Util
local unit = util and util.UnitTokenByName and util.UnitTokenByName(name) or nil
if unit then return unit end
for _, candidate in ipairs({ "target", "focus", "mouseover" }) do
if unitMatchesPlayerName(candidate, name) then return candidate end
end
return nil
end
local function whisperPlayerClass(name, unit, guid, cache)
local class = unit and UnitClass and select(2, UnitClass(unit)) or nil
if not class and guid and GetPlayerInfoByGUID then class = select(2, GetPlayerInfoByGUID(guid)) end
class = class or (cache and cache.class)
local util = NoWCL.Util
if not class and cache and util and util.ClassFromSpecialization then
class = util.ClassFromSpecialization(cache.specId)
end
local roster = NoWCL.Stats and NoWCL.Stats.roster
return class or (roster and roster[name] and roster[name].class) or nil
end
local function whisperPlayerLink(name, context, cache)
local sender = tostring(context and context.sender or name or "未知"):gsub("|", "")
local display = tostring(name or "未知"):gsub("|", "")
local link = string.format("|Hplayer:%s|h%s|h", sender, display)
local util = NoWCL.Util
local class = context and context.class or whisperPlayerClass(name, context and context.unit,
context and context.guid, cache)
return util and util.ClassColor and util.ClassColor(link, class) or link
end
local function talentEmuRuntime()
local meta = _G and rawget(_G, "__ala_meta__")
local emu = meta and meta.emu
if type(emu) ~= "table" or type(emu.MT) ~= "table" or type(emu.VT) ~= "table"
or type(emu.MT.SendQueryRequest) ~= "function" or type(emu.VT.TQueryCache) ~= "table" then
return nil
end
return emu
end
local function talentEmuCache(emu, name, sender)
local caches = emu and emu.VT and emu.VT.TQueryCache
if type(caches) ~= "table" then return nil end
local candidates, seen = { sender, name, shortName(sender), shortName(name) }, {}
for _, candidate in ipairs(candidates) do
if candidate and candidate ~= "" and not seen[candidate] then
seen[candidate] = true
if type(caches[candidate]) == "table" then return caches[candidate] end
end
end
local wanted = shortName(name or sender)
if wanted then
for candidate, cache in pairs(caches) do
if type(candidate) == "string" and shortName(candidate) == wanted and type(cache) == "table" then
return cache
end
end
end
return nil
end
local function talentEmuNow(emu)
local getTime = emu and emu.MT and emu.MT.GetUnifiedTime
if type(getTime) == "function" then
local ok, value = pcall(getTime)
if ok and tonumber(value) then return tonumber(value) end
end
return GetTime and GetTime() or 0
end
local function talentEmuCacheFresh(emu, cache)
local tick = cache and cache.EquData and tonumber(cache.EquData.Tick)
if not tick then return false end
local age = talentEmuNow(emu) - tick
return age >= 0 and age <= TALENT_EMU_CACHE_SEC
end
local function talentEmuItemsReady(items)
local found = false
for _, slot in ipairs(EQUIP_SLOTS) do
local link = items and items[slot]
if link then
found = true
if not GetItemInfo then return false end
local _, _, quality, itemLevel = GetItemInfo(link)
if quality == nil or itemLevel == nil then return false end
end
end
return found
end
local function talentEmuTalentSummary(emu, cache)
local class = cache and cache.class
local talData = cache and cache.TalData
local countTreePoints = emu and emu.MT and emu.MT.CountTreePoints
if type(class) ~= "string" or type(talData) ~= "table" or talData.Tick == nil
or type(countTreePoints) ~= "function" then
return nil
end
local active = math.max(1, math.floor(tonumber(talData.active) or 1))
local data = talData[active]
if type(data) ~= "string" and type(data) ~= "table" then return nil end
local ok, rawPoints = pcall(countTreePoints, data, class)
if not ok or type(rawPoints) ~= "table" then return nil end
local points, bestIndex, bestPoints = {}, nil, -1
for index=1,3 do
local value = tonumber(rawPoints[index])
if not value or value < 0 or value > 100 then return nil end
value = math.floor(value)
points[index] = value
if value >= bestPoints then bestIndex, bestPoints = index, value end
end
if bestPoints <= 0 then return nil end
local treeIds = emu.DT and emu.DT.ClassSpec and emu.DT.ClassSpec[class]
local treeId = type(treeIds) == "table" and treeIds[bestIndex] or nil
local specLabels = emu.CT and emu.CT.l10n and emu.CT.l10n.SPEC
local fallbackNames = TALENT_EMU_SPEC_NAMES[class]
local specIds = TALENT_EMU_SPEC_IDS[class]
return {
points=table.concat(points,"/"),
specName=(type(specLabels) == "table" and specLabels[treeId])
or (fallbackNames and fallbackNames[bestIndex]) or "未知",
specId=specIds and specIds[bestIndex] or nil,
}
end
local function talentEmuTalentSummaries(emu, cache)
local talData = cache and cache.TalData
if type(talData) ~= "table" then return nil end
local active = math.max(1, math.floor(tonumber(talData.active) or 1))
local summaries = {}
for group=1,2 do
local clone = { class=cache.class, TalData={ Tick=talData.Tick, active=group, [group]=talData[group] } }
local summary = talentEmuTalentSummary(emu, clone)
if summary then
summary.group = group
summary.active = group == active
summaries[#summaries + 1] = summary
end
end
return #summaries > 0 and summaries or nil
end
function RD:FormatWhisperPrefix(name, context, cache)
return WHISPER_YELLOW .. "玩家「" .. whisperPlayerLink(name, context, cache)
.. WHISPER_YELLOW .. "」密语你："
end
function RD:FormatWhisperGearPrompt(name, cache, context)
if not hasValidGear(cache) then return nil end
local ilvl = math.floor((tonumber(cache.ilvl) or 0) + 0.5)
local lowQuality = math.max(0, math.floor(tonumber(cache.lowQuality) or 0))
local lowText = lowQuality > 0 and ("|cffffd100" .. lowQuality .. "件|r") or "|cff44ff44无|r"
local slots = {}
local audit = cache.gearKey and self:AuditGearSet(cache.gearKey) or nil
for _, item in ipairs(audit and audit.lowQualityItems or {}) do
if item.name and #slots < 6 then slots[#slots + 1] = item.name end
end
local detail = #slots > 0 and ("（" .. table.concat(slots, "、")
.. (lowQuality > #slots and "…" or "") .. "）") or ""
local talent = context and context.talentSummary
local talentText = talent and ("专精 |cffffffff" .. talent.specName .. "|r" .. WHISPER_YELLOW
.. "，天赋 |cffffffff" .. talent.points .. "|r" .. WHISPER_YELLOW .. "，") or ""
return self:FormatWhisperPrefix(name, context, cache) .. talentText
.. "装等 " .. whisperItemLevelColor(ilvl) .. ilvl .. "|r"
.. WHISPER_YELLOW .. "，蓝绿装 " .. lowText .. WHISPER_YELLOW .. detail .. "|r"
end
function RD:FlushWhisperGearPrompt(name)
local requests = self._whisperGearRequests
local request = requests and requests[name]
if not request then return false end
local now = GetTime and GetTime() or 0
if request.expires and now > request.expires then
requests[name] = nil
return false
end
if request.talentEmuStarted and not request.talentEmuResolved and not request.fallbackStarted then
return false
end
local cache = self.localCache and self.localCache[name]
local message = self:FormatWhisperGearPrompt(name, cache, request)
if not message then return false end
requests[name] = nil
if NoWCL.Print then NoWCL:Print(message) end
return true
end
function RD:GetTalentEmuTalentInfo(name, sender)
local emu = talentEmuRuntime()
return talentEmuTalentSummaries(emu, talentEmuCache(emu, name, sender))
end
local function enchantSourceInfo(emu, item, enchantId)
local titan=TITAN_ENCHANT_SOURCES[enchantId]
if titan then return titan[1],titan[2] end
local _,classId,subClassId=itemTypeInfo(item)
local entries=emu and emu.DT and emu.DT.EnchantDB and emu.DT.EnchantDB[classId]
entries=entries and entries[enchantId]
if type(entries)~="table" then return nil,nil end
local itemId=GetItemInfoInstant and select(1,GetItemInfoInstant(item)) or nil
local invType=C_Item and C_Item.GetItemInventoryTypeByID and itemId
and C_Item.GetItemInventoryTypeByID(itemId) or nil
local band=bit and bit.band
local lshift=bit and bit.lshift
local function allowed(mask,value)
return mask==nil or value==nil or not (band and lshift) or band(mask,lshift(1,value))>0
end
for index=#entries,1,-1 do
local source=entries[index]
if allowed(source[1],subClassId) and allowed(source[2],invType) then
return source[3],source[4]
end
end
local source=entries[#entries]
return source and source[3],source and source[4]
end
function RD:GetTalentEmuEnchantInfo(class, slot, item)
local emu = talentEmuRuntime()
local getInfo = emu and emu.MT and emu.MT.GetEnchantInfo
if type(getInfo) ~= "function" or not item then return nil end
local ok, enchantable, enchanted, link, level, description = pcall(getInfo, class, slot, item)
if not ok then return nil end
local enchantId=parseItemLink(item)
local spellId,itemId=enchantSourceInfo(emu,item,enchantId)
enchanted=enchanted or enchantId>0
if enchanted and spellId and GetSpellInfo then description=GetSpellInfo(spellId) or description end
if enchanted and not description and itemId and GetItemInfo then description=GetItemInfo(itemId) end
return {
enchantable=enchantable and true or false, enchanted=enchanted and true or false,
link=link, level=tonumber(level), description=description,
enchantId=enchantId, spellId=spellId, itemId=itemId,
}
end
function RD:ImportTalentEmuGear(name, request, freshOnly)
request = request or {}
local emu = talentEmuRuntime()
local cache = talentEmuCache(emu, name, request and request.sender)
local talData = cache and cache.TalData
local equData = cache and cache.EquData
if (type(talData) == "table" and talData.Tick ~= nil)
or (type(equData) == "table" and equData.Tick ~= nil) then
request.talentEmuResponded = true
end
if freshOnly and not talentEmuCacheFresh(emu, cache) then return false end
local talentSummary = talentEmuTalentSummary(emu, cache)
if talentSummary then request.talentSummary = talentSummary end
if type(equData) ~= "table" or equData.Tick == nil then return false end
local items = copyGearSet(equData)
self:CacheGearPreview(name,items)
if not talentEmuItemsReady(items) then return false end
local gear = summarizeGear(nil, items)
local average = tonumber(equData.AverageItemLevel)
if average and average > 0 then gear.ilvl = math.floor(average + 0.5) end
gear.class = cache.class or request.class
gear.specId = (talentSummary and talentSummary.specId) or gear.specId
if not hasValidGear(gear) then return false end
request.talentEmuResolved = true
self:CacheGear(name, gear)
return true
end
function RD:RegisterTalentEmuCallbacks()
local emu=talentEmuRuntime()
local register=emu and emu.MT and emu.MT._RegisterCallback
if type(register)~="function" or self._talentEmuCallbackRuntime==emu then return false end
self._talentEmuInventoryCallback=self._talentEmuInventoryCallback or function(name)
local wanted=shortName(name) or name
if not wanted then return end
local request=talentEmuPending[wanted]
if not request then
for pendingName,pendingRequest in pairs(talentEmuPending) do
if shortName(pendingName)==wanted then
wanted,request=pendingName,pendingRequest
break
end
end
end
request=request or {sender=name}
if RD:ImportTalentEmuGear(wanted,request,true) then
talentEmuPending[wanted]=nil
end
end
register("CALLBACK_INVENTORY_DATA_RECV",self._talentEmuInventoryCallback)
register("CALLBACK_INVENTORY_DATA_CHANGED",self._talentEmuInventoryCallback)
self._talentEmuCallbackRuntime=emu
return true
end
function RD:GetPlayerGear(name)
local cache = name and self.localCache and self.localCache[name]
local stored=cache and cache.gearKey and self:GetGearSet(cache.gearKey) or nil
local preview=name and self.gearPreview and self.gearPreview[name]
local items=preview or stored
if not cache and not items then return nil end
local strict=stored~=nil and (not preview or sameGearSet(preview,stored))
return cache,items,cache and cache.gearKey and self:AuditGearSet(cache.gearKey) or nil,strict
end
function RD:QueueTalentEmuGearQuery(name, unit, priority, sender, class)
if not name or not talentEmuRuntime() then return false end
if pending and pending.name==name then return true end
local now=GetTime and GetTime() or 0
if (talentEmuRetryAt[name] or 0)>now then return false end
local queued = talentEmuQueued[name]
if queued then
if priority then
for index,request in ipairs(talentEmuQueue) do
if request == queued then table.remove(talentEmuQueue,index);break end
end
table.insert(talentEmuQueue,1,queued)
end
return true
end
if talentEmuPending[name] then return true end
local request = { name=name, unit=unit, sender=sender, class=class }
talentEmuQueued[name] = request
if priority then table.insert(talentEmuQueue, 1, request) else talentEmuQueue[#talentEmuQueue + 1] = request end
return true
end
function RD:RequestPlayerGear(name, opts)
opts = opts or {}
if not name then return nil end
self:RegisterTalentEmuCallbacks()
local cached,cachedItems=self:GetPlayerGear(name)
if cachedItems then return cached,cachedItems end
local unit = opts.unit or (NoWCL.Util and NoWCL.Util.UnitTokenByName and NoWCL.Util.UnitTokenByName(name))
local localName=UnitName and UnitName("player")
if localName and shortName(localName)==shortName(name) then unit="player" end
if unit == "player" or (UnitIsUnit and unit and UnitIsUnit(unit, "player")) then
local gear=self:ScanGear("player")
self:CacheGearPreview(name,gear and gear.items)
self:CacheGear(name,gear)
return self:GetPlayerGear(name)
end
local context = { sender=opts.sender, class=opts.class }
local imported = self:ImportTalentEmuGear(name, context, true)
if not imported then
local queued=self:QueueTalentEmuGearQuery(name, unit, opts.priority == true, opts.sender, opts.class)
if queued and opts.priority==true then self:ProcessTalentEmuGearQueries() end
if not queued and unit and self:CanInspectUnit(unit) and self:InspectRetryReady(name) then
iq[#iq+1]=unit
self:PumpInspect()
end
end
return self:GetPlayerGear(name)
end
function RD:ProcessTalentEmuGearQueries()
self:RegisterTalentEmuCallbacks()
local emu = talentEmuRuntime()
if not emu then
wipe(talentEmuQueue); wipe(talentEmuQueued); wipe(talentEmuPending)
return
end
local now = GetTime and GetTime() or 0
for name, request in pairs(talentEmuPending) do
if self:ImportTalentEmuGear(name, request, true) then
talentEmuPending[name] = nil
elseif now >= (request.deadline or now) then
talentEmuPending[name] = nil
local cache = self.localCache and self.localCache[name]
if not hasFullGear(cache) and request.unit and self:CanInspectUnit(request.unit)
and self:InspectRetryReady(name) then
iq[#iq + 1] = request.unit
end
end
end
if now - talentEmuLastQueryAt < TALENT_EMU_QUERY_INTERVAL_SEC then return end
local request = table.remove(talentEmuQueue, 1)
if not request then return end
talentEmuQueued[request.name] = nil
local ok = pcall(emu.MT.SendQueryRequest, request.sender or request.name, nil,
true, false, true, false, true)
talentEmuLastQueryAt = now
talentEmuRetryAt[request.name] = now + 60
if ok then
request.deadline = now + TALENT_EMU_QUERY_TIMEOUT_SEC
talentEmuPending[request.name] = request
self:ImportTalentEmuGear(request.name, request, true)
elseif request.unit and self:CanInspectUnit(request.unit) and self:InspectRetryReady(request.name) then
iq[#iq + 1] = request.unit
end
end
function RD:StartTalentEmuWhisperQuery(name, request)
local emu = talentEmuRuntime()
if not emu then return false, "本机未安装或未启用 TalentEmuX" end
local now = GetTime and GetTime() or 0
request.talentEmuStarted = true
request.talentEmuDeadline = now + TALENT_EMU_QUERY_TIMEOUT_SEC
local ok = pcall(emu.MT.SendQueryRequest, request.sender or name, nil, true, false, true, false, true)
if not ok then
request.talentEmuStarted = nil
return false, "TalentEmuX 查询接口调用失败"
end
self:ImportTalentEmuGear(name, request)
return true
end
function RD:BeginWhisperInspectFallback(name, request, reason)
if request.fallbackStarted then return false end
request.fallbackStarted = true
local unit = whisperUnitByName(request.sender or name)
request.unit = unit or request.unit
if NoWCL.Print then
local fallback = hasValidGear(self.localCache and self.localCache[name]) and "已回退到 NoWCL 本地装备缓存。"
or (unit and "已回退到暴雪装备检视。" or "暂无本地缓存；选中该玩家后将自动使用暴雪装备检视。")
NoWCL:Print(self:FormatWhisperPrefix(name, request, self.localCache and self.localCache[name])
.. reason .. "，" .. fallback .. "|r")
end
if hasValidGear(self.localCache and self.localCache[name]) then
self:FlushWhisperGearPrompt(name)
elseif unit and unit ~= "player" then
self:QueueWhisperInspect(name, unit)
end
return true
end
function RD:QueueWhisperInspect(name, unit)
local request = self._whisperGearRequests and self._whisperGearRequests[name]
if not (request and unit and unit ~= "player" and self:InspectRetryReady(name)) then return false end
local identity = UnitGUID and UnitGUID(unit) or unit
if request.queued == identity then return false end
request.queued = identity
request.unit = unit
request.class = whisperPlayerClass(name, unit, request.guid, self.localCache and self.localCache[name])
whisperIq[#whisperIq + 1] = { unit=unit, name=name }
self:PumpInspect()
return true
end
function RD:TryResolveWhisperRequests()
local now = GetTime and GetTime() or 0
for name, request in pairs(self._whisperGearRequests or {}) do
if request.expires and now > request.expires then
self._whisperGearRequests[name] = nil
elseif not request.fallbackStarted then
if not request.talentEmuStarted then
local started, reason = self:StartTalentEmuWhisperQuery(name, request)
if not started then self:BeginWhisperInspectFallback(name, request, reason) end
elseif not self:ImportTalentEmuGear(name, request)
and now >= (request.talentEmuDeadline or now) then
local reason = request.talentEmuResponded
and "TalentEmuX 返回的装备数据不完整"
or "未收到 TalentEmuX 装备回包，对方可能没有安装 TalentEmuX"
self:BeginWhisperInspectFallback(name, request, reason)
end
elseif hasValidGear(self.localCache and self.localCache[name]) then
self:FlushWhisperGearPrompt(name)
elseif not request.queued then
local unit = whisperUnitByName(request.sender or name)
if unit and unit ~= "player" then self:QueueWhisperInspect(name, unit) end
end
end
end
function RD:OnWhisperMessage(_, sender, ...)
if not whisperGearPromptEnabled() then return false end
local lineID, guid = select(9, ...), select(10, ...)
local unit = whisperUnitByName(sender)
if unit == "player" then return false end
local name = (unit and unitName(unit)) or shortName(sender)
if not name then return false end
local cache = self.localCache and self.localCache[name]
local context = {
sender=sender, lineID=lineID, guid=guid, unit=unit,
class=whisperPlayerClass(name, unit, guid, cache),
}
local now = GetTime and GetTime() or 0
self._whisperGearPromptAt = self._whisperGearPromptAt or {}
local last = self._whisperGearPromptAt[name]
if last and now - last < WHISPER_PROMPT_DEDUPE_SEC then return false end
self._whisperGearPromptAt[name] = now
self._whisperGearRequests = self._whisperGearRequests or {}
context.expires = now + WHISPER_PROMPT_WAIT_SEC
self._whisperGearRequests[name] = context
local started, reason = self:StartTalentEmuWhisperQuery(name, context)
if not self._whisperGearRequests[name] then return true end
if not started then
self:BeginWhisperInspectFallback(name, context, reason)
end
return true
end
function RD:CanInspectUnit(unit)
if inspectLocked() then return false end
if not (unit and UnitExists and UnitExists(unit)) then return false end
if UnitIsConnected and not UnitIsConnected(unit) then return false end
if UnitIsVisible and not UnitIsVisible(unit) then return false end
if UnitInRange then
local inRange = UnitInRange(unit)
if inRange == false then return false end
end
if not (CanInspect and CanInspect(unit)) then return false end
return true
end
function RD:InspectRetryReady(name)
local retryAt = self._inspectRetryAt and self._inspectRetryAt[name]
return not retryAt or GetTime() >= retryAt
end
function RD:DeferInspect(name)
if not name then return end
self._inspectRetryAt = self._inspectRetryAt or {}
self._inspectRetryAt[name] = GetTime() + INSPECT_RETRY_SEC
end
local function applySnapshot(name, c)
if not RD._scanFightId then return end
if NoWCL.Sync and NoWCL.Sync.ApplyReadinessSnapshot then
NoWCL.Sync:ApplyReadinessSnapshot(name, c, RD._scanFightId)
end
end
local function groupHasMissingReadiness()
if not IsInGroup() then return false end
for _, u in ipairs(groupUnits()) do
local name = unitName(u)
if name and (not UnitIsConnected or UnitIsConnected(u)) then
local c = RD.localCache[name]
local sr = NoWCL.Sync and NoWCL.Sync.recvStats and NoWCL.Sync.recvStats[name]
if not hasFullGear(c) or not validSpecId(c and c.specId) then return true end
end
end
return false
end
function RD:ScanGroup()
if not IsInGroup() then return end
if inspectLocked() then return end
wipe(iq)
for _, u in ipairs(groupUnits()) do
local name = unitName(u)
if name and (not UnitIsConnected or UnitIsConnected(u)) then
local c = self.localCache[name] or {}
local sr = NoWCL.Sync and NoWCL.Sync.recvStats and NoWCL.Sync.recvStats[name]
if u ~= "player" then
local class = UnitClass and select(2, UnitClass(u)) or nil
self:ImportTalentEmuGear(name, { class=class }, true)
c = self.localCache[name] or c
end
if (not hasValidGear(c) or not validSpecId(c.specId)) and hasValidGear(sr) then
self:CacheGear(name, sr)
c = self.localCache[name] or c
end
if u == "player" and (not hasFullGear(c) or not validSpecId(c.specId)) then
local g = self:ScanGear("player")
self:CacheGear(name, g)
c = self.localCache[name] or c
elseif u ~= "player" and (not hasFullGear(c) or not validSpecId(c.specId)) and self:InspectRetryReady(name) then
local class = UnitClass and select(2, UnitClass(u)) or nil
local queued = self:QueueTalentEmuGearQuery(name, u, false, nil, class)
if not queued and self:CanInspectUnit(u) then
iq[#iq+1] = u
end
end
self.localCache[name] = c
if hasValidGear(c) then applySnapshot(name, c) end
end
end
end
local function requestScan(self, fightId)
self._scanFightId = fightId
local now = GetTime()
self._scanUntil = now + SCAN_WINDOW_SEC
self._nextGroupScanAt = now + SCAN_RETRY_INTERVAL
self:ScanGroup()
self:PumpInspect()
if NoWCL.AuditUI and NoWCL.AuditUI.Refresh then NoWCL.AuditUI:Refresh() end
end
function RD:RequestRosterScan()
requestScan(self, nil)
end
function RD:RequestGroupScan(fightId)
requestScan(self, fightId)
end
function RD:PumpInspect()
if inspectLocked() then return end
if pending then
if (GetTime() - pending.t) > 3 then
self:DeferInspect(pending.name)
local request = pending.whisperName and self._whisperGearRequests
and self._whisperGearRequests[pending.whisperName]
if request then request.queued = nil end
pending = nil
else
return
end
end
local direct = table.remove(whisperIq, 1)
local u = direct and direct.unit or table.remove(iq, 1)
while u and not self:CanInspectUnit(u) do
local name = direct and direct.name or unitName(u)
self:DeferInspect(name)
local request = direct and self._whisperGearRequests and self._whisperGearRequests[direct.name]
if request then request.queued = nil end
direct = table.remove(whisperIq, 1)
u = direct and direct.unit or table.remove(iq, 1)
end
if not u then return end
local guid, name = UnitGUID and UnitGUID(u), unitName(u)
if not (guid and name and NotifyInspect) then
self:DeferInspect(name)
local request = direct and self._whisperGearRequests and self._whisperGearRequests[direct.name]
if request then request.queued = nil end
return
end
pending = { unit=u, guid=guid, name=name, whisperName=direct and direct.name,
t=GetTime(), samples=0, stable=0 }
NotifyInspect(u)
end
local function finishPendingInspect(self, accepted)
if not pending then return end
local state = pending
if accepted and state.sample and state.sample.gearScanned then
if self:CacheGear(state.name, state.sample) then
if self._inspectRetryAt then self._inspectRetryAt[state.name] = nil end
applySnapshot(state.name, self.localCache[state.name])
else
self:DeferInspect(state.name)
end
else
self:DeferInspect(state.name)
local request = state.whisperName and self._whisperGearRequests
and self._whisperGearRequests[state.whisperName]
if request then request.queued = nil end
end
if ClearInspectPlayer then ClearInspectPlayer() end
pending = nil
if NoWCL.AuditUI and NoWCL.AuditUI.Refresh then NoWCL.AuditUI:Refresh() end
end
function RD:SamplePendingInspect(guid)
if not pending or guid ~= pending.guid then return end
local state = pending
if inspectLocked() or not UnitExists(state.unit)
or (UnitIsConnected and not UnitIsConnected(state.unit))
or (UnitGUID and UnitGUID(state.unit) ~= state.guid) then
finishPendingInspect(self, false)
return
end
local fresh = self:ScanGear(state.unit)
local merged = mergeGearSamples(state.unit, state.sample, fresh)
local unchanged = state.sample and sameGearSet(state.sample.items, merged.items)
state.sample = merged
state.samples = state.samples + 1
state.stable = unchanged and (state.stable + 1) or 1
if merged.gearScanned and state.stable >= INSPECT_STABLE_SAMPLES then
finishPendingInspect(self, true)
return
end
if state.samples >= INSPECT_MAX_SAMPLES then
finishPendingInspect(self, false)
return
end
if C_Timer and C_Timer.After then
C_Timer.After(INSPECT_SAMPLE_DELAY, function() RD:SamplePendingInspect(guid) end)
else
self:SamplePendingInspect(guid)
end
end
function RD:OnInspectReady(guid)
self:SamplePendingInspect(guid)
end
function RD:Init()
if self._inited then return end
self._inited = true
self:RegisterTalentEmuCallbacks()
if not inspectLocked() then self:Scan() end
local f = CreateFrame("Frame")
f:RegisterEvent("INSPECT_READY")
f:RegisterEvent("CHAT_MSG_WHISPER")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("PLAYER_FOCUS_CHANGED")
f:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
f:SetScript("OnEvent", function(_, ev, ...)
if ev == "INSPECT_READY" then RD:OnInspectReady(...)
elseif ev == "CHAT_MSG_WHISPER" then RD:OnWhisperMessage(...)
else RD:TryResolveWhisperRequests() end
end)
if C_Timer and C_Timer.NewTicker and not pumpTicker then
pumpTicker = C_Timer.NewTicker(1, function()
RD:TryResolveWhisperRequests()
RD:ProcessTalentEmuGearQueries()
if inspectLocked() then
if RD._scanUntil then RD._scanUntil = GetTime() + SCAN_WINDOW_SEC end
return
end
RD:PumpInspect()
if not IsInGroup() then return end
local now = GetTime()
if RD._scanUntil and now <= RD._scanUntil and (not RD._nextGroupScanAt or now >= RD._nextGroupScanAt) then
RD._nextGroupScanAt = now + SCAN_RETRY_INTERVAL
if pending or #iq > 0 then return end
if groupHasMissingReadiness() then
RD:ScanGroup()
RD:PumpInspect()
if NoWCL.AuditUI and NoWCL.AuditUI.Refresh then NoWCL.AuditUI:Refresh() end
else
RD._scanUntil = nil
end
end
end)
end
if C_Timer and C_Timer.After then
C_Timer.After(2, function() RD:RequestRosterScan() end)
else
self:RequestRosterScan()
end
end
