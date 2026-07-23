local addonName, NoWCL = ...
local P = {}
NoWCL.GearInspectPanel = P
local U = NoWCL.Util
local Style = NoWCL.UIStyle
local SLOT_ORDER = { 1,2,3,15,5,9,10,6,7,8,11,12,13,14,16,17,18 }
local SLOT_NAMES = {
[1]="头部",[2]="项链",[3]="肩部",[5]="胸甲",[6]="腰带",[7]="腿部",[8]="鞋",
[9]="护腕",[10]="手套",[11]="戒指1",[12]="戒指2",[13]="饰品1",[14]="饰品2",
[15]="披风",[16]="主手",[17]="副手",[18]="远程",
}
local PANEL_HEIGHT, MIN_WIDTH, MAX_WIDTH = 424, 330, 620
local ROW_HEIGHT, ROW_GAP, ROW_TOP = 17, 3, -80
local DAMAGE_WIDTH, DAMAGE_VISIBLE_ROWS, DAMAGE_ROW_HEIGHT = 470, 15, 20
local HOVER_KINDS = { gear=true, damage=true }
local HOVER_MODES = { hover=true, ctrl=true, alt=true, disabled=true }
local HOVER_DEFAULTS = { gear="disabled", damage="disabled" }
local HOVER_KEYS = { gear="gearInspectHoverMode", damage="damageInspectHoverMode" }
local EMPTY_ICON = 136509
local frame
local modifierWatcher
local function shortName(name)
return type(name)=="string" and (name:match("^[^-]+") or name) or nil
end
local function samePlayer(left,right)
if not (left and right) then return false end
if left==right then return true end
return shortName(left)==shortName(right)
end
local function classColor(class)
local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
return color and color.r or 0.7, color and color.g or 0.7, color and color.b or 0.75
end
local function itemFields(link)
local value = type(link)=="string" and (link:match("|Hitem:([^|]+)|h") or link:match("item:([^|%s]+)"))
local fields = {}
if value then
for field in (value .. ":"):gmatch("([^:]*):") do fields[#fields+1]=field end
end
local gems = {}
for index=3,6 do
local id=tonumber(fields[index]) or 0
if id>0 then gems[#gems+1]=id end
end
return tonumber(fields[1]) or 0, tonumber(fields[2]) or 0, gems
end
local function socketCount(link)
if not (link and GetItemStats) then return 0 end
local ok, stats = pcall(GetItemStats, link)
if not ok or type(stats)~="table" then return 0 end
local count=0
for key,value in pairs(stats) do
if type(key)=="string" and key:find("EMPTY_SOCKET",1,true) then
count=count+(tonumber(value) or 0)
end
end
return count
end
local function noWrap(fs)
if fs.SetWordWrap then fs:SetWordWrap(false) end
if fs.SetNonSpaceWrap then fs:SetNonSpaceWrap(false) end
end
local function setTooltipText(owner, title, text, bad)
if not GameTooltip then return end
GameTooltip:SetOwner(owner,"ANCHOR_RIGHT")
GameTooltip:ClearLines()
GameTooltip:AddLine(title or "装备信息",bad and 1 or 0.3,bad and 0.25 or 0.9,bad and 0.25 or 0.4)
if text and text~="" then GameTooltip:AddLine(text,1,1,1,true) end
GameTooltip:Show()
end
local function createEnhancement(parent)
local button=CreateFrame("Button",nil,parent)
button:SetSize(16,16)
button.icon=button:CreateTexture(nil,"ARTWORK")
button.icon:SetSize(14,14);button.icon:SetPoint("CENTER")
button.icon:SetTexCoord(0.06,0.94,0.06,0.94)
button.border=button:CreateTexture(nil,"OVERLAY")
button.border:SetSize(19,19);button.border:SetPoint("CENTER")
button.border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
button:SetScript("OnEnter",function(self)
if self.spellId and GameTooltip then
GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
if GameTooltip.SetSpellByID then GameTooltip:SetSpellByID(self.spellId)
else GameTooltip:SetHyperlink("spell:"..self.spellId) end
GameTooltip:Show()
elseif self.itemId and GameTooltip then
GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
GameTooltip:SetItemByID(self.itemId)
GameTooltip:Show()
else
setTooltipText(self,self.tooltipTitle,self.tooltipText,self.missing)
end
end)
button:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
button:SetScript("OnClick",function(self)
if not HandleModifiedItemClick then return end
local link
if self.itemId and GetItemInfo then link=select(2,GetItemInfo(self.itemId))
elseif self.spellId and GetSpellLink then link=GetSpellLink(self.spellId) end
if link then HandleModifiedItemClick(link) end
end)
button:Hide()
return button
end
local function createTalent(parent, size)
local button=CreateFrame("Button",nil,parent)
button:SetSize(size,size)
button.icon=button:CreateTexture(nil,"ARTWORK")
button.icon:SetSize(size-8,size-8);button.icon:SetPoint("TOP")
button.icon:SetTexCoord(0.06,0.94,0.06,0.94)
if button.CreateMaskTexture then
local mask=button:CreateMaskTexture()
mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask","CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
mask:SetAllPoints(button.icon)
button.icon:AddMaskTexture(mask)
end
button.label=button:CreateFontString(nil,"OVERLAY","SystemFont_Outline_Small")
button.label:SetPoint("CENTER",button.icon,"CENTER")
button.label:SetTextColor(1,0.82,0)
button.points=button:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
button.points:SetPoint("BOTTOM",0,0)
button:SetScript("OnEnter",function(self)
setTooltipText(self,self.specName or "天赋",self.pointsText or "等待天赋数据",false)
end)
button:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
return button
end
local function createRow(parent, slot, index)
local row=CreateFrame("Button",nil,parent)
row:SetHeight(ROW_HEIGHT)
row:SetPoint("TOPLEFT",10,ROW_TOP-(index-1)*(ROW_HEIGHT+ROW_GAP))
row:SetPoint("RIGHT",-10,0)
row:RegisterForClicks("LeftButtonUp")
row.slot=slot
row.slotBox=CreateFrame("Frame",nil,row,"BackdropTemplate")
row.slotBox:SetPoint("TOPLEFT");row.slotBox:SetPoint("BOTTOMLEFT");row.slotBox:SetWidth(43)
row.slotBox:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
edgeFile="Interface\\Buttons\\WHITE8X8",tile=true,tileSize=8,edgeSize=1,
insets={left=1,right=1,top=1,bottom=1}})
row.slotBox:SetBackdropColor(0.6,0.6,0.6,0.2)
row.slotBox:SetBackdropBorderColor(0.6,0.6,0.6,0.2)
row.slotText=row.slotBox:CreateFontString(nil,"ARTWORK","GameFontNormalSmall")
row.slotText:SetPoint("CENTER");row.slotText:SetText(SLOT_NAMES[slot])
row.level=row:CreateFontString(nil,"ARTWORK","GameFontHighlight")
row.level:SetPoint("LEFT",row.slotBox,"RIGHT",3,0);row.level:SetWidth(31);row.level:SetJustifyH("CENTER")
row.name=row:CreateFontString(nil,"ARTWORK","GameFontNormal")
row.name:SetPoint("LEFT",row.level,"RIGHT",3,0);row.name:SetJustifyH("LEFT");noWrap(row.name)
row.enchant=createEnhancement(row)
row.gems={}
for i=1,4 do row.gems[i]=createEnhancement(row) end
row:SetScript("OnEnter",function(self)
local r,g,b=classColor(frame and frame.class)
self.slotBox:SetBackdropColor(r,g,b,0.55)
if self.item and GameTooltip then
GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
GameTooltip:SetHyperlink(self.item)
GameTooltip:Show()
end
end)
row:SetScript("OnLeave",function(self)
local r,g,b=classColor(frame and frame.class)
self.slotBox:SetBackdropColor(r,g,b,0.2)
if GameTooltip then GameTooltip:Hide() end
end)
row:SetScript("OnClick",function(self)
if self.item and HandleModifiedItemClick then HandleModifiedItemClick(self.item) end
end)
return row
end
local function createDamageRow(parent,index)
local row=CreateFrame("Frame",nil,parent)
row:SetPoint("TOPLEFT",10,-98-(index-1)*DAMAGE_ROW_HEIGHT)
row:SetPoint("RIGHT",-10,0);row:SetHeight(DAMAGE_ROW_HEIGHT-1);row:EnableMouse(true)
row.bg=row:CreateTexture(nil,"BACKGROUND");row.bg:SetAllPoints()
row.bg:SetColorTexture(0,0,0,index%2==0 and 0.18 or 0.05)
row.bar=row:CreateTexture(nil,"ARTWORK");row.bar:SetPoint("LEFT",22,0);row.bar:SetHeight(DAMAGE_ROW_HEIGHT-3)
row.icon=row:CreateTexture(nil,"OVERLAY");row.icon:SetSize(16,16);row.icon:SetPoint("LEFT",2,0)
row.icon:SetTexCoord(0.08,0.92,0.08,0.92)
row.name=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
row.name:SetPoint("LEFT",24,0);row.name:SetWidth(190);row.name:SetJustifyH("LEFT");noWrap(row.name)
row.amount=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
row.amount:SetPoint("RIGHT",-116,0);row.amount:SetWidth(82);row.amount:SetJustifyH("RIGHT")
row.share=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
row.share:SetPoint("RIGHT",-58,0);row.share:SetWidth(52);row.share:SetJustifyH("RIGHT")
row.count=row:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
row.count:SetPoint("RIGHT",-4,0);row.count:SetWidth(48);row.count:SetJustifyH("RIGHT")
row:SetScript("OnEnter",function(self)
if self.detail and NoWCL.DetailStats and NoWCL.DetailStats.ShowSpellTooltip then
NoWCL.DetailStats.ShowSpellTooltip(self,self.detail,false,self.total)
end
end)
row:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
row:Hide()
return row
end
local function fallbackDamageRows(rec)
local out={}
for name,amount in pairs(rec and rec.spells or {}) do
amount=tonumber(amount) or 0
if amount>0 then out[#out+1]={name=name,amount=amount,casts=0,hits=0,crits=0} end
end
table.sort(out,function(left,right)
if left.amount==right.amount then return tostring(left.name)<tostring(right.name) end
return left.amount>right.amount
end)
return out
end
function P:BuildDamageRows(rec,view,selection)
view=view or {}
local mode
if U and U.ResolveDamageMode then
mode=U.ResolveDamageMode(view,selection or (view.live and "current" or nil))
else
mode=view.isBoss==false and "all" or (view.cfg and view.cfg.dpsMode) or "boss"
end
local bossCfg=(view.cfg and view.cfg.bossCfg)
or (NoWCL.db and NoWCL.db.settings and NoWCL.db.settings.bossCfg)
local rows=NoWCL.DetailStats and NoWCL.DetailStats.SpellRows
and NoWCL.DetailStats.SpellRows(rec,false,view.encounter,mode,bossCfg) or fallbackDamageRows(rec)
local total=0
for _,row in ipairs(rows or {}) do total=total+(tonumber(row.amount or row.v) or 0) end
return rows or {},total,mode
end
local function updatePortrait(f)
local unit=f.unit
if unit and UnitExists and UnitExists(unit) and SetPortraitTexture then
SetPortraitTexture(f.portrait,unit)
f.portrait:SetTexCoord(0,1,0,1)
f.level:SetText(UnitLevel and UnitLevel(unit) or "")
elseif f.class and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[f.class] then
f.portrait:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
f.portrait:SetTexCoord(unpack(CLASS_ICON_TCOORDS[f.class]))
f.level:SetText("")
else
f.portrait:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
f.portrait:SetTexCoord(0,1,0,1)
f.level:SetText("")
end
end
local function fallbackSpecName(specId)
if GetSpecializationInfoByID and specId then
local _,name=GetSpecializationInfoByID(specId)
if name then return name end
end
return "专精"
end
local function updateTalents(f, cache)
local summaries=NoWCL.Readiness and NoWCL.Readiness.GetTalentEmuTalentInfo
and NoWCL.Readiness:GetTalentEmuTalentInfo(f.playerName,f.sender) or nil
if not summaries then
summaries={{specId=cache and cache.specId,specName=fallbackSpecName(cache and cache.specId),points="等待数据",active=true}}
end
for index,button in ipairs({f.talent1,f.talent2}) do
local info=summaries[index]
if info then
button.specName=info.specName
button.pointsText=info.points
button.icon:SetTexture(U and U.SpecializationIcon and U.SpecializationIcon(info.specId) or EMPTY_ICON)
button.icon:SetVertexColor(info.active==false and 0.55 or 1,info.active==false and 0.55 or 1,info.active==false and 0.55 or 1)
button.label:SetText((info.group==2 or info.active==false) and "副" or info.specName)
button.points:SetText(info.points or "")
button:Show()
else
button:Hide()
end
end
end
local function playerGear(name)
local readiness=NoWCL.Readiness
if readiness and readiness.GetPlayerGear then
return readiness:GetPlayerGear(name)
end
end
local function updateEnhancements(row, link, class)
row.enchant:Hide()
for _,gem in ipairs(row.gems) do gem:Hide() end
local _,enchantId,gems=itemFields(link)
local enchantInfo=NoWCL.Readiness and NoWCL.Readiness.GetTalentEmuEnchantInfo
and NoWCL.Readiness:GetTalentEmuEnchantInfo(class,row.slot,link) or nil
local enchantable=enchantInfo and enchantInfo.enchantable
if enchantable==nil then
enchantable=NoWCL.Readiness and NoWCL.Readiness.NeedsEnchant
and NoWCL.Readiness:NeedsEnchant(row.slot,link) or enchantId>0
end
if enchantable then
local enchanted=(enchantInfo and enchantInfo.enchanted) or enchantId>0
local spellId=enchantInfo and enchantInfo.spellId or nil
local spellIcon=spellId and GetSpellInfo and select(3,GetSpellInfo(spellId)) or nil
row.enchant.icon:SetTexture(enchanted and (spellIcon or EMPTY_ICON) or EMPTY_ICON)
row.enchant.border:SetVertexColor(enchanted and 0.2 or 1,enchanted and 0.9 or 0.2,enchanted and 0.2 or 0.2)
row.enchant.tooltipTitle=enchanted and "附魔" or "缺失附魔"
row.enchant.tooltipText=(enchantInfo and enchantInfo.description)
or (enchanted and ("附魔 ID: "..enchantId) or "该部位尚未附魔")
row.enchant.missing=not enchanted
row.enchant.spellId=spellId
row.enchant.itemId=nil
row.enchant:Show()
end
local total=math.max(#gems,socketCount(link))
for index=1,math.min(4,total) do
local button=row.gems[index]
local gemId=gems[index]
button.itemId=gemId
button.spellId=nil
button.icon:SetTexture(gemId and ((GetItemIcon and GetItemIcon(gemId)) or EMPTY_ICON) or EMPTY_ICON)
button.border:SetVertexColor(gemId and 0.25 or 1,gemId and 0.8 or 0.2,gemId and 0.9 or 0.2)
button.tooltipTitle=gemId and "宝石" or "空宝石孔"
if gemId then
button.tooltipText=nil
else
button.tooltipText="该插槽尚未镶嵌宝石"
end
button.missing=not gemId
button:Show()
end
return (row.enchant:IsShown() and 1 or 0)+math.min(4,total)
end
local function Create()
local f=CreateFrame("Frame","NoWCLGearInspectPanel",UIParent,"BackdropTemplate")
f:SetSize(MIN_WIDTH,PANEL_HEIGHT)
f:SetFrameStrata("DIALOG")
f:SetClampedToScreen(true)
f:EnableMouse(true)
f:SetBackdrop({bgFile="Interface\\Tooltips\\UI-Tooltip-Background",
edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=true,tileSize=8,edgeSize=16,
insets={left=4,right=4,top=4,bottom=4}})
f:SetBackdropColor(0.02,0.02,0.03,0.96)
f.portrait=f:CreateTexture(nil,"BORDER")
f.portrait:SetSize(44,44);f.portrait:SetPoint("TOPLEFT",18,-16)
f.level=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
f.level:SetPoint("BOTTOM",f.portrait,"BOTTOM",0,-2)
f.name=f:CreateFontString(nil,"OVERLAY","GameFontNormalOutline")
f.name:SetPoint("TOPLEFT",66,-18);f.name:SetJustifyH("LEFT");noWrap(f.name)
f.itemLevel=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
f.itemLevel:SetPoint("TOPLEFT",66,-42);f.itemLevel:SetTextColor(1,0.82,0)
f.loading=f:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
f.loading:SetPoint("TOPLEFT",66,-59);f.loading:SetText("正在获取装备资料…")
f.close=CreateFrame("Button",nil,f,"UIPanelCloseButton")
f.close:SetSize(24,24);f.close:SetPoint("TOPRIGHT",2,2)
f.close:SetScript("OnClick",function() P:Close() end)
f.talent1=createTalent(f,48);f.talent1:SetPoint("TOPRIGHT",-20,-10)
f.talent2=createTalent(f,38);f.talent2:SetPoint("RIGHT",f.talent1,"LEFT",-6,-4)
f.rows={}
for index,slot in ipairs(SLOT_ORDER) do f.rows[index]=createRow(f,slot,index) end
f.damageHeader={}
local damageColumns={
{text="技能",point={"TOPLEFT",34,-82}},
{text="伤害",point={"TOPRIGHT",-116,-82}},
{text="占比",point={"TOPRIGHT",-58,-82}},
{text="次数",point={"TOPRIGHT",-4,-82}},
}
for _,column in ipairs(damageColumns) do
local label=f:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
label:SetPoint(column.point[1],f,column.point[1],column.point[2],column.point[3])
label:SetText(column.text);f.damageHeader[#f.damageHeader+1]=label
end
f.damageSummary=f:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
f.damageSummary:SetPoint("TOPLEFT",66,-59);f.damageSummary:SetJustifyH("LEFT")
f.damageRows={}
for index=1,DAMAGE_VISIBLE_ROWS do f.damageRows[index]=createDamageRow(f,index) end
f:EnableMouseWheel(true)
f:SetScript("OnMouseWheel",function(_,delta)
if f.kind~="damage" then return end
f.damageOffset=math.max(0,math.min(f.damageMaxOffset or 0,(f.damageOffset or 0)-(delta>0 and 3 or -3)))
P:RefreshDamage()
end)
f:SetScript("OnUpdate",function(self,elapsed)
self._refreshTick=(self._refreshTick or 0)+elapsed
if self.kind=="damage" then
if self._refreshTick>=0.5 then self._refreshTick=0;P:RefreshDamage() end
return
end
if not self.loading:IsShown() then return end
self._queryTick=(self._queryTick or 0)+elapsed
if self._queryTick>=1 then
self._queryTick=0
if NoWCL.Readiness and NoWCL.Readiness.RequestPlayerGear then
NoWCL.Readiness:RequestPlayerGear(self.playerName,
{unit=self.unit,sender=self.sender,class=self.class,priority=true})
end
end
if self._refreshTick>=0.5 then self._refreshTick=0;P:Refresh() end
end)
f:Hide()
if Style and Style.RegisterRoot then Style:RegisterRoot(f) end
return f
end
local function showDamageContent(f,shown)
for _,row in ipairs(f.rows or {}) do row:SetShown(not shown) end
for _,label in ipairs(f.damageHeader or {}) do label:SetShown(shown) end
for _,row in ipairs(f.damageRows or {}) do row:SetShown(shown and row.detail~=nil) end
f.damageSummary:SetShown(shown)
if shown then
f.loading:Hide();f.talent1:Hide();f.talent2:Hide()
end
end
local function damagePlayer(view,name)
for _,player in ipairs(view and view.players or {}) do
if samePlayer(player.name,name) then return player end
end
end
function P:RefreshDamage()
if not (frame and frame.playerName and frame.kind=="damage") then return end
local view,selection
if frame.viewProvider then
local ok,providedView,providedSelection=pcall(frame.viewProvider)
if ok then view,selection=providedView,providedSelection end
end
view=view or frame.damageView or {players={}}
selection=selection or frame.selection
local rec=damagePlayer(view,frame.playerName)
if rec then
frame.class=rec.class or frame.class
frame.specId=rec.specId or frame.specId
end
local r,g,b=classColor(frame.class)
frame.name:SetText(frame.playerName or "未知")
frame.name:SetTextColor(r,g,b);frame:SetBackdropBorderColor(r,g,b)
updatePortrait(frame)
frame:SetWidth(DAMAGE_WIDTH);frame:SetHeight(PANEL_HEIGHT)
frame.itemLevel:SetText(U and U.Trunc and U.Trunc(view.encounter or "当前战斗",28) or (view.encounter or "当前战斗"))
local detailed,total=self:BuildDamageRows(rec,view,selection)
local maxOffset=math.max(0,#detailed-DAMAGE_VISIBLE_ROWS)
frame.damageMaxOffset=maxOffset
frame.damageOffset=math.max(0,math.min(maxOffset,frame.damageOffset or 0))
local suffix=maxOffset>0 and string.format("  第 %d-%d / %d 项",frame.damageOffset+1,
math.min(#detailed,frame.damageOffset+DAMAGE_VISIBLE_ROWS),#detailed) or ""
frame.damageSummary:SetText(rec and ("总伤害 "..(U and U.Short and U.Short(total) or tostring(total))..suffix)
or "当前所选战斗没有该角色的伤害资料")
local peak=tonumber(detailed[1] and (detailed[1].amount or detailed[1].v)) or 1
if peak<=0 then peak=1 end
for index,row in ipairs(frame.damageRows) do
local detail=detailed[frame.damageOffset+index]
row.detail=detail;row.total=total
if detail then
local amount=tonumber(detail.amount or detail.v) or 0
local icon=detail.spellId and GetSpellInfo and select(3,GetSpellInfo(detail.spellId)) or EMPTY_ICON
row.icon:SetTexture(icon or EMPTY_ICON)
row.name:SetText(detail.name or (detail.spellId and ("技能 "..detail.spellId)) or "未知技能")
row.amount:SetText(U and U.Short and U.Short(amount) or tostring(amount))
row.share:SetText(U and U.Pct2 and U.Pct2(total>0 and amount/total or 0)
or string.format("%.1f%%",total>0 and amount/total*100 or 0))
row.count:SetText(tostring(tonumber(detail.hits) or tonumber(detail.casts) or 0))
row.bar:SetWidth(math.max(1,420*amount/peak));row.bar:SetColorTexture(r,g,b,0.16)
row:Show()
else
row:Hide()
end
end
showDamageContent(frame,true)
end
function P:Refresh()
if not (frame and frame.playerName) then return end
if frame.kind=="damage" then self:RefreshDamage();return end
showDamageContent(frame,false)
local cache,items=playerGear(frame.playerName)
frame.class=(cache and cache.class) or frame.class
local r,g,b=classColor(frame.class)
frame.name:SetText(frame.playerName or "未知")
frame.name:SetTextColor(r,g,b)
frame:SetBackdropBorderColor(r,g,b)
frame.itemLevel:SetText(string.format("iLvl: %.1f",tonumber(cache and cache.ilvl) or 0))
updatePortrait(frame)
updateTalents(frame,cache)
local maxNameWidth=150
local unresolvedItem=false
for index,row in ipairs(frame.rows) do
local link=items and items[row.slot]
row.item=link
row.level:SetText("")
row.name:SetText("")
row.enchant:Hide();for _,gem in ipairs(row.gems) do gem:Hide() end
if link then
local name,itemLink,quality,itemLevel
if GetItemInfo then name,itemLink,quality,itemLevel=GetItemInfo(link) end
if not name and C_Item and C_Item.RequestLoadItemDataByID then
local itemId=itemFields(link);C_Item.RequestLoadItemDataByID(itemId)
end
if not name then unresolvedItem=true end
local ir,ig,ib=1,1,1
if quality and GetItemQualityColor then ir,ig,ib=GetItemQualityColor(quality) end
row.slotText:SetTextColor(ir,ig,ib)
row.slotBox:SetBackdropColor(ir,ig,ib,0.2);row.slotBox:SetBackdropBorderColor(ir,ig,ib,0.2)
row.level:SetText(itemLevel or "")
row.name:SetText(itemLink or link)
local measured=row.name.GetStringWidth and row.name:GetStringWidth() or 150
maxNameWidth=math.max(maxNameWidth,math.min(410,measured))
row._iconCount=updateEnhancements(row,link,frame.class)
else
row.slotText:SetTextColor(0.55,0.55,0.58)
row.slotBox:SetBackdropColor(0.55,0.55,0.58,0.12);row.slotBox:SetBackdropBorderColor(0.55,0.55,0.58,0.2)
row.name:SetText(items and "未装备" or "等待装备资料")
row.name:SetTextColor(0.5,0.5,0.52)
row._iconCount=0
end
end
local stillLoading=not items or unresolvedItem
if stillLoading then
local elapsed=(GetTime and GetTime() or 0)-(frame.requestStartedAt or 0)
if items then
frame.loading:SetText("正在载入物品资料…")
elseif elapsed>=8 then
frame.loading:SetText("暂未获取，等待 TalentEmuX 或检视…")
else
frame.loading:SetText("正在获取装备资料…")
end
end
frame.loading:SetShown(stillLoading)
local maxIcons=0
for _,row in ipairs(frame.rows) do maxIcons=math.max(maxIcons,row._iconCount or 0) end
local width=math.max(MIN_WIDTH,math.min(MAX_WIDTH,88+maxNameWidth+maxIcons*19+14))
frame:SetWidth(width)
local available=width-98-maxIcons*19
for _,row in ipairs(frame.rows) do
row.name:SetWidth(math.max(90,math.min(maxNameWidth,available)))
local x=80+row.name:GetWidth()+3
if row.enchant:IsShown() then row.enchant:ClearAllPoints();row.enchant:SetPoint("LEFT",row,"LEFT",x,0);x=x+19 end
for _,gem in ipairs(row.gems) do
if gem:IsShown() then gem:ClearAllPoints();gem:SetPoint("LEFT",row,"LEFT",x,0);x=x+19 end
end
end
end
function P:ShowForPlayer(name,class,specId,anchor,unit,sender,kind,viewProvider,selection)
if not name then return end
if not frame then frame=Create() end
local playerName=shortName(name) or name
local panelKind=HOVER_KINDS[kind] and kind or "gear"
local sameRequest=frame:IsShown() and samePlayer(frame.playerName,playerName)
and frame.kind==panelKind and frame.anchor==anchor and frame.selection==selection
frame.playerName=playerName
frame.sender=sender or name
frame.class=class
frame.specId=specId
frame.unit=unit or (U and U.UnitTokenByName and U.UnitTokenByName(name))
frame.kind=panelKind
frame.viewProvider=viewProvider
frame.selection=selection
frame._idleSince=nil
frame.anchor=anchor
if sameRequest then return end
if frame.kind=="damage" then frame.damageOffset=0 end
frame.requestStartedAt=GetTime and GetTime() or 0
frame._queryTick=0
frame:ClearAllPoints()
frame:SetPoint("TOPRIGHT",anchor or UIParent,"TOPLEFT",-4,0)
frame:Show()
if frame.kind=="gear" and NoWCL.Readiness and NoWCL.Readiness.RequestPlayerGear then
NoWCL.Readiness:RequestPlayerGear(frame.playerName,{unit=frame.unit,sender=frame.sender,class=class,priority=true})
end
self:Refresh()
end
function P:GetHoverMode(kind)
kind=HOVER_KINDS[kind] and kind or "gear"
local mode=NoWCL.db and NoWCL.db.window and NoWCL.db.window[HOVER_KEYS[kind]]
return HOVER_MODES[mode] and mode or HOVER_DEFAULTS[kind]
end
function P:SetHoverMode(kind,mode)
if mode==nil then mode=kind;kind="gear" end
kind=HOVER_KINDS[kind] and kind or "gear"
mode=HOVER_MODES[mode] and mode or HOVER_DEFAULTS[kind]
if NoWCL.db then
NoWCL.db.window=NoWCL.db.window or {}
local other=kind=="gear" and "damage" or "gear"
local oldMode=self:GetHoverMode(kind)
if mode~="disabled" and self:GetHoverMode(other)==mode then
NoWCL.db.window[HOVER_KEYS[other]]=oldMode
end
NoWCL.db.window[HOVER_KEYS[kind]]=mode
end
self._nameHoverContext=nil
self:Close()
end
local function kindForTrigger(mode)
if P:GetHoverMode("gear")==mode then return "gear",mode end
if P:GetHoverMode("damage")==mode then return "damage",mode end
end
local function triggerKind()
local ctrl=IsControlKeyDown and IsControlKeyDown()
local alt=IsAltKeyDown and IsAltKeyDown()
if ctrl then
local kind,mode=kindForTrigger("ctrl")
if kind then return kind,mode end
end
if alt then
local kind,mode=kindForTrigger("alt")
if kind then return kind,mode end
end
return kindForTrigger("hover")
end
function P:ApplyHoverContext()
local context=self._nameHoverContext
if not context then return end
local kind,mode=triggerKind()
if not kind then self:SetPlayerNameHovered(context.owner,false);return end
self:ShowForPlayer(context.name,context.class,context.specId,context.anchor,context.unit,context.sender,
kind,context.viewProvider,context.selection)
self._activeTrigger=mode
self:SetPlayerNameHovered(context.owner,true)
end
local function ensureModifierWatcher()
if modifierWatcher then return end
modifierWatcher=CreateFrame("Frame")
modifierWatcher:RegisterEvent("MODIFIER_STATE_CHANGED")
modifierWatcher:SetScript("OnEvent",function(_,_,key)
if key~="LALT" and key~="RALT" and key~="LCTRL" and key~="RCTRL" then return end
local mode=(key=="LCTRL" or key=="RCTRL") and "ctrl" or "alt"
local down=mode=="ctrl" and IsControlKeyDown and IsControlKeyDown()
or mode=="alt" and IsAltKeyDown and IsAltKeyDown()
if not down and P._activeTrigger==mode then
P:Close()
return
end
P:ApplyHoverContext()
end)
end
function P:BeginPlayerNameHover(name,class,specId,anchor,owner,unit,sender,viewProvider,selection)
if not name then return end
if type(unit)=="table" then
local options=unit
unit,sender,viewProvider,selection=options.unit,options.sender,options.viewProvider,options.selection
end
self._nameHoverContext={
name=name,class=class,specId=specId,anchor=anchor,owner=owner,unit=unit,sender=sender,
viewProvider=viewProvider,selection=selection,
}
self._hoverLeaveSerial=(self._hoverLeaveSerial or 0)+1
ensureModifierWatcher()
self:ApplyHoverContext()
end
function P:EndPlayerNameHover(owner)
local context=self._nameHoverContext
if not (context and (not owner or context.owner==owner)) then return end
self._hoverLeaveSerial=(self._hoverLeaveSerial or 0)+1
local serial=self._hoverLeaveSerial
local function closeIfStillOutside()
if serial~=P._hoverLeaveSerial then return end
local current=P._nameHoverContext
if not (current and (not owner or current.owner==owner)) then return end
local mouseOver=owner and ((MouseIsOver and MouseIsOver(owner))
or (owner.IsMouseOver and owner:IsMouseOver()))
if mouseOver then return end
P:Close()
end
if C_Timer and C_Timer.After then C_Timer.After(0.05,closeIfStillOutside)
else closeIfStillOutside() end
end
function P:SetPlayerNameHovered(owner,hovered)
if not frame then return end
if hovered then
frame._nameHoverOwner=owner or true
frame._idleSince=nil
elseif not owner or frame._nameHoverOwner==owner then
frame._nameHoverOwner=nil
end
end
function P:OnGearUpdated(name)
if frame and frame:IsShown() and shortName(name)==shortName(frame.playerName) then self:Refresh() end
end
function P:Close()
self._hoverLeaveSerial=(self._hoverLeaveSerial or 0)+1
self._nameHoverContext=nil
self._activeTrigger=nil
if frame then
frame._nameHoverOwner=nil
frame._idleSince=nil
frame:Hide()
end
end
function P:IsShown()
return frame and frame:IsShown() or false
end
