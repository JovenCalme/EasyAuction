local _, ns = ...

ns = ns or {}
ns.BagValue = ns.BagValue or {}
local BagValue = ns.BagValue

local Estimator = {}
Estimator.__index = Estimator

local DEFAULT_FRESH_SECONDS = 24 * 60 * 60

local function nonNegativeInteger(value)
    value = tonumber(value) or 0
    if value <= 0 then return 0 end
    return math.floor(value + 0.5)
end

local function getPrice(provider, item, now)
    if type(provider) == "function" then
        return provider(item.itemID, item.name, now, item)
    end
    if type(provider) == "table" and type(provider.GetPrice) == "function" then
        return provider:GetPrice(item.itemID, item.name, now, item)
    end
end

local function getDisenchantPrice(provider, item)
    if type(provider) ~= "function" then return 0 end
    local ok, value = pcall(provider, item.classID, item.quality, item.itemLevel)
    if not ok then return 0 end
    return nonNegativeInteger(value)
end

local function normalizePrice(result, now, freshSeconds)
    if type(result) == "number" then
        if result <= 0 then return nil, nil, nil, "missing" end
        return nonNegativeInteger(result), nil, nil, "unknown"
    end
    if type(result) ~= "table" then return nil, nil, nil, "missing" end
    local unit = tonumber(result.auctionUnit or result.unitPrice or result.price)
    if not unit or unit <= 0 or result.ok == false or result.state == "unavailable" then
        return nil, result.source, tonumber(result.observedAt), "missing"
    end
    local observedAt = tonumber(result.observedAt)
    local freshness = result.freshness or result.state
    if freshness ~= "fresh" and freshness ~= "stale" then
        if observedAt and now and now >= observedAt then
            freshness = now - observedAt <= freshSeconds and "fresh" or "stale"
        else
            freshness = "unknown"
        end
    end
    return nonNegativeInteger(unit), result.source, observedAt, freshness
end

local function rowSort(left, right)
    if left.totalValue ~= right.totalValue then return left.totalValue > right.totalValue end
    local leftName = tostring(left.name or "")
    local rightName = tostring(right.name or "")
    if leftName ~= rightName then return leftName < rightName end
    return left.itemID < right.itemID
end

function Estimator.New(deps)
    deps = deps or {}
    return setmetatable({
        priceProvider = deps.priceProvider,
        disenchantProvider = deps.disenchantProvider or _G.GetDisenchantValue,
        now = deps.now,
        freshSeconds = tonumber(deps.freshSeconds) or DEFAULT_FRESH_SECONDS,
    }, Estimator)
end

function Estimator:Estimate(snapshotOrItems, options)
    options = options or {}
    local snapshot = type(snapshotOrItems) == "table" and snapshotOrItems or nil
    local items = snapshot and snapshot.items or snapshotOrItems or {}
    local minQuality = tonumber(options.minQuality) or 0
    local now = tonumber(options.now)
    if not now then
        now = type(self.now) == "function" and tonumber(self.now()) or tonumber(self.now)
    end
    local rows = {}
    local summary = {
        total = 0,
        auction = 0,
        vendor = 0,
        disenchant = 0,
        pricedCount = 0,
        unpricedCount = 0,
        pendingCount = snapshot and nonNegativeInteger(snapshot.unresolvedCount) or 0,
        pricedItemCount = 0,
        unpricedItemCount = 0,
    }

    for index = 1, #items do
        local item = items[index]
        local quality = tonumber(item.quality)
        if quality == nil or quality >= minQuality then
            local count = nonNegativeInteger(item.count)
            local boundCount = math.min(count, nonNegativeInteger(item.boundCount))
            local unboundCount = math.min(count - boundCount, nonNegativeInteger(item.unboundCount))
            if boundCount + unboundCount < count then
                unboundCount = count - boundCount
            end
            local vendorUnit = nonNegativeInteger(item.vendorUnit)
            local disenchantUnit = getDisenchantPrice(self.disenchantProvider, item)
            local priceResult
            if unboundCount > 0 then priceResult = getPrice(self.priceProvider, item, now) end
            local auctionUnit, source, observedAt, freshness = normalizePrice(
                priceResult, now, self.freshSeconds)
            local auctionPricedCount = auctionUnit and unboundCount or 0
            local recoveryCount = count - auctionPricedCount
            local vendorPricedCount = 0
            local disenchantPricedCount = 0
            if vendorUnit > 0 and vendorUnit >= disenchantUnit then
                vendorPricedCount = recoveryCount
            elseif disenchantUnit > 0 then
                disenchantPricedCount = recoveryCount
            end
            local pricedItemCount = auctionPricedCount + vendorPricedCount + disenchantPricedCount
            local unpricedItemCount = count - pricedItemCount
            local auctionValue = (auctionUnit or 0) * auctionPricedCount
            local vendorValue = vendorUnit * vendorPricedCount
            local disenchantValue = disenchantUnit * disenchantPricedCount
            local totalValue = auctionValue + vendorValue + disenchantValue
            local row = {
                itemID = item.itemID,
                name = item.name,
                link = item.link,
                quality = item.quality,
                icon = item.icon,
                count = count,
                boundCount = boundCount,
                unboundCount = unboundCount,
                vendorUnit = vendorUnit,
                disenchantUnit = disenchantUnit,
                auctionUnit = auctionUnit,
                source = source,
                observedAt = observedAt,
                freshness = freshness,
                auctionValue = auctionValue,
                vendorValue = vendorValue,
                disenchantValue = disenchantValue,
                totalValue = totalValue,
                pricedItemCount = pricedItemCount,
                unpricedItemCount = unpricedItemCount,
                pending = item.pending == true,
            }
            rows[#rows + 1] = row
            summary.total = summary.total + totalValue
            summary.auction = summary.auction + auctionValue
            summary.vendor = summary.vendor + vendorValue
            summary.disenchant = summary.disenchant + disenchantValue
            summary.pricedItemCount = summary.pricedItemCount + pricedItemCount
            summary.unpricedItemCount = summary.unpricedItemCount + unpricedItemCount
            if pricedItemCount > 0 then
                summary.pricedCount = summary.pricedCount + 1
            else
                summary.unpricedCount = summary.unpricedCount + 1
            end
            if row.pending then summary.pendingCount = summary.pendingCount + 1 end
        end
    end

    table.sort(rows, rowSort)
    summary.totalValue = summary.total
    summary.auctionValue = summary.auction
    summary.vendorValue = summary.vendor
    summary.disenchantValue = summary.disenchant
    return { rows = rows, summary = summary }
end

BagValue.BagValueEstimator = Estimator

return Estimator
