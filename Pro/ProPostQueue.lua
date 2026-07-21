local _, ns = ...

local Pro = ns.EasyAuctionPro
if not Pro then return end

local ENABLE_QUEUE_BULK_POST_UI = false
local ROW_HEIGHT = 34
local MAX_ROWS = 10

local scanTooltip
local bulkPostState = {
    running = false,
}
local singlePostRunning = false
local UpdateBulkControls

local function GetScanTooltip()
    if scanTooltip then
        return scanTooltip
    end
    scanTooltip = CreateFrame("GameTooltip", "EasyAuctionProScanTooltip", UIParent, "GameTooltipTemplate")
    scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    return scanTooltip
end

local function TooltipHasText(text)
    if not text or text == "" then
        return false
    end
    local tooltip = GetScanTooltip()
    for i = 1, tooltip:NumLines() do
        local left = _G["EasyAuctionProScanTooltipTextLeft" .. i]
        local right = _G["EasyAuctionProScanTooltipTextRight" .. i]
        if left and left:GetText() == text then
            return true
        end
        if right and right:GetText() == text then
            return true
        end
    end
    return false
end

local function IsSoulboundBagItem(bag, slot)
    local tooltip = GetScanTooltip()
    tooltip:ClearLines()
    tooltip:SetBagItem(bag, slot)
    return TooltipHasText(ITEM_SOULBOUND) or TooltipHasText("灵魂绑定")
end

local function IsAuctionableBagItem(bag, slot, info)
    if not info or info.isLocked or not info.itemID or not info.stackCount or info.stackCount <= 0 then
        return false
    end
    if IsSoulboundBagItem(bag, slot) then
        return false
    end
    return true
end

local function GetBagItemDisplayName(info)
    local link = info and (info.hyperlink or info.itemLink)
    local name = link and link:match("%[(.-)%]")
    if name and name ~= "" then
        return name, link
    end
    name = info and info.itemID and GetItemInfo(info.itemID) or nil
    return name, link
end

local function GetQueueItemKey(itemName, itemID)
    if itemName and itemID then
        return itemName .. ":" .. tostring(itemID)
    end
    return itemName or tostring(itemID or "")
end

local function GetSuggestionItemKey(suggestion)
    if not suggestion then
        return nil
    end
    if suggestion.itemKey and suggestion.itemKey ~= "" then
        return suggestion.itemKey
    end
    if suggestion.itemName and suggestion.itemID then
        return suggestion.itemName .. ":" .. tostring(suggestion.itemID)
    end
    return suggestion.itemName
end

local function GetSelectionKey(suggestion)
    local key = GetSuggestionItemKey(suggestion)
    if key and key ~= "" then
        return key
    end
    if suggestion and suggestion.itemID then
        return tostring(suggestion.itemID)
    end
    return nil
end

local function IsPostableSuggestion(suggestion)
    return suggestion and suggestion.status ~= "skip" and
        tonumber(suggestion.unitPrice) and tonumber(suggestion.unitPrice) > 0
end

local function EnsureQueueSelection(frame, queue)
    if not ENABLE_QUEUE_BULK_POST_UI then
        return
    end
    if not frame then
        return
    end
    frame.selection = frame.selection or {}
    frame.selectionTouched = frame.selectionTouched or {}
    for _, suggestion in ipairs(queue or {}) do
        local key = GetSelectionKey(suggestion)
        if key and IsPostableSuggestion(suggestion) and frame.selectionTouched[key] == nil then
            frame.selection[key] = true
        end
    end
end

local function SetAllPostableSelected(frame, queue, selected)
    if not frame then
        return 0
    end
    frame.selection = frame.selection or {}
    frame.selectionTouched = frame.selectionTouched or {}
    local count = 0
    for _, suggestion in ipairs(queue or {}) do
        local key = GetSelectionKey(suggestion)
        if key and IsPostableSuggestion(suggestion) then
            frame.selection[key] = selected and true or false
            frame.selectionTouched[key] = true
            count = count + 1
        end
    end
    return count
end

local function GetSelectedPostableQueue(frame, queue)
    local selected = {}
    if not frame then
        return selected
    end
    frame.selection = frame.selection or {}
    for _, suggestion in ipairs(queue or {}) do
        local key = GetSelectionKey(suggestion)
        if key and frame.selection[key] and IsPostableSuggestion(suggestion) then
            selected[#selected + 1] = suggestion
        end
    end
    return selected
end

local function CountSelectedPostable(frame, queue)
    return #GetSelectedPostableQueue(frame, queue)
end

local function ScanBagItems()
    local result = {}
    local byKey = {}
    for bag = 0, NUM_BAG_SLOTS do
        local slots = C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if IsAuctionableBagItem(bag, slot, info) then
                local itemName, itemLink = GetBagItemDisplayName(info)
                local _, fallbackLink, quality, _, _, _, _, maxStack, _, icon = GetItemInfo(info.itemID)
                itemLink = itemLink or fallbackLink
                if (not icon or icon == "") and type(GetItemIcon) == "function" then
                    icon = GetItemIcon(info.itemID)
                end
                if itemName then
                    local itemKey = GetQueueItemKey(itemName, info.itemID)
                    local entry = byKey[itemKey]
                    if not entry then
                        entry = {
                            itemID = info.itemID,
                            itemName = itemName,
                            itemKey = itemKey,
                            itemLink = itemLink,
                            quality = quality,
                            icon = icon,
                            maxStack = maxStack or 1,
                            count = 0,
                        }
                        byKey[itemKey] = entry
                        table.insert(result, entry)
                    end
                    entry.count = entry.count + info.stackCount
                end
            end
        end
    end
    table.sort(result, function(a, b)
        return (a.itemName or "") < (b.itemName or "")
    end)
    return result
end

local function SplitMoney(copper)
    copper = math.max(0, math.floor(tonumber(copper) or 0))
    return math.floor(copper / 10000), math.floor((copper % 10000) / 100), copper % 100
end

local function FormatQueueMoney(copper)
    copper = math.max(0, math.floor(tonumber(copper) or 0))
    if copper >= 10000000 then
        local gold = math.floor(copper / 10000)
        local silver = math.floor((copper % 10000) / 100)
        return string.format("%d金%d银", gold, silver)
    end
    return Pro.FormatMoney(copper)
end

local function SetButtonTextColor(button, r, g, b)
    if not button or not button.GetFontString then
        return
    end
    local text = button:GetFontString()
    if text and text.SetTextColor then
        text:SetTextColor(r, g, b, 1)
    end
end

local function HookButtonStyleRestore(button, restoreFunc)
    if not button then
        return
    end
    button.EasyAuctionProRestoreStyle = restoreFunc
    if button.EasyAuctionProRestoreHooked then
        return
    end
    button.EasyAuctionProRestoreHooked = true
    local function restore(self)
        if self and self.EasyAuctionProRestoreStyle then
            self:EasyAuctionProRestoreStyle()
            if _G.C_Timer and _G.C_Timer.After then
                _G.C_Timer.After(0, function()
                    if self and self.EasyAuctionProRestoreStyle then
                        self:EasyAuctionProRestoreStyle()
                    end
                end)
            end
        end
    end
    button:HookScript("OnLeave", restore)
    button:HookScript("OnMouseUp", restore)
end

local function HookCustomHover(button, enterFunc, leaveFunc)
    if not button or button.EasyAuctionProCustomHoverHooked then
        return
    end
    button.EasyAuctionProCustomHoverHooked = true
    button:HookScript("OnEnter", function(self)
        if self:IsEnabled() and self.EasyAuctionProHoverStyle then
            self:EasyAuctionProHoverStyle()
            if _G.C_Timer and _G.C_Timer.After then
                _G.C_Timer.After(0, function()
                    if self and self:IsEnabled() and self.EasyAuctionProHoverStyle then
                        self:EasyAuctionProHoverStyle()
                    end
                end)
            end
        end
    end)
    button:HookScript("OnLeave", function(self)
        if self.EasyAuctionProRestoreStyle then
            self:EasyAuctionProRestoreStyle()
        elseif self.EasyAuctionProLeaveStyle then
            self:EasyAuctionProLeaveStyle()
        end
    end)
    button.EasyAuctionProHoverStyle = enterFunc
    button.EasyAuctionProLeaveStyle = leaveFunc
end

local function PrepareCustomButton(button, enabled)
    if not button then
        return
    end
    button.__EAStyleActive = false
    button.__EAStyleDisabled = not enabled
    if Pro.SkinButton and not button.EasyAuctionProCustomSkinApplied then
        button.EasyAuctionProCustomSkinApplied = true
        Pro.SkinButton(button, false)
    end
    if button.SetBackdrop then
        button:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
    end
end

local function PaintApplyButton(button, canApply, hover)
    PrepareCustomButton(button, canApply)
    if button.SetBackdropColor then
        if canApply then
            button:SetBackdropColor(hover and 0.05 or 0.04, hover and 0.42 or 0.34, hover and 0.22 or 0.18, 0.98)
            button:SetBackdropBorderColor(0.00, hover and 1.00 or 0.95, 0.48, 1)
        else
            button:SetBackdropColor(0.12, 0.12, 0.14, 0.72)
            button:SetBackdropBorderColor(0.34, 0.34, 0.38, 0.85)
        end
    end
    SetButtonTextColor(button, canApply and 0.76 or 0.58, canApply and 1.00 or 0.58, canApply and 0.80 or 0.62)
end

local function PaintPostButton(button, canPost, hover)
    PrepareCustomButton(button, canPost)
    if button.SetBackdropColor then
        if canPost then
            button:SetBackdropColor(hover and 0.44 or 0.34, hover and 0.26 or 0.20, hover and 0.05 or 0.04, 0.98)
            button:SetBackdropBorderColor(1.00, hover and 0.84 or 0.72, 0.18, 1)
        else
            button:SetBackdropColor(0.12, 0.12, 0.14, 0.72)
            button:SetBackdropBorderColor(0.34, 0.34, 0.38, 0.85)
        end
    end
    SetButtonTextColor(button, canPost and 1.00 or 0.58, canPost and 0.88 or 0.58, canPost and 0.46 or 0.62)
end

local function PaintBulkPostButton(button, enabled, hover)
    PrepareCustomButton(button, enabled)
    if button.SetBackdropColor then
        if enabled then
            button:SetBackdropColor(hover and 0.50 or 0.42, hover and 0.30 or 0.24, 0.03, 0.98)
            button:SetBackdropBorderColor(1.00, hover and 0.90 or 0.82, 0.24, 1)
        else
            button:SetBackdropColor(0.12, 0.12, 0.15, 0.86)
            button:SetBackdropBorderColor(0.38, 0.38, 0.44, 0.95)
        end
    end
    SetButtonTextColor(button, enabled and 1.00 or 0.62, enabled and 0.92 or 0.62, enabled and 0.56 or 0.66)
end

local function UpdateApplyButtonState(button, canApply)
    if not button then
        return
    end
    button.EasyAuctionProCanApply = canApply and true or false
    button:SetEnabled(canApply and true or false)
    button:SetText(canApply and "填入" or "不可填")
    button:SetAlpha(1)
    PaintApplyButton(button, canApply, false)
    HookButtonStyleRestore(button, function(self)
        PaintApplyButton(self, self.EasyAuctionProCanApply, false)
    end)
    HookCustomHover(button, function(self)
        PaintApplyButton(self, self.EasyAuctionProCanApply, true)
    end)
end

local function UpdatePostButtonState(button, canPost)
    if not button then
        return
    end
    button.EasyAuctionProCanPost = canPost and true or false
    button:SetEnabled(canPost and true or false)
    button:SetText(canPost and "拍卖" or "不可拍")
    button:SetAlpha(1)
    PaintPostButton(button, canPost, false)
    HookButtonStyleRestore(button, function(self)
        PaintPostButton(self, self.EasyAuctionProCanPost, false)
    end)
    HookCustomHover(button, function(self)
        PaintPostButton(self, self.EasyAuctionProCanPost, true)
    end)
end

local function StyleBulkPostButton(button, enabled)
    if not button then
        return
    end
    enabled = enabled and true or false
    button.EasyAuctionProBulkEnabled = enabled
    PaintBulkPostButton(button, enabled, false)
    HookButtonStyleRestore(button, function(self)
        PaintBulkPostButton(self, self.EasyAuctionProBulkEnabled, false)
    end)
    HookCustomHover(button, function(self)
        PaintBulkPostButton(self, self.EasyAuctionProBulkEnabled, true)
    end)
end

local function StyleSmallTooltipText(size)
    size = size or 11
    local font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    for i = 1, (_G.GameTooltip and _G.GameTooltip:NumLines() or 0) do
        local left = _G["GameTooltipTextLeft" .. i]
        local right = _G["GameTooltipTextRight" .. i]
        if left and left.SetFont then left:SetFont(font, size, "") end
        if right and right.SetFont then right:SetFont(font, size, "") end
    end
end

local dropdownIndex = 0

local function SortedKeys(tbl)
    local keys = {}
    for key in pairs(tbl or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

local function GetOperationChoices()
    local pro = Pro.InitDB()
    local choices = {}
    for _, operationName in ipairs(SortedKeys(pro and pro.auctionOps or {})) do
        choices[#choices + 1] = { value = operationName, label = operationName }
    end
    return choices
end

local function GetChoiceLabel(choices, value)
    for _, choice in ipairs(choices or {}) do
        if choice.value == value then
            return choice.label
        end
    end
    return tostring(value or "")
end

local function CreateDropdown(parent, width, choices, onSelect)
    dropdownIndex = dropdownIndex + 1
    local dropdown = CreateFrame(
        "Frame",
        "EasyAuctionProQueueDropDown" .. dropdownIndex,
        parent,
        "UIDropDownMenuTemplate"
    )
    width = width or 90
    dropdown.EasyAuctionProVisualWidth = width
    dropdown:SetSize(width, 22)
    dropdown.choices = choices or {}
    UIDropDownMenu_SetWidth(dropdown, width)
    dropdown:SetSize(width, 22)
    function dropdown:SetValue(value)
        self.value = value
        UIDropDownMenu_SetText(self, GetChoiceLabel(self.choices, value))
        if Pro.ReskinDropDown then
            Pro.ReskinDropDown(self)
        end
    end
    function dropdown:GetValue()
        return self.value
    end
    UIDropDownMenu_Initialize(dropdown, function(self, level)
        for _, choice in ipairs(dropdown.choices or {}) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = choice.label
            info.value = choice.value
            info.func = function()
                dropdown:SetValue(choice.value)
                if onSelect then onSelect(choice.value, choice) end
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
    return dropdown
end

local function RecalculateWithOperation(suggestion, operationName)
    if not suggestion or not operationName or operationName == "" then
        return suggestion
    end
    local pro = Pro.InitDB()
    if not pro or not pro.auctionOps or not pro.auctionOps[operationName] then
        return suggestion
    end
    local itemKey = tostring(suggestion.itemID)
    local originalGroup = pro.itemGroups and pro.itemGroups[itemKey] or nil
    local tempGroup = "__queue_override_" .. tostring(suggestion.itemID)
    pro.groups[tempGroup] = pro.groups[tempGroup] or { items = {}, auctionOp = operationName }
    pro.groups[tempGroup].auctionOp = operationName
    pro.itemGroups[itemKey] = tempGroup
    local updated = Pro.CalcPostSuggestion(suggestion.itemID, suggestion.itemName, suggestion.bagCount or 1)
    if originalGroup then
        pro.itemGroups[itemKey] = originalGroup
    else
        pro.itemGroups[itemKey] = nil
    end
    pro.groups[tempGroup] = nil
    if updated then
        updated.itemLink = suggestion.itemLink
        updated.quality = suggestion.quality
        updated.bagCount = suggestion.bagCount
        updated.operationName = operationName
        return updated
    end
    return suggestion
end

local function IsSuggestionBagItem(suggestion, info)
    if not suggestion or not info or info.itemID ~= suggestion.itemID then
        return false
    end
    if not suggestion.itemName or suggestion.itemName == "" then
        return true
    end
    local bagName = GetBagItemDisplayName(info)
    return bagName == suggestion.itemName
end

local function FillSellPanel(suggestion)
    if not suggestion or not suggestion.itemID then
        return false
    end
    for bag = 0, NUM_BAG_SLOTS do
        local slots = C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if IsSuggestionBagItem(suggestion, info) and IsAuctionableBagItem(bag, slot, info) then
                if type(_G.PickupAndPutToAuction) == "function" then
                    _G.PickupAndPutToAuction(bag, slot)
                else
                    if C_Container and C_Container.PickupContainerItem then
                        C_Container.PickupContainerItem(bag, slot)
                    else
                        PickupContainerItem(bag, slot)
                    end
                    ClickAuctionSellItemButton()
                    ClearCursor()
                end

                C_Timer.After(0.15, function()
                    local frame = _G.AuctionHelper
                    if not frame then return end
                    local gold, silver, copper = SplitMoney(suggestion.unitPrice)
                    if frame.UnitGold then frame.UnitGold:SetNumber(gold) end
                    if frame.UnitSilver then frame.UnitSilver:SetNumber(silver) end
                    if frame.UnitCopper then frame.UnitCopper:SetNumber(copper) end
                    if frame.StackCount then frame.StackCount:SetNumber(suggestion.stackSize or 1) end
                    if frame.NumStacks then frame.NumStacks:SetNumber(suggestion.numStacks or 1) end
                    if _G.EasyAuctionDB then
                        _G.EasyAuctionDB.auctionDuration = suggestion.duration or _G.EasyAuctionDB.auctionDuration or 1
                    end
                    if frame.SetItemNameForCopy then
                        frame:SetItemNameForCopy(suggestion.itemName)
                    end
                    if type(_G.MyAH_AutoFillPrice) == "function" then
                        _G.MyAH_AutoFillPrice()
                    end
                    if type(_G.UpdateDepositMoney) == "function" then
                        _G.UpdateDepositMoney()
                    end
                end)
                return true
            end
        end
    end
    return false
end

local function EnsureBulkPostConfirmDialog()
    local dialogs = _G.StaticPopupDialogs
    if not dialogs then
        return
    end
    dialogs.EASYAUCTIONPRO_BULK_POST_CONFIRM = dialogs.EASYAUCTIONPRO_BULK_POST_CONFIRM or {
        text =
        "|cffff4040提示|r\n\n将从选中条目中按建议单价填入 1 个可上架物品。\n由于游戏保护机制限制，最终发布必须由你点击拍卖行原生“创建拍卖/拍卖”按钮完成。\n\n发布完成后可再次点击批量填入处理下一件。",
        button1 = "确认填入",
        button2 = "取消",
        OnAccept = function(_, data)
            if data and data.callback then
                data.callback(data.frame)
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

local function EnsureSinglePostConfirmDialog()
    local dialogs = _G.StaticPopupDialogs
    if not dialogs then
        return
    end
    dialogs.EASYAUCTIONPRO_SINGLE_POST_CONFIRM = dialogs.EASYAUCTIONPRO_SINGLE_POST_CONFIRM or {
        text = "|cffffd200单条填入确认|r\n\n是否按建议价填入：%s？\n单价：%s\n\n填入后请点击拍卖行原生发布按钮完成上架。",
        button1 = "确认填入",
        button2 = "取消",
        OnAccept = function(_, data)
            if data and data.callback then
                data.callback(data.frame, data.suggestion)
            end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

local function SetBulkStatus(frame, text, ok)
    if frame and frame.status then
        if ok == false then
            frame.status:SetText("|cffff6060" .. text .. "|r")
        else
            frame.status:SetText("|cff60ff60" .. text .. "|r")
        end
    else
        print(text)
    end
end

local function StartSinglePost(frame, suggestion)
    if singlePostRunning or bulkPostState.running then
        SetBulkStatus(frame, "已有上架流程正在执行，请等待完成。", false)
        return
    end
    if not IsPostableSuggestion(suggestion) then
        SetBulkStatus(frame, "该条目当前不可上架。", false)
        return
    end
    if not _G.AuctionFrame or not _G.AuctionFrame:IsShown() then
        SetBulkStatus(frame, "请先打开拍卖行后再填入。", false)
        return
    end

    singlePostRunning = true
    UpdateBulkControls(frame, Pro.queue or {})
    SetBulkStatus(frame, "正在按建议价填入：" .. (suggestion.itemName or "?"), true)

    if not FillSellPanel(suggestion) then
        singlePostRunning = false
        UpdateBulkControls(frame, Pro.queue or {})
        SetBulkStatus(frame, "未找到背包中的对应物品。", false)
        return
    end

    singlePostRunning = false
    UpdateBulkControls(frame, Pro.queue or {})
    SetBulkStatus(frame, "已按建议价填入：" .. (suggestion.itemName or "?") .. "。请点击拍卖行原生发布按钮完成上架。", true)
end

local function ConfirmSinglePost(frame, suggestion)
    if not IsPostableSuggestion(suggestion) then
        SetBulkStatus(frame, "该条目当前不可上架。", false)
        return
    end
    EnsureSinglePostConfirmDialog()
    if _G.StaticPopupDialogs and _G.StaticPopupDialogs.EASYAUCTIONPRO_SINGLE_POST_CONFIRM and _G.StaticPopup_Show then
        _G.StaticPopup_Show("EASYAUCTIONPRO_SINGLE_POST_CONFIRM", suggestion.itemName or "?", FormatQueueMoney(suggestion.unitPrice or 0), {
            frame = frame,
            suggestion = suggestion,
            callback = StartSinglePost,
        })
    else
        StartSinglePost(frame, suggestion)
    end
end

local function StartBulkPost(frame)
    if bulkPostState.running then
        SetBulkStatus(frame, "批量填入正在执行，请等待完成。", false)
        return
    end
    if not _G.AuctionFrame or not _G.AuctionFrame:IsShown() then
        SetBulkStatus(frame, "请先打开拍卖行后再批量填入。", false)
        return
    end
    local queue = Pro.queue or Pro.RefreshPostQueue()
    EnsureQueueSelection(frame, queue)
    local selected = GetSelectedPostableQueue(frame, queue)
    if #selected == 0 then
        SetBulkStatus(frame, "没有选中的可上架条目。", false)
        return
    end

    local suggestion = selected[1]
    if not FillSellPanel(suggestion) then
        SetBulkStatus(frame, "未找到背包中的对应物品：" .. (suggestion.itemName or "?"), false)
        return
    end

    local key = GetSelectionKey(suggestion)
    if key then
        frame.selection = frame.selection or {}
        frame.selectionTouched = frame.selectionTouched or {}
        frame.selection[key] = false
        frame.selectionTouched[key] = true
    end
    UpdateBulkControls(frame, Pro.queue or {})
    SetBulkStatus(frame, string.format(
        "已填入 1/%d：%s。请点击拍卖行原生发布按钮完成上架，完成后可再次点击批量填入。",
        #selected,
        suggestion.itemName or "?"
    ), true)
end

local function ConfirmBulkPost(frame)
    local queue = Pro.queue or Pro.RefreshPostQueue()
    EnsureQueueSelection(frame, queue)
    local selectedCount = CountSelectedPostable(frame, queue)
    if selectedCount == 0 then
        SetBulkStatus(frame, "没有选中的可上架条目。", false)
        return
    end
    EnsureBulkPostConfirmDialog()
    if _G.StaticPopupDialogs and _G.StaticPopupDialogs.EASYAUCTIONPRO_BULK_POST_CONFIRM and _G.StaticPopup_Show then
        _G.StaticPopup_Show("EASYAUCTIONPRO_BULK_POST_CONFIRM", selectedCount, nil, {
            frame = frame,
            callback = StartBulkPost,
        })
    else
        StartBulkPost(frame)
    end
end

local function BuildQueue()
    local queue = {}
    for _, item in ipairs(ScanBagItems()) do
        local suggestion = Pro.CalcPostSuggestion(item.itemID, item.itemName, item.count)
        if suggestion then
            suggestion.itemLink = item.itemLink
            suggestion.quality = item.quality
            suggestion.bagCount = item.count
            suggestion.itemKey = item.itemKey
            table.insert(queue, suggestion)
        end
    end
    return queue
end

local function ShowQueueItemChart(suggestion)
    local key = GetSuggestionItemKey(suggestion)
    if key and key ~= "" and type(_G.EasyAuction_ShowChart) == "function" then
        _G.EasyAuction_ShowChart(key)
        local chartFrame = _G.EasyAuction_ChartFrame
        if chartFrame then
            chartFrame:SetFrameStrata("FULLSCREEN_DIALOG")
            chartFrame:SetFrameLevel(220)
            chartFrame:SetToplevel(true)
        end
        return true
    end
    print("|cffff2020[EasyAuctionPro]|r 该物品暂无可查看的价格走势。")
    return false
end

function Pro.RefreshPostQueue()
    Pro.queue = BuildQueue()
    local db = Pro.InitDB()
    if db then
        db.queue.lastBuild = time()
        db.queue.count = #Pro.queue
    end
    return Pro.queue
end

UpdateBulkControls = function(frame, queue)
    if not frame then
        return
    end
    if not ENABLE_QUEUE_BULK_POST_UI then
        if frame.selectAllBtn then frame.selectAllBtn:Hide() end
        if frame.bulkPostBtn then frame.bulkPostBtn:Hide() end
        if frame.bulkCountText then
            frame.bulkCountText:SetText("")
            frame.bulkCountText:Hide()
        end
        return
    end
    queue = queue or Pro.queue or {}
    local selectedCount = CountSelectedPostable(frame, queue)
    local postableCount = 0
    for _, suggestion in ipairs(queue) do
        if IsPostableSuggestion(suggestion) then
            postableCount = postableCount + 1
        end
    end
    if frame.selectAllBtn then
        frame.selectAllBtn:SetText(selectedCount >= postableCount and postableCount > 0 and "取消" or "全选")
        frame.selectAllBtn:SetEnabled(postableCount > 0 and not bulkPostState.running)
    end
    if frame.bulkPostBtn then
        local enabled = selectedCount > 0 and not bulkPostState.running and not singlePostRunning
        frame.bulkPostBtn:SetEnabled(enabled)
        StyleBulkPostButton(frame.bulkPostBtn, enabled)
    end
    if frame.bulkCountText then
        frame.bulkCountText:SetText(string.format("已选 %d / 可上架 %d", selectedCount, postableCount))
    end
end

local function CreateFrameOnce()
    if Pro.queueFrame then
        return Pro.queueFrame
    end

    local f = CreateFrame("Frame", "EasyAuctionProPostQueueFrame", UIParent, "BackdropTemplate")
    f:SetSize(1240, 500)
    f:SetPoint("CENTER")
    if Pro.RaiseMainFrame then Pro.RaiseMainFrame(f) end
    Pro.ApplyFrameScale(f)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    if Pro.SkinFrame then Pro.SkinFrame(f, "window") end
    tinsert(UISpecialFrames, "EasyAuctionProPostQueueFrame")

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", 14, -12)
    f.title:SetText("|cffffd200EasyAuction Pro|r 策略上架队列")
    if Pro.SkinText then Pro.SkinText(f.title, "accent", 14) end

    local closeBtn = Pro.CreateCloseButton and Pro.CreateCloseButton(f) or CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -8, -8)

    f.refreshBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.refreshBtn:SetSize(80, 22)
    f.refreshBtn:SetPoint("TOPRIGHT", closeBtn, "BOTTOMRIGHT", -10, -2)
    f.refreshBtn:SetText("刷新")
    f.refreshBtn:SetScript("OnClick", function()
        Pro.RefreshPostQueue()
        Pro.DrawPostQueue()
    end)
    if Pro.SkinButton then Pro.SkinButton(f.refreshBtn) end

    f.strategyBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.strategyBtn:SetSize(88, 22)
    f.strategyBtn:SetPoint("RIGHT", f.refreshBtn, "LEFT", -8, 0)
    f.strategyBtn:SetText("策略设置")
    f.strategyBtn:SetScript("OnClick", function()
        if Pro.ShowStrategyEditor then
            Pro.ShowStrategyEditor()
        end
    end)
    if Pro.SkinButton then Pro.SkinButton(f.strategyBtn) end

    f.status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.status:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -8)
    f.status:SetWidth(820)
    f.status:SetJustifyH("LEFT")
    f.status:SetText("")
    if Pro.SkinText then Pro.SkinText(f.status, "text", 12) end

    f.help = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.help:SetPoint("TOPLEFT", f.status, "BOTTOMLEFT", 0, -2)
    f.help:SetWidth(820)
    f.help:SetJustifyH("LEFT")
    --f.help:SetText("先扫描价格并刷新物品，可逐行改策略，绿色行点“填入”。")
    if Pro.SkinText then Pro.SkinText(f.help, "muted", 12) end

    local header = CreateFrame("Frame", nil, f, "BackdropTemplate")
    header:SetPoint("TOPLEFT", 14, -86)
    header:SetSize(1210, 20)
    if Pro.SkinHeader then Pro.SkinHeader(header) end
    local cols = {
        { "物品", 145 },
        { "库存", 38 },
        { "策略", 118 },
        { "走势", 52 },
        { "当前最低", 86 },
        { "昨日最低", 86 },
        { "7日中位", 86 },
        { "建议单价", 86 },
        { "堆叠/组", 58 },
        { "状态", 62 },
        { "原因", 158 },
        { "操作", 50 },
        { ENABLE_QUEUE_BULK_POST_UI and "拍卖" or "", 54 },
        { "", 46 },
    }
    local x = 0
    for _, col in ipairs(cols) do
        local fs = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("LEFT", header, "LEFT", x, 0)
        fs:SetWidth(col[2])
        fs:SetJustifyH("LEFT")
        fs:SetText(col[1])
        if Pro.SkinText then Pro.SkinText(fs, "muted", 11) end
        x = x + col[2] + 6
    end
    f.selectAllBtn = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
    f.selectAllBtn:SetSize(46, 18)
    f.selectAllBtn:SetPoint("LEFT", header, "LEFT", x - cols[#cols][2] - 6, 0)
    f.selectAllBtn:SetText("全选")
    f.selectAllBtn:SetScript("OnClick", function()
        local queue = Pro.queue or Pro.RefreshPostQueue()
        EnsureQueueSelection(f, queue)
        local selectedCount = CountSelectedPostable(f, queue)
        local postableCount = 0
        for _, suggestion in ipairs(queue or {}) do
            if IsPostableSuggestion(suggestion) then
                postableCount = postableCount + 1
            end
        end
        SetAllPostableSelected(f, queue, selectedCount < postableCount)
        Pro.DrawPostQueue()
    end)
    if Pro.SkinButton then Pro.SkinButton(f.selectAllBtn) end
    if not ENABLE_QUEUE_BULK_POST_UI then f.selectAllBtn:Hide() end

    f.rows = {}
    for i = 1, MAX_ROWS do
        local row = CreateFrame("Button", nil, f, "BackdropTemplate")
        row:SetSize(1210, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 14, -110 - (i - 1) * ROW_HEIGHT)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        if Pro.SkinRow then Pro.SkinRow(row, i) end
        row.cols = {}
        x = 0
        for colIndex, col in ipairs(cols) do
            local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fs:SetPoint("LEFT", row, "LEFT", x, 0)
            fs:SetWidth(col[2])
            fs:SetJustifyH("LEFT")
            fs:SetText("")
        if colIndex == 11 then
            fs:SetNonSpaceWrap(false)
            fs:SetWordWrap(false)
        end
            if Pro.SkinText then Pro.SkinText(fs, "text", 12) end
            row.cols[colIndex] = fs
            x = x + col[2] + 6
        end
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(18, 18)
        row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.itemHitArea = CreateFrame("Button", nil, row)
        row.itemHitArea:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.itemHitArea:SetSize(cols[1][2], ROW_HEIGHT)
        row.itemHitArea:SetScript("OnEnter", function(self)
            local data = self:GetParent().data
            if not data then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:ClearLines()
            if data.itemLink then
                GameTooltip:SetHyperlink(data.itemLink)
            elseif data.itemID then
                GameTooltip:SetItemByID(data.itemID)
            else
                GameTooltip:SetText(data.itemName or "", 1, 1, 1)
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine("库存", tostring(data.bagCount or 0), 1, 1, 1, 0.8, 0.8, 0.8)
            if data.operationName then
                GameTooltip:AddDoubleLine("策略", data.operationName, 1, 1, 1, 0.8, 0.8, 0.8)
            end
            if data.itemID then
                GameTooltip:AddDoubleLine("物品ID", tostring(data.itemID), 1, 1, 1, 0.8, 0.8, 0.8)
            end
            GameTooltip:Show()
        end)
        row.itemHitArea:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        row.reasonHitArea = CreateFrame("Button", nil, row)
        row.reasonHitArea:SetPoint("LEFT", row.cols[11], "LEFT", 0, 0)
        row.reasonHitArea:SetSize(cols[11][2], ROW_HEIGHT)
        row.reasonHitArea:SetScript("OnEnter", function(self)
            local data = self:GetParent().data
            local reason = data and data.reason
            if not reason or reason == "" then
                return
            end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:ClearLines()
            GameTooltip:AddLine("原因", 1, 0.82, 0, true)
            GameTooltip:AddLine(reason, 0.92, 0.92, 0.92, true)
            StyleSmallTooltipText(11)
            GameTooltip:Show()
        end)
        row.reasonHitArea:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        row.operationDropDown = CreateDropdown(row, 96, GetOperationChoices(), function(value)
            local data = row.data
            if data then
                local updated = RecalculateWithOperation(data, value)
                local queue = Pro.queue or {}
                if row.queueIndex then
                    queue[row.queueIndex] = updated
                end
                row.data = updated
                Pro.DrawPostQueue()
            end
        end)
        row.operationDropDown:SetPoint("LEFT", row.cols[3], "LEFT", -18, -2)

        row.trendBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.trendBtn:SetSize(46, 20)
        row.trendBtn:SetPoint("LEFT", row.cols[4], "LEFT", 0, 0)
        row.trendBtn:SetText("走势")
        row.trendBtn:SetScript("OnClick", function(self)
            ShowQueueItemChart(self:GetParent().data)
        end)
        if Pro.SkinButton then Pro.SkinButton(row.trendBtn) end

        row.applyBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.applyBtn:SetSize(52, 20)
        row.applyBtn:SetPoint("LEFT", row.cols[12], "LEFT", 0, 0)
        row.applyBtn:SetText("填入")
        row.applyBtn:SetScript("OnClick", function(self)
            local data = self:GetParent().data
            if data and FillSellPanel(data) then
                print("|cff00ff00[EasyAuctionPro]|r 已填入策略上架建议：" .. (data.itemName or ""))
            else
                print("|cffff2020[EasyAuctionPro]|r 未找到背包中的对应物品。")
            end
        end)
        if Pro.SkinButton then Pro.SkinButton(row.applyBtn) end

        row.postBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.postBtn:SetSize(52, 20)
        row.postBtn:SetPoint("LEFT", row.cols[13], "LEFT", 0, 0)
        row.postBtn:SetText("确认")
        row.postBtn:SetScript("OnClick", function(self)
            ConfirmSinglePost(f, self:GetParent().data)
        end)
        if Pro.SkinButton then Pro.SkinButton(row.postBtn) end
        if not ENABLE_QUEUE_BULK_POST_UI then row.postBtn:Hide() end

        row.selectCheck = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        row.selectCheck:SetSize(24, 24)
        row.selectCheck:SetPoint("LEFT", row.cols[14], "LEFT", 6, 0)
        row.selectCheck:SetScript("OnClick", function(self)
            local data = self:GetParent().data
            local key = GetSelectionKey(data)
            if not key then
                return
            end
            f.selection = f.selection or {}
            f.selectionTouched = f.selectionTouched or {}
            f.selection[key] = self:GetChecked() and true or false
            f.selectionTouched[key] = true
            UpdateBulkControls(f, Pro.queue or {})
        end)
        if not ENABLE_QUEUE_BULK_POST_UI then row.selectCheck:Hide() end
        f.rows[i] = row
    end

    f.prevBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.prevBtn:SetSize(60, 22)
    f.prevBtn:SetPoint("BOTTOMLEFT", 14, 14)
    f.prevBtn:SetText("上一页")
    f.prevBtn:SetScript("OnClick", function()
        f.page = math.max(1, (f.page or 1) - 1)
        Pro.DrawPostQueue()
    end)
    if Pro.SkinButton then Pro.SkinButton(f.prevBtn) end

    f.nextBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.nextBtn:SetSize(60, 22)
    f.nextBtn:SetPoint("LEFT", f.prevBtn, "RIGHT", 8, 0)
    f.nextBtn:SetText("下一页")
    f.nextBtn:SetScript("OnClick", function()
        f.page = (f.page or 1) + 1
        Pro.DrawPostQueue()
    end)
    if Pro.SkinButton then Pro.SkinButton(f.nextBtn) end

    f.pageText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.pageText:SetPoint("LEFT", f.nextBtn, "RIGHT", 12, 0)
    if Pro.SkinText then Pro.SkinText(f.pageText, "muted", 12) end

    f.bulkPostBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.bulkPostBtn:SetSize(136, 30)
    f.bulkPostBtn:SetPoint("BOTTOMRIGHT", -14, 14)
    f.bulkPostBtn:SetText("批量填入")
    f.bulkPostBtn:SetScript("OnClick", function()
        ConfirmBulkPost(f)
    end)
    if Pro.SkinButton then Pro.SkinButton(f.bulkPostBtn) end
    StyleBulkPostButton(f.bulkPostBtn, false)
    if not ENABLE_QUEUE_BULK_POST_UI then f.bulkPostBtn:Hide() end

    f.bulkCountText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.bulkCountText:SetPoint("RIGHT", f.bulkPostBtn, "LEFT", -12, 0)
    f.bulkCountText:SetWidth(190)
    f.bulkCountText:SetJustifyH("RIGHT")
    f.bulkCountText:SetText("")
    if Pro.SkinText then Pro.SkinText(f.bulkCountText, "muted", 12) end
    if not ENABLE_QUEUE_BULK_POST_UI then f.bulkCountText:Hide() end

    Pro.queueFrame = f
    return f
end

local function RaiseQueueFrame(frame)
    if Pro.RaiseMainFrame then
        Pro.RaiseMainFrame(frame)
    end
end

function Pro.DrawPostQueue()
    local f = CreateFrameOnce()
    Pro.ApplyFrameScale(f)
    RaiseQueueFrame(f)
    local queue = Pro.queue or Pro.RefreshPostQueue()
    EnsureQueueSelection(f, queue)
    local totalPages = math.max(1, math.ceil(#queue / MAX_ROWS))
    f.page = math.min(math.max(f.page or 1, 1), totalPages)
    local startIndex = (f.page - 1) * MAX_ROWS + 1

    f.status:SetText(string.format("共 %d 个可拍卖物品", #queue))
    f.pageText:SetText(string.format("%d / %d", f.page, totalPages))
    f.prevBtn:SetEnabled(f.page > 1)
    f.nextBtn:SetEnabled(f.page < totalPages)

    for i, row in ipairs(f.rows) do
        local data = queue[startIndex + i - 1]
        row.data = data
        row.queueIndex = startIndex + i - 1
        if data then
            local name = data.itemLink or data.itemName or ""
            row.icon:SetTexture(data.icon or (data.itemID and GetItemIcon(data.itemID)) or nil)
            row.icon:Show()
            row.cols[1]:SetText(name)
            row.cols[1]:ClearAllPoints()
            row.cols[1]:SetPoint("LEFT", row, "LEFT", 22, 0)
            row.cols[1]:SetWidth(123)
            row.cols[2]:SetText(tostring(data.bagCount or 0))
            row.cols[3]:SetText("")
            row.operationDropDown.choices = GetOperationChoices()
            row.operationDropDown:SetValue(data.operationName or Pro.GetDefaultOperationName())
            row.operationDropDown:Show()
            row.trendBtn:Show()
            row.cols[4]:SetText("")
            row.cols[5]:SetText(data.currentMin and FormatQueueMoney(data.currentMin) or "-")
            row.cols[6]:SetText(data.yesterdayMin and FormatQueueMoney(data.yesterdayMin) or "-")
            row.cols[7]:SetText(data.median7d and FormatQueueMoney(data.median7d) or "-")
            row.cols[8]:SetText(FormatQueueMoney(data.unitPrice or 0))
            row.cols[9]:SetText(string.format("%d/%d", data.stackSize or 0, data.numStacks or 0))
            row.cols[10]:SetText(data.status == "skip" and "|cffff6060跳过|r" or "|cff60ff60可上架|r")
            row.cols[11]:SetText(data.reason or "")
            row.cols[12]:SetText("")
            row.cols[13]:SetText("")
            row.cols[14]:SetText("")
            local canPost = IsPostableSuggestion(data) and not bulkPostState.running and not singlePostRunning
            UpdateApplyButtonState(row.applyBtn, data.status ~= "skip" and not singlePostRunning)
            if ENABLE_QUEUE_BULK_POST_UI then
                UpdatePostButtonState(row.postBtn, canPost)
                row.postBtn:Show()
            else
                row.postBtn:Hide()
            end
            local key = GetSelectionKey(data)
            local canSelect = key and IsPostableSuggestion(data)
            if row.selectCheck then
                if ENABLE_QUEUE_BULK_POST_UI then
                    row.selectCheck:SetEnabled(canSelect and not bulkPostState.running and not singlePostRunning)
                    row.selectCheck:SetChecked(canSelect and f.selection and f.selection[key] or false)
                    row.selectCheck:Show()
                else
                    row.selectCheck:Hide()
                end
            end
            row.reasonHitArea:Show()
            row.itemHitArea:Show()
            row:Show()
        else
            row.operationDropDown:Hide()
            row.trendBtn:Hide()
            row.applyBtn:Hide()
            row.postBtn:Hide()
            if row.selectCheck then
                row.selectCheck:Hide()
            end
            row.icon:Hide()
            row.reasonHitArea:Hide()
            row.itemHitArea:Hide()
            row:Hide()
        end
    end
    for _, row in ipairs(f.rows) do
        if row.data and row.applyBtn then
            row.applyBtn:Show()
            if ENABLE_QUEUE_BULK_POST_UI then
                row.postBtn:Show()
            else
                row.postBtn:Hide()
            end
        end
    end
    UpdateBulkControls(f, queue)
end

function Pro.ShowPostQueue()
    Pro.RefreshPostQueue()
    local f = CreateFrameOnce()
    f.page = 1
    Pro.DrawPostQueue()
    RaiseQueueFrame(f)
    f:Show()
end

function _G.EasyAuctionPro_ShowPostQueue()
    Pro.ShowPostQueue()
end

function _G.EasyAuctionPro_BulkPostQueue()
    if not ENABLE_QUEUE_BULK_POST_UI then
        Pro.ShowPostQueue()
        print("|cffffd200[EasyAuctionPro]|r 批量填入功能当前已隐藏，请使用队列中的“填入”逐条处理。")
        return
    end
    if not Pro.queue then
        Pro.RefreshPostQueue()
    end
    local f = CreateFrameOnce()
    Pro.DrawPostQueue()
    f:Show()
    ConfirmBulkPost(f)
end

SLASH_EASYAUCTIONPRO1 = "/eapro"
SlashCmdList.EASYAUCTIONPRO = function(msg)
    msg = msg or ""
    local cmd, rest = string.match(msg, "^(%S*)%s*(.-)$")
    cmd = string.lower(cmd or "")
    if cmd == "queue" or cmd == "" then
        Pro.ShowPostQueue()
    elseif cmd == "postall" or cmd == "bulkpost" then
        _G.EasyAuctionPro_BulkPostQueue()
    elseif cmd == "strategy" or cmd == "config" or cmd == "settings" then
        if Pro.ShowStrategyEditor then
            Pro.ShowStrategyEditor()
        end
    elseif cmd == "maintain" or cmd == "maintenance" or cmd == "owner" then
        if Pro.ShowMaintenance then
            Pro.ShowMaintenance("owner")
        end
    elseif cmd == "ledger" then
        if Pro.ShowMaintenance then
            Pro.ShowMaintenance("ledger")
        end
    elseif cmd == "restock" then
        if Pro.ShowBuyFrame then
            Pro.ShowBuyFrame()
        elseif Pro.ShowRestock then
            Pro.ShowRestock()
        end
    elseif cmd == "snipe" or cmd == "sniper" then
        if Pro.ShowBuyFrame then
            Pro.ShowBuyFrame()
        elseif Pro.ShowStrategySnipe then
            Pro.ShowStrategySnipe()
        end
    elseif cmd == "shopping" or cmd == "list" or cmd == "buy" then
        if Pro.ShowShoppingList then
            Pro.ShowShoppingList()
        elseif Pro.ShowBuyFrame then
            Pro.ShowBuyFrame()
        end
    elseif cmd == "help" or cmd == "guide" then
        if Pro.ShowHelp then
            Pro.ShowHelp()
        end
    elseif cmd == "group" then
        local itemID, groupName = string.match(rest or "", "^(%d+)%s+(.+)$")
        if itemID and groupName and Pro.SetItemGroup(tonumber(itemID), groupName) then
            print("|cff00ff00[EasyAuctionPro]|r 已设置物品策略组：" .. itemID .. " -> " .. groupName)
        else
            print("|cffff2020[EasyAuctionPro]|r 用法：/eapro group 物品ID 分组名")
        end
    elseif cmd == "op" then
        local groupName, opName = string.match(rest or "", "^(.+)%s+(.+)$")
        if groupName and opName and Pro.SetGroupAuctionOperation(groupName, opName) then
            print("|cff00ff00[EasyAuctionPro]|r 已设置分组拍卖策略：" .. groupName .. " -> " .. opName)
        else
            print("|cffff2020[EasyAuctionPro]|r 用法：/eapro op 分组名 策略名")
        end
    else
        print("|cffffd200[EasyAuctionPro]|r /eapro queue 队列；strategy 策略；maintain 维护；ledger 复盘。")
        print("|cffffd200[EasyAuctionPro]|r /eapro shopping 购物清单；help 帮助。")
    end
end

SLASH_EASYAUCTIONPROBULKPOST1 = "/eapropostall"
SlashCmdList.EASYAUCTIONPROBULKPOST = function()
    _G.EasyAuctionPro_BulkPostQueue()
end

local function StyleButton(button)
    if button and _G.EAStyle and _G.EAStyle.SkinButton then
        _G.EAStyle:SkinButton(button)
    elseif button and _G.EasyAuctionStyle and _G.EasyAuctionStyle.SkinButton then
        _G.EasyAuctionStyle:SkinButton(button)
    end
end

local PRO_HELP_TEXT = [[
你可以把 Pro 理解成三件事：
先用“策略”告诉插件怎么定价和上架，
再用“队列”把背包物品生成建议，
最后用“买入”和“运营”补货、捡漏、复盘和维护异常拍卖。

|cff80d8ff快速索引|r

1. 主界面入口：买入、队列、策略、运营、帮助。
2. 策略上架：先配置策略，再打开队列检查建议。
3. 买入助手：补货扫描和策略狙击。
4. 运营维护：异常拍卖、账本复盘和流拍判断。

|cffffd200一、主界面入口|r

买入：打开买入助手，里面有“补货扫描”和“策略狙击”两个页签。
队列：打开策略上架队列，扫描背包可拍卖物品，并按策略生成建议价格、堆叠和组数。
策略：打开策略设置，管理拍卖方案、策略组、单物品绑定、分类绑定和建议价计算。
运营：打开运营维护，查看我的拍卖建议、复盘账本，并取消异常拍卖。
帮助：打开本说明。

|cffffd200二、推荐工作流|r

1. 先点“策略”，确认默认策略是否适合你的物品。
2. 在策略设置里创建分组，例如“材料”“消耗品”“装备图纸”。
3. 把物品或分类绑定到分组，再把分组绑定到拍卖策略。
4. 回到拍卖行闪卖页，点“队列”，检查每一行建议。
5. 少量物品可逐行点“填入”，插件会把该物品放入拍卖栏并填写建议价格、堆叠和组数。

|cffffd200三、策略上架队列|r

队列会扫描背包里可拍卖、非绑定的物品。
每一行通常包含物品名、背包数量、策略、走势、价格参考、建议单价、堆叠/组数、状态、原因和“填入”。

策略下拉：可以临时切换某个物品使用的策略。切换后该行会重新计算建议。
走势：查看该物品的价格走势，适合在填入前判断当前价是否异常。
当前最低 / 昨日最低 / 7日中位：帮助你对比“现在市场价”和“最近正常价”。
建议单价：由当前市场价格、价格库历史和策略参数共同算出。
堆叠/组数：告诉你建议每组多少个、上多少组。
状态：
- 可上架：当前参数下可以生成建议。
- 跳过：价格或数量不满足策略，例如低于底价、保留数量后没有可卖库存、流拍次数超过限制。
填入：把这一行的物品、价格、堆叠和组数填到闪卖面板，适合少量物品逐个检查。

|cffffd200四、策略设置：价格参数|r

策略是 Pro 的核心。
它不是简单地“永远压最低价”，而是先算出底价、正常价和最高价，再根据当前市场决定是否跟价、保护价格或跳过。

价格源：
- 7日中位价：最近 7 天价格的中间水平，抗波动能力强，适合大多数物品。
- 当前最低价：拍卖行当前最低单价，适合快速出手和材料薄利，但容易被离谱低价带偏。
- 历史最低价：价格库记录过的历史低位，适合保守参考。
- 昨日最低价：昨天的低价记录，适合短周期波动参考。
- 固定价：完全使用你填的铜币价格，适合价格稳定或你有明确心理价的物品。

最低价源 / 最低价比例：
最低价是保护线。
比如最低价源为 7日中位价，比例 0.75，表示低于中位价 75% 时不建议继续跟价。
比例越高越保守，越不容易贱卖；比例越低越激进，越容易卖出但利润可能变薄。

正常价源 / 正常价比例：
正常价是没有可靠当前最低价时的建议价，也是在异常低价环境下回退使用的价格。
比例 0.95 表示按参考价的 95% 上架。
提高它会让建议价更高，降低它会更容易成交。

最高价源 / 最高价比例：
最高价是封顶线。当前最低价过高时，Pro 不会盲目跟到离谱高价，而是限制在最高价以内。
比例越高，允许试探高价的空间越大；比例越低，价格更贴近日常成交区间。

压价铜：
当当前最低价在合理区间内，Pro 通常会用“当前最低价 - 压价铜”作为建议。
压价铜为 1 表示只便宜 1 铜，避免无意义大幅压价。
填 0 表示不压价，填很大则会明显拉低市场价，不建议常用。

异常低价比例 / 异常低价数量：
这两个参数用来识别“一个或少数人挂了离谱低价”的情况。
当前低价低于参考价的一定比例，且低价数量不多时，队列会认为这是异常低价，不会跟着砸盘，而是回到正常价或底价附近。
异常低价比例越高，越容易判定低价异常；越低，越愿意跟随市场低价。
异常低价数量越大，表示允许更多低价拍卖仍被视为异常。

|cffffd200五、策略设置：上架数量参数|r

保留数量：
从背包数量中扣除不卖的数量。
比如背包有 80 个，保留 20 个，只会按 60 个计算可上架数量。
适合自用材料、消耗品和任务物品。

上架上限：
限制本次最多上多少组。
它控制市场铺货量，避免一次把全部库存挂出去。
材料可设高一些，稀有装备建议低一些。

堆叠数：
每组放多少个。
材料常用 20，装备通常 1。
堆叠数过大可能不适合买家小额购买，过小会增加上架次数。

组数：
理想上架组数。
最终组数还会受到背包数量、保留数量、上架上限影响。

时长(1-3)：
拍卖时长档位。
1 通常是短时，适合流动快的材料；
2 适合稳价物品；
3 适合慢卖物品，但押金占用和流拍风险更高。

流拍上限：
如果某物品流拍次数达到上限，队列会提示跳过，避免持续为卖不动的东西付押金。
填 0 表示不启用这个限制。

|cffffd200六、分组、单物品绑定和分类绑定|r

分组是“物品 -> 分组 -> 策略”的中间层。
好处是你不用给每个物品都单独设置完整策略。

创建分组：
在策略设置中输入分组名，选择拍卖策略，点创建或绑定。

单物品绑定：
选择或输入物品 ID，把它绑定到某个分组。
单物品绑定优先级最高，适合特殊物品，例如稀有图纸、贵重材料、节日物品。

分类绑定：
把某个分类绑定到分组。
适合批量管理，例如把“商品”或某个材料分类统一走“材料薄利”。
如果同时存在单物品绑定和分类绑定，通常以单物品绑定为准。

建议价计算：
输入物品 ID、物品名和背包数量，点计算后可预览这个物品在当前策略下会得到什么建议价、堆叠和跳过原因。
它适合在真正上架前测试参数。

|cffffd200七、买入助手：补货扫描|r

补货扫描用于“库存不足时买入”。
它根据目标库存、当前库存和最高买入价筛选当前浏览结果。

目标库存：
希望最终拥有多少个。当前库存低于目标库存时，才会出现补货建议。

最高%：
按参考价格计算最高可买价。
例如 80 表示最高买入价为 7日中位价的 80%。
数值越低越谨慎，越容易错过；越高越容易买到，但利润空间变小。

数量：
单次最多买多少个。它防止一次扫太多货。

花费G：
单次最多花多少金币。它是风险阀门，避免误点或市场异常时花超预算。

购买：
点购买会弹确认框。确认前请看清物品、数量和总价。

|cffffd200八、买入助手：策略狙击|r

策略狙击用于“当前价格明显低于参考价格时买入”。默认参考 7日中位价。

低于中位%：
比如 70 表示只显示低于 7日中位价 70% 的拍卖。
数值越低，越便宜但机会更少；数值越高，机会更多但安全边际变小。

数量和花费G：
和补货扫描一样，用来限制单次购买数量与预算。

适合场景：
材料价格短暂下探、玩家误挂低价、冷门物品偶发低价。
不要只看折扣，也要看物品是否真的卖得动。

|cffffd200九、运营维护|r

运营页会读取你的拍卖和 Pro 账本数据，帮助你发现异常。

我的拍卖建议：
查看当前在售物品，识别低于策略底价、长时间未卖出或需要保留的拍卖。
行内“取消”用于撤下单条异常拍卖。

取消异常：
批量取消被判定为异常的拍卖，例如价格低于策略底价。
使用前建议先刷新并检查列表，避免取消你本来就想清仓的物品。

账本复盘：
查看已上架、已购买、已售出、已流拍等记录。
Pro 会用这些记录辅助判断流拍次数、成交表现和运营风险。

|cffffd200十一、背后的计算逻辑|r

1. Pro 先取得物品的分组和策略。单物品绑定优先，其次分类绑定，最后默认分组。
2. 根据策略中的价格源取参考价，例如 7日中位价或当前最低价。
3. 用参考价乘以比例，得到最低价、正常价和最高价。
4. 如果当前最低价低于最低价，或被判定为异常低价，Pro 不会盲目跟价，会回退到正常价或底价附近。
5. 如果当前最低价高于最高价，Pro 会用最高价封顶。
6. 如果当前最低价在合理范围内，Pro 用当前最低价减去压价铜，尽量排在前面但不大幅破坏市场。
7. 再扣除保留数量，计算可卖数量，并按堆叠数、组数和上架上限得出最终建议。
8. 如果可卖数量为 0、没有价格参考、流拍次数超过限制，就会显示跳过和原因。

|cffffd200十二、调参建议|r

想快卖：使用“快速出手”或降低正常价比例，参考当前最低价，时长选短。
想稳价：提高最低价比例，使用 7日中位价，降低上架上限。
材料走量：堆叠数 20，上架上限和组数可高一些，压价铜保持 1。
稀有装备：堆叠数 1，上架上限 1，正常价和最高价比例可高一些，时长可选 2。
避免亏本：提高最低价比例、设置异常低价比例和保留数量。
避免占用太多金币：买入助手里降低数量和花费G。

|cffffd200十三、常见问题|r

队列没有物品：确认背包有可拍卖且未绑定的物品，并点击刷新。
没有建议价：价格库或历史数据不足，可先扫描价格库，或在策略里使用固定价。
显示跳过：看“原因”列，通常是低于底价、保留数量后无可卖库存、流拍次数达到上限。
买入列表为空：当前浏览结果没有低于你的最高买入价，或数量/预算限制太严。
按钮看不清：Pro 会尽量使用主版皮肤和不透明背景；如果仍异常，尝试关闭冲突插件后 /reload。
]]

local function RaiseProHelpFrame(frame)
    if Pro.RaiseHelpFrame then
        Pro.RaiseHelpFrame(frame)
    elseif frame then
        frame:SetFrameStrata("DIALOG")
        frame:SetFrameLevel(120)
        frame:SetToplevel(true)
    end
end

local function SkinProHelpPanel(panel, alpha)
    if not panel then return end
    local style = Pro.GetStyle and Pro.GetStyle() or _G.EAStyle or _G.EasyAuctionStyle
    if panel.SetBackdrop then
        panel:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
    end
    if panel.SetBackdropColor then
        local p = style and style.Palette and style:Palette() or nil
        if p then
            local bg = p.plot or p.panel or { 0.07, 0.08, 0.10 }
            local border = p.border or { 0.26, 0.30, 0.34 }
            panel:SetBackdropColor(bg[1], bg[2], bg[3], alpha or 0.90)
            panel:SetBackdropBorderColor(border[1], border[2], border[3], 0.95)
        else
            panel:SetBackdropColor(0.055, 0.060, 0.075, alpha or 0.92)
            panel:SetBackdropBorderColor(0.25, 0.28, 0.34, 0.95)
        end
    end
end

local function RefreshProHelpFrameStyle(frame)
    if not frame then return end
    SkinProHelpPanel(frame.headerPanel, 0.56)
    SkinProHelpPanel(frame.contentPanel, 0.84)
end

local function CreateProHelpFrame()
    if Pro.helpFrame then
        return Pro.helpFrame
    end

    local f = CreateFrame("Frame", "EasyAuctionProHelpFrame", UIParent, "BackdropTemplate")
    f:SetSize(820, 620)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    if Pro.ApplyFrameScale then Pro.ApplyFrameScale(f) end
    if Pro.SkinFrame then Pro.SkinFrame(f, "window") end
    tinsert(UISpecialFrames, "EasyAuctionProHelpFrame")

    f.headerPanel = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.headerPanel:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -12)
    f.headerPanel:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -12)
    f.headerPanel:SetHeight(66)
    f.headerPanel:SetFrameLevel((f:GetFrameLevel() or 1) + 1)
    SkinProHelpPanel(f.headerPanel, 0.56)

    f.headerLine = f.headerPanel:CreateTexture(nil, "OVERLAY")
    f.headerLine:SetTexture("Interface\\Buttons\\WHITE8X8")
    f.headerLine:SetPoint("BOTTOMLEFT", f.headerPanel, "BOTTOMLEFT", 12, 0)
    f.headerLine:SetPoint("BOTTOMRIGHT", f.headerPanel, "BOTTOMRIGHT", -12, 0)
    f.headerLine:SetHeight(1)
    f.headerLine:SetVertexColor(0.22, 0.86, 1, 0.48)

    f.title = f.headerPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", f.headerPanel, "TOPLEFT", 16, -12)
    f.title:SetText("|cff00e5ffEasyAuction Pro|r |cffffd200功能使用指南|r")
    f.title:SetJustifyH("LEFT")
    if f.title.SetDrawLayer then f.title:SetDrawLayer("OVERLAY", 7) end
    if Pro.SkinText then Pro.SkinText(f.title, "accent", 18) end

    f.subtitle = f.headerPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.subtitle:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -6)
    f.subtitle:SetPoint("RIGHT", f.headerPanel, "RIGHT", -18, 0)
    f.subtitle:SetJustifyH("LEFT")
    f.subtitle:SetText("|cff9aa8b8策略配置、队列上架、买入助手与运营维护的完整说明|r")
    if f.subtitle.SetDrawLayer then f.subtitle:SetDrawLayer("OVERLAY", 7) end
    if Pro.SkinText then Pro.SkinText(f.subtitle, "muted", 12) end

    local closeBtn = Pro.CreateCloseButton and Pro.CreateCloseButton(f)
        or CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)

    f.contentPanel = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.contentPanel:SetPoint("TOPLEFT", f.headerPanel, "BOTTOMLEFT", 0, -12)
    f.contentPanel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 18)
    SkinProHelpPanel(f.contentPanel, 0.84)

    local scroll = CreateFrame("ScrollFrame", "EasyAuctionProHelpScrollFrame", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", f.contentPanel, "TOPLEFT", 18, -18)
    scroll:SetPoint("BOTTOMRIGHT", f.contentPanel, "BOTTOMRIGHT", -30, 18)

    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(730, 1)
    scroll:SetScrollChild(child)

    local text = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
    text:SetWidth(720)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetSpacing(6)
    if text.SetWordWrap then text:SetWordWrap(true) end
    if text.SetNonSpaceWrap then text:SetNonSpaceWrap(false) end
    text:SetText(PRO_HELP_TEXT)
    if Pro.SkinText then Pro.SkinText(text, "text", 12) end
    child:SetHeight(math.max(500, text:GetStringHeight() + 28))

    f.helpText = text
    f.scrollChild = child
    local style = Pro.GetStyle and Pro.GetStyle() or _G.EAStyle or _G.EasyAuctionStyle
    if style and style.OnTheme then
        style:OnTheme(function()
            RefreshProHelpFrameStyle(f)
        end)
    end
    f:Hide()
    Pro.helpFrame = f
    return f
end

function Pro.ShowHelp()
    local f = CreateProHelpFrame()
    if Pro.ApplyFrameScale then Pro.ApplyFrameScale(f) end
    RaiseProHelpFrame(f)
    if f.scrollChild and f.helpText then
        f.scrollChild:SetHeight(math.max(500, f.helpText:GetStringHeight() + 28))
    end
    f:Show()
end

function _G.EasyAuctionPro_ShowHelp()
    Pro.ShowHelp()
end

local function CreatePriceDBStrategyButton()
    local dbFrame = _G.EasyAuctionDBFrame
    if not dbFrame or dbFrame.EasyAuctionProStrategyButton then
        return
    end

    local button = CreateFrame("Button", "EasyAuctionProDBStrategyButton", dbFrame, "UIPanelButtonTemplate")
    button:SetSize(80, 22)
    button:SetText("Pro策略")
    StyleButton(button)
    button:SetScript("OnClick", function()
        if Pro.ShowStrategyEditor then
            Pro.ShowStrategyEditor("price")
        end
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("|cffffd200EasyAuction Pro 策略设置|r")
        GameTooltip:AddLine("从价格库进入策略模板、策略组和物品绑定。", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    dbFrame.EasyAuctionProStrategyButton = button
    dbFrame:HookScript("OnShow", function()
        if dbFrame.EasyAuctionProLayoutPriceDBButton then
            dbFrame:EasyAuctionProLayoutPriceDBButton()
        end
    end)
    function dbFrame:EasyAuctionProLayoutPriceDBButton()
        local anchor = self.EA_ExportBtn or self.EA_CategoryManageBtn
        if anchor and anchor:IsShown() then
            button:ClearAllPoints()
            button:SetPoint("RIGHT", anchor, "LEFT", -6, 0)
        else
            button:ClearAllPoints()
            button:SetPoint("TOPRIGHT", self, "TOPRIGHT", -284, -14)
        end
        StyleButton(button)
        button:Show()
        if _G.EasyAuction_LayoutDBFrameControls then
            _G.EasyAuction_LayoutDBFrameControls()
        end
    end
    if dbFrame.EA_ExportBtn then
        dbFrame.EA_ExportBtn:HookScript("OnShow", function()
            dbFrame:EasyAuctionProLayoutPriceDBButton()
        end)
        dbFrame.EA_ExportBtn:HookScript("OnHide", function()
            dbFrame:EasyAuctionProLayoutPriceDBButton()
        end)
    end
    if dbFrame.EA_CategoryManageBtn then
        dbFrame.EA_CategoryManageBtn:HookScript("OnShow", function()
            dbFrame:EasyAuctionProLayoutPriceDBButton()
        end)
        dbFrame.EA_CategoryManageBtn:HookScript("OnHide", function()
            dbFrame:EasyAuctionProLayoutPriceDBButton()
        end)
    end
    dbFrame:EasyAuctionProLayoutPriceDBButton()
end

local function FitProButtonMetrics(footer, mainFrame, count)
    local gap = 4
    local width = 42
    local buyWidth = 74
    local height = 22
    local available = footer.GetWidth and footer:GetWidth() or 0
    if (not available or available <= 0) and mainFrame and mainFrame.GetWidth then
        available = mainFrame:GetWidth() - 12
    end
    available = math.max((available or 0) - 2, 0)

    local total = buyWidth + math.max(count - 1, 0) * width + math.max(count - 1, 0) * gap
    if available > 0 and total > available then
        width = math.floor((available - buyWidth - math.max(count - 1, 0) * gap) / math.max(count - 1, 1))
        if width < 34 then
            gap = 2
            buyWidth = 68
            width = math.floor((available - buyWidth - math.max(count - 1, 0) * gap) / math.max(count - 1, 1))
        end
        width = math.max(width, 30)
    end
    return width, height, gap, buyWidth
end

local PRO_FOOTER_RESERVE_HEIGHT = 26

function _G.EasyAuctionPro_LayoutHeaderButtons()
    local strategyBtn = _G.EasyAuctionProStrategyButton
    local queueBtn = _G.EasyAuctionProPostQueueButton
    local maintainBtn = _G.EasyAuctionProMaintenanceButton
    local buyBtn = _G.EasyAuctionProBuyButton
    local helpBtn = _G.EasyAuctionProHelpButton
    local mainFrame = _G.AuctionBar and _G.AuctionBar.AuctionFrame or _G.AuctionHelper
    local footer = mainFrame and mainFrame.EAFooter
    if not strategyBtn or not queueBtn or not maintainBtn or not buyBtn or not helpBtn or not mainFrame or not footer then
        return
    end

    if not mainFrame.EAProFooter then
        local proFooter = CreateFrame("Frame", "EasyAuctionProFooter", mainFrame)
        proFooter:SetHeight(22)
        proFooter:SetFrameLevel((footer.GetFrameLevel and footer:GetFrameLevel() or mainFrame:GetFrameLevel()) + 1)
        mainFrame.EAProFooter = proFooter
    end

    local proFooter = mainFrame.EAProFooter
    mainFrame.EAProFooterReserveHeight = PRO_FOOTER_RESERVE_HEIGHT
    if mainFrame.EAContent then
        mainFrame.EAContent:ClearAllPoints()
        if mainFrame.EATabStrip then
            mainFrame.EAContent:SetPoint("TOPLEFT", mainFrame.EATabStrip, "BOTTOMLEFT", -8, -6)
        else
            mainFrame.EAContent:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 6, -72)
        end
        mainFrame.EAContent:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -3, 66)
    end

    footer:ClearAllPoints()
    footer:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 6, 35)
    footer:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -6, 35)
    footer:SetHeight(24)

    proFooter:ClearAllPoints()
    proFooter:SetPoint("TOPLEFT", footer, "BOTTOMLEFT", 0, -4)
    proFooter:SetPoint("TOPRIGHT", footer, "BOTTOMRIGHT", 0, -4)
    proFooter:SetHeight(22)
    proFooter:Show()
    local footerLevel = math.max((mainFrame.EAContent and mainFrame.EAContent:GetFrameLevel() or 0) + 8,
        (mainFrame:GetFrameLevel() or 0) + 8)
    footer:SetFrameLevel(footerLevel)
    proFooter:SetFrameLevel(footerLevel + 1)
    buyBtn:ClearAllPoints()
    queueBtn:ClearAllPoints()
    strategyBtn:ClearAllPoints()
    maintainBtn:ClearAllPoints()
    helpBtn:ClearAllPoints()

    local levelBase = proFooter.GetFrameLevel and proFooter:GetFrameLevel() or footerLevel
    local buttons = { buyBtn, queueBtn, strategyBtn, maintainBtn, helpBtn }
    local buttonWidth, buttonHeight, gap, buyButtonWidth = FitProButtonMetrics(footer, mainFrame, #buttons)
    for i = #buttons, 1, -1 do
        local button = buttons[i]
        local width = button == buyBtn and buyButtonWidth or buttonWidth
        button:SetParent(proFooter)
        button:SetFrameStrata(mainFrame:GetFrameStrata() or "MEDIUM")
        button:SetFrameLevel(levelBase + 1)
        button:ClearAllPoints()
        button:SetSize(width, buttonHeight)
        if i == #buttons then
            button:SetPoint("RIGHT", proFooter, "RIGHT", 0, 0)
        else
            button:SetPoint("RIGHT", buttons[i + 1], "LEFT", -gap, 0)
        end
        StyleButton(button)
        button:Show()
        local fs = button:GetFontString()
        if fs then
            fs:SetFont(_G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", width < 34 and 11 or 13, "")
            fs:SetJustifyH("CENTER")
            if button == helpBtn then
                fs:SetTextColor(1.00, 0.88, 0.38, 1)
            end
        end
    end
    if mainFrame.EARefreshLayout then
        mainFrame.EARefreshLayout()
    end
end

function _G.EasyAuctionPro_CreatePostQueueButton()
    local mainFrame = _G.AuctionBar and _G.AuctionBar.AuctionFrame or _G.AuctionHelper
    if not mainFrame or not mainFrame.EAFooter then
        return
    end
    if _G.EasyAuctionProPostQueueButton then
        _G.EasyAuctionPro_LayoutHeaderButtons()
        return
    end
    local strategyBtn = CreateFrame("Button", "EasyAuctionProStrategyButton", mainFrame, "UIPanelButtonTemplate")
    strategyBtn:SetSize(42, 22)
    strategyBtn:SetText("策略")
    strategyBtn:SetScript("OnClick", function()
        if Pro.ShowStrategyEditor then
            Pro.ShowStrategyEditor()
        end
    end)
    strategyBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("|cffffd200EasyAuction Pro 策略设置|r")
        GameTooltip:AddLine("编辑拍卖策略模板、策略组和物品/分类绑定。", 1, 1, 1)
        GameTooltip:Show()
    end)
    strategyBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local btn = CreateFrame("Button", "EasyAuctionProPostQueueButton", mainFrame, "UIPanelButtonTemplate")
    btn:SetSize(42, 22)
    btn:SetText("队列")
    btn:SetScript("OnClick", function()
        Pro.ShowPostQueue()
    end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("|cffffd200EasyAuction Pro 策略上架队列|r")
        GameTooltip:AddLine("扫描背包，按 Pro 策略生成建议上架列表。", 1, 1, 1)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local maintainBtn = CreateFrame(
        "Button",
        "EasyAuctionProMaintenanceButton",
        mainFrame,
        "UIPanelButtonTemplate"
    )
    maintainBtn:SetSize(42, 22)
    maintainBtn:SetText("运营")
    maintainBtn:SetScript("OnClick", function()
        if Pro.ShowMaintenance then
            Pro.ShowMaintenance("owner")
        end
    end)
    maintainBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("|cffffd200EasyAuction Pro 运营维护|r")
        GameTooltip:AddLine("查看我的拍卖建议、复盘账本，并可取消异常拍卖。", 1, 1, 1)
        GameTooltip:Show()
    end)
    maintainBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local helpBtn = CreateFrame(
        "Button",
        "EasyAuctionProHelpButton",
        mainFrame,
        "UIPanelButtonTemplate"
    )
    helpBtn:SetSize(42, 22)
    helpBtn:SetText("帮助")
    helpBtn:SetScript("OnClick", function()
        if Pro.ShowHelp then
            Pro.ShowHelp()
        end
    end)
    helpBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("|cffffd200EasyAuction Pro 帮助指南|r")
        GameTooltip:AddLine("查看 Pro 版功能、策略参数、买入、队列和运营维护的完整说明。", 1, 1, 1)
        GameTooltip:Show()
    end)
    helpBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local buyBtn = CreateFrame(
        "Button",
        "EasyAuctionProBuyButton",
        mainFrame,
        "UIPanelButtonTemplate"
    )
    buyBtn:SetSize(86, 22)
    buyBtn:SetText("购物清单")
    buyBtn:SetScript("OnClick", function()
        if Pro.ShowShoppingList then
            Pro.ShowShoppingList()
        elseif Pro.ShowBuyFrame then
            Pro.ShowBuyFrame()
        end
    end)
    buyBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("|cffffd200EasyAuction Pro 购物清单|r")
        GameTooltip:AddLine("创建、编辑和导入购物清单，并跟踪拍卖成交后的购买进度。", 1, 1, 1)
        GameTooltip:Show()
    end)
    buyBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    _G.EasyAuctionPro_LayoutHeaderButtons()
    if _G.C_Timer then
        _G.C_Timer.After(0.5, _G.EasyAuctionPro_LayoutHeaderButtons)
    end
end

local function ScheduleProMainButtons(attempt)
    attempt = attempt or 1
    if _G.C_Timer then
        _G.C_Timer.After(attempt == 1 and 0.2 or 0.3, function()
            _G.EasyAuctionPro_CreatePostQueueButton()
            if not _G.EasyAuctionProPostQueueButton and attempt < 8 then
                ScheduleProMainButtons(attempt + 1)
            end
        end)
    else
        _G.EasyAuctionPro_CreatePostQueueButton()
    end
end

local queueButtonFrame = CreateFrame("Frame")
queueButtonFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
queueButtonFrame:SetScript("OnEvent", function()
    ScheduleProMainButtons()
    C_Timer.After(0.3, CreatePriceDBStrategyButton)
end)

local lastAppliedScale

local function ApplyProScaleIfChanged()
    local scale = Pro.GetUIScale and Pro.GetUIScale() or nil
    if not scale or scale == lastAppliedScale then
        return
    end
    lastAppliedScale = scale
    if Pro.ApplyAllFrameScale then
        Pro.ApplyAllFrameScale()
    end
end

local scaleHookFrame = CreateFrame("Frame")
scaleHookFrame:RegisterEvent("PLAYER_LOGIN")
scaleHookFrame:SetScript("OnEvent", function()
    ApplyProScaleIfChanged()
    if _G.EasyAuctionConfigFrame then
        _G.EasyAuctionConfigFrame:HookScript("OnShow", function()
            ApplyProScaleIfChanged()
            if not scaleHookFrame.scaleTicker and _G.C_Timer then
                scaleHookFrame.scaleTicker = _G.C_Timer.NewTicker(0.2, ApplyProScaleIfChanged)
            end
        end)
        _G.EasyAuctionConfigFrame:HookScript("OnHide", function()
            ApplyProScaleIfChanged()
            if scaleHookFrame.scaleTicker then
                scaleHookFrame.scaleTicker:Cancel()
                scaleHookFrame.scaleTicker = nil
            end
        end)
    end
end)
