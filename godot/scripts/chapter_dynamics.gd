## Chapter terrain uses the battle clock, including warning/movement and saved routes.
## Rendering only reads these states; pausing and speed changes cannot desynchronise it.
extends RefCounted

const LIFT_DURATION := 2.4
const LIFT_FIRST := 70.0
const LIFT_PERIOD := 40.0
const WARNING := 8.0
const SLIDE_PERIOD := 30.0
const SLIDE_DURATION := 3.0
var owner_ref: WeakRef
var warned_cycle := -1
var moving_cycle := -1
var event_group := -1
var event_start := -100.0
var event_mode := ""
var event_pair := 0
var market_pair := -1
var market_last_at := -100.0
var routed := 0
var hastened := 0

func _init(owner) -> void:
	owner_ref = weakref(owner)

func platform_group(col: int, row: int) -> int:
	var s = owner_ref.get_ref()
	var clock: float = s.time if s != null else 0.0
	for group in 2:
		var start := platform_start(group,clock)
		if row >= int(start.y) and row < int(start.y)+3 and col+.5 >= start.x and col+.5 < start.x+4: return group
	return -1

func platform_start(group: int, clock: float) -> Vector2:
	var state := slide_state(clock)
	return Vector2(state.offset,0) if group==0 else Vector2(2.0-state.offset,3)

func slide_state(clock: float) -> Dictionary:
	var cycle := floori(clock/SLIDE_PERIOD)
	var since := fposmod(clock,SLIDE_PERIOD)
	var moving := cycle > 0 and since < SLIDE_DURATION
	var target: float = 2.0 * (cycle % 2)
	var offset := lerpf(2.0-target,target,smoothstep(0.0,SLIDE_DURATION,since)) if moving else target
	return {"cycle":cycle,"moving":moving,"offset":offset,"next_at":(cycle+1)*SLIDE_PERIOD}

func lift_state(clock: float) -> Dictionary:
	var cycle := maxi(0, floori((clock - LIFT_FIRST) / LIFT_PERIOD) + 1)
	var next_at := LIFT_FIRST + cycle * LIFT_PERIOD
	var since := clock - (next_at - LIFT_PERIOD)
	var moving := cycle > 0 and since < LIFT_DURATION
	var blend := smoothstep(0.0, LIFT_DURATION, since) if moving else 1.0
	var target_a := 1.0 if cycle % 2 == 0 else 0.0
	var target_b := 1.0 if cycle == 0 else 1.0-target_a
	var from_a := 1.0 if cycle <= 1 else 1.0-target_a
	var from_b := 1.0 if cycle <= 1 else 1.0-target_b
	var a := lerpf(from_a,target_a,blend)
	var b := lerpf(from_b,target_b,blend)
	return {"cycle": cycle, "next_at": next_at, "warning": clock >= next_at - WARNING,
		"moving": moving, "progress": blend, "a": a, "b": b,
		"a_ready":a>.999 and not (moving and from_a!=target_a),
		"b_ready":b>.999 and not (moving and from_b!=target_b)}

func plant_elevation(plant) -> float:
	var s = owner_ref.get_ref()
	if s == null or plant.cloud_group < 0: return 1.0
	var state := lift_state(s.time)
	return float(state.a if plant.cloud_group == 0 else state.b)

func elevation(col: int, row: int) -> float:
	var s = owner_ref.get_ref()
	if s == null or s.level.get("map", "") != "sky": return 1.0
	var group := platform_group(col, row)
	if group < 0: return 1.0
	var state := lift_state(s.time)
	return float(state.a if group == 0 else state.b)

func present(plant) -> bool:
	var s = owner_ref.get_ref()
	if plant == null or plant.dead: return false
	if s == null or s.level.get("map", "") != "sky": return true
	if plant.cloud_group < 0: return true
	var state := lift_state(s.time)
	return bool(state.a_ready if plant.cloud_group==0 else state.b_ready)

func placement(col: int, row: int) -> String:
	var s = owner_ref.get_ref()
	if s == null: return ""
	match String(s.level.get("map", "")):
		"sky":
			if col >= 6: return ""
			if platform_group(col, row) < 0: return "这里没有浮台，不能安置草木"
		"theatre":
			if col == 6: return "这里是斜巷，要留给过路的客人"
	return ""

func tick(_dt: float) -> void:
	var s = owner_ref.get_ref()
	if s == null: return
	match String(s.level.get("map", "")):
		"sky":
			sync_platforms()
			var state := lift_state(s.time)
			if state.warning and warned_cycle != state.cycle:
				warned_cycle = state.cycle
				s.sfx("bell"); s.banner = {"text": "铜铃将歇 · 云台即将换位", "t": 4.0, "max": 4.0}
			if state.moving and moving_cycle != state.cycle:
				moving_cycle = state.cycle
				s.sfx("guardian"); s._banyan_cache_at = -1.0; s._collector_cache_at = -1.0
		"theatre":
			var group := maxi(0, int(maxi(0, s.wave_index-1) / Content.WAVES_PER_GROUP))
			if event_group != group and s.wave_index > 0:
				event_group = group; event_start = s.time
				event_mode = "guide" if group % 2 == 0 else "haste"
				event_pair = s.rng.randi_range(0, 2); routed = 0; hastened = 0
				s.sfx("bell")
				s.banner = {"text": "巷灯转向 · 戏班将引客借道" if event_mode == "guide" else "催场锣起 · 这两路脚步将急", "t": 4.0, "max": 4.0}
		"ghostmarket":
			var last_batch: bool = s.wave_index > 0 and Content.is_flag_batch(s.wave_index-1)
			var group := maxi(0, int(maxi(0, s.wave_index-1) / Content.WAVES_PER_GROUP))
			if (last_batch and event_group != group) or (s.boss != null and s.boss.alive() and s.time-market_last_at >= 45.0):
				event_group = group; market_last_at = s.time; event_start = s.time
				market_pair = s.rng.randi_range(0, 2)
				s.sfx("bell"); s.banner = {"text": "市灯将明 · 客潮循光而来", "t": 4.0, "max": 4.0}

func attach(plant) -> void:
	var s = owner_ref.get_ref()
	if s == null or s.level.get("map","")!="sky": return
	plant.cloud_group = platform_group(plant.col,plant.row)
	if plant.cloud_group < 0: return
	var start := platform_start(plant.cloud_group,s.time)
	plant.cloud_cell = roundi(plant.col-start.x)
	_position_plant(plant)

func _position_plant(plant) -> void:
	var s = owner_ref.get_ref()
	var start := platform_start(plant.cloud_group,s.time)
	plant.col = roundi(start.x+plant.cloud_cell)
	plant.pos.x = Geo.BOARD_X+(start.x+plant.cloud_cell+.5)*Geo.CELL_W
	plant.cloud_drop = (1.0-plant_elevation(plant))*38.0
	plant.cloud_scale = 1.0-(1.0-plant_elevation(plant))*.08

func sync_platforms() -> void:
	var s = owner_ref.get_ref()
	if s == null or s.level.get("map","")!="sky": return
	for plant in s.plants:
		if plant.cloud_group<0 or plant.dead:continue
		if s.cells[plant.row][plant.col]==plant:s.cells[plant.row][plant.col]=null
	for plant in s.plants:
		if plant.cloud_group<0 or plant.dead:continue
		_position_plant(plant)
		s.cells[plant.row][plant.col]=plant
	for row in 6:
		for col in 6:s.tiles[row][col].kind="cloud-platform" if platform_group(col,row)>=0 else "walkway"

func pick_cell(point: Vector2) -> Vector2i:
	var s = owner_ref.get_ref()
	if s == null or s.level.get("map","")!="sky": return Geo.screen_cell_at(point,s.rows if s!=null else 6)
	var state := lift_state(s.time)
	# Inverse-project each moving surface, including the visible lower cloud deck.
	var order: Array = [0,1] if float(state.a)>=float(state.b) else [1,0]
	for group in order:
		var start := platform_start(group,s.time)
		var drop: float = (1.0-float(state.a if group==0 else state.b))*38.0
		var flat := Geo.to_flat(point-Vector2(0,drop),s.rows)
		var local_x: float = (flat.x-Geo.BOARD_X)/Geo.CELL_W-start.x
		var row := floori((flat.y-Geo.BOARD_Y)/Geo.cell_h(s.rows))
		if row>=int(start.y) and row<int(start.y)+3 and local_x>=0 and local_x<4:
			return Vector2i(roundi(start.x+floori(local_x)),row)
	var cell := Geo.screen_cell_at(point,s.rows)
	return cell if cell.x>=6 else Vector2i(-1,-1)

func cell_polygon(col: int,row: int) -> PackedVector2Array:
	var s = owner_ref.get_ref()
	var corners := Geo.screen_cell_polygon(col,row,s.rows)
	if s.level.get("map","")!="sky": return corners
	var group := platform_group(col,row)
	if group<0:return corners
	var start := platform_start(group,s.time)
	var local := roundi(col-start.x)
	var x: float = Geo.BOARD_X+(start.x+local)*Geo.CELL_W
	var y: float = Geo.BOARD_Y+row*Geo.cell_h(s.rows)
	var drop: float = (1.0-elevation(col,row))*38.0
	var offset := Vector2(0,drop)
	return PackedVector2Array([Geo.to_screen(Vector2(x,y),s.rows)+offset,
		Geo.to_screen(Vector2(x+Geo.CELL_W,y),s.rows)+offset,
		Geo.to_screen(Vector2(x+Geo.CELL_W,y+Geo.cell_h(s.rows)),s.rows)+offset,
		Geo.to_screen(Vector2(x,y+Geo.cell_h(s.rows)),s.rows)+offset])

func event_active() -> bool:
	var s = owner_ref.get_ref()
	return s != null and s.time-event_start >= (8.0 if s.level.get("map", "") == "ghostmarket" else 6.0) and s.time-event_start < (20.0 if s.level.get("map", "") == "ghostmarket" else 18.0)

func spawn_row() -> int:
	var s = owner_ref.get_ref()
	if s == null or s.level.get("map", "") != "ghostmarket" or not event_active(): return -1
	var draw: float = s.rng.randf()
	var pair := market_pair if draw < .5 else (market_pair + (1 if draw < .75 else 2)) % 3
	return pair*2 + s.rng.randi_range(0, 1)

func try_route(z) -> void:
	var s = owner_ref.get_ref()
	if s == null or s.level.get("map", "") != "theatre" or not event_active(): return
	if z.is_large() or z.boss_role != "" or bool(z.def.get("flying_tool", false)): return
	if int(z.row/2) != event_pair or z.scene_route_done: return
	var right: float = Geo.BOARD_X + 7*Geo.CELL_W
	var left: float = Geo.BOARD_X + 6*Geo.CELL_W
	if z.pos.x > right or z.pos.x < left: return
	if event_mode == "guide" and routed < 4:
		z.scene_route_from = z.row; z.scene_route_to = z.row ^ 1
		z.scene_route_done = true; z.scene_route_active = true; routed += 1
	elif event_mode == "haste" and hastened < 6:
		z.scene_haste_until = s.time + 8.0; z.scene_route_done = true; hastened += 1

func step_route(z) -> void:
	if not z.scene_route_active: return
	var right: float = Geo.BOARD_X + 7*Geo.CELL_W
	var left: float = Geo.BOARD_X + 6*Geo.CELL_W
	var f := clampf((right - z.pos.x) / Geo.CELL_W, 0.0, 1.0)
	# Geometry is a visible diagonal through column seven, never a teleport.
	z.pos.y = lerpf(Geo.row_y(z.scene_route_from, 6), Geo.row_y(z.scene_route_to, 6), f)
	z.row = z.scene_route_from if f < .5 else z.scene_route_to
	if z.pos.x <= left:
		z.row = z.scene_route_to; z.pos.y = Geo.row_y(z.row, 6); z.scene_route_active = false

func serialize() -> Dictionary:
	return {"warned_cycle": warned_cycle, "moving_cycle": moving_cycle, "event_group": event_group,
		"event_start": event_start, "event_mode": event_mode, "event_pair": event_pair,
		"market_pair": market_pair, "market_last_at": market_last_at, "routed": routed, "hastened": hastened}

func restore(data: Dictionary) -> void:
	for key in serialize():
		if data.has(key): set(key, data[key])
