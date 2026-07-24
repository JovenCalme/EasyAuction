local addonName, ns = ...

ns.Mail = ns.Mail or {}
local Mail = ns.Mail

Mail.ADDON_NAME = addonName or "EasyAuction"
Mail.SCHEMA_VERSION = 3

-- 该常量只控制当前构建是否运行邮箱模块，绝不写入 SavedVariables。
if Mail.ROLLOUT_ENABLED == nil then
    Mail.ROLLOUT_ENABLED = true
end

Mail.RuntimeState = Mail.RuntimeState or {
    UNINITIALIZED = "UNINITIALIZED",
    DISABLED_ROLLOUT = "DISABLED_ROLLOUT",
    WAITING_CONFLICT_DECISION = "WAITING_CONFLICT_DECISION",
    ENABLING = "ENABLING",
    ENABLED = "ENABLED",
    DISABLING = "DISABLING",
    DISABLED = "DISABLED",
}

Mail.OwnerKind = Mail.OwnerKind or {
    INBOX_QUEUE = "INBOX_QUEUE",
    SINGLE_SEND = "SINGLE_SEND",
    ATTACHMENT = "ATTACHMENT",
    BULK_SEND = "BULK_SEND",
}

Mail._subscribers = Mail._subscribers or {}
Mail._runtimeModules = Mail._runtimeModules or {}
Mail._runtimeModuleById = Mail._runtimeModuleById or {}

local REALM_ROMAN_SUFFIXES = {
    { "VIII", "8" }, { "VII", "7" }, { "III", "3" },
    { "VI", "6" }, { "IV", "4" }, { "II", "2" }, { "IX", "9" },
    { "X", "10" }, { "V", "5" }, { "I", "1" },
}
local REALM_LOCALIZED_SUFFIXES = {
    { "Ⅷ", "8" }, { "Ⅶ", "7" }, { "Ⅲ", "3" },
    { "Ⅵ", "6" }, { "Ⅳ", "4" }, { "Ⅱ", "2" }, { "Ⅸ", "9" },
    { "Ⅹ", "10" }, { "Ⅴ", "5" }, { "Ⅰ", "1" },
    { "十", "10" }, { "九", "9" }, { "八", "8" }, { "七", "7" }, { "六", "6" },
    { "五", "5" }, { "四", "4" }, { "三", "3" }, { "二", "2" }, { "一", "1" },
}

local function hasNonASCII(value)
    for index = 1, #value do
        if string.byte(value, index) > 127 then return true end
    end
    return false
end

local function timeRealmBase(value)
    local prefix = "时光"
    if value:sub(1, #prefix) ~= prefix then return nil end
    local remainder = value:sub(#prefix + 1)
    local upper = string.upper(remainder)
    for index = 1, #REALM_ROMAN_SUFFIXES do
        local numeral = REALM_ROMAN_SUFFIXES[index][1]
        if upper:sub(1, #numeral) == numeral then
            return prefix .. remainder:sub(1, #numeral)
        end
    end
    for index = 1, #REALM_LOCALIZED_SUFFIXES do
        local numeral = REALM_LOCALIZED_SUFFIXES[index][1]
        if remainder:sub(1, #numeral) == numeral then
            return prefix .. numeral
        end
    end
end

function Mail.NormalizeRealmToken(value)
    if type(value) ~= "string" then return "" end
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    local decoratedBase = value:match("^(.-)%s+%-%s+.+$")
    if decoratedBase and decoratedBase ~= "" then value = decoratedBase end
    value = value:gsub("%s+", "")
    return timeRealmBase(value) or value
end

function Mail.NormalizeRealmKey(value)
    local token = Mail.NormalizeRealmToken(value)
    if token == "" then return "" end
    local upper = string.upper(token)
    for index = 1, #REALM_ROMAN_SUFFIXES do
        local suffix, replacement = unpack(REALM_ROMAN_SUFFIXES[index])
        if #upper > #suffix and upper:sub(-#suffix) == suffix then
            local prefix = token:sub(1, #token - #suffix)
            if hasNonASCII(prefix) then return string.lower(prefix .. replacement) end
        end
    end
    for index = 1, #REALM_LOCALIZED_SUFFIXES do
        local suffix, replacement = unpack(REALM_LOCALIZED_SUFFIXES[index])
        if #token > #suffix and token:sub(-#suffix) == suffix then
            return string.lower(token:sub(1, #token - #suffix) .. replacement)
        end
    end
    return string.lower(token)
end

function Mail.IsSameRealm(left, right)
    local leftKey = Mail.NormalizeRealmKey(left)
    return leftKey ~= "" and leftKey == Mail.NormalizeRealmKey(right)
end

function Mail.GetCurrentRecipientRealm(api)
    api = api or _G
    if type(api.GetNormalizedRealmName) == "function" then
        local ok, realm = pcall(api.GetNormalizedRealmName)
        if ok and type(realm) == "string" and realm ~= "" then
            return Mail.NormalizeRealmToken(realm)
        end
    end
    if type(api.UnitName) == "function" then
        local ok, _, realm = pcall(api.UnitName, "player")
        if ok and type(realm) == "string" and realm ~= "" then
            return Mail.NormalizeRealmToken(realm)
        end
    end
    if type(api.GetRealmName) == "function" then
        local ok, realm = pcall(api.GetRealmName)
        if ok then return Mail.NormalizeRealmToken(realm) end
    end
    return ""
end

local function reportError(message)
    local text = "|cffff4040[EasyAuction 邮箱]|r " .. tostring(message)
    if _G.DEFAULT_CHAT_FRAME and type(_G.DEFAULT_CHAT_FRAME.AddMessage) == "function" then
        _G.DEFAULT_CHAT_FRAME:AddMessage(text)
    elseif type(_G.print) == "function" then
        _G.print(text)
    end
end

function Mail.NewError(_, code, message, detail)
    return {
        code = tostring(code or "UNKNOWN_ERROR"),
        message = tostring(message or "发生未知错误。"),
        detail = detail,
    }
end

function Mail:SafeCall(callback, ...)
    if type(callback) ~= "function" then
        return nil, self:NewError("INVALID_CALLBACK", "回调函数无效。")
    end
    local result = { pcall(callback, ...) }
    if not result[1] then
        reportError(result[2])
        return nil, self:NewError("CALLBACK_FAILED", "邮箱模块回调执行失败。", {
            cause = tostring(result[2]),
        })
    end
    table.remove(result, 1)
    return unpack(result)
end

function Mail:Subscribe(eventName, owner, callback)
    if type(eventName) ~= "string" or owner == nil or type(callback) ~= "function" then
        return nil, self:NewError("INVALID_SUBSCRIPTION", "邮箱事件订阅参数无效。")
    end
    local bucket = self._subscribers[eventName]
    if not bucket then
        bucket = {}
        self._subscribers[eventName] = bucket
    end
    for i = #bucket, 1, -1 do
        if bucket[i].owner == owner then
            table.remove(bucket, i)
        end
    end
    bucket[#bucket + 1] = { owner = owner, callback = callback }
    return true
end

function Mail:UnsubscribeOwner(owner)
    if owner == nil then return false end
    local removed = false
    for eventName, bucket in pairs(self._subscribers) do
        for i = #bucket, 1, -1 do
            if bucket[i].owner == owner then
                table.remove(bucket, i)
                removed = true
            end
        end
        if #bucket == 0 then
            self._subscribers[eventName] = nil
        end
    end
    return removed
end

function Mail:Publish(eventName, payload)
    local bucket = self._subscribers[eventName]
    if not bucket then return 0 end
    local snapshot = {}
    for i = 1, #bucket do snapshot[i] = bucket[i] end
    local delivered = 0
    for i = 1, #snapshot do
        local ok, cause = pcall(snapshot[i].callback, payload, eventName)
        if ok then
            delivered = delivered + 1
        else
            reportError(cause)
        end
    end
    return delivered
end

function Mail:RegisterRuntimeModule(id, module, order)
    if type(id) ~= "string" or id == "" or type(module) ~= "table" then
        return nil, self:NewError("INVALID_RUNTIME_MODULE", "运行模块注册参数无效。")
    end
    local existing = self._runtimeModuleById[id]
    if existing then
        existing.module = module
        existing.order = tonumber(order) or existing.order or 100
    else
        existing = { id = id, module = module, order = tonumber(order) or 100 }
        self._runtimeModuleById[id] = existing
        self._runtimeModules[#self._runtimeModules + 1] = existing
    end
    table.sort(self._runtimeModules, function(left, right)
        if left.order == right.order then return left.id < right.id end
        return left.order < right.order
    end)
    return true
end

function Mail:GetRuntimeModules()
    return self._runtimeModules
end

function Mail:IsGenerationCurrent(generation)
    local controller = self.ModuleController
    return controller and controller:IsRuntimeEnabled()
        and controller:GetGeneration() == generation
end

function Mail.CreateGenerationGuard(_, generation, callback)
    return function(...)
        if not Mail:IsGenerationCurrent(generation) then return end
        return callback(...)
    end
end
