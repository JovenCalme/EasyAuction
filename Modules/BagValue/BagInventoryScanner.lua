local _, ns = ...

ns = ns or {}
ns.BagValue = ns.BagValue or {}
local BagValue = ns.BagValue

local Scanner = {}
Scanner.__index = Scanner

local function itemIDFromLink(link)
    if type(link) ~= "string" then return nil end
    return tonumber(link:match("item:(%d+)"))
end

local function defaultBags()
    local bags = {}
    local lastBag = tonumber(_G.NUM_BAG_SLOTS) or 4
    for bag = 0, lastBag do
        bags[#bags + 1] = bag
    end
    return bags
end

local function defaultAPI()
    local container = _G.C_Container or {}
    local itemAPI = _G.C_Item or {}
    return {
        GetContainerNumSlots = container.GetContainerNumSlots or _G.GetContainerNumSlots,
        GetContainerItemInfo = container.GetContainerItemInfo or _G.GetContainerItemInfo,
        GetContainerItemLink = container.GetContainerItemLink or _G.GetContainerItemLink,
        GetItemInfo = itemAPI.GetItemInfo or _G.GetItemInfo,
        IsBound = function(bag, slot)
            if type(itemAPI.IsBound) ~= "function" or not _G.ItemLocation
                    or type(_G.ItemLocation.CreateFromBagAndSlot) ~= "function" then
                return false
            end
            local location = _G.ItemLocation:CreateFromBagAndSlot(bag, slot)
            return itemAPI.IsBound(location) == true
        end,
    }
end

local function readContainerInfo(api, bag, slot)
    local values = { api.GetContainerItemInfo(bag, slot) }
    if values[1] == nil then return nil end
    if type(values[1]) == "table" then
        local info = values[1]
        local link = info.hyperlink or info.itemLink
        if not link and type(api.GetContainerItemLink) == "function" then
            link = api.GetContainerItemLink(bag, slot)
        end
        return {
            itemID = tonumber(info.itemID) or itemIDFromLink(link),
            count = tonumber(info.stackCount or info.count) or 1,
            name = info.itemName or info.name,
            link = link,
            quality = info.quality,
            icon = info.iconFileID or info.icon,
            bound = info.isBound == true or info.bound == true,
        }
    end

    local link = values[7]
    if not link and type(api.GetContainerItemLink) == "function" then
        link = api.GetContainerItemLink(bag, slot)
    end
    return {
        itemID = tonumber(values[10]) or itemIDFromLink(link),
        count = tonumber(values[2]) or 1,
        link = link,
        quality = values[4],
        icon = values[1],
        bound = values[11] == true,
    }
end

local function readItemInfo(api, item)
    if type(api.GetItemInfo) ~= "function" then return nil end
    local values = { api.GetItemInfo(item.link or item.itemID) }
    if type(values[1]) == "table" then
        local info = values[1]
        if not info.name and not info.itemName then return nil end
        return {
            name = info.name or info.itemName,
            link = info.hyperlink or info.itemLink,
            quality = info.quality,
            icon = info.iconFileID or info.icon,
            vendorUnit = tonumber(info.sellPrice or info.vendorUnit) or 0,
        }
    end
    if values[1] == nil then return nil end
    return {
        name = values[1],
        link = values[2],
        quality = values[3],
        icon = values[10],
        vendorUnit = tonumber(values[11]) or 0,
    }
end

local function mergeMetadata(target, source)
    if source.link then target.link = source.link end
    if source.name then target.name = source.name end
    if source.quality ~= nil then target.quality = source.quality end
    if source.icon ~= nil then target.icon = source.icon end
    if source.vendorUnit ~= nil then target.vendorUnit = source.vendorUnit end
end

function Scanner.New(deps)
    deps = deps or {}
    return setmetatable({
        api = deps.api or defaultAPI(),
        bagIds = deps.bagIds or defaultBags(),
    }, Scanner)
end

function Scanner:Scan()
    local snapshot = {
        items = {},
        pendingCount = 0,
        pendingItemCount = 0,
        unresolvedCount = 0,
        totalCount = 0,
        itemCount = 0,
    }
    local api = self.api
    if type(api.GetContainerNumSlots) ~= "function"
            or type(api.GetContainerItemInfo) ~= "function" then
        snapshot.error = {
            code = "CONTAINER_API_UNAVAILABLE",
            message = "当前客户端不提供背包扫描接口",
        }
        return snapshot
    end

    local byItemID = {}
    for bagIndex = 1, #self.bagIds do
        local bag = self.bagIds[bagIndex]
        local slotCount = tonumber(api.GetContainerNumSlots(bag)) or 0
        for slot = 1, slotCount do
            local slotItem = readContainerInfo(api, bag, slot)
            if slotItem then
                local count = math.max(0, math.floor(slotItem.count or 0))
                if count > 0 and not slotItem.itemID then
                    snapshot.pendingCount = snapshot.pendingCount + 1
                    snapshot.pendingItemCount = snapshot.pendingItemCount + count
                    snapshot.unresolvedCount = snapshot.unresolvedCount + 1
                    snapshot.totalCount = snapshot.totalCount + count
                elseif count > 0 then
                    if not slotItem.bound and type(api.IsBound) == "function" then
                        slotItem.bound = api.IsBound(bag, slot, slotItem) == true
                    end
                    local item = byItemID[slotItem.itemID]
                    if not item then
                        item = {
                            itemID = slotItem.itemID,
                            count = 0,
                            boundCount = 0,
                            unboundCount = 0,
                            link = slotItem.link,
                            quality = slotItem.quality,
                            icon = slotItem.icon,
                            vendorUnit = 0,
                        }
                        byItemID[slotItem.itemID] = item
                        snapshot.items[#snapshot.items + 1] = item
                    end
                    item.count = item.count + count
                    if slotItem.bound then
                        item.boundCount = item.boundCount + count
                    else
                        item.unboundCount = item.unboundCount + count
                    end
                    mergeMetadata(item, slotItem)
                end
            end
        end
    end

    for index = 1, #snapshot.items do
        local item = snapshot.items[index]
        local metadata = readItemInfo(api, item)
        if metadata then
            mergeMetadata(item, metadata)
            item.pending = false
        else
            item.pending = true
            snapshot.pendingCount = snapshot.pendingCount + 1
            snapshot.pendingItemCount = snapshot.pendingItemCount + item.count
        end
        snapshot.totalCount = snapshot.totalCount + item.count
    end
    snapshot.itemCount = #snapshot.items
    return snapshot
end

BagValue.BagInventoryScanner = Scanner

return Scanner
