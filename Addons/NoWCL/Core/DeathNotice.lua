local addonName, NoWCL = ...
local N = {}
NoWCL.DeathNotice = N
local U = NoWCL.Util
local NOTICE_TTL = 30
local MAX_DEATH_NOTICES = 5
local function localEnabled()
local settings = NoWCL.db and NoWCL.db.settings
return settings and settings.deathAnnounce == true or false
end
function N:IsEnabled()
local election = NoWCL.AnnouncementElection
if election and election.EffectiveEnabled then return election:EffectiveEnabled("death") end
local sync = NoWCL.Sync
if sync and sync.HasLeaderAuthority and sync:HasLeaderAuthority() and sync.cfg then
return sync.cfg.deathAnnounce == true
end
return localEnabled()
end
function N:SetEnabled(enabled)
local election = NoWCL.AnnouncementElection
if election and election.SetFeatureEnabled then return election:SetFeatureEnabled("death", enabled) end
local sync = NoWCL.Sync
if sync and sync.HasLeaderAuthority and sync:HasLeaderAuthority() then return false end
local settings = NoWCL.db and NoWCL.db.settings
if not settings then return false end
settings.deathAnnounce = enabled and true or false
if sync and sync.BroadcastConfig then sync:BroadcastConfig() end
return true
end
function N:CanPublish()
if not self:IsEnabled() then return false end
if not (IsInGroup and IsInGroup()) then return false end
if not (U and U.GroupChannel and U.GroupChannel()) then return false end
local election = NoWCL.AnnouncementElection
if election and election.IsOwner then return election:IsOwner("death") end
local sync = NoWCL.Sync
if sync and sync.HasLeaderAuthority and sync:HasLeaderAuthority() then return false end
return true
end
function N:BuildMessage(name, deathDetail, guid)
local identity = U and U.ResolveGroupCharacterLabel
and U.ResolveGroupCharacterLabel(name, guid)
or ("0-0 未知职业「" .. (tostring(name or "未知角色"):match("^[^-]+") or "未知角色") .. "」")
local hits = deathDetail and deathDetail[2]
local hit = hits and hits[#hits]
local spellName = hit and hit[4] or "未知攻击"
return identity .. " 死亡 最后一击 " .. tostring(spellName)
end
function N:Announce(name, guid, deathDetail, fightToken)
if not self:IsEnabled() or not (IsInGroup and IsInGroup())
or not (U and U.GroupChannel and U.GroupChannel()) then return false, "inactive" end
local publisher = NoWCL.GroupPublisher
if not (publisher and publisher.Publish) then return false, "publisher-missing" end
local now = GetTime and GetTime() or time()
self._recent = self._recent or {}
for key, at in pairs(self._recent) do
if now - at > NOTICE_TTL then self._recent[key] = nil end
end
local deathMs = deathDetail and tonumber(deathDetail[1]) or 0
local key = tostring(guid or name or "?") .. ":" .. tostring(deathMs or 0)
if self._recent[key] then return false, "duplicate" end
self._recent[key] = now
fightToken = fightToken or "__unspecified_fight"
if self._fightToken ~= fightToken then
self._fightToken = fightToken
self._fightDeaths = 0
self._limitPublished = nil
end
self._fightDeaths = (self._fightDeaths or 0) + 1
if not self:CanPublish() then return false, "inactive" end
if self._fightDeaths > MAX_DEATH_NOTICES then
if self._limitPublished then return false, "limit" end
self._limitPublished = true
local message = "本场死亡已超过5人 后续不再通报"
local election = NoWCL.AnnouncementElection
if election and election.PublishOnce then
local fightKey = type(fightToken) == "table" and fightToken._announcementKey or tostring(fightToken)
return election:PublishOnce("death", tostring(fightKey) .. ":limit", function()
return publisher:Publish({ message }, { source="death-notice-limit", append=true, bypassRankingGap=true })
end)
end
return publisher:Publish({ message }, { source="death-notice-limit", append=true, bypassRankingGap=true })
end
local message = self:BuildMessage(name, deathDetail, guid)
local election = NoWCL.AnnouncementElection
if election and election.PublishOnce then
local fightKey = type(fightToken) == "table" and fightToken._announcementKey or tostring(fightToken)
return election:PublishOnce("death", tostring(fightKey) .. ":" .. key, function()
return publisher:Publish({ message }, { source="death-notice", append=true, bypassRankingGap=true })
end)
end
return publisher:Publish({ message }, { source="death-notice", append=true, bypassRankingGap=true })
end
