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
var guide_up := true
var theatre_encore_at := -1.0
var theatre_sequence := 0
var lamp_cutoffs: Array = [-100.0,-100.0,-100.0]
var lamp_cutoff_strengths: Array = [1.0,1.0,1.0]
var market_pair := -1
var market_last_at := -100.0
var market_count := 0
var market_all := false
var market_base_count := 0
var market_lane_cursor := 0
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
	var s = owner_ref.get_ref()
	var first := 0.0 if s != null and s.factor("cloud_immediate") > 0 else LIFT_FIRST
	var cycle := maxi(0, floori((clock - first) / LIFT_PERIOD) + 1)
	var next_at := first + cycle * LIFT_PERIOD
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
		"direction_a": target_a-from_a if moving else 1.0-2.0*target_a,
		"direction_b": target_b-from_b if moving else target_a-target_b,
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
	if deck_exposed(plant): return true
	var s = owner_ref.get_ref()
	return plant != null and not plant.dead and s != null and plant.def.get("role", "") == "产能" and s.factor("cloud_silence") == 0

func deck_exposed(plant) -> bool:
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
			if col in [6,7]: return "这里是斜巷，要留给过路的客人"
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
				s.sfx("bell"); s.banner = {"text": "云渡鸣铃 · 浮台即将升降", "t": 4.0, "max": 4.0}
			if state.moving and moving_cycle != state.cycle:
				moving_cycle = state.cycle
				s.sfx("guardian"); s._banyan_cache_at = -1.0; s._collector_cache_at = -1.0
		"theatre":
			var group := maxi(0, int(maxi(0, s.wave_index-1) / Content.WAVES_PER_GROUP))
			if event_group != group and s.wave_index > 0:
				event_group = group
				var encore: bool = s.factor("troupe_encore") > 0
				_begin_theatre(theatre_sequence if encore else group)
				theatre_encore_at = -1.0
				if encore:
					var waves: Array = s.level.get("waves", [])
					var next := (group + 1) * Content.WAVES_PER_GROUP
					var start := group * Content.WAVES_PER_GROUP
					if next < waves.size():
						var next_at: float = float(waves[next].t) + s.wave_time_offset
						theatre_encore_at = s.time + maxf(0.0, next_at-s.time)*.5
					elif start >= Content.WAVES_PER_GROUP and start < waves.size():
						theatre_encore_at = s.time + (float(waves[start].t)-float(waves[start-Content.WAVES_PER_GROUP].t))*.5
			elif theatre_encore_at >= 0.0 and s.time >= theatre_encore_at:
				theatre_encore_at = -1.0
				_begin_theatre(theatre_sequence)
		"ghostmarket":
			var last_batch: bool = s.wave_index > 0 and Content.is_flag_batch(s.wave_index-1)
			var group := maxi(0, int(maxi(0, s.wave_index-1) / Content.WAVES_PER_GROUP))
			if (last_batch and event_group != group) or (s.boss != null and s.boss.alive() and s.time-market_last_at >= 45.0):
				event_group = group; market_last_at = s.time
				begin_market(s.rng.randi_range(0, 2))
				s.sfx("bell"); s.banner = {"text": "三灯将明 · 六路客潮加剧" if market_all else "市灯将明 · 客潮循光而来", "t": 4.0, "max": 4.0}

func _begin_theatre(sequence: int) -> void:
	var s = owner_ref.get_ref()
	theatre_sequence = sequence + 1
	event_start = s.time
	event_mode = "guide" if sequence % 2 == 0 else "haste"
	event_pair = s.rng.randi_range(0, 2); guide_up = event_pair % 2 == 0; routed = 0; hastened = 0
	s.sfx("bell")
	s.banner = {"text": "巷灯转向 · 戏班将引客借道" if event_mode == "guide" else "催场锣起 · 巷中脚步将急", "t": 4.0, "max": 4.0}

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
	if s == null or s.level.get("map", "") != "ghostmarket" or not event_active() or market_all: return -1
	var draw: float = s.rng.randf()
	var pair := market_pair if draw < .5 else (market_pair + (1 if draw < .75 else 2)) % 3
	return pair*2 + s.rng.randi_range(0, 1)

## Three visible diagonal passages operate together; no per-event guest cap.
func passage_contains(z) -> bool:
	return z.pos.x >= Geo.BOARD_X+6*Geo.CELL_W and z.pos.x <= Geo.BOARD_X+8*Geo.CELL_W

func haste_applies(z) -> bool:
	var s = owner_ref.get_ref()
	return s != null and s.level.get("map", "") == "theatre" and event_mode == "haste" and event_active() and passage_contains(z) and z.boss_role.is_empty()

func haste_multiplier(z) -> float:
	return (2.0 if owner_ref.get_ref().factor("troupe_fervor") > 0 else 1.5) if haste_applies(z) else 1.0

func route_damage_multiplier() -> float:
	return .25 if owner_ref.get_ref().factor("troupe_fervor") > 0 else .5

func try_route(z) -> void:
	var s = owner_ref.get_ref()
	if s == null or s.level.get("map", "") != "theatre" or not event_active(): return
	if not z.boss_role.is_empty() or not z.carrier_uid.is_empty(): return
	if event_mode != "guide" or z.scene_route_active or is_equal_approx(z.scene_route_event,event_start): return
	if not passage_contains(z) or (z.row % 2 == 1) != guide_up: return
	# Only entrants take the full visible diagonal; never snap an existing guest sideways.
	if z.pos.x < Geo.BOARD_X+8*Geo.CELL_W-maxf(4,z.speed*.1):return
	z.scene_route_from = z.row; z.scene_route_to = z.row ^ 1
	z.scene_route_done = true; z.scene_route_active = true; z.scene_route_event = event_start
	z.scene_route_left = Geo.BOARD_X+6*Geo.CELL_W
	# Same endpoints as the silk path rendered on the deck.
	z.scene_route_right = Geo.BOARD_X+8*Geo.CELL_W
	z.scene_route_curved = true; routed += 1

func route_speed_factor(z) -> float:
	if not z.scene_route_active: return 1.0
	var width: float = route_right(z)-route_left(z)
	var f := clampf((route_right(z)-z.pos.x)/width,0,1)
	var slope: float = Geo.cell_h(6)/width * (6*f*(1-f) if z.scene_route_curved else 1.0)
	return 1.0/sqrt(1.0+slope*slope)

func route_left(z) -> float:
	return z.scene_route_left if z.scene_route_right > z.scene_route_left else Geo.BOARD_X+6*Geo.CELL_W

func route_right(z) -> float:
	return z.scene_route_right if z.scene_route_right > z.scene_route_left else Geo.BOARD_X+7*Geo.CELL_W

func step_route(z) -> void:
	if not z.scene_route_active: return
	var f := clampf((route_right(z)-z.pos.x)/(route_right(z)-route_left(z)),0,1)
	var blend := smoothstep(0,1,f) if z.scene_route_curved else f
	z.pos.y = lerpf(Geo.row_y(z.scene_route_from,6),Geo.row_y(z.scene_route_to,6),blend)
	z.row = z.scene_route_from if f < .5 else z.scene_route_to
	if z.pos.x <= route_left(z):
		z.row = z.scene_route_to; z.pos.y = Geo.row_y(z.row,6); z.scene_route_active = false
		if z.type=="curtain-effigy":z.guest_action_at=owner_ref.get_ref().time

func begin_market(pair: int) -> void:
	var s = owner_ref.get_ref()
	if s.time-event_start>=7.2 and s.time-event_start<20.9:
		for old_pair in 3:
			if market_all or old_pair == market_pair:
				lamp_cutoff_strengths[old_pair]=float(lamp_pose(old_pair).light)
				lamp_cutoffs[old_pair]=s.time
	market_count += 1
	market_all = s.factor("lamp_crowd") > 0 and market_count % 3 == 0
	market_base_count = 0
	market_lane_cursor = pair * 2
	market_pair=pair;event_start=s.time

func triple_market_active() -> bool:
	var s = owner_ref.get_ref()
	return s != null and s.level.get("map", "") == "ghostmarket" and market_all and event_active()

func next_market_lane() -> int:
	var row := market_lane_cursor % 6
	market_lane_cursor += 1
	return row

func market_ward_multiplier(z) -> float:
	var s = owner_ref.get_ref()
	if s == null or s.level.get("map", "") != "ghostmarket" or s.factor("lamp_ward") == 0 or not event_active(): return 1.0
	if not z.boss_role.is_empty(): return 1.0
	return .8 if market_all or int(z.row / 2) == market_pair else 1.0

## All five lamp clips share a fixed stone-foot anchor. One-shot clips clamp.
func lamp_pose(pair: int) -> Dictionary:
	var s = owner_ref.get_ref()
	var elapsed: float = s.time-event_start
	var fade: float=s.time-float(lamp_cutoffs[pair])
	if fade>=0 and fade<.9:
		var intensity:float=clampf(float(lamp_cutoff_strengths[pair]),0,1)
		return {"clip":"extinguish","key":minf(3.875,(1-intensity+intensity*fade/.9)*3.875),"light":intensity*(1.0-smoothstep(0,.9,fade))}
	if (not market_all and pair != market_pair) or elapsed < 0:
		return {"clip":"dark","key":fposmod(s.time*.8+pair,4),"light":0.0}
	if elapsed < 7.2: return {"clip":"warning","key":fposmod(elapsed*2,4),"light":.13+.09*sin(elapsed*5)}
	if elapsed < 8: return {"clip":"ignite","key":minf(3.875,(elapsed-7.2)/.8*3.875),"light":smoothstep(7.2,8,elapsed)}
	if elapsed < 20: return {"clip":"lit","key":fposmod(elapsed*1.8,4),"light":.90+.1*sin(elapsed*4)}
	if elapsed < 20.9: return {"clip":"extinguish","key":minf(3.875,(elapsed-20)/.9*3.875),"light":1.0-smoothstep(20,20.9,elapsed)}
	return {"clip":"dark","key":fposmod(s.time*.8+pair,4),"light":0.0}

func serialize() -> Dictionary:
	return {"warned_cycle": warned_cycle, "moving_cycle": moving_cycle, "event_group": event_group,
		"event_start": event_start, "guide_up": guide_up, "event_mode": event_mode, "event_pair": event_pair,
		"theatre_encore_at": theatre_encore_at, "theatre_sequence": theatre_sequence,
		"market_count": market_count, "market_all": market_all, "market_base_count": market_base_count, "market_lane_cursor": market_lane_cursor,
		"market_pair": market_pair, "lamp_cutoffs": lamp_cutoffs, "lamp_cutoff_strengths": lamp_cutoff_strengths, "market_last_at": market_last_at, "routed": routed, "hastened": hastened}

func restore(data: Dictionary) -> void:
	for key in serialize():
		if data.has(key): set(key, data[key])
