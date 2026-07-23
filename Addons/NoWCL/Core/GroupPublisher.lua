local addonName, NoWCL = ...
local P = {}
NoWCL.GroupPublisher = P
local U = NoWCL.Util
local DEFAULT_INTERVAL = 0.4
local POST_RANKING_GAP = 12
local CHAT_TAG = "[NCL]"
function P:PrefixMessage(message)
message = tostring(message or "")
if message:sub(1, #CHAT_TAG) == CHAT_TAG then return message end
return CHAT_TAG .. " " .. message
end
local function clock()
return GetTime and GetTime() or 0
end
local function finishBatch(self)
local batch = self._batch
if self._ticker then self._ticker:Cancel(); self._ticker = nil end
self._queue = nil
self._batch = nil
if batch and batch.onComplete then pcall(batch.onComplete) end
end
function P:IsBusy()
return self._batch ~= nil or self._ticker ~= nil
end
function P:_Flush()
local batch = self._batch
local queue = self._queue
if not batch or not queue then return end
local item = queue[1]
if not item then
finishBatch(self)
return
end
if type(item) == "table" and item.waitAfterPrior and self._lastSendAt
and clock() - self._lastSendAt < POST_RANKING_GAP then
return
end
table.remove(queue, 1)
local message = item.message
local channel = item.channel or batch.channel or U.GroupChannel()
local target = item.target or batch.target
if channel and message then
local args = target and { message, channel, nil, target } or { message, channel }
SendChatMessage(unpack(args))
self._lastSendAt = clock()
self._lastSource = type(item) == "table" and item.publisherSource or batch.source
local onSend = item.publisherOnSend or batch.onSend
if onSend then pcall(onSend, item, message, channel, target) end
end
end
function P:Publish(messages, options)
options = options or {}
local channel = options.channel or U.GroupChannel()
if not channel then return false, "no-group" end
local queue = {}
for _, raw in ipairs(messages or {}) do
local message = type(raw) == "table" and raw.message or raw
if type(message) == "string" and message ~= "" then
local item = { message=message }
if type(raw) == "table" then
for key, value in pairs(raw) do item[key] = value end
end
item.channel = item.channel or options.channel
item.target = item.target or options.target
item.publisherOnSend = item.publisherOnSend or options.onSend
item.publisherSource = item.publisherSource or options.source
item.message = self:PrefixMessage(item.message)
queue[#queue + 1] = item
end
end
if #queue == 0 then return false, "empty" end
local waitAfterRanking = not options.bypassRankingGap
and options.source ~= "ranking" and self._lastSource == "ranking"
and self._lastSendAt and clock() - self._lastSendAt < POST_RANKING_GAP
if self:IsBusy() then
if not options.append or not self._queue then return false, "busy" end
for index, item in ipairs(queue) do
if index == 1 and waitAfterRanking then item.waitAfterPrior = true end
self._queue[#self._queue + 1] = item
end
return true, #queue, channel
end
if waitAfterRanking then queue[1].waitAfterPrior = true end
self._queue = queue
self._batch = {
source=options.source,
channel=options.channel,
target=options.target,
onSend=options.onSend,
onComplete=options.onComplete,
}
if C_Timer and C_Timer.NewTicker then
self._ticker = C_Timer.NewTicker(options.interval or DEFAULT_INTERVAL, function()
P:_Flush()
end)
else
while self._batch do self:_Flush() end
end
return true, #queue, channel
end
