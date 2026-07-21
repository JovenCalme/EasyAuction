local EAStyle = _G.EasyAuctionStyle
local EAGraph = LibStub and LibStub("LibGraph-2.0", true)

local function EA_Palette()
    if EAStyle then
        return EAStyle:Palette()
    end
    return {
        bg = { 0.10, 0.10, 0.13 },
        panel = { 0.13, 0.13, 0.16 },
        plot = { 0.08, 0.08, 0.10 },
        border = { 0.7, 0.6, 1 },
        text = { 1, 1, 1 },
        muted = { 0.65, 0.65, 0.65 },
        accent = { 0, 0.7, 1 },
        accent2 = { 0.1, 0.7, 0.9 },
    }
end

local function EA_SkinChartFrame(frame, role)
    if EAStyle then
        EAStyle:SkinExistingFrame(frame, role or "window")
    end
end

local function EA_SkinChartText(fs, role)
    if EAStyle then
        EAStyle:SkinText(fs, role)
    end
end

local function EA_SkinChartCloseButton(button)
    if not (EAStyle and button) then return end
    button:SetSize(22, 22)
    button:SetText("\195\151")
    EAStyle:SkinButton(button)
    local fs = button:GetFontString()
    if fs then
        fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 15, "")
        fs:ClearAllPoints()
        fs:SetPoint("CENTER", 0, 0)
    end
    button:HookScript("OnEnter", function()
        if button.SetBackdropColor then
            button:SetBackdropColor(EAStyle.Bear[1], EAStyle.Bear[2], EAStyle.Bear[3], 0.85)
            button:SetBackdropBorderColor(EAStyle.Bear[1], EAStyle.Bear[2], EAStyle.Bear[3], 1)
            if fs then fs:SetTextColor(1, 1, 1) end
        end
    end)
end

local function EA_RaiseChartFrame(frame)
    if not frame then return end
    local maxLevel = 0
    local function AddFrameLevel(candidate)
        if candidate and candidate.GetFrameLevel and (not candidate.IsShown or candidate:IsShown()) then
            maxLevel = math.max(maxLevel, candidate:GetFrameLevel() or 0)
        end
    end

    AddFrameLevel(_G.EasyAuctionDBFrame)
    AddFrameLevel(_G.DBFrame)
    AddFrameLevel(_G.AuctionHelper)
    AddFrameLevel(_G.EasyAuctionConfigFrame)
    AddFrameLevel(_G.EasyAuction_GoldBillFrame)

    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(math.max(maxLevel + 80, 260))
    frame:SetToplevel(true)
    if frame.Raise then
        frame:Raise()
    end
end

local function EA_EnsureLineGraph(owner, key, left, bottom, width, height)
    if not EAGraph then return nil end
    owner.__EAGraphs = owner.__EAGraphs or {}
    local graph = owner.__EAGraphs[key]
    if not graph then
        graph = EAGraph:CreateGraphLine(nil, owner, "BOTTOMLEFT", "BOTTOMLEFT", left, bottom, width, height)
        graph:SetFrameLevel((owner:GetFrameLevel() or 1) + 1)
        graph:SetAxisDrawing(true, true)
        owner.__EAGraphs[key] = graph
    end
    graph:ClearAllPoints()
    graph:SetPoint("BOTTOMLEFT", owner, "BOTTOMLEFT", left, bottom)
    graph:SetSize(width, height)
    graph:Show()
    return graph
end

local function EA_RenderLineGraph(owner, key, values, left, bottom, width, height, xScale)
    local graph = EA_EnsureLineGraph(owner, key, left, bottom, width, height)
    if not graph then return false end

    graph:ResetData()
    local pts = {}
    local minV, maxV
    local maxX = 1
    for i = 1, #values do
        local v = values[i]
        if v and v > 0 then
            local x = xScale and xScale(i) or (i - 1)
            pts[#pts + 1] = { x, v }
            maxX = math.max(maxX, x)
            minV = minV and math.min(minV, v) or v
            maxV = maxV and math.max(maxV, v) or v
        end
    end
    if #pts < 2 then
        graph:Hide()
        return false
    end

    minV = 0
    maxV = maxV or 1

    local p = EA_Palette()
    graph:SetXAxis(0, maxX)
    graph:SetYAxis(minV, maxV)
    graph:SetGridSpacing(math.max(maxX / 6, 0.001), (maxV - minV) / 4)
    graph:SetAxisColor({ p.border[1], p.border[2], p.border[3], 0.85 })
    graph:SetGridColor({ p.border[1], p.border[2], p.border[3], 0.18 })
    graph:AddDataSeries(pts, { p.accent[1], p.accent[2], p.accent[3], 1 })
    return true
end

function EasyAuction_ShowChart(itemName)
    -- 使用全局数据库引用
    local EasyAuctionDB = _G.EasyAuctionDB
    if not EasyAuctionDB then
        print("|cff00ff00[EasyAuction]|r 数据库未初始化。")
        return
    end
    EasyAuctionDB.DailyMinPrice = EasyAuctionDB.DailyMinPrice or {}
    EasyAuctionDB.PriceHistory = EasyAuctionDB.PriceHistory or {}
    EasyAuctionDB.HourlyMinPrice = EasyAuctionDB.HourlyMinPrice or {}

    local itemID = tostring(itemName):match(":(%d+)$") or ""
    itemID = tonumber(itemID) or ""
    local dailyArray = EasyAuction_GetDailyMinPrice and EasyAuction_GetDailyMinPrice(itemName, EasyAuctionDB) or EasyAuctionDB.DailyMinPrice[itemName]
    if not dailyArray or #dailyArray == 0 then
        if EasyAuction_ChartFrame and EasyAuction_ChartFrame:IsShown() then
            EasyAuction_ChartFrame:Hide()
        end
        print("|cff00ff00[EasyAuction]|r 暂无此物品每日价格数据。")
        return
    end

    -- 辅助函数：查找某天的数据
    local function findDailyByDate(date)
        for _, v in ipairs(dailyArray) do
            if v[1] == date then return v end
        end
        return nil
    end

    -- 找到最后一个有数据的日期
    local lastDay
    for _, v in ipairs(dailyArray) do
        if v[1] and v[2] and v[2] > 0 then
            if not lastDay or v[1] > lastDay then lastDay = v[1] end
        end
    end
    if not lastDay then
        print("|cff00ff00[EasyAuction]|r 暂无此物品每日价格数据。")
        return
    end

    local y, m, d = lastDay:match("(%d+)-(%d+)-(%d+)")
    local axisRight = time({ year = tonumber(y), month = tonumber(m), day = tonumber(d) })

    local points, countPoints, totalCountPoints, days = {}, {}, {}, {}
    for i = 29, 0, -1 do
        local t = date("%Y-%m-%d", axisRight - i * 86400)
        table.insert(days, t)
        local v = findDailyByDate(t)
        if v then
            table.insert(points, v[2] or 0)          -- unit
            table.insert(countPoints, v[3] or 0)     -- count
            table.insert(totalCountPoints, v[6] or 0)-- totalCount
        else
            table.insert(points, 0)
            table.insert(countPoints, 0)
            table.insert(totalCountPoints, 0)
        end
    end

    local chartFrame = EasyAuction_ChartFrame
    if not chartFrame then
        chartFrame = CreateFrame("Frame", "EasyAuction_ChartFrame", UIParent, "BackdropTemplate")
        chartFrame:SetSize(580, 420)
        chartFrame:SetPoint("CENTER")
        chartFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        chartFrame:SetMovable(true)
        chartFrame:EnableMouse(true)
        chartFrame:EnableKeyboard(true)
        chartFrame:RegisterForDrag("LeftButton")
        chartFrame:SetScript("OnDragStart", chartFrame.StartMoving)
        chartFrame:SetScript("OnDragStop", chartFrame.StopMovingOrSizing)
        chartFrame:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32,
            edgeSize = 18,
            insets = { left = 6, right = 6, top = 6, bottom = 6 }
        })
        chartFrame:SetBackdropColor(0.10, 0.10, 0.13, 0.97)
        chartFrame:SetBackdropBorderColor(0.7, 0.6, 1, 1)
        EA_SkinChartFrame(chartFrame, "window")
        EA_RaiseChartFrame(chartFrame)
        local closeBtn = CreateFrame("Button", nil, chartFrame, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", chartFrame, "TOPRIGHT", -8, -8)
        closeBtn:SetSize(26, 26)
        EA_SkinChartCloseButton(closeBtn)
        closeBtn:SetScript("OnClick", function() chartFrame:Hide() end)
        tinsert(UISpecialFrames, "EasyAuction_ChartFrame")

        chartFrame.headerLine1 = chartFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        chartFrame.headerLine1:SetPoint("TOPLEFT", 18, -14)
        chartFrame.headerLine1:SetJustifyH("LEFT")
        EA_SkinChartText(chartFrame.headerLine1, "accent")

        chartFrame.headerLine2 = chartFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        chartFrame.headerLine2:SetPoint("TOPLEFT", chartFrame.headerLine1, "BOTTOMLEFT", 0, -8)
        chartFrame.headerLine2:SetJustifyH("LEFT")
        EA_SkinChartText(chartFrame.headerLine2, "text")

        local underline = chartFrame:CreateTexture(nil, "OVERLAY")
        local p = EA_Palette()
        underline:SetColorTexture(p.border[1], p.border[2], p.border[3], 0.55)
        underline:SetHeight(2)
        underline:SetPoint("TOPLEFT", 20, -64)
        underline:SetPoint("TOPRIGHT", -20, -64)

        chartFrame.headerRow1 = CreateFrame("Frame", nil, chartFrame)
        chartFrame.headerRow1:SetPoint("TOPLEFT", chartFrame.headerLine2, "BOTTOMLEFT", -15, -8)
        chartFrame.headerRow1:SetPoint("TOPRIGHT", chartFrame, "TOPRIGHT", -18, 0)
        chartFrame.headerRow1:SetHeight(20)

        chartFrame.headerRow2 = CreateFrame("Frame", nil, chartFrame)
        chartFrame.headerRow2:SetPoint("TOPLEFT", chartFrame.headerRow1, "BOTTOMLEFT", 0, -8)
        chartFrame.headerRow2:SetPoint("TOPRIGHT", chartFrame, "TOPRIGHT", -18, 0)
        chartFrame.headerRow2:SetHeight(20)

        local colWidths = {60, 100, 60, 100, 60, 100}
        local rowFrames = {chartFrame.headerRow1, chartFrame.headerRow2}
        for rowIndex, rowFrame in ipairs(rowFrames) do
            rowFrame.cols = {}
            for colIndex = 1, 6 do
                local col = CreateFrame("Frame", nil, rowFrame)
                if colIndex == 1 then
                    col:SetPoint("TOPLEFT", rowFrame, "TOPLEFT", 0, 0)
                else
                    col:SetPoint("TOPLEFT", rowFrame.cols[colIndex-1], "TOPRIGHT", 5, 0)
                end
                col:SetWidth(colWidths[colIndex])
                col:SetHeight(rowFrame:GetHeight())
                col.text = col:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                col.text:SetAllPoints(col)
                col.text:SetJustifyH("RIGHT")
                EA_SkinChartText(col.text, colIndex % 2 == 1 and "muted" or "text")
                rowFrame.cols[colIndex] = col
            end
        end

        chartFrame.pages = {}
        for i = 1, 2 do
            local page = CreateFrame("Frame", nil, chartFrame)
            page:SetPoint("TOPLEFT", chartFrame, "TOPLEFT", 5, -115)
            page:SetPoint("BOTTOMRIGHT", chartFrame, "BOTTOMRIGHT", -5, 8)
            page:Hide()
            chartFrame.pages[i] = page
        end

        chartFrame.tabs = {}
        local tabNames = {"日K线", "月K线"}
        local tabIcons = {
            "Interface\\Common\\UI-Searchbox-Icon",
            "Interface\\Common\\Calendar"
        }
        for i, name in ipairs(tabNames) do
            if not chartFrame.tabs[i] then
                local tab = CreateFrame("Button", nil, chartFrame)
                tab:SetID(i)
                tab:SetSize(80, 24)
                if i == 1 then
                    tab:SetPoint("TOPLEFT", chartFrame, "TOPLEFT", 10, -240)
                else
                    tab:SetPoint("LEFT", chartFrame.tabs[i-1], "RIGHT", 0, 0)
                end
                tab.icon = tab:CreateTexture(nil, "ARTWORK")
                tab.icon:SetTexture(tabIcons[i] or "Interface\\Common\\UI-Searchbox-Icon")
                tab.icon:SetSize(16, 16)
                tab.icon:SetPoint("LEFT", tab, "LEFT", 6, 0)
                tab.icon:SetAlpha(0)
                tab.icon:Hide()
                tab.text = tab:CreateFontString(nil, "ARTWORK", "GameFontNormal")
                tab.text:SetPoint("CENTER")
                tab.text:SetText(name)
                tab.text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 13, "")
                EA_SkinChartText(tab.text, "text")
                tab:SetNormalFontObject(GameFontNormal)
                if EAStyle then
                    tab:SetText(name)
                    EAStyle:SkinButton(tab)
                    tab.text = tab:GetFontString()
                    tab.text:SetPoint("CENTER")
                end
                tab:SetScript("OnClick", function(self)
                    for j, t in ipairs(chartFrame.tabs) do
                        if j == i then
                            t:Disable()
                            if EAStyle then EAStyle:SetButtonActive(t, true) end
                            chartFrame.pages[j]:Show()
                            local chartType = (j == 1) and "daily" or "monthly"
                            chartFrame.currentChartType = chartType
                            if chartFrame.UpdateTrendAnalysis then
                                chartFrame.UpdateTrendAnalysis(chartType)
                            end
                        else
                            t:Enable()
                            if EAStyle then EAStyle:SetButtonActive(t, false) end
                            chartFrame.pages[j]:Hide()
                        end
                    end
                end)
                chartFrame.tabs[i] = tab
            end
            chartFrame.tabs[i].text:SetText(name)
        end
        chartFrame.tabs[1]:Disable()
        if EAStyle then EAStyle:SetButtonActive(chartFrame.tabs[1], true) end
        chartFrame.pages[1]:Show()
        for i = 2, #chartFrame.tabs do
            chartFrame.tabs[i]:Enable()
            if EAStyle then EAStyle:SetButtonActive(chartFrame.tabs[i], false) end
            chartFrame.pages[i]:Hide()
        end
    end
    local f = chartFrame

    local latestPrice = points[30] or 0
    local today = days[30]

    local openPrice = 0
    local hourlyOpenRecords = EasyAuction_GetHourlyMinPrice and EasyAuction_GetHourlyMinPrice(itemName, EasyAuctionDB) or (EasyAuctionDB.HourlyMinPrice and EasyAuctionDB.HourlyMinPrice[itemName]) or {}
    if hourlyOpenRecords then
        for _, v in ipairs(hourlyOpenRecords) do
            local hourNum = tonumber(v[1])
            local price = v[2]
            local count = v[3]
            if hourNum and hourNum >= 0 and hourNum <= 23 and price and price > 0 and count and count > 0 then
                if v.t and date("%Y-%m-%d", v.t) == today then
                    openPrice = price
                    break
                elseif not v.t then
                    openPrice = price
                    break
                end
            end
        end
    end
    if openPrice == 0 then
        openPrice = points[29] or points[30] or 0
    end
    local todayDaily = findDailyByDate(today)
    local todayHigh = todayDaily and (todayDaily[5] or todayDaily[2] or 0) or 0
    local todayLow = todayDaily and (todayDaily[4] or todayDaily[2] or 0) or 0
    local todayTotalValue = todayDaily and ((todayDaily[6] or 0) * (todayDaily[2] or 0)) or 0

    local hist_max, hist_min = 0, nil
    for _, v in ipairs(dailyArray) do
        local current_max = v[5] or v[2]
        local current_min = v[4] or v[2]
        if current_max and current_max > 0 then
            if not hist_max or current_max > hist_max then hist_max = current_max end
        end
        if current_min and current_min > 0 then
            if not hist_min or current_min < hist_min then hist_min = current_min end
        end
    end
    local realName = tostring(itemName):match("^(.-):%d+$") or itemName

    local changePercent = 0
    if openPrice > 0 then
        changePercent = ((latestPrice - openPrice) / openPrice) * 100
    end

    local colorCode = "|cffff4040"
    if changePercent > 0 then
        colorCode = "|cff00ff00"
    end

    local percentText
    if changePercent >= 0 then
        percentText = string.format("+%.2f%%", changePercent)
    else
        percentText = string.format("%.2f%%", changePercent)
    end

    f.headerLine1:SetText(string.format("|cffffd700%s|r |cff888888(ID:%s)|r",realName, itemID))
    f.headerLine2:SetText(string.format("|cffff4040%s|r", FormatGold(latestPrice, 12)))
    f.headerLine2:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 24, "")

    if not f.percentText then
        f.percentText = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.percentText:SetPoint("LEFT", f.headerLine2, "RIGHT", 10, 0)
        f.percentText:SetJustifyH("LEFT")
    end
    f.percentText:SetText(string.format("%s%s|r", colorCode, percentText))
    f.percentText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 16, "")
    f.percentText:Show()

    f.headerRow1.cols[1].text:SetText("今开价：")
    f.headerRow1.cols[2].text:SetText(string.format("|cffa0a0a0%s|r", FormatGold(openPrice, 12)))
    f.headerRow1.cols[3].text:SetText("今最高价：")
    f.headerRow1.cols[4].text:SetText(string.format("|cff00c000%s|r", FormatGold(todayHigh, 12)))
    f.headerRow1.cols[5].text:SetText("历史最高：")
    f.headerRow1.cols[6].text:SetText(string.format("|cff00ff00%s|r", FormatGold(hist_max or 0, 12)))

    f.headerRow2.cols[1].text:SetText("总市值：")
    f.headerRow2.cols[2].text:SetText(string.format("|cff00c0ff%s|r", FormatGold(todayTotalValue, 12)))
    f.headerRow2.cols[3].text:SetText("今最低价：")
    f.headerRow2.cols[4].text:SetText(string.format("|cffff4040%s|r", FormatGold(todayLow, 12)))
    f.headerRow2.cols[5].text:SetText("历史最低：")
    f.headerRow2.cols[6].text:SetText(string.format("|cffff2020%s|r", FormatGold(hist_min or 0, 12)))

    f.headerLine1:Show()
    f.headerLine2:Show()

    if not chartFrame.underline2 then
        chartFrame.underline2 = chartFrame:CreateTexture(nil, "OVERLAY")
        chartFrame.underline2:SetHeight(1)
        chartFrame.underline2:SetPoint("TOPLEFT", 20, -122)
        chartFrame.underline2:SetPoint("TOPRIGHT", -20, -122)
    end
    do
        local p = EA_Palette()
        chartFrame.underline2:SetColorTexture(p.border[1], p.border[2], p.border[3], 0.55)
    end

    -- 小时图
    local hourPoints, hourCounts = {}, {}
    local nowDay = days[30]
    local tmpPrice = {}
    local tmpCount = {}
    for i = 0, 23 do
        tmpPrice[i] = 0
        tmpCount[i] = 0
    end

    local hasHourlyData = false
    local hourlyRecords = EasyAuction_GetHourlyMinPrice and EasyAuction_GetHourlyMinPrice(itemName, EasyAuctionDB) or (EasyAuctionDB.HourlyMinPrice and EasyAuctionDB.HourlyMinPrice[itemName]) or {}
    if hourlyRecords then
        for _, v in ipairs(hourlyRecords) do
            local hourNum = tonumber(v[1])
            if hourNum and hourNum >= 0 and hourNum <= 23 and v[2] and v[2] > 0 then
                tmpPrice[hourNum] = tmpPrice[hourNum] or 0
                tmpCount[hourNum] = tmpCount[hourNum] or 0

                if tmpPrice[hourNum] == 0 or v[2] < tmpPrice[hourNum] then
                    tmpPrice[hourNum] = v[2]
                end
                tmpCount[hourNum] = tmpCount[hourNum] + (v[4] or v[3] or 1)
                hasHourlyData = true
            end
        end
    end

    local historyRecords = EasyAuction_GetPriceHistory and EasyAuction_GetPriceHistory(itemName, EasyAuctionDB) or (EasyAuctionDB.PriceHistory and EasyAuctionDB.PriceHistory[itemName]) or {}
    if not hasHourlyData and historyRecords then
        for _, v in ipairs(historyRecords) do
            if v.t and date("%Y-%m-%d", v.t) == nowDay then
                local h = date("%H", v.t)
                local hourNum = tonumber(h)
                if hourNum and hourNum >=0 and hourNum <=23 and v.unit and v.unit >0 then
                    if tmpPrice[hourNum] ==0 or v.unit < tmpPrice[hourNum] then
                        tmpPrice[hourNum] = v.unit
                    end
                    tmpCount[hourNum] = tmpCount[hourNum] + (v.count or 1)
                end
            end
        end
    end

    for hourNum = 0, 23 do
        hourPoints[hourNum+1] = tmpPrice[hourNum] or 0
        hourCounts[hourNum+1] = tmpCount[hourNum] or 0
    end

    if not f.trendText then
        f.trendText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        f.trendText:SetPoint("BOTTOM", chartFrame.headerRow2, "BOTTOM", -15, -90)
        f.trendText:SetWidth(500)
        f.trendText:SetJustifyH("LEFT")
        EA_SkinChartText(f.trendText, "text")
    end

    local function UpdateTrendAnalysis(chartType)
        local dataPoints, trendStr, advices
        if chartType == "daily" then
            dataPoints = hourPoints or {}
        else
            dataPoints = points or {}
        end

        if not dataPoints or type(dataPoints) ~= "table" then
            dataPoints = {}
        end

        local validCount = 0
        local validPoints = {}
        for i = 1, #dataPoints do
            if dataPoints[i] > 0 then
                validCount = validCount + 1
                table.insert(validPoints, dataPoints[i])
            end
        end

        trendStr = ""
        advices = {}

        if validCount < 3 then
            trendStr = "暂无足够数据分析走势。"
            advices = {}
        else
            local first = validPoints[1]
            local last = validPoints[#validPoints]

            if first and last then
                local pct = (last - first) / first
                local upThreshold = (chartType == "daily") and 0.05 or 0.10
                local downThreshold = (chartType == "daily") and -0.05 or -0.10

                if pct > upThreshold then
                    trendStr = "|cff00ff00近期价格呈上涨趋势|r，"
                elseif pct < downThreshold then
                    trendStr = "|cffff2020近期价格呈下降趋势|r，"
                else
                    trendStr = "|cffffff00近期价格整体平稳|r，"
                end

                local minV, maxV = first, first
                for _, p in ipairs(validPoints) do
                    if p < minV then minV = p end
                    if p > maxV then maxV = p end
                end
                local volatility = (maxV - minV) / ((maxV + minV) / 2)
                if chartType == "daily" then
                    if volatility > 0.3 then
                        trendStr = trendStr .. "日内价格波动剧烈，需密切关注市场变化。"
                    elseif volatility > 0.15 then
                        trendStr = trendStr .. "日内价格波动较大，操作需谨慎。"
                    elseif volatility < 0.05 then
                        trendStr = trendStr .. "日内价格波澜不惊，市场交易清淡。"
                    else
                        trendStr = trendStr .. "日内价格波动适中。"
                    end
                else
                    if volatility > 0.5 then
                        trendStr = trendStr .. "区间极大，行情如过山车，需关注极端波动风险。"
                    elseif volatility > 0.25 then
                        trendStr = trendStr .. "价格波动较大，操作需谨慎。"
                    elseif volatility < 0.08 then
                        trendStr = trendStr .. "波澜不惊，主力可能蓄势待发。"
                    else
                        trendStr = trendStr .. "波动适中。"
                    end
                end
            else
                trendStr = "暂无足够数据分析走势。"
            end

            local ma_short, ma_long
            if chartType == "daily" then
                if #validPoints >= 4 then
                    local sum = 0
                    for i = math.max(1, #validPoints - 3), #validPoints do
                        sum = sum + validPoints[i]
                    end
                    ma_long = sum / 4
                end
                if #validPoints >= 2 then
                    local sum = 0
                    for i = #validPoints - 1, #validPoints do
                        sum = sum + validPoints[i]
                    end
                    ma_short = sum / 2
                end
            else
                if #validPoints >= 7 then
                    local sum = 0
                    for i = math.max(1, #validPoints - 6), #validPoints do
                        sum = sum + validPoints[i]
                    end
                    ma_long = sum / 7
                end
                if #validPoints >= 3 then
                    local sum = 0
                    for i = #validPoints - 2, #validPoints do
                        sum = sum + validPoints[i]
                    end
                    ma_short = sum / 3
                end
            end

            if ma_long and last then
                if chartType == "daily" then
                    if last > ma_long * 1.05 then
                        table.insert(advices, "|cff00ff00多头走强，日内短线有上涨动能，可关注买入机会。|r")
                    elseif last < ma_long * 0.95 then
                        table.insert(advices, "|cffff2020空头占优，日内短线或有下跌风险，需谨慎操作。|r")
                    elseif math.abs(last - ma_long) < ma_long * 0.02 then
                        table.insert(advices, "|cffffff00价格贴近均线，日内行情或面临方向选择。|r")
                    end
                else
                    if last > ma_long * 1.10 then
                        table.insert(advices, "|cff00ff00多头排列，强势上攻，短线有资金推动迹象。|r")
                    elseif last < ma_long * 0.90 then
                        table.insert(advices, "|cffff2020空头陷阱格局，短线仍需防范下行风险。|r")
                    elseif math.abs(last - ma_long) < ma_long * 0.03 then
                        table.insert(advices, "|cffffff00均线粘合，行情或将变盘，静待方向选择。|r")
                    end
                end
            end

            local up_count, down_count = 0, 0
            for i = 2, #validPoints do
                if validPoints[i] > validPoints[i - 1] then
                    up_count = up_count + 1
                    down_count = 0
                elseif validPoints[i] < validPoints[i - 1] then
                    down_count = down_count + 1
                    up_count = 0
                else
                    up_count = 0
                    down_count = 0
                end
            end

            if chartType == "daily" then
                if up_count >= 2 then
                    table.insert(advices, "连续数小时上涨，短线或有获利回吐，谨防追高。")
                elseif down_count >= 2 then
                    table.insert(advices, "连续数小时下跌，或有短期反弹机会，可关注抄底。")
                end
            else
                if up_count >= 3 then
                    table.insert(advices, "连续多日上涨，短线或有获利回吐压力，谨防追高。")
                elseif down_count >= 3 then
                    table.insert(advices, "连续下跌，疑似主力吸筹，短线可关注反弹机遇。")
                end
            end

            if last and #validPoints >= 5 then
                local minV, maxV
                minV, maxV = validPoints[1], validPoints[1]
                for _, p in ipairs(validPoints) do
                    if p < minV then minV = p end
                    if p > maxV then maxV = p end
                end
                if last == maxV and maxV > minV * (chartType == "daily" and 1.15 or 1.30) then
                    table.insert(advices, "|cffffd700刚突破近期新高，上涨动能增强，可适当关注。|r")
                elseif last == minV and maxV > minV * (chartType == "daily" and 1.15 or 1.30) then
                    table.insert(advices, "|cffff2020跌至新低，或有抄底资金介入，注意风险控制。|r")
                end
            end

            if #validPoints >= 5 then
                local recent_period = (chartType == "daily") and 4 or 9
                local recent_max, recent_min = 0, 1e10
                for i = math.max(1, #validPoints - recent_period), #validPoints do
                    local p = validPoints[i]
                    if p > recent_max then recent_max = p end
                    if p < recent_min then recent_min = p end
                end
                local btop = (last >= recent_max and recent_max > 0)
                local blow = (last <= recent_min and recent_min < 1e10)
                if chartType == "daily" then
                    if btop then table.insert(advices, "|cff00ff00价格突破近期小时高点，多头动能增强，关注短期表现。|r") end
                    if blow then table.insert(advices, "|cffff2020价格跌破近期小时低点，弱势明显，注意风险控制。|r") end
                else
                    if btop then table.insert(advices, "|cff00ff00价格突破近期高点，多头动能增强，关注强势表现。|r") end
                    if blow then table.insert(advices, "|cffff2020价格跌破近期低点，弱势明显，注意风险控制。|r") end
                end
            end

            if #advices == 0 then
                if chartType == "daily" then
                    table.insert(advices, "日内暂无明显趋势，建议观望为主。")
                else
                    table.insert(advices, "暂无明显主力信号，建议观望为主。")
                end
            end
        end

        local typeText = (chartType == "daily") and "|cffffff00日K线走势分析：\n|r" or "|cffffff00月K线走势分析：|r"
        f.trendText:SetText(typeText .. trendStr .. (#advices > 0 and "\n" .. table.concat(advices, "\n") or ""))
        f.trendText:Show()
    end

    f.UpdateTrendAnalysis = UpdateTrendAnalysis
    f.currentChartType = "daily"
    f.UpdateTrendAnalysis(f.currentChartType)

    -- 日K线
    local chartLeft, chartBottom = 60, 25
    local chartWidth, chartHeight = 480, 110
    local tab1 = f.pages[1]
    if not tab1.inited then
        tab1.yLabels, tab1.yLines, tab1.xLabels = {}, {}, {}
        tab1.lines, tab1.dots, tab1.dotFrames, tab1.barRects = {}, {}, {}, {}
        tab1.inited = true
    end
    local yMax = 1
    for i = 1, 24 do if hourPoints[i] > yMax then yMax = hourPoints[i] end end
    if yMax == 0 then yMax = 1 end
    for i = 0, 4 do
        local y = chartBottom + i * chartHeight / 4
        if not tab1.yLabels[i] then
            tab1.yLabels[i] = tab1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            tab1.yLabels[i]:SetJustifyH("RIGHT")
            tab1.yLabels[i]:SetWidth(50)
            EA_SkinChartText(tab1.yLabels[i], "muted")
        end
        tab1.yLabels[i]:SetPoint("RIGHT", tab1, "BOTTOMLEFT", chartLeft - 4, y)
        local goldValue = (yMax * i / 4) / 10000
        tab1.yLabels[i]:SetText(string.format("%.2f", goldValue))
        if not tab1.yLines[i] then
            tab1.yLines[i] = tab1:CreateTexture()
            tab1.yLines[i]:SetHeight(1)
        end
        do
            local p = EA_Palette()
            tab1.yLines[i]:SetColorTexture(p.border[1], p.border[2], p.border[3], 0.18)
        end
        tab1.yLines[i]:SetPoint("LEFT", tab1, "BOTTOMLEFT", chartLeft, y)
        tab1.yLines[i]:SetPoint("RIGHT", tab1, "BOTTOMLEFT", chartLeft + chartWidth, y)
        tab1.yLines[i]:Show()
    end

    for i = 1, 24 do
        if not tab1.xLabels[i] then
            tab1.xLabels[i] = tab1:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            tab1.xLabels[i]:SetWidth(23)
            tab1.xLabels[i]:SetJustifyH("CENTER")
            EA_SkinChartText(tab1.xLabels[i], "muted")
            local x = chartLeft + (i - 1) * chartWidth / 23
            tab1.xLabels[i]:SetPoint("BOTTOM", tab1, "BOTTOMLEFT", x, chartBottom - 18)
        end
        tab1.xLabels[i]:SetText(i)
    end

    local dotSize = 18
    for i = 1, 24 do
        if not tab1.dotFrames[i] then
            local frame = CreateFrame("Frame", nil, tab1)
            frame:SetSize(dotSize * 1.2, dotSize * 1.2)
            frame:SetFrameStrata("FULLSCREEN_DIALOG")
            frame:SetScript("OnEnter", function(self)
                local idx = self.idx
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.nowDay .. " " .. (idx-1) .. ":00 价格")
                local price = self.hourPoints[idx]
                if price and price > 0 then
                    GameTooltip:AddLine("|cffffd700最新价：|r" .. FormatGold(price))
                else
                    GameTooltip:AddLine("无数据")
                end
                GameTooltip:Show()
            end)
            frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
            tab1.dotFrames[i] = frame
        end

        local x = chartLeft + (i - 1) * chartWidth / 23
        local y = chartBottom + (hourPoints[i] / yMax) * chartHeight
        tab1.dotFrames[i]:SetPoint("CENTER", tab1, "BOTTOMLEFT", x, y)
        tab1.dotFrames[i].idx = i
        tab1.dotFrames[i].hourPoints = hourPoints
        tab1.dotFrames[i].nowDay = nowDay

        if not tab1.dots[i] then
            tab1.dots[i] = tab1.dotFrames[i]:CreateTexture()
            tab1.dots[i]:SetDrawLayer("ARTWORK", 3)
        end

        tab1.dots[i]:SetPoint("CENTER")
        if hourPoints[i] > 0 then
            local isLastValid = true
            for j = i + 1, 24 do
                if hourPoints[j] > 0 then
                    isLastValid = false
                    break
                end
            end
            if isLastValid then
                tab1.dots[i]:SetTexture("Interface\\COMMON\\Indicator-Green")
            else
                tab1.dots[i]:SetTexture("Interface\\COMMON\\Indicator-Yellow")
            end
            tab1.dots[i]:SetSize(dotSize, dotSize)
            tab1.dots[i]:Show()
            tab1.dotFrames[i]:Show()
        else
            tab1.dots[i]:Hide()
            tab1.dotFrames[i]:Hide()
        end
    end

    for i = 25, #tab1.dots do if tab1.dots[i] then tab1.dots[i]:Hide() end end
    for i = 25, #tab1.dotFrames do if tab1.dotFrames[i] then tab1.dotFrames[i]:Hide() end end

    local renderedByGraph = EA_RenderLineGraph(tab1, "daily", hourPoints, chartLeft, chartBottom, chartWidth, chartHeight, function(i)
        return i - 1
    end)
    local validIndices = {}
    for i = 1, 24 do if hourPoints[i] > 0 then table.insert(validIndices, i) end end
    local lineIdx = 1
    if not renderedByGraph then
        for k = 1, #validIndices - 1 do
            local i = validIndices[k]
            local j = validIndices[k + 1]
            local x1 = chartLeft + (i - 1) * chartWidth / 23
            local y1 = chartBottom + (hourPoints[i] / yMax) * chartHeight
            local x2 = chartLeft + (j - 1) * chartWidth / 23
            local y2 = chartBottom + (hourPoints[j] / yMax) * chartHeight

            if not tab1.lines[lineIdx] then
                tab1.lines[lineIdx] = tab1:CreateTexture()
                tab1.lines[lineIdx]:SetDrawLayer("ARTWORK", 2)
            end
            do
                local p = EA_Palette()
                tab1.lines[lineIdx]:SetColorTexture(p.accent[1], p.accent[2], p.accent[3], 1)
            end

            local dx, dy = x2 - x1, y2 - y1
            local len = math.sqrt(dx * dx + dy * dy)
            local angle = math.atan2(dy, dx)
            tab1.lines[lineIdx]:ClearAllPoints()
            tab1.lines[lineIdx]:SetPoint("CENTER", tab1, "BOTTOMLEFT", x1 + dx / 2, y1 + dy / 2)
            tab1.lines[lineIdx]:SetSize(len, 2)
            tab1.lines[lineIdx]:SetRotation(angle)
            tab1.lines[lineIdx]:Show()

            lineIdx = lineIdx + 1
        end
    end
    for i = lineIdx, #tab1.lines do if tab1.lines[i] then tab1.lines[i]:Hide() end end
    local maxCnt = 1
    for i = 1, 24 do if hourCounts[i] > maxCnt then maxCnt = hourCounts[i] end end
    local barBottom = chartBottom - 38
    local barHeight = 36
    local barWidth = math.floor(chartWidth / 28)
    for i = 1, 24 do
        if not tab1.barRects[i] then
            tab1.barRects[i] = tab1:CreateTexture(nil, "ARTWORK")
        end
        do
            local p = EA_Palette()
            tab1.barRects[i]:SetColorTexture(p.accent2[1], p.accent2[2], p.accent2[3], 0.42)
        end
        local x = chartLeft + (i - 1) * chartWidth / 23
        local h = (hourCounts[i] > 0 and (hourCounts[i] / maxCnt) * barHeight) or 0
        tab1.barRects[i]:ClearAllPoints()
        tab1.barRects[i]:SetPoint("BOTTOMLEFT", tab1, "BOTTOMLEFT", x - barWidth / 2, chartBottom)
        tab1.barRects[i]:SetSize(barWidth, h)
        tab1.barRects[i]:SetShown(hourCounts[i] > 0)
        if hourCounts[i] > 0 then
            tab1.barRects[i]:EnableMouse(true)
            tab1.barRects[i].hourCounts = hourCounts
            tab1.barRects[i].hourPoints = hourPoints
            tab1.barRects[i].nowDay = nowDay
            tab1.barRects[i].i = i
            tab1.barRects[i]:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.nowDay .. " " .. (self.i-1) .. ":00")
                GameTooltip:AddLine("|cff00bfff在售数：|r" .. self.hourCounts[self.i])
                local price = self.hourPoints[self.i]
                if price and price > 0 then
                    GameTooltip:AddLine("|cffffd700最新价：|r" .. FormatGold(price))
                else
                    GameTooltip:AddLine("无价格数据")
                end
                GameTooltip:Show()
            end)
            tab1.barRects[i]:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
        else
            tab1.barRects[i]:EnableMouse(false)
            tab1.barRects[i]:SetScript("OnEnter", nil)
            tab1.barRects[i]:SetScript("OnLeave", nil)
        end
    end
    for i = 25, #tab1.barRects do if tab1.barRects[i] then tab1.barRects[i]:Hide() end end

    local tab2 = f.pages[2]
    if not tab2.inited then
        tab2.chart = CreateFrame("Frame", nil, tab2)
        tab2.chart:SetAllPoints(tab2)
        tab2.inited = true
    end

    EasyAuction_Draw30DChart(tab2.chart, points, countPoints, totalCountPoints, days)
    tab2.chart:Show()

    f:Show()
end

function EasyAuction_Draw30DChart(parent, points, countPoints, totalCountPoints, days)
    local chartLeft, chartBottom = 60, 25
    local chartWidth, chartHeight = 480, 110
    local dayWidth = chartWidth / 30
    local weekdayNames = {"星期日", "星期一", "星期二", "星期三", "星期四", "星期五", "星期六"}
    local weekdayShortNames = {"日", "一", "二", "三", "四", "五", "六"}
    local weekdayColors = {
        {0.46, 0.24, 0.24, 0.16},
        {0.18, 0.30, 0.42, 0.14},
        {0.18, 0.36, 0.30, 0.14},
        {0.38, 0.32, 0.18, 0.14},
        {0.30, 0.24, 0.42, 0.14},
        {0.20, 0.36, 0.42, 0.14},
        {0.44, 0.28, 0.18, 0.16},
    }
    parent.yLabels = parent.yLabels or {}
    parent.yLines = parent.yLines or {}
    parent.xLabels = parent.xLabels or {}
    parent.lines = parent.lines or {}
    parent.dots = parent.dots or {}
    parent.dotFrames = parent.dotFrames or {}
    parent.barRects = parent.barRects or {}
    parent.weekdayBgs = parent.weekdayBgs or {}
    parent.weekdayLabels = parent.weekdayLabels or {}
    local weekdayIndexes, axisDates = {}, {}

    local function GetDayX(index)
        return chartLeft + (index - 0.5) * dayWidth
    end

    local function GetWeekdayIndex(dayText)
        if not dayText then return 1 end
        local year, month, day = dayText:match("^(%d+)%-(%d+)%-(%d+)$")
        if not year then return 1 end
        local stamp = time({ year = tonumber(year), month = tonumber(month), day = tonumber(day) })
        if not stamp then return 1 end
        return (tonumber(date("%w", stamp)) or 0) + 1
    end

    local function FormatAxisDate(dayText)
        local month, day = tostring(dayText or ""):match("^%d%d%d%d%-(%d+)%-(%d+)$")
        if not month then return "" end
        return string.format("%d/%d", tonumber(month) or 0, tonumber(day) or 0)
    end

    local max = 1
    for _, v in ipairs(points) do if v > max then max = v end end
    for i = 1, 30 do
        weekdayIndexes[i] = GetWeekdayIndex(days[i])
        axisDates[i] = FormatAxisDate(days[i])
        local weekdayIndex = weekdayIndexes[i]
        local color = weekdayColors[weekdayIndex] or weekdayColors[1]
        if not parent.weekdayBgs[i] then
            parent.weekdayBgs[i] = parent:CreateTexture(nil, "BACKGROUND")
            parent.weekdayBgs[i]:SetDrawLayer("BACKGROUND", 0)
        end
        parent.weekdayBgs[i]:ClearAllPoints()
        parent.weekdayBgs[i]:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", chartLeft + (i - 1) * dayWidth, chartBottom)
        parent.weekdayBgs[i]:SetSize(dayWidth, chartHeight)
        parent.weekdayBgs[i]:SetColorTexture(color[1], color[2], color[3], color[4])
        parent.weekdayBgs[i]:Show()

        if not parent.weekdayLabels[i] then
            parent.weekdayLabels[i] = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            parent.weekdayLabels[i]:SetJustifyH("CENTER")
            EA_SkinChartText(parent.weekdayLabels[i], "muted")
        end
        parent.weekdayLabels[i]:ClearAllPoints()
        parent.weekdayLabels[i]:SetWidth(dayWidth)
        parent.weekdayLabels[i]:SetPoint("BOTTOM", parent, "BOTTOMLEFT", GetDayX(i), chartBottom + chartHeight + 2)
        parent.weekdayLabels[i]:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 8, "")
        parent.weekdayLabels[i]:SetText(weekdayShortNames[weekdayIndex] or "")
        parent.weekdayLabels[i]:Show()
    end
    for i = 31, #parent.weekdayBgs do if parent.weekdayBgs[i] then parent.weekdayBgs[i]:Hide() end end
    for i = 31, #parent.weekdayLabels do if parent.weekdayLabels[i] then parent.weekdayLabels[i]:Hide() end end

    for i = 0, 4 do
        local y = chartBottom + i * chartHeight / 4
        if not parent.yLabels[i] then
            parent.yLabels[i] = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            parent.yLabels[i]:SetJustifyH("RIGHT")
            parent.yLabels[i]:SetWidth(50)
            EA_SkinChartText(parent.yLabels[i], "muted")
        end
        parent.yLabels[i]:SetPoint("RIGHT", parent, "BOTTOMLEFT", chartLeft - 4, y)
        local goldValue = (max * i / 4) / 10000
        parent.yLabels[i]:SetText(string.format("%.2f", goldValue))
        if not parent.yLines[i] then
            parent.yLines[i] = parent:CreateTexture()
            parent.yLines[i]:SetHeight(1)
        end
        do
            local p = EA_Palette()
            parent.yLines[i]:SetColorTexture(p.border[1], p.border[2], p.border[3], 0.18)
        end
        parent.yLines[i]:SetPoint("LEFT", parent, "BOTTOMLEFT", chartLeft, y)
        parent.yLines[i]:SetPoint("RIGHT", parent, "BOTTOMLEFT", chartLeft + chartWidth, y)
        parent.yLines[i]:Show()
    end

    for i = 1, 30 do
        if not parent.xLabels[i] then
            parent.xLabels[i] = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            parent.xLabels[i]:SetJustifyH("CENTER")
            EA_SkinChartText(parent.xLabels[i], "muted")
        end
        local x = GetDayX(i)
        parent.xLabels[i]:ClearAllPoints()
        parent.xLabels[i]:SetWidth(46)
        parent.xLabels[i]:SetPoint("BOTTOM", parent, "BOTTOMLEFT", x, chartBottom - 18)
        local d = axisDates[i]
        if i == 1 or i == 8 or i == 15 or i == 22 or i == 30 then
            parent.xLabels[i]:SetText(d)
        else
            parent.xLabels[i]:SetText("")
        end
    end

    local validIndices = {}
    for i = 1, 30 do
        if points[i] > 0 then
            table.insert(validIndices, i)
        end
    end
    local lineIdx = 1
    local renderedByGraph = EA_RenderLineGraph(parent, "monthly", points, chartLeft, chartBottom, chartWidth, chartHeight, function(i)
        return i - 1
    end)
    if not renderedByGraph then
        for k = 1, #validIndices - 1 do
            local i = validIndices[k]
            local j = validIndices[k + 1]
            local x1 = GetDayX(i)
            local y1 = chartBottom + (points[i] / max) * chartHeight
            local x2 = GetDayX(j)
            local y2 = chartBottom + (points[j] / max) * chartHeight
            if not parent.lines[lineIdx] then
                parent.lines[lineIdx] = parent:CreateTexture()
                parent.lines[lineIdx]:SetDrawLayer("ARTWORK", 2)
            end
            do
                local p = EA_Palette()
                parent.lines[lineIdx]:SetColorTexture(p.accent[1], p.accent[2], p.accent[3], 1)
            end
            local dx, dy = x2 - x1, y2 - y1
            local len = math.sqrt(dx * dx + dy * dy)
            local angle = math.atan2(dy, dx)
            parent.lines[lineIdx]:ClearAllPoints()
            parent.lines[lineIdx]:SetPoint("CENTER", parent, "BOTTOMLEFT", x1 + dx / 2, y1 + dy / 2)
            parent.lines[lineIdx]:SetSize(len, 2)
            parent.lines[lineIdx]:SetRotation(angle)
            parent.lines[lineIdx]:Show()
            lineIdx = lineIdx + 1
        end
    end
    for i = lineIdx, #parent.lines do if parent.lines[i] then parent.lines[i]:Hide() end end

    local dotSize = 18
    for i = 1, 30 do
        if not parent.dotFrames[i] then
            local frame = CreateFrame("Frame", nil, parent)
            frame:SetSize(dotSize * 1.2, dotSize * 1.2)
            frame:SetFrameStrata("FULLSCREEN_DIALOG")
            frame:SetScript("OnEnter", function(self)
                local idx = self.idx
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.days[idx] .. " " .. (self.weekdayNames[self.weekdayIndex] or "") .. " 价格")
                local price = self.points[idx]
                if price and price > 0 then
                    GameTooltip:AddLine("|cffffd700最新价：|r" .. FormatGold(price))
                else
                    GameTooltip:AddLine("无数据")
                end
                GameTooltip:Show()
            end)
            frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
            parent.dotFrames[i] = frame
        end
        local x = GetDayX(i)
        local y = chartBottom + (points[i] / max) * chartHeight
        parent.dotFrames[i]:SetPoint("CENTER", parent, "BOTTOMLEFT", x, y)
        parent.dotFrames[i].idx = i
        parent.dotFrames[i].points = points
        parent.dotFrames[i].days = days
        parent.dotFrames[i].weekdayIndex = weekdayIndexes[i]
        parent.dotFrames[i].weekdayNames = weekdayNames
        if points[i] > 0 then parent.dotFrames[i]:Show() else parent.dotFrames[i]:Hide() end

        if not parent.dots[i] then
            parent.dots[i] = parent.dotFrames[i]:CreateTexture()
            parent.dots[i]:SetDrawLayer("ARTWORK", 3)
        end
        parent.dots[i]:SetPoint("CENTER")
        if points[i] > 0 then
            if i == 30 then
                parent.dots[i]:SetTexture("Interface\\COMMON\\Indicator-Green")
            else
                parent.dots[i]:SetTexture("Interface\\COMMON\\Indicator-Yellow")
            end
            parent.dots[i]:SetSize(dotSize, dotSize)
            parent.dots[i]:Show()
        else
            parent.dots[i]:Hide()
        end
    end
    for i = 31, #parent.dotFrames do if parent.dotFrames[i] then parent.dotFrames[i]:Hide() end end
    for i = 31, #parent.dots do if parent.dots[i] then parent.dots[i]:Hide() end end

    local maxTotalCount = 0
    for _, v in ipairs(totalCountPoints) do if v > maxTotalCount then maxTotalCount = v end end
    if maxTotalCount == 0 then maxTotalCount = 1 end
    local barHeight = 36
    local barWidth = math.floor(chartWidth / 32)
    for i = 1, 30 do
        if not parent.barRects[i] then
            parent.barRects[i] = parent:CreateTexture(nil, "ARTWORK")
        end
        do
            local p = EA_Palette()
            parent.barRects[i]:SetColorTexture(p.accent2[1], p.accent2[2], p.accent2[3], 0.42)
        end
        local x = GetDayX(i)
        local h = (totalCountPoints[i] > 0 and (totalCountPoints[i] / maxTotalCount) * barHeight) or 0
        parent.barRects[i]:ClearAllPoints()
        parent.barRects[i]:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", x - barWidth / 2, chartBottom)
        parent.barRects[i]:SetSize(barWidth, h)
        parent.barRects[i]:SetShown(totalCountPoints[i] > 0)
        if totalCountPoints[i] > 0 then
            parent.barRects[i]:EnableMouse(true)
            parent.barRects[i].totalCountPoints = totalCountPoints
            parent.barRects[i].points = points
            parent.barRects[i].days = days
            parent.barRects[i].weekdayIndex = weekdayIndexes[i]
            parent.barRects[i].weekdayNames = weekdayNames
            parent.barRects[i].i = i
            parent.barRects[i]:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.days[self.i] .. " " .. (self.weekdayNames[self.weekdayIndex] or ""))
                GameTooltip:AddLine("|cff00bfff在售数：|r" .. self.totalCountPoints[self.i])
                local price = self.points[self.i]
                if price and price > 0 then
                    GameTooltip:AddLine("|cffffd700最新价：|r" .. FormatGold(price))
                else
                    GameTooltip:AddLine("无价格数据")
                end
                GameTooltip:Show()
            end)
            parent.barRects[i]:SetScript("OnLeave", function(self) GameTooltip:Hide() end)
        else
            parent.barRects[i]:EnableMouse(false)
            parent.barRects[i]:SetScript("OnEnter", nil)
            parent.barRects[i]:SetScript("OnLeave", nil)
        end
    end
    for i = 31, #parent.barRects do if parent.barRects[i] then parent.barRects[i]:Hide() end end
end

function FormatGold(copper, size)
    size = size or 12
    copper = copper or 0
    local totalGold = copper / 10000
    local iconStr = ":" .. size .. ":" .. size .. ":2:0"
    local str = ""

    local formatted
    if totalGold < 1 and totalGold > 0 then
        -- 小于1金，保留4位小数
        formatted = string.format("%.4f", totalGold)
        formatted = formatted:gsub("^0(%.)", "0%1") -- 保证是0.xxxx
    else
        -- 1金及以上，保留2位小数
        formatted = string.format("%.2f", totalGold)
        formatted = formatted:gsub("%.?0*$", "") -- 去掉末尾多余0
    end

    if formatted == "" or formatted == "." then
        formatted = "0"
    end
    str = formatted .. "|TInterface\\MoneyFrame\\UI-GoldIcon" .. iconStr .. "|t"
    return str
end

-- TokenTrend 风格价格走势窗口：复用原有价格数据，只重建图表、统计、历史三个视图。
local EA_CHART_MA7_COLOR = { 0.98, 0.72, 0.18, 1 }
local EA_CHART_MA30_COLOR = { 0.58, 0.64, 0.72, 1 }
local EA_CHART_ROWS = 12
local EA_CHART_DAY = 86400
local EA_CHART_HOUR = 3600
local EA_CHART_WEEKDAYS = { "周日", "周一", "周二", "周三", "周四", "周五", "周六" }

local function EA_SetChartTooltip(frame, title, body, anchor)
    if not frame then return end
    if EAStyle and EAStyle.SetTooltip then
        EAStyle:SetTooltip(frame, title, body, anchor or "ANCHOR_TOP")
        return
    end
    frame.__EAChartTipTitle = title
    frame.__EAChartTipBody = body
    frame.__EAChartTipAnchor = anchor or "ANCHOR_TOP"
    if frame.__EAChartTipHooked then return end
    frame.__EAChartTipHooked = true
    frame:HookScript("OnEnter", function(owner)
        if not owner.__EAChartTipTitle then return end
        GameTooltip:SetOwner(owner, owner.__EAChartTipAnchor)
        GameTooltip:AddLine(owner.__EAChartTipTitle)
        if owner.__EAChartTipBody then
            GameTooltip:AddLine(owner.__EAChartTipBody, 0.7, 0.7, 0.7, true)
        end
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function EA_ChartStyleButton(button)
    if EAStyle then
        EAStyle:SkinButton(button)
    end
    return button
end

local function EA_ChartSetActive(button, active)
    if EAStyle then
        EAStyle:SetButtonActive(button, active)
    elseif button and button:GetFontString() then
        button:GetFontString():SetTextColor(active and 0 or 1, active and 1 or 0.82, active and 1 or 0)
    end
end

local function EA_ChartText(parent, size, role)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(EAStyle and EAStyle.Font or STANDARD_TEXT_FONT, size or 12, "")
    fs:SetShadowOffset(1, -1)
    EA_SkinChartText(fs, role or "text")
    return fs
end

local function EA_DateToTime(day)
    local y, m, d = tostring(day or ""):match("(%d+)-(%d+)-(%d+)")
    if not y then return 0 end
    return time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 0 })
end

local function EA_FormatShortDate(t)
    return date("%m/%d", tonumber(t) or 0)
end

local function EA_FormatShortDateHour(t)
    return date("%m/%d %H:00", tonumber(t) or 0)
end

local function EA_FormatPct(v)
    if not v then return "-" end
    return string.format("%+.1f%%", v)
end

local function EA_FormatMarketCount(count)
    count = math.floor((tonumber(count) or 0) + 0.5)
    if count >= 10000 then
        return string.format("%.1f万", count / 10000)
    end
    return tostring(count)
end

local function EA_BuildChartSamples(dailyArray)
    local samples = {}
    for _, v in ipairs(dailyArray or {}) do
        local price = tonumber(v[2]) or 0
        if v[1] and price > 0 then
            samples[#samples + 1] = {
                day = v[1],
                t = EA_DateToTime(v[1]),
                close = price,
                open = price,
                high = price,
                low = price,
                count = tonumber(v[6]) or 0,
            }
        end
    end
    table.sort(samples, function(a, b) return a.day < b.day end)
    for i = 1, #samples do
        if i > 1 then
            samples[i].open = samples[i - 1].close
            samples[i].high = math.max(samples[i].open, samples[i].close)
            samples[i].low = math.min(samples[i].open, samples[i].close)
        end
        samples[i].idx = i
        local sum7, n7, sum30, n30 = 0, 0, 0, 0
        for j = math.max(1, i - 6), i do
            sum7 = sum7 + samples[j].close
            n7 = n7 + 1
        end
        for j = math.max(1, i - 29), i do
            sum30 = sum30 + samples[j].close
            n30 = n30 + 1
        end
        samples[i].ma7 = n7 > 0 and (sum7 / n7) or nil
        samples[i].ma30 = n30 > 0 and (sum30 / n30) or nil
    end
    return samples
end

local function EA_BuildRawChartPoints(db, itemName, dailySamples)
    local points = {}
    local history = EasyAuction_GetPriceHistory and EasyAuction_GetPriceHistory(itemName, db) or (db and db.PriceHistory and db.PriceHistory[itemName])
    if type(history) == "table" then
        for _, rec in ipairs(history) do
            local t = tonumber(rec.t)
            local p = tonumber(rec.unit or rec.price or rec[2])
            if t and p and p > 0 then
                points[#points + 1] = { t = t, p = p, count = tonumber(rec.count or rec[3]) or 0 }
            end
        end
    end
    table.sort(points, function(a, b) return a.t < b.t end)
    if #points > 0 then
        return points
    end
    for _, sample in ipairs(dailySamples or {}) do
        points[#points + 1] = { t = sample.t + 12 * EA_CHART_HOUR, p = sample.close, count = sample.count or 0 }
    end
    return points
end

local function EA_FilterRawPoints(points, rangeDays)
    if not points or #points == 0 then return 1, 0 end
    if not rangeDays or rangeDays <= 0 then return 1, #points end
    local cutoff = points[#points].t - rangeDays * EA_CHART_DAY
    for i = 1, #points do
        if points[i].t >= cutoff then
            return i, #points
        end
    end
    return #points, #points
end

local function EA_FilterSamples(samples, rangeDays)
    if rangeDays == 0 or #samples == 0 then
        return 1, #samples
    end
    local cutoff = samples[#samples].t - rangeDays * 86400
    local first = #samples
    for i = 1, #samples do
        if samples[i].t >= cutoff then
            first = i
            break
        end
    end
    return first, #samples
end

local function EA_BucketStart(t, group)
    if group == "hour" then
        return math.floor(t / EA_CHART_HOUR) * EA_CHART_HOUR
    end
    local dt = date("*t", t)
    dt.hour, dt.min, dt.sec = 0, 0, 0
    return time(dt)
end

local function EA_BuildHourlyCandlesFromBuckets(state, rangeDays)
    local db = state and state.db
    local itemName = state and state.itemName
    local hourly = EasyAuction_GetHourlyMinPrice and EasyAuction_GetHourlyMinPrice(itemName, db) or (db and db.HourlyMinPrice and db.HourlyMinPrice[itemName])
    if type(hourly) ~= "table" or #hourly == 0 then
        return nil
    end

    local rawPoints = state.rawPoints or {}
    local history = EasyAuction_GetPriceHistory and EasyAuction_GetPriceHistory(itemName, db) or (db and db.PriceHistory and db.PriceHistory[itemName])
    local anchorT = tonumber(history and history.lastScanT)
        or (rawPoints[#rawPoints] and rawPoints[#rawPoints].t)
        or time()
    local anchorDay = EA_BucketStart(anchorT, "day")
    local anchorHour = tonumber(date("%H", anchorT)) or tonumber(date("%H")) or 0
    local cutoff = rangeDays and rangeDays > 0 and (anchorT - rangeDays * EA_CHART_DAY) or nil
    local candles = {}

    for _, rec in ipairs(hourly) do
        local hour = tonumber(rec[1])
        local price = tonumber(rec[2])
        if hour and hour >= 0 and hour <= 23 and price and price > 0 then
            local t = tonumber(rec[5])
            if not t then
                t = anchorDay + hour * EA_CHART_HOUR
                if hour > anchorHour then
                    t = t - EA_CHART_DAY
                end
            end
            if (not cutoff or t >= cutoff) and t <= anchorT + EA_CHART_HOUR then
                candles[#candles + 1] = {
                    t = t,
                    o = price,
                    h = price,
                    l = price,
                    c = price,
                    n = tonumber(rec[4] or rec[3]) or 0,
                }
            end
        end
    end

    table.sort(candles, function(a, b) return a.t < b.t end)
    for i = 2, #candles do
        candles[i].o = candles[i - 1].c
        if candles[i].o > candles[i].h then
            candles[i].h = candles[i].o
        end
        if candles[i].o < candles[i].l then
            candles[i].l = candles[i].o
        end
    end
    return candles
end

local function EA_BuildCandles(frame, group, rangeDays)
    local state = frame and frame.EAState
    local candles = {}
    if not state then return candles end

    if group == "day" then
        local samples = state.samples or {}
        local first, last = EA_FilterSamples(samples, rangeDays or 0)
        for i = first, last do
            local s = samples[i]
            candles[#candles + 1] = {
                t = s.t,
                o = s.open or s.close,
                h = s.high or s.close,
                l = s.low or s.close,
                c = s.close,
                n = s.count or 0,
            }
        end
        return candles
    end

    local bucketCandles = EA_BuildHourlyCandlesFromBuckets(state, rangeDays or 0)
    if bucketCandles and #bucketCandles > 0 then
        return bucketCandles
    end

    local points = state.rawPoints or {}
    local lo, hi = EA_FilterRawPoints(points, rangeDays or 0)
    local cur
    for i = lo, hi do
        local pt = points[i]
        if pt and pt.p and pt.p > 0 then
            local bucket = EA_BucketStart(pt.t, "hour")
            if not cur or cur.t ~= bucket then
                cur = { t = bucket, o = pt.p, h = pt.p, l = pt.p, c = pt.p, n = pt.count or 1 }
                candles[#candles + 1] = cur
            else
                if pt.p > cur.h then cur.h = pt.p end
                if pt.p < cur.l then cur.l = pt.p end
                cur.c = pt.p
                cur.n = (cur.n or 0) + (pt.count or 1)
            end
        end
    end

    if #candles == 0 and state.db and state.itemName and state.samples and #state.samples > 0 then
        local lastDay = state.samples[#state.samples].day
        local dayStart = EA_DateToTime(lastDay)
        local hourly = EasyAuction_GetHourlyMinPrice and EasyAuction_GetHourlyMinPrice(state.itemName, state.db) or (state.db.HourlyMinPrice and state.db.HourlyMinPrice[state.itemName])
        for _, rec in ipairs(hourly or {}) do
            local hour = tonumber(rec[1])
            local p = tonumber(rec[2])
            if hour and hour >= 0 and hour <= 23 and p and p > 0 then
                candles[#candles + 1] = { t = dayStart + hour * EA_CHART_HOUR, o = p, h = p, l = p, c = p, n = tonumber(rec[4] or rec[3]) or 0 }
            end
        end
        table.sort(candles, function(a, b) return a.t < b.t end)
    end
    return candles
end

local function EA_IsBuySignal(samples)
    if not samples or #samples == 0 then return false end
    local current = samples[#samples].close
    local first = math.max(1, #samples - 29)
    local low30
    for i = first, #samples do
        local v = samples[i].close
        low30 = low30 and math.min(low30, v) or v
    end
    return low30 and current <= low30 * 1.02, low30
end

local function EA_ChartStats(samples)
    local s = { samples = #samples }
    if #samples == 0 then return s end
    local last = samples[#samples]
    local prev = samples[#samples - 1]
    s.current = last.close
    s.prevClose = prev and prev.close or nil
    s.changeAbs = prev and (last.close - prev.close) or 0
    s.changePct = (prev and prev.close and prev.close > 0) and (s.changeAbs / prev.close * 100) or 0
    s.since = samples[1].day
    s.dayRange = last.low and last.high and (FormatGold(last.low, 10) .. " - " .. FormatGold(last.high, 10)) or nil
    local function rangeStats(days)
        local first = math.max(1, #samples - days + 1)
        local lo, hi, sum, n
        for i = first, #samples do
            local v = samples[i].close
            lo = lo and math.min(lo, v) or v
            hi = hi and math.max(hi, v) or v
            sum = (sum or 0) + v
            n = (n or 0) + 1
        end
        return lo, hi, (n and n > 0) and (sum / n) or nil, n or 0
    end
    s.low7, s.high7, s.avg7 = rangeStats(7)
    s.low30, s.high30, s.avg30, s.count30 = rangeStats(30)
    s.lowAll, s.highAll, s.avgAll = rangeStats(#samples)
    return s
end

local function EA_AverageByBucket(points, bucketCount, keyFn)
    local sums, counts = {}, {}
    for i = 0, bucketCount - 1 do
        sums[i], counts[i] = 0, 0
    end
    for _, pt in ipairs(points or {}) do
        local key = keyFn(pt.t)
        if key and sums[key] then
            sums[key] = sums[key] + pt.p
            counts[key] = counts[key] + 1
        end
    end
    local out = {}
    for i = 0, bucketCount - 1 do
        out[i] = counts[i] > 0 and (sums[i] / counts[i]) or nil
    end
    return out
end

local function EA_AverageHoursFromHourlyMin(state)
    local db = state and state.db
    local hourly = EasyAuction_GetHourlyMinPrice and EasyAuction_GetHourlyMinPrice(state.itemName, db) or (db and db.HourlyMinPrice and db.HourlyMinPrice[state.itemName])
    if type(hourly) ~= "table" then return nil, 0 end
    local out, count = {}, 0
    for _, rec in ipairs(hourly) do
        local hour = tonumber(rec[1])
        local price = tonumber(rec[2])
        if hour and hour >= 0 and hour <= 23 and price and price > 0 then
            out[hour] = price
            count = count + 1
        end
    end
    return out, count
end

local function EA_AverageWeekdaysFromDailyMin(state)
    local db = state and state.db
    local daily = EasyAuction_GetDailyMinPrice and EasyAuction_GetDailyMinPrice(state.itemName, db) or (db and db.DailyMinPrice and db.DailyMinPrice[state.itemName])
    if type(daily) ~= "table" then return nil, 0 end
    local sums, counts = {}, {}
    for i = 0, 6 do
        sums[i], counts[i] = 0, 0
    end
    for _, rec in ipairs(daily) do
        local day = rec and rec[1]
        local price = tonumber(rec and rec[2])
        local t = day and EA_DateToTime(day)
        if t and t > 0 and price and price > 0 then
            local weekday = date("*t", t).wday - 1
            sums[weekday] = sums[weekday] + price
            counts[weekday] = counts[weekday] + 1
        end
    end
    local out, count = {}, 0
    for i = 0, 6 do
        if counts[i] > 0 then
            out[i] = sums[i] / counts[i]
            count = count + 1
        end
    end
    return out, count
end

local function EA_HeatColor(frac)
    local bull = EAStyle and EAStyle.Bull or { 0.13, 0.77, 0.37 }
    local bear = EAStyle and EAStyle.Bear or { 0.94, 0.27, 0.27 }
    return bear[1] * frac + bull[1] * (1 - frac),
        bear[2] * frac + bull[2] * (1 - frac),
        bear[3] * frac + bull[3] * (1 - frac)
end

local function EA_UpdateHeatStrip(container, cells, values, labels)
    if not container or not cells then return false end
    local w = container:GetWidth()
    if w <= 0 then return false end
    local n = #cells
    local cellW = w / n
    local lo, hi
    for i = 0, n - 1 do
        local v = values and values[i]
        if v then
            lo = lo and math.min(lo, v) or v
            hi = hi and math.max(hi, v) or v
        end
    end
    local span = (lo and hi and hi > lo) and (hi - lo) or 1
    local p = EA_Palette()
    for i = 0, n - 1 do
        local cell = cells[i + 1]
        cell:ClearAllPoints()
        cell:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", i * cellW + 1, 14)
        cell:SetSize(math.max(cellW - 2, 1), math.max(container:GetHeight() - 16, 1))
        local v = values and values[i]
        if v then
            local r, g, b = EA_HeatColor((v - lo) / span)
            cell.bg:SetColorTexture(r, g, b, 0.85)
            cell.value = v
        else
            cell.bg:SetColorTexture(p.border[1], p.border[2], p.border[3], 0.18)
            cell.value = nil
        end
        cell.tip = labels and labels[i + 1] or ""
    end
    return true
end

local function EA_LayoutStatsTicks(page)
    if not page or not page.weekStrip or not page.hourStrip then return end
    local w = page.weekStrip:GetWidth()
    if w > 0 and page.weekTicks then
        local cw = w / 7
        for i = 1, 7 do
            page.weekTicks[i]:ClearAllPoints()
            page.weekTicks[i]:SetPoint("TOP", page.weekStrip, "BOTTOMLEFT", (i - 0.5) * cw, -2)
        end
    end
    local hw = page.hourStrip:GetWidth()
    if hw > 0 and page.hourTicks then
        local hcw = hw / 24
        for _, t in ipairs(page.hourTicks) do
            t.font:ClearAllPoints()
            t.font:SetPoint("TOP", page.hourStrip, "BOTTOMLEFT", (t.hour + 0.5) * hcw, -2)
        end
    end
end

local function EA_BestBucket(values, count)
    local bestIdx, bestValue
    for i = 0, count - 1 do
        local v = values and values[i]
        if v and (not bestValue or v < bestValue) then
            bestIdx, bestValue = i, v
        end
    end
    return bestIdx, bestValue
end

local function EA_RangeVerdict(low, high, current, sampleCount)
    if not (low and high and current) then
        return nil
    end
    local prefix = (sampleCount and sampleCount > 0 and sampleCount < 7) and string.format("样本仅%d天，", sampleCount) or ""
    if high <= low then
        return prefix .. "30日记录价格暂无波动。", "text"
    end
    if current <= low * 1.001 then
        return prefix .. "当前处于30日低点附近。", "bull"
    end
    if current >= high * 0.999 then
        return prefix .. "当前处于30日高点附近。", "bear"
    end
    local frac = (current - low) / (high - low)
    local label, role
    if frac <= 0.25 then
        label, role = "偏低", "bull"
    elseif frac >= 0.75 then
        label, role = "偏高", "bear"
    else
        label, role = "合理", "text"
    end
    local pct = low > 0 and ((current - low) / low * 100) or 0
    return string.format("%s%s：高于30日低点 %.1f%%", prefix, label, pct), role
end

local function EA_FormatChartHeaderGold(copper)
    copper = tonumber(copper) or 0
    local sign = ""
    if copper < 0 then
        sign = "-"
        copper = -copper
    end
    return sign .. string.format("%.4f", copper / 10000) .. "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:1:0|t"
end

local function EA_PositionChartHeaderArrow(frame, current)
    if not (frame and frame.headerArrow and frame.headerPrice) then return end
    local goldText = string.format("%.4f", math.abs(tonumber(current) or 0) / 10000)
    local priceWidth = math.min(math.max(#goldText * 9 + 18, 72), 160)
    frame.headerArrow:ClearAllPoints()
    frame.headerArrow:SetPoint("RIGHT", frame.headerPrice, "RIGHT", -priceWidth - 4, 0)
end

local function EA_FormatChartHeaderDelta(copper)
    copper = math.floor(tonumber(copper) or 0)
    if copper == 0 then
        return "无变化"
    end
    local sign = copper > 0 and "+" or "-"
    copper = math.abs(copper)
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local coin = copper % 100
    local text = sign
    if gold > 0 then
        text = text .. gold .. "|TInterface\\MoneyFrame\\UI-GoldIcon:11:11:1:0|t"
    end
    if silver > 0 then
        text = text .. silver .. "|TInterface\\MoneyFrame\\UI-SilverIcon:11:11:1:0|t"
    end
    if coin > 0 or gold == 0 and silver == 0 then
        text = text .. coin .. "|TInterface\\MoneyFrame\\UI-CopperIcon:11:11:1:0|t"
    end
    return text
end

local function EA_SetChartArrow(tex, isUp)
    if not tex then return end
    local atlas = isUp and "poi-door-arrow-up" or "poi-door-arrow-down"
    local textureApi = _G.C_Texture
    if textureApi and textureApi.GetAtlasInfo and textureApi.GetAtlasInfo(atlas) then
        tex:SetAtlas(atlas, false)
        tex:SetSize(16, 16)
        return
    end
    tex:SetTexCoord(0, 1, 0, 1)
    tex:SetTexture(isUp and "Interface\\Buttons\\Arrow-Up-Up" or "Interface\\Buttons\\Arrow-Down-Up")
    tex:SetSize(16, 16)
end

local function EA_GetChartItemIcon(itemName, cleanName)
    local itemID = tostring(itemName or ""):match(":(%d+)$")
    local icon = itemID and GetItemIcon(tonumber(itemID))
    if not icon and cleanName and cleanName ~= "" then
        icon = select(10, GetItemInfo(cleanName)) or GetItemIcon(cleanName)
    end
    return icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function EA_GetCurrentSaleCount(db, itemName)
    if not (db and itemName) then return nil end
    local total = 0
    local history = EasyAuction_GetPriceHistory and EasyAuction_GetPriceHistory(itemName, db) or (db and db.PriceHistory and db.PriceHistory[itemName])
    if type(history) == "table" then
        for _, rec in ipairs(history) do
            total = total + (tonumber(rec and (rec.count or rec[3])) or 0)
        end
    end
    if total > 0 then
        return total
    end
    local daily = EasyAuction_GetDailyMinPrice and EasyAuction_GetDailyMinPrice(itemName, db) or (db and db.DailyMinPrice and db.DailyMinPrice[itemName])
    local last = daily and daily[#daily]
    local dailyCount = last and tonumber(last[6] or last[3])
    return dailyCount and dailyCount > 0 and dailyCount or nil
end

local function EA_RefreshTokenHeader(frame)
    if not (frame and frame.EAState and frame.headerPrice and frame.headerDelta) then return end
    local s = EA_ChartStats(frame.EAState.samples or {})
    frame.headerPrice:SetText(s.current and EA_FormatChartHeaderGold(s.current) or "--")
    local delta = s.changeAbs or 0
    frame.headerDelta:SetText("较昨日：" .. EA_FormatChartHeaderDelta(delta))
    if EAStyle then
        local r, g, b = EAStyle:ColorTrend(delta)
        frame.headerDelta:SetTextColor(r, g, b)
        if frame.headerArrow then
            frame.headerArrow:SetVertexColor(r, g, b)
        end
    elseif frame.headerArrow then
        frame.headerArrow:SetVertexColor(delta >= 0 and 0 or 1, delta >= 0 and 1 or 0, 0)
    end
    if frame.headerArrow then
        if delta ~= 0 then
            EA_SetChartArrow(frame.headerArrow, delta > 0)
            EA_PositionChartHeaderArrow(frame, s.current)
            frame.headerArrow:Show()
        else
            frame.headerArrow:Hide()
        end
    end
    if frame.subtitle then
        local count = EA_GetCurrentSaleCount(frame.EAState.db, frame.EAState.itemName)
        frame.subtitle:SetText(count and ("当前在售：" .. count) or "当前在售：-")
    end
end

local function EA_ClearPool(pool)
    if not pool then return end
    for i = 1, #pool do
        pool[i]:Hide()
        pool[i]:ClearAllPoints()
    end
    pool.active = 0
end

local function EA_AcquireTexture(parent, pool)
    pool.active = (pool.active or 0) + 1
    pool[pool.active] = pool[pool.active] or parent:CreateTexture(nil, "ARTWORK")
    local tex = pool[pool.active]
    tex:Show()
    return tex
end

local function EA_DrawMarketVolumeBars(plot, pool, barCount, maxCount, getX, getCount, barWidth)
    if not plot or not pool or not barCount or barCount < 1 or not maxCount or maxCount <= 0 then
        return false
    end
    local plotH = plot:GetHeight()
    if plotH <= 0 then return false end
    local maxH = math.max(plotH * 0.22, 14)
    local p = EA_Palette()
    for i = 1, barCount do
        local count = tonumber(getCount(i)) or 0
        if count > 0 then
            local bar = EA_AcquireTexture(plot, pool)
            local h = math.max((count / maxCount) * maxH, 1)
            bar:SetColorTexture(p.accent2[1], p.accent2[2], p.accent2[3], 0.28)
            bar:SetPoint("BOTTOM", plot, "BOTTOMLEFT", getX(i), 1)
            bar:SetSize(math.max(barWidth or 2, 1), h)
        end
    end
    return true
end

local function EA_HideChartHover(panel)
    if not panel then return end
    panel.hoverKey = nil
    if panel.crossV then panel.crossV:Hide() end
    if panel.marker then panel.marker:Hide() end
    if panel.tip then panel.tip:Hide() end
end

local function EA_NearestChartIndex(samples, first, last, x)
    local count = math.max(last - first, 1)
    local idx = first + math.floor((x * count) + 0.5)
    if idx < first then idx = first elseif idx > last then idx = last end
    return idx
end

local function EA_ShowChartReadout(panel, x, y, title, body, marker)
    local plot = panel.plot
    local p = EA_Palette()
    panel.crossV:ClearAllPoints()
    panel.crossV:SetPoint("BOTTOM", plot, "BOTTOMLEFT", x, 0)
    panel.crossV:SetSize(1, plot:GetHeight())
    panel.crossV:SetColorTexture(p.accent[1], p.accent[2], p.accent[3], 0.5)
    panel.crossV:Show()

    if marker then
        panel.marker:ClearAllPoints()
        panel.marker:SetPoint("CENTER", plot, "BOTTOMLEFT", x, y)
        panel.marker:SetColorTexture(p.accent[1], p.accent[2], p.accent[3], 1)
        panel.marker:Show()
    else
        panel.marker:Hide()
    end

    local tip = panel.tip
    tip.title:SetText(title or "")
    tip.body:SetText(body or "")
    local w = math.max(tip.title:GetStringWidth(), tip.body:GetStringWidth()) + 16
    local h = tip.title:GetStringHeight() + tip.body:GetStringHeight() + 15
    local plotW, plotH = plot:GetWidth(), plot:GetHeight()
    local cx = math.min(math.max(x, w / 2), math.max(plotW - w / 2, w / 2))
    tip:SetSize(w, h)
    tip:ClearAllPoints()
    if y + h + 14 > plotH then
        tip:SetPoint("TOP", plot, "BOTTOMLEFT", cx, y - 8)
    else
        tip:SetPoint("BOTTOM", plot, "BOTTOMLEFT", cx, y + 12)
    end
    tip:Show()
end

local function EA_OnChartHoverUpdate(plot, panel)
    local data = panel.hoverData
    if not data or not plot:GetLeft() then
        EA_HideChartHover(panel)
        return
    end
    local plotW, plotH = plot:GetWidth(), plot:GetHeight()
    local rx = (GetCursorPosition() / plot:GetEffectiveScale()) - plot:GetLeft()
    if rx < 0 or rx > plotW then
        EA_HideChartHover(panel)
        return
    end

    if data.mode == "candle" then
        local slot = plotW / math.max(data.count, 1)
        local k = math.min(math.max(math.floor(rx / slot), 0), data.count - 1)
        if panel.hoverKey == k then return end
        panel.hoverKey = k
        local cd = data.candles[data.first + k]
        if not cd then
            EA_HideChartHover(panel)
            return
        end
        local x = (k + 0.5) * slot
        local title = data.group == "hour" and EA_FormatShortDateHour(cd.t) or EA_FormatShortDate(cd.t)
        local body = string.format(
            "开盘  %s\n最高  %s\n最低  %s\n收盘  %s\n市场在售  %s",
            FormatGold(cd.o, 10),
            FormatGold(cd.h, 10),
            FormatGold(cd.l, 10),
            FormatGold(cd.c, 10),
            EA_FormatMarketCount(cd.n or 0)
        )
        EA_ShowChartReadout(panel, x, plotH * 0.6, title, body, false)
        return
    end

    local idx = EA_NearestChartIndex(data.samples, data.first, data.last, rx / math.max(plotW, 1))
    if panel.hoverKey == idx then return end
    panel.hoverKey = idx
    local sample = data.samples[idx]
    if not sample then
        EA_HideChartHover(panel)
        return
    end
    local xMax = math.max(data.last - data.first, 1)
    local x = ((idx - data.first) / xMax) * plotW
    local y = ((sample.close - data.minV) / math.max(data.maxV - data.minV, 1)) * plotH
    local body = FormatGold(sample.close, 10) .. "\n市场在售  " .. EA_FormatMarketCount(sample.count or 0)
    EA_ShowChartReadout(panel, x, y, sample.day, body, true)
end

local function EA_RenderTokenChart(frame)
    local state = frame.EAState
    local panel = frame.chartPage
    if not state or not panel then return end
    local samples = state.samples or {}
    local first, last = EA_FilterSamples(samples, state.rangeDays or 30)
    local hasData = last >= first
    EA_ChartSetActive(panel.btnLine, state.mode == "line")
    EA_ChartSetActive(panel.btnCandle, state.mode == "candle")
    EA_ChartSetActive(panel.btnMA7, state.showMA7)
    EA_ChartSetActive(panel.btnMA30, state.showMA30)
    EA_ChartSetActive(panel.btnHour, state.candleGroup == "hour")
    EA_ChartSetActive(panel.btnDay, state.candleGroup == "day")
    for days, btn in pairs(panel.rangeBtns or {}) do
        EA_ChartSetActive(btn, state.rangeDays == days)
    end
    panel.btnMA7:SetShown(state.mode == "line")
    panel.btnMA30:SetShown(state.mode == "line")
    panel.btnHour:SetShown(state.mode == "candle")
    panel.btnDay:SetShown(state.mode == "candle")
    EA_ClearPool(panel.candlePool)
    EA_ClearPool(panel.gridPool)
    EA_ClearPool(panel.linePool)
    EA_ClearPool(panel.volumePool)
    panel.hoverData = nil
    EA_HideChartHover(panel)

    local buySignal = EA_IsBuySignal(samples)
    panel.banner:SetShown(buySignal and hasData)

    if not hasData then
        panel.empty:Show()
        if panel.graph then panel.graph:Hide() end
        if panel.volumeLabel then panel.volumeLabel:Hide() end
        return
    end
    panel.empty:Hide()

    local minV, maxV = math.huge, -math.huge
    for i = first, last do
        local r = samples[i]
        minV = math.min(minV, r.low or r.close, r.close, r.ma7 or r.close, r.ma30 or r.close)
        maxV = math.max(maxV, r.high or r.close, r.close, r.ma7 or r.close, r.ma30 or r.close)
    end
    local span = math.max(maxV - minV, 1)
    minV = minV - span * 0.04
    maxV = maxV + span * 0.04
    span = math.max(maxV - minV, 1)

    local plot = panel.plot
    local plotW, plotH = plot:GetWidth(), plot:GetHeight()
    if plotW <= 0 or plotH <= 0 then
        C_Timer.After(0, function() if frame:IsShown() then EA_RenderTokenChart(frame) end end)
        return
    end
    if panel.volumeLabel then
        panel.volumeLabel:Hide()
    end

    for i = 0, 4 do
        local g = EA_AcquireTexture(plot, panel.gridPool)
        g:SetColorTexture((EA_Palette().border)[1], (EA_Palette().border)[2], (EA_Palette().border)[3], 0.16)
        g:SetPoint("LEFT", plot, "BOTTOMLEFT", 0, plotH * i / 4)
        g:SetSize(plotW, 1)
        local label = panel.yLabels[i + 1]
        label:SetText(FormatGold(minV + span * i / 4, 9))
        label:ClearAllPoints()
        label:SetPoint("RIGHT", plot, "BOTTOMLEFT", -4, plotH * i / 4)
    end
    panel.xLabels[1]:SetText(samples[first].day)
    panel.xLabels[2]:SetText(samples[math.floor((first + last) / 2)].day)
    panel.xLabels[3]:SetText(samples[last].day)

    if state.mode == "line" then
        local maxCount = 0
        for i = first, last do
            local count = tonumber(samples[i].count) or 0
            if count > maxCount then maxCount = count end
        end
        local lineCount = last - first + 1
        local xMaxForVolume = math.max(lineCount - 1, 1)
        local volumeBarW = math.max(plotW / math.max(lineCount, 1) * 0.5, 2)
        local hasVolume = EA_DrawMarketVolumeBars(plot, panel.volumePool, lineCount, maxCount,
            function(i) return ((i - 1) / xMaxForVolume) * plotW end,
            function(i) return samples[first + i - 1] and samples[first + i - 1].count or 0 end,
            volumeBarW)
        if hasVolume and panel.volumeLabel then
            panel.volumeLabel:SetText("市场在售")
            panel.volumeLabel:ClearAllPoints()
            panel.volumeLabel:SetPoint("LEFT", plot, "BOTTOMLEFT", 4, 4)
            panel.volumeLabel:Show()
        end
        if panel.graph then
            panel.graph:Show()
            panel.graph:ResetData()
            local pricePts, ma7Pts, ma30Pts = {}, {}, {}
            local xMax = math.max(last - first, 1)
            for i = first, last do
                local x = i - first
                pricePts[#pricePts + 1] = { x, samples[i].close }
                if samples[i].ma7 then ma7Pts[#ma7Pts + 1] = { x, samples[i].ma7 } end
                if samples[i].ma30 then ma30Pts[#ma30Pts + 1] = { x, samples[i].ma30 } end
            end
            if #pricePts == 1 then pricePts[2] = { 1, pricePts[1][2] } end
            panel.graph:SetXAxis(0, xMax)
            panel.graph:SetYAxis(minV, maxV)
            panel.graph:SetGridSpacing(math.max(xMax / 6, 0.001), span / 4)
            local p = EA_Palette()
            panel.graph:SetAxisColor({ p.border[1], p.border[2], p.border[3], 0.85 })
            panel.graph:SetGridColor({ p.border[1], p.border[2], p.border[3], 0.18 })
            if state.showMA30 and #ma30Pts >= 2 then panel.graph:AddDataSeries(ma30Pts, EA_CHART_MA30_COLOR) end
            if state.showMA7 and #ma7Pts >= 2 then panel.graph:AddDataSeries(ma7Pts, EA_CHART_MA7_COLOR) end
            panel.graph:AddDataSeries(pricePts, { p.accent[1], p.accent[2], p.accent[3], 1 })
        else
            local count = last - first + 1
            local xMax = math.max(count - 1, 1)
            local function y(v) return ((v - minV) / span) * plotH end
            local function drawSeries(valueKey, color)
                local prevX, prevY
                for i = first, last do
                    local v = samples[i][valueKey]
                    if v and v > 0 then
                        local x = ((i - first) / xMax) * plotW
                        local yy = y(v)
                        if prevX then
                            local dx, dy = x - prevX, yy - prevY
                            local len = math.sqrt(dx * dx + dy * dy)
                            local line = EA_AcquireTexture(plot, panel.linePool)
                            line:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
                            line:SetPoint("CENTER", plot, "BOTTOMLEFT", prevX + dx / 2, prevY + dy / 2)
                            line:SetSize(math.max(len, 1), 2)
                            line:SetRotation(math.atan2(dy, dx))
                        end
                        prevX, prevY = x, yy
                    end
                end
            end
            local p = EA_Palette()
            if state.showMA30 then drawSeries("ma30", EA_CHART_MA30_COLOR) end
            if state.showMA7 then drawSeries("ma7", EA_CHART_MA7_COLOR) end
            drawSeries("close", { p.accent[1], p.accent[2], p.accent[3], 1 })
        end
        panel.hoverData = {
            mode = "line",
            samples = samples,
            first = first,
            last = last,
            minV = minV,
            maxV = maxV,
        }
    else
        if panel.graph then panel.graph:Hide() end
        local candles = EA_BuildCandles(frame, state.candleGroup or "day", state.rangeDays or 30)
        local maxFit = math.max(math.floor(plotW / 3), 1)
        local candleFirst = math.max(#candles - maxFit + 1, 1)
        local count = #candles - candleFirst + 1
        if count < 1 then
            panel.empty:Show()
            return
        end
        minV, maxV = math.huge, -math.huge
        for i = candleFirst, #candles do
            minV = math.min(minV, candles[i].l or candles[i].c)
            maxV = math.max(maxV, candles[i].h or candles[i].c)
        end
        span = math.max(maxV - minV, 1)
        minV = minV - span * 0.04
        maxV = maxV + span * 0.04
        span = math.max(maxV - minV, 1)
        for i = 0, 4 do
            local label = panel.yLabels[i + 1]
            label:SetText(FormatGold(minV + span * i / 4, 9))
        end
        local midCandle = candles[math.floor((candleFirst + #candles) / 2)]
        if state.candleGroup == "hour" then
            panel.xLabels[1]:SetText(EA_FormatShortDateHour(candles[candleFirst].t))
            panel.xLabels[2]:SetText(EA_FormatShortDateHour(midCandle.t))
            panel.xLabels[3]:SetText(EA_FormatShortDateHour(candles[#candles].t))
        else
            panel.xLabels[1]:SetText(EA_FormatShortDate(candles[candleFirst].t))
            panel.xLabels[2]:SetText(EA_FormatShortDate(midCandle.t))
            panel.xLabels[3]:SetText(EA_FormatShortDate(candles[#candles].t))
        end
        local slot = plotW / math.max(count, 1)
        local bodyW = math.max(slot * 0.62, 2)
        local function y(v) return ((v - minV) / span) * plotH end
        local maxCount = 0
        for k = 0, count - 1 do
            local n = tonumber(candles[candleFirst + k] and candles[candleFirst + k].n) or 0
            if n > maxCount then maxCount = n end
        end
        local hasVolume = EA_DrawMarketVolumeBars(plot, panel.volumePool, count, maxCount,
            function(i) return (i - 0.5) * slot end,
            function(i) return candles[candleFirst + i - 1] and candles[candleFirst + i - 1].n or 0 end,
            math.max(slot * 0.5, 2))
        if hasVolume and panel.volumeLabel then
            panel.volumeLabel:SetText("市场在售")
            panel.volumeLabel:ClearAllPoints()
            panel.volumeLabel:SetPoint("LEFT", plot, "BOTTOMLEFT", 4, 4)
            panel.volumeLabel:Show()
        end
        for k = 0, count - 1 do
            local r = candles[candleFirst + k]
            local x = (k + 0.5) * slot
            local bull = r.c >= (r.o or r.c)
            local col = bull and (EAStyle and EAStyle.Bull or { 0, 1, 0 }) or (EAStyle and EAStyle.Bear or { 1, 0, 0 })
            local wick = EA_AcquireTexture(plot, panel.candlePool)
            wick:SetColorTexture(col[1], col[2], col[3], 0.9)
            local lowY, highY = y(r.l or r.c), y(r.h or r.c)
            wick:SetPoint("BOTTOM", plot, "BOTTOMLEFT", x, lowY)
            wick:SetSize(math.max(slot * 0.12, 1), math.max(highY - lowY, 1))
            local body = EA_AcquireTexture(plot, panel.candlePool)
            body:SetColorTexture(col[1], col[2], col[3], 1)
            local openY, closeY = y(r.o or r.c), y(r.c)
            body:SetPoint("BOTTOM", plot, "BOTTOMLEFT", x, math.min(openY, closeY))
            body:SetSize(bodyW, math.max(math.abs(closeY - openY), 1.5))
        end
        panel.hoverData = {
            mode = "candle",
            candles = candles,
            first = candleFirst,
            count = count,
            group = state.candleGroup or "day",
        }
    end
end

local function EA_RefreshTokenStats(frame)
    local page = frame.statsPage
    if not page then return end
    local state = frame.EAState or {}
    local s = EA_ChartStats(state.samples or {})
    local function set(row, text, role, delta)
        row.value:SetText(text or "-")
        if delta ~= nil and EAStyle then
            local r, g, b = EAStyle:ColorTrend(delta)
            row.value:SetTextColor(r, g, b)
        elseif role then
            EA_SkinChartText(row.value, role)
        end
    end
    set(page.rows.current, s.current and FormatGold(s.current, 10), nil, s.changeAbs)
    set(page.rows.change, s.changeAbs and ((s.changeAbs >= 0 and "+" or "-") .. FormatGold(math.abs(s.changeAbs), 10) .. string.format(" (%.1f%%)", s.changePct or 0)), nil, s.changeAbs)
    set(page.rows.prevClose, s.prevClose and FormatGold(s.prevClose, 10))
    set(page.rows.dayRange, s.dayRange)
    set(page.rows.low7, s.low7 and FormatGold(s.low7, 10), "bull")
    set(page.rows.high7, s.high7 and FormatGold(s.high7, 10), "bear")
    set(page.rows.avg7, s.avg7 and FormatGold(s.avg7, 10))
    set(page.rows.low30, s.low30 and FormatGold(s.low30, 10), "bull")
    set(page.rows.high30, s.high30 and FormatGold(s.high30, 10), "bear")
    set(page.rows.avg30, s.avg30 and FormatGold(s.avg30, 10))
    set(page.rows.lowAll, s.lowAll and FormatGold(s.lowAll, 10), "bull")
    set(page.rows.highAll, s.highAll and FormatGold(s.highAll, 10), "bear")
    set(page.rows.samples, tostring(s.samples or 0))
    set(page.rows.since, s.since)
    if page.rangeBar and s.low30 and s.high30 and s.current then
        page.rangeBar:Update(s.low30, s.high30, s.current, function(v) return FormatGold(v, 9) end, true)
    end
    local verdict, verdictRole = EA_RangeVerdict(s.low30, s.high30, s.current, s.count30)
    if page.rangeVerdict then
        page.rangeVerdict:SetText(verdict or "30日样本不足，暂无法分析价格位置。")
        EA_SkinChartText(page.rangeVerdict, verdictRole or "muted")
    end

    local hours, hourCount = EA_AverageHoursFromHourlyMin(state)
    if not hours or hourCount == 0 then
        hours = EA_AverageByBucket(state.rawPoints or {}, 24, function(t) return tonumber(date("%H", t)) end)
        hourCount = 0
        for i = 0, 23 do
            if hours[i] then hourCount = hourCount + 1 end
        end
    end
    local weekdays, weekdayCount = EA_AverageWeekdaysFromDailyMin(state)
    if not weekdays or weekdayCount == 0 then
        weekdays = EA_AverageByBucket(state.rawPoints or {}, 7, function(t) return date("*t", t).wday - 1 end)
        weekdayCount = 0
        for i = 0, 6 do
            if weekdays[i] then weekdayCount = weekdayCount + 1 end
        end
    end

    local enough = hourCount > 0 or weekdayCount > 0
    page.empty:SetShown(not enough)
    page.hourTitle:SetShown(enough)
    page.hourStrip:SetShown(enough)
    page.weekTitle:SetShown(enough)
    page.weekStrip:SetShown(enough)
    page.bestText:SetShown(enough)
    if not enough then return end
    if page.hourStrip:GetWidth() <= 0 then
        C_Timer.After(0, function() if frame:IsShown() then EA_RefreshTokenStats(frame) end end)
        return
    end
    EA_LayoutStatsTicks(page)

    local hourLabels = {}
    for i = 0, 23 do
        hourLabels[i + 1] = string.format("%02d:00", i)
    end
    EA_UpdateHeatStrip(page.hourStrip, page.hourCells, hours, hourLabels)

    EA_UpdateHeatStrip(page.weekStrip, page.weekCells, weekdays, EA_CHART_WEEKDAYS)

    local bestHour, bestHourValue = EA_BestBucket(hours, 24)
    local bestDay, bestDayValue = EA_BestBucket(weekdays, 7)
    if bestHour and bestDay then
        page.bestText:SetText(string.format("最佳买入时间：%s %02d:00  ·  约 %s", EA_CHART_WEEKDAYS[bestDay + 1], bestHour, FormatGold(math.floor(bestHourValue or bestDayValue or 0), 10)))
    elseif bestHour then
        page.bestText:SetText(string.format("最佳买入时间：%02d:00  ·  约 %s", bestHour, FormatGold(math.floor(bestHourValue or 0), 10)))
    else
        page.bestText:SetText("最佳买入时间：样本不足")
    end
end

local function EA_RefreshTokenHistory(frame)
    local page = frame.historyPage
    if not page then return end
    local state = frame.EAState or {}
    EA_ChartSetActive(page.btnDay, state.historyGroup == "day")
    EA_ChartSetActive(page.btnHour, state.historyGroup == "hour")
    if page.LayoutColumns then
        page:LayoutColumns()
    end
    local candles = EA_BuildCandles(frame, state.historyGroup or "day", 0)
    local total = #candles
    if total == 0 then
        page.empty:Show()
        page.pageText:SetText("")
        page.btnPrev:SetEnabled(false)
        page.btnNext:SetEnabled(false)
        for i = 1, #page.rows do
            page.rows[i]:Hide()
        end
        return
    end
    page.empty:Hide()
    local totalPages = math.max(math.ceil(total / EA_CHART_ROWS), 1)
    state.historyPage = math.min(math.max(state.historyPage or 1, 1), totalPages)
    local firstNewest = (state.historyPage - 1) * EA_CHART_ROWS + 1
    for i = 1, #page.rows do
        local row = page.rows[i]
        local newestRank = firstNewest + i - 1
        local idx = total - newestRank + 1
        local data = candles[idx]
        if data then
            local prevClose = idx > 1 and candles[idx - 1].c or data.o
            local delta = data.c - prevClose
            row:Show()
            row.cols[1]:SetText((state.historyGroup == "hour") and EA_FormatShortDateHour(data.t) or date("%m/%d/%Y", data.t))
            row.cols[2]:SetText(FormatGold(data.c, 9))
            row.cols[3]:SetText(FormatGold(data.o, 9))
            row.cols[4]:SetText(FormatGold(data.h, 9))
            row.cols[5]:SetText(FormatGold(data.l, 9))
            row.cols[6]:SetText(EA_FormatPct(prevClose ~= 0 and delta / prevClose * 100 or 0))
            if EAStyle then
                local r, g, b = EAStyle:ColorTrend(delta)
                row.cols[2]:SetTextColor(r, g, b)
                row.cols[6]:SetTextColor(r, g, b)
            end
            if row.bg then
                if EAStyle then EAStyle:RowColor(row.bg, i, false) end
            end
        else
            row:Hide()
        end
    end
    local shownTo = math.min(firstNewest + EA_CHART_ROWS - 1, total)
    page.pageText:SetText(string.format("%d-%d / %d", firstNewest, shownTo, total))
    page.btnPrev:SetEnabled(state.historyPage > 1)
    page.btnNext:SetEnabled(state.historyPage < totalPages)
    page.btnPrev:SetAlpha(state.historyPage > 1 and 1 or 0.35)
    page.btnNext:SetAlpha(state.historyPage < totalPages and 1 or 0.35)
end

local function EA_ShowTokenChartPage(frame, pageName)
    frame.EAState.page = pageName
    for _, name in ipairs({ "chart", "stats", "history" }) do
        frame[name .. "Page"]:SetShown(name == pageName)
        EA_ChartSetActive(frame.tabBtns[name], name == pageName)
    end
    if pageName == "chart" then
        EA_RenderTokenChart(frame)
    elseif pageName == "stats" then
        EA_RefreshTokenStats(frame)
    else
        EA_RefreshTokenHistory(frame)
    end
end

local function EA_MakeMetricRow(parent, anchor, labelText)
    local label = EA_ChartText(parent, 12, "muted")
    label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -7)
    label:SetText(labelText)
    local value = EA_ChartText(parent, 12, "text")
    value:SetPoint("LEFT", label, "LEFT", 120, 0)
    return { label = label, value = value, anchor = label }
end

local function EA_BuildHeatStrip(parent, count)
    local strip = CreateFrame("Frame", nil, parent)
    local cells = {}
    for i = 1, count do
        local cell = CreateFrame("Frame", nil, strip)
        cell.bg = cell:CreateTexture(nil, "ARTWORK")
        cell.bg:SetAllPoints()
        cell:EnableMouse(true)
        cell:SetScript("OnEnter", function(self)
            if not self.value then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(self.tip or "")
            GameTooltip:AddLine(FormatGold(math.floor(self.value), 10), 1, 1, 1)
            GameTooltip:Show()
        end)
        cell:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        cells[i] = cell
    end
    return strip, cells
end

local function EA_BuildTokenChartFrame()
    local frame = CreateFrame("Frame", "EasyAuction_ChartFrame", UIParent, "BackdropTemplate")
    frame:SetSize(640, 460)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    EA_SkinChartFrame(frame, "window")
    EA_RaiseChartFrame(frame)
    tinsert(UISpecialFrames, "EasyAuction_ChartFrame")

    frame.itemIcon = frame:CreateTexture(nil, "ARTWORK")
    frame.itemIcon:SetPoint("TOPLEFT", 14, -10)
    frame.itemIcon:SetSize(28, 28)
    frame.itemIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    frame.title = EA_ChartText(frame, 16, "accent")
    frame.title:SetPoint("TOPLEFT", frame.itemIcon, "TOPRIGHT", 8, 0)
    frame.title:SetPoint("RIGHT", frame, "RIGHT", -230, 0)
    frame.title:SetJustifyH("LEFT")
    frame.title:SetWordWrap(false)
    frame.subtitle = EA_ChartText(frame, 11, "muted")
    frame.subtitle:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -2)

    frame.headerPrice = EA_ChartText(frame, 16, "accent")
    frame.headerPrice:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -42, -12)
    frame.headerPrice:SetWidth(180)
    frame.headerPrice:SetJustifyH("RIGHT")
    frame.headerArrow = frame:CreateTexture(nil, "OVERLAY")
    frame.headerArrow:SetPoint("RIGHT", frame.headerPrice, "RIGHT", -52, 0)
    frame.headerArrow:Hide()
    frame.headerDelta = EA_ChartText(frame, 11, "muted")
    frame.headerDelta:SetPoint("TOPRIGHT", frame.headerPrice, "BOTTOMRIGHT", 0, -2)
    frame.headerDelta:SetWidth(180)
    frame.headerDelta:SetJustifyH("RIGHT")

    local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    close:SetPoint("TOPRIGHT", -8, -8)
    close:SetSize(22, 22)
    close:SetText("\195\151")
    EA_SkinChartCloseButton(close)
    close:SetScript("OnClick", function() frame:Hide() end)
    EA_SetChartTooltip(close, "关闭", "关闭价格走势窗口。", "ANCHOR_LEFT")

    frame.tabBtns = {}
    local tabStrip = CreateFrame("Frame", nil, frame)
    tabStrip:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -54)
    tabStrip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, 0)
    tabStrip:SetHeight(22)
    local tabs = { { "chart", "图表" }, { "stats", "统计" }, { "history", "历史" } }
    local prev
    for _, def in ipairs(tabs) do
        local btn = CreateFrame("Button", nil, tabStrip, "UIPanelButtonTemplate")
        btn:SetSize(54, 22)
        btn:SetText(def[2])
        EA_ChartStyleButton(btn)
        if prev then
            btn:SetPoint("LEFT", prev, "RIGHT", 4, 0)
        else
            btn:SetPoint("LEFT", 0, 0)
        end
        btn:SetScript("OnClick", function() EA_ShowTokenChartPage(frame, def[1]) end)
        EA_SetChartTooltip(btn, def[2], def[1] == "chart" and "查看折线、K线与均线。" or def[1] == "stats" and "查看价格统计与最佳买入时间。" or "浏览每日/小时历史记录。")
        frame.tabBtns[def[1]] = btn
        prev = btn
    end

    local content = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    content:SetPoint("TOPLEFT", tabStrip, "BOTTOMLEFT", 0, -6)
    content:SetPoint("BOTTOMRIGHT", -14, 14)
    if EAStyle then EAStyle:Skin(content, "panel") end
    frame.content = content

    local chartPage = CreateFrame("Frame", nil, content)
    chartPage:SetAllPoints(content)
    frame.chartPage = chartPage
    local controls = CreateFrame("Frame", nil, chartPage)
    controls:SetPoint("TOPLEFT", 8, -8)
    controls:SetPoint("TOPRIGHT", -8, -8)
    controls:SetHeight(24)
    local function makeControl(text, width, onClick)
        local b = CreateFrame("Button", nil, controls, "UIPanelButtonTemplate")
        b:SetSize(width, 22)
        b:SetText(text)
        EA_ChartStyleButton(b)
        b:SetScript("OnClick", onClick)
        return b
    end
    chartPage.btnLine = makeControl("折线", 54, function() frame.EAState.mode = "line"; EA_RenderTokenChart(frame) end)
    chartPage.btnLine:SetPoint("LEFT", 0, 0)
    EA_SetChartTooltip(chartPage.btnLine, "折线", "按时间显示价格走势，鼠标指向节点可查看时点价格。")
    chartPage.btnCandle = makeControl("K线", 54, function() frame.EAState.mode = "candle"; EA_RenderTokenChart(frame) end)
    chartPage.btnCandle:SetPoint("LEFT", chartPage.btnLine, "RIGHT", 4, 0)
    EA_SetChartTooltip(chartPage.btnCandle, "K线", "按小时或每日显示开盘、最高、最低、收盘。")
    chartPage.btnMA7 = makeControl("MA7", 48, function() frame.EAState.showMA7 = not frame.EAState.showMA7; EA_RenderTokenChart(frame) end)
    chartPage.btnMA7:SetPoint("LEFT", chartPage.btnCandle, "RIGHT", 12, 0)
    EA_SetChartTooltip(chartPage.btnMA7, "MA7", "显示或隐藏 7 日均线。")
    chartPage.btnMA30 = makeControl("MA30", 54, function() frame.EAState.showMA30 = not frame.EAState.showMA30; EA_RenderTokenChart(frame) end)
    chartPage.btnMA30:SetPoint("LEFT", chartPage.btnMA7, "RIGHT", 4, 0)
    EA_SetChartTooltip(chartPage.btnMA30, "MA30", "显示或隐藏 30 日均线。")
    chartPage.btnHour = makeControl("小时", 54, function() frame.EAState.candleGroup = "hour"; EA_RenderTokenChart(frame) end)
    chartPage.btnHour:SetPoint("LEFT", chartPage.btnCandle, "RIGHT", 12, 0)
    EA_SetChartTooltip(chartPage.btnHour, "小时K线", "每根 K 线代表一小时价格变化。")
    chartPage.btnDay = makeControl("每日", 54, function() frame.EAState.candleGroup = "day"; EA_RenderTokenChart(frame) end)
    chartPage.btnDay:SetPoint("LEFT", chartPage.btnHour, "RIGHT", 4, 0)
    EA_SetChartTooltip(chartPage.btnDay, "每日K线", "每根 K 线代表一天价格变化。")
    chartPage.rangeBtns = {}
    local ranges = { { 0, "全部" }, { 90, "90D" }, { 30, "30D" }, { 7, "7D" } }
    local rightPrev
    for _, r in ipairs(ranges) do
        local days, label = r[1], r[2]
        local b = makeControl(label, 46, function() frame.EAState.rangeDays = days; EA_RenderTokenChart(frame) end)
        if rightPrev then
            b:SetPoint("RIGHT", rightPrev, "LEFT", -4, 0)
        else
            b:SetPoint("RIGHT", controls, "RIGHT", 0, 0)
        end
        rightPrev = b
        chartPage.rangeBtns[days] = b
        EA_SetChartTooltip(b, label, days > 0 and ("显示最近 " .. days .. " 天。") or "显示全部记录。")
    end

    local plotArea = CreateFrame("Frame", nil, chartPage, "BackdropTemplate")
    plotArea:SetPoint("TOPLEFT", controls, "BOTTOMLEFT", 0, -6)
    plotArea:SetPoint("BOTTOMRIGHT", chartPage, "BOTTOMRIGHT", -8, 8)
    if EAStyle then EAStyle:Skin(plotArea, "plot") end
    chartPage.plotArea = plotArea
    local plot = CreateFrame("Frame", nil, plotArea)
    plot:SetPoint("TOPLEFT", 56, -16)
    plot:SetPoint("BOTTOMRIGHT", -10, 22)
    plot:SetClipsChildren(true)
    chartPage.plot = plot
    if EAGraph then
        chartPage.graph = EAGraph:CreateGraphLine(nil, plot, "TOPLEFT", "TOPLEFT", 0, 0, 100, 100)
        chartPage.graph:SetAllPoints(plot)
    end
    chartPage.yLabels, chartPage.xLabels = {}, {}
    for i = 1, 5 do chartPage.yLabels[i] = EA_ChartText(plotArea, 10, "muted") end
    for i = 1, 3 do
        local fs = EA_ChartText(plotArea, 10, "muted")
        fs:SetPoint(i == 1 and "LEFT" or i == 3 and "RIGHT" or "CENTER", plot, i == 1 and "BOTTOMLEFT" or i == 3 and "BOTTOMRIGHT" or "BOTTOM", 0, -13)
        chartPage.xLabels[i] = fs
    end
    chartPage.empty = EA_ChartText(plotArea, 13, "muted")
    chartPage.empty:SetPoint("CENTER")
    chartPage.empty:SetText("暂无价格历史")
    chartPage.volumeLabel = EA_ChartText(plotArea, 9, "muted")
    chartPage.volumeLabel:SetPoint("LEFT", plot, "BOTTOMLEFT", 4, 4)
    chartPage.volumeLabel:SetAlpha(0.75)
    chartPage.volumeLabel:Hide()
    chartPage.candlePool, chartPage.gridPool, chartPage.linePool, chartPage.volumePool = {}, {}, {}, {}

    local banner = CreateFrame("Frame", nil, plotArea, "BackdropTemplate")
    banner:SetPoint("TOP", plot, "TOP", 0, -4)
    banner:SetSize(260, 22)
    banner:SetFrameLevel(plotArea:GetFrameLevel() + 20)
    banner:Hide()
    if banner.SetBackdrop then
        banner:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    end
    banner.icon = banner:CreateTexture(nil, "OVERLAY")
    EA_SetChartArrow(banner.icon, true)
    banner.icon:SetPoint("LEFT", 8, 0)
    banner.icon:SetVertexColor(1, 1, 1)
    banner.text = EA_ChartText(banner, 12, "text")
    banner.text:SetPoint("LEFT", banner.icon, "RIGHT", 5, 0)
    banner.text:SetText("买入信号 · 当前接近30日低点，适合买入。")
    if EAStyle then
        banner:SetBackdropColor(EAStyle.Bull[1], EAStyle.Bull[2], EAStyle.Bull[3], 0.9)
        banner:SetBackdropBorderColor(EAStyle.Bull[1], EAStyle.Bull[2], EAStyle.Bull[3], 1)
    end
    chartPage.banner = banner

    local overlay = CreateFrame("Frame", nil, plot)
    overlay:SetAllPoints(plot)
    overlay:SetFrameLevel((chartPage.graph and chartPage.graph:GetFrameLevel() or plot:GetFrameLevel()) + 5)
    chartPage.crossV = overlay:CreateTexture(nil, "OVERLAY")
    chartPage.crossV:Hide()
    chartPage.marker = overlay:CreateTexture(nil, "OVERLAY")
    chartPage.marker:SetSize(7, 7)
    chartPage.marker:Hide()
    local tip = CreateFrame("Frame", nil, plotArea, "BackdropTemplate")
    tip:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    tip:SetFrameLevel(plotArea:GetFrameLevel() + 30)
    tip.title = EA_ChartText(tip, 11, "accent")
    tip.title:SetPoint("TOPLEFT", 8, -6)
    tip.title:SetJustifyH("LEFT")
    tip.body = EA_ChartText(tip, 11, "text")
    tip.body:SetPoint("TOPLEFT", tip.title, "BOTTOMLEFT", 0, -3)
    tip.body:SetJustifyH("LEFT")
    tip:Hide()
    if EAStyle then
        local p = EA_Palette()
        tip:SetBackdropColor(p.panel[1], p.panel[2], p.panel[3], 0.95)
        tip:SetBackdropBorderColor(p.accent[1], p.accent[2], p.accent[3], 1)
    end
    chartPage.tip = tip
    plot:EnableMouse(true)
    plot:SetScript("OnEnter", function()
        plot:SetScript("OnUpdate", function(self)
            EA_OnChartHoverUpdate(self, chartPage)
        end)
    end)
    plot:SetScript("OnLeave", function()
        plot:SetScript("OnUpdate", nil)
        EA_HideChartHover(chartPage)
    end)

    local statsPage = CreateFrame("Frame", nil, content)
    statsPage:SetAllPoints(content)
    frame.statsPage = statsPage
    local left = CreateFrame("Frame", nil, statsPage)
    left:SetPoint("TOPLEFT", 12, -10)
    left:SetPoint("BOTTOMLEFT", 12, 12)
    left:SetWidth(250)
    local heading = EA_ChartText(left, 13, "accent")
    heading:SetPoint("TOPLEFT", 0, 0)
    heading:SetText("统计")
    statsPage.rows = {}
    local row = EA_MakeMetricRow(left, heading, "当前价格"); statsPage.rows.current = row
    row = EA_MakeMetricRow(left, row.anchor, "涨跌"); statsPage.rows.change = row
    row = EA_MakeMetricRow(left, row.anchor, "前收盘"); statsPage.rows.prevClose = row
    row = EA_MakeMetricRow(left, row.anchor, "今日区间"); statsPage.rows.dayRange = row
    row = EA_MakeMetricRow(left, row.anchor, "7日最低"); statsPage.rows.low7 = row
    row = EA_MakeMetricRow(left, row.anchor, "7日最高"); statsPage.rows.high7 = row
    row = EA_MakeMetricRow(left, row.anchor, "7日均价"); statsPage.rows.avg7 = row
    row = EA_MakeMetricRow(left, row.anchor, "30日最低"); statsPage.rows.low30 = row
    row = EA_MakeMetricRow(left, row.anchor, "30日最高"); statsPage.rows.high30 = row
    row = EA_MakeMetricRow(left, row.anchor, "30日均价"); statsPage.rows.avg30 = row
    row = EA_MakeMetricRow(left, row.anchor, "历史最低"); statsPage.rows.lowAll = row
    row = EA_MakeMetricRow(left, row.anchor, "历史最高"); statsPage.rows.highAll = row
    row = EA_MakeMetricRow(left, row.anchor, "样本数"); statsPage.rows.samples = row
    row = EA_MakeMetricRow(left, row.anchor, "开始记录"); statsPage.rows.since = row
    local divider = EAStyle and EAStyle:Divider(statsPage, "vertical") or statsPage:CreateTexture(nil, "ARTWORK")
    if not EAStyle then
        divider:SetWidth(1)
        divider:SetColorTexture(0.5, 0.5, 0.5, 0.7)
    end
    divider:SetPoint("TOPLEFT", left, "TOPRIGHT", 8, 0)
    divider:SetPoint("BOTTOMLEFT", left, "BOTTOMRIGHT", 8, 0)
    local right = CreateFrame("Frame", nil, statsPage)
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 20, 0)
    right:SetPoint("BOTTOMRIGHT", -12, 12)
    statsPage.hourTitle = EA_ChartText(right, 13, "accent")
    statsPage.hourTitle:SetPoint("TOPLEFT", 0, -10)
    statsPage.hourTitle:SetText("一天中较便宜的时段")
    local hourStrip, hourCells = EA_BuildHeatStrip(right, 24)
    hourStrip:SetPoint("TOPLEFT", statsPage.hourTitle, "BOTTOMLEFT", 0, -8)
    hourStrip:SetPoint("RIGHT", right, "RIGHT", 0, 0)
    hourStrip:SetHeight(74)
    statsPage.hourStrip, statsPage.hourCells = hourStrip, hourCells
    statsPage.hourTicks = {}
    for _, hr in ipairs({ 0, 6, 12, 18 }) do
        local tick = EA_ChartText(right, 9, "muted")
        tick:SetText(string.format("%02d", hr))
        tick:SetPoint("TOP", hourStrip, "BOTTOMLEFT", (hr + 0.5) * 16, -2)
        statsPage.hourTicks[#statsPage.hourTicks + 1] = { font = tick, hour = hr }
    end

    statsPage.weekTitle = EA_ChartText(right, 13, "accent")
    statsPage.weekTitle:SetPoint("TOPLEFT", hourStrip, "BOTTOMLEFT", 0, -22)
    statsPage.weekTitle:SetText("一周中较便宜的日期")
    local weekStrip, weekCells = EA_BuildHeatStrip(right, 7)
    weekStrip:SetPoint("TOPLEFT", statsPage.weekTitle, "BOTTOMLEFT", 0, -8)
    weekStrip:SetPoint("RIGHT", right, "RIGHT", 0, 0)
    weekStrip:SetHeight(50)
    statsPage.weekStrip, statsPage.weekCells = weekStrip, weekCells
    statsPage.weekTicks = {}
    for i = 1, 7 do
        local tick = EA_ChartText(right, 9, "muted")
        tick:SetText(EA_CHART_WEEKDAYS[i])
        statsPage.weekTicks[i] = tick
    end
    statsPage.bestText = EA_ChartText(right, 12, "text")
    statsPage.bestText:SetPoint("TOPLEFT", weekStrip, "BOTTOMLEFT", 0, -16)

    local rangeTitle = EA_ChartText(right, 13, "accent")
    rangeTitle:SetPoint("TOPLEFT", statsPage.bestText, "BOTTOMLEFT", 0, -18)
    rangeTitle:SetText("30日价格区间")
    statsPage.rangeBar = EAStyle and EAStyle:RangeBar(right, nil) or nil
    if statsPage.rangeBar then
        statsPage.rangeBar.frame:SetPoint("TOPLEFT", rangeTitle, "BOTTOMLEFT", 0, -14)
        statsPage.rangeBar.frame:SetPoint("RIGHT", right, "RIGHT", 0, 0)
    end
    statsPage.rangeVerdict = EA_ChartText(right, 12, "text")
    statsPage.rangeVerdict:SetPoint("TOPLEFT", statsPage.rangeBar and statsPage.rangeBar.frame or rangeTitle, "BOTTOMLEFT", 0, -8)
    statsPage.rangeVerdict:SetWidth(300)
    statsPage.rangeVerdict:SetJustifyH("LEFT")
    statsPage.empty = EA_ChartText(right, 12, "muted")
    statsPage.empty:SetPoint("TOPLEFT", statsPage.hourTitle, "BOTTOMLEFT", 0, -20)
    statsPage.empty:SetWidth(360)
    statsPage.empty:SetJustifyH("LEFT")
    statsPage.empty:SetText("历史样本不足，继续扫描后会生成时段与星期分析。")

    local historyPage = CreateFrame("Frame", nil, content)
    historyPage:SetAllPoints(content)
    frame.historyPage = historyPage
    local histControls = CreateFrame("Frame", nil, historyPage)
    histControls:SetPoint("TOPLEFT", 8, -8)
    histControls:SetPoint("TOPRIGHT", -8, -8)
    histControls:SetHeight(24)
    local function makeHistoryButton(text, width, onClick)
        local b = CreateFrame("Button", nil, histControls, "UIPanelButtonTemplate")
        b:SetSize(width, 22)
        b:SetText(text)
        EA_ChartStyleButton(b)
        b:SetScript("OnClick", onClick)
        return b
    end
    historyPage.btnDay = makeHistoryButton("每日", 54, function() frame.EAState.historyGroup = "day"; frame.EAState.historyPage = 1; EA_RefreshTokenHistory(frame) end)
    historyPage.btnDay:SetPoint("LEFT", 0, 0)
    EA_SetChartTooltip(historyPage.btnDay, "每日历史", "按天显示历史 OHLC 记录。")
    historyPage.btnHour = makeHistoryButton("小时", 54, function() frame.EAState.historyGroup = "hour"; frame.EAState.historyPage = 1; EA_RefreshTokenHistory(frame) end)
    historyPage.btnHour:SetPoint("LEFT", historyPage.btnDay, "RIGHT", 4, 0)
    EA_SetChartTooltip(historyPage.btnHour, "小时历史", "按小时显示历史 OHLC 记录。")
    historyPage.btnNext = makeHistoryButton(">", 28, function() frame.EAState.historyPage = (frame.EAState.historyPage or 1) + 1; EA_RefreshTokenHistory(frame) end)
    historyPage.btnNext:SetPoint("RIGHT", 0, 0)
    EA_SetChartTooltip(historyPage.btnNext, "下一页", "显示更早的历史记录。")
    historyPage.pageText = EA_ChartText(histControls, 11, "muted")
    historyPage.pageText:SetPoint("RIGHT", historyPage.btnNext, "LEFT", -10, 0)
    historyPage.pageText:SetJustifyH("RIGHT")
    historyPage.btnPrev = makeHistoryButton("<", 28, function() frame.EAState.historyPage = (frame.EAState.historyPage or 1) - 1; EA_RefreshTokenHistory(frame) end)
    historyPage.btnPrev:SetPoint("RIGHT", historyPage.pageText, "LEFT", -10, 0)
    EA_SetChartTooltip(historyPage.btnPrev, "上一页", "显示更新的历史记录。")

    local headers = {
        { text = "日期", justify = "LEFT" },
        { text = "收盘", justify = "RIGHT" },
        { text = "开盘", justify = "RIGHT" },
        { text = "最高", justify = "RIGHT" },
        { text = "最低", justify = "RIGHT" },
        { text = "涨跌", justify = "RIGHT" },
    }
    local tableFrame = CreateFrame("Frame", nil, historyPage)
    tableFrame:SetPoint("TOPLEFT", histControls, "BOTTOMLEFT", 0, -4)
    tableFrame:SetPoint("BOTTOMRIGHT", historyPage, "BOTTOMRIGHT", -8, 10)
    historyPage.tableFrame = tableFrame

    local headerRow = CreateFrame("Frame", nil, tableFrame)
    headerRow:SetPoint("TOPLEFT", tableFrame, "TOPLEFT", 0, 0)
    headerRow:SetPoint("TOPRIGHT", tableFrame, "TOPRIGHT", 0, 0)
    headerRow:SetHeight(22)
    historyPage.headerCells = {}
    for i, def in ipairs(headers) do
        local fs = EA_ChartText(headerRow, 11, "accent")
        fs:SetJustifyH(def.justify)
        fs:SetText(def.text)
        historyPage.headerCells[i] = fs
    end
    historyPage.rows = {}
    for r = 1, EA_CHART_ROWS do
        local rowFrame = CreateFrame("Frame", nil, tableFrame)
        rowFrame:SetPoint("TOPLEFT", headerRow, "BOTTOMLEFT", 0, -(r - 1) * 23)
        rowFrame:SetPoint("TOPRIGHT", headerRow, "BOTTOMRIGHT", 0, -(r - 1) * 23)
        rowFrame:SetHeight(22)
        rowFrame.bg = rowFrame:CreateTexture(nil, "BACKGROUND")
        rowFrame.bg:SetAllPoints()
        if EAStyle then EAStyle:RowColor(rowFrame.bg, r, false) end
        rowFrame.cols = {}
        for c = 1, #headers do
            local fs = EA_ChartText(rowFrame, 11, c == 1 and "text" or "muted")
            fs:SetJustifyH(headers[c].justify)
            rowFrame.cols[c] = fs
        end
        historyPage.rows[r] = rowFrame
    end
    function historyPage:PositionCells(cells)
        local W = self.tableFrame:GetWidth()
        if W <= 0 then return false end
        local pad = 6
        local dateRight = W * 0.26
        local numW = (W - pad - dateRight) / (#headers - 1)
        for i, fs in ipairs(cells) do
            fs:ClearAllPoints()
            fs:SetJustifyH(headers[i].justify)
            if i == 1 then
                fs:SetPoint("LEFT", fs:GetParent(), "LEFT", pad, 0)
            else
                fs:SetPoint("RIGHT", fs:GetParent(), "LEFT", dateRight + numW * (i - 1), 0)
            end
        end
        return true
    end
    function historyPage:LayoutColumns()
        if not self:PositionCells(self.headerCells) then return end
        for i = 1, #self.rows do
            self:PositionCells(self.rows[i].cols)
        end
    end
    historyPage:SetScript("OnSizeChanged", function(self)
        self:LayoutColumns()
    end)
    historyPage.empty = EA_ChartText(historyPage, 13, "muted")
    historyPage.empty:SetPoint("TOP", headerRow, "BOTTOM", 0, -30)
    historyPage.empty:SetText("暂无价格历史")

    statsPage:SetScript("OnSizeChanged", function()
        EA_LayoutStatsTicks(statsPage)
    end)

    frame.EAState = { page = "chart", mode = "line", candleGroup = "hour", historyGroup = "day", historyPage = 1, showMA7 = true, showMA30 = true, rangeDays = 30, samples = {}, rawPoints = {} }
    return frame
end

function EasyAuction_ShowChart(itemName)
    local db = _G.EasyAuctionDB
    if not db or not db.DailyMinPrice then
        print("|cff00ff00[EasyAuction]|r 数据库未初始化。")
        return
    end
    local dailyArray = EasyAuction_GetDailyMinPrice and EasyAuction_GetDailyMinPrice(itemName, db) or db.DailyMinPrice[itemName]
    local samples = EA_BuildChartSamples(dailyArray)
    if #samples == 0 then
        if EasyAuction_ChartFrame and EasyAuction_ChartFrame:IsShown() then EasyAuction_ChartFrame:Hide() end
        print("|cff00ff00[EasyAuction]|r 暂无此物品每日价格数据。")
        return
    end
    local frame = EasyAuction_ChartFrame or EA_BuildTokenChartFrame()
    frame.EAState.db = db
    frame.EAState.itemName = itemName
    frame.EAState.samples = samples
    frame.EAState.rawPoints = EA_BuildRawChartPoints(db, itemName, samples)
    frame.EAState.historyPage = 1
    local cleanName = tostring(itemName or ""):gsub(":%d+$", "")
    frame.itemIcon:SetTexture(EA_GetChartItemIcon(itemName, cleanName))
    frame.title:SetText(cleanName .. " 价格走势")
    EA_RefreshTokenHeader(frame)
    EA_RaiseChartFrame(frame)
    frame:Show()
    EA_RaiseChartFrame(frame)
    EA_ShowTokenChartPage(frame, frame.EAState.page or "chart")
end
