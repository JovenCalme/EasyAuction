local addonName, ns = ...

ns.EasyAuctionPro = ns.EasyAuctionPro or {}
local Pro = ns.EasyAuctionPro

local STATE_LIMITS = {
    diagnostics = 64,
    pending = 200,
}

local state = {
    ready = false,
    frame = nil,
    sessionID = nil,
    sessionEpoch = 0,
    sessionActive = false,
    openedAt = nil,
    closedAt = nil,
    browse = {},
    pending = {},
    seenLines = {},
    diagnostics = {},
}

local unpack = table.unpack or unpack
local auctionBidHookInstalled = false
local auctionBidTokenSerial = 0
local RecordPending

local patterns = {
    (ERR_AUCTION_WON_S or "你赢得了对%s的竞标"):gsub("%%s", "(.+)"),
    (ERR_AUCTION_WON_S or "你赢得了拍卖物品：%s。"):gsub("%%s", "(.+)"),
    "你赢得了对(.+)的竞标",
    "你赢得了拍卖物品：(.+)",
}

local function Copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}
    seen[value] = out
    for key, child in pairs(value) do
        out[Copy(key, seen)] = Copy(child, seen)
    end
    return out
end

local function Error(code, message, extra)
    local out = { ok = false, code = code, message = message }
    for key, value in pairs(extra or {}) do out[key] = value end
    return out
end

local function Now(value)
    local number = tonumber(value)
    if type(number) == "number" and number == number and number >= 0 and number < math.huge then
        return number
    end
end

local function NormalizeName(value)
    return tostring(value or "")
        :gsub("|c%x%x%x%x%x%x%x%x", "")
        :gsub("|r", "")
        :gsub("%s+", "")
        :lower()
end

local function PushDiagnostic(code, extra)
    local entry = { code = code }
    for key, value in pairs(extra or {}) do entry[key] = value end
    state.diagnostics[#state.diagnostics + 1] = entry
    if #state.diagnostics > STATE_LIMITS.diagnostics then
        table.remove(state.diagnostics, 1)
    end
    return entry
end

local function AddPending(entry)
    if #state.pending >= STATE_LIMITS.pending then
        table.remove(state.pending, 1)
        PushDiagnostic("PENDING_TRIMMED")
    end
    state.pending[#state.pending + 1] = entry
    return entry
end

local function RemovePending(index)
    table.remove(state.pending, index)
end

local function ActiveSessionState()
    local ok, session = pcall(Pro.GetShoppingSession)
    if ok and type(session) == "table" and session.ok then
        return session
    end
end

local function CollectRelevantItemIDs()
    local relevant = {}
    local listsResult = Pro.GetShoppingLists and Pro.GetShoppingLists()
    if type(listsResult) ~= "table" or not listsResult.ok then
        return relevant
    end
    for _, list in ipairs(listsResult.lists or {}) do
        for itemID in pairs(list.items or {}) do
            relevant[#relevant + 1] = tonumber(itemID)
        end
    end
    return relevant
end

local function CollectBagCounts(relevant)
    local counts = {}
    local snapshot = Pro.GetInventorySnapshot and Pro.GetInventorySnapshot("bags", Now(GetTime and GetTime() or 0), nil)
    if type(snapshot) == "table" and snapshot.ok and snapshot.known and type(snapshot.counts) == "table" then
        for _, itemID in ipairs(relevant or {}) do
            counts[itemID] = snapshot.counts[itemID] or 0
        end
    else
        for _, itemID in ipairs(relevant or {}) do
            counts[itemID] = 0
        end
    end
    return counts
end

local function ResetRuntimeState()
    state.sessionID = nil
    state.sessionEpoch = 0
    state.sessionActive = false
    state.openedAt = nil
    state.closedAt = nil
    state.browse = {}
    state.pending = {}
    state.seenLines = {}
    state.diagnostics = {}
end

local function EnsureReady()
    if not state.ready then
        return nil, Error("NOT_READY", "Shopping runtime is not initialized")
    end
    return true
end

local function RecordBrowseMinimum(itemID, unitPrice, observedAt)
    itemID = tonumber(itemID)
    unitPrice = tonumber(unitPrice)
    observedAt = Now(observedAt)
    if not itemID or not unitPrice or unitPrice <= 0 or not observedAt then
        return Error("INVALID_BROWSE", "Browse minimum is invalid")
    end
    local current = state.browse[itemID]
    if not current or unitPrice < current.unitPrice then
        state.browse[itemID] = { itemID = itemID, unitPrice = math.floor(unitPrice), observedAt = observedAt }
    end
    return { ok = true, entry = Copy(state.browse[itemID]) }
end

local function ItemIDFromLink(link)
    if type(link) ~= "string" then return nil end
    return tonumber(link:match("item:(%d+)"))
end

local function ReadAuctionRow(auctionType, index)
    if type(GetAuctionItemInfo) ~= "function" then
        return {}
    end
    local row = { GetAuctionItemInfo(auctionType, index) }
    local itemID = tonumber(row[17])
    if not itemID and type(GetAuctionItemLink) == "function" then
        itemID = ItemIDFromLink(GetAuctionItemLink(auctionType, index))
    end
    return {
        name = row[1],
        count = tonumber(row[3]),
        buyout = tonumber(row[10]),
        itemID = itemID,
    }
end

local function RecordPendingAuctionBid(auctionType, index, price)
    if not state.ready or not state.sessionActive then
        return
    end
    local submittedPrice = tonumber(price)
    local row = ReadAuctionRow(auctionType, index)
    if not row.itemID or not row.count or row.count <= 0 or type(row.name) ~= "string" or row.name == "" then
        PushDiagnostic("PLACE_BID_ROW_INVALID", { auctionType = tostring(auctionType), index = tonumber(index) or 0 })
        return
    end
    if not row.buyout or row.buyout <= 0 or not submittedPrice or submittedPrice < row.buyout then
        PushDiagnostic("PLACE_BID_IGNORED", { itemID = row.itemID, count = row.count })
        return
    end
    auctionBidTokenSerial = auctionBidTokenSerial + 1
    RecordPending({
        itemID = row.itemID,
        name = row.name,
        count = row.count,
        buyout = row.buyout,
        submittedPrice = submittedPrice,
        mode = "buyout",
        token = string.format(
            "place-bid:%s:%s:%s:%s:%s:%s:%s",
            tostring(state.sessionID or ""),
            tostring(auctionType or ""),
            tostring(index or ""),
            tostring(row.itemID),
            tostring(row.count),
            tostring(submittedPrice),
            tostring(auctionBidTokenSerial)
        ),
    })
end

local function InstallAuctionBidHook()
    if auctionBidHookInstalled or type(hooksecurefunc) ~= "function" then
        return
    end
    hooksecurefunc("PlaceAuctionBid", function(auctionType, index, price)
        RecordPendingAuctionBid(auctionType, index, price)
    end)
    auctionBidHookInstalled = true
end

local function ResetBrowseCache()
    state.browse = {}
end

local function MatchCandidates(observationName)
    local candidates = {}
    local normalized = NormalizeName(observationName)
    for index, entry in ipairs(state.pending) do
        if entry.mode == "buyout" and entry.sessionID == state.sessionID then
            local pendingName = NormalizeName(entry.name)
            if pendingName == normalized or pendingName:find(normalized, 1, true) or normalized:find(pendingName, 1, true) then
                candidates[#candidates + 1] = { index = index, entry = entry }
            end
        end
    end
    return candidates
end

local function ParseSystemMessage(msg)
    if type(msg) ~= "string" then return nil end
    for _, pattern in ipairs(patterns) do
        local wonName = msg:match(pattern)
        if wonName then return wonName end
    end
end

local function StartSession(openedAt)
    if state.sessionActive then
        Pro.EndShoppingSession("reopened")
    end
    state.sessionEpoch = state.sessionEpoch + 1
    openedAt = Now(openedAt) or (Now(GetTime and GetTime() or 0) or 0)
    local sessionID = string.format("AH:%s:%d", tostring(openedAt), state.sessionEpoch)
    local relevant = CollectRelevantItemIDs()
    local bagCounts = CollectBagCounts(relevant)
    local result = Pro.StartShoppingSession(sessionID, relevant, bagCounts, openedAt)
    if not result.ok then
        PushDiagnostic("SESSION_START_FAILED", { code = result.code, message = result.message })
        return result
    end
    state.sessionID = sessionID
    state.sessionActive = true
    state.openedAt = openedAt
    state.closedAt = nil
    state.pending = {}
    state.seenLines = {}
    ResetBrowseCache()
    return { ok = true, sessionID = sessionID }
end

local function CloseSession(reason)
    local result = Pro.EndShoppingSession(reason or "closed")
    state.sessionActive = false
    state.closedAt = Now(GetTime and GetTime() or 0)
    state.pending = {}
    ResetBrowseCache()
    return result
end

local function RefreshBrowseMinimum()
    if not state.sessionActive then
        return { ok = true, skipped = true }
    end
    local num = type(GetNumAuctionItems) == "function" and GetNumAuctionItems("list") or 0
    if type(num) ~= "number" then num = 0 end
    for index = 1, num do
        local row = { GetAuctionItemInfo("list", index) }
        local count = tonumber(row[3] or row.count)
        local buyout = tonumber(row[10] or row.buyout)
        local itemID = tonumber(row[17] or row.itemID)
        if itemID and count and count > 0 and buyout and buyout > 0 then
            local unit = math.floor(buyout / count + 0.5)
            local existing = state.browse[itemID]
            if not existing or unit < existing.unitPrice then
                state.browse[itemID] = {
                    itemID = itemID,
                    unitPrice = unit,
                    observedAt = Now(GetTime and GetTime() or 0) or 0,
                }
            end
        end
    end
    return { ok = true, count = num }
end

local function ConfirmBuyout(entry, observationName)
    local result = Pro.ApplyConfirmedShoppingPurchase(entry.token, entry.itemID, entry.count)
    if not result.ok then
        PushDiagnostic("CONFIRM_FAILED", { code = result.code, itemID = entry.itemID, name = observationName })
        return result
    end
    PushDiagnostic("CONFIRMED_BUYOUT", { itemID = entry.itemID, count = entry.count, token = entry.token })
    return { ok = true, confirmed = true, delta = result.delta, token = entry.token }
end

local function ObserveSystemMessage(msg, lineID)
    local observationName = ParseSystemMessage(msg)
    if not observationName then
        return { ok = true, ignored = true }
    end
    if lineID ~= nil then
        local dedupeKey = tostring(lineID)
        if state.seenLines[dedupeKey] then
            return { ok = true, duplicate = true }
        end
        state.seenLines[dedupeKey] = true
    end
    if not state.sessionActive then
        local code = state.closedAt and "LATE_AFTER_CLOSE" or "NO_ACTIVE_SESSION"
        PushDiagnostic(code, { name = observationName })
        return { ok = true, ignored = true, code = code }
    end
    local candidates = MatchCandidates(observationName)
    if #candidates == 0 then
        PushDiagnostic("NO_MATCH", { name = observationName })
        return { ok = true, ignored = true }
    end
    if #candidates > 1 then
        PushDiagnostic("AMBIGUOUS", { name = observationName, count = #candidates })
        return { ok = true, ambiguous = true }
    end
    local candidate = candidates[1]
    RemovePending(candidate.index)
    return ConfirmBuyout(candidate.entry, observationName)
end

function RecordPending(info)
    info = type(info) == "table" and info or {}
    local itemID = tonumber(info.itemID)
    local count = tonumber(info.count)
    local name = type(info.name) == "string" and info.name or nil
    local token = type(info.token) == "string" and info.token or nil
    local buyout = tonumber(info.buyout)
    if not itemID or not count or count <= 0 or not name then
        return Error("INVALID_PENDING", "Pending submission is invalid")
    end
    local mode = info.mode
    if mode ~= "buyout" and mode ~= "bid" then
        mode = (buyout and buyout > 0 and tonumber(info.submittedPrice or buyout) >= buyout) and "buyout" or "bid"
    end
    token = token or string.format("%s:%d", state.sessionID or "pending", #state.pending + 1)
    local entry = {
        token = token,
        itemID = itemID,
        name = name,
        count = math.floor(count),
        buyout = buyout or 0,
        mode = mode,
        sessionID = state.sessionID,
        submittedAt = Now(info.submittedAt or (GetTime and GetTime() or 0)) or 0,
    }
    AddPending(entry)
    PushDiagnostic("PENDING_RECORDED", { token = token, itemID = itemID, mode = mode })
    return { ok = true, pending = Copy(entry) }
end

function Pro.GetShoppingRuntimeStatus()
    return {
        ok = true,
        ready = state.ready,
        sessionID = state.sessionID,
        sessionActive = state.sessionActive,
        pendingCount = #state.pending,
        browseCount = (function()
            local count = 0
            for _ in pairs(state.browse) do count = count + 1 end
            return count
        end)(),
        diagnostics = Copy(state.diagnostics),
    }
end

function Pro.GetShoppingRuntimeBrowseMinimum(itemID)
    itemID = tonumber(itemID)
    if not itemID then return Error("INVALID_ITEM", "Item ID is invalid") end
    local entry = state.browse[itemID]
    if not entry then
        return { ok = true, itemID = itemID, state = "unavailable" }
    end
    return { ok = true, itemID = itemID, state = "fresh", unitPrice = entry.unitPrice, observedAt = entry.observedAt }
end

function Pro.ShoppingRuntimeRecordBrowseMinimum(itemID, unitPrice, observedAt)
    local ready, failure = EnsureReady()
    if not ready then return failure end
    return RecordBrowseMinimum(itemID, unitPrice, observedAt)
end

function Pro.ShoppingRuntimeRecordPending(info)
    local ready, failure = EnsureReady()
    if not ready then return failure end
    return RecordPending(info)
end

function Pro.ShoppingRuntimeObserveSystemMessage(msg, lineID)
    local ready, failure = EnsureReady()
    if not ready then return failure end
    return ObserveSystemMessage(msg, lineID)
end

function Pro.ShoppingRuntimeHandleEvent(event, ...)
    local ready, failure = EnsureReady()
    if not ready then return failure end
    if event == "AUCTION_HOUSE_SHOW" then
        return StartSession(...)
    elseif event == "AUCTION_HOUSE_CLOSED" then
        return CloseSession("closed")
    elseif event == "AUCTION_ITEM_LIST_UPDATE" then
        if _G.IsScanningAll or _G.IsScanningCategory
            or (ns.EA_IsFullScanSnapshotActive and ns.EA_IsFullScanSnapshotActive()) then
            return { ok = true, skipped = true, reason = "full_scan_snapshot" }
        end
        return RefreshBrowseMinimum()
    elseif event == "CHAT_MSG_SYSTEM" then
        return ObserveSystemMessage(...)
    end
    return { ok = true, ignored = true }
end

function Pro.InitializeShoppingRuntime(options)
    options = type(options) == "table" and options or {}
    if state.ready and not options.force then
        InstallAuctionBidHook()
        return { ok = true, cached = true }
    end
    ResetRuntimeState()
    if type(_G.CreateFrame) == "function" then
        local frame = _G.CreateFrame("Frame")
        state.frame = frame
        if frame and frame.RegisterEvent and frame.SetScript then
            frame:RegisterEvent("AUCTION_HOUSE_SHOW")
            frame:RegisterEvent("AUCTION_HOUSE_CLOSED")
            frame:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
            frame:RegisterEvent("CHAT_MSG_SYSTEM")
            frame:RegisterEvent("BAG_UPDATE")
            frame:RegisterEvent("BAG_UPDATE_DELAYED")
            frame:RegisterEvent("BANKFRAME_OPENED")
            frame:RegisterEvent("BANKFRAME_CLOSED")
            frame:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
            frame:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED")
            frame:SetScript("OnEvent", function(_, event, ...)
                Pro.ShoppingRuntimeHandleEvent(event, ...)
            end)
        end
    end
    state.ready = true
    InstallAuctionBidHook()
    if type(Pro.SetReadiness) == "function" then
        Pro.SetReadiness("runtime", true, { ready = true })
    end
    return { ok = true, ready = true }
end

Pro.InitializeShoppingRuntime()
