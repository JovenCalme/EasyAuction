local addonName, NoWCL = ...
local S = {}
NoWCL.UIStyle = S
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
local DEFAULT_TEXTURE = "AlwaysWork"
local DEFAULT_TEXTURE_PATH = "Interface\\WorldStateFrame\\WORLDSTATEFINALSCORE-HIGHLIGHT"
local SOLID_TEXTURE = "NoWCL 纯色"
local DEFAULT_FONT = "NoWCL 默认"
local FALLBACK_TEXTURE = "Interface\\Buttons\\WHITE8X8"
local FALLBACK_FONT = STANDARD_TEXT_FONT or "Fonts\\ARKai_T.ttf"
S.defaults = {
texture = DEFAULT_TEXTURE,
font = DEFAULT_FONT,
fontSize = 12,
outline = "OUTLINE",
fullBarHeight = 18,
fullBarSpacing = 4,
miniBarHeight = 22,
miniBarSpacing = 6,
whitePlayerNames = false,
}
local LIMITS = {
fontSize = { 9, 16 },
fullBarHeight = { 14, 30 },
fullBarSpacing = { 0, 8 },
miniBarHeight = { 16, 34 },
miniBarSpacing = { 0, 8 },
}
local OUTLINES = { [""] = true, OUTLINE = true, THICKOUTLINE = true }
local cache = {}
local roots = setmetatable({}, { __mode = "k" })
if LSM then
if not LSM:Fetch("statusbar", DEFAULT_TEXTURE, true) then
LSM:Register("statusbar", DEFAULT_TEXTURE, DEFAULT_TEXTURE_PATH)
end
LSM:Register("statusbar", SOLID_TEXTURE, FALLBACK_TEXTURE)
LSM:Register("statusbar", "NoWCL 暴雪", "Interface\\TargetingFrame\\UI-StatusBar")
LSM:Register("statusbar", "NoWCL 团队框架", "Interface\\RaidFrame\\Raid-Bar-Hp-Fill")
LSM:Register("font", DEFAULT_FONT, FALLBACK_FONT, 255)
end
local function clampNumber(value, key)
local lim = LIMITS[key]
local n = tonumber(value) or S.defaults[key]
n = math.floor(n + 0.5)
if n < lim[1] then return lim[1] end
if n > lim[2] then return lim[2] end
return n
end
local function appearanceDB()
if not NoWCL.db then return nil end
NoWCL.db.window = NoWCL.db.window or {}
NoWCL.db.window.appearance = NoWCL.db.window.appearance or {}
return NoWCL.db.window.appearance
end
function S:EnsureDefaults()
local cfg = appearanceDB()
if not cfg then return self.defaults end
if type(cfg.texture) ~= "string" or cfg.texture == "" then cfg.texture = self.defaults.texture end
if type(cfg.font) ~= "string" or cfg.font == "" then cfg.font = self.defaults.font end
cfg.fontSize = clampNumber(cfg.fontSize, "fontSize")
cfg.fullBarHeight = clampNumber(cfg.fullBarHeight, "fullBarHeight")
cfg.fullBarSpacing = clampNumber(cfg.fullBarSpacing, "fullBarSpacing")
cfg.miniBarHeight = clampNumber(cfg.miniBarHeight, "miniBarHeight")
cfg.miniBarSpacing = clampNumber(cfg.miniBarSpacing, "miniBarSpacing")
cfg.whitePlayerNames = cfg.whitePlayerNames == true
if not OUTLINES[cfg.outline or false] then cfg.outline = self.defaults.outline end
return cfg
end
function S:GetConfig()
return self:EnsureDefaults()
end
function S:ResolveMedia(mediaType, name)
local path = LSM and LSM:Fetch(mediaType, name, true)
if path then return path end
if mediaType == "font" then
return (LSM and LSM:Fetch("font", DEFAULT_FONT, true)) or FALLBACK_FONT
end
return (LSM and LSM:Fetch("statusbar", DEFAULT_TEXTURE, true)) or FALLBACK_TEXTURE
end
function S:RefreshCache()
local cfg = self:EnsureDefaults()
cache.texture = self:ResolveMedia("statusbar", cfg.texture)
cache.font = self:ResolveMedia("font", cfg.font)
cache.fontSize = cfg.fontSize
cache.outline = cfg.outline
cache.fullBarHeight = cfg.fullBarHeight
cache.fullBarSpacing = cfg.fullBarSpacing
cache.miniBarHeight = cfg.miniBarHeight
cache.miniBarSpacing = cfg.miniBarSpacing
cache.whitePlayerNames = cfg.whitePlayerNames
return cache
end
local function currentCache()
if not cache.texture then S:RefreshCache() end
return cache
end
function S:TexturePath() return currentCache().texture end
function S:FontPath() return currentCache().font end
function S:FontSize() return currentCache().fontSize or self.defaults.fontSize end
function S:FontOutline() return currentCache().outline or self.defaults.outline end
function S:FullRowHeight() return currentCache().fullBarHeight or self.defaults.fullBarHeight end
function S:MiniRowHeight() return currentCache().miniBarHeight or self.defaults.miniBarHeight end
function S:MiniDetailRowHeight() return math.max(14, self:MiniRowHeight() - 4) end
function S:FullBarSpacing() return currentCache().fullBarSpacing or self.defaults.fullBarSpacing end
function S:MiniBarSpacing() return currentCache().miniBarSpacing or self.defaults.miniBarSpacing end
function S:WhitePlayerNames() return currentCache().whitePlayerNames == true end
function S:FullFillHeight() return math.max(6, self:FullRowHeight() - self:FullBarSpacing()) end
function S:FullDetailFillHeight() return math.max(8, self:FullRowHeight() - 4) end
function S:MiniFillHeight() return math.max(8, self:MiniRowHeight() - self:MiniBarSpacing()) end
function S:MiniDetailFillHeight() return math.max(8, self:MiniDetailRowHeight() - 4) end
function S:ApplyFont(fs, delta)
if not fs or not fs.SetFont then return end
fs._nowclUsesCustomSize = true
fs._nowclFontDelta = delta or 0
local c = currentCache()
local size = math.max(8, (c.fontSize or self.defaults.fontSize) + fs._nowclFontDelta)
local ok = fs:SetFont(c.font or FALLBACK_FONT, size, c.outline or "")
if ok == false and c.font ~= FALLBACK_FONT then
fs:SetFont(FALLBACK_FONT, size, c.outline or "")
end
end
function S:ApplyFontFace(fs)
if not fs or not fs.SetFont or not fs.GetFont then return end
if fs._nowclUsesCustomSize then
self:ApplyFont(fs, fs._nowclFontDelta or 0)
return
end
if not fs._nowclBaseFontSize then
local _, size = fs:GetFont()
fs._nowclBaseFontSize = tonumber(size) or self.defaults.fontSize
end
local c = currentCache()
local ok = fs:SetFont(c.font or FALLBACK_FONT, fs._nowclBaseFontSize, c.outline or "")
if ok == false and c.font ~= FALLBACK_FONT then
fs:SetFont(FALLBACK_FONT, fs._nowclBaseFontSize, c.outline or "")
end
end
function S:ApplyFontTree(root)
if not root then return end
local objectType = root.GetObjectType and root:GetObjectType()
if objectType == "FontString" or objectType == "EditBox" then self:ApplyFontFace(root) end
if root.GetRegions then
local regions = { root:GetRegions() }
for _, region in ipairs(regions) do
if region.GetObjectType and region:GetObjectType() == "FontString" then self:ApplyFontFace(region) end
end
end
if root.GetChildren then
local children = { root:GetChildren() }
for _, child in ipairs(children) do self:ApplyFontTree(child) end
end
end
function S:RegisterRoot(root)
if not root then return end
roots[root] = true
self:ApplyFontTree(root)
end
function S:ApplyTexture(texture, r, g, b, a)
if not texture then return end
local path = self:TexturePath()
local ok = texture:SetTexture(path)
if ok == false and path ~= FALLBACK_TEXTURE then texture:SetTexture(FALLBACK_TEXTURE) end
texture:SetVertexColor(r or 1, g or 1, b or 1)
texture:SetAlpha(a == nil and 1 or a)
end
function S:SetTextureColor(texture, r, g, b, a)
if not texture then return end
texture:SetVertexColor(r or 1, g or 1, b or 1)
texture:SetAlpha(a == nil and 1 or a)
end
function S:PlayerName(name, class)
name = name or "?"
if self:WhitePlayerNames() then return "|cffffffff" .. name .. "|r" end
local U = NoWCL.Util
if U and U.ClassColor then return U.ClassColor(name, class) end
local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
if c then return string.format("|cff%02x%02x%02x%s|r", c.r * 255, c.g * 255, c.b * 255, name) end
return name
end
function S:MediaList(mediaType, filter)
local out = {}
local needle = tostring(filter or ""):lower()
local list = LSM and LSM:List(mediaType) or {}
for _, name in ipairs(list or {}) do
if needle == "" or tostring(name):lower():find(needle, 1, true) then out[#out + 1] = name end
end
if #out == 0 and needle == "" then
out[1] = mediaType == "font" and DEFAULT_FONT or DEFAULT_TEXTURE
end
table.sort(out, function(a, b) return tostring(a) < tostring(b) end)
return out
end
function S:Set(key, value)
local cfg = self:EnsureDefaults()
if key == "fontSize" or key == "fullBarHeight" or key == "fullBarSpacing"
or key == "miniBarHeight" or key == "miniBarSpacing" then
cfg[key] = clampNumber(value, key)
elseif key == "outline" then
cfg.outline = OUTLINES[value or false] and value or self.defaults.outline
elseif key == "font" or key == "texture" then
cfg[key] = type(value) == "string" and value ~= "" and value or self.defaults[key]
elseif key == "whitePlayerNames" then
cfg.whitePlayerNames = value == true
else
return
end
self:ApplyAll()
end
function S:Reset()
local cfg = self:EnsureDefaults()
for key, value in pairs(self.defaults) do cfg[key] = value end
self:ApplyAll()
end
function S:Summary()
local cfg = self:EnsureDefaults()
return string.format("%s · %s · %d号 · 横%d/%d · 竖%d/%d%s", cfg.texture, cfg.font, cfg.fontSize,
cfg.fullBarHeight, cfg.fullBarSpacing, cfg.miniBarHeight, cfg.miniBarSpacing,
cfg.whitePlayerNames and " · 白色角色名" or "")
end
function S:ApplyAll()
self:RefreshCache()
if NoWCL.AuditUI and NoWCL.AuditUI.ApplyStyle then NoWCL.AuditUI:ApplyStyle() end
if NoWCL.MiniUI and NoWCL.MiniUI.ApplyStyle then NoWCL.MiniUI:ApplyStyle() end
for root in pairs(roots) do self:ApplyFontTree(root) end
if NoWCL.AppearanceConfig and NoWCL.AppearanceConfig.Refresh then NoWCL.AppearanceConfig:Refresh() end
end
