local _, ns = ...
local Mail = ns.Mail

local Config = {}
Config.__index = Config

local DEFAULT_MAIL = {
    schemaVersion = Mail.SCHEMA_VERSION,
    enabled = true,
    inbox = {
        enabled = true,
        groupStacks = true,
        advanced = false,
        defaultTab = false,
        qualityColors = false,
        operationTimeout = 5,
    },
    compose = {
        autoFillRecipient = true,
        enableAltClick = false,
        autoSend = false,
        bulkMatchMode = "EXACT_ID",
        enabledBags = { [0] = true, [1] = true, [2] = true, [3] = true, [4] = true },
        recipientByCategory = {},
    },
    recipientGroups = { order = {}, byId = {} },
    bulk = {
        enabled = true,
        maxRecipientsPerBatch = 200,
        historyMaxBatches = 50,
        historyMaxRecipientEntries = 5000,
        historyMaxAgeDays = 90,
        lastSourceKind = "raid",
        guildRankFilter = {},
    },
    bulkHistory = { order = {}, byId = {} },
    recipients = {
        contacts = {},
        recent = {},
        recentLimit = 20,
        blacklist = { order = {}, byKey = {} },
    },
    migrations = {},
}

local DEFAULT_GLOBAL = {
    schemaVersion = Mail.SCHEMA_VERSION,
    alts = {},
}

local function copyTable(source)
    if type(source) ~= "table" then return source end
    local result = {}
    for key, value in pairs(source) do
        result[key] = copyTable(value)
    end
    return result
end

local function fillMissing(target, defaults)
    for key, value in pairs(defaults) do
        if target[key] == nil then
            target[key] = copyTable(value)
        elseif type(value) == "table" and type(target[key]) == "table" then
            fillMissing(target[key], value)
        elseif type(value) == "table" then
            target[key] = copyTable(value)
        end
    end
end

local function booleanOrNil(value)
    if type(value) == "boolean" then return value end
    return nil
end

local function clampInteger(value, fallback, minimum, maximum)
    local number = math.floor(tonumber(value) or fallback)
    if number < minimum then number = minimum end
    if number > maximum then number = maximum end
    return number
end

local function normalizeConfig(mail)
    if type(mail.inbox.enabled) ~= "boolean" then mail.inbox.enabled = true end
    if type(mail.bulk.enabled) ~= "boolean" then mail.bulk.enabled = true end
    mail.inbox.operationTimeout = clampInteger(mail.inbox.operationTimeout, 5, 1, 30)
    mail.bulk.maxRecipientsPerBatch = clampInteger(mail.bulk.maxRecipientsPerBatch, 200, 1, 200)
    mail.bulk.historyMaxBatches = clampInteger(mail.bulk.historyMaxBatches, 50, 1, 200)
    mail.bulk.historyMaxRecipientEntries = clampInteger(
        mail.bulk.historyMaxRecipientEntries, 5000, 1, 20000)
    mail.bulk.historyMaxAgeDays = clampInteger(mail.bulk.historyMaxAgeDays, 90, 1, 365)
    mail.recipients.recentLimit = clampInteger(mail.recipients.recentLimit, 20, 1, 100)
    if type(mail.compose.autoFillRecipient) ~= "boolean" then mail.compose.autoFillRecipient = true end
    if type(mail.compose.enableAltClick) ~= "boolean" then mail.compose.enableAltClick = false end
    if type(mail.compose.autoSend) ~= "boolean" then mail.compose.autoSend = false end
    if mail.compose.bulkMatchMode ~= "EXACT_ID" then mail.compose.bulkMatchMode = "EXACT_ID" end
    if mail.bulk.lastSourceKind == "party" then mail.bulk.lastSourceKind = "raid" end
    local validSource = { raid = true, guild = true, custom = true }
    if not validSource[mail.bulk.lastSourceKind] then mail.bulk.lastSourceKind = "raid" end
    for bag = 0, 4 do
        if type(mail.compose.enabledBags[bag]) ~= "boolean" then
            mail.compose.enabledBags[bag] = true
        end
    end
end

local function migrateComposeShortcutDefaults(mail)
    if mail.migrations.composeShortcutsDefaultOff then return end
    mail.compose.enableAltClick = false
    mail.compose.autoSend = false
    mail.migrations.composeShortcutsDefaultOff = true
end

local function defaultRealmFactionKey()
    local realm = type(_G.GetRealmName) == "function" and _G.GetRealmName() or "Unknown"
    local faction
    if type(_G.UnitFactionGroup) == "function" then
        local first, second = _G.UnitFactionGroup("player")
        faction = second or first
    end
    return tostring(realm or "Unknown") .. "-" .. tostring(faction or "Neutral")
end

local function migrateInbox(mail, source)
    if type(source) ~= "table" or mail.migrations.inboxMailBag then return end
    local inbox = mail.inbox
    local groupStacks = booleanOrNil(source.GROUP_STACKS)
    local advanced = booleanOrNil(source.ADVANCED)
    local defaultTab = booleanOrNil(source.MAIL_DEFAULT)
    local qualityColors = booleanOrNil(source.QUALITY_COLORS)
    if groupStacks ~= nil then inbox.groupStacks = groupStacks end
    if advanced ~= nil then inbox.advanced = advanced end
    if defaultTab ~= nil then inbox.defaultTab = defaultTab end
    if qualityColors ~= nil then inbox.qualityColors = qualityColors end
    mail.migrations.inboxMailBag = true
end

local function decodeLegacyAlt(value)
    if type(value) == "table" then return copyTable(value) end
    if type(value) ~= "string" then return nil end
    local name, realm, faction, level, classFile = value:match(
        "^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)$")
    if not name then name, realm, faction = value:match("^([^|]*)|([^|]*)|([^|]*)") end
    if not name or name == "" then return nil end
    return {
        name = name,
        realm = realm ~= "" and realm or nil,
        faction = faction ~= "" and faction or nil,
        level = tonumber(level),
        classFile = classFile ~= "" and classFile or nil,
    }
end

local function altKey(value)
    local record = decodeLegacyAlt(value)
    if not record then return nil end
    local realm = type(Mail.NormalizeRealmKey) == "function"
        and Mail.NormalizeRealmKey(record.realm) or string.lower((record.realm or ""):gsub("%s+", ""))
    return string.lower((record.name or ""):gsub("%s+", "")) .. "|"
        .. realm .. "|" .. string.lower(record.faction or "")
end

local function mergePostalAlts(target, source)
    if type(target) ~= "table" or type(source) ~= "table" then return end
    local indexByKey = {}
    for index = 1, #target do
        local key = altKey(target[index])
        if key then indexByKey[key] = index end
    end
    for index = 1, #source do
        local incoming = decodeLegacyAlt(source[index])
        local key = altKey(incoming)
        if incoming and key then
            local targetIndex = indexByKey[key]
            if targetIndex then
                local current = decodeLegacyAlt(target[targetIndex]) or {}
                if current.level == nil then current.level = incoming.level end
                if current.classFile == nil then current.classFile = incoming.classFile end
                target[targetIndex] = current
            else
                target[#target + 1] = incoming
                indexByKey[key] = #target
            end
        end
    end
end

local function migratePostal(mail, globalConfig, source)
    if type(source) ~= "table" then return end
    if not mail.migrations.postal then
        local profile = source.profile
        local profileReady = type(profile) == "table"
            and (type(profile.BlackBook) == "table" or type(profile.QuickAttach) == "table")
        if profileReady then
            local blackBook = profile.BlackBook
            if type(blackBook) == "table" then
                local autoFill = booleanOrNil(blackBook.AutoFill)
                if autoFill ~= nil then mail.compose.autoFillRecipient = autoFill end
                if type(blackBook.contacts) == "table" and next(mail.recipients.contacts) == nil then
                    mail.recipients.contacts = copyTable(blackBook.contacts)
                end
                if type(blackBook.recent) == "table" and next(mail.recipients.recent) == nil then
                    mail.recipients.recent = copyTable(blackBook.recent)
                end
            end
            local quickAttach = profile.QuickAttach
            if type(quickAttach) == "table" then
                for bag = 0, 4 do
                    local value = booleanOrNil(quickAttach["EnableBag" .. bag])
                    if value ~= nil then mail.compose.enabledBags[bag] = value end
                end
            end
            mail.migrations.postal = true
        end
    end
    local global = source.global
    if type(global) == "table" and type(global.BlackBook) == "table" then
        mergePostalAlts(globalConfig.alts, global.BlackBook.alts)
    end
end

function Config.New(deps)
    deps = deps or {}
    return setmetatable({
        deps = deps,
        root = deps.dbRoot,
        realmFactionKey = deps.realmFactionKey,
        mail = nil,
        global = nil,
    }, Config)
end

function Config:GetRealmFactionKey()
    return self.realmFactionKey or defaultRealmFactionKey()
end

function Config:Initialize()
    local root = self.root
    if type(root) ~= "table" then
        _G.EasyAuctionDB2 = type(_G.EasyAuctionDB2) == "table" and _G.EasyAuctionDB2 or {}
        root = _G.EasyAuctionDB2
        self.root = root
    end
    local realmKey = self:GetRealmFactionKey()
    root[realmKey] = type(root[realmKey]) == "table" and root[realmKey] or {}
    local realmDB = root[realmKey]
    realmDB.mail = type(realmDB.mail) == "table" and realmDB.mail or {}
    root.__MailGlobal = type(root.__MailGlobal) == "table" and root.__MailGlobal or {}

    local mail = realmDB.mail
    local savedEnabled = booleanOrNil(mail.enabled)
    fillMissing(mail, DEFAULT_MAIL)
    mail.enabled = savedEnabled == nil and true or savedEnabled
    fillMissing(root.__MailGlobal, DEFAULT_GLOBAL)

    local legacyInbox = self.deps.legacyInbox
    if legacyInbox == nil then legacyInbox = _G.MAILBAGDB end
    local legacyPostal = self.deps.legacyPostal
    if legacyPostal == nil and type(_G.Postal) == "table" then
        legacyPostal = _G.Postal.db
    end
    if legacyPostal == nil and type(_G.Postal3DB) == "table" then
        legacyPostal = { global = _G.Postal3DB.global }
    end
    migrateInbox(mail, legacyInbox)
    migratePostal(mail, root.__MailGlobal, legacyPostal)
    migrateComposeShortcutDefaults(mail)
    normalizeConfig(mail)
    mail.schemaVersion = Mail.SCHEMA_VERSION
    root.__MailGlobal.schemaVersion = Mail.SCHEMA_VERSION

    self.mail = mail
    self.global = root.__MailGlobal
    self.realmFactionKey = realmKey
    return mail
end

function Config:GetMailConfig()
    local root = self.root or _G.EasyAuctionDB2
    local realm = type(root) == "table" and root[self:GetRealmFactionKey()]
    if not self.mail or type(realm) ~= "table" or realm.mail ~= self.mail then
        return self:Initialize()
    end
    return self.mail
end

function Config:GetGlobalConfig()
    local root = self.root or _G.EasyAuctionDB2
    if not self.global or type(root) ~= "table" or root.__MailGlobal ~= self.global then
        self:Initialize()
    end
    return self.global
end

function Config:GetEnabled()
    return self:GetMailConfig().enabled == true
end

function Config:RetryLegacyMigrations()
    local mail = self:GetMailConfig()
    local globalConfig = self:GetGlobalConfig()
    local legacyInbox = self.deps.legacyInbox
    if legacyInbox == nil then legacyInbox = _G.MAILBAGDB end
    local legacyPostal = self.deps.legacyPostal
    if legacyPostal == nil and type(_G.Postal) == "table" then
        legacyPostal = _G.Postal.db
    end
    if legacyPostal == nil and type(_G.Postal3DB) == "table" then
        legacyPostal = { global = _G.Postal3DB.global }
    end
    migrateInbox(mail, legacyInbox)
    migratePostal(mail, globalConfig, legacyPostal)
    migrateComposeShortcutDefaults(mail)
    normalizeConfig(mail)
    return true
end

function Config:SetEnabled(enabled)
    if type(enabled) ~= "boolean" then
        return nil, Mail:NewError("INVALID_ENABLED_VALUE", "邮箱开关必须是 boolean。")
    end
    self:GetMailConfig().enabled = enabled
    return true
end

local FEATURE_SECTIONS = { inbox = true, bulk = true }
local COMPOSE_OPTIONS = { autoFillRecipient = true, enableAltClick = true, autoSend = true }

function Config:GetFeatureEnabled(feature)
    if not FEATURE_SECTIONS[feature] then return false end
    return self:GetMailConfig()[feature].enabled == true
end

function Config:SetFeatureEnabled(feature, enabled)
    if not FEATURE_SECTIONS[feature] then
        return nil, Mail:NewError("INVALID_MAIL_FEATURE", "邮箱子功能无效。", { feature = feature })
    end
    if type(enabled) ~= "boolean" then
        return nil, Mail:NewError("INVALID_ENABLED_VALUE", "邮箱子功能开关必须是 boolean。")
    end
    self:GetMailConfig()[feature].enabled = enabled
    return true
end

function Config:GetComposeOption(option)
    if not COMPOSE_OPTIONS[option] then return false end
    return self:GetMailConfig().compose[option] == true
end

function Config:SetComposeOption(option, enabled)
    if not COMPOSE_OPTIONS[option] then
        return nil, Mail:NewError("INVALID_COMPOSE_OPTION", "发件快捷选项无效。", { option = option })
    end
    if type(enabled) ~= "boolean" then
        return nil, Mail:NewError("INVALID_ENABLED_VALUE", "发件快捷开关必须是 boolean。")
    end
    self:GetMailConfig().compose[option] = enabled
    return true
end

function Config:Reset()
    local root = self.root or _G.EasyAuctionDB2
    if type(root) ~= "table" then
        return nil, Mail:NewError("MAIL_CONFIG_UNAVAILABLE", "邮箱配置数据库不可用。")
    end
    local realmKey = self:GetRealmFactionKey()
    root[realmKey] = type(root[realmKey]) == "table" and root[realmKey] or {}
    root[realmKey].mail = copyTable(DEFAULT_MAIL)
    self.mail = root[realmKey].mail
    return self.mail
end

function Config.GetDefaults(_)
    return copyTable(DEFAULT_MAIL)
end

Mail.MailConfig = Config
Mail.Config = Mail.Config or Config.New()
