## 图鉴：草木志与恶客录。
##
## 来历与引语照抄 v0.2.4 的 www/src/content/almanac.js。
## 「本事」与「底细」不再手写数字，而是从 data/content.gd 与 data/upgrades.gd 推导，
## 数值一改图鉴就跟着改——v0.2.4 里图鉴与代码是两份手抄数据，曾因此说谎。
class_name Almanac
extends RefCounted

const BOSS_ORDER = ["earth", "paper", "river", "island", "magistrate-bound", "magistrate-full", "wind-warden", "mask-master", "market-lamplord"]
const BossRules = preload("res://scripts/boss_encounter.gd")
const BOSS_PAGES = {
	"wind-warden":["云上听铃","第六周 · 第五夜","巡使以云索缠住出手的草木。云台没入时留意常驻石台的火力，不要把所有后手都押在同一块浮台上。"],
	"mask-master":["百面开场","第七周 · 第五夜","班主会剪落戏幕、催急鼓点，再向最前方的草木落下压轴一击。留出补防的香火，也别让火力全挤在前沿。"],
	"market-lamplord":["万灯收契","第八周 · 第五夜","掌灯人借市灯改换客潮，契灯还能削弱草木。看清下一盏亮灯，照顾六行防线，准备接住万灯齐落。"],
	"earth": ["街下有主", "第一周 · 第五夜", "震地前先有红纹，随后石俑沿街扑来。快拆挡路的石俑，把火力转到獾王所在的两行。"],
	"paper": ["纸上有愿", "第二周 · 第五夜", "纸符会封住草木的本事，纸官还会从栈道唤来帮手。尽快打散符纸，留些香火补上空缺。"],
	"river": ["潮底戴傩", "第三周 · 第五夜", "盯住涨潮的红纹和横冲的水蟹。傩主会闪到别处，把输出布在几行就能接住它。"],
	"island": ["提灯引潮", "第四周 · 第五夜", "夜叉守着孤岛岸边，铃一响便借潮水冲击摊位。"],
	"magistrate-bound": ["锁印听审", "第五周 · 第五夜 · 第四大波", "鬼官的印玺仍被铁链束缚。击退它之后，还有四大波要守。"],
	"magistrate-full": ["开印断生", "第五周 · 第五夜 · 第八大波", "地底府衙真正的主人。官印已开，它会接连点名并降下重判。"],
}
static var _boss_data: Dictionary = {}
static var _boss_portraits: Dictionary = {}


static func boss_name(id: String) -> String:
	return String(boss_record(id).get("name", "恶首"))


static func boss_record(id: String) -> Dictionary:
	if _boss_data.is_empty():
		var config = JSON.parse_string(FileAccess.get_file_as_string("res://data/boss_balance.json"))
		for entry in config.bosses:
			_boss_data[String(entry.id)] = entry
	return _boss_data.get(id, {})


static func boss_skills(id: String) -> Array:
	var data := boss_record(id)
	var hp := float(data.max_hp) * BossRules.HEALTH_SCALE * BossRules.EASY_HP_SCALE
	var force := BossRules.SKILL_FORCE
	var rows := [
		["恶首底细", "生命　初月 %d · 常夜 %d · 沉夜 %d · 噩梦 %d。身躯占相邻两行，每施放一至两次小招便随机换行。" % [
			roundi(hp * Sim.DIFFICULTY.easy.hp), roundi(hp * Sim.DIFFICULTY.normal.hp), roundi(hp * Sim.DIFFICULTY.hard.hp), roundi(hp * Sim.DIFFICULTY.nightmare.hp)]],
		["出招节奏", "现身后准备3秒。首次小招在%.2f秒后到来，之后每%.2f秒再次施放。闪影换行用时%.2f秒。" % [
			float(data.small_first_s) / BossRules.SKILL_RATE, float(data.small_period_s) / BossRules.SKILL_RATE, BossRules.BLINK_TIME]]]
	match id:
		"earth":
			rows.append(["双穴裂街", "预警2.2秒，同时震开两处地穴，各造成%d。地穴耐久%d，存续11.25秒，可从街下唤来饿鬼。" % [roundi(140 * force), roundi(160 * force)]])
		"paper":
			rows.append(["三符缚愿", "预警1.8秒，最多封住三行各一株草木。纸符耐久%d。产香草木受封%.2f秒，其他草木%.2f秒；打碎符纸即可解开。" % [roundi(120 * force), 2 * force, 5 * force]])
			rows.append(["双渡迎客", "与缚愿交替出招，预警1.8秒，在空位展开两处纸渡。纸渡耐久%d，存续15秒；3秒后开始召来斗笠鬼。" % roundi(240 * force)])
		"river":
			rows.append(["并潮双蟹", "预警2秒，派出两只潮蟹各冲一行。潮蟹耐久%d，最多存续10秒，撞上草木时造成%d。先拆开一路，再守住另一路。" % [roundi(180 * force), roundi(300 * force)]])
		"wind-warden","mask-master","market-lamplord":
			var skill:Dictionary=data.small_skill
			var follow:String={"wind-warden":"幸存草木攻速降低20%%，持续4秒。交替的系云结不造成直接伤害，可封住最多两株草木3秒；云结耐久%d，可击碎解开。" % roundi(160*force),"mask-master":"幸存草木沉睡2秒。交替的催急鼓令最多六名普通恶客移速提高35%，持续6秒。","market-lamplord":"幸存草木伤害降低20%，持续4秒。交替的点市招客重新随机选灯，经过8秒预告后开市12秒，不额外增加客潮总量。"}[id]
			rows.append([String(skill.label),"预警%.2f秒，直击最多%d株草木，每株%d伤害。%s" % [float(skill.warning),int(skill.targets),roundi(float(skill.damage)*force),follow]])
		_:
			var skill: Dictionary = data.small_skill
			var extra := "幸存草木的攻击速度降低20%，持续5秒。" if id == "island" else (
				"幸存草木的伤害降低25%，持续5秒。" if id == "magistrate-full" else "")
			rows.append([String(skill.label), "预警%.2f秒，最多波及%d行各一株草木，每株受到%d，并受封%.2f秒。%s" % [
				float(skill.warning), int(skill.targets), roundi(float(skill.damage) * force), float(skill.seal_s) * force, extra]])
	if bool(data.get("summon_final", true)):
		rows.append(["恶首号令", "第%d次小招起，每隔%d次小招施放一次。预警2.4秒，召来与今夜最后一大波相当的恶客。" % [
			int(data.get("summon_first_cast", BossRules.FINAL_WAVE_FIRST_CAST)), int(data.get("summon_cast_interval", BossRules.FINAL_WAVE_CAST_INTERVAL))]])
	var marks := PackedStringArray()
	for threshold in data.major_thresholds:
		marks.append("%d%%" % roundi(float(threshold) * 100))
	if marks.is_empty():
		rows.append(["受限官印", "锁链尚在，只能点卯。重判与号令须待完整形态才会施展。"])
	else:
		var major: Dictionary = data.major
		var skill_name := String({"earth":"裂街震地", "paper":"缚愿大阵", "river":"暗河决堤",
			"island":"潮灯压岸", "magistrate-full":"冥府重判","wind-warden":"云索卷灯","mask-master":"百面压轴","market-lamplord":"万灯收契"}.get(id,"压阵"))
		var extra := "幸存草木另受%.2f秒封印。" % (2.0 * force) if id in ["paper", "magistrate-full"] else ""
		rows.append([skill_name, "生命降至%s时各发动一次。预警%.2f秒，最多落击%d处，每击%d，相邻落击间隔%.2f秒。%s" % [
			"、".join(marks), float(major.warning_s), int(major.hit_count), roundi(float(major.damage_per_hit) * force), float(major.hit_spacing_s), extra]])
	rows.append(["援军与抗性", "恶首出战5秒后，援军按今夜普通来客的强度接续到来。控制时长保留四分之一，单次最多0.75秒，10秒内累计最多1.5秒；比例伤害每次与同源每秒最多造成其最大生命的1%。"])
	return rows


static func boss_portrait(id: String) -> Texture2D:
	if not _boss_portraits.has(id):
		if id in ["island", "magistrate-bound", "magistrate-full", "wind-warden", "mask-master", "market-lamplord"]:
			var actor := "boss-" + id
			var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://data/actor_frames.json"))
			if manifest is Dictionary and manifest.has(actor):
				var r: Array = manifest[actor].clips.idle[0].rect
				var portrait := AtlasTexture.new()
				portrait.atlas = load("res://" + String(manifest[actor].file))
				portrait.region = Rect2(r[0], r[1], r[2], r[3])
				portrait.filter_clip = true
				_boss_portraits[id] = portrait
			return _boss_portraits.get(id)
		var path := "assets/boss/boss_%s_atlas.png" % id
		var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://data/boss_art_manifest.json"))
		for sheet in manifest.atlases:
			if String(sheet.file) != path:
				continue
			for frame in sheet.frames:
				if String(frame.name) == "idle":
					var crop := AtlasTexture.new()
					crop.atlas = load("res://" + path)
					crop.region = Rect2(frame.region[0] + frame.alpha_bbox_local[0],
						frame.region[1] + frame.alpha_bbox_local[1], frame.alpha_bbox_local[2] - frame.alpha_bbox_local[0],
						frame.alpha_bbox_local[3] - frame.alpha_bbox_local[1])
					_boss_portraits[id] = crop
	return _boss_portraits.get(id)

const PLANTS = {
	"five-brew":{"epithet":"酒瓮只收四样火候","story":"空瓮在灶边长出了三只调料葫芦。一把签、一团飞火、一缕魂，兑对了次序，瓮里就自己滚开。","quote":"一味不成席，多来一味。"},
	"blank-orchid":{"epithet":"空处自有一脉香","story":"老园丁在石座旁留了四个空位。原以为那里什么都没种，夜半才看见墨叶一直舒到了空格边。","quote":"空出的那一笔，也是画。"},
	"root-palanquin":{"epithet":"换个落脚处，旧愿仍随身","story":"两只叶灵用青藤编了一乘小轿。它们不接夜客，只替守夜人搬动累得扎根的草木。轿帘掀起时，旧伤、旧愿与未尽的法术都跟着走，连龟甲也一并抬好。","quote":"根不伤，愿不散。"},
	"watch-bloom":{"epithet":"把等候拨快一更","story":"更夫的竹筹落进花盆，竟生出一朵听得见时辰的花。它不追夜客，只挑最久未醒的种子敲一声。夜市里更筹再多，也只依着同一声更鼓。","quote":"别急，我替你数着呢。"},
	"vow-toad":{"epithet":"一枚铜钱，一纸愿契","story":"金蟾蹲在旧钱匣上，嘴里含着一枚从未花出的愿钱。守夜人许它香火，它便将铜钱吐成退敌的流光；灯少时又闭嘴守财，生怕连最后一点火也付出去。","quote":"留够底火，这笔买卖我做。"},
	"year-banyan":{"epithet":"一圈年轮，一盏长明","story":"老榕树把年轮借给守夜人。它不催更鼓，只把夜风里长出的新叶，轻轻换成下一盏灯。","quote":"再等一轮，枝头便亮。"},
	"sky-mortar":{"epithet":"炮向云霄，声落鬼市","story":"夜市旧哨台留下了一门镇霄炮。守夜人以榕根作轮，以朱绳系住炮火，只许它在恶客聚集时响起。","quote":"诸位，让一让。"},
	"reed-chime":{"epithet": "一篁响，半庭风", "story": "夜市旁的竹篁被风吹了百年，学会把风藏进空心里。它不开口，陶盆上的老脸替它听着街声。", "quote": "借你一口夜风。"},
	"soul-casket":{"epithet": "借来的光，一发不少", "story": "老匠把莲籽种进听声匣里。根须长出时，五窍也醒了；它收住路过的光，再循着恶客的气息一一送还。", "quote": "先替你收着。"},
	"herb-gourd": {"epithet":"一葫清露，救得半巷灯","story":"旧药铺门前的一只青瓷葫芦，听了一辈子问诊。入夜后，它自己摇起药叶扇，只盼这条街上的灯都能亮到天明。","quote":"先把这一口气养回来。"},

	"ruin-cap": {"epithet": "一地劫火", "story": "山坳里的古芝把最后一缕雷火收在伞下。揭开封条，火就沿摊面一格一格漫开。", "quote": "先退两步。"},
	"sky-kite": {"epithet": "乘风越过屋脊", "story": "扎鸢人把一根旧竹篾留在纸鸢里。夜里只要远处有客，那根竹篾就会抖一下，纸鸢便迎风飞向远处的来客。", "quote": "远的那个，交给我。"},
	"wish-till": {"epithet": "把退场的名字结清", "story": "这只账匣曾管过一整条街的夜账。哪一行少了一位恶客，算盘就响一声，把账结进摊主手里。", "quote": "这一笔，清了。"},
	"cash-pod": {"epithet": "挨一口掉几文", "story": "旧钱庄屋檐下长出一只铜红色的豆荚。拿走它不花钱，倒是啃它的恶客常听见一声铜钱响。", "quote": "这一口算你二十五。"},
	"ember-cicada": {"epithet": "铜翅里藏着火", "story": "夏末飞进炉房的蝉把烧红的炉灰夹在翅下。火弹射光后，它合拢铜翅蓄火，充满了才重新展开。", "quote": "听见收翅，就知道我还会回来。"},
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
		"story": "夜市西头的旧灯架上挂着一截狐尾形状的灯芯。摊主说，那是只走丢的狐妖留下的最后一点火。它不照路，只照人：谁身上的阴气最重，尾火就朝谁飘过去。灯芯烧旺时，十团狐火会接连窜出，像一条照遍夜路的狐尾。",
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
		"epithet": "守住门里的一盏灯",
		"story": "恶客闯街那夜，旧货摊的钟馗像压住了门缝里钻进来的煞气。天亮以后，大家才发现，画上裂了一道口子，供在画前的灯火还没有熄。",
		"quote": "靠近些，我守着。",
	},
	"gust": {
		"epithet": "借一阵穿街风",
		"story": "夜市散场后，没人敢去收摊边那把乌羽扇。只要它轻轻一抖，街上的灯幡便全朝同一边倒，连河里的影子也得往回漂。",
		"quote": "都给我退回去。",
	},
	"firework": {
		"epithet": "提着满筒火星的孩子",
		"story": "烟花童总蹲在炮仗铺门口，等人来借一缕火。恶客逼近时，他把一捧火星丢过屋檐，在来客脚边开出一朵红花。",
		"quote": "抬头，看这一朵。",
	},
	"squash": {
		"epithet": "一声闷响压住邪祟",
		"story": "老摊主把黄符系到冬瓜藤上。夜里瓜籽在壳里响了一声，整个瓜就醒了。听见恶客挨近，最沉的那一个会先跳起来。",
		"quote": "站住，我马上下来。",
	},
	"dragon": {
		"epithet": "铜龙有两口气",
		"story": "铸炉师把旧庙的一段龙脊装上木座。低头时喷一街青火，仰头时含一串铜丸。过路人都说，它打了个喷嚏才有了龙声。",
		"quote": "近处我看着，远处也别想走。",
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
	"incense-thief":{"epithet":"把灯灰藏进旧罐","story":"摊主总在盘账时少了一把香火。长街尽头的破罐轻轻一响，盗烬客便把最后一缕灯灰吞进肚里。","counter":"初次入场5秒后停步窃取，此后每7秒最多偷35香火，余额不足则扣至0。第二次起每次炼化15，击退时掉落尚未炼化的部分。沉默可阻止窃取，尽早击退可取回更多。","quote":"这缕烟，你方才数过吗？"},
	"sky-ferry":{"epithet":"两盏浮灯，顺路载客","story":"轿架只容一位客，浮灯轿夫却从不问来人的身量。它掀起篓沿，把同路的恶客送到摊后，才肯收起两盏青灯。","counter":"携带1500耐久的浮灯轿架，飞行时速度提高50%。遇到的第一位可搭载恶客会随轿升空，大型也可搭乘。拆毁轿架或进入门神前四格后落地。追魂、抛弹、灰烬可对空；在障碍上坠落会退场。","quote":"上轿吧，前头不必走。"},
	"mist-hat":{"epithet":"浸了云水的蓑衣","story":"蓑雾客爱把蓑衣晾在云海里，穿上时衣角仍滴着水。","counter":"仅在第六周出现，所受灼烧的持续时间减半。用直接伤害处理。","quote":"这衣裳，今日也干不得。"},
	"cloud-porter":{"epithet":"肩头的铃认得云路","story":"旧栈拆了以后，踏云役仍来回挑着两筐空云。","counter":"仅在第六周出现。脚下云台正在上升时，移速提高35%。静止台面、下降和常驻石台均无加速。","quote":"起了台，自然好走。"},
	"gong-imp":{"epithet":"半面铜锣催一步","story":"碎锣童磕坏了铜锣，偏把裂缝那一声当作好彩头。","counter":"仅在第七周出现。首次降至半血后独自快跑2秒，移速提高45%。留一点后排拦截。","quote":"这一声，是催我自己！"},
	"curtain-effigy":{"epithet":"顺着绸巷追到台前","story":"提幕傀拖着戏帘，最认得袖子拐弯时那条暗巷。","counter":"仅在第七周出现。走完整段引路通道后，移速提高35%，持续3秒。可以在对应出口布防。","quote":"幕还没落，往前走。"},
	"freight-yokel":{"epithet":"肩上的担子从不歇","story":"渡口人早已收摊，挑担客还在替那些没有落款的货单赶路。","counter":"在河埠口靠近货垛时步子更快；清出泊位能让货船把碍路的货搬走。","quote":"这两包送到就歇。"},
	"river-fisher":{"epithet":"借一只葫芦浮水","story":"黑水下有东西拽它，它便把旧葫芦拴在了手腕上。","counter":"只从水路来，顺水来得快。看浮标再决定哪条渠先补防。","quote":"别解绳。"},
	"reef-haunter":{"epithet":"旧罟里从来没有鱼","story":"披着弃网的背罟鬼趁夜雾摸上石岸。","counter":"只从陆地上岸，身在未被驱散的海雾里会加快脚步。用前排草木清出视野。","quote":"雾里有路。"},
	"timber-bearer":{"epithet":"走哪儿都带两块旧木","story":"旧衙的桥塌过许多回，衔木客每夜都挑几根木头回来。","counter":"冥判窟旗帜波的衔木客被击退后会留下木材，点断桥便可补起。","quote":"这回应当架得牢。"},
	"wick-pilgrim":{"epithet":"只认点亮的那对街巷","story":"循灯纸客用旧灯纸糊了自己，在发亮的路上走得比影子快。","counter":"仅在第八周出现。开市时，站在亮灯对应的两条街或三灯齐亮时，移速提高30%。熄灯即失去加速。","quote":"哪里有灯，哪里有路。"},
	"lantern-judge":{"epithet":"灯骨先替它挨一记","story":"判客提着一盏有裂纹的铁灯，灯断了也不肯松手。","counter":"仅在第八周出现。第一次承受至少80点的单次伤害时挡去40点；灰烬不例外。轻击可正常消耗其耐久。","quote":"这一笔先记在灯上。"},
	"sky-wick":{"epithet": "借纸作翅", "story": "纸铺剩下的旧鸢，驮着一个不肯落地的饿鬼。飞到灯火近旁，纸翅就撑不住了。", "counter": "飞行时忽略障碍。完整纸鸢翼提供50%加速，飞行另提供50%加速，两者相加后速度为基础的2倍。没有对空能力的普通射弹与直接范围攻击无法命中它；追魂与抛弹可以命中，灰烬攻击仍遵守草木自身的对空限制。门神前四格内遇到可落脚处便降落；障碍上破翅会坠亡。", "quote": "脚下的路，我先借过。"},
	"shield-envoy":{"epithet": "旧牌分给后来人", "story": "它背着一摞无人认领的护身牌，沿街把牌塞给饿鬼。牌上名字已经磨平，它仍记得授牌的手势。", "counter": "入场5秒后首次授牌，此后每11秒，把2.2格内尚无护具的低阶恶客全部加上1080耐久的护身牌。抛弹、范围等非普通射弹攻击可绕过护牌。沉默能阻止授牌。", "quote": "牌拿稳，莫掉了。"},
	"oar-barge":{"epithet": "五桨一齐，阴舟不歇", "story": "暗河里五个饿鬼合坐一条旧舟，橹声总在同一拍。它们不认渡钱，只认挡在船头的摊位。", "counter": "仅从水路来。每2.4秒同步划桨，前0.75秒冲进；遇到攻击范围内的草木则改为撞击，造成300。船壳击沉后，五名饿鬼落水并继续游来。", "quote": "一、二——划。"},
	"flinch": {"epithet": "受惊就跑", "story": "它平时贴着墙根挪，直到一支竹签把它吓离了墙。从那以后，挨一下就埋头往前冲。", "counter": "第一次受到伤害后会加快脚步。先在同一行放好后续火力。", "quote": "我本来没这么快。"},
	"wave-herald": {"epithet": "一面破幡先到", "story": "起风时，一面旧幡会在摊头响起来。拿幡的客只管开路，每逢一大波只来一位。", "counter": "每一大波的最后一拨到场，带来这一轮最紧密的攻势。像普通恶客一样行走和啃食。", "quote": "诸位，进街。"},
	"formless": {"epithet": "一团泥没有骨头", "story": "水窖漏过一场雨，留下的泥影学会了过街。竹签常穿过它，只有低头啃东西时，它才像有个固定形状。", "counter": "未啃食时，每次受击有50%概率免去这次伤害。啃食时无法闪避。", "quote": "你打中的是哪一块？"},
	"reed-shot": {"epithet": "芦管吹过一条街", "story": "有个河边猎户用芦管吹出细针。它夜里走进一格半就停住，慢慢吹，看谁先撑不住。", "counter": "进场走过1.5格后停住，每1.2秒射击一次。同一行最先碰到的草木受到40。沉默可阻止远射。", "quote": "挡着的人，自然先挨。"},
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
		"story": "抬轿鬼抬着一顶褪色的红轿，轿帘后面坐着谁，没人看清过。它们走得不快，轿子却硬得很，像把一整场喜事都糊在了木头上。空轿破了，两个饿鬼撒手继续走。若帘后坐着新娘，她也会下轿。",
		"counter": "轿子有一半机会载着鬼新娘。用签筒击碎轿壳后，留一道火力对付下轿的客人。",
		"quote": "起轿——别问去哪。",
	},
	"returner": {
		"epithet": "灯灭一息，还会再亮",
		"story": "送灯人把最后一盏灯揣进怀里。它摔倒时，灯焰缩成一点，隔一息又沿衣襟爬起来，脚步比先前更急。",
		"counter": "第一次击倒后继续留火力。它一秒后满血复生，移动速度提高50%，只复生一次。",
		"quote": "灯还没送到。",
	},
	"matchmaker": {
		"epithet": "红线另一头是喜轿",
		"story": "她牵着的红绳总拖过街角，没人看见尽头。打结时远处便响起脚步，抬轿鬼把帘后那位客人送到她面前。",
		"counter": "她的身板较脆，先点掉她。进场4秒后叫来一顶喜轿，此后每11秒再叫一顶，始终是她所在的路。",
		"quote": "红线未断，客人还要来。",
	},
	"phaseguard": {
		"epithet": "一副木骨，两副相",
		"story": "扎戏偶的师傅给它做了两副肩壳。青壳紧闭，接得住飞来的暗器。黄壳像伞一样张开，接得住从高处掉下来的东西。",
		"counter": "青相少受50%射弹伤害，多受20%近身等伤害。黄相少受50%抛弹伤害，多受20%其余伤害。生命过半时换相一次。",
		"quote": "翻一面，再来。",
	},
	"tamer": {
		"epithet": "一抖线，两路见影",
		"story": "巡相师的影子不跟着脚走，倒跟着手腕走。铜扣一响，街上两张木脸便各寻一条路。",
		"counter": "进场4秒后随机在各路召出两只双相傀，之后每9秒再召一次。先截住他，免得傀儡越来越多。",
		"quote": "轮到你们登台。",
	},
	"shieldguard": {
		"epithet": "硬牌挡飞签",
		"story": "旧庙门板给夜路人拆走一块。再见时，铜扣仍在，只是门板前面多了一双石脚。",
		"counter": "护身牌先挡普通射弹和追魂。穿透射弹、灰烬炮弹及香雾等范围攻击同时打到盾牌和本体；普通抛弹和近身攻击可绕牌。",
		"quote": "飞来的，我替它们接。",
	},
	"reedboat": {
		"epithet": "一苇过暗河",
		"story": "河面低处有个撑蒲舟的客人。舟没破时看不清它的脚，只能看到水花一路赶着灯影。",
		"counter": "只走水路。蒲舟完好时移动速度提高90%，击毁蒲舟后它只能游过去。",
		"quote": "借水一程。",
	},
	"dreambell": {
		"epithet": "铃响，灯下做梦",
		"story": "她从不睁眼。摇铃时巷口静一下，被她叫中的那株草木便以为天亮了，合上眼就睡。",
		"counter": "进场4秒后令本行一株随机草木睡3秒，之后每11秒再摇铃。准备备用火力和香火来源。",
		"quote": "灯下睡一会儿吧。",
	},
	"bride": {
		"epithet": "帘开了，喜路还没走完",
		"story": "她只坐红轿来。轿子碎了，她拾起盖头，从两个轿夫身后踏上夜市。",
		"counter": "鬼新娘能闪避爆竹、坟头菇和其他灰烬伤害。烬翼蝉的看破能让她无法闪避；也可用签筒、狐火等持续火力守住这一路。",
		"quote": "劳烦，让我把这段路走完。",
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
		"counter": "先让它受到的伤害增加，再用高伤害射弹集火破瓮；透骨针绕过陶瓮，最好和签筒混编。",
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
		"counter": "铁面判官是硬仗：先让它受到的伤害增加，再用重弹破面，再让透骨针收本体；铜铃和纸伞能拖住它的脚步。",
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
		_row("冷却", "%s 秒" % String.num(float(d.get("cooldown", 0)), 1), "time"),
	]
	match type:
		"five-brew":
			rows.append(_row("基础攻击","10 点特殊伤害，0.8 格溅射，每2.4秒一次","atk"))
			rows.append(_row("酿印","10 秒；只记录不同主类型。二类开酿95，三类酿成230，1格内溅射80%。","desc"))
		"blank-orchid":
			rows.append(_row("基础攻击","14 点射弹伤害，每2.5秒一次","atk"))
			rows.append(_row("留白","每个相邻合法空格使伤害和攻速提高15%，最多四格；布局稳定后计入。","desc"))
		"root-palanquin":
			rows.append(_row("搬迁","先选已有草木，再选合法空位；成功才付香火","desc"))
			rows.append(_row("保留","生命、成长、进化、护罩、冷却和异常状态全数保留；夜莲留在原处。收妖、持续施法和特殊动作期间不能搬。","desc"))
		"watch-bloom":
			rows.append(_row("更筹周期","15秒，不受攻击加速影响","time"))
			rows.append(_row("拨筹","剩余冷却最长的种植卡减少3秒；基础不作用于自己、灰烬或主动技能。同名草木不叠加拨筹频率。","desc"))
		"vow-toad":
			rows.append(_row("铜钱伤害","175","atk"))
			rows.append(_row("攻击间隔","2.5秒","time"))
			rows.append(_row("愿契","默认蓄香；主动切换开火，每发支付25香火，支付后至少留150。不够时暂停射击。基础切换冷却10秒。","desc"))
		"year-banyan":
			rows.append(_row("产出","50香火；首次3秒，之后每10秒","gold"))
			rows.append(_row("成长","种下30秒、60秒各成长一次，每次产出增加15；任一路满阶后还能每30秒成长一次，共四次。","desc"))
			rows.append(_row("能力","进化可获得榕籽连射、庇佑、明视与同心。攻击加速不改变生产节奏，专门的生产加成才有效。","desc"))
		"sky-mortar":
			rows.append(_row("炮弹伤害","185；一格范围内全额溅射","atk"))
			rows.append(_row("攻击间隔","6.9秒；炮弹升空后1.5秒落下","time"))
			rows.append(_row("目标","炮弹落地前0.25秒，锁定当前最密集的地面目标区域（含水中恶客）；基础不能对空。灰烬爆炸同时打到本体和外置护具。","desc"))
		"reed-chime":
			rows.append(_row("竹声伤害", str(Upgrades.EFFECTS["reed-chime"].damage[0]), "atk"));rows.append(_row("攻击间隔", "1.6 秒", "time"));rows.append(_row("范围", "正前方三格的窄束范围攻击", "desc"))
		"soul-casket":
			rows.append(_row("收弹", "5发；每0.09秒放出一发", "desc"));rows.append(_row("收弹冷却", "放出后3.5秒", "time"));rows.append(_row("子弹伤害","基础20%；第二路第一阶为35%，第二阶为50%","desc"))
		"herb-gourd":
			rows.append(_row("治疗", "60", "hp"))
			rows.append(_row("治疗间隔", "1.5 秒", "time"))
			rows.append(_row("范围", "自身及本行前方3格", "desc"))
		"ruin-cap":
			rows.append(_row("灰烬伤害", "%d" % int(d.ruin.damage), "atk"))
			rows.append(_row("爆炸范围", "以自身为中心的五行五列", "desc"))
			rows.append(_row("引爆时间", "%s 秒" % String.num(d.ruin.fuse, 1), "time"))
		"sky-kite":
			rows.append(_row("抛弹伤害", str(int(Upgrades.EFFECTS["sky-kite"].damage[0])), "atk"))
			rows.append(_row("攻击间隔", "%s 秒" % String.num(float(Content.PLANTS["sky-kite"].kite.interval), 1), "time"))
			rows.append(_row("目标", "本行距离最远的恶客", "desc"))
		"wish-till":
			rows.append(_row("产出", "本行每退场一名恶客，获得5香火", "gold"))
		"cash-pod":
			rows.append(_row("产出", "每损失100耐久，获得25香火", "gold"))
			rows.append(_row("被击毁", "额外获得25香火", "gold"))
		"ember-cicada":
			rows.append(_row("追踪火弹", "直击82", "atk"))
			rows.append(_row("溅射", "0.3格内受到直击伤害的50%", "desc"))
			rows.append(_row("攻击间隔", "1.2 秒", "time"))
			rows.append(_row("弹药与补充", "4发，耗尽后需4.8秒补满", "time"))
		"lantern":
			var produce: Dictionary = d["produce"]
			rows.append(_row("单次产量", str(int(produce["value"])), "gold"))
			rows.append(_row("产出间隔", "%s 秒" % String.num(produce["interval"], 1), "time"))
			rows.append(_row("首次产出", "%s 秒" % String.num(produce["first"], 1), "time"))
			rows.append(_row("增幅", "多个红灯笼只生效最高值，可与其他来源相加", "desc"))
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
			rows.append(_row("攻击间隔", "%s 秒" % String.num(pulse["interval"], 1), "time"))
			rows.append(_row("范围", "本行前方", "desc"))
		"censer":
			var cd: Dictionary = d["censer"]
			rows.append(_row("香雾伤害", str(int(float(cd["damage"]))), "atk"))
			rows.append(_row("攻击间隔", "%s 秒" % String.num(float(cd["interval"]), 1), "time"))
			rows.append(_row("半径", in_cells(float(cd["radius"])), "desc"))
		"umbrella":
			var chomp: Dictionary = d["chomp"]
			rows.append(_row("收妖时间", "%s 秒" % String.num(chomp["chew"], 1), "time"))
			rows.append(_row("对大型伤害", str(int(chomp["large_damage"])), "atk"))
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
			rows.append(_row("类别", "防御 · 不可升阶", "cost"))
			rows.append(_row("特性", "铲子可单独拆下", "desc"))
		"lobber":
			var lob: Dictionary = d["lob"]
			rows.append(_row("汤圆伤害", str(int(lob["damage"])), "atk"))
			rows.append(_row("攻击间隔", "%s 秒" % String.num(lob["interval"], 1), "time"))
			rows.append(_row("目标", "攻击范围内最靠左", "desc"))
			rows.append(_row("轨迹", "抛物线越过前排", "desc"))
		"torch":
			var t_orch: Dictionary = Upgrades.EFFECTS["torch"]
			rows.append(_row("射弹伤害增幅", "+%d%%" % int(round(t_orch["buff"][0] * 100)), "atk"))
			rows.append(_row("作用", "穿过火盆的友方射弹", "desc"))
			rows.append(_row("类别", "辅助 · 不主动攻击", "cost"))
			rows.append(_row("耐久成长", "最高进化阶数每阶增加500耐久", "hp"))
			rows.append(_row("特性", "多个炭火盆只生效最高增幅", "desc"))
		"star":
			var star: Dictionary = d["star"]
			rows.append(_row("每道伤害", str(int(star["damage"])), "atk"))
			rows.append(_row("攻击间隔", "%s 秒" % String.num(star["interval"], 1), "time"))
			rows.append(_row("范围", "五向各一道", "desc"))
		"needle":
			var needle: Dictionary = d["needle"]
			rows.append(_row("本体伤害", str(int(needle["damage"])), "atk"))
			rows.append(_row("攻击间隔", "%s 秒" % String.num(needle["interval"], 1), "time"))
			rows.append(_row("目标", "本行前方", "desc"))
			rows.append(_row("特性", "穿透普通护具；护身牌仍会阻挡", "desc"))
		"judge":
			rows.append(_row("庇护", "自身为中心3×3", "desc"))
			rows.append(_row("受到的伤害降低", percent(Upgrades.EFFECTS.judge.reduction[0]), "desc"))
		"gust":
			rows.append(_row("退敌", "全场退后2格", "desc"))
			rows.append(_row("大型", "退后1格，遇障即止", "desc"))
			rows.append(_row("类别", "灰烬 · 仅用一次", "cost"))
		"firework":
			rows.append(_row("直击伤害", "100", "atk"))
			rows.append(_row("攻击间隔", "3.5 秒", "time"))
			rows.append(_row("溅射", "0.8格内受到直击伤害的50%", "desc"))
		"squash":
			rows.append(_row("砸击伤害", "1800", "atk"))
			rows.append(_row("索敌范围", "1.2 格", "desc"))
			rows.append(_row("砸击范围", "0.5 格", "desc"))
			rows.append(_row("类别", "灰烬 · 一次性", "cost"))
		"dragon":
			rows.append(_row("近攻伤害", str(int(Upgrades.EFFECTS.dragon.near_damage[0])), "atk"))
			rows.append(_row("攻击间隔", "0.25 秒", "time"))
			rows.append(_row("范围", "本行前方3格", "desc"))
		"lily":
			rows.append(_row("水面", "必须", "desc"))
			rows.append(_row("作用", "承载一株草木", "desc"))
			rows.append(_row("类别", "浮台 · 不可升阶", "cost"))
		"kelp":
			var tangle: Dictionary = d["tangle"]
			rows.append(_row("拖拽效果", "立即拖沉一个水中恶客", "atk"))
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
	"root-palanquin":"点选迁根轿，先选要搬的草木，再点新空位。水面落脚处须已有夜莲；取消不付香火。搬迁不会回血、洗去异常或重算种下时的奖励，也不计作草木损失。",
	"watch-bloom":"按更筹周期照料冷却最久的种植卡。三路分别缩短周期、照料更多卡并降低下次种植费用、扩展灰烬与主动技能支持。第三路可在升阶面板指定优先卡，满阶解锁全场回筹；同名唯一主动只由最早满阶且仍在场的更筹花持有。",
	"five-brew":"每2.4秒打出10点特殊伤害、溅射0.8格，给受伤恶客挂酿印10秒。射弹、抛弹、追魂、范围（含灰烬）四类各可记一次。二类开酿95；三类酿成230、溅射1格80%，并清印。同一目标1.5秒内再受酿成时伤害减半。特殊反应不记类型。",
	"blank-orchid":"每2.5秒发一枚14伤射弹。四邻每个稳定的空种植格提供15%伤害和攻速，边界、机关及不可种格不算。三路分别强化穿透、借邻株共生与主动全场共生、凝露治疗与主动全场降雨。",
	"vow-toad":"开火时付香火退敌，蓄香时保留火种。三路分别强化铜钱与大型伤害、加速并合并付费、改为抛射与蓄香生产，最终解锁超频。超频每60秒最多12秒，到时回到蓄香；任何射击都不会花掉最后150香火。",
	"year-banyan":"种下3秒产出50香火，之后每10秒产出。30秒和60秒时成长，每次产出增加15；任一路升至三级后，仍可每30秒再成长一次，最多四次。三路分别侧重产能、榕籽连射、守护与全队协作。",
	"sky-mortar":"向天空发射重炮，总飞行1.5秒；落地前0.25秒才锁定当前最密集区域，对一格内目标造成185全额灰烬伤害。基础能打陆上和水中，不能对空。第三路可看破闪避与免疫、分射八块弹片，并解锁霄炮镇平安。",
	"reed-chime":"竹声穿过前方三格，打中束内的全部恶客。进化可拓宽为七向扇面、附带减速，或强化竹声与出手节奏。",
	"soul-casket":"收集己方射弹并保留其全部效果，收满后按0.09秒间隔逐发追魂放出。由灵枢放出的子弹造成的伤害提升20%；第二路第一阶提升至35%，第二阶提升至50%，第三阶每发必定额外复制一发。灵枢可以获得造成伤害提升效果，但不受攻击速度提升效果影响。原弹与灵枢的伤害提升分别计算并相乘。",
	"herb-gourd": "照料自身和前方三格内生命最低的受伤草木。进化可扩大范围、提高治疗，并在同伴满血时鼓舞。",
	"ruin-cap": "落地后稍等片刻，便对周围五行五列的恶客造成灰烬伤害。用完即退场，原地留下60秒无法种植的坑洞。",
	"sky-kite": "越过近处恶客，向本行距离最远的一名恶客抛弹。缄音进化可以压住恶客的特殊能力。",
	"wish-till": "本行每有一名恶客退场，立即获得香火。催工可以提高同行草木的攻击速度。",
	"cash-pod": "每实际损失100点耐久，立即产出25香火。被击毁时额外产出25香火。",
	"ember-cicada": "发射追踪火弹，命中后溅伤附近恶客。射完弹药会合翅蓄火，补满后重新出手。",
	"lantern": "持续产出香火，是添置草木与进化的根本。适合放在后排；进化后可以增加产量、加快产出，或照亮前方友军，让它们打得更重。",
	"shooter": "向本行发射竹签。连发最多六发并接受全队额外签数；邻行路线照应上下行。急雨路线在普通攻击时概率缩短下一轮间隔，满阶解锁万签骤雨：130发竹签、每发间隔0.02秒，冷却45秒。",
	"wall": "替后方草木挡住啃咬。进化可以让它自行修复、反弹伤害恶客，或磨出碎石还手。能挡多久，往往就决定后排能打多久。",
	"bomb": "点燃后稍等片刻便会爆开，重创周围的恶客。只能使用一次，适合挽救突然吃紧的一段防线。",
	"mushroom": "埋下后需要时间长成。长成时若正被啃食，立即喷出鬼火；也会被近处的恶客触发。",
	"bell": "摇铃放慢本行前方的恶客。进化可以加快摇铃、概率定身，或让铃声照顾整行，唤醒沉睡的草木并恢复生命。",
	"censer": "香雾能同时熏伤身边多名恶客。进化可以扩大烟圈、加深香印或加快喷烟。",
	"umbrella": "能把靠近的非大型恶客收进伞中；遇到大型敌人则用伞骨击打。进化可以加快收妖、给自己撑起护盾，还能打开两个独立的副收妖位。",
	"lion": "撞击并推开本行恶客。狮步可远跃、贯穿整行，满阶攻击间隔1.8秒。喝彩传给除自己外造价最高的3株草木；满堂喝彩改为5株加自己，每层攻击速度提高10%。",
	"cat": "尾火会追向全场最近的恶客，也能跨行救急。进化可以缩短出手间隔、接连放出十团狐火，或让每团狐火命中后再追另一名。",
	"shell": "给已有草木披上一层龟甲。恶客先啃壳，壳碎了才伤到里面的草木；用铲子可以单独拆下龟甲，不伤及被保护的草木。",
	"lobber": "向本行前方最近的恶客抛出汤圆，越过障碍击中目标。进化可以提高伤害、缩短攻击间隔，或照顾整行，在没有恶客时给同伴送去造成的伤害提升的温暖。",
	"torch": "辅助穿过的友军射弹，基础造成的伤害提升50%。最高进化阶数每阶额外增加500耐久。火色强化造成的伤害提升与溅射；暖灰提高生产产出和范围；穿薪使原本无穿透的射弹继续向前命中后续目标，不改变原有穿透弹。",
	"star": "场上有恶客时，五个方向同时发出灯焰。没有命中的灯焰会沿原路折返一次。进化可以提高伤害、缩短攻击间隔，或让灯焰追魂；巡天满阶还能额外发出五颗追踪灯焰。",
	"needle": "骨针穿过普通护具直接伤害本体；护身牌仍会阻挡骨针。进化可以贯穿一整行、加快出针并钉住恶客，或让被扎中的恶客更易受伤。",
	"judge": "基础庇护以自身为中心的3×3草木，受到的伤害降低30%。护命路线增强受到的伤害降低与独立60秒续命；镇街路线覆盖整行、威慑减速并鼓舞攻击速度，满阶解锁唯一主动神威护境；赐福路线提高伤害。",
	"gust": "扇风不伤恶客，却能让各路恶客后退。大型恶客退得较少，路上有障碍时会被挡住。",
	"firework": "烟花越过障碍，在本行落下并溅伤附近恶客。进化可以连抛、扩大爆炸或添上追踪烟花。",
	"squash": "同行恶客走进索敌范围时，镇煞瓜便会跃起砸下。能压住落点周围聚在一起的恶客，用完即退场。",
	"dragon": "龙首铳喷出短程气焰，打中本行近处的恶客。进化可让它仰射铜弹，或用双口同时攻近处和远处。",
	"lily": "先在水面放一片夜莲，其他草木才有地方落脚。它只负责承载，不会攻击；水路要提前留出放夜莲的香火。",
	"kelp": "只能种在水面。水中恶客靠近时，缠魂藻立即将其拖沉，护具再厚也拦不住。恶首不会触发；能闪避灰烬的恶客须先被看破。"
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
		"flinch": "受伤后加速", "wave-herald": "每大波来一名", "formless": "受击可能闪避", "reed-shot": "停步后远射",
		"ghost": "数量最多", "paper": "纸壳护具", "mountain": "重型啃穿",
		"tongue": "快手远嘴", "mourner": "助威加速", "sedan": "破轿分身",
		"straw": "斗笠护具", "stonehat": "石帽护具", "bucket": "陶瓮重甲",
		"vault": "跳过首株", "artisan": "分发纸甲", "ironjudge": "铁面重甲",
		"returner": "满血复生", "matchmaker": "召唤喜轿", "phaseguard": "半血换相",
		"tamer": "召唤双相傀", "shieldguard": "护牌挡射弹", "reedboat": "蒲舟加速", "dreambell": "摇铃催眠",
	}
	return TRAITS.get(type, "数量最多")


static func zombie_ability(type: String) -> String:
	var d: Dictionary = Content.ZOMBIES[type]
	var head = "%s·%s：本体 %d" % [
		Content.tier_label(String(d["tier"])), d["kind"], int(d["hp"])]
	if float(d.get("armor", 0)) > 0:
		head += "，%s %d" % [d["armor_name"], int(d["armor"])]
		if type == "shieldguard":
			head += "（抵御直线射弹与追魂弹）"
		else:
			head += "（先破护具才伤本体）"
	else:
		head += "，无护具"
	head += "；行进速度 %s/秒，啃食伤害 %d/秒。" % [in_cells(float(d["speed"]),2),int(d["dps"])]
	match type:
		"flinch", "wave-herald", "formless", "reed-shot", "returner", "matchmaker", "phaseguard", "tamer", "shieldguard", "reedboat", "dreambell", "incense-thief", "sky-ferry", "sky-wick", "shield-envoy", "oar-barge":
			head += String(ZOMBIES[type]["counter"])
			if type in ["matchmaker", "tamer", "dreambell", "reed-shot"]:
				head += "这是可被沉默打断的特殊能力。"
		"tongue":
			head += "约 %s 外就会停下开咬，比别的低阶更早动手。" % in_cells(d["reach"])
		"mourner":
			var aura: Dictionary = d["aura"]
			head += "每 %s 秒哭号一次，让 %s 内的恶客移动速度提高 %d%%，持续 %s 秒。" % [
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


const BOSS_LORE={
	"wind-warden":"云海旧栈曾有一名巡夜使，只听风铃便知道哪盏灯将熄。后来浮台沉入云底，他仍沿着铃声来往，将不肯歇息的灯一盏盏系住。",
	"mask-master":"戏台散场后，总有一张没有卸下的脸留在帘后。班主将那些脸收进长袖，鼓点越急，台下越分不清是谁在看戏，又是谁正在登场。",
	"market-lamplord":"最后一条街不卖货，只收愿。掌灯人替每个来客点一盏契灯，等万灯都亮起，便来收走守夜人尚未兑现的承诺。",
	"earth":"旧街铺石时，匠人总在地底听见低低的磨牙声。摊贩留下第一盏灯，换得脚下安稳；等灯灭了，街下的旧主便来讨债。",
	"paper":"河埠的纸铺曾替无名亡魂写愿。纸官把没能寄出的愿望折进袖中，夜夜沿栈道寻找署名的人。",
	"river":"暗河捞起过一张傩面，晒了三日仍滴着水。后来守夜人见到面具从水下缓缓抬起，才知道河底也有人开市。",
	"island":"孤岛上每一盏潮灯都照着一条归路。夜叉曾是提灯的引路人，如今铃声只唤来忘记归岸的影子。",
	"magistrate-bound":"冥判窟的锁链并非为了关住闯入者。旧案压住官印，也压住鬼官半数威势；它隔着锁印，仍在等待最后一个名字。",
	"magistrate-full":"官印开时，石壁上的旧名一起褪去。鬼市的线索终于在这座地底府衙合拢：它不是来赴夜市的，它要把整条夜市记进册中。"
}
