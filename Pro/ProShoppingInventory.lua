local addonName, ns = ...

ns.EasyAuctionPro = ns.EasyAuctionPro or {}
local Pro = ns.EasyAuctionPro

local SCHEMA_VERSION = 1
local CHANGE_EVENT = "SHOPPING_INVENTORY_CHANGED_V1"
local SESSION_EVENT = "SHOPPING_SESSION_CHANGED_V1"
local MAX_CHARACTERS = 100
local MAX_ITEMS = 4000
local MAX_NAME = 255
local MAX_TOKEN = 255
local MAX_DIAGNOSTICS = 64
local MAX_COUNT = 2147483647
local MAX_INTEGER = 9007199254740991

local state = { ready = false, db = nil, snapshots = nil, characterKey = nil, partition = nil,
    mutating = false, notifying = false, session = nil, diagnostics = {} }

local function IsBusy()
    return state.mutating or state.notifying or Pro.IsDomainTransactionActive()
end

local function CurrentFaction()
    if type(_G.UnitFactionGroup) ~= "function" then return nil end
    local first, second = _G.UnitFactionGroup("player")
    local faction = second or first
    if type(faction) == "string" and faction ~= "" and #faction <= MAX_NAME then return faction end
end

local function Copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}; seen[value] = out
    for key, child in pairs(value) do out[Copy(key, seen)] = Copy(child, seen) end
    return out
end

local function DeepEqual(left, right, seen)
    if left == right then return true end
    if type(left) ~= "table" or type(right) ~= "table" then return false end
    seen = seen or {}
    seen[left] = seen[left] or {}
    if seen[left][right] then return true end
    seen[left][right] = true
    for key, value in pairs(left) do
        if not DeepEqual(value, right[key], seen) then return false end
    end
    for key in pairs(right) do
        if left[key] == nil then return false end
    end
    return true
end

local function Error(code, message, extra)
    local out = { ok = false, code = code, message = message }
    for key, value in pairs(extra or {}) do out[key] = value end
    return out
end

local function ClearReady()
    state.ready, state.db, state.snapshots, state.characterKey, state.partition = false, nil, nil, nil, nil
end

local function FiniteInteger(value, minimum, maximum)
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
        and value == math.floor(value) and value >= minimum and value <= (maximum or MAX_INTEGER)
end

local function ItemID(value)
    local number = type(value) == "number" and value or tonumber(value)
    if FiniteInteger(number, 1) then return number end
end

local function Now(value)
    local number = tonumber(value)
    if FiniteInteger(number, 0) then return number end
end

local function CharacterInfo(options)
    options = type(options) == "table" and options or {}
    if options.lastScanError ~= nil and (type(options.lastScanError) ~= "string" or #options.lastScanError > MAX_NAME) then
        return nil, Error("INVALID_OPTIONS", "Scan error is malformed")
    end
    if options.realm ~= nil and (type(options.realm) ~= "string" or options.realm == "" or #options.realm > MAX_NAME) then
        return nil, Error("INVALID_OPTIONS", "Character realm is invalid")
    end
    if options.faction ~= nil and (type(options.faction) ~= "string" or options.faction == "" or #options.faction > MAX_NAME) then
        return nil, Error("INVALID_OPTIONS", "Character faction is invalid")
    end
    local runtimeRealm = type(_G.GetRealmName) == "function" and _G.GetRealmName() or nil
    local runtimeFaction = CurrentFaction()
    local realm = runtimeRealm or options.realm
    local faction = runtimeFaction or options.faction
    if options.realm and runtimeRealm and options.realm ~= runtimeRealm then
        return nil, Error("FOREIGN_PARTITION", "Character realm does not match current partition")
    end
    if options.faction and runtimeFaction and options.faction ~= runtimeFaction then
        return nil, Error("FOREIGN_PARTITION", "Character faction does not match current partition")
    end
    local guid = options.guid or (type(_G.UnitGUID) == "function" and _G.UnitGUID("player"))
    local name = options.name
    if not name and type(_G.UnitName) == "function" then name = _G.UnitName("player") end
    if guid ~= nil and (type(guid) ~= "string" or guid == "" or #guid > MAX_NAME) then
        return nil, Error("INVALID_OPTIONS", "Character GUID is invalid")
    end
    if name ~= nil and (type(name) ~= "string" or name == "" or #name > MAX_NAME) then
        return nil, Error("INVALID_OPTIONS", "Character name is invalid")
    end
    if type(realm) ~= "string" or realm == "" or #realm > MAX_NAME then
        return nil, Error("NOT_READY", "Realm identity is unavailable")
    end
    if type(faction) ~= "string" or faction == "" or #faction > MAX_NAME then faction = "Neutral" end
    if not guid and not name then return nil, Error("NOT_READY", "Character identity is unavailable") end
    local key = guid or ((realm or "?") .. ":" .. (name or "?"))
    return { key = key, guid = guid, name = name or key, realm = realm, faction = faction }
end

local function PartitionKey()
    local db = Pro.GetDB()
    if not db then return nil end
    local realm = type(_G.GetRealmName) == "function" and _G.GetRealmName() or db.realmKey
    local faction
    faction = CurrentFaction()
    return (realm or db.realmKey or "?") .. "-" .. (faction or "Neutral")
end

local function ResolveDB()
    local partition = PartitionKey()
    local db2 = _G.EasyAuctionDB2
    if type(db2) == "table" and partition and type(db2[partition]) == "table" then
        _G.EasyAuctionDB = db2[partition]
        return db2[partition]
    end
    return Pro.GetDB()
end

local function CountKeys(value)
    local count = 0; for _ in pairs(value or {}) do count = count + 1 end; return count
end

local function NormalizeCounts(input)
    if type(input) ~= "table" then return nil, Error("INVALID_COUNTS", "Counts must be a table") end
    if CountKeys(input) > MAX_ITEMS then return nil, Error("LIMIT_EXCEEDED", "Item count limit exceeded") end
    local out = {}
    for key, value in pairs(input) do
        local id, count = ItemID(key), tonumber(value)
        if not id or not FiniteInteger(count, 0, MAX_COUNT) then
            return nil, Error("INVALID_COUNTS", "Counts contain an invalid item or quantity")
        end
        if count > 0 then out[id] = count end
    end
    return out
end

local function StrictCounts(input)
    if type(input) ~= "table" then return nil, Error("STORAGE_INVALID", "Counts must be a table") end
    if CountKeys(input) > MAX_ITEMS then return nil, Error("STORAGE_LIMIT_EXCEEDED", "Item count limit exceeded") end
    local out = {}
    for key, value in pairs(input) do
        if type(key) ~= "number" or not FiniteInteger(key, 1) or not FiniteInteger(value, 0, MAX_COUNT) then
            return nil, Error("STORAGE_INVALID", "Counts contain a non-canonical item or quantity")
        end
        if value > 0 then out[key] = value end
    end
    return out
end

local function ValidText(value, allowNil)
    return (allowNil and value == nil) or (type(value) == "string" and value ~= "" and #value <= MAX_NAME)
end

local function ValidateCharacterBase(key, character, expectedRealm, expectedFaction)
    if type(key) ~= "string" or type(character) ~= "table" or (character.characterKey ~= nil and character.characterKey ~= key) then
        return nil, Error("STORAGE_INVALID", "Character identity is malformed")
    end
    if not ValidText(character.guid, true) or not ValidText(character.name, false)
            or not ValidText(character.realm, false) or not ValidText(character.faction, false)
            or not Now(character.lastSeenAt) then
        return nil, Error("STORAGE_INVALID", "Character metadata is invalid")
    end
    if (expectedRealm and character.realm ~= expectedRealm) or (expectedFaction and character.faction ~= expectedFaction) then
        return nil, Error("FOREIGN_PARTITION", "Character snapshot belongs to another partition")
    end
    return {
        characterKey = key,
        guid = character.guid,
        name = character.name,
        realm = character.realm,
        faction = character.faction,
        lastSeenAt = Now(character.lastSeenAt),
    }
end

local function ValidateStorage(storage)
    if type(storage) ~= "table" or type(storage.known) ~= "boolean" then return nil, Error("STORAGE_INVALID", "Storage snapshot is malformed") end
    local observed = Now(storage.observedAt)
    if storage.lastScanError ~= nil and (type(storage.lastScanError) ~= "string" or #storage.lastScanError > MAX_NAME) then
        return nil, Error("STORAGE_INVALID", "Scan error is malformed")
    end
    if storage.known then
        if not observed or type(storage.counts) ~= "table" then return nil, Error("STORAGE_INVALID", "Known snapshot is malformed") end
        local counts, failure = StrictCounts(storage.counts); if not counts then return nil, failure end
        return { known = true, observedAt = observed, counts = counts, lastScanError = storage.lastScanError }
    end
    if storage.counts ~= nil then return nil, Error("STORAGE_INVALID", "Unknown storage must not contain counts") end
    if storage.observedAt ~= nil and not observed then return nil, Error("STORAGE_INVALID", "Observed timestamp is invalid") end
    return { known = false, observedAt = observed, counts = nil, lastScanError = storage.lastScanError }
end

local function ValidateStorageForItem(storage, itemID)
    if type(storage) ~= "table" or type(storage.known) ~= "boolean" then return nil, Error("STORAGE_INVALID", "Storage snapshot is malformed") end
    local observed = Now(storage.observedAt)
    if storage.lastScanError ~= nil and (type(storage.lastScanError) ~= "string" or #storage.lastScanError > MAX_NAME) then
        return nil, Error("STORAGE_INVALID", "Scan error is malformed")
    end
    if storage.known then
        if not observed or type(storage.counts) ~= "table" then return nil, Error("STORAGE_INVALID", "Known snapshot is malformed") end
        local count = storage.counts[itemID]
        if count ~= nil and not FiniteInteger(count, 0, MAX_COUNT) then
            return nil, Error("STORAGE_INVALID", "Counts contain a non-canonical item or quantity")
        end
        return { known = true, observedAt = observed, count = count or 0 }
    end
    if storage.counts ~= nil then return nil, Error("STORAGE_INVALID", "Unknown storage must not contain counts") end
    if storage.observedAt ~= nil and not observed then return nil, Error("STORAGE_INVALID", "Observed timestamp is invalid") end
    return { known = false, observedAt = observed, count = 0 }
end

local function ValidateSchema(value, expectedRealm, expectedFaction)
    if type(value) ~= "table" then return nil, Error("STORAGE_INVALID", "Inventory storage must be a table") end
    if value.schemaVersion ~= SCHEMA_VERSION then return nil, Error("UNSUPPORTED_SCHEMA", "Inventory schema is unsupported") end
    if type(value.characters) ~= "table" or CountKeys(value.characters) > MAX_CHARACTERS then return nil, Error("STORAGE_INVALID", "Character map is malformed") end
    local out = { schemaVersion = SCHEMA_VERSION, characters = {} }
    for key, character in pairs(value.characters) do
        local base, baseFailure = ValidateCharacterBase(key, character, expectedRealm, expectedFaction)
        if not base then return nil, baseFailure end
        local bags, bagsFailure = ValidateStorage(character.bags)
        if not bags then return nil, bagsFailure end
        local bank, bankFailure = ValidateStorage(character.bank)
        if not bank then return nil, bankFailure end
        base.bags, base.bank = bags, bank
        out.characters[key] = base
    end
    return out
end

local function EnsureReady()
    if not state.ready then return nil, Error("NOT_READY", "Shopping inventory is not initialized") end
    local db = Pro.GetDB()
    if db ~= state.db or PartitionKey() ~= state.partition then return nil, Error("NOT_READY", "Inventory is not initialized for this realm") end
    if type(db.Pro) ~= "table" or db.Pro.inventorySnapshots ~= state.snapshots
            or type(state.snapshots) ~= "table" or type(state.snapshots.characters) ~= "table"
            or type(state.snapshots.characters[state.characterKey]) ~= "table" then
        ClearReady()
        return nil, Error("NOT_READY", "Inventory snapshot cache is invalid")
    end
    return db
end

local function Emit(event, payload)
    local result = Pro.Emit(event, payload)
    return result and result.ok ~= false
end

function Pro.GetShoppingInventoryStatus()
    return { ready = state.ready, partition = state.partition, characterKey = state.characterKey,
        diagnostics = Copy(state.diagnostics) }
end

function Pro.InitializeShoppingInventory(options)
    if IsBusy() then return Error("BUSY", "Inventory is busy") end
    local db = ResolveDB(); if not db then ClearReady(); return Error("NOT_READY", "Realm database is not ready") end
    local info, identityFailure = CharacterInfo(options); if not info then ClearReady(); return identityFailure end
    local originalProValue = db.Pro
    local originalPro = type(db.Pro) == "table" and db.Pro or {}
    local stored = originalPro.inventorySnapshots
    local candidate
    if stored == nil then
        candidate = { schemaVersion = SCHEMA_VERSION, characters = {} }
    else
        local storageFailure
        candidate, storageFailure = ValidateSchema(stored, info.realm, info.faction)
        if not candidate then ClearReady(); return storageFailure end
    end
    local character = candidate.characters[info.key]
    local created = false
    if not character then
        if CountKeys(candidate.characters) >= MAX_CHARACTERS then
            ClearReady()
            return Error("STORAGE_LIMIT_EXCEEDED", "Character limit exceeded")
        end
        created = true
        character = { characterKey = info.key, guid = info.guid, name = info.name, realm = info.realm, faction = info.faction,
            lastSeenAt = Now(options and options.now) or 0, bags = { known = false, counts = nil }, bank = { known = false, counts = nil } }
        candidate.characters[info.key] = character
    end
    if character.guid ~= info.guid or character.name ~= info.name or character.realm ~= info.realm or character.faction ~= info.faction then
        character.guid, character.name, character.realm, character.faction = info.guid, info.name, info.realm, info.faction
        local now = Now(options and options.now); if now ~= nil then character.lastSeenAt = now end
    end
    local changed = stored == nil or created or not DeepEqual(stored, candidate)
    local oldPro = originalPro
    local oldReady, oldDB, oldSnapshots, oldCharacterKey, oldPartition = state.ready, state.db, state.snapshots, state.characterKey, state.partition
    state.mutating, state.notifying = true, true
    local tx = Pro.RunDomainTransaction(function()
        if changed then db.Pro.inventorySnapshots = candidate end
        state.ready, state.db, state.snapshots, state.characterKey, state.partition = true, db, db.Pro.inventorySnapshots, info.key, PartitionKey()
        state.mutating = false
        if changed then
            if Emit(CHANGE_EVENT, { schemaVersion = SCHEMA_VERSION, characterKey = info.key }) then return { ok = true } end
            return Error("EMIT_FAILED", "Inventory notification failed")
        end
        return { ok = true }
    end)
    state.mutating, state.notifying = false, false
    if not tx.ok then
        if changed then db.Pro.inventorySnapshots = originalProValue.inventorySnapshots end
        state.ready, state.db, state.snapshots, state.characterKey, state.partition = oldReady, oldDB, oldSnapshots, oldCharacterKey, oldPartition
        return tx
    end
    return { ok = true, changed = changed, cached = false }
end

function Pro.UpdateInventorySnapshot(storage, counts, observedAt, options)
    if IsBusy() then return Error("BUSY", "Inventory is busy") end
    local db, failure = EnsureReady(); if not db then return failure end
    if storage ~= "bags" and storage ~= "bank" then return Error("INVALID_STORAGE", "Storage must be bags or bank") end
    observedAt = Now(observedAt); if not observedAt then return Error("INVALID_TIMESTAMP", "Timestamp is invalid") end
    options = type(options) == "table" and options or {}
    if options.lastScanError ~= nil and (type(options.lastScanError) ~= "string" or #options.lastScanError > MAX_NAME) then
        return Error("INVALID_OPTIONS", "Scan error is malformed")
    end
    local original = db.Pro.inventorySnapshots
    local candidate, storedFailure = ValidateSchema(original,
        type(_G.GetRealmName) == "function" and _G.GetRealmName() or nil, CurrentFaction())
    if storedFailure then return storedFailure end
    local character = candidate.characters[state.characterKey]
    local replacement
    if options.lastScanError ~= nil and counts == nil and options.known ~= false then
        replacement = Copy(character[storage])
        replacement.lastScanError = options.lastScanError
    elseif options.known == false or counts == nil then
        replacement = { known = false, observedAt = observedAt, counts = nil, lastScanError = options.lastScanError }
    else
        local normalized, invalid = NormalizeCounts(counts); if not normalized then return invalid end
        replacement = { known = true, observedAt = observedAt, counts = normalized, lastScanError = options.lastScanError }
    end
    character[storage] = replacement
    if not (options.lastScanError ~= nil and counts == nil and options.known ~= false) then
        character.lastSeenAt = observedAt
    end
    local oldSnapshot = db.Pro.inventorySnapshots
    local oldStateSnapshot = state.snapshots
    state.mutating, state.notifying = true, true
    local tx = Pro.RunDomainTransaction(function()
        db.Pro.inventorySnapshots = candidate
        state.snapshots = candidate
        state.mutating = false
        if Emit(CHANGE_EVENT, { schemaVersion = SCHEMA_VERSION, characterKey = state.characterKey, storage = storage, observedAt = observedAt }) then
            return { ok = true }
        end
        return Error("EMIT_FAILED", "Inventory notification failed")
    end)
    state.mutating, state.notifying = false, false
    if not tx.ok then
        db.Pro.inventorySnapshots = oldSnapshot
        state.snapshots = oldStateSnapshot
        return tx
    end
    return { ok = true, snapshot = Copy(replacement) }
end

function Pro.GetCharacterInventorySnapshot(characterKey, storage, now, maxAge)
    local _, failure = EnsureReady(); if failure then return failure end
    if type(characterKey) ~= "string" or characterKey == "" then return Error("INVALID_CHARACTER", "Character key is invalid") end
    if storage ~= "bags" and storage ~= "bank" then return Error("INVALID_STORAGE", "Storage must be bags or bank") end
    local character = state.snapshots.characters[characterKey]
    if not character then return Error("UNKNOWN_CHARACTER", "Character is not known") end
    local _, baseFailure = ValidateCharacterBase(characterKey, character,
        type(_G.GetRealmName) == "function" and _G.GetRealmName() or nil, CurrentFaction())
    if baseFailure then return baseFailure end
    local snapshot, storageFailure = ValidateStorage(character[storage])
    if not snapshot then return storageFailure end
    local age = tonumber(maxAge); local current = Now(now)
    local stale = snapshot.known and age and current and current - snapshot.observedAt > age
    local out = Copy(snapshot); out.ok = true; out.stale = stale == true
    if out.stale then out.known, out.counts = false, nil end
    out.characterKey = characterKey
    return out
end

function Pro.GetInventorySnapshot(storage, now, maxAge)
    return Pro.GetCharacterInventorySnapshot(state.characterKey, storage, now, maxAge)
end

function Pro.GetAggregatedInventory(itemID, now, maxAge)
    local _, failure = EnsureReady(); if failure then return failure end
    itemID = ItemID(itemID); if not itemID then return Error("INVALID_ITEM", "Item ID is invalid") end
    local total, complete, unknown, oldest = 0, true, {}, nil
    local expectedRealm = type(_G.GetRealmName) == "function" and _G.GetRealmName() or nil
    local expectedFaction = CurrentFaction()
    for key, character in pairs(state.snapshots.characters) do
        local base, baseFailure = ValidateCharacterBase(key, character, expectedRealm, expectedFaction)
        if not base then return baseFailure end
        if character.realm ~= (type(_G.GetRealmName) == "function" and _G.GetRealmName() or character.realm)
                or character.faction ~= (CurrentFaction() or character.faction) then
            -- Foreign records are excluded from this realm/faction aggregate.
            character = nil
        end
        if character then
        local characterUnknown = false
        for _, storageName in ipairs({ "bags", "bank" }) do
            local storage, storageFailure = ValidateStorageForItem(character[storageName], itemID)
            if not storage then return storageFailure end
            local stale = storage.known and tonumber(maxAge) and Now(now) and Now(now) - storage.observedAt > tonumber(maxAge)
            if storage.known and not stale then
                total = total + storage.count
                if not oldest or storage.observedAt < oldest then oldest = storage.observedAt end
            else characterUnknown = true end
        end
        if characterUnknown then unknown[#unknown + 1] = key; complete = false end
        end
    end
    return { ok = true, count = total, complete = complete, unknownCharacters = #unknown, unknownCharacterKeys = unknown, oldestObservedAt = oldest }
end

local function SessionChanged()
    if Emit(SESSION_EVENT, { sessionID = state.session and state.session.sessionID or nil, active = state.session ~= nil }) then
        return { ok = true }
    end
    return Error("EMIT_FAILED", "Shopping session notification failed")
end

function Pro.StartShoppingSession(sessionID, relevantItemIDs, bagCounts, openedAt)
    if IsBusy() then return Error("BUSY", "Shopping session is busy") end
    if type(sessionID) ~= "string" or sessionID == "" or #sessionID > MAX_TOKEN then return Error("INVALID_SESSION", "Session ID is invalid") end
    local opened = Now(openedAt); if not opened then return Error("INVALID_TIMESTAMP", "Timestamp is invalid") end
    local counts, invalid = NormalizeCounts(bagCounts or {}); if not counts then return invalid end
    local relevant, baseline = {}, {}
    if type(relevantItemIDs) ~= "table" then return Error("INVALID_ITEMS", "Relevant items are invalid") end
    for key, value in pairs(relevantItemIDs) do
        local id = ItemID(value or key); if not id then return Error("INVALID_ITEM", "Relevant item is invalid") end
        relevant[id] = true; baseline[id] = counts[id] or 0
    end
    local previous = state.session
    state.mutating, state.notifying = true, true
    local tx = Pro.RunDomainTransaction(function()
        state.session = { sessionID = sessionID, epoch = (previous and previous.epoch or 0) + 1, openedAt = opened,
            relevant = relevant, baseline = baseline, purchases = {}, dedupe = {}, diagnostics = {} }
        state.mutating = false
        return SessionChanged()
    end)
    state.mutating, state.notifying = false, false
    if not tx.ok then state.session = previous; return tx end
    return { ok = true, session = Copy(state.session) }
end

function Pro.EnsureShoppingSessionBaseline(itemID, currentBagCount)
    if IsBusy() then return Error("BUSY", "Shopping session is busy") end
    if not state.session then return Error("SESSION_INACTIVE", "Shopping session is inactive") end
    itemID = ItemID(itemID); local count = tonumber(currentBagCount)
    if not itemID or not FiniteInteger(count, 0, MAX_COUNT) then return Error("INVALID_COUNT", "Bag count is invalid") end
    if state.session.baseline[itemID] ~= nil then return { ok = true, baseline = state.session.baseline[itemID], captured = false } end
    state.mutating, state.notifying = true, true
    local tx = Pro.RunDomainTransaction(function()
        state.session.relevant[itemID], state.session.baseline[itemID] = true, count
        state.mutating = false
        return SessionChanged()
    end)
    state.mutating, state.notifying = false, false
    if not tx.ok then state.session.relevant[itemID], state.session.baseline[itemID] = nil, nil; return tx end
    return { ok = true, baseline = count, captured = true }
end

function Pro.ApplyConfirmedShoppingPurchase(token, itemID, count)
    if IsBusy() then return Error("BUSY", "Shopping session is busy") end
    if not state.session then return Error("SESSION_INACTIVE", "Shopping session is inactive") end
    if type(token) ~= "string" or token == "" or #token > MAX_TOKEN then return Error("INVALID_TOKEN", "Purchase token is invalid") end
    itemID = ItemID(itemID); count = tonumber(count)
    if not itemID or not FiniteInteger(count, 1, MAX_COUNT) then return Error("INVALID_PURCHASE", "Purchase is invalid") end
    if state.session.dedupe[token] then return { ok = true, duplicate = true, delta = 0, purchases = state.session.purchases[itemID] or 0 } end
    if CountKeys(state.session.dedupe) >= MAX_ITEMS then return Error("LIMIT_EXCEEDED", "Purchase token limit exceeded") end
    local prior = state.session.purchases[itemID] or 0; if prior > MAX_COUNT - count then return Error("LIMIT_EXCEEDED", "Purchase total exceeds limit") end
    state.mutating, state.notifying = true, true
    local tx = Pro.RunDomainTransaction(function()
        state.session.dedupe[token] = true; state.session.purchases[itemID] = prior + count
        state.mutating = false
        return SessionChanged()
    end)
    state.mutating, state.notifying = false, false
    if not tx.ok then state.session.dedupe[token] = nil; state.session.purchases[itemID] = prior > 0 and prior or nil; return tx end
    return { ok = true, duplicate = false, delta = count, purchases = prior + count }
end

function Pro.ReconcileShoppingPurchaseTotal(source, itemID, totalCount)
    if IsBusy() then return Error("BUSY", "Shopping session is busy") end
    if not state.session then return Error("SESSION_INACTIVE", "Shopping session is inactive") end
    source = tostring(source or "")
    if source == "" or #source > MAX_TOKEN then return Error("INVALID_TOKEN", "Purchase source is invalid") end
    itemID = ItemID(itemID); totalCount = tonumber(totalCount)
    if not itemID or not FiniteInteger(totalCount, 0, MAX_COUNT) then return Error("INVALID_PURCHASE", "Purchase total is invalid") end
    local prior = state.session.purchases[itemID] or 0
    if totalCount <= prior then
        return { ok = true, duplicate = true, delta = 0, purchases = prior }
    end
    local delta = totalCount - prior
    state.mutating, state.notifying = true, true
    local tx = Pro.RunDomainTransaction(function()
        state.session.purchases[itemID] = totalCount
        state.mutating = false
        return SessionChanged()
    end)
    state.mutating, state.notifying = false, false
    if not tx.ok then state.session.purchases[itemID] = prior > 0 and prior or nil; return tx end
    return { ok = true, duplicate = false, delta = delta, purchases = totalCount }
end

function Pro.EndShoppingSession(reason)
    if IsBusy() then return Error("BUSY", "Shopping session is busy") end
    if not state.session then return { ok = true, inactive = true } end
    local previous = state.session
    state.mutating, state.notifying = true, true
    local tx = Pro.RunDomainTransaction(function()
        state.session = nil
        state.mutating = false
        return SessionChanged()
    end)
    state.mutating, state.notifying = false, false
    if not tx.ok then state.session = previous; return tx end
    return { ok = true, reason = reason }
end

function Pro.GetShoppingSession()
    if not state.session then return Error("SESSION_INACTIVE", "Shopping session is inactive") end
    return { ok = true, sessionID = state.session.sessionID, epoch = state.session.epoch, openedAt = state.session.openedAt,
        relevant = Copy(state.session.relevant), baseline = Copy(state.session.baseline), purchases = Copy(state.session.purchases) }
end

function Pro.GetShoppingSessionItem(itemID)
    if not state.session then return Error("SESSION_INACTIVE", "Shopping session is inactive") end
    itemID = ItemID(itemID); if not itemID then return Error("INVALID_ITEM", "Item ID is invalid") end
    return { ok = true, itemID = itemID, baseline = state.session.baseline[itemID], purchases = state.session.purchases[itemID] or 0,
        progress = (state.session.baseline[itemID] or 0) + (state.session.purchases[itemID] or 0) }
end

function Pro.GetShoppingCompletion(itemID, plannedQuantity)
    local quantity = tonumber(plannedQuantity); if not FiniteInteger(quantity, 1, MAX_COUNT) then return Error("INVALID_QUANTITY", "Planned quantity is invalid") end
    itemID = ItemID(itemID); if not itemID then return Error("INVALID_ITEM", "Item ID is invalid") end
    if not state.session then
        return { ok = true, state = "unavailable", itemID = itemID, plannedQuantity = quantity, completed = false }
    end
    local item = Pro.GetShoppingSessionItem(itemID); if not item.ok then return item end
    return { ok = true, state = "active", itemID = item.itemID, baseline = item.baseline or 0, purchases = item.purchases, progress = item.progress, plannedQuantity = quantity, completed = item.progress >= quantity }
end

Pro.GetInventoryStatus = Pro.GetShoppingInventoryStatus
Pro.SetInventorySnapshot = Pro.UpdateInventorySnapshot
Pro.AggregateInventory = Pro.GetAggregatedInventory
