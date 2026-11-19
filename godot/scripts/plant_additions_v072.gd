extends RefCounted

const ORTH := [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]
const CORNERS := [Vector2i(-1,-1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(1,1)]
var owner: WeakRef
var brews := {}
var orchids := {}
var rain_blessings := {}
var rain_wet := {}
var droplets: Array = []

func _init(sim) -> void:
	owner=weakref(sim)

func clear() -> void:
	brews.clear();orchids.clear();rain_blessings.clear();rain_wet.clear();droplets.clear()

func save() -> Dictionary:
	return {"brews":brews,"orchids":orchids,"blessings":rain_blessings,"wet":rain_wet,"droplets":droplets}

func restore(data: Dictionary) -> void:
	brews=Dictionary(data.get("brews",{})).duplicate(true)
	orchids=Dictionary(data.get("orchids",{})).duplicate(true)
	rain_blessings=Dictionary(data.get("blessings",{})).duplicate(true)
	rain_wet=Dictionary(data.get("wet",{})).duplicate(true)
	droplets=Array(data.get("droplets",[])).duplicate(true)

static func primary(source: String, key: String, delivery: String) -> int:
	if source in ["five-brew","mower"] or key in ["burn_tick","fox_ignite","fox_graze","bleed_tick","brew_reaction","brew_cast"]:return 0
	if delivery=="area" or key.begins_with("ash_") or key in ["dragon_breath","lion_step","lion_brace","incense_blast","incense_primary","soup_burst","ground_area"]:return 8
	match delivery:
		"pea","star","drift":return 1
		"lob":return 2
		"homing":return 4
	if delivery=="" and source in ["bell","censer","bomb","mushroom","squash","ruin-cap","reed-chime"]:return 8
	return 0

func _guest_key(z) -> String:
	if z.boss_role!="body":return z.uid
	var s=owner.get_ref()
	return "boss:%s:%s:%d" % [s.boss.id if s.boss!=null else "",s.special_bosses_completed,int(z.boss_meta.get("encounter_slot",0))]

func _layers(m: Dictionary) -> int:
	var mask := int(m.get("mask",0))
	return int(bool(mask&1))+int(bool(mask&2))+int(bool(mask&4))+int(bool(mask&8))+int(m.get("extra",0))

func vulnerability(z, kind: int) -> float:
	var mark: Dictionary=brews.get(_guest_key(z),{})
	if not bool(mark.get("permanent",false)):return 1.0
	return 1.0 + _layers(mark)*(.25 if int(mark.mask)&kind else .10)

func _put_brew(guest, uid: String, t1: int, t2: int, t3: int, existing: Dictionary) -> Dictionary:
	var s=owner.get_ref()
	# The strongest matching mark is retained. Refreshing never restores spent reactions.
	var mark := existing
	if mark.is_empty():
		mark={"uid":uid,"p1":t1,"p2":t2,"p3":t3,"mask":0,"extra":int(t2>=3),"stage":0}
	elif String(mark.uid)==uid:
		mark.p1=t1;mark.p2=t2;mark.p3=t3
	mark.until=s.time+(18.0 if int(mark.p2)>=1 else 10.0)
	brews[_guest_key(guest)]=mark
	return mark

func _live_mark(z) -> Dictionary:
	var s=owner.get_ref()
	var key := _guest_key(z)
	var mark: Dictionary=brews.get(key,{})
	if not mark.is_empty() and not bool(mark.get("permanent",false)) and s.time>=float(mark.until):
		brews.erase(key);return {}
	return mark

func observe(guest, kind: int) -> void:
	if kind==0 or not guest.alive():return
	var mark := _live_mark(guest)
	if mark.is_empty() or bool(mark.get("permanent",false)):return
	if int(mark.mask)&kind:return
	mark.mask=int(mark.mask)|kind
	_resolve(guest,mark)

func update_brew(plant, dt: float) -> void:
	var s=owner.get_ref()
	plant.timer+=dt
	var interval: float=2.4/maxf(.1,plant.attack_rate())
	if plant.timer<interval:return
	var victim=s.lane_target(plant)
	if victim==null:
		plant.timer=interval;return
	plant.timer=maxf(0,plant.timer-interval)
	plant.action_at=s.time;plant.recoil=1
	plant.needle_shots+=1
	var bonus: bool=plant.tier(3)>=1 and plant.needle_shots%3==0
	s.ring(victim.pos+Vector2(0,-24),Color("#dbac6c"),.8*Geo.CELL_W,.5)
	s.spark(victim.pos+Vector2(0,-20),Color("#b0c283"),7)
	var seen := {}
	for guest in _circle(victim,.8):
		var key := _guest_key(guest)
		if seen.has(key):continue
		seen[key]=true
		var old := _live_mark(guest)
		if s.damage_zombie(guest,10.0*plant.damage_multiplier(),false,false,plant.type,"brew_cast",false,"special",plant.uid)<=0 or not guest.alive():continue
		var mark := _put_brew(guest,plant.uid,plant.tier(1),plant.tier(2),plant.tier(3),old)
		if bonus and not old.is_empty() and not bool(mark.get("permanent",false)) and _layers(mark)<4:
			mark.extra=int(mark.extra)+1
			_resolve(guest,mark)

func _circle(center, cells: float) -> Array:
	var s=owner.get_ref()
	var result := [center]
	for guest in s.zombies:
		if guest!=center and guest.alive() and (s._guest_airborne(center)==s._guest_airborne(guest)) and guest.pos.distance_to(center.pos)<=cells*Geo.CELL_W:
			result.append(guest)
	return result

func _resolve(guest, mark: Dictionary) -> void:
	var s=owner.get_ref()
	var count := _layers(mark)
	var key := _guest_key(guest)
	var p1 := int(mark.p1)
	var p2 := int(mark.p2)
	var p3 := int(mark.p3)
	if count<2:return
	if int(mark.stage)==0 and p3<2:
		mark.stage=1
		s.damage_zombie(guest,[95,130,165,200][p1],false,true,"five-brew","brew_reaction",false,"special",String(mark.uid))
		s.spark(guest.pos+Vector2(0,-40),Color("#f1cf8d"),8)
	if not guest.alive():return
	if int(mark.stage)<2 and count>=(2 if p3>=2 else 3):
		mark.stage=2
		if p1<3 and p3<3:brews.erase(key)
		_burst(guest,mark,float([230,330,430,530][p1]),1.0,false)
	if not guest.alive():return
	if p3>=3 and count>=3:
		mark.permanent=true
	elif p1>=3 and count>=4:
		brews.erase(key)
		_burst(guest,mark,1080.0,1.4,true)

func _burst(center, mark: Dictionary, amount: float, radius: float, final: bool) -> void:
	var s=owner.get_ref()
	var p2 := int(mark.p2)
	var uid := String(mark.uid)
	var state: Dictionary=orchids.get("brew:"+uid,{})
	var spread: bool=p2>=2 and not final and s.time>=float(state.get("spread_at",0))
	var spread_used := false
	var center_pos: Vector2=center.pos+Vector2(0,-22)
	s.ring(center_pos,Color("#e8b35d") if final else Color("#d2bb83"),radius*Geo.CELL_W,.72)
	s.spark(center_pos,Color("#ecb572"),24 if final else 13)
	s.sfx("bomb" if final else "censer")
	var hit := {}
	for guest in _circle(center,radius):
		var key := _guest_key(guest)
		if hit.has(key):continue
		hit[key]=true
		var until_key := "brew-hit:"+key
		var ratio := 1.0 if final or guest==center else .8
		if not final and s.time<float(orchids.get(until_key,0)):ratio*=.5
		if s.damage_zombie(guest,amount*ratio,false,true,"five-brew","brew_reaction",false,"special",uid)<=0:continue
		if not final:orchids[until_key]=s.time+1.5
		if not guest.alive() or final or p2<2:continue
		s.apply_slow(guest,2.5,.4,"five-brew")
		var old := _live_mark(guest)
		if guest==center:continue
		if old.is_empty() and spread:
			_put_brew(guest,uid,int(mark.p1),p2,int(mark.p3),old)
			spread_used=true
		elif not old.is_empty() and p2>=3 and not bool(old.get("permanent",false)) and _layers(old)<4:
			old.extra=int(old.extra)+1
	if spread_used:
		state.spread_at=s.time+2
		orchids["brew:"+uid]=state

func _orchid(plant) -> Dictionary:
	if not orchids.has(plant.uid):orchids[plant.uid]={"cells":{},"dew":0,"region":0.0}
	return orchids[plant.uid]

func _valid_ally(plant) -> bool:
	return plant!=null and not plant.dead and not plant.ash

func _symbio(plant) -> int:
	var count := 0
	var peak := 0
	for value in plant.upgrades.values():
		count+=int(value);peak=maxi(peak,int(value))
	return 2+int(count>=2)+int(peak>=3)

func _neighbors(plant) -> Dictionary:
	var s=owner.get_ref()
	var offsets := ORTH + (CORNERS if plant.tier(1)>=3 else [])
	var result := {}
	for dir in offsets:
		var col: int=plant.col+dir.x
		var row: int=plant.row+dir.y
		if col<0 or col>=Geo.COLS or row<0 or row>=s.rows:continue
		var tile: Dictionary=s.tile_at(col,row)
		var other=s.main_plant_at(col,row)
		var base=s.lily_at(col,row)
		var key := "%d:%d"%[col,row]
		if _valid_ally(other) and s.plant_on_stage(other):
			if plant.tier(2)>=1:result[key]={"uid":other.uid,"n":_symbio(other),"col":col,"row":row}
		elif other==null and tile.kind in ["land","water"] and (tile.kind!="water" or _valid_ally(base) or not s.shore.mat_on(col,row).is_empty()) and not s.shore.flooded(col,row) and s.chapter.placement(col,row).is_empty():
			result[key]={"uid":"","n":1,"col":col,"row":row}
	return result

func _stable_layout(plant) -> Dictionary:
	var s=owner.get_ref()
	var state := _orchid(plant)
	var now := _neighbors(plant)
	var prev: Dictionary=state.cells
	var good := {}
	for key in now:
		var item: Dictionary=now[key]
		var old: Dictionary=prev.get(key,{})
		item.at=float(old.at) if old.get("uid","?")==item.uid and old.get("n",0)==item.n else s.time+.55
		if s.time>=float(item.at):good[key]=item
	state.cells=now
	return good

func _contributors(plant, stable: Dictionary) -> Dictionary:
	var s=owner.get_ref()
	var result := {}
	if plant.tier(2)<1:return result
	if s.time<float(plant.skill_effect_until):
		for ally in s.plants:
			if ally!=plant and _valid_ally(ally):result[ally.uid]=_symbio(ally)
	else:
		for item in stable.values():
			if not String(item.uid).is_empty():result[item.uid]=int(item.n)
	return result

func discount(plant) -> float:
	if plant.type!="blank-orchid" or plant.tier(2)<1:return 1.0
	var count := _blank_count(_stable_layout(plant))
	return 1.0-.1*count

func _blank_count(stable: Dictionary) -> int:
	var count := 0
	for item in stable.values():count+=int(String(item.uid).is_empty())
	return count

func collect_bonuses() -> Dictionary:
	var s=owner.get_ref()
	var strong := {}
	var own := {}
	for plant in s.plants:
		if plant.type!="blank-orchid" or not s.plant_on_stage(plant) or plant.sleep_until>s.time or plant.sealed_until>s.time:continue
		var layout := _stable_layout(plant)
		var per: float=.10 if plant.tier(2)>=3 else .05
		var contributors := _contributors(plant,layout)
		if plant.tier(2)==0:
			var bonus: float=(.30 if plant.tier(1)>=3 else .15)*_blank_count(layout)
			own[plant.uid]=Vector2(bonus,bonus)
			continue
		var count := 0
		for uid in contributors:
			var n := int(contributors[uid])
			count+=n
			if plant.tier(2)<2:continue
			var gift: int=n*(2 if plant.skill_effect_until>s.time else 1)
			var vector := Vector2(gift*.10,gift*per)
			var old: Vector2=strong.get(uid,Vector2.ZERO)
			strong[uid]=Vector2(maxf(old.x,vector.x),maxf(old.y,vector.y))
		own[plant.uid]=Vector2(count*.10,count*per)
	var results := {}
	for ally in s.plants:
		if ally.dead:continue
		var total: Vector2=own.get(ally.uid,Vector2.ZERO)
		total+=Vector2(strong.get(ally.uid,Vector2.ZERO))
		results[ally.uid]=total
	return results

func update_orchid(plant, dt: float) -> void:
	var s=owner.get_ref()
	var state := _orchid(plant)
	var stable := _stable_layout(plant)
	var contributors := _contributors(plant,stable)
	if plant.tier(3)>=1:
		if (_blank_count(stable)>0 if plant.tier(2)==0 else not contributors.is_empty()):
			state.region=float(state.region)+dt
			var gap: float=4.0 if plant.tier(3)>=3 else 6.0
			if float(state.region)>=gap:
				state.region=float(state.region)-gap
				state.dew=mini(6,int(state.dew)+1)
		else:state.region=0.0
		_auto_rain(plant,state)
	plant.timer+=dt
	var interval: float=2.5/maxf(.1,plant.attack_rate())
	if plant.timer<interval:return
	var victim=s.lane_target(plant)
	if victim==null:
		plant.timer=interval;return
	plant.timer=maxf(0,plant.timer-interval)
	var shot=s.new_shot()
	shot.pos=plant.pos+Vector2(18,-30);shot.row=plant.row;shot.speed=430;shot.look="orchid"
	if victim.pos.x<plant.pos.x:shot.dir=Vector2.LEFT
	if plant.tier(1)>=1:
		var bonus := _blank_count(stable)
		if plant.tier(2)>0:
			var count := 0
			for n in contributors.values():count+=int(n)
			bonus=floori(count*.5)
		shot.pierce_left=2 if plant.tier(1)==1 else 3+bonus
		shot.pierce_factors=[1.0]
		for i in shot.pierce_left:
			shot.pierce_factors.append(.5 if plant.tier(1)==1 else minf(1.0,.5+bonus*.10))
	s._prepare_shot(shot,plant,14)
	s.shots.append(shot);plant.action_at=s.time;plant.recoil=.7
	s.sfx("needle_shot")

func on_orchid_hit(uid: String) -> void:
	var s=owner.get_ref()
	for plant in s.plants:
		if plant.uid!=uid or plant.dead or plant.tier(3)<1:continue
		var state := _orchid(plant)
		if s.time>=float(state.get("hit_at",0)):
			state.hit_at=s.time+(2 if plant.tier(3)>=3 else 3)
			state.dew=mini(6,int(state.dew)+1)
		return

func _auto_rain(plant, state: Dictionary) -> void:
	if int(state.dew)<3:return
	var s=owner.get_ref()
	var available: Array = s.plants.filter(func(p): return _valid_ally(p) and s.chapter.deck_exposed(p) and not droplets.any(func(drop): return drop.uid == p.uid))
	var hurt: Array = available.filter(func(p): return p.hp < p.max_hp * .5)
	hurt.sort_custom(func(a,b): return a.hp/a.max_hp < b.hp/b.max_hp)
	var nearest: Array = available.filter(func(p): return p not in hurt and not nourished(p))
	nearest.sort_custom(func(a,b): return a.pos.distance_squared_to(plant.pos) < b.pos.distance_squared_to(plant.pos))
	var candidates: Array = hurt + nearest
	if candidates.is_empty(): return
	state.dew=int(state.dew)-3
	for i in mini(candidates.size(), 2 if plant.tier(3)>=3 else 1):
		_drop(plant,candidates[i], false, i*.16)

func _drop(plant,target, all: bool, delay: float = 0) -> void:
	var s=owner.get_ref()
	var from: Vector2=target.pos+Vector2(0,-143) if all else plant.pos+Vector2(0,-55)
	droplets.append({"uid":target.uid,"from":[from.x,from.y],"start":s.time+delay,"end":s.time+delay+(.65 if all else .58),"bless":plant.tier(3)>=2})

func cast_orchid(plant) -> void:
	var s=owner.get_ref()
	if plant.tier(2)>=3:
		plant.skill_effect_until=s.time+8
		s.ring(plant.pos+Vector2(0,-30),Color("#7fbba0"),160,.9)
	else:
		for ally in s.plants:
			if _valid_ally(ally):_drop(plant,ally,true)
	s.sfx("herb_heal")

func tick() -> void:
	var s=owner.get_ref()
	for key in brews.keys():
		var mark: Dictionary=brews[key]
		if not key.begins_with("boss:") and s.guest_uid(key)==null:brews.erase(key)
		elif not bool(mark.get("permanent",false)) and s.time>=float(mark.until):brews.erase(key)
	for key in orchids.keys():
		if key.begins_with("brew-hit:") and s.time>=float(orchids[key]):orchids.erase(key)
	for uid in rain_blessings.keys():
		if s.time>=float(rain_blessings[uid]):rain_blessings.erase(uid)
	for uid in rain_wet.keys():
		if s.time >= float(rain_wet[uid]): rain_wet.erase(uid)
	var pending := []
	for drop in droplets:
		if s.time<float(drop.end):
			pending.append(drop);continue
		for plant in s.plants:
			if plant.uid!=drop.uid or not _valid_ally(plant):continue
			if not s.chapter.deck_exposed(plant):
				# Rain reaches plants on a submerged deck, but still uses the normal HP cap.
				s.heal_plant(plant,maxf(200,plant.max_hp*.1),false,true)
			else:s.heal_plant(plant,maxf(200,plant.max_hp*.1))
			rain_wet[plant.uid] = s.time + 8
			if drop.bless:rain_blessings[plant.uid]=s.time+8
			break
	droplets=pending

func nourished(plant) -> bool:
	return float(rain_wet.get(plant.uid,0)) > owner.get_ref().time or blessed(plant)

func blessed(plant) -> bool:
	return float(rain_blessings.get(plant.uid,0))>owner.get_ref().time
