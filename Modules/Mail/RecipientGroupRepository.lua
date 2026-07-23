local _, ns = ...

ns = ns or {}
ns.Mail = ns.Mail or {}
local Mail = ns.Mail

local RecipientGroupRepository = {}
RecipientGroupRepository.__index = RecipientGroupRepository

local function newError(code, message, detail)
    if Mail.NewError then return Mail:NewError(code, message, detail) end
    return { code = code, message = message, detail = detail }
end

local function trim(value)
    if type(value) ~= "string" then return "" end
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function clone(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do
        result[key] = type(item) == "table" and clone(item) or item
    end
    return result
end

function RecipientGroupRepository.New(deps)
    deps = deps or {}
    local storage = deps.storage or {}
    storage.order = type(storage.order) == "table" and storage.order or {}
    storage.byId = type(storage.byId) == "table" and storage.byId or {}
    return setmetatable({
        storage = storage,
        recipientRepository = deps.recipientRepository,
        idFactory = deps.idFactory,
        nextId = 0,
        subscribers = {},
        maxMembers = tonumber(deps.maxMembers) or 200,
    }, RecipientGroupRepository)
end

function RecipientGroupRepository:_makeId()
    if self.idFactory then return tostring(self.idFactory()) end
    local groupId
    repeat
        self.nextId = self.nextId + 1
        groupId = "recipient-group-" .. self.nextId
    until not self.storage.byId[groupId]
    return groupId
end

function RecipientGroupRepository:_notify(kind, groupId)
    local payload = { kind = kind, groupId = groupId }
    local callbacks = {}
    for _, subscription in pairs(self.subscribers) do callbacks[#callbacks + 1] = subscription.callback end
    for index = 1, #callbacks do
        if Mail.SafeCall then Mail:SafeCall(callbacks[index], payload) else pcall(callbacks[index], payload) end
    end
    if Mail.Publish then Mail:Publish("MAIL_RECIPIENT_GROUPS_CHANGED", payload) end
end

function RecipientGroupRepository:_normalizeMember(value)
    if self.recipientRepository and self.recipientRepository.Normalize then
        return self.recipientRepository:Normalize(value, "custom")
    end
    if type(value) ~= "table" or trim(value.name) == "" then
        return nil, newError("INVALID_RECIPIENT", "自定义组成员无效")
    end
    local result = clone(value)
    result.displayName = result.displayName or result.name
    result.sendName = result.sendName or (result.realm and (result.name .. "-" .. result.realm) or result.name)
    result.recipientKey = result.recipientKey or string.lower(result.sendName:gsub("%s+", ""))
    result.source = "custom"
    return result
end

function RecipientGroupRepository:UpsertGroup(group)
    if type(group) ~= "table" then return nil, newError("INVALID_GROUP", "用户组记录无效") end
    local name = trim(group.name)
    if name == "" then return nil, newError("INVALID_GROUP_NAME", "用户组名称不能为空") end
    local members, seen = {}, {}
    for index = 1, #(group.members or {}) do
        local member, err = self:_normalizeMember(group.members[index])
        if not member then return nil, err end
        if not seen[member.recipientKey] then
            if #members >= self.maxMembers then
                return nil, newError("TOO_MANY_RECIPIENTS", "用户组成员不能超过 " .. self.maxMembers .. " 人")
            end
            seen[member.recipientKey] = true
            members[#members + 1] = clone(member)
        end
    end

    local groupId = trim(group.id)
    if groupId == "" then groupId = self:_makeId() end
    local existed = self.storage.byId[groupId] ~= nil
    self.storage.byId[groupId] = {
        id = groupId,
        name = name,
        members = members,
        updatedAt = group.updatedAt,
    }
    if not existed then self.storage.order[#self.storage.order + 1] = groupId end
    self:_notify(existed and "UPDATED" or "CREATED", groupId)
    return true, nil, groupId
end

function RecipientGroupRepository:ListGroups()
    local result = {}
    for index = 1, #self.storage.order do
        local group = self.storage.byId[self.storage.order[index]]
        if group then result[#result + 1] = clone(group) end
    end
    return result
end

function RecipientGroupRepository:GetMembers(groupId)
    local group = self.storage.byId[groupId]
    return group and clone(group.members) or {}
end

function RecipientGroupRepository:Get(groupId)
    return self.storage.byId[groupId] and clone(self.storage.byId[groupId]) or nil
end

function RecipientGroupRepository:AddMember(groupId, value)
    local group = self.storage.byId[groupId]
    if not group then return nil, newError("GROUP_NOT_FOUND", "找不到指定用户组") end
    local member, err = self:_normalizeMember(value)
    if not member then return nil, err end
    for index = 1, #group.members do
        if group.members[index].recipientKey == member.recipientKey then return true end
    end
    if #group.members >= self.maxMembers then
        return nil, newError("TOO_MANY_RECIPIENTS", "用户组成员不能超过 " .. self.maxMembers .. " 人")
    end
    group.members[#group.members + 1] = clone(member)
    self:_notify("UPDATED", groupId)
    return true
end

function RecipientGroupRepository:RemoveMember(groupId, value)
    local group = self.storage.byId[groupId]
    if not group then return nil, newError("GROUP_NOT_FOUND", "找不到指定用户组") end
    local member, err = self:_normalizeMember(value)
    if not member then return nil, err end
    for index = #group.members, 1, -1 do
        if group.members[index].recipientKey == member.recipientKey then
            table.remove(group.members, index)
            self:_notify("UPDATED", groupId)
            return true
        end
    end
    return nil, newError("GROUP_MEMBER_NOT_FOUND", "该成员不在当前用户组")
end

function RecipientGroupRepository:DeleteGroup(groupId)
    if not self.storage.byId[groupId] then return false end
    self.storage.byId[groupId] = nil
    for index = #self.storage.order, 1, -1 do
        if self.storage.order[index] == groupId then table.remove(self.storage.order, index) end
    end
    self:_notify("DELETED", groupId)
    return true
end

function RecipientGroupRepository:Subscribe(owner, callback)
    if owner == nil or type(callback) ~= "function" then
        return nil, newError("INVALID_SUBSCRIPTION", "订阅必须包含 owner 和 callback")
    end
    self.subscribers[owner] = { callback = callback }
    return true
end

function RecipientGroupRepository:Unsubscribe(owner)
    self.subscribers[owner] = nil
end

Mail.RecipientGroupRepository = RecipientGroupRepository
