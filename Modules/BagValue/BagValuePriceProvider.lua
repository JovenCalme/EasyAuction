local _, ns = ...

ns = ns or {}
ns.BagValue = ns.BagValue or {}
local BagValue = ns.BagValue

local PriceProvider = {}
PriceProvider.__index = PriceProvider

function PriceProvider.New(deps)
    return setmetatable({ deps = deps or {} }, PriceProvider)
end

function PriceProvider:GetPrice(itemID, itemName, now)
    local getEstimate = self.deps.getEstimate or _G.EasyAuctionPro_GetShoppingPriceEstimate
    if type(getEstimate) ~= "function" then
        return { freshness = "unavailable", state = "unavailable", source = "none" }
    end

    now = tonumber(now)
    if not now then
        local getNow = self.deps.getNow or _G.GetServerTime or _G.time
        if type(getNow) == "function" then
            local ok, value = pcall(getNow)
            if ok then now = tonumber(value) end
        end
    end

    local ok, result = pcall(getEstimate, itemID, itemName, now)
    if not ok or type(result) ~= "table" or result.ok == false then
        return { freshness = "unavailable", state = "unavailable", source = "none" }
    end

    local state = result.state
    local unitPrice = tonumber(result.unitPrice)
    if (state ~= "fresh" and state ~= "stale") or not unitPrice or unitPrice <= 0 then
        return {
            freshness = "unavailable",
            state = "unavailable",
            source = result.source or "none",
        }
    end

    return {
        unitPrice = math.max(1, math.floor(unitPrice + 0.5)),
        freshness = state,
        state = state,
        source = result.source or "price_history",
        observedAt = tonumber(result.observedAt),
    }
end

BagValue.PriceProvider = PriceProvider

return PriceProvider
