extends RefCounted
## 河埠到冥判窟的地图事件。时钟走战斗时间；独立随机流不扰动现有出怪抽签。
const Geo = preload("res://scripts/geo.gd")
const Content = preload("res://data/content.gd")
const DOCK_ROWS := [1, 4]
const CHANNEL_ROWS := [1, 3]
const WET_ROWS := [0, 1, 4, 5]
const BRIDGE_COLS := [[4, 6, 7], [6, 7]]
const FIRST_WATER := [7, 8, 9, 9, 8, 7]
const TIMBER_GUEST := "timber-bearer"

var owner: WeakRef
var rng := RandomNumberGenerator.new()
var state: Dictionary = {}

func _init(sim) -> void:
	owner = weakref(sim)

func setup() -> void:
	var s = owner.get_ref()
	rng.seed = hash("shore:%d:%d" % [s.level_id, int(s.level.get("fixed_seed", 0))])
	state = {"cargo": [], "boats": [], "next_cargo": false, "mats": [], "flow": 0,
		"flow_at": -1.0, "flow_next": 1, "wet": true, "tide_previous_stayed": false,
		"tide_at": -1.0, "tide_next": true, "tide_anim": -10.0, "tide_lane": -1, "short_group": -1,
		"fog_at": -1.0, "fog_until": -1.0, "fog_col": 5, "fog_old_until": -1.0, "fog_old_col": 5,
		"fog_notice": -1.0, "fog_next_col": 5, "gate_row": -1, "gate_start": -10.0, "gate_until": -10.0,
		"gate_ready": 0.0, "bridges": [], "wood": 0, "timber_dropped": [], "group": -1}
	match map_key():
		"market":
			var slots: Array = []
			for row in s.rows:
				for col in range(5, 9):
					if s.tiles[row][col].kind == "blocked":
						state.cargo.append({"col": col, "row": row, "removed": false})
					else: slots.append(Vector2i(col, row))
			for i in mini(slots.size(), 2):
				var cell: Vector2i = slots.pop_at(rng.randi_range(0, slots.size() - 1))
				state.cargo.append({"col": cell.x, "row": cell.y, "removed": false})
			sync_tiles()
		"water":
			for row in CHANNEL_ROWS:
				var ends: Array = []
				for cols in [range(1, 4), range(7, 4, -1)]:
					for col in cols:
						if s.tiles[row][col].kind == "water":
							ends.append(col)
							break
				if ends.size() == 2:
					state.mats.append({"row": row, "ends": ends, "current": 0, "to": 0, "start": -2.0, "end": -1.0, "uid": ""})
		"cavern":
			for row in BRIDGE_COLS.size():
				for col in BRIDGE_COLS[row]:
					if s.tiles[row][col].kind == "pit":
						state.bridges.append({"col": col, "row": row, "intact": true, "at": -10.0})
			sync_tiles()

func map_key() -> String:
	return String(owner.get_ref().level.get("map", ""))

func sync_tiles() -> void:
	var s = owner.get_ref()
	match map_key():
		"market":
			for c in state.cargo:
				s.tiles[int(c.row)][int(c.col)] = {"kind": "land" if c.removed else "blocked", "obj": 0, "water": ""}
		"cavern":
			for b in state.bridges:
				s.tiles[int(b.row)][int(b.col)] = {"kind": "bridge" if b.intact else "pit", "obj": 0, "water": ""}

func save() -> Dictionary:
	return {"state": state, "rng": str(rng.state)}

func restore(data: Dictionary, _wave_count: int) -> void:
	if data.has("state"):
		state.merge(Dictionary(data.state).duplicate(true), true)
		rng.state = int(data.get("rng", str(rng.state)))
	else:
		# Old mid-battle saves keep their original terrain until the next run.
		state["legacy"] = true
		state.cargo.clear(); state.mats.clear(); state.bridges.clear()
		var s = owner.get_ref()
		s.tiles = s._make_tiles()
	sync_tiles()

func enabled() -> bool:
	return not bool(state.get("legacy", false)) and map_key() in ["market", "water", "island", "cavern"]

func boss_group(group: int) -> bool:
	var s = owner.get_ref()
	if s.training or s.tutorial != null: return false
	return (String(s.level.get("boss_id", "")) != "" and group == int(s.level.get("wave_groups", 0)) - 1) or (String(s.level.get("mid_boss", "")) != "" and group == 3)

func on_batch(index: int) -> void:
	if not enabled(): return
	var s = owner.get_ref()
	var group: int = index / 3
	var sub := index % 3
	state.group = group
	match map_key():
		"market":
			if sub == 0 and not boss_group(group):
				var row: int = DOCK_ROWS[rng.randi_range(0, 1)]
				state.boats.append({"row": row, "cargo": bool(state.next_cargo), "phase": "in", "at": s.time,
					"until": s.time + 3.0, "haul": {}, "reward": 0})
				state.next_cargo = not bool(state.next_cargo)
		"water":
			var cycle: int = int(state.flow_next)
			if index + 1 >= ceili(4.5 * cycle):
				state.flow_next = cycle + 1
				state.flow_at = s.time + 6.0
				s.sfx("wave")
		"island":
			if sub == 0:
				state.fog_notice = s.time + 5.0
				state.fog_next_col = rng.randi_range(5, 6)
			if sub == 1:
				var wet := bool(state.wet)
				var next := wet if group == 0 else (not wet if group == 1 or bool(state.tide_previous_stayed) else bool(rng.randi_range(0, 1)))
				state.tide_previous_stayed = next == wet
				if next != wet:
					state.tide_at = s.time + 8.0
					state.tide_next = next
					state.tide_lane = [0, 5][rng.randi_range(0, 1)] if not next else -1
		"cavern":
			if sub == 0 and group in [2, 5]:
				var standing: Array = state.bridges.filter(func(b): return bool(b.intact))
				if not standing.is_empty():
					var b: Dictionary = standing[rng.randi_range(0, standing.size() - 1)]
					b.intact = false; b.at = s.time
					sync_tiles()
					s.sfx("armor_break")
			if sub == 2 and group in [3, 6] and int(s.level.get("wave_groups", 0)) > group + 1:
				var row: int = rng.randi_range(0, 1)
				s.spawn_queue.append({"type": TIMBER_GUEST, "row": row, "wave_no": index, "t": s.time + .75, "boss_wave": false, "shore_timber": true})

## 首次回流挑同一批来客在两条渠入场，保留本批总耐久预算。
func pair_first_current(entries: Array, index: int) -> void:
	if index != 4 or not enabled() or map_key() != "water" or float(state.flow_at) < 0: return
	var swimmers := entries.filter(func(entry):
		var guest: Dictionary = Content.ZOMBIES.get(String(entry.type), {})
		return guest.get("tier", "h") != "h" and not guest.get("land_only", false) and not guest.get("large", false))
	if swimmers.is_empty(): return
	if swimmers.size() == 1:
		var twin: Dictionary = swimmers[0].duplicate()
		twin.mass_scale = float(twin.get("mass_scale", 1.0)) * .5
		swimmers[0].mass_scale = twin.mass_scale
		swimmers.append(twin); entries.append(twin)
	var when := maxf(float(state.flow_at), maxf(float(swimmers[0].t), float(swimmers[1].t)))
	for i in CHANNEL_ROWS.size():
		swimmers[i].row = CHANNEL_ROWS[i]
		swimmers[i].t = when + i * .12

func tick() -> void:
	if not enabled(): return
	var s = owner.get_ref()
	match map_key():
		"market": _step_boats(s)
		"water":
			if float(state.flow_at) >= 0 and s.time >= float(state.flow_at):
				state.flow_at = -1.0
				state.flow = -1 if int(state.flow) > 0 else 1
			for mat in state.mats: _step_mat(s, mat)
		"island":
			if float(state.fog_notice) >= 0 and s.time >= float(state.fog_notice):
				state.fog_notice = -1.0
				state.fog_old_col = state.fog_col; state.fog_old_until = state.fog_until
				state.fog_col = state.fog_next_col
				state.fog_at = s.time; state.fog_until = s.time + 25.0
			if float(state.tide_at) >= 0 and s.time >= float(state.tide_at):
				state.tide_at = -1.0
				state.wet = bool(state.tide_next)
				state.tide_anim = s.time
				state.short_group = int(state.group) if not state.wet else -1
				s.sfx("splash")

func _step_boats(s) -> void:
	var active: Array = []
	for b in state.boats:
		var row := int(b.row)
		match String(b.phase):
			"in":
				if s.time >= float(b.until): b.phase = "wait"; b.at = s.time; b.until = s.time + 8.0
			"wait":
				var occupied: bool = s.zombies.any(func(z): return z.alive() and z.row == row and z.pos.x >= Geo.BOARD_X + Geo.CELL_W * 7 and z.pos.x <= Geo.BOARD_X + Geo.BOARD_W + 15)
				if not occupied and s.time <= float(b.until):
					b.phase = "dock"; b.at = s.time; b.until = s.time + 1.0
				elif s.time >= float(b.until):
					b.phase = "leave"; b.at = s.time; b.until = s.time + 2.4
			"dock":
				if s.time >= float(b.until):
					if bool(b.cargo):
						var cargo: Array = state.cargo.filter(func(c): return not c.removed and not c.has("hauled_at"))
						if not cargo.is_empty():
							var item: Dictionary = cargo[rng.randi_range(0, cargo.size() - 1)]
							item.hauled_at = s.time
							b.haul = {"col": item.col, "row": item.row}
					else:
						b.reward = s.gain_incense(300)
						s.float_text(Vector2(Geo.BOARD_X + Geo.BOARD_W - 34, s.row_y(row) - 55), "香船卸香 · %d" % int(b.reward), Color("#f4c87d"), 19, 1.5)
					b.phase = "unload"; b.at = s.time; b.until = s.time + 1.25
			"unload":
				if s.time >= float(b.until):
					if not b.haul.is_empty():
						for item in state.cargo:
							if item.col == b.haul.col and item.row == b.haul.row: item.removed = true
						sync_tiles()
					b.phase = "leave"; b.at = s.time; b.until = s.time + 2.4
			"leave":
				if s.time >= float(b.until): continue
		active.append(b)
	state.boats = active

func mat_on(col: int, row: int) -> Dictionary:
	if not enabled() or map_key() != "water": return {}
	for m in state.mats:
		if int(m.row) == row and int(m.ends[int(m.current)]) == col: return m
	return {}

func transit(plant) -> bool:
	if not enabled() or map_key() != "water": return false
	var s = owner.get_ref()
	return state.mats.any(func(m): return m.uid == plant.uid and float(m.end) > s.time)

func _step_mat(s, m: Dictionary) -> void:
	if float(m.end) < 0.0: return
	var row := int(m.row)
	var current := int(m.ends[int(m.current)])
	var dest := int(m.ends[int(m.to)])
	var plant = s.main_plant_at(current, row)
	if plant == null or plant.uid != m.uid or plant.dead: plant = null
	var f := smoothstep(0.0, 1.0, (s.time - float(m.start)) / maxf(.001, float(m.end) - float(m.start)))
	if plant != null: plant.pos = s.cell_pos(current, row).lerp(s.cell_pos(dest, row), f)
	if s.time >= float(m.end):
		if s.main_plant_at(dest, row) == null and s.lily_at(dest, row) == null:
			m.current = m.to
			if plant != null:
				s.cells[row][current] = null; s.cells[row][dest] = plant
				plant.col = dest; plant.pos = s.cell_pos(dest, row)
		elif plant != null: plant.pos = s.cell_pos(current, row)
		m.end = -1.0; m.uid = ""

func moving_target(col: int, row: int) -> bool:
	if not enabled() or map_key() != "water": return false
	for m in state.mats:
		if int(m.row) == row and float(m.end) >= 0 and int(m.ends[int(m.to)]) == col: return true
	return false

func click(cell: Vector2i, point: Vector2 = Vector2.INF) -> bool:
	if not enabled() or cell.x < 0: return false
	var s = owner.get_ref()
	var col := cell.x; var row := cell.y
	if map_key() == "water":
		for m in state.mats:
			if int(m.row) != row or col != int(m.ends[1 - int(m.current)]): continue
			if float(m.end) >= 0 or s.main_plant_at(col, row) != null or s.lily_at(col, row) != null:
				s.deny("泊位还不能靠", s.cell_pos(col, row)); return true
			var plant = s.main_plant_at(int(m.ends[int(m.current)]), row)
			m.uid = "" if plant == null else plant.uid
			m.to = 1 - int(m.current); m.start = s.time; m.end = s.time + 1.55
			s.sfx("splash")
			return true
	elif map_key() == "cavern":
		for b in state.bridges:
			if int(b.col) != col or int(b.row) != row or b.intact: continue
			if point != Vector2.INF and absf(point.x-Geo.screen_cell_center(col,row,s.rows).x)>45: continue
			if int(state.wood) == 0:
				s.deny("缺少补桥用的木材", s.cell_pos(col,row)); return true
			state.wood = int(state.wood) - 1; b.intact = true; b.at = s.time
			sync_tiles(); s.sfx("upgrade")
			return true
		var foot := Geo.to_screen(Vector2(Geo.BOARD_X+8.0*Geo.CELL_W+9.0,s.row_y(row)),s.rows)
		if row < 4 and col in [7,8] and (point == Vector2.INF or (absf(point.x-foot.x)<34 and point.y<foot.y+23 and point.y>foot.y-63)):
			if s.time < float(state.gate_ready) or (s.boss != null and s.boss.alive()):
				s.deny("石闸尚不能落下", s.cell_pos(col, row)); return true
			state.gate_row = row; state.gate_start = s.time; state.gate_until = s.time + 5.0; state.gate_ready = s.time + 30.0
			s.sfx("armor_break")
			return true
	return false

func bridge_wood(z) -> void:
	if not enabled() or map_key() != "cavern" or z.type != TIMBER_GUEST or not z.shore_timber: return
	if z.wave_no in state.timber_dropped: return
	state.timber_dropped.append(z.wave_no)
	state.wood = int(state.wood) + 1
	var s = owner.get_ref()
	s.float_text(z.pos + Vector2(0, -35), "拾到补桥木材", Color("#ddbf90"), 19, 1.6)

func over_water(z, col: int) -> bool:
	if not enabled() or map_key() != "island" or z.boss_role != "" or z.row not in WET_ROWS: return false
	return bool(state.wet) and col >= int(FIRST_WATER[z.row])

func island_arrival(type: String, row: int, wave_no: int, _weights: Array) -> Array:
	if not enabled() or map_key() != "island" or type == "wave-herald": return [type, row, false]
	var col_type: Dictionary = Content.ZOMBIES.get(type, {})
	if row < 0 or row >= 6: return [type,row,false]
	var wet := bool(state.wet)
	if wet and row in WET_ROWS and not bool(col_type.get("water_only", false)) and (col_type.get("tier", "") == "h" or bool(col_type.get("land_only", false)) or bool(col_type.get("large", false))):
		# Do not force land specialists onto water. Aquatic arrivals replace their own lane's scheduled slot.
		var choices: Array = ["ghost", "reedboat"]
		type = choices[rng.randi_range(0, choices.size() - 1)]
	elif wet and row in WET_ROWS and wave_no >= 3 and not col_type.get("water_only", false) and rng.randf() < .22:
		type = "reedboat"
	elif (not wet or row not in WET_ROWS) and col_type.get("water_only", false):
		type = "ghost"
	var short: bool = wave_no >= 0 and not wet and row == int(state.tide_lane) and (int(state.short_group) >= 0 or int(state.get("short_batch", -1)) == wave_no)
	if short:
		state.short_group = -1
		state.short_batch = wave_no
	return [type, row, short]

func speed(z) -> float:
	if not enabled() or z.boss_role != "" or z.type == "wave-herald": return 1.0
	if z.type == "freight-yokel" and map_key() == "market":
		var s = owner.get_ref()
		var next := floori((z.pos.x - Geo.BOARD_X) / Geo.CELL_W) - 1
		if next >= 0 and next < 9 and s.tiles[z.row][next].kind == "blocked": return 1.35
	if z.type == "reef-haunter" and fogged(z): return 1.25
	if map_key() == "water" and z.row in CHANNEL_ROWS and z.water_entered and not owner.get_ref()._guest_airborne(z):
		return 1.2 if int(state.flow) * (1 if z.row == 1 else -1) > 0 else (.7 if int(state.flow) != 0 else 1.0)
	if map_key() == "island" and z.shore_short and not bool(state.wet) and z.pos.x >= Geo.BOARD_X + float(FIRST_WATER[z.row]) * Geo.CELL_W:
		return 1.5
	return 1.0

func stop_position(z, next_x: float) -> float:
	if not enabled() or map_key() != "cavern" or z.row != int(state.gate_row) or z.water_entered or z.boss_role != "": return next_x
	var s = owner.get_ref()
	if s.time >= float(state.gate_until) or s._guest_airborne(z): return next_x
	var line := Geo.BOARD_X + 8.0 * Geo.CELL_W + 9.0
	return maxf(next_x, line) if z.pos.x >= line else next_x

func fogged(z) -> bool:
	if not enabled() or map_key() != "island" or z.boss_role != "": return false
	var s = owner.get_ref()
	if s.time < float(state.fog_at) or s.time >= float(state.fog_until) or z.pos.x < Geo.BOARD_X + int(state.fog_col) * Geo.CELL_W: return false
	return not s.plants.any(func(p): return not p.dead and p.pos.distance_to(z.pos) <= Geo.CELL_W * 1.3)

func evade(z, delivery: String, true_sight: bool) -> bool:
	return not true_sight and z.revealed_tier == 0 and delivery in ["pea", "star", "drift", "lob", "homing"] and fogged(z) and rng.randf() < .5
