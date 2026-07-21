-- EasyAuctionStyle - TokenTrend-inspired financial terminal UI primitives.

local _, ns = ...

local Style = {}
ns.Style = Style
_G.EasyAuctionStyle = Style

local function hex(s)
    return {
        tonumber(s:sub(1, 2), 16) / 255,
        tonumber(s:sub(3, 4), 16) / 255,
        tonumber(s:sub(5, 6), 16) / 255,
    }
end

local function clamp(v)
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

local function mixInto(out, a, b, ratio)
    out[1] = clamp(a[1] * (1 - ratio) + b[1] * ratio)
    out[2] = clamp(a[2] * (1 - ratio) + b[2] * ratio)
    out[3] = clamp(a[3] * (1 - ratio) + b[3] * ratio)
    return out
end

Style.BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
}

Style.LEGACY260_WINDOW_BACKDROP = {
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 18,
    insets = { left = 6, right = 6, top = 6, bottom = 6 },
}

Style.LEGACY260_PANEL_BACKDROP = {
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

Style.BLIZZARD_WINDOW_BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
}

Style.BLIZZARD_PANEL_BACKDROP = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

Style.Palettes = {
    legacy260 = {
        key = "legacy260",
        name = "经典主题",
        legacy = true,
        bg = { 0.10, 0.10, 0.13 },
        panel = { 0.15, 0.14, 0.20 },
        plot = { 0.05, 0.05, 0.07 },
        border = { 0.70, 0.60, 1.00 },
        text = hex("FFFFFF"),
        muted = hex("B8B8C8"),
        accent = hex("FFD200"),
        accent2 = hex("AEDDFF"),
    },
    blizzard = {
        key = "blizzard",
        name = "暴雪默认风格",
        blizzard = true,
        bg = { 0.09, 0.07, 0.04 },
        panel = { 0.02, 0.02, 0.02 },
        plot = { 0.00, 0.00, 0.00 },
        border = { 0.78, 0.64, 0.33 },
        backdropTint = { 1, 1, 1 },
        text = hex("FFFFFF"),
        muted = hex("B8B8B8"),
        accent = hex("FFD100"),
        accent2 = hex("FFFFFF"),
    },
    terminal = {
        key = "terminal",
        name = "交易终端",
        bg = hex("18181B"),
        panel = hex("212126"),
        plot = hex("141418"),
        border = hex("3F3F46"),
        text = hex("F4F4F5"),
        muted = hex("A1A1AA"),
        accent = hex("06B6D4"),
        accent2 = hex("38BDF8"),
    },
    lunar = {
        key = "lunar",
        name = "月光交易所",
        bg = hex("1A1C23"),
        panel = hex("23262F"),
        plot = hex("151821"),
        border = hex("5E6B7E"),
        text = hex("E2E8F0"),
        muted = hex("94A3B8"),
        accent = hex("3B82F6"),
        accent2 = hex("60A5FA"),
    },
    amber = {
        key = "amber",
        name = "赤金拍行",
        bg = hex("1F1A14"),
        panel = hex("292116"),
        plot = hex("17130F"),
        border = hex("6B4F2A"),
        text = hex("FFF7ED"),
        muted = hex("D6B891"),
        accent = hex("F59E0B"),
        accent2 = hex("FBBF24"),
    },
    jade = {
        key = "jade",
        name = "翡翠账本",
        bg = hex("111C18"),
        panel = hex("182720"),
        plot = hex("0D1714"),
        border = hex("2F6B55"),
        text = hex("ECFDF5"),
        muted = hex("8DC9B2"),
        accent = hex("10B981"),
        accent2 = hex("34D399"),
    },
    violet = {
        key = "violet",
        name = "奥术紫晶",
        bg = hex("191622"),
        panel = hex("241F31"),
        plot = hex("14101D"),
        border = hex("69548F"),
        text = hex("F5F3FF"),
        muted = hex("B8A9D9"),
        accent = hex("A78BFA"),
        accent2 = hex("C4B5FD"),
    },
    fan = {
        key = "fan",
        name = "粉丝少女",
        bg = hex("211620"),
        panel = hex("2B1B2A"),
        plot = hex("170F18"),
        border = hex("8B5A7C"),
        text = hex("FFF1F7"),
        muted = hex("E8AFC9"),
        accent = hex("F472B6"),
        accent2 = hex("F9A8D4"),
    },
    class = {
        key = "class",
        name = "职业徽记",
        bg = hex("171719"),
        panel = hex("202024"),
        plot = hex("121214"),
        border = hex("3F3F46"),
        text = hex("F4F4F5"),
        muted = hex("A1A1AA"),
        accent = hex("06B6D4"),
        accent2 = hex("38BDF8"),
    },
}

Style.DefaultPalette = "blizzard"
Style.PaletteOrder = { "blizzard", "terminal", "legacy260", "lunar", "amber", "jade", "violet", "fan", "class" }
Style.ClassPalette = {}
Style.ClassAccent = {}
Style.ClassAccent2 = {}
Style.ClassBorder = {}
Style.White = { 1, 1, 1 }
Style.Bull = hex("22C55E")
Style.Bear = hex("EF4444")
Style.Neutral = hex("94A3B8")
Style.Warning = hex("F59E0B")
Style.Font = STANDARD_TEXT_FONT
Style.FontNumber = NumberFontNormal and NumberFontNormal:GetFont() or STANDARD_TEXT_FONT
Style.WindowInset = 3
Style.ContentInset = 8
Style.TabHeight = 22
Style.FooterHeight = 24
Style.ButtonHeight = 22

Style.themed = {}

function Style:ClassColor()
    local classFile
    local unitClass = _G.UnitClass
    if unitClass then
        local _, detectedClass = unitClass("player")
        classFile = detectedClass
    end
    local colors = (_G.CUSTOM_CLASS_COLORS and classFile and _G.CUSTOM_CLASS_COLORS[classFile])
        or (_G.RAID_CLASS_COLORS and classFile and _G.RAID_CLASS_COLORS[classFile])
    if colors then
        local accent = self.ClassAccent
        accent[1] = clamp(colors.r or colors[1] or 1)
        accent[2] = clamp(colors.g or colors[2] or 1)
        accent[3] = clamp(colors.b or colors[3] or 1)
        return accent
    end
    return self.Palettes.terminal.accent
end

function Style:ClassThemePalette()
    local base = self.Palettes.class
    local accent = self:ClassColor()
    local p = self.ClassPalette
    p.key = base.key
    p.name = base.name
    p.bg = base.bg
    p.panel = base.panel
    p.plot = base.plot
    p.text = base.text
    p.muted = base.muted
    p.accent = accent
    p.accent2 = mixInto(self.ClassAccent2, accent, self.White, 0.28)
    p.border = mixInto(self.ClassBorder, accent, base.border, 0.48)
    return p
end

function Style:NormalizePaletteKey(key)
    if key == "native" then
        key = "blizzard"
    end
    if key == "class" or self.Palettes[key] then
        return key
    end
    return self.DefaultPalette
end

function Style:Palette()
    local db = _G.EasyAuctionDB
    local key = self:NormalizePaletteKey(db and db.uiPalette or self.DefaultPalette)
    if db and db.uiPalette ~= key then
        db.uiPalette = key
    end
    if key == "class" then
        return self:ClassThemePalette()
    end
    return self.Palettes[key] or self.Palettes[self.DefaultPalette]
end

function Style:IsBlizzard()
    local p = self:Palette()
    return p and p.blizzard
end

function Style:OnTheme(fn)
    self.themed[#self.themed + 1] = fn
    fn(self:Palette())
end

function Style:GetBackdrop(p, role)
    if p and p.blizzard then
        if role == "window" then
            return self.BLIZZARD_WINDOW_BACKDROP
        end
        return self.BLIZZARD_PANEL_BACKDROP
    end
    if p and p.legacy then
        if role == "window" then
            return self.LEGACY260_WINDOW_BACKDROP
        end
        return self.LEGACY260_PANEL_BACKDROP
    end
    return self.BACKDROP
end

function Style:ApplyTheme()
    local p = self:Palette()
    for i = 1, #self.themed do
        self.themed[i](p)
    end
end

function Style:AnnouncePalette(key)
    local p = self:Palette()
    key = key or (p and p.key) or self.DefaultPalette
    local r = math.floor((p.accent[1] or 1) * 255 + 0.5)
    local g = math.floor((p.accent[2] or 1) * 255 + 0.5)
    local b = math.floor((p.accent[3] or 1) * 255 + 0.5)
    print(string.format("|cff%02X%02X%02X[EasyAuction]|r 界面主题：%s", r, g, b, p.name or key))
end

function Style:SetPalette(key, silent)
    local db = _G.EasyAuctionDB
    if not db then return nil end
    key = self:NormalizePaletteKey(key)
    db.uiPalette = key
    self:ApplyTheme()
    if not silent then
        self:AnnouncePalette(key)
    end
    return self:Palette()
end

function Style:CyclePalette()
    local db = _G.EasyAuctionDB
    if not db then return end
    local current = self:NormalizePaletteKey(db.uiPalette or self.DefaultPalette)
    local nextKey = self.PaletteOrder[1]
    for i = 1, #self.PaletteOrder do
        if self.PaletteOrder[i] == current then
            nextKey = self.PaletteOrder[(i % #self.PaletteOrder) + 1]
            break
        end
    end
    return self:SetPalette(nextKey)
end

function Style:EnsureBackdrop(frame)
    if frame and not frame.SetBackdrop and BackdropTemplateMixin then
        Mixin(frame, BackdropTemplateMixin)
    end
end

local function EAStyle_ShowTexture(texture, file, atlas, useAtlasSize)
    if not texture then return end
    if atlas and texture.SetAtlas then
        texture:SetAtlas(atlas, useAtlasSize and true or false)
    elseif file then
        texture:SetTexture(file)
    end
    texture:SetAlpha(1)
    texture:Show()
end

local function EAStyle_ClearButtonTexture(texture)
    if not texture then return end
    if texture.SetTexture then
        texture:SetTexture(nil)
    end
    texture:SetAlpha(0)
    texture:Hide()
end

function Style:SetNativeFrameRegions(frame, p)
    if not frame then return end
    local showNative = p and p.blizzard
    if frame.NineSlice then
        if showNative then
            frame.NineSlice:Show()
        else
            frame.NineSlice:Hide()
        end
    end
    if frame.Inset then
        if showNative then
            frame.Inset:Show()
        else
            frame.Inset:Hide()
        end
    end
end

function Style:SyncNativeFrameRegions(frame)
    if not frame or frame.__EAStyleNativeRegionHooked then return end
    frame.__EAStyleNativeRegionHooked = true
    self:OnTheme(function(p)
        self:SetNativeFrameRegions(frame, p)
    end)
end

function Style:Skin(frame, role)
    if not frame then return frame end
    self:EnsureBackdrop(frame)
    if frame.SetBackdrop then
        frame:SetBackdrop(self:GetBackdrop(self:Palette(), role or frame.__EAStyleRole or "panel"))
    end
    frame.__EAStyleRole = role or frame.__EAStyleRole or "panel"
    self:OnTheme(function(p)
        if not frame.SetBackdropColor then return end
        if frame.SetBackdrop then
            frame:SetBackdrop(self:GetBackdrop(p, frame.__EAStyleRole))
        end
        local bg = p.panel
        if frame.__EAStyleRole == "window" then
            bg = p.bg
        elseif frame.__EAStyleRole == "plot" then
            bg = p.plot or p.bg
        end
        local backdropColor = bg
        local alpha = 1
        local borderAlpha = 1
        if p.legacy then
            alpha = (frame.__EAStyleRole == "window") and 0.97 or 0.93
            borderAlpha = (frame.__EAStyleRole == "window") and 1 or 0.80
        elseif p.blizzard then
            backdropColor = p.backdropTint or self.White
            alpha = 1
            borderAlpha = 1
        end
        frame:SetBackdropColor(backdropColor[1], backdropColor[2], backdropColor[3], alpha)
        frame:SetBackdropBorderColor(p.border[1], p.border[2], p.border[3], borderAlpha)
        self:SetNativeFrameRegions(frame, p)
    end)
    return frame
end

function Style:SkinExistingFrame(frame, role)
    self:Skin(frame, role)
    self:SyncNativeFrameRegions(frame)
    return frame
end

function Style:Text(parent, layer, fontPath, size, flags, role)
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    fs:SetFont(fontPath or self.Font, size or 12, flags or "")
    fs:SetShadowOffset(1, -1)
    self:SkinText(fs, role)
    return fs
end

function Style:SkinText(fs, role)
    if not fs then return fs end
    role = role or "text"
    self:OnTheme(function(p)
        local col = p.text
        if role == "muted" then
            col = p.muted
        elseif role == "accent" then
            col = p.accent
        elseif role == "warning" then
            col = self.Warning
        elseif role == "bull" then
            col = self.Bull
        elseif role == "bear" then
            col = self.Bear
        end
        fs:SetTextColor(col[1], col[2], col[3])
    end)
    return fs
end

function Style:Button(parent, text, width, onClick)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(width or 72, self.ButtonHeight)
    b:SetText(text or "")
    self:SkinButton(b)
    if onClick then
        b:SetScript("OnClick", onClick)
    end
    return b
end

function Style:EnsureButtonBorder(button)
    if not button or button.__EAStyleBorder then return end
    local border = {}
    border.top = button:CreateTexture(nil, "OVERLAY")
    border.top:SetHeight(1)
    border.top:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    border.top:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
    border.bottom = button:CreateTexture(nil, "OVERLAY")
    border.bottom:SetHeight(1)
    border.bottom:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
    border.bottom:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    border.left = button:CreateTexture(nil, "OVERLAY")
    border.left:SetWidth(1)
    border.left:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    border.left:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
    border.right = button:CreateTexture(nil, "OVERLAY")
    border.right:SetWidth(1)
    border.right:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
    border.right:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    for _, tex in pairs(border) do
        tex.__EAStyleBorder = true
        tex:SetTexture("Interface\\Buttons\\WHITE8X8")
        tex:Show()
    end
    button.__EAStyleBorder = border
end

function Style:SetButtonBorderColor(button, color, alpha)
    if not button then return end
    self:EnsureButtonBorder(button)
    if not button.__EAStyleBorder then return end
    alpha = alpha or 1
    for _, tex in pairs(button.__EAStyleBorder) do
        tex:SetColorTexture(color[1], color[2], color[3], alpha)
        tex:Show()
    end
end

function Style.SetButtonBorderShown(_, button, shown)
    if not button or not button.__EAStyleBorder then return end
    for _, tex in pairs(button.__EAStyleBorder) do
        if shown then
            tex:Show()
        else
            tex:Hide()
        end
    end
end

function Style:EnsureBlizzardButtonPieces(button)
    if not button then return end
    local left = button.Left or button.__EAStyleNativeLeft
    local middle = button.Middle or button.__EAStyleNativeMiddle
    local right = button.Right or button.__EAStyleNativeRight
    if not (left and middle and right) then
        left = button.__EAStyleNativeLeft or button:CreateTexture(nil, "BACKGROUND")
        middle = button.__EAStyleNativeMiddle or button:CreateTexture(nil, "BACKGROUND")
        right = button.__EAStyleNativeRight or button:CreateTexture(nil, "BACKGROUND")
        button.__EAStyleNativeLeft = left
        button.__EAStyleNativeMiddle = middle
        button.__EAStyleNativeRight = right
    end
    left.__EAStyleNativePiece = true
    middle.__EAStyleNativePiece = true
    right.__EAStyleNativePiece = true

    left:ClearAllPoints()
    left:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
    left:SetWidth(12)
    left:SetTexCoord(0, 0.09375, 0, 0.6875)

    right:ClearAllPoints()
    right:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    right:SetWidth(12)
    right:SetTexCoord(0.53125, 0.625, 0, 0.6875)

    middle:ClearAllPoints()
    middle:SetPoint("TOPLEFT", left, "TOPRIGHT", 0, 0)
    middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)
    middle:SetTexCoord(0.09375, 0.53125, 0, 0.6875)

    return left, middle, right
end

function Style:RestoreBlizzardButtonTextures(button, disabled, pushed)
    if not button then return end
    local file = "Interface\\Buttons\\UI-Panel-Button-Up"
    if disabled then
        file = "Interface\\Buttons\\UI-Panel-Button-Disabled"
    elseif pushed then
        file = "Interface\\Buttons\\UI-Panel-Button-Down"
    end
    local left, middle, right = self:EnsureBlizzardButtonPieces(button)
    EAStyle_ShowTexture(left, file)
    EAStyle_ShowTexture(middle, file)
    EAStyle_ShowTexture(right, file)
    if button.SetHighlightTexture then
        button:SetHighlightTexture("Interface\\Buttons\\UI-Panel-Button-Highlight", "ADD")
        local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
        if highlight then
            highlight:SetTexCoord(0, 0.625, 0, 0.6875)
            highlight:SetAlpha(1)
        end
    end
end

function Style:ApplyBlizzardCloseButtonStyle(button, label)
    if not button then return end
    self:SetButtonBorderShown(button, false)
    if button.SetBackdrop then
        button:SetBackdrop(nil)
    end
    if button.SetNormalTexture then
        button:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
        button:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
        button:SetDisabledTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Disabled")
        button:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
    end
    for _, tex in ipairs({
        button.GetNormalTexture and button:GetNormalTexture(),
        button.GetPushedTexture and button:GetPushedTexture(),
        button.GetDisabledTexture and button:GetDisabledTexture(),
        button.GetHighlightTexture and button:GetHighlightTexture(),
    }) do
        if tex then
            tex:SetAlpha(1)
            tex:Show()
        end
    end
    if button.__EAStyleNativeLeft then
        EAStyle_ClearButtonTexture(button.__EAStyleNativeLeft)
        EAStyle_ClearButtonTexture(button.__EAStyleNativeMiddle)
        EAStyle_ClearButtonTexture(button.__EAStyleNativeRight)
    end
    if label then
        label:SetAlpha(0)
        label:Hide()
    end
end

function Style:ApplyBlizzardButtonStyle(button, label, p, hover, pushed)
    if not button then return end
    if button.__EAStyleClose then
        self:ApplyBlizzardCloseButtonStyle(button, label)
        return
    end
    self:SetButtonBorderShown(button, false)
    if button.SetBackdrop then
        button:SetBackdrop(nil)
    end
    self:RestoreBlizzardButtonTextures(button, button.__EAStyleDisabled, pushed or button.__EAStyleActive)
    if button.LockHighlight and button.UnlockHighlight then
        if button.__EAStyleActive and not button.__EAStyleDisabled then
            button:LockHighlight()
        else
            button:UnlockHighlight()
        end
    end
    if label then
        label:Show()
        label:SetAlpha(1)
        label:SetFont(self.Font, 12, "")
        label:SetShadowOffset(0, 0)
        if button.__EAStyleDisabled then
            label:SetTextColor(0.50, 0.50, 0.50, 1)
        elseif button.__EAStyleActive then
            label:SetTextColor(1, 1, 1, 1)
        elseif hover then
            label:SetTextColor(1, 1, 1, 1)
        else
            label:SetTextColor(p.accent[1], p.accent[2], p.accent[3], 1)
        end
    end
end

function Style:HideButtonTextures(button)
    if not button then return end
    local regions = { button:GetRegions() }
    for i = 1, #regions do
        local region = regions[i]
        if region and region.GetObjectType and region:GetObjectType() == "Texture"
            and not region.__EAStyleBorder and not region.__EAStylePreserve then
            region:SetTexture(nil)
            region:SetAlpha(0)
            region:Hide()
        end
    end
    if button.GetNormalTexture and button:GetNormalTexture() then
        button:GetNormalTexture():SetAlpha(0)
        button:GetNormalTexture():Hide()
    end
    if button.GetPushedTexture and button:GetPushedTexture() then
        button:GetPushedTexture():SetAlpha(0)
        button:GetPushedTexture():Hide()
    end
    if button.GetDisabledTexture and button:GetDisabledTexture() then
        button:GetDisabledTexture():SetAlpha(0)
        button:GetDisabledTexture():Hide()
    end
    if button.GetHighlightTexture and button:GetHighlightTexture() then
        button:GetHighlightTexture():SetAlpha(0)
        button:GetHighlightTexture():Hide()
    end
    self:SetButtonBorderShown(button, true)
end

function Style:ApplyLegacyButtonStyle(button, label, p, hover)
    if not button then return end
    self:HideButtonTextures(button)
    if button.SetBackdrop then
        button:SetBackdrop(self.BACKDROP)
    end
    if button.SetBackdropColor then
        if button.__EAStyleDisabled then
            button:SetBackdropColor(0.08, 0.07, 0.09, 0.78)
            button:SetBackdropBorderColor(p.border[1], p.border[2], p.border[3], 0.35)
        elseif button.__EAStyleActive then
            button:SetBackdropColor(0.22, 0.08, 0.03, 0.96)
            button:SetBackdropBorderColor(p.accent[1], p.accent[2], p.accent[3], 1)
        elseif hover then
            button:SetBackdropColor(0.42, 0.04, 0.04, 0.96)
            button:SetBackdropBorderColor(p.accent2[1], p.accent2[2], p.accent2[3], 0.95)
        else
            button:SetBackdropColor(0.26, 0.02, 0.02, 0.92)
            button:SetBackdropBorderColor(p.border[1], p.border[2], p.border[3], 0.85)
        end
    end
    if button.__EAStyleDisabled then
        self:SetButtonBorderColor(button, p.border, 0.35)
    elseif button.__EAStyleActive then
        self:SetButtonBorderColor(button, p.accent, 1)
    elseif hover then
        self:SetButtonBorderColor(button, p.accent2, 0.95)
    else
        self:SetButtonBorderColor(button, p.border, 0.85)
    end
    if label then
        label:Show()
        label:SetAlpha(1)
        label:SetShadowOffset(1, -1)
        if button.__EAStyleDisabled then
            label:SetTextColor(p.muted[1], p.muted[2], p.muted[3], 0.65)
        elseif button.__EAStyleActive then
            label:SetTextColor(p.accent[1], p.accent[2], p.accent[3])
        elseif hover then
            label:SetTextColor(p.accent2[1], p.accent2[2], p.accent2[3])
        else
            label:SetTextColor(p.text[1], p.text[2], p.text[3])
        end
    end
end

function Style:SkinButton(button)
    if not button then return button end
    local text = button:GetText()
    self:EnsureBackdrop(button)
    if button.SetBackdrop then
        button:SetBackdrop(self.BACKDROP)
    end
    self:EnsureButtonBorder(button)

    local label = button:GetFontString()
    if not label then
        label = button:CreateFontString(nil, "OVERLAY")
        label:SetPoint("CENTER")
        button:SetFontString(label)
    end
    button.label = label
    if text then
        button:SetText(text)
    end
    label:SetFont(self.Font, 12, "")
    label:SetShadowOffset(1, -1)

    local function rest()
        local p = self:Palette()
        if p.blizzard then
            self:ApplyBlizzardButtonStyle(button, label, p)
            return
        end
        if p.legacy then
            self:ApplyLegacyButtonStyle(button, label, p)
            return
        end
        self:HideButtonTextures(button)
        if button.SetBackdrop then
            button:SetBackdrop(self.BACKDROP)
        end
        if button.SetBackdropColor then
            if button.__EAStyleActive then
                button:SetBackdropColor(p.accent[1], p.accent[2], p.accent[3], 0.18)
                button:SetBackdropBorderColor(p.accent[1], p.accent[2], p.accent[3], 1)
            elseif button.__EAStyleDisabled then
                button:SetBackdropColor(p.bg[1], p.bg[2], p.bg[3], 0.72)
                button:SetBackdropBorderColor(p.border[1], p.border[2], p.border[3], 0.45)
            else
                button:SetBackdropColor(p.panel[1], p.panel[2], p.panel[3], 1)
                button:SetBackdropBorderColor(p.border[1], p.border[2], p.border[3], 1)
            end
        end
        if button.__EAStyleActive then
            self:SetButtonBorderColor(button, p.accent, 1)
        elseif button.__EAStyleDisabled then
            self:SetButtonBorderColor(button, p.border, 0.45)
        else
            self:SetButtonBorderColor(button, p.border, 1)
        end
        label:Show()
        label:SetAlpha(1)
        label:SetShadowOffset(1, -1)
        if button.__EAStyleActive then
            label:SetTextColor(p.accent[1], p.accent[2], p.accent[3])
        elseif button.__EAStyleDisabled then
            label:SetTextColor(p.muted[1], p.muted[2], p.muted[3], 0.65)
        else
            label:SetTextColor(p.text[1], p.text[2], p.text[3])
        end
    end

    button:HookScript("OnEnter", function()
        local p = self:Palette()
        if p.blizzard then
            if button:IsEnabled() then
                self:ApplyBlizzardButtonStyle(button, label, p, true)
            end
            return
        end
        if p.legacy then
            if button:IsEnabled() then
                self:ApplyLegacyButtonStyle(button, label, p, true)
            end
            return
        end
        if button.SetBackdropColor and button:IsEnabled() then
            button:SetBackdropColor(p.accent[1], p.accent[2], p.accent[3], 0.24)
            button:SetBackdropBorderColor(p.accent[1], p.accent[2], p.accent[3], 1)
        end
        if button:IsEnabled() then
            self:SetButtonBorderColor(button, p.accent, 1)
        end
    end)
    button:HookScript("OnMouseDown", function()
        local p = self:Palette()
        if p.blizzard and button:IsEnabled() then
            self:ApplyBlizzardButtonStyle(button, label, p, false, true)
        end
    end)
    button:HookScript("OnMouseUp", function()
        local p = self:Palette()
        if p.blizzard then
            self:ApplyBlizzardButtonStyle(button, label, p)
        end
    end)
    button:HookScript("OnLeave", rest)
    button:HookScript("OnDisable", function()
        button.__EAStyleDisabled = true
        button.__EAStyleActive = false
        rest()
    end)
    button:HookScript("OnEnable", function()
        button.__EAStyleDisabled = false
        rest()
    end)
    self:OnTheme(rest)
    return button
end

function Style:Divider(parent, orientation)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    if orientation == "vertical" then
        tex:SetWidth(1)
    else
        tex:SetHeight(1)
    end
    self:OnTheme(function(p)
        tex:SetColorTexture(p.border[1], p.border[2], p.border[3], 0.8)
    end)
    return tex
end

function Style:Surface(parent, role)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    self:Skin(frame, role or "panel")
    return frame
end

function Style:SetButtonWidth(button, width)
    if button then
        button:SetSize(width or button:GetWidth(), self.ButtonHeight)
    end
    return button
end

function Style:SkinEditBox(box)
    if not box then return box end
    self:EnsureBackdrop(box)
    if box.SetBackdrop then
        box:SetBackdrop(self.BACKDROP)
    end
    if box.SetTextInsets then
        box:SetTextInsets(6, 6, 0, 0)
    end
    if box.SetFont then
        box:SetFont(self.Font, 12, "")
    end
    self:OnTheme(function(p)
        if box.SetBackdropColor then
            if p.blizzard then
                local hasNative = false
                if box.Left then
                    EAStyle_ShowTexture(box.Left, nil, "common-search-border-left", false)
                    hasNative = true
                end
                if box.Middle then
                    EAStyle_ShowTexture(box.Middle, nil, "common-search-border-middle", false)
                    hasNative = true
                end
                if box.Right then
                    EAStyle_ShowTexture(box.Right, nil, "common-search-border-right", false)
                    hasNative = true
                end
                if hasNative then
                    if box.SetBackdrop then
                        box:SetBackdrop(nil)
                    end
                else
                    if box.SetBackdrop then
                        box:SetBackdrop(self.BLIZZARD_PANEL_BACKDROP)
                    end
                    box:SetBackdropColor(0, 0, 0, 0.82)
                    box:SetBackdropBorderColor(p.border[1], p.border[2], p.border[3], 0.85)
                end
            elseif p.legacy then
                box:SetBackdropColor(0, 0, 0, 0.80)
                box:SetBackdropBorderColor(1, 1, 1, 0.20)
            else
                box:SetBackdropColor(p.plot[1], p.plot[2], p.plot[3], 0.88)
                box:SetBackdropBorderColor(p.border[1], p.border[2], p.border[3], 1)
            end
        end
        if box.SetTextColor then
            box:SetTextColor(p.text[1], p.text[2], p.text[3], 1)
        end
    end)
    return box
end

function Style:SkinAllButtons(root)
    if not root or not root.GetChildren then return root end
    local children = { root:GetChildren() }
    for i = 1, #children do
        local child = children[i]
        if child and child.GetObjectType and child:GetObjectType() == "Button" and child.GetScript then
            self:SkinButton(child)
        end
        self:SkinAllButtons(child)
    end
    return root
end

function Style:MoneyText(copper)
    copper = math.floor(tonumber(copper) or 0)
    local sign = ""
    if copper < 0 then
        sign = "-"
        copper = -copper
    end
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local coin = copper % 100
    if gold > 0 then
        return string.format("%s%d|TInterface\\MoneyFrame\\UI-GoldIcon:11:11:1:0|t %02d|TInterface\\MoneyFrame\\UI-SilverIcon:11:11:1:0|t", sign, gold, silver)
    elseif silver > 0 then
        return string.format("%s%d|TInterface\\MoneyFrame\\UI-SilverIcon:11:11:1:0|t %02d|TInterface\\MoneyFrame\\UI-CopperIcon:11:11:1:0|t", sign, silver, coin)
    end
    return string.format("%s%d|TInterface\\MoneyFrame\\UI-CopperIcon:11:11:1:0|t", sign, coin)
end

function Style:Popover(parent, titleText, width, height)
    local panel = CreateFrame("Frame", nil, parent or UIParent, "BackdropTemplate")
    panel:SetSize(width or 300, height or 260)
    panel:SetFrameStrata("DIALOG")
    panel:SetToplevel(true)
    panel:EnableMouse(true)
    panel:Hide()
    self:Skin(panel, "panel")

    local title = self:Text(panel, "OVERLAY", self.Font, 14, "", "accent")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText(titleText or "")
    panel.title = title

    local close = self:CloseButton(panel)
    close:SetPoint("TOPRIGHT", -6, -6)
    close:SetScript("OnClick", function() panel:Hide() end)
    self:SetTooltip(close, "关闭", "关闭此面板。", "ANCHOR_LEFT")
    panel.close = close

    local body = CreateFrame("Frame", nil, panel)
    body:SetPoint("TOPLEFT", 12, -38)
    body:SetPoint("BOTTOMRIGHT", -12, 12)
    panel.body = body
    return panel
end

function Style:SetButtonActive(button, active)
    if not button then return end
    button.__EAStyleActive = active and true or false
    button.__EAStyleDisabled = (not active) and (button.IsEnabled and not button:IsEnabled()) or false
    local p = self:Palette()
    local fs = button:GetFontString() or button.label or button.text or button._fs
    if p.blizzard then
        self:ApplyBlizzardButtonStyle(button, fs, p)
        return
    end
    if p.legacy then
        self:ApplyLegacyButtonStyle(button, fs, p)
        return
    end
    if active then
        if button.SetBackdropColor then
            button:SetBackdropColor(p.accent[1], p.accent[2], p.accent[3], 0.18)
            button:SetBackdropBorderColor(p.accent[1], p.accent[2], p.accent[3], 1)
        end
        self:SetButtonBorderColor(button, p.accent, 1)
        if fs then fs:SetTextColor(p.accent[1], p.accent[2], p.accent[3]) end
    else
        if button.SetBackdropColor then
            button:SetBackdropColor(p.panel[1], p.panel[2], p.panel[3], 1)
            button:SetBackdropBorderColor(p.border[1], p.border[2], p.border[3], 1)
        end
        self:SetButtonBorderColor(button, p.border, 1)
        if fs then fs:SetTextColor(p.text[1], p.text[2], p.text[3]) end
    end
end

function Style:SetButtonDisabled(button, disabled)
    if not button then return end
    button.__EAStyleDisabled = disabled and true or false
    button.__EAStyleActive = false
    local p = self:Palette()
    local fs = button:GetFontString() or button.label or button.text or button._fs
    if p.blizzard then
        self:ApplyBlizzardButtonStyle(button, fs, p)
        return
    end
    if p.legacy then
        self:ApplyLegacyButtonStyle(button, fs, p)
        return
    end
    if button.SetBackdropColor then
        if button.__EAStyleDisabled then
            button:SetBackdropColor(p.bg[1], p.bg[2], p.bg[3], 0.72)
            button:SetBackdropBorderColor(p.border[1], p.border[2], p.border[3], 0.45)
        else
            button:SetBackdropColor(p.panel[1], p.panel[2], p.panel[3], 1)
            button:SetBackdropBorderColor(p.border[1], p.border[2], p.border[3], 1)
        end
    end
    self:SetButtonBorderColor(button, p.border, button.__EAStyleDisabled and 0.45 or 1)
    if fs then
        if button.__EAStyleDisabled then
            fs:SetTextColor(p.muted[1], p.muted[2], p.muted[3], 0.65)
        else
            fs:SetTextColor(p.text[1], p.text[2], p.text[3])
        end
    end
end

function Style:CloseButton(parent)
    local b = self:Button(parent, "\195\151", 22)
    b.__EAStyleClose = true
    b:SetSize(22, 22)
    local fs = b:GetFontString()
    if fs then
        fs:SetFont(self.Font, 15, "")
    end
    b:HookScript("OnEnter", function()
        local p = self:Palette()
        if p.blizzard then
            self:ApplyBlizzardButtonStyle(b, fs, p, true)
            return
        end
        if b.SetBackdropColor then
            b:SetBackdropColor(self.Bear[1], self.Bear[2], self.Bear[3], 0.85)
            b:SetBackdropBorderColor(self.Bear[1], self.Bear[2], self.Bear[3], 1)
        end
        if fs then fs:SetTextColor(1, 1, 1) end
    end)
    local p = self:Palette()
    if p.blizzard then
        self:ApplyBlizzardButtonStyle(b, fs, p)
    end
    return b
end

function Style:SetTooltip(frame, title, body, anchor)
    if not frame then return end
    frame.__EATipTitle = title
    frame.__EATipBody = body
    frame.__EATipAnchor = anchor or "ANCHOR_TOP"
    if frame.__EATipHooked then return end
    frame.__EATipHooked = true
    frame:HookScript("OnEnter", function(owner)
        if not owner.__EATipTitle then return end
        GameTooltip:SetOwner(owner, owner.__EATipAnchor)
        GameTooltip:AddLine(owner.__EATipTitle)
        if owner.__EATipBody then
            GameTooltip:AddLine(owner.__EATipBody, 0.7, 0.7, 0.7, true)
        end
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

function Style:RangeBar(parent, captionText)
    local rb = {}
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetHeight(30)
    rb.frame = frame

    if captionText then
        rb.caption = self:Text(frame, "OVERLAY", self.Font, 10, "", "muted")
        rb.caption:SetPoint("TOP", 0, 0)
        rb.caption:SetText(captionText)
    end

    rb.track = frame:CreateTexture(nil, "ARTWORK")
    rb.track:SetPoint("TOPLEFT", 0, -13)
    rb.track:SetPoint("TOPRIGHT", 0, -13)
    rb.track:SetHeight(4)

    rb.marker = frame:CreateTexture(nil, "OVERLAY")
    rb.marker:SetSize(3, 12)
    rb.marker:Hide()

    rb.low = self:Text(frame, "OVERLAY", self.Font, 10, "", "muted")
    rb.low:SetPoint("TOPLEFT", rb.track, "BOTTOMLEFT", 0, -3)
    rb.high = self:Text(frame, "OVERLAY", self.Font, 10, "", "muted")
    rb.high:SetPoint("TOPRIGHT", rb.track, "BOTTOMRIGHT", 0, -3)
    rb.high:SetJustifyH("RIGHT")

    self:OnTheme(function(p)
        rb.track:SetColorTexture(p.border[1], p.border[2], p.border[3], 0.55)
    end)

    function rb:Update(low, high, current, formatter, colorByFrac)
        if not (low and high and current) or high <= low then
            self.marker:Hide()
            self.low:SetText("")
            self.high:SetText("")
            return
        end
        formatter = formatter or tostring
        self.low:SetText(formatter(low))
        self.high:SetText(formatter(high))
        local frac = (current - low) / (high - low)
        if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
        local w = self.track:GetWidth()
        if w <= 0 then return end
        self.marker:ClearAllPoints()
        self.marker:SetPoint("CENTER", self.track, "LEFT", frac * w, 0)
        if colorByFrac then
            local bull, bear = Style.Bull, Style.Bear
            self.marker:SetColorTexture(
                bear[1] * frac + bull[1] * (1 - frac),
                bear[2] * frac + bull[2] * (1 - frac),
                bear[3] * frac + bull[3] * (1 - frac),
                1
            )
        else
            local p = Style:Palette()
            self.marker:SetColorTexture(p.accent[1], p.accent[2], p.accent[3], 1)
        end
        self.marker:Show()
    end

    return rb
end

function Style:ColorTrend(delta)
    if not delta or math.abs(delta) < 1e-9 then
        return self.Neutral[1], self.Neutral[2], self.Neutral[3]
    elseif delta > 0 then
        return self.Bull[1], self.Bull[2], self.Bull[3]
    end
    return self.Bear[1], self.Bear[2], self.Bear[3]
end

function Style:RowColor(texture, index, selected)
    if not texture then return end
    index = tonumber(index) or 1
    local p = self:Palette()
    if p.blizzard then
        if selected then
            texture:SetColorTexture(1, 0.82, 0, 0.18)
        elseif index % 2 == 0 then
            texture:SetColorTexture(1, 0.82, 0, 0.06)
        else
            texture:SetColorTexture(1, 1, 1, 0.03)
        end
        return
    end
    if p.legacy then
        if selected then
            texture:SetColorTexture(0.68, 0.83, 1, 0.20)
        elseif index % 2 == 0 then
            texture:SetColorTexture(0.95, 0.95, 1, 0.20)
        else
            texture:SetColorTexture(1, 1, 1, 0.10)
        end
        return
    end
    if selected then
        texture:SetColorTexture(p.accent[1], p.accent[2], p.accent[3], 0.18)
    else
        texture:SetColorTexture(p.text[1], p.text[2], p.text[3], (index % 2 == 0) and 0.04 or 0.08)
    end
end
