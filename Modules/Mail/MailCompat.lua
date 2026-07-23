local _, ns = ...
local Mail = ns.Mail

local Compat = {}
Compat.__index = Compat

local MAIL_UI_ERROR_GLOBALS = {
    "ERR_MAIL_ATTACHMENT_INVALID", "ERR_MAIL_BAG", "ERR_MAIL_BOUND_ITEM",
    "ERR_MAIL_CONJURED_ITEM", "ERR_MAIL_DATABASE_ERROR", "ERR_MAIL_INVALID_ATTACHMENT",
    "ERR_MAIL_INVALID_ATTACHMENT_SLOT", "ERR_MAIL_LIMITED_DURATION_ITEM",
    "ERR_MAIL_QUEST_ITEM", "ERR_MAIL_RECIPIENT_NOT_FOUND", "ERR_MAIL_TARGET_NOT_FOUND",
    "ERR_MAIL_TEMP_RETURN_OUTAGE", "ERR_MAIL_TOO_MANY_ATTACHMENTS", "ERR_MAIL_TO_SELF",
    "ERR_MAIL_UNIQUE_ITEM", "ERR_MAIL_WRAPPED_COD", "ERR_NOT_ENOUGH_MONEY",
    "ERR_INV_FULL", "ERR_ITEM_MAX_COUNT", "ERR_ITEM_LOCKED", "ERR_OBJECT_IS_BUSY",
}

local function apiValue(self, name)
    local value = self.api[name]
    if value ~= nil then return value end
    return _G[name]
end

local function unavailable(name)
    return nil, Mail:NewError("API_UNAVAILABLE", "当前客户端不支持邮件接口：" .. tostring(name), {
        api = name,
    })
end

local function packValues(...)
    return { n = select("#", ...), ... }
end

local function invoke(self, name, ...)
    local callback = apiValue(self, name)
    if type(callback) ~= "function" then return unavailable(name) end
    local result = packValues(pcall(callback, ...))
    if not result[1] then
        return nil, Mail:NewError("API_CALL_FAILED", "邮件接口调用失败：" .. tostring(name), {
            api = name,
            cause = tostring(result[2]),
        })
    end
    return unpack(result, 2, result.n)
end

function Compat.New(api)
    return setmetatable({
        api = api or {},
        capabilities = nil,
        lifecycleListeners = {},
        sendListeners = {},
        eventListeners = {},
        enabled = false,
        generation = 0,
        frame = nil,
    }, Compat)
end

function Compat:Detect()
    if self.capabilities then return self.capabilities end
    local cAddOns = self.api.C_AddOns or _G.C_AddOns
    local cContainer = self.api.C_Container or _G.C_Container
    local enum = self.api.Enum or _G.Enum
    self.capabilities = {
        hasInteractionManager = enum and enum.PlayerInteractionType
            and enum.PlayerInteractionType.MailInfo ~= nil or false,
        hasContainerAPI = type(cContainer) == "table"
            and type(cContainer.PickupContainerItem) == "function" or false,
        hasScrollBox = _G.ScrollUtil ~= nil,
        hasFauxScroll = type(_G.FauxScrollFrame_Update) == "function",
        hasSecureTransfer = type(self.api.C_SecureTransfer or _G.C_SecureTransfer) == "table",
        hasSecureTransferMailEvent = true,
        hasModernAddOnAPI = type(cAddOns) == "table",
        canTakeMoney = type(apiValue(self, "TakeInboxMoney")) == "function",
        canTakeItems = type(apiValue(self, "TakeInboxItem")) == "function",
        canReturn = type(apiValue(self, "ReturnInboxItem")) == "function",
        canDelete = type(apiValue(self, "DeleteInboxItem")) == "function",
    }
    return self.capabilities
end

function Compat:GetInboxCounts()
    return invoke(self, "GetInboxNumItems")
end

function Compat:GetHeader(index)
    if type(index) ~= "number" or index < 1 then
        return nil, Mail:NewError("INVALID_MAIL_INDEX", "邮件索引无效。")
    end
    local values = packValues(invoke(self, "GetInboxHeaderInfo", index))
    if values[1] == nil then
        if type(values[2]) == "table" and values[2].code then return nil, values[2] end
        local hasHeaderValue = false
        for valueIndex = 2, values.n do
            if values[valueIndex] ~= nil then
                hasHeaderValue = true
                break
            end
        end
        if not hasHeaderValue then
            return nil, Mail:NewError("MAIL_HEADER_UNAVAILABLE", "邮件标题尚不可用。", {
                index = index,
            })
        end
    end
    local canDelete, hasDeleteDecision = false, false
    local canDeleteCallback = apiValue(self, "InboxItemCanDelete")
    if type(canDeleteCallback) == "function" then
        local ok, value = pcall(canDeleteCallback, index)
        if ok then
            hasDeleteDecision = true
            canDelete = value == true
        end
    end
    return {
        index = index,
        packageIcon = values[1],
        stationeryIcon = values[2],
        sender = values[3],
        subject = values[4],
        money = tonumber(values[5]) or 0,
        cod = tonumber(values[6]) or 0,
        daysLeft = tonumber(values[7]) or 0,
        itemCount = tonumber(values[8]) or 0,
        wasRead = values[9] == true,
        wasReturned = values[10] == true,
        textCreated = values[11] == true,
        canReply = values[12] == true,
        isGM = values[13] == true,
        canDelete = canDelete,
        canReturn = hasDeleteDecision and not canDelete,
        isCOD = (tonumber(values[6]) or 0) > 0,
    }
end

function Compat:GetAttachment(index, slot)
    if type(index) ~= "number" or index < 1 or type(slot) ~= "number" or slot < 1 then
        return nil, Mail:NewError("INVALID_ATTACHMENT_INDEX", "邮件附件索引无效。")
    end
    local values = { invoke(self, "GetInboxItem", index, slot) }
    if values[1] == nil then
        if type(values[2]) == "table" and values[2].code then return nil, values[2] end
        return nil
    end
    local link = self:GetAttachmentLink(index, slot)
    local itemType, itemSubType, equipLoc, classID, subclassID
    local getItemInfo = apiValue(self, "GetItemInfo")
    local cItem = self.api.C_Item or _G.C_Item
    if type(getItemInfo) ~= "function" and cItem then getItemInfo = cItem.GetItemInfo end
    if type(getItemInfo) == "function" then
        local ok, info = pcall(function() return { getItemInfo(link or values[2]) } end)
        if ok then
            itemType = info[6]
            itemSubType = info[7]
            equipLoc = info[9]
            classID = tonumber(info[12])
            subclassID = tonumber(info[13])
        end
    end
    local getItemInfoInstant = apiValue(self, "GetItemInfoInstant")
    if type(getItemInfoInstant) ~= "function" and cItem then
        getItemInfoInstant = cItem.GetItemInfoInstant
    end
    if type(getItemInfoInstant) == "function" then
        local ok, info = pcall(function() return { getItemInfoInstant(link or values[2]) } end)
        if ok then
            itemType = info[2] or itemType
            itemSubType = info[3] or itemSubType
            equipLoc = info[4] or equipLoc
            classID = tonumber(info[6]) or classID
            subclassID = tonumber(info[7]) or subclassID
        end
    end
    return {
        mailIndex = index,
        slot = slot,
        name = values[1],
        itemID = values[2],
        texture = values[3],
        count = tonumber(values[4]) or 1,
        quality = values[5],
        canUse = values[6],
        link = link,
        itemType = itemType,
        itemSubType = itemSubType,
        equipLoc = equipLoc,
        classID = classID,
        subclassID = subclassID,
    }
end

function Compat:GetAttachmentLink(index, slot)
    local value = invoke(self, "GetInboxItemLink", index, slot)
    return value
end

function Compat:GetInvoice(index)
    if type(index) ~= "number" or index < 1 then
        return nil, Mail:NewError("INVALID_MAIL_INDEX", "邮件索引无效。")
    end
    local values = { invoke(self, "GetInboxInvoiceInfo", index) }
    if values[1] == nil then
        if type(values[2]) == "table" and values[2].code == "API_UNAVAILABLE" then
            return nil
        end
        return nil, type(values[2]) == "table" and values[2] or nil
    end
    return {
        type = values[1],
        itemName = values[2],
        playerName = values[3],
        buyer = values[3],
        bid = tonumber(values[4]),
        buyout = tonumber(values[5]),
        deposit = tonumber(values[6]),
        consignment = tonumber(values[7]),
        moneyDelay = tonumber(values[8]),
        etaHour = tonumber(values[9]),
        etaMin = tonumber(values[10]),
        count = tonumber(values[11]),
        commerceAuction = values[12],
    }
end

function Compat:TakeItem(index, slot)
    local value, err = invoke(self, "TakeInboxItem", index, slot)
    if err then return nil, err end
    return value == nil and true or value
end

function Compat:TakeMoney(index)
    local value, err = invoke(self, "TakeInboxMoney", index)
    if err then return nil, err end
    return value == nil and true or value
end

function Compat:MarkRead(index)
    local value, err = invoke(self, "GetInboxText", index)
    if err then return nil, err end
    return value == nil and true or value
end

function Compat:OpenInboxMail(index)
    if type(index) ~= "number" or index < 1 then
        return nil, Mail:NewError("INVALID_MAIL_INDEX", "邮件索引无效。")
    end
    local inboxFrame = apiValue(self, "InboxFrame")
    local openMailFrame = apiValue(self, "OpenMailFrame")
    local openMailInset = apiValue(self, "OpenMailFrameInset")
    local switchTab = apiValue(self, "MailFrameTab_OnClick")
    local updateOpenMail = apiValue(self, "OpenMail_Update")
    local updateInbox = apiValue(self, "InboxFrame_Update")
    local showPanel = apiValue(self, "ShowUIPanel")
    if not inboxFrame or not openMailFrame
        or type(updateOpenMail) ~= "function" or type(showPanel) ~= "function" then
        return unavailable("OpenMailFrame")
    end
    if type(switchTab) == "function" then pcall(switchTab, nil, 1) end
    local pageSize = math.max(1, tonumber(apiValue(self, "INBOXITEMS_TO_DISPLAY")) or 7)
    inboxFrame.pageNum = math.ceil(index / pageSize)
    inboxFrame.openMailID = index
    openMailFrame.updateButtonPositions = true
    local ok, cause = pcall(updateOpenMail)
    if not ok then
        return nil, Mail:NewError("API_CALL_FAILED", "无法打开原生邮件详情。", {
            cause = tostring(cause), index = index,
        })
    end
    local shown, showCause = pcall(showPanel, openMailFrame)
    if not shown then
        return nil, Mail:NewError("API_CALL_FAILED", "无法显示原生邮件详情。", {
            cause = tostring(showCause), index = index,
        })
    end
    if openMailInset and type(openMailInset.SetPoint) == "function" then
        pcall(openMailInset.SetPoint, openMailInset, "TOPLEFT", 4, -80)
    end
    if type(updateInbox) == "function" then pcall(updateInbox) end
    return true
end

function Compat:GetPlayerMoney()
    local value = invoke(self, "GetMoney")
    return tonumber(value) or 0
end

function Compat:GetSendPrice()
    local value = invoke(self, "GetSendMailPrice")
    return tonumber(value) or 0
end

function Compat:GetOutgoingSnapshot()
    local maxAttachments = tonumber(apiValue(self, "ATTACHMENTS_MAX_SEND"))
        or tonumber(_G.ATTACHMENTS_MAX_SEND) or 12
    local items = {}
    local getItem = apiValue(self, "GetSendMailItem")
    if type(getItem) == "function" then
        for slot = 1, maxAttachments do
            local name, itemID, texture, count, quality = getItem(slot)
            if name then
                items[#items + 1] = {
                    slot = slot,
                    name = name,
                    itemID = itemID,
                    texture = texture,
                    count = count,
                    quality = quality,
                }
            end
        end
    end
    local recipientBox = apiValue(self, "SendMailNameEditBox")
    local subjectBox = apiValue(self, "SendMailSubjectEditBox")
    local bodyBox = apiValue(self, "MailEditBox")
    local money, cod
    local readInputMoney = apiValue(self, "MoneyInputFrame_GetCopper")
    local moneyInput = apiValue(self, "SendMailMoney")
    local sendMoneyButton = apiValue(self, "SendMailSendMoneyButton")
    local codButton = apiValue(self, "SendMailCODButton")
    if type(readInputMoney) == "function" and moneyInput and (sendMoneyButton or codButton) then
        local amountOK, amount = pcall(readInputMoney, moneyInput)
        local modeOK, sendsMoney = false, false
        local sendOK, sendChecked = false, false
        local codOK, codChecked = false, false
        if sendMoneyButton and type(sendMoneyButton.GetChecked) == "function" then
            sendOK, sendChecked = pcall(sendMoneyButton.GetChecked, sendMoneyButton)
        end
        if codButton and type(codButton.GetChecked) == "function" then
            codOK, codChecked = pcall(codButton.GetChecked, codButton)
        end
        if sendOK and sendChecked then
            modeOK, sendsMoney = true, true
        elseif codOK and codChecked then
            modeOK, sendsMoney = true, false
        elseif sendOK and not codButton then
            modeOK, sendsMoney = true, false
        elseif codOK and not sendMoneyButton then
            modeOK, sendsMoney = true, not codChecked
        end
        if amountOK and modeOK then
            amount = math.max(0, math.floor(tonumber(amount) or 0))
            money = sendsMoney and amount or 0
            cod = sendsMoney and 0 or amount
        end
    end
    if money == nil or cod == nil then
        local getMoney = apiValue(self, "GetSendMailMoney")
        local getCOD = apiValue(self, "GetSendMailCOD")
        local moneyOK, moneyValue = true, 0
        local codOK, codValue = true, 0
        if type(getMoney) == "function" then moneyOK, moneyValue = pcall(getMoney) end
        if type(getCOD) == "function" then codOK, codValue = pcall(getCOD) end
        money = tonumber(moneyOK and moneyValue or 0) or 0
        cod = tonumber(codOK and codValue or 0) or 0
    end
    return {
        recipient = recipientBox and recipientBox.GetText and recipientBox:GetText() or "",
        subject = subjectBox and subjectBox.GetText and subjectBox:GetText() or "",
        body = bodyBox and bodyBox.GetInputText and bodyBox:GetInputText()
            or bodyBox and bodyBox.GetText and bodyBox:GetText() or "",
        money = money,
        cod = cod,
        attachments = items,
    }
end

local function setChecked(button, checked)
    if button and type(button.SetChecked) == "function" then
        local ok, cause = pcall(button.SetChecked, button, checked)
        if not ok then return nil, cause end
    end
    return true
end

function Compat:_applyMoneyMode(money, cod)
    money = math.max(0, math.floor(tonumber(money) or 0))
    cod = math.max(0, math.floor(tonumber(cod) or 0))
    if money > 0 and cod > 0 then
        return nil, Mail:NewError("DRAFT_MONEY_AND_COD",
            "同一封邮件不能同时发送金币并使用付款取信。")
    end

    local mode = cod > 0 and 2 or 1
    local amount = cod > 0 and cod or money
    local radio = apiValue(self, "SendMailRadioButton_OnClick")
    if type(radio) == "function" then
        local ok, cause = pcall(radio, mode)
        if not ok then
            return nil, Mail:NewError("MONEY_MODE_FAILED", "切换邮件金币模式失败。", {
                cause = tostring(cause),
            })
        end
    end
    local checked, checkedError = setChecked(
        apiValue(self, "SendMailSendMoneyButton"), mode == 1)
    if not checked then
        return nil, Mail:NewError("MONEY_MODE_FAILED", "同步发送金币选项失败。", {
            cause = tostring(checkedError),
        })
    end
    checked, checkedError = setChecked(apiValue(self, "SendMailCODButton"), mode == 2)
    if not checked then
        return nil, Mail:NewError("MONEY_MODE_FAILED", "同步付款取信选项失败。", {
            cause = tostring(checkedError),
        })
    end

    local setInput = apiValue(self, "MoneyInputFrame_SetCopper")
    local moneyInput = apiValue(self, "SendMailMoney")
    if moneyInput and type(setInput) ~= "function" then
        return unavailable("MoneyInputFrame_SetCopper")
    end
    if type(setInput) == "function" and moneyInput then
        local ok, cause = pcall(setInput, moneyInput, amount)
        if not ok then
            return nil, Mail:NewError("MONEY_INPUT_FAILED", "填写邮件金币输入框失败。", {
                cause = tostring(cause),
            })
        end
    end

    local setMoney = apiValue(self, "SetSendMailMoney")
    local setCOD = apiValue(self, "SetSendMailCOD")
    if type(setMoney) ~= "function" and money > 0 then return unavailable("SetSendMailMoney") end
    if type(setCOD) ~= "function" and cod > 0 then return unavailable("SetSendMailCOD") end
    if type(setMoney) == "function" then
        local ok, cause = pcall(setMoney, money)
        if not ok then
            return nil, Mail:NewError("MONEY_INPUT_FAILED", "设置邮件金币失败。", {
                cause = tostring(cause),
            })
        end
    end
    if type(setCOD) == "function" then
        local ok, cause = pcall(setCOD, cod)
        if not ok then
            return nil, Mail:NewError("MONEY_INPUT_FAILED", "设置付款取信金额失败。", {
                cause = tostring(cause),
            })
        end
    end
    return true
end

function Compat:AttachBagItem(bag, slot)
    local cContainer = self.api.C_Container or _G.C_Container
    local pickup = cContainer and cContainer.PickupContainerItem or apiValue(self, "PickupContainerItem")
    local attach = apiValue(self, "ClickSendMailItemButton")
    if type(pickup) ~= "function" or type(attach) ~= "function" then
        return unavailable("PickupContainerItem/ClickSendMailItemButton")
    end
    local ok, cause = pcall(function()
        pickup(bag, slot)
        attach()
    end)
    if not ok then
        local clear = apiValue(self, "ClearCursor")
        if type(clear) == "function" then pcall(clear) end
        return nil, Mail:NewError("ATTACH_ITEM_FAILED", "添加邮件附件失败。", { cause = tostring(cause) })
    end
    return true
end

function Compat:IsCursorEmpty()
    local hasItem = apiValue(self, "CursorHasItem")
    if type(hasItem) ~= "function" then return true end
    local ok, value = pcall(hasItem)
    return ok and value ~= true
end

function Compat:ClearCursor()
    local clear = apiValue(self, "ClearCursor")
    if type(clear) ~= "function" then return true end
    local ok, cause = pcall(clear)
    if not ok then
        return nil, Mail:NewError("CLEAR_CURSOR_FAILED", "清理鼠标指针物品失败。", {
            cause = tostring(cause),
        })
    end
    return true
end

function Compat.NormalizeRecipient(_, name, realm)
    if type(name) ~= "string" then
        return nil, Mail:NewError("INVALID_RECIPIENT", "收件人名称无效。")
    end
    name = string.gsub(name, "^%s+", "")
    name = string.gsub(name, "%s+$", "")
    if name == "" or string.find(name, "%s") then
        return nil, Mail:NewError("INVALID_RECIPIENT", "收件人名称无效。")
    end
    local sendName = name
    if realm and realm ~= "" and not string.find(name, "-", 1, true) then
        sendName = name .. "-" .. realm
    end
    return { name = name, realm = realm, sendName = sendName, key = string.lower(sendName) }
end

function Compat:PrepareMoneyDraft(draft)
    draft = draft or {}
    local recipient = self:NormalizeRecipient(draft.recipient or draft.sendName)
    if not recipient then return nil, Mail:NewError("INVALID_RECIPIENT", "收件人名称无效。") end
    local amount = math.floor(tonumber(draft.amount) or 0)
    if amount <= 0 then return nil, Mail:NewError("INVALID_AMOUNT", "邮寄金币必须大于 0。") end
    local recipientBox = apiValue(self, "SendMailNameEditBox")
    local subjectBox = apiValue(self, "SendMailSubjectEditBox")
    local bodyBox = apiValue(self, "MailEditBox")
    if not recipientBox or not subjectBox then
        return nil, Mail:NewError("MAIL_FRAME_UNAVAILABLE", "原生发件界面尚未就绪。")
    end
    recipientBox:SetText(recipient.sendName)
    subjectBox:SetText(tostring(draft.subject or ""))
    if bodyBox and bodyBox.SetText then bodyBox:SetText(tostring(draft.body or "")) end
    return self:_applyMoneyMode(amount, 0)
end

function Compat:PrepareDraft(draft)
    draft = draft or {}
    local recipient, recipientError = self:NormalizeRecipient(draft.recipient or draft.sendName)
    if not recipient then return nil, recipientError end
    local recipientBox = apiValue(self, "SendMailNameEditBox")
    local subjectBox = apiValue(self, "SendMailSubjectEditBox")
    local bodyBox = apiValue(self, "MailEditBox")
    if not recipientBox or not subjectBox then
        return nil, Mail:NewError("MAIL_FRAME_UNAVAILABLE", "原生发件界面尚未就绪。")
    end
    recipientBox:SetText(recipient.sendName)
    subjectBox:SetText(tostring(draft.subject or ""))
    if bodyBox and bodyBox.SetText then bodyBox:SetText(tostring(draft.body or "")) end
    return self:_applyMoneyMode(draft.money or 0, draft.cod or 0)
end

function Compat:AssertNoAttachmentsOrCOD()
    local snapshot = self:GetOutgoingSnapshot()
    if #snapshot.attachments > 0 then
        return nil, Mail:NewError("DRAFT_HAS_ATTACHMENTS", "批量金币邮件不能包含附件。")
    end
    if snapshot.cod > 0 then
        return nil, Mail:NewError("DRAFT_HAS_COD", "批量金币邮件不能使用付款取信。")
    end
    return true
end

function Compat:SendCurrentDraft()
    self:RefreshNativeSendButton()
    local nativeSend = apiValue(self, "SendMailFrame_SendMail")
    if type(nativeSend) == "function" then
        local ok, cause = pcall(nativeSend)
        if ok then return true end
        return nil, Mail:NewError("SEND_DISPATCH_FAILED", "提交邮件失败。", { cause = tostring(cause) })
    end
    local send = apiValue(self, "SendMail")
    if type(send) ~= "function" then return unavailable("SendMail") end
    local draft = self:GetOutgoingSnapshot()
    local ok, cause = pcall(send, draft.recipient, draft.subject, draft.body)
    if not ok then
        return nil, Mail:NewError("SEND_DISPATCH_FAILED", "提交邮件失败。", { cause = tostring(cause) })
    end
    return true
end

function Compat:IsCommandPending()
    local cMail = self.api.C_Mail or _G.C_Mail
    if cMail and type(cMail.IsCommandPending) == "function" then
        local ok, pending = pcall(cMail.IsCommandPending)
        if ok then return pending == true end
    end
    return false
end

function Compat:RefreshNativeSendButton(arbiter)
    local button = apiValue(self, "SendMailMailButton")
    if not button then return false end

    arbiter = arbiter or Mail.WriteArbiter
    local owner = arbiter and type(arbiter.GetOwner) == "function" and arbiter:GetOwner() or nil
    local locked = owner and (owner.ownerKind == "SINGLE_SEND" or owner.ownerKind == "BULK_SEND")
    if not locked and arbiter and type(arbiter.GetQuarantine) == "function" then
        local quarantine = arbiter:GetQuarantine("SINGLE_SEND")
        if quarantine then
            local session = Mail.Session
            local generation = session and type(session.GetGeneration) == "function"
                and session:GetGeneration() or nil
            locked = generation == nil or quarantine.sessionGeneration == generation
        end
    end

    if locked then
        if type(button.Disable) == "function" then button:Disable() end
        return true
    end

    local refresh = apiValue(self, "SendMailFrame_CanSend")
    if type(refresh) == "function" then
        local ok = pcall(refresh)
        return ok
    end
    return false
end

function Compat.NormalizeUIError(_, ...)
    local values = { ... }
    local message = values[#values]
    local recognized = false
    for index = 1, #MAIL_UI_ERROR_GLOBALS do
        local localized = _G[MAIL_UI_ERROR_GLOBALS[index]]
        if localized ~= nil and localized == message then
            recognized = true
            break
        end
    end
    return Mail:NewError(recognized and "SERVER_REJECTED" or "UNKNOWN",
        tostring(message or "未归类的界面错误。"), {
        raw = values,
    })
end

function Compat:RegisterMailLifecycle(owner, onOpen, onClose)
    self.lifecycleListeners[owner] = { onOpen = onOpen, onClose = onClose }
    return true
end

function Compat:RegisterSendLifecycle(owner, callback)
    self.sendListeners[owner] = callback
    return true
end

function Compat:RegisterEventListener(owner, callback)
    self.eventListeners[owner] = callback
    return true
end

function Compat:UnregisterOwner(owner)
    self.lifecycleListeners[owner] = nil
    self.sendListeners[owner] = nil
    self.eventListeners[owner] = nil
    return true
end

function Compat:IsMailOpen()
    local frame = apiValue(self, "MailFrame")
    return frame and frame.IsShown and frame:IsShown() or false
end

local function notify(listeners, method, ...)
    for _, listener in pairs(listeners) do
        local callback = method and listener[method] or listener
        if type(callback) == "function" then Mail:SafeCall(callback, ...) end
    end
end

function Compat:OnEvent(event, ...)
    if not self.enabled then return end
    if event == "MAIL_SHOW" then
        notify(self.lifecycleListeners, "onOpen", event)
    elseif event == "MAIL_CLOSED" or event == "PLAYER_LEAVING_WORLD" then
        notify(self.lifecycleListeners, "onClose", event)
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW"
        or event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
        local interactionType = ...
        local enum = self.api.Enum or _G.Enum
        local mailType = enum and enum.PlayerInteractionType and enum.PlayerInteractionType.MailInfo
        if mailType == nil or interactionType == mailType then
            notify(self.lifecycleListeners,
                event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" and "onOpen" or "onClose", event)
        end
    end
    if event == "MAIL_SEND_SUCCESS" or event == "MAIL_FAILED" or event == "UI_ERROR_MESSAGE"
        or event == "SECURE_TRANSFER_CONFIRM_SEND_MAIL" or event == "SECURE_TRANSFER_CANCEL" then
        notify(self.sendListeners, nil, event, ...)
    end
    notify(self.eventListeners, nil, event, ...)
end

function Compat:Enable(context)
    if self.enabled then return true end
    self.enabled = true
    self.generation = context and context.generation or 0
    local createFrame = apiValue(self, "CreateFrame")
    if type(createFrame) == "function" then
        self.frame = self.frame or createFrame("Frame")
        self.frame:SetScript("OnEvent", function(_, event, ...)
            self:OnEvent(event, ...)
        end)
        local events = {
            "MAIL_SHOW", "MAIL_CLOSED", "PLAYER_LEAVING_WORLD",
            "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "PLAYER_INTERACTION_MANAGER_FRAME_HIDE",
            "MAIL_INBOX_UPDATE", "MAIL_SEND_SUCCESS", "MAIL_FAILED", "MAIL_SUCCESS",
            "UI_ERROR_MESSAGE", "BAG_UPDATE_DELAYED", "MAIL_SEND_INFO_UPDATE",
            "SEND_MAIL_MONEY_CHANGED", "SECURE_TRANSFER_CONFIRM_SEND_MAIL",
            "SECURE_TRANSFER_CANCEL", "ITEM_PUSH", "PLAYER_MONEY",
            "GROUP_ROSTER_UPDATE", "GUILD_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE", "FRIENDLIST_UPDATE",
        }
        for i = 1, #events do pcall(self.frame.RegisterEvent, self.frame, events[i]) end
    end
    self:Detect()
    return true
end

function Compat:Disable()
    self.enabled = false
    if self.frame then self.frame:UnregisterAllEvents() end
    return true
end

Mail.MailCompat = Compat
Mail.Compat = Mail.Compat or Compat.New()
Mail:RegisterRuntimeModule("compat", Mail.Compat, 10)
