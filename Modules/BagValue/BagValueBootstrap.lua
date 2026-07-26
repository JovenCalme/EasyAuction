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

function Bootstrap:_tooltip()
    if self.tooltipPresenter then return self.tooltipPresenter end
    self.tooltipPresenter = self.deps.tooltipPresenter
    if not self.tooltipPresenter and BagValue.Tooltip and type(BagValue.Tooltip.New) == "function" then
        self.tooltipPresenter = BagValue.Tooltip.New({ controller = self:_controller() })
    end
    return self.tooltipPresenter
end

function Bootstrap:ShowTooltip(owner)
    local presenter = self:_tooltip()
    if presenter and type(presenter.Show) == "function" then return presenter:Show(owner) end
    return false
end

function Bootstrap:HideTooltip()
    local presenter = self:_tooltip()
    if presenter and type(presenter.Hide) == "function" then presenter:Hide() end
end

function Bootstrap:_bindValuationButton(button)
    if not button then return false end
    button:SetScript("OnClick", function() self:Toggle() end)
    button:SetScript("OnEnter", function(target) self:ShowTooltip(target) end)
    button:SetScript("OnLeave", function() self:HideTooltip() end)
    return true
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
    self:_bindValuationButton(button)
    dbFrame.EasyAuctionBagValueButton = button
    self.priceDBButton = button
    dbFrame:HookScript("OnShow", function() self:_layoutPriceDBButton() end)
    return self:_layoutPriceDBButton()
end

function Bootstrap:_updateNativeBagButton(frame, bagID)
    if not frame then return false end
    local button = frame.EasyAuctionBagValueButton
    if not button and bagID ~= 0 then return false end
    if not button then
        local create = self.deps.createFrame or (_G and _G.CreateFrame)
        if type(create) ~= "function" then return false end
        button = create("Button", nil, frame)
        button:SetSize(20, 20)
        button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -34, -5)
        if button.SetFrameLevel and frame.GetFrameLevel then
            button:SetFrameLevel(frame:GetFrameLevel() + 10)
        end
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetAllPoints()
        button.icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
        if button.icon.SetTexCoord then button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
        button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        self:_bindValuationButton(button)
        frame.EasyAuctionBagValueButton = button
    end
    button:SetShown(bagID == 0)
    return bagID == 0
end

function Bootstrap:_hookNativeBagButton()
    if self.nativeBagHooked then return true end
    local hook = self.deps.hooksecurefunc or (_G and _G.hooksecurefunc)
    if type(hook) == "function" and type(_G.ContainerFrame_GenerateFrame) == "function" then
        hook("ContainerFrame_GenerateFrame", function(frame, _, bagID)
            self:_updateNativeBagButton(frame, bagID)
        end)
        self.nativeBagHooked = true
    end
    local frameCount = tonumber(_G.NUM_CONTAINER_FRAMES) or 13
    for index = 1, frameCount do
        local frame = _G["ContainerFrame" .. index]
        if frame and type(frame.GetID) == "function" then
            self:_updateNativeBagButton(frame, frame:GetID())
        end
    end
    return self.nativeBagHooked == true
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
    _G.EasyAuction_ShowBagValueTooltip = function(owner) return self:ShowTooltip(owner) end
    _G.EasyAuction_HideBagValueTooltip = function() return self:HideTooltip() end
    _G.SLASH_EASYAUCTIONBAGVALUE1 = "/eabv"
    _G.SlashCmdList = _G.SlashCmdList or {}
    _G.SlashCmdList.EASYAUCTIONBAGVALUE = function() self:Toggle() end
    self:_createPriceDBButton()
    self:_hookNativeBagButton()
    return true
end

BagValue.BagValueBootstrap = Bootstrap
BagValue.Bootstrap = BagValue.Bootstrap or Bootstrap.New({ addonName = addonName })
BagValue.Bootstrap:Initialize()
