## 固定策略机器人：qa_battle（回归断言）与 qa_sweep（十五夜曲线）共用同一套打法。
##
## 它只代表"一个会玩的普通玩家"，不是平衡结论的唯一依据；但同一套打法在版本之间
## 的胜负变化，是难度曲线最省事的回归信号。
class_name QaBot
extends RefCounted

const LOADOUT = [
	"lantern", "shooter", "wall", "bell", "censer",
	"umbrella", "lion", "torch", "needle", "lily",
]


## 跑完一夜。返回 {sim, won, lost, max_shots, bad}；bad 非空表示模拟本身出错。
static func play(level_id: int, seed_value: int = 7, difficulty: String = "easy") -> Dictionary:
	var sim = Sim.new()
	sim.setup(Content.get_level(level_id), LOADOUT.duplicate(), difficulty)
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	var won = [false]
	var lost = [false]
	sim.on_win = func(): won[0] = true
	sim.on_lose = func(_z): lost[0] = true
	var dt = 1.0 / 60.0
	var steps = 0
	var strategy_timer = 0.0
	var max_shots = 0
	var bad = ""
	while steps < int(900.0 / dt) and not won[0] and not lost[0]:
		sim.tick(dt)
		sim.sounds.clear()
		sim.sound_detail.clear()
		steps += 1
		strategy_timer += dt
		if strategy_timer >= 0.5:
			strategy_timer = 0.0
			strategy(sim, rng)
		max_shots = maxi(max_shots, sim.shots.size())
		if not is_finite(sim.sun) or sim.sun < -10000:
			bad = "香火异常 %s" % str(sim.sun)
			break
		for z in sim.zombies:
			if not is_finite(z.hp):
				bad = "恶客血量 NaN"
				break
		if bad != "":
			break
	return {"sim": sim, "won": won[0], "lost": lost[0], "max_shots": max_shots,
		"bad": bad}


## 按「列」推进：先给每一行铺灯，再补输出，最后才上肉盾与水面浮台，
## 并且始终留一点香火应急，避免把香火全砸在便宜货上。
static func strategy(sim: Sim, rng: RandomNumberGenerator) -> void:
	var plan = [
		[0, "lantern"], [1, "lantern"], [2, "shooter"], [3, "shooter"],
		[4, "wall"], [5, "censer"], [6, "umbrella"],
	]
	for item in plan:
		var col = int(item[0])
		var type = String(item[1])
		for row in sim.rows:
			var tile = sim.tile_at(col, row)
			if String(tile["kind"]) == "water":
				if sim.lily_at(col, row) == null:
					var lily_index = _card_index(sim, "lily")
					if lily_index >= 0 and sim.sun >= 150 \
							and float(sim.cards[lily_index]["cd"]) <= 0.0:
						sim.try_place_card(lily_index, col, row, Vector2.ZERO)
					continue
			var index = _card_index(sim, type)
			if index < 0:
				continue
			if sim.main_plant_at(col, row) != null:
				continue
			var cost = int(Content.PLANTS[type]["cost"])
			if sim.sun < cost + 40:
				continue
			if float(sim.cards[index]["cd"]) > 0.0:
				continue
			var check = sim.can_place_at(type, col, row)
			if not bool(check["ok"]):
				continue
			sim.try_place_card(index, col, row, Vector2.ZERO)
	# 有余钱就把中间几株签筒升上去
	for row in sim.rows:
		var primary = sim.main_plant_at(2, row)
		if primary != null and primary.tier(1) < 3 and sim.sun > 360:
			sim.try_upgrade(primary, 1, Vector2.ZERO)
		var second = sim.main_plant_at(3, row)
		if second != null and second.tier(1) < 2 and sim.sun > 560:
			sim.try_upgrade(second, 1, Vector2.ZERO)


static func _card_index(sim: Sim, type: String) -> int:
	for i in sim.cards.size():
		if String(sim.cards[i]["id"]) == type:
			return i
	return -1
