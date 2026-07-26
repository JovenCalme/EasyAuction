local _, ns = ...

ns = type(ns) == "table" and ns or {}
ns.BagValue = type(ns.BagValue) == "table" and ns.BagValue or {}

local BagValue = ns.BagValue
local Tooltip = {}
Tooltip.__index = Tooltip

local function formatMoney(value)
    value = math.max(0, math.floor(tonumber(value) or 0))
    if type(_G.GetCoinTextureString) == "function" then
        local ok, text = pcall(_G.GetCoinTextureString, value, 12)
        if ok and type(text) == "string" then return text end
    end
    return tostring(value) .. " 铜"
end

local function errorText(value)
    if type(value) == "table" then return value.message or value.code end
    return value
end

local function topRows(rows, limit)
    local values = {}
    for index = 1, #(rows or {}) do
        local row = rows[index]
        if (tonumber(row.totalValue) or 0) > 0 then values[#values + 1] = row end
    end
    table.sort(values, function(left, right)
        return (tonumber(left.totalValue) or 0) > (tonumber(right.totalValue) or 0)
    end)
    while #values > limit do values[#values] = nil end
    return values
end

function Tooltip.New(deps)
    return setmetatable({ deps = deps or {} }, Tooltip)
end

function Tooltip:Show(owner)
    local tooltip = self.deps.tooltip or _G.GameTooltip
    local controller = self.deps.controller
    if not tooltip or not controller or type(controller.GetTooltipResult) ~= "function" then return false end

    tooltip:SetOwner(owner, "ANCHOR_LEFT")
    if type(tooltip.ClearLines) == "function" then tooltip:ClearLines() end
    local result, err = controller:GetTooltipResult()
    if not result then
        tooltip:AddLine("背包估值", 1, 0.82, 0)
        tooltip:AddLine(errorText(err) or "暂时无法读取背包", 1, 0.35, 0.35, true)
        tooltip:Show()
        return false
    end

    local summary = result.summary or {}
    tooltip:AddDoubleLine("背包估值", formatMoney(summary.totalValue or summary.total),
        1, 0.82, 0, 1, 0.82, 0)
    tooltip:AddDoubleLine("拍卖", formatMoney(summary.auctionValue or summary.auction), 1, 1, 1, 1, 1, 1)
    tooltip:AddDoubleLine("卖店", formatMoney(summary.vendorValue or summary.vendor), 1, 1, 1, 1, 1, 1)
    tooltip:AddDoubleLine("分解", formatMoney(summary.disenchantValue or summary.disenchant), 1, 1, 1, 1, 1, 1)

    local rows = topRows(result.rows, 5)
    if #rows > 0 then
        tooltip:AddLine(" ")
        tooltip:AddLine("价值最高的 5 类物品", 1, 0.82, 0)
        for index = 1, #rows do
            local row = rows[index]
            local label = row.link or row.name or ("物品 " .. tostring(row.itemID or "?"))
            tooltip:AddDoubleLine(label .. " x" .. tostring(row.count or 0),
                formatMoney(row.totalValue), 1, 1, 1, 1, 1, 1)
        end
    end

    tooltip:AddLine(" ")
    tooltip:AddDoubleLine("无价格", tostring(math.max(0, tonumber(summary.unpricedCount) or 0)) .. " 项",
        1, 0.45, 0.45, 1, 0.45, 0.45)
    tooltip:AddLine("点击打开详细列表", 0.75, 0.75, 0.75)
    tooltip:Show()
    return true
end

function Tooltip:Hide()
    local tooltip = self.deps.tooltip or _G.GameTooltip
    if tooltip and type(tooltip.Hide) == "function" then tooltip:Hide() end
end

BagValue.BagValueTooltip = Tooltip
BagValue.Tooltip = Tooltip

return Tooltip
