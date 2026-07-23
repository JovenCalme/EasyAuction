local _, NoWCL = ...
local RM = NoWCL.RaidManagement
local U = RM.Util
local A = { runMeta = {} }
RM.Assignment = A
local MAX_TEMPLATE_ASSIGNMENTS = 40
local DETERMINISTIC_TIE_MAX = 1000
local COMPATIBILITY_BASE = 1000000
local COMPATIBILITY_SCORE_MAX = 1500000 + DETERMINISTIC_TIE_MAX
local SOURCE_PAIR_BONUS = MAX_TEMPLATE_ASSIGNMENTS * COMPATIBILITY_SCORE_MAX + 1
local CRITICAL_PAIR_BONUS = MAX_TEMPLATE_ASSIGNMENTS
* (SOURCE_PAIR_BONUS + COMPATIBILITY_SCORE_MAX) + 1
local STABILITY_BONUS = MAX_TEMPLATE_ASSIGNMENTS
* (CRITICAL_PAIR_BONUS + SOURCE_PAIR_BONUS + COMPATIBILITY_SCORE_MAX) + 1
local REQUIRED_AREA_BONUS = MAX_TEMPLATE_ASSIGNMENTS
* (STABILITY_BONUS + CRITICAL_PAIR_BONUS + SOURCE_PAIR_BONUS + COMPATIBILITY_SCORE_MAX) + 1
local REQUIRED_SLOT_BONUS = MAX_TEMPLATE_ASSIGNMENTS
* (REQUIRED_AREA_BONUS + STABILITY_BONUS + CRITICAL_PAIR_BONUS
+ SOURCE_PAIR_BONUS + COMPATIBILITY_SCORE_MAX) + 1
A.SolverPriorities = {
maxAssignments=MAX_TEMPLATE_ASSIGNMENTS,
lowLevelMax=COMPATIBILITY_SCORE_MAX,
sourcePair=SOURCE_PAIR_BONUS,
criticalPair=CRITICAL_PAIR_BONUS,
stability=STABILITY_BONUS,
requiredArea=REQUIRED_AREA_BONUS,
requiredSlot=REQUIRED_SLOT_BONUS,
}
local ROLE_ORDER = { TANK=1, HEALER=2, DAMAGER=3, DPS=3, NONE=4 }
local SPEC_ROLE = {
[250]="TANK", [251]="DAMAGER", [252]="DAMAGER",
[102]="DAMAGER", [103]="DAMAGER", [104]="TANK", [105]="HEALER",
[253]="DAMAGER", [254]="DAMAGER", [255]="DAMAGER",
[62]="DAMAGER", [63]="DAMAGER", [64]="DAMAGER",
[268]="TANK", [269]="DAMAGER", [270]="HEALER",
[65]="HEALER", [66]="TANK", [70]="DAMAGER",
[256]="HEALER", [257]="HEALER", [258]="DAMAGER",
[259]="DAMAGER", [260]="DAMAGER", [261]="DAMAGER",
[262]="DAMAGER", [263]="DAMAGER", [264]="HEALER",
[265]="DAMAGER", [266]="DAMAGER", [267]="DAMAGER",
[71]="DAMAGER", [72]="DAMAGER", [73]="TANK",
[577]="DAMAGER", [581]="TANK",
[1467]="DAMAGER", [1468]="HEALER", [1473]="DAMAGER",
}
local MELEE_SPEC = {
[103]=true,
[250]=true, [251]=true, [252]=true,
[259]=true, [260]=true, [261]=true,
[263]=true,
[269]=true,
[70]=true,
[71]=true, [72]=true,
}
local MELEE_CLASS = { DEATHKNIGHT=true, ROGUE=true, WARRIOR=true, MONK=true, DEMONHUNTER=true }
local RANGED_CLASS = { HUNTER=true, MAGE=true, WARLOCK=true, PRIEST=true }
local PURE_DAMAGE_CLASS = { HUNTER=true, MAGE=true, ROGUE=true, WARLOCK=true }
local function normalizedRole(role)
role = tostring(role or "NONE"):upper()
if role == "DPS" then return "DAMAGER" end
return ROLE_ORDER[role] and role or "NONE"
end
local function inferredRole(player)
local role = normalizedRole(player and player.role)
if role ~= "NONE" then return role end
local specRole = SPEC_ROLE[tonumber(player and player.specId)]
if specRole then return specRole end
if PURE_DAMAGE_CLASS[tostring(player and player.class or "")] then return "DAMAGER" end
return "NONE"
end
function A:PlayerRole(player)
return inferredRole(player)
end
local function taskRoster(roster)
local out = {}
for _, player in ipairs(roster or {}) do out[#out + 1] = player end
table.sort(out, function(a, b)
local ar, br = ROLE_ORDER[inferredRole(a)] or 4, ROLE_ORDER[inferredRole(b)] or 4
if ar ~= br then return ar < br end
if tostring(a.class) ~= tostring(b.class) then return tostring(a.class) < tostring(b.class) end
return tostring(a.name) < tostring(b.name)
end)
return out
end
local function mapRoster(roster)
local out = {}
for _, player in ipairs(roster or {}) do out[#out + 1] = player end
table.sort(out, function(a, b)
local ag, bg = tonumber(a.subgroup) or 99, tonumber(b.subgroup) or 99
if ag ~= bg then return ag < bg end
local ai, bi = tonumber(a.raidIndex) or 99, tonumber(b.raidIndex) or 99
if ai ~= bi then return ai < bi end
if tostring(a.class) ~= tostring(b.class) then return tostring(a.class) < tostring(b.class) end
return tostring(a.name) < tostring(b.name)
end)
return out
end
function A:OrderedRoster(roster)
return mapRoster(roster)
end
local function ringPoint(index, count, radius, phase)
local angle = (phase or -math.pi / 2) + ((index - 1) / math.max(1, count)) * math.pi * 2
return 0.5 + math.cos(angle) * radius, 0.5 + math.sin(angle) * radius
end
function A:PlayerKind(player)
local role = inferredRole(player)
if role == "TANK" or role == "HEALER" then return role end
if role ~= "DAMAGER" then return "NONE" end
local specId, class = tonumber(player.specId), tostring(player.class or "")
if specId and MELEE_SPEC[specId] then return "MELEE" end
if MELEE_CLASS[class] then return "MELEE" end
if RANGED_CLASS[class] then return "RANGED" end
if class == "PALADIN" then return "MELEE" end
if class == "SHAMAN" or class == "DRUID" then
return specId and MELEE_SPEC[specId] and "MELEE" or "RANGED"
end
return "RANGED"
end
local function listContains(values, wanted)
if not values then return false end
for _, value in ipairs(values) do
if tostring(value) == tostring(wanted) then return true end
end
return false
end
local function classMatches(player, classes)
if not classes or #classes == 0 then return true end
for _, class in ipairs(classes) do if player.class == class then return true end end
return false
end
local function specMatches(player, specs)
if not specs or #specs == 0 then return true end
return listContains(specs, tonumber(player and player.specId))
end
local function roleMatches(player, roles)
if not roles or #roles == 0 then return true end
return listContains(roles, inferredRole(player))
end
function A:MatchesRule(player, rule)
if not classMatches(player, rule.classes) then return false end
if rule.excludeClasses and listContains(rule.excludeClasses, player.class) then return false end
if not specMatches(player, rule.specs) then return false end
if rule.excludeSpecs and listContains(rule.excludeSpecs, tonumber(player and player.specId)) then return false end
if not roleMatches(player, rule.roles) then return false end
if rule.subgroup and tonumber(player.subgroup) ~= tonumber(rule.subgroup) then return false end
local kind = self:PlayerKind(player)
if rule.kinds and #rule.kinds > 0 and not listContains(rule.kinds, kind) then return false end
if rule.kind == "DAMAGER" then return inferredRole(player) == "DAMAGER" end
return not rule.kind or kind == rule.kind
end
local function ruleAllowsSlot(rule, slotIndex)
for _, index in ipairs(rule and rule.slots or {}) do
if tonumber(index) == tonumber(slotIndex) then return true end
end
return false
end
local function ruleSpecificity(rule, ruleIndex)
local score = 0
if rule.subgroup then score = score + 80 end
if rule.classes and #rule.classes > 0 then score = score + 60 end
if rule.specs and #rule.specs > 0 then score = score + 90 end
if rule.roles and #rule.roles > 0 then score = score + 35 end
if rule.kinds and #rule.kinds > 0 then score = score + 35 end
if rule.excludeClasses and #rule.excludeClasses > 0 then score = score + 10 end
if rule.excludeSpecs and #rule.excludeSpecs > 0 then score = score + 10 end
if rule.kind == "TANK" or rule.kind == "HEALER"
or rule.kind == "MELEE" or rule.kind == "RANGED" then
score = score + 40
elseif rule.kind == "DAMAGER" then
score = score + 15
end
if rule.limit then score = score + 5 end
return score * 1000 - (tonumber(ruleIndex) or 0)
end
function A:MatchingRules(player, phase, slot)
local matches = {}
if not player or not phase or not slot then return matches end
for ruleIndex, rule in ipairs(phase.rules or {}) do
if ruleAllowsSlot(rule, slot.index) and self:MatchesRule(player, rule) then
matches[#matches + 1] = {
rule=rule, ruleIndex=ruleIndex, specificity=ruleSpecificity(rule,ruleIndex),
}
end
end
table.sort(matches,function(a,b)
if a.specificity ~= b.specificity then return a.specificity > b.specificity end
return a.ruleIndex < b.ruleIndex
end)
return matches
end
function A:MatchingRule(player, phase, slot)
local matches = self:MatchingRules(player,phase,slot)
local best = matches[1]
return best and best.rule, best and best.ruleIndex, best and best.specificity
end
function A:SlotLabels(phase, slot)
local labels = {}
for _, rule in ipairs(phase and phase.rules or {}) do
if ruleAllowsSlot(rule, slot and slot.index) then
local label = tostring(rule.label or rule.kind or "成员")
local duplicate
for _, value in ipairs(labels) do if value == label then duplicate = true; break end end
if not duplicate then labels[#labels + 1] = label end
end
end
return labels
end
function A:SlotCompatibility(player, map, phase, slot)
map = type(map) == "table" and map or RM:GetMap(map)
phase = phase or RM:GetMapPhase(map)
slot = type(slot) == "table" and slot or (phase and phase.slotById and phase.slotById[slot])
if not player or not phase or not slot then return false, "无可用规则" end
local expected = self:SlotLabels(phase, slot)
local rule = self:MatchingRule(player, phase, slot)
if rule then return true, tostring(rule.label or rule.kind or "成员") end
if #expected == 0 then return false, "该位置没有自动规则" end
return false, "需要" .. table.concat(expected, "/")
end
local assignmentMetaKey
function A:AssignmentReason(plan, map, phase, slot, player)
if not (plan and phase and slot) then return nil end
map = type(map) == "table" and map or RM:GetMap(map or plan.mapId)
local layout = RM.Plan:GetMapLayout(plan, map.id, phase.id)
if layout.locks and layout.locks[slot.id] then return "锁定保留" end
if layout.manual and layout.manual[slot.id] then return "手工指定" end
local meta = self.runMeta[assignmentMetaKey(plan,map,phase)]
if meta and meta.reasons and meta.reasons[slot.id] then return meta.reasons[slot.id] end
local rule = self:MatchingRule(player, phase, slot)
return rule and tostring(rule.label or rule.kind or "模板顺序") or "模板顺序"
end
local function rosterByName(roster)
local out = {}
for _, player in ipairs(roster or {}) do out[U.ShortName(player.name)] = player end
return out
end
local function pairKey(name, slotId)
return tostring(name or "") .. "\001" .. tostring(slotId or "")
end
assignmentMetaKey = function(plan, map, phase)
return table.concat({tostring(plan and plan.id or ""), tostring(map and map.id or ""),
tostring(phase and phase.id or "")}, "\001")
end
local function copySet(values)
local out = {}
for key, value in pairs(values or {}) do if value then out[key] = true end end
return out
end
local function addFlowEdge(graph, from, to, capacity, cost, tag)
local forward = {to=to, rev=#graph[to]+1, cap=capacity, cost=cost, tag=tag, original=capacity}
local reverse = {to=from, rev=#graph[from]+1, cap=0, cost=-cost}
graph[from][#graph[from]+1] = forward
graph[to][#graph[to]+1] = reverse
return forward
end
local function solveFlow(graph, source, sink)
local nodeCount, flow, totalCost = #graph, 0, 0
while true do
local distance, previousNode, previousEdge = {}, {}, {}
for node = 1, nodeCount do distance[node] = math.huge end
distance[source] = 0
for _ = 1, nodeCount - 1 do
local changed = false
for node = 1, nodeCount do
if distance[node] < math.huge then
for edgeIndex, edge in ipairs(graph[node]) do
if edge.cap > 0 then
local candidate = distance[node] + edge.cost
if candidate < distance[edge.to] then
distance[edge.to] = candidate
previousNode[edge.to], previousEdge[edge.to] = node, edgeIndex
changed = true
end
end
end
end
end
if not changed then break end
end
if not previousNode[sink] then break end
local node = sink
while node ~= source do
local from, edgeIndex = previousNode[node], previousEdge[node]
local edge = graph[from][edgeIndex]
edge.cap = edge.cap - 1
graph[node][edge.rev].cap = graph[node][edge.rev].cap + 1
node = from
end
flow, totalCost = flow + 1, totalCost + distance[sink]
end
return flow, totalCost
end
local function assignmentSatisfies(self, assignments, known, map, phase, slotId)
local name = U.ShortName(assignments and assignments[slotId] or "")
local player = known[name]
return player and self:SlotCompatibility(player, map, phase, slotId) and true or false
end
local function buildPreferredPairs(self, roster, map, phase, slots, fixed, used, blocked, known)
local ordered = mapRoster(roster)
local temporary, temporaryUsed = {}, copySet(used)
for slotId, name in pairs(fixed or {}) do temporary[slotId] = name end
local preferred = {}
local function place(player, slot, bonus)
if not player or not slot or blocked[slot.id] or temporary[slot.id] then return false end
local name = U.ShortName(player.name)
if name == "" or temporaryUsed[name] then return false end
temporary[slot.id], temporaryUsed[name] = name, true
preferred[pairKey(name,slot.id)] = math.max(preferred[pairKey(name,slot.id)] or 0,bonus)
return true
end
local function bestForSlot(slot)
local best, bestScore
for rosterIndex, player in ipairs(ordered) do
local name = U.ShortName(player.name)
if not temporaryUsed[name] then
local _, _, specificity = self:MatchingRule(player,phase,slot)
if specificity then
local score = specificity * 1000 - rosterIndex
if not best or score > bestScore then best, bestScore = player, score end
end
end
end
return best
end
for _, slotId in ipairs(phase.requiredSlots or {}) do
local slot = phase.slotById and phase.slotById[slotId]
if slot and not temporary[slotId] then place(bestForSlot(slot),slot,CRITICAL_PAIR_BONUS) end
end
for _, area in ipairs(phase.requiredAreas or {}) do
if area.autoFill ~= false then
local minimum = math.max(1,math.floor(tonumber(area.minimum) or 1))
local filled = 0
for _, slotId in ipairs(area.slots or {}) do
if assignmentSatisfies(self,temporary,known,map,phase,slotId) then filled=filled+1 end
end
while filled < minimum do
local selectedPlayer, selectedSlot
for _, player in ipairs(ordered) do
local name = U.ShortName(player.name)
if not temporaryUsed[name] then
for _, slotId in ipairs(area.slots or {}) do
local slot = phase.slotById and phase.slotById[slotId]
if slot and not blocked[slotId] and not temporary[slotId]
and self:SlotCompatibility(player,map,phase,slot) then
selectedPlayer, selectedSlot = player, slot
break
end
end
end
if selectedPlayer then break end
end
if not place(selectedPlayer,selectedSlot,CRITICAL_PAIR_BONUS) then break end
filled = filled + 1
end
end
end
for _, rule in ipairs(phase.rules or {}) do
local candidates = {}
for _, player in ipairs(ordered) do
local name = U.ShortName(player.name)
if not temporaryUsed[name] and self:MatchesRule(player,rule) then candidates[#candidates+1]=player end
end
local candidateIndex, placed = 1, 0
for _, slotIndex in ipairs(rule.slots or {}) do
local slot = slots[slotIndex]
if slot and not blocked[slot.id] and not temporary[slot.id] and candidates[candidateIndex] then
if place(candidates[candidateIndex],slot,SOURCE_PAIR_BONUS) then
candidateIndex, placed = candidateIndex + 1, placed + 1
if rule.limit and placed >= rule.limit then break end
end
end
end
end
return preferred
end
function A:AutoFreePositions(plan, roster)
plan.positions = plan.positions or {}
local groups = { TANK={}, HEALER={}, DAMAGER={} }
for _, player in ipairs(taskRoster(roster)) do
local role = inferredRole(player)
role = groups[role] and role or "DAMAGER"
groups[role][#groups[role] + 1] = player
end
local function save(player, x, y, role)
local current = plan.positions[player.name]
if current and current.locked then return end
plan.positions[player.name] = { x=U.Clamp(x,0.04,0.96), y=U.Clamp(y,0.04,0.96), role=role, locked=false }
end
for index, player in ipairs(groups.TANK) do save(player, 0.46+(index-1)*0.08, 0.28, "TANK") end
for index, player in ipairs(groups.HEALER) do
local x,y=ringPoint(index,#groups.HEALER,0.28,math.pi/2); save(player,x,y,"HEALER")
end
for index, player in ipairs(groups.DAMAGER) do
local radius=index<=8 and 0.18 or 0.40
local ringIndex=index<=8 and index or index-8
local ringCount=index<=8 and math.min(8,#groups.DAMAGER) or math.max(1,#groups.DAMAGER-8)
local x,y=ringPoint(ringIndex,ringCount,radius,index<=8 and 0 or math.pi/8)
save(player,x,y,"DAMAGER")
end
RM.Plan:Touch(plan)
return plan.positions
end
function A:AutoTemplatePositions(plan, roster, map, phase)
phase = phase or RM.Plan:GetPhase(plan, map.id)
local slots = phase and phase.slots or map.slots or {}
local layout = RM.Plan:GetMapLayout(plan, map.id, phase and phase.id)
local templateIssues = self:ValidateTemplate(map,phase)
if #templateIssues > 0 then
self.runMeta[assignmentMetaKey(plan,map,phase)] = {
algorithm="template-rejected",flow=0,score=0,reasons={},fixedCount=0,
templateIssues=templateIssues,
}
return layout.assignments or {}
end
local known = rosterByName(roster)
local assignments, used, blocked = {}, {}, {}
local oldAssignments = layout.assignments or {}
local previousManual = layout.manual or {}
local preservedManual = {}
for _, slot in ipairs(slots) do
local slotId = slot.id
local locked, manual = layout.locks[slotId] and true or false, previousManual[slotId] and true or false
if locked or manual then
blocked[slotId] = true
local name = U.ShortName(oldAssignments[slotId] or "")
if name ~= "" then
assignments[slotId] = name
if known[name] then used[name] = true end
if manual then preservedManual[slotId] = true end
end
end
end
local preferred = buildPreferredPairs(self,roster,map,phase,slots,assignments,used,blocked,known)
local ordered = mapRoster(roster)
local freePlayers, freeSlots = {}, {}
for _, player in ipairs(ordered) do
local name = U.ShortName(player.name)
if name ~= "" and not used[name] then freePlayers[#freePlayers+1]=player end
end
for _, slot in ipairs(slots) do
if not blocked[slot.id] and not assignments[slot.id] then freeSlots[#freeSlots+1]=slot end
end
local requiredSlots = {}
for _, slotId in ipairs(phase.requiredSlots or {}) do requiredSlots[slotId]=true end
local areas, areaBySlot = {}, {}
for areaIndex, sourceArea in ipairs(phase.requiredAreas or {}) do
local area = {source=sourceArea,index=areaIndex,slots={},fixed=0}
for _, slotId in ipairs(sourceArea.slots or {}) do
local slot = phase.slotById and phase.slotById[slotId]
if slot then
area.slots[#area.slots+1]=slotId
areaBySlot[slotId]=areaBySlot[slotId] or areaIndex
if assignmentSatisfies(self,assignments,known,map,phase,slotId) then area.fixed=area.fixed+1 end
end
end
area.minimum=math.max(1,math.floor(tonumber(sourceArea.minimum) or 1))
area.remaining=math.max(0,area.minimum-area.fixed)
areas[areaIndex]=area
end
local source = 1
local playerStart = 2
local slotStart = playerStart + #freePlayers
local areaStart = slotStart + #freeSlots
local sink = areaStart + #areas
local graph = {}
for node=1,sink do graph[node]={} end
local assignmentEdges = {}
for playerIndex, player in ipairs(freePlayers) do
local playerNode=playerStart+playerIndex-1
local name=U.ShortName(player.name)
addFlowEdge(graph,source,playerNode,1,0)
for slotIndex, slot in ipairs(freeSlots) do
local _, _, specificity = self:MatchingRule(player,phase,slot)
if specificity then
local weight=COMPATIBILITY_BASE+specificity
if requiredSlots[slot.id] then weight=weight+REQUIRED_SLOT_BONUS end
if U.ShortName(oldAssignments[slot.id] or "")==name then weight=weight+STABILITY_BONUS end
weight=weight+(preferred[pairKey(name,slot.id)] or 0)
weight=weight+math.max(0,DETERMINISTIC_TIE_MAX-playerIndex*30-slotIndex)
local edge=addFlowEdge(graph,playerNode,slotStart+slotIndex-1,1,-weight,{
player=player,slot=slot,weight=weight,
})
assignmentEdges[#assignmentEdges+1]=edge
end
end
end
for slotIndex, slot in ipairs(freeSlots) do
local slotNode=slotStart+slotIndex-1
local areaIndex=areaBySlot[slot.id]
if areaIndex then addFlowEdge(graph,slotNode,areaStart+areaIndex-1,1,0)
else addFlowEdge(graph,slotNode,sink,1,0) end
end
for areaIndex, area in ipairs(areas) do
local areaNode=areaStart+areaIndex-1
if area.remaining>0 then addFlowEdge(graph,areaNode,sink,area.remaining,-REQUIRED_AREA_BONUS) end
addFlowEdge(graph,areaNode,sink,math.max(1,#area.slots),0)
end
local flow,totalCost=solveFlow(graph,source,sink)
local reasons={}
for _, edge in ipairs(assignmentEdges) do
if edge.original==1 and edge.cap==0 then
local name,slot=U.ShortName(edge.tag.player.name),edge.tag.slot
assignments[slot.id],used[name]=name,true
local rule=self:MatchingRule(edge.tag.player,phase,slot)
local label=tostring(rule and (rule.label or rule.kind) or "模板顺序")
if requiredSlots[slot.id] then reasons[slot.id]="关键职责 · "..label
elseif areaBySlot[slot.id] then
local area=areas[areaBySlot[slot.id]]
reasons[slot.id]=tostring(area and area.source.label or "关键区域").." · "..label
elseif U.ShortName(oldAssignments[slot.id] or "")==name then reasons[slot.id]="稳定保留 · "..label
else reasons[slot.id]=label end
end
end
layout.assignments = assignments
layout.manual = preservedManual
local usedGroups = {}
for _, groupSlot in ipairs(phase and phase.groupSlots or {}) do
local subgroup = math.floor(tonumber(layout.groups[groupSlot.id]) or 0)
if subgroup >= 1 and subgroup <= 8 and not usedGroups[subgroup] then
usedGroups[subgroup] = true
else
layout.groups[groupSlot.id] = nil
end
end
for _, groupSlot in ipairs(phase and phase.groupSlots or {}) do
if not layout.groups[groupSlot.id] then
local preferred = math.floor(tonumber(groupSlot.preferred) or 0)
local subgroup = preferred >= 1 and preferred <= 8 and not usedGroups[preferred] and preferred or nil
if not subgroup then
for candidate = 1, 8 do if not usedGroups[candidate] then subgroup = candidate; break end end
end
if subgroup then layout.groups[groupSlot.id], usedGroups[subgroup] = subgroup, true end
end
end
local assignedCount=0
for _ in pairs(assignments) do assignedCount=assignedCount+1 end
self.runMeta[assignmentMetaKey(plan,map,phase)]={
algorithm="global-weighted-flow-v2",flow=flow,score=-totalCost,reasons=reasons,
fixedCount=assignedCount-flow,
}
RM.Plan:Touch(plan)
return assignments
end
function A:AutoPositions(plan, roster)
local map = RM:GetMap(plan.mapId)
local phase = RM.Plan:GetPhase(plan, map.id)
if phase and ((phase.slots and #phase.slots > 0) or (phase.groupSlots and #phase.groupSlots > 0)) then
return self:AutoTemplatePositions(plan, roster, map, phase)
end
if map.id ~= "neutral" then return {} end
return self:AutoFreePositions(plan, roster)
end
function A:AssignSlot(plan, mapId, slotId, playerName, phaseId)
local map = RM:GetMap(mapId)
local phase = RM:GetMapPhase(map, phaseId or RM.Plan:GetPhaseId(plan, map.id))
local layout = RM.Plan:GetMapLayout(plan, map.id, phase and phase.id)
if not (phase and phase.slotById[slotId]) then return false end
playerName = U.ShortName(playerName or "")
if playerName ~= "" then
for otherSlot, name in pairs(layout.assignments) do
if U.ShortName(name) == playerName then
layout.assignments[otherSlot] = nil
layout.manual[otherSlot] = nil
end
end
layout.assignments[slotId] = playerName
layout.manual[slotId] = true
else
layout.assignments[slotId] = nil
layout.manual[slotId] = nil
end
RM.Plan:Touch(plan)
return true
end
function A:ToggleSlotLock(plan, mapId, slotId, phaseId)
local layout = RM.Plan:GetMapLayout(plan, mapId, phaseId)
layout.locks[slotId] = not layout.locks[slotId] or nil
RM.Plan:Touch(plan)
return layout.locks[slotId] and true or false
end
function A:SetSlotOffset(plan, mapId, slotId, x, y, phaseId)
local map = RM:GetMap(mapId)
local phase = RM:GetMapPhase(map, phaseId or RM.Plan:GetPhaseId(plan, map.id))
local layout = RM.Plan:GetMapLayout(plan, map.id, phase and phase.id)
if not (phase and phase.slotById[slotId]) then return false end
local gridX,gridY=U.PositionGridIndex(x),U.PositionGridIndex(y)
for _,other in ipairs(phase.slots or {}) do
if other.id~=slotId then
local point=layout.offsets[other.id] or other
if U.PositionGridIndex(point.x)==gridX and U.PositionGridIndex(point.y)==gridY then
return false,"occupied",other.id
end
end
end
layout.offsets[slotId] = { x=U.PositionFromGrid(gridX), y=U.PositionFromGrid(gridY) }
return true
end
function A:SetFreePosition(plan, playerName, x, y)
playerName=U.ShortName(playerName)
local gridX,gridY=U.PositionGridIndex(x),U.PositionGridIndex(y)
for name,point in pairs(plan.positions or {}) do
if U.ShortName(name)~=playerName and type(point)=="table"
and U.PositionGridIndex(point.x)==gridX and U.PositionGridIndex(point.y)==gridY then
return false,"occupied",U.ShortName(name)
end
end
plan.positions=type(plan.positions)=="table" and plan.positions or {}
local point=plan.positions[playerName] or {}
point.x,point.y=U.PositionFromGrid(gridX),U.PositionFromGrid(gridY)
plan.positions[playerName]=point
return true
end
function A:ResetSlotOffset(plan, mapId, slotId, phaseId)
local layout = RM.Plan:GetMapLayout(plan, mapId, phaseId)
layout.offsets[slotId] = nil
RM.Plan:Touch(plan)
end
function A:ResetAllOffsets(plan, mapId, phaseId)
local layout = RM.Plan:GetMapLayout(plan, mapId, phaseId)
layout.offsets = {}
RM.Plan:Touch(plan)
end
function A:CustomLayoutKey(mapId, phaseId)
return RM.Plan:LayoutKey(mapId, phaseId)
end
function A:HasCustomOffsets(mapId, phaseId)
local db=RM:GetDB();db.customSlotLayouts=type(db.customSlotLayouts)=="table" and db.customSlotLayouts or {}
local saved = db.customSlotLayouts[self:CustomLayoutKey(mapId, phaseId)]
return type(saved) == "table"
end
function A:SaveCustomOffsets(plan, mapId, phaseId)
local layout = RM.Plan:GetMapLayout(plan, mapId, phaseId)
local db=RM:GetDB();db.customSlotLayouts=type(db.customSlotLayouts)=="table" and db.customSlotLayouts or {}
db.customSlotLayouts[self:CustomLayoutKey(mapId, phaseId)] = U.Copy(layout.offsets or {}, 4) or {}
return true
end
function A:RestoreCustomOffsets(plan, mapId, phaseId)
local db=RM:GetDB();db.customSlotLayouts=type(db.customSlotLayouts)=="table" and db.customSlotLayouts or {}
local saved = db.customSlotLayouts[self:CustomLayoutKey(mapId, phaseId)]
if type(saved) ~= "table" then return false end
local layout = RM.Plan:GetMapLayout(plan, mapId, phaseId)
layout.offsets = U.Copy(saved, 4) or {}
RM.Plan:Touch(plan)
return true
end
function A:ClearAssignments(plan, mapId, phaseId)
local layout = RM.Plan:GetMapLayout(plan, mapId, phaseId)
layout.assignments = {}
layout.locks = {}
layout.groups = {}
layout.manual = {}
RM.Plan:Touch(plan)
end
function A:SetGroup(plan, mapId, phaseId, groupSlotId, subgroup)
local map = RM:GetMap(mapId)
local phase = RM:GetMapPhase(map, phaseId or RM.Plan:GetPhaseId(plan, map.id))
if not (phase and phase.groupSlotById[groupSlotId]) then return false end
local layout = RM.Plan:GetMapLayout(plan, map.id, phase.id)
subgroup = math.floor(tonumber(subgroup) or 0)
if subgroup >= 1 and subgroup <= 8 then
for otherSlotId, otherSubgroup in pairs(layout.groups) do
if otherSlotId ~= groupSlotId and tonumber(otherSubgroup) == subgroup then
layout.groups[otherSlotId] = nil
end
end
layout.groups[groupSlotId] = subgroup
else layout.groups[groupSlotId] = nil end
RM.Plan:Touch(plan)
return true
end
function A:Unassigned(roster, assignments)
local assigned, out = {}, {}
for _, name in pairs(assignments or {}) do assigned[U.ShortName(name)] = true end
for _, player in ipairs(mapRoster(roster)) do
if not assigned[U.ShortName(player.name)] then out[#out + 1] = player end
end
return out
end
local function append(list, player, reason, slotId)
list[#list + 1] = {
player=player, name=U.ShortName(player and player.name or ""),
reason=reason, slotId=slotId,
}
end
function A:ValidateTemplate(map, phase)
map = type(map)=="table" and map or RM:GetMap(map)
phase = phase or RM:GetMapPhase(map)
local issues,slotIds,slotIndexes = {},{},{}
local function issue(reason,slotId)
issues[#issues+1]={name=slotId or (phase and phase.id) or "模板",slotId=slotId,reason=reason}
end
if not phase then issue("缺少阶段定义");return issues end
for _,slot in ipairs(phase.slots or {}) do
if type(slot.id)~="string" or slot.id=="" then issue("站位缺少唯一ID")
elseif slotIds[slot.id] then issue("站位ID重复",slot.id)
else slotIds[slot.id]=slot end
local index=tonumber(slot.index)
if not index or slotIndexes[index] then issue("站位序号缺失或重复",slot.id)
else slotIndexes[index]=slot.id end
if tonumber(slot.x)==nil or tonumber(slot.y)==nil or slot.x<0.02 or slot.x>0.98 or slot.y<0.02 or slot.y>0.98 then
issue("站位坐标越界",slot.id)
end
end
for ruleIndex,rule in ipairs(phase.rules or {}) do
local valid=0
for _,slotIndex in ipairs(rule.slots or {}) do
if slotIndexes[tonumber(slotIndex)] then valid=valid+1
else issue(string.format("第%d条规则引用无效站位%s",ruleIndex,tostring(slotIndex))) end
end
if valid==0 then issue(string.format("第%d条规则没有有效站位",ruleIndex)) end
if rule.limit then
local limit=math.floor(tonumber(rule.limit) or 0)
if limit<1 then
issue(string.format("第%d条规则人数上限无效",ruleIndex))
elseif valid>limit then
issue(string.format("第%d条规则人数上限跨多个站位，模板必须拆成独立限额槽位",ruleIndex))
end
end
end
local requiredSeen={}
for _,slotId in ipairs(phase.requiredSlots or {}) do
if requiredSeen[slotId] then issue("关键职责重复定义",slotId)
elseif not slotIds[slotId] then issue("关键职责引用无效站位",slotId)
elseif #self:SlotLabels(phase,slotIds[slotId])==0 then issue("关键职责没有兼容规则",slotId) end
requiredSeen[slotId]=true
end
local areaOwner={}
for _,area in ipairs(phase.requiredAreas or {}) do
local unique,valid={},0
for _,slotId in ipairs(area.slots or {}) do
if unique[slotId] then issue("关键区域内站位重复",slotId)
elseif not slotIds[slotId] then issue("关键区域引用无效站位",slotId)
else
unique[slotId],valid=true,valid+1
if areaOwner[slotId] and areaOwner[slotId]~=area.id and not area.allowOverlap then
issue("关键区域槽位重复定义",slotId)
else areaOwner[slotId]=area.id end
end
end
local minimum=math.max(1,math.floor(tonumber(area.minimum) or 1))
if minimum>valid then issue(string.format("%s最低人数超过区域容量",tostring(area.label or area.id or "关键区域")),area.id) end
end
local groupIds={}
for _,groupSlot in ipairs(phase.groupSlots or {}) do
if type(groupSlot.id)~="string" or groupSlot.id=="" or groupIds[groupSlot.id] then
issue("小队区域ID缺失或重复",groupSlot.id)
else groupIds[groupSlot.id]=true end
end
return issues
end
function A:AnalyzeTemplate(plan, roster, map, phase)
plan = plan or RM.Plan:GetCurrent()
map = type(map) == "table" and map or RM:GetMap(map or plan.mapId)
phase = phase or RM.Plan:GetPhase(plan, map.id)
local layout = RM.Plan:GetMapLayout(plan, map.id, phase and phase.id)
local players = mapRoster(roster)
local byName = rosterByName(players)
local diagnostics = {
unassigned={}, overflow={}, unmatched={}, sharedMarker={}, requiredEmpty={},
requiredConflicts={},manualOverrides={}, manualConflicts={}, staleAssignments={},
duplicates={},lockedEmpty={},templateConflicts={},
}
diagnostics.templateConflicts=self:ValidateTemplate(map,phase)
local assignedByName = {}
for _, slot in ipairs(phase and phase.slots or {}) do
if layout.locks and layout.locks[slot.id] and not layout.assignments[slot.id] then
diagnostics.lockedEmpty[#diagnostics.lockedEmpty+1]={
name=string.format("%d号位",tonumber(slot.index) or 0),slotId=slot.id,reason="空槽位已锁定",
}
end
end
for slotId, rawName in pairs(layout.assignments or {}) do
local name = U.ShortName(rawName)
local player = byName[name]
if assignedByName[name] then
append(diagnostics.duplicates, player or {name=name}, "同时占用多个站位", slotId)
else
assignedByName[name] = slotId
end
if not player then
append(diagnostics.staleAssignments, {name=name}, "成员已不在当前团队", slotId)
elseif layout.manual and layout.manual[slotId] then
local compatible, reason = self:SlotCompatibility(player, map, phase, slotId)
append(compatible and diagnostics.manualOverrides or diagnostics.manualConflicts,
player, compatible and "手工指定" or reason, slotId)
else
local compatible, reason = self:SlotCompatibility(player, map, phase, slotId)
if not compatible then append(diagnostics.manualConflicts, player, reason, slotId) end
end
end
local coveredGroups = {}
for groupSlotId, subgroup in pairs(layout.groups or {}) do
subgroup = tonumber(subgroup)
if subgroup then
if coveredGroups[subgroup] then
append(diagnostics.manualConflicts, {name=tostring(subgroup).."队"}, "小队被重复分配", groupSlotId)
else
coveredGroups[subgroup] = groupSlotId
end
end
end
for _, player in ipairs(players) do
local name = U.ShortName(player.name)
if not assignedByName[name] then
local subgroup = tonumber(player.subgroup)
if subgroup and coveredGroups[subgroup] then
append(diagnostics.sharedMarker, player, tostring(subgroup).."队区域", coveredGroups[subgroup])
else
local matched, hasOpen, reason = false, false, nil
for _, slot in ipairs(phase and phase.slots or {}) do
local compatible, detail = self:SlotCompatibility(player, map, phase, slot)
if compatible then
matched, reason = true, detail
if not layout.assignments[slot.id] then hasOpen = true end
end
end
if matched then
append(hasOpen and diagnostics.unassigned or diagnostics.overflow, player,
hasOpen and ("可安排为"..tostring(reason or "成员")) or "兼容槽位已满")
else
local kind = self:PlayerKind(player)
if phase and (phase.sharedAll or (phase.sharedKinds and phase.sharedKinds[kind])) then
append(diagnostics.sharedMarker, player, "使用共享"..tostring(kind).."标记")
else
append(diagnostics.unmatched, player, "没有匹配的站位规则")
end
end
end
end
end
for _, slotId in ipairs(phase and phase.requiredSlots or {}) do
local name=U.ShortName(layout.assignments[slotId] or "")
local player=byName[name]
if name=="" then
local slot = phase.slotById and phase.slotById[slotId]
diagnostics.requiredEmpty[#diagnostics.requiredEmpty + 1] = {
slotId=slotId, slotIndex=slot and slot.index, reason="关键职责尚未安排",
}
elseif not player then
append(diagnostics.requiredConflicts,{name=name},"关键职责成员已不在团队",slotId)
else
local compatible,reason=self:SlotCompatibility(player,map,phase,slotId)
if not compatible then append(diagnostics.requiredConflicts,player,"关键职责"..tostring(reason),slotId) end
end
end
for _, area in ipairs(phase and phase.requiredAreas or {}) do
local minimum = math.max(1, math.floor(tonumber(area.minimum) or 1))
local filled = 0
for _, slotId in ipairs(area.slots or {}) do
if assignmentSatisfies(self,layout.assignments,byName,map,phase,slotId) then filled = filled + 1 end
end
if filled < minimum then
diagnostics.requiredEmpty[#diagnostics.requiredEmpty + 1] = {
slotId=area.id,
reason=string.format("%s缺少%d人",tostring(area.label or area.id or "关键区域"),minimum-filled),
}
end
end
for _, groupSlot in ipairs(phase and phase.groupSlots or {}) do
if not layout.groups[groupSlot.id] then
diagnostics.requiredEmpty[#diagnostics.requiredEmpty + 1] = {
slotId=groupSlot.id, reason=(groupSlot.label or "小队区域").."尚未安排",
}
end
end
diagnostics.issueCount = #diagnostics.unassigned + #diagnostics.overflow + #diagnostics.unmatched
+ #diagnostics.requiredEmpty + #diagnostics.requiredConflicts + #diagnostics.manualConflicts
+ #diagnostics.staleAssignments + #diagnostics.duplicates + #diagnostics.lockedEmpty
+ #diagnostics.templateConflicts
diagnostics.solver=self.runMeta[assignmentMetaKey(plan,map,phase)]
return diagnostics
end
function A:AutoTasks(plan, roster)
local players = taskRoster(roster)
local tasks = RM.Plan:GetActiveTasks(plan)
local available = rosterByName(players)
local loads = {}
local changed = false
for _, task in ipairs(tasks) do
local assignee = U.ShortName(task.assignee or "")
if assignee ~= "" and assignee ~= "未知" and available[assignee] then
loads[assignee] = (loads[assignee] or 0) + 1
elseif task.autoAssign ~= false and assignee ~= "" and assignee ~= "未知" then
task.assignee = ""
changed = true
end
end
for _, task in ipairs(tasks) do
if task.autoAssign ~= false and (not task.assignee or task.assignee == "" or task.assignee == "未知") then
local best, bestLoad
for _, player in ipairs(players) do
local classCompatible = not task.classes or #task.classes == 0
for _, class in ipairs(task.classes or {}) do
if class == player.class then classCompatible = true; break end
end
if task.class and (not task.classes or #task.classes == 0) then classCompatible = task.class == player.class end
local compatible = (not task.role or task.role == inferredRole(player)) and classCompatible
local name = U.ShortName(player.name)
local load = loads[name] or 0
if compatible and (not best or load < bestLoad) then best,bestLoad=player,load end
end
if best then
local name = U.ShortName(best.name)
task.assignee=name; loads[name]=bestLoad+1; changed=true
end
end
end
if changed then RM.Plan:Touch(plan) end
return changed
end
function A:Run(plan, roster)
self:AutoTasks(plan, roster)
self:AutoPositions(plan, roster)
return plan
end
