local _, ns = ...

ns = ns or {}
ns.Mail = ns.Mail or {}
local Mail = ns.Mail

local RecipientSuggestions = {}
RecipientSuggestions.__index = RecipientSuggestions

local function clone(value)
    local result = {}
    for key, item in pairs(value or {}) do result[key] = item end
    return result
end

local function beginsWith(value, prefix)
    return prefix == "" or string.sub(value, 1, #prefix) == prefix
end

function RecipientSuggestions.New(deps)
    deps = deps or {}
    local self = setmetatable({ providers = {}, casefold = deps.casefold or string.lower }, RecipientSuggestions)
    local repository = deps.recipientRepository
    if repository then
        self:RegisterProvider("contacts", 10, function(_, context) return repository:ListContacts(context) end)
        self:RegisterProvider("recent", 20, function(_, context) return repository:ListRecent(context) end)
        self:RegisterProvider("realmAlts", 30, function(_, context)
            local query = clone(context)
            query.currentRealmOnly = true
            return repository:ListAlts(query)
        end)
        self:RegisterProvider("allAlts", 40, function(_, context) return repository:ListAlts(context) end)
    end
    return self
end

function RecipientSuggestions:RegisterProvider(name, priority, provider)
    if type(name) ~= "string" or (type(provider) ~= "function" and type(provider) ~= "table") then
        return false
    end
    self.providers[#self.providers + 1] = { name = name, priority = tonumber(priority) or 100, provider = provider }
    table.sort(self.providers, function(left, right)
        if left.priority == right.priority then return left.name < right.name end
        return left.priority < right.priority
    end)
    return true
end

function RecipientSuggestions:Query(prefix, context)
    prefix = self.casefold((prefix or ""):gsub("^%s+", ""))
    context = context or {}
    local byKey, ordered = {}, {}
    for providerIndex = 1, #self.providers do
        local descriptor = self.providers[providerIndex]
        local ok, values
        if type(descriptor.provider) == "function" then
            ok, values = pcall(descriptor.provider, prefix, context)
        else
            ok, values = pcall(descriptor.provider.Query, descriptor.provider, prefix, context)
        end
        if ok and type(values) == "table" then
            for index = 1, #values do
                local value = values[index]
                local searchable = self.casefold(value.displayName or value.sendName or value.name or "")
                local sendName = self.casefold(value.sendName or "")
                if value.recipientKey and not value.isSelf
                    and (beginsWith(searchable, prefix) or beginsWith(sendName, prefix)) then
                    local candidate = byKey[value.recipientKey]
                    if not candidate then
                        candidate = clone(value)
                        candidate.sources = {}
                        candidate.priority = descriptor.priority
                        byKey[value.recipientKey] = candidate
                        ordered[#ordered + 1] = candidate
                    end
                    local sourceName = value.source or descriptor.name
                    local duplicate = false
                    for sourceIndex = 1, #candidate.sources do
                        if candidate.sources[sourceIndex] == sourceName then duplicate = true break end
                    end
                    if not duplicate then candidate.sources[#candidate.sources + 1] = sourceName end
                end
            end
        end
    end
    table.sort(ordered, function(left, right)
        if left.priority ~= right.priority then return left.priority < right.priority end
        return self.casefold(left.displayName or "") < self.casefold(right.displayName or "")
    end)
    return ordered
end

Mail.RecipientSuggestions = RecipientSuggestions
Mail.RecipientSuggestionService = RecipientSuggestions
