local _, ns = ...

ns = ns or {}
ns.Mail = ns.Mail or {}
local Mail = ns.Mail

local ComposeController = {}
ComposeController.__index = ComposeController

local function clone(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = clone(item) end
    return result
end

function ComposeController.New(deps)
    deps = deps or {}
    return setmetatable({
        locale = deps.locale or (_G.GetLocale and _G.GetLocale()) or "enUS",
        config = deps.config or { autoFillRecipient = true, autoSend = false },
        recipientRepository = deps.recipientRepository,
        transaction = deps.transaction,
        transactionFactory = deps.transactionFactory,
        transactionDeps = deps.transactionDeps or {},
        draft = { recipient = nil, subject = "", body = "", money = 0, cod = 0, attachments = {} },
        lastGeneratedSubject = nil,
    }, ComposeController)
end

function ComposeController:SetRecipient(recipient)
    if type(recipient) == "string" and self.recipientRepository then
        recipient = self.recipientRepository:Normalize({ name = recipient }, "recent")
    end
    self.draft.recipient = recipient and clone(recipient) or nil
end

function ComposeController:SetSubject(subject)
    self.draft.subject = type(subject) == "string" and subject or ""
end

function ComposeController:SetBody(body)
    self.draft.body = type(body) == "string" and body or ""
end

function ComposeController:SetAttachments(attachments)
    self.draft.attachments = clone(attachments or {})
end

function ComposeController:SetMoney(amount)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    local ownsSubject = self.draft.subject == "" or self.draft.subject == self.lastGeneratedSubject
    self.draft.money = amount
    self.draft.cod = 0
    if ownsSubject then
        local formatter = Mail.MoneySubjectFormatter
        local generated = formatter and formatter.Format(amount, self.locale) or ""
        self.draft.subject = generated
        self.lastGeneratedSubject = generated
    end
    return self.draft.subject
end

function ComposeController:AutoFillRecipient(context)
    if self.draft.recipient or not self.config.autoFillRecipient or not self.recipientRepository then return false end
    local recent = self.recipientRepository:ListRecent(context, 1)
    if not recent[1] then return false end
    self.draft.recipient = clone(recent[1])
    return true
end

function ComposeController:GetDraft()
    return clone(self.draft)
end

function ComposeController:BeginSend(policy)
    local transaction = self.transaction
    if not transaction and self.transactionFactory then transaction = self.transactionFactory(self.transactionDeps) end
    if not transaction and Mail.SendTransaction then transaction = Mail.SendTransaction.New(self.transactionDeps) end
    if not transaction then return nil, { code = "SEND_SERVICE_UNAVAILABLE", message = "发件服务尚未初始化" } end
    self.transaction = transaction
    local draft = self:GetDraft()
    draft.mode = #draft.attachments == 0 and draft.money > 0 and "MONEY_ONLY" or "STANDARD"
    policy = policy or {}
    if policy.autoSend == nil then policy.autoSend = self.config.autoSend == true end
    return transaction:Begin(draft, policy)
end

function ComposeController:Send()
    if not self.transaction then return nil, { code = "NO_TRANSACTION", message = "当前没有可发送事务" } end
    return self.transaction:Send()
end

function ComposeController:OnSendEvent(event, payload)
    if self.transaction then return self.transaction:OnSendEvent(event, payload) end
end

function ComposeController:RefreshConfig(config)
    self.config = config or self.config
end

Mail.ComposeController = ComposeController
