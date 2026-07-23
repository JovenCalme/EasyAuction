local _, NoWCL = ...
local RM = NoWCL.RaidManagement
local U = {}
RM.Util = U
U.POSITION_GRID_MAX = 63
local CLASSIC_SPEC_ICONS = {
[62]=135932,[63]=135810,[64]=135846,
[65]=135920,[66]=135893,[70]=135873,
[71]=132355,[72]=132347,[73]=134952,
[102]=136096,[103]=132276,[104]=132276,[105]=136041,
[250]=135770,[251]=135773,[252]=135775,
[253]=132164,[254]=132222,[255]=132215,
[256]=135987,[257]=237542,[258]=136207,
[259]=132292,[260]=132090,[261]=132320,
[262]=136048,[263]=136051,[264]=136052,
[265]=136145,[266]=136172,[267]=136186,
}
function U.RegisterFontRoot(root)
local api=RM.GetNoWCLAPI and RM:GetNoWCLAPI()
if api and api.RegisterFontRoot then return api:RegisterFontRoot(root) end
return false
end
function U.Clamp(value, low, high)
value = tonumber(value) or low
if value < low then return low end
if value > high then return high end
return value
end
function U.PositionGridIndex(value)
return math.max(0, math.min(U.POSITION_GRID_MAX,
math.floor(U.Clamp(value, 0, 1) * U.POSITION_GRID_MAX + 0.5)))
end
function U.PositionFromGrid(index)
return math.max(0.02, math.min(0.98,
math.max(0, math.min(U.POSITION_GRID_MAX, math.floor(tonumber(index) or 0)))
/ U.POSITION_GRID_MAX))
end
function U.SnapGridCoordinate(value)
return U.PositionFromGrid(U.PositionGridIndex(value))
end
function U.ShortName(name)
return type(name) == "string" and (name:match("^[^-]+") or name) or "未知"
end
function U.TruncateUTF8(text, maxChars)
text = tostring(text or "")
maxChars = math.max(0, math.floor(tonumber(maxChars) or 0))
local index, count, length = 1, 0, #text
while index <= length and count < maxChars do
local byte = text:byte(index)
local width = byte >= 240 and 4 or byte >= 224 and 3 or byte >= 192 and 2 or 1
index = math.min(length + 1, index + width)
count = count + 1
end
return text:sub(1, index - 1)
end
function U.Copy(value, depth, seen)
if type(value) ~= "table" then return value end
depth = tonumber(depth) or 8
if depth <= 0 then return nil end
seen = seen or {}
if seen[value] then return nil end
seen[value] = true
local out = {}
for key, item in pairs(value) do
if type(key) ~= "table" then out[key] = U.Copy(item, depth - 1, seen) end
end
seen[value] = nil
return out
end
function U.ClassColor(class)
local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
if color then return color.r or 0.8, color.g or 0.8, color.b or 0.8 end
return 0.75, 0.78, 0.82
end
function U.SpecializationIcon(specId)
specId = tonumber(specId)
if not (specId and specId > 0) then return nil end
if CLASSIC_SPEC_ICONS[specId] then return CLASSIC_SPEC_ICONS[specId] end
if GetSpecializationInfoByID then
local _, _, _, icon = GetSpecializationInfoByID(specId)
if icon then return icon end
end
end
function U.GroupChannel()
local instanceCategory = _G.LE_PARTY_CATEGORY_INSTANCE
if instanceCategory and IsInGroup and IsInGroup(instanceCategory) then
return "INSTANCE_CHAT"
end
if IsInRaid and IsInRaid() then return "RAID" end
if (IsInGroup and IsInGroup())
or (GetNumGroupMembers and (GetNumGroupMembers() or 0) > 0) then return "PARTY" end
return nil
end
function U.GroupRank(name)
name = U.ShortName(name or UnitName("player"))
if not (IsInRaid and IsInRaid()) then
local units = {"player"}
local partyCount = GetNumSubgroupMembers and GetNumSubgroupMembers() or 0
for index = 1, partyCount do units[#units + 1] = "party" .. index end
for _, unit in ipairs(units) do
if U.ShortName(UnitName and UnitName(unit)) == name then
if UnitIsGroupLeader and UnitIsGroupLeader(unit) then return 2 end
if UnitIsGroupAssistant and UnitIsGroupAssistant(unit) then return 1 end
if #units == 1 and unit == "player" then return 2 end
return 0
end
end
return 0
end
if not GetRaidRosterInfo then return 0 end
local count = GetNumGroupMembers and GetNumGroupMembers() or 0
for index = 1, count do
local rosterName, rank = GetRaidRosterInfo(index)
if U.ShortName(rosterName) == name then return math.max(0, math.min(2, tonumber(rank) or 0)) end
end
return 0
end
function U.IsLeaderOrAssistant(name)
return U.GroupRank(name) > 0
end
function U.Escape(text)
text = tostring(text or "")
return (text:gsub("%%", "%%25"):gsub("|", "%%7C"):gsub("\n", "%%0A"):gsub("\r", "%%0D"))
end
function U.Unescape(text)
return (tostring(text or ""):gsub("%%0[Dd]", "\r"):gsub("%%0[Aa]", "\n")
:gsub("%%7[Cc]", "|"):gsub("%%25", "%%"))
end
function U.Split(text, delimiter)
local out, start = {}, 1
delimiter = delimiter or "|"
while true do
local at = string.find(text, delimiter, start, true)
if not at then out[#out + 1] = string.sub(text, start); break end
out[#out + 1] = string.sub(text, start, at - 1)
start = at + #delimiter
end
return out
end
function U.Checksum(text)
local a, b = 1, 0
for index = 1, #text do
a = (a + string.byte(text, index)) % 65521
b = (b + a) % 65521
end
return b * 65536 + a
end
function U.NewId(prefix)
local seed = tostring(time and time() or 0) .. tostring(GetTime and GetTime() or 0) .. tostring(math.random(1000,9999))
return tostring(prefix or "id") .. "-" .. tostring(U.Checksum(seed))
end
function U.SpellLabel(spellId)
spellId = tonumber(spellId)
if not spellId then return "未设置技能" end
local name, _, icon = GetSpellInfo(spellId)
return name or ("法术#" .. spellId), icon
end
local dropdownMenu
local function setDropdownExpanded(dropdown,expanded)
if dropdown and dropdown.arrow then dropdown.arrow:SetText(expanded and "▼" or "▶") end
end
local function ensureDropdownMenu()
if dropdownMenu then return dropdownMenu end
local catcher=CreateFrame("Button",nil,UIParent)
catcher:SetAllPoints(UIParent);catcher:SetFrameStrata("TOOLTIP");catcher:SetFrameLevel(9000);catcher:Hide()
local menu=CreateFrame("Frame",nil,UIParent)
menu:SetFrameStrata("TOOLTIP");menu:SetFrameLevel(catcher:GetFrameLevel()+5)
local background=menu:CreateTexture(nil,"BACKGROUND");background:SetAllPoints();background:SetColorTexture(0,0,0,0.5)
local border=menu:CreateTexture(nil,"BORDER");border:SetPoint("TOPLEFT",-1,1);border:SetPoint("BOTTOMRIGHT",1,-1);border:SetColorTexture(0,0,0,0.85)
menu.buttons={}
catcher:SetScript("OnClick",function() menu:Hide() end)
menu:SetScript("OnHide",function()
catcher:Hide()
setDropdownExpanded(menu.owner,false)
end)
function menu:Open(owner)
local items=owner.itemsFn and owner.itemsFn() or {}
local width=math.max(owner:GetWidth() or 120,120)
local y=-3
for index,itemValue in ipairs(items) do
local item=itemValue
local row=self.buttons[index]
if not row then
row=CreateFrame("Button",nil,self);row:SetHeight(19)
row.dot=row:CreateTexture(nil,"ARTWORK");row.dot:SetSize(8,8);row.dot:SetPoint("LEFT",6,0)
row.dot:SetTexture("Interface\\COMMON\\Indicator-Green")
row.text=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
row.text:SetPoint("LEFT",19,0);row.text:SetPoint("RIGHT",-5,0);row.text:SetJustifyH("LEFT")
row.highlight=row:CreateTexture(nil,"HIGHLIGHT");row.highlight:SetAllPoints();row.highlight:SetColorTexture(1,1,1,0.12)
self.buttons[index]=row
end
row:ClearAllPoints();row:SetPoint("TOPLEFT",2,y);row:SetWidth(width-4)
row.isTitle=item.isTitle and true or false
if row.isTitle then
row.text:SetText(tostring(item.text or ""));row.text:SetTextColor(0.48,0.72,1)
row.dot:Hide()
row:Disable();row.highlight:Hide()
else
row.dot:SetShown(item.checked and true or false)
row.text:SetText(tostring(item.text or ""))
row.text:SetTextColor(1,1,1);row:Enable();row.highlight:Show()
row:SetScript("OnClick",function()
self:Hide()
if owner.onSelect then owner.onSelect(item.value) end
end)
end
row:Show();y=y-19
end
for index=#items+1,#self.buttons do self.buttons[index]:Hide() end
self:SetSize(width,-y+3)
self:ClearAllPoints();self:SetPoint("TOPLEFT",owner,"BOTTOMLEFT",0,-2)
U.RegisterFontRoot(self)
catcher:Show();self:Show()
end
menu:Hide();dropdownMenu=menu
return menu
end
function U.MakeDropdown(parent,width)
local dropdown=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
dropdown:SetSize(width,22)
dropdown.arrow=dropdown:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
dropdown.arrow:SetSize(8,8);dropdown.arrow:SetPoint("LEFT",7,0);dropdown.arrow:SetJustifyH("CENTER")
local arrowFont=select(1,dropdown.arrow:GetFont()) or STANDARD_TEXT_FONT or "Fonts\\ARKai_T.ttf"
dropdown.arrow:SetFont(arrowFont,8,"OUTLINE");dropdown.arrow._nowclBaseFontSize=8
dropdown.arrow:SetText("▶")
dropdown.arrow:SetTextColor(1,0.82,0.22)
local label=dropdown:GetFontString()
if label then
label:ClearAllPoints();label:SetPoint("LEFT",18,0);label:SetPoint("RIGHT",-5,0);label:SetJustifyH("CENTER")
end
dropdown:SetScript("OnClick",function(self)
local menu=ensureDropdownMenu()
if menu:IsShown() and menu.owner==self then menu:Hide()
else
setDropdownExpanded(menu.owner,false)
menu.owner=self
setDropdownExpanded(self,true)
menu:Open(self)
end
end)
return dropdown
end
