local addonName, NoWCL = ...
local A = {}
NoWCL.AppearanceConfig = A
local U = NoWCL.Util
local S = NoWCL.UIStyle
local frame
local browserRows = {}
local previewFull, previewMini = {}, {}
local BROWSER_VISIBLE = 10
local OUTLINE_ITEMS = {
{ text = "无描边", value = "" },
{ text = "细描边", value = "OUTLINE" },
{ text = "粗描边", value = "THICKOUTLINE" },
}
local function outlineName(value)
for _, item in ipairs(OUTLINE_ITEMS) do
if item.value == value then return item.text end
end
return "细描边"
end
local function makeSlider(parent, name, x, y, label, minValue, maxValue, onChange)
local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOPLEFT", x, y)
title:SetText(label)
local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
slider:SetSize(218, 16)
slider:SetPoint("TOPLEFT", x, y - 24)
slider:SetOrientation("HORIZONTAL")
slider:SetMinMaxValues(minValue, maxValue)
slider:SetValueStep(1)
if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
local low, high, text = _G[name .. "Low"], _G[name .. "High"], _G[name .. "Text"]
if low then low:SetText(tostring(minValue)) end
if high then high:SetText(tostring(maxValue)) end
if text then text:SetText(""); text:Hide() end
slider.value = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
slider.value:SetPoint("LEFT", slider, "RIGHT", 10, 0)
slider.value:SetWidth(42)
slider.value:SetJustifyH("LEFT")
slider:SetScript("OnValueChanged", function(self, value)
value = math.floor((tonumber(value) or minValue) + 0.5)
self.value:SetText(tostring(value))
if not self._silent then onChange(value) end
end)
return slider
end
local function makePreviewRow(parent, pool, index)
if pool[index] then return pool[index] end
local row = CreateFrame("Frame", nil, parent)
row.bg = row:CreateTexture(nil, "BACKGROUND")
row.bg:SetAllPoints()
row.bg:SetColorTexture(0.02, 0.02, 0.03, index % 2 == 0 and 0.28 or 0.12)
row.bar = row:CreateTexture(nil, "ARTWORK")
row.bar:SetPoint("LEFT", 0, 0)
row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
row.name:SetPoint("LEFT", 7, 0)
row.name:SetJustifyH("LEFT")
row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
row.value:SetPoint("RIGHT", -7, 0)
row.value:SetJustifyH("RIGHT")
pool[index] = row
return row
end
local function refreshPreviewRows(parent, pool, rowHeight, fillHeight, startY, names)
local colors = {
{ 0.78, 0.61, 0.43 }, { 0.25, 0.78, 0.92 }, { 0.72, 0.32, 0.82 },
}
local classes = { "WARRIOR", "SHAMAN", "WARLOCK" }
for i = 1, #names do
local row = makePreviewRow(parent, pool, i)
row:ClearAllPoints()
row:SetPoint("TOPLEFT", 0, startY - (i - 1) * rowHeight)
row:SetPoint("TOPRIGHT", 0, startY - (i - 1) * rowHeight)
row:SetHeight(rowHeight)
row.bar:SetHeight(fillHeight)
row.bar:SetWidth((parent:GetWidth() > 10 and parent:GetWidth() or 300) * (1 - (i - 1) * 0.22))
S:ApplyTexture(row.bar, colors[i][1], colors[i][2], colors[i][3], 0.88)
S:ApplyFont(row.name, 0)
S:ApplyFont(row.value, -1)
row.name:SetText(i .. ". " .. S:PlayerName(names[i], classes[i]))
row.value:SetText(({ "8.42M  12.8K", "6.71M  10.2K", "4.98M  7.6K" })[i])
row:Show()
end
end
local function refreshPreview()
if not frame then return end
local fullH, miniH = S:FullRowHeight(), S:MiniRowHeight()
frame.fullPreview:SetHeight(fullH * 2)
frame.miniLabel:ClearAllPoints()
frame.miniLabel:SetPoint("TOPLEFT", 338, -128 - fullH * 2)
frame.miniPreview:ClearAllPoints()
frame.miniPreview:SetPoint("TOPLEFT", 338, -146 - fullH * 2)
frame.miniPreview:SetWidth(342)
frame.miniPreview:SetHeight(miniH * 2)
refreshPreviewRows(frame.fullPreview, previewFull, fullH, S:FullFillHeight(), 0,
{ "横版输出示例", "横版治疗示例" })
refreshPreviewRows(frame.miniPreview, previewMini, miniH, S:MiniFillHeight(), 0,
{ "竖版输出示例", "竖版治疗示例" })
end
local function filteredMedia()
if not frame then return {} end
local filter = frame.search and frame.search:GetText() or ""
return S:MediaList(frame.browserType or "statusbar", filter)
end
local function refreshBrowser()
if not frame then return end
local list = filteredMedia()
local maxOffset = math.max(0, #list - BROWSER_VISIBLE)
frame.browserOffset = math.max(0, math.min(frame.browserOffset or 0, maxOffset))
if frame.browserScroll then
frame.browserScroll._silent = true
frame.browserScroll:SetMinMaxValues(0, maxOffset)
frame.browserScroll:SetValue(frame.browserOffset)
frame.browserScroll:SetShown(maxOffset > 0)
frame.browserScroll._silent = nil
end
local cfg = S:GetConfig()
local selected
if frame.browserType == "font" then selected = cfg.font else selected = cfg.texture end
frame.browserTitle:SetText(frame.browserType == "font" and "选择字体" or "选择伤害条纹理")
frame.browserCount:SetText(string.format("%d-%d / %d", #list > 0 and frame.browserOffset + 1 or 0,
math.min(#list, frame.browserOffset + BROWSER_VISIBLE), #list))
for i = 1, BROWSER_VISIBLE do
local row = browserRows[i]
local name = list[(frame.browserOffset or 0) + i]
if name then
row.mediaName = name
row.bg:SetColorTexture(0.08, 0.08, 0.11, i % 2 == 0 and 0.92 or 0.72)
row.sample:Show()
row.label:ClearAllPoints()
if frame.browserType == "font" then
row.sample:Hide()
row.label:SetPoint("LEFT", 10, 0)
local ok = row.label:SetFont(S:ResolveMedia("font", name), 12, S:FontOutline())
if ok == false then S:ApplyFont(row.label, 0) end
else
row.sample:SetTexture(S:ResolveMedia("statusbar", name))
row.sample:SetVertexColor(0.35, 0.70, 0.95)
row.sample:SetAlpha(0.95)
row.label:SetPoint("LEFT", 112, 0)
S:ApplyFont(row.label, -1)
end
row.label:SetText((name == selected and "|cff44ff44●|r " or "") .. tostring(name))
row:Show()
else
row.mediaName = nil
row:Hide()
end
end
end
local function openBrowser(mediaType)
if not frame then return end
frame.browserType = mediaType
frame.browserOffset = 0
frame.search:SetText("")
refreshBrowser()
frame.search:SetFocus()
end
local function Create()
local f = CreateFrame("Frame", "NoWCLAppearanceFrame", UIParent)
f:SetSize(700, 650)
f:SetPoint("CENTER")
U.SetPanelLayer(f,true)
U.MakeMovable(f)
local bg = f:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(0.055, 0.055, 0.075, 0.98)
local tb = f:CreateTexture(nil, "ARTWORK")
tb:SetPoint("TOPLEFT"); tb:SetPoint("TOPRIGHT"); tb:SetHeight(28)
tb:SetColorTexture(0.12, 0.12, 0.16, 1)
f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
f.title:SetPoint("LEFT", tb, "LEFT", 10, 0)
f.title:SetText("NoWCL 界面外观")
local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -2, -2)
close:SetScript("OnClick", function() f:Hide() end)
f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
f.hint:SetPoint("TOPLEFT", 18, -38)
f.hint:SetText("|cff44ff44仅本机生效|r，不随团长同步；字体覆盖全部 NoWCL 界面，字号只调整排名与详情数据行。")
f.textureLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
f.textureLabel:SetPoint("TOPLEFT", 18, -76); f.textureLabel:SetText("伤害条纹理")
f.textureBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
f.textureBtn:SetSize(278, 24); f.textureBtn:SetPoint("TOPLEFT", 18, -98)
f.textureBtn:SetScript("OnClick", function() openBrowser("statusbar") end)
f.fontLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
f.fontLabel:SetPoint("TOPLEFT", 18, -140); f.fontLabel:SetText("界面字体")
f.fontBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
f.fontBtn:SetSize(278, 24); f.fontBtn:SetPoint("TOPLEFT", 18, -162)
f.fontBtn:SetScript("OnClick", function() openBrowser("font") end)
f.fontSize = makeSlider(f, "NoWCLAppearanceFontSizeSlider", 18, -212, "数据行文字大小", 9, 16,
function(value) S:Set("fontSize", value) end)
f.fullHeight = makeSlider(f, "NoWCLAppearanceFullHeightSlider", 18, -282, "横版伤害条高度", 14, 30,
function(value) S:Set("fullBarHeight", value) end)
f.fullSpacing = makeSlider(f, "NoWCLAppearanceFullSpacingSlider", 18, -346, "横版伤害条间距", 0, 8,
function(value) S:Set("fullBarSpacing", value) end)
f.miniHeight = makeSlider(f, "NoWCLAppearanceMiniHeightSlider", 18, -410, "竖版伤害条高度", 16, 34,
function(value) S:Set("miniBarHeight", value) end)
f.miniSpacing = makeSlider(f, "NoWCLAppearanceMiniSpacingSlider", 18, -474, "竖版伤害条间距", 0, 8,
function(value) S:Set("miniBarSpacing", value) end)
f.outlineLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
f.outlineLabel:SetPoint("TOPLEFT", 18, -538); f.outlineLabel:SetText("文字描边")
f.outline = U.MakeDropdown(f, 150)
f.outline:SetPoint("TOPLEFT", 18, -560)
f.outline.itemsFn = function()
local cfg, out = S:GetConfig(), {}
for _, item in ipairs(OUTLINE_ITEMS) do
out[#out + 1] = { text = item.text, value = item.value, checked = cfg.outline == item.value }
end
return out
end
f.outline.onSelect = function(value) S:Set("outline", value) end
f.whiteNames = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
f.whiteNames:SetSize(20, 20); f.whiteNames:SetPoint("TOPLEFT", 160, -556)
f.whiteNames:SetHitRectInsets(0, -130, 0, 0)
f.whiteNames:SetScript("OnClick", function(self)
S:Set("whitePlayerNames", self:GetChecked() and true or false)
end)
f.whiteNamesLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
f.whiteNamesLabel:SetPoint("LEFT", f.whiteNames, "RIGHT", 1, 0)
f.whiteNamesLabel:SetText("伤害条角色名白色")
f.reset = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
f.reset:SetSize(150, 24); f.reset:SetPoint("TOPLEFT", 18, -612); f.reset:SetText("恢复默认外观")
f.reset:SetScript("OnClick", function() S:Reset() end)
local divider = f:CreateTexture(nil, "ARTWORK")
divider:SetPoint("TOPLEFT", 318, -72); divider:SetPoint("BOTTOMLEFT", 318, 18)
divider:SetWidth(1); divider:SetColorTexture(1, 1, 1, 0.12)
f.previewTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
f.previewTitle:SetPoint("TOPLEFT", 338, -76); f.previewTitle:SetText("实时预览")
f.fullLabel = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
f.fullLabel:SetPoint("TOPLEFT", 338, -102); f.fullLabel:SetText("横版")
f.fullPreview = CreateFrame("Frame", nil, f)
f.fullPreview:SetPoint("TOPLEFT", 338, -120); f.fullPreview:SetWidth(342)
f.miniLabel = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
f.miniLabel:SetPoint("TOPLEFT", 338, -184); f.miniLabel:SetText("竖版")
f.miniPreview = CreateFrame("Frame", nil, f)
f.miniPreview:SetPoint("TOPLEFT", 338, -202); f.miniPreview:SetWidth(342)
f.browser = CreateFrame("Frame", nil, f)
f.browser:SetPoint("TOPLEFT", 330, -288); f.browser:SetPoint("BOTTOMRIGHT", -12, 18)
f.browser:EnableMouseWheel(true)
f.browser:SetScript("OnMouseWheel", function(_, delta)
f.browserOffset = math.max(0, (f.browserOffset or 0) - (delta > 0 and 3 or -3))
refreshBrowser()
end)
f.browserTitle = f.browser:CreateFontString(nil, "OVERLAY", "GameFontNormal")
f.browserTitle:SetPoint("TOPLEFT", 8, -2)
f.browserCount = f.browser:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
f.browserCount:SetPoint("TOPRIGHT", -8, -4)
f.search = CreateFrame("EditBox", nil, f.browser, "InputBoxTemplate")
f.search:SetSize(332, 24); f.search:SetPoint("TOPLEFT", 8, -24)
f.search:SetAutoFocus(false); f.search:SetMaxLetters(40)
f.search:SetScript("OnTextChanged", function() f.browserOffset = 0; refreshBrowser() end)
f.search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
f.browserScroll = CreateFrame("Slider", "NoWCLAppearanceMediaScrollBar", f.browser, "UIPanelScrollBarTemplate")
f.browserScroll:SetPoint("TOPRIGHT", -2, -50)
f.browserScroll:SetPoint("BOTTOMRIGHT", -2, 6)
f.browserScroll:SetOrientation("VERTICAL")
f.browserScroll:SetValueStep(1)
if f.browserScroll.SetObeyStepOnDrag then f.browserScroll:SetObeyStepOnDrag(true) end
f.browserScroll:SetScript("OnValueChanged", function(self, value)
if self._silent then return end
f.browserOffset = math.floor((tonumber(value) or 0) + 0.5)
refreshBrowser()
end)
for i = 1, BROWSER_VISIBLE do
local row = CreateFrame("Button", nil, f.browser)
row:SetHeight(22); row:SetPoint("TOPLEFT", 6, -52 - (i - 1) * 23); row:SetPoint("TOPRIGHT", -24, -52 - (i - 1) * 23)
row.bg = row:CreateTexture(nil, "BACKGROUND"); row.bg:SetAllPoints()
row.sample = row:CreateTexture(nil, "ARTWORK"); row.sample:SetPoint("LEFT", 8, 0); row.sample:SetSize(94, 12)
row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
row.label:SetPoint("LEFT", 112, 0); row.label:SetPoint("RIGHT", -8, 0); row.label:SetJustifyH("LEFT")
local hl = row:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(0.28, 0.52, 0.82, 0.35)
row:SetScript("OnClick", function(self)
if not self.mediaName then return end
S:Set(f.browserType == "font" and "font" or "texture", self.mediaName)
end)
browserRows[i] = row
end
tinsert(UISpecialFrames, "NoWCLAppearanceFrame")
f.browserType = "statusbar"
f.browserOffset = 0
f:Hide()
frame = f
if S and S.RegisterRoot then S:RegisterRoot(f) end
return f
end
function A:Refresh()
if not frame or not frame:IsShown() then return end
local cfg = S:GetConfig()
frame.textureBtn:SetText(cfg.texture)
frame.fontBtn:SetText(cfg.font)
frame.outline:SetText(outlineName(cfg.outline))
frame.whiteNames:SetChecked(cfg.whitePlayerNames == true)
for slider, value in pairs({
[frame.fontSize] = cfg.fontSize,
[frame.fullHeight] = cfg.fullBarHeight,
[frame.fullSpacing] = cfg.fullBarSpacing,
[frame.miniHeight] = cfg.miniBarHeight,
[frame.miniSpacing] = cfg.miniBarSpacing,
}) do
slider._silent = true
slider:SetValue(value)
slider.value:SetText(tostring(value))
slider._silent = nil
end
refreshPreview()
refreshBrowser()
end
function A:Show()
if not frame then Create() end
frame:Show()
self:Refresh()
end
function A:Toggle()
if not frame then Create() end
if frame:IsShown() then frame:Hide() else self:Show() end
end
