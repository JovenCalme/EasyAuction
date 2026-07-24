local _, ns = ...

ns = ns or {}
ns.Mail = ns.Mail or {}
local Mail = ns.Mail

local RecipientRepository = {}
RecipientRepository.__index = RecipientRepository

local function newError(code, message, detail)
    if Mail.NewError then
        return Mail:NewError(code, message, detail)
    end
    return { code = code, message = message, detail = detail }
end

local function trim(value)
    if type(value) ~= "string" then return "" end
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function realmToken(value)
    if type(Mail.NormalizeRealmToken) == "function" then
        return Mail.NormalizeRealmToken(value)
    end
    return trim(value):gsub("%s+", "")
end

local function isSameRealm(left, right)
    if type(Mail.IsSameRealm) == "function" then return Mail.IsSameRealm(left, right) end
    return string.lower(realmToken(left)) == string.lower(realmToken(right))
end

local function realmKey(value, casefold)
    if type(Mail.NormalizeRealmKey) == "function" then return Mail.NormalizeRealmKey(value) end
    return casefold(realmToken(value))
end

local function copyRecord(source)
    local target = {}
    for key, value in pairs(source or {}) do
        target[key] = value
    end
    return target
end

local function decodeLegacy(value)
    if type(value) == "table" then return value end
    if type(value) ~= "string" then return nil end
    local name, realm, faction, level, classFile = value:match(
        "^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)$")
    if not name then name, realm, faction = value:match("^([^|]+)|?([^|]*)|?([^|]*)") end
    if not name then return nil end
    return {
        name = name,
        realm = realm ~= "" and realm or nil,
        faction = faction ~= "" and faction or nil,
        level = tonumber(level),
        classFile = classFile ~= "" and classFile or nil,
    }
end

function RecipientRepository.New(deps)
    deps = deps or {}
    local storage = deps.storage or {}
    storage.contacts = type(storage.contacts) == "table" and storage.contacts or {}
    storage.recent = type(storage.recent) == "table" and storage.recent or {}
    storage.recentLimit = tonumber(storage.recentLimit) or 20
    storage.blacklist = type(storage.blacklist) == "table" and storage.blacklist or {}
    storage.blacklist.order = type(storage.blacklist.order) == "table"
        and storage.blacklist.order or {}
    storage.blacklist.byKey = type(storage.blacklist.byKey) == "table"
        and storage.blacklist.byKey or {}
    local globalStorage = deps.globalStorage or {}
    globalStorage.alts = type(globalStorage.alts) == "table" and globalStorage.alts or {}

    local repository = setmetatable({
        storage = storage,
        globalStorage = globalStorage,
        currentRealm = "",
        currentKey = nil,
        currentFaction = nil,
        now = deps.now or _G.time or os.time,
        casefold = deps.casefold or string.lower,
    }, RecipientRepository)
    repository:SetPlayerContext({
        name = deps.currentName,
        realm = deps.currentRealm,
        faction = deps.currentFaction,
    })
    return repository
end

function RecipientRepository:SetPlayerContext(context)
    context = context or {}
    self.currentRealm = realmToken(context.realm or self.currentRealm or "")
    self.currentFaction = context.faction or self.currentFaction
    local name = trim(context.name)
    if name == "" then
        self.currentKey = nil
        return false
    end
    self.currentKey = self.casefold(name)
    if self.currentRealm ~= "" then
        self.currentKey = self.currentKey .. "-" .. realmKey(self.currentRealm, self.casefold)
    end
    return true
end

function RecipientRepository:Normalize(value, source)
    value = decodeLegacy(value)
    if not value then
        return nil, newError("INVALID_RECIPIENT", "收件人记录格式无效")
    end

    local name = trim(value.name or value.sendName or value.displayName)
    local suppliedRealm = value.realm
    if name ~= "" and not suppliedRealm then
        local shortName, suffix = name:match("^([^-]+)%-(.+)$")
        if shortName and suffix then
            name = trim(shortName)
            suppliedRealm = suffix
        end
    end
    local realm = realmToken(suppliedRealm or self.currentRealm)
    if name == "" then
        return nil, newError("INVALID_RECIPIENT", "收件人姓名不能为空")
    end

    local foldedName = self.casefold(name)
    local foldedRealm = realmKey(realm, self.casefold)
    local key = foldedName
    if foldedRealm ~= "" then key = key .. "-" .. foldedRealm end
    local sendName = name
    local sameRealm = self.currentRealm ~= ""
        and isSameRealm(realm, self.currentRealm)
    if realm ~= "" and not sameRealm then sendName = sendName .. "-" .. realm end

    local result = copyRecord(value)
    result.name = name
    result.realm = realm ~= "" and realm or nil
    result.faction = value.faction or self.currentFaction
    result.recipientKey = key
    result.sendName = sendName
    result.displayName = trim(value.displayName) ~= "" and trim(value.displayName) or name
    result.source = source or value.source or "contact"
    if result.source == "alt" then
        result.isSelf = self.currentKey ~= nil and key == self.currentKey
    else
        result.isSelf = value.isSelf == true or (self.currentKey ~= nil and key == self.currentKey)
    end
    return result
end

local function findByKey(records, key, normalize)
    for index = 1, #records do
        local candidate = normalize(records[index])
        if candidate and candidate.recipientKey == key then
            return index, candidate
        end
    end
end

local function matchingBlacklistKeys(repository, recipientKey)
    local matches = {}
    local blacklist = repository.storage.blacklist
    for storedKey, record in pairs(blacklist.byKey) do
        local normalized = repository:Normalize(record, "blacklist")
        if storedKey == recipientKey or normalized and normalized.recipientKey == recipientKey then
            matches[storedKey] = true
        end
    end
    return matches
end

local function acceptsContext(record, context)
    if not context then return true end
    if context.faction and record.faction and context.faction ~= record.faction then return false end
    if context.realm and record.realm and not isSameRealm(context.realm, record.realm) then return false end
    return true
end

function RecipientRepository:AddContact(value)
    local normalized, err = self:Normalize(value, "contact")
    if not normalized then return nil, err end
    local index = findByKey(self.storage.contacts, normalized.recipientKey, function(item)
        return self:Normalize(item, "contact")
    end)
    if index then
        self.storage.contacts[index] = copyRecord(normalized)
    else
        self.storage.contacts[#self.storage.contacts + 1] = copyRecord(normalized)
    end
    return true
end

function RecipientRepository:RemoveContact(value)
    local normalized = self:Normalize(value, "contact")
    if not normalized then return false end
    local index = findByKey(self.storage.contacts, normalized.recipientKey, function(item)
        return self:Normalize(item, "contact")
    end)
    if not index then return false end
    table.remove(self.storage.contacts, index)
    return true
end

function RecipientRepository:ListContacts(context)
    local result, seen = {}, {}
    for index = 1, #self.storage.contacts do
        local normalized = self:Normalize(self.storage.contacts[index], "contact")
        local visible = context and context.includeBlacklisted == true
            or not self:IsBlacklisted(normalized)
        if normalized and visible and not seen[normalized.recipientKey]
            and acceptsContext(normalized, context) then
            seen[normalized.recipientKey] = true
            result[#result + 1] = copyRecord(normalized)
        end
    end
    table.sort(result, function(left, right)
        return self.casefold(left.displayName) < self.casefold(right.displayName)
    end)
    return result
end

function RecipientRepository:IsBlacklisted(value)
    local normalized = self:Normalize(value, "blacklist")
    if not normalized then return false end
    if self.storage.blacklist.byKey[normalized.recipientKey] ~= nil then return true end
    return next(matchingBlacklistKeys(self, normalized.recipientKey)) ~= nil
end

function RecipientRepository:AddBlacklist(value)
    local normalized, err = self:Normalize(value, "blacklist")
    if not normalized then return nil, err end
    if normalized.isSelf then
        return nil, newError("SELF_RECIPIENT", "不能把当前角色加入黑名单")
    end
    normalized.blockedAt = self.now()
    local blacklist = self.storage.blacklist
    local matches = matchingBlacklistKeys(self, normalized.recipientKey)
    for key in pairs(matches) do blacklist.byKey[key] = nil end
    blacklist.byKey[normalized.recipientKey] = copyRecord(normalized)
    for index = #blacklist.order, 1, -1 do
        if matches[blacklist.order[index]] or blacklist.order[index] == normalized.recipientKey then
            table.remove(blacklist.order, index)
        end
    end
    table.insert(blacklist.order, 1, normalized.recipientKey)
    return true
end

function RecipientRepository:RemoveBlacklist(value)
    local normalized = self:Normalize(value, "blacklist")
    if not normalized then return false end
    local blacklist = self.storage.blacklist
    local matches = matchingBlacklistKeys(self, normalized.recipientKey)
    if next(matches) == nil then return false end
    for key in pairs(matches) do blacklist.byKey[key] = nil end
    for index = #blacklist.order, 1, -1 do
        if matches[blacklist.order[index]] or blacklist.order[index] == normalized.recipientKey then
            table.remove(blacklist.order, index)
        end
    end
    return true
end

function RecipientRepository:ListBlacklist(context)
    local result, seen = {}, {}
    local blacklist = self.storage.blacklist
    for index = 1, #blacklist.order do
        local key = blacklist.order[index]
        local normalized = self:Normalize(blacklist.byKey[key], "blacklist")
        if normalized and not seen[normalized.recipientKey] and acceptsContext(normalized, context) then
            seen[normalized.recipientKey] = true
            result[#result + 1] = copyRecord(normalized)
        end
    end
    return result
end

function RecipientRepository:RecordSent(value)
    local normalized, err = self:Normalize(value, "recent")
    if not normalized then return nil, err end
    normalized.sentAt = self.now()
    local index = findByKey(self.storage.recent, normalized.recipientKey, function(item)
        return self:Normalize(item, "recent")
    end)
    if index then table.remove(self.storage.recent, index) end
    table.insert(self.storage.recent, 1, copyRecord(normalized))
    local limit = math.max(0, math.floor(self.storage.recentLimit))
    while #self.storage.recent > limit do table.remove(self.storage.recent) end
    return true
end

function RecipientRepository:ListRecent(context, limit)
    local result, seen = {}, {}
    local maximum = math.max(0, math.floor(tonumber(limit) or self.storage.recentLimit))
    for index = 1, #self.storage.recent do
        local normalized = self:Normalize(self.storage.recent[index], "recent")
        local visible = context and context.includeBlacklisted == true
            or not self:IsBlacklisted(normalized)
        if normalized and visible and not seen[normalized.recipientKey]
            and acceptsContext(normalized, context) then
            seen[normalized.recipientKey] = true
            result[#result + 1] = copyRecord(normalized)
            if #result >= maximum then break end
        end
    end
    return result
end

function RecipientRepository:UpsertAlt(value)
    local decoded = decodeLegacy(value)
    local normalized, err = self:Normalize(decoded, "alt")
    if not normalized then return nil, err end
    normalized.level = tonumber(decoded.level) or nil
    normalized.classFile = decoded.classFile
    normalized.updatedAt = self.now()
    normalized.isSelf = nil
    local index = findByKey(self.globalStorage.alts, normalized.recipientKey, function(item)
        return self:Normalize(item, "alt")
    end)
    if index then
        local current = self:Normalize(self.globalStorage.alts[index], "alt") or {}
        if normalized.level == nil then normalized.level = current.level end
        if normalized.classFile == nil then normalized.classFile = current.classFile end
        if normalized.className == nil then normalized.className = current.className end
        self.globalStorage.alts[index] = copyRecord(normalized)
    else
        self.globalStorage.alts[#self.globalStorage.alts + 1] = copyRecord(normalized)
    end
    return true
end

function RecipientRepository:ListAlts(context)
    context = context or {}
    local result, seen = {}, {}
    local includeAllFactions = context.includeAllFactions == true
    for index = 1, #self.globalStorage.alts do
        local normalized = self:Normalize(self.globalStorage.alts[index], "alt")
        local sameFaction = includeAllFactions
            or not self.currentFaction or not normalized or not normalized.faction
            or normalized.faction == self.currentFaction
        local sameRealm = not normalized or not context.currentRealmOnly
            or isSameRealm(normalized.realm, self.currentRealm)
        local visible = context.includeBlacklisted == true or not self:IsBlacklisted(normalized)
        if normalized and visible and sameFaction and sameRealm and acceptsContext(normalized, context)
            and not seen[normalized.recipientKey] then
            seen[normalized.recipientKey] = true
            local item = copyRecord(normalized)
            if includeAllFactions and item.realm and item.realm ~= "" then
                item.displayName = item.name .. "-" .. item.realm
                if item.faction and item.faction ~= "" then
                    item.displayName = item.displayName .. "-" .. item.faction
                end
            end
            result[#result + 1] = item
        end
    end
    table.sort(result, function(left, right)
        return self.casefold(left.displayName) < self.casefold(right.displayName)
    end)
    return result
end

Mail.RecipientRepository = RecipientRepository
