local addonName, NoWCL = ...
local R = {}
NoWCL.Rules = R
local function deepcopy(t)
if type(t) ~= "table" then return t end
local r = {}
for k, v in pairs(t) do r[k] = deepcopy(v) end
return r
end
local DEFAULT = {
name = "默认团规",
bosses = {},
checks = {
{ id="dps_floor",  metric="dps",       baseline="rank1", op=">=", ratio=0.60, desc="DPS≥第一名60%" },
{ id="active",     metric="active",    baseline="fixed", op=">=", value=0.50, desc="活跃度≥50%" },
{ id="interrupts", metric="interrupt", baseline="fixed", op=">=", value=1,    desc="打断≥1", optional=true },
},
}
function R:EnsureDefault()
local db = NoWCL.db
if not db then return end
if not db.rulesets["default"] then
db.rulesets["default"] = deepcopy(DEFAULT)
end
if not db.rulesets[db.activeRuleset] then
db.activeRuleset = "default"
end
end
function R:GetActive()
local db = NoWCL.db
if not db then return DEFAULT end
return db.rulesets[db.activeRuleset] or db.rulesets["default"] or DEFAULT
end
local function bossSessionKey()
if not UnitGUID then return nil end
if not (IsInGroup and IsInGroup()) then
local guid=UnitGUID("player")
return guid and ("solo:"..guid) or nil
end
if UnitIsGroupLeader and UnitIsGroupLeader("player") then
local guid=UnitGUID("player")
return guid and ("group:"..guid) or nil
end
local count=(GetNumGroupMembers and GetNumGroupMembers()) or 0
if IsInRaid and IsInRaid() then
for i=1,count do
local unit="raid"..i
if UnitIsGroupLeader and UnitIsGroupLeader(unit) then
local guid=UnitGUID(unit)
return guid and ("group:"..guid) or nil
end
end
else
for i=1,math.max(0,count-1) do
local unit="party"..i
if UnitIsGroupLeader and UnitIsGroupLeader(unit) then
local guid=UnitGUID(unit)
return guid and ("group:"..guid) or nil
end
end
end
return nil
end
function R:ReconcileBossSession()
local rs=self:GetActive()
local key=bossSessionKey()
if not key then return false end
if rs.bossSessionKey==key then return false end
rs.bosses={}
rs.bossSessionKey=key
return true
end
local function baselineValue(players, baseline)
if baseline == "fixed" then return nil end
local vals = {}
for _, p in ipairs(players) do vals[#vals+1] = p.dps or 0 end
table.sort(vals, function(a,b) return a>b end)
if baseline == "rank1" then return vals[1] or 0 end
if baseline == "rank2" then return vals[2] or vals[1] or 0 end
if baseline == "average" then
local s=0; for _,v in ipairs(vals) do s=s+v end
return (#vals>0) and s/#vals or 0
end
if baseline == "median" then
local m = #vals
if m==0 then return 0 end
return vals[math.ceil(m/2)]
end
return 0
end
local function evalCheck(check, player, players)
local m = check.metric
if m == "dps" then
local base = baselineValue(players, check.baseline) or 0
local need = base * (check.ratio or 1)
local got = player.dps or 0
return got >= need, string.format("%s/%s", NoWCL.Util.Short(got), NoWCL.Util.Short(need))
elseif m == "active" then
local got = player.activePct or 0
return got >= (check.value or 0), NoWCL.Util.Pct(got)
elseif m == "interrupt" then
return (player.interrupts or 0) >= (check.value or 0), tostring(player.interrupts or 0)
elseif m == "dispel" then
return (player.dispels or 0) >= (check.value or 0), tostring(player.dispels or 0)
elseif m == "beat_role" then
local tankDmg = 0
for _,p in ipairs(players) do
if NoWCL.Util.RoleOfPlayer(p)=="TANK" then tankDmg = math.max(tankDmg, p.dmg or 0) end
end
return (player.dmg or 0) > tankDmg, NoWCL.Util.Short(player.dmg or 0)
elseif m and m:match("^uptime:") then
local key = m:sub(8)
local got = (player.uptime and player.uptime[key]) or 0
return got >= (check.value or 0), NoWCL.Util.Pct(got)
elseif m and m:match("^ready:") then
local key = m:sub(7)
local ok = player.ready and player.ready[key] == 1
return ok, ok and "有" or "无"
end
return true, ""
end
function R:Evaluate(player, players)
local rs = self:GetActive()
local fails, results, allPass = {}, {}, true
for _, check in ipairs(rs.checks or {}) do
local pass, detail = evalCheck(check, player, players)
results[check.id] = { pass=pass, detail=detail, desc=check.desc, optional=check.optional }
if not pass and not check.optional then
allPass = false
fails[#fails+1] = check.desc
end
end
return { pass=allPass, fails=fails, results=results }
end
function R:IsBoss(name)
local rs = self:GetActive()
return rs.bosses and rs.bosses[name] == true
end
function R:SetBoss(name, v)
self:ReconcileBossSession()
local rs = self:GetActive()
rs.bosses = rs.bosses or {}
rs.bosses[name] = v and true or nil
if NoWCL.Sync then NoWCL.Sync:BroadcastConfig() end
end
