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
const CELL_PX = 88.0


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
			rows.append(_row("减速", percent(Upgrades.EFFECTS["bell"]["slow"][0]), "time"))
			rows.append(_row("持续", "%s 秒" % String.num(pulse["slow"], 1), "time"))
			rows.append(_row("摇铃间隔", "%s 秒" % String.num(pulse["interval"], 1), "time"))
			rows.append(_row("范围", "本行前方", "desc"))
		"censer":
			var fx: Dictionary = Upgrades.EFFECTS["censer"]
			rows.append(_row("香雾伤害", str(int(fx["damage"][0])), "atk"))
			rows.append(_row("喷烟间隔", "%s 秒" % String.num(fx["interval"], 1), "time"))
			rows.append(_row("半径", in_cells(fx["radius"][0]), "desc"))
		"umbrella":
			var chomp: Dictionary = d["chomp"]
			rows.append(_row("收妖时间", "%s 秒" % String.num(chomp["chew"], 1), "time"))
			rows.append(_row("对大型", "%d 伤害" % int(chomp["large_damage"]), "atk"))
			rows.append(_row("收妖范围", in_cells(chomp["reach"]), "desc"))
			rows.append(_row("特性", "非大型即收", "desc"))
		"lion":
			var melee: Dictionary = Upgrades.EFFECTS["lion"]
			rows.append(_row("撞头伤害", str(int(melee["damage"][0])), "atk"))
			rows.append(_row("攻击间隔", "%s 秒" % String.num(melee["interval"][0], 2), "time"))
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
			rows.append(_row("射弹增幅", "+%d%% 伤害" % 50, "atk"))
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


## 「本事」：由数据推导的一句话说明，含基础数值与升阶方向。
static func plant_ability(type: String) -> String:
	var d: Dictionary = Content.PLANTS[type]
	var e: Dictionary = Upgrades.EFFECTS.get(type, {})
	match type:
		"lantern":
			return "产能：每 %s 秒吐出一团 %d 香火，首次 %s 秒，落地后收取。一路提产量（最高 %d），一路缩间隔（最低 %s 秒），一路增幅身前友军（伤害 +%d%%，满阶 +%d%%）。增幅多盏只取最高。" % [
				String.num(d["produce"]["interval"], 1), int(d["produce"]["value"]),
				String.num(d["produce"]["first"], 1), int(e["value"][3]),
				String.num(e["interval"][3], 1), int(round(e["buff_damage"][1] * 100)),
				int(round(e["buff_damage"][3] * 100))]
		"shooter":
			return "本行输出：每 %s 秒朝前方射出一发竹签，单发 %d 伤害。一路连发（最高 %d 发），一路借射相邻行（半伤到满伤），一路甩出双倍伤害的大签（最高 %d%% 概率，满阶命中减速 50%%，持续 %s 秒）。" % [
				String.num(d["shot"]["interval"], 1), int(d["shot"]["damage"]),
				int(e["volley"][3]), int(round(e["crit_chance"][3] * 100)),
				String.num(e["crit_slow"][3], 0)]
		"wall":
			return "肉盾：耐久 %d，替同行挡下啃食。一路自愈（最高 %d/秒，满阶被啃也能回），一路反伤（最高 %d/秒），一路磨出碎石（%d 伤害；满阶把非大型恶客击退 %s 格，对大型改为双倍伤害）。" % [
				int(d["hp"]), int(e["heal"][3]), int(e["reflect"][3]),
				int(e["gravel_damage"][3]), String.num(e["knock_cells"][3], 1)]
		"bomb":
			return "灰烬类 · 一次性：点燃后引信 %s 秒，在 %s 半径内造成 %d 伤害。不可升阶。" % [
				String.num(d["bomb"]["fuse"], 1), in_cells(d["bomb"]["radius"]),
				int(d["bomb"]["damage"])]
		"mushroom":
			return "灰烬类 · 一次性陷阱：埋下后 %d 秒长成，恶客踩中即喷发鬼火，造成 %d 伤害并同归于尽。不可升阶。" % [
				int(d["mine"]["arm"]), int(d["mine"]["damage"])]
		"bell":
			return "控制与辅助：每 %s 秒摇铃，使本行前方恶客减速 %d%%、持续 %s 秒。一路加快摇铃并把减速提到 %d%%，一路用铃声增幅友军攻速，一路让铃浪造成 %d 伤害乃至定身 %s 秒。减速只取最强值。" % [
				String.num(d["pulse"]["interval"], 1), int(round(e["slow"][0] * 100)),
				String.num(e["slow_duration"], 1), int(round(e["slow"][3] * 100)),
				int(e["damage"][1]), String.num(e["root_duration"], 1)]
		"censer":
			return "范围输出：每 %s 秒喷出一圈香雾，对圈内恶客造成 %d 伤害。一路加伤害（最高 %d），一路把烟圈从 %s 扩到 %s，一路让被熏到的恶客减速（最高 %d%%、持续 %s 秒）。" % [
				String.num(e["interval"], 1), int(e["damage"][0]), int(e["damage"][3]),
				in_cells(e["radius"][0]), in_cells(e["radius"][3]),
				int(round(e["slow"][3] * 100)), String.num(e["slow_duration"][3], 1)]
		"umbrella":
			return "收妖 · 肉盾：耐久 %d，非大型恶客靠近即被收入伞中，%s 秒收化；大型恶客撑不进伞，只能被伞骨击打，每次 %d 伤害。一路加快收妖，一路收妖后产香火（最高 %d），一路减少收妖期间的伤害（最高 %d%%）。" % [
				int(d["hp"]), String.num(d["chomp"]["chew"], 1),
				int(d["chomp"]["large_damage"]), int(e["sun"][3]),
				int(round(e["chew_guard"][3] * 100))]
		"lion":
			return "近战守卫：恶客靠近到 %s 内时，每 %s 秒撞头一次，造成 %d 伤害并击退 %s 格。一路加伤害与击退（最高 %d），一路加快撞击并有 %d%% 概率撞晕 %s 秒，一路命中回耐久（最高 %d）。" % [
				in_cells(e["reach"]), String.num(e["interval"][0], 2),
				int(e["damage"][0]), String.num(e["knock_cells"], 1),
				int(e["damage"][3]), int(round(e["stun_chance"][3] * 100)),
				String.num(e["stun_duration"], 2), int(e["heal"][3])]
		"cat":
			return "跨行追踪：每 %s 秒放出 %d 团尾火，自动追向全场最近的恶客，每团 %d 伤害。一路增加尾火数量（最高 %d 团），一路提伤害并让尾火再追一个目标，一路附加易伤与减速。易伤、减速只取最强值。" % [
				String.num(e["interval"], 1), int(e["count"][0]), int(e["damage"][0]),
				int(e["count"][3])]
		"shell":
			return "护罩：只能罩在已种下的草木上，提供 %d 点护罩耐久；恶客先啃龟甲，壳碎后里面的草木仍在。不可升阶；用铲子可单独拆下。" % [
				int(e["hp"])]
		"lobber":
			return "后排打击：每 %s 秒向本行最右侧的恶客抛出一颗汤圆，走抛物线越过前排，落地造成 %d 伤害。一路加伤害（最高 %d），一路加快投掷，一路让落点附带减速（最高 %d%%）。" % [
				String.num(e["interval"][0], 1), int(e["damage"][0]), int(e["damage"][3]),
				int(round(e["slow"][3] * 100))]
		"torch":
			return "增幅：不主动攻击，只有穿过火盆火焰的友方射弹才会被增幅，伤害 +%d%%。一路把增幅提到 +%d%%，一路为穿过的射弹附加灼烧（最高 %d/秒），一路附加减速（最高 %d%%）。多盆只取最高，不叠加。" % [
				int(round(e["buff"][0] * 100)), int(round(e["buff"][3] * 100)),
				int(e["burn"][3]), int(round(e["slow"][3] * 100))]
		"star":
			return "多方向：每 %s 秒检查正后、正上、正下、右上、右下五个方向，哪个方向有恶客就射出一道 %d 伤害的灯焰，没有敌人的方向不发灯。一路加伤害（最高 %d），一路加快转灯，一路附加易伤。" % [
				String.num(e["interval"][0], 1), int(e["damage"][0]), int(e["damage"][3])]
		"needle":
			return "破甲：优先攻击本行带护具的恶客，骨针无视护具直接扣本体血量，每 %s 秒一针、%d 伤害。一路加伤害（最高 %d），一路加快出针，一路附加易伤。" % [
				String.num(e["interval"][0], 1), int(e["damage"][0]), int(e["damage"][3])]
		"judge":
			return "控制：每 %s 秒睁眼，望向本行 %s 内最近的恶客，造成 %d 伤害并把它顶回去 %s 格。一路加击退（最高 %s 格），一路缩短显灵间隔（最低 %s 秒），一路提高伤害（最高 %d）。一次只盯一只，大型恶客也会被顶退。" % [
				String.num(e["interval"][0], 1), in_cells(e["reach"]),
				int(e["damage"][0]), String.num(e["knock_cells"][0], 2),
				String.num(e["knock_cells"][3], 1), String.num(e["interval"][3], 1),
				int(e["damage"][3])]
		"lily":
			return "浮台：只能放在水面，为其他草木提供一块落脚地，上面的草木正常生长与攻击。不可升阶；水面没有夜莲时，普通草木无法直接种下。"
		"kelp":
			return "灰烬类 · 一次性：只能种在水面，恶客进入 %s 范围后用 %s 秒把它拖入水底，造成 %d 伤害，随后自己散掉。不可升阶。" % [
				in_cells(d["tangle"]["range"]), String.num(d["tangle"]["drag"], 1),
				int(d["tangle"]["damage"])]
	return ""


static func zombie_rows(type: String) -> Array:
	var d: Dictionary = Content.ZOMBIES[type]
	var tier = String(d["tier"])
	var tier_tone = "atk" if tier == "h" else ("gold" if tier == "m" else "time")
	var rows: Array = [
		_row("阶级", Content.tier_label(tier), tier_tone),
		_row("本体血量", str(int(d["hp"])), "hp"),
		_row("护具", "%s %d" % [d["armor_name"], int(d["armor"])]
			if float(d.get("armor", 0)) > 0 else "无", "hp" if float(d.get("armor", 0)) > 0 else "desc"),
		_row("速度", str(int(d["speed"])), "time"),
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
			rows.append(_row("跳幡", "跳过首株 · 落地速度 %d" % int(d["vault"]["speed_after"]),
				"desc"))
		"artisan":
			var support: Dictionary = d["support"]
			rows.append(_row("发甲间隔", "%s 秒" % String.num(support["interval"], 1), "time"))
			rows.append(_row("纸甲", "%d 点 · 最多 %d 只" % [
				int(support["armor"]), int(support["targets"])], "gold"))
			rows.append(_row("发甲范围", in_cells(support["radius"]), "desc"))
	if bool(d.get("large", false)):
		rows.append(_row("体型", "大型 · 尸体停留 1 秒", "desc"))
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
	head += "；速度 %d，啃食 %d/秒。" % [int(d["speed"]), int(d["dps"])]
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
			head += "第一次遇到草木会撑幡跳过它，落地后速度降到 %d，跳过时不啃食。" % int(
				vault["speed_after"])
		"artisan":
			var support: Dictionary = d["support"]
			head += "每 %s 秒给 %s 内最多 %d 只低阶恶客发 %d 点纸甲；纸甲与已有护具不叠加，只取更厚的一层。" % [
				String.num(support["interval"], 1), in_cells(support["radius"]),
				int(support["targets"]), int(support["armor"])]
		"mountain", "ironjudge":
			head += "体型大，能正面啃穿石磨，尸体停留 1 秒。"
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
