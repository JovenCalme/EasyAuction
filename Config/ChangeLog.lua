local ADDON_VERSION = "3.3.5"
local EAStyle = _G.EasyAuctionStyle

local function EA_ChangelogSkinFrame(frame, role)
    if EAStyle then
        EAStyle:Skin(frame, role or "panel")
    elseif frame and frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        frame:SetBackdropColor(0.10, 0.10, 0.13, 1)
        frame:SetBackdropBorderColor(0.28, 0.30, 0.34, 1)
    end
    return frame
end

local function EA_ChangelogSkinText(fs, role)
    if EAStyle then
        EAStyle:SkinText(fs, role)
    elseif fs then
        if role == "accent" then
            fs:SetTextColor(0.02, 0.71, 0.83)
        elseif role == "muted" then
            fs:SetTextColor(0.63, 0.63, 0.67)
        else
            fs:SetTextColor(0.96, 0.96, 0.96)
        end
    end
    return fs
end

local function EA_ChangelogSkinButton(button)
    if EAStyle then
        EAStyle:SkinButton(button)
    end
    local fs = button and button:GetFontString()
    if fs then
        fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
        fs:ClearAllPoints()
        fs:SetPoint("CENTER")
    end
    return button
end

local function EA_ChangelogCloseButton(button)
    button:SetSize(22, 22)
    button:SetText("\195\151")
    EA_ChangelogSkinButton(button)
    local fs = button:GetFontString()
    if fs then
        fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 15, "")
    end
    return button
end

local function EA_ChangelogLine(parent, alpha)
    local tex = parent:CreateTexture(nil, "OVERLAY")
    tex:SetTexture("Interface\\Buttons\\WHITE8X8")
    tex:SetHeight(1)
    if EAStyle then
        EAStyle:OnTheme(function(p)
            tex:SetColorTexture(p.border[1], p.border[2], p.border[3], alpha or 0.85)
        end)
    else
        tex:SetColorTexture(0.28, 0.30, 0.34, alpha or 0.85)
    end
    return tex
end

local UPDATE_NOTES = {
    {
        version = "3.3.5",
        date = "2026-07-26",
        note = [[
- 发件箱新增“记住上个收件人”，发送成功后自动保留名字，连续邮寄更省事。
- 新增“背包估值”，按价格库扫描价、卖店价和分解价值汇总当前背包，并列出高价值及无价格物品。
- 优化背包估值金额与入口布局，可从价格库和待售库存快速打开。
- 背包新增估值图标，指向估值入口可快速查看总额和高价值物品。
- 背包估值金额显示更紧凑，单价和小计使用金币图标，顶部估值保持小字号单行显示。
- 修正顶部估值标签与数值对齐，五项统计上下居中一致。
- 邮寄记录现在会保存普通和批量邮件，金额与邮资改用金银铜图标显示。
- 带附件的邮寄记录新增简洁物品清单，清楚显示图标、名称和数量。
- 邮寄记录改为清晰表格布局，可按时间、类型、人数和结果快速浏览。
- 邮寄时间改用更小的单行字体，日期和时刻不再换行。
]],
    },
    {
        version = "3.3.4",
        date = "2026-07-26",
        note = [[
- 新增“闪退”，确认统计后可批量退回当前可退邮件。
- “可退 / 转寄”提示更清爽，只提醒真正需要处理的邮件。
]],
    },
    {
        version = "3.3.3",
        date = "2026-07-25",
        note = [[
- 收件箱和邮包新增“可退 / 转寄”提示及“闪退”按钮，可在确认邮件、附件、金币和到期统计后批量退回当前可退邮件。
- 闪寄更加稳定：修复公会名单刷新问题，默认显示团队并隐藏自己，自定义组补充好友名单。
- 优化批量邮寄金额统计和确认窗口，清楚显示邮资与总支出，核对信息更方便。
]],
    },
    {
        version = "3.3.2",
        date = "2026-07-24",
        note = [[
- 修复闪收选择“全部”时遗漏邮件金币的问题，现在会同时显示物品和金币。
- 修复同服收件人自动附加服务器后缀、导致发件前需要额外确认的问题；跨服收件人仍保留服务器名。
- 修复闪寄批量金币邮件第一封成功后，第二封可能提示 OUTBOUND_BUSY 并暂停的问题。
- 发件箱新增 Alt+左键自动填入并一键发送所点击的物品，可在设置中开启，默认关闭。
- 发件箱新增 Ctrl+左键自动将点击的相同 itemID 的所有可邮寄物品填入到当前邮件。
]],
    },
    {
        version = "3.3.0",
        date = "2026-07-23",
        note = [[
- 新增 EasyAuction 邮箱助手，可在插件设置中随时开启或关闭。
- 新增“邮包”页面：同类物品会自动整理到一起，并可搜索、查看金币和邮件到期时间；邮件较多时可以滚动浏览。
- 付款取件邮件仍在游戏原生收件箱中处理，避免在整理邮件时误付金币。
- 发件箱新增收件人名单，可快速选择最近邮寄、联系人、小号、好友、公会成员和自定义分组。
- 新增收件人管理，可创建分组、添加或删除联系人，并将不想发送邮件的角色加入黑名单。
- 新增快捷附件分类，可一键放入矿石、草药、布料、消耗品等常用物品。
- 新增批量金币邮寄，可从团队、公会、小号、好友或自定义分组中多选收件人，并自动计算需要发送的总金额。
- 批量邮寄会逐人显示发送结果，并保存发送记录；发送失败时可以确认名单后重试，不会再次发送给已经成功的角色。
- 检测到 Postal 或 InboxMailBag 时会显示简单提示，可选择继续使用、关闭 EasyAuction 邮箱助手，或直接禁用冲突插件并重新载入界面。
- 优化邮箱页面布局和切换效果，修复界面尺寸、控件重叠、名单显示和金币提示等问题。
]],
    },
    {
        version = "3.2.9",
        date = "2026-07-21",
        note = [[
- 大幅加快价格库打开速度：多次扫描后再打开价格库，不再卡好几秒才弹出。
- 浏览拍卖行更流畅：搜索、翻页时插件后台处理做了合并优化，减少掉帧。
- 数据清理改为每天最多一次，扫描开始前不再因清理旧数据而卡顿。
- 修复全量扫描后可能存下"物品名为空"的无效记录，现在自动拦截写入，已有脏数据会在每日清理时移除。
- 修正待售物品列表及在售物品列表显示框体尺寸。
]],
    },
    {
        version = "3.2.7",
        date = "2026-07-19",
        note = [[
- 修复全量扫描超过 5 秒时，正常结果事件与超时兜底可能重复启动扫描和保存任务的问题。
- 全量扫描加入会话失效保护，拍卖行关闭后不再执行残留的批处理、物品加载或保存回调。
- 隔离全量扫描留下的拍卖快照，避免扫描完成后迟到事件重复遍历巨量结果导致游戏卡顿或假死。
]],
    },
    {
        version = "3.2.5",
        date = "2026-07-19",
        note = [[
- 修复购物清单导出文本重新粘贴时提示表头格式错误的问题。
- 购物清单物品输入支持带双引号的物品名，例如 "铜矿石"。
- 购物清单新增“圆圆的笔记本”下载入口，可快速复制插件下载地址。
- 完善购物清单第三方 API：新增安全复制格式导出，补齐能力限制、回调契约和接口文档。
- 修复文本导入绕过物品数量上限，以及超长清单名称自动重名后无法重新加载的问题。
- 修复购物清单本次购买进度、库存和缺口数据刷新不准确的问题。
- 修复 EasyAuction 设置页层级错误，避免窗口遮挡和交互异常。
]],
    },
    {
        version = "3.2.4",
        date = "2026-07-19",
        note = [[
- 移除买入助手模块。
- 新增购物清单：支持多清单、物品名/ID 添加、导入导出和第三方插件导入接口。
- 新增购物清单详情：显示采购进度、背包库存、缺口成本和本次购买明细。
- 修复弹窗错误，避免影响系统其他弹窗样式。
]],
    },
    {
        version = "3.2.2",
        date = "2026-07-08",
        note = [[
- 修改界面缩放默认值改为 100%。
- 修复闪卖页放入物品后图标过大、超出边框的问题。
]],
    },
    {
        version = "3.2.1",
        date = "2026-07-03",
        note = [[
- 默认界面改为“暴雪默认风格”，更接近游戏原生窗口。
- 主题切换改成下拉选择，不用再一下一下循环切换。
- 优化金币账单和价格走势窗口：账单金额更稳，走势窗口不会被价格库挡住。
- 修正一些界面细节：按钮选中更明显，涨跌榜表头更清楚，低价价格显示更准确。
]],
    },
    {
        version = "3.2.0",
        date = "2026-07-02",
        note = [[
- 新增 EasyAuction Pro 功能：策略上架队列、策略模板、策略组、单物品/分类绑定和建议价计算，适合按不同物品类型自动生成上架方案。
- Pro 买入助手加入补货扫描和策略狙击，可按库存目标、最高买入价、风险限制和策略低价规则筛选当前浏览结果。
- Pro 运营维护与账本增强：辅助检查我的拍卖、低于底价或被压价的条目，并记录轻量成交、购买、流拍汇总。
- 购买风控确认弹窗会明确显示本次一口价，避免超过警戒线时确认框金额为空。
]],
    },
    {
        version = "3.1.1",
        date = "2026-06-27",
        note = [[
- 本次升级后，检测到已有 EasyAuction 数据时会一次性询问是否重置数据库；选择“否”后继续使用现有数据且不再提示。
]],
    },
    {
        version = "3.1.0",
        date = "2026-06-27",
        note = [[
- 新增“经典主题”，复刻旧版 EasyAuction 暗底紫框、金色强调、系统按钮和列表高亮风格。
- 放大闪卖界面价格显示，提高可读性。
]],
    },

    {
        version = "3.0.8",
        date = "2026-06-26",
        note = [[
- 浏览列表“买/竞”按钮新增悬停提示，说明点击后的购买或竞价动作。
- “竞”按钮新增竞价确认弹窗，确认后才会出价，并修复确认金额显示为空的问题。
- 优化确认弹窗样式，增加描边和标题分隔线。
]],
    },

    {
        version = "3.0.7",
        date = "2026-06-26",
        note = [[
- 修复全局扫描被意外中止后，导致打印"processItemData 返回: 无效数据或扫描已停止"的问题。
]],
    },

    {
        version = "3.0.4",
        date = "2026-06-25",
        note = [[
- 新增金币账单弹窗，统计角色金币数据、走势图，包括日均、单项、拍卖/购买/利润摘要
- 修复旧版本升级后旧 UI 字段不兼容导致闪卖面板错位的问题，兼容旧数据中闪卖区段全部关闭或价格分布区被折叠的异常组合。
]],
    },

    {
        version = "2.8.7",
        date = "2026-06-21",
        note = [[
- 设置页新增“显示浏览买按钮”，可关闭浏览列表 EasyAuction 的“买”按钮
- 设置页新增“显示浏览竞按钮”，可关闭浏览列表 EasyAuction 的“竞”按钮
- 设置页新增“搜索框防污染”，可关闭拍卖行搜索框防污染/防限流提示与拦截
]],
    },

    {
        version = "2.8.6",
        date = "2026-06-12",
        note = [[
- 新增狙击页签，支持狙击目标列表、狙击结果与竞价结果查看
- 最近搜索与常用物品右键菜单新增加入狙击列表
- 新增竞价列表、继续竞价、浏览列表竞价按钮与最高竞价高亮
- 狙击设置支持分解价、卖店价检测与竞价折扣比例
- 引入输入框防污染脚本，源代码由“意难平”贡献
]],
    },

            {
        version = "2.8.5",
        date = "2026-04-23",
        note = [[
- 新增价格库分类管理，可按分类编辑、删除和重置物品清单
- 新增价格库数据导出，可按指定分类或全库导出 CSV 文本
- 新增扫描方式选择，支持全量扫描与分类扫描
- 打通常用物品清单，闪购页与价格库共用同一份“常用”数据
- 修正分类扫描 QueryAuctionItems 调用参数与分页等待节奏
- 修复闪卖页“本次价格分布”点价后预计利润未及时刷新的问题
]],
    },

            {
        version = "2.8.2",
        date = "2026-03-22",
        note = [[
- 按单价聚合拍卖记录，减少重复数据
- 支持配置历史记录保留天数、每小时聚合窗口
- 添加数据清理功能，自动移除过期记录
- 优化内存使用，减少常驻内存占用
- 改进重置数据库逻辑，支持多服务器数据管理
- 修正设置无法保存的问题
]],
    },

            {
        version = "2.7.6",
        date = "2026-02-11",
        note = [[
- 重构数据库结构为按服务器-阵营存储
- 修复全局扫描时的报错问题
- 若扫描超时，请切换为极简模式再进行全局扫描
]],
    }, 
            {
        version = "2.7.5",
        date = "2026-01-21",
        note = [[
- 修复自动填充上次拍卖物品和价格的问题
- 修复价格库界面，物品名错误匹配问题
- 新增分解概率显示选项， 控制是否显示物品分解概率
- 为小地图图标添加右键点击打开配置窗口功能
- 添加README文档，详细说明插件功能和使用方法
]],
    }, 
            {
        version = "2.7.1",
        date = "2026-01-20",
        note = [[
- 优化分解收益计算逻辑
- 鼠标提示中，添加选矿和研磨收益显示
- 插件设置中，添加选矿和研磨提示开关选项
- 修正自动填写价格逻辑，高亮当前选择的价格
- 价格数据库界面，矿石和草药类别显示选矿和研磨收益
]],
    },    
            {
        version = "2.6.9",
        date = "2026-01-20",
        note = [[
- 新增价格分布数据的时间过滤功能，只显示最近60秒内的数据
- 修正偶尔出现的物品名错误问题
]],
    },
{
        version = "2.6.6",
        date = "2026-01-19",
        note = [[
- 移除快速扫描模式及相关配置选项
- 增加原生卖店价显示开关配置
- 优化搜索界面鼠标提示
- 修复单体搜索模式下，物品ID匹配问题，聚合同id物品销售价格
- 补全插件运行库
]],
    },
            {
        version = "2.6.4",
        date = "2026-01-19",
        note = [[
- 修正鼠标提示
- 修正单体搜索时，同名不同ID物品的写入错误
]],
    },     
            {
        version = "2.6.1",
        date = "2026-01-18",
        note = [[
- 新增配置选项"历史价格显示"用于控制鼠标信息是否显示历史最低价
- 重构价格数据存储结构，移除冗余字段提升性能
]],
    }, 
            {
        version = "2.5.9",
        date = "2026-01-17",
        note = [[
- 新增交易历史查询功能
- 新增历史信息保存天数、保存条数修改功能，入口：插件设置-保留天数、保留条数
- 新增待售库存界面物品选中高亮
- 新增上架物品选中价格高亮显示
- 新增上架后自动选择背包同ID剩余物品功能
- 新增拍卖按钮宏命令 /click EasyAuctionStartBtn
- 保存用户上次选择的标签页，下次打开拍卖行恢复该标签
- 改进内存管理，增加垃圾回收调用
- 更新插件使用说明
- 修复拍卖框虚拟填充物品的清空问题
- 修复分类页历史价格处理逻辑
- 修复闪卖界面利润计算逻辑
]],
    },    
            {
        version = "2.5.7",
        date = "2026-01-16",
        note = [[
致谢网易DD网友 [暴躁蓝心] 修改提交

- 重构价格历史记录逻辑，优先使用每日最低价数据
- 改进拍卖行扫描功能，增加物品信息加载处理
- 修复拍卖框虚拟填充物品的清空问题，不需要手动清空虚拟填充物品
- 增加与Kiwi Farm等插件的兼容性优化
]],
    },
            {
        version = "2.5.5",
        date = "2026-01-13",
        note = [[
- 优化拍卖行界面布局和交互体验
- 优化价格库界面布局
- 优化价格走势界面布局
- 扩展外部接口，修正alatradeskill 数据获取错误
- 修复价格库数据在售数量获取错误问题
- 修复价格库价格分布界面显示错误问题
]],
    },
            {
        version = "2.5.3",
        date = "2026-01-09",
        note = [[
- 新增常用物品清单的导入导出功能，支持多角色同步
- 修复拍卖行扫描时的变量作用域问题
- 优化单体搜索时自动填写逻辑
- 在价格库列表中添加在售数列，显示当前拍卖行中该物品的数量
]],
    },
            {
        version = "2.5.1",
        date = "2026-01-09",
        note = [[
- 新增拍卖列表左键复制物品名称功能，可通过配置开关，设置入口：EasyAuctio设置--插件设置--在售列表左键复制
- 修复自动填充上次拍卖价格的逻辑，默认关闭该功能
- 调整部分UI元素位置和尺寸
]],
    },
            {
        version = "2.4.8",
        date = "2026-01-08",
        note = [[
- 新增自动填充上次拍卖价格功能，默认关闭，可在设置中开启。
  注意：该功能开启后，自动压价功能将失效。
- 移除待售列表左键点击复制功能。
]],
    },
        {
        version = "2.4.7",
        date = "2026-01-06",
        note = [[
- 添加窗口锁定/解锁功能，允许用户固定或移动拍卖行界面。
- 修复鼠标提示变量刷新问题，确保在鼠标悬停时显示准确的物品信息。
- 修复全服扫描时价格数据合并的问题。
- 调整商机发现界面UI元素的层级，确保正常显示和操作。
]],
    },
        {
        version = "2.4.6",
        date = "2026-01-06",
        note = [[
- 优化全局扫描功能，重构拍卖扫描逻辑
- 清理冗余代码
]],
    },    
    {
        version = "2.4.5",
        date = "2026-01-05",
        note = [[
- 新增UI缩放控制功能，支持50%-200%的缩放调节，
进入路径：设置--插件设置

- 添加更新日志弹窗，显示版本变更信息，
进入路径：设置--插件设置--更新日志

- 添加“周边插件”按钮，
进入路径：设置--插件设置--周边插件
]],
    },
    {
        version = "2.4.4",
        date = "2026-01-03",
        note = [[
- 优化价格走势界面，修复无数据连线错误
- 优化价格库界面，增加走势按钮
- 新增分类按钮高亮显示功能
- 添加极简模式按钮，支持快速禁用/恢复其他插件
- 优化分类页面逻辑，修复分页显示问题
- 调整宝石分类数据，增加新宝石类型
- 修复配置界面布局和文字对齐问题
- 修复拍卖行可用状态更新错误
]],
    },
}

local RELATED_ADDONS = {
    {
        name = "alaTradeSkill：时光服专业助手",
        install ="下载补丁，解压至\\World of Warcraft\\_classic_titan_\\Interface\\AddOns\\alaTradeSkill\\plugin 覆盖",
        url = "https://img.nga.178.com/attachments/mon_202601/03/axsjQkt4-hu41K1.zip"
    },
    {
        name = "Kiwi Farm：战利品收益记录",
        install ="下载插件，解压至\\World of Warcraft\\_classic_titan_\\Interface\\AddOns 覆盖",
        url = "https://img.nga.178.com/attachments/mon_202601/09/axsjQ991l-gngkK1u.zip"
    },
}

local function EnsureUpdateNotes()
    if not EasyAuctionDB then return end
    if not EasyAuctionDB.updateNotes then EasyAuctionDB.updateNotes = {} end
    local exists = {}
    for _, v in ipairs(EasyAuctionDB.updateNotes) do
        exists[v.version] = true
    end
    for _, v in ipairs(UPDATE_NOTES) do
        if not exists[v.version] then
            table.insert(EasyAuctionDB.updateNotes, v)
        end
    end

end

local function RaiseUpdateNotesFrame(frame)
    if not frame then return end
    local owner = _G.EasyAuctionConfigFrame
    local ownerLevel = owner and owner.GetFrameLevel and owner:GetFrameLevel() or 0
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(math.max(ownerLevel + 20, 220))
    frame:SetToplevel(true)
end

function ShowUpdateNotesPopup()
    if EasyAuctionUpdateNoteFrame then
        RaiseUpdateNotesFrame(EasyAuctionUpdateNoteFrame)
        EasyAuctionUpdateNoteFrame:Show()
        return
    end

    local f = CreateFrame("Frame", "EasyAuctionUpdateNoteFrame", UIParent, "BackdropTemplate")
    f:SetSize(540, 390)
    f:SetPoint("CENTER")
    RaiseUpdateNotesFrame(f)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetScript("OnShow", function(self)
        RaiseUpdateNotesFrame(self)
    end)
    EA_ChangelogSkinFrame(f, "window")

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText("EasyAuction 更新日志")
    title:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 15, "")
    EA_ChangelogSkinText(title, "accent")

    local subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetText("查看版本变更与功能修正")
    subtitle:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
    EA_ChangelogSkinText(subtitle, "muted")

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
    EA_ChangelogCloseButton(closeBtn)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    local underline = EA_ChangelogLine(f, 0.85)
    underline:SetPoint("TOPLEFT", 12, -52)
    underline:SetPoint("TOPRIGHT", -12, -52)

    local versionDateLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    versionDateLabel:SetPoint("TOPLEFT", 18, -66)
    versionDateLabel:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
    EA_ChangelogSkinText(versionDateLabel, "text")

    local versionDropDown = CreateFrame("Frame", "EasyAuctionUpdateNoteDropDown", f, "UIDropDownMenuTemplate")
    versionDropDown:SetPoint("TOPRIGHT", -116, -56)
    UIDropDownMenu_SetWidth(versionDropDown, 96)

    local contentBG = CreateFrame("Frame", nil, f, "BackdropTemplate")
    contentBG:SetPoint("TOPLEFT", 14, -92)
    contentBG:SetPoint("BOTTOMRIGHT", -14, 50)
    EA_ChangelogSkinFrame(contentBG, "plot")

    local scrollFrame = CreateFrame("ScrollFrame", nil, contentBG, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)
    local editBox = CreateFrame("EditBox", nil, scrollFrame, "BackdropTemplate")
    editBox:SetMultiLine(true)
    editBox:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
    editBox:SetTextColor(0.96, 0.96, 0.96)
    editBox:SetWidth(468)
    editBox:SetAutoFocus(false)
    editBox:EnableMouse(true)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    editBox:SetJustifyH("LEFT")
    editBox:SetTextInsets(4, 4, 2, 2)
    scrollFrame:SetScrollChild(editBox)

    local okBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    okBtn:SetSize(96, 24)
    okBtn:SetPoint("BOTTOM", 0, 14)
    okBtn:SetText("我知道了")
    EA_ChangelogSkinButton(okBtn)
    okBtn:SetScript("OnClick", function()
        f:Hide()
        if EasyAuctionDB then
            EasyAuctionDB.lastSeenVersion = ADDON_VERSION
        end
    end)

    local function SelectVersion(idx)
        local note = UPDATE_NOTES[idx]
        if note then
            UIDropDownMenu_SetText(versionDropDown, note.version)
            editBox:SetText(note.note or "")
            editBox:SetCursorPosition(0)
            local y, m, d = note.date:match("(%d+)%-(%d+)%-(%d+)")
            local zhDate = y and (y.."年"..m.."月"..d.."日") or (note.date or "")
            versionDateLabel:SetText(format("版本号：%s    更新日期：%s", note.version, zhDate))
        end
    end

    UIDropDownMenu_Initialize(versionDropDown, function(self, level, menuList)
        local info = UIDropDownMenu_CreateInfo()
        for i, v in ipairs(UPDATE_NOTES) do
            info.text = v.version
            info.func = function() SelectVersion(i) end
            info.checked = (UIDropDownMenu_GetText(versionDropDown) == v.version)
            UIDropDownMenu_AddButton(info)
        end
    end)

    SelectVersion(1)
end

function CheckShowUpdateNotes()
    --EnsureUpdateNotes()
    if EasyAuctionDB and EasyAuctionDB.lastSeenVersion ~= ADDON_VERSION then
        ShowUpdateNotesPopup()
    end
end

function ShowRelatedAddonsPopup()
    if EasyAuctionRelatedAddonsFrame then
        EasyAuctionRelatedAddonsFrame:Show()
        return
    end

    local f = CreateFrame("Frame", "EasyAuctionRelatedAddonsFrame", UIParent, "BackdropTemplate")
    f:SetSize(540, 390)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    EA_ChangelogSkinFrame(f, "window")

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 16, -14)
    title:SetText("周边插件")
    title:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 15, "")
    EA_ChangelogSkinText(title, "accent")

    local subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetText("支持调用 EasyAuction 数据库的扩展")
    subtitle:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
    EA_ChangelogSkinText(subtitle, "muted")

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
    EA_ChangelogCloseButton(closeBtn)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    local underline = EA_ChangelogLine(f, 0.85)
    underline:SetPoint("TOPLEFT", 12, -52)
    underline:SetPoint("TOPRIGHT", -12, -52)

    f:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local contentBG = CreateFrame("Frame", nil, f, "BackdropTemplate")
    contentBG:SetPoint("TOPLEFT", 14, -66)
    contentBG:SetPoint("BOTTOMRIGHT", -14, 50)
    EA_ChangelogSkinFrame(contentBG, "plot")

    local scrollFrame = CreateFrame("ScrollFrame", nil, contentBG, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 8, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(468)
    scrollFrame:SetScrollChild(scrollChild)
    
    local y = -4
    for i, addon in ipairs(RELATED_ADDONS) do
        local name = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        name:SetPoint("TOPLEFT", 0, y)
        name:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 13, "")
        name:SetText("插件名：" .. addon.name)
        EA_ChangelogSkinText(name, "accent")

        local install = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        install:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -4)
        install:SetWidth(468)
        install:SetWordWrap(true)
        install:SetJustifyH("LEFT")
        install:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
        install:SetText("安装方式：" .. (addon.install or ""))
        EA_ChangelogSkinText(install, "text")

        local urlLabel = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        urlLabel:SetPoint("TOPLEFT", install, "BOTTOMLEFT", 0, -4)
        urlLabel:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
        urlLabel:SetText("下载地址：")
        EA_ChangelogSkinText(urlLabel, "muted")

        local urlBtn = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
        urlBtn:SetPoint("LEFT", urlLabel, "RIGHT", 2, 0)
        urlBtn:SetSize(66, 20)
        urlBtn:SetText("点击复制")
        EA_ChangelogSkinButton(urlBtn)
        urlBtn.url = addon.url

        local urlEdit = CreateFrame("EditBox", nil, scrollChild, "BackdropTemplate")
        urlEdit:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
        urlEdit:SetTextColor(0.96, 0.96, 0.96)
        urlEdit:SetSize(286, 20)
        urlEdit:SetPoint("LEFT", urlBtn, "RIGHT", 6, 0)
        urlEdit:SetAutoFocus(true)
        urlEdit:Hide()
        urlEdit:SetTextInsets(4, 4, 0, 0)
        EA_ChangelogSkinFrame(urlEdit, "plot")
        urlEdit:SetScript("OnEscapePressed", function(self) self:Hide() end)
        urlBtn:SetScript("OnClick", function()
            urlEdit:SetText(urlBtn.url)
            urlEdit:Show()
            urlEdit:SetFocus()
            urlEdit:HighlightText()
        end)
        urlEdit:SetScript("OnEditFocusLost", function(self) self:Hide() end)

        local height = name:GetStringHeight() + install:GetStringHeight() + urlLabel:GetStringHeight() + 28
        y = y - height - 10
    end

    scrollChild:SetHeight(math.abs(y)+10)
    
    local okBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    okBtn:SetSize(96, 24)
    okBtn:SetPoint("BOTTOM", 0, 14)
    okBtn:SetText("关闭")
    EA_ChangelogSkinButton(okBtn)
    okBtn:SetScript("OnClick", function() f:Hide() end)
end
