## 对局模拟：与绘制、界面完全解耦的纯逻辑层。
##
## 数值与规则移植自 v0.2.4 的 www/src/game/game.js（18 草木 / 12 恶客 / 三天地图 /
## 十二波 / 三路升阶 / 训练场 / 教学关）。渲染与 UI 只读这里的状态，测试也可以在
## 无窗口模式下直接跑这一层。
##
## 必须守住的设计不变量：
##  1. 状态（减速/易伤/灼烧/恶客加速）一律「更强才覆盖、同强才续时、弱效果不延长也不回退」。
##  2. 护具先于本体：攻击先扣 armor，破具后才伤 hp。
##  3. 每座最多开两路，每路逐级，只有一路能到三级（见 Upgrades.path_status）。
##  4. 尸体在死亡动画期间仍然挡射弹，但不啃食。
##  5. 训练场不刷波次、不判负、不写存档；教学关不写存档。
class_name Sim
extends RefCounted


class Plant:
	var type = ""
	var def: Dictionary = {}
	var row = 0
	var col = 0
	var pos = Vector2.ZERO
	var hp = 0.0
	var max_hp = 0.0
	var timer = 0.0
	var phase = 0.0
	var recoil = 0.0
	var pulse = 0.0
	var charge = 0.0
	var bite_t = 0.0
	var dead = false
	var buff_damage = 0.0
	var haste = 0.0
	var upgrades: Dictionary = {}
	var shell = 0.0
	var shell_max = 0.0
	var shell_pulse = 0.0
	var is_lily = false
	var on_lily = false
	var chew_t = 0.0
	var chew_max = 0.0
	var arm_t = 0.0
	var armed = false
	var pull_t = 0.0
	var burst: Dictionary = {}
	var adj_flip = 0
	var tutorial_idle = false
	var death_t = -1.0
	var heal_t = 0.0

	func tier(path_id: int) -> int:
		return int(upgrades.get(path_id, 0))


class Zombie:
	var type = ""
	var def: Dictionary = {}
	var row = 0
	var pos = Vector2.ZERO
	var hp = 0.0
	var max_hp = 0.0
	var armor = 0.0
	var max_armor = 0.0
	var armor_type = ""
	var armor_name = ""
	var speed = 0.0
	var slow_t = 0.0
	var slow_amount = 0.0
	var vuln_t = 0.0
	var vuln = 0.0
	var burn_t = 0.0
	var burn_dps = 0.0
	var rage_t = 0.0
	var rage_mult = 1.0
	var stun_t = 0.0
	var eating = false
	var chomp = 0.0
	var eat_bite = 0.0
	var eat_snd_t = 0.0
	var anim = 0.0
	var phase = 0.0
	var hurt = 0.0
	var armor_pulse = 0.0
	var aura_t = 0.0
	var aura_pulse = 0.0
	var support_t = 0.0
	var support_pulse = 0.0
	var wail_t = 0.0
	var dying = false
	var dead = false
	var death_t = 0.0
	var death_dur = 0.5
	var breached = false
	var vaulted = false
	var vault_t = 0.0
	var vault_from = 0.0
	var vault_to = 0.0
	var vault_arc = 0.0
	var last_object = ""
	var object_hop = 0.0
	var split_done = false

	func alive() -> bool:
		return not dead and not dying

	func is_large() -> bool:
		return bool(def.get("large", false))


class Shot:
	var kind = "pea"       # pea / homing / lob / star
	var pos = Vector2.ZERO
	var row = 0
	var speed = 0.0
	var damage = 0.0
	var base_damage = 0.0
	var lantern_buff = 0.0
	var torch_buff = 0.0
	var dead = false
	var big = false
	var pierce_armor = false
	var vuln = 0.0
	var vuln_duration = 2.0
	var burn = 0.0
	var burn_duration = 2.0
	var slow = 0.0
	var slow_duration = 1.5
	var knock = 0.0
	var fire = false
	var fire_t = 0.0
	# homing
	var target: Zombie = null
	var hit_ids: Array = []
	var hits_left = 1
	# lob
	var start = Vector2.ZERO
	var tx = 0.0
	var ty = 0.0
	var t = 0.0
	var flight = 0.9
	# star
	var dir = Vector2.ZERO
	var life = 5.0


const DIFFICULTY = {
	"easy": {"count": 1.0, "hp": 1.0},
	"normal": {"count": 1.25, "hp": 1.25},
	"hard": {"count": 1.5, "hp": 1.5},
}

const MAX_LOADOUT = 10

var level: Dictionary = {}
var level_id = 1
var rows = 5
var tiles: Array = []                 # rows × COLS，元素 {kind, obj, water}
var cells: Array = []                 # rows × COLS，主植物或 null
var lilies: Dictionary = {}           # "r:c" -> Plant
var plants: Array = []
var zombies: Array = []
var shots: Array = []
var orbs: Array = []
var particles: Array = []
var floaters: Array = []
var mowers: Array = []
var cards: Array = []                 # [{id, def, cd}]
var sun = 100
var time = 0.0
var wave_index = 0
var spawn_queue: Array = []
var pending_spawns: Array = []
var kills = 0
var plants_lost = 0
var natural_timer = 3.0
var shake = 0.0
var result: Dictionary = {}

var difficulty = "easy"
var count_mul = 1.0
var hp_mul = 1.0
var training = false
var tutorial: Variant = null
var no_cooldown = false
var auto_collect = true
var collect_delay = 0.0

var sounds: Array = []                # 本帧要播的音效名（含可选的品种）
var sound_detail: Array = []
var banner: Dictionary = {}
var rng = RandomNumberGenerator.new()

# 回调用：由 game.gd 接管胜负与存档
var on_win = Callable()
var on_lose = Callable()
var on_banner = Callable()


func setup(p_level: Dictionary, loadout: Array, p_difficulty: String = "easy") -> void:
	level = p_level
	level_id = int(p_level.get("id", 1))
	rows = clampi(int(p_level.get("rows", 5)), 5, 6)
	difficulty = p_difficulty if DIFFICULTY.has(p_difficulty) else "easy"
	var scale = sqrt(maxf(0.1, float(p_level.get("threat", 1.0))))
	count_mul = scale
	hp_mul = scale
	training = false
	tutorial = null
	no_cooldown = false
	rng.seed = hash("%d:%s" % [level_id, difficulty])
	_reset(loadout)


func _reset(loadout: Array) -> void:
	tiles = _make_tiles()
	lilies.clear()
	cells = []
	for r in rows:
		var line: Array = []
		line.resize(Geo.COLS)
		line.fill(null)
		cells.append(line)
	plants.clear()
	zombies.clear()
	shots.clear()
	orbs.clear()
	particles.clear()
	floaters.clear()
	spawn_queue.clear()
	pending_spawns.clear()
	mowers = []
	for r in rows:
		mowers.append({"row": r, "ready": true, "active": false, "x": Geo.MOWER_X})
	cards = []
	for id in loadout:
		if Content.PLANTS.has(id):
			cards.append({"id": id, "def": Content.PLANTS[id], "cd": 0.0})
	sun = int(level.get("start_sun", 100))
	time = 0.0
	wave_index = 0
	kills = 0
	plants_lost = 0
	natural_timer = 3.0
	shake = 0.0
	result = {}
	banner = {}


func _make_tiles() -> Array:
	var grid: Array = []
	for r in rows:
		var line: Array = []
		for c in Geo.COLS:
			line.append({"kind": "land", "obj": 0, "water": ""})
		grid.append(line)
	var map = String(level.get("map", "street"))
	if map == "water":
		for r in level.get("water_rows", []):
			if r < 0 or r >= rows:
				continue
			for c in Geo.COLS:
				grid[r][c] = {"kind": "water", "obj": -1,
					"water": "river" if r == 1 else "ditch"}
		for pair in level.get("object_cells", []):
			var r: int = pair[0]
			var c: int = pair[1]
			if r >= 0 and r < rows and c >= 0 and c < Geo.COLS:
				grid[r][c] = {"kind": "object", "obj": (r + c) % 3,
					"water": "river" if r == 1 else "ditch"}
	elif map == "market":
		# 靠右四列随机 5 个障碍格；种子由关卡 id 固定，存档读回后位置不变。
		var local = RandomNumberGenerator.new()
		local.seed = hash("market-blocks:%d" % level_id)
		var pool: Array = []
		for c in range(Geo.COLS - 4, Geo.COLS):
			for r in rows:
				pool.append(Vector2i(c, r))
		for i in range(pool.size() - 1, 0, -1):
			var j = local.randi_range(0, i)
			var tmp = pool[i]
			pool[i] = pool[j]
			pool[j] = tmp
		for i in mini(5, pool.size()):
			var p: Vector2i = pool[i]
			grid[p.y][p.x] = {"kind": "blocked", "obj": i % 3, "water": ""}
	return grid


# ── 坐标与小工具 ────────────────────────────────────────────────────────────
func row_y(row: int) -> float:
	return Geo.row_y(row, rows)


func cell_pos(col: int, row: int) -> Vector2:
	return Geo.cell_center(col, row, rows)


func tile_at(col: int, row: int) -> Dictionary:
	if row < 0 or row >= rows or col < 0 or col >= Geo.COLS:
		return {"kind": "land", "obj": 0, "water": ""}
	return tiles[row][col]


func main_plant_at(col: int, row: int) -> Plant:
	if row < 0 or row >= rows or col < 0 or col >= Geo.COLS:
		return null
	return cells[row][col]


func lily_at(col: int, row: int) -> Plant:
	return lilies.get("%d:%d" % [row, col], null)


func unit_scale() -> float:
	return Geo.unit_scale(rows)


func difficulty_mult() -> Dictionary:
	return DIFFICULTY.get(difficulty, DIFFICULTY["easy"])


# ── 音效与特效队列 ──────────────────────────────────────────────────────────
func sfx(name: String, detail: Dictionary = {}) -> void:
	sounds.append(name)
	sound_detail.append(detail)


func spark(pos: Vector2, color: Color, count: int, power: float = 1.0) -> void:
	for i in count:
		var a = rng.randf() * TAU
		var sp = (40.0 + rng.randf() * 90.0) * power
		particles.append({
			"x": pos.x, "y": pos.y,
			"vx": cos(a) * sp, "vy": sin(a) * sp - 30.0 * power,
			"life": 0.3 + rng.randf() * 0.25, "max": 0.55,
			"size": 1.6 + rng.randf() * 2.2, "color": color, "kind": "circle",
		})


func ring(pos: Vector2, color: Color, radius: float, life: float = 0.5) -> void:
	particles.append({
		"x": pos.x, "y": pos.y, "vx": 0.0, "vy": 0.0,
		"life": life, "max": life, "size": radius, "color": color, "kind": "ring",
	})


func float_text(pos: Vector2, text: String, color: Color = Color(1, 0.88, 0.63),
		size: int = 18, life: float = 1.2) -> void:
	floaters.append({
		"x": pos.x, "y": pos.y, "text": text, "color": color,
		"life": life, "max": life, "size": size,
	})


func deny(text: String, at: Vector2) -> void:
	float_text(at, text, Color("#ff9d7a"), 17, 1.15)
	sfx("deny")


# ── 种植 ────────────────────────────────────────────────────────────────────
func can_place_at(type: String, col: int, row: int) -> Dictionary:
	if col < 0 or col >= Geo.COLS or row < 0 or row >= rows:
		return {"ok": false, "reason": "这里不能种"}
	var def: Dictionary = Content.PLANTS.get(type, {})
	if def.is_empty() or bool(def.get("attach", false)):
		return {"ok": false, "reason": "这里不能种"}
	var tile = tile_at(col, row)
	var main = main_plant_at(col, row)
	var lily = lily_at(col, row)
	if tile["kind"] == "blocked":
		return {"ok": false, "reason": "障碍挡住了，不能种"}
	if tile["kind"] == "object":
		return {"ok": false, "reason": "这里有物件，不能种"}
	if bool(def.get("lily", false)):
		if tile["kind"] != "water":
			return {"ok": false, "reason": "夜莲只能放在水面"}
		if main != null or lily != null:
			return {"ok": false, "reason": "这里已经摆了东西"}
		return {"ok": true, "reason": ""}
	if bool(def.get("water_only", false)):
		if tile["kind"] != "water":
			return {"ok": false, "reason": "缠魂藻只能种在水面"}
		if main != null or lily != null:
			return {"ok": false, "reason": "这里已经摆了东西"}
		return {"ok": true, "reason": ""}
	if tile["kind"] == "water":
		if lily == null:
			return {"ok": false, "reason": "水面要先放夜莲"}
		if main != null:
			return {"ok": false, "reason": "这里已经摆了东西"}
		return {"ok": true, "reason": ""}
	if main != null:
		return {"ok": false, "reason": "这里已经摆了东西"}
	return {"ok": true, "reason": ""}


func place_free(type: String, col: int, row: int) -> Plant:
	var check = can_place_at(type, col, row)
	if not bool(check["ok"]):
		return null
	var def: Dictionary = Content.PLANTS[type]
	var plant = Plant.new()
	plant.type = type
	plant.def = def
	plant.row = row
	plant.col = col
	plant.pos = cell_pos(col, row)
	plant.hp = float(def.get("hp", 300))
	plant.max_hp = plant.hp
	plant.phase = rng.randf() * TAU
	plant.upgrades = Upgrades.init_upgrades()
	if def.has("produce"):
		plant.timer = float(def["produce"]["interval"]) - float(def["produce"]["first"])
	elif def.has("shot"):
		plant.timer = float(def["shot"]["interval"])
	if bool(def.get("lily", false)):
		plant.is_lily = true
		lilies["%d:%d" % [row, col]] = plant
	else:
		cells[row][col] = plant
		if lily_at(col, row) != null:
			plant.on_lily = true
	plants.append(plant)
	refresh_plant_buffs()
	return plant


func try_place_card(index: int, col: int, row: int, at: Vector2) -> bool:
	if index < 0 or index >= cards.size():
		return false
	var card: Dictionary = cards[index]
	var def: Dictionary = card["def"]
	if float(card["cd"]) > 0.0 and not no_cooldown:
		deny("还没缓过手来", at)
		return false
	if sun < int(def["cost"]):
		deny("香火不够", at)
		return false
	if bool(def.get("attach", false)):
		var host = main_plant_at(col, row)
		if host == null:
			deny("先种一株草木，再罩龟甲", at)
			return false
		if host.shell > 0.0:
			deny("这里已经罩了龟甲", at)
			return false
		sun -= int(def["cost"])
		card["cd"] = 0.0 if no_cooldown else float(def["cooldown"])
		attach_shell(host)
		sfx("place")
		return true
	var check = can_place_at(card["id"], col, row)
	if not bool(check["ok"]):
		deny(String(check["reason"]), at)
		return false
	sun -= int(def["cost"])
	card["cd"] = 0.0 if no_cooldown else float(def["cooldown"])
	var plant = place_free(card["id"], col, row)
	if plant == null:
		return false
	ring(plant.pos + Vector2(0, 8), Color(1, 0.78, 0.42, 0.55), 46.0, 0.4)
	spark(plant.pos, Color(0.93, 0.76, 0.4), 9)
	sfx("place")
	if tutorial != null and String(tutorial["step"]) == "plant" and card["id"] == "shooter":
		tutorial["shooter"] = plant
		tutorial["step"] = "upgrade"
	return true


func attach_shell(host: Plant) -> void:
	var hp = float(Upgrades.EFFECTS["shell"]["hp"])
	host.shell = hp
	host.shell_max = hp
	host.shell_pulse = 0.6
	float_text(host.pos + Vector2(0, -60), "龟甲罩上了", Color("#cfe0b0"), 16)
	spark(host.pos + Vector2(0, -20), Color("#c8d6a4"), 10)


func remove_shell(host: Plant) -> void:
	if host == null or host.shell <= 0.0:
		return
	host.shell = 0.0
	float_text(host.pos + Vector2(0, -52), "拆下龟甲罩", Color("#dce7c4"), 15)
	spark(host.pos + Vector2(0, -16), Color("#bfd0a0"), 8)
	sfx("shell")


func damage_plant(plant: Plant, amount: float) -> void:
	if plant == null or plant.dead or amount <= 0.0:
		return
	if plant.shell > 0.0:
		plant.shell -= amount
		plant.shell_pulse = 0.25
		if plant.shell <= 0.0:
			plant.shell = 0.0
			sfx("shell")
			float_text(plant.pos + Vector2(0, -54), "龟甲碎了", Color("#e8d6a8"), 15)
			for i in 10:
				particles.append({
					"x": plant.pos.x + rng.randf_range(-15, 15),
					"y": plant.pos.y - 8.0 - rng.randf() * 26.0,
					"vx": rng.randf_range(-65, 65), "vy": -40.0 - rng.randf() * 100.0,
					"life": 0.5 + rng.randf() * 0.4, "max": 0.9,
					"size": 3.0 + rng.randf() * 4.0,
					"color": Color("#d8cfae") if i % 2 else Color("#9e9a78"),
					"kind": "shard",
				})
		return
	plant.hp -= amount
	plant.bite_t = maxf(plant.bite_t, 0.2)
	if plant.hp <= 0.0:
		kill_plant(plant)


func kill_plant(plant: Plant, silent: bool = false) -> void:
	if plant == null or plant.dead:
		return
	plant.dead = true
	plant.shell = 0.0
	if plant.is_lily:
		lilies.erase("%d:%d" % [plant.row, plant.col])
	else:
		if cells[plant.row][plant.col] == plant:
			cells[plant.row][plant.col] = null
		if not silent:
			plants_lost += 1
	if not silent:
		sfx("plant_down")
	for i in 8:
		particles.append({
			"x": plant.pos.x + rng.randf_range(-12, 12), "y": plant.pos.y - 8.0,
			"vx": rng.randf_range(-60, 60), "vy": -40.0 - rng.randf() * 100.0,
			"life": 0.5, "max": 0.5, "size": 3.0 + rng.randf() * 3.0,
			"color": Color("#c9a15c"), "kind": "shard",
		})
	refresh_plant_buffs()


func shovel_at(col: int, row: int) -> Dictionary:
	"""返回被铲掉的东西：{ok, text, shell}。龟甲罩与浮台可单独拆。"""
	var main = main_plant_at(col, row)
	var lily = lily_at(col, row)
	if main != null and main.shell > 0.0:
		remove_shell(main)
		return {"ok": true, "text": "拆下龟甲罩"}
	if main != null:
		kill_plant(main, true)
		return {"ok": true, "text": "已铲除"}
	if lily != null:
		if main_plant_at(col, row) != null:
			return {"ok": false, "text": "先移除上面的草木"}
		kill_plant(lily, true)
		return {"ok": true, "text": "已拆下夜莲"}
	return {"ok": false, "text": "这里没有东西"}


# ── 升阶 ────────────────────────────────────────────────────────────────────
func try_upgrade(plant: Plant, path_id: int, at: Vector2) -> Dictionary:
	if plant == null or plant.dead:
		return {"ok": false, "reason": "草木已经不在了"}
	var status = Upgrades.path_status(plant.type, plant.upgrades, path_id)
	if not bool(status["ok"]):
		var reason = String(status["reason"])
		deny(reason, at)
		return {"ok": false, "reason": reason}
	var cost = int(status["cost"])
	if sun < cost:
		deny("香火不够", at)
		return {"ok": false, "reason": "香火不够"}
	sun -= cost
	plant.upgrades[path_id] = int(status["next_tier"])
	float_text(plant.pos + Vector2(0, -66), "%d-%d %s" % [
		path_id, int(status["next_tier"]), String(status["name"])],
		Color("#ffe1a1"), 18, 1.4)
	spark(plant.pos + Vector2(0, -18), Color(String(status["path"]["color"])), 12)
	shake = maxf(shake, 3.0)
	plant.pulse = 0.5
	refresh_plant_buffs()
	sfx("upgrade")
	if tutorial != null and String(tutorial["step"]) == "upgrade" \
			and tutorial["shooter"] == plant:
		tutorial["step"] = "battle"
		tutorial["battle_t"] = 1.0
	return {"ok": true, "tier": int(status["next_tier"]), "cost": cost}


func refresh_plant_buffs() -> void:
	for plant in plants:
		if plant.dead:
			continue
		plant.buff_damage = 0.0
		plant.haste = 0.0
	var lantern_fx: Dictionary = Upgrades.EFFECTS["lantern"]
	var bell_fx: Dictionary = Upgrades.EFFECTS["bell"]
	for source in plants:
		if source.dead:
			continue
		if source.type == "lantern":
			var tier = source.tier(3)
			if tier <= 0:
				continue
			var reach: int = lantern_fx["buff_range"][tier]
			var value: float = lantern_fx["buff_damage"][tier]
			for target in plants:
				if target.dead or target == source or target.row != source.row:
					continue
				if tier < 3 and (target.col <= source.col or target.col - source.col > reach):
					continue
				target.buff_damage = maxf(target.buff_damage, value)
		elif source.type == "bell":
			var tier = source.tier(2)
			if tier <= 0:
				continue
			var reach: int = bell_fx["haste_range"][tier]
			var slow_pct: float = float(bell_fx["slow"][source.tier(1)])
			var value: float = slow_pct * float(bell_fx["haste_factor"][tier])
			for target in plants:
				if target.dead or target == source or target.row != source.row:
					continue
				if tier < 3 and (target.col <= source.col or target.col - source.col > reach):
					continue
				target.haste = maxf(target.haste, value)


# ── 经济与波次 ──────────────────────────────────────────────────────────────
func update_economy(dt: float) -> void:
	if tutorial != null:
		return
	natural_timer -= dt
	if natural_timer <= 0.0:
		natural_timer = 8.0 + rng.randf() * 2.0
		orbs.append({
			"x": Geo.BOARD_X + 50.0 + rng.randf() * (Geo.BOARD_W - 100.0),
			"y": -24.0,
			"target_y": Geo.BOARD_Y + 70.0 + rng.randf() * (Geo.BOARD_H - 120.0),
			"landed": false, "life": 10.0, "value": 25,
			"phase": rng.randf() * TAU, "dead": false, "auto_t": 0.0,
		})


func update_waves() -> void:
	if training:
		return
	var waves: Array = level.get("waves", [])
	while wave_index < waves.size() and time >= float(waves[wave_index]["t"]):
		var wave: Dictionary = waves[wave_index]
		wave_index += 1
		queue_wave(wave)
	var keep: Array = []
	for entry in spawn_queue:
		if time >= float(entry["t"]):
			spawn_zombie(String(entry["type"]), int(entry["row"]))
		else:
			keep.append(entry)
	spawn_queue = keep


func queue_wave(wave: Dictionary) -> void:
	sfx("alert" if bool(wave["flag"]) else "wave")
	var count_mult: float = count_mul * float(difficulty_mult()["count"])
	var k = 0
	for group in wave["groups"]:
		var n = maxi(1, int(round(float(group[1]) * count_mult)))
		for i in n:
			spawn_queue.append({
				"t": time + k * 0.38 + rng.randf() * 0.25,
				"type": group[0],
				"row": rng.randi_range(0, rows - 1),
			})
			k += 1
	if bool(wave["flag"]):
		banner = {"text": "一大波恶客正在靠近", "t": 3.4, "max": 3.4}
		shake = maxf(shake, 5.0)
		if on_banner.is_valid():
			on_banner.call(banner["text"])


func summon_next_wave() -> bool:
	if training:
		return false
	var waves: Array = level.get("waves", [])
	if wave_index >= waves.size():
		return false
	var wave: Dictionary = waves[wave_index]
	wave_index += 1
	queue_wave(wave)
	shake = maxf(shake, 4.0)
	return true


func spawn_zombie(type: String, row: int, opts: Dictionary = {}) -> Zombie:
	var def: Dictionary = Content.ZOMBIES.get(type, {})
	if def.is_empty():
		return null
	var hp_mult = hp_mul * float(difficulty_mult()["hp"])
	var hp_factor = float(opts.get("hp_factor", 1.0))
	var z = Zombie.new()
	z.type = type
	z.def = def
	z.row = clampi(row, 0, rows - 1)
	z.pos = Vector2(float(opts.get("x", Geo.SPAWN_X + rng.randf() * 70.0)),
		row_y(z.row) + 4.0)
	z.hp = maxf(1.0, round(float(def["hp"]) * hp_mult * hp_factor))
	z.max_hp = z.hp
	z.armor = maxf(0.0, round(float(def.get("armor", 0.0)) * hp_mult))
	z.max_armor = z.armor
	z.armor_type = String(def.get("armor_type", ""))
	z.armor_name = String(def.get("armor_name", ""))
	z.speed = float(def["speed"])
	z.death_dur = 1.0 if bool(def.get("large", false)) else 0.5
	z.anim = rng.randf() * TAU
	z.phase = rng.randf() * TAU
	z.aura_t = 0.8 + rng.randf() * float(def["aura"]["interval"]) if def.has("aura") else 0.0
	z.support_t = 1.5 + rng.randf() * float(def["support"]["interval"]) \
		if def.has("support") else 0.0
	zombies.append(z)
	return z


func flush_pending_spawns() -> void:
	if pending_spawns.is_empty():
		return
	var list = pending_spawns
	pending_spawns = []
	for entry in list:
		spawn_zombie(String(entry["type"]), int(entry["row"]),
			{"x": float(entry["x"]), "hp_factor": float(entry["hp_factor"])})


# ── 状态（不叠加）────────────────────────────────────────────────────────────
func apply_slow(z: Zombie, duration: float, amount: float = 0.5) -> void:
	if z == null or not z.alive() or duration <= 0.0:
		return
	var slow = clampf(amount, 0.0, 0.9)
	var current = z.slow_amount if z.slow_t > 0.0 else 0.0
	if slow > current + 0.0001:
		z.slow_amount = slow
		z.slow_t = duration
	elif absf(slow - current) <= 0.0001:
		z.slow_t = maxf(z.slow_t, duration)


func apply_vulnerable(z: Zombie, duration: float, amount: float) -> void:
	if z == null or not z.alive() or duration <= 0.0 or amount <= 0.0:
		return
	var current = z.vuln if z.vuln_t > 0.0 else 0.0
	if amount > current + 0.0001:
		z.vuln = amount
		z.vuln_t = duration
	elif absf(amount - current) <= 0.0001:
		z.vuln_t = maxf(z.vuln_t, duration)


func apply_burn(z: Zombie, duration: float, dps: float) -> void:
	if z == null or not z.alive() or duration <= 0.0 or dps <= 0.0:
		return
	var current = z.burn_dps if z.burn_t > 0.0 else 0.0
	if dps > current + 0.0001:
		z.burn_dps = dps
		z.burn_t = duration
	elif absf(dps - current) <= 0.0001:
		z.burn_t = maxf(z.burn_t, duration)


func apply_stun(z: Zombie, duration: float) -> void:
	if z == null or not z.alive() or duration <= 0.0:
		return
	z.stun_t = maxf(z.stun_t, duration)
	z.eating = false
	for i in 4:
		particles.append({
			"x": z.pos.x + rng.randf_range(-11, 11),
			"y": z.pos.y - 54.0 + rng.randf_range(-6, 6),
			"vx": rng.randf_range(-25, 25), "vy": -20.0 - rng.randf() * 40.0,
			"life": 0.5, "max": 0.5, "size": 2.0 + rng.randf() * 2.0,
			"color": Color("#ffe09a"), "kind": "circle",
		})


func apply_shot_statuses(z: Zombie, shot: Shot) -> void:
	if shot.vuln > 0.0:
		apply_vulnerable(z, shot.vuln_duration, shot.vuln)
	if shot.burn > 0.0:
		apply_burn(z, shot.burn_duration, shot.burn)
	if shot.slow > 0.0:
		apply_slow(z, shot.slow_duration, shot.slow)


# ── 主循环 ──────────────────────────────────────────────────────────────────
func tick(dt: float) -> void:
	for card in cards:
		if no_cooldown:
			card["cd"] = 0.0
		else:
			card["cd"] = maxf(0.0, float(card["cd"]) - dt)
	if not banner.is_empty():
		banner["t"] = float(banner["t"]) - dt
		if float(banner["t"]) <= 0.0:
			banner = {}
	if shake > 0.0:
		shake = maxf(0.0, shake - dt * 34.0)
	time += dt
	update_economy(dt)
	update_waves()
	update_plants(dt)
	update_zombies(dt)
	update_shots(dt)
	update_mowers(dt)
	update_orbs(dt)
	update_particles(dt)
	flush_pending_spawns()
	_cleanup()
	if tutorial != null:
		update_tutorial(dt)
	elif is_cleared() and on_win.is_valid():
		on_win.call()


func _cleanup() -> void:
	var keep_plants: Array = []
	for p in plants:
		if not p.dead:
			keep_plants.append(p)
	plants = keep_plants
	var keep_zombies: Array = []
	for z in zombies:
		if not z.dead:
			keep_zombies.append(z)
	zombies = keep_zombies
	var keep_shots: Array = []
	for s in shots:
		if not s.dead:
			keep_shots.append(s)
	shots = keep_shots
	var keep_orbs: Array = []
	for o in orbs:
		if not bool(o["dead"]):
			keep_orbs.append(o)
	orbs = keep_orbs
	var keep_particles: Array = []
	for p in particles:
		if float(p["life"]) > 0.0:
			keep_particles.append(p)
	particles = keep_particles
	var keep_floaters: Array = []
	for f in floaters:
		if float(f["life"]) > 0.0:
			keep_floaters.append(f)
	floaters = keep_floaters


func active_zombies() -> int:
	var count = 0
	for z in zombies:
		if z.alive():
			count += 1
	return count


func is_cleared() -> bool:
	if training or tutorial != null:
		return false
	var waves: Array = level.get("waves", [])
	return wave_index >= waves.size() and spawn_queue.is_empty() and zombies.is_empty()


# ── 草木行为 ────────────────────────────────────────────────────────────────
func update_plants(dt: float) -> void:
	refresh_plant_buffs()
	for plant in plants:
		if plant.dead:
			continue
		plant.recoil = maxf(0.0, plant.recoil - dt * 3.0)
		plant.pulse = maxf(0.0, plant.pulse - dt)
		plant.bite_t = maxf(0.0, plant.bite_t - dt)
		plant.charge = 0.0
		plant.heal_t += dt
		if plant.shell_pulse > 0.0:
			plant.shell_pulse = maxf(0.0, plant.shell_pulse - dt)
		var def = plant.def
		if def.has("produce"):
			_update_producer(plant, dt)
		elif def.has("shot"):
			_update_shooter(plant, dt)
		elif def.has("pulse"):
			_update_bell(plant, dt)
		elif def.has("censer"):
			_update_censer(plant, dt)
		elif def.has("chomp"):
			_update_umbrella(plant, dt)
		elif def.has("melee"):
			_update_lion(plant, dt)
		elif def.has("mine"):
			_update_mine(plant, dt)
		elif def.has("tangle"):
			_update_kelp(plant, dt)
		elif def.has("homing"):
			_update_cat(plant, dt)
		elif def.has("lob"):
			_update_lobber(plant, dt)
		elif def.has("star"):
			_update_star(plant, dt)
		elif def.has("needle"):
			_update_needle(plant, dt)
		elif def.has("judge"):
			_update_judge(plant, dt)
		elif def.has("torch"):
			plant.pulse = 0.18 + sin((time + plant.phase) * 3.2) * 0.08
		elif plant.type == "wall":
			_update_wall(plant, dt)
		elif def.has("bomb"):
			plant.timer += dt
			if plant.timer >= float(def["bomb"]["fuse"]):
				explode(plant)


func lantern_value(plant: Plant) -> int:
	return int(Upgrades.EFFECTS["lantern"]["value"][plant.tier(1)])


func lantern_interval(plant: Plant) -> float:
	return float(Upgrades.EFFECTS["lantern"]["interval"][plant.tier(2)])


func _update_producer(plant: Plant, dt: float) -> void:
	if plant.tutorial_idle:
		return
	var interval = lantern_interval(plant)
	plant.timer += dt
	if plant.timer >= interval:
		plant.timer -= interval
		plant.pulse = 0.45
		sfx("produce")
		orbs.append({
			"x": plant.pos.x + rng.randf_range(-22, 22),
			"y": plant.pos.y - 30.0,
			"target_y": plant.pos.y - 30.0,
			"landed": true, "life": 9.0, "value": lantern_value(plant),
			"phase": rng.randf() * TAU, "dead": false, "auto_t": 0.0,
		})


func lane_target(plant: Plant) -> Zombie:
	for z in zombies:
		if z.alive() and z.row == plant.row and z.pos.x > plant.pos.x + 6.0:
			return z
	return null


func _update_shooter(plant: Plant, dt: float) -> void:
	if not plant.burst.is_empty():
		plant.burst["timer"] = float(plant.burst["timer"]) - dt
		if int(plant.burst["left"]) > 0 and float(plant.burst["timer"]) <= 0.0:
			fire_volley_shot(plant)
		if plant.burst.is_empty() or int(plant.burst.get("left", 0)) <= 0:
			plant.burst = {}
			plant.timer = 0.0
		return
	plant.timer += dt
	var target = lane_target(plant)
	var interval = float(plant.def["shot"]["interval"]) / (1.0 + plant.haste)
	if target != null:
		if plant.timer >= interval:
			plant.timer = 0.0
			start_volley(plant)
		else:
			plant.charge = minf(1.0, plant.timer / interval)
	else:
		plant.timer = minf(plant.timer, interval)


func start_volley(plant: Plant) -> void:
	var adjacent = plant.tier(2)
	var lanes: Array = []
	if adjacent > 0:
		if plant.row > 0:
			lanes.append(plant.row - 1)
		if plant.row < rows - 1:
			lanes.append(plant.row + 1)
		if adjacent == 1 and lanes.size() > 1:
			plant.adj_flip += 1
			lanes = [lanes[plant.adj_flip % 2]]
	var fx: Dictionary = Upgrades.EFFECTS["shooter"]
	plant.burst = {
		"left": int(fx["volley"][plant.tier(1)]),
		"index": 0,
		"timer": 0.0,
		"adjacent": adjacent,
		"lanes": lanes,
		"crit_chance": float(fx["crit_chance"][plant.tier(3)]),
		"crit_slow": float(fx["crit_slow"][plant.tier(3)]),
	}
	fire_volley_shot(plant)
	if plant.burst.is_empty() or int(plant.burst.get("left", 0)) <= 0:
		plant.burst = {}
		plant.timer = 0.0


func fire_volley_shot(plant: Plant) -> void:
	if plant.burst.is_empty():
		return
	var index = int(plant.burst["index"])
	var raw = float(plant.def["shot"]["damage"])
	var big = index == 0 and rng.randf() < float(plant.burst["crit_chance"])
	sfx("shoot")
	var shot = Shot.new()
	shot.pos = plant.pos + Vector2(20.0, -12.0 + (-2.0 if index % 2 == 0 else 2.0))
	shot.row = plant.row
	shot.speed = float(plant.def["shot"]["speed"])
	_prepare_shot(shot, plant, raw * (2.0 if big else 1.0))
	shot.big = big
	if float(plant.burst["crit_slow"]) > 0.0:
		shot.slow = 0.5
		shot.slow_duration = float(plant.burst["crit_slow"])
	shots.append(shot)
	if index == 0 and not plant.burst["lanes"].is_empty():
		var factor = float(Upgrades.EFFECTS["shooter"]["adjacent_factor"][
			int(plant.burst["adjacent"])])
		for lane in plant.burst["lanes"]:
			var extra = Shot.new()
			extra.pos = Vector2(plant.pos.x + 20.0, row_y(int(lane)) - 12.0)
			extra.row = int(lane)
			extra.speed = float(plant.def["shot"]["speed"])
			_prepare_shot(extra, plant, raw * factor)
			shots.append(extra)
	plant.recoil = 1.0
	plant.charge = 0.0
	plant.burst["index"] = index + 1
	plant.burst["left"] = int(plant.burst["left"]) - 1
	plant.burst["timer"] = 0.09


func bell_slow(plant: Plant) -> float:
	return float(Upgrades.EFFECTS["bell"]["slow"][plant.tier(1)])


func _update_bell(plant: Plant, dt: float) -> void:
	var fx: Dictionary = Upgrades.EFFECTS["bell"]
	var interval = float(fx["interval"][plant.tier(1)]) / (1.0 + plant.haste)
	plant.timer += dt
	if plant.timer < interval:
		return
	var damage = float(fx["damage"][plant.tier(3)])
	var damage_range: int = fx["damage_range"][plant.tier(3)]
	var root_chance = float(fx["root_chance"][plant.tier(3)])
	var hit_any = false
	for z in zombies:
		if not z.alive() or z.row != plant.row or z.pos.x <= plant.pos.x - 8.0:
			continue
		apply_slow(z, float(fx["slow_duration"]), bell_slow(plant))
		if damage > 0.0 and (damage_range >= 99 or
				z.pos.x - plant.pos.x <= damage_range * Geo.CELL_W):
			damage_zombie(z, damage * (1.0 + plant.buff_damage))
			if root_chance > 0.0 and not z.is_large() and rng.randf() < root_chance:
				apply_stun(z, float(fx["root_duration"]))
		hit_any = true
	if hit_any:
		plant.timer = 0.0
		plant.pulse = 0.55
		sfx("bell")
		ring(plant.pos + Vector2(0, -6),
			Color(0.56, 0.82, 0.85, 0.55),
			74.0 if damage_range >= 99 else (48.0 if damage_range > 1 else 26.0), 0.5)
	else:
		plant.timer = minf(plant.timer, interval)


func censer_effect(plant: Plant) -> Dictionary:
	var fx: Dictionary = Upgrades.EFFECTS["censer"]
	return {
		"damage": float(fx["damage"][plant.tier(1)]),
		"radius": float(fx["radius"][plant.tier(2)]),
		"slow": float(fx["slow"][plant.tier(3)]),
		"slow_duration": float(fx["slow_duration"][plant.tier(3)]),
	}


func _update_censer(plant: Plant, dt: float) -> void:
	var interval = float(Upgrades.EFFECTS["censer"]["interval"]) / (1.0 + plant.haste)
	plant.timer += dt
	plant.charge = minf(1.0, plant.timer / interval)
	if plant.timer < interval:
		return
	plant.timer -= interval
	plant.charge = 0.0
	var fx = censer_effect(plant)
	plant.pulse = 0.7
	sfx("censer")
	var any = false
	for z in zombies:
		if not z.alive():
			continue
		if z.pos.distance_to(plant.pos) > float(fx["radius"]):
			continue
		damage_zombie(z, float(fx["damage"]) * (1.0 + plant.buff_damage))
		if float(fx["slow"]) > 0.0:
			apply_slow(z, float(fx["slow_duration"]), float(fx["slow"]))
		any = true
	ring(plant.pos + Vector2(0, -4), Color(0.84, 0.78, 0.64, 0.34),
		maxf(30.0, float(fx["radius"]) - 26.0), 0.6)
	for i in 7:
		var a = rng.randf() * TAU
		particles.append({
			"x": plant.pos.x + cos(a) * (14.0 + rng.randf() * 20.0),
			"y": plant.pos.y - 12.0 + sin(a) * 10.0,
			"vx": cos(a) * 16.0, "vy": -24.0 - rng.randf() * 22.0,
			"life": 0.6 + rng.randf() * 0.5, "max": 1.1,
			"size": 3.0 + rng.randf() * 4.0,
			"color": Color("#c9b28c") if any else Color("#b9aa90"), "kind": "circle",
		})
	if any:
		shake = maxf(shake, 2.0)


func plant_guard(target: Plant) -> float:
	if target.type == "umbrella" and target.chew_t > 0.0:
		return float(Upgrades.EFFECTS["umbrella"]["chew_guard"][target.tier(3)])
	return 0.0


func flytrap_target(plant: Plant) -> Zombie:
	var reach = float(plant.def["chomp"]["reach"])
	var best: Zombie = null
	for z in zombies:
		if not z.alive() or z.row != plant.row:
			continue
		if z.pos.x < plant.pos.x - 14.0 or z.pos.x - plant.pos.x > reach:
			continue
		if best == null or z.pos.x < best.pos.x:
			best = z
	return best


func _update_umbrella(plant: Plant, dt: float) -> void:
	if plant.chew_t > 0.0:
		plant.chew_t = maxf(0.0, plant.chew_t - dt)
		plant.charge = 1.0 - plant.chew_t / plant.chew_max if plant.chew_max > 0.0 else 0.0
		if plant.chew_t <= 0.0:
			var value = float(Upgrades.EFFECTS["umbrella"]["sun"][plant.tier(2)])
			if value > 0.0:
				orbs.append({
					"x": plant.pos.x + rng.randf_range(-13, 13),
					"y": plant.pos.y - 24.0, "target_y": plant.pos.y - 24.0,
					"landed": true, "life": 9.0, "value": int(value),
					"phase": rng.randf() * TAU, "dead": false, "auto_t": 0.0,
				})
			plant.pulse = 0.5
			plant.charge = 0.0
		return
	plant.timer += dt
	var target = flytrap_target(plant)
	if target == null:
		plant.timer = minf(plant.timer, 0.35)
		return
	var base = float(Upgrades.EFFECTS["umbrella"]["large_interval"]) \
		if target.is_large() else 0.35
	var interval = base / (1.0 + plant.haste)
	plant.charge = minf(1.0, plant.timer / interval)
	if plant.timer >= interval:
		plant.timer = 0.0
		plant.charge = 0.0
		flytrap_bite(plant, target)


func flytrap_bite(plant: Plant, target: Zombie) -> void:
	sfx("umbrella")
	plant.recoil = 1.0
	plant.pulse = 0.5
	if target.is_large():
		damage_zombie(target, float(plant.def["chomp"]["large_damage"])
			* (1.0 + plant.buff_damage))
		spark(plant.pos + Vector2(22, -22), Color("#7a8f55"), 5)
		return
	kill_zombie(target)
	var speed = float(Upgrades.EFFECTS["umbrella"]["chew_speed"][plant.tier(1)])
	plant.chew_max = float(plant.def["chomp"]["chew"]) * (1.0 - speed)
	plant.chew_t = plant.chew_max
	float_text(plant.pos + Vector2(0, -74), "收了", Color("#cfe0a0"), 16, 1.0)


func _update_mine(plant: Plant, dt: float) -> void:
	if not plant.armed:
		plant.arm_t += dt
		if plant.arm_t < float(plant.def["mine"]["arm"]):
			return
		plant.armed = true
		plant.pulse = 0.5
		spark(plant.pos + Vector2(0, 12), Color("#d8e8a5"), 10)
		for i in 9:
			var a = rng.randf() * TAU
			var sp = 30.0 + rng.randf() * 70.0
			particles.append({
				"x": plant.pos.x + rng.randf_range(-12, 12), "y": plant.pos.y + 20.0,
				"vx": cos(a) * sp, "vy": -30.0 - rng.randf() * 65.0,
				"life": 0.45 + rng.randf() * 0.35, "max": 0.8,
				"size": 2.2 + rng.randf() * 3.0,
				"color": Color("#c9d99a") if i % 3 == 0 else Color("#7d6a4a"),
				"kind": "shard",
			})
		return
	for z in zombies:
		if not z.alive() or z.row != plant.row:
			continue
		if z.pos.x >= plant.pos.x - 16.0 and z.pos.x - plant.pos.x <= 44.0:
			mine_explode(plant, z)
			return


func mine_explode(plant: Plant, target: Zombie) -> void:
	plant.dead = true
	cells[plant.row][plant.col] = null
	sfx("mine")
	damage_zombie(target, float(plant.def["mine"]["damage"]) * (1.0 + plant.buff_damage))
	for i in 22:
		var a = rng.randf() * TAU
		var sp = 70.0 + rng.randf() * 190.0
		particles.append({
			"x": plant.pos.x, "y": plant.pos.y,
			"vx": cos(a) * sp, "vy": sin(a) * sp - 45.0,
			"life": 0.4 + rng.randf() * 0.4, "max": 0.8,
			"size": 2.5 + rng.randf() * 4.0,
			"color": Color("#b58a52") if rng.randf() < 0.5 else Color("#e0c087"),
			"kind": "shard",
		})
	shake = maxf(shake, 9.0)


func _update_kelp(plant: Plant, dt: float) -> void:
	var reach = float(plant.def["tangle"]["range"])
	var target: Zombie = null
	for z in zombies:
		if not z.alive() or z.row != plant.row:
			continue
		if z.pos.x < plant.pos.x - 24.0 or z.pos.x > plant.pos.x + reach:
			continue
		if target == null or z.pos.x < target.pos.x:
			target = z
	if target == null:
		plant.pull_t = maxf(0.0, plant.pull_t - dt)
		return
	plant.pull_t += dt
	target.eating = false
	target.pos.x += (plant.pos.x + 8.0 - target.pos.x) * minf(1.0, dt * 4.0)
	if rng.randf() < dt * 24.0:
		particles.append({
			"x": target.pos.x + rng.randf_range(-12, 12),
			"y": target.pos.y - 20.0 + rng.randf() * 20.0,
			"vx": rng.randf_range(-20, 20), "vy": -18.0 - rng.randf() * 30.0,
			"life": 0.4 + rng.randf() * 0.3, "max": 0.7,
			"size": 2.0 + rng.randf() * 2.0,
			"color": Color("#7ea998") if rng.randf() < 0.5 else Color("#b7d4bd"),
			"kind": "circle",
		})
	if plant.pull_t < float(plant.def["tangle"]["drag"]):
		return
	damage_zombie(target, float(plant.def["tangle"]["damage"]))
	plant.dead = true
	cells[plant.row][plant.col] = null
	for i in 16:
		var a = rng.randf() * TAU
		var sp = 30.0 + rng.randf() * 110.0
		particles.append({
			"x": plant.pos.x, "y": plant.pos.y + 8.0,
			"vx": cos(a) * sp, "vy": -40.0 - rng.randf() * 60.0,
			"life": 0.5 + rng.randf() * 0.4, "max": 0.9,
			"size": 2.0 + rng.randf() * 4.0,
			"color": Color("#5f8f7c") if i % 3 else Color("#c7e0bd"),
			"kind": "circle",
		})
	float_text(plant.pos + Vector2(0, -40), "沉底了", Color("#bfe0cf"), 16)


func nearest_zombies(pos: Vector2, limit: int, exclude: Array = []) -> Array:
	var pool: Array = []
	for z in zombies:
		if not z.alive() or exclude.has(z):
			continue
		pool.append({"z": z, "d": pos.distance_squared_to(z.pos)})
	pool.sort_custom(func(a, b): return float(a["d"]) < float(b["d"]))
	var out: Array = []
	for entry in pool.slice(0, limit):
		out.append(entry["z"])
	return out


func nearest_any(plant: Plant) -> Zombie:
	var best: Zombie = null
	var best_d = INF
	for z in zombies:
		if not z.alive():
			continue
		var d = z.pos.distance_squared_to(plant.pos)
		if d < best_d:
			best_d = d
			best = z
	return best


func _update_cat(plant: Plant, dt: float) -> void:
	var interval = float(plant.def["homing"]["interval"]) / (1.0 + plant.haste)
	plant.timer += dt
	var target = nearest_any(plant)
	if target == null:
		plant.timer = minf(plant.timer, interval)
		return
	plant.charge = minf(1.0, plant.timer / interval)
	if plant.timer < interval:
		return
	plant.timer = 0.0
	plant.charge = 0.0
	fire_cat(plant)


## 射弹的伤害由「基准值 × (1 + 取最高的增幅)」得到，红灯笼与炭火盆不叠加。
func _prepare_shot(shot: Shot, plant: Plant, raw: float) -> void:
	shot.base_damage = raw
	shot.lantern_buff = plant.buff_damage
	shot.damage = raw * (1.0 + plant.buff_damage)


func fire_cat(plant: Plant) -> void:
	var fx: Dictionary = Upgrades.EFFECTS["cat"]
	var count = int(fx["count"][plant.tier(1)])
	var targets = nearest_zombies(plant.pos, count)
	if targets.is_empty():
		return
	var damage = float(fx["damage"][plant.tier(2)])
	var hits = int(fx["hits"][plant.tier(2)])
	sfx("cat_shot")
	for i in count:
		var target: Zombie = targets[i % targets.size()]
		var shot = Shot.new()
		shot.kind = "homing"
		shot.target = target
		shot.hits_left = hits
		shot.pos = plant.pos + Vector2(12, -22)
		shot.row = target.row
		shot.speed = float(fx["speed"])
		_prepare_shot(shot, plant, damage)
		shot.vuln = float(fx["vuln"][plant.tier(3)])
		shot.vuln_duration = float(fx["vuln_duration"])
		shot.slow = float(fx["slow"][plant.tier(3)])
		shot.slow_duration = float(fx["slow_duration"])
		shots.append(shot)
	plant.recoil = 0.7


func _update_lobber(plant: Plant, dt: float) -> void:
	var fx: Dictionary = Upgrades.EFFECTS["lobber"]
	var interval = float(fx["interval"][plant.tier(2)]) / (1.0 + plant.haste)
	plant.timer += dt
	var target: Zombie = null
	for z in zombies:
		if not z.alive() or z.row != plant.row or z.pos.x <= plant.pos.x + 6.0:
			continue
		if target == null or z.pos.x > target.pos.x:
			target = z
	if target == null:
		plant.timer = minf(plant.timer, interval)
		return
	plant.charge = minf(1.0, plant.timer / interval)
	if plant.timer < interval:
		return
	plant.timer = 0.0
	plant.charge = 0.0
	var shot = Shot.new()
	shot.kind = "lob"
	shot.target = target
	shot.row = plant.row
	shot.pos = plant.pos + Vector2(10, -22)
	shot.start = shot.pos
	shot.tx = target.pos.x
	shot.ty = target.pos.y - 14.0
	shot.flight = float(plant.def["lob"]["flight"])
	_prepare_shot(shot, plant, float(fx["damage"][plant.tier(1)]))
	shot.slow = float(fx["slow"][plant.tier(3)])
	shot.slow_duration = float(fx["slow_duration"])
	shots.append(shot)
	plant.recoil = 0.9
	sfx("lob_shot")


func star_direction_has_target(origin: Vector2, dir: Vector2) -> bool:
	for z in zombies:
		if not z.alive():
			continue
		var delta = Vector2(z.pos.x - origin.x, (z.pos.y - 26.0) - origin.y)
		var along = delta.dot(dir)
		if along <= 0.0:
			continue
		if absf(delta.x * dir.y - delta.y * dir.x) <= 34.0:
			return true
	return false


func _update_star(plant: Plant, dt: float) -> void:
	var fx: Dictionary = Upgrades.EFFECTS["star"]
	var interval = float(fx["interval"][plant.tier(2)]) / (1.0 + plant.haste)
	plant.timer += dt
	var has_target = false
	for z in zombies:
		if z.alive() and z.pos.x > plant.pos.x:
			has_target = true
			break
	if not has_target:
		plant.timer = minf(plant.timer, interval)
		return
	plant.charge = minf(1.0, plant.timer / interval)
	if plant.timer < interval:
		return
	plant.timer = 0.0
	plant.charge = 0.0
	var origin = plant.pos + Vector2(0, -22)
	var dirs: Array = [
		Vector2(-1, 0), Vector2(0, -1), Vector2(0, 1),
		Vector2(cos(PI / 3.0), -sin(PI / 3.0)),
		Vector2(cos(PI / 3.0), sin(PI / 3.0)),
	]
	var any = false
	for dir in dirs:
		if not star_direction_has_target(origin, Vector2(dir)):
			continue
		any = true
		var shot = Shot.new()
		shot.kind = "star"
		shot.dir = dir
		shot.pos = origin + Vector2(dir) * 16.0
		shot.row = plant.row
		shot.speed = 560.0
		_prepare_shot(shot, plant, float(fx["damage"][plant.tier(1)]))
		shot.vuln = float(fx["vuln"][plant.tier(3)])
		shot.vuln_duration = float(fx["vuln_duration"])
		shots.append(shot)
	if any:
		sfx("star_shot")
		plant.recoil = 0.7
		plant.pulse = 0.45


func _update_needle(plant: Plant, dt: float) -> void:
	var fx: Dictionary = Upgrades.EFFECTS["needle"]
	var interval = float(fx["interval"][plant.tier(2)]) / (1.0 + plant.haste)
	plant.timer += dt
	var best: Zombie = null
	var best_armored: Zombie = null
	for z in zombies:
		if not z.alive() or z.row != plant.row or z.pos.x <= plant.pos.x + 6.0:
			continue
		if best == null or z.pos.x < best.pos.x:
			best = z
		if z.armor > 0.0 and (best_armored == null or z.pos.x < best_armored.pos.x):
			best_armored = z
	var target: Zombie = best_armored if best_armored != null else best
	if target == null:
		plant.timer = minf(plant.timer, interval)
		return
	plant.charge = minf(1.0, plant.timer / interval)
	if plant.timer < interval:
		return
	plant.timer = 0.0
	plant.charge = 0.0
	var shot = Shot.new()
	shot.pos = plant.pos + Vector2(22, -16)
	shot.row = plant.row
	shot.speed = float(plant.def["needle"]["speed"])
	_prepare_shot(shot, plant, float(fx["damage"][plant.tier(1)]))
	shot.pierce_armor = true
	shot.vuln = float(fx["vuln"][plant.tier(3)])
	shot.vuln_duration = float(fx["vuln_duration"])
	shots.append(shot)
	plant.recoil = 0.6
	sfx("needle_shot")


func _update_judge(plant: Plant, dt: float) -> void:
	var fx: Dictionary = Upgrades.EFFECTS["judge"]
	var interval = float(fx["interval"][plant.tier(2)]) / (1.0 + plant.haste)
	plant.timer += dt
	var reach = float(fx["reach"])
	var target: Zombie = null
	for z in zombies:
		if not z.alive() or z.row != plant.row:
			continue
		if z.pos.x < plant.pos.x - 12.0 or z.pos.x - plant.pos.x > reach:
			continue
		if target == null or z.pos.x < target.pos.x:
			target = z
	if target == null:
		plant.timer = minf(plant.timer, interval)
		return
	plant.charge = minf(1.0, plant.timer / interval)
	if plant.timer < interval:
		return
	plant.timer = 0.0
	plant.charge = 0.0
	var damage = float(fx["damage"][plant.tier(3)]) * (1.0 + plant.buff_damage)
	var knock = float(fx["knock_cells"][plant.tier(1)]) * Geo.CELL_W
	sfx("judge")
	damage_zombie(target, damage)
	if target.alive():
		target.pos.x = minf(Geo.RETREAT_MAX_X, target.pos.x + knock)
	ring(plant.pos + Vector2(0, -30), Color(0.84, 0.45, 0.3, 0.5), 54.0, 0.5)
	spark(Vector2(target.pos.x, target.pos.y - 14.0), Color("#f0c26e"), 6)
	shake = maxf(shake, 3.0)
	plant.recoil = 1.0
	plant.pulse = 0.5


func _update_lion(plant: Plant, dt: float) -> void:
	var fx: Dictionary = Upgrades.EFFECTS["lion"]
	var interval = float(fx["interval"][plant.tier(2)]) / (1.0 + plant.haste)
	plant.timer += dt
	var reach = float(fx["reach"])
	var target: Zombie = null
	for z in zombies:
		if not z.alive() or z.row != plant.row:
			continue
		if z.pos.x < plant.pos.x - 12.0 or z.pos.x - plant.pos.x > reach:
			continue
		if target == null or z.pos.x < target.pos.x:
			target = z
	if target == null:
		plant.timer = minf(plant.timer, interval)
		return
	plant.charge = minf(1.0, plant.timer / interval)
	if plant.timer < interval:
		return
	plant.timer = 0.0
	plant.charge = 0.0
	sfx("lion")
	var damage = float(fx["damage"][plant.tier(1)]) * (1.0 + plant.buff_damage)
	var stun_chance = float(fx["stun_chance"][plant.tier(2)])
	var heal = float(fx["heal"][plant.tier(3)])
	var knock = float(fx["knock_cells"]) * Geo.CELL_W * float(
		fx["knock_bonus"][plant.tier(1)])
	damage_zombie(target, damage)
	if not target.dead:
		if stun_chance > 0.0 and rng.randf() < stun_chance:
			apply_stun(target, float(fx["stun_duration"]))
		target.pos.x = minf(Geo.RETREAT_MAX_X, target.pos.x + knock)
	if heal > 0.0:
		plant.hp = minf(plant.max_hp, plant.hp + heal)
	plant.recoil = 1.0
	plant.pulse = 0.35
	spark(plant.pos + Vector2(18, -14), Color("#f0c26e"), 5)
	shake = maxf(shake, 1.6)


func _update_wall(plant: Plant, dt: float) -> void:
	var fx: Dictionary = Upgrades.EFFECTS["wall"]
	var heal_tier = plant.tier(1)
	if heal_tier > 0 and plant.hp < plant.max_hp and (
			bool(fx["heal_while_eaten"][heal_tier]) or plant.bite_t <= 0.0):
		plant.hp = minf(plant.max_hp, plant.hp + float(fx["heal"][heal_tier]) * dt)
		if rng.randf() < dt * 1.8:
			particles.append({
				"x": plant.pos.x + rng.randf_range(-12, 12),
				"y": plant.pos.y - 4.0 - rng.randf() * 18.0,
				"vx": rng.randf_range(-5, 5), "vy": -18.0 - rng.randf() * 20.0,
				"life": 0.5, "max": 0.5, "size": 1.6 + rng.randf() * 1.6,
				"color": Color("#9fc7a4"), "kind": "circle",
			})
	var tier = plant.tier(3)
	if tier <= 0:
		return
	plant.timer += dt
	var interval = float(fx["gravel_interval"]) / (1.0 + plant.haste)
	var target = lane_target(plant)
	if target == null:
		plant.timer = minf(plant.timer, interval)
		return
	plant.charge = minf(1.0, plant.timer / interval)
	if plant.timer < interval:
		return
	plant.timer -= interval
	plant.charge = 0.0
	var shot = Shot.new()
	shot.pos = plant.pos + Vector2(24, -10)
	shot.row = plant.row
	shot.speed = 430.0
	_prepare_shot(shot, plant, float(fx["gravel_damage"][tier]))
	shot.vuln = float(fx["vuln"][tier])
	shot.vuln_duration = float(fx["vuln_duration"])
	shot.knock = float(fx["knock_cells"][tier])
	shots.append(shot)
	plant.recoil = 0.8
	sfx("gravel_shot")


func explode(plant: Plant) -> void:
	plant.dead = true
	cells[plant.row][plant.col] = null
	sfx("explode")
	var radius = float(plant.def["bomb"]["radius"])
	var damage = float(plant.def["bomb"]["damage"]) * (1.0 + plant.buff_damage)
	for z in zombies:
		if not z.alive():
			continue
		if z.pos.distance_to(plant.pos) <= radius:
			damage_zombie(z, damage)
	for i in 30:
		var a = rng.randf() * TAU
		var sp = 80.0 + rng.randf() * 260.0
		particles.append({
			"x": plant.pos.x, "y": plant.pos.y,
			"vx": cos(a) * sp, "vy": sin(a) * sp - 60.0,
			"life": 0.45 + rng.randf() * 0.45, "max": 0.9,
			"size": 3.0 + rng.randf() * 5.0,
			"color": Color("#ff8b3d") if rng.randf() < 0.5 else Color("#ffd36b"),
			"kind": "circle",
		})
	shake = maxf(shake, 14.0)


# ── 恶客行为 ────────────────────────────────────────────────────────────────
func eat_target(z: Zombie) -> Plant:
	var reach = float(z.def.get("reach", 38.0))
	var best: Plant = null
	for plant in plants:
		if plant.dead or plant.row != z.row:
			continue
		if plant.is_lily and main_plant_at(plant.col, plant.row) != null:
			continue
		if plant.pos.x <= z.pos.x + 2.0 and z.pos.x - plant.pos.x <= reach:
			if best == null or plant.pos.x > best.pos.x:
				best = plant
	return best


func update_zombies(dt: float) -> void:
	for z in zombies:
		if z.dead:
			continue
		if z.dying:
			z.death_t += dt
			if z.death_t >= z.death_dur:
				z.dead = true
				z.dying = false
			continue
		z.hurt = maxf(0.0, z.hurt - dt)
		if z.slow_t > 0.0:
			z.slow_t = maxf(0.0, z.slow_t - dt)
			if z.slow_t <= 0.0:
				z.slow_amount = 0.0
		if z.vuln_t > 0.0:
			z.vuln_t = maxf(0.0, z.vuln_t - dt)
			if z.vuln_t <= 0.0:
				z.vuln = 0.0
		if z.burn_t > 0.0:
			z.burn_t = maxf(0.0, z.burn_t - dt)
			damage_zombie(z, z.burn_dps * dt, true)
			if not z.alive():
				continue
			if z.burn_t <= 0.0:
				z.burn_dps = 0.0
		if z.rage_t > 0.0:
			z.rage_t = maxf(0.0, z.rage_t - dt)
		z.aura_pulse = maxf(0.0, z.aura_pulse - dt)
		z.support_pulse = maxf(0.0, z.support_pulse - dt)
		z.armor_pulse = maxf(0.0, z.armor_pulse - dt)
		z.wail_t = maxf(0.0, z.wail_t - dt)
		if z.stun_t > 0.0:
			z.stun_t = maxf(0.0, z.stun_t - dt)
			z.eating = false
			if rng.randf() < dt * 2.5:
				particles.append({
					"x": z.pos.x + rng.randf_range(-10, 10),
					"y": z.pos.y - 48.0 + rng.randf_range(-5, 5),
					"vx": 8.0, "vy": -18.0, "life": 0.4, "max": 0.4,
					"size": 1.8, "color": Color("#ffe09a"), "kind": "circle",
				})
			continue
		if z.def.has("aura"):
			z.aura_t -= dt
			if z.aura_t <= 0.0:
				mourner_wail(z)
		if z.def.has("support"):
			z.support_t -= dt
			if z.support_t <= 0.0:
				artisan_grant(z)
		if z.vault_t > 0.0:
			z.vault_t = maxf(0.0, z.vault_t - dt)
			var dur = float(z.def["vault"]["duration"])
			var k = 1.0 - z.vault_t / dur
			z.pos.x = lerpf(z.vault_from, z.vault_to, k)
			z.vault_arc = sin(PI * clampf(k, 0.0, 1.0))
			z.anim += dt * 2.4
			z.eating = false
			if z.vault_t <= 0.0:
				z.vaulted = true
				z.speed = float(z.def["vault"]["speed_after"])
				z.vault_arc = 0.0
				for i in 7:
					particles.append({
						"x": z.pos.x + rng.randf_range(-13, 13), "y": z.pos.y + 24.0,
						"vx": rng.randf_range(-40, 40), "vy": -20.0 - rng.randf() * 40.0,
						"life": 0.4 + rng.randf() * 0.3, "max": 0.7,
						"size": 2.0 + rng.randf() * 3.0,
						"color": Color(0.72, 0.65, 0.52, 0.8), "kind": "circle",
					})
				shake = maxf(shake, 2.5)
			continue
		if z.def.has("vault") and not z.vaulted:
			var obstacle = eat_target(z)
			if obstacle != null:
				z.vault_from = z.pos.x
				z.vault_to = maxf(Geo.BOARD_X + 8.0, obstacle.pos.x - 42.0)
				z.vault_t = float(z.def["vault"]["duration"])
				z.vault_arc = 0.0
				z.eating = false
				for i in 6:
					particles.append({
						"x": z.pos.x + rng.randf_range(-11, 11), "y": z.pos.y + 26.0,
						"vx": rng.randf_range(-45, 45), "vy": -35.0 - rng.randf() * 50.0,
						"life": 0.35 + rng.randf() * 0.3, "max": 0.65,
						"size": 2.0 + rng.randf() * 3.0,
						"color": Color(0.77, 0.69, 0.55, 0.8), "kind": "circle",
					})
				float_text(z.pos + Vector2(0, -66), "跳幡！", Color("#f0d59a"), 15, 0.9)
				continue
		var target = eat_target(z)
		if target != null:
			z.eating = true
			z.chomp += dt
			z.eat_bite = maxf(0.0, z.eat_bite - dt * 8.0)
			z.eat_snd_t -= dt
			if z.eat_snd_t <= 0.0:
				z.eat_bite = 1.0
				target.bite_t = 0.2
				sfx("eat")
				z.eat_snd_t = 0.3 + rng.randf() * 0.12
				for i in 4:
					particles.append({
						"x": z.pos.x - 26.0 + rng.randf_range(-8, 8),
						"y": z.pos.y - 22.0 + rng.randf_range(-7, 7),
						"vx": -30.0 - rng.randf() * 60.0, "vy": -35.0 - rng.randf() * 70.0,
						"life": 0.32 + rng.randf() * 0.22, "max": 0.54,
						"size": 2.0 + rng.randf() * 2.6,
						"color": Color("#c7cba8") if target.shell > 0.0 else Color("#e0c58c"),
						"kind": "shard" if i % 2 else "circle",
					})
			var guard = plant_guard(target)
			damage_plant(target, float(z.def["dps"]) * (1.0 - guard) * dt)
			if target.type == "wall":
				var reflect = float(Upgrades.EFFECTS["wall"]["reflect"][target.tier(2)])
				if reflect > 0.0:
					damage_zombie(z, reflect * (1.0 + target.buff_damage) * dt, true)
			if rng.randf() < dt * 4.0:
				particles.append({
					"x": target.pos.x + rng.randf_range(-10, 10), "y": target.pos.y - 6.0,
					"vx": rng.randf_range(-20, 20), "vy": -30.0 - rng.randf() * 40.0,
					"life": 0.5, "max": 0.5, "size": 2.0 + rng.randf() * 2.0,
					"color": Color("#c7cba8") if target.shell > 0.0 else Color("#d9c08a"),
					"kind": "circle",
				})
			continue
		z.eating = false
		z.eat_bite = 0.0
		z.eat_snd_t = 0.0
		var slow_mult = (1.0 - z.slow_amount) if z.slow_t > 0.0 else 1.0
		var rage = maxf(1.0, z.rage_mult) if z.rage_t > 0.0 else 1.0
		z.pos.x -= z.speed * slow_mult * rage * dt
		z.anim += dt * slow_mult * rage
		var col = int((z.pos.x - Geo.BOARD_X) / Geo.CELL_W)
		if col >= 0 and col < Geo.COLS:
			var tile = tile_at(col, z.row)
			if tile["kind"] == "object":
				var key = "%d:%d" % [z.row, col]
				if z.last_object != key:
					z.last_object = key
					z.pos.x = maxf(Geo.BOARD_X + 6.0, z.pos.x - Geo.CELL_W * 0.62)
					z.object_hop = 0.34
					for i in 5:
						particles.append({
							"x": z.pos.x + rng.randf_range(-11, 11), "y": z.pos.y + 22.0,
							"vx": rng.randf_range(-35, 35), "vy": -18.0 - rng.randf() * 35.0,
							"life": 0.35 + rng.randf() * 0.25, "max": 0.6,
							"size": 2.0 + rng.randf() * 2.5,
							"color": Color(0.71, 0.78, 0.75, 0.75), "kind": "circle",
						})
			else:
				z.last_object = ""
		if z.object_hop > 0.0:
			z.object_hop = maxf(0.0, z.object_hop - dt)
		if z.pos.x < Geo.BREACH_X and not z.breached:
			breach(z)


func mourner_wail(z: Zombie) -> void:
	var aura: Dictionary = z.def["aura"]
	z.aura_t = float(aura["interval"])
	z.aura_pulse = 0.85
	z.wail_t = 0.95
	var buffed = false
	for other in zombies:
		if not other.alive() or other == z:
			continue
		if other.pos.distance_to(z.pos) > float(aura["radius"]):
			continue
		var current = maxf(1.0, other.rage_mult) if other.rage_t > 0.0 else 1.0
		var haste = float(aura["haste"])
		if haste > current + 0.0001:
			other.rage_mult = haste
			other.rage_t = float(aura["duration"])
		elif absf(haste - current) <= 0.0001:
			other.rage_t = maxf(other.rage_t, float(aura["duration"]))
		buffed = true
	ring(z.pos + Vector2(0, -6), Color(0.77, 0.49, 0.4, 0.4) if buffed
		else Color(0.59, 0.51, 0.47, 0.32), maxf(30.0, float(aura["radius"]) - 26.0), 0.7)
	for i in 8:
		particles.append({
			"x": z.pos.x + rng.randf_range(-13, 13),
			"y": z.pos.y - 32.0 - rng.randf() * 22.0,
			"vx": rng.randf_range(-18, 18) - 18.0, "vy": -24.0 - rng.randf() * 30.0,
			"life": 0.55 + rng.randf() * 0.35, "max": 0.9,
			"size": 1.8 + rng.randf() * 2.4,
			"color": Color(0.69, 0.84, 0.89, 0.75) if i % 2 else Color(0.86, 0.91, 0.93, 0.55),
			"kind": "circle",
		})
	sfx("wail")


## 纸扎匠优先给没有护具、护具最薄的低阶恶客发甲。
static func _later_armor_first(a: Zombie, b: Zombie) -> bool:
	var aa = 1 if a.armor > 0.0 else 0
	var bb = 1 if b.armor > 0.0 else 0
	if aa != bb:
		return aa < bb
	return a.armor < b.armor


func artisan_grant(z: Zombie) -> void:
	var support: Dictionary = z.def["support"]
	z.support_t = float(support["interval"])
	z.support_pulse = 0.85
	var hp_mult = hp_mul * float(difficulty_mult()["hp"])
	var armor_value = maxf(40.0, round(float(support["armor"]) * hp_mult))
	var pool: Array = []
	for other in zombies:
		if not other.alive() or other == z:
			continue
		if String(other.def.get("tier", "")) != "l":
			continue
		if other.pos.distance_to(z.pos) > float(support["radius"]):
			continue
		pool.append(other)
	pool.sort_custom(_later_armor_first)
	for other in pool.slice(0, int(support["targets"])):
		other.max_armor = maxf(other.max_armor, armor_value)
		other.armor = minf(other.max_armor, maxf(other.armor, armor_value))
		other.armor_type = "charm"
		other.armor_name = String(support["name"])
		other.armor_pulse = 0.9
		float_text(other.pos + Vector2(0, -62), "纸甲", Color("#e5d6a4"), 14, 1.1)
	ring(z.pos + Vector2(0, -20), Color(0.88, 0.8, 0.59, 0.55) if not pool.is_empty()
		else Color(0.67, 0.63, 0.55, 0.3), 54.0, 0.65)
	sfx("grant")


func breach(z: Zombie) -> void:
	z.breached = true
	var mower: Dictionary = mowers[z.row]
	if bool(mower["ready"]):
		mower["ready"] = false
		mower["active"] = true
		mower["x"] = Geo.MOWER_X
		sfx("mower")
		shake = maxf(shake, 8.0)
		float_text(Vector2(Geo.BOARD_X + 60.0, row_y(z.row) - 40.0), "门神显灵！",
			Color("#ffd98a"), 18, 1.4)
		return
	if training:
		z.dead = true
		z.dying = false
		float_text(Vector2(Geo.BOARD_X + 80.0, row_y(z.row) - 36.0), "训练场不判负",
			Color("#ffd98a"), 16, 1.4)
		return
	if on_lose.is_valid():
		on_lose.call(z)


# ── 射弹 ────────────────────────────────────────────────────────────────────
func update_shots(dt: float) -> void:
	for shot in shots:
		if shot.dead:
			continue
		match shot.kind:
			"homing":
				_update_homing(shot, dt)
			"lob":
				_update_lob_shot(shot, dt)
			"star":
				_update_star_shot(shot, dt)
			_:
				_update_straight(shot, dt)


func _apply_torch_pass(shot: Shot, previous: Vector2) -> void:
	for plant in plants:
		if plant.dead or plant.type != "torch":
			continue
		var crossed = false
		if shot.kind == "star":
			crossed = shot.pos.distance_to(plant.pos + Vector2(0, -18)) < 52.0
		else:
			var same_lane = absf(shot.pos.y - plant.pos.y) < 64.0 \
				if shot.kind == "homing" else shot.row == plant.row
			if not same_lane:
				continue
			crossed = (previous.x - plant.pos.x) * (shot.pos.x - plant.pos.x) <= 0.0
			if not crossed:
				crossed = absf(shot.pos.x - plant.pos.x) < 12.0
		if not crossed:
			continue
		var fx: Dictionary = Upgrades.EFFECTS["torch"]
		var buff = float(fx["buff"][plant.tier(1)])
		var burn = float(fx["burn"][plant.tier(2)])
		var slow = float(fx["slow"][plant.tier(3)])
		# 多盆只取最高：火盆增幅与红灯笼增幅同样「取最高不叠加」。
		if buff > shot.torch_buff + 0.0001:
			shot.torch_buff = buff
			shot.damage = shot.base_damage * (1.0 + maxf(shot.lantern_buff, buff))
		if burn > shot.burn + 0.0001:
			shot.burn = burn
			shot.burn_duration = float(fx["burn_duration"])
		if slow > shot.slow + 0.0001:
			shot.slow = slow
			shot.slow_duration = float(fx["slow_duration"])
		if shot.torch_buff > 0.0 or shot.burn > 0.0 or shot.slow > 0.0:
			shot.fire = true
			shot.fire_t = maxf(shot.fire_t, 0.6)
		if burn > 0.0 and burn > shot.burn:
			shot.burn = burn
			shot.burn_duration = float(fx["burn_duration"])
		if slow > 0.0 and slow > shot.slow:
			shot.slow = slow
			shot.slow_duration = float(fx["slow_duration"])


func _update_straight(shot: Shot, dt: float) -> void:
	var previous = shot.pos
	shot.pos.x += shot.speed * dt
	_apply_torch_pass(shot, previous)
	var victim: Zombie = null
	for z in zombies:
		if z.dead or z.row != shot.row:
			continue
		if shot.pos.x + 8.0 >= z.pos.x - 24.0 and shot.pos.x - 8.0 <= z.pos.x + 24.0:
			if victim == null or z.pos.x < victim.pos.x:
				victim = z
	if victim != null:
		shot.dead = true
		if victim.dying:
			spark(shot.pos, Color("#c9bda0"), 3)
			return
		var large = victim.is_large()
		var damage = shot.damage * 2.0 if (shot.knock > 0.0 and large) else shot.damage
		damage_zombie(victim, damage, false, shot.pierce_armor)
		apply_shot_statuses(victim, shot)
		if shot.knock > 0.0 and not large and victim.alive():
			victim.pos.x = minf(Geo.RETREAT_MAX_X, victim.pos.x + shot.knock * Geo.CELL_W)
			ring(Vector2(victim.pos.x, victim.pos.y + 8.0), Color(0.78, 0.7, 0.55, 0.6), 18.0, 0.4)
		spark(shot.pos, Color("#ffe9a8") if shot.big else Color("#f0dca8"),
			8 if shot.big else 3)
		return
	if shot.pos.x > 1360.0:
		shot.dead = true


func _update_homing(shot: Shot, dt: float) -> void:
	var previous = shot.pos
	_apply_torch_pass(shot, previous)
	if shot.target == null or not shot.target.alive():
		var next = nearest_zombies(shot.pos, 1, shot.hit_ids)
		shot.target = next[0] if not next.is_empty() else null
	if shot.target == null:
		shot.dead = true
		return
	var aim = Vector2(shot.target.pos.x, shot.target.pos.y - 24.0)
	var delta = aim - shot.pos
	var distance = delta.length()
	if distance < 15.0:
		var victim = shot.target
		shot.hit_ids.append(victim)
		damage_zombie(victim, shot.damage)
		apply_shot_statuses(victim, shot)
		spark(shot.pos, Color("#ffd08a"), 5)
		shot.hits_left -= 1
		if shot.hits_left > 0:
			var next = nearest_zombies(shot.pos, 1, shot.hit_ids)
			if not next.is_empty():
				shot.target = next[0]
				return
		shot.dead = true
		return
	shot.pos += (delta / distance) * shot.speed * dt
	_apply_torch_pass(shot, previous)
	if rng.randf() < dt * 24.0:
		particles.append({
			"x": shot.pos.x, "y": shot.pos.y,
			"vx": rng.randf_range(-8, 8), "vy": -12.0 - rng.randf() * 16.0,
			"life": 0.35, "max": 0.35, "size": 1.8 + rng.randf() * 1.4,
			"color": Color("#ffb45e"), "kind": "circle",
		})
	for z in zombies:
		if not z.dying:
			continue
		if Vector2(z.pos.x, z.pos.y - 24.0).distance_to(shot.pos) > 22.0:
			continue
		shot.dead = true
		return


func _update_lob_shot(shot: Shot, dt: float) -> void:
	if shot.target != null and shot.target.alive():
		shot.tx = shot.target.pos.x
		shot.ty = shot.target.pos.y - 14.0
	var previous = shot.pos
	shot.t += dt
	var k = minf(1.0, shot.t / shot.flight)
	shot.pos.x = lerpf(shot.start.x, shot.tx, k)
	var base_y = lerpf(shot.start.y, shot.ty, k)
	shot.pos.y = base_y - 108.0 * 4.0 * k * (1.0 - k)
	_apply_torch_pass(shot, previous)
	if k < 1.0:
		return
	shot.dead = true
	var victim: Zombie = null
	for z in zombies:
		if not z.alive() or z.row != shot.row:
			continue
		if victim == null or absf(z.pos.x - shot.tx) < absf(victim.pos.x - shot.tx):
			victim = z
	if victim == null or absf(victim.pos.x - shot.tx) > 54.0:
		spark(shot.pos, Color("#e8d6a8"), 4)
		return
	damage_zombie(victim, shot.damage)
	apply_shot_statuses(victim, shot)
	spark(shot.pos, Color("#f0dca8"), 7)
	ring(shot.pos + Vector2(0, 8), Color(0.9, 0.82, 0.67, 0.5), 18.0, 0.4)


func _update_star_shot(shot: Shot, dt: float) -> void:
	var previous = shot.pos
	shot.pos += shot.dir * shot.speed * dt
	shot.life -= dt
	_apply_torch_pass(shot, previous)
	if shot.life <= 0.0 or shot.pos.x < -100.0 or shot.pos.x > 1380.0 \
			or shot.pos.y < -100.0 or shot.pos.y > Geo.BOARD_Y + Geo.BOARD_H + 100.0:
		shot.dead = true
		return
	var victim: Zombie = null
	for z in zombies:
		if not z.alive():
			continue
		if absf(z.pos.x - shot.pos.x) <= 28.0 and absf((z.pos.y - 26.0) - shot.pos.y) <= 40.0:
			if victim == null or absf(z.pos.x - shot.pos.x) < absf(victim.pos.x - shot.pos.x):
				victim = z
	if victim == null:
		return
	shot.dead = true
	damage_zombie(victim, shot.damage)
	apply_shot_statuses(victim, shot)
	spark(shot.pos, Color("#ffcf7a") if shot.fire else Color("#ffe08a"), 5)


# ── 伤害与死亡 ──────────────────────────────────────────────────────────────
func damage_zombie(z: Zombie, amount: float, silent: bool = false,
		pierce_armor: bool = false) -> float:
	if z == null or not z.alive():
		return 0.0
	if not silent and amount >= 8.0:
		sfx("hit")
	var damage = amount
	if z.vuln_t > 0.0 and z.vuln > 0.0:
		damage *= 1.0 + z.vuln
	var dealt = 0.0
	if not pierce_armor and z.armor > 0.0:
		var absorbed = minf(z.armor, damage)
		z.armor -= absorbed
		damage -= absorbed
		dealt += absorbed
		if z.armor <= 0.0:
			z.armor = 0.0
			break_armor(z)
	if damage > 0.0:
		z.hp -= damage
		dealt += damage
	z.hurt = 0.14
	if z.hp <= 0.0:
		kill_zombie(z)
	return dealt


func break_armor(z: Zombie) -> void:
	sfx("shell")
	var colors = {
		"paper": Color("#efe6cf"), "sedan": Color("#c77a55"), "straw": Color("#d7b26a"),
		"stonehat": Color("#a8a69a"), "urn": Color("#b07a4e"), "mask": Color("#7d858a"),
		"charm": Color("#e5d6a4"),
	}
	var color: Color = colors.get(z.armor_type, Color("#efe6cf"))
	for i in 10:
		particles.append({
			"x": z.pos.x + rng.randf_range(-14, 14),
			"y": z.pos.y - 24.0 - rng.randf() * 22.0,
			"vx": rng.randf_range(-70, 70), "vy": -40.0 - rng.randf() * 100.0,
			"life": 0.55, "max": 0.75, "size": 3.0 + rng.randf() * 5.0,
			"color": color,
			"kind": "shard" if z.armor_type in ["paper", "charm"] else "circle",
		})
	if z.def.has("split") and not z.split_done:
		z.split_done = true
		var split: Dictionary = z.def["split"]
		var count = int(split["count"])
		for i in count:
			pending_spawns.append({
				"type": split["type"], "row": z.row,
				"x": z.pos.x + (i - (count - 1) * 0.5) * 20.0,
				"hp_factor": float(split["hp"]),
			})
		float_text(z.pos + Vector2(0, -76), "轿子散了！", Color("#ffd0a0"), 17, 1.4)
		shake = maxf(shake, 6.0)


func kill_zombie(z: Zombie) -> void:
	if not z.alive():
		return
	z.dying = true
	z.death_t = 0.0
	z.hp = 0.0
	z.eating = false
	z.stun_t = 0.0
	z.breached = true
	sfx("zombie_die")
	kills += 1
	var colors = {
		"mountain": Color("#5a4030"), "paper": Color("#efe6cf"),
		"mourner": Color("#d8d2c4"), "sedan": Color("#a83a2e"),
		"tongue": Color("#87a87d"), "straw": Color("#c9a45e"),
		"stonehat": Color("#9a978b"), "bucket": Color("#8f999b"),
		"vault": Color("#a98252"), "artisan": Color("#e8ddc1"),
		"ironjudge": Color("#6f7679"),
	}
	var color: Color = colors.get(z.type, Color("#9fb3a2"))
	for i in 10:
		particles.append({
			"x": z.pos.x + rng.randf_range(-13, 13),
			"y": z.pos.y - 10.0 - rng.randf() * 30.0,
			"vx": rng.randf_range(-70, 70), "vy": -30.0 - rng.randf() * 120.0,
			"life": 0.5 + rng.randf() * 0.4, "max": 0.9,
			"size": 3.0 + rng.randf() * 4.0, "color": color, "kind": "shard",
		})
	if bool(z.def.get("large", false)):
		shake = maxf(shake, 5.0)
	if tutorial != null and String(tutorial["step"]) == "battle" and tutorial["zombie"] == z:
		tutorial["step"] = "finishing"
		tutorial["done_t"] = 0.9
		float_text(z.pos + Vector2(0, -58), "干得漂亮", Color("#ffe1a1"), 22, 1.4)


# ── 门神与太阳 ──────────────────────────────────────────────────────────────
func update_mowers(dt: float) -> void:
	for mower in mowers:
		if not bool(mower["active"]):
			continue
		mower["x"] = float(mower["x"]) + 640.0 * dt
		for z in zombies:
			if z.alive() and z.row == int(mower["row"]) \
					and absf(z.pos.x - float(mower["x"])) < 56.0:
				kill_zombie(z)
		if float(mower["x"]) > 1360.0:
			mower["active"] = false


func restore_mowers() -> void:
	for mower in mowers:
		mower["ready"] = true
		mower["active"] = false
		mower["x"] = Geo.MOWER_X


func update_orbs(dt: float) -> void:
	for orb in orbs:
		if bool(orb["dead"]):
			continue
		if not bool(orb["landed"]):
			orb["y"] = float(orb["y"]) + 130.0 * dt
			if float(orb["y"]) >= float(orb["target_y"]):
				orb["y"] = float(orb["target_y"])
				orb["landed"] = true
			continue
		orb["life"] = float(orb["life"]) - dt
		# 教学关的香火不设时限，也不能被自动拾取（v0.2.4 曾在这里把 life 改回 10 卡死教学）。
		if auto_collect and tutorial == null:
			orb["auto_t"] = float(orb["auto_t"]) + dt
			if float(orb["auto_t"]) >= collect_delay:
				collect_orb(orb)
				continue
		if float(orb["life"]) <= 0.0:
			orb["dead"] = true


func collect_orb(orb: Dictionary) -> void:
	if bool(orb["dead"]):
		return
	orb["dead"] = true
	sun += int(orb["value"])
	float_text(Vector2(float(orb["x"]), float(orb["y"]) - 12.0),
		"+%d" % int(orb["value"]), Color("#ffd98a"), 18, 0.9)
	spark(Vector2(float(orb["x"]), float(orb["y"])), Color("#ffcf7a"), 6)
	sfx("collect")
	if tutorial != null and String(tutorial["step"]) == "collect" and tutorial["orb"] == orb:
		tutorial["step"] = "plant"
		tutorial["orb"] = {}


func pick_orb(at: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_d = 44.0
	for orb in orbs:
		if bool(orb["dead"]):
			continue
		var d = Vector2(float(orb["x"]), float(orb["y"])).distance_to(at)
		if d < best_d:
			best_d = d
			best = orb
	return best


func update_particles(dt: float) -> void:
	for p in particles:
		if String(p["kind"]) == "ring":
			p["life"] = float(p["life"]) - dt
			continue
		p["vy"] = float(p["vy"]) + (260.0 if String(p["kind"]) == "shard" else 180.0) * dt
		p["x"] = float(p["x"]) + float(p["vx"]) * dt
		p["y"] = float(p["y"]) + float(p["vy"]) * dt
		p["life"] = float(p["life"]) - dt
	for f in floaters:
		f["y"] = float(f["y"]) - 26.0 * dt
		f["life"] = float(f["life"]) - dt


func auto_collect_enabled() -> bool:
	return auto_collect


# ── 训练场 ──────────────────────────────────────────────────────────────────
func summon_training(type: String, count: int, lane: int) -> void:
	if not training:
		return
	var def: Dictionary = Content.ZOMBIES.get(type, Content.ZOMBIES["ghost"])
	for i in count:
		var row = clampi(lane, 0, rows - 1) if lane >= 0 else rng.randi_range(0, rows - 1)
		spawn_zombie(String(def.get("id", type)), row,
			{"x": 1250.0 + i * 48.0 + rng.randf() * 24.0})
	floaters.append({
		"x": Geo.VIEW.x * 0.5, "y": 300.0,
		"text": "召来 %s ×%d" % [String(def["name"]), count],
		"color": Color("#ffd0a0"), "life": 1.6, "max": 1.6, "size": 20,
	})
	sfx("wave")


func clear_plants() -> void:
	if not training:
		return
	for plant in plants.duplicate():
		kill_plant(plant, true)
	plants.clear()
	lilies.clear()
	for r in rows:
		for c in Geo.COLS:
			cells[r][c] = null
	floaters.append({
		"x": Geo.VIEW.x * 0.5, "y": 310.0, "text": "草木已清空",
		"color": Color("#ffe1a1"), "life": 1.6, "max": 1.6, "size": 20,
	})
	sfx("explode")


func kill_all_zombies() -> int:
	var count = 0
	for z in zombies:
		if z.alive():
			kill_zombie(z)
			count += 1
	return count


# ── 教学关 ──────────────────────────────────────────────────────────────────
func start_tutorial() -> void:
	level = {
		"id": 0, "day": 1, "day_name": "第一天", "day_sub": "夜市街",
		"map": "street", "rows": 5, "water_rows": [], "object_cells": [],
		"name": "新手教程", "tag": "第一课", "threat": 1.0,
		"start_sun": 200, "waves": [],
	}
	level_id = 0
	rows = 5
	difficulty = "easy"
	count_mul = 1.0
	hp_mul = 1.0
	training = false
	no_cooldown = false
	tutorial = {
		"step": "collect", "orb": {}, "lantern": null, "shooter": null,
		"zombie": null, "battle_t": 0.0, "done_t": 0.0, "t": 0.0,
	}
	_reset(["shooter"])
	var lantern = place_free("lantern", 0, 2)
	if lantern != null:
		lantern.tutorial_idle = true
	var orb = {
		"x": (lantern.pos.x if lantern != null else 400.0) + 78.0,
		"y": (lantern.pos.y if lantern != null else 460.0) - 56.0,
		"target_y": (lantern.pos.y if lantern != null else 460.0) - 12.0,
		"landed": false, "life": 999999.0, "value": 25,
		"phase": 0.0, "dead": false, "auto_t": 0.0, "tutorial": true,
	}
	# v0.2.4 在落地时统一把 life 改成 10，教学香火因此会过期；本作教学香火不设时限。
	orbs.append(orb)
	tutorial["orb"] = orb
	tutorial["lantern"] = lantern


func spawn_tutorial_zombie() -> void:
	if tutorial == null:
		return
	var shooter: Plant = tutorial["shooter"]
	var row = shooter.row if shooter != null else 2
	var base_x = shooter.pos.x if shooter != null else Geo.BOARD_X + 300.0
	var x = minf(Geo.BOARD_X + Geo.BOARD_W - 12.0, maxf(1000.0, base_x + 260.0))
	var z = spawn_zombie("ghost", row, {"x": x})
	if z == null:
		return
	z.hp = 120.0
	z.max_hp = 120.0
	z.speed = 14.0
	tutorial["zombie"] = z
	banner = {"text": "恶客上门 · 看签筒出手", "t": 2.2, "max": 2.2}


func update_tutorial(dt: float) -> void:
	tutorial["t"] = float(tutorial["t"]) + dt
	if String(tutorial["step"]) == "battle" and float(tutorial["battle_t"]) > 0.0:
		tutorial["battle_t"] = float(tutorial["battle_t"]) - dt
		if float(tutorial["battle_t"]) <= 0.0:
			spawn_tutorial_zombie()
	if String(tutorial["step"]) == "finishing":
		tutorial["done_t"] = float(tutorial["done_t"]) - dt
		if float(tutorial["done_t"]) <= 0.0:
			tutorial["step"] = "done"
			if on_win.is_valid():
				on_win.call()


func tutorial_step() -> String:
	return String(tutorial["step"]) if tutorial != null else ""


func begin_tutorial_battle() -> void:
	if tutorial == null:
		return
	tutorial["step"] = "battle"
	tutorial["battle_t"] = 1.0


# ── 快照（存档）──────────────────────────────────────────────────────────────
func serialize() -> Dictionary:
	var plant_rows: Array = []
	for plant in plants:
		if plant.dead or plant.is_lily:
			continue
		plant_rows.append({
			"type": plant.type, "c": plant.col, "r": plant.row,
			"hp": plant.hp, "shell": plant.shell,
			"up": plant.upgrades.duplicate(), "timer": plant.timer,
			"armed": plant.armed, "arm_t": plant.arm_t,
			"chew_t": plant.chew_t, "chew_max": plant.chew_max,
		})
	var lily_rows: Array = []
	for key in lilies:
		var lily: Plant = lilies[key]
		if lily.dead:
			continue
		lily_rows.append({"c": lily.col, "r": lily.row, "hp": lily.hp})
	var zombie_rows: Array = []
	for z in zombies:
		if z.dead:
			continue
		zombie_rows.append({
			"type": z.type, "r": z.row, "x": z.pos.x, "hp": z.hp,
			"max_hp": z.max_hp, "armor": z.armor, "max_armor": z.max_armor,
			"armor_type": z.armor_type, "armor_name": z.armor_name,
			"speed": z.speed, "slow_t": z.slow_t, "slow": z.slow_amount,
			"vuln_t": z.vuln_t, "vuln": z.vuln, "burn_t": z.burn_t,
			"burn_dps": z.burn_dps, "vaulted": z.vaulted,
			"split_done": z.split_done,
		})
	var orb_rows: Array = []
	for orb in orbs:
		if bool(orb["dead"]):
			continue
		orb_rows.append({
			"x": orb["x"], "y": orb["y"], "target_y": orb["target_y"],
			"landed": orb["landed"], "life": orb["life"], "value": orb["value"],
		})
	var mower_rows: Array = []
	for mower in mowers:
		mower_rows.append({"ready": mower["ready"]})
	var cooldowns: Dictionary = {}
	for card in cards:
		cooldowns[card["id"]] = card["cd"]
	return {
		"level_id": level_id, "rows": rows, "time": time, "sun": sun,
		"wave_index": wave_index, "kills": kills, "plants_lost": plants_lost,
		"difficulty": difficulty, "count_mul": count_mul, "hp_mul": hp_mul,
		"plants": plant_rows, "lilies": lily_rows, "zombies": zombie_rows,
		"orbs": orb_rows, "mowers": mower_rows, "cooldowns": cooldowns,
		"cards": cards.map(func(c): return String(c["id"])),
		"spawn_queue": spawn_queue.duplicate(true),
		"training": training, "no_cooldown": no_cooldown,
	}


func restore(data: Dictionary) -> void:
	var lvl = Content.get_level(int(data.get("level_id", 1)))
	setup(lvl, data.get("cards", []), String(data.get("difficulty", "easy")))
	time = float(data.get("time", 0.0))
	sun = int(data.get("sun", 100))
	wave_index = int(data.get("wave_index", 0))
	kills = int(data.get("kills", 0))
	plants_lost = int(data.get("plants_lost", 0))
	count_mul = float(data.get("count_mul", count_mul))
	hp_mul = float(data.get("hp_mul", hp_mul))
	training = bool(data.get("training", false))
	no_cooldown = bool(data.get("no_cooldown", false))
	spawn_queue = data.get("spawn_queue", []).duplicate(true)
	var cooldowns: Dictionary = data.get("cooldowns", {})
	for card in cards:
		card["cd"] = float(cooldowns.get(card["id"], 0.0))
	for row_data in data.get("lilies", []):
		var lily = place_free("lily", int(row_data["c"]), int(row_data["r"]))
		if lily != null:
			lily.hp = float(row_data.get("hp", lily.hp))
	for row_data in data.get("plants", []):
		var plant = place_free(String(row_data["type"]), int(row_data["c"]),
			int(row_data["r"]))
		if plant == null:
			continue
		plant.hp = float(row_data.get("hp", plant.hp))
		plant.shell = float(row_data.get("shell", 0.0))
		plant.shell_max = float(Upgrades.EFFECTS["shell"]["hp"])
		plant.timer = float(row_data.get("timer", 0.0))
		plant.armed = bool(row_data.get("armed", false))
		plant.arm_t = float(row_data.get("arm_t", 0.0))
		plant.chew_t = float(row_data.get("chew_t", 0.0))
		plant.chew_max = float(row_data.get("chew_max", 0.0))
		var upgrades: Dictionary = row_data.get("up", {})
		for key in upgrades:
			plant.upgrades[int(key)] = int(upgrades[key])
	refresh_plant_buffs()
	for row_data in data.get("zombies", []):
		var z = spawn_zombie(String(row_data["type"]), int(row_data["r"]),
			{"x": float(row_data["x"]), "hp_factor": 1.0})
		if z == null:
			continue
		z.hp = float(row_data.get("hp", z.hp))
		z.max_hp = float(row_data.get("max_hp", z.max_hp))
		z.armor = float(row_data.get("armor", z.armor))
		z.max_armor = float(row_data.get("max_armor", z.max_armor))
		z.armor_type = String(row_data.get("armor_type", z.armor_type))
		z.armor_name = String(row_data.get("armor_name", z.armor_name))
		z.speed = float(row_data.get("speed", z.speed))
		z.slow_t = float(row_data.get("slow_t", 0.0))
		z.slow_amount = float(row_data.get("slow", 0.0))
		z.vuln_t = float(row_data.get("vuln_t", 0.0))
		z.vuln = float(row_data.get("vuln", 0.0))
		z.burn_t = float(row_data.get("burn_t", 0.0))
		z.burn_dps = float(row_data.get("burn_dps", 0.0))
		z.vaulted = bool(row_data.get("vaulted", false))
		z.split_done = bool(row_data.get("split_done", false))
	orbs.clear()
	for row_data in data.get("orbs", []):
		orbs.append({
			"x": row_data["x"], "y": row_data["y"],
			"target_y": row_data["target_y"], "landed": row_data["landed"],
			"life": row_data["life"], "value": row_data["value"],
			"phase": 0.0, "dead": false, "auto_t": 0.0,
		})
	var saved_mowers: Array = data.get("mowers", [])
	for i in mini(saved_mowers.size(), mowers.size()):
		mowers[i]["ready"] = bool(saved_mowers[i]["ready"])
		mowers[i]["active"] = false
		mowers[i]["x"] = Geo.MOWER_X
