local _, ns = ...
ns = type(ns) == "table" and ns or {}
ns.Mail = type(ns.Mail) == "table" and ns.Mail or {}

local Mail = ns.Mail
local Search = {}

local CASE_FOLD = {
    ["Ä"] = "ä",
    ["Ö"] = "ö",
    ["Ü"] = "ü",
    ["ẞ"] = "ß",
}

local function normalize(value)
    value = tostring(value or "")
    for upper, lower in pairs(CASE_FOLD) do
        value = string.gsub(value, upper, lower)
    end
    value = string.lower(value)
    value = string.gsub(value, "^%s+", "")
    value = string.gsub(value, "%s+$", "")
    value = string.gsub(value, "%s+", " ")
    return value
end

local function tokenize(query)
    local tokens = {}
    query = normalize(query)
    for token in string.gmatch(query, "%S+") do
        tokens[#tokens + 1] = token
    end
    return tokens
end

function Search.Normalize(value)
    return normalize(value)
end

function Search.Build(entries, locale)
    local index = {
        locale = locale,
        order = {},
        documents = {},
        entriesById = {},
    }

    for position = 1, #(entries or {}) do
        local entry = entries[position]
        local fields = { entry.displayName or "" }
        for fieldIndex = 1, #(entry.searchFields or {}) do
            fields[#fields + 1] = entry.searchFields[fieldIndex]
        end
        local id = entry.id or tostring(position)
        index.order[#index.order + 1] = id
        index.documents[id] = normalize(table.concat(fields, " "))
        index.entriesById[id] = entry
    end

    return index
end

function Search.Filter(index, query)
    local result = {}
    if type(index) ~= "table" then return result end
    local tokens = tokenize(query)

    for position = 1, #(index.order or {}) do
        local id = index.order[position]
        local document = index.documents[id] or ""
        local matches = true
        for tokenIndex = 1, #tokens do
            if not string.find(document, tokens[tokenIndex], 1, true) then
                matches = false
                break
            end
        end
        if matches then result[#result + 1] = id end
    end

    return result
end

function Search.ToSet(entryIds)
    local set = {}
    for index = 1, #(entryIds or {}) do
        set[entryIds[index]] = true
    end
    return set
end

function Search.New()
    return setmetatable({}, { __index = Search })
end

Mail.InboxSearch = Search

return Search
