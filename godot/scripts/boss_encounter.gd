## Deterministic encounter model. All clocks use Sim.time; View never deals damage.
extends RefCounted

var _owner: WeakRef
var sim:
	get:return _owner.get_ref() if _owner!=null else null
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
var weakpoints: Array = []
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
var total_damage = 0.0
var add_count = 0
var peak_adds = 0
var major_count = 0
var last_boss_destroy_at = -1.0
var wave_end = 0
var major_wait_since = -1.0
var adds_were_paused = false

func begin(owner, boss_id: String) -> void:
	_owner = weakref(owner)
	id = boss_id
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/boss_balance.json"))
	for row in data.bosses:
		if row.id == id:
			config = row.duplicate(true)
	# Boss is excluded from threat: only an explicit difficulty choice changes its HP.
	var difficulty_scale = {"easy":0.85,"normal":1.0,"hard":1.15}.get(sim.difficulty,1.0)
	max_hp = float(config.max_hp) * float(difficulty_scale)
	hp = max_hp
	began_at = sim.time
	combat_at = sim.time + 3.0
	state_end = combat_at
	small_at = combat_at + float(config.small_first_s)
	adds_at = combat_at + 5.0
	wave_end = Array(sim.level.waves).size()
	if bool(sim.level.get("special",false)):wave_end=(sim.special_bosses_completed+1)*12
	sim.wave_index = wave_end
	sim.last_group = int(wave_end/Content.WAVES_PER_GROUP)-1
	sim.spawn_queue.clear()
	sim.pending_spawns.clear()
	for row in sim.rows:
		var proxy = sim.make_boss_proxy("weakpoint",row,Geo.BOARD_X+Geo.BOARD_W-4,max_hp,{})
		weakpoints.append(proxy)
	sim.banner={"text":String(config.name)+"现身", "group":int(wave_end/Content.WAVES_PER_GROUP),
		"groups":Content.wave_groups(sim.level),"t":3.0,"max":3.0}
	sim.sfx("boss_intro")

func alive() -> bool:
	return died_at < 0.0

func finished() -> bool:
	return died_at >= 0.0 and sim.time >= died_at+2.0

func pose() -> String:
	if not alive(): return "defeat"
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
	for z in weakpoints:
		z.hp=hp
		z.max_hp=max_hp

func damage(proxy, amount: float, source: String = "") -> float:
	if not alive() or amount<=0: return 0.0
	if damage_token!="" and hit_tokens.has(damage_token): return 0.0
	if damage_token!="": hit_tokens[damage_token]=sim.time
	var damage_value = amount
	if proxy!=null and proxy.vuln_t>0: damage_value*=1.0+proxy.vuln
	if state=="recovery": damage_value*=1.25
	if damage_token.begins_with("percent:"):damage_value=minf(damage_value,max_hp*0.01)
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

func control(seconds: float) -> void:
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
	# A poison/burn status shared through several lane weakpoints cannot multiply by lane count.
	var burn=0.0;var bleed=0.0;var burn_source=""
	for z in weakpoints:
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
	if burn>0: damage(null,burn*dt,burn_source)
	if bleed>0: damage(null,bleed*dt,"bell")
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
			if not supply_given:
				supply_given=true;sim.sun+=int(config.entry_incense)
				sim.float_text(Vector2(Geo.BOARD_X+150,sim.row_y(0)),"援香 +%d" % int(config.entry_incense))
		return
	if sim.time<stun_until: return
	match state:
		"small_warning":
			if sim.time>=state_end:
				_resolve_small();state="small_recovery";state_end=sim.time+0.5
		"small_recovery":
			if sim.time>=state_end:state="idle"
		"major_warning":
			if sim.time>=state_end:state="major_hits"
		"major_hits":
			_resolve_major()
		"recovery":
			if sim.time>=state_end:state="major_gap";state_end=sim.time+1.0
		"major_gap":
			if sim.time>=state_end:
				state="idle";small_at=sim.time+float(config.small_period_s);adds_at=sim.time+_interval()
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
				_start_small();small_at=sim.time+float(config.small_period_s)
	if paused_adds:
		adds_were_paused=true
	elif adds_were_paused:
		adds_were_paused=false;adds_at=sim.time+_interval()
	elif sim.time>=adds_at:
		_spawn_add("")
		adds_at=sim.time+_interval()
	peak_adds=maxi(peak_adds,sim.active_zombies())

func _interval() -> float:
	return sim.rng.randf_range(float(config.adds.interval_s[0]),float(config.adds.interval_s[1]))

func _spawn_add(role: String,source=null) -> bool:
	if not alive() or sim.time<spawn_gate or sim.active_zombies()>=int(config.adds.live_cap):return false
	var lane=0;var best=100000
	for r in sim.rows:
		var count=0
		for z in sim.zombies:
			if z.alive() and z.boss_role!="weakpoint" and z.boss_role!="prop" and z.row==r:count+=1
		if r==last_lane and lane_streak>=2:count+=100
		if count<best or (count==best and sim.rng.randf()<0.5):best=count;lane=r
	if source!=null:
		lane=source.row
		if lane==last_lane and lane_streak>=2:return false
	if lane==last_lane:lane_streak+=1
	else:last_lane=lane;lane_streak=1
	var type="ghost"
	if role=="armor":type="straw"
	elif role!="light":
		var roll=sim.rng.randi_range(1,100)
		if roll>int(config.adds.weights.light)+int(config.adds.weights.armor):type="bucket"
		elif roll>int(config.adds.weights.light):type="straw"
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
	var kind="tunnel" if id=="earth" else ("seal" if alternate%2==0 else "paper_ferry")
	if id=="river":kind="crab"
	alternate+=1
	var targets: Array=[]
	var warning=2.2
	if kind=="tunnel":
		var cell=_random_cell(4,7)
		if not cell.is_empty():targets.append(cell)
	elif kind=="paper_ferry":
		var cell=_random_cell(6,8,true)
		if not cell.is_empty():targets.append(cell)
		warning=1.8
	else:
		warning=1.8 if kind=="seal" else 2.0
		var candidates: Array=[]
		for p in sim.plants:
			if not p.dead and not p.is_lily and not p.ash and _cell_ok(p.col,p.row):candidates.append(p)
		var picked_rows: Array=[]
		var economy_chosen=false
		for i in (2 if kind=="seal" else 1):
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
	if id=="earth":
		var row=sim.rng.randi_range(0,sim.rows-1)
		if row==last_major_row:row=(row+1)%sim.rows
		last_major_row=row
		for col in [7,5,3]:
			if _cell_ok(col,row):targets.append(_target(col,row))
	else:
		var front: Array=[]
		for r in sim.rows:
			for c in range(8,1,-1):
				var p=sim.main_plant_at(c,r)
				if p!=null and not p.dead and not p.ash and _cell_ok(c,r):
					front.append([c,r]);break
		while targets.size()<int(config.major.hit_count) and not front.is_empty():
			var index=sim.rng.randi_range(0,front.size()-1)
			var cell: Array=front.pop_at(index)
			targets.append(_target(cell[0],cell[1]))
		targets.sort_custom(func(a,b):return int(a.r)<int(b.r))
	var warning=float(config.major.warning_s)
	action={"kind":"major","targets":targets,"warning_start":sim.time,"warning_end":sim.time+warning,"hit":0,"kills":0}
	state="major_warning";state_end=sim.time+warning
	major_count+=1
	sim.sfx("boss_warning")

func _resolve_small() -> void:
	for cell in action.targets:
		var pos: Vector2=sim.cell_pos(int(cell.c),int(cell.r))
		match String(action.kind):
			"tunnel":
				_hurt_cell(cell,140)
				_add_prop("tunnel",cell,160,9)
				emit("earth",pos)
			"paper_ferry":
				if _prop_count()<2 and sim.main_plant_at(int(cell.c),int(cell.r))==null and sim.lily_at(int(cell.c),int(cell.r))==null:
					_add_prop("paper_ferry",cell,240,12)
			"seal":
				var host=sim.main_plant_at(int(cell.c),int(cell.r))
				if host!=null and not host.dead and _prop_count()<2:
					var duration=2.0 if host.def.has("produce") else 5.0
					host.sealed_until=sim.time+duration
					_add_prop("paper_seal",cell,120,duration)
			"crab":
				if sim.time>=spawn_gate and sim.active_zombies()<int(config.adds.live_cap):
					var z=sim.make_boss_proxy("crab",int(cell.r),Geo.SPAWN_X,180,
						{"kind":"crab","until":sim.time+10.0,"next":0.0,"c":int(cell.c),"r":int(cell.r)})
					props.append(z);spawn_gate=sim.time+1.5
	sim.sfx("boss_impact")

func _prop_count() -> int:
	var n=0
	for z in props:
		if z.alive() and z.boss_role=="prop":n+=1
	return n

func _add_prop(kind: String,cell: Dictionary,health: float,life: float) -> void:
	if _prop_count()>=2:return
	var pos: Vector2=sim.cell_pos(int(cell.c),int(cell.r))
	var z=sim.make_boss_proxy("prop",int(cell.r),pos.x,health,
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
			if distance>0:sim._nail_progress(z,distance)
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
		if host!=null and host.uid==String(z.boss_meta.get("host_uid",host.uid)):host.sealed_until=0.0
	emit("break",z.pos,{"prop":kind})
	sim.sfx("boss_paper" if kind in ["paper_ferry","paper_seal"] else "boss_impact")

func _hurt_cell(cell: Dictionary,amount: float) -> void:
	if int(cell.c)<2:return
	var p=sim.main_plant_at(int(cell.c),int(cell.r))
	if p==null or p.dead or p.is_lily or p.ash:return
	var lethal_allowed=destruction_used<int(config.destruction_budget) and int(action.get("kills",0))<1
	# Charged crabs are separate casts, but never split one frame into several losses.
	if String(action.get("kind",""))!="major":lethal_allowed=destruction_used<int(config.destruction_budget) and absf(last_boss_destroy_at-sim.time)>0.0001
	var applied=amount
	if not lethal_allowed:
		applied=minf(applied,maxf(0.0,p.hp-1.0))
		p.sealed_until=minf(maxf(p.sealed_until,sim.time+2),sim.time+4)
	if applied>0:sim.damage_plant(p,applied)
	if (p.dead or p.ash or p.dance_t>0) and not p.boss_recycled:
		p.boss_recycled=true
		destruction_used+=1;action.kills=int(action.get("kills",0))+1;last_boss_destroy_at=sim.time
		var refund=int(floor(float(p.paid_incense)*0.8/5.0))*5
		sim.sun+=refund
		for card in sim.cards:
			if String(card.id)==String(p.type):card.cd=0.0
		repair_marks.append({"c":int(cell.c),"r":int(cell.r),"until":sim.time+8.0})
		sim.float_text(p.pos+Vector2(0,-70),"回收香火 +%d" % refund,Color("#e5cc93"))
	elif not lethal_allowed:
		sim.float_text(p.pos+Vector2(0,-65),"护市结界 · 失衡",Color("#b8cbb0"),15)

func _resolve_major() -> void:
	var targets: Array=action.targets
	while int(action.hit)<targets.size():
		var index=int(action.hit)
		if sim.time<float(action.warning_end)+index*float(config.major.hit_spacing_s):break
		var cell: Dictionary=targets[index]
		_hurt_cell(cell,float(config.major.damage_per_hit))
		if id=="paper":
			var host=sim.main_plant_at(int(cell.c),int(cell.r))
			if host!=null and not host.dead:host.sealed_until=maxf(host.sealed_until,sim.time+2.0)
		emit("earth" if id=="earth" else ("paper" if id=="paper" else "water"),sim.cell_pos(int(cell.c),int(cell.r)))
		sim.shake=maxf(sim.shake,3.0);sim.sfx("boss_impact")
		action.hit=index+1
	var last_hit=float(action.warning_end)+maxi(0,targets.size()-1)*float(config.major.hit_spacing_s)
	if int(action.hit)>=targets.size() and sim.time>=last_hit+0.6:
		state="recovery";state_end=sim.time+3.0

func _die() -> void:
	died_at=sim.time;hp=0;state="dead";major_queue.clear();action={}
	for z in props:break_prop(z)
	props.clear()
	for z in sim.zombies:
		if not z.dead and z.boss_role=="":emit("release",z.pos)
		z.dead=true;z.eating=false
	for p in sim.plants:p.sealed_until=0.0
	sim.spawn_queue.clear();sim.pending_spawns.clear()
	sim.banner={"text":String(config.name)+"退散", "group":Content.wave_groups(sim.level),
		"groups":Content.wave_groups(sim.level),"t":2.0,"max":2.0}
	sim.sfx("boss_defeat")

func serialize() -> Dictionary:
	var saved: Dictionary={}
	for name in ["id","hp","max_hp","began_at","combat_at","died_at","state","state_end","small_at","adds_at","spawn_gate",
		"major_queue","fired","action","cell_cooldowns","repair_marks","destruction_used","supply_given","alternate","last_lane",
		"lane_streak","last_major_row","cc_log","stun_until","total_damage","add_count","peak_adds","major_count","last_boss_destroy_at",
		"major_wait_since","adds_were_paused","hit_tokens","effects"]:
		saved[name]=get(name)
	var proxy_rows: Array=[]
	for z in weakpoints+props:
		if not z.dead:proxy_rows.append(sim.pack_unit(z))
	saved.proxies=proxy_rows
	return saved

func restore(owner,data: Dictionary) -> void:
	begin(owner,String(data.id))
	for z in weakpoints:z.dead=true
	weakpoints.clear();props.clear()
	for name in data:
		if name!="proxies":set(name,data[name])
	for row in data.get("proxies",[]):
		var z=sim.make_boss_proxy(String(row.boss_role),int(row.row),float(row.pos[0]),float(row.max_hp),Dictionary(row.boss_meta))
		sim.unpack_unit(z,row)
		if z.boss_role=="weakpoint":weakpoints.append(z)
		else:props.append(z)
	_sync_hp()
	sim.banner={}
