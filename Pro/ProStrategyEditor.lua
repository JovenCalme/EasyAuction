local _, ns = ...

local Pro = ns.EasyAuctionPro
if not Pro then return end

local SOURCE_HINT = "价格源、策略、物品与分类可通过下拉菜单选择；输入框保留为新建或兜底。"

local PRICE_SOURCES = {
    { value = "median7d", label = "7日中位价" },
    { value = "currentMin", label = "当前最低价" },
    { value = "historyMin", label = "历史最低价" },
    { value = "yesterdayMin", label = "昨日最低价" },
    { value = "fixed", label = "固定价" },
}

local ITEM_SOURCES = {
    { value = "bag", label = "背包" },
    { value = "favorite", label = "常用" },
    { value = "price", label = "价格库" },
    { value = "history", label = "历史" },
    { value = "all", label = "全部" },
}

local QUALITY_COLORS = (_G and _G.ITEM_QUALITY_COLORS) or {
    [0] = { r = 0.62, g = 0.62, b = 0.62 },
    [1] = { r = 1.00, g = 1.00, b = 1.00 },
    [2] = { r = 0.12, g = 1.00, b = 0.00 },
    [3] = { r = 0.00, g = 0.44, b = 0.87 },
    [4] = { r = 0.64, g = 0.21, b = 0.93 },
    [5] = { r = 1.00, g = 0.50, b = 0.00 },
}

local ITEM_CLASS_NAMES = {
    [0] = "消耗",
    [1] = "容器",
    [2] = "武器",
    [3] = "宝石",
    [4] = "护甲",
    [7] = "商品",
    [9] = "配方",
    [15] = "杂项",
}

local ITEM_CATEGORY_ORDER = { "商品", "武器", "护甲", "消耗", "宝石", "配方", "容器", "杂项", "其他" }
local ITEM_CHOICES_PER_PAGE = 84
local OPERATION_LIST_PAGE_SIZE = 10
local GROUP_LIST_PAGE_SIZE = 9

local STRATEGY_DESCRIPTIONS = {
    ["默认策略"] = "适合大多数物品：\n参考7日中位价，少量上架，避免跟随离谱高价或低价。",
    ["快速出手"] = "适合想尽快卖掉的物品：\n贴近当前最低价，价格更主动。",
    ["稳价上架"] = "适合不急卖的材料和装备：\n保护底价，低于底价时队列会提示跳过。",
    ["材料薄利"] = "适合布、草药、矿石等材料：\n堆叠和上架上限更高，薄利多销。",
    ["高价试挂"] = "适合稀有装备、图纸和不确定价格物品：\n少量试挂，不铺太多库存。",
    ["消耗品清仓"] = "适合节日物品、药剂、卷轴等清仓：\n更贴近当前行情，快速回笼金币。",
}

local FIELDS = {
    { key = "minPriceSource", label = "最低价源", kind = "source" },
    { key = "minPricePct", label = "最低价%", kind = "percent" },
    { key = "minPriceFixed", label = "固定底价", kind = "money" },
    { key = "normalPriceSource", label = "正常价源", kind = "source" },
    { key = "normalPricePct", label = "正常价%", kind = "percent" },
    { key = "normalPriceFixed", label = "固定正常价", kind = "money" },
    { key = "maxPriceSource", label = "最高价源", kind = "source" },
    { key = "maxPricePct", label = "最高价%", kind = "percent" },
    { key = "maxPriceFixed", label = "固定最高价", kind = "money" },
    { key = "undercutAmount", label = "压价铜", kind = "number" },
    { key = "ignoreLowPricePct", label = "异常低价%", kind = "percent" },
    { key = "ignoreLowQuantity", label = "异常低价数量", kind = "number" },
    { key = "keepQuantity", label = "保留数量", kind = "number" },
    { key = "postCap", label = "上架上限", kind = "number" },
    { key = "stackSize", label = "堆叠数", kind = "number" },
    { key = "numStacks", label = "组数", kind = "number" },
    { key = "duration", label = "时长(1-3)", kind = "number" },
}

local dropdownIndex = 0

local function Trim(value)
    value = tostring(value or "")
    local trimmed = value:gsub("^%s+", "")
    trimmed = trimmed:gsub("%s+$", "")
    return trimmed
end

local function SortedKeys(tbl)
    local keys = {}
    for key in pairs(tbl or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

local function ClampListPage(page, itemCount, pageSize)
    local totalPages = math.max(1, math.ceil((itemCount or 0) / pageSize))
    page = tonumber(page) or 1
    if page < 1 then
        page = 1
    elseif page > totalPages then
        page = totalPages
    end
    return page, totalPages
end

local function FindPageForValue(keys, value, pageSize)
    if not value then
        return nil
    end
    for index, key in ipairs(keys or {}) do
        if key == value then
            return math.ceil(index / pageSize)
        end
    end
    return nil
end

local function ParseItemKey(key)
    key = tostring(key or "")
    local itemID = tonumber(key:match(":(%d+)$"))
    local itemName = itemID and key:gsub(":%d+$", "") or key
    if itemName == "" then
        itemName = nil
    end
    return itemName, itemID
end

local function MakeItemKey(itemName, itemID)
    if itemName and itemName ~= "" and itemID then
        return itemName .. ":" .. tostring(itemID)
    end
    return itemName
end

local function SetStatus(frame, text, ok)
    if not frame or not frame.status then
        return
    end
    if ok == false then
        frame.status:SetText("|cffff6060" .. text .. "|r")
    else
        frame.status:SetText("|cff60ff60" .. text .. "|r")
    end
end

local function EnsureDeleteConfirmDialogs()
    local dialogs = _G.StaticPopupDialogs
    if not dialogs then
        return
    end

    dialogs.EASYAUCTIONPRO_DELETE_OPERATION = dialogs.EASYAUCTIONPRO_DELETE_OPERATION or {
        text = "|cffff4040删除策略模板|r\n\n确定要删除“%s”吗？\n引用该模板的策略组会自动切回默认策略。",
        button1 = "确认删除",
        button2 = "取消",
        OnAccept = function(_, data)
            if data and data.callback then
                data.callback(data.frame, data.name)
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    dialogs.EASYAUCTIONPRO_DELETE_GROUP = dialogs.EASYAUCTIONPRO_DELETE_GROUP or {
        text = "|cffff4040删除策略组|r\n\n确定要删除“%s”吗？\n该组的单物品绑定和分类绑定会被清理。",
        button1 = "确认删除",
        button2 = "取消",
        OnAccept = function(_, data)
            if data and data.callback then
                data.callback(data.frame, data.name)
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

local function ShowDeleteConfirm(dialogName, displayName, frame, callback)
    EnsureDeleteConfirmDialogs()
    local dialogs = _G.StaticPopupDialogs
    local showPopup = _G.StaticPopup_Show
    if dialogs and dialogs[dialogName] and showPopup then
        showPopup(dialogName, displayName, nil, {
            frame = frame,
            name = displayName,
            callback = callback,
        })
    elseif callback then
        callback(frame, displayName)
    end
end

local function GetStrategyDescription(operationName)
    return STRATEGY_DESCRIPTIONS[operationName] or "自定义策略：使用你保存的价格源、比例、堆叠和上架上限。"
end

local function GetOperationBrief(operation)
    if type(operation) ~= "table" then
        return ""
    end
    return string.format(
        "底价 %.0f%% / 正常 %.0f%% / 最高 %.0f%%，每组 %d 个，上架 %d 组，保留 %d 个。",
        (tonumber(operation.minPricePct) or 0) * 100,
        (tonumber(operation.normalPricePct) or 0) * 100,
        (tonumber(operation.maxPricePct) or 0) * 100,
        tonumber(operation.stackSize) or 0,
        tonumber(operation.numStacks) or 0,
        tonumber(operation.keepQuantity) or 0
    )
end

local function GetSourceLabel(value)
    for _, choice in ipairs(PRICE_SOURCES) do
        if choice.value == value then
            return choice.label
        end
    end
    return tostring(value or "")
end

local function FormatPct(value)
    return string.format("%.0f%%", (tonumber(value) or 0) * 100)
end

local function UpdateRuleText(frame, operation)
    if not frame or not frame.ruleText then
        return
    end
    if type(operation) ~= "table" then
        frame.ruleText:SetText("当前策略无可显示的计算规则。")
        return
    end
    local lowQty = tonumber(operation.ignoreLowQuantity) or 0
    local lowQtyText = lowQty > 0 and ("且这一档数量不超过 " .. lowQty .. " 个") or "无论这一档有多少数量"
    local lines = {
        string.format(
            "1. 价格线：底价=%s x %s；正常价=%s x %s；最高价=%s x %s。",
            GetSourceLabel(operation.minPriceSource),
            FormatPct(operation.minPricePct),
            GetSourceLabel(operation.normalPriceSource),
            FormatPct(operation.normalPricePct),
            GetSourceLabel(operation.maxPriceSource),
            FormatPct(operation.maxPricePct)
        ),
        string.format(
            "2. 合理最低价：从当前最低价往上找；低于参考价 %s，%s，就跳过这一档。",
            FormatPct(operation.ignoreLowPricePct),
            lowQtyText
        ),
        string.format(
            "3. 建议单价：合理最低价 - %d 铜；低于底价就不跟价，高于最高价就封顶。",
            tonumber(operation.undercutAmount) or 0
        ),
        string.format(
            "4. 上架数量：库存先保留 %d 个；每组 %d 个，最多 %d 组。",
            tonumber(operation.keepQuantity) or 0,
            tonumber(operation.stackSize) or 0,
            tonumber(operation.numStacks) or 0
        ),
    }
    frame.ruleText:SetText(table.concat(lines, "\n"))
end

local function CreateLabel(parent, text, point, relativeTo, relativePoint, x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint(point, relativeTo or parent, relativePoint or point, x or 0, y or 0)
    fs:SetText(text)
    fs:SetJustifyH("LEFT")
    if Pro.SkinText then Pro.SkinText(fs, "muted", 11) end
    return fs
end

local function CreateEditBox(parent, width, height)
    local edit = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    edit:SetSize(width or 120, height or 20)
    edit:SetAutoFocus(false)
    edit:SetFontObject(ChatFontNormal)
    edit:SetScript("OnEscapePressed", edit.ClearFocus)
    edit:SetScript("OnEnterPressed", edit.ClearFocus)
    if Pro.SkinEditBox then Pro.SkinEditBox(edit) end
    return edit
end

local function CreateButton(parent, text, width, height)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width or 80, height or 22)
    btn:SetText(text)
    if Pro.SkinButton then Pro.SkinButton(btn) end
    return btn
end

local function CreatePanel(parent, x, y, width, height)
    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    panel:SetPoint("TOPLEFT", parent, "TOPLEFT", x or 0, y or 0)
    panel:SetSize(width or 100, height or 100)
    if Pro.SkinFrame then Pro.SkinFrame(panel, "panel") end
    return panel
end

local function CreateSectionTitle(parent, text, x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x or 0, y or 0)
    fs:SetText(text)
    fs:SetJustifyH("LEFT")
    if Pro.SkinText then Pro.SkinText(fs, "accent", 13) end
    return fs
end

local function CreateDivider(parent, point, relativeTo, relativePoint, x, y, width, height)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetPoint(point, relativeTo or parent, relativePoint or point, x or 0, y or 0)
    line:SetSize(width or 1, height or 1)
    local style = Pro.GetStyle and Pro.GetStyle()
    if style and style.OnTheme then
        style:OnTheme(function(p)
            line:SetColorTexture(p.border[1], p.border[2], p.border[3], 0.75)
        end)
    elseif style and style.Palette then
        local p = style:Palette()
        line:SetColorTexture(p.border[1], p.border[2], p.border[3], 0.75)
    else
        line:SetColorTexture(0.25, 0.25, 0.30, 0.75)
    end
    return line
end

local function SetFrameShown(frame, shown)
    if not frame then
        return
    end
    if shown then
        frame:Show()
    else
        frame:Hide()
    end
end

local function RegisterTabFrame(frame, tabName, ui)
    frame.tabFrames = frame.tabFrames or {}
    frame.tabFrames[tabName] = frame.tabFrames[tabName] or {}
    frame.tabFrames[tabName][#frame.tabFrames[tabName] + 1] = ui
end

local function SetItemButtonIcon(button, icon)
    icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark"
    if type(SetItemButtonTexture) == "function" then
        SetItemButtonTexture(button, icon)
    end
    local texture = button and (button.icon or button.Icon or button.texture)
    if not texture and button and button.GetNormalTexture then
        texture = button:GetNormalTexture()
    end
    if texture and texture.SetTexture then
        texture:SetTexture(icon)
    end
end

local function GetControlValue(control)
    if control and control.GetValue then
        return control:GetValue()
    end
    if control and control.GetText then
        return control:GetText()
    end
    return nil
end

local function SetControlValue(control, value)
    if control and control.SetValue then
        control:SetValue(value)
    elseif control and control.SetText then
        control:SetText(tostring(value or ""))
    end
end

local function GetChoiceLabel(choices, value)
    for _, choice in ipairs(choices or {}) do
        if choice.value == value then
            return choice.label
        end
    end
    return tostring(value or "")
end

local function ResolveChoices(choices)
    if type(choices) == "function" then
        return choices()
    end
    return choices or {}
end

local function CreateDropdown(parent, width, choices, onSelect)
    dropdownIndex = dropdownIndex + 1
    local dropdown = CreateFrame(
        "Frame",
        "EasyAuctionProStrategyDropDown" .. dropdownIndex,
        parent,
        "UIDropDownMenuTemplate"
    )
    width = width or 120
    dropdown.EasyAuctionProVisualWidth = width
    dropdown:SetSize(width, 22)
    dropdown.choices = choices or {}
    local initialChoices = ResolveChoices(dropdown.choices)
    dropdown.value = initialChoices[1] and initialChoices[1].value or nil
    UIDropDownMenu_SetWidth(dropdown, width)
    dropdown:SetSize(width, 22)
    UIDropDownMenu_SetText(dropdown, GetChoiceLabel(initialChoices, dropdown.value))
    UIDropDownMenu_Initialize(dropdown, function(self, level)
        local list = ResolveChoices(dropdown.choices)
        for _, choice in ipairs(list or {}) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = choice.label
            info.value = choice.value
            info.func = function()
                dropdown:SetValue(choice.value, choice)
                if onSelect then
                    onSelect(choice.value, choice)
                end
                if Pro.ReskinDropDown then
                    Pro.ReskinDropDown(dropdown)
                end
            end
            UIDropDownMenu_AddButton(info, level)
        end
        if Pro.SkinDropDownMenu then
            Pro.SkinDropDownMenu(level, dropdown)
        end
    end)
    if Pro.SkinDropDown then
        Pro.SkinDropDown(dropdown)
    end
    local button = dropdown.Button or _G[dropdown:GetName() .. "Button"]
    if button then
        button:HookScript("OnClick", function()
            local timer = _G.C_Timer
            if timer and timer.After and Pro.ReskinDropDown then
                timer.After(0, function()
                    Pro.ReskinDropDown(dropdown)
                end)
            end
        end)
    end
    function dropdown:SetValue(value, choice)
        self.value = value
        local label
        if choice then
            label = choice.label
        else
            local list = ResolveChoices(self.choices)
            label = GetChoiceLabel(list, value)
        end
        UIDropDownMenu_SetText(self, label)
        if Pro.ReskinDropDown then
            Pro.ReskinDropDown(self)
        end
    end
    function dropdown:GetValue()
        return self.value
    end
    return dropdown
end

local function ReadFieldValue(control, kind)
    local value = Trim(GetControlValue(control))
    if kind == "percent" then
        return math.max(0, (tonumber(value) or 0) / 100)
    elseif kind == "number" or kind == "money" then
        return tonumber(value) or 0
    end
    return value
end

local function FormatFieldValue(field, value)
    if field.kind == "percent" then
        return tostring(math.floor((tonumber(value) or 0) * 100 + 0.5))
    end
    return tostring(value or "")
end

local function GetOperationChoices()
    local pro = Pro.InitDB()
    local choices = {}
    for _, operationName in ipairs(SortedKeys(pro and pro.auctionOps or {})) do
        choices[#choices + 1] = { value = operationName, label = operationName }
    end
    return choices
end

local function GetGroupChoices()
    local pro = Pro.InitDB()
    local choices = {}
    for _, groupName in ipairs(SortedKeys(pro and pro.groups or {})) do
        choices[#choices + 1] = { value = groupName, label = groupName }
    end
    return choices
end

local function GetCategoryChoices()
    local choices = { { value = "常用", label = "常用" } }
    local seen = { ["常用"] = true }
    local db = Pro.GetDB()
    for _, categoryName in ipairs(SortedKeys(ns.EA_CATEGORY_LIST or {})) do
        if not seen[categoryName] then
            choices[#choices + 1] = { value = categoryName, label = categoryName }
            seen[categoryName] = true
        end
    end
    for _, categoryName in ipairs(SortedKeys(db and db.CategoryOverrides or {})) do
        if not seen[categoryName] then
            choices[#choices + 1] = { value = categoryName, label = categoryName }
            seen[categoryName] = true
        end
    end
    return choices
end

local function GetItemSourceChoices()
    local choices = {}
    for _, choice in ipairs(ITEM_SOURCES) do
        choices[#choices + 1] = choice
    end
    for _, category in ipairs(GetCategoryChoices()) do
        choices[#choices + 1] = {
            value = "category:" .. category.value,
            label = "分类：" .. category.label,
        }
    end
    return choices
end

local function GetCategoryEntries(categoryName)
    local db = Pro.GetDB()
    if categoryName == "常用" then
        local entries = {}
        for itemID, info in pairs(db and db.FavoriteItems or {}) do
            entries[#entries + 1] = { info and info.name or tostring(itemID), tonumber(itemID) }
        end
        return entries
    end
    local overrides = db and db.CategoryOverrides and db.CategoryOverrides[categoryName]
    if type(overrides) == "table" then
        return overrides
    end
    if type(ns.EA_CATEGORY_LIST) == "table" then
        return ns.EA_CATEGORY_LIST[categoryName] or {}
    end
    return {}
end

local function GetItemChoices(filterText, sourceFilter)
    local db = Pro.GetDB()
    local choices = {}
    local seen = {}
    local filter = Trim(filterText):lower()
    sourceFilter = sourceFilter or "bag"
    local categoryFilter = sourceFilter:match("^category:(.+)$")

    local function sourceAllowed(source)
        if categoryFilter then
            return source == "category"
        end
        return sourceFilter == "all" or sourceFilter == source
    end

    local function matches(itemName, itemID, key)
        if filter == "" then
            return true
        end
        itemName = tostring(itemName or ""):lower()
        key = tostring(key or ""):lower()
        itemID = tostring(itemID or "")
        return itemName:find(filter, 1, true) or key:find(filter, 1, true) or itemID:find(filter, 1, true)
    end

    local function addItem(source, sourceLabel, itemName, itemID, key, count)
        itemName, itemID = itemName or ParseItemKey(key), itemID or select(2, ParseItemKey(key))
        key = key or MakeItemKey(itemName, itemID)
        if not key or seen[key] or not sourceAllowed(source) or not matches(itemName, itemID, key) then
            return
        end
        seen[key] = true
        local label = string.format("[%s] %s", sourceLabel, itemName or key)
        if itemID then
            label = label .. " #" .. tostring(itemID)
        end
        if count and count > 0 then
            label = label .. " x" .. tostring(count)
        end
        local displayName, itemLink, quality, icon, classID
        if itemID then
            displayName, itemLink, quality, _, _, _, _, _, _, icon, _, classID = GetItemInfo(itemID)
            if (not icon or icon == "") and type(GetItemIcon) == "function" then
                icon = GetItemIcon(itemID)
            end
        end
        choices[#choices + 1] = {
            value = key,
            label = label,
            itemName = displayName or itemName,
            itemID = itemID,
            key = key,
            count = count,
            source = source,
            sourceLabel = sourceLabel,
            itemLink = itemLink,
            quality = quality,
            icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark",
            category = ITEM_CLASS_NAMES[classID] or "其他",
        }
    end

    if sourceFilter == "bag" or sourceFilter == "all" then
        local queue = Pro.queue
        if (not queue or #queue == 0) and Pro.RefreshPostQueue then
            queue = Pro.RefreshPostQueue()
        end
        for _, row in ipairs(queue or {}) do
            addItem("bag", "背包", row.itemName, row.itemID, nil, row.bagCount)
        end
    end

    if sourceFilter == "favorite" or sourceFilter == "all" then
        for itemID, info in pairs(db and db.FavoriteItems or {}) do
            addItem("favorite", "常用", info and info.name, tonumber(itemID), nil, nil)
        end
    end

    if categoryFilter then
        for _, entry in ipairs(GetCategoryEntries(categoryFilter)) do
            addItem("category", "分类:" .. categoryFilter, entry and entry[1], entry and entry[2], nil, nil)
        end
    end

    if sourceFilter == "price" or sourceFilter == "all" then
        for key in pairs(db and db.DailyMinPrice or {}) do
            local itemName, itemID = ParseItemKey(key)
            addItem("price", "价格库", itemName, itemID, key, nil)
        end
    end

    if sourceFilter == "history" or sourceFilter == "all" then
        for key in pairs(db and db.PriceHistory or {}) do
            local itemName, itemID = ParseItemKey(key)
            addItem("history", "历史", itemName, itemID, key, nil)
        end
    end

    if #choices == 0 then
        choices[1] = { value = "", label = "暂无可选物品：请先扫描背包或拍卖行" }
    end
    table.sort(choices, function(a, b)
        return (a.label or "") < (b.label or "")
    end)
    return choices
end

local function SelectCalculatorItem(frame, choice)
    if not choice then
        return
    end
    frame.calcSelectedItem = choice
    frame.calcItemIDEdit:SetText(choice.itemID and tostring(choice.itemID) or "")
    frame.calcItemNameEdit:SetText(choice.itemName or "")
    if choice.count and choice.count > 0 then
        frame.calcCountEdit:SetText(tostring(choice.count))
    end
end

local function SelectBindItem(frame, choice)
    if not choice then
        return
    end
    frame.bindSelectedItem = choice
    frame.itemIDEdit:SetText(choice.itemID and tostring(choice.itemID) or "")
end

local function SelectItemForWorkPanel(frame, choice)
    if not choice or not choice.key or choice.key == "" then
        return
    end
    SelectBindItem(frame, choice)
    SelectCalculatorItem(frame, choice)
    if frame.selectedItemText then
        local selectedText = choice.itemName or choice.key
        if choice.count and choice.count > 0 then
            selectedText = selectedText .. " x" .. tostring(choice.count)
        end
        if choice.itemID then
            selectedText = selectedText .. " #" .. tostring(choice.itemID)
        end
        frame.selectedItemText:SetText("已选：" .. selectedText)
    end
end

local function BuildChoiceGroups(choices)
    local groups = {}
    local hasGroup = {}
    for _, category in ipairs(ITEM_CATEGORY_ORDER) do
        groups[category] = {}
    end
    for _, choice in ipairs(choices or {}) do
        if choice and choice.key and choice.key ~= "" then
            local category = choice.category or "其他"
            groups[category] = groups[category] or {}
            groups[category][#groups[category] + 1] = choice
            hasGroup[category] = true
        end
    end
    return groups, hasGroup
end

local function SetChoiceButtonSelected(button, selected)
    if button and button.selectedBorder then
        SetFrameShown(button.selectedBorder, selected)
    end
end

local function RefreshItemSearch(frame)
    if not frame or not frame.itemResultButtons then
        return
    end
    local filterText = frame.itemSearchEdit and frame.itemSearchEdit:GetText() or ""
    local source = frame.itemSourceDropDown and frame.itemSourceDropDown:GetValue() or "bag"
    local choices = GetItemChoices(filterText, source)
    local totalPages = math.max(1, math.ceil(#choices / ITEM_CHOICES_PER_PAGE))
    frame.itemPage = math.min(math.max(frame.itemPage or 1, 1), totalPages)
    local startIndex = (frame.itemPage - 1) * ITEM_CHOICES_PER_PAGE + 1
    local pageChoices = {}
    for i = startIndex, math.min(#choices, startIndex + ITEM_CHOICES_PER_PAGE - 1) do
        pageChoices[#pageChoices + 1] = choices[i]
    end
    local groups, hasGroup = BuildChoiceGroups(pageChoices)
    local buttons = frame.itemResultButtons
    local headers = frame.itemCategoryHeaders or {}
    local buttonIndex = 1
    local y = 0
    local iconSize, iconPadding = 32, 8
    local labelWidth, labelPadding = 40, 10
    local gridWidth = frame.itemGridWidth or 620
    local iconAreaWidth = math.max(iconSize, gridWidth - labelWidth - labelPadding - 6)
    local iconsPerRow = math.max(1, math.floor((iconAreaWidth + iconPadding) / (iconSize + iconPadding)))

    for _, button in ipairs(buttons) do
        button:Hide()
        button.choice = nil
    end
    for _, header in pairs(headers) do
        header:Hide()
    end

    for _, category in ipairs(ITEM_CATEGORY_ORDER) do
        local groupItems = groups[category] or {}
        if hasGroup[category] and #groupItems > 0 then
            local header = headers[category]
            if not header then
                header = frame.itemGridChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                header:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 13, "")
                headers[category] = header
                RegisterTabFrame(frame, "items", header)
            end
            header:ClearAllPoints()
            header:SetPoint("TOPLEFT", frame.itemGridChild, "TOPLEFT", labelPadding, -y - 7)
            header:SetText("|cffffd200" .. category .. "|r")
            header:Show()

            for index, choice in ipairs(groupItems) do
                local button = buttons[buttonIndex]
                if not button then
                    button = CreateFrame("Button", nil, frame.itemGridChild, "ItemButtonTemplate")
                    button:SetSize(iconSize, iconSize)
                    button:RegisterForClicks("LeftButtonUp")
                    button.selectedBorder = button:CreateTexture(nil, "OVERLAY")
                    button.selectedBorder:SetPoint("TOPLEFT", button, "TOPLEFT", -12, 12)
                    button.selectedBorder:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 12, -12)
                    button.selectedBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
                    button.selectedBorder:SetBlendMode("ADD")
                    button.selectedBorder:SetVertexColor(0, 1, 0, 0.9)
                    button.selectedBorder:Hide()
                    button:SetScript("OnClick", function(self)
                        SelectItemForWorkPanel(frame, self.choice)
                        for _, other in ipairs(frame.itemResultButtons or {}) do
                            SetChoiceButtonSelected(other, other.choice and frame.bindSelectedItem and
                                other.choice.key == frame.bindSelectedItem.key)
                        end
                    end)
                    button:SetScript("OnEnter", function(self)
                        if not self.choice then return end
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:ClearLines()
                        if self.choice.itemLink then
                            GameTooltip:SetHyperlink(self.choice.itemLink)
                        elseif self.choice.itemID then
                            GameTooltip:SetItemByID(self.choice.itemID)
                        else
                            GameTooltip:SetText(self.choice.itemName or self.choice.key or "", 1, 1, 1)
                        end
                        GameTooltip:AddLine(" ")
                        GameTooltip:AddDoubleLine("来源", self.choice.sourceLabel or "-", 1, 1, 1, 0.8, 0.8, 0.8)
                        if self.choice.count and self.choice.count > 0 then
                            GameTooltip:AddDoubleLine("数量", tostring(self.choice.count), 1, 1, 1, 0.8, 0.8, 0.8)
                        end
                        if self.choice.itemID then
                            GameTooltip:AddDoubleLine("物品ID", tostring(self.choice.itemID), 1, 1, 1, 0.8, 0.8, 0.8)
                        end
                        GameTooltip:AddLine("左键：选择该物品用于绑定和计算。", 1, 1, 1)
                        GameTooltip:Show()
                    end)
                    button:SetScript("OnLeave", function()
                        GameTooltip:Hide()
                    end)
                    buttons[buttonIndex] = button
                    RegisterTabFrame(frame, "items", button)
                end
                local col = (index - 1) % iconsPerRow
                local row = math.floor((index - 1) / iconsPerRow)
                button:ClearAllPoints()
                button:SetPoint(
                    "TOPLEFT",
                    frame.itemGridChild,
                    "TOPLEFT",
                    labelWidth + labelPadding + col * (iconSize + iconPadding),
                    -y - row * (iconSize + iconPadding)
                )
                button.choice = choice
                SetItemButtonIcon(button, choice.icon)
                SetItemButtonCount(button, choice.count or 0)
                local quality = choice.quality or 1
                local color = QUALITY_COLORS[quality] or QUALITY_COLORS[1]
                if choice.quality then
                    SetItemButtonQuality(button, choice.quality, choice.itemID)
                else
                    SetItemButtonQuality(button, nil)
                end
                SetChoiceButtonSelected(button, frame.bindSelectedItem and frame.bindSelectedItem.key == choice.key)
                if button.IconBorder then
                    button.IconBorder:SetVertexColor(color.r or 1, color.g or 1, color.b or 1, 0.9)
                end
                button:Show()
                buttonIndex = buttonIndex + 1
            end
            y = y + math.ceil(#groupItems / iconsPerRow) * (iconSize + iconPadding) + 6
        end
    end

    frame.itemCategoryHeaders = headers
    if frame.itemEmptyText then
        if buttonIndex == 1 then
            frame.itemEmptyText:SetText("没有匹配物品；换个来源或关键字")
            frame.itemEmptyText:Show()
        else
            frame.itemEmptyText:Hide()
        end
    end
    if frame.itemGridChild then
        frame.itemGridChild:SetWidth(gridWidth)
        frame.itemGridChild:SetHeight(math.max(frame.itemGridHeight or 178, y + 10))
    end
    if frame.itemPageText then
        frame.itemPageText:SetText(string.format("%d / %d", frame.itemPage, totalPages))
    end
    if frame.itemPrevBtn then
        frame.itemPrevBtn:SetEnabled(frame.itemPage > 1)
    end
    if frame.itemNextBtn then
        frame.itemNextBtn:SetEnabled(frame.itemPage < totalPages)
    end
end

local function LoadOperation(frame, operationName)
    local pro = Pro.InitDB()
    if not pro then
        return
    end
    operationName = Trim(operationName)
    if operationName == "" or not pro.auctionOps[operationName] then
        operationName = Pro.GetDefaultOperationName()
    end
    frame.selectedOperation = operationName
    frame.operationPage = FindPageForValue(
        SortedKeys(pro.auctionOps),
        operationName,
        OPERATION_LIST_PAGE_SIZE
    ) or frame.operationPage
    frame.operationNameEdit:SetText(operationName)
    local operation = pro.auctionOps[operationName] or {}
    for _, field in ipairs(FIELDS) do
        local control = frame.fieldEdits[field.key]
        if control then
            SetControlValue(control, FormatFieldValue(field, operation[field.key]))
        end
    end
    if frame.simpleTitle then
        frame.simpleTitle:SetText("当前方案：" .. operationName)
    end
    if frame.simpleDesc then
        frame.simpleDesc:SetText(GetStrategyDescription(operationName) .. "\n" .. GetOperationBrief(operation))
    end
    if frame.deleteBtn then
        frame.deleteBtn:SetEnabled(not (Pro.IsDefaultOperation and Pro.IsDefaultOperation(operationName)))
    end
    if frame.resetBtn then
        frame.resetBtn:SetEnabled(Pro.IsDefaultOperation and Pro.IsDefaultOperation(operationName))
    end
    UpdateRuleText(frame, operation)
    Pro.DrawStrategyEditor()
end

local function SaveOperation(frame)
    local operationName = Trim(frame.operationNameEdit:GetText())
    if operationName == "" then
        SetStatus(frame, "策略名不能为空", false)
        return
    end
    local values = {}
    for _, field in ipairs(FIELDS) do
        values[field.key] = ReadFieldValue(frame.fieldEdits[field.key], field.kind)
    end
    if Pro.UpdateAuctionOperation(operationName, values) then
        frame.selectedOperation = operationName
        local pro = Pro.InitDB()
        UpdateRuleText(frame, pro and pro.auctionOps and pro.auctionOps[operationName])
        SetStatus(frame, "已保存策略：" .. operationName, true)
        Pro.DrawStrategyEditor()
        if Pro.DrawPostQueue and Pro.queueFrame and Pro.queueFrame:IsShown() then
            Pro.RefreshPostQueue()
            Pro.DrawPostQueue()
        end
    else
        SetStatus(frame, "保存策略失败", false)
    end
end

local function CreateOperation(frame)
    local pro = Pro.InitDB()
    if not pro then
        SetStatus(frame, "数据库未就绪，无法新建策略。", false)
        return
    end

    local index = 1
    local operationName
    repeat
        operationName = "自定义策略" .. tostring(index)
        index = index + 1
    until not pro.auctionOps[operationName]

    if frame.operationNameEdit then
        frame.operationNameEdit:SetText(operationName)
    end
    SaveOperation(frame)
end

local function ResetOperation(frame)
    local operationName = Trim(frame.operationNameEdit:GetText())
    if Pro.ResetAuctionOperation and Pro.ResetAuctionOperation(operationName) then
        LoadOperation(frame, operationName)
        SetStatus(frame, "已恢复默认策略：" .. operationName, true)
    else
        SetStatus(frame, "该策略没有内置默认模板", false)
    end
end

local function DoDeleteOperation(frame, operationName)
    operationName = Trim(operationName)
    if Pro.DeleteAuctionOperation and Pro.DeleteAuctionOperation(operationName) then
        frame.selectedOperation = Pro.GetDefaultOperationName()
        LoadOperation(frame, frame.selectedOperation)
        SetStatus(frame, "已删除自定义策略：" .. operationName .. "；相关策略组已切回默认策略。", true)
        if Pro.DrawPostQueue and Pro.queueFrame and Pro.queueFrame:IsShown() then
            Pro.RefreshPostQueue()
            Pro.DrawPostQueue()
        end
    else
        SetStatus(frame, "删除策略失败，请确认它是自定义策略且未被系统保护。", false)
    end
end

local function DeleteOperation(frame)
    local operationName = Trim(frame.operationNameEdit:GetText())
    if operationName == "" then
        SetStatus(frame, "请先选择要删除的策略。", false)
        return
    end
    if Pro.IsDefaultOperation and Pro.IsDefaultOperation(operationName) then
        SetStatus(frame, "内置策略模板不能删除，可用“恢复默认”重置参数。", false)
        return
    end
    ShowDeleteConfirm("EASYAUCTIONPRO_DELETE_OPERATION", operationName, frame, DoDeleteOperation)
end

local function SelectStrategyGroup(frame, groupName)
    local pro = Pro.InitDB()
    groupName = Trim(groupName)
    if groupName == "" or not pro or not pro.groups[groupName] then
        groupName = Pro.GetDefaultGroupName()
    end
    frame.selectedGroup = groupName
    frame.groupPage = FindPageForValue(
        SortedKeys(pro.groups),
        groupName,
        GROUP_LIST_PAGE_SIZE
    ) or frame.groupPage
    if frame.groupNameEdit then
        frame.groupNameEdit:SetText(groupName)
    end
    local group = pro and pro.groups[groupName]
    local operationName = group and group.auctionOp or Pro.GetDefaultOperationName()
    if frame.groupOperationDropDown then
        frame.groupOperationDropDown:SetValue(operationName)
    end
    if frame.groupSummary then
        local itemCount = 0
        for _, assignedGroup in pairs(pro.itemGroups or {}) do
            if assignedGroup == groupName then
                itemCount = itemCount + 1
            end
        end
        frame.groupSummary:SetText(string.format(
            "当前组：%s\n使用策略：%s\n已绑定物品：%d 个",
            groupName,
            operationName,
            itemCount
        ))
    end
    if frame.groupDeleteBtn then
        frame.groupDeleteBtn:SetEnabled(groupName ~= Pro.GetDefaultGroupName())
    end
end

local function StartNewStrategyGroup(frame)
    local pro = Pro.InitDB()
    local index = 1
    local groupName
    repeat
        groupName = "新策略组" .. tostring(index)
        index = index + 1
    until not pro or not pro.groups[groupName]
    frame.selectedGroup = nil
    frame.groupNameEdit:SetText(groupName)
    frame.groupOperationDropDown:SetValue(Pro.GetDefaultOperationName())
    if frame.groupSummary then
        frame.groupSummary:SetText("正在新建策略组；填写名称并点击“保存”。")
    end
    if frame.groupDeleteBtn then
        frame.groupDeleteBtn:SetEnabled(false)
    end
end

local function SaveStrategyGroup(frame)
    local groupName = Trim(frame.groupNameEdit:GetText())
    local operationName = Trim(GetControlValue(frame.groupOperationDropDown))
    local pro = Pro.InitDB()
    local oldName = Trim(frame.selectedGroup or "")
    if groupName == "" then
        SetStatus(frame, "请先填写策略组名称。", false)
        return
    end
    if operationName == "" then
        operationName = Pro.GetDefaultOperationName()
    end

    local isRenamingGroup = oldName ~= "" and oldName ~= groupName and
        oldName ~= Pro.GetDefaultGroupName() and pro and pro.groups[oldName]
    if isRenamingGroup then
        local ok, mode = Pro.RenameGroup(oldName, groupName, operationName)
        if ok then
            frame.selectedGroup = groupName
            if mode == "merged" then
                SetStatus(frame, "已合并策略组：" .. oldName .. " -> " .. groupName, true)
            else
                SetStatus(frame, "已重命名策略组：" .. oldName .. " -> " .. groupName, true)
            end
            Pro.DrawStrategyEditor()
        else
            SetStatus(frame, "重命名策略组失败，请确认策略存在。", false)
        end
        return
    end

    if Pro.CreateGroup(groupName, operationName) and Pro.SetGroupAuctionOperation(groupName, operationName) then
        frame.selectedGroup = groupName
        SetStatus(frame, "已保存策略组：" .. groupName, true)
        Pro.DrawStrategyEditor()
    else
        SetStatus(frame, "保存策略组失败，请确认策略存在。", false)
    end
end

local function DoDeleteStrategyGroup(frame, groupName)
    groupName = Trim(groupName)
    if Pro.DeleteGroup and Pro.DeleteGroup(groupName) then
        frame.selectedGroup = Pro.GetDefaultGroupName()
        SetStatus(frame, "已删除策略组：" .. groupName, true)
        Pro.DrawStrategyEditor()
    else
        SetStatus(frame, "删除策略组失败。", false)
    end
end

local function DeleteSelectedStrategyGroup(frame)
    local groupName = Trim(frame.selectedGroup or frame.groupNameEdit:GetText())
    if groupName == "" then
        SetStatus(frame, "请先选择要删除的策略组。", false)
        return
    end
    if groupName == Pro.GetDefaultGroupName() then
        SetStatus(frame, "默认分组不能删除。", false)
        return
    end
    ShowDeleteConfirm("EASYAUCTIONPRO_DELETE_GROUP", groupName, frame, DoDeleteStrategyGroup)
end

local function BindItemGroup(frame)
    local itemID = tonumber(Trim(frame.itemIDEdit:GetText()))
    local groupName = Trim(GetControlValue(frame.itemGroupDropDown))
    if itemID and Pro.SetItemGroup(itemID, groupName) then
        SetStatus(frame, "已绑定物品：" .. itemID .. " -> " .. groupName, true)
        Pro.DrawStrategyEditor()
    else
        SetStatus(frame, "物品绑定失败", false)
    end
end

local function BindCategoryGroup(frame)
    local categoryName = Trim(GetControlValue(frame.categoryDropDown))
    local groupName = Trim(GetControlValue(frame.categoryGroupDropDown))
    local count = Pro.BindCategoryItems(categoryName, groupName)
    if count > 0 then
        SetStatus(frame, string.format("已绑定分类：%s -> %s（%d 个物品）", categoryName, groupName, count), true)
        Pro.DrawStrategyEditor()
    elseif Pro.SetCategoryGroup(categoryName, groupName) then
        SetStatus(frame, "已记录分类策略，未找到可批量绑定的分类清单", true)
        Pro.DrawStrategyEditor()
    else
        SetStatus(frame, "分类绑定失败", false)
    end
end

local function ShortReason(reason)
    reason = tostring(reason or "")
    if reason == "" then return "按策略" end
    if reason:find("高于最高价", 1, true) then return "高于上限，按封顶价" end
    if reason:find("低于最低价", 1, true) then return "低于底价，跳过" end
    if reason:find("异常低价", 1, true) then return "忽略异常低价" end
    if reason:find("当前最低价压价", 1, true) then return "跟随最低价压价" end
    if reason:find("保留数量", 1, true) then return "库存需保留" end
    if reason:find("流拍", 1, true) then return reason end
    if reason:find("缺少可用价格", 1, true) then return "缺少价格数据" end
    return reason
end

local function RunCalculator(frame)
    local itemID = tonumber(Trim(frame.calcItemIDEdit:GetText()))
    local itemName = Trim(frame.calcItemNameEdit:GetText())
    local bagCount = tonumber(Trim(frame.calcCountEdit:GetText())) or 1
    if itemName == "" and itemID then
        itemName = GetItemInfo(itemID) or ""
    end
    if not itemID or itemName == "" then
        frame.calcResult:SetText("|cffff6060请输入物品ID和物品名，或先让客户端缓存该物品。|r")
        return
    end
    local s = Pro.CalcPostSuggestion(itemID, itemName, bagCount)
    if not s then
        frame.calcResult:SetText("|cffff6060没有生成建议。|r")
        return
    end
    local statusText = s.status == "skip" and "|cffff6060跳过|r" or "|cff60ff60可上架|r"
    frame.calcResult:SetText(string.format(
        "建议价：%s  %s\n策略：%s  堆叠：%d x %d\n参考：市价 %s / 中位 %s\n原因：%s",
        Pro.FormatMoney(s.unitPrice or 0),
        statusText,
        s.operationName or "",
        s.stackSize or 0,
        s.numStacks or 0,
        Pro.FormatMoney(s.currentMin or 0),
        Pro.FormatMoney(s.median7d or 0),
        ShortReason(s.reason)
    ))
end

local function ShowCalculatorChart(frame)
    local itemID = tonumber(Trim(frame.calcItemIDEdit:GetText()))
    local itemName = Trim(frame.calcItemNameEdit:GetText())
    local key = frame.calcSelectedItem and frame.calcSelectedItem.key or MakeItemKey(itemName, itemID)
    if key and key ~= "" and type(_G.EasyAuction_ShowChart) == "function" then
        _G.EasyAuction_ShowChart(key)
    else
        SetStatus(frame, "没有可查看走势的物品。", false)
    end
end

local function SetAdvancedMode(frame, enabled)
    frame.advancedMode = enabled and true or false
    SetFrameShown(frame.operationNameLabel, frame.advancedMode)
    SetFrameShown(frame.operationNameEdit, frame.advancedMode)
    SetFrameShown(frame.createBtn, frame.advancedMode)
    SetFrameShown(frame.saveBtn, frame.advancedMode)
    SetFrameShown(frame.resetBtn, frame.advancedMode)
    SetFrameShown(frame.deleteBtn, frame.advancedMode)
    SetFrameShown(frame.operationDropDown, frame.advancedMode)
    for _, label in pairs(frame.fieldLabels or {}) do
        SetFrameShown(label, frame.advancedMode)
    end
    for _, control in pairs(frame.fieldEdits or {}) do
        SetFrameShown(control, frame.advancedMode)
    end
    if frame.advancedToggleBtn then
        frame.advancedToggleBtn:SetText(frame.advancedMode and "日常模式" or "高级调参")
    end
end

local function SetStrategyTab(frame, tabName)
    if tabName == "calculator" then
        tabName = "items"
    end
    frame.activeTab = tabName or "overview"
    for name, controls in pairs(frame.tabFrames or {}) do
        local shown = name == frame.activeTab
        for _, control in ipairs(controls) do
            SetFrameShown(control, shown)
        end
    end
    for name, btn in pairs(frame.tabButtons or {}) do
        btn:SetText(btn.rawText or "")
        if name == frame.activeTab then
            btn:SetNormalFontObject(GameFontHighlight)
        else
            btn:SetNormalFontObject(GameFontNormal)
        end
        if Pro.SetButtonActive then
            Pro.SetButtonActive(btn, name == frame.activeTab)
        end
    end
    SetAdvancedMode(frame, frame.activeTab == "advanced")
    SetFrameShown(frame.rulePanel, frame.activeTab == "advanced")
    if frame.activeTab == "items" then
        RefreshItemSearch(frame)
    end
end

local function CreateTabButton(frame, tabName, text, anchor, x, y)
    local btn = CreateButton(frame, text, 82, 22)
    btn.rawText = text
    btn:SetPoint("LEFT", anchor, "RIGHT", x or 6, y or 0)
    btn:SetScript("OnClick", function()
        SetStrategyTab(frame, tabName)
    end)
    frame.tabButtons = frame.tabButtons or {}
    frame.tabButtons[tabName] = btn
    return btn
end

local function CreateStrategyEditor()
    if Pro.strategyFrame then
        return Pro.strategyFrame
    end

    local f = CreateFrame("Frame", "EasyAuctionProStrategyFrame", UIParent, "BackdropTemplate")
    f:SetSize(720, 640)
    f:SetPoint("CENTER", 0, 10)
    if Pro.RaiseMainFrame then Pro.RaiseMainFrame(f) end
    Pro.ApplyFrameScale(f)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    if Pro.SkinFrame then Pro.SkinFrame(f, "window") end
    tinsert(UISpecialFrames, "EasyAuctionProStrategyFrame")

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", 14, -12)
    f.title:SetText("|cffffd200EasyAuction Pro|r 策略设置")
    if Pro.SkinText then Pro.SkinText(f.title, "accent", 14) end

    local closeBtn = Pro.CreateCloseButton and Pro.CreateCloseButton(f) or CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -8, -8)

    f.status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.status:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -6)
    f.status:SetWidth(640)
    f.status:SetJustifyH("LEFT")
    f.status:SetText(SOURCE_HINT)
    if Pro.SkinText then Pro.SkinText(f.status, "muted", 12) end

    f.rulePanel = CreatePanel(f, 18, -506, 676, 104)
    f.ruleTitle = CreateSectionTitle(f.rulePanel, "当前策略计算规则", 12, -8)
    f.ruleText = f.rulePanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.ruleText:SetPoint("TOPLEFT", f.rulePanel, "TOPLEFT", 12, -28)
    f.ruleText:SetWidth(652)
    f.ruleText:SetJustifyH("LEFT")
    f.ruleText:SetJustifyV("TOP")
    f.ruleText:SetText("")
    if Pro.SkinText then Pro.SkinText(f.ruleText, "muted", 11) end

    f.tabAnchor = CreateFrame("Frame", nil, f)
    f.tabAnchor:SetSize(1, 1)
    f.tabAnchor:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -52)
    local tab1 = CreateButton(f, "方案", 82, 22)
    tab1.rawText = "方案"
    tab1:SetPoint("TOPLEFT", f.tabAnchor, "TOPLEFT", 0, 0)
    tab1:SetScript("OnClick", function() SetStrategyTab(f, "overview") end)
    f.tabButtons = { overview = tab1 }
    CreateTabButton(f, "groups", "策略组", tab1, 6, 0)
    CreateTabButton(f, "items", "物品绑定", f.tabButtons.groups, 6, 0)
    CreateTabButton(f, "advanced", "高级调参", f.tabButtons.items, 6, 0)

    local operationTitle = CreateLabel(f, "方案管理", "TOPLEFT", f, "TOPLEFT", 18, -88)
    RegisterTabFrame(f, "overview", operationTitle)

    f.operationListPanel = CreatePanel(f, 18, -118, 210, 350)
    f.operationListTitle = CreateSectionTitle(f.operationListPanel, "策略模板列表", 12, -10)
    CreateDivider(f.operationListPanel, "TOPLEFT", f.operationListPanel, "TOPLEFT", 12, -34, 186, 1)
    f.operationPage = 1
    f.operationList = {}
    for i = 1, OPERATION_LIST_PAGE_SIZE do
        local btn = CreateButton(f.operationListPanel, "", 154, 24)
        btn:SetPoint("TOPLEFT", f.operationListPanel, "TOPLEFT", 14, -44 - (i - 1) * 28)
        btn:SetScript("OnClick", function(self)
            if self.operationName then
                LoadOperation(f, self.operationName)
            end
        end)
        f.operationList[i] = btn
        RegisterTabFrame(f, "overview", btn)
    end
    f.operationPrevBtn = CreateButton(f.operationListPanel, "▲", 24, 24)
    f.operationPrevBtn:SetPoint("TOPRIGHT", f.operationListPanel, "TOPRIGHT", -12, -44)
    f.operationPrevBtn:SetScript("OnClick", function()
        f.operationPage = math.max(1, (f.operationPage or 1) - 1)
        Pro.DrawStrategyEditor()
    end)
    f.operationNextBtn = CreateButton(f.operationListPanel, "▼", 24, 24)
    f.operationNextBtn:SetPoint("BOTTOMRIGHT", f.operationListPanel, "BOTTOMRIGHT", -12, 16)
    f.operationNextBtn:SetScript("OnClick", function()
        f.operationPage = (f.operationPage or 1) + 1
        Pro.DrawStrategyEditor()
    end)
    f.operationPageText = f.operationListPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.operationPageText:SetPoint("BOTTOMRIGHT", f.operationNextBtn, "TOPRIGHT", 0, 6)
    f.operationPageText:SetWidth(48)
    f.operationPageText:SetJustifyH("RIGHT")
    f.operationPageText:SetText("1/1")
    if Pro.SkinText then Pro.SkinText(f.operationPageText, "muted", 11) end
    for _, control in ipairs({ f.operationPrevBtn, f.operationNextBtn, f.operationPageText }) do
        RegisterTabFrame(f, "overview", control)
    end

    f.operationDetailPanel = CreatePanel(f, 240, -118, 454, 350)
    f.operationDetailTitle = CreateSectionTitle(f.operationDetailPanel, "当前方案", 12, -10)
    CreateDivider(f.operationDetailPanel, "TOPLEFT", f.operationDetailPanel, "TOPLEFT", 12, -34, 430, 1)
    f.simpleTitle = f.operationDetailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.simpleTitle:SetPoint("TOPLEFT", f.operationDetailPanel, "TOPLEFT", 16, -54)
    f.simpleTitle:SetWidth(414)
    f.simpleTitle:SetJustifyH("LEFT")
    f.simpleTitle:SetText("当前方案：默认策略")
    if Pro.SkinText then Pro.SkinText(f.simpleTitle, "accent", 14) end
    f.simpleDesc = f.operationDetailPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.simpleDesc:SetPoint("TOPLEFT", f.operationDetailPanel, "TOPLEFT", 16, -86)
    f.simpleDesc:SetWidth(414)
    f.simpleDesc:SetJustifyH("LEFT")
    f.simpleDesc:SetJustifyV("TOP")
    f.simpleDesc:SetText(GetStrategyDescription("默认策略"))
    if Pro.SkinText then Pro.SkinText(f.simpleDesc, "text", 12) end
    f.simpleSteps = f.operationDetailPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.simpleSteps:SetPoint("TOPLEFT", f.operationDetailPanel, "TOPLEFT", 16, -190)
    f.simpleSteps:SetWidth(414)
    f.simpleSteps:SetJustifyH("LEFT")
    f.simpleSteps:SetJustifyV("TOP")
    f.simpleSteps:SetText("操作方式：\n1. 左侧选择模板查看效果。\n2. 进入高级调参可新建、保存或删除自定义模板。\n3. 策略组页可把不同物品绑定到不同模板。")
    if Pro.SkinText then Pro.SkinText(f.simpleSteps, "muted", 12) end
    f.operationManageBtn = CreateButton(f.operationDetailPanel, "高级调参", 104, 24)
    f.operationManageBtn:SetPoint("BOTTOMLEFT", f.operationDetailPanel, "BOTTOMLEFT", 16, 16)
    f.operationManageBtn:SetScript("OnClick", function() SetStrategyTab(f, "advanced") end)
    f.operationGroupBtn = CreateButton(f.operationDetailPanel, "策略组", 86, 24)
    f.operationGroupBtn:SetPoint("LEFT", f.operationManageBtn, "RIGHT", 10, 0)
    f.operationGroupBtn:SetScript("OnClick", function() SetStrategyTab(f, "groups") end)
    for _, control in ipairs({
        f.operationListPanel, f.operationListTitle, f.operationDetailPanel, f.operationDetailTitle,
        f.simpleTitle, f.simpleDesc, f.simpleSteps, f.operationManageBtn, f.operationGroupBtn,
    }) do
        RegisterTabFrame(f, "overview", control)
    end

    f.advancedPanel = CreatePanel(f, 18, -88, 676, 404)
    f.advancedTitle = CreateSectionTitle(f.advancedPanel, "策略参数", 12, -10)
    f.advancedHint = f.advancedPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.advancedHint:SetPoint("LEFT", f.advancedTitle, "RIGHT", 10, 0)
    f.advancedHint:SetWidth(300)
    f.advancedHint:SetJustifyH("LEFT")
    --f.advancedHint:SetText("按 TokenTrend 的面板网格重排，价格源与上架规则分区显示。")
    if Pro.SkinText then Pro.SkinText(f.advancedHint, "muted", 11) end
    CreateDivider(f.advancedPanel, "TOPLEFT", f.advancedPanel, "TOPLEFT", 12, -35, 652, 1)

    f.operationNameLabel = CreateLabel(f.advancedPanel, "策略名", "TOPLEFT", f.advancedPanel, "TOPLEFT", 12, -50)
    f.operationNameEdit = CreateEditBox(f.advancedPanel, 150, 20)
    f.operationNameEdit:SetPoint("TOPLEFT", f.advancedPanel, "TOPLEFT", 64, -46)

    f.operationDropDown = CreateDropdown(f.advancedPanel, 128, GetOperationChoices, function(value)
        LoadOperation(f, value)
    end)
    f.operationDropDown:SetPoint("LEFT", f.operationNameEdit, "RIGHT", 8, -2)

    f.createBtn = CreateButton(f.advancedPanel, "新建", 62, 22)
    f.createBtn:SetPoint("TOPLEFT", f.advancedPanel, "TOPLEFT", 64, -70)
    f.createBtn:SetScript("OnClick", function() CreateOperation(f) end)

    f.saveBtn = CreateButton(f.advancedPanel, "保存", 62, 22)
    f.saveBtn:SetPoint("LEFT", f.createBtn, "RIGHT", 8, 0)
    f.saveBtn:SetScript("OnClick", function() SaveOperation(f) end)

    f.resetBtn = CreateButton(f.advancedPanel, "恢复默认", 76, 22)
    f.resetBtn:SetPoint("LEFT", f.saveBtn, "RIGHT", 8, 0)
    f.resetBtn:SetScript("OnClick", function() ResetOperation(f) end)

    f.deleteBtn = CreateButton(f.advancedPanel, "删除", 62, 22)
    f.deleteBtn:SetPoint("LEFT", f.resetBtn, "RIGHT", 8, 0)
    f.deleteBtn:SetScript("OnClick", function() DeleteOperation(f) end)

    f.pricePanel = CreatePanel(f.advancedPanel, 12, -96, 318, 298)
    f.postPanel = CreatePanel(f.advancedPanel, 346, -96, 318, 298)
    f.priceTitle = CreateSectionTitle(f.pricePanel, "价格区间", 12, -10)
    f.postTitle = CreateSectionTitle(f.postPanel, "上架规则", 12, -10)
    CreateDivider(f.pricePanel, "TOPLEFT", f.pricePanel, "TOPLEFT", 12, -34, 294, 1)
    CreateDivider(f.postPanel, "TOPLEFT", f.postPanel, "TOPLEFT", 12, -34, 294, 1)

    f.fieldEdits = {}
    f.fieldLabels = {}
    local priceFieldCount = 11
    for index, field in ipairs(FIELDS) do
        local panel = index <= priceFieldCount and f.pricePanel or f.postPanel
        local row = index <= priceFieldCount and index or index - priceFieldCount
        local y = -46 - (row - 1) * 23
        f.fieldLabels[field.key] = CreateLabel(panel, field.label, "TOPLEFT", panel, "TOPLEFT", 12, y)
        local control
        if field.kind == "source" then
            control = CreateDropdown(panel, 170, PRICE_SOURCES)
            control:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, y + 2)
        else
            control = CreateEditBox(panel, 128, 20)
            control:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, y + 4)
        end
        f.fieldEdits[field.key] = control
    end
    RegisterTabFrame(f, "advanced", f.advancedPanel)
    RegisterTabFrame(f, "advanced", f.operationNameLabel)
    RegisterTabFrame(f, "advanced", f.operationNameEdit)
    RegisterTabFrame(f, "advanced", f.operationDropDown)
    RegisterTabFrame(f, "advanced", f.createBtn)
    RegisterTabFrame(f, "advanced", f.saveBtn)
    RegisterTabFrame(f, "advanced", f.resetBtn)
    RegisterTabFrame(f, "advanced", f.deleteBtn)
    RegisterTabFrame(f, "advanced", f.advancedTitle)
    RegisterTabFrame(f, "advanced", f.advancedHint)
    RegisterTabFrame(f, "advanced", f.pricePanel)
    RegisterTabFrame(f, "advanced", f.postPanel)
    RegisterTabFrame(f, "advanced", f.priceTitle)
    RegisterTabFrame(f, "advanced", f.postTitle)

    local groupTitle = CreateLabel(f, "策略组管理", "TOPLEFT", f, "TOPLEFT", 18, -92)
    RegisterTabFrame(f, "groups", groupTitle)

    f.groupListPanel = CreatePanel(f, 18, -118, 210, 350)
    f.groupListTitle = CreateSectionTitle(f.groupListPanel, "策略组列表", 12, -10)
    CreateDivider(f.groupListPanel, "TOPLEFT", f.groupListPanel, "TOPLEFT", 12, -34, 186, 1)
    f.groupPage = 1
    f.groupButtons = {}
    for i = 1, GROUP_LIST_PAGE_SIZE do
        local btn = CreateButton(f.groupListPanel, "", 154, 24)
        btn:SetPoint("TOPLEFT", f.groupListPanel, "TOPLEFT", 14, -44 - (i - 1) * 28)
        btn:SetScript("OnClick", function(self)
            if self.groupName then
                SelectStrategyGroup(f, self.groupName)
                Pro.DrawStrategyEditor()
            end
        end)
        f.groupButtons[i] = btn
    end
    f.groupPrevBtn = CreateButton(f.groupListPanel, "▲", 24, 24)
    f.groupPrevBtn:SetPoint("TOPRIGHT", f.groupListPanel, "TOPRIGHT", -12, -44)
    f.groupPrevBtn:SetScript("OnClick", function()
        f.groupPage = math.max(1, (f.groupPage or 1) - 1)
        Pro.DrawStrategyEditor()
    end)
    f.groupNextBtn = CreateButton(f.groupListPanel, "▼", 24, 24)
    f.groupNextBtn:SetPoint("BOTTOMRIGHT", f.groupListPanel, "BOTTOMRIGHT", -12, 16)
    f.groupNextBtn:SetScript("OnClick", function()
        f.groupPage = (f.groupPage or 1) + 1
        Pro.DrawStrategyEditor()
    end)
    f.groupPageText = f.groupListPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.groupPageText:SetPoint("BOTTOMRIGHT", f.groupNextBtn, "TOPRIGHT", 0, 6)
    f.groupPageText:SetWidth(48)
    f.groupPageText:SetJustifyH("RIGHT")
    f.groupPageText:SetText("1/1")
    if Pro.SkinText then Pro.SkinText(f.groupPageText, "muted", 11) end

    f.groupEditorPanel = CreatePanel(f, 240, -118, 454, 350)
    f.groupEditorTitle = CreateSectionTitle(f.groupEditorPanel, "编辑当前策略组", 12, -10)
    CreateDivider(f.groupEditorPanel, "TOPLEFT", f.groupEditorPanel, "TOPLEFT", 12, -34, 430, 1)

    f.groupNameLabel = CreateLabel(f.groupEditorPanel, "组名", "TOPLEFT", f.groupEditorPanel, "TOPLEFT", 16, -58)
    f.groupNameEdit = CreateEditBox(f.groupEditorPanel, 260, 22)
    f.groupNameEdit:SetPoint("TOPLEFT", f.groupEditorPanel, "TOPLEFT", 78, -54)
    f.groupNameEdit:SetText(Pro.GetDefaultGroupName())

    f.groupOperationLabel = CreateLabel(f.groupEditorPanel, "使用策略", "TOPLEFT", f.groupEditorPanel, "TOPLEFT", 16, -94)
    f.groupOperationDropDown = CreateDropdown(f.groupEditorPanel, 180, GetOperationChoices)
    f.groupOperationDropDown:SetPoint("TOPLEFT", f.groupEditorPanel, "TOPLEFT", 78, -92)
    f.groupOperationDropDown:SetValue(Pro.GetDefaultOperationName())

    f.groupSummary = f.groupEditorPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.groupSummary:SetPoint("TOPLEFT", f.groupEditorPanel, "TOPLEFT", 16, -134)
    f.groupSummary:SetWidth(414)
    f.groupSummary:SetJustifyH("LEFT")
    f.groupSummary:SetJustifyV("TOP")
    f.groupSummary:SetText("")
    if Pro.SkinText then Pro.SkinText(f.groupSummary, "muted", 12) end

    f.groupCreateBtn = CreateButton(f.groupEditorPanel, "新建组", 86, 24)
    f.groupCreateBtn:SetPoint("BOTTOMLEFT", f.groupEditorPanel, "BOTTOMLEFT", 16, 16)
    f.groupCreateBtn:SetScript("OnClick", function() StartNewStrategyGroup(f) end)
    f.groupSaveBtn = CreateButton(f.groupEditorPanel, "保存", 86, 24)
    f.groupSaveBtn:SetPoint("LEFT", f.groupCreateBtn, "RIGHT", 10, 0)
    f.groupSaveBtn:SetScript("OnClick", function() SaveStrategyGroup(f) end)
    f.groupDeleteBtn = CreateButton(f.groupEditorPanel, "删除当前组", 104, 24)
    f.groupDeleteBtn:SetPoint("LEFT", f.groupSaveBtn, "RIGHT", 10, 0)
    f.groupDeleteBtn:SetScript("OnClick", function() DeleteSelectedStrategyGroup(f) end)

    f.groupList = f.groupEditorPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.groupList:SetPoint("TOPLEFT", f.groupEditorPanel, "TOPLEFT", 16, -210)
    f.groupList:SetWidth(414)
    f.groupList:SetJustifyH("LEFT")
    f.groupList:SetJustifyV("TOP")
    if Pro.SkinText then Pro.SkinText(f.groupList, "text", 12) end
    for _, control in ipairs({
        f.groupListPanel, f.groupListTitle, f.groupEditorPanel, f.groupEditorTitle,
        f.groupNameLabel, f.groupNameEdit, f.groupOperationLabel, f.groupOperationDropDown,
        f.groupSummary, f.groupCreateBtn, f.groupSaveBtn, f.groupDeleteBtn, f.groupList,
    }) do
        RegisterTabFrame(f, "groups", control)
    end
    for _, btn in ipairs(f.groupButtons) do
        RegisterTabFrame(f, "groups", btn)
    end
    for _, control in ipairs({ f.groupPrevBtn, f.groupNextBtn, f.groupPageText }) do
        RegisterTabFrame(f, "groups", control)
    end

    local itemTitle = CreateLabel(f, "物品搜索", "TOPLEFT", f, "TOPLEFT", 18, -92)
    RegisterTabFrame(f, "items", itemTitle)
    f.itemSourceDropDown = CreateDropdown(f, 120, GetItemSourceChoices, function()
        f.itemPage = 1
        RefreshItemSearch(f)
    end)
    f.itemSourceDropDown:SetPoint("TOPLEFT", 18, -118)
    f.itemSourceDropDown:SetValue("bag")
    f.itemSearchEdit = CreateEditBox(f, 190, 20)
    f.itemSearchEdit:SetPoint("LEFT", f.itemSourceDropDown, "RIGHT", 8, 2)
    f.itemSearchEdit:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        f.itemPage = 1
        RefreshItemSearch(f)
    end)
    f.itemSearchEdit:SetScript("OnTextChanged", function()
        f.itemPage = 1
        RefreshItemSearch(f)
    end)
    f.itemSearchBtn = CreateButton(f, "搜索", 56, 22)
    f.itemSearchBtn:SetPoint("LEFT", f.itemSearchEdit, "RIGHT", 8, 0)
    f.itemSearchBtn:SetScript("OnClick", function()
        f.itemPage = 1
        RefreshItemSearch(f)
    end)

    f.itemGridAnchor = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    f.itemGridAnchor:SetPoint("TOPLEFT", 18, -148)
    f.itemGridAnchor:SetSize(675, 178)
    f.itemGridChild = CreateFrame("Frame", nil, f.itemGridAnchor)
    f.itemGridWidth = 645
    f.itemGridHeight = 178
    f.itemGridChild:SetSize(f.itemGridWidth, f.itemGridHeight)
    f.itemGridAnchor:SetScrollChild(f.itemGridChild)
    f.itemResultButtons = {}
    f.itemCategoryHeaders = {}
    f.itemEmptyText = f.itemGridChild:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.itemEmptyText:SetPoint("TOPLEFT", f.itemGridChild, "TOPLEFT", 10, -8)
    f.itemEmptyText:SetText("没有匹配物品；换个来源或关键字")
    if Pro.SkinText then Pro.SkinText(f.itemEmptyText, "muted", 12) end
    RegisterTabFrame(f, "items", f.itemGridAnchor)
    RegisterTabFrame(f, "items", f.itemEmptyText)

    f.selectedItemText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.selectedItemText:SetPoint("TOPLEFT", 18, -338)
    f.selectedItemText:SetWidth(500)
    f.selectedItemText:SetJustifyH("LEFT")
    f.selectedItemText:SetText("已选：无")
    if Pro.SkinText then Pro.SkinText(f.selectedItemText, "text", 12) end

    f.itemPrevBtn = CreateButton(f, "上一页", 60, 22)
    f.itemPrevBtn:SetPoint("LEFT", f.selectedItemText, "RIGHT", 12, 0)
    f.itemPrevBtn:SetScript("OnClick", function()
        f.itemPage = math.max(1, (f.itemPage or 1) - 1)
        RefreshItemSearch(f)
    end)
    f.itemNextBtn = CreateButton(f, "下一页", 60, 22)
    f.itemNextBtn:SetPoint("LEFT", f.itemPrevBtn, "RIGHT", 8, 0)
    f.itemNextBtn:SetScript("OnClick", function()
        f.itemPage = (f.itemPage or 1) + 1
        RefreshItemSearch(f)
    end)
    f.itemPageText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.itemPageText:SetPoint("LEFT", f.itemNextBtn, "RIGHT", 8, 0)
    if Pro.SkinText then Pro.SkinText(f.itemPageText, "muted", 12) end

    local bindPanel = CreatePanel(f, 18, -360, 340, 132)
    local calcPanel = CreatePanel(f, 370, -360, 324, 132)

    local bindItemTitle = CreateSectionTitle(bindPanel, "单物品绑定", 12, -10)
    f.itemIDEdit = CreateEditBox(bindPanel, 72, 22)
    f.itemIDEdit:SetPoint("TOPLEFT", bindPanel, "TOPLEFT", 12, -34)
    f.itemIDEdit:SetText("物品ID")
    f.itemGroupDropDown = CreateDropdown(bindPanel, 116, GetGroupChoices)
    f.itemGroupDropDown:SetPoint("LEFT", f.itemIDEdit, "RIGHT", 8, 0)
    f.itemGroupDropDown:SetValue(Pro.GetDefaultGroupName())
    f.itemBindBtn = CreateButton(bindPanel, "绑定", 72, 22)
    f.itemBindBtn:SetPoint("LEFT", f.itemGroupDropDown, "RIGHT", 8, 0)
    f.itemBindBtn:SetScript("OnClick", function() BindItemGroup(f) end)

    local bindCategoryTitle = CreateSectionTitle(bindPanel, "分类绑定", 12, -68)
    f.categoryDropDown = CreateDropdown(bindPanel, 112, GetCategoryChoices)
    f.categoryDropDown:SetPoint("TOPLEFT", bindPanel, "TOPLEFT", 12, -92)
    f.categoryDropDown:SetValue("常用")
    f.categoryGroupDropDown = CreateDropdown(bindPanel, 112, GetGroupChoices)
    f.categoryGroupDropDown:SetPoint("LEFT", f.categoryDropDown, "RIGHT", 8, 0)
    f.categoryGroupDropDown:SetValue(Pro.GetDefaultGroupName())
    f.categoryBindBtn = CreateButton(bindPanel, "绑定分类", 80, 22)
    f.categoryBindBtn:SetPoint("LEFT", f.categoryGroupDropDown, "RIGHT", 8, 0)
    f.categoryBindBtn:SetScript("OnClick", function() BindCategoryGroup(f) end)
    for _, control in ipairs({
        f.itemSourceDropDown, f.itemSearchEdit, f.itemSearchBtn, f.selectedItemText,
        f.itemPrevBtn, f.itemNextBtn, f.itemPageText,
        bindPanel,
        bindItemTitle, f.itemIDEdit, f.itemGroupDropDown, f.itemBindBtn,
        bindCategoryTitle, f.categoryDropDown, f.categoryGroupDropDown, f.categoryBindBtn,
    }) do
        RegisterTabFrame(f, "items", control)
    end

    local calcTitle = CreateSectionTitle(calcPanel, "建议价计算", 12, -10)
    f.calcItemIDEdit = CreateEditBox(calcPanel, 68, 22)
    f.calcItemIDEdit:SetPoint("TOPLEFT", calcPanel, "TOPLEFT", 12, -34)
    f.calcItemIDEdit:SetText("物品ID")
    f.calcItemNameEdit = CreateEditBox(calcPanel, 130, 22)
    f.calcItemNameEdit:SetPoint("LEFT", f.calcItemIDEdit, "RIGHT", 8, 0)
    f.calcItemNameEdit:SetText("物品名")
    f.calcCountEdit = CreateEditBox(calcPanel, 42, 22)
    f.calcCountEdit:SetPoint("LEFT", f.calcItemNameEdit, "RIGHT", 8, 0)
    f.calcCountEdit:SetText("1")
    f.calcBtn = CreateButton(calcPanel, "计算", 68, 22)
    f.calcBtn:SetPoint("TOPLEFT", calcPanel, "TOPLEFT", 12, -66)
    f.calcBtn:SetScript("OnClick", function() RunCalculator(f) end)

    f.calcChartBtn = CreateButton(calcPanel, "走势", 68, 22)
    f.calcChartBtn:SetPoint("LEFT", f.calcBtn, "RIGHT", 8, 0)
    f.calcChartBtn:SetScript("OnClick", function() ShowCalculatorChart(f) end)

    f.calcResult = calcPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.calcResult:SetPoint("TOPLEFT", calcPanel, "TOPLEFT", 12, -94)
    f.calcResult:SetWidth(300)
    f.calcResult:SetJustifyH("LEFT")
    f.calcResult:SetJustifyV("TOP")
    f.calcResult:SetText("")
    if Pro.SkinText then Pro.SkinText(f.calcResult, "text", 12) end
    for _, control in ipairs({
        calcPanel,
        calcTitle, f.calcItemIDEdit, f.calcItemNameEdit, f.calcCountEdit,
        f.calcBtn, f.calcChartBtn, f.calcResult,
    }) do
        RegisterTabFrame(f, "items", control)
    end

    Pro.strategyFrame = f
    RefreshItemSearch(f)
    SetStrategyTab(f, "overview")
    return f
end

local function RaiseStrategyFrame(frame)
    if Pro.RaiseMainFrame then
        Pro.RaiseMainFrame(frame)
    end
end

function Pro.DrawStrategyEditor()
    local f = CreateStrategyEditor()
    RaiseStrategyFrame(f)
    local pro = Pro.InitDB()
    if not pro then
        return
    end
    if Pro.CleanupGroupBindings then
        Pro.CleanupGroupBindings()
    end

    local operationNames = SortedKeys(pro.auctionOps)
    local operationTotalPages
    f.operationPage, operationTotalPages = ClampListPage(
        f.operationPage,
        #operationNames,
        OPERATION_LIST_PAGE_SIZE
    )
    local operationStart = (f.operationPage - 1) * OPERATION_LIST_PAGE_SIZE
    for i, btn in ipairs(f.operationList) do
        local operationName = operationNames[operationStart + i]
        btn.operationName = operationName
        if operationName then
            btn:SetText(operationName)
            btn:SetEnabled(true)
            btn:Show()
            if Pro.SetButtonActive then
                Pro.SetButtonActive(btn, operationName == f.selectedOperation)
            end
        else
            btn.operationName = nil
            btn:SetText("")
            btn:SetEnabled(false)
            if Pro.SetButtonActive then
                Pro.SetButtonActive(btn, false)
            end
            btn:Hide()
        end
    end
    if f.operationPrevBtn then
        f.operationPrevBtn:SetEnabled(f.operationPage > 1)
    end
    if f.operationNextBtn then
        f.operationNextBtn:SetEnabled(f.operationPage < operationTotalPages)
    end
    if f.operationPageText then
        f.operationPageText:SetText(string.format("%d/%d", f.operationPage, operationTotalPages))
    end

    local groupNames = SortedKeys(pro.groups)
    if not f.selectedGroup or not pro.groups[f.selectedGroup] then
        f.selectedGroup = Pro.GetDefaultGroupName()
    end
    local groupTotalPages
    f.groupPage, groupTotalPages = ClampListPage(f.groupPage, #groupNames, GROUP_LIST_PAGE_SIZE)
    local groupStart = (f.groupPage - 1) * GROUP_LIST_PAGE_SIZE
    for i, btn in ipairs(f.groupButtons or {}) do
        local groupName = groupNames[groupStart + i]
        btn.groupName = groupName
        if groupName then
            local group = pro.groups[groupName]
            btn:SetText(groupName .. "  |cff808080" .. (group and group.auctionOp or "") .. "|r")
            btn:SetEnabled(true)
            btn:Show()
            if Pro.SetButtonActive then
                Pro.SetButtonActive(btn, groupName == f.selectedGroup)
            end
        else
            btn.groupName = nil
            btn:SetText("")
            btn:SetEnabled(false)
            if Pro.SetButtonActive then
                Pro.SetButtonActive(btn, false)
            end
            btn:Hide()
        end
    end
    if f.groupPrevBtn then
        f.groupPrevBtn:SetEnabled(f.groupPage > 1)
    end
    if f.groupNextBtn then
        f.groupNextBtn:SetEnabled(f.groupPage < groupTotalPages)
    end
    if f.groupPageText then
        f.groupPageText:SetText(string.format("%d/%d", f.groupPage, groupTotalPages))
    end
    local lines = {
        "操作方式：",
        "1. 左侧点选一个策略组。",
        "2. 右侧修改组名或使用策略。",
        "3. 点击保存后立即生效；删除会清除该组的物品绑定。",
    }
    f.groupList:SetText(table.concat(lines, "\n"))
    SelectStrategyGroup(f, f.selectedGroup)
    if f.operationDropDown then
        f.operationDropDown:SetValue(f.selectedOperation or Pro.GetDefaultOperationName())
    end

    if not f.selectedOperation then
        LoadOperation(f, Pro.GetDefaultOperationName())
    end
    SetStrategyTab(f, f.activeTab or "overview")
    if f.activeTab == "overview" then
        for _, btn in ipairs(f.operationList or {}) do
            if not btn.operationName then
                btn:SetText("")
                btn:Hide()
            end
        end
    end
    if f.activeTab == "groups" then
        for _, btn in ipairs(f.groupButtons or {}) do
            if not btn.groupName then
                btn:SetText("")
                btn:Hide()
            end
        end
    end
end

function Pro.ShowStrategyEditor(source, categoryName)
    local f = CreateStrategyEditor()
    Pro.ApplyFrameScale(f)
    RaiseStrategyFrame(f)
    if source == "price" and f.itemSourceDropDown then
        if categoryName and categoryName ~= "" and categoryName ~= "全类" then
            f.itemSourceDropDown:SetValue("category:" .. categoryName)
        else
            f.itemSourceDropDown:SetValue("price")
        end
        f.itemPage = 1
        RefreshItemSearch(f)
    end
    LoadOperation(f, f.selectedOperation or Pro.GetDefaultOperationName())
    f:Show()
end

function _G.EasyAuctionPro_ShowStrategyEditor(source, categoryName)
    Pro.ShowStrategyEditor(source, categoryName)
end
