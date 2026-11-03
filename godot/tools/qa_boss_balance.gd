## Isolated, disclosed mature-army fixture, not a full-route or human playtest.
extends SceneTree
static func army(id: int,seed_value: int,profile: String="reference") -> Sim:
	var s=Sim.new()
	s.setup(Content.get_level(id),QaBot.LOADOUT.duplicate(),"normal")
	s.rng.seed=seed_value
	s.time=500
	for col in 7:
		for row in s.rows:
			if String(s.tile_at(col,row).kind) in ["blocked","object"]:continue
			if String(s.tile_at(col,row).kind)=="water":s.place_free("lily",col,row)
			var type=["lantern","lantern","shooter","shooter","wall","censer","umbrella"][col]
			var p=s.place_free(type,col,row)
			if p==null:continue
			if col==2:p.upgrades={1:{"low":1,"reference":2,"high":3}[profile],2:0,3:0}
			if col==3:p.upgrades={1:{"low":0,"reference":1,"high":2}[profile],2:0,3:0}
			s.apply_hp_scale(p)
			for path in Upgrades.paths_for(type):
				for i in p.tier(int(path.id)):p.paid_incense+=int(path.tiers[i].cost)
	s.sun=500
	s.refresh_plant_buffs()
	s.wave_index=s.level.waves.size()-3
	s.queue_wave(s.level.waves[s.wave_index],s.wave_index)
	return s
func _init() -> void:
	var results: Array=[]
	var failures=0
	for id in [5,10,15]:
		for profile in ["low","reference","high"]:
			for seed_value in [7,19,41]:
				var s=army(id,seed_value,profile)
				var rng=RandomNumberGenerator.new();rng.seed=seed_value
				var won=[false];var lost=[false]
				s.on_win=func():won[0]=true
				s.on_lose=func(_z):lost[0]=true
				var initial_cost=0
				for p in s.plants:initial_cost+=p.paid_incense
				for i in int(240*60):
					s.tick(1.0/60.0);s.sounds.clear();s.sound_detail.clear()
					if i%30==0:QaBot.strategy(s,rng)
					if won[0] or lost[0]:break
				var b=s.boss
				var row={"stage":id,"profile":profile,"seed":seed_value,"fixture_cost":initial_cost,"won":won[0],"lost":lost[0],
					"combat_s":snappedf((b.died_at if b.died_at>=0 else s.time)-b.combat_at,.1),"hp":b.hp,"max_hp":b.max_hp,
					"direct_losses":b.destruction_used,"majors":b.major_count,"adds":b.add_count,"peak_adds":b.peak_adds}
				print(JSON.stringify(row));results.append(row)
				if not won[0] or b.destruction_used>int(b.config.destruction_budget):failures+=1
				if profile=="reference" and (row.combat_s<105 or row.combat_s>135):failures+=1
	var f=FileAccess.open("res://qa/boss-balance.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"scope":"isolated mature army, normal; legitimate upgrade tiers, supplied fixture; not human/full-route","runs":results,"failures":failures},"  "))
	quit(0 if failures==0 else 1)
