local addonName, ns = ...
ns.EasyAuctionPro = ns.EasyAuctionPro or {}
local Pro = ns.EasyAuctionPro
if not Pro then return end

local LIST_ROWS = 10
local ITEM_ROWS = 8
local PURCHASE_ROWS = 3
local LIST_ROW_HEIGHT = 28
local ITEM_ROW_HEIGHT = 30
local PURCHASE_ROW_HEIGHT = 20
local ITEM_COLUMNS = {
    { "物品", 164 },
    { "采购进度", 82 },
    { "需买", 44 },
    { "背包", 48 },
    { "单价", 112 },
    { "成本", 100 },
    { "状态", 54 },
}

local NOTEBOOK_DOWNLOAD_URL = "https://www.wclbox.com/share/ADPneUvf5fe"

local state = {
    selectedListID = nil,
    listPage = 1,
    itemPage = 1,
    purchasePage = 1,
    exportText = nil,
    revealSelectedList = true,
    sessionRefreshRegistered = false,
    sessionRefreshActive = false,
}

local function Money(copper)
    if Pro.FormatMoney then
        return Pro.FormatMoney(copper or 0)
    end
    return tostring(copper or 0)
end

local function CostMoney(copper)
    copper = math.floor(tonumber(copper) or 0)
    if copper >= 10000 then
        local size = 12
        local gold = math.floor(copper / 10000)
        return tostring(gold) .. "|TInterface\\MoneyFrame\\UI-GoldIcon:" .. size .. ":" .. size .. ":2:0|t"
    end
    return Money(copper)
end

local function PriceLabel(estimate)
    if type(estimate) ~= "table" or not estimate.unitPrice then
        return "-"
    end
    if estimate.state == "fresh" then
        return "实时 " .. Money(estimate.unitPrice)
    end
    if estimate.state == "stale" then
        return "历史 " .. Money(estimate.unitPrice)
    end
    return Money(estimate.unitPrice)
end

local function Trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function KeepSingleLine(fontString)
    if fontString.SetWordWrap then fontString:SetWordWrap(false) end
    if fontString.SetNonSpaceWrap then fontString:SetNonSpaceWrap(false) end
end

local function CreateLabel(parent, text, x, y, width)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetWidth(width or 80)
    label:SetJustifyH("LEFT")
    KeepSingleLine(label)
    label:SetText(text)
    if Pro.SkinText then Pro.SkinText(label, "muted", 11) end
    return label
end

local function CreateEdit(parent, name, x, y, width)
    local edit = CreateFrame("EditBox", name, parent, "InputBoxTemplate")
    edit:SetSize(width or 120, 20)
    edit:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    edit:SetAutoFocus(false)
    edit:SetNumeric(false)
    edit:SetFontObject("GameFontHighlightSmall")
    if Pro.SkinEditBox then Pro.SkinEditBox(edit) end
    return edit
end

local function Button(parent, text, x, y, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 72, 22)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    if Pro.SkinButton then Pro.SkinButton(button) end
    return button
end

local function RaiseFrame(frame)
    if Pro.RaiseMainFrame then
        Pro.RaiseMainFrame(frame)
    end
end

local function RegisterSessionRefresh()
    if state.sessionRefreshRegistered or type(Pro.RegisterListener) ~= "function" then
        return
    end
    local result = Pro.RegisterListener("SHOPPING_SESSION_CHANGED_V1", "shopping-buy-frame-refresh", function()
        if state.sessionRefreshActive then
            return
        end
        local frame = Pro.buyFrame
        if not frame or not frame.IsShown or not frame:IsShown() or type(Pro.DrawBuyFrame) ~= "function" then
            return
        end
        state.sessionRefreshActive = true
        Pro.DrawBuyFrame()
        state.sessionRefreshActive = false
    end)
    if type(result) ~= "table" or result.ok ~= false then
        state.sessionRefreshRegistered = true
    end
end

local function EnsureReady()
    if Pro.InitializeShoppingLists then
        local result = Pro.InitializeShoppingLists()
        if type(result) == "table" and result.ok == false then
            return result
        end
    end
    if Pro.InitializeShoppingInventory then
        local result = Pro.InitializeShoppingInventory()
        if type(result) == "table" and result.ok == false then
            return result
        end
    end
    if Pro.InitializeShoppingRuntime then
        local result = Pro.InitializeShoppingRuntime()
        if type(result) == "table" and result.ok == false then
            return result
        end
    end
    RegisterSessionRefresh()
    return { ok = true }
end

local function GetLists()
    local ready = EnsureReady()
    if type(ready) == "table" and ready.ok == false then
        return ready
    end
    return Pro.GetShoppingLists and Pro.GetShoppingLists() or {
        ok = false,
        code = "MISSING_SHOPPING_LISTS",
        message = "Shopping list module is unavailable",
    }
end

local function SelectFirstList(lists)
    if not state.selectedListID and lists and lists[1] then
        state.selectedListID = lists[1].id
        state.revealSelectedList = true
    end
    local found = false
    for _, list in ipairs(lists or {}) do
        if list.id == state.selectedListID then
            found = true
            break
        end
    end
    if not found then
        state.selectedListID = lists and lists[1] and lists[1].id or nil
        state.listPage = 1
        state.revealSelectedList = true
    end
end

local function ClampPage(page, totalPages)
    totalPages = math.max(1, tonumber(totalPages) or 1)
    page = math.floor(tonumber(page) or 1)
    if page < 1 then return 1 end
    if page > totalPages then return totalPages end
    return page
end

local function FindListIndex(lists, listID)
    for index, list in ipairs(lists or {}) do
        if list.id == listID then
            return index
        end
    end
end

local function SetMouseWheelPaging(frame, callback)
    if not frame or type(callback) ~= "function" then
        return
    end
    if frame.EnableMouseWheel then
        frame:EnableMouseWheel(true)
    end
    frame:SetScript("OnMouseWheel", callback)
end

local function SortedItems(list)
    local items = {}
    for itemID, entry in pairs(list and list.items or {}) do
        items[#items + 1] = {
            itemID = tonumber(itemID),
            itemName = entry.itemName,
            plannedQuantity = entry.plannedQuantity,
        }
    end
    table.sort(items, function(a, b)
        return tostring(a.itemName or a.itemID) < tostring(b.itemName or b.itemID)
    end)
    return items
end

local function LiveBagCount(itemID)
    if type(Pro.GetInventoryCount) == "function" then
        local count = tonumber(Pro.GetInventoryCount(itemID))
        if count then
            return count
        end
    end
    return 0
end

local function BankCount(itemID)
    local now = type(_G.GetTime) == "function" and _G.GetTime() or nil
    local result = Pro.GetInventorySnapshot and Pro.GetInventorySnapshot("bank", now, nil)
    if type(result) ~= "table" or not result.ok or not result.known then
        return 0
    end
    return tonumber(result.counts and result.counts[itemID]) or 0
end

local function TotalCount(itemID)
    local now = type(_G.GetTime) == "function" and _G.GetTime() or nil
    local aggregate = Pro.GetAggregatedInventory and Pro.GetAggregatedInventory(itemID, now, nil)
    local live = LiveBagCount(itemID) + BankCount(itemID)
    if type(aggregate) ~= "table" or not aggregate.ok then
        return live, false
    end
    return math.max(tonumber(aggregate.count) or 0, live), aggregate.complete == true
end

local function NonNegativeInteger(value, defaultValue)
    local number = tonumber(value)
    if not number or number < 0 then
        return defaultValue or 0
    end
    return math.floor(number)
end

local function SessionBuyStatsCount(itemID)
    itemID = tonumber(itemID)
    local stats = _G.EasyAuction_SessionBuyStats
    local entry = itemID and type(stats) == "table" and stats[itemID] or nil
    return NonNegativeInteger(entry and entry.num, 0)
end

local function SessionBuyStatsCost(itemID)
    itemID = tonumber(itemID)
    local stats = _G.EasyAuction_SessionBuyStats
    local entry = itemID and type(stats) == "table" and stats[itemID] or nil
    return NonNegativeInteger(entry and entry.sum, 0)
end

local function ProgressLabel(baseline, bought, planned, active, liveBags)
    if active or bought > 0 then
        return string.format("%d+|cff40ff80%d|r/%d", baseline, bought, planned)
    end
    return string.format("%d/%d", liveBags, planned)
end

local function ShoppingProgress(itemID, plannedQuantity)
    itemID = tonumber(itemID)
    local planned = NonNegativeInteger(plannedQuantity, 0)
    local liveBags = LiveBagCount(itemID)
    if Pro.EnsureShoppingSessionBaseline then
        Pro.EnsureShoppingSessionBaseline(itemID, liveBags)
    end

    local completion = Pro.GetShoppingCompletion and Pro.GetShoppingCompletion(itemID, planned)
    local active = completion and completion.ok and completion.state == "active"
    local baseline = active and NonNegativeInteger(completion.baseline, liveBags) or liveBags
    local bought = math.max(active and NonNegativeInteger(completion.purchases, 0) or 0, SessionBuyStatsCount(itemID))
    local progress = (active or bought > 0) and (baseline + bought) or liveBags
    local needed = planned - progress
    if needed < 0 then needed = 0 end

    return {
        itemID = itemID,
        plannedQuantity = planned,
        baseline = baseline,
        liveBags = liveBags,
        bought = bought,
        progress = progress,
        neededQuantity = needed,
        ownedQuantity = progress,
        active = active or bought > 0,
        completed = progress >= planned and planned > 0,
        progressLabel = ProgressLabel(baseline, bought, planned, active, liveBags),
    }
end

local function CurrentPurchaseRows(items)
    local rows = {}
    for _, item in ipairs(items or {}) do
        local itemID = tonumber(item.itemID)
        if itemID then
            local progress = item.progress
            local quantity = progress and NonNegativeInteger(progress.bought, 0) or SessionBuyStatsCount(itemID)
            local cost = SessionBuyStatsCost(itemID)
            if quantity > 0 or cost > 0 then
                rows[#rows + 1] = {
                    itemID = itemID,
                    itemName = item.itemName,
                    quantity = quantity,
                    cost = cost,
                }
            end
        end
    end
    table.sort(rows, function(a, b)
        return tostring(a.itemName or a.itemID) < tostring(b.itemName or b.itemID)
    end)
    return rows
end

local function EstimateByItem(summary)
    local byID = {}
    for _, entry in ipairs(summary and summary.items or {}) do
        byID[tonumber(entry.itemID)] = entry
    end
    return byID
end

local function ItemIcon(itemID)
    if type(_G.GetItemIcon) == "function" then
        return _G.GetItemIcon(itemID)
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function SelectDialogText(dialog)
    if dialog and dialog.edit then
        dialog.edit:SetFocus()
        if dialog.edit.SetCursorPosition then
            dialog.edit:SetCursorPosition(0)
        end
        dialog.edit:HighlightText()
    end
end

local function CreateShoppingTextDialog()
    if Pro.shoppingTextDialog then
        return Pro.shoppingTextDialog
    end

    local dialog = CreateFrame("Frame", "EasyAuctionProShoppingTextDialog", UIParent, "BackdropTemplate")
    dialog:SetSize(560, 360)
    dialog:SetPoint("CENTER")
    dialog:SetFrameStrata("FULLSCREEN_DIALOG")
    if dialog.SetToplevel then dialog:SetToplevel(true) end
    dialog:EnableMouse(true)
    dialog:SetMovable(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", dialog.StartMoving)
    dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
    if Pro.ApplyFrameScale then Pro.ApplyFrameScale(dialog) end
    if Pro.SkinFrame then Pro.SkinFrame(dialog, "window") end
    tinsert(UISpecialFrames, "EasyAuctionProShoppingTextDialog")

    dialog.title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    dialog.title:SetPoint("TOPLEFT", 16, -14)
    dialog.title:SetText("购物清单文本")
    if Pro.SkinText then Pro.SkinText(dialog.title, "accent", 14) end

    local closeBtn = Pro.CreateCloseButton and Pro.CreateCloseButton(dialog) or CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -8, -8)

    dialog.help = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dialog.help:SetPoint("TOPLEFT", dialog, "TOPLEFT", 18, -44)
    dialog.help:SetWidth(524)
    dialog.help:SetJustifyH("LEFT")
    if Pro.SkinText then Pro.SkinText(dialog.help, "muted", 12) end

    dialog.box = CreateFrame("Frame", nil, dialog, "BackdropTemplate")
    dialog.box:SetPoint("TOPLEFT", dialog, "TOPLEFT", 18, -72)
    dialog.box:SetSize(524, 210)
    if Pro.SkinHeader then Pro.SkinHeader(dialog.box) end

    dialog.scroll = CreateFrame("ScrollFrame", "EasyAuctionProShoppingTextScrollFrame", dialog.box, "UIPanelScrollFrameTemplate")
    dialog.scroll:SetPoint("TOPLEFT", dialog.box, "TOPLEFT", 8, -8)
    dialog.scroll:SetPoint("BOTTOMRIGHT", dialog.box, "BOTTOMRIGHT", -28, 8)

    dialog.edit = CreateFrame("EditBox", "EasyAuctionProShoppingTextEdit", dialog.scroll)
    dialog.edit:SetMultiLine(true)
    dialog.edit:SetAutoFocus(false)
    dialog.edit:SetFontObject("GameFontHighlightSmall")
    dialog.edit:SetWidth(478)
    dialog.edit:SetHeight(190)
    dialog.edit:SetMaxLetters(0)
    if dialog.edit.SetTextInsets then dialog.edit:SetTextInsets(4, 4, 4, 4) end
    dialog.edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    dialog.scroll:SetScrollChild(dialog.edit)
    if Pro.SkinEditBox then Pro.SkinEditBox(dialog.edit) end

    dialog.status = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dialog.status:SetPoint("TOPLEFT", dialog, "TOPLEFT", 18, -290)
    dialog.status:SetWidth(524)
    dialog.status:SetJustifyH("LEFT")
    KeepSingleLine(dialog.status)
    if Pro.SkinText then Pro.SkinText(dialog.status, "muted", 12) end

    dialog.primaryBtn = Button(dialog, "导入", 278, -320, 82, function()
        if dialog.mode == "import" then
            local text = dialog.edit:GetText() or ""
            local result = Pro.ImportShoppingListText and Pro.ImportShoppingListText(text, {
                mode = dialog.targetListID and "merge" or "create",
                listID = dialog.targetListID,
            })
            if type(result) == "table" and result.ok then
                state.selectedListID = result.list and result.list.id or dialog.targetListID
                state.itemPage = 1
                state.purchasePage = 1
                state.revealSelectedList = true
                if dialog.ownerFrame and dialog.ownerFrame.status then
                    dialog.ownerFrame.status:SetText("|cff60ff60导入完成。|r")
                end
                dialog:Hide()
                if Pro.DrawBuyFrame then Pro.DrawBuyFrame() end
            else
                dialog.status:SetText("|cffff6060导入失败：" .. tostring(result and result.message or "文本格式不正确") .. "|r")
            end
        else
            SelectDialogText(dialog)
            dialog.status:SetText("|cff60ff60已全选。请按 Ctrl+C 复制。|r")
        end
    end)

    dialog.secondaryBtn = Button(dialog, "关闭", 370, -320, 82, function()
        dialog:Hide()
    end)

    dialog.closeBtn = Button(dialog, "取消", 460, -320, 82, function()
        dialog:Hide()
    end)

    dialog:Hide()
    Pro.shoppingTextDialog = dialog
    return dialog
end

local function ShowShoppingImportPopup(frame)
    local dialog = CreateShoppingTextDialog()
    if Pro.ApplyFrameScale then Pro.ApplyFrameScale(dialog) end
    if Pro.RaiseChildDialog then Pro.RaiseChildDialog(dialog, frame) end
    dialog.mode = "import"
    dialog.ownerFrame = frame
    dialog.targetListID = state.selectedListID
    dialog.title:SetText("导入购物清单")
    dialog.help:SetText("粘贴 EASYAUCTION_SHOPPING_LIST 文本。已有清单时会合并到当前清单；未选清单时会新建。")
    dialog.edit:SetText("")
    dialog.edit:SetFocus()
    dialog.status:SetText("支持从其他插件或导出的标准购物清单文本导入。")
    dialog.primaryBtn:SetText("导入")
    dialog.secondaryBtn:SetText("清空")
    dialog.secondaryBtn:SetScript("OnClick", function()
        dialog.edit:SetText("")
        dialog.edit:SetFocus()
        dialog.status:SetText("已清空输入框。")
    end)
    dialog.closeBtn:SetText("取消")
    dialog:Show()
    if Pro.RaiseChildDialog then Pro.RaiseChildDialog(dialog, frame) end
end

local function ShowShoppingExportPopup(frame, text)
    local dialog = CreateShoppingTextDialog()
    if Pro.ApplyFrameScale then Pro.ApplyFrameScale(dialog) end
    if Pro.RaiseChildDialog then Pro.RaiseChildDialog(dialog, frame) end
    dialog.mode = "export"
    dialog.ownerFrame = frame
    dialog.targetListID = state.selectedListID
    dialog.title:SetText("导出购物清单")
    dialog.help:SetText("下方是标准购物清单文本。点击“全选”后按 Ctrl+C 复制保存。")
    dialog.edit:SetText(text or "")
    dialog.status:SetText((text and text ~= "") and "导出内容已生成并自动全选。" or "|cffff6060当前清单没有可导出的内容。|r")
    dialog.primaryBtn:SetText("全选")
    dialog.secondaryBtn:SetText("刷新")
    dialog.secondaryBtn:SetScript("OnClick", function()
        local exporter = Pro.ExportShoppingListDisplayText or Pro.ExportShoppingListText
        local result = exporter and exporter(state.selectedListID)
        if type(result) == "table" and result.ok then
            state.exportText = result.text
            dialog.edit:SetText(result.text or "")
            dialog.status:SetText("导出内容已刷新并全选。")
            SelectDialogText(dialog)
        else
            dialog.status:SetText("|cffff6060导出失败。|r")
        end
    end)
    dialog.closeBtn:SetText("关闭")
    dialog:Show()
    if Pro.RaiseChildDialog then Pro.RaiseChildDialog(dialog, frame) end
    SelectDialogText(dialog)
end

local function CreateShoppingNotebookDialog()
    if Pro.shoppingNotebookDialog then return Pro.shoppingNotebookDialog end

    local dialog = CreateFrame("Frame", "EasyAuctionProShoppingNotebookDialog", UIParent, "BackdropTemplate")
    dialog:SetSize(500, 190)
    dialog:SetPoint("CENTER")
    dialog:SetFrameStrata("FULLSCREEN_DIALOG")
    if dialog.SetToplevel then dialog:SetToplevel(true) end
    dialog:EnableMouse(true)
    dialog:SetMovable(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", dialog.StartMoving)
    dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
    if Pro.ApplyFrameScale then Pro.ApplyFrameScale(dialog) end
    if Pro.SkinFrame then Pro.SkinFrame(dialog, "window") end
    tinsert(UISpecialFrames, "EasyAuctionProShoppingNotebookDialog")

    dialog.title = dialog:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    dialog.title:SetPoint("TOPLEFT", 16, -14)
    dialog.title:SetText("下载圆圆的笔记本")
    if Pro.SkinText then Pro.SkinText(dialog.title, "accent", 14) end

    local closeBtn = Pro.CreateCloseButton and Pro.CreateCloseButton(dialog)
        or CreateFrame("Button", nil, dialog, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -8, -8)

    dialog.help = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dialog.help:SetPoint("TOPLEFT", dialog, "TOPLEFT", 18, -48)
    dialog.help:SetWidth(464)
    dialog.help:SetJustifyH("LEFT")
    dialog.help:SetText("圆圆的笔记本可在游戏内便捷生成各种采购清单，并一键导入 EasyAuction。")
    if Pro.SkinText then Pro.SkinText(dialog.help, "text", 12) end

    dialog.edit = CreateFrame("EditBox", "EasyAuctionProShoppingNotebookURL", dialog, "InputBoxTemplate")
    dialog.edit:SetSize(456, 24)
    dialog.edit:SetPoint("TOPLEFT", dialog, "TOPLEFT", 18, -78)
    dialog.edit:SetAutoFocus(false)
    dialog.edit:SetFontObject("GameFontHighlightSmall")
    dialog.edit:SetText(NOTEBOOK_DOWNLOAD_URL)
    dialog.edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    if Pro.SkinEditBox then Pro.SkinEditBox(dialog.edit) end

    dialog.status = dialog:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dialog.status:SetPoint("TOPLEFT", dialog, "TOPLEFT", 18, -112)
    dialog.status:SetWidth(280)
    dialog.status:SetJustifyH("LEFT")
    dialog.status:SetText("点击“全选地址”后按 Ctrl+C 复制。")
    if Pro.SkinText then Pro.SkinText(dialog.status, "muted", 11) end

    dialog.copyBtn = Button(dialog, "全选地址", 310, -145, 82, function()
        dialog.edit:SetFocus()
        dialog.edit:HighlightText()
        dialog.status:SetText("|cff60ff60地址已全选，请按 Ctrl+C 复制。|r")
    end)
    dialog.closeBtn = Button(dialog, "关闭", 400, -145, 82, function()
        dialog:Hide()
    end)

    dialog:Hide()
    Pro.shoppingNotebookDialog = dialog
    return dialog
end

local function ShowShoppingNotebookPopup(frame)
    local dialog = CreateShoppingNotebookDialog()
    if Pro.ApplyFrameScale then Pro.ApplyFrameScale(dialog) end
    if Pro.RaiseChildDialog then Pro.RaiseChildDialog(dialog, frame) end
    dialog.edit:SetText(NOTEBOOK_DOWNLOAD_URL)
    dialog.status:SetText("点击“全选地址”后按 Ctrl+C 复制。")
    dialog:Show()
    if Pro.RaiseChildDialog then Pro.RaiseChildDialog(dialog, frame) end
end

local function CreateFrameOnce()
    if Pro.buyFrame then
        return Pro.buyFrame
    end

    local f = CreateFrame("Frame", "EasyAuctionProBuyFrame", UIParent, "BackdropTemplate")
    f:SetSize(940, 540)
    f:SetPoint("CENTER")
    f.EasyAuctionProScaleMultiplier = 0.80
    RaiseFrame(f)
    if Pro.ApplyFrameScale then Pro.ApplyFrameScale(f) end
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    if Pro.SkinFrame then Pro.SkinFrame(f, "window") end
    tinsert(UISpecialFrames, "EasyAuctionProBuyFrame")

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", 14, -12)
    f.title:SetText("|cffffd200EasyAuction Pro|r 购物清单")
    if Pro.SkinText then Pro.SkinText(f.title, "accent", 14) end

    local closeBtn = Pro.CreateCloseButton and Pro.CreateCloseButton(f) or CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -8, -8)

    f.refreshBtn = Button(f, "刷新", 0, 0, 64, function()
        Pro.DrawBuyFrame()
    end)
    f.refreshBtn:ClearAllPoints()
    f.refreshBtn:SetPoint("RIGHT", closeBtn, "LEFT", -8, 0)

    f.left = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.left:SetPoint("TOPLEFT", 14, -48)
    f.left:SetSize(236, 428)
    if Pro.SkinHeader then Pro.SkinHeader(f.left) end

    CreateLabel(f.left, "购物清单", 10, -10, 58)
    local notebookHint = CreateLabel(f.left, "推荐 →", 70, -10, 40)
    if Pro.SkinText then Pro.SkinText(notebookHint, "accent", 11) end
    f.notebookBtn = Button(f.left, "圆圆的笔记本", 112, -8, 108, function()
        ShowShoppingNotebookPopup(f)
    end)
    f.notebookBtn.icon = f.notebookBtn:CreateTexture(nil, "OVERLAY", nil, 7)
    f.notebookBtn.icon.__EAStylePreserve = true
    f.notebookBtn.icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
    f.notebookBtn.icon:SetSize(14, 14)
    f.notebookBtn.icon:SetPoint("LEFT", f.notebookBtn, "LEFT", 5, 0)
    local notebookText = f.notebookBtn:GetFontString()
    if notebookText then
        notebookText:ClearAllPoints()
        notebookText:SetPoint("LEFT", f.notebookBtn.icon, "RIGHT", 3, 0)
        notebookText:SetPoint("RIGHT", f.notebookBtn, "RIGHT", -4, 0)
        notebookText:SetJustifyH("CENTER")
    end
    local style = Pro.GetStyle and Pro.GetStyle()
    if style and style.SetTooltip then
        style:SetTooltip(
            f.notebookBtn,
            "下载圆圆的笔记本",
            "复制下载地址并安装插件，即可在游戏内生成采购清单，再导入 EasyAuction。",
            "ANCHOR_RIGHT"
        )
    end
    f.listNameEdit = CreateEdit(f.left, "EasyAuctionProShoppingListNameEdit", 10, -36, 132)
    f.createListBtn = Button(f.left, "新建", 150, -36, 70, function()
        local name = Trim(f.listNameEdit:GetText())
        if name == "" then name = "购物清单" end
        local result = Pro.CreateShoppingList and Pro.CreateShoppingList(name)
        if type(result) == "table" and result.ok then
            state.selectedListID = result.list.id
            state.itemPage = 1
            state.purchasePage = 1
            state.revealSelectedList = true
        else
            f.status:SetText("|cffff6060创建清单失败：" .. tostring(result and result.message or "") .. "|r")
        end
        Pro.DrawBuyFrame()
    end)
    f.renameListBtn = Button(f.left, "改名", 10, -64, 64, function()
        if not state.selectedListID then return end
        local name = Trim(f.listNameEdit:GetText())
        if name == "" then return end
        local result = Pro.RenameShoppingList and Pro.RenameShoppingList(state.selectedListID, name)
        if type(result) == "table" and not result.ok then
            f.status:SetText("|cffff6060改名失败：" .. tostring(result.message or "") .. "|r")
        end
        Pro.DrawBuyFrame()
    end)
    f.deleteListBtn = Button(f.left, "删除", 82, -64, 64, function()
        if not state.selectedListID then return end
        local result = Pro.DeleteShoppingList and Pro.DeleteShoppingList(state.selectedListID)
        if type(result) == "table" and result.ok then
            state.selectedListID = nil
            state.itemPage = 1
            state.purchasePage = 1
            state.revealSelectedList = true
        else
            f.status:SetText("|cffff6060删除失败：" .. tostring(result and result.message or "") .. "|r")
        end
        Pro.DrawBuyFrame()
    end)
    f.clearDoneBtn = Button(f.left, "清已完成", 154, -64, 66, function()
        if not state.selectedListID or not Pro.ClearCompletedShoppingList then return end
        local selected = Pro.GetShoppingList(state.selectedListID)
        if type(selected) ~= "table" or not selected.ok then return end
        local completed = {}
        for itemID, entry in pairs(selected.list.items or {}) do
            local progress = ShoppingProgress(itemID, entry.plannedQuantity)
            if type(progress) == "table" and progress.completed then
                completed[itemID] = true
            end
        end
        Pro.ClearCompletedShoppingList(state.selectedListID, completed)
        Pro.DrawBuyFrame()
    end)

    f.importBtn = Button(f, "导入", 14, -484, 112, function()
        ShowShoppingImportPopup(f)
    end)
    f.exportBtn = Button(f, "导出", 138, -484, 112, function()
        if not state.selectedListID then
            return
        end
        local exporter = Pro.ExportShoppingListDisplayText or Pro.ExportShoppingListText
        local result = exporter and exporter(state.selectedListID)
        if type(result) == "table" and result.ok then
            state.exportText = result.text
            ShowShoppingExportPopup(f, result.text)
        elseif f.status then
            f.status:SetText("|cffff6060导出失败。|r")
        end
    end)

    f.listRows = {}
    local function OnListMouseWheel(_, delta)
        state.listPage = (state.listPage or 1) + (delta and delta > 0 and -1 or 1)
        Pro.DrawBuyFrame()
    end
    for i = 1, LIST_ROWS do
        local row = CreateFrame("Button", nil, f.left, "BackdropTemplate")
        row:SetSize(216, LIST_ROW_HEIGHT)
        row:SetPoint("TOPLEFT", f.left, "TOPLEFT", 10, -100 - (i - 1) * LIST_ROW_HEIGHT)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        if Pro.SkinRow then Pro.SkinRow(row, i) end
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", 8, 0)
        row.text:SetWidth(196)
        row.text:SetJustifyH("LEFT")
        KeepSingleLine(row.text)
        row:SetScript("OnClick", function(self)
            state.selectedListID = self.listID
            state.itemPage = 1
            state.purchasePage = 1
            Pro.DrawBuyFrame()
        end)
        SetMouseWheelPaging(row, OnListMouseWheel)
        f.listRows[i] = row
    end

    f.listPrevBtn = Button(f.left, "<", 10, -392, 36, function()
        state.listPage = (state.listPage or 1) - 1
        Pro.DrawBuyFrame()
    end)
    f.listNextBtn = Button(f.left, ">", 54, -392, 36, function()
        state.listPage = (state.listPage or 1) + 1
        Pro.DrawBuyFrame()
    end)
    f.listPageText = f.left:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.listPageText:SetPoint("TOPLEFT", f.left, "TOPLEFT", 102, -396)
    f.listPageText:SetWidth(118)
    f.listPageText:SetJustifyH("LEFT")
    KeepSingleLine(f.listPageText)
    if Pro.SkinText then Pro.SkinText(f.listPageText, "muted", 12) end
    SetMouseWheelPaging(f.left, OnListMouseWheel)

    f.detail = CreateFrame("Frame", nil, f, "BackdropTemplate")
    f.detail:SetPoint("TOPLEFT", 264, -48)
    f.detail:SetSize(662, 428)
    if Pro.SkinHeader then Pro.SkinHeader(f.detail) end
    local function OnItemMouseWheel(_, delta)
        state.itemPage = (state.itemPage or 1) + (delta and delta > 0 and -1 or 1)
        Pro.DrawBuyFrame()
    end
    local function OnPurchaseMouseWheel(_, delta)
        state.purchasePage = (state.purchasePage or 1) + (delta and delta > 0 and -1 or 1)
        Pro.DrawBuyFrame()
    end
    SetMouseWheelPaging(f.detail, OnItemMouseWheel)

    CreateLabel(f.detail, "物品名 / ID", 10, -10, 80)
    f.itemEdit = CreateEdit(f.detail, "EasyAuctionProShoppingItemEdit", 92, -8, 220)
    CreateLabel(f.detail, "计划数量", 326, -10, 62)
    f.qtyEdit = CreateEdit(f.detail, "EasyAuctionProShoppingQtyEdit", 392, -8, 54)
    f.qtyEdit:SetText("1")
    f.addItemBtn = Button(f.detail, "添加/更新", 456, -8, 86, function()
        if not state.selectedListID then return end
        local itemID, itemName = Pro.ResolveItemIdentifier and Pro.ResolveItemIdentifier(f.itemEdit:GetText())
        if not itemID then
            f.status:SetText("|cffff6060请输入准确的物品名、物品链接或 ID。|r")
            return
        end
        local qty = math.floor(tonumber(f.qtyEdit:GetText()) or 0)
        local result = Pro.AddShoppingListItem and Pro.AddShoppingListItem(state.selectedListID, itemID, qty, "replace")
        if type(result) == "table" and result.ok then
            f.itemEdit:SetText(itemName or ("ID:" .. itemID))
            f.status:SetText("|cff60ff60已加入购物清单：" .. (itemName or ("ID:" .. itemID)) .. "。|r")
        else
            f.status:SetText("|cffff6060添加失败：" .. tostring(result and result.message or "") .. "|r")
        end
        Pro.DrawBuyFrame()
    end)
    f.removeItemBtn = Button(f.detail, "移除", 550, -8, 62, function()
        if not state.selectedListID then return end
        local itemID = Pro.ResolveItemIdentifier and Pro.ResolveItemIdentifier(f.itemEdit:GetText())
        if not itemID then return end
        local result = Pro.RemoveShoppingListItem and Pro.RemoveShoppingListItem(state.selectedListID, itemID)
        if type(result) == "table" and result.ok then
            f.status:SetText("|cff60ff60已从购物清单移除。|r")
        else
            f.status:SetText("|cffff6060移除失败：" .. tostring(result and result.message or "") .. "|r")
        end
        Pro.DrawBuyFrame()
    end)

    f.header = CreateFrame("Frame", nil, f.detail, "BackdropTemplate")
    f.header:SetPoint("TOPLEFT", f.detail, "TOPLEFT", 10, -70)
    f.header:SetSize(642, 20)
    if Pro.SkinHeader then Pro.SkinHeader(f.header) end
    SetMouseWheelPaging(f.header, OnItemMouseWheel)
    local headers = ITEM_COLUMNS
    f.header.labels = {}
    local x = 0
    for i, header in ipairs(headers) do
        local label = f.header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", f.header, "LEFT", x, 0)
        label:SetWidth(header[2])
        label:SetText(header[1])
        label:SetJustifyH("LEFT")
        KeepSingleLine(label)
        if Pro.SkinText then Pro.SkinText(label, "muted", 11) end
        f.header.labels[i] = label
        x = x + header[2] + 6
    end

    f.itemRows = {}
    for i = 1, ITEM_ROWS do
        local row = CreateFrame("Button", nil, f.detail, "BackdropTemplate")
        row:SetSize(642, ITEM_ROW_HEIGHT)
        row:SetPoint("TOPLEFT", f.detail, "TOPLEFT", 10, -94 - (i - 1) * ITEM_ROW_HEIGHT)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        if Pro.SkinRow then Pro.SkinRow(row, i) end
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(18, 18)
        row.icon:SetPoint("LEFT", 0, 0)
        row.cols = {}
        for c = 1, #headers do
            row.cols[c] = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.cols[c]:SetJustifyH("LEFT")
            KeepSingleLine(row.cols[c])
            if Pro.SkinText then Pro.SkinText(row.cols[c], "text", 11) end
        end
        row:SetScript("OnClick", function(self)
            local data = self.data
            if not data then return end
            f.itemEdit:SetText(data.itemName or tostring(data.itemID))
            f.qtyEdit:SetText(tostring(data.plannedQuantity or 1))
        end)
        row:SetScript("OnEnter", function(self)
            local data = self.data
            if not data then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if data.itemID and GameTooltip.SetItemByID then
                GameTooltip:SetItemByID(data.itemID)
            else
                GameTooltip:SetText(data.itemName or "")
            end
            GameTooltip:AddLine("点击可载入到上方编辑框。", 1, 1, 1)
            if data.progress then
                local progress = data.progress
                if progress.active then
                    GameTooltip:AddLine(string.format("进度：背包基准 %d + 本次购买 %d / 计划 %d。", progress.baseline, progress.bought, progress.plannedQuantity), 0.8, 0.8, 0.8)
                    GameTooltip:AddLine(string.format("当前实时背包：%d。", progress.liveBags), 0.8, 0.8, 0.8)
                else
                    GameTooltip:AddLine(string.format("进度：实时背包 %d / 计划 %d。", progress.liveBags, progress.plannedQuantity), 0.8, 0.8, 0.8)
                end
                GameTooltip:AddLine(string.format("库存：银行 %d，所有角色总持有 %d。", data.bank or 0, data.total or 0), 0.8, 0.8, 0.8)
                GameTooltip:AddLine(string.format("缺口成本只按需买数量 %d 计算。", progress.neededQuantity), 0.8, 0.8, 0.8)
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
        SetMouseWheelPaging(row, OnItemMouseWheel)
        f.itemRows[i] = row
    end

    f.totalRow = CreateFrame("Frame", nil, f.detail, "BackdropTemplate")
    f.totalRow:SetSize(642, 24)
    f.totalRow:SetPoint("BOTTOMLEFT", f.detail, "BOTTOMLEFT", 10, 80)
    if Pro.SkinRow then Pro.SkinRow(f.totalRow, ITEM_ROWS + 1) end
    SetMouseWheelPaging(f.totalRow, OnItemMouseWheel)
    f.totalCols = {}
    for c = 1, #headers do
        f.totalCols[c] = f.totalRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.totalCols[c]:SetJustifyH("LEFT")
        KeepSingleLine(f.totalCols[c])
        if Pro.SkinText then Pro.SkinText(f.totalCols[c], "text", 11) end
    end
    f.totalRow.cols = f.totalCols

    f.sessionSpendRow = CreateFrame("Frame", nil, f.detail, "BackdropTemplate")
    f.sessionSpendRow:SetSize(642, 66)
    f.sessionSpendRow:SetPoint("BOTTOMLEFT", f.detail, "BOTTOMLEFT", 10, 8)
    if Pro.SkinRow then Pro.SkinRow(f.sessionSpendRow, ITEM_ROWS + 2) end
    SetMouseWheelPaging(f.sessionSpendRow, OnPurchaseMouseWheel)
    f.sessionSpendText = f.sessionSpendRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.sessionSpendText:SetPoint("TOPLEFT", f.sessionSpendRow, "TOPLEFT", 8, -4)
    f.sessionSpendText:SetWidth(620)
    f.sessionSpendText:SetJustifyH("LEFT")
    KeepSingleLine(f.sessionSpendText)
    if Pro.SkinText then Pro.SkinText(f.sessionSpendText, "text", 11) end
    f.sessionPurchaseRows = {}
    for i = 1, PURCHASE_ROWS do
        local row = CreateFrame("Frame", nil, f.sessionSpendRow, "BackdropTemplate")
        row:SetSize(626, PURCHASE_ROW_HEIGHT)
        row:SetPoint("TOPLEFT", f.sessionSpendRow, "TOPLEFT", 8, -18 - (i - 1) * PURCHASE_ROW_HEIGHT)
        SetMouseWheelPaging(row, OnPurchaseMouseWheel)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(16, 16)
        row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.name:SetPoint("LEFT", row, "LEFT", 20, 0)
        row.name:SetWidth(310)
        row.name:SetJustifyH("LEFT")
        KeepSingleLine(row.name)
        row.quantity = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.quantity:SetPoint("LEFT", row, "LEFT", 340, 0)
        row.quantity:SetWidth(74)
        row.quantity:SetJustifyH("LEFT")
        KeepSingleLine(row.quantity)
        row.cost = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.cost:SetPoint("LEFT", row, "LEFT", 424, 0)
        row.cost:SetWidth(190)
        row.cost:SetJustifyH("LEFT")
        KeepSingleLine(row.cost)
        if Pro.SkinText then
            Pro.SkinText(row.name, "text", 11)
            Pro.SkinText(row.quantity, "accent", 11)
            Pro.SkinText(row.cost, "text", 11)
        end
        f.sessionPurchaseRows[i] = row
    end

    f.prevBtn = Button(f, "<", 502, -488, 36, function()
        state.itemPage = math.max(1, (state.itemPage or 1) - 1)
        Pro.DrawBuyFrame()
    end)
    f.nextBtn = Button(f, ">", 546, -488, 36, function()
        state.itemPage = (state.itemPage or 1) + 1
        Pro.DrawBuyFrame()
    end)
    f.pageText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.pageText:SetPoint("TOPLEFT", f, "TOPLEFT", 594, -492)
    f.pageText:SetWidth(120)
    f.pageText:SetJustifyH("LEFT")
    if Pro.SkinText then Pro.SkinText(f.pageText, "muted", 12) end

    f.status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.status:SetPoint("BOTTOMLEFT", 14, 16)
    f.status:SetWidth(900)
    f.status:SetJustifyH("LEFT")
    KeepSingleLine(f.status)
    if Pro.SkinText then Pro.SkinText(f.status, "muted", 12) end

    Pro.buyFrame = f
    return f
end

local function LayoutColumns(row)
    local widths = {}
    for i, column in ipairs(ITEM_COLUMNS) do
        widths[i] = column[2]
    end
    local x = 0
    for i, width in ipairs(widths) do
        row.cols[i]:ClearAllPoints()
        row.cols[i]:SetPoint("LEFT", row, "LEFT", x, 0)
        row.cols[i]:SetWidth(width)
        row.cols[i]:Show()
        x = x + width + 6
    end
    row.cols[1]:ClearAllPoints()
    row.cols[1]:SetPoint("LEFT", row, "LEFT", 22, 0)
    row.cols[1]:SetWidth(widths[1] - 22)
end

local function LayoutItemRow(row)
    LayoutColumns(row)
end

local function LayoutTotalRow(row)
    if not row or not row.cols then return end
    local x = 0
    for i, column in ipairs(ITEM_COLUMNS) do
        row.cols[i]:ClearAllPoints()
        row.cols[i]:SetPoint("LEFT", row, "LEFT", x, 0)
        row.cols[i]:SetWidth(column[2])
        row.cols[i]:Show()
        x = x + column[2] + 6
    end
end

function Pro.DrawBuyFrame()
    local f = CreateFrameOnce()
    if Pro.ApplyFrameScale then Pro.ApplyFrameScale(f) end

    local listsResult = GetLists()
    if type(listsResult) ~= "table" or not listsResult.ok then
        f.status:SetText("|cffff6060购物清单不可用：" .. tostring(listsResult and listsResult.message or "") .. "|r")
        return
    end
    SelectFirstList(listsResult.lists)

    local listTotalPages = math.max(1, math.ceil(#(listsResult.lists or {}) / LIST_ROWS))
    if state.revealSelectedList then
        local selectedIndex = FindListIndex(listsResult.lists, state.selectedListID)
        if selectedIndex then
            state.listPage = math.ceil(selectedIndex / LIST_ROWS)
        end
        state.revealSelectedList = false
    end
    state.listPage = ClampPage(state.listPage, listTotalPages)
    local listStartIndex = (state.listPage - 1) * LIST_ROWS + 1
    for i, row in ipairs(f.listRows) do
        local list = listsResult.lists[listStartIndex + i - 1]
        if list then
            row.listID = list.id
            row.text:SetText((list.id == state.selectedListID and "|cff60ff60● |r" or "  ") .. list.name)
            row:Show()
        else
            row.listID = nil
            row:Hide()
        end
    end
    f.listPageText:SetText(string.format("%d / %d", state.listPage, listTotalPages))
    if state.listPage > 1 then f.listPrevBtn:Enable() else f.listPrevBtn:Disable() end
    if state.listPage < listTotalPages then f.listNextBtn:Enable() else f.listNextBtn:Disable() end

    local selected = state.selectedListID and Pro.GetShoppingList and Pro.GetShoppingList(state.selectedListID) or nil
    local list = selected and selected.ok and selected.list or nil
    if list and not f.listNameEdit:HasFocus() then
        f.listNameEdit:SetText(list.name)
    end

    local items = SortedItems(list)
    local progressByItemID = {}
    local totals = {
        planned = 0,
        liveBags = 0,
        bought = 0,
        needed = 0,
        boughtCost = 0,
    }
    for _, item in ipairs(items) do
        local itemID = tonumber(item.itemID)
        if itemID then
            local progress = ShoppingProgress(itemID, item.plannedQuantity)
            item.progress = progress
            totals.planned = totals.planned + (progress.plannedQuantity or 0)
            totals.liveBags = totals.liveBags + (progress.liveBags or 0)
            totals.bought = totals.bought + (progress.bought or 0)
            totals.needed = totals.needed + (progress.neededQuantity or 0)
            totals.boughtCost = totals.boughtCost + SessionBuyStatsCost(itemID)
            progressByItemID[itemID] = {
                ownedQuantity = progress.ownedQuantity,
                neededQuantity = progress.neededQuantity,
            }
        end
    end
    local summary = list and Pro.GetShoppingListCostSummary and Pro.GetShoppingListCostSummary(list.id, {
        quantitiesByItemID = progressByItemID,
    }) or nil
    local estimates = EstimateByItem(summary)
    local purchaseRows = CurrentPurchaseRows(items)
    local purchasePages = math.max(1, math.ceil(#purchaseRows / PURCHASE_ROWS))
    state.purchasePage = ClampPage(state.purchasePage, purchasePages)
    local purchaseStartIndex = (state.purchasePage - 1) * PURCHASE_ROWS + 1
    local totalPages = math.max(1, math.ceil(#items / ITEM_ROWS))
    state.itemPage = ClampPage(state.itemPage, totalPages)
    local startIndex = (state.itemPage - 1) * ITEM_ROWS + 1

    for i, row in ipairs(f.itemRows) do
        local item = items[startIndex + i - 1]
        row.data = item
        if item then
            local itemID = tonumber(item.itemID)
            local planned = tonumber(item.plannedQuantity) or 0
            local progress = item.progress or ShoppingProgress(itemID, planned)
            local bank = BankCount(itemID)
            local total = TotalCount(itemID)
            item.bank = bank
            item.total = total
            local estimate = estimates[itemID] or {}
            local status = "|cffffd200待购|r"
            if progress.completed then
                status = "|cff60ff60完成|r"
            elseif estimate.state == "unavailable" or not estimate.unitPrice then
                status = "|cffff6060缺价格|r"
            end
            LayoutItemRow(row)
            row.icon:SetTexture(ItemIcon(itemID))
            row.icon:Show()
            row.cols[1]:SetText(item.itemName or ("ID:" .. itemID))
            row.cols[2]:SetText(progress.progressLabel)
            row.cols[3]:SetText(tostring(progress.neededQuantity))
            row.cols[4]:SetText(tostring(progress.liveBags or 0))
            row.cols[5]:SetText(PriceLabel(estimate))
            row.cols[6]:SetText(progress.neededQuantity <= 0 and CostMoney(0)
                or (estimate.subtotal and estimate.subtotal > 0 and CostMoney(estimate.subtotal) or "-"))
            row.cols[7]:SetText(status)
            row:Show()
        else
            row.icon:Hide()
            row:Hide()
        end
    end

    if list then
        f.totalRow:Show()
        LayoutTotalRow(f.totalRow)
        f.totalCols[1]:SetText(string.format("合计:%d项", #items))
        f.totalCols[2]:SetText("")
        f.totalCols[3]:SetText(tostring(totals.needed))
        f.totalCols[4]:SetText(tostring(totals.liveBags))
        f.totalCols[5]:SetText("")
        f.totalCols[6]:SetText(CostMoney(summary and (summary.estimatedSubtotal or summary.knownSubtotal) or 0))
        f.totalCols[7]:SetText("")
        f.sessionSpendRow:Show()
        f.sessionSpendText:SetText(string.format("本次购买：%d项 / %d件 / %s  %d/%d",
            #purchaseRows, totals.bought, Money(totals.boughtCost), state.purchasePage, purchasePages))
        for i, row in ipairs(f.sessionPurchaseRows or {}) do
            local purchase = purchaseRows[purchaseStartIndex + i - 1]
            if purchase then
                row.icon:SetTexture(ItemIcon(purchase.itemID))
                row.name:SetText(purchase.itemName or ("ID:" .. purchase.itemID))
                row.quantity:SetText(string.format("数量 %d", purchase.quantity or 0))
                row.cost:SetText(string.format("合计 %s", Money(purchase.cost or 0)))
                row:Show()
            else
                row.icon:SetTexture(nil)
                row.name:SetText("")
                row.quantity:SetText("")
                row.cost:SetText("")
                row:Hide()
            end
        end
    else
        for _, col in ipairs(f.totalCols or {}) do col:SetText("") end
        f.totalRow:Hide()
        f.sessionSpendRow:Hide()
    end

    f.pageText:SetText(string.format("%d / %d", state.itemPage, totalPages))
    if state.itemPage > 1 then f.prevBtn:Enable() else f.prevBtn:Disable() end
    if state.itemPage < totalPages then f.nextBtn:Enable() else f.nextBtn:Disable() end

    if not list then
        f.status:SetText("")
    end
end

function Pro.ShowBuyFrame()
    local f = CreateFrameOnce()
    state.itemPage = 1
    state.purchasePage = 1
    Pro.DrawBuyFrame()
    RaiseFrame(f)
    f:Show()
end

function Pro.ShowShoppingList()
    Pro.ShowBuyFrame()
end

function Pro.ShowRestock()
    Pro.ShowBuyFrame()
end

function Pro.ShowStrategySnipe()
    Pro.ShowBuyFrame()
end

function _G.EasyAuctionPro_ShowBuyFrame()
    Pro.ShowBuyFrame()
end

function _G.EasyAuctionPro_ShowShoppingList()
    Pro.ShowBuyFrame()
end

function _G.EasyAuctionPro_ShowRestock()
    Pro.ShowBuyFrame()
end

function _G.EasyAuctionPro_ShowStrategySnipe()
    Pro.ShowBuyFrame()
end
