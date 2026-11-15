## New plants share the existing unit/shot/save model; this module owns only rules.
extends RefCounted
var owner_ref: WeakRef
var bloom_elapsed := 0.0
var bloom_skill_ready_at := 0.0
var flares: Array = []
var bloom_events: Array=[]

func _init(owner) -> void: owner_ref=weakref(owner)

func tick(dt: float) -> void:
	var s=owner_ref.get_ref()
	if s==null:return
	for event in bloom_events.duplicate():
		if s.time>=float(event.at):
			resolve_bloom(String(event.uid));bloom_events.erase(event)
	for plant in s.plants:
		if plant.transplant_progress<1.0:plant.transplant_progress=clampf((s.time-plant.transplant_started)/.9,0,1)
	var flowers: Array=s.plants.filter(func(p):return p.type=="watch-bloom" and s.plant_on_stage(p) and p.transplant_until<=s.time and p.sleep_until<=s.time and p.sealed_until<=s.time)
	if flowers.is_empty():
		if not s.plants.any(func(p):return not p.dead and p.type=="watch-bloom"):bloom_elapsed=0.0
	else:
		flowers.sort_custom(func(a,b):return bloom_score(a)>bloom_score(b))
		var lead=flowers[0]
		var interval: float=Upgrades.EFFECTS["watch-bloom"].interval[lead.tier(1)]
		bloom_elapsed=minf(interval,bloom_elapsed+dt)
		for flower in flowers:flower.timer=bloom_elapsed
		if bloom_elapsed>=interval:
			bloom_elapsed=0.0
			bloom_trigger(lead)
	var keep: Array=[]
	for event in flares:
		if s.time<float(event.at):keep.append(event);continue
		var seen_bodies: Array=[]
		for guest in s.zombies:
			if not guest.alive():continue
			guest.flare_reveal_until=maxf(guest.flare_reveal_until,s.time+6.0)
			if guest.boss_role=="body":
				var slot:int=guest.boss_meta.get("encounter_slot",0)
				if slot in seen_bodies:continue
				seen_bodies.append(slot)
			var duration: float=.9 if guest.is_large() else 1.8
			# This long-cooldown active explicitly grants 1.8/.9 seconds; ordinary
			# repeated-control budgets still see its duration, and bosses retain their cap.
			s.apply_stun(guest,duration)
			guest.cc_log.append([s.time,duration])
			s.magic_effect("v070-flare-stun",guest.pos,105,1.8)
		s.magic_effect("v070-flare-burst",Vector2(800,170),520,.9)
		s.sfx("cicada_shot")
	flares=keep

func bloom_score(plant) -> float:
	var amount: float=Upgrades.EFFECTS["watch-bloom"].reduction[plant.tier(1)]-float(plant.tier(2)>0)
	return amount*int(Upgrades.EFFECTS["watch-bloom"].targets[plant.tier(2)])/float(Upgrades.EFFECTS["watch-bloom"].interval[plant.tier(1)])+.000001*plant.tier(3)

func bloom_trigger(plant) -> void:
	var s=owner_ref.get_ref()
	var candidates: Array=[]
	for card in s.cards:
		if card.id=="watch-bloom" or float(card.cd)<=0:continue
		if String(card.def.role)=="灰烬" and plant.tier(3)<1:continue
		candidates.append(card)
	candidates.sort_custom(func(a,b):
		if a.id==plant.seed_priority and b.id!=plant.seed_priority:return true
		if b.id==plant.seed_priority and a.id!=plant.seed_priority:return false
		return float(a.cd)>float(b.cd))
	if candidates.is_empty():return
	var amount: float=Upgrades.EFFECTS["watch-bloom"].reduction[plant.tier(1)]-float(plant.tier(2)>0)
	var count: int=Upgrades.EFFECTS["watch-bloom"].targets[plant.tier(2)]
	for card in candidates.slice(0,count):
		card.cd=maxf(0,float(card.cd)-amount)
		if plant.tier(2)>=2:
			var cap: int=25*int(Upgrades.EFFECTS["watch-bloom"].discount_cap[plant.tier(2)])
			card["discount"]=mini(cap,int(card.get("discount",0))+25)
	if plant.tier(3)>=2:
		var actors: Array=s.plants.filter(func(p):return p!=plant and not p.dead and s.active_skill_status(p).exists and s.active_skill_status(p).left>0)
		actors.sort_custom(func(a,b):return s.active_skill_status(a).left>s.active_skill_status(b).left)
		if not actors.is_empty():reduce_skill(actors[0],amount)
	plant.action_at=s.time;plant.pulse=.65
	s.magic_effect("v070-bloom-tally",plant.pos,130,.8)
	s.sfx("bell")

func reduce_skill(plant,amount: float) -> void:
	var s=owner_ref.get_ref()
	plant.skill_ready_at=maxf(s.time,plant.skill_ready_at-amount)
	if plant.type=="sky-mortar":plant.mortar_active_ready_at=maxf(s.time,plant.mortar_active_ready_at-amount)
	if plant.type=="judge":s.unique_skill_ready_at=maxf(s.time,s.unique_skill_ready_at-amount)
	if plant.type=="watch-bloom":bloom_skill_ready_at=maxf(s.time,bloom_skill_ready_at-amount)

func cast_bloom(plant) -> void:
	var s=owner_ref.get_ref()
	bloom_skill_ready_at=plant.skill_ready_at
	plant.skill_effect_until=s.time+.8
	bloom_events.append({"at":s.time+.8,"uid":plant.uid})
	s.magic_effect("v070-bloom-cast",plant.pos,360,.8)
	s.sfx("capstone")

func resolve_bloom(owner_uid:String) -> void:
	var s=owner_ref.get_ref()
	for card in s.cards:card.cd=0.0
	for ally in s.plants:
		if ally.dead or ally.uid==owner_uid or ally.type=="watch-bloom":continue
		if s.active_skill_status(ally).unlocked:reduce_skill(ally,10)

func cast_flare(plant) -> void:
	var s=owner_ref.get_ref()
	plant.skill_effect_until=s.time+1.0
	flares.append({"at":s.time+1.0,"uid":plant.uid})
	s.magic_effect("v070-flare-rise",plant.pos+Vector2(0,-40),300,1.0)
	s.sfx("cicada_shot")

func update_toad(plant,dt: float) -> void:
	var s=owner_ref.get_ref()
	if plant.toad_mode=="overclock" and s.time>=plant.toad_overclock_until:
		plant.toad_mode="hoard";plant.action_at=s.time;plant.toad_changed_at=s.time
	if plant.toad_mode=="hoard":
		if plant.tier(3)>=2:
			var interval: float=6.5*(1.0-plant.production_reduction)/maxf(.1,1+plant.production_haste)
			plant.toad_income_timer+=dt
			if plant.toad_income_timer>=interval:
				plant.toad_income_timer-=interval
				s.orbs.append({"x":plant.pos.x,"y":plant.pos.y-30,"target_y":plant.pos.y-8,"landed":false,"life":10.0,"value":roundi(50*(1+plant.production_bonus)),"phase":plant.phase,"dead":false,"auto_t":0.0})
				plant.action_at=s.time;s.sfx("produce")
		return
	var interval: float=maxf(.2,float(Upgrades.EFFECTS["vow-toad"].interval[plant.tier(2)])-(.6 if plant.toad_mode=="overclock" else 0.0))/plant.attack_rate()
	plant.timer=minf(interval,plant.timer+dt)
	if plant.timer<interval:return
	var target=s.lane_target(plant)
	if target==null:return
	var divisor: int=Upgrades.EFFECTS["vow-toad"].payment_divisor[plant.tier(2)]
	var cost: int=(50 if plant.tier(3)>=2 else 25) if plant.toad_shots%divisor==0 else 0
	plant.toad_starved=s.sun-cost<150
	if plant.toad_starved:return
	s.sun-=cost;plant.toad_shots+=1;plant.timer=0.0
	var shot=s.new_shot()
	shot.kind="lob" if plant.tier(3)>=1 else "pea"
	shot.look="vow-coin";shot.row=plant.row;shot.owner_uid=plant.uid
	shot.pos=plant.pos+Vector2(22,-24);shot.start=shot.pos;shot.speed=480
	shot.tx=target.pos.x;shot.ty=target.pos.y-14
	shot.flight=clampf(shot.pos.distance_to(target.pos)/460.0,.45,1.35)
	shot.payload={"toad_large":plant.tier(1)>=3,"coin_radius":.5*Geo.CELL_W if plant.tier(3)>=1 else 0.0,
		"coin_splash":1.0 if plant.toad_mode=="overclock" else .5}
	var mode_bonus: float=1.2 if plant.toad_mode=="overclock" else (.7 if plant.tier(3)>=2 else 0.0)
	var damage: float=Upgrades.EFFECTS["vow-toad"].damage[plant.tier(1)]
	s._prepare_shot(shot,plant,damage)
	# Include the form's damage in the ordinary additive source bucket.
	shot.lantern_buff+=mode_bonus;shot.damage=s._shot_damage(shot)
	s.shots.append(shot);plant.action_at=s.time;plant.recoil=.7
	s.sfx("sign_shot")

func cycle_toad(plant) -> void:
	var s=owner_ref.get_ref()
	if plant.toad_mode=="hoard":plant.toad_mode="fire"
	elif plant.toad_mode=="fire" and plant.tier(3)>=3 and s.time>=plant.toad_overclock_ready_at:
		plant.toad_mode="overclock";plant.toad_overclock_until=s.time+12;plant.toad_overclock_ready_at=s.time+60
	else:plant.toad_mode="hoard"
	plant.toad_changed_at=s.time
	s.magic_effect("v070-toad-pact",plant.pos,140,.6)
	s.sfx("upgrade")

func coin_impact(shot,victim) -> void:
	var s=owner_ref.get_ref()
	var center:=Vector2(float(shot.tx),float(shot.ty)+14)
	if victim!=null:
		s.damage_zombie(victim,shot.damage*(2.0 if bool(shot.payload.get("toad_large",false)) and victim.is_large() else 1.0),false,false,shot.src,"",false,shot.kind,shot.owner_uid)
		s.apply_shot_statuses(victim,shot)
	var radius: float=shot.payload.get("coin_radius",0.0)
	for guest in s.zombies:
		if guest==victim or not guest.alive() or guest.pos.distance_to(center)>radius:continue
		if s._guest_airborne(guest) and not s._owner_air(shot.owner_uid):continue
		var amount: float=shot.damage*float(shot.payload.get("coin_splash",.5))
		if guest.is_large() and bool(shot.payload.get("toad_large",false)):amount*=2
		s.damage_zombie(guest,amount,false,false,shot.src,"",false,shot.kind,shot.owner_uid)
	if victim!=null:s.apply_shot_blast(shot,victim)
	s.magic_effect("v070-coin-burst",center,100,.45)

func transplant_reason(plant) -> String:
	var s=owner_ref.get_ref()
	if plant==null or plant.dead or plant.is_lily or plant.ash:return "请选择一株已在场的草木"
	if plant.chew_t>0 or not plant.secondary.is_empty() or not plant.tertiary.is_empty():return "正在收妖，暂时不能搬迁"
	if plant.skill_shots_left>0 or plant.mortar_burst_left>0 or plant.skill_effect_until>s.time:return "正在持续施法，暂时不能搬迁"
	if plant.squash_at>=0 or plant.dance_t>0 or plant.dragon_switch_until>s.time or plant.transplant_until>s.time:return "正忙着出手，稍等片刻再搬"
	return ""

func transplant(index: int,plant,col: int,row: int,at: Vector2) -> bool:
	var s=owner_ref.get_ref()
	var reason:=transplant_reason(plant)
	if not reason.is_empty():s.deny(reason,at);return false
	if index<0 or index>=s.cards.size() or s.cards[index].id!="root-palanquin":return false
	var card: Dictionary=s.cards[index]
	if s.time<s.curfew_until:s.deny("宵禁中，暂不能搬迁",at);return false
	if not s.no_cooldown and float(card.cd)>0:s.deny("迁根轿还没缓过手",at);return false
	var cost: int=s.card_cost(index)
	if s.sun<cost:s.deny("香火不够",at);return false
	# Validate occupancy/water/caps as a move, never as a new loss or new planting.
	var old_col: int=plant.col;var old_row: int=plant.row
	if old_col==col and old_row==row:s.deny("它已在这里，换个落脚处吧",at);return false
	s.cells[old_row][old_col]=null
	s._moving_existing=true
	var check: Dictionary=s.can_place_at(plant.type,col,row)
	s._moving_existing=false
	s.cells[old_row][old_col]=plant
	if not check.ok:s.deny(String(check.reason),at);return false
	var old_position: Vector2=plant.pos
	var old_drop: float=plant.cloud_drop
	s.sun-=cost;card.cd=0.0 if s.no_cooldown else float(card.def.cooldown);card.discount=0
	s.cells[old_row][old_col]=null;s.cells[row][col]=plant
	plant.col=col;plant.row=row;plant.pos=s.cell_pos(col,row)
	plant.cloud_group=-1;plant.cloud_cell=0;plant.cloud_drop=0;plant.cloud_scale=1.0
	s.chapter.attach(plant)
	plant.on_lily=s.lily_at(col,row)!=null
	plant.transplant_from=old_position;plant.transplant_started=s.time;plant.transplant_until=s.time+.9
	plant.transplant_from_drop=old_drop;plant.transplant_progress=0.0
	# Pointed marks follow the original living unit; moving does not wash them off.
	for encounter in s.active_bosses():
		for target in encounter.action.get("targets",[]):
			if int(target.c)==old_col and int(target.r)==old_row:
				target.c=col;target.r=row;target["host_uid"]=plant.uid
	s._banyan_cache_at=-1;s._collector_cache_at=-1
	s.refresh_plant_buffs();s.sfx("shell")
	return true

func serialize() -> Dictionary:
	return {"bloom_elapsed":bloom_elapsed,"bloom_skill_ready_at":bloom_skill_ready_at,"flares":flares.duplicate(true),"bloom_events":bloom_events.duplicate(true)}
func restore(data: Dictionary) -> void:
	bloom_elapsed=float(data.get("bloom_elapsed",0));bloom_skill_ready_at=float(data.get("bloom_skill_ready_at",0));flares=Array(data.get("flares",[])).duplicate(true);bloom_events=Array(data.get("bloom_events",[])).duplicate(true)
