local addonName, NoWCL = ...
local P = {}
NoWCL.TeamAnnouncementPanel = P
local U = NoWCL.Util
local Style = NoWCL.UIStyle
local frame, copyFrame
local function clampTopCount(value)
return math.max(1, math.min(8, math.floor(tonumber(value) or 3)))
end
local function effectiveScoringConfig()
local sync=NoWCL.Sync
if sync and sync.HasLeaderAuthority and sync:HasLeaderAuthority() and sync.cfg then return sync.cfg end
return NoWCL.db.settings or {}
end
local function savedConfig()
NoWCL.db.window = NoWCL.db.window or {}
local config = NoWCL.db.window.teamAnnouncement
if not config then
local settings = effectiveScoringConfig()
config = {
content="death",
performanceRankingMode=settings.performanceRankingMode == "all" and "all" or "split",
performanceScope=settings.performanceScope == "summary" and "summary" or "fight",
performanceTopCount=clampTopCount(settings.performanceTopCount),
failureType=settings.failureDps == false and settings.failureActivity ~= false and "activity" or "dps",
failureScope=settings.failureScope == "summary" and "summary" or "fight",
channelGroup=true,
channelGuild=false,
channelCopy=false,
}
NoWCL.db.window.teamAnnouncement = config
end
config.content = (config.content == "performance" or config.content == "failures") and config.content or "death"
config.performanceRankingMode = config.performanceRankingMode == "all" and "all" or "split"
config.performanceScope = config.performanceScope == "summary" and "summary" or "fight"
config.performanceTopCount = clampTopCount(config.performanceTopCount)
config.failureType = config.failureType == "activity" and "activity" or "dps"
config.failureScope = config.failureScope == "summary" and "summary" or "fight"
if config.channelGroup == nil then config.channelGroup = true end
return config
end
local function latestFightView()
local stats = NoWCL.Stats
if stats and stats.IsCurrentSegmentVisible and stats:IsCurrentSegmentVisible() then
local players, duration
if stats.GetDisplayPlayers then players, duration = stats:GetDisplayPlayers()
else players, duration = stats:GetPlayers() end
return { players=players or {}, dur=duration or 0, encounter=stats:SegmentName(), live=true }
end
local sync = NoWCL.Sync
local tabs = sync and sync.GetTabs and sync:GetTabs() or {}
local latest = tabs[#tabs]
if latest and sync.GetView then return sync:GetView(latest.fightId, false) end
if stats and stats.ViewPlayers then
local players, duration, encounter = stats:ViewPlayers("current")
return { players=players or {}, dur=duration or 0, encounter=encounter }
end
return { players={}, dur=0, encounter="(无数据)" }
end
local function selectedView(scope)
if scope == "summary" and NoWCL.Sync and NoWCL.Sync.GetView then
local view=NoWCL.Sync:GetView("all", false)
local live=latestFightView()
if live.live and U.ShouldMergeLiveIntoSummary and U.ShouldMergeLiveIntoSummary(live)
and U.MergeCombatViews then
return U.MergeCombatViews(view,live,false)
end
return view
end
return latestFightView()
end
local function buildMessages(config)
local announcements = NoWCL.TeamAnnouncements
if not announcements then return {}, "团队通告模块未加载。" end
if config.content == "death" then
local view = latestFightView()
if not view.players or #view.players == 0 then return {}, "当前没有可通告的战斗记录。" end
return announcements:BuildDeathMessages(view.players), nil
end
if config.content == "performance" then
local view = selectedView(config.performanceScope)
if not view.players or #view.players == 0 then return {}, "当前没有可通告的 DPS 排名数据。" end
local scoring=effectiveScoringConfig()
local options = {
dpsBaseline=scoring.dpsBaseline or scoring.baseline,
dpsRatio=scoring.dpsRatio or scoring.ratio,
dpsMode=scoring.dpsMode,
bosses=(view.cfg and view.cfg.bosses) or scoring.bosses
or (NoWCL.Rules and NoWCL.Rules.GetActive and NoWCL.Rules:GetActive().bosses) or {},
performanceRankingMode=config.performanceRankingMode,
performanceScope=config.performanceScope,
performanceTopCount=config.performanceTopCount,
}
local messages = announcements:BuildPerformanceMessages(view.players, view.dur, options)
return messages, #messages == 0 and "当前没有可通告的 DPS 排名数据。" or nil
end
local view = selectedView(config.failureScope)
if not view.players or #view.players == 0 then return {}, "当前没有可通告的考核数据。" end
local settings = effectiveScoringConfig()
local options = {
dpsBaseline=settings.dpsBaseline or settings.baseline,
dpsRatio=settings.dpsRatio or settings.ratio,
dpsMode=settings.dpsMode,
bosses=(view.cfg and view.cfg.bosses) or settings.bosses
or (NoWCL.Rules and NoWCL.Rules.GetActive and NoWCL.Rules:GetActive().bosses) or {},
checks=settings.checks,
failureDps=config.failureType == "dps",
failureActivity=config.failureType == "activity",
failureScope=config.failureScope,
}
local messages = announcements:BuildFailureMessages(view.players, view.dur, options)
return messages, #messages == 0 and "本次没有符合所选条件的不及格人员。" or nil
end
local function showCopyText(messages)
if not copyFrame then
local f = CreateFrame("Frame","NoWCLTeamAnnouncementCopyFrame",UIParent)
f:SetSize(500,390); f:SetPoint("CENTER"); U.SetPanelLayer(f,true); U.MakeMovable(f)
local bg=f:CreateTexture(nil,"BACKGROUND");bg:SetAllPoints();bg:SetColorTexture(0.05,0.05,0.07,0.97)
local bar=f:CreateTexture(nil,"ARTWORK");bar:SetPoint("TOPLEFT");bar:SetPoint("TOPRIGHT");bar:SetHeight(26);bar:SetColorTexture(0.12,0.12,0.16,1)
local title=f:CreateFontString(nil,"OVERLAY","GameFontNormal");title:SetPoint("LEFT",bar,"LEFT",10,0)
title:SetText("通告文本  |cff888888(Ctrl+C 复制)|r")
local close=CreateFrame("Button",nil,f,"UIPanelCloseButton");close:SetPoint("TOPRIGHT",-2,-2)
local scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT",10,-34);scroll:SetPoint("BOTTOMRIGHT",-30,10)
local edit=CreateFrame("EditBox",nil,scroll);edit:SetMultiLine(true);edit:SetFontObject(ChatFontNormal)
edit:SetWidth(445);edit:SetAutoFocus(false);edit:SetScript("OnEscapePressed",function() f:Hide() end)
scroll:SetScrollChild(edit);f.edit=edit
close:SetScript("OnClick",function() f:Hide() end)
if Style and Style.RegisterRoot then Style:RegisterRoot(f) end
tinsert(UISpecialFrames,"NoWCLTeamAnnouncementCopyFrame")
copyFrame=f
end
local publisher=NoWCL.GroupPublisher
local output={}
for _, message in ipairs(messages) do
output[#output+1]=publisher and publisher.PrefixMessage and publisher:PrefixMessage(message) or message
end
copyFrame.edit:SetText(table.concat(output,"\n"));copyFrame:Show()
copyFrame.edit:HighlightText();copyFrame.edit:SetFocus()
end
local function publishSelection()
local config = savedConfig()
config.performanceTopCount = clampTopCount(frame.topCount:GetText())
frame.topCount:SetText(config.performanceTopCount)
local messages, reason = buildMessages(config)
if #messages == 0 then NoWCL:Print(reason or "当前没有可通告的数据。"); return end
local queue, unavailable = {}, {}
local groupChannel = U.GroupChannel and U.GroupChannel()
if config.channelGroup then
if groupChannel then
for _, message in ipairs(messages) do queue[#queue+1]={message=message,channel=groupChannel} end
else unavailable[#unavailable+1]="团队" end
end
if config.channelGuild then
if IsInGuild and IsInGuild() then
for _, message in ipairs(messages) do queue[#queue+1]={message=message,channel="GUILD"} end
else unavailable[#unavailable+1]="工会" end
end
if config.channelCopy then showCopyText(messages) end
if #queue > 0 then
local publisher=NoWCL.GroupPublisher
local ok, publishReason = publisher and publisher.Publish and publisher:Publish(queue, {
source="manual-team-announcement",
channel=queue[1].channel,
append=true,
bypassRankingGap=true,
})
if not ok then
NoWCL:Print(publishReason == "busy" and "通告发送队列正忙，请稍候重试。" or "团队通告发送失败。")
return
end
end
if #queue == 0 and not config.channelCopy then
NoWCL:Print("请至少选择一个可用的通告频道。")
return
end
if #unavailable > 0 then NoWCL:Print(table.concat(unavailable,"、").."频道当前不可用，已处理其他所选渠道。") end
end
local function setEnabled(control, enabled)
if enabled then control:Enable() else control:Disable() end
if control.label then control.label:SetTextColor(enabled and 1 or 0.5,enabled and 1 or 0.5,enabled and 1 or 0.5) end
end
local function refresh()
if not frame then return end
local config=savedConfig()
frame.death:SetChecked(config.content=="death")
frame.performance:SetChecked(config.content=="performance")
frame.failures:SetChecked(config.content=="failures")
frame.performanceAll:SetChecked(config.performanceRankingMode=="all")
frame.performanceSplit:SetChecked(config.performanceRankingMode=="split")
frame.performanceFight:SetChecked(config.performanceScope=="fight")
frame.performanceSummary:SetChecked(config.performanceScope=="summary")
frame.failureDps:SetChecked(config.failureType=="dps")
frame.failureActivity:SetChecked(config.failureType=="activity")
frame.failureFight:SetChecked(config.failureScope=="fight")
frame.failureSummary:SetChecked(config.failureScope=="summary")
if not frame.topCount:HasFocus() then frame.topCount:SetText(config.performanceTopCount) end
frame.channelGroup:SetChecked(config.channelGroup==true)
frame.channelGuild:SetChecked(config.channelGuild==true)
frame.channelCopy:SetChecked(config.channelCopy==true)
local performance=config.content=="performance"
local failures=config.content=="failures"
for _, control in ipairs({frame.performanceAll,frame.performanceSplit,frame.performanceFight,
frame.performanceSummary,frame.topCount}) do setEnabled(control,performance) end
for _, control in ipairs({frame.failureDps,frame.failureActivity,frame.failureFight,
frame.failureSummary}) do setEnabled(control,failures) end
for _, label in ipairs({frame.performanceModeLabel,frame.performanceScopeLabel}) do
label:SetTextColor(performance and 0.75 or 0.45,performance and 0.78 or 0.45,performance and 0.82 or 0.45)
end
for _, label in ipairs({frame.failureTypeLabel,frame.failureScopeLabel}) do
label:SetTextColor(failures and 0.75 or 0.45,failures and 0.78 or 0.45,failures and 0.82 or 0.45)
end
frame.topCountPrefix:SetTextColor(performance and 0.8 or 0.45,performance and 0.8 or 0.45,performance and 0.8 or 0.45)
frame.topCountSuffix:SetTextColor(performance and 0.8 or 0.45,performance and 0.8 or 0.45,performance and 0.8 or 0.45)
end
local function createRadio(parent,x,y,text,onClick,width)
local button=CreateFrame("CheckButton",nil,parent,"UIRadioButtonTemplate")
button:SetSize(18,18);button:SetPoint("TOPLEFT",x,y)
button.label=parent:CreateFontString(nil,"OVERLAY","GameFontHighlight")
button.label:SetPoint("LEFT",button,"RIGHT",2,0);button.label:SetText(text);button.label:SetWidth(width or 150)
button:SetHitRectInsets(0,-(width or 150),0,0);button:SetScript("OnClick",onClick)
return button
end
local function createCheck(parent,x,y,text,onClick,width)
local button=CreateFrame("CheckButton",nil,parent,"UICheckButtonTemplate")
button:SetSize(18,18);button:SetPoint("TOPLEFT",x,y)
button.label=parent:CreateFontString(nil,"OVERLAY","GameFontHighlight")
button.label:SetPoint("LEFT",button,"RIGHT",0,0);button.label:SetText(text);button.label:SetWidth(width or 120)
button:SetHitRectInsets(0,-(width or 120),0,0);button:SetScript("OnClick",onClick)
return button
end
local function create()
local f=CreateFrame("Frame","NoWCLTeamAnnouncementFrame",UIParent)
f:SetSize(570,420);f:SetPoint("CENTER");U.SetPanelLayer(f,true);U.MakeMovable(f)
local bg=f:CreateTexture(nil,"BACKGROUND");bg:SetAllPoints();bg:SetColorTexture(0.05,0.05,0.07,0.97)
local bar=f:CreateTexture(nil,"ARTWORK");bar:SetPoint("TOPLEFT");bar:SetPoint("TOPRIGHT");bar:SetHeight(28);bar:SetColorTexture(0.12,0.12,0.16,1)
local title=f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge");title:SetPoint("LEFT",bar,"LEFT",10,0);title:SetText("团队通告")
local close=CreateFrame("Button",nil,f,"UIPanelCloseButton");close:SetPoint("TOPRIGHT",-2,-2);close:SetScript("OnClick",function() f:Hide() end)
local contentHead=f:CreateFontString(nil,"OVERLAY","GameFontNormal");contentHead:SetPoint("TOPLEFT",18,-44);contentHead:SetText("通告内容 |cff888888(单选)|r")
local function selectContent(value) return function() savedConfig().content=value;refresh() end end
f.death=createRadio(f,20,-66,"通告本场战斗角色死亡和最后一击（结束后取上一场）",selectContent("death"),410)
f.performance=createRadio(f,20,-98,"通告 DPS 排名",selectContent("performance"),160)
local function setConfig(key,value) return function() savedConfig()[key]=value;refresh() end end
f.performanceModeLabel=f:CreateFontString(nil,"OVERLAY","GameFontDisableSmall");f.performanceModeLabel:SetPoint("TOPLEFT",54,-132);f.performanceModeLabel:SetText("排名：")
f.performanceAll=createRadio(f,100,-126,"全部 DPS",setConfig("performanceRankingMode","all"),72)
f.performanceSplit=createRadio(f,198,-126,"近战 + 远程",setConfig("performanceRankingMode","split"),104)
f.topCountPrefix=f:CreateFontString(nil,"OVERLAY","GameFontDisableSmall");f.topCountPrefix:SetPoint("TOPLEFT",328,-132);f.topCountPrefix:SetText("前")
f.topCount=CreateFrame("EditBox",nil,f,"InputBoxTemplate");f.topCount:SetSize(30,20);f.topCount:SetPoint("TOPLEFT",348,-124)
f.topCount:SetNumeric(true);f.topCount:SetMaxLetters(1);f.topCount:SetAutoFocus(false);f.topCount:SetJustifyH("CENTER")
f.topCount:SetScript("OnEnterPressed",function(self) self:ClearFocus() end)
f.topCount:SetScript("OnEditFocusLost",function(self) savedConfig().performanceTopCount=clampTopCount(self:GetText());refresh() end)
f.topCountSuffix=f:CreateFontString(nil,"OVERLAY","GameFontDisableSmall");f.topCountSuffix:SetPoint("LEFT",f.topCount,"RIGHT",5,0);f.topCountSuffix:SetText("名")
f.performanceScopeLabel=f:CreateFontString(nil,"OVERLAY","GameFontDisableSmall");f.performanceScopeLabel:SetPoint("TOPLEFT",54,-158);f.performanceScopeLabel:SetText("范围：")
f.performanceFight=createRadio(f,100,-152,"本场战斗",setConfig("performanceScope","fight"),80)
f.performanceSummary=createRadio(f,208,-152,"所有战斗统计",setConfig("performanceScope","summary"),112)
f.failures=createRadio(f,20,-188,"通告不及格人员",selectContent("failures"),160)
f.failureTypeLabel=f:CreateFontString(nil,"OVERLAY","GameFontDisableSmall");f.failureTypeLabel:SetPoint("TOPLEFT",54,-222);f.failureTypeLabel:SetText("项目：")
f.failureDps=createRadio(f,100,-216,"DPS 不及格",setConfig("failureType","dps"),90)
f.failureActivity=createRadio(f,220,-216,"活跃度不及格",setConfig("failureType","activity"),112)
f.failureScopeLabel=f:CreateFontString(nil,"OVERLAY","GameFontDisableSmall");f.failureScopeLabel:SetPoint("TOPLEFT",54,-248);f.failureScopeLabel:SetText("范围：")
f.failureFight=createRadio(f,100,-242,"本场战斗",setConfig("failureScope","fight"),80)
f.failureSummary=createRadio(f,208,-242,"所有战斗统计",setConfig("failureScope","summary"),112)
local separator=f:CreateTexture(nil,"ARTWORK");separator:SetPoint("TOPLEFT",18,-276);separator:SetPoint("TOPRIGHT",-18,-276);separator:SetHeight(1);separator:SetColorTexture(1,1,1,0.12)
local channelHead=f:CreateFontString(nil,"OVERLAY","GameFontNormal");channelHead:SetPoint("TOPLEFT",18,-294);channelHead:SetText("通告频道 |cff888888(可多选)|r")
local function toggleChannel(key) return function(self) savedConfig()[key]=self:GetChecked() and true or false end end
f.channelGroup=createCheck(f,20,-318,"团队",toggleChannel("channelGroup"),60)
f.channelGuild=createCheck(f,112,-318,"工会",toggleChannel("channelGuild"),60)
f.channelCopy=createCheck(f,204,-318,"通告文本复制到剪贴板",toggleChannel("channelCopy"),190)
f.channelCopy:SetScript("OnEnter",function(self)
if not GameTooltip then return end
GameTooltip:SetOwner(self,"ANCHOR_TOP");GameTooltip:AddLine("复制通告文本")
GameTooltip:AddLine("WoW 插件不能直接写入系统剪贴板；通告时会打开已全选的文本框，请按 Ctrl+C。",0.8,0.8,0.8,true);GameTooltip:Show()
end)
f.channelCopy:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
local publish=CreateFrame("Button",nil,f,"UIPanelButtonTemplate");publish:SetSize(126,26);publish:SetPoint("BOTTOMRIGHT",-18,16);publish:SetText("立即通告");publish:SetScript("OnClick",publishSelection)
local note=f:CreateFontString(nil,"OVERLAY","GameFontDisableSmall");note:SetPoint("BOTTOMLEFT",18,21);note:SetText("本场战斗：战斗中取当前，脱战后取上一场。")
if Style and Style.RegisterRoot then Style:RegisterRoot(f) end
tinsert(UISpecialFrames,"NoWCLTeamAnnouncementFrame")
f:Hide();frame=f
return f
end
function P:Show()
if not frame then create() end
refresh();frame:Show();frame:Raise()
end
function P:Toggle()
if frame and frame:IsShown() then frame:Hide() else self:Show() end
end
