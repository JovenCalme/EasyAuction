local addonName, ns = ...

ns.EasyAuctionPro = ns.EasyAuctionPro or {}
local Pro = ns.EasyAuctionPro

local DEFAULT_OPERATION_NAME = "默认策略"
local DEFAULT_GROUP_NAME = "默认分组"

local LEGACY_DEFAULT_OPERATION = {
    minPriceSource = "median7d",
    minPricePct = 0.70,
    normalPriceSource = "median7d",
    normalPricePct = 0.95,
    maxPriceSource = "median7d",
    maxPricePct = 1.30,
    undercutAmount = 1,
    ignoreLowPricePct = 0.60,
    keepQuantity = 0,
    postCap = 5,
    stackSize = 20,
    numStacks = 1,
    duration = 1,
    maxExpires = 0,
}

local DEFAULT_AUCTION_OPERATIONS = {
    ["默认策略"] = {
        minPriceSource = "median7d",
        minPricePct = 0.75,
        normalPriceSource = "median7d",
        normalPricePct = 0.95,
        maxPriceSource = "median7d",
        maxPricePct = 1.15,
        undercutAmount = 1,
        ignoreLowPricePct = 0.45,
        ignoreLowQuantity = 2,
        keepQuantity = 0,
        postCap = 3,
        stackSize = 20,
        numStacks = 1,
        duration = 1,
        maxExpires = 0,
    },
    ["快速出手"] = {
        minPriceSource = "currentMin",
        minPricePct = 0.90,
        normalPriceSource = "currentMin",
        normalPricePct = 1.00,
        maxPriceSource = "median7d",
        maxPricePct = 1.05,
        undercutAmount = 1,
        ignoreLowPricePct = 0.35,
        ignoreLowQuantity = 1,
        keepQuantity = 0,
        postCap = 5,
        stackSize = 20,
        numStacks = 2,
        duration = 1,
        maxExpires = 0,
    },
    ["稳价上架"] = {
        minPriceSource = "median7d",
        minPricePct = 0.85,
        normalPriceSource = "median7d",
        normalPricePct = 1.00,
        maxPriceSource = "median7d",
        maxPricePct = 1.25,
        undercutAmount = 1,
        ignoreLowPricePct = 0.50,
        ignoreLowQuantity = 2,
        keepQuantity = 0,
        postCap = 2,
        stackSize = 20,
        numStacks = 1,
        duration = 2,
        maxExpires = 0,
    },
    ["材料薄利"] = {
        minPriceSource = "currentMin",
        minPricePct = 0.95,
        normalPriceSource = "currentMin",
        normalPricePct = 1.00,
        maxPriceSource = "median7d",
        maxPricePct = 1.10,
        undercutAmount = 1,
        ignoreLowPricePct = 0.30,
        ignoreLowQuantity = 1,
        keepQuantity = 0,
        postCap = 10,
        stackSize = 20,
        numStacks = 3,
        duration = 1,
        maxExpires = 0,
    },
    ["高价试挂"] = {
        minPriceSource = "median7d",
        minPricePct = 0.95,
        normalPriceSource = "median7d",
        normalPricePct = 1.15,
        maxPriceSource = "median7d",
        maxPricePct = 1.50,
        undercutAmount = 1,
        ignoreLowPricePct = 0.55,
        ignoreLowQuantity = 1,
        keepQuantity = 0,
        postCap = 1,
        stackSize = 1,
        numStacks = 1,
        duration = 2,
        maxExpires = 0,
    },
    ["消耗品清仓"] = {
        minPriceSource = "currentMin",
        minPricePct = 0.85,
        normalPriceSource = "currentMin",
        normalPricePct = 0.98,
        maxPriceSource = "median7d",
        maxPricePct = 1.05,
        undercutAmount = 1,
        ignoreLowPricePct = 0.25,
        ignoreLowQuantity = 0,
        keepQuantity = 0,
        postCap = 12,
        stackSize = 20,
        numStacks = 5,
        duration = 1,
        maxExpires = 0,
    },
}

local DEFAULT_OPERATION_ORDER = {
    "默认策略",
    "快速出手",
    "稳价上架",
    "材料薄利",
    "高价试挂",
    "消耗品清仓",
}

local function CopyDefaults(target, defaults)
    target = target or {}
    for key, value in pairs(defaults) do
        if target[key] == nil then
            target[key] = value
        end
    end
    return target
end

local function CopyTable(source)
    local copied = {}
    for key, value in pairs(source or {}) do
        copied[key] = value
    end
    return copied
end

local CORE_LIMITS = {
    emitQueue = 128,
    diagnostics = 64,
    receipts = 128,
    deliveries = 256,
    maxAttempts = 5,
}

local coreState = {
    readiness = {
        domain = false,
        runtime = false,
        ui = false,
    },
    readinessDetails = {},
    listeners = {},
    emitQueue = {},
    dispatching = false,
    transactionActive = false,
    transactionEmits = nil,
    transactionReliableEmits = nil,
    transactionReliableByToken = nil,
    transactionReliableProcessing = false,
    transactionReliableLimit = nil,
    processingReliable = false,
    diagnostics = {},
    listenerErrors = 0,
    droppedEmits = 0,
    receipts = {},
    receiptOrder = {},
    deliveries = {},
    deliveryOrder = {},
    shoppingPriceCache = {
        fresh = {},
    },
    shoppingPriceProviders = {
        byID = {},
        order = {},
    },
}

local function SnapshotValue(value, seen)
    if type(value) ~= "table" then
        return value
    end
    seen = seen or {}
    if seen[value] then
        return seen[value]
    end
    local copied = {}
    seen[value] = copied
    for key, child in pairs(value) do
        copied[SnapshotValue(key, seen)] = SnapshotValue(child, seen)
    end
    return copied
end

local function CoreError(code, message, extra)
    local result = {
        ok = false,
        code = code,
        message = message,
    }
    for key, value in pairs(extra or {}) do
        result[key] = value
    end
    return result
end

local function SafeErrorText(value)
    local ok, message = pcall(tostring, value)
    if ok then
        return message
    end
    return "<unprintable error>"
end

local function IsFiniteNumber(value)
    return type(value) == "number" and value == value and
        value < math.huge and value > -math.huge
end

local function RecordCoreDiagnostic(code, fields)
    local entry = { code = code }
    for key, value in pairs(fields or {}) do
        entry[key] = value
    end
    local diagnostics = coreState.diagnostics
    diagnostics[#diagnostics + 1] = entry
    if #diagnostics > CORE_LIMITS.diagnostics then
        table.remove(diagnostics, 1)
    end
end

local function IsValidKey(value)
    return type(value) == "string" and value ~= ""
end

function Pro.SetReadiness(layer, ready, detail)
    if coreState.readiness[layer] == nil then
        return CoreError("INVALID_READINESS_LAYER", "Unknown readiness layer", { layer = layer })
    end
    coreState.readiness[layer] = ready and true or false
    coreState.readinessDetails[layer] = SnapshotValue(detail)
    return {
        ok = true,
        layer = layer,
        ready = coreState.readiness[layer],
    }
end

function Pro.IsReady(layer)
    return coreState.readiness[layer] == true
end

function Pro.GetReadiness()
    return {
        domain = coreState.readiness.domain,
        runtime = coreState.readiness.runtime,
        ui = coreState.readiness.ui,
        details = SnapshotValue(coreState.readinessDetails),
    }
end

function Pro.RequireReady(layers)
    if type(layers) == "string" then
        layers = { layers }
    elseif layers == nil then
        layers = { "domain", "runtime", "ui" }
    elseif type(layers) ~= "table" then
        return CoreError("INVALID_READINESS_LAYER", "Readiness requirement must be a layer or list")
    end

    for _, layer in ipairs(layers) do
        if coreState.readiness[layer] == nil then
            return CoreError("INVALID_READINESS_LAYER", "Unknown readiness layer", { layer = layer })
        end
        if not coreState.readiness[layer] then
            return CoreError("NOT_READY", "Required subsystem is not ready", {
                layer = layer,
                readiness = Pro.GetReadiness(),
            })
        end
    end
    return { ok = true, readiness = Pro.GetReadiness() }
end

local SHOPPING_PRICE_PROVIDER_CONTRACT = "EasyAuction.ShoppingPriceProvider"
local SHOPPING_PRICE_PROVIDER_MAJOR = 1

local function IsProviderCallable(provider)
    return type(provider) == "function" or
        (type(provider) == "table" and type(provider.GetPrice) == "function")
end

local function ProviderMetadata(provider)
    if type(provider) ~= "table" then
        return nil, nil, nil
    end
    return provider.__contract, provider.__major, provider.__owner
end

local function ProvidersCompatible(left, right)
    local leftContract, leftMajor, leftOwner = ProviderMetadata(left)
    local rightContract, rightMajor, rightOwner = ProviderMetadata(right)
    if leftContract == nil and rightContract == nil then
        return true
    end
    return leftContract == rightContract and tonumber(leftMajor) == tonumber(rightMajor) and leftOwner == rightOwner
end

local function NormalizePriceResult(result, providerID)
    if type(result) ~= "table" then
        return CoreError("PROVIDER_INVALID_RESULT", "Shopping price provider returned an invalid result", {
            providerID = providerID,
        })
    end
    if result.ok == false then
        return result
    end
    local state = result.state
    if state ~= "fresh" and state ~= "stale" and state ~= "unavailable" then
        return CoreError("PROVIDER_INVALID_RESULT", "Shopping price provider returned an invalid state", {
            providerID = providerID,
        })
    end
    if state == "fresh" or state == "stale" then
        local unitPrice = tonumber(result.unitPrice)
        if not IsFiniteNumber(unitPrice) or unitPrice <= 0 then
            return CoreError("PROVIDER_INVALID_RESULT", "Shopping price provider returned an invalid price", {
                providerID = providerID,
            })
        end
        result.unitPrice = math.max(1, math.floor(unitPrice + 0.5))
    else
        result.unitPrice = nil
    end
    result.ok = true
    result.providerID = result.providerID or providerID
    return result
end

local function RememberFreshShoppingPrice(result)
    if type(result) ~= "table" or not result.ok or result.state ~= "fresh" then
        return
    end
    local itemID = tonumber(result.itemID)
    if not itemID then
        return
    end
    coreState.shoppingPriceCache.fresh[itemID] = {
        itemID = itemID,
        itemName = result.itemName,
        unitPrice = result.unitPrice,
        state = result.state,
        source = result.source,
        observedAt = result.observedAt,
        providerID = result.providerID,
    }
end

function Pro.HasFreshShoppingPriceEstimate(itemID)
    itemID = tonumber(itemID)
    if not itemID then
        return false
    end
    return coreState.shoppingPriceCache.fresh[itemID] ~= nil
end

function Pro.RegisterShoppingPriceProvider(providerID, provider, options)
    if not IsValidKey(providerID) or not IsProviderCallable(provider) then
        return CoreError("INVALID_PROVIDER", "Provider ID and callable provider are required")
    end
    if options ~= nil and type(options) ~= "table" then
        return CoreError("INVALID_OPTIONS", "Provider options must be a table")
    end
    options = options or {}
    local registry = coreState.shoppingPriceProviders
    local providerContract, providerMajor, providerOwner = ProviderMetadata(provider)
    local wrapped = {
        __contract = options.contract or providerContract or SHOPPING_PRICE_PROVIDER_CONTRACT,
        __major = tonumber(options.major or providerMajor) or SHOPPING_PRICE_PROVIDER_MAJOR,
        __owner = options.owner or providerOwner,
    }
    if type(provider) == "function" then
        function wrapped.GetPrice(_, itemID, itemName, now, callOptions)
            return provider(itemID, itemName, now, callOptions)
        end
    else
        function wrapped.GetPrice(_, itemID, itemName, now, callOptions)
            return provider:GetPrice(itemID, itemName, now, callOptions)
        end
    end
    local existing = registry.byID[providerID]
    if existing and not ProvidersCompatible(existing, wrapped) then
        return CoreError("PRICE_PROVIDER_CONFLICT", "An incompatible shopping price provider is already registered", {
            providerID = providerID,
        })
    end
    registry.byID[providerID] = wrapped
    local replaced = existing ~= nil
    if not replaced then
        registry.order[#registry.order + 1] = providerID
    end
    return { ok = true, providerID = providerID, replaced = replaced }
end

function Pro.GetShoppingPriceProvider(providerID)
    if not IsValidKey(providerID) then
        return CoreError("INVALID_PROVIDER", "Provider ID is required")
    end
    local provider = coreState.shoppingPriceProviders.byID[providerID]
    if not provider then
        return CoreError("PROVIDER_NOT_FOUND", "Shopping price provider was not found", {
            providerID = providerID,
        })
    end
    return { ok = true, providerID = providerID, provider = provider }
end

function Pro.ClearShoppingPriceProviders()
    coreState.shoppingPriceProviders = { byID = {}, order = {} }
    return { ok = true }
end

function Pro.GetShoppingPrice(itemID, itemName, now, options)
    options = type(options) == "table" and options or {}
    if now == nil and type(_G.GetTime) == "function" then
        now = _G.GetTime()
    end
    local registry = coreState.shoppingPriceProviders
    local providerID = options.providerID
    local provider = providerID and registry.byID[providerID] or registry.byID.default
    if not provider then
        providerID = providerID or registry.order[1]
        provider = providerID and registry.byID[providerID] or nil
    end
    if not provider then
        return { ok = true, itemID = tonumber(itemID), state = "unavailable", source = "none" }
    end
    local ok, result
    if type(provider) == "function" then
        ok, result = pcall(provider, itemID, itemName, now, options)
    else
        ok, result = pcall(provider.GetPrice, provider, itemID, itemName, now, options)
    end
    if not ok then
        local message = SafeErrorText(result)
        RecordCoreDiagnostic("PRICE_PROVIDER_ERROR", { providerID = providerID, message = message })
        return CoreError("PROVIDER_FAILED", "Shopping price provider failed", {
            providerID = providerID,
            detail = message,
        })
    end
    return NormalizePriceResult(SnapshotValue(result), providerID)
end

function Pro.GetShoppingPriceEstimate(itemID, itemName, now, options)
    local result = Pro.GetShoppingPrice(itemID, itemName, now, options)
    RememberFreshShoppingPrice(result)
    return result
end

local function GetListenerRegistry(eventName, create)
    local registry = coreState.listeners[eventName]
    if not registry and create then
        registry = { byID = {}, order = {} }
        coreState.listeners[eventName] = registry
    end
    return registry
end

function Pro.RegisterListener(eventName, listenerID, callback, options)
    if not IsValidKey(eventName) or not IsValidKey(listenerID) or type(callback) ~= "function" then
        return CoreError("INVALID_LISTENER", "Event, listener ID, and callback are required")
    end
    if options ~= nil and type(options) ~= "table" then
        return CoreError("INVALID_OPTIONS", "Listener options must be a table")
    end
    options = options or {}
    local maxAttempts = CORE_LIMITS.maxAttempts
    if options.maxAttempts ~= nil then
        maxAttempts = tonumber(options.maxAttempts)
        if not IsFiniteNumber(maxAttempts) then
            return CoreError("INVALID_OPTIONS", "maxAttempts must be a finite number", {
                field = "maxAttempts",
            })
        end
        maxAttempts = math.floor(maxAttempts)
    end
    if maxAttempts < 1 then maxAttempts = 1 end
    if maxAttempts > CORE_LIMITS.maxAttempts then maxAttempts = CORE_LIMITS.maxAttempts end
    local registry = GetListenerRegistry(eventName, true)
    local replaced = registry.byID[listenerID] ~= nil
    registry.byID[listenerID] = {
        id = listenerID,
        callback = callback,
        reliable = options.reliable and true or false,
        maxAttempts = maxAttempts,
    }
    if not replaced then
        registry.order[#registry.order + 1] = listenerID
    end
    return { ok = true, replaced = replaced }
end

function Pro.RegisterReliableListener(eventName, listenerID, callback, options)
    if options ~= nil and type(options) ~= "table" then
        return CoreError("INVALID_OPTIONS", "Listener options must be a table")
    end
    options = CopyTable(options)
    options.reliable = true
    return Pro.RegisterListener(eventName, listenerID, callback, options)
end

function Pro.UnregisterListener(eventName, listenerID)
    local registry = GetListenerRegistry(eventName, false)
    if not registry or not registry.byID[listenerID] then
        return { ok = true, removed = false }
    end
    registry.byID[listenerID] = nil
    for index, registeredID in ipairs(registry.order) do
        if registeredID == listenerID then
            table.remove(registry.order, index)
            break
        end
    end
    if #registry.order == 0 then
        coreState.listeners[eventName] = nil
    end
    return { ok = true, removed = true }
end

local function SnapshotListeners(eventName, reliable)
    local copied = {}
    local registry = GetListenerRegistry(eventName, false)
    if not registry then
        return copied
    end
    for _, listenerID in ipairs(registry.order) do
        local listener = registry.byID[listenerID]
        if listener and listener.reliable == reliable then
            copied[#copied + 1] = listener
        end
    end
    return copied
end

local function QueueEmit(eventName, payload)
    if #coreState.emitQueue >= CORE_LIMITS.emitQueue then
        coreState.droppedEmits = coreState.droppedEmits + 1
        RecordCoreDiagnostic("EMIT_QUEUE_FULL", { event = eventName })
        return CoreError("EMIT_QUEUE_FULL", "Dispatcher queue is full", { event = eventName })
    end
    coreState.emitQueue[#coreState.emitQueue + 1] = {
        event = eventName,
        payload = payload,
    }
    return { ok = true, queued = true }
end

local function DrainEmitQueue()
    if coreState.dispatching then return { ok = true, deferred = true } end
    coreState.dispatching = true
    local ok, failure = pcall(function()
        while #coreState.emitQueue > 0 do
            local emission = table.remove(coreState.emitQueue, 1)
            local listeners = SnapshotListeners(emission.event, false)
            for _, listener in ipairs(listeners) do
                local listenerOK, message = pcall(listener.callback, emission.payload, emission.event, listener.id)
                if not listenerOK then
                    coreState.listenerErrors = coreState.listenerErrors + 1
                    RecordCoreDiagnostic("LISTENER_ERROR", {
                        event = emission.event,
                        listenerID = listener.id,
                        message = SafeErrorText(message),
                    })
                end
            end
        end
    end)
    coreState.dispatching = false
    if not ok then
        local message = SafeErrorText(failure)
        RecordCoreDiagnostic("DISPATCH_ERROR", { message = message })
        return CoreError("DISPATCH_FAILED", "Dispatcher failed", { detail = message })
    end
    return { ok = true }
end

function Pro.Emit(eventName, payload)
    if not IsValidKey(eventName) then
        return CoreError("INVALID_EVENT", "Event name is required")
    end
    if coreState.transactionActive then
        local deferred = coreState.transactionEmits
        if #deferred >= CORE_LIMITS.emitQueue then
            coreState.droppedEmits = coreState.droppedEmits + 1
            RecordCoreDiagnostic("TRANSACTION_EMIT_QUEUE_FULL", { event = eventName })
            return CoreError("EMIT_QUEUE_FULL", "Transaction callback queue is full", { event = eventName })
        end
        deferred[#deferred + 1] = { event = eventName, payload = payload }
        return { ok = true, queued = true, deferred = true }
    end
    local result = QueueEmit(eventName, payload)
    if result.ok then
        local drained = DrainEmitQueue()
        if not drained.ok then
            return drained
        end
    end
    return result
end

local function DeliveryKey(token, listenerID)
    return tostring(#token) .. ":" .. token .. tostring(#listenerID) .. ":" .. listenerID
end

local function ReceiptIsTerminal(receipt)
    for _, key in ipairs(receipt.deliveryKeys) do
        local delivery = coreState.deliveries[key]
        if delivery and not delivery.acked and not delivery.exhausted then
            return false
        end
    end
    return true
end

local function RemoveReceiptAt(index)
    local token = coreState.receiptOrder[index]
    local receipt = token and coreState.receipts[token]
    if receipt then
        for _, key in ipairs(receipt.deliveryKeys) do
            coreState.deliveries[key] = nil
            for deliveryIndex, orderedKey in ipairs(coreState.deliveryOrder) do
                if orderedKey == key then
                    table.remove(coreState.deliveryOrder, deliveryIndex)
                    break
                end
            end
        end
        coreState.receipts[token] = nil
    end
    table.remove(coreState.receiptOrder, index)
end

local function MakeReliableCapacity(requiredDeliveries, requiredReceipts)
    requiredReceipts = requiredReceipts or 1
    while (#coreState.receiptOrder + requiredReceipts > CORE_LIMITS.receipts or
            #coreState.deliveryOrder + requiredDeliveries > CORE_LIMITS.deliveries) do
        local removed = false
        for index, token in ipairs(coreState.receiptOrder) do
            local receipt = coreState.receipts[token]
            if receipt and ReceiptIsTerminal(receipt) then
                RemoveReceiptAt(index)
                removed = true
                break
            end
        end
        if not removed then
            return false
        end
    end
    return true
end

local function StoreReliableEmission(emission)
    local receipt = {
        token = emission.token,
        event = emission.event,
        payload = emission.payload,
        deliveryKeys = {},
    }
    coreState.receipts[emission.token] = receipt
    coreState.receiptOrder[#coreState.receiptOrder + 1] = emission.token
    for _, listener in ipairs(emission.listeners) do
        local key = DeliveryKey(emission.token, listener.id)
        local delivery = {
            key = key,
            token = emission.token,
            event = emission.event,
            listenerID = listener.id,
            callback = listener.callback,
            payload = receipt.payload,
            attempts = 0,
            maxAttempts = listener.maxAttempts,
            acked = false,
            exhausted = false,
        }
        coreState.deliveries[key] = delivery
        coreState.deliveryOrder[#coreState.deliveryOrder + 1] = key
        receipt.deliveryKeys[#receipt.deliveryKeys + 1] = key
    end
end

function Pro.EmitReliable(eventName, token, payload)
    if not IsValidKey(eventName) or not IsValidKey(token) then
        return CoreError("INVALID_RECEIPT", "Event name and receipt token are required")
    end
    local existing = coreState.receipts[token]
    if existing then
        if existing.event ~= eventName then
            RecordCoreDiagnostic("RECEIPT_TOKEN_CONFLICT", { token = token, event = eventName })
            return CoreError("RECEIPT_TOKEN_CONFLICT", "Receipt token already belongs to another event", {
                token = token,
            })
        end
        return { ok = true, duplicate = true, token = token, listenerCount = #existing.deliveryKeys }
    end

    local listeners = SnapshotListeners(eventName, true)
    local emission = {
        token = token,
        event = eventName,
        payload = SnapshotValue(payload),
        listeners = listeners,
    }
    if coreState.transactionActive then
        local staged = coreState.transactionReliableByToken[token]
        if staged then
            if staged.event ~= eventName then
                return CoreError("RECEIPT_TOKEN_CONFLICT", "Receipt token already belongs to another event", {
                    token = token,
                })
            end
            return { ok = true, duplicate = true, deferred = true, token = token,
                listenerCount = #staged.listeners }
        end
        local stagedDeliveries = #listeners
        for _, pending in ipairs(coreState.transactionReliableEmits) do
            stagedDeliveries = stagedDeliveries + #pending.listeners
        end
        if #coreState.transactionReliableEmits + 1 > CORE_LIMITS.receipts or
                stagedDeliveries > CORE_LIMITS.deliveries then
            return CoreError("DELIVERY_QUEUE_FULL", "Transaction reliable delivery queue is full", {
                token = token,
            })
        end
        coreState.transactionReliableEmits[#coreState.transactionReliableEmits + 1] = emission
        coreState.transactionReliableByToken[token] = emission
        return { ok = true, duplicate = false, deferred = true, token = token,
            listenerCount = #listeners }
    end

    if not MakeReliableCapacity(#listeners, 1) then
        RecordCoreDiagnostic("DELIVERY_QUEUE_FULL", { token = token, event = eventName })
        return CoreError("DELIVERY_QUEUE_FULL", "Reliable delivery queue is full", { token = token })
    end
    StoreReliableEmission(emission)
    return { ok = true, duplicate = false, token = token, listenerCount = #listeners }
end

function Pro.AcknowledgeReliableDelivery(token, listenerID)
    if not IsValidKey(token) or not IsValidKey(listenerID) then
        return CoreError("INVALID_ACK", "Receipt token and listener ID are required")
    end
    local delivery = coreState.deliveries[DeliveryKey(token, listenerID)]
    if not delivery then
        return CoreError("DELIVERY_NOT_FOUND", "Reliable delivery was not found", {
            token = token,
            listenerID = listenerID,
        })
    end
    local duplicate = delivery.acked
    delivery.acked = true
    delivery.exhausted = false
    return { ok = true, duplicate = duplicate }
end

local function DefaultReliableProcessingLimit()
    local limit = #coreState.deliveryOrder
    if coreState.transactionActive then
        for _, emission in ipairs(coreState.transactionReliableEmits or {}) do
            limit = limit + #emission.listeners
        end
    end
    return limit
end

function Pro.ProcessReliableDeliveries(limit)
    if coreState.processingReliable then
        return CoreError("BUSY", "Reliable deliveries are already being processed")
    end
    if limit == nil then
        limit = DefaultReliableProcessingLimit()
    else
        limit = tonumber(limit)
        if not IsFiniteNumber(limit) then
            return CoreError("INVALID_LIMIT", "Reliable processing limit must be a finite number")
        end
        limit = math.floor(limit)
    end
    if limit < 0 then limit = 0 end
    if coreState.transactionActive then
        if not coreState.transactionReliableProcessing then
            coreState.transactionReliableLimit = limit
        else
            -- One epilogue pass honors the strictest processing budget requested in the transaction.
            coreState.transactionReliableLimit = math.min(coreState.transactionReliableLimit, limit)
        end
        coreState.transactionReliableProcessing = true
        return {
            ok = true,
            processed = 0,
            acknowledged = 0,
            deferred = true,
            limit = coreState.transactionReliableLimit,
        }
    end
    coreState.processingReliable = true
    local processed = 0
    local acknowledged = 0
    local ok, failure = pcall(function()
        for _, key in ipairs(coreState.deliveryOrder) do
            if processed >= limit then break end
            local delivery = coreState.deliveries[key]
            if delivery and not delivery.acked and not delivery.exhausted then
                processed = processed + 1
                delivery.attempts = delivery.attempts + 1
                local wasAcked = delivery.acked
                local listenerOK, result = pcall(
                    delivery.callback,
                    delivery.payload,
                    delivery.event,
                    delivery.token,
                    delivery.listenerID,
                    delivery.attempts
                )
                if listenerOK and result == true then
                    delivery.acked = true
                elseif not listenerOK then
                    coreState.listenerErrors = coreState.listenerErrors + 1
                    delivery.lastError = SafeErrorText(result)
                    RecordCoreDiagnostic("RELIABLE_LISTENER_ERROR", {
                        event = delivery.event,
                        token = delivery.token,
                        listenerID = delivery.listenerID,
                        attempt = delivery.attempts,
                        message = delivery.lastError,
                    })
                end
                if not wasAcked and delivery.acked then
                    acknowledged = acknowledged + 1
                end
                if not delivery.acked and delivery.attempts >= delivery.maxAttempts then
                    delivery.exhausted = true
                    RecordCoreDiagnostic("DELIVERY_RETRY_EXHAUSTED", {
                        event = delivery.event,
                        token = delivery.token,
                        listenerID = delivery.listenerID,
                        attempts = delivery.attempts,
                    })
                end
            end
        end
    end)
    coreState.processingReliable = false
    if not ok then
        local message = SafeErrorText(failure)
        RecordCoreDiagnostic("RELIABLE_PROCESSING_ERROR", { message = message })
        return CoreError("RELIABLE_PROCESSING_FAILED", "Reliable delivery processing failed", {
            detail = message,
        })
    end
    return { ok = true, processed = processed, acknowledged = acknowledged }
end

function Pro.IsDomainTransactionActive()
    return coreState.transactionActive
end

function Pro.RunDomainTransaction(callback)
    if type(callback) ~= "function" then
        return CoreError("INVALID_TRANSACTION", "Transaction callback is required")
    end
    if coreState.transactionActive then
        return CoreError("BUSY", "A domain transaction is already active")
    end

    coreState.transactionActive = true
    coreState.transactionEmits = {}
    coreState.transactionReliableEmits = {}
    coreState.transactionReliableByToken = {}
    coreState.transactionReliableProcessing = false
    coreState.transactionReliableLimit = nil
    local ok, result = pcall(callback)
    local deferred = coreState.transactionEmits
    local reliableEmissions = coreState.transactionReliableEmits
    local processReliable = coreState.transactionReliableProcessing
    local reliableLimit = coreState.transactionReliableLimit
    coreState.transactionEmits = nil
    coreState.transactionReliableEmits = nil
    coreState.transactionReliableByToken = nil
    coreState.transactionReliableProcessing = false
    coreState.transactionReliableLimit = nil
    coreState.transactionActive = false

    if not ok then
        local message = SafeErrorText(result)
        RecordCoreDiagnostic("TRANSACTION_ERROR", { message = message })
        return CoreError("TRANSACTION_FAILED", "Domain transaction failed", { detail = message })
    end
    if type(result) == "table" and result.ok == false then
        return result
    end

    if #coreState.emitQueue + #deferred > CORE_LIMITS.emitQueue then
        coreState.droppedEmits = coreState.droppedEmits + #deferred
        RecordCoreDiagnostic("TRANSACTION_EMIT_QUEUE_FULL", {
            queued = #coreState.emitQueue,
            required = #deferred,
        })
        return CoreError("EMIT_QUEUE_FULL", "Dispatcher queue cannot commit transaction callbacks", {
            queued = #coreState.emitQueue,
            required = #deferred,
        })
    end

    local requiredDeliveries = 0
    for _, emission in ipairs(reliableEmissions) do
        requiredDeliveries = requiredDeliveries + #emission.listeners
    end
    if #reliableEmissions > 0 and
            not MakeReliableCapacity(requiredDeliveries, #reliableEmissions) then
        RecordCoreDiagnostic("DELIVERY_QUEUE_FULL", {
            receipts = #reliableEmissions,
            deliveries = requiredDeliveries,
        })
        return CoreError("DELIVERY_QUEUE_FULL", "Reliable delivery queue cannot commit transaction receipts")
    end

    for _, emission in ipairs(deferred) do
        QueueEmit(emission.event, emission.payload)
    end
    for _, emission in ipairs(reliableEmissions) do
        StoreReliableEmission(emission)
    end
    local drained = DrainEmitQueue()
    if not drained.ok then
        return drained
    end
    if processReliable then
        local processed = Pro.ProcessReliableDeliveries(reliableLimit)
        if not processed.ok then
            return processed
        end
    end
    if result == nil then
        return { ok = true }
    end
    return result
end

function Pro.GetDispatcherDiagnostics()
    local deliveries = {}
    for _, key in ipairs(coreState.deliveryOrder) do
        local delivery = coreState.deliveries[key]
        if delivery then
            deliveries[#deliveries + 1] = {
                token = delivery.token,
                event = delivery.event,
                listenerID = delivery.listenerID,
                attempts = delivery.attempts,
                maxAttempts = delivery.maxAttempts,
                acked = delivery.acked,
                exhausted = delivery.exhausted,
                lastError = delivery.lastError,
            }
        end
    end
    local receipts = {}
    for _, token in ipairs(coreState.receiptOrder) do
        local receipt = coreState.receipts[token]
        if receipt then
            receipts[#receipts + 1] = {
                token = token,
                event = receipt.event,
                listenerCount = #receipt.deliveryKeys,
                terminal = ReceiptIsTerminal(receipt),
            }
        end
    end
    return {
        readiness = Pro.GetReadiness(),
        entries = SnapshotValue(coreState.diagnostics),
        deliveries = deliveries,
        receipts = receipts,
        listenerErrors = coreState.listenerErrors,
        droppedEmits = coreState.droppedEmits,
        queuedEmits = #coreState.emitQueue,
        transactionActive = coreState.transactionActive,
        limits = CopyTable(CORE_LIMITS),
    }
end

local function OperationMatches(operation, defaults)
    if type(operation) ~= "table" then
        return false
    end
    for key, value in pairs(defaults) do
        if operation[key] ~= value then
            return false
        end
    end
    return true
end

local function NormalizeAuctionOperation(operation, defaults)
    if type(operation) ~= "table" then
        return
    end
    defaults = defaults or {}
    for _, key in ipairs({ "minPricePct", "normalPricePct", "maxPricePct", "ignoreLowPricePct" }) do
        local value = tonumber(operation[key])
        if value and value > 10 then
            operation[key] = value / 100
        elseif value and value > 0 and value < 0.10 and tonumber(defaults[key]) and defaults[key] > 1 then
            operation[key] = value * 100
        end
    end
    for _, key in ipairs({ "minPriceFixed", "normalPriceFixed", "maxPriceFixed" }) do
        operation[key] = math.max(0, math.floor(tonumber(operation[key]) or 0))
    end
end

local function GetRuntimeRealmKey()
    if type(_G.GetRealmName) == "function" and type(_G.UnitFactionGroup) == "function" then
        local realm = _G.GetRealmName()
        local _, faction = _G.UnitFactionGroup("player")
        if realm and realm ~= "" then
            return realm .. "-" .. (faction or "Neutral")
        end
    end

    local redirect = _G.EasyAuctionDB
    if type(redirect) == "table" and type(redirect.realmKey) == "string" and redirect.realmKey ~= "" then
        return redirect.realmKey
    end
    return nil
end

function Pro.GetDB()
    local db = _G.EasyAuctionDB
    local db2 = _G.EasyAuctionDB2
    if type(db2) == "table" then
        local key = GetRuntimeRealmKey()
        local realmDB = key and db2[key] or nil
        if type(realmDB) == "table" then
            _G.EasyAuctionDB = realmDB
            return realmDB
        end

        if type(db) == "table" and type(db.realmKey) == "string" and type(db2[db.realmKey]) == "table" then
            _G.EasyAuctionDB = db2[db.realmKey]
            return _G.EasyAuctionDB
        end
    end

    if type(db) == "table" and not db.legacyRedirect then
        return db
    end

    return nil
end

local function TrimItemIdentifier(value)
    local text = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if #text >= 2 and text:sub(1, 1) == '"' and text:sub(-1) == '"' then
        text = text:sub(2, -2):gsub("^%s+", ""):gsub("%s+$", "")
    end
    return text
end

local function CachedItemName(itemID)
    if not GetItemInfo then return nil end
    return GetItemInfo(itemID)
end

local MAX_EXACT_INTEGER = 9007199254740991

local function IsPositiveInteger(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
        and value >= 1 and value <= MAX_EXACT_INTEGER and value == math.floor(value)
end

local function ExtractDirectItemID(text)
    local numericText = text:match("^([1-9]%d*)$")
    if numericText then return tonumber(numericText) end

    local itemText = text:match("^item:([1-9]%d*)$")
        or text:match("^item:([1-9]%d*):[%d:%-]+$")
    if itemText then return tonumber(itemText) end

    local linkText = text
    if linkText:match("^|c%x%x%x%x%x%x%x%x") and linkText:sub(-2) == "|r" then
        linkText = linkText:sub(11, -3)
    end
    local linkID = linkText:match("^|Hitem:([1-9]%d*)|h%[[^%]]*%]|h$")
        or linkText:match("^|Hitem:([1-9]%d*):[%d:%-]+|h%[[^%]]*%]|h$")
    return linkID and tonumber(linkID) or nil
end

function Pro.ResolveItemIdentifier(value)
    local text = TrimItemIdentifier(value)
    if text == "" then return nil end

    local itemID = ExtractDirectItemID(text)
    if IsPositiveInteger(itemID) then
        local itemName = CachedItemName(itemID) or text:match("%[([^%]]+)%]")
        return itemID, itemName or ("ID:" .. itemID)
    end
    if text:find("item:", 1, true) or text:find("|Hitem:", 1, true) then return nil end

    local normalized = string.lower(text)
    if GetItemInfo then
        local itemName, itemLink = GetItemInfo(text)
        local cachedID = itemLink and tonumber(itemLink:match("item:(%d+)")) or nil
        if IsPositiveInteger(cachedID) then
            return cachedID, itemName or text
        end
    end

    local numBrowse = GetNumAuctionItems and GetAuctionItemInfo and GetNumAuctionItems("list") or 0
    for index = 1, numBrowse do
        local itemName, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, browseID =
            GetAuctionItemInfo("list", index)
        browseID = tonumber(browseID)
        if itemName and IsPositiveInteger(browseID) and string.lower(itemName) == normalized then
            return browseID, itemName
        end
    end

    local db = Pro.GetDB()
    for favoriteID, info in pairs(db and db.FavoriteItems or {}) do
        local itemName = info and info.name
        favoriteID = tonumber(favoriteID)
        if itemName and IsPositiveInteger(favoriteID) and string.lower(itemName) == normalized then
            return favoriteID, itemName
        end
    end
    for key in pairs(db and db.PriceHistory or {}) do
        local itemName, historyID = string.match(key, "^(.-):(%d+)$")
        historyID = tonumber(historyID)
        if itemName and IsPositiveInteger(historyID) and string.lower(itemName) == normalized then
            return historyID, itemName
        end
    end

    return nil
end

function Pro.InitDB()
    local db = Pro.GetDB()
    if not db then
        return nil
    end

    db.Pro = db.Pro or {}
    local pro = db.Pro
    pro.version = 1
    pro.groups = pro.groups or {}
    pro.itemGroups = pro.itemGroups or {}
    pro.categoryGroups = pro.categoryGroups or {}
    pro.auctionOps = pro.auctionOps or {}
    pro.ledger = pro.ledger or {}
    pro.ledger.itemStats = pro.ledger.itemStats or {}
    pro.ledger.seenExpireKeys = pro.ledger.seenExpireKeys or {}
    pro.ledger.seenExpireOrder = pro.ledger.seenExpireOrder or {}
    pro.ledger.seenSoldKeys = pro.ledger.seenSoldKeys or {}
    pro.ledger.seenSoldOrder = pro.ledger.seenSoldOrder or {}
    pro.queue = pro.queue or {}

    if (pro.strategyRevision or 0) < 2 and
        OperationMatches(pro.auctionOps[DEFAULT_OPERATION_NAME], LEGACY_DEFAULT_OPERATION) then
        pro.auctionOps[DEFAULT_OPERATION_NAME] = CopyTable(DEFAULT_AUCTION_OPERATIONS[DEFAULT_OPERATION_NAME])
    end
    for _, operationName in ipairs(DEFAULT_OPERATION_ORDER) do
        local defaults = DEFAULT_AUCTION_OPERATIONS[operationName]
        pro.auctionOps[operationName] = CopyDefaults(pro.auctionOps[operationName], defaults)
        NormalizeAuctionOperation(pro.auctionOps[operationName], defaults)
    end
    for _, operation in pairs(pro.auctionOps) do
        NormalizeAuctionOperation(operation)
    end
    pro.strategyRevision = 2

    pro.groups[DEFAULT_GROUP_NAME] = pro.groups[DEFAULT_GROUP_NAME] or {
        items = {},
        auctionOp = DEFAULT_OPERATION_NAME,
    }

    if type(Pro.InitializeShoppingLists) == "function" then
        Pro.InitializeShoppingLists()
    end

    return db.Pro
end

function Pro.GetDefaultOperationTemplate(operationName)
    local template = DEFAULT_AUCTION_OPERATIONS[operationName or DEFAULT_OPERATION_NAME]
    if not template then
        return nil
    end
    return CopyTable(template)
end

function Pro.IsDefaultOperation(operationName)
    return DEFAULT_AUCTION_OPERATIONS[operationName or DEFAULT_OPERATION_NAME] ~= nil
end

function Pro.GetDefaultOperationNames()
    return DEFAULT_OPERATION_ORDER
end

function Pro.GetDefaultOperationName()
    return DEFAULT_OPERATION_NAME
end

function Pro.GetDefaultGroupName()
    return DEFAULT_GROUP_NAME
end

function Pro.FormatMoney(copper)
    if type(_G.FormatGoldIcon) == "function" then
        return _G.FormatGoldIcon(copper or 0, 12)
    end
    if type(_G.GetCoinTextureString) == "function" then
        return _G.GetCoinTextureString(copper or 0)
    end
    return tostring(copper or 0) .. "c"
end

function Pro.GetUIScale()
    local mainDB = _G.EasyAuctionDB
    local proDB = Pro.GetDB()
    local scale = mainDB and tonumber(mainDB.uiScale) or proDB and tonumber(proDB.uiScale) or 1
    if not scale or scale <= 0 then
        scale = 1
    end
    if scale < 0.50 then scale = 0.50 end
    if scale > 1.20 then scale = 1.20 end
    return scale
end

local function NormalizeUIScale(value)
    local scale = tonumber(value)
    if not scale or scale <= 0 then
        scale = 1
    end
    if scale < 0.50 then scale = 0.50 end
    if scale > 1.20 then scale = 1.20 end
    return scale
end

function Pro.ApplyFrameScale(frame, scaleOverride)
    if frame and frame.SetScale then
        local scale = NormalizeUIScale(scaleOverride or Pro.GetUIScale())
        local multiplier = tonumber(frame.EasyAuctionProScaleMultiplier) or 1
        if multiplier > 0 then
            scale = scale * multiplier
        end
        frame:SetScale(scale)
    end
end

local frameRaiseLevel = 80

function Pro.BringFrameToFront(frame, options)
    if not frame then return end
    options = type(options) == "table" and options or {}
    frameRaiseLevel = math.max(frameRaiseLevel + 2, tonumber(options.minLevel) or 80)
    frame:SetFrameStrata(options.strata or "FULLSCREEN_DIALOG")
    frame:SetFrameLevel(frameRaiseLevel)
    frame:SetToplevel(true)
end

function Pro.EnableClickToFront(frame, options)
    if not frame then return end
    frame.EasyAuctionProClickToFront = type(options) == "table" and options or frame.EasyAuctionProClickToFront or {}
    if frame.EasyAuctionProClickToFrontHooked then return end
    if frame.EnableMouse then frame:EnableMouse(true) end
    local function raise(self)
        local clickOptions = self.EasyAuctionProClickToFront or {}
        Pro.BringFrameToFront(clickOptions.targetFrame or self, clickOptions)
    end
    if frame.HookScript then
        frame:HookScript("OnMouseDown", raise)
    else
        frame:SetScript("OnMouseDown", raise)
    end
    frame.EasyAuctionProClickToFrontHooked = true
end

local function IsInteractiveControl(frame)
    if not frame then return true end
    local objectType = frame.GetObjectType and frame:GetObjectType() or nil
    if objectType == "Button" or objectType == "CheckButton" or objectType == "EditBox" or objectType == "Slider" then
        return true
    end
    if frame.GetScript and type(frame:GetScript("OnClick")) == "function" then
        return true
    end
    return false
end

function Pro.EnableClickToFrontTree(frame, options, depth)
    if not frame then return end
    options = type(options) == "table" and options or {}
    local treeOptions = {}
    for key, value in pairs(options) do treeOptions[key] = value end
    treeOptions.targetFrame = treeOptions.targetFrame or frame
    Pro.EnableClickToFront(frame, treeOptions)
    depth = tonumber(depth) or 1
    if depth <= 0 or type(frame.GetChildren) ~= "function" then
        return
    end
    local children = { frame:GetChildren() }
    for _, child in ipairs(children) do
        if child and child.HookScript and not IsInteractiveControl(child) then
            Pro.EnableClickToFront(child, treeOptions)
            Pro.EnableClickToFrontTree(child, treeOptions, depth - 1)
        end
    end
end

function Pro.EnableKnownEasyAuctionClickToFront()
    local topFrames = {
        _G.EasyAuctionConfigFrame,
        _G.EasyAuctionDBFrame,
        _G.EasyAuctionPriceFrame,
        _G.AuctionHelper,
        _G.AuctionBar and _G.AuctionBar.AuctionFrame,
    }
    for _, frame in ipairs(topFrames) do
        if frame then
            Pro.EnableClickToFront(frame, { strata = "FULLSCREEN_DIALOG", minLevel = 80 })
        end
    end

    local mainContentFrames = {
        _G.AuctionBar and _G.AuctionBar.AuctionFrame and _G.AuctionBar.AuctionFrame.ItemsFrame,
        _G.AuctionBar and _G.AuctionBar.AuctionFrame and _G.AuctionBar.AuctionFrame.MyAuctionListFrame,
    }
    for _, frame in ipairs(mainContentFrames) do
        if frame then
            Pro.EnableClickToFrontTree(frame, { strata = "FULLSCREEN_DIALOG", minLevel = 80 }, 2)
        end
    end
end

function Pro.RaiseMainFrame(frame)
    Pro.EnableKnownEasyAuctionClickToFront()
    Pro.EnableClickToFront(frame, { strata = "FULLSCREEN_DIALOG", minLevel = 80 })
    Pro.BringFrameToFront(frame, { strata = "FULLSCREEN_DIALOG", minLevel = 80 })
end

function Pro.RaiseHelpFrame(frame)
    Pro.EnableKnownEasyAuctionClickToFront()
    Pro.EnableClickToFront(frame, { strata = "FULLSCREEN_DIALOG", minLevel = 90 })
    Pro.BringFrameToFront(frame, { strata = "FULLSCREEN_DIALOG", minLevel = 90 })
end

function Pro.RaiseChildDialog(frame, owner)
    if not frame then return end
    Pro.EnableKnownEasyAuctionClickToFront()
    Pro.EnableClickToFront(frame, { strata = "FULLSCREEN_DIALOG", minLevel = 85 })
    local ownerLevel = owner and owner.GetFrameLevel and tonumber(owner:GetFrameLevel()) or nil
    local minLevel = ownerLevel and (ownerLevel + 4) or 85
    Pro.BringFrameToFront(frame, { strata = "FULLSCREEN_DIALOG", minLevel = minLevel })
end

function Pro.ApplyAllFrameScale(scaleOverride)
    Pro.EnableKnownEasyAuctionClickToFront()
    local scale = NormalizeUIScale(scaleOverride or Pro.GetUIScale())
    Pro.ApplyFrameScale(Pro.strategyFrame, scale)
    Pro.ApplyFrameScale(Pro.queueFrame, scale)
    Pro.ApplyFrameScale(Pro.maintenanceFrame, scale)
    Pro.ApplyFrameScale(Pro.buyFrame, scale)
    Pro.ApplyFrameScale(Pro.shoppingTextDialog, scale)
    Pro.ApplyFrameScale(Pro.shoppingNotebookDialog, scale)
    Pro.ApplyFrameScale(Pro.helpFrame, scale)
    return { ok = true, scale = scale }
end

function Pro.GetStyle()
    return _G.EAStyle or _G.EasyAuctionStyle
end

function Pro.SkinFrame(frame, role)
    local style = Pro.GetStyle()
    if style and style.Skin then
        style:Skin(frame, role or "panel")
    elseif frame and frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        frame:SetBackdropColor(0.08, 0.08, 0.10, 0.98)
        frame:SetBackdropBorderColor(0.25, 0.25, 0.30, 1)
    end
    return frame
end

function Pro.SkinButton(button, active)
    local style = Pro.GetStyle()
    if style and style.SkinButton then
        style:SkinButton(button)
        if style.SetButtonActive then
            style:SetButtonActive(button, active and true or false)
        end
    end
    return button
end

function Pro.SetButtonActive(button, active)
    local style = Pro.GetStyle()
    if style and style.SetButtonActive then
        style:SetButtonActive(button, active and true or false)
    elseif button and button.SetBackdropBorderColor then
        if active then
            button:SetBackdropBorderColor(0.06, 0.72, 0.83, 1)
        else
            button:SetBackdropBorderColor(0.25, 0.25, 0.30, 1)
        end
    end
end

function Pro.SkinEditBox(edit)
    if not edit then return edit end
    local style = Pro.GetStyle()
    local palette = style and style.Palette and style:Palette() or nil
    if not (palette and palette.blizzard) then
        local regions = { edit:GetRegions() }
        for i = 1, #regions do
            local region = regions[i]
            if region and region.GetObjectType and region:GetObjectType() == "Texture" then
                region:SetTexture(nil)
                region:SetAlpha(0)
                region:Hide()
            end
        end
        local name = edit.GetName and edit:GetName() or nil
        if name then
            for _, suffix in ipairs({ "Left", "Middle", "Right", "LeftTexture", "MiddleTexture", "RightTexture" }) do
                local tex = _G[name .. suffix]
                if tex and tex.SetTexture then
                    tex:SetTexture(nil)
                    tex:SetAlpha(0)
                    tex:Hide()
                end
            end
        end
    end
    if style and style.SkinEditBox then
        style:SkinEditBox(edit)
    end
    return edit
end

function Pro.SkinText(fontString, role, size)
    if not fontString then return fontString end
    local style = Pro.GetStyle()
    role = role or "text"
    size = size or 12
    if style and style.Font and fontString.SetFont then
        fontString:SetFont(style.Font, size, "")
        fontString:SetShadowOffset(1, -1)
    elseif fontString.SetFont then
        fontString:SetFont(_G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, "")
        fontString:SetShadowOffset(1, -1)
    end
    if style and style.SkinText and
        (fontString.EasyAuctionProTextRole ~= role or fontString.EasyAuctionProTextSize ~= size) then
        fontString.EasyAuctionProTextRole = role
        fontString.EasyAuctionProTextSize = size
        style:SkinText(fontString, role)
    end
    return fontString
end

function Pro.CreateCloseButton(parent)
    local style = Pro.GetStyle()
    local button
    if style and style.CloseButton then
        button = style:CloseButton(parent)
    else
        button = CreateFrame("Button", nil, parent, "UIPanelCloseButton")
    end
    button:SetScript("OnClick", function()
        if parent then
            parent:Hide()
        end
    end)
    return button
end

function Pro.SkinHeader(frame)
    if not frame then return frame end
    Pro.SkinFrame(frame, "panel")
    local style = Pro.GetStyle()
    if style and style.Palette and not frame.EasyAuctionProHeaderTheme then
        frame.EasyAuctionProHeaderTheme = true
        style:OnTheme(function(p)
            if frame.SetBackdropColor then
                frame:SetBackdropColor(p.plot[1], p.plot[2], p.plot[3], 0.78)
                frame:SetBackdropBorderColor(p.border[1], p.border[2], p.border[3], 0.9)
            end
        end)
    end
    return frame
end

function Pro.SkinRow(row, index)
    if not row then return row end
    Pro.SkinFrame(row, "panel")
    local style = Pro.GetStyle()
    if style and style.Palette and not row.EasyAuctionProRowTheme then
        row.EasyAuctionProRowTheme = true
        style:OnTheme(function(p)
            if row.SetBackdropColor then
                local alpha = (index and index % 2 == 0) and 0.62 or 0.46
                row:SetBackdropColor(p.panel[1], p.panel[2], p.panel[3], alpha)
                row:SetBackdropBorderColor(p.border[1], p.border[2], p.border[3], 0.45)
            end
        end)
    end
    return row
end

local function ProEnsureBorder(frame)
    if not frame or frame.EasyAuctionProBorder then return end
    local border = {}
    border.top = frame:CreateTexture(nil, "OVERLAY")
    border.top:SetHeight(1)
    border.top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    border.top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    border.bottom = frame:CreateTexture(nil, "OVERLAY")
    border.bottom:SetHeight(1)
    border.bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    border.bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    border.left = frame:CreateTexture(nil, "OVERLAY")
    border.left:SetWidth(1)
    border.left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    border.left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    border.right = frame:CreateTexture(nil, "OVERLAY")
    border.right:SetWidth(1)
    border.right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    border.right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    for _, tex in pairs(border) do
        tex:SetTexture("Interface\\Buttons\\WHITE8X8")
    end
    frame.EasyAuctionProBorder = border
end

local function ProSetBorderColor(frame, color, alpha)
    if not frame or not frame.EasyAuctionProBorder or not color then return end
    for _, tex in pairs(frame.EasyAuctionProBorder) do
        tex:SetColorTexture(color[1], color[2], color[3], alpha or 1)
        tex:SetAlpha(alpha or 1)
        tex:Show()
    end
end

local function ProHideBorder(frame)
    if not frame or not frame.EasyAuctionProBorder then return end
    for _, tex in pairs(frame.EasyAuctionProBorder) do
        tex:SetAlpha(0)
        tex:Hide()
    end
end

local function ProShowTexture(tex, file)
    if not tex then return end
    if file then
        tex:SetTexture(file)
    end
    tex:SetAlpha(1)
    tex:Show()
end

local function ProHideTexture(tex)
    if not tex then return end
    tex:SetAlpha(0)
    tex:Hide()
end

local function ProSetDropDownPiece(tex, left, right)
    if not tex then return end
    tex:SetTexture("Interface\\Glues\\CharacterCreate\\CharacterCreate-LabelFrame")
    tex:SetTexCoord(left, right, 0, 1)
    tex:SetAlpha(1)
    tex:Show()
end

local function ProRestoreBlizzardDropDown(dropdown)
    if not dropdown then return end
    local name = dropdown.GetName and dropdown:GetName() or nil
    local left = dropdown.Left or (name and _G[name .. "Left"])
    local middle = dropdown.Middle or (name and _G[name .. "Middle"])
    local right = dropdown.Right or (name and _G[name .. "Right"])
    if left and middle and right then
        ProSetDropDownPiece(left, 0, 0.1953125)
        ProSetDropDownPiece(middle, 0.1953125, 0.8046875)
        ProSetDropDownPiece(right, 0.8046875, 1)
        local w = dropdown.GetWidth and dropdown:GetWidth() or 165
        middle:SetWidth(math.max((w or 165) - 50, 40))
    end
    if dropdown.SetBackdrop then
        dropdown:SetBackdrop(nil)
    end
    if dropdown.EasyAuctionProFill then ProHideTexture(dropdown.EasyAuctionProFill) end
    if dropdown.EasyAuctionProButtonDivider then ProHideTexture(dropdown.EasyAuctionProButtonDivider) end
    ProHideBorder(dropdown)

    local text = name and _G[name .. "Text"]
    if text then
        text:ClearAllPoints()
        text:SetPoint("RIGHT", right or dropdown, "RIGHT", right and -43 or -40, 2)
        text:SetJustifyH("RIGHT")
        Pro.SkinText(text, "text", 12)
    end

    local button = name and _G[name .. "Button"]
    if button then
        button:ClearAllPoints()
        if right then
            button:SetPoint("TOPRIGHT", right, "TOPRIGHT", -16, -18)
        else
            button:SetPoint("RIGHT", dropdown, "RIGHT", -16, 0)
        end
        button:SetSize(24, 24)
        ProShowTexture(
            button.GetNormalTexture and button:GetNormalTexture(),
            "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up"
        )
        ProShowTexture(
            button.GetPushedTexture and button:GetPushedTexture(),
            "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down"
        )
        ProShowTexture(
            button.GetDisabledTexture and button:GetDisabledTexture(),
            "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Disabled"
        )
        if button.SetHighlightTexture then
            button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        end
        ProShowTexture(button.GetHighlightTexture and button:GetHighlightTexture())
        if button.EasyAuctionProArrow then button.EasyAuctionProArrow:Hide() end
        if button.EasyAuctionProHover then ProHideTexture(button.EasyAuctionProHover) end
    end
end

local function ProHookBlizzardDropDownTheme(dropdown)
    local style = Pro.GetStyle()
    if style and style.OnTheme and not dropdown.EasyAuctionProDropDownTheme then
        dropdown.EasyAuctionProDropDownTheme = true
        style:OnTheme(function()
            if Pro.ReskinDropDown then
                Pro.ReskinDropDown(dropdown)
            end
        end)
    end
end

function Pro.SkinDropDown(dropdown)
    if not dropdown then return dropdown end
    local name = dropdown.GetName and dropdown:GetName() or nil
    local style = Pro.GetStyle()
    local palette = style and style.Palette and style:Palette() or nil
    if dropdown.EasyAuctionProVisualWidth then
        dropdown:SetWidth(dropdown.EasyAuctionProVisualWidth)
    end
    dropdown:SetHeight(22)
    if palette and palette.blizzard then
        ProRestoreBlizzardDropDown(dropdown)
        ProHookBlizzardDropDownTheme(dropdown)
        return dropdown
    end
    if name then
        for _, suffix in ipairs({
            "Left", "Middle", "Right", "Text", "Button",
            "ButtonNormalTexture", "ButtonPushedTexture", "ButtonDisabledTexture",
        }) do
            local region = _G[name .. suffix]
            if region and region.GetObjectType and region:GetObjectType() == "Texture" then
                region:SetTexture(nil)
                region:SetAlpha(0)
                region:Hide()
            end
        end
    end
    local regions = { dropdown:GetRegions() }
    for i = 1, #regions do
        local region = regions[i]
        if region and region.GetObjectType and region:GetObjectType() == "Texture" then
            region:SetTexture(nil)
            region:SetAlpha(0)
            region:Hide()
        end
    end
    Pro.SkinFrame(dropdown, "plot")
    ProEnsureBorder(dropdown)
    if not dropdown.EasyAuctionProFill then
        local fill = dropdown:CreateTexture(nil, "BACKGROUND")
        fill:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 1, -1)
        fill:SetPoint("BOTTOMRIGHT", dropdown, "BOTTOMRIGHT", -1, 1)
        dropdown.EasyAuctionProFill = fill
    else
        dropdown.EasyAuctionProFill:SetAlpha(1)
        dropdown.EasyAuctionProFill:Show()
    end
    if not dropdown.EasyAuctionProButtonDivider then
        local divider = dropdown:CreateTexture(nil, "ARTWORK")
        divider:SetWidth(1)
        divider:SetPoint("TOPRIGHT", dropdown, "TOPRIGHT", -25, -4)
        divider:SetPoint("BOTTOMRIGHT", dropdown, "BOTTOMRIGHT", -25, 4)
        dropdown.EasyAuctionProButtonDivider = divider
    else
        dropdown.EasyAuctionProButtonDivider:SetAlpha(1)
        dropdown.EasyAuctionProButtonDivider:Show()
    end
    if name and _G[name .. "Text"] then
        local text = _G[name .. "Text"]
        text:ClearAllPoints()
        text:SetPoint("LEFT", dropdown, "LEFT", 10, 0)
        text:SetPoint("RIGHT", dropdown, "RIGHT", -32, 0)
        text:SetJustifyH("LEFT")
        Pro.SkinText(text, "text", 12)
    end
    local button = name and _G[name .. "Button"]
    if button then
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 0, 0)
        button:SetPoint("BOTTOMRIGHT", dropdown, "BOTTOMRIGHT", 0, 0)
        for _, tex in ipairs({
            button.GetNormalTexture and button:GetNormalTexture(),
            button.GetPushedTexture and button:GetPushedTexture(),
            button.GetDisabledTexture and button:GetDisabledTexture(),
            button.GetHighlightTexture and button:GetHighlightTexture(),
        }) do
            if tex and tex.SetTexture then
                tex:SetTexture(nil)
                tex:SetAlpha(0)
                tex:Hide()
            end
        end
        if not button.EasyAuctionProArrow then
            local arrow = button:CreateFontString(nil, "OVERLAY")
            arrow:SetPoint("RIGHT", dropdown, "RIGHT", -8, 0)
            Pro.SkinText(arrow, "accent", 11)
            arrow:SetText("v")
            button.EasyAuctionProArrow = arrow
        end
        button.EasyAuctionProArrow:ClearAllPoints()
        button.EasyAuctionProArrow:SetPoint("RIGHT", dropdown, "RIGHT", -8, 0)
        Pro.SkinText(button.EasyAuctionProArrow, "accent", 11)
        if not button.EasyAuctionProHover then
            local hover = button:CreateTexture(nil, "HIGHLIGHT")
            hover:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 1, -1)
            hover:SetPoint("BOTTOMRIGHT", dropdown, "BOTTOMRIGHT", -1, 1)
            button:SetHighlightTexture(hover)
            button.EasyAuctionProHover = hover
        else
            button.EasyAuctionProHover:Show()
        end
    end
    style = Pro.GetStyle()
    palette = style and style.Palette and style:Palette() or nil
    if palette then
        ProSetBorderColor(dropdown, palette.border, 1)
    end
    if style and style.Palette and not dropdown.EasyAuctionProDropDownTheme then
        dropdown.EasyAuctionProDropDownTheme = true
        style:OnTheme(function(p)
            if dropdown.SetBackdropColor then
                dropdown:SetBackdropColor(p.plot[1], p.plot[2], p.plot[3], 0.98)
                dropdown:SetBackdropBorderColor(p.border[1], p.border[2], p.border[3], 1)
            end
            if dropdown.EasyAuctionProFill then
                dropdown.EasyAuctionProFill:SetColorTexture(p.plot[1], p.plot[2], p.plot[3], 0.98)
            end
            if dropdown.EasyAuctionProButtonDivider then
                dropdown.EasyAuctionProButtonDivider:SetColorTexture(p.border[1], p.border[2], p.border[3], 0.85)
            end
            if button and button.EasyAuctionProHover then
                button.EasyAuctionProHover:SetColorTexture(p.accent[1], p.accent[2], p.accent[3], 0.12)
            end
            ProSetBorderColor(dropdown, p.border, 1)
            if button and button.EasyAuctionProArrow then
                button.EasyAuctionProArrow:SetTextColor(p.accent[1], p.accent[2], p.accent[3], 1)
            end
        end)
    end
    return dropdown
end

function Pro.ReskinDropDown(dropdown)
    if not dropdown then return end
    local name = dropdown.GetName and dropdown:GetName() or nil
    local style = Pro.GetStyle()
    local palette = style and style.Palette and style:Palette() or nil
    if dropdown.EasyAuctionProVisualWidth then
        dropdown:SetWidth(dropdown.EasyAuctionProVisualWidth)
    end
    dropdown:SetHeight(22)
    if palette and palette.blizzard then
        ProRestoreBlizzardDropDown(dropdown)
        return
    end
    if name and _G[name .. "Text"] then
        local text = _G[name .. "Text"]
        text:ClearAllPoints()
        text:SetPoint("LEFT", dropdown, "LEFT", 10, 0)
        text:SetPoint("RIGHT", dropdown, "RIGHT", -32, 0)
        text:SetJustifyH("LEFT")
        Pro.SkinText(text, "text", 12)
    end
    local button = name and _G[name .. "Button"]
    if button then
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 0, 0)
        button:SetPoint("BOTTOMRIGHT", dropdown, "BOTTOMRIGHT", 0, 0)
        if button.EasyAuctionProArrow then
            button.EasyAuctionProArrow:ClearAllPoints()
            button.EasyAuctionProArrow:SetPoint("RIGHT", dropdown, "RIGHT", -8, 0)
        end
        for _, tex in ipairs({
            button.GetNormalTexture and button:GetNormalTexture(),
            button.GetPushedTexture and button:GetPushedTexture(),
            button.GetDisabledTexture and button:GetDisabledTexture(),
        }) do
            if tex and tex.SetTexture then
                tex:SetTexture(nil)
                tex:SetAlpha(0)
                tex:Hide()
            end
        end
    end
    if dropdown.EasyAuctionProFill then
        dropdown.EasyAuctionProFill:SetAlpha(1)
        dropdown.EasyAuctionProFill:Show()
    end
    if dropdown.EasyAuctionProButtonDivider then
        dropdown.EasyAuctionProButtonDivider:SetAlpha(1)
        dropdown.EasyAuctionProButtonDivider:Show()
    end
    style = Pro.GetStyle()
    palette = style and style.Palette and style:Palette() or nil
    if palette then
        if dropdown.SetBackdropColor then
            dropdown:SetBackdropColor(palette.plot[1], palette.plot[2], palette.plot[3], 0.98)
            dropdown:SetBackdropBorderColor(palette.border[1], palette.border[2], palette.border[3], 1)
        end
        if dropdown.EasyAuctionProFill then
            dropdown.EasyAuctionProFill:SetColorTexture(palette.plot[1], palette.plot[2], palette.plot[3], 0.98)
        end
        if dropdown.EasyAuctionProButtonDivider then
            dropdown.EasyAuctionProButtonDivider:SetColorTexture(
                palette.border[1], palette.border[2], palette.border[3], 0.85
            )
        end
        if button and button.EasyAuctionProHover then
            button.EasyAuctionProHover:SetColorTexture(palette.accent[1], palette.accent[2], palette.accent[3], 0.12)
        end
        if button and button.EasyAuctionProArrow then
            button.EasyAuctionProArrow:SetTextColor(palette.accent[1], palette.accent[2], palette.accent[3], 1)
        end
        ProSetBorderColor(dropdown, palette.border, 1)
    end
end

function Pro.SkinDropDownMenu(level, owner)
    level = level or 1
    local listName = "DropDownList" .. level
    local list = _G[listName]
    if not list then return end
    local style = Pro.GetStyle()
    local palette = style and style.Palette and style:Palette() or nil
    if palette and palette.blizzard then
        if list.EasyAuctionProMenuFill then ProHideTexture(list.EasyAuctionProMenuFill) end
        ProHideBorder(list)
        if list.SetBackdrop then
            list:SetBackdrop({
                bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
                edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                tile = true,
                tileSize = 32,
                edgeSize = 32,
                insets = { left = 11, right = 12, top = 12, bottom = 11 },
            })
            list:SetBackdropColor(1, 1, 1, 1)
            list:SetBackdropBorderColor(1, 1, 1, 1)
        end
        for _, frame in ipairs({
            _G[listName .. "Backdrop"],
            _G[listName .. "MenuBackdrop"],
        }) do
            if frame and frame.SetBackdrop then
                frame:SetBackdrop({
                    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
                    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                    tile = true,
                    tileSize = 32,
                    edgeSize = 32,
                    insets = { left = 11, right = 12, top = 12, bottom = 11 },
                })
                frame:SetBackdropColor(1, 1, 1, 1)
                frame:SetBackdropBorderColor(1, 1, 1, 1)
            end
        end
        local count = list.numButtons or 0
        for i = 1, count do
            local button = _G[listName .. "Button" .. i]
            if button then
                if button.EasyAuctionProHighlight then ProHideTexture(button.EasyAuctionProHighlight) end
                local text = _G[listName .. "Button" .. i .. "NormalText"] or
                    (button.GetFontString and button:GetFontString())
                if text then
                    text:ClearAllPoints()
                    text:SetPoint("LEFT", button, "LEFT", -5, 0)
                    text:SetJustifyH("LEFT")
                    Pro.SkinText(text, "text", 12)
                end
            end
        end
        if owner then
            ProRestoreBlizzardDropDown(owner)
        end
        return
    end
    local function HideFrameTextures(frame)
        if not frame or not frame.GetRegions then return end
        local regions = { frame:GetRegions() }
        for i = 1, #regions do
            local region = regions[i]
            if region and region.GetObjectType and region:GetObjectType() == "Texture" then
                region:SetTexture(nil)
                region:SetAlpha(0)
                region:Hide()
            end
        end
    end

    HideFrameTextures(list)
    Pro.SkinFrame(list, "plot")
    ProEnsureBorder(list)
    if not list.EasyAuctionProMenuFill then
        local fill = list:CreateTexture(nil, "BACKGROUND")
        fill:SetPoint("TOPLEFT", list, "TOPLEFT", 1, -1)
        fill:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", -1, 1)
        list.EasyAuctionProMenuFill = fill
    else
        list.EasyAuctionProMenuFill:SetAlpha(1)
        list.EasyAuctionProMenuFill:Show()
    end
    if owner and owner.GetWidth and list.SetWidth then
        list:SetWidth(owner:GetWidth())
    end
    for _, frame in ipairs({
        _G[listName .. "Backdrop"],
        _G[listName .. "MenuBackdrop"],
    }) do
        if frame then
            HideFrameTextures(frame)
            Pro.SkinFrame(frame, "plot")
        end
    end

    style = Pro.GetStyle()
    palette = style and style.Palette and style:Palette() or nil
    local count = list.numButtons or 0
    local function HideRegion(region)
        if region then
            region:SetAlpha(0)
            region:Hide()
        end
    end
    for i = 1, count do
        local button = _G[listName .. "Button" .. i]
        if button then
            HideRegion(button.check)
            HideRegion(button.unCheck)
            HideRegion(_G[listName .. "Button" .. i .. "Check"])
            HideRegion(_G[listName .. "Button" .. i .. "UnCheck"])
            HideRegion(_G[listName .. "Button" .. i .. "Icon"])
            local text = _G[listName .. "Button" .. i .. "NormalText"] or
                (button.GetFontString and button:GetFontString())
            Pro.SkinText(text, "text", 12)
            if text then
                text:ClearAllPoints()
                text:SetPoint("LEFT", button, "LEFT", 8, 0)
                text:SetPoint("RIGHT", button, "RIGHT", -8, 0)
                text:SetJustifyH("LEFT")
            end
            if button.SetHeight then
                button:SetHeight(20)
            end
            if palette and button.SetHighlightTexture and not button.EasyAuctionProHighlight then
                local highlight = button:CreateTexture(nil, "HIGHLIGHT")
                highlight:SetTexture("Interface\\Buttons\\WHITE8X8")
                highlight:SetAllPoints(button)
                highlight:SetColorTexture(palette.accent[1], palette.accent[2], palette.accent[3], 0.16)
                button:SetHighlightTexture(highlight)
                button.EasyAuctionProHighlight = highlight
            elseif palette and button.EasyAuctionProHighlight then
                button.EasyAuctionProHighlight:SetColorTexture(
                    palette.accent[1], palette.accent[2], palette.accent[3], 0.16
                )
            end
        end
    end

    if palette then
        if list.EasyAuctionProMenuFill then
            list.EasyAuctionProMenuFill:SetColorTexture(palette.plot[1], palette.plot[2], palette.plot[3], 0.98)
        end
        if list.SetBackdropColor then
            list:SetBackdropColor(palette.plot[1], palette.plot[2], palette.plot[3], 0.98)
            list:SetBackdropBorderColor(palette.border[1], palette.border[2], palette.border[3], 1)
        end
        ProSetBorderColor(list, palette.border, 1)
    end
    if owner and Pro.ReskinDropDown then
        Pro.ReskinDropDown(owner)
        local timer = _G.C_Timer
        if timer and timer.After then
            timer.After(0, function()
                Pro.ReskinDropDown(owner)
            end)
        end
    end
end

function _G.EasyAuctionPro_InitDB()
    return Pro.InitDB()
end

function _G.EasyAuctionPro_GetShoppingPriceEstimate(itemID, itemName, now, options)
    return Pro.GetShoppingPriceEstimate(itemID, itemName, now, options)
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, loadedAddon)
    if event == "ADDON_LOADED" and loadedAddon ~= addonName then
        return
    end
    if Pro.InitDB() then
        self:UnregisterEvent("ADDON_LOADED")
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)
