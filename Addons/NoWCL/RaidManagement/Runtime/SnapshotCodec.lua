local _, NoWCL = ...
local RM = NoWCL.RaidManagement
local C = { format = 2, maxBinaryBytes = 65536 }
RM.SnapshotCodec = C
local floor, min, max = math.floor, math.min, math.max
local BASE64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local BASE64_VALUE = {}
for index = 1, #BASE64 do BASE64_VALUE[BASE64:sub(index,index)] = index - 1 end
local function sortedKeys(values)
local keys = {}
for key in pairs(values or {}) do keys[#keys + 1] = key end
table.sort(keys, function(a,b) return tostring(a) < tostring(b) end)
return keys
end
local function base64Encode(raw)
local out = {}
for index = 1, #raw, 3 do
local a, b, c = raw:byte(index,index + 2)
local value = a * 65536 + (b or 0) * 256 + (c or 0)
local c1 = floor(value / 262144) % 64
local c2 = floor(value / 4096) % 64
local c3 = floor(value / 64) % 64
local c4 = value % 64
out[#out + 1] = BASE64:sub(c1 + 1,c1 + 1)
out[#out + 1] = BASE64:sub(c2 + 1,c2 + 1)
out[#out + 1] = b and BASE64:sub(c3 + 1,c3 + 1) or "="
out[#out + 1] = c and BASE64:sub(c4 + 1,c4 + 1) or "="
end
return table.concat(out)
end
local function base64Decode(text)
if type(text) ~= "string" or #text == 0 or #text % 4 ~= 0 then return nil, "base64_size" end
local out = {}
for index = 1, #text, 4 do
local a, b, c, d = text:sub(index,index), text:sub(index + 1,index + 1),
text:sub(index + 2,index + 2), text:sub(index + 3,index + 3)
local va, vb = BASE64_VALUE[a], BASE64_VALUE[b]
local vc, vd = c == "=" and 0 or BASE64_VALUE[c], d == "=" and 0 or BASE64_VALUE[d]
if va == nil or vb == nil or vc == nil or vd == nil then return nil, "base64_character" end
if (c == "=" and d ~= "=") or (index + 3 < #text and (c == "=" or d == "=")) then
return nil, "base64_padding"
end
local value = va * 262144 + vb * 4096 + vc * 64 + vd
out[#out + 1] = string.char(floor(value / 65536) % 256)
if c ~= "=" then out[#out + 1] = string.char(floor(value / 256) % 256) end
if d ~= "=" then out[#out + 1] = string.char(value % 256) end
end
return table.concat(out)
end
local function writer()
return { parts = {}, size = 0 }
end
local function putByte(out, value)
out.parts[#out.parts + 1] = string.char(floor(tonumber(value) or 0) % 256)
out.size = out.size + 1
end
local function putVar(out, value)
value = max(0, floor(tonumber(value) or 0))
repeat
local byte = value % 128
value = floor(value / 128)
if value > 0 then byte = byte + 128 end
putByte(out, byte)
until value == 0
end
local function putU16(out, value)
value = max(0, min(65535, floor(tonumber(value) or 0)))
putByte(out, value % 256)
putByte(out, floor(value / 256))
end
local function putU32(out, value)
value = max(0, floor(tonumber(value) or 0))
putByte(out, value % 256)
putByte(out, floor(value / 256) % 256)
putByte(out, floor(value / 65536) % 256)
putByte(out, floor(value / 16777216) % 256)
end
local function putRaw(out, value)
value = tostring(value or "")
putVar(out, #value)
out.parts[#out.parts + 1] = value
out.size = out.size + #value
end
local function reader(raw)
return { raw=raw, pos=1, size=#raw }
end
local function getByte(input)
if input.pos > input.size then input.error = input.error or "unexpected_end"; return 0 end
local value = input.raw:byte(input.pos)
input.pos = input.pos + 1
return value
end
local function getVar(input)
local value, scale = 0, 1
for _ = 1, 5 do
local byte = getByte(input)
value = value + (byte % 128) * scale
if byte < 128 then return value end
scale = scale * 128
end
input.error = input.error or "varint_overflow"
return 0
end
local function getU16(input)
return getByte(input) + getByte(input) * 256
end
local function getU32(input)
return getByte(input) + getByte(input) * 256 + getByte(input) * 65536
+ getByte(input) * 16777216
end
local function getRaw(input, limit)
local length = getVar(input)
if length > (limit or 16384) or input.pos + length - 1 > input.size then
input.error = input.error or "string_size"
return ""
end
local value = input.raw:sub(input.pos,input.pos + length - 1)
input.pos = input.pos + length
return value
end
local function quantize(value)
value = max(0, min(1, tonumber(value) or 0.5))
return floor(value * 65535 + 0.5)
end
local function dequantize(value)
return value / 65535
end
local function addList(intern, values)
for _, value in ipairs(values or {}) do intern(value) end
end
local function buildDictionary(plan, contracts)
local strings, indices = {}, {}
local function intern(value)
value = tostring(value or "")
if value == "" then return 0 end
local index = indices[value]
if not index then
index = #strings + 1
strings[index], indices[value] = value, index
end
return index
end
intern(plan.id); intern(plan.key); intern(plan.name); intern(plan.mapId)
for _, mapId in ipairs(sortedKeys(contracts)) do intern(mapId); intern(contracts[mapId]) end
for _, mapId in ipairs(sortedKeys(plan.taskTemplateVersions)) do intern(mapId) end
for _, mapId in ipairs(sortedKeys(plan.dismissedTemplateTasks)) do
intern(mapId)
for _, templateId in ipairs(sortedKeys(plan.dismissedTemplateTasks[mapId])) do intern(templateId) end
end
for _, task in ipairs(plan.tasks or {}) do
for _, value in ipairs({task.id,task.name,task.type,task.event,task.assignee,task.role,task.class,
task.mode,task.subject,task.phaseId,task.mapId,task.templateId}) do intern(value) end
addList(intern,task.events);addList(intern,task.targetRoles);addList(intern,task.sourceRoles);addList(intern,task.classes)
end
for _, name in ipairs(sortedKeys(plan.positions)) do
intern(name);intern(plan.positions[name] and plan.positions[name].role)
end
for _, mapId in ipairs(sortedKeys(plan.phaseIds)) do intern(mapId);intern(plan.phaseIds[mapId]) end
for _, mapId in ipairs(sortedKeys(plan.mapLayouts)) do
intern(mapId)
local layout=plan.mapLayouts[mapId] or {};local slots={}
for slotId in pairs(layout.assignments or {}) do slots[slotId]=true end
for slotId in pairs(layout.locks or {}) do slots[slotId]=true end
for slotId in pairs(layout.manual or {}) do slots[slotId]=true end
for _, slotId in ipairs(sortedKeys(slots)) do intern(slotId);intern(layout.assignments and layout.assignments[slotId]) end
for _, slotId in ipairs(sortedKeys(layout.offsets)) do intern(slotId) end
for _, slotId in ipairs(sortedKeys(layout.groups)) do intern(slotId) end
end
return strings, indices
end
local function contractTable(plan)
local contracts = {}
local maps = {[tostring(plan.mapId or "neutral")]=true}
for mapId in pairs(plan.phaseIds or {}) do maps[tostring(mapId)] = true end
for layoutKey in pairs(plan.mapLayouts or {}) do maps[tostring(layoutKey):match("^[^@]+") or tostring(layoutKey)] = true end
for _, mapId in ipairs(sortedKeys(maps)) do
local map = RM.MapById and RM.MapById[mapId]
if map and map.templateContract then contracts[mapId] = map.templateContract end
end
return contracts
end
local function encodeBinaryV1(plan, protocol)
local contracts = contractTable(plan)
local strings, indices = buildDictionary(plan,contracts)
local out = writer()
out.parts[#out.parts + 1] = "NCS1"; out.size = 4
putVar(out, protocol or 1)
putVar(out,#strings)
for _, value in ipairs(strings) do putRaw(out,value) end
local function ref(value) putVar(out,indices[tostring(value or "")] or 0) end
local function refs(values)
putVar(out,#(values or {}));for _, value in ipairs(values or {}) do ref(value) end
end
local function nums(values)
putVar(out,#(values or {}));for _, value in ipairs(values or {}) do putVar(out,value) end
end
ref(plan.id);ref(plan.key);ref(plan.name);ref(plan.mapId);putVar(out,plan.revision or 1)
putVar(out,#sortedKeys(contracts))
for _, mapId in ipairs(sortedKeys(contracts)) do ref(mapId);ref(contracts[mapId]) end
putVar(out,#sortedKeys(plan.taskTemplateVersions))
for _, mapId in ipairs(sortedKeys(plan.taskTemplateVersions)) do ref(mapId);putVar(out,plan.taskTemplateVersions[mapId]) end
putVar(out,#sortedKeys(plan.dismissedTemplateTasks))
for _, mapId in ipairs(sortedKeys(plan.dismissedTemplateTasks)) do
local dismissed=plan.dismissedTemplateTasks[mapId] or {};ref(mapId);putVar(out,#sortedKeys(dismissed))
for _, templateId in ipairs(sortedKeys(dismissed)) do ref(templateId) end
end
putVar(out,#(plan.tasks or {}))
for _, task in ipairs(plan.tasks or {}) do
ref(task.id);ref(task.name);ref(task.type);putVar(out,task.spellId or 0);ref(task.event)
putVar(out,task.expectedAt or 0);putVar(out,task.tolerance or 8);putVar(out,task.count or 1)
ref(task.assignee);ref(task.role);ref(task.class);ref(task.mode);ref(task.subject)
nums(task.spellIds);refs(task.events);putVar(out,task.minimum or task.count or 1);putVar(out,task.maximum or 0)
ref(task.phaseId);ref(task.mapId);ref(task.templateId)
putByte(out,task.autoAssign==false and 0 or 1)
refs(task.targetRoles);refs(task.sourceRoles);refs(task.classes)
end
putVar(out,#sortedKeys(plan.positions))
for _, name in ipairs(sortedKeys(plan.positions)) do
local point=plan.positions[name] or {};ref(name);putU16(out,quantize(point.x));putU16(out,quantize(point.y));ref(point.role)
putByte(out,point.locked and 1 or 0)
end
putVar(out,#sortedKeys(plan.phaseIds))
for _, mapId in ipairs(sortedKeys(plan.phaseIds)) do ref(mapId);ref(plan.phaseIds[mapId]) end
putVar(out,#sortedKeys(plan.mapLayouts))
for _, mapId in ipairs(sortedKeys(plan.mapLayouts)) do
local layout=plan.mapLayouts[mapId] or {};ref(mapId)
local slots={}
for slotId in pairs(layout.assignments or {}) do slots[slotId]=true end
for slotId in pairs(layout.locks or {}) do slots[slotId]=true end
for slotId in pairs(layout.manual or {}) do slots[slotId]=true end
putVar(out,#sortedKeys(slots))
for _, slotId in ipairs(sortedKeys(slots)) do
ref(slotId);ref(layout.assignments and layout.assignments[slotId])
local flags=(layout.locks and layout.locks[slotId]) and 1 or 0
if layout.manual and layout.manual[slotId] then flags=flags+2 end
putByte(out,flags)
end
putVar(out,#sortedKeys(layout.offsets))
for _, slotId in ipairs(sortedKeys(layout.offsets)) do
local point=layout.offsets[slotId] or {};ref(slotId);putU16(out,quantize(point.x));putU16(out,quantize(point.y))
end
putVar(out,#sortedKeys(layout.groups))
for _, slotId in ipairs(sortedKeys(layout.groups)) do ref(slotId);putByte(out,layout.groups[slotId]) end
end
return table.concat(out.parts)
end
local function decodeBinaryV1(raw, envelopeProtocol)
if type(raw)~="string" or #raw<5 or #raw>C.maxBinaryBytes or raw:sub(1,4)~="NCS1" then return nil,"binary_header" end
local input=reader(raw);input.pos=5
local protocol=getVar(input)
if envelopeProtocol and protocol~=envelopeProtocol then return nil,"protocol_mismatch" end
local stringCount=getVar(input)
if stringCount>4096 then return nil,"dictionary_size" end
local strings={}
for index=1,stringCount do strings[index]=getRaw(input,16384) end
local function ref()
local index=getVar(input)
if index==0 then return nil end
if index>#strings then input.error=input.error or "dictionary_reference";return nil end
return strings[index]
end
local function refs(limit)
local count=getVar(input);if count>(limit or 128) then input.error=input.error or "list_size";return {} end
local out={};for index=1,count do out[index]=ref() end;return out
end
local function nums(limit)
local count=getVar(input);if count>(limit or 128) then input.error=input.error or "list_size";return {} end
local out={};for index=1,count do out[index]=getVar(input) end;return out
end
local plan={id=ref(),key=ref(),name=ref(),mapId=ref(),revision=getVar(input),protocol=protocol,
tasks={},positions={},mapLayouts={},phaseIds={},templateContracts={},taskTemplateVersions={},dismissedTemplateTasks={}}
local count=getVar(input);if count>128 then return nil,"contract_count" end
for _=1,count do local mapId,contract=ref(),ref();if mapId then plan.templateContracts[mapId]=contract end end
count=getVar(input);if count>128 then return nil,"version_count" end
for _=1,count do local mapId=ref();local version=getVar(input);if mapId then plan.taskTemplateVersions[mapId]=version end end
count=getVar(input);if count>128 then return nil,"dismissed_map_count" end
for _=1,count do
local mapId=ref();local templateCount=getVar(input);if templateCount>512 then return nil,"dismissed_count" end
local dismissed={};for _=1,templateCount do local templateId=ref();if templateId then dismissed[templateId]=true end end
if mapId then plan.dismissedTemplateTasks[mapId]=dismissed end
end
count=getVar(input);if count>80 then return nil,"task_count" end
for index=1,count do
local task={id=ref(),name=ref(),type=ref(),spellId=getVar(input),event=ref(),expectedAt=getVar(input),
tolerance=getVar(input),count=getVar(input),assignee=ref(),role=ref(),class=ref(),mode=ref(),subject=ref()}
task.spellIds=nums(128);task.events=refs(128);task.minimum=getVar(input);task.maximum=getVar(input)
task.phaseId=ref();task.mapId=ref();task.templateId=ref();task.autoAssign=getByte(input)%2==1
task.targetRoles=refs(16);task.sourceRoles=refs(16);task.classes=refs(16);plan.tasks[index]=task
end
count=getVar(input);if count>80 then return nil,"position_count" end
for _=1,count do
local name=ref();local point={x=dequantize(getU16(input)),y=dequantize(getU16(input)),role=ref(),locked=getByte(input)%2==1}
if name then plan.positions[name]=point end
end
count=getVar(input);if count>128 then return nil,"phase_count" end
for _=1,count do local mapId,phaseId=ref(),ref();if mapId and phaseId then plan.phaseIds[mapId]=phaseId end end
count=getVar(input);if count>128 then return nil,"layout_count" end
local rows=0
for _=1,count do
local mapId=ref();local layout={assignments={},offsets={},locks={},groups={},manual={}}
local slotCount=getVar(input);rows=rows+slotCount;if rows>512 then return nil,"layout_rows" end
for _=1,slotCount do
local slotId,name,flags=ref(),ref(),getByte(input)
if slotId then
if name then layout.assignments[slotId]=name end
if flags%2==1 then layout.locks[slotId]=true end
if floor(flags/2)%2==1 then layout.manual[slotId]=true end
end
end
local offsetCount=getVar(input);rows=rows+offsetCount;if rows>512 then return nil,"layout_rows" end
for _=1,offsetCount do
local slotId=ref();local point={x=dequantize(getU16(input)),y=dequantize(getU16(input))}
if slotId then layout.offsets[slotId]=point end
end
local groupCount=getVar(input);rows=rows+groupCount;if rows>512 then return nil,"layout_rows" end
for _=1,groupCount do local slotId=ref();local subgroup=getByte(input);if slotId and subgroup>=1 and subgroup<=8 then layout.groups[slotId]=subgroup end end
if mapId then plan.mapLayouts[mapId]=layout end
end
if input.error then return nil,input.error end
if input.pos~=input.size+1 then return nil,"binary_trailing_data" end
return plan
end
local ROLES = { TANK=1, HEALER=2, DAMAGER=3, DPS=3 }
local function inverse(values)
local out = {}
for key, value in pairs(values) do if not out[value] then out[value] = key end end
return out
end
local ROLE_NAMES = inverse(ROLES)
local function rosterMaps()
local api = RM.GetNoWCLAPI and RM:GetNoWCLAPI()
local roster = api and api.GetRosterSnapshot and api:GetRosterSnapshot() or {}
local rows = {}
for _, player in ipairs(roster) do rows[#rows + 1] = player end
local isRaid=IsInRaid and IsInRaid()
table.sort(rows, function(a,b)
if not isRaid then
return tostring(RM.Util.ShortName(a.name))<tostring(RM.Util.ShortName(b.name))
end
local ai,bi=tonumber(a.raidIndex) or 999,tonumber(b.raidIndex) or 999
if ai~=bi then return ai<bi end
return tostring(a.name)<tostring(b.name)
end)
local byName, byToken, checksumParts, subgroupSlots = {}, {}, {}, {}
for index, player in ipairs(rows) do
local subgroup=max(1,min(8,floor(tonumber(player.subgroup) or 1)))
subgroupSlots[subgroup]=(subgroupSlots[subgroup] or 0)+1
local subgroupSlot=isRaid and floor(tonumber(player.subgroupSlot) or subgroupSlots[subgroup]) or index
if not isRaid then subgroup=1 end
local name=RM.Util.ShortName(player.name)
local token=(subgroup-1)*5+subgroupSlot
if name~="" and name~="未知" and subgroupSlot>=1 and subgroupSlot<=5 and not byToken[token] then
byName[name]=token;byToken[token]=name
checksumParts[#checksumParts+1]=string.format("%02d=%s",token,name)
end
end
table.sort(checksumParts)
return {
byName=byName,byToken=byToken,
checksum=#checksumParts>0 and RM.Util.Checksum(table.concat(checksumParts,";")) or 0,
}
end
local function phaseIndex(map, phaseId)
for index, phase in ipairs(map and map.phases or {}) do
if phase.id==phaseId then return index end
end
return 0
end
local function phaseFromIndex(input, map, index)
if index==0 then return nil end
local phase=map and map.phases and map.phases[index]
if not phase then input.error=input.error or "phase_reference" end
return phase
end
local function gridIndex(value)
return RM.Util.PositionGridIndex and RM.Util.PositionGridIndex(value)
or floor(max(0,min(1,tonumber(value) or 0.5))*63+0.5)
end
local function gridValue(value)
return RM.Util.PositionFromGrid and RM.Util.PositionFromGrid(value)
or max(0.02,min(0.98,(tonumber(value) or 0)/63))
end
local function encodeBinaryV2(plan, protocol)
local mapId=tostring(plan.mapId or "neutral")
local map=RM.MapById and RM.MapById[mapId] or RM.GetMap and RM:GetMap(mapId)
if not map then return nil,"unknown_template" end
local roster=rosterMaps();local out=writer()
local explicitSlotCoordinates=(tonumber(protocol) or 10)>=11
out.parts[1]=explicitSlotCoordinates and "NCS3" or "NCS2";out.size=4
putVar(out,protocol or 10);putU32(out,roster.checksum)
local mapIndex=0
for index,candidate in ipairs(RM.PositionBossCatalog or {}) do if candidate.id==mapId then mapIndex=index;break end end
putByte(out,mapIndex);if mapIndex==0 then putRaw(out,mapId) end
putU32(out,tonumber(map.templateContract) or 0);putVar(out,plan.revision or 1)
local selectedPhaseId=plan.phaseIds and plan.phaseIds[mapId] or map.defaultPhaseId
local selectedPhase=map.phaseById and map.phaseById[selectedPhaseId]
or map.phases and map.phases[1]
local selectedPhaseIndex=phaseIndex(map,selectedPhase and selectedPhase.id)
putByte(out,selectedPhaseIndex)
local hasTemplate=selectedPhase and (#(selectedPhase.slots or {})>0 or #(selectedPhase.groupSlots or {})>0)
putByte(out,hasTemplate and 1 or 0)
if hasTemplate then
local key=RM.Plan and RM.Plan.LayoutKey and RM.Plan:LayoutKey(map.id,selectedPhase.id)
or (selectedPhase.id==map.defaultPhaseId and map.id or map.id.."@"..selectedPhase.id)
local layout=plan.mapLayouts and plan.mapLayouts[key] or {}
local offsets=layout.offsets or {}
for _,slot in ipairs(selectedPhase.slots or {}) do
local token=roster.byName[RM.Util.ShortName(layout.assignments and layout.assignments[slot.id] or "")] or 0
local packed=token
if layout.locks and layout.locks[slot.id] then packed=packed+64 end
if layout.manual and layout.manual[slot.id] then packed=packed+128 end
putByte(out,packed)
end
if explicitSlotCoordinates then
for _,slot in ipairs(selectedPhase.slots or {}) do
local point=offsets[slot.id] or slot
putByte(out,gridIndex(point.x));putByte(out,gridIndex(point.y))
end
else
local maskSize=math.ceil(#(selectedPhase.slots or {})/8)
local masks={};for index=1,maskSize do masks[index]=0 end
for index,slot in ipairs(selectedPhase.slots or {}) do
if offsets[slot.id] then
local byteIndex=floor((index-1)/8)+1
masks[byteIndex]=masks[byteIndex]+2^((index-1)%8)
end
end
for index=1,maskSize do putByte(out,masks[index]) end
for _,slot in ipairs(selectedPhase.slots or {}) do
local point=offsets[slot.id]
if point then putByte(out,gridIndex(point.x));putByte(out,gridIndex(point.y)) end
end
end
for _,slot in ipairs(selectedPhase.groupSlots or {}) do
putByte(out,layout.groups and layout.groups[slot.id] or 0)
end
else
local masks={0,0,0,0,0};local points={}
for token=1,40 do
local name=roster.byToken[token];local point=name and plan.positions and plan.positions[name]
if point then
local byteIndex=floor((token-1)/8)+1
masks[byteIndex]=masks[byteIndex]+2^((token-1)%8)
points[#points+1]={token=token,point=point}
end
end
for index=1,5 do putByte(out,masks[index]) end
for _,entry in ipairs(points) do
local point=entry.point
putByte(out,(ROLES[tostring(point.role or ""):upper()] or 0)+(point.locked and 4 or 0))
putByte(out,gridIndex(point.x));putByte(out,gridIndex(point.y))
end
end
return table.concat(out.parts)
end
local function decodeBinaryV2(raw, envelopeProtocol)
local header=type(raw)=="string" and raw:sub(1,4) or ""
if type(raw)~="string" or #raw<10 or #raw>C.maxBinaryBytes
or (header~="NCS2" and header~="NCS3") then return nil,"binary_header" end
local explicitSlotCoordinates=header=="NCS3"
local input=reader(raw);input.pos=5
local protocol=getVar(input);if envelopeProtocol and protocol~=envelopeProtocol then return nil,"protocol_mismatch" end
if explicitSlotCoordinates~=(protocol>=11) then return nil,"protocol_mismatch" end
local remoteRosterChecksum=getU32(input);local roster=rosterMaps()
if remoteRosterChecksum~=0 and remoteRosterChecksum~=roster.checksum then return nil,"roster_mismatch" end
local mapIndex=getByte(input);local mapId
if mapIndex==0 then mapId=getRaw(input,128)
else mapId=RM.PositionBossCatalog and RM.PositionBossCatalog[mapIndex] and RM.PositionBossCatalog[mapIndex].id end
local map=mapId and RM.MapById and RM.MapById[mapId]
if not map then return nil,"unknown_template" end
local remoteContract=getU32(input);local revision=getVar(input)
local phase=phaseFromIndex(input,map,getByte(input));local layoutKind=getByte(input)
local plan={id="sync-"..map.id,key=map.encounterId and ("encounter-"..tostring(map.encounterId)) or ("map-"..map.id),
name=map.bossName or map.name,mapId=map.id,revision=revision,protocol=protocol,tasks={},positions={},
mapLayouts={},phaseIds={},templateContracts={[map.id]=tostring(remoteContract)},taskTemplateVersions={},
dismissedTemplateTasks={},mapExplicit=true}
if phase then plan.phaseIds[map.id]=phase.id end
if layoutKind==1 then
if not phase then return nil,"phase_reference" end
local layout={assignments={},offsets={},locks={},groups={},manual={}}
for _,slot in ipairs(phase.slots or {}) do
local packed=getByte(input);local token=packed%64
if token>0 then
local name=roster.byToken[token]
if not name then input.error=input.error or "roster_reference" else layout.assignments[slot.id]=name end
end
if floor(packed/64)%2==1 then layout.locks[slot.id]=true end
if floor(packed/128)%2==1 and token>0 then layout.manual[slot.id]=true end
end
if explicitSlotCoordinates then
for _,slot in ipairs(phase.slots or {}) do
layout.offsets[slot.id]={x=gridValue(getByte(input)),y=gridValue(getByte(input))}
end
else
local maskSize=math.ceil(#(phase.slots or {})/8);local masks={}
for index=1,maskSize do masks[index]=getByte(input) end
for index,slot in ipairs(phase.slots or {}) do
local mask=masks[floor((index-1)/8)+1] or 0
if floor(mask/2^((index-1)%8))%2==1 then
layout.offsets[slot.id]={x=gridValue(getByte(input)),y=gridValue(getByte(input))}
end
end
end
for _,slot in ipairs(phase.groupSlots or {}) do
local subgroup=getByte(input);if subgroup>=1 and subgroup<=8 then layout.groups[slot.id]=subgroup end
end
local key=RM.Plan and RM.Plan.LayoutKey and RM.Plan:LayoutKey(map.id,phase.id)
or (phase.id==map.defaultPhaseId and map.id or map.id.."@"..phase.id)
plan.mapLayouts[key]=layout
elseif layoutKind==0 then
local masks={};for index=1,5 do masks[index]=getByte(input) end
for token=1,40 do
local mask=masks[floor((token-1)/8)+1] or 0
if floor(mask/2^((token-1)%8))%2==1 then
local packed=getByte(input);local name=roster.byToken[token]
local point={role=ROLE_NAMES[packed%4],locked=floor(packed/4)%2==1,
x=gridValue(getByte(input)),y=gridValue(getByte(input))}
if not name then input.error=input.error or "roster_reference" else plan.positions[name]=point end
end
end
else
return nil,"layout_kind"
end
if input.error then return nil,input.error end
if input.pos~=input.size+1 then return nil,"binary_trailing_data" end
return plan
end
local function decodeBinary(raw, envelopeProtocol)
if type(raw)~="string" then return nil,"binary_header" end
if raw:sub(1,4)=="NCS2" or raw:sub(1,4)=="NCS3" then return decodeBinaryV2(raw,envelopeProtocol) end
return decodeBinaryV1(raw,envelopeProtocol)
end
function C:Encode(plan,protocol)
local raw,reason
if (tonumber(protocol) or 1)>=10 then raw,reason=encodeBinaryV2(plan or {},protocol)
else raw=encodeBinaryV1(plan or {},protocol) end
if not raw then return nil,reason end
local marker="B"
if C_EncodingUtil and C_EncodingUtil.CompressString then
local ok,compressed=pcall(C_EncodingUtil.CompressString,raw)
if ok and type(compressed)=="string" and #compressed+4<#raw then raw,marker=compressed,"Z" end
end
return marker..base64Encode(raw)
end
function C:Decode(payload,protocol)
if type(payload)~="string" or #payload<2 then return nil,"payload_size" end
local marker=payload:sub(1,1)
if marker~="B" and marker~="Z" then return nil,"payload_marker" end
local raw,reason=base64Decode(payload:sub(2));if not raw then return nil,reason end
if marker=="Z" then
if not (C_EncodingUtil and C_EncodingUtil.DecompressString) then return nil,"compression_unavailable" end
local ok,decompressed=pcall(C_EncodingUtil.DecompressString,raw)
if not ok or type(decompressed)~="string" then return nil,"decompression_failed" end
raw=decompressed
end
return decodeBinary(raw,protocol)
end
C.EncodeBinary=encodeBinaryV2
C.EncodeBinaryV1=encodeBinaryV1
C.DecodeBinary=decodeBinary
C.Base64Encode=base64Encode
C.Base64Decode=base64Decode
