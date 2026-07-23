local _, NoWCL = ...
local RM = NoWCL.RaidManagement
local function range(first, last)
local out = {}
for index = first, last do out[#out + 1] = index end
return out
end
local function slots(width, height, points)
local out = {}
for index, point in ipairs(points) do
out[index] = {
id = string.format("p%02d", index),
index = index,
x = math.max(0.05, math.min(0.95, point[1] / width)),
y = math.max(0.05, math.min(0.95, 1 - point[2] / height)),
}
end
return out
end
local function rotatedSlots(width, height, points)
local rotated={}
for index,point in ipairs(points) do rotated[index]={width-point[1],height-point[2]} end
return slots(width,height,rotated)
end
local function marker(width, height, x, y, label, kind, icon)
return {
x = math.max(0.02, math.min(0.98, x / width)),
y = math.max(0.02, math.min(0.98, 1 - y / height)),
label = label,
kind = kind,
icon = icon,
}
end
local function rotatedMarker(width, height, x, y, label, kind, icon)
return marker(width,height,width-x,height-y,label,kind,icon)
end
local ICON = {
BOSS = "Interface\\Icons\\ability_hunter_sickem",
TANK = "Interface\\Icons\\Spell_Deathknight_BloodPresence",
HEALER = "Interface\\Icons\\spell_holy_holybolt",
MELEE = "Interface\\Icons\\ability_steelmelee",
RANGED = "Interface\\Icons\\ability_marksmanship",
RAID = "Interface\\Icons\\spell_magic_lesserinvisibilty",
}
local function bossMarker(width, height, x, y, label, portrait)
local point=marker(width,height,x,y,label,"BOSS",ICON.BOSS)
point.npcId=portrait.npcId
point.displayId=portrait.displayId
return point
end
local function rotatedBossMarker(width, height, x, y, label, portrait)
return bossMarker(width,height,width-x,height-y,label,portrait)
end
local SUNWELL_PORTRAIT = {
KALECGOS={npcId=24850,displayId=23345},
BRUTALLUS={npcId=24882,displayId=22711},
FELMYST={npcId=25038,displayId=22838},
SACROLASH={npcId=25165,displayId=23177},
ALYTHESS={npcId=25166,displayId=23334},
MURU={npcId=25741,displayId=23404},
KILJAEDEN={npcId=25315,displayId=23200},
}
local maps = {
{
id="neutral", name="通用战术网格", texture=nil,
summary="没有专属模板时按职责生成通用布局。",
},
{
id="toc_arena_long", name="十字军竞技场·猛兽P2", encounterId=1088,
texture="Interface\\AddOns\\NoWCL\\RaidManagement\\Media\\Maps\\toc-arena-long.png",
slots=slots(700, 700/1394*784, {
{271,58},{441,55},{348,163},{310,226},{381,230},{228,196},{428,174},{159,154},{181,251},
{115,223},{253,275},{198,327},{340,295},{424,283},{286,351},{400,350},{488,233},
}),
rules={
{ kind="TANK", slots=range(1,2), label="坦克" },
{ kind="HEALER", slots=range(3,10), label="治疗" },
{ kind="RANGED", slots=range(3,17), label="远程DPS" },
},
markers={
marker(700,700/1394*784,241,125,"1队近战","MELEE",ICON.MELEE),
marker(700,700/1394*784,298,123,"2队近战","MELEE",ICON.MELEE),
marker(700,700/1394*784,268,101,"酸喉","BOSS",ICON.BOSS),
marker(700,700/1394*784,441,102,"恐鳞","BOSS",ICON.BOSS),
},
summary="坦克1-2号；治疗3-10号；其余远程依次分散。",
},
{
id="toc_arena", name="十字军竞技场·双子沙包", encounterId=1089,
texture="Interface\\AddOns\\NoWCL\\RaidManagement\\Media\\Maps\\toc-arena.png",
slots=slots(700, 700/1394*784, {
{62,185},{292,70},{291,277},{146,285},{335,177},{718,16},{717,52},{717,87},
}),
rules={
{ kind="DAMAGER", classes={"HUNTER"}, slots=range(1,8), label="猎人" },
{ kind="DAMAGER", classes={"PRIEST"}, slots=range(1,8), label="暗牧" },
{ kind="DAMAGER", classes={"MAGE"}, slots=range(1,8), label="法师" },
},
markers={
marker(700,700/1394*784,202,182,"大团","RAID",ICON.RAID),
marker(700,700/1394*784,180,102,"坦克","TANK",ICON.TANK),
marker(700,700/1394*784,190,142,"双子","BOSS",ICON.BOSS),
},
summary="沙包优先安排猎人、暗牧，其次法师。",
},
{
id="naxx_slime", name="纳克萨玛斯·塔迪乌斯分队", encounterId=1120,
texture="Interface\\AddOns\\NoWCL\\RaidManagement\\Media\\Maps\\naxx-slime-channel.png",
slots=slots(700, 700/1356*766, {
{46,341},{646,345},{45,290},{646,292},{45,238},{644,237},{46,188},{645,184},{114,344},
{582,345},{113,293},{581,294},{113,240},{579,242},{113,189},{578,188},{181,343},{512,349},
{179,291},{511,297},{180,240},{511,244},{178,190},{510,188},{248,343},
}),
rules={
{ kind="TANK", slots=range(1,25), label="坦克" },
{ kind="HEALER", slots=range(1,25), label="治疗" },
{ kind="MELEE", slots=range(1,25), label="近战DPS" },
{ kind="RANGED", slots=range(1,25), label="远程DPS" },
},
summary="槽位左右交替，按坦克、治疗、近战、远程顺序平均分队。",
},
{
id="naxx_hall", name="纳克萨玛斯·四骑士", encounterId=1121,
texture="Interface\\AddOns\\NoWCL\\RaidManagement\\Media\\Maps\\naxx-stone-hall.png",
slots=slots(600, 600/1086*777, {
{89,367},{536,374},{514,293},{215,75},{411,76},{157,74},{470,77},
}),
rules={
{ kind="TANK", slots=range(1,2), label="坦克" },
{ kind="HEALER", slots=range(3,5), label="治疗" },
{ kind="MELEE", slots=range(6,7), label="近战DPS" },
},
markers={
marker(600,600/1086*777,104,286,"其他人","RAID",ICON.RAID),
marker(600,600/1086*777,96,326,"库尔塔兹","BOSS",ICON.BOSS),
marker(600,600/1086*777,529,333,"瑞文戴尔","BOSS",ICON.BOSS),
marker(600,600/1086*777,189,46,"布劳缪克丝","BOSS",ICON.BOSS),
marker(600,600/1086*777,442,48,"瑟里耶克","BOSS",ICON.BOSS),
},
summary="1-2号坦克；3-5号治疗；6-7号近战。",
},
{
id="naxx_frost", name="纳克萨玛斯·克尔苏加德", encounterId=1114,
texture="Interface\\AddOns\\NoWCL\\RaidManagement\\Media\\Maps\\naxx-frost-hall.png",
slots=slots(600, 600/940*770, {
{301,378},{163,244},{443,249},{210,151},{397,149},{196,347},{404,345},{304,104},{303,448},
{182,427},{431,426},{104,319},{501,319},{113,166},{486,177},{208,73},{403,76},
}),
rules={
{ kind="HEALER", classes={"PALADIN"}, slots={2,3}, label="奶骑" },
{ kind="HEALER", classes={"SHAMAN","PRIEST","DRUID"}, slots=range(1,17), label="其他治疗" },
{ kind="RANGED", slots=range(1,17), label="远程DPS" },
},
markers={
marker(600,600/940*770,300,291,"坦克","TANK",ICON.TANK),
marker(600,600/940*770,270,216,"2队近战","MELEE",ICON.MELEE),
marker(600,600/940*770,338,219,"1队近战","MELEE",ICON.MELEE),
marker(600,600/940*770,302,249,"克尔苏加德","BOSS",ICON.BOSS),
},
summary="奶骑固定2、3号；其他治疗填1、4、5号附近；其余为远程。",
},
{
id="ssc_metal", name="毒蛇神殿·海度斯冰阶段", encounterId=623,
texture="Interface\\AddOns\\NoWCL\\RaidManagement\\Media\\Maps\\ssc-metal-platform.png",
slots=slots(650,593, {
{229,326},{418,336},{231,408},{414,408},{327,416},{160,184},{207,248},{106,248},{125,332},
{139,420},{485,190},{434,250},{546,249},{513,327},{513,429},{198,484},{459,489},
}),
rules={
{ kind="HEALER", slots=range(1,5), label="治疗" },
{ kind="RANGED", slots=range(1,17), label="远程DPS" },
},
markers={
marker(650,593,327,178,"近战","MELEE",ICON.MELEE),
marker(650,593,326,275,"坦克","TANK",ICON.TANK),
marker(650,593,326,226,"海度斯","BOSS",ICON.BOSS),
},
summary="1-5号治疗；6-17号远程DPS。",
},
{
id="ssc_cavern", name="毒蛇神殿·鱼斯拉", encounterId=624,
texture="Interface\\AddOns\\NoWCL\\RaidManagement\\Media\\Maps\\ssc-cavern.png",
slots=slots(650,536, {
{208,308},{354,374},{364,152},{248,175},{423,239},{135,125},{146,67},{79,89},{509,194},
{539,122},{581,179},{497,379},{576,396},{531,472},{189,225},{409,326},{264,386},
}),
rules={
{ kind="HEALER", slots=range(1,5), label="治疗" },
{ kind="RANGED", slots=range(1,17), label="远程DPS" },
},
markers={
marker(650,536,331,206,"近战","MELEE",ICON.MELEE),
marker(650,536,286,317,"坦克","TANK",ICON.TANK),
marker(650,536,304,259,"鱼斯拉","BOSS",ICON.BOSS),
},
summary="1-5号治疗；其余岛屿位置安排远程DPS。",
},
{
id="ssc_bridge", name="毒蛇神殿·盲眼者", encounterId=625,
texture="Interface\\AddOns\\NoWCL\\RaidManagement\\Media\\Maps\\ssc-green-bridge.png",
slots=slots(700,452, {
{203,91},{503,94},{241,271},{478,279},{354,281},{279,62},{420,68},{267,128},{437,127},
{178,165},{540,160},{258,201},{445,205},{173,241},{538,231},{293,337},{425,336},
}),
rules={
{ kind="HEALER", slots=range(1,5), label="治疗" },
{ kind="RANGED", slots=range(1,17), label="远程DPS" },
},
markers={
marker(700,452,354,115,"近战","MELEE",ICON.MELEE),
marker(700,452,353,204,"坦克","TANK",ICON.TANK),
marker(700,452,354,161,"盲眼者","BOSS",ICON.BOSS),
},
summary="1-5号治疗；6-17号远程DPS。",
},
{
id="ssc_octagon", name="毒蛇神殿·瓦丝琪P2", encounterId=628,
texture="Interface\\AddOns\\NoWCL\\RaidManagement\\Media\\Maps\\ssc-octagon.png",
slots=slots(650,520, {
{237,244},{386,254},{447,185},{389,108},{252,114},{106,390},{291,447},{488,420},{582,301},
{585,196},{530,109},{462,55},{341,40},{240,52},{145,88},{92,141},{68,274},
}),
rules={
{ kind="HEALER", slots=range(1,5), label="治疗" },
{ kind="RANGED", slots=range(1,17), label="远程DPS" },
},
markers={ marker(650,520,321,167,"瓦丝琪","BOSS",ICON.BOSS) },
summary="1-5号治疗；6-17号远程DPS环形分散。",
},
{
id="tk_arcane", name="风暴要塞·空灵机甲", encounterId=731,
texture="Interface\\AddOns\\NoWCL\\RaidManagement\\Media\\Maps\\tk-arcane-platform.png",
slots=slots(650,650/1360*1158, {
{324,477},{108,313},{548,330},{181,98},{483,101},{228,453},{423,456},{158,400},
{494,409},{101,238},{556,247},{129,163},{533,173},{249,58},{417,57},{331,44},
}),
rules={
{ kind="HEALER", slots=range(1,16), label="治疗" },
{ kind="RANGED", slots=range(1,16), label="远程DPS" },
},
markers={ marker(650,650/1360*1158,328,240,"空灵机甲","BOSS",ICON.BOSS) },
summary="所有治疗优先落位；剩余位置安排远程DPS。",
},
{
id="sw_apex", name="太阳井高地·卡雷苟斯", encounterId=724,
texture="Interface\\AddOns\\NoWCL\\RaidManagement\\Media\\Maps\\sunwell-apex-point.png",
slots=slots(600,600/886*780, {
{300,245},{255,270},{345,270},{265,325},{335,325},
{158,256},{100,209},{224,208},{92,292},{220,296},
{447,256},{379,211},{506,208},{388,294},{504,291},
{177,401},{115,362},{242,369},{132,436},{245,440},
{421,403},{369,366},{481,365},{363,450},{468,446},
}),
rules={
{ subgroup=1, slots=range(1,5), label="1队" },
{ subgroup=2, slots=range(6,10), label="2队" },
{ subgroup=3, slots=range(11,15), label="3队" },
{ subgroup=4, slots=range(16,20), label="4队" },
{ subgroup=5, slots=range(21,25), label="5队" },
},
markers={
bossMarker(600,600/886*780,306,82,"卡雷苟斯",SUNWELL_PORTRAIT.KALECGOS),
marker(600,600/886*780,251,81,"坦克","TANK",ICON.TANK),
marker(600,600/886*780,309,137,"近战","MELEE",ICON.MELEE),
},
summary="严格按1-5队写入各自五个分散槽位，保持传送门轮换小队完整。",
},
{
id="sw_dead_scar", name="太阳井高地·布鲁塔卢斯", encounterId=725,
texture="Interface\\AddOns\\NoWCL\\RaidManagement\\Media\\Maps\\sunwell-dead-scar.png",
slots=slots(600,600/689*740, {
{307,237},{298,330},{370,250},{351,357},{343,192},{284,386},{153,303},
{399,207},{342,405},{433,256},{397,392},{371,144},{290,442},{426,160},
{343,478},{452,210},{394,450},{407,109},{290,510},{487,264},{444,423},
}),
rules={
{ kind="TANK", classes={"DEATHKNIGHT"}, slots=range(1,2), label="死亡骑士坦克" },
{ kind="TANK", classes={"PALADIN","WARRIOR","DRUID","MONK"}, slots=range(1,2), label="其他坦克" },
{ kind="HEALER", slots=range(1,21), label="治疗" },
{ kind="RANGED", slots=range(8,21), label="远程DPS" },
},
markers={
bossMarker(600,600/689*740,270,279,"布鲁塔卢斯",SUNWELL_PORTRAIT.BRUTALLUS),
marker(600,600/689*740,218,300,"近战安全区","MELEE",ICON.MELEE),
marker(600,600/689*740,154,243,"上侧燃烧区","MOVE",ICON.RAID),
marker(600,600/689*740,154,369,"下侧燃烧区","MOVE",ICON.RAID),
},
summary="死亡骑士坦克优先1-2号；治疗随后占位；远程从8号起补齐两侧流星组。",
},
{
id="sw_felmyst", name="太阳井高地·菲米丝", encounterId=726,
texture="Interface\\AddOns\\NoWCL\\RaidManagement\\Media\\Maps\\sunwell-dead-scar.png",
slots=slots(968,649, {
{560,285},{600,330},
{240,110},{300,120},{360,110},{100,320},{150,360},{200,340},
{210,80},{270,90},{330,80},{380,100},{80,280},{90,340},{110,400},{160,420},
{350,460},{400,470},{450,470},{330,500},{380,520},{430,520},{480,500},{360,550},{440,550},
}),
rules={
{ kind="TANK", slots=range(1,2), label="坦克" },
{ kind="HEALER", slots=range(3,8), label="治疗分组" },
{ kind="RANGED", slots=range(9,16), label="远程分组" },
{ kind="MELEE", slots=range(17,25), label="近战背后" },
{ kind="DAMAGER", slots=range(9,25), label="输出补位" },
},
markers={
bossMarker(968,649,425,330,"菲米丝",SUNWELL_PORTRAIT.FELMYST),
marker(968,649,557,285,"坦克","TANK",ICON.TANK),
},
summary="地面阶段按坦克、治疗、远程和近战分区；空中阶段改用迷雾三线动态路线。",
},
{
id="sw_twins", name="太阳井高地·艾瑞达双子", encounterId=727,
texture="Interface\\AddOns\\NoWCL\\RaidManagement\\Media\\Maps\\sunwell-witch-sanctum.png",
slots=slots(1000,1000, {
{710,650},{760,610},{360,690},{300,720},
{390,125},{455,125},{520,125},{585,125},{345,170},{420,170},{500,170},{580,170},
{650,180},{700,190},{750,210},{800,235},
{565,655},{610,700},{655,735},{700,765},{520,715},{565,760},{610,800},{660,830},{710,850},
}),
rules={
{ kind="DAMAGER", classes={"WARLOCK"}, slots={3}, limit=1, label="火女远程坦" },
{ kind="TANK", slots=range(1,4), label="双子坦克" },
{ kind="HEALER", slots=range(5,12), label="平台治疗" },
{ kind="RANGED", slots=range(5,16), label="平台远程" },
{ kind="MELEE", slots=range(17,25), label="楼下近战" },
{ kind="DAMAGER", slots=range(13,25), label="输出补位" },
},
markers={
bossMarker(1000,1000,700,590,"萨洛拉丝",SUNWELL_PORTRAIT.SACROLASH),
bossMarker(1000,1000,340,735,"奥蕾塞丝",SUNWELL_PORTRAIT.ALYTHESS),
marker(1000,1000,500,90,"远程与治疗平台","RANGED",ICON.RANGED),
},
summary="远程与治疗在入口平台集合；坦克与近战在楼下处理萨洛拉丝，火女由远程坦接手。",
},
{
id="sw_muru", name="太阳井高地·穆鲁", encounterId=728,
texture="Interface\\AddOns\\NoWCL\\RaidManagement\\Media\\Maps\\sunwell-shrine-eclipse.png",
slots=slots(1000,1000, {
{175,350},{825,350},{500,790},
{245,420},{285,455},{325,490},{255,545},{305,580},{355,610},
{205,475},{220,525},{245,575},{285,625},{330,660},{375,690},{420,710},{465,720},
{310,390},{350,420},{390,445},{430,465},{350,515},{395,535},{440,555},{480,575},
}),
rules={
{ kind="TANK", slots=range(1,3), label="入口/出口/哨兵坦克" },
{ kind="HEALER", slots=range(4,9), label="治疗" },
{ kind="RANGED", slots=range(10,17), label="远程DPS" },
{ kind="MELEE", slots=range(18,25), label="近战DPS" },
{ kind="DAMAGER", slots=range(10,25), label="输出补位" },
},
markers={
bossMarker(1000,1000,500,500,"穆鲁",SUNWELL_PORTRAIT.MURU),
marker(1000,1000,120,350,"入口小怪","RAID",ICON.RAID),
marker(1000,1000,880,350,"出口小怪","RAID",ICON.RAID),
marker(1000,1000,500,850,"虚空哨兵","BOSS",ICON.BOSS),
},
summary="两侧小怪与虚空哨兵职责先落位；大团默认在入口侧形成安全击杀区。",
},
{
id="sw_sunwell", name="太阳井高地·基尔加丹", encounterId=729,
texture="Interface\\AddOns\\NoWCL\\RaidManagement\\Media\\Maps\\sunwell-sunwell.png",
slots=rotatedSlots(600,600/879*779, {
{429,271},{391,169},{294,130},{448,130},{348,19},{549,214},{497,334},
{215,77},{424,217},{349,140},{506,263},{483,194},{376,78},{297,65},
{516,140},{467,75},{413,36},
}),
rules={
{ kind="DAMAGER", classes={"MAGE"}, slots={7,8}, label="控龙法师" },
{ kind="HEALER", slots=range(1,17), label="治疗" },
{ kind="RANGED", slots=range(1,17), label="远程DPS" },
},
markers={
rotatedBossMarker(600,600/879*779,301,271,"基尔加丹",SUNWELL_PORTRAIT.KILJAEDEN),
rotatedMarker(600,600/879*779,370,320,"坦克","TANK",ICON.TANK),
rotatedMarker(600,600/879*779,261,192,"近战","MELEE",ICON.MELEE),
marker(1000,1000,205,250,"宝珠","RAID",ICON.RAID),
marker(1000,1000,795,250,"宝珠","RAID",ICON.RAID),
marker(1000,1000,195,720,"宝珠","RAID",ICON.RAID),
marker(1000,1000,795,720,"宝珠","RAID",ICON.RAID),
},
summary="法师优先7-8号控龙位；治疗随后占位；远程补齐同侧半场分散位置。",
},
{
id="zug_courtyard", name="祖尔格拉布·温诺希斯重叠站位", encounterId=784,
texture="Interface\\AddOns\\NoWCL\\RaidManagement\\Media\\Maps\\zug-jungle-courtyard.png",
slots={}, rules={},
markers={
marker(700,700/2103*1394,359,318,"5队治疗","HEALER",ICON.HEALER),
marker(700,700/2103*1394,496,313,"4队远程","RANGED",ICON.RANGED),
marker(700,700/2103*1394,355,194,"3队远程","RANGED",ICON.RANGED),
marker(700,700/2103*1394,515,219,"2队近战","MELEE",ICON.MELEE),
marker(700,700/2103*1394,471,163,"1队近战","MELEE",ICON.MELEE),
marker(700,700/2103*1394,548,146,"坦克","TANK",ICON.TANK),
marker(700,700/2103*1394,515,174,"温诺希斯","BOSS",ICON.BOSS),
},
summary="该图以小队重叠区域为单位，不分配个人槽位。",
},
{
id="zug_terrace", name="祖尔格拉布·哈卡", encounterId=793,
texture="Interface\\AddOns\\NoWCL\\RaidManagement\\Media\\Maps\\zug-temple-terrace.png",
slots=slots(700,700/2424*1500, {
{349,263},{254,259},{446,260},{297,176},{400,177},{83,232},{186,234},{145,182},{107,121},
{210,125},{634,228},{520,231},{568,168},{614,122},{496,126},{298,325},{413,326},
}),
rules={
{ kind="HEALER", slots=range(1,17), label="治疗" },
{ kind="RANGED", slots=range(1,17), label="远程DPS" },
},
markers={
marker(700,700/2424*1500,350,29,"近战","MELEE",ICON.MELEE),
marker(700,700/2424*1500,352,104,"坦克","TANK",ICON.TANK),
marker(700,700/2424*1500,352,66,"哈卡","BOSS",ICON.BOSS),
},
summary="1-5号治疗；6-17号远程DPS。",
},
{
id="mc_lava", name="熔火之心·拉格纳罗斯", encounterId=672,
texture="Interface\\AddOns\\NoWCL\\RaidManagement\\Media\\Maps\\mc-lava-platform.png",
slots=slots(650,505, {
{493,116},{595,178},{100,318},{328,410},{438,360},{80,181},{30,260},{68,405},{203,388},
{149,456},{255,466},{413,446},{547,378},{496,275},{588,284},
}),
rules={
{ kind="HEALER", classes={"PALADIN"}, slots={1}, limit=1, label="1号奶骑" },
{ kind="HEALER", classes={"PALADIN"}, slots={2}, limit=1, label="2号奶骑" },
{ kind="HEALER", slots=range(1,5), label="其他治疗" },
{ kind="RANGED", slots=range(1,15), label="远程DPS" },
},
markers={
marker(650,505,242,140,"惩戒骑/增强萨","MELEE",ICON.MELEE),
marker(650,505,258,245,"近战","MELEE",ICON.MELEE),
marker(650,505,378,151,"坦克","TANK",ICON.TANK),
marker(650,505,317,194,"拉格纳罗斯","BOSS",ICON.BOSS),
},
summary="1-2号优先奶骑；3-5号其他治疗；6-15号远程DPS。",
},
}
RM.MapCatalog = maps
RM.MapById = {}
RM.MapByEncounter = {}
for _, map in ipairs(maps) do
map.templateVersion = math.max(1, math.floor(tonumber(map.templateVersion) or 1))
RM.MapById[map.id] = map
if map.encounterId then RM.MapByEncounter[map.encounterId] = map end
map.slotById = {}
for _, slot in ipairs(map.slots or {}) do map.slotById[slot.id] = slot end
for _, rule in ipairs(map.rules or {}) do
for _, index in ipairs(rule.slots or {}) do
local slot = map.slots and map.slots[index]
if slot then
slot.hints = slot.hints or {}
local duplicate
for _, hint in ipairs(slot.hints) do if hint == rule.label then duplicate=true; break end end
if not duplicate then slot.hints[#slot.hints + 1] = rule.label end
end
end
end
end
function RM:GetMap(mapId)
return self.MapById[mapId] or self.MapCatalog[1]
end
function RM:GetMapForEncounter(encounterId)
return self.MapByEncounter[tonumber(encounterId)]
end
local POSITION_TEMPLATE_DEFS = {
{ id="mc_lava",       phase="P1", raidKey="MC",   bossName="拉格纳罗斯" },
{ id="ssc_octagon",   phase="P2", raidKey="SSC",  bossName="瓦丝琪" },
{ id="naxx_slime",    phase="P3", raidKey="NAXX", bossName="塔迪乌斯" },
{ id="naxx_hall",     phase="P3", raidKey="NAXX", bossName="天启四骑士" },
{ id="naxx_frost",    phase="P3", raidKey="NAXX", bossName="克尔苏加德" },
{ id="sw_apex",       phase="P5", raidKey="SWP",  bossName="卡雷苟斯" },
{ id="sw_dead_scar",  phase="P5", raidKey="SWP",  bossName="布鲁塔卢斯" },
{ id="sw_felmyst",    phase="P5", raidKey="SWP",  bossName="菲米丝" },
{ id="sw_twins",      phase="P5", raidKey="SWP",  bossName="艾瑞达双子" },
{ id="sw_muru",       phase="P5", raidKey="SWP",  bossName="穆鲁" },
{ id="sw_sunwell",    phase="P5", raidKey="SWP",  bossName="基尔加丹" },
}
local RAID_CONTEXTS = {
{ key="MC",   phase="P1", name="熔火之心",       mapIds={409}, aliases={"熔火之心"} },
{ key="SSC",  phase="P2", name="毒蛇神殿",       mapIds={548}, aliases={"毒蛇神殿"} },
{ key="TK",   phase="P2", name="风暴要塞",       mapIds={550}, aliases={"风暴要塞"} },
{ key="NAXX", phase="P3", name="纳克萨玛斯",     mapIds={533}, aliases={"纳克萨玛斯"} },
{ key="OS",   phase="P3", name="黑曜石圣所",     mapIds={615}, aliases={"黑曜石圣所"} },
{ key="EOE",  phase="P3", name="永恒之眼",       mapIds={616}, aliases={"永恒之眼"} },
{ key="ZG",   phase="P4", name="祖尔格拉布",     mapIds={309,859}, aliases={"祖尔格拉布"} },
{ key="TOC",  phase="P4", name="十字军的试炼",   mapIds={649}, aliases={"十字军的试炼","十字军试炼"} },
{ key="SWP",  phase="P5", name="太阳井高地",     mapIds={580}, aliases={"太阳井高地","太阳之井高地"} },
}
RM.PositionBossCatalog = {}
RM.PositionMapByEncounter = {}
RM.PositionMapByBossName = {}
RM.PositionRaidCatalog = RAID_CONTEXTS
RM.PositionRaidByKey = {}
RM.PositionRaidByInstanceMap = {}
for _, raid in ipairs(RAID_CONTEXTS) do
raid.maps = {}
RM.PositionRaidByKey[raid.key] = raid
for _, instanceMapId in ipairs(raid.mapIds or {}) do
RM.PositionRaidByInstanceMap[tonumber(instanceMapId)] = raid
end
end
for _, definition in ipairs(POSITION_TEMPLATE_DEFS) do
local map = RM.MapById[definition.id]
local raid = RM.PositionRaidByKey[definition.raidKey]
if map and raid then
map.positionEnabled = true
map.phaseKey = definition.phase
map.raidKey = definition.raidKey
map.bossName = definition.bossName
map.positionLabel = definition.phase .. " · " .. definition.bossName
RM.PositionBossCatalog[#RM.PositionBossCatalog + 1] = map
RM.PositionMapByEncounter[tonumber(map.encounterId)] = map
RM.PositionMapByBossName[definition.bossName] = map
raid.maps[#raid.maps + 1] = map
end
end
local function compactInstanceName(value)
return tostring(value or ""):gsub("%s+", ""):gsub("之", "")
end
function RM:GetPositionMapForEncounter(encounterId)
return self.PositionMapByEncounter[tonumber(encounterId)]
end
function RM:GetPositionMapForBossName(bossName)
bossName = tostring(bossName or "")
local exact = self.PositionMapByBossName[bossName]
if exact then return exact end
for name, map in pairs(self.PositionMapByBossName) do
if bossName:find(name, 1, true) then return map end
end
end
function RM:IsPositionMap(mapId)
local map = type(mapId) == "table" and mapId or self.MapById[mapId]
return map and map.positionEnabled and true or false
end
function RM:GetPositionRaidForInstance(instanceName, instanceMapId)
local byMap = self.PositionRaidByInstanceMap[tonumber(instanceMapId)]
if byMap then return byMap end
local compact = compactInstanceName(instanceName)
if compact == "" then return nil end
for _, raid in ipairs(self.PositionRaidCatalog) do
for _, alias in ipairs(raid.aliases or {}) do
local candidate = compactInstanceName(alias)
if compact == candidate or compact:find(candidate, 1, true) then return raid end
end
end
end
function RM:GetNextPositionMap(raidKey, defeated)
local raid = self.PositionRaidByKey[tostring(raidKey or "")]
if not raid or #(raid.maps or {}) == 0 then return nil end
defeated = defeated or {}
for _, map in ipairs(raid.maps) do
if not defeated[tonumber(map.encounterId)] and not defeated[map.bossName] then return map end
end
return raid.maps[#raid.maps]
end
