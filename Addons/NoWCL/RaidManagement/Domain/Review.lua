local _, NoWCL = ...
local RM = NoWCL.RaidManagement
local U = RM.Util
local R = {}
RM.Review = R
local function listContains(values, value)
if not values or #values == 0 then return true end
for _, candidate in ipairs(values) do if candidate == value then return true end end
return false
end
local function tableCount(values)
local count = 0
for _ in pairs(values or {}) do count = count + 1 end
return count
end
function R:EventMatches(task, event)
if event.taskId ~= task.id then return false end
if task.assignee and task.assignee ~= "" then
local assignee = U.ShortName(task.assignee)
local subject = task.subject or "source"
local matched = subject == "target" and U.ShortName(event.target) == assignee
or subject == "any" and (U.ShortName(event.source) == assignee or U.ShortName(event.target) == assignee)
or subject == "source" and U.ShortName(event.source) == assignee
if not matched then return false end
end
if not listContains(task.sourceRoles, event.sourceRole) then return false end
if not listContains(task.targetRoles, event.targetRole) then return false end
if task.expectedAt > 0 and math.abs((event.at or 0) - task.expectedAt) > task.tolerance then return false end
return true
end
local function verdict(task, observed)
local mode = task.mode or "minimum"
if mode == "observe" then return "observe", true, "仅记录，不参与评分" end
if mode == "maximum" then
local maximum = math.max(0, tonumber(task.maximum) or 0)
if observed <= maximum then return "pass", true, string.format("未超过上限 %d 次",maximum) end
return "miss", false, string.format("超过上限 %d 次",observed-maximum)
end
local minimum = math.max(1, tonumber(task.minimum or task.count) or 1)
if observed >= minimum then return "pass", true, string.format("达到至少 %d 次",minimum) end
return "miss", false, string.format("少于要求，缺少 %d 次",minimum-observed)
end
function R:BuildAssignmentAudit(plan, roster)
plan = plan or RM.Plan:GetCurrent()
local map = RM:GetMap(plan.mapId)
local phase = RM.Plan:GetPhase(plan, map.id)
local hasSlots = phase and phase.slots and #phase.slots > 0
local hasGroups = phase and phase.groupSlots and #phase.groupSlots > 0
if not hasSlots and not hasGroups then
return {
status="dynamic",mapId=map.id,phaseId=phase and phase.id,
phaseName=phase and phase.name,issueCount=0,issues={},
}
end
local diagnostics = RM.Assignment:AnalyzeTemplate(plan,roster,map,phase)
local layout = RM.Plan:GetMapLayout(plan,map.id,phase and phase.id)
local audit = {
status=diagnostics.issueCount > 0 and "issue" or "complete",
mapId=map.id,phaseId=phase and phase.id,phaseName=phase and phase.name,
issueCount=diagnostics.issueCount or 0,issues={},
assigned=tableCount(layout.assignments),shared=#(diagnostics.sharedMarker or {}),
groups=tableCount(layout.groups),
}
local categories = {
{"关键职责",diagnostics.requiredEmpty},{"关键冲突",diagnostics.requiredConflicts},
{"待安排",diagnostics.unassigned},
{"容量不足",diagnostics.overflow},{"无匹配",diagnostics.unmatched},
{"手工冲突",diagnostics.manualConflicts},{"成员离队",diagnostics.staleAssignments},
{"重复占位",diagnostics.duplicates},{"空位锁定",diagnostics.lockedEmpty},
{"模板冲突",diagnostics.templateConflicts},
}
for _, category in ipairs(categories) do
for _, item in ipairs(category[2] or {}) do
if #audit.issues >= 12 then break end
audit.issues[#audit.issues + 1] = {
category=category[1],name=item.name,slotId=item.slotId,reason=item.reason,
}
end
if #audit.issues >= 12 then break end
end
return audit
end
function R:Build(plan, session, success)
local review = {
id = U.NewId("review"), planId=plan.id, planKey=plan.key, planRevision=plan.revision,
encounterId=session.encounterId, encounterName=session.encounterName,
startedAt=session.startedWall, duration=math.max(0, (session.endedAt or GetTime()) - session.startedAt),
success=success and true or false, tasks={}, deaths=U.Copy(session.deaths or {}, 5),
assignmentAudit=U.Copy(session.assignmentAudit,6),
}
local passed, scoreable = 0, 0
local tasks = RM.Plan:GetActiveTasks(plan)
for _, task in ipairs(tasks) do
local observed, evidence = 0, {}
local stats = session.taskStats and session.taskStats[task.id]
if stats then
observed = math.max(0, math.floor(tonumber(stats.count) or 0))
evidence = U.Copy(stats.evidence or {}, 4)
else
for _, event in ipairs(session.events or {}) do
if self:EventMatches(task, event) then
observed = observed + 1
if #evidence < 8 then evidence[#evidence + 1] = U.Copy(event, 3) end
end
end
end
local status, ok, reason = verdict(task, observed)
if (task.mode or "minimum") ~= "observe" then
scoreable = scoreable + 1
if ok then passed = passed + 1 end
end
review.tasks[#review.tasks + 1] = {
id=task.id, name=task.name, type=task.type, spellId=task.spellId,
spellIds=U.Copy(task.spellIds or {},3),events=U.Copy(task.events or {},3),
assignee=task.assignee,mode=task.mode or "minimum",subject=task.subject or "source",
minimum=task.minimum or task.count or 1,maximum=task.maximum or 0,
expected=(task.mode=="maximum" and task.maximum) or task.minimum or task.count or 1,
observed=observed,status=status,reason=reason,evidence=evidence,
phaseId=task.phaseId,mapId=task.mapId,templateId=task.templateId,
}
end
review.passed = passed
review.total = scoreable
review.taskCount = #tasks
review.score = scoreable > 0 and passed / scoreable or nil
local db = RM:GetDB()
table.insert(db.reviews, 1, review)
local limit = db.settings.maxReviews or 30
while #db.reviews > limit do table.remove(db.reviews) end
RM:Refresh()
return review
end
function R:Latest()
return RM:GetDB().reviews[1]
end
