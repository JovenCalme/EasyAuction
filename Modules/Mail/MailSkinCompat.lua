local _, ns = ...

ns = ns or {}
ns.Mail = ns.Mail or {}
local Mail = ns.Mail

local SkinCompat = {}
SkinCompat.__index = SkinCompat

local function copyList(source)
    local result = {}
    for index = 1, #(source or {}) do result[index] = source[index] end
    return result
end

function SkinCompat.New(api)
    return setmetatable({
        api = api or {},
        targets = {},
        popoverWidgets = {},
    }, SkinCompat)
end

function SkinCompat:_ndui()
    local value = self.api.NDui
    if value == nil then value = _G.NDui end
    if type(value) ~= "table" or type(value[1]) ~= "table" then return nil end
    local config = value[2]
    if type(config) == "table" and type(config.db) == "table"
        and type(config.db.Skins) == "table"
        and config.db.Skins.BlizzardSkins == false then
        return nil
    end
    return value[1]
end

function SkinCompat:IsEnabled()
    return self:_ndui() ~= nil
end

function SkinCompat:_remember(kind, object)
    if type(object) ~= "table" then return end
    self.targets[object] = kind
end

function SkinCompat:_call(method, object, ...)
    local bridge = self:_ndui()
    if not bridge or type(object) ~= "table" then return false end
    local callback = bridge[method]
    if type(callback) ~= "function" then return false end
    object.__EasyAuctionNDuiSkin = object.__EasyAuctionNDuiSkin or {}
    if object.__EasyAuctionNDuiSkin[method] then return true end
    -- NDui 对外调用约定是 B.Reskin(widget)，不要把 B 自身作为第一个参数。
    local ok = pcall(callback, object, ...)
    if ok then object.__EasyAuctionNDuiSkin[method] = true end
    return ok
end

local function invoke(object, method, ...)
    if object and type(object[method]) == "function" then
        return pcall(object[method], object, ...)
    end
    return false
end

function SkinCompat:_useHighlightText(widget)
    if not widget or type(widget.SetTextColor) ~= "function" then return false end
    local color = self.api.HIGHLIGHT_FONT_COLOR or _G.HIGHLIGHT_FONT_COLOR
    local red, green, blue = 1, 1, 1
    if type(color) == "table" and type(color.GetRGB) == "function" then
        local ok, r, g, b = pcall(color.GetRGB, color)
        if ok then red, green, blue = r or red, g or green, b or blue end
    elseif type(color) == "table" then
        red, green, blue = color.r or red, color.g or green, color.b or blue
    end
    return pcall(widget.SetTextColor, widget, red, green, blue)
end

function SkinCompat:SkinTab(button)
    self:_remember("tab", button)
    return self:_call("ReskinTab", button)
end

function SkinCompat:SkinInbox(view)
    self:_remember("inbox", view)
    if type(view) ~= "table" or not self:IsEnabled() then return false end
    invoke(view.paperBackground, "Hide")
    self:_call("CreateBDFrame", view.content, 0.25)
    self:_call("ReskinCheck", view.groupButton)
    self:_call("ReskinCheck", view.advancedButton)
    self:_call("ReskinInput", view.searchBox)
    self:_call("ReskinScroll", view.scrollBar)
    for index = 1, #(view.categoryButtons or {}) do
        self:_call("Reskin", view.categoryButtons[index])
    end
    for index = 1, #(view.buttons or {}) do
        local button = view.buttons[index]
        invoke(button and button.__eaSlotBackground, "Hide")
        invoke(button, "SetNormalTexture", 0)
        invoke(button, "SetPushedTexture", 0)
        local highlight = button and type(button.GetHighlightTexture) == "function"
            and button:GetHighlightTexture() or nil
        invoke(highlight, "SetColorTexture", 1, 1, 1, 0.25)
        self:_call("ReskinIcon", button and (button.icon or button.Icon))
    end
    return self:IsEnabled()
end

function SkinCompat:SkinCompose(runtime)
    self:_remember("compose", runtime)
    if type(runtime) ~= "table" then return false end
    self:_call("ReskinArrow", runtime.directoryButton, "down")
    for index = 1, #(runtime.categoryRows or {}) do
        self:_call("Reskin", runtime.categoryRows[index])
    end
    return self:IsEnabled()
end

function SkinCompat:SkinRecipientManager(manager)
    self:_remember("recipientManager", manager)
    if type(manager) ~= "table" or not self:IsEnabled() then return false end
    invoke(manager, "SetBackdrop", nil)
    self:_call("StripTextures", manager)
    self:_call("CreateBDFrame", manager, 0.62)
    self:_call("ReskinClose", manager.closeButton, manager)
    for _, tab in pairs(manager.tabs or {}) do self:_call("ReskinTab", tab) end
    for _, list in ipairs({
        manager.contactListFrame, manager.blacklistFrame,
        manager.groupListFrame, manager.memberListFrame,
    }) do
        self:_call("StripTextures", list)
        self:_call("CreateBDFrame", list, 0.62)
    end
    for _, rows in ipairs({
        manager.contactRows, manager.blacklistRows,
        manager.groupRows, manager.memberRows,
    }) do
        for index = 1, #(rows or {}) do
            local row = rows[index]
            self:_call("ReskinClose", row and row.deleteButton, row, nil, nil, true)
        end
    end
    self:_call("ReskinInput", manager.name)
    for _, button in ipairs({ manager.new, manager.save, manager.addMember, manager.blockCurrent }) do
        self:_call("Reskin", button)
    end
    return self:IsEnabled()
end

function SkinCompat:SkinBulk(view)
    self:_remember("bulk", view)
    if type(view) ~= "table" or type(view.frame) ~= "table" or not self:IsEnabled() then return false end
    local frame = view.frame
    self:_call("Reskin", frame.composeTab)
    self:_call("Reskin", frame.historyTab)
    for index = 1, #(frame.sourceButtons or {}) do
        self:_call("Reskin", frame.sourceButtons[index])
    end
    self:_call("Reskin", frame.rankButton)
    self:_call("ReskinCheck", frame.onlineOnly)
    self:_call("ReskinInput", frame.search)
    self:_call("ReskinScroll", frame.scroll)
    self:_call("ReskinInput", frame.subject)
    if view.amountUsesMoneyFrame then
        local amount = frame.amount
        for _, field in ipairs({ amount and amount.gold, amount and amount.silver, amount and amount.copper }) do
            self:_call("ReskinInput", field)
        end
    else
        self:_call("ReskinInput", frame.amount)
    end
    for _, button in ipairs({ frame.selectAll, frame.clear, frame.send }) do
        self:_call("Reskin", button)
    end
    local panel = frame.historyPanel
    if panel then
        for _, button in ipairs({ panel.retry, panel.newBatch }) do self:_call("Reskin", button) end
    end
    invoke(frame.bodyPaper, "Hide")
    self:_call("StripTextures", frame.bodyContainer)
    self:_call("CreateBDFrame", frame.bodyContainer, 0.25)
    self:_call("ReskinTrimScroll", frame.bodyScrollBar)
    self:_useHighlightText(frame.body)
    return self:IsEnabled()
end

function SkinCompat:SkinPopover(frame, widgets)
    self:_remember("popover", frame)
    self.popoverWidgets[frame] = copyList(widgets)
    for index = 1, #(widgets or {}) do
        local widget = widgets[index]
        local isCheck = widget and widget.frameType == "CheckButton"
        if widget and type(widget.IsObjectType) == "function" then
            local ok, value = pcall(widget.IsObjectType, widget, "CheckButton")
            isCheck = ok and value == true
        end
        if isCheck then
            self:_call("ReskinCheck", widget)
        else
            self:_call("Reskin", widget)
        end
    end
    return self:IsEnabled()
end

function SkinCompat:Refresh()
    local pending = {}
    for object, kind in pairs(self.targets) do
        pending[#pending + 1] = { object = object, kind = kind }
    end
    for index = 1, #pending do
        local target = pending[index]
        if target.kind == "tab" then self:SkinTab(target.object)
        elseif target.kind == "inbox" then self:SkinInbox(target.object)
        elseif target.kind == "compose" then self:SkinCompose(target.object)
        elseif target.kind == "recipientManager" then self:SkinRecipientManager(target.object)
        elseif target.kind == "bulk" then self:SkinBulk(target.object)
        elseif target.kind == "popover" then
            self:SkinPopover(target.object, self.popoverWidgets[target.object])
        end
    end
    return self:IsEnabled()
end

Mail.MailSkinCompat = SkinCompat
Mail.SkinCompat = Mail.SkinCompat or SkinCompat.New()

return SkinCompat
