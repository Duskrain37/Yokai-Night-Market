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
	"lily", "kelp", "gust", "firework", "squash", "dragon",
	"ruin-cap", "sky-kite", "wish-till", "cash-pod", "ember-cicada", "herb-gourd",
]

const ZOMBIE_ORDER: Array[String] = [
	"ghost", "tongue", "straw", "paper", "stonehat", "bucket",
	"vault", "mourner", "sedan", "artisan", "ironjudge", "mountain", "bride",
	"returner", "matchmaker", "phaseguard", "tamer", "shieldguard", "reedboat", "dreambell",
	"flinch", "wave-herald", "formless", "reed-shot",
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
		"name": "石磨", "role": "防御", "cost": 50, "cooldown": 18, "hp": 3000,
		"sprite_h": 108, "tint": "#a8a294",
	},
	"bomb": {
		"name": "爆竹", "role": "灰烬", "cost": 150, "cooldown": 30, "hp": 300,
		"sprite_h": 86, "bomb": {"fuse": 1.2, "radius": 150.0, "damage": 1800.0},
		"tint": "#e04832",
	},
	"bell": {
		"name": "铜铃", "role": "辅助", "cost": 125, "cooldown": 12, "hp": 300,
		"sprite_h": 96, "pulse": {"interval": 2.5, "slow": 0.25,
			"slow_duration": 1.5}, "tint": "#d8ab4c",
	},
	"censer": {"name": "香炉", "role": "范围", "cost": 150, "cooldown": 8, "hp": 340, "sprite_h": 90, "censer": {"interval": 2.5, "radius": 140.0, "damage": 45.0}, "tint": "#a4845c"},
	"umbrella": {
		"name": "纸伞", "role": "收妖", "cost": 150, "cooldown": 12, "hp": 900,
		"sprite_h": 112, "chomp": {"reach": 74.0, "chew": 6.0,
			"chew_speed": 0.0, "large_damage": 40.0,
			"large_interval": 2.0}, "tint": "#cc5a4c",
	},
	"lion": {
		"name": "醒狮", "role": "近战", "cost": 200, "cooldown": 10, "hp": 1200,
		"sprite_h": 104, "melee": {"reach": 110.0, "interval": 1.5,
			"damage": 50.0, "knock_cells": 0.2}, "tint": "#e0553a",
	},
	"mushroom": {
		"name": "坟头菇", "role": "灰烬", "cost": 25, "cooldown": 20, "hp": 300,
		"sprite_h": 86, "mine": {"arm": 14.0, "damage": 1800.0}, "tint": "#93a468",
	},
	"cat": {"name": "狐尾灯", "role": "追魂", "cost": 250, "cooldown": 8, "hp": 300, "sprite_h": 100, "homing": {"interval": 1.6, "damage": 24.0, "speed": 300.0, "count": 1}, "tint": "#e8a24e"},
	"shell": {
		"name": "龟甲罩", "role": "护罩", "cost": 100, "cooldown": 18, "hp": 1400,
		"sprite_h": 104, "attach": true, "tint": "#86966f",
	},
	"lobber": {"name": "汤圆仔", "role": "抛射", "cost": 100, "cooldown": 7, "hp": 300, "sprite_h": 94, "lob": {"interval": 2.3, "damage": 40.0, "flight": 0.9}, "tint": "#e8d6ac"},
	"torch": {
		"name": "炭火盆", "role": "增幅", "cost": 150, "cooldown": 12, "hp": 300,
		"sprite_h": 86, "torch": {"buff": 0.5}, "tint": "#e87440",
	},
	"star": {
		"name": "五路巡灯", "role": "五向", "cost": 175, "cooldown": 9, "hp": 300,
		"sprite_h": 100, "star": {"interval": 1.6, "damage": 20.0, "dirs": 5}, "tint": "#e8c25c",
	},
	"needle": {"name": "透骨针", "role": "破甲", "cost": 125, "cooldown": 8, "hp": 300, "sprite_h": 92, "needle": {"interval": 1.6, "damage": 24, "speed": 720.0}, "tint": "#e4dcc4"},
	"judge": {
		"name": "钟馗像", "role": "庇护", "cost": 125, "cooldown": 10, "hp": 900,
		"sprite_h": 106, "judge": {"interval": 1.6, "damage": 38.0, "speed": 530.0},
		"tint": "#c4503a",
	},
	"gust": {
		"name": "归风扇", "role": "灰烬", "cost": 175, "cooldown": 46, "hp": 320,
		"sprite_h": 94, "ash": true, "no_upgrade": true, "gust": {"fuse": 0.6}, "tint": "#649f99",
	},
	"firework": {
		"name": "烟花童", "role": "抛射", "cost": 275, "cooldown": 10, "hp": 320,
		"sprite_h": 100, "firework": true, "tint": "#c77941",
	},
	"squash": {
		"name": "镇煞瓜", "role": "灰烬", "cost": 75, "cooldown": 30, "hp": 300,
		"sprite_h": 88, "ash": true, "no_upgrade": true, "squash": true, "tint": "#91a46b",
	},
	"dragon": {"name": "龙首铳", "role": "近攻", "cost": 325, "cooldown": 10, "hp": 300, "sprite_h": 102, "dragon": true, "tint": "#b08d54"},
	"lily": {
		"name": "夜莲", "role": "浮台", "cost": 25, "cooldown": 5, "hp": 260,
		"sprite_h": 56, "lily": true, "water_only": true, "no_upgrade": true,
		"tint": "#5fa08c",
	},
	"herb-gourd": {"name":"回春葫","role":"扶伤","cost":175,"cooldown":22,"hp":300,"sprite_h":100,"healer":true,"tint":"#719e85"},
	"ruin-cap": {"name": "劫火芝", "role": "灰烬", "cost": 275, "cooldown": 56, "hp": 300, "sprite_h": 108, "ash": true, "no_upgrade": true, "ruin": {"fuse": 1.1, "reach": 2, "damage": 1800}, "tint": "#8b638c"},
	"sky-kite": {"name": "逐云鸢", "role": "抛射", "cost": 200, "cooldown": 8, "hp": 300, "sprite_h": 105, "kite": {"interval": 1.3}, "tint": "#60958c"},
	"wish-till": {"name": "清账匣", "role": "产能", "cost": 75, "cooldown": 16, "hp": 300, "sprite_h": 92, "till": true, "tint": "#a18452"},
	"cash-pod": {"name": "铜钱荚", "role": "灰烬", "cost": 0, "cooldown": 26, "hp": 400, "sprite_h": 78, "ash": true, "no_upgrade": true, "cash_pod": true, "tint": "#a35336"},
	"ember-cicada": {"name": "烬翼蝉", "role": "追魂", "cost": 275, "cooldown": 10, "hp": 320, "sprite_h": 105, "ember": true, "tint": "#b9673e"},
	"kelp": {
		"name": "缠魂藻", "role": "灰烬", "cost": 50, "cooldown": 20, "hp": 300,
		"sprite_h": 104, "water_only": true, "no_upgrade": true, "ash": true,
		"tangle": {"range": 120.0}, "tint": "#4d8570",
	},
}

# ── 恶客 ────────────────────────────────────────────────────────────────────
# hp 本体 / armor 护具 / speed 像素每秒 / dps 啃食每秒 / reach 啃食距离（缺省 38）
const ZOMBIES = {
	"flinch": {"name": "惊巷鬼", "kind": "惊走", "tier": "l", "hp": 110, "armor": 0, "speed": 12, "dps": 38, "sprite_h": 107, "death": "ghost", "hurt_speed": 27},
	"wave-herald": {"name": "执幡客", "kind": "报浪", "tier": "l", "hp": 90, "armor": 0, "speed": 20, "dps": 35, "sprite_h": 116, "death": "ghost", "flag_only": true},
	"formless": {"name": "泥影", "kind": "无形", "tier": "m", "hp": 170, "armor": 0, "speed": 16, "dps": 47, "sprite_h": 97, "death": "ghost", "miss_chance": 0.5},
	"reed-shot": {"name": "芦管客", "kind": "远射", "tier": "m", "hp": 270, "armor": 0, "speed": 18, "dps": 47, "sprite_h": 109, "death": "ghost", "reed_shot": {"steps": 1.5, "interval": 1.2, "damage": 40}},
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
	"returner": {
		"name": "回灯鬼", "kind": "复生", "tier": "m", "hp": 250.0, "armor": 0.0,
		"speed": 17.0, "dps": 60.0, "scale": 0.98, "sprite_h": 109, "death": "ghost",
	},
	"matchmaker": {
		"name": "红绳媒", "kind": "召唤", "tier": "h", "hp": 580.0, "armor": 0.0,
		"speed": 11.5, "dps": 65.0, "scale": 1.0, "sprite_h": 118, "death": "mourner",
		"special_period": 11.0,
	},
	"phaseguard": {
		"name": "双相傀", "kind": "变相", "tier": "m", "hp": 420.0, "armor": 0.0,
		"speed": 17.0, "dps": 70.0, "scale": 1.0, "sprite_h": 104, "death": "paper",
	},
	"tamer": {
		"name": "巡相师", "kind": "召唤", "tier": "h", "hp": 750.0, "armor": 0.0,
		"speed": 12.5, "dps": 75.0, "scale": 1.02, "sprite_h": 124, "death": "paper",
		"special_period": 9.0,
	},
	"shieldguard": {
		"name": "持牌鬼", "kind": "盾牌", "tier": "m", "hp": 340.0, "armor": 1080.0,
		"armor_type": "shield", "armor_name": "护身牌", "projectile_shield": true,
		"speed": 16.0, "dps": 70.0, "scale": 1.0, "sprite_h": 114, "death": "stonehat",
	},
	"reedboat": {
		"name": "蒲舟客", "kind": "水路", "tier": "m", "hp": 320.0, "armor": 380.0,
		"armor_type": "raft", "armor_name": "蒲舟", "water_only": true, "armor_speed": 1.9,
		"speed": 16.0, "dps": 60.0, "scale": 1.0, "sprite_h": 104, "death": "ghost",
	},
	"dreambell": {
		"name": "梦铃婆", "kind": "催眠", "tier": "h", "hp": 1050.0, "armor": 0.0,
		"speed": 13.5, "dps": 90.0, "scale": 1.0, "sprite_h": 118, "death": "mourner",
		"special_period": 11.0,
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
	{"id": 4, "name": "第四周", "sub": "孤灯屿", "map": "island", "rows": 6,
		"blurb": "潮落才显露的海岛夜市。摊面两端收窄，落石每次换位置。"},
	{"id": 5, "name": "第五周", "sub": "冥判窟", "map": "cavern", "rows": 6,
		"blurb": "地下府衙前的暗河蜿蜒穿过石道，石台有数处断裂。"},
]

const WATER_ROWS = [1, 3]
const WATER_OBJECTS = [[1, 2], [1, 5], [1, 7], [3, 3], [3, 6]]
const SPECIAL_ID := 16 # Keep existing save identifiers stable.
const CAVERN_WATER_ROWS = [4, 5]
const CAVERN_WATER_CELLS = [[1], [1, 2], [1, 2, 3], [2, 3], [0, 2, 3, 4, 5, 6, 7, 8], [0, 2, 3, 4, 5, 6, 7, 8]]
const CAVERN_PITS = [[4, 6, 7], [6, 7], [6], [], [], []]
const ISLAND_EDGE = [[0, 1, 7, 8], [0, 8], [], [], [0, 8], [0, 1, 7, 8]]
const SPECIAL_THREATS = [1.6, 2.1, 3.1, 3.6, 4.2]


static func level_id_for(week: int, night: int = 0) -> int:
	return (week - 1) * 5 + night + 1 + int(week >= 4)


static func map_key(level: Dictionary) -> String:
	return String({"street": "day1", "market": "day2", "water": "day3", "island": "day4", "cavern": "day5"}.get(level.get("map", "street"), "day1"))


static func map_picture(level: Dictionary, overview := false) -> String:
	var key := map_key(level)
	return "res://assets/bg/map-%s.%s" % [key, "jpg" if overview else "png"]

# 五种地图均为全部草木提供明确的推荐顺序。
const LOADOUT_TIPS = {
	"street": ["lantern", "shooter", "wall", "wish-till", "cash-pod", "bell", "censer", "torch", "mushroom", "bomb", "cat", "needle", "herb-gourd", "judge", "umbrella", "lion", "lobber", "star", "firework", "dragon", "squash", "gust", "shell", "sky-kite", "ember-cicada", "ruin-cap", "lily", "kelp"],
	"market": ["lantern", "shooter", "wall", "sky-kite", "lobber", "ember-cicada", "cat", "star", "bell", "herb-gourd", "bomb", "judge", "censer", "torch", "needle", "wish-till", "umbrella", "lion", "mushroom", "firework", "dragon", "squash", "gust", "shell", "cash-pod", "ruin-cap", "lily", "kelp"],
	"water": ["lily", "lantern", "shooter", "wall", "kelp", "cat", "sky-kite", "wish-till", "lobber", "herb-gourd", "bell", "firework", "censer", "torch", "needle", "judge", "star", "umbrella", "lion", "mushroom", "dragon", "squash", "bomb", "gust", "shell", "ember-cicada", "cash-pod", "ruin-cap"],
	"island": ["lantern", "shooter", "wall", "sky-kite", "ember-cicada", "star", "cash-pod", "firework", "ruin-cap", "herb-gourd", "gust", "lobber", "cat", "bomb", "judge", "censer", "wish-till", "bell", "torch", "shell", "needle", "mushroom", "squash", "dragon", "lion", "umbrella", "lily", "kelp"],
	"cavern": ["lily", "lantern", "shooter", "wall", "kelp", "sky-kite", "ember-cicada", "wish-till", "firework", "herb-gourd", "ruin-cap", "cat", "dragon", "star", "shell", "cash-pod", "lobber", "gust", "judge", "bell", "bomb", "torch", "censer", "needle", "umbrella", "lion", "mushroom", "squash"],
}


static func loadout_tips(map: String) -> Array:
	return LOADOUT_TIPS.get(map, LOADOUT_TIPS["street"])


## 前四夜的推荐会把这一夜练习所需的草木带到卡组前面。
static func night_loadout_tips(level: Dictionary) -> Array:
	var picks := loadout_tips(String(level["map"])).duplicate()
	var drills := {
		"island": ["wall", "sky-kite", "ember-cicada", "sky-kite", "ruin-cap"],
		"cavern": ["lily", "wall", "kelp", "sky-kite", "firework"],
	}
	var map := String(level["map"])
	if not drills.has(map) or bool(level.get("special", false)):
		return picks
	var card: String = drills[map][clampi(int(level.get("night", 0)), 0, 4)]
	if picks.find(card) >= 5:
		picks.erase(card)
		picks.insert(5, card)
	return picks


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
static func wave_mass_ratio(level: Dictionary, wave_index: int) -> float:
	if not level.has("night"):
		return 0.60 if int(level.get("day", 0)) == 3 and not bool(level.get("special", false)) and wave_index in range(6) else 1.0
	if wave_index < 0 or level.get("waves", []).is_empty():
		return 1.0
	var group := int(wave_index / WAVES_PER_GROUP)
	var count := wave_groups(level)
	var phase := mini(2, int(float(group) * 3.0 / count))
	return [0.56, 0.9, 1.26][phase] * (0.60 if group < 2 else 1.0)


static func wave_low_only(level: Dictionary, wave_index: int) -> bool:
	return wave_index in [0, 1] and (level.has("night") or (int(level.get("day", 0)) == 3 and not bool(level.get("special", false))))


static func allows_high_tier(wave_index: int) -> bool:
	return wave_index < 0 or wave_index >= 3 * WAVES_PER_GROUP


static func wave_guest_type(guest: String, wave_index: int) -> String:
	if not allows_high_tier(wave_index) and ZOMBIES.get(guest, {}).get("tier", "") == "h":
		return "paper"
	return guest


static func checkpoint_threat(level: Dictionary, checkpoint: int) -> float:
	var waves: Array = level.get("waves", [])
	var index := clampi(checkpoint * 4 * WAVES_PER_GROUP, 0, maxi(0, waves.size() - 1))
	return float(waves[index].get("threat", level.get("threat", 1.0))) if not waves.is_empty() else 1.0


## Convert weighted terrain loss to combat pressure. Water remains usable after planting a float.
static func terrain_factor(level: Dictionary) -> float:
	var map := String(level.get("map", ""))
	if map not in ["island", "cavern"]:
		return 1.0
	var weights: Array = level["lane_weights"]
	var burden := 0.0
	for row in 6:
		var denied := float(ISLAND_EDGE[row].size()) if map == "island" else float(CAVERN_PITS[row].size())
		var extra: float = (1.25 if row in [1, 2, 3, 4] else 0.0) if map == "island" else CAVERN_WATER_CELLS[row].size() * 0.40
		burden += float(weights[row]) * (denied + extra)
	return 1.0 + burden / 900.0


static func wave_sub(wave_index: int) -> int:
	return int(wave_index % WAVES_PER_GROUP) + 1


static func is_flag_batch(wave_index: int) -> bool:
	return wave_index >= 0 and wave_sub(wave_index) == WAVES_PER_GROUP


static func wave_text(level: Dictionary, wave_index: int) -> String:
	var group = mini(wave_group_of(level, wave_index) + 1, wave_groups(level))
	return "第 %d 大波 · 第 %d 拨" % [group, wave_sub(wave_index)]


## 每周五夜在本周威胁区间内等距取点。
const DAY_THREAT_RANGE = [
	[0.4, 1.2],
	[0.6, 1.6],
	[0.8, 2.1],
	[1.0, 3.0],
	[1.4, 3.6],
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
	[
		{"name": "第一夜", "tag": "靠岸", "band": "mid_soft"},
		{"name": "第二夜", "tag": "盐雾", "band": "mid"},
		{"name": "第三夜", "tag": "碎石", "band": "mid"},
		{"name": "第四夜", "tag": "潮祠", "band": "mid_late"},
		{"name": "第五夜", "tag": "潮灯", "band": "late"},
	],
	[
		{"name": "第一夜", "tag": "入窟", "band": "mid"},
		{"name": "第二夜", "tag": "断桥", "band": "mid_late"},
		{"name": "第三夜", "tag": "渡影", "band": "late"},
		{"name": "第四夜", "tag": "听审", "band": "late"},
		{"name": "第五夜", "tag": "鬼官", "band": "late"},
	],
]

const NIGHT_LESSONS = [
	[
		["熟悉五条街道。先攒香火，每行留一处能出手的草木。", ""],
		["斗笠和石帽能挡住头几下。让同一行两株草木合力拆甲。", "stonehat"],
		["跳幡鬼会跃过第一株草木。前面用石磨接它，输出往后放。", "vault"],
		["回灯鬼倒下还能站起来。等这一行安静了，再把香火花去别处。", "returner"],
		["熟客与生客都会上门。留些香火应付恶首换行和援军。", ""],
	],
	[
		["木栈和岸道隔得更开。先看清每一行从哪里来客，再落子。", ""],
		["哭丧鬼会拖慢近处的草木。用更远的射程先打它。", "mourner"],
		["持牌鬼专挡射弹。让近身草木或爆竹绕开这块牌。", "shieldguard"],
		["纸扎匠会给身边的恶客补护具。先把它请下场。", "artisan"],
		["今夜各路恶客都会来，缚愿纸官也会带来援军。", ""],
	],
	[
		["两条水路把暗河分开。先铺夜莲，也给水路留出输出。", ""],
		["蒲舟客只走水路，浮舟没破时走得快。先给水路补一层防线。", "reedboat"],
		["双相傀会换相。把直射和抛射布在一起，两种身相都能应付。", "phaseguard"],
		["梦铃婆会让草木打盹。关键一行留两处输出，别只指望一株。", "dreambell"],
		["水陆各路恶客都会出没。暗河傩主现身后，留意它占住哪两行。", ""],
	],
	[["今夜先熟悉海岛的摊位。中间两行最宽，外侧两行的边角无法种植，先从中间排起防线。", ""],
	 ["落石和碎木会占住摊位，恶客却能翻过去。布不下直射草木时，把逐云鸢种在障碍后方。", "stonehat"],
	 ["今夜练补刀。回灯鬼倒下还会再起，在它那一行留一株持续出手的草木。", "returner"],
	 ["今夜练打断召唤。巡相师会唤来双相傀，逐云鸢升到缄音第三阶，可以暂时封住它的特殊能力。", "tamer"],
	 ["潮灯夜叉会换行并引潮冲击摊位。给多行留火力，手里留些香火应对潮涌。", ""]],
	[["今夜先辨水面与石台。水道沿各行弯折，青色水面先放夜莲，黑色坑洞不能种植。", ""],
	 ["今夜练守坑口。恶客会跨过断裂石台，在它落地的位置摆石磨，输出放在石磨后面。", "vault"],
	 ["今夜练守水路。蒲舟客只从最下两路来，浮舟击沉后仍能游动。缠魂藻可以拖沉一名水中恶客。", "reedboat"],
	 ["今夜练应对催眠。梦铃婆会让一株草木睡去，在同一路分开布置两处火力。", "dreambell"],
	 ["第四大波先迎战受限的鬼官。打退它后还有四大波，把香火和补位留给第八大波的真身。", ""]],
]

const NIGHT_INTRODUCTIONS = [
	[["ghost", "tongue", "paper"], ["straw", "stonehat", "flinch"], ["vault", "bucket", "formless"], ["returner", "mourner", "reed-shot"]],
	[["ghost", "tongue", "straw", "paper", "mountain"], ["mourner", "stonehat", "bucket", "flinch"],
		["shieldguard", "vault", "returner", "formless"], ["artisan", "sedan", "ironjudge", "reed-shot"]],
	[["ghost", "tongue", "straw", "paper", "mountain"], ["reedboat", "stonehat", "bucket"],
		["phaseguard", "returner", "vault", "shieldguard", "tamer"], ["dreambell", "mourner", "sedan", "matchmaker"]],
	[["ghost", "tongue", "straw", "paper", "mountain"], ["stonehat", "bucket", "vault"],
		["returner", "phaseguard", "mourner"], ["tamer", "shieldguard", "artisan"]],
	[["ghost", "tongue", "straw", "paper", "mountain"], ["vault", "stonehat", "bucket"],
		["reedboat", "returner", "phaseguard", "shieldguard"], ["dreambell", "tamer", "artisan", "sedan"]],
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
			var id := level_id_for(day_index + 1, night)
			var span: Array = DAY_THREAT_RANGE[day_index]
			var threat := snappedf(lerpf(float(span[0]), float(span[1]), night / 4.0) + 0.000001, 0.01)
			out.append({
				"id": id,
				"day": day["id"],
				"night": night,
				"day_name": day["name"],
				"day_sub": day["sub"],
				"map": day["map"],
				"rows": day["rows"],
				"name": info["name"],
				"tag": info["tag"],
				"threat": threat,
				"band": info["band"],
				"theme": NIGHT_LESSONS[day_index][night][0],
				"theme_zombie": NIGHT_LESSONS[day_index][night][1],
				"water_rows": CAVERN_WATER_ROWS if day_index == 4 else (WATER_ROWS if day_index == 2 else []),
				"lane_weights": [10, 16, 24, 24, 16, 10] if day_index == 3 else ([10, 20, 20, 20, 15, 15] if day_index == 4 else []),
				"object_cells": WATER_OBJECTS if day["map"] == "water" else [],
				"start_sun": 100,
				"wave_groups": [4, 4, 6, 6, 8][night],
				"boss_id": ["earth", "paper", "river", "island", "magistrate-full"][day_index] if night == 4 else "",
				"mid_boss": "magistrate-bound" if day_index == 4 and night == 4 else "",
				"waves": _night_roster(_with_guest_variants(build_waves(info["band"], [4, 4, 6, 6, 8][night]),
					day_index + 1, night), day_index, night),
			})
	# 鬼市深处：二十大波，每四大波迎战一位恶首。
	var special_waves: Array=[]
	for section in SPECIAL_THREATS.size():
		var chunk = _with_guest_variants(build_waves("late", 4), 3, 4)
		for wave in chunk:
			wave.t=float(wave.t)+section*216.0
			wave.threat= SPECIAL_THREATS[section]
			if not allows_high_tier(special_waves.size()):
				wave["budget_groups"] = wave["groups"]
				wave["groups"] = wave["budget_groups"].map(func(group):
					return [wave_guest_type(group[0], special_waves.size()), group[1]])
			special_waves.append(wave)
	out.insert(SPECIAL_ID - 1, {"id":SPECIAL_ID,"special":true,"day":5,"night":0,"day_name":"特殊关","day_sub":"鬼市深处",
		"map":"cavern","rows":6,"name":"鬼市深处","tag":"终极守夜","threat":SPECIAL_THREATS[0],"band":"late",
		"water_rows":CAVERN_WATER_ROWS,"lane_weights":[10,20,20,20,15,15],"object_cells":[],"start_sun":100,"wave_groups":20,"boss_id":"",
		"boss_checkpoints":["earth","paper","river","island","magistrate-full"],"waves":special_waves,
		"theme":"二十大波，五场恶首。每四波击退一位恶首，带着阵容和香火继续深入。",
		"theme_zombie":""})
	return out


## Keep the exact scheduled count, timing, and original durability budget. Only substitute roles.
static func _night_roster(waves: Array, week: int, night: int) -> Array:
	var allowed: Array = []
	if night == 4:
		for type in ZOMBIE_ORDER:
			if not bool(ZOMBIES[type].get("sedan_only", false)) and not bool(ZOMBIES[type].get("flag_only", false)) and (week in [2, 4] or not bool(ZOMBIES[type].get("water_only", false))):
				allowed.append(type)
	else:
		for i in range(night + 1):
			allowed.append_array(NIGHT_INTRODUCTIONS[week][i])
	var substitutes := {"l": "ghost", "m": "paper", "h": "mountain"}
	var previous := {}
	var slots: Array = []
	for index in waves.size():
		var wave: Dictionary = waves[index]
		wave["budget_groups"] = wave["groups"]
		wave["guest_slots"] = []
		for group in wave["budget_groups"]:
			var original: String = group[0]
			var candidate: String = original if original in allowed else substitutes[ZOMBIES[original]["tier"]]
			var type := wave_guest_type(candidate, index)
			var replacements: Array = []
			for i in int(group[1]):
				replacements.append(candidate)
				if index >= 2 and index < waves.size() - (WAVES_PER_GROUP if night == 4 else 0):
					slots.append({"picks": replacements, "slot": i, "wave_index": index})
					previous[type] = int(previous.get(type, 0)) + 1
			wave["guest_slots"].append(replacements)
	# Ensure a first encounter with every newly eligible type before the boss takes over.
	for wanted in allowed:
		if previous.has(wanted):
			continue
		var tier: String = ZOMBIES[wanted]["tier"]
		var donor_tiers := [tier]
		# The first week's boss night has fewer high-tier slots than distinct high-tier guests.
		# Borrow a late middle-tier slot, with no increase to the original batch's budget.
		if night == 4 and tier == "h":
			donor_tiers.append("m")
		for donor in donor_tiers:
			for i in range(slots.size() - 1, -1, -1):
				var slot: Dictionary = slots[i]
				if tier == "h" and not allows_high_tier(slot.wave_index):
					continue
				var incumbent := wave_guest_type(slot.picks[slot.slot], slot.wave_index)
				if ZOMBIES[incumbent]["tier"] != donor or int(previous[incumbent]) < 2:
					continue
				slot.picks[slot.slot] = wanted
				previous[incumbent] -= 1
				previous[wanted] = 1
				break
			if previous.has(wanted):
				break
	for index in waves.size():
		var wave: Dictionary = waves[index]
		var counts := {}
		for picks in wave["guest_slots"]:
			for guest in picks:
				var type := wave_guest_type(guest, index)
				counts[type] = int(counts.get(type, 0)) + 1
		wave["groups"] = []
		for type in counts:
			wave["groups"].append([type, counts[type]])
	return waves


## 某一天（1—3）的威胁区间，界面用它把当天的五夜排成一条自己的尺。
## 最新用户规则：这些是实际关卡系数，暗河不再另加码；玩家界面只画进度条。
## Replace slots within their original tier. The new guests change tactics without adding spawns.
static func _with_guest_variants(waves: Array, week: int, night: int) -> Array:
	if week == 1 and night >= 2:
		_replace_guest(waves, 8, "returner")
	elif week == 2:
		_replace_guest(waves, 6, "returner")
		_replace_guest(waves, 8, "phaseguard")
		if night >= 2:
			_replace_guest(waves, 10, "shieldguard")
		if night >= 3:
			_replace_guest(waves, 11, "dreambell")
	elif week == 3:
		_replace_guest(waves, 6, "reedboat")
		_replace_guest(waves, 7, "returner")
		_replace_guest(waves, 8, "phaseguard")
		_replace_guest(waves, 9, "shieldguard")
		_replace_guest(waves, 10, "dreambell")
		_replace_guest(waves, 11, "matchmaker")
		if night >= 2:
			_replace_guest(waves, 11, "tamer")
			_replace_guest(waves, 15, "reedboat")
	return waves


static func _replace_guest(waves: Array, index: int, guest: String) -> void:
	if index >= waves.size():
		return
	var groups: Array = waves[index]["groups"]
	var tier = ZOMBIES[guest]["tier"]
	for i in groups.size():
		var old = groups[i]
		if String(old[0]) in ["returner", "matchmaker", "phaseguard", "tamer", "shieldguard", "reedboat", "dreambell"]:
			continue
		if ZOMBIES[String(old[0])]["tier"] != tier:
			continue
		if int(old[1]) == 1:
			groups.remove_at(i)
		else:
			old[1] = int(old[1]) - 1
		groups.append([guest, 1])
		return


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
	# 其后按第四组相对第三组的非负增量延续各阶数量，
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
	# 每个大波的最后一拨承接该组最多的各阶来客，组内各阶总数和时间表照旧。
	for first in range(0, plan.size(), WAVES_PER_GROUP):
		for tier in ["l", "m", "h"]:
			var counts: Array[int] = []
			for offset in WAVES_PER_GROUP:
				counts.append(int(plan[first + offset].get(tier, 0)))
			counts.sort()
			for offset in WAVES_PER_GROUP:
				plan[first + offset][tier] = counts[offset]
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
	if zombie_type == "wave-herald":
		return "第一周·第一夜 第1大波"
	if zombie_type == "bride":
		zombie_type = "sedan"
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
	var seen: Array = ["wave-herald"]
	for wave in level["waves"]:
		for group in wave["groups"]:
			if not seen.has(group[0]):
				seen.append(group[0])
	var ordered: Array = []
	for type in ZOMBIE_ORDER:
		if seen.has(type) or (type == "bride" and (seen.has("sedan") or seen.has("matchmaker"))):
			ordered.append(type)
	return ordered


static func next_story_level(id: int) -> int:
	var ids: Array[int]=[]
	for week in range(1,DAYS.size()+1):
		for night in 5:ids.append(level_id_for(week,night))
	var at:=ids.find(id)
	return ids[at+1] if at>=0 and at+1<ids.size() else 0
