local addonName, ns = ...

ns.EasyAuctionPro = ns.EasyAuctionPro or {}
local Pro = ns.EasyAuctionPro

local SCHEMA_VERSION = 1
local CLEANUP_VERSION = 1
local CHANGE_EVENT = "SHOPPING_LISTS_CHANGED_V1"
local MAX_LISTS = 100
local MAX_ITEMS_PER_LIST = 2000
local MAX_QUANTITY = 2147483647
local MAX_EXACT_INTEGER = 9007199254740991
local MAX_COUNTER_VALUE = MAX_EXACT_INTEGER - 1
local MAX_NAME_BYTES = 255
local MAX_IMPORT_BYTES = 524288

local state = {
    ready = false,
    notifying = 0,
    apiStatus = nil,
    db = nil,
    shopping = nil,
    nameIndex = {},
    itemIndex = {},
}

local function ResultError(code, message, extra)
    local result = { ok = false, code = code, message = message }
    for key, value in pairs(extra or {}) do
        result[key] = value
    end
    return result
end

local function DeepCopy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local copied = {}
    seen[value] = copied
    for key, child in pairs(value) do
        copied[DeepCopy(key, seen)] = DeepCopy(child, seen)
    end
    return copied
end

local function Trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function NameKey(value)
    return string.lower(Trim(value))
end

local function ValidateName(value)
    if type(value) ~= "string" then
        return nil, ResultError("INVALID_NAME", "Shopping list name must be a string", { field = "name" })
    end
    local name = Trim(value)
    if name == "" or #name > MAX_NAME_BYTES then
        return nil, ResultError("INVALID_NAME", "Shopping list name is empty or too long", { field = "name" })
    end
    return name
end

local function ValidateQuantity(value)
    local quantity = tonumber(value)
    if not quantity or quantity ~= math.floor(quantity) or quantity < 1 or quantity > MAX_QUANTITY then
        return nil, ResultError("INVALID_QUANTITY", "Planned quantity must be a positive bounded integer", {
            field = "plannedQuantity",
        })
    end
    return quantity
end

local function IsPositiveInteger(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
        and value >= 1 and value <= MAX_EXACT_INTEGER and value == math.floor(value)
end

local function CanonicalItemID(value)
    local itemID = tonumber(value)
    if IsPositiveInteger(itemID) then return itemID end
    return nil
end

local function ResolveItem(value)
    local itemID, itemName = Pro.ResolveItemIdentifier(value)
    itemID = tonumber(itemID)
    if not IsPositiveInteger(itemID) then
        return nil, nil, ResultError("ITEM_UNRESOLVED", "Item could not be resolved", { field = "item" })
    end
    return itemID, itemName or ("ID:" .. itemID)
end

local function NewSchema()
    return {
        schemaVersion = SCHEMA_VERSION,
        nextListID = 1,
        order = {},
        listsByID = {},
        changeToken = 0,
    }
end

local function BuildIndexes(shopping)
    local indexes = { names = {}, items = {} }
    for _, listID in ipairs(shopping.order or {}) do
        local list = shopping.listsByID[listID]
        if list then
            indexes.names[NameKey(list.name)] = listID
            for itemID in pairs(list.items or {}) do
                local IDs = indexes.items[itemID]
                if not IDs then
                    IDs = {}
                    indexes.items[itemID] = IDs
                end
                IDs[#IDs + 1] = listID
            end
        end
    end
    return indexes
end

local function InstallIndexes(db, shopping, indexes)
    state.db = db
    state.shopping = shopping
    state.nameIndex = indexes.names
    state.itemIndex = indexes.items
end

local function DeepEqual(left, right, seen)
    if type(left) ~= type(right) then return false end
    if type(left) ~= "table" then return left == right end
    seen = seen or {}
    if seen[left] == right then return true end
    seen[left] = right
    for key, value in pairs(left) do
        if not DeepEqual(value, right[key], seen) then return false end
    end
    for key in pairs(right) do
        if left[key] == nil then return false end
    end
    return true
end

local function CountKeys(value)
    local count = 0
    for _ in pairs(value or {}) do count = count + 1 end
    return count
end

local function ValidateArray(value)
    if type(value) ~= "table" then return nil end
    local count, maximum = 0, 0
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key ~= math.floor(key) then return nil end
        count = count + 1
        if key > maximum then maximum = key end
    end
    if maximum ~= count then return nil end
    return count
end

local function ParseListID(value)
    if type(value) ~= "string" then return nil end
    local numeric = tonumber(value:match("^L([1-9]%d*)$"))
    if IsPositiveInteger(numeric) then return numeric end
    return nil
end

local function StorageError(code, message, field)
    return ResultError(code, message, field and { field = field } or nil)
end

local function ValidateStoredShopping(shopping)
    if type(shopping) ~= "table" then
        return nil, StorageError("STORAGE_INVALID", "Shopping storage must be a table", "shopping")
    end
    if shopping.schemaVersion ~= SCHEMA_VERSION then
        return nil, StorageError("UNSUPPORTED_SCHEMA", "Shopping storage schema is unsupported", "schemaVersion")
    end
    if shopping.listIDByName ~= nil or shopping.listIDsByItem ~= nil then
        return nil, StorageError("STORAGE_INVALID", "Derived indexes must not be persisted", "indexes")
    end
    local orderCount = ValidateArray(shopping.order)
    if orderCount == nil or type(shopping.listsByID) ~= "table" then
        return nil, StorageError("STORAGE_INVALID", "Shopping list order or map is malformed", "order")
    end
    local mapCount = CountKeys(shopping.listsByID)
    if orderCount > MAX_LISTS or mapCount > MAX_LISTS then
        return nil, StorageError("STORAGE_LIMIT_EXCEEDED", "Shopping list storage exceeds its list limit", "listsByID")
    end
    if orderCount ~= mapCount then
        return nil, StorageError("STORAGE_INVALID", "Shopping list order and map disagree", "order")
    end
    if not IsPositiveInteger(shopping.nextListID) or shopping.nextListID > MAX_COUNTER_VALUE then
        return nil, StorageError("STORAGE_INVALID", "Next list ID is invalid", "nextListID")
    end
    local token = shopping.changeToken
    if type(token) ~= "number" or token ~= token or token == math.huge or token == -math.huge
            or token < 0 or token > MAX_COUNTER_VALUE or token ~= math.floor(token) then
        return nil, StorageError("STORAGE_INVALID", "Change token is invalid", "changeToken")
    end

    local names, present = {}, {}
    local maxListNumber = 0
    for _, listID in ipairs(shopping.order) do
        local listNumber = ParseListID(listID)
        local list = shopping.listsByID[listID]
        if not listNumber or present[listID] or type(list) ~= "table" or list.id ~= listID then
            return nil, StorageError("STORAGE_INVALID", "Shopping list identity is invalid", "listID")
        end
        present[listID] = true
        if listNumber > maxListNumber then maxListNumber = listNumber end
        local name = type(list.name) == "string" and ValidateName(list.name) or nil
        if not name or name ~= list.name or names[NameKey(name)] then
            return nil, StorageError("STORAGE_INVALID", "Shopping list name is invalid or duplicated", "name")
        end
        names[NameKey(name)] = listID
        if list.exportName ~= nil then
            local exportName = type(list.exportName) == "string" and ValidateName(list.exportName) or nil
            if not exportName or exportName ~= list.exportName then
                return nil, StorageError("STORAGE_INVALID", "Shopping list export name is invalid", "exportName")
            end
        end
        if type(list.items) ~= "table" then
            return nil, StorageError("STORAGE_INVALID", "Shopping list items are malformed", "items")
        end
        local itemCount = CountKeys(list.items)
        if itemCount > MAX_ITEMS_PER_LIST then
            return nil, StorageError("STORAGE_LIMIT_EXCEEDED", "Shopping list exceeds its item limit", "items")
        end
        for itemID, entry in pairs(list.items) do
            local quantity = type(entry) == "table" and type(entry.plannedQuantity) == "number"
                and ValidateQuantity(entry.plannedQuantity) or nil
            if type(itemID) ~= "number" or not IsPositiveInteger(itemID)
                    or type(entry) ~= "table" or entry.itemID ~= itemID or not quantity
                    or type(entry.itemName) ~= "string" or entry.itemName == "" then
                return nil, StorageError("STORAGE_INVALID", "Shopping list item is invalid", "items")
            end
        end
    end
    for listID in pairs(shopping.listsByID) do
        if not present[listID] then
            return nil, StorageError("STORAGE_INVALID", "Shopping list map contains an unordered entry", "listsByID")
        end
    end
    if shopping.nextListID <= maxListNumber then
        return nil, StorageError("STORAGE_INVALID", "Next list ID would reuse a persisted ID", "nextListID")
    end
    return BuildIndexes(shopping)
end

local function SetInitializationFailure(failure)
    state.ready = false
    state.db = nil
    state.shopping = nil
    state.nameIndex = {}
    state.itemIndex = {}
    Pro.SetReadiness("domain", false, { code = failure.code, message = failure.message })
    return failure
end

local function GetStorage()
    if not state.ready then
        return nil, nil, ResultError("NOT_READY", "Shopping lists are not initialized")
    end
    local db = Pro.GetDB()
    local shopping = db and db.Pro and db.Pro.shopping
    if state.db ~= db or state.shopping ~= shopping
            or type(shopping) ~= "table" or shopping.schemaVersion ~= SCHEMA_VERSION then
        return nil, nil, ResultError("NOT_READY", "Shopping lists are not initialized for this realm")
    end
    return db, shopping
end

local function FindList(shopping, listID)
    local list = shopping.listsByID[tostring(listID or "")]
    if not list then
        return nil, ResultError("LIST_NOT_FOUND", "Shopping list was not found", { listID = listID })
    end
    return list
end

local function UTF8Prefix(value, maxBytes)
    if #value <= maxBytes then return value end
    local characterStart = maxBytes
    while characterStart > 0 do
        local byte = value:byte(characterStart)
        if not byte or byte < 128 or byte >= 192 then break end
        characterStart = characterStart - 1
    end
    if characterStart == 0 then return "" end

    local lead = value:byte(characterStart)
    local width = 1
    if lead >= 240 and lead <= 247 then
        width = 4
    elseif lead >= 224 and lead <= 239 then
        width = 3
    elseif lead >= 192 and lead <= 223 then
        width = 2
    end
    if characterStart + width - 1 > maxBytes then
        maxBytes = characterStart - 1
    end
    return value:sub(1, maxBytes)
end

local function UniqueName(indexes, requested, excludedID)
    local name, failure = ValidateName(requested)
    if not name then return nil, failure end
    local owner = indexes.names[NameKey(name)]
    if not owner or owner == excludedID then return name end
    local suffix = 2
    while true do
        local ending = " (" .. suffix .. ")"
        local candidate = UTF8Prefix(name, MAX_NAME_BYTES - #ending) .. ending
        owner = indexes.names[NameKey(candidate)]
        if not owner or owner == excludedID then return candidate end
        suffix = suffix + 1
    end
end

local function Mutate(callback)
    if state.notifying > 0 or Pro.IsDomainTransactionActive() then
        return ResultError("BUSY", "Shopping list mutation is busy")
    end
    local db, original, failure = GetStorage()
    if not db then return failure end
    if original.changeToken >= MAX_COUNTER_VALUE then
        return ResultError("CHANGE_TOKEN_EXHAUSTED", "Shopping list change token is exhausted")
    end
    local working = DeepCopy(original)
    local oldIndexes = { names = state.nameIndex, items = state.itemIndex }
    local workingIndexes = BuildIndexes(working)
    local installed = false
    local transaction = Pro.RunDomainTransaction(function()
        local result = callback(working, workingIndexes)
        if type(result) == "table" and result.ok == false then return result end
        workingIndexes = BuildIndexes(working)
        working.changeToken = (tonumber(original.changeToken) or 0) + 1
        db.Pro.shopping = working
        InstallIndexes(db, working, workingIndexes)
        installed = true
        local emitted = Pro.Emit(CHANGE_EVENT, {
            changeToken = working.changeToken,
            schemaVersion = SCHEMA_VERSION,
        })
        if not emitted.ok then
            db.Pro.shopping = original
            InstallIndexes(db, original, oldIndexes)
            installed = false
            return emitted
        end
        return result or { ok = true }
    end)
    if not transaction.ok and installed and db.Pro.shopping == working then
        db.Pro.shopping = original
        InstallIndexes(db, original, oldIndexes)
    end
    return DeepCopy(transaction)
end

function Pro.InvalidateShoppingLists()
    if Pro.IsDomainTransactionActive() then
        return ResultError("BUSY", "Shopping list invalidation is busy")
    end
    state.ready = false
    state.db = nil
    state.shopping = nil
    state.nameIndex = {}
    state.itemIndex = {}
    Pro.SetReadiness("domain", false, { code = "INVALIDATED" })
    return { ok = true }
end

function Pro.InitializeShoppingLists(options)
    if Pro.IsDomainTransactionActive() then
        local busy = ResultError("BUSY", "Shopping list initialization is busy")
        if state.ready then return busy end
        return SetInitializationFailure(busy)
    end
    options = type(options) == "table" and options or {}
    local db = Pro.GetDB()
    if not db then return SetInitializationFailure(ResultError("NOT_READY", "Realm database is not ready")) end
    local currentShopping = type(db.Pro) == "table" and db.Pro.shopping or nil
    if not options.force and state.ready and state.db == db and state.shopping == currentShopping then
        return { ok = true, schemaVersion = SCHEMA_VERSION, changed = false, cached = true }
    end
    if db.Pro ~= nil and type(db.Pro) ~= "table" then
        return SetInitializationFailure(StorageError("STORAGE_INVALID", "Pro storage must be a table", "Pro"))
    end
    local originalPro = db.Pro or {}
    local candidatePro = DeepCopy(originalPro)
    local indexes, storageFailure
    if candidatePro.shopping == nil then
        candidatePro.shopping = NewSchema()
        indexes = BuildIndexes(candidatePro.shopping)
    else
        indexes, storageFailure = ValidateStoredShopping(candidatePro.shopping)
        if not indexes then return SetInitializationFailure(storageFailure) end
    end
    if (tonumber(candidatePro.shoppingCleanupVersion) or 0) < CLEANUP_VERSION then
        candidatePro.itemRestock = nil
        candidatePro.groupRestock = nil
        candidatePro.restockOps = nil
        candidatePro.sniper = nil
        candidatePro.shoppingCleanupVersion = CLEANUP_VERSION
    end
    local changed = not DeepEqual(originalPro, candidatePro)
    if changed then
        if candidatePro.shopping.changeToken >= MAX_COUNTER_VALUE then
            return SetInitializationFailure(ResultError(
                "CHANGE_TOKEN_EXHAUSTED", "Shopping list change token is exhausted"
            ))
        end
        candidatePro.shopping.changeToken = candidatePro.shopping.changeToken + 1
    end
    local installed = false
    local transaction = Pro.RunDomainTransaction(function()
        if changed then
            db.Pro = candidatePro
            installed = true
        end
        local committedShopping = changed and candidatePro.shopping or originalPro.shopping
        InstallIndexes(db, committedShopping, indexes)
        state.ready = true
        Pro.SetReadiness("domain", true, { schemaVersion = SCHEMA_VERSION })
        if changed then
            local emitted = Pro.Emit(CHANGE_EVENT, {
                changeToken = candidatePro.shopping.changeToken,
                schemaVersion = SCHEMA_VERSION,
            })
            if not emitted.ok then return emitted end
        end
        return { ok = true, schemaVersion = SCHEMA_VERSION, changed = changed, cached = false }
    end)
    if not transaction.ok then
        if installed and db.Pro == candidatePro then db.Pro = originalPro end
        return SetInitializationFailure(transaction)
    end
    return transaction
end

function Pro.GetShoppingLists()
    local _, shopping, failure = GetStorage()
    if not shopping then return failure end
    local lists = {}
    for _, listID in ipairs(shopping.order) do
        lists[#lists + 1] = DeepCopy(shopping.listsByID[listID])
    end
    return { ok = true, lists = lists, changeToken = shopping.changeToken }
end

function Pro.GetShoppingList(listID)
    local _, shopping, failure = GetStorage()
    if not shopping then return failure end
    local list, missing = FindList(shopping, listID)
    if not list then return missing end
    return { ok = true, list = DeepCopy(list), changeToken = shopping.changeToken }
end

function Pro.GetShoppingListIDByName(name)
    local _, shopping, failure = GetStorage()
    if not shopping then return failure end
    return { ok = true, listID = state.nameIndex[NameKey(name)] }
end

function Pro.GetShoppingListIDsForItem(item)
    local _, shopping, failure = GetStorage()
    if not shopping then return failure end
    local itemID, _, unresolved = ResolveItem(item)
    if not itemID then return unresolved end
    return { ok = true, listIDs = DeepCopy(state.itemIndex[itemID] or {}) }
end

local function CreateList(shopping, indexes, requestedName, unique)
    if #shopping.order >= MAX_LISTS then
        return ResultError("LIST_LIMIT", "Shopping list limit reached")
    end
    if shopping.nextListID >= MAX_COUNTER_VALUE then
        return ResultError("ID_EXHAUSTED", "Shopping list ID space is exhausted")
    end
    local name, failure = ValidateName(requestedName)
    if not name then return failure end
    local existing = indexes.names[NameKey(name)]
    if existing and not unique then
        return ResultError("NAME_EXISTS", "Shopping list name already exists", { field = "name" })
    end
    if existing then name = UniqueName(indexes, name) end
    local listID = "L" .. shopping.nextListID
    shopping.nextListID = shopping.nextListID + 1
    local list = { id = listID, name = name, items = {} }
    shopping.listsByID[listID] = list
    shopping.order[#shopping.order + 1] = listID
    indexes.names[NameKey(name)] = listID
    return { ok = true, list = list }
end

function Pro.CreateShoppingList(name)
    return Mutate(function(shopping, indexes)
        local result = CreateList(shopping, indexes, name, false)
        if not result.ok then return result end
        result.list = DeepCopy(result.list)
        return result
    end)
end

function Pro.RenameShoppingList(listID, requestedName)
    return Mutate(function(shopping, indexes)
        local list, failure = FindList(shopping, listID)
        if not list then return failure end
        local name, invalid = ValidateName(requestedName)
        if not name then return invalid end
        local owner = indexes.names[NameKey(name)]
        if owner and owner ~= list.id then
            return ResultError("NAME_EXISTS", "Shopping list name already exists", { field = "name" })
        end
        list.name = name
        list.exportName = nil
        return { ok = true, list = DeepCopy(list) }
    end)
end

function Pro.DeleteShoppingList(listID)
    return Mutate(function(shopping)
        local list, failure = FindList(shopping, listID)
        if not list then return failure end
        shopping.listsByID[list.id] = nil
        for index, orderedID in ipairs(shopping.order) do
            if orderedID == list.id then table.remove(shopping.order, index) break end
        end
        return { ok = true, listID = list.id }
    end)
end

local function SetItem(list, itemID, itemName, quantity, duplicateRule)
    local existing = list.items[itemID]
    if existing and duplicateRule ~= "replace" then
        quantity = existing.plannedQuantity + quantity
        if quantity > MAX_QUANTITY then
            return ResultError("INVALID_QUANTITY", "Merged quantity exceeds the supported limit", {
                field = "plannedQuantity",
            })
        end
    end
    if not existing and CountKeys(list.items) >= MAX_ITEMS_PER_LIST then
        return ResultError("ITEM_LIMIT", "Shopping list item limit reached")
    end
    list.items[itemID] = {
        itemID = itemID,
        itemName = itemName,
        plannedQuantity = quantity,
    }
    return { ok = true }
end

function Pro.AddShoppingListItem(listID, item, plannedQuantity, duplicateRule)
    local itemID, itemName, unresolved = ResolveItem(item)
    if not itemID then return unresolved end
    local quantity, invalid = ValidateQuantity(plannedQuantity)
    if not quantity then return invalid end
    if duplicateRule ~= nil and duplicateRule ~= "merge" and duplicateRule ~= "replace" then
        return ResultError("INVALID_DUPLICATE_RULE", "Duplicate rule must be merge or replace")
    end
    return Mutate(function(shopping)
        local list, failure = FindList(shopping, listID)
        if not list then return failure end
        local result = SetItem(list, itemID, itemName, quantity, duplicateRule or "merge")
        if not result.ok then return result end
        return { ok = true, list = DeepCopy(list) }
    end)
end

function Pro.UpdateShoppingListItem(listID, item, plannedQuantity)
    local itemID, itemName, unresolved = ResolveItem(item)
    if not itemID then return unresolved end
    local quantity, invalid = ValidateQuantity(plannedQuantity)
    if not quantity then return invalid end
    return Mutate(function(shopping)
        local list, failure = FindList(shopping, listID)
        if not list then return failure end
        if not list.items[itemID] then
            return ResultError("ITEM_NOT_FOUND", "Shopping list item was not found", { itemID = itemID })
        end
        list.items[itemID] = { itemID = itemID, itemName = itemName, plannedQuantity = quantity }
        return { ok = true, list = DeepCopy(list) }
    end)
end

function Pro.RemoveShoppingListItem(listID, item)
    local itemID, _, unresolved = ResolveItem(item)
    if not itemID then return unresolved end
    return Mutate(function(shopping)
        local list, failure = FindList(shopping, listID)
        if not list then return failure end
        if not list.items[itemID] then
            return ResultError("ITEM_NOT_FOUND", "Shopping list item was not found", { itemID = itemID })
        end
        list.items[itemID] = nil
        return { ok = true, list = DeepCopy(list) }
    end)
end

local function ValidateBatch(operations)
    if not ValidateArray(operations) then
        return nil, ResultError("BATCH_INVALID", "Batch operations must be a table", {
            errors = { ResultError("INVALID_BATCH", "Batch operations must be a dense array") },
        })
    end
    local prepared, errors = {}, {}
    for index, operation in ipairs(operations) do
        local action = type(operation) == "table" and operation.action or nil
        local itemValue = type(operation) == "table" and (operation.itemID or operation.item) or nil
        local itemID, itemName, itemFailure = ResolveItem(itemValue)
        local quantity, quantityFailure
        if action == "set" then quantity, quantityFailure = ValidateQuantity(operation.plannedQuantity) end
        local failure = itemFailure or quantityFailure
        if action ~= "set" and action ~= "remove" then
            failure = ResultError("INVALID_ACTION", "Batch action must be set or remove", { field = "action" })
        end
        if failure then
            failure.index = index
            errors[#errors + 1] = failure
        else
            prepared[#prepared + 1] = {
                action = action,
                itemID = itemID,
                itemName = itemName,
                plannedQuantity = quantity,
            }
        end
    end
    if #errors > 0 then
        return nil, ResultError("BATCH_INVALID", "One or more batch operations are invalid", { errors = errors })
    end
    return prepared
end

function Pro.BatchShoppingListItems(listID, operations)
    local prepared, invalid = ValidateBatch(operations)
    if not prepared then return invalid end
    return Mutate(function(shopping)
        local list, failure = FindList(shopping, listID)
        if not list then return failure end
        for _, operation in ipairs(prepared) do
            if operation.action == "remove" then
                list.items[operation.itemID] = nil
            else
                local result = SetItem(list, operation.itemID, operation.itemName,
                    operation.plannedQuantity, "replace")
                if not result.ok then return result end
            end
        end
        return { ok = true, list = DeepCopy(list) }
    end)
end

function Pro.ClearCompletedShoppingList(listID, completed)
    if type(completed) ~= "table" and type(completed) ~= "function" then
        return ResultError("INVALID_COMPLETED", "Completed items must be a table or function")
    end
    return Mutate(function(shopping)
        local list, failure = FindList(shopping, listID)
        if not list then return failure end
        for itemID in pairs(list.items) do
            local remove = type(completed) == "function" and completed(itemID, DeepCopy(list.items[itemID]))
                or completed[itemID] or completed[tostring(itemID)]
            if remove then list.items[itemID] = nil end
        end
        return { ok = true, list = DeepCopy(list) }
    end)
end

function Pro.GetShoppingListCostSummary(listID, options)
    local _, shopping, failure = GetStorage()
    if not shopping then return failure end
    local list, missing = FindList(shopping, listID)
    if not list then return missing end
    options = type(options) == "table" and options or {}
    local now = options.now
    if now == nil and type(_G.GetTime) == "function" then
        now = _G.GetTime()
    end
    local summary = {
        ok = true,
        listID = list.id,
        listName = list.name,
        itemCount = 0,
        freshCount = 0,
        staleCount = 0,
        missingCount = 0,
        knownSubtotal = 0,
        freshSubtotal = 0,
        staleSubtotal = 0,
        estimatedSubtotal = 0,
        exact = true,
        items = {},
    }

    local function NonNegativeInteger(value, defaultValue)
        local number = tonumber(value)
        if not number or number < 0 then
            return defaultValue or 0
        end
        return math.floor(number)
    end

    local function ReadByItemID(map, itemID)
        if type(map) ~= "table" then
            return nil
        end
        return map[itemID] or map[tostring(itemID)]
    end

    local function ResolveQuantities(itemID, plannedQuantity)
        local planned = NonNegativeInteger(plannedQuantity, 0)
        local context = ReadByItemID(options.quantitiesByItemID, itemID)
            or ReadByItemID(options.quantityContextByItemID, itemID)
        local owned = 0
        local needed = planned

        if type(context) == "table" then
            owned = NonNegativeInteger(context.ownedQuantity or context.ownedCount or context.owned, 0)
            local explicitNeeded = context.neededQuantity or context.missingQuantity or context.quantity
            if explicitNeeded ~= nil then
                needed = NonNegativeInteger(explicitNeeded, planned)
            else
                needed = planned - owned
            end
        else
            local explicitNeeded = ReadByItemID(options.neededQuantitiesByItemID, itemID)
                or ReadByItemID(options.missingQuantitiesByItemID, itemID)
            if explicitNeeded ~= nil then
                needed = NonNegativeInteger(explicitNeeded, planned)
            else
                owned = NonNegativeInteger(ReadByItemID(options.ownedCountsByItemID, itemID)
                    or ReadByItemID(options.ownedQuantitiesByItemID, itemID), 0)
                needed = planned - owned
            end
        end

        if needed < 0 then needed = 0 end
        if needed > planned then needed = planned end
        return owned, needed
    end

    local itemIDs = {}
    for itemID in pairs(list.items or {}) do
        itemIDs[#itemIDs + 1] = itemID
    end
    table.sort(itemIDs)
    for _, itemID in ipairs(itemIDs) do
        local item = list.items[itemID]
        local quantity = tonumber(item and item.plannedQuantity) or 0
        local ownedQuantity, neededQuantity = ResolveQuantities(itemID, quantity)
        local estimate = Pro.GetShoppingPriceEstimate and Pro.GetShoppingPriceEstimate(itemID, item and item.itemName, now, options) or nil
        local unitPrice = tonumber(estimate and estimate.unitPrice)
        local subtotal = 0
        local entry = {
            itemID = itemID,
            itemName = item and item.itemName,
            plannedQuantity = quantity,
            ownedQuantity = ownedQuantity,
            neededQuantity = neededQuantity,
            unitPrice = unitPrice and math.max(1, math.floor(unitPrice + 0.5)) or nil,
            state = estimate and estimate.state or "unavailable",
            source = estimate and estimate.source or "none",
            observedAt = estimate and estimate.observedAt or nil,
            subtotal = 0,
            exact = false,
        }
        summary.itemCount = summary.itemCount + 1
        if neededQuantity <= 0 then
            entry.exact = true
            entry.state = estimate and estimate.state or "covered"
            entry.source = estimate and estimate.source or "covered"
        elseif estimate and estimate.ok and unitPrice and unitPrice > 0
                and (estimate.state == "fresh" or estimate.state == "stale") then
            subtotal = math.max(0, math.floor(unitPrice * neededQuantity + 0.5))
            entry.subtotal = subtotal
            summary.estimatedSubtotal = summary.estimatedSubtotal + subtotal
            if estimate.state == "fresh" then
                summary.freshCount = summary.freshCount + 1
                summary.freshSubtotal = summary.freshSubtotal + subtotal
                summary.knownSubtotal = summary.knownSubtotal + subtotal
                entry.exact = true
            else
                summary.staleCount = summary.staleCount + 1
                summary.staleSubtotal = summary.staleSubtotal + subtotal
            end
        else
            summary.missingCount = summary.missingCount + 1
        end
        summary.exact = summary.exact and entry.exact
        summary.items[#summary.items + 1] = entry
    end
    summary.exact = summary.staleCount == 0 and summary.missingCount == 0
    return summary
end

local function EscapeField(value)
    return tostring(value):gsub("\\", "\\\\"):gsub("\t", "\\t"):gsub("\r", "\\r"):gsub("\n", "\\n"):gsub("|", "\\|")
end

local function UnescapeField(value)
    local output, index = {}, 1
    while index <= #value do
        local character = value:sub(index, index)
        if character ~= "\\" then
            output[#output + 1] = character
            index = index + 1
        else
            local escaped = value:sub(index + 1, index + 1)
            local replacement = ({ ["\\"] = "\\", t = "\t", r = "\r", n = "\n", ["|"] = "|" })[escaped]
            if not replacement then return nil end
            output[#output + 1] = replacement
            index = index + 2
        end
    end
    return table.concat(output)
end

local function SplitRow(line)
    local fields = {}
    for field in (line .. "\t"):gmatch("(.-)\t") do fields[#fields + 1] = field end
    return fields
end

local function SplitPipeRow(line)
    local fields, current, index = {}, {}, 1
    while index <= #line do
        local character = line:sub(index, index)
        if character == "\\" then
            local escaped = line:sub(index + 1, index + 1)
            if escaped == "" then
                current[#current + 1] = character
                index = index + 1
            else
                current[#current + 1] = character
                current[#current + 1] = escaped
                index = index + 2
            end
        elseif character == "|" then
            fields[#fields + 1] = table.concat(current)
            current = {}
            index = index + 1
        else
            current[#current + 1] = character
            index = index + 1
        end
    end
    fields[#fields + 1] = table.concat(current)
    return fields
end

local function SplitImportRow(line, delimiter)
    if delimiter == "pipe" then
        return SplitPipeRow(line)
    end
    return SplitRow(line)
end

local function ParseImport(text)
    if type(text) ~= "string" then
        return nil, ResultError("IMPORT_INVALID", "Import text must be a string", {
            errors = { { line = 1, code = "MALFORMED_HEADER" } },
        })
    end
    if #text > MAX_IMPORT_BYTES then
        return nil, ResultError("IMPORT_TOO_LARGE", "Import text exceeds the limit", { line = 1 })
    end
    text = text:gsub("\r\n", "\n"):gsub("\r", "\n")
    local lines = {}
    if text ~= "" then
        text = text:gsub("\n$", "")
        for line in (text .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end
    end
    -- WoW EditBox paste handling escapes literal pipes as "||". Detect that
    -- representation from the header and restore the exported wire text.
    if lines[1] and lines[1]:match("^EASYAUCTION_SHOPPING_LIST||%d+$") then
        for index = 1, #lines do
            lines[index] = lines[index]:gsub("||", "|")
        end
    end
    local delimiter
    if lines[1] == "EASYAUCTION_SHOPPING_LIST\t1" then
        delimiter = "tab"
    elseif lines[1] == "EASYAUCTION_SHOPPING_LIST|1" then
        delimiter = "pipe"
    else
        local version = lines[1] and (lines[1]:match("^EASYAUCTION_SHOPPING_LIST\t(%d+)$")
            or lines[1]:match("^EASYAUCTION_SHOPPING_LIST|(%d+)$"))
        if version and tonumber(version) ~= SCHEMA_VERSION then
            return nil, ResultError("UNSUPPORTED_VERSION", "Shopping list text version is unsupported", { line = 1 })
        end
        return nil, ResultError("IMPORT_INVALID", "Shopping list header is malformed", {
            errors = { { line = 1, code = "MALFORMED_HEADER" } },
        })
    end
    local parsed = { items = {} }
    local seenItems, errors = {}, {}
    for lineNumber = 2, #lines do
        local fields = SplitImportRow(lines[lineNumber], delimiter)
        if fields[1] == "LIST" and #fields == 2 and not parsed.name then
            parsed.name = UnescapeField(fields[2])
            if not parsed.name then errors[#errors + 1] = { line = lineNumber, code = "MALFORMED_ROW" } end
        elseif fields[1] == "ITEM" and #fields == 3 then
            local itemToken = fields[2]:match("^[1-9]%d*$")
            local quantityToken = fields[3]:match("^[1-9]%d*$")
            local itemID = itemToken and tonumber(itemToken) or nil
            local quantity = quantityToken and tonumber(quantityToken) or nil
            if not IsPositiveInteger(itemID) then
                errors[#errors + 1] = { line = lineNumber, code = "ITEM_UNRESOLVED" }
            elseif seenItems[itemID] then
                errors[#errors + 1] = { line = lineNumber, code = "DUPLICATE_ITEM" }
            elseif not quantity or quantity ~= math.floor(quantity) or quantity < 1 or quantity > MAX_QUANTITY then
                errors[#errors + 1] = { line = lineNumber, code = "INVALID_QUANTITY" }
                seenItems[itemID] = true
            else
                seenItems[itemID] = true
                local resolvedID, itemName = ResolveItem(itemID)
                if not resolvedID then
                    errors[#errors + 1] = { line = lineNumber, code = "ITEM_UNRESOLVED" }
                else
                    parsed.items[#parsed.items + 1] = {
                        itemID = resolvedID,
                        itemName = itemName,
                        plannedQuantity = quantity,
                    }
                end
            end
        else
            errors[#errors + 1] = { line = lineNumber, code = "MALFORMED_ROW" }
        end
    end
    local validName = parsed.name and ValidateName(parsed.name)
    if not parsed.name or not validName then
        errors[#errors + 1] = { line = 2, code = "INVALID_NAME" }
    end
    if #errors > 0 then
        return nil, ResultError("IMPORT_INVALID", "Shopping list text contains invalid rows", { errors = errors })
    end
    if #parsed.items > MAX_ITEMS_PER_LIST then
        return nil, ResultError("ITEM_LIMIT", "Shopping list item limit reached")
    end
    parsed.name = validName
    return parsed
end

function Pro.ExportShoppingListText(listID)
    local result = Pro.GetShoppingList(listID)
    if not result.ok then return result end
    local list = result.list
    local rows = {
        "EASYAUCTION_SHOPPING_LIST\t1",
        "LIST\t" .. EscapeField(list.exportName or list.name),
    }
    local itemIDs = {}
    for itemID in pairs(list.items) do itemIDs[#itemIDs + 1] = itemID end
    table.sort(itemIDs)
    for _, itemID in ipairs(itemIDs) do
        rows[#rows + 1] = "ITEM\t" .. itemID .. "\t" .. list.items[itemID].plannedQuantity
    end
    return { ok = true, text = table.concat(rows, "\n") }
end

function Pro.ExportShoppingListDisplayText(listID)
    local result = Pro.GetShoppingList(listID)
    if not result.ok then return result end
    local list = result.list
    local rows = {
        "EASYAUCTION_SHOPPING_LIST|1",
        "LIST|" .. EscapeField(list.exportName or list.name),
    }
    local itemIDs = {}
    for itemID in pairs(list.items) do itemIDs[#itemIDs + 1] = itemID end
    table.sort(itemIDs)
    for _, itemID in ipairs(itemIDs) do
        rows[#rows + 1] = "ITEM|" .. itemID .. "|" .. list.items[itemID].plannedQuantity
    end
    return { ok = true, text = table.concat(rows, "\n") }
end

function Pro.ImportShoppingListText(text, options)
    local parsed, invalid = ParseImport(text)
    if not parsed then return invalid end
    options = type(options) == "table" and options or {}
    local mode = options.mode or "create"
    if mode == "create" then
        return Mutate(function(shopping, indexes)
            local result = CreateList(shopping, indexes, parsed.name, true)
            if not result.ok then return result end
            local list = result.list
            if list.name ~= parsed.name then list.exportName = parsed.name end
            for _, item in ipairs(parsed.items) do
                list.items[item.itemID] = DeepCopy(item)
            end
            return { ok = true, list = DeepCopy(list) }
        end)
    end
    if mode ~= "merge" and mode ~= "replace" then
        return ResultError("INVALID_IMPORT_MODE", "Import mode must be create, merge, or replace")
    end
    local listID = options.listID
    return Mutate(function(shopping, indexes)
        local list, failure = FindList(shopping, listID)
        if not list then return failure end
        if mode == "replace" then
            local owner = indexes.names[NameKey(parsed.name)]
            if owner and owner ~= list.id then
                return ResultError("NAME_EXISTS", "Shopping list name already exists", { field = "name" })
            end
            list.name, list.items, list.exportName = parsed.name, {}, nil
        end
        for _, item in ipairs(parsed.items) do
            local result = SetItem(list, item.itemID, item.itemName, item.plannedQuantity,
                mode == "merge" and "merge" or "replace")
            if not result.ok then return result end
        end
        return { ok = true, list = DeepCopy(list) }
    end)
end

local function PreparePayload(payload, requireName)
    if type(payload) ~= "table" then
        return nil, ResultError("INVALID_PAYLOAD", "Shopping list payload must be a table")
    end
    local name, invalid
    if requireName or payload.name ~= nil then
        name, invalid = ValidateName(payload.name)
        if not name then return nil, invalid end
    end
    if payload.items ~= nil and not ValidateArray(payload.items) then
        return nil, ResultError("PAYLOAD_INVALID", "Payload items must be a dense array", {
            field = "items",
            errors = { ResultError("INVALID_ITEMS", "Payload items must be a dense array", { field = "items" }) },
        })
    end
    if payload.items == nil then payload.items = {} end
    local prepared, byID = { name = name, items = {} }, {}
    local errors = {}
    for index, item in ipairs(payload.items or {}) do
        local itemID, itemName, itemFailure = ResolveItem(type(item) == "table" and (item.itemID or item.item))
        local quantity, quantityFailure = ValidateQuantity(type(item) == "table" and item.plannedQuantity)
        local failure = itemFailure or quantityFailure
        if failure then
            failure.index = index
            errors[#errors + 1] = failure
        elseif byID[itemID] then
            local merged = byID[itemID].plannedQuantity + quantity
            if merged > MAX_QUANTITY then
                errors[#errors + 1] = { index = index, code = "INVALID_QUANTITY", field = "plannedQuantity" }
            else
                byID[itemID].plannedQuantity = merged
            end
        else
            local entry = { itemID = itemID, itemName = itemName, plannedQuantity = quantity }
            byID[itemID] = entry
            prepared.items[#prepared.items + 1] = entry
        end
    end
    if #errors > 0 then
        return nil, ResultError("PAYLOAD_INVALID", "Shopping list payload contains invalid items", { errors = errors })
    end
    if #prepared.items > MAX_ITEMS_PER_LIST then
        return nil, ResultError("ITEM_LIMIT", "Shopping list item limit reached")
    end
    return prepared
end

local function APICreate(payload)
    local prepared, invalid = PreparePayload(DeepCopy(payload), true)
    if not prepared then return invalid end
    return Mutate(function(shopping, indexes)
        local result = CreateList(shopping, indexes, prepared.name, true)
        if not result.ok then return result end
        for _, item in ipairs(prepared.items) do result.list.items[item.itemID] = DeepCopy(item) end
        return { ok = true, list = DeepCopy(result.list) }
    end)
end

local function APIMerge(listID, payload)
    local copied = DeepCopy(payload)
    if type(copied) == "table" then copied.name = nil end
    local prepared, invalid = PreparePayload(copied, false)
    if not prepared then return invalid end
    return Mutate(function(shopping)
        local list, failure = FindList(shopping, listID)
        if not list then return failure end
        for _, item in ipairs(prepared.items) do
            local result = SetItem(list, item.itemID, item.itemName, item.plannedQuantity, "merge")
            if not result.ok then return result end
        end
        return { ok = true, list = DeepCopy(list) }
    end)
end

local function APIReplace(listID, payload)
    local prepared, invalid = PreparePayload(DeepCopy(payload), true)
    if not prepared then return invalid end
    return Mutate(function(shopping, indexes)
        local list, failure = FindList(shopping, listID)
        if not list then return failure end
        local owner = indexes.names[NameKey(prepared.name)]
        if owner and owner ~= list.id then
            return ResultError("NAME_EXISTS", "Shopping list name already exists", { field = "name" })
        end
        list.name, list.items, list.exportName = prepared.name, {}, nil
        for _, item in ipairs(prepared.items) do list.items[item.itemID] = DeepCopy(item) end
        return { ok = true, list = DeepCopy(list) }
    end)
end

local function EnsureAPIReady()
    local db = Pro.GetDB and Pro.GetDB()
    if state.ready and state.db == db and state.shopping == (db and db.Pro and db.Pro.shopping) then
        return { ok = true }
    end
    if type(Pro.InitializeShoppingLists) == "function" then
        return Pro.InitializeShoppingLists()
    end
    return ResultError("NOT_READY", "Shopping lists are not initialized")
end

local function APICall(callback)
    local ready = EnsureAPIReady()
    if type(ready) == "table" and ready.ok == false then
        return ready
    end
    return callback()
end

local api = {
    __contract = "EasyAuction.ShoppingLists",
    __major = 1,
    __owner = "EasyAuction",
}

function api.GetCapabilities()
    return APICall(function()
        local _, shopping, failure = GetStorage()
        if not shopping then return failure end
        return {
            ok = true,
            schemaVersion = SCHEMA_VERSION,
            maxLists = MAX_LISTS,
            maxItemsPerList = MAX_ITEMS_PER_LIST,
            maxQuantity = MAX_QUANTITY,
            maxNameBytes = MAX_NAME_BYTES,
            maxImportBytes = MAX_IMPORT_BYTES,
            importModes = { "create", "merge", "replace" },
            exportFormats = { "tsv", "pipe" },
            changeToken = shopping.changeToken,
        }
    end)
end

function api.Create(payload)
    return APICall(function() return APICreate(payload) end)
end

function api.Merge(listID, payload)
    return APICall(function() return APIMerge(listID, payload) end)
end

function api.Replace(listID, payload)
    return APICall(function() return APIReplace(listID, payload) end)
end

function api.ImportText(text, options)
    return APICall(function() return Pro.ImportShoppingListText(text, options) end)
end

function api.ExportText(listID)
    return APICall(function() return Pro.ExportShoppingListText(listID) end)
end

function api.ExportDisplayText(listID)
    return APICall(function() return Pro.ExportShoppingListDisplayText(listID) end)
end

function api.GetList(listID)
    return APICall(function() return Pro.GetShoppingList(listID) end)
end

function api.GetLists()
    return APICall(function() return Pro.GetShoppingLists() end)
end

function api.RegisterCallback(listenerID, callback)
    if type(listenerID) ~= "string" or listenerID == "" or type(callback) ~= "function" then
        return ResultError("INVALID_CALLBACK", "Callback ID and function are required")
    end
    return Pro.RegisterListener(CHANGE_EVENT, "shopping-api:" .. listenerID, function(payload)
        state.notifying = state.notifying + 1
        local ok, message = pcall(callback, DeepCopy(payload))
        state.notifying = state.notifying - 1
        if not ok then error(message) end
    end)
end

function api.UnregisterCallback(listenerID)
    if type(listenerID) ~= "string" or listenerID == "" then
        return ResultError("INVALID_CALLBACK", "Callback ID is required")
    end
    return Pro.UnregisterListener(CHANGE_EVENT, "shopping-api:" .. listenerID)
end

function Pro.GetShoppingListsAPIStatus()
    return DeepCopy(state.apiStatus)
end

function _G.EasyAuctionPro_GetShoppingListCostSummary(listID, options)
    return Pro.GetShoppingListCostSummary(listID, options)
end

local apiRoot = _G.EasyAuctionAPI
if apiRoot ~= nil and type(apiRoot) ~= "table" then
    state.apiStatus = ResultError("API_NAMESPACE_CONFLICT", "EasyAuctionAPI is already occupied by a non-table value")
else
    apiRoot = apiRoot or {}
    _G.EasyAuctionAPI = apiRoot
    local shoppingAPI = apiRoot.ShoppingLists
    if shoppingAPI ~= nil and type(shoppingAPI) ~= "table" then
        state.apiStatus = ResultError(
            "API_NAMESPACE_CONFLICT", "EasyAuctionAPI.ShoppingLists is already occupied by a non-table value"
        )
    else
        shoppingAPI = shoppingAPI or {}
        apiRoot.ShoppingLists = shoppingAPI
        local existing = shoppingAPI.v1
        if existing == nil then
            shoppingAPI.v1 = api
            state.apiStatus = { ok = true, installed = true, major = 1 }
        elseif type(existing) == "table" and existing.__contract == api.__contract
                and existing.__major == api.__major and existing.__owner == api.__owner then
            state.apiStatus = { ok = true, installed = false, compatible = true, major = 1 }
        else
            state.apiStatus = ResultError(
                "API_VERSION_CONFLICT", "An incompatible ShoppingLists v1 API is already installed"
            )
        end
    end
end
