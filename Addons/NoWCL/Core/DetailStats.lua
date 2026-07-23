local _zoceomicrv, _kxpvlorvyd = ...
local _pedvqgaynb = {}
_kxpvlorvyd.DetailStats = _pedvqgaynb
local _croxpxzhvp = _kxpvlorvyd.Util
local _bmmxlhdltn, _zwhqhqynuz, _ebdaujxmqn, _tpcpxfwvms, _yzrelbxytq = 1, 2, 3, 4, 5
local _dpndqhsgdg, _rhikelwfbe = 6, 7
local _wpmdockvti, _nympogznaa, _mwwswrhosr, _umyqoczrvh = 8, 9, 10, 11
local _xoziqcutre, _xcjelqcurg, _kahgzsdisa, _tvoqfecdwa = 12, 13, 14, 15
local _owfdghrrng, _bkzrcpmzxx = 1, 2
local _fcprludhcd = "\001"
_pedvqgaynb.SPELL = {
SID=_bmmxlhdltn, SCHOOL=_zwhqhqynuz, TOTAL=_ebdaujxmqn, HITS=_tpcpxfwvms, CRITS=_yzrelbxytq,
NORMAL_TOTAL=_dpndqhsgdg, CRIT_TOTAL=_rhikelwfbe,
NORMAL_MIN=_wpmdockvti, NORMAL_MAX=_nympogznaa,
CRIT_MIN=_mwwswrhosr, CRIT_MAX=_umyqoczrvh,
ABSORBED=_xoziqcutre, MISSES=_xcjelqcurg, ALIGNED=_kahgzsdisa, TARGET_NAME=_tvoqfecdwa,
}
local _krujdxjler, _udlelxjxou, _gnjvrkwouw, _oicguashfp = 1, 2, 3, 4
local _wiuwcuifoz, _vnfklxhfld, _ihmoibjiek, _gpliwnlpos, _brbfcsxnuj = 5, 6, 7, 8, 9
local _jabmlggvyd, _bztwsdekym = 10, 11
local _ltkebfoxoq, _czdsukzjku, _qvqaaeiypi = 12, 13, 14
local _tuzfsqpdda, _odgedsrocx = 1000, 10
local _ehnfousucc = {
57399, 57367, 57294, 57365, 57360, 57358, 57356, 57334, 57332, 57329,
57327, 57325, 57291, 57288, 57286, 57139, 57111, 57371, 57079, 57097,
57100, 57102, 53284, 57107,
}
local _kaxjrmtwpz = { 53755, 53758, 53760, 54212, 53752, 62380, 67016, 67017, 67018, 67019 }
local _rgjagdbkih = { 53749 }
local _nbmmqrjlff = { 53746, 53748, 60340, 60341, 60344, 60345, 60346, 63729, 28497, 33721 }
local _hcwvujvtpu = { 53747, 53751, 53763, 53764, 60343, 60347 }
local _iivlizyhak = { 53908, 53909 }
local _xgtylqdaai = { 55637, 55767, 55775 }
local function _dmsqbblthz(list)
local out = {}
for _, spellId in ipairs(list) do out[spellId] = true end
return out
end
local _pszxhovpws = _dmsqbblthz(_ehnfousucc)
local _jgjuffkgdj = _dmsqbblthz(_kaxjrmtwpz)
local _dkzpetdglo = _dmsqbblthz(_rgjagdbkih)
local _bxomcxkzwi = _dmsqbblthz(_nbmmqrjlff)
local _hvrapeioar = _dmsqbblthz(_hcwvujvtpu)
local _znxjxyndyr = _dmsqbblthz(_iivlizyhak)
local _ixlvnesiog = _dmsqbblthz(_xgtylqdaai)
local _nnaplyhigm = {}
for _, set in ipairs({ _pszxhovpws, _jgjuffkgdj, _dkzpetdglo,
_bxomcxkzwi, _hvrapeioar, _znxjxyndyr, _ixlvnesiog }) do
for spellId in pairs(set) do _nnaplyhigm[spellId] = true end
end
local _uyukpuwipw = setmetatable({}, { __mode = "k" })
local function _phhmpozmdr(v) return tonumber(v) or 0 end
function _pedvqgaynb.Flag(v)
return v == true or v == 1 or v == "1" or v == "true"
end
local function _ikyzjkqtrd(old, value)
value = _phhmpozmdr(value)
if value <= 0 then return _phhmpozmdr(old) end
if _phhmpozmdr(old) <= 0 or value < old then return value end
return old
end
local _vfqwcuiopj = setmetatable({}, { __mode = "k" })
local function _yruonnyuns(key, spellId)
key = tostring(key or "?")
local display, suffix = key:match("^(.*)" .. _fcprludhcd .. "(%d+)$")
if display and _phhmpozmdr(suffix) > 0 and (_phhmpozmdr(spellId) <= 0 or _phhmpozmdr(suffix) == _phhmpozmdr(spellId)) then
return display
end
return key
end
local function _qnfzdunyyq(display, spellId)
spellId = _phhmpozmdr(spellId)
if spellId <= 0 then return tostring(display or "?") end
return _yruonnyuns(display, spellId) .. _fcprludhcd .. tostring(spellId)
end
local function _nveanqzvxa(dst, src)
if not dst then return src end
if _phhmpozmdr(dst[_bmmxlhdltn]) <= 0 and _phhmpozmdr(src[_bmmxlhdltn]) > 0 then dst[_bmmxlhdltn] = _phhmpozmdr(src[_bmmxlhdltn]) end
if _phhmpozmdr(dst[_zwhqhqynuz]) <= 0 and _phhmpozmdr(src[_zwhqhqynuz]) > 0 then dst[_zwhqhqynuz] = _phhmpozmdr(src[_zwhqhqynuz]) end
dst[_ebdaujxmqn] = _phhmpozmdr(dst[_ebdaujxmqn]) + _phhmpozmdr(src[_ebdaujxmqn])
dst[_tpcpxfwvms] = _phhmpozmdr(dst[_tpcpxfwvms]) + _phhmpozmdr(src[_tpcpxfwvms])
dst[_yzrelbxytq] = _phhmpozmdr(dst[_yzrelbxytq]) + _phhmpozmdr(src[_yzrelbxytq])
dst[_dpndqhsgdg] = _phhmpozmdr(dst[_dpndqhsgdg]) + _phhmpozmdr(src[_dpndqhsgdg])
dst[_rhikelwfbe] = _phhmpozmdr(dst[_rhikelwfbe]) + _phhmpozmdr(src[_rhikelwfbe])
dst[_wpmdockvti] = _ikyzjkqtrd(dst[_wpmdockvti], src[_wpmdockvti])
dst[_nympogznaa] = math.max(_phhmpozmdr(dst[_nympogznaa]), _phhmpozmdr(src[_nympogznaa]))
dst[_mwwswrhosr] = _ikyzjkqtrd(dst[_mwwswrhosr], src[_mwwswrhosr])
dst[_umyqoczrvh] = math.max(_phhmpozmdr(dst[_umyqoczrvh]), _phhmpozmdr(src[_umyqoczrvh]))
dst[_xoziqcutre] = _phhmpozmdr(dst[_xoziqcutre]) + _phhmpozmdr(src[_xoziqcutre])
dst[_xcjelqcurg] = _phhmpozmdr(dst[_xcjelqcurg]) + _phhmpozmdr(src[_xcjelqcurg])
dst[_kahgzsdisa] = _phhmpozmdr(dst[_kahgzsdisa]) + _phhmpozmdr(src[_kahgzsdisa])
if (not dst[_tvoqfecdwa] or dst[_tvoqfecdwa] == "") and src[_tvoqfecdwa] then
dst[_tvoqfecdwa] = src[_tvoqfecdwa]
end
return dst
end
local function _tocfdlpfml(dst, src)
if not dst then return src end
if _phhmpozmdr(dst[1]) <= 0 and _phhmpozmdr(src[1]) > 0 then dst[1] = _phhmpozmdr(src[1]) end
if _phhmpozmdr(dst[2]) <= 0 and _phhmpozmdr(src[2]) > 0 then dst[2] = _phhmpozmdr(src[2]) end
dst[3] = _phhmpozmdr(dst[3]) + _phhmpozmdr(src[3])
return dst
end
local function _zyzyjoqrbj(dst, src)
dst = dst or {}
for npcId, row in pairs(src or {}) do
dst[npcId] = _nveanqzvxa(dst[npcId], row)
end
return dst
end
local function _qwfkcnkbpf(dst, src)
dst = dst or {}
for npcId, value in pairs(src or {}) do
local row = dst[npcId]
if not row then
dst[npcId] = value
else
row[_owfdghrrng] = _phhmpozmdr(row[_owfdghrrng]) + _phhmpozmdr(value[_owfdghrrng])
if (not row[_bkzrcpmzxx] or row[_bkzrcpmzxx] == "")
and value[_bkzrcpmzxx] then
row[_bkzrcpmzxx] = value[_bkzrcpmzxx]
end
end
end
return dst
end
local function _blxplncbgo(map, oldKey, newKey, merge)
if type(map) ~= "table" or oldKey == newKey or map[oldKey] == nil then return end
local value = map[oldKey]
map[oldKey] = nil
map[newKey] = merge(map[newKey], value)
end
local function _qdhcgjoezz(rec, display)
local function migrate(primaryField, targetField, primaryMerge, targetMerge)
local primary = rec[primaryField]
local row = type(primary) == "table" and primary[display]
local spellId = _phhmpozmdr(row and row[_bmmxlhdltn])
if spellId <= 0 then return end
local key = _qnfzdunyyq(display, spellId)
if targetField then
_blxplncbgo(rec[targetField], display, key, targetMerge)
end
_blxplncbgo(primary, display, key, primaryMerge)
end
migrate("spellStats", "spellTargetStats", _nveanqzvxa, _zyzyjoqrbj)
migrate("healStats", nil, _nveanqzvxa, nil)
migrate("castStats", "castTargetStats", _tocfdlpfml, _qwfkcnkbpf)
migrate("summarySpellStats", nil, _nveanqzvxa, nil)
migrate("summaryCastStats", nil, _tocfdlpfml, nil)
end
local _lnuzrzbgxh = {
"spellStats", "healStats", "castStats", "summarySpellStats", "summaryCastStats",
}
local function _kqmwjdlfht(rec)
local state = {}
for _, field in ipairs(_lnuzrzbgxh) do
for key, row in pairs(type(rec[field]) == "table" and rec[field] or {}) do
local spellId = _phhmpozmdr(row and row[_bmmxlhdltn])
if spellId > 0 then
local display = _yruonnyuns(key, spellId)
local entry = state[display]
if not entry then entry = { ids={}, count=0 }; state[display] = entry end
if not entry.ids[spellId] then entry.count = entry.count + 1 end
entry.ids[spellId] = key
if key ~= display then entry.encoded = true end
end
end
end
return state
end
local function _tonfzydurj(rec)
local state = _kqmwjdlfht(rec)
local migrated = false
for display, entry in pairs(state) do
if entry.count > 1 or entry.encoded then
_qdhcgjoezz(rec, display)
migrated = true
end
end
if migrated then state = _kqmwjdlfht(rec) end
_vfqwcuiopj[rec] = state
return state
end
local function _hiqekqxxly(rec, display, spellId)
display, spellId = _yruonnyuns(display, spellId), _phhmpozmdr(spellId)
if spellId <= 0 then return display end
local state = _vfqwcuiopj[rec] or _tonfzydurj(rec)
local entry = state[display]
if not entry then
state[display] = { ids={ [spellId]=display }, count=1 }
return display
end
if entry.ids[spellId] then return entry.ids[spellId] end
if entry.count > 0 then
_qdhcgjoezz(rec, display)
for id, key in pairs(entry.ids) do
if key == display then entry.ids[id] = _qnfzdunyyq(display, id) end
end
entry.encoded = true
end
local key = _qnfzdunyyq(display, spellId)
entry.ids[spellId] = key
entry.count = entry.count + 1
return key
end
local function _jkdhveqgfr(map, key, spellId, school)
map = map or {}
local row = map[key]
if not row then
row = { _phhmpozmdr(spellId), _phhmpozmdr(school), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
map[key] = row
else
if _phhmpozmdr(row[_bmmxlhdltn]) <= 0 and _phhmpozmdr(spellId) > 0 then row[_bmmxlhdltn] = _phhmpozmdr(spellId) end
if _phhmpozmdr(row[_zwhqhqynuz]) <= 0 and _phhmpozmdr(school) > 0 then row[_zwhqhqynuz] = _phhmpozmdr(school) end
end
return map, row
end
local function _ofckjpyach(row, amount, absorbed, critical, missed, aligned)
amount, absorbed = math.max(0, _phhmpozmdr(amount)), math.max(0, _phhmpozmdr(absorbed))
if missed then row[_xcjelqcurg] = _phhmpozmdr(row[_xcjelqcurg]) + 1 end
if amount <= 0 then return end
row[_ebdaujxmqn] = _phhmpozmdr(row[_ebdaujxmqn]) + amount
row[_tpcpxfwvms] = _phhmpozmdr(row[_tpcpxfwvms]) + 1
row[_xoziqcutre] = _phhmpozmdr(row[_xoziqcutre]) + absorbed
if aligned ~= nil then row[_kahgzsdisa] = _phhmpozmdr(row[_kahgzsdisa]) + math.max(0, _phhmpozmdr(aligned)) end
if critical then
row[_yzrelbxytq] = _phhmpozmdr(row[_yzrelbxytq]) + 1
row[_rhikelwfbe] = _phhmpozmdr(row[_rhikelwfbe]) + amount
row[_mwwswrhosr] = _ikyzjkqtrd(row[_mwwswrhosr], amount)
row[_umyqoczrvh] = math.max(_phhmpozmdr(row[_umyqoczrvh]), amount)
else
row[_dpndqhsgdg] = _phhmpozmdr(row[_dpndqhsgdg]) + amount
row[_wpmdockvti] = _ikyzjkqtrd(row[_wpmdockvti], amount)
row[_nympogznaa] = math.max(_phhmpozmdr(row[_nympogznaa]), amount)
end
end
function _pedvqgaynb.InitRecord(rec)
if not rec then return end
rec.spellStats = rec.spellStats or {}
rec.healStats = rec.healStats or {}
rec.castStats = rec.castStats or {}
rec.castTargetStats = rec.castTargetStats or {}
rec.spellTargetStats = rec.spellTargetStats or {}
rec.auraBuffs = rec.auraBuffs or {}
rec.auraDebuffs = rec.auraDebuffs or {}
end
local _yjqtszotad = setmetatable({}, { __mode = "k" })
local _intouwhaee = setmetatable({}, { __mode = "k" })
local _gkqwfjttgn = setmetatable({}, { __mode = "k" })
local _zvumqajvzg = 0.05
local _ihrwmefnoo = 30
local _vlqvroqour = 5
local _eevzhzlkdr = { [60053]=true }
local _wlnhakujwr = { [60052]=true, [60053]=true }
local _migfdbdxom = { [53352]=true }
local _ihudovyscj = {
[44572]=71757, [71757]=71757,
[60052]=53352, [60053]=53352, [53352]=53352,
}
function _pedvqgaynb.ShouldRecordCast(spellId)
return not _eevzhzlkdr[_phhmpozmdr(spellId)]
end
function _pedvqgaynb.ShouldRecordDamageMiss(spellId)
return not _wlnhakujwr[_phhmpozmdr(spellId)]
end
function _pedvqgaynb.NormalizeDamageCritical(spellId, critical, resisted, blocked)
if not critical then return false end
if _migfdbdxom[_phhmpozmdr(spellId)]
and _phhmpozmdr(resisted) > 0 and _phhmpozmdr(blocked) > 0 then
return false
end
return true
end
function _pedvqgaynb.EventTime(seg, runtimeTime, cleuTime)
runtimeTime = _phhmpozmdr(runtimeTime)
cleuTime = tonumber(cleuTime)
if not (seg and cleuTime) then return runtimeTime end
local state = _gkqwfjttgn[seg]
if not state then
state = { runtime=runtimeTime, cleu=cleuTime }
_gkqwfjttgn[seg] = state
return runtimeTime
end
local mapped = state.runtime + (cleuTime - state.cleu)
if math.abs(mapped - runtimeTime) > _vlqvroqour then
state.runtime, state.cleu = runtimeTime, cleuTime
return runtimeTime
end
return mapped
end
function _pedvqgaynb.RecordCast(rec, key, spellId, school, npcId, targetName, eventTime, family, targetToken)
if not (rec and key) then return end
if family and tonumber(eventTime) then
local families = _yjqtszotad[rec]
if not families then families = {}; _yjqtszotad[rec] = families end
local token = targetToken or targetName or npcId or ""
local previous = families[family]
if previous and previous.token == token
and math.abs(tonumber(eventTime) - previous.time) <= _zvumqajvzg then
return false
end
families[family] = { time = tonumber(eventTime), token = token }
end
_pedvqgaynb.InitRecord(rec)
spellId = _ihudovyscj[_phhmpozmdr(spellId)] or spellId
key = _hiqekqxxly(rec, key, spellId)
local row = rec.castStats[key]
if not row then row = { _phhmpozmdr(spellId), _phhmpozmdr(school), 0 }; rec.castStats[key] = row end
row[3] = _phhmpozmdr(row[3]) + 1
npcId = _phhmpozmdr(npcId)
if npcId > 0 then
local scope = rec.castTargetStats[key]
if not scope then scope = {}; rec.castTargetStats[key] = scope end
local target = scope[npcId]
if not target then
target = { 0, targetName or "" }
scope[npcId] = target
elseif (not target[_bkzrcpmzxx] or target[_bkzrcpmzxx] == "") and targetName then
target[_bkzrcpmzxx] = targetName
end
target[_owfdghrrng] = _phhmpozmdr(target[_owfdghrrng]) + 1
end
return true
end
local function _acjrcvopau(rec, family, eventTime)
local families = _intouwhaee[rec]
local state = families and families[family]
if not state then return nil end
local now = tonumber(eventTime)
if now and state.started and (now < state.started - _zvumqajvzg
or now - state.started > _ihrwmefnoo) then
return nil
end
return state
end
function _pedvqgaynb.BeginDerivedCastGeneration(rec, family, eventTime)
if not (rec and family) then return end
local families = _intouwhaee[rec]
if not families then families = {}; _intouwhaee[rec] = families end
families[family] = { started = tonumber(eventTime), seen = {} }
end
function _pedvqgaynb.MarkDerivedCastObserved(rec, family, childId, eventTime)
local state = _acjrcvopau(rec, family, eventTime)
if not state then return false end
state.seen[_phhmpozmdr(childId)] = true
return true
end
function _pedvqgaynb.RecordDerivedCast(rec, family, childId, key, spellId, school,
npcId, targetName, eventTime, targetToken)
local state = _acjrcvopau(rec, family, eventTime)
childId = _phhmpozmdr(childId)
if not state or state.seen[childId] then return false end
state.seen[childId] = true
return _pedvqgaynb.RecordCast(rec, key, spellId, school, npcId, targetName,
eventTime, nil, targetToken)
end
function _pedvqgaynb.RecordDamage(rec, key, spellId, school, amount, absorbed, critical,
npcId, targetName, alignedAmount, includedAmount, missed)
if not (rec and key) then return end
_pedvqgaynb.InitRecord(rec)
key = _hiqekqxxly(rec, key, spellId)
local map, row = _jkdhveqgfr(rec.spellStats, key, spellId, school)
rec.spellStats = map
_ofckjpyach(row, amount, absorbed, critical, missed, includedAmount)
npcId = _phhmpozmdr(npcId)
if npcId > 0 then
local scope = rec.spellTargetStats[key]
if not scope then scope = {}; rec.spellTargetStats[key] = scope end
local target = scope[npcId]
if not target then
target = { _phhmpozmdr(spellId), _phhmpozmdr(school), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, targetName or "" }
scope[npcId] = target
elseif (not target[_tvoqfecdwa] or target[_tvoqfecdwa] == "") and targetName then
target[_tvoqfecdwa] = targetName
end
_ofckjpyach(target, amount, absorbed, critical, missed, alignedAmount)
end
end
function _pedvqgaynb.RecordHeal(rec, key, spellId, school, effective, overheal, critical)
if not (rec and key) then return end
_pedvqgaynb.InitRecord(rec)
key = _hiqekqxxly(rec, key, spellId)
local map, row = _jkdhveqgfr(rec.healStats, key, spellId, school)
rec.healStats = map
effective, overheal = math.max(0, _phhmpozmdr(effective)), math.max(0, _phhmpozmdr(overheal))
if effective > 0 then
_ofckjpyach(row, effective, overheal, critical, false)
else
row[_tpcpxfwvms] = _phhmpozmdr(row[_tpcpxfwvms]) + 1
row[_xoziqcutre] = _phhmpozmdr(row[_xoziqcutre]) + overheal
if critical then row[_yzrelbxytq] = _phhmpozmdr(row[_yzrelbxytq]) + 1 end
end
end
local _sjtvckyjyy = {}
_pedvqgaynb.activeAuras = _sjtvckyjyy
function _pedvqgaynb.ExportActiveAuras() return _sjtvckyjyy end
function _pedvqgaynb.RestoreActiveAuras(saved)
for key in pairs(_sjtvckyjyy) do _sjtvckyjyy[key]=nil end
for key,value in pairs(type(saved)=="table" and saved or {}) do _sjtvckyjyy[key]=value end
end
local function _ubhqeozcwl(dstGUID, spellId, srcGUID)
return tostring(dstGUID or "") .. "\001" .. tostring(spellId or 0) .. "\001" .. tostring(srcGUID or "")
end
function _pedvqgaynb.TrackAuraState(sub, srcGUID, srcName, dstGUID, dstName, spellId, spellName, school, auraType, stacks)
if not (sub and sub:sub(1, 11) == "SPELL_AURA_" and dstGUID and _phhmpozmdr(spellId) > 0) then return end
local key = _ubhqeozcwl(dstGUID, spellId, srcGUID)
if sub == "SPELL_AURA_REMOVED" or sub == "SPELL_AURA_BROKEN" or sub == "SPELL_AURA_BROKEN_SPELL" then
_sjtvckyjyy[key] = nil
elseif sub == "SPELL_AURA_APPLIED" or sub == "SPELL_AURA_REFRESH"
or sub == "SPELL_AURA_APPLIED_DOSE" or sub == "SPELL_AURA_REMOVED_DOSE" then
local old = _sjtvckyjyy[key]
if sub == "SPELL_AURA_REMOVED_DOSE" and not old then return end
local stackCount = _phhmpozmdr(stacks)
if stackCount <= 0 then
if sub == "SPELL_AURA_APPLIED" then stackCount = 1
elseif sub == "SPELL_AURA_APPLIED_DOSE" then stackCount = _phhmpozmdr(old and old.stacks) + 1
else stackCount = math.max(1, _phhmpozmdr(old and old.stacks)) end
end
_sjtvckyjyy[key] = {
srcGUID=srcGUID or (old and old.srcGUID), srcName=srcName or (old and old.srcName),
dstGUID=dstGUID, dstName=dstName or (old and old.dstName),
spellId=_phhmpozmdr(spellId), spellName=spellName or (old and old.spellName),
school=_phhmpozmdr(school) > 0 and _phhmpozmdr(school) or _phhmpozmdr(old and old.school),
auraType=auraType or (old and old.auraType), stacks=stackCount,
seenAt=time and time() or 0,
}
end
end
function _pedvqgaynb.ClearTargetAuras(dstGUID, preserveBuffs)
if not dstGUID then return end
local prefix=tostring(dstGUID).."\001"
for key, aura in pairs(_sjtvckyjyy) do
if key:sub(1,#prefix)==prefix and not (preserveBuffs and aura.auraType == "BUFF") then
_sjtvckyjyy[key]=nil
end
end
end
local function _cheyjwjkqp(name)
if not name then return nil end
return name:match("^[^-]+") or name
end
local function _hobcynilmx()
local units = { "player" }
local count = GetNumGroupMembers and (GetNumGroupMembers() or 0) or 0
if IsInRaid and IsInRaid() then
units = {}
for i = 1, count do units[#units + 1] = "raid" .. i end
elseif count > 0 then
for i = 1, math.max(0, count - 1) do units[#units + 1] = "party" .. i end
end
return units
end
local function _iqabwtadim(unit)
if GetUnitName then
local fullName = GetUnitName(unit, true)
if fullName and fullName ~= "" then
return _cheyjwjkqp(fullName), tostring(fullName)
end
end
local name, realm
if UnitFullName then name, realm = UnitFullName(unit) end
if not name and UnitName then name, realm = UnitName(unit) end
if not name or name == "" then return nil, nil end
local display = _cheyjwjkqp(name)
if realm and realm ~= "" and not tostring(name):find("-", 1, true) then
return display, tostring(name) .. "-" .. tostring(realm)
end
return display, tostring(name)
end
local function _xwmnimshzl()
local labels, positions = {}, {}
if not (IsInRaid and IsInRaid()) then
labels.player = "1-1"
local count = GetNumGroupMembers and (GetNumGroupMembers() or 0) or 0
for index = 1, math.max(0, count - 1) do
labels["party" .. index] = string.format("1-%d", index + 1)
end
return labels
end
local count = GetNumGroupMembers and (GetNumGroupMembers() or 0) or 0
for raidIndex = 1, count do
local subgroup
if GetRaidRosterInfo then subgroup = select(3, GetRaidRosterInfo(raidIndex)) end
subgroup = tonumber(subgroup) or (math.floor((raidIndex - 1) / 5) + 1)
positions[subgroup] = (positions[subgroup] or 0) + 1
labels["raid" .. raidIndex] = string.format("%d-%d", subgroup, positions[subgroup])
end
return labels
end
local function _nnzzkiegyy(sourceUnit)
if not sourceUnit or sourceUnit == "" then return nil end
local ownerUnit
if sourceUnit == "pet" then
ownerUnit = "player"
else
local index = tostring(sourceUnit):match("^raidpet(%d+)$")
if index then ownerUnit = "raid" .. index end
if not ownerUnit then
index = tostring(sourceUnit):match("^partypet(%d+)$")
if index then ownerUnit = "party" .. index end
end
end
return _cheyjwjkqp(UnitName((ownerUnit or sourceUnit)))
end
local function _jnablnycme(unit)
local summary = { bursts = {} }
local tailoringSeen = {}
local auras = {}
local observedAny = false
for index = 1, 255 do
local auraName, _, _, _, _, _, sourceUnit, _, _, spellId = UnitAura(unit, index, "HELPFUL")
if not auraName then break end
observedAny = true
spellId = _phhmpozmdr(spellId)
local teamBuffs = _kxpvlorvyd.TeamBuffs
if spellId > 0 and teamBuffs and teamBuffs.IsTrackedAura
and teamBuffs:IsTrackedAura(spellId, auraName) then
auras[spellId] = {
spellId=spellId, name=auraName, sourceUnit=sourceUnit,
sourceName=_nnzzkiegyy(sourceUnit),
}
end
if _pszxhovpws[spellId] and not summary.food then summary.food = spellId end
if _jgjuffkgdj[spellId] and not summary.flask then summary.flask = spellId end
if _dkzpetdglo[spellId] and not summary.combined then summary.combined = spellId end
if _bxomcxkzwi[spellId] and not summary.battle then summary.battle = spellId end
if _hvrapeioar[spellId] and not summary.guardian then summary.guardian = spellId end
if _znxjxyndyr[spellId] and #summary.bursts < 2 then
summary.bursts[#summary.bursts + 1] = spellId
end
if _ixlvnesiog[spellId] and not tailoringSeen[spellId] then
tailoringSeen[spellId] = true
summary.bursts[#summary.bursts + 1] = spellId
end
end
return summary, observedAny, auras
end
function _pedvqgaynb.HasLongMedicine(summary)
return summary and (summary.flask or summary.combined
or (summary.battle and summary.guardian)) and true or false
end
function _pedvqgaynb.ScanGroupConsumables(previousSnapshot)
local snapshot = {
players = {}, scannedAt = time and time() or 0,
scannedClock = GetTime and GetTime() or 0,
known = 0, unknown = 0, missingFood = 0, missingMedicine = 0,
}
if not (UnitAura and UnitName) then return snapshot end
local members, expected = {}, 0
if _croxpxzhvp and _croxpxzhvp.GroupRosterMembers then members, expected = _croxpxzhvp.GroupRosterMembers() end
if #members == 0 and (tonumber(expected) or 0) == 0 then
local groupLabels = _xwmnimshzl()
for _, unit in ipairs(_hobcynilmx()) do
local displayName, whisperName = _iqabwtadim(unit)
members[#members + 1] = {
unit=unit, name=displayName, whisperName=whisperName,
exists=not UnitExists or UnitExists(unit),
connected=not UnitIsConnected or UnitIsConnected(unit),
visible=not UnitIsVisible or UnitIsVisible(unit),
isSelf=unit == "player" or (UnitIsUnit and UnitIsUnit(unit, "player")) or false,
groupLabel=groupLabels[unit],
}
end
expected = #members
end
local targetCount = tonumber(expected) or #members
if targetCount == 0 and IsInGroup and IsInGroup() and previousSnapshot then
targetCount = #(previousSnapshot.players or {})
end
snapshot.expectedCount = targetCount
local seen = {}
for _, member in ipairs(members) do
local unit = member.unit
local exists = member.exists == true
local displayName, whisperName = member.name, member.whisperName
if displayName then
local connected = member.connected ~= false
local summary, observedAny, auras = { bursts={} }, false, {}
if exists then summary, observedAny, auras = _jnablnycme(unit) end
local visible = member.visible == true
local isSelf = member.isSelf == true
local known = connected and (visible or observedAny or isSelf) and true or false
local class = member.class
local role = member.role
local ready = _kxpvlorvyd.Readiness and _kxpvlorvyd.Readiness.localCache
and _kxpvlorvyd.Readiness.localCache[displayName]
local roster = _kxpvlorvyd.Stats and _kxpvlorvyd.Stats.roster and _kxpvlorvyd.Stats.roster[displayName]
local groupLabel = member.groupLabel or (roster and roster.groupLabel)
local row = {
name = displayName, whisperName = whisperName, unit = unit,
groupLabel = groupLabel,
reminderName = _croxpxzhvp and _croxpxzhvp.GroupCharacterLabel
and _croxpxzhvp.GroupCharacterLabel(displayName, class or (roster and roster.class), groupLabel)
or (groupLabel and (groupLabel .. " " .. displayName) or displayName),
guid = UnitGUID and UnitGUID(unit) or nil,
class = class or (roster and roster.class),
role = role or (roster and roster.role),
specId = (ready and ready.specId) or (roster and roster.specId),
isSelf = isSelf,
consumables = summary, consumablesKnown = known,
consumablesLive = true,
teamAuras = auras, teamBuffsKnown = known,
}
snapshot.players[#snapshot.players + 1] = row
seen[displayName] = true
if known then
snapshot.known = snapshot.known + 1
if not summary.food then snapshot.missingFood = snapshot.missingFood + 1 end
if not _pedvqgaynb.HasLongMedicine(summary) then
snapshot.missingMedicine = snapshot.missingMedicine + 1
end
else
snapshot.unknown = snapshot.unknown + 1
end
end
end
local function appendUnknown(source)
local name = source and source.name
if not name or seen[name] or #snapshot.players >= targetCount then return end
local roster = _kxpvlorvyd.Stats and _kxpvlorvyd.Stats.roster and _kxpvlorvyd.Stats.roster[name]
local ready = _kxpvlorvyd.Readiness and _kxpvlorvyd.Readiness.localCache
and _kxpvlorvyd.Readiness.localCache[name]
snapshot.players[#snapshot.players + 1] = {
name=name, whisperName=source.whisperName or (roster and roster.whisperName) or name,
unit=source.unit or (roster and roster.unit),
groupLabel=source.groupLabel or (roster and roster.groupLabel),
reminderName=_croxpxzhvp and _croxpxzhvp.GroupCharacterLabel
and _croxpxzhvp.GroupCharacterLabel(name, source.class or (roster and roster.class),
source.groupLabel or (roster and roster.groupLabel)) or name,
guid=source.guid or (roster and roster.guid),
class=source.class or (roster and roster.class),
role=source.role or (roster and roster.role),
specId=source.specId or (ready and ready.specId) or (roster and roster.specId),
isSelf=source.isSelf == true,
consumables={bursts={}}, consumablesKnown=false, consumablesLive=true,
teamAuras={}, teamBuffsKnown=false, rosterPending=true,
}
snapshot.unknown = snapshot.unknown + 1
seen[name] = true
end
if #snapshot.players < targetCount then
for _, row in ipairs((previousSnapshot and previousSnapshot.players) or {}) do appendUnknown(row) end
end
if #snapshot.players < targetCount then
for name, info in pairs((_kxpvlorvyd.Stats and _kxpvlorvyd.Stats.roster) or {}) do
local row = {}
for key, value in pairs(info) do row[key] = value end
row.name = name
appendUnknown(row)
end
end
table.sort(snapshot.players, function(a, b) return tostring(a.name) < tostring(b.name) end)
if _kxpvlorvyd.TeamBuffs and _kxpvlorvyd.TeamBuffs.EvaluateSnapshot then
_kxpvlorvyd.TeamBuffs:EvaluateSnapshot(snapshot)
end
return snapshot
end
function _pedvqgaynb.RefreshGroupPlayerBuffs()
if not (UnitAura and UnitGUID and UnitName) then return 0 end
local refreshed, scanned = 0, 0
local oldByTargetSpell = {}
for _, aura in pairs(_sjtvckyjyy) do
if aura.auraType == "BUFF" and aura.dstGUID and _phhmpozmdr(aura.spellId) > 0 then
oldByTargetSpell[tostring(aura.dstGUID) .. "\001" .. tostring(_phhmpozmdr(aura.spellId))] = aura
end
end
for _, unit in ipairs(_hobcynilmx()) do
local exists = not UnitExists or UnitExists(unit)
local connected = not UnitIsConnected or UnitIsConnected(unit)
local dstGUID = exists and connected and UnitGUID(unit) or nil
local dstName = dstGUID and _cheyjwjkqp(UnitName(unit)) or nil
if dstGUID and dstName then
scanned = scanned + 1
local observed = {}
for index = 1, 255 do
local name, _, stacks, _, _, _, sourceUnit, _, _, spellId = UnitAura(unit, index, "HELPFUL")
if not name then break end
spellId = _phhmpozmdr(spellId)
if spellId > 0 then
local sourceGUID = sourceUnit and UnitGUID(sourceUnit) or nil
local sourceName = sourceUnit and _cheyjwjkqp(UnitName(sourceUnit)) or nil
local old = oldByTargetSpell[tostring(dstGUID) .. "\001" .. tostring(spellId)]
sourceGUID = sourceGUID or (old and old.srcGUID) or ("visible:" .. tostring(spellId))
observed[_ubhqeozcwl(dstGUID, spellId, sourceGUID)] = {
srcGUID=sourceGUID, srcName=sourceName or (old and old.srcName),
dstGUID=dstGUID, dstName=dstName,
spellId=spellId, spellName=name,
school=_phhmpozmdr(old and old.school), auraType="BUFF",
stacks=math.max(1, _phhmpozmdr(stacks)), seenAt=time and time() or 0,
}
refreshed = refreshed + 1
end
end
for key, aura in pairs(observed) do _sjtvckyjyy[key] = aura end
end
end
return refreshed, scanned
end
_pedvqgaynb.RefreshVisiblePlayerBuffs = _pedvqgaynb.RefreshGroupPlayerBuffs
function _pedvqgaynb.ClearTransientAuras()
for key, aura in pairs(_sjtvckyjyy) do
if aura.auraType == "DEBUFF" then _sjtvckyjyy[key] = nil end
end
end
local function _zfgbrwymhg(spellId, peer, npcId)
return tostring(spellId or 0) .. "\001" .. tostring(peer or "") .. "\001" .. tostring(npcId or 0)
end
local function _xmgtzhapib(row)
local scale = _phhmpozmdr(row and row[_jabmlggvyd])
return scale > 0 and scale or _odgedsrocx
end
local function _iwsggezxkn(row)
if row and row[_bztwsdekym] ~= nil then return _phhmpozmdr(row[_bztwsdekym]) end
return _phhmpozmdr(row and row[_wiuwcuifoz]) + _phhmpozmdr(row and row[_vnfklxhfld])
end
local function _gfuvnbpxcw(ids, observed)
for _, spellId in ipairs(ids) do
if observed[spellId] then return spellId end
end
end
function _pedvqgaynb.ConsumableSummary(rec)
if not rec then return nil end
local cached = _uyukpuwipw[rec]
if cached then return cached end
local started, observed, observedCounts = {}, {}, {}
for _, row in pairs(rec.auraBuffs or {}) do
local spellId = _phhmpozmdr(row[_krujdxjler])
if _nnaplyhigm[spellId] and _iwsggezxkn(row) > 0 then
observed[spellId] = true
observedCounts[spellId] = _phhmpozmdr(observedCounts[spellId]) + _iwsggezxkn(row)
if _phhmpozmdr(row[_wiuwcuifoz]) == 0 then started[spellId] = true end
end
end
local bursts = {}
for _, spellId in ipairs(_iivlizyhak) do
local count = math.min(observedCounts[spellId] or 0, 2 - #bursts)
for _ = 1, count do bursts[#bursts + 1] = spellId end
if #bursts >= 2 then break end
end
for _, spellId in ipairs(_xgtylqdaai) do
if observed[spellId] then bursts[#bursts + 1] = spellId end
end
local summary = {
food = _gfuvnbpxcw(_ehnfousucc, started),
flask = _gfuvnbpxcw(_kaxjrmtwpz, started),
combined = _gfuvnbpxcw(_rgjagdbkih, started),
battle = _gfuvnbpxcw(_nbmmqrjlff, started),
guardian = _gfuvnbpxcw(_hcwvujvtpu, started),
bursts = bursts,
}
_uyukpuwipw[rec] = summary
return summary
end
local function _byltiueuzw(row, scale)
local count = _iwsggezxkn(row)
local oldScale = _xmgtzhapib(row)
if oldScale ~= scale then
row[_oicguashfp] = math.floor(_phhmpozmdr(row[_oicguashfp]) * scale / oldScale + 0.5)
if row[_ihmoibjiek] ~= nil then row[_ihmoibjiek] = math.floor(_phhmpozmdr(row[_ihmoibjiek]) * scale / oldScale + 0.5) end
if row[_ltkebfoxoq] ~= nil then row[_ltkebfoxoq] = math.floor(_phhmpozmdr(row[_ltkebfoxoq]) * scale / oldScale + 0.5) end
end
row[_jabmlggvyd] = scale
row[_bztwsdekym] = count
end
local function _hliwudwfwd(row, relUnits, kind)
if row[_ltkebfoxoq] ~= relUnits or type(row[_czdsukzjku]) ~= "number"
or type(row[_qvqaaeiypi]) ~= "number" then
row[_ltkebfoxoq] = relUnits
row[_czdsukzjku] = 0
row[_qvqaaeiypi] = 0
end
if kind == "DOSE" then
row[_bztwsdekym] = _iwsggezxkn(row) + 1
row[_czdsukzjku] = row[_czdsukzjku] + 1
else
if row[_czdsukzjku] > 0 then
row[_czdsukzjku] = row[_czdsukzjku] - 1
else
row[_bztwsdekym] = _iwsggezxkn(row) + 1
end
row[_qvqaaeiypi] = row[_qvqaaeiypi] + 1
end
end
local function _tryboukycj(map, key, sub, spellId, spellName, school, peer, npcId, relUnits, seeded, seedStacks)
local row = map[key]
if not row then
row = { _phhmpozmdr(spellId), _phhmpozmdr(school), peer or "", 0, 0, 0, nil, spellName or "?", _phhmpozmdr(npcId), _tuzfsqpdda, 0 }
map[key] = row
else
_byltiueuzw(row, _tuzfsqpdda)
end
if sub == "SPELL_AURA_APPLIED" then
if row[_ihmoibjiek] == nil then row[_ihmoibjiek] = relUnits end
if seeded then
row[_bztwsdekym] = _iwsggezxkn(row) + 1
else
row[_wiuwcuifoz] = _phhmpozmdr(row[_wiuwcuifoz]) + 1
row[_bztwsdekym] = _iwsggezxkn(row) + 1
end
elseif sub == "SPELL_AURA_REFRESH" then
if row[_ihmoibjiek] ~= nil then row[_oicguashfp] = _phhmpozmdr(row[_oicguashfp]) + math.max(0, relUnits - row[_ihmoibjiek]) end
row[_ihmoibjiek] = relUnits
if not seeded then
row[_vnfklxhfld] = _phhmpozmdr(row[_vnfklxhfld]) + 1
_hliwudwfwd(row, relUnits, "REFRESH")
end
elseif sub == "SPELL_AURA_APPLIED_DOSE" then
if row[_ihmoibjiek] == nil then row[_ihmoibjiek] = relUnits end
if not seeded then _hliwudwfwd(row, relUnits, "DOSE") end
elseif sub == "SPELL_AURA_REMOVED" or sub == "SPELL_AURA_BROKEN" or sub == "SPELL_AURA_BROKEN_SPELL" then
if row[_ihmoibjiek] ~= nil then row[_oicguashfp] = _phhmpozmdr(row[_oicguashfp]) + math.max(0, relUnits - row[_ihmoibjiek]) end
row[_ihmoibjiek] = nil
end
end
function _pedvqgaynb.RecordBuff(rec, sub, spellId, spellName, school, sourceName, relUnits, seeded, seedStacks)
if not rec then return end
_pedvqgaynb.InitRecord(rec)
local key = _zfgbrwymhg(spellId, sourceName, 0)
_tryboukycj(rec.auraBuffs, key, sub, spellId, spellName, school, sourceName, 0, relUnits, seeded, seedStacks)
if _nnaplyhigm[_phhmpozmdr(spellId)] then _uyukpuwipw[rec] = nil end
end
function _pedvqgaynb.RecordDebuff(rec, sub, spellId, spellName, school, targetName, npcId, relUnits, seeded, seedStacks)
if not (rec and _phhmpozmdr(npcId) > 0) then return end
_pedvqgaynb.InitRecord(rec)
local key = _zfgbrwymhg(spellId, targetName, npcId)
_tryboukycj(rec.auraDebuffs, key, sub, spellId, spellName, school, targetName, npcId, relUnits, seeded, seedStacks)
end
function _pedvqgaynb.CaptureSegmentAuras(seg)
if not seg then return end
local seeds={}
for key,aura in pairs(_sjtvckyjyy) do
seeds[key]={
srcGUID=aura.srcGUID,srcName=aura.srcName,dstGUID=aura.dstGUID,dstName=aura.dstName,
spellId=aura.spellId,spellName=aura.spellName,school=aura.school,auraType=aura.auraType,
stacks=aura.stacks,
}
end
seg._detailAuraSeeds=seeds
end
local function _cmxewhgujd(rec, spellId)
for _, row in pairs(rec and rec.auraBuffs or {}) do
if _phhmpozmdr(row[_krujdxjler]) == _phhmpozmdr(spellId) and row[_ihmoibjiek] ~= nil then return true end
end
return false
end
function _pedvqgaynb.SeedRecord(rec, playerName, playerGUID, seg, reconcile)
if not rec or (rec._detailSeeded and not reconcile) then return end
local firstSeed = not rec._detailSeeded
rec._detailSeeded = true
_pedvqgaynb.InitRecord(rec)
local seeds=(seg and seg._detailAuraSeeds) or _sjtvckyjyy
for _, aura in pairs(seeds) do
if aura.auraType == "BUFF" and (aura.dstName == playerName or aura.dstGUID == playerGUID) then
if firstSeed or not _cmxewhgujd(rec, aura.spellId) then
_pedvqgaynb.RecordBuff(rec, "SPELL_AURA_APPLIED", aura.spellId, aura.spellName, aura.school, aura.srcName, 0, true, aura.stacks)
end
elseif firstSeed and aura.auraType == "DEBUFF" and aura.srcName == playerName then
local W = _kxpvlorvyd.WCLBosses
local npcId = W and W.NpcId and W.NpcId(aura.dstGUID) or 0
_pedvqgaynb.RecordDebuff(rec, "SPELL_AURA_APPLIED", aura.spellId, aura.spellName, aura.school, aura.dstName, npcId, 0, true, aura.stacks)
end
end
end
function _pedvqgaynb.ReconcileSegmentAuraSeeds(seg)
for name, rec in pairs(seg and seg.players or {}) do
_pedvqgaynb.SeedRecord(rec, name, rec.guid, seg, true)
end
end
local function _ipqulhjyyg(map, endUnits)
for _, row in pairs(map or {}) do
_byltiueuzw(row, _tuzfsqpdda)
if row[_ihmoibjiek] ~= nil then
row[_oicguashfp] = _phhmpozmdr(row[_oicguashfp]) + math.max(0, endUnits - row[_ihmoibjiek])
row[_ihmoibjiek] = nil
end
row[_ltkebfoxoq], row[_czdsukzjku], row[_qvqaaeiypi] = nil, nil, nil
end
end
function _pedvqgaynb.CloseRecord(rec, duration)
if not rec then return end
local endUnits = math.max(0, math.floor(_phhmpozmdr(duration) * _tuzfsqpdda + 0.5))
_ipqulhjyyg(rec.auraBuffs, endUnits)
_ipqulhjyyg(rec.auraDebuffs, endUnits)
end
local function _vkqbfdzmru(bossName, npcId, targetName, bossCfg)
local W = _kxpvlorvyd.WCLBosses
if _croxpxzhvp and _croxpxzhvp.IsTrainingDummy and _croxpxzhvp.IsTrainingDummy(targetName) then return true end
if W and W.Get and W.Get(bossName) and W.CountsNpcAsBoss then
return W:CountsNpcAsBoss(bossName, npcId, bossCfg)
end
return bossName and targetName and bossName == targetName
end
local function _rkwxniskup(name)
return type(name) == "string" and name:find("^所有战斗汇总") ~= nil
end
_pedvqgaynb.IsSummaryEncounter = _rkwxniskup
local function _aatodnsezy(dst, src, amountIndex)
local amount = _phhmpozmdr(src[amountIndex or _ebdaujxmqn])
dst.amount = dst.amount + amount
dst.hits = dst.hits + _phhmpozmdr(src[_tpcpxfwvms])
dst.crits = dst.crits + _phhmpozmdr(src[_yzrelbxytq])
dst.normalTotal = dst.normalTotal + _phhmpozmdr(src[_dpndqhsgdg])
dst.critTotal = dst.critTotal + _phhmpozmdr(src[_rhikelwfbe])
dst.normalMin = _ikyzjkqtrd(dst.normalMin, src[_wpmdockvti])
dst.normalMax = math.max(dst.normalMax, _phhmpozmdr(src[_nympogznaa]))
dst.critMin = _ikyzjkqtrd(dst.critMin, src[_mwwswrhosr])
dst.critMax = math.max(dst.critMax, _phhmpozmdr(src[_umyqoczrvh]))
dst.absorbed = dst.absorbed + _phhmpozmdr(src[_xoziqcutre])
dst.misses = dst.misses + _phhmpozmdr(src[_xcjelqcurg])
end
local function _leusilhnzo(rec, key, bossName, bossCfg)
local scoped = rec and rec.castTargetStats and rec.castTargetStats[key]
if type(scoped) ~= "table" or not next(scoped) then
return _phhmpozmdr(rec and rec.castStats and rec.castStats[key] and rec.castStats[key][3])
end
local total = _phhmpozmdr(rec and rec.castStats and rec.castStats[key] and rec.castStats[key][3])
local targeted, count = 0, 0
for npcId, target in pairs(scoped) do
targeted = targeted + _phhmpozmdr(target[_owfdghrrng])
if _vkqbfdzmru(bossName, _phhmpozmdr(npcId), target[_bkzrcpmzxx], bossCfg) then
count = count + _phhmpozmdr(target[_owfdghrrng])
end
end
return count + math.max(0, total - targeted)
end
function _pedvqgaynb.SpellRows(rec, healing, bossName, mode, bossCfg)
if rec then
_pedvqgaynb.InitRecord(rec)
if not _vfqwcuiopj[rec] then _tonfzydurj(rec) end
end
local summary = not healing and mode == "boss" and _rkwxniskup(bossName)
local generatedSummary = summary and rec and rec._detailSummary
local stats, legacy
if rec then
if healing then
stats, legacy = rec.healStats, rec.heals
elseif generatedSummary then
stats, legacy = rec.summarySpellStats, rec.summaryLegacySpells
else
stats, legacy = rec.spellStats, rec.spells
end
end
legacy = legacy or {}
local out = {}
local seen = {}
local byDisplay = {}
for key, src in pairs(stats or {}) do
local display = _yruonnyuns(key, src[_bmmxlhdltn])
local castMap = generatedSummary and rec.summaryCastStats or rec.castStats
local casts = _phhmpozmdr(castMap and castMap[key] and castMap[key][3])
if not generatedSummary and not healing and mode == "boss" then
casts = _leusilhnzo(rec, key, bossName, bossCfg)
end
local row = {
name=display, spellId=_phhmpozmdr(src[_bmmxlhdltn]), school=_phhmpozmdr(src[_zwhqhqynuz]), amount=0,
hits=0, crits=0, normalTotal=0, critTotal=0,
normalMin=0, normalMax=0, critMin=0, critMax=0, absorbed=0, misses=0,
casts=casts, detailed=true,
}
local useTargetScope = not generatedSummary and not healing and mode == "boss"
and type(rec.spellTargetStats) == "table"
if useTargetScope then
local scoped = rec.spellTargetStats[key]
if scoped then
for npcId, target in pairs(scoped) do
if _vkqbfdzmru(bossName, _phhmpozmdr(npcId), target[_tvoqfecdwa], bossCfg) then
_aatodnsezy(row, target, _kahgzsdisa)
end
end
end
else
_aatodnsezy(row, src, generatedSummary and _kahgzsdisa or _ebdaujxmqn)
end
if row.amount > 0 or row.casts > 0 or row.misses > 0 then out[#out + 1] = row end
seen[display] = _phhmpozmdr(seen[display]) + 1
byDisplay[display] = byDisplay[display] or {}
byDisplay[display][#byDisplay[display] + 1] = row
end
for key, value in pairs(legacy or {}) do
local matching = byDisplay[key]
if generatedSummary and matching and #matching == 1 and _phhmpozmdr(value) > 0 then
matching[1].amount = matching[1].amount + _phhmpozmdr(value)
matching[1].detailed = false
elseif generatedSummary and matching and #matching > 1 and _phhmpozmdr(value) > 0 then
out[#out + 1] = { name=key, amount=_phhmpozmdr(value), casts=0, hits=0, crits=0, detailed=false }
elseif not seen[key] then
out[#out + 1] = { name=key, amount=_phhmpozmdr(value), casts=0, hits=0, crits=0, detailed=false }
end
end
table.sort(out, function(a, b)
if a.amount == b.amount then return tostring(a.name) < tostring(b.name) end
return a.amount > b.amount
end)
return out
end
function _pedvqgaynb.AuraRows(rec, kind, duration, bossName, bossCfg)
local map = rec and (kind == "debuff" and rec.auraDebuffs or rec.auraBuffs) or {}
local out = {}
for _, src in pairs(map or {}) do
if kind ~= "debuff" or not bossName or _vkqbfdzmru(bossName, _phhmpozmdr(src[_brbfcsxnuj]), src[_gnjvrkwouw], bossCfg) then
local scale = _xmgtzhapib(src)
local endUnits = math.max(0, math.floor(_phhmpozmdr(duration) * scale + 0.5))
local uptimeUnits = _phhmpozmdr(src[_oicguashfp])
if src[_ihmoibjiek] ~= nil then uptimeUnits = uptimeUnits + math.max(0, endUnits - src[_ihmoibjiek]) end
local uptime = uptimeUnits / scale
out[#out + 1] = {
spellId=_phhmpozmdr(src[_krujdxjler]), school=_phhmpozmdr(src[_udlelxjxou]), name=src[_gpliwnlpos] or "?",
peer=src[_gnjvrkwouw], uptime=uptime,
percent=duration and duration > 0 and math.min(1, uptime / duration) or 0,
count=_iwsggezxkn(src), applications=_phhmpozmdr(src[_wiuwcuifoz]), refreshes=_phhmpozmdr(src[_vnfklxhfld]),
}
end
end
table.sort(out, function(a, b)
if a.uptime == b.uptime then return tostring(a.name) < tostring(b.name) end
return a.uptime > b.uptime
end)
return out
end
function _pedvqgaynb.FilterAuraRowsByCaster(rows, casterName)
local wanted = _cheyjwjkqp(casterName)
if not wanted or wanted == "" then return {} end
local out = {}
for _, row in ipairs(rows or {}) do
if _cheyjwjkqp(row.peer) == wanted then out[#out + 1] = row end
end
return out
end
local function _tdnfuxmeqt(detail, fallback)
GameTooltip:ClearLines()
if detail.spellId and detail.spellId > 0 and GameTooltip.SetHyperlink then
GameTooltip:SetHyperlink("spell:" .. detail.spellId)
else
GameTooltip:AddLine(detail.name or fallback, 1, 0.82, 0)
end
end
function _pedvqgaynb.ShowSpellTooltip(owner, detail, isHeal, total)
if not (GameTooltip and owner and detail) then return end
GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
_tdnfuxmeqt(detail, "技能")
local amount = _phhmpozmdr(detail.amount or detail.v)
GameTooltip:AddDoubleLine(isHeal and "有效治疗" or "伤害", _croxpxzhvp.Short(amount), 1, 1, 1, 1, 1, 1)
if _phhmpozmdr(total) > 0 then
GameTooltip:AddDoubleLine("占比", _croxpxzhvp.Pct2(amount / _phhmpozmdr(total)), 0.8, 0.8, 0.8, 1, 0.82, 0)
end
GameTooltip:AddDoubleLine("释放次数", _phhmpozmdr(detail.casts) > 0 and tostring(detail.casts) or "-", 0.8, 0.8, 0.8, 1, 1, 1)
GameTooltip:AddDoubleLine("命中 / 跳数", tostring(_phhmpozmdr(detail.hits)), 0.8, 0.8, 0.8, 1, 1, 1)
local critPct = _phhmpozmdr(detail.hits) > 0 and _phhmpozmdr(detail.crits) / _phhmpozmdr(detail.hits) or 0
GameTooltip:AddDoubleLine("暴击", string.format("%d（%.1f%%）", _phhmpozmdr(detail.crits), critPct * 100), 0.8, 0.8, 0.8, 1, 0.82, 0)
local normalHits = math.max(0, _phhmpozmdr(detail.hits) - _phhmpozmdr(detail.crits))
if normalHits > 0 and _phhmpozmdr(detail.normalTotal) > 0 then
GameTooltip:AddDoubleLine("普通 最小 / 最大", _croxpxzhvp.Short(detail.normalMin) .. " / " .. _croxpxzhvp.Short(detail.normalMax), 0.7, 0.7, 0.7, 1, 1, 1)
GameTooltip:AddDoubleLine("普通 平均", _croxpxzhvp.Short(_phhmpozmdr(detail.normalTotal) / normalHits), 0.7, 0.7, 0.7, 1, 1, 1)
end
if _phhmpozmdr(detail.crits) > 0 and _phhmpozmdr(detail.critTotal) > 0 then
GameTooltip:AddDoubleLine("暴击 最小 / 最大", _croxpxzhvp.Short(detail.critMin) .. " / " .. _croxpxzhvp.Short(detail.critMax), 0.7, 0.7, 0.7, 1, 1, 1)
GameTooltip:AddDoubleLine("暴击 平均", _croxpxzhvp.Short(_phhmpozmdr(detail.critTotal) / _phhmpozmdr(detail.crits)), 0.7, 0.7, 0.7, 1, 1, 1)
end
if _phhmpozmdr(detail.misses) > 0 then GameTooltip:AddDoubleLine("未命中", tostring(detail.misses), 0.8, 0.8, 0.8, 1, 0.45, 0.35) end
if _phhmpozmdr(detail.absorbed) > 0 then
GameTooltip:AddDoubleLine(isHeal and "过量治疗" or "吸收计入", _croxpxzhvp.Short(detail.absorbed), 0.8, 0.8, 0.8, 0.7, 0.85, 1)
end
if detail.detailed == false then GameTooltip:AddLine("旧记录没有释放、命中与暴击明细。", 0.55, 0.55, 0.55, true) end
GameTooltip:Show()
end
function _pedvqgaynb.ShowAuraTooltip(owner, detail, kind)
if not (GameTooltip and owner and detail) then return end
GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
_tdnfuxmeqt(detail, "Aura")
GameTooltip:AddDoubleLine("覆盖时间", string.format("%.1f秒", _phhmpozmdr(detail.uptime)), 0.8, 0.8, 0.8, 1, 1, 1)
GameTooltip:AddDoubleLine("覆盖率", string.format("%.1f%%", _phhmpozmdr(detail.percent) * 100), 0.8, 0.8, 0.8, 1, 0.82, 0)
GameTooltip:AddDoubleLine("次数", tostring(_phhmpozmdr(detail.count)), 0.8, 0.8, 0.8, 1, 1, 1)
GameTooltip:AddDoubleLine("施加次数", tostring(_phhmpozmdr(detail.applications)), 0.8, 0.8, 0.8, 1, 1, 1)
GameTooltip:AddDoubleLine("刷新次数", tostring(_phhmpozmdr(detail.refreshes)), 0.8, 0.8, 0.8, 1, 1, 1)
if detail.peer and detail.peer ~= "" then
GameTooltip:AddDoubleLine(kind == "debuff" and "目标" or "来源", detail.peer, 0.8, 0.8, 0.8, 1, 1, 1)
end
GameTooltip:Show()
end
function _pedvqgaynb.ShowBossTooltip(owner, detail)
if not (GameTooltip and owner and detail) then return end
GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
_tdnfuxmeqt(detail, "Boss技能")
GameTooltip:AddDoubleLine("伤害", _croxpxzhvp.Short(detail.damage), 0.8, 0.8, 0.8, 1, 1, 1)
GameTooltip:AddDoubleLine("施放次数", tostring(_phhmpozmdr(detail.casts)), 0.8, 0.8, 0.8, 1, 1, 1)
GameTooltip:AddDoubleLine("命中次数", tostring(_phhmpozmdr(detail.hits)), 0.8, 0.8, 0.8, 1, 1, 1)
local critPct = _phhmpozmdr(detail.hits) > 0 and _phhmpozmdr(detail.crits) / _phhmpozmdr(detail.hits) or 0
GameTooltip:AddDoubleLine("暴击", string.format("%d（%.1f%%）", _phhmpozmdr(detail.crits), critPct * 100), 0.8, 0.8, 0.8, 1, 0.82, 0)
GameTooltip:AddDoubleLine("时间点", tostring(_phhmpozmdr(detail.events)), 0.8, 0.8, 0.8, 1, 1, 1)
GameTooltip:Show()
end
local function _byygrzwsew(dst, src, owner)
for sourceKey, value in pairs(src or {}) do
local key = owner and _hiqekqxxly(owner,
_yruonnyuns(sourceKey, value[_bmmxlhdltn]), value[_bmmxlhdltn]) or sourceKey
local map, row = _jkdhveqgfr(dst, key, value[_bmmxlhdltn], value[_zwhqhqynuz])
dst = map
row[_ebdaujxmqn] = _phhmpozmdr(row[_ebdaujxmqn]) + _phhmpozmdr(value[_ebdaujxmqn])
row[_tpcpxfwvms] = _phhmpozmdr(row[_tpcpxfwvms]) + _phhmpozmdr(value[_tpcpxfwvms])
row[_yzrelbxytq] = _phhmpozmdr(row[_yzrelbxytq]) + _phhmpozmdr(value[_yzrelbxytq])
row[_dpndqhsgdg] = _phhmpozmdr(row[_dpndqhsgdg]) + _phhmpozmdr(value[_dpndqhsgdg])
row[_rhikelwfbe] = _phhmpozmdr(row[_rhikelwfbe]) + _phhmpozmdr(value[_rhikelwfbe])
row[_wpmdockvti] = _ikyzjkqtrd(row[_wpmdockvti], value[_wpmdockvti])
row[_nympogznaa] = math.max(_phhmpozmdr(row[_nympogznaa]), _phhmpozmdr(value[_nympogznaa]))
row[_mwwswrhosr] = _ikyzjkqtrd(row[_mwwswrhosr], value[_mwwswrhosr])
row[_umyqoczrvh] = math.max(_phhmpozmdr(row[_umyqoczrvh]), _phhmpozmdr(value[_umyqoczrvh]))
row[_xoziqcutre] = _phhmpozmdr(row[_xoziqcutre]) + _phhmpozmdr(value[_xoziqcutre])
row[_xcjelqcurg] = _phhmpozmdr(row[_xcjelqcurg]) + _phhmpozmdr(value[_xcjelqcurg])
row[_kahgzsdisa] = _phhmpozmdr(row[_kahgzsdisa]) + _phhmpozmdr(value[_kahgzsdisa])
if (not row[_tvoqfecdwa] or row[_tvoqfecdwa] == "") and value[_tvoqfecdwa] then row[_tvoqfecdwa] = value[_tvoqfecdwa] end
end
return dst
end
local function _dggycyzjps(dst, src, sourceDuration)
for key, value in pairs(src or {}) do
local row = dst[key]
if not row then
row = { value[_krujdxjler], value[_udlelxjxou], value[_gnjvrkwouw], 0, 0, 0, nil,
value[_gpliwnlpos], value[_brbfcsxnuj], _tuzfsqpdda, 0 }
dst[key] = row
else
_byltiueuzw(row, _tuzfsqpdda)
end
local existingCount = _iwsggezxkn(row)
local sourceScale = _xmgtzhapib(value)
local uptime = _phhmpozmdr(value[_oicguashfp])
if value[_ihmoibjiek] ~= nil and sourceDuration and sourceDuration > 0 then
local endUnits = math.floor(sourceDuration * sourceScale + 0.5)
uptime = uptime + math.max(0, endUnits - _phhmpozmdr(value[_ihmoibjiek]))
end
row[_oicguashfp] = _phhmpozmdr(row[_oicguashfp]) + math.floor(uptime * _tuzfsqpdda / sourceScale + 0.5)
row[_wiuwcuifoz] = _phhmpozmdr(row[_wiuwcuifoz]) + _phhmpozmdr(value[_wiuwcuifoz])
row[_vnfklxhfld] = _phhmpozmdr(row[_vnfklxhfld]) + _phhmpozmdr(value[_vnfklxhfld])
row[_bztwsdekym] = existingCount + _iwsggezxkn(value)
end
end
local function _pznycdcdsi(dst, src)
for key, value in pairs(src or {}) do dst[key] = _phhmpozmdr(dst[key]) + _phhmpozmdr(value) end
end
local function _dbkzbzhjad(dst, src, owner)
for sourceKey, value in pairs(src or {}) do
local key = owner and _hiqekqxxly(owner,
_yruonnyuns(sourceKey, value[_bmmxlhdltn]), value[_bmmxlhdltn]) or sourceKey
local row = dst[key]
if not row then row = { value[1], value[2], 0 }; dst[key] = row end
row[3] = _phhmpozmdr(row[3]) + _phhmpozmdr(value[3])
end
return dst
end
local function _vkbflklehl(dst, src, owner, sourceCasts)
for sourceKey, targets in pairs(src or {}) do
local cast = sourceCasts and sourceCasts[sourceKey]
local key = owner and cast and _hiqekqxxly(owner,
_yruonnyuns(sourceKey, cast[_bmmxlhdltn]), cast[_bmmxlhdltn]) or sourceKey
local out = dst[key]
if not out then out = {}; dst[key] = out end
for npcId, value in pairs(targets or {}) do
local row = out[npcId]
if not row then row = { 0, value[_bkzrcpmzxx] }; out[npcId] = row end
row[_owfdghrrng] = _phhmpozmdr(row[_owfdghrrng]) + _phhmpozmdr(value[_owfdghrrng])
if (not row[_bkzrcpmzxx] or row[_bkzrcpmzxx] == "") and value[_bkzrcpmzxx] then
row[_bkzrcpmzxx] = value[_bkzrcpmzxx]
end
end
end
return dst
end
local function _qefzrppfhh(dst, src, bossName, bossCfg)
if src._detailSummary then
dst.summarySpellStats = _byygrzwsew(dst.summarySpellStats or {}, src.summarySpellStats, dst)
dst.summaryCastStats = _dbkzbzhjad(dst.summaryCastStats or {}, src.summaryCastStats, dst)
dst.summaryLegacySpells = dst.summaryLegacySpells or {}
_pznycdcdsi(dst.summaryLegacySpells, src.summaryLegacySpells)
dst._detailSummary = true
return
end
if not bossName or _rkwxniskup(bossName) then return end
dst._detailSummary = true
dst.summarySpellStats = dst.summarySpellStats or {}
dst.summaryCastStats = dst.summaryCastStats or {}
local scoped = src.spellTargetStats
if type(scoped) == "table" and next(scoped) then
for key, targets in pairs(scoped) do
for npcId, target in pairs(targets or {}) do
if _vkqbfdzmru(bossName, _phhmpozmdr(npcId), target[_tvoqfecdwa], bossCfg) then
local resolved = _hiqekqxxly(dst, _yruonnyuns(key, target[_bmmxlhdltn]), target[_bmmxlhdltn])
dst.summarySpellStats[resolved] = dst.summarySpellStats[resolved] or {}
dst.summarySpellStats = _byygrzwsew(dst.summarySpellStats, { [key] = target }, dst)
end
end
end
elseif not (type(src.spellStats) == "table" and next(src.spellStats)) then
dst.summaryLegacySpells = dst.summaryLegacySpells or {}
_pznycdcdsi(dst.summaryLegacySpells, src.spells)
end
for key, value in pairs(src.castStats or {}) do
local count = _leusilhnzo(src, key, bossName, bossCfg)
if count > 0 then
local resolved = _hiqekqxxly(dst, _yruonnyuns(key, value[_bmmxlhdltn]), value[_bmmxlhdltn])
local row = dst.summaryCastStats[resolved]
if not row then row = { value[1], value[2], 0 }; dst.summaryCastStats[resolved] = row end
row[3] = _phhmpozmdr(row[3]) + count
end
end
end
function _pedvqgaynb.MergePlayerDetails(dst, src, bossName, bossCfg)
if not (dst and src) then return end
_pedvqgaynb.InitRecord(dst)
_pedvqgaynb.InitRecord(src)
if not _vfqwcuiopj[src] then _tonfzydurj(src) end
dst.spellStats = _byygrzwsew(dst.spellStats, src.spellStats, dst)
dst.healStats = _byygrzwsew(dst.healStats, src.healStats, dst)
dst.castStats = _dbkzbzhjad(dst.castStats, src.castStats, dst)
dst.castTargetStats = _vkbflklehl(dst.castTargetStats, src.castTargetStats, dst, src.castStats)
for key, targets in pairs(src.spellTargetStats or {}) do
local sample
for _, target in pairs(targets or {}) do sample = target; break end
local resolved = sample and _hiqekqxxly(dst,
_yruonnyuns(key, sample[_bmmxlhdltn]), sample[_bmmxlhdltn]) or key
dst.spellTargetStats[resolved] = dst.spellTargetStats[resolved] or {}
dst.spellTargetStats[resolved] = _byygrzwsew(dst.spellTargetStats[resolved], targets)
end
local sourceDuration = _phhmpozmdr(src.fightDur or src.ivDur)
_dggycyzjps(dst.auraBuffs, src.auraBuffs, sourceDuration)
_dggycyzjps(dst.auraDebuffs, src.auraDebuffs, sourceDuration)
_qefzrppfhh(dst, src, bossName, bossCfg)
end
local function _zwmzbfvmad(row, timeTenths, code, targetName)
row[7] = row[7] or {}
if #row[7] >= 600 then return end
row[7][#row[7] + 1] = timeTenths
row[7][#row[7] + 1] = code
row[7][#row[7] + 1] = targetName or ""
end
local function _xgcrdqwxty(seg, spellId, spellName, school)
seg.bossSpells = seg.bossSpells or {}
local key = _phhmpozmdr(spellId) > 0 and _phhmpozmdr(spellId) or (spellName or "?")
local row = seg.bossSpells[key]
if not row then
row = { spellName or "?", _phhmpozmdr(school), 0, 0, 0, 0, {} }
seg.bossSpells[key] = row
end
return row
end
function _pedvqgaynb.IsBossSource(seg, srcGUID, srcName)
if not (seg and seg.isBoss and srcGUID and not (_croxpxzhvp and _croxpxzhvp.IsPlayer and _croxpxzhvp.IsPlayer(srcGUID))) then return false end
local W = _kxpvlorvyd.WCLBosses
local npcId = W and W.NpcId and W.NpcId(srcGUID) or 0
local base = W and W.Get and W.Get(seg.name)
if base and base.big then
for _, id in ipairs(base.big) do if id == npcId then return true end end
return false
end
return srcName and seg.name and srcName == seg.name
end
function _pedvqgaynb.RecordBossCast(seg, sub, spellId, spellName, school, targetName, now)
local row = _xgcrdqwxty(seg, spellId, spellName, school)
local rel = math.max(0, math.floor((_phhmpozmdr(now) - _phhmpozmdr(seg.startTime)) * 10 + 0.5))
if sub == "SPELL_CAST_START" then
row._startAt = rel
_zwmzbfvmad(row, rel, 1, targetName)
elseif sub == "SPELL_CAST_SUCCESS" then
row[3] = _phhmpozmdr(row[3]) + 1
if row._startAt == nil or rel - row._startAt > 150 then _zwmzbfvmad(row, rel, 2, targetName) end
row._startAt = nil
end
end
function _pedvqgaynb.RecordBossHit(seg, spellId, spellName, school, amount, critical)
local row = _xgcrdqwxty(seg, spellId, spellName, school)
row[4] = _phhmpozmdr(row[4]) + 1
row[5] = _phhmpozmdr(row[5]) + math.max(0, _phhmpozmdr(amount))
if critical then row[6] = _phhmpozmdr(row[6]) + 1 end
end
function _pedvqgaynb.RecordBossAura(seg, sub, spellId, spellName, school, targetName, now)
if sub ~= "SPELL_AURA_APPLIED" and sub ~= "SPELL_AURA_REMOVED" then return end
local row = _xgcrdqwxty(seg, spellId, spellName, school)
local rel = math.max(0, math.floor((_phhmpozmdr(now) - _phhmpozmdr(seg.startTime)) * 10 + 0.5))
_zwmzbfvmad(row, rel, sub == "SPELL_AURA_APPLIED" and 3 or 4, targetName)
end
function _pedvqgaynb.CloseBossSpells(seg)
for _, row in pairs(seg and seg.bossSpells or {}) do row._startAt = nil end
if seg then seg._detailAuraSeeds=nil end
end
function _pedvqgaynb.BossEvents(bossSpells)
local out = {}
for spellId, row in pairs(bossSpells or {}) do
local events = row[7] or {}
for i = 1, #events, 3 do
out[#out + 1] = {
spellId=tonumber(spellId) or 0, name=row[1] or "?", school=_phhmpozmdr(row[2]),
time=_phhmpozmdr(events[i]) / 10, code=_phhmpozmdr(events[i + 1]), target=events[i + 2],
}
end
end
table.sort(out, function(a, b)
if a.time == b.time then return tostring(a.name) < tostring(b.name) end
return a.time < b.time
end)
return out
end
function _pedvqgaynb.BossRows(bossSpells)
local out = {}
for spellId, row in pairs(bossSpells or {}) do
out[#out + 1] = {
spellId=tonumber(spellId) or 0, name=row[1] or "?", school=_phhmpozmdr(row[2]),
casts=_phhmpozmdr(row[3]), hits=_phhmpozmdr(row[4]), damage=_phhmpozmdr(row[5]), crits=_phhmpozmdr(row[6]),
events=math.floor(#(row[7] or {}) / 3),
}
end
table.sort(out, function(a, b)
if a.damage == b.damage then
if a.casts == b.casts then return tostring(a.name) < tostring(b.name) end
return a.casts > b.casts
end
return a.damage > b.damage
end)
return out
end
local function _xuyhyytmvd(value, stack)
local kind = type(value)
if kind == "nil" then return 3 end
if kind == "boolean" then return value and 4 or 5 end
if kind == "number" then return #tostring(value) end
if kind == "string" then return #value + 2 end
if kind ~= "table" then return 8 end
if stack[value] then return 0 end
stack[value] = true
local bytes = 2
for key, item in pairs(value) do bytes = bytes + _xuyhyytmvd(key, stack) + _xuyhyytmvd(item, stack) + 6 end
stack[value] = nil
return bytes
end
local storageEstimate
function _pedvqgaynb.InvalidateStorageEstimate()
storageEstimate = nil
end
function _pedvqgaynb.EstimateCombatStorage()
if storageEstimate ~= nil then return storageEstimate end
local db = NoWCLDB or {}
storageEstimate = _xuyhyytmvd(db.tabs or {}, {}) + _xuyhyytmvd(db.segments or {}, {})
+ _xuyhyytmvd(db.activeSegment or {}, {})
return storageEstimate
end
function _pedvqgaynb.FormatBytes(bytes)
bytes = math.max(0, _phhmpozmdr(bytes))
if bytes >= 1024 * 1024 then return string.format("%.1f MB", bytes / 1024 / 1024) end
if bytes >= 1024 then return string.format("%.0f KB", bytes / 1024) end
return tostring(math.floor(bytes)) .. " B"
end
