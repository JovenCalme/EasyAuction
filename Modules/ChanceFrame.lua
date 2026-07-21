local EAStyle = _G.EasyAuctionStyle

local function EA_SkinFrame(frame, role)
    EAStyle = EAStyle or _G.EasyAuctionStyle
    if EAStyle then
        EAStyle:SkinExistingFrame(frame, role or "window")
    end
end

local function EA_SkinPanel(frame, role)
    EAStyle = EAStyle or _G.EasyAuctionStyle
    if EAStyle then
        EAStyle:Skin(frame, role or "panel")
    end
end

local function EA_SkinButton(button)
    EAStyle = EAStyle or _G.EasyAuctionStyle
    if EAStyle then
        EAStyle:SkinButton(button)
    end
end

local function EA_SkinText(fs, role)
    EAStyle = EAStyle or _G.EasyAuctionStyle
    if EAStyle then
        EAStyle:SkinText(fs, role)
    end
end

local function EA_RowColor(texture, index, selected)
    EAStyle = EAStyle or _G.EasyAuctionStyle
    if EAStyle then
        EAStyle:RowColor(texture, index, selected)
    elseif texture then
        texture:SetColorTexture(1, 1, 1, (index % 2 == 0) and 0.05 or 0.10)
    end
end

local function EA_SkinEditBox(box)
    EAStyle = EAStyle or _G.EasyAuctionStyle
    if EAStyle then
        EAStyle:SkinEditBox(box)
    end
    if box and box.SetFont then
        box:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
    end
    return box
end

local function EA_AddLine(parent, key, orientation, alpha)
    parent.EA_Lines = parent.EA_Lines or {}
    local tex = parent.EA_Lines[key]
    if not tex then
        tex = parent:CreateTexture(nil, "OVERLAY")
        tex:SetTexture("Interface\\Buttons\\WHITE8X8")
        parent.EA_Lines[key] = tex
        if EAStyle then
            EAStyle:OnTheme(function(p)
                tex:SetColorTexture(p.border[1], p.border[2], p.border[3], alpha or 0.6)
            end)
        end
    end
    tex:ClearAllPoints()
    if orientation == "vertical" then
        tex:SetWidth(1)
    else
        tex:SetHeight(1)
    end
    if not EAStyle then
        tex:SetColorTexture(0.45, 0.45, 0.50, alpha or 0.6)
    end
    tex:Show()
    return tex
end

local function EA_ApplyTableLines(row, headers, alpha)
    if not row or not headers then return end
    local top = EA_AddLine(row, "top", "horizontal", alpha)
    top:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    local bottom = EA_AddLine(row, "bottom", "horizontal", alpha)
    bottom:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    local left = EA_AddLine(row, "left", "vertical", alpha)
    left:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    local right = EA_AddLine(row, "right", "vertical", alpha)
    right:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    row.EA_ColLines = row.EA_ColLines or {}
    for i = 1, #headers - 1 do
        local cell = row.cols and row.cols[i]
        local line = row.EA_ColLines[i]
        if not line then
            line = row:CreateTexture(nil, "OVERLAY")
            line:SetTexture("Interface\\Buttons\\WHITE8X8")
            line:SetWidth(1)
            row.EA_ColLines[i] = line
            if EAStyle then
                EAStyle:OnTheme(function(p)
                    line:SetColorTexture(p.border[1], p.border[2], p.border[3], 0.45)
                end)
            end
        end
        line:ClearAllPoints()
        if cell then
            line:SetPoint("TOPLEFT", cell, "TOPRIGHT", 0, 0)
            line:SetPoint("BOTTOMLEFT", cell, "BOTTOMRIGHT", 0, 0)
        end
        if not EAStyle then
            line:SetColorTexture(0.45, 0.45, 0.50, 0.45)
        end
        line:Show()
    end
end

function EasyAuction_ChanceOptionsFrame()
    local defaultOptions = {
        minVol = 5,            -- 最低低价数量
        pricePct = 0.7,        -- 低价占比
        minProfit = 50,        -- 套利空间最少铜币
        lowPrice = 100,        -- 超低价阈值
        minNetProfitRate = 0.08, -- 最低净利润率（8%=0.08）
        maxSaturation = 2.0,     -- 最大库存饱和度
    }
    -- 使用全局数据库引用
    local EasyAuctionDB = _G.EasyAuctionDB
    if not EasyAuctionDB then return end
    EasyAuctionDB.OpportunityOptions = EasyAuctionDB.OpportunityOptions or {}
    local opts = EasyAuctionDB.OpportunityOptions
    for k, v in pairs(defaultOptions) do
        if opts[k] == nil then opts[k] = v end
    end

    if EasyAuction_OpportunityOptionsFrame then
        EasyAuction_OpportunityOptionsFrame:Show()
        return
    end

    local f = CreateFrame("Frame", "EasyAuction_OpportunityOptionsFrame", UIParent, "BackdropTemplate")
    f:SetSize(448, 424)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetFrameLevel(300)
    f:SetToplevel(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    EA_SkinFrame(f, "window")
    tinsert(UISpecialFrames, "EasyAuction_OpportunityOptionsFrame")

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", 14, -12)
    f.title:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 14, "")
    f.title:SetText("商机发现参数设置")
    EA_SkinText(f.title, "accent")
    if EAStyle then
        local closeBtn = EAStyle:CloseButton(f)
        closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
        closeBtn:SetScript("OnClick", function() f:Hide() end)
    end

    local fields = {
        { key="minVol", label="低价量门槛", desc="最低低价数量（如5）", default=defaultOptions.minVol, order=1, group="基础筛选" },
        { key="pricePct", label="低价占比", desc="低于中位价/昨日价百分比（如0.7=70%）", default=defaultOptions.pricePct, order=2, group="基础筛选" },
        { key="lowPrice", label="超低价阈值", desc="低于此值判为超低价", default=defaultOptions.lowPrice, order=3, group="基础筛选" },
        { key="minProfit", label="套利空间", desc="套利空间最少铜币（如50）", default=defaultOptions.minProfit, order=4, group="利润相关" },
        { key="minNetProfitRate", label="最低净利润率", desc="（如0.08=8%）仅显示高于该比例的商机", default=defaultOptions.minNetProfitRate, order=5, group="利润相关" },
        { key="maxSaturation", label="最大库存饱和度", desc="（如2.0）只推荐当前库存/日均销量低于该值的物品", default=defaultOptions.maxSaturation, order=6, group="库存相关" },
    }

    local groupOrder = {"基础筛选", "利润相关", "库存相关"}

    f.inputs = {}
    local y = -42
    for _, group in ipairs(groupOrder) do
        local groupPanel = CreateFrame("Frame", nil, f, "BackdropTemplate")
        groupPanel:SetPoint("TOPLEFT", f, "TOPLEFT", 18, y)
        groupPanel:SetPoint("TOPRIGHT", f, "TOPRIGHT", -18, y)
        local groupFieldCount = 0
        local groupTitle = groupPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        groupTitle:SetPoint("TOPLEFT", groupPanel, "TOPLEFT", 10, -8)
        groupTitle:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
        groupTitle:SetText(group)
        EA_SkinText(groupTitle, "accent")

        for _, field in ipairs(fields) do
            if field.group == group then
                groupFieldCount = groupFieldCount + 1
                local rowY = -34 - (groupFieldCount - 1) * 30
                local label = groupPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                label:SetPoint("TOPLEFT", groupPanel, "TOPLEFT", 12, rowY + 4)
                label:SetWidth(92)
                label:SetJustifyH("LEFT")
                label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
                label:SetText(field.label .. "：")
                EA_SkinText(label, "muted")

                local edit = CreateFrame("EditBox", nil, groupPanel, "InputBoxTemplate")
                edit:SetSize(84, 22)
                edit:SetPoint("TOPLEFT", groupPanel, "TOPLEFT", 112, rowY)
                edit:SetAutoFocus(false)
                edit:SetNumeric(false)
                edit:SetMaxLetters(12)
                EA_SkinEditBox(edit)
                if type(field.default) == "number" and math.floor(field.default) == field.default then
                    edit:SetText(tostring(opts[field.key] or field.default))
                else
                    edit:SetText(tostring(opts[field.key] or field.default))
                end
                edit:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(field.label, 1, 1, 1)
                    GameTooltip:AddLine(field.desc, nil, nil, nil, true)
                    GameTooltip:Show()
                end)
                edit:SetScript("OnLeave", function() GameTooltip:Hide() end)

                local desc = groupPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                desc:SetPoint("LEFT", edit, "RIGHT", 10, 0)
                desc:SetWidth(210)
                desc:SetJustifyH("LEFT")
                desc:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "")
                desc:SetText(field.desc)
                EA_SkinText(desc, "muted")

                f.inputs[field.key] = edit
            end
        end
        local groupHeight = 42 + groupFieldCount * 30
        groupPanel:SetHeight(groupHeight)
        EA_SkinPanel(groupPanel, "panel")
        y = y - groupHeight - 12
    end

    local saveBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    saveBtn:SetSize(70, 22)
    saveBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 16)
    saveBtn:SetText("保存")
    EA_SkinButton(saveBtn)
    saveBtn:SetScript("OnClick", function()
        local function safeNum(e, d)
            local v = tonumber(e:GetText() or "")
            return (v and v >= 0) and v or d
        end
        opts.minVol = math.max(1, math.floor(safeNum(f.inputs.minVol, defaultOptions.minVol)))
        opts.pricePct = safeNum(f.inputs.pricePct, defaultOptions.pricePct)
        opts.minProfit = math.max(0, math.floor(safeNum(f.inputs.minProfit, defaultOptions.minProfit)))
        opts.lowPrice = math.max(0, math.floor(safeNum(f.inputs.lowPrice, defaultOptions.lowPrice)))
        opts.minNetProfitRate = safeNum(f.inputs.minNetProfitRate, defaultOptions.minNetProfitRate)
        opts.maxSaturation = safeNum(f.inputs.maxSaturation, defaultOptions.maxSaturation)
        print("|cff00ff00[EasyAuction]|r 商机参数已保存。")
        f:Hide()
    end)

    local resetBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    resetBtn:SetSize(90, 22)
    resetBtn:SetPoint("RIGHT", saveBtn, "LEFT", -6, 0)
    resetBtn:SetText("恢复默认")
    EA_SkinButton(resetBtn)
    resetBtn:SetScript("OnClick", function()
        for _, field in ipairs(fields) do
            f.inputs[field.key]:SetText(tostring(field.default))
        end
    end)
end

function EasyAuction_ChanceFrame(page)
    local FRAME_WIDTH = 1280
    local FRAME_HEIGHT = 640
    local ROWS = 13
    -- 默认按净利润率降序
    local sortBy, sortAsc = 9, false 
    local lastResults = nil

    local sortFields = {
        [1] = "name",
        [2] = "unitPrice",
        [3] = "minUnit",
        [4] = "minCount",
        [5] = "totalCount",
        [6] = "median",
        [7] = "yest",
        [8] = "sellPrice",
        [9] = "netProfitRate",
        [10] = "saturation",
        [11] = "reason",
    }

    if not EasyAuction_OpportunitiesFrame then
        local f = CreateFrame("Frame", "EasyAuction_OpportunitiesFrame", UIParent, "BackdropTemplate")
        f:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
        f:SetPoint("CENTER")
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetMovable(true)
        f:EnableMouse(true)
        f:SetFrameLevel(200)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        EA_SkinFrame(f, "window")
        tinsert(UISpecialFrames, "EasyAuction_OpportunitiesFrame")

        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.title:SetPoint("TOPLEFT", 14, -12)
        f.title:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 15, "")
        f.title:SetText("EasyAuction 商机发现")
        EA_SkinText(f.title, "accent")

        local closeBtn = EAStyle and EAStyle:CloseButton(f) or CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
        closeBtn:SetScript("OnClick", function() f:Hide() end)

        local optionsBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        optionsBtn:SetSize(90, 22)
        optionsBtn:SetPoint("TOPRIGHT", closeBtn, "LEFT", -8, 0)
        optionsBtn:SetText("参数设置")
        EA_SkinButton(optionsBtn)
        optionsBtn:SetScript("OnClick", function()
            EasyAuction_ChanceOptionsFrame()
        end)

        local refreshBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        refreshBtn:SetSize(70, 22)
        refreshBtn:SetPoint("RIGHT", optionsBtn, "LEFT", -6, 0)
        refreshBtn:SetText("刷新")
        EA_SkinButton(refreshBtn)
        f.refreshBtn = refreshBtn

        f.statusText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.statusText:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -42)
        f.statusText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
        f.statusText:SetText("")
        EA_SkinText(f.statusText, "muted")

        f.tablePanel = CreateFrame("Frame", nil, f, "BackdropTemplate")
        f.tablePanel:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -86)
        f.tablePanel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 50)
        EA_SkinPanel(f.tablePanel, "panel")

        f.progressBG = f:CreateTexture(nil, "BACKGROUND")
        if EAStyle then
            local p = EAStyle:Palette()
            f.progressBG:SetColorTexture(p.plot[1], p.plot[2], p.plot[3], 0.85)
        else
            f.progressBG:SetColorTexture(0.2, 0.2, 0.2, 0.7)
        end
        f.progressBG:SetSize(320, 22)
        f.progressBG:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -58)
        f.progressBar = f:CreateTexture(nil, "ARTWORK")
        if EAStyle then
            f.progressBar:SetColorTexture(EAStyle.Bull[1], EAStyle.Bull[2], EAStyle.Bull[3], 1)
        else
            f.progressBar:SetColorTexture(0.18, 0.7, 0.18, 1)
        end
        f.progressBar:SetPoint("LEFT", f.progressBG, "LEFT", 0, 0)
        f.progressBar:SetSize(0, 22)
        f.progressText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.progressText:SetPoint("CENTER", f.progressBG, "CENTER", 0, 0)
        EA_SkinText(f.progressText, "text")

        local headers = {
            {text="物品名", width=180, justify="LEFT"},
            {text="单位价", width=90, justify="RIGHT"},
            {text="最低一口", width=90, justify="RIGHT"},
            {text="低价数量", width=70, justify="CENTER"},
            {text="总量", width=70, justify="CENTER"},
            {text="中位价", width=110, justify="RIGHT"},
            {text="昨日", width=110, justify="RIGHT"},
            {text="卖店", width=90, justify="RIGHT"},
            {text="净利润率", width=90, justify="RIGHT"},
            {text="饱和度", width=80, justify="RIGHT"},
            {text="理由", width=230, justify="LEFT"},
        }

        f.headerFS = {}
        f.headerBtns = {}
        local x = 18
        for i, h in ipairs(headers) do
            local btn = CreateFrame("Button", nil, f)
            btn:SetSize(h.width, 20)
            btn:SetPoint("TOPLEFT", f, "TOPLEFT", x, -92)
            local fs = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            fs:SetPoint("LEFT", btn, "LEFT", 4, 0)
            fs:SetWidth(h.width-12)
            fs:SetJustifyH(h.justify or "LEFT")
            fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
            fs:SetText(h.text)
            EA_SkinText(fs, "muted")
            btn:SetFontString(fs)
            btn.bg = btn:CreateTexture(nil, "BACKGROUND")
            btn.bg:SetAllPoints()
            EA_RowColor(btn.bg, i, true)
            btn.cols = { fs }
            EA_ApplyTableLines(btn, { h }, 0.65)
            btn:SetScript("OnEnter", function(self)
                if self.bg then EA_RowColor(self.bg, i, true) end
            end)
            btn:SetScript("OnLeave", function(self)
                if self.bg then EA_RowColor(self.bg, i, true) end
            end)
            btn:SetScript("OnClick", function()
                if sortBy == i then
                    sortAsc = not sortAsc
                else
                    sortBy = i
                    sortAsc = (i ~= 9 and i ~= 10)
                end
                if lastResults then
                    SortResults(lastResults)
                    ShowPage(1, lastResults)
                end
            end)
            f.headerFS[i] = fs
            f.headerBtns[i] = btn
            x = x + h.width + 8
        end

        f.ROWS = ROWS
        f.rows = {}
        for i=1, f.ROWS do
            local row = CreateFrame("Button", nil, f)
            row:SetSize(FRAME_WIDTH-24, 28)
            row:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -112-(i-1)*30)
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
            EA_RowColor(row.bg, i)
            row:Hide()
            row.cols = {}
            local col_x = 0
            for j, h in ipairs(headers) do
                row.cols[j] = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
                row.cols[j]:SetPoint("LEFT", row, "LEFT", col_x + 4, 0)
                row.cols[j]:SetWidth(h.width)
                row.cols[j]:SetJustifyH(h.justify or "LEFT")
                row.cols[j]:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
                EA_SkinText(row.cols[j], "text")
                col_x = col_x + h.width + 8
            end
            EA_ApplyTableLines(row, headers, 0.5)
            row:SetScript("OnEnter", function(self)
                if self.bg then EA_RowColor(self.bg, i, true) end
                local link = self.itemLink
                if link then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetHyperlink(link)
                    GameTooltip:AddLine("左键：价格历史\n右键：复制链接", 0.8, 0.8, 0.8)
                    GameTooltip:Show()
                end
            end)
            row:SetScript("OnLeave", function(self)
                if self.bg then EA_RowColor(self.bg, i) end
                GameTooltip:Hide()
            end)
            row:SetScript("OnClick", function(self, button)
                if not self.itemName then return end
                if button == "LeftButton" then
                    local key = self.itemName
                    if self.itemID then
                        key = self.itemName .. ":" .. self.itemID
                    end
                    local priceList = EasyAuction_GetPriceHistory and EasyAuction_GetPriceHistory(key, EasyAuctionDB) or (EasyAuctionDB and EasyAuctionDB.PriceHistory and EasyAuctionDB.PriceHistory[key])
                    if priceList and type(priceList) == "table" and #priceList > 0 then
                        ShowPriceFrame(key, priceList)
                    else
                        print("|cff00ff00[EasyAuction]|r 无历史价格数据："..(self.itemName or "?"))
                    end
                elseif button == "RightButton" and self.itemLink then
                    HandleModifiedItemClick(self.itemLink)
                end
            end)
            f.rows[i] = row
        end

        f.prevBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.prevBtn:SetSize(80, 22)
        f.prevBtn:SetPoint("BOTTOMLEFT", 32, 15)
        f.prevBtn:SetText("上一页")
        EA_SkinButton(f.prevBtn)

        f.nextBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        f.nextBtn:SetSize(80, 22)
        f.nextBtn:SetPoint("LEFT", f.prevBtn, "RIGHT", 6, 0)
        f.nextBtn:SetText("下一页")
        EA_SkinButton(f.nextBtn)

        f.pageText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.pageText:SetPoint("LEFT", f.nextBtn, "RIGHT", 10, 0)
        f.pageText:SetText("")
        EA_SkinText(f.pageText, "muted")

        function f:DisableNav()
            f.prevBtn:Disable()
            f.nextBtn:Disable()
            for i=1,f.ROWS do f.rows[i]:Hide() end
        end

        EasyAuction_OpportunitiesFrame = f
    end

    local frame = EasyAuction_OpportunitiesFrame
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    for i=1, ROWS do
        frame.rows[i]:SetWidth(FRAME_WIDTH-24)
    end
    frame:Show()

    function SortResults(results)
        local field = sortFields[sortBy] or "netProfitRate"
        table.sort(results, function(a, b)
            local va, vb = a[field], b[field]
            if va == vb then
                return (a.netProfitRate or 0) > (b.netProfitRate or 0)
            end
            if sortAsc then
                return (va or 0) < (vb or 0)
            else
                return (va or 0) > (vb or 0)
            end
        end)
    end

    function ShowPage(page, results)
        lastResults = results
        local totalPages = math.max(1, math.ceil((results and #results or 0) / frame.ROWS))
        page = math.max(1, math.min(totalPages, page or 1))
        frame._page = page
        local startIdx = (page - 1) * frame.ROWS + 1
        local endIdx = math.min(startIdx + frame.ROWS - 1, results and #results or 0)
        for rowi = 1, frame.ROWS do
            local row = frame.rows[rowi]
            local idx = startIdx + rowi - 1
            local item = results and results[idx]
            if item then
                local icon = ""
                if item.link then
                    local itemID = tonumber(item.link:match("item:(%d+)"))
                    if itemID then
                        local iconPath = GetItemIcon(itemID)
                        if iconPath then
                            icon = "|T"..iconPath..":18:18:0:0|t "
                        end
                        row.itemID = itemID
                    else
                        row.itemID = nil
                    end
                end
                row.cols[1]:SetText(icon..(item.name or ""))
                row.cols[2]:SetText(item.unitPrice and FormatGoldIcon(item.unitPrice) or "-")
                row.cols[3]:SetText(item.minUnit and FormatGoldIcon(item.minUnit) or "-")
                row.cols[4]:SetText(item.minCount or "-")
                row.cols[5]:SetText(item.totalCount or "-")
                row.cols[6]:SetText(item.median and FormatGoldIcon(item.median) or "-")
                row.cols[7]:SetText(item.yest and FormatGoldIcon(item.yest) or "-")
                row.cols[8]:SetText(item.sellPrice and FormatGoldIcon(item.sellPrice) or "-")
                row.cols[9]:SetText(item.netProfitRate and string.format("%.1f%%", item.netProfitRate*100) or "-")
                row.cols[10]:SetText(item.saturation and string.format("%.2f", item.saturation) or "-")
                row.cols[11]:SetText(item.reason or "")
                row.itemLink = item.link
                row.minUnit = item.minUnit
                row.itemName = item.name
                row:Show()
            else
                row:Hide()
                row.itemLink = nil
                row.minUnit = nil
                row.itemName = nil
                row.itemID = nil
            end
        end
        frame.prevBtn:SetEnabled(page > 1)
        frame.nextBtn:SetEnabled(page < totalPages)
        frame.pageText:SetText(string.format("第%d/%d页", page, totalPages))
    end
    frame.prevBtn:SetScript("OnClick", function()
        if frame._page > 1 and lastResults then ShowPage(frame._page - 1, lastResults) end
    end)
    frame.nextBtn:SetScript("OnClick", function()
        local totalPages = math.max(1, math.ceil((lastResults and #lastResults or 0) / frame.ROWS))
        if frame._page < totalPages and lastResults then ShowPage(frame._page + 1, lastResults) end
    end)

    function frame:StartAnalysis()
        frame:DisableNav()
        frame.statusText:SetText("正在分析，请稍候...")
        frame.progressBG:Show()
        frame.progressBar:Show()
        frame.progressText:Show()
        frame.progressBar:SetWidth(0)
        frame.progressText:SetText("0%")

        local opts = EasyAuctionDB and EasyAuctionDB.OpportunityOptions or {}
        local MIN_VOL = opts.minVol or 5
        local PRICE_PCT = opts.pricePct or 0.7
        local MIN_PROFIT = opts.minProfit or 50
        local LOW_PRICE = opts.lowPrice or 100
        local MIN_NET_PROFIT_RATE = opts.minNetProfitRate or 0.08
        local MAX_SATURATION = opts.maxSaturation or 2.0

        local results = {}
        local allKeys = {}
        for key in pairs(EasyAuctionDB.PriceHistory or {}) do
            table.insert(allKeys, key)
        end
        local total = #allKeys
        local i = 1
        local BATCH_SIZE = 10

        local function get3DayAvgSold(name)
            -- 留空，待补充
            return 1
        end
        local function getDeposit(name, stackSize)
            -- 留空，待补充
            return 0
        end
        local function suspiciousName(name)
            -- 留空，待补充
            return false
        end

        local function processBatch()
            local batch = 0
            local t0 = debugprofilestop()
            while i <= total and batch < BATCH_SIZE and (debugprofilestop() - t0) < 10 do
                local key = allKeys[i]
                local data = EasyAuction_GetPriceHistory and EasyAuction_GetPriceHistory(key, EasyAuctionDB) or EasyAuctionDB.PriceHistory[key]
                if type(data) == "table" and #data > 0 then
                    local name, itemID = key:match("^(.-):(%d+)$")
                    itemID = tonumber(itemID)
                    local prices, totalCount = {}, 0
            for _, v in ipairs(data) do
                local unit = tonumber(v.unit or v[2])
                local count = tonumber(v.count or v[1]) or 0
                if unit and count > 0 then
                    table.insert(prices, {unit = unit, count = count})
                    totalCount = totalCount + count
                end
            end
                    table.sort(prices, function(a, b) return a.unit < b.unit end)
                    if #prices > 0 then
                        local minUnit, minCount = prices[1].unit, prices[1].count
                        for j = 2, #prices do
                            if prices[j].unit == minUnit then
                                minCount = minCount + prices[j].count
                            else
                                break
                            end
                        end
                        local function trimmed_median(units, trimPct)
                            table.sort(units)
                            local n = #units
                            local trim = math.floor(n * (trimPct or 0.1) + 0.5)
                            local from = trim + 1
                            local to = n - trim
                            if from > to then from, to = 1, n end
                            local trimmed = {}
                            for i = from, to do
                                trimmed[#trimmed + 1] = units[i]
                            end
                            local tn = #trimmed
                            if tn == 0 then return nil end
                            if tn % 2 == 1 then
                                return trimmed[math.ceil(tn / 2)]
                            else
                                return math.floor((trimmed[tn / 2] + trimmed[tn / 2 + 1]) / 2 + 0.5)
                            end
                        end
                        local units = {}
                        for _, v in ipairs(prices) do table.insert(units, v.unit) end
                        local median = trimmed_median(units, 0.1)
                        table.sort(units)
                        if #units % 2 == 1 then
                            median = units[math.ceil(#units/2)]
                        else
                            median = math.floor((units[#units/2] + units[#units/2+1])/2+0.5)
                        end

                        local function GetYesterdayDailyPrice(key)
                            local daily = EasyAuction_GetDailyMinPrice and EasyAuction_GetDailyMinPrice(key, EasyAuctionDB) or (EasyAuctionDB.DailyMinPrice and EasyAuctionDB.DailyMinPrice[key])
                            if not daily or type(daily) ~= "table" or #daily == 0 then
                                return nil
                            end
                            local target = date("%Y-%m-%d", time()-86400)
                            for i = #daily, 1, -1 do
                                if daily[i][1] == target then
                                    return daily[i][2]  -- 返回unit（单价），如需其它字段可换下标
                                end
                            end
                            return nil
                        end

                        local yest = GetYesterdayDailyPrice(key)
                        if type(yest) ~= "number" then yest = nil end

                        local link = data[1][4] or nil
                        local sellPrice = 0
                        local itemID
                        if link then
                            itemID = tonumber(link:match("item:(%d+)"))
                            if itemID then
                                EasyAuctionDB.VendorPrice = EasyAuctionDB.VendorPrice or {}
                                sellPrice = EasyAuctionDB.VendorPrice[itemID] or 0
                                if sellPrice == 0 then
                                    local price = select(11, GetItemInfo(itemID))
                                    if price and type(price) == "number" and price > 0 then
                                        sellPrice = price
                                        EasyAuctionDB.VendorPrice[itemID] = price
                                    else
                                        sellPrice = 0
                                    end
                                end
                            end
                        end

                        local unitPrice = minUnit

                        -- 预估售价：中位价优先，次选昨日，最后卖店
                        local estSell = median or yest or sellPrice or 0

                        local deposit = getDeposit(name, 1)
                        local feeRate = 0.05
                        local fee = math.floor(estSell * feeRate + 0.5)

                        local netProfit = estSell - unitPrice - fee - deposit
                        local netProfitRate = (unitPrice > 0) and (netProfit / unitPrice) or 0

                        local avg3DaySold = get3DayAvgSold(name)
                        local saturation = (avg3DaySold > 0) and (totalCount / avg3DaySold) or 999

                        if minUnit and minUnit > 0
                            and not suspiciousName(name)
                            and minCount >= (MIN_VOL or 1)
                            and netProfitRate >= MIN_NET_PROFIT_RATE
                            --and saturation <= MAX_SATURATION 
                        then

                            local reason = ""
                            if median and minUnit < median * PRICE_PCT then
                                reason = reason .. string.format("低于中位价%.0f%%，低价量%d", minUnit/median*100, minCount)
                            end
                            if yest and minUnit < yest * PRICE_PCT then
                                reason = reason .. (reason~="" and "，" or "") .. string.format("低于昨日价%.0f%%，低价量%d", minUnit/yest*100, minCount)
                            end
                            if sellPrice > 0 and minUnit < sellPrice * 0.95 and minCount >= MIN_VOL then
                                local afterTax = math.floor(minUnit * 0.95 + 0.5)
                                if (sellPrice - afterTax) >= MIN_PROFIT then
                                    reason = reason .. (reason~="" and "，" or "") .. "套利空间："..FormatGoldIcon(sellPrice-afterTax)
                                end
                            end
                            if minUnit <= LOW_PRICE and minCount >= MIN_VOL then
                                reason = reason .. (reason~="" and "，" or "") .. "超低价"
                            end
                            if netProfitRate >= 0.2 then
                                reason = reason .. (reason~="" and "，" or "") .. string.format("高净利%.1f%%", netProfitRate*100)
                            end
                            if saturation < 1 then
                                reason = reason .. (reason~="" and "，" or "") .. "库存紧张"
                            end
                            if reason == "" then
                                reason = "满足基础筛选"
                            end

                            table.insert(results, {
                                name = name,
                                unitPrice = unitPrice,
                                minUnit = minUnit,
                                minCount = minCount,
                                totalCount = totalCount,
                                median = median,
                                yest = yest,
                                sellPrice = sellPrice,
                                netProfitRate = netProfitRate,
                                saturation = saturation,
                                link = link,
                                reason = reason
                            })
                        end 
                    end
                end
                i = i + 1
                batch = batch + 1
            end

            local percent = total > 0 and math.floor(i * 100 / total) or 100
            local width = math.floor(320 * percent / 100)
            frame.progressBar:SetWidth(width)
            frame.progressText:SetText(percent.."%")
            frame.statusText:SetText(string.format("已分析%d/%d（%d%%），发现%d个商机...", math.min(i,total), total, percent, #results))

            SortResults(results)
            ShowPage(1, results)

            if i <= total then
                C_Timer.After(0.02, processBatch)
            else
                frame.statusText:SetText(string.format(
                    "共发现 %d 个商机 | 净利≥%.1f%%，饱和度≤%.2f，低价量≥%d",
                    #results, (MIN_NET_PROFIT_RATE or 0.08)*100, MAX_SATURATION or 2, MIN_VOL or 5
                ))
                frame.progressBar:SetWidth(320)
                frame.progressText:SetText("100%")
                EasyAuctionDB.LastOpportunitiesSummary = { count = #results, time = time() }
                frame._lastResults = results
                C_Timer.After(0.3, function()
                    frame.progressBG:Hide()
                    frame.progressBar:Hide()
                    frame.progressText:Hide()
                    ShowPage(frame._page, results)
                    frame.prevBtn:SetEnabled(true)
                    frame.nextBtn:SetEnabled(true)
                end)
            end
        end
        processBatch()
    end

    frame.refreshBtn:SetScript("OnClick", function() frame:StartAnalysis() end)

    local cached = frame._lastResults
    if cached and #cached > 0 then
        SortResults(cached)
        ShowPage(page or 1, cached)
        frame.statusText:SetText(string.format("共发现 %d 个商机（分析于 %s，点击刷新）", #cached, date("%Y-%m-%d %H:%M")))
        frame.progressBG:Hide()
        frame.progressBar:Hide()
        frame.progressText:Hide()
        frame.prevBtn:SetEnabled(true)
        frame.nextBtn:SetEnabled(true)
    else
        frame.statusText:SetText("无分析数据，请点击刷新按钮进行分析。")
        frame.progressBG:Hide()
        frame.progressBar:Hide()
        frame.progressText:Hide()
        frame:DisableNav()
    end
    frame:Show()
end
