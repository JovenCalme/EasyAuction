local _, ns = ...

ns = ns or {}
ns.Mail = ns.Mail or {}
local Mail = ns.Mail

local MoneySubjectFormatter = {}

local units = {
    zhCN = { gold = "金", silver = "银", copper = "铜" },
    zhTW = { gold = "金", silver = "銀", copper = "銅" },
    ruRU = { gold = "з", silver = "с", copper = "м" },
    enUS = { gold = "g", silver = "s", copper = "c" },
}

function MoneySubjectFormatter.Split(amount)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    local gold = math.floor(amount / 10000)
    local silver = math.floor((amount % 10000) / 100)
    local copper = amount % 100
    return gold, silver, copper
end

function MoneySubjectFormatter.Format(amount, locale)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if amount == 0 then return "" end
    local labels = units[locale] or units.enUS
    local gold, silver, copper = MoneySubjectFormatter.Split(amount)
    if gold > 0 then
        return string.format("[%d%s %d%s %d%s]", gold, labels.gold, silver, labels.silver, copper, labels.copper)
    end
    if silver > 0 then
        return string.format("[%d%s %d%s]", silver, labels.silver, copper, labels.copper)
    end
    return string.format("[%d%s]", copper, labels.copper)
end

Mail.MoneySubjectFormatter = MoneySubjectFormatter

