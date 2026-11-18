## Nightmare factors are immutable per run. Levels are sanitized against stage eligibility.
extends RefCounted
const FACTORS = [
	{
		"id": "light_pack",
		"name": "行囊缄缚",
		"descriptions": [
			"本局最多携带10株草木",
			"本局最多携带8株草木"
		],
		"points": [
			1,
			3
		]
	},
	{
		"id": "price",
		"name": "香价腾烟",
		"descriptions": [
			"所有进化费用提高 50%",
			"所有进化费用提高 100%"
		],
		"points": [
			1,
			2
		]
	},
	{
		"id": "curfew",
		"name": "夜禁封市",
		"descriptions": [
			"一大波恶客到来后的 5 秒内不能种植或升阶"
		],
		"points": [
			1
		]
	},
	{
		"id": "swarm",
		"name": "百鬼叩市",
		"descriptions": [
			"恶客数量与血量额外提高 10%",
			"恶客数量与血量额外提高 20%",
			"恶客数量与血量额外提高 40%"
		],
		"points": [
			1,
			2,
			3
		]
	},
	{
		"id": "early",
		"name": "阴客抢更",
		"descriptions": [
			"中阶、高阶恶客的阵容提前1大波到来",
			"中阶、高阶恶客的阵容提前2大波到来"
		],
		"points": [
			1,
			2
		]
	},
	{
		"id": "dim",
		"name": "残灯锁香",
		"descriptions": [
			"任意连续10秒内最多获得1000香火，超出部分不入账",
			"任意连续10秒内最多获得750香火，超出部分不入账"
		],
		"points": [
			1,
			2
		]
	},
	{
		"id": "loss",
		"name": "草木薄命",
		"descriptions": [
			"草木累计损失达到30株时立即失守",
			"草木累计损失达到20株时立即失守"
		],
		"points": [
			1,
			3
		]
	},
	{
		"id": "seeds",
		"name": "一席难求",
		"descriptions": [
			"场上最多同时存在30株草木，夜莲和龟甲罩各计1株",
			"场上最多同时存在25株草木，夜莲和龟甲罩各计1株",
			"场上最多同时存在20株草木，夜莲和龟甲罩各计1株"
		],
		"points": [
			1,
			2,
			3
		]
	},
	{
		"id": "unguarded",
		"name": "神龛蒙尘",
		"descriptions": [
			"首个门神显灵并清除撞门恶客后，所有门神立即退场",
			"所有来路均无门神守护"
		],
		"points": [
			1,
			2
		]
	},
	{
		"id": "no_capstone",
		"name": "天门闭锁",
		"descriptions": [
			"所有三级进化均被禁用"
		],
		"points": [
			3
		]
	},
	{
		"id": "one_path",
		"name": "独修一途",
		"descriptions": [
			"每株草木只能沿一个方向进化"
		],
		"points": [
			2
		]
	},
	{
		"id": "boss_power",
		"name": "凶首开煞",
		"descriptions": [
			"恶首血量、技能释放频率额外提高 50%",
			"恶首血量、技能释放频率额外提高 100%"
		],
		"points": [
			1,
			2
		],
		"boss_only": true
	},
	{
		"id": "twins",
		"name": "双煞同临",
		"descriptions": [
			"最终波同时迎战两位相同恶首；深处每次迎战均生效"
		],
		"points": [
			2
		],
		"boss_only": true
	},
	{
		"id": "rush",
		"name": "长夜催魂",
		"descriptions": [
			"各拨攻势与恶首援军的间隔缩短 25%"
		],
		"points": [
			1
		]
	},
	{
		"id": "no_ash",
		"name": "灰契封炉",
		"descriptions": [
			"不能携带标签为“灰烬”的草木；已选中的灰烬草木须在开战前取下"
		],
		"points": [
			1
		]
	},
	{"id":"cloud_silence","name":"云中绝香","map":"sky","descriptions":["浮台没入云间后，产能草木也停止运作"],"points":[1]},
	{"id":"cloud_immediate","name":"云渡抢更","map":"sky","descriptions":["开局立即开始浮台升降，取消70秒准备时间"],"points":[1]},
	{"id":"troupe_fervor","name":"红绫催客","map":"theatre","descriptions":["引路途中的恶客减伤75%；催场加速提高至100%"],"points":[1]},
	{"id":"troupe_encore","name":"急锣连场","map":"theatre","descriptions":["戏班发动能力的间隔缩短50%"],"points":[1]},
	{"id":"lamp_ward","name":"灯下藏煞","map":"ghostmarket","descriptions":["市灯亮起时，对应两路的恶客减伤20%"],"points":[1]},
	{"id":"lamp_crowd","name":"三灯赶市","map":"ghostmarket","descriptions":["每第三次三灯齐亮，亮灯期间来客总数增至1.5倍；六路各获原客流的25%"],"points":[2]}
]
const INFO = "初月 · 月色尚浅，来客稀疏，适合初到夜市的守夜人。恶客数量与血量为常夜的 0.8 倍。\n\n常夜 · 长街寻常的一夜，以原定来客与血量迎战，数量与血量均为 1 倍。\n\n沉夜 · 夜色渐浓，来客稍密、身骨稍硬，数量与血量均为常夜的 1.1 倍。\n\n噩梦 · 百鬼叩门，四种守夜方式中最为凶险。恶客数量与血量均为常夜的 1.2 倍，另可在备战时添加噩梦因子。\n\n红星与金星\n噩梦守到天亮即可独立获得第四颗红星，惊动门神也不会失去红星。三颗金星分别要求：通关、至多惊动一次门神、从未惊动门神；每颗分别保存已获得的成绩。\n\n噩梦因子\n每条旁的数字为因子数，分级词条按当前等级计分。带因子通关，可在红星旁留下朱印与最佳因子数，并收录本次挑战徽章。因子随本局保存，开战后不能更改。\n\n残灯锁香：以连续滚动的 10 秒为窗口，超出香火上限的部分不会入账。\n夜禁封市：从一大波提示出现时开始，持续 5 秒，其间不能种植或升阶。\n草木薄命：被摧毁、铲除和灰烬草木用毕均计为损失；夜莲和龟甲罩也各算一株。龟甲罩被拆除、击碎或随宿主退场时同样计入。\n独修一途：按每株草木分别限制进化路线。香价腾烟只提高升阶费用。无门神不视为惊动门神。\n行囊缄缚：按所选等级携带十株或八株；选好因子后须取下超出的牌，开战时锁定。\n\n训练、教学和使用作弊的战斗不授予噩梦星与徽章。"
static func loadout_limit(raw: Dictionary) -> int:
	return [12,10,8][clampi(int(raw.get("light_pack",0)),0,2)]

static func has_boss(level: Dictionary) -> bool:
	return String(level.get("boss_id",""))!="" or not Array(level.get("boss_checkpoints",[])).is_empty()
static func eligible(factor: Dictionary, level: Dictionary) -> bool:
	return (not factor.get("boss_only",false) or has_boss(level)) and (not factor.has("map") or factor.map == level.get("map",""))
static func sanitize(raw: Dictionary, level: Dictionary) -> Dictionary:
	var result := {}
	for f in FACTORS:
		if not eligible(f,level):continue
		var tier := clampi(int(raw.get(f.id,0)),0,f.points.size())
		if tier>0:result[f.id]=tier
	return result
static func points(raw: Dictionary) -> int:
	var total := 0
	for f in FACTORS:
		var tier := clampi(int(raw.get(f.id,0)),0,f.points.size())
		if tier>0:total+=int(f.points[tier-1])
	return total
static func flags(progress: Dictionary, id: int) -> Array:
	var raw: Array = Dictionary(progress.get("star_flags",{})).get(str(id),[])
	if raw.size()==4:return raw.duplicate()
	var legacy := clampi(int(Dictionary(progress.get("stars",{})).get(str(id),0)),0,3)
	return [legacy>=1,legacy>=2,legacy>=3,false]
static func record(progress: Dictionary,id: int,earned: Array,factors: Dictionary) -> void:
	var saved := flags(progress,id)
	for i in 4:saved[i]=bool(saved[i]) or bool(earned[i])
	var all_flags: Dictionary=progress.get("star_flags",{})
	all_flags[str(id)]=saved;progress.star_flags=all_flags
	var legacy: Dictionary=progress.get("stars",{})
	legacy[str(id)]=int(saved[0])+int(saved[1])+int(saved[2]);progress.stars=legacy
	if earned[3] and points(factors)>0:
		var badges: Dictionary=progress.get("nightmare_badges",{})
		var entry: Dictionary=badges.get(str(id),{"best":0,"builds":[]})
		entry.best=maxi(int(entry.best),points(factors))
		var signature := JSON.stringify(factors, "",true)
		if not entry.builds.has(signature):entry.builds.append(signature)
		badges[str(id)]=entry;progress.nightmare_badges=badges

static func allows_plant(type: String, raw: Dictionary) -> bool:
	return int(raw.get("no_ash",0))<=0 or String(Content.PLANTS.get(type,{}).get("role",""))!="灰烬"

static func danger_band(points_count: int) -> int:
	return 3 if points_count>=15 else 2 if points_count>=10 else 1 if points_count>=5 else 0
