local _, ns = ...
ns = type(ns) == "table" and ns or {}
ns.Mail = type(ns.Mail) == "table" and ns.Mail or {}

local Mail = ns.Mail
local Aggregator = {}

local function copySource(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        copy[key] = value
    end
    return copy
end

local function appendUnique(fields, seen, value)
    if value == nil then return end
    value = tostring(value)
    if value == "" or seen[value] then return end
    seen[value] = true
    fields[#fields + 1] = value
end

local function searchFieldsFor(attachment)
    local fields = {}
    local seen = {}
    appendUnique(fields, seen, attachment.name)
    appendUnique(fields, seen, attachment.itemType)
    appendUnique(fields, seen, attachment.itemSubType)
    appendUnique(fields, seen, attachment.equipLoc)
    appendUnique(fields, seen, attachment.itemID)
    return fields
end

local function updateMinimum(current, candidate)
    if candidate == nil then return current end
    if current == nil or candidate < current then return candidate end
    return current
end

local function newItemEntry(source, attachment, id)
    return {
        id = id,
        kind = "item",
        itemKey = source.itemKey,
        itemLink = attachment.itemLink,
        displayName = attachment.name or "未知物品",
        icon = attachment.icon,
        totalCount = 0,
        totalMoney = 0,
        minDaysLeft = nil,
        quality = attachment.quality,
        searchFields = searchFieldsFor(attachment),
        sources = {},
    }
end

local function newMoneyEntry(id, settings)
    return {
        id = id,
        kind = "money",
        itemKey = nil,
        displayName = settings.moneyLabel or "金币",
        icon = settings.moneyIcon or "Interface\\Icons\\INV_Misc_Coin_02",
        totalCount = 0,
        totalMoney = 0,
        minDaysLeft = nil,
        quality = nil,
        searchFields = { settings.moneyLabel or "金币", "money", "cash" },
        sources = {},
    }
end

local function addSource(entry, source)
    entry.sources[#entry.sources + 1] = copySource(source)
    if source.kind == "item" then
        entry.totalCount = entry.totalCount + (tonumber(source.amount) or 0)
    else
        entry.totalMoney = entry.totalMoney + (tonumber(source.amount) or 0)
    end
    entry.minDaysLeft = updateMinimum(entry.minDaysLeft, source.daysLeft)
end

local function sourceMailIdentity(source, fallback)
    local mailKey = source.mailKey
    if type(mailKey) == "table" then
        return tostring(mailKey.fingerprint) .. ":" .. tostring(mailKey.duplicateOrdinal)
    end
    if source.mailIndex ~= nil then return "index:" .. tostring(source.mailIndex) end
    return "source:" .. tostring(source.sourceKey or fallback)
end

local function summarizeReturnability(entry)
    local byMail = {}
    for index = 1, #entry.sources do
        local source = entry.sources[index]
        local key = sourceMailIdentity(source, index)
        local state = byMail[key]
        if not state then
            state = { canReturn = source.canReturn == true, wasReturned = source.wasReturned == true }
            byMail[key] = state
        else
            state.canReturn = state.canReturn and source.canReturn == true
            state.wasReturned = state.wasReturned or source.wasReturned == true
        end
    end
    local returnable, nonReturnable, forwardRequired = 0, 0, 0
    for _, state in pairs(byMail) do
        if state.canReturn then
            returnable = returnable + 1
        else
            nonReturnable = nonReturnable + 1
            if state.wasReturned then forwardRequired = forwardRequired + 1 end
        end
    end
    entry.returnableMailCount = returnable
    entry.nonReturnableMailCount = nonReturnable
    entry.forwardRequiredMailCount = forwardRequired
end

local function matchesCategory(attachment, categoryId, registry)
    if categoryId == nil or categoryId == "all" then return true end
    if categoryId == "money" then return false end
    return registry and type(registry.Matches) == "function"
        and registry:Matches(categoryId, attachment) == true
end

function Aggregator.Build(snapshot, settings)
    settings = settings or {}
    local groupStacks = settings.groupStacks ~= false
    local categoryId = settings.categoryId or "all"
    local includeMoney = categoryId == "all" or categoryId == "money"
    local categoryRegistry = settings.categoryRegistry or Mail.ItemCategoryRegistry
    local entries = {}
    local grouped = {}
    local mails = snapshot and snapshot.mails or {}

    for mailPosition = 1, #mails do
        local mail = mails[mailPosition]
        if (tonumber(mail.cod) or 0) <= 0 then
            for attachmentPosition = 1, #(mail.attachments or {}) do
                local attachment = mail.attachments[attachmentPosition]
                if matchesCategory(attachment, categoryId, categoryRegistry) then
                    local source = attachment
                    local groupKey = groupStacks and ("item:" .. tostring(source.itemKey))
                        or ("source:" .. tostring(source.sourceKey))
                    local entry = grouped[groupKey]
                    if not entry then
                        entry = newItemEntry(source, attachment, groupKey)
                        grouped[groupKey] = entry
                        entries[#entries + 1] = entry
                    end
                    addSource(entry, source)
                end
            end
            if includeMoney and mail.moneySource then
                local source = mail.moneySource
                local groupKey = groupStacks and "money:all"
                    or ("money:" .. tostring(source.sourceKey))
                local entry = grouped[groupKey]
                if not entry then
                    entry = newMoneyEntry(groupKey, settings)
                    grouped[groupKey] = entry
                    entries[#entries + 1] = entry
                end
                addSource(entry, source)
            end
        end
    end

    for index = 1, #entries do summarizeReturnability(entries[index]) end

    return entries
end

function Aggregator.New()
    return setmetatable({}, { __index = Aggregator })
end

Mail.InboxAggregator = Aggregator

return Aggregator
