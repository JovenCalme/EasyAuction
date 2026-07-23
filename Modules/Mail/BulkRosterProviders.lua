local _, ns = ...

ns = ns or {}
ns.Mail = ns.Mail or {}
local Mail = ns.Mail

local BulkRosterProviders = {}

local function clone(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = clone(item) end
    return result
end

local function realmToken(value)
    return type(value) == "string" and value:gsub("%s+", "") or ""
end

local function recipientKey(name, realm, currentRealm)
    if type(name) ~= "string" or name == "" then return nil end
    if not realm then
        local shortName, suffix = name:match("^([^-]+)%-(.+)$")
        if shortName and suffix then name, realm = shortName, suffix end
    end
    realm = realmToken(realm or currentRealm)
    local sendName = name .. (realm ~= "" and ("-" .. realm) or "")
    return string.lower(sendName:gsub("%s+", ""))
end

local function normalizeMember(value, sourceKind, currentRealm, currentKey)
    if type(value) ~= "table" then return nil end
    local name = value.name or value.displayName
    if type(name) ~= "string" or name == "" then return nil end
    local realm = realmToken(value.realm or currentRealm)
    local sendName = value.sendName or name .. (realm ~= "" and ("-" .. realm) or "")
    local result = clone(value)
    result.name = name
    result.realm = realm ~= "" and realm or nil
    result.sendName = sendName
    result.displayName = value.displayName or name
    result.recipientKey = value.recipientKey or string.lower(sendName:gsub("%s+", ""))
    result.source = sourceKind
    result.isSelf = value.isSelf == true or (currentKey ~= nil and result.recipientKey == currentKey)
    return result
end

local function classFileFor(className, classFile)
    if classFile and classFile ~= "" then return classFile end
    local male = _G.LOCALIZED_CLASS_NAMES_MALE or {}
    local female = _G.LOCALIZED_CLASS_NAMES_FEMALE or {}
    for token, localized in pairs(male) do
        if localized == className or female[token] == className then return token end
    end
end

function BulkRosterProviders.ListFriends(deps)
    deps = deps or {}
    local api = deps.api or _G
    local friendApi = api.C_FriendList
    if not friendApi then return {} end
    if type(friendApi.ShowFriends) == "function" then pcall(friendApi.ShowFriends) end
    local currentName, unitRealm = deps.currentName, deps.currentPlayerRealm
    if not currentName and api.UnitName then currentName, unitRealm = api.UnitName("player") end
    local currentRealm = realmToken(deps.currentRealm or unitRealm or "")
    local currentKey = recipientKey(currentName, unitRealm, currentRealm)
    local count = type(friendApi.GetNumFriends) == "function" and friendApi.GetNumFriends() or 0
    local result = {}
    for index = 1, count do
        local info = type(friendApi.GetFriendInfoByIndex) == "function"
            and friendApi.GetFriendInfoByIndex(index)
        local member = info and normalizeMember({
            name = info.name,
            level = info.level,
            className = info.className,
            classFile = classFileFor(info.className, info.classFile or info.classFilename),
            online = info.connected == true,
        }, "friend", currentRealm, currentKey)
        if member and not member.isSelf then result[#result + 1] = member end
    end
    table.sort(result, function(left, right)
        return string.lower(left.displayName) < string.lower(right.displayName)
    end)
    return result
end

local function newProvider(kind, deps)
    deps = deps or {}
    local api = deps.api or _G
    local currentName, unitRealm = deps.currentName, deps.currentPlayerRealm
    if not currentName and api.UnitName then currentName, unitRealm = api.UnitName("player") end
    local currentRealm = realmToken(deps.currentRealm or unitRealm or "")
    return {
        kind = kind,
        deps = deps,
        generation = 0,
        loading = false,
        stale = false,
        members = {},
        ranks = {},
        subscribers = {},
        currentRealm = currentRealm,
        currentKey = recipientKey(currentName, unitRealm, currentRealm),
    }
end

local function notify(provider)
    local snapshot = provider:GetSnapshot()
    for _, callback in pairs(provider.subscribers) do callback(snapshot) end
end

local function subscribe(provider, owner, callback)
    if owner == nil or type(callback) ~= "function" then return false end
    provider.subscribers[owner] = callback
    return true
end

local GroupProvider = {}
GroupProvider.__index = GroupProvider

function BulkRosterProviders.NewGroup(deps)
    local provider = newProvider("party", deps)
    provider.sourceKind = "party"
    return setmetatable(provider, GroupProvider)
end

function GroupProvider:SetSource(sourceKind)
    if sourceKind ~= "party" and sourceKind ~= "raid" then return false end
    self.sourceKind = sourceKind
    self.kind = sourceKind
    return true
end

function GroupProvider:_nativeRaid()
    local result = {}
    local api = self.deps.api or _G
    local count = api.GetNumGroupMembers and api.GetNumGroupMembers() or 0
    local inRaid = not api.IsInRaid or api.IsInRaid()
    for index = 1, count do
        local name, _, subgroup, _, _, classFile, _, online = api.GetRaidRosterInfo(index)
        if name then
            local shortName, realm = name:match("^([^-]+)%-(.+)$")
            local unit = inRaid and ("raid" .. index)
                or (index == 1 and "player" or ("party" .. (index - 1)))
            result[#result + 1] = {
                name = shortName or name,
                realm = realm,
                subgroup = tonumber(subgroup) or 1,
                classFile = classFile,
                online = online ~= false,
                isSelf = api.UnitIsUnit and api.UnitIsUnit(unit, "player") or false,
                rosterIndex = index,
            }
        end
    end
    return result
end

function GroupProvider:_nativeParty()
    local api = self.deps.api or _G
    if api.IsInRaid and api.IsInRaid() then
        local raid = self:_nativeRaid()
        local ownSubgroup
        for index = 1, #raid do if raid[index].isSelf then ownSubgroup = raid[index].subgroup break end end
        local result = {}
        for index = 1, #raid do
            if raid[index].subgroup == ownSubgroup then result[#result + 1] = raid[index] end
        end
        return result
    end
    local result = {}
    for index = 0, 4 do
        local unit = index == 0 and "player" or ("party" .. index)
        local exists = index == 0 or not api.UnitExists or api.UnitExists(unit)
        if exists and api.UnitName then
            local name, realm = api.UnitName(unit)
            if name then
                local _, classFile
                if api.UnitClass then _, classFile = api.UnitClass(unit) end
                result[#result + 1] = {
                    name = name, realm = realm, subgroup = 1, classFile = classFile,
                    online = not api.UnitIsConnected or api.UnitIsConnected(unit), isSelf = index == 0,
                    rosterIndex = index + 1,
                }
            end
        end
    end
    return result
end

function GroupProvider:Refresh()
    self.generation = self.generation + 1
    local raw
    if self.sourceKind == "raid" then
        raw = self.deps.listRaid and self.deps.listRaid() or self:_nativeRaid()
    else
        raw = self.deps.listParty and self.deps.listParty() or self:_nativeParty()
    end
    self.members = {}
    for index = 1, #(raw or {}) do
        local member = normalizeMember(raw[index], self.sourceKind, self.currentRealm, self.currentKey)
        if member then
            member.rosterIndex = member.rosterIndex or index
            self.members[#self.members + 1] = member
        end
    end
    table.sort(self.members, function(left, right)
        if self.sourceKind == "raid" and (left.subgroup or 1) ~= (right.subgroup or 1) then
            return (left.subgroup or 1) < (right.subgroup or 1)
        end
        return (left.rosterIndex or 0) < (right.rosterIndex or 0)
    end)
    self.loading = false
    self.stale = false
    notify(self)
    return self.generation
end

function GroupProvider:GetSnapshot()
    return {
        generation = self.generation, sourceKind = self.sourceKind, loading = self.loading,
        stale = self.stale, members = clone(self.members), ranks = {},
    }
end

function GroupProvider:Subscribe(owner, callback) return subscribe(self, owner, callback) end

local GuildProvider = {}
GuildProvider.__index = GuildProvider

function BulkRosterProviders.NewGuild(deps)
    return setmetatable(newProvider("guild", deps), GuildProvider)
end

function GuildProvider:_request()
    if self.deps.requestRoster then return self.deps.requestRoster() end
    local api = self.deps.api or _G
    if api.C_GuildInfo and api.C_GuildInfo.GuildRoster then return api.C_GuildInfo.GuildRoster() end
    if api.GuildRoster then return api.GuildRoster() end
end

function GuildProvider:_nativeList()
    local api = self.deps.api or _G
    local members, ranks = {}, {}
    local count = api.GetNumGuildMembers and api.GetNumGuildMembers() or 0
    for index = 1, count do
        local name, rankName, rankIndex, _, _, _, _, _, online, _, classFile = api.GetGuildRosterInfo(index)
        if name then
            local shortName, realm = name:match("^([^-]+)%-(.+)$")
            members[#members + 1] = {
                name = shortName or name, realm = realm, rankName = rankName,
                rankIndex = tonumber(rankIndex) or 0, classFile = classFile, online = online == true,
                rosterIndex = index,
            }
            ranks[tonumber(rankIndex) or 0] = rankName
        end
    end
    return members, ranks
end

function GuildProvider:Refresh()
    self.generation = self.generation + 1
    self.loading = true
    self.stale = true
    self:_request()
    notify(self)
    return self.generation
end

function GuildProvider:OnRosterUpdate()
    local raw, ranks
    if self.deps.listGuild then raw, ranks = self.deps.listGuild() else raw, ranks = self:_nativeList() end
    self.members, self.ranks = {}, clone(ranks or {})
    for index = 1, #(raw or {}) do
        local member = normalizeMember(raw[index], "guild", self.currentRealm, self.currentKey)
        if member then
            member.rosterIndex = member.rosterIndex or index
            self.members[#self.members + 1] = member
            if member.rankIndex ~= nil and member.rankName then self.ranks[member.rankIndex] = member.rankName end
        end
    end
    table.sort(self.members, function(left, right)
        local leftRank, rightRank = tonumber(left.rankIndex) or 999, tonumber(right.rankIndex) or 999
        if leftRank ~= rightRank then return leftRank < rightRank end
        return string.lower(left.displayName) < string.lower(right.displayName)
    end)
    self.loading = false
    self.stale = false
    notify(self)
    return self.generation
end

function GuildProvider:GetSnapshot(filter)
    filter = filter or {}
    local members = {}
    local rankFilter = filter.rankIndices
    local hasRankFilter = type(rankFilter) == "table" and next(rankFilter) ~= nil
    for index = 1, #self.members do
        local member = self.members[index]
        local rankAllowed = not hasRankFilter or rankFilter[member.rankIndex] == true
        local onlineAllowed = not filter.onlineOnly or member.online == true
        if rankAllowed and onlineAllowed then members[#members + 1] = clone(member) end
    end
    return {
        generation = self.generation, sourceKind = "guild", loading = self.loading,
        stale = self.stale, members = members, ranks = clone(self.ranks),
    }
end

function GuildProvider:Subscribe(owner, callback) return subscribe(self, owner, callback) end

local CustomProvider = {}
CustomProvider.__index = CustomProvider

function BulkRosterProviders.NewCustom(deps)
    local provider = newProvider("custom", deps)
    provider.repository = deps and deps.recipientGroupRepository
    provider.resolveMembers = deps and deps.resolveMembers
    if provider.repository and provider.repository.Subscribe then
        provider.repository:Subscribe(provider, function() provider:Refresh("GROUP_CHANGED") end)
    end
    return setmetatable(provider, CustomProvider)
end

function CustomProvider:SetGroup(groupId)
    self.groupId = groupId
end

function CustomProvider:Refresh()
    self.generation = self.generation + 1
    self.members = {}
    local raw
    if self.resolveMembers then raw = self.resolveMembers(self.groupId) end
    if raw == nil then raw = self.repository and self.repository:GetMembers(self.groupId) or {} end
    for index = 1, #raw do
        local member = normalizeMember(raw[index], "custom", self.currentRealm, self.currentKey)
        if member then self.members[#self.members + 1] = member end
    end
    self.loading = false
    self.stale = false
    notify(self)
    return self.generation
end

function CustomProvider:GetSnapshot()
    return {
        generation = self.generation, sourceKind = "custom", sourceGroupId = self.groupId,
        loading = self.loading, stale = self.stale, members = clone(self.members), ranks = {},
    }
end

function CustomProvider:Subscribe(owner, callback) return subscribe(self, owner, callback) end

local RosterService = {}
RosterService.__index = RosterService

function BulkRosterProviders.NewService(deps)
    deps = deps or {}
    return setmetatable({ providers = deps.providers or {}, sourceKind = "raid", subscribers = {} }, RosterService)
end

function RosterService:SetSource(sourceKind, sourceGroupId)
    if not self.providers[sourceKind] then return false end
    self.sourceKind = sourceKind
    self.sourceGroupId = sourceGroupId
    local provider = self.providers[sourceKind]
    if provider.SetSource then provider:SetSource(sourceKind) end
    if provider.SetGroup then provider:SetGroup(sourceGroupId) end
    return true
end

function RosterService:Refresh(reason)
    local provider = self.providers[self.sourceKind]
    return provider and provider:Refresh(reason) or nil
end

function RosterService:GetSnapshot(filter)
    local provider = self.providers[self.sourceKind]
    if not provider then
        return { generation = 0, sourceKind = self.sourceKind, loading = false, stale = true, members = {}, ranks = {} }
    end
    return provider:GetSnapshot(filter)
end

function RosterService:Subscribe(owner, callback)
    local provider = self.providers[self.sourceKind]
    if not provider then return false end
    self.subscribers[owner] = callback
    return provider:Subscribe(owner, callback)
end

Mail.BulkRosterProviders = BulkRosterProviders
Mail.BulkRosterService = RosterService
