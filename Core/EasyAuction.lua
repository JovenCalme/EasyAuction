local addonName, ns = ...
local EAStyle = _G.EasyAuctionStyle

local function EA_RaiseUtilityFrame(frame, baseOwner)
    if not frame then return end
    local maxLevel = 0
    local function AddFrameLevel(candidate)
        if candidate and candidate.GetFrameLevel then
            maxLevel = math.max(maxLevel, candidate:GetFrameLevel() or 0)
        end
    end

    local auctionBar = _G.AuctionBarFrame
    local owner = baseOwner or (auctionBar and auctionBar.AuctionFrame)
    AddFrameLevel(owner)
    AddFrameLevel(_G.AuctionHelper)
    if owner then
        AddFrameLevel(owner.ItemsFrame)
        AddFrameLevel(owner.MyAuctionListFrame)
    end
    if auctionBar and auctionBar.AuctionFrame and auctionBar.AuctionFrame ~= owner then
        AddFrameLevel(auctionBar.AuctionFrame)
        AddFrameLevel(auctionBar.AuctionFrame.ItemsFrame)
        AddFrameLevel(auctionBar.AuctionFrame.MyAuctionListFrame)
    end

    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(math.max(maxLevel + 50, 200))
    frame:SetToplevel(true)
end

local function EA_ToggleConfigFrame(anchor)
    if EasyAuctionConfigFrame and EasyAuctionConfigFrame:IsShown() then
        EasyAuctionConfigFrame:Hide()
        return
    end

    if type(CreateEasyAuctionConfigFrame) ~= "function" then
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                if type(CreateEasyAuctionConfigFrame) == "function" then
                    EA_ToggleConfigFrame(anchor)
                else
                    print("|cffff2020[EasyAuction]|r 设置窗口尚未加载，请稍后再试。")
                end
            end)
            return
        end
        print("|cffff2020[EasyAuction]|r 设置窗口尚未加载，请稍后再试。")
        return
    end

    local mainFrame = _G.AuctionBarFrame and _G.AuctionBarFrame.AuctionFrame
    local dockAnchor = anchor
    if not (dockAnchor and dockAnchor.GetObjectType and dockAnchor:IsShown()) then
        if mainFrame and mainFrame:IsShown() then
            dockAnchor = mainFrame
        elseif _G.AuctionHelper and _G.AuctionHelper:IsShown() then
            dockAnchor = _G.AuctionHelper
        else
            dockAnchor = nil
        end
    end

    if not EasyAuctionConfigFrame then
        CreateEasyAuctionConfigFrame(dockAnchor or UIParent)
    end
    if not EasyAuctionConfigFrame then return end

    EasyAuctionConfigFrame:ClearAllPoints()
    if dockAnchor then
        EasyAuctionConfigFrame:SetPoint("TOPLEFT", dockAnchor, "TOPRIGHT", 6, 0)
    else
        EasyAuctionConfigFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
    if EasyAuctionConfigFrame.SetClampedToScreen then
        EasyAuctionConfigFrame:SetClampedToScreen(true)
    end
    EA_RaiseUtilityFrame(EasyAuctionConfigFrame, dockAnchor or UIParent)
    EasyAuctionConfigFrame:Show()
end
_G.EasyAuction_ToggleConfigFrame = EA_ToggleConfigFrame

local function EA_StyleSkin(frame, role)
    EAStyle = EAStyle or _G.EasyAuctionStyle
    if EAStyle then
        EAStyle:SkinExistingFrame(frame, role or "panel")
    end
    return frame
end

local function EA_StyleButton(button)
    EAStyle = EAStyle or _G.EasyAuctionStyle
    if EAStyle then
        EAStyle:SkinButton(button)
    end
    return button
end

local function EA_StyleText(fs, role)
    EAStyle = EAStyle or _G.EasyAuctionStyle
    if EAStyle then
        EAStyle:SkinText(fs, role)
    end
    return fs
end

local function EA_StyleRow(texture, index, selected)
    EAStyle = EAStyle or _G.EasyAuctionStyle
    if EAStyle then
        EAStyle:RowColor(texture, index, selected)
    elseif texture then
        texture:SetColorTexture(1, 1, 1, selected and 0.18 or ((index % 2 == 0) and 0.04 or 0.08))
    end
end

local function EA_StyleDialog(frame, titleText, width, height, hideClose)
    if not frame then return end
    frame:SetSize(width, height)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    EA_StyleSkin(frame, "window")
    if frame.NineSlice then frame.NineSlice:Hide() end
    if frame.Inset then frame.Inset:Hide() end
    if not frame.EA_Title then
        frame.EA_Title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        frame.EA_Title:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -12)
        frame.EA_Title:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 14, "")
        EA_StyleText(frame.EA_Title, "accent")
    end
    frame.EA_Title:SetText(titleText or "")
    if not frame.EA_Close then
        frame.EA_Close = EAStyle and EAStyle:CloseButton(frame) or CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        frame.EA_Close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
        frame.EA_Close:SetScript("OnClick", function() frame:Hide() end)
    end
    if hideClose then
        frame.EA_Close:Hide()
    else
        frame.EA_Close:Show()
    end
end

local function EA_StylePanel(frame, role)
    if frame then
        if EAStyle then
            EAStyle:Skin(frame, role or "panel")
        else
            frame:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
            })
            frame:SetBackdropColor(0.10, 0.10, 0.13, 0.97)
            frame:SetBackdropBorderColor(0.35, 0.35, 0.40, 1)
        end
    end
    return frame
end

local function EA_EnsureSolidBackground(frame, role, alpha)
    if not frame then return end
    local bg = frame.EA_SolidBackground
    if not bg then
        bg = frame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        frame.EA_SolidBackground = bg
    end
    alpha = alpha or 0.98
    if EAStyle then
        if not bg.EA_ThemeHooked then
            bg.EA_ThemeHooked = true
            EAStyle:OnTheme(function(p)
                local col = p.panel
                if role == "window" then
                    col = p.bg
                elseif role == "plot" then
                    col = p.plot or p.bg
                end
                bg:SetColorTexture(col[1], col[2], col[3], alpha)
            end)
        end
    else
        bg:SetColorTexture(0.10, 0.10, 0.13, alpha)
    end
    bg:Show()
    return bg
end

local function EA_StyleEditBox(box)
    if not box then return box end
    if EAStyle then
        EAStyle:SkinEditBox(box)
    end
    if box.SetFont then
        box:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
    end
    return box
end

local function EA_AddBoxLine(parent, key, orientation)
    parent.EA_Lines = parent.EA_Lines or {}
    local tex = parent.EA_Lines[key]
    if not tex then
        tex = parent:CreateTexture(nil, "OVERLAY")
        tex:SetTexture("Interface\\Buttons\\WHITE8X8")
        parent.EA_Lines[key] = tex
    end
    tex:ClearAllPoints()
    if orientation == "vertical" then
        tex:SetWidth(1)
    else
        tex:SetHeight(1)
    end
    if EAStyle then
        if not tex.EA_ThemeHooked then
            tex.EA_ThemeHooked = true
            EAStyle:OnTheme(function(p)
                tex:SetColorTexture(p.border[1], p.border[2], p.border[3], 0.65)
            end)
        end
    else
        tex:SetColorTexture(0.45, 0.45, 0.50, 0.65)
    end
    tex:Show()
    return tex
end

local function EA_StyleCloseButton(parent, onClick)
    local close = parent.EA_CloseButton
    if not close then
        close = EAStyle and EAStyle:CloseButton(parent) or CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        close:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, -8)
        parent.EA_CloseButton = close
    end
    close:SetSize(22, 22)
    if close.SetText then close:SetText("\195\151") end
    if not EAStyle then EA_StyleButton(close) end
    close:SetScript("OnClick", onClick or function(self) self:GetParent():Hide() end)
    close:Show()
    return close
end

local function EA_ApplyCellFont(fs, role, justify)
    if not fs then return end
    fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    EA_StyleText(fs, role or "text")
end

local function EA_StyleRowHighlight(button)
    if not button then return end
    local tex = button.EA_RowHighlight
    if not tex then
        tex = button:CreateTexture(nil, "HIGHLIGHT")
        tex:SetAllPoints()
        tex:SetTexture("Interface\\Buttons\\WHITE8X8")
        button:SetHighlightTexture(tex)
        button.EA_RowHighlight = tex
    end
    if EAStyle then
        if not tex.EA_ThemeHooked then
            tex.EA_ThemeHooked = true
            EAStyle:OnTheme(function(p)
                tex:SetColorTexture(p.accent[1], p.accent[2], p.accent[3], 0.18)
            end)
        end
    else
        tex:SetColorTexture(0.10, 0.75, 0.90, 0.18)
    end
    tex:Show()
end

ns.EA_DB_RESET_PROMPT_VERSION = 2

-- 新的全局数据库，按服务器-阵营存储
EasyAuctionDB2 = type(EasyAuctionDB2) == "table" and EasyAuctionDB2 or {}

-- 向后兼容：保留旧的全局变量引用，但数据将从新的结构中迁移
-- EasyAuctionDB 将在 PLAYER_LOGIN 后被设置为当前服务器-阵营的数据库
_G.EasyAuctionDB = type(_G.EasyAuctionDB) == "table" and _G.EasyAuctionDB or {}

-- 声明局部变量 EasyAuctionDB，将在初始化时指向当前服务器-阵营的数据库
local EasyAuctionDB

function ns.EA_MarkDBResetPromptDone()
    EasyAuctionDB2 = type(EasyAuctionDB2) == "table" and EasyAuctionDB2 or {}
    EasyAuctionDB2.__DBResetPromptVersion = ns.EA_DB_RESET_PROMPT_VERSION
end

function ns.EA_ShouldAskDBReset()
    EasyAuctionDB2 = type(EasyAuctionDB2) == "table" and EasyAuctionDB2 or {}
    local hasSavedDB2 = false
    for key in pairs(EasyAuctionDB2) do
        if key ~= "__LegacyResetPromptVersion" and key ~= "__DBResetPromptVersion" then
            hasSavedDB2 = true
            break
        end
    end
    local legacyDB = _G.EasyAuctionDB
    local hasLegacyDB = type(legacyDB) == "table" and next(legacyDB) ~= nil
    if not hasSavedDB2 and not hasLegacyDB then
        return false
    end
    return tonumber(EasyAuctionDB2.__DBResetPromptVersion or 0) < ns.EA_DB_RESET_PROMPT_VERSION
end

local function EA_GetAddonMetadata(name, field)
    if type(GetAddOnMetadata) == "function" then
        return GetAddOnMetadata(name, field)
    end
    if C_AddOns and type(C_AddOns.GetAddOnMetadata) == "function" then
        return C_AddOns.GetAddOnMetadata(name, field)
    end
end

local function EA_GetAddonToggle(funcName)
    if C_AddOns and type(C_AddOns[funcName]) == "function" then
        return C_AddOns[funcName]
    end
    if type(_G[funcName]) == "function" then
        return _G[funcName]
    end
end

local function EA_GetAddonEnableState(addon, character)
    if C_AddOns and type(C_AddOns.GetAddOnEnableState) == "function" then
        return C_AddOns.GetAddOnEnableState(addon, character)
    end
    if type(GetAddOnEnableState) == "function" then
        return GetAddOnEnableState(character, addon)
    end
end

local function EA_IsAddonEnabled(addon, character)
    local state = EA_GetAddonEnableState(addon, character)
    return type(state) == "number" and state > 0
end

local function EA_IsManagedAddon(name)
    return name and name ~= addonName and not name:find("^Blizzard_")
end

EasyAuction_SearchHistoryDropDown = CreateFrame("Frame", "EasyAuction_SearchHistoryDropDown", UIParent,
    "UIDropDownMenuTemplate")

local RECENT_MAX = 20
local FAVORITE_MAX = 50
local EA_CategoryMode = nil
local EA_CategorySortKey = "titanValue"
local EA_CategorySortDesc = true
local EA_CategoryCurrentPage = 1
local EA_CategoryTotalPages = 1
local EA_ActiveCategory = nil

local function EA_ClampInt(value, defaultValue, minValue, maxValue)
    local n = math.floor(tonumber(value) or tonumber(defaultValue) or 0)
    if minValue and n < minValue then n = minValue end
    if maxValue and n > maxValue then n = maxValue end
    return n
end

local function EA_AssignIfNil(tbl, key, value)
    if tbl[key] == nil then
        tbl[key] = value
    end
end

local EA_UpdateItemIDIndexForKey
local EA_RemoveItemIDIndexForKey

local function EA_CompressHistoryRecords(records, keepLimit, cutoffTime)
    if type(records) ~= "table" then
        return {}, 0
    end

    local byUnit = {}
    local removed = 0
    for _, rec in ipairs(records) do
        local unit = rec and tonumber(rec.unit)
        local count = rec and tonumber(rec.count) or 1
        local t = rec and tonumber(rec.t) or nil

        if not unit or unit <= 0 then
            removed = removed + 1
        elseif cutoffTime and t and t <= cutoffTime then
            removed = removed + 1
        else
            local bucket = byUnit[unit]
            if not bucket then
                byUnit[unit] = {
                    unit = unit,
                    count = count > 0 and count or 1,
                    t = t or time(),
                }
            else
                bucket.count = (bucket.count or 0) + (count > 0 and count or 1)
                if t and ((bucket.t or 0) < t) then
                    bucket.t = t
                end
                removed = removed + 1
            end
        end
    end

    local out = {}
    for _, bucket in pairs(byUnit) do
        out[#out + 1] = bucket
    end
    table.sort(out, function(a, b) return (a.unit or 0) < (b.unit or 0) end)

    local limit = EA_ClampInt(keepLimit or 0, 0, 0, 5000)
    if limit > 0 and #out > limit then
        for i = #out, limit + 1, -1 do
            out[i] = nil
            removed = removed + 1
        end
    end

    return out, removed
end

local EA_STORAGE_VERSION = 3
local EA_STORAGE_CACHE_LIMIT = 120
local EA_STORAGE_CACHE_TICK = 0
local EA_STORAGE_CACHE = {
    price = { map = {}, order = {} },
    daily = { map = {}, order = {} },
    hourly = { map = {}, order = {} },
}

local function EA_GetRuntimeDB()
    return _G.EasyAuctionDB or EasyAuctionDB
end

-- PriceHistory 键数缓存：随写入/删除增量维护，避免每次数表（用全局避免触及主 chunk 局部变量上限）
EA_PriceHistoryKeyCountDB = nil
EA_PriceHistoryKeyCount = nil

function EA_GetPriceHistoryKeyCount()
    local db = EA_GetRuntimeDB()
    if EA_PriceHistoryKeyCount and EA_PriceHistoryKeyCountDB == db then
        return EA_PriceHistoryKeyCount
    end
    local count = 0
    for _ in pairs(db and db.PriceHistory or {}) do
        count = count + 1
    end
    EA_PriceHistoryKeyCountDB = db
    EA_PriceHistoryKeyCount = count
    return count
end

-- 缓存上限随 PriceHistory 键数动态扩容：全库一遍遍历后所有 key 的解码结果都能留在缓存里
function EA_GetStorageCacheLimit()
    return math.max(EA_STORAGE_CACHE_LIMIT, EA_GetPriceHistoryKeyCount())
end

local function EA_IsEncodedStorageValue(value, prefix)
    return type(value) == "string" and value:sub(1, #prefix) == prefix
end

local function EA_ClearStorageCache(kind, key)
    local cache = EA_STORAGE_CACHE[kind]
    if not cache then return end
    if key then
        cache.map[key] = nil
        return
    end
    wipe(cache.map)
    wipe(cache.order)
end

local function EA_TouchStorageCache(kind, key, raw, value)
    local cache = EA_STORAGE_CACHE[kind]
    if not cache or not key then return value end
    EA_STORAGE_CACHE_TICK = EA_STORAGE_CACHE_TICK + 1
    cache.map[key] = { raw = raw, value = value, stamp = EA_STORAGE_CACHE_TICK }
    cache.order[#cache.order + 1] = key
    local limit = EA_GetStorageCacheLimit()
    if #cache.order > limit * 3 then
        local compact = {}
        for cachedKey in pairs(cache.map) do
            compact[#compact + 1] = cachedKey
        end
        table.sort(compact, function(a, b)
            return (cache.map[a].stamp or 0) > (cache.map[b].stamp or 0)
        end)
        for i = limit + 1, #compact do
            cache.map[compact[i]] = nil
        end
        wipe(cache.order)
        for i = 1, math.min(limit, #compact) do
            cache.order[i] = compact[i]
        end
    end
    return value
end

local function EA_GetStorageCache(kind, key, raw)
    local cache = EA_STORAGE_CACHE[kind]
    local entry = cache and cache.map[key]
    if entry and entry.raw == raw then
        EA_STORAGE_CACHE_TICK = EA_STORAGE_CACHE_TICK + 1
        entry.stamp = EA_STORAGE_CACHE_TICK
        return entry.value
    end
    return nil
end

-- 价格库列表脏标记：数据写入/删除、搜索或排序变化时置脏（用全局避免触及主 chunk 局部变量上限）
EA_DBItemListDirty = true
function EA_MarkDBItemListDirty()
    EA_DBItemListDirty = true
end

-- 校验存储 key 的物品名部分（冒号前，无冒号时为整个 key），空名禁止入库
function EA_IsValidStorageKey(key)
    if type(key) ~= "string" or key == "" then return false end
    local namePart = key:match("^(.-):") or key
    return namePart ~= ""
end

local function EA_ParseNumber(value)
    local n = tonumber(value)
    return n and math.floor(n + 0.5) or nil
end

local function EA_ParsePositiveTimestamp(value)
    local n = EA_ParseNumber(value)
    return n and n > 0 and n or nil
end

local function EA_DateStringFromTimestamp(value)
    local t = EA_ParsePositiveTimestamp(value)
    return t and date("%Y-%m-%d", t) or nil
end

local function EA_NormalizePriceRecord(rec, fallbackTime)
    if type(rec) ~= "table" then return nil end
    local unit = EA_ParseNumber(rec.unit or rec.price or rec[2] or rec[1])
    local count = EA_ParseNumber(rec.count or rec.num or rec[3] or rec[2]) or 1
    local t = EA_ParseNumber(rec.t or rec.time or rec[4] or rec[3] or fallbackTime) or time()
    if not unit or unit <= 0 then return nil end
    if count <= 0 then count = 1 end
    return { unit = unit, count = count, t = t }
end

local function EA_NormalizePriceHistory(raw)
    local records = {}
    local minUnit = nil
    local latestTime = nil
    if type(raw) == "table" then
        for _, rec in ipairs(raw) do
            local normalized = EA_NormalizePriceRecord(rec, raw.lastScanT)
            if normalized then
                records[#records + 1] = normalized
                if not minUnit or normalized.unit < minUnit then minUnit = normalized.unit end
                if not latestTime or normalized.t > latestTime then latestTime = normalized.t end
            end
        end
        records.minUnit = EA_ParseNumber(raw.minUnit) or minUnit
        records.lastScanT = EA_ParseNumber(raw.lastScanT) or latestTime
    end
    return records
end

local function EA_DecodePriceHistoryString(raw)
    local minText, lastText, body = raw:match("^PH2|([^|]*)|([^|]*)|(.*)$")
    if not minText then return {} end
    local records = {}
    local minUnit = EA_ParseNumber(minText)
    local latestTime = EA_ParseNumber(lastText)
    for unitText, countText, timeText in tostring(body or ""):gmatch("([^,;]+),([^,;]+),([^;]+)") do
        local unit = EA_ParseNumber(unitText)
        local count = EA_ParseNumber(countText) or 1
        local t = EA_ParseNumber(timeText) or latestTime or time()
        if unit and unit > 0 then
            records[#records + 1] = { unit = unit, count = math.max(1, count), t = t }
            if not minUnit or unit < minUnit then minUnit = unit end
            if not latestTime or t > latestTime then latestTime = t end
        end
    end
    records.minUnit = minUnit
    records.lastScanT = latestTime
    return records
end

local function EA_EncodePriceHistory(records, minUnit, lastScanT)
    local out = {}
    local minVal = EA_ParseNumber(minUnit)
    local lastVal = EA_ParseNumber(lastScanT)
    for _, rec in ipairs(records or {}) do
        local normalized = EA_NormalizePriceRecord(rec, lastVal)
        if normalized then
            out[#out + 1] = table.concat({ normalized.unit, normalized.count, normalized.t }, ",")
            if not minVal or normalized.unit < minVal then minVal = normalized.unit end
            if not lastVal or normalized.t > lastVal then lastVal = normalized.t end
        end
    end
    if #out == 0 and (not minVal or minVal <= 0) then
        return nil
    end
    return "PH2|" .. tostring(minVal or 0) .. "|" .. tostring(lastVal or time()) .. "|" .. table.concat(out, ";")
end

local function EA_NormalizeDailyRecord(rec)
    if type(rec) ~= "table" then return nil end
    local day = rec[1] or rec.day
    local minUnit = EA_ParseNumber(rec[2] or rec.unit or rec.minUnit)
    if type(day) ~= "string" or not minUnit or minUnit <= 0 then return nil end
    return {
        day,
        minUnit,
        EA_ParseNumber(rec[3] or rec.count or rec.minCount) or 0,
        EA_ParseNumber(rec[4] or rec.lowUnit) or minUnit,
        EA_ParseNumber(rec[5] or rec.highUnit) or minUnit,
        EA_ParseNumber(rec[6] or rec.totalCount) or 0,
    }
end

local function EA_DecodeDailyString(raw)
    local body = raw:match("^DM2|(.*)$")
    if not body then return {} end
    local records = {}
    for day, unitText, countText, lowText, highText, totalText in body:gmatch("([^,;]+),([^,;]+),([^,;]+),([^,;]+),([^,;]+),([^;]+)") do
        local unit = EA_ParseNumber(unitText)
        if type(day) == "string" and unit and unit > 0 then
            records[#records + 1] = {
                day,
                unit,
                EA_ParseNumber(countText) or 0,
                EA_ParseNumber(lowText) or unit,
                EA_ParseNumber(highText) or unit,
                EA_ParseNumber(totalText) or 0,
            }
        end
    end
    return records
end

local function EA_EncodeDailyRecords(records)
    local out = {}
    for _, rec in ipairs(records or {}) do
        local normalized = EA_NormalizeDailyRecord(rec)
        if normalized then
            out[#out + 1] = table.concat(normalized, ",")
        end
    end
    if #out == 0 then return nil end
    return "DM2|" .. table.concat(out, ";")
end

local function EA_NormalizeHourlyRecord(rec)
    if type(rec) ~= "table" then return nil end
    local hour = EA_ParseNumber(rec[1] or rec.hour)
    local unit = EA_ParseNumber(rec[2] or rec.unit or rec.minUnit)
    if not hour or hour < 0 or hour > 23 or not unit or unit <= 0 then return nil end
    local storedAt = EA_ParsePositiveTimestamp(rec[5] or rec.t or rec.time or rec.storedAt)
    return {
        hour,
        unit,
        EA_ParseNumber(rec[3] or rec.count or rec.minCount) or 0,
        EA_ParseNumber(rec[4] or rec.totalCount) or EA_ParseNumber(rec[3] or rec.count) or 0,
        storedAt,
    }
end

local function EA_DecodeHourlyString(raw)
    local body = raw:match("^HM2|(.*)$")
    if not body then return {} end
    local records = {}
    for hourText, unitText, countText, totalText, timeText in body:gmatch("([^,;]+),([^,;]+),([^,;]+),([^,;]+),([^;]+)") do
        local hour = EA_ParseNumber(hourText)
        local unit = EA_ParseNumber(unitText)
        if hour and hour >= 0 and hour <= 23 and unit and unit > 0 then
            records[#records + 1] = {
                hour,
                unit,
                EA_ParseNumber(countText) or 0,
                EA_ParseNumber(totalText) or 0,
                EA_ParsePositiveTimestamp(timeText),
            }
        end
    end
    return records
end

local function EA_EncodeHourlyRecords(records)
    local out = {}
    for _, rec in ipairs(records or {}) do
        local normalized = EA_NormalizeHourlyRecord(rec)
        if normalized then
            out[#out + 1] = table.concat({
                normalized[1],
                normalized[2],
                normalized[3],
                normalized[4],
                normalized[5] or 0,
            }, ",")
        end
    end
    if #out == 0 then return nil end
    return "HM2|" .. table.concat(out, ";")
end

function EasyAuction_GetPriceHistory(key, db)
    db = db or EA_GetRuntimeDB()
    local raw = db and db.PriceHistory and db.PriceHistory[key]
    if not raw then return {} end
    local cached = EA_GetStorageCache("price", key, raw)
    if cached then return cached end
    local records
    if EA_IsEncodedStorageValue(raw, "PH2|") then
        records = EA_DecodePriceHistoryString(raw)
    else
        records = EA_NormalizePriceHistory(raw)
    end
    return EA_TouchStorageCache("price", key, raw, records)
end

function EasyAuction_GetPriceHistoryMinUnit(key, db)
    db = db or EA_GetRuntimeDB()
    local raw = db and db.PriceHistory and db.PriceHistory[key]
    if type(raw) == "string" then
        local minText = raw:match("^PH2|([^|]*)|")
        return EA_ParseNumber(minText)
    elseif type(raw) == "table" then
        return EA_ParseNumber(raw.minUnit) or (EasyAuction_GetPriceHistory(key, db).minUnit)
    end
    return nil
end

function EasyAuction_GetDailyMinPrice(key, db)
    db = db or EA_GetRuntimeDB()
    local raw = db and db.DailyMinPrice and db.DailyMinPrice[key]
    if not raw then return {} end
    local cached = EA_GetStorageCache("daily", key, raw)
    if cached then return cached end
    local records
    if EA_IsEncodedStorageValue(raw, "DM2|") then
        records = EA_DecodeDailyString(raw)
    else
        records = {}
        for _, rec in ipairs(type(raw) == "table" and raw or {}) do
            local normalized = EA_NormalizeDailyRecord(rec)
            if normalized then records[#records + 1] = normalized end
        end
    end
    return EA_TouchStorageCache("daily", key, raw, records)
end

function EasyAuction_GetHourlyMinPrice(key, db)
    db = db or EA_GetRuntimeDB()
    local raw = db and db.HourlyMinPrice and db.HourlyMinPrice[key]
    if not raw then return {} end
    local cached = EA_GetStorageCache("hourly", key, raw)
    if cached then return cached end
    local records
    if EA_IsEncodedStorageValue(raw, "HM2|") then
        records = EA_DecodeHourlyString(raw)
    else
        records = {}
        for _, rec in ipairs(type(raw) == "table" and raw or {}) do
            local normalized = EA_NormalizeHourlyRecord(rec)
            if normalized then records[#records + 1] = normalized end
        end
    end
    return EA_TouchStorageCache("hourly", key, raw, records)
end

function EasyAuction_SetPriceHistory(key, records, minUnit, lastScanT, db)
    db = db or EA_GetRuntimeDB()
    if not db or not EA_IsValidStorageKey(key) then return end
    db.PriceHistory = db.PriceHistory or {}
    local encoded = EA_EncodePriceHistory(records, minUnit, lastScanT)
    if encoded then
        if EA_PriceHistoryKeyCount and db == EA_PriceHistoryKeyCountDB and db.PriceHistory[key] == nil then
            EA_PriceHistoryKeyCount = EA_PriceHistoryKeyCount + 1
        end
        db.PriceHistory[key] = encoded
        if EA_UpdateItemIDIndexForKey then
            EA_UpdateItemIDIndexForKey(key, EasyAuction_GetPriceHistoryMinUnit(key, db))
        end
    else
        if EA_PriceHistoryKeyCount and db == EA_PriceHistoryKeyCountDB and db.PriceHistory[key] ~= nil then
            EA_PriceHistoryKeyCount = EA_PriceHistoryKeyCount - 1
        end
        db.PriceHistory[key] = nil
        if EA_RemoveItemIDIndexForKey then EA_RemoveItemIDIndexForKey(key) end
    end
    EA_ClearStorageCache("price", key)
    EA_MarkDBItemListDirty()
end

function EasyAuction_SetDailyMinPrice(key, records, db)
    db = db or EA_GetRuntimeDB()
    if not db or not EA_IsValidStorageKey(key) then return end
    db.DailyMinPrice = db.DailyMinPrice or {}
    local encoded = EA_EncodeDailyRecords(records)
    db.DailyMinPrice[key] = encoded
    EA_ClearStorageCache("daily", key)
    EA_MarkDBItemListDirty()
end

function EasyAuction_SetHourlyMinPrice(key, records, db)
    db = db or EA_GetRuntimeDB()
    if not db or not EA_IsValidStorageKey(key) then return end
    db.HourlyMinPrice = db.HourlyMinPrice or {}
    local encoded = EA_EncodeHourlyRecords(records)
    db.HourlyMinPrice[key] = encoded
    EA_ClearStorageCache("hourly", key)
end

local function EA_DeleteStorageKey(db, field, kind, key)
    local existed = db and db[field] and db[field][key] ~= nil
    if db and db[field] then db[field][key] = nil end
    EA_ClearStorageCache(kind, key)
    if existed and field == "PriceHistory" then
        if EA_PriceHistoryKeyCount and db == EA_PriceHistoryKeyCountDB then
            EA_PriceHistoryKeyCount = EA_PriceHistoryKeyCount - 1
        end
        if EA_RemoveItemIDIndexForKey then
            EA_RemoveItemIDIndexForKey(key)
        end
    end
    if existed then EA_MarkDBItemListDirty() end
end

local function EA_AddOrUpdateHourlyRecord(records, hour, minUnit, minCount, totalCount, storedAt)
    local normalizedHour = EA_ParseNumber(hour)
    if not normalizedHour then return records end
    storedAt = EA_ParsePositiveTimestamp(storedAt)
    records = records or {}
    for _, record in ipairs(records) do
        if record[1] == normalizedHour then
            record[2] = minUnit
            record[3] = minCount or record[3] or 0
            record[4] = totalCount or record[4] or record[3] or 0
            record[5] = storedAt or EA_ParsePositiveTimestamp(record[5])
            return records
        end
    end
    records[#records + 1] = { normalizedHour, minUnit, minCount or 0, totalCount or 0, storedAt }
    return records
end

local function EA_AddOrUpdateDailyRecord(records, day, minUnit, minCount, lowUnit, highUnit, totalCount)
    if type(day) ~= "string" then return records end
    records = records or {}
    for _, record in ipairs(records) do
        if record[1] == day then
            record[2] = minUnit
            record[3] = minCount or record[3] or 0
            local low = lowUnit or minUnit or record[4]
            local high = highUnit or minUnit or record[5]
            if low and record[4] then
                record[4] = math.min(record[4], low)
            else
                record[4] = low
            end
            if high and record[5] then
                record[5] = math.max(record[5], high)
            else
                record[5] = high
            end
            record[6] = totalCount or record[6] or 0
            return records
        end
    end
    records[#records + 1] = { day, minUnit, minCount or 0, lowUnit or minUnit, highUnit or minUnit, totalCount or 0 }
    return records
end

local function EA_TrimOperationHistory(db)
    local ops = db and db.OperationHistory
    if type(ops) ~= "table" then return 0 end
    table.sort(ops, function(a, b) return (a.time or 0) > (b.time or 0) end)
    local removed = 0
    for i = #ops, 501, -1 do
        ops[i] = nil
        removed = removed + 1
    end
    return removed
end

-- 获取当前服务器-阵营的键名
local function GetRealmFactionKey()
    local realm = GetRealmName() or "Unknown"
    local _, faction = UnitFactionGroup("player")
    faction = faction or "Neutral"
    return realm .. "-" .. faction
end

-- 初始化当前服务器-阵营的数据库
local function InitEasyAuctionDB()
    local key = GetRealmFactionKey()
    
    -- 如果新数据库中不存在当前服务器-阵营的数据，则创建
    if not EasyAuctionDB2[key] then
        EasyAuctionDB2[key] = {}
    end
    
    -- 设置局部变量 EasyAuctionDB 指向当前服务器-阵营的数据
    EasyAuctionDB = EasyAuctionDB2[key]
    
    -- 向后兼容：如果旧数据库有数据且新数据库为空，则迁移数据
    local oldDB = _G.EasyAuctionDB
    if oldDB and next(oldDB) ~= nil then
        -- 检查是否已有价格历史数据
        if not EasyAuctionDB.PriceHistory or next(EasyAuctionDB.PriceHistory) == nil then
            if oldDB.PriceHistory and next(oldDB.PriceHistory) ~= nil then
                EasyAuctionDB.PriceHistory = oldDB.PriceHistory
            end
        end
        if not EasyAuctionDB.DailyMinPrice or next(EasyAuctionDB.DailyMinPrice) == nil then
            if oldDB.DailyMinPrice and next(oldDB.DailyMinPrice) ~= nil then
                EasyAuctionDB.DailyMinPrice = oldDB.DailyMinPrice
            end
        end
        if not EasyAuctionDB.FavoriteItems or next(EasyAuctionDB.FavoriteItems) == nil then
            if oldDB.FavoriteItems and next(oldDB.FavoriteItems) ~= nil then
                EasyAuctionDB.FavoriteItems = oldDB.FavoriteItems
            end
        end
        if not EasyAuctionDB.RecentSearch or #EasyAuctionDB.RecentSearch == 0 then
            if oldDB.RecentSearch and #oldDB.RecentSearch > 0 then
                EasyAuctionDB.RecentSearch = oldDB.RecentSearch
            end
        end
        -- 迁移其他设置
        EA_AssignIfNil(EasyAuctionDB, "CustomHistoryPage", oldDB.CustomHistoryPage)
        EA_AssignIfNil(EasyAuctionDB, "scanPerFrame", oldDB.scanPerFrame)
        EA_AssignIfNil(EasyAuctionDB, "undercutMode", oldDB.undercutMode)
        EA_AssignIfNil(EasyAuctionDB, "showSections", oldDB.showSections)
        EA_AssignIfNil(EasyAuctionDB, "ShowPrice", oldDB.ShowPrice)
        EA_AssignIfNil(EasyAuctionDB, "enablePrice", oldDB.enablePrice)
        EA_AssignIfNil(EasyAuctionDB, "enableDisenchant", oldDB.enableDisenchant)
        EA_AssignIfNil(EasyAuctionDB, "enableProspect", oldDB.enableProspect)
        EA_AssignIfNil(EasyAuctionDB, "enableMill", oldDB.enableMill)
        EA_AssignIfNil(EasyAuctionDB, "enableTitanValue", oldDB.enableTitanValue)
        EA_AssignIfNil(EasyAuctionDB, "showUnitPrice", oldDB.showUnitPrice)
        EA_AssignIfNil(EasyAuctionDB, "enableUndercut", oldDB.enableUndercut)
        EA_AssignIfNil(EasyAuctionDB, "hideSellPrice", oldDB.hideSellPrice)
        EA_AssignIfNil(EasyAuctionDB, "enableDisenchantProb", oldDB.enableDisenchantProb)
        EA_AssignIfNil(EasyAuctionDB, "autoFillLastAuction", oldDB.autoFillLastAuction)
        EA_AssignIfNil(EasyAuctionDB, "enableAuctionListCopy", oldDB.enableAuctionListCopy)
        EA_AssignIfNil(EasyAuctionDB, "enableBrowseBuyButton", oldDB.enableBrowseBuyButton)
        EA_AssignIfNil(EasyAuctionDB, "enableBrowseBidButton", oldDB.enableBrowseBidButton)
        EA_AssignIfNil(EasyAuctionDB, "enableSearchBoxProtection", oldDB.enableSearchBoxProtection)
        EA_AssignIfNil(EasyAuctionDB, "VendorPrice", oldDB.VendorPrice)
        EA_AssignIfNil(EasyAuctionDB, "bidDiscount", oldDB.bidDiscount)
        EA_AssignIfNil(EasyAuctionDB, "undercut", oldDB.undercut)
        EA_AssignIfNil(EasyAuctionDB, "stackCount", oldDB.stackCount)
        EA_AssignIfNil(EasyAuctionDB, "defaultNumStacks", oldDB.defaultNumStacks)
        EA_AssignIfNil(EasyAuctionDB, "auctionDuration", oldDB.auctionDuration)
        EA_AssignIfNil(EasyAuctionDB, "buyRiskLimit", oldDB.buyRiskLimit)
        EA_AssignIfNil(EasyAuctionDB, "SnipeList", oldDB.SnipeList)
        EA_AssignIfNil(EasyAuctionDB, "BidDiscountRatio", oldDB.BidDiscountRatio)
        EA_AssignIfNil(EasyAuctionDB, "SnipeCheckDisenchant", oldDB.SnipeCheckDisenchant)
        EA_AssignIfNil(EasyAuctionDB, "SnipeCheckVendor", oldDB.SnipeCheckVendor)
        EA_AssignIfNil(EasyAuctionDB, "scanQuickLimit", oldDB.scanQuickLimit)
        EA_AssignIfNil(EasyAuctionDB, "historyKeepDays", oldDB.historyKeepDays)
        EA_AssignIfNil(EasyAuctionDB, "historyMaxEntry", oldDB.historyMaxEntry)
        EA_AssignIfNil(EasyAuctionDB, "scanKeepPerItem", oldDB.scanKeepPerItem)
        EA_AssignIfNil(EasyAuctionDB, "dailyKeepDays", oldDB.dailyKeepDays)
        EA_AssignIfNil(EasyAuctionDB, "hourlyKeepHours", oldDB.hourlyKeepHours)
        EA_AssignIfNil(EasyAuctionDB, "ShowMinPrice", oldDB.ShowMinPrice)
        EA_AssignIfNil(EasyAuctionDB, "enableVendor", oldDB.enableVendor)
        EA_AssignIfNil(EasyAuctionDB, "SellPanel", oldDB.SellPanel)
        EA_AssignIfNil(EasyAuctionDB, "minimap", oldDB.minimap)
        EA_AssignIfNil(EasyAuctionDB, "OperationHistory", oldDB.OperationHistory)
        EA_AssignIfNil(EasyAuctionDB, "CategoryOverrides", oldDB.CategoryOverrides)
        EA_AssignIfNil(EasyAuctionDB, "AddonBackup", oldDB.AddonBackup)
        EA_AssignIfNil(EasyAuctionDB, "MinimalModeActive", oldDB.MinimalModeActive)
        EA_AssignIfNil(EasyAuctionDB, "uiPalette", oldDB.uiPalette)
        EA_AssignIfNil(EasyAuctionDB, "playerGoldDay", oldDB.playerGoldDay)
        EA_AssignIfNil(EasyAuctionDB, "playerGoldToday", oldDB.playerGoldToday)
        EA_AssignIfNil(EasyAuctionDB, "playerGoldYesterday", oldDB.playerGoldYesterday)
        EA_AssignIfNil(EasyAuctionDB, "GoldHistory", oldDB.GoldHistory)
        EA_AssignIfNil(EasyAuctionDB, "GoldHourlyHistory", oldDB.GoldHourlyHistory)
    end
    
    -- 设置默认值
    EasyAuctionDB.PriceHistory = EasyAuctionDB.PriceHistory or {}
    EasyAuctionDB.DailyMinPrice = EasyAuctionDB.DailyMinPrice or {}
    EasyAuctionDB.HourlyMinPrice = EasyAuctionDB.HourlyMinPrice or {}
    EasyAuctionDB.uiPalette = EasyAuctionDB.uiPalette or "blizzard"
    EasyAuctionDB.playerGoldDay = EasyAuctionDB.playerGoldDay or date("%Y-%m-%d")
    EasyAuctionDB.playerGoldToday = tonumber(EasyAuctionDB.playerGoldToday) or (type(GetMoney) == "function" and GetMoney() or 0)
    EasyAuctionDB.playerGoldYesterday = tonumber(EasyAuctionDB.playerGoldYesterday) or EasyAuctionDB.playerGoldToday
    EasyAuctionDB.GoldHistory = EasyAuctionDB.GoldHistory or {}
    EasyAuctionDB.GoldHourlyHistory = EasyAuctionDB.GoldHourlyHistory or {}
    EasyAuctionDB.CustomHistoryPage = EasyAuctionDB.CustomHistoryPage or 1
    EasyAuctionDB.scanPerFrame = EA_ClampInt(EasyAuctionDB.scanPerFrame or 200, 200, 50, 500)
    EasyAuctionDB.scanKeepPerItem = EA_ClampInt(EasyAuctionDB.scanKeepPerItem or 120, 120, 20, 500)
    EasyAuctionDB.historyKeepDays = EA_ClampInt(EasyAuctionDB.historyKeepDays or 30, 30, 1, 365)
    EasyAuctionDB.historyMaxEntry = EA_ClampInt(EasyAuctionDB.historyMaxEntry or 0, 0, 0, 2000)
    EasyAuctionDB.dailyKeepDays = EA_ClampInt(
        EasyAuctionDB.dailyKeepDays or EasyAuctionDB.historyKeepDays or 30,
        EasyAuctionDB.historyKeepDays or 30,
        1,
        365
    )
    -- HourlyMinPrice 当前结构仅按小时(0-23)聚合，最多保留 24 小时窗口。
    EasyAuctionDB.hourlyKeepHours = EA_ClampInt(EasyAuctionDB.hourlyKeepHours or 24, 24, 1, 24)
    EasyAuctionDB.LastSelectedPriceInfo = nil
    EasyAuctionDB.CurrentDistItemName = nil
    EasyAuctionDB.CurrentDistData = nil
    EasyAuctionDB.undercutMode = EasyAuctionDB.undercutMode or "total"
    EasyAuctionDB.showSections = EasyAuctionDB.showSections or { items = true, price = true, myauct = true }
    EasyAuctionDB.RecentSearch = EasyAuctionDB.RecentSearch or {}
    EasyAuctionDB.FavoriteItems = EasyAuctionDB.FavoriteItems or {}
    EasyAuctionDB.CategoryOverrides = EasyAuctionDB.CategoryOverrides or {}
    
    if EasyAuctionDB.ShowPrice == nil then EasyAuctionDB.ShowPrice = true end
    if EasyAuctionDB.enablePrice == nil then EasyAuctionDB.enablePrice = true end
    if EasyAuctionDB.enableDisenchant == nil then EasyAuctionDB.enableDisenchant = true end
    if EasyAuctionDB.enableProspect == nil then EasyAuctionDB.enableProspect = true end
    if EasyAuctionDB.enableMill == nil then EasyAuctionDB.enableMill = true end
    if EasyAuctionDB.enableTitanValue == nil then EasyAuctionDB.enableTitanValue = true end
    if EasyAuctionDB.showUnitPrice == nil then EasyAuctionDB.showUnitPrice = true end
    if EasyAuctionDB.enableUndercut == nil then EasyAuctionDB.enableUndercut = true end
    if EasyAuctionDB.undercutMode ~= "unit" then EasyAuctionDB.undercutMode = "total" end
    if EasyAuctionDB.hideSellPrice == nil then EasyAuctionDB.hideSellPrice = false end
    if EasyAuctionDB.enableDisenchantProb == nil then EasyAuctionDB.enableDisenchantProb = true end
    if EasyAuctionDB.MinimalModeActive == nil and type(EasyAuctionDB.AddonBackup) ~= "table" then
        EasyAuctionDB.MinimalModeActive = false
    end
    
    EasyAuctionDB.autoFillLastAuction =
        EasyAuctionDB.autoFillLastAuction == nil and false or EasyAuctionDB.autoFillLastAuction
    EasyAuctionDB.enableAuctionListCopy =
        EasyAuctionDB.enableAuctionListCopy == nil and true or EasyAuctionDB.enableAuctionListCopy
    EasyAuctionDB.enableBrowseBuyButton =
        EasyAuctionDB.enableBrowseBuyButton == nil and true or EasyAuctionDB.enableBrowseBuyButton
    EasyAuctionDB.enableBrowseBidButton =
        EasyAuctionDB.enableBrowseBidButton == nil and true or EasyAuctionDB.enableBrowseBidButton
    EasyAuctionDB.enableSearchBoxProtection =
        EasyAuctionDB.enableSearchBoxProtection == nil and true or EasyAuctionDB.enableSearchBoxProtection
    EasyAuctionDB.VendorPrice = EasyAuctionDB.VendorPrice or {}
    -- 更新全局引用（用于兼容其他可能的访问）
    _G.EasyAuctionDB = EasyAuctionDB
    if type(EasyAuction_RebindFrameDB) == "function" then
        EasyAuction_RebindFrameDB()
    end
    C_Timer.After(1, function()
        if type(EasyAuction_MigrateStorageV2) == "function" then EasyAuction_MigrateStorageV2() end
    end)
    C_Timer.After(10, function() EasyAuction_RunDailyCleanup(false) end)
    if oldDB and oldDB ~= EasyAuctionDB then
        -- 旧结构可能是大表，尽早释放引用，降低登录后常驻压力。
        oldDB = nil
        collectgarbage("collect")
    end
    
    return EasyAuctionDB
end

IsScanningAll = false
IsScanningCategory = false
local EasyAuctionScanProgressFrame = nil
EasyAuction_ItemID_Index = {}
EA_UpdateItemIDIndexForKey = function(key, minUnit)
    if type(key) ~= "string" or key == "" then return end
    local matchID = key:match(":(%d+)$")
    local itemid = tonumber(matchID)
    if not itemid then return end

    local entries = EasyAuction_ItemID_Index[itemid]
    if not entries then
        entries = {}
        EasyAuction_ItemID_Index[itemid] = entries
    end

    for i = 1, #entries do
        local entry = entries[i]
        if entry and entry.key == key then
            entry.minUnit = minUnit
            return
        end
    end

    entries[#entries + 1] = {
        key = key,
        minUnit = minUnit,
    }
end

EA_RemoveItemIDIndexForKey = function(key)
    if type(key) ~= "string" or key == "" then return end
    local matchID = key:match(":(%d+)$")
    local itemid = tonumber(matchID)
    if not itemid then return end

    local entries = EasyAuction_ItemID_Index[itemid]
    if not entries then return end
    for i = #entries, 1, -1 do
        local entry = entries[i]
        if entry and entry.key == key then
            table.remove(entries, i)
        end
    end
    if #entries == 0 then
        EasyAuction_ItemID_Index[itemid] = nil
    end
end

local function BuildItemIDIndex()
    wipe(EasyAuction_ItemID_Index)
    for key in pairs(EasyAuctionDB.PriceHistory or {}) do
        local minUnit = EasyAuction_GetPriceHistoryMinUnit(key, EasyAuctionDB)
        EA_UpdateItemIDIndexForKey(key, minUnit)
    end
end

local function EasyAuction_CreateDefaultDB()
    return {
        bidDiscount = 0.99,
        undercut = 1,
        stackCount = 20,
        defaultNumStacks = 1,
        auctionDuration = 1,
        showSections = { items = true, price = true, myauct = true },
        buyRiskLimit = 500,
        scanPerFrame = 200,
        scanKeepPerItem = 120,
        historyKeepDays = 30,
        historyMaxEntry = 0,
        dailyKeepDays = 30,
        hourlyKeepHours = 24,
        uiScale = 1.0,
        layoutMigrationVersion = 4,
        uiPalette = "blizzard",
        playerGoldDay = date("%Y-%m-%d"),
        playerGoldToday = type(GetMoney) == "function" and GetMoney() or 0,
        playerGoldYesterday = type(GetMoney) == "function" and GetMoney() or 0,
        GoldHistory = {},
        GoldHourlyHistory = {},
        scanQuickLimit = 100,
        PriceHistory = {},
        DailyMinPrice = {},
        HourlyMinPrice = {},
        CurrentTodayMin = {},
        FavoriteItems = {},
        RecentSearch = {},
        SnipeList = {},
        BidDiscountRatio = 0.95,
        SnipeCheckDisenchant = true,
        SnipeCheckVendor = true,
        VendorPrice = {},
        OperationHistory = {},
        CategoryOverrides = {},
        minimap = {},
        autoFillLastAuction = false,
        enableAuctionListCopy = true,
        enableBrowseBuyButton = true,
        enableBrowseBidButton = true,
        enableSearchBoxProtection = true,
        CustomHistoryPage = 1,
        MinimalModeActive = false,
        dbResetPromptVersion = ns.EA_DB_RESET_PROMPT_VERSION,
    }
end

-- resetAllRealms=true 时清空 EasyAuctionDB2 下所有服务器-阵营数据。
function ns.EA_CanResetSavedVariables()
    local mail = ns.Mail
    local arbiter = mail and mail.WriteArbiter
    if arbiter and type(arbiter.CanResetDatabase) == "function" then
        return arbiter:CanResetDatabase()
    end
    local owner = arbiter and type(arbiter.GetOwner) == "function" and arbiter:GetOwner() or nil
    if owner then
        local errorObject = mail and type(mail.NewError) == "function"
            and mail:NewError("MAIL_WRITE_BUSY", "当前有邮件操作正在进行，请等待操作结束后再重置插件。", owner)
            or { code = "MAIL_WRITE_BUSY", message = "当前有邮件操作正在进行，请等待操作结束后再重置插件。", detail = owner }
        return nil, errorObject
    end
    return true
end

function EasyAuction_ResetSavedVariables(resetAllRealms)
    local allowed, resetError = ns.EA_CanResetSavedVariables()
    if not allowed then return nil, resetError end
    local key = GetRealmFactionKey()
    EasyAuctionDB2 = type(EasyAuctionDB2) == "table" and EasyAuctionDB2 or {}
    if resetAllRealms then
        wipe(EasyAuctionDB2)
    end

    local newDB = EasyAuction_CreateDefaultDB()
    newDB.dbResetPromptVersion = ns.EA_DB_RESET_PROMPT_VERSION
    EasyAuctionDB2[key] = newDB
    EasyAuctionDB2.__DBResetPromptVersion = ns.EA_DB_RESET_PROMPT_VERSION
    EasyAuctionDB = newDB
    _G.EasyAuctionDB2 = EasyAuctionDB2
    _G.EasyAuctionDB = newDB
    EA_MarkDBItemListDirty()

    if type(EasyAuction_RebindFrameDB) == "function" then
        EasyAuction_RebindFrameDB()
    end

    wipe(EasyAuction_ItemID_Index)
    return newDB
end

local function EA_ContinueAfterDBResetPrompt(owner)
    local DB = InitEasyAuctionDB()
    if not DB then return nil end
    ns.EA_MarkDBResetPromptDone()

    DB.minimap = DB.minimap or {}
    if DB.scanPerFrame < 50 then
        DB.scanPerFrame = 50
    elseif DB.scanPerFrame >= 500 then
        DB.scanPerFrame = 200
    end

    local LDB = LibStub("LibDataBroker-1.1", true)
    local LDBIcon = LibStub("LibDBIcon-1.0", true)
    if LDB and LDBIcon then
        local minimapName = "EasyAuction"
        local dataobj = LDB.GetDataObjectByName and LDB:GetDataObjectByName(minimapName)
        if not dataobj then
            dataobj = LDB:NewDataObject(minimapName, {})
        end
        dataobj.type = "data source"
        dataobj.text = "EasyAuction"
        dataobj.icon = "Interface\\Icons\\INV_Misc_Coin_01"
        dataobj.OnClick = function(self, button)
            if button == "LeftButton" then
                if EasyAuction_OpenDBFrame then
                    EasyAuction_OpenDBFrame()
                end
            elseif button == "RightButton" then
                if type(_G.EasyAuction_ToggleConfigFrame) == "function" then
                    _G.EasyAuction_ToggleConfigFrame()
                end
            end
        end
        dataobj.OnTooltipShow = function(tt)
            tt:AddLine("|cff00ff00EasyAuction 拍卖助手|r")
            tt:AddLine("|cffffff00左键|r 价格数据库")
            tt:AddLine("|cffffff00右键|r 插件设置")
        end

        if LDBIcon.IsRegistered and LDBIcon:IsRegistered(minimapName) then
            LDBIcon:Refresh(minimapName, DB.minimap)
        else
            LDBIcon:Register(minimapName, dataobj, DB.minimap)
        end
        if LDBIcon.GetMinimapButton then
            local minimapButton = LDBIcon:GetMinimapButton(minimapName)
            if minimapButton then
                minimapButton.dataObject = dataobj
            end
        end
    end
    print("|cff00ff00[EasyAuction]|r 拍卖行增强插件已加载，输入 |cff00ff00/epah|r 打开插件。")
    CheckShowUpdateNotes()
    BuildItemIDIndex()
    if owner and owner.UnregisterEvent then
        owner:UnregisterEvent("ADDON_LOADED")
    end
    return DB
end

StaticPopupDialogs["EASYAUCTION_DB_RESET_PROMPT"] = {
    text = "|cffff4040检测到旧版|r |cffffff00EasyAuction|r |cffff4040拍卖行历史数据|r\n\n"
        .. "继续使用旧数据，可能会|cffff4040导致插件报错|r。\n\n"
        .. "|cffffff00选择“重置”|r：清空历史数据和设置，并自动重载；插件会以全新状态运行，更稳定，但旧数据会丢失。\n\n"
        .. "|cffffff00选择“保留”|r：继续使用现有数据，之后不再提示；数据转换为新版格式，但仍可能报错。",
    button1 = "重置并重载",
    button2 = "保留现有数据",
    OnAccept = function()
        if type(EasyAuction_ResetSavedVariables) == "function" then
            local newDB, resetError = EasyAuction_ResetSavedVariables(true)
            if not newDB then
                print("|cffff4040EasyAuction|r：" .. tostring(resetError and resetError.message
                    or "当前无法重置插件。"))
                return
            end
        end
        ns.EA_MarkDBResetPromptDone()
        print("|cff00ff00[EasyAuction]|r 已重置数据库，正在重载界面。")
        if type(ReloadUI) == "function" then ReloadUI() end
    end,
    OnCancel = function(self, data)
        ns.EA_MarkDBResetPromptDone()
        if data and data.owner then
            EA_ContinueAfterDBResetPrompt(data.owner)
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = false,
    preferredIndex = 3,
}

function AddRecentSearch(itemID, name, price, t)
    if not itemID or not name then return end
    for i = #EasyAuctionDB.RecentSearch, 1, -1 do
        if EasyAuctionDB.RecentSearch[i].itemID == itemID then
            table.remove(EasyAuctionDB.RecentSearch, i)
        end
    end
    table.insert(EasyAuctionDB.RecentSearch, 1, { itemID = itemID, name = name, price = price, time = t or time() })
    while #EasyAuctionDB.RecentSearch > RECENT_MAX do table.remove(EasyAuctionDB.RecentSearch) end
end

function AddFavoriteItem(itemID, name, price, t)
    if not itemID or not name then return end
    EasyAuctionDB.FavoriteItems[itemID] = { name = name, price = price, time = t or time() }
    local count = 0
    for _ in pairs(EasyAuctionDB.FavoriteItems) do count = count + 1 end
    if count > FAVORITE_MAX then
        local oldestID, oldestTime
        for id, info in pairs(EasyAuctionDB.FavoriteItems) do
            if not oldestTime or (info.time or 0) < oldestTime then
                oldestID, oldestTime = id, info.time or 0
            end
        end
        if oldestID then EasyAuctionDB.FavoriteItems[oldestID] = nil end
    end
end

function EasyAuction_SaveGoldRecord()
    local db = _G.EasyAuctionDB
    if not db then return end
    local today = date("%Y-%m-%d")
    local hourKey = date("%Y-%m-%d %H:00")
    local money = type(GetMoney) == "function" and GetMoney() or 0
    local playerName = UnitName("player") or "Unknown"
    db.GoldHistory = db.GoldHistory or {}
    db.GoldHistory[playerName] = db.GoldHistory[playerName] or {}
    db.GoldHistory[playerName][today] = money
    db.GoldHourlyHistory = db.GoldHourlyHistory or {}
    db.GoldHourlyHistory[playerName] = db.GoldHourlyHistory[playerName] or {}
    db.GoldHourlyHistory[playerName][hourKey] = money
    local keepDays = 1095
    local cutoffTime = time() - keepDays * 86400
    for charName, charHistory in pairs(db.GoldHistory) do
        for dateStr in pairs(charHistory) do
            local y, m, d = dateStr:match("^(%d+)%-(%d+)%-(%d+)$")
            if y and m and d then
                local stamp = time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 0, min = 0, sec = 0 })
                if stamp and stamp < cutoffTime then
                    charHistory[dateStr] = nil
                end
            end
        end
    end
    local cutoffHourTime = time() - 72 * 3600
    for _, charHistory in pairs(db.GoldHourlyHistory) do
        for dateStr in pairs(charHistory) do
            local y, m, d, h = dateStr:match("^(%d+)%-(%d+)%-(%d+) (%d+):00$")
            if y and m and d and h then
                local stamp = time({
                    year = tonumber(y),
                    month = tonumber(m),
                    day = tonumber(d),
                    hour = tonumber(h),
                })
                if stamp and stamp < cutoffHourTime then
                    charHistory[dateStr] = nil
                end
            end
        end
    end
end

function EasyAuction_GetGoldHistory(days, charNames)
    local db = _G.EasyAuctionDB
    if not db or not db.GoldHistory then return {} end
    days = tonumber(days) or 30
    local result = {}
    local today = date("%Y-%m-%d")
    local y, m, d = today:match("^(%d+)%-(%d+)%-(%d+)$")
    if not y then return {} end
    local todayStamp = time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 0, min = 0, sec = 0 })

    local targetChars = {}
    if charNames and #charNames > 0 then
        for _, name in ipairs(charNames) do
            targetChars[name] = true
        end
    else
        for name in pairs(db.GoldHistory) do
            targetChars[name] = true
        end
    end

    local charSeries = {}
    for charName in pairs(targetChars) do
        local entries = {}
        for dateStr, money in pairs(db.GoldHistory[charName] or {}) do
            local ey, em, ed = dateStr:match("^(%d+)%-(%d+)%-(%d+)$")
            if ey and em and ed then
                local stamp = time({ year = tonumber(ey), month = tonumber(em), day = tonumber(ed), hour = 0, min = 0, sec = 0 })
                if stamp then
                    entries[#entries + 1] = { stamp = stamp, gold = tonumber(money) or 0 }
                end
            end
        end
        table.sort(entries, function(a, b) return a.stamp < b.stamp end)
        charSeries[charName] = { entries = entries, index = 1, gold = 0 }
    end

    for i = days - 1, 0, -1 do
        local stamp = todayStamp - i * 86400
        local dateStr = date("%Y-%m-%d", stamp)
        local totalGold = 0
        for _, series in pairs(charSeries) do
            while series.index <= #series.entries and series.entries[series.index].stamp <= stamp do
                series.gold = series.entries[series.index].gold
                series.index = series.index + 1
            end
            totalGold = totalGold + (series.gold or 0)
        end
        table.insert(result, { date = dateStr, gold = totalGold, time = stamp })
    end
    return result
end

function EasyAuction_GetGoldHourlyHistory(hours, charNames)
    local db = _G.EasyAuctionDB
    if not db then return {} end
    local dailyHistory = db.GoldHistory or {}
    local hourlyHistory = db.GoldHourlyHistory or {}
    hours = math.max(1, math.floor(tonumber(hours) or 24))
    local result = {}
    local now = time()
    local currentHour = time({
        year = tonumber(date("%Y", now)),
        month = tonumber(date("%m", now)),
        day = tonumber(date("%d", now)),
        hour = tonumber(date("%H", now)),
        min = 0,
        sec = 0,
    })

    local targetChars = {}
    if charNames and #charNames > 0 then
        for _, name in ipairs(charNames) do
            targetChars[name] = true
        end
    else
        for name in pairs(dailyHistory) do
            targetChars[name] = true
        end
        for name in pairs(hourlyHistory) do
            targetChars[name] = true
        end
    end

    local charSeries = {}
    for charName in pairs(targetChars) do
        local entries = {}
        for dateStr, money in pairs(dailyHistory[charName] or {}) do
            local ey, em, ed = dateStr:match("^(%d+)%-(%d+)%-(%d+)$")
            if ey and em and ed then
                local stamp = time({ year = tonumber(ey), month = tonumber(em), day = tonumber(ed), hour = 0, min = 0, sec = 0 })
                if stamp then
                    entries[#entries + 1] = { stamp = stamp, gold = tonumber(money) or 0, order = 1 }
                end
            end
        end
        for dateStr, money in pairs(hourlyHistory[charName] or {}) do
            local ey, em, ed, eh = dateStr:match("^(%d+)%-(%d+)%-(%d+) (%d+):00$")
            if ey and em and ed and eh then
                local stamp = time({
                    year = tonumber(ey),
                    month = tonumber(em),
                    day = tonumber(ed),
                    hour = tonumber(eh),
                    min = 0,
                    sec = 0,
                })
                if stamp then
                    entries[#entries + 1] = { stamp = stamp, gold = tonumber(money) or 0, order = 2 }
                end
            end
        end
        table.sort(entries, function(a, b)
            if a.stamp == b.stamp then
                return (a.order or 1) < (b.order or 1)
            end
            return a.stamp < b.stamp
        end)
        charSeries[charName] = { entries = entries, index = 1, gold = 0 }
    end

    for i = hours - 1, 0, -1 do
        local stamp = currentHour - i * 3600
        local totalGold = 0
        for _, series in pairs(charSeries) do
            while series.index <= #series.entries and series.entries[series.index].stamp <= stamp do
                series.gold = series.entries[series.index].gold
                series.index = series.index + 1
            end
            totalGold = totalGold + (series.gold or 0)
        end
        table.insert(result, {
            date = date("%m-%d %H:00", stamp),
            gold = totalGold,
            time = stamp,
        })
    end
    return result
end

function EasyAuction_GetAllGoldCharacters()
    local db = _G.EasyAuctionDB
    if not db then return {} end
    local seen = {}
    local chars = {}
    for name in pairs(db.GoldHistory or {}) do
        seen[name] = true
    end
    for name in pairs(db.GoldHourlyHistory or {}) do
        seen[name] = true
    end
    for name in pairs(seen) do
        chars[#chars + 1] = name
    end
    table.sort(chars)
    return chars
end

local EA_SCAN_CATEGORIES = { "矿石", "草药", "附魔", "珠宝", "布皮", "元素", "药剂", "鱼类", "常用" }
local EA_FULL_SCAN_COOLDOWN_SECONDS = 15 * 60
local EA_FULL_SCAN_FALLBACK_SECONDS = 90
local EA_LastFullScanQueryTime = nil
local EA_FullScanSnapshotActive = false
local EA_ActiveFullScanState = nil

local function EA_IsFullScanSnapshotActive()
    return EA_FullScanSnapshotActive == true
end

ns.EA_IsFullScanSnapshotActive = EA_IsFullScanSnapshotActive

local function EA_CancelActiveFullScan()
    local state = EA_ActiveFullScanState
    if not state then return end
    state.cancelled = true
    if state.eventFrame then
        state.eventFrame:UnregisterAllEvents()
        state.eventFrame:SetScript("OnEvent", nil)
        state.eventFrame = nil
    end
    local cleanup = state.cleanup
    state.cleanup = nil
    EA_ActiveFullScanState = nil
    if cleanup then cleanup() end
end

local function EA_GetFullScanCooldownRemaining()
    if not EA_LastFullScanQueryTime then return nil end
    local remaining = EA_FULL_SCAN_COOLDOWN_SECONDS - (GetTime() - EA_LastFullScanQueryTime)
    if remaining > 0 then
        return math.ceil(remaining)
    end
    return 0
end

local function EA_TrimText(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function EA_SanitizeCategoryEntry(name, itemID, titan)
    local cleanName = EA_TrimText(name)
    local cleanID = tonumber(itemID)
    local cleanTitan = math.max(0, math.floor(tonumber(titan) or 0))
    if cleanName == "" or not cleanID or cleanID <= 0 then
        return nil
    end
    return { cleanName, cleanID, cleanTitan }
end

local function EA_CopyCategoryEntries(entries)
    local copied = {}
    for _, info in ipairs(entries or {}) do
        local entry = EA_SanitizeCategoryEntry(info[1], info[2], info[3])
        if entry then
            copied[#copied + 1] = entry
        end
    end
    return copied
end

local function EA_GetCategoryOverrideStore()
    if not EasyAuctionDB then
        return {}
    end
    EasyAuctionDB.CategoryOverrides = EasyAuctionDB.CategoryOverrides or {}
    return EasyAuctionDB.CategoryOverrides
end

local function EA_GetFavoriteCategoryEntries()
    local entries = {}
    for itemID, info in pairs(EasyAuctionDB and EasyAuctionDB.FavoriteItems or {}) do
        local entry = EA_SanitizeCategoryEntry(info and info.name, itemID, info and info.titan)
        if entry then
            entry._time = info and info.time or 0
            entries[#entries + 1] = entry
        end
    end
    table.sort(entries, function(a, b)
        return (a._time or 0) > (b._time or 0)
    end)
    for _, info in ipairs(entries) do
        info._time = nil
    end
    return entries
end

local function EA_GetCategoryEntries(cat)
    if cat == "常用" then
        return EA_GetFavoriteCategoryEntries()
    end
    local overrides = EA_GetCategoryOverrideStore()
    if type(overrides[cat]) == "table" then
        return overrides[cat]
    end
    return ns.EA_CATEGORY_LIST[cat] or {}
end

local function EA_SetCategoryEntries(cat, entries)
    if not EasyAuctionDB then
        return
    end
    if cat == "常用" then
        local favorites = {}
        local now = time()
        for index, info in ipairs(entries or {}) do
            favorites[info[2]] = {
                name = info[1],
                titan = tonumber(info[3]) or 0,
                time = now - index,
            }
        end
        EasyAuctionDB.FavoriteItems = favorites
        return
    end
    local overrides = EA_GetCategoryOverrideStore()
    overrides[cat] = EA_CopyCategoryEntries(entries)
end

local function EA_ResetCategoryEntries(cat)
    if not EasyAuctionDB then
        return
    end
    if cat == "常用" then
        EasyAuctionDB.FavoriteItems = {}
        return
    end
    local overrides = EA_GetCategoryOverrideStore()
    overrides[cat] = nil
end

local function EA_GetCategoryTitanMap()
    local itemID2Titan = {}
    for _, cat in ipairs(EA_SCAN_CATEGORIES) do
        if cat ~= "常用" then
            for _, info in ipairs(EA_GetCategoryEntries(cat)) do
                local itemID = tonumber(info[2])
                local titan = tonumber(info[3])
                if itemID then
                    itemID2Titan[itemID] = titan
                end
            end
        end
    end
    return itemID2Titan
end

local function EA_GetHistoryStats(key)
    local history = EasyAuction_GetPriceHistory(key, EasyAuctionDB)
    local minUnit, latestTime, historyMin, snapshotCount = nil, nil, nil, 0
    if type(history) == "table" then
        historyMin = tonumber(history.minUnit)
        for _, rec in ipairs(history) do
            local unit = tonumber(rec and rec.unit)
            local count = tonumber(rec and rec.count) or 1
            local recTime = tonumber(rec and rec.t)
            if unit and (not minUnit or unit < minUnit) then
                minUnit = unit
            end
            if unit and (not historyMin or unit < historyMin) then
                historyMin = unit
            end
            if recTime and (not latestTime or recTime > latestTime) then
                latestTime = recTime
            end
            snapshotCount = snapshotCount + math.max(1, count)
        end
        latestTime = tonumber(history.lastScanT) or latestTime
    end

    local dailyData = EasyAuction_GetDailyMinPrice(key, EasyAuctionDB)
    if type(dailyData) == "table" then
        local today = date("%Y-%m-%d")
        for _, record in ipairs(dailyData) do
            if record[1] == today then
                snapshotCount = tonumber(record[6]) or snapshotCount
                break
            end
        end
    end

    return {
        minUnit = minUnit,
        latestTime = latestTime,
        historyMin = historyMin,
        snapshotCount = snapshotCount,
        history = history,
    }
end

-- 列表页轻量统计：只解析编码串头部与每日聚合，避免全记录解码
function EA_GetHistoryListStats(key)
    local db = EasyAuctionDB
    local raw = db and db.PriceHistory and db.PriceHistory[key]
    if type(raw) ~= "string" then
        return EA_GetHistoryStats(key)
    end
    local minText, lastText = raw:match("^PH2|([^|]*)|([^|]*)|")
    local minUnit = EA_ParseNumber(minText)
    if not minUnit then
        return EA_GetHistoryStats(key)
    end
    local latestTime = EA_ParseNumber(lastText)

    local snapshotCount = 0
    local todayCount = nil
    local dailyData = EasyAuction_GetDailyMinPrice(key, db)
    if type(dailyData) == "table" then
        local today = date("%Y-%m-%d")
        for _, record in ipairs(dailyData) do
            if record[1] == today then
                todayCount = tonumber(record[6])
                break
            end
        end
    end
    if todayCount then
        snapshotCount = todayCount
    else
        -- 无今日聚合时才需要全量解码统计快照数（口径与 EA_GetHistoryStats 一致）
        local history = EasyAuction_GetPriceHistory(key, db)
        for _, rec in ipairs(history) do
            snapshotCount = snapshotCount + math.max(1, tonumber(rec and rec.count) or 1)
        end
    end

    return {
        minUnit = minUnit,
        latestTime = latestTime,
        historyMin = minUnit,
        snapshotCount = snapshotCount,
        history = nil,
    }
end

local function EA_SaveAggregatedBuckets(batchData, scanTime)
    if not EasyAuctionDB then
        return 0, 0
    end
    EasyAuctionDB.PriceHistory = EasyAuctionDB.PriceHistory or {}
    EasyAuctionDB.HourlyMinPrice = EasyAuctionDB.HourlyMinPrice or {}
    EasyAuctionDB.DailyMinPrice = EasyAuctionDB.DailyMinPrice or {}

    local keepPerItem = EA_ClampInt(EasyAuctionDB.scanKeepPerItem or 120, 120, 20, 500)
    local hour = tonumber(date("%H"))
    local today = date("%Y-%m-%d")
    local storedAt = tonumber(scanTime) or time()
    local newCount, updateCount = 0, 0

    for key, bucket in pairs(batchData or {}) do
        local records = {}
        for _, rec in pairs(bucket.byUnit or {}) do
            records[#records + 1] = {
                unit = rec.unit,
                count = rec.count,
                t = tonumber(rec.t) or storedAt,
            }
        end

        local compressed = EA_CompressHistoryRecords(records, keepPerItem, nil)
        if type(compressed) == "table" and #compressed > 0 then
            if EasyAuctionDB.PriceHistory[key] then
                updateCount = updateCount + 1
            else
                newCount = newCount + 1
            end

            local minUnit = tonumber(bucket.minUnit) or tonumber(compressed[1] and compressed[1].unit) or 0
            local maxUnit = tonumber(bucket.maxUnit) or minUnit
            local minCount = tonumber(bucket.minCount) or 0
            local totalCount = tonumber(bucket.totalCount) or 0

            EasyAuction_SetPriceHistory(key, compressed, minUnit, storedAt, EasyAuctionDB)

            local hourlyRecords = EasyAuction_GetHourlyMinPrice(key, EasyAuctionDB)
            hourlyRecords = EA_AddOrUpdateHourlyRecord(hourlyRecords, hour, minUnit, minCount, totalCount, storedAt)
            EasyAuction_SetHourlyMinPrice(key, hourlyRecords, EasyAuctionDB)

            local dailyRecords = EasyAuction_GetDailyMinPrice(key, EasyAuctionDB)
            dailyRecords = EA_AddOrUpdateDailyRecord(dailyRecords, today, minUnit, minCount, minUnit, maxUnit, totalCount)
            EasyAuction_SetDailyMinPrice(key, dailyRecords, EasyAuctionDB)
        end
    end

    return newCount, updateCount
end

function EasyAuction_ShowDropdownMenu(menuTable, anchor, x, y)
    local function initialize(frame, level)
        level = level or 1
        local menu = menuTable
        if level > 1 and UIDROPDOWNMENU_MENU_VALUE then
            for _, item in ipairs(menuTable) do
                if item.menuList and item.text == UIDROPDOWNMENU_MENU_VALUE then
                    menu = item.menuList
                    break
                end
            end
        end
        for _, item in ipairs(menu or {}) do
            local info = UIDropDownMenu_CreateInfo()
            for k, v in pairs(item) do
                info[k] = v
            end
            if item.menuList then
                info.hasArrow = true
                info.notCheckable = true
                info.menuList = item.menuList
                info.value = item.text
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end
    UIDropDownMenu_Initialize(EasyAuction_SearchHistoryDropDown, initialize, "MENU")
    ToggleDropDownMenu(1, nil, EasyAuction_SearchHistoryDropDown, anchor, x, y)
end

local PRICE_NUM = 20
local PRICE_ROWS_PER_PAGE = 15
local priceCurrentPage = 1
local priceTotalPages = 1
local priceDataCache = {}
local PriceFrame = EasyAuctionPriceFrame
local GetContainerNumSlots = GetContainerNumSlots or (C_Container and C_Container.GetContainerNumSlots)
local GetContainerItemLink = GetContainerItemLink or (C_Container and C_Container.GetContainerItemLink)
local GetContainerItemInfo = GetContainerItemInfo or (C_Container and C_Container.GetContainerItemInfo)

PriceFrame:SetSize(350, 402)
EA_StyleSkin(PriceFrame, "window")
EA_EnsureSolidBackground(PriceFrame, "window", 0.99)

PriceFrame:SetFrameStrata("FULLSCREEN_DIALOG")
PriceFrame:SetMovable(true)
PriceFrame:EnableMouse(true)
PriceFrame:RegisterForDrag("LeftButton")
PriceFrame:SetScript("OnDragStart", PriceFrame.StartMoving)
PriceFrame:SetScript("OnDragStop", PriceFrame.StopMovingOrSizing)
PriceFrame:Hide()

PriceFrame:SetScript("OnHide", function(self)
    EasyAuctionDB.LastSelectedPriceInfo = nil
end)

local CloseBtn = _G["EasyAuctionPriceFrameClose"]
if CloseBtn then CloseBtn:Hide() end
EA_StyleCloseButton(PriceFrame)
local ITEM_QUALITY_COLORS = {
    [1] = "|cffffffff",
    [2] = "|cff1eff00",
    [3] = "|cff0070dd",
    [4] = "|cffa335ee",
    [5] = "|cffff8000",
    [6] = "|cffe6cc80",
}
local function ColorName(name, link)
    if link then
        local quality = select(3, GetItemInfo(link))
        quality = tonumber(quality)
        if quality and ITEM_QUALITY_COLORS[quality] then
            return ITEM_QUALITY_COLORS[quality] .. name .. "|r"
        end
    end
    return "|cffffffff" .. (name or "") .. "|r"
end
local function GetCurrentStackSize()
    if AuctionsStackSizeEntry and AuctionsStackSizeEntry.GetNumber then
        local n = AuctionsStackSizeEntry:GetNumber()
        if n and n > 0 then return n end
    end
    return 1
end
local function FillAuctionPrice(unitPrice)
    local stackSize = GetCurrentStackSize()
    local totalPrice = unitPrice * stackSize
    MoneyInputFrame_SetCopper(StartPrice, totalPrice - 1)
    MoneyInputFrame_SetCopper(BuyoutPrice, totalPrice - 1)

    if AuctionBar and AuctionBar.HookAuctionFrame then
        local f = AuctionBar.HookAuctionFrame
        local displayUnit = math.max(unitPrice - 1, 0)
        if f.UnitGoldPrice and f.UnitSilverPrice and f.UnitCopperPrice then
            f.UnitGoldPrice:SetNumber(math.floor(displayUnit / 10000))
            f.UnitSilverPrice:SetNumber(math.floor((displayUnit % 10000) / 100))
            f.UnitCopperPrice:SetNumber(displayUnit % 100)
        end

        local sideStackSize = (f.StackCount and f.StackCount:GetNumber() or 1)
        local sideTotal = displayUnit * (sideStackSize > 0 and sideStackSize or 1)
        if f.StackGoldPrice and f.StackSilverPrice and f.StackCopperPrice then
            f.StackGoldPrice:SetNumber(math.floor(sideTotal / 10000))
            f.StackSilverPrice:SetNumber(math.floor((sideTotal % 10000) / 100))
            f.StackCopperPrice:SetNumber(sideTotal % 100)
        end
    end
end

local PriceItemNameFS = _G["EasyAuctionPriceFrameItemName"]
if PriceItemNameFS then
    PriceItemNameFS:ClearAllPoints()
    PriceItemNameFS:SetPoint("TOPLEFT", PriceFrame, "TOPLEFT", 14, -14)
    PriceItemNameFS:SetPoint("TOPRIGHT", PriceFrame, "TOPRIGHT", -42, -14)
    PriceItemNameFS:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 15, "")
    PriceItemNameFS:SetJustifyH("LEFT")
    PriceItemNameFS:SetWordWrap(false)
    EA_StyleText(PriceItemNameFS, "accent")
end

local PriceVendorFS = _G["EasyAuctionPriceFrameVendorPrice"]
if PriceVendorFS then
    PriceVendorFS:ClearAllPoints()
    PriceVendorFS:SetPoint("TOPLEFT", PriceFrame, "TOPLEFT", 14, -42)
    PriceVendorFS:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
    EA_StyleText(PriceVendorFS, "bull")
end

local PriceMinFS = _G["EasyAuctionPriceFrameMinPrice"]
if PriceMinFS then
    PriceMinFS:ClearAllPoints()
    PriceMinFS:SetPoint("TOPLEFT", PriceFrame, "TOPLEFT", 14, -60)
    PriceMinFS:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
    EA_StyleText(PriceMinFS, "accent")
end

local PriceHeaderFS = _G["EasyAuctionPriceFrameHeader"]
if PriceHeaderFS then PriceHeaderFS:Hide() end

local PriceTableFrame = CreateFrame("Frame", nil, PriceFrame, "BackdropTemplate")
PriceTableFrame:SetPoint("TOPLEFT", PriceFrame, "TOPLEFT", 12, -82)
PriceTableFrame:SetPoint("BOTTOMRIGHT", PriceFrame, "BOTTOMRIGHT", -12, 72)
EA_StylePanel(PriceTableFrame, "plot")
EA_EnsureSolidBackground(PriceTableFrame, "plot", 0.98)
PriceFrame.EA_TableFrame = PriceTableFrame

local PriceHeader = CreateFrame("Frame", nil, PriceTableFrame)
PriceHeader:SetPoint("TOPLEFT", PriceTableFrame, "TOPLEFT", 6, -6)
PriceHeader:SetPoint("TOPRIGHT", PriceTableFrame, "TOPRIGHT", -22, -6)
PriceHeader:SetHeight(20)
PriceHeader.bg = PriceHeader:CreateTexture(nil, "BACKGROUND")
PriceHeader.bg:SetAllPoints()
if EAStyle then
    EAStyle:OnTheme(function(p)
        PriceHeader.bg:SetColorTexture(p.plot[1], p.plot[2], p.plot[3], 0.72)
    end)
else
    PriceHeader.bg:SetColorTexture(0.08, 0.09, 0.11, 0.72)
end
PriceFrame.EA_HeaderFrame = PriceHeader

local priceHeaders = {
    { text = "序", width = 30, justify = "CENTER" },
    { text = "堆叠", width = 52, justify = "CENTER" },
    { text = "单价", width = 130, justify = "RIGHT" },
    { text = "卖方", width = 74, justify = "CENTER" },
}
PriceHeader.cols = {}
for i, col in ipairs(priceHeaders) do
    local fs = PriceHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetText(col.text)
    fs:SetWidth(col.width)
    EA_ApplyCellFont(fs, "accent", col.justify)
    if i == 1 then
        fs:SetPoint("LEFT", PriceHeader, "LEFT", 0, 0)
    else
        fs:SetPoint("LEFT", PriceHeader.cols[i - 1], "RIGHT", 4, 0)
    end
    PriceHeader.cols[i] = fs
end
local headerBottom = EA_AddBoxLine(PriceHeader, "bottom", "horizontal")
headerBottom:SetPoint("BOTTOMLEFT", PriceHeader, "BOTTOMLEFT", 0, 0)
headerBottom:SetPoint("BOTTOMRIGHT", PriceHeader, "BOTTOMRIGHT", 0, 0)

PriceFrame.rows = {}
for i = 1, PRICE_NUM do
    local btn = CreateFrame("Button", nil, PriceTableFrame)
    btn:SetSize(298, 16)
    btn:SetPoint("TOPLEFT", PriceTableFrame, "TOPLEFT", 6, -28 - (i - 1) * 16)
    btn:SetNormalFontObject("GameFontHighlightSmall")
    EA_StyleRowHighlight(btn)
    btn:Hide()
    btn.bg = btn:CreateTexture(nil, "BACKGROUND")
    btn.bg:SetAllPoints()
    btn.cols = btn.cols or {}
    btn.cols[1] = btn:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    btn.cols[1]:SetPoint("LEFT", btn, "LEFT", 0, 0)
    btn.cols[1]:SetWidth(priceHeaders[1].width)
    EA_ApplyCellFont(btn.cols[1], "muted", "CENTER")
    btn.cols[2] = btn:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    btn.cols[2]:SetPoint("LEFT", btn.cols[1], "RIGHT", 4, 0)
    btn.cols[2]:SetWidth(priceHeaders[2].width)
    EA_ApplyCellFont(btn.cols[2], "text", "CENTER")
    btn.cols[3] = btn:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    btn.cols[3]:SetPoint("LEFT", btn.cols[2], "RIGHT", 4, 0)
    btn.cols[3]:SetWidth(priceHeaders[3].width)
    EA_ApplyCellFont(btn.cols[3], "text", "RIGHT")
    btn.cols[4] = btn:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    btn.cols[4]:SetPoint("LEFT", btn.cols[3], "RIGHT", 4, 0)
    btn.cols[4]:SetWidth(priceHeaders[4].width)
    EA_ApplyCellFont(btn.cols[4], "muted", "CENTER")
    btn.bottomLine = EA_AddBoxLine(btn, "bottom", "horizontal")
    btn.bottomLine:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
    btn.bottomLine:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    btn.vLines = {}
    for j = 1, 3 do
        btn.vLines[j] = EA_AddBoxLine(btn, "v" .. j, "vertical")
        btn.vLines[j]:SetPoint("TOPLEFT", btn.cols[j], "TOPRIGHT", 2, 0)
        btn.vLines[j]:SetPoint("BOTTOMLEFT", btn.cols[j], "BOTTOMRIGHT", 2, 0)
    end
    PriceFrame.rows[i] = btn
end
local pricePrevBtn = CreateFrame("Button", nil, PriceFrame, "UIPanelButtonTemplate")
pricePrevBtn:SetSize(62, 22)
pricePrevBtn:SetPoint("BOTTOMLEFT", PriceFrame, "BOTTOMLEFT", 14, 14)
pricePrevBtn:SetText("上一页")
EA_StyleButton(pricePrevBtn)
pricePrevBtn:Hide()

local priceNextBtn = CreateFrame("Button", nil, PriceFrame, "UIPanelButtonTemplate")
priceNextBtn:SetSize(62, 22)
priceNextBtn:SetPoint("LEFT", pricePrevBtn, "RIGHT", 6, 0)
priceNextBtn:SetText("下一页")
EA_StyleButton(priceNextBtn)
priceNextBtn:Hide()

local pricePageText = PriceFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
pricePageText:SetPoint("LEFT", priceNextBtn, "RIGHT", 8, 0)
pricePageText:SetText("")
EA_StyleText(pricePageText, "accent")

local ICON_SIZE = 12
function FormatGoldIcon(copper, size)
    size = size or ICON_SIZE or 12
    copper = copper or 0
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local copperOnly = copper % 100
    local iconStr = ":" .. size .. ":" .. size .. ":2:0"
    local str = ""

    if gold > 0 then
        str = str .. gold .. "|TInterface\\MoneyFrame\\UI-GoldIcon" .. iconStr .. "|t"
        str = str .. string.format("%02d", silver) .. "|TInterface\\MoneyFrame\\UI-SilverIcon" .. iconStr .. "|t"
        str = str .. string.format("%02d", copperOnly) .. "|TInterface\\MoneyFrame\\UI-CopperIcon" .. iconStr .. "|t"
    elseif silver > 0 then
        str = str .. silver .. "|TInterface\\MoneyFrame\\UI-SilverIcon" .. iconStr .. "|t"
        str = str .. string.format("%02d", copperOnly) .. "|TInterface\\MoneyFrame\\UI-CopperIcon" .. iconStr .. "|t"
    else
        str = str .. copperOnly .. "|TInterface\\MoneyFrame\\UI-CopperIcon" .. iconStr .. "|t"
    end

    return str
end

local function FormatGoldText(copper)
    copper = math.floor(tonumber(copper) or 0)
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local copperOnly = copper % 100
    if gold > 0 then
        return string.format("%d金%02d银%02d铜", gold, silver, copperOnly)
    elseif silver > 0 then
        return string.format("%d银%02d铜", silver, copperOnly)
    end
    return string.format("%d铜", copperOnly)
end

local function FormatTimeAgo(ts)
    local diff = time() - (ts or 0)
    if diff < 3600 then
        return string.format("（%d分钟前）", math.floor(diff / 60))
    elseif diff < 86400 then
        return string.format("（%d小时前）", math.floor(diff / 3600))
    else
        return string.format("（%d天前）", math.floor(diff / 86400))
    end
end

local function showUnitPrice()
    local db = _G.EasyAuctionDB or EasyAuctionDB
    if not db then
        return true
    end
    if db.showUnitPrice then
        return IsShiftKeyDown()
    else
        return not IsShiftKeyDown()
    end
end

local _EA_nextTooltipPriceInfo = {}

local function EasyAuction_OnTooltipItem()
    -- 闭包缓存
    local lastItemID = nil
    local lastResult = {}

    return function(tip, link, count)
        local db = _G.EasyAuctionDB or EasyAuctionDB
        if type(db) ~= "table" or not db.ShowPrice then return end
        if not link or not tip or not tip.AddDoubleLine then return end
        count = (count and count > 0) and count or 1

        -- 获取 itemID
        local itemID = tonumber(link:match("item:(%d+):"))
        local name, _, quality, itemLevel, _, _, _, _, _, _, sellPrice, classID = GetItemInfo(link)
        if not itemID then return end

        -- 缓存命中
        local curUnit, curTime, minUnit, minTime
        if lastItemID == itemID then
            curUnit, curTime, minUnit, minTime = lastResult.curUnit, lastResult.curTime, lastResult.minUnit,
                lastResult.minTime
        else
            curUnit, curTime, minUnit, minTime = nil, nil, nil, nil
            if db.enablePrice then
                local timeWindow = 1800 -- 30分钟
                local idHistories = EasyAuction_ItemID_Index[itemID]
                if idHistories then
                    local latestTime = nil
                    for _, entry in ipairs(idHistories) do
                        local history = EasyAuction_GetPriceHistory(entry.key, db)
                        if type(history) == "table" and #history > 0 then
                            for _, v in ipairs(history) do
                                if v.unit and v.t and (not latestTime or v.t > latestTime) then
                                    latestTime = v.t
                                end
                            end
                        end
                    end
                    -- 30分钟内的最低价
                    if latestTime then
                        for _, entry in ipairs(idHistories) do
                            local history = EasyAuction_GetPriceHistory(entry.key, db)
                            if type(history) == "table" and #history > 0 then
                                for _, v in ipairs(history) do
                                    if v.unit and v.t and v.t >= latestTime - timeWindow then
                                        if not curUnit or v.unit < curUnit then
                                            curUnit = v.unit
                                            curTime = v.t
                                            minTime = v.t
                                        end
                                    end
                                end
                            end
                            -- 聚合全局史低
                            local entryMin = entry.minUnit or EasyAuction_GetPriceHistoryMinUnit(entry.key, db)
                            if entryMin and (not minUnit or entryMin < minUnit) then
                                minUnit = entryMin
                            end
                        end
                    end
                end
            end
            -- 缓存本次结果
            lastItemID = itemID
            lastResult.curUnit = curUnit
            lastResult.curTime = curTime
            lastResult.minUnit = minUnit
            lastResult.minTime = minTime
        end

        if db.enablePrice then
            -- 卖店价
            if db.enableVendor and sellPrice and sellPrice > 0 then
                if showUnitPrice() and count > 1 then
                    tip:AddDoubleLine(
                        "|cff00ff00卖店|r",
                        FormatGoldIcon(sellPrice * count) .. "（总价）",
                        1, 0.82, 0, 1, 1, 1
                    )
                else
                    tip:AddDoubleLine(
                        "|cff00ff00卖店|r",
                        FormatGoldIcon(sellPrice) .. "（单价）",
                        1, 0.82, 0, 1, 1, 1
                    )
                end
            end

            if curUnit then
                local ago = curTime and FormatTimeAgo(curTime) or ""
                if showUnitPrice() and count > 1 then
                    tip:AddDoubleLine(
                        ("|cff00c0ff拍卖|r %s"):format(ago),
                        FormatGoldIcon(curUnit * count) .. "（总价）",
                        0, 1, 1, 1, 1, 1
                    )
                else
                    tip:AddDoubleLine(
                        ("|cff00c0ff拍卖|r %s"):format(ago),
                        FormatGoldIcon(curUnit) .. "（单价）",
                        0, 1, 1, 1, 1, 1
                    )
                end
            end

            if db.ShowMinPrice and minUnit and minUnit ~= curUnit then
                if showUnitPrice() and count > 1 then
                    tip:AddDoubleLine(
                        "|cff80ff80史低|r",
                        FormatGoldIcon(minUnit * count) .. "（总价）",
                        0, 1, 0.5, 1, 1, 1
                    )
                else
                    tip:AddDoubleLine(
                        "|cff80ff80史低|r",
                        FormatGoldIcon(minUnit) .. "（单价）",
                        0, 1, 0.5, 1, 1, 1
                    )
                end
            end
        end

        if IsDisenchantable(classID, quality) and db.enableDisenchant then
            local maxV = GetDisenchantValue(classID, quality, itemLevel)
            local breakdown = GetDisenchantBreakdown(classID, quality, itemLevel)
            if breakdown and #breakdown > 0 then
                if maxV and maxV > 0 then
                    tip:AddDoubleLine(
                        "|cff00ff99分解收益|r",
                        FormatGoldIcon(maxV, 12),
                        0, 1, 0, 1, 1, 1
                    )
                end
                if db.enableDisenchantProb then
                    tip:AddLine("|cff00ff99分解概率：|r")
                    for _, mat in ipairs(breakdown) do
                        local matName = FormatItemLinkWithColor and FormatItemLinkWithColor(mat.itemid)
                            or (ns.DE_Mats and ns.DE_Mats[mat.itemid] or ("物品" .. tostring(mat.itemid)))
                        tip:AddDoubleLine(
                            string.format("   %s", matName),
                            string.format("%dx (%.1f%%)", mat.count, mat.rate * 100),
                            0.5, 1, 0.5, 1, 1, 1
                        )
                    end
                end
            end
        end

        if IsProspectableOre(itemID) and db.enableProspect then
            local prospectValue = GetProspectValue(itemID)
            if prospectValue and prospectValue > 0 then
                tip:AddDoubleLine(
                    "|cff00bfff选矿收益|r",
                    FormatGoldIcon(prospectValue, 12),
                    1, 0.8, 0, 1, 1, 1
                )
            else
                tip:AddDoubleLine(
                    "|cff00bfff选矿收益|r",
                    "|cff888888未知|r",
                    0.7, 0.7, 0.7, 1, 1, 1
                )
            end
        end

        if IsMillableHerb(itemID) and db.enableMill then
            local millValue = GetMillValue(itemID)

            if millValue and millValue > 0 then
                tip:AddDoubleLine(
                    "|cff00bfff研磨收益|r",
                    FormatGoldIcon(millValue, 12),
                    1, 0.8, 0, 1, 1, 1
                )
            else
                tip:AddDoubleLine(
                    "|cff00bfff研磨收益|r",
                    "|cff888888未知|r",
                    0.7, 0.7, 0.7, 1, 1, 1
                )
            end
        end

        if db.enableTitanValue then
            local titan

            for _, arr in pairs(ns.EA_CATEGORY_LIST) do
                for _, info in ipairs(arr) do
                    local _, id, t = unpack(info)
                    if tonumber(id) == itemID and t and tonumber(t) > 0 then
                        titan = tonumber(t)
                        break
                    end
                end
                if titan then break end
            end

            if titan and titan > 0 then
                tip:AddDoubleLine(
                    "|cffffaa00兑换需碎片|r",
                    tostring(titan) .. " |TInterface\\Icons\\Inv_ingot_titansteel_dark:10:10:0:0|t",
                    0.27, 0.82, 0.82, 1, 1, 1
                )
                local unitPrice = curUnit or minUnit
                if unitPrice and unitPrice > 0 then
                    local tv = math.floor(unitPrice / titan + 0.5)
                    tip:AddDoubleLine(
                        "|cffffaa00每碎片价值|r",
                        FormatGoldIcon(tv, 12),
                        0.27, 0.82, 0.82, 1, 1, 1
                    )
                else
                    tip:AddDoubleLine(
                        "|cffffaa00碎片价值|r",
                        "|cff888888未知|r",
                        0.7, 0.7, 0.7, 1, 1, 1
                    )
                end
            end
        end

        tip:Show()
    end
end

EasyAuction_OnTooltipItem = EasyAuction_OnTooltipItem()
-- local tip = GameTooltip
-- local origs = {}
-- for k, v in pairs(getmetatable(tip).__index) do
--     if type(v) == "function" and not k:find("SetScript") then
--         origs[k] = v
--         hooksecurefunc(tip, k, function(self, ...)
--             print("GameTooltip方法调用:", k, ...)
--         end)
--     end
-- end
if GameTooltip.SetTradeSkillItem then
    hooksecurefunc(GameTooltip, "SetTradeSkillItem", function(self, arg1, arg2)
        local itemLink
        if arg2 then
            itemLink = GetTradeSkillReagentItemLink(arg1, arg2)
        else
            itemLink = GetTradeSkillItemLink(arg1)
        end
        if itemLink then
            EasyAuction_OnTooltipItem(self, itemLink, 1)
        end
    end)
end

local function FillUnitPriceOnly(unitPrice)
    AuctionBar = _G["AuctionBarFrame"]
    if AuctionBar and AuctionBar.AuctionFrame then
        local f = AuctionBar.AuctionFrame
        local ug = math.floor(unitPrice / 10000)
        local us = math.floor((unitPrice % 10000) / 100)
        local uc = unitPrice % 100
        f.UnitGold:SetNumber(ug)
        f.UnitSilver:SetNumber(us)
        f.UnitCopper:SetNumber(uc)
        if f.StackCount and f.StackCount:GetNumber() then
            local count = f.StackCount:GetNumber()
            local stackTotal = unitPrice * count
            local sg = math.floor(stackTotal / 10000)
            local ss = math.floor((stackTotal % 10000) / 100)
            local sc = stackTotal % 100
            f.StackGold:SetNumber(sg)
            f.StackSilver:SetNumber(ss)
            f.StackCopper:SetNumber(sc)
            local bidDiscount = EasyAuctionDB.bidDiscount or 0.99
            local bidTotal = math.floor(stackTotal * bidDiscount)
            local bg = math.floor(bidTotal / 10000)
            local bs = math.floor((bidTotal % 10000) / 100)
            local bc = bidTotal % 100
            f.BidGold:SetNumber(bg)
            f.BidSilver:SetNumber(bs)
            f.BidCopper:SetNumber(bc)
        end
    end
end

local itemInfoWaitFrame = CreateFrame("Frame")
itemInfoWaitFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
itemInfoWaitFrame:SetScript("OnEvent", function(_, _, itemID, success)
    if GameTooltip and GameTooltip:IsShown() and (GameTooltip.__EA_RefreshWaiting or IsShiftKeyDown()) then
        local tipInfo = _EA_nextTooltipPriceInfo[GameTooltip]
        if tipInfo and tipInfo.itemID == itemID then
            local link = select(2, GetItemInfo(itemID))
            if link then
                tipInfo.link = link
                EasyAuction_OnTooltipItem(GameTooltip, link, tipInfo.count)
                GameTooltip.__EA_RefreshWaiting = nil
            end
        end
    end
end)

function ShowPriceFrame(itemName, data, page)
    -- if AuctionHelper and AuctionHelper:IsShown() then
    --     PriceFrame:Hide()
    --     return
    -- end
    if (not data) or (#data == 0) then
        if EasyAuction_DistributionFrame and EasyAuction_DistributionFrame:IsShown() then
            EasyAuction_DistributionFrame:Hide()
        end
        PriceFrame:Hide()
        return
    end

    priceDataCache = data
    priceTotalPages = math.max(1, math.ceil(#data / PRICE_ROWS_PER_PAGE))
    if not page then priceCurrentPage = 1 else priceCurrentPage = page end
    if priceCurrentPage < 1 then priceCurrentPage = 1 end
    if priceCurrentPage > priceTotalPages then priceCurrentPage = priceTotalPages end

    table.sort(data, function(a, b) return a.unit < b.unit end)

    local startIdx = (priceCurrentPage - 1) * PRICE_ROWS_PER_PAGE + 1

    for i, btn in ipairs(PriceFrame.rows) do
        local idx = startIdx + i - 1
        local info = data[idx]
        if i <= PRICE_ROWS_PER_PAGE and info then
            btn:Show()
            if btn.bg then
                EA_StyleRow(btn.bg, i)
            end
            btn.cols[1]:SetText(string.format("%2d", idx))
            btn.cols[1]:Show()
            btn.cols[2]:SetText(string.format("%4d", info.count or 0))
            btn.cols[2]:Show()
            btn.cols[3]:SetText(FormatGoldIcon(info.unit))
            btn.cols[3]:Show()
            btn.cols[4]:SetText(info.owner or "-")
            btn.cols[4]:Show()
            btn:SetScript("OnClick", function()
                EasyAuctionDB.LastSelectedPriceInfo = info
                FillAuctionPrice(info.unit)
                FillUnitPriceOnly(info.unit)
            end)
        else
            for k = 1, 4 do
                if btn.cols[k] then
                    btn.cols[k]:SetText(""); btn.cols[k]:Hide()
                end
            end
            btn:Hide()
        end
    end

    pricePrevBtn:SetShown(priceTotalPages > 1)
    priceNextBtn:SetShown(priceTotalPages > 1)
    pricePrevBtn:SetEnabled(priceCurrentPage > 1)
    priceNextBtn:SetEnabled(priceCurrentPage < priceTotalPages)
    pricePageText:SetText(string.format("第%d/%d页", priceCurrentPage, priceTotalPages))

    local ItemNameFS = _G["EasyAuctionPriceFrameItemName"]
    if ItemNameFS then
        ItemNameFS:SetText(itemName or "")
    end
    local TimeFS = _G["EasyAuctionPriceFrameTime"]
    local timeStr = ""
    if data[1] and data[1].t then
        timeStr = date("%Y-%m-%d %H:%M", data[1].t)
    end
    if TimeFS then
        TimeFS:ClearAllPoints()
        TimeFS:SetPoint("BOTTOMLEFT", PriceFrame, "BOTTOMLEFT", 14, 44)
        TimeFS:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "")
        EA_StyleText(TimeFS, "muted")
        TimeFS:SetText("采集时间：" .. timeStr)
    end

    if not PriceFrame._itemInfoEventRegistered then
        local f = CreateFrame("Frame")
        f:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        f:SetScript("OnEvent", function(_, _, _, success)
            if success and PriceFrame:IsShown() then
                if PriceFrame.__ea_in_update then return end
                PriceFrame.__ea_in_update = true
                local itemNameFS = _G["EasyAuctionPriceFrameItemName"]
                local itemName = itemNameFS and itemNameFS:GetText():gsub("[%[%]]", "")
                if itemName and itemName ~= "" then
                    ShowPriceFrame(itemName, priceDataCache, priceCurrentPage)
                end
                PriceFrame.__ea_in_update = nil
            end
        end)
        PriceFrame._itemInfoEventRegistered = true
    end
    if data and #data > 0 then
        C_Timer.After(0.05, function()
            local name, _, _, _, _, _, _, _, _, itemID = GetAuctionSellItemInfo()
            local priceList
            if name and itemID then
                local key = name .. ":" .. itemID
                priceList = EasyAuction_GetPriceHistory(key, EasyAuctionDB)
            end
            if priceList and #priceList > 0 then
                local minUnit = priceList[1].unit
                for _, v in ipairs(priceList) do
                    if v.unit < minUnit then minUnit = v.unit end
                end
                EasyAuctionDB.LastSelectedPriceInfo = nil
                FillAuctionPrice(minUnit)
                --print("|cff00ff00[EasyAuction]|r 自动填价，物品："..(name or "?").."，最低单价："..FormatGoldIcon(minUnit))
            else
                --print("|cffff0000[EasyAuction]|r 没有历史价格数据："..(name or "?"))
            end
        end)
    end
    if AuctionsStackSizeEntry and not AuctionsStackSizeEntry.EasyAuction_PriceAutoFillHooked then
        AuctionsStackSizeEntry:HookScript("OnTextChanged", function(self)
            if EasyAuctionPriceFrame and EasyAuctionPriceFrame:IsShown() then
                local info = EasyAuctionDB.LastSelectedPriceInfo
                if not info and priceDataCache and #priceDataCache > 0 then
                    info = priceDataCache[1]
                    for _, v in ipairs(priceDataCache) do
                        if v.unit < info.unit then info = v end
                    end
                    EasyAuctionDB.LastSelectedPriceInfo = info
                end
                if info then
                    FillAuctionPrice(info.unit)
                    RefreshMinPriceLines(itemName)
                end
            end
        end)
        AuctionsStackSizeEntry.EasyAuction_PriceAutoFillHooked = true
    end

    local VendorPriceFS = _G["EasyAuctionPriceFrameVendorPrice"]
    local vendorPrice
    if itemName then
        local itemID = tonumber(itemName:match(":(%d+)$"))
        local name2, _, _, _, _, _, _, _, _, _, sellPrice
        if itemID then
            name2, _, _, _, _, _, _, _, _, _, sellPrice = GetItemInfo(itemID)
        else
            name2, _, _, _, _, _, _, _, _, _, sellPrice = GetItemInfo(itemName)
        end
        if sellPrice and sellPrice > 0 then
            vendorPrice = sellPrice
        end
    end
    if VendorPriceFS then
        if vendorPrice then
            VendorPriceFS:SetText("卖店价：" .. FormatGoldIcon(vendorPrice, 11))
        else
            VendorPriceFS:SetText("卖店价：无")
        end
    end

    local MinPriceFS = _G["EasyAuctionPriceFrameMinPrice"]
    if MinPriceFS and not MinPriceFS.EasyAuctionClickable then
        MinPriceFS:EnableMouse(true)
        MinPriceFS:SetScript("OnMouseUp", function(self, button)
            local name, _, _, _, _, _, _, _, _, itemID = GetAuctionSellItemInfo()
            local key = name and itemID and (name .. ":" .. itemID) or name
            local minHistory = key and EasyAuction_GetPriceHistoryMinUnit(key, EasyAuctionDB)
            if minHistory then
                FillAuctionPrice(minHistory)
                print("|cff00ff00[EasyAuction]|r 已使用历史最低价。")
            else
                print("|cffff0000[EasyAuction]|r 无历史最低价数据，请先搜索获得历史价格！")
            end
        end)
        MinPriceFS:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("点击以历史最低价销售", 1, 1, 1)
            GameTooltip:Show()
        end)
        MinPriceFS:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
        MinPriceFS.EasyAuctionClickable = true
    end

    local minHistory = EasyAuction_GetPriceHistoryMinUnit(itemName, EasyAuctionDB)
    if data and #data > 0 then
        for _, v in ipairs(data) do
            if not minHistory or v.unit < minHistory then minHistory = v.unit end
        end
    end

    if MinPriceFS then
        if minHistory then
            MinPriceFS:SetText("历史最低价：" .. FormatGoldIcon(minHistory, 11))
        else
            MinPriceFS:SetText("历史最低价：无")
        end
    end

    if not PriceFrame.EasyAuction_DistributionButton then
        local btn = CreateFrame("Button", nil, PriceFrame, "UIPanelButtonTemplate")
        btn:SetText("价格分布")
        btn:SetSize(82, 22)
        btn:SetPoint("BOTTOMRIGHT", PriceFrame, "BOTTOMRIGHT", -14, 44)
        EA_StyleButton(btn)
        btn:Show()
        PriceFrame.EasyAuction_DistributionButton = btn
    end
    PriceFrame.EasyAuction_DistributionItemName = itemName
    PriceFrame.EasyAuction_DistributionData = data
    PriceFrame.EasyAuction_DistributionButton:SetScript("OnClick", function()
        ShowDistributionFrame(PriceFrame.EasyAuction_DistributionItemName, PriceFrame.EasyAuction_DistributionData)
    end)

    if not PriceFrame.EasyAuction_ChartButton then
        local btn = CreateFrame("Button", nil, PriceFrame, "UIPanelButtonTemplate")
        btn:SetText("价格走势")
        btn:SetSize(82, 22)
        btn:SetPoint("BOTTOMRIGHT", PriceFrame, "BOTTOMRIGHT", -14, 14)
        EA_StyleButton(btn)
        btn:Show()
        PriceFrame.EasyAuction_ChartButton = btn
    end

    PriceFrame.EasyAuction_ChartButton:SetScript("OnClick", function()
        EasyAuction_ShowChart(itemName)
    end)
    EasyAuctionDB.CurrentDistItemName = itemName
    EasyAuctionDB.CurrentDistData = data

    if (not data) or (#data == 0) then
        if EasyAuction_DistributionFrame and EasyAuction_DistributionFrame:IsShown() then
            EasyAuction_DistributionFrame:Hide()
        end
    else
        if EasyAuction_DistributionFrame and EasyAuction_DistributionFrame:IsShown() then
            ShowDistributionFrame(itemName, data)
        end
    end
    if PriceFrame and PriceFrame.DistributionArea then
        EasyAuction_UpdateInlineDistribution(itemName, data)
    end
    PriceFrame:Show()
end

function ShowDistributionFrame(itemName, data)
    if not data or #data == 0 then
        if EasyAuction_DistributionFrame then
            EasyAuction_DistributionFrame:Hide()
        end
        return
    end

    local FRAME_WIDTH = 500
    local FRAME_HEIGHT = 342
    local ROW_HEIGHT = 18
    local MAX_ROWS = 12

    if not EasyAuction_DistributionFrame then
        local f = CreateFrame("Frame", "EasyAuction_DistributionFrame", UIParent, "BackdropTemplate")
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
        if EasyAuctionPriceFrame and EasyAuctionPriceFrame:IsShown() then
            f:SetPoint("LEFT", EasyAuctionPriceFrame, "RIGHT", 10, 0)
        else
            f:SetPoint("CENTER")
        end
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", function(self) self:StartMoving() end)
        f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
        f:SetClampedToScreen(true)
        EA_StyleSkin(f, "window")
        EA_EnsureSolidBackground(f, "window", 0.99)

        f:EnableKeyboard(true)
        f:SetPropagateKeyboardInput(true)

        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -12)
        f.title:SetPoint("TOPRIGHT", f, "TOPRIGHT", -42, -12)
        f.title:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 14, "")
        f.title:SetJustifyH("LEFT")
        f.title:SetWordWrap(false)
        EA_StyleText(f.title, "accent")
        f.title:SetText("价格分布统计")

        f.headerLine = EA_AddBoxLine(f, "header", "horizontal")
        f.headerLine:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -38)
        f.headerLine:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -38)

        f.statsPanel = CreateFrame("Frame", nil, f, "BackdropTemplate")
        f.statsPanel:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -48)
        f.statsPanel:SetSize(154, 280)
        EA_StylePanel(f.statsPanel, "panel")
        EA_EnsureSolidBackground(f.statsPanel, "panel", 0.99)

        f.summary = f.statsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.summary:SetPoint("TOPLEFT", f.statsPanel, "TOPLEFT", 10, -10)
        f.summary:SetJustifyH("LEFT")
        f.summary:SetJustifyV("TOP")
        f.summary:SetWidth(134)
        f.summary:SetHeight(260)
        f.summary:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
        f.summary:SetSpacing(3)
        EA_StyleText(f.summary, "text")

        f.plotPanel = CreateFrame("Frame", nil, f, "BackdropTemplate")
        f.plotPanel:SetPoint("TOPLEFT", f.statsPanel, "TOPRIGHT", 8, 0)
        f.plotPanel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 14)
        EA_StylePanel(f.plotPanel, "plot")
        EA_EnsureSolidBackground(f.plotPanel, "plot", 0.99)

        f.distHeader = CreateFrame("Frame", nil, f.plotPanel)
        f.distHeader:SetPoint("TOPLEFT", f.plotPanel, "TOPLEFT", 8, -8)
        f.distHeader:SetPoint("TOPRIGHT", f.plotPanel, "TOPRIGHT", -28, -8)
        f.distHeader:SetHeight(20)
        f.distHeader.bg = f.distHeader:CreateTexture(nil, "BACKGROUND")
        f.distHeader.bg:SetAllPoints()
        if EAStyle then
            EAStyle:OnTheme(function(p)
                f.distHeader.bg:SetColorTexture(p.plot[1], p.plot[2], p.plot[3], 0.72)
            end)
        else
            f.distHeader.bg:SetColorTexture(0.08, 0.09, 0.11, 0.72)
        end
        f.distHeader.price = f.distHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.distHeader.price:SetPoint("LEFT", f.distHeader, "LEFT", 4, 0)
        f.distHeader.price:SetWidth(84)
        f.distHeader.price:SetText("价格")
        EA_ApplyCellFont(f.distHeader.price, "accent", "RIGHT")
        f.distHeader.count = f.distHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.distHeader.count:SetPoint("RIGHT", f.distHeader, "RIGHT", -4, 0)
        f.distHeader.count:SetWidth(42)
        f.distHeader.count:SetText("数量")
        EA_ApplyCellFont(f.distHeader.count, "accent", "RIGHT")
        f.distHeader.bar = f.distHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.distHeader.bar:SetPoint("LEFT", f.distHeader.price, "RIGHT", 10, 0)
        f.distHeader.bar:SetPoint("RIGHT", f.distHeader.count, "LEFT", -8, 0)
        f.distHeader.bar:SetText("分布")
        EA_ApplyCellFont(f.distHeader.bar, "accent", "LEFT")
        f.distHeader.bottomLine = EA_AddBoxLine(f.distHeader, "bottom", "horizontal")
        f.distHeader.bottomLine:SetPoint("BOTTOMLEFT", f.distHeader, "BOTTOMLEFT", 0, 0)
        f.distHeader.bottomLine:SetPoint("BOTTOMRIGHT", f.distHeader, "BOTTOMRIGHT", 0, 0)
        f.distHeader.priceLine = EA_AddBoxLine(f.distHeader, "price", "vertical")
        f.distHeader.priceLine:SetPoint("TOPLEFT", f.distHeader.price, "TOPRIGHT", 5, 0)
        f.distHeader.priceLine:SetPoint("BOTTOMLEFT", f.distHeader.price, "BOTTOMRIGHT", 5, 0)
        f.distHeader.countLine = EA_AddBoxLine(f.distHeader, "count", "vertical")
        f.distHeader.countLine:SetPoint("TOPLEFT", f.distHeader.count, "TOPLEFT", -6, 0)
        f.distHeader.countLine:SetPoint("BOTTOMLEFT", f.distHeader.count, "BOTTOMLEFT", -6, 0)

        f.scroll = CreateFrame("ScrollFrame", nil, f.plotPanel, "UIPanelScrollFrameTemplate")
        f.scroll:SetPoint("TOPLEFT", f.plotPanel, "TOPLEFT", 8, -30)
        f.scroll:SetPoint("BOTTOMRIGHT", f.plotPanel, "BOTTOMRIGHT", -28, 8)

        f.content = CreateFrame("Frame", nil, f.scroll)
        f.scroll:SetScrollChild(f.content)
        f.content:SetSize(292, ROW_HEIGHT * MAX_ROWS)
        f.content.rows = {}

        f:EnableMouseWheel(true)
        f:SetScript("OnMouseWheel", function(self, delta)
            local scrollbar = f.scroll:GetVerticalScrollBar()
            if scrollbar and scrollbar:IsShown() then
                local min, max = scrollbar:GetMinMaxValues()
                local value = scrollbar:GetValue()
                if delta < 0 then
                    scrollbar:SetValue(math.min(value + ROW_HEIGHT * 2, max))
                else
                    scrollbar:SetValue(math.max(value - ROW_HEIGHT * 2, min))
                end
            end
        end)
        EA_StyleCloseButton(f, function()
            f:Hide()
            collectgarbage("collect")
        end)
        tinsert(UISpecialFrames, "EasyAuction_DistributionFrame")
        EasyAuction_DistributionFrame = f
    end

    local f = EasyAuction_DistributionFrame
    f:Show()

    if EasyAuctionPriceFrame and EasyAuctionPriceFrame:IsShown() then
        f:ClearAllPoints()
        f:SetPoint("LEFT", EasyAuctionPriceFrame, "RIGHT", 10, 0)
    end
    f:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    f.title:SetText((itemName or "") .. " 价格分布统计")


    local stats, maxCount = {}, 0
    for _, v in ipairs(data or {}) do
        if v.unit then
            stats[v.unit] = (stats[v.unit] or 0) + (v.count or 1)
            if stats[v.unit] > maxCount then maxCount = stats[v.unit] end
        end
    end
    local statArr = {}
    for unit, count in pairs(stats) do
        count = tonumber(count) or 0
        table.insert(statArr, { unit = unit, count = count })
    end
    table.sort(statArr, function(a, b) return a.unit < b.unit end)

    local plotWidth = f.plotPanel and f.plotPanel:GetWidth() or 0
    if not plotWidth or plotWidth < 260 then
        plotWidth = FRAME_WIDTH - 12 - 154 - 8 - 12
    end
    local rowWidth = math.max(240, plotWidth - 38)
    local maxBarWidth = math.max(80, rowWidth - 156)
    if f.distHeader then
        f.distHeader:SetWidth(rowWidth)
    end

    local totalRows = #statArr
    local visibleHeight = ROW_HEIGHT * math.min(math.max(totalRows, 1), MAX_ROWS) + 8
    f.content:SetSize(rowWidth, math.max(visibleHeight, ROW_HEIGHT * totalRows + 8))
    if f.scroll then
        f.scroll:SetVerticalScroll(0)
    end

    for idx, v in ipairs(statArr) do
        local row = f.content.rows[idx]
        if not row then
            row = CreateFrame("Frame", nil, f.content)
            row:SetSize(rowWidth, ROW_HEIGHT)
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
            row.icon = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.icon:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
            row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)
            row.icon:SetWidth(84)
            row.icon:SetJustifyH("RIGHT")
            row.bar = row:CreateTexture(nil, "ARTWORK")
            row.bar:SetTexture("Interface\\Buttons\\WHITE8X8")
            row.bar:SetPoint("LEFT", row.icon, "RIGHT", 10, 0)
            row.bar:SetHeight(10)
            row.count = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.count:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
            row.count:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            row.count:SetWidth(42)
            row.count:SetJustifyH("RIGHT")
            EA_StyleText(row.count, "accent")
            row.bottomLine = EA_AddBoxLine(row, "bottom", "horizontal")
            row.bottomLine:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
            row.bottomLine:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
            row.priceLine = EA_AddBoxLine(row, "price", "vertical")
            row.priceLine:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 5, 0)
            row.priceLine:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 5, 0)
            row.countLine = EA_AddBoxLine(row, "count", "vertical")
            row:SetScript("OnEnter", function(self)
                if self.bg then EA_StyleRow(self.bg, self.__eaIndex or 1, true) end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("点击此价格自动填入拍卖栏", 0, 1, 0)
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function(self)
                if self.bg then EA_StyleRow(self.bg, self.__eaIndex or 1, false) end
                GameTooltip:Hide()
            end)
            f.content.rows[idx] = row
        end
        row:ClearAllPoints()
        row:SetSize(rowWidth, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", f.content, "TOPLEFT", 0, -ROW_HEIGHT * (idx - 1))
        row.__eaIndex = idx
        if row.bg then EA_StyleRow(row.bg, idx) end
        if row.countLine then
            row.countLine:ClearAllPoints()
            row.countLine:SetPoint("TOPLEFT", row, "TOPRIGHT", -50, 0)
            row.countLine:SetPoint("BOTTOMLEFT", row, "BOTTOMRIGHT", -50, 0)
        end
        row.icon:SetText(FormatGoldIcon(v.unit, 11))
        local barLen = maxCount > 0 and math.max(6, math.floor(v.count / maxCount * maxBarWidth + 0.5)) or 6
        if EAStyle then
            local p = EAStyle:Palette()
            local barColor = p.bull or EAStyle.Bull or p.accent or { 0, 0.8, 0.2 }
            row.bar:SetColorTexture(barColor[1], barColor[2], barColor[3], 0.92)
        else
            row.bar:SetColorTexture(0, 0.8, 0.2, 0.92)
        end
        row.bar:SetWidth(barLen)
        row.bar:Show()
        row.count:SetText(tostring(v.count))
        row:Show()
        row.icon:EnableMouse(true)
        row.icon:SetScript("OnMouseUp", function()
            FillAuctionPrice(v.unit)
            print("|cff00ff00[EasyAuction]|r 已自动填入单价：" .. FormatGoldIcon(v.unit, 11))
        end)
        row.icon:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("点击自动填入拍卖栏单价", 1, 1, 0)
            GameTooltip:Show()
        end)
        row.icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    local totalCount = 0
    for _, v in ipairs(statArr) do totalCount = totalCount + v.count end

    table.sort(statArr, function(a, b) return a.count > b.count end)
    local top3 = {}
    for i = 1, math.min(3, #statArr) do
        local v = statArr[i]
        local percent = totalCount > 0 and v.count / totalCount * 100 or 0
        table.insert(top3, string.format("%s  %.1f%%", FormatGoldIcon(v.unit, 11), percent))
    end
    local top3text = #top3 > 0 and table.concat(top3, "\n") or "无"
    f.summary:SetText(string.format("样本数：%d\n\n占比前三\n%s", totalCount, top3text))
    f.summary:Show()
    f.content:SetWidth(rowWidth)
    for i = #statArr + 1, #f.content.rows do
        if f.content.rows[i] then f.content.rows[i]:Hide() end
    end
end

pricePrevBtn:SetScript("OnClick", function()
    if priceCurrentPage > 1 then
        ShowPriceFrame(_G["EasyAuctionPriceFrameItemName"]:GetText():gsub("[%[%]]", ""), priceDataCache,
            priceCurrentPage - 1)
    end
end)

priceNextBtn:SetScript("OnClick", function()
    if priceCurrentPage < priceTotalPages then
        ShowPriceFrame(_G["EasyAuctionPriceFrameItemName"]:GetText():gsub("[%[%]]", ""), priceDataCache,
            priceCurrentPage + 1)
    end
end)

local lastSearchName
hooksecurefunc("QueryAuctionItems", function(name, ...)
    local getAll = select(6, ...)
    EA_FullScanSnapshotActive = getAll == true
    if getAll then
        EA_LastFullScanQueryTime = GetTime()
    end
    if name and name ~= "" then
        lastSearchName = name
    else
        lastSearchName = nil
    end
end)

-- 行刷新节流：1 秒内合并多次触发，连续翻页结束后最多 1 秒内刷新到最新（用全局避免触及主 chunk 局部变量上限）
EA_RowRefreshLastTime = 0
EA_RowRefreshTimerPending = false
function EA_ThrottledRefreshRows()
    if type(RefreshRecentSearchRows) ~= "function" or type(RefreshFavoriteRows) ~= "function" then return end
    local now = GetTime()
    if now - EA_RowRefreshLastTime >= 1 then
        EA_RowRefreshLastTime = now
        RefreshRecentSearchRows(true)
        RefreshFavoriteRows()
    elseif not EA_RowRefreshTimerPending then
        EA_RowRefreshTimerPending = true
        C_Timer.After(1 - (now - EA_RowRefreshLastTime), function()
            EA_RowRefreshTimerPending = false
            EA_RowRefreshLastTime = GetTime()
            RefreshRecentSearchRows(true)
            RefreshFavoriteRows()
        end)
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
eventFrame:SetScript("OnEvent", function()
    if IsScanningAll or IsScanningCategory or EA_IsFullScanSnapshotActive() then return end

    local DB = EasyAuctionDB or {}
    DB.PriceHistory = DB.PriceHistory or {}
    local n = GetNumAuctionItems("list")
    local today = date("%Y-%m-%d")
    local hour = tonumber(date("%H"))

    local keepPerItem = EA_ClampInt(DB.scanKeepPerItem or 120, 120, 20, 500)
    local nowTs = time()
    local batchData = {} -- key = name:itemID -> { byUnit = {}, minUnit/maxUnit/totalCount/... }
    local lastSearchMap = {}
    local searchItemIDs = {}

    for i = 1, n do
        local name, _, count, _, _, _, _, _, _, buyout, _, _, _, owner, _, _, itemID = GetAuctionItemInfo("list", i)
        local link = GetAuctionItemLink("list", i)
        if name and name ~= "" and itemID and buyout and buyout > 0 and count and count > 0 then
            local unit = math.floor((buyout / count) + 0.5)
            local key = name .. ":" .. itemID
            batchData[key] = batchData[key] or {
                byUnit = {},
                minUnit = nil,
                minCount = 0,
                maxUnit = nil,
                maxCount = 0,
                totalCount = 0,
            }
            local bucket = batchData[key]
            local unitKey = tostring(unit)
            local unitRec = bucket.byUnit[unitKey]
            if unitRec then
                unitRec.count = (unitRec.count or 0) + count
                if nowTs > (unitRec.t or 0) then
                    unitRec.t = nowTs
                end
            else
                bucket.byUnit[unitKey] = {
                    unit = unit,
                    count = count,
                    t = nowTs,
                }
            end
            bucket.totalCount = (bucket.totalCount or 0) + count
            if not bucket.minUnit or unit < bucket.minUnit then
                bucket.minUnit = unit
                bucket.minCount = count
            elseif unit == bucket.minUnit then
                bucket.minCount = (bucket.minCount or 0) + count
            end
            if not bucket.maxUnit or unit > bucket.maxUnit then
                bucket.maxUnit = unit
                bucket.maxCount = count
            elseif unit == bucket.maxUnit then
                bucket.maxCount = (bucket.maxCount or 0) + count
            end

            AddRecentSearch(itemID, name, unit, nowTs)

            if lastSearchName and name == lastSearchName then
                if not lastSearchMap[itemID] then
                    lastSearchMap[itemID] = { searchList = {}, searchMinUnit = nil }
                    table.insert(searchItemIDs, itemID)
                end
                table.insert(lastSearchMap[itemID].searchList, {
                    count = count,
                    unit = unit,
                    t = nowTs,
                    owner = owner,
                    itemID = itemID,
                    link = link,
                })
                if not lastSearchMap[itemID].searchMinUnit or unit < lastSearchMap[itemID].searchMinUnit then
                    lastSearchMap[itemID].searchMinUnit = unit
                end
            end
        end
    end

    for key, bucket in pairs(batchData) do
        local minUnit = bucket.minUnit
        local minCount = bucket.minCount or 0
        local maxUnit = bucket.maxUnit or minUnit
        local totalCount = bucket.totalCount or 0

        local records = {}
        for _, rec in pairs(bucket.byUnit or {}) do
            records[#records + 1] = rec
        end
        local compressed = EA_CompressHistoryRecords(records, keepPerItem, nil)
        if type(compressed) == "table" and #compressed > 0 then
            EasyAuction_SetPriceHistory(key, compressed, minUnit or compressed[1].unit or 0, nowTs, DB)
        else
            EA_DeleteStorageKey(DB, "PriceHistory", "price", key)
        end

        local hourlyRecords = EasyAuction_GetHourlyMinPrice(key, DB)
        hourlyRecords = EA_AddOrUpdateHourlyRecord(hourlyRecords, hour, minUnit, minCount, totalCount, nowTs)
        EasyAuction_SetHourlyMinPrice(key, hourlyRecords, DB)

        local dailyRecords = EasyAuction_GetDailyMinPrice(key, DB)
        dailyRecords = EA_AddOrUpdateDailyRecord(dailyRecords, today, minUnit, minCount, minUnit, maxUnit, totalCount)
        EasyAuction_SetDailyMinPrice(key, dailyRecords, DB)

        batchData[key] = nil
    end

    if EasyAuctionDBFrame and EasyAuctionDBFrame:IsShown() and type(RefreshDBFrame) == "function" then RefreshDBFrame() end
    if EasyAuctionPriceFrame and EasyAuctionPriceFrame:IsShown() then
        local showName = (_G["EasyAuctionPriceFrameItemName"] and _G["EasyAuctionPriceFrameItemName"]:GetText() or "")
            :gsub("[%[%]]", "")
        local showItemID = n > 0 and select(17, GetAuctionItemInfo("list", 1)) or nil
        local key = (showName and showItemID) and (showName .. ":" .. showItemID) or showName
        local key2 = (lastSearchName and ns.searchItemID) and (lastSearchName .. ":" .. ns.searchItemID) or
            lastSearchName
        if lastSearchName and ns.searchItemID then
            ShowPriceFrame(key2, EasyAuction_GetPriceHistory(key2, DB))
        elseif DB.PriceHistory[showName] then
            ShowPriceFrame(key, EasyAuction_GetPriceHistory(key, DB))
        end
    end
    if EasyAuction_DistributionFrame and EasyAuction_DistributionFrame:IsShown() then
        ShowDistributionFrame(DB.CurrentDistItemName, DB.CurrentDistData)
    end
    local curName, _, _, _, _, _, _, _, _, curItemID = GetAuctionSellItemInfo()
    if curName and curItemID and (not lastSearchName or curName == lastSearchName) then
        local key = curName .. ":" .. curItemID
        local history = EasyAuction_GetPriceHistory(key, DB)
        if history and #history > 0 then
            if EasyAuctionPriceFrame and not EasyAuctionPriceFrame:IsShown() and not AuctionHelper:IsShown() then
                ShowPriceFrame(key, history)
            end
        end
    end
    if EasyAuction_ChartFrame and EasyAuction_ChartFrame:IsShown() and n > 0 then
        local chartItem = (_G["EasyAuction_ChartFrame"] and EasyAuction_ChartFrame.title and EasyAuction_ChartFrame.title:GetText() or "")
            :match("^(.+) 近%d+天价格走势")
        if chartItem then
            local showItemID = select(17, GetAuctionItemInfo("list", 1))
            if showItemID then
                local key = chartItem .. ":" .. showItemID
                EasyAuction_ShowChart(key)
            end
        end
    end
    if AuctionBar and AuctionBar.AuctionFrame and EasyAuction_UpdateInlineDistribution then
        local sellName, _, _, _, _, _, _, _, _, sellItemID = GetAuctionSellItemInfo()
        if sellName and sellItemID then
            local key = sellName .. ":" .. sellItemID
            EasyAuction_UpdateInlineDistribution(key, EasyAuction_GetPriceHistory(key, DB))
        end
    end

    if curName and lastSearchName == curName then
        local key = lastSearchName .. ":" .. (searchItemIDs[1] or "")
        EasyAuction_UpdateInlineDistribution(key,
            lastSearchMap[searchItemIDs[1]] and lastSearchMap[searchItemIDs[1]].searchList)
        RefreshMinPriceLines(lastSearchName, searchItemIDs[1])
    elseif lastSearchName == nil and n > 0 then
        local name, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, itemID = GetAuctionItemInfo("list", 1)
        if name and itemID then
            local key = name .. ":" .. itemID
            local history = EasyAuction_GetPriceHistory(key, DB)
            EasyAuction_UpdateInlineDistribution(key, history)
            RefreshMinPriceLines(name, itemID)
        end
    elseif #searchItemIDs > 0 and not curName then
        local key = lastSearchName .. ":" .. searchItemIDs[1]
        EasyAuction_UpdateInlineDistribution(key,
            lastSearchMap[searchItemIDs[1]] and lastSearchMap[searchItemIDs[1]].searchList)
        RefreshMinPriceLines(lastSearchName, searchItemIDs[1])
    end

    EA_ThrottledRefreshRows()
    if AuctionBar and AuctionBar.AuctionFrame and AuctionBar.AuctionFrame:IsShown() then
        local f = AuctionBar.AuctionFrame
        local name, _, _, _, _, _, _, _, _, _, _, _, _, _, itemID = GetAuctionSellItemInfo()
        if name and itemID then
            if type(RefreshMinPriceLines) == "function" then RefreshMinPriceLines(name, itemID) end
            if type(MyAH_AutoFillPrice) == "function" then MyAH_AutoFillPrice() end
            local key = name .. ":" .. itemID
            if type(EasyAuction_UpdateInlineDistribution) == "function" and DB.PriceHistory[key] then
                EasyAuction_UpdateInlineDistribution(key, EasyAuction_GetPriceHistory(key, DB))
            end
            if type(UpdateTrendFrame) == "function" then
                UpdateTrendFrame(key)
            end
        end
    end
end)
local closeEvent = CreateFrame("Frame")
closeEvent:RegisterEvent("AUCTION_HOUSE_CLOSED")
closeEvent:SetScript("OnEvent", function()
    EA_FullScanSnapshotActive = false
    EA_CancelActiveFullScan()
    if IsScanningAll or IsScanningCategory then
        IsScanningAll = false
        IsScanningCategory = false
        if type(UpdateScanBtnState) == "function" then
            UpdateScanBtnState()
        end
        if type(UpdateAuctionQueryStatusText) == "function" then
            UpdateAuctionQueryStatusText()
        end
        if type(EasyAuction_HideScanProgress) == "function" then
            EasyAuction_HideScanProgress()
        end
    end
    PriceFrame:Hide()
    if EasyAuction_DistributionFrame then EasyAuction_DistributionFrame:Hide() end
    collectgarbage("collect")
end)

DBFrame = EasyAuctionDBFrame
if DBFrame.SetBackdrop then
    EA_StyleSkin(DBFrame, "window")
end
EA_EnsureSolidBackground(DBFrame, "window", 0.99)
DBFrame:SetSize(920, 440)
DBFrame:SetFrameStrata("DIALOG")
DBFrame:SetToplevel(true)

local DB_TABLE_LEFT = 18
local DB_TABLE_TOP = -92
local DB_HEADER_TOP = -66
local DB_ROW_WIDTH = 884
local DB_FOOTER_Y = 14
local DB_ROW_HEIGHT = 22
local DB_ROW_GAP = 2

local function EA_SkinDBFrameSurface()
    if not DBFrame then return end
    EA_StyleSkin(DBFrame, "window")
    if not DBFrame.EA_Surface then
        local surface = CreateFrame("Frame", nil, DBFrame, "BackdropTemplate")
        surface:SetPoint("TOPLEFT", DBFrame, "TOPLEFT", 10, -58)
        surface:SetPoint("BOTTOMRIGHT", DBFrame, "BOTTOMRIGHT", -10, 48)
        surface:SetFrameLevel(DBFrame:GetFrameLevel() + 1)
        DBFrame.EA_Surface = surface
    end
    EA_EnsureSolidBackground(DBFrame, "window", 0.99)
    if EasyAuctionStyle then
        EasyAuctionStyle:Skin(DBFrame.EA_Surface, "panel")
    else
        DBFrame.EA_Surface:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true,
            tileSize = 16,
            edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 }
        })
        DBFrame.EA_Surface:SetBackdropColor(0.10, 0.10, 0.13, 0.97)
        DBFrame.EA_Surface:SetBackdropBorderColor(0.7, 0.6, 1, 1)
    end
    EA_EnsureSolidBackground(DBFrame.EA_Surface, "panel", 0.99)
    DBFrame.EA_Surface:Show()
    if not DBFrame.EA_FooterLine then
        DBFrame.EA_FooterLine = DBFrame:CreateTexture(nil, "OVERLAY")
        DBFrame.EA_FooterLine:SetHeight(1)
        DBFrame.EA_FooterLine:SetPoint("BOTTOMLEFT", DBFrame, "BOTTOMLEFT", 10, 44)
        DBFrame.EA_FooterLine:SetPoint("BOTTOMRIGHT", DBFrame, "BOTTOMRIGHT", -10, 44)
        if EAStyle then
            EAStyle:OnTheme(function(p)
                DBFrame.EA_FooterLine:SetColorTexture(p.border[1], p.border[2], p.border[3], 0.8)
            end)
        else
            DBFrame.EA_FooterLine:SetColorTexture(0.45, 0.45, 0.50, 0.8)
        end
    end
end
EA_SkinDBFrameSurface()

local searchEditBox
local EA_LayoutDBFrameControls
local resetBtn
local opportunityBtn
local DB_SEARCH_LEFT = 288
local DB_SEARCH_COMPACT_LEFT = 200
local DB_SEARCH_MIN_WIDTH = 150
local DB_SEARCH_FALLBACK_WIDTH = 220

local function EA_GetRelativeLeft(frame, parent)
    if not frame or not parent or not frame.GetLeft or not parent.GetLeft then return nil end
    if frame.IsShown and not frame:IsShown() then return nil end
    local left = frame:GetLeft()
    local parentLeft = parent:GetLeft()
    if not left or not parentLeft then return nil end
    return left - parentLeft
end

local function EA_GetDBTopButtonLeftEdge()
    local leftEdge
    local buttons = {
        resetBtn,
        DBFrame and DBFrame.EA_CategoryManageBtn,
        opportunityBtn,
        DBFrame and DBFrame.EA_ExportBtn,
        DBFrame and DBFrame.EasyAuctionProStrategyButton,
        DBFrame and DBFrame.EasyAuctionBagValueButton,
    }
    for _, button in ipairs(buttons) do
        local left = EA_GetRelativeLeft(button, DBFrame)
        if left and (not leftEdge or left < leftEdge) then
            leftEdge = left
        end
    end
    return leftEdge
end

local function EA_LayoutDBSearchBox()
    if not searchEditBox or not DBFrame then return end
    local searchLeft = DBFrame.EasyAuctionBagValueButton and DB_SEARCH_COMPACT_LEFT or DB_SEARCH_LEFT
    local width = DB_SEARCH_FALLBACK_WIDTH
    local buttonLeft = EA_GetDBTopButtonLeftEdge()
    if buttonLeft then
        width = math.max(DB_SEARCH_MIN_WIDTH, buttonLeft - searchLeft - 10)
    end
    searchEditBox:ClearAllPoints()
    searchEditBox:SetPoint("TOPLEFT", DBFrame, "TOPLEFT", searchLeft, -14)
    searchEditBox:SetSize(width, 22)
    searchEditBox:SetFrameLevel(DBFrame:GetFrameLevel() + 20)
end

local DBFrame_CloseBtn = _G["EasyAuctionDBFrameClose"]
if DBFrame_CloseBtn then DBFrame_CloseBtn:Hide() end
EA_StyleCloseButton(DBFrame)

resetBtn = CreateFrame("Button", nil, DBFrame, "UIPanelButtonTemplate")
resetBtn:SetSize(80, 22)
resetBtn:SetPoint("TOPRIGHT", DBFrame, "TOPRIGHT", -44, -14)
resetBtn:SetText("重置数据")
EA_StyleButton(resetBtn)
resetBtn:Hide()

DBFrame:HookScript("OnShow", function()
    EA_SkinDBFrameSurface()
    resetBtn:Show()
    EA_LayoutDBFrameControls()
end)
DBFrame:HookScript("OnHide", function()
    if resetBtn then resetBtn:Hide() end
    collectgarbage("collect")
end)

opportunityBtn = CreateFrame("Button", nil, DBFrame, "UIPanelButtonTemplate")
opportunityBtn:SetSize(80, 22)
opportunityBtn:SetPoint("RIGHT", resetBtn, "LEFT", -6, 0)
opportunityBtn:SetText("寻找商机")
EA_StyleButton(opportunityBtn)
opportunityBtn:SetScript("OnClick", function()
    EasyAuction_ChanceFrame()
end)
opportunityBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("自动筛选价格库中的低价/套利商机", 1, 1, 1)
    GameTooltip:AddLine("快速发现低于均价、昨日或卖店价的好买卖", 0.85, 0.85, 0.85)
    GameTooltip:Show()
end)
opportunityBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

local normalHeaders = {
    { name = "序", key = "idx", width = 30 },
    { name = "物品名", key = "name", width = 180 },
    { name = "在售数", key = "num", width = 70 },
    { name = "历史最低", key = "history", width = 120 },
    { name = "最新单价", key = "min", width = 120 },
    { name = "碎片数", key = "titan", width = 70 },
    { name = "每碎片价值", key = "titanValue", width = 120 },
    { name = "采集时间", key = "t", width = 80 },
    { name = "走势", key = "action", width = 80 },
}

local currentSortKey = "t"
local currentSortReverse = true

EASYAUCTION_HELP_TEXT = [[
|cffffd700EasyAuction拍卖行插件说明|r

|cff00bfff1、自动采集拍卖价格|r

|cffffd700进入拍卖行后，需先在【搜索】页面搜索你关心的物品，或使用全局扫描进行价格采集。|r

搜索或扫描后，插件会自动采集和记录市场在售最低价与历史价格，拍卖的物品价格才会准确！

|cff00bfff2、快速上架与价格参考|r
切换到【拍卖】页面，把物品拖入上架栏，会自动弹出历史价格，点击可一键填入单价。
支持自动压价、跟价、复制价格、一键上架等。

|cff00bfff3、价格数据库与走势|r
点击【价格库】可浏览所有采集过的物品历史价格、最低价、日K线走势图等。

|cff00bfff4、商机发现|r
在价格库内可通过“寻找商机”快速筛选低于市场价、套利空间大的物品，辅助倒买倒卖。

|cff00bfff5、常用与最近|r
插件自动记录最近搜索与常用物品，便于下次一键查询或上架。

|cff00bfff6、狙击低价物品|r
狙击用于盯住你关心的物品，只在价格低于你设置的最高单价时提醒或购买。

- 添加目标：在最近搜索或常用列表里右键物品，选择“加入狙击物品列表”
- 设置价格：打开【狙击】页，点【狙击设置】，给每个物品填写能接受的最高单价
- 开始寻找：回到【狙击】页搜索/扫描，插件会匹配狙击列表里的低价拍卖
- 直接购买：确认价格低于封顶价后，可用“狙击瞬秒”快速一口价购买
- 参与竞价：想压低成本时，可设置竞价折扣比例，再查看竞价结果继续出价

|cffff4040提示：|r狙击列表默认最多保存50个物品。建议先设好购买风险限制，避免误买高价或数量异常的拍卖。

|cffff8800常用命令|r
|cffffde00/epah|r —— 打开价格数据库界面
|cffffde00/epsp|r —— 开关物品鼠标提示中的价格与分解信息

|cffff8800小技巧|r
- 建议在背包中Shift+左键背包物品自动填入搜索框进行搜索
- 待售库存列表中，左键复制，右键快速上架或移除常用
- “开始拍卖”按钮支持宏调用 /click EasyAuctionStartBtn

|cffff4040注意事项|r
- 价格仅供参考，谨慎定价，避免被低价误导
- 拍卖行长时间未刷新建议点“刷新”获取新价
- 如遇界面卡顿、冲突可用“极简模式”排查插件冲突

|cff00ff00EasyAuction|r —— 专注简洁高效的拍卖体验！
]]

local ROWS_NUM = 12
local currentPage = 1
local totalPages = 1
local dbItemList = {}
local prevBtn = CreateFrame("Button", nil, DBFrame, "UIPanelButtonTemplate")
prevBtn:SetSize(60, 22)
prevBtn:SetPoint("BOTTOMRIGHT", DBFrame, "BOTTOMRIGHT", -154, DB_FOOTER_Y)
prevBtn:SetText("上一页")
EA_StyleButton(prevBtn)
prevBtn:Hide()

local nextBtn = CreateFrame("Button", nil, DBFrame, "UIPanelButtonTemplate")
nextBtn:SetSize(60, 22)
nextBtn:SetPoint("LEFT", prevBtn, "RIGHT", 6, 0)
nextBtn:SetText("下一页")
EA_StyleButton(nextBtn)
nextBtn:Hide()

local pageText = DBFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
pageText:SetPoint("RIGHT", prevBtn, "LEFT", -8, 0)
pageText:SetText("")
EA_StyleText(pageText, "muted")

EA_LayoutDBFrameControls = function()
    if not DBFrame then return end
    local title = _G["EasyAuctionDBFrameTitle"]
    if title then
        title:ClearAllPoints()
        title:SetPoint("TOPLEFT", DBFrame, "TOPLEFT", 14, -14)
        title:SetWidth(DBFrame.EasyAuctionBagValueButton and (DB_SEARCH_COMPACT_LEFT - 28) or 260)
        title:SetJustifyH("LEFT")
        title:SetWordWrap(false)
    end
    resetBtn:ClearAllPoints()
    resetBtn:SetPoint("TOPRIGHT", DBFrame, "TOPRIGHT", -44, -14)
    if DBFrame.EA_CategoryManageBtn then
        DBFrame.EA_CategoryManageBtn:ClearAllPoints()
        DBFrame.EA_CategoryManageBtn:SetPoint("RIGHT", resetBtn, "LEFT", -6, 0)
        EA_StyleButton(DBFrame.EA_CategoryManageBtn)
    end
    if opportunityBtn then
        opportunityBtn:ClearAllPoints()
        local anchor = DBFrame.EA_CategoryManageBtn or resetBtn
        opportunityBtn:SetPoint("RIGHT", anchor, "LEFT", -6, 0)
        EA_StyleButton(opportunityBtn)
    end
    if DBFrame.EA_ExportBtn then
        DBFrame.EA_ExportBtn:ClearAllPoints()
        local anchor = opportunityBtn or DBFrame.EA_CategoryManageBtn or resetBtn
        DBFrame.EA_ExportBtn:SetPoint("RIGHT", anchor, "LEFT", -6, 0)
        EA_StyleButton(DBFrame.EA_ExportBtn)
    end
    if searchEditBox then
        EA_LayoutDBSearchBox()
    end
    if DBFrame.EA_CategoryReturnBtn then
        DBFrame.EA_CategoryReturnBtn:ClearAllPoints()
        DBFrame.EA_CategoryReturnBtn:SetPoint("BOTTOMLEFT", DBFrame, "BOTTOMLEFT", 16, DB_FOOTER_Y)
        EA_StyleButton(DBFrame.EA_CategoryReturnBtn)
    end
    if DBFrame.EA_CategoryBtns then
        for i, btn in ipairs(DBFrame.EA_CategoryBtns) do
            btn:ClearAllPoints()
            if i == 1 then
                btn:SetPoint("LEFT", DBFrame.EA_CategoryReturnBtn, "RIGHT", 4, 0)
            else
                btn:SetPoint("LEFT", DBFrame.EA_CategoryBtns[i - 1], "RIGHT", 4, 0)
            end
            EA_StyleButton(btn)
        end
    end
    prevBtn:ClearAllPoints()
    prevBtn:SetPoint("BOTTOMRIGHT", DBFrame, "BOTTOMRIGHT", -154, DB_FOOTER_Y)
    nextBtn:ClearAllPoints()
    nextBtn:SetPoint("LEFT", prevBtn, "RIGHT", 6, 0)
    pageText:ClearAllPoints()
    pageText:SetPoint("RIGHT", prevBtn, "LEFT", -8, 0)
end

_G.EasyAuction_LayoutDBFrameControls = EA_LayoutDBFrameControls

DBFrame.rows = DBFrame.rows or {}
for i = 1, ROWS_NUM do
    if not DBFrame.rows[i] then
        local btn = CreateFrame("Button", nil, DBFrame)
        btn:SetSize(DB_ROW_WIDTH, DB_ROW_HEIGHT)
        btn:SetPoint("TOPLEFT", DBFrame, "TOPLEFT", DB_TABLE_LEFT, DB_TABLE_TOP - (i - 1) * (DB_ROW_HEIGHT + DB_ROW_GAP))
        btn:SetFrameLevel(DBFrame:GetFrameLevel() + 10)
        EA_StyleRowHighlight(btn)
        btn:Hide()
        btn.cols = {}

        for j, col in ipairs(normalHeaders) do
            local fs = btn:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            EA_StyleText(fs, j == 2 and "text" or "muted")
            btn.cols[j] = fs
            fs:SetWidth(col.width)
            if j == 1 then
                fs:SetPoint("LEFT", btn, "LEFT", 0, 0)
            elseif j == 2 then
                fs:SetPoint("LEFT", btn, "LEFT", 4, 0)
                fs.clickBtn = CreateFrame("Button", nil, btn)
                fs.clickBtn:SetAllPoints(fs)
                fs.clickBtn:SetFrameLevel(btn:GetFrameLevel() + 5)
                fs.clickBtn:EnableMouse(true)
                fs.clickBtn:RegisterForClicks("LeftButtonUp")
                fs.clickBtn:Hide()
                fs:SetWordWrap(false)
                fs:SetNonSpaceWrap(false)
                if fs.SetEllipsizeMode then
                    fs:SetEllipsizeMode("END")
                end
            elseif j == 2 or j == 4 or j == 5 or j == 7 then
                fs:SetJustifyH("RIGHT")
                fs:SetFont(GameFontHighlightSmall:GetFont(), 12)
            else
                fs:SetPoint("LEFT", btn.cols[j - 1], "RIGHT", 4, 0)
            end
            if j == 1 then
                fs:SetJustifyH("CENTER")
            elseif j == 2 then
                fs:SetJustifyH("LEFT")
            elseif j == #normalHeaders or j == #normalHeaders - 1 then
                fs:SetJustifyH("CENTER")
            else
                fs:SetJustifyH("RIGHT")
            end
        end

        DBFrame.rows[i] = btn
    end
end

local function EA_StyleDBTableRow(row, headers)
    if not row or not headers then return end
    if row.sep then row.sep:Hide() end
    if row.seps then
        for _, sep in ipairs(row.seps) do
            if sep then sep:Hide() end
        end
    end
    local top = EA_AddBoxLine(row, "top", "horizontal")
    top:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    local bottom = EA_AddBoxLine(row, "bottom", "horizontal")
    bottom:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    local left = EA_AddBoxLine(row, "left", "vertical")
    left:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    local right = EA_AddBoxLine(row, "right", "vertical")
    right:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)

    row.EA_ColLines = row.EA_ColLines or {}
    for j = 1, #headers - 1 do
        local cell = row.cols and row.cols[j]
        local sep = row.EA_ColLines[j]
        if not sep then
            sep = row:CreateTexture(nil, "OVERLAY")
            sep:SetTexture("Interface\\Buttons\\WHITE8X8")
            sep:SetWidth(1)
            row.EA_ColLines[j] = sep
            if EAStyle then
                sep.EA_ThemeHooked = true
                EAStyle:OnTheme(function(p)
                    sep:SetColorTexture(p.border[1], p.border[2], p.border[3], 0.55)
                end)
            end
        end
        sep:ClearAllPoints()
        if cell then
            sep:SetPoint("TOPLEFT", cell, "TOPRIGHT", 0, 0)
            sep:SetPoint("BOTTOMLEFT", cell, "BOTTOMRIGHT", 0, 0)
        end
        if not EAStyle then
            sep:SetColorTexture(0.45, 0.45, 0.50, 0.55)
        end
        sep:Show()
    end
end

CurrentSearchText = ""

local function EasyAuction_CreateDBSearchBox()
    if not DBFrame or searchEditBox then return end

    searchEditBox = CreateFrame("EditBox", "EasyAuctionDBSearchBox", DBFrame, "InputBoxTemplate")
    searchEditBox:SetSize(DB_SEARCH_FALLBACK_WIDTH, 22)
    searchEditBox:SetAutoFocus(false)
    searchEditBox:SetPoint("TOPLEFT", DBFrame, "TOPLEFT", DB_SEARCH_LEFT, -14)
    searchEditBox:SetFontObject(ChatFontNormal)
    searchEditBox:SetTextInsets(8, 8, 0, 0)
    searchEditBox:SetMaxLetters(60)
    searchEditBox:SetText("")
    EA_StyleEditBox(searchEditBox)
    searchEditBox:Show()
    EA_LayoutDBFrameControls()
    searchEditBox.placeholder = searchEditBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    searchEditBox.placeholder:SetPoint("LEFT", searchEditBox, "LEFT", 10, 0)
    searchEditBox.placeholder:SetText("输入物品名快速查找")
    EA_StyleText(searchEditBox.placeholder, "muted")

    searchEditBox:SetScript("OnTextChanged", function(self)
        local txt = self:GetText() or ""
        if txt == "" then
            searchEditBox.placeholder:Show()
        else
            searchEditBox.placeholder:Hide()
        end
        CurrentSearchText = txt or ""
        EA_MarkDBItemListDirty()
        if EA_CategoryMode then
            EA_ShowCategory(EA_CategoryMode, 1, txt)
        else
            RefreshDBFrame()
        end
    end)
    searchEditBox:SetScript("OnEditFocusGained", function(self)
        if self:GetText() == "" then
            searchEditBox.placeholder:Show()
        end
    end)
    searchEditBox:SetScript("OnEditFocusLost", function(self)
        if self:GetText() == "" then
            searchEditBox.placeholder:Show()
        end
    end)
end

DBFrame:HookScript("OnShow", function()
    EasyAuction_CreateDBSearchBox()
    EA_LayoutDBFrameControls()
    if searchEditBox then
        searchEditBox:SetText(CurrentSearchText or "")
        searchEditBox.placeholder:SetShown((CurrentSearchText or "") == "")
    end
end)

local function BuildDBItemList()
    if not EA_DBItemListDirty then return end -- 列表未脏直接复用，翻页/重绘不重建
    EA_DBItemListDirty = false
    local db = _G.EasyAuctionDB or EasyAuctionDB
    dbItemList = {}
    if type(db) ~= "table" then
        totalPages = 1
        return
    end
    db.PriceHistory = db.PriceHistory or {}
    local filter = (CurrentSearchText or ""):lower()
    local idx = 0
    local itemID2Titan = EA_GetCategoryTitanMap()
    local uniqueKeys = {}
    for name, data in pairs(db.PriceHistory) do
        if filter == "" or tostring(name):lower():find(filter, 1, true) then
            if not uniqueKeys[name] then
                uniqueKeys[name] = true
                local stats = EA_GetHistoryListStats(name)
                local min = stats.minUnit
                local t = stats.latestTime
                local minHistory = stats.historyMin
                local _, itemID = tostring(name):match("^(.-):(%d+)$")
                local foundItemID = tonumber(itemID)

                if min and foundItemID then
                    idx = idx + 1
                    local snapshotCount = stats.snapshotCount or 0
                    local key = name
                    local titan, titanValue, titanValueRaw
                    titan = itemID2Titan[foundItemID]
                    if titan and tonumber(titan) > 0 and min > 0 then
                        titanValueRaw = min / titan
                        titanValue = FormatGoldIcon(math.floor(titanValueRaw + 0.5))
                    end

                    dbItemList[#dbItemList + 1] = {
                        idx = idx,
                        name = name, -- 现在就是 name:itemid 格式
                        num = snapshotCount,
                        snapshot = snapshotCount,
                        history = minHistory,
                        min = min,
                        t = t,
                        data = data,
                        link = nil, -- link 已移除
                        titan = titan or "-",
                        titanValue = titanValue or "-",
                        titanValueRaw = titanValueRaw,
                    }
                end
            end
        end
    end
    table.sort(dbItemList, function(a, b)
        local key = currentSortKey
        if key == "name" then
            if currentSortReverse then
                return (a.name or "") > (b.name or "")
            else
                return (a.name or "") < (b.name or "")
            end
        elseif key == "num" or key == "snapshot" then
            local sa, sb = a.snapshot or 0, b.snapshot or 0
            if currentSortReverse then
                return sa > sb
            else
                return sa < sb
            end
        elseif key == "history" then
            if currentSortReverse then
                return (a.history or 0) > (b.history or 0)
            else
                return (a.history or 0) < (b.history or 0)
            end
        elseif key == "min" then
            if currentSortReverse then
                return (a.min or 0) > (b.min or 0)
            else
                return (a.min or 0) < (b.min or 0)
            end
        elseif key == "titan" then
            if currentSortReverse then
                return (tonumber(a.titan) or 0) > (tonumber(b.titan) or 0)
            else
                return (tonumber(a.titan) or 0) < (tonumber(b.titan) or 0)
            end
        elseif key == "titanValue" then
            local va = tonumber(a.titanValueRaw) or 0
            local vb = tonumber(b.titanValueRaw) or 0
            if currentSortReverse then
                return va > vb
            else
                return va < vb
            end
        elseif key == "t" then
            if currentSortReverse then
                return (a.t or 0) > (b.t or 0)
            else
                return (a.t or 0) < (b.t or 0)
            end
        else
            return (a.t or 0) > (b.t or 0)
        end
    end)
    totalPages = math.max(1, math.ceil(#dbItemList / ROWS_NUM))
end

function RefreshDBFrame()
    if EA_CategoryMode then
        EA_ShowCategory(EA_CategoryMode, EA_CategoryCurrentPage, CurrentSearchText)
        return
    end

    if DBFrame.EA_CategoryHeaderBtns then
        for _, btn in ipairs(DBFrame.EA_CategoryHeaderBtns) do btn:Hide() end
    end

    if searchEditBox then searchEditBox:Show() end
    if resetBtn then resetBtn:Show() end
    if opportunityBtn then opportunityBtn:Show() end

    if not DBFrame.NormalHeaderBtns then DBFrame.NormalHeaderBtns = {} end
    for j, col in ipairs(normalHeaders) do
        local btn = DBFrame.NormalHeaderBtns[j]
        if not btn then
            btn = CreateFrame("Button", nil, DBFrame)
            btn:SetSize(col.width, 24)
            btn:SetFrameLevel(DBFrame:GetFrameLevel() + 10)
            if j == 1 then
                btn:SetPoint("TOPLEFT", DBFrame, "TOPLEFT", DB_TABLE_LEFT, DB_HEADER_TOP)
            else
                btn:SetPoint("LEFT", DBFrame.NormalHeaderBtns[j - 1], "RIGHT", 0, 0)
            end
            btn.bg = btn:CreateTexture(nil, "BACKGROUND")
            btn.bg:SetAllPoints()
            EA_StyleRow(btn.bg, j, true)
            EA_StyleRowHighlight(btn)

            btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            btn.text:SetPoint("CENTER")
            btn.text:SetJustifyH("CENTER")
            btn.text:SetWidth(col.width)
            btn.text:Show()
            EA_StyleText(btn.text, "accent")

            btn.sep = btn:CreateTexture(nil, "OVERLAY")
            if EAStyle then
                EAStyle:OnTheme(function(p)
                    btn.sep:SetColorTexture(p.border[1], p.border[2], p.border[3], 0.7)
                end)
            else
                btn.sep:SetColorTexture(0.7, 0.7, 0.7, 0.7)
            end
            btn.sep:SetWidth(1)
            btn.sep:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, -2)
            btn.sep:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 2)
            btn.sep:Show()

            DBFrame.NormalHeaderBtns[j] = btn
        end
        if j == #normalHeaders then
            btn.sep:Hide()
        else
            btn.sep:Show()
        end
        EA_StyleDBTableRow(btn, normalHeaders)

        btn:EnableMouse(true)
        btn:SetScript("OnEnter", function(self)
            EA_StyleRow(self.bg, j, true)
        end)
        btn:SetScript("OnLeave", function(self)
            EA_StyleRow(self.bg, j, true)
        end)
        if col.key and col.key ~= "action" then
            btn:SetScript("OnClick", function()
                if currentSortKey == col.key then
                    currentSortReverse = not currentSortReverse
                else
                    currentSortKey = col.key
                    currentSortReverse = false
                end
                EA_MarkDBItemListDirty()
                RefreshDBFrame()
            end)
        else
            btn:SetScript("OnClick", nil)
        end
        local arrow = (currentSortKey == col.key and col.key ~= "action") and
            (currentSortReverse and " ▼" or " ▲") or ""
        btn.text:SetText(col.name .. arrow)
        btn.text:Show()
        btn:Show()
    end

    BuildDBItemList()
    if currentPage > totalPages then currentPage = totalPages end
    if currentPage < 1 then currentPage = 1 end
    local start = (currentPage - 1) * ROWS_NUM + 1

    for i = 1, ROWS_NUM do
        local row = DBFrame.rows[i]
        local item = dbItemList[start + i - 1]

        if not row.bg then
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
        end
        if i % 2 == 1 then
            EA_StyleRow(row.bg, i, false)
        else
            EA_StyleRow(row.bg, i, false)
        end

        row:EnableMouse(true)
        row:SetScript("OnEnter", function(self)
            if self.bg then EA_StyleRow(self.bg, i, true) end
            self:LockHighlight()
        end)
        row:SetScript("OnLeave", function(self)
            if self.bg then EA_StyleRow(self.bg, i, false) end
            self:UnlockHighlight()
        end)

        for j, col in ipairs(normalHeaders) do
            local cell = row.cols[j]
            if not cell then
                cell = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
                row.cols[j] = cell
            end
            cell:ClearAllPoints()
            if j == 1 then
                cell:SetPoint("LEFT", row, "LEFT", 0, 0)
            else
                cell:SetPoint("LEFT", row.cols[j - 1], "RIGHT", 0, 0)
            end
            cell:SetWidth(col.width)
            if j == 1 then
                cell:SetJustifyH("CENTER")
            elseif j == 2 then
                cell:SetJustifyH("LEFT")
            elseif j == 3 or j == 4 or j == 5 or j == 6 or j == 7 then
                cell:SetJustifyH("RIGHT")
            elseif j == 8 then
                cell:SetJustifyH("CENTER")
            else
                cell:SetJustifyH("CENTER")
            end
            if not row.seps then row.seps = {} end
            if not row.seps[j] then
                local sep = row:CreateTexture(nil, "OVERLAY")
                if EAStyle then
                    EAStyle:OnTheme(function(p)
                        sep:SetColorTexture(p.border[1], p.border[2], p.border[3], 0.35)
                    end)
                else
                    sep:SetColorTexture(0.8, 0.8, 0.8, 0.5)
                end
                sep:SetWidth(1)
                sep:SetPoint("TOPLEFT", cell, "TOPRIGHT", 2, 0)
                sep:SetPoint("BOTTOMLEFT", cell, "BOTTOMRIGHT", 2, 0)
                row.seps[j] = sep
            end
            if j == 1 or j == #normalHeaders then
                row.seps[j]:Hide()
            else
                row.seps[j]:Show()
            end
        end
        EA_StyleDBTableRow(row, normalHeaders)

        if item then
            row:Show()
            row.cols[1]:SetText(tostring(start + i - 1))

            -- icon和物品名：由 item.name 拆分
            local rName, itemID = tostring(item.name):match("^(.-):(%d+)$")
            itemID = tonumber(itemID)
            local icon = ""
            if itemID then
                local iconPath = GetItemIcon(itemID)
                if iconPath then
                    icon = "|T" .. iconPath .. ":16:16:0:0|t "
                end
            end
            -- 物品名显示
            row.cols[2]:SetText(icon .. ColorName(rName or "?", itemID))
            row.itemData = item

            -- 点击按钮逻辑
            if row.cols[2].clickBtn then
                row.cols[2].clickBtn:Show()
                row.cols[2].clickBtn:SetScript("OnClick", function(self, button)
                    local thisItem = row.itemData
                    if button == "LeftButton" and thisItem then
                        ShowPriceFrame(thisItem.name, thisItem.data)
                    end
                end)
                row.cols[2].clickBtn:SetScript("OnEnter", function(self)
                    if row.bg then EA_StyleRow(row.bg, row.__eaIndex or i, true) end
                    local thisItem = row.itemData
                    local name = (thisItem and (thisItem.name or "")) or row.cols[2]:GetText()
                    local itemID = thisItem and
                        (thisItem.itemid or (thisItem.name and tostring(thisItem.name):match(":(%d+)$")))
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    if itemID then
                        local link = itemID and select(2, GetItemInfo(itemID)) or nil
                        if link then
                            GameTooltip:SetHyperlink(link)
                        else
                            GameTooltip:SetText(name, 1, 1, 1)
                        end
                    else
                        GameTooltip:SetText(name, 1, 1, 1)
                    end
                    if thisItem and thisItem.t then
                        GameTooltip:AddLine("采集时间：" .. date("%Y-%m-%d %H:%M", thisItem.t), 0.7, 0.7, 0.7)
                    end
                    GameTooltip:Show()
                end)
                row.cols[2].clickBtn:SetScript("OnLeave", function(self)
                    if row.bg then EA_StyleRow(row.bg, row.__eaIndex or i, false) end
                    GameTooltip:Hide()
                end)
            end

            -- 统计数、历史最低、最新单价等
            local snapshotCount = 0
            local today = date("%Y-%m-%d")
            local key = item.name
            local dailyData = EasyAuction_GetDailyMinPrice(key, EasyAuctionDB)
            local history = EasyAuction_GetPriceHistory(key, EasyAuctionDB)
            if dailyData then
                for _, record in ipairs(dailyData) do
                    if record[1] == today then
                        snapshotCount = record[6] or 0
                        break
                    end
                end
            end
            if snapshotCount == 0 and history then
                for _, v in ipairs(history) do
                    snapshotCount = snapshotCount + (v.count or 1)
                end
            end
            local minHistory = EasyAuction_GetPriceHistoryMinUnit(item.name, EasyAuctionDB)
            for _, v in ipairs(EasyAuction_GetPriceHistory(item.name, EasyAuctionDB)) do
                if not minHistory or v.unit < minHistory then
                    minHistory = v.unit
                end
            end
            row.cols[3]:SetText(snapshotCount > 0 and tostring(snapshotCount) or "-")
            row.cols[4]:SetText(minHistory and FormatGoldIcon(minHistory) or "-")
            row.cols[5]:SetText(FormatGoldIcon(item.min))
            row.cols[6]:SetText(item.titan or "-")
            row.cols[7]:SetText(item.titanValue or "-")
            row.cols[8]:SetText(item.t and EA_GetShortTime(item.t) or "-")
            if not row.trendBtn then
                row.trendBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                row.trendBtn:SetSize(50, 20)
                row.trendBtn:SetText("走势")
                EA_StyleButton(row.trendBtn)
            end
            row.trendBtn:ClearAllPoints()
            row.trendBtn:SetPoint("LEFT", row.cols[8], "RIGHT", 8, 0)
            row.trendBtn:Show()
            row.trendBtn:SetEnabled(item.min and item.min > 0)
            row.trendBtn:SetScript("OnClick", function()
                EasyAuction_ShowChart(item.name)
            end)
            row.cols[9]:SetText("")
            row.cols[9]:Show()
        else
            row:Hide()
            if row.trendBtn then row.trendBtn:Hide() end
        end
    end

    prevBtn:SetShown(totalPages > 1)
    nextBtn:SetShown(totalPages > 1)
    prevBtn:SetEnabled(currentPage > 1)
    nextBtn:SetEnabled(currentPage < totalPages)
    pageText:SetText(string.format("第%d/%d页", currentPage, totalPages))
    prevBtn:SetScript("OnClick", function()
        if currentPage > 1 then
            currentPage = currentPage - 1
            RefreshDBFrame()
        end
    end)
    nextBtn:SetScript("OnClick", function()
        if currentPage < totalPages then
            currentPage = currentPage + 1
            RefreshDBFrame()
        end
    end)
    EasyAuction_UpdateCategoryButtonHighlight()
end

resetBtn:SetScript("OnClick", function()
    StaticPopupDialogs["EASYAUCTION_RESET_DB"] = {
        text = "|cffff4040警告|r\n\n确定要清空所有拍卖历史记录和设置吗？\n此操作不可恢复。",
        button1 = "确定",
        button2 = "取消",
        OnAccept = function()
            local newDB, resetError = EasyAuction_ResetSavedVariables(true)
            if not newDB then
                print("|cffff4040EasyAuction|r：" .. tostring(resetError and resetError.message
                    or "当前无法重置插件。"))
                return
            end
            EasyAuctionDB = newDB
            print("|cff00ff00EasyAuction|r：所有设置与历史数据已重置，正在重载界面。")
            if type(ReloadUI) == "function" then ReloadUI() end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("EASYAUCTION_RESET_DB")
end)

prevBtn:SetScript("OnClick", function()
    if currentPage > 1 then
        currentPage = currentPage - 1
        RefreshDBFrame()
    end
end)

nextBtn:SetScript("OnClick", function()
    if currentPage < totalPages then
        currentPage = currentPage + 1
        RefreshDBFrame()
    end
end)

DBFrame:EnableMouseWheel(true)
DBFrame:SetScript("OnMouseWheel", function(self, delta)
    if delta < 0 and currentPage < totalPages then
        currentPage = currentPage + 1
        RefreshDBFrame()
    elseif delta > 0 and currentPage > 1 then
        currentPage = currentPage - 1
        RefreshDBFrame()
    end
end)

function EasyAuction_OpenDBFrame()
    currentPage = 1
    EA_ActiveCategory = nil
    RefreshDBFrame()
    EasyAuction_UpdateCategoryButtonHighlight()
    DBFrame:Show()
end

local itemInfoFrame = CreateFrame("Frame")
itemInfoFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
-- 物品信息到达事件触发频繁，0.2 秒防抖合并刷新，避免连续全量重建
EA_ItemInfoRefreshPending = false
itemInfoFrame:SetScript("OnEvent", function(_, _, itemID, success)
    if not success or not DBFrame or not DBFrame:IsShown() then return end
    if EA_ItemInfoRefreshPending then return end
    EA_ItemInfoRefreshPending = true
    C_Timer.After(0.2, function()
        EA_ItemInfoRefreshPending = false
        if DBFrame and DBFrame:IsShown() then
            RefreshDBFrame()
        end
    end)
end)

SLASH_EasyAuctionDB1 = "/epah"
SlashCmdList["EasyAuctionDB"] = function()
    EasyAuction_OpenDBFrame()
end

SLASH_EasyAuctionShowPrice1 = "/epsp"
SlashCmdList["EasyAuctionShowPrice"] = function()
    EasyAuctionDB.ShowPrice = not EasyAuctionDB.ShowPrice
    print("|cff00ff00[EasyAuction]|r 鼠标提示价格显示已" .. (EasyAuctionDB.ShowPrice and "开启" or "关闭"))
end

local EA_CATEGORIES = { "全类", "矿石", "草药", "附魔", "珠宝", "布皮", "元素", "药剂", "鱼类", "常用" }

local EA_CategoryHeaderBtns = {}

function EA_GetShortTime(ts)
    local diff = time() - (ts or 0)
    if diff < 3600 then
        return string.format("%d分钟前", math.floor(diff / 60))
    elseif diff < 86400 then
        return string.format("%d小时前", math.floor(diff / 3600))
    else
        return string.format("%d天前", math.floor(diff / 86400))
    end
end

function EasyAuction_UpdateCategoryButtonHighlight()
    for cat, btn in pairs(DBFrame.EA_CategoryBtnsByCat or {}) do
        if EAStyle then
            EAStyle:SetButtonActive(btn, EA_ActiveCategory == cat)
        elseif btn:GetFontString() then
            btn:GetFontString():SetTextColor(EA_ActiveCategory == cat and 0.2 or 1, EA_ActiveCategory == cat and 0.8 or 1, 1, 1)
        end
    end
    if DBFrame.EA_CategoryReturnBtn then
        if EAStyle then
            EAStyle:SetButtonActive(DBFrame.EA_CategoryReturnBtn, EA_ActiveCategory == nil)
        end
    end
    if DBFrame.EA_CategoryManageBtn then
        local canManage = EA_CategoryMode and EA_CategoryMode ~= "全类"
        DBFrame.EA_CategoryManageBtn:SetEnabled(canManage and true or false)
        DBFrame.EA_CategoryManageBtn:SetAlpha(canManage and 1 or 0.6)
    end
    if DBFrame.EA_ExportBtn then
        DBFrame.EA_ExportBtn:SetEnabled(true)
        DBFrame.EA_ExportBtn:SetAlpha(1)
    end
end

DBFrame:HookScript("OnShow", function()
    if not DBFrame.EA_CategoryBtns then
        DBFrame.EA_CategoryBtns = {}
        DBFrame.EA_CategoryBtnsByCat = {}
        local btnWidth, btnHeight = 48, 22
        local btnSpacing = 4
        for i, cat in ipairs(EA_CATEGORIES) do
            local btn = CreateFrame("Button", nil, DBFrame, "UIPanelButtonTemplate")
            btn:SetSize(btnWidth, btnHeight)
            btn:SetText(cat)
            EA_StyleButton(btn)
            if i == 1 then
                btn:SetPoint("LEFT", DBFrame.EA_CategoryReturnBtn, "RIGHT", btnSpacing, 0)
            else
                btn:SetPoint("LEFT", DBFrame.EA_CategoryBtns[i - 1], "RIGHT", btnSpacing, 0)
            end
            btn:SetScript("OnClick", function()
                EA_ActiveCategory = cat
                EA_ShowCategory(cat, 1, CurrentSearchText)
                EasyAuction_UpdateCategoryButtonHighlight()
            end)
            DBFrame.EA_CategoryBtns[i] = btn
            DBFrame.EA_CategoryBtnsByCat[cat] = btn
        end
    end
    for _, btn in ipairs(DBFrame.EA_CategoryBtns) do btn:Show() end
    EA_LayoutDBFrameControls()
end)
DBFrame:HookScript("OnHide", function()
    if DBFrame.EA_CategoryBtns then for _, btn in ipairs(DBFrame.EA_CategoryBtns) do btn:Hide() end end
    if EA_CategoryHeaderBtns then for _, btn in ipairs(EA_CategoryHeaderBtns) do btn:Hide() end end
end)

if not DBFrame.EA_CategoryReturnBtn then
    DBFrame.EA_CategoryReturnBtn = CreateFrame("Button", nil, DBFrame, "UIPanelButtonTemplate")
    DBFrame.EA_CategoryReturnBtn:SetSize(60, 22)
    DBFrame.EA_CategoryReturnBtn:SetPoint("BOTTOMLEFT", DBFrame, "BOTTOMLEFT", 16, DB_FOOTER_Y)
    DBFrame.EA_CategoryReturnBtn:SetText("首页")
    EA_StyleButton(DBFrame.EA_CategoryReturnBtn)
    DBFrame.EA_CategoryReturnBtn:SetScript("OnClick", function()
        EA_CategoryMode = nil
        EA_ActiveCategory = nil
        if DBFrame.EA_CategoryHeaderFS then DBFrame.EA_CategoryHeaderFS:Hide() end
        if EA_CategoryHeaderBtns then for _, btn in ipairs(EA_CategoryHeaderBtns) do btn:Hide() end end
        RefreshDBFrame()
        EasyAuction_UpdateCategoryButtonHighlight()
    end)
end
DBFrame.EA_CategoryReturnBtn:Show()

local function EA_BuildCategoryEditorText(cat)
    local lines = {}
    for _, info in ipairs(EA_GetCategoryEntries(cat)) do
        local titan = tonumber(info[3]) or 0
        if titan > 0 then
            lines[#lines + 1] = string.format("%d,%s,%d", tonumber(info[2]) or 0, tostring(info[1] or ""), titan)
        else
            lines[#lines + 1] = string.format("%d,%s", tonumber(info[2]) or 0, tostring(info[1] or ""))
        end
    end
    return table.concat(lines, "\n")
end

local function EA_BuildCategoryEditorTextFromEntries(entries)
    local lines = {}
    for _, info in ipairs(entries or {}) do
        local titan = tonumber(info[3]) or 0
        if titan > 0 then
            lines[#lines + 1] = string.format("%d,%s,%d", tonumber(info[2]) or 0, tostring(info[1] or ""), titan)
        else
            lines[#lines + 1] = string.format("%d,%s", tonumber(info[2]) or 0, tostring(info[1] or ""))
        end
    end
    return table.concat(lines, "\n")
end

local function EA_ParseCategoryEditorText(text)
    local entries = {}
    local indexByID = {}
    local errorLine = nil
    text = tostring(text or ""):gsub("，", ",")
    for line in text:gmatch("[^\r\n]+") do
        local cleanLine = EA_TrimText(line)
        if cleanLine ~= "" then
            local itemID, itemName, titan = cleanLine:match("^(%d+)%s*,%s*([^,]+)%s*,%s*(%-?%d+)%s*$")
            if not itemID then
                itemID, itemName = cleanLine:match("^(%d+)%s*,%s*(.+)%s*$")
            end
            local entry = EA_SanitizeCategoryEntry(itemName, itemID, titan)
            if not entry then
                errorLine = cleanLine
                break
            end
            local itemKey = tonumber(entry[2])
            if indexByID[itemKey] then
                entries[indexByID[itemKey]] = entry
            else
                indexByID[itemKey] = #entries + 1
                entries[#entries + 1] = entry
            end
        end
    end
    return entries, errorLine
end

local function EA_RefreshCategoryViewsAfterEdit(cat)
    if EasyAuctionDBFrame and EasyAuctionDBFrame:IsShown() then
        if cat and EA_CategoryMode == cat then
            EA_ShowCategory(cat, 1, CurrentSearchText)
        else
            RefreshDBFrame()
        end
    end
    if cat == "常用" and type(RefreshFavoriteRows) == "function" then
        RefreshFavoriteRows()
    end
end

function EasyAuction_ShowCategoryManager(cat)
    cat = cat or EA_CategoryMode
    if not cat or cat == "全类" then
        print("|cffff0000[EasyAuction]|r 请先在价格库选择一个具体分类。")
        return
    end

    if not EasyAuctionCategoryManagerFrame then
        local f = CreateFrame("Frame", "EasyAuctionCategoryManagerFrame", UIParent, "BackdropTemplate")
        f:SetSize(448, 486)
        f:SetPoint("CENTER")
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        EA_StyleDialog(f, "分类管理", 448, 486)
        tinsert(UISpecialFrames, "EasyAuctionCategoryManagerFrame")

        local title = f.EA_Title
        f.title = title

        local desc = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        desc:SetPoint("TOPLEFT", 18, -40)
        desc:SetPoint("RIGHT", -18, 0)
        desc:SetJustifyH("LEFT")
        desc:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
        EA_StyleText(desc, "muted")
        desc:SetText("每行格式：物品ID,物品名[,碎片数]。添加可用上方输入，删除可直接删掉对应行后保存。")
        f.desc = desc

        local inputPanel = CreateFrame("Frame", nil, f, "BackdropTemplate")
        inputPanel:SetPoint("TOPLEFT", 18, -76)
        inputPanel:SetPoint("TOPRIGHT", -18, -76)
        inputPanel:SetHeight(66)
        EA_StylePanel(inputPanel, "panel")

        local idLabel = inputPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        idLabel:SetPoint("TOPLEFT", inputPanel, "TOPLEFT", 10, -10)
        idLabel:SetText("物品ID")
        EA_StyleText(idLabel, "muted")

        local idEdit = CreateFrame("EditBox", nil, inputPanel, "InputBoxTemplate")
        idEdit:SetSize(78, 22)
        idEdit:SetPoint("LEFT", idLabel, "RIGHT", 6, 0)
        idEdit:SetAutoFocus(false)
        idEdit:SetNumeric(true)
        EA_StyleEditBox(idEdit)
        f.idEdit = idEdit

        local nameLabel = inputPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameLabel:SetPoint("LEFT", idEdit, "RIGHT", 12, 0)
        nameLabel:SetText("物品名")
        EA_StyleText(nameLabel, "muted")

        local nameEdit = CreateFrame("EditBox", nil, inputPanel, "InputBoxTemplate")
        nameEdit:SetSize(156, 22)
        nameEdit:SetPoint("LEFT", nameLabel, "RIGHT", 6, 0)
        nameEdit:SetAutoFocus(false)
        EA_StyleEditBox(nameEdit)
        f.nameEdit = nameEdit

        local titanLabel = inputPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        titanLabel:SetPoint("TOPLEFT", inputPanel, "TOPLEFT", 10, -38)
        titanLabel:SetText("碎片数")
        EA_StyleText(titanLabel, "muted")

        local titanEdit = CreateFrame("EditBox", nil, inputPanel, "InputBoxTemplate")
        titanEdit:SetSize(78, 22)
        titanEdit:SetPoint("LEFT", titanLabel, "RIGHT", 6, 0)
        titanEdit:SetAutoFocus(false)
        titanEdit:SetNumeric(true)
        titanEdit:SetText("0")
        EA_StyleEditBox(titanEdit)
        f.titanEdit = titanEdit

        local addBtn = CreateFrame("Button", nil, inputPanel, "UIPanelButtonTemplate")
        addBtn:SetSize(86, 22)
        addBtn:SetPoint("LEFT", titanEdit, "RIGHT", 12, 0)
        addBtn:SetText("添加/替换")
        EA_StyleButton(addBtn)
        f.addBtn = addBtn

        local contentBG = CreateFrame("Frame", nil, f, "BackdropTemplate")
        contentBG:SetPoint("TOPLEFT", 18, -150)
        contentBG:SetPoint("BOTTOMRIGHT", -18, 62)
        EA_StylePanel(contentBG, "plot")

        local scrollFrame = CreateFrame("ScrollFrame", nil, contentBG, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 8, -8)
        scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)

        local editBox = CreateFrame("EditBox", nil, scrollFrame)
        editBox:SetMultiLine(true)
        editBox:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
        editBox:SetAutoFocus(false)
        editBox:SetWidth(372)
        editBox:SetHeight(260)
        if editBox.SetTextColor and EAStyle then
            local p = EAStyle:Palette()
            editBox:SetTextColor(p.text[1], p.text[2], p.text[3], 1)
        end
        scrollFrame:SetScrollChild(editBox)
        f.editBox = editBox

        local warnBar = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        warnBar:SetPoint("BOTTOMLEFT", 18, 40)
        warnBar:SetPoint("RIGHT", -18, 0)
        warnBar:SetJustifyH("LEFT")
        warnBar:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
        EA_StyleText(warnBar, "warning")
        warnBar:SetText("")
        warnBar:Hide()
        f.warnBar = warnBar

        local saveBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        saveBtn:SetSize(72, 22)
        saveBtn:SetPoint("BOTTOMRIGHT", -18, 14)
        saveBtn:SetText("保存")
        EA_StyleButton(saveBtn)

        local resetBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        resetBtn:SetSize(72, 22)
        resetBtn:SetPoint("RIGHT", saveBtn, "LEFT", -6, 0)
        resetBtn:SetText("重置")
        EA_StyleButton(resetBtn)

        local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        closeBtn:SetSize(72, 22)
        closeBtn:SetPoint("RIGHT", resetBtn, "LEFT", -6, 0)
        closeBtn:SetText("关闭")
        EA_StyleButton(closeBtn)
        closeBtn:SetScript("OnClick", function()
            f:Hide()
        end)

        addBtn:SetScript("OnClick", function()
            local currentEntries, errorLine = EA_ParseCategoryEditorText(editBox:GetText())
            if errorLine then
                warnBar:SetText("|cffff4040存在格式错误行，先修正后再添加：|r" .. errorLine)
                warnBar:Show()
                return
            end
            local entry = EA_SanitizeCategoryEntry(nameEdit:GetText(), idEdit:GetText(), titanEdit:GetText())
            if not entry then
                warnBar:SetText("|cffff4040请输入有效的物品ID和物品名。|r")
                warnBar:Show()
                return
            end
            local replaced = false
            for index, info in ipairs(currentEntries) do
                if tonumber(info[2]) == tonumber(entry[2]) then
                    currentEntries[index] = entry
                    replaced = true
                    break
                end
            end
            if not replaced then
                currentEntries[#currentEntries + 1] = entry
            end
            editBox:SetText(EA_BuildCategoryEditorTextFromEntries(currentEntries))
            nameEdit:SetText("")
            idEdit:SetText("")
            titanEdit:SetText("0")
            warnBar:Hide()
        end)

        saveBtn:SetScript("OnClick", function()
            local entries, errorLine = EA_ParseCategoryEditorText(editBox:GetText())
            if errorLine then
                warnBar:SetText("|cffff4040保存失败，存在格式错误行：|r" .. errorLine)
                warnBar:Show()
                return
            end
            EA_SetCategoryEntries(f.category, entries)
            warnBar:Hide()
            EA_RefreshCategoryViewsAfterEdit(f.category)
            print(string.format("|cff00ff00[EasyAuction]|r [%s] 分类列表已保存，共 %d 项。", f.category, #entries))
            f:Hide()
        end)

        resetBtn:SetScript("OnClick", function()
            EA_ResetCategoryEntries(f.category)
            editBox:SetText(EA_BuildCategoryEditorText(f.category))
            warnBar:Hide()
            EA_RefreshCategoryViewsAfterEdit(f.category)
            if f.category == "常用" then
                print("|cff00ff00[EasyAuction]|r 常用清单已清空。")
            else
                print(string.format("|cff00ff00[EasyAuction]|r [%s] 分类已恢复默认列表。", f.category))
            end
        end)

        EasyAuctionCategoryManagerFrame = f
    end

    local frame = EasyAuctionCategoryManagerFrame
    frame.category = cat
    frame.title:SetText(string.format("%s - 分类管理", cat))
    if cat == "常用" then
        frame.desc:SetText("常用清单与闪购页共用同一份数据。每行格式：物品ID,物品名[,碎片数]。删除可直接删行后保存，重置会清空当前常用。")
    else
        frame.desc:SetText("每行格式：物品ID,物品名[,碎片数]。添加可用上方输入，删除可直接删掉对应行后保存，重置可恢复默认分类。")
    end
    frame.editBox:SetText(EA_BuildCategoryEditorText(cat))
    frame.warnBar:Hide()
    frame.idEdit:SetText("")
    frame.nameEdit:SetText("")
    frame.titanEdit:SetText("0")
    frame:Show()
end

local function EA_FormatPricePlain(copper)
    local value = tonumber(copper)
    if not value or value <= 0 then
        return ""
    end
    local gold = math.floor(value / 10000)
    local silver = math.floor((value % 10000) / 100)
    local copperOnly = value % 100
    if gold > 0 then
        return string.format("%dg%02ds%02dc", gold, silver, copperOnly)
    elseif silver > 0 then
        return string.format("%ds%02dc", silver, copperOnly)
    end
    return string.format("%dc", copperOnly)
end

local function EA_EscapeCSVField(value)
    local text = tostring(value or "")
    if text:find("[\",\r\n]") then
        text = "\"" .. text:gsub("\"", "\"\"") .. "\""
    end
    return text
end

local function EA_BuildExportRows(cat)
    local rows = {}
    local titanMap = EA_GetCategoryTitanMap()

    local function appendRow(name, itemID, titan)
        local key = name .. ":" .. tostring(itemID)
        local stats = EA_GetHistoryStats(key)
        local titanCount = tonumber(titan) or tonumber(titanMap[itemID]) or 0
        local titanValue = ""
        if titanCount > 0 and stats.minUnit and stats.minUnit > 0 then
            titanValue = EA_FormatPricePlain(math.floor((stats.minUnit / titanCount) + 0.5))
        end
        rows[#rows + 1] = {
            name = name,
            itemID = tonumber(itemID) or 0,
            snapshot = stats.snapshotCount or 0,
            history = stats.historyMin and EA_FormatPricePlain(stats.historyMin) or "",
            min = stats.minUnit and EA_FormatPricePlain(stats.minUnit) or "",
            titan = titanCount > 0 and tostring(titanCount) or "",
            titanValue = titanValue,
            scanTime = stats.latestTime and date("%Y-%m-%d %H:%M", stats.latestTime) or "",
        }
    end

    if not cat or cat == "全库" then
        for key in pairs(EasyAuctionDB.PriceHistory or {}) do
            local name, itemID = tostring(key):match("^(.-):(%d+)$")
            itemID = tonumber(itemID)
            if name and itemID then
                appendRow(name, itemID, titanMap[itemID])
            end
        end
    else
        for _, info in ipairs(EA_GetCategoryEntries(cat)) do
            appendRow(tostring(info[1] or ""), tonumber(info[2]) or 0, tonumber(info[3]) or 0)
        end
    end

    table.sort(rows, function(a, b)
        return (a.name or "") < (b.name or "")
    end)
    return rows
end

local function EA_GenerateExportText(cat)
    local rows = EA_BuildExportRows(cat)
    if #rows == 0 then
        return nil, 0
    end
    local lines = { "物品名,物品ID,在售数,历史最低价,最新单价,碎片数,每碎片价值,采集时间" }
    for _, row in ipairs(rows) do
        lines[#lines + 1] = table.concat({
            EA_EscapeCSVField(row.name),
            EA_EscapeCSVField(row.itemID or 0),
            EA_EscapeCSVField(row.snapshot or 0),
            EA_EscapeCSVField(row.history),
            EA_EscapeCSVField(row.min),
            EA_EscapeCSVField(row.titan),
            EA_EscapeCSVField(row.titanValue),
            EA_EscapeCSVField(row.scanTime),
        }, ",")
    end
    return table.concat(lines, "\n"), #rows
end

function EasyAuction_ShowExportFrame(cat)
    local exportText, itemCount = EA_GenerateExportText(cat)
    if not exportText then
        print("|cffff0000[EasyAuction]|r 当前导出范围没有可用数据。")
        return
    end

    if not EasyAuctionExportFrame then
        local f = CreateFrame("Frame", "EasyAuctionExportFrame", UIParent, "BackdropTemplate")
        f:SetSize(680, 500)
        f:SetPoint("CENTER")
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        EA_StyleDialog(f, "价格库数据导出", 680, 500)
        tinsert(UISpecialFrames, "EasyAuctionExportFrame")

        f.title = f.EA_Title

        local tip = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        tip:SetPoint("TOPLEFT", 18, -40)
        tip:SetText("Ctrl+A 全选，Ctrl+C 复制；内容为 CSV，可粘贴或导入 Excel。")
        tip:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
        EA_StyleText(tip, "muted")

        local exportPanel = CreateFrame("Frame", nil, f, "BackdropTemplate")
        exportPanel:SetPoint("TOPLEFT", 16, -62)
        exportPanel:SetPoint("BOTTOMRIGHT", -16, 44)
        EA_StylePanel(exportPanel, "plot")

        local scroll = CreateFrame("ScrollFrame", nil, exportPanel, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 8, -8)
        scroll:SetPoint("BOTTOMRIGHT", -28, 8)

        local editBox = CreateFrame("EditBox", nil, scroll)
        editBox:SetMultiLine(true)
        editBox:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
        editBox:SetAutoFocus(false)
        editBox:SetWidth(612)
        editBox:SetHeight(360)
        if editBox.SetTextColor and EAStyle then
            local p = EAStyle:Palette()
            editBox:SetTextColor(p.text[1], p.text[2], p.text[3], 1)
        end
        scroll:SetScrollChild(editBox)
        f.editBox = editBox

        local selectBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        selectBtn:SetSize(80, 22)
        selectBtn:SetPoint("BOTTOMLEFT", 16, 12)
        selectBtn:SetText("全选")
        EA_StyleButton(selectBtn)
        selectBtn:SetScript("OnClick", function()
            editBox:SetFocus()
            editBox:HighlightText()
        end)

        local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        closeBtn:SetSize(80, 22)
        closeBtn:SetPoint("BOTTOMRIGHT", -16, 12)
        closeBtn:SetText("关闭")
        EA_StyleButton(closeBtn)
        closeBtn:SetScript("OnClick", function()
            f:Hide()
        end)

        EasyAuctionExportFrame = f
    end

    local frame = EasyAuctionExportFrame
    frame.title:SetText(string.format("价格库数据导出 - %s（%d条）", cat or "全库", itemCount))
    frame.editBox:SetText(exportText)
    frame:Show()
end

function EasyAuction_ShowExportSelector()
    if not EasyAuctionExportSelectorFrame then
        local f = CreateFrame("Frame", "EasyAuctionExportSelectorFrame", UIParent, "BackdropTemplate")
        f:SetSize(352, 238)
        f:SetPoint("CENTER")
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        EA_StyleDialog(f, "选择导出范围", 352, 238)
        tinsert(UISpecialFrames, "EasyAuctionExportSelectorFrame")

        local allBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        allBtn:SetSize(104, 22)
        allBtn:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -46)
        allBtn:SetText("全库导出")
        EA_StyleButton(allBtn)
        allBtn:SetScript("OnClick", function()
            f:Hide()
            EasyAuction_ShowExportFrame("全库")
        end)

        local buttons = {}
        for index, cat in ipairs(EA_SCAN_CATEGORIES) do
            local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            btn:SetSize(72, 22)
            local row = math.floor((index - 1) / 4)
            local col = (index - 1) % 4
            btn:SetPoint("TOPLEFT", f, "TOPLEFT", 18 + col * 80, -82 - row * 28)
            btn:SetText(cat)
            EA_StyleButton(btn)
            btn:SetScript("OnClick", function()
                f:Hide()
                EasyAuction_ShowExportFrame(cat)
            end)
            buttons[#buttons + 1] = btn
        end

        local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        closeBtn:SetSize(72, 22)
        closeBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -18, 14)
        closeBtn:SetText("关闭")
        EA_StyleButton(closeBtn)
        closeBtn:SetScript("OnClick", function()
            f:Hide()
        end)

        EasyAuctionExportSelectorFrame = f
    end

    EasyAuctionExportSelectorFrame:Show()
end

if not DBFrame.EA_CategoryManageBtn then
    DBFrame.EA_CategoryManageBtn = CreateFrame("Button", nil, DBFrame, "UIPanelButtonTemplate")
    DBFrame.EA_CategoryManageBtn:SetSize(78, 22)
    DBFrame.EA_CategoryManageBtn:SetPoint("RIGHT", opportunityBtn, "LEFT", -6, 0)
    DBFrame.EA_CategoryManageBtn:SetText("分类管理")
    EA_StyleButton(DBFrame.EA_CategoryManageBtn)
    DBFrame.EA_CategoryManageBtn:SetScript("OnClick", function()
        EasyAuction_ShowCategoryManager(EA_CategoryMode)
    end)
    DBFrame.EA_CategoryManageBtn:Hide()
end

if not DBFrame.EA_ExportBtn then
    DBFrame.EA_ExportBtn = CreateFrame("Button", nil, DBFrame, "UIPanelButtonTemplate")
    DBFrame.EA_ExportBtn:SetSize(72, 22)
    DBFrame.EA_ExportBtn:SetPoint("RIGHT", DBFrame.EA_CategoryManageBtn, "LEFT", -6, 0)
    DBFrame.EA_ExportBtn:SetText("数据导出")
    EA_StyleButton(DBFrame.EA_ExportBtn)
    DBFrame.EA_ExportBtn:SetScript("OnClick", function()
        EasyAuction_ShowExportSelector()
    end)
    DBFrame.EA_ExportBtn:Hide()
end

DBFrame:HookScript("OnShow", function()
    if DBFrame.EA_CategoryManageBtn then DBFrame.EA_CategoryManageBtn:Show() end
    if DBFrame.EA_ExportBtn then DBFrame.EA_ExportBtn:Show() end
    EA_LayoutDBFrameControls()
    EasyAuction_UpdateCategoryButtonHighlight()
end)

DBFrame:HookScript("OnHide", function()
    if DBFrame.EA_CategoryManageBtn then DBFrame.EA_CategoryManageBtn:Hide() end
    if DBFrame.EA_ExportBtn then DBFrame.EA_ExportBtn:Hide() end
end)

local function EA_AppendCategoryRow(list, categoryKey, name, itemID, titan)
    local key = name .. ":" .. tostring(itemID)
    local stats = EA_GetHistoryStats(key)
    local min = stats.minUnit
    local t = stats.latestTime
    local minHistory = stats.historyMin
    local snapshotCount = stats.snapshotCount or 0
    local titanValue, titanValueRaw = nil, nil
    local titanCount = (type(titan) == "number" and titan > 0) and titan or nil
    if titanCount and min and min > 0 then
        titanValueRaw = min / titanCount
        titanValue = FormatGoldIcon(math.floor(titanValueRaw + 0.5))
    end
    local entry = {
        idx = #list + 1,
        name = name,
        itemid = tonumber(itemID),
        titan = titanCount,
        min = tonumber(min) or nil,
        t = tonumber(t) or nil,
        key = key,
        titanValue = titanValue,
        titanValueRaw = titanValueRaw,
        snapshot = snapshotCount,
        history = minHistory,
    }
    if categoryKey == "矿石" then
        entry.prospectValue = GetProspectValue and GetProspectValue(itemID)
    elseif categoryKey == "草药" then
        entry.millValue = GetMillValue and GetMillValue(itemID)
    end
    list[#list + 1] = entry
end

function EA_ShowCategory(cat, page, searchText)
    EA_CategoryMode = cat

    local list = {}
    local headers = {}
    for i, h in ipairs(normalHeaders) do
        headers[i] = {}
        for k, v in pairs(h) do
            headers[i][k] = v
        end
    end
    if cat == "矿石" then
        headers[4].name = "选矿收益"
    elseif cat == "草药" then
        headers[4].name = "研磨收益"
    end

    if cat == "全类" then
        local merged = {}
        for _, key in ipairs(EA_SCAN_CATEGORIES) do
            if key ~= "常用" then
                for _, info in ipairs(EA_GetCategoryEntries(key)) do
                    local name, itemid, titan = unpack(info)
                    local uniqueKey = tostring(name) .. ":" .. tostring(itemid)
                    if not merged[uniqueKey] then
                        merged[uniqueKey] = true
                        EA_AppendCategoryRow(list, key, name, itemid, titan)
                    end
                end
            end
        end
    else
        for _, info in ipairs(EA_GetCategoryEntries(cat)) do
            local name, itemid, titan = unpack(info)
            if cat == "常用" then
                titan = nil
            end
            EA_AppendCategoryRow(list, cat, name, itemid, titan)
        end
    end

    if searchText and searchText ~= "" then
        local keyword = strlower(searchText)
        local filtered = {}
        for _, data in ipairs(list) do
            local name = data.name and strlower(tostring(data.name)) or ""
            local itemid = data.itemid and tostring(data.itemid) or ""
            if name:find(keyword) or itemid:find(keyword) then
                tinsert(filtered, data)
            end
        end
        list = filtered
    end

    local function catSort(a, b)
        local key = EA_CategorySortKey or "t"
        local desc = EA_CategorySortDesc
        local va, vb
        if cat == "矿石" and key == "history" then
            -- 用prospectValue
            va, vb = a.prospectValue or 0, b.prospectValue or 0
        elseif cat == "草药" and key == "history" then
            -- 用millValue
            va, vb = a.millValue or 0, b.millValue or 0
        else
            -- 其余依然用key
            if key == "num" or key == "snapshot" then
                va, vb = a.snapshot or 0, b.snapshot or 0
            elseif key == "titanValue" then
                va, vb = a.titanValueRaw, b.titanValueRaw
            elseif key == "idx" then
                va, vb = a.idx, b.idx
            elseif key == "name" then
                va, vb = a.name or "", b.name or ""
            elseif key == "min" then
                va, vb = a.min, b.min
            elseif key == "titan" then
                va, vb = a.titan, b.titan
            elseif key == "history" then
                va, vb = a.history, b.history
            elseif key == "t" then
                va, vb = a.t, b.t
            else
                va, vb = a.idx, b.idx
            end
        end
        if va == nil and vb == nil then return (a.idx or 0) < (b.idx or 0) end
        if va == nil then return false end
        if vb == nil then return true end
        if va == vb then return (a.idx or 0) < (b.idx or 0) end
        if desc then
            return va > vb
        else
            return va < vb
        end
    end
    table.sort(list, catSort)

    EA_CategoryTotalPages = math.max(1, math.ceil(#list / ROWS_NUM))
    if not page or type(page) ~= "number" or page < 1 then
        EA_CategoryCurrentPage = 1
    elseif page > EA_CategoryTotalPages then
        EA_CategoryCurrentPage = EA_CategoryTotalPages
    else
        EA_CategoryCurrentPage = page
    end

    if DBFrame.NormalHeaderBtns then for _, btn in ipairs(DBFrame.NormalHeaderBtns) do btn:Hide() end end
    --if searchEditBox then searchEditBox:Hide() end
    if resetBtn then resetBtn:Hide() end
    if opportunityBtn then opportunityBtn:Hide() end

    if not DBFrame.EA_CategoryHeaderBtns then DBFrame.EA_CategoryHeaderBtns = {} end
    for j, col in ipairs(headers) do
        local btn = DBFrame.EA_CategoryHeaderBtns[j]
        if not btn then
            btn = CreateFrame("Button", nil, DBFrame)
            btn:SetSize(col.width, 24)
            btn:SetFrameLevel(DBFrame:GetFrameLevel() + 10)
            if j == 1 then
                btn:SetPoint("TOPLEFT", DBFrame, "TOPLEFT", DB_TABLE_LEFT, DB_HEADER_TOP)
            else
                btn:SetPoint("LEFT", DBFrame.EA_CategoryHeaderBtns[j - 1], "RIGHT", 0, 0)
            end
            btn.bg = btn:CreateTexture(nil, "BACKGROUND")
            btn.bg:SetAllPoints()
            EA_StyleRow(btn.bg, j, true)
            btn:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")

            btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            btn.text:SetPoint("CENTER")
            btn.text:SetJustifyH("CENTER")
            btn.text:SetWidth(col.width)
            btn.text:Show()
            EA_StyleText(btn.text, "accent")

            btn.sep = btn:CreateTexture(nil, "OVERLAY")
            if EAStyle then
                EAStyle:OnTheme(function(p)
                    btn.sep:SetColorTexture(p.border[1], p.border[2], p.border[3], 0.7)
                end)
            else
                btn.sep:SetColorTexture(0.7, 0.7, 0.7, 0.7)
            end
            btn.sep:SetWidth(1)
            btn.sep:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, -2)
            btn.sep:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 2)
            btn.sep:Show()

            DBFrame.EA_CategoryHeaderBtns[j] = btn
        end

        if j == #headers then
            btn.sep:Hide()
        else
            btn.sep:Show()
        end
        EA_StyleDBTableRow(btn, headers)
        btn:EnableMouse(true)
        btn:SetScript("OnEnter", function(self)
            EA_StyleRow(self.bg, j, true)
        end)
        btn:SetScript("OnLeave", function(self)
            EA_StyleRow(self.bg, j, true)
        end)
        if col.key and col.key ~= "action" then
            btn:SetScript("OnClick", function()
                if EA_CategorySortKey == col.key then
                    EA_CategorySortDesc = not EA_CategorySortDesc
                else
                    EA_CategorySortKey = col.key
                    EA_CategorySortDesc = false
                end
                EA_ShowCategory(EA_CategoryMode, 1, CurrentSearchText)
            end)
        else
            btn:SetScript("OnClick", nil)
        end
        local arrow = (EA_CategorySortKey == col.key and col.key ~= "action") and
            (EA_CategorySortDesc and " ▼" or " ▲") or ""
        btn.text:SetText(col.name .. arrow)
        btn.text:Show()
        btn:Show()
    end

    local startIdx = (EA_CategoryCurrentPage - 1) * ROWS_NUM + 1
    for i = 1, ROWS_NUM do
        local row = DBFrame.rows[i]
        local data = list[startIdx + i - 1]
        if not row.bg then
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
        end
        EA_StyleRow(row.bg, i, false)

        row:EnableMouse(true)
        row:SetScript("OnEnter", function(self)
            if self.bg then EA_StyleRow(self.bg, i, true) end
        end)
        row:SetScript("OnLeave", function(self)
            if self.bg then EA_StyleRow(self.bg, i, false) end
        end)
        row.__eaIndex = i
        for j, col in ipairs(headers) do
            local cell = row.cols[j]
            if not cell then
                cell = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
                row.cols[j] = cell
            end
            cell:ClearAllPoints()
            if j == 1 then
                cell:SetPoint("LEFT", row, "LEFT", 0, 0)
            else
                cell:SetPoint("LEFT", row.cols[j - 1], "RIGHT", 0, 0)
            end
            cell:SetWidth(col.width)
            if j == 1 then
                cell:SetJustifyH("CENTER")
            elseif j == 2 then
                cell:SetJustifyH("LEFT")
            elseif j == 3 or j == 4 or j == 5 or j == 6 or j == 7 then
                cell:SetJustifyH("RIGHT")
            elseif j == 8 then
                cell:SetJustifyH("CENTER")
            else
                cell:SetJustifyH("CENTER")
            end

            if not row.seps then row.seps = {} end
            if not row.seps[j] then
                local sep = row:CreateTexture(nil, "OVERLAY")
                if EAStyle then
                    EAStyle:OnTheme(function(p)
                        sep:SetColorTexture(p.border[1], p.border[2], p.border[3], 0.35)
                    end)
                else
                    sep:SetColorTexture(0.8, 0.8, 0.8, 0.5)
                end
                sep:SetWidth(1)
                sep:SetPoint("TOPLEFT", cell, "TOPRIGHT", 2, 0)
                sep:SetPoint("BOTTOMLEFT", cell, "BOTTOMRIGHT", 2, 0)
                row.seps[j] = sep
            end
            if j == 1 or j == #headers then
                row.seps[j]:Hide()
            else
                row.seps[j]:Show()
            end
        end
        EA_StyleDBTableRow(row, headers)
        if data then
            row:Show()
            row.cols[1]:SetText(tostring(startIdx + i - 1))
            local icon = ""
            if data.itemid then
                local iconPath = GetItemIcon(data.itemid)
                if iconPath then icon = "|T" .. iconPath .. ":16:16:0:0|t " end
            end
            local itemID = tonumber(data.key and data.key:match(":(%d+)$"))
            local itemLink = itemID and select(2, GetItemInfo(itemID)) or nil
            local realName
            if itemLink then
                realName = select(1, GetItemInfo(itemLink))
            end
            if not realName then
                realName = tostring(data.name):match("^(.-):%d+$") or tostring(data.name)
            end
            row.cols[2]:SetText(icon .. ColorName(realName, itemLink))
            row.itemLink = itemLink
            row.itemData = data

            if row.cols[2].clickBtn then
                row.cols[2].clickBtn:Show()
                row.cols[2].clickBtn:SetScript("OnClick", function(self, button)
                    if itemLink and HandleModifiedItemClick(itemLink) then
                        return
                    end
                    if button == "LeftButton" then
                        ShowPriceFrame(data.key, EasyAuction_GetPriceHistory(data.key, EasyAuctionDB))
                    end
                end)
                row.cols[2].clickBtn:SetScript("OnEnter", function(self)
                    row:LockHighlight()
                    local name = row.cols[2]:GetText()
                    local link = row.itemLink
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    if link then
                        GameTooltip:SetHyperlink(link)
                    else
                        GameTooltip:SetText(name, 1, 1, 1)
                    end
                    GameTooltip:AddLine("左键点击查看价格列表", 1, 1, 0)
                    GameTooltip:Show()
                end)
                row.cols[2].clickBtn:SetScript("OnLeave", function(self)
                    row:UnlockHighlight()
                    GameTooltip:Hide()
                end)
            end

            row.cols[3]:SetText(data.snapshot or "-")
            if cat == "矿石" then
                -- 选矿收益
                local prospectValue = data.itemid and GetProspectValue and GetProspectValue(data.itemid)
                row.cols[4]:SetText(prospectValue and prospectValue > 0 and FormatGoldIcon(prospectValue) or "-")
            elseif cat == "草药" then
                -- 研磨收益
                local millValue = data.itemid and GetMillValue and GetMillValue(data.itemid)
                row.cols[4]:SetText(millValue and millValue > 0 and FormatGoldIcon(millValue) or "-")
            else
                row.cols[4]:SetText(data.history and FormatGoldIcon(data.history) or "-")
            end
            row.cols[5]:SetText(data.min and FormatGoldIcon(data.min) or "-")
            row.cols[6]:SetText(data.titan or "-")
            row.cols[7]:SetText(data.titanValue or "-")
            row.cols[8]:SetText(data.t and EA_GetShortTime(data.t) or "-")
            if not row.trendBtn then
                row.trendBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                row.trendBtn:SetSize(50, 20)
                row.trendBtn:SetText("走势")
                EA_StyleButton(row.trendBtn)
            end
            row.trendBtn:ClearAllPoints()
            row.trendBtn:SetPoint("LEFT", row.cols[8], "RIGHT", 8, 0)
            row.trendBtn:Show()
            row.trendBtn:SetEnabled(data.min and data.min > 0)
            row.trendBtn:SetScript("OnClick", function()
                EasyAuction_ShowChart(data.key)
            end)
            row.cols[9]:SetText("")
            row.cols[9]:Show()
        else
            row:Hide()
            if row.trendBtn then row.trendBtn:Hide() end
        end
    end

    prevBtn:SetShown(EA_CategoryTotalPages > 1)
    nextBtn:SetShown(EA_CategoryTotalPages > 1)
    prevBtn:SetEnabled(EA_CategoryCurrentPage > 1)
    nextBtn:SetEnabled(EA_CategoryCurrentPage < EA_CategoryTotalPages)
    pageText:SetText(string.format("第%d/%d页", EA_CategoryCurrentPage, EA_CategoryTotalPages))
    prevBtn:SetScript("OnClick", function()
        if EA_CategoryMode and EA_CategoryCurrentPage > 1 then
            EA_ShowCategory(EA_CategoryMode, EA_CategoryCurrentPage - 1, CurrentSearchText)
        end
    end)
    nextBtn:SetScript("OnClick", function()
        if EA_CategoryMode and EA_CategoryCurrentPage < EA_CategoryTotalPages then
            EA_ShowCategory(EA_CategoryMode, EA_CategoryCurrentPage + 1, CurrentSearchText)
        end
    end)

    EasyAuction_UpdateCategoryButtonHighlight()
end

local _old_RefreshDBFrame = RefreshDBFrame
function RefreshDBFrame()
    if EA_CategoryMode then
        EA_ShowCategory(EA_CategoryMode, EA_CategoryCurrentPage, CurrentSearchText)
        return
    end
    if DBFrame.EA_CategoryHeaderFS then DBFrame.EA_CategoryHeaderFS:Hide() end
    if EA_CategoryHeaderBtns then for _, btn in ipairs(EA_CategoryHeaderBtns) do btn:Hide() end end

    local headerFS = _G["EasyAuctionDBFrameHeader"]
    if headerFS then headerFS:Show() end
    if searchEditBox then searchEditBox:Show() end
    if resetBtn then resetBtn:Show() end
    if opportunityBtn then opportunityBtn:Show() end
    if _old_RefreshDBFrame then _old_RefreshDBFrame() end
end

local function MyAH_AutoFillStackAndCount()
    local name, _, count, _, _, _, _, sCount, _, itemID = GetAuctionSellItemInfo()
    if not name or not itemID then
        if AuctionsStackSizeEntry then AuctionsStackSizeEntry:Hide() end
        if AuctionsNumStacksEntry then AuctionsNumStacksEntry:Hide() end
        if AuctionsStackSizeMaxButton then AuctionsStackSizeMaxButton:Hide() end
        if AuctionsNumStacksMaxButton then AuctionsNumStacksMaxButton:Hide() end
        return
    end

    local total = 0
    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, GetContainerNumSlots(bag) do
            local link = GetContainerItemLink(bag, slot)
            if link and tonumber(link:match("item:(%d+)")) == itemID then
                local _, bagCount = GetContainerItemInfo(bag, slot)
                total = total + (bagCount or 0)
            end
        end
    end
    if total < 1 then total = 1 end

    if sCount and sCount > 1 then
        local stackSize = (count and count > 0) and count or math.min(sCount, total)
        if stackSize <= 0 then stackSize = sCount end
        local numStacks
        if total >= stackSize and stackSize > 0 then
            numStacks = math.floor(total / stackSize)
        elseif total > 0 and stackSize > 0 then
            numStacks = 1
        else
            numStacks = 1
        end
        if AuctionsStackSizeEntry then
            AuctionsStackSizeEntry:SetNumber(stackSize)
            AuctionsStackSizeEntry:Show()
            if AuctionsStackSizeEntry.SetEnabled then
                AuctionsStackSizeEntry:SetEnabled(true)
            elseif AuctionsStackSizeEntry.Enable then
                AuctionsStackSizeEntry:Enable()
            end
        end
        if AuctionsNumStacksEntry then
            AuctionsNumStacksEntry:SetNumber(numStacks)
            AuctionsNumStacksEntry:Show()
        end
        if AuctionsStackSizeMaxButton then
            AuctionsStackSizeMaxButton:Show()
            AuctionsStackSizeMaxButton:SetScript("OnClick", function()
                local _, _, _, _, _, _, _, sCount, _, iID = GetAuctionSellItemInfo()
                local bagTotal = 0
                for bag = 0, NUM_BAG_SLOTS do
                    for slot = 1, GetContainerNumSlots(bag) do
                        local link = GetContainerItemLink(bag, slot)
                        if link and tonumber(link:match("item:(%d+)")) == iID then
                            local _, n = GetContainerItemInfo(bag, slot)
                            bagTotal = bagTotal + (n or 0)
                        end
                    end
                end
                local fill = math.min(bagTotal, sCount or 1)
                if fill <= 0 then fill = sCount or 1 end
                AuctionsStackSizeEntry:SetNumber(fill)
            end)
        end
        if AuctionsNumStacksMaxButton then AuctionsNumStacksMaxButton:Show() end
    else
        if AuctionsStackSizeEntry then
            AuctionsStackSizeEntry:SetNumber(1)
            AuctionsStackSizeEntry:Show()
            if AuctionsStackSizeEntry.SetEnabled then
                AuctionsStackSizeEntry:SetEnabled(false)
            elseif AuctionsStackSizeEntry.Disable then
                AuctionsStackSizeEntry:Disable()
            end
        end
        if AuctionsNumStacksEntry then
            AuctionsNumStacksEntry:SetNumber(total)
            AuctionsNumStacksEntry:Show()
        end
        if AuctionsStackSizeMaxButton then
            AuctionsStackSizeMaxButton:Show()
            AuctionsStackSizeMaxButton:SetScript("OnClick", function()
                if AuctionsStackSizeEntry then AuctionsStackSizeEntry:SetNumber(1) end
            end)
        end
        if AuctionsNumStacksMaxButton then AuctionsNumStacksMaxButton:Show() end
    end
end
local autoFillFrame = CreateFrame("Frame")
autoFillFrame:RegisterEvent("NEW_AUCTION_UPDATE")
autoFillFrame:SetScript("OnEvent", function()
    C_Timer.After(0.1, MyAH_AutoFillStackAndCount)
end)

function MyAH_AutoFillPrice()
    local name, _, _, _, _, _, _, _, _, itemID = GetAuctionSellItemInfo()
    local key = name and itemID and (name .. ":" .. itemID) or name
    local history = key and EasyAuction_GetPriceHistory(key, EasyAuctionDB) or nil
    if history and #history > 0 then
        local min = math.huge
        for _, v in ipairs(history) do
            if v.unit < min then min = v.unit end
        end
        if min < math.huge then
            FillAuctionPrice(min)
        end
    end
end

local priceFillFrame = CreateFrame("Frame")
priceFillFrame:RegisterEvent("NEW_AUCTION_UPDATE")
priceFillFrame:SetScript("OnEvent", function()
    MyAH_AutoFillPrice()
    local name, _, _, _, _, _, _, _, _, itemID = GetAuctionSellItemInfo()
    local key = name and itemID and (name .. ":" .. itemID) or name
    if _G["AuctionHelper"] and _G["AuctionHelper"]:IsShown() then
        return
    elseif key and EasyAuctionDB and EasyAuctionDB.PriceHistory[key] then
        ShowPriceFrame(key, EasyAuction_GetPriceHistory(key, EasyAuctionDB))
    end
end)

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, addon)
    if addon == "Blizzard_AuctionUI" then
        if AuctionsStackSizeEntry then
            AuctionsStackSizeEntry:ClearAllPoints()
            AuctionsStackSizeEntry:SetPoint("TOPLEFT", AuctionFrameAuctions, "TOPLEFT", 120, -220)
            AuctionsStackSizeEntry:SetWidth(40)
            AuctionsStackSizeEntry:SetHeight(22)
        end

        if AuctionsNumStacksEntry then
            AuctionsNumStacksEntry:ClearAllPoints()
            AuctionsNumStacksEntry:SetPoint("LEFT", AuctionsStackSizeEntry, "RIGHT", -40, -45)
            AuctionsNumStacksEntry:SetWidth(40)
            AuctionsNumStacksEntry:SetHeight(22)
        end

        if AuctionsStackSizeMaxButton then
            AuctionsStackSizeMaxButton:ClearAllPoints()
            AuctionsStackSizeMaxButton:SetPoint("LEFT", AuctionsStackSizeEntry, "RIGHT", 5, 0)
            AuctionsStackSizeMaxButton:SetWidth(32)
            AuctionsStackSizeMaxButton:SetHeight(22)
        end

        if AuctionsNumStacksMaxButton then
            AuctionsNumStacksMaxButton:ClearAllPoints()
            AuctionsNumStacksMaxButton:SetPoint("LEFT", AuctionsNumStacksEntry, "RIGHT", 5, 0)
            AuctionsNumStacksMaxButton:SetWidth(32)
            AuctionsNumStacksMaxButton:SetHeight(22)
        end
        if AuctionsCreateAuctionButton and not AuctionsCreateAuctionButton.EasyAuctionHooked then
            AuctionsCreateAuctionButton.__EasyAuction_OldOnClick = AuctionsCreateAuctionButton:GetScript("OnClick")
            AuctionsCreateAuctionButton:SetScript("OnClick", function(self)
                local name, _, count, _, _, _, _, sCount, _, itemID = GetAuctionSellItemInfo()
                if not name or not itemID then
                    if self.__EasyAuction_OldOnClick then self.__EasyAuction_OldOnClick(self) end
                    return
                end
                local buyout = MoneyInputFrame_GetCopper(BuyoutPrice)
                local stackSize = AuctionsStackSizeEntry and AuctionsStackSizeEntry:GetNumber() or 1
                if stackSize < 1 then stackSize = 1 end
                local _, _, _, _, _, _, _, _, _, _, vendorPrice = GetItemInfo(itemID)
                if not vendorPrice or vendorPrice <= 0 then
                    if self.__EasyAuction_OldOnClick then self.__EasyAuction_OldOnClick(self) end
                    return
                end
                local totalVendor = vendorPrice * stackSize
                local totalBuyout = buyout
                local afterTax = math.floor(totalBuyout * 0.99 + 0.5)
                if totalBuyout > 0 and afterTax < totalVendor then
                    StaticPopupDialogs["EASYAUCTION_LOW_PROFIT"] = {
                        text = string.format("拍卖到手：%s\n直接卖店：%s\n\n当前价格低于卖店收益，是否继续上架？",
                            FormatGoldIcon(afterTax, 12), FormatGoldIcon(totalVendor, 12)),
                        button1 = "继续上架",
                        button2 = "取消",
                        OnAccept = function()
                            if AuctionsCreateAuctionButton.__EasyAuction_OldOnClick then
                                AuctionsCreateAuctionButton.__EasyAuction_OldOnClick(AuctionsCreateAuctionButton)
                            end
                        end,
                        timeout = 0,
                        whileDead = true,
                        hideOnEscape = true,
                        preferredIndex = 3,
                    }
                    StaticPopup_Show("EASYAUCTION_LOW_PROFIT")
                    return
                end
                if self.__EasyAuction_OldOnClick then self.__EasyAuction_OldOnClick(self) end
            end)
            AuctionsCreateAuctionButton.EasyAuctionHooked = true
        end
    end
end)

local function EA_AreManagedAddOnsDisabled()
    local playerName = UnitName("player")
    for i = 1, C_AddOns.GetNumAddOns() do
        local name = C_AddOns.GetAddOnInfo(i)
        if EA_IsManagedAddon(name) and EA_IsAddonEnabled(name, playerName) then
            return false
        end
    end
    return true
end

local function EasyAuction_BackupAddonList()
    if not EasyAuctionDB then return false end
    if EasyAuctionDB.MinimalModeActive == nil and type(EasyAuctionDB.AddonBackup) == "table"
        and next(EasyAuctionDB.AddonBackup) ~= nil then
        EasyAuctionDB.MinimalModeActive = EA_AreManagedAddOnsDisabled()
    end
    if EasyAuctionDB.MinimalModeActive then return false end
    local playerName = UnitName("player")
    local backup = {}
    for i = 1, C_AddOns.GetNumAddOns() do
        local name, _, _, _ = C_AddOns.GetAddOnInfo(i)
        if EA_IsManagedAddon(name) then
            backup[name] = EA_IsAddonEnabled(name, playerName)
        end
    end
    EasyAuctionDB.AddonBackup = backup
    EasyAuctionDB.MinimalModeActive = false
    return true
end

function EasyAuction_IsMinimalModeActive()
    if not EasyAuctionDB then
        return false
    end
    if EasyAuctionDB.MinimalModeActive ~= nil then
        return EasyAuctionDB.MinimalModeActive == true
    end
    if type(EasyAuctionDB.AddonBackup) ~= "table" or next(EasyAuctionDB.AddonBackup) == nil then
        return false
    end
    return EA_AreManagedAddOnsDisabled()
end

function EasyAuction_SetMinimalAddon()
    if not EasyAuctionDB then
        print("|cffff0000[EasyAuction]|r 插件数据未初始化，无法切换极简模式。")
        return
    end
    local disableAddOn = EA_GetAddonToggle("DisableAddOn")
    if not disableAddOn then
        print("|cffff0000[EasyAuction]|r 当前客户端不支持禁用插件接口。")
        return
    end
    EasyAuction_BackupAddonList()
    EasyAuctionDB.MinimalModeActive = true
    for i = 1, C_AddOns.GetNumAddOns() do
        local name = C_AddOns.GetAddOnInfo(i)
        if EA_IsManagedAddon(name) then
            disableAddOn(name)
        end
    end
    print("|cff00ff00[EasyAuction]|r 极简模式已应用，仅保留EasyAuction")
    ReloadUI()
end

function EasyAuction_RestoreAddon()
    if not EasyAuctionDB or type(EasyAuctionDB.AddonBackup) ~= "table" then
        print("|cffff0000[EasyAuction]|r 没有可恢复的插件配置。")
        return
    end
    local enableAddOn = EA_GetAddonToggle("EnableAddOn")
    local disableAddOn = EA_GetAddonToggle("DisableAddOn")
    if not enableAddOn or not disableAddOn then
        print("|cffff0000[EasyAuction]|r 当前客户端不支持插件恢复接口。")
        return
    end
    for name, state in pairs(EasyAuctionDB.AddonBackup) do
        if state then
            enableAddOn(name)
        else
            disableAddOn(name)
        end
    end
    EasyAuctionDB.MinimalModeActive = false
    print("|cff00ff00[EasyAuction]|r 插件配置已恢复。")
    ReloadUI()
end

local function InitEasyAuctionUI()
    if not AuctionFrameBrowse or not BrowseName or not BrowseBidButton then
        C_Timer.After(0.5, InitEasyAuctionUI)
        return
    end
end
local specialFrames = {
    "EasyAuctionPriceFrame",
    "EasyAuctionDBFrame",
}
for _, name in ipairs(specialFrames) do
    if _G[name] then
        tinsert(UISpecialFrames, name)
    end
end

local minimapLDBInitFrame = CreateFrame("Frame")
minimapLDBInitFrame:RegisterEvent("ADDON_LOADED")
minimapLDBInitFrame:RegisterEvent("PLAYER_LOGIN")
minimapLDBInitFrame:SetScript("OnEvent", function(self, event, addon)
    if event == "ADDON_LOADED" then
        if addon == "Blizzard_AuctionUI" then
            InitEasyAuctionUI()
        elseif addon == "EasyAuction" then
            if ns.EA_ShouldAskDBReset() then
                local popup = StaticPopup_Show("EASYAUCTION_DB_RESET_PROMPT", nil, nil, { owner = self })
                if not popup then
                    ns.EA_MarkDBResetPromptDone()
                    EA_ContinueAfterDBResetPrompt(self)
                end
            else
                EA_ContinueAfterDBResetPrompt(self)
            end
        end
    elseif event == "PLAYER_LOGIN" then
        EasyAuction_BackupAddonList()
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)

local legacyShadowFrame = CreateFrame("Frame")
legacyShadowFrame:RegisterEvent("PLAYER_LOGOUT")
legacyShadowFrame:SetScript("OnEvent", function()
    local realmKey = GetRealmFactionKey()
    if type(EasyAuctionDB2) == "table" and EasyAuctionDB2[realmKey] then
        -- 避免 EasyAuctionDB 与 EasyAuctionDB2 持久化双份大表。
        _G.EasyAuctionDB = {
            legacyRedirect = true,
            realmKey = realmKey,
            ts = time(),
            version = tostring(EA_GetAddonMetadata(addonName, "Version") or "?"),
            note = "Use EasyAuctionDB2[realmKey]",
        }
    end
end)
function EasyAuction_ShowScanProgress()
    if EasyAuctionScanProgressFrame then
        EasyAuctionScanProgressFrame:Reset()
        EA_RaiseUtilityFrame(EasyAuctionScanProgressFrame)
        EasyAuctionScanProgressFrame:Show()
        return
    end

    local f = CreateFrame("Frame", "EasyAuctionScanProgressFrame", UIParent, "BackdropTemplate")
    f:SetSize(420, 176)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    EA_RaiseUtilityFrame(f)
    if EasyAuctionStyle then
        EasyAuctionStyle:Skin(f, "window")
    end

    f.Title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.Title:SetPoint("TOPLEFT", 14, -12)
    f.Title:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 16, "")
    f.Title:SetText("正在搜索拍卖行价格")
    if EasyAuctionStyle then EasyAuctionStyle:SkinText(f.Title, "accent") end

    f.Status = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.Status:SetPoint("TOPLEFT", f.Title, "BOTTOMLEFT", 0, -8)
    f.Status:SetPoint("RIGHT", f, "RIGHT", -14, 0)
    f.Status:SetJustifyH("LEFT")
    f.Status:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
    f.Status:SetText("正在准备...")
    if EasyAuctionStyle then EasyAuctionStyle:SkinText(f.Status, "text") end

    f.ProgressBar = CreateFrame("StatusBar", nil, f, "TextStatusBar")
    f.ProgressBar:SetPoint("TOPLEFT", f.Status, "BOTTOMLEFT", 0, -14)
    f.ProgressBar:SetSize(392, 22)
    f.ProgressBar:SetMinMaxValues(0, 1)
    f.ProgressBar:SetValue(0)
    f.ProgressBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    f.ProgressBar.Bg = f.ProgressBar:CreateTexture(nil, "BACKGROUND")
    f.ProgressBar.Bg:SetAllPoints()
    f.ProgressBar.Bg:SetColorTexture(1, 1, 1, 0.06)
    if EasyAuctionStyle then
        EasyAuctionStyle:OnTheme(function(p)
            f.ProgressBar:SetStatusBarColor(p.accent[1], p.accent[2], p.accent[3], 0.88)
        end)
    else
        f.ProgressBar:SetStatusBarColor(0.2, 0.7, 1)
    end

    f.ProgressBar.Percent = f.ProgressBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.ProgressBar.Percent:SetPoint("CENTER", f.ProgressBar, "CENTER")
    f.ProgressBar.Percent:SetText("0%")
    if EasyAuctionStyle then EasyAuctionStyle:SkinText(f.ProgressBar.Percent, "text") end

    f.ProgressBar.Detail = f.ProgressBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.ProgressBar.Detail:SetPoint("RIGHT", f.ProgressBar, "RIGHT", -6, 0)
    if EasyAuctionStyle then EasyAuctionStyle:SkinText(f.ProgressBar.Detail, "muted") end

    f.Desc = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.Desc:SetPoint("TOPLEFT", f.ProgressBar, "BOTTOMLEFT", 0, -10)
    f.Desc:SetPoint("RIGHT", f, "RIGHT", -14, 0)
    f.Desc:SetJustifyH("LEFT")
    f.Desc:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
    f.Desc:SetText("扫描期间请避免操作拍卖行；完成后结果会显示在此窗口。")
    if EasyAuctionStyle then EasyAuctionStyle:SkinText(f.Desc, "muted") end

    f.Result = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.Result:SetPoint("TOPLEFT", f.Desc, "BOTTOMLEFT", 0, -8)
    f.Result:SetPoint("RIGHT", f, "RIGHT", -14, 0)
    f.Result:SetJustifyH("LEFT")
    f.Result:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
    f.Result:SetText("")
    f.Result:Hide()
    if EasyAuctionStyle then EasyAuctionStyle:SkinText(f.Result, "bull") end

    f.CloseBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.CloseBtn:SetText("价格库")
    f.CloseBtn:SetSize(74, 22)
    f.CloseBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 12)
    if EasyAuctionStyle then EasyAuctionStyle:SkinButton(f.CloseBtn) end
    f.CloseBtn:Hide()
    f.CloseBtn:SetScript("OnClick", function()
        f:Hide()
        if EasyAuctionDBFrame then
            EasyAuction_OpenDBFrame()
        end
    end)

    f.ReloadBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.ReloadBtn:SetText("重载")
    f.ReloadBtn:SetSize(64, 22)
    f.ReloadBtn:SetPoint("RIGHT", f.CloseBtn, "LEFT", -6, 0)
    if EasyAuctionStyle then EasyAuctionStyle:SkinButton(f.ReloadBtn) end
    f.ReloadBtn:Hide()
    f.ReloadBtn:SetScript("OnClick", function()
        ReloadUI()
    end)

    f.HideBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.HideBtn:SetText("关闭")
    f.HideBtn:SetSize(64, 22)
    f.HideBtn:SetPoint("RIGHT", f.ReloadBtn, "LEFT", -6, 0)
    if EasyAuctionStyle then EasyAuctionStyle:SkinButton(f.HideBtn) end
    f.HideBtn:Hide()
    f.HideBtn:SetScript("OnClick", function()
        f:Hide()
    end)

    f._EA_PrepareTicker = nil
    f._EA_PrepareTime = nil

    function f:StartPrepareTimer()
        if self._EA_PrepareTicker then
            self._EA_PrepareTicker:Cancel()
        end
        self._EA_PrepareTime = GetTime()
        self._EA_PrepareTicker = C_Timer.NewTicker(0.1, function()
            if not self:IsVisible() then
                if self._EA_PrepareTicker then
                    self._EA_PrepareTicker:Cancel()
                end
                return
            end
            local t = GetTime() - (self._EA_PrepareTime or GetTime())
            self.Status:SetText(string.format("正在准备...(%.1f秒)", t))
        end)
    end

    function f:StopPrepareTimer()
        if self._EA_PrepareTicker then
            self._EA_PrepareTicker:Cancel()
            self._EA_PrepareTicker = nil
        end
    end

    function f:UpdateStatus(msg)
        self:StopPrepareTimer()
        self.Status:SetText(msg or "")
    end

    function f:UpdateProgress(cur, total)
        cur = cur or 0
        total = total or 1
        self.ProgressBar:SetMinMaxValues(0, total)
        self.ProgressBar:SetValue(cur)
        local percent = (total > 0) and (cur / total * 100) or 100
        if self.ProgressBar.Percent then
            self.ProgressBar.Percent:SetText(string.format("%.1f%%", percent))
        end
        if self.ProgressBar.Detail then
            self.ProgressBar.Detail:SetText(string.format("%d / %d", cur, total))
        end
        self:StopPrepareTimer()
    end

    function f:ShowResult(text)
        self:StopPrepareTimer()
        self.Result:SetText(text or "")
        self.Result:Show()
        self.CloseBtn:Show()
        self.ReloadBtn:Show()
        self.HideBtn:Show()
        self.Desc:Hide()
    end

    function f:Reset()
        self:StopPrepareTimer()
        self.Result:Hide()
        self.CloseBtn:Hide()
        self.ReloadBtn:Hide()
        self.HideBtn:Hide()
        self.Desc:Show()
        self.Status:SetText("正在准备...")
        self.ProgressBar:SetMinMaxValues(0, 1)
        self.ProgressBar:SetValue(0)
        self.ProgressBar.Percent:SetText("0%")
        self.ProgressBar.Detail:SetText("0 / 0")
        self:StartPrepareTimer()
    end

    tinsert(UISpecialFrames, "EasyAuctionScanProgressFrame")
    EasyAuctionScanProgressFrame = f

    f:Reset()
    EA_RaiseUtilityFrame(f)
    f:Show()
end
local isUpdatingScanProgress = false

function EasyAuction_UpdateScanProgress(cur, total, elapsed)
    if isUpdatingScanProgress then return end   -- 防止递归/死循环
    isUpdatingScanProgress = true

    if not EasyAuctionScanProgressFrame then
        isUpdatingScanProgress = false
        return
    end

    local f = EasyAuctionScanProgressFrame
    f.ProgressBar:SetMinMaxValues(0, total > 0 and total or 1)
    f.ProgressBar:SetValue(cur)
    local percent = (total > 0) and (cur / total * 100) or 100
    if f.ProgressBar.Percent then
        f.ProgressBar.Percent:SetText(string.format("%.1f%%", percent))
    end

    if f._EA_PrepareTicker then
        f._EA_PrepareTicker:Cancel()
        f._EA_PrepareTicker = nil
    end
    if elapsed then
        f.Status:SetText(string.format("已采集：%d / %d  用时：%.1fs", cur, total, elapsed))
    end

    isUpdatingScanProgress = false
end

function CleanupOldData()
    local db = _G.EasyAuctionDB or EasyAuctionDB
    if type(db) ~= "table" then return end
    local days = EA_ClampInt(db.historyKeepDays or 30, 30, 1, 365)
    local maxEntry = EA_ClampInt(db.historyMaxEntry or 0, 0, 0, 2000)
    local keepPerItem = EA_ClampInt(db.scanKeepPerItem or 120, 120, 20, 500)
    local dailyKeepDays = EA_ClampInt(db.dailyKeepDays or days, days, 1, 365)
    local hourlyKeepHours = EA_ClampInt(db.hourlyKeepHours or 24, 24, 1, 24)
    db.historyKeepDays = days
    db.historyMaxEntry = maxEntry
    db.scanKeepPerItem = keepPerItem
    db.dailyKeepDays = dailyKeepDays
    db.hourlyKeepHours = hourlyKeepHours

    local cutoffTime = time() - (days * 86400)
    local cutoffDay = date("%Y-%m-%d", time() - (dailyKeepDays * 86400))
    local removedRecords = 0
    local removedDaily = 0
    local removedHourly = 0

    -- 清理物品名为空的脏数据 key（历史遗留 ":itemID" 形式记录）
    for key in pairs(db.PriceHistory or {}) do
        if not EA_IsValidStorageKey(key) then
            EA_DeleteStorageKey(db, "PriceHistory", "price", key)
            removedRecords = removedRecords + 1
        end
    end
    for key in pairs(db.DailyMinPrice or {}) do
        if not EA_IsValidStorageKey(key) then
            EA_DeleteStorageKey(db, "DailyMinPrice", "daily", key)
            removedDaily = removedDaily + 1
        end
    end
    for key in pairs(db.HourlyMinPrice or {}) do
        if not EA_IsValidStorageKey(key) then
            EA_DeleteStorageKey(db, "HourlyMinPrice", "hourly", key)
            removedHourly = removedHourly + 1
        end
    end

    for key in pairs(db.PriceHistory or {}) do
        local raw = db.PriceHistory[key]
        local perItemLimit = keepPerItem
        if maxEntry > 0 and maxEntry < perItemLimit then
            perItemLimit = maxEntry
        end
        local beforeCount = type(raw) == "table" and #raw or #(EasyAuction_GetPriceHistory(key, db) or {})
        local newData, removed = EA_CompressHistoryRecords(EasyAuction_GetPriceHistory(key, db), perItemLimit, cutoffTime)
        removedRecords = removedRecords + removed
        if #newData == 0 then
            EA_DeleteStorageKey(db, "PriceHistory", "price", key)
        else
            local minUnit = nil
            local latestTime = nil
            for _, rec in ipairs(newData) do
                if rec.unit and (not minUnit or rec.unit < minUnit) then minUnit = rec.unit end
                if rec.t and (not latestTime or rec.t > latestTime) then latestTime = rec.t end
            end
            EasyAuction_SetPriceHistory(key, newData, minUnit, latestTime, db)
            if beforeCount > #newData then
                removedRecords = removedRecords + (beforeCount - #newData)
            end
        end
    end

    for key in pairs(db.DailyMinPrice or {}) do
        local newArr = {}
        for _, rec in ipairs(EasyAuction_GetDailyMinPrice(key, db)) do
            local day = rec and rec[1]
            if type(day) == "string" and day >= cutoffDay then
                newArr[#newArr + 1] = rec
            else
                removedDaily = removedDaily + 1
            end
        end
        if #newArr > 0 then
            EasyAuction_SetDailyMinPrice(key, newArr, db)
        else
            EA_DeleteStorageKey(db, "DailyMinPrice", "daily", key)
        end
    end

    local function NormalizeHourlyList(arr)
        if type(arr) ~= "table" then return nil, 0 end
        local currentHour = tonumber(date("%H")) or 0
        local keepHourCount = math.min(24, math.max(1, math.floor(hourlyKeepHours)))
        local oldestHour = (currentHour - keepHourCount + 24) % 24
        local function IsHourInWindow(hour)
            if keepHourCount >= 24 then return true end
            if oldestHour <= currentHour then
                return hour >= oldestHour and hour <= currentHour
            end
            return hour >= oldestHour or hour <= currentHour
        end

        local removed = 0
        local byHour = {}
        for _, rec in ipairs(arr) do
            local hour = rec and tonumber(rec[1]) or nil
            if hour and hour >= 0 and hour <= 23 and IsHourInWindow(hour) then
                local old = byHour[hour]
                if not old then
                    byHour[hour] = rec
                else
                    old[4] = (old[4] or 0) + (rec[4] or rec[3] or 0)
                    if (rec[2] or math.huge) < (old[2] or math.huge) then
                        old[2] = rec[2]
                        old[3] = rec[3]
                    elseif rec[2] == old[2] then
                        old[3] = (old[3] or 0) + (rec[3] or 0)
                    end
                    removed = removed + 1
                end
            else
                removed = removed + 1
            end
        end

        local normalized = {}
        for _, rec in pairs(byHour) do
            normalized[#normalized + 1] = rec
        end
        table.sort(normalized, function(a, b)
            return (tonumber(a[1]) or 0) < (tonumber(b[1]) or 0)
        end)
        return normalized, removed
    end

    for key in pairs(db.HourlyMinPrice or {}) do
        local normalized, removed = NormalizeHourlyList(EasyAuction_GetHourlyMinPrice(key, db))
        removedHourly = removedHourly + removed
        if normalized and #normalized > 0 then
            EasyAuction_SetHourlyMinPrice(key, normalized, db)
        else
            EA_DeleteStorageKey(db, "HourlyMinPrice", "hourly", key)
        end
    end

    local removedOps = EA_TrimOperationHistory(db)
    if type(db.LastOpportunities) == "table" then
        db.LastOpportunities = nil
    end
    local totalRemoved = removedRecords + removedDaily + removedHourly + removedOps
    if totalRemoved > 0 then
        print(string.format("|cff00ff00[EasyAuction]|r 清理完成，移除记录%d条（历史%d/日聚合%d/小时聚合%d/操作%d）。",
            totalRemoved, removedRecords, removedDaily, removedHourly, removedOps))
    end
    db.LastCleanupDay = date("%Y-%m-%d")
    db.LastCleanupAt = time()
    db.LastFullCleanupAt = db.LastCleanupAt
    collectgarbage("collect")
end

function EasyAuction_RunDailyCleanup(force)
    local db = _G.EasyAuctionDB or EasyAuctionDB
    if type(db) ~= "table" then return end
    local today = date("%Y-%m-%d")
    if not force and db.LastCleanupDay == today then
        return
    end
    CleanupOldData()
end

local EA_STORAGE_MIGRATION_FIELDS = {
    { field = "HourlyMinPrice", kind = "hourly" },
    { field = "PriceHistory", kind = "price" },
    { field = "DailyMinPrice", kind = "daily" },
}

local function EA_GetLatestDailyDayForKey(db, key)
    local latestDay = nil
    for _, rec in ipairs(EasyAuction_GetDailyMinPrice(key, db)) do
        local day = rec and rec[1]
        if type(day) == "string" and (not latestDay or day > latestDay) then
            latestDay = day
        end
    end
    return latestDay
end

local function EA_GetHourlyAnchorDay(db, key)
    local dailyDay = EA_GetLatestDailyDayForKey(db, key)
    if dailyDay then return dailyDay end
    local history = EasyAuction_GetPriceHistory(key, db)
    return history and EA_DateStringFromTimestamp(history.lastScanT)
end

local function EA_RepairHourlyTimestamps(db, key, records)
    local anchorDay = EA_GetHourlyAnchorDay(db, key)
    local changed = false
    if not anchorDay then return records, changed end
    for _, rec in ipairs(records or {}) do
        local storedDay = rec and EA_DateStringFromTimestamp(rec[5])
        if storedDay and storedDay > anchorDay then
            rec[5] = nil
            changed = true
        end
    end
    return records, changed
end

local function EA_EncodeExistingStorageKey(db, field, kind, key)
    if field == "HourlyMinPrice" then
        local records = EasyAuction_GetHourlyMinPrice(key, db)
        records = EA_RepairHourlyTimestamps(db, key, records)
        if #records > 0 then
            EasyAuction_SetHourlyMinPrice(key, records, db)
        else
            EA_DeleteStorageKey(db, field, kind, key)
        end
    elseif field == "PriceHistory" then
        local records = EasyAuction_GetPriceHistory(key, db)
        if #records > 0 then
            EasyAuction_SetPriceHistory(key, records, records.minUnit, records.lastScanT, db)
        else
            EA_DeleteStorageKey(db, field, kind, key)
        end
    elseif field == "DailyMinPrice" then
        local records = EasyAuction_GetDailyMinPrice(key, db)
        if #records > 0 then
            EasyAuction_SetDailyMinPrice(key, records, db)
        else
            EA_DeleteStorageKey(db, field, kind, key)
        end
    end
end

function EasyAuction_MigrateStorageV2()
    local db = _G.EasyAuctionDB or EasyAuctionDB
    if type(db) ~= "table" then return end
    if db.StorageFormatVersion == EA_STORAGE_VERSION and not db.StorageMigrationState then return end

    local state = db.StorageMigrationState
    if type(state) ~= "table" or state.targetVersion ~= EA_STORAGE_VERSION then
        state = { fieldIndex = 1, lastKey = nil, converted = 0, targetVersion = EA_STORAGE_VERSION }
        db.StorageMigrationState = state
    end

    local batchLimit = 160
    local convertedThisBatch = 0

    while convertedThisBatch < batchLimit and state.fieldIndex <= #EA_STORAGE_MIGRATION_FIELDS do
        local info = EA_STORAGE_MIGRATION_FIELDS[state.fieldIndex]
        local store = db[info.field]
        local processedField = false

        if type(store) == "table" then
            local keys = {}
            for key in pairs(store) do
                if not state.lastKey or tostring(key) > tostring(state.lastKey) then
                    keys[#keys + 1] = key
                end
            end
            table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
            for _, key in ipairs(keys) do
                local raw = store[key]
                local prefix = info.kind == "price" and "PH2|" or info.kind == "daily" and "DM2|" or "HM2|"
                if info.kind == "hourly" or type(raw) == "table" or not EA_IsEncodedStorageValue(raw, prefix) then
                    EA_EncodeExistingStorageKey(db, info.field, info.kind, key)
                    state.converted = (state.converted or 0) + 1
                    convertedThisBatch = convertedThisBatch + 1
                    if state.converted % 1000 == 0 then
                        collectgarbage("collect")
                    end
                    if convertedThisBatch >= batchLimit then
                        state.lastKey = key
                        break
                    end
                end
            end
            if convertedThisBatch < batchLimit then
                processedField = true
            end
        else
            processedField = true
        end

        if processedField then
            state.fieldIndex = state.fieldIndex + 1
            state.lastKey = nil
        end
    end

    if state.fieldIndex > #EA_STORAGE_MIGRATION_FIELDS then
        db.StorageFormatVersion = EA_STORAGE_VERSION
        db.StorageMigrationState = nil
        collectgarbage("collect")
        print("|cff00ff00[EasyAuction]|r 历史价格存储格式升级完成。")
    else
        C_Timer.After(0.05, EasyAuction_MigrateStorageV2)
    end
end

function EasyAuction_ShowScanResult(new, update, totalKinds, elapsed)
    if not EasyAuctionScanProgressFrame then return end
    local f = EasyAuctionScanProgressFrame
    f:UpdateProgress(totalKinds or 1, totalKinds or 1)
    f.Status:SetText(string.format("扫描完成  用时 %.1fs", elapsed or 0))
    f:ShowResult(string.format("总种类 %d    新增 %d    更新 %d\n建议重载界面保存全服扫描数据。", totalKinds or 0, new or 0, update or 0))
    f:Show()
end

function EasyAuction_HideScanProgress()
    if EasyAuctionScanProgressFrame then
        EasyAuctionScanProgressFrame:Hide()
    end
end

if EasyAuctionScanFinishFrame then
    EasyAuctionScanFinishFrame:Hide()
    EasyAuctionScanFinishFrame = nil
end

local function ShowEasyAuctionScanFinishFrame()
    if EasyAuctionScanProgressFrame then
        EasyAuctionScanProgressFrame:Show()
    end
end

local function EA_AccumulateScanBucket(bucket, unit, count, ts)
    if not bucket or not unit or unit <= 0 or not count or count <= 0 then
        return
    end
    local unitKey = tostring(unit)
    bucket.byUnit = bucket.byUnit or {}
    if bucket.byUnit[unitKey] then
        bucket.byUnit[unitKey].count = (bucket.byUnit[unitKey].count or 0) + count
        if ts and ts > (bucket.byUnit[unitKey].t or 0) then
            bucket.byUnit[unitKey].t = ts
        end
    else
        bucket.byUnit[unitKey] = { unit = unit, count = count, t = ts or time() }
    end
    bucket.totalCount = (bucket.totalCount or 0) + count
    if not bucket.minUnit or unit < bucket.minUnit then
        bucket.minUnit = unit
        bucket.minCount = count
    elseif unit == bucket.minUnit then
        bucket.minCount = (bucket.minCount or 0) + count
    end
    if not bucket.maxUnit or unit > bucket.maxUnit then
        bucket.maxUnit = unit
        bucket.maxCount = count
    elseif unit == bucket.maxUnit then
        bucket.maxCount = (bucket.maxCount or 0) + count
    end
end

function EasyAuction_ScanCategory(cat)
    local QUERY_RETRY_DELAY = 0.08
    local NEXT_QUERY_DELAY = 0.05
    local QUERY_TIMEOUT = 1.8

    if IsScanningAll or IsScanningCategory then
        print("|cff00ff00[EasyAuction]|r 正在扫描中，请稍候...")
        return
    end
    if not cat or cat == "全类" then
        print("|cffff0000[EasyAuction]|r 请选择一个具体分类。")
        return
    end

    local canQuery = select(1, CanSendAuctionQuery())
    if not canQuery then
        print("|cffff0000[EasyAuction]|r 当前拍卖行搜索不可用，请稍后再试。")
        return
    end

    local queue, dedupe = {}, {}
    for _, info in ipairs(EA_GetCategoryEntries(cat)) do
        local name = EA_TrimText(info[1])
        local itemID = tonumber(info[2])
        if name ~= "" and itemID and itemID > 0 and not dedupe[itemID] then
            dedupe[itemID] = true
            queue[#queue + 1] = { name = name, itemID = itemID }
        end
    end

    if #queue == 0 then
        print(string.format("|cffff0000[EasyAuction]|r [%s] 分类没有可扫描的物品。", cat))
        return
    end

    EasyAuction_RunDailyCleanup(false)
    IsScanningCategory = true
    UpdateScanBtnState()
    UpdateAuctionQueryStatusText()
    EasyAuction_ShowScanProgress()
    EasyAuction_UpdateScanProgress(0, #queue, 0)

    local scanFrame = _G.EasyAuctionCategoryScanFrame or CreateFrame("Frame", "EasyAuctionCategoryScanFrame")
    local scanStartTime = GetTime()
    local queueIndex = 0
    local newCount, updateCount = 0, 0
    local currentItem = nil
    local currentPage = 0
    local currentBucket = nil
    local currentToken = 0
    local currentRequestID = 0
    local dispatchCurrentQuery

    local function finishScan(message)
        scanFrame:UnregisterAllEvents()
        IsScanningCategory = false
        UpdateScanBtnState()
        UpdateAuctionQueryStatusText()
        if message then
            EasyAuction_HideScanProgress()
            print(message)
            return
        end
        EasyAuction_ShowScanResult(newCount, updateCount, #queue, GetTime() - scanStartTime)
        EA_RefreshCategoryViewsAfterEdit(cat)
    end

    local function finishCurrentItem()
        if not IsScanningCategory or not currentItem then
            return
        end
        local key = currentItem.name .. ":" .. tostring(currentItem.itemID)
        local storedAt = time()
        if currentBucket and next(currentBucket.byUnit or {}) then
            local itemNew, itemUpdate = EA_SaveAggregatedBuckets({ [key] = currentBucket }, storedAt)
            newCount = newCount + itemNew
            updateCount = updateCount + itemUpdate
        elseif EasyAuctionDB.PriceHistory and EasyAuctionDB.PriceHistory[key] then
            local history = EasyAuction_GetPriceHistory(key, EasyAuctionDB)
            EasyAuction_SetPriceHistory(key, history, history.minUnit, storedAt, EasyAuctionDB)
        end
        currentItem = nil
        currentBucket = nil
        currentPage = 0
        EasyAuction_UpdateScanProgress(queueIndex, #queue, GetTime() - scanStartTime)
        if queueIndex >= #queue then
            finishScan(nil)
        else
            C_Timer.After(NEXT_QUERY_DELAY, function()
                if IsScanningCategory then
                    currentToken = currentToken + 1
                    queueIndex = queueIndex + 1
                    currentItem = queue[queueIndex]
                    currentBucket = { byUnit = {}, totalCount = 0 }
                    currentPage = 0
                    dispatchCurrentQuery()
                end
            end)
        end
    end

    dispatchCurrentQuery = function()
        local token = currentToken
        local function tryQuery()
            if not IsScanningCategory or token ~= currentToken or not currentItem then
                return
            end
            local searchReady = select(1, CanSendAuctionQuery())
            if searchReady then
                currentRequestID = currentRequestID + 1
                local requestID = currentRequestID
                scanFrame:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
                -- Classic AH uses the legacy signature:
                -- QueryAuctionItems(name, minLevel, maxLevel, page, isUsable, quality, getAll, exactMatch, filters)
                QueryAuctionItems(currentItem.name, nil, nil, currentPage, nil, nil, false, true, nil)
                C_Timer.After(QUERY_TIMEOUT, function()
                    if IsScanningCategory and token == currentToken and requestID == currentRequestID and currentItem then
                        scanFrame:UnregisterEvent("AUCTION_ITEM_LIST_UPDATE")
                        finishCurrentItem()
                    end
                end)
            else
                C_Timer.After(QUERY_RETRY_DELAY, tryQuery)
            end
        end
        tryQuery()
    end

    scanFrame:SetScript("OnEvent", function(self, event)
        if not IsScanningCategory or not currentItem then
            self:UnregisterAllEvents()
            return
        end
        self:UnregisterEvent("AUCTION_ITEM_LIST_UPDATE")
        local n = GetNumAuctionItems("list")
        local nowTs = time()
        for i = 1, n do
            local _, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemID = GetAuctionItemInfo("list", i)
            local link = GetAuctionItemLink("list", i)
            local linkID = tonumber(link and link:match("item:(%d+)")) or tonumber(itemID)
            if linkID == currentItem.itemID and buyout and buyout > 0 and count and count > 0 then
                local unit = math.floor((buyout / count) + 0.5)
                EA_AccumulateScanBucket(currentBucket, unit, count, nowTs)
            end
        end

        if n >= 50 then
            currentPage = currentPage + 1
            C_Timer.After(NEXT_QUERY_DELAY, dispatchCurrentQuery)
        else
            finishCurrentItem()
        end
    end)

    queueIndex = 1
    currentToken = currentToken + 1
    currentItem = queue[queueIndex]
    currentBucket = { byUnit = {}, totalCount = 0 }
    currentPage = 0
    dispatchCurrentQuery()
end

function EasyAuction_ShowScanModeSelector()
    if not EasyAuctionScanModeSelectorFrame then
        local parent = _G.AuctionHelper or UIParent
        local f = CreateFrame("Frame", "EasyAuctionScanModeSelectorFrame", parent, "BackdropTemplate")
        f:SetSize(320, 260)
        if _G.AuctionHelper then
            f:SetPoint("TOPLEFT", _G.AuctionHelper, "TOPRIGHT", 6, 0)
        else
            f:SetPoint("CENTER")
        end
        EA_RaiseUtilityFrame(f)
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        if EasyAuctionStyle then
            EasyAuctionStyle:Skin(f, "panel")
        else
            f:SetBackdrop({
                bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true,
                tileSize = 16,
                edgeSize = 12,
                insets = { left = 3, right = 3, top = 3, bottom = 3 }
            })
        end

        local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
        title:SetPoint("TOPLEFT", 12, -10)
        title:SetText("拍卖行扫描")
        if EasyAuctionStyle then EasyAuctionStyle:SkinText(title, "accent") end

        local desc = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
        desc:SetPoint("RIGHT", -20, 0)
        desc:SetJustifyH("LEFT")
        desc:SetText("全量扫描会抓取整个拍卖行；分类扫描只抓取指定分类。分类不一定比全量更快。")
        if EasyAuctionStyle then EasyAuctionStyle:SkinText(desc, "muted") end

        local fullBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        fullBtn:SetSize(92, 22)
        fullBtn:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -12)
        fullBtn:SetText("全量扫描")
        if EasyAuctionStyle then EasyAuctionStyle:SkinButton(fullBtn) end
        fullBtn:SetScript("OnClick", function()
            f:Hide()
            StaticPopup_Show("EASYAUCTION_SCANALL_CONFIRM")
        end)
        f.fullBtn = fullBtn

        local fullStatus = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fullStatus:SetPoint("LEFT", fullBtn, "RIGHT", 10, 0)
        fullStatus:SetPoint("RIGHT", -16, 0)
        fullStatus:SetJustifyH("LEFT")
        fullStatus:SetText("")
        if EasyAuctionStyle then EasyAuctionStyle:SkinText(fullStatus, "muted") end
        f.fullStatus = fullStatus

        f.categoryBtns = {}
        for index, cat in ipairs(EA_SCAN_CATEGORIES) do
            local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            btn:SetSize(58, 22)
            local row = math.floor((index - 1) / 4)
            local col = (index - 1) % 4
            btn:SetPoint("TOPLEFT", f, "TOPLEFT", 20 + col * 72, -118 - row * 28)
            btn:SetText(cat)
            if EasyAuctionStyle then EasyAuctionStyle:SkinButton(btn) end
            btn:SetScript("OnClick", function()
                f:Hide()
                EasyAuction_ScanCategory(cat)
            end)
            f.categoryBtns[#f.categoryBtns + 1] = btn
        end

        local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        closeBtn:SetSize(22, 22)
        closeBtn:SetPoint("TOPRIGHT", -6, -6)
        closeBtn:SetText("\195\151")
        if EasyAuctionStyle then EasyAuctionStyle:SkinButton(closeBtn) end
        closeBtn:SetScript("OnClick", function()
            f:Hide()
        end)

        function f:RefreshScanModeState()
            local canQuery, canQueryAll = CanSendAuctionQuery()
            local busy = IsScanningAll or IsScanningCategory
            if busy or canQueryAll then
                self.fullFallbackStart = nil
            elseif not self.fullFallbackStart then
                self.fullFallbackStart = GetTime()
            end
            local fallbackRemaining = nil
            local fallbackReady = false
            if self.fullFallbackStart then
                fallbackRemaining = EA_FULL_SCAN_FALLBACK_SECONDS - (GetTime() - self.fullFallbackStart)
                if fallbackRemaining <= 0 then
                    fallbackReady = true
                    fallbackRemaining = 0
                else
                    fallbackRemaining = math.ceil(fallbackRemaining)
                end
            end
            local fullReady = (not busy) and (canQueryAll or fallbackReady)
            self.fullBtn:SetEnabled(fullReady)
            if EasyAuctionStyle and EasyAuctionStyle.SetButtonDisabled then
                EasyAuctionStyle:SetButtonDisabled(self.fullBtn, not fullReady)
            end
            if busy then
                self.fullBtn:SetText("扫描中")
                self.fullStatus:SetText("")
            elseif canQueryAll then
                self.fullBtn:SetText("全量扫描")
                self.fullStatus:SetText("")
            elseif fallbackReady then
                self.fullBtn:SetText("全量扫描")
                self.fullStatus:SetText("兜底可试")
            else
                local remaining = EA_GetFullScanCooldownRemaining()
                if remaining and remaining > 0 then
                    local minutes = math.floor(remaining / 60)
                    local seconds = remaining % 60
                    self.fullBtn:SetText(string.format("%02d:%02d", minutes, seconds))
                    self.fullStatus:SetText("全量冷却中")
                elseif fallbackRemaining and fallbackRemaining > 0 then
                    self.fullBtn:SetText(string.format("00:%02d", fallbackRemaining))
                    self.fullStatus:SetText("等待全量可用")
                else
                    self.fullBtn:SetText("等待中")
                    self.fullStatus:SetText("等待全量扫描可用")
                end
            end
            for _, btn in ipairs(self.categoryBtns or {}) do
                local categoryReady = (not busy) and canQuery
                btn:SetEnabled(categoryReady)
                if EasyAuctionStyle and EasyAuctionStyle.SetButtonDisabled then
                    EasyAuctionStyle:SetButtonDisabled(btn, not categoryReady)
                end
            end
        end

        f:SetScript("OnShow", function(self)
            EA_RaiseUtilityFrame(self)
            self.fullFallbackStart = nil
            self:RefreshScanModeState()
            if self.scanStateTicker then
                self.scanStateTicker:Cancel()
            end
            self.scanStateTicker = C_Timer.NewTicker(1, function()
                if self:IsShown() then
                    self:RefreshScanModeState()
                end
            end)
        end)

        f:SetScript("OnHide", function(self)
            self.fullFallbackStart = nil
            if self.scanStateTicker then
                self.scanStateTicker:Cancel()
                self.scanStateTicker = nil
            end
        end)

        EasyAuctionScanModeSelectorFrame = f
        f:Hide()
    end

    if EasyAuctionScanModeSelectorFrame:IsShown() then
        EasyAuctionScanModeSelectorFrame:Hide()
    else
        EasyAuctionScanModeSelectorFrame:ClearAllPoints()
        if _G.AuctionHelper then
            EasyAuctionScanModeSelectorFrame:SetPoint("TOPLEFT", _G.AuctionHelper, "TOPRIGHT", 6, 0)
        else
            EasyAuctionScanModeSelectorFrame:SetPoint("CENTER")
        end
        EA_RaiseUtilityFrame(EasyAuctionScanModeSelectorFrame)
        EasyAuctionScanModeSelectorFrame:Show()
    end
end

function EasyAuction_ScanAllAuctionItems()
    EasyAuctionDB.debugPrint = false
    if IsScanningAll or IsScanningCategory then
        print("|cff00ff00[EasyAuction]|r 正在扫描中，请稍候...")
        return
    end

    --print("|cff00ff00[EasyAuction]|r ===== 扫描开始 =====")
    EasyAuction_RunDailyCleanup(false)
    EA_CancelActiveFullScan()
    local scanState = {
        cancelled = false,
        processingStarted = false,
        finalized = false,
        eventFrame = nil,
        cleanup = nil,
    }
    EA_ActiveFullScanState = scanState
    IsScanningAll = true
    UpdateScanBtnState()
    UpdateAuctionQueryStatusText()
    EasyAuction_ShowScanProgress()

    local scanStartTime = GetTime()
    local perFrame      = EA_ClampInt(EasyAuctionDB.scanPerFrame or 200, 200, 50, 500)
    local keepPerItem   = EA_ClampInt(EasyAuctionDB.scanKeepPerItem or 120, 120, 20, 500)
    if perFrame < 50 then perFrame = 50 elseif perFrame >= 500 then perFrame = 200 end
    EasyAuctionDB.scanPerFrame = perFrame
    EasyAuctionDB.scanKeepPerItem = keepPerItem
    local totalItems            = 0
    local result                = {}
    local totalKinds            = 0
    local newCount, updateCount = 0, 0
    local waitingItems          = {}
    local processedIndexes      = {}

    scanState.cleanup = function()
        for k in pairs(result) do result[k] = nil end
        for k in pairs(waitingItems) do waitingItems[k] = nil end
        for k in pairs(processedIndexes) do processedIndexes[k] = nil end
    end

    local function isCurrentScan()
        return IsScanningAll
            and EA_ActiveFullScanState == scanState
            and not scanState.cancelled
            and not scanState.finalized
    end

    local function abortScan(hideProgress)
        if EA_ActiveFullScanState ~= scanState then return end
        EA_CancelActiveFullScan()
        IsScanningAll = false
        UpdateScanBtnState()
        UpdateAuctionQueryStatusText()
        if hideProgress then
            EasyAuction_HideScanProgress()
        end
    end

    local RETRY_MAX             = 5   -- 最多重试5次
    local RETRY_DELAY           = 0.2 -- 每次重试间隔
    local RETRY_TIMEOUT         = 2.5 -- 超时后丢弃

    local function finalizeScan()
        if not isCurrentScan() then return end
        scanState.finalized = true
        if scanState.eventFrame then
            scanState.eventFrame:UnregisterAllEvents()
            scanState.eventFrame:SetScript("OnEvent", nil)
            scanState.eventFrame = nil
        end
        local cleanup = scanState.cleanup
        scanState.cleanup = nil
        EA_ActiveFullScanState = nil
        if cleanup then cleanup() end
        collectgarbage("collect")
        IsScanningAll = false
        UpdateScanBtnState()
        UpdateAuctionQueryStatusText()
        EasyAuction_ShowScanResult(newCount, updateCount, totalKinds, GetTime() - scanStartTime)
        C_Timer.After(0.5, function()
            ShowEasyAuctionScanFinishFrame()
            C_Timer.After(2.0, function()
                C_Timer.After(2.0, function()
                    if EasyAuctionDBFrame and EasyAuctionDBFrame:IsShown() then
                        RefreshDBFrame()
                    end
                end)
            end)
        end)
    end

    local function updatePriceData(key, unit, count)
        local bucket = result[key]
        if not bucket then return end
        if not bucket.minUnit or unit < bucket.minUnit then
            bucket.minUnit = unit
            bucket.minCount = count
        elseif unit == bucket.minUnit then
            bucket.minCount = (bucket.minCount or 0) + count
        end
        if not bucket.maxUnit or unit > bucket.maxUnit then
            bucket.maxUnit = unit
        end
        bucket.totalCount = (bucket.totalCount or 0) + count
    end

    local function processItemData(itemInfo, index)
        if not itemInfo or not isCurrentScan() then
            print("|cffff0000[EasyAuction]|r processItemData 返回: 无效数据或扫描已停止")
            return 
        end
        --print(string.format("|cff00ff00[EasyAuction]|r processItemData: index=%d", index))
        local link = itemInfo.link
        local itemID = itemInfo.itemID
        local count = itemInfo.count
        local buyout = itemInfo.buyout
        local unit = itemInfo.unit

        if not link or not itemID or not buyout or buyout <= 0 or not count or count <= 0 then return end

        local linkID = tonumber(link:match("item:(%d+)"))
        if linkID ~= itemID then return end

        local safeName = select(1, GetItemInfo(link))
        if not safeName or safeName == "" then return end

        local key = safeName .. ":" .. linkID
        --print(string.format("|cff00ff00[EasyAuction]|r 生成key: %s", key))

        result[key] = result[key] or { byUnit = {} }
        local bucket = result[key]
        local nowTs = time()
        local unitKey = tostring(unit)
        if bucket.byUnit[unitKey] then
            bucket.byUnit[unitKey].count = (bucket.byUnit[unitKey].count or 0) + count
            if nowTs > (bucket.byUnit[unitKey].t or 0) then
                bucket.byUnit[unitKey].t = nowTs
            end
        else
            bucket.byUnit[unitKey] = {
                unit = unit,
                count = count,
                t = nowTs,
            }
        end
        totalItems = totalItems + 1

        updatePriceData(key, unit, count)
        processedIndexes[index] = true

        if EasyAuctionDB.debugPrint then
            print(string.format("入库: index=%d, name=%s, itemID=%d, linkID=%d, link=%s, 单价=%d, 数量=%d", index, safeName, itemID, linkID, link, unit, count))
        end
    end

    local processBatch
    processBatch = function(startIndex)
        if not isCurrentScan() then return end
        --print(string.format("|cff00ff00[EasyAuction]|r processBatch 被调用, startIndex=%s", tostring(startIndex)))
        startIndex = startIndex or 0
        local n = GetNumAuctionItems("list")
        --print(string.format("|cff00ff00[EasyAuction]|r 当前拍卖物品总数: %d, 起始索引: %d", n, startIndex))
        if startIndex >= n then
            --print("|cff00ff00[EasyAuction]|r 扫描完成，准备保存数据...")
            -- 检查是否还有等待加载的物品
            local hasWaitingItems = false
            for idx, _ in pairs(waitingItems) do
                if not processedIndexes[idx] then
                    hasWaitingItems = true
                    break
                end
            end

            if hasWaitingItems then
                --print("|cff00ff00[EasyAuction]|r 存在等待物品，延迟0.5秒重试...")
                C_Timer.After(0.5, function()
                    processBatch(startIndex)
                end)
                return
            end

            local itemKeys = {}
            for k in pairs(result) do table.insert(itemKeys, k) end
            totalKinds = #itemKeys
            --print(string.format("|cff00ff00[EasyAuction]|r 收集到 %d 种物品，准备分批保存...", totalKinds))
            -- 打印前5个key用于调试
            for i = 1, math.min(5, #itemKeys) do
                local key = itemKeys[i]
                local itemCount = 0
                if result[key] and type(result[key].byUnit) == "table" then
                    for _ in pairs(result[key].byUnit) do
                        itemCount = itemCount + 1
                    end
                elseif result[key] and type(result[key]) == "table" then
                    itemCount = #result[key]
                end
                --print(string.format("|cff00ff00[EasyAuction]|r 物品示例 %d: key=%s, 记录数=%d", i, key, itemCount))
            end
            local idx = 1
            local perSave = 50

            local function saveBatch()
                if not isCurrentScan() then return end
                --print(string.format("|cff00ff00[EasyAuction]|r saveBatch 被调用, idx=%d, totalKinds=%d", idx, totalKinds))
                local i = 0
                local savedCount = 0
                while idx <= totalKinds and i < perSave do
                    local key = itemKeys[idx]
                    if key and key ~= "" then
                        local bucket = result[key]
                        local items = nil
                        if type(bucket) == "table" then
                            if bucket.byUnit then
                                local tmp = {}
                                for _, rec in pairs(bucket.byUnit) do
                                    tmp[#tmp + 1] = rec
                                end
                                items = tmp
                            else
                                items = bucket
                            end
                        end

                        if type(items) == "table" and #items > 0 then
                            local compressed = nil
                            compressed = EA_CompressHistoryRecords(items, keepPerItem, nil)
                            items = compressed
                            if items[1] and items[1].unit and items[1].unit > 0 then
                                local prev = EasyAuctionDB.PriceHistory[key]
                                if not prev then
                                    newCount = newCount + 1
                                else
                                    updateCount = updateCount + 1
                                end
                                local minUnit = EasyAuction_GetPriceHistoryMinUnit(key, EasyAuctionDB)
                                for _, v in ipairs(items) do
                                    if v.unit and (not minUnit or v.unit < minUnit) then
                                        minUnit = v.unit
                                    end
                                end
                                local storedAt = time()
                                EasyAuction_SetPriceHistory(key, items, minUnit or 0, storedAt, EasyAuctionDB)
                                local bucketMin = bucket.minUnit or minUnit or 0
                                local bucketMinCount = bucket.minCount or 0
                                local bucketMax = bucket.maxUnit or bucketMin
                                local bucketTotal = bucket.totalCount or bucketMinCount
                                local hour = tonumber(date("%H"))
                                local today = date("%Y-%m-%d")
                                local hourlyRecords = EasyAuction_GetHourlyMinPrice(key, EasyAuctionDB)
                                hourlyRecords = EA_AddOrUpdateHourlyRecord(hourlyRecords, hour, bucketMin, bucketMinCount, bucketTotal, storedAt)
                                EasyAuction_SetHourlyMinPrice(key, hourlyRecords, EasyAuctionDB)
                                local dailyRecords = EasyAuction_GetDailyMinPrice(key, EasyAuctionDB)
                                dailyRecords = EA_AddOrUpdateDailyRecord(dailyRecords, today, bucketMin, bucketMinCount, bucketMin, bucketMax, bucketTotal)
                                EasyAuction_SetDailyMinPrice(key, dailyRecords, EasyAuctionDB)
                                savedCount = savedCount + 1
                                --print(string.format("|cff00ff00[EasyAuction]|r 已保存: key=%s, items=%d, minUnit=%s", key, #items, tostring(minUnit)))
                            else
                                --print(string.format("|cffff0000[EasyAuction]|r 保存失败: items[1].unit 无效, key=%s", key))
                            end
                        else
                            --print(string.format("|cffff0000[EasyAuction]|r 保存失败: items 表为空或无效, key=%s", key))
                        end
                    else
                        --print(string.format("|cffff0000[EasyAuction]|r 保存失败: key 为空"))
                    end
                    if key then
                        result[key] = nil
                    end
                    idx = idx + 1
                    i = i + 1
                end
                --print(string.format("|cff00ff00[EasyAuction]|r 本批次保存完成: savedCount=%d, idx=%d", savedCount, idx))
                if idx % 50 == 0 or idx == totalKinds then
                    EasyAuction_UpdateScanProgress(idx - 1, totalKinds, GetTime() - scanStartTime)
                end
                if idx <= totalKinds then
                    C_Timer.After(0.01, saveBatch)       -- 分批续写
                else
                    finalizeScan()
                end
            end
            saveBatch()
        else
            local endIndex = math.min(startIndex + perFrame, n)
            for i = startIndex + 1, endIndex do
                if i % 50 == 0 or i == n then
                    EasyAuction_UpdateScanProgress(i, n, GetTime() - scanStartTime)
                end
                local name, _, count, _, _, _, _, _, _, buyout, _, _, _, owner, _, _, itemID = GetAuctionItemInfo("list", i)
                local link = GetAuctionItemLink("list", i)
                local unit = (buyout and count and count > 0) and math.floor(buyout / count) or nil

                if not processedIndexes[i] then
                    if link and itemID and itemID > 0 and buyout and count and count > 0 then
                        local safeName = select(1, GetItemInfo(link))
                        -- link存在，但name未缓存时，也要等待name
                        if safeName and safeName ~= "" then
                            processItemData({
                                name = safeName,
                                count = count,
                                buyout = buyout,
                                owner = owner,
                                itemID = itemID,
                                unit = unit,
                                link = link,
                                index = i
                            }, i)
                        else
                            -- name未缓存，丢到等待队列
                            if not waitingItems[i] then
                                waitingItems[i] = {
                                    name = nil,
                                    count = count,
                                    buyout = buyout,
                                    owner = owner,
                                    itemID = itemID,
                                    unit = unit,
                                    link = link,
                                    index = i,
                                    startTime = GetTime(),
                                    retry = 0,
                                }
                                local item = Item:CreateFromItemID(itemID)
                                item:ContinueOnItemLoad(function()
                                    C_Timer.After(0, function()
                                        local ref = waitingItems[i]
                                        if ref and isCurrentScan() then
                                            local cachedName = select(1, GetItemInfo(link))
                                            if cachedName and cachedName ~= "" then
                                                ref.name = cachedName
                                                processItemData(ref, i)
                                                waitingItems[i] = nil
                                                processedIndexes[i] = true
                                            end
                                        end
                                    end)
                                end)
                            end
                        end
                        processedIndexes[i] = true
                    else
                        -- link未获取到，需异步等待
                        if itemID and itemID > 0 and not waitingItems[i] then
                            waitingItems[i] = {
                                name = nil,
                                count = count,
                                buyout = buyout,
                                owner = owner,
                                itemID = itemID,
                                unit = unit,
                                link = nil,
                                index = i,
                                startTime = GetTime(),
                                retry = 0,
                            }
                            local function tryLoadItemInfo(waitItem)
                                if not isCurrentScan() or not waitItem then return end
                                waitItem.retry = (waitItem.retry or 0) + 1
                                local loadedLink = GetAuctionItemLink("list", i)
                                local loadedName = loadedLink and select(1, GetItemInfo(loadedLink))
                                local now = GetTime()
                                if loadedLink and loadedName and loadedName ~= "" then
                                    waitItem.link = loadedLink
                                    waitItem.name = loadedName
                                    processItemData(waitItem, i)
                                    waitingItems[i] = nil
                                    processedIndexes[i] = true
                                elseif waitItem.retry * RETRY_DELAY > RETRY_TIMEOUT then
                                    -- 超时放弃，不降级写入
                                    waitingItems[i] = nil
                                    processedIndexes[i] = true
                                    if EasyAuctionDB.debugPrint then
                                        print(string.format("超时丢弃 index=%d, itemID=%s", i, tostring(itemID)))
                                    end
                                else
                                    C_Timer.After(RETRY_DELAY, function()
                                        tryLoadItemInfo(waitItem)
                                    end)
                                end
                            end
                            -- 异步加载物品
                            local item = Item:CreateFromItemID(itemID)
                            item:ContinueOnItemLoad(function()
                                tryLoadItemInfo(waitingItems[i])
                            end)
                        end
                    end
                end
            end

            --print(string.format("|cff00ff00[EasyAuction]|r 本批次处理完成，准备处理下一批: endIndex=%d", endIndex))
            C_Timer.After(0.05, function()
                if isCurrentScan() then
                    processBatch(endIndex)
                else
                    --print("|cffff0000[EasyAuction]|r 扫描被中断，不再继续")
                end
            end)
        end
    end

    local function startProcessing()
        if not isCurrentScan() or scanState.processingStarted then return false end
        scanState.processingStarted = true
        processBatch(0)
        return true
    end

    --print("|cff00ff00[EasyAuction]|r 注册 AUCTION_ITEM_LIST_UPDATE 事件...")
    local eventFrame = CreateFrame("Frame")
    scanState.eventFrame = eventFrame
    eventFrame:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
    eventFrame:SetScript("OnEvent", function(self)
        --print("|cff00ff00[EasyAuction]|r AUCTION_ITEM_LIST_UPDATE 触发，开始处理数据...")
        self:UnregisterAllEvents()
        startProcessing()
    end)

-- 必须在拍卖行界面，并且在“浏览”Tab
    if not (AuctionFrame and AuctionFrame:IsShown()) then
        --print("|cffff0000[EasyAuction]|r 拍卖行界面未打开，无法扫描！")
        BuildItemIDIndex()
        abortScan(true)
        return
    end

    -- 封装安全的Query方式，保证真的在浏览页
    local function TryQueryAuctionItems(retries)
        if not isCurrentScan() then return end
        retries = retries or 0
        if not AuctionFrameBrowse:IsShown() then
            AuctionFrameTab1:Click()
            C_Timer.After(0.25, function()
                if not isCurrentScan() then return end
                -- 最多尝试3次
                if retries < 3 then
                    TryQueryAuctionItems(retries + 1)
                else
                    if not AuctionFrameBrowse:IsShown() then
                        --print("|cffff0000[EasyAuction]|r 始终无法切换至浏览页，扫描中止")
                        abortScan(true)
                        return
                    end
                end
            end)
        else
            --print("|cff00ff00[EasyAuction]|r 已在浏览页，开始全服拍卖查询")
            QueryAuctionItems("", nil, nil, 0, nil, nil, true, true, nil)
        end
    end

    TryQueryAuctionItems()

    -- 兜底：5秒内仍未触发事件则强行推进
    C_Timer.After(5, function()
        if not isCurrentScan() then return end
        if GetNumAuctionItems("list") > 0 then
            --print("|cff00ff00[EasyAuction]|r [兜底] 事件未触发，手动进入处理流程")
            startProcessing()
        elseif not scanState.processingStarted then
            --print("|cffff0000[EasyAuction]|r [兜底] 5秒后仍未获取到拍卖数据，扫描中止")
            abortScan(true)
        end
    end)
end

StaticPopupDialogs["EASYAUCTION_SCANALL_CONFIRM"] = {
    text =
    "|cffff4040警告|r\n\n本操作将自动扫描所有拍卖物品。\n扫描期间请勿操作鼠标和键盘，避免拍卖数据异常。\n\n请确认你已准备好再继续。",
    button1 = "我已知晓风险，继续",
    button2 = "取消",
    OnAccept = function()
        EasyAuction_ScanAllAuctionItems()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}
StaticPopupDialogs["EASYAUCTION_BUYOUT_CONFIRM"] = {
    text = "|cffff4040警告|r\n\n当前物品一口价已超过风控金额。\n本次一口价：%s\n请仔细核对价格，确认后再购买。",
    button1 = "确定",
    button2 = "取消",
    OnAccept = function(self, data)
        if data and data.func then
            data.func()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    hasMoneyFrame = false,
}
StaticPopupDialogs["EASYAUCTION_BID_CONFIRM"] = {
    text = "|cffffcc00竞价确认|r\n\n将以 %s 参与竞价。\n请确认价格无误。",
    button1 = "确认竞价",
    button2 = "取消",
    OnAccept = function(self, data)
        if data and data.func then
            data.func()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
    hasMoneyFrame = false,
}


local function SetFlashBuyButtonsVisible(visible)
    local allowBuyButton = not EasyAuctionDB or EasyAuctionDB.enableBrowseBuyButton ~= false
    for i = 1, NUM_BROWSE_TO_DISPLAY do
        local row = _G["BrowseButton" .. i]
        if row and row.EasyAuctionFlashBuy then
            if visible and allowBuyButton then
                row.EasyAuctionFlashBuy:Show()
            else
                row.EasyAuctionFlashBuy:Hide()
            end
        end
    end
end

local function SetFlashBuyModeEnabled(enabled)
    SetFlashBuyButtonsVisible(not enabled)
    if type(EasyAuction_RefreshFlashBuyButtons) == "function" then
        EasyAuction_RefreshFlashBuyButtons()
    end
end

local function AttachBrowseActionTooltip(button, title, text)
    if not button or button.__EasyAuctionActionTooltip then return end
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 1, 1)
        GameTooltip:AddLine(text, 0.85, 0.85, 0.85, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    button.__EasyAuctionActionTooltip = true
end

function EasyAuction_CreateBuyoutButton()
    if _G["EasyAuctionBuyoutCheckButton"] or not AuctionFrameBrowse then return end
    local btn = CreateFrame("CheckButton", "EasyAuctionBuyoutCheckButton", AuctionFrameBrowse, "UICheckButtonTemplate")
    if _G["EasyAuctionAllowOverBuyCheck"] then
        btn:SetPoint("LEFT", EasyAuctionAllowOverBuyCheck, "RIGHT", 30, 0)
    else
        btn:SetPoint("LEFT", AuctionFrameBrowse, "TOPLEFT", 530, -52)
    end
    btn:SetSize(26, 26)
    local txt = _G["EasyAuctionBuyoutCheckButtonText"]
    txt:SetFontObject(GameFontHighlightSmall)
    txt:SetText(
        "|cffff4040闪|r" ..
        "|cffffa840购|r" ..
        "|cffffed40模|r" ..
        "|cff90ee90式|r"
    )
    txt:EnableMouse(true)
    txt:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("闪购模式", 1, 1, 1, true)
        GameTooltip:AddLine("开启后：", 1, 1, 0.8, true)
        GameTooltip:AddLine("1. 点击拍卖记录的任意位置，将自动直接购买，无需确认。", 1, 1, 1, true)
        GameTooltip:AddLine("2. 原有的‘买’按钮将被隐藏。", 1, 0.9, 0.2, true)
        GameTooltip:AddLine("（大于100金会弹出系统确认窗口）", 1, 0.5, 0.5, true)
        GameTooltip:AddLine("|cffff0000请谨慎操作，防止误买！|r", 1, 0.4, 0.4, true)
        GameTooltip:Show()
    end)
    txt:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    btn:SetScript("OnClick", function(self)
        SetFlashBuyModeEnabled(self:GetChecked())
    end)

    C_Timer.After(0.1, function()
        SetFlashBuyModeEnabled(btn:GetChecked())
    end)

    if not EasyAuction_BuyoutHooked then
        hooksecurefunc("BrowseButton_OnClick", function(button)
            if EasyAuctionBuyoutCheckButton and EasyAuctionBuyoutCheckButton:GetChecked() then
                local index = GetSelectedAuctionItem and AuctionFrame and AuctionFrame.type and
                    GetSelectedAuctionItem(AuctionFrame.type)
                local buyout = AuctionFrame and AuctionFrame.buyoutPrice
                if index and buyout and buyout > 0 then
                    local buyRiskLimit = EasyAuctionDB.buyRiskLimit or 500
                    if buyRiskLimit > 0 and buyout > buyRiskLimit * 10000 then
                        local priceText = FormatGoldText(buyout)
                        StaticPopup_Show("EASYAUCTION_BUYOUT_CONFIRM", priceText, nil, {
                            func = function()
                                PlaceAuctionBid(AuctionFrame.type, index, buyout)
                            end
                        })
                    else
                        PlaceAuctionBid(AuctionFrame.type, index, buyout)
                    end
                end
            end
        end)
        EasyAuction_BuyoutHooked = true
    end
end

function EasyAuction_EnsureFlashBuyButtons()
    for i = 1, NUM_BROWSE_TO_DISPLAY do
        local row = _G["BrowseButton" .. i]
        if row and not row.EasyAuctionFlashBuy then
            local btn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            btn:SetSize(28, 28)
            btn:SetText("买")
            btn:SetPoint("RIGHT", row, "RIGHT", -160, 2)
            btn:Hide()
            btn:SetFrameLevel(row:GetFrameLevel() + 10)
            btn:SetFrameStrata(row:GetFrameStrata() or "HIGH")
            AttachBrowseActionTooltip(btn, "购买", "点击后按一口价购买。")
            row.EasyAuctionFlashBuy = btn
        end
        if row and not row.EasyAuctionFlashBid then
            local btn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            btn:SetSize(28, 28)
            btn:SetText("竞")
            btn:SetPoint("RIGHT", row, "RIGHT", -190, 2)
            btn:Hide()
            btn:SetFrameLevel(row:GetFrameLevel() + 10)
            btn:SetFrameStrata(row:GetFrameStrata() or "HIGH")
            AttachBrowseActionTooltip(btn, "竞价", "点击后按当前最低可竞价出价。")
            row.EasyAuctionFlashBid = btn
        end
    end

    local function AttachEasyAuctionTooltip(frame, i)
        if not frame or frame._ea_tooltip_hooked then return end
        frame:HookScript("OnEnter", function(self)
            local offset = FauxScrollFrame_GetOffset(BrowseScrollFrame)
            local index = offset + i
            local name, texture, count, quality, canUse, level, levelColHeader, minBid, minIncrement, buyoutPrice, _, _, _, owner, _, _, itemID =
                GetAuctionItemInfo("list", index)

            if not name or not buyoutPrice or not count or count == 0 then return end
            local unitBuyout = math.floor(buyoutPrice / count + 0.5)

            local histMin = nil
            local todayMin = nil
            local today = date("%Y-%m-%d")
            local key = name .. ":" .. itemID
            local dailyArray = EasyAuction_GetDailyMinPrice(key, EasyAuctionDB)
            if EasyAuctionDB.PriceHistory and name and itemID then
                histMin = EasyAuction_GetPriceHistoryMinUnit(key, EasyAuctionDB)
                if dailyArray then
                    for _, daily in ipairs(dailyArray) do
                        if daily[1] == today then
                            todayMin = daily[4]
                            break
                        end
                    end
                end
            end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetAuctionItem("list", index)
            GameTooltip:AddDoubleLine("本行单价", FormatGoldIcon(unitBuyout), 1, 1, 1, 1, 1, 1)
            if histMin and histMin > 0 then
                local diff = unitBuyout - histMin
                diff = (diff >= 0) and math.floor(diff + 0.5) or math.ceil(diff - 0.5)
                local percent = diff / histMin * 100
                local percentColor = percent >= 0 and "|cffff6600" or "|cff00ff00"
                local diffColor = percent >= 0 and "|cffff6600" or "|cff00ff00"
                local leftText = format("比历史最低：%s%+.1f%%%s", percentColor, percent, "|r")
                local rightText = diffColor .. (diff >= 0 and "+" or "") .. FormatGoldIcon(diff) .. "|r"
                GameTooltip:AddDoubleLine(leftText, rightText, 1, 1, 1, 1, 1, 1)
            elseif histMin == nil then
                GameTooltip:AddDoubleLine("比历史最低：", "|cffff8888无数据|r", 1, 1, 1, 1, 1, 1)
            end

            if todayMin and todayMin > 0 then
                local diff = unitBuyout - todayMin
                diff = (diff >= 0) and math.floor(diff + 0.5) or math.ceil(diff - 0.5)
                local percent = diff / todayMin * 100
                local percentColor = percent >= 0 and "|cffffcc00" or "|cff00ff00"
                local diffColor = percent >= 0 and "|cffffcc00" or "|cff00ff00"
                local leftText = format("比今日最低：%s%+.1f%%%s", percentColor, percent, "|r")
                local rightText = diffColor .. (diff >= 0 and "+" or "") .. FormatGoldIcon(diff) .. "|r"
                GameTooltip:AddDoubleLine(leftText, rightText, 1, 1, 1, 1, 1, 1)
            elseif todayMin == nil then
                GameTooltip:AddDoubleLine("比今日最低：", "|cffff8888无数据|r", 1, 1, 1, 1, 1, 1)
            end

            GameTooltip:Show()
        end)
        frame:HookScript("OnLeave", function(self) GameTooltip:Hide() end)
        frame._ea_tooltip_hooked = true
    end

    for i = 1, NUM_BROWSE_TO_DISPLAY or 8 do
        local row = _G["BrowseButton" .. i]
        AttachEasyAuctionTooltip(row, i)
        AttachEasyAuctionTooltip(_G["BrowseButton" .. i .. "HighBidderName"], i)
        AttachEasyAuctionTooltip(_G["BrowseButton" .. i .. "BuyoutFrame"], i)
        AttachEasyAuctionTooltip(_G["BrowseButton" .. i .. "ClosingTime"], i)
        AttachEasyAuctionTooltip(_G["BrowseButton" .. i .. "Item"], i)
    end
end

function EasyAuction_RefreshFlashBuyButtons()
    if EasyAuctionBuyoutCheckButton and EasyAuctionBuyoutCheckButton:GetChecked() then
        for i = 1, NUM_BROWSE_TO_DISPLAY do
            local row = _G["BrowseButton" .. i]
            local buyBtn = row and row.EasyAuctionFlashBuy
            local bidBtn = row and row.EasyAuctionFlashBid
            if buyBtn then buyBtn:Hide() end
            if bidBtn then bidBtn:Hide() end
            if row and row.EasyAuctionHighBidderBG then
                row.EasyAuctionHighBidderBG:Hide()
            end
        end
        return
    end

    local offset = FauxScrollFrame_GetOffset(BrowseScrollFrame) or 0
    local myName = UnitName("player")
    local allowBuyButton = not EasyAuctionDB or EasyAuctionDB.enableBrowseBuyButton ~= false
    local allowBidButton = not EasyAuctionDB or EasyAuctionDB.enableBrowseBidButton ~= false
    for i = 1, NUM_BROWSE_TO_DISPLAY do
        local row = _G["BrowseButton" .. i]
        local buyBtn = row and row.EasyAuctionFlashBuy
        local bidBtn = row and row.EasyAuctionFlashBid
        local idx = offset + i
        local name, _, count, _, _, _, _, minBid, minIncrement, buyout, bid, highBidder,
            _, owner, _, saleStatus, itemID = GetAuctionItemInfo("list", idx)
        local isMine = owner and myName and (owner == myName or owner:find("^" .. myName .. "-"))
        local isHighBidder = highBidder == true or saleStatus == 1

        if row then
            if not row.EasyAuctionHighBidderBG then
                local bg = row:CreateTexture(nil, "BACKGROUND", nil, -1)
                bg:SetAllPoints(row)
                bg:SetColorTexture(0.6, 1, 0.6, 0.18)
                bg:Hide()
                row.EasyAuctionHighBidderBG = bg
            end
            if isHighBidder then
                row.EasyAuctionHighBidderBG:Show()
            else
                row.EasyAuctionHighBidderBG:Hide()
            end
        end

        if buyBtn then
            buyBtn:ClearAllPoints()
            buyBtn:SetPoint("RIGHT", row, "RIGHT", -160, 2)
            if allowBuyButton and buyout and buyout > 0 and not isMine then
                buyBtn:Show()
                buyBtn:SetEnabled(true)
                buyBtn:SetScript("OnClick", function(self)
                    local buyRiskLimit = EasyAuctionDB.buyRiskLimit or 500
                    if buyRiskLimit > 0 and buyout > buyRiskLimit * 10000 then
                        local priceText = FormatGoldText(buyout)
                        StaticPopup_Show("EASYAUCTION_BUYOUT_CONFIRM", priceText, nil, {
                            func = function()
                                PlaceAuctionBid("list", idx, buyout)
                            end
                        })
                    else
                        PlaceAuctionBid("list", idx, buyout)
                    end
                end)
            else
                buyBtn:Hide()
                buyBtn:SetEnabled(false)
                buyBtn:SetScript("OnClick", nil)
            end
        end

        if bidBtn then
            bidBtn:ClearAllPoints()
            bidBtn:SetPoint("RIGHT", row, "RIGHT", -190, 2)
            if allowBidButton and minBid and minBid > 0 and not isMine and not isHighBidder then
                bidBtn:Show()
                bidBtn:SetEnabled(true)
                bidBtn:SetScript("OnClick", function()
                    local nextBid = minBid
                    if bid and bid > 0 then
                        nextBid = bid + (minIncrement or 0)
                    end
                    if nextBid and nextBid > 0 then
                        StaticPopup_Show("EASYAUCTION_BID_CONFIRM", FormatGoldText(nextBid), nil, {
                            func = function()
                                PlaceAuctionBid("list", idx, nextBid)
                            end
                        })
                    end
                end)
            else
                bidBtn:Hide()
                bidBtn:SetEnabled(false)
                bidBtn:SetScript("OnClick", nil)
            end
        end
    end
end

local function EasyAuction_RegisterAuctionsButtonRightClick()
    for i = 1, NUM_AUCTIONS_TO_DISPLAY do
        local btn = _G["AuctionsButton" .. i]
        if btn and not btn.__EasyAuction_RightClickRegistered then
            btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            btn:HookScript("OnClick", function(self, button)
                if button == "RightButton" then
                    local offset = FauxScrollFrame_GetOffset(AuctionsScrollFrame)
                    local index = offset + i
                    local saleStatus = select(16, GetAuctionItemInfo("owner", index))
                    if saleStatus ~= 1 then
                        CancelAuction(index)
                    end
                end
            end)
            btn:HookScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine("右键取消该拍卖", 1, 0.6, 0.2)
                GameTooltip:Show()
            end)
            btn:HookScript("OnLeave", function(self)
                GameTooltip:Hide()
            end)
            btn.__EasyAuction_RightClickRegistered = true
        end
    end
end
local function EasyAuction_InitBrowseButtonHighlight()
    for i = 1, NUM_BROWSE_TO_DISPLAY do
        local btn = _G["BrowseButton" .. i]
        if btn and not btn.ownerTextur then
            local tex = btn:CreateTexture(nil, "BACKGROUND")
            tex:SetAllPoints()
            tex:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
            tex:SetVertexColor(0.5, 0.7, 1.0, 0.9)
            tex:Hide()
            btn.ownerTextur = tex
        end
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("AUCTION_HOUSE_SHOW")
f:SetScript("OnEvent", function(_, event)
    SetCVar("auctionSortByBuyoutPrice", 1)
    SetCVar("auctionSortByUnitPrice", 1)
    AuctionFrame_SetSort(sortTable or "list", "bid", false)
    C_Timer.After(0.1, EasyAuction_CreateBuyoutButton)
    C_Timer.After(0.2, EasyAuction_CreateSellPanelButton)
    C_Timer.After(0.2, EasyAuction_RegisterAuctionsButtonRightClick)
    C_Timer.After(0.5, function() EasyAuction_RunDailyCleanup(false) end)
    C_Timer.After(0.2, EasyAuction_InitBrowseButtonHighlight)
end)

hooksecurefunc("FauxScrollFrame_Update", function(frame)
    if IsScanningAll or IsScanningCategory then return end
    if frame == _G["BrowseScrollFrame"] then
        EasyAuction_EnsureFlashBuyButtons()
        EasyAuction_RefreshFlashBuyButtons()
        local myName = UnitName("player")
        for i = 1, NUM_BROWSE_TO_DISPLAY do
            local btn = _G["BrowseButton" .. i]
            if btn and btn.itemIndex and btn.ownerTextur then
                local index = btn.itemIndex
                index = (index % 50 == 0) and 50 or (index % 50)
                local owner = select(14, GetAuctionItemInfo("list", index))
                if owner and myName and (owner == myName or owner:find("^" .. myName .. "%-")) then
                    btn.ownerTextur:Show()
                else
                    btn.ownerTextur:Hide()
                end
            elseif btn and btn.ownerTextur then
                btn.ownerTextur:Hide()
            end
        end
    end
end)

local function EasyAuction_AddPriceInfo(tip, itemLink, itemCount)
    EasyAuction_OnTooltipItem(tip, itemLink, itemCount or 1)
end

local function RemoveSellPrice(tooltip)
    local db = _G.EasyAuctionDB or EasyAuctionDB
    if not db or not db.hideSellPrice then return end
    -- 隐藏金币控件
    for i = 1, 3 do
        local moneyFrame = _G[tooltip:GetName() .. "MoneyFrame" .. i]
        if moneyFrame then
            moneyFrame:Hide()
        end
    end
end

local function HookTooltipMethods()
    local methods = {
        "SetBagItem", "SetInventoryItem", "SetMerchantItem", "SetBuybackItem",
        "SetGuildBankItem", "SetLootItem", "SetLootRollItem", "SetQuestItem",
        "SetQuestLogItem", "SetSendMailItem", "SetInboxItem",
        "SetTradePlayerItem", "SetTradeTargetItem", "SetAuctionItem",
        "SetItemByID", "SetHyperlink",
    }
    for _, method in ipairs(methods) do
        if GameTooltip[method] then
            hooksecurefunc(GameTooltip, method, function(self, ...)
                local itemLink
                local itemCount = 1
                if method == "SetBagItem" then
                    local bag, slot = ...
                    itemLink = GetContainerItemLink(bag, slot)
                    local info = GetContainerItemInfo(bag, slot)
                    if type(info) == "table" then
                        itemCount = info.stackCount or 1
                    else
                        local _, count = GetContainerItemInfo(bag, slot)
                        itemCount = count or 1
                    end
                elseif method == "SetInventoryItem" then
                    local unit, slot = ...
                    itemLink = GetInventoryItemLink(unit, slot)
                    itemCount = GetInventoryItemCount(unit, slot) or 1
                elseif method == "SetMerchantItem" then
                    local index = ...
                    itemLink = GetMerchantItemLink(index)
                    local _, _, _, count = GetMerchantItemInfo(index)
                    itemCount = count
                elseif method == "SetBuybackItem" then
                    local slot = ...
                    itemLink = GetBuybackItemLink(slot)
                    local _, _, _, count = GetBuybackItemInfo(slot)
                    itemCount = count
                elseif method == "SetGuildBankItem" then
                    local tab, slot = ...
                    itemLink = GetGuildBankItemLink(tab, slot)
                    local _, count = GetGuildBankItemInfo(tab, slot)
                    itemCount = count
                elseif method == "SetLootItem" then
                    local slot = ...
                    itemLink = GetLootSlotLink(slot)
                    local _, _, count = GetLootSlotInfo(slot)
                    itemCount = count or 1
                elseif method == "SetLootRollItem" then
                    local slot = ...
                    itemLink = GetLootRollItemLink(slot)
                    local _, _, count = GetLootRollItemInfo(slot)
                    itemCount = count
                elseif method == "SetQuestItem" then
                    local type, index = ...
                    itemLink = GetQuestItemLink(type, index)
                    local _, _, count = GetQuestItemInfo(type, index)
                    itemCount = count
                elseif method == "SetQuestLogItem" then
                    local type, index = ...
                    itemLink = GetQuestLogItemLink(type, index)
                    if type == "choice" then
                        _, _, itemCount = GetQuestLogChoiceInfo(index)
                    else
                        _, _, itemCount = GetQuestLogRewardInfo(index)
                    end
                elseif method == "SetSendMailItem" then
                    local id = ...
                    itemLink = GetSendMailItemLink(id)
                    local _, _, _, count = GetSendMailItem(id)
                    itemCount = count
                elseif method == "SetInboxItem" then
                    local index, attachIndex = ...
                    if index and attachIndex then
                        itemLink = GetInboxItemLink(index, attachIndex)
                        local _, _, _, count = GetInboxItem(index, attachIndex)
                        itemCount = count
                    end
                elseif method == "SetTradePlayerItem" then
                    local id = ...
                    itemLink = GetTradePlayerItemLink(id)
                    local _, _, count = GetTradePlayerItemInfo(id)
                    itemCount = count
                elseif method == "SetTradeTargetItem" then
                    local id = ...
                    itemLink = GetTradeTargetItemLink(id)
                    local _, _, count = GetTradeTargetItemInfo(id)
                    itemCount = count
                elseif method == "SetAuctionItem" then
                    local viewType, index = ...
                    itemLink = GetAuctionItemLink(viewType, index)
                    local _, _, count = GetAuctionItemInfo(viewType, index)
                    itemCount = count
                elseif method == "SetItemByID" then
                    local itemID = ...
                    itemLink = select(2, GetItemInfo(itemID))
                elseif method == "SetHyperlink" then
                    itemLink = ...
                end
                if itemLink then
                    RemoveSellPrice(self)
                    EasyAuction_AddPriceInfo(self, itemLink, itemCount)
                end
            end)
        end
    end
end

HookTooltipMethods()


-- =========================================================================================
-- 拍卖行搜索框防污染 / 防限流模块（由 AHFix 移植精简）
-- 独立 do...end 作用域隔离，避免污染核心数据层；仅监听拍卖行相关事件，不依赖既有逻辑。
-- 原理：结合文本安全标记与相关全局的具名污染源，区分「玩家手输 / 暴雪原生 / 第三方污染」三态，
--       污染时锁死搜索通道并引导 Ctrl+C → Ctrl+V 洗白，已触发限流则提示 /reload。
-- =========================================================================================
;(function()
    local After = _G.C_Timer.After
    local IsCtrl = _G.IsControlKeyDown
    local IsShift = _G.IsShiftKeyDown
    local IsSecure = _G.issecurevalue
    local IsSecureVariable = _G.issecurevariable
    local HookSecure = _G.hooksecurefunc
    local Errors = _G.UIErrorsFrame
    local FORCE_TAINT = "*** ForceTaint_Strong ***"

    -- 状态：state 当前状态 / taint 污染源 / paste 洗白阶段 / hooked 是否已挂钩
    local S = { state = "WAITING", taint = "None", paste = "NONE", hooked = false }
    local statusText   -- 顶部状态提示 FontString
    local overlayEdit  -- 覆盖在搜索框上的拦截 EditBox
    local searchCover  -- 覆盖在搜索按钮上的拦截 Button
    local Hook
    local EnsureStatusText
    local UpdateUI

    local function NamedTaint(taint)
        if taint ~= nil and taint ~= "nil" and taint ~= FORCE_TAINT and taint ~= "EasyAuction" then
            return taint
        end
    end

    local function MailboxTaint(taint)
        if taint == "Postal" or taint == "InboxMailBag" then
            return taint
        end
    end

    -- Titan 原生 Shift 点击即使没有第三方插件也可能标记 ForceTaint_Strong；
    -- 只有相关全局同时带有具名邮箱插件污染时，才将其判为不安全。
    local function GetMailboxSearchTaint()
        local modifiedClick = _G.ContainerFrameItemButton_OnModifiedClick
        if modifiedClick then
            if type(IsSecureVariable) == "function" then
                local variableSecure, variableTaint = IsSecureVariable("ContainerFrameItemButton_OnModifiedClick")
                if not variableSecure then
                    local taint = MailboxTaint(variableTaint)
                    if taint then return taint end
                end
            end

            local valueSecure, valueTaint = IsSecure(modifiedClick)
            if not valueSecure then
                local taint = MailboxTaint(valueTaint)
                if taint then return taint end
            end
        end

        local searchBars = _G.ITEM_SEARCHBAR_LIST
        if type(searchBars) == "table" then
            for i = 1, #searchBars do
                local searchBarName = searchBars[i]
                if searchBarName == "InboxMailbagFrameItemSearchBox" then
                    local valueSecure, valueTaint = IsSecure(searchBarName)
                    if not valueSecure then
                        return MailboxTaint(valueTaint) or "InboxMailBag"
                    end
                end
            end
        end
    end

    local function IsEnabled()
        return not EasyAuctionDB or EasyAuctionDB.enableSearchBoxProtection ~= false
    end

    local function DisableUI()
        if statusText then statusText:GetParent():Hide() end
        if searchCover then searchCover:Hide() end
        if overlayEdit then overlayEdit:Hide(); overlayEdit:ClearFocus() end
        S.state, S.taint, S.paste = "WAITING", "None", "NONE"
    end

    _G.EasyAuction_UpdateSearchBoxProtection = function()
        if IsEnabled() then
            Hook()
            if _G.AuctionFrame and _G.AuctionFrame:IsShown() then
                EnsureStatusText()
                if statusText then statusText:GetParent():Show() end
            end
            UpdateUI()
        else
            DisableUI()
        end
    end

    -- 刷新右上角状态提示文字与拦截按钮可见性
    UpdateUI = function()
        if not IsEnabled() then
            DisableUI()
            return
        end
        if not statusText or not _G.AuctionFrame or not _G.AuctionFrame:IsShown() then return end
        local t
        if S.state == "PERMANENT_TAINT" then
            t = "|cFFFF0000锁定 /reload|r"
        elseif S.state == "WARNING" then
            t = "|cFFFF2020污染 Ctrl+C/V|r"
        elseif S.state == "SAFE_USER" then
            t = "|cFF00FF00安全|r"
        elseif S.state == "SAFE_BLIZZARD" then
            t = "|cFF00CCFF可信|r"
        else
            t = "|cFF888888待命|r"
        end
        statusText:SetText(t)
        if searchCover then
            if S.state == "WARNING" or S.state == "PERMANENT_TAINT" then searchCover:Show() else searchCover:Hide() end
        end
    end

    -- 污染状态下的统一拦截提示
    local function WarnBlocked()
        if not IsEnabled() then return end
        if S.state == "PERMANENT_TAINT" then
            Errors:AddMessage("搜索已彻底污染锁定！请立刻输入 /reload 重载界面！", 1, 0, 0)
        else
            Errors:AddMessage("拦截动作！当前处于污染状态，请按【Ctrl+C】再按【Ctrl+V】洗白！", 1, 0, 0)
        end
    end

    Hook = function()
        local name, searchBtn = _G.BrowseName, _G.BrowseSearchButton
        if not name or S.hooked then return end
        S.hooked = true

        -- 透明覆盖 EditBox：污染时抢占焦点物理拦截玩家操作
        overlayEdit = _G.CreateFrame("EditBox", nil, name:GetParent(), "InputBoxTemplate")
        overlayEdit:SetAllPoints(name)
        overlayEdit:SetFrameLevel(name:GetFrameLevel() + 10)
        overlayEdit:SetFontObject(name:GetFontObject())
        overlayEdit:SetAutoFocus(false)
        overlayEdit:SetTextInsets(name:GetTextInsets())
        overlayEdit:Hide()

        overlayEdit:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
            WarnBlocked()
            if S.state ~= "PERMANENT_TAINT" then
                After(0, function() if self:IsVisible() then self:SetFocus(); self:HighlightText() end end)
            end
        end)
        overlayEdit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        -- 玩家手动改动覆盖框 => 视为清理污染，清空原框并交回焦点
        overlayEdit:SetScript("OnTextChanged", function(self, byUser)
            if not IsEnabled() then
                DisableUI()
                return
            end
            if byUser then
                name:SetText("")
                self:ClearFocus()
                After(0, function() if name:IsVisible() then name:SetFocus() end end)
                Errors:AddMessage("检测到手动修改/删除，污染已清理！请继续输入。", 0, 1, 0)
            end
        end)
        -- 监测 Ctrl+C 进入「已复制」洗白阶段
        overlayEdit:SetScript("OnKeyDown", function(_, key)
            if not IsEnabled() then
                DisableUI()
                return
            end
            if key == "C" and IsCtrl() then
                After(0.05, function() if S.paste == "NEED_COPY" then S.paste = "COPIED" end end)
            end
        end)

        -- 原生搜索框文本变化：按输入来源和污染标记判定三态
        name:HookScript("OnTextChanged", function(self, byUser)
            if not IsEnabled() then
                DisableUI()
                return
            end
            if S.state == "PERMANENT_TAINT" then return end
            local txt = self:GetText()
            if not txt or txt == "" then
                S.state, S.taint, S.paste = "WAITING", "None", "NONE"
                overlayEdit:Hide()
            else
                local isReal, taintReal = IsSecure(txt)
                if byUser then
                    S.state, S.taint, S.paste = "SAFE_USER", "None", "NONE"
                    overlayEdit:Hide()
                else
                    local mailboxTaint = MailboxTaint(taintReal) or GetMailboxSearchTaint()
                    if mailboxTaint then
                        S.state, S.taint, S.paste = "WARNING", mailboxTaint, "NEED_COPY"
                        self:ClearFocus()
                        overlayEdit:SetText(txt)
                        overlayEdit:Show()
                        overlayEdit:SetFocus()
                        overlayEdit:HighlightText()
                    elseif isReal or IsShift() or taintReal == FORCE_TAINT or taintReal == "EasyAuction" then
                        S.state, S.taint, S.paste = "SAFE_BLIZZARD", "None", "NONE"
                        overlayEdit:Hide()
                    else
                        S.state, S.taint, S.paste = "WARNING", NamedTaint(taintReal) or "Unknown", "NEED_COPY"
                        self:ClearFocus()
                        overlayEdit:SetText(txt)
                        overlayEdit:Show()
                        overlayEdit:SetFocus()
                        overlayEdit:HighlightText()
                    end
                end
            end
            UpdateUI()
        end)

        -- 污染状态下回车兜底拦截
        name:HookScript("OnKeyDown", function(self, key)
            if not IsEnabled() then
                DisableUI()
                return
            end
            if (key == "ENTER" or key == "NUMPADENTER") and (S.state == "WARNING" or S.state == "PERMANENT_TAINT") then
                self:ClearFocus()
                self:SetPropagateKeyboardInput(false)
                if S.state == "PERMANENT_TAINT" then
                    Errors:AddMessage("搜索已彻底污染锁定！请立刻输入 /reload 重载界面！", 1, 0, 0)
                else
                    Errors:AddMessage("拦截兜底！当前处于准备粘贴状态，请完成【Ctrl+V】洗白！", 1, 0, 0)
                    After(0, function() if self:IsVisible() then self:SetFocus(); self:HighlightText() end end)
                end
            end
        end)

        -- 搜索按钮罩层：污染时点击只提示，并跟踪 Ctrl+C/V 洗白流程
        if searchBtn then
            searchCover = _G.CreateFrame("Button", nil, searchBtn)
            searchCover:SetAllPoints(searchBtn)
            searchCover:SetFrameLevel(searchBtn:GetFrameLevel() + 5)
            searchCover:Hide()
            searchCover:SetScript("OnClick", function()
                if not IsEnabled() then
                    DisableUI()
                    return
                end
                WarnBlocked()
                if S.state ~= "PERMANENT_TAINT" and overlayEdit:IsShown() then
                    overlayEdit:SetFocus(); overlayEdit:HighlightText()
                end
            end)
            searchCover:SetScript("OnUpdate", function()
                if not IsEnabled() then
                    DisableUI()
                    return
                end
                if S.state ~= "WARNING" then return end
                local ctrl = IsCtrl()
                if S.paste == "COPIED" then
                    if ctrl and overlayEdit:HasFocus() then
                        S.paste = "PASTING"
                        overlayEdit:Hide()
                        name:SetFocus(); name:HighlightText()
                    end
                elseif S.paste == "PASTING" then
                    if not ctrl then
                        S.paste = "COPIED"
                        overlayEdit:Show()
                        if name:HasFocus() then overlayEdit:SetFocus(); overlayEdit:HighlightText() end
                    end
                end
            end)
        end

        -- 在 WARNING 状态下真的发起搜索 => 升级为永久污染
        HookSecure("AuctionFrameBrowse_Search", function()
            if IsEnabled() and name and S.state == "WARNING" then
                S.state = "PERMANENT_TAINT"
                UpdateUI()
            end
        end)
    end

    EnsureStatusText = function()
        if statusText or not _G.AuctionFrame then return end
        local holder = _G.CreateFrame("Frame", nil, _G.UIParent)
        holder:SetSize(120, 18)
        holder:SetPoint("TOPRIGHT", _G.AuctionFrame, "TOPRIGHT", -118, -16)
        holder:SetFrameStrata("HIGH")
        statusText = holder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        statusText:SetPoint("CENTER")
        statusText:SetJustifyH("CENTER")
    end

    local frame = _G.CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:RegisterEvent("AUCTION_HOUSE_SHOW")
    frame:RegisterEvent("AUCTION_HOUSE_CLOSED")
    frame:SetScript("OnEvent", function(_, event, arg)
        if event == "ADDON_LOADED" and arg == "Blizzard_AuctionUI" then
            Hook()
        elseif event == "AUCTION_HOUSE_SHOW" then
            if not IsEnabled() then
                DisableUI()
                return
            end
            if not statusText then
                EnsureStatusText()
            end
            Hook()
            statusText:GetParent():Show()
            UpdateUI()
        elseif event == "AUCTION_HOUSE_CLOSED" then
            if statusText then statusText:GetParent():Hide() end
            if searchCover then searchCover:Hide() end
            if overlayEdit then overlayEdit:Hide() end
            S.paste = "NONE"
        end
    end)
end)()
