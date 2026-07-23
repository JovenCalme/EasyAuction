local addonName, NoWCL = ...
local capturedCChat = C_ChatInfo and C_ChatInfo.SendChatMessage
local capturedLegacyChat = SendChatMessage
local S = {}
NoWCL.SafeChat = S
function S:Source()
if SendChatMessage then return "SendChatMessage" end
if capturedLegacyChat then return "SendChatMessage(captured)" end
if capturedCChat then return "C_ChatInfo.SendChatMessage" end
return nil
end
function S:CChatSource()
if capturedCChat then return "C_ChatInfo.SendChatMessage" end
if capturedLegacyChat then return "SendChatMessage" end
return nil
end
function S:IsAvailable()
return SendChatMessage ~= nil or capturedLegacyChat ~= nil or capturedCChat ~= nil
end
local function productSender()
return SendChatMessage or capturedLegacyChat or capturedCChat
end
local function accepted(result)
if result == false then return false, "chat-api-rejected" end
local successCode = Enum and Enum.SendAddonMessageResult
and Enum.SendAddonMessageResult.Success
if type(result) == "number" and successCode ~= nil and result ~= successCode then
return false, tostring(result)
end
return true, result
end
function S:Send(message, chatType, language, target)
if type(message) ~= "string" or message == "" then
return false, "invalid-message"
end
if type(chatType) ~= "string" or chatType == "" then
return false, "invalid-chat-type"
end
local sender = productSender()
if not sender then return false, "chat-api-unavailable" end
local ok, result = pcall(sender, message, chatType, language, target)
if not ok then return false, tostring(result) end
return accepted(result)
end
function S:SendFromHardwareClick(message, chatType, language, target)
if type(message) ~= "string" or message == "" then
return false, "invalid-message"
end
if type(chatType) ~= "string" or chatType == "" then
return false, "invalid-chat-type"
end
local sender = productSender()
if not sender then return false, "chat-api-unavailable" end
return accepted(sender(message, chatType, language, target))
end
function S:SendCChat(message, chatType, language, target)
if type(message) ~= "string" or message == "" then
return false, "invalid-message"
end
if type(chatType) ~= "string" or chatType == "" then
return false, "invalid-chat-type"
end
local sender = capturedCChat or capturedLegacyChat
if not sender then return false, "chat-api-unavailable" end
local ok, result = pcall(sender, message, chatType, language, target)
if not ok then return false, tostring(result) end
return accepted(result)
end
