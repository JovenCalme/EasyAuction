local _, NoWCL = ...
local RM = NoWCL.RaidManagement
local U = RM.Util
local REC = { session=nil, watch={}, tasksById={}, maxEvidencePerTask=8 }
RM.Recorder = REC
RM.modules[#RM.modules + 1] = REC
local EXTRA_SPELL_EVENTS = {
SPELL_DISPEL=true,
SPELL_STOLEN=true,
SPELL_INTERRUPT=true,
}
function REC:Start(payload)
local plan = RM.Plan:SetCurrent(payload and payload.encounterId, payload and payload.encounterName)
local api = RM:GetNoWCLAPI()
local roster = api and api:GetRosterSnapshot() or {}
RM.Assignment:AutoTasks(plan, roster)
local assignmentAudit = RM.Review:BuildAssignmentAudit(plan,roster)
self.watch = RM.Plan:WatchIndex(plan)
self.tasksById = {}
local taskStats = {}
for _, task in ipairs(RM.Plan:GetActiveTasks(plan)) do
self.tasksById[task.id] = task
taskStats[task.id] = { count=0, evidence={} }
end
local rosterByName = {}
for _, player in ipairs(roster) do
local name = U.ShortName(player.name)
if name ~= "" and name ~= "未知" then
rosterByName[name] = {
role=RM.Assignment:PlayerRole(player), class=player.class, specId=player.specId,
}
end
end
self.session = {
encounterId=payload and payload.encounterId,
encounterName=payload and payload.encounterName or plan.name,
startedAt=GetTime(), startedWall=time(), taskStats=taskStats, deaths={}, roster=rosterByName,
assignmentAudit=assignmentAudit,
plan=U.Copy(plan, 9),
}
RM:Refresh()
end
function REC:Finish(payload)
local session = self.session
if not session then return end
session.endedAt = GetTime()
session.success = payload and payload.success and true or false
self.session = nil
self.watch = {}
self.tasksById = {}
RM.Review:Build(session.plan or RM.Plan:GetCurrent(), session, session.success)
end
function REC:HandleCLEU(event)
local session = self.session
if not session then return end
local subevent = event[2]
if subevent == "UNIT_DIED" then
local name = U.ShortName(event[9])
if name and session.roster[name] then
session.deaths[#session.deaths + 1] = { name=name, at=math.max(0, event[1] - session.startedAt) }
end
return
end
local bySpell = self.watch[subevent]
if not bySpell then return end
local primarySpellId = tonumber(event[12])
local extraSpellId = EXTRA_SPELL_EVENTS[subevent] and tonumber(event[15]) or nil
local matchedTasks = {}
local function addMatches(spellId, prefer)
for _, taskId in ipairs(spellId and bySpell[spellId] or {}) do
if not matchedTasks[taskId] or prefer then matchedTasks[taskId] = spellId end
end
end
addMatches(primarySpellId, false)
addMatches(extraSpellId, true)
if not next(matchedTasks) then return end
local source, target = U.ShortName(event[5]), U.ShortName(event[9])
local sourceInfo, targetInfo = session.roster[source] or {}, session.roster[target] or {}
local at = math.max(0, (tonumber(event[1]) or GetTime()) - session.startedAt)
for taskId, matchedSpellId in pairs(matchedTasks) do
local task = self.tasksById[taskId]
local evidence = {
taskId=taskId, subevent=subevent, spellId=matchedSpellId,
triggerSpellId=primarySpellId, extraSpellId=extraSpellId,
source=source, target=target, at=at,
sourceRole=sourceInfo.role,sourceClass=sourceInfo.class,
targetRole=targetInfo.role,targetClass=targetInfo.class,
}
if task and RM.Review:EventMatches(task, evidence) then
local stats = session.taskStats[taskId]
if stats then
stats.count = (stats.count or 0) + 1
if #stats.evidence < self.maxEvidencePerTask then
stats.evidence[#stats.evidence + 1] = evidence
end
end
end
end
end
function REC:OnLogin()
local api = RM:GetNoWCLAPI()
api:Subscribe("ENCOUNTER_START", self, function(payload) REC:Start(payload) end)
api:Subscribe("ENCOUNTER_END", self, function(payload) REC:Finish(payload) end)
self.frame = self.frame or CreateFrame("Frame")
self.frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
self.frame:SetScript("OnEvent", function()
if not REC.session then return end
REC:HandleCLEU({ CombatLogGetCurrentEventInfo() })
end)
end
function REC:OnLogout()
local api = RM:GetNoWCLAPI()
if api then
api:Unsubscribe("ENCOUNTER_START", self)
api:Unsubscribe("ENCOUNTER_END", self)
end
end
