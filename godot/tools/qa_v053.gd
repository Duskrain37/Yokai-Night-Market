extends SceneTree
var total := 0
var failed := 0
var checks: Array = []
func check(name: String, ok: bool) -> void:
	total += 1
	checks.append({"name":name,"ok":ok})
	if not ok:
		failed += 1
		printerr("FAIL ",name)
func battle(id := 1) -> Sim:
	var sim := Sim.new()
	sim.setup(Content.get_level(id),Content.PLANT_ORDER.duplicate(),"easy")
	return sim
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var s := battle()
	var target := s.spawn_zombie("ghost",2,{"x":s.cell_pos(3,2).x})
	var squash := s.place_free("squash",3,2)
	check("落地时已有目标立即蓄势",squash.squash_at>=0)
	for i in 50: s.tick(1.0/60.0)
	check("镇煞瓜完成扑击",squash.dead and not target.alive())
	s=battle()
	var dead := s.spawn_zombie("ghost",2,{"x":900})
	s.kill_zombie(dead)
	var next := s.spawn_zombie("ghost",2,{"x":800})
	next.hp=500
	var shot := Sim.Shot.new()
	shot.kind="homing";shot.src="cat";shot.pos=Vector2(700,next.pos.y-24);shot.target=dead;shot.dir=Vector2.RIGHT;shot.speed=300;shot.damage=24
	s._update_homing(shot,0.1)
	check("无转追次数时沿最后方向直飞",shot.kind=="drift" and not shot.dead and shot.target==null and shot.dir==Vector2.RIGHT)
	s._update_drifting(shot,0.6)
	check("失锁射弹仍能撞到沿途恶客",shot.dead and next.hp==476)
	shot=Sim.Shot.new();shot.kind="homing";shot.target=dead;shot.retarget=1;shot.pos=Vector2(650,next.pos.y-24);shot.speed=300
	s._update_homing(shot,0.01)
	check("有额外索敌机制时仍转追",shot.target==next and shot.kind=="homing")
	s=battle()
	var lamp := s.place_free("star",3,2)
	var guest := s.spawn_zombie("ghost",2,{"x":1000})
	s._update_star(lamp,10)
	check("基础即可齐发五道",s.shots.size()==5)
	var returning: Sim.Shot=s.shots[0]
	returning.pos=Vector2(Geo.BOARD_X-44,lamp.pos.y);returning.dir=Vector2.LEFT
	s._update_star_shot(returning,0.1)
	check("基础灯焰第一次到边界沿原路折返",not returning.dead and returning.dir==Vector2.RIGHT and returning.payload.get("returned",false))
	returning.pos=Vector2(Geo.RETREAT_MAX_X+44,lamp.pos.y)
	s._update_star_shot(returning,0.1)
	check("折返后第二次到边界消失",returning.dead)
	s.shots.clear();lamp.upgrades[3]=3;s._update_star(lamp,10)
	check("巡天满阶五直线加五追踪",s.shots.size()==10 and s.shots.filter(func(x):return x.kind=="homing").size()==5)
	s.shots.clear();lamp.upgrades[3]=0;lamp.upgrades[2]=3;lamp.star_guardian_until=s.time+10;s._update_star(lamp,10)
	check("惊动门神后获得额外200%伤害",s.shots.size()==5 and is_equal_approx(s.shots[0].damage,60.0))
	check("巡灯攻击间隔按原稿",is_equal_approx(float(Upgrades.EFFECTS.star.interval[1]),1.4) and is_equal_approx(float(Upgrades.EFFECTS.star.interval[3]),1.0))
	s=battle()
	var soup := s.place_free("lobber",3,2)
	var first := s.spawn_zombie("ghost",2,{"x":900})
	var last := s.spawn_zombie("ghost",2,{"x":1200})
	check("汤圆优先前方最左目标",s._lobber_target(soup)==first)
	first.dead=true;last.dead=true
	var friend := s.place_free("wall",0,2);friend.hp=2000
	soup.upgrades[3]=1
	s._update_lobber(soup,10)
	check("无敌人时温暖最左友方",s.shots.size()==1 and s.shots[0].payload.get("friend","")==friend.uid)
	var friendly: Sim.Shot=s.shots[0]
	s._update_lob_shot(friendly,2)
	check("友方汤圆无伤害且增伤12%",friend.hp==2000 and is_equal_approx(friend.buff_damage,0.12))
	s.time=4.1;s.refresh_plant_buffs()
	check("温暖按时到期",friend.buff_damage==0)
	s._soup_warm(friend,soup.uid,0.24,1e9)
	s._soup_warm(friend,"another",0.12,4)
	check("同类温暖取最高",is_equal_approx(friend.buff_damage,0.24))
	var restored := Sim.new();restored.restore(JSON.parse_string(JSON.stringify(s.serialize())))
	check("温暖跟随存档",is_equal_approx(restored.main_plant_at(0,2).buff_damage,0.24))
	s=battle()
	var bell := s.place_free("bell",3,2);bell.upgrades[3]=3
	friend=s.place_free("shooter",1,2);friend.hp=100;friend.sleep_until=100
	var different := s.place_free("shooter",1,1);different.hp=100;different.sleep_until=100
	s._update_bell(bell,10)
	check("清音唤醒同排身后的草木",friend.sleep_until<=s.time)
	check("养身为整行恢复55",friend.hp==155)
	check("清音不跨行",different.hp==100 and different.sleep_until==100)
	s=battle()
	var fire := s.place_free("torch",3,2);fire.upgrades[2]=3
	var producer := s.place_free("lantern",2,1)
	var other := s.place_free("torch",1,2);other.upgrades[2]=2
	var outside := s.place_free("lantern",6,1)
	s.refresh_plant_buffs()
	check("照明九格增产且同来源不叠加",s.lantern_value(producer)==31 and s.lantern_value(outside)==25)
	check("满阶照明加快生产10%",is_equal_approx(s.lantern_interval(producer),8.0/1.1))
	check("增产没有误算攻击增伤",producer.buff_damage==0)
	check("新耐久上限1500",Upgrades.EFFECTS.torch.max_hp[2]==1500)
	check("删去火盆旧灼烧与掉星",Upgrades.EFFECTS.torch.burn_dps==[0,0,0,0] and Upgrades.EFFECTS.torch.sparks_per_projectile==[0,0,0,0])
	check("透骨针基础与三阶伤害",Content.PLANTS.needle.needle.damage==24 and Upgrades.EFFECTS.needle.damage==[24,28,32,36])
	check("逐云鸢原稿费用与伤害",Content.PLANTS["sky-kite"].cost==200 and Upgrades.EFFECTS["sky-kite"].damage==[40,50,60,70])
	check("烬翼蝉消耗275",Content.PLANTS["ember-cicada"].cost==275)
	s=battle()
	var tough=s.spawn_zombie("mountain",2,{"x":s.cell_pos(3,2).x+15});tough.hp=2000
	var ready=s.place_free("squash",3,2)
	s.update_zombies(.1)
	check("已蓄势镇煞瓜不会在腾跃前被啃食",ready.hp==ready.max_hp and ready.squash_at>=0)
	var invalid=s.place_free("squash",5,1)
	s.spawn_zombie("bride",1,{"x":invalid.pos.x+30,"sedan_split":true});s._update_squash(invalid)
	check("镇煞瓜仍遵守灰烬免疫",invalid.squash_at<0)
	s=battle()
	lamp=s.place_free("star",3,2);lamp.upgrades[1]=3
	for i in 6:
		var prey=s.spawn_zombie("ghost",2,{"x":900});prey.hp=1
		var beam=Sim.Shot.new();beam.src="star";beam.owner_uid=lamp.uid;beam.damage=36
		s.time=i*.2;s._star_impact(beam,prey)
	check("巡灯激励最多五层且满层不刷新",lamp.star_morale_stacks==5 and is_equal_approx(lamp.star_morale_until,5.8))
	s=battle()
	lamp=s.place_free("star",3,2);lamp.upgrades[3]=1;guest=s.spawn_zombie("ghost",2,{"x":1000});s._update_star(lamp,10)
	var seeking:Sim.Shot=s.shots[0];seeking.pos.x=Geo.BOARD_X-50;s._update_star_shot(seeking,.01)
	check("巡天一阶边界变为半伤追魂",seeking.kind=="homing" and seeking.target!=null and seeking.damage==10)
	check("巡灯基础间隔与图鉴数据一致",Upgrades.EFFECTS.star.interval[0]==Content.PLANTS.star.star.interval)
	var mobile_motion:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/actor_motion_mobile.json"))
	check("既有手机版动作保留且PC仍支持",mobile_motion.keys().all(func(actor):return JSON.parse_string(FileAccess.get_file_as_string("res://data/actor_motion.json")).has(actor)))
	var split:Dictionary=mobile_motion["v053-buff-fx"]
	check("八种增益拆为独立32帧GPU图集",split.clip_files.size()==8 and split.clips.values().all(func(x):return x.size()==32))
	check("第三周通关衔接第四周，不误入特殊关",Content.next_story_level(15)==17 and Content.next_story_level(16)==0 and Content.next_story_level(26)==0)
	s=battle();bell=s.place_free("bell",3,2);bell.upgrades[3]=3;s.banner={};s.kill_plant(bell)
	check("取消旧满街铃退场报幕",s.banner.is_empty())
	var frames: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/actor_frames.json"))
	check("蒲舟客游泳裁切排除上一行腿部",frames.reedboat.clips.swim[0].rect[1]>710)
	var motion: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/actor_motion.json"))
	check("八种增益各有32帧",motion["v053-buff-fx"].clips.size()==8 and motion["v053-buff-fx"].clips.values().all(func(x):return x.size()==32))
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game.open_news();await process_frame
	check("公告默认打开更新页且两页导航",game.screen_node.page==0 and game.screen_node._tabs.size()==2)
	game.screen_node.select_page(1)
	check("下载反馈页可切换",game.screen_node.page==1)
	var output:=FileAccess.open("res://qa/v053-tests.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"total":total,"failures":failed,"checks":checks},"  "))
	print("V053 TOTAL ",total," FAILURES ",failed)
	quit(0 if failed==0 else 1)
