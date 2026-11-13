extends SceneTree
var checks: Array = []
var failures := 0
func check(name: String, ok: bool):
	checks.append({"name": name, "ok": ok})
	if not ok: failures += 1; printerr("FAIL ",name)
func fresh(id: int = 1) -> Sim:
	var s := Sim.new(); s.setup(Content.get_level(id), Content.PLANT_ORDER.duplicate(), "normal", 600)
	s.hp_mul = 1; s.count_mul = 1
	return s
func guest(s: Sim, type: String = "ghost", x: float = 1080, row: int = 2) -> Sim.Zombie:
	return s.spawn_zombie(type,row,{"x":x,"sedan_split":true})
func shell(s: Sim, plant: Sim.Plant, target: Sim.Zombie) -> Sim.Shot:
	s._mortar_launch(plant,target.pos)
	return s.shots[-1]
func _initialize(): run.call_deferred()
func run():
	check("本次草木仍为32株",Content.PLANT_ORDER.size()==32)
	check("本次恶客新增2种，共29种",Content.ZOMBIE_ORDER.size()==29 and Content.ZOMBIES.size()==29)
	var spawns := fresh()
	for i in 300:
		var incoming := spawns.spawn_zombie("ghost", i % spawns.rows)
		check("出怪缓冲不超过半格",incoming.pos.x >= Geo.BOARD_X + Geo.BOARD_W and incoming.pos.x <= Geo.SPAWN_X and is_equal_approx(Geo.SPAWN_BUFFER,Geo.CELL_W*.5))
	var s := fresh(); var z := guest(s,"incense-thief"); s.sun=100
	s.time=4.99; s._step_incense_thief(z); check("首次五秒前不偷",s.sun==100)
	s.time=5; var stopped := s._step_incense_thief(z)
	check("首次偷35且原地施法",s.sun==65 and z.stolen_incense==35 and z.theft_count==1 and stopped)
	s.time=5.86; check("施法结束恢复移动",not s._step_incense_thief(z))
	s.time=12; s._step_incense_thief(z); check("第二次偷35炼化15",s.sun==30 and z.stolen_incense==55)
	s.time=19; s._step_incense_thief(z); check("余额不足35扣至零仅记录实扣",s.sun==0 and z.stolen_incense==70)
	s.time=26; s._step_incense_thief(z); check("空手也仅炼化既有香火",s.sun==0 and z.stolen_incense==55)
	var copy := Sim.new(); copy.restore(JSON.parse_string(JSON.stringify(s.serialize())))
	check("窃取数量和次数随档保存",copy.zombies[0].stolen_incense==55 and copy.zombies[0].theft_count==4 and copy.zombies[0].theft_ready_at==33)
	s.kill_zombie(z); check("死亡仅掉落未炼化量",s.orbs.size()==1 and s.orbs[0].value==55 and z.stolen_incense==0)
	s.kill_zombie(z); check("重复死亡不重复掉落",s.orbs.size()==1)
	s.collect_orb(s.orbs[0]); check("返还可拾取",s.sun==55)
	s=fresh(); z=guest(s,"incense-thief"); z.silence_until=10; s.time=5; s.sun=20
	s._step_incense_thief(z); check("沉默阻止窃取",s.sun==20 and z.theft_count==0)
	s.time=10; s._step_incense_thief(z); check("沉默后恢复且不产生负值",s.sun==0 and z.stolen_incense==20)
	for passenger_type in ["ghost","mountain","incense-thief"]:
		s=fresh(); var rider:=guest(s,passenger_type,1000); var ferry:=guest(s,"sky-ferry",1025)
		s._step_sky_wick(ferry,.1)
		check("可搭载普通和大型/"+passenger_type,rider.carrier_uid==ferry.uid and ferry.passenger_uid==rider.uid and ferry.pickup_used and s._guest_airborne(rider))
		copy=Sim.new(); copy.restore(JSON.parse_string(JSON.stringify(s.serialize())))
		var loaded:=copy.guest_uid(ferry.uid); var restored:=copy.guest_uid(rider.uid)
		check("载客关系随档恢复/"+passenger_type,loaded!=null and restored!=null and loaded.passenger_uid==restored.uid and copy._guest_airborne(restored))
		var hp_before:float=rider.hp
		s.damage_zombie(rider,20,false,false,"shooter","",false,"pea")
		check("乘客升空后普通射弹不可命中/"+passenger_type,rider.hp==hp_before)
		ferry.armor=0; s.break_armor(ferry)
		check("破甲两者落地/"+passenger_type,not s._guest_airborne(rider) and not s._guest_airborne(ferry) and rider.carrier_uid=="" and ferry.passenger_uid=="")
		s.time+=1; var another:=guest(s,"ghost",ferry.pos.x); s._step_sky_wick(ferry,.1)
		check("同一轿夫不重复载客/"+passenger_type,another.carrier_uid=="")
	s=fresh(); var rider:=guest(s,"ghost",1000); var ferry:=guest(s,"sky-ferry",1020)
	s._try_pickup(ferry); ferry.pos.x=Geo.BREACH_X+4*Geo.CELL_W-1; s._step_sky_wick(ferry,0)
	check("门神前四格自动落地",ferry.flight_landing_at>=0 and rider.carrier_uid=="")
	s=fresh(); rider=guest(s,"ghost",1000); ferry=guest(s,"sky-ferry",1020); s._try_pickup(ferry)
	s.kill_zombie(ferry,false,true); check("轿夫灰烬退场也释放乘客",rider.alive() and rider.carrier_uid=="" and not s._guest_airborne(rider))
	s=fresh(); rider=guest(s,"ghost",1000); ferry=guest(s,"sky-ferry",1020); s._try_pickup(ferry)
	s.kill_zombie(rider); check("乘客先退场清理轿夫关系",ferry.passenger_uid=="")
	s=fresh(); var plant:=s.place_free("sky-mortar",2,2)
	z=guest(s,"shieldguard"); var armor:float=z.armor; var hp:float=z.hp
	s._mortar_impact(shell(s,plant,z)); check("基础炮弹绕过持牌鬼盾牌",z.armor==armor and is_equal_approx(z.hp,hp-215))
	z=guest(s,"ghost"); z.hp=1; s._mortar_impact(shell(s,plant,z))
	check("基础炮弹灰烬击退不留尸",z.dead and not z.dying)
	s=fresh(); plant=s.place_free("sky-mortar",2,2); z=guest(s,"sky-wick")
	check("基础不索敌空中",s._mortar_aim(plant)==null)
	hp=z.hp; armor=z.armor; s._mortar_impact(shell(s,plant,z))
	check("基础溅射不误伤空中",z.hp==hp and z.armor==armor)
	plant.upgrades={1:0,2:0,3:1}; check("看破解锁空中索敌",s._mortar_aim(plant)==z)
	s._mortar_impact(shell(s,plant,z)); check("看破能命中空中护具",z.armor==armor-215)
	s=fresh(11); plant=s.place_free("sky-mortar",2,0); z=guest(s,"reedboat",1000,1)
	check("基础允许水中目标",s._mortar_aim(plant)==z)
	s=fresh(); plant=s.place_free("sky-mortar",2,2); z=guest(s,"bride"); z.hp=10000
	s._mortar_impact(shell(s,plant,z)); check("基础灰烬遵守鬼新娘免疫",z.hp==10000)
	plant.upgrades={1:0,2:0,3:1}; s._mortar_impact(shell(s,plant,z))
	check("看破优先于鬼新娘灰烬免疫",z.hp==9785)
	z=guest(s,"formless"); z.def=z.def.duplicate(); z.def.miss_chance=1.0; z.hp=10000
	s._mortar_impact(shell(s,plant,z)); check("看破不能被闪避",z.hp==9785)
	plant.upgrades={1:0,2:0,3:2}; z=guest(s); z.hp=10000; s.shots.clear()
	s._mortar_impact(shell(s,plant,z))
	var fragments:Array=s.shots.filter(func(q):return q.look=="mortar-fragment")
	check("每次命中生成八片射弹",fragments.size()==8)
	var directions:Dictionary={}
	for fragment in fragments:
		directions[str(fragment.dir)]=true
		check("弹片45与签筒三分之二速度",fragment.damage==45 and is_equal_approx(fragment.speed,520.0*2/3))
	check("弹片八向发散",directions.size()==8)
	s=fresh();plant=s.place_free("sky-mortar",2,2);plant.upgrades={1:0,2:0,3:2};z=guest(s,"shieldguard");z.hp=10000
	s._mortar_impact(shell(s,plant,z));armor=z.armor;hp=z.hp
	var shard:Sim.Shot=s.shots[1];shard.pos=z.pos-Vector2(40,24);shard.dir=Vector2.RIGHT
	s._update_drifting(shard,.2)
	check("弹片属于射弹会被护身牌挡住",z.armor==armor-45 and z.hp==hp)
	s=fresh(); plant=s.place_free("sky-mortar",2,2); plant.upgrades={1:0,2:0,3:3}; z=guest(s); z.hp=10000
	check("主动首次可用",s.active_skill_status(plant).ready and s.activate_skill(plant))
	check("主动首发660并立刻冷却",s.shots.size()==1 and s.shots[0].damage==660 and is_equal_approx(plant.mortar_active_ready_at,55))
	s.time=.249; s._update_mortar(plant,0); check("未到0.25秒不提前补炮",s.shots.size()==1)
	for i in range(1,7): s.time=i*.25; s._update_mortar(plant,0)
	check("主动恰好七发每发660",s.shots.size()==7 and s.shots.all(func(q):return q.damage==660 and q.look=="mortar-heavy") and plant.mortar_burst_left==0)
	check("冷却中不能重复施放",not s.activate_skill(plant) and s.shots.size()==7)
	copy=Sim.new(); copy.restore(JSON.parse_string(JSON.stringify(s.serialize())))
	var restored_plant=copy.main_plant_at(2,2)
	check("主动冷却随存档保存",restored_plant.mortar_active_ready_at==55 and not copy.active_skill_status(restored_plant).ready)
	var burst_save:=fresh();var burst_plant:=burst_save.place_free("sky-mortar",2,2);burst_plant.upgrades={1:0,2:0,3:3};guest(burst_save)
	burst_save.activate_skill(burst_plant);burst_save.time=.25;burst_save._update_mortar(burst_plant,0)
	var resumed:=Sim.new();resumed.restore(JSON.parse_string(JSON.stringify(burst_save.serialize())))
	var resumed_plant=resumed.main_plant_at(2,2)
	for i in range(2,7):resumed.time=i*.25;resumed._update_mortar(resumed_plant,0)
	check("主动连发中读档不重复不丢炮",resumed.shots.size()==7 and resumed_plant.mortar_burst_left==0 and resumed_plant.mortar_active_ready_at==55)
	s.time=54.99; check("55秒前不可用",not s.active_skill_status(plant).ready)
	s.time=55; check("55秒准时恢复",s.active_skill_status(plant).ready)
	s=fresh(); plant=s.place_free("sky-mortar",2,2); plant.upgrades={1:3,2:0,3:3}; z=guest(s)
	s.activate_skill(plant); check("主动重炮不受连炮减伤",s.shots[0].damage==660)
	s=fresh(); plant=s.place_free("sky-mortar",2,2); plant.upgrades={1:0,2:0,3:3}
	check("无目标不消耗主动冷却",not s.activate_skill(plant) and plant.mortar_active_ready_at==0)
	var catalog=JSON.parse_string(FileAccess.get_file_as_string("res://data/actor_motion.json"))
	for actor in ["incense-thief","sky-ferry"]:
		check("新恶客连续动画存在/"+actor,catalog.has(actor))
		for clip in catalog[actor].clips:
			check("每段32帧/"+actor+"/"+clip,catalog[actor].clips[clip].size()==32)
	var f:=FileAccess.open("res://qa/v060-tests.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"total":checks.size(),"failures":failures,"checks":checks},"  "));f.close()
	print("V060 TOTAL ",checks.size()," FAILURES ",failures)
	quit(0 if failures==0 else 1)
