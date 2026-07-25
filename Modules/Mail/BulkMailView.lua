local _, ns = ...

ns = ns or {}
ns.Mail = ns.Mail or {}
local Mail = ns.Mail

local BulkMailView = {}
BulkMailView.__index = BulkMailView

local ROOT_WIDTH, ROOT_HEIGHT = 774, 388
local GRID_COLUMNS, GRID_ROWS = 4, 10
local CELL_WIDTH, CELL_HEIGHT = 102, 20
local CELL_X_STEP, CELL_Y_STEP = 104, 24
local CELL_START_X, CELL_START_Y = 6, -6
local BULK_AMOUNT_FRAME_NAME = "EasyAuctionBulkMailAmountInput"
local DEFAULT_SUBJECT = "金币邮寄"
local DEFAULT_BODY = "你好，这是本次批量邮寄的金币，请查收。"
local BODY_TEXT_COLOR = { 0.42, 0.24, 0.08 }

local STATUS_TEXT = {
    PENDING = "待发送", PREPARING = "准备中", WAITING_USER_ACTION = "点击继续",
    WAITING_SECURE_CONFIRM = "等待确认", AWAITING_ACK = "发送中", SUCCEEDED = "成功",
    FAILED = "失败", UNKNOWN = "结果未知", CANCELLED = "已取消", SKIPPED = "已跳过",
}

local STATUS_COLOR = {
    PENDING = { 0.7, 0.7, 0.7 }, PREPARING = { 1, 0.82, 0 },
    WAITING_USER_ACTION = { 0.3, 0.8, 1 }, WAITING_SECURE_CONFIRM = { 1, 0.45, 0.2 },
    AWAITING_ACK = { 0.3, 0.8, 1 }, SUCCEEDED = { 0.2, 1, 0.2 }, FAILED = { 1, 0.25, 0.25 },
    UNKNOWN = { 1, 0.55, 0.1 }, CANCELLED = { 0.55, 0.55, 0.55 }, SKIPPED = { 0.55, 0.55, 0.55 },
}

local STATUS_TEXTURE = {
    PENDING = "Interface/Common/Indicator-Gray",
    PREPARING = "Interface/Common/Indicator-Yellow",
    WAITING_USER_ACTION = "Interface/Common/Indicator-Yellow",
    WAITING_SECURE_CONFIRM = "Interface/Common/Indicator-Red",
    AWAITING_ACK = "Interface/Common/Indicator-Yellow",
    SUCCEEDED = "Interface/RaidFrame/ReadyCheck-Ready",
    FAILED = "Interface/RaidFrame/ReadyCheck-NotReady",
    UNKNOWN = "Interface/Buttons/UI-GroupLoot-Pass-Up",
    CANCELLED = "Interface/RaidFrame/ReadyCheck-Waiting",
    SKIPPED = "Interface/RaidFrame/ReadyCheck-Waiting",
}

local HISTORY_SOURCE_LABEL = {
    raid = "团队",
    party = "小队",
    guild = "公会",
    custom = "自定",
}

local function formatBatchTitle(record, timestamp)
    local source = HISTORY_SOURCE_LABEL[record.sourceKind] or tostring(record.sourceKind or "")
    local text = string.format("%s %s %d人 成%d败%d", timestamp, source,
        record.selectedCount or #(record.recipients or {}), record.successCount or 0,
        record.failedCount or 0)
    local unknown = tonumber(record.unknownCount) or 0
    local cancelled = tonumber(record.cancelledCount) or 0
    if unknown > 0 then text = text .. " 未" .. unknown end
    if cancelled > 0 then text = text .. " 取" .. cancelled end
    return text
end

local function truncateUTF8(value, maximum)
    value = tostring(value or "")
    local index, characters = 1, 0
    while index <= #value and characters < maximum do
        local byte = string.byte(value, index)
        local width = byte < 0x80 and 1 or byte < 0xE0 and 2 or byte < 0xF0 and 3 or 4
        index = index + width
        characters = characters + 1
    end
    if index <= #value then return string.sub(value, 1, index - 1) .. "..." end
    return value
end

local function clone(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = clone(item) end
    return result
end

local function formatMoney(amount)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if type(_G.GetCoinTextureString) == "function" then
        local ok, value = pcall(_G.GetCoinTextureString, amount, 14)
        if ok and type(value) == "string" then return value end
    end
    return tostring(amount) .. " 铜"
end

local function ensureBulkConfirmRows(popup)
    if popup.easyAuctionBulkRows then return popup.easyAuctionBulkRows end
    local rows = {}
    for index = 1, 5 do
        local row = {}
        local y = -58 - (index - 1) * 24
        if index == 5 then y = y - 10 end
        row.label = popup:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        row.label:SetPoint("TOPLEFT", popup, "TOPLEFT", 20, y)
        row.label:SetSize(104, 22)
        row.label:SetJustifyH("CENTER")
        row.value = popup:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        row.value:SetPoint("TOPLEFT", popup, "TOPLEFT", 132, y)
        row.value:SetSize(168, 22)
        row.value:SetJustifyH("RIGHT")
        rows[index] = row
    end
    popup.easyAuctionBulkRows = rows
    return rows
end

local function showBulkConfirmRows(popup, data)
    if not popup then return end
    popup:SetHeight(250)
    local rows = ensureBulkConfirmRows(popup)
    local values = data and data.rows or {}
    for index = 1, #rows do
        local rowData = values[index] or {}
        local row = rows[index]
        row.label:SetText(rowData.label or "")
        row.value:SetText(rowData.value or "")
        if index == 5 then
            row.label:SetTextColor(1, 0.82, 0)
            row.value:SetTextColor(1, 0.82, 0)
        else
            row.label:SetTextColor(1, 1, 1)
            row.value:SetTextColor(1, 1, 1)
        end
        row.label:Show()
        row.value:Show()
    end
end

local function hideBulkConfirmRows(popup)
    for _, row in ipairs(popup and popup.easyAuctionBulkRows or {}) do
        row.label:Hide()
        row.value:Hide()
    end
end

function BulkMailView:_readAmount()
    if self.frame and self.amountUsesMoneyFrame and type(_G.MoneyInputFrame_GetCopper) == "function" then
        return math.max(0, math.floor(tonumber(_G.MoneyInputFrame_GetCopper(self.frame.amount)) or 0))
    end
    if self.frame and self.frame.amount and self.frame.amount.GetText then
        return math.max(0, math.floor(tonumber(self.frame.amount:GetText()) or 0))
    end
    return 0
end

function BulkMailView:_refreshTotalAmount()
    if not self.frame or not self.frame.totalAmount then return end
    local count = self.model and self.model:GetSelectionCount() or 0
    local postageEach = type(self.deps.getPostageEach) == "function"
        and math.max(0, math.floor(tonumber(self.deps.getPostageEach()) or 0)) or 0
    local postage = postageEach * count
    self.frame.totalPostage:SetText("合计邮资成本：" .. formatMoney(postage))
    self.frame.totalAmount:SetText("总支出：" .. formatMoney((self:_readAmount() + postageEach) * count))
end

function BulkMailView:_applyInitialExamples()
    if self.initialExamplesApplied or not self.frame then return end
    if self.frame.subject and self.frame.subject:GetText() == "" then
        self.frame.subject:SetText(DEFAULT_SUBJECT)
    end
    if self.frame.body and self.frame.body:GetText() == "" then
        self.frame.body:SetText(DEFAULT_BODY)
    end
    self.initialExamplesApplied = true
end

function BulkMailView.BuildBindings(snapshot, rowOffset)
    snapshot = snapshot or {}
    local members = snapshot.members or {}
    local bindings = {}
    rowOffset = math.max(0, math.floor(tonumber(rowOffset) or 0))
    if snapshot.sourceKind == "raid" then
        local groups = {}
        for subgroup = 1, 8 do groups[subgroup] = {} end
        for index = 1, #members do
            local subgroup = math.max(1, math.min(8, tonumber(members[index].subgroup) or 1))
            groups[subgroup][#groups[subgroup] + 1] = members[index]
        end
        local byCell = {}
        for subgroup = 1, 8 do
            local segmentOffset = subgroup > 4 and 20 or 0
            local column = (subgroup - 1) % 4 + 1
            for row = 1, 5 do
                local member = groups[subgroup][row]
                if member then
                    local cellIndex = segmentOffset + (row - 1) * 4 + column
                    byCell[cellIndex] = { cellIndex = cellIndex, member = clone(member) }
                end
            end
        end
        for cellIndex = 1, 40 do
            if byCell[cellIndex] then bindings[#bindings + 1] = byCell[cellIndex] end
        end
        return bindings
    end
    local first = rowOffset * GRID_COLUMNS + 1
    for logicalIndex = first, math.min(#members, first + 39) do
        bindings[#bindings + 1] = {
            cellIndex = logicalIndex - first + 1,
            logicalIndex = logicalIndex,
            member = clone(members[logicalIndex]),
        }
    end
    return bindings
end

function BulkMailView.New(deps)
    deps = deps or {}
    return setmetatable({
        deps = deps,
        model = deps.selectionModel,
        rowOffset = 0,
        cells = {},
        bindings = {},
        focusedCell = 1,
        focusedRecipientKey = nil,
        enabled = true,
        filter = clone(deps.initialFilter or {}),
        mode = "compose",
        historyOffset = 0,
        historyDetailOffset = 0,
        selectedHistoryId = nil,
    }, BulkMailView)
end

local function setText(fontString, text)
    if fontString and fontString.SetText then fontString:SetText(text or "") end
end

local function setFittedText(fontString, text)
    if not fontString or not fontString.SetText then return end
    text = tostring(text or "")
    local characterLimit = 12
    fontString:SetText(truncateUTF8(text, characterLimit))
    if type(fontString.GetStringWidth) ~= "function" or type(fontString.GetWidth) ~= "function" then
        fontString:SetText(truncateUTF8(text, 6))
        return
    end
    local availableWidth = tonumber(fontString:GetWidth()) or 0
    if availableWidth <= 0 then return end
    while characterLimit > 0 and fontString:GetStringWidth() > availableWidth do
        characterLimit = characterLimit - 1
        fontString:SetText(truncateUTF8(text, characterLimit))
    end
    if fontString:GetStringWidth() > availableWidth then fontString:SetText("") end
end

local function createWithTemplate(createFrame, frameType, parent, template, fallbackTemplate, globalName)
    local ok, widget = pcall(createFrame, frameType, globalName, parent, template)
    if ok and widget then return widget, true end
    return createFrame(frameType, nil, parent, fallbackTemplate), false
end

local function getScrollMaximum(sourceKind, memberCount)
    if sourceKind == "party" or sourceKind == "raid" then return 0 end
    return math.max(0, math.ceil(math.max(0, memberCount or 0) / GRID_COLUMNS) - GRID_ROWS)
end

local function createSelectionLayer(button)
    local layer = button:CreateTexture(nil, "ARTWORK")
    layer:SetAllPoints(button)
    layer:SetColorTexture(1, 0.72, 0.12, 0.22)
    layer:Hide()
    button.selectionLayer = layer
end

local function setButtonSelected(button, selected)
    if not button then return end
    button.selected = selected == true
    if button.SetEnabled then button:SetEnabled(true) end
    if button.selectionLayer then button.selectionLayer:SetShown(button.selected) end
    local label = button.GetFontString and button:GetFontString()
    if label and label.SetTextColor then
        if button.selected then label:SetTextColor(1, 0.82, 0)
        else label:SetTextColor(1, 1, 1) end
    end
end

function BulkMailView:_layoutCells(sourceKind)
    if not self.frame or not self.frame.grid then return end
    for index = 1, 40 do
        local cell = self.cells[index]
        local row, column
        if sourceKind == "party" then
            row, column = index - 1, 0
        elseif sourceKind == "raid" and index > 20 then
            row, column = math.floor((index - 21) / 4), (index - 21) % 4
        else
            row, column = math.floor((index - 1) / 4), (index - 1) % 4
        end
        local y
        if sourceKind == "raid" then
            y = index > 20 and (-140 - row * 22) or (-18 - row * 22)
        else
            y = CELL_START_Y - row * CELL_Y_STEP
        end
        cell:ClearAllPoints()
        cell:SetPoint("TOPLEFT", self.frame.grid, "TOPLEFT", CELL_START_X + column * CELL_X_STEP, y)
    end
    for subgroup = 1, #(self.frame.groupHeaders or {}) do
        local header = self.frame.groupHeaders[subgroup]
        local column = (subgroup - 1) % 4
        local y = subgroup > 4 and -124 or -2
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", self.frame.grid, "TOPLEFT", CELL_START_X + column * CELL_X_STEP, y)
    end
end

function BulkMailView:_createCell(parent, index, createFrame)
    local cell = createFrame("Button", nil, parent, "BackdropTemplate")
    cell:SetSize(CELL_WIDTH, CELL_HEIGHT)
    local row = math.floor((index - 1) / GRID_COLUMNS)
    local column = (index - 1) % GRID_COLUMNS
    cell:SetPoint("TOPLEFT", parent, "TOPLEFT", CELL_START_X + column * CELL_X_STEP,
        CELL_START_Y - row * CELL_Y_STEP)
    if cell.SetBackdrop then
        cell:SetBackdrop({
            bgFile = "Interface/Buttons/WHITE8X8",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            edgeSize = 8,
        })
        cell:SetBackdropColor(0.05, 0.05, 0.05, 0.75)
        cell:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
    end
    cell.check = createFrame("CheckButton", nil, cell, "UICheckButtonTemplate")
    cell.check:SetPoint("LEFT", 0, 0)
    cell.check:SetSize(20, 20)
    cell.name = cell:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cell.name:SetPoint("LEFT", cell.check, "RIGHT", -1, 0)
    cell.name:SetWidth(CELL_WIDTH - 38)
    cell.name:SetJustifyH("LEFT")
    if cell.name.SetWordWrap then cell.name:SetWordWrap(false) end
    if cell.name.SetMaxLines then cell.name:SetMaxLines(1) end
    cell.stateIcon = cell:CreateTexture(nil, "ARTWORK")
    cell.stateIcon:SetSize(12, 12)
    cell.stateIcon:SetPoint("RIGHT", cell, "RIGHT", -3, 0)
    cell.status = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cell.status:SetPoint("CENTER", cell.stateIcon, "CENTER", 0, 0)
    cell.status:SetJustifyH("CENTER")
    if cell.status.SetWordWrap then cell.status:SetWordWrap(false) end
    if cell.status.SetMaxLines then cell.status:SetMaxLines(1) end
    local cellIndex = index
    local function toggle()
        local binding = self.bindings[cellIndex]
        if binding and binding.member and self.model then
            local toggled, toggleError = self.model:Toggle(binding.member.recipientKey)
            if not toggled and toggleError then self:ShowError(toggleError) else self:ShowError(nil) end
            self.focusedCell = cellIndex
            self.focusedRecipientKey = binding.member.recipientKey
            self:Refresh()
        end
    end
    cell:SetScript("OnClick", toggle)
    cell.check:SetScript("OnClick", toggle)
    cell:SetScript("OnEnter", function()
        local binding = self.bindings[cellIndex]
        local status = binding and binding.member and self.model
            and self.model:GetRecipientStatus(binding.member.recipientKey)
        if binding and binding.member and _G.GameTooltip then
            _G.GameTooltip:SetOwner(cell, "ANCHOR_RIGHT")
            _G.GameTooltip:SetText(binding.member.displayName or binding.member.sendName or "")
            if binding.member.isSelf then
                _G.GameTooltip:AddLine("当前角色（不可选择）", 0.7, 0.7, 0.7)
            end
            if status then
                _G.GameTooltip:AddLine(STATUS_TEXT[status.state] or status.state or "", 1, 1, 1)
                if status.errorCode then _G.GameTooltip:AddLine("错误代码：" .. status.errorCode, 1, 0.35, 0.35) end
                if status.errorMessage then _G.GameTooltip:AddLine(status.errorMessage, 1, 0.75, 0.75, true) end
                if status.attemptCount then
                    _G.GameTooltip:AddLine("尝试次数：" .. status.attemptCount, 0.8, 0.8, 0.8)
                end
            end
            _G.GameTooltip:Show()
        end
    end)
    cell:SetScript("OnLeave", function() if _G.GameTooltip then _G.GameTooltip:Hide() end end)
    return cell
end

function BulkMailView:Create(parent)
    if self.frame then return self.frame end
    local createFrame = self.deps.CreateFrame or _G.CreateFrame
    if type(createFrame) ~= "function" then return nil end
    local frame = createFrame("Frame", nil, parent)
    frame:SetSize(ROOT_WIDTH, ROOT_HEIGHT)
    frame:EnableMouseWheel(true)
    if frame.EnableKeyboard then frame:EnableKeyboard(true) end
    if frame.SetPropagateKeyboardInput then frame:SetPropagateKeyboardInput(true) end
    self.frame = frame

    frame.composeTab = createFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.composeTab:SetSize(96, 22)
    frame.composeTab:SetPoint("TOPLEFT", frame, "TOPLEFT", 40, 0)
    frame.composeTab:SetText("批量邮寄")
    createSelectionLayer(frame.composeTab)
    frame.composeTab:SetScript("OnClick", function() self:SetMode("compose") end)
    frame.historyTab = createFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.historyTab:SetSize(96, 22)
    frame.historyTab:SetPoint("LEFT", frame.composeTab, "RIGHT", 2, 0)
    frame.historyTab:SetText("邮寄记录")
    createSelectionLayer(frame.historyTab)
    frame.historyTab:SetScript("OnClick", function() self:SetMode("history") end)

    local sourceLabels = { { "raid", "团队" }, { "guild", "公会" }, { "custom", "自定义组" } }
    frame.sourceButtons = {}
    for index = 1, #sourceLabels do
        local descriptor = sourceLabels[index]
        local button = createFrame("Button", nil, frame, "UIPanelButtonTemplate")
        button:SetSize(78, 22)
        button:SetPoint("TOPLEFT", frame, "TOPLEFT", 304 + (index - 1) * 80, 0)
        button.sourceKind = descriptor[1]
        button:SetText(descriptor[2])
        createSelectionLayer(button)
        button:SetScript("OnClick", function()
            if self.batchState and (self.batchState.state == "COMPLETED" or self.batchState.state == "PARTIAL"
                or self.batchState.state == "STOPPED") then
                self:StartNewBatch()
            end
            if descriptor[1] == "custom" then
                self:ToggleGroupMenu()
                return
            end
            self.rowOffset = 0
            if self.model then self.model:SetSource(descriptor[1]) end
            if self.deps.onSourceChanged then self.deps.onSourceChanged(descriptor[1]) end
            if self.model then self.model:SetFilter(self.filter) end
            self:Refresh()
        end)
        frame.sourceButtons[index] = button
        if descriptor[1] == "custom" then self.customSourceButton = button end
    end

    frame.loading = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.loading:SetPoint("TOPLEFT", frame, "TOPLEFT", 462, -176)
    frame.loading:SetText("正在刷新名单")
    frame.loading:Hide()

    frame.rankButton = createFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.rankButton:SetSize(112, 22)
    frame.rankButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 304, -28)
    frame.rankButton:SetText("会阶筛选")
    frame.rankButton:SetScript("OnClick", function() self:ToggleRankMenu() end)
    frame.onlineOnly = createFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    frame.onlineOnly:SetSize(24, 24)
    frame.onlineOnly:SetPoint("TOPLEFT", frame, "TOPLEFT", 420, -27)
    frame.onlineOnly.text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.onlineOnly.text:SetPoint("LEFT", frame.onlineOnly, "RIGHT", -2, 0)
    frame.onlineOnly.text:SetText("仅在线")
    frame.onlineOnly:SetScript("OnClick", function(button)
        self.filter.onlineOnly = button:GetChecked() == true
        if self.model then self.model:SetFilter(self.filter) end
        self.rowOffset = 0
        self:Refresh()
    end)

    frame.search, self.searchUsesNativeTemplate = createWithTemplate(createFrame, "EditBox", frame,
        "SearchBoxTemplate", "InputBoxTemplate")
    frame.search:SetSize(180, 22)
    frame.search:SetPoint("TOPLEFT", frame, "TOPLEFT", 550, -28)
    frame.search:SetAutoFocus(false)
    frame.search:SetScript("OnTextChanged", function(box)
        self.filter.query = box:GetText() or ""
        if self.model then self.model:SetFilter(self.filter) end
        self.rowOffset = 0
        self:Refresh()
    end)

    frame.grid = createFrame("Frame", nil, frame, "InsetFrameTemplate")
    frame.grid:SetSize(442, 250)
    frame.grid:SetPoint("TOPLEFT", frame, "TOPLEFT", 304, -58)
    frame.groupHeaders = {}
    for subgroup = 1, 8 do
        local header = frame.grid:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        local column = (subgroup - 1) % 4
        header:SetPoint("TOPLEFT", frame.grid, "TOPLEFT", CELL_START_X + column * CELL_X_STEP,
            subgroup > 4 and -124 or -2)
        header:SetWidth(CELL_WIDTH)
        header:SetJustifyH("CENTER")
        header:SetText(subgroup .. "组")
        frame.groupHeaders[subgroup] = header
    end
    for index = 1, 40 do self.cells[index] = self:_createCell(frame.grid, index, createFrame) end

    frame.scroll = createFrame("Slider", nil, frame, "UIPanelScrollBarTemplate")
    frame.scroll:SetPoint("TOPLEFT", frame.grid, "TOPRIGHT", 2, -14)
    frame.scroll:SetPoint("BOTTOMLEFT", frame.grid, "BOTTOMRIGHT", 2, 14)
    frame.scroll:SetMinMaxValues(0, 0)
    frame.scroll:SetValueStep(1)
    frame.scroll:SetScript("OnValueChanged", function(_, value)
        local offset = math.floor(value + 0.5)
        if offset ~= self.rowOffset then self.rowOffset = offset self:Refresh() end
    end)

    frame.subjectLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.subjectLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -34)
    frame.subjectLabel:SetText("主题")
    frame.amountLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.amountLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -278)
    frame.amountLabel:SetText("单人金额")
    frame.subject = createFrame("EditBox", nil, frame, "InputBoxTemplate")
    frame.subject:SetSize(242, 22)
    frame.subject:SetPoint("TOPLEFT", frame, "TOPLEFT", 48, -30)
    frame.subject:SetAutoFocus(false)
    frame.amount, self.amountUsesMoneyFrame = createWithTemplate(createFrame, "Frame", frame,
        "MoneyInputFrameTemplate", nil, BULK_AMOUNT_FRAME_NAME)
    if not self.amountUsesMoneyFrame or type(_G.MoneyInputFrame_GetCopper) ~= "function" then
        frame.amount:Hide()
        frame.amount = createFrame("EditBox", nil, frame, "InputBoxTemplate")
        self.amountUsesMoneyFrame = false
    end
    frame.amount:SetSize(196, 24)
    frame.amount:SetPoint("TOPLEFT", frame, "TOPLEFT", 76, -272)
    if self.amountUsesMoneyFrame then
        local silver = frame.amount.silver or _G[BULK_AMOUNT_FRAME_NAME .. "Silver"]
        local copper = frame.amount.copper or _G[BULK_AMOUNT_FRAME_NAME .. "Copper"]
        if silver and silver.SetWidth then silver:SetWidth(38) end
        if copper and copper.SetWidth then copper:SetWidth(38) end
        if type(_G.MoneyInputFrame_SetOnValueChangedFunc) == "function" then
            _G.MoneyInputFrame_SetOnValueChangedFunc(frame.amount, function() self:_refreshTotalAmount() end)
        end
    else
        frame.amount:SetAutoFocus(false)
        frame.amount:SetNumeric(true)
        frame.amount:SetMaxLetters(10)
        frame.amount:SetScript("OnTextChanged", function() self:_refreshTotalAmount() end)
        frame.amountLabel:SetText("单人金额（铜）")
    end
    frame.totalPostage = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.totalPostage:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -300)
    frame.totalPostage:SetSize(286, 18)
    frame.totalPostage:SetJustifyH("LEFT")
    frame.totalAmount = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.totalAmount:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -318)
    frame.totalAmount:SetSize(286, 18)
    frame.totalAmount:SetJustifyH("LEFT")

    frame.bodyPaper = createFrame("Frame", nil, frame)
    frame.bodyPaper:SetSize(286, 205)
    frame.bodyPaper:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -58)
    frame.bodyPaper.leftTexture = frame.bodyPaper:CreateTexture(nil, "BACKGROUND")
    frame.bodyPaper.leftTexture:SetTexture("Interface\\Stationery\\stationerytest1")
    frame.bodyPaper.leftTexture:SetPoint("TOPLEFT", frame.bodyPaper, "TOPLEFT", 0, 0)
    frame.bodyPaper.leftTexture:SetSize(222, 205)
    frame.bodyPaper.leftTexture:SetTexCoord(0, 222 / 252, 0, 205 / 256)
    frame.bodyPaper.rightTexture = frame.bodyPaper:CreateTexture(nil, "BACKGROUND")
    frame.bodyPaper.rightTexture:SetTexture("Interface\\Stationery\\stationerytest2")
    frame.bodyPaper.rightTexture:SetPoint("TOPLEFT", frame.bodyPaper.leftTexture, "TOPRIGHT", 0, 0)
    frame.bodyPaper.rightTexture:SetSize(64, 205)
    frame.bodyPaper.rightTexture:SetTexCoord(0, 1, 0, 205 / 256)

    local bodyContainer, bodyUsesNativeTemplate = createWithTemplate(createFrame, "Frame", frame,
        "ScrollingEditBoxTemplate", nil)
    local bodyEditBox = bodyUsesNativeTemplate and bodyContainer.GetEditBox and bodyContainer:GetEditBox()
    if not bodyEditBox then
        bodyContainer:Hide()
        bodyContainer = createFrame("EditBox", nil, frame, "InputBoxTemplate")
        bodyEditBox = bodyContainer
    end
    frame.bodyContainer, frame.body = bodyContainer, bodyEditBox
    bodyContainer:SetSize(240, 190)
    bodyContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -69)
    frame.body:SetAutoFocus(false)
    if frame.body.SetMultiLine then frame.body:SetMultiLine(true) end
    if frame.body.SetMaxLetters then frame.body:SetMaxLetters(500) end
    if frame.body.SetFontObject then frame.body:SetFontObject(_G.MailTextFontNormal or "MailTextFontNormal") end
    if frame.body.SetTextColor then
        frame.body:SetTextColor(unpack(BODY_TEXT_COLOR))
    end
    frame.bodyPaper:SetScript("OnMouseDown", function()
        if frame.body and frame.body.SetFocus then frame.body:SetFocus() end
    end)
    frame.bodyScrollBar = createFrame("EventFrame", nil, frame, "WowClassicScrollBar")
    frame.bodyScrollBar:SetWidth(18)
    frame.bodyScrollBar:SetPoint("TOPLEFT", bodyContainer, "TOPRIGHT", 7, 14)
    frame.bodyScrollBar:SetPoint("BOTTOMLEFT", bodyContainer, "BOTTOMRIGHT", 7, 0)
    if bodyUsesNativeTemplate and bodyContainer.ScrollBox and _G.ScrollUtil
        and type(_G.ScrollUtil.RegisterScrollBoxWithScrollBar) == "function" then
        _G.ScrollUtil.RegisterScrollBoxWithScrollBar(bodyContainer.ScrollBox, frame.bodyScrollBar)
    end
    self:_applyInitialExamples()

    frame.errorBanner = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.errorBanner:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -338)
    frame.errorBanner:SetSize(286, 16)
    frame.errorBanner:SetJustifyH("LEFT")
    if frame.errorBanner.SetJustifyV then frame.errorBanner:SetJustifyV("TOP") end
    if frame.errorBanner.SetWordWrap then frame.errorBanner:SetWordWrap(true) end
    if frame.errorBanner.SetMaxLines then frame.errorBanner:SetMaxLines(1) end
    frame.errorBanner:SetTextColor(1, 0.25, 0.25)
    frame.errorBanner:SetText("")

    frame.selectAll = createFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.selectAll:SetSize(88, 22)
    frame.selectAll:SetPoint("TOPLEFT", frame, "TOPLEFT", 304, -326)
    frame.selectAll:SetText("全选")
    frame.selectAll:SetScript("OnClick", function()
        if not self.model then return end
        local result = self.model:SelectFiltered()
        if result and result.error then self:ShowError(result.error) else self:ShowError(nil) end
        self:Refresh()
    end)
    frame.clear = createFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.clear:SetSize(88, 22)
    frame.clear:SetPoint("LEFT", frame.selectAll, "RIGHT", 2, 0)
    frame.clear:SetText("取消全选")
    frame.clear:SetScript("OnClick", function()
        if not self.model then return end
        self.model:ClearFiltered()
        self:ShowError(nil)
        self:Refresh()
    end)
    frame.send = createFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.send:SetSize(286, 24)
    frame.send:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -360)
    frame.send:SetText("开始批量邮寄")
    frame.send:SetScript("OnClick", function() self:ConfirmStart() end)
    frame.summary = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.summary:SetPoint("TOPLEFT", frame, "TOPLEFT", 304, -364)
    frame.summary:SetSize(442, 18)
    frame.summary:SetJustifyH("LEFT")
    frame.selectionSummary = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.selectionSummary:SetPoint("TOPLEFT", frame, "TOPLEFT", 488, -330)
    frame.selectionSummary:SetSize(180, 18)
    frame.selectionSummary:SetJustifyH("LEFT")

    self:_createHistoryPanel(frame, createFrame)
    self.composeWidgets = {
        frame.grid, frame.scroll, frame.search, frame.subject, frame.amount, frame.bodyPaper,
        frame.bodyContainer, frame.bodyScrollBar, frame.subjectLabel,
        frame.amountLabel, frame.totalPostage, frame.totalAmount,
        frame.selectAll, frame.clear, frame.send, frame.summary,
        frame.selectionSummary,
        frame.errorBanner, frame.rankButton, frame.onlineOnly, frame.onlineOnly.text,
        frame.loading,
    }
    for index = 1, #frame.groupHeaders do self.composeWidgets[#self.composeWidgets + 1] = frame.groupHeaders[index] end
    for index = 1, #frame.sourceButtons do
        self.composeWidgets[#self.composeWidgets + 1] = frame.sourceButtons[index]
    end

    frame:SetScript("OnMouseWheel", function(_, delta) self:ScrollRows(delta > 0 and -1 or 1) end)
    frame:SetScript("OnKeyDown", function(widget, key)
        local handled = self:OnKeyDown(key)
        if widget.SetPropagateKeyboardInput then widget:SetPropagateKeyboardInput(not handled) end
    end)
    self:SetMode("compose")
    self:Refresh()
    local skinCompat = self.deps.skinCompat or Mail.SkinCompat
    if skinCompat and type(skinCompat.SkinBulk) == "function" then
        skinCompat:SkinBulk(self)
    end
    return frame
end

function BulkMailView:ConfirmRetryFailed()
    if not self.selectedHistoryId or not self.deps.onPrepareRetryFailed then return false end
    local plan, err = self.deps.onPrepareRetryFailed(self.selectedHistoryId)
    if not plan then self:ShowError(err) return nil, err end
    local names = {}
    for index = 1, math.min(8, #(plan.recipients or {})) do
        local recipient = plan.recipients[index]
        names[#names + 1] = recipient.displayName or recipient.sendName or recipient.recipientKey
    end
    local remaining = #(plan.recipients or {}) - #names
    local nameText = table.concat(names, "、")
    if remaining > 0 then nameText = nameText .. "，另 " .. remaining .. " 人" end
    local summary = string.format(
        "确认仅重试以下 %d 名明确失败收件人？\n名单：%s\n单人金额：%s\n合计金额：%s",
        #(plan.recipients or {}), nameText, formatMoney(plan.amountEach),
        formatMoney((tonumber(plan.amountEach) or 0) * #(plan.recipients or {})))
    if not _G.StaticPopupDialogs or not _G.StaticPopup_Show then
        local unavailable = { code = "CONFIRMATION_UNAVAILABLE", message = "当前客户端无法显示重试确认框" }
        self:ShowError(unavailable)
        return nil, unavailable
    end
    if not _G.StaticPopupDialogs.EASYAUCTION_BULK_RETRY_CONFIRM then
        _G.StaticPopupDialogs.EASYAUCTION_BULK_RETRY_CONFIRM = {
            text = "%s", button1 = _G.ACCEPT or "确定", button2 = _G.CANCEL or "取消",
            OnAccept = function(_, data)
                if not data or not data.view or not data.plan then return end
                local batchId, retryError = data.view.deps.onRetryFailed(data.plan)
                if not batchId and retryError then data.view:ShowError(retryError)
                else data.view:ShowError(nil) end
                data.view:RefreshHistory()
            end,
            timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
        }
    end
    _G.StaticPopup_Show("EASYAUCTION_BULK_RETRY_CONFIRM", summary, nil, {
        view = self,
        plan = clone(plan),
    })
    return true
end

function BulkMailView:_createHistoryPanel(frame, createFrame)
    local panel = createFrame("Frame", nil, frame)
    panel:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -30)
    panel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    frame.historyPanel = panel
    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.title:SetPoint("TOPLEFT", 10, -4)
    panel.title:SetText("批次记录")
    panel.detailTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    panel.detailTitle:SetPoint("TOPLEFT", 276, -4)
    panel.detailTitle:SetText("发送结果")
    panel.retry = createFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panel.retry:SetSize(130, 24)
    panel.retry:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 8)
    panel.retry:SetText("仅重试明确失败")
    panel.retry:SetScript("OnClick", function() self:ConfirmRetryFailed() end)
    panel.newBatch = createFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panel.newBatch:SetSize(90, 24)
    panel.newBatch:SetPoint("RIGHT", panel.retry, "LEFT", -4, 0)
    panel.newBatch:SetText("新建批次")
    panel.newBatch:SetScript("OnClick", function() self:StartNewBatch() end)
    panel.error = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    panel.error:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 8, 12)
    panel.error:SetPoint("RIGHT", panel.newBatch, "LEFT", -8, 0)
    panel.error:SetJustifyH("LEFT")
    panel.error:SetTextColor(1, 0.25, 0.25)
    panel.batchListFrame = createFrame("Frame", nil, panel, "InsetFrameTemplate")
    panel.batchListFrame:SetSize(252, 252)
    panel.batchListFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -24)
    panel.detailListFrame = createFrame("Frame", nil, panel, "InsetFrameTemplate")
    panel.detailListFrame:SetSize(488, 252)
    panel.detailListFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 270, -24)
    panel.batchEmpty = panel.batchListFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    panel.batchEmpty:SetPoint("CENTER", panel.batchListFrame, "CENTER", 0, 0)
    panel.batchEmpty:SetText("暂无批量邮寄记录")
    panel.detailEmpty = panel.detailListFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    panel.detailEmpty:SetPoint("CENTER", panel.detailListFrame, "CENTER", 0, 0)
    panel.detailEmpty:SetText("选择左侧批次查看逐人结果")
    panel.batchRows, panel.detailRows = {}, {}
    for index = 1, 10 do
        local row = createFrame("Button", nil, panel.batchListFrame, "BackdropTemplate")
        row:SetSize(242, 21)
        row:SetPoint("TOPLEFT", panel.batchListFrame, "TOPLEFT", 5, -5 - (index - 1) * 22)
        if row.SetBackdrop then
            row:SetBackdrop({
                bgFile = "Interface/Buttons/WHITE8X8",
                edgeFile = "Interface/Buttons/WHITE8X8",
                edgeSize = 1,
            })
            row:SetBackdropColor(0.04, 0.04, 0.04, 0.65)
            row:SetBackdropBorderColor(0.28, 0.28, 0.28, 1)
        end
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", row, "LEFT", 4, 0)
        row.text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        row.text:SetJustifyH("LEFT")
        if row.text.SetWordWrap then row.text:SetWordWrap(false) end
        row:SetScript("OnClick", function()
            if row.batchId then
                self.selectedHistoryId = row.batchId
                self.historyDetailOffset = 0
                self:RefreshHistory()
            end
        end)
        panel.batchRows[index] = row
    end
    for index = 1, 12 do
        local row = createFrame("Button", nil, panel.detailListFrame, "BackdropTemplate")
        row:SetSize(478, 18)
        row:SetPoint("TOPLEFT", panel.detailListFrame, "TOPLEFT", 5, -5 - (index - 1) * 19)
        if row.SetBackdrop then
            row:SetBackdrop({
                bgFile = "Interface/Buttons/WHITE8X8",
                edgeFile = "Interface/Buttons/WHITE8X8",
                edgeSize = 1,
            })
            row:SetBackdropColor(0.04, 0.04, 0.04, 0.55)
            row:SetBackdropBorderColor(0.28, 0.28, 0.28, 1)
        end
        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.name:SetPoint("LEFT", row, "LEFT", 4, 0)
        row.name:SetWidth(170)
        row.name:SetJustifyH("LEFT")
        row.status = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.status:SetPoint("LEFT", row.name, "RIGHT", 4, 0)
        row.status:SetWidth(68)
        row.status:SetJustifyH("LEFT")
        row.amount = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.amount:SetPoint("LEFT", row.status, "RIGHT", 4, 0)
        row.amount:SetWidth(132)
        row.amount:SetJustifyH("RIGHT")
        row.postage = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.postage:SetPoint("LEFT", row.amount, "RIGHT", 4, 0)
        row.postage:SetWidth(86)
        row.postage:SetJustifyH("RIGHT")
        row:SetScript("OnEnter", function()
            if row.result and _G.GameTooltip then
                _G.GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
                _G.GameTooltip:SetText(row.result.displayName or row.result.sendName or "")
                _G.GameTooltip:AddLine(STATUS_TEXT[row.result.state] or row.result.state or "", 1, 1, 1)
                if row.result.errorCode then
                    _G.GameTooltip:AddLine("错误代码：" .. row.result.errorCode, 1, 0.35, 0.35)
                end
                if row.result.errorMessage then
                    _G.GameTooltip:AddLine(row.result.errorMessage, 1, 0.75, 0.75, true)
                end
                _G.GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function() if _G.GameTooltip then _G.GameTooltip:Hide() end end)
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", function(_, delta)
            local maximum = math.max(0, (panel.detailCount or 0) - #panel.detailRows)
            self.historyDetailOffset = math.max(0, math.min(maximum,
                self.historyDetailOffset + (delta > 0 and -1 or 1)))
            self:RefreshHistory()
        end)
        panel.detailRows[index] = row
    end
    panel:EnableMouseWheel(true)
    panel:SetScript("OnMouseWheel", function(_, delta)
        self.historyOffset = math.max(0, self.historyOffset + (delta > 0 and -1 or 1))
        self:RefreshHistory()
    end)
    panel:Hide()
end

function BulkMailView:SetMode(mode)
    if not self.frame or (mode ~= "compose" and mode ~= "history") then return false end
    self.mode = mode
    setButtonSelected(self.frame.composeTab, mode == "compose")
    setButtonSelected(self.frame.historyTab, mode == "history")
    for index = 1, #(self.composeWidgets or {}) do
        local widget = self.composeWidgets[index]
        if widget and widget.SetShown then widget:SetShown(mode == "compose")
        elseif widget then if mode == "compose" then widget:Show() else widget:Hide() end end
    end
    if mode == "history" then self.frame.historyPanel:Show() self:RefreshHistory()
    else self.frame.historyPanel:Hide() self:Refresh() end
    return true
end

function BulkMailView:RefreshHistory()
    if not self.frame or not self.frame.historyPanel then return end
    local repository = self.deps.historyRepository
    local records = repository and repository:List(self.historyOffset, 10) or {}
    local selected = repository and repository:Get(self.selectedHistoryId) or nil
    if not selected and records[1] then
        self.selectedHistoryId = records[1].id
        self.historyDetailOffset = 0
        selected = repository:Get(self.selectedHistoryId)
    elseif not records[1] then
        self.selectedHistoryId = nil
    end
    self.frame.historyPanel.batchEmpty:SetShown(#records == 0)
    for index = 1, #self.frame.historyPanel.batchRows do
        local row, record = self.frame.historyPanel.batchRows[index], records[index]
        if record then
            row.batchId = record.id
            row:Show()
            local timestamp = _G.date and _G.date("%m-%d %H:%M", record.startedAt or 0)
                or tostring(record.startedAt or "")
            row.text:SetText(formatBatchTitle(record, timestamp))
            row.selected = record.id == self.selectedHistoryId
            if row.SetBackdropBorderColor then
                if row.selected then row:SetBackdropBorderColor(1, 0.82, 0, 1)
                else row:SetBackdropBorderColor(0.28, 0.28, 0.28, 1) end
            end
        else
            row.batchId = nil
            row.selected = false
            row:Hide()
        end
    end
    local results = selected and selected.recipients or {}
    self.frame.historyPanel.detailEmpty:SetText(selected and "该批次暂无收件人结果"
        or "选择左侧批次查看逐人结果")
    self.frame.historyPanel.detailEmpty:SetShown(#results == 0)
    for index = 1, #self.frame.historyPanel.detailRows do
        local row, result = self.frame.historyPanel.detailRows[index], results[self.historyDetailOffset + index]
        if result then
            row.result = result
            row:Show()
            row.name:SetText(truncateUTF8(result.displayName or result.sendName, 18))
            row.status:SetText(STATUS_TEXT[result.state] or result.state or "")
            local statusColor = STATUS_COLOR[result.state]
            if statusColor then row.status:SetTextColor(statusColor[1], statusColor[2], statusColor[3]) end
            row.amount:SetText(string.format("%d铜", result.amount or 0))
            row.postage:SetText("邮资" .. (result.postage and tostring(result.postage) or "-"))
        else
            row.result = nil
            row.name:SetText("")
            row.status:SetText("")
            row.amount:SetText("")
            row.postage:SetText("")
            row:Hide()
        end
    end
    self.frame.historyPanel.detailCount = #results
end

function BulkMailView:_refreshGroupMenu()
    local descriptors
    if self.deps.listRecipientSources then descriptors = self.deps.listRecipientSources() end
    if not descriptors then
        descriptors = {
            { id = "builtin:alts", label = "小号", sourceKind = "custom", sourceGroupId = "builtin:alts" },
            { id = "builtin:friends", label = "好友", sourceKind = "custom", sourceGroupId = "builtin:friends" },
        }
        local groups = self.deps.recipientGroupRepository
            and self.deps.recipientGroupRepository:ListGroups() or {}
        for index = 1, #groups do
            descriptors[#descriptors + 1] = {
                id = groups[index].id,
                label = groups[index].name,
                sourceKind = "custom",
                sourceGroupId = groups[index].id,
            }
        end
    end
    local offset = math.max(0, math.min(self.groupMenuOffset or 0, math.max(0, #descriptors - 8)))
    self.groupMenuOffset = offset
    for index = 1, #self.groupMenu.rows do
        local row, descriptor = self.groupMenu.rows[index], descriptors[offset + index]
        if descriptor then
            row.descriptor = descriptor
            row:SetText(descriptor.label)
            row:Show()
        else
            row.descriptor = nil
            row:Hide()
        end
    end
    self.groupMenu.total = #descriptors
end

function BulkMailView:ToggleGroupMenu()
    if not self.frame then return end
    if self.groupMenu and self.groupMenu:IsShown() then self.groupMenu:Hide() return end
    local createFrame = self.deps.CreateFrame or _G.CreateFrame
    if not self.groupMenu then
        self.groupMenu = createFrame("Frame", nil, self.frame, "BackdropTemplate")
        self.groupMenu:SetSize(190, 220)
        self.groupMenu:SetPoint("TOPLEFT", self.customSourceButton, "BOTTOMLEFT", 0, -2)
        self.groupMenu:SetFrameStrata("DIALOG")
        if self.groupMenu.SetBackdrop then
            self.groupMenu:SetBackdrop({
                bgFile = "Interface/Buttons/WHITE8X8",
                edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
                edgeSize = 10,
            })
            self.groupMenu:SetBackdropColor(0.03, 0.03, 0.03, 0.95)
        end
        self.groupMenu.rows = {}
        for index = 1, 8 do
            local row = createFrame("Button", nil, self.groupMenu, "UIPanelButtonTemplate")
            row:SetSize(168, 24)
            row:SetPoint("TOPLEFT", 10, -10 - (index - 1) * 25)
            row:SetScript("OnClick", function(button)
                local descriptor = button.descriptor
                if not descriptor then return end
                self.groupMenu:Hide()
                self.rowOffset = 0
                if self.model then self.model:SetSource(descriptor.sourceKind, descriptor.sourceGroupId) end
                if self.deps.onSourceChanged then
                    self.deps.onSourceChanged(descriptor.sourceKind, descriptor.sourceGroupId)
                end
                if self.model then self.model:SetFilter(self.filter) end
                self:Refresh()
            end)
            self.groupMenu.rows[index] = row
        end
        self.groupMenu:EnableMouseWheel(true)
        self.groupMenu:SetScript("OnMouseWheel", function(_, delta)
            local maximum = math.max(0, (self.groupMenu.total or 0) - 8)
            self.groupMenuOffset = math.max(0, math.min(maximum, (self.groupMenuOffset or 0) + (delta > 0 and -1 or 1)))
            self:_refreshGroupMenu()
        end)
        local skinCompat = self.deps.skinCompat or Mail.SkinCompat
        if skinCompat and type(skinCompat.SkinPopover) == "function" then
            skinCompat:SkinPopover(self.groupMenu, self.groupMenu.rows)
        end
    end
    self:_refreshGroupMenu()
    self.groupMenu:Show()
end

function BulkMailView:_applyRankFilter()
    if self.model then self.model:SetFilter(self.filter) end
    if self.deps.onFilterChanged then self.deps.onFilterChanged(clone(self.filter)) end
    self.rowOffset = 0
    self:Refresh()
end

function BulkMailView:_refreshRankMenu()
    local offset = math.max(0, math.min(self.rankMenuOffset or 0, math.max(0, #self.rankDescriptors - 8)))
    self.rankMenuOffset = offset
    for index = 1, #self.rankMenu.rows do
        local row, descriptor = self.rankMenu.rows[index], self.rankDescriptors[offset + index]
        if descriptor then
            row.descriptor = descriptor
            row.text:SetText(descriptor.name or ("会阶 " .. descriptor.index))
            row:SetChecked(self.filter.rankIndices[descriptor.index] == true)
            row:Show()
        else
            row.descriptor = nil
            row:Hide()
        end
    end
end

function BulkMailView:ToggleRankMenu()
    if not self.frame then return end
    if self.rankMenu and self.rankMenu:IsShown() then self.rankMenu:Hide() return end
    local createFrame = self.deps.CreateFrame or _G.CreateFrame
    if not self.rankMenu then
        self.rankMenu = createFrame("Frame", nil, self.frame, "BackdropTemplate")
        self.rankMenu:SetSize(190, 270)
        self.rankMenu:SetPoint("TOPLEFT", self.frame.rankButton, "BOTTOMLEFT", 0, -2)
        self.rankMenu:SetFrameStrata("DIALOG")
        if self.rankMenu.SetBackdrop then
            self.rankMenu:SetBackdrop({
                bgFile = "Interface/Buttons/WHITE8X8",
                edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
                edgeSize = 10,
            })
            self.rankMenu:SetBackdropColor(0.03, 0.03, 0.03, 0.95)
        end
        self.rankMenu.all = createFrame("Button", nil, self.rankMenu, "UIPanelButtonTemplate")
        self.rankMenu.all:SetSize(168, 24)
        self.rankMenu.all:SetPoint("TOPLEFT", 10, -8)
        self.rankMenu.all:SetText("全部会阶")
        self.rankMenu.all:SetScript("OnClick", function()
            self.filter.rankIndices = {}
            self:_applyRankFilter()
            self:_refreshRankMenu()
        end)
        self.rankMenu.rows = {}
        for index = 1, 8 do
            local row = createFrame("CheckButton", nil, self.rankMenu, "UICheckButtonTemplate")
            row:SetSize(24, 24)
            row:SetPoint("TOPLEFT", 8, -35 - (index - 1) * 25)
            row.text = self.rankMenu:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.text:SetPoint("LEFT", row, "RIGHT", 0, 0)
            row:SetScript("OnClick", function(button)
                local descriptor = button.descriptor
                if not descriptor then return end
                self.filter.rankIndices[descriptor.index] = button:GetChecked() == true or nil
                self:_applyRankFilter()
            end)
            self.rankMenu.rows[index] = row
        end
        self.rankMenu:EnableMouseWheel(true)
        self.rankMenu:SetScript("OnMouseWheel", function(_, delta)
            local maximum = math.max(0, #self.rankDescriptors - 8)
            self.rankMenuOffset = math.max(0, math.min(maximum, (self.rankMenuOffset or 0) + (delta > 0 and -1 or 1)))
            self:_refreshRankMenu()
        end)
        local skinCompat = self.deps.skinCompat or Mail.SkinCompat
        if skinCompat and type(skinCompat.SkinPopover) == "function" then
            local widgets = { self.rankMenu.all }
            for index = 1, #self.rankMenu.rows do widgets[#widgets + 1] = self.rankMenu.rows[index] end
            skinCompat:SkinPopover(self.rankMenu, widgets)
        end
    end
    local ranks = self.model and self.model:GetRosterSnapshot().ranks or {}
    self.rankDescriptors = {}
    for rankIndex, rankName in pairs(ranks) do
        self.rankDescriptors[#self.rankDescriptors + 1] = { index = rankIndex, name = rankName }
    end
    table.sort(self.rankDescriptors, function(left, right) return left.index < right.index end)
    self.filter.rankIndices = self.filter.rankIndices or {}
    self:_refreshRankMenu()
    self.rankMenu:Show()
end

function BulkMailView:ShowError(err)
    if not self.frame or not self.frame.errorBanner then return end
    local message
    if type(err) == "table" then
        local code = err.code or err.errorCode
        message = (code and (code .. "：") or "")
            .. tostring(err.message or err.errorMessage or "批量邮寄失败")
    else
        message = tostring(err or "")
    end
    self.frame.errorBanner:SetText(message)
    if self.frame.historyPanel and self.frame.historyPanel.error then
        self.frame.historyPanel.error:SetText(message)
    end
end

function BulkMailView:StartNewBatch()
    self.batchState = nil
    if self.model and self.model.ClearStatuses then self.model:ClearStatuses() end
    self:ShowError(nil)
    self:SetMode("compose")
    self:Refresh()
end

function BulkMailView:ConfirmStart()
    if self.batchState and (self.batchState.state == "COMPLETED" or self.batchState.state == "PARTIAL"
        or self.batchState.state == "STOPPED" or self.batchState.state == "INTERRUPTED") then
        self.selectedHistoryId = self.batchState.id or self.selectedHistoryId
        self:SetMode("history")
        return
    end
    if self.batchState and (self.batchState.state == "RUNNING"
        or self.batchState.state == "WAITING_SERVER") then return end
    if self.batchState and self.batchState.state == "WAITING_SECURE_CONFIRM" then
        self:ShowError({ code = "SECURE_CONFIRM_PENDING", message = "请先处理原生安全转账确认框" })
        return
    end
    if self.batchState and (self.batchState.state == "WAITING_USER_ACTION" or self.batchState.state == "PAUSED") then
        if self.deps.onContinue then
            local ok, err = self.deps.onContinue()
            if not ok and err then self:ShowError(err) end
        end
        return
    end
    local draft = self:GetDraft()
    local validation = self.deps.validate and self.deps.validate(draft)
    if validation and validation.ok == false then self:ShowError(validation.errors and validation.errors[1]) return end
    local count = #draft.recipients
    local amount = math.max(0, math.floor(tonumber(draft.amountEach) or 0))
    local postage = validation and validation.postageEach or 0
    local rows = {
        { label = "收件人数", value = count .. " 人" },
        { label = "单人金额", value = formatMoney(amount) },
        { label = "金币合计", value = formatMoney(count * amount) },
        { label = "邮资成本", value = formatMoney(count * postage) },
        { label = "总支出", value = formatMoney(count * (amount + postage)) },
    }
    local function start()
        local batchId, err
        if self.deps.onStart then batchId, err = self.deps.onStart(draft) end
        if not batchId and err then self:ShowError(err) else self:ShowError(nil) end
    end
    if _G.StaticPopupDialogs and _G.StaticPopup_Show then
        if not _G.StaticPopupDialogs.EASYAUCTION_BULK_SEND_CONFIRM then
            _G.StaticPopupDialogs.EASYAUCTION_BULK_SEND_CONFIRM = {
                text = "%s", button1 = _G.ACCEPT or "确定", button2 = _G.CANCEL or "取消",
                OnAccept = function(_, data) if data and data.callback then data.callback() end end,
                OnShow = showBulkConfirmRows,
                OnHide = hideBulkConfirmRows,
                timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
            }
        end
        _G.StaticPopup_Show("EASYAUCTION_BULK_SEND_CONFIRM", "|cffffd100确认批量邮寄|r", nil, {
            callback = start,
            rows = rows,
        })
    else
        start()
    end
end

function BulkMailView:GetDraft()
    return {
        recipients = self.model and self.model:GetSelectedSnapshot() or {},
        rosterGeneration = self.model and self.model:GetRosterSnapshot().generation or 0,
        sourceKind = self.model and self.model.sourceKind or "raid",
        sourceGroupId = self.model and self.model.sourceGroupId or nil,
        subject = self.frame and self.frame.subject:GetText() or "",
        body = self.frame and self.frame.body:GetText() or "",
        amountEach = self:_readAmount(),
    }
end

function BulkMailView:ScrollRows(delta)
    local members = self.model and self.model:GetFilteredMembers() or {}
    local maximum = getScrollMaximum(self.model and self.model.sourceKind, #members)
    self.rowOffset = math.max(0, math.min(maximum, self.rowOffset + delta))
    if self.frame and self.frame.scroll then self.frame.scroll:SetValue(self.rowOffset) end
    self:Refresh()
end

function BulkMailView:_isEditing()
    local focus = self.deps.getKeyboardFocus and self.deps.getKeyboardFocus()
        or _G.GetCurrentKeyBoardFocus and _G.GetCurrentKeyBoardFocus()
    return focus and focus.IsObjectType and focus:IsObjectType("EditBox")
end

function BulkMailView:OnKeyDown(key)
    if self:_isEditing() then return false end
    local occupied = {}
    for cellIndex, binding in pairs(self.bindings) do
        if binding and binding.member then occupied[#occupied + 1] = cellIndex end
    end
    table.sort(occupied)
    if #occupied == 0 then return false end
    local position = 1
    for index = 1, #occupied do
        if occupied[index] == self.focusedCell then position = index break end
    end
    local target = occupied[position]
    local isParty = self.model and self.model.sourceKind == "party"
    if key == "LEFT" or key == "RIGHT" then
        if not isParty then
            local candidate = target + (key == "LEFT" and -1 or 1)
            if math.floor((candidate - 1) / GRID_COLUMNS) == math.floor((target - 1) / GRID_COLUMNS)
                and self.bindings[candidate] then target = candidate end
        end
    elseif key == "UP" then
        if isParty then target = occupied[math.max(1, position - 1)]
        else
            local candidate = target - GRID_COLUMNS
            if self.bindings[candidate] then target = candidate end
        end
    elseif key == "DOWN" then
        if isParty then target = occupied[math.min(#occupied, position + 1)]
        else
            local candidate = target + GRID_COLUMNS
            if self.bindings[candidate] then target = candidate end
        end
    elseif key == "PAGEUP" then self:ScrollRows(-5) return true
    elseif key == "PAGEDOWN" then self:ScrollRows(5) return true
    elseif key == "HOME" then target = occupied[1]
    elseif key == "END" then target = occupied[#occupied]
    elseif key == "SPACE" then
        local binding = self.bindings[target]
        if binding and binding.member and self.model then
            self.focusedRecipientKey = binding.member.recipientKey
            local toggled, toggleError = self.model:Toggle(binding.member.recipientKey)
            if not toggled and toggleError then self:ShowError(toggleError) else self:ShowError(nil) end
            self:Refresh()
        end
        return true
    else return false end
    self.focusedCell = math.max(1, math.min(40, target))
    local focusedBinding = self.bindings[self.focusedCell]
    if focusedBinding and focusedBinding.member then
        self.focusedRecipientKey = focusedBinding.member.recipientKey
    end
    self:Refresh()
    return true
end

function BulkMailView:GetVisibleSlotCount()
    return self.model and self.model.sourceKind == "party" and 5 or 40
end

function BulkMailView:Refresh()
    if not self.model then return end
    local snapshot = self.model:GetRosterSnapshot()
    snapshot.members = self.model:GetFilteredMembers()
    local maximum = getScrollMaximum(self.model.sourceKind, #snapshot.members)
    self.rowOffset = math.max(0, math.min(maximum, self.rowOffset))
    self.bindings = {}
    local compact = BulkMailView.BuildBindings(snapshot, self.rowOffset)
    for index = 1, #compact do self.bindings[compact[index].cellIndex] = compact[index] end
    local focusedVisibleCell
    for cellIndex, binding in pairs(self.bindings) do
        if binding.member and binding.member.recipientKey == self.focusedRecipientKey then
            focusedVisibleCell = cellIndex
            self.focusedCell = cellIndex
            break
        end
    end
    if not focusedVisibleCell then
        local firstCell
        for cellIndex, binding in pairs(self.bindings) do
            if binding.member and (not firstCell or cellIndex < firstCell) then firstCell = cellIndex end
        end
        if firstCell then
            self.focusedRecipientKey = self.bindings[firstCell].member.recipientKey
            self.focusedCell = firstCell
            focusedVisibleCell = firstCell
        end
    end
    if not self.frame then return end
    self:_layoutCells(self.model.sourceKind)
    self.lastRenderedFocusedCell = focusedVisibleCell
    local visibleSlotCount = self:GetVisibleSlotCount()
    for index = 1, 40 do
        local cell, binding = self.cells[index], self.bindings[index]
        if binding and binding.member then
            local member = binding.member
            cell:Show()
            cell.isPlaceholder = false
            cell:EnableMouse(not member.isSelf)
            cell.check:Show()
            cell.check:SetEnabled(not member.isSelf)
            cell.check:SetChecked(self.model:IsSelected(member.recipientKey))
            setFittedText(cell.name, member.displayName)
            if cell.SetBackdropColor then cell:SetBackdropColor(0.05, 0.05, 0.05, 0.75) end
            local status = self.model:GetRecipientStatus(member.recipientKey)
            setText(cell.status, "")
            local statusTexture = status and STATUS_TEXTURE[status.state]
            if member.isSelf then
                cell.stateIcon:SetTexture("Interface/Common/Indicator-Gray")
                cell.stateIcon:Show()
            elseif statusTexture then cell.stateIcon:SetTexture(statusTexture) cell.stateIcon:Show()
            else cell.stateIcon:Hide() end
            local statusColor = status and STATUS_COLOR[status.state]
            if statusColor then cell.status:SetTextColor(statusColor[1], statusColor[2], statusColor[3])
            else cell.status:SetTextColor(0.9, 0.9, 0.9) end
            local classColor = _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[member.classFile]
            if classColor then
                cell.name:SetTextColor(classColor.r, classColor.g, classColor.b)
            else
                cell.name:SetTextColor(1, 0.82, 0)
            end
            if cell.SetBackdropBorderColor then
                if index == focusedVisibleCell then cell:SetBackdropBorderColor(1, 0.82, 0, 1)
                elseif self.model:IsSelected(member.recipientKey) then cell:SetBackdropBorderColor(0.2, 0.8, 0.2, 1)
                else cell:SetBackdropBorderColor(0.35, 0.35, 0.35, 1) end
            end
        elseif index <= visibleSlotCount then
            cell:Show()
            cell.isPlaceholder = true
            cell:EnableMouse(false)
            cell.check:SetChecked(false)
            cell.check:SetEnabled(false)
            cell.check:Hide()
            setText(cell.name, "")
            setText(cell.status, "")
            cell.stateIcon:Hide()
            if cell.SetBackdropColor then cell:SetBackdropColor(0.035, 0.035, 0.035, 0.45) end
            if cell.SetBackdropBorderColor then cell:SetBackdropBorderColor(0.22, 0.22, 0.22, 0.7) end
        else
            cell.check:SetChecked(false)
            setText(cell.name, "")
            setText(cell.status, "")
            cell.stateIcon:Hide()
            cell:Hide()
        end
    end
    self.frame.scroll:SetMinMaxValues(0, maximum)
    self.frame.scroll:SetValue(self.rowOffset)
    if self.frame.scroll.SetShown then self.frame.scroll:SetShown(self.mode == "compose" and maximum > 0) end
    if snapshot.loading then self.frame.loading:Show() else self.frame.loading:Hide() end
    if self.mode == "compose" then
        for index = 1, #self.frame.groupHeaders do
            if self.model.sourceKind == "raid" then self.frame.groupHeaders[index]:Show()
            else self.frame.groupHeaders[index]:Hide() end
        end
        for index = 1, #self.frame.sourceButtons do
            local button = self.frame.sourceButtons[index]
            setButtonSelected(button, button.sourceKind == self.model.sourceKind)
        end
        if self.model.sourceKind == "guild" then
            self.frame.rankButton:Show()
            self.frame.onlineOnly:Show()
            self.frame.onlineOnly.text:Show()
        else
            self.frame.rankButton:Hide()
            self.frame.onlineOnly:Hide()
            self.frame.onlineOnly.text:Hide()
        end
    end
    setText(self.frame.selectionSummary, string.format("已选 %d 人", self.model:GetSelectionCount()))
    self:_refreshTotalAmount()
end

function BulkMailView:SetBatchState(state)
    if not self.frame then return end
    state = state or {}
    self.batchState = clone(state)
    for index = 1, #(state.recipients or {}) do
        local item = state.recipients[index]
        if self.model then self.model:SetRecipientStatus(item.recipientKey, item) end
    end
    local text = "开始批量邮寄"
    if state.state == "RUNNING" then text = string.format("发送中 %d/%d", state.completedCount or 0, state.totalCount or 0)
    elseif state.state == "WAITING_SERVER" then text = "等待邮件服务器"
    elseif state.state == "WAITING_USER_ACTION" then text = "继续发送下一封"
    elseif state.state == "PAUSED" or state.state == "STOPPED" then text = "已暂停"
    elseif state.state == "COMPLETED" or state.state == "PARTIAL" then text = "完成，查看记录" end
    self.frame.send:SetText(text)
    setText(self.frame.summary, string.format("成功 %d  失败 %d  未知 %d  剩余 %d",
        state.successCount or 0, state.failedCount or 0, state.unknownCount or 0, state.pendingCount or 0))
    if state.current and state.current.errorCode then self:ShowError(state.current) end
    self:Refresh()
end

function BulkMailView:Show()
    if self.frame then self.frame:Show() end
end

function BulkMailView:OnActivated(generation)
    if self.deps.onActivated then self.deps.onActivated(generation) end
    self:Refresh()
end

function BulkMailView:OnDeactivated(reason)
    if self.deps.onDeactivated then return self.deps.onDeactivated(reason) end
end

function BulkMailView:Hide()
    if self.frame then self.frame:Hide() end
end

Mail.BulkMailView = BulkMailView
