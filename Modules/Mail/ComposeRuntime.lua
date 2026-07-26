local _, ns = ...

ns = ns or {}
ns.Mail = ns.Mail or {}
local Mail = ns.Mail

local ComposeRuntime = {}
ComposeRuntime.__index = ComposeRuntime
local MENU_PAGE_SIZE = 20

local function newError(code, message, detail)
    if Mail.NewError then return Mail:NewError(code, message, detail) end
    return { code = code, message = message, detail = detail }
end

local function playerContext()
    local faction
    if _G.UnitFactionGroup then
        faction = _G.UnitFactionGroup("player")
    end
    return {
        currentRealm = Mail.GetCurrentRecipientRealm and Mail.GetCurrentRecipientRealm(_G)
            or (_G.GetRealmName and _G.GetRealmName() or ""),
        currentFaction = faction,
    }
end

function Mail:EnsureRecipientServices()
    local config = self.Config and self.Config:GetMailConfig() or nil
    if not config or not self.RecipientRepository or not self.RecipientGroupRepository then return nil end
    local context = playerContext()
    local currentName = _G.UnitName and _G.UnitName("player") or nil
    if not self.Recipients then
        self.Recipients = self.RecipientRepository.New({
            storage = config.recipients,
            globalStorage = self.Config:GetGlobalConfig(),
            currentRealm = context.currentRealm,
            currentFaction = context.currentFaction,
            currentName = currentName,
        })
    end
    if not self.RecipientGroups then
        self.RecipientGroups = self.RecipientGroupRepository.New({
            storage = config.recipientGroups,
            recipientRepository = self.Recipients,
            maxMembers = config.bulk.maxRecipientsPerBatch,
        })
    end
    return self.Recipients, self.RecipientGroups
end

function ComposeRuntime.New(deps)
    return setmetatable({
        deps = deps or {},
        enabled = false,
        generation = 0,
        suggestionOffset = 0,
        suggestionRows = {},
        categoryRows = {},
        hooksInstalled = false,
        bagHookInstalled = false,
        bagTooltipHookInstalled = false,
        moneyHookInstalled = false,
        nativeCanSendGuardHookInstalled = false,
        nativeEnableSendGuardHookInstalled = false,
    }, ComposeRuntime)
end

function ComposeRuntime:_compat() return self.deps.compat or Mail.Compat end
function ComposeRuntime:_session() return self.deps.session or Mail.Session end
function ComposeRuntime:_arbiter() return self.deps.arbiter or Mail.WriteArbiter end
function ComposeRuntime:_sessionGeneration()
    local session = self:_session()
    return session and session.GetGeneration and session:GetGeneration() or self.generation
end

function ComposeRuntime:_config()
    return self.deps.config or (Mail.Config and Mail.Config:GetMailConfig().compose) or {
        autoFillRecipient = true, enableAltClick = false, autoSend = false,
        enabledBags = {}, recipientByCategory = {},
    }
end

function ComposeRuntime:_restoreRecipientAfterSuccess(recipient)
    if not self:_config().autoFillRecipient then return false end
    local sendName = type(recipient) == "table" and (recipient.sendName or recipient.name) or recipient
    if type(sendName) ~= "string" or sendName == "" then return false end
    local function restore()
        if not self.enabled or not self:_config().autoFillRecipient then return end
        local recipientBox = self.deps.recipientBox or _G.SendMailNameEditBox
        if recipientBox and recipientBox:GetText() == "" then recipientBox:SetText(sendName) end
    end
    if self.deps.scheduleFrame then
        self.deps.scheduleFrame(restore)
    elseif _G.C_Timer and _G.C_Timer.After then
        _G.C_Timer.After(0, restore)
    else
        restore()
    end
    return true
end

function ComposeRuntime:_ensureServices()
    local recipients, groups = self.deps.recipientRepository, self.deps.recipientGroupRepository
    if not recipients then recipients, groups = Mail:EnsureRecipientServices() end
    self.recipients = recipients
    self.groups = groups or self.deps.recipientGroupRepository
    if not self.history then
        self.history = self.deps.historyRepository
            or (Mail.EnsureHistoryRepository and Mail:EnsureHistoryRepository())
    end
    if not self.suggestions and Mail.RecipientSuggestions then
        self.suggestions = Mail.RecipientSuggestions.New({ recipientRepository = self.recipients })
    end
    if not self.scanner and Mail.BagScanner then
        self.scanner = Mail.BagScanner.New({ categoryRegistry = Mail.ItemCategoryRegistry })
    end
    if not self.attachments and Mail.AttachmentService then
        self.attachments = Mail.AttachmentService.New({
            compat = self:_compat(), arbiter = self:_arbiter(),
            generation = function() return self:_sessionGeneration() end,
            onComplete = function(result) self:_onAttachmentComplete(result) end,
        })
    end
    if not self.quickAttach and Mail.QuickAttachController then
        self.quickAttach = Mail.QuickAttachController.New({
            scanner = self.scanner, attachmentService = self.attachments,
            categoryRegistry = Mail.ItemCategoryRegistry,
            recipientRepository = self.recipients, config = self:_config(),
        })
    end
end

function ComposeRuntime:_setStatus(message, isError)
    if self.status then
        self.status:SetText(message or "")
        if isError then self.status:SetTextColor(1, 0.25, 0.25)
        else self.status:SetTextColor(0.2, 1, 0.2) end
        return
    end
    if message and message ~= "" and _G.UIErrorsFrame and _G.UIErrorsFrame.AddMessage then
        local red, green, blue = 0.2, 1, 0.2
        if isError then red, green, blue = 1, 0.25, 0.25 end
        _G.UIErrorsFrame:AddMessage(message, red, green, blue)
    end
end

function ComposeRuntime:_recipientCandidates(query)
    local result, seen = {}, {}
    local suggestions = self.suggestions and self.suggestions:Query(query or "", {}) or {}
    for index = 1, #suggestions do
        result[#result + 1] = suggestions[index]
        seen[suggestions[index].recipientKey] = true
    end
    local groups = self.groups and self.groups:ListGroups() or {}
    local folded = string.lower(query or "")
    for groupIndex = 1, #groups do
        local group = groups[groupIndex]
        for memberIndex = 1, #group.members do
            local member = group.members[memberIndex]
            local target = string.lower((member.displayName or "") .. " " .. (member.sendName or ""))
            local blocked = self.recipients and self.recipients:IsBlacklisted(member)
            if not blocked and not seen[member.recipientKey]
                and (folded == "" or string.find(target, folded, 1, true)) then
                local candidate = {}
                for key, value in pairs(member) do candidate[key] = value end
                candidate.groupName = group.name
                result[#result + 1] = candidate
                seen[member.recipientKey] = true
            end
        end
    end
    return result
end

local function pagedMenu(entries)
    if #entries <= MENU_PAGE_SIZE then return entries end
    local pages = {}
    for first = 1, #entries, MENU_PAGE_SIZE do
        local children = {}
        local last = math.min(#entries, first + MENU_PAGE_SIZE - 1)
        for index = first, last do children[#children + 1] = entries[index] end
        pages[#pages + 1] = {
            text = string.format("%d-%d", first, last),
            hasArrow = true,
            menuList = children,
            notCheckable = true,
        }
    end
    return pages
end

local function classFileFor(className, classFile)
    if classFile and classFile ~= "" then return classFile end
    if not className or className == "" then return nil end
    local male = _G.LOCALIZED_CLASS_NAMES_MALE or {}
    local female = _G.LOCALIZED_CLASS_NAMES_FEMALE or {}
    for token, localized in pairs(male) do
        if localized == className or female[token] == className then return token end
    end
end

local function recipientLabel(recipient)
    local name = recipient.displayName or recipient.sendName or recipient.name or ""
    local classFile = classFileFor(recipient.className, recipient.classFile)
    local level = tonumber(recipient.level)
    if not level or not classFile then return name end
    local colors = _G.CUSTOM_CLASS_COLORS or _G.RAID_CLASS_COLORS or {}
    local color = colors[classFile]
    local className = recipient.className
        or (_G.LOCALIZED_CLASS_NAMES_MALE and _G.LOCALIZED_CLASS_NAMES_MALE[classFile])
        or classFile
    if not color then return string.format("%s (%d %s)", name, level, className) end
    return string.format("%s |cff%02x%02x%02x(%d %s)|r", name,
        math.floor((color.r or 1) * 255 + 0.5),
        math.floor((color.g or 1) * 255 + 0.5),
        math.floor((color.b or 1) * 255 + 0.5), level, className)
end

local function enrichRecipients(recipients, metadataByKey)
    local result = {}
    for index = 1, #(recipients or {}) do
        local source = recipients[index]
        local item = {}
        for key, value in pairs(source) do item[key] = value end
        local metadata = metadataByKey[item.recipientKey]
        if metadata then
            if item.level == nil then item.level = metadata.level end
            if item.classFile == nil then item.classFile = metadata.classFile end
            if item.className == nil then item.className = metadata.className end
        end
        result[#result + 1] = item
    end
    return result
end

function ComposeRuntime:_selectDirectoryRecipient(recipient, fallbackSendName)
    local currentRealm = Mail.GetCurrentRecipientRealm and Mail.GetCurrentRecipientRealm(_G) or ""
    if self.recipients and type(self.recipients.SetPlayerContext) == "function"
        and type(_G.UnitName) == "function" and currentRealm ~= "" then
        self.recipients:SetPlayerContext({
            name = _G.UnitName("player"),
            realm = currentRealm,
            faction = _G.UnitFactionGroup and _G.UnitFactionGroup("player") or nil,
        })
    end
    local normalized = self.recipients and self.recipients:Normalize(recipient, recipient and recipient.source)
    local sendName = normalized and normalized.sendName or fallbackSendName
        or recipient and (recipient.sendName or recipient.name) or ""
    local box = self.deps.recipientBox or _G.SendMailNameEditBox
    if box then box:SetText(sendName) end
    local subject = _G.SendMailSubjectEditBox
    if subject and subject.SetFocus then subject:SetFocus() end
    if type(_G.CloseDropDownMenus) == "function" then _G.CloseDropDownMenus() end
    return sendName
end

function ComposeRuntime:_recipientMenuItems(recipients)
    local items, seen = {}, {}
    for index = 1, #(recipients or {}) do
        local recipient = recipients[index]
        if recipient and recipient.recipientKey and not recipient.isSelf
            and not self.recipients:IsBlacklisted(recipient)
            and not seen[recipient.recipientKey] then
            seen[recipient.recipientKey] = true
            local sendName = recipient.sendName or recipient.name
            items[#items + 1] = {
                text = recipientLabel(recipient),
                sendName = sendName,
                arg1 = sendName,
                notCheckable = true,
                func = function()
                    self:_selectDirectoryRecipient(recipient, sendName)
                end,
            }
        end
    end
    if #items == 0 then
        items[1] = { text = "暂无成员", disabled = true, notCheckable = true }
    end
    return pagedMenu(items)
end

function ComposeRuntime:_nativeFriends()
    local api = _G.C_FriendList
    if not api then return {} end
    if type(api.ShowFriends) == "function" then pcall(api.ShowFriends) end
    local count = type(api.GetNumFriends) == "function" and api.GetNumFriends() or 0
    local result = {}
    for index = 1, count do
        local info = type(api.GetFriendInfoByIndex) == "function" and api.GetFriendInfoByIndex(index)
        local recipient = info and self.recipients:Normalize({
            name = info.name,
            level = info.level,
            className = info.className,
            classFile = classFileFor(info.className, info.classFile or info.classFilename),
            online = info.connected == true,
        }, "friend")
        if recipient and not recipient.isSelf then result[#result + 1] = recipient end
    end
    table.sort(result, function(left, right)
        return string.lower(left.displayName) < string.lower(right.displayName)
    end)
    return result
end

function ComposeRuntime:_nativeGuild()
    if _G.C_GuildInfo and type(_G.C_GuildInfo.GuildRoster) == "function" then
        pcall(_G.C_GuildInfo.GuildRoster)
    end
    local count = type(_G.GetNumGuildMembers) == "function" and _G.GetNumGuildMembers() or 0
    local result = {}
    for index = 1, count do
        local name, rankName, rankIndex, level, className, _, _, _, online, _, classFile =
            _G.GetGuildRosterInfo(index)
        local recipient = name and self.recipients:Normalize({
            name = name,
            rankName = rankName,
            rankIndex = rankIndex,
            level = level,
            className = className,
            classFile = classFile,
            online = online == true,
        }, "guild")
        if recipient and not recipient.isSelf then result[#result + 1] = recipient end
    end
    table.sort(result, function(left, right)
        return string.lower(left.displayName) < string.lower(right.displayName)
    end)
    return result
end

function ComposeRuntime:_refreshDirectory()
    return self:_recipientCandidates("")
end

function ComposeRuntime:_toggleDirectory()
    if Mail.Config and type(Mail.Config.RetryLegacyMigrations) == "function" then
        Mail.Config:RetryLegacyMigrations()
    end
    local groups = self.groups and self.groups:ListGroups() or {}
    local alts = self.recipients:ListAlts({ currentRealmOnly = true })
    local allAlts = self.recipients:ListAlts({ includeAllFactions = true })
    local friends = self:_nativeFriends()
    local guild = self:_nativeGuild()
    local metadataByKey = {}
    for _, list in ipairs({ alts, friends, guild }) do
        for index = 1, #list do metadataByKey[list[index].recipientKey] = list[index] end
    end
    self.directoryMetadata = metadataByKey
    local groupMenu = {}
    for index = 1, #groups do
        groupMenu[#groupMenu + 1] = {
            text = groups[index].name,
            hasArrow = true,
            menuList = self:_recipientMenuItems(enrichRecipients(groups[index].members, metadataByKey)),
            notCheckable = true,
        }
    end
    if #groupMenu == 0 then
        groupMenu[1] = { text = "暂无自定义组", disabled = true, notCheckable = true }
    end
    local current = self:_currentRecipient()
    local addTargets = {
        {
            text = "默认联系人",
            notCheckable = true,
            func = function() self:_addCurrentRecipient() end,
        },
    }
    for index = 1, #groups do
        local groupId = groups[index].id
        addTargets[#addTargets + 1] = {
            text = groups[index].name,
            notCheckable = true,
            func = function() self:_addCurrentRecipient(groupId) end,
        }
    end
    local menu = {
        {
            text = "添加当前收件人",
            hasArrow = true,
            menuList = addTargets,
            disabled = not current or self:_recipientIsBlacklisted(current),
            notCheckable = true,
        },
        { text = "", isTitle = true, disabled = true, notCheckable = true },
        { text = "联系人", hasArrow = true,
            menuList = self:_recipientMenuItems(enrichRecipients(
                self.recipients:ListContacts(), metadataByKey)), notCheckable = true },
        { text = "最近邮寄", hasArrow = true,
            menuList = self:_recipientMenuItems(enrichRecipients(
                self.recipients:ListRecent(), metadataByKey)), notCheckable = true },
        { text = "小号", hasArrow = true,
            menuList = self:_recipientMenuItems(alts), notCheckable = true },
        { text = "全部小号", hasArrow = true,
            menuList = self:_recipientMenuItems(allAlts), notCheckable = true },
        { text = "好友", hasArrow = true,
            menuList = self:_recipientMenuItems(friends), notCheckable = true },
        { text = "公会", hasArrow = true,
            menuList = self:_recipientMenuItems(guild), notCheckable = true },
        { text = "自定义组", hasArrow = true, menuList = groupMenu, notCheckable = true },
    }
    menu[#menu + 1] = {
        text = "收件人管理",
        notCheckable = true,
        func = function()
            if type(_G.CloseDropDownMenus) == "function" then _G.CloseDropDownMenus() end
            self:_toggleGroupManager(self.deps.CreateFrame or _G.CreateFrame)
        end,
    }
    self.recipientMenuEntries = menu
    if type(_G.ToggleDropDownMenu) == "function" and self.recipientMenu then
        _G.ToggleDropDownMenu(1, nil, self.recipientMenu, self.directoryButton, 0, 0)
    else
        self:_setStatus("当前客户端无法打开收件人菜单", true)
    end
end

function ComposeRuntime:_currentRecipient()
    local box = self.deps.recipientBox or _G.SendMailNameEditBox
    if not box or box:GetText() == "" then return nil, newError("INVALID_RECIPIENT", "请先填写收件人") end
    return self.recipients:Normalize({ name = box:GetText() }, "contact")
end

function ComposeRuntime:_addCurrentRecipient(groupId)
    local recipient, err = self:_currentRecipient()
    if not recipient then self:_setStatus(err and err.message or "收件人无效", true) return nil, err end
    if self:_recipientIsBlacklisted(recipient) then
        local blocked = newError("RECIPIENT_BLACKLISTED", "黑名单收件人不能加入联系人或用户组")
        self:_setStatus(blocked.message, true)
        return nil, blocked
    end
    local ok, saveError
    if groupId then ok, saveError = self.groups:AddMember(groupId, recipient)
    else ok, saveError = self.recipients:AddContact(recipient) end
    if not ok then
        self:_setStatus(saveError and saveError.message or "添加收件人失败", true)
        return nil, saveError
    end
    if type(_G.CloseDropDownMenus) == "function" then _G.CloseDropDownMenus() end
    self:_setStatus(groupId and "已加入自定义组" or "已添加默认联系人", false)
    self:_refreshGroupManager()
    self:_refreshDirectory()
    return true
end

function ComposeRuntime:_recipientIsBlacklisted(value)
    if not self.recipients or type(self.recipients.IsBlacklisted) ~= "function" then return false end
    local recipient = value
    if type(value) ~= "table" then
        recipient = self.recipients:Normalize({ name = tostring(value or "") }, "blacklist-check")
    end
    return recipient and self.recipients:IsBlacklisted(recipient) or false
end

function ComposeRuntime:_applyRecipientBlacklistGuard(recipientBox, skipRefresh)
    recipientBox = recipientBox or self.deps.recipientBox or _G.SendMailNameEditBox
    local name = recipientBox and recipientBox:GetText() or ""
    local blocked = name ~= "" and self:_recipientIsBlacklisted(name)
    local button = self.deps.nativeSendButton or _G.SendMailMailButton
    if blocked then
        if button and button.Disable then button:Disable() end
        self.pendingNativeRecipient = nil
        self.pendingNativeMail = nil
        self:_setStatus("该收件人已在黑名单，请先解除后再发送", true)
    elseif self.recipientWasBlacklisted and not skipRefresh then
        local compat = self:_compat()
        if compat and type(compat.RefreshNativeSendButton) == "function" then
            compat:RefreshNativeSendButton(self:_arbiter())
        end
    end
    self.recipientWasBlacklisted = blocked == true
    return blocked == true
end

function ComposeRuntime:_refreshGroupManager()
    if not self.groupManager then return end
    local contacts = self.recipients and enrichRecipients(
        self.recipients:ListContacts(), self.directoryMetadata or {}) or {}
    local contactOffset = math.max(0, math.min(self.groupManager.contactOffset or 0,
        math.max(0, #contacts - #self.groupManager.contactRows)))
    self.groupManager.contactOffset = contactOffset
    for index = 1, #self.groupManager.contactRows do
        local row, contact = self.groupManager.contactRows[index], contacts[contactOffset + index]
        row.contact = contact
        if contact then
            row.label:SetText(recipientLabel(contact))
            row.selected = contact.recipientKey == self.selectedManagedContactKey
            row:Show()
        else
            row.label:SetText("")
            row.selected = false
            row:Hide()
        end
    end
    self.groupManager.contactCount = #contacts

    local blacklist = self.recipients and self.recipients:ListBlacklist() or {}
    local blacklistOffset = math.max(0, math.min(self.groupManager.blacklistOffset or 0,
        math.max(0, #blacklist - #self.groupManager.blacklistRows)))
    self.groupManager.blacklistOffset = blacklistOffset
    for index = 1, #self.groupManager.blacklistRows do
        local row = self.groupManager.blacklistRows[index]
        local recipient = blacklist[blacklistOffset + index]
        row.blockedRecipient = recipient
        if recipient then
            row.label:SetText(recipientLabel(recipient))
            row.selected = recipient.recipientKey == self.selectedManagedBlacklistKey
            row:Show()
        else
            row.label:SetText("")
            row.selected = false
            row:Hide()
        end
    end
    self.groupManager.blacklistCount = #blacklist

    local groups = self.groups and self.groups:ListGroups() or {}
    local offset = math.max(0, math.min(self.groupManager.groupOffset or 0,
        math.max(0, #groups - #self.groupManager.groupRows)))
    self.groupManager.groupOffset = offset
    for index = 1, #self.groupManager.groupRows do
        local row, group = self.groupManager.groupRows[index], groups[offset + index]
        row.group = group
        if group then
            row.label:SetText(group.name)
            row.selected = group.id == self.selectedManagedGroupId
            row:Show()
        else
            row.label:SetText("")
            row.selected = false
            row:Hide()
        end
    end
    self.groupManager.groupCount = #groups
    local selected = self.selectedManagedGroupId and self.groups:Get(self.selectedManagedGroupId) or nil
    if not selected and groups[1] then selected = groups[1] self.selectedManagedGroupId = selected.id end
    if selected then self.groupManager.name:SetText(selected.name)
    else self.groupManager.name:SetText("") end
    local members = selected and enrichRecipients(selected.members, self.directoryMetadata or {}) or {}
    local memberOffset = math.max(0, math.min(self.groupManager.memberOffset or 0,
        math.max(0, #members - #self.groupManager.memberRows)))
    self.groupManager.memberOffset = memberOffset
    for index = 1, #self.groupManager.memberRows do
        local row, member = self.groupManager.memberRows[index], members[memberOffset + index]
        row.member = member
        row.memberGroupId = selected and selected.id or nil
        if member then
            row.label:SetText(recipientLabel(member))
            row.selected = member.recipientKey == self.selectedManagedMemberKey
            row:Show()
        else
            row.label:SetText("")
            row.selected = false
            row:Hide()
        end
    end
    self.groupManager.memberCount = #members
    for _, rows in ipairs({
        self.groupManager.contactRows, self.groupManager.blacklistRows,
        self.groupManager.groupRows, self.groupManager.memberRows,
    }) do
        for index = 1, #rows do
            if rows[index].selectionLayer then rows[index].selectionLayer:SetShown(rows[index].selected == true) end
        end
    end
end

function ComposeRuntime:_saveManagedGroup(createNew)
    local name = self.groupManager.name:GetText():gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then self:_setStatus("用户组名称不能为空", true) return end
    local existing = not createNew and self.selectedManagedGroupId
        and self.groups:Get(self.selectedManagedGroupId) or nil
    local ok, err, groupId = self.groups:UpsertGroup({
        id = existing and existing.id or nil,
        name = name,
        members = existing and existing.members or {},
    })
    if not ok then self:_setStatus(err and err.message or "用户组保存失败", true) return end
    self.selectedManagedGroupId = groupId
    self:_setStatus(createNew and "已新建用户组" or "已保存用户组", false)
    self:_refreshGroupManager()
    self:_refreshDirectory()
end

function ComposeRuntime:_deleteManagedContact(recipient)
    if not recipient or not self.recipients:RemoveContact(recipient) then
        self:_setStatus("联系人删除失败", true)
        return nil
    end
    if self.selectedManagedContactKey == recipient.recipientKey then
        self.selectedManagedContactKey = nil
    end
    self:_setStatus("已删除联系人", false)
    self:_refreshGroupManager()
    self:_refreshDirectory()
    return true
end

function ComposeRuntime:_deleteManagedBlacklist(recipient)
    if not recipient or not self.recipients:RemoveBlacklist(recipient) then
        self:_setStatus("黑名单成员删除失败", true)
        return nil
    end
    if self.selectedManagedBlacklistKey == recipient.recipientKey then
        self.selectedManagedBlacklistKey = nil
    end
    self:_setStatus("已解除黑名单", false)
    self:_refreshGroupManager()
    self:_refreshDirectory()
    self:_applyRecipientBlacklistGuard(nil, false)
    return true
end

function ComposeRuntime:_deleteManagedGroup(group)
    if not group or not self.groups:DeleteGroup(group.id) then
        self:_setStatus("用户组删除失败", true)
        return nil
    end
    if self.selectedManagedGroupId == group.id then
        self.selectedManagedGroupId = nil
        self.selectedManagedMemberKey = nil
    end
    self:_setStatus("已删除用户组", false)
    self:_refreshGroupManager()
    self:_refreshDirectory()
    return true
end

function ComposeRuntime:_addManagedMember()
    local group = self.selectedManagedGroupId and self.groups:Get(self.selectedManagedGroupId)
    if not group then self:_setStatus("请先选择用户组", true) return end
    local recipient, err = self:_currentRecipient()
    if not recipient then self:_setStatus(err.message, true) return end
    local ok, saveError = self.groups:AddMember(group.id, recipient)
    if not ok then self:_setStatus(saveError and saveError.message or "用户组成员保存失败", true) return end
    self:_setStatus("已加入用户组", false)
    self:_refreshGroupManager()
    self:_refreshDirectory()
    return true
end

function ComposeRuntime:_deleteManagedMember(groupId, recipient)
    if not groupId or not recipient then return nil end
    local ok, saveError = self.groups:RemoveMember(groupId, recipient)
    if not ok then
        self:_setStatus(saveError and saveError.message or "用户组成员删除失败", true)
        return nil
    end
    if self.selectedManagedMemberKey == recipient.recipientKey then
        self.selectedManagedMemberKey = nil
    end
    self:_setStatus("已移出用户组", false)
    self:_refreshGroupManager()
    self:_refreshDirectory()
    return true
end

function ComposeRuntime:_setGroupManagerPage(pageId)
    local manager = self.groupManager
    if not manager or not manager.pages or not manager.pages[pageId] then return false end
    manager.activePage = pageId
    for id, page in pairs(manager.pages) do page:SetShown(id == pageId) end
    for id, button in pairs(manager.tabs or {}) do
        button.selected = id == pageId
        if button.selected and type(_G.PanelTemplates_SelectTab) == "function" then
            _G.PanelTemplates_SelectTab(button)
        elseif not button.selected and type(_G.PanelTemplates_DeselectTab) == "function" then
            _G.PanelTemplates_DeselectTab(button)
        end
        if type(_G.PanelTemplates_SelectTab) ~= "function" then
            if button.selected then button:Disable() else button:Enable() end
        end
    end
    return true
end

function ComposeRuntime:_ensureGroupManager(createFrame)
    if self.groupManager then return self.groupManager end
    local managerName = "EasyAuctionRecipientManager"
    local manager = createFrame("Frame", managerName, self.toolbar, "BackdropTemplate")
    manager:SetSize(338, 424)
    manager:SetPoint("TOPLEFT", _G.MailFrame or self.toolbar, "TOPRIGHT", 0, 0)
    manager:SetFrameStrata("DIALOG")
    manager:EnableMouse(true)
    if manager.SetClampedToScreen then manager:SetClampedToScreen(true) end
    if manager.SetBackdrop then
        manager:SetBackdrop({
            bgFile = "Interface/Buttons/WHITE8X8",
            edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
            edgeSize = 10,
        })
        manager:SetBackdropColor(0.03, 0.03, 0.03, 0.97)
    end
    manager.title = manager:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    manager.title:SetPoint("TOP", manager, "TOP", 0, -12)
    manager.title:SetText("收件人管理")
    manager.closeButton = createFrame("Button", nil, manager, "UIPanelCloseButton")
    manager.closeButton:SetPoint("TOPRIGHT", manager, "TOPRIGHT", -3, -3)
    manager.closeButton:SetScript("OnClick", function() manager:Hide() end)
    _G.UISpecialFrames = _G.UISpecialFrames or {}
    local registered
    for index = 1, #_G.UISpecialFrames do
        if _G.UISpecialFrames[index] == managerName then registered = true break end
    end
    if not registered then _G.UISpecialFrames[#_G.UISpecialFrames + 1] = managerName end

    manager.pages, manager.tabs = {}, {}
    local pageIds = { { "contacts", "联系人" }, { "blacklist", "黑名单" }, { "groups", "自定义组" } }
    for index = 1, #pageIds do
        local pageId, label = pageIds[index][1], pageIds[index][2]
        local page = createFrame("Frame", nil, manager)
        page:SetPoint("TOPLEFT", manager, "TOPLEFT", 8, -72)
        page:SetPoint("BOTTOMRIGHT", manager, "BOTTOMRIGHT", -8, 42)
        manager.pages[pageId] = page
        local tab = createFrame("Button", managerName .. "Tab" .. index,
            manager, "PanelTopTabButtonTemplate")
        tab:SetID(index)
        tab:SetSize(92, 32)
        tab:SetPoint("TOPLEFT", manager, "TOPLEFT", 12 + (index - 1) * 96, -38)
        tab:SetText(label)
        if type(_G.PanelTemplates_TabResize) == "function" then
            _G.PanelTemplates_TabResize(tab, 0, 92, 92)
        end
        tab:SetScript("OnClick", function() self:_setGroupManagerPage(pageId) end)
        manager.tabs[pageId] = tab
    end

    local function createList(parent, x, width, title, height)
        local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, 0)
        label:SetText(title)
        local list = createFrame("Frame", nil, parent, "InsetFrameTemplate")
        list:SetSize(width, height or 276)
        list:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -18)
        return list
    end

    local function createRow(list, index, width, onDelete)
        local row = createFrame("Button", nil, list)
        row:SetSize(width - 10, 24)
        row:SetPoint("TOPLEFT", list, "TOPLEFT", 5, -5 - (index - 1) * 25)
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        row.selectionLayer = row:CreateTexture(nil, "BACKGROUND")
        row.selectionLayer:SetAllPoints(row)
        row.selectionLayer:SetColorTexture(1, 0.72, 0.12, 0.18)
        row.selectionLayer:Hide()
        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.label:SetPoint("LEFT", row, "LEFT", 4, 0)
        row.deleteButton = createFrame("Button", nil, row, "UIPanelCloseButtonNoScripts")
        row.deleteButton:SetSize(18, 18)
        row.deleteButton:SetPoint("RIGHT", row, "RIGHT", 1, 0)
        row.deleteButton:SetScript("OnClick", function() onDelete(row) end)
        row.label:SetPoint("RIGHT", row.deleteButton, "LEFT", -1, 0)
        row.label:SetJustifyH("LEFT")
        return row
    end

    manager.contactListFrame = createList(manager.pages.contacts, 0, 322, "默认联系人", 256)
    manager.blacklistFrame = createList(manager.pages.blacklist, 0, 322, "发件黑名单", 256)
    manager.groupListFrame = createList(manager.pages.groups, 0, 120, "自定义组", 214)
    manager.memberListFrame = createList(manager.pages.groups, 128, 194, "组成员", 214)
    manager.contactRows, manager.blacklistRows = {}, {}
    manager.groupRows, manager.memberRows = {}, {}
    for index = 1, 8 do
        local contactRow = createRow(manager.contactListFrame, index, 322,
            function(row) self:_deleteManagedContact(row.contact) end)
        contactRow:SetScript("OnClick", function(button)
            if not button.contact then return end
            self.selectedManagedContactKey = button.contact.recipientKey
            local box = self.deps.recipientBox or _G.SendMailNameEditBox
            if box then box:SetText(button.contact.sendName) end
            self:_refreshGroupManager()
        end)
        manager.contactRows[index] = contactRow

        local blacklistRow = createRow(manager.blacklistFrame, index, 322,
            function(row) self:_deleteManagedBlacklist(row.blockedRecipient) end)
        blacklistRow:SetScript("OnClick", function(button)
            if not button.blockedRecipient then return end
            self.selectedManagedBlacklistKey = button.blockedRecipient.recipientKey
            local box = self.deps.recipientBox or _G.SendMailNameEditBox
            if box then box:SetText(button.blockedRecipient.sendName) end
            self:_refreshGroupManager()
        end)
        manager.blacklistRows[index] = blacklistRow

        local groupRow = createRow(manager.groupListFrame, index, 120,
            function(row) self:_deleteManagedGroup(row.group) end)
        groupRow:SetScript("OnClick", function(button)
            if not button.group then return end
            self.selectedManagedGroupId = button.group.id
            self.selectedManagedMemberKey = nil
            manager.memberOffset = 0
            self:_refreshGroupManager()
        end)
        manager.groupRows[index] = groupRow

        local memberRow = createRow(manager.memberListFrame, index, 194,
            function(row) self:_deleteManagedMember(row.memberGroupId, row.member) end)
        memberRow:SetScript("OnClick", function(button)
            if not button.member then return end
            self.selectedManagedMemberKey = button.member.recipientKey
            local box = self.deps.recipientBox or _G.SendMailNameEditBox
            if box then box:SetText(button.member.sendName) end
            self:_refreshGroupManager()
        end)
        manager.memberRows[index] = memberRow
    end

    manager.name = createFrame("EditBox", nil, manager.pages.groups, "InputBoxTemplate")
    manager.name:SetSize(120, 22)
    manager.name:SetPoint("BOTTOMLEFT", manager.pages.groups, "BOTTOMLEFT", 0, 32)
    manager.name:SetAutoFocus(false)
    manager.new = createFrame("Button", nil, manager.pages.groups, "UIPanelButtonTemplate")
    manager.new:SetSize(42, 22)
    manager.new:SetPoint("BOTTOMLEFT", manager.pages.groups, "BOTTOMLEFT", 0, 4)
    manager.new:SetText("新建")
    manager.new:SetScript("OnClick", function() self:_saveManagedGroup(true) end)
    manager.save = createFrame("Button", nil, manager.pages.groups, "UIPanelButtonTemplate")
    manager.save:SetSize(42, 22)
    manager.save:SetPoint("LEFT", manager.new, "RIGHT", 4, 0)
    manager.save:SetText("改名")
    manager.save:SetScript("OnClick", function() self:_saveManagedGroup(false) end)
    manager.addMember = createFrame("Button", nil, manager.pages.groups, "UIPanelButtonTemplate")
    manager.addMember:SetSize(92, 22)
    manager.addMember:SetPoint("BOTTOMLEFT", manager.pages.groups, "BOTTOMLEFT", 128, 32)
    manager.addMember:SetText("加入当前")
    manager.addMember:SetScript("OnClick", function() self:_addManagedMember() end)
    manager.blockCurrent = createFrame("Button", nil, manager.pages.blacklist, "UIPanelButtonTemplate")
    manager.blockCurrent:SetSize(88, 22)
    manager.blockCurrent:SetPoint("BOTTOMLEFT", manager.pages.blacklist, "BOTTOMLEFT", 0, 4)
    manager.blockCurrent:SetText("拉黑当前")
    manager.blockCurrent:SetScript("OnClick", function()
        local recipient, err = self:_currentRecipient()
        local ok, saveError
        if recipient then ok, saveError = self.recipients:AddBlacklist(recipient) end
        if ok then
            self.selectedManagedBlacklistKey = recipient.recipientKey
            self.selectedManagedContactKey = nil
            self:_setStatus("已加入黑名单", false)
            self:_refreshGroupManager()
            self:_refreshDirectory()
            self:_applyRecipientBlacklistGuard(nil, true)
        else
            self:_setStatus((saveError or err or {}).message or "黑名单收件人无效", true)
        end
    end)
    manager.groupListFrame:EnableMouseWheel(true)
    manager.groupListFrame:SetScript("OnMouseWheel", function(_, delta)
        local maximum = math.max(0, (manager.groupCount or 0) - #manager.groupRows)
        manager.groupOffset = math.max(0, math.min(maximum, (manager.groupOffset or 0) + (delta > 0 and -1 or 1)))
        self:_refreshGroupManager()
    end)
    manager.contactListFrame:EnableMouseWheel(true)
    manager.contactListFrame:SetScript("OnMouseWheel", function(_, delta)
        local maximum = math.max(0, (manager.contactCount or 0) - #manager.contactRows)
        manager.contactOffset = math.max(0, math.min(maximum,
            (manager.contactOffset or 0) + (delta > 0 and -1 or 1)))
        self:_refreshGroupManager()
    end)
    manager.blacklistFrame:EnableMouseWheel(true)
    manager.blacklistFrame:SetScript("OnMouseWheel", function(_, delta)
        local maximum = math.max(0, (manager.blacklistCount or 0) - #manager.blacklistRows)
        manager.blacklistOffset = math.max(0, math.min(maximum,
            (manager.blacklistOffset or 0) + (delta > 0 and -1 or 1)))
        self:_refreshGroupManager()
    end)
    manager.memberListFrame:EnableMouseWheel(true)
    manager.memberListFrame:SetScript("OnMouseWheel", function(_, delta)
        local maximum = math.max(0, (manager.memberCount or 0) - #manager.memberRows)
        manager.memberOffset = math.max(0, math.min(maximum,
            (manager.memberOffset or 0) + (delta > 0 and -1 or 1)))
        self:_refreshGroupManager()
    end)
    self.groupManager = manager
    local skinCompat = self.deps.skinCompat or Mail.SkinCompat
    if skinCompat and type(skinCompat.SkinRecipientManager) == "function" then
        skinCompat:SkinRecipientManager(manager)
    end
    self:_setGroupManagerPage("contacts")
    manager:Hide()
    return manager
end

function ComposeRuntime:_toggleGroupManager(createFrame)
    local manager = self:_ensureGroupManager(createFrame)
    if manager:IsShown() then manager:Hide() return end
    local mailFrame = _G.MailFrame or self.toolbar
    local width = mailFrame and mailFrame.GetWidth and mailFrame:GetWidth() or 338
    local height = mailFrame and mailFrame.GetHeight and mailFrame:GetHeight() or 424
    if width <= 0 or width > 400 then width = 338 end
    if height <= 0 or height > 512 then height = 424 end
    manager:SetSize(width, height)
    manager:ClearAllPoints()
    manager:SetPoint("TOPLEFT", mailFrame, "TOPRIGHT", 0, 0)
    self:_refreshGroupManager()
    self:_setGroupManagerPage(manager.activePage or "contacts")
    manager:Show()
end

function ComposeRuntime:_onAttachmentComplete(result)
    if not result or not self.lastAttachmentOperation then return false end
    if result.operationId and result.operationId ~= self.lastAttachmentOperation then return false end
    if result.state == "SUCCEEDED" then
        self:_setStatus("附件已就绪", false)
        local autoSend = self.lastAttachmentAutoSend == true
        self.lastAttachmentOperation = nil
        self.lastAttachmentAutoSend = nil
        if autoSend then
            local sent, err = self:SendCurrentDraft()
            if not sent then self:_setStatus((err and (err.message or err.code)) or "发送失败", true) end
        end
        return true
    end
    if result.state == "FAILED" or result.state == "INDETERMINATE" or result.state == "CANCELLED" then
        self:_setStatus(result.error and result.error.message or "附件操作失败", true)
        self.lastAttachmentOperation = nil
        self.lastAttachmentAutoSend = nil
        return true
    end
    return false
end

function ComposeRuntime:_startAttachment(operationId, err, autoSend)
    if not operationId then
        self.lastAttachmentAutoSend = nil
        self:_setStatus((err and (err.message or err.code)) or "无法附加物品", true)
        return
    end
    self.lastAttachmentOperation = operationId
    self.lastAttachmentAutoSend = autoSend == true
    self:_setStatus("正在确认附件", false)
    if self.attachments then self:_onAttachmentComplete(self.attachments:GetResult(operationId)) end
end

function ComposeRuntime:_bagShortcutVisible()
    local sendFrame = self.deps.sendFrame or _G.SendMailFrame
    if not self.enabled or not self.toolbar or not sendFrame then return false end
    if self.toolbar.IsVisible and not self.toolbar:IsVisible() then return false end
    if sendFrame.IsShown and not sendFrame:IsShown() then return false end
    return true
end

function ComposeRuntime._bagSlot(_, button, itemLocation)
    if itemLocation then
        local bag = itemLocation.bagID or itemLocation.bagIndex
        local slot = itemLocation.slotIndex or itemLocation.slot
        if bag ~= nil and slot ~= nil then return bag, slot end
    end
    if not button then return nil, nil end
    local bag
    if type(button.GetBagID) == "function" then bag = button:GetBagID() end
    local parent = type(button.GetParent) == "function" and button:GetParent() or nil
    if bag == nil and parent and type(parent.GetID) == "function" then bag = parent:GetID() end
    local slot = type(button.GetID) == "function" and button:GetID() or nil
    return bag, slot
end

function ComposeRuntime:_bagItem(bag, slot)
    if bag == nil or slot == nil then return nil end
    local container = _G.C_Container
    local getInfo = self.deps.GetContainerItemInfo
        or (container and container.GetContainerItemInfo) or _G.GetContainerItemInfo
    if type(getInfo) ~= "function" then return nil end
    local first, count, locked, _, _, _, link, _, _, itemID = getInfo(bag, slot)
    if type(first) == "table" then
        local info = first
        return {
            bag = bag, slot = slot, itemID = tonumber(info.itemID),
            itemLink = info.hyperlink or info.itemLink,
            count = tonumber(info.stackCount or info.count) or 1,
            locked = info.isLocked == true or info.locked == true,
            bound = info.isBound == true or info.bound == true,
            icon = info.iconFileID or info.icon,
        }
    end
    if not itemID then
        local getItemID = container and container.GetContainerItemID or _G.GetContainerItemID
        if type(getItemID) == "function" then itemID = getItemID(bag, slot) end
    end
    return {
        bag = bag, slot = slot, itemID = tonumber(itemID), itemLink = link,
        count = tonumber(count) or 1, locked = locked == true, icon = first,
    }
end

function ComposeRuntime:HandleModifiedBagClick(button, mouseButton, itemLocation)
    if mouseButton ~= "LeftButton" or not self:_bagShortcutVisible() or not self.quickAttach then return false end
    local altDown = _G.IsAltKeyDown and _G.IsAltKeyDown()
    local controlDown = _G.IsControlKeyDown and _G.IsControlKeyDown()
    local config = self:_config()
    local useAlt = altDown and config.enableAltClick == true
    if not useAlt and not controlDown then return false end
    local bag, slot = self:_bagSlot(button, itemLocation)
    local item = self:_bagItem(bag, slot)
    if not item or not item.itemID or item.locked then return false end
    local operationId, err
    if useAlt then
        operationId, err = self.quickAttach:AttachSlot(item)
        local recipientBox = self.deps.recipientBox or _G.SendMailNameEditBox
        local recipient = recipientBox and recipientBox.GetText and recipientBox:GetText() or ""
        local autoSend = config.autoSend == true and recipient:gsub("%s", "") ~= ""
        self:_startAttachment(operationId, err, autoSend)
    else
        operationId, err = self.quickAttach:AttachExact(item.itemID)
        self:_startAttachment(operationId, err, false)
    end
    return operationId ~= nil
end

function ComposeRuntime:_addBagShortcutTooltip(tooltip)
    if not self:_bagShortcutVisible() or not tooltip or type(tooltip.AddLine) ~= "function" then return end
    local compat = self:_compat()
    if compat and type(compat.IsCursorEmpty) == "function" and not compat:IsCursorEmpty() then return end
    local config = self:_config()
    if config.enableAltClick == true then
        local recipientBox = self.deps.recipientBox or _G.SendMailNameEditBox
        local recipient = recipientBox and recipientBox.GetText and recipientBox:GetText() or ""
        if config.autoSend == true and recipient:gsub("%s", "") ~= "" then
            tooltip:AddLine("|cffffd200Alt+左键|r：将此物品发送给 " .. recipient, 1, 1, 1)
        else
            tooltip:AddLine("|cffffd200Alt+左键|r：附加当前物品", 1, 1, 1)
        end
    end
    tooltip:AddLine("|cffffd200Ctrl+左键|r：附加背包中的相同物品", 1, 1, 1)
end

function ComposeRuntime:_installBagShortcutHooks()
    if not self.bagHookInstalled and type(_G.hooksecurefunc) == "function" then
        if type(_G.ContainerFrameItemButton_OnModifiedClick) == "function" then
            _G.hooksecurefunc("ContainerFrameItemButton_OnModifiedClick", function(button, mouseButton)
                self:HandleModifiedBagClick(button, mouseButton)
            end)
            self.bagHookInstalled = true
        elseif type(_G.HandleModifiedItemClick) == "function" then
            _G.hooksecurefunc("HandleModifiedItemClick", function(_, itemLocation)
                if not itemLocation then return end
                local mouseButton = _G.GetMouseButtonClicked and _G.GetMouseButtonClicked() or "LeftButton"
                self:HandleModifiedBagClick(nil, mouseButton, itemLocation)
            end)
            self.bagHookInstalled = true
        end
    end
    local tooltip = self.deps.gameTooltip or _G.GameTooltip
    if not self.bagTooltipHookInstalled and tooltip and type(tooltip.HookScript) == "function" then
        tooltip:HookScript("OnTooltipSetItem", function(currentTooltip)
            self:_addBagShortcutTooltip(currentTooltip)
        end)
        self.bagTooltipHookInstalled = true
    end
end

function ComposeRuntime:_ensureUI()
    if self.toolbar then return true end
    local createFrame = self.deps.CreateFrame or _G.CreateFrame
    local parent = self.deps.sendFrame or _G.SendMailFrame
    local recipientBox = self.deps.recipientBox or _G.SendMailNameEditBox
    if type(createFrame) ~= "function" or not parent or not recipientBox then return false end

    local toolbar = createFrame("Frame", nil, parent)
    toolbar:SetAllPoints(parent)
    toolbar:SetScript("OnHide", function()
        if self.groupManager then self.groupManager:Hide() end
        if type(_G.CloseDropDownMenus) == "function" then _G.CloseDropDownMenus() end
    end)
    self.toolbar = toolbar
    self.directoryButton = createFrame("Button", nil, toolbar)
    self.directoryButton:SetSize(25, 25)
    self.directoryButton:SetPoint("LEFT", recipientBox, "RIGHT", -2, 2)
    self.directoryButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    self.directoryButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
    self.directoryButton:SetDisabledTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Disabled")
    self.directoryButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Round")
    self.directoryButton:SetScript("OnClick", function() self:_toggleDirectory() end)
    self.directoryButton:SetScript("OnHide", function()
        if type(_G.CloseDropDownMenus) == "function" then _G.CloseDropDownMenus() end
    end)
    self.recipientMenu = createFrame("Frame", nil, toolbar, "UIDropDownMenuTemplate")
    self.recipientMenu:Hide()
    if type(_G.UIDropDownMenu_Initialize) == "function" then
        _G.UIDropDownMenu_Initialize(self.recipientMenu, function(_, level, menuList)
            if type(_G.UIDropDownMenu_CreateInfo) ~= "function"
                or type(_G.UIDropDownMenu_AddButton) ~= "function" then return end
            local entries = level == 1 and self.recipientMenuEntries or menuList or {}
            for index = 1, #entries do
                local entry = entries[index]
                local info = _G.UIDropDownMenu_CreateInfo()
                info.text = entry.text
                info.notCheckable = entry.notCheckable
                info.disabled = entry.disabled
                info.func = entry.func
                info.arg1 = entry.arg1
                info.hasArrow = entry.hasArrow
                info.menuList = entry.menuList
                info.isTitle = entry.isTitle
                _G.UIDropDownMenu_AddButton(info, level)
            end
        end, "MENU")
    end

    local categories = Mail.ItemCategoryRegistry and Mail.ItemCategoryRegistry:List() or {}
    local mailFrame = self.deps.mailFrame or _G.MailFrame or parent
    for index = 1, #categories do
        local category = categories[index]
        local row = createFrame("Button", nil, toolbar, "UIPanelButtonTemplate")
        row:SetSize(42, 22)
        row:SetPoint("TOPLEFT", mailFrame, "TOPRIGHT", 2, -28 - (index - 1) * 24)
        row:SetText(category.label)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetScript("OnClick", function(_, mouseButton)
            local name = recipientBox:GetText()
            if mouseButton == "RightButton" or (_G.IsShiftKeyDown and _G.IsShiftKeyDown()) then
                if name == "" then self:_setStatus("请先填写类别默认收件人", true) return end
                local recipient, normalizeError = self.recipients:Normalize({ name = name }, "contact")
                local saved, saveError
                if recipient then saved, saveError = self.quickAttach:SetDefaultRecipient(category.id, recipient) end
                if saved then self:_setStatus("已保存" .. category.label .. "默认收件人", false)
                else self:_setStatus((saveError or normalizeError or {}).message or "默认收件人无效", true) end
                return
            end
            if name == "" then
                local defaultRecipient = self.quickAttach:GetDefaultRecipient(category.id)
                if defaultRecipient then recipientBox:SetText(defaultRecipient.sendName or defaultRecipient.name) end
            end
            self:_startAttachment(self.quickAttach:AttachCategory(category.id))
        end)
        row:SetScript("OnEnter", function()
            if _G.GameTooltip then
                _G.GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
                _G.GameTooltip:SetText(category.tooltip or category.label)
                _G.GameTooltip:AddLine("左键：附加该分类物品", 1, 1, 1)
                _G.GameTooltip:AddLine("Shift/右键：把当前姓名设为默认收件人", 0.8, 0.8, 0.8, true)
                _G.GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function() if _G.GameTooltip then _G.GameTooltip:Hide() end end)
        self.categoryRows[index] = row
    end
    self:_installHooks(recipientBox)
    local skinCompat = self.deps.skinCompat or Mail.SkinCompat
    if skinCompat and type(skinCompat.SkinCompose) == "function" then
        skinCompat:SkinCompose(self)
    end
    return true
end

function ComposeRuntime:_installHooks(recipientBox)
    if not self.hooksInstalled then
        recipientBox:HookScript("OnTextChanged", function()
            if self.enabled then
                self.suggestionOffset = 0
                self:_applyRecipientBlacklistGuard(recipientBox, false)
            end
        end)
        local nativeSend = self.deps.nativeSendButton or _G.SendMailMailButton
        if nativeSend and nativeSend.HookScript then
            nativeSend:HookScript("OnClick", function()
                if self.enabled and recipientBox:GetText() ~= ""
                    and not self:_recipientIsBlacklisted(recipientBox:GetText()) then
                    local recipient = self.recipients
                        and self.recipients:Normalize({ name = recipientBox:GetText() }, "recent")
                    self.pendingNativeRecipient = recipient
                    local compat = self:_compat()
                    local snapshot = compat and compat.GetOutgoingSnapshot
                        and compat:GetOutgoingSnapshot() or nil
                    if recipient and snapshot then
                        self.pendingNativeMail = {
                            sourceKind = "single",
                            recipient = recipient,
                            subject = snapshot.subject,
                            amount = snapshot.money,
                            postage = compat.GetSendPrice and compat:GetSendPrice() or 0,
                        }
                    else
                        self.pendingNativeMail = nil
                    end
                end
            end)
        end
        self.hooksInstalled = true
    end
    if not self.nativeCanSendGuardHookInstalled and _G.hooksecurefunc
        and type(_G.SendMailFrame_CanSend) == "function" then
        _G.hooksecurefunc("SendMailFrame_CanSend", function()
            if self.enabled then self:_applyRecipientBlacklistGuard(recipientBox, true) end
        end)
        self.nativeCanSendGuardHookInstalled = true
    end
    local moneyInput = self.deps.moneyInput or _G.SendMailMoney
    if not self.moneyHookInstalled and _G.hooksecurefunc and moneyInput
        and type(moneyInput.onValueChangedFunc) == "function" then
        _G.hooksecurefunc(moneyInput, "onValueChangedFunc", function()
            if self.enabled then self:_onMoneyChanged() end
        end)
        self.moneyHookInstalled = true
    end
    if not self.nativeEnableSendGuardHookInstalled and _G.hooksecurefunc
        and type(_G.SendMailFrame_EnableSendMailButton) == "function" then
        _G.hooksecurefunc("SendMailFrame_EnableSendMailButton", function()
            if not self.enabled then return end
            local compat = self:_compat()
            if compat and type(compat.RefreshNativeSendButton) == "function" then
                compat:RefreshNativeSendButton(self:_arbiter())
            end
            self:_applyRecipientBlacklistGuard(recipientBox, true)
        end)
        self.nativeEnableSendGuardHookInstalled = true
    end
    self:_installBagShortcutHooks()
end

function ComposeRuntime:_onMoneyChanged()
    if not self.enabled or not self.compose or not _G.SendMailSubjectEditBox then return end
    local compat = self:_compat()
    local snapshot = compat and compat:GetOutgoingSnapshot() or nil
    if not snapshot then return end
    self.compose:SetSubject(snapshot.subject or "")
    local generated = self.compose:SetMoney(snapshot.money or 0)
    if generated ~= snapshot.subject then _G.SendMailSubjectEditBox:SetText(generated) end
end

function ComposeRuntime:_transactionFromSnapshot(snapshot)
    local recipient, err = self.recipients:Normalize({ name = snapshot.recipient }, "recent")
    if not recipient then return nil, err end
    local transaction = Mail.SendTransaction.New({
        compat = self:_compat(), arbiter = self:_arbiter(), recipientRepository = self.recipients,
        historyRepository = self.history,
        generation = function() return self:_sessionGeneration() end,
        onTimeout = function(result)
            self:_setStatus(result.error and result.error.message or "等待发送结果超时", true)
        end,
    })
    local mode = snapshot.money > 0 and snapshot.cod == 0 and #snapshot.attachments == 0 and "MONEY_ONLY" or "STANDARD"
    local id, beginError = transaction:Begin({
        mode = mode, recipient = recipient, subject = snapshot.subject, body = snapshot.body,
        money = snapshot.money, cod = snapshot.cod, attachments = snapshot.attachments,
    }, { autoSend = false, attachmentsAlreadyPrepared = true })
    if not id then return nil, beginError end
    return transaction
end

function ComposeRuntime:SendCurrentDraft()
    local terminal = { SUCCEEDED = true, FAILED = true, UNKNOWN = true, CANCELLED = true }
    if self.transaction and not terminal[self.transaction:GetState()] then
        return nil, newError("TRANSACTION_BUSY", "已有发件事务正在进行")
    end
    local snapshot = self:_compat():GetOutgoingSnapshot()
    local transaction, err = self:_transactionFromSnapshot(snapshot)
    if not transaction then return nil, err end
    self.transaction = transaction
    local sent, sendError = transaction:Send()
    if sent then self:_setStatus("正在发送", false) end
    return sent, sendError
end

function ComposeRuntime:_recordPendingNativeMail(state, err)
    local pending = self.pendingNativeMail
    self.pendingNativeMail = nil
    if not pending or not self.history or not self.history.RecordSingle then return false end
    pending.state = state
    pending.error = err
    self.history:RecordSingle(pending)
    return true
end

function ComposeRuntime:OnSendEvent(event, ...)
    local transactionHandled = false
    if self.transaction then
        transactionHandled = self.transaction:OnSendEvent(event, ...) == true
        local state = self.transaction:GetState()
        if state == "SUCCEEDED" then
            self:_setStatus("发送成功", false)
            if transactionHandled then
                local snapshot = self.transaction:GetSnapshot()
                self:_restoreRecipientAfterSuccess(snapshot.draft and snapshot.draft.recipient)
            end
        elseif state == "FAILED" or state == "UNKNOWN" then
            local snapshot = self.transaction:GetSnapshot()
            self:_setStatus(snapshot.error and snapshot.error.message or state, true)
        elseif state == "WAITING_SECURE_CONFIRM" then self:_setStatus("等待原生安全转账确认", true) end
    end
    if event == "MAIL_SEND_SUCCESS" and not transactionHandled
        and self.pendingNativeRecipient and self.recipients then
        local recipient = self.pendingNativeRecipient
        self.recipients:RecordSent(recipient)
        self:_recordPendingNativeMail("SUCCEEDED")
        self.pendingNativeRecipient = nil
        self:_restoreRecipientAfterSuccess(recipient)
    elseif event == "MAIL_FAILED" then
        self:_recordPendingNativeMail("FAILED", { code = "MAIL_FAILED", message = "邮件发送失败" })
        self.pendingNativeRecipient = nil
    end
end

function ComposeRuntime:OnWoWEvent(event)
    if event == "SEND_MAIL_MONEY_CHANGED" then self:_onMoneyChanged() end
    if event == "MAIL_SEND_INFO_UPDATE" or event == "BAG_UPDATE_DELAYED" then
        if self.attachments then self.attachments:OnWoWEvent(event) end
        if self.lastAttachmentOperation and self.attachments then
            self:_onAttachmentComplete(self.attachments:GetResult(self.lastAttachmentOperation))
        end
    end
end

function ComposeRuntime:_rememberCurrentAlt()
    if not self.recipients or not _G.UnitName then return false end
    local name = _G.UnitName("player")
    local realm = Mail.GetCurrentRecipientRealm and Mail.GetCurrentRecipientRealm(_G)
        or (_G.GetRealmName and _G.GetRealmName())
    local faction = _G.UnitFactionGroup and _G.UnitFactionGroup("player") or nil
    local _, classFile
    if _G.UnitClass then _, classFile = _G.UnitClass("player") end
    if not name or not realm or not faction then return false end
    if type(self.recipients.SetPlayerContext) == "function" then
        self.recipients:SetPlayerContext({ name = name, realm = realm, faction = faction })
    end
    local saved = self.recipients:UpsertAlt({
        name = name,
        realm = realm,
        faction = faction,
        level = _G.UnitLevel and _G.UnitLevel("player") or nil,
        classFile = classFile,
    })
    local listKnown = self.deps.listKnownAltNames or _G.EasyAuction_GetAllGoldCharacters
    if type(listKnown) == "function" then
        local ok, knownNames = pcall(listKnown)
        if ok and type(knownNames) == "table" then
            for index = 1, #knownNames do
                local knownName = knownNames[index]
                if type(knownName) == "string" and knownName ~= "" then
                    self.recipients:UpsertAlt({
                        name = knownName,
                        realm = realm,
                        faction = faction,
                    })
                end
            end
        end
    end
    return saved
end

function ComposeRuntime:OnSessionStart()
    self:_ensureUI()
    if Mail.Config and type(Mail.Config.RetryLegacyMigrations) == "function" then
        Mail.Config:RetryLegacyMigrations()
    end
    self:_rememberCurrentAlt()
    local recipientBox = self.deps.recipientBox or _G.SendMailNameEditBox
    if recipientBox then self:_installHooks(recipientBox) end
    if self.toolbar then self.toolbar:Show() end
    if self:_config().autoFillRecipient and _G.SendMailNameEditBox and _G.SendMailNameEditBox:GetText() == "" then
        local recent = self.recipients and self.recipients:ListRecent(nil, 1) or {}
        if recent[1] then _G.SendMailNameEditBox:SetText(recent[1].sendName) end
    end
    local compat = self:_compat()
    if compat and type(compat.RefreshNativeSendButton) == "function" then
        compat:RefreshNativeSendButton(self:_arbiter())
    end
    self:_applyRecipientBlacklistGuard(nil, true)
end

function ComposeRuntime:OnSessionStop()
    if self.toolbar then self.toolbar:Hide() end
    if type(_G.CloseDropDownMenus) == "function" then _G.CloseDropDownMenus() end
    if self.groupManager then self.groupManager:Hide() end
    if self.attachments then self.attachments:OnSessionClosed() end
    self.lastAttachmentAutoSend = nil
    self:_recordPendingNativeMail("UNKNOWN", {
        code = "INTERRUPTED_UNKNOWN", message = "邮箱关闭前未收到明确发送结果",
    })
    self.pendingNativeRecipient = nil
    if self.transaction then
        local state = self.transaction:GetState()
        local terminal = state == "SUCCEEDED" or state == "FAILED" or state == "UNKNOWN" or state == "CANCELLED"
        if not terminal then
            local snapshot = self.transaction:GetSnapshot()
            if snapshot and snapshot.dispatched then
                self.transaction:OnSendEvent("MAIL_CLOSED")
            else
                self.transaction:Cancel("MAIL_CLOSED")
            end
        end
    end
end

function ComposeRuntime:Enable(context)
    if self.enabled then return true end
    self.enabled = true
    self.generation = context and context.generation or self.generation
    self:_ensureServices()
    if not self.recipients then
        self.enabled = false
        return nil, newError("RECIPIENT_STORE_UNAVAILABLE", "收件人仓储尚未初始化")
    end
    self:_rememberCurrentAlt()
    self.compose = Mail.ComposeController.New({
        locale = _G.GetLocale and _G.GetLocale() or "zhCN",
        config = self:_config(), recipientRepository = self.recipients,
    })
    local session = self:_session()
    if session then
        session:Register(self, {
            OnStart = function() self:OnSessionStart() end,
            OnStop = function() self:OnSessionStop() end,
            Cancel = function() self:OnSessionStop() end,
        })
    end
    local compat = self:_compat()
    if compat then
        compat:RegisterSendLifecycle(self, function(event, ...) self:OnSendEvent(event, ...) end)
        compat:RegisterEventListener(self, function(event, ...) self:OnWoWEvent(event, ...) end)
    end
    self:_ensureUI()
    if session and session:IsOpen() then self:OnSessionStart() elseif self.toolbar then self.toolbar:Hide() end
    return true
end

function ComposeRuntime:BeginDisable()
    if self.toolbar then self.toolbar:Hide() end
    if self.transaction then self.transaction:OnDrain("MODULE_DISABLED") end
    return true
end

function ComposeRuntime:Disable()
    if not self.enabled then return true end
    self.enabled = false
    local session = self:_session()
    if session then session:Unregister(self) end
    local compat = self:_compat()
    if compat then compat:UnregisterOwner(self) end
    if self.toolbar then self.toolbar:Hide() end
    self.generation = self.generation + 1
    return true
end

Mail.ComposeRuntimeClass = ComposeRuntime
Mail.ComposeRuntime = Mail.ComposeRuntime or ComposeRuntime.New()
if Mail.RegisterRuntimeModule then Mail:RegisterRuntimeModule("compose", Mail.ComposeRuntime, 50) end

return ComposeRuntime
