local _, ns = ...

ns = ns or {}
ns.Mail = ns.Mail or {}
local Mail = ns.Mail

local BagScanner = {}
BagScanner.__index = BagScanner

local function newError(code, message, detail)
    if Mail.NewError then return Mail:NewError(code, message, detail) end
    return { code = code, message = message, detail = detail }
end

local function defaultAPI()
    local container = _G.C_Container or {}
    return {
        GetContainerNumSlots = container.GetContainerNumSlots or _G.GetContainerNumSlots,
        GetContainerItemInfo = container.GetContainerItemInfo or _G.GetContainerItemInfo,
        GetContainerItemLink = container.GetContainerItemLink or _G.GetContainerItemLink,
        GetItemInfoInstant = _G.C_Item and _G.C_Item.GetItemInfoInstant or _G.GetItemInfoInstant,
        IsBound = function(bag, _, slot)
            if _G.C_Item and _G.C_Item.IsBound and _G.ItemLocation
                and _G.ItemLocation.CreateFromBagAndSlot then
                local location = _G.ItemLocation:CreateFromBagAndSlot(bag, slot)
                return _G.C_Item.IsBound(location) == true
            end
            return false
        end,
    }
end

local function defaultBags()
    local result = {}
    local lastBag = tonumber(_G.NUM_BAG_SLOTS) or 4
    for bag = 0, lastBag do result[#result + 1] = bag end
    return result
end

local function itemIdFromLink(link)
    if type(link) ~= "string" then return nil end
    return tonumber(link:match("item:(%d+)"))
end

function BagScanner.New(deps)
    deps = deps or {}
    return setmetatable({
        api = deps.api or defaultAPI(),
        bagIds = deps.bagIds or defaultBags(),
        categoryRegistry = deps.categoryRegistry,
    }, BagScanner)
end

function BagScanner:_matches(filter, item)
    if type(filter) == "number" then return item.itemID == filter end
    filter = filter or {}
    if filter.exactItemID then return item.itemID == tonumber(filter.exactItemID) end
    if filter.itemCategory then
        return self.categoryRegistry and self.categoryRegistry.Matches
            and self.categoryRegistry:Matches(filter.itemCategory, item) == true
    end
    if type(filter.predicate) == "function" then return filter.predicate(item) == true end
    return false
end

function BagScanner:Scan(filter, options)
    options = options or {}
    local result, skipped = {}, {}
    local enabledBags = options.enabledBags
    local getSlots = self.api.GetContainerNumSlots
    local getInfo = self.api.GetContainerItemInfo
    if type(getSlots) ~= "function" or type(getInfo) ~= "function" then
        return result, { newError("CONTAINER_API_UNAVAILABLE", "当前客户端不提供背包扫描接口") }
    end

    for bagIndex = 1, #self.bagIds do
        local bag = self.bagIds[bagIndex]
        if not enabledBags or enabledBags[bag] ~= false then
            local slotCount = tonumber(getSlots(bag)) or 0
            for slot = 1, slotCount do
                local info = getInfo(bag, slot)
                if info then
                    local link = info.hyperlink or info.itemLink
                    if not link and self.api.GetContainerItemLink then link = self.api.GetContainerItemLink(bag, slot) end
                    local item = {
                        bag = bag,
                        slot = slot,
                        itemID = tonumber(info.itemID) or itemIdFromLink(link),
                        itemLink = link,
                        count = tonumber(info.stackCount or info.count) or 1,
                        locked = info.isLocked == true or info.locked == true,
                        bound = info.isBound == true or info.bound == true,
                        quality = info.quality,
                        icon = info.iconFileID or info.icon,
                    }
                    local classifier = self.api.GetItemClassification or self.api.GetItemInfoInstant
                        or _G.GetItemInfoInstant
                    if classifier then
                        local _, _, _, equipLoc, _, classID, subclassID = classifier(link or item.itemID)
                        item.equipLoc = equipLoc
                        item.classID = classID
                        item.subclassID = subclassID
                    end
                    if not item.bound and self.api.IsBound then item.bound = self.api.IsBound(bag, item, slot) == true end
                    local attachable = not self.api.CanAttach or self.api.CanAttach(bag, item, slot) ~= false
                    if not item.itemID then
                        skipped[#skipped + 1] = newError("ITEM_DATA_PENDING", "物品数据尚未载入", { bag = bag, slot = slot })
                    elseif item.locked then
                        skipped[#skipped + 1] = newError("ITEM_LOCKED", "物品格正在使用", { bag = bag, slot = slot })
                    elseif item.bound then
                        skipped[#skipped + 1] = newError("ITEM_BOUND", "绑定物品不能邮寄", { bag = bag, slot = slot })
                    elseif not attachable then
                        skipped[#skipped + 1] = newError("ITEM_NOT_MAILABLE", "该物品不能作为邮件附件", { bag = bag, slot = slot })
                    elseif self:_matches(filter, item) then
                        result[#result + 1] = item
                    end
                end
            end
        end
    end
    return result, skipped
end

Mail.BagScanner = BagScanner
