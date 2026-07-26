local _, ns = ...

ns = type(ns) == "table" and ns or {}
ns.BagValue = type(ns.BagValue) == "table" and ns.BagValue or {}

local BagValue = ns.BagValue
local Controller = {}
Controller.__index = Controller

local function instantiate(candidate, deps)
    if type(candidate) ~= "table" then return candidate end
    if getmetatable(candidate) then return candidate end
    if type(candidate.New) == "function" then return candidate.New(deps or {}) end
    return candidate
end

function Controller.New(deps)
    return setmetatable({
        deps = deps or {},
        dirty = true,
        refreshing = false,
        refreshGeneration = 0,
        snapshot = nil,
        result = nil,
    }, Controller)
end

function Controller:_after(delay, callback)
    if type(self.deps.after) == "function" then return self.deps.after(delay, callback) end
    if _G and _G.C_Timer and type(_G.C_Timer.After) == "function" then
        return _G.C_Timer.After(delay, callback)
    end
    return callback()
end

function Controller:_ensureDataServices()
    if not self.scanner then
        self.scanner = instantiate(self.deps.scanner or BagValue.Scanner
            or BagValue.BagInventoryScanner, self.deps.scannerDeps)
    end
    if not self.estimator then
        local estimatorDeps = self.deps.estimatorDeps or {}
        if not estimatorDeps.priceProvider and BagValue.PriceProvider
            and type(BagValue.PriceProvider.New) == "function" then
            estimatorDeps.priceProvider = BagValue.PriceProvider.New(self.deps.priceProviderDeps)
        end
        self.estimator = instantiate(self.deps.estimator or BagValue.Estimator
            or BagValue.BagValueEstimator, estimatorDeps)
    end
    if not self.scanner or type(self.scanner.Scan) ~= "function" then
        return nil, "背包扫描服务尚未加载。"
    end
    if not self.estimator or type(self.estimator.Estimate) ~= "function" then
        return nil, "估值服务尚未加载。"
    end
    return true
end

function Controller:_ensureServices()
    local ready, err = self:_ensureDataServices()
    if not ready then return nil, err end
    if not self.view then
        self.view = self.deps.view
        if not self.view and BagValue.View and type(BagValue.View.New) == "function" then
            self.view = BagValue.View.New({
                createFrame = self.deps.createFrame,
                onRefresh = function() self:RefreshNow("MANUAL") end,
                onHide = function() self:OnViewHidden() end,
            })
        end
    end
    if not self.view then return nil, "背包估值窗口尚未加载。" end
    if type(self.view.Create) == "function" and not (self.view.frame or self.view.root) then
        self.view:Create(self.deps.parent or (_G and _G.UIParent))
    end
    return true
end

function Controller:_calculate()
    local scanOK, snapshot, scanError = pcall(self.scanner.Scan, self.scanner)
    if not scanOK then return nil, snapshot end
    if not snapshot then return nil, scanError or "读取背包失败，请稍后重试。" end
    if snapshot.error then return nil, snapshot.error end

    local estimateOK, result, estimateError = pcall(self.estimator.Estimate,
        self.estimator, snapshot, self.deps.options or {})
    if not estimateOK then return nil, result end
    if not result then return nil, estimateError or "计算背包估值失败。" end

    if not result.summary then
        result = { summary = result, rows = result.rows or result.items or snapshot.items or {} }
    elseif not result.rows then
        result.rows = result.summary.items or snapshot.items or {}
    end
    result.summary.pendingCount = tonumber(result.summary.pendingCount)
        or tonumber(snapshot.pendingCount) or 0
    self.snapshot, self.result = snapshot, result
    self.dirty = false
    return result
end

function Controller:GetTooltipResult()
    if not self.dirty and self.result then return self.result end
    if self.refreshing then return self.result end
    local ready, err = self:_ensureDataServices()
    if not ready then return nil, err end
    self.refreshing = true
    local result, calculateError = self:_calculate()
    self.refreshing = false
    if not result then self.dirty = true end
    return result, calculateError
end

function Controller:IsShown()
    if self.view and type(self.view.IsShown) == "function" then return self.view:IsShown() end
    local frame = self.view and (self.view.frame or self.view.root)
    return frame and frame.IsShown and frame:IsShown() == true or false
end

function Controller:Show()
    local ready, err = self:_ensureServices()
    if not ready then
        if _G and type(_G.print) == "function" then
            _G.print("|cffff4040[EasyAuction]|r " .. tostring(err))
        end
        return nil, err
    end
    if type(self.view.Show) == "function" then self.view:Show() end
    if self.dirty or not self.result then self:RefreshNow("SHOW") end
    return true
end

function Controller:Hide()
    self.refreshGeneration = self.refreshGeneration + 1
    if self.view and type(self.view.Hide) == "function" then self.view:Hide() end
    return true
end

function Controller:Toggle()
    if self:IsShown() then return self:Hide() end
    return self:Show()
end

function Controller:OnViewHidden()
    self.refreshGeneration = self.refreshGeneration + 1
end

function Controller:MarkDirty(reason)
    self.dirty = true
    self.dirtyReason = reason
    if self:IsShown() then self:RequestRefresh(reason) end
    return true
end

function Controller:RequestRefresh(reason, delay)
    if not self:IsShown() then
        self.dirty = true
        self.dirtyReason = reason
        return false
    end
    self.dirty = true
    self.dirtyReason = reason
    self.refreshGeneration = self.refreshGeneration + 1
    local generation = self.refreshGeneration
    self:_after(delay == nil and 0.2 or math.max(0, tonumber(delay) or 0), function()
        if generation ~= self.refreshGeneration or not self:IsShown() then return end
        self:RefreshNow(reason)
    end)
    return true
end

function Controller:RefreshNow(reason)
    if not self:IsShown() or self.refreshing then
        self.dirty = true
        return false
    end
    local ready, serviceError = self:_ensureServices()
    if not ready then return nil, serviceError end
    self.refreshing = true
    self.dirty = false
    if type(self.view.SetBusy) == "function" then self.view:SetBusy(true) end
    local result, calculateError = self:_calculate()
    self.refreshing = false
    if type(self.view.SetBusy) == "function" then self.view:SetBusy(false) end
    if not result then
        self.dirty = true
        if type(self.view.ShowError) == "function" then self.view:ShowError(calculateError) end
        return nil, calculateError
    end
    if type(self.view.ShowError) == "function" then self.view:ShowError(nil) end
    if type(self.view.Render) == "function" then self.view:Render(result) end
    self.lastRefreshReason = reason
    return result
end

function Controller:OnEvent(event)
    if event == "BAG_UPDATE_DELAYED" then
        return self:MarkDirty(event)
    end
    if event == "GET_ITEM_INFO_RECEIVED" then
        local pending = self.snapshot and tonumber(self.snapshot.pendingCount) or 0
        local resultPending = self.result and self.result.summary
            and tonumber(self.result.summary.pendingCount) or 0
        if pending > 0 or resultPending > 0 then return self:MarkDirty(event) end
    end
    return false
end

BagValue.BagValueController = Controller
BagValue.Controller = Controller
