local _, ns = ...
ns = type(ns) == "table" and ns or {}
ns.Mail = type(ns.Mail) == "table" and ns.Mail or {}

local Mail = ns.Mail
local Presenter = {}

local COLUMN_COUNT = 6
local ROW_COUNT = 7
local CELL_COUNT = COLUMN_COUNT * ROW_COUNT

local function clamp(value, minimum, maximum)
    value = math.floor(tonumber(value) or 0)
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function makeVisibleSet(value)
    if value == nil then return nil end
    local set = {}
    if #value > 0 then
        for index = 1, #value do set[value[index]] = true end
    else
        for key, enabled in pairs(value) do
            if enabled then set[key] = true end
        end
    end
    return set
end

local function expiryState(daysLeft)
    if type(daysLeft) ~= "number" then return nil end
    if daysLeft < 1 then return "critical" end
    if daysLeft < 7 then return "warning" end
    return nil
end

local function entryModel(entry, visibleSet, options)
    local searchMatch = visibleSet == nil or visibleSet[entry.id] == true
    local showQuality = options.qualityColors == true
        and type(entry.quality) == "number" and entry.quality ~= 1
    return {
        entry = entry,
        entryId = entry.id,
        kind = entry.kind,
        itemKey = entry.itemKey,
        displayName = entry.displayName,
        icon = entry.icon,
        totalCount = tonumber(entry.totalCount) or 0,
        totalMoney = tonumber(entry.totalMoney) or 0,
        minDaysLeft = entry.minDaysLeft,
        quality = entry.quality,
        sources = entry.sources,
        expiryState = expiryState(entry.minDaysLeft),
        showQuality = showQuality,
        searchMatch = searchMatch,
        enabled = options.enabled ~= false and entry.enabled ~= false,
        operationState = entry.operationState,
    }
end

local function emptyModel(cellIndex)
    return {
        cellIndex = cellIndex,
        entry = nil,
        entryId = nil,
        kind = nil,
        icon = nil,
        totalCount = 0,
        totalMoney = 0,
        expiryState = nil,
        showQuality = false,
        searchMatch = true,
        enabled = false,
    }
end

function Presenter.Project(entries, options)
    entries = entries or {}
    options = options or {}
    local projectableEntries = entries
    for index = 1, #entries do
        local entry = entries[index]
        if entry.kind == "cod" or entry.isCOD == true or (tonumber(entry.cod) or 0) > 0 then
            projectableEntries = {}
            for candidateIndex = 1, #entries do
                local candidate = entries[candidateIndex]
                if candidate.kind ~= "cod" and candidate.isCOD ~= true
                    and (tonumber(candidate.cod) or 0) <= 0 then
                    projectableEntries[#projectableEntries + 1] = candidate
                end
            end
            break
        end
    end
    local totalRows = math.ceil(#projectableEntries / COLUMN_COUNT)
    local maximumOffset = math.max(0, totalRows - ROW_COUNT)
    local rowOffset = clamp(options.rowOffset, 0, maximumOffset)
    local firstEntry = rowOffset * COLUMN_COUNT + 1
    local visibleSet = makeVisibleSet(options.visibleEntryIds)
    local cells = {}

    for cellIndex = 1, CELL_COUNT do
        local entry = projectableEntries[firstEntry + cellIndex - 1]
        if entry then
            cells[cellIndex] = entryModel(entry, visibleSet, options)
            cells[cellIndex].cellIndex = cellIndex
        else
            cells[cellIndex] = emptyModel(cellIndex)
        end
    end

    return {
        cells = cells,
        columnCount = COLUMN_COUNT,
        rowCount = ROW_COUNT,
        cellCount = CELL_COUNT,
        entryCount = #projectableEntries,
        totalRows = totalRows,
        rowOffset = rowOffset,
        maxRowOffset = maximumOffset,
        canScroll = maximumOffset > 0,
        firstEntryIndex = firstEntry,
    }
end

function Presenter.New()
    return setmetatable({}, { __index = Presenter })
end

Presenter.COLUMN_COUNT = COLUMN_COUNT
Presenter.ROW_COUNT = ROW_COUNT
Presenter.CELL_COUNT = CELL_COUNT

Mail.InboxPresenter = Presenter

return Presenter
