local addonName, ns = ...
local AuctionBar = CreateFrame("Frame", "AuctionBarFrame", UIParent)
local EAStyle = _G.EasyAuctionStyle

local function EA_SkinFrame(frame, role)
    if EAStyle then
        EAStyle:SkinExistingFrame(frame, role)
    end
    return frame
end

local function EA_SkinPanel(frame, role)
    if EAStyle then
        EAStyle:Skin(frame, role or "panel")
    end
    return frame
end

local function EA_SkinButton(button)
    if EAStyle then
        EAStyle:SkinButton(button)
    end
    return button
end

local function EA_SkinText(fs, role)
    if EAStyle then
        EAStyle:SkinText(fs, role)
    end
    return fs
end

local function EA_CreateLine(parent, orientation, alpha)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetTexture("Interface\\Buttons\\WHITE8X8")
    if orientation == "vertical" then
        tex:SetWidth(1)
    else
        tex:SetHeight(1)
    end
    if EAStyle then
        EAStyle:OnTheme(function(p)
            tex:SetColorTexture(p.border[1], p.border[2], p.border[3], alpha or 0.85)
        end)
    else
        tex:SetColorTexture(0.28, 0.30, 0.34, alpha or 0.85)
    end
    return tex
end

local function EA_SkinTextButton(button, text, width, height)
    if not button then return button end
    if width or height then
        button:SetSize(width or button:GetWidth(), height or button:GetHeight())
    end
    if button.icon then
        button.icon:SetAlpha(0)
        button.icon:Hide()
    end
    local oldText = button.text or button._fs
    if text then
        button:SetText(text)
    elseif oldText and oldText.GetText then
        button:SetText(oldText:GetText() or "")
    end
    EA_SkinButton(button)
    local fs = button:GetFontString()
    if fs then
        fs:ClearAllPoints()
        fs:SetPoint("CENTER")
        fs:SetJustifyH("CENTER")
        fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
    end
    if oldText and oldText ~= fs and oldText.Hide then
        oldText:Hide()
    end
    button.text = fs
    button._fs = fs
    return button
end

local function EA_SetFooterButton(button, width, height)
    if not button then return button end
    button:SetSize(width or 42, height or 22)
    local fs = button:GetFontString()
    if fs then
        fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 13, "")
        fs:SetJustifyH("CENTER")
    end
    return button
end

local function EA_SetProminentButton(button, paletteKey)
    if not button then return button end
    local function apply()
        if button.IsEnabled and not button:IsEnabled() then
            if EAStyle and EAStyle.SetButtonDisabled then
                EAStyle:SetButtonDisabled(button, true)
            end
            return
        end
        if EAStyle then
            local p = EAStyle:Palette()
            if p.blizzard then
                local fs = button:GetFontString()
                if EAStyle.ApplyBlizzardButtonStyle then
                    EAStyle:ApplyBlizzardButtonStyle(button, fs, p)
                elseif EAStyle.SetButtonActive then
                    EAStyle:SetButtonActive(button, false)
                end
                return
            end
            local color = (paletteKey == "bull" and EAStyle.Bull) or p.accent
            if button.SetBackdropColor then
                button:SetBackdropColor(color[1], color[2], color[3], 0.28)
                button:SetBackdropBorderColor(color[1], color[2], color[3], 1)
            end
            if EAStyle.SetButtonBorderColor then
                EAStyle:SetButtonBorderColor(button, color, 1)
            end
            local fs = button:GetFontString()
            if fs then
                fs:SetTextColor(1, 1, 1, 1)
            end
        elseif button.SetBackdropColor then
            button:SetBackdropColor(0.10, 0.45, 0.36, 0.9)
            button:SetBackdropBorderColor(0.25, 1, 0.65, 1)
        end
    end
    button.__EAProminentApply = apply
    if EAStyle and not button.__EAProminentThemeHooked then
        button.__EAProminentThemeHooked = true
        EAStyle:OnTheme(function()
            if button.__EAProminentApply then
                button.__EAProminentApply()
            end
        end)
    end
    if not button.__EAProminentHooked then
        button.__EAProminentHooked = true
        button:HookScript("OnLeave", apply)
        button:HookScript("OnEnable", apply)
    end
    apply()
    return button
end

local function EA_SetMinimalButtonMark(button, active)
    if not button then return button end
    local function apply()
        if button.IsEnabled and not button:IsEnabled() then
            if EAStyle and EAStyle.SetButtonDisabled then
                EAStyle:SetButtonDisabled(button, true)
            end
            return
        end
        local color = active and { 0.74, 0.42, 1.00 } or { 0.52, 0.33, 0.86 }
        if EAStyle then
            local p = EAStyle:Palette()
            if p.blizzard then
                if EAStyle.SetButtonActive then
                    EAStyle:SetButtonActive(button, active)
                end
                return
            end
        end
        if button.SetBackdropColor then
            button:SetBackdropColor(color[1], color[2], color[3], active and 0.36 or 0.24)
            button:SetBackdropBorderColor(color[1], color[2], color[3], 1)
        end
        if EAStyle and EAStyle.SetButtonBorderColor then
            EAStyle:SetButtonBorderColor(button, color, 1)
        end
        local fs = button:GetFontString()
        if fs then
            fs:SetTextColor(1, 1, 1, 1)
        end
    end
    button.__EAMinimalMarkApply = apply
    button.__EAMinimalMarked = active
    if EAStyle and not button.__EAMinimalMarkThemeHooked then
        button.__EAMinimalMarkThemeHooked = true
        EAStyle:OnTheme(function()
            if button.__EAMinimalMarkApply then
                button.__EAMinimalMarkApply()
            end
        end)
    end
    if not button.__EAMinimalMarkHooked then
        button.__EAMinimalMarkHooked = true
        button:HookScript("OnLeave", apply)
        button:HookScript("OnEnable", apply)
    end
    apply()
    return button
end

local function EA_CreateAuctionIconButton(name, parent, iconTexture, tooltipTitle, tooltipText)
    local button = CreateFrame("Button", name, parent)
    button:SetSize(28, 28)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints()
    button.icon:SetTexture(iconTexture)
    button:SetHighlightTexture(iconTexture)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT")
        GameTooltip:ClearLines()
        if tooltipTitle then
            GameTooltip:AddLine(tooltipTitle, 1, 1, 1, true)
        end
        if tooltipText then
            GameTooltip:AddLine(tooltipText, 1, 0.82, 0, true)
        end
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    return button
end

local function EA_AddMainHelpTooltipLines(version)
    local helpText = _G.EASYAUCTION_HELP_TEXT or ""
    local title = helpText:match("([^\r\n]+)") or "EasyAuction拍卖行插件说明"
    local summaryByTitle = {
        ["1、自动采集拍卖价格"] = "搜索或全量扫描后记录市场最低价与历史价格。",
        ["2、快速上架与价格参考"] = "闪卖页拖入物品后参考历史价，支持压价、跟价和一键上架。",
        ["3、价格数据库与走势"] = "价格库可查看历史价格、最低价、分类和日K线走势。",
        ["4、商机发现"] = "从价格库筛选低价或套利空间大的物品。",
        ["5、常用与最近"] = "自动记录最近搜索与常用物品，方便复查和上架。",
        ["6、狙击低价物品"] = "维护目标物品和最高单价，匹配低价拍卖后购买或竞价。",
    }
    local compactLines = {}

    for line in string.gmatch(helpText, "[^\r\n]+") do
        local sectionTitle = line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        local summary = summaryByTitle[sectionTitle]
        if summary then
            compactLines[#compactLines + 1] = sectionTitle .. "：" .. summary
        end
    end
    if #compactLines == 0 then
        compactLines = {
            "1、价格采集：搜索或扫描后记录最低价与历史价格。",
            "2、闪卖上架：参考历史价，支持压价、跟价和一键上架。",
            "3、价格库/走势：查看历史价格、分类和趋势。",
            "4、商机/常用：筛选套利物品，复用最近和常用清单。",
            "5、狙击：按最高单价匹配低价拍卖并购买或竞价。",
        }
    end

    GameTooltip:AddLine("EasyAuction V" .. version .. " 使用说明", 1, 1, 1, true)
    GameTooltip:AddLine(title, 1, 0.82, 0, true)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cff00bfff核心流程|r", 0.2, 0.8, 1, true)
    GameTooltip:AddLine("先搜索或扫描采集价格，再用闪卖、价格库、商机和狙击功能做定价与购买决策。", 0.92, 0.92, 0.92, true)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cff00bfff功能摘要|r", 0.2, 0.8, 1, true)
    for i = 1, math.min(#compactLines, 6) do
        GameTooltip:AddLine(compactLines[i], 0.86, 0.86, 0.86, true)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cffff8800命令|r  /epah 打开价格库    /epsp 开关鼠标提示价格", 1, 0.75, 0.35, true)
    GameTooltip:AddLine("|cffff4040注意：|r价格仅供参考，长时间未刷新时请先重新扫描。", 1, 0.62, 0.45, true)
    GameTooltip:AddLine("点击打开指向提示；再次点击可关闭。", 0.72, 0.72, 0.72, true)
end

local function EA_SkinIconButton(button, iconTexture, width, height)
    if not button then return button end
    button:SetSize(width or 28, height or 28)
    local fs = button:GetFontString()
    if fs then
        fs:Hide()
    end
    if not button.icon then
        button.icon = button:CreateTexture(nil, "ARTWORK")
    end
    button.icon:ClearAllPoints()
    button.icon:SetAllPoints()
    button.icon:SetTexture(iconTexture)
    button.icon:SetAlpha(1)
    button.icon:Show()
    button:SetHighlightTexture(iconTexture)
    return button
end

local function EasyAuction_LayoutMainHeaderButtons()
    local btn = _G.EasyAuctionMainHelpButton
    local lockBtn = _G.EasyAuctionLockButton
    if btn and lockBtn then
        lockBtn:ClearAllPoints()
        lockBtn:SetPoint("RIGHT", btn, "LEFT", -4, 0)
        lockBtn:Show()
    end
end

local function EA_SetTextButtonActive(button, active)
    if EAStyle then
        EAStyle:SetButtonActive(button, active)
    elseif button and button:GetFontString() then
        button:GetFontString():SetTextColor(active and 0 or 1, active and 1 or 0.82, active and 1 or 0)
    end
end

local EA_ThemeDropdownButtons = {}

local function EA_GetThemeKey()
    local defaultKey = (EAStyle and EAStyle.DefaultPalette) or "blizzard"
    local key = EasyAuctionDB and EasyAuctionDB.uiPalette or defaultKey
    if EAStyle and EAStyle.NormalizePaletteKey then
        return EAStyle:NormalizePaletteKey(key)
    end
    if key == "native" then
        return "blizzard"
    end
    return key or defaultKey
end

local function EA_GetThemeName(key)
    local palette = EAStyle and EAStyle.Palettes and EAStyle.Palettes[key]
    return (palette and palette.name) or key or "暴雪风格"
end

local function EA_UpdateThemeDropdownButton(button)
    if not button then return end
    local name = EA_GetThemeName(EA_GetThemeKey())
    if button.__EAThemeCompact then
        button:SetText("主题 v")
    else
        button:SetText(name .. " v")
    end
end

local function EA_UpdateThemeDropdownMenu(menu)
    if not menu then return end
    local current = EA_GetThemeKey()
    for _, row in ipairs(menu.rows or {}) do
        row:SetText(EA_GetThemeName(row.themeKey))
        EA_SetTextButtonActive(row, row.themeKey == current)
    end
end

local function EA_UpdateThemeDropdowns()
    for _, button in ipairs(EA_ThemeDropdownButtons) do
        EA_UpdateThemeDropdownButton(button)
        EA_UpdateThemeDropdownMenu(button.__EAThemeMenu)
    end
end

local function EA_SelectTheme(key)
    if not EasyAuctionDB then return end
    if EAStyle and EAStyle.SetPalette then
        EAStyle:SetPalette(key)
    else
        EasyAuctionDB.uiPalette = key
    end
    EA_UpdateThemeDropdowns()
end

local function EA_ShowThemeDropdown(button)
    if not button or not EAStyle then return end
    local order = EAStyle.PaletteOrder or {}
    if #order == 0 then return end
    local menu = button.__EAThemeMenu
    local width = button.__EAThemeMenuWidth or button:GetWidth() or 112
    local rowHeight = 22
    if menu and menu:IsShown() then
        menu:Hide()
        return
    end
    if not menu then
        menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        menu.rows = {}
        menu:SetFrameStrata("TOOLTIP")
        menu:SetToplevel(true)
        menu:EnableMouse(true)
        if menu.SetClampedToScreen then
            menu:SetClampedToScreen(true)
        end
        EA_SkinPanel(menu, "panel")
        button.__EAThemeMenu = menu
        for i, key in ipairs(order) do
            local row = CreateFrame("Button", nil, menu, "UIPanelButtonTemplate")
            row.themeKey = key
            row:SetSize(width - 12, rowHeight)
            row:SetPoint("TOPLEFT", menu, "TOPLEFT", 6, -6 - (i - 1) * (rowHeight + 2))
            EA_SkinButton(row)
            local fs = row:GetFontString()
            if fs then
                fs:ClearAllPoints()
                fs:SetPoint("LEFT", row, "LEFT", 8, 0)
                fs:SetPoint("RIGHT", row, "RIGHT", -8, 0)
                fs:SetJustifyH("LEFT")
            end
            row:SetScript("OnClick", function(self)
                EA_SelectTheme(self.themeKey)
                menu:Hide()
            end)
            menu.rows[i] = row
        end
        button:HookScript("OnHide", function()
            if menu then
                menu:Hide()
            end
        end)
    end
    menu:SetFrameStrata("TOOLTIP")
    menu:SetSize(width, 12 + #order * (rowHeight + 2))
    menu:SetFrameLevel(math.max((button:GetFrameLevel() or 1) + 80, 80))
    for _, row in ipairs(menu.rows) do
        row:SetSize(width - 12, rowHeight)
        row:SetFrameLevel(menu:GetFrameLevel() + 2)
    end
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)
    EA_UpdateThemeDropdownMenu(menu)
    menu:Show()
end

local function EA_SetThemeDropdownButton(button, compact)
    if not button then return button end
    button.__EAThemeCompact = compact and true or false
    button.__EAThemeMenuWidth = 100
    if not button.__EAThemeDropdownRegistered then
        button.__EAThemeDropdownRegistered = true
        EA_ThemeDropdownButtons[#EA_ThemeDropdownButtons + 1] = button
        button:SetScript("OnClick", function(self)
            EA_ShowThemeDropdown(self)
        end)
        if EAStyle then
            EAStyle:OnTheme(function()
                EA_UpdateThemeDropdownButton(button)
                EA_UpdateThemeDropdownMenu(button.__EAThemeMenu)
            end)
        end
    end
    local fs = button:GetFontString()
    if fs then
        fs:ClearAllPoints()
        fs:SetPoint("LEFT", button, "LEFT", 9, 0)
        fs:SetPoint("RIGHT", button, "RIGHT", -8, 0)
        fs:SetJustifyH("LEFT")
    end
    EA_UpdateThemeDropdownButton(button)
    if EAStyle then
        EAStyle:SetTooltip(button, "选择主题", "点击打开主题列表，直接选择要使用的界面风格。")
    end
    return button
end

local function EA_SkinCloseButton(button)
    if not button then return button end
    button:SetSize(22, 22)
    button:SetText("\195\151")
    EA_SkinButton(button)
    local fs = button:GetFontString()
    if fs then
        fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 15, "")
        fs:ClearAllPoints()
        fs:SetPoint("CENTER", 0, 0)
    end
    button:HookScript("OnEnter", function()
        if EAStyle and EAStyle.Palette and EAStyle:Palette().blizzard then
            if EAStyle.ApplyBlizzardButtonStyle then
                EAStyle:ApplyBlizzardButtonStyle(button, fs, EAStyle:Palette(), true)
            end
            return
        end
        if EAStyle and button.SetBackdropColor then
            button:SetBackdropColor(EAStyle.Bear[1], EAStyle.Bear[2], EAStyle.Bear[3], 0.85)
            button:SetBackdropBorderColor(EAStyle.Bear[1], EAStyle.Bear[2], EAStyle.Bear[3], 1)
            if fs then fs:SetTextColor(1, 1, 1) end
        end
    end)
    return button
end

local function EA_RowColor(texture, index, selected)
    if EAStyle then
        EAStyle:RowColor(texture, index, selected)
    elseif texture then
        texture:SetColorTexture(1, 1, 1, (index % 2 == 0) and 0.05 or 0.10)
    end
end

local function EA_ThemeColor(name, fallback)
    if EAStyle then
        local p = EAStyle:Palette()
        return p[name] or fallback
    end
    return fallback
end

local function EA_AddLine(parent, key, layer)
    local tex = parent[key]
    if not tex then
        tex = parent:CreateTexture(nil, layer or "OVERLAY")
        parent[key] = tex
    end
    tex:SetTexture("Interface\\Buttons\\WHITE8X8")
    tex:Show()
    return tex
end

local function EA_SetLineColor(tex, alpha)
    if not tex then return end
    local c = EA_ThemeColor("border", { 0.25, 0.25, 0.30 })
    tex:SetColorTexture(c[1], c[2], c[3], alpha or 0.8)
end

local function EA_ApplyOutline(frame, alpha)
    if not frame then return end
    local top = EA_AddLine(frame, "__EAOutlineTop")
    top:ClearAllPoints()
    top:SetHeight(1)
    top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    local bottom = EA_AddLine(frame, "__EAOutlineBottom")
    bottom:ClearAllPoints()
    bottom:SetHeight(1)
    bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    local left = EA_AddLine(frame, "__EAOutlineLeft")
    left:ClearAllPoints()
    left:SetWidth(1)
    left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    local right = EA_AddLine(frame, "__EAOutlineRight")
    right:ClearAllPoints()
    right:SetWidth(1)
    right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    EA_SetLineColor(top, alpha)
    EA_SetLineColor(bottom, alpha)
    EA_SetLineColor(left, alpha)
    EA_SetLineColor(right, alpha)
end

local function EA_ApplyRowLines(row, colWidths, rowHeight)
    if not row or not colWidths then return end
    EA_ApplyOutline(row, 0.45)
    row.__EAColLines = row.__EAColLines or {}
    local x = 0
    for i = 1, #colWidths - 1 do
        x = x + colWidths[i]
        local line = row.__EAColLines[i] or row:CreateTexture(nil, "OVERLAY")
        row.__EAColLines[i] = line
        line:SetTexture("Interface\\Buttons\\WHITE8X8")
        line:ClearAllPoints()
        line:SetWidth(1)
        line:SetPoint("TOPLEFT", row, "TOPLEFT", x, 0)
        line:SetHeight(rowHeight or row:GetHeight() or 20)
        EA_SetLineColor(line, 0.35)
        line:Show()
    end
end

local function EA_CreateSwitch(parent, width)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(width or 48, 20)
    EA_SkinPanel(b, "panel")
    b.knob = b:CreateTexture(nil, "OVERLAY")
    b.knob:SetTexture("Interface\\Buttons\\WHITE8X8")
    b.knob:SetSize(16, 16)
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.label:SetPoint("CENTER")
    b.label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "")
    local checked = false
    local function ClearNativeCheckTextures(self)
        for _, tex in ipairs({
            self.GetNormalTexture and self:GetNormalTexture(),
            self.GetPushedTexture and self:GetPushedTexture(),
            self.GetDisabledTexture and self:GetDisabledTexture(),
            self.GetHighlightTexture and self:GetHighlightTexture(),
        }) do
            if tex then
                tex:SetTexture(nil)
                tex:SetAlpha(0)
                tex:Hide()
            end
        end
    end
    function b:SetCheckedState(value)
        checked = value and true or false
        local p = EAStyle and EAStyle.Palette and EAStyle:Palette() or nil
        if p and p.blizzard then
            self:SetSize(22, 20)
            if self.SetBackdrop then
                self:SetBackdrop(nil)
            end
            if self.SetNormalTexture then
                self:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
                self:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
                self:SetDisabledTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
                self:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight", "ADD")
            end
            self.knob:ClearAllPoints()
            self.knob:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
            self.knob:SetSize(20, 20)
            self.knob:SetPoint("CENTER", self, "CENTER", 0, 0)
            if checked then
                self.knob:SetAlpha(1)
                self.knob:Show()
            else
                self.knob:Hide()
            end
            self.label:SetText("")
            self.label:Hide()
            return
        end
        self:SetSize(width or 48, 20)
        ClearNativeCheckTextures(self)
        self.knob:SetTexture("Interface\\Buttons\\WHITE8X8")
        self.knob:SetSize(16, 16)
        self.knob:SetAlpha(1)
        self.knob:Show()
        self.label:Show()
        self.knob:ClearAllPoints()
        self.label:ClearAllPoints()
        if checked then
            self.knob:SetPoint("RIGHT", self, "RIGHT", -2, 0)
            self.label:SetPoint("LEFT", self, "LEFT", 7, 0)
            self.label:SetJustifyH("LEFT")
            self.label:SetText("ON")
        else
            self.knob:SetPoint("LEFT", self, "LEFT", 2, 0)
            self.label:SetPoint("RIGHT", self, "RIGHT", -7, 0)
            self.label:SetJustifyH("RIGHT")
            self.label:SetText("OFF")
        end
        if EAStyle and self.SetBackdropColor then
            local switchPalette = EAStyle:Palette()
            local bg = checked and switchPalette.accent or switchPalette.plot
            self:SetBackdropColor(bg[1], bg[2], bg[3], checked and 0.28 or 0.95)
            self:SetBackdropBorderColor(switchPalette.border[1], switchPalette.border[2], switchPalette.border[3], 1)
            self.knob:SetColorTexture(
                checked and switchPalette.accent[1] or switchPalette.muted[1],
                checked and switchPalette.accent[2] or switchPalette.muted[2],
                checked and switchPalette.accent[3] or switchPalette.muted[3],
                1
            )
            self.label:SetTextColor(
                switchPalette.text[1], switchPalette.text[2], switchPalette.text[3], checked and 1 or 0.65
            )
        end
    end
    function b.GetCheckedState()
        return checked
    end
    if EAStyle then
        EAStyle:OnTheme(function()
            b:SetCheckedState(checked)
        end)
    end
    b:SetCheckedState(false)
    return b
end

local function EA_DockRightOfMain(frame, owner, gap)
    if not frame then return end
    frame:ClearAllPoints()
    local anchor = owner
    if not (anchor and anchor.GetObjectType) then
        anchor = AuctionBar and AuctionBar.AuctionFrame
    end
    if not (anchor and anchor.GetObjectType) then
        anchor = _G.AuctionHelper
    end
    if anchor and anchor.GetObjectType and anchor:IsShown() then
        frame:SetPoint("TOPLEFT", anchor, "TOPRIGHT", gap or 6, 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

local function EA_RaiseUtilityFrame(frame, baseOwner)
    if not frame then return end
    local maxLevel = 0
    local function AddFrameLevel(candidate)
        if candidate and candidate.GetFrameLevel then
            maxLevel = math.max(maxLevel, candidate:GetFrameLevel() or 0)
        end
    end

    local owner = baseOwner or (AuctionBar and AuctionBar.AuctionFrame)
    AddFrameLevel(owner)
    AddFrameLevel(_G.AuctionHelper)
    if owner then
        AddFrameLevel(owner.ItemsFrame)
        AddFrameLevel(owner.MyAuctionListFrame)
    end
    if AuctionBar and AuctionBar.AuctionFrame and AuctionBar.AuctionFrame ~= owner then
        AddFrameLevel(AuctionBar.AuctionFrame)
        AddFrameLevel(AuctionBar.AuctionFrame.ItemsFrame)
        AddFrameLevel(AuctionBar.AuctionFrame.MyAuctionListFrame)
    end

    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(math.max(maxLevel + 50, 200))
    frame:SetToplevel(true)
    local Pro = ns and ns.EasyAuctionPro
    if Pro and Pro.BringFrameToFront then
        Pro.BringFrameToFront(frame, { strata = "FULLSCREEN_DIALOG", minLevel = 200 })
    end
end

-- 声明局部变量，将在 ADDON_LOADED 事件后指向当前服务器-阵营的数据库
local EasyAuctionDB

local function EA_GetAddonMetadata(name, field)
    if type(GetAddOnMetadata) == "function" then
        return GetAddOnMetadata(name, field)
    end
    if C_AddOns and type(C_AddOns.GetAddOnMetadata) == "function" then
        return C_AddOns.GetAddOnMetadata(name, field)
    end
end

local function EA_GetAddonEnableState(name, character)
    if C_AddOns and type(C_AddOns.GetAddOnEnableState) == "function" then
        return C_AddOns.GetAddOnEnableState(name, character)
    end
    if type(GetAddOnEnableState) == "function" then
        return GetAddOnEnableState(character, name)
    end
end

local function NormalizePositiveInt(value, fallback)
    value = math.floor(tonumber(value) or fallback or 1)
    if value < 1 then
        value = fallback or 1
    end
    return value
end

local EA_LAYOUT_MIGRATION_VERSION = 4
local EA_DEFAULT_UI_SCALE = 1.0

local function EA_NormalizeLayoutDB(db, forceReset)
    if not db then return end
    local migrated = tonumber(db.layoutMigrationVersion or 0) < EA_LAYOUT_MIGRATION_VERSION

    if type(db.showSections) ~= "table" then
        db.showSections = { items = true, price = true, myauct = true }
    else
        db.showSections.items = db.showSections.items == true
        db.showSections.price = db.showSections.price ~= false
        db.showSections.myauct = db.showSections.myauct ~= false
    end
    if migrated and not db.showSections.items and not db.showSections.price and not db.showSections.myauct then
        db.showSections.items = true
        db.showSections.price = true
        db.showSections.myauct = true
    end
    if migrated then
        db.showSections.price = true
    end

    local scale = tonumber(db.uiScale)
    if forceReset or not scale or scale < 0.5 or scale > 1.2 then
        db.uiScale = EA_DEFAULT_UI_SCALE
    else
        db.uiScale = math.floor(scale * 100 + 0.5) / 100
    end

    if type(db.LastActiveTab) ~= "number" or db.LastActiveTab < 1 or db.LastActiveTab > 4 then
        db.LastActiveTab = 1
    end
    if db.locked ~= false then
        db.locked = true
        db.customPos = nil
    elseif type(db.customPos) ~= "table" then
        db.customPos = nil
    end

    db.layoutMigrationVersion = EA_LAYOUT_MIGRATION_VERSION
end

local function EasyAuction_AddOperationHistory(entry)
    if not EasyAuctionDB or type(entry) ~= "table" then return end
    entry.charName = entry.charName or (UnitName("player") or "Unknown")
    EasyAuctionDB.OperationHistory = EasyAuctionDB.OperationHistory or {}
    table.insert(EasyAuctionDB.OperationHistory, entry)
    if #EasyAuctionDB.OperationHistory > 500 then
        table.sort(EasyAuctionDB.OperationHistory, function(a, b) return (a.time or 0) > (b.time or 0) end)
        for i = #EasyAuctionDB.OperationHistory, 501, -1 do
            EasyAuctionDB.OperationHistory[i] = nil
        end
    end
end

local function ApplyFrameDBDefaults()
    if not EasyAuctionDB then return end

    -- 设置默认值
    if EasyAuctionDB.bidDiscount == nil then EasyAuctionDB.bidDiscount = 0.99 end -- 起拍折扣比例，默认0.99
    if EasyAuctionDB.undercut == nil then EasyAuctionDB.undercut = 1 end           -- 压价金额，铜
    if EasyAuctionDB.stackCount == nil then EasyAuctionDB.stackCount = 20 end      -- 默认堆叠数
    if EasyAuctionDB.defaultNumStacks == nil then EasyAuctionDB.defaultNumStacks = 1 end -- 默认组数
    if EasyAuctionDB.auctionDuration == nil then EasyAuctionDB.auctionDuration = 1 end -- 默认12小时
    EA_NormalizeLayoutDB(EasyAuctionDB, false)
    if EasyAuctionDB.buyRiskLimit == nil then EasyAuctionDB.buyRiskLimit = 500 end -- 购买风控价格500金
    if EasyAuctionDB.uiScale == nil or EasyAuctionDB.uiScale > 1.2 then EasyAuctionDB.uiScale = EA_DEFAULT_UI_SCALE end
    if EasyAuctionDB.uiPalette == nil then EasyAuctionDB.uiPalette = "blizzard" end
    if EasyAuctionDB.playerGoldDay == nil then EasyAuctionDB.playerGoldDay = date("%Y-%m-%d") end
    if EasyAuctionDB.playerGoldToday == nil then EasyAuctionDB.playerGoldToday = type(GetMoney) == "function" and GetMoney() or 0 end
    if EasyAuctionDB.playerGoldYesterday == nil then EasyAuctionDB.playerGoldYesterday = EasyAuctionDB.playerGoldToday end
    if EasyAuctionDB.locked == nil then
        EasyAuctionDB.locked = true
    end
    EasyAuctionDB.customPos = EasyAuctionDB.customPos or nil
    if EasyAuctionDB.autoFillLastAuction == nil then EasyAuctionDB.autoFillLastAuction = false end
    if EasyAuctionDB.enableBrowseBuyButton == nil then
        EasyAuctionDB.enableBrowseBuyButton = true
    end
    if EasyAuctionDB.enableBrowseBidButton == nil then
        EasyAuctionDB.enableBrowseBidButton = true
    end
    if EasyAuctionDB.enableSearchBoxProtection == nil then
        EasyAuctionDB.enableSearchBoxProtection = true
    end
    if EasyAuctionDB.OperationHistory == nil then EasyAuctionDB.OperationHistory = {} end
    if EasyAuctionDB.LastActiveTab == nil then EasyAuctionDB.LastActiveTab = 1 end
    if EasyAuctionDB.SnipeList == nil then EasyAuctionDB.SnipeList = {} end
    if EasyAuctionDB.BidDiscountRatio == nil then EasyAuctionDB.BidDiscountRatio = 0.95 end
    if EasyAuctionDB.SnipeCheckDisenchant == nil then EasyAuctionDB.SnipeCheckDisenchant = true end
    if EasyAuctionDB.SnipeCheckVendor == nil then EasyAuctionDB.SnipeCheckVendor = true end
    EasyAuctionDB.scanKeepPerItem = NormalizePositiveInt(EasyAuctionDB.scanKeepPerItem or 120, 120)
    EasyAuctionDB.dailyKeepDays = NormalizePositiveInt(
        EasyAuctionDB.dailyKeepDays or EasyAuctionDB.historyKeepDays or 30,
        NormalizePositiveInt(EasyAuctionDB.historyKeepDays or 30, 30)
    )
    EasyAuctionDB.hourlyKeepHours = math.min(
        24,
        NormalizePositiveInt(EasyAuctionDB.hourlyKeepHours or 24, 24)
    )
    if EasyAuctionDB.SellPanel == nil then
        EasyAuctionDB.SellPanel = true
    end
    if EasyAuctionDB.CategoryOverrides == nil then
        EasyAuctionDB.CategoryOverrides = {}
    end
    if EasyAuctionDB.MinimalModeActive == nil and type(EasyAuctionDB.AddonBackup) ~= "table" then
        EasyAuctionDB.MinimalModeActive = false
    end
end

-- 延迟初始化函数，在 ADDON_LOADED 事件中调用
local function InitFrameDB()
    -- 从全局获取当前服务器-阵营的数据库引用
    EasyAuctionDB = _G.EasyAuctionDB
    if not EasyAuctionDB then return end

    ApplyFrameDBDefaults()
end

function EasyAuction_RebindFrameDB()
    EasyAuctionDB = _G.EasyAuctionDB
    ApplyFrameDBDefaults()
    return EasyAuctionDB
end

EasyAuction_SessionBuyStats = {}
EasyAuction_NeedAutoFillFromRecent = false
local EA_pendingAutoNumStacks = 0
local LastAuctionSold = {
    name = nil,
    itemID = nil,
    unitPrice = nil,
    Progress = false,
}

local LastBuyItemID, LastBuyName, LastBuyCount, LastBuyUnitPrice = nil, nil, nil, nil

-- 当前选择的拍卖时长
local selectedDuration = 1

-- 延迟获取 selectedDuration，在初始化后
local function GetSelectedDuration()
    return EasyAuctionDB and EasyAuctionDB.auctionDuration or selectedDuration or 1
end

-- 设置拍卖时长
local function SetSelectedDuration(val)
    selectedDuration = val
    if EasyAuctionDB then
        EasyAuctionDB.auctionDuration = val
    end
end
local function GetCopper(g, s, c) return (g or 0) * 10000 + (s or 0) * 100 + (c or 0) end
local function SplitCopper(c)
    return math.floor(c / 10000), math.floor((c % 10000) / 100), c % 100
end

local function GetAutoFillFlashSellCounts(availableStackCount, availableTotalCount)
    local stackCount = NormalizePositiveInt(EasyAuctionDB and EasyAuctionDB.stackCount or 20, 20)
    local numStacks = NormalizePositiveInt(EasyAuctionDB and EasyAuctionDB.defaultNumStacks or 1, 1)
    if availableStackCount and availableStackCount > 0 and stackCount > availableStackCount then
        stackCount = availableStackCount
    end
    if availableTotalCount and availableTotalCount > 0 and stackCount > availableTotalCount then
        stackCount = availableTotalCount
    end
    if stackCount < 1 then
        stackCount = 1
    end
    if availableTotalCount and availableTotalCount > 0 then
        local maxGroups = math.floor(availableTotalCount / stackCount)
        if maxGroups < 1 then
            maxGroups = 1
        end
        if numStacks > maxGroups then
            numStacks = maxGroups
        end
    end
    return stackCount, numStacks
end

local version = EA_GetAddonMetadata(addonName, "Version") or "?"

local ITEM_QUALITY_COLORS = {
    [0] = { r = 0.62, g = 0.62, b = 0.62 },
    [1] = { r = 1, g = 1, b = 1 },
    [2] = { r = 0.12, g = 1, b = 0 },
    [3] = { r = 0.1, g = 0.44, b = 1 },
    [4] = { r = 0.64, g = 0.21, b = 0.93 },
    [5] = { r = 1, g = 0.5, b = 0 },
    [6] = { r = 0.9, g = 0.8, b = 0.5 },
}
local CLASS_MAP = {
    [0] = "消耗品",
    [1] = "容器",
    [2] = "武器",
    [3] = "宝石",
    [4] = "护甲",
    [5] = "材料",
    [6] = "弹药",
    [7] = "商品",
    [9] = "配方",
    [15] = "杂项",
}
local CLASS_ORDER = { "消耗品", "商品", "材料", "武器", "护甲", "容器", "宝石", "配方", "杂项", "其他" }

local function tIndexOf(t, val)
    for i, v in ipairs(t) do if v == val then return i end end
end

local function CategorizeItems(items)
    local groups, order = {}, {}
    for _, item in ipairs(items) do
        local cname = CLASS_MAP[item.classID] or "其他"
        if not groups[cname] then
            groups[cname] = {}
            table.insert(order, cname)
        end
        table.insert(groups[cname], item)
    end
    table.sort(order, function(a, b)
        local ia, ib = tIndexOf(CLASS_ORDER, a), tIndexOf(CLASS_ORDER, b)
        return (ia or 99) < (ib or 99)
    end)
    return groups, order
end

local function FixItemButtonIconSize(btn, size)
    if not btn then return end
    size = tonumber(size) or math.min(btn:GetWidth() or 40, btn:GetHeight() or 40)
    if not size or size <= 0 then size = 40 end
    if btn.SetClipsChildren then
        btn:SetClipsChildren(true)
    end
    local inset = size >= 56 and 5 or 3
    local name = btn.GetName and btn:GetName()
    local normal = btn.GetNormalTexture and btn:GetNormalTexture()
    local pushed = btn.GetPushedTexture and btn:GetPushedTexture()
    local highlight = btn.GetHighlightTexture and btn:GetHighlightTexture()
    local iconBorder = name and _G[name .. "IconBorder"]
    local icon = (name and (_G[name .. "IconTexture"] or _G[name .. "Icon"]))
        or btn.IconTexture or btn.Icon or btn.iconTexture or btn.icon
    if not icon and btn.GetRegions then
        local regions = { btn:GetRegions() }
        for i = 1, #regions do
            local region = regions[i]
            if region and region.GetObjectType and region:GetObjectType() == "Texture"
                and region ~= normal
                and region ~= pushed
                and region ~= highlight
                and region ~= iconBorder
                and not region.__EAItemSlotChrome
                and not region.__EAStyleBorder then
                icon = region
                break
            end
        end
    end
    local function HideTemplateTexture(texture)
        if not texture then return end
        texture:SetAlpha(0)
        texture:Hide()
    end
    if not btn.__EAItemSlotChrome then
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg.__EAItemSlotChrome = true
        bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        bg:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
        bg:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)

        local border = {}
        border.top = btn:CreateTexture(nil, "OVERLAY")
        border.bottom = btn:CreateTexture(nil, "OVERLAY")
        border.left = btn:CreateTexture(nil, "OVERLAY")
        border.right = btn:CreateTexture(nil, "OVERLAY")
        for _, tex in pairs(border) do
            tex.__EAItemSlotChrome = true
            tex:SetTexture("Interface\\Buttons\\WHITE8X8")
        end
        border.top:SetHeight(2)
        border.bottom:SetHeight(2)
        border.left:SetWidth(2)
        border.right:SetWidth(2)
        border.top:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
        border.top:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
        border.bottom:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
        border.bottom:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
        border.left:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
        border.left:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
        border.right:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
        border.right:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)

        btn.__EAItemSlotChrome = {
            bg = bg,
            border = border,
        }
    end
    if btn.__EAItemSlotChrome then
        local bg = btn.__EAItemSlotChrome.bg
        if bg then
            bg:SetColorTexture(0, 0, 0, 0.55)
            bg:Show()
        end
        local color = EA_ThemeColor("border", { 0.78, 0.64, 0.33 })
        for _, tex in pairs(btn.__EAItemSlotChrome.border or {}) do
            tex:SetColorTexture(color[1], color[2], color[3], 0.95)
            tex:Show()
        end
    end
    if icon then
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", btn, "TOPLEFT", inset, -inset)
        icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -inset, inset)
        if icon.SetTexCoord then
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
        icon:SetAlpha(1)
        icon:Show()
    end
    HideTemplateTexture(iconBorder)
    HideTemplateTexture(normal)
    HideTemplateTexture(pushed)
    HideTemplateTexture(highlight)
end

if type(hooksecurefunc) == "function" and not ns.__EAMainItemButtonTextureHooked then
    local function RefineMainItemButton(button)
        if button and button.GetName and button:GetName() == "EasyAuctionItemButton" then
            FixItemButtonIconSize(button, button:GetWidth() or 40)
        end
    end
    if type(SetItemButtonTexture) == "function" then
        hooksecurefunc("SetItemButtonTexture", RefineMainItemButton)
    end
    if type(SetItemButtonQuality) == "function" then
        hooksecurefunc("SetItemButtonQuality", RefineMainItemButton)
    end
    ns.__EAMainItemButtonTextureHooked = true
end

local function ApplyEasyAuctionUIScale()
    local scale = EasyAuctionDB.uiScale or EA_DEFAULT_UI_SCALE
    if AuctionBar and AuctionBar.AuctionFrame then
        AuctionBar.AuctionFrame:SetScale(scale)
    end
    if EasyAuction_HelpFrame then
        EasyAuction_HelpFrame:SetScale(scale)
    end
    if EasyAuctionConfigFrame then
        EasyAuctionConfigFrame:SetScale(scale)
    end
    if EasyAuctionDBFrame then
        EasyAuctionDBFrame:SetScale(scale)
    end
    if _G.EasyAuctionBagValueFrame then
        _G.EasyAuctionBagValueFrame:SetScale(scale)
    end
    local Pro = ns and ns.EasyAuctionPro
    if Pro and Pro.ApplyAllFrameScale then
        Pro.ApplyAllFrameScale()
    end
end

local function CreateBaseFrame(name, parent, width, height)
    local f = CreateFrame("Frame", name or nil, parent or UIParent, "BackdropTemplate")
    f:SetSize(width or 305, height or 350)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    if EAStyle then
        EAStyle:Skin(f, "window")
    else
        f:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 18,
            insets = { left = 6, right = 6, top = 6, bottom = 6 }
        })
        f:SetBackdropColor(0.10, 0.10, 0.13, 0.97)
        f:SetBackdropBorderColor(0.7, 0.6, 1, 1)
    end
    f:SetMovable(true)
    f:SetToplevel(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        if not EasyAuctionDB.locked then
            self:StartMoving()
        end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if not EasyAuctionDB.locked then
            local point, relativeTo, relativePoint, x, y = self:GetPoint()
            EasyAuctionDB.customPos = {
                point = point,
                relativeTo = relativeTo and relativeTo:GetName() or "UIParent",
                relativePoint = relativePoint,
                x = x,
                y = y
            }
        end
    end)
    return f
end

local function CreateNumericBox(parent, width)
    local edit = CreateFrame("EditBox", nil, parent)
    edit:SetAutoFocus(false)
    edit:SetNumeric(true)
    edit:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    edit:SetSize(width or 40, 20)

    edit.bg = edit:CreateTexture(nil, "BACKGROUND")
    edit.bg:SetAllPoints()
    if EAStyle then
        local p = EAStyle:Palette()
        local input = p.input or p.plot
        edit.bg:SetColorTexture(input[1], input[2], input[3], 0.9)
    else
        edit.bg:SetColorTexture(0, 0, 0, 0.8)
    end

    EA_ApplyOutline(edit, 0.75)
    if EAStyle then
        EAStyle:OnTheme(function(p)
            local input = p.input or p.plot
            edit.bg:SetColorTexture(input[1], input[2], input[3], 0.9)
            edit.__EAOutlineTop:SetColorTexture(p.border[1], p.border[2], p.border[3], 0.75)
            edit.__EAOutlineBottom:SetColorTexture(p.border[1], p.border[2], p.border[3], 0.75)
            edit.__EAOutlineLeft:SetColorTexture(p.border[1], p.border[2], p.border[3], 0.75)
            edit.__EAOutlineRight:SetColorTexture(p.border[1], p.border[2], p.border[3], 0.75)
        end)
    end

    edit:SetTextInsets(4, 4, 0, 0)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    edit:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
        if not self.__BlurFrame then
            self.__BlurFrame = CreateFrame("Frame", nil, UIParent)
            self.__BlurFrame:SetAllPoints(UIParent)
            self.__BlurFrame:SetFrameStrata("FULLSCREEN_DIALOG")
            self.__BlurFrame:EnableMouse(true)
            self.__BlurFrame:SetScript("OnMouseDown", function(frame)
                if self:HasFocus() then self:ClearFocus() end
                frame:Hide()
            end)
        end
        self.__BlurFrame:Show()
        self.__BlurFrame:SetFrameLevel((self:GetFrameLevel() or 10) + 10)
    end)
    edit:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
        if self.__BlurFrame then self.__BlurFrame:Hide() end
    end)
    return edit
end


local function SetMoneyEdit(targetGold, targetSilver, targetCopper, value)
    local gold = math.floor(value / 10000)
    local silver = math.floor((value % 10000) / 100)
    local copper = value % 100
    targetGold:SetNumber(gold)
    targetSilver:SetNumber(silver)
    targetCopper:SetNumber(copper)
end

local function UpdateStackPrice(frame)
    if not frame then
        return
    end
    local name = GetAuctionSellItemInfo and GetAuctionSellItemInfo()
    if not name or name == "" then
        SetMoneyEdit(frame.UnitGold, frame.UnitSilver, frame.UnitCopper, 0)
        SetMoneyEdit(frame.StackGold, frame.StackSilver, frame.StackCopper, 0)
        SetMoneyEdit(frame.BidGold, frame.BidSilver, frame.BidCopper, 0)
        frame.StackCount:SetNumber(0)
        frame.NumStacks:SetNumber(0)
        return
    end

    local unitGold           = frame.UnitGold:GetNumber()
    local unitSilver         = frame.UnitSilver:GetNumber()
    local unitCopper         = frame.UnitCopper:GetNumber()
    local count              = frame.StackCount:GetNumber()
    local unit               = (unitGold * 10000 + unitSilver * 100 + unitCopper)
    local stackTotal         = unit * count
    local undercut           = EasyAuctionDB.undercut or 1
    local undercutMode       = EasyAuctionDB.undercutMode or "total"
    local enableUndercut     = EasyAuctionDB.enableUndercut ~= false

    local undercutStackTotal = stackTotal
    if enableUndercut then
        if undercutMode == "total" then
            undercutStackTotal = math.max(stackTotal - undercut, 1)
        else
            local newUnit = math.max(unit - undercut, 1)
            undercutStackTotal = newUnit * count
        end
    end
    SetMoneyEdit(frame.StackGold, frame.StackSilver, frame.StackCopper, undercutStackTotal)

    local bidDiscount = EasyAuctionDB.bidDiscount or 0.99
    local bidTotal = math.floor(undercutStackTotal * bidDiscount)
    SetMoneyEdit(frame.BidGold, frame.BidSilver, frame.BidCopper, bidTotal)
    if frame.__EARefreshHeader then
        frame.__EARefreshHeader()
    end
end

function ScanBagAuctionableItems()
    local itemsByID = {}
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID and info.stackCount and info.stackCount > 0 then
                local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
                local itemName, _, quality, _, _, _, _, _, _, _, _, classID = C_Item.GetItemInfo(info.hyperlink)
                local auctionable = false
                if C_AuctionHouse then
                    auctionable = C_AuctionHouse.IsSellItemValid(location, false)
                else
                    auctionable = not C_Item.IsBound(location)
                end
                if auctionable then
                    if not itemsByID[info.itemID] then
                        itemsByID[info.itemID] = {
                            bag = bag,
                            slot = slot,
                            itemID = info.itemID,
                            icon = info.iconFileID,
                            count = info.stackCount,
                            quality = quality,
                            classID = classID,
                            itemName = itemName,
                            itemLink = info.hyperlink,
                        }
                    else
                        itemsByID[info.itemID].count = itemsByID[info.itemID].count + info.stackCount
                    end
                end
            end
        end
    end
    local items = {}
    for _, v in pairs(itemsByID) do
        table.insert(items, v)
    end
    return items
end

local function ShowBorder(frame, color)
    local t = frame:CreateTexture(nil, "BACKGROUND")
    t:SetAllPoints()
    t:SetColorTexture(unpack(color or { 0, 0, 0, 0.8 }))
end

local function SetupAutoBlurForEditBox(editBox, onSave)
    editBox:SetAutoFocus(false)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        if onSave then onSave(self) end
    end)
    editBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        if onSave then onSave(self) end
    end)
    editBox:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()

        if not self.__BlurFrame then
            self.__BlurFrame = CreateFrame("Frame", nil, UIParent)
            self.__BlurFrame:SetAllPoints(UIParent)
            self.__BlurFrame:SetFrameStrata("FULLSCREEN_DIALOG")
            self.__BlurFrame:EnableMouse(true)
            self.__BlurFrame:SetPropagateKeyboardInput(true)
            self.__BlurFrame:SetScript("OnMouseDown", function(frame, btn)
                if not editBox:HasFocus() then return end
                editBox:ClearFocus()
                if onSave then onSave(editBox) end
                frame:Hide()
            end)
        end
        self.__BlurFrame:Show()
        self.__BlurFrame:SetFrameLevel((self:GetFrameLevel() or 10) + 10)
    end)
    editBox:SetScript("OnEditFocusLost", function(self)
        self:HighlightText(0, 0)
        if self.__BlurFrame then self.__BlurFrame:Hide() end
        if onSave then onSave(self) end
    end)
end

function CreateEasyAuctionConfigFrame(parent)
    EasyAuctionDB = EasyAuction_RebindFrameDB() or EasyAuctionDB
    if EasyAuctionConfigFrame then return end
    local width, height = 430, 620
    local frameParent = (parent and parent.GetObjectType and parent) or UIParent
    local frame = CreateFrame("Frame", "EasyAuctionConfigFrame", frameParent, "BackdropTemplate")
    frame:SetSize(width, height)
    if parent and parent.GetObjectType then
        frame:SetPoint("TOPLEFT", parent, "TOPRIGHT", 6, 0)
    elseif AuctionHelper and AuctionHelper:IsShown() and AuctionHelper.EAFooter then
        frame:SetPoint("TOPLEFT", AuctionHelper, "TOPRIGHT", 6, 0)
    elseif AuctionHelper and AuctionHelper:IsShown() then
        frame:SetPoint("TOPLEFT", AuctionHelper, "TOPRIGHT", 6, 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", -400, 0)
    end
    EA_RaiseUtilityFrame(frame, frameParent)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetToplevel(true)
    EA_SkinFrame(frame, "window")
    frame:SetScript("OnMouseDown", function(self, btn)
        if btn == "LeftButton" then self:StartMoving() end
    end)
    frame:SetScript("OnMouseUp", function(self) self:StopMovingOrSizing() end)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText("EasyAuction 设置")
    EA_SkinText(title, "accent")

    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
    EA_SkinCloseButton(closeBtn)
    closeBtn:SetScript("OnClick", function() frame:Hide() end)

    local tabState = { pages = {}, buttons = {}, active = "tips" }
    for i, info in ipairs({
        { key = "tips", text = "鼠标提示设置" },
        { key = "auction", text = "拍卖功能设置" },
        { key = "mail", text = "邮箱功能设置" },
    }) do
        local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        button:SetSize(128, 24)
        button:SetPoint("TOPLEFT", frame, "TOPLEFT", 14 + (i - 1) * 134, -42)
        button.configPageKey = info.key
        EA_SkinTextButton(button, info.text, 128, 24)
        tabState.buttons[info.key] = button

        local page = CreateFrame("Frame", nil, frame)
        page:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -76)
        page:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 122)
        page:Hide()
        tabState.pages[info.key] = page
    end

    local function ShowConfigTab(key)
        if not tabState.pages[key] then key = "tips" end
        tabState.active = key
        for pageKey, page in pairs(tabState.pages) do
            page:SetShown(pageKey == key)
            EA_SetTextButtonActive(tabState.buttons[pageKey], pageKey == key)
        end
    end
    for _, button in pairs(tabState.buttons) do
        button:SetScript("OnClick", function(self) ShowConfigTab(self.configPageKey) end)
    end
    frame.pages = tabState.pages
    frame.mailSettingsHost = tabState.pages.mail
    frame.EA_ShowConfigCategory = ShowConfigTab
    frame.EA_ShowAddonConfigTab = ShowConfigTab

    local interfaceFooter = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    interfaceFooter:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 46)
    interfaceFooter:SetSize(402, 64)
    EA_SkinPanel(interfaceFooter, "panel")
    EA_ApplyOutline(interfaceFooter, 0.58)

    local pageAuction = tabState.pages.auction
    local pageTips = tabState.pages.tips

    local labelWidth = 112
    local inputStartX = 118
    local auctionContent
    local cfgRows = {
        [1] = -34,
        [2] = -62,
        [6] = -90,
        [3] = -164,
        [4] = -192,
        [5] = -220,
        [8] = -294,
        [9] = -322,
        [10] = -350,
    }

    local function GetCfgRowY(row)
        return cfgRows[row] or -34
    end

    local function AddAuctionPanel(x, y, w, h)
        local panel = CreateFrame("Frame", nil, pageAuction, "BackdropTemplate")
        panel:SetPoint("TOPLEFT", pageAuction, "TOPLEFT", x, y)
        panel:SetSize(w, h)
        EA_SkinPanel(panel, "panel")
        EA_ApplyOutline(panel, 0.58)
        return panel
    end

    local function AddAuctionSection(x, y, w, text)
        local fs = pageAuction:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", pageAuction, "TOPLEFT", x + 8, y)
        fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
        fs:SetText(text)
        EA_SkinText(fs, "accent")
        local line = pageAuction:CreateTexture(nil, "OVERLAY")
        line:SetTexture("Interface\\Buttons\\WHITE8X8")
        line:SetHeight(1)
        line:SetPoint("LEFT", fs, "RIGHT", 8, 0)
        line:SetPoint("RIGHT", pageAuction, "TOPLEFT", x + w - 8, y)
        EA_SetLineColor(line, 0.45)
        return fs
    end

    local function AddCfgLabel(text, row)
        local l = auctionContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        l:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
        l:SetPoint("TOPRIGHT", auctionContent, "TOPLEFT", labelWidth - 25, GetCfgRowY(row))
        l:SetJustifyH("RIGHT")
        l:SetWidth(labelWidth)
        l:SetText(text)
        EA_SkinText(l, "text")
        return l
    end

    local function AddCfgEditBox(width, row, dx)
        local box = CreateNumericBox(auctionContent, width)
        box:SetPoint("TOPLEFT", inputStartX + (dx or 0) - 20, GetCfgRowY(row) + 1)
        box:SetJustifyH("RIGHT")
        return box
    end

    AddAuctionPanel(0, -18, 402, 104)
    AddAuctionSection(0, -4, 402, "上架价格")
    AddAuctionPanel(0, -148, 195, 104)
    AddAuctionSection(0, -134, 195, "默认上架")
    AddAuctionPanel(0, -278, 195, 104)
    AddAuctionSection(0, -264, 195, "数据与扫描")
    auctionContent = CreateFrame("Frame", nil, pageAuction)
    auctionContent:SetAllPoints(pageAuction)
    auctionContent:SetFrameLevel(pageAuction:GetFrameLevel() + 8)

    local labelHistoryDays = AddCfgLabel("保留天数：", 9)
    labelHistoryDays:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("价格历史保留天数", 1, 1, 1)
        GameTooltip:AddLine("只保留最近N天的价格记录，过期数据会自动清理。", 1, .82, 0, 1)
        GameTooltip:Show()
    end)
    labelHistoryDays:SetScript("OnLeave", GameTooltip_Hide)

    local boxHistoryDays = AddCfgEditBox(52, 9)
    boxHistoryDays:SetNumber(EasyAuctionDB.historyKeepDays or 30)
    SetupAutoBlurForEditBox(boxHistoryDays, function(self)
        local v = tonumber(self:GetText()) or 30
        if v < 1 then v = 1 elseif v > 999 then v = 999 end
        EasyAuctionDB.historyKeepDays = v
        self:SetNumber(v)
    end)
    boxHistoryDays:SetScript("OnEnter", labelHistoryDays:GetScript("OnEnter"))
    boxHistoryDays:SetScript("OnLeave", GameTooltip_Hide)

    local labelHistoryMax = AddCfgLabel("保留条数：", 10)
    labelHistoryMax:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("每物品保留条数", 1, 1, 1)
        GameTooltip:AddLine("每种物品最多保留多少条历史，0为不限制。", 1, .82, 0, 1)
        GameTooltip:Show()
    end)
    labelHistoryMax:SetScript("OnLeave", GameTooltip_Hide)

    local boxHistoryMax = AddCfgEditBox(52, 10)
    boxHistoryMax:SetNumber(EasyAuctionDB.historyMaxEntry or 0)
    SetupAutoBlurForEditBox(boxHistoryMax, function(self)
        local v = tonumber(self:GetText()) or 0
        if v < 0 then v = 0 elseif v > 9999 then v = 9999 end
        EasyAuctionDB.historyMaxEntry = v
        self:SetNumber(v)
    end)
    boxHistoryMax:SetScript("OnEnter", labelHistoryMax:GetScript("OnEnter"))
    boxHistoryMax:SetScript("OnLeave", GameTooltip_Hide)


    local labelDiscount = AddCfgLabel("起拍折扣：", 1)
    labelDiscount:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("起拍折扣", 1, 1, 1)
        GameTooltip:AddLine("设置起拍总价为一口价总价的百分比。\n如99即起拍价=一口价×0.99", 1, .82, 0, 1)
        GameTooltip:Show()
    end)
    labelDiscount:SetScript("OnLeave", GameTooltip_Hide)
    local boxDiscount = AddCfgEditBox(40, 1)
    boxDiscount:SetNumber((EasyAuctionDB.bidDiscount or 0.99) * 100)
    boxDiscount:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("起拍折扣", 1, 1, 1)
        GameTooltip:AddLine("设置起拍价为一口价的百分比。\n如99即起拍价=一口价×0.99", 1, .82, 0, 1)
        GameTooltip:Show()
    end)
    boxDiscount:SetScript("OnLeave", GameTooltip_Hide)
    SetupAutoBlurForEditBox(boxDiscount, function(self)
        local v = tonumber(self:GetText()) or 99
        if v < 1 then v = 1 elseif v > 100 then v = 100 end
        EasyAuctionDB.bidDiscount = v / 100
        self:SetNumber(v)
        UpdateStackPrice(AuctionBar.AuctionFrame)
    end)

    local labelUndercut = AddCfgLabel("压价金额：", 2)
    labelUndercut:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("自动压价", 1, 1, 1)
        GameTooltip:AddLine("自动比市场最低价低指定金额上架。\n如1银，则自动一口价-1银。", 1, .82, 0, 1)
        GameTooltip:Show()
    end)
    labelUndercut:SetScript("OnLeave", GameTooltip_Hide)
    local boxGold = AddCfgEditBox(40, 2)
    boxGold:SetNumber(math.floor((EasyAuctionDB.undercut or 1) / 10000))
    local iconGold = auctionContent:CreateTexture(nil, "ARTWORK")
    iconGold:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
    iconGold:SetSize(12, 12)
    iconGold:SetPoint("LEFT", boxGold, "RIGHT", 1, 0)

    local boxSilver = AddCfgEditBox(35, 2, 52)
    boxSilver:SetNumber(math.floor(((EasyAuctionDB.undercut or 1) % 10000) / 100))
    local iconSilver = auctionContent:CreateTexture(nil, "ARTWORK")
    iconSilver:SetTexture("Interface\\MoneyFrame\\UI-SilverIcon")
    iconSilver:SetSize(12, 12)
    iconSilver:SetPoint("LEFT", boxSilver, "RIGHT", 1, 0)

    local boxCopper = AddCfgEditBox(35, 2, 100)
    boxCopper:SetNumber((EasyAuctionDB.undercut or 1) % 100)
    local iconCopper = auctionContent:CreateTexture(nil, "ARTWORK")
    iconCopper:SetTexture("Interface\\MoneyFrame\\UI-CopperIcon")
    iconCopper:SetSize(12, 12)
    iconCopper:SetPoint("LEFT", boxCopper, "RIGHT", 1, 0)

    local function SaveUndercut()
        EasyAuctionDB.undercut = GetCopper(boxGold:GetNumber(), boxSilver:GetNumber(), boxCopper:GetNumber())
        if AuctionHelper and AuctionHelper:IsShown() then
            UpdateStackPrice(AuctionBar.AuctionFrame)
        end
    end
    SetupAutoBlurForEditBox(boxGold, SaveUndercut)
    SetupAutoBlurForEditBox(boxSilver, SaveUndercut)
    SetupAutoBlurForEditBox(boxCopper, SaveUndercut)
    boxGold:SetScript("OnTextChanged", SaveUndercut)
    boxSilver:SetScript("OnTextChanged", SaveUndercut)
    boxCopper:SetScript("OnTextChanged", SaveUndercut)

    boxGold:SetScript("OnLeave", GameTooltip_Hide)
    boxSilver:SetScript("OnEnter", boxGold:GetScript("OnEnter"))
    boxSilver:SetScript("OnLeave", GameTooltip_Hide)
    boxCopper:SetScript("OnEnter", boxGold:GetScript("OnEnter"))
    boxCopper:SetScript("OnLeave", GameTooltip_Hide)

    local labelStack = AddCfgLabel("默认堆叠：", 3)
    labelStack:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("默认堆叠数", 1, 1, 1)
        GameTooltip:AddLine("每次上架默认每组的物品数量。\n如20表示每组20个。", 1, .82, 0, 1)
        GameTooltip:Show()
    end)
    labelStack:SetScript("OnLeave", GameTooltip_Hide)
    local boxStack = AddCfgEditBox(32, 3)
    boxStack:SetNumber(EasyAuctionDB.stackCount or 20)
    SetupAutoBlurForEditBox(boxStack, function(self)
        local v = tonumber(self:GetText()) or 1
        if v < 1 then v = 1 elseif v > 999 then v = 999 end
        EasyAuctionDB.stackCount = v
        self:SetNumber(v)
        UpdateStackPrice(AuctionBar.AuctionFrame)
    end)

    local labelDefaultNumStacks = AddCfgLabel("默认组数：", 4)
    labelDefaultNumStacks:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("闪卖默认组数", 1, 1, 1)
        GameTooltip:AddLine("闪卖页放入物品时默认填入的组数。若超过当前物品实际可上架组数，将自动按实际可上架组数填入。", 1, .82, 0, 1)
        GameTooltip:Show()
    end)
    labelDefaultNumStacks:SetScript("OnLeave", GameTooltip_Hide)

    local boxDefaultNumStacks = AddCfgEditBox(32, 4)
    boxDefaultNumStacks:SetNumber(EasyAuctionDB.defaultNumStacks or 1)
    SetupAutoBlurForEditBox(boxDefaultNumStacks, function(self)
        local v = tonumber(self:GetText()) or 1
        if v < 1 then v = 1 elseif v > 999 then v = 999 end
        EasyAuctionDB.defaultNumStacks = v
        self:SetNumber(v)
    end)
    boxDefaultNumStacks:SetScript("OnEnter", labelDefaultNumStacks:GetScript("OnEnter"))
    boxDefaultNumStacks:SetScript("OnLeave", GameTooltip_Hide)

    local labelDuration = AddCfgLabel("默认时长：", 5)
    labelDuration:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("默认时长", 1, 1, 1)
        GameTooltip:AddLine("每次上架拍卖的默认持续时间。\n可选12/24/48小时。", 1, .82, 0, 1)
        GameTooltip:Show()
    end)
    labelDuration:SetScript("OnLeave", GameTooltip_Hide)
    local durationBox = CreateFrame("Frame", nil, auctionContent, "UIDropDownMenuTemplate")
    durationBox:SetPoint("TOPLEFT", inputStartX - 30, GetCfgRowY(5) + 4)
    UIDropDownMenu_SetWidth(durationBox, 80)
    local durations = { { text = "12小时", value = 1 }, { text = "24小时", value = 2 }, { text = "48小时", value = 3 } }
    UIDropDownMenu_Initialize(durationBox, function(self, level)
        for _, v in ipairs(durations) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = v.text
            info.value = v.value
            info.func = function()
                EasyAuctionDB.auctionDuration = v.value
                UIDropDownMenu_SetSelectedValue(durationBox, v.value)
                if AuctionBar and AuctionBar.AuctionFrame and _G["EasyAuctionDurationDropdown"] then
                    UIDropDownMenu_SetSelectedValue(_G["EasyAuctionDurationDropdown"], v.value)
                end
                UpdateStackPrice(AuctionBar.AuctionFrame)
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    UIDropDownMenu_SetSelectedValue(durationBox, EasyAuctionDB.auctionDuration or 1)

    local labelUndercutMode = AddCfgLabel("压价方式：", 6)
    labelUndercutMode:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("压价方式", 1, 1, 1)
        GameTooltip:AddLine("只能选一种压价方式。", 1, .82, 0, 1)
        GameTooltip:AddLine("压总价：按总价整体压价\n压单价：每个单价都压价", .75, .75, .75, 1)
        GameTooltip:Show()
    end)
    labelUndercutMode:SetScript("OnLeave", GameTooltip_Hide)

    local cbUndercutTotal = CreateFrame("CheckButton", nil, auctionContent, "ChatConfigCheckButtonTemplate")
    cbUndercutTotal:SetPoint("TOPLEFT", inputStartX - 20, GetCfgRowY(6) + 4)
    cbUndercutTotal.Text:SetText("压总价")
    cbUndercutTotal.Text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
    EA_SkinText(cbUndercutTotal.Text, "text")
    cbUndercutTotal:SetChecked(EasyAuctionDB.undercutMode ~= "unit")
    cbUndercutTotal:SetHitRectInsets(0, -(cbUndercutTotal.Text:GetStringWidth() + 8), 0, 0)
    local cbUndercutUnit = CreateFrame("CheckButton", nil, auctionContent, "ChatConfigCheckButtonTemplate")
    cbUndercutUnit:SetPoint("LEFT", cbUndercutTotal, "RIGHT", 62, 0)
    cbUndercutUnit.Text:SetText("压单价")
    cbUndercutUnit.Text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
    EA_SkinText(cbUndercutUnit.Text, "text")
    cbUndercutUnit:SetChecked(EasyAuctionDB.undercutMode == "unit")
    cbUndercutUnit:SetHitRectInsets(0, -(cbUndercutUnit.Text:GetStringWidth() + 8), 0, 0)
    cbUndercutTotal:SetScript("OnClick", function(self)
        cbUndercutTotal:SetChecked(true)
        cbUndercutUnit:SetChecked(false)
        EasyAuctionDB.undercutMode = "total"
        UpdateStackPrice(AuctionBar.AuctionFrame)
    end)
    cbUndercutUnit:SetScript("OnClick", function(self)
        cbUndercutTotal:SetChecked(false)
        cbUndercutUnit:SetChecked(true)
        EasyAuctionDB.undercutMode = "unit"
        UpdateStackPrice(AuctionBar.AuctionFrame)
    end)

    local labelScanPerFrame = AddCfgLabel("扫描帧速：", 8)
    labelScanPerFrame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("全局扫描每帧条数", 1, 1, 1)
        GameTooltip:AddLine("全局扫描时每帧处理多少条拍卖数据。\n数值越大扫描越快，但可能导致卡顿。\n建议100~300之间。", 1, .82, 0, 1)
        GameTooltip:Show()
    end)
    labelScanPerFrame:SetScript("OnLeave", GameTooltip_Hide)

    local boxScanPerFrame = AddCfgEditBox(50, 8)
    boxScanPerFrame:SetNumber(EasyAuctionDB.scanPerFrame or 200)
    SetupAutoBlurForEditBox(boxScanPerFrame, function(self)
        local v = tonumber(self:GetText()) or 200
        if v < 50 then v = 50 elseif v >= 500 then v = 200 end
        EasyAuctionDB.scanPerFrame = v
        self:SetNumber(v)
    end)
    boxScanPerFrame:SetScript("OnEnter", labelScanPerFrame:GetScript("OnEnter"))
    boxScanPerFrame:SetScript("OnLeave", GameTooltip_Hide)

    local optionRowHeight = 20

    local function AddOptionPanel(parentPage, x, y, w, h)
        local panel = CreateFrame("Frame", nil, parentPage, "BackdropTemplate")
        panel:SetPoint("TOPLEFT", parentPage, "TOPLEFT", x, y)
        panel:SetSize(w, h)
        EA_SkinPanel(panel, "panel")
        EA_ApplyOutline(panel, 0.58)
        return panel
    end

    local function AddOptionSection(parentPage, x, y, w, text)
        local fs = parentPage:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", parentPage, "TOPLEFT", x + 8, y)
        fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
        fs:SetText(text)
        EA_SkinText(fs, "accent")
        local line = parentPage:CreateTexture(nil, "OVERLAY")
        line:SetTexture("Interface\\Buttons\\WHITE8X8")
        line:SetHeight(1)
        line:SetPoint("LEFT", fs, "RIGHT", 8, 0)
        line:SetPoint("RIGHT", parentPage, "TOPLEFT", x + w - 8, y)
        EA_SetLineColor(line, 0.45)
        return fs
    end

    local function AddOptionCheck(parentPage, x, y, rowWidth, textWidth, label, key, tooltip)
        local row = CreateFrame("Frame", nil, parentPage)
        row:SetSize(rowWidth, optionRowHeight)
        row:SetPoint("TOPLEFT", parentPage, "TOPLEFT", x, y)
        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
        row.label:SetWidth(textWidth)
        row.label:SetJustifyH("LEFT")
        row.label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
        row.label:SetText(label)
        EA_SkinText(row.label, "text")
        local cb = EA_CreateSwitch(row, 52)
        cb:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        cb.tooltip = tooltip
        cb:SetCheckedState(EasyAuctionDB[key] ~= false)
        cb:SetScript("OnClick", function(self)
            local checked = not self:GetCheckedState()
            self:SetCheckedState(checked)
            EasyAuctionDB[key] = checked
            if key == "enableUndercut" then
                UpdateStackPrice(AuctionBar.AuctionFrame)
            elseif key == "enableBrowseBuyButton" or key == "enableBrowseBidButton" then
                if type(EasyAuction_RefreshFlashBuyButtons) == "function" then
                    EasyAuction_RefreshFlashBuyButtons()
                end
            elseif key == "enableSearchBoxProtection" then
                if type(EasyAuction_UpdateSearchBoxProtection) == "function" then
                    EasyAuction_UpdateSearchBoxProtection()
                end
            end
        end)
        row:EnableMouse(true)
        row:SetScript("OnEnter", function(self)
            if tooltip then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(label, 1, 1, 1)
                GameTooltip:AddLine(tooltip, 0.85, 0.85, 0.85, true)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", GameTooltip_Hide)
        cb:SetScript("OnEnter", row:GetScript("OnEnter"))
        cb:SetScript("OnLeave", GameTooltip_Hide)
        return cb
    end

    AddOptionPanel(pageTips, 0, -18, 402, 132)
    AddOptionSection(pageTips, 0, -4, 402, "价格提示")
    AddOptionCheck(pageTips, 8, -26, 386, 306, "价格提示总开关", "ShowPrice",
        "EasyAuction鼠标提示总开关")
    AddOptionCheck(pageTips, 8, -47, 386, 306, "隐藏原生卖店价", "hideSellPrice",
        "是否显示系统卖价信息")
    AddOptionCheck(pageTips, 8, -68, 386, 306, "显示拍卖价格", "enablePrice",
        "是否显示卖店价及拍卖价格信息")
    AddOptionCheck(pageTips, 8, -89, 386, 306, "显示卖店价", "enableVendor", "是否显示卖店价价格")
    AddOptionCheck(pageTips, 8, -110, 386, 306, "显示历史最低", "ShowMinPrice",
        "是否显示物品历史最低价格")
    AddOptionCheck(pageTips, 8, -131, 386, 306, "单价优先", "showUnitPrice",
        "关闭后优先显示总价，按 Shift 显示单价；开启后优先显示单价。")

    AddOptionPanel(pageTips, 0, -166, 402, 90)
    AddOptionSection(pageTips, 0, -152, 402, "专业收益提示")
    AddOptionCheck(pageTips, 8, -174, 386, 306, "分解收益", "enableDisenchant", "是否显示物品分解价值")
    AddOptionCheck(pageTips, 8, -195, 386, 306, "分解概率", "enableDisenchantProb", "是否显示物品分解概率")
    AddOptionCheck(pageTips, 8, -216, 386, 306, "选矿收益", "enableProspect", "是否显示物品选矿价值")
    AddOptionCheck(pageTips, 8, -237, 386, 306, "研磨收益", "enableMill", "是否显示物品研磨价值")

    AddOptionPanel(pageAuction, 203, -148, 199, 174)
    AddOptionSection(pageAuction, 203, -134, 199, "拍卖行设置")
    AddOptionCheck(pageAuction, 209, -156, 187, 123, "启用自动压价", "enableUndercut",
        "开启后，总价/起拍价会自动减去配置的压价金额")
    AddOptionCheck(pageAuction, 209, -179, 187, 123, "连续上架同价", "autoFillLastAuction",
        "连续上架相同物品时自动填充上一次拍卖价格。")
    AddOptionCheck(pageAuction, 209, -202, 187, 123, "在售列表左键复制", "enableAuctionListCopy",
        "开启后，可在在售列表中左键点击物品名称进行复制")
    AddOptionCheck(pageAuction, 209, -225, 187, 123, "浏览买按钮", "enableBrowseBuyButton",
        "关闭后，拍卖行浏览列表不显示 EasyAuction 的“买”按钮")
    AddOptionCheck(pageAuction, 209, -248, 187, 123, "浏览竞按钮", "enableBrowseBidButton",
        "关闭后，拍卖行浏览列表不显示 EasyAuction 的“竞”按钮")
    AddOptionCheck(pageAuction, 209, -271, 187, 123, "搜索框防污染", "enableSearchBoxProtection",
        "关闭后，不再启用拍卖行搜索框防污染/防限流拦截提示")

    local buyRiskRow = CreateFrame("Frame", nil, pageAuction)
    buyRiskRow:SetSize(187, optionRowHeight)
    buyRiskRow:SetPoint("TOPLEFT", pageAuction, "TOPLEFT", 209, -294)
    local buyRiskLabel = buyRiskRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    buyRiskLabel:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
    buyRiskLabel:SetPoint("LEFT", buyRiskRow, "LEFT", 0, 0)
    buyRiskLabel:SetJustifyH("LEFT")
    buyRiskLabel:SetWidth(120)
    buyRiskLabel:SetText("单次购买风控")
    EA_SkinText(buyRiskLabel, "text")

    local buyRiskEdit = CreateNumericBox(buyRiskRow, 46)
    buyRiskEdit:SetPoint("LEFT", buyRiskLabel, "RIGHT", 4, 0)
    buyRiskEdit:SetJustifyH("CENTER")
    buyRiskEdit:SetNumber(EasyAuctionDB.buyRiskLimit or 0)

    local buyRiskGoldIcon = buyRiskRow:CreateTexture(nil, "ARTWORK")
    buyRiskGoldIcon:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
    buyRiskGoldIcon:SetSize(12, 12)
    buyRiskGoldIcon:SetPoint("LEFT", buyRiskEdit, "RIGHT", 2, 0)

    buyRiskEdit:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("单次购买风控", 1, 1, 1)
        GameTooltip:AddLine("单次购买超过此金额（单位：金）时将弹窗提示。0为不限制。", 1, .82, 0, 1)
        GameTooltip:Show()
    end)
    buyRiskEdit:SetScript("OnLeave", GameTooltip_Hide)
    buyRiskRow:EnableMouse(true)
    buyRiskRow:SetScript("OnEnter", buyRiskEdit:GetScript("OnEnter"))
    buyRiskRow:SetScript("OnLeave", GameTooltip_Hide)

    SetupAutoBlurForEditBox(buyRiskEdit, function(self)
        local v = tonumber(self:GetText()) or EasyAuctionDB.buyRiskLimit or 500
        if v < 0 then v = 0 end
        EasyAuctionDB.buyRiskLimit = v
        self:SetNumber(v)
    end)

    local scalePanel = CreateFrame("Frame", nil, interfaceFooter)
    scalePanel:SetSize(276, 44)
    scalePanel:SetPoint("LEFT", interfaceFooter, "LEFT", 8, 0)

    local scaleLabel = scalePanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    scaleLabel:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
    scaleLabel:SetPoint("TOPLEFT", scalePanel, "TOPLEFT", 0, -1)
    scaleLabel:SetText("界面缩放")
    EA_SkinText(scaleLabel, "text")

    local scaleValue = scalePanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    scaleValue:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
    scaleValue:SetPoint("TOPRIGHT", scalePanel, "TOPRIGHT", 0, -2)
    scaleValue:SetJustifyH("RIGHT")
    EA_SkinText(scaleValue, "accent")

    local scaleRange = scalePanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    scaleRange:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "")
    scaleRange:SetPoint("TOP", scalePanel, "TOP", 0, -2)
    scaleRange:SetText("50% - 120%")
    EA_SkinText(scaleRange, "muted")

    local scaleMinusBtn = CreateFrame("Button", nil, scalePanel, "UIPanelButtonTemplate")
    scaleMinusBtn:SetSize(22, 20)
    scaleMinusBtn:SetText("-")
    scaleMinusBtn:SetPoint("TOPLEFT", scalePanel, "TOPLEFT", 0, -20)
    EA_SkinButton(scaleMinusBtn)

    local scaleResetBtn = CreateFrame("Button", nil, scalePanel, "UIPanelButtonTemplate")
    scaleResetBtn:SetSize(42, 20)
    scaleResetBtn:SetText("重置")
    scaleResetBtn:SetPoint("TOPRIGHT", scalePanel, "TOPRIGHT", 0, -20)
    EA_SkinButton(scaleResetBtn)

    local scalePlusBtn = CreateFrame("Button", nil, scalePanel, "UIPanelButtonTemplate")
    scalePlusBtn:SetSize(22, 20)
    scalePlusBtn:SetText("+")
    scalePlusBtn:SetPoint("RIGHT", scaleResetBtn, "LEFT", -4, 0)
    EA_SkinButton(scalePlusBtn)

    local scaleSlider = CreateFrame("Slider", nil, scalePanel, "OptionsSliderTemplate")
    scaleSlider:SetPoint("TOPLEFT", scaleMinusBtn, "TOPRIGHT", 6, 0)
    scaleSlider:SetPoint("TOPRIGHT", scalePlusBtn, "TOPLEFT", -6, 0)
    scaleSlider:SetMinMaxValues(0.5, 1.2)
    scaleSlider:SetValueStep(0.01)
    if scaleSlider.SetObeyStepOnDrag then
        scaleSlider:SetObeyStepOnDrag(true)
    end
    scaleSlider:SetHitRectInsets(0, 0, 0, 0)
    if scaleSlider.Low then
        scaleSlider.Low:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "")
        scaleSlider.Low:SetText("")
        EA_SkinText(scaleSlider.Low, "muted")
    end
    if scaleSlider.High then
        scaleSlider.High:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "")
        scaleSlider.High:SetText("")
        EA_SkinText(scaleSlider.High, "muted")
    end
    if scaleSlider.Text then
        scaleSlider.Text:SetText("")
    end

    local function ApplyScaleValue(value, applyNow)
        value = tonumber(value) or EA_DEFAULT_UI_SCALE
        if value < 0.5 then value = 0.5 elseif value > 1.2 then value = 1.2 end
        value = math.floor(value * 100 + 0.5) / 100
        scaleValue:SetText(string.format("%d%%", math.floor(value * 100 + 0.5)))
        if applyNow then
            EasyAuctionDB.uiScale = value
            if math.abs((scaleSlider:GetValue() or 1) - value) > 0.001 then
                scaleSlider:SetValue(value)
            end
            ApplyEasyAuctionUIScale()
        end
    end

    scaleMinusBtn:SetScript("OnClick", function()
        ApplyScaleValue((EasyAuctionDB.uiScale or EA_DEFAULT_UI_SCALE) - 0.01, true)
    end)
    scalePlusBtn:SetScript("OnClick", function()
        ApplyScaleValue((EasyAuctionDB.uiScale or EA_DEFAULT_UI_SCALE) + 0.01, true)
    end)
    scaleResetBtn:SetScript("OnClick", function()
        ApplyScaleValue(EA_DEFAULT_UI_SCALE, true)
    end)

    scaleSlider:SetValue(EasyAuctionDB.uiScale or EA_DEFAULT_UI_SCALE)
    ApplyScaleValue(EasyAuctionDB.uiScale or EA_DEFAULT_UI_SCALE, true)
    scaleSlider:SetScript("OnValueChanged", function(_, value)
        ApplyScaleValue(value, false)
    end)
    scaleSlider:SetScript("OnMouseUp", function()
        ApplyScaleValue(scaleSlider:GetValue(), true)
    end)
    scaleSlider:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("界面缩放", 1, 1, 1)
        GameTooltip:AddLine("拖动滑杆或使用 +/- 微调主界面、设置、价格库等窗口缩放，重置为 100%。", 1, .82, 0, 1)
        GameTooltip:Show()
    end)
    scaleSlider:SetScript("OnLeave", GameTooltip_Hide)
    if EAStyle then
        EAStyle:OnTheme(function(p)
            if scaleSlider:GetThumbTexture() then
                scaleSlider:GetThumbTexture():SetVertexColor(p.accent[1], p.accent[2], p.accent[3], 1)
            end
        end)
    end
    local resetBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    resetBtn:SetSize(80, 24)
    resetBtn:SetText("重置插件")
    resetBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 14)
    EA_SkinButton(resetBtn)

    resetBtn:SetScript("OnClick", function()
            StaticPopupDialogs["EASYAUCTION_RESET_DB"] = {
            text = "|cffff4040警告|r\n\n确定要清空所有拍卖历史记录和设置吗？\n此操作不可恢复。",
            button1 = "确定",
            button2 = "取消",
            OnAccept = function()
                if type(EasyAuction_ResetSavedVariables) == "function" then
                    local newDB, resetError = EasyAuction_ResetSavedVariables(true)
                    if not newDB then
                        print("|cffff4040EasyAuction|r：" .. tostring(resetError and resetError.message
                            or "当前无法重置插件。"))
                        return
                    end
                    EasyAuctionDB = newDB
                else
                    EasyAuctionDB = {
                        bidDiscount = 0.99,
                        undercut = 1,
                        stackCount = 20,
                        defaultNumStacks = 1,
                        auctionDuration = 1,
                        showSections = { items = true, price = true, myauct = true },
                        buyRiskLimit = 500,
                        enableBrowseBuyButton = true,
                        enableBrowseBidButton = true,
                        enableSearchBoxProtection = true,
                        scanPerFrame = 200,
                        scanKeepPerItem = 120,
                        historyKeepDays = 30,
                        historyMaxEntry = 0,
                        dailyKeepDays = 30,
                        hourlyKeepHours = 24,
                        uiScale = EA_DEFAULT_UI_SCALE,
                        layoutMigrationVersion = EA_LAYOUT_MIGRATION_VERSION,
                        uiPalette = "blizzard",
                        playerGoldDay = date("%Y-%m-%d"),
                        playerGoldToday = type(GetMoney) == "function" and GetMoney() or 0,
                        playerGoldYesterday = type(GetMoney) == "function" and GetMoney() or 0,
                        PriceHistory = {},
                        DailyMinPrice = {},
                        HourlyMinPrice = {},
                        CurrentTodayMin = {},
                        FavoriteItems = {},
                        RecentSearch = {},
                        CategoryOverrides = {},
                        scanQuickLimit = 100,
                        MinimalModeActive = false,
                    }
                    _G.EasyAuctionDB = EasyAuctionDB
                    _G.EasyAuctionDB2 = _G.EasyAuctionDB2 or {}
                end
                print("|cff00ff00EasyAuction|r：所有设置与历史数据已重置，正在重载界面。")
                if type(ReloadUI) == "function" then ReloadUI() end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopup_Show("EASYAUCTION_RESET_DB")
    end)

    local changelogBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    changelogBtn:SetSize(80, 24)
    changelogBtn:SetPoint("LEFT", resetBtn, "RIGHT", 8, 0)
    changelogBtn:SetText("更新日志")
    EA_SkinButton(changelogBtn)
    changelogBtn:SetScript("OnClick", function()
        ShowUpdateNotesPopup()
    end)

    local themePanel = CreateFrame("Frame", nil, interfaceFooter)
    themePanel:SetSize(96, 44)
    themePanel:SetPoint("RIGHT", interfaceFooter, "RIGHT", -8, 0)

    local themeLabel = themePanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    themeLabel:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
    themeLabel:SetPoint("TOPLEFT", themePanel, "TOPLEFT", 0, -1)
    themeLabel:SetText("界面主题")
    EA_SkinText(themeLabel, "text")

    local themeBtn = CreateFrame("Button", nil, themePanel, "UIPanelButtonTemplate")
    themeBtn:SetSize(96, 24)
    themeBtn:SetPoint("BOTTOM", themePanel, "BOTTOM", 0, 0)
    EA_SkinButton(themeBtn)
    EA_SetThemeDropdownButton(themeBtn, false)
    frame:SetScript("OnShow", function()
        EA_RaiseUtilityFrame(frame, frameParent)
        ShowConfigTab(tabState.active or "tips")
    end)
    ShowConfigTab("tips")
end

local function PickupAndPutToAuction(bag, slot)
    C_Container.PickupContainerItem(bag, slot)
    C_Timer.After(0.01, function()
        ClickAuctionSellItemButton()
        C_Timer.After(0.01, function()
            ClearCursor()
            local f = AuctionBar and AuctionBar.AuctionFrame
            local ItemButton = _G["EasyAuctionItemButton"]
            if f and ItemButton and ItemButton.itemID then
                local name, _, _, _, _, _, _, _, _, itemID = GetAuctionSellItemInfo()
                if name and itemID then
                    RefreshMinPriceLines(name, itemID)
                end
            end
        end)
    end)
end

function UpdateDepositMoney()
    local HookAuctionFrame = AuctionBar.AuctionFrame
    if not HookAuctionFrame then return end

    local StackSize = HookAuctionFrame.StackCount:GetNumber()
    local NumStacks = HookAuctionFrame.NumStacks:GetNumber()
    local duration = GetSelectedDuration()
    local perDepositMoney = GetAuctionDeposit(1, 1, 1, StackSize, 1)
    local TolDepositMoney
    if duration == 3 then
        TolDepositMoney = perDepositMoney * 4 * NumStacks
    else
        TolDepositMoney = perDepositMoney * duration * NumStacks
    end
    if HookAuctionFrame and HookAuctionFrame.totalDepositMoneyLabel then
        HookAuctionFrame.totalDepositMoneyLabel:SetText(format("|cffffff00总保管费：|r|cffffffff%s|r",
            GetMoneyString(TolDepositMoney or 0)))
    end
    if HookAuctionFrame and HookAuctionFrame.totalProfitLabel then
        local stackGold = HookAuctionFrame.StackGold:GetNumber()
        local stackSilver = HookAuctionFrame.StackSilver:GetNumber()
        local stackCopper = HookAuctionFrame.StackCopper:GetNumber()
        local perBuyout = stackGold * 10000 + stackSilver * 100 + stackCopper
        local totalBuyout = perBuyout * NumStacks
        local totalProfit = math.floor(totalBuyout * 0.99 + 0.5) - TolDepositMoney
        HookAuctionFrame.totalProfitLabel:SetText(format("|cff00ff00预计利润：|r|cffffffff%s|r",
            GetMoneyString(totalProfit or 0)))
    end
end

local AuctionBrowseResults = {}

local function CollectAuctionBrowseResults()
    if IsScanningAll or IsScanningCategory then return end
    AuctionBrowseResults = {}
    local num = GetNumAuctionItems("list")
    for i = 1, num do
        local name, texture, count, quality, _, _, _, minBid, minIncrement, buyoutPrice,
            bidAmount, highBidder, _, owner, _, saleStatus, itemID = GetAuctionItemInfo("list", i)
        if name and itemID and count then
            table.insert(AuctionBrowseResults, {
                index = i,
                name = name,
                texture = texture,
                count = count,
                quality = quality,
                minBid = minBid,
                minIncrement = minIncrement,
                buyout = buyoutPrice,
                bid = bidAmount,
                owner = owner,
                highBidder = highBidder,
                saleStatus = saleStatus,
                itemID = itemID,
            })
        end
    end
end

local function FormatBidStatus(highBidder, saleStatus)
    if highBidder == true or saleStatus == 1 then
        return "|cff00ff00领先|r"
    end
    return "|cffff0000被超过|r"
end

local function FormatTimeLeft(timeLeft)
    if timeLeft == 1 then
        return "|cffff8800<30分钟|r"
    elseif timeLeft == 2 then
        return "|cff00ff002小时|r"
    elseif timeLeft == 3 then
        return "|cff00bfff12小时|r"
    elseif timeLeft == 4 then
        return "|cffffff0048小时|r"
    end
    return "--"
end

function RefreshMyBidListFrame()
    if not MyBidListFrame then return end
    local num = GetNumAuctionItems("bidder")
    local data = {}
    local sumBid = 0
    local sumBuyout = 0

    for idx = 1, num do
        local name, texture, count, quality, _, _, _, minBid, minIncrement, buyout, bid,
            highBidder, _, owner, _, saleStatus, itemID = GetAuctionItemInfo("bidder", idx)
        local timeLeft = GetAuctionItemTimeLeft("bidder", idx)
        table.insert(data, {
            idx = idx,
            name = name,
            texture = texture,
            count = count,
            quality = quality,
            minBid = minBid,
            minIncrement = minIncrement,
            buyout = buyout,
            bid = bid,
            highBidder = highBidder,
            owner = owner,
            saleStatus = saleStatus,
            itemID = itemID,
            timeLeft = timeLeft,
        })
        sumBid = sumBid + (bid or 0)
        sumBuyout = sumBuyout + (buyout or 0)
    end

    table.sort(data, function(a, b)
        local aOver = not (a.highBidder == true or a.saleStatus == 1)
        local bOver = not (b.highBidder == true or b.saleStatus == 1)
        if aOver ~= bOver then return aOver end
        return (a.timeLeft or 99) < (b.timeLeft or 99)
    end)

    local maxRows = #MyBidListFrame.rows
    local scroll = MyBidListFrame.scroll
    local offset = FauxScrollFrame_GetOffset(scroll)
    FauxScrollFrame_Update(scroll, #data, maxRows, 20)

    for i = 1, maxRows do
        local row = MyBidListFrame.rows[i]
        local entry = data[offset + i]
        if entry then
            row.icon:SetTexture(entry.texture)
            row.nameText:SetText(entry.name or "?")
            local color = ITEM_QUALITY_COLORS[entry.quality or 1] or ITEM_QUALITY_COLORS[1]
            row.nameText:SetTextColor(color.r, color.g, color.b)
            row.countText:SetText(entry.count or "")
            row.bidText:SetText(GetCoinTextureString(entry.bid or 0))
            row.buyoutText:SetText(GetCoinTextureString(entry.buyout or 0))
            row.statusText:SetText(FormatBidStatus(entry.highBidder, entry.saleStatus))
            row.statusText:SetTextColor((entry.highBidder == true or entry.saleStatus == 1) and 0 or 1,
                (entry.highBidder == true or entry.saleStatus == 1) and 1 or 0, 0)
            row.timeText:SetText(FormatTimeLeft(entry.timeLeft))
            row:Show()
            row.rebidBtn:Hide()
            if not (entry.highBidder == true or entry.saleStatus == 1) then
                row.rebidBtn:Show()
                row.rebidBtn:SetScript("OnClick", function()
                    local _, _, _, _, _, _, _, minBid2, minInc2, _, currBid =
                        GetAuctionItemInfo("bidder", entry.idx)
                    local nextBid = (currBid and currBid > 0) and (currBid + (minInc2 or 0)) or minBid2
                    if nextBid and nextBid > 0 then
                        PlaceAuctionBid("bidder", entry.idx, nextBid)
                        print("|cff00ff00[EasyAuction]|r 已继续竞价：" .. (entry.name or "?"))
                    end
                end)
            end
            row:SetScript("OnEnter", function()
                GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
                if entry.itemID then
                    GameTooltip:SetItemByID(entry.itemID)
                else
                    GameTooltip:AddLine(entry.name or "?")
                end
                GameTooltip:Show()
                row.bg:SetColorTexture(0.3, 0.6, 1, 0.18)
            end)
            row:SetScript("OnLeave", function()
                GameTooltip:Hide()
                row.bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.05 or 0.10)
            end)
        else
            row:Hide()
        end
    end

    if MyBidListFrame.statFrame then
        MyBidListFrame.statFrame.bidSum:SetText(GetCoinTextureString(sumBid))
        MyBidListFrame.statFrame.buyoutSum:SetText(GetCoinTextureString(sumBuyout))
        local profit = sumBuyout - sumBid
        local col = profit < 0 and "|cffff4444" or "|cff00ff00"
        MyBidListFrame.statFrame.profit:SetText(col .. GetCoinTextureString(profit) .. "|r")
    end
end

function ShowMyBidListFrame()
    if MyBidListFrame and MyBidListFrame:IsShown() then
        MyBidListFrame:Hide()
        return
    end
    if not MyBidListFrame then
        local frame = CreateFrame("Frame", "MyBidListFrame", UIParent, "BackdropTemplate")
        frame:SetSize(920, 320)
        EA_DockRightOfMain(frame, nil, 6)
        frame:SetFrameStrata("FULLSCREEN_DIALOG")
        frame:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 18,
            insets = { left = 6, right = 6, top = 6, bottom = 6 }
        })
        frame:SetBackdropColor(0.10, 0.10, 0.13, 0.97)
        frame:SetBackdropBorderColor(0.7, 0.6, 1, 1)
        EA_SkinFrame(frame, "window")
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

        frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        frame.title:SetPoint("TOP", 0, -14)
        frame.title:SetText("竞价列表")
        EA_SkinText(frame.title, "accent")

        local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
        EA_SkinCloseButton(closeBtn)
        closeBtn:SetScript("OnClick", function() frame:Hide() end)

        local tableFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        tableFrame:SetPoint("TOPLEFT", 12, -42)
        tableFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -220, 12)
        EA_SkinPanel(tableFrame, "panel")
        EA_ApplyOutline(tableFrame, 0.9)
        frame.tableFrame = tableFrame

        local scroll = CreateFrame("ScrollFrame", nil, tableFrame, "FauxScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", tableFrame, "TOPLEFT", 0, -22)
        scroll:SetPoint("BOTTOMRIGHT", tableFrame, "BOTTOMRIGHT", -20, 0)
        frame.scroll = scroll

        local header = CreateFrame("Frame", nil, tableFrame)
        local colW = { 28, 180, 46, 126, 126, 72, 72, 76 }
        header:SetSize(726, 22)
        header:SetPoint("TOPLEFT", tableFrame, "TOPLEFT", 0, 0)
        local labels = { " ", "物品名", "数量", "我的出价", "一口价", "状态", "剩余", "操作" }
        EA_ApplyRowLines(header, colW, 22)
        local x = 0
        for i, labelText in ipairs(labels) do
            local fs = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            fs:SetPoint("LEFT", header, "LEFT", x, 0)
            fs:SetWidth(colW[i])
            fs:SetText(labelText)
            EA_SkinText(fs, "muted")
            x = x + colW[i]
        end

        local ROWS = 10
        frame.rows = {}
        for i = 1, ROWS do
            local row = CreateFrame("Button", nil, tableFrame)
            row:SetSize(726, 20)
            row:SetPoint("TOPLEFT", tableFrame, "TOPLEFT", 0, -22 - (i - 1) * 21)
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
            EA_RowColor(row.bg, i)
            row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            EA_ApplyRowLines(row, colW, 20)

            local xx = 0
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(20, 20)
            row.icon:SetPoint("LEFT", row, "LEFT", xx, 0)
            xx = xx + colW[1]

            row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.nameText:SetPoint("LEFT", row, "LEFT", xx, 0)
            row.nameText:SetWidth(colW[2])
            row.nameText:SetWordWrap(false)
            row.nameText:SetJustifyH("LEFT")
            row.nameText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
            xx = xx + colW[2]

            row.countText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.countText:SetPoint("LEFT", row, "LEFT", xx, 0)
            row.countText:SetWidth(colW[3])
            xx = xx + colW[3]

            row.bidText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.bidText:SetPoint("LEFT", row, "LEFT", xx, 0)
            row.bidText:SetWidth(colW[4])
            row.bidText:SetJustifyH("RIGHT")
            row.bidText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
            xx = xx + colW[4]

            row.buyoutText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.buyoutText:SetPoint("LEFT", row, "LEFT", xx, 0)
            row.buyoutText:SetWidth(colW[5])
            row.buyoutText:SetJustifyH("RIGHT")
            row.buyoutText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
            xx = xx + colW[5]

            row.statusText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.statusText:SetPoint("LEFT", row, "LEFT", xx, 0)
            row.statusText:SetWidth(colW[6])
            xx = xx + colW[6]

            row.timeText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.timeText:SetPoint("LEFT", row, "LEFT", xx, 0)
            row.timeText:SetWidth(colW[7])
            xx = xx + colW[7]

            row.rebidBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            row.rebidBtn:SetSize(60, 18)
            row.rebidBtn:SetPoint("LEFT", row, "LEFT", xx + 2, 0)
            row.rebidBtn:SetText("继续竞价")
            EA_SkinButton(row.rebidBtn)
            row.rebidBtn:Hide()
            frame.rows[i] = row
        end

        local statFrame = CreateFrame("Frame", nil, frame)
        statFrame:SetSize(180, 120)
        statFrame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -45)
        statFrame.bg = statFrame:CreateTexture(nil, "BACKGROUND")
        statFrame.bg:SetAllPoints()
        if EAStyle then
            local p = EAStyle:Palette()
            statFrame.bg:SetColorTexture(p.panel[1], p.panel[2], p.panel[3], 0.76)
        else
            statFrame.bg:SetColorTexture(0.2, 0.2, 0.3, 0.13)
        end
        EA_ApplyOutline(statFrame, 0.65)
        statFrame.title = statFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        statFrame.title:SetPoint("TOPLEFT", 10, -8)
        statFrame.title:SetText("|cffbbaaee统计信息|r")
        EA_SkinText(statFrame.title, "accent")
        statFrame.bidSumLabel = statFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        statFrame.bidSumLabel:SetPoint("TOPLEFT", statFrame.title, "BOTTOMLEFT", 0, -10)
        statFrame.bidSumLabel:SetText("总出价：")
        statFrame.bidSum = statFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        statFrame.bidSum:SetPoint("LEFT", statFrame.bidSumLabel, "RIGHT", 2, 0)
        statFrame.buyoutSumLabel = statFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        statFrame.buyoutSumLabel:SetPoint("TOPLEFT", statFrame.bidSumLabel, "BOTTOMLEFT", 0, -6)
        statFrame.buyoutSumLabel:SetText("总货值：")
        statFrame.buyoutSum = statFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        statFrame.buyoutSum:SetPoint("LEFT", statFrame.buyoutSumLabel, "RIGHT", 2, 0)
        statFrame.profitLabel = statFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        statFrame.profitLabel:SetPoint("TOPLEFT", statFrame.buyoutSumLabel, "BOTTOMLEFT", 0, -6)
        statFrame.profitLabel:SetText("竞价利润：")
        statFrame.profit = statFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        statFrame.profit:SetPoint("LEFT", statFrame.profitLabel, "RIGHT", 2, 0)
        frame.statFrame = statFrame

        frame:SetScript("OnShow", RefreshMyBidListFrame)
        frame.scroll:SetScript("OnVerticalScroll", function(self, offset)
            FauxScrollFrame_OnVerticalScroll(self, offset, 20, RefreshMyBidListFrame)
        end)
        MyBidListFrame = frame
    end
    EA_DockRightOfMain(MyBidListFrame, nil, 6)
    MyBidListFrame:Show()
    RefreshMyBidListFrame()
end

function CreateAuctionSide()
    EasyAuctionDB = EasyAuctionDB or {}
    EA_NormalizeLayoutDB(EasyAuctionDB, false)
    if type(EasyAuctionDB.bidDiscount) ~= "number" or EasyAuctionDB.bidDiscount <= 0 or EasyAuctionDB.bidDiscount > 1 then
        EasyAuctionDB.bidDiscount = 0.99
    end
    if type(EasyAuctionDB.undercut) ~= "number" then
        EasyAuctionDB.undercut = 1
    end
    if type(EasyAuctionDB.stackCount) ~= "number" or EasyAuctionDB.stackCount <= 0 then
        EasyAuctionDB.stackCount = 20
    end
    EasyAuctionDB.defaultNumStacks = NormalizePositiveInt(EasyAuctionDB.defaultNumStacks, 1)
    if type(EasyAuctionDB.auctionDuration) ~= "number" then
        EasyAuctionDB.auctionDuration = 1
    end
    if AuctionBar.AuctionFrame then return end

    local totalWidth, totalHeight = 360, 560
    local baseWidth, baseHeight = totalWidth, totalHeight
    local sideListGap = 8
    local defaultSideListHeight = math.floor((baseHeight - sideListGap) / 2)
    local midX = 340
    local midY = 200

    local f = CreateBaseFrame("AuctionHelper", AuctionFrame, totalWidth, totalHeight)
    f:SetPoint("TOPLEFT", AuctionFrame, "TOPRIGHT", 0, -10)
    f.__EARefreshHeader = nil

    local shellHeader = EAStyle and EAStyle:Surface(f, "panel") or CreateFrame("Frame", nil, f)
    shellHeader:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -3)
    shellHeader:SetPoint("TOPRIGHT", f, "TOPRIGHT", -3, -3)
    shellHeader:SetHeight(64)
    f.EAHeader = shellHeader

    local brandIcon = shellHeader:CreateTexture(nil, "ARTWORK")
    brandIcon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
    brandIcon:SetSize(36, 36)
    brandIcon:SetPoint("TOPLEFT", 12, -10)

    local brandTitle = EAStyle and EAStyle:Text(shellHeader, "OVERLAY", EAStyle.Font, 20, "", "accent")
        or shellHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    brandTitle:SetPoint("TOPLEFT", brandIcon, "TOPRIGHT", 10, 4)
    brandTitle:SetText("EasyAuction")

    local brandSub = EAStyle and EAStyle:Text(shellHeader, "OVERLAY", EAStyle.Font, 13, "", "muted")
        or shellHeader:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    brandSub:SetPoint("TOPLEFT", brandTitle, "BOTTOMLEFT", 0, -1)
    brandSub:SetText("V" .. version .. "  ·  拍卖工作台")
    f.EAHeaderSubtitle = brandSub

    local headlineBtn = CreateFrame("Button", nil, shellHeader)
    headlineBtn:SetPoint("TOPRIGHT", shellHeader, "TOPRIGHT", -12, -12)
    headlineBtn:SetSize(200, 24)
    headlineBtn:SetScript("OnClick", function()
        EasyAuction_SaveGoldRecord()
        EasyAuction_ShowGoldBillFrame()
    end)
    headlineBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
        GameTooltip:SetText("点击查看金币账单")
        GameTooltip:Show()
    end)
    headlineBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local headline = EAStyle and EAStyle:Text(headlineBtn, "OVERLAY", EAStyle.FontNumber, 20, "", "text")
        or headlineBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    headline:SetPoint("TOPRIGHT", headlineBtn, "TOPRIGHT", 0, 0)
    headline:SetJustifyH("RIGHT")
    headline:SetText("0")
    f.EAHeaderHeadline = headline

    local hint = EAStyle and EAStyle:Text(shellHeader, "OVERLAY", EAStyle.Font, 11, "", "muted")
        or shellHeader:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPRIGHT", headlineBtn, "BOTTOMRIGHT", 0, -2)
    hint:SetJustifyH("RIGHT")
    hint:SetText("较昨日：今日基准")
    f.EAHeaderHint = hint

    local tabStrip = CreateFrame("Frame", nil, f)
    tabStrip:SetPoint("TOPLEFT", shellHeader, "BOTTOMLEFT", 8, -6)
    tabStrip:SetPoint("TOPRIGHT", shellHeader, "BOTTOMRIGHT", -8, -6)
    tabStrip:SetHeight(22)
    f.EATabStrip = tabStrip

    local contentFrame = EAStyle and EAStyle:Surface(f, "panel") or CreateFrame("Frame", nil, f)
    contentFrame:SetPoint("TOPLEFT", tabStrip, "BOTTOMLEFT", -8, -6)
    contentFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, 40)
    f.EAContent = contentFrame

    local footer = CreateFrame("Frame", nil, f)
    footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 6, 9)
    footer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 9)
    footer:SetHeight(24)
    f.EAFooter = footer
    local tab1 = CreateFrame("Button", f:GetName() .. "Tab1", f, nil)
    tab1:SetSize(60, 24)
    tab1:SetID(1)
    tab1:SetPoint("LEFT", tabStrip, "LEFT", 0, 0)
    tab1.icon = tab1:CreateTexture(nil, "ARTWORK")
    tab1.icon:SetTexture("Interface\\Icons\\inv_misc_bag_10_green")
    tab1.icon:SetSize(18, 18)
    tab1.icon:SetPoint("LEFT", tab1, "LEFT", 4, 0)
    tab1.text = tab1:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    tab1.text:SetPoint("LEFT", tab1.icon, "RIGHT", 2, 0)
    tab1.text:SetText("闪购")
    tab1.text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 14, "")


    local tab2 = CreateFrame("Button", f:GetName() .. "Tab2", f, nil)
    tab2:SetSize(60, 24)
    tab2:SetID(2)
    tab2:SetPoint("LEFT", tab1, "RIGHT", 6, 0)
    tab2.icon = tab2:CreateTexture(nil, "ARTWORK")
    tab2.icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
    tab2.icon:SetSize(18, 18)
    tab2.icon:SetPoint("LEFT", tab2, "LEFT", 4, 0)
    tab2.text = tab2:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    tab2.text:SetPoint("LEFT", tab2.icon, "RIGHT", 2, 0)
    tab2.text:SetText("闪卖")
    tab2.text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 14, "")



    local tab3 = CreateFrame("Button", f:GetName() .. "Tab3", f, nil)
    tab3:SetSize(60, 24)
    tab3:SetID(3)
    tab3:SetPoint("LEFT", tab2, "RIGHT", 6, 0)
    tab3.icon = tab3:CreateTexture(nil, "ARTWORK")
    tab3.icon:SetTexture("Interface\\Icons\\racial_troll_berserk")
    tab3.icon:SetSize(18, 18)
    tab3.icon:SetPoint("LEFT", tab3, "LEFT", 4, 0)
    tab3.text = tab3:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    tab3.text:SetPoint("LEFT", tab3.icon, "RIGHT", 2, 0)
    tab3.text:SetText("狙击")
    tab3.text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 14, "")

    local tab4 = CreateFrame("Button", f:GetName() .. "Tab4", f, nil)
    _G.EasyAuctionMainHelpButton = tab4
    tab4:SetSize(120, 24)
    tab4:SetID(4)
    tab4:SetText("|cff00ffffEasyAuction|r")
    tab4:SetPoint("RIGHT", tabStrip, "RIGHT", 0, 0)
    tab4:SetScript("OnClick", function()
        if EasyAuction_HelpFrame and EasyAuction_HelpFrame:IsShown() then
            EasyAuction_HelpFrame:Hide()
            return
        end
        if not EasyAuction_HelpFrame then
            local guide = CreateFrame("Frame", "EasyAuction_HelpFrame", UIParent, "BackdropTemplate")
            guide:SetSize(260, 226)
            if EAStyle then
                EAStyle:Skin(guide, "panel")
                guide.title = EAStyle:Text(guide, "OVERLAY", EAStyle.Font, 14, "", "accent")
                guide.title:SetPoint("TOPLEFT", 12, -10)
                guide.title:SetText("EasyAuction 指向提示")
                guide.close = EAStyle:CloseButton(guide)
                guide.close:SetPoint("TOPRIGHT", -6, -6)
                guide.close:SetScript("OnClick", function() guide:Hide() end)
                guide.body = CreateFrame("Frame", nil, guide)
                guide.body:SetPoint("TOPLEFT", 12, -38)
                guide.body:SetPoint("BOTTOMRIGHT", -12, 12)
            else
                EA_SkinFrame(guide, "window")
            end
            guide:SetFrameStrata("DIALOG")
            guide:SetToplevel(true)
            guide:EnableMouse(true)
            guide:SetMovable(true)
            guide:RegisterForDrag("LeftButton")
            guide:SetScript("OnDragStart", guide.StartMoving)
            guide:SetScript("OnDragStop", guide.StopMovingOrSizing)
            guide.steps = {}
            guide.lines = {}

            local highlight = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
            highlight:SetFrameStrata("DIALOG")
            highlight:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
            highlight:SetBackdropBorderColor(0, 0.9, 1, 1)
            highlight:Hide()
            guide.highlight = highlight

            local body = guide.body or guide
            local stepData = {
                { key = "buy", label = "闪购", getTarget = function() return tab1 end, text = "在这里查看最近搜索和常用物品，左键复制名称，右键加入狙击或常用清单。" },
                { key = "sell", label = "闪卖", getTarget = function() return tab2 end, text = "切到闪卖后拖入物品或从库存选择，系统会按价格库填入单价、组数和保管费。" },
                { key = "scan", label = "扫描", getTarget = function() return f.EAScanBtn end, text = "扫描按钮会在主框右侧打开方式选择，可执行全量扫描或按分类扫描。" },
                { key = "db", label = "价格库", getTarget = function() return f.EAHistoryBtn end, text = "价格库用于查看扫描记录、分类、常用物品和历史最低价。" },
                { key = "cfg", label = "设置", getTarget = function() return f.EAConfigBtn end, text = "设置面板同样贴在主框右侧，调整拍卖参数、插件排错和界面行为。" },
                { key = "snipe", label = "狙击", getTarget = function() return tab3 end, text = "狙击页用于维护目标物品，并从当前搜索结果里筛选可瞬秒或低价竞拍的条目。" },
            }
            for i, data in ipairs(stepData) do
                local btn = EAStyle and EAStyle:Button(body, data.label, 76) or CreateFrame("Button", nil, body, "UIPanelButtonTemplate")
                btn:SetSize(76, 22)
                btn:SetText(data.label)
                btn:SetPoint("TOPLEFT", body, "TOPLEFT", ((i - 1) % 3) * 82, -math.floor((i - 1) / 3) * 28)
                if not EAStyle then EA_SkinButton(btn) end
                btn.data = data
                guide.steps[#guide.steps + 1] = btn
            end
            local tip = body:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            tip:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -68)
            tip:SetPoint("RIGHT", body, "RIGHT", -2, 0)
            tip:SetJustifyH("LEFT")
            tip:SetJustifyV("TOP")
            tip:SetHeight(92)
            tip:SetSpacing(3)
            if EAStyle then EAStyle:SkinText(tip, "text") end
            guide.tip = tip

            local function SelectGuideStep(_, btn)
                local target = btn and btn.data and btn.data.getTarget and btn.data.getTarget()
                local text = btn and btn.data and btn.data.text or ""
                guide.tip:SetText(text)
                for _, step in ipairs(guide.steps or {}) do
                    EA_SetTextButtonActive(step, step == btn)
                end
                if target and target.GetParent then
                    highlight:SetParent(target:GetParent() or UIParent)
                    highlight:ClearAllPoints()
                    highlight:SetPoint("TOPLEFT", target, "TOPLEFT", -3, 3)
                    highlight:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 3, -3)
                    highlight:SetFrameLevel((target:GetFrameLevel() or 1) + 25)
                    highlight:Show()
                    guide:ClearAllPoints()
                    guide:SetPoint("TOPLEFT", target, "TOPRIGHT", 8, 0)
                else
                    highlight:Hide()
                    guide:ClearAllPoints()
                    guide:SetPoint("TOPLEFT", f, "TOPRIGHT", 6, 0)
                end
            end
            for _, step in ipairs(guide.steps) do
                step:SetScript("OnClick", function(self) SelectGuideStep(guide, self) end)
            end
            guide:SetScript("OnHide", function(self)
                if self.highlight then self.highlight:Hide() end
            end)
            guide.SelectGuideStep = SelectGuideStep
            tinsert(UISpecialFrames, "EasyAuction_HelpFrame")
            EasyAuction_HelpFrame = guide
        end
        if EasyAuction_HelpFrame.SelectGuideStep and EasyAuction_HelpFrame.steps and EasyAuction_HelpFrame.steps[1] then
            EasyAuction_HelpFrame:SelectGuideStep(EasyAuction_HelpFrame.steps[1])
        else
            EasyAuction_HelpFrame:ClearAllPoints()
            EasyAuction_HelpFrame:SetPoint("TOPLEFT", f, "TOPRIGHT", 6, 0)
        end
        EasyAuction_HelpFrame:Show()
    end)
    tab4:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT")
        GameTooltip:ClearLines()
        EA_AddMainHelpTooltipLines(version)
        GameTooltip:Show()
    end)
    tab4:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    EA_SkinTextButton(tab1, "闪购", 70, 22)
    tab1:ClearAllPoints()
    tab1:SetPoint("LEFT", tabStrip, "LEFT", 0, 0)
    EA_SkinTextButton(tab2, "闪卖", 70, 22)
    tab2:ClearAllPoints()
    tab2:SetPoint("LEFT", tab1, "RIGHT", 6, 0)
    EA_SkinTextButton(tab3, "狙击", 70, 22)
    tab3:ClearAllPoints()
    tab3:SetPoint("LEFT", tab2, "RIGHT", 6, 0)
    EA_SkinIconButton(tab4, 616343, 28, 28)
    tab4:ClearAllPoints()
    tab4:SetPoint("RIGHT", tabStrip, "RIGHT", 0, 0)
    EasyAuction_LayoutMainHeaderButtons()

    local tabFlashSellPage = CreateFrame("Frame", nil, contentFrame)
    tabFlashSellPage:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 8, -8)
    tabFlashSellPage:SetPoint("BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", -8, 8)
    tabFlashSellPage:Show()
    ns.tabFlashSellPage = tabFlashSellPage
    local recentCommonPanel = CreateFrame("Frame", nil, tabFlashSellPage, "BackdropTemplate")
    recentCommonPanel:SetPoint("BOTTOMLEFT", tabFlashSellPage, "BOTTOMLEFT", 0, 0)
    recentCommonPanel:SetPoint("BOTTOMRIGHT", tabFlashSellPage, "BOTTOMRIGHT", 0, 0)
    recentCommonPanel:SetHeight(240)
    recentCommonPanel:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 18,
        insets = { left = 6, right = 6, top = 6, bottom = 6 }
    })
    recentCommonPanel:SetBackdropColor(0.10, 0.10, 0.13, 0.97)
    recentCommonPanel:SetBackdropBorderColor(0.7, 0.6, 1, 1)
    EA_SkinPanel(recentCommonPanel, "panel")
    local detailPanel = CreateFrame("Frame", nil, tabFlashSellPage, "BackdropTemplate")
    detailPanel:SetPoint("TOPLEFT", tabFlashSellPage, "TOPLEFT", 0, 0)
    detailPanel:SetPoint("TOPRIGHT", tabFlashSellPage, "TOPRIGHT", 0, 0)
    detailPanel:SetHeight(132)
    EA_SkinPanel(detailPanel, "panel")
    f.FlashBuyDetailPanel = detailPanel
    recentCommonPanel:ClearAllPoints()
    recentCommonPanel:SetPoint("TOPLEFT", detailPanel, "BOTTOMLEFT", 0, -8)
    recentCommonPanel:SetPoint("BOTTOMRIGHT", tabFlashSellPage, "BOTTOMRIGHT", 0, 0)

    local currentPriceLabel = detailPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    currentPriceLabel:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "")
    currentPriceLabel:SetPoint("TOPRIGHT", detailPanel, "TOPRIGHT", -10, -8)
    currentPriceLabel:SetJustifyH("RIGHT")
    currentPriceLabel:SetText("当前价格")
    EA_SkinText(currentPriceLabel, "muted")

    local currentPriceValue = detailPanel:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    currentPriceValue:SetFont(
        NumberFontNormal and NumberFontNormal:GetFont() or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",
        14,
        ""
    )
    currentPriceValue:SetPoint("TOPRIGHT", currentPriceLabel, "BOTTOMRIGHT", 0, -1)
    currentPriceValue:SetJustifyH("RIGHT")
    currentPriceValue:SetWidth(138)
    EA_SkinText(currentPriceValue, "accent")

    local currentPriceDelta = detailPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    currentPriceDelta:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "")
    currentPriceDelta:SetPoint("TOPRIGHT", currentPriceValue, "BOTTOMRIGHT", 0, -2)
    currentPriceDelta:SetJustifyH("RIGHT")
    currentPriceDelta:SetWidth(138)
    EA_SkinText(currentPriceDelta, "muted")

    local sessionHeading = detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sessionHeading:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "")
    sessionHeading:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", 58, -37)
    sessionHeading:SetText("本次购买")
    EA_SkinText(sessionHeading, "muted")

    local function CreateCompactStat(anchor, labelText, offsetX)
        local label = detailPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "")
        label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", offsetX, -3)
        label:SetText(labelText)
        EA_SkinText(label, "muted")

        local value = detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        value:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
        value:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -1)
        value:SetWidth(82)
        value:SetJustifyH("LEFT")
        EA_SkinText(value, "text")
        return value
    end

    local sessionCountValue = CreateCompactStat(sessionHeading, "数量", 0)
    local sessionTotalValue = CreateCompactStat(sessionHeading, "合计", 48)
    local sessionAvgValue = CreateCompactStat(sessionHeading, "平均", 100)

    local function CreateMetricRow(parent, labelText, x, y, valueWidth)
        local label = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "")
        label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        label:SetText(labelText)
        label:SetWidth(48)
        label:SetJustifyH("LEFT")
        EA_SkinText(label, "muted")

        local value = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        value:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
        value:SetPoint("LEFT", label, "RIGHT", 6, 0)
        value:SetWidth(valueWidth or 96)
        value:SetJustifyH("LEFT")
        EA_SkinText(value, "text")
        return value
    end

    local function CreateDayRangeRows(parent, x, y, valueWidth)
        local title = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        title:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "")
        title:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        title:SetText("今日区间")
        title:SetWidth(48)
        title:SetJustifyH("LEFT")
        EA_SkinText(title, "muted")

        local lowLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        lowLabel:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "")
        lowLabel:SetPoint("LEFT", title, "RIGHT", 6, 0)
        lowLabel:SetText("低：")
        lowLabel:SetWidth(24)
        lowLabel:SetJustifyH("LEFT")
        EA_SkinText(lowLabel, "muted")

        local lowValue = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        lowValue:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
        lowValue:SetPoint("LEFT", lowLabel, "RIGHT", 2, 0)
        lowValue:SetWidth(valueWidth or 132)
        lowValue:SetJustifyH("LEFT")
        EA_SkinText(lowValue, "text")

        local highLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        highLabel:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "")
        highLabel:SetPoint("TOPLEFT", lowLabel, "BOTTOMLEFT", 0, -2)
        highLabel:SetText("高：")
        highLabel:SetWidth(24)
        highLabel:SetJustifyH("LEFT")
        EA_SkinText(highLabel, "muted")

        local highValue = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        highValue:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
        highValue:SetPoint("LEFT", highLabel, "RIGHT", 2, 0)
        highValue:SetWidth(valueWidth or 132)
        highValue:SetJustifyH("LEFT")
        EA_SkinText(highValue, "text")

        return { low = lowValue, high = highValue }
    end

    local flashBuyMetrics = {
        prevClose = CreateMetricRow(detailPanel, "前收盘", 10, -78, 90),
        dayRange = CreateDayRangeRows(detailPanel, 164, -78, 112),
        lowAll = CreateMetricRow(detailPanel, "历史最低", 10, -96, 90),
        highAll = CreateMetricRow(detailPanel, "历史最高", 10, -114, 90),
    }

    local minPriceCurLabel, minPriceCurValue = currentPriceLabel, currentPriceValue
    local minPriceTodayLabel, minPriceTodayValue = sessionHeading, currentPriceDelta
    local minPriceHistLabel, minPriceHistValue = flashBuyMetrics.lowAll, flashBuyMetrics.highAll

    local function SetMutedText(fs, text)
        if not fs then return end
        fs:SetText(text or "--")
        if EAStyle then
            local p = EAStyle:Palette()
            fs:SetTextColor(p.muted[1], p.muted[2], p.muted[3])
        else
            fs:SetTextColor(0.62, 0.62, 0.66)
        end
    end

    local function SetRoleColor(fs, role)
        if not fs then return end
        if EAStyle then
            local p = EAStyle:Palette()
            local col = p.text
            if role == "accent" then
                col = p.accent
            elseif role == "muted" then
                col = p.muted
            end
            fs:SetTextColor(col[1], col[2], col[3])
        elseif role == "accent" then
            fs:SetTextColor(0, 0.85, 1)
        elseif role == "muted" then
            fs:SetTextColor(0.62, 0.62, 0.66)
        else
            fs:SetTextColor(1, 1, 1)
        end
    end

    local function SetTrendText(fs, text, delta)
        if not fs then return end
        fs:SetText(text or "--")
        if EAStyle then
            local r, g, b = EAStyle:ColorTrend(delta or 0)
            fs:SetTextColor(r, g, b)
        elseif (delta or 0) >= 0 then
            fs:SetTextColor(0, 1, 0)
        else
            fs:SetTextColor(1, 0.35, 0.35)
        end
    end

    local function FormatPriceOrDash(copper)
        copper = tonumber(copper)
        if copper and copper > 0 then
            return FormatGoldIcon(copper, 10)
        end
        return "--"
    end

    local function BuildFlashBuyPriceStats(key, actualItemID)
        local db = EasyAuctionDB or {}
        local stats = {}
        local seen = {}
        local keys = {}
        if key then
            keys[#keys + 1] = key
            seen[key] = true
        end
        if actualItemID then
            local suffix = ":" .. tostring(actualItemID) .. "$"
            for k in pairs(db.DailyMinPrice or {}) do
                if not seen[k] and k:match(suffix) then
                    keys[#keys + 1] = k
                    seen[k] = true
                end
            end
            for k in pairs(db.PriceHistory or {}) do
                if not seen[k] and k:match(suffix) then
                    keys[#keys + 1] = k
                    seen[k] = true
                end
            end
        end

        local today = date("%Y-%m-%d")
        local prevDay
        for _, priceKey in ipairs(keys) do
            local dailyArray = EasyAuction_GetDailyMinPrice and EasyAuction_GetDailyMinPrice(priceKey, db) or (db.DailyMinPrice and db.DailyMinPrice[priceKey])
            if dailyArray then
                for _, rec in ipairs(dailyArray) do
                    local day = rec[1]
                    local close = tonumber(rec[2])
                    local low = tonumber(rec[4]) or close
                    local high = tonumber(rec[5]) or close
                    if day == today then
                        stats.current = stats.current or close
                        stats.todayMin = stats.todayMin and math.min(stats.todayMin, low or stats.todayMin) or low
                        stats.todayMax = stats.todayMax and math.max(stats.todayMax, high or stats.todayMax) or high
                    elseif day and day < today and close and (not prevDay or day > prevDay) then
                        prevDay = day
                        stats.prevClose = close
                    end
                    if low and low > 0 then
                        stats.lowAll = stats.lowAll and math.min(stats.lowAll, low) or low
                    end
                    if high and high > 0 then
                        stats.highAll = stats.highAll and math.max(stats.highAll, high) or high
                    end
                end
            end

            local history = EasyAuction_GetPriceHistory and EasyAuction_GetPriceHistory(priceKey, db) or (db.PriceHistory and db.PriceHistory[priceKey])
            if type(history) == "table" then
                if history.minUnit and history.minUnit > 0 then
                    stats.lowAll = stats.lowAll and math.min(stats.lowAll, history.minUnit) or history.minUnit
                end
                for _, rec in ipairs(history) do
                    local unit = tonumber(rec.unit)
                    if unit and unit > 0 then
                        stats.current = stats.current or unit
                        stats.lowAll = stats.lowAll and math.min(stats.lowAll, unit) or unit
                        stats.highAll = stats.highAll and math.max(stats.highAll, unit) or unit
                    end
                end
            end
        end
        return stats
    end

    function RefreshMinPriceLines(name, itemID)
        if not name or name == "" then
            minPriceCurLabel:SetText("当前价格")
            SetMutedText(minPriceCurValue, "无数据")
            minPriceTodayLabel:SetText("本次购买")
            SetMutedText(minPriceTodayValue, "较昨日：--")
            SetMutedText(sessionCountValue, "--")
            SetMutedText(sessionTotalValue, "--")
            SetMutedText(sessionAvgValue, "--")
            SetMutedText(flashBuyMetrics.prevClose, "--")
            SetMutedText(flashBuyMetrics.dayRange.low, "--")
            SetMutedText(flashBuyMetrics.dayRange.high, "--")
            SetMutedText(minPriceHistLabel, "--")
            SetMutedText(minPriceHistValue, "--")
            return
        end

        local key = nil
        local actualItemID = itemID
        local displayName = name
        if type(name) == "string" and name:find(":") then
            key = name
            local parsedName, parsedID = string.match(name, "^(.+):(%d+)$")
            if parsedName and parsedName ~= "" then
                displayName = parsedName
            end
            if parsedID then
                actualItemID = tonumber(parsedID)
            end
        else
            if not actualItemID then
                local _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, id = GetItemInfo(name)
                actualItemID = id
            end
            key = name .. ":" .. (actualItemID or "0")
        end
        if actualItemID then
            local itemName, _, quality, _, _, _, _, _, _, icon = GetItemInfo(actualItemID)
            displayName = itemName or displayName
            local color = ITEM_QUALITY_COLORS[quality or 1] or ITEM_QUALITY_COLORS[1]
            local displayText = displayName or tostring(actualItemID)
            if color then
                displayText = ("|cff%02x%02x%02x%s|r"):format(color.r * 255, color.g * 255, color.b * 255, displayText)
            end
            local itemButton = _G["EasyAuctionItemButton"]
            if itemButton then
                local sellName, _, _, _, _, _, _, _, _, sellItemID = GetAuctionSellItemInfo()
                local hasRealAuctionItem = sellName and sellItemID and not itemButton.isVirtual
                itemButton.itemID = actualItemID
                if not hasRealAuctionItem then
                    itemButton.isVirtual = true
                end
                SetItemButtonTexture(itemButton, icon or GetItemIcon(actualItemID) or "Interface\\Icons\\INV_Misc_QuestionMark")
                SetItemButtonCount(itemButton, 1)
                SetItemButtonQuality(itemButton, quality, actualItemID)
                FixItemButtonIconSize(itemButton, itemButton:GetWidth() or 40)
            end
            if f.ItemName then
                f.ItemName:SetText(displayText)
            end
            if f.ItemNameBtn then
                f.ItemNameBtn:Show()
            end
            if f.__EARaiseFlashBuyItemVisuals then
                f.__EARaiseFlashBuyItemVisuals()
            end
            AuctionBar._EA_SelectedItemID = actualItemID
            if f.__EARefreshHeader then
                f.__EARefreshHeader()
            end
        end

        local stats = BuildFlashBuyPriceStats(key, actualItemID)
        local curPrice = stats.current

        minPriceCurLabel:SetText("当前价格")
        if curPrice and curPrice > 0 then
            minPriceCurValue:SetText(FormatGoldIcon(curPrice, 12))
            SetRoleColor(minPriceCurValue, "accent")
        else
            SetMutedText(minPriceCurValue, "无数据")
        end

        if curPrice and stats.prevClose and stats.prevClose > 0 then
            local diff = curPrice - stats.prevClose
            local percent = diff / stats.prevClose * 100
            SetTrendText(minPriceTodayValue, string.format("较昨日：%+.1f%%", percent), diff)
        else
            SetMutedText(minPriceTodayValue, "较昨日：--")
        end

        local stat = actualItemID and EasyAuction_SessionBuyStats[actualItemID]
        if stat and stat.num and stat.num > 0 then
            local avg = math.floor(stat.sum / stat.num + 0.5)
            sessionCountValue:SetText(string.format("%d个", stat.num))
            sessionTotalValue:SetText(GetMoneyString(stat.sum, true))
            sessionAvgValue:SetText(GetMoneyString(avg, true))
            SetRoleColor(sessionCountValue, "text")
            SetRoleColor(sessionTotalValue, "text")
            SetRoleColor(sessionAvgValue, "text")
        else
            SetMutedText(sessionCountValue, "--")
            SetMutedText(sessionTotalValue, "--")
            SetMutedText(sessionAvgValue, "--")
        end

        flashBuyMetrics.prevClose:SetText(FormatPriceOrDash(stats.prevClose))
        SetRoleColor(flashBuyMetrics.prevClose, stats.prevClose and "text" or "muted")
        if stats.todayMin and stats.todayMax then
            flashBuyMetrics.dayRange.low:SetText(FormatPriceOrDash(stats.todayMin))
            flashBuyMetrics.dayRange.high:SetText(FormatPriceOrDash(stats.todayMax))
            SetRoleColor(flashBuyMetrics.dayRange.low, "text")
            SetRoleColor(flashBuyMetrics.dayRange.high, "text")
        else
            SetMutedText(flashBuyMetrics.dayRange.low, "--")
            SetMutedText(flashBuyMetrics.dayRange.high, "--")
        end
        minPriceHistLabel:SetText(FormatPriceOrDash(stats.lowAll))
        minPriceHistValue:SetText(FormatPriceOrDash(stats.highAll))
        SetRoleColor(minPriceHistLabel, stats.lowAll and "text" or "muted")
        SetRoleColor(minPriceHistValue, stats.highAll and "text" or "muted")
    end

    local rcTab1 = CreateFrame("Button", nil, recentCommonPanel)
    rcTab1:SetSize(80, 24)
    rcTab1:SetPoint("TOPLEFT", recentCommonPanel, 10, -5)
    rcTab1.icon = rcTab1:CreateTexture(nil, "ARTWORK")
    rcTab1.icon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    rcTab1.icon:SetSize(16, 16)
    rcTab1.icon:SetPoint("LEFT", rcTab1, "LEFT", 6, 0)
    rcTab1.text = rcTab1:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    rcTab1.text:SetPoint("LEFT", rcTab1.icon, "RIGHT", 4, 0)
    rcTab1.text:SetText("最近搜索")
    rcTab1.text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 13, "")
    rcTab1:SetNormalFontObject(GameFontNormal)
    EA_SkinTextButton(rcTab1, "最近搜索", 80, 22)

    local rcTab2 = CreateFrame("Button", nil, recentCommonPanel)
    rcTab2:SetSize(80, 24)
    rcTab2:SetPoint("LEFT", rcTab1, "RIGHT", 6, 0)
    rcTab2.icon = rcTab2:CreateTexture(nil, "ARTWORK")
    rcTab2.icon:SetTexture("Interface\\Icons\\inv_misc_gift_01")
    rcTab2.icon:SetSize(16, 16)
    rcTab2.icon:SetPoint("LEFT", rcTab2, "LEFT", 6, 0)

    rcTab2.text = rcTab2:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    rcTab2.text:SetPoint("LEFT", rcTab2.icon, "RIGHT", 4, 0)
    rcTab2.text:SetText("常用物品")
    rcTab2.text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 13, "")
    rcTab2:SetNormalFontObject(GameFontNormal)
    EA_SkinTextButton(rcTab2, "常用物品", 80, 22)

    local favoriteImportExportBtn = CreateFrame("Button", nil, recentCommonPanel, "UIPanelButtonTemplate")
    favoriteImportExportBtn:SetSize(80, 20)
    favoriteImportExportBtn:SetText("编辑清单")
    favoriteImportExportBtn:SetPoint("LEFT", rcTab2, "RIGHT", 54, 0)
    favoriteImportExportBtn:Hide()
    EA_SkinButton(favoriteImportExportBtn)

    local function ShowFavoriteImportExportFrame()
        if EasyAuctionFavoriteImportExportFrame and EasyAuctionFavoriteImportExportFrame:IsShown() then
            EasyAuctionFavoriteImportExportFrame:Hide()
            return
        end

        if not EasyAuctionFavoriteImportExportFrame then
            local f = CreateFrame("Frame", "EasyAuctionFavoriteImportExportFrame", UIParent, "BackdropTemplate")
            f:SetSize(360, 404)
            f:SetPoint("CENTER")
            f:SetFrameStrata("FULLSCREEN_DIALOG")
            f:SetMovable(true)
            f:EnableMouse(true)
            f:RegisterForDrag("LeftButton")
            f:SetScript("OnDragStart", f.StartMoving)
            f:SetScript("OnDragStop", f.StopMovingOrSizing)
            EA_SkinFrame(f, "window")

            local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
            title:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -12)
            title:SetText("常用物品清单")
            title:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 14, "")
            EA_SkinText(title, "accent")

            local warnBar = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            warnBar:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -38)
            warnBar:SetSize(318, 22)
            warnBar:SetJustifyH("LEFT")
            warnBar:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
            EA_SkinText(warnBar, "warning")
            warnBar:SetText("")
            warnBar:Hide()
            f.warnBar = warnBar

            local contentBG = CreateFrame("Frame", nil, f, "BackdropTemplate")
            contentBG:SetPoint("TOPLEFT", 18, -66)
            contentBG:SetPoint("BOTTOMRIGHT", -18, 76)
            EA_SkinPanel(contentBG, "plot")

            local scrollFrame = CreateFrame("ScrollFrame", nil, contentBG, "UIPanelScrollFrameTemplate")
            scrollFrame:SetPoint("TOPLEFT", 8, -8)
            scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)

            local editBox = CreateFrame("EditBox", nil, scrollFrame)
            editBox:SetMultiLine(true)
            editBox:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
            editBox:SetMaxLetters(8000)
            editBox:SetWidth(282)
            editBox:SetHeight(260)
            editBox:SetAutoFocus(false)
            if editBox.SetTextColor and EAStyle then
                local p = EAStyle:Palette()
                editBox:SetTextColor(p.text[1], p.text[2], p.text[3], 1)
            end
            scrollFrame:SetScrollChild(editBox)
            f.editBox = editBox

            local tip = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            tip:SetPoint("TOPLEFT", contentBG, "BOTTOMLEFT", 2, 0)
            tip:SetPoint("RIGHT", f, -18, 0)
            tip:SetJustifyH("LEFT")
            tip:SetSpacing(4)
            tip:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "")
            EA_SkinText(tip, "muted")
            tip:SetText(
                "每行格式：物品ID,物品名\n" ..
                "可全选复制到别的号，也可手动编辑。\n" ..
                "要清空全部常用物品，请清空内容后保存。"
            )

            local saveBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            saveBtn:SetSize(72, 22)
            saveBtn:SetText("保存")
            saveBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 16)
            EA_SkinButton(saveBtn)

            local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            closeBtn:SetSize(72, 22)
            closeBtn:SetText("关闭")
            closeBtn:SetPoint("RIGHT", saveBtn, "LEFT", -6, 0)
            EA_SkinButton(closeBtn)
            closeBtn:SetScript("OnClick", function()
                f:Hide()
            end)

            local topCloseBtn = EAStyle and EAStyle:CloseButton(f) or CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            topCloseBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
            topCloseBtn:SetScript("OnClick", function()
                f:Hide()
            end)

            f.origText = ""

            saveBtn:SetScript("OnClick", function()
                local text = editBox:GetText() or ""
                text = text:gsub("，", ",")
                local newTbl = {}
                local lineCount = 0
                local errorLine
                for line in text:gmatch("[^\r\n]+") do
                    local id, name = line:match("^%s*(%d+)%s*,%s*(.+)%s*$")
                    if not id or not name then
                        if line:find("，") then
                            errorLine = line
                            break
                        end
                    else
                        local currentTime = currentTime or time()
                        newTbl[tonumber(id)] = { name = name, time = currentTime - lineCount }
                        lineCount = lineCount + 1
                    end
                end
                if errorLine then
                    f.warnBar:SetText("|cffff4040保存失败，第一个格式错误（或含中文逗号）的行：|r" .. errorLine)
                    f.warnBar:Show()
                    return
                end
                EasyAuctionDB.FavoriteItems = newTbl
                f.origText = text
                f.warnBar:Hide()
                if lineCount == 0 then
                    print("|cff00ff00常用物品清单已清空。|r")
                else
                    print("|cff00ff00常用物品清单已保存，共|r|cffffff00" .. lineCount .. "|r|cff00ff00项。|r")
                end
                if RefreshFavoriteRows then RefreshFavoriteRows() end
                f:Hide()
            end)
            editBox:SetScript("OnEscapePressed", function(self)
                self:ClearFocus()
            end)
            editBox:SetScript("OnEditFocusLost", function(self)
                self:HighlightText(0, 0)
                local orig = f.origText or ""
                if self:GetText() ~= orig then
                    f.warnBar:SetText("|cffffff00内容已更改，记得点击保存。|r")
                    f.warnBar:Show()
                end
            end)



            f:SetPropagateKeyboardInput(true)
            f:EnableKeyboard(true)
            f:SetScript("OnKeyDown", function(self, key)
                if key == "ESCAPE" then
                    if not editBox:HasFocus() then
                        self:Hide()
                    end
                end
            end)
            f:SetScript("OnShow", function(self)
                self:SetPropagateKeyboardInput(true)
                self:EnableKeyboard(true)
            end)
            f:SetScript("OnHide", function(self)
                self:EnableKeyboard(false)
            end)

            EasyAuctionFavoriteImportExportFrame = f
        end

        local function RefreshFavoriteListContent(editBox)
            local tbl = EasyAuctionDB.FavoriteItems or {}
            local arr = {}
            for k, v in pairs(tbl) do
                table.insert(arr, { id = k, name = v.name or "", time = v.time or 0 })
            end
            table.sort(arr, function(a, b) return (a.time or 0) > (b.time or 0) end)
            local lines = {}
            for _, v in ipairs(arr) do
                table.insert(lines, string.format("%s,%s", tostring(v.id), v.name))
            end
            local text = table.concat(lines, "\n")
            editBox:SetText(text)
            editBox:HighlightText(0, -1)
            local frame = EasyAuctionFavoriteImportExportFrame
            if frame then
                frame.origText = text
                if frame.warnBar then
                    frame.warnBar:SetText("")
                    frame.warnBar:Hide()
                end
            end
        end

        EasyAuctionFavoriteImportExportFrame:Show()
        RefreshFavoriteListContent(EasyAuctionFavoriteImportExportFrame.editBox)
        EasyAuctionFavoriteImportExportFrame.editBox:SetFocus()
    end

    favoriteImportExportBtn:SetScript("OnClick", function()
        if type(EasyAuction_ShowCategoryManager) == "function" then
            EasyAuction_ShowCategoryManager("常用")
        else
            ShowFavoriteImportExportFrame()
        end
    end)
    favoriteImportExportBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("编辑常用物品清单", 1, 1, 1)
        GameTooltip:AddLine("与价格库中的“常用”分类共用同一份数据", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    favoriteImportExportBtn:SetScript("OnLeave", GameTooltip_Hide)

    local rcScroll1 = CreateFrame("ScrollFrame", "EasyAuctionRecentSearchScroll", recentCommonPanel,
        "UIPanelScrollFrameTemplate")
    rcScroll1:SetPoint("TOPLEFT", 10, -26)
    rcScroll1:SetPoint("BOTTOMRIGHT", -20, 10)
    local rcScrollChild1 = CreateFrame("Frame", nil, rcScroll1)
    rcScrollChild1:SetWidth(recentCommonPanel:GetWidth() - 24)
    rcScroll1:SetScrollChild(rcScrollChild1)
    rcScroll1:Hide()
    local scrollBar = _G["EasyAuctionRecentSearchScrollScrollBar"]
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPRIGHT", rcScroll1, "TOPRIGHT", 12, -18)
        scrollBar:SetPoint("BOTTOMRIGHT", rcScroll1, "BOTTOMRIGHT", 12, 18)
        scrollBar:SetWidth(12)
    end

    local rcScroll2 = CreateFrame("ScrollFrame", "EasyAuctionFavoriteScroll", recentCommonPanel,
        "UIPanelScrollFrameTemplate")
    rcScroll2:SetPoint("TOPLEFT", 10, -26)
    rcScroll2:SetPoint("BOTTOMRIGHT", -20, 10)
    local rcScrollChild2 = CreateFrame("Frame", nil, rcScroll2)
    rcScrollChild2:SetWidth(recentCommonPanel:GetWidth() - 24)
    rcScroll2:SetScrollChild(rcScrollChild2)
    rcScroll2:Hide()
    local favScrollBar = _G["EasyAuctionFavoriteScrollScrollBar"]
    if favScrollBar then
        favScrollBar:ClearAllPoints()
        favScrollBar:SetPoint("TOPRIGHT", rcScroll2, "TOPRIGHT", 12, -18)
        favScrollBar:SetPoint("BOTTOMRIGHT", rcScroll2, "BOTTOMRIGHT", 12, 18)
        favScrollBar:SetWidth(12)
    end

    local function ShowRCTab(idx)
        if idx == 1 then
            rcScroll1:Show()
            rcScroll2:Hide()
            rcTab1:SetText("最近搜索")
            rcTab2:SetText("常用物品")
            EA_SetTextButtonActive(rcTab1, true)
            EA_SetTextButtonActive(rcTab2, false)
            favoriteImportExportBtn:Hide()
        else
            rcScroll1:Hide()
            rcScroll2:Show()
            rcTab1:SetText("最近搜索")
            rcTab2:SetText("常用物品")
            EA_SetTextButtonActive(rcTab1, false)
            EA_SetTextButtonActive(rcTab2, true)
            favoriteImportExportBtn:Show()
        end
    end
    rcTab1:SetScript("OnClick", function()
        ShowRCTab(1); RefreshRecentSearchRows()
    end)
    rcTab2:SetScript("OnClick", function()
        ShowRCTab(2); RefreshFavoriteRows()
    end)

    local function FormatTimeAgo(ts)
        local d = time() - (ts or 0)
        if d < 60 then
            return string.format("|cff00ff00(%d秒前)|r", d)
        elseif d < 3600 then
            return string.format("|cff00ff00(%d分钟前)|r", math.floor(d / 60))
        elseif d < 86400 then
            return string.format("|cff00ff00(%d小时前)|r", math.floor(d / 3600))
        else
            return string.format("|cff00ff00(%d天前)|r", math.floor(d / 86400))
        end
    end

    local MAX_SNIPE_STORE = 50
    local EasyAuction_RightClickMenu = CreateFrame("Frame", "EasyAuction_RightClickMenu", UIParent, "UIDropDownMenuTemplate")
    local function ShowRightClickMenu(anchor, itemID, itemName, context)
        if not itemID then return end
        local menu = {
            {
                text = "加入狙击物品列表",
                func = function()
                    EasyAuctionDB.SnipeList = EasyAuctionDB.SnipeList or {}
                    if not EasyAuctionDB.SnipeList[itemID] then
                        EasyAuctionDB.SnipeList[itemID] = { name = itemName, time = time() }
                        local items = {}
                        for id, info in pairs(EasyAuctionDB.SnipeList) do
                            table.insert(items, { id = id, time = info.time or 0 })
                        end
                        table.sort(items, function(a, b) return (a.time or 0) > (b.time or 0) end)
                        for i = MAX_SNIPE_STORE + 1, #items do
                            EasyAuctionDB.SnipeList[items[i].id] = nil
                        end
                        print("|cffffd200已加入狙击物品列表|r", itemName or itemID)
                    else
                        print("|cffff8800该物品已在狙击列表中|r")
                    end
                    if RefreshSnipeRows then RefreshSnipeRows() end
                end,
            },
            { text = "取消", func = function() end }
        }
        if context == "recent" then
            table.insert(menu, 1, {
                text = "添加到常用物品",
                func = function()
                    AddFavoriteItem(itemID, itemName, 0, time())
                    if RefreshFavoriteRows then RefreshFavoriteRows() end
                    print("|cff00ff00已添加到常用物品|r")
                end
            })
        elseif context == "favorite" then
            table.insert(menu, 1, {
                text = "移除常用物品",
                func = function()
                    EasyAuctionDB.FavoriteItems[itemID] = nil
                    if RefreshFavoriteRows then RefreshFavoriteRows() end
                    print("|cffff2020已从常用物品移除|r")
                end
            })
        end
        EasyAuction_RightClickMenu.displayMode = "MENU"
        EasyAuction_RightClickMenu.initialize = function(_, level)
            for _, entry in ipairs(menu) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = entry.text
                info.func = entry.func
                UIDropDownMenu_AddButton(info, level)
            end
        end
        ToggleDropDownMenu(1, nil, EasyAuction_RightClickMenu, anchor, 0, 0)
    end

    local RECENT_ROW_HEIGHT = 38
    local ICON_SIZE = 32
    local recentRows = {}
    function RefreshRecentSearchRows(autoFillFirstItem)
        if type(EasyAuctionDB.RecentSearch) ~= "table" then
            EasyAuctionDB.RecentSearch = {}
        end
        for _, row in ipairs(recentRows) do row:Hide() end
        local RECENT_MAX_SHOW = 10
        local total = math.min(#EasyAuctionDB.RecentSearch, RECENT_MAX_SHOW)
        for i = 1, total do
            local info = EasyAuctionDB.RecentSearch[i]
            local row = recentRows[i]
            if not row then
                row = CreateFrame("Button", nil, rcScrollChild1)
                row:SetSize(rcScrollChild1:GetWidth(), RECENT_ROW_HEIGHT)
                row.bg = row:CreateTexture(nil, "BACKGROUND")
                row.bg:SetAllPoints()
                EA_RowColor(row.bg, i)
                row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
                row.highlight:SetAllPoints()
                row.highlight:SetColorTexture(1, 1, 1, 0.09)
                row.icon = row:CreateTexture(nil, "ARTWORK")
                row.icon:SetSize(ICON_SIZE, ICON_SIZE)
                row.icon:SetPoint("LEFT", 6, 0)
                row.iconBorder = row:CreateTexture(nil, "OVERLAY")
                row.iconBorder:SetPoint("CENTER", row.icon, "CENTER")
                row.iconBorder:SetSize(ICON_SIZE + 4, ICON_SIZE + 4)
                row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                row.name:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 13, "")
                row.name:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
                row.name:SetJustifyH("LEFT")
                row.name:SetWidth(130)
                row.price = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                row.price:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
                row.price:SetPoint("LEFT", row.name, "RIGHT", -5, 8)
                row.price:SetWidth(120)
                row.price:SetJustifyH("RIGHT")
                row.trendBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                row.trendBtn:SetSize(50, 20)
                row.trendBtn:SetText("走势")
                row.trendBtn:SetNormalFontObject(GameFontNormalSmall)
                row.trendBtn:SetHighlightFontObject(GameFontHighlightSmall)
                EA_SkinButton(row.trendBtn)
                row.time = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                row.time:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
                row.time:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -5, 5)
                recentRows[i] = row
            end


            local name, _, quality, _, _, _, _, maxStack, _, icon = GetItemInfo(info.itemID)
            local price = nil
            local key = name and info.itemID and (name .. ":" .. info.itemID) or name
            if key then
                local history = EasyAuction_GetPriceHistory and EasyAuction_GetPriceHistory(key, EasyAuctionDB) or (EasyAuctionDB.PriceHistory and EasyAuctionDB.PriceHistory[key])
                if #history > 0 and history[1].unit then
                    price = history[1].unit
                end
            end

            local color = ITEM_QUALITY_COLORS[quality or 1] or ITEM_QUALITY_COLORS[1]
            row.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            row.name:SetText(name or info.name)
            row.name:SetTextColor(color.r, color.g, color.b)
            if price and price > 0 then
                row.price:SetText(GetCoinTextureString(price))
            else
                row.price:SetText("|cff888888无在售|r")
            end
            row.time:SetText(FormatTimeAgo(info.time))
            row.iconBorder:SetTexture("Interface\\AddOns\\EasyAuction\\border.blp")
            row.iconBorder:SetVertexColor(color.r, color.g, color.b, 0.9)
            row.trendBtn:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -65, 1)
            row.trendBtn:SetScript("OnClick", function()
                local itemKey = (name or info.name) .. ":" .. info.itemID
                EasyAuction_ShowChart(itemKey)
            end)
            row:SetPoint("TOPLEFT", rcScrollChild1, "TOPLEFT", -5, -((i - 1) * RECENT_ROW_HEIGHT))
            row:Show()
            row:SetScript("OnEnter", function(self)
                if self.bg then EA_RowColor(self.bg, i, true) end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:ClearLines()
                GameTooltip:SetItemByID(info.itemID)
                GameTooltip:AddLine("左键点击：复制名称", 1, 1, 1)
                GameTooltip:AddLine("右键点击：打开操作菜单", 0, 1, 0)
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function(self)
                if self.bg then
                    if i % 2 == 1 then
                        EA_RowColor(self.bg, i)
                    else
                        EA_RowColor(self.bg, i)
                    end
                end
                GameTooltip:Hide()
            end)
            row:SetScript("OnMouseUp", function(self, btn)
                if btn == "RightButton" then
                    ShowRightClickMenu(self, info.itemID, name or info.name, "recent")
                elseif btn == "LeftButton" then
                    EasyAuction_ShowCopyBox("\"" .. (name or info.name) .. "\"")
                end
            end)
        end
        rcScrollChild1:SetHeight(total * RECENT_ROW_HEIGHT)

        if total > 0 and autoFillFirstItem then
            local f = AuctionBar and AuctionBar.AuctionFrame
            local ItemButton = _G["EasyAuctionItemButton"]
            if f and ItemButton then
                if not ItemButton.itemID or ItemButton.isVirtual then
                    local first = EasyAuctionDB.RecentSearch[1]
                    if first and first.itemID and first.name then
                        ItemButton.itemID = first.itemID
                        ItemButton.isVirtual = true
                        local icon = GetItemIcon(first.itemID)
                        if icon then
                            SetItemButtonTexture(ItemButton, icon)
                            FixItemButtonIconSize(ItemButton, ItemButton:GetWidth() or 40)
                        end
                        if f.ItemName then
                            f.ItemName:SetText(first.name)
                        end
                        if RefreshMinPriceLines then RefreshMinPriceLines(first.name, first.itemID) end
                    end
                else
                    local name, _, _, _, _, _, _, _, _, itemID = GetAuctionSellItemInfo()
                    if name and itemID then
                        RefreshMinPriceLines(name, itemID)
                    end
                end
            end
        else
            -- 只在拍卖框已有物品时才刷新价格线，不自动填充物品
            local f = AuctionBar and AuctionBar.AuctionFrame
            local ItemButton = _G["EasyAuctionItemButton"]
            if f and ItemButton then
                if ItemButton.itemID and not ItemButton.isVirtual then
                    local name, _, _, _, _, _, _, _, _, itemID = GetAuctionSellItemInfo()
                    if name and itemID then
                        RefreshMinPriceLines(name, itemID)
                    end
                end
            end
        end
    end

    rcScroll1:EnableMouseWheel(true)
    rcScroll1:SetScript("OnMouseWheel", function(self, delta)
        local bar = self.ScrollBar
        if bar then
            bar:SetValue(bar:GetValue() - delta * RECENT_ROW_HEIGHT * 2)
        end
    end)

    local FAVORITE_ROW_HEIGHT = 38
    local favoriteRows = {}
    function RefreshFavoriteRows()
        if type(EasyAuctionDB.FavoriteItems) ~= "table" then
            EasyAuctionDB.FavoriteItems = {}
        end
        for _, row in ipairs(favoriteRows) do row:Hide() end
        local items = {}
        for itemID, info in pairs(EasyAuctionDB.FavoriteItems) do
            table.insert(items, { itemID = itemID, info = info })
        end
        table.sort(items, function(a, b) return (a.info.time or 0) > (b.info.time or 0) end)
        local total = #items
        for i = 1, total do
            local entry = items[i]
            local info = entry.info
            local itemID = entry.itemID
            local row = favoriteRows[i]
            if not row then
                row = CreateFrame("Button", nil, rcScrollChild2)
                row:SetSize(rcScrollChild2:GetWidth(), FAVORITE_ROW_HEIGHT)
                row.bg = row:CreateTexture(nil, "BACKGROUND")
                row.bg:SetAllPoints()
                EA_RowColor(row.bg, i)
                row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
                row.highlight:SetAllPoints()
                row.highlight:SetColorTexture(1, 1, 1, 0.09)
                row.icon = row:CreateTexture(nil, "ARTWORK")
                row.icon:SetSize(ICON_SIZE, ICON_SIZE)
                row.icon:SetPoint("LEFT", 6, 0)
                row.iconBorder = row:CreateTexture(nil, "OVERLAY")
                row.iconBorder:SetPoint("CENTER", row.icon, "CENTER")
                row.iconBorder:SetSize(ICON_SIZE + 4, ICON_SIZE + 4)
                row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                row.name:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 13, "")
                row.name:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
                row.name:SetJustifyH("LEFT")
                row.name:SetWidth(130)
                row.price = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                row.price:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
                row.price:SetPoint("LEFT", row.name, "RIGHT", -5, 8)
                row.price:SetWidth(120)
                row.price:SetJustifyH("RIGHT")
                row.time = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                row.time:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
                row.time:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -5, 5)
                row.trendBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                row.trendBtn:SetSize(50, 20)
                row.trendBtn:SetText("走势")
                row.trendBtn:SetNormalFontObject(GameFontNormalSmall)
                row.trendBtn:SetHighlightFontObject(GameFontHighlightSmall)
                EA_SkinButton(row.trendBtn)
                favoriteRows[i] = row
            end
            local name, _, quality, _, _, _, _, maxStack, _, icon = GetItemInfo(itemID)
            local price = nil
            local key = name and itemID and (name .. ":" .. itemID) or name
            if key then
                local history = EasyAuction_GetPriceHistory and EasyAuction_GetPriceHistory(key, EasyAuctionDB) or (EasyAuctionDB.PriceHistory and EasyAuctionDB.PriceHistory[key])
                if #history > 0 and history[1].unit then
                    price = history[1].unit
                end
            end
            local color = ITEM_QUALITY_COLORS[quality or 1] or ITEM_QUALITY_COLORS[1]
            row.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            row.name:SetText(name or info.name)
            row.name:SetTextColor(color.r, color.g, color.b)
            row.price:SetText(GetCoinTextureString(price or 0))
            row.time:SetText(FormatTimeAgo(info.time))
            row.iconBorder:SetTexture("Interface\\AddOns\\EasyAuction\\border.blp")
            row.iconBorder:SetVertexColor(color.r, color.g, color.b, 0.9)
            row.trendBtn:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -65, 1)
            row.trendBtn:SetScript("OnClick", function()
                local itemKey = (name or info.name) .. ":" .. itemID
                EasyAuction_ShowChart(itemKey)
            end)
            row:SetPoint("TOPLEFT", rcScrollChild2, "TOPLEFT", -5, -((i - 1) * FAVORITE_ROW_HEIGHT))
            row:Show()
            row:SetScript("OnEnter", function(self)
                if self.bg then EA_RowColor(self.bg, i, true) end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:ClearLines()
                GameTooltip:SetItemByID(itemID)
                GameTooltip:AddLine("左键点击：复制名称", 1, 1, 1)
                GameTooltip:AddLine("右键点击：打开操作菜单", 1, 0.8, 0.3)
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function(self)
                if self.bg then
                    if i % 2 == 1 then
                        EA_RowColor(self.bg, i)
                    else
                        EA_RowColor(self.bg, i)
                    end
                end
                GameTooltip:Hide()
            end)
            row:SetScript("OnMouseUp", function(self, btn)
                if btn == "RightButton" then
                    ShowRightClickMenu(self, itemID, name or info.name, "favorite")
                elseif btn == "LeftButton" then
                    EasyAuction_ShowCopyBox("\"" .. (name or info.name) .. "\"")
                end
            end)
        end
        rcScrollChild2:SetHeight(total * FAVORITE_ROW_HEIGHT)
    end

    rcScroll2:EnableMouseWheel(true)
    rcScroll2:SetScript("OnMouseWheel", function(self, delta)
        local bar = self.ScrollBar
        if bar then
            bar:SetValue(bar:GetValue() - delta * RECENT_ROW_HEIGHT * 2)
        end
    end)

    ShowRCTab(1)
    RefreshRecentSearchRows()
    RefreshFavoriteRows()

    local tabOtherPage = CreateFrame("Frame", nil, contentFrame)
    tabOtherPage:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 8, -8)
    tabOtherPage:SetPoint("BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", -8, 8)
    tabOtherPage:Hide()
    local function ClearAuctionVirtualItem()
        local f = AuctionBar and AuctionBar.AuctionFrame
        local ItemButton = _G["EasyAuctionItemButton"]
        if not f or not ItemButton then return end
        if ItemButton.isVirtual then
            ItemButton.itemID = nil
            ItemButton.isVirtual = nil
            SetItemButtonTexture(ItemButton, "")
            SetItemButtonCount(ItemButton, 0)
            SetItemButtonQuality(ItemButton, nil)
            RefreshMinPriceLines()
            if f.ItemName then f.ItemName:SetText("") end
        end
    end

    local tabSnipePage = CreateFrame("Frame", nil, contentFrame)
    tabSnipePage:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 8, -8)
    tabSnipePage:SetPoint("BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", -8, 8)
    tabSnipePage:Hide()
    ns.tabSnipePage = tabSnipePage

    local SNIPE_ROW_HEIGHT = 30
    local SNIPE_ICON_SIZE = 24
    local MAX_SNIPE_SHOW = 6
    local snipePanel = CreateFrame("Frame", nil, tabSnipePage, "BackdropTemplate")
    snipePanel:SetPoint("TOPLEFT", 0, -6)
    snipePanel:SetPoint("TOPRIGHT", -80, -6)
    snipePanel:SetHeight(SNIPE_ROW_HEIGHT * MAX_SNIPE_SHOW + 24)
    EA_SkinPanel(snipePanel, "panel")
    EA_ApplyOutline(snipePanel, 0.85)

    local snipeScroll = CreateFrame("ScrollFrame", "EasyAuctionSnipeScroll", snipePanel, "FauxScrollFrameTemplate")
    snipeScroll:SetPoint("TOPLEFT", snipePanel, "TOPLEFT", 0, -24)
    snipeScroll:SetPoint("BOTTOMRIGHT", snipePanel, "BOTTOMRIGHT", -20, 0)
    snipeScroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, SNIPE_ROW_HEIGHT, RefreshSnipeRows)
    end)

    local snipeTitle = snipePanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    snipeTitle:SetPoint("TOPLEFT", 10, -8)
    snipeTitle:SetText("狙击物品列表")
    snipeTitle:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 14, "")

    local snipeRows = {}
    function RefreshSnipeRows()
        EasyAuctionDB.SnipeList = EasyAuctionDB.SnipeList or {}
        local items = {}
        for itemID, info in pairs(EasyAuctionDB.SnipeList) do
            table.insert(items, { itemID = itemID, info = info })
        end
        table.sort(items, function(a, b) return (a.info.time or 0) > (b.info.time or 0) end)
        local offset = FauxScrollFrame_GetOffset(snipeScroll)
        FauxScrollFrame_Update(snipeScroll, #items, MAX_SNIPE_SHOW, SNIPE_ROW_HEIGHT)

        for i = 1, MAX_SNIPE_SHOW do
            local row = snipeRows[i]
            if not row then
                row = CreateFrame("Button", nil, snipePanel)
                row:SetSize(250, SNIPE_ROW_HEIGHT)
                row.bg = row:CreateTexture(nil, "BACKGROUND")
                row.bg:SetAllPoints()
                row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
                row.highlight:SetAllPoints()
                row.highlight:SetColorTexture(1, 1, 1, 0.09)
                row.icon = row:CreateTexture(nil, "ARTWORK")
                row.icon:SetSize(SNIPE_ICON_SIZE, SNIPE_ICON_SIZE)
                row.icon:SetPoint("LEFT", 6, 0)
                row.iconBorder = row:CreateTexture(nil, "OVERLAY")
                row.iconBorder:SetPoint("CENTER", row.icon, "CENTER")
                row.iconBorder:SetSize(SNIPE_ICON_SIZE + 4, SNIPE_ICON_SIZE + 4)
                row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                row.name:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 13, "")
                row.name:SetPoint("LEFT", row.icon, "RIGHT", 5, 0)
                row.name:SetJustifyH("LEFT")
                row.name:SetWidth(100)
                row.price = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                row.price:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
                row.price:SetPoint("LEFT", row.name, "RIGHT", -5, 0)
                row.price:SetWidth(90)
                row.price:SetJustifyH("RIGHT")
                EA_ApplyRowLines(row, { 30, 128, 92 }, SNIPE_ROW_HEIGHT)
                snipeRows[i] = row
            end
            local entry = items[offset + i]
            if entry then
                local itemID = tonumber(entry.itemID) or entry.itemID
                local info = entry.info
                local name, _, quality, _, _, _, _, _, _, icon = GetItemInfo(itemID)
                local color = ITEM_QUALITY_COLORS[quality or 1] or ITEM_QUALITY_COLORS[1]
                row.bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.05 or 0.10)
                row.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                row.name:SetText(name or info.name or ("ID:" .. tostring(itemID)))
                row.name:SetTextColor(color.r, color.g, color.b)
                row.price:SetText(info.maxPrice and GetCoinTextureString(info.maxPrice) or "")
                row.iconBorder:SetTexture("Interface\\AddOns\\EasyAuction\\border.blp")
                row.iconBorder:SetVertexColor(color.r, color.g, color.b, 0.9)
                row:SetPoint("TOPLEFT", snipePanel, "TOPLEFT", 0, -22 - (i - 1) * SNIPE_ROW_HEIGHT)
                row:Show()
                row:SetScript("OnEnter", function()
                    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
                    GameTooltip:ClearLines()
                    GameTooltip:SetItemByID(itemID)
                    GameTooltip:AddLine("左键点击：复制名称", 1, 1, 1)
                    GameTooltip:AddLine("右键点击：移除狙击物品", 1, 0.3, 0.3)
                    GameTooltip:Show()
                end)
                row:SetScript("OnLeave", GameTooltip_Hide)
                row:SetScript("OnMouseUp", function(_, btn)
                    if btn == "RightButton" then
                        StaticPopupDialogs["EASYAUCTION_REMOVE_SNIPEITEM"] = {
                            text = "确定要移除狙击物品：\n|cffffff00" .. (name or info.name or tostring(itemID)) .. "|r？",
                            button1 = "移除",
                            button2 = "取消",
                            OnAccept = function()
                                EasyAuctionDB.SnipeList[entry.itemID] = nil
                                EasyAuctionDB.SnipeList[itemID] = nil
                                RefreshSnipeRows()
                                print("|cffff2020已从狙击列表移除|r", name or info.name or itemID)
                            end,
                            timeout = 0,
                            whileDead = true,
                            hideOnEscape = true,
                            preferredIndex = 3,
                        }
                        StaticPopup_Show("EASYAUCTION_REMOVE_SNIPEITEM")
                    elseif btn == "LeftButton" then
                        EasyAuction_ShowCopyBox("\"" .. (name or info.name or itemID) .. "\"")
                    end
                end)
            else
                row:Hide()
            end
        end
    end

    local preyPanel = CreateFrame("Frame", nil, tabSnipePage, "BackdropTemplate")
    preyPanel:SetPoint("TOPLEFT", snipePanel, "BOTTOMLEFT", 0, -10)
    preyPanel:SetPoint("BOTTOMRIGHT", tabSnipePage, "BOTTOMRIGHT", 0, 0)
    preyPanel:SetHeight(230)
    EA_SkinPanel(preyPanel, "panel")
    EA_ApplyOutline(preyPanel, 0.85)

    local preyTab1 = CreateFrame("Button", nil, preyPanel)
    preyTab1:SetSize(106, 24)
    preyTab1:SetPoint("TOPLEFT", 8, -5)
    preyTab1.icon = preyTab1:CreateTexture(nil, "ARTWORK")
    preyTab1.icon:SetTexture("Interface\\Icons\\ability_hunter_snipershot")
    preyTab1.icon:SetSize(16, 16)
    preyTab1.icon:SetPoint("LEFT", preyTab1, "LEFT", 6, 0)
    preyTab1.text = preyTab1:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    preyTab1.text:SetPoint("LEFT", preyTab1.icon, "RIGHT", 4, 0)
    preyTab1.text:SetText("狙击")
    preyTab1.text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 13, "")
    EA_SkinTextButton(preyTab1, "狙击", 82, 22)

    local preyTab2 = CreateFrame("Button", nil, preyPanel)
    preyTab2:SetSize(106, 24)
    preyTab2:SetPoint("LEFT", preyTab1, "RIGHT", 6, 0)
    preyTab2.icon = preyTab2:CreateTexture(nil, "ARTWORK")
    preyTab2.icon:SetTexture("Interface\\Icons\\spell_holy_borrowedtime")
    preyTab2.icon:SetSize(16, 16)
    preyTab2.icon:SetPoint("LEFT", preyTab2, "LEFT", 6, 0)
    preyTab2.text = preyTab2:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    preyTab2.text:SetPoint("LEFT", preyTab2.icon, "RIGHT", 4, 0)
    preyTab2.text:SetText("竞价")
    preyTab2.text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 13, "")
    EA_SkinTextButton(preyTab2, "竞价", 82, 22)

    local preyScroll1 = CreateFrame("ScrollFrame", "EasyAuctionPreySnipeScroll", preyPanel, "UIPanelScrollFrameTemplate")
    preyScroll1:SetPoint("TOPLEFT", 0, -28)
    preyScroll1:SetPoint("BOTTOMRIGHT", -24, 0)
    local preyScrollChild1 = CreateFrame("Frame", nil, preyScroll1)
    preyScrollChild1:SetWidth(320)
    preyScroll1:SetScrollChild(preyScrollChild1)

    local preyScroll2 = CreateFrame("ScrollFrame", "EasyAuctionPreyBidScroll", preyPanel, "UIPanelScrollFrameTemplate")
    preyScroll2:SetPoint("TOPLEFT", 0, -28)
    preyScroll2:SetPoint("BOTTOMRIGHT", -24, 0)
    local preyScrollChild2 = CreateFrame("Frame", nil, preyScroll2)
    preyScrollChild2:SetWidth(320)
    preyScroll2:SetScrollChild(preyScrollChild2)
    preyScroll2:Hide()

    local snipeBuyAllBtn = CreateFrame("Button", nil, preyPanel, "UIPanelButtonTemplate")
    snipeBuyAllBtn:SetSize(80, 22)
    snipeBuyAllBtn:SetText("狙击瞬秒")
    snipeBuyAllBtn:SetPoint("LEFT", preyTab2, "RIGHT", 12, 0)
    EA_SkinButton(snipeBuyAllBtn)

    local bidAllBtn = CreateFrame("Button", nil, preyPanel, "UIPanelButtonTemplate")
    bidAllBtn:SetSize(80, 22)
    bidAllBtn:SetText("竞价锁单")
    bidAllBtn:SetPoint("LEFT", preyTab2, "RIGHT", 12, 0)
    bidAllBtn:Hide()
    EA_SkinButton(bidAllBtn)

    local function CoinText(amount)
        amount = tonumber(amount) or 0
        local gold = math.floor(amount / 10000)
        local silver = math.floor((amount % 10000) / 100)
        local copper = amount % 100
        local str = ""
        if gold > 0 then str = str .. gold .. "|TInterface\\MoneyFrame\\UI-GoldIcon:14:14:2:0|t" end
        if gold > 0 or silver > 0 then str = str .. silver .. "|TInterface\\MoneyFrame\\UI-SilverIcon:14:14:2:0|t" end
        return str .. copper .. "|TInterface\\MoneyFrame\\UI-CopperIcon:14:14:2:0|t"
    end

    function RefreshPreyRows(tabIdx)
        local container = (tabIdx == 1) and preyScrollChild1 or preyScrollChild2
        container.rows = container.rows or {}
        for _, child in ipairs(container.rows) do child:Hide() end
        local rowsData = {}
        if tabIdx == 1 then
            local snipeList = EasyAuctionDB.SnipeList or {}
            for _, v in ipairs(AuctionBrowseResults) do
                local snipeInfo = snipeList[tonumber(v.itemID)] or snipeList[tostring(v.itemID)]
                if snipeInfo then
                    local maxPrice = snipeInfo.maxPrice or 0
                    local price = v.buyout and v.buyout > 0 and math.floor(v.buyout / (v.count or 1)) or 0
                    if v.buyout and v.buyout > 0 and maxPrice > 0 and price > 0 and price <= maxPrice then
                        table.insert(rowsData, v)
                    end
                end
            end
            if #rowsData == 0 and (EasyAuctionDB.SnipeCheckDisenchant or EasyAuctionDB.SnipeCheckVendor) then
                for _, v in ipairs(AuctionBrowseResults) do
                    local disenchantOK = false
                    if EasyAuctionDB.SnipeCheckDisenchant and ns and ns.GetDisenchantValue then
                        local deValue = ns.GetDisenchantValue(v.itemID) or 0
                        disenchantOK = deValue > 0 and v.buyout and v.buyout > 0 and v.buyout < deValue * (v.count or 1)
                    end
                    local vendorOK = false
                    if EasyAuctionDB.SnipeCheckVendor then
                        local vendorPrice = select(11, GetItemInfo(v.itemID)) or 0
                        vendorOK = vendorPrice > 0 and v.buyout and v.buyout > 0 and v.buyout < vendorPrice * (v.count or 1)
                    end
                    if disenchantOK or vendorOK then table.insert(rowsData, v) end
                end
            end
        else
            local ratio = EasyAuctionDB.BidDiscountRatio or 0.95
            for _, v in ipairs(AuctionBrowseResults) do
                if v.buyout and v.buyout > 0 and v.minBid and v.minBid > 0 and v.highBidder ~= true then
                    local bidUnit = math.floor(v.minBid / (v.count or 1))
                    local buyoutUnit = math.floor(v.buyout / (v.count or 1))
                    if buyoutUnit > 0 and (bidUnit / buyoutUnit) < ratio then
                        table.insert(rowsData, v)
                    end
                end
            end
        end

        local header = container.rows[1]
        if not header then
            header = CreateFrame("Frame", nil, container)
            header:SetSize(320, 20)
            header.bg = header:CreateTexture(nil, "BACKGROUND")
            header.bg:SetAllPoints()
            header.bg:SetColorTexture(0.1, 0.1, 0.15, 0.45)
            header.nameText = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            header.nameText:SetPoint("LEFT", 4, 0)
            header.nameText:SetWidth(70)
            header.nameText:SetJustifyH("LEFT")
            header.nameText:SetFont(header.nameText:GetFont(), 12, "")
            header.countText = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            header.countText:SetPoint("LEFT", header.nameText, "RIGHT", 4, 0)
            header.countText:SetWidth(34)
            header.countText:SetJustifyH("RIGHT")
            header.countText:SetText("数量")
            header.countText:SetFont(header.countText:GetFont(), 12, "")
            header.unitPriceText = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            header.unitPriceText:SetPoint("LEFT", header.countText, "RIGHT", 4, 0)
            header.unitPriceText:SetWidth(80)
            header.unitPriceText:SetJustifyH("RIGHT")
            header.unitPriceText:SetFont(header.unitPriceText:GetFont(), 12, "")
            header.buyoutText = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            header.buyoutText:SetPoint("LEFT", header.unitPriceText, "RIGHT", 4, 0)
            header.buyoutText:SetWidth(80)
            header.buyoutText:SetJustifyH("RIGHT")
            header.buyoutText:SetFont(header.buyoutText:GetFont(), 12, "")
            EA_ApplyRowLines(header, { 84, 38, 88, 88 }, 20)
            container.rows[1] = header
        end
        header.nameText:SetText("名称")
        header.unitPriceText:SetText(tabIdx == 2 and "竞标单价" or "单价")
        header.buyoutText:SetText(tabIdx == 2 and "竞标总价" or "总价")
        header:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
        header:Show()

        for i, v in ipairs(rowsData) do
            local idx = i + 1
            local row = container.rows[idx]
            if not row then
                row = CreateFrame("Button", nil, container)
                row:SetSize(320, 18)
                row.bg = row:CreateTexture(nil, "BACKGROUND")
                row.bg:SetAllPoints()
                row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
                row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                row.nameText:SetFont(row.nameText:GetFont(), 10, "")
                row.nameText:SetPoint("LEFT", 2, 0)
                row.nameText:SetWidth(80)
                row.nameText:SetJustifyH("LEFT")
                row.countText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                row.countText:SetFont(row.countText:GetFont(), 10, "")
                row.countText:SetPoint("LEFT", row.nameText, "RIGHT", 2, 0)
                row.countText:SetWidth(30)
                row.countText:SetJustifyH("RIGHT")
                row.unitPriceText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                row.unitPriceText:SetFont(row.unitPriceText:GetFont(), 10, "")
                row.unitPriceText:SetPoint("LEFT", row.countText, "RIGHT", 2, 0)
                row.unitPriceText:SetWidth(85)
                row.unitPriceText:SetJustifyH("RIGHT")
                row.buyoutText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                row.buyoutText:SetFont(row.buyoutText:GetFont(), 10, "")
                row.buyoutText:SetPoint("LEFT", row.unitPriceText, "RIGHT", 2, 0)
                row.buyoutText:SetWidth(85)
                row.buyoutText:SetJustifyH("RIGHT")
                EA_ApplyRowLines(row, { 84, 34, 89, 89 }, 18)
                container.rows[idx] = row
            end
            local color = ITEM_QUALITY_COLORS[v.quality or 1] or ITEM_QUALITY_COLORS[1]
            row.bg:SetColorTexture(1, 1, 1, (idx % 2 == 0) and 0.05 or 0.10)
            row.nameText:SetText(v.name or "?")
            row.nameText:SetTextColor(color.r, color.g, color.b)
            row.countText:SetText("|cffffff00" .. (v.count or 1) .. "|r")
            if tabIdx == 2 then
                local bidUnit = math.floor(((v.minBid or 0) / ((v.count and v.count > 0) and v.count or 1)) + 0.5)
                row.unitPriceText:SetText(CoinText(bidUnit))
                row.buyoutText:SetText(CoinText(v.minBid or 0))
            else
                local unitPrice = math.floor(((v.buyout or 0) / ((v.count and v.count > 0) and v.count or 1)) + 0.5)
                row.unitPriceText:SetText(CoinText(unitPrice))
                row.buyoutText:SetText(CoinText(v.buyout or 0))
            end
            row:SetScript("OnEnter", function()
                GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
                if v.itemID then GameTooltip:SetItemByID(v.itemID) else GameTooltip:AddLine(v.name or "?") end
                GameTooltip:Show()
                row.bg:SetColorTexture(0.3, 0.6, 1, 0.18)
            end)
            row:SetScript("OnLeave", function()
                GameTooltip:Hide()
                row.bg:SetColorTexture(1, 1, 1, (idx % 2 == 0) and 0.05 or 0.10)
            end)
            row:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -((idx - 1) * 19))
            row:Show()
        end

        for i = #rowsData + 2, #(container.rows or {}) do
            if container.rows[i] then container.rows[i]:Hide() end
        end
        container:SetHeight((#rowsData + 1) * 19)
        if tabIdx == 1 then
            EasyAuction_CurrentPreyRows = rowsData
        else
            EasyAuction_CurrentBidRows = rowsData
        end
    end

    local function ShowPreyTab(idx)
        if idx == 1 then
            preyScroll1:Show()
            preyScroll2:Hide()
            preyTab1:SetText("狙击")
            preyTab2:SetText("竞价")
            EA_SetTextButtonActive(preyTab1, true)
            EA_SetTextButtonActive(preyTab2, false)
            snipeBuyAllBtn:Show()
            bidAllBtn:Hide()
        else
            preyScroll1:Hide()
            preyScroll2:Show()
            preyTab1:SetText("狙击")
            preyTab2:SetText("竞价")
            EA_SetTextButtonActive(preyTab1, false)
            EA_SetTextButtonActive(preyTab2, true)
            snipeBuyAllBtn:Hide()
            bidAllBtn:Show()
        end
    end
    preyTab1:SetScript("OnClick", function() ShowPreyTab(1); RefreshPreyRows(1) end)
    preyTab2:SetScript("OnClick", function() ShowPreyTab(2); RefreshPreyRows(2) end)

    snipeBuyAllBtn:SetScript("OnClick", function()
        for _, v in ipairs(EasyAuction_CurrentPreyRows or {}) do
            if v.index and v.buyout and v.buyout > 0 then
                PlaceAuctionBid("list", v.index, v.buyout)
                print("|cff00ff00[EasyAuction]|r 已提交购买：" .. (v.name or "?"))
                return
            end
        end
        print("|cffff0000[EasyAuction]|r 没有可购买的项目！")
    end)

    bidAllBtn:SetScript("OnClick", function()
        CollectAuctionBrowseResults()
        RefreshPreyRows(2)
        for _, v in ipairs(EasyAuction_CurrentBidRows or {}) do
            if v.index and v.minBid and v.minBid > 0 then
                local _, _, _, _, _, _, _, minBid, minIncrement, _, bid, highBidder, _, _, _, saleStatus =
                    GetAuctionItemInfo("list", v.index)
                if not (highBidder == true or saleStatus == 1) then
                    local bidPrice = (bid and bid > 0) and (bid + (minIncrement or 0)) or minBid
                    if bidPrice and bidPrice > 0 then
                        PlaceAuctionBid("list", v.index, bidPrice)
                        RefreshPreyRows(2)
                        return
                    end
                end
            end
        end
        print("|cffff0000[EasyAuction]|r 没有可竞价的项目！")
    end)
    ShowPreyTab(1)
    RefreshPreyRows(1)

    local function CreateSnipeSettingFrame()
        if EasyAuctionSnipeSettingFrame then return end
        local frame = CreateFrame("Frame", "EasyAuctionSnipeSettingFrame", UIParent, "BackdropTemplate")
        frame:SetSize(520, 460)
        EA_DockRightOfMain(frame, f, 6)
        frame:SetFrameStrata("DIALOG")
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:SetToplevel(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        EA_SkinFrame(frame, "window")

        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 14, -12)
        title:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 16, "")
        title:SetText("狙击设置")
        EA_SkinText(title, "accent")

        local optionPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        optionPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -42)
        optionPanel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -42)
        optionPanel:SetHeight(88)
        EA_SkinPanel(optionPanel, "panel")
        EA_ApplyOutline(optionPanel, 0.75)

        local deLabel = optionPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        deLabel:SetPoint("TOPLEFT", 12, -12)
        deLabel:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
        deLabel:SetText("低于分解价值")
        EA_SkinText(deLabel, "text")
        local cbDisenchant = EA_CreateSwitch(optionPanel, 52)
        cbDisenchant:SetPoint("TOPRIGHT", optionPanel, "TOPRIGHT", -12, -8)
        cbDisenchant:SetCheckedState(EasyAuctionDB.SnipeCheckDisenchant ~= false)
        cbDisenchant:SetScript("OnClick", function(self)
            local checked = not self:GetCheckedState()
            self:SetCheckedState(checked)
            EasyAuctionDB.SnipeCheckDisenchant = checked
            RefreshPreyRows(1)
        end)

        local vendorLabel = optionPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        vendorLabel:SetPoint("TOPLEFT", deLabel, "BOTTOMLEFT", 0, -16)
        vendorLabel:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
        vendorLabel:SetText("低于卖店价")
        EA_SkinText(vendorLabel, "text")
        local cbVendor = EA_CreateSwitch(optionPanel, 52)
        cbVendor:SetPoint("TOPRIGHT", cbDisenchant, "BOTTOMRIGHT", 0, -10)
        cbVendor:SetCheckedState(EasyAuctionDB.SnipeCheckVendor ~= false)
        cbVendor:SetScript("OnClick", function(self)
            local checked = not self:GetCheckedState()
            self:SetCheckedState(checked)
            EasyAuctionDB.SnipeCheckVendor = checked
            RefreshPreyRows(1)
        end)

        local ratioLabel = optionPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        ratioLabel:SetPoint("TOPLEFT", vendorLabel, "BOTTOMLEFT", 0, -16)
        ratioLabel:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
        ratioLabel:SetText("竞拍价低于一口价的比例：")
        EA_SkinText(ratioLabel, "text")

        local ratioEdit = CreateNumericBox(optionPanel, 40)
        ratioEdit:SetPoint("LEFT", ratioLabel, "RIGHT", 8, 0)
        ratioEdit:SetNumber((EasyAuctionDB.BidDiscountRatio or 0.95) * 100)
        ratioEdit:SetScript("OnTextChanged", function(self)
            local v = tonumber(self:GetText()) or 95
            if v < 1 then v = 1 elseif v > 100 then v = 100 end
            EasyAuctionDB.BidDiscountRatio = v / 100
            RefreshPreyRows(2)
        end)

        local listLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        listLabel:SetPoint("TOPLEFT", optionPanel, "BOTTOMLEFT", 0, -12)
        listLabel:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 13, "")
        listLabel:SetText("狙击物品列表（设置最高单价）")
        EA_SkinText(listLabel, "accent")

        local listPanel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        listPanel:SetPoint("TOPLEFT", listLabel, "BOTTOMLEFT", 0, -8)
        listPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -32, 44)
        EA_SkinPanel(listPanel, "panel")
        EA_ApplyOutline(listPanel, 0.8)
        local scroll = CreateFrame("ScrollFrame", nil, listPanel, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 0, 0)
        scroll:SetPoint("BOTTOMRIGHT", listPanel, "BOTTOMRIGHT", -22, 0)
        local scrollChild = CreateFrame("Frame", nil, scroll)
        local SNIPE_SETTING_ROW_WIDTH = 452
        local SNIPE_SETTING_ROW_HEIGHT = 30
        local SNIPE_SETTING_COL_NAME = 206
        local SNIPE_SETTING_COL_LABEL = 106
        local SNIPE_SETTING_COL_MONEY = 46
        local SNIPE_SETTING_COLS = {
            SNIPE_SETTING_COL_NAME,
            SNIPE_SETTING_COL_LABEL,
            SNIPE_SETTING_COL_MONEY,
            SNIPE_SETTING_COL_MONEY,
            SNIPE_SETTING_COL_MONEY,
        }
        local SNIPE_SETTING_PRICE_X = SNIPE_SETTING_COL_NAME + SNIPE_SETTING_COL_LABEL
        scrollChild:SetWidth(SNIPE_SETTING_ROW_WIDTH)
        scroll:SetScrollChild(scrollChild)
        local settingRows = {}

        local function RefreshSnipeSettingRows()
            for _, row in ipairs(settingRows) do row:Hide() end
            EasyAuctionDB.SnipeList = EasyAuctionDB.SnipeList or {}
            local entries = {}
            for itemID, info in pairs(EasyAuctionDB.SnipeList) do
                table.insert(entries, { itemID = itemID, info = info })
            end
            table.sort(entries, function(a, b) return (a.info.time or 0) > (b.info.time or 0) end)
            for idx, entry in ipairs(entries) do
                local row = settingRows[idx]
                if not row then
                    row = CreateFrame("Button", nil, scrollChild)
                    row:SetSize(SNIPE_SETTING_ROW_WIDTH, SNIPE_SETTING_ROW_HEIGHT)
                    row.bg = row:CreateTexture(nil, "BACKGROUND")
                    row.bg:SetAllPoints()
                    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    row.name:SetPoint("LEFT", row, "LEFT", 12, 0)
                    row.name:SetWidth(SNIPE_SETTING_COL_NAME - 24)
                    row.name:SetJustifyH("LEFT")
                    row.name:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
                    row.priceLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    row.priceLabel:SetPoint("LEFT", row, "LEFT", SNIPE_SETTING_COL_NAME + 10, 0)
                    row.priceLabel:SetWidth(SNIPE_SETTING_COL_LABEL - 18)
                    row.priceLabel:SetJustifyH("LEFT")
                    row.priceLabel:SetText("最高单价：")
                    EA_SkinText(row.priceLabel, "accent")
                    row.priceGold = CreateNumericBox(row, 30)
                    row.priceGold:SetPoint("LEFT", row, "LEFT", SNIPE_SETTING_PRICE_X + 5, 0)
                    row.priceGold:SetJustifyH("RIGHT")
                    row.goldIcon = row:CreateTexture(nil, "ARTWORK")
                    row.goldIcon:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
                    row.goldIcon:SetSize(12, 12)
                    row.goldIcon:SetPoint("LEFT", row.priceGold, "RIGHT", 2, 0)
                    row.priceSilver = CreateNumericBox(row, 24)
                    row.priceSilver:SetMaxLetters(2)
                    row.priceSilver:SetPoint("LEFT", row, "LEFT", SNIPE_SETTING_PRICE_X + SNIPE_SETTING_COL_MONEY + 7, 0)
                    row.priceSilver:SetJustifyH("RIGHT")
                    row.silverIcon = row:CreateTexture(nil, "ARTWORK")
                    row.silverIcon:SetTexture("Interface\\MoneyFrame\\UI-SilverIcon")
                    row.silverIcon:SetSize(12, 12)
                    row.silverIcon:SetPoint("LEFT", row.priceSilver, "RIGHT", 2, 0)
                    row.priceCopper = CreateNumericBox(row, 24)
                    row.priceCopper:SetMaxLetters(2)
                    row.priceCopper:SetPoint("LEFT", row, "LEFT", SNIPE_SETTING_PRICE_X + SNIPE_SETTING_COL_MONEY * 2 + 7, 0)
                    row.priceCopper:SetJustifyH("RIGHT")
                    row.copperIcon = row:CreateTexture(nil, "ARTWORK")
                    row.copperIcon:SetTexture("Interface\\MoneyFrame\\UI-CopperIcon")
                    row.copperIcon:SetSize(12, 12)
                    row.copperIcon:SetPoint("LEFT", row.priceCopper, "RIGHT", 2, 0)
                    EA_ApplyRowLines(row, SNIPE_SETTING_COLS, SNIPE_SETTING_ROW_HEIGHT)
                    settingRows[idx] = row
                end

                local itemID = entry.itemID
                local info = entry.info
                local maxPrice = info.maxPrice or 0
                local g = math.floor(maxPrice / 10000)
                local s = math.floor((maxPrice % 10000) / 100)
                local c = maxPrice % 100
                row:SetSize(SNIPE_SETTING_ROW_WIDTH, SNIPE_SETTING_ROW_HEIGHT)
                row.bg:SetAllPoints()
                EA_RowColor(row.bg, idx, false)
                row.name:SetText(GetItemInfo(itemID) or info.name or ("ID:" .. tostring(itemID)))
                row.priceGold:SetScript("OnTextChanged", nil)
                row.priceSilver:SetScript("OnTextChanged", nil)
                row.priceCopper:SetScript("OnTextChanged", nil)
                row.priceGold:SetNumber(g)
                row.priceSilver:SetNumber(s)
                row.priceCopper:SetNumber(c)
                local function UpdateMaxPrice()
                    local gold = math.min(tonumber(row.priceGold:GetText()) or 0, 999999)
                    local silver = math.min(tonumber(row.priceSilver:GetText()) or 0, 99)
                    local copper = math.min(tonumber(row.priceCopper:GetText()) or 0, 99)
                    EasyAuctionDB.SnipeList[itemID] = EasyAuctionDB.SnipeList[itemID] or info
                    EasyAuctionDB.SnipeList[itemID].maxPrice = gold * 10000 + silver * 100 + copper
                    RefreshSnipeRows()
                    RefreshPreyRows(1)
                end
                row.priceGold:SetScript("OnTextChanged", UpdateMaxPrice)
                row.priceSilver:SetScript("OnTextChanged", UpdateMaxPrice)
                row.priceCopper:SetScript("OnTextChanged", UpdateMaxPrice)
                row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(idx - 1) * SNIPE_SETTING_ROW_HEIGHT)
                row:Show()
            end
            scrollChild:SetHeight(math.max(#entries * SNIPE_SETTING_ROW_HEIGHT, 1))
        end

        frame.RefreshSnipeSettingRows = RefreshSnipeSettingRows
        local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
        EA_SkinCloseButton(closeBtn)
        EasyAuctionSnipeSettingFrame = frame
        frame:Hide()
    end

    local snipeSettingBtn = CreateFrame("Button", nil, tabSnipePage, "UIPanelButtonTemplate")
    snipeSettingBtn:SetSize(70, 22)
    snipeSettingBtn:SetText("狙击设置")
    snipeSettingBtn:SetPoint("TOPRIGHT", tabSnipePage, "TOPRIGHT", -10, -8)
    EA_SkinButton(snipeSettingBtn)
    snipeSettingBtn:SetScript("OnClick", function()
        if EasyAuctionSnipeSettingFrame and EasyAuctionSnipeSettingFrame:IsShown() then
            EasyAuctionSnipeSettingFrame:Hide()
            return
        end
        if not EasyAuctionSnipeSettingFrame then
            CreateSnipeSettingFrame()
        end
        EA_DockRightOfMain(EasyAuctionSnipeSettingFrame, f, 6)
        EasyAuctionSnipeSettingFrame:Show()
        EasyAuctionSnipeSettingFrame.RefreshSnipeSettingRows()
    end)

    local showMyBidListBtn = CreateFrame("Button", nil, tabSnipePage, "UIPanelButtonTemplate")
    showMyBidListBtn:SetSize(70, 22)
    showMyBidListBtn:SetText("竞价列表")
    showMyBidListBtn:SetPoint("TOPRIGHT", snipeSettingBtn, "BOTTOMRIGHT", 0, -4)
    EA_SkinButton(showMyBidListBtn)
    showMyBidListBtn:SetScript("OnClick", function()
        ShowMyBidListFrame()
    end)
    showMyBidListBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("查看你当前参与竞标的所有拍卖", 1, 1, 1)
        GameTooltip:Show()
    end)
    showMyBidListBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local activeTabIndex
    local tabNames = { "闪购", "闪卖", "狙击" }
    local flashSellItemSize = 40
    local flashBuyItemSize = 40
    local function RaiseFlashBuyItemVisuals()
        local itemButton = _G["EasyAuctionItemButton"]
        if itemButton then
            itemButton:SetAlpha(1)
            itemButton:Show()
            if itemButton.Raise then itemButton:Raise() end
        end
        if f.ItemNameBtn then
            f.ItemNameBtn:SetAlpha(1)
            f.ItemNameBtn:Show()
            if f.ItemNameBtn.Raise then f.ItemNameBtn:Raise() end
        end
        if f.ItemName then
            f.ItemName:SetAlpha(1)
            f.ItemName:Show()
            if f.ItemName.SetDrawLayer then
                f.ItemName:SetDrawLayer("OVERLAY", 7)
            end
        end
    end
    f.__EARaiseFlashBuyItemVisuals = RaiseFlashBuyItemVisuals

    local function SyncFlashSellItemControls()
        local itemButton = _G["EasyAuctionItemButton"]
        if not (itemButton and f.ItemNameBtn) then return end
        local shown = activeTabIndex ~= 3
        local detailParent = f.FlashBuyDetailPanel or contentFrame
        itemButton:ClearAllPoints()
        f.ItemNameBtn:ClearAllPoints()
        if activeTabIndex == 1 or not activeTabIndex then
            itemButton:SetParent(detailParent)
            f.ItemNameBtn:SetParent(detailParent)
            itemButton:SetSize(flashBuyItemSize, flashBuyItemSize)
            itemButton:SetFrameLevel((detailParent:GetFrameLevel() or 1) + 5)
            f.ItemNameBtn:SetFrameLevel((detailParent:GetFrameLevel() or 1) + 6)
            itemButton:SetPoint("TOPLEFT", detailParent, "TOPLEFT", 10, -10)
            f.ItemNameBtn:SetPoint("TOPLEFT", itemButton, "TOPRIGHT", 8, -1)
            f.ItemNameBtn:SetPoint("RIGHT", detailParent, "RIGHT", -154, 0)
        else
            local sellParent = f.EAFlashSellPanel or contentFrame
            itemButton:SetParent(sellParent)
            f.ItemNameBtn:SetParent(sellParent)
            itemButton:SetSize(flashSellItemSize, flashSellItemSize)
            itemButton:SetFrameLevel((sellParent:GetFrameLevel() or 1) + 5)
            f.ItemNameBtn:SetFrameLevel((sellParent:GetFrameLevel() or 1) + 6)
            itemButton:SetPoint("TOPLEFT", sellParent, "TOPLEFT", 26, -30)
            f.ItemNameBtn:SetPoint("TOPLEFT", sellParent, "TOPLEFT", 90, -8)
            f.ItemNameBtn:SetPoint("RIGHT", sellParent, "RIGHT", -12, 0)
        end
        FixItemButtonIconSize(itemButton, itemButton:GetWidth() or (activeTabIndex == 2 and flashSellItemSize or flashBuyItemSize))
        itemButton:SetShown(shown)
        f.ItemNameBtn:SetShown(shown)
        if shown then
            RaiseFlashBuyItemVisuals()
        end
    end
    local LayoutAuctionSide

    local function SetTabSelected(idx)
        activeTabIndex = idx
        EasyAuctionDB.LastActiveTab = idx
        for i, tab in ipairs({ tab1, tab2, tab3 }) do
            if i == idx then
                EA_SetTextButtonActive(tab, true)
                if tab2 and i == 2 then
                    ClearAuctionVirtualItem()
                end
            else
                EA_SetTextButtonActive(tab, false)
                if i == 1 then
                    local ItemButton = _G["EasyAuctionItemButton"]
                    if (not ItemButton) or (not ItemButton.itemID) then
                        if type(EasyAuction_UpdateInlineDistribution) == "function" then
                            EasyAuction_UpdateInlineDistribution(nil, nil)
                            UpdateTrendFrame(nil)
                        end
                    end
                end
            end
        end
        tabFlashSellPage:Hide()
        tabOtherPage:Hide()
        tabSnipePage:Hide()
        if idx == 1 then
            tabFlashSellPage:Show()
        elseif idx == 2 then
            tabOtherPage:Show()
        elseif idx == 3 then
            tabSnipePage:Show()
            CollectAuctionBrowseResults()
            RefreshSnipeRows()
            RefreshPreyRows(preyScroll2:IsShown() and 2 or 1)
            ClearAuctionVirtualItem()
        end
        SyncFlashSellItemControls()
        if LayoutAuctionSide then
            LayoutAuctionSide()
        end
        if f.__EARefreshHeader then
            f.__EARefreshHeader()
        end
    end

    tab1:SetScript("OnClick", function() SetTabSelected(1) end)
    tab2:SetScript("OnClick", function() SetTabSelected(2) end)
    tab3:SetScript("OnClick", function() SetTabSelected(3) end)

    local sellPanelsParent = CreateFrame("Frame", nil, tabOtherPage)
    sellPanelsParent:SetAllPoints(tabOtherPage)

    local fastFrame = CreateFrame("Frame", nil, sellPanelsParent, "BackdropTemplate")
    fastFrame:SetSize(338, 150)
    fastFrame:SetPoint("TOPLEFT", sellPanelsParent, "TOPLEFT", 0, 0)
    EA_SkinPanel(fastFrame, "panel")
    f.EAFlashSellPanel = fastFrame

    local footerBtnWidth, footerBtnHeight, footerBtnGap = 42, 22, 4

    local openCfgBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    openCfgBtn:SetSize(38, footerBtnHeight)
    openCfgBtn:SetText("设置")
    openCfgBtn:SetPoint("RIGHT", footer, "RIGHT", 0, 0)
    local ofontString = openCfgBtn:GetFontString()
    if ofontString then
        ofontString:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 14, "")
    end
    EA_SkinButton(openCfgBtn)
    f.EAConfigBtn = openCfgBtn
    openCfgBtn:SetScript("OnClick", function()
        if type(_G.EasyAuction_ToggleConfigFrame) == "function" then
            _G.EasyAuction_ToggleConfigFrame(f)
            return
        end
        if EasyAuctionConfigFrame and EasyAuctionConfigFrame:IsShown() then
            EasyAuctionConfigFrame:Hide()
            return
        end
        if not EasyAuctionConfigFrame then
            CreateEasyAuctionConfigFrame(f)
        end
        EasyAuctionConfigFrame:ClearAllPoints()
        EasyAuctionConfigFrame:SetPoint("TOPLEFT", f, "TOPRIGHT", 6, 0)
        EA_RaiseUtilityFrame(EasyAuctionConfigFrame, f)
        EasyAuctionConfigFrame:Show()
    end)

    local lockBtn = EA_CreateAuctionIconButton("EasyAuctionLockButton", f,
        "Interface\\BUTTONS\\LockButton-Locked-Up.blp", "锁定 EasyAuction", "点击切换侧边面板是否固定在拍卖行右侧。")
    f.EALockBtn = lockBtn
    lockBtn:Hide()
    local mainThemeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    mainThemeBtn:SetSize(52, footerBtnHeight)
    mainThemeBtn:SetPoint("RIGHT", openCfgBtn, "LEFT", -footerBtnGap, 0)
    EA_SkinButton(mainThemeBtn)
    EA_SetThemeDropdownButton(mainThemeBtn, true)
    mainThemeBtn:Hide()

    lockBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        if EasyAuctionDB.locked then
            GameTooltip:AddLine("已锁定", 1, 1, 1, true)
            GameTooltip:AddLine("点击解锁后可拖动 EasyAuction 面板。", 1, 0.82, 0, true)
        else
            GameTooltip:AddLine("已解锁", 1, 1, 1, true)
            GameTooltip:AddLine("点击锁定并复位到拍卖行右侧。", 1, 0.82, 0, true)
        end
        GameTooltip:Show()
    end)
    lockBtn:SetScript("OnLeave", GameTooltip_Hide)
    lockBtn:SetScript("OnClick", function()
        EasyAuctionDB.locked = not EasyAuctionDB.locked
        UpdateLockState()
    end)


    local historyBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    EA_SetFooterButton(historyBtn, footerBtnWidth, footerBtnHeight)
    historyBtn:SetText("价格库")
    local historyBtnfont = historyBtn:GetFontString()
    if historyBtnfont then
        historyBtnfont:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 14, "")
    end
    EA_SkinButton(historyBtn)
    f.EAHistoryBtn = historyBtn
    historyBtn:SetPoint("RIGHT", openCfgBtn, "LEFT", -footerBtnGap, 0)
    historyBtn:SetScript("OnClick", function()
        if EasyAuctionDBFrame and EasyAuctionDBFrame:IsShown() then
            EasyAuctionDBFrame:Hide()
            return
        end
        if EasyAuctionDBFrame then
            EasyAuction_OpenDBFrame()
        end
    end)
    historyBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("打开拍卖价格数据库", 1, 1, 1)
        GameTooltip:Show()
    end)
    historyBtn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    local scanBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    EA_SetFooterButton(scanBtn, footerBtnWidth, footerBtnHeight)
    scanBtnfont = scanBtn:GetFontString()
    if scanBtnfont then
        scanBtnfont:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 14, "")
    end
    EA_SkinButton(scanBtn)
    EA_SetProminentButton(scanBtn, "accent")
    f.EAScanBtn = scanBtn
    scanBtn:SetPoint("RIGHT", historyBtn, "LEFT", -footerBtnGap, 0)
    scanBtn:SetScript("OnClick", function()
        if type(EasyAuction_ShowScanModeSelector) == "function" then
            EasyAuction_ShowScanModeSelector()
        else
            StaticPopup_Show("EASYAUCTION_SCANALL_CONFIRM")
        end
        UpdateScanBtnState()
        UpdateAuctionQueryStatusText()
    end)
    scanBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("选择扫描方式", 1, 1, 1)
        GameTooltip:AddLine("支持全量扫描和分类扫描", 0.9, 0.9, 0.9)
        GameTooltip:Show()
    end)
    scanBtn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    local function UpdateLockBtnVisual()
        local icon
        if EasyAuctionDB.locked then
            icon = "Interface\\BUTTONS\\LockButton-Locked-Up.blp"
        else
            icon = "Interface\\BUTTONS\\LockButton-Unlocked-Up.blp"
        end
        lockBtn.icon:SetTexture(icon)
        lockBtn:SetHighlightTexture(icon)
    end

    local function SaveCustomPosition()
        if not f then return end
        local point, relativeTo, relativePoint, x, y = f:GetPoint()
        EasyAuctionDB.customPos = {
            point = point,
            relativeTo = relativeTo and relativeTo:GetName() or "UIParent",
            relativePoint =
                relativePoint,
            x = x,
            y = y
        }
    end

    local function RestoreCustomPosition()
        if not f then return end
        local pos = EasyAuctionDB.customPos
        if pos and not EasyAuctionDB.locked then
            f:ClearAllPoints()
            f:SetPoint(pos.point or "TOPLEFT", pos.relativeTo or "UIParent", pos.relativePoint or "TOPLEFT", pos.x or 0,
                pos.y or 0)
        end
    end

    function UpdateLockState()
        UpdateLockBtnVisual()
        if EasyAuction_LayoutMainHeaderButtons then
            EasyAuction_LayoutMainHeaderButtons()
        end
        if EasyAuctionDB.locked then
            f:SetMovable(false)
            f:EnableMouse(false)
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", AuctionFrame, "TOPRIGHT", 0, -10)
        else
            f:SetMovable(true)
            f:EnableMouse(true)
            RestoreCustomPosition()
        end
    end

    function UpdateScanBtnState()
        if not scanBtn then return end
        if IsScanningAll or IsScanningCategory then
            scanBtn:SetText("扫描中")
            scanBtn:SetEnabled(false)
            return
        end
        local canQuery, canQueryAll = CanSendAuctionQuery()
        scanBtn:SetText("扫描")
        scanBtn:SetEnabled(canQuery or canQueryAll)
        EA_SetProminentButton(scanBtn, "accent")
    end

    UpdateScanBtnState()
    scanBtn:HookScript("OnEnter", function(self)
        if not self:IsEnabled() then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("当前拍卖行扫描不可用", 1, 0.82, 0)
            GameTooltip:AddLine("请稍后再试，或返回可进行全量扫描的区域。", 1, 1, 1)
            GameTooltip:Show()
        end
    end)
    scanBtn:HookScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    local scanBtnTicker
    if scanBtnTicker then
        scanBtnTicker:Cancel()
    end
    scanBtnTicker = C_Timer.NewTicker(0.5, function()
        UpdateScanBtnState()
        UpdateAuctionQueryStatusText()
    end)

    local inventoryBtn = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    EA_SetFooterButton(inventoryBtn, footerBtnWidth, footerBtnHeight)
    inventoryBtn:SetText("库存")
    inventoryBtn:SetPoint("RIGHT", scanBtn, "LEFT", -footerBtnGap, 0)
    local ifontString = inventoryBtn:GetFontString()
    if ifontString then
        ifontString:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 14, "")
    end
    EA_SkinButton(inventoryBtn)
    f.EAInventoryBtn = inventoryBtn

    local function RefreshInventoryToggleBtn()
        local shown = EasyAuctionDB.showSections and EasyAuctionDB.showSections.items == true
            and itemsFrame and itemsFrame:IsShown()
        EA_SetTextButtonActive(inventoryBtn, shown)
    end

    inventoryBtn:SetScript("OnClick", function()
        if itemsFrame then
            EasyAuctionDB.showSections = EasyAuctionDB.showSections or {}
            local show = not (EasyAuctionDB.showSections.items == true and itemsFrame:IsShown())
            EasyAuctionDB.showSections.items = show
            EA_DockRightOfMain(itemsFrame, f, 6)
            itemsFrame:SetShown(show)
            if show and type(itemsFrame.RefreshBagItemFrame) == "function" then
                itemsFrame:RefreshBagItemFrame()
            end
            if LayoutAuctionSide then
                LayoutAuctionSide()
            end
            RefreshInventoryToggleBtn()
        end
    end)
    inventoryBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("查看待售库存", 1, 1, 1)
        GameTooltip:AddLine("显示背包中可拍卖物品", 0.9, 0.9, 0.9)
        GameTooltip:Show()
    end)
    inventoryBtn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    local myAuctionToggleBtn = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    EA_SetFooterButton(myAuctionToggleBtn, footerBtnWidth, footerBtnHeight)
    myAuctionToggleBtn:SetText("在售")
    myAuctionToggleBtn:SetPoint("RIGHT", inventoryBtn, "LEFT", -footerBtnGap, 0)
    EA_SkinButton(myAuctionToggleBtn)
    f.EAMyAuctionBtn = myAuctionToggleBtn

    local function RefreshMyAuctionToggleBtn()
        local shown = EasyAuctionDB.showSections and EasyAuctionDB.showSections.myauct ~= false
        EA_SetTextButtonActive(myAuctionToggleBtn, shown)
    end

    myAuctionToggleBtn:SetScript("OnClick", function()
        EasyAuctionDB.showSections = EasyAuctionDB.showSections or {}
        local val = not (EasyAuctionDB.showSections.myauct ~= false)
        EasyAuctionDB.showSections.myauct = val
        if f.MyAuctionListFrame then
            f.MyAuctionListFrame:SetShown(val)
            if val and f.RefreshMyAuctionList then
                f:RefreshMyAuctionList()
            end
        end
        RefreshMyAuctionToggleBtn()
        if LayoutAuctionSide then
            LayoutAuctionSide()
        end
    end)
    myAuctionToggleBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("查看在售列表", 1, 1, 1)
        GameTooltip:AddLine("开启或关闭右侧在售拍卖窗口。", 0.9, 0.9, 0.9)
        GameTooltip:Show()
    end)
    myAuctionToggleBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local minimalToggleBtn = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    EA_SetFooterButton(minimalToggleBtn, footerBtnWidth, footerBtnHeight)
    minimalToggleBtn:SetPoint("RIGHT", myAuctionToggleBtn, "LEFT", -footerBtnGap, 0)
    local fontString = minimalToggleBtn:GetFontString()
    if fontString then
        fontString:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 14, "")
    end
    EA_SkinButton(minimalToggleBtn)

    local function IsMinimalAddonMode()
        if type(EasyAuction_IsMinimalModeActive) == "function" then
            return EasyAuction_IsMinimalModeActive()
        end
        local playerName = UnitName("player")
        for i = 1, C_AddOns.GetNumAddOns() do
            local name = C_AddOns.GetAddOnInfo(i)
            if name and name ~= addonName and not name:find("^Blizzard_") then
                if (EA_GetAddonEnableState(name, playerName) or 0) > 0 then
                    return false
                end
            end
        end
        return true
    end

    function RefreshMinimalToggleBtn()
        if IsMinimalAddonMode() then
            minimalToggleBtn:SetText("恢复")
            minimalToggleBtn:SetEnabled(true)
            minimalToggleBtn:SetAlpha(1.0)
            EA_SetMinimalButtonMark(minimalToggleBtn, true)
            minimalToggleBtn.tooltipText =
                "恢复插件加载时的所有插件启用状态。\n\n" ..
                "如遇拍卖行报错，可先用极简配置排查插件冲突。"
        else
            minimalToggleBtn:SetText("极简")
            minimalToggleBtn:SetEnabled(true)
            minimalToggleBtn:SetAlpha(1.0)
            EA_SetMinimalButtonMark(minimalToggleBtn, false)
            minimalToggleBtn.tooltipText =
                "禁用除EasyAuction以外的所有插件。\n\n" ..
                "用于排查拍卖行界面出错或卡顿（常因其他插件冲突导致）。\n\n" ..
                "|cff00ff00使用极简模式后，可随时点击“恢复配置”恢复原有插件状态。|r\n\n" ..
                "如恢复配置后仍有报错，可联系作者反馈。"
        end
    end

    minimalToggleBtn:SetScript("OnClick", function()
        if IsMinimalAddonMode() then
            StaticPopupDialogs["EASYAUCTION_RESTORE_CONFIRM"] = {
                text = "将恢复插件加载时的所有插件状态。\n\n确定继续？",
                button1 = "确定",
                button2 = "取消",
                OnAccept = function()
                    EasyAuction_RestoreAddon()
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3,
            }
            StaticPopup_Show("EASYAUCTION_RESTORE_CONFIRM")
        else
            StaticPopupDialogs["EASYAUCTION_MINIMAL_CONFIRM"] = {
                text = "将禁用除 EasyAuction 以外的所有插件。\n\n确定继续？",
                button1 = "确定",
                button2 = "取消",
                OnAccept = function()
                    EasyAuction_SetMinimalAddon()
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3,
            }
            StaticPopup_Show("EASYAUCTION_MINIMAL_CONFIRM")
        end
    end)
    minimalToggleBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.tooltipText or "")
        GameTooltip:Show()
    end)
    minimalToggleBtn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    local opHistoryBtn = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    EA_SetFooterButton(opHistoryBtn, footerBtnWidth, footerBtnHeight)
    opHistoryBtn:SetText("历史")
    opHistoryBtn:SetPoint("RIGHT", minimalToggleBtn, "LEFT", -footerBtnGap, 0)
    EA_SkinButton(opHistoryBtn)
    opHistoryBtn:SetScript("OnClick", function()
        EasyAuction_ShowOperationHistory()
    end)
    opHistoryBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("查看每次购买/拍卖记录", 1, 1, 1)
        GameTooltip:Show()
    end)
    opHistoryBtn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    RefreshMinimalToggleBtn()
    RefreshMyAuctionToggleBtn()

    function UpdateAuctionQueryStatusText()
    end

    local itemControlParent = f.FlashBuyDetailPanel or contentFrame
    local ItemButton = CreateFrame("Button", "EasyAuctionItemButton", itemControlParent, "ItemButtonTemplate")
    ItemButton:SetSize(40, 40)
    ItemButton:SetFrameLevel((itemControlParent:GetFrameLevel() or 1) + 5)
    ItemButton:SetPoint("TOPLEFT", itemControlParent, "TOPLEFT", 10, -10)
    SetItemButtonTexture(ItemButton, "")
    SetItemButtonCount(ItemButton, 0)
    SetItemButtonQuality(ItemButton, nil)

    ItemButton:SetScript("OnEnter", function(self)
        if self.itemID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(self.itemID)
            GameTooltip:Show()
        end
    end)
    ItemButton:SetScript("OnLeave", GameTooltip_Hide)
    ItemButton:SetScript("OnReceiveDrag", function(self)
        if CursorHasItem() then
            ClickAuctionSellItemButton()
            ClearCursor()
            FixItemButtonIconSize(self, self:GetWidth() or flashBuyItemSize)
        end
    end)
    ItemButton:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and CursorHasItem() then
            ClickAuctionSellItemButton()
            ClearCursor()
            FixItemButtonIconSize(self, self:GetWidth() or flashBuyItemSize)
        elseif button == "RightButton" then
            self.itemID = nil
            SetItemButtonTexture(self, "")
            SetItemButtonCount(self, 0)
            SetItemButtonQuality(self, nil)
            FixItemButtonIconSize(self, self:GetWidth() or flashBuyItemSize)
            if f.ItemName then f.ItemName:SetText("") end
            f.UnitGold:SetNumber(0)
            f.UnitSilver:SetNumber(0)
            f.UnitCopper:SetNumber(0)
            f.StackGold:SetNumber(0)
            f.StackSilver:SetNumber(0)
            f.StackCopper:SetNumber(0)
            f.StackCount:SetNumber(1)
            f.NumStacks:SetNumber(1)
            if EasyAuction_UpdateInlineDistribution then
                EasyAuction_UpdateInlineDistribution(nil, nil)
                UpdateTrendFrame(nil)
            end
            RefreshMinPriceLines()
            -- 取消所有按钮高亮
            if _G.EA_ItemButtons and type(_G.EA_ItemButtons) == "table" then
                for _, b in ipairs(_G.EA_ItemButtons) do
                    if b.selectedBorder then b.selectedBorder:Hide() end
                end
            end
            AuctionBar._EA_SelectedItemID = nil
            if f.__EARefreshHeader then
                f.__EARefreshHeader()
            end
        end
    end)

    local itemNameBtn = CreateFrame("Button", nil, itemControlParent)
    itemNameBtn:SetFrameLevel((itemControlParent:GetFrameLevel() or 1) + 6)
    itemNameBtn:SetPoint("TOPLEFT", ItemButton, "TOPRIGHT", 8, -1)
    itemNameBtn:SetPoint("RIGHT", itemControlParent, "RIGHT", -154, 0)
    itemNameBtn:SetHeight(20)
    itemNameBtn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    f.ItemNameBtn = itemNameBtn
    SyncFlashSellItemControls()

    local itemName = itemNameBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    itemName:SetPoint("LEFT")
    itemName:SetJustifyH("LEFT")
    itemName:SetAllPoints(itemNameBtn)
    itemNameBtn:SetFontString(itemName)
    itemName:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 16, "")
    if itemName.SetDrawLayer then
        itemName:SetDrawLayer("OVERLAY", 7)
    end
    f.ItemName = itemName

    itemNameBtn:SetScript("OnClick", function()
        local name = itemName:GetText() or ""
        if name ~= "" then
            if not (name:sub(1, 1) == "\"" and name:sub(-1) == "\"") then
                name = "\"" .. name .. "\""
            end
            EasyAuction_ShowCopyBox(name, itemNameBtn)
        end
    end)

    itemNameBtn:SetScript("OnEnter", function(self)
        if (itemName:GetText() or "") ~= "" then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("点击复制物品名称", 1, 1, 1)
            GameTooltip:AddLine("弹窗可Ctrl+C复制", 0.9, 0.9, 0.9)
            GameTooltip:Show()
        end
    end)
    itemNameBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    f.SetItemNameForCopy = function(self, text)
        itemName:SetText(text or "")
        if text and text ~= "" then
            itemNameBtn:Show()
        else
            itemNameBtn:Hide()
        end
        if self.__EARefreshHeader then
            self.__EARefreshHeader()
        end
    end

    f.__EARefreshHeader = function()
        if not (f.EAHeaderHeadline and f.EAHeaderHint) then return end
        local function FormatGoldOnly(copper)
            copper = tonumber(copper) or 0
            local sign = ""
            if copper < 0 then
                sign = "-"
                copper = -copper
            end
            local gold = math.floor(copper / 10000)
            return sign .. gold .. "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:1:0|t"
        end
        local function FormatDeltaMoney(copper)
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
        local db = EasyAuction_RebindFrameDB() or EasyAuctionDB
        if db then
            local today = date("%Y-%m-%d")
            local money = type(GetMoney) == "function" and GetMoney() or (db.playerGoldToday or 0)
            if db.playerGoldDay ~= today then
                db.playerGoldYesterday = tonumber(db.playerGoldToday) or money
                db.playerGoldDay = today
            end
            db.playerGoldToday = money
            local yesterday = tonumber(db.playerGoldYesterday) or money
            local delta = money - yesterday
            f.EAHeaderHeadline:SetText(FormatGoldOnly(money))
            local deltaText
            if delta == 0 then
                deltaText = "较昨日：无变化"
            else
                deltaText = "较昨日：" .. FormatDeltaMoney(delta)
            end
            f.EAHeaderHint:SetText(deltaText)
            if EAStyle then
                local r, g, b = EAStyle:ColorTrend(delta)
                f.EAHeaderHint:SetTextColor(r, g, b)
            end
            if type(EasyAuction_SaveGoldRecord) == "function" then
                local now = time()
                if not f.lastGoldSaveTime or now - f.lastGoldSaveTime > 60 then
                    EasyAuction_SaveGoldRecord()
                    f.lastGoldSaveTime = now
                end
            end
        end
    end

    local function AddMoneyEdit(parent, anchor, label, y, prefix)
        local labelFS = fastFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        labelFS:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, y)
        labelFS:SetText(label)
        labelFS:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
        EA_SkinText(labelFS, "muted")

        local editGold = CreateNumericBox(fastFrame, 55)
        editGold:SetPoint("LEFT", labelFS, "RIGHT", 4, 0)
        editGold:SetJustifyH("RIGHT")
        local iconGold = fastFrame:CreateTexture(nil, "ARTWORK")
        iconGold:SetTexture("Interface\\MoneyFrame\\UI-GoldIcon")
        iconGold:SetSize(12, 12)
        iconGold:SetPoint("LEFT", editGold, "RIGHT", 2, 0)
        editGold.__EAIcon = iconGold

        local editSilver = CreateNumericBox(fastFrame, 35)
        editSilver:SetPoint("LEFT", iconGold, "RIGHT", 2, 0)
        editSilver:SetJustifyH("RIGHT")
        local iconSilver = fastFrame:CreateTexture(nil, "ARTWORK")
        iconSilver:SetTexture("Interface\\MoneyFrame\\UI-SilverIcon")
        iconSilver:SetSize(12, 12)
        iconSilver:SetPoint("LEFT", editSilver, "RIGHT", 2, 0)
        editSilver.__EAIcon = iconSilver

        local editCopper = CreateNumericBox(fastFrame, 35)
        editCopper:SetPoint("LEFT", iconSilver, "RIGHT", 2, 0)
        editCopper:SetJustifyH("RIGHT")
        local iconCopper = fastFrame:CreateTexture(nil, "ARTWORK")
        iconCopper:SetTexture("Interface\\MoneyFrame\\UI-CopperIcon")
        iconCopper:SetSize(12, 12)
        iconCopper:SetPoint("LEFT", editCopper, "RIGHT", 2, 0)
        editCopper.__EAIcon = iconCopper

        f[prefix .. "Gold"] = editGold
        f[prefix .. "Silver"] = editSilver
        f[prefix .. "Copper"] = editCopper

        return labelFS, editGold, editSilver, editCopper
    end

    local function LayoutCompactMoneyRow(labelFS, editGold, editSilver, editCopper, x, y)
        labelFS:ClearAllPoints()
        labelFS:SetPoint("TOPLEFT", fastFrame, "TOPLEFT", x, y)
        labelFS:SetWidth(58)
        labelFS:SetJustifyH("LEFT")

        editGold:ClearAllPoints()
        editGold:SetWidth(60)
        editGold:SetPoint("LEFT", labelFS, "RIGHT", 3, 0)
        if editGold.__EAIcon then
            editGold.__EAIcon:ClearAllPoints()
            editGold.__EAIcon:SetPoint("LEFT", editGold, "RIGHT", 2, 0)
        end

        editSilver:ClearAllPoints()
        editSilver:SetWidth(40)
        editSilver:SetPoint("LEFT", editGold.__EAIcon or editGold, "RIGHT", 2, 0)
        if editSilver.__EAIcon then
            editSilver.__EAIcon:ClearAllPoints()
            editSilver.__EAIcon:SetPoint("LEFT", editSilver, "RIGHT", 2, 0)
        end

        editCopper:ClearAllPoints()
        editCopper:SetWidth(40)
        editCopper:SetPoint("LEFT", editSilver.__EAIcon or editSilver, "RIGHT", 2, 0)
        if editCopper.__EAIcon then
            editCopper.__EAIcon:ClearAllPoints()
            editCopper.__EAIcon:SetPoint("LEFT", editCopper, "RIGHT", 2, 0)
        end
    end

    local function HideMoneyRow(labelFS, editGold, editSilver, editCopper)
        labelFS:Hide()
        editGold:Hide()
        editSilver:Hide()
        editCopper:Hide()
        if editGold.__EAIcon then editGold.__EAIcon:Hide() end
        if editSilver.__EAIcon then editSilver.__EAIcon:Hide() end
        if editCopper.__EAIcon then editCopper.__EAIcon:Hide() end
    end

    local unitLabel, unitGold, unitSilver, unitCopper = AddMoneyEdit(fastFrame, ItemButton, "一口(单)：", -2, "Unit")
    local bidLabel, bidGold, bidSilver, bidCopper = AddMoneyEdit(fastFrame, unitLabel, "起拍(总)：", -5, "Bid")
    f.BidGold:SetEnabled(false)
    f.BidSilver:SetEnabled(false)
    f.BidCopper:SetEnabled(false)
    local stackLabel, stackGold, stackSilver, stackCopper = AddMoneyEdit(fastFrame, bidLabel, "一口(总)：", -5, "Stack")
    LayoutCompactMoneyRow(unitLabel, unitGold, unitSilver, unitCopper, 90, -34)
    LayoutCompactMoneyRow(bidLabel, bidGold, bidSilver, bidCopper, 90, -56)
    LayoutCompactMoneyRow(stackLabel, stackGold, stackSilver, stackCopper, 90, -58)
    HideMoneyRow(bidLabel, bidGold, bidSilver, bidCopper)

    local stackCountLabel = fastFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    stackCountLabel:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
    EA_SkinText(stackCountLabel, "muted")
    stackCountLabel:SetPoint("TOPLEFT", fastFrame, "TOPLEFT", 10, -80)
    stackCountLabel:SetWidth(34)
    stackCountLabel:SetJustifyH("LEFT")
    stackCountLabel:SetText("堆叠：")
    f.StackCount = CreateNumericBox(fastFrame, 45)
    f.StackCount:SetPoint("LEFT", stackCountLabel, "RIGHT", 2, 0)
    f.StackCount:SetJustifyH("RIGHT")

    local MaxStackCountBtn = CreateFrame("Button", nil, fastFrame, "UIPanelButtonTemplate")
    MaxStackCountBtn.Text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
    MaxStackCountBtn:SetSize(30, 20)
    MaxStackCountBtn:SetText("最大")
    MaxStackCountBtn:SetPoint("LEFT", f.StackCount, "RIGHT", 3, 0)
    EA_SkinButton(MaxStackCountBtn)
    MaxStackCountBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("|cffffd700最大|r")
        GameTooltip:AddLine("自动设置为单组能堆叠的最大数量", 1, 1, 1)
        GameTooltip:AddLine("比如最大堆叠是20，你背包有50个，会填20个一组，2组", 0.9, 0.9, 0.9)
        GameTooltip:Show()
    end)
    MaxStackCountBtn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    local numStacksLabel = fastFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    numStacksLabel:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
    EA_SkinText(numStacksLabel, "muted")
    numStacksLabel:SetPoint("TOPLEFT", stackCountLabel, "BOTTOMLEFT", 0, -6)
    numStacksLabel:SetWidth(34)
    numStacksLabel:SetJustifyH("LEFT")
    numStacksLabel:SetText("组数：")
    f.NumStacks = CreateNumericBox(fastFrame, 45)
    f.NumStacks:SetPoint("LEFT", numStacksLabel, "RIGHT", 2, 0)
    f.NumStacks:SetJustifyH("RIGHT")
    f.NumStacks:SetScript("OnTextChanged", function(self)
        if self:GetNumber() < 1 then
            self:SetNumber(1)
        end
        UpdateDepositMoney()
    end)

    local MaxNumStacksBtn = CreateFrame("Button", nil, fastFrame, "UIPanelButtonTemplate")
    MaxNumStacksBtn.Text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
    MaxNumStacksBtn:SetSize(30, 20)
    MaxNumStacksBtn:SetText("最多")
    MaxNumStacksBtn:SetPoint("LEFT", f.NumStacks, "RIGHT", 3, 0)
    EA_SkinButton(MaxNumStacksBtn)
    MaxNumStacksBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("|cffffd700最多|r")
        GameTooltip:AddLine("根据当前的堆叠数，自动算出最多能分成多少组", 1, 1, 1)
        GameTooltip:AddLine("比如你填2个一组，背包有18个，会自动填9组", 0.9, 0.9, 0.9)
        GameTooltip:Show()
    end)
    MaxNumStacksBtn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    local label = fastFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
    label:SetPoint("BOTTOMLEFT", fastFrame, "BOTTOMLEFT", 10, 22)
    label:SetText("|cffffff00总保管费：|r")
    f.totalDepositMoneyLabel = label

    local profitLabel = fastFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    profitLabel:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
    profitLabel:SetPoint("BOTTOMLEFT", fastFrame, "BOTTOMLEFT", 10, 6)
    profitLabel:SetText("|cff00ff00预计利润：|r")
    f.totalProfitLabel = profitLabel

    local startBtn = CreateFrame("Button", "EasyAuctionStartBtn", fastFrame, "UIPanelButtonTemplate")
    startBtn:SetPoint("TOPRIGHT", fastFrame, "TOPRIGHT", -10, -115)
    startBtn:SetSize(94, 28)
    startBtn:SetText("开始拍卖")
    EA_SkinButton(startBtn)
    EA_SetProminentButton(startBtn, "bull")
    if startBtn:GetFontString() then
        startBtn:GetFontString():SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 13, "")
    end
    startBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("|cff00ff00左键：拍卖当前物品|r", 0.7, 1, 0.7)
        GameTooltip:AddLine("右键：复制拍卖宏命令", 1, 0.9, 0.2)
        GameTooltip:Show()
    end)
    startBtn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)

    local AuctionDurations = {
        { text = "12", value = 1 },
        { text = "24", value = 2 },
        { text = "48", value = 3 },
    }
    local durationBtns = {}
    local durationLabel = fastFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    durationLabel:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
    EA_SkinText(durationLabel, "muted")
    durationLabel:SetPoint("TOPLEFT", fastFrame, "TOPLEFT", 214, -90)
    durationLabel:SetWidth(26)
    durationLabel:SetJustifyH("LEFT")
    durationLabel:SetText("时长")
    local function SetAuctionDuration(val)
        SetSelectedDuration(val)
        for i, btn in ipairs(durationBtns) do
            EA_SetTextButtonActive(btn, btn.value == val)
            UpdateDepositMoney()
        end
    end

    for i, v in ipairs(AuctionDurations) do
        local btn = CreateFrame("Button", nil, fastFrame, "UIPanelButtonTemplate")
        btn:SetSize(i == 3 and 26 or 24, 20)
        if i == 1 then
            btn:SetPoint("LEFT", durationLabel, "RIGHT", 2, 0)
        else
            btn:SetPoint("LEFT", durationBtns[i - 1], "RIGHT", 2, 0)
        end
        btn.value = v.value
        btn:SetText(v.text)
        if btn.Text then
            btn.Text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
        end
        EA_SkinButton(btn)
        btn:SetScript("OnClick", function(self)
            SetAuctionDuration(self.value)
        end)
        table.insert(durationBtns, btn)
    end
    SetAuctionDuration(EasyAuctionDB.auctionDuration or 1)


    f.UnitGold:SetScript("OnTextChanged", function() UpdateStackPrice(f) end)
    f.UnitSilver:SetScript("OnTextChanged", function() UpdateStackPrice(f) end)
    f.UnitCopper:SetScript("OnTextChanged", function() UpdateStackPrice(f) end)

    f.StackCount:SetScript("OnTextChanged", function(self)
        local input = self:GetNumber()
        local name, _, _, _, _, _, _, maxStack, totalCount = GetAuctionSellItemInfo()
        local currentStack = select(8, GetAuctionSellItemInfo())
        if name and maxStack and totalCount then
            local limit = math.min(maxStack, totalCount, currentStack or maxStack)
            if input > limit then
                self:SetNumber(limit)
            elseif input < 1 then
                self:SetNumber(1)
            end
        else
            if input < 1 then
                self:SetNumber(1)
            end
        end
        UpdateStackPrice(f)
        UpdateDepositMoney()
        SetItemButtonCount(ItemButton, self:GetNumber() or 1)
    end)
    MaxStackCountBtn:SetScript("OnClick", function()
        local name, _, _, _, _, _, _, maxStack, totalCount = GetAuctionSellItemInfo()
        if name and maxStack and totalCount then
            local limit = math.min(maxStack, totalCount)
            f.StackCount:SetNumber(limit)
            local groups = math.floor(totalCount / limit)
            if groups < 1 then groups = 1 end
            f.NumStacks:SetNumber(groups)
        end
    end)
    MaxNumStacksBtn:SetScript("OnClick", function()
        local name, _, _, _, _, _, _, stackCount, totalCount = GetAuctionSellItemInfo()
        if name then
            local stackNum = f.StackCount:GetNumber()
            if stackNum < 1 then stackNum = 1 end
            local maxGroups = math.floor(totalCount / stackNum)
            if maxGroups < 1 then maxGroups = 1 end
            f.NumStacks:SetNumber(maxGroups)
        end
    end)

    function AutoSelectLeftoverItem(itemID)
        for bag = 0, NUM_BAG_SLOTS do
            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.itemID == itemID and info.stackCount and info.stackCount > 0 then
                    PickupAndPutToAuction(bag, slot)
                    -- 自动填充上次拍卖价格
                    if LastAuctionSold and LastAuctionSold.itemID == itemID and LastAuctionSold.unitPrice then
                        C_Timer.After(0.15, function()
                            local f = AuctionBar and AuctionBar.AuctionFrame
                            if f then
                                local price = LastAuctionSold.unitPrice
                                local ug = math.floor(price / 10000)
                                local us = math.floor((price % 10000) / 100)
                                local uc = price % 100
                                f.UnitGold:SetNumber(ug)
                                f.UnitSilver:SetNumber(us)
                                f.UnitCopper:SetNumber(uc)
                                UpdateStackPrice(f)
                            end
                        end)
                    end
                    return
                end
            end
        end
    end

    startBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    startBtn:SetScript("OnClick", function(self, btn)
        if btn == "RightButton" then
            -- 弹出复制框
            EasyAuction_ShowCopyBox("/click EasyAuctionStartBtn", self)
        else
            local name, _, _, _, _, _, _, stackCount, totalCount, itemID = GetAuctionSellItemInfo()
            if not name then
                print("|cffFF2020未放入拍卖物品！|r")
                return
            end
            local stackSize = f.StackCount:GetNumber()
            local numStacks = f.NumStacks:GetNumber()
            local unitPrice = (f.UnitGold:GetNumber() * 10000 + f.UnitSilver:GetNumber() * 100 + f.UnitCopper:GetNumber())
            local buyout = f.StackGold:GetNumber() * 10000 + f.StackSilver:GetNumber() * 100 + f.StackCopper:GetNumber()
            local minBid = f.BidGold:GetNumber() * 10000 + f.BidSilver:GetNumber() * 100 + f.BidCopper:GetNumber()
            local vendorPrice = select(11, GetItemInfo(itemID)) or 0

            local function ResetAuctionUI()
                if f.ItemName then f.ItemName:SetText("") end
                if ItemButton then
                    ItemButton.itemID = nil
                    SetItemButtonTexture(ItemButton, "")
                    SetItemButtonCount(ItemButton, 0)
                    SetItemButtonQuality(ItemButton, nil)
                end
                f.UnitGold:SetNumber(0)
                f.UnitSilver:SetNumber(0)
                f.UnitCopper:SetNumber(0)
                f.StackGold:SetNumber(0)
                f.StackSilver:SetNumber(0)
                f.StackCopper:SetNumber(0)
                f.StackCount:SetNumber(1)
                f.NumStacks:SetNumber(1)
                f.BidGold:SetNumber(0)
                f.BidSilver:SetNumber(0)
                f.BidCopper:SetNumber(0)
            end
            f.ResetAuctionUI = ResetAuctionUI

            if vendorPrice > 0 and (unitPrice - vendorPrice) < 0 then
                StaticPopupDialogs["EASYFRAME_LOW_PRICE"] = {
                    text = "|cffff4040警告|r\n\n你的单价低于卖店价。\n是否继续上架？",
                    button1 = "继续上架",
                    button2 = "取消",
                    OnAccept = function()
                        LastAuctionSold.name = name
                        LastAuctionSold.itemID = itemID
                        LastAuctionSold.unitPrice = unitPrice
                        PostAuction(minBid, buyout, GetSelectedDuration(), stackSize, numStacks, false)
                        print("|cff00ff00已发布拍卖：|r" .. name .. " x" .. numStacks)
                        EasyAuction_AddOperationHistory({
                            time = time(),
                            op = "拍卖",
                            name = name,
                            price = buyout,
                            count = stackSize * numStacks,
                            itemID = itemID,
                        })
                        EA_pendingAutoNumStacks = numStacks - 1
                    end,
                    timeout = 0,
                    whileDead = true,
                    hideOnEscape = true,
                    preferredIndex = 3,
                }
                StaticPopup_Show("EASYFRAME_LOW_PRICE")
                return
            end
            local expireHours = 3
            local expireSeconds = expireHours * 3600

            local latestTime = 0
            local key = (name and itemID) and (name .. ":" .. itemID) or nil
            local historyForExpire = key and (EasyAuction_GetPriceHistory and EasyAuction_GetPriceHistory(key, EasyAuctionDB) or (EasyAuctionDB.PriceHistory and EasyAuctionDB.PriceHistory[key]) or {}) or {}
            for _, v in ipairs(historyForExpire) do
                if v.t and v.t > latestTime then
                    latestTime = v.t
                end
            end
            local now = time()
            if latestTime > 0 and now - latestTime > expireSeconds then
                StaticPopupDialogs["EASYAUCTION_PRICE_EXPIRED"] = {
                    text = string.format(
                        "|cffff2020该物品的价格数据已超过|r|cffffd200%d小时|r|cffff2020未更新！|r\n\n请|cffffd200【搜索】|r获取最新价格。",
                        expireHours
                    ),
                    button1 = "继续上架",
                    button2 = "取消",
                    timeout = 0,
                    OnAccept = function()
                        LastAuctionSold.name = name
                        LastAuctionSold.itemID = itemID
                        LastAuctionSold.unitPrice = unitPrice
                        PostAuction(minBid, buyout, GetSelectedDuration(), stackSize, numStacks, false)
                        EasyAuction_AddOperationHistory({
                            time = time(),
                            op = "拍卖",
                            name = name,
                            price = buyout,
                            count = stackSize * numStacks,
                            itemID = itemID,
                        })
                        print("|cff00ff00已发布拍卖：|r" .. name .. " x" .. numStacks)
                        EA_pendingAutoNumStacks = numStacks - 1
                    end,
                    whileDead = true,
                    hideOnEscape = true,
                    preferredIndex = 3,
                }
                StaticPopup_Show("EASYAUCTION_PRICE_EXPIRED")
                return
            end
            LastAuctionSold.name = name
            LastAuctionSold.itemID = itemID
            LastAuctionSold.unitPrice = unitPrice
            LastAuctionSold.Progress = false
            PostAuction(minBid, buyout, GetSelectedDuration(), stackSize, numStacks, false)
            EasyAuction_AddOperationHistory({
                time = time(),
                op = "拍卖",
                name = name,
                price = buyout,
                count = stackSize * numStacks,
                itemID = itemID,
            })
            print("|cff00ff00已发布拍卖：|r" .. name .. " x" .. numStacks)
            EA_pendingAutoNumStacks = numStacks
        end
    end)

    itemsFrame = CreateFrame("Frame", nil, f, "BackdropTemplate")
    itemsFrame:SetPoint("TOPLEFT", f, "TOPRIGHT", 6, 0)
    itemsFrame:SetWidth(338)
    itemsFrame:SetHeight(defaultSideListHeight)
    itemsFrame:SetShown(false)
    EA_SkinPanel(itemsFrame, "panel")
    f.ItemsFrame = itemsFrame
    local itemsTitle = itemsFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    itemsTitle:SetPoint("TOPLEFT", 10, -8)
    itemsTitle:SetText("待售库存")
    itemsTitle:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 14, "")
    EA_SkinText(itemsTitle, "accent")

    local bagValueBtn = CreateFrame("Button", nil, itemsFrame, "UIPanelButtonTemplate")
    bagValueBtn:SetSize(82, 22)
    bagValueBtn:SetPoint("TOPRIGHT", itemsFrame, "TOPRIGHT", -8, -6)
    bagValueBtn:SetText("背包估值")
    EA_SkinButton(bagValueBtn)
    bagValueBtn:SetScript("OnClick", function()
        if type(_G.EasyAuction_ToggleBagValueFrame) == "function" then
            _G.EasyAuction_ToggleBagValueFrame()
        end
    end)
    bagValueBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("背包估值", 1, 0.82, 0)
        GameTooltip:AddLine("汇总当前背包的拍卖、卖店与分解价值。", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    bagValueBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    itemsFrame.EABagValueButton = bagValueBtn

    local itemsScroll = CreateFrame("ScrollFrame", nil, itemsFrame, "UIPanelScrollFrameTemplate")
    itemsScroll:SetPoint("TOPLEFT", itemsFrame, "TOPLEFT", 8, -34)
    itemsScroll:SetPoint("BOTTOMRIGHT", itemsFrame, "BOTTOMRIGHT", -24, 8)

    local itemsScrollChild = CreateFrame("Frame", nil, itemsScroll)
    itemsScrollChild:SetWidth(306)
    itemsScroll:SetScrollChild(itemsScrollChild)
    local ICON_SIZE, ICON_PADDING, ICONS_PER_ROW = 32, 5, 7
    local CATEGORY_LABEL_WIDTH = 38
    local CATEGORY_LABEL_PADDING = 6
    _G.EA_ItemButtons = _G.EA_ItemButtons or {}
    local itemButtons = _G.EA_ItemButtons
    local categoryHeaders = {}

    local function RefreshBagItemIcons()
        for _, btn in ipairs(itemButtons) do btn:Hide() end
        for _, hdr in pairs(categoryHeaders) do hdr:Hide() end

        local items = ScanBagAuctionableItems()
        local groups, order = CategorizeItems(items)
        local idx = 1
        local y = 0

        for _, cname in ipairs(order) do
            local groupItems = groups[cname]
            if #groupItems > 0 then
                local rows = math.ceil(#groupItems / ICONS_PER_ROW)
                local hdr = categoryHeaders[cname]
                if not hdr then
                    hdr = itemsScrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    categoryHeaders[cname] = hdr
                end
                local showName = cname == "消耗品" and "消耗" or cname
                hdr:SetText(showName)
                hdr:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
                EA_SkinText(hdr, "accent")
                hdr:ClearAllPoints()
                hdr:SetPoint("TOPLEFT", itemsScrollChild, "TOPLEFT", 0, -y - 5)
                hdr:Show()
                for i, item in ipairs(groupItems) do
                    local col = (i - 1) % ICONS_PER_ROW
                    local row = math.floor((i - 1) / ICONS_PER_ROW)
                    local btn = itemButtons[idx]
                    if not btn then
                        btn = CreateFrame("Button", nil, itemsScrollChild, "ItemButtonTemplate")
                        btn:SetSize(ICON_SIZE, ICON_SIZE)
                        itemButtons[idx] = btn
                    else
                        btn:SetParent(itemsScrollChild)
                    end
                    if not btn.selectedBorder then
                        btn.selectedBorder = btn:CreateTexture(nil, "OVERLAY")
                        btn.selectedBorder:SetPoint("TOPLEFT", btn, "TOPLEFT", -12, 12)
                        btn.selectedBorder:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 12, -12)
                        btn.selectedBorder:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
                        btn.selectedBorder:SetBlendMode("ADD")
                        btn.selectedBorder:SetVertexColor(0, 1, 0, 0.9)
                        btn.selectedBorder:Hide()
                    end
                    local iconX = CATEGORY_LABEL_WIDTH + CATEGORY_LABEL_PADDING + col * (ICON_SIZE + ICON_PADDING)
                    local iconY = -y - row * (ICON_SIZE + ICON_PADDING)
                    btn:SetPoint("TOPLEFT", itemsScrollChild, "TOPLEFT", iconX, iconY)
                    SetItemButtonTexture(btn, item.icon)
                    SetItemButtonCount(btn, item.count)
                    if item.quality and ITEM_QUALITY_COLORS[item.quality] then
                        SetItemButtonQuality(btn, item.quality, item.itemID)
                    end
                    btn.itemID = item.itemID
                    btn.bag = item.bag
                    btn.slot = item.slot
                    btn:Show()
                    btn:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:ClearLines()
                        GameTooltip:SetBagItem(self.bag, self.slot)
                        GameTooltip:AddLine(" ")
                        GameTooltip:AddDoubleLine("|cffffff00左键|r", "复制物品名称")
                        GameTooltip:AddDoubleLine("|cffffff00右键|r", "放入拍卖栏（上架）")
                        GameTooltip:Show()
                    end)
                    btn:SetScript("OnLeave", GameTooltip_Hide)
                    btn:SetScript("OnLeave", GameTooltip_Hide)
                    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                    btn:SetScript("OnClick", function(self, button)
                        if button == "LeftButton" and EasyAuctionDB.enableAuctionListCopy then
                            local name = item.itemName or ""
                            EasyAuction_ShowCopyBox("\"" .. name .. "\"")
                        elseif button == "RightButton" then
                            -- 清空旧的虚拟填充
                            if ItemButton and ItemButton.isVirtual then
                                ItemButton.itemID = nil
                                ItemButton.isVirtual = nil
                                if ItemButton.SetNormalTexture then
                                    SetItemButtonTexture(ItemButton, "")
                                end
                                SetItemButtonCount(ItemButton, 0)
                                SetItemButtonQuality(ItemButton, nil)
                                if AuctionBar and AuctionBar.AuctionFrame and AuctionBar.AuctionFrame.ItemName then
                                    AuctionBar.AuctionFrame.ItemName:SetText("")
                                end
                            end
                            if ItemButton.itemID == self.itemID then return end
                            PickupAndPutToAuction(self.bag, self.slot)
                            RefreshMinPriceLines(item.itemName, item.itemID)

                            for _, b in ipairs(itemButtons) do
                                if b.selectedBorder then b.selectedBorder:Hide() end
                            end
                            if self.selectedBorder then self.selectedBorder:Show() end
                            AuctionBar._EA_SelectedItemID = self.itemID
                        end
                    end)
                    idx = idx + 1
                end
                y = y + rows * (ICON_SIZE + ICON_PADDING) + 6
            end
        end
        local curID = AuctionBar._EA_SelectedItemID
        for _, b in ipairs(itemButtons) do
            if curID and b.itemID == curID then
                if b.selectedBorder then b.selectedBorder:Show() end
            else
                if b.selectedBorder then b.selectedBorder:Hide() end
            end
        end
        itemsScrollChild:SetHeight(y + 10)
    end
    f.RefreshBagItemFrame = RefreshBagItemIcons

    local priceFrame = CreateFrame("Frame", "EasyFrame_PriceDistFrame", sellPanelsParent, "BackdropTemplate")
    priceFrame:SetSize(328, 238)
    priceFrame:SetPoint("TOPLEFT", sellPanelsParent, "TOPLEFT", 0, -158)
    priceFrame:SetShown(EasyAuctionDB.showSections.price ~= false)
    priceFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 18,
        insets = { left = 6, right = 6, top = 6, bottom = 6 }
    })
    priceFrame:SetBackdropColor(0.10, 0.10, 0.13, 0.97)
    priceFrame:SetBackdropBorderColor(0.7, 0.6, 1, 1)
    EA_SkinPanel(priceFrame, "panel")
    priceFrame.innerLine = EA_CreateLine(priceFrame, "horizontal", 0.75)
    priceFrame.innerLine:SetPoint("TOPLEFT", priceFrame, "TOPLEFT", 8, -28)
    priceFrame.innerLine:SetPoint("TOPRIGHT", priceFrame, "TOPRIGHT", -8, -28)
    if not priceFrame.scroll then
        local scroll = CreateFrame("ScrollFrame", nil, priceFrame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", priceFrame, "TOPLEFT", 8, -32)
        scroll:SetPoint("BOTTOMRIGHT", priceFrame, "BOTTOMRIGHT", -28, 126)
        priceFrame.scroll = scroll

        local content = CreateFrame("Frame", nil, scroll)
        content:SetWidth(priceFrame:GetWidth() - 36)
        scroll:SetScrollChild(content)
        priceFrame.content = content
    end

    priceFrame.distContentHeight = 72

    local trendFrame = CreateFrame("Frame", nil, priceFrame)
    trendFrame:SetPoint("TOPLEFT", priceFrame, "TOPLEFT", 8, -120)
    trendFrame:SetPoint("BOTTOMRIGHT", priceFrame, "BOTTOMRIGHT", -28, 8)
    priceFrame.trend = trendFrame
    if not trendFrame.scroll then
        local scroll = CreateFrame("ScrollFrame", nil, trendFrame, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", trendFrame, "TOPLEFT", 0, -28)
        scroll:SetPoint("BOTTOMRIGHT", trendFrame, "BOTTOMRIGHT", 0, 6)
        trendFrame.scroll = scroll

        local content = CreateFrame("Frame", nil, scroll)
        content:SetWidth(priceFrame:GetWidth() - 36)
        scroll:SetScrollChild(content)
        trendFrame.content = content
    else
        local scroll = trendFrame.scroll
        scroll:ClearAllPoints()
        scroll:SetPoint("TOPLEFT", trendFrame, "TOPLEFT", 0, -28)
        scroll:SetPoint("BOTTOMRIGHT", trendFrame, "BOTTOMRIGHT", 0, 6)
        local content = scroll:GetScrollChild()
        if content then
            content:SetWidth(priceFrame:GetWidth() - 36)
        end
    end

    local trendTitle = trendFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    trendTitle:SetPoint("TOPLEFT", trendFrame, "TOPLEFT", 10, -8)
    trendTitle:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
    EA_SkinText(trendTitle, "accent")
    trendFrame.title = trendTitle

    local function FormatDateText(d)
        local today = date("%Y-%m-%d")
        if d == today then
            return "今日"
        elseif d == "" then
            return "--"
        elseif d:find("^%d%d%d%d%-%d%d%-%d%d$") then
            local m, day = d:sub(6, 7), d:sub(9, 10)
            return string.format("%d月%d日", tonumber(m), tonumber(day))
        else
            return d
        end
    end

    function UpdateTrendFrame(itemName)
        local f = priceFrame.trend
        local scroll = f.scroll
        local content = f.content
        local contentWidth = content:GetWidth()
        if contentWidth <= 0 then
            contentWidth = math.max(220, priceFrame:GetWidth() - 36)
        end
        local changeWidth = 48
        local countWidth = 46
        local dateWidth = 58
        local priceWidth = math.max(78, contentWidth - changeWidth - countWidth - dateWidth - 10)
        if not content.rows then content.rows = {} end
        for _, row in ipairs(content.rows) do for j = 1, 3 do if row[j] then row[j]:Hide() end end end
        if not itemName or not EasyAuctionDB.DailyMinPrice then
            if content.rows then
                for _, row in ipairs(content.rows) do
                    for j = 1, 3 do if row[j] then row[j]:Hide() end end
                end
            end
            if not f.nodataFS then
                f.nodataFS = content:CreateFontString(nil, "OVERLAY", "GameFontDisableLarge")
                f.nodataFS:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 13, "")
                f.nodataFS:SetPoint("TOPLEFT", content, "TOPLEFT", 24, 0)
                f.nodataFS:SetWidth(260)
                f.nodataFS:SetJustifyH("LEFT")
            end
            f.nodataFS:SetPoint("TOP", content, "TOP", 0, 0)
            f.nodataFS:SetJustifyH("CENTER")
            f.nodataFS:SetText("无数据")
            f.nodataFS:Show()
            return
        else
            if f.nodataFS then f.nodataFS:Hide() end
        end
        if not f.header then
            f.header = {}
            local headers = { "涨跌", "单价", "可购买", "日期" }
            for i = 1, 4 do
                local fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
                fs:SetText(headers[i])
                if i == 1 then
                    fs:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -8)
                    fs:SetWidth(changeWidth)
                    fs:SetJustifyH("RIGHT")
                elseif i == 2 then
                    fs:SetPoint("LEFT", f.header[1], "RIGHT", 2, 0)
                    fs:SetWidth(priceWidth)
                    fs:SetJustifyH("RIGHT")
                elseif i == 3 then
                    fs:SetPoint("LEFT", f.header[2], "RIGHT", 4, 0)
                    fs:SetWidth(countWidth)
                    fs:SetJustifyH("CENTER")
                else
                    fs:SetPoint("LEFT", f.header[3], "RIGHT", 4, 0)
                    fs:SetWidth(dateWidth)
                    fs:SetJustifyH("LEFT")
                end
                f.header[i] = fs
            end
        end
        f.header[1]:SetWidth(changeWidth)
        f.header[2]:SetWidth(priceWidth)
        f.header[3]:SetWidth(countWidth)
        f.header[4]:SetWidth(dateWidth)
        if not f.headerBox then
            f.headerBox = CreateFrame("Frame", nil, f)
        end
        f.headerBox:ClearAllPoints()
        f.headerBox:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -4)
        f.headerBox:SetSize(changeWidth + priceWidth + countWidth + dateWidth + 10, 22)
        EA_ApplyRowLines(f.headerBox, {
            changeWidth + 2,
            priceWidth + 4,
            countWidth + 4,
            dateWidth,
        }, 22)
        f.headerBox:Show()
        for i = 1, 4 do f.header[i]:Show() end
        EasyAuctionDB = EasyAuctionDB or {}
        EasyAuctionDB.DailyMinPrice = EasyAuctionDB.DailyMinPrice or {}

        local itemid = nil
        do
            local id = tostring(itemName):match(":(%d+)$")
            if id then
                itemid = id
            else
                for key in pairs(EasyAuctionDB.DailyMinPrice) do
                    local name, id2 = tostring(key):match("^(.*):(%d+)$")
                    if name and id2 and tostring(name):gsub("%[", ""):gsub("%]", "") == itemName:gsub("%[", ""):gsub("%]", "") then
                        itemid = id2
                        break
                    end
                end
            end
        end

        local dailyArray = {}
        local function AppendDailyRecords(key)
            local records = EasyAuction_GetDailyMinPrice and EasyAuction_GetDailyMinPrice(key, EasyAuctionDB)
                or EasyAuctionDB.DailyMinPrice[key]
            if type(records) ~= "table" then return end
            for _, v in ipairs(records) do
                table.insert(dailyArray, v)
            end
        end
        if itemid then
            for key in pairs(EasyAuctionDB.DailyMinPrice) do
                local _, id = tostring(key):match("^(.*):(%d+)$")
                if id and id == tostring(itemid) then
                    AppendDailyRecords(key)
                end
            end
        else
            AppendDailyRecords(itemName)
        end

        local dayList = {}
        for _, v in ipairs(dailyArray) do
            if v[1] and v[2] and v[2] > 0 then
                dayList[v[1]] = true
            end
        end
        local dayArr = {}
        for d in pairs(dayList) do table.insert(dayArr, d) end
        table.sort(dayArr, function(a, b) return a > b end)
        local today = date("%Y-%m-%d")
        local sortedDays = {}

        local function findRecordByDay(day)
            local found
            for _, v in ipairs(dailyArray) do
                if v[1] == day then
                    if not found or (v[2] and v[2] < found[2]) then
                        found = v
                    end
                end
            end
            return found
        end

        if findRecordByDay(today) then
            table.insert(sortedDays, today)
        end

        for _, d in ipairs(dayArr) do
            if #sortedDays >= 7 then break end
            local exists = false
            for _, d2 in ipairs(sortedDays) do
                if d2 == d then exists = true end
            end
            if not exists then table.insert(sortedDays, d) end
        end
        while #sortedDays < 7 do table.insert(sortedDays, "") end

        local rowHeight = 20
        for i = 1, 7 do
            local d = sortedDays[i]
            local row = content.rows[i]
            if not row then
                row = {}
                row.bg = content:CreateTexture(nil, "BACKGROUND")
                row.bg:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i - 1) * rowHeight)
                row.bg:SetPoint("BOTTOMRIGHT", content, "TOPRIGHT", 0, -i * rowHeight)
                if i % 2 == 1 then
                    EA_RowColor(row.bg, i)
                else
                    EA_RowColor(row.bg, i)
                end
                for j = 1, 4 do
                    row[j] = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    row[j]:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
                end
                row[1]:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i - 1) * rowHeight)
                row[1]:SetWidth(changeWidth)
                row[1]:SetJustifyH("RIGHT")
                row[2]:SetPoint("LEFT", row[1], "RIGHT", 2, 0)
                row[2]:SetWidth(priceWidth)
                row[2]:SetJustifyH("RIGHT")
                row[3]:SetPoint("LEFT", row[2], "RIGHT", 4, 0)
                row[3]:SetWidth(countWidth)
                row[3]:SetJustifyH("CENTER")
                row[4]:SetPoint("LEFT", row[3], "RIGHT", 4, 0)
                row[4]:SetWidth(dateWidth)
                row[4]:SetJustifyH("CENTER")
                content.rows[i] = row
            else
                if not row.bg then
                    row.bg = content:CreateTexture(nil, "BACKGROUND")
                end
                row.bg:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i - 1) * rowHeight)
                row.bg:SetPoint("BOTTOMRIGHT", content, "TOPRIGHT", 0, -i * rowHeight)
                if i % 2 == 1 then
                    EA_RowColor(row.bg, i)
                else
                    EA_RowColor(row.bg, i)
                end
                row.bg:Show()
            end
            row[1]:SetWidth(changeWidth)
            row[2]:SetWidth(priceWidth)
            row[3]:SetWidth(countWidth)
            row[4]:SetWidth(dateWidth)

            local priceStr, countStr, dateStr, percentStr = "--", "--", "--", "--"
            local curPrice = nil
            if d and d ~= "" then
                local v = findRecordByDay(d)
                if v then
                    -- v: {date, unit, count, min, max, totalCount}
                    local price = v[2] or 0
                    local qty   = v[3] or 0
                    priceStr    = price > 0 and GetMoneyString(price, true) or "--"
                    countStr    = qty > 0 and tostring(qty) or "--"
                    dateStr     = FormatDateText(d)
                    curPrice    = price
                end
            end

            local todayPrice = 0
            do
                local v = findRecordByDay(today)
                if v then
                    todayPrice = v[2] or 0
                end
            end

            if d == today then
                percentStr = "|cffffff00-|r"
            elseif curPrice and todayPrice and curPrice > 0 then
                local diff = todayPrice - curPrice
                local percent = diff / curPrice * 100
                if math.abs(percent) < 0.05 then
                    percentStr = "|cffffff00±0.0%|r"
                elseif percent > 0 then
                    percentStr = string.format("|cff00ff00+%.1f%%|r", percent)
                else
                    percentStr = string.format("|cffff5050%.1f%%|r", percent)
                end
            else
                percentStr = "--"
            end

            row[1]:SetText(percentStr)
            row[2]:SetText(priceStr)
            row[3]:SetText(countStr)
            row[4]:SetText(dateStr)
            for j = 1, 4 do row[j]:Show() end
        end
        content:SetHeight(7 * rowHeight + 10)
    end

    function EasyAuction_UpdateInlineDistribution(itemName, filteredData, highlightUnit)
        --print("DEBUG[分布] itemName=", itemName)
        local f = priceFrame
        local content = priceFrame.content
        local priceVisible = not (EasyAuctionDB.showSections and EasyAuctionDB.showSections.price == false)
        f:SetShown(priceVisible)
        if content and not content:IsShown() then content:Show() end
        if not f.title then
            f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -10)
            f.title:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
            EA_SkinText(f.title, "accent")
            f.title:Show()
        end
        if not f.trendBtn then
            f.trendBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            f.trendBtn:SetText("走势")
            f.trendBtn:SetSize(54, 20)
            f.trendBtn:SetPoint("LEFT", f.title, "RIGHT", 10, 0)
            EA_SkinButton(f.trendBtn)
            f.trendBtn:Show()
        end
        if not f.summary then
            f.summary = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            f.summary:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -10)
            f.summary:SetJustifyH("RIGHT")
            f.summary:SetWidth(f:GetWidth() - 20)
            f.summary:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
            EA_SkinText(f.summary, "accent")
            f.summary:Show()
        end
        if not content.emptyTip then
            content.emptyTip = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            content.emptyTip:SetPoint("CENTER", content, "CENTER", 10, -30)
            content.emptyTip:SetTextColor(1, 0.85, 0.2, 1)
            content.emptyTip:SetJustifyH("CENTER")
            content.emptyTip:SetWidth(content:GetWidth() - 20)
            content.emptyTip:Show()
        end


        local stats, maxCount = {}, 0
        for _, v in ipairs(filteredData or {}) do
            if type(v) == "table" and tonumber(v.unit) then
                local unit = tonumber(v.unit)
                stats[unit] = (stats[unit] or 0) + (v.count or 1)
                if stats[unit] > maxCount then maxCount = stats[unit] end
            end
        end
        local statArr = {}
        for unit, count in pairs(stats) do
            table.insert(statArr, { unit = unit, count = count })
        end
        table.sort(statArr, function(a, b) return a.unit < b.unit end)

        -- -- ========== 调试输出 ==========
        -- print("DEBUG[分布] statArr size=", #statArr)
        -- for i, v in ipairs(statArr) do print("DEBUG[分布] statArr[",i,"]=", v.unit, v.count) end
        -- -- =================================

        if not itemName or #statArr == 0 then
            f.title:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
            f.title:SetText("价格分布")
            if content.rows then for i = 1, #content.rows do content.rows[i]:Hide() end end
            f.summary:Hide()
            if not content.emptyTip then
                content.emptyTip = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                content.emptyTip:SetPoint("CENTER", content, "CENTER", 10, -30)
                content.emptyTip:SetTextColor(1, 0.85, 0.2, 1)
                content.emptyTip:SetJustifyH("CENTER")
                content.emptyTip:SetWidth(content:GetWidth() - 20)
            end
            content.emptyTip:Show()
            content.emptyTip:SetText("|cffffee00无价格数据，点击|r|cffffd200【搜索】|r|cffffee00更新数据。|r")
            content:SetHeight(80)
            return
        else
            if content.emptyTip then content.emptyTip:Hide() end
        end

        f.title:SetText("本次价格分布")
        f.trendBtn:SetScript("OnClick", function()
            EasyAuction_ShowChart(itemName)
        end)
        local AMOUNT_AREA_WIDTH, ROW_HEIGHT = 118, 17
        local LEFT_PADDING, RIGHT_PADDING, GAP1, GAP2, BAR_HEIGHT = 4, 8, 6, 2, 11

        local rowFont, rowFontSize, rowFontFlags = GameFontHighlightSmall:GetFont()
        local maxCountWidth = 0
        for _, v in ipairs(statArr) do
            local tempFS = content.tempFS or content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            content.tempFS = tempFS
            tempFS:SetFont(rowFont, rowFontSize, rowFontFlags)
            tempFS:SetText("|cffffde00" .. v.count .. "|r")
            local w = tempFS:GetStringWidth()
            if w > maxCountWidth then maxCountWidth = w end
        end
        maxCountWidth = maxCountWidth + GAP2

        local totalWidth = content:GetWidth()
        local barMaxWidth = totalWidth - LEFT_PADDING - RIGHT_PADDING - AMOUNT_AREA_WIDTH - GAP1 - maxCountWidth
        if barMaxWidth < 16 then barMaxWidth = 16 end

        content.rows = content.rows or {}
        if not content.lastHighlightRow then
            content.lastHighlightRow = nil
        end
        if not content._lastItemName then
            content._lastItemName = nil
        end
        if content._lastItemName ~= itemName then
            if content.lastHighlightRow and content.lastHighlightRow.highlight then
                content.lastHighlightRow.highlight:Hide()
            end
            content.lastHighlightRow = nil
            content._lastItemName = itemName
        end
        for idx, v in ipairs(statArr) do
            local row = content.rows[idx]
            if not row then
                row = CreateFrame("Button", nil, content)
                row:SetSize(totalWidth, ROW_HEIGHT)
                -- icon
                local font, size, flags = GameFontHighlightSmall:GetFont()
                row.icon = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                row.icon:SetFont(STANDARD_TEXT_FONT or font, 11, flags)
                row.icon:SetJustifyH("RIGHT")
                row.icon:SetWidth(AMOUNT_AREA_WIDTH)
                row.icon:SetPoint("LEFT", row, "LEFT", LEFT_PADDING, 0)
                row.icon:SetPoint("TOP", row, "TOP", 0, 0)
                -- bar
                row.bar = row:CreateTexture(nil, "ARTWORK")
                row.bar:SetHeight(BAR_HEIGHT)
                -- count
                row.count = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                row.count:SetFont(STANDARD_TEXT_FONT or font, 11, flags)
                row.count:SetJustifyH("LEFT")
                -- 背景
                row.bg = content:CreateTexture(nil, "BACKGROUND")
                -- 高亮
                row.highlight = row:CreateTexture(nil, "ARTWORK")
                row.highlight:SetAllPoints()
                row.highlight:SetColorTexture(0.1, 0.8, 1, 0.3)
                row.highlight:Hide()
                content.rows[idx] = row
            end

            row.bg:ClearAllPoints()
            row.bg:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -(idx - 1) * ROW_HEIGHT)
            row.bg:SetPoint("BOTTOMRIGHT", content, "TOPRIGHT", 0, -idx * ROW_HEIGHT)
            EA_RowColor(row.bg, idx)
            row.bg:Show()

            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(idx - 1) * ROW_HEIGHT)
            row:SetSize(totalWidth, ROW_HEIGHT)
            row.icon:SetText(FormatGoldIcon(v.unit, 12))
            row.icon:ClearAllPoints()
            row.icon:SetWidth(AMOUNT_AREA_WIDTH)
            row.icon:SetJustifyH("RIGHT")
            row.icon:SetPoint("LEFT", row, "LEFT", LEFT_PADDING, 0)
            row.icon:SetPoint("TOP", row, "TOP", 0, 0)

            local barLen = 1
            if maxCount > 0 then
                if maxCount == 1 then
                    barLen = math.floor(barMaxWidth * 0.5 + 0.5)
                else
                    barLen = math.floor(v.count / maxCount * barMaxWidth + 0.5)
                    if barLen < 8 then barLen = 8 end
                end
            end
            row.bar:ClearAllPoints()
            row.bar:SetPoint("LEFT", row.icon, "RIGHT", GAP1, 0)
            row.bar:SetWidth(barLen)
            row.bar:SetColorTexture(0, 0.8, 0, 1)
            row.bar:Show()

            row.count:SetText("|cffffde00" .. v.count .. "|r")
            row.count:ClearAllPoints()
            row.count:SetWidth(maxCountWidth)
            row.count:SetPoint("LEFT", row.bar, "RIGHT", GAP2, 0)
            row.count:SetJustifyH("LEFT")
            row.count:Show()

            row:EnableMouse(true)
            row:SetScript("OnClick", function(self)
                local price = v.unit
                local ug, us, uc = SplitCopper(price)
                local mainFrame = AuctionBar and AuctionBar.AuctionFrame
                if mainFrame then
                    mainFrame.UnitGold:SetNumber(ug)
                    mainFrame.UnitSilver:SetNumber(us)
                    mainFrame.UnitCopper:SetNumber(uc)
                    UpdateStackPrice(mainFrame)
                    UpdateDepositMoney()
                    MyAH_AutoFillPrice()
                end
                if content.lastHighlightRow and content.lastHighlightRow ~= self then
                    if content.lastHighlightRow.highlight then content.lastHighlightRow.highlight:Hide() end
                end
                if self.highlight then self.highlight:Show() end
                content.lastHighlightRow = self
            end)

            row:SetScript("OnEnter", function(self)
                local price = v.unit
                local gold, silver, copper = SplitCopper(price)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:ClearLines()
                local priceStr = ""
                if gold > 0 then
                    priceStr = priceStr .. gold .. "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"
                end
                if silver > 0 or gold > 0 then
                    priceStr = priceStr .. silver .. "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"
                end
                priceStr = priceStr .. copper .. "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"
                GameTooltip:AddLine("价格：" .. priceStr, 1, 1, 1)
                GameTooltip:AddLine("|cff00ff00点击：使用此价填入一口价(单)|r", 0.2, 1, 0.2)
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function(self)
                GameTooltip:Hide()
            end)
            local id = tostring(itemName):match(":(%d+)$")
            local lastID = tostring(LastAuctionSold.itemID)
            if highlightUnit and v.unit == highlightUnit then
                if row.highlight then row.highlight:Show() end
                content.lastHighlightRow = row
            else
                if row.highlight then row.highlight:Hide() end
            end

            row:Show()
        end
        for i = #statArr + 1, #(content.rows or {}) do if content.rows[i] then content.rows[i]:Hide() end end

        local totalHeight = #statArr * ROW_HEIGHT + 8
        content:SetHeight(math.max(totalHeight, priceFrame:GetHeight() - 60))
        local totalCount = 0
        for _, v in ipairs(statArr) do totalCount = totalCount + v.count end
        table.sort(statArr, function(a, b) return a.count > b.count end)
        local top3 = {}
        for i = 1, math.min(3, #statArr) do
            local v = statArr[i]
            local percent = totalCount > 0 and v.count / totalCount * 100 or 0
            table.insert(top3, string.format("%s (%.1f%%)", FormatGoldIcon(v.unit, 10), percent))
        end
        f.summary:SetText(string.format("统计数：%d", totalCount))
        f.summary:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
        EA_SkinText(f.summary, "accent")
        f.summary:Show()
        if priceFrame and priceFrame.trend then
            UpdateTrendFrame(itemName)
        end
    end

    local function ApplyMyAuctionListColumnLayout(myAuctionFrame, tableWidth)
        if not myAuctionFrame then return end

        local rowWidth = math.max(224, tableWidth or 224)
        local durationW = 46
        local priceW = 110
        local nameW = math.max(68, rowWidth - priceW - durationW)

        if myAuctionFrame.header then
            if myAuctionFrame.header.v1 then
                myAuctionFrame.header.v1:ClearAllPoints()
                myAuctionFrame.header.v1:SetPoint("TOPLEFT", myAuctionFrame.header, "TOPLEFT", nameW, 0)
                myAuctionFrame.header.v1:SetPoint("BOTTOMLEFT", myAuctionFrame.header, "BOTTOMLEFT", nameW, 0)
            end
            if myAuctionFrame.header.v2 then
                myAuctionFrame.header.v2:ClearAllPoints()
                myAuctionFrame.header.v2:SetPoint("TOPLEFT", myAuctionFrame.header, "TOPLEFT", nameW + priceW, 0)
                myAuctionFrame.header.v2:SetPoint("BOTTOMLEFT", myAuctionFrame.header, "BOTTOMLEFT", nameW + priceW, 0)
            end
            if myAuctionFrame.headerLabels then
                myAuctionFrame.headerLabels[1]:ClearAllPoints()
                myAuctionFrame.headerLabels[1]:SetPoint("LEFT", myAuctionFrame.header, "LEFT", 4, 0)
                myAuctionFrame.headerLabels[1]:SetWidth(nameW - 8)
                myAuctionFrame.headerLabels[2]:ClearAllPoints()
                myAuctionFrame.headerLabels[2]:SetPoint("LEFT", myAuctionFrame.header, "LEFT", nameW + 4, 0)
                myAuctionFrame.headerLabels[2]:SetWidth(priceW - 8)
                myAuctionFrame.headerLabels[3]:ClearAllPoints()
                myAuctionFrame.headerLabels[3]:SetPoint("LEFT", myAuctionFrame.header, "LEFT", nameW + priceW, 0)
                myAuctionFrame.headerLabels[3]:SetWidth(durationW)
            end
        end

        for _, row in ipairs(myAuctionFrame.rows or {}) do
            row:SetWidth(rowWidth)
            row.nameText:ClearAllPoints()
            row.nameText:SetPoint("LEFT", row, "LEFT", 4, 0)
            row.nameText:SetWidth(nameW - 8)
            row.priceText:ClearAllPoints()
            row.priceText:SetPoint("LEFT", row, "LEFT", nameW + 4, 0)
            row.priceText:SetWidth(priceW - 8)
            row.priceText:SetJustifyH("RIGHT")
            row.durationText:ClearAllPoints()
            row.durationText:SetPoint("LEFT", row, "LEFT", nameW + priceW, 0)
            row.durationText:SetWidth(durationW)
            row.v1:ClearAllPoints()
            row.v1:SetPoint("TOPLEFT", row, "TOPLEFT", nameW, 0)
            row.v1:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", nameW, 0)
            row.v2:ClearAllPoints()
            row.v2:SetPoint("TOPLEFT", row, "TOPLEFT", nameW + priceW, 0)
            row.v2:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", nameW + priceW, 0)
        end
    end

    if not f.MyAuctionListFrame then
        local myAuctionFrame = CreateFrame("Frame", nil, f, "BackdropTemplate")
        myAuctionFrame:SetSize(256, defaultSideListHeight)
        myAuctionFrame:SetPoint("TOPLEFT", priceFrame, "BOTTOMLEFT", 0, -6)
        myAuctionFrame:EnableMouse(true)
        myAuctionFrame:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 18,
            insets = { left = 6, right = 6, top = 6, bottom = 6 }
        })
        myAuctionFrame:SetBackdropColor(0.10, 0.10, 0.13, 0.97)
        myAuctionFrame:SetBackdropBorderColor(0.7, 0.6, 1, 1)
        EA_SkinPanel(myAuctionFrame, "panel")
        myAuctionFrame:Show()
        f.MyAuctionListFrame = myAuctionFrame
        if f.MyAuctionListFrame then
            f.MyAuctionListFrame:SetShown(EasyAuctionDB.showSections.myauct ~= false)
        end
        local title = myAuctionFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        title:SetPoint("TOPLEFT", 10, -10)
        title:SetText("在售列表")
        title:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 13, "")
        EA_SkinText(title, "accent")
        title:EnableMouse(true)
        title:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("在下方拍卖列表中，右键点击可取消该拍卖", 1, 1, 1)
            GameTooltip:Show()
        end)
        title:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)

        local totalLabel = myAuctionFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        totalLabel:SetPoint("TOPRIGHT", myAuctionFrame, "TOPRIGHT", -10, -8)
        totalLabel:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "")
        totalLabel:SetJustifyH("RIGHT")
        totalLabel:SetWidth(150)
        EA_SkinText(totalLabel, "text")
        myAuctionFrame.totalLabel = totalLabel

        local statusLabel = myAuctionFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        statusLabel:SetPoint("TOPRIGHT", totalLabel, "BOTTOMRIGHT", 0, -3)
        statusLabel:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "")
        statusLabel:SetJustifyH("RIGHT")
        statusLabel:SetWidth(190)
        EA_SkinText(statusLabel, "text")
        myAuctionFrame.statusLabel = statusLabel

        myAuctionFrame.header = CreateFrame("Frame", nil, myAuctionFrame)
        myAuctionFrame.header:SetPoint("TOPLEFT", myAuctionFrame, "TOPLEFT", 8, -34)
        myAuctionFrame.header:SetPoint("TOPRIGHT", myAuctionFrame, "TOPRIGHT", -24, -34)
        myAuctionFrame.header:SetHeight(18)
        myAuctionFrame.header.bg = myAuctionFrame.header:CreateTexture(nil, "BACKGROUND")
        myAuctionFrame.header.bg:SetAllPoints()
        if EAStyle then
            EAStyle:OnTheme(function(p)
                myAuctionFrame.header.bg:SetColorTexture(p.plot[1], p.plot[2], p.plot[3], 0.68)
            end)
        else
            myAuctionFrame.header.bg:SetColorTexture(0.08, 0.09, 0.11, 0.68)
        end
        myAuctionFrame.header.bottomLine = EA_CreateLine(myAuctionFrame.header, "horizontal", 0.9)
        myAuctionFrame.header.bottomLine:SetPoint("BOTTOMLEFT", myAuctionFrame.header, "BOTTOMLEFT", 0, 0)
        myAuctionFrame.header.bottomLine:SetPoint("BOTTOMRIGHT", myAuctionFrame.header, "BOTTOMRIGHT", 0, 0)
        myAuctionFrame.header.v1 = EA_CreateLine(myAuctionFrame.header, "vertical", 0.75)
        myAuctionFrame.header.v2 = EA_CreateLine(myAuctionFrame.header, "vertical", 0.75)
        myAuctionFrame.headerLabels = {}
        local headerTitles = { "物品", "单价", "时长" }
        for i = 1, 3 do
            local h = myAuctionFrame.header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            h:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "")
            h:SetText(headerTitles[i])
            h:SetJustifyH(i == 1 and "LEFT" or "CENTER")
            EA_SkinText(h, "accent")
            myAuctionFrame.headerLabels[i] = h
        end

        local scroll = CreateFrame("ScrollFrame", nil, myAuctionFrame, "FauxScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", myAuctionFrame, "TOPLEFT", 8, -52)
        scroll:SetPoint("BOTTOMRIGHT", myAuctionFrame, "BOTTOMRIGHT", -24, 8)
        myAuctionFrame.scroll = scroll
        scroll:SetScript("OnVerticalScroll", function(self, offset)
            FauxScrollFrame_OnVerticalScroll(self, offset, 18, function() f:RefreshMyAuctionList() end)
        end)
        local maxRows = math.floor((defaultSideListHeight - 60) / 18)
        myAuctionFrame.rows = {}
        for i = 1, maxRows do
            local row = CreateFrame("Button", nil, myAuctionFrame)
            row:SetSize(224, 18)
            row:SetPoint("TOPLEFT", 8, -52 - (i - 1) * 18)
            row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.nameText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "")
            row.nameText:SetPoint("LEFT", 4, 0)
            row.nameText:SetWidth(90)
            row.nameText:SetJustifyH("LEFT")
            row.nameText:SetWordWrap(false)
            row.priceText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.priceText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "")
            row.priceText:SetPoint("LEFT", row.nameText, "RIGHT", 6, 0)
            row.priceText:SetWidth(82)
            row.priceText:SetJustifyH("RIGHT")
            row.durationText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.durationText:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "")
            row.durationText:SetPoint("LEFT", row.priceText, "RIGHT", 6, 0)
            row.durationText:SetWidth(36)
            row.durationText:SetJustifyH("CENTER")
            EA_SkinText(row.nameText, "text")
            EA_SkinText(row.priceText, "text")
            EA_SkinText(row.durationText, "text")
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
            row.bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.05 or 0.10)
            row.bottomLine = EA_CreateLine(row, "horizontal", 0.55)
            row.bottomLine:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
            row.bottomLine:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
            row.v1 = EA_CreateLine(row, "vertical", 0.5)
            row.v1:SetPoint("TOPLEFT", row, "TOPLEFT", 96, 0)
            row.v1:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 96, 0)
            row.v2 = EA_CreateLine(row, "vertical", 0.5)
            row.v2:SetPoint("TOPLEFT", row, "TOPLEFT", 184, 0)
            row.v2:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 184, 0)
            row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
            row:SetScript("OnMouseUp", function(self, btn)
                if btn == "RightButton" and self.auctionIndex then
                    CancelAuction(self.auctionIndex)
                    f:RefreshMyAuctionList()
                end
            end)
            row:SetScript("OnEnter", function(self)
                self.bg:SetColorTexture(0.3, 0.6, 1, 0.18)
                if self.link then
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetHyperlink(self.link)
                    GameTooltip:AddLine("右键取消该拍卖", 1, 0.6, 0.2)
                    GameTooltip:Show()
                end
            end)
            row:SetScript("OnLeave", function(self)
                row.bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.05 or 0.10)
                GameTooltip:Hide()
            end)
            myAuctionFrame.rows[i] = row
        end
        ApplyMyAuctionListColumnLayout(myAuctionFrame, 224)
    end

    LayoutAuctionSide = function()
        local showSell = activeTabIndex == 2
        local showItems = false
        local contentWidth = 338
        local topHeight = 150
        local gap = sideListGap
        local sideWidth = contentWidth
        local footerReserveHeight = tonumber(f.EAProFooterReserveHeight) or 0
        local pageHeight = tabOtherPage:GetHeight()
        if not pageHeight or pageHeight <= 0 then
            pageHeight = baseHeight + footerReserveHeight - 157
        elseif footerReserveHeight > 0 then
            local currentHeight = f:GetHeight() or baseHeight
            local reservedHeight = baseHeight + footerReserveHeight
            if currentHeight < reservedHeight then
                pageHeight = pageHeight + reservedHeight - currentHeight
            end
        end
        local availablePriceHeight = math.max(216, pageHeight - topHeight - gap - 8)
        local priceHeight = (EasyAuctionDB.showSections and EasyAuctionDB.showSections.price == false) and 0
            or availablePriceHeight
        local sellHeight = topHeight
        if priceHeight > 0 then
            sellHeight = sellHeight + gap + priceHeight
        end

        local targetWidth = baseWidth
        local baseTargetHeight = showSell and math.max(baseHeight, sellHeight + 104) or baseHeight
        local targetHeight = baseTargetHeight + footerReserveHeight
        local sideColumnHeight = targetHeight - gap
        local itemsHeight = math.floor(sideColumnHeight / 2)
        local auctionHeight = (EasyAuctionDB.showSections and EasyAuctionDB.showSections.myauct == false)
            and 0 or sideColumnHeight - itemsHeight
        f:SetSize(targetWidth, targetHeight)

        sellPanelsParent:SetSize(contentWidth, sellHeight)
        fastFrame:ClearAllPoints()
        fastFrame:SetPoint("TOPLEFT", sellPanelsParent, "TOPLEFT", 0, 0)
        fastFrame:SetSize(contentWidth, topHeight)

        itemsFrame:ClearAllPoints()
        EA_DockRightOfMain(itemsFrame, f, 6)
        itemsFrame:SetSize(sideWidth, itemsHeight)
        itemsFrame:SetShown(EasyAuctionDB.showSections and EasyAuctionDB.showSections.items == true)
        if RefreshInventoryToggleBtn then
            RefreshInventoryToggleBtn()
        end
        if itemsScrollChild then
            itemsScrollChild:SetWidth(math.max(224, sideWidth - 32))
        end

        priceFrame:ClearAllPoints()
        priceFrame:SetPoint("TOPLEFT", sellPanelsParent, "TOPLEFT", 0, -topHeight - gap)
        priceFrame:SetSize(contentWidth, math.max(priceHeight, 1))
        priceFrame:SetShown(priceHeight > 0)
        local distContentHeight = priceFrame.distContentHeight or 72
        local trendTopOffset = 40 + distContentHeight + 8
        local priceScrollBottomOffset = math.max(54, priceHeight - trendTopOffset + 8)
        if priceFrame.scroll then
            priceFrame.scroll:ClearAllPoints()
            priceFrame.scroll:SetPoint("TOPLEFT", priceFrame, "TOPLEFT", 8, -32)
            priceFrame.scroll:SetPoint("BOTTOMRIGHT", priceFrame, "BOTTOMRIGHT", -28, priceScrollBottomOffset)
        end
        if priceFrame.content then
            priceFrame.content:SetWidth(math.max(220, contentWidth - 36))
        end
        if priceFrame.trend then
            priceFrame.trend:ClearAllPoints()
            priceFrame.trend:SetPoint("TOPLEFT", priceFrame, "TOPLEFT", 8, -trendTopOffset)
            priceFrame.trend:SetPoint("BOTTOMRIGHT", priceFrame, "BOTTOMRIGHT", -28, 8)
            if priceFrame.trend.scroll then
                priceFrame.trend.scroll:ClearAllPoints()
                priceFrame.trend.scroll:SetPoint("TOPLEFT", priceFrame.trend, "TOPLEFT", 0, -28)
                priceFrame.trend.scroll:SetPoint("BOTTOMRIGHT", priceFrame.trend, "BOTTOMRIGHT", 0, 6)
            end
            if priceFrame.trend.content then
                priceFrame.trend.content:SetWidth(math.max(220, contentWidth - 36))
            end
        end

        if f.MyAuctionListFrame then
            local myAuctionFrame = f.MyAuctionListFrame
            myAuctionFrame:ClearAllPoints()
            myAuctionFrame:SetPoint("TOPLEFT", itemsFrame, "BOTTOMLEFT", 0, -gap)
            myAuctionFrame:SetSize(sideWidth, math.max(auctionHeight, 1))
            myAuctionFrame:SetShown(auctionHeight > 0)
            if myAuctionFrame.header then
                myAuctionFrame.header:ClearAllPoints()
                myAuctionFrame.header:SetPoint("TOPLEFT", myAuctionFrame, "TOPLEFT", 8, -34)
                myAuctionFrame.header:SetPoint("TOPRIGHT", myAuctionFrame, "TOPRIGHT", -24, -34)
                myAuctionFrame.header:SetHeight(18)
            end
            if myAuctionFrame.scroll then
                myAuctionFrame.scroll:ClearAllPoints()
                myAuctionFrame.scroll:SetPoint("TOPLEFT", myAuctionFrame, "TOPLEFT", 8, -52)
                myAuctionFrame.scroll:SetPoint("BOTTOMRIGHT", myAuctionFrame, "BOTTOMRIGHT", -24, 8)
            end
            ApplyMyAuctionListColumnLayout(myAuctionFrame, sideWidth - 32)
            myAuctionFrame.totalLabel:SetWidth(190)
            myAuctionFrame.statusLabel:SetWidth(270)
        end
        if EasyAuctionConfigFrame and EasyAuctionConfigFrame:IsShown() then
            EA_RaiseUtilityFrame(EasyAuctionConfigFrame, f)
        end

        if f.__EARefreshHeader then
            f.__EARefreshHeader()
        end
    end
    f.EARefreshLayout = function()
        if LayoutAuctionSide then
            LayoutAuctionSide()
        end
    end

    local sectionBtnSize, sectionBtnGap = 70, 4
    local sectionBtnHeight = 22
    local firstBtnTopOffset = -30
    local sectionNames = {
        { key = "items", label = "待售库存" },
        { key = "myauct", label = "在售列表" },
        { key = "price", label = "价格分布" },
    }
    local sectionBtns = {}
    EasyAuctionDB.showSections = EasyAuctionDB.showSections or {}
    local defaultSections = { items = true, price = true, myauct = true }
    for k, v in pairs(defaultSections) do
        if EasyAuctionDB.showSections[k] == nil then
            if k == "price" then
                EasyAuctionDB.showSections[k] = true
            else
                EasyAuctionDB.showSections[k] = v
            end
        end
    end
    RefreshMyAuctionToggleBtn()
    RefreshInventoryToggleBtn()
    local HIGHLIGHT_TEXTURE = "Interface\\Buttons\\UI-Panel-Button-Highlight"

    for i, data in ipairs(sectionNames) do
        local btn = CreateFrame("Button", nil, fastFrame, "UIPanelButtonTemplate")
        btn:SetSize(sectionBtnSize, sectionBtnHeight)
        btn:SetText(data.label)
        local fontString = btn:GetFontString()
        if fontString then
            fontString:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 14, "")
        end
        EA_SkinButton(btn)

        btn:SetPoint("TOPRIGHT", scanBtn, "BOTTOMRIGHT", 0, firstBtnTopOffset - (i - 2) *
            (sectionBtnGap + sectionBtnHeight))
        btn:Hide()

        if not btn.grayMask then
            btn.grayMask = btn:CreateTexture(nil, "OVERLAY")
            btn.grayMask:SetAllPoints(btn)
            btn.grayMask:SetColorTexture(0.15, 0.15, 0.15, 0.7)
            btn.grayMask:Hide()
        end

        local function UpdateBtnVisual()
            if EasyAuctionDB.showSections[data.key] then
                EA_SetTextButtonActive(btn, true)
                btn.grayMask:Hide()
            else
                EA_SetTextButtonActive(btn, false)
                if fontString and EAStyle then
                    local p = EAStyle:Palette()
                    fontString:SetTextColor(p.muted[1], p.muted[2], p.muted[3], 0.65)
                elseif fontString then
                    fontString:SetTextColor(0.5, 0.5, 0.5, 1)
                end
                btn.grayMask:Show()
            end
        end

        btn:SetScript("OnClick", function(self)
            local val = not EasyAuctionDB.showSections[data.key]
            EasyAuctionDB.showSections[data.key] = val
            if data.key == "items" then
                itemsFrame:SetShown(val)
                if RefreshInventoryToggleBtn then RefreshInventoryToggleBtn() end
            elseif data.key == "price" then
                priceFrame:SetShown(val)
            elseif data.key == "myauct" then
                if f.MyAuctionListFrame then f.MyAuctionListFrame:SetShown(val) end
                if RefreshMyAuctionToggleBtn then RefreshMyAuctionToggleBtn() end
            end
            UpdateBtnVisual()
            if LayoutAuctionSide then
                LayoutAuctionSide()
            end
        end)
        UpdateBtnVisual()
    end

    local function utf8sub(str, startChar, numChars)
        local startIndex = 1
        while startChar > 1 do
            local char = string.byte(str, startIndex)
            if char >= 240 then
                startIndex = startIndex + 4
            elseif char >= 224 then
                startIndex = startIndex + 3
            elseif char >= 192 then
                startIndex = startIndex + 2
            else
                startIndex = startIndex + 1
            end
            startChar = startChar - 1
        end
        local currentIndex = startIndex
        while numChars > 0 and currentIndex <= #str do
            local char = string.byte(str, currentIndex)
            if char >= 240 then
                currentIndex = currentIndex + 4
            elseif char >= 224 then
                currentIndex = currentIndex + 3
            elseif char >= 192 then
                currentIndex = currentIndex + 2
            else
                currentIndex = currentIndex + 1
            end
            numChars = numChars - 1
        end
        return str:sub(1, currentIndex - 1)
    end

    local function TruncateNameAndKeepCount(fs, name, count, maxWidth)
        local qtyStr = " x" .. count
        fs:SetText(name .. qtyStr)
        if fs:GetStringWidth() <= maxWidth then
            return name .. qtyStr
        end
        local len = strlenutf8(name)
        for i = len, 1, -1 do
            local truncName = utf8sub(name, 1, i)
            local newText = truncName .. "…" .. qtyStr
            fs:SetText(newText)
            if fs:GetStringWidth() <= maxWidth then
                return newText
            end
        end
        return "…" .. qtyStr
    end

    local function GetShortMoneyString(money, maxWidth)
        local s = GetMoneyString(money, true)
        local temp = UIParent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        temp:SetText(s)
        if temp:GetStringWidth() <= maxWidth then
            temp:Hide()
            return s
        end

        local gold = floor(money / (COPPER_PER_GOLD))
        local silver = floor((money - gold * COPPER_PER_GOLD) / COPPER_PER_SILVER)
        local s2 = ""
        if gold > 0 then
            s2 = s2 .. ("%s|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"):format(gold)
        end
        if silver > 0 or gold > 0 then
            s2 = s2 .. ("%s|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"):format(silver)
        end
        temp:SetText(s2)
        if temp:GetStringWidth() <= maxWidth then
            temp:Hide()
            return s2
        end

        s2 = ("%s|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"):format(gold)
        temp:SetText(s2)
        temp:Hide()
        return s2
    end

    function f:RefreshMyAuctionList()
        local myAuctionFrame = self.MyAuctionListFrame
        if not myAuctionFrame then return end
        local num = GetNumAuctionItems("owner")
        local maxRows = #myAuctionFrame.rows
        local scroll = myAuctionFrame.scroll
        local offset = FauxScrollFrame_GetOffset(scroll)
        FauxScrollFrame_Update(scroll, num, maxRows, 18)

        local totalBuyout = 0
        local soldBuyout = 0
        local nameColWidth = 88
        local priceColWidth = 82
        if myAuctionFrame.rows and myAuctionFrame.rows[1] then
            nameColWidth = myAuctionFrame.rows[1].nameText:GetWidth() or nameColWidth
            priceColWidth = myAuctionFrame.rows[1].priceText:GetWidth() or priceColWidth
        end
        for idx = 1, num do
            local _, _, count, _, _, _, _, _, _, buyoutPrice, _, _, _, _, _, saleStatus = GetAuctionItemInfo("owner", idx)

            if buyoutPrice and buyoutPrice > 0 then
                if saleStatus == 1 then
                    soldBuyout = soldBuyout + buyoutPrice
                else
                    totalBuyout = totalBuyout + buyoutPrice
                end
            end
        end
        local sum = totalBuyout + soldBuyout

        for i = 1, maxRows do
            local idx = offset + i
            local row = myAuctionFrame.rows[i]
            if idx <= num then
                local res = { GetAuctionItemInfo("owner", idx) }
                local name = res[1]
                local count = tonumber(res[3]) or 0
                local buyout = tonumber(res[10]) or 0
                local buyer = res[12] or ""
                if count == 0 and buyer ~= "" then
                    local displayCount      = tonumber(res[4]) or 1
                    local nameCountStr      = TruncateNameAndKeepCount(row.nameText, name or "?", displayCount, nameColWidth)
                    local grayColor         = "|cffbbbbbb"
                    local qtyColor          = "|cffffff00"
                    local soldIcon          = "|TInterface\\Icons\\classic_temp:16:16:0:-2|t"
                    local itemName, itemQty = string.match(nameCountStr, "^(.-)( x%d+)$")
                    if not itemName then
                        itemName = nameCountStr; itemQty = ""
                    end
                    local nameShow = string.format("%s%s|r%s%s|r %s|cffff8800已售出|r", grayColor, itemName, qtyColor,
                        itemQty, soldIcon)
                    row.nameText:SetWidth(nameColWidth)
                    row.nameText:SetText(nameShow)
                    row.priceText:SetText("")
                    row.durationText:SetText("")
                    row.link = GetAuctionItemLink("owner", idx)
                    row.auctionIndex = nil
                    row:Show()
                elseif count > 0 and buyout > 0 then
                    row.nameText:SetWidth(nameColWidth)
                    local nameColor         = "|cffffffff"
                    local qtyColor          = "|cffffff00"
                    local nameCountStr      = TruncateNameAndKeepCount(row.nameText, name or "?", count, nameColWidth)
                    local itemName, itemQty = string.match(nameCountStr, "^(.-)( x%d+)$")
                    if not itemName then
                        itemName = nameCountStr; itemQty = ""
                    end
                    local nameShow = string.format("%s%s|r%s%s|r", nameColor, itemName, qtyColor, itemQty)
                    row.nameText:SetText(nameShow)
                    local price = buyout / count
                    local priceStr = GetShortMoneyString(price, priceColWidth)
                    local timeLeft = GetAuctionItemTimeLeft("owner", idx)
                    local durationStr = ""
                    if timeLeft == 1 then
                        durationStr = "|cffff8800<30分钟|r"
                    elseif timeLeft == 2 then
                        durationStr = "|cff00ff002小时|r"
                    elseif timeLeft == 3 then
                        durationStr = "|cff00bfff12小时|r"
                    elseif timeLeft == 4 then
                        durationStr = "|cffffff0048小时|r"
                    end
                    row.priceText:SetText(priceStr)
                    row.durationText:SetText(durationStr)
                    row.link = GetAuctionItemLink("owner", idx)
                    row.auctionIndex = idx
                    row:Show()
                else
                    row:Hide()
                end
            else
                row:Hide()
                row.link = nil
                row.auctionIndex = nil
            end
        end

        if myAuctionFrame.totalLabel then
            myAuctionFrame.totalLabel:SetText("|cffffd100总额：|r" .. GetCoinTextureString(sum))
        end
        if myAuctionFrame.statusLabel then
            myAuctionFrame.statusLabel:SetText("|cffff5050未售：|r" ..
                GetCoinTextureString(totalBuyout) .. "   |cff00ff00已售：|r" .. GetCoinTextureString(soldBuyout))
        end
    end

    -- 公用：分析一个 itemID 的历史价格，返回分析表
    local function AnalyzeAuctionHistory(itemID)
        -- 取出该物品所有价格历史记录（合并所有 key:xxx:itemID 相关的v）
        -- 注意：PriceHistory 现已使用 PH2| 字符串编码，必须通过 EasyAuction_GetPriceHistory 解码
        local history = {}
        if EasyAuctionDB and EasyAuctionDB.PriceHistory then
            for k in pairs(EasyAuctionDB.PriceHistory) do
                if k:match(":%d+$") == ":" .. tostring(itemID) then
                    local records = EasyAuction_GetPriceHistory and EasyAuction_GetPriceHistory(k, EasyAuctionDB) or {}
                    for _, vv in ipairs(records) do
                        if type(vv) == "table" then
                            table.insert(history, vv)
                        end
                    end
                end
            end
        end

        -- 过滤出最近120秒内的记录
        local maxTimestamp = 0
        for _, v in ipairs(history) do
            if v.t and v.t > maxTimestamp then
                maxTimestamp = v.t
            end
        end
        local timeThreshold = maxTimestamp - 120
        local filtered = {}
        for _, v in ipairs(history) do
            if v.unit and v.t and v.t >= timeThreshold then
                table.insert(filtered, v)
            end
        end
        -- fallback：如没有则退一步查近60秒
        if #filtered == 0 and #history > 0 then
            local fallbackThreshold = maxTimestamp - 60
            for _, v in ipairs(history) do
                if v.unit and v.t and v.t >= fallbackThreshold then
                    table.insert(filtered, v)
                end
            end
        end

        -- 统计分布和最小单价
        local stats, minUnit = {}, nil
        for _, v in ipairs(filtered) do
            local unit = tonumber(v.unit)
            if unit then
                stats[unit] = (stats[unit] or 0) + (v.count or 1)
                if not minUnit or unit < minUnit then
                    minUnit = unit
                end
            end
        end

        return {
            filtered = filtered, -- 过滤后的表
            stats = stats,       -- 单价分布
            minUnit = minUnit,   -- 最低价
            maxTimestamp = maxTimestamp,
        }
    end

    local function AutoFillPrice()
        local name, _, _, _, _, _, _, stackCount, totalCount, itemID = GetAuctionSellItemInfo()
        if not name or not itemID then return end

        local _, _, quality = GetItemInfo(itemID)
        local r, g, b = 1, 1, 1
        if quality then
            r, g, b = GetItemQualityColor(quality)
        end
        local historyInfo = {}
        local stats = {}
        local histUnit = nil
        local classID = select(12, GetItemInfo(itemID))
        if classID == 2 or classID == 4 then
            historyInfo = AnalyzeAuctionHistory(itemID)
            stats = historyInfo.stats
            histUnit = historyInfo.minUnit
        else
            local key = name .. ":" .. (itemID or "0")
            local hist = EasyAuction_GetPriceHistory and EasyAuction_GetPriceHistory(key, EasyAuctionDB) or (EasyAuctionDB and EasyAuctionDB.PriceHistory and EasyAuctionDB.PriceHistory[key])
            if hist and #hist > 0 then
                histUnit = hist[1].unit
                for _, v in ipairs(hist) do
                    if v.unit < histUnit then histUnit = v.unit end
                end
            end
            historyInfo.filtered = {}
            if not hist or type(hist) ~= "table" or #hist == 0 then
                local actualItemID = nil
                if type(itemName) == "string" and itemName:find(":") then
                    local _, parsedID = string.match(itemName, "^(.+):(%d+)$")
                    if parsedID then
                        actualItemID = tonumber(parsedID)
                        --print("DEBUG[分布] fallback actualItemID=", actualItemID)
                    end
                end
                if actualItemID then
                    for k in pairs(EasyAuctionDB.PriceHistory or {}) do
                        local candidate = EasyAuction_GetPriceHistory and EasyAuction_GetPriceHistory(k, EasyAuctionDB) or EasyAuctionDB.PriceHistory[k]
                        if k:match(":(%d+)$") == tostring(actualItemID) and type(candidate) == "table" and #candidate > 0 then
                            hist = candidate
                            --print("DEBUG[分布] fallback matched key:", k, "size:", #v)
                            break
                        end
                    end
                end
            end

            if type(hist) == "table" and (#hist > 0 or hist[1]) then
                historyInfo.filtered = hist
            elseif type(hist) == "table" then
                for _, v in pairs(hist) do
                    if type(v) == "table" and v.unit then
                        table.insert(historyInfo.filtered, v)
                    end
                end
            end
        end


        local vendorPrice = select(11, GetItemInfo(itemID)) or 0
        local useStack, useNumStacks = GetAutoFillFlashSellCounts(stackCount, totalCount)
        f.StackCount:SetNumber(useStack)
        f.NumStacks:SetNumber(useNumStacks)

        local unitPrice
        if EasyAuctionDB.autoFillLastAuction
            and LastAuctionSold.name == name
            and LastAuctionSold.itemID == itemID
            and LastAuctionSold.unitPrice then
            unitPrice = LastAuctionSold.unitPrice
        elseif histUnit then
            unitPrice = histUnit
        else
            unitPrice = math.max(vendorPrice * 5, 1)
        end

        local ug, us, uc = SplitCopper(unitPrice)
        f.UnitGold:SetNumber(ug)
        f.UnitSilver:SetNumber(us)
        f.UnitCopper:SetNumber(uc)

        if f.ItemName then
            local colorStr = ("|cff%02x%02x%02x%s|r"):format(r * 255, g * 255, b * 255, name)
            f.ItemName:SetText(colorStr)
        end
        if ItemButton and ItemButton.SetNormalTexture then
            local icon = GetItemIcon(itemID)
            if icon then
                SetItemButtonTexture(ItemButton, icon)
                FixItemButtonIconSize(ItemButton, ItemButton:GetWidth() or 40)
            end
            ItemButton.itemID = itemID
            SetItemButtonCount(ItemButton, f.StackCount:GetNumber() or 1)
        end
        UpdateStackPrice(f)
        UpdateDepositMoney()
        MyAH_AutoFillPrice()
        if EasyAuction_UpdateInlineDistribution then
            local key = (name and itemID) and (name .. ":" .. itemID) or nil
            if key then
                if EasyAuctionDB.autoFillLastAuction and LastAuctionSold.unitPrice then
                    EasyAuction_UpdateInlineDistribution(key, historyInfo.filtered, LastAuctionSold.unitPrice)
                else
                    EasyAuction_UpdateInlineDistribution(key, historyInfo.filtered, histUnit)
                end
                UpdateTrendFrame(key)
            else
                EasyAuction_UpdateInlineDistribution(nil, nil, nil)
                UpdateTrendFrame(nil)
            end
        end
    end
    ns.AutoFillPrice = AutoFillPrice

    f:RegisterEvent("BAG_UPDATE")
    f:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
    f:RegisterEvent("NEW_AUCTION_UPDATE")
    f:RegisterEvent("AUCTION_HOUSE_SHOW")
    f:RegisterEvent("AUCTION_OWNED_LIST_UPDATE")
    f:RegisterEvent("AUCTION_BIDDER_LIST_UPDATE")
    f:SetScript("OnEvent", function(self, event)
        if event == "AUCTION_ITEM_LIST_UPDATE" or event == "NEW_AUCTION_UPDATE" or event == "AUCTION_HOUSE_SHOW" then
            if IsScanningAll or IsScanningCategory then return end
            local fullScanSnapshot = ns.EA_IsFullScanSnapshotActive and ns.EA_IsFullScanSnapshotActive()
            if event == "AUCTION_ITEM_LIST_UPDATE" and fullScanSnapshot then return end
            self:RefreshBagItemFrame()
            self:RefreshMyAuctionList()
            UpdateScanBtnState()
            if not fullScanSnapshot then
                CollectAuctionBrowseResults()
                if ns and ns.tabSnipePage and ns.tabSnipePage:IsShown() then
                    if preyScroll1:IsShown() then
                        RefreshPreyRows(1)
                    elseif preyScroll2:IsShown() then
                        RefreshPreyRows(2)
                    end
                end
            end
            if MyBidListFrame and MyBidListFrame:IsShown() then
                RefreshMyBidListFrame()
            end
            AutoFillPrice()
            SetAuctionDuration(EasyAuctionDB.auctionDuration or 1)
        elseif event == "AUCTION_BIDDER_LIST_UPDATE" then
            if MyBidListFrame and MyBidListFrame:IsShown() then
                RefreshMyBidListFrame()
            end
        elseif event == "BAG_UPDATE" then
            self:RefreshBagItemFrame()
        elseif event == "AUCTION_OWNED_LIST_UPDATE" then
            self:RefreshBagItemFrame()
            self:RefreshMyAuctionList()
        end
    end)
    if f.MyAuctionListFrame then
        f.MyAuctionListFrame:SetScript("OnShow", function() f:RefreshMyAuctionList() end)
    end
    itemsFrame:SetScript("OnShow", function() f:RefreshBagItemFrame() end)
    f:HookScript("OnShow", function()
        f:RefreshBagItemFrame()
        f:RefreshMyAuctionList()
        if LayoutAuctionSide then
            LayoutAuctionSide()
        end
        ApplyEasyAuctionUIScale()
        if f.__EARefreshHeader then
            f.__EARefreshHeader()
        end
    end)
    AuctionBar.AuctionFrame = f
    SetTabSelected(EasyAuctionDB.LastActiveTab or 1)
    if LayoutAuctionSide then
        LayoutAuctionSide()
    end
    if f.__EARefreshHeader then
        f.__EARefreshHeader()
    end
    UpdateLockState()
    ApplyEasyAuctionUIScale()
end

function EasyAuction_CreateSellPanelButton()
    local btn = _G.EasyAuctionSellPanelButton
    if not btn then
        btn = CreateFrame("Button", "EasyAuctionSellPanelButton", AuctionFrame, "UIPanelButtonTemplate")
    end
    btn:ClearAllPoints()
    btn:SetSize(120, 22)
    local BuyoutCheckButton = _G["EasyAuctionBuyoutCheckButton"]
    if BuyoutCheckButton then
        btn:SetPoint("BOTTOMLEFT", BuyoutCheckButton, "TOPLEFT", -80, 4)
    else
        btn:SetPoint("TOPLEFT", AuctionFrame, "TOPLEFT", 0, -32)
    end
    btn:SetText("EasyAuction")
    btn:SetNormalFontObject(GameFontHighlightSmall)
    btn:SetHighlightFontObject(GameFontHighlightSmall)
    local fontString = btn:GetFontString()
    if fontString then
        fontString:Show()
    end

    btn:SetScript("OnClick", function()
        if AuctionBar and AuctionBar.AuctionFrame then
            if AuctionBar.AuctionFrame:IsShown() then
                AuctionBar.AuctionFrame:Hide()
                EasyAuctionDB.SellPanel = false
            else
                AuctionBar.AuctionFrame:Show()
                EasyAuctionDB.SellPanel = true
            end
        end
    end)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_NONE")
        GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine("EasyAuction", 1, 1, 1, true)
        if AuctionBar and AuctionBar.AuctionFrame and AuctionBar.AuctionFrame:IsShown() then
            GameTooltip:AddLine("点击关闭闪卖面板", 0, 1, 0, true)
        else
            GameTooltip:AddLine("点击打开闪卖面板", 1, 0.82, 0, true)
        end
        GameTooltip:AddLine("显示或隐藏 EasyAuction 侧边拍卖工作台。", 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", GameTooltip_Hide)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "AUCTION_HOUSE_SHOW" then
        CreateAuctionSide()
        RefreshMinimalToggleBtn()
        EasyAuction_SessionBuyStats = {}
        RefreshMinPriceLines()
        RefreshRecentSearchRows()
        RefreshFavoriteRows()
        if AuctionBar.AuctionFrame then
            if EasyAuctionDB.SellPanel then
                AuctionBar.AuctionFrame:Show()
            else
                AuctionBar.AuctionFrame:Hide()
            end
        end
        if AuctionFrame and AuctionFrame.selectedTab == 3 then
            for i = 1, NUM_AUCTIONS_TO_DISPLAY do
                local btn = _G["AuctionsButton" .. i]
                if btn and not btn.__EasyAuction_RightClickRegistered then
                    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
                    btn:HookScript("OnClick", function(self, button)
                        if button == "RightButton" then
                            local offset = FauxScrollFrame_GetOffset(AuctionsScrollFrame)
                            local index = offset + i
                            local saleStatus = select(16, GetAuctionItemInfo("owner", index))
                            if saleStatus ~= 1 then
                                CancelAuction(index)
                            end
                        end
                    end)
                    btn:HookScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:AddLine("右键取消该拍卖", 1, 0.6, 0.2)
                        GameTooltip:Show()
                    end)
                    btn:HookScript("OnLeave", function(self)
                        GameTooltip:Hide()
                    end)
                    btn.__EasyAuction_RightClickRegistered = true
                end
            end
        end
    end
end)

hooksecurefunc("ContainerFrameItemButton_OnModifiedClick", function(self, button)
    if button == "LeftButton" and IsShiftKeyDown() and AuctionFrame and AuctionFrame:IsShown() then
        local bag, slot = self:GetParent():GetID(), self:GetID()
        PickupAndPutToAuction(bag, slot)
    end
end)

function EasyAuction_ClearSellPanelCache()
    if not (AuctionBar and AuctionBar.AuctionFrame) then return end
    local f = AuctionBar.AuctionFrame
    EasyAuction_SessionBuyStats = {}
    if f.ItemName then f.ItemName:SetText("") end
    if f.UnitGold then f.UnitGold:SetNumber(0) end
    if f.UnitSilver then f.UnitSilver:SetNumber(0) end
    if f.UnitCopper then f.UnitCopper:SetNumber(0) end
    if f.StackGold then f.StackGold:SetNumber(0) end
    if f.StackSilver then f.StackSilver:SetNumber(0) end
    if f.StackCopper then f.StackCopper:SetNumber(0) end
    if f.StackCount then f.StackCount:SetNumber(1) end
    if f.NumStacks then f.NumStacks:SetNumber(1) end
    if f.BidGold then f.BidGold:SetNumber(0) end
    if f.BidSilver then f.BidSilver:SetNumber(0) end
    if f.BidCopper then f.BidCopper:SetNumber(0) end

    local ItemButton = _G["EasyAuctionItemButton"]
    if ItemButton then
        ItemButton.itemID = nil
        ItemButton.isVirtual = nil
        if ItemButton.SetNormalTexture then
            SetItemButtonTexture(ItemButton, "")
        end
        SetItemButtonCount(ItemButton, 0)
        SetItemButtonQuality(ItemButton, nil)
    end

    if EasyAuction_UpdateInlineDistribution then
        EasyAuction_UpdateInlineDistribution(nil, nil)
        UpdateTrendFrame(nil)
    end
    RefreshMinPriceLines()
end

C_Timer.After(0.5, function()
    if AuctionBar and AuctionBar.AuctionFrame and not AuctionBar.AuctionFrame.__EasyAuction_HideHooked then
        AuctionBar.AuctionFrame:HookScript("OnHide", function(self)
            EasyAuction_ClearSellPanelCache()
        end)
        AuctionBar.AuctionFrame.__EasyAuction_HideHooked = true
    end
end)

local totalMultisell = 0
local doneMultisell = 0
local multiSellFrame = CreateFrame("Frame")
multiSellFrame:RegisterEvent("AUCTION_MULTISELL_UPDATE")
multiSellFrame:RegisterEvent("AUCTION_MULTISELL_START")
multiSellFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")
multiSellFrame:RegisterEvent("NEW_AUCTION_UPDATE")
multiSellFrame:SetScript("OnEvent", function(self, event, current, total)
    local f = AuctionBar.AuctionFrame
    if event == "AUCTION_MULTISELL_START" then
        LastAuctionSold.Progress = true
    elseif event == "AUCTION_MULTISELL_UPDATE" then
        totalMultisell = total or 0
        doneMultisell = current or 0

        if totalMultisell > 0 and doneMultisell == totalMultisell then
            -- 拍卖结束时，自动处理剩余上架
            C_Timer.After(0.5, function()
                if LastAuctionSold.itemID and EA_pendingAutoNumStacks > 0 then
                    if f and f.ResetAuctionUI then f.ResetAuctionUI() end
                    EasyAuction_ClearSellPanelCache()
                    if f and f.RefreshMyAuctionList then f:RefreshMyAuctionList() end
                    -- 检查背包是否还有物品
                    local found = false
                    for bag = 0, NUM_BAG_SLOTS do
                        for slot = 1, C_Container.GetContainerNumSlots(bag) do
                            local info = C_Container.GetContainerItemInfo(bag, slot)
                            if info and info.itemID == LastAuctionSold.itemID and info.stackCount and info.stackCount > 0 then
                                found = true
                                PickupAndPutToAuction(bag, slot)
                                print("|cff00ff00已填充上次物品：|r", LastAuctionSold.name, "x" .. info.stackCount)
                                
                                if LastAuctionSold and LastAuctionSold.itemID == LastAuctionSold.itemID and LastAuctionSold.unitPrice and EasyAuctionDB.autoFillLastAuction then
                                    print("|cff00ff00已填充上次价格：|r", FormatGoldIcon(LastAuctionSold.unitPrice))
                                    C_Timer.After(0.15, function()
                                        local f = AuctionBar and AuctionBar.AuctionFrame
                                        if f then
                                            local price = LastAuctionSold.unitPrice
                                            local ug = math.floor(price / 10000)
                                            local us = math.floor((price % 10000) / 100)
                                            local uc = price % 100
                                            f.UnitGold:SetNumber(ug)
                                            f.UnitSilver:SetNumber(us)
                                            f.UnitCopper:SetNumber(uc)
                                            local useStack, useNumStacks = GetAutoFillFlashSellCounts(
                                                info.stackCount,
                                                info.stackCount
                                            )
                                            f.StackCount:SetNumber(useStack)
                                            f.NumStacks:SetNumber(useNumStacks)
                                            UpdateStackPrice(f)
                                        end
                                    end)
                                end
                                break
                            end
                        end
                        if found then break end
                    end
                    if found then
                        -- 只减少一次
                        EA_pendingAutoNumStacks = EA_pendingAutoNumStacks - 1
                        --AutoSelectLeftoverItem(LastAuctionSold.itemID)
                        LastAuctionSold.Progress = true
                    else
                        if f and f.ResetAuctionUI then f.ResetAuctionUI() end
                        EasyAuction_ClearSellPanelCache()
                        if f and f.RefreshMyAuctionList then f:RefreshMyAuctionList() end
                        EA_pendingAutoNumStacks = 0
                        LastAuctionSold.Progress = false
                    end
                end
            end)
        end
    elseif event == "NEW_AUCTION_UPDATE" then
        if not LastAuctionSold.Progress then
            if (totalMultisell == 0 or doneMultisell == 0) and f and f.ResetAuctionUI then
                C_Timer.After(0.5, function()
                    if LastAuctionSold.itemID and EA_pendingAutoNumStacks > 0 then
                        local found = false
                        for bag = 0, NUM_BAG_SLOTS do
                            for slot = 1, C_Container.GetContainerNumSlots(bag) do
                                local info = C_Container.GetContainerItemInfo(bag, slot)
                                if info and info.itemID == LastAuctionSold.itemID and info.stackCount and info.stackCount > 0 then
                                    found = true
                                    PickupAndPutToAuction(bag, slot)
                                    print("|cff00ff00已填充上次物品：|r", LastAuctionSold.name, "x" .. info.stackCount)
                                    -- 自动填充上次拍卖价格
                                    if LastAuctionSold and LastAuctionSold.itemID == LastAuctionSold.itemID and LastAuctionSold.unitPrice and EasyAuctionDB.autoFillLastAuction then
                                        print("|cff00ff00已填充上次价格：|r", FormatGoldIcon(LastAuctionSold.unitPrice))
                                        C_Timer.After(0.15, function()
                                            local f = AuctionBar and AuctionBar.AuctionFrame
                                            if f then
                                                local price = LastAuctionSold.unitPrice
                                                local ug = math.floor(price / 10000)
                                                local us = math.floor((price % 10000) / 100)
                                                local uc = price % 100
                                                f.UnitGold:SetNumber(ug)
                                                f.UnitSilver:SetNumber(us)
                                                f.UnitCopper:SetNumber(uc)
                                                UpdateStackPrice(f)
                                            end
                                        end)
                                    end
                                    break
                                end
                            end
                            if found then break end
                        end
                        if found then
                            EA_pendingAutoNumStacks = EA_pendingAutoNumStacks - 1
                            LastAuctionSold.Progress = true
                        else
                            if f and f.ResetAuctionUI then f.ResetAuctionUI() end
                            EasyAuction_ClearSellPanelCache()
                            if f and f.RefreshMyAuctionList then f:RefreshMyAuctionList() end
                            EA_pendingAutoNumStacks = 0
                            LastAuctionSold.Progress = false
                        end
                    end
                end)
            end
        end
        totalMultisell = 0
        doneMultisell = 0
    elseif event == "AUCTION_HOUSE_CLOSED" then
        totalMultisell = 0
        doneMultisell = 0
        EasyAuction_ClearSellPanelCache()
        if EasyAuctionCopyBox and EasyAuctionCopyBox:IsShown() then
            EasyAuctionCopyBox:Hide()
        end
    end
end)

if not AuctionBar.__EasyAuctionSellItemButtonHooked then
    local isInHook = false
    hooksecurefunc("ClickAuctionSellItemButton", function()
        if isInHook then return end
        isInHook = true
        C_Timer.After(0.05, function()
            local f = AuctionBar.AuctionFrame
            if f then
                if f.AutoFillPrice then f:AutoFillPrice() end
                if f.RefreshBagItemFrame then f:RefreshBagItemFrame() end
                if f.RefreshMyAuctionList then f:RefreshMyAuctionList() end
                UpdateDepositMoney()
            end
            isInHook = false
        end)
        local name, _, _, _, _, _, _, _, _, itemID = GetAuctionSellItemInfo()
        if name and itemID then
            RefreshMinPriceLines(name, itemID)
        end
    end)
    AuctionBar.__EasyAuctionSellItemButtonHooked = true
end

hooksecurefunc("PlaceAuctionBid", function(type, index, price)
    local name, _, count, _, _, _, _, _, _, buyout, _, _, _, owner, _, _, itemID = GetAuctionItemInfo(type, index)
    if itemID and count and price then
        LastBuyItemID = itemID
        LastBuyName = name
        LastBuyCount = count
        LastBuyUnitPrice = math.floor(price / count + 0.5)
    end
    if itemID and count and price then
        EasyAuction_AddOperationHistory({
            time = time(),
            op = "购买",
            name = name,
            price = price,
            count = count,
            itemID = itemID,
        })
    end
end)

local patterns = {
    gsub(ERR_AUCTION_WON_S or "你赢得了对%s的竞标", "%%s", "(.+)"),
    gsub(ERR_AUCTION_WON_S or "你赢得了拍卖物品：%s。", "%%s", "(.+)"),
    "你赢得了对(.+)的竞标",
    "你赢得了拍卖物品：(.+)",
}

local buyEventFrame = CreateFrame("Frame")
buyEventFrame:RegisterEvent("CHAT_MSG_SYSTEM")
buyEventFrame:SetScript("OnEvent", function(self, event, msg)
    if not msg then return end
    local wonName
    for _, pat in ipairs(patterns) do
        wonName = msg:match(pat)
        if wonName then break end
    end
    if wonName and LastBuyItemID and LastBuyName then
        local function stripColor(str)
            if not str then return "" end
            return str:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("%s+", "")
        end
        local s1, s2 = stripColor(LastBuyName), stripColor(wonName)
        if s1 == s2 or s1:find(s2, 1, true) or s2:find(s1, 1, true) then
            local stat = EasyAuction_SessionBuyStats[LastBuyItemID] or { sum = 0, num = 0 }
            stat.sum = stat.sum + (LastBuyUnitPrice or 0) * (LastBuyCount or 1)
            stat.num = stat.num + (LastBuyCount or 0)
            EasyAuction_SessionBuyStats[LastBuyItemID] = stat
            local Pro = ns and ns.EasyAuctionPro
            if Pro and Pro.ReconcileShoppingPurchaseTotal then
                Pro.ReconcileShoppingPurchaseTotal("EasyAuction_SessionBuyStats", LastBuyItemID, stat.num)
            end
            if Pro and Pro.DrawBuyFrame and Pro.buyFrame and Pro.buyFrame.IsShown and Pro.buyFrame:IsShown() then
                Pro.DrawBuyFrame()
            end
            LastBuyItemID, LastBuyName, LastBuyCount, LastBuyUnitPrice = nil, nil, nil, nil
        end
    end
end)

local function EasyAuction_GetCopyBox()
    if not EasyAuctionCopyOverlay then
        EasyAuctionCopyOverlay = CreateFrame("Frame", "EasyAuctionCopyOverlay", UIParent)
        EasyAuctionCopyOverlay:SetAllPoints(UIParent)
        EasyAuctionCopyOverlay:SetFrameStrata("FULLSCREEN_DIALOG")
        EasyAuctionCopyOverlay:EnableMouse(true)
        EasyAuctionCopyOverlay:Hide()
        EasyAuctionCopyOverlay:SetScript("OnMouseDown", function(self)
            self:Hide()
            if EasyAuctionCopyBox then
                EasyAuctionCopyBox:Hide()
            end
        end)
    end

    if not EasyAuctionCopyBox then
        EasyAuctionCopyBox = CreateFrame("EditBox", "EasyAuctionCopyBox", UIParent, "InputBoxTemplate")
        EasyAuctionCopyBox:SetAutoFocus(true)
        EasyAuctionCopyBox:SetFontObject("GameFontHighlightSmall")
        EasyAuctionCopyBox:SetSize(160, 28)
        EasyAuctionCopyBox:SetFrameStrata("FULLSCREEN_DIALOG")
        EasyAuctionCopyBox:SetJustifyH("LEFT")
        EasyAuctionCopyBox:SetScript("OnEscapePressed", function(self)
            self:Hide()
            if EasyAuctionCopyOverlay then
                EasyAuctionCopyOverlay:Hide()
            end
        end)
        EasyAuctionCopyBox:SetScript("OnShow", function(self)
            self:HighlightText(0, -1)
            self:SetFocus()
        end)
        EasyAuctionCopyBox:SetScript("OnHide", function(self)
            if EasyAuctionCopyOverlay then
                EasyAuctionCopyOverlay:Hide()
            end
        end)
    end
    return EasyAuctionCopyBox
end

function EasyAuction_ShowCopyBox(text, anchor, x, y)
    local box = EasyAuction_GetCopyBox()
    if EasyAuctionCopyOverlay then
        EasyAuctionCopyOverlay:Show()
        box:SetFrameLevel(EasyAuctionCopyOverlay:GetFrameLevel() + 1)
    end
    box:ClearAllPoints()
    x = x or 0
    y = y or 0
    if anchor then
        box:SetPoint("CENTER", anchor, "CENTER", x, y)
    else
        local mx, my = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        box:SetPoint("CENTER", UIParent, "BOTTOMLEFT", mx / scale, my / scale)
    end
    box:SetText(text or "")
    box:Show()
    box:SetFocus()
    box:HighlightText(0, -1)
end

if not _G.EasyAuction_Favorite_GlobalFocusHooked then
    _G.EasyAuction_Favorite_GlobalFocusHooked = true
    WorldFrame:HookScript("OnMouseDown", function(_, btn)
        local f = _G.EasyAuctionFavoriteImportExportFrame
        if f and f:IsShown() and f.editBox and f.editBox:HasFocus() then
            local x, y = GetCursorPosition()
            local scale = f:GetEffectiveScale()
            x = x / scale
            y = y / scale
            local left = f:GetLeft()
            local right = f:GetRight()
            local bottom = f:GetBottom()
            local top = f:GetTop()
            if not (x >= left and x <= right and y >= bottom and y <= top) then
                f.editBox:ClearFocus()
            end
        end
    end)
end

function EasyAuction_ShowOperationHistory()
    if EasyAuction_OpHistoryFrame then
        EasyAuction_OpHistoryFrame:Show()
        if EasyAuction_OpHistoryFrame.Refresh then
            EasyAuction_OpHistoryFrame:Refresh()
        end
        return
    end

    local FRAME_WIDTH, FRAME_HEIGHT = 820, 420
    local ROW_HEIGHT = 24
    local HEADER_HEIGHT = 28
    local MAX_ROWS = 100

    local f = CreateFrame("Frame", "EasyAuction_OpHistoryFrame", UIParent, "BackdropTemplate")
    f:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    EA_DockRightOfMain(f, nil, 6)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    f:SetBackdropColor(1, 1, 1, 1)
    f:SetBackdropBorderColor(0.78, 0.64, 0.33, 1)
    EA_SkinFrame(f, "window")
    tinsert(UISpecialFrames, "EasyAuction_OpHistoryFrame")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
    closeBtn:SetSize(26, 26)
    EA_SkinCloseButton(closeBtn)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 20, -16)
    title:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 15, "")
    title:SetText("历史操作记录")
    EA_SkinText(title, "accent")

    -- 累计金额显示
    local sumBuyFS = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sumBuyFS:SetPoint("TOPRIGHT", f, "TOPRIGHT", -40, -12)
    sumBuyFS:SetJustifyH("RIGHT")
    sumBuyFS:SetWidth(360)
    sumBuyFS:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
    EA_SkinText(sumBuyFS, "text")
    local sumSellFS = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sumSellFS:SetPoint("TOPRIGHT", sumBuyFS, "BOTTOMRIGHT", 0, -2)
    sumSellFS:SetJustifyH("RIGHT")
    sumSellFS:SetWidth(360)
    sumSellFS:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
    EA_SkinText(sumSellFS, "text")

    -- 删除按钮
    local delBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    delBtn:SetSize(112, 24)
    delBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -15, 10)
    delBtn:SetText("删除所有记录")
    EA_SkinButton(delBtn)
    delBtn:SetScript("OnClick", function()
        StaticPopupDialogs["EASYAUCTION_CLEAR_OPHISTORY"] = {
            text = "|cffff4040警告|r\n\n确定要删除所有操作历史记录吗？\n此操作不可恢复。",
            button1 = "确定",
            button2 = "取消",
            OnAccept = function()
                EasyAuctionDB.OperationHistory = {}
                if f.Refresh then f:Refresh() end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopup_Show("EASYAUCTION_CLEAR_OPHISTORY")
    end)

    -- 字段头
    local headers     = { "时间", "操作", "物品名", "总价格", "数量" }
    local columns     = {
        { width = 138, align = "LEFT", role = "muted" },
        { width = 64, align = "CENTER", role = "text" },
        { width = 312, align = "LEFT", role = "text" },
        { width = 178, align = "RIGHT", role = "text" },
        { width = 60, align = "CENTER", role = "text" },
    }
    local widths      = {}
    local CONTENT_WIDTH = FRAME_WIDTH - 68
    local CELL_PAD = 8
    for i = 1, #columns do
        widths[i] = columns[i].width
    end
    local tableFrame = CreateFrame("Frame", nil, f, "BackdropTemplate")
    tableFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -54)
    tableFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -32, 48)
    EA_SkinPanel(tableFrame, "panel")
    EA_ApplyOutline(tableFrame, 0.9)
    local headerFrame = CreateFrame("Frame", nil, tableFrame)
    headerFrame:SetPoint("TOPLEFT", tableFrame, "TOPLEFT", 0, 0)
    headerFrame:SetSize(CONTENT_WIDTH, HEADER_HEIGHT)
    headerFrame.cells = {}
    EA_ApplyRowLines(headerFrame, widths, HEADER_HEIGHT)
    local headx = 0
    for i = 1, #headers do
        local fs = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("LEFT", headerFrame, "LEFT", headx + CELL_PAD, 0)
        fs:SetWidth(widths[i] - CELL_PAD * 2)
        fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
        fs:SetJustifyH(columns[i].align)
        fs:SetText(headers[i])
        EA_SkinText(fs, "accent")
        headerFrame.cells[i] = fs
        headx = headx + widths[i]
    end

    -- 滚动区域
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", tableFrame, "TOPLEFT", 0, -HEADER_HEIGHT)
    scroll:SetPoint("BOTTOMRIGHT", tableFrame, "BOTTOMRIGHT", -20, 0)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(CONTENT_WIDTH)
    scroll:SetScrollChild(content)
    f.scroll = scroll
    f.content = content

    -- 记录行
    content.rows = {}
    for i = 1, MAX_ROWS do
        local row = content.rows[i] or CreateFrame("Button", nil, content)
        row:SetSize(CONTENT_WIDTH, ROW_HEIGHT)
        if i == 1 then
            row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
        else
            row:SetPoint("TOPLEFT", content.rows[i - 1], "BOTTOMLEFT", 0, 0)
        end
        -- 间隔背景
        if not row.bg then
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetDrawLayer("BACKGROUND", 0)
            row.bg:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
            row.bg:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
        end
        EA_RowColor(row.bg, i)
        EA_ApplyRowLines(row, widths, ROW_HEIGHT)
        row.fs = row.fs or {}
        local xx = 0
        for j = 1, #headers do
            row.fs[j] = row.fs[j] or row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.fs[j]:ClearAllPoints()
            row.fs[j]:SetPoint("LEFT", row, "LEFT", xx + CELL_PAD, 0)
            row.fs[j]:SetWidth(widths[j] - CELL_PAD * 2)
            row.fs[j]:SetHeight(ROW_HEIGHT)
            row.fs[j]:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
            row.fs[j]:SetJustifyH(columns[j].align)
            row.fs[j]:SetJustifyV("MIDDLE")
            EA_SkinText(row.fs[j], columns[j].role)
            xx = xx + widths[j]
        end
        content.rows[i] = row
    end

    function f:Refresh()
        local ops = EasyAuctionDB.OperationHistory or {}
        table.sort(ops, function(a, b) return (a.time or 0) > (b.time or 0) end)
        local totalBuy, totalSell = 0, 0
        for i = 1, #content.rows do
            local row = content.rows[i]
            local info = ops[i]
            if info then
                row:Show()
                EA_RowColor(row.bg, i)
                local tstr = date("%Y-%m-%d %H:%M", info.time or 0)
                row.fs[1]:SetText(tstr)
                row.fs[2]:SetText(info.op == "购买" and "购买" or "拍卖")
                local itemName = info.name or ""
                if info.itemID then
                    local icon = GetItemIcon(info.itemID)
                    if icon then
                        itemName = "|T" .. icon .. ":16:16:0:0|t " .. itemName
                    end
                end
                row.fs[3]:SetText(itemName)
                row.fs[4]:SetText(GetCoinTextureString(info.price or 0))
                row.fs[5]:SetText(tostring(info.count or 1))
                if info.op == "购买" then
                    totalBuy = totalBuy + (info.price or 0)
                elseif info.op == "拍卖" then
                    totalSell = totalSell + (info.price or 0)
                end

                -- 鼠标悬停高亮
                row:SetScript("OnEnter", function(self)
                    EA_RowColor(self.bg, i, true)
                    if info.itemID then
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetItemByID(info.itemID)
                        GameTooltip:Show()
                    end
                end)
                row:SetScript("OnLeave", function(self)
                    EA_RowColor(self.bg, i)
                    GameTooltip:Hide()
                end)
            else
                row:Hide()
            end
        end
        content:SetHeight(math.max(#ops, 5) * ROW_HEIGHT)
        sumBuyFS:SetText(string.format("累计购买：%s", GetCoinTextureString(totalBuy)))
        sumSellFS:SetText(string.format("累计拍卖：%s", GetCoinTextureString(totalSell)))
    end

    f:Refresh()
    EasyAuction_OpHistoryFrame = f
end

local function EA_GoldBillCoinText(value)
    value = math.floor(tonumber(value) or 0)
    if value < 0 then
        return "-" .. GetCoinTextureString(math.abs(value))
    elseif value > 0 then
        return GetCoinTextureString(value)
    end
    return GetCoinTextureString(0)
end

local function EA_GoldBillSignedText(value)
    value = math.floor(tonumber(value) or 0)
    if value > 0 then
        return "+" .. GetCoinTextureString(value)
    elseif value < 0 then
        return "-" .. GetCoinTextureString(math.abs(value))
    end
    return GetCoinTextureString(0)
end

local function EA_GoldBillPlainMoney(value, signed)
    value = math.floor(tonumber(value) or 0)
    local sign = ""
    if value < 0 then
        sign = "-"
        value = math.abs(value)
    elseif signed and value > 0 then
        sign = "+"
    end
    local gold = math.floor(value / 10000)
    local silver = math.floor((value % 10000) / 100)
    local copper = value % 100
    if gold > 0 then
        if silver > 0 then
            return string.format("%s%d金%02d银", sign, gold, silver)
        end
        return string.format("%s%d金", sign, gold)
    elseif silver > 0 then
        if copper > 0 then
            return string.format("%s%d银%02d铜", sign, silver, copper)
        end
        return string.format("%s%d银", sign, silver)
    end
    return string.format("%s%d铜", sign, copper)
end

local function EA_GoldBillShortGold(value, span)
    value = math.max(0, math.floor(tonumber(value) or 0))
    span = math.floor(tonumber(span) or 0)
    local gold = math.floor(value / 10000)
    local silver = math.floor((value % 10000) / 100)
    local copper = value % 100
    if span > 0 and span < 10000 then
        if gold > 0 then
            return string.format("%d金%02d银", gold, silver)
        elseif silver > 0 then
            return string.format("%d银%02d铜", silver, copper)
        end
        return tostring(copper) .. "铜"
    end
    if gold >= 100000 then
        return string.format("%.1f万金", gold / 10000)
    end
    return tostring(gold) .. "金"
end

local function EA_GoldBillTrendColor(fs, value)
    if not fs then return end
    if EAStyle then
        local r, g, b = EAStyle:ColorTrend(value or 0)
        fs:SetTextColor(r, g, b)
    elseif (value or 0) > 0 then
        fs:SetTextColor(0.25, 1, 0.45)
    elseif (value or 0) < 0 then
        fs:SetTextColor(1, 0.25, 0.25)
    else
        fs:SetTextColor(0.8, 0.8, 0.8)
    end
end

local function EA_GoldBillCurrentGold(selectedChars)
    local db = EasyAuctionDB
    local playerName = UnitName("player") or "Unknown"
    local currentMoney = type(GetMoney) == "function" and GetMoney() or 0
    local now = time()
    local selected = {}
    local seen = {}
    local function LatestSavedGold(charName)
        local latestTime, latestGold = 0, 0
        local daily = db and db.GoldHistory and db.GoldHistory[charName]
        if daily then
            for dateStr, money in pairs(daily) do
                local y, m, d = dateStr:match("^(%d+)%-(%d+)%-(%d+)$")
                if y and m and d then
                    local stamp = time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 0, min = 0, sec = 0 })
                    if stamp and stamp <= now and stamp >= latestTime then
                        latestTime = stamp
                        latestGold = tonumber(money) or 0
                    end
                end
            end
        end
        local hourly = db and db.GoldHourlyHistory and db.GoldHourlyHistory[charName]
        if hourly then
            for dateStr, money in pairs(hourly) do
                local y, m, d, h = dateStr:match("^(%d+)%-(%d+)%-(%d+) (%d+):00$")
                if y and m and d and h then
                    local stamp = time({
                        year = tonumber(y),
                        month = tonumber(m),
                        day = tonumber(d),
                        hour = tonumber(h),
                        min = 0,
                        sec = 0,
                    })
                    if stamp and stamp <= now and stamp >= latestTime then
                        latestTime = stamp
                        latestGold = tonumber(money) or 0
                    end
                end
            end
        end
        return latestGold
    end
    if selectedChars and #selectedChars > 0 then
        for _, name in ipairs(selectedChars) do
            selected[name] = true
        end
    end

    if next(selected) then
        local total = 0
        for name in pairs(selected) do
            if name == playerName then
                total = total + currentMoney
            else
                total = total + LatestSavedGold(name)
            end
        end
        return total
    end

    local total = 0
    local seenPlayer = false
    if db and db.GoldHistory then
        for name in pairs(db.GoldHistory) do
            seen[name] = true
        end
    end
    if db and db.GoldHourlyHistory then
        for name in pairs(db.GoldHourlyHistory) do
            seen[name] = true
        end
    end
    if next(seen) then
        for name in pairs(seen) do
            if name == playerName then
                seenPlayer = true
                total = total + currentMoney
            else
                total = total + LatestSavedGold(name)
            end
        end
    end
    if not seenPlayer then
        total = total + currentMoney
    end
    return total
end

local function EA_GoldBillCharAllowed(selectedChars, charName)
    if not selectedChars or #selectedChars == 0 then
        return true
    end
    if not charName then
        return true
    end
    for _, name in ipairs(selectedChars) do
        if name == charName then
            return true
        end
    end
    return false
end

local function EA_GoldBillUpdateTopItem(summary, side, info)
    local name = info.name or "-"
    local item = summary[side .. "Items"][name] or { total = 0, count = 0, itemID = info.itemID }
    item.total = item.total + (info.price or 0)
    item.count = item.count + (info.count or 1)
    item.itemID = item.itemID or info.itemID
    summary[side .. "Items"][name] = item
    if item.total > (summary[side .. "TopTotal"] or 0) then
        summary[side .. "TopTotal"] = item.total
        summary[side .. "TopName"] = name
        summary[side .. "TopItemID"] = item.itemID
    end
end

local function EA_GoldBillOperationSummary(days, selectedChars)
    local summary = {
        saleTotal = 0,
        saleCount = 0,
        saleTopValue = 0,
        saleTopName = nil,
        saleTopTotal = 0,
        saleTopItemID = nil,
        saleItems = {},
        buyTotal = 0,
        buyCount = 0,
        buyTopValue = 0,
        buyTopName = nil,
        buyTopTotal = 0,
        buyTopItemID = nil,
        buyItems = {},
        opCount = 0,
    }
    local ops = EasyAuctionDB and EasyAuctionDB.OperationHistory or {}
    local cutoff = time() - (tonumber(days) or 7) * 86400
    for _, info in ipairs(ops) do
        if (info.time or 0) >= cutoff and EA_GoldBillCharAllowed(selectedChars, info.charName) then
            local price = tonumber(info.price) or 0
            local count = tonumber(info.count) or 1
            summary.opCount = summary.opCount + 1
            if info.op == "购买" then
                summary.buyTotal = summary.buyTotal + price
                summary.buyCount = summary.buyCount + count
                if price > summary.buyTopValue then
                    summary.buyTopValue = price
                end
                EA_GoldBillUpdateTopItem(summary, "buy", info)
            elseif info.op == "拍卖" then
                summary.saleTotal = summary.saleTotal + price
                summary.saleCount = summary.saleCount + count
                if price > summary.saleTopValue then
                    summary.saleTopValue = price
                end
                EA_GoldBillUpdateTopItem(summary, "sale", info)
            end
        end
    end
    summary.profitTotal = summary.saleTotal - summary.buyTotal
    summary.days = math.max(tonumber(days) or 1, 1)
    return summary
end

local function EA_GoldBillMakeText(parent, size, role, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size or 11, "")
    fs:SetJustifyH(justify or "LEFT")
    EA_SkinText(fs, role or "text")
    return fs
end

local function EA_GoldBillMakeStatRow(parent, anchor, label, yOffset)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(18)
    row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset or -2)
    row:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    row.label = EA_GoldBillMakeText(row, 10, "muted", "LEFT")
    row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.label:SetWidth(76)
    row.label:SetText(label)
    row.value = EA_GoldBillMakeText(row, 10, "text", "RIGHT")
    row.value:SetPoint("LEFT", row.label, "RIGHT", 6, 0)
    row.value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    return row
end

local function EA_GoldBillSetItemText(fs, name, itemID)
    if not fs then return end
    if name and name ~= "-" then
        local text = name
        local icon = itemID and GetItemIcon(itemID)
        if icon then
            text = "|T" .. icon .. ":14:14:0:0|t " .. text
        end
        fs:SetText(text)
    else
        fs:SetText("-")
    end
end

local function EA_GoldBillFormatPointTime(point)
    if point and point.time then
        return date("%Y-%m-%d %H:%M", point.time)
    end
    return ((point and point.date) or "-") .. " 00:00"
end

local function EA_GoldBillAxisText(entry)
    if not entry then return "-" end
    if entry.time and type(entry.date) == "string" and entry.date:find(" ", 1, true) then
        return date("%m-%d %H:%M", entry.time)
    end
    return entry.date and entry.date:sub(6) or "-"
end

local function EA_GoldBillAcquireLine(panel)
    panel.linePoolIndex = (panel.linePoolIndex or 0) + 1
    local tex = panel.linePool[panel.linePoolIndex]
    if not tex then
        tex = panel.plot:CreateTexture(nil, "ARTWORK")
        tex:SetTexture("Interface\\Buttons\\WHITE8X8")
        panel.linePool[panel.linePoolIndex] = tex
    end
    tex:ClearAllPoints()
    tex:SetRotation(0)
    tex:SetSize(1, 1)
    tex:SetAlpha(1)
    tex:Show()
    return tex
end

local function EA_GoldBillHideChartObjects(panel)
    panel.linePoolIndex = 0
    for _, tex in ipairs(panel.linePool or {}) do
        tex:Hide()
        tex:ClearAllPoints()
        tex:SetRotation(0)
        tex:SetSize(1, 1)
    end
    if panel.marker then
        panel.marker:Hide()
        panel.marker:ClearAllPoints()
    end
    if panel.crossV then
        panel.crossV:Hide()
        panel.crossV:ClearAllPoints()
        panel.crossV:SetRotation(0)
    end
    if panel.tip then panel.tip:Hide() end
    panel.hoverKey = nil
end

local function EA_GoldBillNearestPoint(points, ratio)
    local count = #points
    if count <= 1 then
        return points[1], 1
    end
    local idx = math.floor(ratio * (count - 1) + 1.5)
    if idx < 1 then idx = 1 end
    if idx > count then idx = count end
    return points[idx], idx
end

local function EA_GoldBillShowReadout(panel, point, idx)
    if not point then return end
    local plot = panel.plot
    local tip = panel.tip
    local prev = idx > 1 and panel.points[idx - 1] or nil
    local delta = prev and (point.gold - prev.gold) or 0
    local percent = prev and prev.gold > 0 and (delta / prev.gold * 100) or 0
    local title = EA_GoldBillFormatPointTime(point)
    local body = "金币：" .. EA_GoldBillCoinText(point.gold) .. "\n涨跌：" .. EA_GoldBillSignedText(delta)
    if prev then
        body = body .. string.format(" (%.1f%%)", percent)
    end

    panel.crossV:ClearAllPoints()
    panel.crossV:SetPoint("BOTTOM", plot, "BOTTOMLEFT", point.x, 0)
    panel.crossV:SetSize(1, plot:GetHeight())
    panel.crossV:Show()
    panel.marker:ClearAllPoints()
    panel.marker:SetPoint("CENTER", plot, "BOTTOMLEFT", point.x, point.y)
    panel.marker:Show()

    tip.title:SetText(title)
    tip.body:SetText(body)
    EA_GoldBillTrendColor(tip.body, delta)
    local width = math.max(tip.title:GetStringWidth(), tip.body:GetStringWidth()) + 18
    local height = tip.title:GetStringHeight() + tip.body:GetStringHeight() + 18
    tip:SetSize(math.max(width, 142), height)
    local plotW, plotH = plot:GetWidth(), plot:GetHeight()
    local cx = point.x
    if cx < tip:GetWidth() / 2 then
        cx = tip:GetWidth() / 2
    elseif cx > plotW - tip:GetWidth() / 2 then
        cx = plotW - tip:GetWidth() / 2
    end
    tip:ClearAllPoints()
    if point.y + tip:GetHeight() + 14 > plotH then
        tip:SetPoint("TOP", plot, "BOTTOMLEFT", cx, point.y - 8)
    else
        tip:SetPoint("BOTTOM", plot, "BOTTOMLEFT", cx, point.y + 12)
    end
    tip:Show()
end

local function EA_GoldBillRenderChart(frame, history, minGold, maxGold)
    local panel = frame.chartPanel
    local plot = panel.plot
    EA_GoldBillHideChartObjects(panel)
    panel.points = {}
    panel.empty:Hide()

    local plotW = plot:GetWidth()
    local plotH = plot:GetHeight()
    if plotW <= 0 or plotH <= 0 then
        C_Timer.After(0, function()
            if frame:IsShown() then
                frame:Refresh()
            end
        end)
        return
    end
    if not history or #history == 0 then
        panel.empty:SetText("暂无金币记录")
        panel.empty:Show()
        return
    end

    local span = math.max((maxGold or 0) - (minGold or 0), 1)
    minGold = (minGold or 0) - span * 0.04
    maxGold = (maxGold or 0) + span * 0.04
    span = math.max(maxGold - minGold, 1)

    for i = 1, 5 do
        local frac = (i - 1) / 4
        local value = minGold + span * frac
        local label = panel.yLabels[i]
        label:SetText(EA_GoldBillShortGold(value, span))
        label:ClearAllPoints()
        label:SetPoint("RIGHT", plot, "BOTTOMLEFT", -6, plotH * frac)
        local grid = panel.gridLines[i]
        grid:ClearAllPoints()
        grid:SetPoint("LEFT", plot, "BOTTOMLEFT", 0, plotH * frac)
        grid:SetPoint("RIGHT", plot, "BOTTOMRIGHT", 0, plotH * frac)
        grid:Show()
    end

    local xMax = math.max(#history - 1, 1)
    for i, entry in ipairs(history) do
        local gold = tonumber(entry.gold) or 0
        local x = ((i - 1) / xMax) * plotW
        local y = ((gold - minGold) / span) * plotH
        panel.points[i] = { x = x, y = y, gold = gold, date = entry.date, time = entry.time }
    end

    for i = 2, #panel.points do
        local a, b = panel.points[i - 1], panel.points[i]
        local dx, dy = b.x - a.x, b.y - a.y
        local len = math.sqrt(dx * dx + dy * dy)
        local line = EA_GoldBillAcquireLine(panel)
        if EAStyle then
            local p = EAStyle:Palette()
            line:SetColorTexture(p.accent[1], p.accent[2], p.accent[3], 1)
        else
            line:SetColorTexture(0.4, 0.8, 1, 1)
        end
        line:SetPoint("CENTER", plot, "BOTTOMLEFT", a.x + dx / 2, a.y + dy / 2)
        line:SetSize(math.max(len, 1), 2)
        line:SetRotation(math.atan2(dy, dx))
    end
    if #panel.points == 1 then
        local point = panel.points[1]
        local line = EA_GoldBillAcquireLine(panel)
        if EAStyle then
            local p = EAStyle:Palette()
            line:SetColorTexture(p.accent[1], p.accent[2], p.accent[3], 0.9)
        else
            line:SetColorTexture(0.4, 0.8, 1, 0.9)
        end
        line:SetPoint("CENTER", plot, "BOTTOMLEFT", plotW / 2, point.y)
        line:SetSize(plotW, 2)
    end

    local midIdx = math.max(math.floor((#history + 1) / 2), 1)
    panel.xLabels[1]:SetText(EA_GoldBillAxisText(history[1]))
    panel.xLabels[2]:SetText(EA_GoldBillAxisText(history[midIdx]))
    panel.xLabels[3]:SetText(EA_GoldBillAxisText(history[#history]))
    panel.xLabels[1]:ClearAllPoints()
    panel.xLabels[2]:ClearAllPoints()
    panel.xLabels[3]:ClearAllPoints()
    panel.xLabels[1]:SetPoint("TOPLEFT", plot, "BOTTOMLEFT", 0, -4)
    panel.xLabels[2]:SetPoint("TOP", plot, "BOTTOM", 0, -4)
    panel.xLabels[3]:SetPoint("TOPRIGHT", plot, "BOTTOMRIGHT", 0, -4)
end

local function EA_GoldBillUpdateHover(plot, panel)
    if not panel.points or #panel.points == 0 or not plot:GetLeft() then
        return
    end
    local x = (GetCursorPosition() / plot:GetEffectiveScale()) - plot:GetLeft()
    local width = plot:GetWidth()
    if x < 0 or x > width then
        panel.hoverKey = nil
        panel.crossV:Hide()
        panel.marker:Hide()
        panel.tip:Hide()
        return
    end
    local point, idx = EA_GoldBillNearestPoint(panel.points, x / math.max(width, 1))
    if panel.hoverKey == idx then
        return
    end
    panel.hoverKey = idx
    EA_GoldBillShowReadout(panel, point, idx)
end

function EasyAuction_ShowGoldBillFrame()
    if EasyAuction_GoldBillFrame then
        EasyAuction_GoldBillFrame:Show()
        if EasyAuction_GoldBillFrame.Refresh then
            EasyAuction_GoldBillFrame:Refresh()
        end
        return
    end

    local FRAME_WIDTH, FRAME_HEIGHT = 680, 560
    local HEADER_HEIGHT = 32
    local CHART_HEIGHT = 280
    local BUTTON_HEIGHT = 28

    local f = CreateFrame("Frame", "EasyAuction_GoldBillFrame", UIParent, "BackdropTemplate")
    f:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    EA_DockRightOfMain(f, nil, 6)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 18,
        insets = { left = 6, right = 6, top = 6, bottom = 6 }
    })
    f:SetBackdropColor(0.10, 0.10, 0.13, 0.97)
    f:SetBackdropBorderColor(0.7, 0.6, 1, 1)
    EA_SkinFrame(f, "window")
    tinsert(UISpecialFrames, "EasyAuction_GoldBillFrame")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
    closeBtn:SetSize(26, 26)
    EA_SkinCloseButton(closeBtn)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 20, -16)
    title:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 15, "")
    title:SetText("金币账单")
    EA_SkinText(title, "accent")

    local headerMoney = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    headerMoney:SetPoint("LEFT", title, "RIGHT", 12, 0)
    headerMoney:SetPoint("RIGHT", closeBtn, "LEFT", -8, 0)
    headerMoney:SetJustifyH("LEFT")
    headerMoney:SetWordWrap(false)
    headerMoney:SetText("")
    EA_SkinText(headerMoney, "muted")
    f.headerMoney = headerMoney

    f.selectedChars = {}

    local charDropdownBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    charDropdownBtn:SetSize(140, BUTTON_HEIGHT)
    charDropdownBtn:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    charDropdownBtn:SetText("所有角色")
    EA_SkinButton(charDropdownBtn)

    f.charDropdownBtn = charDropdownBtn

    charDropdownBtn:SetScript("OnClick", function(self)
        local chars = EasyAuction_GetAllGoldCharacters()
        if #chars == 0 then
            return
        end

        if f.charDropdownMenu then
            f.charDropdownMenu:Hide()
            f.charDropdownMenu = nil
            return
        end

        local menu = CreateFrame("Frame", "EasyAuction_GoldBillCharMenu", UIParent, "BackdropTemplate")
        menu:SetSize(160, math.min(#chars * 24 + 40, 300))
        menu:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 12,
            insets = { left = 4, right = 4, top = 4, bottom = 4 }
        })
        menu:SetBackdropColor(0.15, 0.15, 0.2, 0.98)
        menu:SetBackdropBorderColor(0.7, 0.6, 1, 1)
        EA_SkinPanel(menu, "panel")
        menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetFrameLevel(math.max((f:GetFrameLevel() or 1) + 120, (self:GetFrameLevel() or 1) + 80))
        menu:SetToplevel(true)
        menu:EnableMouse(true)

        local allBtn = CreateFrame("Button", nil, menu, "UIPanelButtonTemplate")
        allBtn:SetSize(140, 22)
        allBtn:SetPoint("TOP", menu, "TOP", 0, -8)
        allBtn:SetText("所有角色")
        EA_SkinButton(allBtn)
        allBtn:SetFrameLevel(menu:GetFrameLevel() + 2)
        allBtn:SetScript("OnClick", function()
            f.selectedChars = {}
            charDropdownBtn:SetText("所有角色")
            menu:Hide()
            f.charDropdownMenu = nil
            f:Refresh()
        end)

        local line = menu:CreateTexture(nil, "ARTWORK")
        line:SetHeight(1)
        line:SetColorTexture(0.3, 0.3, 0.3, 0.5)
        line:SetPoint("LEFT", menu, "LEFT", 8, -32)
        line:SetPoint("RIGHT", menu, "RIGHT", -8, -32)

        for i, charName in ipairs(chars) do
            local btn = CreateFrame("Button", nil, menu, "UIPanelButtonTemplate")
            btn:SetSize(140, 22)
            btn:SetPoint("TOP", menu, "TOP", 0, -38 - (i - 1) * 24)
            btn:SetText(charName)
            EA_SkinButton(btn)
            btn:SetFrameLevel(menu:GetFrameLevel() + 2)
            btn:SetScript("OnClick", function(self)
                local selected = false
                for j, name in ipairs(f.selectedChars) do
                    if name == charName then
                        table.remove(f.selectedChars, j)
                        selected = true
                        break
                    end
                end
                if not selected then
                    table.insert(f.selectedChars, charName)
                end
                if #f.selectedChars == 0 then
                    charDropdownBtn:SetText("所有角色")
                elseif #f.selectedChars == 1 then
                    charDropdownBtn:SetText(f.selectedChars[1])
                else
                    charDropdownBtn:SetText(string.format("%d 个角色", #f.selectedChars))
                end
                menu:Hide()
                f.charDropdownMenu = nil
                f:Refresh()
            end)
        end

        menu:Show()
        f.charDropdownMenu = menu

        menu:SetScript("OnHide", function()
            f.charDropdownMenu = nil
        end)
    end)

    f.timeRange = "week"
    local timeRanges = {
        { key = "hour", label = "小时", hours = 24 },
        { key = "day", label = "天", days = 1 },
        { key = "week", label = "周", days = 7 },
        { key = "month", label = "月", days = 30 },
        { key = "year", label = "年", days = 365 },
        { key = "year2", label = "2年", days = 730 },
        { key = "year3", label = "3年", days = 1095 },
    }

    local timeBtnFrame = CreateFrame("Frame", nil, f)
    timeBtnFrame:SetPoint("TOPRIGHT", f, "TOPRIGHT", -44, -44)
    timeBtnFrame:SetSize(410, BUTTON_HEIGHT)

    local timeButtons = {}
    local prevBtn = nil
    for i, range in ipairs(timeRanges) do
        local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        btn:SetSize(range.key == "hour" and 66 or 50, BUTTON_HEIGHT)
        if i == 1 then
            btn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -44, -42)
        else
            btn:SetPoint("RIGHT", prevBtn, "LEFT", -6, 0)
        end
        btn:SetText(range.label)
        EA_SkinButton(btn)
        btn:SetScript("OnClick", function(self)
            f.timeRange = range.key
            for _, b in ipairs(timeButtons) do
                EA_SetTextButtonActive(b, false)
            end
            EA_SetTextButtonActive(self, true)
            f:Refresh()
        end)
        timeButtons[i] = btn
        prevBtn = btn
    end
    EA_SetTextButtonActive(timeButtons[3], true)

    local chartFrame = CreateFrame("Frame", nil, f)
    chartFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -HEADER_HEIGHT - BUTTON_HEIGHT - 14)
    chartFrame:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -HEADER_HEIGHT - BUTTON_HEIGHT - 14)
    chartFrame:SetHeight(CHART_HEIGHT)
    EA_SkinPanel(chartFrame, "panel")

    EA_ApplyOutline(chartFrame, 0.85)
    f.chartPanel = chartFrame
    chartFrame.linePool = {}
    chartFrame.points = {}

    local plot = CreateFrame("Frame", nil, chartFrame)
    plot:SetPoint("TOPLEFT", chartFrame, "TOPLEFT", 58, -16)
    plot:SetPoint("BOTTOMRIGHT", chartFrame, "BOTTOMRIGHT", -12, 24)
    plot:EnableMouse(true)
    chartFrame.plot = plot

    local chartBg = plot:CreateTexture(nil, "BACKGROUND")
    chartBg:SetAllPoints(plot)
    if EAStyle then
        local p = EAStyle:Palette()
        chartBg:SetColorTexture(p.plot[1], p.plot[2], p.plot[3], 0.86)
    else
        chartBg:SetColorTexture(0, 0, 0, 0.5)
    end

    local gridLines = {}
    for i = 1, 5 do
        local line = plot:CreateTexture(nil, "BACKGROUND")
        line:SetHeight(1)
        if EAStyle then
            local p = EAStyle:Palette()
            line:SetColorTexture(p.border[1], p.border[2], p.border[3], 0.18)
        else
            line:SetColorTexture(0.3, 0.3, 0.3, 0.35)
        end
        gridLines[i] = line
    end
    chartFrame.gridLines = gridLines

    chartFrame.yLabels = {}
    for i = 1, 5 do
        chartFrame.yLabels[i] = EA_GoldBillMakeText(chartFrame, 9, "muted", "RIGHT")
        chartFrame.yLabels[i]:SetWidth(52)
    end
    chartFrame.xLabels = {}
    for i = 1, 3 do
        chartFrame.xLabels[i] = EA_GoldBillMakeText(chartFrame, 9, "muted",
            i == 1 and "LEFT" or i == 2 and "CENTER" or "RIGHT")
        chartFrame.xLabels[i]:SetWidth(70)
    end

    chartFrame.crossV = plot:CreateTexture(nil, "OVERLAY")
    chartFrame.crossV:SetTexture("Interface\\Buttons\\WHITE8X8")
    chartFrame.crossV:Hide()
    chartFrame.marker = plot:CreateTexture(nil, "OVERLAY")
    chartFrame.marker:SetTexture("Interface\\Buttons\\WHITE8X8")
    chartFrame.marker:SetSize(7, 7)
    chartFrame.marker:Hide()
    if EAStyle then
        local p = EAStyle:Palette()
        chartFrame.crossV:SetColorTexture(p.accent[1], p.accent[2], p.accent[3], 0.45)
        chartFrame.marker:SetColorTexture(p.accent[1], p.accent[2], p.accent[3], 1)
    else
        chartFrame.crossV:SetColorTexture(0.4, 0.8, 1, 0.45)
        chartFrame.marker:SetColorTexture(0.4, 0.8, 1, 1)
    end

    local tip = CreateFrame("Frame", nil, chartFrame, "BackdropTemplate")
    tip:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    if EAStyle then
        local p = EAStyle:Palette()
        tip:SetBackdropColor(p.panel[1], p.panel[2], p.panel[3], 0.96)
        tip:SetBackdropBorderColor(p.accent[1], p.accent[2], p.accent[3], 1)
    else
        tip:SetBackdropColor(0.08, 0.08, 0.11, 0.96)
        tip:SetBackdropBorderColor(0.4, 0.8, 1, 1)
    end
    tip:SetFrameLevel(chartFrame:GetFrameLevel() + 20)
    tip.title = EA_GoldBillMakeText(tip, 11, "accent", "LEFT")
    tip.title:SetPoint("TOPLEFT", tip, "TOPLEFT", 8, -6)
    tip.body = EA_GoldBillMakeText(tip, 11, "text", "LEFT")
    tip.body:SetPoint("TOPLEFT", tip.title, "BOTTOMLEFT", 0, -3)
    tip:Hide()
    chartFrame.tip = tip

    if EAStyle then
        EAStyle:OnTheme(function(p)
            if p.blizzard then
                chartBg:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background-Dark")
                if chartBg.SetHorizTile then chartBg:SetHorizTile(true) end
                if chartBg.SetVertTile then chartBg:SetVertTile(true) end
                chartBg:SetVertexColor(1, 1, 1, 1)
                chartBg:SetAlpha(1)
                if tip.SetBackdrop and EAStyle.GetBackdrop then
                    tip:SetBackdrop(EAStyle:GetBackdrop(p, "panel"))
                end
                if tip.SetBackdropColor then
                    tip:SetBackdropColor(1, 1, 1, 1)
                    tip:SetBackdropBorderColor(p.border[1], p.border[2], p.border[3], 1)
                end
            else
                if chartBg.SetHorizTile then chartBg:SetHorizTile(false) end
                if chartBg.SetVertTile then chartBg:SetVertTile(false) end
                chartBg:SetColorTexture(p.plot[1], p.plot[2], p.plot[3], 0.86)
                if tip.SetBackdrop then
                    tip:SetBackdrop({
                        bgFile = "Interface\\Buttons\\WHITE8X8",
                        edgeFile = "Interface\\Buttons\\WHITE8X8",
                        edgeSize = 1,
                    })
                end
                if tip.SetBackdropColor then
                    tip:SetBackdropColor(p.panel[1], p.panel[2], p.panel[3], 0.96)
                    tip:SetBackdropBorderColor(p.accent[1], p.accent[2], p.accent[3], 1)
                end
            end
            for _, grid in ipairs(gridLines) do
                grid:SetColorTexture(p.border[1], p.border[2], p.border[3], p.blizzard and 0.30 or 0.18)
            end
            chartFrame.crossV:SetColorTexture(p.accent[1], p.accent[2], p.accent[3], p.blizzard and 0.55 or 0.45)
            chartFrame.marker:SetColorTexture(p.accent[1], p.accent[2], p.accent[3], 1)
        end)
    end

    chartFrame.empty = EA_GoldBillMakeText(chartFrame, 13, "muted", "CENTER")
    chartFrame.empty:SetPoint("CENTER", plot, "CENTER", 0, 0)
    chartFrame.empty:Hide()

    plot:SetScript("OnEnter", function(self)
        self:SetScript("OnUpdate", function(inner)
            EA_GoldBillUpdateHover(inner, chartFrame)
        end)
    end)
    plot:SetScript("OnLeave", function(self)
        self:SetScript("OnUpdate", nil)
        chartFrame.hoverKey = nil
        chartFrame.crossV:Hide()
        chartFrame.marker:Hide()
        chartFrame.tip:Hide()
    end)

    local statsFrame = CreateFrame("Frame", nil, f, "BackdropTemplate")
    statsFrame:SetPoint("TOPLEFT", chartFrame, "BOTTOMLEFT", 0, -12)
    statsFrame:SetPoint("TOPRIGHT", chartFrame, "BOTTOMRIGHT", 0, -12)
    statsFrame:SetHeight(64)
    EA_SkinPanel(statsFrame, "panel")
    EA_ApplyOutline(statsFrame, 0.65)

    f.summaryFields = {}
    local summaryCols = {
        { key = "range", title = "区间", rows = { { "low", "最低" }, { "high", "最高" } } },
        { key = "daily", title = "日均", rows = { { "sales", "拍卖件数" }, { "purchases", "购买件数" } } },
        { key = "top", title = "单项", rows = { { "sale", "最高拍卖" }, { "purchase", "最高购买" } } },
    }
    local colWidth = math.floor((FRAME_WIDTH - 24 - 2) / 3)
    for i, colInfo in ipairs(summaryCols) do
        local col = CreateFrame("Frame", nil, statsFrame)
        col:SetWidth(colWidth)
        col:SetPoint("TOP", statsFrame, "TOP", (i - 2) * colWidth, -8)
        col:SetHeight(54)
        col.title = EA_GoldBillMakeText(col, 11, "accent", "LEFT")
        col.title:SetPoint("TOPLEFT", col, "TOPLEFT", 10, 0)
        col.title:SetText(colInfo.title)
        for _, rowDef in ipairs(colInfo.rows) do
            local anchor = col.lastRow or col.title
            local row = EA_GoldBillMakeStatRow(col, anchor, rowDef[2], col.lastRow and -1 or -4)
            f.summaryFields[colInfo.key .. rowDef[1]] = row.value
            col.lastRow = row
        end
        if i > 1 then
            local sep = EA_CreateLine(statsFrame, "vertical", 0.55)
            sep:SetPoint("TOP", statsFrame, "TOP", (i - 2) * colWidth - colWidth / 2, -8)
            sep:SetPoint("BOTTOM", statsFrame, "BOTTOM", (i - 2) * colWidth - colWidth / 2, 8)
        end
    end

    local detailFrame = CreateFrame("Frame", nil, f, "BackdropTemplate")
    detailFrame:SetPoint("TOPLEFT", statsFrame, "BOTTOMLEFT", 0, -8)
    detailFrame:SetPoint("TOPRIGHT", statsFrame, "BOTTOMRIGHT", 0, -8)
    detailFrame:SetHeight(94)
    EA_SkinPanel(detailFrame, "panel")
    EA_ApplyOutline(detailFrame, 0.65)
    f.detailFields = {}

    local detailCols = {
        { key = "sales", title = "拍卖", rows = { { "total", "总收入" }, { "avg", "日均收入" }, { "top", "最高物品" } } },
        { key = "expenses", title = "购买", rows = { { "total", "总支出" }, { "avg", "日均支出" }, { "top", "最高物品" } } },
        { key = "profit", title = "利润", rows = { { "total", "净变化" }, { "avg", "日均变化" }, { "count", "记录数" } } },
    }
    local detailColWidth = math.floor((FRAME_WIDTH - 24 - 2) / 3)
    for i, colInfo in ipairs(detailCols) do
        local col = CreateFrame("Frame", nil, detailFrame)
        col:SetWidth(detailColWidth)
        col:SetPoint("TOP", detailFrame, "TOP", (i - 2) * detailColWidth, -9)
        col:SetHeight(82)
        col.title = EA_GoldBillMakeText(col, 11, "accent", "LEFT")
        col.title:SetPoint("TOPLEFT", col, "TOPLEFT", 10, 0)
        col.title:SetText(colInfo.title)
        for _, rowDef in ipairs(colInfo.rows) do
            local anchor = col.lastRow or col.title
            local row = EA_GoldBillMakeStatRow(col, anchor, rowDef[2], col.lastRow and -1 or -4)
            f.detailFields[colInfo.key .. rowDef[1]] = row.value
            col.lastRow = row
        end
        if i > 1 then
            local sep = EA_CreateLine(detailFrame, "vertical", 0.55)
            sep:SetPoint("TOP", detailFrame, "TOP", (i - 2) * detailColWidth - detailColWidth / 2, -8)
            sep:SetPoint("BOTTOM", detailFrame, "BOTTOM", (i - 2) * detailColWidth - detailColWidth / 2, 8)
        end
    end

    function f:Refresh()
        local days = 7
        local hours = nil
        for _, range in ipairs(timeRanges) do
            if range.key == self.timeRange then
                days = range.days or 1
                hours = range.hours
                break
            end
        end

        local selectedChars = #self.selectedChars > 0 and self.selectedChars or nil
        local history
        if hours and type(EasyAuction_GetGoldHourlyHistory) == "function" then
            history = EasyAuction_GetGoldHourlyHistory(hours, selectedChars)
        else
            history = EasyAuction_GetGoldHistory(days, selectedChars)
        end
        local currentGold = EA_GoldBillCurrentGold(self.selectedChars)
        if #history > 0 then
            history[#history].gold = currentGold
        end

        local minGold, maxGold = math.huge, 0
        local validCount, firstGold = 0, nil

        for _, entry in ipairs(history) do
            local gold = tonumber(entry.gold) or 0
            if gold > 0 then
                minGold = math.min(minGold, gold)
                maxGold = math.max(maxGold, gold)
                validCount = validCount + 1
                if not firstGold then
                    firstGold = gold
                end
            end
        end

        if validCount == 0 then
            minGold, maxGold, firstGold = 0, 0, 0
        end

        local deltaGold = currentGold - (firstGold or 0)
        local statDays = hours and math.max(hours / 24, 1 / 24) or math.max(days, 1)
        local ops = EA_GoldBillOperationSummary(statDays, self.selectedChars)
        local profitAvg = math.floor((ops.profitTotal or 0) / statDays)

        self.summaryFields.rangelow:SetText(EA_GoldBillCoinText(minGold))
        self.summaryFields.rangehigh:SetText(EA_GoldBillCoinText(maxGold))
        self.summaryFields.dailysales:SetText(tostring(math.floor((ops.saleCount or 0) / statDays + 0.5)))
        self.summaryFields.dailypurchases:SetText(tostring(math.floor((ops.buyCount or 0) / statDays + 0.5)))
        self.summaryFields.topsale:SetText(EA_GoldBillCoinText(ops.saleTopValue or 0))
        self.summaryFields.toppurchase:SetText(EA_GoldBillCoinText(ops.buyTopValue or 0))

        self.detailFields.salestotal:SetText(EA_GoldBillCoinText(ops.saleTotal or 0))
        self.detailFields.salesavg:SetText(EA_GoldBillCoinText(math.floor((ops.saleTotal or 0) / statDays)))
        EA_GoldBillSetItemText(self.detailFields.salestop, ops.saleTopName, ops.saleTopItemID)
        self.detailFields.expensestotal:SetText(EA_GoldBillCoinText(ops.buyTotal or 0))
        self.detailFields.expensesavg:SetText(EA_GoldBillCoinText(math.floor((ops.buyTotal or 0) / statDays)))
        EA_GoldBillSetItemText(self.detailFields.expensestop, ops.buyTopName, ops.buyTopItemID)
        self.detailFields.profittotal:SetText(EA_GoldBillSignedText(ops.profitTotal or 0))
        EA_GoldBillTrendColor(self.detailFields.profittotal, ops.profitTotal or 0)
        self.detailFields.profitavg:SetText(EA_GoldBillSignedText(profitAvg))
        EA_GoldBillTrendColor(self.detailFields.profitavg, profitAvg)
        self.detailFields.profitcount:SetText(tostring(ops.opCount or 0))

        title:SetText("金币账单")
        if self.headerMoney then
            local text = "当前 " .. EA_GoldBillPlainMoney(currentGold)
            if validCount > 0 and deltaGold ~= 0 then
                text = text .. "  变化 " .. EA_GoldBillPlainMoney(deltaGold, true)
            end
            self.headerMoney:SetText(text)
            EA_GoldBillTrendColor(self.headerMoney, deltaGold)
        end
        EA_GoldBillRenderChart(self, history, minGold, maxGold)
    end

    f:Refresh()
    EasyAuction_GoldBillFrame = f
end

-- 注册 ADDON_LOADED 事件，在插件加载完成后初始化数据库引用
local eaFrameInit = CreateFrame("Frame")
eaFrameInit:RegisterEvent("ADDON_LOADED")
eaFrameInit:SetScript("OnEvent", function(self, event, addon)
    if addon == "EasyAuction" then
        InitFrameDB()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
