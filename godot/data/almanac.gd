## 图鉴：草木志与恶客录。
##
## 来历与引语照抄 v0.2.4 的 www/src/content/almanac.js。
## 「本事」与「底细」不再手写数字，而是从 data/content.gd 与 data/upgrades.gd 推导，
## 数值一改图鉴就跟着改——v0.2.4 里图鉴与代码是两份手抄数据，曾因此说谎。
class_name Almanac
extends RefCounted

const BOSS_ORDER = ["earth", "paper", "river", "island", "magistrate-bound", "magistrate-full"]
const BossRules = preload("res://scripts/boss_encounter.gd")
const BOSS_PAGES = {
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
	return String(boss_record(id).get("name", "首领"))


static func boss_record(id: String) -> Dictionary:
	if _boss_data.is_empty():
		var config = JSON.parse_string(FileAccess.get_file_as_string("res://data/boss_balance.json"))
		for entry in config.bosses:
			_boss_data[String(entry.id)] = entry
	return _boss_data.get(id, {})


static func boss_skills(id: String) -> Array:
	var data := boss_record(id)
	var hp := float(data.max_hp) * BossRules.HEALTH_SCALE * BossRules.EASY_HP_SCALE
	var rows := [["首领底细", "生命　简单 %d · 普通 %d · 困难 %d\n现身预警 3 秒，入场援香 %d。身躯占相邻两行，每出 1–2 次小技能随机换行，闪影约 %.2f 秒。" % [roundi(hp), roundi(hp * Sim.DIFFICULTY["normal"]["hp"]), roundi(hp * Sim.DIFFICULTY["hard"]["hp"]), int(data.entry_incense), BossRules.BLINK_TIME]],
		["小技能节奏", "首次出招 %.2f 秒，之后间隔 %.2f 秒。" % [float(data.small_first_s) / BossRules.SKILL_RATE, float(data.small_period_s) / BossRules.SKILL_RATE]]]
	match id:
		"earth":
			rows.append(["开凿地穴", "预警 2.2 秒，一格受 %.1f 点伤害。地穴耐久 %.1f，存续 9 秒，每 4 秒可唤来饿鬼。" % [140.0 * BossRules.SKILL_FORCE, 160.0 * BossRules.SKILL_FORCE]])
		"paper":
			rows.append(["缚愿纸符", "预警 1.8 秒，最多封住两行各一株。纸符耐久 %.1f，产香草木受封 %.2f 秒，其他草木 %.2f 秒。打碎纸符即可解封。" % [120.0 * BossRules.SKILL_FORCE, 2.0 * BossRules.SKILL_FORCE, 5.0 * BossRules.SKILL_FORCE]])
			rows.append(["纸渡接客", "与纸符交替出招。预警 1.8 秒，空格出现耐久 %.1f 的纸渡，存续 12 秒。3 秒后首次唤来斗笠鬼，之后每 4 秒可再召唤。" % (240.0 * BossRules.SKILL_FORCE)])
		"river":
			rows.append(["遣潮蟹", "预警 2 秒，耐久 %.1f 的潮蟹冲过一行，速度 1.54 格/秒，最多存续 10 秒。撞到第一株草木时造成 %.1f 点伤害后退散。" % [180.0 * BossRules.SKILL_FORCE, 300.0 * BossRules.SKILL_FORCE]])
		_:
			var skill: Dictionary = data.small_skill
			rows.append([String(skill.label), "预警 %.2f 秒，最多点中 %d 路各一株，每株受 %.1f 点伤害，幸存草木被封 %.2f 秒。" % [float(skill.warning), int(skill.targets), float(skill.damage) * BossRules.SKILL_FORCE, float(skill.seal_s) * BossRules.SKILL_FORCE]])
	if bool(data.get("summon_final", true)):
		rows.append(["首领号令", "第 %d 次小技能起每隔 %d 次施放，预警 2.4 秒，召来一整轮最终大波。" % [int(data.get("summon_first_cast", BossRules.FINAL_WAVE_FIRST_CAST)), int(data.get("summon_cast_interval", BossRules.FINAL_WAVE_CAST_INTERVAL))]])
	var thresholds: Array = data.major_thresholds
	if thresholds.is_empty():
		rows.append(["受限官印", "限制形态只能点名，无法施展强力技能与首领号令。"])
	else:
		var marks: PackedStringArray = []
		for threshold in thresholds:
			marks.append("%d%%" % roundi(float(threshold) * 100))
		var major: Dictionary = data.major
		var name := String({"earth":"裂街震地", "paper":"缚愿大阵", "river":"暗河决堤", "island":"潮灯压岸", "magistrate-full":"冥府重判"}.get(id))
		var extra := "。幸存草木另受 %.2f 秒封印" % (2.0 * BossRules.SKILL_FORCE) if id in ["paper", "magistrate-full"] else ""
		rows.append([name, "生命降至 %s 各发动一次。预警 %.2f 秒，最多 %d 次落击，每击 %.1f 点伤害，相邻落击间隔 %.2f 秒%s。" % ["、".join(marks), float(major.warning_s), int(major.hit_count), float(major.damage_per_hit) * BossRules.SKILL_FORCE, float(major.hit_spacing_s), extra]])
	rows.append(["常驻援军与抗性", "开战 5 秒后开始召援，按常规波次总耐久的 75% 调派。控制时长仅保留四分之一，单次至多 0.75 秒，10 秒内累计至多 1.5 秒。比例伤害每次及同源每秒上限为最大生命的 1%。"])
	return rows


static func boss_portrait(id: String) -> Texture2D:
	if not _boss_portraits.has(id):
		if id in ["island", "magistrate-bound", "magistrate-full"]:
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
	"ruin-cap": {"epithet": "一地劫火", "story": "山坳里的古芝把最后一缕雷火收在伞下。揭开封条，火就沿摊面一格一格漫开。", "quote": "先退两步。"},
	"sky-kite": {"epithet": "乘风越过屋脊", "story": "扎鸢人把一根旧竹篾留在纸鸢里。夜里只要远处有客，那根竹篾就会抖一下，纸鸢跟着抛出瓦弹。", "quote": "远的那个，交给我。"},
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
	"flinch": {"epithet": "受惊就跑", "story": "它平时贴着墙根挪，直到一支竹签把它吓离了墙。从那以后，挨一下就埋头往前冲。", "counter": "第一次受到伤害后会加快脚步。先在同一行放好后续火力。", "quote": "我本来没这么快。"},
	"wave-herald": {"epithet": "一面破幡先到", "story": "起风时，一面旧幡会在摊头响起来。拿幡的客只管开路，每逢一大波只来一位。", "counter": "每一大波开始时出现一名。除此之外，它像普通恶客一样行走和啃食。", "quote": "诸位，进街。"},
	"formless": {"epithet": "一团泥没有骨头", "story": "水窖漏过一场雨，留下的泥影学会了过街。竹签常穿过它，只有低头啃东西时，它才像有个固定形状。", "counter": "未啃食时，每次受击有50%概率免去这次伤害。啃食时无法闪避。", "quote": "你打中的是哪一块？"},
	"reed-shot": {"epithet": "芦管吹过一条街", "story": "有个河边猎户用芦管吹出细针。它夜里走进一格半就停住，慢慢吹，看谁先撑不住。", "counter": "进场走过1.5格后停住，每1.2秒射击一次。同一行最先碰到的草木受到40点伤害。沉默可阻止远射。", "quote": "挡着的人，自然先挨。"},
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
		"counter": "第一次击倒后继续留火力。它一秒后满血复生，移速提高50%，只复生一次。",
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
		"counter": "青相少受50%射弹伤害，多受20%近身等伤害。黄相少受50%抛射伤害，多受20%其余伤害。生命过半时换相一次。",
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
		"counter": "护身牌只挡射弹。香雾、撞击和贴身伤害可以越过牌子直接伤它。",
		"quote": "飞来的，我替它们接。",
	},
	"reedboat": {
		"epithet": "一苇过暗河",
		"story": "河面低处有个撑蒲舟的客人。舟没破时看不清它的脚，只能看到水花一路赶着灯影。",
		"counter": "只走水路。蒲舟完好时移速提高90%，击毁蒲舟后它只能游过去。",
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
		"counter": "鬼新娘免疫爆竹、坟头菇和其他灰烬伤害。用签筒、狐火或别的持续火力守住这一路。",
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
		"ruin-cap":
			rows.append(_row("灰烬伤害", "%d 点" % int(d.ruin.damage), "atk"))
			rows.append(_row("爆炸范围", "以自身为中心的五行五列", "desc"))
			rows.append(_row("引爆时间", "%s 秒" % String.num(d.ruin.fuse, 1), "time"))
		"sky-kite":
			rows.append(_row("抛弹伤害", "42 点", "atk"))
			rows.append(_row("攻击间隔", "1.5 秒", "time"))
			rows.append(_row("目标", "本行距离最远的恶客", "desc"))
		"wish-till":
			rows.append(_row("产出", "本行每退场一名恶客，获得5香火", "gold"))
		"cash-pod":
			rows.append(_row("产出", "每损失100耐久，获得25香火", "gold"))
			rows.append(_row("被击毁", "额外获得25香火", "gold"))
		"ember-cicada":
			rows.append(_row("追踪火弹", "直击82点伤害", "atk"))
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
			rows.append(_row("特性", "多个炭火盆只生效最高增幅", "desc"))
		"star":
			var star: Dictionary = d["star"]
			rows.append(_row("每道伤害", str(int(star["damage"])), "atk"))
			rows.append(_row("发灯间隔", "%s 秒" % String.num(star["interval"], 1), "time"))
			rows.append(_row("范围", "五向各一道", "desc"))
		"needle":
			var needle: Dictionary = d["needle"]
			rows.append(_row("本体伤害", str(int(needle["damage"])), "atk"))
			rows.append(_row("出针间隔", "%s 秒" % String.num(needle["interval"], 1), "time"))
			rows.append(_row("目标", "本行前方", "desc"))
			rows.append(_row("特性", "无视护具", "desc"))
		"judge":
			rows.append(_row("庇护", "自身与相邻四格", "desc"))
			rows.append(_row("减伤", "20%", "desc"))
		"gust":
			rows.append(_row("退敌", "全场退后2格", "desc"))
			rows.append(_row("大型", "退后1格，遇障即止", "desc"))
			rows.append(_row("类别", "灰烬 · 仅用一次", "cost"))
		"firework":
			rows.append(_row("直击伤害", "100", "atk"))
			rows.append(_row("抛射间隔", "3.5 秒", "time"))
			rows.append(_row("溅射", "0.8格内受到直击伤害的50%", "desc"))
		"squash":
			rows.append(_row("砸击伤害", "1800", "atk"))
			rows.append(_row("索敌与范围", "%s 格" % String.num(Sim.SQUASH_RANGE_CELLS, 1), "desc"))
			rows.append(_row("类别", "灰烬 · 一次性", "cost"))
		"dragon":
			rows.append(_row("近攻伤害", "14", "atk"))
			rows.append(_row("近攻间隔", "0.25 秒", "time"))
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
	"ruin-cap": "落地后稍等片刻，便对周围五行五列的恶客造成灰烬伤害。用完即退场。",
	"sky-kite": "越过近处恶客，向本行距离最远的一名恶客抛弹。缄音进化可以压住恶客的特殊能力。",
	"wish-till": "本行每有一名恶客退场，立即获得香火。催工可以提高同行草木的攻击速度。",
	"cash-pod": "每实际损失100点耐久，立即产出25香火。被击毁时额外产出25香火。",
	"ember-cicada": "发射追踪火弹，命中后溅伤附近恶客。射完弹药会合翅蓄火，补满后重新出手。",
	"lantern": "持续产出香火，是添置草木与进化的根本。适合放在后排；进化后可以增加产量、加快产出，或照亮前方友军，让它们打得更重。",
	"shooter": "守住本行前方的恶客。连发擅长磨掉护具，借射可以照应相邻行，大签则能打出重击。把石磨放在它前面，留给它出手的时间。",
	"wall": "替后方草木挡住啃咬。进化可以让它自行修复、反弹伤害恶客，或磨出碎石还手。能挡多久，往往就决定后排能打多久。",
	"bomb": "点燃后稍等片刻便会爆开，重创周围的恶客。只能使用一次，适合挽救突然吃紧的一段防线。",
	"mushroom": "埋下后需要时间长成。长成时若正被啃食，立即喷出鬼火；也会被近处的恶客触发。",
	"bell": "让本行前方的恶客放慢脚步，为整条防线争取时间。进化可以加快摇铃、让敌人停步回头，或反噬啃咬者。",
	"censer": "香雾能同时熏伤身边多名恶客。进化可以扩大烟圈、加深香印或加快喷烟。",
	"umbrella": "能把靠近的非大型恶客收进伞中；遇到大型敌人则用伞骨击打。进化可以加快收妖、给自己撑起护盾，还能打开两个独立的副收妖位。",
	"lion": "撞击并推开本行恶客。进化后可以远跃、贯穿整行，最后一击横扫这一行；也能重摔恶客或给身边同伴恢复耐久。",
	"cat": "尾火会追向全场最近的恶客，也能跨行救急。进化可以缩短出手间隔、接连放出十团狐火，或让每团狐火命中后再追另一名。",
	"shell": "给已有草木披上一层龟甲。恶客先啃壳，壳碎了才伤到里面的草木；用铲子可以单独拆下龟甲，不伤及被保护的草木。",
	"lobber": "把汤圆越过前排，抛向本行队尾。进化可以提高伤害、加快抛射，或留下能减速和烫伤恶客的热汤。",
	"torch": "友军射出的竹签、尾火等穿过火焰时会变得更有威力。适合种在射手前方；进化还能留下火星、灼烧与火油。穿过多个火盆也只得到最强的一次加成。",
	"star": "向有敌人的方向送出灯焰，适合照应多行。进化可以提高伤害或攻速，门神出手时还能短暂急巡；错过敌人的灯焰也可折回追击。",
	"needle": "骨针穿过护具直伤本体。进化可以贯穿一整行、加快出针并钉住恶客，或让被扎中的恶客更易受伤。",
	"judge": "把它放在容易受围攻的草木旁。它也庇护自己；进化可以挡住一次致命伤、扩大范围或鼓舞附近草木。",
	"gust": "扇风不伤恶客，却能让各路恶客后退。大型恶客退得较少，路上有障碍时会被挡住。",
	"firework": "烟花越过障碍，在本行落下并溅伤附近恶客。进化可以连抛、扩大爆炸或添上追踪烟花。",
	"squash": "同行恶客走进索敌范围时，镇煞瓜便会跃起砸下。能压住落点周围聚在一起的恶客，用完即退场。",
	"dragon": "龙首铳喷出短程气焰，打中本行近处的恶客。进化可让它仰射铜弹，或用双口同时攻近处和远处。",
	"lily": "先在水面放一片夜莲，其他草木才有地方落脚。它只负责承载，不会攻击；水路要提前留出放夜莲的香火。",
	"kelp": "只能种在水面。水中恶客靠近时，缠魂藻立即将其拖沉，护具再厚也拦不住。首领和免疫灰烬的恶客不会触发。"
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
			head += "（仅抵御射弹）"
		else:
			head += "（先破护具才伤本体）"
	else:
		head += "，无护具"
	head += "；行进速度 %s/秒，啃食伤害 %d/秒。" % [in_cells(float(d["speed"]),2),int(d["dps"])]
	match type:
		"flinch", "wave-herald", "formless", "reed-shot", "returner", "matchmaker", "phaseguard", "tamer", "shieldguard", "reedboat", "dreambell":
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
