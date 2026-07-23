local addonName, NoWCL = ...
local C = {}
NoWCL.ConsumableCheck = C
local REMIND_INTERVAL = 0.4
local MESSAGE_LIMIT = 230
local REMINDER_MESSAGE_LIMIT = 230
local LINKED_REMINDER_MESSAGE_LIMIT = 230
local LEGACY_REMINDER_PREFIX = "开战检查 "
local CHAT_PREFIX = "[NCL] "
local AUTO_SELF_REMINDER_COOLDOWN = 300
local DEFAULT_AUTO_SELF_REMINDER_MINUTES = 5
local function shortName(name)
return name and (tostring(name):match("^[^-]+") or tostring(name)) or nil
end
local function trimBytes(text, limit)
text = tostring(text or "")
if #text <= limit then return text end
local i, last = 1, 0
while i <= #text do
local b = text:byte(i)
local step = (b < 0x80 and 1) or (b < 0xE0 and 2) or (b < 0xF0 and 3) or 4
if i + step - 1 > limit then break end
last = i + step - 1
i = i + step
end
return text:sub(1, last)
end
local function restrictedReminderText(text)
text = tostring(text or "")
text = text:gsub("（", " "):gsub("）", " "):gsub("、", " "):gsub("；", " ")
local out, i, len = {}, 1, #text
while i <= len do
local b1 = text:byte(i)
local two = text:sub(i, i + 1)
local three = text:sub(i, i + 2)
if two == "·" then
out[#out + 1] = two
i = i + 2
elseif three == "「" or three == "」" or three == "，" then
out[#out + 1] = three
i = i + 3
elseif b1 == 32 or b1 == 45 or (b1 >= 48 and b1 <= 57) then
out[#out + 1] = text:sub(i, i)
i = i + 1
elseif b1 >= 0xE0 and b1 < 0xF0 and i + 2 <= len then
local b2, b3 = text:byte(i + 1), text:byte(i + 2)
local cp = (b1 - 0xE0) * 0x1000 + (b2 - 0x80) * 0x40 + (b3 - 0x80)
if (cp >= 0x3400 and cp <= 0x9FFF) or (cp >= 0xF900 and cp <= 0xFAFF) then
out[#out + 1] = text:sub(i, i + 2)
else
out[#out + 1] = " "
end
i = i + 3
else
out[#out + 1] = " "
i = i + (b1 >= 0xF0 and 4 or b1 >= 0xC0 and 2 or 1)
end
end
return (table.concat(out):gsub(" +", " "):gsub("^ ", ""):gsub(" $", ""))
end
local function reminderLine(body)
return trimBytes(restrictedReminderText(body), REMINDER_MESSAGE_LIMIT)
end
local function splitPlain(text, delimiter)
local out, startAt = {}, 1
text, delimiter = tostring(text or ""), tostring(delimiter or "")
if delimiter == "" then return { text } end
while true do
local at = text:find(delimiter, startAt, true)
if not at then
if startAt <= #text then out[#out + 1] = text:sub(startAt) end
return out
end
if at > startAt then out[#out + 1] = text:sub(startAt, at - 1) end
startAt = at + #delimiter
end
end
local function spellHyperlink(spellId)
spellId = tonumber(spellId)
if not spellId or spellId <= 0 then return nil end
local link
if GetSpellLink then
local ok, value = pcall(GetSpellLink, spellId)
if ok then link = value end
end
if not link and C_Spell and C_Spell.GetSpellLink then
local ok, value = pcall(C_Spell.GetSpellLink, spellId)
if ok then link = value end
end
if link and link:find("|Hspell:", 1, true) then return link end
return nil
end
local function safeTargetName(name)
name = tostring(name or "")
local groupLabel, classLabel, characterName = name:match("^(%d+%-%d+)%s+([^「]+)「([^」]+)」$")
if groupLabel then
characterName = tostring(shortName(characterName) or "")
characterName = characterName:gsub("[Nn][Oo][Ww][Cc][Ll]", ""):gsub("[Ww][Cc][Ll]", "")
if characterName ~= "" then
return groupLabel .. " " .. classLabel .. "「" .. characterName .. "」"
end
end
groupLabel, classLabel, characterName = name:match("^(%d+%-%d+)%s+·([^·]+)·「([^」]+)」$")
if groupLabel then
characterName = tostring(shortName(characterName) or "")
characterName = characterName:gsub("[Nn][Oo][Ww][Cc][Ll]", ""):gsub("[Ww][Cc][Ll]", "")
if characterName ~= "" then
return groupLabel .. " " .. classLabel .. "「" .. characterName .. "」"
end
end
groupLabel, characterName = name:match("^(%d+%-%d+)%s+(.+)$")
name = tostring(shortName(characterName or name) or "")
name = name:gsub("[Nn][Oo][Ww][Cc][Ll]", ""):gsub("[Ww][Cc][Ll]", "")
if groupLabel and name ~= "" then name = groupLabel .. " " .. name end
return name
end
local function linkedBuffLines(group)
local rule = group and group.rule
local link = spellHyperlink(group and group.spellId)
or (rule and rule.label) or "团队增益"
local base = "请补 " .. link .. " 给 "
local lines, names = {}, {}
for _, rawName in ipairs(group.targets or {}) do
local name = safeTargetName(rawName)
if name ~= "" then
local candidateNames = {}
for i, current in ipairs(names) do candidateNames[i] = current end
candidateNames[#candidateNames + 1] = name
local candidate = base .. table.concat(candidateNames, "，")
if #candidate > LINKED_REMINDER_MESSAGE_LIMIT and #names > 0 then
lines[#lines + 1] = base .. table.concat(names, "，")
names = { name }
elseif #candidate > LINKED_REMINDER_MESSAGE_LIMIT then
lines[#lines + 1] = reminderLine("请补 " .. (rule and rule.label or "团队增益") .. " 给 " .. name)
names = {}
else
names = candidateNames
end
end
end
if #names > 0 then lines[#lines + 1] = base .. table.concat(names, "，") end
if #lines == 0 then lines[1] = "请补 " .. link end
return lines
end
function C:BuildWhisperMessages(plan)
local messages = {}
for _, item in ipairs(plan or {}) do
local target = item.whisperName
if target and (item.kind == "consumables" or item.kind == "combined"
or item.kind == "food" or item.kind == "medicine") then
local missing = {}
if item.missingFood or item.kind == "food" then missing[#missing + 1] = "缺食物" end
if item.missingMedicine or item.kind == "medicine" then missing[#missing + 1] = "缺药剂" end
if #missing > 0 then
local who = item.reminderName and (safeTargetName(item.reminderName) .. " ") or ""
messages[#messages + 1] = {
message=reminderLine(who .. table.concat(missing, " ") .. " 请补充"),
channel="WHISPER", target=target,
}
end
end
if target and (item.kind == "teamBuff" or item.kind == "combined") then
local found = false
for _, group in ipairs(item.buffGroups or {}) do
local lines = linkedBuffLines(group)
for _, line in ipairs(lines or {}) do
found = true
messages[#messages + 1] = {
message=line, channel="WHISPER", target=target,
}
end
end
if not found then
for _, clause in ipairs(splitPlain(item.buffBody, "；")) do
found = true
messages[#messages + 1] = {
message=reminderLine("请补" .. clause),
channel="WHISPER", target=target,
}
end
end
if not found then
messages[#messages + 1] = {
message=reminderLine("请补团队增益"),
channel="WHISPER", target=target,
}
end
end
end
return messages
end
local function selfBuffLine(groups, reminderName)
local links = {}
for _, group in ipairs(groups or {}) do
links[#links + 1] = spellHyperlink(group.spellId)
or (group.rule and group.rule.label) or "团队增益"
end
local who = reminderName and safeTargetName(reminderName) or "我"
if #links == 1 then
return "请给 " .. who .. " 加一个 " .. links[1] .. " Buff，谢谢！"
end
return "请给 " .. who .. " 加 " .. table.concat(links, " ") .. " Buff，谢谢！"
end
function C:BuildSelfWhisperMessages(plan)
local messages = {}
for _, item in ipairs(plan or {}) do
if item.kind == "teamBuff" and item.whisperName then
local pending = {}
local reminderName = item.reminderName
or (item.buffGroups and item.buffGroups[1] and item.buffGroups[1].targets
and item.buffGroups[1].targets[1])
local function flush()
if #pending == 0 then return end
messages[#messages + 1] = {
message=selfBuffLine(pending, reminderName), channel="WHISPER", target=item.whisperName,
}
pending = {}
end
for _, group in ipairs(item.buffGroups or {}) do
local candidate = {}
for index, value in ipairs(pending) do candidate[index] = value end
candidate[#candidate + 1] = group
if #selfBuffLine(candidate, reminderName) > LINKED_REMINDER_MESSAGE_LIMIT and #pending > 0 then
flush()
pending[1] = group
else
pending = candidate
end
end
flush()
end
end
return messages
end
local function saveDebug(key, value)
NoWCLDB = NoWCLDB or {}
NoWCLDB[key] = value
end
local function auraFingerprint(auras)
local ids = {}
for spellId in pairs(auras or {}) do ids[#ids + 1] = tonumber(spellId) or 0 end
table.sort(ids)
local parts = {}
for _, spellId in ipairs(ids) do
local aura = auras[spellId] or {}
parts[#parts + 1] = tostring(spellId) .. ":" .. tostring(aura.sourceName or "")
end
return table.concat(parts, ",")
end
function C:SnapshotFingerprint(snapshot)
local parts = {}
for _, row in ipairs(snapshot and snapshot.players or {}) do
local summary = row.consumables or {}
parts[#parts + 1] = table.concat({
tostring(row.name or ""), row.consumablesKnown == true and "1" or "0",
tostring(summary.food or 0), tostring(summary.flask or 0),
tostring(summary.combined or 0), tostring(summary.battle or 0),
tostring(summary.guardian or 0), table.concat(summary.bursts or {}, ","),
tostring(row.class or ""), tostring(row.role or ""), tostring(row.specId or 0),
tostring(row.groupLabel or ""),
auraFingerprint(row.teamAuras),
}, "|")
end
return table.concat(parts, "\n")
end
function C:Scan()
local D = NoWCL.DetailStats
local previous = self.snapshot
local previousFingerprint = previous and previous.fingerprint
self.snapshot = D and D.ScanGroupConsumables and D.ScanGroupConsumables(previous)
or { players = {}, known = 0, unknown = 0, missingFood = 0, missingMedicine = 0 }
self.snapshot.fingerprint = self:SnapshotFingerprint(self.snapshot)
return self.snapshot, self.snapshot.fingerprint ~= previousFingerprint
end
function C:GetSnapshot()
return self.snapshot
end
function C:MissingConsumables(snapshot)
snapshot = snapshot or self.snapshot
local D = NoWCL.DetailStats
local out = {}
for _, row in ipairs(snapshot and snapshot.players or {}) do
local missingFood = not (row.consumables and row.consumables.food)
local hasMedicine = D and D.HasLongMedicine and D.HasLongMedicine(row.consumables)
if row.consumablesKnown == true and (missingFood or not hasMedicine)
and row.isSelf ~= true and row.whisperName and row.whisperName ~= "" then
out[#out + 1] = {
name=row.name, whisperName=row.whisperName,
reminderName=row.reminderName,
class=row.class, groupLabel=row.groupLabel,
missingFood=missingFood, missingMedicine=not hasMedicine,
}
end
end
return out
end
function C:PreviousBuffSources()
local seg = NoWCL.Stats and NoWCL.Stats.lastCurrentSegment
local T = NoWCL.TeamBuffs
if not (seg and T and T.ObservedSourcesFromHistory) then
self._previousBuffSourcesSegment, self._previousBuffSourcesCache = nil, nil
return {}
end
if self._previousBuffSourcesSegment == seg and self._previousBuffSourcesCache then
return self._previousBuffSourcesCache
end
self._previousBuffSourcesSegment = seg
self._previousBuffSourcesCache = T:ObservedSourcesFromHistory(seg.players, seg.dur)
return self._previousBuffSourcesCache
end
local function compactTargets(names)
local joined = table.concat(names or {}, "，")
if #joined <= 96 then return joined end
local shown = {}
for _, name in ipairs(names or {}) do
local candidate = table.concat(shown, "，")
candidate = candidate ~= "" and (candidate .. "，" .. name) or name
if #candidate > 72 then break end
shown[#shown + 1] = name
end
return table.concat(shown, "，") .. string.format("等%d人", #(names or {}))
end
local function providerBody(assignment, budget)
local pieces = {}
for _, group in ipairs(assignment.groups or {}) do
local piece = group.rule.label .. " 给 " .. compactTargets(group.targets)
local candidate = table.concat(pieces, "；")
candidate = candidate .. (#pieces > 0 and "；" or "") .. piece
if #candidate <= (budget or MESSAGE_LIMIT) then
pieces[#pieces + 1] = piece
else
local remaining = #(assignment.groups or {}) - #pieces
pieces[#pieces + 1] = string.format("另%d项", remaining)
break
end
end
return table.concat(pieces, "；")
end
local function mergeSameRecipient(plan)
local out, byTarget = {}, {}
for _, item in ipairs(plan) do
local previous = byTarget[item.whisperName]
if previous and previous.kind == "consumables" and item.kind == "teamBuff" and item.buffBody then
previous.kind = "combined"
previous.buffBody = item.buffBody
previous.buffGroups = item.buffGroups
else
out[#out + 1] = item
if not previous then byTarget[item.whisperName] = item end
end
end
return out
end
function C:ReminderPlan(snapshot)
snapshot = snapshot or self.snapshot
local plan = {}
for _, row in ipairs(self:MissingConsumables(snapshot)) do
plan[#plan + 1] = {
whisperName=row.whisperName, displayName=row.name,
reminderName=row.reminderName or (NoWCL.Util and NoWCL.Util.GroupCharacterLabel
and NoWCL.Util.GroupCharacterLabel(row.name, row.class, row.groupLabel)),
missingFood=row.missingFood, missingMedicine=row.missingMedicine,
kind="consumables",
}
end
local T = NoWCL.TeamBuffs
local myName = shortName(UnitName and UnitName("player"))
local assignments = T and T.BuildProviderAssignments
and T:BuildProviderAssignments(snapshot, self:PreviousBuffSources(), myName) or {}
local whisperByName = {}
for _, row in ipairs(snapshot and snapshot.players or {}) do
if row.name and row.whisperName then whisperByName[row.name] = row.whisperName end
end
for _, assignment in ipairs(assignments) do
local whisperName = whisperByName[assignment.provider]
if whisperName and assignment.provider ~= myName then
local body = providerBody(assignment, MESSAGE_LIMIT)
plan[#plan + 1] = {
whisperName=whisperName, displayName=assignment.provider,
buffBody=body, buffGroups=assignment.groups, kind="teamBuff",
}
end
end
return mergeSameRecipient(plan)
end
local function snapshotSelf(snapshot)
local myName = shortName(UnitName and UnitName("player"))
for _, row in ipairs(snapshot and snapshot.players or {}) do
if row.isSelf == true or (myName and row.name == myName) then return row, myName end
end
return nil, myName
end
function C:SelfReminderPlan(snapshot)
snapshot = snapshot or self.snapshot
local selfRow, myName = snapshotSelf(snapshot)
if not selfRow then return {} end
local T = NoWCL.TeamBuffs
local assignments = T and T.BuildProviderAssignments
and T:BuildProviderAssignments(snapshot, self:PreviousBuffSources(), nil, selfRow.name) or {}
local rowsByName = {}
for _, row in ipairs(snapshot and snapshot.players or {}) do
if row.name then rowsByName[row.name] = row end
end
local plan = {}
for _, assignment in ipairs(assignments) do
local provider = rowsByName[assignment.provider]
local isSelfProvider = assignment.provider == selfRow.name
or (myName and assignment.provider == myName)
if isSelfProvider or (provider and provider.whisperName) then
plan[#plan + 1] = {
whisperName=not isSelfProvider and provider.whisperName or nil,
displayName=assignment.provider,
reminderName=selfRow.reminderName or (NoWCL.Util and NoWCL.Util.GroupCharacterLabel
and NoWCL.Util.GroupCharacterLabel(selfRow.name, selfRow.class, selfRow.groupLabel)),
buffGroups=assignment.groups,
kind=isSelfProvider and "selfCast" or "teamBuff",
}
end
end
return plan
end
function C:ReminderCount(snapshot)
return #self:ReminderPlan(snapshot)
end
function C:RemindMissingBuffs()
local publisher = NoWCL.GroupPublisher
if not publisher then return false end
local snapshot = self:Scan()
local plan = self:ReminderPlan(snapshot)
if #plan == 0 then return false, "empty" end
local messages = self:BuildWhisperMessages(plan)
if #messages == 0 then return false, "empty" end
saveDebug("reminderSendDebug", {
at=time and time() or 0, sender=UnitName and UnitName("player") or nil,
planned=#messages, submitted=0, channel=NoWCL.Util.GroupChannel(), state="queued",
messages=messages,
})
local ok, reason, activeChannel = publisher:Publish(messages, {
source="buff-reminder", channel="WHISPER", interval=REMIND_INTERVAL, append=true,
onSend=function()
local debug = NoWCLDB and NoWCLDB.reminderSendDebug
if debug then debug.submitted = (debug.submitted or 0) + 1 end
end,
})
if not ok then return false, reason end
NoWCLDB.reminderSendDebug.channel = activeChannel
return true, #messages
end
local function localSelfReminderText(plan)
local labels, seen = {}, {}
for _, item in ipairs(plan or {}) do
if item.kind == "selfCast" then
for _, group in ipairs(item.buffGroups or {}) do
local label = group.rule and group.rule.label or "团队增益"
if not seen[label] then seen[label] = true; labels[#labels + 1] = label end
end
end
end
if #labels == 0 then return nil end
table.sort(labels)
return "|cffffd100请自行补充：|r" .. table.concat(labels, "、")
end
function C:SendSelfReminderPlan(plan, source)
local messages = self:BuildSelfWhisperMessages(plan)
local localText = localSelfReminderText(plan)
if localText and NoWCL.Toast and NoWCL.Toast.Show then NoWCL.Toast:Show(localText, 3) end
if #messages == 0 then return localText ~= nil, localText and 1 or "empty" end
local publisher = NoWCL.GroupPublisher
if not publisher then return false, "publisher-unavailable" end
local ok, reason = publisher:Publish(messages, {
source=source or "self-buff-reminder", channel="WHISPER",
interval=REMIND_INTERVAL, append=true,
})
if not ok then return false, reason end
return true, #messages + (localText and 1 or 0)
end
function C:RemindSelfBuffs(options)
options = options or {}
local snapshot = options.snapshot or self:Scan()
local plan = options.plan or self:SelfReminderPlan(snapshot)
if #plan == 0 then
if not options.silentEmpty and NoWCL.Toast and NoWCL.Toast.Show then
NoWCL.Toast:Show("|cff44ff44当前无需催补自身团队 Buff|r", 2)
end
return false, "empty"
end
return self:SendSelfReminderPlan(plan, options.source)
end
local function autoMinutes()
local settings = NoWCL.db and NoWCL.db.settings
local value = math.floor(tonumber(settings and settings.autoSelfBuffReminderMinutes)
or DEFAULT_AUTO_SELF_REMINDER_MINUTES)
return math.max(1, math.min(10, value))
end
local function autoGroupKey(item, group)
local ruleKey = group.rule and group.rule.key or "buff"
return table.concat({ tostring(item.displayName or item.whisperName or "self"),
tostring(ruleKey), tostring(group.spellId or 0) }, "\001")
end
function C:RunAutoSelfReminder()
local settings = NoWCL.db and NoWCL.db.settings
if not (settings and settings.autoSelfBuffReminder) then return false, "disabled" end
if IsInGroup and not IsInGroup() then return false, "no-group" end
local snapshot = self:Scan()
local plan = self:SelfReminderPlan(snapshot)
local now = GetTime and GetTime() or 0
local missing, eligibleKeys, filtered = {}, {}, {}
self._autoSelfLastSent = self._autoSelfLastSent or {}
for _, item in ipairs(plan) do
local groups = {}
for _, group in ipairs(item.buffGroups or {}) do
local key = autoGroupKey(item, group)
missing[key] = true
if now - (self._autoSelfLastSent[key] or -AUTO_SELF_REMINDER_COOLDOWN)
>= AUTO_SELF_REMINDER_COOLDOWN then
groups[#groups + 1] = group
eligibleKeys[#eligibleKeys + 1] = key
end
end
if #groups > 0 then
filtered[#filtered + 1] = {
kind=item.kind, whisperName=item.whisperName,
displayName=item.displayName, reminderName=item.reminderName, buffGroups=groups,
}
end
end
for key in pairs(self._autoSelfLastSent) do
if not missing[key] then self._autoSelfLastSent[key] = nil end
end
if #filtered == 0 then return false, #plan == 0 and "empty" or "cooldown" end
local ok, result = self:SendSelfReminderPlan(filtered, "auto-self-buff-reminder")
if ok then
for _, key in ipairs(eligibleKeys) do self._autoSelfLastSent[key] = now end
end
return ok, result
end
function C:RefreshAutoReminderTimer()
if self._autoSelfTicker then self._autoSelfTicker:Cancel(); self._autoSelfTicker = nil end
local settings = NoWCL.db and NoWCL.db.settings
if not (settings and settings.autoSelfBuffReminder and C_Timer and C_Timer.NewTicker) then return end
settings.autoSelfBuffReminderMinutes = autoMinutes()
self._autoSelfTicker = C_Timer.NewTicker(settings.autoSelfBuffReminderMinutes * 60, function()
C:RunAutoSelfReminder()
end)
end
function C:Init()
self:RefreshAutoReminderTimer()
end
C.RemindMissingMedicine = C.RemindMissingBuffs
function C:OnWhisperMessage(message, sender)
if type(message) ~= "string" then return false end
local payload = message
if payload:sub(1, #CHAT_PREFIX) == CHAT_PREFIX then
payload = payload:sub(#CHAT_PREFIX + 1)
end
local legacy = payload:sub(1, #LEGACY_REMINDER_PREFIX) == LEGACY_REMINDER_PREFIX
if legacy then
payload = payload:sub(#LEGACY_REMINDER_PREFIX + 1)
end
local structured = payload:match("^%d+%-%d+%s+") ~= nil
and payload:find("「", 1, true) ~= nil
if not legacy and not structured and payload:sub(1, 3) ~= "缺"
and payload:sub(1, 6) ~= "请补" and payload:sub(1, 6) ~= "请给" then return false end
saveDebug("reminderReceiveDebug", {
at=time and time() or 0, receiver=UnitName and UnitName("player") or nil,
sender=sender, message=message,
})
return true
end
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("CHAT_MSG_WHISPER")
eventFrame:RegisterEvent("CHAT_MSG_WHISPER_INFORM")
eventFrame:SetScript("OnEvent", function(_, _, message, sender)
C:OnWhisperMessage(message, sender)
end)
