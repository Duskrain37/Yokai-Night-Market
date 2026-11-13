## Recommendation-driven deterministic fixture. Losses describe this bot, not human impossibility.
class_name QaBot
extends RefCounted
# Historical fixture retained for isolated evil-leader comparison only.
const LOADOUT=["lantern","shooter","wall","bell","censer","umbrella","lion","torch","needle","lily"]
const STRATEGY_ROLES={"year-banyan":"产能","sky-mortar":"抛射","reed-chime":"范围","soul-casket":"借弹","lantern":"产能","shooter":"射线","wall":"防御","bomb":"灰烬","bell":"辅助","censer":"范围","umbrella":"收妖","lion":"近战","mushroom":"灰烬","cat":"追魂","shell":"护罩","lobber":"抛射","torch":"增幅","star":"五向","needle":"破甲","judge":"庇护","gust":"灰烬","firework":"抛射","squash":"灰烬","dragon":"近攻","lily":"浮台","herb-gourd":"扶伤","ruin-cap":"灰烬","sky-kite":"抛射","wish-till":"产能","cash-pod":"灰烬","ember-cicada":"追魂","kelp":"灰烬"}
const STRATEGY_VERSION="recommended-v2"
const MAX_SECONDS=1800.0
const PACE_SECONDS=1200.0

static func play(level_id: int,seed_value: int=7,difficulty: String="easy",options: Dictionary={}) -> Dictionary:
	var sim=Sim.new()
	var cards: Array=options.get("cards",Content.night_loadout_tips(Content.get_level(level_id)).slice(0,10))
	sim.setup(Content.get_level(level_id),cards,difficulty,seed_value)
	var rng=RandomNumberGenerator.new();rng.seed=seed_value
	var won=[false];var lost=[false]
	sim.on_win=func():won[0]=true
	sim.on_lose=func(_z):lost[0]=true
	var dt=1.0/30.0;var decision=0.0;var max_shots=0;var bad="";var stalls=0
	var last_recovery=-1000.0;var previous_hp={};var last_damage=0.0
	var trace=HashingContext.new();trace.start(HashingContext.HASH_SHA256)
	var last_wave=0
	while sim.time<float(options.get("ceiling",MAX_SECONDS)) and not won[0] and not lost[0]:
		sim.tick(dt);sim.sounds.clear();sim.sound_detail.clear()
		if sim.wave_index!=last_wave:
			last_wave=sim.wave_index
			trace.update(JSON.stringify(sim.spawn_queue).to_utf8_buffer())
		for z in sim.zombies:
			var hp=float(z.hp+z.armor)
			if previous_hp.has(z.uid) and hp<float(previous_hp[z.uid]):last_damage=sim.time
			previous_hp[z.uid]=hp
		decision+=dt
		if decision>=0.5:
			decision=0
			var stuck=sim.wave_index>=Array(sim.level.waves).size() and sim.spawn_queue.is_empty() and sim.boss==null and sim.time-last_damage>=60
			if stuck and sim.time-last_recovery>=60:
				stalls+=1;last_recovery=sim.time
				for z in sim.zombies:
					if not z.alive():continue
					for plant in sim.plants.duplicate():
						if not plant.dead and plant.row==z.row and plant.pos.x<z.pos.x+50:sim.shovel_at(plant.col,plant.row)
			strategy(sim,rng)
		max_shots=maxi(max_shots,sim.shots.size())
		if not is_finite(sim.sun) or sim.sun<0:bad="香火异常";break
		for z in sim.zombies:
			if not is_finite(z.hp) or not is_finite(z.armor):bad="耐久异常";break
		if not bad.is_empty():break
	var outcome="error" if not bad.is_empty() else ("won" if won[0] else ("lost" if lost[0] else ("bot_stalemate" if stalls>0 else "timeout")))
	sim.on_win=Callable();sim.on_lose=Callable()
	return {"sim":sim,"won":won[0],"lost":lost[0],"bad":bad,"max_shots":max_shots,"outcome":outcome,"bot_stalemate":stalls,"pace_ok":sim.time<=PACE_SECONDS,"strategy":STRATEGY_VERSION,"cards":cards,"spawn_trace":trace.finish().hex_encode()}

static func _attack_type(type: String) -> bool:
	return type=="reed-chime" or String(STRATEGY_ROLES.get(type,Content.PLANTS[type].role)) in ["射线","抛射","追魂","破甲","五向"]

static func _plan(sim: Sim) -> Array:
	var producers=[];var attackers=[];var blockers=[];var others=[]
	for card in sim.cards:
		var type=String(card.id);var role=String(STRATEGY_ROLES.get(type,Content.PLANTS[type].role))
		if role=="产能":producers.append(type)
		elif _attack_type(type):attackers.append(type)
		elif role in ["防御","收妖","近战","近攻"]:blockers.append(type)
		elif role in ["辅助","范围","增幅","庇护","扶伤","借弹"]:others.append(type)
	var plan=[]
	if not producers.is_empty():plan.append([0,producers[0]]);plan.append([1,producers[0]])
	if not attackers.is_empty():
		for col in [2,3,4]:plan.append([col,attackers[(col-2)%attackers.size()]])
	if not blockers.is_empty():plan.append([6,blockers[0]])
	for i in mini(others.size(),2):plan.append([5+i*2,others[i]])
	return plan

static func strategy(sim: Sim,rng: RandomNumberGenerator) -> void:
	# Pay normal costs, obey normal cooldowns and never replenish underneath a bypassed guest.
	var plan=_plan(sim)
	var order=range(sim.rows)
	order.sort_custom(func(a,b):return _pressure(sim,a)>_pressure(sim,b))
	for item in plan:
		var col=int(item[0]);var type=String(item[1]);var index=_card_index(sim,type)
		if index<0 or float(sim.cards[index].cd)>0:continue
		for row in order:
			var unsafe=false
			for z in sim.zombies:
				if z.alive() and z.row==row and z.pos.x<sim.cell_pos(col,row).x+60:unsafe=true;break
			if unsafe or sim.main_plant_at(col,row)!=null:continue
			if String(sim.tile_at(col,row).kind)=="water" and sim.lily_at(col,row)==null:
				_put(sim,"lily",col,row,0);continue
			_put(sim,type,col,row,0 if sim.time<60 else 40)
	# Upgrade every available offensive role by a declared route, not fixed columns.
	for plant in sim.plants:
		if plant.dead:continue
		var route=int({"lantern":1,"shooter":1,"needle":1,"sky-kite":1,"ember-cicada":2,"cat":2,"star":1,"lobber":1,"censer":1,"wish-till":1,"wall":1,"reed-chime":1,"soul-casket":3}.get(plant.type,0))
		if route<=0:continue
		var status=sim.upgrade_status(plant,route)
		var reserve=150 if sim.time<120 else 80
		if status.ok and sim.sun>=int(status.cost)+reserve:sim.try_upgrade(plant,route,plant.pos)
	# Reactive one-use cards from the chosen loadout, without granting extra cards or resources.
	for z in sim.zombies:
		if not z.alive() or z.boss_role!="" or z.pos.x>Geo.BOARD_X+Geo.CELL_W*6:continue
		for type in ["kelp","squash","bomb","ruin-cap","mushroom","cash-pod"]:
			if _card_index(sim,type)<0:continue
			var col=clampi(floori((z.pos.x-Geo.BOARD_X)/Geo.CELL_W)-1,0,8)
			if type=="cash-pod":col+=1
			if col<9:_put(sim,type,col,z.row,60)

static func _pressure(sim: Sim,row: int) -> float:
	var value=0.0
	for z in sim.zombies:
		if z.alive() and z.row==row:value+=1000.0/maxf(10,z.pos.x-Geo.BREACH_X)
	return value

static func _put(sim: Sim,type: String,col: int,row: int,reserve: int) -> bool:
	var at=_card_index(sim,type)
	if at<0 or sim.sun<int(Content.PLANTS[type].cost)+reserve or float(sim.cards[at].cd)>0:return false
	if not bool(sim.can_place_at(type,col,row).ok):return false
	return sim.try_place_card(at,col,row,Vector2.ZERO)

static func _card_index(sim: Sim,type: String) -> int:
	for i in sim.cards.size():
		if String(sim.cards[i].id)==type:return i
	return -1
