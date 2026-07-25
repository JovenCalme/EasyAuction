local _, ns = ...
ns = type(ns) == "table" and ns or {}
ns.Mail = type(ns.Mail) == "table" and ns.Mail or {}

local Mail = ns.Mail
local View = {}
View.__index = View

local CELL_COUNT = 42
local COLUMN_COUNT = 6
local CELL_SIZE = 37
local CELL_GAP = 7
local CATEGORY_BUTTON_WIDTH = 42
local CATEGORY_BUTTON_HEIGHT = 21
local CATEGORY_BUTTON_STEP = 22

local function invoke(target, method, ...)
    if target and type(target[method]) == "function" then
        return target[method](target, ...)
    end
end

local function clearTable(target)
    for key in pairs(target) do target[key] = nil end
end

local function copyModel(target, source)
    clearTable(target)
    for key, value in pairs(source or {}) do target[key] = value end
    target.totalCount = target.totalCount or 0
    target.totalMoney = target.totalMoney or 0
    target.showQuality = target.showQuality == true
    target.searchMatch = target.searchMatch ~= false
    target.enabled = target.enabled == true
end

local function qualityColor(quality)
    local colors = _G and _G.ITEM_QUALITY_COLORS
    local color = colors and colors[quality]
    if color then return color.r or 1, color.g or 1, color.b or 1 end
    return 1, 1, 1
end

local function textureFor(button)
    return button and (button.icon or button.Icon or button.texture)
end

function View.New(deps)
    deps = deps or {}
    local self = setmetatable({
        deps = deps,
        cells = {},
        buttons = {},
        projection = nil,
        rowOffset = 0,
        enabled = true,
        shown = false,
        query = "",
        categoryId = "all",
        categoryButtons = {},
        groupStacks = true,
        advanced = false,
        qualityColors = true,
        summaryCurrent = 0,
        summaryTotal = 0,
        updatingControls = false,
    }, View)
    for index = 1, CELL_COUNT do self.cells[index] = {} end
    if deps.parent then self:Create(deps.parent) end
    return self
end

function View:Create(parent)
    if self.root then
        invoke(self.root, "SetParent", parent)
        return self.root
    end
    if not parent then return nil end
    local root = self:_createFrames(parent)
    if root and self.shown then invoke(root, "Show") end
    return root
end

function View:_createFrames(parent)
    local createFrame = self.deps.createFrame or (_G and _G.CreateFrame)
    if type(createFrame) ~= "function" then return nil end

    local root = createFrame("Frame", nil, parent)
    self.root = root
    self.frame = root
    invoke(root, "SetSize", 384, 512)
    if self.deps.anchor then
        invoke(root, "SetPoint", unpack(self.deps.anchor))
    else
        invoke(root, "SetPoint", "TOPLEFT", parent, "TOPLEFT", 0, 0)
    end
    invoke(root, "Hide")

    self.paperBackground = invoke(root, "CreateTexture", nil, "BACKGROUND")
    invoke(self.paperBackground, "SetSize", 512, 512)
    invoke(self.paperBackground, "SetPoint", "TOPLEFT", root, "TOPLEFT", 7, -62)
    invoke(self.paperBackground, "SetTexture", "Interface\\MailFrame\\UI-MailFrameBG")

    self.title = invoke(root, "CreateFontString", nil, "OVERLAY", "GameFontNormal")
    invoke(self.title, "SetSize", 224, 14)
    invoke(self.title, "SetPoint", "TOP", root, "TOP", 0, -4)
    invoke(self.title, "SetText", "邮包")

    local content = createFrame("Frame", nil, root)
    self.content = content
    invoke(content, "SetSize", 344, 350)
    invoke(content, "SetPoint", "TOPLEFT", root, "TOPLEFT", 20, -32)

    self.groupButton = createFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    invoke(self.groupButton, "SetSize", 24, 24)
    invoke(self.groupButton, "SetPoint", "TOPLEFT", content, "TOPLEFT", 30, -2)
    invoke(self.groupButton, "SetChecked", self.groupStacks)
    invoke(self.groupButton, "SetScript", "OnClick", function(button)
        if self.updatingControls then return end
        self.groupStacks = invoke(button, "GetChecked") == true
        if type(self.deps.onGroupStacksChanged) == "function" then
            self.deps.onGroupStacksChanged(self.groupStacks)
        end
    end)
    self.groupLabel = invoke(content, "CreateFontString", nil, "OVERLAY", "GameFontNormalSmall")
    invoke(self.groupLabel, "SetPoint", "LEFT", self.groupButton, "RIGHT", 2, 0)
    invoke(self.groupLabel, "SetText", "堆叠")

    self.searchBox = createFrame("EditBox", nil, content, "SearchBoxTemplate")
    invoke(self.searchBox, "SetSize", 130, 20)
    invoke(self.searchBox, "SetPoint", "TOPRIGHT", content, "TOPRIGHT", -36, -1)
    invoke(self.searchBox, "SetAutoFocus", false)
    invoke(self.searchBox, "SetScript", "OnTextChanged", function(editBox)
        if self.updatingControls then return end
        local value = invoke(editBox, "GetText") or ""
        self.query = value
        if type(self.deps.onSearchChanged) == "function" then
            self.deps.onSearchChanged(value)
        end
    end)

    self.summaryText = invoke(content, "CreateFontString", nil, "OVERLAY", "GameFontNormalSmall")
    invoke(self.summaryText, "SetPoint", "TOPLEFT", content, "TOPLEFT", 2, -38)
    invoke(self.summaryText, "SetText", "")

    local categoryOptions = {
        { id = "all", label = "全部", tooltip = "显示全部物品和金币" },
        { id = "money", label = "金币", tooltip = "只显示邮件中的金币" },
    }
    for index = 1, #(self.deps.categories or {}) do
        categoryOptions[#categoryOptions + 1] = self.deps.categories[index]
    end
    for index = 1, #categoryOptions do
        local option = categoryOptions[index]
        local button = createFrame("Button", nil, root, "UIPanelButtonTemplate")
        invoke(button, "SetSize", CATEGORY_BUTTON_WIDTH, CATEGORY_BUTTON_HEIGHT)
        invoke(button, "SetPoint", "TOPLEFT", parent, "TOPRIGHT", 2,
            -28 - (index - 1) * CATEGORY_BUTTON_STEP)
        invoke(button, "SetText", option.label)
        button.categoryId = option.id
        button.__eaSelected = invoke(button, "CreateTexture", nil, "OVERLAY")
        invoke(button.__eaSelected, "SetAllPoints", button)
        invoke(button.__eaSelected, "SetTexture", "Interface\\Buttons\\UI-Listbox-Highlight2")
        invoke(button.__eaSelected, "SetBlendMode", "ADD")
        invoke(button.__eaSelected, "Hide")
        invoke(button, "SetScript", "OnClick", function()
            if self.enabled and type(self.deps.onCategoryChanged) == "function" then
                self.deps.onCategoryChanged(option.id)
            end
        end)
        invoke(button, "SetScript", "OnEnter", function(frame)
            local tooltip = self.deps.tooltip or (_G and _G.GameTooltip)
            if tooltip then
                invoke(tooltip, "SetOwner", frame, "ANCHOR_RIGHT")
                invoke(tooltip, "SetText", option.tooltip or option.label)
                invoke(tooltip, "Show")
            end
        end)
        invoke(button, "SetScript", "OnLeave", function()
            local tooltip = self.deps.tooltip or (_G and _G.GameTooltip)
            invoke(tooltip, "Hide")
        end)
        self.categoryButtons[index] = button
    end

    self.scrollBar = createFrame("Slider", nil, content, "UIPanelScrollBarTemplate")
    invoke(self.scrollBar, "SetPoint", "TOPRIGHT", content, "TOPRIGHT", -12, -60)
    invoke(self.scrollBar, "SetPoint", "BOTTOMRIGHT", content, "BOTTOMRIGHT", -12, 4)
    invoke(self.scrollBar, "SetMinMaxValues", 0, 0)
    invoke(self.scrollBar, "SetValueStep", 1)
    invoke(self.scrollBar, "SetScript", "OnValueChanged", function(_, value)
        if not self.updatingControls then self:RequestRowOffset(value) end
    end)
    invoke(self.scrollBar, "Hide")

    for index = 1, CELL_COUNT do
        local button = createFrame("Button", nil, content, "ItemButtonTemplate")
        local column = (index - 1) % COLUMN_COUNT
        local row = math.floor((index - 1) / COLUMN_COUNT)
        invoke(button, "SetSize", CELL_SIZE, CELL_SIZE)
        invoke(button, "SetPoint", "TOPLEFT", content, "TOPLEFT",
            column * (CELL_SIZE + CELL_GAP), -58 - row * (CELL_SIZE + CELL_GAP))
        invoke(button, "RegisterForClicks", "LeftButtonUp", "RightButtonUp")

        button.__eaSlotBackground = invoke(button, "CreateTexture", nil, "BACKGROUND")
        if button.__eaSlotBackground then
            invoke(button.__eaSlotBackground, "SetSize", 39, 39)
            invoke(button.__eaSlotBackground, "SetPoint", "TOPLEFT", button, "TOPLEFT", -2, 2)
            invoke(button.__eaSlotBackground, "SetTexture", "Interface\\Buttons\\UI-Slot-Background")
            invoke(button.__eaSlotBackground, "SetTexCoord", 0, 0.640625, 0, 0.640625)
            invoke(button.__eaSlotBackground, "SetVertexColor", 1, 1, 1, 0.66)
        end

        button.__eaExpiryOverlay = invoke(button, "CreateTexture", nil, "OVERLAY")
        if button.__eaExpiryOverlay then
            invoke(button.__eaExpiryOverlay, "SetAllPoints", button)
            invoke(button.__eaExpiryOverlay, "SetTexture", "Interface\\Buttons\\WHITE8X8")
            invoke(button.__eaExpiryOverlay, "SetBlendMode", "MOD")
        end
        button.__eaSearchOverlay = invoke(button, "CreateTexture", nil, "OVERLAY", nil, 2)
        if button.__eaSearchOverlay then
            invoke(button.__eaSearchOverlay, "SetAllPoints", button)
            invoke(button.__eaSearchOverlay, "SetTexture", "Interface\\Buttons\\WHITE8X8")
            invoke(button.__eaSearchOverlay, "SetVertexColor", 0, 0, 0, 0.65)
        end
        button.__eaQualityBorder = invoke(button, "CreateTexture", nil, "ARTWORK", nil, 1)
        if button.__eaQualityBorder then
            invoke(button.__eaQualityBorder, "SetAllPoints", textureFor(button) or button)
            invoke(button.__eaQualityBorder, "SetTexture", "Interface\\Common\\WhiteIconFrame")
        end
        button.__eaReturnStatus = invoke(button, "CreateFontString", nil, "OVERLAY", "GameFontNormalSmall")
        invoke(button.__eaReturnStatus, "SetSize", CELL_SIZE, 12)
        invoke(button.__eaReturnStatus, "SetPoint", "TOP", button, "TOP", 0, -1)
        invoke(button.__eaReturnStatus, "SetJustifyH", "CENTER")
        local cellIndex = index
        invoke(button, "SetScript", "OnClick", function(_, mouseButton)
            self:_onClick(cellIndex, mouseButton)
        end)
        invoke(button, "SetScript", "OnEnter", function(frame)
            self:_onEnter(cellIndex, frame)
        end)
        invoke(button, "SetScript", "OnLeave", function()
            self:_onLeave()
        end)
        self.buttons[index] = button
    end

    invoke(root, "EnableMouseWheel", true)
    invoke(root, "SetScript", "OnMouseWheel", function(_, delta)
        self:RequestRowOffset(self.rowOffset - delta)
    end)
    self:_renderCategories()
    local skinCompat = self.deps.skinCompat or Mail.SkinCompat
    if skinCompat and type(skinCompat.SkinInbox) == "function" then
        skinCompat:SkinInbox(self)
    end
    return root
end

function View:_renderCategories()
    for index = 1, #self.categoryButtons do
        local button = self.categoryButtons[index]
        invoke(button.__eaSelected, button.categoryId == self.categoryId and "Show" or "Hide")
        if self.enabled then invoke(button, "Enable") else invoke(button, "Disable") end
    end
end

function View:_onClick(cellIndex, mouseButton)
    local cell = self.cells[cellIndex]
    if not self.enabled or not cell or not cell.entryId or not cell.enabled then return end
    if type(self.deps.onEntryClick) == "function" then
        self.deps.onEntryClick(cell.entry, mouseButton, cellIndex)
    end
end

function View:_onEnter(cellIndex, owner)
    local cell = self.cells[cellIndex]
    if not cell or not cell.entryId then return end
    if type(self.deps.onEntryEnter) == "function" then
        self.deps.onEntryEnter(cell.entry, owner, cellIndex)
        return
    end

    local builder = self.deps.tooltipBuilder or Mail.InboxTooltipBuilder
    local tooltip = self.deps.tooltip or (_G and _G.GameTooltip)
    if builder and type(builder.Build) == "function" and type(builder.Render) == "function" then
        builder.Render(builder.Build(cell.entry, self.deps.tooltipOptions), tooltip, owner)
    end
end

function View:_onLeave()
    if type(self.deps.onEntryLeave) == "function" then
        self.deps.onEntryLeave()
        return
    end
    local tooltip = self.deps.tooltip or (_G and _G.GameTooltip)
    invoke(tooltip, "Hide")
end

function View:_renderCell(index)
    local model = self.cells[index]
    local button = self.buttons[index]
    if not button then return end

    button.__eaEntryId = model.entryId
    local texture = model.entryId and model.icon or nil
    if _G and type(_G.SetItemButtonTexture) == "function" then
        _G.SetItemButtonTexture(button, texture)
    else
        invoke(textureFor(button), "SetTexture", texture)
    end
    local count = model.entryId and model.kind == "item" and model.totalCount or 0
    if _G and type(_G.SetItemButtonCount) == "function" then
        _G.SetItemButtonCount(button, count)
    elseif button.Count then
        invoke(button.Count, "SetText", count > 1 and tostring(count) or "")
    end

    if model.expiryState == "critical" then
        invoke(button.__eaExpiryOverlay, "SetVertexColor", 1, 0.125, 0.125, 0.8)
        invoke(button.__eaExpiryOverlay, "Show")
    elseif model.expiryState == "warning" then
        invoke(button.__eaExpiryOverlay, "SetVertexColor", 1, 0.5, 0, 0.7)
        invoke(button.__eaExpiryOverlay, "Show")
    else
        invoke(button.__eaExpiryOverlay, "Hide")
    end

    if model.showQuality then
        local red, green, blue = qualityColor(model.quality)
        invoke(button.__eaQualityBorder, "SetVertexColor", red, green, blue, 1)
        invoke(button.__eaQualityBorder, "Show")
    else
        invoke(button.__eaQualityBorder, "Hide")
    end

    if model.entryId and not model.searchMatch then
        invoke(button.__eaSearchOverlay, "Show")
    else
        invoke(button.__eaSearchOverlay, "Hide")
    end

    if model.entryId and model.returnState == "action-required" then
        invoke(button.__eaReturnStatus, "SetText", "转寄")
        invoke(button.__eaReturnStatus, "SetTextColor", 1, 0.2, 0.2)
        invoke(button.__eaReturnStatus, "Show")
    elseif model.entryId and model.returnState == "returnable" then
        invoke(button.__eaReturnStatus, "SetText", "可退")
        invoke(button.__eaReturnStatus, "SetTextColor", 0.2, 1, 0.2)
        invoke(button.__eaReturnStatus, "Show")
    else
        invoke(button.__eaReturnStatus, "SetText", "")
        invoke(button.__eaReturnStatus, "Hide")
    end

    if model.entryId and model.enabled and self.enabled then
        invoke(button, "Enable")
    else
        invoke(button, "Disable")
    end
end

function View:Bind(projection)
    projection = projection or { cells = {} }
    self.projection = projection
    self.rowOffset = projection.rowOffset or 0
    for index = 1, CELL_COUNT do
        copyModel(self.cells[index], projection.cells and projection.cells[index] or nil)
        self:_renderCell(index)
    end
    if self.scrollBar then
        self.updatingControls = true
        invoke(self.scrollBar, "SetMinMaxValues", 0, projection.maxRowOffset or 0)
        invoke(self.scrollBar, "SetValue", self.rowOffset)
        self.updatingControls = false
        if projection.canScroll then invoke(self.scrollBar, "Show")
        else invoke(self.scrollBar, "Hide") end
    end
    return self
end

function View:GetCell(index)
    return self.cells[index]
end

function View:GetRoot()
    return self.root
end

function View:Show()
    self.shown = true
    invoke(self.root, "Show")
end

function View:Hide()
    self.shown = false
    invoke(self.root, "Hide")
end

function View:IsShown()
    if self.root and type(self.root.IsShown) == "function" then return self.root:IsShown() end
    return self.shown == true
end

function View:OnActivated()
    self:Show()
    if type(self.deps.onActivated) == "function" then self.deps.onActivated() end
end

function View:SetQuery(query)
    query = tostring(query or "")
    self.query = query
    if self.searchBox and type(self.searchBox.SetText) == "function"
        and invoke(self.searchBox, "GetText") ~= query then
        self.updatingControls = true
        self.searchBox:SetText(query)
        self.updatingControls = false
    end
end

function View:SetGroupStacks(enabled)
    self.groupStacks = enabled == true
    if self.groupButton then
        self.updatingControls = true
        invoke(self.groupButton, "SetChecked", self.groupStacks)
        self.updatingControls = false
    end
end

function View:SetAdvanced(enabled)
    self.advanced = enabled == true
    if self.advancedButton then
        self.updatingControls = true
        invoke(self.advancedButton, "SetChecked", self.advanced)
        self.updatingControls = false
    end
end

function View:SetCategory(categoryId)
    self.categoryId = tostring(categoryId or "all")
    self:_renderCategories()
end

function View:SetQualityColors(enabled)
    self.qualityColors = enabled == true
    if self.qualityButton then
        self.updatingControls = true
        invoke(self.qualityButton, "SetChecked", self.qualityColors)
        self.updatingControls = false
    end
end

function View:SetSummary(current, total)
    self.summaryCurrent = math.max(0, math.floor(tonumber(current) or 0))
    self.summaryTotal = math.max(self.summaryCurrent, math.floor(tonumber(total) or self.summaryCurrent))
    invoke(self.summaryText, "SetText", string.format("邮件：%d / %d",
        self.summaryCurrent, self.summaryTotal))
    invoke(self.summaryText, "Show")
end

function View:RequestRowOffset(offset)
    local maximum = self.projection and self.projection.maxRowOffset or 0
    offset = math.max(0, math.min(maximum, math.floor(tonumber(offset) or 0)))
    if offset == self.rowOffset then return false end
    self.rowOffset = offset
    if self.scrollBar then
        self.updatingControls = true
        invoke(self.scrollBar, "SetValue", offset)
        self.updatingControls = false
    end
    if type(self.deps.onScroll) == "function" then self.deps.onScroll(offset) end
    return true
end

function View:SetEnabled(enabled)
    self.enabled = enabled == true
    for index = 1, CELL_COUNT do self:_renderCell(index) end
    self:_renderCategories()
end

function View:Destroy()
    for index = 1, #self.buttons do
        local button = self.buttons[index]
        invoke(button, "SetScript", "OnClick", nil)
        invoke(button, "SetScript", "OnEnter", nil)
        invoke(button, "SetScript", "OnLeave", nil)
        invoke(button, "Hide")
    end
    for index = 1, #self.categoryButtons do
        local button = self.categoryButtons[index]
        invoke(button, "SetScript", "OnClick", nil)
        invoke(button, "SetScript", "OnEnter", nil)
        invoke(button, "SetScript", "OnLeave", nil)
        invoke(button, "Hide")
    end
    invoke(self.root, "SetScript", "OnMouseWheel", nil)
    invoke(self.root, "Hide")
    self.buttons = {}
    self.categoryButtons = {}
    self.root = nil
    self.frame = nil
    self.groupButton = nil
    self.groupLabel = nil
    self.advancedButton = nil
    self.advancedLabel = nil
    self.qualityButton = nil
    self.qualityLabel = nil
    self.defaultButton = nil
    self.defaultLabel = nil
    self.searchBox = nil
    self.summaryText = nil
    self.scrollBar = nil
    self.shown = false
end

View.CELL_COUNT = CELL_COUNT
View.COLUMN_COUNT = COLUMN_COUNT

Mail.InboxView = View

return View
