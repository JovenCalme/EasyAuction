local _izcxfucxwe, _lvuoojcdav = ...
if not (_lvuoojcdav and _lvuoojcdav.Stats) then
if _lvuoojcdav then _lvuoojcdav.ParserUnavailable = true end
return
end
local _lihsplnifh = 5
local _eigcvacujp = 1
local _pgrwdxaclo = 2
local _dhttjtkebw = 0
local _xbbzwsttfc = 0
local _nppqlagcoo = 0
local _dedhdoyvsk = 0
local _jliuycbrmn = 3
local _urkzsapemg = 5
local schedulePostEncounterClear
local _yuhiuyvwby = {
SPELL_DAMAGE=true, SPELL_PERIODIC_DAMAGE=true, RANGE_DAMAGE=true,
DAMAGE_SHIELD=true, SWING_DAMAGE=true, SPELL_BUILDING_DAMAGE=true,
SPELL_MISSED=true, SPELL_PERIODIC_MISSED=true, RANGE_MISSED=true,
DAMAGE_SHIELD_MISSED=true, SWING_MISSED=true,
}
local function _jywxqnqtwu(endTime)
local seg = _lvuoojcdav.Stats.segment
if not seg or seg._ended then return end
local endedBoss = seg.isBoss and true or false
_lvuoojcdav.Stats:OnCombatEnd(endTime)
if _lvuoojcdav.Sync then _lvuoojcdav.Sync:OnSegmentEnd() end
if _lvuoojcdav.TeamAnnouncements and _lvuoojcdav.TeamAnnouncements.OnSegmentEnd then
_lvuoojcdav.TeamAnnouncements:OnSegmentEnd(seg)
end
if endedBoss and schedulePostEncounterClear then schedulePostEncounterClear() end
end
local function _mtugmbyyeb()
_xbbzwsttfc = _xbbzwsttfc + 1
local seg = _lvuoojcdav.Stats and _lvuoojcdav.Stats.segment
if seg then seg._passiveWatchToken = nil end
end
local function _mtmbheomwn()
_nppqlagcoo = _nppqlagcoo + 1
local seg = _lvuoojcdav.Stats and _lvuoojcdav.Stats.segment
if seg then seg._dummyWatchToken = nil end
end
local function _sslxeecook(endAt)
if _lvuoojcdav.Stats and _lvuoojcdav.Stats.FreezeCurrentDisplay then
_lvuoojcdav.Stats:FreezeCurrentDisplay(endAt)
end
end
local function _szgmlhwgrf()
if not UnitIsDeadOrGhost then return false end
local checked = 0
local function alive(unit)
if UnitExists and not UnitExists(unit) then return false end
checked = checked + 1
if UnitIsConnected and UnitIsConnected(unit) == false then return false end
return not UnitIsDeadOrGhost(unit)
end
if IsInRaid and IsInRaid() then
local n = GetNumGroupMembers and (GetNumGroupMembers() or 0) or 0
for i = 1, n do if alive("raid"..i) then return false end end
elseif IsInGroup and IsInGroup() then
if alive("player") then return false end
local n = GetNumGroupMembers and (GetNumGroupMembers() or 0) or 0
for i = 1, n do if alive("party"..i) then return false end end
else
if alive("player") then return false end
end
return checked > 0
end
local function _lshrejehsr(unit)
if UnitExists and not UnitExists(unit) then return false end
if UnitIsConnected and UnitIsConnected(unit) == false then return false end
return UnitAffectingCombat and UnitAffectingCombat(unit) and true or false
end
local function _fbokeuvyha()
if IsInRaid and IsInRaid() then
local n = GetNumGroupMembers and (GetNumGroupMembers() or 0) or 0
for i = 1, n do if _lshrejehsr("raid"..i) then return true end end
return false
end
if _lshrejehsr("player") then return true end
if IsInGroup and IsInGroup() then
local n = GetNumSubgroupMembers and (GetNumSubgroupMembers() or 0)
or math.max(0, (GetNumGroupMembers and (GetNumGroupMembers() or 0) or 0) - 1)
for i = 1, n do if _lshrejehsr("party"..i) then return true end end
end
return false
end
local function _oudolajpdh()
return IsEncounterInProgress and IsEncounterInProgress() and true or false
end
local function _okonpirvvi()
_dedhdoyvsk = _dedhdoyvsk + 1
end
schedulePostEncounterClear = function()
if not (_lvuoojcdav.Stats and _lvuoojcdav.Stats.IsPostEncounterFenced
and _lvuoojcdav.Stats:IsPostEncounterFenced()) then return false end
_okonpirvvi()
local tok = _dedhdoyvsk
local stableAt
local function check()
if tok ~= _dedhdoyvsk then return end
if not (_lvuoojcdav.Stats and _lvuoojcdav.Stats.IsPostEncounterFenced
and _lvuoojcdav.Stats:IsPostEncounterFenced()) then return end
if _oudolajpdh() or _fbokeuvyha() then
stableAt = nil
else
stableAt = stableAt or GetTime()
if GetTime() - stableAt >= _pgrwdxaclo then
_lvuoojcdav.Stats:ReleasePostEncounterFence()
return
end
end
if C_Timer and C_Timer.After then
C_Timer.After(_eigcvacujp, check)
elseif stableAt then
_lvuoojcdav.Stats:ReleasePostEncounterFence()
end
end
check()
return true
end
local function _urbtldlnde(seg, token)
if not (seg and seg._endingReason == "group_regen") then return end
if token and seg._groupRegenBoundaryToken ~= token then return end
local endAt = seg._endingAt
if _lvuoojcdav.Stats and _lvuoojcdav.Stats.ClearCurrentDisplayFreeze then
_lvuoojcdav.Stats:ClearCurrentDisplayFreeze(endAt)
else
seg._endingAt = nil
seg._displayPlayers = nil
seg._displayDur = nil
seg._displayEndAt = nil
end
seg._endingReason = nil
seg._groupRegenSafeAt = nil
seg._groupRegenBoundaryToken = nil
end
local function _qjcvwcsbqt()
local seg = _lvuoojcdav.Stats and _lvuoojcdav.Stats.segment
if not (seg and seg.isBoss and not seg._ended and _szgmlhwgrf()) then return false end
_dhttjtkebw = _dhttjtkebw + 1
local tok = _dhttjtkebw
local endAt = seg._wipeAt or GetTime()
seg._wipeDetected = true
seg._wipeAt = endAt
seg._endingAt = endAt
seg._endingReason = "wipe"
_sslxeecook(endAt)
local function fin()
local s = _lvuoojcdav.Stats and _lvuoojcdav.Stats.segment
if tok ~= _dhttjtkebw or not (s and s.isBoss and not s._ended) then return end
if _szgmlhwgrf() then
_jywxqnqtwu(endAt)
elseif s._wipeAt == endAt then
s._wipeDetected = nil
s._wipeAt = nil
if _lvuoojcdav.Stats.ClearCurrentDisplayFreeze then
_lvuoojcdav.Stats:ClearCurrentDisplayFreeze(endAt)
end
end
end
if C_Timer and C_Timer.After then C_Timer.After(_jliuycbrmn, fin) else fin() end
return true
end
local function _mljdlfingg()
local seg = _lvuoojcdav.Stats and _lvuoojcdav.Stats.segment
local deathFinishes = seg and (seg._observedBoss or seg._finishOnBossDeath)
if not (seg and seg.isBoss and deathFinishes and not seg._ended and seg._bossDied) then return false end
_dhttjtkebw = _dhttjtkebw + 1
local tok = _dhttjtkebw
local endAt = seg._bossDiedAt or GetTime()
seg._endingAt = endAt
seg._endingReason = "boss_death"
_sslxeecook(endAt)
local function fin()
local s = _lvuoojcdav.Stats and _lvuoojcdav.Stats.segment
local stillFinishes = s and (s._observedBoss or s._finishOnBossDeath)
if tok == _dhttjtkebw and s and s.isBoss and stillFinishes and not s._ended and s._bossDied then _jywxqnqtwu(endAt) end
end
if C_Timer and C_Timer.After then C_Timer.After(_urkzsapemg, fin) else fin() end
return true
end
local function _fbkcwapwzd(freezeDisplay)
_mtugmbyyeb()
_mtmbheomwn()
_dhttjtkebw = _dhttjtkebw + 1
local tok = _dhttjtkebw
local endAt = GetTime()
local seg = _lvuoojcdav.Stats and _lvuoojcdav.Stats.segment
if seg and not seg._ended then
seg._endingAt = endAt
seg._endingReason = "player_regen"
end
if freezeDisplay then _sslxeecook(endAt) end
if C_Timer and C_Timer.After then
C_Timer.After(_lihsplnifh, function() if tok == _dhttjtkebw then _jywxqnqtwu(endAt) end end)
else
_jywxqnqtwu(endAt)
end
end
local function _exqbhyzwxt()
local seg = _lvuoojcdav.Stats and _lvuoojcdav.Stats.segment
if not (seg and seg.isBoss and not seg._ended) then return false end
if seg._bossRegenWatchToken then return true end
_dhttjtkebw = _dhttjtkebw + 1
local tok = _dhttjtkebw
local expected = seg
expected._bossRegenWatchToken = tok
local function check()
local current = _lvuoojcdav.Stats and _lvuoojcdav.Stats.segment
if tok ~= _dhttjtkebw or current ~= expected or current._ended then
if expected._bossRegenWatchToken == tok then expected._bossRegenWatchToken = nil end
_urbtldlnde(expected, tok)
return
end
if _oudolajpdh() or _fbokeuvyha() then
_urbtldlnde(expected, tok)
if C_Timer and C_Timer.After then
C_Timer.After(_eigcvacujp, check)
else
expected._bossRegenWatchToken = nil
end
return
end
local safeAt = expected._groupRegenSafeAt
if not safeAt then
safeAt = GetTime()
expected._groupRegenSafeAt = safeAt
expected._groupRegenBoundaryToken = tok
expected._endingAt = safeAt
expected._endingReason = "group_regen"
_sslxeecook(safeAt)
end
local remaining = _lihsplnifh - math.max(0, GetTime() - safeAt)
if remaining > 0 and C_Timer and C_Timer.After then
C_Timer.After(math.min(_eigcvacujp, remaining), check)
return
end
expected._bossRegenWatchToken = nil
_jywxqnqtwu(safeAt)
end
check()
return true
end
local function _xyzozcxgyy(handled, sub)
if not handled or not _yuhiuyvwby[sub] then return end
local seg = _lvuoojcdav.Stats and _lvuoojcdav.Stats.segment
if not (seg and seg._passiveObserved and not seg.isBoss and not seg.isDummy and not seg._ended) then return end
seg._passiveLastAt = GetTime()
if seg._passiveWatchToken then return end
_xbbzwsttfc = _xbbzwsttfc + 1
local tok = _xbbzwsttfc
local expected = seg
expected._passiveWatchToken = tok
if C_Timer and C_Timer.After then
local function check()
local current = _lvuoojcdav.Stats and _lvuoojcdav.Stats.segment
if tok ~= _xbbzwsttfc or current ~= expected or not current._passiveObserved
or current._ended then
if expected._passiveWatchToken == tok then expected._passiveWatchToken = nil end
return
end
local lastAt = tonumber(current._passiveLastAt) or GetTime()
local remaining = _lihsplnifh - math.max(0, GetTime() - lastAt)
if remaining > 0 then
C_Timer.After(math.max(0.1, remaining), check)
else
current._passiveWatchToken = nil
_jywxqnqtwu(lastAt)
end
end
C_Timer.After(_lihsplnifh, check)
end
end
local function _fjedecllnd(seg)
seg = seg or (_lvuoojcdav.Stats and _lvuoojcdav.Stats.segment)
if not (seg and seg._observed and seg.isDummy and not seg._ended) or seg._endingAt then return end
seg._dummyLastAt = GetTime()
if seg._dummyWatchToken then return end
_nppqlagcoo = _nppqlagcoo + 1
local tok = _nppqlagcoo
local expected = seg
expected._dummyWatchToken = tok
if not (C_Timer and C_Timer.After) then
expected._dummyWatchToken = nil
_jywxqnqtwu(expected._dummyLastAt)
return
end
local function check()
local current = _lvuoojcdav.Stats and _lvuoojcdav.Stats.segment
if tok ~= _nppqlagcoo or current ~= expected or current._ended or current._endingAt then
if expected._dummyWatchToken == tok then expected._dummyWatchToken = nil end
return
end
if current._playerCombat and UnitAffectingCombat and UnitAffectingCombat("player") then
current._dummyWatchToken = nil
return
end
local lastAt = tonumber(current._dummyLastAt) or GetTime()
local remaining = _lihsplnifh - math.max(0, GetTime() - lastAt)
if remaining > 0 then
C_Timer.After(math.max(0.1, remaining), check)
else
current._dummyWatchToken = nil
_jywxqnqtwu(lastAt)
end
end
C_Timer.After(_lihsplnifh, check)
end
local function _rominntnvu(e, handled)
if not handled then return end
local seg = _lvuoojcdav.Stats and _lvuoojcdav.Stats.segment
if not (seg and seg._observed and seg.isDummy and not seg._ended) or seg._endingAt then return end
if _lvuoojcdav.Util and _lvuoojcdav.Util.IsTrainingDummy and _lvuoojcdav.Util.IsTrainingDummy(e and e[9]) then
_fjedecllnd(seg)
end
end
local _lsxftbvhfw = CreateFrame("Frame")
_lsxftbvhfw:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
_lsxftbvhfw:RegisterEvent("ENCOUNTER_START")
_lsxftbvhfw:RegisterEvent("ENCOUNTER_END")
_lsxftbvhfw:RegisterEvent("PLAYER_REGEN_DISABLED")
_lsxftbvhfw:RegisterEvent("PLAYER_REGEN_ENABLED")
_lsxftbvhfw:RegisterEvent("PLAYER_DEAD")
_lsxftbvhfw:RegisterEvent("UNIT_HEALTH")
_lsxftbvhfw:RegisterEvent("GROUP_ROSTER_UPDATE")
_lsxftbvhfw:RegisterEvent("UNIT_PET")
_lsxftbvhfw:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
_lsxftbvhfw:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
local function _elzcscqotz(u)
return u == "player" or (type(u)=="string" and (u:match("^raid%d+$") or u:match("^party%d+$"))) ~= nil
end
local _jxvvokdjpe = 0
_lsxftbvhfw:SetScript("OnUpdate", function(_, elapsed)
_jxvvokdjpe = _jxvvokdjpe + (tonumber(elapsed) or 0)
if _jxvvokdjpe < 0.2 then return end
_jxvvokdjpe = 0
local flushed = _lvuoojcdav.Stats.FlushPendingSwings
and _lvuoojcdav.Stats:FlushPendingSwings(GetTime(), false) or 0
local seg = _lvuoojcdav.Stats.segment
if flushed > 0 and seg and not seg._ended and not seg._endingAt then
if seg._observed and seg.isDummy then
_fjedecllnd(seg)
elseif seg._passiveObserved and not seg.isBoss then
_xyzozcxgyy(true, "SWING_DAMAGE")
end
end
end)
_lsxftbvhfw:SetScript("OnEvent", function(self, event, ...)
if event == "COMBAT_LOG_EVENT_UNFILTERED" then
local n = select("#", CombatLogGetCurrentEventInfo())
local e = { CombatLogGetCurrentEventInfo() }
local handled = _lvuoojcdav.Stats:HandleCLEU(e, n)
_rominntnvu(e, handled)
_mljdlfingg()
_xyzozcxgyy(handled, e[2])
elseif event == "ENCOUNTER_START" then
_dhttjtkebw = _dhttjtkebw + 1
_mtugmbyyeb()
_mtmbheomwn()
_okonpirvvi()
if _lvuoojcdav.Stats.CancelPendingCombatEnd then _lvuoojcdav.Stats:CancelPendingCombatEnd() end
local encounterID, encounterName = ...
if _lvuoojcdav.Stats.FlushPendingSwings then _lvuoojcdav.Stats:FlushPendingSwings(GetTime(), true) end
_lvuoojcdav.Stats:OnCombatStart(true, encounterName or ("首领#"..tostring(encounterID)))
local announcementSegment = _lvuoojcdav.Stats and _lvuoojcdav.Stats.segment
if announcementSegment then
announcementSegment._announcementKey = tostring(encounterID or encounterName or "Boss")
.. ":" .. tostring(time())
end
if _lvuoojcdav.ExtensionAPI then
_lvuoojcdav.ExtensionAPI:Publish("ENCOUNTER_START", {
encounterId = tonumber(encounterID), encounterName = encounterName,
startedAt = GetTime(), roster = _lvuoojcdav.ExtensionAPI:GetRosterSnapshot(),
})
end
_lvuoojcdav:Print("进入首领战: " .. tostring(encounterName))
elseif event == "ENCOUNTER_END" then
_dhttjtkebw = _dhttjtkebw + 1
_mtugmbyyeb()
_mtmbheomwn()
local encounterID, encounterName, difficultyID, groupSize, success = ...
local seg = _lvuoojcdav.Stats and _lvuoojcdav.Stats.segment
if seg then
seg._encounterSuccess = tonumber(success) == 1
if seg._encounterSuccess then seg._bossDied = true; seg._bossDiedAt = GetTime() end
end
_jywxqnqtwu()
if _lvuoojcdav.ExtensionAPI then
_lvuoojcdav.ExtensionAPI:Publish("ENCOUNTER_END", {
encounterId = tonumber(encounterID), encounterName = encounterName,
difficultyId = tonumber(difficultyID), groupSize = tonumber(groupSize),
success = tonumber(success) == 1, endedAt = GetTime(),
})
end
elseif event == "PLAYER_REGEN_DISABLED" then
_dhttjtkebw = _dhttjtkebw + 1
_mtugmbyyeb()
_mtmbheomwn()
if _lvuoojcdav.Stats.OnPlayerCombatStart then
_lvuoojcdav.Stats:OnPlayerCombatStart()
else
local seg = _lvuoojcdav.Stats.segment
if not seg or seg._ended then _lvuoojcdav.Stats:OnCombatStart(false, "战斗") end
end
elseif event == "PLAYER_REGEN_ENABLED" then
_mtugmbyyeb()
local seg = _lvuoojcdav.Stats.segment
if seg and seg.isBoss and not seg._ended then
if not _qjcvwcsbqt() then _exqbhyzwxt() end
return
end
_fbkcwapwzd(true)
elseif event == "PLAYER_DEAD" or event == "UNIT_HEALTH" then
_qjcvwcsbqt()
elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
local unit = ...
if _elzcscqotz(unit) then _lvuoojcdav.Stats:OnChannelStart(UnitName(unit), UnitGUID(unit)) end
elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
local unit = ...
if _elzcscqotz(unit) then _lvuoojcdav.Stats:OnChannelStop(UnitName(unit)) end
elseif event == "GROUP_ROSTER_UPDATE" then
if _lvuoojcdav.ConsumableCheck then _lvuoojcdav.ConsumableCheck.snapshot = nil end
_lvuoojcdav.Stats:UpdateRoster()
if _lvuoojcdav.Sync and _lvuoojcdav.Sync.OnRosterUpdate then _lvuoojcdav.Sync:OnRosterUpdate() end
if _lvuoojcdav.Readiness and _lvuoojcdav.Readiness.RequestRosterScan then _lvuoojcdav.Readiness:RequestRosterScan() end
if _lvuoojcdav.ExtensionAPI then
_lvuoojcdav.ExtensionAPI:Publish("ROSTER_UPDATED", _lvuoojcdav.ExtensionAPI:GetRosterSnapshot())
end
if _lvuoojcdav.AuditUI and _lvuoojcdav.AuditUI.Refresh then _lvuoojcdav.AuditUI:Refresh() end
elseif event == "UNIT_PET" then
local unit = ...
if _elzcscqotz(unit) and _lvuoojcdav.Stats.RefreshUnitPet then _lvuoojcdav.Stats:RefreshUnitPet(unit) end
end
end)
_lvuoojcdav.Parser = _lsxftbvhfw
