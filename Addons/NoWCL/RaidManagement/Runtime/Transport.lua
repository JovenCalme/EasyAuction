local _, NoWCL = ...
local RM = NoWCL.RaidManagement
local T = {
handlers = {},
registered = {},
priority = "NORMAL",
}
RM.Transport = T
RM.modules[#RM.modules + 1] = T
local function multipartCount(length)
length = math.max(0, tonumber(length) or 0)
if length <= 255 then return 1 end
return math.ceil(length / 254)
end
function T:Ensure()
if self.ready and type(self.SendCommMessage) == "function" then return true end
local aceComm = LibStub and LibStub("AceComm-3.0", true)
if not aceComm then return false, "AceComm-3.0 unavailable" end
aceComm:Embed(self)
if type(self.SendCommMessage) ~= "function" or type(self.RegisterComm) ~= "function" then
return false, "AceComm-3.0 embed failed"
end
self.ready = true
return true
end
function T:Register(prefix, handler)
if type(prefix) ~= "string" or prefix == "" or #prefix > 16 or type(handler) ~= "function" then
return false, "invalid registration"
end
local ready, reason = self:Ensure()
if not ready then return false, reason end
self.handlers[prefix] = handler
if self.registered[prefix] then return true end
local ok, err = pcall(self.RegisterComm, self, prefix, "OnCommReceived")
if not ok then return false, tostring(err) end
self.registered[prefix] = true
return true
end
function T:OnCommReceived(prefix, message, distribution, sender)
local handler = self.handlers[prefix]
if not handler then return end
local ok, err = pcall(handler, prefix, message, distribution, sender)
if not ok and RM.Print then RM:Print("同步消息处理失败: " .. tostring(err)) end
end
function T:Send(prefix, message, distribution, target, onComplete, priority)
if type(prefix) ~= "string" or type(message) ~= "string" or message:find("\000", 1, true)
or type(distribution) ~= "string" then
return false, "invalid message"
end
priority = priority or self.priority
if priority ~= "BULK" and priority ~= "NORMAL" and priority ~= "ALERT" then
return false, "invalid priority"
end
local ready, reason = self:Ensure()
if not ready then return false, reason end
local expectedParts = multipartCount(#message)
local state = { callbacks=0, expected=expectedParts, done=false, failed=false }
local function progress(current, sent, total, sendResult)
if current.done then return end
local finished
if type(sent) == "number" then
if sendResult == false then current.failed = true end
finished = sent >= (tonumber(total) or #message)
else
current.callbacks = current.callbacks + 1
if sent == false then current.failed = true end
finished = current.callbacks >= current.expected
end
if finished then
current.done = true
if onComplete then onComplete(not current.failed, sendResult) end
end
end
local callback = onComplete and progress or nil
local callbackArg = onComplete and state or nil
local ok, err = pcall(self.SendCommMessage, self, prefix, message, distribution, target,
priority, callback, callbackArg)
if not ok then return false, tostring(err) end
return true, expectedParts
end
function T:OnLogin()
self:Ensure()
end
T.MultipartCount = multipartCount
