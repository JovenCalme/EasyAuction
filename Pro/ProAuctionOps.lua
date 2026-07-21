local _, ns = ...

local Pro = ns.EasyAuctionPro
if not Pro then return end

local function ClampNumber(value, defaultValue, minValue, maxValue)
    local n = tonumber(value)
    if n == nil then n = defaultValue end
    if minValue and n < minValue then n = minValue end
    if maxValue and n > maxValue then n = maxValue end
    return n
end

local function ClampInt(value, defaultValue, minValue, maxValue)
    return math.floor(ClampNumber(value, defaultValue, minValue, maxValue))
end

local function GetItemKey(itemID, itemName)
    itemID = tonumber(itemID)
    if itemName and itemID then
        return itemName .. ":" .. itemID
    end
    return itemName
end

local function HasPriceData(db)
    if type(db) ~= "table" then
        return false
    end
    return (type(db.PriceHistory) == "table" and next(db.PriceHistory) ~= nil) or
        (type(db.DailyMinPrice) == "table" and next(db.DailyMinPrice) ~= nil)
end

local function AddCandidate(candidates, seen, db)
    if type(db) ~= "table" or seen[db] then
        return
    end
    seen[db] = true
    candidates[#candidates + 1] = db
end

local function GetPriceDBCandidates()
    local candidates = {}
    local seen = {}
    local primary = Pro.GetDB()
    AddCandidate(candidates, seen, primary)

    if HasPriceData(primary) then
        return candidates
    end

    local db2 = _G.EasyAuctionDB2
    if type(db2) ~= "table" then
        return candidates
    end

    local keys = {}
    for key, realmDB in pairs(db2) do
        if type(key) == "string" and type(realmDB) == "table" and HasPriceData(realmDB) then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys)
    for _, key in ipairs(keys) do
        AddCandidate(candidates, seen, db2[key])
    end
    return candidates
end

local function GetFallbackKeysByItemID(db, itemID)
    local keys = {}
    itemID = tonumber(itemID)
    if not db or not itemID then
        return keys
    end

    local index = _G.EasyAuction_ItemID_Index
    local entries = index and index[itemID]
    if type(entries) == "table" then
        table.sort(entries, function(a, b)
            return (tonumber(a and a.minUnit) or 0) < (tonumber(b and b.minUnit) or 0)
        end)
        for _, entry in ipairs(entries) do
            if entry and entry.key then
                keys[#keys + 1] = entry.key
            end
        end
    end

    if #keys == 0 and type(db.PriceHistory) == "table" then
        local suffix = ":" .. tostring(itemID)
        for key in pairs(db.PriceHistory) do
            if type(key) == "string" and key:sub(-#suffix) == suffix then
                keys[#keys + 1] = key
            end
        end
        table.sort(keys)
    end
    return keys
end

local function GetHistory(itemID, itemName)
    local key = GetItemKey(itemID, itemName)
    if not key then
        return nil, key
    end
    for _, db in ipairs(GetPriceDBCandidates()) do
        if type(_G.EasyAuction_GetPriceHistory) == "function" then
            local history = _G.EasyAuction_GetPriceHistory(key, db)
            if type(history) == "table" and (#history > 0 or history.minUnit or history.records) then
                return history, key
            end
            for _, fallbackKey in ipairs(GetFallbackKeysByItemID(db, itemID)) do
                history = _G.EasyAuction_GetPriceHistory(fallbackKey, db)
                if type(history) == "table" and (#history > 0 or history.minUnit or history.records) then
                    return history, fallbackKey
                end
            end
        end
        if type(db.PriceHistory) == "table" then
            local raw = db.PriceHistory[key]
            if raw then
                return raw, key
            end
            for _, fallbackKey in ipairs(GetFallbackKeysByItemID(db, itemID)) do
                if db.PriceHistory[fallbackKey] then
                    return db.PriceHistory[fallbackKey], fallbackKey
                end
            end
        end
    end
    return nil, key
end

local function GetDaily(itemID, itemName)
    local key = GetItemKey(itemID, itemName)
    if not key then
        return nil
    end
    for _, db in ipairs(GetPriceDBCandidates()) do
        if type(_G.EasyAuction_GetDailyMinPrice) == "function" then
            local daily = _G.EasyAuction_GetDailyMinPrice(key, db)
            if type(daily) == "table" and #daily > 0 then
                return daily
            end
            for _, fallbackKey in ipairs(GetFallbackKeysByItemID(db, itemID)) do
                daily = _G.EasyAuction_GetDailyMinPrice(fallbackKey, db)
                if type(daily) == "table" and #daily > 0 then
                    return daily
                end
            end
        end
        if type(db.DailyMinPrice) == "table" then
            local raw = db.DailyMinPrice[key]
            if raw then
                return raw
            end
            for _, fallbackKey in ipairs(GetFallbackKeysByItemID(db, itemID)) do
                if db.DailyMinPrice[fallbackKey] then
                    return db.DailyMinPrice[fallbackKey]
                end
            end
        end
    end
    return nil
end

local HISTORY_FRESH_SECONDS = 24 * 60 * 60

local function NormalizeHistoryRecord(row, fallbackTime)
    if type(row) ~= "table" then
        return nil
    end
    local unit = tonumber(row.unit or row[2] or row.price or row.minUnit)
    if not unit or unit <= 0 then
        return nil
    end
    local count = tonumber(row.count or row[3]) or 1
    if count < 1 then
        count = 1
    end
    local observedAt = tonumber(row.time or row[1] or row.timestamp or row.observedAt or row.updatedAt or row.lastUpdated)
    if not observedAt and fallbackTime then
        observedAt = fallbackTime
    end
    return {
        unit = math.floor(unit + 0.5),
        count = math.floor(count + 0.5),
        time = observedAt,
    }
end

local function SelectHistoryRecord(history)
    if type(history) ~= "table" then
        return nil, nil, 0
    end
    local rows = type(history.records) == "table" and history.records or history
    local fallbackTime = tonumber(history.updatedAt or history.lastUpdated or history.time or history.timestamp or history.observedAt)
    local freshest, cheapest, seen = nil, nil, 0
    for _, row in ipairs(rows) do
        local entry = NormalizeHistoryRecord(row, fallbackTime)
        if entry then
            seen = seen + 1
            if not cheapest or entry.unit < cheapest.unit
                    or (entry.unit == cheapest.unit and entry.time and (not cheapest.time or entry.time > cheapest.time)) then
                cheapest = entry
            end
            if entry.time ~= nil then
                if not freshest or freshest.time == nil or entry.time > freshest.time
                        or (entry.time == freshest.time and entry.unit < freshest.unit) then
                    freshest = entry
                end
            end
        end
    end
    if not freshest and not cheapest then
        local unit = tonumber(history.minUnit or history.unit or history.price)
        if unit and unit > 0 then
            local entry = {
                unit = math.floor(unit + 0.5),
                count = 1,
                time = fallbackTime,
            }
            seen = seen + 1
            freshest = entry
            cheapest = entry
        end
    end
    return freshest, cheapest, seen
end

local function BuildHistoryEstimate(itemID, itemName, now)
    local history = GetHistory(itemID, itemName)
    local freshest, cheapest, count = SelectHistoryRecord(history)
    itemID = tonumber(itemID)
    if freshest and freshest.time and now and now >= freshest.time and (now - freshest.time) <= HISTORY_FRESH_SECONDS then
        return {
            ok = true,
            itemID = itemID,
            itemName = itemName,
            unitPrice = freshest.unit,
            state = "fresh",
            source = "price_history",
            observedAt = freshest.time,
            recordCount = count,
        }
    end
    if cheapest then
        local observedAt = freshest and freshest.time or cheapest.time
        return {
            ok = true,
            itemID = itemID,
            itemName = itemName,
            unitPrice = cheapest.unit,
            state = "stale",
            source = "price_history",
            observedAt = observedAt,
            recordCount = count,
        }
    end
    local daily = GetDaily(itemID, itemName)
    local dailyPrice = GetYesterdayMin(daily)
    if dailyPrice and dailyPrice > 0 then
        return {
            ok = true,
            itemID = itemID,
            itemName = itemName,
            unitPrice = math.floor(dailyPrice + 0.5),
            state = "stale",
            source = "daily_min",
        }
    end
    return {
        ok = true,
        itemID = itemID,
        itemName = itemName,
        state = "unavailable",
        source = "price_history",
    }
end

local function DefaultShoppingPriceProvider(itemID, itemName, now)
    local runtime = type(Pro.GetShoppingRuntimeBrowseMinimum) == "function"
        and Pro.GetShoppingRuntimeBrowseMinimum(itemID) or nil
    if type(runtime) == "table" and runtime.ok and runtime.state == "fresh" and runtime.unitPrice then
        return {
            ok = true,
            itemID = tonumber(itemID),
            itemName = itemName,
            unitPrice = runtime.unitPrice,
            state = "fresh",
            source = "session_browse",
            observedAt = runtime.observedAt,
        }
    end
    return BuildHistoryEstimate(itemID, itemName, now)
end

local function GetCurrentMin(history)
    if type(history) ~= "table" then
        return nil
    end
    if tonumber(history.minUnit) and history.minUnit > 0 then
        return history.minUnit
    end
    local minUnit
    for _, row in ipairs(history) do
        local unit = tonumber(row.unit or row[2])
        if unit and unit > 0 and (not minUnit or unit < minUnit) then
            minUnit = unit
        end
    end
    return minUnit
end

local function GetMarketRows(history)
    local rows = {}
    if type(history) ~= "table" then
        return rows
    end
    for _, row in ipairs(history) do
        local unit = tonumber(row.unit or row[2])
        local count = tonumber(row.count or row[3]) or 1
        if unit and unit > 0 then
            rows[#rows + 1] = {
                unit = unit,
                count = math.max(1, math.floor(count)),
            }
        end
    end
    table.sort(rows, function(a, b)
        return a.unit < b.unit
    end)
    return rows
end

local function GetReasonableMarketPrice(rows, referencePrice, lowPct, lowQuantity)
    if #rows == 0 then
        return nil, nil
    end
    lowPct = ClampNumber(lowPct, 0.45, 0, 1)
    lowQuantity = ClampInt(lowQuantity, 2, 0, 50000)
    if not referencePrice or referencePrice <= 0 then
        return rows[1].unit, rows[1]
    end
    local floorPrice = math.max(1, math.floor(referencePrice * lowPct + 0.5))
    for _, row in ipairs(rows) do
        if row.unit >= floorPrice or row.count > lowQuantity then
            return row.unit, row
        end
    end
    return rows[1].unit, rows[1]
end

local function GetYesterdayMin(daily)
    if type(daily) ~= "table" or #daily == 0 then
        return nil
    end
    local latest
    for _, row in ipairs(daily) do
        if row[1] and row[2] and (not latest or tostring(row[1]) > tostring(latest[1])) then
            latest = row
        end
    end
    return latest and tonumber(latest[2]) or nil
end

local function GetMedian7d(daily, history)
    local values = {}
    if type(daily) == "table" then
        local startIndex = math.max(1, #daily - 6)
        for i = startIndex, #daily do
            local price = tonumber(daily[i] and daily[i][2])
            if price and price > 0 then
                table.insert(values, price)
            end
        end
    end
    if #values == 0 and type(history) == "table" then
        for _, row in ipairs(history) do
            local unit = tonumber(row.unit or row[2])
            if unit and unit > 0 then
                table.insert(values, unit)
            end
        end
    end
    if #values == 0 then
        return nil
    end
    table.sort(values)
    local mid = math.ceil(#values / 2)
    if #values % 2 == 0 then
        return math.floor((values[mid] + values[mid + 1]) / 2 + 0.5)
    end
    return values[mid]
end

local function ResolveBasePrice(source, fixedValue, context)
    if source == "fixed" then
        return tonumber(fixedValue)
    elseif source == "currentMin" then
        return context.currentMin
    elseif source == "historyMin" then
        return context.historyMin
    elseif source == "yesterdayMin" then
        return context.yesterdayMin
    elseif source == "median7d" then
        return context.median7d
    end
    return context.median7d or context.currentMin or context.historyMin or context.yesterdayMin
end

local function ResolvePrice(sourceKey, pctKey, fixedKey, operation, context)
    if operation[sourceKey] == "fixed" then
        local fixed = tonumber(operation[fixedKey])
        if fixed and fixed > 0 then
            return math.max(1, math.floor(fixed + 0.5))
        end
        return nil
    end
    local base = ResolveBasePrice(operation[sourceKey], operation[fixedKey], context)
    if not base or base <= 0 then
        return nil
    end
    return math.max(1, math.floor(base * ClampNumber(operation[pctKey], 1, 0, 100) + 0.5))
end

function Pro.GetAuctionOperation(itemID)
    local pro = Pro.InitDB()
    if not pro then
        return nil
    end
    local groupName = Pro.GetItemGroup(itemID)
    local group = groupName and pro.groups[groupName]
    local opName = group and group.auctionOp or Pro.GetDefaultOperationName()
    return pro.auctionOps[opName] or pro.auctionOps[Pro.GetDefaultOperationName()], opName
end

function Pro.UpdateAuctionOperation(operationName, values)
    local pro = Pro.InitDB()
    if not pro or not operationName or operationName == "" or type(values) ~= "table" then
        return false
    end
    pro.auctionOps[operationName] = pro.auctionOps[operationName] or {}
    for key, value in pairs(values) do
        pro.auctionOps[operationName][key] = value
    end
    return true
end

function Pro.ResetAuctionOperation(operationName)
    local pro = Pro.InitDB()
    if not pro or not operationName or operationName == "" then
        return false
    end
    local defaults = Pro.GetDefaultOperationTemplate(operationName)
    if not defaults then
        return false
    end
    pro.auctionOps[operationName] = defaults
    return true
end

function Pro.DeleteAuctionOperation(operationName)
    local pro = Pro.InitDB()
    if not pro or not operationName or operationName == "" then
        return false
    end
    if operationName == Pro.GetDefaultOperationName() then
        return false
    end
    if Pro.IsDefaultOperation and Pro.IsDefaultOperation(operationName) then
        return false
    end
    if not pro.auctionOps[operationName] then
        return false
    end

    pro.auctionOps[operationName] = nil
    local fallback = Pro.GetDefaultOperationName()
    for _, group in pairs(pro.groups or {}) do
        if group and group.auctionOp == operationName then
            group.auctionOp = fallback
        end
    end
    return true
end

function Pro.CalcPostSuggestion(itemID, itemName, bagCount)
    local operation, opName = Pro.GetAuctionOperation(itemID)
    if not operation then
        return nil
    end
    local pro = Pro.InitDB()

    local history = GetHistory(itemID, itemName)
    local daily = GetDaily(itemID, itemName)
    local marketRows = GetMarketRows(history)
    local context = {
        currentMin = GetCurrentMin(history),
        historyMin = GetCurrentMin(history),
        yesterdayMin = GetYesterdayMin(daily),
        median7d = GetMedian7d(daily, history),
    }
    context.reasonableMin = GetReasonableMarketPrice(
        marketRows,
        context.median7d or context.yesterdayMin or context.historyMin,
        operation.ignoreLowPricePct,
        operation.ignoreLowQuantity
    )
    if context.reasonableMin then
        context.currentMin = context.reasonableMin
    end
    local minPrice = ResolvePrice("minPriceSource", "minPricePct", "minPriceFixed", operation, context)
    local normalPrice = ResolvePrice("normalPriceSource", "normalPricePct", "normalPriceFixed", operation, context)
    local maxPrice = ResolvePrice("maxPriceSource", "maxPricePct", "maxPriceFixed", operation, context)
    local price = normalPrice or context.currentMin or context.historyMin or context.yesterdayMin
    local reason = "按策略建议上架"
    local status = "post"
    local ignoredLowPrice = false

    if not price or price <= 0 then
        status = "skip"
        reason = "缺少可用价格数据，请先扫描或手动定价"
    end

    local rawMin = GetCurrentMin(history)
    if rawMin and context.currentMin and rawMin < context.currentMin then
        ignoredLowPrice = true
        reason = "已忽略少量异常低价，按下一档建议"
    end

    if context.currentMin and minPrice and context.currentMin < minPrice then
        local ignoreLine = context.median7d and
            context.median7d * ClampNumber(operation.ignoreLowPricePct, 0.60, 0, 1) or nil
        if ignoreLine and context.currentMin < ignoreLine and normalPrice then
            price = normalPrice
            reason = "当前最低价疑似异常，已按正常价建议"
        else
            status = "skip"
            price = minPrice
            reason = "当前市场价低于最低价，不建议上架"
        end
    elseif context.currentMin and maxPrice and context.currentMin > maxPrice then
        price = maxPrice
        reason = "当前市场价高于最高价，按最高价建议"
    elseif context.currentMin and price then
        price = math.max(minPrice or 1, context.currentMin - ClampInt(operation.undercutAmount, 1, 0, 1000000))
        if maxPrice then price = math.min(price, maxPrice) end
        reason = ignoredLowPrice and "已忽略少量异常低价，按参考最低价压价" or "按当前最低价压价"
    end

    local keepQuantity = ClampInt(operation.keepQuantity, 0, 0, 50000)
    local available = math.max(0, ClampInt(bagCount, 0, 0, 50000) - keepQuantity)
    local stackSize = ClampInt(operation.stackSize, 20, 1, 200)
    if available > 0 and stackSize > available then
        stackSize = available
    end
    local numStacks = ClampInt(operation.numStacks, 1, 1, 50000)
    local postCap = ClampInt(operation.postCap, 5, 0, 50000)
    if postCap > 0 then
        numStacks = math.min(numStacks, postCap)
    end
    if stackSize > 0 then
        numStacks = math.min(numStacks, math.floor(available / stackSize))
    end
    if available <= 0 or numStacks <= 0 then
        status = "skip"
        reason = "保留数量后没有可上架库存"
    end

    local maxExpires = ClampInt(operation.maxExpires, 0, 0, 50000)
    local stat = pro and pro.ledger and pro.ledger.itemStats and pro.ledger.itemStats[tostring(itemID)]
    local expiredCount = stat and ClampInt(stat.expiredCount, 0, 0, 50000) or 0
    if maxExpires > 0 and expiredCount >= maxExpires then
        status = "skip"
        reason = string.format("流拍 %d 次已达到策略上限 %d 次", expiredCount, maxExpires)
    end

    return {
        itemID = itemID,
        itemName = itemName,
        operationName = opName,
        unitPrice = price or 0,
        minPrice = minPrice,
        normalPrice = normalPrice,
        maxPrice = maxPrice,
        currentMin = rawMin,
        marketMin = context.currentMin,
        yesterdayMin = context.yesterdayMin,
        median7d = context.median7d,
        stackSize = math.max(1, stackSize),
        numStacks = math.max(0, numStacks),
        duration = ClampInt(operation.duration, 1, 1, 3),
        keepQuantity = keepQuantity,
        expiredCount = expiredCount,
        maxExpires = maxExpires,
        status = status,
        reason = reason,
    }
end

function _G.EasyAuctionPro_GetAuctionOperation(itemID)
    return Pro.GetAuctionOperation(itemID)
end

function _G.EasyAuctionPro_CalcPostSuggestion(itemID, itemName, bagCount)
    return Pro.CalcPostSuggestion(itemID, itemName, bagCount)
end

function _G.EasyAuctionPro_UpdateAuctionOperation(operationName, values)
    return Pro.UpdateAuctionOperation(operationName, values)
end

function _G.EasyAuctionPro_ResetAuctionOperation(operationName)
    return Pro.ResetAuctionOperation(operationName)
end

function _G.EasyAuctionPro_DeleteAuctionOperation(operationName)
    return Pro.DeleteAuctionOperation(operationName)
end

if type(Pro.RegisterShoppingPriceProvider) == "function" then
    Pro.RegisterShoppingPriceProvider("default", DefaultShoppingPriceProvider, {
        owner = "EasyAuction",
        major = 1,
    })
end
