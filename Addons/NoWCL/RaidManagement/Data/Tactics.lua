local _, NoWCL = ...
local RM = NoWCL.RaidManagement
local U = RM.Util
local ICON = {
BOSS = "Interface\\Icons\\ability_hunter_sickem",
TANK = "Interface\\Icons\\Spell_Deathknight_BloodPresence",
HEALER = "Interface\\Icons\\spell_holy_holybolt",
MELEE = "Interface\\Icons\\ability_steelmelee",
RANGED = "Interface\\Icons\\ability_marksmanship",
RAID = "Interface\\Icons\\spell_magic_lesserinvisibilty",
MOVE = "Interface\\Icons\\ability_rogue_sprint",
STACK = "Interface\\Icons\\spell_holy_divineprovidence",
SPREAD = "Interface\\Icons\\spell_nature_wispsplode",
POSITIVE = "Interface\\Icons\\spell_chargepositive",
NEGATIVE = "Interface\\Icons\\spell_chargenegative",
}
local function mark(x, y, label, kind, icon)
return { x=x, y=y, label=label, kind=kind, icon=icon or ICON[kind] }
end
local function zone(id, label, x, y, width, height, kind)
return { id=id, label=label, x=x, y=y, width=width, height=height, kind=kind or "RAID" }
end
local function route(id, label, kind, points, loop)
return { id=id, label=label, kind=kind or "MOVE", points=points, loop=loop and true or false }
end
local function hard(text)
return { level="hard", text=text }
end
local function template(text)
return { level="template", text=text }
end
local function auditTask(templateId, name, event, spellIds, options)
local task = options or {}
task.templateId = templateId
task.name = name
task.event = event
task.events = task.events or { event }
task.spellIds = spellIds
task.type = task.type or "mechanic"
if task.autoAssign == nil then task.autoAssign = false end
return task
end
local SOURCES = {
replay = { label="泰坦 Warcraft Logs Replay", kind="replay" },
icy = { label="Icy Veins 首领攻略", kind="guide" },
wowhead = { label="Wowhead 首领攻略", kind="guide" },
raidguru = { label="RaidGuru / MMO-Champion 菲米丝攻略", kind="guide" },
warcraftWiki = { label="Warcraft Wiki 太阳井社区分层地图", kind="map" },
source = { label="项目历史站位模板审计", kind="template" },
}
local tactics = {
neutral = {
strategyType="FREEFORM", confidence="custom", defaultPhaseId="free",
sources={},
phases={
{
id="free", name="自由布局", strategyType="FREEFORM",
summary="没有专属模板时，按职责生成可编辑的通用布局。",
assignmentNotes="坦克前置，治疗中圈，输出按内外圈分布。",
constraints={template("通用布局仅作为编辑起点，不代表具体首领机制。")},
},
},
},
toc_arena_long = {
strategyType="STATIC", confidence="audited", defaultPhaseId="worms",
sources={SOURCES.replay,SOURCES.icy,SOURCES.source},
phases={
{
id="worms", name="P2 双虫分散", strategyType="STATIC",
summary="两坦分别接酸喉与恐鳞，治疗和远程在两侧预分散。",
assignmentNotes="坦克1-2号，治疗3-10号，其余远程按团队顺序补空位。",
requiredSlots={"p01","p02"},
sharedKinds={MELEE=true},
constraints={
hard("两名坦克必须分别覆盖酸喉和恐鳞。"),
hard("远程与治疗保持松散分布，避免麻痹喷射连锁。"),
template("近战按小队集中在双虫背侧，移动时跟随当前可攻击目标。"),
},
zones={
zone("left_melee","酸喉近战区",0.36,0.66,0.16,0.14,"MELEE"),
zone("right_melee","恐鳞近战区",0.58,0.66,0.16,0.14,"MELEE"),
},
dynamic={"钻地换位后，坦克和近战跟随首领新位置，远程保持原分散扇区。"},
},
},
},
toc_arena = {
strategyType="ASSIGNMENT", confidence="audited", defaultPhaseId="soakers",
sources={SOURCES.replay,SOURCES.icy,SOURCES.source},
phases={
{
id="soakers", name="沙包分区", strategyType="ASSIGNMENT",
summary="高机动远程负责外围球区，大团在首领侧后方集中。",
assignmentNotes="猎人优先，暗牧其次，剩余槽位由法师补充。",
requiredSlots={"p01","p02","p03","p04"},
sharedAll=true,
constraints={
hard("沙包必须覆盖预定方向，不能同时追逐同一颗球。"),
hard("沙包根据当前精华颜色处理同色球，错误颜色必须避让。"),
template("大团与坦克保持固定侧位，避免沙包路线穿过人群。"),
},
zones={
zone("raid","大团区",0.20,0.47,0.22,0.22,"RAID"),
zone("orb_arc","外围沙包区",0.50,0.15,0.92,0.26,"RANGED"),
},
dynamic={"沙包槽位代表负责方向，不是必须钉死的像素坐标。"},
},
},
},
naxx_slime = {
strategyType="MULTIPHASE", confidence="audited", defaultPhaseId="opening",
sources={SOURCES.replay,SOURCES.icy,SOURCES.source},
phases={
{
id="opening", name="开场双平台", strategyType="GROUP_SPLIT",
summary="团队按左右交替槽位均衡分到费尔根与斯塔拉格两侧。",
assignmentNotes="依次放入坦克、治疗、近战、远程，槽位左右交替保证人数和职责均衡。",
requiredSlots={"p01","p02"},
constraints={
hard("左右平台都必须有坦克、治疗和足够输出。"),
hard("两只小首领需要在接近的时间内击杀。"),
template("左右交替编号用于稳定分队，不表示后续电荷。"),
},
zones={
zone("left_platform","左平台",0.18,0.64,0.30,0.56,"RAID"),
zone("right_platform","右平台",0.82,0.64,0.30,0.56,"RAID"),
},
},
{
id="polarity", name="电荷动态换边", strategyType="DYNAMIC", slots=false, rules=false,
summary="跳台后按实时正负电荷站到首领两侧；电荷变化时沿外圈换边。",
assignmentNotes="电荷是战斗中随机获得，不能在开战前固定到个人槽位。",
constraints={
hard("同极集中、异极分离，任何静态人员分配都不能代替实时看电荷。"),
hard("换边沿团队约定外圈移动，禁止穿过首领和另一极人群。"),
},
markers={
mark(0.36,0.76,"正电荷","POSITIVE",ICON.POSITIVE),
mark(0.64,0.76,"负电荷","NEGATIVE",ICON.NEGATIVE),
mark(0.50,0.76,"塔迪乌斯","BOSS",ICON.BOSS),
},
zones={
zone("positive","正极集合",0.34,0.76,0.24,0.28,"POSITIVE"),
zone("negative","负极集合",0.66,0.76,0.24,0.28,"NEGATIVE"),
},
routes={
route("swap_top","上侧换边","MOVE",{{0.34,0.63},{0.50,0.55},{0.66,0.63}}),
route("swap_bottom","下侧换边","MOVE",{{0.66,0.89},{0.50,0.96},{0.34,0.89}}),
},
dynamic={"正负区域只表达团队约定；实际左右可以由团长交换。"},
},
},
},
naxx_hall = {
strategyType="MULTIPHASE", confidence="audited", defaultPhaseId="opening",
sources={SOURCES.replay,SOURCES.icy,SOURCES.source},
phases={
{
id="opening", name="开场四角", strategyType="ASSIGNMENT",
summary="前场双坦分开两名近战骑士，后场由治疗和远程覆盖。",
assignmentNotes="1-2号坦克，3-5号治疗，6-7号近战。",
requiredSlots={"p01","p02","p03","p04","p05","p06","p07"},
sharedAll=true,
constraints={
hard("四个角都必须有可承受印记的人员，前场两名首领必须分开。"),
hard("后场两名首领由治疗和远程维持距离并承接印记。"),
},
zones={
zone("front_left","前场左",0.16,0.31,0.25,0.28,"TANK"),
zone("front_right","前场右",0.84,0.31,0.25,0.28,"TANK"),
zone("back_left","后场左",0.32,0.84,0.30,0.24,"HEALER"),
zone("back_right","后场右",0.70,0.84,0.30,0.24,"HEALER"),
},
},
{
id="marks", name="印记轮换", strategyType="DYNAMIC", slots=false, rules=false,
summary="达到团队约定印记层数后，前后场分别沿本侧路线交换。",
assignmentNotes="轮换由印记层数触发，开战前只安排轮换组和方向。",
constraints={
hard("换位前必须确认接班组已到位，不能让任何一个角落空场。"),
hard("前场交换不能把两名近战首领带到一起。"),
},
markers={
mark(0.16,0.31,"前左","BOSS",ICON.BOSS), mark(0.84,0.31,"前右","BOSS",ICON.BOSS),
mark(0.32,0.84,"后左","BOSS",ICON.BOSS), mark(0.70,0.84,"后右","BOSS",ICON.BOSS),
},
routes={
route("front_swap","前场轮换","MOVE",{{0.16,0.31},{0.50,0.49},{0.84,0.31}},true),
route("back_swap","后场轮换","MOVE",{{0.32,0.84},{0.50,0.70},{0.70,0.84}},true),
},
dynamic={"轮换层数属于团队策略参数，模板不强制固定为某个数值。"},
},
},
},
naxx_frost = {
strategyType="MULTIPHASE", confidence="audited", defaultPhaseId="boss",
sources={SOURCES.replay,SOURCES.icy,SOURCES.source},
phases={
{
id="adds", name="P1 外圈小怪", strategyType="DYNAMIC", slots=false, rules=false,
summary="团队在房间中央控制距离，远程处理外圈进入的小怪。",
assignmentNotes="P1 不使用 P2 的固定分散槽位。",
constraints={
hard("近战不要提前贴近外圈未激活的小怪包。"),
template("远程按方向负责进入视野的骷髅和女妖。"),
},
markers={mark(0.50,0.48,"P1 大团","RAID",ICON.RAID)},
zones={zone("p1_raid","P1 大团",0.50,0.48,0.28,0.28,"RAID")},
},
{
id="boss", name="P2/P3 分散", strategyType="STATIC",
summary="首领居中，近战分两组，远程与治疗按预定槽位保持间距。",
assignmentNotes="奶骑固定2、3号；其他治疗先填1、4、5号；剩余位置安排远程。",
sharedKinds={TANK=true,MELEE=true},
constraints={
hard("远程和治疗保持分散，冰霜冲击不能连锁多人。"),
hard("近战两组彼此分开，并避免冰霜冲击覆盖另一组。"),
template("P3 小强坦克在首领后侧接怪，不穿过远程分散区。"),
},
dynamic={"被暗影裂隙或法力爆炸点名时临时离开槽位，机制结束后归位。"},
},
},
},
ssc_metal = {
strategyType="MULTIPHASE", confidence="audited", defaultPhaseId="frost",
sources={SOURCES.replay,SOURCES.icy,SOURCES.source},
phases={
{
id="frost", name="冰阶段", strategyType="STATIC",
summary="冰坦将首领稳定在平台中央，治疗与远程保持八码分散。",
assignmentNotes="1-5号治疗，6-17号远程。",
sharedKinds={TANK=true,MELEE=true},
constraints={hard("水之墓会连锁，远程与治疗必须保持分散。"),hard("冰坦与自然坦的交接路线不得穿过大团。")},
},
{
id="nature", name="自然阶段", strategyType="STATIC",
summary="自然坦接手后，团队保持原有分散扇区并处理自然形态小怪。",
assignmentNotes="沿用冰阶段的治疗和远程槽位，独立保存本阶段微调。",
sharedKinds={TANK=true,MELEE=true},
constraints={hard("腐化印记叠高前完成阶段切换。"),template("分散扇区不因坦克换位而整体穿场。")},
dynamic={"阶段切换时短暂向交接点靠拢，首领稳定后返回槽位。"},
},
},
},
ssc_cavern = {
strategyType="MULTIPHASE", confidence="audited", defaultPhaseId="islands",
sources={SOURCES.replay,SOURCES.icy,SOURCES.source},
phases={
{
id="islands", name="主环与外岛", strategyType="ASSIGNMENT",
summary="治疗覆盖主环和外岛，远程按岛屿槽位负责小怪控制。",
assignmentNotes="1-5号治疗，剩余槽位安排远程；外岛槽位表示责任区。",
sharedKinds={TANK=true,MELEE=true},
constraints={
hard("三座外岛都必须有可靠的远程控制与击杀能力。"),
hard("治疗分布需要覆盖主坦、主环和外岛人员。"),
template("外岛负责人优先选择法师、术士、猎人等远程职业。"),
},
requiredAreas={
{id="island_nw",label="西北岛",slots={"p06","p07","p08"},minimum=1},
{id="island_ne",label="东北岛",slots={"p09","p10","p11"},minimum=1},
{id="island_se",label="东南岛",slots={"p12","p13","p14"},minimum=1},
},
zones={
zone("center_ring","主环",0.50,0.50,0.42,0.42,"RAID"),
zone("island_nw","西北岛",0.14,0.79,0.20,0.20,"RANGED"),
zone("island_ne","东北岛",0.85,0.75,0.20,0.20,"RANGED"),
zone("island_se","东南岛",0.81,0.23,0.20,0.20,"RANGED"),
},
},
{
id="spout", name="喷泉与下潜", strategyType="DYNAMIC", slots=false, rules=false,
summary="喷泉出现后沿平台边缘同向移动或下水规避，结束后返回责任区。",
assignmentNotes="这是实时移动机制，不固定到个人像素槽位。",
constraints={hard("禁止逆着喷泉方向穿过水柱。"),hard("下潜结束前不要丢失自己负责的外岛小怪。")},
routes={route("ring_move","主环规避路线","MOVE",{{0.35,0.68},{0.58,0.70},{0.70,0.50},{0.57,0.30},{0.35,0.34}},true)},
zones={zone("water","临时下水区",0.50,0.50,0.66,0.66,"MOVE")},
dynamic={"采用沿环移动还是下水规避，由团长在具体战术中确定。"},
},
},
},
ssc_bridge = {
strategyType="MULTIPHASE", confidence="audited", defaultPhaseId="spread",
sources={SOURCES.replay,SOURCES.icy,SOURCES.source},
phases={
{
id="spread", name="常规分散", strategyType="STATIC",
summary="坦克在中央控制首领，治疗和远程在两侧预分散。",
assignmentNotes="1-5号治疗，6-17号远程。",
sharedKinds={TANK=true,MELEE=true},
constraints={hard("旋风斩前远程与治疗保持分散。"),hard("近战在旋风斩开始前退出危险半径。")},
},
{
id="whirlwind", name="旋风斩规避", strategyType="DYNAMIC", slots=false, rules=false,
summary="旋风斩期间离开中央通道，沿各自侧翼保持距离并避免交叉。",
assignmentNotes="只预分左右侧，不把随机追逐路径伪装成固定站位。",
constraints={hard("被追逐者远离大团，其他人不要横穿其路线。"),hard("旋风斩结束后再回中央输出区。")},
zones={zone("left_safe","左侧分散",0.24,0.54,0.30,0.70,"RANGED"),zone("right_safe","右侧分散",0.76,0.54,0.30,0.70,"RANGED")},
routes={route("boss_path","首领可能追逐区","MOVE",{{0.50,0.75},{0.50,0.52},{0.50,0.28}},true)},
},
},
},
ssc_octagon = {
strategyType="MULTIPHASE", confidence="audited", defaultPhaseId="p2",
sources={SOURCES.replay,SOURCES.icy,SOURCES.source},
phases={
{
id="p1", name="P1/P3 环形分散", strategyType="STATIC",
summary="首领居中，远程与治疗沿外圈分散，近战在背后集中。",
assignmentNotes="沿用环形槽位，但本阶段与 P2 分区分别保存。",
sharedKinds={TANK=true,MELEE=true},
constraints={hard("静电充能目标必须远离其他成员。"),template("远程围绕平台均匀分布，给移动机制留出通道。")},
dynamic={"P3 毒孢子区域出现后按顺时针逐步转移，不整体穿过人群。"},
},
{
id="p2", name="P2 四区守点", strategyType="ASSIGNMENT",
summary="治疗覆盖内圈，远程按四个方向负责元素、长脚和污染之核传递。",
assignmentNotes="1-5号治疗，6-17号远程；槽位同时表达四个责任扇区。",
sharedKinds={TANK=true,MELEE=true},
constraints={
hard("四个方向必须持续有人观察并处理被污染的元素。"),
hard("污染之核沿同一扇区逐段传向中央，不能跨越无接应区域。"),
hard("猎人等高机动职业优先承担长脚风筝。"),
},
requiredAreas={
{id="north",label="北区",slots={"p12","p13","p14"},minimum=1},
{id="east",label="东区",slots={"p09","p10","p11"},minimum=1},
{id="south",label="南区",slots={"p06","p07","p08"},minimum=1},
{id="west",label="西区",slots={"p15","p16","p17"},minimum=1},
},
zones={
zone("north","北区",0.50,0.18,0.30,0.26,"RANGED"), zone("east","东区",0.82,0.50,0.26,0.32,"RANGED"),
zone("south","南区",0.50,0.82,0.30,0.26,"RANGED"), zone("west","西区",0.18,0.50,0.26,0.32,"RANGED"),
zone("center","内圈接核",0.50,0.50,0.28,0.28,"HEALER"),
},
routes={
route("north_core","北区传核","MOVE",{{0.50,0.08},{0.50,0.28},{0.50,0.47}}),
route("east_core","东区传核","MOVE",{{0.92,0.50},{0.72,0.50},{0.53,0.50}}),
route("south_core","南区传核","MOVE",{{0.50,0.92},{0.50,0.72},{0.50,0.53}}),
route("west_core","西区传核","MOVE",{{0.08,0.50},{0.28,0.50},{0.47,0.50}}),
},
},
},
},
tk_arcane = {
strategyType="STATIC", confidence="audited", defaultPhaseId="ring",
sources={SOURCES.replay,SOURCES.icy,SOURCES.source},
phases={
{
id="ring", name="环形分散", strategyType="STATIC",
summary="首领居中，治疗优先占内圈覆盖位，远程沿外围均匀分散。",
assignmentNotes="先放治疗，再由远程填充剩余槽位。",
sharedKinds={TANK=true,MELEE=true},
constraints={hard("远程之间保持足够间距，奥术宝珠目标向外侧规避。"),hard("坦克保持首领居中，避免带动整团重排。")},
dynamic={"宝珠落点属于实时机制，点名者离开槽位后应从外侧返回。"},
zones={zone("boss_center","首领与近战",0.50,0.54,0.25,0.25,"MELEE")},
},
},
},
sw_apex = {
strategyType="MULTIPHASE", confidence="audited", defaultPhaseId="dragon",
sources={SOURCES.source,SOURCES.wowhead,SOURCES.warcraftWiki},
taskTemplateVersion=1,
defaultTasks={
auditTask("avoid-cleave","非坦克避免顺劈斩","SPELL_DAMAGE",{44799},{
mode="maximum",maximum=0,subject="target",targetRoles={"HEALER","DAMAGER"},phaseId="dragon",
}),
auditTask("avoid-tail","避免扫尾伤害","SPELL_DAMAGE",{45122},{
mode="maximum",maximum=0,subject="target",phaseId="dragon",
}),
auditTask("spectral-entry","灵魂世界进入记录","SPELL_AURA_APPLIED",{46021},{
mode="observe",subject="target",phaseId="spectral",
}),
auditTask("arcane-buffet","奥术打击目标记录","SPELL_AURA_APPLIED",{45018},{
mode="observe",subject="target",phaseId="dragon",
}),
auditTask("curse-dispel","无边苦痛诅咒驱散","SPELL_DISPEL",{45032,45034},{
mode="observe",subject="source",type="dispel",phaseId="dragon",
}),
},
phases={
{
id="dragon", name="龙形态分队分散", strategyType="GROUP_SPLIT",
summary="五个小队各自使用一组分散槽位，传送门出现后由被点名者所在小队整组进入内场。",
assignmentNotes="按团队顺序分组：1-5号为1队，6-10号为2队，依次到21-25号5队。",
requiredAreas={
{id="team1",label="1队分散区",slots={"p01","p02","p03","p04","p05"},minimum=1},
{id="team2",label="2队分散区",slots={"p06","p07","p08","p09","p10"},minimum=1},
{id="team3",label="3队分散区",slots={"p11","p12","p13","p14","p15"},minimum=1},
{id="team4",label="4队分散区",slots={"p16","p17","p18","p19","p20"},minimum=1},
{id="team5",label="5队分散区",slots={"p21","p22","p23","p24","p25"},minimum=1},
},
constraints={
hard("远程与治疗保持十码分散，避免灵魂冲击同时命中多人。"),
hard("龙头与龙尾不得朝向分散大团，坦克沿房间边缘控制朝向。"),
hard("传送门按完整小队轮换，内外场同时保留坦克、治疗、解诅咒和输出。"),
},
dynamic={"实际传送门目标随机；槽位表示开场分散和小队归属，不预判门的位置。"},
},
{
id="spectral", name="内外场轮换", strategyType="DYNAMIC", slots=false, rules=false,
summary="点名小队经传送门进入灵魂世界，60秒后返回并由下一队接替。",
assignmentNotes="本阶段只表达轮换次序和内外场职责，不建立随机传送门个人坐标。",
constraints={
hard("内场始终必须有可接萨索瓦尔的坦克、足够治疗和解诅咒。"),
hard("卡雷苟斯与萨索瓦尔压血必须同步，任一目标过早进入10%都会快速失控。"),
},
zones={
zone("dragon_realm","龙形态外场",0.35,0.50,0.56,0.82,"RAID"),
zone("spectral_realm","灵魂世界",0.73,0.50,0.42,0.62,"MOVE"),
},
routes={route("portal","传送门轮换","MOVE",{{0.35,0.50},{0.52,0.50},{0.73,0.50}})},
},
},
},
sw_dead_scar = {
strategyType="MULTIPHASE", confidence="audited", defaultPhaseId="meteor",
sources={SOURCES.source,SOURCES.wowhead,SOURCES.warcraftWiki},
taskTemplateVersion=1,
defaultTasks={
auditTask("stomp","践踏目标记录","SPELL_AURA_APPLIED",{45185},{
mode="observe",subject="target",phaseId="meteor",
}),
auditTask("meteor-slash","流星猛击承伤记录","SPELL_AURA_APPLIED",{45150},{
mode="observe",subject="target",phaseId="meteor",
}),
auditTask("burn","燃烧目标记录","SPELL_AURA_APPLIED",{46394},{
mode="observe",subject="target",phaseId="burn",
}),
},
phases={
{
id="meteor", name="双侧流星分组", strategyType="STATIC",
summary="两名主坦形成错开的双侧流星锥，治疗与远程均分到两个承伤组，近战留在无招架区。",
assignmentNotes="严格复现来源顺序：死亡骑士坦优先1-2号，其他坦克补位；治疗随后占空位；远程从8号起补位。",
requiredSlots={"p01","p02"},
sharedKinds={MELEE=true},
requiredAreas={
{id="meteor_upper",label="上侧流星组",slots={"p01","p03","p05","p08","p10","p12","p14","p16","p18","p20"},minimum=5,autoFill=false},
{id="meteor_lower",label="下侧流星组",slots={"p02","p04","p06","p07","p09","p11","p13","p15","p17","p19","p21"},minimum=5,autoFill=false},
},
constraints={
hard("两个流星组都必须有坦克并保持足够承伤人数，三层后完成换坦。"),
hard("两坦不能完全相对，必须给近战保留始终可用的无招架侧后区。"),
hard("所有成员保持4-5码间距，燃烧目标不得穿过另一名成员。"),
},
},
{
id="burn", name="燃烧离场", strategyType="DYNAMIC", slots=false, rules=false,
summary="远程或治疗获得燃烧后从本侧流星锥外缘绕行到安全区，结束后原路返回。",
assignmentNotes="燃烧目标随机，本阶段只表达两侧离场路线。",
constraints={hard("燃烧移动时必须绕开所有成员，不能横穿近战或另一侧流星组。")},
zones={
zone("burn_upper","上侧燃烧区",0.18,0.31,0.24,0.24,"MOVE"),
zone("burn_lower","下侧燃烧区",0.18,0.69,0.24,0.24,"MOVE"),
},
routes={
route("burn_upper_route","上侧离场","MOVE",{{0.56,0.37},{0.38,0.28},{0.18,0.31}}),
route("burn_lower_route","下侧离场","MOVE",{{0.56,0.63},{0.38,0.72},{0.18,0.69}}),
},
},
},
},
sw_felmyst = {
strategyType="MULTIPHASE", confidence="guide_template", defaultPhaseId="ground",
sources={SOURCES.raidguru,SOURCES.warcraftWiki},
taskTemplateVersion=1,
defaultTasks={
auditTask("gas-dispel-1","毒气新星群驱一","SPELL_DISPEL",{45855},{
mode="minimum",minimum=1,subject="source",type="dispel",role="HEALER",classes={"PRIEST"},autoAssign=true,phaseId="ground",
}),
auditTask("gas-dispel-2","毒气新星群驱二","SPELL_DISPEL",{45855},{
mode="minimum",minimum=1,subject="source",type="dispel",role="HEALER",classes={"PRIEST"},autoAssign=true,phaseId="ground",
}),
auditTask("gas-dispel-3","毒气新星群驱三","SPELL_DISPEL",{45855},{
mode="minimum",minimum=1,subject="source",type="dispel",role="HEALER",classes={"PRIEST"},autoAssign=true,phaseId="ground",
}),
auditTask("encapsulate-target","压缩点名记录","SPELL_CAST_SUCCESS",{45661},{
mode="observe",subject="target",phaseId="ground",
}),
auditTask("encapsulate-damage","压缩承伤记录","SPELL_DAMAGE",{45662,45665},{
mode="observe",subject="target",events={"SPELL_DAMAGE","SPELL_PERIODIC_DAMAGE"},phaseId="ground",
}),
auditTask("vapor-damage","恶魔蒸汽承伤记录","SPELL_DAMAGE",{45402,46931},{
mode="observe",subject="target",events={"SPELL_DAMAGE","SPELL_PERIODIC_DAMAGE"},phaseId="air",
}),
auditTask("fog-hit","避免腐蚀之雾","SPELL_AURA_APPLIED",{45717},{
mode="maximum",maximum=0,subject="target",phaseId="air",
}),
auditTask("corrosion","腐蚀目标记录","SPELL_AURA_APPLIED",{45866},{
mode="observe",subject="target",phaseId="ground",
}),
},
phases={
{
id="ground", name="地面分组", strategyType="ASSIGNMENT",
summary="坦克单独站正面，近战在背后；治疗与远程分成可被群体驱散覆盖的队形。",
assignmentNotes="坦克1-2号、治疗3-8号、远程9-16号、近战17-25号；输出不足时按职责补空位。",
requiredSlots={"p01","p02"},
requiredAreas={
{id="north_group",label="北侧驱散组",slots={"p03","p04","p05","p09","p10","p11","p12"},minimum=3},
{id="west_group",label="西侧驱散组",slots={"p06","p07","p08","p13","p14","p15","p16"},minimum=3},
},
constraints={
hard("只有坦克站在首领正面，其他成员全部位于背后或侧后。"),
hard("毒气新星后快速群体驱散；分组必须处于负责牧师的群驱覆盖范围内。"),
hard("压缩点名组立即向外散开，保持20码，结束后再回到驱散分组。"),
},
dynamic={"模板采用 RaidGuru / MMO-Champion 的分组与群驱覆盖思路；团队也可在毒气新星后改为全员分散。"},
},
{
id="air", name="空中迷雾三线", strategyType="DYNAMIC", slots=false, rules=false,
summary="两轮恶魔蒸汽后，全团集合观察飞行方向，再在树线、中线、火线之间避让三次腐蚀之雾。",
assignmentNotes="迷雾路线由首领实时飞行方向决定，不能预先固定到个人槽位。",
constraints={
hard("蒸汽点名沿场地边缘蛇形带走，其他人不得踩入毒迹。"),
hard("迷雾开始前全团集合听指挥，确认安全线后整体移动。"),
hard("第三轮迷雾结束后到降落端集合，由坦克重新接怪。"),
},
zones={
zone("fog_tree","树线",0.50,0.20,0.92,0.18,"MOVE"),
zone("fog_middle","中线",0.50,0.50,0.92,0.18,"MOVE"),
zone("fog_fire","火线",0.50,0.80,0.92,0.18,"MOVE"),
},
routes={route("vapor_kite","蒸汽蛇形路线","MOVE",{{0.10,0.18},{0.18,0.32},{0.10,0.48},{0.18,0.64},{0.10,0.82}})},
},
},
},
sw_twins = {
strategyType="MULTIPHASE", confidence="guide_template", defaultPhaseId="sacrolash",
sources={SOURCES.wowhead,SOURCES.warcraftWiki},
taskTemplateVersion=1,
defaultTasks={
auditTask("steal-pyrogenics-1","偷取高热一","SPELL_STOLEN",{45230},{
mode="minimum",minimum=1,subject="source",type="dispel",role="DAMAGER",classes={"MAGE"},autoAssign=true,phaseId="sacrolash",
}),
auditTask("steal-pyrogenics-2","偷取高热二","SPELL_STOLEN",{45230},{
mode="minimum",minimum=1,subject="source",type="dispel",role="DAMAGER",classes={"MAGE"},autoAssign=true,phaseId="sacrolash",
}),
auditTask("steal-pyrogenics-3","偷取高热三","SPELL_STOLEN",{45230},{
mode="minimum",minimum=1,subject="source",type="dispel",role="DAMAGER",classes={"MAGE"},autoAssign=true,phaseId="sacrolash",
}),
auditTask("conflagration","燃烧点名记录","SPELL_AURA_APPLIED",{45342},{
mode="observe",subject="target",phaseId="sacrolash",
}),
auditTask("shadow-nova","暗影新星点名记录","SPELL_AURA_APPLIED",{45329},{
mode="observe",subject="target",phaseId="sacrolash",
}),
auditTask("confounding-blow","混乱重击记录","SPELL_AURA_APPLIED",{45256},{
mode="observe",subject="target",phaseId="sacrolash",
}),
auditTask("blaze-damage","避免踩地板火","SPELL_DAMAGE",{45235},{
mode="maximum",maximum=0,subject="target",events={"SPELL_DAMAGE","SPELL_PERIODIC_DAMAGE"},phaseId="sacrolash",
}),
},
phases={
{
id="sacrolash", name="先暗女·平台站位", strategyType="ASSIGNMENT",
summary="远程与治疗在入口平台集中，近战和坦克下楼优先攻击萨洛拉丝，火女由远程坦牵制。",
assignmentNotes="术士优先3号火女远程坦；普通坦克填1-4号；治疗与远程在5-16号平台；近战在17-25号楼下。",
requiredSlots={"p01","p02","p03"},
requiredAreas={
{id="ledge",label="入口平台",slots={"p05","p06","p07","p08","p09","p10","p11","p12","p13","p14","p15","p16"},minimum=8},
{id="floor",label="楼下暗女组",slots={"p01","p02","p17","p18","p19","p20","p21","p22","p23","p24","p25"},minimum=3},
},
constraints={
hard("萨洛拉丝需要两名威胁位应对混乱重击，所有输出低于两名坦克威胁。"),
hard("燃烧点名者立即远离平台或楼下人群，不能在队友身边完成施法。"),
hard("火女坦持续移动避开烈焰地面，并与暗女近战组保持距离。"),
},
},
{
id="alythess", name="暗女死后集合", strategyType="DYNAMIC", slots=false, rules=false,
summary="萨洛拉丝死亡后，全团转移并集中到奥蕾塞丝附近完成击杀。",
assignmentNotes="这是阶段转换集合，不覆盖开场平台与楼下分配。",
constraints={hard("确认萨洛拉丝死亡后再统一下平台，避免提前引爆燃烧或失去治疗视野。")},
zones={zone("alythess_stack","火女集合",0.34,0.72,0.24,0.22,"STACK")},
routes={route("ledge_down","平台转火","MOVE",{{0.50,0.14},{0.46,0.38},{0.34,0.72}})},
},
},
},
sw_muru = {
strategyType="MULTIPHASE", confidence="guide_template", defaultPhaseId="p1",
sources={SOURCES.wowhead,SOURCES.warcraftWiki},
taskTemplateVersion=1,
defaultTasks={
auditTask("mass-dispel-1","群驱黑暗魔一","SPELL_CAST_SUCCESS",{32375},{
mode="minimum",minimum=1,subject="source",type="dispel",role="HEALER",classes={"PRIEST"},autoAssign=true,phaseId="p1",
}),
auditTask("mass-dispel-2","群驱黑暗魔二","SPELL_CAST_SUCCESS",{32375},{
mode="minimum",minimum=1,subject="source",type="dispel",role="HEALER",classes={"PRIEST"},autoAssign=true,phaseId="p1",
}),
auditTask("steal-spell-fury","偷取法术之怒","SPELL_STOLEN",{46102},{
mode="minimum",minimum=1,subject="source",type="dispel",role="DAMAGER",classes={"MAGE"},autoAssign=true,phaseId="p1",
}),
auditTask("dark-fiend-explosion","避免黑暗魔爆炸","SPELL_DAMAGE",{45944},{
mode="maximum",maximum=0,subject="target",phaseId="p1",
}),
auditTask("darkness-damage","避免踩黑水","SPELL_DAMAGE",{45996,45998,46264},{
mode="maximum",maximum=0,subject="target",events={"SPELL_DAMAGE","SPELL_PERIODIC_DAMAGE"},phaseId="p2",
}),
auditTask("singularity-damage","避免奇点伤害","SPELL_DAMAGE",{46238},{
mode="maximum",maximum=0,subject="target",events={"SPELL_DAMAGE","SPELL_PERIODIC_DAMAGE"},phaseId="p2",
}),
},
phases={
{
id="p1", name="P1 入口击杀区", strategyType="ASSIGNMENT",
summary="两名坦克分别接入口和出口血精灵，虚空哨兵拉到外侧；大团在入口侧集中处理小怪。",
assignmentNotes="坦克先填1-3号，治疗4-9号，远程10-17号，近战18-25号；输出按近远程补位。",
requiredSlots={"p01","p02","p03"},
sharedAll=false,
constraints={
hard("入口与出口两批血精灵必须同时有人接怪，远侧小怪通过嘲讽、沉默或误导带回击杀区。"),
hard("虚空哨兵与大团保持十码以上，死亡后立即控制或击杀虚空魔。"),
hard("黑暗出现时全团离开穆鲁中央，群体驱散必须准确覆盖八只黑暗魔。"),
},
zones={
zone("kill_zone","入口击杀区",0.30,0.55,0.34,0.46,"RAID"),
zone("sentinel_zone","哨兵处理区",0.50,0.83,0.28,0.20,"TANK"),
},
routes={route("far_adds","出口小怪拉回","MOVE",{{0.88,0.35},{0.66,0.44},{0.38,0.54}})},
},
{
id="p2", name="P2 熵魔转场", strategyType="DYNAMIC", slots=false, rules=false,
summary="清完残余小怪后接住熵魔，全团围绕首领移动躲避黑水和奇点。",
assignmentNotes="P2 地面危险区域持续变化，只保留坦克接怪点和团队移动方向。",
constraints={
hard("转阶段先清完P1残余小怪，再集中输出熵魔。"),
hard("黑水落脚立即横向离开；奇点接近时全团同向让路，禁止挤入死角。"),
},
markers={mark(0.50,0.50,"熵魔","BOSS",ICON.BOSS)},
routes={route("entropius_move","熵魔绕场","MOVE",{{0.34,0.62},{0.40,0.38},{0.62,0.34},{0.70,0.58},{0.50,0.72}},true)},
},
},
},
sw_sunwell = {
strategyType="MULTIPHASE", confidence="audited", defaultPhaseId="spread",
sources={SOURCES.source,SOURCES.wowhead,SOURCES.warcraftWiki},
taskTemplateVersion=1,
defaultTasks={
auditTask("fire-bloom-target","火焰之花点名记录","SPELL_AURA_APPLIED",{45641},{
mode="observe",subject="target",phaseId="spread",
}),
auditTask("fire-bloom-friendly","火焰之花避免误伤","SPELL_DAMAGE",{45642},{
mode="maximum",maximum=0,subject="source",events={"SPELL_DAMAGE","SPELL_PERIODIC_DAMAGE"},phaseId="spread",
}),
auditTask("shadow-spike","暗影之刺承伤记录","SPELL_DAMAGE",{45885},{
mode="observe",subject="target",phaseId="spread",
}),
auditTask("armageddon","避免末日决战伤害","SPELL_DAMAGE",{45915},{
mode="maximum",maximum=0,subject="target",phaseId="spread",
}),
auditTask("dragon-control-1","控龙一","SPELL_AURA_APPLIED",{45839},{
mode="minimum",minimum=1,subject="target",role="DAMAGER",classes={"MAGE"},autoAssign=true,phaseId="darkness",
}),
auditTask("dragon-control-2","控龙二","SPELL_AURA_APPLIED",{45839},{
mode="minimum",minimum=1,subject="target",role="DAMAGER",classes={"MAGE"},autoAssign=true,phaseId="darkness",
}),
auditTask("blue-shield-1","蓝龙护盾一","SPELL_CAST_SUCCESS",{45848},{
mode="minimum",minimum=1,subject="source",role="DAMAGER",classes={"MAGE"},autoAssign=true,phaseId="darkness",
}),
auditTask("blue-shield-2","蓝龙护盾二","SPELL_CAST_SUCCESS",{45848},{
mode="minimum",minimum=1,subject="source",role="DAMAGER",classes={"MAGE"},autoAssign=true,phaseId="darkness",
}),
auditTask("darkness-cast","千魂之暗读条记录","SPELL_CAST_SUCCESS",{46605},{
mode="observe",subject="source",phaseId="darkness",
}),
auditTask("dragon-haste","龙息急速覆盖记录","SPELL_AURA_APPLIED",{45856},{
mode="observe",subject="target",phaseId="darkness",
}),
auditTask("dragon-recovery","龙息恢复覆盖记录","SPELL_AURA_APPLIED",{45860},{
mode="observe",subject="target",phaseId="darkness",
}),
},
phases={
{
id="spread", name="P2-P5 半场分散", strategyType="STATIC",
summary="坦克与近战在首领一侧，治疗和远程只占半场分散位，保证能快速进入蓝龙护盾。",
assignmentNotes="严格复现来源顺序：法师先占7-8号控龙位，治疗随后占空位，远程最后补齐。",
sharedKinds={TANK=true,MELEE=true},
constraints={
hard("火焰之花期间保持十码分散，点名者不得向千魂集合点靠拢。"),
hard("全团只使用约半个房间，确保千魂读条时能及时进入蓝龙护盾。"),
hard("远程优先转火护盾宝珠，阶段越后同时出现的宝珠越多。"),
},
dynamic={"邪恶镜像、暗影之刺和末日决战都需要临时离位，机制结束后从外侧归位。"},
},
{
id="darkness", name="千魂护盾集合", strategyType="DYNAMIC", slots=false, rules=false,
summary="千魂之暗读条时全团向约定蓝龙护盾点集合，火焰之花目标先停在外缘，护盾展开后再进入。",
assignmentNotes="护盾点取决于当轮被激活的宝珠和控龙者位置，不预先固定个人像素。",
constraints={
hard("控龙者先覆盖急速与恢复龙息，再在千魂结束前展开蓝龙护盾。"),
hard("火焰之花目标不能提前进入大团；护盾展开后再进可同时清除点名。"),
hard("千魂结束后立即重新分散，避免下一轮火焰之花和烈焰之刺连锁。"),
},
zones={zone("blue_shield","蓝龙护盾集合",0.56,0.62,0.24,0.24,"STACK")},
routes={
route("shield_left","左侧进盾","MOVE",{{0.25,0.48},{0.40,0.56},{0.56,0.62}}),
route("shield_right","右侧进盾","MOVE",{{0.82,0.45},{0.70,0.54},{0.56,0.62}}),
},
},
},
},
zug_courtyard = {
strategyType="MULTIPHASE", confidence="source_template", defaultPhaseId="overlap",
sources={SOURCES.replay,SOURCES.icy,SOURCES.source},
phases={
{
id="overlap", name="P1 小队重叠", strategyType="GROUP_ASSIGNMENT", slots=false, rules=false,
summary="保留五个小队的参考集合点；Boss 与蛇怪分侧，近战处理蛇怪，远程攻击首领。",
assignmentNotes="默认1-2队近战、3-4队远程、5队治疗；小队编号可手工调整。",
constraints={
hard("主坦将首领与蛇怪分开，副坦和近战在另一侧处理蛇怪。"),
hard("P1 近战不能贴近首领，远程保持对首领输出。"),
template("五个小队各自重叠在固定参考点属于团队模板，不是首领机制要求的唯一站法。"),
},
markers={
mark(0.78,0.69,"坦克","TANK",ICON.TANK),
mark(0.74,0.63,"温诺希斯","BOSS",ICON.BOSS),
},
groupSlots={
{id="g01",x=0.67,y=0.65,label="近战区",preferred=1},
{id="g02",x=0.74,y=0.53,label="近战区",preferred=2},
{id="g03",x=0.51,y=0.58,label="远程区",preferred=3},
{id="g04",x=0.71,y=0.33,label="远程区",preferred=4},
{id="g05",x=0.51,y=0.32,label="治疗区",preferred=5},
},
},
{
id="kite", name="P2 绕场风筝", strategyType="DYNAMIC", slots=false, rules=false,
summary="蛇形态开始后大团沿庭院边缘同向移动，避免毒云切断退路。",
assignmentNotes="P2 使用团队移动路线，不进行个人静态分配。",
constraints={hard("全团统一方向移动，禁止逆向穿过毒云。"),hard("坦克保持首领头部远离移动中的大团。")},
routes={route("court_loop","绕场路线","MOVE",{{0.72,0.72},{0.50,0.78},{0.30,0.66},{0.30,0.40},{0.50,0.25},{0.72,0.36}},true)},
markers={mark(0.72,0.72,"起点","STACK",ICON.STACK)},
},
},
},
zug_terrace = {
strategyType="MULTIPHASE", confidence="audited", defaultPhaseId="spread",
sources={SOURCES.replay,SOURCES.wowhead,SOURCES.source},
phases={
{
id="spread", name="常规分散", strategyType="STATIC",
summary="坦克在北侧控制首领，近战背后集中，治疗和远程分列两侧。",
assignmentNotes="1-5号治疗，6-17号远程。",
sharedKinds={TANK=true,MELEE=true},
constraints={hard("远程与治疗保持分散，避免腐化之血连锁。"),template("两侧分布要给毒蛇拉入和击杀留出路径。")},
},
{
id="siphon", name="虹吸前集合", strategyType="DYNAMIC", slots=false, rules=false,
summary="生命虹吸前，全团在指定区域集合并确保获得毒血；结束后重新分散。",
assignmentNotes="集合动作由时间点触发，不覆盖常规分散分配。",
constraints={hard("虹吸前必须确认毒血已覆盖需要的成员。"),hard("虹吸结束后立即回到左右分散区域。")},
markers={mark(0.50,0.63,"虹吸集合","STACK",ICON.STACK),mark(0.50,0.83,"哈卡","BOSS",ICON.BOSS)},
zones={zone("siphon_stack","虹吸集合",0.50,0.63,0.28,0.20,"STACK")},
routes={route("return_spread","集合后分散","MOVE",{{0.50,0.63},{0.34,0.54},{0.18,0.50}}),route("return_spread_2","集合后分散","MOVE",{{0.50,0.63},{0.66,0.54},{0.82,0.50}})},
},
},
},
mc_lava = {
strategyType="MULTIPHASE", confidence="audited", defaultPhaseId="main",
sources={SOURCES.replay,SOURCES.icy,SOURCES.source},
phases={
{
id="main", name="常规分散", strategyType="STATIC",
summary="坦克控制首领朝向，近战在侧后方，治疗和远程沿平台外圈分散。",
assignmentNotes="1-2号优先奶骑，3-5号其他治疗，6-15号远程。",
sharedKinds={TANK=true,MELEE=true},
constraints={hard("远程与治疗保持八码分散，避免拉格纳罗斯之怒连锁击飞。"),hard("近战组与坦克组分开，首领正面只保留坦克。")},
},
{
id="recover", name="击飞后归位", strategyType="DYNAMIC", slots=false, rules=false,
summary="被击飞后从平台边缘沿最近安全路线返回原扇区，避免横穿近战区。",
assignmentNotes="原槽位保存在常规分散阶段，本阶段只表达返回路径。",
constraints={hard("返回时避开熔岩边缘和首领正面。"),template("优先沿本人原扇区径向返回，不进行整团换位。")},
markers={mark(0.50,0.62,"拉格纳罗斯","BOSS",ICON.BOSS)},
routes={
route("return_left","左侧归位","MOVE",{{0.10,0.18},{0.20,0.35},{0.34,0.52}}),
route("return_right","右侧归位","MOVE",{{0.90,0.20},{0.79,0.37},{0.66,0.52}}),
route("return_bottom","后侧归位","MOVE",{{0.50,0.06},{0.50,0.28},{0.50,0.44}}),
},
},
},
},
}
local function normalizePhase(map, phase)
phase.id = tostring(phase.id or "default")
phase.name = tostring(phase.name or phase.id)
phase.strategyType = phase.strategyType or map.strategyType or "STATIC"
phase.slots = phase.slots == false and {} or phase.slots or map.slots or {}
phase.rules = phase.rules == false and {} or phase.rules or map.rules or {}
phase.markers = phase.markers or map.markers or {}
phase.zones = phase.zones or {}
phase.routes = phase.routes or {}
phase.groupSlots = phase.groupSlots or {}
phase.constraints = phase.constraints or {}
phase.dynamic = phase.dynamic or {}
phase.requiredSlots = phase.requiredSlots or {}
phase.requiredAreas = phase.requiredAreas or {}
phase.sharedKinds = phase.sharedKinds or {}
phase.sharedAll = phase.sharedAll and true or false
phase.slotById = {}
for _, slot in ipairs(phase.slots or {}) do phase.slotById[slot.id] = slot end
phase.groupSlotById = {}
for _, slot in ipairs(phase.groupSlots) do phase.groupSlotById[slot.id] = slot end
return phase
end
RM.TacticCatalog = tactics
for mapId, tactic in pairs(tactics) do
local map = RM.MapById[mapId]
if map then
map.strategyType = tactic.strategyType or "STATIC"
map.confidence = tactic.confidence or "template"
map.sources = tactic.sources or {}
map.defaultPhaseId = tactic.defaultPhaseId
map.phases = tactic.phases or {}
map.taskTemplateVersion = math.max(0, math.floor(tonumber(tactic.taskTemplateVersion) or 0))
map.defaultTasks = tactic.defaultTasks or {}
map.phaseById = {}
for _, phase in ipairs(map.phases) do
normalizePhase(map, phase)
map.phaseById[phase.id] = phase
end
if not map.phaseById[map.defaultPhaseId] then
map.defaultPhaseId = map.phases[1] and map.phases[1].id or nil
end
local contract = {map.id, tostring(map.templateVersion or 1), "tasks:"..tostring(map.taskTemplateVersion)}
for _, phase in ipairs(map.phases) do
contract[#contract + 1] = table.concat({"phase",phase.id,phase.strategyType,tostring(#phase.slots),tostring(#phase.groupSlots)},":")
for _, slot in ipairs(phase.slots) do
contract[#contract + 1] = table.concat({"slot",phase.id,slot.id,string.format("%.4f",slot.x),string.format("%.4f",slot.y)},":")
end
for _, groupSlot in ipairs(phase.groupSlots) do
contract[#contract + 1] = table.concat({"group",phase.id,groupSlot.id,string.format("%.4f",groupSlot.x),string.format("%.4f",groupSlot.y)},":")
end
for _, rule in ipairs(phase.rules) do
local classes = table.concat(rule.classes or {},",")
local ruleSlots = {}
for _, index in ipairs(rule.slots or {}) do ruleSlots[#ruleSlots + 1] = tostring(index) end
contract[#contract + 1] = table.concat({"rule",phase.id,tostring(rule.kind or ""),classes,table.concat(ruleSlots,","),tostring(rule.limit or "")},":")
end
for _, area in ipairs(phase.requiredAreas) do
contract[#contract + 1] = table.concat({
"area",phase.id,tostring(area.id or ""),tostring(area.minimum or 1),
area.autoFill == false and "validate" or "fill",table.concat(area.slots or {},","),
},":")
end
end
for _, task in ipairs(map.defaultTasks) do
local spellIds={};for _,spellId in ipairs(task.spellIds or {}) do spellIds[#spellIds+1]=tostring(spellId) end
local events={};for _,event in ipairs(task.events or {task.event}) do events[#events+1]=tostring(event) end
contract[#contract + 1] = table.concat({
"task",tostring(task.templateId or ""),tostring(task.mode or "minimum"),
tostring(task.subject or "source"),table.concat(events,","),table.concat(spellIds,","),
tostring(task.minimum or ""),tostring(task.maximum or ""),tostring(task.phaseId or ""),
},":")
end
map.templateContract = tostring(U.Checksum(table.concat(contract,";")))
end
end
function RM:GetMapPhase(mapOrId, phaseId)
local map = type(mapOrId) == "table" and mapOrId or self:GetMap(mapOrId)
if not map then return nil end
return map.phaseById and (map.phaseById[phaseId] or map.phaseById[map.defaultPhaseId])
end
function RM:GetStrategyLabel(strategyType)
return ({
FREEFORM="自由布局", STATIC="固定站位", ASSIGNMENT="职责分区",
GROUP_ASSIGNMENT="小队区域", GROUP_SPLIT="均衡分队", DYNAMIC="动态走位",
MULTIPHASE="多阶段",
})[strategyType] or tostring(strategyType or "战术模板")
end
function RM:GetConfidenceLabel(confidence)
return ({
audited="机制已审计",
guide_template="攻略来源模板",
source_template="来源模板",
custom="自定义",
})[confidence] or tostring(confidence or "模板")
end
