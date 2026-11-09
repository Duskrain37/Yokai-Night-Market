## Nightmare factors are immutable per run. Levels are sanitized against stage eligibility.
extends RefCounted
const FACTORS = [
	{"id":"price","name":"进化涨价","descriptions":["所有进化费用提高 50%","所有进化费用提高 100%"],"points":[1,2]},
	{"id":"curfew","name":"宵禁","descriptions":["一大波恶客到来后的 5 秒内不能种植或升阶"],"points":[1]},
	{"id":"swarm","name":"群鬼压境","descriptions":["恶客数量与血量额外提高 10%","恶客数量与血量额外提高 20%","恶客数量与血量额外提高 40%"],"points":[1,2,3]},
	{"id":"early","name":"邪客早至","descriptions":["中阶、高阶恶客的阵容提前一大波到来"],"points":[1]},
	{"id":"dim","name":"灯火昏暗","descriptions":["任意连续 10 秒内最多获得 750 香火","任意连续 10 秒内最多获得 500 香火"],"points":[1,2]},
	{"id":"loss","name":"草木珍贵","descriptions":["损失达到 20 株草木即告失守","损失达到 10 株草木即告失守"],"points":[1,3]},
	{"id":"seeds","name":"种子稀少","descriptions":["场上最多同时存在 25 株草木","场上最多同时存在 15 株草木"],"points":[1,2]},
	{"id":"unguarded","name":"门神失修","descriptions":["所有来路均无门神守护"],"points":[1]},
	{"id":"no_capstone","name":"潜能封锁","descriptions":["所有三级进化均被禁用"],"points":[2]},
	{"id":"one_path","name":"独修一途","descriptions":["每株草木只能沿一个方向进化"],"points":[2]},
	{"id":"boss_power","name":"恶首逞威","descriptions":["恶首血量、技能释放频率额外提高 50%","恶首血量、技能释放频率额外提高 100%"],"points":[1,2],"boss_only":true},
	{"id":"twins","name":"呼朋引伴","descriptions":["最终波同时迎战两位相同恶首；深处每次迎战均生效"],"points":[2],"boss_only":true},
	{"id":"rush","name":"攻势不歇","descriptions":["各拨攻势与恶首援军的间隔缩短 25%"],"points":[1]},
]
const INFO = "噩梦中，恶客的数量与血量均为简单的 1.35 倍。\n\n守到天亮即可独立获得第四颗红星，惊动门神也不会失去红星。三颗金星分别要求：通关、至多惊动一次门神、从未惊动门神；每颗分别保存已获得的成绩。\n\n备战时可自由添加噩梦因子，每条旁的数字是因子数，分档词条按当前档位计分。带因子通关，可在红星旁留下朱印与最佳因子数，并收录本次挑战徽章。\n\n灯火限制使用连续滚动的 10 秒窗口，超出部分不会入账。草木损失包括被摧毁、铲除和灰烬草木用毕；夜莲和龟甲罩也各算一株；龟甲罩被拆除、击碎或随宿主退场时也计入损失。独修一途按每株草木分别限制。进化涨价仅提高升阶费用；宵禁从一大波提示出现时开始，持续 5 秒。无门神因子不视为惊动门神。\n\n因子随本局保存，开战后不能更改。训练、教学、三卡试炼和使用作弊的战斗不授予噩梦星与徽章。"
static func has_boss(level: Dictionary) -> bool:
	return String(level.get("boss_id",""))!="" or not Array(level.get("boss_checkpoints",[])).is_empty()
static func sanitize(raw: Dictionary, level: Dictionary) -> Dictionary:
	var result := {}
	for f in FACTORS:
		if f.get("boss_only",false) and not has_boss(level):continue
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
