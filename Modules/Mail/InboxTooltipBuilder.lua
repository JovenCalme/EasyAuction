local _, ns = ...
ns = type(ns) == "table" and ns or {}
ns.Mail = type(ns.Mail) == "table" and ns.Mail or {}

local Mail = ns.Mail
local TooltipBuilder = {}

local function defaultMoney(amount)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    local formatter = _G and _G.GetCoinTextureString
    if type(formatter) ~= "function" and _G and _G.C_CurrencyInfo then
        formatter = _G.C_CurrencyInfo.GetCoinTextureString
    end
    if type(formatter) == "function" then
        local ok, value = pcall(formatter, amount, 14)
        if ok and type(value) == "string" and value ~= "" then return value end
    end
    local gold = math.floor(amount / 10000)
    local silver = math.floor((amount % 10000) / 100)
    local copper = amount % 100
    local parts = {}
    if gold > 0 then
        parts[#parts + 1] = gold .. "|TInterface\\MoneyFrame\\UI-GoldIcon:14:14:2:0|t"
    end
    if silver > 0 then
        parts[#parts + 1] = silver .. "|TInterface\\MoneyFrame\\UI-SilverIcon:14:14:2:0|t"
    end
    if copper > 0 or #parts == 0 then
        parts[#parts + 1] = copper .. "|TInterface\\MoneyFrame\\UI-CopperIcon:14:14:2:0|t"
    end
    return table.concat(parts, " ")
end

local function defaultDuration(daysLeft)
    if type(daysLeft) ~= "number" then return "未知" end
    if daysLeft < 1 then
        return string.format("%.1f小时", math.max(0, daysLeft * 24))
    end
    return string.format("%d天", math.floor(daysLeft))
end

local function append(lines, text, color)
    lines[#lines + 1] = { text = tostring(text or ""), color = color }
end

local function summarizeSourceMails(sources)
    local states = {}
    for index = 1, #sources do
        local source = sources[index]
        local mailKey = source.mailKey
        local key
        if type(mailKey) == "table" then
            key = tostring(mailKey.fingerprint) .. ":" .. tostring(mailKey.duplicateOrdinal)
        elseif source.mailIndex ~= nil then
            key = "index:" .. tostring(source.mailIndex)
        else
            key = "source:" .. tostring(index)
        end
        local canReturn = source.canReturn == true
        if states[key] == nil or not canReturn then states[key] = canReturn end
    end
    local count, returnable, nonReturnable = 0, 0, 0
    for _, canReturn in pairs(states) do
        count = count + 1
        if canReturn then returnable = returnable + 1 else nonReturnable = nonReturnable + 1 end
    end
    return count, returnable, nonReturnable
end

function TooltipBuilder.Build(entry, options)
    options = options or {}
    entry = entry or {}
    local formatMoney = options.formatMoney or defaultMoney
    local formatDuration = options.formatDuration or defaultDuration
    local sources = entry.sources or {}
    local sourceCount, returnableMailCount, nonReturnableMailCount = summarizeSourceMails(sources)
    local model = {
        kind = entry.kind,
        title = entry.displayName or (entry.kind == "money" and "金币" or "未知物品"),
        itemLink = entry.itemLink,
        lines = {},
        sourceCount = sourceCount,
        returnableMailCount = returnableMailCount,
        nonReturnableMailCount = nonReturnableMailCount,
    }
    local firstSource = sources[1]
    if firstSource then
        model.mailIndex = firstSource.mailIndex
        model.attachmentIndex = firstSource.attachmentIndex
        model.itemLink = model.itemLink or firstSource.itemLink
    end

    if entry.kind == "money" then
        append(model.lines, string.format("合计：%s，来自 %d 封邮件",
            formatMoney(entry.totalMoney), sourceCount), { 1, 1, 1 })
    else
        append(model.lines, string.format("汇总：%d 件，来自 %d 封邮件",
            math.max(0, tonumber(entry.totalCount) or 0), sourceCount), { 1, 1, 1 })
    end

    local earliest
    for sourceIndex = 1, #sources do
        local daysLeft = tonumber(sources[sourceIndex].daysLeft)
        if daysLeft and (not earliest or daysLeft < earliest) then earliest = daysLeft end
    end
    if earliest then append(model.lines, "最早到期：" .. formatDuration(earliest)) end
    if nonReturnableMailCount > 0 then
        append(model.lines, string.format("退信状态：可退 %d 封，需转寄 %d 封",
            returnableMailCount, nonReturnableMailCount), { 1, 0.25, 0.25 })
    elseif returnableMailCount > 0 then
        append(model.lines, string.format("退信状态：%d 封均可退信",
            returnableMailCount), { 0.2, 1, 0.2 })
    end
    append(model.lines, "左键领取全部，右键仅领取一封", { 0.75, 0.75, 0.75 })

    return model
end

function TooltipBuilder.Render(model, tooltip, owner)
    if type(tooltip) ~= "table" or type(tooltip.AddLine) ~= "function" then return false end
    if type(tooltip.SetOwner) == "function" and owner then
        tooltip:SetOwner(owner, "ANCHOR_RIGHT")
    end
    if type(tooltip.ClearLines) == "function" then tooltip:ClearLines() end
    local renderedItem = false
    if model.kind == "item" and model.mailIndex and model.attachmentIndex
        and type(tooltip.SetInboxItem) == "function" then
        renderedItem = pcall(tooltip.SetInboxItem, tooltip, model.mailIndex, model.attachmentIndex)
    elseif model.kind == "item" and model.itemLink and type(tooltip.SetHyperlink) == "function" then
        renderedItem = pcall(tooltip.SetHyperlink, tooltip, model.itemLink)
    end
    if not renderedItem then tooltip:AddLine(model.title or "") end
    for index = 1, #(model.lines or {}) do
        local line = model.lines[index]
        local color = line.color
        if color then
            tooltip:AddLine(line.text, color[1], color[2], color[3], true)
        else
            tooltip:AddLine(line.text, nil, nil, nil, true)
        end
    end
    if type(tooltip.Show) == "function" then tooltip:Show() end
    return true
end

function TooltipBuilder.New()
    return setmetatable({}, { __index = TooltipBuilder })
end

Mail.InboxTooltipBuilder = TooltipBuilder

return TooltipBuilder
