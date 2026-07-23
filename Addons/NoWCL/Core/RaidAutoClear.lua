local addonName, NoWCL = ...
local R = {}
NoWCL.RaidAutoClear = R
local RESET_GRACE = 90
local CLEAR_DELAY = 10
local function now()
if GetServerTime then return GetServerTime() end
return time()
end
local function characterKey()
local guid = UnitGUID and UnitGUID("player")
if guid and guid ~= "" then return guid end
local name, realm = UnitName("player")
return tostring(name or "?") .. "-" .. tostring(realm or GetRealmName and GetRealmName() or "?")
end
local function sameDifficulty(a, b)
a, b = tonumber(a) or 0, tonumber(b) or 0
return a == 0 or b == 0 or a == b
end
local function savedLockout(instanceName, difficultyID)
if not (GetNumSavedInstances and GetSavedInstanceInfo) then return nil, nil end
for i = 1, (GetNumSavedInstances() or 0) do
local name, lockoutID, reset, savedDifficulty, locked, _, mostSig, isRaid = GetSavedInstanceInfo(i)
if isRaid and locked and name == instanceName and sameDifficulty(savedDifficulty, difficultyID) then
local id
if lockoutID and tonumber(lockoutID) and tonumber(lockoutID) ~= 0 then
id = tostring(mostSig or 0) .. ":" .. tostring(lockoutID)
end
local resetAt
if tonumber(reset) and tonumber(reset) > 0 then resetAt = now() + tonumber(reset) end
return id, resetAt
end
end
return nil, nil
end
local function fallbackResetAt()
local remaining
if GetInstanceLockTimeRemaining then remaining = GetInstanceLockTimeRemaining() end
if not (type(remaining) == "number" and remaining > 0) then
if C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset then
remaining = C_DateAndTime.GetSecondsUntilWeeklyReset()
elseif GetSecondsUntilWeeklyReset then
remaining = GetSecondsUntilWeeklyReset()
end
end
if type(remaining) ~= "number" or remaining <= 0 or remaining > 14 * 24 * 60 * 60 then return nil end
return math.floor((now() + remaining) / 60 + 0.5) * 60
end
function R:CurrentIdentity()
if not GetInstanceInfo then return nil end
local name, instanceType, difficultyID, difficultyName, _, _, _, instanceMapID = GetInstanceInfo()
if instanceType ~= "raid" or not name or name == "" then return nil end
local lockoutID, resetAt = savedLockout(name, difficultyID)
resetAt = resetAt or fallbackResetAt()
return {
character = characterKey(),
name = name,
difficultyID = tonumber(difficultyID) or 0,
difficultyName = difficultyName,
instanceMapID = tonumber(instanceMapID),
lockoutID = lockoutID,
resetAt = resetAt,
}
end
function R:IsSameRaidCD(previous, current, at)
if not (previous and current) then return false end
if previous.character ~= current.character or previous.name ~= current.name
or not sameDifficulty(previous.difficultyID, current.difficultyID) then
return false
end
local expired = previous.resetAt and (at or now()) > previous.resetAt + RESET_GRACE
if expired and (not previous.lockoutID or not current.lockoutID
or previous.lockoutID ~= current.lockoutID) then
return false
end
if previous.lockoutID and current.lockoutID then return previous.lockoutID == current.lockoutID end
return true
end
function R:HasPastRecords()
if NoWCL.Sync and next(NoWCL.Sync.tabs or {}) then return true end
return NoWCL.Stats and next(NoWCL.Stats.history or {}) ~= nil or false
end
local function saveState(state)
if NoWCLDB then NoWCLDB.raidAutoClearState = state end
end
local function saveEntryState(state)
if NoWCLDB then NoWCLDB.raidEntryState = state end
end
function R:CancelPendingClear(showConfirmation)
local pending=self._pendingClear
if not pending then return false end
self._pendingClear=nil
if pending.toastToken and NoWCL.Toast and NoWCL.Toast.CancelAction then
NoWCL.Toast:CancelAction(pending.toastToken,false)
end
if showConfirmation and NoWCL.Toast and NoWCL.Toast.Show then
NoWCL.Toast:Show("|cffffd100已取消本次自动清空|r",2)
end
return true
end
function R:ScheduleAutoClear(current)
if not (current and NoWCL.Toast and NoWCL.Toast.ShowAction) then return false end
self:CancelPendingClear(false)
local pending={ identity=current }
self._pendingClear=pending
local function cancel()
if self._pendingClear~=pending then return end
self._pendingClear=nil
if NoWCL.Toast and NoWCL.Toast.Show then
NoWCL.Toast:Show("|cffffd100已取消本次自动清空|r",2)
end
end
local function expire()
if self._pendingClear~=pending then return end
self._pendingClear=nil
local settings=NoWCL.db and NoWCL.db.settings
local stillHere=self:CurrentIdentity()
if not (settings and settings.autoClearNewRaidCD==true
and self:IsSameRaidCD(pending.identity,stillHere) and self:HasPastRecords()
and NoWCL.Sync and NoWCL.Sync.ClearTabs) then return end
NoWCL.Sync:ClearTabs()
if NoWCL.Toast and NoWCL.Toast.Show then
NoWCL.Toast:Show("|cff44ff44进入新团本CD：|r|cffffd100"..pending.identity.name
.."|r\n已自动清空过去的战斗记录",3)
end
end
pending.toastToken=NoWCL.Toast:ShowAction("|cff44ff44进入新团本CD：|r|cffffd100"..current.name
.."|r\n10秒后自动清空过去的战斗记录",CLEAR_DELAY,"下次再说",cancel,expire)
return pending.toastToken~=nil
end
function R:UpdateRaidEntry(current)
local state = NoWCLDB and NoWCLDB.raidEntryState or nil
state = type(state) == "table" and state or {}
if not current then
state.insideRaid = false
state.checkedAt = now()
saveEntryState(state)
return false
end
local same = self:IsSameRaidCD(state.identity, current)
local entered = state.insideRaid ~= true
local changed = state.identity == nil or not same
local activate = entered or changed
state.insideRaid = true
state.identity = current
state.checkedAt = now()
saveEntryState(state)
if activate and NoWCL.AuditUI and NoWCL.AuditUI.ActivateCurrentStatus then
NoWCL.AuditUI:ActivateCurrentStatus()
end
return activate
end
function R:CheckCurrentRaid(baselineOnly)
local current = self:CurrentIdentity()
self:UpdateRaidEntry(current)
local settings = NoWCL.db and NoWCL.db.settings
if not (settings and settings.autoClearNewRaidCD == true) then return false end
local state = NoWCLDB and NoWCLDB.raidAutoClearState or nil
state = type(state) == "table" and state or {}
if not current then
state.insideRaid = false
saveState(state)
return false
end
local same = self:IsSameRaidCD(state.identity, current)
local shouldClear = not baselineOnly and not same
local scheduled = false
if shouldClear and self:HasPastRecords() and NoWCL.Sync and NoWCL.Sync.ClearTabs then
scheduled=self:ScheduleAutoClear(current)
end
state.insideRaid = true
state.identity = current
state.checkedAt = now()
saveState(state)
return scheduled
end
function R:SetEnabled(enabled)
if not (NoWCL.db and NoWCL.db.settings) then return end
NoWCL.db.settings.autoClearNewRaidCD = enabled and true or false
if not enabled then
self:CancelPendingClear(false)
self._checkRevision = (self._checkRevision or 0) + 1
saveState(nil)
return
end
saveState(nil)
self:CheckCurrentRaid(true)
if RequestRaidInfo then RequestRaidInfo() end
self:ScheduleCheck(1)
end
function R:ScheduleCheck(delay)
self._checkRevision = (self._checkRevision or 0) + 1
local revision = self._checkRevision
local function run()
if revision == self._checkRevision then self:CheckCurrentRaid(false) end
end
if C_Timer and C_Timer.After then C_Timer.After(delay or 0.5, run) else run() end
end
function R:Init()
if self._inited then return end
self._inited = true
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("UPDATE_INSTANCE_INFO")
frame:SetScript("OnEvent", function(_, event)
if event ~= "UPDATE_INSTANCE_INFO" and RequestRaidInfo then RequestRaidInfo() end
self:ScheduleCheck(event == "UPDATE_INSTANCE_INFO" and 0.2 or 0.8)
end)
self._eventFrame = frame
if RequestRaidInfo then RequestRaidInfo() end
self:ScheduleCheck(1)
end
