local _, ns = ...

local Pro = ns.EasyAuctionPro
if not Pro then return end

local function GetProDB()
    return Pro.InitDB()
end

local function NormalizeItemID(itemID)
    itemID = tonumber(itemID)
    if not itemID or itemID <= 0 then
        return nil
    end
    return tostring(itemID)
end

local function NormalizeText(value)
    value = tostring(value or "")
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    if value == "" then
        return nil
    end
    return value
end

function Pro.CleanupGroupBindings()
    local pro = GetProDB()
    if not pro then
        return 0
    end

    local cleaned = 0
    pro.groups = pro.groups or {}
    pro.itemGroups = pro.itemGroups or {}
    pro.categoryGroups = pro.categoryGroups or {}

    for itemID, assignedGroup in pairs(pro.itemGroups) do
        if not assignedGroup or not pro.groups[assignedGroup] then
            pro.itemGroups[itemID] = nil
            cleaned = cleaned + 1
        end
    end

    for categoryName, assignedGroup in pairs(pro.categoryGroups) do
        if not assignedGroup or not pro.groups[assignedGroup] then
            pro.categoryGroups[categoryName] = nil
            cleaned = cleaned + 1
        end
    end

    for groupName, group in pairs(pro.groups) do
        group.items = group.items or {}
        for itemID in pairs(group.items) do
            if pro.itemGroups[tostring(itemID)] ~= groupName then
                group.items[itemID] = nil
            end
        end
    end

    return cleaned
end

function Pro.GetItemGroup(itemID)
    local pro = GetProDB()
    local key = NormalizeItemID(itemID)
    if not pro or not key then
        return nil
    end
    local groupName = pro.itemGroups[key]
    if groupName and pro.groups[groupName] then
        return groupName
    end
    if groupName then
        pro.itemGroups[key] = nil
    end
    return Pro.GetDefaultGroupName()
end

function Pro.GetCategoryGroup(categoryName)
    local pro = GetProDB()
    categoryName = NormalizeText(categoryName)
    if not pro or not categoryName then
        return nil
    end
    local groupName = pro.categoryGroups and pro.categoryGroups[categoryName]
    if groupName and pro.groups[groupName] then
        return groupName
    end
    if groupName then
        pro.categoryGroups[categoryName] = nil
    end
    return nil
end

function Pro.CreateGroup(groupName, operationName)
    local pro = GetProDB()
    groupName = NormalizeText(groupName)
    if not pro or not groupName then
        return false
    end
    operationName = NormalizeText(operationName) or Pro.GetDefaultOperationName()
    if not pro.auctionOps[operationName] then
        operationName = Pro.GetDefaultOperationName()
    end
    pro.groups[groupName] = pro.groups[groupName] or {
        items = {},
        auctionOp = operationName,
    }
    pro.groups[groupName].items = pro.groups[groupName].items or {}
    pro.groups[groupName].auctionOp = pro.groups[groupName].auctionOp or operationName
    return true
end

function Pro.DeleteGroup(groupName)
    local pro = GetProDB()
    groupName = NormalizeText(groupName)
    if not pro or not groupName or groupName == Pro.GetDefaultGroupName() then
        return false
    end
    if not pro.groups[groupName] then
        return false
    end

    pro.groups[groupName] = nil
    for itemID, assignedGroup in pairs(pro.itemGroups or {}) do
        if assignedGroup == groupName then
            pro.itemGroups[itemID] = nil
        end
    end
    for categoryName, assignedGroup in pairs(pro.categoryGroups or {}) do
        if assignedGroup == groupName then
            pro.categoryGroups[categoryName] = nil
        end
    end
    Pro.CleanupGroupBindings()
    return true
end

function Pro.SetItemGroup(itemID, groupName)
    local pro = GetProDB()
    local key = NormalizeItemID(itemID)
    groupName = NormalizeText(groupName)
    if not pro or not key or not groupName or groupName == "" then
        return false
    end

    Pro.CreateGroup(groupName)
    local oldGroupName = pro.itemGroups[key]
    if oldGroupName and oldGroupName ~= groupName and pro.groups[oldGroupName] and pro.groups[oldGroupName].items then
        pro.groups[oldGroupName].items[key] = nil
    end
    pro.itemGroups[key] = groupName
    pro.groups[groupName].items[key] = true
    return true
end

function Pro.SetCategoryGroup(categoryName, groupName)
    local pro = GetProDB()
    categoryName = NormalizeText(categoryName)
    groupName = NormalizeText(groupName)
    if not pro or not categoryName or not groupName then
        return false
    end
    Pro.CreateGroup(groupName)
    pro.categoryGroups = pro.categoryGroups or {}
    pro.categoryGroups[categoryName] = groupName
    return true
end

function Pro.BindCategoryItems(categoryName, groupName)
    local pro = GetProDB()
    categoryName = NormalizeText(categoryName)
    groupName = NormalizeText(groupName)
    if not pro or not categoryName or not groupName then
        return 0
    end

    local entries
    if categoryName == "常用" then
        entries = {}
        local favorites = Pro.GetDB() and Pro.GetDB().FavoriteItems or {}
        for itemID, info in pairs(favorites or {}) do
            entries[#entries + 1] = { info and info.name or tostring(itemID), tonumber(itemID) }
        end
    else
        local db = Pro.GetDB()
        entries = db and db.CategoryOverrides and db.CategoryOverrides[categoryName] or nil
        if type(entries) ~= "table" and type(ns.EA_CATEGORY_LIST) == "table" then
            entries = ns.EA_CATEGORY_LIST[categoryName]
        end
    end
    if type(entries) ~= "table" then
        return 0
    end

    Pro.SetCategoryGroup(categoryName, groupName)
    local count = 0
    for _, entry in ipairs(entries) do
        local itemID = entry and entry[2]
        if itemID and Pro.SetItemGroup(itemID, groupName) then
            count = count + 1
        end
    end
    return count
end

function Pro.SetGroupAuctionOperation(groupName, operationName)
    local pro = GetProDB()
    groupName = NormalizeText(groupName)
    if not pro or not groupName or groupName == "" then
        return false
    end
    operationName = NormalizeText(operationName) or Pro.GetDefaultOperationName()
    if not pro.auctionOps[operationName] then
        return false
    end
    pro.groups[groupName] = pro.groups[groupName] or {
        items = {},
        auctionOp = operationName,
    }
    pro.groups[groupName].auctionOp = operationName
    return true
end

function Pro.RenameGroup(oldName, newName, operationName)
    local pro = GetProDB()
    oldName = NormalizeText(oldName)
    newName = NormalizeText(newName)
    if not pro or not oldName or not newName then
        return false
    end
    if oldName == Pro.GetDefaultGroupName() then
        return false
    end
    if not pro.groups[oldName] then
        return false
    end

    operationName = NormalizeText(operationName) or Pro.GetDefaultOperationName()
    if not pro.auctionOps[operationName] then
        operationName = Pro.GetDefaultOperationName()
    end

    if oldName == newName then
        return Pro.SetGroupAuctionOperation(newName, operationName), "updated"
    end

    local source = pro.groups[oldName]
    local merged = pro.groups[newName] ~= nil
    pro.groups[newName] = pro.groups[newName] or {
        items = {},
        auctionOp = operationName,
    }
    pro.groups[newName].items = pro.groups[newName].items or {}
    pro.groups[newName].auctionOp = operationName

    for itemID in pairs(source.items or {}) do
        pro.groups[newName].items[itemID] = true
    end
    for itemID, assignedGroup in pairs(pro.itemGroups or {}) do
        if assignedGroup == oldName then
            pro.itemGroups[itemID] = newName
            pro.groups[newName].items[tostring(itemID)] = true
        end
    end
    for categoryName, assignedGroup in pairs(pro.categoryGroups or {}) do
        if assignedGroup == oldName then
            pro.categoryGroups[categoryName] = newName
        end
    end

    pro.groups[oldName] = nil
    Pro.CleanupGroupBindings()
    return true, merged and "merged" or "renamed"
end

function Pro.GetGroup(groupName)
    local pro = GetProDB()
    if not pro then
        return nil
    end
    groupName = NormalizeText(groupName) or Pro.GetDefaultGroupName()
    if not pro.groups[groupName] then
        groupName = Pro.GetDefaultGroupName()
    end
    return pro.groups[groupName]
end

function _G.EasyAuctionPro_GetItemGroup(itemID)
    return Pro.GetItemGroup(itemID)
end

function _G.EasyAuctionPro_SetItemGroup(itemID, groupName)
    return Pro.SetItemGroup(itemID, groupName)
end

function _G.EasyAuctionPro_SetGroupAuctionOperation(groupName, operationName)
    return Pro.SetGroupAuctionOperation(groupName, operationName)
end

function _G.EasyAuctionPro_SetCategoryGroup(categoryName, groupName)
    return Pro.SetCategoryGroup(categoryName, groupName)
end

function _G.EasyAuctionPro_CreateGroup(groupName, operationName)
    return Pro.CreateGroup(groupName, operationName)
end

function _G.EasyAuctionPro_DeleteGroup(groupName)
    return Pro.DeleteGroup(groupName)
end

function _G.EasyAuctionPro_RenameGroup(oldName, newName, operationName)
    return Pro.RenameGroup(oldName, newName, operationName)
end
