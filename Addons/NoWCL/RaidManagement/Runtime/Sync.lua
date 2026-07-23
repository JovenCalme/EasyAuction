local _, NoWCL = ...
local RM = NoWCL.RaidManagement
local U = RM.Util
local S = {
prefix="NCLRaidMgmt1", protocol=11, outgoing={}, received={}, authorities={},
latestActivationBySender={}, pageOpenByName={}, observedAcks={},
status="尚未同步", snapshotRepeatSeconds=3, ackConfirmSettleSeconds=0.6,
}
RM.Sync = S
RM.modules[#RM.modules + 1] = S
local function bool(value) return value and "1" or "0" end
local function join(values)
local out={};for _,value in ipairs(values or {}) do out[#out+1]=tostring(value) end
return table.concat(out,",")
end
local function sortedKeys(values)
local keys = {}
for key in pairs(values or {}) do keys[#keys + 1] = key end
table.sort(keys, function(a,b) return tostring(a) < tostring(b) end)
return keys
end
function S:NextActivationId()
local second = math.max(0, math.floor(tonumber(time and time() or 0) or 0))
if second ~= self.activationSecond then
self.activationSecond = second
self.activationCounter = 0
end
self.activationCounter = math.min(9999, (tonumber(self.activationCounter) or 0) + 1)
local db = RM:GetDB()
local previous = math.max(0, tonumber(db.lastSyncActivationId) or 0)
local activationId = math.max(second * 10000 + self.activationCounter, previous + 1)
db.lastSyncActivationId = activationId
return activationId
end
function S:EncodeLegacyPlan(plan)
local lines = {
table.concat({"P",U.Escape(plan.id),U.Escape(plan.key),U.Escape(plan.name),
U.Escape(plan.mapId),tostring(plan.revision or 1),tostring(self.protocol)}, "|"),
}
local contractMaps = {[tostring(plan.mapId or "neutral")]=true}
for mapId in pairs(plan.phaseIds or {}) do contractMaps[tostring(mapId)] = true end
for layoutKey in pairs(plan.mapLayouts or {}) do
contractMaps[tostring(layoutKey):match("^[^@]+") or tostring(layoutKey)] = true
end
for _, mapId in ipairs(sortedKeys(contractMaps)) do
local map = RM.MapById and RM.MapById[mapId]
if map and map.templateContract then
lines[#lines + 1] = table.concat({"K",U.Escape(mapId),U.Escape(map.templateContract)}, "|")
end
end
for _, mapId in ipairs(sortedKeys(plan.taskTemplateVersions)) do
local version = plan.taskTemplateVersions[mapId]
lines[#lines + 1] = table.concat({"Q",U.Escape(mapId),tostring(version or 0)}, "|")
end
for _, mapId in ipairs(sortedKeys(plan.dismissedTemplateTasks)) do
local dismissed = plan.dismissedTemplateTasks[mapId]
for _, templateId in ipairs(sortedKeys(dismissed)) do
local value = dismissed[templateId]
if value then lines[#lines + 1] = table.concat({"D",U.Escape(mapId),U.Escape(templateId)}, "|") end
end
end
for _, task in ipairs(plan.tasks or {}) do
lines[#lines + 1] = table.concat({"T",U.Escape(task.id),U.Escape(task.name),task.type,
tostring(task.spellId or 0),task.event,tostring(task.expectedAt or 0),
tostring(task.tolerance or 8),tostring(task.count or 1),U.Escape(task.assignee),
U.Escape(task.role),U.Escape(task.class),U.Escape(task.mode),U.Escape(task.subject),
join(task.spellIds),join(task.events),tostring(task.minimum or task.count or 1),
tostring(task.maximum or 0),U.Escape(task.phaseId),U.Escape(task.mapId),
U.Escape(task.templateId),bool(task.autoAssign ~= false),join(task.targetRoles),join(task.sourceRoles),
join(task.classes)}, "|")
end
for _, name in ipairs(sortedKeys(plan.positions)) do
local point = plan.positions[name]
lines[#lines + 1] = table.concat({"X",U.Escape(name),string.format("%.4f",point.x or 0.5),
string.format("%.4f",point.y or 0.5),U.Escape(point.role),bool(point.locked)}, "|")
end
for _, mapId in ipairs(sortedKeys(plan.phaseIds)) do
local phaseId = plan.phaseIds[mapId]
lines[#lines + 1] = table.concat({"H",U.Escape(mapId),U.Escape(phaseId)}, "|")
end
for _, mapId in ipairs(sortedKeys(plan.mapLayouts)) do
local layout = plan.mapLayouts[mapId]
local layoutSlots={}
for slotId in pairs(layout.assignments or {}) do layoutSlots[slotId]=true end
for slotId in pairs(layout.locks or {}) do layoutSlots[slotId]=true end
for slotId in pairs(layout.manual or {}) do layoutSlots[slotId]=true end
for _, slotId in ipairs(sortedKeys(layoutSlots)) do
local name = layout.assignments and layout.assignments[slotId] or ""
lines[#lines + 1] = table.concat({"L",U.Escape(mapId),U.Escape(slotId),U.Escape(name),
bool(layout.locks and layout.locks[slotId]),bool(layout.manual and layout.manual[slotId])}, "|")
end
for _, slotId in ipairs(sortedKeys(layout.offsets)) do
local point = layout.offsets[slotId]
lines[#lines + 1] = table.concat({"O",U.Escape(mapId),U.Escape(slotId),
string.format("%.4f",point.x or 0.5),string.format("%.4f",point.y or 0.5)}, "|")
end
for _, slotId in ipairs(sortedKeys(layout.groups)) do
local subgroup = layout.groups[slotId]
lines[#lines + 1] = table.concat({"G",U.Escape(mapId),U.Escape(slotId),tostring(subgroup)}, "|")
end
end
return table.concat(lines, "\n")
end
function S:DecodeLegacyPlan(payload)
if type(payload) ~= "string" or #payload > 40000 then return nil, "payload_size" end
local plan, layoutRows
for line in payload:gmatch("[^\n]+") do
local fields = U.Split(line, "|")
if fields[1] == "P" and not plan then
plan = { id=U.Unescape(fields[2]), key=U.Unescape(fields[3]), name=U.Unescape(fields[4]),
mapId=U.Unescape(fields[5]), revision=tonumber(fields[6]) or 1, protocol=tonumber(fields[7]) or 1,
tasks={}, positions={}, mapLayouts={}, phaseIds={}, templateContracts={},
taskTemplateVersions={},dismissedTemplateTasks={} }
elseif fields[1] == "T" and plan and #plan.tasks < 80 then
plan.tasks[#plan.tasks + 1] = { id=U.Unescape(fields[2]), name=U.Unescape(fields[3]),
type=fields[4], spellId=tonumber(fields[5]), event=fields[6], expectedAt=tonumber(fields[7]),
tolerance=tonumber(fields[8]), count=tonumber(fields[9]), assignee=U.Unescape(fields[10]),
role=U.Unescape(fields[11]), class=U.Unescape(fields[12]),mode=U.Unescape(fields[13]),
subject=U.Unescape(fields[14]),spellIds=fields[15] and U.Split(fields[15],",") or nil,
events=fields[16] and U.Split(fields[16],",") or nil,minimum=tonumber(fields[17]),
maximum=tonumber(fields[18]),phaseId=U.Unescape(fields[19]),mapId=U.Unescape(fields[20]),
templateId=U.Unescape(fields[21]),autoAssign=fields[22]~="0",
targetRoles=fields[23] and U.Split(fields[23],",") or nil,
sourceRoles=fields[24] and U.Split(fields[24],",") or nil,
classes=fields[25] and U.Split(fields[25],",") or nil }
elseif fields[1] == "Q" and plan then
local mapId=U.Unescape(fields[2]);if mapId~="" then plan.taskTemplateVersions[mapId]=tonumber(fields[3]) or 0 end
elseif fields[1] == "D" and plan then
local mapId,templateId=U.Unescape(fields[2]),U.Unescape(fields[3])
if mapId~="" and templateId~="" then
plan.dismissedTemplateTasks[mapId]=plan.dismissedTemplateTasks[mapId] or {}
plan.dismissedTemplateTasks[mapId][templateId]=true
end
elseif fields[1] == "X" and plan then
local name = U.Unescape(fields[2])
if name ~= "" then plan.positions[name] = { x=U.Clamp(fields[3],0.02,0.98),
y=U.Clamp(fields[4],0.02,0.98), role=U.Unescape(fields[5]), locked=fields[6]=="1" } end
elseif fields[1] == "H" and plan then
local mapId, phaseId = U.Unescape(fields[2]), U.Unescape(fields[3])
if mapId ~= "" and phaseId ~= "" then plan.phaseIds[mapId] = phaseId end
elseif fields[1] == "K" and plan then
local mapId, contract = U.Unescape(fields[2]), U.Unescape(fields[3])
if mapId ~= "" and contract ~= "" then plan.templateContracts[mapId] = contract end
elseif (fields[1] == "L" or fields[1] == "O" or fields[1] == "G") and plan then
layoutRows = (layoutRows or 0) + 1
if layoutRows <= 512 then
local mapId, slotId = U.Unescape(fields[2]), U.Unescape(fields[3])
if mapId ~= "" and slotId ~= "" then
local layout = plan.mapLayouts[mapId]
if not layout then layout={assignments={},offsets={},locks={},groups={},manual={}}; plan.mapLayouts[mapId]=layout end
if fields[1] == "L" then
local name = U.Unescape(fields[4])
if name ~= "" then layout.assignments[slotId]=name end
if fields[5] == "1" then layout.locks[slotId]=true end
if fields[6] == "1" then layout.manual[slotId]=true end
elseif fields[1] == "O" then
layout.offsets[slotId] = { x=U.Clamp(fields[4],0.02,0.98), y=U.Clamp(fields[5],0.02,0.98) }
else
local subgroup = math.floor(tonumber(fields[4]) or 0)
if subgroup >= 1 and subgroup <= 8 then layout.groups[slotId] = subgroup end
end
end
end
end
end
if not plan or plan.id == "" or plan.key == "" then return nil, "invalid_plan" end
if (plan.protocol or 1) > self.protocol then return nil, "unsupported_protocol" end
local requiredContracts = {[tostring(plan.mapId or "neutral")]=true}
for mapId in pairs(plan.phaseIds or {}) do requiredContracts[tostring(mapId)] = true end
for layoutKey in pairs(plan.mapLayouts or {}) do
requiredContracts[tostring(layoutKey):match("^[^@]+") or tostring(layoutKey)] = true
end
for mapId in pairs(requiredContracts) do
local localMap = RM.MapById and RM.MapById[mapId]
local remoteContract = plan.templateContracts and plan.templateContracts[mapId]
if not localMap or not localMap.templateContract then return nil, "unknown_template", mapId end
if (plan.protocol or 1) >= 4 then
if tostring(remoteContract or "") ~= tostring(localMap.templateContract) then
return nil, "template_mismatch", mapId
end
elseif plan.mapLayouts and next(plan.mapLayouts) then
return nil, "template_contract_missing", mapId
end
end
return plan
end
function S:ValidatePlan(plan)
if not plan or type(plan) ~= "table" or tostring(plan.id or "") == "" or tostring(plan.key or "") == "" then
return nil, "invalid_plan"
end
if (tonumber(plan.protocol) or 1) > self.protocol then return nil, "unsupported_protocol" end
local requiredContracts = {[tostring(plan.mapId or "neutral")]=true}
for mapId in pairs(plan.phaseIds or {}) do requiredContracts[tostring(mapId)] = true end
for layoutKey in pairs(plan.mapLayouts or {}) do
requiredContracts[tostring(layoutKey):match("^[^@]+") or tostring(layoutKey)] = true
end
for mapId in pairs(requiredContracts) do
local localMap = RM.MapById and RM.MapById[mapId]
local remoteContract = plan.templateContracts and plan.templateContracts[mapId]
if not localMap or not localMap.templateContract then return nil, "unknown_template", mapId end
if tostring(remoteContract or "") ~= tostring(localMap.templateContract) then
return nil, "template_mismatch", mapId
end
end
return plan
end
function S:EncodePlan(plan)
if RM.SnapshotCodec and RM.SnapshotCodec.Encode then
return RM.SnapshotCodec:Encode(plan,self.protocol)
end
return self:EncodeLegacyPlan(plan)
end
function S:DecodePlan(payload, protocol)
local marker=type(payload)=="string" and payload:sub(1,1)
if (marker=="B" or marker=="Z") and RM.SnapshotCodec and RM.SnapshotCodec.Decode then
local plan,reason=RM.SnapshotCodec:Decode(payload,protocol)
if not plan then return nil,reason end
return self:ValidatePlan(plan)
end
return self:DecodeLegacyPlan(payload)
end
function S:BuildEnvelope(transferId, checksum, activationId, payload)
return table.concat({"S",tostring(transferId),tostring(checksum),tostring(self.protocol),
string.format("%.0f",tonumber(activationId) or 0),tostring(payload or "")}, "|")
end
function S:ParseEnvelope(message)
if type(message) ~= "string" then return nil end
local transferId, checksum, protocol, activationId, payload =
message:match("^S|([^|]+)|(%d+)|(%d+)|(%d+)|(.*)$")
if not transferId or #transferId > 80 then return nil end
return transferId, tonumber(checksum), tonumber(protocol), tonumber(activationId), payload
end
function S:SendRaw(message, channel, onComplete, target, priority)
if not (RM.Transport and RM.Transport.Send) then return false, "transport unavailable" end
return RM.Transport:Send(self.prefix, message, channel, target, onComplete, priority)
end
local function expectedRecipients()
local api = RM.GetNoWCLAPI and RM:GetNoWCLAPI()
local own = U.ShortName(UnitName("player"))
local out = {}
for _, peer in ipairs(api and api.GetAddonPeers and api:GetAddonPeers() or {}) do
local name = U.ShortName(type(peer)=="table" and peer.name or peer)
if name ~= "" and name ~= own then out[name] = true end
end
return out
end
local function rosterMember(name)
name=U.ShortName(name)
local api=RM.GetNoWCLAPI and RM:GetNoWCLAPI()
for _,player in ipairs(api and api.GetRosterSnapshot and api:GetRosterSnapshot() or {}) do
if U.ShortName(player.name)==name and player.online~=false then return true end
end
return false
end
local function countSet(values)
local count = 0
for _ in pairs(values or {}) do count = count + 1 end
return count
end
local function countResponses(transfer)
local names = {}
for _, responses in ipairs({transfer.acks,transfer.incompatible,transfer.templateMismatch,transfer.rejected}) do
for name in pairs(responses or {}) do names[name] = true end
end
return countSet(names)
end
local function expectedResponse(transfer, sender)
if not transfer then return false end
local name = U.ShortName(sender)
if name == "" or name == U.ShortName(UnitName("player")) then return false end
if not rosterMember(name) then return false end
transfer.expected[name]=true
return true
end
function S:RefreshExpected(transfer)
if not transfer then return end
for name in pairs(expectedRecipients()) do transfer.expected[name]=true end
for name in pairs(transfer.expected or {}) do
if not rosterMember(name) then
transfer.expected[name]=nil
transfer.acks[name]=nil
transfer.incompatible[name]=nil
transfer.templateMismatch[name]=nil
transfer.rejected[name]=nil
transfer.retryable[name]=nil
end
end
end
function S:GetReceiptStatus(transfer)
transfer=transfer or (self.latestBroadcastId and self.outgoing[self.latestBroadcastId])
local info={received={},missing={},terminal={},total=0,acked=0}
if not transfer then info.done=true;return info end
self:RefreshExpected(transfer)
for name in pairs(transfer.expected or {}) do
info.total=info.total+1
if transfer.acks[name] then info.acked=info.acked+1;info.received[#info.received+1]=name
elseif transfer.incompatible[name] or transfer.templateMismatch[name] or transfer.rejected[name] then
info.terminal[#info.terminal+1]=name
else info.missing[#info.missing+1]=name end
end
table.sort(info.received);table.sort(info.missing);table.sort(info.terminal)
info.done=#info.missing==0
return info
end
function S:GetRosterSyncStates()
local api=RM.GetNoWCLAPI and RM:GetNoWCLAPI()
local roster=api and api.GetRosterSnapshot and api:GetRosterSnapshot() or {}
local own=U.ShortName(UnitName("player"));local peers=expectedRecipients()
local transfer=self.latestBroadcastId and self.outgoing[self.latestBroadcastId]
local activeTransferId=transfer and transfer.id or self.lastAppliedTransferId
local rows={}
for _,player in ipairs(roster) do
local name=U.ShortName(player.name);local isSelf=name==own
local addon=isSelf or peers[name] or false
local open=isSelf and self.positionPageOpen or self.pageOpenByName[name]==true
local state
if not addon then state="missing"
elseif not open then state="closed"
elseif isSelf then state="synced"
elseif transfer and transfer.acks[name] then state="synced"
elseif activeTransferId and self.observedAcks[name]==activeTransferId then state="synced"
else state="syncing" end
rows[#rows+1]={name=name,state=state,subgroup=player.subgroup,
subgroupSlot=player.subgroupSlot,raidIndex=player.raidIndex,class=player.class}
end
table.sort(rows,function(a,b)
local ai,bi=tonumber(a.raidIndex) or 999,tonumber(b.raidIndex) or 999
if ai~=bi then return ai<bi end
return tostring(a.name)<tostring(b.name)
end)
return rows
end
function S:GetAuthoritySyncState()
local api=RM.GetNoWCLAPI and RM:GetNoWCLAPI()
local roster=api and api.GetRosterSnapshot and api:GetRosterSnapshot() or {}
local plan=RM.Plan and RM.Plan:GetCurrent()
local authority=plan and self.authorities[tostring(plan.key or "")]
local authorityName=authority and U.ShortName(authority.sender) or ""
if authorityName=="" or U.GroupRank(authorityName)~=2 then
for _,player in ipairs(roster) do
if tonumber(player.rank)==2 or U.GroupRank(player.name)==2 then
authorityName=U.ShortName(player.name)
break
end
end
end
local row
for _,player in ipairs(roster) do
if U.ShortName(player.name)==authorityName then row=player;break end
end
local applied=authority and U.ShortName(authority.sender)==authorityName
and self.lastAppliedTransferId and self.confirmedTransferId==self.lastAppliedTransferId
return {
name=authorityName~="" and authorityName or "团长端",
state=applied and "synced" or "syncing",
subgroup=row and row.subgroup,subgroupSlot=row and row.subgroupSlot,
raidIndex=row and row.raidIndex,class=row and row.class,
}
end
function S:SendPageState(open, target)
local channel=target and "WHISPER" or U.GroupChannel()
if not channel then return false end
return self:SendRaw("P|"..(open and "1" or "0"),channel,nil,target)
end
function S:UpdateOutgoingStatus(transfer)
if not transfer then return end
if self.latestBroadcastId and transfer.id ~= self.latestBroadcastId then return end
local receipt=self:GetReceiptStatus(transfer)
local total = receipt.total
local received = receipt.acked
local incompatible = countSet(transfer.incompatible)
local templateMismatch = countSet(transfer.templateMismatch)
local rejected = countSet(transfer.rejected)
local retryable = countSet(transfer.retryable)
local terminal=incompatible+templateMismatch+rejected
if total > 0 then
local formatText=transfer.timedOut and "同步超时 %d/%d%s%s"
or (receipt.done and terminal>0) and "同步结束 %d/%d%s%s"
or receipt.done and "全团已确认 %d/%d%s%s" or "同步中 %d/%d%s%s"
self.status = string.format(formatText, received, total,
incompatible > 0 and string.format("  ·  %d人版本不兼容", incompatible) or "",
templateMismatch > 0 and string.format("  ·  %d人模板不一致", templateMismatch) or "")
if rejected > 0 then self.status = self.status .. string.format("  ·  %d人拒绝当前方案",rejected) end
if retryable > 0 then self.status = self.status .. string.format("  ·  %d人等待团队名单一致",retryable) end
else
self.status = "完整方案已广播  ·  暂无其他 NoWCL 用户"
end
RM:Refresh()
end
function S:GetMatchingTransfer(key, checksum)
local transfer=self.latestBroadcastId and self.outgoing[self.latestBroadcastId]
if not transfer or transfer.timedOut then return nil end
if tostring(transfer.planKey or "")~=tostring(key or "")
or tonumber(transfer.checksum)~=tonumber(checksum) then return nil end
return transfer
end
function S:ContinueTransfer(transfer)
if not transfer or self.outgoing[transfer.id]~=transfer then return false end
self:RefreshExpected(transfer)
local receipt=self:GetReceiptStatus(transfer)
if receipt.done then
transfer.completed=true
self:UpdateOutgoingStatus(transfer)
return true
end
transfer.completed=false
local now=GetTime and GetTime() or 0
if not transfer.queueing
and now-(tonumber(transfer.lastQueuedAt) or -100)>=self.snapshotRepeatSeconds then
return self:QueueTransfer(transfer,true)
end
self:UpdateOutgoingStatus(transfer)
return true
end
function S:QueueTransfer(transfer, retrying)
if not transfer or self.outgoing[transfer.id] ~= transfer then return false end
if transfer.queueing then return true end
transfer.queueing=true
transfer.lastQueuedAt=GetTime and GetTime() or 0
transfer.queueAttempt = (tonumber(transfer.queueAttempt) or 0) + 1
local attempt = transfer.queueAttempt
transfer.cleanupSerial = (tonumber(transfer.cleanupSerial) or 0) + 1
local cleanupSerial = transfer.cleanupSerial
transfer.queueComplete = false
local ok, detail = self:SendRaw(transfer.message, transfer.channel, function(success, result)
local current = S.outgoing[transfer.id]
if current ~= transfer or current.queueAttempt ~= attempt then return end
current.queueing=false
current.queueComplete = true
current.queueSucceeded = success ~= false
current.queueResult = result
current.lastQueuedAt = GetTime and GetTime() or 0
if S.latestBroadcastId == current.id then
S.status = success ~= false and "方案已发送，等待成员回执"
or "部分数据发送失败，等待完整重发"
RM:Refresh()
end
if C_Timer and C_Timer.After then
C_Timer.After(success ~= false and S.snapshotRepeatSeconds or 1, function() S:RetryTransfer(current.id) end)
C_Timer.After(120, function()
local pending = S.outgoing[current.id]
if pending == current and pending.cleanupSerial == cleanupSerial then
S.outgoing[current.id] = nil
end
end)
end
end, transfer.target)
if not ok then
transfer.queueing=false
transfer.queueComplete = true
transfer.queueSucceeded = false
transfer.queueResult = detail
if self.latestBroadcastId == transfer.id then
self.status = retrying and "方案完整重发失败" or "方案发送失败"
RM:Refresh()
end
return false, detail
end
return true, detail
end
function S:RetryTransfer(transferId)
local transfer = self.outgoing[transferId]
if not transfer or self.latestBroadcastId~=transferId then return end
self:RefreshExpected(transfer)
local total = countSet(transfer.expected)
if total > 0 and countResponses(transfer) >= total then
transfer.completed=true
self:UpdateOutgoingStatus(transfer)
return
end
local now=GetTime and GetTime() or 0
if now-(tonumber(transfer.sentAt) or now)>=120 then
transfer.timedOut=true
self:UpdateOutgoingStatus(transfer)
return
end
if total==0 and (tonumber(transfer.queueAttempt) or 0)>=2 then
transfer.completed=true
self:UpdateOutgoingStatus(transfer)
return
end
transfer.completed=false
self.status = total>0 and "部分成员未确认，正在重发完整方案" or "正在再次广播完整方案"
RM:Refresh()
self:QueueTransfer(transfer, true)
end
function S:Transmit(plan, channel, target)
channel = channel or U.GroupChannel()
if not channel then RM:Print("不在队伍或团队中，无法同步方案。"); return false end
if not U.IsLeaderOrAssistant() then RM:Print("只有团长或助理可以同步全团方案。"); return false end
plan = plan or RM.Plan:GetCurrent()
local payload = self:EncodePlan(plan)
if #payload > 40000 then RM:Print("方案超过 40KB 上限，请减少任务后重试。"); return false end
local checksum = U.Checksum(payload)
local planKey=tostring(plan.key or "")
if not target then
local matching=self:GetMatchingTransfer(planKey,checksum)
if matching then return self:ContinueTransfer(matching) end
end
local transferId = U.NewId("tx")
local activationId = self:NextActivationId()
local transfer = {
id=transferId, checksum=checksum, channel=channel,
target=target, expected=target and {[U.ShortName(target)]=true} or expectedRecipients(),
acks={}, incompatible={}, templateMismatch={}, rejected={}, retryable={},
sentAt=GetTime(), revision=plan.revision or 1, activationId=activationId,
planKey=planKey,
}
transfer.message = self:BuildEnvelope(transferId, checksum, activationId, payload)
if #transfer.message > 255 then
RM:Print("当前站位方案超过单包 255 字节上限，请恢复模板槽位后重试。")
return false
end
self.outgoing[transferId] = transfer
self.latestBroadcastId = transferId
self.status = target and ("正在向 "..U.ShortName(target).." 补发最新站位") or "正在加入同步发送队列"
if not self:QueueTransfer(transfer, false) then
self.outgoing[transferId] = nil
RM:Print("方案未能加入同步发送队列。")
return false
end
self:RememberAuthority(UnitName("player"), plan, U.GroupRank(), activationId)
self.lastBroadcast = { key=plan.key, checksum=checksum, revision=plan.revision or 1,
sentAt=GetTime and GetTime() or 0 }
if C_Timer and C_Timer.After then
C_Timer.After(600, function() S.outgoing[transferId] = nil end)
end
return true
end
function S:Broadcast(plan)
return self:Transmit(plan, U.GroupChannel())
end
function S:PlanFingerprint(plan)
plan = plan or RM.Plan:GetCurrent()
local payload = self:EncodePlan(plan)
return U.Checksum(payload), tostring(plan.key or ""), tonumber(plan.revision) or 1
end
function S:StopPositionHeartbeat()
if self.positionTicker and self.positionTicker.Cancel then self.positionTicker:Cancel() end
self.positionTicker=nil
end
function S:ReconcilePositionPage()
if not self.positionPageOpen or RM:GetDB().settings.autoSync == false or not U.GroupChannel() then
self:StopPositionHeartbeat()
return false
end
if U.GroupRank() ~= 2 then return true end
self:SendRaw("Q|1",U.GroupChannel())
local checksum,key=self:PlanFingerprint()
local last=self.lastBroadcast
if not last or last.key~=key or last.checksum~=checksum then return self:Broadcast(RM.Plan:GetCurrent()) end
local transfer=self.latestBroadcastId and self.outgoing[self.latestBroadcastId]
if not transfer then return self:Broadcast(RM.Plan:GetCurrent()) end
local receipt=self:GetReceiptStatus(transfer)
if not receipt.done then
local now=GetTime and GetTime() or 0
if not transfer.queueing and now-(tonumber(transfer.lastQueuedAt) or -100)>=self.snapshotRepeatSeconds then
return self:QueueTransfer(transfer,true)
end
else
transfer.completed=true
self:UpdateOutgoingStatus(transfer)
end
return true
end
function S:SetPositionPageOpen(open)
open = open and true or false
self.positionPageOpen=open
self._pageRequestSerial=(self._pageRequestSerial or 0)+1
local serial=self._pageRequestSerial
self:StopPositionHeartbeat()
if U.GroupChannel() then self:SendPageState(open) end
if not open or RM:GetDB().settings.autoSync == false or not U.GroupChannel() then return false end
if U.GroupRank() == 2 then
self._scheduleSerial=(self._scheduleSerial or 0)+1
self:Broadcast(RM.Plan:GetCurrent())
self:SendRaw("Q|1",U.GroupChannel())
if C_Timer and C_Timer.NewTicker then
self.positionTicker=C_Timer.NewTicker(self.snapshotRepeatSeconds,function()
if not S.positionPageOpen or serial~=S._pageRequestSerial then S:StopPositionHeartbeat();return end
S:ReconcilePositionPage()
end)
end
return true
end
self.status="等待团长广播完整方案"
RM:Refresh()
return true
end
function S:ScheduleBroadcast(plan, delay)
local settings = RM:GetDB().settings
if settings.autoSync == false or U.GroupRank() ~= 2 or not U.GroupChannel() then return false end
if not (C_Timer and C_Timer.After) then return false end
local checksum,key=self:PlanFingerprint(plan)
local matching=self:GetMatchingTransfer(key,checksum)
if matching then return self:ContinueTransfer(matching) end
local last=self.lastBroadcast
local receipt=self:GetReceiptStatus()
if last and last.key==key and last.checksum==checksum and receipt.done then return true end
local fingerprint=tostring(key)..":"..tostring(checksum)
if self._scheduledFingerprint==fingerprint then return true end
self._scheduleSerial = (self._scheduleSerial or 0) + 1
local serial = self._scheduleSerial
local planKey = plan and plan.key
self._scheduledFingerprint=fingerprint
C_Timer.After(tonumber(delay) or 2, function()
if serial ~= S._scheduleSerial then return end
S._scheduledFingerprint=nil
if RM:GetDB().settings.autoSync == false or U.GroupRank() ~= 2 or not U.GroupChannel() then
S.status="自动同步已暂停";RM:Refresh();return
end
local current = RM.Plan:GetCurrent()
if planKey and current.key ~= planKey then
return S:ScheduleBroadcast(current,0.2)
end
local currentChecksum,currentKey=S:PlanFingerprint(current)
local active=S:GetMatchingTransfer(currentKey,currentChecksum)
if active then return S:ContinueTransfer(active) end
if not S:Broadcast(current) then S.status="自动同步发送失败";RM:Refresh() end
end)
self.status = "正在合并站位变更"
RM:Refresh()
return true
end
function S:AcceptSender(sender)
if U.ShortName(sender) == U.ShortName(UnitName("player")) then return true end
return RM:GetDB().settings.acceptLeaderPlans ~= false and U.IsLeaderOrAssistant(sender)
end
function S:IsFollowingAuthority(plan)
plan = plan or RM.Plan:GetCurrent()
local authority = plan and self.authorities[tostring(plan.key or "")]
if not authority then return false end
local sender = U.ShortName(authority.sender)
return sender ~= "" and sender ~= U.ShortName(UnitName("player")) and U.IsLeaderOrAssistant(sender)
end
function S:CanApplyPlan(sender, plan, activationId)
local name = U.ShortName(sender)
local rank = U.GroupRank(name)
local key = tostring(plan and plan.key or "")
local previous = self.authorities[key]
activationId = math.max(0, tonumber(activationId) or 0)
local latestActivation = math.max(0, tonumber(self.latestActivationBySender[name]) or 0)
if activationId > 0 and latestActivation > 0 and activationId < latestActivation then
return false, "stale_activation"
end
local newlyActivated = activationId > latestActivation
if previous then
if previous.sender == name and not newlyActivated
and (tonumber(plan.revision) or 1) < (tonumber(previous.revision) or 1) then
return false, "stale_revision"
end
local previousStillAuthoritative = U.GroupRank(previous.sender) >= (tonumber(previous.rank) or 0)
if previous.sender ~= name and previousStillAuthoritative and rank < (tonumber(previous.rank) or 0) then
return false, "lower_authority"
end
end
return true, nil, rank
end
function S:RememberAuthority(sender, plan, rank, activationId)
local name=U.ShortName(sender)
activationId=math.max(0,tonumber(activationId) or 0)
self.authorities[tostring(plan.key or "")] = {
sender=name, rank=tonumber(rank) or U.GroupRank(sender),
revision=tonumber(plan.revision) or 1, activationId=activationId,
receivedAt=GetTime and GetTime() or 0,
}
if activationId > math.max(0,tonumber(self.latestActivationBySender[name]) or 0) then
self.latestActivationBySender[name]=activationId
end
end
local function responseChannel(distribution)
if distribution == "RAID" or distribution == "PARTY" or distribution == "INSTANCE_CHAT"
or distribution == "WHISPER" then
return distribution
end
return U.GroupChannel()
end
function S:SendResponse(response, sender, distribution)
if type(response)~="string" or response=="" then return false end
local target=tostring(sender or "")
if target~="" then
return self:SendRaw(response,"WHISPER",nil,target,"ALERT")
end
local channel=responseChannel(distribution)
return channel and self:SendRaw(response,channel,nil,nil,"ALERT") or false
end
function S:ScheduleAckRetry(pending)
if not (pending and C_Timer and C_Timer.After) then return end
C_Timer.After(self.snapshotRepeatSeconds,function()
local current=S.pendingAck
if current~=pending or S.confirmedTransferId==current.transferId then return end
if U.ShortName(current.sender)=="" or not rosterMember(current.sender)
or not U.IsLeaderOrAssistant(current.sender) then
S.pendingAck=nil
return
end
S:SendRaw(current.response,"WHISPER",nil,current.sender,"ALERT")
S:ScheduleAckRetry(current)
end)
end
function S:AwaitAckConfirmation(sender, transferId, response)
if type(response)~="string" or response:sub(1,2)~="A|" then return end
self.confirmedTransferId=nil
local pending={sender=tostring(sender or ""),transferId=tostring(transferId or ""),response=response}
self.pendingAck=pending
self:ScheduleAckRetry(pending)
end
function S:ScheduleLeaderConfirmation(transfer, sender)
if not transfer then return false end
local name=U.ShortName(sender)
if name=="" then return false end
transfer.confirmPending=transfer.confirmPending or {}
if transfer.confirmPending[name] then return true end
transfer.confirmPending[name]=true
local target=tostring(sender or name)
local function sendIfCurrent()
transfer.confirmPending[name]=nil
if S.outgoing[transfer.id]~=transfer or S.latestBroadcastId~=transfer.id
or not transfer.acks[name] or not rosterMember(name) then return end
S:SendRaw("C|"..tostring(transfer.id),"WHISPER",nil,target,"ALERT")
end
if C_Timer and C_Timer.After then
C_Timer.After(self.ackConfirmSettleSeconds,sendIfCurrent)
else
sendIfCurrent()
end
return true
end
function S:RememberResponse(sender, transferId, checksum, response)
local key = U.ShortName(sender) .. "\t" .. tostring(transferId)
self.received[key] = {
checksum=checksum, response=response, receivedAt=GetTime and GetTime() or 0,
}
return key
end
function S:Handle(prefix, message, distribution, sender)
if prefix ~= self.prefix or type(message) ~= "string" or #message > 42000 then return end
if U.ShortName(sender) == U.ShortName(UnitName("player")) then return end
local kind = message:match("^([^|]+)")
local fields = kind ~= "S" and U.Split(message, "|") or nil
local transferId = fields and fields[2]
if kind == "Q" then
self:SendPageState(self.positionPageOpen,sender)
return
elseif kind == "P" then
local name=U.ShortName(sender)
if rosterMember(name) then self.pageOpenByName[name]=fields[2]=="1";RM:Refresh() end
return
elseif kind == "C" then
local pending=self.pendingAck
if pending and tostring(transferId or "")==pending.transferId
and U.ShortName(sender)==U.ShortName(pending.sender) then
self.confirmedTransferId=pending.transferId
self.pendingAck=nil
self.status="团长已确认完整方案回执"
RM:Refresh()
end
return
elseif kind == "A" then
local transfer = self.outgoing[transferId]
local name = U.ShortName(sender)
if rosterMember(name) and (fields[5]=="1" or fields[5]=="0") then
self.pageOpenByName[name]=fields[5]=="1"
end
if transferId and transferId==self.lastAppliedTransferId then self.observedAcks[name]=transferId;RM:Refresh() end
if expectedResponse(transfer,sender) then
transfer.retryable[name]=nil
transfer.rejected[name]=nil
transfer.acks[name] = tonumber(fields[4]) or true
self:UpdateOutgoingStatus(transfer)
self:ScheduleLeaderConfirmation(transfer,sender)
end
return
elseif kind == "V" then
local transfer = self.outgoing[transferId]
local name = U.ShortName(sender)
if expectedResponse(transfer,sender) then
transfer.retryable[name]=nil
transfer.incompatible[name] = tonumber(fields[3]) or true
self:UpdateOutgoingStatus(transfer)
end
return
elseif kind == "M" then
local transfer = self.outgoing[transferId]
local name = U.ShortName(sender)
if expectedResponse(transfer,sender) then
transfer.retryable[name]=nil
transfer.templateMismatch[name] = U.Unescape(fields[3] or "未知模板")
self:UpdateOutgoingStatus(transfer)
end
return
elseif kind == "N" then
local transfer = self.outgoing[transferId]
local name = U.ShortName(sender)
if expectedResponse(transfer,sender) then
local reason=U.Unescape(fields[3] or "rejected")
if reason=="roster_mismatch" then
transfer.retryable[name]=reason
transfer.rejected[name]=nil
else
transfer.retryable[name]=nil
transfer.rejected[name]=reason
end
self:UpdateOutgoingStatus(transfer)
end
return
end
if kind ~= "S" or not self:AcceptSender(sender) then return end
local checksum, protocol, activationId, payload
transferId, checksum, protocol, activationId, payload = self:ParseEnvelope(message)
if not transferId then return end
local now = GetTime and GetTime() or 0
for key, received in pairs(self.received) do
if now - (received.receivedAt or now) > 120 then self.received[key] = nil end
end
local cacheKey = U.ShortName(sender) .. "\t" .. transferId
local cached = self.received[cacheKey]
if cached then
if cached.checksum == checksum then self:SendResponse(cached.response,sender,distribution) end
return
end
local response, cacheResponse
cacheResponse=true
if protocol > self.protocol then
response = table.concat({"V",transferId,tostring(self.protocol)},"|")
self.status = string.format("无法接收：方案协议 v%d，本地仅支持 v%d",protocol,self.protocol)
RM:Refresh()
elseif U.Checksum(payload) ~= checksum then
response = table.concat({"N",transferId,U.Escape("checksum_mismatch")},"|")
self.status = "无法接收：方案完整性校验失败"
RM:Refresh()
else
local plan, reason, mismatchMapId = self:DecodePlan(payload,protocol)
local canApply, rejectReason, senderRank = plan and self:CanApplyPlan(sender,plan,activationId)
if plan and not canApply then
response = table.concat({"N",transferId,U.Escape(rejectReason)},"|")
self.status = (rejectReason == "stale_revision" or rejectReason == "stale_activation")
and "已忽略较旧的同来源方案" or "已保留团长发送的方案"
RM:Refresh()
elseif plan and RM.Plan:Replace(plan) then
self:RememberAuthority(sender,plan,senderRank,activationId)
self.lastAppliedTransferId=transferId
self.confirmedTransferId=nil
self.observedAcks={}
self.status = string.format("已接收 %s 的完整站位，正在提交回执",U.ShortName(sender))
response = table.concat({"A",transferId,tostring(plan.revision or 1),tostring(self.protocol),
self.positionPageOpen and "1" or "0"},"|")
RM:Print("已同步站位: " .. tostring(plan.name))
RM:Refresh()
elseif reason == "unsupported_protocol" then
response = table.concat({"V",transferId,tostring(self.protocol)},"|")
elseif reason == "template_mismatch" or reason == "template_contract_missing" or reason == "unknown_template" then
response = table.concat({"M",transferId,U.Escape(mismatchMapId or "未知模板")},"|")
self.status = "无法接收：双方站位模板不一致（"..tostring(mismatchMapId or "未知").."）"
RM:Print(self.status)
RM:Refresh()
else
response = table.concat({"N",transferId,U.Escape(reason or "invalid_plan")},"|")
if reason=="roster_mismatch" then
cacheResponse=false
self.status="团队名单正在同步，等待团长重发最新站位"
RM:Refresh()
end
end
end
if cacheResponse then self:RememberResponse(sender, transferId, checksum, response) end
self:AwaitAckConfirmation(sender,transferId,response)
self:SendResponse(response,sender,distribution)
end
function S:OnLogin()
local ok, reason = RM.Transport and RM.Transport:Register(self.prefix, function(prefix, message, distribution, sender)
S:Handle(prefix, message, distribution, sender)
end)
if not ok then
self.status = "同步通信库加载失败"
RM:Print(self.status .. ": " .. tostring(reason or "未知错误"))
RM:Refresh()
end
if not self.rosterFrame then
self.rosterFrame=CreateFrame("Frame")
self.rosterFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
self.rosterFrame:SetScript("OnEvent",function()
if not S.positionPageOpen or U.GroupRank()~=2 or RM:GetDB().settings.autoSync==false then return end
S._rosterSerial=(S._rosterSerial or 0)+1
local serial=S._rosterSerial
if C_Timer and C_Timer.After then
C_Timer.After(1,function()
if serial==S._rosterSerial and S.positionPageOpen and U.GroupRank()==2 then
S:Broadcast(RM.Plan:GetCurrent())
end
end)
end
end)
end
end
function S:OnLogout()
self.positionPageOpen=false
self.pendingAck=nil
self:StopPositionHeartbeat()
if self.rosterFrame then self.rosterFrame:UnregisterAllEvents() end
end
