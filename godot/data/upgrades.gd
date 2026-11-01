## 升阶系统：13 株可升阶草木，每株三路、每路三级；两条路可开，只有一条能到三级。
##
## 数值与文案来自 v0.2.4 的 www/src/game/upgrade.js。
## 设计不变量：满进化必须「略亏」——UPGRADE_COST_SCALE 让每株最强一路的
## 「收益增幅 / 费用增幅」始终小于 1（实测 88%—91%），满进化是省格子，不是纯赚。
class_name Upgrades
extends RefCounted

const RED = "#d2492f"
const TEAL = "#4f8a86"
const GOLD = "#d0a044"

const UPGRADE_COST_SCALE = {
	"shooter": 1.2, "lantern": 0.25, "wall": 0.3, "bell": 0.4, "censer": 0.78,
	"umbrella": 0.4, "lion": 1.3, "cat": 1.25, "lobber": 0.63, "torch": 0.4,
	"star": 0.5, "needle": 0.3, "judge": 0.45,
}

const TREES = {
	"shooter": [
		{"id": 1, "name": "连发", "color": RED, "tiers": [
			{"name": "双发", "desc": "一次攻击射出两支竹签", "cost": 75},
			{"name": "四发", "desc": "一次攻击射出四支竹签", "cost": 150},
			{"name": "六发", "desc": "一次攻击射出六支竹签", "cost": 250},
		]},
		{"id": 2, "name": "邻行", "color": TEAL, "tiers": [
			{"name": "借行", "desc": "向相邻行补射一发半伤竹签，两侧相通时交替", "cost": 75},
			{"name": "双邻", "desc": "同时向上下两行各补射一发半伤竹签", "cost": 150},
			{"name": "全力", "desc": "邻行补射提升为全额伤害", "cost": 250},
		]},
		{"id": 3, "name": "重弹", "color": GOLD, "tiers": [
			{"name": "重弹", "desc": "10% 概率射出一发双倍伤害的大竹签", "cost": 75},
			{"name": "重型", "desc": "大竹签概率提升到 20%", "cost": 150},
			{"name": "霜重", "desc": "大竹签概率提升到 30%，命中后减速敌人 50%，持续 3 秒", "cost": 250},
		]},
	],
	"lantern": [
		{"id": 1, "name": "香火", "color": GOLD, "tiers": [
			{"name": "旺火", "desc": "每次产出香火 25 → 35", "cost": 75},
			{"name": "长明", "desc": "每次产出香火提升到 50", "cost": 150},
			{"name": "灯会", "desc": "每次产出香火提升到 75", "cost": 250},
		]},
		{"id": 2, "name": "灯油", "color": RED, "tiers": [
			{"name": "挑芯", "desc": "产出间隔 8 秒 → 7 秒", "cost": 75},
			{"name": "双芯", "desc": "产出间隔缩短到 6 秒", "cost": 150},
			{"name": "火树", "desc": "产出间隔缩短到 5 秒", "cost": 250},
		]},
		{"id": 3, "name": "红火", "color": "#e05a30", "tiers": [
			{"name": "旺友", "desc": "增幅前方 1 格友军，伤害 +20%", "cost": 75},
			{"name": "连旺", "desc": "增幅范围扩展到前方 3 格，伤害 +20%", "cost": 150},
			{"name": "满街红火", "desc": "增幅整行友军，伤害 +25%", "cost": 250},
		]},
	],
	"wall": [
		{"id": 1, "name": "自愈", "color": "#7f8d94", "tiers": [
			{"name": "渗养", "desc": "未被啃食时每秒恢复 20 生命", "cost": 75},
			{"name": "石心", "desc": "未被啃食时每秒恢复 40 生命", "cost": 150},
			{"name": "不坏", "desc": "被啃食时也能每秒恢复 40 生命", "cost": 250},
		]},
		{"id": 2, "name": "粗粝", "color": "#a86a48", "tiers": [
			{"name": "磨齿", "desc": "被啃时每秒反伤敌人 15", "cost": 75},
			{"name": "重磨", "desc": "反伤提升到 30/秒", "cost": 150},
			{"name": "碾磨", "desc": "反伤提升到 50/秒", "cost": 250},
		]},
		{"id": 3, "name": "碎石", "color": GOLD, "tiers": [
			{"name": "磨石", "desc": "每 2.8 秒向本行前方射出一块碎石，伤害 20", "cost": 75},
			{"name": "石屑", "desc": "碎石命中使目标获得 10% 易伤，持续 3 秒", "cost": 150},
			{"name": "飞石", "desc": "碎石击退非大型单位 0.4 格；对大型单位改为伤害加倍", "cost": 250},
		]},
	],
	"bell": [
		{"id": 1, "name": "急铃", "color": RED, "tiers": [
			{"name": "快摇", "desc": "摇铃间隔 2.5 秒 → 2 秒", "cost": 75},
			{"name": "连响", "desc": "摇铃间隔缩短到 1.5 秒", "cost": 150},
			{"name": "惊魂", "desc": "减速效果增强到 40%", "cost": 250},
		]},
		{"id": 2, "name": "和鸣", "color": TEAL, "tiers": [
			{"name": "应声", "desc": "摇铃也增幅身前一格友方，攻速 +减速值的一半", "cost": 75},
			{"name": "共振", "desc": "攻速增幅提升到等同于减速值", "cost": 150},
			{"name": "满堂", "desc": "增幅范围扩展到整行友军", "cost": 250},
		]},
		{"id": 3, "name": "荡魂", "color": GOLD, "tiers": [
			{"name": "声浪", "desc": "摇铃对前方 4 格敌人造成 40 伤害", "cost": 75},
			{"name": "贯街", "desc": "伤害范围扩展到整行", "cost": 150},
			{"name": "定魄", "desc": "攻击有 20% 概率定身 0.4 秒，对大型敌人无效", "cost": 250},
		]},
	],
	"censer": [
		{"id": 1, "name": "炉火", "color": RED, "tiers": [
			{"name": "旺炉", "desc": "每圈香雾伤害 45 → 70", "cost": 75},
			{"name": "猛火", "desc": "香雾伤害提升到 100", "cost": 150},
			{"name": "熔金", "desc": "香雾伤害提升到 140", "cost": 250},
		]},
		{"id": 2, "name": "烟气", "color": TEAL, "tiers": [
			{"name": "扩烟", "desc": "香雾半径 1.6 格 → 1.8 格，能熏到更远的邻行", "cost": 75},
			{"name": "浓烟", "desc": "香雾半径扩大到 2.1 格", "cost": 150},
			{"name": "满街", "desc": "香雾半径扩大到 2.4 格", "cost": 250},
		]},
		{"id": 3, "name": "安神", "color": GOLD, "tiers": [
			{"name": "静气", "desc": "被香雾熏到的敌人减速 25%，持续 2 秒", "cost": 75},
			{"name": "宁神", "desc": "减速提升到 35%，持续 2.5 秒", "cost": 150},
			{"name": "入定", "desc": "减速提升到 45%，持续 3 秒", "cost": 250},
		]},
	],
	"umbrella": [
		{"id": 1, "name": "收伞", "color": RED, "tiers": [
			{"name": "快收", "desc": "收妖速度加快 10%", "cost": 75},
			{"name": "卷云", "desc": "收妖速度加快 20%", "cost": 150},
			{"name": "一伞收", "desc": "收妖速度加快 40%", "cost": 250},
		]},
		{"id": 2, "name": "还愿", "color": GOLD, "tiers": [
			{"name": "回香", "desc": "收妖完成后产出 50 香火", "cost": 75},
			{"name": "厚礼", "desc": "收妖完成后产出 100 香火", "cost": 150},
			{"name": "满愿", "desc": "收妖完成后产出 225 香火", "cost": 250},
		]},
		{"id": 3, "name": "护纸", "color": TEAL, "tiers": [
			{"name": "紧纸", "desc": "收妖期间受到伤害降低 25%", "cost": 75},
			{"name": "油纸", "desc": "收妖期间受到伤害降低 50%", "cost": 150},
			{"name": "不破", "desc": "收妖期间受到伤害降低 75%", "cost": 250},
		]},
	],
	"lion": [
		{"id": 1, "name": "狮头", "color": RED, "tiers": [
			{"name": "开脸", "desc": "撞头伤害 50 → 72", "cost": 75},
			{"name": "点睛", "desc": "撞头伤害提升到 98", "cost": 150},
			{"name": "吞煞", "desc": "撞头伤害提升到 130，击退距离增加 50%", "cost": 250},
		]},
		{"id": 2, "name": "步法", "color": TEAL, "tiers": [
			{"name": "踩桩", "desc": "攻击间隔 1.5 秒 → 1.35 秒", "cost": 75},
			{"name": "腾挪", "desc": "攻击间隔缩短到 1.2 秒", "cost": 150},
			{"name": "扑食", "desc": "攻击间隔缩短到 1.05 秒，25% 概率撞晕 0.65 秒", "cost": 250},
		]},
		{"id": 3, "name": "采青", "color": GOLD, "tiers": [
			{"name": "衔青", "desc": "每次撞中敌人回复自身 25 耐久", "cost": 75},
			{"name": "纳福", "desc": "每次撞中回复 45 耐久", "cost": 150},
			{"name": "瑞气", "desc": "每次撞中回复 70 耐久", "cost": 250},
		]},
	],
	"cat": [
		{"id": 1, "name": "多尾", "color": RED, "tiers": [
			{"name": "双尾", "desc": "一次放出 2 团尾火", "cost": 75},
			{"name": "三尾", "desc": "一次放出 3 团尾火", "cost": 150},
			{"name": "四尾", "desc": "一次放出 4 团尾火", "cost": 250},
		]},
		{"id": 2, "name": "重尾", "color": GOLD, "tiers": [
			{"name": "重焰", "desc": "尾火伤害 24 → 26", "cost": 75},
			{"name": "烈尾", "desc": "尾火伤害提升到 27", "cost": 150},
			{"name": "回魂", "desc": "每团尾火命中后可再追一个目标", "cost": 250},
		]},
		{"id": 3, "name": "缠魂", "color": TEAL, "tiers": [
			{"name": "沾魂", "desc": "尾火命中附带 5% 易伤，持续 2 秒", "cost": 75},
			{"name": "缠丝", "desc": "易伤提升到 10%", "cost": 150},
			{"name": "锁魂", "desc": "易伤提升到 20%，并使目标减速 15% 1.5 秒", "cost": 250},
		]},
	],
	"lobber": [
		{"id": 1, "name": "馅足", "color": RED, "tiers": [
			{"name": "大馅", "desc": "汤圆伤害 40 → 55", "cost": 75},
			{"name": "双馅", "desc": "汤圆伤害提升到 75", "cost": 150},
			{"name": "满馅", "desc": "汤圆伤害提升到 100", "cost": 250},
		]},
		{"id": 2, "name": "快手", "color": TEAL, "tiers": [
			{"name": "快包", "desc": "投掷间隔 2.6 秒 → 2.2 秒", "cost": 75},
			{"name": "连抛", "desc": "投掷间隔缩短到 1.9 秒", "cost": 150},
			{"name": "如雨", "desc": "投掷间隔缩短到 1.6 秒", "cost": 250},
		]},
		{"id": 3, "name": "黏汤", "color": GOLD, "tiers": [
			{"name": "糖心", "desc": "落点使目标减速 20%，持续 2 秒", "cost": 75},
			{"name": "拉丝", "desc": "减速提升到 30%", "cost": 150},
			{"name": "封口", "desc": "减速提升到 40%", "cost": 250},
		]},
	],
	"torch": [
		{"id": 1, "name": "旺焰", "color": RED, "tiers": [
			{"name": "烈焰", "desc": "穿过火盆的射弹伤害 +80%", "cost": 75},
			{"name": "赤焰", "desc": "穿过火盆的射弹伤害 +105%", "cost": 150},
			{"name": "不熄", "desc": "穿过火盆的射弹伤害 +130%", "cost": 250},
		]},
		{"id": 2, "name": "余烬", "color": GOLD, "tiers": [
			{"name": "火屑", "desc": "穿过的射弹命中附带 5 伤害/秒，持续 2 秒", "cost": 75},
			{"name": "流火", "desc": "灼烧提升到 9 伤害/秒", "cost": 150},
			{"name": "燎原", "desc": "灼烧提升到 14 伤害/秒", "cost": 250},
		]},
		{"id": 3, "name": "火舌", "color": TEAL, "tiers": [
			{"name": "舔焰", "desc": "穿过的射弹命中使目标减速 10%，持续 1.5 秒", "cost": 75},
			{"name": "卷火", "desc": "减速提升到 18%", "cost": 150},
			{"name": "火墙", "desc": "减速提升到 25%", "cost": 250},
		]},
	],
	"star": [
		{"id": 1, "name": "灯芒", "color": GOLD, "tiers": [
			{"name": "亮街", "desc": "每道灯焰伤害 16 → 20", "cost": 75},
			{"name": "通明", "desc": "每道灯焰伤害提升到 26", "cost": 150},
			{"name": "满城", "desc": "每道灯焰伤害提升到 32", "cost": 250},
		]},
		{"id": 2, "name": "转灯", "color": TEAL, "tiers": [
			{"name": "快转", "desc": "发灯间隔 2.6 秒 → 2.2 秒", "cost": 75},
			{"name": "连转", "desc": "发灯间隔缩短到 1.9 秒", "cost": 150},
			{"name": "灯轮", "desc": "发灯间隔缩短到 1.6 秒", "cost": 250},
		]},
		{"id": 3, "name": "灯蚀", "color": RED, "tiers": [
			{"name": "蚀焰", "desc": "灯焰命中附带 5% 易伤，持续 2 秒", "cost": 75},
			{"name": "落焰", "desc": "易伤提升到 10%", "cost": 150},
			{"name": "灯瘴", "desc": "易伤提升到 15%", "cost": 250},
		]},
	],
	"needle": [
		{"id": 1, "name": "针锋", "color": RED, "tiers": [
			{"name": "透甲", "desc": "穿骨针伤害 18 → 23", "cost": 75},
			{"name": "穿骨", "desc": "穿骨针伤害提升到 29", "cost": 150},
			{"name": "钉魂", "desc": "穿骨针伤害提升到 36", "cost": 250},
		]},
		{"id": 2, "name": "快针", "color": TEAL, "tiers": [
			{"name": "连刺", "desc": "出针间隔 1.7 秒 → 1.45 秒", "cost": 75},
			{"name": "急刺", "desc": "出针间隔缩短到 1.2 秒", "cost": 150},
			{"name": "无影", "desc": "出针间隔缩短到 1.0 秒", "cost": 250},
		]},
		{"id": 3, "name": "破绽", "color": GOLD, "tiers": [
			{"name": "寻隙", "desc": "命中附带 5% 易伤，持续 2 秒", "cost": 75},
			{"name": "裂甲", "desc": "易伤提升到 10%", "cost": 150},
			{"name": "破军", "desc": "易伤提升到 15%", "cost": 250},
		]},
	],
	"judge": [
		{"id": 1, "name": "镇宅", "color": RED, "tiers": [
			{"name": "怒目", "desc": "击退距离 0.4 格 → 0.55 格", "cost": 75},
			{"name": "显圣", "desc": "击退距离提升到 0.7 格", "cost": 150},
			{"name": "巡街", "desc": "击退距离提升到 0.9 格", "cost": 250},
		]},
		{"id": 2, "name": "请神", "color": TEAL, "tiers": [
			{"name": "急召", "desc": "显灵间隔 5.5 秒 → 4.8 秒", "cost": 75},
			{"name": "连召", "desc": "显灵间隔缩短到 4.1 秒", "cost": 150},
			{"name": "显灵", "desc": "显灵间隔缩短到 3.5 秒", "cost": 250},
		]},
		{"id": 3, "name": "判官笔", "color": GOLD, "tiers": [
			{"name": "勾魂", "desc": "显灵伤害 40 → 50", "cost": 75},
			{"name": "断罪", "desc": "显灵伤害提升到 60", "cost": 150},
			{"name": "判死", "desc": "显灵伤害提升到 72", "cost": 250},
		]},
	],
}

## 逐阶数值表：下标 = 该路等级（0 = 未开）。
const EFFECTS = {
	"shooter": {
		"volley": [1, 2, 4, 6],
		"adjacent_sides": [0, 1, 2, 2],
		"adjacent_factor": [0.0, 0.5, 0.5, 1.0],
		"crit_chance": [0.0, 0.1, 0.2, 0.3],
		"crit_slow": [0.0, 0.0, 0.0, 3.0],
	},
	"lantern": {
		"value": [25, 35, 50, 75],
		"interval": [8.0, 7.0, 6.0, 5.0],
		"buff_range": [0, 1, 3, 99],
		"buff_damage": [0.0, 0.2, 0.2, 0.25],
	},
	"wall": {
		"heal": [0.0, 20.0, 40.0, 40.0],
		"heal_while_eaten": [false, false, false, true],
		"reflect": [0.0, 15.0, 30.0, 50.0],
		"gravel": [0, 1, 1, 1],
		"gravel_damage": [0.0, 20.0, 20.0, 20.0],
		"gravel_interval": 2.8,
		"vuln": [0.0, 0.0, 0.1, 0.1],
		"vuln_duration": 3.0,
		"knock_cells": [0.0, 0.0, 0.0, 0.4],
	},
	"bell": {
		"interval": [2.5, 2.0, 1.5, 1.5],
		"slow_duration": 1.5,
		"slow": [0.25, 0.25, 0.25, 0.4],
		"haste_range": [0, 1, 1, 99],
		"haste_factor": [0.0, 0.5, 1.0, 1.0],
		"damage": [0.0, 40.0, 40.0, 40.0],
		"damage_range": [0, 4, 99, 99],
		"root_chance": [0.0, 0.0, 0.0, 0.2],
		"root_duration": 0.4,
	},
	"censer": {
		"interval": 3.0,
		"damage": [45.0, 70.0, 100.0, 140.0],
		"radius": [140.0, 160.0, 185.0, 215.0],
		"slow": [0.0, 0.25, 0.35, 0.45],
		"slow_duration": [0.0, 2.0, 2.5, 3.0],
	},
	"umbrella": {
		"chew_speed": [0.0, 0.1, 0.2, 0.4],
		"sun": [0.0, 50.0, 100.0, 225.0],
		"chew_guard": [0.0, 0.25, 0.5, 0.75],
		"large_damage": 40.0,
		"large_interval": 2.0,
	},
	"lion": {
		"damage": [50.0, 72.0, 98.0, 130.0],
		"interval": [1.5, 1.35, 1.2, 1.05],
		"stun_chance": [0.0, 0.0, 0.0, 0.25],
		"stun_duration": 0.65,
		"heal": [0.0, 25.0, 45.0, 70.0],
		"reach": 110.0,
		"knock_cells": 0.2,
		"knock_bonus": [1.0, 1.0, 1.0, 1.5],
	},
	"cat": {
		"interval": 1.6,
		"damage": [24.0, 26.0, 27.0, 28.0],
		"speed": 300.0,
		"count": [1, 2, 3, 4],
		"hits": [1, 1, 1, 2],
		"vuln": [0.0, 0.05, 0.1, 0.2],
		"vuln_duration": 2.0,
		"slow": [0.0, 0.0, 0.0, 0.15],
		"slow_duration": 1.5,
	},
	"lobber": {
		"interval": [2.6, 2.2, 1.9, 1.6],
		"damage": [40.0, 55.0, 75.0, 100.0],
		"flight": 0.9,
		"slow": [0.0, 0.2, 0.3, 0.4],
		"slow_duration": 2.0,
	},
	"torch": {
		"buff": [0.5, 0.8, 1.05, 1.3],
		"burn": [0.0, 5.0, 9.0, 14.0],
		"burn_duration": 2.0,
		"slow": [0.0, 0.1, 0.18, 0.25],
		"slow_duration": 1.5,
	},
	"star": {
		"interval": [2.6, 2.2, 1.9, 1.6],
		"damage": [16.0, 20.0, 26.0, 32.0],
		"vuln": [0.0, 0.05, 0.1, 0.15],
		"vuln_duration": 2.0,
	},
	"needle": {
		"interval": [1.7, 1.45, 1.2, 1.0],
		"damage": [18.0, 23.0, 29.0, 36.0],
		"vuln": [0.0, 0.05, 0.1, 0.15],
		"vuln_duration": 2.0,
	},
	"judge": {
		"interval": [5.5, 4.8, 4.1, 3.5],
		"damage": [40.0, 50.0, 60.0, 72.0],
		"knock_cells": [0.4, 0.55, 0.7, 0.9],
		"reach": 260.0,
	},
	"shell": {"hp": 1400.0},
}


static func paths_for(type: String) -> Array:
	return TREES.get(type, [])


static func init_upgrades() -> Dictionary:
	return {1: 0, 2: 0, 3: 0}


static func effect(type: String, key: String, tier: int) -> Variant:
	var row: Dictionary = EFFECTS.get(type, {})
	var values: Variant = row.get(key)
	if values is Array:
		return values[clampi(tier, 0, values.size() - 1)]
	return values


static func opened_paths(upgrades: Dictionary, type: String) -> int:
	var count = 0
	for path in paths_for(type):
		if int(upgrades.get(path["id"], 0)) > 0:
			count += 1
	return count


static func other_path_has_tier3(upgrades: Dictionary, type: String, path_id: int) -> bool:
	for path in paths_for(type):
		if int(path["id"]) != path_id and int(upgrades.get(path["id"], 0)) >= 3:
			return true
	return false


## 返回 {ok, kind, path, tier, next_tier, cost, name, desc, reason}
static func path_status(type: String, upgrades: Dictionary, path_id: int) -> Dictionary:
	var path = {}
	for candidate in paths_for(type):
		if int(candidate["id"]) == path_id:
			path = candidate
			break
	if path.is_empty():
		return {"ok": false, "kind": "none", "path": {}, "tier": 0,
			"reason": "此物无法升阶"}
	var tier = int(upgrades.get(path_id, 0))
	if tier >= 3:
		return {"ok": false, "kind": "maxed", "path": path, "tier": tier,
			"reason": "%s已修到三级" % path["name"]}
	if tier == 0 and opened_paths(upgrades, type) >= 2:
		return {"ok": false, "kind": "locked", "path": path, "tier": tier,
			"reason": "已选两路，第三路关闭"}
	if tier == 2 and other_path_has_tier3(upgrades, type, path_id):
		return {"ok": false, "kind": "locked3", "path": path, "tier": tier,
			"reason": "另一路已到三级，此路三级关闭"}
	var next: Dictionary = path["tiers"][tier]
	var scale: float = float(UPGRADE_COST_SCALE.get(type, 1.0))
	return {
		"ok": true, "kind": "next", "path": path, "tier": tier,
		"next_tier": tier + 1,
		"cost": maxi(10, int(round(float(next["cost"]) * scale / 5.0)) * 5),
		"name": next["name"], "desc": next["desc"],
		"reason": "",
	}


## 某一路在某级的显示费用（含系数），升阶菜单与图鉴共用。
static func tier_cost(type: String, path_id: int, tier: int) -> int:
	for path in paths_for(type):
		if int(path["id"]) != path_id:
			continue
		if tier < 1 or tier > path["tiers"].size():
			return 0
		var base = float(path["tiers"][tier - 1]["cost"])
		var scale: float = float(UPGRADE_COST_SCALE.get(type, 1.0))
		return maxi(10, int(round(base * scale / 5.0)) * 5)
	return 0
