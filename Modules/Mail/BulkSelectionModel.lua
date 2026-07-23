local _, ns = ...

ns = ns or {}
ns.Mail = ns.Mail or {}
local Mail = ns.Mail

local BulkSelectionModel = {}
BulkSelectionModel.__index = BulkSelectionModel
local VIEWPORT_COLUMNS = 4

local function newError(code, message, detail)
    if Mail.NewError then return Mail:NewError(code, message, detail) end
    return { code = code, message = message, detail = detail }
end

local function clone(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = clone(item) end
    return result
end

function BulkSelectionModel.New(deps)
    deps = deps or {}
    local selectionBySource = { ["raid:"] = {} }
    local statusBySource = { ["raid:"] = {} }
    return setmetatable({
        maxRecipients = tonumber(deps.maxRecipients) or 200,
        isRecipientBlocked = deps.isRecipientBlocked,
        sourceKind = "raid",
        sourceGroupId = nil,
        filter = {},
        roster = { generation = 0, sourceKind = "raid", loading = false, stale = false, members = {}, ranks = {} },
        selectionBySource = selectionBySource,
        statusBySource = statusBySource,
        selected = selectionBySource["raid:"],
        statusByKey = statusBySource["raid:"],
    }, BulkSelectionModel)
end

function BulkSelectionModel:SetSource(sourceKind, sourceGroupId)
    self.sourceKind = sourceKind
    self.sourceGroupId = sourceGroupId
    local sourceKey = tostring(sourceKind) .. ":" .. tostring(sourceGroupId or "")
    self.selectionBySource[sourceKey] = self.selectionBySource[sourceKey] or {}
    self.statusBySource[sourceKey] = self.statusBySource[sourceKey] or {}
    self.selected = self.selectionBySource[sourceKey]
    self.statusByKey = self.statusBySource[sourceKey]
    self.filter = {}
end

function BulkSelectionModel:SetFilter(filter)
    self.filter = clone(filter or {})
end

function BulkSelectionModel:UpdateRoster(snapshot)
    self.roster = clone(snapshot or {
        generation = 0, sourceKind = self.sourceKind, loading = false, stale = true, members = {}, ranks = {},
    })
    self.roster.members = self.roster.members or {}
    local available = {}
    for index = 1, #self.roster.members do
        local key = self.roster.members[index].recipientKey
        if key and not self:_isBlocked(self.roster.members[index]) then available[key] = true end
    end
    for key in pairs(self.selected) do
        if not available[key] then self.selected[key] = nil end
    end
end

function BulkSelectionModel:_isBlocked(member)
    return type(self.isRecipientBlocked) == "function"
        and self.isRecipientBlocked(member) == true
end

function BulkSelectionModel:_matches(member)
    if self:_isBlocked(member) then return false end
    local filter = self.filter
    local rankFilter = filter.rankIndices
    if self.sourceKind == "guild" and type(rankFilter) == "table"
        and next(rankFilter) ~= nil and rankFilter[member.rankIndex] ~= true then
        return false
    end
    if filter.onlineOnly and member.online ~= true then return false end
    if type(filter.query) == "string" and filter.query ~= "" then
        local query = string.lower(filter.query)
        local target = string.lower((member.displayName or "") .. " " .. (member.sendName or ""))
        if not string.find(target, query, 1, true) then return false end
    end
    return true
end

function BulkSelectionModel:GetFilteredMembers()
    local result = {}
    for index = 1, #self.roster.members do
        local member = self.roster.members[index]
        if self:_matches(member) then result[#result + 1] = clone(member) end
    end
    return result
end

function BulkSelectionModel:Toggle(recipientKey)
    local member
    for index = 1, #self.roster.members do
        if self.roster.members[index].recipientKey == recipientKey then member = self.roster.members[index] break end
    end
    if not member then return nil, newError("INVALID_RECIPIENT", "名单中不存在该收件人") end
    if member.isSelf then return nil, newError("SELF_RECIPIENT", "不能给当前角色邮寄金币") end
    if self:_isBlocked(member) then
        return nil, newError("RECIPIENT_BLACKLISTED", "该收件人已在黑名单")
    end
    if self.selected[recipientKey] then
        self.selected[recipientKey] = nil
        return true
    end
    local count = 0
    for _ in pairs(self.selected) do count = count + 1 end
    if count >= self.maxRecipients then
        return nil, newError("TOO_MANY_RECIPIENTS", "单批最多选择 " .. self.maxRecipients .. " 人")
    end
    self.selected[recipientKey] = true
    return true
end

function BulkSelectionModel:SelectFiltered()
    local filtered = self:GetFilteredMembers()
    local additions = {}
    local selectedCount = 0
    for _ in pairs(self.selected) do selectedCount = selectedCount + 1 end
    for index = 1, #filtered do
        local member = filtered[index]
        if not member.isSelf and not self.selected[member.recipientKey] then
            additions[#additions + 1] = member.recipientKey
        end
    end
    if selectedCount + #additions > self.maxRecipients then
        return {
            selectedCount = selectedCount,
            changedCount = 0,
            error = newError("TOO_MANY_RECIPIENTS", "筛选结果超过单批人数上限", {
                maximum = self.maxRecipients, requested = selectedCount + #additions,
            }),
        }
    end
    for index = 1, #additions do self.selected[additions[index]] = true end
    return { selectedCount = selectedCount + #additions, changedCount = #additions }
end

function BulkSelectionModel:ClearFiltered()
    local changed = 0
    local filtered = self:GetFilteredMembers()
    for index = 1, #filtered do
        local key = filtered[index].recipientKey
        if self.selected[key] then self.selected[key] = nil changed = changed + 1 end
    end
    return { selectedCount = self:GetSelectionCount(), changedCount = changed }
end

function BulkSelectionModel:GetSelectionCount()
    local count = 0
    for _ in pairs(self.selected) do count = count + 1 end
    return count
end

function BulkSelectionModel:IsSelected(recipientKey)
    return self.selected[recipientKey] == true
end

function BulkSelectionModel:GetSelectedSnapshot()
    local result = {}
    for index = 1, #self.roster.members do
        local member = self.roster.members[index]
        if self.selected[member.recipientKey] and not member.isSelf and not self:_isBlocked(member) then
            result[#result + 1] = {
                itemId = member.recipientKey,
                recipientKey = member.recipientKey,
                sendName = member.sendName,
                displayName = member.displayName,
                sourceKind = self.sourceKind,
                sourceGroupId = self.sourceGroupId,
                rankIndex = member.rankIndex,
                online = member.online,
            }
        end
    end
    return result
end

function BulkSelectionModel:SetRecipientStatus(recipientKey, status)
    self.statusByKey[recipientKey] = clone(status)
end

function BulkSelectionModel:GetRecipientStatus(recipientKey)
    return clone(self.statusByKey[recipientKey])
end

function BulkSelectionModel:ClearStatuses()
    self.statusByKey = {}
    local sourceKey = tostring(self.sourceKind) .. ":" .. tostring(self.sourceGroupId or "")
    self.statusBySource[sourceKey] = self.statusByKey
end

function BulkSelectionModel:GetViewport(rowOffset, capacity)
    local filtered = self:GetFilteredMembers()
    local start = math.max(0, math.floor(tonumber(rowOffset) or 0)) * VIEWPORT_COLUMNS + 1
    capacity = math.max(1, math.floor(tonumber(capacity) or 40))
    local members = {}
    for index = start, math.min(#filtered, start + capacity - 1) do members[#members + 1] = filtered[index] end
    return {
        rowOffset = math.max(0, math.floor(tonumber(rowOffset) or 0)),
        total = #filtered,
        members = members,
        loading = self.roster.loading,
        stale = self.roster.stale,
    }
end

function BulkSelectionModel:GetRosterSnapshot()
    return clone(self.roster)
end

Mail.BulkSelectionModel = BulkSelectionModel
