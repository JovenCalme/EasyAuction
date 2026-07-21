# EasyAuction 购物清单第三方导入接口

本文档面向第三方插件作者，说明如何通过 EasyAuction 的公开 API 一键创建、合并或替换购物清单。

推荐优先使用结构化 API；文本导入格式主要用于跨插件复制、导出文件或人工粘贴。

## 1. API 入口

EasyAuction 加载后会暴露全局对象：

```lua
EasyAuctionAPI.ShoppingLists.v1
```

建议第三方插件在 `PLAYER_LOGIN`、EasyAuction 的 `ADDON_LOADED` 后，或真正需要导入时再读取该对象。
如声明了 `OptionalDeps: EasyAuction`，你的插件加载时该对象通常已经可用。

```lua
local function GetShoppingAPI()
    local root = _G.EasyAuctionAPI
    local shopping = type(root) == "table" and root.ShoppingLists or nil
    local api = type(shopping) == "table" and shopping.v1 or nil

    if type(api) ~= "table"
            or api.__contract ~= "EasyAuction.ShoppingLists"
            or api.__major ~= 1
            or api.__owner ~= "EasyAuction" then
        return nil
    end
    for _, method in ipairs({
        "GetCapabilities", "Create", "Merge", "Replace", "ImportText",
        "ExportText", "ExportDisplayText", "GetList", "GetLists",
        "RegisterCallback", "UnregisterCallback",
    }) do
        if type(api[method]) ~= "function" then return nil end
    end
    return api
end
```

如你的插件不是强依赖 EasyAuction，建议在 `.toc` 中声明：

```toc
## OptionalDeps: EasyAuction
```

## 2. 返回值约定

公开方法使用 `api.Method(...)` 点调用，不要使用 `api:Method(...)` 冒号调用。所有方法均返回 table：

| 方法 | 参数 | 成功结果 |
| --- | --- | --- |
| `GetCapabilities` | 无 | 版本、限制、支持格式和变更令牌 |
| `Create` | `payload` | `list` |
| `Merge` | `listID, payload` | `list` |
| `Replace` | `listID, payload` | `list` |
| `ImportText` | `text, options?` | `list` |
| `ExportText` | `listID` | `text`，规范 TSV 格式 |
| `ExportDisplayText` | `listID` | `text`，适合复制的 pipe 格式 |
| `GetList` | `listID` | `list, changeToken` |
| `GetLists` | 无 | `lists, changeToken` |
| `RegisterCallback` | `listenerID, callback` | `replaced` |
| `UnregisterCallback` | `listenerID` | `removed` |

成功：

```lua
{
    ok = true,
    list = {
        id = "L1",
        name = "药水清单",
        items = {
            [13444] = {
                itemID = 13444,
                itemName = "特效法力药水",
                plannedQuantity = 20,
            },
        },
    },
}
```

失败：

```lua
{
    ok = false,
    code = "PAYLOAD_INVALID",
    message = "Shopping list payload contains invalid items",
    errors = {
        { index = 1, code = "ITEM_UNRESOLVED", field = "item" },
    },
}
```

请始终检查 `result.ok`，不要假设导入一定成功。
传入数据会被复制，成功结果也是独立快照；修改返回 table 不会直接修改 EasyAuction 数据。

## 3. 推荐方式：结构化一键导入

### 3.1 创建新清单

```lua
local api = GetShoppingAPI()
if not api then
    print("EasyAuction 购物清单 API 不可用")
    return
end

local result = api.Create({
    name = "团本消耗补给",
    items = {
        { itemID = 13444, plannedQuantity = 20 },
        { itemID = 13446, plannedQuantity = 10 },
        { item = "厚符文布绷带", plannedQuantity = 40 },
    },
})

if result.ok then
    print("已创建 EasyAuction 购物清单：" .. result.list.name)
else
    print("创建失败：" .. tostring(result.code))
end
```

字段说明：

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `name` | string | 是 | 清单名称 |
| `items` | array | 否 | 物品条目数组 |
| `items[].itemID` | number | 与 `item` 二选一 | 物品 ID，最稳定 |
| `items[].item` | number/string | 与 `itemID` 二选一 | 可传物品 ID、物品名或物品链接；成对 ASCII 双引号会作为输入包装去除 |
| `items[].plannedQuantity` | number | 是 | 计划购买数量，正整数 |

同一个 payload 内重复物品会自动合并数量。
名称冲突时会自动追加 ` (2)`、` (3)` 等后缀；如原名称已达到字节上限，会按 UTF-8 字符边界缩短前缀，为后缀预留空间。

### 3.2 合并到已有清单

适合第三方插件提供“一键追加到当前/指定 EasyAuction 清单”。

```lua
local api = GetShoppingAPI()
local listID = "L1"

local result = api.Merge(listID, {
    items = {
        { itemID = 2835, plannedQuantity = 100 },
        { itemID = 2840, plannedQuantity = 20 },
    },
})

if not result.ok then
    print("合并失败：" .. tostring(result.code))
end
```

合并规则：

- 已存在物品：计划数量累加。
- 不存在物品：新增条目。
- `payload.name` 会被忽略，清单名称不变。

### 3.3 替换已有清单

适合“用第三方插件的数据重新生成整张清单”。

```lua
local api = GetShoppingAPI()
local listID = "L1"

local result = api.Replace(listID, {
    name = "专业冲级材料",
    items = {
        { itemID = 2835, plannedQuantity = 100 },
        { itemID = 2836, plannedQuantity = 80 },
    },
})

if result.ok then
    print("已替换清单：" .. result.list.name)
else
    print("替换失败：" .. tostring(result.code))
end
```

替换规则：

- 清空目标清单原有物品。
- 使用 payload 中的新物品集合。
- `name` 必填，并会更新清单名称。

## 4. 获取和选择目标清单

```lua
local api = GetShoppingAPI()
local result = api.GetLists()

if result.ok then
    for _, list in ipairs(result.lists) do
        print(list.id, list.name)
    end
end
```

获取单个清单：

```lua
local result = api.GetList("L1")
if result.ok then
    print(result.list.name)
end
```

## 5. 文本导入格式

公开 API 提供两种导出：

```lua
local canonical = api.ExportText(listID)         -- 规范 TSV，适合机器保存和稳定比较
local display = api.ExportDisplayText(listID)    -- pipe 格式，适合 EditBox 和剪贴板

if display.ok then
    print(display.text)
end
```

两者成功时均返回 `{ ok = true, text = "..." }`，并且都可以交给 `ImportText`。如果你的插件需要生成可复制的文本，推荐使用无制表符的可读格式：

```text
EASYAUCTION_SHOPPING_LIST|1
LIST|团本消耗补给
ITEM|13444|20
ITEM|13446|10
```

格式说明：

| 行类型 | 格式 | 说明 |
| --- | --- | --- |
| Header | `EASYAUCTION_SHOPPING_LIST|1` | 固定头和版本 |
| List | `LIST|清单名称` | 清单名称 |
| Item | `ITEM|物品ID|数量` | 物品 ID 和计划购买数量 |

转义规则：

- `\` 写作 `\\`
- 换行写作 `\n`
- 回车写作 `\r`
- 制表符写作 `\t`
- 竖线写作 `\|`

文本导入示例：

```lua
local api = GetShoppingAPI()

local text = table.concat({
    "EASYAUCTION_SHOPPING_LIST|1",
    "LIST|团本消耗补给",
    "ITEM|13444|20",
    "ITEM|13446|10",
}, "\n")

local result = api.ImportText(text, {
    mode = "create",
})

if result.ok then
    print("导入完成：" .. result.list.name)
else
    print("导入失败：" .. tostring(result.code))
end
```

`ImportText` 也兼容旧 TSV 格式：

```text
EASYAUCTION_SHOPPING_LIST	1
LIST	团本消耗补给
ITEM	13444	20
```

但 TSV 中的真实制表符在游戏输入框里可能显示成乱码字符，因此 UI 和第三方复制文本建议使用 `|` 格式。
从 WoW `EditBox` 粘贴时，字面竖线可能变为 `||`；`ImportText` 会识别并兼容这种形式。

## 6. ImportText 的模式

```lua
api.ImportText(text, {
    mode = "create",  -- create / merge / replace
    listID = "L1",    -- merge/replace 时需要
})
```

| mode | 说明 |
| --- | --- |
| `create` | 创建新清单；名称冲突时自动生成唯一名称 |
| `merge` | 合并到 `listID` 指定清单 |
| `replace` | 替换 `listID` 指定清单 |

## 7. 能力查询

```lua
local caps = api.GetCapabilities()
if caps.ok then
    print(caps.schemaVersion)
    print(caps.maxLists)
    print(caps.maxItemsPerList)
end
```

当前能力字段：

| 字段 | 说明 |
| --- | --- |
| `schemaVersion` | 购物清单数据版本 |
| `maxLists` | 最大清单数量 |
| `maxItemsPerList` | 单清单最大物品数量 |
| `maxQuantity` | 单个物品支持的最大计划数量 |
| `maxNameBytes` | 清单名称最大 UTF-8 字节数 |
| `maxImportBytes` | 文本导入最大字节数 |
| `importModes` | 支持的文本导入模式 |
| `exportFormats` | 支持的导出格式：`tsv`、`pipe` |
| `changeToken` | 清单变更令牌 |

## 8. 监听清单变化

```lua
local api = GetShoppingAPI()

local registered = api.RegisterCallback("MyAddonShoppingSync", function(payload)
    -- payload 只包含 changeToken 和 schemaVersion，不包含清单正文。
    local latest = api.GetLists()
    if latest.ok then
        print("EasyAuction 购物清单已变化", payload.changeToken, #latest.lists)
    end
end)

if not registered.ok then
    print("监听注册失败：" .. tostring(registered.code))
end

-- 不再需要时注销
api.UnregisterCallback("MyAddonShoppingSync")
```

注意：

- 回调中不要再次调用会修改购物清单的 API，避免重入修改。
- 回调负载为 `{ changeToken = number, schemaVersion = number }`；需要最新数据时调用 `GetLists` 或 `GetList`。
- 相同 `listenerID` 会替换之前的回调，注册结果的 `replaced` 会反映这一点。
- 如果你的插件只做一键导入，不需要注册回调。

## 9. 常见错误码

| code | 常见原因 |
| --- | --- |
| `NOT_READY` | EasyAuction 存储未初始化 |
| `INVALID_PAYLOAD` | payload 不是 table |
| `PAYLOAD_INVALID` | items 不是连续数组、物品无法解析或数量非法 |
| `INVALID_NAME` | 清单名称为空或超长 |
| `NAME_EXISTS` | 替换清单时目标名称与其他清单冲突 |
| `LIST_NOT_FOUND` | 指定 listID 不存在 |
| `LIST_LIMIT` | 清单数量已达到上限 |
| `ITEM_LIMIT` | 超过单清单物品上限 |
| `INVALID_QUANTITY` | 数量无效，或合并后的数量超过上限 |
| `IMPORT_INVALID` | 文本格式错误 |
| `IMPORT_TOO_LARGE` | 文本超过大小限制 |
| `INVALID_IMPORT_MODE` | 文本导入模式不是 create、merge 或 replace |
| `UNSUPPORTED_VERSION` | 文本版本不受支持 |
| `INVALID_CALLBACK` | 监听 ID 为空或回调不是 function |
| `BUSY` | 在变更回调或另一事务执行期间尝试修改数据 |
| `ID_EXHAUSTED` / `CHANGE_TOKEN_EXHAUSTED` | 内部 ID 或变更令牌达到安全整数上限 |
| `STORAGE_INVALID` / `UNSUPPORTED_SCHEMA` | EasyAuction 本地购物清单存储损坏或版本不兼容 |

如果 `GetShoppingAPI()` 返回 nil，表示 EasyAuction 未加载、公开 API 不完整，或全局命名空间被不兼容对象占用。`API_VERSION_CONFLICT` 和 `API_NAMESPACE_CONFLICT` 是 EasyAuction 内部安装状态，不会由一个已成功取得的官方 v1 对象返回。

## 10. 一键导入完整示例

下面示例会优先合并到同名清单；如果没有找到同名清单，就创建新清单。

```lua
local function GetShoppingAPI()
    local root = _G.EasyAuctionAPI
    local shopping = type(root) == "table" and root.ShoppingLists or nil
    local api = type(shopping) == "table" and shopping.v1 or nil
    if type(api) ~= "table"
            or api.__contract ~= "EasyAuction.ShoppingLists"
            or api.__major ~= 1
            or api.__owner ~= "EasyAuction" then return nil end
    for _, method in ipairs({ "GetCapabilities", "Create", "Merge", "GetLists" }) do
        if type(api[method]) ~= "function" then return nil end
    end
    return api
end

local function FindListByName(api, name)
    local result = api.GetLists()
    if not result.ok then return nil, result end
    for _, list in ipairs(result.lists or {}) do
        if list.name == name then
            return list
        end
    end
end

function MyAddon_ImportToEasyAuction()
    local api = GetShoppingAPI()
    if not api then
        print("EasyAuction 购物清单 API 不可用")
        return
    end

    local name = "MyAddon 推荐采购"
    local payload = {
        name = name,
        items = {
            { itemID = 2835, plannedQuantity = 100 },
            { itemID = 2840, plannedQuantity = 40 },
            { item = "劣质的石头", plannedQuantity = 100 },
        },
    }

    local existing = FindListByName(api, name)
    local result
    if existing then
        result = api.Merge(existing.id, payload)
    else
        result = api.Create(payload)
    end

    if result.ok then
        print("已导入 EasyAuction 购物清单：" .. result.list.name)
    else
        print("导入 EasyAuction 购物清单失败：" .. tostring(result.code))
    end
end
```

## 11. 最佳实践

- 优先传 `itemID`，避免物品名因本地缓存或多语言导致解析失败。
- 如果必须传物品名，请确保客户端已经见过该物品，或同时提供物品链接。
- `plannedQuantity` 必须是正整数。
- 大批量导入前读取 `GetCapabilities()`，不要硬编码名称、数量或条目上限。
- 结构化 API 比文本导入更适合插件间自动集成。
- 文本导入适合用户复制、导出文件或跨插件剪贴板场景。
- 第三方插件不要直接写入 `EasyAuctionDB`，应始终通过公开 API。
