# 更新日志 / Changelog

## 简体中文

### 3.3.3 (2026-07-25)

- 收件箱和邮包新增“可退 / 转寄”提示及“闪退”按钮，可在确认邮件、附件、金币和到期统计后批量退回当前可退邮件
- 闪寄更加稳定：修复公会名单刷新问题，默认显示团队并隐藏自己，自定义组补充好友名单
- 优化批量邮寄金额统计和确认窗口，清楚显示邮资与总支出，核对信息更方便

### 3.3.2 (2026-07-24)

- 修复闪收选择“全部”时遗漏邮件金币的问题，现在会同时显示物品和金币
- 修复同服收件人自动附加服务器后缀、导致发件前需要额外确认的问题；跨服收件人仍保留服务器名
- 修复闪寄批量金币邮件第一封成功后，第二封可能提示 `OUTBOUND_BUSY` 并暂停的问题；
- 发件箱新增`Alt+左键`自动填入并一键发送所点击的物品，可在设置中开启，默认关闭；
- 发件箱新增`Ctrl+左键`自动将点击的相同 itemID 的所有可邮寄物品填入到当前邮件；

### 3.3.0 (2026-07-23)

- 新增 EasyAuction 邮箱助手，可在插件设置中随时开启或关闭
- 新增“邮包”页面，可自动整理同类物品，并支持搜索、金币汇总、到期提醒和滚动浏览
- 付款取件邮件继续通过游戏原生收件箱处理，避免整理邮件时误付金币
- 发件箱新增最近邮寄、联系人、小号、好友、公会成员和自定义分组名单
- 新增收件人管理、用户分组和黑名单，联系人维护更加方便
- 新增快捷附件分类，可一键放入矿石、草药、布料、消耗品等常用物品
- 新增批量金币邮寄，可多选收件人、自动计算总金额并查看每个人的发送结果
- 新增批量发送记录和失败重试，已经发送成功的角色不会被重复发送
- 检测到 Postal 或 InboxMailBag 时，可选择继续使用、关闭 EasyAuction 邮箱助手，或直接禁用冲突插件并重新载入界面
- 优化邮箱布局和页面切换，修复尺寸、重叠、名单显示及金币提示问题

### 3.2.9 (2026-07-21)

- 大幅加快价格库打开速度：多次扫描后再打开价格库，不再卡好几秒才弹出
- 浏览拍卖行更流畅：搜索、翻页时插件后台处理做了合并优化，减少掉帧
- 数据清理改为每天最多一次，扫描开始前不再因清理旧数据而卡顿
- 修复全量扫描后可能存下"物品名为空"的无效记录，现在自动拦截写入，已有脏数据会在每日清理时移除
- 修正待售物品列表及在售物品列表显示框体尺寸

### 3.2.7 (2026-07-19)

- 修复全量扫描超过 5 秒时，正常结果事件与超时兜底可能重复启动扫描和保存任务的问题
- 全量扫描加入会话失效保护，拍卖行关闭后不再执行残留的批处理、物品加载或保存回调
- 隔离全量扫描留下的拍卖快照，避免扫描完成后迟到事件重复遍历巨量结果导致游戏卡顿或假死

### 3.2.5 (2026-07-19)

- 修复购物清单导出文本重新粘贴时提示表头格式错误的问题
- 购物清单物品输入支持带双引号的物品名，例如 "铜矿石"
- 购物清单新增"圆圆的笔记本"下载入口，可快速复制插件下载地址
- 完善购物清单第三方 API：新增安全复制格式导出，补齐能力限制、回调契约和接口文档
- 修复文本导入绕过物品数量上限，以及超长清单名称自动重名后无法重新加载的问题
- 修复购物清单本次购买进度、库存和缺口数据刷新不准确的问题
- 修复 EasyAuction 设置页层级错误，避免窗口遮挡和交互异常

### 3.2.4 (2026-07-19)

- 移除买入助手模块
- 新增购物清单：支持多清单、物品名/ID 添加、导入导出和第三方插件导入接口
- 新增购物清单详情：显示采购进度、背包库存、缺口成本和本次购买明细
- 修复弹窗错误，避免影响系统其他弹窗样式

### 3.2.2 (2026-07-08)

- 修改界面缩放默认值改为 100%
- 修复闪卖页放入物品后图标过大、超出边框的问题

### 3.2.1 (2026-07-03)

- 默认界面改为"暴雪默认风格"，更接近游戏原生窗口
- 主题切换改成下拉选择，不用再一下一下循环切换
- 优化金币账单和价格走势窗口：账单金额更稳，走势窗口不会被价格库挡住
- 修正一些界面细节：按钮选中更明显，涨跌榜表头更清楚，低价价格显示更准确

### 3.2.0 (2026-07-02)

- 新增 EasyAuction Pro 功能：策略上架队列、策略模板、策略组、单物品/分类绑定和建议价计算
- Pro 买入助手加入补货扫描和策略狙击，可按库存目标、最高买入价、风险限制和策略低价规则筛选当前浏览结果
- Pro 运营维护与账本增强：辅助检查我的拍卖、低于底价或被压价的条目，并记录轻量成交、购买、流拍汇总
- 购买风控确认弹窗会明确显示本次一口价，避免超过警戒线时确认框金额为空

---

## English

### 3.3.3 (2026-07-25)

- Added Returnable / Forward indicators and a confirmed bulk-return action to the native inbox and Mail Bag
- Improved Bulk Mail stability, guild roster refreshes, Raid defaults, self filtering, and Friends access
- Improved bulk-mail cost summaries and confirmation layout with clear postage and total spending

### 3.3.2 (2026-07-24)

- Fixed the All inbox filter omitting attached gold; it now includes both items and money
- Fixed same-realm recipients receiving an unnecessary realm suffix and confirmation prompt; cross-realm names remain fully qualified
- Fixed bulk gold mail pausing with `OUTBOUND_BUSY` after the first successful message
- Added optional `Alt+Left Click` quick attachment and one-click sending to the outbox; disabled by default
- Added `Ctrl+Left Click` to attach every mailable bag item with the same item ID to the current message

### 3.3.0 (2026-07-23)

- Added an EasyAuction mail assistant that can be enabled or disabled from addon settings
- Added a Mail Bag page that organizes matching items and supports search, money summaries, expiry reminders, and scrolling
- Kept COD mail in Blizzard's native inbox to help prevent accidental payments
- Added quick recipient lists for recent mail, contacts, alts, friends, guild members, and custom groups
- Added recipient management, custom groups, and a sending blacklist
- Added quick attachment categories for commonly mailed items
- Added bulk gold mailing with multi-select recipients, automatic total calculation, and per-recipient results
- Added saved bulk-mail history and safe retry for failed recipients without resending successful mail
- Added a clear choice to continue, disable EasyAuction Mail, or disable the conflicting Postal/InboxMailBag add-on and reload
- Improved mailbox layout and fixed sizing, overlap, roster display, and money hint issues

### 3.2.9 (2026-07-21)

- Significantly improved price database opening speed
- Smoother auction browsing with merged background processing
- Data cleanup now runs at most once per day
- Fixed invalid empty item name records from full scan
- Fixed display size for sell list and my auctions list

### 3.2.7 (2026-07-19)

- Fixed duplicate scan/save tasks when full scan exceeds 5 seconds
- Added session invalidation protection for full scan
- Isolated auction snapshots to prevent late events causing lag

### 3.2.5 (2026-07-19)

- Fixed shopping list export text re-paste format error
- Added support for quoted item names in shopping lists
- Added "圆圆笔记本" download entry for shopping lists
- Improved shopping list third-party API
- Fixed text import bypassing quantity limits
- Fixed purchase progress and inventory refresh issues
- Fixed settings frame level error

### 3.2.4 (2026-07-19)

- Removed buy assistant module
- Added shopping lists with import/export
- Added shopping list details view
- Fixed popup styling issues

### 3.2.2 (2026-07-08)

- Changed default UI scale to 100%
- Fixed oversized item icon in quick sell panel

### 3.2.1 (2026-07-03)

- Changed default theme to "Blizzard Default Style"
- Changed theme switch to dropdown selection
- Improved gold ledger and price chart windows
- Fixed UI details

### 3.2.0 (2026-07-02)

- Added EasyAuction Pro features: strategy posting queue, templates, groups
- Pro buy assistant with restock scan and strategy sniper
- Pro operations maintenance and ledger enhancements
- Fixed purchase risk confirmation popup amount display
