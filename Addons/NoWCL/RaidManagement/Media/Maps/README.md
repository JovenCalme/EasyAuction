# 团战管理地图素材规范

## 房间底图原则

插件展示的 Boss 房间底图必须保留可辨认的真实游戏场地纹理和几何结构。新增地图时统一使用以下流程：

> 固定规范：太阳井五张底图以 Wowhead 的带真实游戏场景俯视战术截图为几何与纹理参考，去除人物、文字和战术标记后生成本地干净底图。今后新增 Boss 房间底图一律优先沿用这条 Wowhead 来源与清理流程；找不到同类截图时，必须在本目录记录替代来源和采用理由。

1. 优先从对应 Boss 的 Wowhead 攻略中寻找带真实游戏场景的俯视战术截图。
2. 以截图中的房间轮廓、入口方向、地面纹理和固定地标为参考。
3. 去除人物、姓名、文字、箭头、职责图标、范围色块和其他战术标记。
4. 必要时使用图像生成工具清理或重绘，但不得改变影响站位判断的房间几何和固定地标。
5. 输出为插件本地干净底图；动漫化等风格处理只能改变表现，不能改变地图结构。

战术分区、个人站位、集合点、危险区和移动路线必须由 UI 作为独立覆盖层绘制，不能烘焙进底图。Rhinx、专业攻略和 Warcraft Logs Replay 用于验证这些覆盖层，不取代真实纹理底图。

## 太阳井基准

当前五张太阳井底图以 Wowhead 的五张真实场景俯视截图为参考，清理重绘为本地 `512x512` 底图：

| 首领房间 | Wowhead 参考图 | 本地文件 |
|---|---|---|
| 卡雷苟斯 | https://wow.zamimg.com/uploads/screenshots/normal/1259804.jpg | `sunwell-apex-point.png` |
| 布鲁塔卢斯、菲米丝共用场地 | https://wow.zamimg.com/uploads/screenshots/normal/1259826.jpg | `sunwell-dead-scar.png` |
| 艾瑞达双子 | https://wow.zamimg.com/uploads/screenshots/normal/1259945.jpg | `sunwell-witch-sanctum.png` |
| 穆鲁 | https://wow.zamimg.com/uploads/screenshots/normal/1260007.jpg | `sunwell-shrine-eclipse.png` |
| 基尔加丹 | https://wow.zamimg.com/uploads/screenshots/normal/1260224.jpg | `sunwell-sunwell.png` |

World of MapCraft 和副本分层地图只用于复核房间层级、入口方向与相对位置，不作为可直接替代上述房间底图的素材。

## 太阳井首领标记

P5 地图中的首领标记不再共用通用技能图标。以下 NPC ID 与 creature display ID 取自对应 Wowhead WotLK NPC 页面，运行时由客户端 `SetPortraitTextureFromCreatureDisplayID` 生成标准首领头像；因此无需额外打包头像图片。

| 首领 | Wowhead NPC | Display ID |
|---|---|---:|
| 卡雷苟斯 | https://www.wowhead.com/wotlk/npc=24850 | 23345 |
| 布鲁塔卢斯 | https://www.wowhead.com/wotlk/npc=24882 | 22711 |
| 菲米丝 | https://www.wowhead.com/wotlk/npc=25038 | 22838 |
| 萨洛拉丝 | https://www.wowhead.com/wotlk/npc=25165 | 23177 |
| 奥蕾塞丝 | https://www.wowhead.com/wotlk/npc=25166 | 23334 |
| 穆鲁 | https://www.wowhead.com/wotlk/npc=25741 | 23404 |
| 基尔加丹 | https://www.wowhead.com/wotlk/npc=25315 | 23200 |
