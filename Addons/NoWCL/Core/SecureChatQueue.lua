local addonName, NoWCL = ...
local Q = {}
NoWCL.SecureChatQueue = Q
local TEST_RELAY_NAME = "NoWCLSecureChatQueueTestRelay"
local ACTION_RELAY_NAME = "NoWCLSecureChatActionRelay"
local ACTION_BINDING_SPECS = {
{ frame="ActionButton", binding="ACTIONBUTTON", limit=12 },
{ frame="MultiBarBottomLeftButton", binding="MULTIACTIONBAR1BUTTON", limit=12 },
{ frame="MultiBarBottomRightButton", binding="MULTIACTIONBAR2BUTTON", limit=12 },
{ frame="MultiBarRightButton", binding="MULTIACTIONBAR3BUTTON", limit=12 },
{ frame="MultiBarLeftButton", binding="MULTIACTIONBAR4BUTTON", limit=12 },
{ frame="MultiBar5Button", binding="MULTIACTIONBAR5BUTTON", limit=12 },
{ frame="MultiBar6Button", binding="MULTIACTIONBAR6BUTTON", limit=12 },
{ frame="MultiBar7Button", binding="MULTIACTIONBAR7BUTTON", limit=12 },
{ frame="PetActionButton", binding="PETACTIONBUTTON", limit=10 },
{ frame="StanceButton", binding="SHAPESHIFTBUTTON", limit=10 },
}
local function inCombat()
return InCombatLockdown and InCombatLockdown() or false
end
function Q:IsEnabled()
return NoWCL.db and NoWCL.db.settings and NoWCL.db.settings.pullAnnounce ~= false
end
local function ensureHandler(self)
if self._handler then return self._handler end
if not (CreateFrame and SecureHandlerWrapScript) or inCombat() then return nil end
local handler = CreateFrame("Frame", "NoWCLSecureChatQueueHandler", UIParent,
"SecureHandlerBaseTemplate")
if SecureHandler_OnLoad then SecureHandler_OnLoad(handler) end
if handler.Execute then handler:Execute("Core = self") end
handler.FlushPending = function()
return Q:FlushFromHardware()
end
handler.FlushBeforeAction = function()
return Q:FlushBeforeAction()
end
handler.FlushAfterAction = function()
return Q:FlushAfterAction()
end
handler.BindingCleared = function()
return Q:OnSecureBindingCleared()
end
self._handler = handler
return handler
end
local function wrapButton(self, handler, button)
if not button or self._wrapped[button] then return false end
local ok = pcall(SecureHandlerWrapScript, button, "OnClick", handler, [[
local sent = Core:CallMethod("FlushBeforeAction")
if sent then
Core:ClearBindings()
Core:CallMethod("BindingCleared")
end
]], [[
local sent = Core:CallMethod("FlushAfterAction")
if sent then
Core:ClearBindings()
Core:CallMethod("BindingCleared")
end
]])
if not ok then return false end
self._wrapped[button] = true
self._wrappedCount = self._wrappedCount + 1
return true
end
function Q:WrappedCount()
return self._wrappedCount or 0
end
local function normalizeKey(key)
return type(key) == "string" and key:upper() or nil
end
local function bindingHasKey(command, wanted)
if not GetBindingKey then return nil end
local keys = { GetBindingKey(command) }
for _, key in ipairs(keys) do
if normalizeKey(key) == wanted then return key end
end
return nil
end
function Q:FindActionForKey(key)
key = normalizeKey(key)
if not key then return nil end
for _, spec in ipairs(ACTION_BINDING_SPECS) do
for index = 1, spec.limit do
local command = spec.binding .. index
local actualKey = bindingHasKey(command, key)
local buttonName = spec.frame .. index
local button = _G[buttonName]
if actualKey and button then return actualKey, button, buttonName, command end
end
end
for index = 1, 180 do
local button = _G["DominosActionButton" .. index]
local buttonName = button and button.GetName and button:GetName()
if buttonName then
local command = "CLICK " .. buttonName .. ":LeftButton"
local actualKey = bindingHasKey(command, key)
if actualKey then return actualKey, button, buttonName, command end
end
end
return nil
end
function Q:FindFirstAction()
if not GetBindingKey then return nil end
for _, spec in ipairs(ACTION_BINDING_SPECS) do
for index = 1, spec.limit do
local command = spec.binding .. index
local key = GetBindingKey(command)
local buttonName = spec.frame .. index
local button = _G[buttonName]
if type(key) == "string" and key ~= "" and button then
return key, button, buttonName, command
end
end
end
return nil
end
function Q:InstallActionRelay()
if inCombat() then
self._installDeferred = true
return false, "combat-lockdown"
end
if not (CreateFrame and SetOverrideBindingClick) then
return false, "secure-binding-api-unavailable"
end
local handler = ensureHandler(self)
if not handler then return false, "secure-handler-unavailable" end
if ClearOverrideBindings then ClearOverrideBindings(handler) end
local key, button, buttonName, command = self:FindActionForKey("Z")
if not key or not button then
self._triggerKey, self._triggerButtonName, self._triggerCommand = nil, nil, nil
return false, "z-key-not-action"
end
local relay = self._actionRelay or _G[ACTION_RELAY_NAME]
if not relay then
relay = CreateFrame("Button", ACTION_RELAY_NAME, UIParent, "SecureActionButtonTemplate")
end
if not relay then return false, "secure-relay-unavailable" end
if relay.RegisterForClicks then relay:RegisterForClicks("AnyUp") end
relay:SetAttribute("type", "click")
relay:SetAttribute("clickbutton", button)
if not self._wrapped[relay] and not wrapButton(self, handler, relay) then
return false, "secure-relay-wrap-failed"
end
SetOverrideBindingClick(handler, true, key, ACTION_RELAY_NAME, "LeftButton")
self._actionRelay = relay
self._triggerKey = key
self._triggerButtonName = buttonName
self._triggerCommand = command
self._installDeferred = false
if GetBindingAction then
local ok, active = pcall(GetBindingAction, key, true)
self._activeBinding = ok and active or ""
end
local debug = NoWCL.db and NoWCL.db.pullAnnounceDebug
if debug then
debug.activeBinding = self._activeBinding or ""
debug.relayInstalledAt = GetTime and GetTime() or 0
end
return true, key
end
function Q:TriggerKey()
return self._triggerKey
end
function Q:TriggerDescription()
if not self._triggerKey then return "" end
return self._triggerKey .. "=" .. tostring(self._triggerButtonName or self._triggerCommand or "?")
end
function Q:BindingClearRequested()
return self._clearRequested and true or false
end
function Q:ActiveBinding()
return self._activeBinding or ""
end
function Q:OnSecureBindingCleared()
if not self._clearRequested then return false end
self._bindingCleared = true
self._triggerKey, self._triggerButtonName, self._triggerCommand = nil, nil, nil
return true
end
function Q:Disable()
self._pending = nil
if inCombat() then return true end
if self._handler and ClearOverrideBindings then
ClearOverrideBindings(self._handler)
end
self._clearRequested = false
self._bindingCleared = true
self._triggerKey, self._triggerButtonName, self._triggerCommand = nil, nil, nil
return true
end
function Q:ApplyEnabled()
if not self:IsEnabled() then return self:Disable() end
return self:InstallActionRelay()
end
function Q:InstallTestRelay(key, originalButton)
if inCombat() then return false, "combat-lockdown" end
if type(key) ~= "string" or key == "" then return false, "invalid-key" end
if not originalButton then return false, "invalid-original-button" end
if not (CreateFrame and SetOverrideBindingClick) then
return false, "secure-binding-api-unavailable"
end
local handler = ensureHandler(self)
if not handler then return false, "secure-handler-unavailable" end
local relay = self._testRelay or _G[TEST_RELAY_NAME]
if not relay then
relay = CreateFrame("Button", TEST_RELAY_NAME, UIParent, "SecureActionButtonTemplate")
end
if not relay then return false, "secure-relay-unavailable" end
if relay.RegisterForClicks then relay:RegisterForClicks("AnyUp") end
relay:SetAttribute("type", "click")
relay:SetAttribute("clickbutton", originalButton)
if not self._wrapped[relay] and not wrapButton(self, handler, relay) then
return false, "secure-relay-wrap-failed"
end
SetOverrideBindingClick(handler, true, key, TEST_RELAY_NAME, "LeftButton")
self._testRelay = relay
self._testRelayKey = key
self._testOriginalButton = originalButton
return true, TEST_RELAY_NAME
end
function Q:TestRelayState()
return self._testRelayKey, self._testRelay, self._testOriginalButton
end
function Q:Enqueue(message, chatType, language, target, callback)
if type(message) ~= "string" or message == "" then return false end
if not self._triggerKey and not self._testRelayKey then self:ApplyEnabled() end
if not self._triggerKey and not self._testRelayKey then return false end
self._pending = {
message=message, chatType=chatType, language=language, target=target,
callback=callback, attempted=false,
}
return true
end
function Q:EnqueueHardwareProbe(callback)
if not self._triggerKey and not self._testRelayKey then self:ApplyEnabled() end
if not self._triggerKey and not self._testRelayKey then return false end
self._pending = { probe=true, callback=callback, attempted=false }
return true
end
function Q:FlushFromHardware()
local pending = self._pending
if not pending or pending.attempted then return false end
pending.attempted = true
if pending.probe then
self._pending = nil
if type(pending.callback) == "function" then
pcall(pending.callback, true, "hardware-probe")
end
return true
end
local chat = NoWCL.SafeChat
local ok, result
if chat and type(chat.SendCChat) == "function" then
ok, result = chat:SendCChat(pending.message, pending.chatType, pending.language, pending.target)
elseif chat and type(chat.Send) == "function" then
ok, result = chat:Send(pending.message, pending.chatType, pending.language, pending.target)
else
ok, result = false, "chat-api-unavailable"
end
if type(pending.callback) == "function" then
pcall(pending.callback, ok and true or false, result)
end
if ok then
self._clearRequested = true
self._bindingCleared = false
end
if not ok then self._pending = nil end
return ok and true or false
end
function Q:FlushBeforeAction()
if self._pending then return self:FlushFromHardware() end
local notice = NoWCL.PullNotice
if notice and type(notice.OnHardwareTargetAction) == "function" then
return notice:OnHardwareTargetAction()
end
return false
end
function Q:FlushAfterAction()
if self._pending then return self:FlushFromHardware() end
local notice = NoWCL.PullNotice
if notice and type(notice.OnHardwareTargetAction) == "function" then
return notice:OnHardwareTargetAction()
end
return false
end
function Q:Confirm(message)
local pending = self._pending
if not pending or pending.message ~= message then return false end
self._pending = nil
return true
end
function Q:Init()
if self._inited then return end
self._inited = true
self._wrapped = {}
self._wrappedCount = 0
self:ApplyEnabled()
if not CreateFrame then return end
local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("UPDATE_BINDINGS")
events:SetScript("OnEvent", function(_, event)
if Q._clearRequested and Q._handler and ClearOverrideBindings and not inCombat() then
ClearOverrideBindings(Q._handler)
Q:OnSecureBindingCleared()
Q._clearRequested = false
end
Q:ApplyEnabled()
if event == "PLAYER_ENTERING_WORLD" and C_Timer and C_Timer.After then
C_Timer.After(2, function()
if not inCombat() then Q:ApplyEnabled() end
end)
end
end)
self._eventFrame = events
end
