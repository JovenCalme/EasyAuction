local addonName, NoWCL = ...
local Z = {}
NoWCL.AzerothUI = Z
local U = NoWCL.Util
local H = NoWCL.AzerothHistory
local Style = NoWCL.UIStyle
local JOURNAL_BG = "Interface\\AddOns\\" .. addonName .. "\\Media\\azeroth-journal.tga"
Z.view = "calendar"
Z.weekOffset = 0
Z.characterGUID = nil
Z.selectedWeek = nil
Z.selectedRaid = nil
Z.selectedFight = nil
Z.returnView = nil
local panel
local WEEK = 7 * 24 * 60 * 60
local function classColorText(text, class)
local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
if not c then return text or "?" end
return string.format("|cff%02x%02x%02x%s|r", c.r*255, c.g*255, c.b*255, text or "?")
end
local function orderedRaids()
local out = {}
for _, phase in ipairs(H.catalog.phases) do
for _, key in ipairs(phase.raids or {}) do out[#out + 1] = key end
end
return out
end
local function currentCharacter()
local db = H.db or NoWCLAzerothDB or {}
local guid = Z.characterGUID or H:CurrentCharacterGUID()
if not (db.characters and db.characters[guid]) then
local chars = H:GetCharacters()
guid = chars[1] and chars[1].guid
end
Z.characterGUID = guid
return guid, guid and db.characters[guid]
end
local function resetWidget(w)
w:Hide(); w:ClearAllPoints(); w:SetScript("OnClick", nil); w:SetScript("OnEnter", nil); w:SetScript("OnLeave", nil)
w.bg:Hide(); w.fill:Hide(); w.corner:Hide()
w.fill:ClearAllPoints(); w.corner:ClearAllPoints()
for _, b in ipairs(w.border) do b:ClearAllPoints(); b:Hide() end
for _, fs in ipairs(w.texts) do fs:ClearAllPoints(); fs:SetJustifyH("LEFT"); fs:SetTextColor(0.92,0.92,0.90); fs:SetText(""); fs:Hide() end
for _, tex in ipairs(w.parts) do tex:ClearAllPoints(); tex:Hide() end
for _, fs in ipairs(w.partTexts) do fs:ClearAllPoints(); fs:SetJustifyH("CENTER"); fs:SetTextColor(0.94,0.90,0.82); fs:SetText(""); fs:Hide() end
end
local function acquireWidget()
panel._widgetIndex = panel._widgetIndex + 1
local i = panel._widgetIndex
local w = panel.widgets[i]
if not w then
w = CreateFrame("Button", nil, panel.content)
w.bg = w:CreateTexture(nil, "BACKGROUND"); w.bg:SetAllPoints()
w.fill = w:CreateTexture(nil, "BORDER")
w.corner = w:CreateTexture(nil, "OVERLAY")
w.border = {}
for n=1,4 do w.border[n] = w:CreateTexture(nil, "ARTWORK") end
w.texts = {}
for n=1,4 do
local fs = w:CreateFontString(nil, "OVERLAY", n == 1 and "GameFontNormal" or "GameFontHighlightSmall")
fs:SetJustifyH("LEFT"); w.texts[n] = fs
if Style and Style.ApplyFontFace then Style:ApplyFontFace(fs) end
end
w.parts, w.partTexts = {}, {}
for n=1,3 do
w.parts[n] = w:CreateTexture(nil, "BORDER")
w.partTexts[n] = w:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
w.partTexts[n]:SetJustifyH("CENTER")
if Style and Style.ApplyFontFace then Style:ApplyFontFace(w.partTexts[n]) end
end
local hl=w:CreateTexture(nil,"HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(0.35,0.55,0.85,0.18)
panel.widgets[i] = w
end
resetWidget(w); w:Show(); return w
end
local function clearContent()
panel._widgetIndex = 0
for _, w in ipairs(panel.widgets) do w:Hide() end
panel.empty:Hide()
end
local function setBorder(w, r, g, b, a)
local t, l, bot, rr = unpack(w.border)
t:SetPoint("TOPLEFT"); t:SetPoint("TOPRIGHT"); t:SetHeight(1)
bot:SetPoint("BOTTOMLEFT"); bot:SetPoint("BOTTOMRIGHT"); bot:SetHeight(1)
l:SetPoint("TOPLEFT"); l:SetPoint("BOTTOMLEFT"); l:SetWidth(1)
rr:SetPoint("TOPRIGHT"); rr:SetPoint("BOTTOMRIGHT"); rr:SetWidth(1)
for _, tex in ipairs(w.border) do tex:SetColorTexture(r,g,b,a or 1); tex:Show() end
end
local function setTabStates()
panel.calendarBtn:SetButtonState(Z.view == "calendar" and "PUSHED" or "NORMAL")
panel.historyBtn:SetButtonState((Z.view == "history" or Z.view == "raid" or Z.view == "fight") and "PUSHED" or "NORMAL")
panel.bossBtn:SetButtonState(Z.view == "bosses" and "PUSHED" or "NORMAL")
end
local function outcomeText(fight)
if fight.outcome == "kill" then return "|cff55dd77击杀|r" end
if fight.outcome == "wipe" then return "|cffff6666灭团|r" end
return "|cffffcc66结果未知|r"
end
local function raidSummary(guid, resetKey, raidKey)
return H:RaidActivitySummary(guid, resetKey, raidKey)
end
local function renderCalendar(guid)
local width = panel.content:GetWidth()
local height = panel.content:GetHeight()
local weeks = H:GetWeeks(guid, 12, Z.weekOffset)
local gap, cols = 4, 4
local margin = math.max(52, math.floor(width * 0.07))
local cardW = math.floor((width - margin*2 - gap*(cols-1))/cols)
local cardH = math.floor((height - gap*4)/3)
local currentReset = H:ResetKey(time())
for i, resetKey in ipairs(weeks) do
local col, row = (i-1)%cols, math.floor((i-1)/cols)
local x, y = margin + col*(cardW+gap), -gap - row*(cardH+gap)
local summary = H:WeekSummary(guid, resetKey)
local card = acquireWidget(); card:SetPoint("TOPLEFT",x,y); card:SetSize(cardW,cardH)
if resetKey == currentReset then
card.bg:SetColorTexture(0.30,0.12,0.035,0.18); card.bg:Show()
setBorder(card,0.90,0.66,0.20,0.95)
elseif summary.complete then
card.bg:SetColorTexture(0.12,0.32,0.16,0.18); card.bg:Show()
setBorder(card,0.82,0.62,0.18,0.90)
else
card.bg:SetColorTexture(0.18,0.10,0.045,0.06); card.bg:Show()
setBorder(card,0.28,0.17,0.08,0.24)
end
card.texts[1]:SetPoint("TOPLEFT",8,-7); card.texts[1]:SetText(H:WeekLabel(resetKey)); card.texts[1]:SetTextColor(0.27,0.12,0.035); card.texts[1]:Show()
card.texts[2]:SetPoint("TOPRIGHT",-7,-7); card.texts[2]:SetJustifyH("RIGHT")
card.texts[2]:SetText(summary.complete and "|cffffd45a✓|r" or ""); card.texts[2]:Show()
if not summary.applicable then
card.texts[3]:SetPoint("CENTER",0,-5); card.texts[3]:SetText("|cff6b5136尚未开始记录|r"); card.texts[3]:Show()
else
for pi, ps in ipairs(summary.phases) do
local rowH = math.max(17, math.floor((cardH-34)/4)-2)
local py = -30 - (pi-1)*(rowH+2)
local rowW = acquireWidget(); rowW:SetPoint("TOPLEFT",x+7,y+py); rowW:SetSize(cardW-14,rowH)
rowW.bg:SetColorTexture(0.11,0.055,0.035,0.78); rowW.bg:Show()
rowW.texts[1]:SetPoint("LEFT",3,0); rowW.texts[1]:SetWidth(24); rowW.texts[1]:SetText(ps.name); rowW.texts[1]:SetTextColor(0.94,0.72,0.25); rowW.texts[1]:Show()
local raidX, avail = 27, cardW-44
local segW = #ps.raids > 0 and avail/#ps.raids or avail
for ri, item in ipairs(ps.raids) do
local prog = item.progress
local frac = prog.required > 0 and prog.done/prog.required or 0
local sx = raidX + (ri-1)*segW
local part = rowW.parts[ri]; part:ClearAllPoints(); part:SetPoint("LEFT",sx,0)
part:SetSize(math.max(1,segW*frac-2),math.max(12,rowH-4))
if prog.complete then part:SetColorTexture(0.10,0.52,0.25,0.95)
elseif frac > 0 then part:SetColorTexture(0.76,0.45,0.08,0.92)
else part:SetColorTexture(0.22,0.18,0.15,0.72) end
part:Show()
local label = rowW.partTexts[ri]; label:ClearAllPoints(); label:SetPoint("LEFT",sx,0); label:SetWidth(segW-2)
local raid = H.catalog.raids[item.key]
local wipe = false for _, n in pairs(prog.attempts or {}) do if n > 0 and prog.done < prog.required then wipe=true end end
label:SetText((raid and raid.short or item.key)..(prog.complete and prog.allOptional and " ★" or "")..(wipe and " |cffff5555!|r" or "")); label:Show()
end
end
end
card:SetScript("OnClick", function() Z.selectedWeek=resetKey; Z.view="history"; Z:Refresh() end)
end
end
local function renderHistory(guid)
local width = panel.content:GetWidth()
local raids = orderedRaids()
local weekW, gap = 105, 3
local cellW = math.floor((width-weekW-gap*(#raids+2))/#raids)
local head = acquireWidget(); head:SetPoint("TOPLEFT",4,-6); head:SetSize(width-8,24); head.bg:SetColorTexture(0.15,0.15,0.18,1); head.bg:Show()
head.texts[1]:SetPoint("LEFT",6,0); head.texts[1]:SetWidth(weekW-8); head.texts[1]:SetText("周 CD"); head.texts[1]:Show()
for i,key in ipairs(raids) do
local fs=head.partTexts[((i-1)%3)+1]
if i <= 3 then fs:ClearAllPoints(); fs:SetPoint("LEFT",weekW+(i-1)*(cellW+gap),0); fs:SetWidth(cellW); fs:SetText(H.catalog.raids[key].short); fs:Show() end
end
for i=4,#raids do
local hw=acquireWidget(); hw:SetPoint("TOPLEFT",weekW+(i-1)*(cellW+gap),-6); hw:SetSize(cellW,24)
hw.texts[1]:SetAllPoints(); hw.texts[1]:SetJustifyH("CENTER"); hw.texts[1]:SetText(H.catalog.raids[raids[i]].short); hw.texts[1]:Show()
end
local weeks=H:GetWeeks(guid,8,Z.weekOffset)
for wi,resetKey in ipairs(weeks) do
local y=-33-(wi-1)*55
local label=acquireWidget(); label:SetPoint("TOPLEFT",4,y); label:SetSize(weekW-2,51)
label.bg:SetColorTexture(resetKey==Z.selectedWeek and 0.18 or 0.10,0.13,0.17,0.95); label.bg:Show()
label.texts[1]:SetPoint("LEFT",6,0); label.texts[1]:SetText(H:WeekLabel(resetKey)); label.texts[1]:Show()
for ri,raidKey in ipairs(raids) do
local progress, sum=raidSummary(guid,resetKey,raidKey)
local cell=acquireWidget(); cell:SetPoint("TOPLEFT",weekW+(ri-1)*(cellW+gap),y); cell:SetSize(cellW,51)
cell.bg:SetColorTexture(progress.complete and 0.08 or 0.10,progress.complete and 0.26 or 0.10,progress.complete and 0.13 or 0.12,0.95); cell.bg:Show()
cell.texts[1]:SetPoint("TOPLEFT",4,-4); cell.texts[1]:SetText(string.format("%d/%d%s",progress.done,progress.required,progress.complete and progress.allOptional and " ★" or "")); cell.texts[1]:Show()
cell.texts[2]:SetPoint("TOPLEFT",4,-20); cell.texts[2]:SetText(sum.rank and ("#"..sum.rank.."  "..U.Short(sum.rate)) or "-"); cell.texts[2]:Show()
cell.texts[3]:SetPoint("TOPLEFT",4,-35); cell.texts[3]:SetText(sum.duration>0 and ("均"..U.Short(sum.teamAverage).." "..U.FmtTime(sum.duration)) or ""); cell.texts[3]:Show()
cell:SetScript("OnClick",function() Z.selectedWeek=resetKey;Z.selectedRaid=raidKey;Z.view="raid";Z:Refresh() end)
end
end
end
local function renderRaid(guid)
local raid=H.catalog.raids[Z.selectedRaid]
if not raid then Z.view="history"; return Z:Refresh() end
local progress,sum=raidSummary(guid,Z.selectedWeek,Z.selectedRaid)
local back=acquireWidget(); back:SetPoint("TOPLEFT",8,-8); back:SetSize(74,22); back.texts[1]:SetAllPoints();back.texts[1]:SetText("← 返回");back.texts[1]:SetJustifyH("CENTER");back.texts[1]:Show();back:SetScript("OnClick",function()Z.view="history";Z:Refresh()end)
local title=acquireWidget();title:SetPoint("TOPLEFT",92,-8);title:SetSize(panel.content:GetWidth()-100,42)
title.texts[1]:SetPoint("TOPLEFT",0,0);title.texts[1]:SetText(raid.name.."  "..H:WeekLabel(Z.selectedWeek));title.texts[1]:Show()
title.texts[2]:SetPoint("TOPLEFT",0,-20);title.texts[2]:SetText(string.format("完成 %d/%d  角色排名 %s  加权秒量 %s  全团平均 %s  活动耗时 %s",progress.done,progress.required,sum.rank and ("#"..sum.rank) or "-",U.Short(sum.rate),U.Short(sum.teamAverage),U.FmtTime(sum.duration)));title.texts[2]:Show()
local fights=progress.fights
table.sort(fights,function(a,b)return(a.ts or 0)>(b.ts or 0)end)
for i,fight in ipairs(fights) do
if i>16 then break end
local row=acquireWidget();row:SetPoint("TOPLEFT",8,-62-(i-1)*26);row:SetSize(panel.content:GetWidth()-16,23)
row.bg:SetColorTexture(i%2==0 and 0.09 or 0.12,0.12,0.14,0.9);row.bg:Show()
row.texts[1]:SetPoint("LEFT",6,0);row.texts[1]:SetWidth(220);row.texts[1]:SetText(fight.bossName);row.texts[1]:Show()
row.texts[2]:SetPoint("LEFT",230,0);row.texts[2]:SetWidth(110);row.texts[2]:SetText(outcomeText(fight));row.texts[2]:Show()
row.texts[3]:SetPoint("LEFT",345,0);row.texts[3]:SetWidth(260);row.texts[3]:SetText(string.format("#%s  %s  %s",fight.playerRank or "-",U.Short(fight.playerRate or 0),U.FmtTime(fight.duration or 0)));row.texts[3]:Show()
row.texts[4]:SetPoint("RIGHT",-6,0);row.texts[4]:SetJustifyH("RIGHT");row.texts[4]:SetText(date("%m/%d %H:%M",fight.ts or 0));row.texts[4]:Show()
row:SetScript("OnClick",function()Z.selectedFight=fight.id;Z.returnView="raid";Z.view="fight";Z:Refresh()end)
end
if #fights==0 then panel.empty:SetText("这一周还没有该团本的历史记录");panel.empty:Show() end
end
local function renderBossArchive(guid)
local grouped={}
for _,fight in ipairs(H:GetFights(guid)) do
local g=grouped[fight.bossName] or {name=fight.bossName,count=0,kills=0,wipes=0,best=0,total=0,last=fight}
g.count=g.count+1;if fight.outcome=="kill"then g.kills=g.kills+1 elseif fight.outcome=="wipe"then g.wipes=g.wipes+1 end
g.total=g.total+(fight.playerRate or 0);if(fight.playerRate or 0)>g.best then g.best=fight.playerRate or 0 end
if(fight.ts or 0)>(g.last.ts or 0)then g.last=fight end;grouped[fight.bossName]=g
end
local list={} for _,g in pairs(grouped)do list[#list+1]=g end
table.sort(list,function(a,b)return(a.last.ts or 0)>(b.last.ts or 0)end)
for i,g in ipairs(list)do
if i>17 then break end
local row=acquireWidget();row:SetPoint("TOPLEFT",8,-8-(i-1)*27);row:SetSize(panel.content:GetWidth()-16,24)
row.bg:SetColorTexture(i%2==0 and 0.09 or 0.12,0.12,0.14,0.9);row.bg:Show()
row.texts[1]:SetPoint("LEFT",7,0);row.texts[1]:SetWidth(260);row.texts[1]:SetText(g.name);row.texts[1]:Show()
row.texts[2]:SetPoint("LEFT",275,0);row.texts[2]:SetWidth(190);row.texts[2]:SetText(string.format("%d战  |cff55dd77%d胜|r  |cffff6666%d灭|r",g.count,g.kills,g.wipes));row.texts[2]:Show()
row.texts[3]:SetPoint("LEFT",470,0);row.texts[3]:SetWidth(220);row.texts[3]:SetText("最佳 "..U.Short(g.best).."  平均 "..U.Short(g.total/g.count));row.texts[3]:Show()
row.texts[4]:SetPoint("RIGHT",-7,0);row.texts[4]:SetJustifyH("RIGHT");row.texts[4]:SetText(date("%m/%d",g.last.ts or 0));row.texts[4]:Show()
row:SetScript("OnClick",function()Z.selectedFight=g.last.id;Z.returnView="bosses";Z.view="fight";Z:Refresh()end)
end
if #list==0 then panel.empty:SetText("还没有可归档的 Boss 战记录");panel.empty:Show() end
end
local function sortedMap(src)
local out={} for name,value in pairs(src or {})do out[#out+1]={name=name,value=tonumber(value)or 0}end
table.sort(out,function(a,b)return a.value>b.value end);return out
end
local function renderFight(guid)
local fight=H.db.fights[Z.selectedFight]
if not fight or fight.characterGUID~=guid then Z.view=Z.returnView or "history";return Z:Refresh()end
local back=acquireWidget();back:SetPoint("TOPLEFT",8,-8);back:SetSize(74,22);back.texts[1]:SetAllPoints();back.texts[1]:SetJustifyH("CENTER");back.texts[1]:SetText("← 返回");back.texts[1]:Show();back:SetScript("OnClick",function()Z.view=Z.returnView or "history";Z:Refresh()end)
local head=acquireWidget();head:SetPoint("TOPLEFT",92,-8);head:SetSize(panel.content:GetWidth()-100,54)
head.texts[1]:SetPoint("TOPLEFT",0,0);head.texts[1]:SetText(fight.bossName.."  "..outcomeText(fight));head.texts[1]:Show()
head.texts[2]:SetPoint("TOPLEFT",0,-20);head.texts[2]:SetText(string.format("%s  总量 %s  秒量 %s  排名 #%s  装等 %s  死亡 %d",date("%Y/%m/%d %H:%M",fight.ts or 0),U.Short(fight.playerAmount or 0),U.Short(fight.playerRate or 0),fight.playerRank or "-",fight.player.readyIlvl or "-",fight.player.deaths or 0));head.texts[2]:Show()
local role=U.RoleOfPlayer and U.RoleOfPlayer(fight.player) or "DAMAGER"
local left=role=="HEALER" and sortedMap(fight.player.heals)or sortedMap(fight.player.spells)
local right=role=="HEALER" and sortedMap(fight.player.healTargets)or sortedMap(fight.player.targets)
local labels=acquireWidget();labels:SetPoint("TOPLEFT",8,-72);labels:SetSize(panel.content:GetWidth()-16,22)
labels.texts[1]:SetPoint("LEFT",4,0);labels.texts[1]:SetText(role=="HEALER"and"按治疗技能"or"按伤害技能");labels.texts[1]:Show()
labels.texts[2]:SetPoint("LEFT",panel.content:GetWidth()/2,0);labels.texts[2]:SetText(role=="HEALER"and"按治疗目标"or"按伤害目标");labels.texts[2]:Show()
for i=1,math.max(math.min(#left,14),math.min(#right,14))do
local row=acquireWidget();row:SetPoint("TOPLEFT",8,-98-(i-1)*25);row:SetSize(panel.content:GetWidth()-16,22);row.bg:SetColorTexture(i%2==0 and 0.08 or 0.11,0.11,0.13,0.9);row.bg:Show()
local l,r=left[i],right[i]
row.texts[1]:SetPoint("LEFT",6,0);row.texts[1]:SetWidth(panel.content:GetWidth()/2-90);row.texts[1]:SetText(l and l.name or "");row.texts[1]:Show()
row.texts[2]:SetPoint("LEFT",panel.content:GetWidth()/2-90,0);row.texts[2]:SetWidth(80);row.texts[2]:SetJustifyH("RIGHT");row.texts[2]:SetText(l and U.Short(l.value)or"");row.texts[2]:Show()
row.texts[3]:SetPoint("LEFT",panel.content:GetWidth()/2+6,0);row.texts[3]:SetWidth(panel.content:GetWidth()/2-100);row.texts[3]:SetText(r and r.name or "");row.texts[3]:Show()
row.texts[4]:SetPoint("RIGHT",-6,0);row.texts[4]:SetWidth(80);row.texts[4]:SetJustifyH("RIGHT");row.texts[4]:SetText(r and U.Short(r.value)or"");row.texts[4]:Show()
end
end
function Z:Refresh()
if not panel or not panel:IsShown() then return end
H:UpdateResetAnchor()
local guid,char=currentCharacter()
panel.character.itemsFn=function()
local out={}for _,c in ipairs(H:GetCharacters())do out[#out+1]={text=(c.name or "?")..((c.realm and c.realm~="")and("-"..c.realm)or""),value=c.guid,checked=c.guid==guid}end return out
end
panel.character:SetText(char and classColorText(char.name,char.class)or"无角色")
panel.prev:SetShown(Z.view=="calendar"or Z.view=="history")
panel.next:SetShown(Z.view=="calendar"or Z.view=="history")
panel.readingShade:SetShown(Z.view~="calendar")
setTabStates();clearContent()
if not guid then panel.empty:SetText("尚未发现加载过 NoWCL 的角色");panel.empty:Show();return end
if Z.view=="calendar"then renderCalendar(guid)
elseif Z.view=="history"then renderHistory(guid)
elseif Z.view=="raid"then renderRaid(guid)
elseif Z.view=="bosses"then renderBossArchive(guid)
elseif Z.view=="fight"then renderFight(guid)end
end
function Z:CreatePanel(parent)
if panel then return panel end
local p=CreateFrame("Frame",nil,parent);p:SetPoint("TOPLEFT",0,-70);p:SetPoint("BOTTOMRIGHT",0,0);p:Hide();panel=p
p.widgets={};p._widgetIndex=0
p.journalArt=p:CreateTexture(nil,"BACKGROUND",nil,-8);p.journalArt:SetAllPoints();p.journalArt:SetTexture(JOURNAL_BG)
p.readingShade=p:CreateTexture(nil,"BACKGROUND",nil,-6);p.readingShade:SetPoint("TOPLEFT",55,-74);p.readingShade:SetPoint("BOTTOMRIGHT",-55,28);p.readingShade:SetColorTexture(0.035,0.024,0.018,0.78);p.readingShade:Hide()
p.calendarBtn=CreateFrame("Button",nil,p,"UIPanelButtonTemplate");p.calendarBtn:SetSize(90,22);p.calendarBtn:SetPoint("TOPLEFT",70,-24);p.calendarBtn:SetText("周进度")
p.historyBtn=CreateFrame("Button",nil,p,"UIPanelButtonTemplate");p.historyBtn:SetSize(90,22);p.historyBtn:SetPoint("LEFT",p.calendarBtn,"RIGHT",4,0);p.historyBtn:SetText("战斗历史")
p.bossBtn=CreateFrame("Button",nil,p,"UIPanelButtonTemplate");p.bossBtn:SetSize(90,22);p.bossBtn:SetPoint("LEFT",p.historyBtn,"RIGHT",4,0);p.bossBtn:SetText("Boss 档案")
p.character=U.MakeDropdown(p,170);p.character:SetPoint("TOPRIGHT",-105,-24)
p.prev=CreateFrame("Button",nil,p,"UIPanelButtonTemplate");p.prev:SetSize(30,22);p.prev:SetPoint("RIGHT",p.character,"LEFT",-4,0);p.prev:SetText("<")
p.next=CreateFrame("Button",nil,p,"UIPanelButtonTemplate");p.next:SetSize(30,22);p.next:SetPoint("LEFT",p.character,"RIGHT",4,0);p.next:SetText(">")
p.content=CreateFrame("Frame",nil,p);p.content:SetPoint("TOPLEFT",0,-74);p.content:SetPoint("BOTTOMRIGHT",0,28)
p.empty=p.content:CreateFontString(nil,"OVERLAY","GameFontDisable");p.empty:SetPoint("CENTER");p.empty:Hide()
p.calendarBtn:SetScript("OnClick",function()Z.view="calendar";Z:Refresh()end)
p.historyBtn:SetScript("OnClick",function()Z.view="history";Z:Refresh()end)
p.bossBtn:SetScript("OnClick",function()Z.view="bosses";Z:Refresh()end)
p.character.onSelect=function(value)Z.characterGUID=value;Z.selectedWeek=nil;Z.view="calendar";Z:Refresh()end
p.prev:SetScript("OnClick",function()local step=Z.view=="calendar"and 12 or 8;Z.weekOffset=Z.weekOffset+step;Z:Refresh()end)
p.next:SetScript("OnClick",function()local step=Z.view=="calendar"and 12 or 8;Z.weekOffset=math.max(0,Z.weekOffset-step);Z:Refresh()end)
if U.RegisterOpacityChrome then U.RegisterOpacityChrome(parent,p.journalArt,p.readingShade)end
if U.RegisterOpacityChromeHover then U.RegisterOpacityChromeHover(parent,p)end
return p
end
