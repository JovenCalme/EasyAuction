local _, ns = ...

ns = ns or {}
ns.Mail = ns.Mail or {}
local Mail = ns.Mail

local QuickAttachController = {}
QuickAttachController.__index = QuickAttachController

local ItemCategoryRegistry = {
    order = {
        "trade_cloth", "trade_leather", "trade_metal", "trade_cooking", "trade_herb",
        "trade_enchant", "trade_jewel", "trade_parts", "trade_element", "trade_device",
        "trade_explosive", "trade_material", "trade_other", "trade_upgrade", "trade_all",
    },
    definitions = {
        trade_cloth = { label = "布料", tooltip = "布", classID = 7, subclassID = 5 },
        trade_leather = { label = "皮革", tooltip = "皮革", classID = 7, subclassID = 6 },
        trade_metal = { label = "矿石", tooltip = "金属与矿石", classID = 7, subclassID = 7 },
        trade_cooking = { label = "烹饪", tooltip = "烹饪材料", classID = 7, subclassID = 8 },
        trade_herb = { label = "草药", tooltip = "草药", classID = 7, subclassID = 9 },
        trade_enchant = { label = "附魔", tooltip = "附魔材料", classID = 7, subclassID = 12 },
        trade_jewel = { label = "珠宝", tooltip = "珠宝加工", classID = 7, subclassID = 4 },
        trade_parts = { label = "部件", tooltip = "工程部件", classID = 7, subclassID = 1 },
        trade_element = { label = "元素", tooltip = "元素材料", classID = 7, subclassID = 10 },
        trade_device = { label = "设备", tooltip = "工程设备", classID = 7, subclassID = 3 },
        trade_explosive = { label = "炸药", tooltip = "爆炸物", classID = 7, subclassID = 2 },
        trade_material = { label = "材料", tooltip = "其它材料", classID = 7, subclassID = 13 },
        trade_other = { label = "其他", tooltip = "其它贸易品", classID = 7, subclassID = 11 },
        trade_upgrade = { label = "强化", tooltip = "物品强化", classID = 7, subclassID = 14 },
        trade_all = { label = "贸易", tooltip = "全部贸易品", classID = 7, allSubclasses = true },
    },
}

function ItemCategoryRegistry:Matches(categoryId, item)
    local definition = self.definitions[categoryId]
    if not definition or tonumber(item and item.classID) ~= definition.classID then return false end
    return definition.allSubclasses == true or tonumber(item.subclassID) == definition.subclassID
end

function ItemCategoryRegistry:List()
    local result = {}
    for index = 1, #self.order do
        local id = self.order[index]
        local definition = self.definitions[id]
        result[index] = {
            id = id,
            label = definition.label,
            tooltip = definition.tooltip,
            classID = definition.classID,
            subclassID = definition.subclassID,
            allSubclasses = definition.allSubclasses,
        }
    end
    return result
end

local function clone(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = clone(item) end
    return result
end

function QuickAttachController.New(deps)
    deps = deps or {}
    local config = deps.config or {}
    config.enabledBags = type(config.enabledBags) == "table" and config.enabledBags or {}
    config.recipientByCategory = type(config.recipientByCategory) == "table" and config.recipientByCategory or {}
    return setmetatable({
        scanner = deps.scanner,
        attachmentService = deps.attachmentService,
        categoryRegistry = deps.categoryRegistry,
        recipientRepository = deps.recipientRepository,
        config = config,
    }, QuickAttachController)
end

function QuickAttachController:FindExactItems(itemID)
    if not self.scanner then return {} end
    return self.scanner:Scan({ exactItemID = tonumber(itemID) }, { enabledBags = self.config.enabledBags })
end

function QuickAttachController:AttachExact(itemID)
    local items = self:FindExactItems(itemID)
    if #items == 0 then return nil, { code = "ITEM_NOT_FOUND", message = "背包中没有可邮寄的同 ID 物品" } end
    return self.attachmentService:AttachMany(items, _G.ATTACHMENTS_MAX_SEND or 12)
end

function QuickAttachController:AttachSlot(item)
    if not item then return nil, { code = "ITEM_NOT_FOUND", message = "未指定背包物品" } end
    return self.attachmentService:AttachOne(item)
end

function QuickAttachController:FindCategoryItems(categoryId)
    if not self.scanner or not self.categoryRegistry then return {} end
    return self.scanner:Scan({
        predicate = function(item)
            return self.categoryRegistry:Matches(categoryId, item) == true
        end,
    }, { enabledBags = self.config.enabledBags })
end

function QuickAttachController:AttachCategory(categoryId)
    local items = self:FindCategoryItems(categoryId)
    if #items == 0 then return nil, { code = "CATEGORY_EMPTY", message = "启用背包中没有该分类的可邮寄物品" } end
    return self.attachmentService:AttachMany(items, _G.ATTACHMENTS_MAX_SEND or 12)
end

function QuickAttachController:SetDefaultRecipient(categoryId, recipient)
    if categoryId == nil then return nil, { code = "INVALID_CATEGORY", message = "物品分类无效" } end
    if recipient == nil then
        self.config.recipientByCategory[categoryId] = nil
        return true
    end
    local normalized = recipient
    if self.recipientRepository then
        local err
        normalized, err = self.recipientRepository:Normalize(recipient, "contact")
        if not normalized then return nil, err end
    elseif type(recipient) ~= "table" or type(recipient.name) ~= "string" or recipient.name == "" then
        return nil, { code = "INVALID_RECIPIENT", message = "默认收件人无效" }
    end
    self.config.recipientByCategory[categoryId] = clone(normalized)
    return true
end

function QuickAttachController:GetDefaultRecipient(categoryId)
    return clone(self.config.recipientByCategory[categoryId])
end

function QuickAttachController:SetBagEnabled(bag, enabled)
    self.config.enabledBags[bag] = enabled == true
end

Mail.QuickAttachController = QuickAttachController
Mail.ItemCategoryRegistry = Mail.ItemCategoryRegistry or ItemCategoryRegistry
