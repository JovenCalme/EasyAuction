local addonName, NoWCL = ...
local C = {}
NoWCL.Comm = C
C.PROTO = 3
local PREFIX = "NoWCL"
local SEP = "\001"
local MAXCHUNK = 220
local PUMP_INTERVAL = 0.25
local BURST_TOKENS = 10
local TOKEN_PER_SEC = 1
C.handlers = {}
local sendQueue = {}
local recvBuf = {}
local msgCounter = 0
local tokens, lastRefill = BURST_TOKENS, nil
local ctlPending = 0
local PRIORITY = {
REQTAB="ALERT", TABACK="ALERT", TABSUM="ALERT", MANIFEST="ALERT", REQ="ALERT", RESET="ALERT", STAT="ALERT",
SNAPP="NORMAL",
CFG="NORMAL", TOAST="NORMAL", HELLO="BULK",
}
local PRIORITY_RANK = { ALERT=1, NORMAL=2, BULK=3 }
local function rawSend(text, channel, target)
if C_ChatInfo and C_ChatInfo.SendAddonMessage then
return C_ChatInfo.SendAddonMessage(PREFIX, text, channel, target)
elseif SendAddonMessage then
return SendAddonMessage(PREFIX, text, channel, target)
end
end
local function isThrottledResult(ok)
if ok == false then return true end
if Enum and Enum.SendAddonMessageResult and ok == Enum.SendAddonMessageResult.AddonMessageThrottle then return true end
local s = tostring(ok or "")
return s:find("Throttle") or s:find("THROTTLE")
end
local function refillTokens()
local now = GetTime and GetTime() or time()
if not lastRefill then lastRefill = now; return end
local dt = math.max(0, now - lastRefill)
if dt <= 0 then return end
tokens = math.min(BURST_TOKENS, tokens + dt * TOKEN_PER_SEC)
lastRefill = now
end
function C:Register(msgtype, fn)
self.handlers[msgtype] = fn
end
function C:Pending()
return #sendQueue + ctlPending
end
function C:Status()
refillTokens()
return { pending=#sendQueue + ctlPending, tokens=math.floor(tokens), ctl=(ChatThrottleLib and true or false) }
end
function C:UsingChatThrottleLib()
return ChatThrottleLib and ChatThrottleLib.SendAddonMessage and true or false
end
function C:Send(msgtype, payload, channel, target, prio)
channel = channel or NoWCL.Util.GroupChannel()
if not channel then return end
payload = tostring(payload or "")
msgCounter = msgCounter + 1
local id = msgCounter
local total = math.max(1, math.ceil(#payload / MAXCHUNK))
prio = prio or PRIORITY[msgtype] or "NORMAL"
for seq = 1, total do
local chunk = payload:sub((seq-1)*MAXCHUNK + 1, seq*MAXCHUNK)
local wire = table.concat({ msgtype, id, seq, total, chunk }, SEP)
if ChatThrottleLib and ChatThrottleLib.SendAddonMessage then
ctlPending = ctlPending + 1
ChatThrottleLib:SendAddonMessage(prio, PREFIX, wire, channel, target, PREFIX, function()
ctlPending = math.max(0, ctlPending - 1)
end)
else
sendQueue[#sendQueue+1] = { wire=wire, channel=channel, target=target, prio=prio }
end
end
end
local function popNextSend()
if #sendQueue == 0 then return nil end
local best, bestRank = 1, PRIORITY_RANK[sendQueue[1].prio] or PRIORITY_RANK.NORMAL
for i = 2, #sendQueue do
local rank = PRIORITY_RANK[sendQueue[i].prio] or PRIORITY_RANK.NORMAL
if rank < bestRank then best, bestRank = i, rank end
end
return table.remove(sendQueue, best)
end
local function pump()
refillTokens()
if tokens < 1 then return end
local item = popNextSend()
if item then
tokens = tokens - 1
local ok = rawSend(item.wire, item.channel, item.target)
if isThrottledResult(ok) then
table.insert(sendQueue, 1, item)
tokens = 0
end
end
end
local function onReceive(prefix, text, channel, sender)
if prefix ~= PREFIX or not text then return end
local shortSender = sender and sender:match("^[^-]+") or sender
local msgtype, id, seq, total, chunk = strsplit(SEP, text, 5)
if not msgtype or not id then return end
seq, total = tonumber(seq), tonumber(total)
if not seq or not total then return end
if total == 1 then
local fn = C.handlers[msgtype]
if fn then fn(shortSender, chunk or "") end
return
end
local key = table.concat({ shortSender, msgtype, id }, SEP)
local buf = recvBuf[key]
if not buf then buf = { total=total, parts={}, count=0 }; recvBuf[key] = buf end
if not buf.parts[seq] then buf.parts[seq] = chunk or ""; buf.count = buf.count + 1 end
if buf.count >= buf.total then
recvBuf[key] = nil
local fn = C.handlers[msgtype]
if fn then fn(shortSender, table.concat(buf.parts)) end
end
end
function C:Init()
if self._inited then return end
self._inited = true
if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
elseif RegisterAddonMessagePrefix then
RegisterAddonMessagePrefix(PREFIX)
end
local f = CreateFrame("Frame")
f:RegisterEvent("CHAT_MSG_ADDON")
f:SetScript("OnEvent", function(_, _, p, t, ch, s) onReceive(p, t, ch, s) end)
if C_Timer and C_Timer.NewTicker then
C_Timer.NewTicker(PUMP_INTERVAL, pump)
else
local acc = 0
f:SetScript("OnUpdate", function(_, dt)
acc = acc + dt
if acc >= PUMP_INTERVAL then acc = 0; pump() end
end)
end
end
