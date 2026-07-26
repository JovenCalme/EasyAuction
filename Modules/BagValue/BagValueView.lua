local _, ns = ...

ns = type(ns) == "table" and ns or {}
ns.BagValue = type(ns.BagValue) == "table" and ns.BagValue or {}

local BagValue = ns.BagValue
local View = {}
View.__index = View

local FRAME_WIDTH, FRAME_HEIGHT = 680, 500
local ROW_COUNT, ROW_HEIGHT = 10, 27
local COLUMN_DEFS = {
    { key = "name", label = "物品", x = 6, width = 246, justify = "LEFT" },
    { key = "count", label = "数量", x = 252, width = 54, justify = "RIGHT" },
    { key = "unitValue", label = "单价", x = 306, width = 112, justify = "RIGHT" },
    { key = "totalValue", label = "小计", x = 418, width = 122, justify = "RIGHT" },
    { key = "source", label = "来源", x = 540, width = 94, justify = "LEFT" },
}

local function createFrame(create, frameType, name, parent, template)
    if template then
        local ok, frame = pcall(create, frameType, name, parent, template)
        if ok and frame then return frame end
    end
    return create(frameType, name, parent)
end

local function formatMoney(value)
    value = math.max(0, math.floor(tonumber(value) or 0))
    if _G and type(_G.GetCoinTextureString) == "function" then
        local ok, text = pcall(_G.GetCoinTextureString, value, 12)
        if ok and type(text) == "string" then return text end
    end
    return tostring(value) .. " 铜"
end

local function rowValue(row, key)
    if key == "name" then return row.name or row.itemName or row.itemLink or "" end
    if key == "count" then return tonumber(row.count or row.quantity or row.stackCount) or 0 end
    if key == "unitValue" then
        if (tonumber(row.auctionValue) or 0) > 0 then return tonumber(row.auctionUnit) or 0 end
        if (tonumber(row.vendorValue) or 0) > 0 then return tonumber(row.vendorUnit) or 0 end
        return tonumber(row.unitValue or row.unitPrice or row.price) or 0
    end
    if key == "totalValue" then return tonumber(row.totalValue or row.value or row.subtotal) or 0 end
    if key == "source" then
        if row.sourceLabel then return row.sourceLabel end
        local hasAuction = (tonumber(row.auctionValue) or 0) > 0
        local hasVendor = (tonumber(row.vendorValue) or 0) > 0
        if hasAuction and hasVendor then
            return row.freshness == "stale" and "过期价+卖店" or "扫描价+卖店"
        end
        if hasAuction then
            if row.freshness == "stale" then return "过期扫描价" end
            return "扫描价"
        end
        if hasVendor then return "卖店" end
        return row.source or row.priceSource or "无价格"
    end
    return row[key]
end

local function lower(value)
    return string.lower(tostring(value or ""))
end

local function qualityColor(quality)
    local color = _G and _G.ITEM_QUALITY_COLORS and _G.ITEM_QUALITY_COLORS[tonumber(quality)]
    if color then return color.r or 1, color.g or 1, color.b or 1 end
    return 1, 1, 1
end

local function styleText(text, role)
    local style = _G and _G.EasyAuctionStyle
    if style and type(style.SkinText) == "function" then style:SkinText(text, role) end
end

local function styleButton(button)
    local style = _G and _G.EasyAuctionStyle
    if style and type(style.SkinButton) == "function" then style:SkinButton(button) end
end

local function styleFrame(frame, role)
    local style = _G and _G.EasyAuctionStyle
    if style and type(style.SkinExistingFrame) == "function" then
        style:SkinExistingFrame(frame, role)
    elseif frame and frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        frame:SetBackdropColor(0.08, 0.08, 0.10, 0.98)
        frame:SetBackdropBorderColor(0.35, 0.35, 0.4, 1)
    end
end

local function copyRows(rows)
    local result = {}
    for index = 1, #(rows or {}) do result[index] = rows[index] end
    return result
end

function View.New(deps)
    deps = deps or {}
    return setmetatable({
        deps = deps,
        rows = {},
        visibleRows = {},
        rowFrames = {},
        summary = {},
        query = "",
        sortKey = "totalValue",
        sortAscending = false,
        rowOffset = 0,
    }, View)
end

local function createSummaryMetric(parent, x, label)
    local metric = {}
    metric.label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    metric.label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -7)
    metric.label:SetSize(112, 16)
    metric.label:SetJustifyH("LEFT")
    metric.label:SetText(label)
    styleText(metric.label, "muted")
    metric.value = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    metric.value:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -26)
    metric.value:SetSize(112, 20)
    metric.value:SetJustifyH("RIGHT")
    return metric
end

function View:_createRow(parent, index)
    local create = self.deps.createFrame or (_G and _G.CreateFrame)
    local row = createFrame(create, "Button", nil, parent)
    row:SetSize(634, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
    row:RegisterForClicks("LeftButtonUp")
    row.background = row:CreateTexture(nil, "BACKGROUND")
    row.background:SetAllPoints()
    row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
    row.highlight:SetAllPoints()
    row.highlight:SetColorTexture(1, 0.82, 0, 0.12)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("LEFT", row, "LEFT", 6, 0)
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
    row.name:SetSize(216, ROW_HEIGHT)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    for _, def in ipairs(COLUMN_DEFS) do
        if def.key ~= "name" then
            local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            text:SetPoint("LEFT", row, "LEFT", def.x, 0)
            text:SetSize(def.width - 7, ROW_HEIGHT)
            text:SetJustifyH(def.justify)
            text:SetWordWrap(false)
            row[def.key] = text
        end
    end
    row:SetScript("OnEnter", function(button)
        local data = button.data
        local link = data and (data.itemLink or data.link)
        if link and _G and _G.GameTooltip then
            _G.GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            _G.GameTooltip:SetHyperlink(link)
            _G.GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function()
        if _G and _G.GameTooltip then _G.GameTooltip:Hide() end
    end)
    row:Hide()
    return row
end

function View:Create(parent)
    if self.frame then return self.frame end
    local create = self.deps.createFrame or (_G and _G.CreateFrame)
    if type(create) ~= "function" then return nil end
    parent = parent or (_G and _G.UIParent)
    if not parent then return nil end

    local frame = createFrame(create, "Frame", "EasyAuctionBagValueFrame", parent, "BackdropTemplate")
    self.frame = frame
    if _G.UISpecialFrames then
        local registered = false
        for index = 1, #_G.UISpecialFrames do
            if _G.UISpecialFrames[index] == "EasyAuctionBagValueFrame" then registered = true break end
        end
        if not registered then _G.UISpecialFrames[#_G.UISpecialFrames + 1] = "EasyAuctionBagValueFrame" end
    end
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    local scaleFrame = _G and _G.EasyAuctionDBFrame
    if frame.SetScale and scaleFrame and type(scaleFrame.GetScale) == "function" then
        frame:SetScale(scaleFrame:GetScale())
    end
    frame:SetPoint("CENTER", parent, "CENTER", 0, 15)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(target) target:StartMoving() end)
    frame:SetScript("OnDragStop", function(target) target:StopMovingOrSizing() end)
    frame:SetScript("OnHide", function()
        if type(self.deps.onHide) == "function" then self.deps.onHide() end
    end)
    frame:SetScript("OnMouseWheel", function(_, delta) self:Scroll(delta > 0 and -3 or 3) end)
    styleFrame(frame, "window")

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -15)
    frame.title:SetText("背包估值")
    styleText(frame.title, "accent")

    local close = _G.EasyAuctionStyle and _G.EasyAuctionStyle.CloseButton
        and _G.EasyAuctionStyle:CloseButton(frame)
        or createFrame(create, "Button", nil, frame, "UIPanelButtonTemplate")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
    close:SetScript("OnClick", function() frame:Hide() end)
    if not (_G.EasyAuctionStyle and _G.EasyAuctionStyle.CloseButton) then
        close:SetSize(24, 22)
        close:SetText("X")
        styleButton(close)
    end
    frame.closeButton = close

    frame.summaryBand = createFrame(create, "Frame", nil, frame, "BackdropTemplate")
    frame.summaryBand:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -42)
    frame.summaryBand:SetSize(650, 55)
    styleFrame(frame.summaryBand, "panel")
    frame.summaryCards = {
        total = createSummaryMetric(frame.summaryBand, 8, "总估值"),
        auction = createSummaryMetric(frame.summaryBand, 138, "拍卖估值"),
        vendor = createSummaryMetric(frame.summaryBand, 268, "卖店价值"),
        priced = createSummaryMetric(frame.summaryBand, 398, "已估价"),
        unpriced = createSummaryMetric(frame.summaryBand, 528, "无价格"),
    }

    frame.search = createFrame(create, "EditBox", nil, frame, "SearchBoxTemplate")
    if not frame.search.SetTextInsets then
        frame.search = createFrame(create, "EditBox", nil, frame, "InputBoxTemplate")
    end
    frame.search:SetSize(300, 24)
    frame.search:SetPoint("TOPLEFT", frame, "TOPLEFT", 19, -111)
    frame.search:SetAutoFocus(false)
    if frame.search.SetInstructions then frame.search:SetInstructions("搜索物品") end
    if _G.EasyAuctionStyle and _G.EasyAuctionStyle.SkinEditBox then
        _G.EasyAuctionStyle:SkinEditBox(frame.search)
    end
    frame.search:SetScript("OnTextChanged", function(box)
        if not self.updatingSearch then self:SetSearch(box:GetText()) end
    end)
    frame.search:SetScript("OnEscapePressed", function(box) box:ClearFocus() end)
    frame.search:SetScript("OnEnterPressed", function(box) box:ClearFocus() end)

    frame.refresh = createFrame(create, "Button", nil, frame, "UIPanelButtonTemplate")
    frame.refresh:SetSize(74, 24)
    frame.refresh:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -19, -111)
    frame.refresh:SetText("刷新")
    styleButton(frame.refresh)
    frame.refresh:SetScript("OnClick", function()
        if type(self.deps.onRefresh) == "function" then self.deps.onRefresh() end
    end)

    frame.header = createFrame(create, "Frame", nil, frame)
    frame.header:SetPoint("TOPLEFT", frame, "TOPLEFT", 23, -148)
    frame.header:SetSize(634, 24)
    frame.headers = {}
    for _, def in ipairs(COLUMN_DEFS) do
        local button = createFrame(create, "Button", nil, frame.header)
        button:SetPoint("LEFT", frame.header, "LEFT", def.x, 0)
        button:SetSize(def.width, 24)
        button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        button.label:SetAllPoints()
        button.label:SetJustifyH(def.justify)
        button.sortKey = def.key
        button:SetScript("OnClick", function(target) self:SetSort(target.sortKey) end)
        frame.headers[def.key] = button
    end

    frame.list = createFrame(create, "Frame", nil, frame, "BackdropTemplate")
    frame.list:SetPoint("TOPLEFT", frame, "TOPLEFT", 23, -174)
    frame.list:SetSize(634, ROW_COUNT * ROW_HEIGHT)
    styleFrame(frame.list, "panel")
    for index = 1, ROW_COUNT do
        self.rowFrames[index] = self:_createRow(frame.list, index)
    end

    frame.status = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.status:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 23, 18)
    frame.status:SetSize(634, 20)
    frame.status:SetJustifyH("LEFT")
    styleText(frame.status, "muted")
    frame:Hide()
    self:_refreshHeaderLabels()
    self:_refreshRows()
    return frame
end

function View:_refreshHeaderLabels()
    if not self.frame or not self.frame.headers then return end
    for _, def in ipairs(COLUMN_DEFS) do
        local suffix = ""
        if self.sortKey == def.key then suffix = self.sortAscending and " ▲" or " ▼" end
        self.frame.headers[def.key].label:SetText(def.label .. suffix)
        styleText(self.frame.headers[def.key].label, self.sortKey == def.key and "accent" or "muted")
    end
end

function View:_projectRows()
    local query = lower(self.query)
    local projected = {}
    for index = 1, #self.rows do
        local row = self.rows[index]
        local haystack = lower(rowValue(row, "name") .. " " .. rowValue(row, "source"))
        if query == "" or string.find(haystack, query, 1, true) then
            projected[#projected + 1] = { row = row, index = index }
        end
    end
    local key, ascending = self.sortKey, self.sortAscending
    table.sort(projected, function(left, right)
        local a, b = rowValue(left.row, key), rowValue(right.row, key)
        if type(a) == "string" then a, b = lower(a), lower(b) end
        if a == b then return left.index < right.index end
        if ascending then return a < b end
        return a > b
    end)
    self.visibleRows = projected
    self.rowOffset = math.min(self.rowOffset, math.max(0, #projected - ROW_COUNT))
end

function View:_refreshRows()
    self:_projectRows()
    local style = _G and _G.EasyAuctionStyle
    for poolIndex = 1, ROW_COUNT do
        local frame = self.rowFrames[poolIndex]
        if frame then
            local projected = self.visibleRows[self.rowOffset + poolIndex]
            local row = projected and projected.row
            frame.data = row
            if row then
                frame.icon:SetTexture(row.icon or row.texture or row.iconFileID or 134400)
                frame.name:SetText(rowValue(row, "name"))
                frame.name:SetTextColor(qualityColor(row.quality))
                frame.count:SetText(tostring(rowValue(row, "count")))
                frame.unitValue:SetText(formatMoney(rowValue(row, "unitValue")))
                frame.totalValue:SetText(formatMoney(rowValue(row, "totalValue")))
                frame.source:SetText(tostring(rowValue(row, "source")))
                if style and type(style.RowColor) == "function" then
                    style:RowColor(frame.background, self.rowOffset + poolIndex, false)
                else
                    frame.background:SetColorTexture(1, 1, 1, poolIndex % 2 == 0 and 0.03 or 0.07)
                end
                frame:Show()
            else
                frame:Hide()
            end
        end
    end
    if self.frame and self.frame.status then
        local count, total = #self.visibleRows, #self.rows
        local first = count > 0 and self.rowOffset + 1 or 0
        local last = math.min(count, self.rowOffset + ROW_COUNT)
        local pending = math.max(0, tonumber(self.summary.pendingCount) or 0)
        local suffix = pending > 0 and ("，等待物品信息 " .. pending) or ""
        self.frame.status:SetText(string.format("显示 %d-%d / %d 项（背包共 %d 项）%s",
            first, last, count, total, suffix))
    end
end

function View:Render(result, rows)
    local summary
    if rows ~= nil then
        summary = result or {}
    else
        result = result or {}
        summary = result.summary or result
        rows = result.rows or result.items or summary.items or {}
    end
    self.summary = summary or {}
    self.rows = copyRows(rows)
    self.rowOffset = 0
    if self.frame then
        local cards = self.frame.summaryCards
        cards.total.value:SetText(formatMoney(self.summary.totalValue or self.summary.total))
        cards.auction.value:SetText(formatMoney(self.summary.auctionValue or self.summary.auction))
        cards.vendor.value:SetText(formatMoney(self.summary.vendorValue or self.summary.vendor))
        cards.priced.value:SetText(tostring(math.max(0, tonumber(self.summary.pricedCount) or 0)) .. " 项")
        cards.unpriced.value:SetText(tostring(math.max(0, tonumber(self.summary.unpricedCount) or 0)) .. " 项")
    end
    self:_refreshRows()
    return true
end

function View:SetSearch(query)
    query = tostring(query or "")
    if self.query == query then return false end
    self.query = query
    self.rowOffset = 0
    if self.frame and self.frame.search and self.frame.search:GetText() ~= query then
        self.updatingSearch = true
        self.frame.search:SetText(query)
        self.updatingSearch = false
    end
    self:_refreshRows()
    if type(self.deps.onSearch) == "function" then self.deps.onSearch(query) end
    return true
end

function View:GetSearch() return self.query end

function View:SetSort(key, ascending)
    local valid = false
    for _, def in ipairs(COLUMN_DEFS) do
        if def.key == key then valid = true break end
    end
    if not valid then return false end
    if ascending == nil then
        ascending = self.sortKey == key and not self.sortAscending or key == "name"
    end
    self.sortKey, self.sortAscending = key, ascending == true
    self.rowOffset = 0
    self:_refreshHeaderLabels()
    self:_refreshRows()
    if type(self.deps.onSort) == "function" then self.deps.onSort(key, self.sortAscending) end
    return true
end

function View:GetSort() return self.sortKey, self.sortAscending end

function View:Scroll(delta)
    local maximum = math.max(0, #self.visibleRows - ROW_COUNT)
    local nextOffset = math.max(0, math.min(maximum, self.rowOffset + (tonumber(delta) or 0)))
    if nextOffset == self.rowOffset then return false end
    self.rowOffset = nextOffset
    self:_refreshRows()
    return true
end

function View:SetBusy(busy)
    if self.frame and self.frame.refresh then self.frame.refresh:SetEnabled(not busy) end
end

function View:ShowError(message)
    if type(message) == "table" then message = message.message or message.code end
    if self.frame and self.frame.status then
        self.frame.status:SetText(message and ("|cffff4040" .. tostring(message) .. "|r") or "")
    end
end

function View:Show()
    if self.frame then self.frame:Show() return true end
    return false
end

function View:Hide()
    if self.frame then self.frame:Hide() return true end
    return false
end

function View:IsShown()
    return self.frame and self.frame:IsShown() == true or false
end

BagValue.BagValueView = View
BagValue.View = View
