local addonName, NoWCL = ...
local A = {}
NoWCL.PullNotice = A
local U = NoWCL.Util
local function now()
return GetTime and GetTime() or (time and time() or 0)
end
local function saveDebug(fields)
if not NoWCL.db then return end
local debug = NoWCL.db.pullAnnounceDebug or {}
for key, value in pairs(fields) do debug[key] = value end
NoWCL.db.pullAnnounceDebug = debug
end
local function npcIdFromGUID(guid)
if type(guid) ~= "string" then return nil end
return tonumber(guid:match("^[^-]+%-[^-]+%-[^-]+%-[^-]+%-[^-]+%-(%d+)%-"))
end
local function currentTargetBoss()
local rawTarget = UnitName and UnitName("target")
local target = type(rawTarget) == "string" and (rawTarget:match("^[^-]+") or rawTarget) or nil
if not target or target == "" then return nil end
local guid = UnitGUID and UnitGUID("target") or nil
if U.IsTrainingDummy and U.IsTrainingDummy(target) then
return target, target, guid, true
end
local bosses = NoWCL.WCLBosses
local boss = bosses and bosses.ObservedBossName
and bosses.ObservedBossName(npcIdFromGUID(guid), target)
if not boss and UnitClassification and UnitClassification("target") == "worldboss" then
boss = target
end
if not boss then return nil end
return boss, target, guid, false
end
local CLASS_LABELS = {
WARRIOR="战士", PALADIN="圣骑士", HUNTER="猎人", ROGUE="潜行者", PRIEST="牧师",
DEATHKNIGHT="死亡骑士", SHAMAN="萨满祭司", MAGE="法师", WARLOCK="术士", DRUID="德鲁伊",
}
local function shortName(name)
return type(name) == "string" and (name:match("^[^-]+") or name) or nil
end
local function localizedClass(class)
if not class then return "未知职业" end
return (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[class])
or (LOCALIZED_CLASS_NAMES_FEMALE and LOCALIZED_CLASS_NAMES_FEMALE[class])
or CLASS_LABELS[class] or class
end
local function resolveClass(name, fallback)
if fallback then return fallback end
local unit = U.UnitTokenByName and U.UnitTokenByName(name)
if unit and UnitClass then return select(2, UnitClass(unit)) end
local roster = NoWCL.Stats and NoWCL.Stats.roster
local info = roster and roster[shortName(name)]
return info and info.class or nil
end
function A:IsEnabled()
return NoWCL.db and NoWCL.db.settings and NoWCL.db.settings.pullAnnounce ~= false
end
function A:SetEnabled(enabled)
if NoWCL.db and NoWCL.db.settings then
NoWCL.db.settings.pullAnnounce = enabled and true or false
end
if NoWCL.SecureChatQueue and NoWCL.SecureChatQueue.ApplyEnabled then
NoWCL.SecureChatQueue:ApplyEnabled()
end
end
function A:PlainMessagePrefix(puller, class)
class = resolveClass(puller, class)
return "【NoWCL】" .. localizedClass(class) .. " " .. tostring(shortName(puller) or "?") .. " 开怪了 "
end
function A:PlainMessage(boss, puller, class)
return self:PlainMessagePrefix(puller, class) .. tostring(boss or "?")
end
function A:ActionMessage(boss, puller, class)
class = resolveClass(puller, class)
return "【NoWCL】" .. localizedClass(class) .. "开怪了 " .. tostring(boss or "?")
end
function A:IsRecentHardwareNotice(boss)
local recent = self._hardwareNotice
return recent and recent.boss == boss and now() - (recent.at or 0) <= 30
end
function A:OnHardwareTargetAction()
if not self:IsEnabled() then return false end
local boss, target, guid, isDummy = currentTargetBoss()
if not boss or self:IsRecentHardwareNotice(boss) then return false end
local puller = shortName(UnitName and UnitName("player"))
if not puller then return false end
local class = UnitClass and select(2, UnitClass("player")) or nil
local actionMessage = self:ActionMessage(boss, puller, class)
local queuedAt = now()
self._pending = {
boss=boss, puller=puller, expectedMessage=actionMessage,
queuedAt=queuedAt, confirmed=false, hardwareTarget=target,
}
self._hardwareNotice = { boss=boss, target=target, guid=guid, at=queuedAt, isDummy=isDummy }
local queue = NoWCL.SecureChatQueue
local queued = queue and queue.Enqueue and queue:Enqueue(actionMessage, "EMOTE", nil, nil,
function(ok, result) A:OnHardwareSend(ok, result) end)
saveDebug({
mode="vf-z-post-action", state=queued and "target-ready-on-hardware" or "queue-unavailable",
source=NoWCL.SafeChat and (NoWCL.SafeChat.CChatSource
and NoWCL.SafeChat:CChatSource() or NoWCL.SafeChat:Source()) or "", channel="EMOTE",
message=actionMessage, expectedMessage=actionMessage, boss=boss, puller=puller,
queuedAt=queuedAt, hardwareAt=queuedAt, hardwareTarget=target or "",
triggerKey=queue and queue.TriggerKey and queue:TriggerKey() or "",
triggerBinding=queue and queue.TriggerDescription and queue:TriggerDescription() or "",
confirmed=false, sendError=queued and "" or "secure-action-button-unavailable",
})
return queued and queue:FlushFromHardware() or false
end
function A:OnPullDetected(segment, puller, class)
if not self:IsEnabled() or not segment or not (segment.isBoss or segment.isDummy) then return false end
if segment._pullNoticeQueued then return false end
puller = shortName(puller)
local me = shortName(UnitName and UnitName("player"))
if not puller or not me or puller ~= me then return false end
local boss = segment.isDummy and segment.firstTarget or segment.name
if not boss or boss == "" then return false end
if self:IsRecentHardwareNotice(boss) then
segment._pullNoticeQueued = true
saveDebug({ combatAt=now(), matchedCombat=true })
return true
end
local actionMessage = self:ActionMessage(boss, puller, class)
self._lastDetected = {
boss=boss, puller=puller, class=resolveClass(puller, class),
message=self:PlainMessage(boss, puller, class), actionMessage=actionMessage,
}
segment._pullNoticeQueued = true
self._pending = {
boss=boss, puller=puller, expectedMessage=actionMessage,
queuedAt=now(), confirmed=false,
}
local queue = NoWCL.SecureChatQueue
local queued = queue and queue.Enqueue and queue:Enqueue(actionMessage, "EMOTE", nil, nil,
function(ok, result) A:OnHardwareSend(ok, result) end)
saveDebug({
mode="vf-hardware-chat-queue", state=queued and "queued-for-hardware" or "queue-unavailable",
source=NoWCL.SafeChat and (NoWCL.SafeChat.CChatSource
and NoWCL.SafeChat:CChatSource() or NoWCL.SafeChat:Source()) or "", channel="EMOTE",
message=actionMessage, boss=boss, puller=puller, queuedAt=self._pending.queuedAt,
wrappedButtons=queue and queue.WrappedCount and queue:WrappedCount() or 0,
triggerKey=queue and queue.TriggerKey and queue:TriggerKey() or "",
triggerBinding=queue and queue.TriggerDescription and queue:TriggerDescription() or "",
confirmed=false, sendError=queued and "" or "secure-action-button-unavailable",
})
return queued and true or false
end
function A:OnHardwareSend(ok, result)
local pending = self._pending
if not pending then return false end
pending.sentAt = now()
saveDebug({
state=ok and "sent-awaiting-echo" or "send-failed",
sentAt=pending.sentAt, confirmed=false,
sendError=ok and "" or tostring(result or "chat-api-unavailable"),
})
return ok and true or false
end
function A:OnChatMessage(event, message, sender)
local pending = self._pending
if not pending or pending.confirmed then return false end
local me = shortName(UnitName and UnitName("player"))
if not me or shortName(sender) ~= me then return false end
if type(message) ~= "string" then return false end
local expected = pending.expectedMessage
if message ~= expected and not message:find(expected, 1, true) then return false end
pending.confirmed = true
pending.confirmedAt = now()
if NoWCL.SecureChatQueue and NoWCL.SecureChatQueue.Confirm then
NoWCL.SecureChatQueue:Confirm(pending.expectedMessage)
end
saveDebug({
state="confirmed", confirmed=true, confirmedAt=pending.confirmedAt,
chatEvent=event, chatMessage=message, chatSender=sender or "",
})
return true
end
function A:Init()
if self._inited then return end
self._inited = true
if NoWCL.SecureChatQueue and NoWCL.SecureChatQueue.Init then
NoWCL.SecureChatQueue:Init()
end
local ready = {
mode="vf-z-post-action", sessionState="ready", loadedAt=now(),
source=NoWCL.SafeChat and (NoWCL.SafeChat.CChatSource
and NoWCL.SafeChat:CChatSource() or NoWCL.SafeChat:Source()) or "",
channel="EMOTE", confirmed=false,
wrappedButtons=NoWCL.SecureChatQueue and NoWCL.SecureChatQueue:WrappedCount() or 0,
activeBinding=NoWCL.SecureChatQueue and NoWCL.SecureChatQueue.ActiveBinding
and NoWCL.SecureChatQueue:ActiveBinding() or "",
triggerKey=NoWCL.SecureChatQueue and NoWCL.SecureChatQueue.TriggerKey
and NoWCL.SecureChatQueue:TriggerKey() or "",
triggerBinding=NoWCL.SecureChatQueue and NoWCL.SecureChatQueue.TriggerDescription
and NoWCL.SecureChatQueue:TriggerDescription() or "",
}
if not (NoWCL.db and NoWCL.db.pullAnnounceDebug and NoWCL.db.pullAnnounceDebug.state) then
ready.state = "ready"
end
saveDebug(ready)
if not CreateFrame then return end
local events = CreateFrame("Frame")
events:RegisterEvent("CHAT_MSG_EMOTE")
events:RegisterEvent("CHAT_MSG_TEXT_EMOTE")
events:SetScript("OnEvent", function(_, event, ...)
A:OnChatMessage(event, ...)
end)
self._eventFrame = events
end
