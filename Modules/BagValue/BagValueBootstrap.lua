local addonName, ns = ...

ns = type(ns) == "table" and ns or {}
ns.BagValue = type(ns.BagValue) == "table" and ns.BagValue or {}

local BagValue = ns.BagValue
local Bootstrap = {}
Bootstrap.__index = Bootstrap

function Bootstrap.New(deps)
    return setmetatable({ deps = deps or {}, initialized = false }, Bootstrap)
end

function Bootstrap:_controller()
    if self.controller then return self.controller end
    self.controller = self.deps.controller
    if not self.controller and BagValue.Controller and type(BagValue.Controller.New) == "function" then
        local controllerDeps = self.deps.controllerDeps or {}
        local estimatorDeps = controllerDeps.estimatorDeps or {}
        if not estimatorDeps.priceProvider and BagValue.PriceProvider
            and type(BagValue.PriceProvider.New) == "function" then
            estimatorDeps.priceProvider = BagValue.PriceProvider.New(self.deps.priceProviderDeps)
        end
        controllerDeps.estimatorDeps = estimatorDeps
        self.controller = BagValue.Controller.New(controllerDeps)
    end
    return self.controller
end

function Bootstrap:Toggle()
    local controller = self:_controller()
    if not controller or type(controller.Toggle) ~= "function" then
        if _G and type(_G.print) == "function" then
            _G.print("|cffff4040[EasyAuction]|r 背包估值模块尚未加载。")
        end
        return nil
    end
    return controller:Toggle()
end

function Bootstrap:_layoutPriceDBButton()
    local dbFrame = _G and _G.EasyAuctionDBFrame
    local button = self.priceDBButton
    if not dbFrame or not button then return false end
    local anchor = dbFrame.EasyAuctionProStrategyButton
        or dbFrame.EA_ExportBtn or dbFrame.EA_CategoryManageBtn
    button:ClearAllPoints()
    if anchor then
        button:SetPoint("RIGHT", anchor, "LEFT", -6, 0)
    else
        button:SetPoint("TOPRIGHT", dbFrame, "TOPRIGHT", -386, -14)
    end
    if type(_G.EasyAuction_LayoutDBFrameControls) == "function" then
        _G.EasyAuction_LayoutDBFrameControls()
    end
    return true
end

function Bootstrap:_createPriceDBButton()
    local dbFrame = _G and _G.EasyAuctionDBFrame
    local create = self.deps.createFrame or (_G and _G.CreateFrame)
    if not dbFrame or type(create) ~= "function" then return false end
    if dbFrame.EasyAuctionBagValueButton then
        self.priceDBButton = dbFrame.EasyAuctionBagValueButton
        return self:_layoutPriceDBButton()
    end
    local button = create("Button", nil, dbFrame, "UIPanelButtonTemplate")
    button:SetSize(82, 22)
    button:SetText("背包估值")
    local style = _G.EasyAuctionStyle
    if style and type(style.SkinButton) == "function" then style:SkinButton(button) end
    button:SetScript("OnClick", function() self:Toggle() end)
    button:SetScript("OnEnter", function(target)
        if not _G.GameTooltip then return end
        _G.GameTooltip:SetOwner(target, "ANCHOR_RIGHT")
        _G.GameTooltip:SetText("背包估值", 1, 0.82, 0)
        _G.GameTooltip:AddLine("按 EasyAuction 价格库估算当前背包物品价值。", 1, 1, 1, true)
        _G.GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        if _G.GameTooltip then _G.GameTooltip:Hide() end
    end)
    dbFrame.EasyAuctionBagValueButton = button
    self.priceDBButton = button
    dbFrame:HookScript("OnShow", function() self:_layoutPriceDBButton() end)
    return self:_layoutPriceDBButton()
end

function Bootstrap:Initialize()
    if self.initialized then return true end
    self.initialized = true
    local create = self.deps.createFrame or (_G and _G.CreateFrame)
    if type(create) == "function" then
        self.eventFrame = create("Frame")
        self.eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
        self.eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
        self.eventFrame:SetScript("OnEvent", function(_, event, ...)
            local controller = self:_controller()
            if controller and type(controller.OnEvent) == "function" then
                controller:OnEvent(event, ...)
            end
        end)
    end

    _G.EasyAuction_ToggleBagValueFrame = function() return self:Toggle() end
    _G.SLASH_EASYAUCTIONBAGVALUE1 = "/eabv"
    _G.SlashCmdList = _G.SlashCmdList or {}
    _G.SlashCmdList.EASYAUCTIONBAGVALUE = function() self:Toggle() end
    self:_createPriceDBButton()
    return true
end

BagValue.BagValueBootstrap = Bootstrap
BagValue.Bootstrap = BagValue.Bootstrap or Bootstrap.New({ addonName = addonName })
BagValue.Bootstrap:Initialize()
