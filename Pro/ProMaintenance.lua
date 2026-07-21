local _, ns = ...

local Pro = ns.EasyAuctionPro
if not Pro then return end

local ROW_HEIGHT = 30
local MAX_ROWS = 12
local pendingCancelRow
local pendingCancelRows

local function Money(copper)
    return Pro.FormatMoney(copper or 0)
end

local function ShortTime(ts)
    ts = tonumber(ts)
    if not ts or ts <= 0 then
        return "-"
    end
    return date("%m-%d %H:%M", ts)
end

local function TimeLeftText(timeLeft)
    if timeLeft == 1 then
        return "|cffff8800<30分钟|r"
    elseif timeLeft == 2 then
        return "|cff00ff002小时|r"
    elseif timeLeft == 3 then
        return "|cff00bfff12小时|r"
    elseif timeLeft == 4 then
        return "|cffffff0048小时|r"
    end
    return "-"
end

local function GetRows()
    local rows = {}
    local num = GetNumAuctionItems and GetNumAuctionItems("owner") or 0
    local currentKeys = {}

    for idx = 1, num do
        local name, texture, count, quality, _, _, _, _, _, buyout, _, buyer, _, _, _, saleStatus, itemID =
            GetAuctionItemInfo("owner", idx)
        local timeLeft = GetAuctionItemTimeLeft and GetAuctionItemTimeLeft("owner", idx) or nil
        if name and itemID then
            count = tonumber(count) or 0
            buyout = tonumber(buyout) or 0
            local unit = (count > 0 and buyout > 0) and math.floor(buyout / count + 0.5) or buyout
            local operation = Pro.GetAuctionOperation and Pro.GetAuctionOperation(itemID) or nil
            local suggestion = Pro.CalcPostSuggestion and
                Pro.CalcPostSuggestion(itemID, name, math.max(1, count)) or nil
            local context = Pro.GetPriceContext and Pro.GetPriceContext(itemID, name) or {}
            local market = context.currentMin or context.median7d or context.historyMin
            local status = "|cff60ff60保留|r"
            local statusKey = "keep"
            local reason = "当前拍卖符合策略"

            if saleStatus == 1 then
                status = "|cff00ff00已售出|r"
                statusKey = "sold"
                reason = buyer and buyer ~= "" and ("买家：" .. buyer) or "等待收款"
            elseif suggestion and suggestion.minPrice and unit > 0 and unit < suggestion.minPrice then
                status = "|cffff6060低于底价|r"
                statusKey = "belowFloor"
                reason = "我的单价低于策略最低价"
            elseif market and unit > 0 and market > 0 and market < unit then
                status = "|cffffff00被压价|r"
                statusKey = "undercut"
                reason = "市场参考价低于我的单价"
            elseif timeLeft == 1 and operation and tonumber(operation.maxExpires or 0) > 0 then
                status = "|cffffff00建议重挂|r"
                statusKey = "repost"
                reason = "即将结束，检查是否需要调整策略"
            end

            local key = table.concat({ tostring(itemID), tostring(count), tostring(buyout), tostring(idx) }, ":")
            currentKeys[key] = true
            rows[#rows + 1] = {
                index = idx,
                itemID = itemID,
                itemName = name,
                icon = texture or (GetItemIcon and GetItemIcon(itemID)) or nil,
                quality = quality,
                count = count,
                unitPrice = unit,
                minPrice = suggestion and suggestion.minPrice or nil,
                marketPrice = market,
                status = status,
                statusKey = statusKey,
                reason = reason,
                timeLeft = timeLeft,
                saleStatus = saleStatus,
                key = key,
                link = GetAuctionItemLink and GetAuctionItemLink("owner", idx) or nil,
            }
        end
    end

    table.sort(rows, function(a, b)
        if (a.saleStatus == 1) ~= (b.saleStatus == 1) then
            return a.saleStatus == 1
        end
        if (a.timeLeft or 99) ~= (b.timeLeft or 99) then
            return (a.timeLeft or 99) < (b.timeLeft or 99)
        end
        return (a.itemName or "") < (b.itemName or "")
    end)

    local pro = Pro.InitDB()
    if pro then
        pro.ledger.ownerSnapshot = pro.ledger.ownerSnapshot or {}
        for key, snap in pairs(pro.ledger.ownerSnapshot) do
            if not currentKeys[key] and snap and snap.timeLeft == 1 and snap.itemID then
                Pro.RecordLedgerEvent("expired", snap.itemID, {
                    itemName = snap.itemName,
                    count = snap.count or 1,
                    seenKey = "owner-expired:" .. key,
                })
                pro.ledger.ownerSnapshot[key] = nil
            end
        end
        for _, row in ipairs(rows) do
            if row.saleStatus ~= 1 then
                pro.ledger.ownerSnapshot[row.key] = {
                    itemID = row.itemID,
                    itemName = row.itemName,
                    count = math.max(1, row.count or 1),
                    timeLeft = row.timeLeft,
                    seenAt = time(),
                }
            end
        end
    end

    return rows
end

local function CancelOwnerAuction(row)
    if row and row.index and row.saleStatus ~= 1 then
        CancelAuction(row.index)
        return true
    end
    return false
end

local function IsCancelCandidate(row)
    return row and row.index and row.saleStatus ~= 1 and
        (row.statusKey == "belowFloor" or row.statusKey == "undercut" or row.statusKey == "repost")
end

local function ConfirmCancelRow(row)
    if not row or not row.index or row.saleStatus == 1 then
        return
    end
    StaticPopupDialogs.EASYAUCTIONPRO_CANCEL_ONE = StaticPopupDialogs.EASYAUCTIONPRO_CANCEL_ONE or {
        text = "确认取消该拍卖？\n%s",
        button1 = "取消拍卖",
        button2 = "保留",
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        OnAccept = function()
            if CancelOwnerAuction(pendingCancelRow) and Pro.DrawMaintenance then
                Pro.DrawMaintenance()
            end
            pendingCancelRow = nil
        end,
        OnCancel = function()
            pendingCancelRow = nil
        end,
    }
    pendingCancelRow = row
    StaticPopup_Show("EASYAUCTIONPRO_CANCEL_ONE", row.itemName or "")
end

local function ConfirmCancelRows(rows)
    pendingCancelRows = {}
    for _, row in ipairs(rows or {}) do
        if IsCancelCandidate(row) then
            pendingCancelRows[#pendingCancelRows + 1] = row
        end
    end
    if #pendingCancelRows == 0 then
        print("|cffffd200[EasyAuctionPro]|r 当前页没有需要取消的异常拍卖。")
        pendingCancelRows = nil
        return
    end
    StaticPopupDialogs.EASYAUCTIONPRO_CANCEL_PAGE = StaticPopupDialogs.EASYAUCTIONPRO_CANCEL_PAGE or {
        text = "确认取消当前页 %d 条异常拍卖？\n仅取消低于底价、被压价或建议重挂的未售出项目。",
        button1 = "一键取消",
        button2 = "保留",
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        OnAccept = function()
            local cancelled = 0
            for _, row in ipairs(pendingCancelRows or {}) do
                if CancelOwnerAuction(row) then
                    cancelled = cancelled + 1
                end
            end
            pendingCancelRows = nil
            print("|cff00ff00[EasyAuctionPro]|r 已提交取消 " .. cancelled .. " 条拍卖。")
            if Pro.DrawMaintenance then
                Pro.DrawMaintenance()
            end
        end,
        OnCancel = function()
            pendingCancelRows = nil
        end,
    }
    StaticPopup_Show("EASYAUCTIONPRO_CANCEL_PAGE", #pendingCancelRows)
end

local function GetLedgerRows()
    local pro = Pro.InitDB()
    local rows = {}
    for itemID, stat in pairs(pro and pro.ledger and pro.ledger.itemStats or {}) do
        rows[#rows + 1] = {
            itemID = tonumber(itemID),
            itemName = stat.itemName or ("ID:" .. tostring(itemID)),
            postedCount = stat.postedCount or 0,
            soldCount = stat.soldCount or 0,
            expiredCount = stat.expiredCount or 0,
            boughtCount = stat.boughtCount or 0,
            soldRevenue = stat.soldRevenue or 0,
            boughtCost = stat.boughtCost or 0,
            lastSoldTime = stat.lastSoldTime,
            lastExpiredTime = stat.lastExpiredTime,
        }
    end
    table.sort(rows, function(a, b)
        local aTime = math.max(a.lastSoldTime or 0, a.lastExpiredTime or 0)
        local bTime = math.max(b.lastSoldTime or 0, b.lastExpiredTime or 0)
        return aTime > bTime
    end)
    return rows
end

local function RaiseFrame(frame)
    if Pro.RaiseMainFrame then
        Pro.RaiseMainFrame(frame)
    end
end

local function CreateFrameOnce()
    if Pro.maintenanceFrame then
        return Pro.maintenanceFrame
    end

    local f = CreateFrame("Frame", "EasyAuctionProMaintenanceFrame", UIParent, "BackdropTemplate")
    f:SetSize(940, 500)
    f:SetPoint("CENTER")
    RaiseFrame(f)
    Pro.ApplyFrameScale(f)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    if Pro.SkinFrame then Pro.SkinFrame(f, "window") end
    tinsert(UISpecialFrames, "EasyAuctionProMaintenanceFrame")

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", 14, -12)
    f.title:SetText("|cffffd200EasyAuction Pro|r 运营维护")
    if Pro.SkinText then Pro.SkinText(f.title, "accent", 14) end

    local closeBtn = Pro.CreateCloseButton and Pro.CreateCloseButton(f) or CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -8, -8)

    f.tabOwner = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.tabOwner:SetSize(86, 22)
    f.tabOwner:SetPoint("TOPLEFT", 14, -42)
    f.tabOwner:SetText("我的拍卖")
    f.tabOwner:SetScript("OnClick", function()
        f.mode = "owner"
        Pro.DrawMaintenance()
    end)
    if Pro.SkinButton then Pro.SkinButton(f.tabOwner) end

    f.tabLedger = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.tabLedger:SetSize(86, 22)
    f.tabLedger:SetPoint("LEFT", f.tabOwner, "RIGHT", 8, 0)
    f.tabLedger:SetText("复盘账本")
    f.tabLedger:SetScript("OnClick", function()
        f.mode = "ledger"
        Pro.DrawMaintenance()
    end)
    if Pro.SkinButton then Pro.SkinButton(f.tabLedger) end

    f.refreshBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.refreshBtn:SetSize(72, 22)
    f.refreshBtn:SetPoint("TOPRIGHT", closeBtn, "BOTTOMRIGHT", -10, -6)
    f.refreshBtn:SetText("刷新")
    f.refreshBtn:SetScript("OnClick", function()
        Pro.DrawMaintenance()
    end)
    if Pro.SkinButton then Pro.SkinButton(f.refreshBtn) end

    f.cancelBadBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.cancelBadBtn:SetSize(96, 22)
    f.cancelBadBtn:SetPoint("RIGHT", f.refreshBtn, "LEFT", -8, 0)
    f.cancelBadBtn:SetText("取消异常")
    f.cancelBadBtn:SetScript("OnClick", function()
        ConfirmCancelRows(f.currentRows or {})
    end)
    if Pro.SkinButton then Pro.SkinButton(f.cancelBadBtn) end

    f.status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.status:SetPoint("TOPLEFT", f.tabOwner, "BOTTOMLEFT", 0, -8)
    f.status:SetWidth(650)
    f.status:SetJustifyH("LEFT")
    if Pro.SkinText then Pro.SkinText(f.status, "muted", 12) end

    local header = CreateFrame("Frame", nil, f, "BackdropTemplate")
    header:SetPoint("TOPLEFT", 14, -90)
    header:SetSize(910, 20)
    if Pro.SkinHeader then Pro.SkinHeader(header) end
    f.header = header

    f.rows = {}
    for i = 1, MAX_ROWS do
        local row = CreateFrame("Button", nil, f, "BackdropTemplate")
        row:SetSize(910, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 14, -114 - (i - 1) * ROW_HEIGHT)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        if Pro.SkinRow then Pro.SkinRow(row, i) end
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(18, 18)
        row.icon:SetPoint("LEFT", 0, 0)
        row.cols = {}
        for c = 1, 9 do
            row.cols[c] = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.cols[c]:SetJustifyH("LEFT")
            if Pro.SkinText then Pro.SkinText(row.cols[c], "text", 12) end
        end
        row.cancelBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        row.cancelBtn:SetSize(54, 20)
        row.cancelBtn:SetText("取消")
        row.cancelBtn:SetScript("OnClick", function(self)
            ConfirmCancelRow(self:GetParent().data)
        end)
        if Pro.SkinButton then Pro.SkinButton(row.cancelBtn) end
        row:SetScript("OnEnter", function(self)
            local data = self.data
            if not data then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:ClearLines()
            if data.link then
                GameTooltip:SetHyperlink(data.link)
            elseif data.itemID then
                GameTooltip:SetItemByID(data.itemID)
            else
                GameTooltip:SetText(data.itemName or "")
            end
            GameTooltip:AddLine(data.reason or "", 1, 1, 1)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        f.rows[i] = row
    end

    f.prevBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.prevBtn:SetSize(60, 22)
    f.prevBtn:SetPoint("BOTTOMLEFT", 14, 14)
    f.prevBtn:SetText("上一页")
    f.prevBtn:SetScript("OnClick", function()
        f.page = math.max(1, (f.page or 1) - 1)
        Pro.DrawMaintenance()
    end)
    if Pro.SkinButton then Pro.SkinButton(f.prevBtn) end

    f.nextBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.nextBtn:SetSize(60, 22)
    f.nextBtn:SetPoint("LEFT", f.prevBtn, "RIGHT", 8, 0)
    f.nextBtn:SetText("下一页")
    f.nextBtn:SetScript("OnClick", function()
        f.page = (f.page or 1) + 1
        Pro.DrawMaintenance()
    end)
    if Pro.SkinButton then Pro.SkinButton(f.nextBtn) end

    f.pageText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.pageText:SetPoint("LEFT", f.nextBtn, "RIGHT", 12, 0)
    if Pro.SkinText then Pro.SkinText(f.pageText, "muted", 12) end

    Pro.maintenanceFrame = f
    return f
end

local function DrawHeader(f, columns)
    local header = f.header
    header:Hide()
    if header.labels then
        for _, label in ipairs(header.labels) do
            label:Hide()
        end
    end
    header.labels = header.labels or {}
    local x = 0
    for i, col in ipairs(columns) do
        local label = header.labels[i] or header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        header.labels[i] = label
        label:ClearAllPoints()
        label:SetPoint("LEFT", header, "LEFT", x, 0)
        label:SetWidth(col[2])
        label:SetJustifyH("LEFT")
        label:SetText(col[1])
        if Pro.SkinText then Pro.SkinText(label, "muted", 11) end
        label:Show()
        x = x + col[2] + 6
    end
    header:Show()
end

local function LayoutRow(row, columns)
    local x = 0
    for i, col in ipairs(columns) do
        local fs = row.cols[i]
        fs:ClearAllPoints()
        fs:SetPoint("LEFT", row, "LEFT", x, 0)
        fs:SetWidth(col[2])
        fs:Show()
        x = x + col[2] + 6
    end
    for i = #columns + 1, #row.cols do
        row.cols[i]:Hide()
    end
end

function Pro.DrawMaintenance()
    local f = CreateFrameOnce()
    Pro.ApplyFrameScale(f)
    RaiseFrame(f)
    f.mode = f.mode or "owner"
    local rows = f.mode == "ledger" and GetLedgerRows() or GetRows()
    f.currentRows = rows
    local totalPages = math.max(1, math.ceil(#rows / MAX_ROWS))
    f.page = math.min(math.max(f.page or 1, 1), totalPages)
    local startIndex = (f.page - 1) * MAX_ROWS + 1

    f.tabOwner:SetText("我的拍卖")
    f.tabLedger:SetText("复盘账本")
    if Pro.SetButtonActive then
        Pro.SetButtonActive(f.tabOwner, f.mode == "owner")
        Pro.SetButtonActive(f.tabLedger, f.mode == "ledger")
    end
    if f.mode == "owner" then
        f.cancelBadBtn:Show()
    else
        f.cancelBadBtn:Hide()
    end
    f.status:SetText(f.mode == "ledger" and
        "聚合成交、购买、流拍统计；只保存汇总字段。" or
        "读取拍卖行“我的拍卖”，按当前 Pro 策略提示保留、被压价、低于底价。")

    local columns
    if f.mode == "ledger" then
        columns = {
            { "物品", 180 }, { "上架", 44 }, { "成交", 44 }, { "流拍", 44 },
            { "买入", 44 }, { "成交额", 100 }, { "买入额", 100 }, { "最近", 120 },
        }
    else
        columns = {
            { "物品", 170 }, { "数量", 42 }, { "我的单价", 84 }, { "底价", 84 },
            { "市场参考", 84 }, { "时长", 64 }, { "状态", 80 }, { "原因", 190 }, { "操作", 54 },
        }
    end
    DrawHeader(f, columns)

    for i, row in ipairs(f.rows) do
        local data = rows[startIndex + i - 1]
        row.data = data
        if data then
            LayoutRow(row, columns)
            row.cancelBtn:Hide()
            if f.mode == "ledger" then
                row.icon:Hide()
                row.cols[1]:ClearAllPoints()
                row.cols[1]:SetPoint("LEFT", row, "LEFT", 0, 0)
                row.cols[1]:SetWidth(columns[1][2])
                row.cols[1]:SetText(data.itemName or "")
                row.cols[2]:SetText(tostring(data.postedCount or 0))
                row.cols[3]:SetText(tostring(data.soldCount or 0))
                row.cols[4]:SetText(tostring(data.expiredCount or 0))
                row.cols[5]:SetText(tostring(data.boughtCount or 0))
                row.cols[6]:SetText(Money(data.soldRevenue))
                row.cols[7]:SetText(Money(data.boughtCost))
                row.cols[8]:SetText(ShortTime(data.lastSoldTime or data.lastExpiredTime))
            else
                row.icon:SetTexture(data.icon)
                row.icon:Show()
                row.cols[1]:ClearAllPoints()
                row.cols[1]:SetPoint("LEFT", row, "LEFT", 22, 0)
                row.cols[1]:SetWidth(148)
                row.cols[1]:SetText(data.itemName or "")
                row.cols[2]:SetText(tostring(data.count or 0))
                row.cols[3]:SetText(Money(data.unitPrice))
                row.cols[4]:SetText(data.minPrice and Money(data.minPrice) or "-")
                row.cols[5]:SetText(data.marketPrice and Money(data.marketPrice) or "-")
                row.cols[6]:SetText(TimeLeftText(data.timeLeft))
                row.cols[7]:SetText(data.status or "")
                row.cols[8]:SetText(data.reason or "")
                row.cols[9]:SetText("")
                row.cancelBtn:ClearAllPoints()
                row.cancelBtn:SetPoint("LEFT", row.cols[9], "LEFT", 0, 0)
                if data.saleStatus ~= 1 then
                    row.cancelBtn:Show()
                end
            end
            row:Show()
        else
            row.cancelBtn:Hide()
            row:Hide()
        end
    end

    f.pageText:SetText(string.format("%d / %d", f.page, totalPages))
    if f.page > 1 then f.prevBtn:Enable() else f.prevBtn:Disable() end
    if f.page < totalPages then f.nextBtn:Enable() else f.nextBtn:Disable() end
end

function Pro.ShowMaintenance(mode)
    local f = CreateFrameOnce()
    f.mode = mode or f.mode or "owner"
    f.page = 1
    Pro.DrawMaintenance()
    RaiseFrame(f)
    f:Show()
end

function _G.EasyAuctionPro_ShowMaintenance()
    Pro.ShowMaintenance("owner")
end

function _G.EasyAuctionPro_ShowLedger()
    Pro.ShowMaintenance("ledger")
end
