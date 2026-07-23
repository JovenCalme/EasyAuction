local addonName, NoWCL = ...
local T = {}
NoWCL.Toast = T
local U = NoWCL.Util
local DURATION = 5
local queue, active, toastFrame = {}, nil, nil
local showNext
local function getFrame()
if toastFrame then return toastFrame end
local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
f:SetFrameStrata("FULLSCREEN_DIALOG")
f:SetSize(320, 50); f:SetPoint("TOP", UIParent, "TOP", 0, -200)
f:EnableMouse(false)
f:SetBackdrop({
bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
edgeSize = 14, insets = { left=4, right=4, top=4, bottom=4 },
})
f:SetBackdropColor(0, 0, 0, 0.78)
f:SetBackdropBorderColor(0.75, 0.75, 0.8, 0.95)
f.tag=f:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); f.tag:SetPoint("TOPRIGHT",-8,-5); f.tag:SetText("NoWCL团长通告")
f.txt=f:CreateFontString(nil,"OVERLAY","GameFontHighlightLarge"); f.txt:SetPoint("CENTER",0,-3); f.txt:SetJustifyH("CENTER")
f.action=CreateFrame("Button",nil,f,"UIPanelButtonTemplate"); f.action:SetSize(104,22); f.action:SetPoint("BOTTOM",0,10); f.action:Hide()
f.countdown=f:CreateFontString(nil,"OVERLAY","GameFontDisableSmall"); f.countdown:SetPoint("LEFT",f.action,"RIGHT",10,0); f.countdown:Hide()
f.bar=f:CreateTexture(nil,"ARTWORK"); f.bar:SetPoint("BOTTOMLEFT",5,5); f.bar:SetHeight(3); f.bar:SetColorTexture(0.7,0.7,0.75,0.55)
f.action:SetScript("OnClick",function()
local item=f._item
if item and item.token then T:CancelAction(item.token,true) end
end)
f:Hide()
if NoWCL.UIStyle and NoWCL.UIStyle.RegisterRoot then NoWCL.UIStyle:RegisterRoot(f) end
toastFrame=f; return f
end
local function closeActive(reason)
local f = active
if not f then return end
local item = f._item
f:SetScript("OnUpdate",nil)
f._item=nil
f.action:Hide(); f.countdown:Hide(); f:EnableMouse(false); f:Hide()
active=nil
local callback
if reason=="cancel" then callback=item and item.onCancel
elseif reason=="expire" then callback=item and item.onExpire end
if callback then pcall(callback) end
showNext()
end
showNext = function()
if active then return end
local item = table.remove(queue, 1)
if not item then return end
local f = getFrame()
f._item=item
f.txt:SetText(item.text)
f:SetWidth(math.max(300, (f.txt:GetStringWidth() or 200) + 56))
f.txt:ClearAllPoints()
if item.token then
f:SetHeight(82)
f.txt:SetPoint("TOP",0,-20)
f.action:SetText(item.buttonText or "取消")
f.action:Show(); f.countdown:Show(); f:EnableMouse(true)
else
f:SetHeight(50)
f.txt:SetPoint("CENTER",0,-3)
f.action:Hide(); f.countdown:Hide(); f:EnableMouse(false)
end
f.bar:SetWidth(f:GetWidth()-10)
f._t, f._dur = 0, item.dur or DURATION
f:SetAlpha(0); f:Show(); active = f
f:SetScript("OnUpdate", function(self, dt)
self._t = self._t + dt
local t, dur = self._t, self._dur
if item.token then self.countdown:SetText(math.max(0,math.ceil(dur-t)).."秒") end
if t < 0.2 then self:SetAlpha(t/0.2)
elseif t > dur-0.4 then
local a = (dur-t)/0.4
if a <= 0 then closeActive("expire"); return end
self:SetAlpha(a)
else self:SetAlpha(1) end
self.bar:SetWidth((self:GetWidth()-10) * math.max(0, 1 - t/dur))
end)
end
function T:Show(text, dur)
if not text or text == "" then return end
queue[#queue+1] = { text = text, dur = dur }
showNext()
end
function T:ShowAction(text,dur,buttonText,onCancel,onExpire)
if not text or text=="" then return nil end
self._actionSerial=(self._actionSerial or 0)+1
local token="NOWCL_TOAST_ACTION_"..self._actionSerial
queue[#queue+1]={ text=text,dur=dur,buttonText=buttonText,token=token,
onCancel=onCancel,onExpire=onExpire }
showNext()
return token
end
function T:CancelAction(token,invokeCallback)
if not token then return false end
if active and active._item and active._item.token==token then
closeActive(invokeCallback and "cancel" or "dismiss")
return true
end
for index,item in ipairs(queue) do
if item.token==token then
table.remove(queue,index)
if invokeCallback and item.onCancel then pcall(item.onCancel) end
return true
end
end
return false
end
function T:Broadcast(text)
self:Show(text)
if not (IsInGroup() and U.GroupChannel()) then return end
if not UnitIsGroupLeader("player") then return end
local chan = U.GroupChannel()
NoWCL.Comm:Send("TOAST", text)
self:PublishLeaderText(text,"toast",chan)
end
function T:PublishLeaderText(text,source,channel)
if not (IsInGroup and IsInGroup()) then return false end
if not (UnitIsGroupLeader and UnitIsGroupLeader("player")) then return false end
local chan=channel or (U.GroupChannel and U.GroupChannel())
if not chan then return false end
local plain = (text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
local publisher = NoWCL.GroupPublisher
if publisher and publisher.Publish then
publisher:Publish({ plain }, { source=source or "toast", channel=chan, append=true, bypassRankingGap=true })
return true
end
return false
end
function T:BroadcastLeaderSetting(text)
if not (IsInGroup and IsInGroup()) then return false end
if not (UnitIsGroupLeader and UnitIsGroupLeader("player")) then return false end
self:Broadcast("|cffffd100团长设置：|r" .. tostring(text or ""))
return true
end
function T:PublishLeaderSettingText(text)
return self:PublishLeaderText("|cffffd100团长设置：|r"..tostring(text or ""),"leader-setting")
end
function T:Init()
if self._inited then return end
self._inited = true
NoWCL.Comm:Register("TOAST", function(sender, payload)
if sender == UnitName("player") then return end
if not U.IsRaidLeader(sender) then return end
self:Show(payload)
end)
end
