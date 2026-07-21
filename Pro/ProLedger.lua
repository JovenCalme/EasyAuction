local _, ns = ...

local Pro = ns.EasyAuctionPro
if not Pro then return end

local MAX_SEEN_KEYS = 200

local function NormalizeItemID(itemID)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then
        return nil
    end
    return tostring(itemID)
end

local function ClampNumber(value, defaultValue, minValue, maxValue)
    local n = tonumber(value)
    if n == nil then n = defaultValue end
    if minValue and n < minValue then n = minValue end
    if maxValue and n > maxValue then n = maxValue end
    return n
end

local function GetItemKey(itemID, itemName)
    itemID = tonumber(itemID)
    if itemName and itemID then
        return itemName .. ":" .. itemID
    end
    return itemName
end

local function EnsureStat(itemID, itemName)
    local pro = Pro.InitDB()
    local key = NormalizeItemID(itemID)
    if not pro or not key then
        return nil
    end
    pro.ledger.itemStats[key] = pro.ledger.itemStats[key] or {
        postedCount = 0,
        soldCount = 0,
        expiredCount = 0,
        boughtCount = 0,
        soldRevenue = 0,
        boughtCost = 0,
    }
    local stat = pro.ledger.itemStats[key]
    if itemName and itemName ~= "" then
        stat.itemName = itemName
    end
    return stat, pro, key
end

local function MarkSeen(map, order, key)
    if not map or not order or not key then
        return false
    end
    if map[key] then
        return false
    end
    map[key] = true
    order[#order + 1] = key
    while #order > MAX_SEEN_KEYS do
        local oldKey = table.remove(order, 1)
        if oldKey then
            map[oldKey] = nil
        end
    end
    return true
end

function Pro.RecordLedgerEvent(eventType, itemID, values)
    values = values or {}
    local stat, pro = EnsureStat(itemID, values.itemName or values.name)
    if not stat or not pro then
        return false
    end

    local count = math.max(1, math.floor(tonumber(values.count) or 1))
    local total = math.max(0, math.floor(tonumber(values.totalPrice or values.price) or 0))
    local now = tonumber(values.time) or time()

    if eventType == "posted" then
        stat.postedCount = (stat.postedCount or 0) + count
        stat.lastPostedTime = now
    elseif eventType == "sold" then
        local seenKey = values.seenKey
        if seenKey and not MarkSeen(pro.ledger.seenSoldKeys, pro.ledger.seenSoldOrder, seenKey) then
            return false
        end
        stat.soldCount = (stat.soldCount or 0) + count
        stat.soldRevenue = (stat.soldRevenue or 0) + total
        stat.lastSoldTime = now
    elseif eventType == "expired" then
        local seenKey = values.seenKey
        if seenKey and not MarkSeen(pro.ledger.seenExpireKeys, pro.ledger.seenExpireOrder, seenKey) then
            return false
        end
        stat.expiredCount = (stat.expiredCount or 0) + count
        stat.lastExpiredTime = now
    elseif eventType == "bought" then
        stat.boughtCount = (stat.boughtCount or 0) + count
        stat.boughtCost = (stat.boughtCost or 0) + total
        stat.lastBoughtTime = now
    else
        return false
    end

    return true
end

function Pro.GetItemStats(itemID)
    local pro = Pro.InitDB()
    local key = NormalizeItemID(itemID)
    if not pro or not key then
        return nil
    end
    return pro.ledger.itemStats and pro.ledger.itemStats[key] or nil
end

function Pro.ResolveItemIDByName(itemName)
    if not itemName or itemName == "" then
        return nil
    end
    local db = Pro.GetDB()
    if not db then
        return nil
    end
    for itemID, info in pairs(db.FavoriteItems or {}) do
        if info and info.name == itemName then
            return tonumber(itemID)
        end
    end
    for key in pairs(db.PriceHistory or {}) do
        local name, id = string.match(key, "^(.-):(%d+)$")
        if name == itemName then
            return tonumber(id)
        end
    end
    return nil
end

function Pro.GetInventoryCount(itemID)
    itemID = tonumber(itemID)
    if not itemID then
        return 0
    end
    local count = 0
    for bag = 0, NUM_BAG_SLOTS do
        local slots = C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local info = C_Container and C_Container.GetContainerItemInfo and
                C_Container.GetContainerItemInfo(bag, slot)
            if info and tonumber(info.itemID) == itemID then
                count = count + (tonumber(info.stackCount) or 0)
            end
        end
    end
    return count
end

local function GetHistory(itemID, itemName)
    local db = Pro.GetDB()
    local key = GetItemKey(itemID, itemName)
    if not db or not key or not db.PriceHistory then
        return nil, key
    end
    return db.PriceHistory[key], key
end

local function GetDaily(itemID, itemName)
    local db = Pro.GetDB()
    local key = GetItemKey(itemID, itemName)
    if not db or not key or not db.DailyMinPrice then
        return nil
    end
    return db.DailyMinPrice[key]
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
                values[#values + 1] = price
            end
        end
    end
    if #values == 0 and type(history) == "table" then
        for _, row in ipairs(history) do
            local unit = tonumber(row.unit or row[2])
            if unit and unit > 0 then
                values[#values + 1] = unit
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

function Pro.GetPriceContext(itemID, itemName)
    local history = GetHistory(itemID, itemName)
    local daily = GetDaily(itemID, itemName)
    return {
        currentMin = GetCurrentMin(history),
        historyMin = GetCurrentMin(history),
        yesterdayMin = GetYesterdayMin(daily),
        median7d = GetMedian7d(daily, history),
    }
end

function Pro.ResolvePriceSource(source, fixedValue, pct, itemID, itemName)
    local context = Pro.GetPriceContext(itemID, itemName)
    local base
    if source == "fixed" then
        base = tonumber(fixedValue)
    elseif source == "currentMin" then
        base = context.currentMin
    elseif source == "historyMin" then
        base = context.historyMin
    elseif source == "yesterdayMin" then
        base = context.yesterdayMin
    elseif source == "median7d" then
        base = context.median7d
    else
        base = context.median7d or context.currentMin or context.historyMin or context.yesterdayMin
    end
    if not base or base <= 0 then
        return nil, context
    end
    return math.max(1, math.floor(base * ClampNumber(pct, 1, 0, 100) + 0.5)), context
end

local function RecordOwnerSoldRows()
    local num = GetNumAuctionItems and GetNumAuctionItems("owner") or 0
    for idx = 1, num do
        local name, _, count, _, _, _, _, _, _, buyout, _, buyer, _, _, _, saleStatus, itemID =
            GetAuctionItemInfo("owner", idx)
        if itemID and saleStatus == 1 then
            local soldCount = tonumber(count) or 1
            if soldCount <= 0 then
                soldCount = 1
            end
            Pro.RecordLedgerEvent("sold", itemID, {
                itemName = name,
                count = soldCount,
                totalPrice = buyout or 0,
                seenKey = table.concat({
                    "sold",
                    tostring(itemID),
                    tostring(buyout or 0),
                    tostring(buyer or ""),
                    tostring(idx),
                }, ":"),
            })
        end
    end
end

hooksecurefunc("PostAuction", function(_, buyout, _, stackSize, numStacks)
    local name, _, _, _, _, _, _, _, _, itemID = GetAuctionSellItemInfo()
    if name and itemID then
        local posted = {
            itemID = itemID,
            itemName = name,
            count = math.max(1, math.floor((tonumber(stackSize) or 1) * (tonumber(numStacks) or 1))),
            totalPrice = tonumber(buyout) or 0,
            time = time(),
        }
        Pro.RecordLedgerEvent("posted", itemID, posted)
    end
end)

hooksecurefunc("PlaceAuctionBid", function(auctionType, index, price)
    local name, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID =
        GetAuctionItemInfo(auctionType, index)
    if itemID and count and price then
        Pro.RecordLedgerEvent("bought", itemID, {
            itemName = name,
            count = count,
            totalPrice = price or buyout or 0,
        })
    end
end)

local expiredPatterns = {
    gsub(ERR_AUCTION_EXPIRED_S or "你的%s拍卖已到期。", "%%s", "(.+)"),
    "你的(.+)拍卖已到期",
    "(.+)的拍卖已到期",
}

local ledgerFrame = CreateFrame("Frame")
ledgerFrame:RegisterEvent("CHAT_MSG_SYSTEM")
ledgerFrame:RegisterEvent("AUCTION_OWNED_LIST_UPDATE")
ledgerFrame:SetScript("OnEvent", function(_, event, msg)
    if event == "AUCTION_OWNED_LIST_UPDATE" then
        RecordOwnerSoldRows()
        return
    end
    if not msg then return end
    for _, pattern in ipairs(expiredPatterns) do
        local itemName = msg:match(pattern)
        if itemName then
            itemName = itemName:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            local itemID = Pro.ResolveItemIDByName(itemName)
            if itemID then
                Pro.RecordLedgerEvent("expired", itemID, {
                    itemName = itemName,
                    count = 1,
                    seenKey = "expired:" .. tostring(itemID) .. ":" .. tostring(time()),
                })
            end
            return
        end
    end
end)

function _G.EasyAuctionPro_RecordLedgerEvent(eventType, itemID, values)
    return Pro.RecordLedgerEvent(eventType, itemID, values)
end
