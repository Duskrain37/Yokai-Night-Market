## Shared skill metadata for the simulation, battlefield, evolution panel and almanac.
extends RefCounted
const DEFINITIONS := {
	"judge": {"id":"judge-sanctuary", "name":"神威护境", "path":2, "cooldown":50.0, "unique":true, "icon":"res://assets/ui/skills/judge-sanctuary.svg", "summary":"驱散草木负面状态，庇护全场、沉默恶客，减速与攻速增幅40%，持续8秒"},
	"shooter": {"id":"shooter-rain", "name":"万签骤雨", "path":3, "cooldown":45.0, "unique":false, "icon":"res://assets/ui/skills/shooter-rain.svg", "summary":"向本行连续发射130枚竹签，间隔0.02秒"},
	"sky-mortar": {"id":"mortar-peace", "name":"霄炮镇平安", "path":3, "cooldown":55.0, "unique":false, "icon":"res://assets/ui/skills/mortar-peace.svg", "summary":"7枚660伤害重炮，间隔0.25秒；临近落地锁定密集区"}
}
static func definition(type: String) -> Dictionary:
	return DEFINITIONS.get(type, {})
static func unlocked(plant) -> bool:
	var data := definition(plant.type)
	return not data.is_empty() and plant.tier(int(data.path)) >= 3
