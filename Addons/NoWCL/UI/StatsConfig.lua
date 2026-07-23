local addonName, NoWCL = ...
local S = {}
NoWCL.StatsConfig = S
local W = NoWCL.WCLBosses
local frame, bossRows = nil, {}
S.tab = "p4"
local FRAME_W, FRAME_H = 560, 680
local CONTENT_W, TEXT_W = 510, 492
local function canEdit()
return not (NoWCL.Sync and NoWCL.Sync.HasLeaderAuthority
and NoWCL.Sync:HasLeaderAuthority())
end
local function activeBossCfg()
if not canEdit() and NoWCL.Sync and NoWCL.Sync.cfg then return NoWCL.Sync.cfg.bossCfg or {} end
return NoWCL.db.settings.bossCfg or {}
end
local function activeBossProfile()
if not canEdit() and NoWCL.Sync and NoWCL.Sync.cfg then
return W:NormalizeProfile(NoWCL.Sync.cfg.bossProfile or (NoWCL.Sync.cfg.bossCfg or {}).__profile, W.PROFILE_WCL45)
end
return W:NormalizeProfile(NoWCL.db.settings.bossProfile)
end
local function bcfg(boss)
local c=NoWCL.db.settings.bossCfg
c.__profile=activeBossProfile()
c[boss]=c[boss] or {}; c[boss].exclude=c[boss].exclude or {}
return c[boss]
end
local function announceLeaderSetting(text)
if NoWCL.Toast and NoWCL.Toast.BroadcastLeaderSetting then
NoWCL.Toast:BroadcastLeaderSetting(text)
end
end
function S.SetOverride(map, key, value, defaultValue)
if value == defaultValue then map[key] = nil else map[key] = value end
end
local function scopeChanged(boss, notice)
if NoWCL.Sync and NoWCL.Sync.OnBossScopeChanged then NoWCL.Sync:OnBossScopeChanged(boss) end
if notice then announceLeaderSetting(notice) end
S:Refresh()
end
local function defaultOtherTrash(boss) local b=W.byName[boss]; return (b and b.otherTrash) and true or false end
local function defaultExcluded() return false end
local function defaultSummaryExcluded(boss)
return W.DefaultExcludeFromSummary and W:DefaultExcludeFromSummary(boss) or false
end
local function summaryDefaultChanged(boss, notice)
if NoWCL.Sync and NoWCL.Sync.OnBossSummaryDefaultChanged then NoWCL.Sync:OnBossSummaryDefaultChanged(boss)
else scopeChanged(boss) end
if notice then announceLeaderSetting(notice) end
S:Refresh()
end
local function defaultNpcExcluded(boss, npc)
local base = W.byName[boss]
for _, id in ipairs((base and base.big) or {}) do
if id == npc then return defaultExcluded(boss) end
end
return not W:ProfileIncludesNpc(activeBossProfile(), boss, npc)
end
local function effectiveExcluded(boss, npc)
local c = activeBossCfg()[boss]
local ov = c and c.exclude and c.exclude[npc]
if ov ~= nil then return ov and true or false end
return defaultExcluded(boss)
end
local function effectiveOtherTrash(boss)
local c=activeBossCfg()[boss]
if c and c.otherTrash ~= nil then return c.otherTrash and true or false end
return defaultOtherTrash(boss)
end
local function effectiveSummaryExcluded(boss)
local c=activeBossCfg()[boss]
if c and c.excludeFromSummary ~= nil then return c.excludeFromSummary and true or false end
return defaultSummaryExcluded(boss)
end
local function effectiveNonBossIncluded(boss, npc)
local c = activeBossCfg()[boss]
local ov = c and c.exclude and c.exclude[npc]
if ov ~= nil then return not ov end
return not defaultNpcExcluded(boss, npc)
end
function S.IsCustom()
for boss, c in pairs(activeBossCfg()) do
if type(c) == "table" then
if c.otherTrash ~= nil and (c.otherTrash and true or false) ~= defaultOtherTrash(boss) then return true end
if c.excludeFromSummary ~= nil and (c.excludeFromSummary and true or false) ~= defaultSummaryExcluded(boss) then return true end
if c.exclude then
for npc, excluded in pairs(c.exclude) do
if (excluded and true or false) ~= defaultNpcExcluded(boss, npc) then return true end
end
end
end
end
return false
end
function S.ActiveLabel()
if S.IsCustom() then return "自定义" end
return W:ProfileName(activeBossProfile())
end
local function mkCheck(parent)
local cb=CreateFrame("CheckButton",nil,parent,"UICheckButtonTemplate"); cb:SetSize(20,20)
cb.lbl=parent:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); cb.lbl:SetPoint("LEFT",cb,"RIGHT",1,0)
cb.lbl:SetWidth(360); cb.lbl:SetJustifyH("LEFT")
function cb:SetLabelWidth(width)
self.lbl:SetWidth(width)
if self.SetHitRectInsets then self:SetHitRectInsets(0, -(width + 1), 0, 0) end
end
cb:SetLabelWidth(360)
return cb
end
local function npcLabel(npc)
return W.npcName[npc] or "未知目标"
end
local function nonBossText(base)
local out = {}
for _, npc in ipairs((base and base.nonBoss) or {}) do out[#out+1] = npcLabel(npc) end
local more = base and base.nonBossText
if type(more) == "string" then
out[#out+1] = more
elseif type(more) == "table" then
for _, txt in ipairs(more) do out[#out+1] = txt end
end
return table.concat(out, "、")
end
local function hasNonBossIds(base)
return base and base.nonBoss and #base.nonBoss > 0
end
local function textBlock(parent, x, y, template, text, width)
local fs=parent:CreateFontString(nil,"OVERLAY",template or "GameFontHighlightSmall")
fs:SetPoint("TOPLEFT",x,y); fs:SetWidth(width or TEXT_W); fs:SetJustifyH("LEFT")
fs:SetText(text or "")
local h = (fs.GetStringHeight and fs:GetStringHeight()) or 14
if h < 12 then h = 12 end
return fs, h
end
local SKIP_RULES = {
["只计所列目标;未列出的同场敌对单位排除"] = true,
["无额外机制增益还原;仅应用通用有效伤害与目标集合规则"] = true,
}
local function displayRules(rules)
local out = {}
for _, rule in ipairs(rules or {}) do
if not SKIP_RULES[rule] then out[#out + 1] = rule end
end
return out
end
local function buildBossRows(content, order, opts)
opts = opts or {}
local y=-4
if opts.profileHeader then
local _, h = textBlock(content,6,y,"GameFontNormal","|cffffd100"..(opts.title or "统计口径").."|r",TEXT_W)
y = y - h - 8
_, h = textBlock(content,12,y,"GameFontDisableSmall","页面内容对应当前统计口径:计入目标参与统计;排除目标不参与统计;机制规则只读展示。",TEXT_W)
y = y - h - 6
for _, rule in ipairs(W.commonDamageRules or {}) do
_, h = textBlock(content,18,y,"GameFontHighlightSmall","|cff44ff44✓|r  "..rule,TEXT_W-12)
y = y - h - 4
end
y = y - 6
end
for _, boss in ipairs(order) do
local base=W.byName[boss]
local head=content:CreateFontString(nil,"OVERLAY","GameFontNormal"); head:SetPoint("TOPLEFT",6,y); head:SetWidth(148); head:SetJustifyH("LEFT"); head:SetText("|cffffd100"..boss.."|r")
if base and base.excluded then
local ex=content:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); ex:SetPoint("LEFT",head,"RIGHT",8,0); ex:SetText("(整个排除统计)")
y=y-22
else
local ot=mkCheck(content); ot:SetPoint("TOPLEFT",158,y+2); ot.lbl:SetText("包含同场小怪"); ot:SetLabelWidth(132); ot.boss=boss
ot:SetScript("OnClick",function(self)
if not canEdit() then S:Refresh(); return end
local checked = self:GetChecked() and true or false
local c = bcfg(self.boss)
S.SetOverride(c, "otherTrash", checked, defaultOtherTrash(self.boss))
scopeChanged(self.boss,self.boss.."：同场小怪已"..(checked and "计入" or "排除").."统计")
end)
bossRows[#bossRows+1]={type="ot",boss=boss,cb=ot}
local summary=mkCheck(content); summary:SetPoint("TOPLEFT",318,y+2); summary.lbl:SetText("默认不计入汇总"); summary:SetLabelWidth(174); summary.boss=boss
summary:SetScript("OnClick",function(self)
if not canEdit() then S:Refresh(); return end
local checked = self:GetChecked() and true or false
local c = bcfg(self.boss)
S.SetOverride(c, "excludeFromSummary", checked, defaultSummaryExcluded(self.boss))
summaryDefaultChanged(self.boss,self.boss.."：战斗记录默认"..(checked and "不计入" or "计入").."所有战斗汇总")
end)
summary:SetScript("OnEnter",function(self)
if not GameTooltip then return end
GameTooltip:SetOwner(self,"ANCHOR_TOP")
GameTooltip:AddLine("默认不计入所有战斗汇总")
GameTooltip:AddLine("勾选后，此 Boss 新生成的战斗 Tab 默认不参与“所有战斗汇总”；单场记录和详情仍完整保留，也可在 Tab 上手动勾回。",0.8,0.8,0.8,true)
GameTooltip:Show()
end)
summary:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
bossRows[#bossRows+1]={type="summary",boss=boss,cb=summary}
y=y-24
if base and base.big then
local _, h = textBlock(content,18,y,"GameFontDisableSmall","计入目标(可取消勾选):",TEXT_W-18)
y = y - h - 2
for _,npc in ipairs(base.big) do
local cb=mkCheck(content); cb:SetPoint("TOPLEFT",24,y+2)
cb.lbl:SetText(npcLabel(npc)); cb.boss=boss; cb.npc=npc
cb:SetScript("OnClick",function(self)
if not canEdit() then S:Refresh(); return end
local wantExcluded = not self:GetChecked()
local e = bcfg(self.boss).exclude
S.SetOverride(e, self.npc, wantExcluded, defaultExcluded(self.boss))
scopeChanged(self.boss,self.boss.."：目标「"..npcLabel(self.npc).."」已"
..(wantExcluded and "排除" or "计入").."统计")
end)
bossRows[#bossRows+1]={type="big",boss=boss,npc=npc,cb=cb}
y=y-20
end
end
local nb = nonBossText(base)
if hasNonBossIds(base) then
local _, h = textBlock(content,18,y-2,"GameFontDisableSmall","默认排除(勾选计入):",TEXT_W-18)
y = y - h - 2
for i,npc in ipairs(base.nonBoss) do
local col = (i - 1) % 2
local row = math.floor((i - 1) / 2)
local cb=mkCheck(content); cb:SetPoint("TOPLEFT",24 + col * 238,y + 2 - row * 20)
cb.lbl:SetText(npcLabel(npc)); cb:SetLabelWidth(204); cb.boss=boss; cb.npc=npc
cb:SetScript("OnClick",function(self)
if not canEdit() then S:Refresh(); return end
local e = bcfg(self.boss).exclude
local included = self:GetChecked() and true or false
local defaultIncluded = not defaultNpcExcluded(self.boss, self.npc)
if included == defaultIncluded then e[self.npc] = nil
elseif included then e[self.npc] = false
else e[self.npc] = true end
scopeChanged(self.boss,self.boss.."：目标「"..npcLabel(self.npc).."」已"
..(included and "计入" or "排除").."统计")
end)
bossRows[#bossRows+1]={type="nonboss",boss=boss,npc=npc,cb=cb}
end
y = y - (math.ceil(#base.nonBoss / 2) * 20) - 6
end
if base and base.nonBossText then
local more = type(base.nonBossText) == "table" and table.concat(base.nonBossText, "、") or tostring(base.nonBossText)
local _, h = textBlock(content,18,y-2,"GameFontDisableSmall","其他默认排除: |cff888888"..more.."|r",TEXT_W-18)
y = y - h - 8
elseif nb ~= "" and not hasNonBossIds(base) then
local _, h = textBlock(content,18,y-2,"GameFontDisableSmall","默认排除: |cff888888"..nb.."|r",TEXT_W-18)
y = y - h - 8
end
local rules = displayRules(base and base.rules)
if #rules > 0 then
local _, h = textBlock(content,18,y,"GameFontDisableSmall","机制/计算规则:",TEXT_W-18)
y = y - h - 2
for _, rule in ipairs(rules) do
_, h = textBlock(content,28,y,"GameFontHighlightSmall","|cff99ccff•|r  "..rule,TEXT_W-28)
y = y - h - 4
end
end
y=y-10
end
end
content:SetHeight(-y+10)
end
local function Create()
local f=CreateFrame("Frame","NoWCLStatsCfgFrame",UIParent)
f:SetSize(FRAME_W,FRAME_H); f:SetPoint("CENTER"); NoWCL.Util.SetPanelLayer(f,true); NoWCL.Util.MakeMovable(f)
local bg=f:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.06,0.06,0.08,0.97)
local tb=f:CreateTexture(nil,"ARTWORK"); tb:SetPoint("TOPLEFT");tb:SetPoint("TOPRIGHT");tb:SetHeight(26);tb:SetColorTexture(0.12,0.12,0.16,1)
f.title=f:CreateFontString(nil,"OVERLAY","GameFontNormal"); f.title:SetPoint("LEFT",tb,"LEFT",10,0); f.title:SetText("统计口径")
local close=CreateFrame("Button",nil,f,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",-2,-2)
f.sub=f:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); f.sub:SetPoint("TOPLEFT",12,-30)
local TABS={ {k="p1",t="P1熔火",w=58}, {k="p2",t="P2毒蛇风暴",w=84}, {k="p3",t="P3纳克",w=58}, {k="p4",t="P4 ToC/ZG",w=78} }
f.tabBtns={}
local x=8
for _,it in ipairs(TABS) do
local b=CreateFrame("Button",nil,f,"UIPanelButtonTemplate"); b:SetSize(it.w,22); b:SetPoint("TOPLEFT",x,-46); b:SetText(it.t)
b.key=it.k; b:SetScript("OnClick",function(self) S.tab=self.key; S:Refresh() end)
f.tabBtns[it.k]=b; x=x+it.w+3
end
f.profileLabel=f:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); f.profileLabel:SetPoint("TOPLEFT",12,-77); f.profileLabel:SetText("内置 Profile:")
local function selectProfile(profile)
if not canEdit() then S:Refresh(); return end
profile=W:NormalizeProfile(profile)
NoWCL.db.settings.bossProfile=profile
wipe(NoWCL.db.settings.bossCfg)
NoWCL.db.settings.bossCfg.__profile=profile
if NoWCL.Sync and NoWCL.Sync.OnBossScopeChanged then NoWCL.Sync:OnBossScopeChanged() end
announceLeaderSetting("统计目标模板改为「"..W:ProfileName(profile).."」")
S:Refresh()
end
f.profileWcl45=mkCheck(f); f.profileWcl45:SetPoint("TOPLEFT",110,-73); f.profileWcl45.lbl:SetText(W.profileNames[W.PROFILE_WCL45]); f.profileWcl45:SetLabelWidth(360)
f.profileWcl45:SetScript("OnClick",function() selectProfile(W.PROFILE_WCL45) end)
f.profileDamage=mkCheck(f); f.profileDamage:SetPoint("TOPLEFT",110,-95); f.profileDamage.lbl:SetText(W.profileNames[W.PROFILE_DAMAGE]); f.profileDamage:SetLabelWidth(360)
f.profileDamage:SetScript("OnClick",function() selectProfile(W.PROFILE_DAMAGE) end)
f.reset=CreateFrame("Button",nil,f,"UIPanelButtonTemplate"); f.reset:SetSize(110,20); f.reset:SetPoint("TOPRIGHT",-12,-132); f.reset:SetText("恢复当前模板")
f.reset:SetScript("OnClick",function()
if not canEdit() then S:Refresh(); return end
local profile=activeBossProfile()
NoWCL.db.settings.bossProfile=profile; wipe(NoWCL.db.settings.bossCfg); NoWCL.db.settings.bossCfg.__profile=profile
if NoWCL.Sync and NoWCL.Sync.OnBossScopeChanged then NoWCL.Sync:OnBossScopeChanged() end
announceLeaderSetting("统计目标已恢复模板「"..W:ProfileName(profile).."」")
S:Refresh()
end)
local sf=CreateFrame("ScrollFrame","NoWCLStatsCfgScroll",f,"UIPanelScrollFrameTemplate"); sf:SetPoint("TOPLEFT",8,-156); sf:SetPoint("BOTTOMRIGHT",-28,10); f.bossScroll=sf
f.phaseContent={}
for tab, order in pairs({ p1=W.orderP1, p2=W.orderP2, p3=W.orderP3, p4=W.orderP4 }) do
local pc=CreateFrame("Frame",nil,sf); pc:SetSize(CONTENT_W,100); buildBossRows(pc, order); f.phaseContent[tab]=pc
end
sf:SetScrollChild(f.phaseContent.p4)
for t,pc in pairs(f.phaseContent) do pc:SetShown(t=="p4") end
f:HookScript("OnHide", function() if f.phaseContent then for _,pc in pairs(f.phaseContent) do pc:Hide() end end end)
tinsert(UISpecialFrames,"NoWCLStatsCfgFrame"); f:Hide(); frame=f
if NoWCL.UIStyle and NoWCL.UIStyle.RegisterRoot then NoWCL.UIStyle:RegisterRoot(f) end
return f
end
function S:Refresh()
if not frame or not frame:IsShown() then return end
local custom = S.IsCustom()
local editHint = canEdit() and "" or "   |cffffaa00团长口径，只读|r"
local profile=activeBossProfile()
frame.sub:SetText("档案: "..W:ProfileName(profile)..(custom and " |cffffd100(已自定义)|r" or "").."   ("..NoWCL.Profiles:ActiveName()..")"..editHint)
frame.profileWcl45:SetChecked(profile==W.PROFILE_WCL45)
frame.profileDamage:SetChecked(profile==W.PROFILE_DAMAGE)
if canEdit() then frame.profileWcl45:Enable(); frame.profileDamage:Enable()
else frame.profileWcl45:Disable(); frame.profileDamage:Disable() end
for k,b in pairs(frame.tabBtns) do if S.tab==k then b:LockHighlight() else b:UnlockHighlight() end end
local isPhase = (S.tab=="p1" or S.tab=="p2" or S.tab=="p3" or S.tab=="p4")
frame.bossScroll:SetShown(isPhase); frame.reset:SetShown(isPhase)
if canEdit() then frame.reset:Enable() else frame.reset:Disable() end
for t,pc in pairs(frame.phaseContent) do pc:SetShown(isPhase and t==S.tab) end
if isPhase then
frame.bossScroll:SetScrollChild(frame.phaseContent[S.tab])
for _,r in ipairs(bossRows) do
if canEdit() then r.cb:Enable() else r.cb:Disable() end
if r.type=="ot" then r.cb:SetChecked(effectiveOtherTrash(r.boss))
elseif r.type=="summary" then r.cb:SetChecked(effectiveSummaryExcluded(r.boss))
elseif r.type=="big" then r.cb:SetChecked(not effectiveExcluded(r.boss, r.npc))
elseif r.type=="nonboss" then r.cb:SetChecked(effectiveNonBossIncluded(r.boss, r.npc)) end
end
end
end
function S:Toggle()
if not frame then Create() end
if frame:IsShown() then frame:Hide() else frame:Show(); S:Refresh() end
end
