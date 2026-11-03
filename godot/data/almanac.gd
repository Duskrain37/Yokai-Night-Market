## 图鉴：草木志 18 篇、恶客录 12 篇。
##
## 来历与引语照抄 v0.2.4 的 www/src/content/almanac.js。
## 「本事」与「底细」不再手写数字，而是从 data/content.gd 与 data/upgrades.gd 推导，
## 数值一改图鉴就跟着改——v0.2.4 里图鉴与代码是两份手抄数据，曾因此说谎。
class_name Almanac
extends RefCounted

const PLANTS = {
	"lantern": {
		"epithet": "摊前第一盏",
		"story": "收摊以后，别的物件都睡了，只有它还亮着。灯芯是摊主从河灯会上换来的，据说照过谁的回头路。它不爱说话，只在你数香火时晃一下，像在提醒：账可以慢点算，灯不能灭。",
		"quote": "灯亮着，摊子就还在。",
	},
	"shooter": {
		"epithet": "手熟的黑签",
		"story": "签筒原是算命摊上的旧物，签文被雨水泡烂了，只剩筒身还硬朗。它把剩下的竹签当暗器使，起初只为了吓野猫，后来发现对恶客也挺好使。每回甩签前都要抖三下，像在给自己壮胆。",
		"quote": "不求百发百中，只求你别过来。",
	},
	"wall": {
		"epithet": "不肯挪窝的老石头",
		"story": "石磨在夜市口蹲了很多年，磨过豆子、磨过辣椒，也磨过几个不长眼的小贼的鞋底。它不爱说话，磨齿一响，整条街就知道今晚有人要吃亏。摊主给它系过一条红绳，后来被它自己磨断了。",
		"quote": "想过去？先问磨齿。",
	},
	"bomb": {
		"epithet": "一响就散的急脾气",
		"story": "它本是年初一早上用的，被摊主忘在柜底，一忘就是一整年。再拿出来时，它已经憋坏了。引信一点，它先骂一句，再把整条街炸得亮堂堂。没人记得它炸完以后去了哪，大概是被自己吵没了。",
		"quote": "别劝，劝就是炸。",
	},
	"mushroom": {
		"epithet": "坟头土里长出来的",
		"story": "夜市后巷的坟头土最养菇。它埋下去时不声不响，伞盖下压着两张旧符，像替谁守着最后一口气。等它鼓起来，谁踩上去，它就把攒了半宿的鬼火全喷出来，连自己一起烧没。",
		"quote": "别踩，下面埋着东西。",
	},
	"bell": {
		"epithet": "先声夺人",
		"story": "铜铃挂在摊棚角上，平时只是摆设。直到有一晚，饿鬼踩着铃影过来，它突然自己响了。声音不大，却让整条街的恶客都慢了半拍。从那以后它有了差事：别人动手之前，先由它开口。",
		"quote": "先听个响，再谈别的。",
	},
	"censer": {
		"epithet": "账房檐下的老炉",
		"story": "夜市账房门口有只三足铜炉，常年压着半本赊账簿。账房先生说，香灰里埋着往年没还清的名字，所以炉子总在半夜自己冒烟。它不记账，只把那些名字一圈圈熏开，像替谁把没说完的话说完。",
		"quote": "账可以慢算，烟不能断。",
	},
	"umbrella": {
		"epithet": "收得下夜客，也收得下香火",
		"story": "这把油纸伞替摊娘挡过三年夜雨，伞面上画的海棠早褪了色。后来夜市里多了一种说法：撑开它挡雨，收起它收妖。伞骨一合，饿鬼纸人就被卷进伞腹；再撑开时，只剩一团香火落在摊前。",
		"quote": "伞下这寸地，归我管。",
	},
	"lion": {
		"epithet": "初一请来的狮头",
		"story": "年初一舞狮队从摊前过，把这只旧狮头落在了货架底下。摊主嫌它占地方，几次想扔，最后都留了下来。入夜后它会自己抖毛，听见恶客的脚步就低头撞过去，撞完了还要甩甩鬃毛，像在等一声叫好。",
		"quote": "狮子不咬人，狮子只撞。",
	},
	"cat": {
		"epithet": "追着最近那口气走",
		"story": "夜市西头的旧灯架上挂着一截狐尾形状的灯芯。摊主说，那是只走丢的狐妖留下的最后一点火。它不照路，只照人：谁身上的阴气最重，尾火就朝谁飘过去，绕一圈再回来，像狐狸在确认猎物还在不在。",
		"quote": "别回头，它已经看见你了。",
	},
	"shell": {
		"epithet": "老龟留下的半间屋",
		"story": "河滩上捡来的老龟甲，壳口磨得发亮。摊主把它罩在怕风的物件上，后来发现恶客啃壳比啃摊子还费劲。壳里那株植物照常做事，只是从此多了一层沉默的屋顶。",
		"quote": "壳在，摊就在。",
	},
	"lobber": {
		"epithet": "一碗会自己动手的宵夜",
		"story": "甜品摊收工后，锅里总剩几颗汤圆。它们吸了夜市的水汽，慢慢长出小手小脚，最见不得街尾有恶客站着。汤圆仔不会走，只会把同伴一颗颗抛出去，弧线落得又准又黏。",
		"quote": "趁热，别躲。",
	},
	"torch": {
		"epithet": "整条街的火都借它一口",
		"story": "夜市收摊前，摊主会把各家的炭火并进这只旧铜盆。火苗不高，却认路：签筒的竹签、汤圆的糖壳、狐尾的尾火从旁边过，都会被它舔上一口，飞出去时带着一层暖光。",
		"quote": "火不分家，光借你一半。",
	},
	"star": {
		"epithet": "一盏灯巡五方",
		"story": "庙会拆台时落下的五角巡灯，骨架是五根旧竹篾，灯面上画着五个方位。点起来以后，它不肯只照自己摊前，总要朝五个方向各送一道灯焰，像在替谁巡夜。",
		"quote": "五个方向，都得亮着。",
	},
	"needle": {
		"epithet": "纸扎铺里最硬的一根",
		"story": "纸扎铺的针线盒底压着一根黑铁针，缝过纸人，也缝过不该缝的东西。它不认纸壳、不认陶瓮，只认皮囊底下那口气。摊主说，针尖凉，是因为它走过的路都比别处深。",
		"quote": "壳再厚，也隔不住一口气。",
	},
	"judge": {
		"epithet": "挂在门后的那双眼",
		"story": "旧货摊最里面挂着一幅钟馗像，画工不算好，眼睛却像一直睁着。夜市闹得最凶那晚，画里的人忽然抬了抬袖子，街口的恶客就退了三步。第二天摊主给它添了一炷香，再没摘下来。",
		"quote": "这条街，看着我。",
	},
	"lily": {
		"epithet": "水面上借你一块落脚地",
		"story": "暗河里漂着几片不肯沉的夜莲，叶脉里像藏着一线灯火。摊主把灯灰撒下去，莲叶便停在水面不动，成了给别的植物落脚的一块浮台。",
		"quote": "先有叶，再有花。",
	},
	"kelp": {
		"epithet": "这条臭水沟会自己收人",
		"story": "臭水沟底缠着一团发青的水藻，平时像一堆烂绳。等恶客踩进水面，它才突然收紧，把对方拖进河泥里。拖完这一次，藻叶也散了。",
		"quote": "水底下，有人拉你。",
	},
}

const ZOMBIES = {
	"ghost": {
		"epithet": "闻着香火来的",
		"story": "子时过后，街口总会多出几道影子。它们不记得生前叫什么，只记得夜市的味道。饿鬼走得慢，啃东西也不快，但它们从不在乎——反正天还长，摊子总会打烊。",
		"counter": "前几波的主要杂兵；连发与范围清场都能轻松处理，别让它们磨到门口。",
		"quote": "就一口，真的就一口。",
	},
	"paper": {
		"epithet": "一戳就散，先拿张纸挡着",
		"story": "纸人是白事铺里扎剩下的边角料，被野风吹到夜市，捡了张旧告示糊在身上，就当自己有了脸。它很爱惜那层纸壳，哪怕被竹签戳得叮当响，也要先把里头那口纸气撑住。",
		"counter": "先用连发撕壳，再用铜铃拖住；没破壳前别只靠单发签筒。",
		"quote": "别碰脸，脸是借来的。",
	},
	"mountain": {
		"epithet": "不讲道理的大块头",
		"story": "山魈是从城外山上下来的。据说今年山里的果子不好，它一路闻到夜市，就没打算回去。它个头大、脾气坏，啃石磨像啃豆腐，偶尔还会停下来看看摊主有没有藏酒。",
		"counter": "石磨和铜铃一起拖，再用多路签筒集火；单靠一株签筒顶不住。",
		"quote": "果子呢？没有果子就啃摊子。",
	},
	"tongue": {
		"epithet": "舌头比脚先到",
		"story": "长舌鬼生前是个爱传闲话的，死后舌头没缩回去，越长越红。它走路急，吃相更急，隔着半个摊子就把舌头探过来。摊主们说，听它嚼东西的动静，比听它说话还难受。",
		"counter": "在它够到之前用铜铃或香炉减速，再让签筒点掉；纸伞能把它收进伞腹，但别让它先啃到伞面。",
		"quote": "我就舔一下，不咬。",
	},
	"mourner": {
		"epithet": "一哭，整条街都急",
		"story": "哭丧鬼原是白事铺请来的哭灵人，哭了一辈子别人的丧事，最后没人替她哭。她夜里沿着摊位慢慢走，哭声不大，却让周围的恶客都跟着心慌，脚步快得像是有人在后面催。",
		"counter": "优先点杀，别让她站在怪堆里；减速能抵消她带来的加速，范围伤害也容易顺带清掉。",
		"quote": "别急，还没轮到你。",
	},
	"sedan": {
		"epithet": "轿子没落，客人还在",
		"story": "抬轿鬼抬着一顶褪色的红轿，轿帘后面坐着谁，没人看清过。它们走得不快，轿子却硬得很，像把一整场喜事都糊在了木头上。轿破的时候，里头的东西会自己下来走，一边走一边找原来的路。",
		"counter": "先用签筒磨轿，再用爆竹或香炉一次收掉跌出来的饿鬼；铜铃能把整队拖在门口。透骨针可以绕过轿壳直接伤本体，适合收尾。",
		"quote": "起轿——别问去哪。",
	},
	"straw": {
		"epithet": "破斗笠遮半张脸",
		"story": "斗笠鬼生前是赶夜路的挑夫，死后还记着那顶破斗笠。斗笠压得很低，只露出半张嘴，走路一晃一晃，像担子还在肩上。谁要掀它的斗笠，它就先啃谁家的摊脚。",
		"counter": "连发签筒很快就能打掉斗笠；透骨针可以跳过斗笠直接杀本体。",
		"quote": "别掀，风大。",
	},
	"stonehat": {
		"epithet": "把碑帽戴在头上",
		"story": "石帽鬼从乱葬岗来，头上扣着半块碑帽，压得脖子歪向一边。它走得不快，可那顶石帽替它挨过不少竹签。石帽碎了以后，它反倒走得更急，像终于卸下了什么。",
		"counter": "先集中火力碎帽，再补刀；透骨针无视石帽，能省下破帽时间。",
		"quote": "碑上没名字，帽子有。",
	},
	"bucket": {
		"epithet": "陶瓮扣头，油盐不进",
		"story": "瓮头鬼从酒坊废墟里捡来一只裂口陶瓮，扣在头上就再没摘过。瓮里闷着它自己的回声，敲起来嗡嗡响。它走得很慢，却极有耐心，像认定夜市欠它一笔旧账。",
		"counter": "用高伤害或易伤集火破瓮；透骨针绕过陶瓮，最好和签筒混编。",
		"quote": "瓮里有酒吗？有，我。",
	},
	"vault": {
		"epithet": "幡杆一撑，跳过第一摊",
		"story": "跳幡鬼原是个送葬班子的学徒，死后还攥着那根引魂幡杆。它遇到第一株植物会撑幡跳过，落地后幡杆一扔，才老老实实开始啃。那一跳不高，却总让人措手不及。",
		"counter": "在它落点后方再补一株植物，或用铜铃在它起跳前减速；透骨针可以直接消耗它的本体。",
		"quote": "借过，借过。",
	},
	"artisan": {
		"epithet": "给小鬼糊一身纸甲",
		"story": "纸扎匠背着一整架糊好的纸甲，走起路来哗啦响。它不急着啃摊子，先给街上的小鬼一人发一副纸甲，像在替谁办一场迟到的差事。纸甲不值钱，却能让饿鬼多挨好几下。",
		"counter": "优先点杀纸扎匠，别让它反复发甲；透骨针可以直接伤它本体，狐尾灯也能跨行追它。",
		"quote": "穿上，体面点走。",
	},
	"ironjudge": {
		"epithet": "铁面之下，没有冤魂",
		"story": "铁面判官从城隍庙的偏殿里走出来，脸上那副铁面具锈得看不出表情。它每一步都像在敲惊堂木，走过的地方，摊板会轻轻发颤。没人知道它要审谁，只知道它从不空手回去。",
		"counter": "铁面判官是硬仗：先用易伤与高伤射弹破面，再让透骨针收本体；铜铃和纸伞能拖住它的脚步。",
		"quote": "跪下，报上名来。",
	},
}

## 「格」是图鉴唯一的长度单位：1 格 = 一个棋盘格宽。
## 必须与 Geo.CELL_W 一致——之前沿用 v0.2.4 JS 的 88，图鉴里的射程一律比实际短 18%。
const CELL_PX = 104.0


static func in_cells(px: float, decimals: int = 1) -> String:
	var cells = px / CELL_PX
	var text = String.num(cells, decimals)
	text = text.rstrip("0").rstrip(".")
	return "%s 格" % text


static func percent(value: float) -> String:
	return "%d%%" % int(round(value * 100.0))


static func plant_rows(type: String) -> Array:
	var d: Dictionary = Content.PLANTS[type]
	var rows: Array = [
		_row("香火", str(d["cost"]), "cost"),
		_row("耐久", str(d.get("hp", 0)), "hp"),
		_row("冷却", "%d 秒" % int(d.get("cooldown", 0)), "time"),
	]
	match type:
		"lantern":
			var produce: Dictionary = d["produce"]
			rows.append(_row("单次产量", str(int(produce["value"])), "gold"))
			rows.append(_row("产出间隔", "%s 秒" % String.num(produce["interval"], 1), "time"))
			rows.append(_row("首次产出", "%s 秒" % String.num(produce["first"], 1), "time"))
			rows.append(_row("增幅", "取最高，不叠加", "desc"))
		"shooter":
			var shot: Dictionary = d["shot"]
			rows.append(_row("单发伤害", str(int(shot["damage"])), "atk"))
			rows.append(_row("攻击间隔", "%s 秒" % String.num(shot["interval"], 1), "time"))
			rows.append(_row("范围", "本行前方", "desc"))
		"wall":
			rows.append(_row("攻击", "无 · 碎石路需升阶", "desc"))
			rows.append(_row("定位", "肉盾 · 挡啃食", "desc"))
		"mushroom":
			var mine: Dictionary = d["mine"]
			rows.append(_row("鬼火伤害", str(int(mine["damage"])), "atk"))
			rows.append(_row("长成时间", "%d 秒" % int(mine["arm"]), "time"))
			rows.append(_row("类别", "灰烬 · 一次性", "cost"))
		"bomb":
			var bomb: Dictionary = d["bomb"]
			rows.append(_row("爆炸伤害", str(int(bomb["damage"])), "atk"))
			rows.append(_row("引信", "%s 秒" % String.num(bomb["fuse"], 1), "time"))
			rows.append(_row("范围", in_cells(bomb["radius"]), "desc"))
		"bell":
			var pulse: Dictionary = d["pulse"]
			rows.append(_row("减速", percent(Content.PLANTS["bell"]["pulse"]["slow"]), "time"))
			rows.append(_row("持续", "%s 秒" % String.num(pulse["slow_duration"], 1), "time"))
			rows.append(_row("摇铃间隔", "%s 秒" % String.num(pulse["interval"], 1), "time"))
			rows.append(_row("范围", "本行前方", "desc"))
		"censer":
			var cd: Dictionary = d["censer"]
			rows.append(_row("香雾伤害", str(int(float(cd["damage"]))), "atk"))
			rows.append(_row("喷烟间隔", "%s 秒" % String.num(float(cd["interval"]), 1), "time"))
			rows.append(_row("半径", in_cells(float(cd["radius"])), "desc"))
		"umbrella":
			var chomp: Dictionary = d["chomp"]
			rows.append(_row("收妖时间", "%s 秒" % String.num(chomp["chew"], 1), "time"))
			rows.append(_row("对大型", "%d 伤害" % int(chomp["large_damage"]), "atk"))
			rows.append(_row("收妖范围", in_cells(chomp["reach"]), "desc"))
			rows.append(_row("特性", "非大型即收", "desc"))
		"lion":
			var melee: Dictionary = d["melee"]
			rows.append(_row("撞头伤害", str(int(melee["damage"])), "atk"))
			rows.append(_row("攻击间隔", "%s 秒" % String.num(melee["interval"], 2), "time"))
			rows.append(_row("触及距离", in_cells(melee["reach"]), "desc"))
			rows.append(_row("击退", "%s 格" % String.num(melee["knock_cells"], 1), "time"))
		"cat":
			var homing: Dictionary = d["homing"]
			rows.append(_row("尾火伤害", str(int(homing["damage"])), "atk"))
			rows.append(_row("攻击间隔", "%s 秒" % String.num(homing["interval"], 1), "time"))
			rows.append(_row("索敌", "全场最近", "desc"))
			rows.append(_row("特性", "跨行追踪", "desc"))
		"shell":
			rows.append(_row("护罩耐久", str(int(Upgrades.EFFECTS["shell"]["hp"])), "hp"))
			rows.append(_row("种法", "罩在已有草木上", "desc"))
			rows.append(_row("类别", "护罩 · 不可升阶", "cost"))
			rows.append(_row("特性", "铲子可单独拆下", "desc"))
		"lobber":
			var lob: Dictionary = d["lob"]
			rows.append(_row("汤圆伤害", str(int(lob["damage"])), "atk"))
			rows.append(_row("投掷间隔", "%s 秒" % String.num(lob["interval"], 1), "time"))
			rows.append(_row("目标", "本行最右", "desc"))
			rows.append(_row("轨迹", "抛物线越过前排", "desc"))
		"torch":
			var t_orch: Dictionary = Upgrades.EFFECTS["torch"]
			rows.append(_row("射弹增幅", "+%d%% 伤害" % int(round(t_orch["buff"][0] * 100)), "atk"))
			rows.append(_row("作用", "穿过火盆的友方射弹", "desc"))
			rows.append(_row("类别", "增幅 · 不主动攻击", "cost"))
			rows.append(_row("特性", "同类取最高", "desc"))
		"star":
			var star: Dictionary = d["star"]
			rows.append(_row("每道伤害", str(int(star["damage"])), "atk"))
			rows.append(_row("发灯间隔", "%s 秒" % String.num(star["interval"], 1), "time"))
			rows.append(_row("范围", "五向各一道", "desc"))
		"needle":
			var needle: Dictionary = d["needle"]
			rows.append(_row("本体伤害", str(int(needle["damage"])), "atk"))
			rows.append(_row("出针间隔", "%s 秒" % String.num(needle["interval"], 1), "time"))
			rows.append(_row("目标", "优先带护具", "desc"))
			rows.append(_row("特性", "无视护具", "desc"))
		"judge":
			var judge: Dictionary = d["judge"]
			rows.append(_row("显灵伤害", str(int(judge["damage"])), "atk"))
			rows.append(_row("显灵间隔", "%s 秒" % String.num(judge["interval"], 1), "time"))
			rows.append(_row("触及距离", in_cells(judge["reach"]), "desc"))
			rows.append(_row("击退", "%s 格" % String.num(judge["knock_cells"], 1), "time"))
		"lily":
			rows.append(_row("水面", "必须", "desc"))
			rows.append(_row("作用", "承载一株草木", "desc"))
			rows.append(_row("类别", "浮台 · 不可升阶", "cost"))
		"kelp":
			var tangle: Dictionary = d["tangle"]
			rows.append(_row("拖拽伤害", str(int(tangle["damage"])), "atk"))
			rows.append(_row("拖拽时间", "%s 秒" % String.num(tangle["drag"], 1), "time"))
			rows.append(_row("范围", in_cells(tangle["range"]), "desc"))
			rows.append(_row("类别", "灰烬 · 一次性", "cost"))
	return rows


static func _row(label: String, value: String, tone: String) -> Dictionary:
	return {"label": label, "value": value, "tone": tone}


## 定位一句：这株管什么、多少钱、白板最要紧的那个数。
## 数字全部从底细行取，图鉴不再另抄一份，改了数值这句话跟着变。
static func plant_pitch(type: String) -> String:
	var d: Dictionary = Content.PLANTS[type]
	var rows := plant_rows(type)
	var head := ""
	if rows.size() > 3:
		head = "，%s %s" % [String(rows[3]["label"]), String(rows[3]["value"])]
	return "%s · 香火 %d · 冷却 %d 秒%s。" % [String(d["role"]), int(d["cost"]),
		int(d.get("cooldown", 0)), head]


## 「本事」：由数据推导的一句话说明，含基础数值与升阶方向。
static func plant_ability(type: String) -> String:
	const GUIDE = {
	"lantern": "持续产出香火，是添置草木与进化的根本。适合放在后排；进化后可以增加产量、加快产出，或照亮前方友军，让它们打得更重。",
	"shooter": "守住本行前方的恶客。连发擅长磨掉护具，借射可以照应相邻行，大签则能打出重击。把石磨放在它前面，留给它出手的时间。",
	"wall": "替后方草木挡住啃咬。进化可以让它自行修复、反伤恶客，或磨出碎石还手。能挡多久，往往就决定后排能打多久。",
	"bomb": "点燃后稍等片刻便会爆开，重创周围的恶客。只能使用一次，适合挽救突然吃紧的一段防线。",
	"mushroom": "埋下后需要时间长成。恶客靠近时喷出鬼火，与敌人同归于尽；要提前种，别等对方贴到门口才下手。",
	"bell": "让本行前方的恶客放慢脚步，为整条防线争取时间。进化后的余音能照应邻行，也能让敌人停步、回头，或反噬啃咬者。",
	"censer": "香雾能同时熏伤身边多名恶客。进化可以改变烟的去向、给敌人留下香印，或让倒塌的炉子继续守着一缕余烟。",
	"umbrella": "能把靠近的非大型恶客收进伞中，消化时暂时不能再次收妖；遇到大型敌人则用伞骨击打。进化可以打开第二个收妖位，或把收下的妖气化作香火和护盾。",
	"lion": "贴身撞击并推开恶客，适合守住前排。进化可以摔落护具、踩伤附近敌人，或为同伴喝彩；最后一舞能在倒下前再争取几秒。",
	"cat": "尾火会追向全场最近的恶客，也能跨行救急。进化可以让尾火绕行、同时追击多名敌人，或留下令友军打得更重的狐火记号。",
	"shell": "给已有草木披上一层龟甲。恶客先啃壳，壳碎了才伤到里面的草木；用铲子可以单独拆下龟甲，不伤及被保护的草木。",
	"lobber": "把汤圆越过前排，抛向本行队尾。进化可以追着密集的敌人落点、砸碎护具，或留下能减速和烫伤敌人的热汤。",
	"torch": "友军射出的竹签、尾火等穿过火焰时会变得更有威力。适合种在射手前方；进化还能留下火星、灼烧与火油。穿过多个火盆也只得到最强的一次加成。",
	"star": "向有敌人的方向送出灯焰，适合照应多行。进化可以加强密集处的火力、加快发灯，或让错过敌人的灯焰折回追击。",
	"needle": "骨针优先寻找本行带护具的恶客，直接扎伤本体。进化可以贯穿、补针，或在敌人身上留针，让继续向前走的恶客付出代价。",
	"judge": "守望本行，将靠近防线的恶客打退。进化可以让敌人彼此撞倒、压住它们得到的助力，或盖下逐渐催命的死印。",
	"lily": "先在水面放一片夜莲，其他草木才有地方落脚。它只负责承载，不会攻击；水路要提前留出放夜莲的香火。",
	"kelp": "只能在水面等候。恶客靠近时将它拖入水底，随后自己也会散去；适合在水路最吃紧时换掉一个难缠的对手。"
}
	return plant_pitch(type)+"\n"+String(GUIDE.get(type,""))


static func zombie_rows(type: String) -> Array:
	var d: Dictionary = Content.ZOMBIES[type]
	var tier = String(d["tier"])
	var tier_tone = "atk" if tier == "h" else ("gold" if tier == "m" else "time")
	var rows: Array = [
		_row("阶级", Content.tier_label(tier), tier_tone),
		_row("本体血量", str(int(d["hp"])), "hp"),
		_row("护具", "%s %d" % [d["armor_name"], int(d["armor"])]
			if float(d.get("armor", 0)) > 0 else "无", "hp" if float(d.get("armor", 0)) > 0 else "desc"),
		_row("行进速度", in_cells(float(d["speed"]),2)+"/秒", "time"),
		_row("啃食", "%d / 秒" % int(d["dps"]), "atk"),
	]
	match type:
		"tongue":
			rows.append(_row("啃食距离", in_cells(d["reach"]), "desc"))
		"mourner":
			var aura: Dictionary = d["aura"]
			rows.append(_row("哭号范围", in_cells(aura["radius"]), "desc"))
			rows.append(_row("加速", "+%d%% / %s 秒" % [
				int(round((aura["haste"] - 1.0) * 100)), String.num(aura["duration"], 1)], "time"))
		"sedan":
			var split: Dictionary = d["split"]
			rows.append(_row("破轿", "%d 只饿鬼 · %d%% 血量" % [
				int(split["count"]), int(round(float(split["hp"]) * 100))], "desc"))
		"vault":
			rows.append(_row("跳幡", "跳过首株 · 落地速度 %s/秒" % in_cells(float(d["vault"]["speed_after"]),2),
				"desc"))
		"artisan":
			var support: Dictionary = d["support"]
			rows.append(_row("发甲间隔", "%s 秒" % String.num(support["interval"], 1), "time"))
			rows.append(_row("纸甲", "%d 点 · 最多 %d 只" % [
				int(support["armor"]), int(support["targets"])], "gold"))
			rows.append(_row("发甲范围", in_cells(support["radius"]), "desc"))
	if bool(d.get("large", false)):
		rows.append(_row("体型", "大型 · 倒下后会短暂挡住射弹", "desc"))
	var appearance = Content.first_appearance(type)
	if appearance != "":
		rows.append(_row("初遇", appearance, "desc"))
	rows.append(_row("特性", _zombie_trait(type), "desc"))
	return rows


static func _zombie_trait(type: String) -> String:
	const TRAITS = {
		"ghost": "数量最多", "paper": "纸壳护具", "mountain": "重型啃穿",
		"tongue": "快手远嘴", "mourner": "助威加速", "sedan": "破轿分身",
		"straw": "斗笠护具", "stonehat": "石帽护具", "bucket": "陶瓮重甲",
		"vault": "跳过首株", "artisan": "分发纸甲", "ironjudge": "铁面重甲",
	}
	return TRAITS.get(type, "数量最多")


static func zombie_ability(type: String) -> String:
	var d: Dictionary = Content.ZOMBIES[type]
	var head = "%s·%s：本体 %d" % [
		Content.tier_label(String(d["tier"])), d["kind"], int(d["hp"])]
	if float(d.get("armor", 0)) > 0:
		head += "，%s %d（先破护具才伤本体）" % [d["armor_name"], int(d["armor"])]
	else:
		head += "，无护具"
	head += "；行进速度 %s/秒，啃食伤害 %d/秒。" % [in_cells(float(d["speed"]),2),int(d["dps"])]
	match type:
		"tongue":
			head += "约 %s 外就会停下开咬，比别的低阶更早动手。" % in_cells(d["reach"])
		"mourner":
			var aura: Dictionary = d["aura"]
			head += "每 %s 秒哭号一次，让 %s 内的恶客加速 %d%%、持续 %s 秒。" % [
				String.num(aura["interval"], 1), in_cells(aura["radius"]),
				int(round((aura["haste"] - 1.0) * 100)), String.num(aura["duration"], 1)]
		"sedan":
			var split: Dictionary = d["split"]
			head += "轿壳破裂时跌出 %d 只饿鬼，各带 %d%% 血量。" % [
				int(split["count"]), int(round(float(split["hp"]) * 100))]
		"vault":
			var vault: Dictionary = d["vault"]
			head += "第一次遇到草木会撑幡跳过它，落地后速度降至%s/秒，跳过时不啃食。" % in_cells(float(vault["speed_after"]),2)
		"artisan":
			var support: Dictionary = d["support"]
			head += "每 %s 秒给 %s 内最多 %d 只低阶恶客发 %d 点纸甲；纸甲与已有护具不叠加，只取更厚的一层。" % [
				String.num(support["interval"], 1), in_cells(support["radius"]),
				int(support["targets"]), int(support["armor"])]
		"mountain", "ironjudge":
			head += "体型大，能正面啃穿石磨；倒地后还会短暂挡住射弹。"
		"paper", "straw", "stonehat", "bucket":
			head += "攻击先扣护具，壳碎后本体才倒；破具后仍会继续前进。"
	return head


static func plant_entries() -> Array:
	var out: Array = []
	for type in Content.PLANT_ORDER:
		out.append(type)
	return out


static func zombie_entries() -> Array:
	var out: Array = []
	for type in Content.ZOMBIE_ORDER:
		out.append(type)
	return out
