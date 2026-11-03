## 内容表：《妖怪夜市》全部草木、恶客、三天地图与十五夜。
##
## 数值来源：v0.2.4 的 www/src/content.js（草木/恶客/天数/关卡/波次），2026-11-01
## 起以 reviews/2026-11-01/妖怪夜市v0.3.0_数值表_修订v2.docx 的进化表为准
## （升阶树在 data/upgrades.gd，白板与本表第 0 档必须一致，rules_check 会盯）。
## 图鉴文案由数据推导，避免手抄数值走样。
class_name Content
extends RefCounted

const COLS = 9

const PLANT_ORDER: Array[String] = [
	"lantern", "shooter", "wall", "bomb", "bell", "censer", "umbrella", "lion",
	"mushroom", "cat", "shell", "lobber", "torch", "star", "needle", "judge",
	"lily", "kelp", "gust", "firework",
]

const ZOMBIE_ORDER: Array[String] = [
	"ghost", "tongue", "straw", "paper", "stonehat", "bucket",
	"vault", "mourner", "sedan", "artisan", "ironjudge", "mountain", "bride",
]

const TIERS = {
	"l": {"label": "低阶", "short": "低", "color": "#7f9d7a"},
	"m": {"label": "中阶", "short": "中", "color": "#c99a4a"},
	"h": {"label": "高阶", "short": "高", "color": "#b5493e"},
}

# ── 草木 ────────────────────────────────────────────────────────────────────
# cost 香火 / cooldown 冷却秒 / hp 耐久 / sprite_h 立绘高度基准（像素，1600×900 画布）
const PLANTS = {
	"lantern": {
		"name": "红灯笼", "role": "产能", "cost": 50, "cooldown": 5, "hp": 300,
		"sprite_h": 92, "produce": {"interval": 8.0, "first": 5.0, "value": 25},
		"tint": "#e8563a",
	},
	"shooter": {
		"name": "签筒", "role": "射线", "cost": 100, "cooldown": 5, "hp": 300,
		"sprite_h": 106, "shot": {"interval": 1.4, "damage": 20.0, "speed": 520.0},
		"tint": "#d8b06a",
	},
	"wall": {
		"name": "石磨", "role": "防御", "cost": 50, "cooldown": 20, "hp": 3000,
		"sprite_h": 108, "tint": "#a8a294",
	},
	"bomb": {
		"name": "爆竹", "role": "灰烬", "cost": 150, "cooldown": 30, "hp": 300,
		"sprite_h": 86, "bomb": {"fuse": 1.2, "radius": 150.0, "damage": 1800.0},
		"tint": "#e04832",
	},
	"bell": {
		"name": "铜铃", "role": "辅助", "cost": 125, "cooldown": 20, "hp": 300,
		"sprite_h": 96, "pulse": {"interval": 2.5, "slow": 0.25,
			"slow_duration": 1.5}, "tint": "#d8ab4c",
	},
	"censer": {
		"name": "香炉", "role": "范围", "cost": 150, "cooldown": 18, "hp": 340,
		"sprite_h": 90, "censer": {"interval": 3.0, "radius": 140.0,
			"damage": 45.0}, "tint": "#a4845c",
	},
	"umbrella": {
		"name": "纸伞", "role": "收妖", "cost": 150, "cooldown": 16, "hp": 900,
		"sprite_h": 112, "chomp": {"reach": 74.0, "chew": 6.0,
			"chew_speed": 0.0, "large_damage": 40.0,
			"large_interval": 2.0}, "tint": "#cc5a4c",
	},
	"lion": {
		"name": "醒狮", "role": "近战", "cost": 200, "cooldown": 20, "hp": 1200,
		"sprite_h": 104, "melee": {"reach": 110.0, "interval": 1.5,
			"damage": 50.0, "knock_cells": 0.2}, "tint": "#e0553a",
	},
	"mushroom": {
		"name": "坟头菇", "role": "灰烬", "cost": 25, "cooldown": 20, "hp": 300,
		"sprite_h": 86, "mine": {"arm": 14.0, "damage": 1800.0}, "tint": "#93a468",
	},
	"cat": {
		"name": "狐尾灯", "role": "追魂", "cost": 175, "cooldown": 20, "hp": 300,
		"sprite_h": 100, "homing": {"interval": 1.6, "damage": 24.0, "speed": 300.0,
			"count": 1}, "tint": "#e8a24e",
	},
	"shell": {
		"name": "龟甲罩", "role": "护罩", "cost": 100, "cooldown": 25, "hp": 1400,
		"sprite_h": 104, "attach": true, "tint": "#86966f",
	},
	"lobber": {
		"name": "汤圆仔", "role": "抛射", "cost": 125, "cooldown": 12, "hp": 300,
		"sprite_h": 94, "lob": {"interval": 2.6, "damage": 40.0, "flight": 0.9},
		"tint": "#e8d6ac",
	},
	"torch": {
		"name": "炭火盆", "role": "增幅", "cost": 150, "cooldown": 20, "hp": 300,
		"sprite_h": 86, "torch": {"buff": 0.5}, "tint": "#e87440",
	},
	"star": {
		"name": "五路巡灯", "role": "五向", "cost": 175, "cooldown": 22, "hp": 300,
		"sprite_h": 100, "star": {"interval": 1.6, "damage": 20.0, "dirs": 5}, "tint": "#e8c25c",
	},
	"needle": {
		"name": "透骨针", "role": "破甲", "cost": 125, "cooldown": 18, "hp": 300,
		"sprite_h": 92, "needle": {"interval": 1.7, "damage": 18.0, "speed": 720.0},
		"tint": "#e4dcc4",
	},
	"judge": {
		"name": "钟馗像", "role": "庇护", "cost": 125, "cooldown": 20, "hp": 900,
		"sprite_h": 106, "judge": {"interval": 1.6, "damage": 38.0, "speed": 530.0},
		"tint": "#c4503a",
	},
	"gust": {
		"name": "归风扇", "role": "灰烬", "cost": 175, "cooldown": 46, "hp": 320,
		"sprite_h": 94, "ash": true, "no_upgrade": true, "gust": {"fuse": 0.6}, "tint": "#649f99",
	},
	"firework": {
		"name": "烟花童", "role": "抛射", "cost": 200, "cooldown": 24, "hp": 320,
		"sprite_h": 100, "firework": true, "tint": "#c77941",
	},
	"lily": {
		"name": "夜莲", "role": "浮台", "cost": 25, "cooldown": 5, "hp": 260,
		"sprite_h": 56, "lily": true, "water_only": true, "no_upgrade": true,
		"tint": "#5fa08c",
	},
	"kelp": {
		"name": "缠魂藻", "role": "灰烬", "cost": 50, "cooldown": 20, "hp": 300,
		"sprite_h": 104, "water_only": true, "no_upgrade": true, "ash": true,
		"tangle": {"range": 120.0, "drag": 0.5, "damage": 1800.0}, "tint": "#4d8570",
	},
}

# ── 恶客 ────────────────────────────────────────────────────────────────────
# hp 本体 / armor 护具 / speed 像素每秒 / dps 啃食每秒 / reach 啃食距离（缺省 38）
const ZOMBIES = {
	"ghost": {
		"name": "饿鬼", "kind": "小僵尸", "tier": "l",
		"hp": 90.0, "armor": 0.0, "speed": 21.0, "dps": 35.0,
		"scale": 1.0, "sprite_h": 104, "death": "ghost",
	},
	"paper": {
		"name": "纸人", "kind": "特殊", "tier": "m",
		"hp": 420.0, "armor": 250.0, "armor_type": "paper", "armor_name": "纸壳",
		"speed": 19.0, "dps": 80.0, "scale": 1.05, "sprite_h": 106, "death": "paper",
	},
	"mountain": {
		"name": "山魈", "kind": "重型", "tier": "h", "large": true,
		"hp": 1800.0, "armor": 0.0, "speed": 16.0, "dps": 180.0,
		"scale": 1.28, "sprite_h": 128, "death": "mountain",
	},
	"tongue": {
		"name": "长舌鬼", "kind": "超小", "tier": "l",
		"hp": 80.0, "armor": 0.0, "speed": 30.0, "dps": 45.0, "reach": 62.0,
		"scale": 0.98, "sprite_h": 100, "death": "tongue",
	},
	"mourner": {
		"name": "哭丧鬼", "kind": "特殊", "tier": "m",
		"hp": 620.0, "armor": 0.0, "speed": 16.0, "dps": 75.0,
		"scale": 1.06, "sprite_h": 112, "death": "mourner",
		"aura": {"radius": 150.0, "interval": 4.5, "haste": 1.35, "duration": 2.6},
	},
	"sedan": {
		"name": "抬轿鬼", "kind": "重型", "tier": "h", "large": true,
		"hp": 520.0, "armor": 950.0, "armor_type": "sedan", "armor_name": "轿壳",
		"speed": 14.0, "dps": 120.0, "scale": 1.0, "sprite_h": 118, "death": "sedan",
		"split": {"type": "ghost", "count": 2, "hp": 0.6},
	},
	"bride": {
		"name": "鬼新娘", "kind": "轿中客", "tier": "m",
		"hp": 460.0, "armor": 0.0, "speed": 19.0, "dps": 75.0,
		"scale": 1.03, "sprite_h": 108, "death": "ghost", "ash_immune": true,
		"sedan_only": true,
	},
	"straw": {
		"name": "斗笠鬼", "kind": "小僵尸", "tier": "l",
		"hp": 90.0, "armor": 90.0, "armor_type": "straw", "armor_name": "斗笠",
		"speed": 22.0, "dps": 35.0, "scale": 0.95, "sprite_h": 100, "death": "straw",
	},
	"stonehat": {
		"name": "石帽鬼", "kind": "护甲", "tier": "m",
		"hp": 240.0, "armor": 320.0, "armor_type": "stonehat", "armor_name": "石帽",
		"speed": 18.0, "dps": 75.0, "scale": 1.02, "sprite_h": 110, "death": "stonehat",
	},
	"bucket": {
		"name": "瓮头鬼", "kind": "重甲", "tier": "m",
		"hp": 300.0, "armor": 620.0, "armor_type": "urn", "armor_name": "陶瓮",
		"speed": 15.0, "dps": 90.0, "scale": 1.06, "sprite_h": 112, "death": "bucket",
	},
	"vault": {
		"name": "跳幡鬼", "kind": "特殊", "tier": "m",
		"hp": 280.0, "armor": 0.0, "speed": 30.0, "dps": 60.0,
		"scale": 1.0, "sprite_h": 114, "death": "vault",
		"vault": {"speed_after": 18.0, "duration": 0.55, "distance": 0.9},
	},
	"artisan": {
		"name": "纸扎匠", "kind": "辅助", "tier": "h", "large": true,
		"hp": 1100.0, "armor": 0.0, "speed": 14.0, "dps": 90.0,
		"scale": 1.04, "sprite_h": 120, "death": "artisan",
		"support": {"interval": 7.5, "radius": 240.0, "armor": 200.0, "targets": 2,
			"name": "纸甲"},
	},
	"ironjudge": {
		"name": "铁面判官", "kind": "重甲", "tier": "h", "large": true,
		"hp": 1000.0, "armor": 800.0, "armor_type": "mask", "armor_name": "铁面",
		"speed": 12.0, "dps": 150.0, "scale": 1.12, "sprite_h": 126, "death": "ironjudge",
	},
}

# ── 三天 ────────────────────────────────────────────────────────────────────
const DAYS = [
	{"id": 1, "name": "第一周", "sub": "夜市街", "map": "street", "rows": 5,
		"blurb": "青石板的旧夜市，五条摊位一线排开。"},
	{"id": 2, "name": "第二周", "sub": "河埠口", "map": "market", "rows": 6,
		"blurb": "临河的六道木栈，靠右四列有杂物挡道。"},
	{"id": 3, "name": "第三周", "sub": "暗河", "map": "water", "rows": 5,
		"blurb": "暗河两岸，第二、四行是水，得先铺夜莲。"},
]

const WATER_ROWS = [1, 3]
const WATER_OBJECTS = [[1, 2], [1, 5], [1, 7], [3, 3], [3, 6]]

# 每周的推荐配卡顺序：备战「按今夜推荐配卡」取前十张，缺夜莲的一键替换也按这张表挑替身。
# 三张表都排满全部草木，漏排的那张表会让「最不该带的」判不出来。
const LOADOUT_TIPS = {
	# 夜市街：五条平地一线排开，先站稳再讲输出
	"street": ["lantern", "shooter", "wall", "bell", "censer", "torch", "cat",
		"needle", "judge", "umbrella", "lion", "lobber", "star", "mushroom",
		"firework", "bomb", "gust", "shell", "lily", "kelp"],
	# 河埠口：右四列有杂物挡道，种不进去就得靠抛物线、跨行与长手
	"market": ["lantern", "shooter", "wall", "bell", "lobber", "cat", "judge",
		"star", "censer", "torch", "needle", "umbrella", "lion", "mushroom",
		"firework", "bomb", "gust", "shell", "lily", "kelp"],
	# 暗河：第二、四行是水，先铺夜莲才种得下别的东西，缠魂藻只在水里做事
	"water": ["lily", "lantern", "shooter", "wall", "kelp", "bell", "cat",
		"lobber", "censer", "torch", "needle", "judge", "star", "umbrella",
		"lion", "mushroom", "firework", "bomb", "gust", "shell"],
}


static func loadout_tips(map: String) -> Array:
	return LOADOUT_TIPS.get(map, LOADOUT_TIPS["street"])


static func tip_rank(map: String, type: String) -> int:
	var rank := loadout_tips(map).find(type)
	return 999 if rank < 0 else rank

# 每关 12 波。三套主档（early/mid/late）+ 三套混编过渡档（early_mid/mid_soft/mid_late）：
# 过渡档只把下一档的中高阶减半引入，让单夜需求 DPS 的环比涨幅留在 +90% 以内
# （剩下的 +87%/+74% 两处是新恶客登场夜，是故意的）。
# 新一周的第一夜用轻一档的 mid_soft：它的压力要落在上一周第 3~4 夜之间——
# 「开局喘口气」是用户定的规则，qa_sweep.gd 每次扫描都会核对这条。
const WAVE_PLANS = {
	"early": [
		{"l": 1}, {"l": 2}, {"l": 2, "flag": true}, {"l": 3}, {"l": 3}, {"l": 4, "flag": true},
		{"l": 4, "m": 1}, {"l": 4, "m": 1}, {"l": 5, "m": 1, "flag": true},
		{"l": 6, "m": 2}, {"l": 6, "m": 2}, {"l": 7, "m": 3, "flag": true},
	],
	"early_mid": [
		{"l": 1}, {"l": 2}, {"l": 2, "flag": true}, {"l": 3}, {"l": 3, "m": 1},
		{"l": 4, "m": 1, "flag": true}, {"l": 4, "m": 2}, {"l": 4, "m": 2},
		{"l": 5, "m": 2, "flag": true}, {"l": 5, "m": 3}, {"l": 6, "m": 3},
		{"l": 6, "m": 4, "flag": true},
	],
	# 新一周第一夜用：比 early_mid 重、比 mid 轻，让「开局喘一口气」落在上周第 3~4 夜之间
	"mid_soft": [
		{"l": 2}, {"l": 2}, {"l": 2, "flag": true}, {"l": 4}, {"l": 4, "m": 2},
		{"l": 4, "m": 2, "flag": true}, {"l": 4, "m": 2}, {"l": 5, "m": 3},
		{"l": 5, "m": 2, "flag": true}, {"l": 6, "m": 4}, {"l": 6, "m": 4, "h": 1},
		{"l": 7, "m": 5, "h": 2, "flag": true},
	],
	"mid": [
		{"l": 2}, {"l": 3}, {"l": 3, "flag": true}, {"l": 4}, {"l": 4, "m": 2},
		{"l": 5, "m": 3, "flag": true}, {"l": 5, "m": 3}, {"l": 6, "m": 4},
		{"l": 5, "m": 3, "h": 1, "flag": true}, {"l": 6, "m": 4, "h": 1},
		{"l": 7, "m": 5, "h": 2}, {"l": 8, "m": 6, "h": 3, "flag": true},
	],
	"mid_late": [
		{"l": 2}, {"l": 3}, {"l": 3, "flag": true}, {"l": 4, "m": 1}, {"l": 4, "m": 2},
		{"l": 5, "m": 2, "flag": true}, {"l": 5, "m": 3}, {"l": 6, "m": 3},
		{"l": 5, "m": 3, "h": 1, "flag": true}, {"l": 5, "m": 4, "h": 1},
		{"l": 5, "m": 4, "h": 2}, {"l": 6, "m": 5, "h": 2, "flag": true},
	],
	"late": [
		{"l": 2, "m": 1}, {"l": 2, "m": 1}, {"l": 3, "m": 1, "flag": true},
		{"l": 3, "m": 2}, {"l": 3, "m": 2, "h": 1}, {"l": 4, "m": 3, "flag": true},
		{"l": 4, "m": 3, "h": 2}, {"l": 5, "m": 4, "h": 2}, {"m": 3, "h": 2, "flag": true},
		{"m": 4, "h": 2}, {"m": 4, "h": 3}, {"m": 5, "h": 3, "flag": true},
	],
}

## 一大波 = 原来三小波，12 小波合成 4 大波。出怪的种类与数量完全不变，
## 只是把"旗帜波"每三小波放一面（第 3/6/9/12 小波），报幕只在旗帜波上放。
const WAVES_PER_GROUP = 3


static func wave_groups(level: Dictionary) -> int:
	return int(ceil(Array(level["waves"]).size() / float(WAVES_PER_GROUP)))


static func wave_group_of(level: Dictionary, wave_index: int) -> int:
	return int(floor(float(wave_index) / WAVES_PER_GROUP))


static func current_major_wave(level: Dictionary,released: int) -> int:
	return mini(wave_group_of(level,maxi(0,released-1))+1,wave_groups(level))


static func visible_wave_groups(level: Dictionary,released: int) -> Array:
	var start=int((current_major_wave(level,released)-1)/4)*4
	return range(start,mini(start+4,wave_groups(level)))


## 玩家语言只有一套：一夜 = 几大波，一大波里 = 三小拨。
## 内部仍按 12 小波排波（wave_index），所有界面都走这两个函数换算。
static func wave_sub(wave_index: int) -> int:
	return int(wave_index % WAVES_PER_GROUP) + 1


static func wave_text(level: Dictionary, wave_index: int) -> String:
	var group = mini(wave_group_of(level, wave_index) + 1, wave_groups(level))
	return "第 %d 大波 · 第 %d 拨" % [group, wave_sub(wave_index)]


## 每周的威胁区间（用户 2026-11-01 定）：第一周 0.8—1.6、第二周 1.0—2.0、第三周 1.2—2.5。
## 每夜在当天的区间里等距取点，天数之间因此是「区间递进」而不是硬跳。
const DAY_THREAT_RANGE = [
	[0.8, 1.6],
	[1.0, 2.0],
	[1.2, 2.5],
]

const DAY_LEVELS = [
	[
		{"name": "第一夜", "tag": "开张", "threat": 0.8, "band": "early"},
		{"name": "第二夜", "tag": "熟客", "threat": 1.0, "band": "early"},
		{"name": "第三夜", "tag": "起风", "threat": 1.2, "band": "early_mid"},
		{"name": "第四夜", "tag": "灯多", "threat": 1.4, "band": "early_mid"},
		{"name": "第五夜", "tag": "山雨", "threat": 1.6, "band": "early_mid",
			"theme_zombie": "vault",
			"theme": "跳幡鬼会直接跳过最前面那一株。这一夜只练一件事：拿便宜的石磨去接它，把输出留在后面。"},
	],
	[
		{"name": "第一夜", "tag": "河埠", "threat": 1.0, "band": "mid_soft"},
		{"name": "第二夜", "tag": "潮声", "threat": 1.25, "band": "mid_soft"},
		{"name": "第三夜", "tag": "木栈", "threat": 1.5, "band": "mid"},
		{"name": "第四夜", "tag": "客舟", "threat": 1.75, "band": "mid_late",
			"theme_zombie": "artisan",
			"theme": "纸扎匠一路给身边的恶客补护具。这一夜只练一件事：先把它请下场，再跟护具算账。"},
		{"name": "第五夜", "tag": "不眠", "threat": 2.0, "band": "late"},
	],
	[
		{"name": "第一夜", "tag": "暗河", "threat": 1.2, "band": "late",
			"theme_zombie": "",
			"theme": "两条水路把五行切成三段，一行守不住邻行。这一夜只练一件事：留出能跨行支援的草木。"},
		{"name": "第二夜", "tag": "臭水", "threat": 1.53, "band": "late"},
		{"name": "第三夜", "tag": "浮桥", "threat": 1.85, "band": "late"},
		{"name": "第四夜", "tag": "水鬼", "threat": 2.18, "band": "late"},
		{"name": "第五夜", "tag": "天亮前", "threat": 2.5, "band": "late"},
	],
]


static var LEVELS: Array = []


static func _static_init() -> void:
	LEVELS = _build_levels()


static func _build_levels() -> Array:
	var out: Array = []
	for day_index in DAYS.size():
		var day: Dictionary = DAYS[day_index]
		for night in 5:
			var info: Dictionary = DAY_LEVELS[day_index][night]
			var id = day_index * 5 + night + 1
			out.append({
				"id": id,
				"day": day["id"],
				"day_name": day["name"],
				"day_sub": day["sub"],
				"map": day["map"],
				"rows": day["rows"],
				"name": info["name"],
				"tag": info["tag"],
				"threat": info["threat"],
				"band": info["band"],
				"theme": String(info.get("theme", "")),
				"theme_zombie": String(info.get("theme_zombie", "")),
				"water_rows": WATER_ROWS if day["map"] == "water" else [],
				"object_cells": WATER_OBJECTS if day["map"] == "water" else [],
				"start_sun": 100,
				"wave_groups": [4, 4, 6, 6, 8][night],
				"boss_id": ["earth", "paper", "river"][day_index] if night == 4 else "",
				"waves": build_waves(info["band"], [4, 4, 6, 6, 8][night]),
			})
	# Special gauntlet: twelve regular major waves PLUS three checkpoint bosses.
	var special_waves: Array=[]
	for section in 3:
		var chunk=build_waves("late",4)
		for wave in chunk:
			wave.t=float(wave.t)+section*216.0
			wave.threat=[2.0,2.5,3.5][section]
			special_waves.append(wave)
	out.append({"id":16,"special":true,"day":3,"day_name":"特殊关","day_sub":"鬼市深处",
		"map":"water","rows":5,"name":"鬼市深处","tag":"终极守夜","threat":2.0,"band":"late",
		"water_rows":WATER_ROWS,"object_cells":WATER_OBJECTS,"start_sun":100,"wave_groups":12,"boss_id":"",
		"boss_checkpoints":["earth","paper","river"],"waves":special_waves,
		"theme":"十二大波，三场首领。每四波结束后击退首领，保留阵容与香火，再进入更深一层。",
		"theme_zombie":""})
	return out


## 某一天（1—3）的威胁区间，界面用它把当天的五夜排成一条自己的尺。
## 最新用户规则：这些是实际关卡系数，暗河不再另加码；玩家界面只画进度条。
static func day_threat_range(day: int) -> Array:
	if day < 1 or day > DAY_THREAT_RANGE.size():
		return [0.8, 3.0]
	return DAY_THREAT_RANGE[day - 1]


## 把威胁值折算成「在当天区间里的位置」0—1。
static func threat_ratio(level: Dictionary) -> float:
	var span = day_threat_range(int(level.get("day", 1)))
	var low = float(span[0])
	var high = float(span[1])
	if high - low <= 0.0001:
		return 0.0
	return clampf((float(level["threat"]) - low) / (high - low), 0.0, 1.0)


static func get_level(id: int) -> Dictionary:
	for level in LEVELS:
		if level["id"] == id:
			return level
	return LEVELS[0]


static func build_waves(band: String, group_count: int = 4) -> Array:
	# 前四大波逐字保留。其后按第四组相对第三组的非负增量延续各阶数量，
	# 具体敌人仍交给同一套 _add_tier_group；不改变关卡 threat 或 sqrt 缩放。
	var base: Array = WAVE_PLANS.get(band, WAVE_PLANS["early"])
	var plan: Array = base.duplicate(true)
	for group_index in range(4, group_count):
		for sub in WAVES_PER_GROUP:
			var next: Dictionary = {"flag": sub == WAVES_PER_GROUP - 1}
			for tier in ["l", "m", "h"]:
				var last = int(base[9 + sub].get(tier, 0))
				var prior = int(base[6 + sub].get(tier, 0))
				next[tier] = last + (group_index - 3) * maxi(0, last - prior)
			plan.append(next)
	var waves: Array = []
	for wi in plan.size():
		var wave: Dictionary = plan[wi]
		var groups: Array = []
		for tier in ["l", "m", "h"]:
			_add_tier_group(groups, tier, int(wave.get(tier, 0)), wi)
		waves.append({
			"t": (17.5 if wi == 0 else 16.0) + wi * 18.0,
			"flag": bool(wave.get("flag", false)),
			"groups": groups,
		})
	return waves


## 低/中/高三阶各自按波次展开成具体恶客（与 v0.2.4 的 addTierGroup 同规则）。
static func _add_tier_group(groups: Array, tier: String, count: int, wi: int) -> void:
	if count <= 0:
		return
	if tier == "l":
		if wi < 3:
			groups.append(["ghost", count])
			return
		var tongue = 0
		if count >= 2:
			tongue = mini(count, int(floor(count * 0.35)))
		elif wi % 4 == 3:
			tongue = 1
		var straw = 0
		if count - tongue >= 2:
			straw = mini(count - tongue, maxi(1, int(floor(count * 0.2))))
		elif wi % 5 == 4:
			straw = 1
		if count - tongue - straw > 0:
			groups.append(["ghost", count - tongue - straw])
		if tongue > 0:
			groups.append(["tongue", tongue])
		if straw > 0:
			groups.append(["straw", straw])
	elif tier == "m":
		var rest = count
		var mourner = 0
		var bucket = 0
		var vault = 0
		var stonehat = 0
		if wi >= 7 and rest >= 2:
			mourner = mini(rest - 1, maxi(1, int(floor(count * 0.2))))
			rest -= mourner
		if wi >= 6 and rest >= 2:
			bucket = mini(rest - 1, maxi(1, int(floor(count * 0.25))))
			rest -= bucket
		if wi >= 5 and rest >= 2:
			vault = mini(rest - 1, maxi(1, int(floor(count * 0.25))))
			rest -= vault
		if wi >= 3 and rest >= 1:
			stonehat = mini(rest, maxi(1, int(floor(count * 0.3))))
			rest -= stonehat
		if rest > 0:
			groups.append(["paper", rest])
		if stonehat > 0:
			groups.append(["stonehat", stonehat])
		if bucket > 0:
			groups.append(["bucket", bucket])
		if vault > 0:
			groups.append(["vault", vault])
		if mourner > 0:
			groups.append(["mourner", mourner])
	else:
		var rest = count
		var pool: Array = []
		if wi >= 6:
			pool.append("sedan")
		if wi >= 8:
			pool.append("artisan")
		if wi >= 9:
			pool.append("ironjudge")
		var special_count = mini(maxi(0, count - 1), pool.size())
		var start = wi % pool.size() if pool.size() > 0 else 0
		var specials: Array = []
		for i in special_count:
			specials.append(pool[(start + i) % pool.size()])
		rest -= special_count
		for type in specials:
			groups.append([type, 1])
		if rest > 0:
			groups.append(["mountain", rest])


## 关卡里第一次出现某种恶客的夜与波（图鉴「初遇」栏用）。
static func first_appearance(zombie_type: String) -> String:
	for level in LEVELS:
		var waves: Array = level["waves"]
		for i in waves.size():
			for group in waves[i]["groups"]:
				if group[0] == zombie_type and int(group[1]) > 0:
					return "%s·%s 第%d大波" % [level["day_name"], level["name"],
						int(i / WAVES_PER_GROUP) + 1]
	return ""


static func tier_label(tier: String) -> String:
	return TIERS.get(tier, {}).get("label", "")


static func plants_in_level(level: Dictionary) -> Array:
	"""该关可能出现的恶客种类（备战页展示用，按首次出现顺序）。"""
	var seen: Array = []
	for wave in level["waves"]:
		for group in wave["groups"]:
			if not seen.has(group[0]):
				seen.append(group[0])
	var ordered: Array = []
	for type in ZOMBIE_ORDER:
		if seen.has(type):
			ordered.append(type)
	return ordered
