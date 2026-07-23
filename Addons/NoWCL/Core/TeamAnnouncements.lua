local addonName, NoWCL = ...
local A = {}
NoWCL.TeamAnnouncements = A
local U = NoWCL.Util
local MELEE_SPEC = {
[70]=true, [71]=true, [72]=true, [103]=true,
[250]=true, [251]=true, [252]=true,
[259]=true, [260]=true, [261]=true, [263]=true, [269]=true,
}
local MELEE_CLASS = { DEATHKNIGHT=true, ROGUE=true, WARRIOR=true, MONK=true, DEMONHUNTER=true }
local RANGED_CLASS = { HUNTER=true, MAGE=true, WARLOCK=true, PRIEST=true }
local MESSAGE_BODY_LIMIT = 220
local RULE_ROSTER_DEBOUNCE = 3
local RULE_TEXT_MAX_CHARS = 60
local RULE_BASELINE_LABELS = {
rank1="第一名",rank2="第二名",average="平均",median="中位数",tank="坦克",
}
local function effectiveConfig()
local sync = NoWCL.Sync
if sync and sync.HasLeaderAuthority and sync:HasLeaderAuthority() then return sync.cfg or {} end
return NoWCL.db and NoWCL.db.settings or {}
end
local function shortName(name)
return type(name)=="string" and (name:match("^[^-]+") or name) or nil
end
local function roleOf(player)
return U.RoleOfPlayer and U.RoleOfPlayer(player) or tostring(player and player.role or "DAMAGER")
end
local function playerKind(player)
local specId, class = tonumber(player and (player.specId or player.readySpecId)), tostring(player and player.class or "")
if specId and MELEE_SPEC[specId] then return "MELEE" end
if MELEE_CLASS[class] then return "MELEE" end
if RANGED_CLASS[class] then return "RANGED" end
if class == "PALADIN" then return "MELEE" end
if class == "SHAMAN" or class == "DRUID" then return specId and MELEE_SPEC[specId] and "MELEE" or "RANGED" end
return "RANGED"
end
local function identity(player)
if U.ResolveGroupCharacterLabel then
return U.ResolveGroupCharacterLabel(player.name, player.guid, player.class, player.groupLabel)
end
return tostring(player.name or "?")
end
local function shortNumber(value)
if U.Short then return U.Short(value) end
return tostring(math.floor(tonumber(value) or 0))
end
local function pct(value)
return string.format("%.2f%%", (tonumber(value) or 0) * 100)
end
function A:NormalizeRulesText(value)
value=tostring(value or ""):gsub("[%c]+"," "):gsub("%s+"," ")
value=value:gsub("^%s+",""):gsub("%s+$","")
return U.Trunc and U.Trunc(value,RULE_TEXT_MAX_CHARS) or value:sub(1,RULE_TEXT_MAX_CHARS)
end
function A:BuildRulesMessages(config)
config=config or effectiveConfig()
local baseline=RULE_BASELINE_LABELS[config.dpsBaseline or config.baseline or "rank1"] or "第一名"
local ratio=math.floor((tonumber(config.dpsRatio or config.ratio) or 0.6)*100+0.5)
local mode=config.dpsMode=="all" and "Boss战全目标" or "WCL口径/自定义"
local checks=config.checks or {}
local active=checks.active or {}
local messages={
string.format("NCL考核规则：DPS以「%s」为基准，达到%d%%及格；统计口径「%s」。",baseline,ratio,mode),
active.on and string.format("活跃度考核：达到%d%%及格。",math.floor((tonumber(active.v) or 0.5)*100+0.5))
or "活跃度考核：未启用。",
}
local custom=self:NormalizeRulesText(config.rulesAnnouncementText)
if custom~="" then messages[#messages+1]=custom end
return messages
end
local function splitEntries(header, entries)
local out, line = {}, header
for _, entry in ipairs(entries) do
local candidate = line .. (line == header and " " or "  ") .. entry
if #candidate > MESSAGE_BODY_LIMIT and line ~= header then
out[#out + 1] = line
line = header .. " " .. entry
else
line = candidate
end
end
if line ~= header then out[#out + 1] = line end
return out
end
local function modeFor(config)
return config.dpsMode == "all" and "all" or "boss"
end
local function performanceTopCount(config)
return math.max(1, math.min(8, math.floor(tonumber(config and config.performanceTopCount) or 3)))
end
function A:BuildPerformanceMessages(players, duration, config)
config = config or effectiveConfig()
local excluded = config.bosses or (NoWCL.Rules and NoWCL.Rules.GetActive and NoWCL.Rules:GetActive().bosses) or {}
local mode = modeFor(config)
local groups = { ALL={}, MELEE={}, RANGED={} }
for _, player in ipairs(players or {}) do
if roleOf(player) == "DAMAGER" and not excluded[player.name] then
local row={player=player,amount=U.PlayerDisplayAmount(player,mode,duration,config.taskContrib)}
groups.ALL[#groups.ALL+1]=row
groups[playerKind(player)][#groups[playerKind(player)] + 1] = row
end
end
local scopeLabel=config.performanceScope=="summary" and "所有战斗" or "本场"
local rankingMode=config.performanceRankingMode=="all" and "all" or "split"
local topCount=performanceTopCount(config)
local messages = {}
local selected=rankingMode=="all" and {"ALL"} or {"MELEE","RANGED"}
for _, group in ipairs(selected) do
table.sort(groups[group], function(left, right)
if left.amount == right.amount then return tostring(left.player.name) < tostring(right.player.name) end
return left.amount > right.amount
end)
local entries = {}
for index = 1, math.min(topCount, #groups[group]) do
local row = groups[group][index]
entries[#entries + 1] = "【第"..index.."名】" .. identity(row.player) .. " " .. shortNumber(row.amount)
end
local header=scopeLabel..(group=="ALL" and "总伤害前"..topCount
or group=="MELEE" and "近战总伤害前"..topCount or "远程总伤害前"..topCount)
for _, line in ipairs(splitEntries(header, entries)) do messages[#messages + 1] = line end
end
return messages
end
function A:BuildFailureMessages(players, duration, config)
config = config or effectiveConfig()
local excluded = config.bosses or (NoWCL.Rules and NoWCL.Rules.GetActive and NoWCL.Rules:GetActive().bosses) or {}
local checks = config.checks or {}
local mode = modeFor(config)
local baseline = U.DpsBaselineValue(players, config.dpsBaseline or config.baseline or "rank1",
excluded,mode,duration,config.taskContrib)
local ratio = tonumber(config.dpsRatio or config.ratio) or 0.6
local activeEntries, dpsEntries = {}, {}
local includeActivity=config.failureActivity~=false
local includeDps=config.failureDps~=false
if includeActivity and checks.active and checks.active.on then
local threshold = tonumber(checks.active.v) or 0.5
for _, player in ipairs(players or {}) do
if not excluded[player.name] and (tonumber(player.activePct) or 0) < threshold then
activeEntries[#activeEntries + 1] = identity(player) .. " " .. pct(player.activePct)
end
end
end
if includeDps and baseline > 0 then
for _, player in ipairs(players or {}) do
if roleOf(player) == "DAMAGER" and not excluded[player.name] then
local relative=U.PlayerDisplayRate(player,mode,duration,config.taskContrib)/baseline
if relative < ratio then dpsEntries[#dpsEntries + 1] = identity(player) .. " " .. pct(relative) end
end
end
end
local messages = {}
local scopeLabel=config.failureScope=="summary" and "所有战斗" or "本场"
for _, line in ipairs(splitEntries(scopeLabel.."活跃度不及格", activeEntries)) do messages[#messages + 1] = line end
for _, line in ipairs(splitEntries(scopeLabel.."DPS不及格", dpsEntries)) do messages[#messages + 1] = line end
return messages
end
function A:BuildDeathMessages(players)
local deaths = {}
for _, player in ipairs(players or {}) do
for _, detail in ipairs(player.deathDetails or {}) do
deaths[#deaths + 1] = {
name=player.name,
guid=player.guid,
detail=detail,
deathMs=tonumber(detail and detail[1]) or 0,
}
end
end
table.sort(deaths, function(left, right)
if left.deathMs == right.deathMs then return tostring(left.name) < tostring(right.name) end
return left.deathMs < right.deathMs
end)
if #deaths == 0 then return { "本场没有角色死亡" } end
local messages = {}
for _, death in ipairs(deaths) do
if NoWCL.DeathNotice and NoWCL.DeathNotice.BuildMessage then
messages[#messages + 1] = NoWCL.DeathNotice:BuildMessage(death.name, death.detail, death.guid)
end
end
return messages
end
function A:BuildPullMessages(segment, puller)
if not (segment and segment.isBoss and puller) then return {} end
local name=shortName(puller)
local player=NoWCL.Stats and NoWCL.Stats.roster and NoWCL.Stats.roster[name] or {}
local label=identity({name=name,class=player.class,guid=player.guid,groupLabel=player.groupLabel})
local method=segment.pullMethod and segment.pullMethod~="" and "（"..tostring(segment.pullMethod).."）" or ""
return { "开怪："..label..method.." -> 「"..tostring(segment.name or "Boss").."」" }
end
function A:SetEnabled(feature, enabled)
local election = NoWCL.AnnouncementElection
return election and election.SetFeatureEnabled and election:SetFeatureEnabled(feature, enabled) or false
end
function A:IsEnabled(feature)
local election = NoWCL.AnnouncementElection
return election and election.EffectiveEnabled and election:EffectiveEnabled(feature) or false
end
function A:PublisherState(feature)
local election = NoWCL.AnnouncementElection
return election and election.GetOwnerLabel and election:GetOwnerLabel(feature) or "当前负责：无"
end
local function rulesChannel()
if IsInRaid and IsInRaid() then return "RAID" end
if IsInGroup and IsInGroup() then return "PARTY" end
return U.GroupChannel and U.GroupChannel() or nil
end
function A:_Publish(feature, fightKey, messages)
if #messages == 0 then return false, "empty" end
local election, publisher = NoWCL.AnnouncementElection, NoWCL.GroupPublisher
if not (election and election.PublishOnce and publisher and publisher.Publish) then return false, "unavailable" end
return election:PublishOnce(feature, fightKey, function()
return publisher:Publish(messages, {
source="team-announcement-" .. feature,
channel=feature=="rules" and rulesChannel() or nil,
append=true,
bypassRankingGap=true,
})
end)
end
function A:OnRosterUpdate(members,isGrouped)
self._rulesRosterToken=(self._rulesRosterToken or 0)+1
if not isGrouped then
self._rulesRosterReady=true
self._rulesRosterNames={}
return
end
local current,names={},{}
for _,member in ipairs(members or {}) do
local name=shortName(member and member.name)
if name and member.connected~=false then current[name]=true;names[#names+1]=name end
end
table.sort(names)
if not self._rulesRosterReady then
self._rulesRosterReady=true
self._rulesRosterNames=current
return
end
local added=false
for name in pairs(current) do
if not (self._rulesRosterNames and self._rulesRosterNames[name]) then added=true;break end
end
self._rulesRosterNames=current
if not added then return end
local token=self._rulesRosterToken
local rosterKey="roster:"..table.concat(names,",")
local function publish()
if token~=A._rulesRosterToken or not A:IsEnabled("rules") then return end
A:_Publish("rules",rosterKey,A:BuildRulesMessages(effectiveConfig()))
end
if C_Timer and C_Timer.After then C_Timer.After(RULE_ROSTER_DEBOUNCE,publish) else publish() end
end
function A:OnPullDetected(segment, puller)
if not (segment and segment.isBoss and puller and self:IsEnabled("pull")) then return false end
if not segment._teamPullAnnouncementKey then
local started=math.floor((time and time() or 0)/5)
segment._teamPullAnnouncementKey=table.concat({tostring(segment.name or "Boss"),
tostring(shortName(puller) or "?"),tostring(started)},":")
end
return self:_Publish("pull",segment._teamPullAnnouncementKey,self:BuildPullMessages(segment,puller))
end
function A:OnSegmentEnd(segment)
segment = segment or (NoWCL.Stats and NoWCL.Stats.segment)
if not (segment and segment.isBoss and segment._ended and NoWCL.Stats and NoWCL.Stats.GetPlayers) then return false end
local players, duration = NoWCL.Stats:GetPlayers()
if not players or #players == 0 then return false end
local config = effectiveConfig()
local fightKey = segment._announcementKey or (tostring(segment.name or "Boss") .. ":" .. math.floor(time() / 30))
local queued = false
if self:IsEnabled("performance") then
local rankingPlayers,rankingDuration=players,duration
if config.performanceScope=="summary" and NoWCL.Sync and NoWCL.Sync.GetView then
local view=NoWCL.Sync:GetView("all",false)
if view and view.players and #view.players>0 then rankingPlayers,rankingDuration=view.players,view.dur end
end
queued = self:_Publish("performance", fightKey,
self:BuildPerformanceMessages(rankingPlayers, rankingDuration, config)) or queued
end
if self:IsEnabled("failures") then
local failurePlayers,failureDuration=players,duration
if config.failureScope=="summary" and NoWCL.Sync and NoWCL.Sync.GetView then
local view=NoWCL.Sync:GetView("all",false)
if view and view.players and #view.players>0 then failurePlayers,failureDuration=view.players,view.dur end
end
queued = self:_Publish("failures", fightKey,
self:BuildFailureMessages(failurePlayers, failureDuration, config)) or queued
end
return queued
end
