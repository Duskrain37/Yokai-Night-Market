## Shared skill metadata for the simulation, battlefield, evolution panel and almanac.
extends RefCounted
const ORCHID := {
	2:{"id":"orchid-court","name":"兰庭同息","path":2,"cooldown":70.0,"unique":false,"icon":"res://assets/ui/skills/orchid-court.svg","summary":"全场草木贡献共生，各自获得其贡献层数的双倍共生，持续8秒，冷却70秒"},
	3:{"id":"orchid-rain","name":"天降甘霖","path":3,"cooldown":60.0,"unique":false,"icon":"res://assets/ui/skills/orchid-rain.svg","summary":"全场草木各获得一滴带有强化效果的雨露，冷却60秒"}
}
const DEFINITIONS := {
	"judge": {"id":"judge-sanctuary", "name":"神威护境", "path":2, "cooldown":50.0, "unique":true, "icon":"res://assets/ui/skills/judge-sanctuary.svg", "summary":"清除所有草木的负面状态，将钟馗庇护扩至全场，沉默所有恶客；使恶客移动速度降低40%、草木攻击速度提升40%，持续8秒，冷却50秒"},
	"shooter": {"id":"shooter-rain", "name":"万签骤雨", "path":3, "cooldown":45.0, "unique":false, "icon":"res://assets/ui/skills/shooter-rain.svg", "summary":"向本行连续发射130枚竹签，每发间隔0.02秒，每枚使用当前单发伤害；冷却45秒"},
	"sky-mortar": {"id":"mortar-peace", "name":"霄炮镇平安", "path":3, "cooldown":55.0, "unique":false, "icon":"res://assets/ui/skills/mortar-peace.svg", "summary":"连续发射7枚重炮，每枚基础伤害300加本株进化总次数×50、间隔0.25秒；落地前0.25秒锁定密集区，冷却55秒"},
	"ember-cicada": {"id":"ember-flare","name":"烬照长夜","path":3,"cooldown":55.0,"unique":false,"icon":"res://assets/ui/skills/ember-flare.svg","summary":"照明弹在1秒后爆开，眩晕全场恶客1.8秒，大型减半；受眩晕者看破6秒，冷却55秒"},
	"watch-bloom": {"id":"bloom-watch","name":"百更齐回","path":3,"cooldown":90.0,"unique":true,"icon":"res://assets/ui/skills/bloom-watch.svg","summary":"恢复所有种植卡的冷却，其他主动技能剩余冷却减少10秒；同名只由最先升至此阶的在场更筹花持有，冷却90秒"},
	"vow-toad": {"id":"toad-pact","name":"愿契换形","path":0,"base":true,"cooldown":10.0,"unique":false,"icon":"res://assets/ui/skills/toad-pact.svg","summary":"在蓄香与开火之间切换；百愿三阶后无切换冷却，并可进入每60秒最多12秒的超频"}
}
static func definition(type: String, path: int=0) -> Dictionary:
	if type=="blank-orchid":return ORCHID.get(path,{})
	return DEFINITIONS.get(type, {})
static func unlocked(plant) -> bool:
	var data := for_plant(plant)
	return not data.is_empty() and (bool(data.get("base",false)) or plant.tier(int(data.path)) >= 3)

static func for_plant(plant) -> Dictionary:
	if plant.type=="blank-orchid":
		for path in ORCHID:
			if plant.tier(path)>=3:return ORCHID[path]
	return definition(plant.type)
