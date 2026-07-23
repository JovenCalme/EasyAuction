local _qnkyutarnp, _ysknifzsgw = ...
local _jercjlskad = {}
_ysknifzsgw.Stats = _jercjlskad
local _mgrddkckpb = _ysknifzsgw.Util
local _zhsxohecfm = _ysknifzsgw.DetailStats
local _wophgkhwrn = _ysknifzsgw.TeamBuffs
_jercjlskad.segment = nil
_jercjlskad.roster  = {}
_jercjlskad.spellInfo = {}
_jercjlskad._postEncounterFence = false
local _lkadegdain = {}
local _gvggrzhdvg = {}
local _ncsmxlqtsu = {}
local petTooltip
local function _ibckgpezre(name)
if not name then return nil end
return name:match("^[^-]+") or name
end
local function _lenkaxqajf(ownerName, petUnit)
if not ownerName or not petUnit or not UnitGUID then return end
local guid = UnitGUID(petUnit)
if _mgrddkckpb.IsCreature and _mgrddkckpb.IsCreature(guid) then return end
if guid and guid ~= "" then
_lkadegdain[guid] = _ibckgpezre(ownerName)
_ncsmxlqtsu[guid] = nil
end
end
function _jercjlskad:RefreshUnitPet(unit)
if not unit or not UnitName then return end
local ownerName = UnitName(unit)
if not ownerName then return end
local ownerGUID = UnitGUID and UnitGUID(unit)
if ownerGUID and ownerGUID ~= "" then _gvggrzhdvg[ownerGUID] = _ibckgpezre(ownerName) end
local petUnit
if unit == "player" then
petUnit = "pet"
elseif type(unit) == "string" and unit:match("^raid%d+$") then
petUnit = unit:gsub("^raid", "raidpet")
elseif type(unit) == "string" and unit:match("^party%d+$") then
petUnit = unit:gsub("^party", "partypet")
end
if petUnit then _lenkaxqajf(ownerName, petUnit) end
end
local function _fvczyuvyic()
if not UnitName or not UnitGUID then return end
local function scan(ownerUnit, petUnit)
if UnitExists and not UnitExists(ownerUnit) then return end
local ownerName = UnitName(ownerUnit)
if not ownerName then return end
local ownerGUID = UnitGUID(ownerUnit)
if ownerGUID and ownerGUID ~= "" then _gvggrzhdvg[ownerGUID] = _ibckgpezre(ownerName) end
_lenkaxqajf(ownerName, petUnit)
end
if IsInRaid and IsInRaid() then
local n = GetNumGroupMembers and (GetNumGroupMembers() or 0) or 0
for i = 1, n do scan("raid" .. i, "raidpet" .. i) end
elseif IsInGroup and IsInGroup() then
scan("player", "pet")
local n = GetNumGroupMembers and (GetNumGroupMembers() or 0) or 0
for i = 1, n do scan("party" .. i, "partypet" .. i) end
else
scan("player", "pet")
end
end
local function _udgqcozmyh(petGUID, petName)
if not petGUID or not CreateFrame or not WorldFrame then return nil end
petTooltip = petTooltip or CreateFrame("GameTooltip", "NoWCLPetOwnerFinder", nil, "GameTooltipTemplate")
if not petTooltip or not petTooltip.SetOwner or not petTooltip.SetHyperlink then return nil end
petTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
petTooltip:SetHyperlink("unit:" .. petGUID)
local patterns = {}
local titles = {
_G.UNITNAME_TITLE_PET, _G.UNITNAME_TITLE_COMPANION, _G.UNITNAME_TITLE_GUARDIAN,
_G.UNITNAME_TITLE_MINION, _G.UNITNAME_TITLE_CHARM, _G.UNITNAME_TITLE_CREATION,
_G.UNITNAME_TITLE_SQUIRE,
}
for _, title in ipairs(titles) do
if type(title) == "string" then patterns[#patterns + 1] = title:gsub("%%s", "(.+)") end
end
patterns[#patterns + 1] = "(.+)的宠物"
patterns[#patterns + 1] = "(.+)的守护者"
patterns[#patterns + 1] = "(.+)的仆从"
patterns[#patterns + 1] = "(.+)'s Pet"
patterns[#patterns + 1] = "(.+)'s Guardian"
patterns[#patterns + 1] = "(.+)'s Minion"
for i = 1, 4 do
local fs = _G["NoWCLPetOwnerFinderTextLeft" .. i]
local text = fs and fs.GetText and fs:GetText()
if type(text) == "string" and text ~= "" and text ~= petName then
for _, pat in ipairs(patterns) do
local owner = text:match(pat)
owner = owner and owner:gsub("^%s+", ""):gsub("%s+$", ""):gsub("'s$", "")
owner = _ibckgpezre(owner)
if owner and _jercjlskad.roster and _jercjlskad.roster[owner] then return owner end
for rosterName in pairs(_jercjlskad.roster or {}) do
if owner and _ibckgpezre(rosterName) == owner then return _ibckgpezre(rosterName) end
if text:find(_ibckgpezre(rosterName), 1, true) then return _ibckgpezre(rosterName) end
end
end
end
end
return nil
end
local function _uornxrqpsm(petGUID, petName)
if not petGUID or _mgrddkckpb.IsPlayer(petGUID) then return nil end
local now = GetTime and GetTime() or 0
if _ncsmxlqtsu[petGUID] and now - _ncsmxlqtsu[petGUID] < 1.0 then return nil end
_ncsmxlqtsu[petGUID] = now
_fvczyuvyic()
if _lkadegdain[petGUID] then return _lkadegdain[petGUID] end
local owner = _udgqcozmyh(petGUID, petName)
if owner then
_lkadegdain[petGUID] = owner
return owner
end
return nil
end
local function _moexofbiuz(sn, sid, school)
local si = _jercjlskad.spellInfo
if sn and not si[sn] then
si[sn] = { icon = (sid and sid > 0) and GetSpellTexture(sid) or nil, school = school or 0 }
elseif sn and si[sn] then
if not si[sn].icon and sid and sid > 0 then si[sn].icon = GetSpellTexture(sid) end
if (not si[sn].school or si[sn].school == 0) and school then si[sn].school = school end
end
end
local _swmuecoscn = {
SPELL_CAST_SUCCESS=true, SWING_DAMAGE=true, SWING_MISSED=true,
RANGE_DAMAGE=true, RANGE_MISSED=true,
}
local _nsofmuaauq = {
SPELL_DAMAGE=true, SPELL_PERIODIC_DAMAGE=true, RANGE_DAMAGE=true,
DAMAGE_SHIELD=true, SWING_DAMAGE=true, SPELL_BUILDING_DAMAGE=true,
}
local _oieuqthusd = {
SPELL_MISSED=true, SPELL_PERIODIC_MISSED=true, RANGE_MISSED=true,
DAMAGE_SHIELD_MISSED=true, SWING_MISSED=true,
}
local _yorvfbmjth = { SPELL_HEAL=true, SPELL_PERIODIC_HEAL=true }
local _fwsrnozimg = "SPELL_ABSORBED"
local _ksvxdmiunz = 1.5
local _ofwfhrlszx = 5
local _qhtxwwbtlx = 49016
local _tpbpblbgyp = "邪恶狂热"
local _tasxsstwhu = 5384
local _dpxqhkeihi = 2
local _hpgrcfqyja = 44572
local _bibsarqdjs = {
[_hpgrcfqyja] = "deepFreeze",
[71757] = "deepFreeze",
}
local _jzpxuvtimo = 49028
local _jspaegjygo = "dancingRuneWeapon"
local _jkethqktpe = {
[62036]=true, [49941]=true, [49909]=true, [55095]=true,
[49921]=true, [55078]=true, [49924]=true,
}
local _ckuxwzxbkd = "管理者埃克索图斯"
local _vopsmkbnkp = 12018
local _dnmjlknvvm = {
[71]=true, [25780]=true, [48263]=true,
}
local _gtrjplnyuy = {
[10060]="powerInfusion",
[57934]="tricks",
[34477]="misdirection",
[29166]="innervate",
[740]="tranquility", [8918]="tranquility", [9862]="tranquility", [9863]="tranquility",
[26983]="tranquility", [48446]="tranquility", [48447]="tranquility",
[64901]="blueHymn", [64904]="blueHymn",
[64843]="redHymn",
[2825]="heroism", [32182]="heroism",
[1022]="handProtection", [5599]="handProtection", [10278]="handProtection",
[1044]="handFreedom",
[64205]="divineSacrifice",
[6940]="handSacrifice", [20729]="handSacrifice", [27147]="handSacrifice",
[48911]="handSacrifice", [48912]="handSacrifice",
[31821]="auraMastery",
}
local _gfjzcrytfm = {
["能量灌注"]="powerInfusion", ["Power Infusion"]="powerInfusion",
["嫁祸诀窍"]="tricks", ["Tricks of the Trade"]="tricks",
["误导"]="misdirection", ["Misdirection"]="misdirection",
["激活"]="innervate", ["Innervate"]="innervate",
["宁静"]="tranquility", ["Tranquility"]="tranquility",
["希望圣歌"]="blueHymn", ["Hymn of Hope"]="blueHymn",
["神圣赞美诗"]="redHymn", ["Divine Hymn"]="redHymn",
["英勇"]="heroism", ["Bloodlust"]="heroism", ["Heroism"]="heroism",
["保护之手"]="handProtection", ["Hand of Protection"]="handProtection",
["自由之手"]="handFreedom", ["Hand of Freedom"]="handFreedom",
["神圣牺牲"]="divineSacrifice", ["Divine Sacrifice"]="divineSacrifice",
["牺牲之手"]="handSacrifice", ["Hand of Sacrifice"]="handSacrifice",
["光环掌握"]="auraMastery", ["Aura Mastery"]="auraMastery",
}
local _fnmuymhisd = {
[_qhtxwwbtlx]="unholyFrenzy",
}
local _crupoqustr = {
[_tpbpblbgyp]="unholyFrenzy", ["Unholy Frenzy"]="unholyFrenzy",
}
local _zptejpwfwn = {
["精灵之火"]=true, ["精灵之火(野性)"]=true, ["精灵之火（野性）"]=true,
["Faerie Fire"]=true, ["Faerie Fire (Feral)"]=true,
}
local _wzfckrczzz = 3.0
local _upfgamlple = 400
local _drwqcwsxue = {}
local resetPendingSwings
local function _xxymhouyvi(now, e, n)
if e and e._nowclEventTime == nil then e._nowclEventTime = now end
_drwqcwsxue[#_drwqcwsxue + 1] = { t = now, e = e, n = n }
if #_drwqcwsxue > _upfgamlple then
local keep = {}
for i = #_drwqcwsxue - (_upfgamlple / 2) + 1, #_drwqcwsxue do keep[#keep + 1] = _drwqcwsxue[i] end
_drwqcwsxue = keep
end
end
local _yogftxiggz = {
SPELL_CAST_START=true, SPELL_CAST_SUCCESS=true,
SWING_DAMAGE=true, SWING_MISSED=true,
RANGE_DAMAGE=true, RANGE_MISSED=true,
SPELL_DAMAGE=true, SPELL_PERIODIC_DAMAGE=true,
DAMAGE_SHIELD=true, SPELL_BUILDING_DAMAGE=true,
}
local _lkfiircvjk = {
SPELL_CAST_START=true, SPELL_CAST_SUCCESS=true,
SWING_DAMAGE=true, SWING_MISSED=true,
RANGE_DAMAGE=true, RANGE_MISSED=true,
SPELL_DAMAGE=true, SPELL_PERIODIC_DAMAGE=true,
SPELL_MISSED=true, SPELL_PERIODIC_MISSED=true,
DAMAGE_SHIELD=true, DAMAGE_SHIELD_MISSED=true,
SPELL_BUILDING_DAMAGE=true,
}
local function _vnxikbaafy(guid)
if not guid then return nil end
if _gvggrzhdvg[guid] then return _gvggrzhdvg[guid] end
if _lkadegdain[guid] then return _lkadegdain[guid] end
return nil
end
local function _qpvddktdsi(flags)
if not flags or not bit or not bit.band then return false end
return bit.band(flags, COMBATLOG_OBJECT_TYPE_PET or 0x1000) > 0
or bit.band(flags, COMBATLOG_OBJECT_TYPE_GUARDIAN or 0x2000) > 0
end
local function _bqywrqgrgm(e, n, srcGUID)
if not e or not srcGUID then return nil end
for i = 12, (n or #e) - 1 do
if e[i] == srcGUID then
local owner = _vnxikbaafy(e[i + 1])
if owner then return owner end
end
end
return nil
end
local function _zxazfknbhl(srcGUID, srcName, e, n)
if _mgrddkckpb.IsPlayer(srcGUID) then return srcName end
local sourceFlags = e and e[6]
local ownerEligible = _qpvddktdsi(sourceFlags)
and not (_mgrddkckpb.IsHostileNPC and _mgrddkckpb.IsHostileNPC(sourceFlags))
local adv = ownerEligible and _bqywrqgrgm(e, n, srcGUID) or nil
if adv then
if srcGUID and srcGUID ~= "" then _lkadegdain[srcGUID] = adv end
return adv
end
if srcGUID and _lkadegdain[srcGUID] then return _lkadegdain[srcGUID] end
if e and ownerEligible then
local lookedUp = _uornxrqpsm(srcGUID, srcName)
if lookedUp then return lookedUp end
end
return nil
end
local function _hgfawetoph(guid, fromId, toId)
if type(guid) ~= "string" then return nil end
local needle = "-" .. tostring(fromId) .. "-"
if not guid:find(needle, 1, true) then return nil end
return (guid:gsub("%-" .. tostring(fromId) .. "%-", "-" .. tostring(toId) .. "-", 1))
end
local function _vusprrkpjf(self, name)
if not name then return false end
if self.roster[name] then return true end
local short = _ibckgpezre(name)
for n in pairs(self.roster or {}) do
if _ibckgpezre(n) == short then return true end
end
return false
end
local function _uffqbiakbt(self, seg)
if not (seg and seg.puller and (seg.isBoss or seg.isDummy)) then return false end
local info = self.roster and self.roster[_ibckgpezre(seg.puller)]
local announced = false
if seg.isBoss and _ysknifzsgw.TeamAnnouncements and _ysknifzsgw.TeamAnnouncements.OnPullDetected then
announced = _ysknifzsgw.TeamAnnouncements:OnPullDetected(seg, seg.puller) and true or false
end
if _ysknifzsgw.PullNotice and _ysknifzsgw.PullNotice.OnPullDetected then
return _ysknifzsgw.PullNotice:OnPullDetected(seg, seg.puller, info and info.class) or announced
end
return announced
end
local function _mhtfhpbdgc(sub, e, ownerName)
if not (sub and e) then return nil, nil end
local spellId, method
if sub == "SWING_DAMAGE" or sub == "SWING_MISSED" then
spellId, method = 6603, "近战"
else
spellId = _mgrddkckpb.N(e[12])
method = e[13]
if not method or method == "" then
if sub == "RANGE_DAMAGE" or sub == "RANGE_MISSED" then method = "远程攻击"
else method = "施法" end
end
end
local sourceName = _ibckgpezre(e[5])
if ownerName and not _mgrddkckpb.IsPlayer(e[4]) and sourceName and sourceName ~= ownerName then
method = "宠物：" .. tostring(method)
end
return method, spellId > 0 and spellId or nil
end
local function _wpoyinzszj(self, seg, name, sub, e)
name = _ibckgpezre(name)
if not (seg and not seg.puller and name) then return false end
local method, spellId = _mhtfhpbdgc(sub, e, name)
seg.puller = name
seg.pullMethod = method
seg.pullSpellId = tonumber(spellId) or nil
_uffqbiakbt(self, seg)
return true
end
local function _jnioofstry(self, sub, srcGUID, srcName, dstName)
if not _yogftxiggz[sub] or not _mgrddkckpb.IsTrainingDummy(dstName) then return false end
if self._postEncounterFence then return false end
self:UpdateRoster()
local ownerName = _zxazfknbhl(srcGUID, srcName)
if not _vusprrkpjf(self, ownerName) then return false end
self:OnCombatStart(false, "战斗", "passive")
if self.segment then
self.segment._observed = true
self.segment._damageConfirmed = true
self.segment.isDummy = true
self.segment.firstTarget = dstName
_uffqbiakbt(self, self.segment)
end
return true
end
local function _rmrgasqqte(dstGUID, dstName)
local W = _ysknifzsgw.WCLBosses
if not (W and W.NpcId and W.ObservedBossName) then return nil end
return W.ObservedBossName(W.NpcId(dstGUID), dstName)
end
local function _cwtwmvlklt(self, seg, bossName, dstName)
if not (seg and bossName) then return false end
if seg.isBoss then return true end
seg.isBoss = true
seg._damageConfirmed = true
seg._observedBoss = true
seg.name = bossName
seg.firstTarget = dstName or bossName
_uffqbiakbt(self, seg)
return true
end
local function _naajkotkuv(seg)
if not (seg and seg.players) then return false end
for _, r in pairs(seg.players) do
if (r.dmg or 0) > 0 or (r.heal or 0) > 0 or (r.absorbed or 0) > 0
or (r.interrupts or 0) > 0 or (r.dispels or 0) > 0 or (r.deaths or 0) > 0
or (r.actions or 0) > 0 then
return true
end
end
return false
end
local function _chpmhmahkz(bossName, dstGUID, dstName)
local W = _ysknifzsgw.WCLBosses
if W and W.Get and W.Get(bossName) then return W:CountsAsBoss(bossName, dstGUID) end
return dstName and bossName and dstName == bossName and not _mgrddkckpb.IsPlayer(dstGUID)
end
local function _kbvhexyhvz(self, bossName)
for i = 1, #_drwqcwsxue do
local item = _drwqcwsxue[i]
local e = item.e
if e and _lkfiircvjk[e[2]] and _chpmhmahkz(bossName, e[8], _ibckgpezre(e[9])) then
local owner = _zxazfknbhl(e[4], _ibckgpezre(e[5]), e, item.n)
if owner and _vusprrkpjf(self, owner) then
return owner, e[2], e
end
end
end
return nil
end
local function _wijagowggp(self, sub, srcGUID, srcName, dstGUID, dstName)
if not _yogftxiggz[sub] then return false end
if self._postEncounterFence then return false end
local bossName = _rmrgasqqte(dstGUID, dstName)
if not bossName then return false end
self:UpdateRoster()
local ownerName = _zxazfknbhl(srcGUID, srcName)
if not _vusprrkpjf(self, ownerName) then return false end
self:OnCombatStart(false, "战斗")
return _cwtwmvlklt(self, self.segment, bossName, dstName)
end
local function _xcmbeibxbv(self, sub, srcGUID, srcName, dstGUID, dstName, e, n)
if not (_nsofmuaauq[sub] or _oieuqthusd[sub]) then return false end
if self._postEncounterFence then return false end
self:UpdateRoster()
local ownerName = _zxazfknbhl(srcGUID, srcName, e, n)
if not _vusprrkpjf(self, ownerName) then return false end
self:OnCombatStart(false, "战斗", "passive")
if self.segment then
self.segment._observed = true
self.segment._damageConfirmed = true
self.segment._confirmationKind = "outgoing"
self.segment._passiveObserved = true
end
return self.segment ~= nil
end
local function _qojtualhih(r, a, b, s0)
if b <= a then return end
if a >= r._lastEnd then
r.activeMs = r.activeMs + (b - a)*1000
r._lastEnd = b
r.iv[#r.iv+1] = math.max(0, a - s0)
r.iv[#r.iv+1] = b - s0
elseif b > r._lastEnd then
r.activeMs = r.activeMs + (b - r._lastEnd)*1000
r._lastEnd = b
if r.iv[#r.iv] then r.iv[#r.iv] = b - s0 end
end
end
local function _xbkrgmqoiw(src)
if type(src) ~= "table" then return {} end
local out = {}
for k, v in pairs(src) do
if type(v) == "table" then
local child = {}
for ck, cv in pairs(v) do child[ck] = cv end
out[k] = child
else
out[k] = v
end
end
return out
end
local function _jhybfxpcmm(self, inherit)
if not inherit then
return { activeBuff = {}, unholyFrenzy = {}, unholyFrenzyByGuid = {} }
end
return {
activeBuff = _xbkrgmqoiw(self.activeBuff),
unholyFrenzy = _xbkrgmqoiw(self.unholyFrenzy),
unholyFrenzyByGuid = _xbkrgmqoiw(self.unholyFrenzyByGuid),
}
end
local function _ozsxfmqfgq(seg)
if not (_zhsxohecfm and seg) or seg._bossAuraRefreshed or seg._statsWindowPending then return end
seg._bossAuraRefreshed = true
if _zhsxohecfm.RefreshGroupPlayerBuffs then _zhsxohecfm.RefreshGroupPlayerBuffs() end
_zhsxohecfm.CaptureSegmentAuras(seg)
if _zhsxohecfm.ReconcileSegmentAuraSeeds then _zhsxohecfm.ReconcileSegmentAuraSeeds(seg) end
end
local function _mmyygxzwoq(self)
self.activeBuff = {}
self.snapshotBuff = {}
self.unholyFrenzy = {}
self.unholyFrenzyByGuid = {}
self.channelStart = {}
end
local function _mywftrcpin(bossName)
local W = _ysknifzsgw.WCLBosses
local profile = W and W.Get and W.Get(bossName)
return profile and type(profile.statsWindow) == "table" and profile.statsWindow or nil
end
local function _koxrpvjdmx(seg, window)
if not (seg and window) then return false end
if window.start == "FIRST_INCLUDED_BOSS_DAMAGE" then
seg._statsWindowPending = true
seg._statsWindowStart = window.start
seg._statsWindowInheritAuras = window.inheritAuras ~= false
end
if window.finish == "INCLUDED_BOSS_DIED" then seg._finishOnBossDeath = true end
return seg._statsWindowPending and true or false
end
function _jercjlskad:UpdateRoster()
local previous = self.roster or {}
local members, expected = {}, 0
if _mgrddkckpb.GroupRosterMembers then members, expected = _mgrddkckpb.GroupRosterMembers() end
local nextRoster, seen = {}, {}
for _, member in ipairs(members or {}) do
local name = member.name
if name then
local old = previous[name] or {}
nextRoster[name] = {
class=member.class or old.class,
role=member.role or old.role or "DPS",
guid=member.guid or old.guid,
specId=old.specId,
unit=member.unit or old.unit,
groupLabel=member.groupLabel or old.groupLabel,
whisperName=member.whisperName or old.whisperName,
}
seen[name] = true
end
end
local incomplete = (#members < (tonumber(expected) or 0))
or ((tonumber(expected) or 0) == 0 and next(previous) ~= nil)
if incomplete then
for name, old in pairs(previous) do
if not seen[name] then
nextRoster[name] = old
seen[name] = true
end
end
end
wipe(self.roster)
wipe(_gvggrzhdvg)
for name, info in pairs(nextRoster) do
self.roster[name] = info
if info.guid then _gvggrzhdvg[info.guid] = _ibckgpezre(name) end
local unit = info.unit
local petUnit = unit == "player" and "pet"
or (type(unit) == "string" and unit:gsub("^(raid)(%d+)$", "raidpet%2"):gsub("^(party)(%d+)$", "partypet%2"))
if petUnit and petUnit ~= unit then _lenkaxqajf(name, petUnit) end
end
end
function _jercjlskad:OnCombatStart(isBoss, name, origin)
if isBoss then self._postEncounterFence = false end
if isBoss and self.segment and not self.segment._ended and self.segment._restoredDraft then
local sameBoss = self.segment.name == name or self.segment.name == "战斗" or not self.segment.name
if sameBoss then
self:UpdateRoster()
self.segment.isBoss = true
self.segment._damageConfirmed = true
self.segment.name = name or self.segment.name
_ozsxfmqfgq(self.segment)
_uffqbiakbt(self, self.segment)
return
end
end
local now = GetTime()
local active = self.segment
local statsWindow = isBoss and _mywftrcpin(name) or nil
local delayedStart = statsWindow and statsWindow.start == "FIRST_INCLUDED_BOSS_DAMAGE"
if isBoss and active and not active._ended and not active.isBoss
and not delayedStart
and _naajkotkuv(active)
and now - (active.startTime or now) >= 0
and now - (active.startTime or now) <= _wzfckrczzz then
self:UpdateRoster()
active.isBoss = true
active._damageConfirmed = true
active.name = name or active.name
active._promotedFromCombat = true
_koxrpvjdmx(active, statsWindow)
_ozsxfmqfgq(active)
if active.puller then
_uffqbiakbt(self, active)
else
_wpoyinzszj(self, active, _kbvhexyhvz(self, active.name))
end
_drwqcwsxue = {}
local cfg = _ysknifzsgw.db and _ysknifzsgw.db.settings and _ysknifzsgw.db.settings.bossCfg
for _, rec in pairs(active.players or {}) do
if self:RecomputePlayerTargetScope(rec, active.name, now - active.startTime, cfg) then
rec.dmgBoss = rec.rawDmgBoss or rec.dmgBoss
rec.rawDmgBoss = nil
rec.bossDps = nil
end
end
return
end
local carry = _jhybfxpcmm(self, true)
self:UpdateRoster()
self.segment = {
name = name or "战斗", isBoss = isBoss and true or false,
startTime = now, endTime = nil, players = {}, _damageConfirmed = isBoss and true or false,
_playerCombat = isBoss or origin ~= "passive",
_passiveObserved = origin == "passive" and true or nil,
}
_koxrpvjdmx(self.segment, statsWindow)
if _zhsxohecfm and not self.segment._statsWindowPending then
if isBoss then _ozsxfmqfgq(self.segment) else _zhsxohecfm.CaptureSegmentAuras(self.segment) end
end
self.activeBuff = carry.activeBuff
self.snapshotBuff = {}
self.unholyFrenzy = carry.unholyFrenzy
self.unholyFrenzyByGuid = carry.unholyFrenzyByGuid
self.channelStart = {}
if isBoss and self.segment._statsWindowPending then
_drwqcwsxue = {}
elseif isBoss then
self:BackfillPrepull()
end
end
function _jercjlskad:CancelPendingCombatEnd()
local seg = self.segment
if not (seg and not seg._ended and seg._endingAt) then return false end
local endAt = seg._endingAt
if self.ClearCurrentDisplayFreeze then
self:ClearCurrentDisplayFreeze(endAt)
else
seg._endingAt = nil
seg._displayPlayers = nil
seg._displayDur = nil
seg._displayEndAt = nil
end
seg._endingReason = nil
seg._groupRegenSafeAt = nil
seg._groupRegenBoundaryToken = nil
seg._bossRegenWatchToken = nil
return true
end
function _jercjlskad:IsPostEncounterFenced()
return self._postEncounterFence and true or false
end
function _jercjlskad:ReleasePostEncounterFence()
if not self._postEncounterFence then return false end
self._postEncounterFence = false
return true
end
function _jercjlskad:OnPlayerCombatStart()
if self._postEncounterFence then return false end
local seg = self.segment
self:CancelPendingCombatEnd()
if not seg or seg._ended then
self:OnCombatStart(false, "战斗", "player")
elseif not seg.isBoss then
seg._playerCombat = true
seg._passiveObserved = nil
end
return true
end
function _jercjlskad:BackfillPrepull()
local buf = _drwqcwsxue
_drwqcwsxue = {}
local seg = self.segment
if not (seg and seg.isBoss) then return end
local W = _ysknifzsgw.WCLBosses
if not (W and W.Get and W.Get(seg.name)) then return end
local originalStart = seg.startTime or GetTime()
local cutoff = originalStart - _wzfckrczzz
local matched = {}
for i = 1, #buf do
local it = buf[i]
if it.t >= cutoff and W:CountsAsBoss(seg.name, it.e[8]) then
if not seg.puller and _lkfiircvjk[it.e[2]] then
local owner = _zxazfknbhl(it.e[4], _ibckgpezre(it.e[5]), it.e, it.n)
if owner and _vusprrkpjf(self, owner) then
_wpoyinzszj(self, seg, owner, it.e[2], it.e)
end
end
if _nsofmuaauq[it.e[2]] or _oieuqthusd[it.e[2]] then matched[#matched + 1] = it end
end
end
if #matched > 0 and matched[1].t < originalStart then seg.startTime = matched[1].t end
for i = 1, #matched do self:HandleCLEU(matched[i].e, matched[i].n) end
end
local getRec
function _jercjlskad:OnChannelStart(name, guid)
if not self.segment or not name then return end
self.channelStart = self.channelStart or {}
self.channelStart[name] = { t = GetTime(), guid = guid }
end
function _jercjlskad:OnChannelStop(name)
local seg = self.segment
if not seg or not name then return end
local c = self.channelStart and self.channelStart[name]
if not c then return end
self.channelStart[name] = nil
local s0 = seg.startTime or c.t
local a = math.max(c.t, s0)
local r = getRec(seg, name, c.guid)
_qojtualhih(r, a, GetTime(), s0)
end
local function _wmlvtqyirl(playerName, dstGUID, spellId)
return tostring(playerName or "") .. "\001" .. tostring(dstGUID or "") .. "\001" .. tostring(spellId or 0)
end
local function _ndkhaitril(rule, dstGUID)
local npcId = _ysknifzsgw.WCLBosses and _ysknifzsgw.WCLBosses.NpcId and _ysknifzsgw.WCLBosses.NpcId(dstGUID)
if rule.targetIds and not rule.targetIds[npcId] then return false end
return true
end
local function _bixlwdoyxd(playerName, dstGUID)
local ab = _ysknifzsgw.Stats.activeBuff[playerName]
if not ab then return nil end
local prof = _ysknifzsgw.Profiles:GetActive()
local rules = prof.excludedBuffs
if not rules then return nil end
local out = nil
for spellId, stacks in pairs(ab) do
local rule = rules[spellId]
if rule and _ndkhaitril(rule, dstGUID) then
out = out or {}
out[spellId] = stacks
end
end
return out
end
local function _jjhybkleng(ruleStacks, eff)
if not ruleStacks then return 0 end
local prof = _ysknifzsgw.Profiles:GetActive()
local rules = prof.excludedBuffs
if not rules then return 0 end
local excluded = 0
for spellId, stacks in pairs(ruleStacks) do
local rule = rules[spellId]
if rule and rule.mode == "multiplier" then
local add = rule.addedPct or 0
excluded = excluded + eff * (add / (1 + add))
elseif rule and rule.mode == "perStack" then
local add = (rule.perStack or 0) * (stacks or 1)
excluded = excluded + eff * (add / (1 + add))
end
end
return excluded
end
local function _nbarkpgtcb(playerName, eff, dstGUID, spellId, isPeriodic)
local ruleStacks
if isPeriodic then
local key = _wmlvtqyirl(playerName, dstGUID, spellId)
ruleStacks = _ysknifzsgw.Stats.snapshotBuff and _ysknifzsgw.Stats.snapshotBuff[key]
else
ruleStacks = _bixlwdoyxd(playerName, dstGUID)
end
return _jjhybkleng(ruleStacks, eff)
end
local saveCurrentSnapshot
local computeArray
function _jercjlskad:OnCombatEnd(endTime)
local seg = self.segment
local endedBoss = seg and seg.isBoss and not seg._ended
local resolvedEnd = endTime or GetTime()
if seg and seg._finishOnBossDeath and seg._bossDiedAt then resolvedEnd = seg._bossDiedAt end
if seg and not seg._ended then self:FlushPendingSwings(resolvedEnd, true) end
if self.segment and not self.segment.endTime then
local keepCurrent = self.segment.isBoss or self.segment.isDummy
or self.segment._damageConfirmed == true
self.segment.endTime = resolvedEnd
self.segment._ended = true
local dur = math.max(0, self.segment.endTime - (self.segment.startTime or self.segment.endTime))
if _zhsxohecfm then
for _, rec in pairs(self.segment.players or {}) do _zhsxohecfm.CloseRecord(rec, dur) end
_zhsxohecfm.CloseBossSpells(self.segment)
_zhsxohecfm.ClearTransientAuras()
end
if keepCurrent then saveCurrentSnapshot(self) end
self:FinalizeSegment()
_mmyygxzwoq(self)
resetPendingSwings()
if endedBoss then self._postEncounterFence = true end
end
end
getRec = function(seg, name, guid)
local r = seg.players[name]
if not r then
local info = _ysknifzsgw.Stats.roster[name]
local ready = _ysknifzsgw.Readiness and _ysknifzsgw.Readiness.localCache and _ysknifzsgw.Readiness.localCache[name]
r = {
name=name, guid=guid, class=info and info.class, role=info and info.role or "DPS",
specId=ready and ready.specId,
dmg=0, dmgBoss=0, absorbed=0, heal=0, wclExcluded=0, wclBossExcluded=0,
interrupts=0, dispels=0, deaths=0, sunderApplied=0,
extraTasks={},
activeMs=0, _lastEnd=0,
actions=0, iv={},
deadSec=0, deathTimes={}, deathDetails={}, _deadAt=nil,
spells={}, heals={},
_nqrnkeadpv=_ofwfhrlszx,
damageBuckets={}, bossDamageBuckets={}, healingBuckets={},
targets={}, targetsBoss={}, healTargets={},
targetScope={},
scopeTimeline={},
}
if _zhsxohecfm then _zhsxohecfm.InitRecord(r); _zhsxohecfm.SeedRecord(r, name, guid, seg) end
seg.players[name] = r
end
return r
end
local function _bcnobksaov(e, n)
local rawLogTail = e._nowclRawDamageTail == 9
local amount = _mgrddkckpb.N(e[n-9])
local overkill = math.max(0, rawLogTail and _mgrddkckpb.N(e[n-7]) or _mgrddkckpb.N(e[n-8]))
local absorbed = rawLogTail and _mgrddkckpb.N(e[n-3]) or _mgrddkckpb.N(e[n-4])
return math.max(0, amount - overkill), absorbed
end
function _jercjlskad:RecordIncomingDamage(seg, dstName, dstGUID, sub, e, n, now)
if not (seg and dstName and _nsofmuaauq[sub]) then return end
local amount = _bcnobksaov(e, n)
if amount <= 0 then return end
seg._recentDamageByPlayer = seg._recentDamageByPlayer or {}
local state = seg._recentDamageByPlayer[dstName]
if not state then
state = { recent={ {}, {}, {} }, count=0, next=1 }
seg._recentDamageByPlayer[dstName] = state
end
local index = state.next or 1
local hit = state.recent[index]
local swing = sub == "SWING_DAMAGE"
hit[1] = math.max(0, math.floor(((now or GetTime()) - (seg.startTime or now or GetTime())) * 1000 + 0.5))
hit[2] = swing and 6603 or _mgrddkckpb.N(e[12])
hit[3] = amount
hit[4] = swing and "近战" or (e[13] or "未知攻击")
hit[5] = _ibckgpezre(e[5]) or "未知来源"
state.count = math.min(3, (state.count or 0) + 1)
state.next = index % 3 + 1
end
function _jercjlskad:SnapshotDeathDamage(rec, deathTime, state)
if not rec then return end
rec.deathDetails = rec.deathDetails or {}
local hits = {}
local count = math.min(3, state and state.count or 0)
local recent = state and state.recent
if recent and count > 0 then
local first = count < 3 and 1 or (state.next or 1)
local deathMs = math.max(0, math.floor((deathTime or 0) * 1000 + 0.5))
for offset = 0, count - 1 do
local hit = recent[(first + offset - 1) % 3 + 1]
if hit and hit[1] and deathMs - hit[1] <= 15000 then
hits[#hits + 1] = { hit[1], hit[2], hit[3], hit[4], hit[5] }
end
end
rec.deathDetails[#rec.deathDetails + 1] = { deathMs, hits }
else
rec.deathDetails[#rec.deathDetails + 1] = { math.max(0, math.floor((deathTime or 0) * 1000 + 0.5)), hits }
end
end
local function _obdwdyzaiq(e)
if not e then return nil end
local casterAt = tonumber(e[12]) and 15 or 12
local casterGUID = e[casterAt]
local spellId = _mgrddkckpb.N(e[casterAt + 4])
local amount = math.max(0, _mgrddkckpb.N(e[casterAt + 7]))
if not casterGUID or spellId <= 0 or amount <= 0 then return nil end
return casterGUID, _ibckgpezre(e[casterAt + 1]), spellId,
e[casterAt + 5] or "?", _mgrddkckpb.N(e[casterAt + 6]), amount
end
local function _xreeivsdvs(e, n)
if not _zhsxohecfm then return false end
local value = e._nowclRawDamageTail == 9 and e[n-2] or e[n-3]
return _zhsxohecfm.Flag(value)
end
local function _sqrgzoobyx(e, n, spellId)
local critical = _xreeivsdvs(e, n)
if not (critical and _zhsxohecfm and _zhsxohecfm.NormalizeDamageCritical) then return critical end
local rawLogTail = e._nowclRawDamageTail == 9
local resisted = rawLogTail and e[n-5] or e[n-6]
local blocked = rawLogTail and e[n-4] or e[n-5]
return _zhsxohecfm.NormalizeDamageCritical(spellId, critical, resisted, blocked)
end
local _wgytianfmx = 2.0
local _umvfgalcic = 4.0
local _hkicalbreh, _vzpjmidvou, _yrhwdchblk = {}, {}, 1
local _mimdqtdois, _aipyynbfhx, _vlyapwxscy = {}, {}, 1
local _jzkgpvishc = {}
_jercjlskad._swingLandedObserved = false
local function _rmmipkucxs(e, n)
if not (e and n and e[4] and e[8] and n >= 21) then return nil end
local parts = { tostring(e[4]), tostring(e[8]), tostring(e[n - 9]) }
if e._nowclRawDamageTail == 9 then
parts[#parts + 1] = tostring(e[n - 8])
parts[#parts + 1] = tostring(e[n - 6])
parts[#parts + 1] = _xreeivsdvs(e, n) and "1" or "0"
parts[#parts + 1] = tostring(e[n - 1])
parts[#parts + 1] = tostring(e[n])
else
parts[#parts + 1] = tostring(e[n - 7])
parts[#parts + 1] = _xreeivsdvs(e, n) and "1" or "0"
parts[#parts + 1] = tostring(e[n - 2])
parts[#parts + 1] = tostring(e[n - 1])
parts[#parts + 1] = tostring(e[n])
end
return table.concat(parts, "\001")
end
local function _czirowkvrq(e)
local guid = e and e[4]
if type(guid) == "string" and guid:sub(1, 9) == "Creature-" then
return _umvfgalcic
end
return _wgytianfmx
end
resetPendingSwings = function()
_hkicalbreh, _vzpjmidvou, _yrhwdchblk = {}, {}, 1
_mimdqtdois, _aipyynbfhx, _vlyapwxscy = {}, {}, 1
_jzkgpvishc = {}
end
local function _licmvxtsnk(damage, damageN, landed, landedN)
local landedRawTail = landed._nowclRawDamageTail == 9
local overkill = _mgrddkckpb.N(landed[landedRawTail and (landedN - 7) or (landedN - 8)])
local damageRawTail = damage._nowclRawDamageTail == 9
damage[damageRawTail and (damageN - 7) or (damageN - 8)] = overkill
end
local function _ppcuzcpkif(e, n, now)
local key = _rmmipkucxs(e, n)
if not key then return false end
local item = { key=key, e=e, n=n, t=now, used=false }
local queue = _mimdqtdois[key]
if not queue then queue = {}; _mimdqtdois[key] = queue end
queue[#queue + 1] = item
_aipyynbfhx[#_aipyynbfhx + 1] = item
return true
end
local function _ykowzzyfsw(e, n, now)
local key = _rmmipkucxs(e, n)
local queue = key and _mimdqtdois[key]
while queue and #queue > 0 do
local item = table.remove(queue, 1)
if not item.used and now - item.t <= _czirowkvrq(item.e) then
item.used = true
_licmvxtsnk(e, n, item.e, item.n)
_jzkgpvishc[e[4]] = true
return item
end
end
return nil
end
local function _xrbibdcwgz(e, n, now)
if _ykowzzyfsw(e, n, now) then return true end
local key = _rmmipkucxs(e, n)
if not key then return false end
local item = { key=key, e=e, n=n, t=now, used=false }
local queue = _hkicalbreh[key]
if not queue then queue = {}; _hkicalbreh[key] = queue end
queue[#queue + 1] = item
_vzpjmidvou[#_vzpjmidvou + 1] = item
return false
end
local function _wvsuvaiscz(e, n, now)
local key = _rmmipkucxs(e, n)
local queue = key and _hkicalbreh[key]
while queue and #queue > 0 do
local item = table.remove(queue, 1)
if not item.used and now - item.t <= _czirowkvrq(item.e) then
item.used = true
_licmvxtsnk(item.e, item.n, e, n)
_jzkgpvishc[item.e[4]] = true
return item
end
end
_ppcuzcpkif(e, n, now)
return nil
end
local function _qlkimslysb(item, landedObserved)
if not landedObserved then return true end
local guid = item and item.e and item.e[4]
return type(guid) == "string" and guid:sub(1, 9) == "Creature-"
and not _jzkgpvishc[guid]
end
local function _inrsevzhag(now, force)
while _vlyapwxscy <= #_aipyynbfhx do
local item = _aipyynbfhx[_vlyapwxscy]
if item.used then
_vlyapwxscy = _vlyapwxscy + 1
elseif force or now - item.t >= _czirowkvrq(item.e) then
item.used = true
_vlyapwxscy = _vlyapwxscy + 1
else
break
end
end
if _vlyapwxscy > 2048 then
local compacted = {}
for i = _vlyapwxscy, #_aipyynbfhx do compacted[#compacted + 1] = _aipyynbfhx[i] end
_aipyynbfhx = compacted
_vlyapwxscy = 1
end
end
function _jercjlskad:SetSwingLandedAvailable(available)
self._swingLandedObserved = available and true or false
end
function _jercjlskad:FlushPendingSwings(now, force)
now = now or GetTime()
_inrsevzhag(now, force)
local ready = {}
while _yrhwdchblk <= #_vzpjmidvou do
local item = _vzpjmidvou[_yrhwdchblk]
if item.used then
_yrhwdchblk = _yrhwdchblk + 1
elseif force or now - item.t >= _czirowkvrq(item.e) then
item.used = true
_yrhwdchblk = _yrhwdchblk + 1
if _qlkimslysb(item, self._swingLandedObserved) then ready[#ready + 1] = item end
else
break
end
end
if _yrhwdchblk > 2048 then
local compacted = {}
for i = _yrhwdchblk, #_vzpjmidvou do compacted[#compacted + 1] = _vzpjmidvou[i] end
_vzpjmidvou = compacted
_yrhwdchblk = 1
end
for _, item in ipairs(ready) do
item.e._nowclSwingNormalized = true
item.e._nowclEventTime = item.t
self:HandleCLEU(item.e, item.n)
end
if force then resetPendingSwings() end
return #ready
end
local function _vvtmagwimo(e, n)
for i = 15, n do
if e[i] == "BUFF" or e[i] == "DEBUFF" then return e[i] end
end
return nil
end
local function _udkdqjtpxn(seg, dstGUID, dstName, dstFlags, npcId)
if _mgrddkckpb.IsTrainingDummy(dstName) then
seg.isDummy = true
return true
end
if not seg.isBoss then return false end
local W = _ysknifzsgw.WCLBosses
if W and W.Get and W.Get(seg.name) then
if npcId and W.CountsNpcAsBoss then return W:CountsNpcAsBoss(seg.name, npcId) end
return W:CountsAsBoss(seg.name, dstGUID)
end
return dstName and seg.name and dstName == seg.name and not _mgrddkckpb.IsPlayer(dstGUID)
end
local _dwtickbygx = 0.0011
local _ttrwxdtpsj = 64
function _jercjlskad:RememberStatsWindowBoundary(seg, sub, ownerName, e, n, eventClock)
if not (seg and seg._statsWindowPending and _nsofmuaauq[sub]
and ownerName and _vusprrkpjf(self, ownerName)) then return end
local amount, absorbed = _bcnobksaov(e, n)
if amount + absorbed <= 0 then return end
local state = seg._statsWindowBoundary
if not state then
state = { items={}, next=1, order=0 }
seg._statsWindowBoundary = state
end
state.order = state.order + 1
state.items[state.next] = {
e=e, n=n, clock=tonumber(eventClock), order=state.order,
}
state.next = (state.next % _ttrwxdtpsj) + 1
end
local function _oqnmffmudo(seg, eventClock, runtimeNow)
local state = seg and seg._statsWindowBoundary
seg._statsWindowBoundary = nil
if not state then return nil, runtimeNow end
eventClock = tonumber(eventClock)
if not eventClock then return nil, runtimeNow end
local selected, earliestDelta = {}, 0
for _, item in pairs(state.items or {}) do
local clock = tonumber(item.clock)
local delta = clock and (eventClock - clock) or -1
if delta >= 0 and delta <= _dwtickbygx then
selected[#selected + 1] = item
earliestDelta = math.max(earliestDelta, delta)
end
end
table.sort(selected, function(a, b) return a.order < b.order end)
return #selected > 0 and selected or nil, runtimeNow - earliestDelta
end
function _jercjlskad:ActivateStatsWindowIfNeeded(seg, sub, ownerName, dstGUID, dstName, dstFlags, e, n, now)
if not (seg and seg._statsWindowPending) then return true end
if not (_nsofmuaauq[sub]
and ownerName and _vusprrkpjf(self, ownerName)
and _udkdqjtpxn(seg, dstGUID, dstName, dstFlags)) then return false end
local amount, absorbed = _bcnobksaov(e, n)
if amount + absorbed <= 0 then return false end
local backfill
backfill, seg.startTime = _oqnmffmudo(seg, tonumber(e[1]), now)
seg.players = {}
seg.bossSpells = nil
seg._detailAuraSeeds = nil
seg._statsWindowPending = nil
seg._statsWindowActivated = true
seg._statsWindowBackfill = backfill
self.snapshotBuff = {}
self.channelStart = {}
if _zhsxohecfm then
if seg._statsWindowInheritAuras then
_ozsxfmqfgq(seg)
else
seg._detailAuraSeeds = {}
end
end
return true
end
local function _nxqxvpweap(rec, npcId, targetName, allDamage, alignedDamage, eligibleRaw)
if not (rec and npcId and npcId > 0) then return end
local scope = rec.targetScope
if type(scope) ~= "table" then
scope = _mgrddkckpb.UnpackTargetScope(scope)
rec.targetScope = scope
end
local b = scope[npcId]
if not b then
b = { targetName or "", 0, 0, 0 }
scope[npcId] = b
elseif (not b[1] or b[1] == "") and targetName then
b[1] = targetName
end
b[2] = _mgrddkckpb.N(b[2]) + _mgrddkckpb.N(allDamage)
b[3] = _mgrddkckpb.N(b[3]) + _mgrddkckpb.N(alignedDamage)
b[4] = _mgrddkckpb.N(b[4]) + _mgrddkckpb.N(eligibleRaw == nil and allDamage or eligibleRaw)
end
local function _nqrnkeadpv(now, startTime)
return math.floor(math.max(0, _mgrddkckpb.N(now) - _mgrddkckpb.N(startTime)) / _ofwfhrlszx) + 1
end
local function _xkmufbyeck(rec, field, now, startTime, amount)
amount = _mgrddkckpb.N(amount)
if not rec or amount <= 0 then return end
local buckets = rec[field]
if type(buckets) ~= "table" then buckets = {}; rec[field] = buckets end
local bucket = _nqrnkeadpv(now, startTime)
buckets[bucket] = _mgrddkckpb.N(buckets[bucket]) + amount
end
local function _qpudeortbc(rec, npcId, now, startTime, amount)
amount = _mgrddkckpb.N(amount)
if not (rec and npcId and npcId > 0 and amount > 0) then return end
local scope = rec.scopeTimeline
if type(scope) ~= "table" then scope = _mgrddkckpb.UnpackScopeTimeline(scope); rec.scopeTimeline = scope end
local buckets = scope[npcId]
if not buckets then buckets = {}; scope[npcId] = buckets end
local bucket = _nqrnkeadpv(now, startTime)
buckets[bucket] = _mgrddkckpb.N(buckets[bucket]) + amount
end
local function _wedqciqmik(e, sub)
if sub == "SWING_MISSED" then
return e[12] == "ABSORB" and _mgrddkckpb.N(e[14]) or 0
end
return e[15] == "ABSORB" and _mgrddkckpb.N(e[17]) or 0
end
local function _caozzqqmip(seg, dstGUID, npcId)
if seg and seg.name == _ckuxwzxbkd then
local W = _ysknifzsgw.WCLBosses
npcId = npcId or (W and W.NpcId and W.NpcId(dstGUID))
return npcId == _vopsmkbnkp
end
return false
end
local function _wyizrscurg(name, rec, spellId)
if not (name and _dnmjlknvvm[spellId]) then return end
local rosterInfo=_ysknifzsgw.Stats.roster[name]
local ready=_ysknifzsgw.Readiness and _ysknifzsgw.Readiness.localCache and _ysknifzsgw.Readiness.localCache[name]
local specId=(rec and rec.specId) or (ready and ready.specId) or (rosterInfo and rosterInfo.specId)
specId=tonumber(specId)
if specId and specId>0 then return end
if _ysknifzsgw.Stats.roster[name] then _ysknifzsgw.Stats.roster[name].role = "TANK" end
if rec then rec.role = "TANK" end
end
local function _fjprtbcwxc(e, sub)
if sub == "SWING_DAMAGE" or sub == "SWING_MISSED" then return true end
return bit.band(_mgrddkckpb.N(e[14]), 1) > 0
end
local function _ucnjaqzycg(spellId, spellName, byId, byName)
return byId[spellId] or byName[spellName]
end
local function _ekovevnhts(list, spellId)
if not list then return false end
for _, id in ipairs(list) do
if id == spellId then return true end
end
return false
end
local function _eszswbuhxp(prof, spellId, spellName)
local list = prof and prof.uptimeAuras and prof.uptimeAuras.faerieFire
return _ekovevnhts(list, spellId) or _zptejpwfwn[spellName] or false
end
local function _tuaiaejnyx(self, sub, srcGUID, srcName, dstGUID, dstName, e, n)
if not (dstGUID and sub and sub:sub(1, 11) == "SPELL_AURA_") then return end
local spellId = _mgrddkckpb.N(e[12])
if spellId == _qhtxwwbtlx then
self.unholyFrenzy = self.unholyFrenzy or {}
self.unholyFrenzyByGuid = self.unholyFrenzyByGuid or {}
if sub == "SPELL_AURA_APPLIED" or sub == "SPELL_AURA_REFRESH" then
local caster = _zxazfknbhl(srcGUID, srcName, e, n)
if caster and _vusprrkpjf(self, caster) then
if _mgrddkckpb.IsPlayer(dstGUID) then
self.unholyFrenzy[dstName] = { owner = caster, guid = srcGUID }
else
self.unholyFrenzyByGuid[dstGUID] = { owner = caster, guid = srcGUID }
end
end
elseif sub == "SPELL_AURA_REMOVED" then
if _mgrddkckpb.IsPlayer(dstGUID) then
self.unholyFrenzy[dstName] = nil
else
self.unholyFrenzyByGuid[dstGUID] = nil
end
end
end
if _mgrddkckpb.IsPlayer(dstGUID) then
local prof = _ysknifzsgw.Profiles and _ysknifzsgw.Profiles.GetActive and _ysknifzsgw.Profiles:GetActive()
local rules = prof and prof.excludedBuffs
if rules and rules[spellId] then
self.activeBuff = self.activeBuff or {}
self.activeBuff[dstName] = self.activeBuff[dstName] or {}
local t = self.activeBuff[dstName]
if sub == "SPELL_AURA_APPLIED" or sub == "SPELL_AURA_REFRESH" then
t[spellId] = math.max(1, t[spellId] or 0)
elseif sub == "SPELL_AURA_APPLIED_DOSE" then
local dose = _mgrddkckpb.N(e[n])
t[spellId] = dose > 0 and dose or ((t[spellId] or 0) + 1)
elseif sub == "SPELL_AURA_REMOVED_DOSE" then
local dose = _mgrddkckpb.N(e[n])
t[spellId] = dose > 0 and dose or math.max(0, (t[spellId] or 1) - 1)
elseif sub == "SPELL_AURA_REMOVED" then
t[spellId] = nil
end
end
end
end
local function _fhrmbrrqgv(self, sub, dstGUID, e, now)
if not (dstGUID and _mgrddkckpb.IsPlayer(dstGUID) and _mgrddkckpb.N(e[12]) == _tasxsstwhu) then return end
self._recentFeignDeath = self._recentFeignDeath or {}
if sub == "SPELL_AURA_APPLIED" or sub == "SPELL_AURA_REFRESH" then
self._recentFeignDeath[dstGUID] = now
elseif sub == "SPELL_AURA_REMOVED" then
self._recentFeignDeath[dstGUID] = nil
end
end
local function _tpmdgjaxgh(self, guid, name)
if not UnitIsFeignDeath then return false end
name = _ibckgpezre(name)
local info = name and self.roster and self.roster[name]
local unit = info and info.unit
if unit and (not UnitGUID or not guid or UnitGUID(unit) == guid) and UnitIsFeignDeath(unit) then return true end
local count = GetNumGroupMembers and (GetNumGroupMembers() or 0) or 0
local units = {}
if IsInRaid and IsInRaid() then
for index = 1, count do units[#units + 1] = "raid" .. index end
else
units[1] = "player"
for index = 1, math.max(0, count - 1) do units[#units + 1] = "party" .. index end
end
for _, candidate in ipairs(units) do
local sameGuid = guid and UnitGUID and UnitGUID(candidate) == guid
local candidateName = UnitName and _ibckgpezre(UnitName(candidate))
if (sameGuid or (name and candidateName == name)) and UnitIsFeignDeath(candidate) then return true end
end
return false
end
local function _vizxdduhjw(self, guid, name, now)
if _tpmdgjaxgh(self, guid, name) then return true end
local appliedAt = self._recentFeignDeath and self._recentFeignDeath[guid]
return appliedAt and now - appliedAt >= 0 and now - appliedAt <= _dpxqhkeihi or false
end
local function _uqzzausrzk(e, n, sub)
if not NoWCLDB then return end
NoWCLDB.debug = NoWCLDB.debug or {}
if NoWCLDB.debug[sub] then return end
local parts = {}
for i = 1, n do parts[i] = tostring(e[i]) end
NoWCLDB.debug[sub] = { n = n, params = parts }
end
local _fhszjaxqsk = {
trackFeignDeath=_fhrmbrrqgv,
isFeignDeathUnitEvent=_vizxdduhjw,
queuePendingSwing=_xrbibdcwgz,
takePendingSwing=_wvsuvaiscz,
swapNpcId=_hgfawetoph,
trackPersistentAuraState=_tuaiaejnyx,
eventAuraType=_vvtmagwimo,
notePrepull=_xxymhouyvi,
maybeStartObservedBoss=_wijagowggp,
maybeStartObservedDummy=_jnioofstry,
maybeStartObservedCombat=_xcmbeibxbv,
observedBossName=_rmrgasqqte,
segmentHasPlayerData=_naajkotkuv,
promoteObservedBoss=_cwtwmvlklt,
capture=_uqzzausrzk,
}
function _jercjlskad:HandleCLEU(e, n)
local sub      = e[2]
local srcGUID  = e[4]
local srcName  = _ibckgpezre(e[5])
local dstGUID  = e[8]
local dstName  = _ibckgpezre(e[9])
local dstFlags = e[10]
local now = e._nowclEventTime or GetTime()
local cleuTime = tonumber(e[1]) or now
if sub and sub:sub(1, 11) == "SPELL_AURA_" then
_fhszjaxqsk.trackFeignDeath(self, sub, dstGUID, e, now)
elseif sub == "UNIT_DIED" and _mgrddkckpb.IsPlayer(dstGUID) and _fhszjaxqsk.isFeignDeathUnitEvent(self, dstGUID, dstName, now) then
return false
end
if sub == "SWING_DAMAGE" and not e._nowclSwingNormalized then
if _fhszjaxqsk.queuePendingSwing(e, n, now) then
e._nowclSwingNormalized = true
e._nowclEventTime = now
return self:HandleCLEU(e, n)
end
return true
elseif sub == "SWING_DAMAGE_LANDED" then
self._swingLandedObserved = true
local item = _fhszjaxqsk.takePendingSwing(e, n, now)
if not item then return false end
item.e._nowclSwingNormalized = true
item.e._nowclEventTime = item.t
return self:HandleCLEU(item.e, item.n)
end
if _zhsxohecfm and sub == "UNIT_DIED" then _zhsxohecfm.ClearTargetAuras(dstGUID, _mgrddkckpb.IsPlayer(dstGUID)) end
if sub == "SPELL_SUMMON" and dstGUID then
local owner = _zxazfknbhl(srcGUID, srcName, e, n)
if owner then
_lkadegdain[dstGUID] = owner
local elementalGUID = _fhszjaxqsk.swapNpcId(dstGUID, 15439, 15438)
if elementalGUID then _lkadegdain[elementalGUID] = owner end
end
end
_fhszjaxqsk.trackPersistentAuraState(self, sub, srcGUID, srcName, dstGUID, dstName, e, n)
if _zhsxohecfm and sub and sub:sub(1, 11) == "SPELL_AURA_" then
local auraType = _fhszjaxqsk.eventAuraType(e, n)
local localName = UnitName and _ibckgpezre(UnitName("player"))
local source = _zxazfknbhl(srcGUID, srcName, e, n)
local relevantBuff = auraType == "BUFF" and _mgrddkckpb.IsPlayer(dstGUID)
and (_vusprrkpjf(self, dstName) or dstName == localName)
local relevantDebuff = auraType == "DEBUFF" and not _mgrddkckpb.IsPlayer(dstGUID)
and source and (_vusprrkpjf(self, source) or source == localName)
local terminal = sub == "SPELL_AURA_REMOVED" or sub == "SPELL_AURA_BROKEN"
or sub == "SPELL_AURA_BROKEN_SPELL"
if terminal then
_zhsxohecfm.TrackAuraState(sub, srcGUID, srcName, dstGUID, dstName,
e[12], e[13], e[14], auraType, e[n])
elseif relevantBuff or relevantDebuff then
local storedSource = relevantDebuff and _ibckgpezre(source) or srcName
local storedSpell = relevantDebuff and not _mgrddkckpb.IsPlayer(srcGUID)
and ("宠物: " .. tostring(e[13] or "?")) or e[13]
_zhsxohecfm.TrackAuraState(sub, srcGUID, storedSource, dstGUID, dstName,
e[12], storedSpell, e[14], auraType, e[n])
end
end
if _nsofmuaauq[sub] or _oieuqthusd[sub] then
local seg0 = self.segment
if not seg0 or seg0._ended or not seg0.isBoss then _fhszjaxqsk.notePrepull(now, e, n) end
end
local seg = self.segment
if not seg or seg._ended then
if _fhszjaxqsk.maybeStartObservedBoss(self, sub, srcGUID, srcName, dstGUID, dstName) then
seg = self.segment
elseif _fhszjaxqsk.maybeStartObservedDummy(self, sub, srcGUID, srcName, dstName) then
seg = self.segment
elseif _fhszjaxqsk.maybeStartObservedCombat(self, sub, srcGUID, srcName, dstGUID, dstName, e, n) then
seg = self.segment
else
return false
end
elseif not seg.isBoss then
local bossName = _fhszjaxqsk.observedBossName(dstGUID, dstName)
if bossName and _fhszjaxqsk.segmentHasPlayerData(seg) then
self:OnCombatStart(false, "战斗")
seg = self.segment
end
_fhszjaxqsk.promoteObservedBoss(self, seg, bossName, dstName)
end
local ownerName = _zxazfknbhl(srcGUID, srcName, e, n)
local damageEvent = _nsofmuaauq[sub] or _oieuqthusd[sub]
local outgoingDamageEvent = damageEvent and _vusprrkpjf(self, ownerName)
local incomingDamageEvent = damageEvent
and _mgrddkckpb.IsPlayer(dstGUID) and _vusprrkpjf(self, dstName)
local absorbedDamageEvent = sub == _fwsrnozimg
and _mgrddkckpb.IsPlayer(dstGUID) and _vusprrkpjf(self, dstName)
if not seg.isBoss and seg._endingAt then
return false
end
if not seg.isBoss and (outgoingDamageEvent
or (seg._playerCombat and (incomingDamageEvent or absorbedDamageEvent))) then
seg._damageConfirmed = true
seg._observed = true
if outgoingDamageEvent then seg._confirmationKind = "outgoing"
elseif absorbedDamageEvent then seg._confirmationKind = "absorbed"
else seg._confirmationKind = "incoming" end
end
if (seg._endingAt or (not seg.isBoss and not seg.isDummy and not seg._damageConfirmed))
and (_yorvfbmjth[sub] or sub == _fwsrnozimg) then
return false
end
if not self:ActivateStatsWindowIfNeeded(seg, sub, ownerName, dstGUID, dstName, dstFlags, e, n, now) then
self:RememberStatsWindowBoundary(seg, sub, ownerName, e, n, cleuTime)
return false
end
local boundaryBackfill = seg._statsWindowBackfill
if boundaryBackfill then
seg._statsWindowBackfill = nil
for _, item in ipairs(boundaryBackfill) do
self:HandleCLEU(item.e, item.n)
end
end
if _nsofmuaauq[sub] or _oieuqthusd[sub] or _yorvfbmjth[sub] or sub == _fwsrnozimg then _fhszjaxqsk.capture(e, n, sub) end
local detailNow = _zhsxohecfm and _zhsxohecfm.EventTime and _zhsxohecfm.EventTime(seg, now, cleuTime) or now
if _nsofmuaauq[sub] and _mgrddkckpb.IsPlayer(dstGUID) and _vusprrkpjf(self, dstName) then
self:RecordIncomingDamage(seg, dstName, dstGUID, sub, e, n, now)
end
if _zhsxohecfm and _zhsxohecfm.IsBossSource(seg, srcGUID, srcName) then
local spellId = (sub == "SWING_DAMAGE" or sub == "SWING_MISSED") and 6603 or _mgrddkckpb.N(e[12])
local spellName = (sub == "SWING_DAMAGE" or sub == "SWING_MISSED") and "近战" or e[13]
local school = (sub == "SWING_DAMAGE" or sub == "SWING_MISSED") and 1 or _mgrddkckpb.N(e[14])
if sub == "SPELL_CAST_START" or sub == "SPELL_CAST_SUCCESS" then
_moexofbiuz(spellName, spellId, school)
_zhsxohecfm.RecordBossCast(seg, sub, spellId, spellName, school, dstName, detailNow)
elseif _nsofmuaauq[sub] and _mgrddkckpb.IsPlayer(dstGUID) and _vusprrkpjf(self, dstName) then
local amount, absorbed = _bcnobksaov(e, n)
local effective = amount + absorbed
if effective > 0 then
_moexofbiuz(spellName, spellId, school)
_zhsxohecfm.RecordBossHit(seg, spellId, spellName, school, effective, _xreeivsdvs(e, n))
end
elseif sub and sub:sub(1, 11) == "SPELL_AURA_" and _mgrddkckpb.IsPlayer(dstGUID) then
_moexofbiuz(spellName, spellId, school)
_zhsxohecfm.RecordBossAura(seg, sub, spellId, spellName, school, dstName, detailNow)
end
end
local validPullTarget = false
if seg.isBoss then
validPullTarget = _udkdqjtpxn(seg, dstGUID, dstName, dstFlags)
elseif seg.isDummy then
validPullTarget = _mgrddkckpb.IsTrainingDummy(dstName)
end
if not seg.puller and validPullTarget and _lkfiircvjk[sub]
and ownerName and _vusprrkpjf(self, ownerName) then
_wpoyinzszj(self, seg, ownerName, sub, e)
end
if sub == "UNIT_DIED" and seg.isBoss and (seg._observedBoss or seg._finishOnBossDeath)
and dstGUID and not _mgrddkckpb.IsPlayer(dstGUID) then
if _udkdqjtpxn(seg, dstGUID, dstName, dstFlags) then
seg._bossDied = true
seg._bossDiedAt = now
return true
end
end
if sub == "UNIT_DIED" and _mgrddkckpb.IsPlayer(dstGUID) and _vusprrkpjf(self, dstName) then
local r = getRec(seg, dstName, dstGUID)
r.deaths = r.deaths + 1
local deathTime = math.max(0, now - (seg.startTime or now))
r.deathTimes[#r.deathTimes+1] = deathTime
local recentState = seg._recentDamageByPlayer and seg._recentDamageByPlayer[dstName]
self:SnapshotDeathDamage(r, deathTime, recentState)
if seg._recentDamageByPlayer then seg._recentDamageByPlayer[dstName] = nil end
if _ysknifzsgw.DeathNotice and _ysknifzsgw.DeathNotice.Announce then
_ysknifzsgw.DeathNotice:Announce(dstName, dstGUID, r.deathDetails[#r.deathDetails], seg)
end
r._deadAt = now
return true
end
if sub == "SPELL_RESURRECT" and _mgrddkckpb.IsPlayer(dstGUID) then
if _vusprrkpjf(self, dstName) then
local r = getRec(seg, dstName, dstGUID)
if r._deadAt then r.deadSec = r.deadSec + (now - r._deadAt); r._deadAt = nil end
if seg._recentDamageByPlayer then seg._recentDamageByPlayer[dstName] = nil end
end
local caster = _zxazfknbhl(srcGUID, srcName, e, n)
if caster and _vusprrkpjf(self, caster) then _mgrddkckpb.AddExtraTask(getRec(seg, caster, srcGUID), "battleRes") end
return (caster and _vusprrkpjf(self, caster)) or _vusprrkpjf(self, dstName)
end
if sub == _fwsrnozimg then
local shieldGUID, shieldName, spellId, spellName, school, amount = _obdwdyzaiq(e)
local caster = _zxazfknbhl(shieldGUID, shieldName, e, n)
if not caster or not _vusprrkpjf(self, caster) then return false end
local shieldRec = getRec(seg, caster, shieldGUID)
shieldRec.heal = shieldRec.heal + amount
_xkmufbyeck(shieldRec, "healingBuckets", now, seg.startTime, amount)
shieldRec.heals[spellName] = (shieldRec.heals[spellName] or 0) + amount
if dstName then
shieldRec.healTargets[dstName] = (shieldRec.healTargets[dstName] or 0) + amount
end
_moexofbiuz(spellName, spellId, school)
if _zhsxohecfm then _zhsxohecfm.RecordHeal(shieldRec, spellName, spellId, school, amount, 0, false) end
return true
end
if dstGUID and sub and sub:sub(1,11) == "SPELL_AURA_" then
local spellId = _mgrddkckpb.N(e[12])
if srcName == dstName and (sub == "SPELL_AURA_APPLIED" or sub == "SPELL_AURA_REFRESH") then
_wyizrscurg(dstName, seg.players and seg.players[dstName], spellId)
end
if _zhsxohecfm and _fhszjaxqsk.eventAuraType(e, n) == "BUFF" and _mgrddkckpb.IsPlayer(dstGUID) and _vusprrkpjf(self, dstName) then
local dstRec = getRec(seg, dstName, dstGUID)
_zhsxohecfm.RecordBuff(dstRec, sub, spellId, e[13], _mgrddkckpb.N(e[14]), srcName,
math.max(0, math.floor((detailNow - (seg.startTime or detailNow)) * 1000 + 0.5)))
_moexofbiuz(e[13], spellId, _mgrddkckpb.N(e[14]))
end
end
if _mgrddkckpb.IsPlayer(srcGUID) and dstGUID and not _mgrddkckpb.IsPlayer(dstGUID) and sub and sub:sub(1,11) == "SPELL_AURA_" then
local spellId = _mgrddkckpb.N(e[12])
local key = _wmlvtqyirl(srcName, dstGUID, spellId)
if sub == "SPELL_AURA_APPLIED" or sub == "SPELL_AURA_REFRESH" then
self.snapshotBuff[key] = _bixlwdoyxd(srcName, dstGUID)
elseif sub == "SPELL_AURA_REMOVED" then
self.snapshotBuff[key] = nil
end
end
if not ownerName or not _vusprrkpjf(self, ownerName) then return false end
if seg._observed and seg.isDummy and not _vusprrkpjf(self, ownerName) then return false end
local r = getRec(seg, ownerName, srcGUID)
if _zhsxohecfm and sub and sub:sub(1, 11) == "SPELL_AURA_" and _fhszjaxqsk.eventAuraType(e, n) == "DEBUFF"
and dstGUID and not _mgrddkckpb.IsPlayer(dstGUID) then
local spellId = _mgrddkckpb.N(e[12])
local npcId = _ysknifzsgw.WCLBosses and _ysknifzsgw.WCLBosses.NpcId and _ysknifzsgw.WCLBosses.NpcId(dstGUID) or 0
local auraName = _mgrddkckpb.IsPlayer(srcGUID) and e[13] or ("宠物: " .. tostring(e[13] or "?"))
_zhsxohecfm.RecordDebuff(r, sub, spellId, auraName, _mgrddkckpb.N(e[14]), dstName, npcId,
math.max(0, math.floor((detailNow - (seg.startTime or detailNow)) * 1000 + 0.5)))
_moexofbiuz(auraName, spellId, _mgrddkckpb.N(e[14]))
end
if _mgrddkckpb.IsPlayer(srcGUID) and sub and sub:sub(1,6)=="SPELL_" then
local inferred=_mgrddkckpb.SpecializationFromSpell and _mgrddkckpb.SpecializationFromSpell(e[12],r.class)
local inferredClass=inferred and _mgrddkckpb.ClassFromSpecialization
and _mgrddkckpb.ClassFromSpecialization(inferred) or nil
if not inferredClass and _mgrddkckpb.ClassFromSpell then
inferredClass=_mgrddkckpb.ClassFromSpell(e[12],r.class)
end
if inferredClass and not r.class then
r.class=inferredClass
local rosterInfo=self.roster and self.roster[ownerName]
if rosterInfo then rosterInfo.class=inferredClass end
end
if inferred and inferred~=r.specId then
r.specId=inferred
if _ysknifzsgw.Readiness and _ysknifzsgw.Readiness.CacheSpecialization then
_ysknifzsgw.Readiness:CacheSpecialization(ownerName,inferred)
end
end
end
if sub == "SPELL_CAST_SUCCESS" then
local castSpellId = _mgrddkckpb.N(e[12])
local key = _ucnjaqzycg(castSpellId, e[13], _gtrjplnyuy, _gfjzcrytfm)
if key then
local dedupWindow = key == "tranquility" and 10 or nil
local lastAt = r._extraTaskCastAt and r._extraTaskCastAt[key]
if not dedupWindow or not lastAt or (detailNow - lastAt) > dedupWindow then
_mgrddkckpb.AddExtraTask(r, key)
if dedupWindow then
r._extraTaskCastAt = r._extraTaskCastAt or {}
r._extraTaskCastAt[key] = detailNow
end
end
end
if _zhsxohecfm then
local spellKey = _mgrddkckpb.IsPlayer(srcGUID) and (e[13] or "?") or ("宠物: " .. tostring(e[13] or "?"))
local castTargetNpc = dstGUID and not _mgrddkckpb.IsPlayer(dstGUID)
and _ysknifzsgw.WCLBosses and _ysknifzsgw.WCLBosses.NpcId and _ysknifzsgw.WCLBosses.NpcId(dstGUID) or 0
if _zhsxohecfm.ShouldRecordCast(castSpellId) then
_zhsxohecfm.RecordCast(r, spellKey, castSpellId, _mgrddkckpb.N(e[14]), castTargetNpc, dstName,
cleuTime, _bibsarqdjs[castSpellId], dstGUID)
end
if _mgrddkckpb.IsPlayer(srcGUID) and castSpellId == _jzpxuvtimo then
_zhsxohecfm.BeginDerivedCastGeneration(r, _jspaegjygo, cleuTime)
elseif not _mgrddkckpb.IsPlayer(srcGUID) and _jkethqktpe[castSpellId] then
_zhsxohecfm.MarkDerivedCastObserved(r, _jspaegjygo, castSpellId, cleuTime)
end
_moexofbiuz(spellKey, castSpellId, _mgrddkckpb.N(e[14]))
end
end
if _mgrddkckpb.IsPlayer(srcGUID) then
local s0 = seg.startTime or now
if sub == "SPELL_CAST_START" then
r._castStart = now
_qojtualhih(r, now, now + _ksvxdmiunz, s0)
elseif _swmuecoscn[sub] then
r.actions = r.actions + 1
if sub == "SPELL_CAST_SUCCESS" and r._castStart and now > r._castStart and (now - r._castStart) <= 12 then
_qojtualhih(r, r._castStart, now + _ksvxdmiunz, s0)
else
_qojtualhih(r, now, now + _ksvxdmiunz, s0)
end
r._castStart = nil
end
end
if _zhsxohecfm and (sub == "SWING_DAMAGE" or sub == "SWING_MISSED") then
local meleeKey = _mgrddkckpb.IsPlayer(srcGUID) and "近战" or "宠物: 近战"
local meleeTargetNpc = _ysknifzsgw.WCLBosses and _ysknifzsgw.WCLBosses.NpcId
and _ysknifzsgw.WCLBosses.NpcId(dstGUID) or 0
_zhsxohecfm.RecordCast(r, meleeKey, 6603, 1, meleeTargetNpc, dstName)
_moexofbiuz(meleeKey, 6603, 1)
end
if _nsofmuaauq[sub] or _oieuqthusd[sub] then
local amt, absorbed
if _oieuqthusd[sub] then
amt = 0
absorbed = _wedqciqmik(e, sub)
else
amt, absorbed = _bcnobksaov(e, n)
end
local eff = amt + absorbed
if eff > 0 then
r.dmg = r.dmg + eff
_xkmufbyeck(r, "damageBuckets", now, seg.startTime, eff)
r.absorbed = r.absorbed + absorbed
local isSwing = (sub == "SWING_DAMAGE" or sub == "SWING_MISSED")
local sn = isSwing and "近战" or (e[13] or "?")
local spellId = isSwing and 6603 or _mgrddkckpb.N(e[12])
local spellKey = _mgrddkckpb.IsPlayer(srcGUID) and sn or ("宠物: " .. sn)
r.spells[spellKey] = (r.spells[spellKey] or 0) + eff
_wyizrscurg(ownerName, r, spellId)
_moexofbiuz(spellKey, spellId, isSwing and 1 or _mgrddkckpb.N(e[14]))
local excluded = _mgrddkckpb.IsPlayer(srcGUID) and _nbarkpgtcb(ownerName, eff, dstGUID, spellId, sub == "SPELL_PERIODIC_DAMAGE") or 0
r.wclExcluded = r.wclExcluded + excluded
local targetNpc = _ysknifzsgw.WCLBosses and _ysknifzsgw.WCLBosses.NpcId(dstGUID)
local isBossDmg = _udkdqjtpxn(seg, dstGUID, dstName, dstFlags, targetNpc)
local scopeEligible = not _caozzqqmip(seg, dstGUID, targetNpc)
or (_mgrddkckpb.IsPlayer(srcGUID) and _mgrddkckpb.RoleOfPlayer(r) == "TANK")
if isBossDmg and not scopeEligible then isBossDmg = false end
local bossSpellExcluded = 0
if _ysknifzsgw.WCLBosses and _ysknifzsgw.WCLBosses.BossSpellExcluded
and _ysknifzsgw.WCLBosses:BossSpellExcluded(seg.name, spellId) then
bossSpellExcluded = eff
end
local scopeExcluded = excluded + bossSpellExcluded
local eventCritical = not _oieuqthusd[sub]
and _sqrgzoobyx(e, n, isSwing and 6603 or _mgrddkckpb.N(e[12]))
local petUf = self.unholyFrenzyByGuid and self.unholyFrenzyByGuid[srcGUID]
local playerUf = _mgrddkckpb.IsPlayer(srcGUID) and self.unholyFrenzy and self.unholyFrenzy[ownerName]
local uf = petUf or playerUf
if uf and uf.owner and _fjprtbcwxc(e, sub) then
local bonus = math.floor(eff / 6)
local credit = bonus
if playerUf and uf.owner == ownerName and (eff % 6) > 0 then
credit = bonus + 1
end
if bonus > 0 then
r.wclExcluded = r.wclExcluded + bonus
if isBossDmg then r.wclBossExcluded = r.wclBossExcluded + bonus end
scopeExcluded = scopeExcluded + bonus
if _vusprrkpjf(self, uf.owner) then
local ur = getRec(seg, uf.owner, uf.guid)
ur.dmg = ur.dmg + credit
_xkmufbyeck(ur, "damageBuckets", now, seg.startTime, credit)
ur.spells[_tpbpblbgyp] = (ur.spells[_tpbpblbgyp] or 0) + credit
_moexofbiuz(_tpbpblbgyp, _qhtxwwbtlx, 1)
if _zhsxohecfm then
_zhsxohecfm.RecordDamage(ur, _tpbpblbgyp, _qhtxwwbtlx, 1, credit, 0, eventCritical,
targetNpc, dstName, scopeEligible and credit or 0,
(isBossDmg and scopeEligible) and credit or 0,
_oieuqthusd[sub] and true or false)
end
if isBossDmg then
ur.dmgBoss = ur.dmgBoss + credit
_xkmufbyeck(ur, "bossDamageBuckets", now, seg.startTime, credit)
end
if dstName and not _mgrddkckpb.IsPlayer(dstGUID) then
ur.targets[dstName] = (ur.targets[dstName] or 0) + credit
if isBossDmg then ur.targetsBoss[dstName] = true end
_qpudeortbc(ur, targetNpc, now, seg.startTime, scopeEligible and credit or 0)
_nxqxvpweap(ur, targetNpc, dstName, credit, scopeEligible and credit or 0,
scopeEligible and credit or 0)
end
end
end
end
if isBossDmg then
r.dmgBoss = r.dmgBoss + eff
r.wclBossExcluded = r.wclBossExcluded + excluded + bossSpellExcluded
local alignedNow = scopeEligible and math.max(0, eff - scopeExcluded) or 0
_xkmufbyeck(r, "bossDamageBuckets", now, seg.startTime, alignedNow)
end
if _zhsxohecfm then
local alignedForTarget = scopeEligible and math.max(0, eff - scopeExcluded) or 0
if not _mgrddkckpb.IsPlayer(srcGUID) and _jkethqktpe[spellId] then
_zhsxohecfm.RecordDerivedCast(r, _jspaegjygo, spellId, spellKey, spellId,
isSwing and 1 or _mgrddkckpb.N(e[14]), targetNpc, dstName, cleuTime, dstGUID)
end
_zhsxohecfm.RecordDamage(r, spellKey, spellId, isSwing and 1 or _mgrddkckpb.N(e[14]), eff, absorbed,
eventCritical, targetNpc, dstName, alignedForTarget,
(isBossDmg and scopeEligible) and alignedForTarget or 0,
_oieuqthusd[sub] and true or false)
end
if dstName and not _mgrddkckpb.IsPlayer(dstGUID) then
r.targets[dstName] = (r.targets[dstName] or 0) + eff
if isBossDmg then r.targetsBoss[dstName] = true end
_qpudeortbc(r, targetNpc, now, seg.startTime,
scopeEligible and math.max(0, eff - scopeExcluded) or 0)
_nxqxvpweap(r, targetNpc, dstName, eff,
scopeEligible and math.max(0, eff - scopeExcluded) or 0,
scopeEligible and eff or 0)
end
if not seg.isBoss and not seg.firstTarget and dstName and dstGUID and not _mgrddkckpb.IsPlayer(dstGUID) then
seg.firstTarget = dstName
end
elseif _zhsxohecfm and _oieuqthusd[sub]
and not (sub == "SPELL_MISSED" and _mgrddkckpb.N(e[12]) == _hpgrcfqyja
and e[15] == "IMMUNE")
and _zhsxohecfm.ShouldRecordDamageMiss(_mgrddkckpb.N(e[12])) then
local isSwing = sub == "SWING_MISSED"
local spellName = isSwing and "近战" or (e[13] or "?")
local spellId = isSwing and 6603 or _mgrddkckpb.N(e[12])
local spellKey = _mgrddkckpb.IsPlayer(srcGUID) and spellName or ("宠物: " .. spellName)
local targetNpc = _ysknifzsgw.WCLBosses and _ysknifzsgw.WCLBosses.NpcId and _ysknifzsgw.WCLBosses.NpcId(dstGUID) or 0
local petUf = self.unholyFrenzyByGuid and self.unholyFrenzyByGuid[srcGUID]
local playerUf = _mgrddkckpb.IsPlayer(srcGUID) and self.unholyFrenzy and self.unholyFrenzy[ownerName]
local uf = petUf or playerUf
if uf and uf.owner and _fjprtbcwxc(e, sub) and _vusprrkpjf(self, uf.owner) then
local ur = getRec(seg, uf.owner, uf.guid)
_zhsxohecfm.RecordDamage(ur, _tpbpblbgyp, _qhtxwwbtlx, 1, 0, 0, false,
targetNpc, dstName, 0, 0, true)
end
_zhsxohecfm.RecordDamage(r, spellKey, spellId, isSwing and 1 or _mgrddkckpb.N(e[14]), 0, 0, false,
targetNpc, dstName, 0, 0, true)
_moexofbiuz(spellKey, spellId, isSwing and 1 or _mgrddkckpb.N(e[14]))
end
elseif _yorvfbmjth[sub] then
local amt = _mgrddkckpb.N(e[n-3]); local over = _mgrddkckpb.N(e[n-2])
local effHeal = math.max(0, amt - over)
r.heal = r.heal + effHeal
_xkmufbyeck(r, "healingBuckets", now, seg.startTime, effHeal)
local sn = e[13] or "?"
r.heals[sn] = (r.heals[sn] or 0) + effHeal
_moexofbiuz(sn, _mgrddkckpb.N(e[12]), _mgrddkckpb.N(e[14]))
if _zhsxohecfm then _zhsxohecfm.RecordHeal(r, sn, _mgrddkckpb.N(e[12]), _mgrddkckpb.N(e[14]), effHeal, over, _zhsxohecfm.Flag(e[n])) end
if dstName then r.healTargets[dstName] = (r.healTargets[dstName] or 0) + effHeal end
elseif sub == "SPELL_INTERRUPT" then
r.interrupts = r.interrupts + 1
elseif sub == "SPELL_DISPEL" then
r.dispels = r.dispels + 1
elseif sub == "SPELL_AURA_APPLIED" or sub == "SPELL_AURA_REFRESH" then
local spellId = _mgrddkckpb.N(e[12])
local key = _ucnjaqzycg(spellId, e[13], _fnmuymhisd, _crupoqustr)
if key then _mgrddkckpb.AddExtraTask(r, key) end
local prof = _ysknifzsgw.Profiles:GetActive()
if _ekovevnhts(prof.uptimeAuras and prof.uptimeAuras.sunder, spellId) then
r.sunderApplied = r.sunderApplied + 1
elseif _eszswbuhxp(prof, spellId, e[13]) then
_mgrddkckpb.AddExtraTask(r, "faerieFire")
end
end
return true
end
computeArray = function(seg, forcedEnd)
if not seg then return {}, 0 end
local segEnd = (forcedEnd or seg.endTime or seg._endingAt or GetTime())
local dur = (segEnd - seg.startTime)
if dur < 1 then dur = 1 end
local out = {}
local persistTargetScope = seg._ended or seg.endTime
for name, r in pairs(seg.players) do
local ready=_ysknifzsgw.Readiness and _ysknifzsgw.Readiness.localCache and _ysknifzsgw.Readiness.localCache[name]
local deadSec = r.deadSec or 0
if r._deadAt then deadSec = deadSec + (segEnd - r._deadAt) end
local aligned = math.max(0, (r.dmg or 0) - (r.wclExcluded or 0))
local alignedBoss = math.max(0, (r.dmgBoss or 0) - (r.wclBossExcluded or 0))
out[#out+1] = {
name=name, class=r.class, role=r.role, specId=r.specId or (ready and ready.specId),
dmg=r.dmg, dmgBoss=alignedBoss, rawDmgBoss=r.dmgBoss, heal=r.heal, absorbed=r.absorbed,
wclExcluded=r.wclExcluded, wclBossExcluded=r.wclBossExcluded,
alignedDmg=aligned, dps=r.dmg/dur, bossDps=alignedBoss/dur, alignedDps=aligned/dur,
interrupts=r.interrupts, dispels=r.dispels, deaths=r.deaths,
sunderApplied=r.sunderApplied,
extraTasks=_mgrddkckpb.CopyExtraTasks(r.extraTasks, r.class),
activeMs=r.activeMs, activePct=math.min(1,(r.activeMs/1000)/dur),
actions=r.actions, iv=r.iv, fightDur=dur,
deadSec=deadSec, deathTimes=r.deathTimes, deathDetails=r.deathDetails,
spells=r.spells, heals=r.heals,
spellStats=r.spellStats, healStats=r.healStats, castStats=r.castStats,
castTargetStats=r.castTargetStats,
spellTargetStats=r.spellTargetStats, auraBuffs=r.auraBuffs, auraDebuffs=r.auraDebuffs,
timelineBucket=r.timelineBucket or _ofwfhrlszx,
damageBuckets=r.damageBuckets, bossDamageBuckets=r.bossDamageBuckets, healingBuckets=r.healingBuckets,
targets=r.targets, targetsBoss=r.targetsBoss, healTargets=r.healTargets,
targetScope=persistTargetScope and _mgrddkckpb.PackTargetScope(r.targetScope) or nil,
scopeTimeline=persistTargetScope and _mgrddkckpb.PackScopeTimeline(r.scopeTimeline) or nil,
}
end
return out, dur
end
function _jercjlskad:GetPlayers()
return computeArray(self.segment)
end
local function _ckygamzhnz(value, seen)
if type(value) ~= "table" then return value end
seen = seen or {}
if seen[value] then return seen[value] end
local out = {}
seen[value] = out
for key, child in pairs(value) do
out[_ckygamzhnz(key, seen)] = _ckygamzhnz(child, seen)
end
return out
end
function _jercjlskad:FreezeCurrentDisplay(endTime)
local seg = self.segment
if not (seg and not seg._ended) then return false end
if seg._displayPlayers then return true end
local frozenAt = tonumber(endTime) or GetTime()
local players, dur = computeArray(seg, frozenAt)
seg._displayPlayers = _ckygamzhnz(players)
seg._displayDur = dur
seg._displayEndAt = frozenAt
return true
end
function _jercjlskad:GetDisplayPlayers()
local seg = self.segment
if seg and not seg._ended and seg._displayPlayers then
return seg._displayPlayers, seg._displayDur or 0
end
return computeArray(seg)
end
function _jercjlskad:ClearCurrentDisplayFreeze(endTime)
local seg = self.segment
if not (seg and not seg._ended) then return false end
if endTime and seg._displayEndAt and seg._displayEndAt ~= endTime then return false end
seg._displayPlayers = nil
seg._displayDur = nil
seg._displayEndAt = nil
if not endTime or seg._endingAt == endTime then seg._endingAt = nil end
return true
end
function _jercjlskad:RecomputePlayerTargetScope(p, bossName, dur, bossCfg)
if not p or (type(p.targetScope) ~= "string" and type(p.targetScope) ~= "table")
or (type(p.targetScope) == "string" and p.targetScope == "") then return false end
local buckets = _mgrddkckpb.UnpackTargetScope(p.targetScope)
if not next(buckets) then return false end
local W = _ysknifzsgw.WCLBosses
local known = W and W.Get and W.Get(bossName)
local rawBoss, alignedBoss, targetSet = 0, 0, {}
for npcId, b in pairs(buckets) do
local targetName = b[1]
local included
if _mgrddkckpb.IsTrainingDummy(targetName) then
included = true
elseif known and W.CountsNpcAsBoss then
included = W:CountsNpcAsBoss(bossName, npcId, bossCfg)
else
included = targetName and bossName and targetName == bossName
end
if included then
rawBoss = rawBoss + _mgrddkckpb.N(b[4] or b[2])
alignedBoss = alignedBoss + _mgrddkckpb.N(b[3])
if targetName and targetName ~= "" then targetSet[targetName] = true end
end
end
dur = math.max(1, _mgrddkckpb.N(dur or p.fightDur))
p.rawDmgBoss = rawBoss
p.dmgBoss = math.max(0, alignedBoss)
p.wclBossExcluded = math.max(0, rawBoss - alignedBoss)
p.bossDps = p.dmgBoss / dur
p.targetsBoss = targetSet
if (type(p.scopeTimeline) == "string" and p.scopeTimeline ~= "")
or type(p.scopeTimeline) == "table" then
local scopeTimeline = _mgrddkckpb.UnpackScopeTimeline(p.scopeTimeline)
local rebuilt = {}
for npcId, timeline in pairs(scopeTimeline) do
local b = buckets[npcId]
local targetName = b and b[1]
local included
if _mgrddkckpb.IsTrainingDummy(targetName) then
included = true
elseif known and W.CountsNpcAsBoss then
included = W:CountsNpcAsBoss(bossName, npcId, bossCfg)
else
included = targetName and bossName and targetName == bossName
end
if included then
for bucket, amount in pairs(timeline) do rebuilt[bucket] = _mgrddkckpb.N(rebuilt[bucket]) + _mgrddkckpb.N(amount) end
end
end
p.bossDamageBuckets = rebuilt
end
return true
end
function _jercjlskad:SegmentName()
local seg = self.segment
if not seg then return "(无战斗)" end
if seg.isBoss then return seg.name end
return seg.firstTarget or seg.name
end
function _jercjlskad:SegmentCalibrated()
local seg = self.segment
if not (seg and seg.isBoss) then return true end
local W = _ysknifzsgw.WCLBosses
return (W and W.IsCalibrated and W:IsCalibrated(seg.name)) and true or false
end
_jercjlskad.history = {}
local _wbhslwqcym = 300
local function _ayuemejzgx()
return _mgrddkckpb.CombatHistoryLimit and _mgrddkckpb.CombatHistoryLimit() or 30
end
function _jercjlskad:PruneHistory(limit)
limit = math.max(1, math.min(99, tonumber(limit) or _ayuemejzgx()))
local removed = 0
while #self.history > limit do table.remove(self.history); removed = removed + 1 end
if removed > 0 then self:Persist() end
return removed
end
saveCurrentSnapshot = function(self)
if not self.segment then return end
local players, dur = computeArray(self.segment)
if #players == 0 then return end
self.lastCurrentSegment = {
name = self:SegmentName(),
isBoss = self.segment.isBoss,
isDummy = self.segment.isDummy,
dur = dur,
ts = time(),
players = players,
bossSpells = self.segment.bossSpells,
puller = self.segment.puller,
pullMethod = self.segment.pullMethod,
pullSpellId = self.segment.pullSpellId,
}
end
function _jercjlskad:SegmentRecordable()
local s = self.segment
return (s and (s.isBoss or s.isDummy)) and true or false
end
function _jercjlskad:IsCurrentSegmentVisible()
local s = self.segment
return (s and not s._ended and (s.isBoss or s.isDummy or s._damageConfirmed == true)) and true or false
end
function _jercjlskad:FinalizeSegment()
if not self.segment then return end
if not self:SegmentRecordable() then return end
local players, dur = computeArray(self.segment)
if #players == 0 then return end
table.insert(self.history, 1, {
name = self.segment.name, isBoss = self.segment.isBoss,
dur = dur, ts = time(), players = players, bossSpells = self.segment.bossSpells,
puller = self.segment.puller,
pullMethod = self.segment.pullMethod,
pullSpellId = self.segment.pullSpellId,
})
self:PruneHistory(_ayuemejzgx())
self:Persist()
end
function _jercjlskad:Persist()
if not NoWCLDB then return end
NoWCLDB.segments = self.history
NoWCLDB.spellInfo = self.spellInfo
NoWCLDB.currentSegment = self.lastCurrentSegment
if _zhsxohecfm and _zhsxohecfm.ExportActiveAuras then
NoWCLDB.detailAuraState={savedAt=time(),auras=_zhsxohecfm.ExportActiveAuras()}
end
local seg = self.segment
if seg and not seg._ended and self:SegmentRecordable() then
local now = GetTime()
local wall = time()
NoWCLDB.activeSegment = {
segment = seg,
activeBuff = self.activeBuff,
snapshotBuff = self.snapshotBuff,
unholyFrenzy = self.unholyFrenzy,
unholyFrenzyByGuid = self.unholyFrenzyByGuid,
channelStart = self.channelStart,
petOwner = _lkadegdain,
playerByGUID = _gvggrzhdvg,
savedAt = wall,
startWall = wall - math.max(0, now - (seg.startTime or now)),
}
else
NoWCLDB.activeSegment = nil
end
if _zhsxohecfm and _zhsxohecfm.InvalidateStorageEstimate then _zhsxohecfm.InvalidateStorageEstimate() end
end
function _jercjlskad:FlushActiveSegment(endTime)
local seg = self.segment
if not (seg and not seg._ended and self:SegmentRecordable()) then return false end
if seg.isBoss and not (seg._bossDied or seg._wipeDetected) then return false end
local resolvedEnd = endTime or seg._bossDiedAt or seg._wipeAt or GetTime()
if seg._finishOnBossDeath and seg._bossDiedAt then resolvedEnd = seg._bossDiedAt end
self:FlushPendingSwings(resolvedEnd, true)
seg._ended = true
seg.endTime = resolvedEnd
if _zhsxohecfm then
local dur = math.max(0, seg.endTime - (seg.startTime or seg.endTime))
for _, rec in pairs(seg.players or {}) do _zhsxohecfm.CloseRecord(rec, dur) end
_zhsxohecfm.CloseBossSpells(seg)
_zhsxohecfm.ClearTransientAuras()
end
self:FinalizeSegment()
return true
end
function _jercjlskad:Restore()
local function sanitizeStoredSegment(seg)
for _, p in pairs((seg and seg.players) or {}) do
p.extraTasks = _mgrddkckpb.CopyExtraTasks(p.extraTasks, p.class)
end
end
if _zhsxohecfm and _zhsxohecfm.RestoreActiveAuras and NoWCLDB and type(NoWCLDB.detailAuraState)=="table" then
local state=NoWCLDB.detailAuraState
_zhsxohecfm.RestoreActiveAuras((not state.savedAt or time()-state.savedAt<=900) and state.auras or nil)
end
if NoWCLDB and type(NoWCLDB.segments) == "table" then
self.history = NoWCLDB.segments
for _, seg in ipairs(self.history) do sanitizeStoredSegment(seg) end
end
if NoWCLDB and type(NoWCLDB.spellInfo) == "table" then
self.spellInfo = NoWCLDB.spellInfo
end
if NoWCLDB and type(NoWCLDB.currentSegment) == "table" then
self.lastCurrentSegment = NoWCLDB.currentSegment
sanitizeStoredSegment(self.lastCurrentSegment)
if self.lastCurrentSegment.name == "战斗"
and not self.lastCurrentSegment.isBoss and not self.lastCurrentSegment.isDummy then
local hasDamage = false
for _, player in pairs(self.lastCurrentSegment.players or {}) do
if _mgrddkckpb.N(player.dmg) > 0 then hasDamage = true; break end
end
if not hasDamage then
self.lastCurrentSegment = nil
NoWCLDB.currentSegment = nil
end
end
elseif NoWCLDB and type(NoWCLDB.lastSegment) == "table" then
self.lastCurrentSegment = {
name = NoWCLDB.lastSegment.encounter,
dur = NoWCLDB.lastSegment.dur,
players = NoWCLDB.lastSegment.players or {},
}
sanitizeStoredSegment(self.lastCurrentSegment)
end
local draft = NoWCLDB and NoWCLDB.activeSegment
if type(draft) == "table" then sanitizeStoredSegment(draft.segment) end
if type(draft) == "table" and type(draft.segment) == "table" and not draft.segment._ended then
local nowWall = time()
if not draft.savedAt or nowWall - draft.savedAt <= _wbhslwqcym then
local seg = draft.segment
local oldStart = seg.startTime or GetTime()
if draft.startWall then
local newStart = GetTime() - math.max(0, nowWall - draft.startWall)
local shift = newStart - oldStart
seg.startTime = newStart
if seg._bossDiedAt then seg._bossDiedAt = seg._bossDiedAt + shift end
if seg._wipeAt then seg._wipeAt = seg._wipeAt + shift end
for _, r in pairs(seg.players or {}) do
if r._lastEnd then r._lastEnd = r._lastEnd + shift end
if r._deadAt then r._deadAt = r._deadAt + shift end
end
for _, c in pairs(draft.channelStart or {}) do
if c.t then c.t = c.t + shift end
end
end
seg._restoredDraft = true
self.segment = seg
self.activeBuff = draft.activeBuff or {}
self.snapshotBuff = draft.snapshotBuff or {}
self.unholyFrenzy = draft.unholyFrenzy or {}
self.unholyFrenzyByGuid = draft.unholyFrenzyByGuid or {}
self.channelStart = draft.channelStart or {}
_lkadegdain = draft.petOwner or _lkadegdain
_gvggrzhdvg = draft.playerByGUID or _gvggrzhdvg
else
NoWCLDB.activeSegment = nil
end
end
if _zhsxohecfm and _zhsxohecfm.ClearTransientAuras and not self.segment then _zhsxohecfm.ClearTransientAuras() end
end
function _jercjlskad:ValidateRestoredActive()
local seg = self.segment
if not (seg and seg._restoredDraft) then return true end
if UnitAffectingCombat and not UnitAffectingCombat("player") then
self.segment = nil
_mmyygxzwoq(self)
resetPendingSwings()
if _zhsxohecfm and _zhsxohecfm.ClearTransientAuras then _zhsxohecfm.ClearTransientAuras() end
if NoWCLDB then NoWCLDB.activeSegment = nil end
return false
end
return true
end
function _jercjlskad:ClearHistory()
self.history = {}
self.lastCurrentSegment = nil
if self.segment and self.segment._ended then self.segment = nil end
if not (self.segment and not self.segment._ended) then resetPendingSwings() end
if NoWCLDB then
NoWCLDB.segments = self.history
NoWCLDB.lastSegment = nil
NoWCLDB.currentSegment = nil
if not (self.segment and not self.segment._ended) then
NoWCLDB.activeSegment = nil
end
end
if _zhsxohecfm and _zhsxohecfm.InvalidateStorageEstimate then _zhsxohecfm.InvalidateStorageEstimate() end
end
function _jercjlskad:GetHistory() return self.history end
function _jercjlskad:RoleOf(name)
local ov = _ysknifzsgw.db and _ysknifzsgw.db.settings.roleOverride and _ysknifzsgw.db.settings.roleOverride[name]
if ov then return ov end
local info = self.roster[name]
local ready = _ysknifzsgw.Readiness and _ysknifzsgw.Readiness.localCache and _ysknifzsgw.Readiness.localCache[name]
local specRole = _mgrddkckpb.RoleFromSpecialization((ready and ready.specId) or (info and info.specId))
if specRole then return specRole end
local r = info and info.role
if r == "TANK" or r == "HEALER" then return r end
return "DAMAGER"
end
function _jercjlskad:MergedPlayers(segList, bossCfg, includeDetails)
segList = segList or self.history
if includeDetails == nil then includeDetails = true end
local singleSegment = #segList == 1
local acc, totalDur = {}, 0
for _, seg in ipairs(segList) do
totalDur = totalDur + (seg.dur or 0)
local teamRoster, teamByName
if singleSegment and _wophgkhwrn and _wophgkhwrn.EvaluateHistory then
teamRoster, teamByName = {}, {}
for _, raw in ipairs(seg.players or {}) do
local info = self.roster[raw.name] or {}
local ready = _ysknifzsgw.Readiness and _ysknifzsgw.Readiness.localCache
and _ysknifzsgw.Readiness.localCache[raw.name]
local specId = raw.specId or raw.readySpecId or (ready and ready.specId)
local class = raw.class or info.class
or (_mgrddkckpb.ClassFromSpecialization and _mgrddkckpb.ClassFromSpecialization(specId))
local enriched = {
name=raw.name, class=class, role=raw.role or info.role,
specId=specId, auraBuffs=raw.auraBuffs,
}
teamRoster[#teamRoster + 1] = enriched
teamByName[raw.name] = enriched
end
end
for _, p in ipairs(seg.players or {}) do
local a = acc[p.name]
if not a then a = { name=p.name, class=p.class, role=p.role,
dmg=0, dmgBoss=0, heal=0, alignedDmg=0, interrupts=0, dispels=0,
deaths=0, sunderApplied=0, activeMs=0, actions=0, deadSec=0, _segs=0,
selfActiveMs=0, selfCombatMs=0,
extraTasks={} }
if includeDetails then
a.spells={}; a.heals={}; a.targets={}; a.targetsBoss={}; a.healTargets={}
a.spellStats={}; a.healStats={}; a.castStats={}; a.castTargetStats={}
a.spellTargetStats={}; a.auraBuffs={}; a.auraDebuffs={}
end
if singleSegment and _zhsxohecfm and _zhsxohecfm.ConsumableSummary then
a.consumables = _zhsxohecfm.ConsumableSummary(p)
end
if singleSegment and _wophgkhwrn and _wophgkhwrn.EvaluateHistory then
local teamPlayer = teamByName and teamByName[p.name] or p
a.teamBuff = _wophgkhwrn:EvaluateHistory(teamPlayer, teamRoster or seg.players, seg.dur)
end
acc[p.name]=a
end
a.dmg=a.dmg+(p.dmg or 0); a.dmgBoss=a.dmgBoss+(p.dmgBoss or 0)
a.heal=a.heal+((_mgrddkckpb.HealingAmount and _mgrddkckpb.HealingAmount(p)) or (p.heal or 0)); a.alignedDmg=a.alignedDmg+(p.alignedDmg or 0)
a.interrupts=a.interrupts+(p.interrupts or 0); a.dispels=a.dispels+(p.dispels or 0)
a.deaths=a.deaths+(p.deaths or 0); a.sunderApplied=a.sunderApplied+(p.sunderApplied or 0)
_mgrddkckpb.MergeExtraTasks(a.extraTasks, p.extraTasks, p.class)
a.activeMs=a.activeMs+(p.activeMs or 0)
a.selfActiveMs=a.selfActiveMs+(p.selfActiveMs or 0); a.selfCombatMs=a.selfCombatMs+(p.selfCombatMs or 0)
if p.synced then a.synced = true end
a.actions=a.actions+(p.actions or 0); a.deadSec=a.deadSec+(p.deadSec or 0); a._segs=a._segs+1
if a._segs==1 then
a.iv=p.iv; a.ivDur=p.ivDur or p.fightDur; a.deathTimes=p.deathTimes; a.deathDetails=p.deathDetails
a.timelineBucket=p.timelineBucket; a.damageBuckets=p.damageBuckets
a.bossDamageBuckets=p.bossDamageBuckets; a.healingBuckets=p.healingBuckets
a.scopeTimeline=p.scopeTimeline
a.specId=p.specId; a.readySpecId=p.readySpecId
elseif a.specId~=p.specId or a.readySpecId~=p.readySpecId then
a.specId=nil; a.readySpecId=nil
end
if a._segs==1 then
a.readyIlvl=p.readyIlvl;a.readyLowQuality=p.readyLowQuality
a.readyMissEnch=p.readyMissEnch;a.readyEmptyGems=p.readyEmptyGems;a.readyGearKey=p.readyGearKey
end
if includeDetails then
for sn,v in pairs(p.spells or {}) do a.spells[sn]=(a.spells[sn] or 0)+v end
for sn,v in pairs(p.heals or {}) do a.heals[sn]=(a.heals[sn] or 0)+v end
for tn,v in pairs(p.targets or {}) do a.targets[tn]=(a.targets[tn] or 0)+v end
for tn,v in pairs(p.healTargets or {}) do a.healTargets[tn]=(a.healTargets[tn] or 0)+v end
for tn in pairs(p.targetsBoss or {}) do a.targetsBoss[tn]=true end
if _zhsxohecfm then _zhsxohecfm.MergePlayerDetails(a, p, seg.name, bossCfg) end
end
end
end
if totalDur < 1 then totalDur = 1 end
local out = {}
for _, a in pairs(acc) do
a.dps = a.dmg/totalDur; a.bossDps = a.dmgBoss/totalDur; a.alignedDps = a.alignedDmg/totalDur
a.activePct = math.min(1, (a.activeMs/1000)/totalDur)
a.extraTasks = _mgrddkckpb.CopyExtraTasks(a.extraTasks, a.class)
a.fightDur = totalDur
if a._segs ~= 1 then
a.iv = nil; a.ivDur = nil; a.deathTimes = nil; a.deathDetails = nil
a.timelineBucket=nil; a.damageBuckets=nil; a.bossDamageBuckets=nil; a.healingBuckets=nil; a.scopeTimeline=nil
a.readyIlvl=nil;a.readyLowQuality=nil;a.readyMissEnch=nil;a.readyEmptyGems=nil;a.readyGearKey=nil
end
out[#out+1] = a
end
return out, totalDur
end
function _jercjlskad:ViewPlayers(sel)
if sel == "merged" then
local p, d = self:MergedPlayers(); return p, d, "合并全部("..#self.history.."场)"
elseif type(sel) == "number" and self.history[sel] then
local h = self.history[sel]; return h.players, h.dur, h.name
else
if self:IsCurrentSegmentVisible() then
local p,d = self:GetDisplayPlayers(); return p, d, self.segment.name.."(战斗中)"
elseif self.lastCurrentSegment then
local h = self.lastCurrentSegment
return h.players, h.dur, h.name
elseif self.history[1] then
local h=self.history[1]; return h.players, h.dur, h.name
else
return {}, 0, "(无数据)"
end
end
end
do local _9dpimbi3j="4c43576f4e";local _agp7pcjti="6636633930663938316161653431363638383038" end
