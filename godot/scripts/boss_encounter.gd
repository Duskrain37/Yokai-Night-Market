## Deterministic encounter model. All clocks use Sim.time; View never deals damage.
extends RefCounted

var _owner: WeakRef
var sim:
	get:return _owner.get_ref() if _owner!=null else null
var encounter_slot := 0
var rate_scale := 1.0
var config: Dictionary = {}
var id = ""
var hp = 0.0
var max_hp = 0.0
var began_at = 0.0
var combat_at = 0.0
var died_at = -1.0
var state = "intro"
var state_end = 0.0
var small_at = 0.0
var adds_at = 0.0
var spawn_gate = 0.0
var major_queue: Array = []
var fired: Array = []
var action: Dictionary = {}
var effects: Array = []
var cell_cooldowns: Dictionary = {}
var repair_marks: Array = []
var body_targets: Array = []
var body_row := 0
var blink_from := -1
var blink_at := -10.0
var smalls_to_blink := 1
const BLINK_TIME := 0.48
const HEALTH_SCALE := 2.1
const SKILL_RATE := 5.0 / 3.0
const SKILL_FORCE := 2.0
const REINFORCEMENT_MASS := 1.0
const FINAL_WAVE_FIRST_CAST := 3
const FINAL_WAVE_CAST_INTERVAL := 6
var small_casts := 0
var reinforcement_index := 0
var props: Array = []
var destruction_used = 0
var supply_given = false
var alternate = 0
var last_lane = -1
var lane_streak = 0
var last_major_row = -1
var cc_log: Array = []
var stun_until = 0.0
var damage_token = ""
var hit_tokens: Dictionary = {}
var damage_carry: Dictionary = {}
var total_damage = 0.0
var add_count = 0
var peak_adds = 0
var major_count = 0
var last_boss_destroy_at = -1.0
var wave_end = 0
var major_wait_since = -1.0
var adds_were_paused = false
const EASY_HP_SCALE := 0.85

func begin(owner, boss_id: String, last_batch: int = -1, preserve_queue := false) -> void:
	_owner = weakref(owner)
	id = boss_id
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/boss_balance.json"))
	for row in data.bosses:
		if row.id == id:
			config = row.duplicate(true)
	# Boss is excluded from threat: only an explicit difficulty choice changes its HP.
	max_hp = float(config.max_hp) * EASY_HP_SCALE * float(sim.difficulty_mult()["hp"]) * HEALTH_SCALE
	rate_scale=float([1.0,1.5,2.0][sim.factor("boss_power")])
	max_hp*=rate_scale
	hp = max_hp
	began_at = sim.time
	combat_at = sim.time + 3.0
	state_end = combat_at
	small_at = combat_at + float(config.small_first_s) / (SKILL_RATE * rate_scale)
	adds_at = combat_at + 5.0
	wave_end = Array(sim.level.waves).size()
	if bool(sim.level.get("special",false)):wave_end=(sim.special_bosses_completed+1)*12
	if last_batch >= 0: wave_end = last_batch
	sim.wave_index = wave_end
	sim.last_group = int(wave_end/Content.WAVES_PER_GROUP)-1
	if not preserve_queue:
		sim.spawn_queue.clear()
		sim.pending_spawns.clear()
	body_row = clampi(int(sim.rows / 2) - 1, 0, sim.rows - 2)
	smalls_to_blink = sim.rng.randi_range(1, 2)
	_make_body_targets()
	sim.banner={"text":"恶首现身 · "+String(config.name), "group":int(wave_end/Content.WAVES_PER_GROUP),
		"groups":Content.wave_groups(sim.level),"t":3.0,"max":3.0,"ceremony":true}
	sim.sfx("boss_intro")

func _make_proxy(role: String,row: int,x: float,health: float,meta: Dictionary):
	var tagged:=meta.duplicate(true)
	tagged.encounter_slot=encounter_slot
	return sim.make_boss_proxy(role,row,x,health,tagged)

func set_body_row(row: int) -> void:
	body_row=row
	for i in body_targets.size():
		body_targets[i].row=row+i
		body_targets[i].pos.y=sim.row_y(row+i)+4.0

func _make_body_targets() -> void:
	for row in range(body_row, body_row + 2):
		body_targets.append(_make_proxy("body", row, body_x(), max_hp, {}))


func body_x() -> float:
	return Geo.BOARD_X + Geo.BOARD_W - 10.0


func _start_blink() -> void:
	var choices: Array[int] = []
	for row in sim.rows - 1:
		if row != body_row:
			var free:=true
			for other in sim.active_bosses():
				if other!=self and other.alive() and row<=other.body_row+1 and row+1>=other.body_row:free=false
			if free:choices.append(row)
	if choices.is_empty():
		state = "idle"
		return
	blink_from = body_row
	body_row = choices[sim.rng.randi_range(0, choices.size() - 1)]
	blink_at = sim.time
	for i in body_targets.size():
		var target = body_targets[i]
		target.row = body_row + i
		target.pos.y = sim.row_y(target.row) + 4.0
	smalls_to_blink = sim.rng.randi_range(1, 2)
	state = "blink"
	state_end = sim.time + BLINK_TIME


func alive() -> bool:
	return died_at < 0.0

func finished() -> bool:
	return died_at >= 0.0

func pose() -> String:
	if not alive(): return "defeat"
	if state == "blink": return "blink"
	if state == "major_warning" or state == "small_warning": return "anticipation"
	if state == "major_hits": return "major"
	if state == "small_recovery": return "small"
	if state == "recovery": return "hurt"
	return "idle"

func emit(kind: String, at: Vector2, extra: Dictionary = {}) -> void:
	var item: Dictionary={"kind":kind,"x":at.x,"y":at.y,"at":sim.time}
	item.merge(extra,true)
	effects.append(item)
	if effects.size()>96: effects.pop_front()

func _sync_hp() -> void:
	for z in body_targets:
		z.hp=hp
		z.max_hp=max_hp

func damage(proxy, amount: float, source: String = "", continuous := false) -> float:
	if not alive() or amount<=0: return 0.0
	if damage_token!="" and hit_tokens.has(damage_token): return 0.0
	if damage_token!="": hit_tokens[damage_token]=sim.time
	var damage_value = amount
	if proxy!=null and proxy.vuln_t>0: damage_value*=1.0+proxy.vuln
	if state=="recovery": damage_value*=1.25
	if damage_token.begins_with("percent:"):damage_value=minf(damage_value,max_hp*0.01)
	damage_value = Sim.quantized_damage(damage_carry, source, damage_value, continuous)
	if damage_token.begins_with("percent:"): damage_value = minf(damage_value, max_hp * .01)
	var before=hp
	var dealt=minf(hp,damage_value)
	hp=maxf(0,hp-dealt)
	total_damage+=dealt
	if source!="": sim.damage_by_type[source]=float(sim.damage_by_type.get(source,0.0))+dealt
	_sync_hp()
	if hp<=0:
		_die()
		return dealt
	for threshold in config.major_thresholds:
		if not fired.has(threshold) and before>max_hp*float(threshold) and hp<=max_hp*float(threshold):
			fired.append(threshold)
			major_queue.append(threshold)
	return dealt

func control(seconds: float,_proxy=null) -> void:
	if not alive(): return
	var keep: Array=[]
	var used=0.0
	for entry in cc_log:
		if float(entry[0])+10.0>sim.time:
			keep.append(entry);used+=float(entry[1])
	cc_log=keep
	var granted=minf(minf(seconds*0.25,0.75),1.5-used)
	if granted<0.01 or sim.time<stun_until: return
	cc_log.append([sim.time,granted])
	stun_until=sim.time+granted
	if state in ["major_warning","major_hits","small_warning"]:
		state_end+=granted
		if action.has("warning_end"):
			action.warning_end=float(action.warning_end)+granted

func tick(dt: float) -> void:
	effects=effects.filter(func(e):return float(e.at)+2.0>sim.time)
	repair_marks=repair_marks.filter(func(e):return float(e.until)>sim.time)
	if not alive(): return
	# A poison/burn status shared across both lanes of the same body cannot multiply by lane count.
	var burn=0.0;var bleed=0.0;var burn_source=""
	for z in body_targets:
		sim.update_marks(z,dt)
		z.hurt=maxf(0,z.hurt-dt)
		if z.vuln_t>0: z.vuln_t=maxf(0,z.vuln_t-dt)
		if z.burn_t>0:
			z.burn_t=maxf(0,z.burn_t-dt)
			if z.burn_dps>burn: burn=z.burn_dps;burn_source=z.burn_src
		if z.bleed_t>0: z.bleed_t=maxf(0,z.bleed_t-dt);bleed=maxf(bleed,z.bleed_dps)
		if z.bomb_t>0:
			z.bomb_t=maxf(0,z.bomb_t-dt)
			if z.bomb_t<=0:
				damage_token="percent:lobber:%d" % int(sim.time)
				damage(z,minf(z.bomb_damage,max_hp*0.01),"lobber")
				z.bomb_damage=0.0
	damage_token=""
	if burn>0: damage(null,burn*dt,burn_source,true)
	if bleed>0: damage(null,bleed*dt,"bell",true)
	if not alive(): return
	for z in sim.zombies:
		if z.alive() and z.boss_meta.has("portal_at") and sim.time>=float(z.boss_meta.portal_at):
			emit("earth",z.pos)
			z.pos.x=float(z.boss_meta.portal_x);z.boss_meta.erase("portal_at")
			emit("earth",z.pos)
	# Prune per-projectile de-dup keys once their actual projectile has left the simulation.
	var live_tokens: Dictionary={}
	for shot in sim.shots:
		if not shot.dead: live_tokens["shot:"+shot.uid]=true
	for key in hit_tokens.keys():
		if not live_tokens.has(key) and float(hit_tokens[key])+1.0<sim.time: hit_tokens.erase(key)
	var paused_adds=not major_queue.is_empty() or state in ["major_warning","major_hits","recovery","major_gap"]
	_update_props(dt,paused_adds)
	if not alive(): return
	if state=="intro":
		if sim.time>=combat_at:
			state="idle"
			supply_given = true
		return
	if sim.time<stun_until: return
	match state:
		"small_warning":
			if sim.time>=state_end:
				_resolve_small();state="small_recovery";state_end=sim.time+0.5
		"small_recovery":
			if sim.time >= state_end:
				smalls_to_blink -= 1
				if smalls_to_blink <= 0:
					_start_blink()
				else:
					state = "idle"
		"blink":
			if sim.time >= state_end:
				state = "idle"
		"major_warning":
			if sim.time>=state_end:state="major_hits"
		"major_hits":
			_resolve_major()
		"recovery":
			if sim.time>=state_end:state="major_gap";state_end=sim.time+1.0
		"major_gap":
			if sim.time>=state_end:
				state="idle";small_at=sim.time+float(config.small_period_s) / (SKILL_RATE * rate_scale)
		"idle":
			if not major_queue.is_empty():
				# Let an already telegraphed crab finish before the next destructive cast.
				var crabs=props.filter(func(z):return z.alive() and z.boss_role=="crab")
				if crabs.is_empty():
					major_wait_since=-1;major_queue.pop_front();_start_major()
				else:
					if major_wait_since<0:major_wait_since=sim.time
					if sim.time-major_wait_since>=3.0:
						for z in crabs:break_prop(z)
						major_wait_since=-1;major_queue.pop_front();_start_major()
			elif sim.time>=small_at:
				_start_small();small_at=sim.time+float(config.small_period_s) / (SKILL_RATE * rate_scale)
	if sim.time >= adds_at:
		_send_reinforcements()
	peak_adds=maxi(peak_adds,sim.active_zombies())


func _final_wave() -> Array:
	var waves: Array = sim.level["waves"]
	return waves.slice(maxi(0, wave_end - Content.WAVES_PER_GROUP), wave_end)


func _send_reinforcements() -> void:
	var waves: Array = sim.level["waves"]
	if waves.is_empty():
		return
	var first = maxi(0, wave_end - 12) if bool(sim.level.get("special", false)) else 0
	var count = mini(waves.size(), wave_end) - first
	if count <= 0:
		return
	var index = first + reinforcement_index % count
	var interval = 18.0
	if index + 1 < first + count:
		interval = float(waves[index + 1]["t"]) - float(waves[index]["t"])
	var mass_ratio = REINFORCEMENT_MASS * Content.wave_mass_ratio(sim.level, index)
	sim.queue_roster(waves[index], -1, mass_ratio, Content.wave_low_only(sim.level, index), true)
	reinforcement_index += 1
	adds_at = sim.time + interval * (0.75 if sim.factor("rush")>0 else 1.0)


func _spawn_add(role: String,source=null) -> bool:
	if not alive() or sim.time<spawn_gate or sim.active_zombies()>=int(config.adds.live_cap):return false
	var type="ghost"
	if role=="armor":type="straw"
	elif role!="light":
		var roll=sim.rng.randi_range(1,100)
		if roll>int(config.adds.weights.light)+int(config.adds.weights.armor):type="bucket"
		elif roll>int(config.adds.weights.light):type="straw"
	var lane=0;var best=100000
	for r in sim.rows:
		var count=0
		for z in sim.zombies:
			if z.alive() and z.boss_role!="body" and z.boss_role!="prop" and z.row==r:count+=1
		if r==last_lane and lane_streak>=2:count+=100
		if count<best or (count==best and sim.rng.randf()<0.5):best=count;lane=r
	if String(sim.level.get("map", ""))=="water" and source==null:
		lane=sim.choose_spawn_row(type)
		for attempt in 4:
			if lane!=last_lane or lane_streak<2:break
			lane=sim.choose_spawn_row(type)
	if source!=null:
		lane=source.row
		if lane==last_lane and lane_streak>=2:return false
	if lane==last_lane:lane_streak+=1
	else:last_lane=lane;lane_streak=1
	var z=sim.spawn_zombie(type,lane)
	if z==null:return false
	if source!=null and String(source.boss_meta.kind)=="tunnel" and int(source.boss_meta.c)>=5:
		z.boss_meta={"portal_at":sim.time+.45,"portal_x":source.pos.x+Geo.CELL_W*.48}
	spawn_gate=sim.time+1.5;add_count+=1
	return true

func _cell_ok(col: int,row: int,require_empty: bool=false) -> bool:
	if col<2 or col>=Geo.COLS or row<0 or row>=sim.rows:return false
	if String(sim.tile_at(col,row).kind) in ["blocked","object"]:return false
	if require_empty and (sim.main_plant_at(col,row)!=null or sim.lily_at(col,row)!=null):return false
	return sim.time>=float(cell_cooldowns.get("%d:%d" % [row,col],0.0))

func _target(col: int,row: int) -> Dictionary:
	cell_cooldowns["%d:%d" % [row,col]]=sim.time+6.0
	return {"c":col,"r":row}

func _random_cell(first: int,last: int,empty: bool=false) -> Dictionary:
	var pool: Array=[];var occupied: Array=[]
	for r in sim.rows:
		for c in range(first,last+1):
			if _cell_ok(c,r,empty):
				pool.append([c,r])
				if sim.main_plant_at(c,r)!=null:occupied.append([c,r])
	if not empty and not occupied.is_empty():pool=occupied
	if pool.is_empty():return {}
	var cell: Array=pool[sim.rng.randi_range(0,pool.size()-1)]
	return _target(int(cell[0]),int(cell[1]))

func _start_small() -> void:
	small_casts += 1
	var first_summon := int(config.get("summon_first_cast", FINAL_WAVE_FIRST_CAST))
	var summon_interval := int(config.get("summon_cast_interval", FINAL_WAVE_CAST_INTERVAL))
	if bool(config.get("summon_final", true)) and small_casts >= first_summon \
			and (small_casts - first_summon) % summon_interval == 0:
		action = {"kind": "summon_wave", "targets": [], "warning_start": sim.time,
			"warning_end": sim.time + 2.4, "hit": 0, "kills": 0}
		state = "small_warning"
		state_end = sim.time + 2.4
		sim.banner = {"text": "恶首号令 · 大批恶客来袭", "t": 2.4, "max": 2.4}
		sim.sfx("boss_warning")
		return
	var kind="tunnel" if id=="earth" else ("seal" if alternate%2==0 else "paper_ferry")
	if id=="river":kind="crab"
	var skill: Dictionary = config.get("small_skill", {})
	if not skill.is_empty():
		kind = String(skill.kind)
	alternate+=1
	var targets: Array=[]
	var warning=2.2
	if kind in ["tunnel", "paper_ferry"]:
		for index in 2:
			var cell := _random_cell(4 if kind == "tunnel" else 6, 7 if kind == "tunnel" else 8, kind == "paper_ferry")
			if not cell.is_empty():
				targets.append(cell)
		warning = 2.2 if kind == "tunnel" else 1.8
	else:
		warning=float(skill.get("warning", 1.8 if kind=="seal" else 2.0))
		var candidates: Array=[]
		for p in sim.plants:
			if not p.dead and not p.is_lily and not p.ash and p.col >= int(skill.get("first_column", 2)) and _cell_ok(p.col,p.row):candidates.append(p)
		var picked_rows: Array=[]
		var economy_chosen=false
		for i in int(skill.get("targets", 3 if kind=="seal" else 2)):
			var valid: Array=candidates.filter(func(p):return not picked_rows.has(p.row) and not (kind=="seal" and economy_chosen and p.def.has("produce")))
			if valid.is_empty():break
			var p=valid[sim.rng.randi_range(0,valid.size()-1)]
			targets.append(_target(p.col,p.row));picked_rows.append(p.row)
			if p.def.has("produce"):economy_chosen=true
	action={"kind":kind,"targets":targets,"warning_start":sim.time,"warning_end":sim.time+warning,"hit":0,"kills":0}
	state="small_warning";state_end=sim.time+warning
	sim.sfx("boss_warning")

func _start_major() -> void:
	var targets: Array=[]
	if id == "earth":
		var row: int = sim.rng.randi_range(0, sim.rows - 1)
		if row == last_major_row:
			row = (row + 1) % sim.rows
		last_major_row = row
		var columns := [8, 6, 4, 7, 3]
		for index in int(config.major.hit_count):
			var c: int = columns[index % columns.size()]
			var r: int = row if index < 3 else (row + 1) % sim.rows
			if _cell_ok(c, r):
				targets.append(_target(c, r))
	else:
		var candidates: Array = []
		for r in sim.rows:
			for c in range(8, 1, -1):
				var plant = sim.main_plant_at(c, r)
				if plant != null and not plant.dead and not plant.ash and _cell_ok(c, r):
					candidates.append([c, r])
		while targets.size() < int(config.major.hit_count) and not candidates.is_empty():
			var index: int = sim.rng.randi_range(0, candidates.size() - 1)
			var cell: Array = candidates.pop_at(index)
			targets.append(_target(cell[0], cell[1]))
		targets.sort_custom(func(a, b): return int(a.r) < int(b.r))
	var warning=float(config.major.warning_s)
	action={"kind":"major","targets":targets,"warning_start":sim.time,"warning_end":sim.time+warning,"hit":0,"kills":0}
	state="major_warning";state_end=sim.time+warning
	major_count+=1
	sim.sfx("boss_warning")

func _resolve_small() -> void:
	if String(action.kind) == "summon_wave":
		var final_wave = _final_wave()
		var delay = 0.0
		for wave in final_wave:
			var prior_count: int = sim.spawn_queue.size()
			sim.queue_roster(wave, -1, 1.0, false, true, delay)
			delay += maxf(0.9, float(sim.spawn_queue.size() - prior_count) * 0.38)
		sim.sfx("alert")
		return
	for cell in action.targets:
		var pos: Vector2=sim.cell_pos(int(cell.c),int(cell.r))
		match String(action.kind):
			"tide_surge", "verdict":
				var skill: Dictionary = config.small_skill
				_hurt_cell(cell, float(skill.damage))
				var host = sim.main_plant_at(int(cell.c), int(cell.r))
				if host != null and not host.dead:
					host.sealed_until = maxf(host.sealed_until, sim.time + float(skill.seal_s) * SKILL_FORCE)
					if id == "island":
						sim.apply_plant_penalty(host, "haste", 0.2, 5.0, "潮灯惊魂")
					elif id == "magistrate-full":
						sim.apply_plant_penalty(host, "damage", 0.25, 5.0, "墨罚")
				emit("water" if String(action.kind) == "tide_surge" else "paper", pos)
			"tunnel":
				_hurt_cell(cell,140)
				_add_prop("tunnel",cell,160,9.0 * float(config.module_duration_scale))
				emit("earth",pos)
			"paper_ferry":
				if _prop_count() < _prop_limit() and sim.main_plant_at(int(cell.c),int(cell.r))==null and sim.lily_at(int(cell.c),int(cell.r))==null:
					_add_prop("paper_ferry",cell,240,12.0 * float(config.module_duration_scale))
			"seal":
				var host=sim.main_plant_at(int(cell.c),int(cell.r))
				if host!=null and not host.dead and _prop_count()<2:
					var duration = (2.0 if host.def.has("produce") else 5.0) * SKILL_FORCE
					host.sealed_until=maxf(host.sealed_until,sim.time+duration)
					_add_prop("paper_seal",cell,120,duration)
			"crab":
				if sim.active_zombies()<int(config.adds.live_cap) + 2:
					var z=_make_proxy("crab",int(cell.r),Geo.SPAWN_X,180 * SKILL_FORCE,
						{"kind":"crab","until":sim.time+10.0,"next":0.0,"c":int(cell.c),"r":int(cell.r)})
					props.append(z)
	sim.sfx("boss_impact")

func _prop_limit() -> int:
	return 3 if id == "paper" else 2


func _prop_count() -> int:
	var n=0
	for z in props:
		if z.alive() and z.boss_role=="prop":n+=1
	return n

func _add_prop(kind: String,cell: Dictionary,health: float,life: float) -> void:
	if _prop_count() >= _prop_limit(): return
	var pos: Vector2=sim.cell_pos(int(cell.c),int(cell.r))
	var z=_make_proxy("prop",int(cell.r),pos.x,health * SKILL_FORCE,
		{"kind":kind,"until":sim.time+life,"next":sim.time+(4.0 if kind=="tunnel" else 3.0),
		"c":int(cell.c),"r":int(cell.r)})
	props.append(z)
	if kind=="paper_seal":
		var host=sim.main_plant_at(int(cell.c),int(cell.r))
		if host!=null:z.boss_meta.host_uid=host.uid
	emit("paper" if kind!="tunnel" else "earth",pos)

func _update_props(dt: float,paused_adds: bool) -> void:
	var keep: Array=[]
	for z in props:
		if not z.alive():continue
		z.hurt=maxf(0,z.hurt-dt)
		z.vuln_t=maxf(0,z.vuln_t-dt);z.slow_t=maxf(0,z.slow_t-dt)
		if z.burn_t>0:
			z.burn_t=maxf(0,z.burn_t-dt);sim.damage_zombie(z,z.burn_dps*dt,true,false,String(z.burn_src))
		if z.bleed_t>0:
			z.bleed_t=maxf(0,z.bleed_t-dt);sim.damage_zombie(z,z.bleed_dps*dt,true,false,"bell")
		if not z.alive():continue
		sim.update_marks(z,dt)
		z.cc_immune=maxf(0,z.cc_immune-dt)
		var meta: Dictionary=z.boss_meta
		if sim.time>=float(meta.until):break_prop(z);continue
		if String(meta.kind)=="paper_seal":
			var host=sim.main_plant_at(int(meta.c),int(meta.r))
			if host==null or host.dead or host.uid!=String(meta.get("host_uid",host.uid)):break_prop(z);continue
		elif z.boss_role=="crab":
			var factor=(1.0-z.slow_amount) if z.slow_t>0 else 1.0
			if z.stun_t>0:z.stun_t=maxf(0,z.stun_t-dt);factor=0.0
			if z.reverse_t>0:z.reverse_t=maxf(0,z.reverse_t-dt);factor*=-1.0
			var distance=1.54*Geo.CELL_W*dt*factor
			z.pos.x=minf(Geo.SPAWN_X,z.pos.x-distance)
			if not z.alive():continue
			var host=null
			for c in range(8,1,-1):
				var candidate=sim.main_plant_at(c,z.row)
				if candidate!=null and not candidate.dead and z.pos.x<=candidate.pos.x+30:
					host=candidate;break
			if host!=null:
				_hurt_cell({"c":host.col,"r":host.row},300);break_prop(z);continue
			if z.pos.x<=sim.cell_pos(2,z.row).x:break_prop(z);continue
		elif paused_adds:
			meta.next=maxf(float(meta.next),sim.time+2.0)
		elif sim.time>=float(meta.next):
			_spawn_add("light" if String(meta.kind)=="tunnel" else "armor",z)
			meta.next=sim.time+4.0
		keep.append(z)
	props=keep

func break_prop(z) -> void:
	if z.dead:return
	z.dead=true;z.hp=0
	var kind=String(z.boss_meta.get("kind","tunnel"))
	if kind=="paper_seal":
		var host=sim.main_plant_at(int(z.boss_meta.c),z.row)
		if host!=null and host.uid==String(z.boss_meta.get("host_uid",host.uid)):
			var remaining:=0.0
			for peer in sim.active_bosses():
				for prop in peer.props:
					if prop!=z and prop.alive() and String(prop.boss_meta.get("kind",""))=="paper_seal" and String(prop.boss_meta.get("host_uid",""))==host.uid:
						remaining=maxf(remaining,float(prop.boss_meta.until))
			if is_equal_approx(host.sealed_until,float(z.boss_meta.until)):host.sealed_until=remaining
			else:host.sealed_until=maxf(host.sealed_until,remaining)
	emit("break",z.pos,{"prop":kind})
	sim.sfx("boss_paper" if kind in ["paper_ferry","paper_seal"] else "boss_impact")

func _hurt_cell(cell: Dictionary,amount: float) -> void:
	amount = roundf(amount * SKILL_FORCE)
	if int(cell.c)<2:return
	var p=sim.main_plant_at(int(cell.c),int(cell.r))
	if p==null or p.dead or p.is_lily or p.ash:return
	var lethal_allowed=destruction_used<int(config.destruction_budget) and int(action.get("kills",0))<2
	# Charged crabs are separate casts, but never split one frame into several losses.
	if String(action.get("kind",""))!="major":lethal_allowed=destruction_used<int(config.destruction_budget) and absf(last_boss_destroy_at-sim.time)>0.0001
	var applied=amount
	if not lethal_allowed and amount >= p.hp + p.wish + p.shell:
		# After the destructive hit, the remaining force suppresses nearby plants.
		applied = minf(amount, p.hp * 0.45 + p.wish + p.shell)
		p.sealed_until = minf(maxf(p.sealed_until, sim.time + 2.0), sim.time + 4.0)
	if applied>0:sim.damage_plant(p,applied)
	if (p.dead or p.ash or p.dance_t>0) and not p.boss_recycled:
		p.boss_recycled=true
		destruction_used+=1;action.kills=int(action.get("kills",0))+1;last_boss_destroy_at=sim.time
		for card in sim.cards:
			if String(card.id)==String(p.type):card.cd=0.0
		repair_marks.append({"c":int(cell.c),"r":int(cell.r),"until":sim.time+8.0})

func _resolve_major() -> void:
	var targets: Array=action.targets
	while int(action.hit)<targets.size():
		var index=int(action.hit)
		if sim.time<float(action.warning_end)+index*float(config.major.hit_spacing_s):break
		var cell: Dictionary=targets[index]
		_hurt_cell(cell,float(config.major.damage_per_hit))
		sim.request_hit_stop(0.09)
		if id in ["paper", "magistrate-full"]:
			var host=sim.main_plant_at(int(cell.c),int(cell.r))
			if host!=null and not host.dead:host.sealed_until=maxf(host.sealed_until,sim.time + 2.0 * SKILL_FORCE)
		emit("earth" if id=="earth" else ("paper" if id in ["paper", "magistrate-full"] else "water"),sim.cell_pos(int(cell.c),int(cell.r)))
		sim.shake=maxf(sim.shake,3.0);sim.sfx("boss_impact")
		action.hit=index+1
	var last_hit=float(action.warning_end)+maxi(0,targets.size()-1)*float(config.major.hit_spacing_s)
	if int(action.hit)>=targets.size() and sim.time>=last_hit+0.6:
		state="recovery";state_end=sim.time+2.4

func _die() -> void:
	died_at=sim.time;hp=0;state="dead";major_queue.clear();action={}
	for z in props:break_prop(z)
	props.clear()
	var surviving_peer:=false
	for other in sim.active_bosses():
		if other!=self and other.alive():surviving_peer=true
	for z in body_targets:z.dead=true;z.eating=false
	if not surviving_peer:
		for z in sim.zombies:
			if not z.dead and z.boss_role=="":emit("release",z.pos)
			z.dead=true;z.eating=false
		for p in sim.plants:p.sealed_until=0.0
		sim.spawn_queue.clear();sim.pending_spawns.clear()
	sim.banner={"text":String(config.name)+"退散", "group":int(wave_end / Content.WAVES_PER_GROUP),
		"groups":Content.wave_groups(sim.level),"t":2.0,"max":2.0}
	sim.sfx("boss_defeat")

func serialize() -> Dictionary:
	var saved: Dictionary={}
	for name in ["id","hp","max_hp","began_at","combat_at","died_at","state","state_end","small_at","adds_at","spawn_gate",
		"major_queue","fired","action","cell_cooldowns","repair_marks","destruction_used","supply_given","alternate","last_lane",
		"lane_streak","last_major_row","cc_log","stun_until","total_damage","add_count","peak_adds","major_count","last_boss_destroy_at",
		"major_wait_since","adds_were_paused","hit_tokens","damage_carry","effects", "body_row", "blink_from",
		"blink_at", "smalls_to_blink", "small_casts", "reinforcement_index", "wave_end", "encounter_slot", "rate_scale"]:
		saved[name]=get(name)
	var proxy_rows: Array=[]
	for z in body_targets+props:
		if not z.dead:proxy_rows.append(sim.pack_unit(z))
	saved.proxies=proxy_rows
	return saved

func restore(owner,data: Dictionary) -> void:
	encounter_slot=int(data.get("encounter_slot",0))
	begin(owner,String(data.id), int(data.get("wave_end", -1)))
	for z in body_targets:z.dead=true
	body_targets.clear();props.clear()
	for name in data:
		if name!="proxies":
			var current=get(name)
			set(name,int(data[name]) if current is int else data[name])
	for row in data.get("proxies", []):
		var role := String(row.boss_role)
		if role in ["body", "weakpoint"]:
			if int(row.row) not in [body_row, body_row + 1]:
				continue
			var z = _make_proxy("body", int(row.row), body_x(), max_hp, {})
			sim.unpack_unit(z, row)
			z.boss_role = "body"
			z.type = "boss_body"
			z.pos.x = body_x()
			body_targets.append(z)
		else:
			var z = _make_proxy(role, int(row.row), float(row.pos[0]),
				float(row.max_hp), Dictionary(row.boss_meta))
			sim.unpack_unit(z, row)
			props.append(z)
	if alive() and body_targets.is_empty():
		_make_body_targets()
	body_targets.sort_custom(func(a, b): return a.row < b.row)
	_sync_hp()
	sim.banner={}
