local _, ns = ...
ns = type(ns) == "table" and ns or {}
ns.Mail = type(ns.Mail) == "table" and ns.Mail or {}

local Mail = ns.Mail
local Repository = {}
Repository.__index = Repository

local DEFAULT_ATTACHMENT_LIMIT = 16

local function errorValue(code, message, retryable, sourceKey, rawEvent)
    return {
        code = code,
        message = message,
        retryable = retryable == true,
        sourceKey = sourceKey,
        rawEvent = rawEvent,
    }
end

local function encodeScalar(value)
    local valueType = type(value)
    if value == nil then
        return "n;"
    elseif valueType == "boolean" then
        return value and "b1;" or "b0;"
    end

    local text = tostring(value)
    local prefix = valueType == "number" and "d" or "s"
    return prefix .. tostring(#text) .. ":" .. text .. ";"
end

local function encodeSequence(values)
    local encoded = { "a", tostring(#values), "{" }
    for index = 1, #values do
        encoded[#encoded + 1] = encodeScalar(values[index])
    end
    encoded[#encoded + 1] = "}"
    return table.concat(encoded)
end

local function shallowCopy(source)
    local result = {}
    for key, value in pairs(source or {}) do
        result[key] = value
    end
    return result
end

local function normalizedNumber(value, fallback)
    value = tonumber(value)
    if value == nil then
        return fallback or 0
    end
    return value
end

local function hyperlinkPayload(link)
    if type(link) ~= "string" then
        return nil
    end
    return string.match(link, "|H([^|]+)|h")
end

local function joinList(value)
    if type(value) ~= "table" then
        return value
    end
    local parts = {}
    for index = 1, #value do
        parts[index] = tostring(value[index])
    end
    return table.concat(parts, ",")
end

local function canonicalItemIdentity(attachment)
    local payload = hyperlinkPayload(attachment.itemLink)
    if payload then
        return "link:" .. payload
    end
    if attachment.itemGUID ~= nil then
        return "guid:" .. tostring(attachment.itemGUID)
    end
    if attachment.itemID ~= nil then
        return "id:" .. encodeSequence({
            attachment.itemID,
            attachment.suffixID,
            joinList(attachment.bonusIDs),
            attachment.petSpeciesID,
            attachment.petLevel,
            attachment.petQuality,
        })
    end
    return nil
end

local function attachmentIdentitySeed(attachment)
    return encodeSequence({
        attachment.itemKey,
        attachment.itemID,
        attachment.name,
        attachment.icon,
        attachment.count,
        attachment.quality,
        attachment.itemType,
        attachment.itemSubType,
        attachment.equipLoc,
    })
end

local function normalizeHeader(raw)
    raw = raw or {}
    local cod = raw.cod
    if cod == nil then cod = raw.codAmount end
    if cod == nil then cod = raw.CODAmount end

    return {
        packageIcon = raw.packageIcon,
        stationery = raw.stationery or raw.stationeryIcon,
        sender = raw.sender,
        subject = raw.subject,
        money = normalizedNumber(raw.money, 0),
        cod = normalizedNumber(cod, 0),
        daysLeft = tonumber(raw.daysLeft),
        itemCount = math.max(0, normalizedNumber(raw.itemCount, 0)),
        wasRead = raw.wasRead == true,
        wasReturned = raw.wasReturned == true,
        textCreated = raw.textCreated == true,
        canReply = raw.canReply == true,
        isGM = raw.isGM == true,
        canDelete = raw.canDelete == true,
        canReturn = raw.canReturn == true,
        rawCapabilities = raw.capabilities,
    }
end

local function normalizeAttachment(raw, link, mailIndex, attachmentIndex)
    raw = raw or {}
    local attachment = {
        mailIndex = mailIndex,
        attachmentIndex = attachmentIndex,
        itemID = raw.itemID,
        itemGUID = raw.itemGUID,
        itemLink = link or raw.itemLink,
        suffixID = raw.suffixID,
        bonusIDs = raw.bonusIDs,
        petSpeciesID = raw.petSpeciesID,
        petLevel = raw.petLevel,
        petQuality = raw.petQuality,
        name = raw.name or raw.itemName,
        icon = raw.icon or raw.itemTexture or raw.texture,
        count = math.max(1, normalizedNumber(raw.count, 1)),
        quality = tonumber(raw.quality),
        itemType = raw.itemType or raw.className,
        itemSubType = raw.itemSubType or raw.subClassName,
        equipLoc = raw.equipLoc,
        classID = tonumber(raw.classID),
        subclassID = tonumber(raw.subclassID or raw.subClassID),
        dataPending = raw.dataPending == true,
    }
    attachment.itemKey = canonicalItemIdentity(attachment)
    attachment.identitySeed = attachmentIdentitySeed(attachment)
    return attachment
end

local function fingerprintGroups(records)
    local groups = {}
    for index = 1, #records do
        local record = records[index]
        local fingerprint = record.key and record.key.fingerprint or record.fingerprint
        local group = groups[fingerprint]
        if not group then
            group = {}
            groups[fingerprint] = group
        end
        group[#group + 1] = record
    end
    return groups
end

local function compareIndex(left, right)
    return left.index < right.index
end

local function assignDuplicateOrdinals(records, previousSnapshot)
    local previousGroups = previousSnapshot and fingerprintGroups(previousSnapshot.mails) or {}
    local currentGroups = fingerprintGroups(records)
    local ambiguous = {}

    for fingerprint, currentGroup in pairs(currentGroups) do
        table.sort(currentGroup, compareIndex)
        local previousGroup = previousGroups[fingerprint]
        if previousGroup then
            table.sort(previousGroup, compareIndex)
        end

        local previousCount = previousGroup and #previousGroup or 0
        local currentCount = #currentGroup
        local usedOrdinals = {}
        local maximumOrdinal = 0
        if previousGroup then
            for index = 1, previousCount do
                local ordinal = previousGroup[index].key.duplicateOrdinal
                usedOrdinals[ordinal] = true
                if ordinal > maximumOrdinal then maximumOrdinal = ordinal end
            end
        end

        if previousCount == currentCount and previousCount > 0 then
            for index = 1, currentCount do
                currentGroup[index].key = {
                    fingerprint = fingerprint,
                    duplicateOrdinal = previousGroup[index].key.duplicateOrdinal,
                }
            end
        else
            local sharedCount = math.min(previousCount, currentCount)
            for index = 1, sharedCount do
                currentGroup[index].key = {
                    fingerprint = fingerprint,
                    duplicateOrdinal = previousGroup[index].key.duplicateOrdinal,
                }
            end
            for index = sharedCount + 1, currentCount do
                repeat
                    maximumOrdinal = maximumOrdinal + 1
                until not usedOrdinals[maximumOrdinal]
                usedOrdinals[maximumOrdinal] = true
                currentGroup[index].key = {
                    fingerprint = fingerprint,
                    duplicateOrdinal = maximumOrdinal,
                }
            end
            if previousCount > 0 and (previousCount > 1 or currentCount > 1) then
                ambiguous[fingerprint] = true
            end
        end
    end

    return ambiguous
end

local function mailLookupKey(key)
    return encodeSequence({ key.fingerprint, key.duplicateOrdinal })
end

function Repository.MakeFingerprint(header)
    header = normalizeHeader(header)
    return encodeSequence({
        "mail-envelope-v2",
        header.stationery,
        header.sender,
        header.subject,
        header.isGM,
    })
end

function Repository.MakeSourceKey(mailKey, kind, identitySeed, occurrence)
    return encodeSequence({
        "source-v1",
        mailKey.fingerprint,
        mailKey.duplicateOrdinal,
        kind,
        identitySeed,
        occurrence or 1,
    })
end

function Repository.New(deps)
    deps = deps or {}
    return setmetatable({
        compat = deps.compat,
        attachmentLimit = deps.attachmentLimit or DEFAULT_ATTACHMENT_LIMIT,
        generation = 0,
        previousSnapshot = nil,
    }, Repository)
end

function Repository:Configure(deps)
    deps = deps or {}
    self.compat = deps.compat or self.compat
    self.attachmentLimit = deps.attachmentLimit or self.attachmentLimit or DEFAULT_ATTACHMENT_LIMIT
    return self
end

function Repository:_compat()
    return self.compat or Mail.Compat
end

function Repository:Snapshot()
    local compat = self:_compat()
    if type(compat) ~= "table" or type(compat.GetInboxCounts) ~= "function" then
        return nil, errorValue("MISSING_DEPENDENCY", "InboxRepository 缺少 MailCompat")
    end

    local current, totalOrError = compat:GetInboxCounts()
    if current == nil then
        local compatError = type(totalOrError) == "table" and totalOrError or nil
        return nil, compatError or errorValue("API_REJECTED", "无法读取邮箱数量")
    end
    current = math.max(0, normalizedNumber(current, 0))
    local total = math.max(current, normalizedNumber(totalOrError, current))
    local records = {}
    local incompleteReasons = {}

    for mailIndex = 1, current do
        local rawHeader, headerError = compat:GetHeader(mailIndex)
        if not rawHeader then
            return nil, headerError or errorValue("HEADER_MISSING", "无法读取邮件头")
        end

        local header = normalizeHeader(rawHeader)
        local attachments = {}
        local hasPendingAttachment = false
        for attachmentIndex = 1, self.attachmentLimit do
            local rawAttachment, attachmentError = compat:GetAttachment(mailIndex, attachmentIndex)
            if rawAttachment then
                local link
                if type(compat.GetAttachmentLink) == "function" then
                    link = compat:GetAttachmentLink(mailIndex, attachmentIndex)
                end
                attachments[#attachments + 1] = normalizeAttachment(
                    rawAttachment, link, mailIndex, attachmentIndex)
            elseif attachmentError then
                if attachmentError.code == "ITEM_DATA_PENDING" then
                    hasPendingAttachment = true
                    attachments[#attachments + 1] = normalizeAttachment({
                        dataPending = true,
                        count = 1,
                    }, nil, mailIndex, attachmentIndex)
                else
                    return nil, attachmentError
                end
            end
        end

        local attachmentsComplete = not hasPendingAttachment
            and #attachments >= header.itemCount
        if not attachmentsComplete then
            incompleteReasons[#incompleteReasons + 1] = {
                mailIndex = mailIndex,
                expectedAttachments = header.itemCount,
                resolvedAttachments = #attachments,
                itemDataPending = hasPendingAttachment,
            }
        end

        local capabilities = shallowCopy(header.rawCapabilities)
        capabilities.isCOD = capabilities.isCOD == true or header.cod > 0
        capabilities.isGM = capabilities.isGM == true or header.isGM
        capabilities.canTakeMoney = capabilities.canTakeMoney == true or header.money > 0
        capabilities.canTakeItems = not capabilities.isCOD
            and (capabilities.canTakeItems == true or #attachments > 0)
        capabilities.canReturn = header.canReturn
        capabilities.canDelete = capabilities.canDelete == true or header.canDelete

        local invoice
        if type(compat.GetInvoice) == "function" then
            invoice = compat:GetInvoice(mailIndex)
        end

        records[#records + 1] = {
            fingerprint = Repository.MakeFingerprint(header),
            index = mailIndex,
            packageIcon = header.packageIcon,
            stationery = header.stationery,
            sender = header.sender,
            subject = header.subject,
            money = header.money,
            cod = header.cod,
            daysLeft = header.daysLeft,
            itemCount = header.itemCount,
            wasRead = header.wasRead,
            wasReturned = header.wasReturned,
            textCreated = header.textCreated,
            canReply = header.canReply,
            capabilities = capabilities,
            attachments = attachments,
            attachmentsComplete = attachmentsComplete,
            invoice = invoice,
        }
    end

    local ambiguousFingerprints = assignDuplicateOrdinals(records, self.previousSnapshot)
    local snapshot = {
        generation = self.generation + 1,
        current = current,
        total = total,
        mails = records,
        mailsByKey = {},
        sourcesByKey = {},
        ambiguousFingerprints = ambiguousFingerprints,
        complete = #incompleteReasons == 0,
        incomplete = #incompleteReasons > 0,
        loading = #incompleteReasons > 0,
        incompleteReasons = incompleteReasons,
        incompleteMailKeys = {},
    }

    for recordIndex = 1, #records do
        local record = records[recordIndex]
        local recordLookupKey = mailLookupKey(record.key)
        snapshot.mailsByKey[recordLookupKey] = record
        if not record.attachmentsComplete then
            snapshot.incompleteMailKeys[recordLookupKey] = true
        end
        local occurrenceBySeed = {}

        for attachmentIndex = 1, #record.attachments do
            local attachment = record.attachments[attachmentIndex]
            local occurrence = (occurrenceBySeed[attachment.identitySeed] or 0) + 1
            occurrenceBySeed[attachment.identitySeed] = occurrence
            local sourceKey = Repository.MakeSourceKey(
                record.key, "item", attachment.identitySeed, occurrence)
            attachment.sourceKey = sourceKey
            attachment.mailKey = record.key
            attachment.kind = "item"
            attachment.amount = attachment.count
            attachment.daysLeft = record.daysLeft
            attachment.sender = record.sender
            attachment.subject = record.subject
            attachment.cod = record.cod
            attachment.isCOD = record.capabilities.isCOD == true
            attachment.canTakeItems = record.capabilities.canTakeItems == true
            attachment.canDelete = record.capabilities.canDelete
            attachment.canReturn = record.capabilities.canReturn
            attachment.wasReturned = record.wasReturned
            attachment.canReply = record.canReply
            attachment.invoice = record.invoice
            if not attachment.itemKey then
                attachment.itemKey = "pending:" .. sourceKey
            end
            snapshot.sourcesByKey[sourceKey] = attachment
        end

        if record.money > 0 then
            local moneySeed = encodeSequence({ record.money, record.sender, record.subject })
            local sourceKey = Repository.MakeSourceKey(record.key, "money", moneySeed, 1)
            record.moneySource = {
                kind = "money",
                mailKey = record.key,
                sourceKey = sourceKey,
                mailIndex = record.index,
                attachmentIndex = nil,
                itemKey = nil,
                amount = record.money,
                daysLeft = record.daysLeft,
                sender = record.sender,
                subject = record.subject,
                cod = record.cod,
                isCOD = record.capabilities.isCOD == true,
                canDelete = record.capabilities.canDelete,
                canReturn = record.capabilities.canReturn,
                wasReturned = record.wasReturned,
                canReply = record.canReply,
                invoice = record.invoice,
            }
            snapshot.sourcesByKey[sourceKey] = record.moneySource
        end
    end

    self.generation = snapshot.generation
    self.previousSnapshot = snapshot
    return snapshot
end

function Repository:ResolveMail(key, snapshot)
    if type(key) ~= "table" or type(key.fingerprint) ~= "string"
        or type(key.duplicateOrdinal) ~= "number" then
        return nil, errorValue("INVALID_MAIL_KEY", "MailKey 结构无效")
    end

    snapshot = snapshot or self.previousSnapshot
    if not snapshot then
        local snapshotError
        snapshot, snapshotError = self:Snapshot()
        if not snapshot then return nil, snapshotError end
    end
    if snapshot.ambiguousFingerprints[key.fingerprint] then
        return nil, errorValue("MAIL_AMBIGUOUS", "重复邮件变化后无法安全定位")
    end

    local record = snapshot.mailsByKey[mailLookupKey(key)]
    if not record then
        return nil, errorValue("MAIL_MOVED", "邮件已移动或不存在")
    end
    return record
end

function Repository:ResolveSource(sourceKey, snapshot)
    if type(sourceKey) ~= "string" or sourceKey == "" then
        return nil, errorValue("INVALID_SOURCE_KEY", "SourceKey 结构无效", false, sourceKey)
    end

    snapshot = snapshot or self.previousSnapshot
    if not snapshot then
        local snapshotError
        snapshot, snapshotError = self:Snapshot()
        if not snapshot then return nil, snapshotError end
    end

    local source = snapshot.sourcesByKey[sourceKey]
    if not source then
        if snapshot.incomplete == true or snapshot.complete == false then
            return nil, errorValue("SNAPSHOT_INCOMPLETE",
                "邮件附件快照尚未完整，无法确认来源是否已领取", true, sourceKey,
                snapshot.incompleteReasons)
        end
        return nil, errorValue("SOURCE_MISSING", "邮件来源已不存在", false, sourceKey)
    end
    if snapshot.ambiguousFingerprints[source.mailKey.fingerprint] then
        return nil, errorValue("MAIL_AMBIGUOUS", "重复邮件变化后无法安全定位", false, sourceKey)
    end
    return source
end

Repository.compat = nil
Repository.attachmentLimit = DEFAULT_ATTACHMENT_LIMIT
Repository.generation = 0
Repository.previousSnapshot = nil

Mail.InboxRepository = Repository

return Repository
