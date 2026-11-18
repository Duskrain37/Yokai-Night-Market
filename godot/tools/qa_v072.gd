extends SceneTree
const Nightmare=preload("res://data/nightmare.gd")

var total := 0
var bad := 0

func check(label: String, ok: bool) -> void:
	total+=1
	if not ok:bad+=1;printerr("FAIL ",label)

func fresh(week: int=1, factors: Dictionary={}) -> Sim:
	var level:=Content.get_level(Content.level_id_for(week)).duplicate(true)
	level.nightmare_factors=factors
	var s:=Sim.new()
	s.setup(level,["five-brew","blank-orchid","shooter","wall","lily"],"nightmare" if not factors.is_empty() else "normal",72)
	return s

func guest(s: Sim, type: String, row: int, x: float=900):
	var z=s.spawn_zombie(type,row,{"x":x})
	z.hp=10000;z.max_hp=10000
	return z

func _initialize():
	run.call_deferred()

func run() -> void:
	var s:=fresh()
	var foe=guest(s,"shieldguard",2)
	foe.armor=440
	s.damage_zombie(foe,100,false,false,"shooter","",false,"pea")
	check("常规射弹先打盾牌",foe.hp==10000 and foe.armor==340)
	s.damage_zombie(foe,100,false,false,"needle","",false,"pea","",false,true)
	check("穿透射弹对盾牌本体各100",foe.hp==9900 and foe.armor==240)
	s.damage_zombie(foe,90,false,false,"sky-mortar","ash_mortar",false,"lob")
	check("灰烬对盾牌本体各90",foe.hp==9810 and foe.armor==150)
	s.damage_zombie(foe,60,false,false,"lobber","",false,"lob")
	check("普通抛弹仍直接打持牌鬼",foe.hp==9750 and foe.armor==150)
	var internal=guest(s,"stonehat",1)
	internal.armor=350
	s.damage_zombie(internal,100,false,false,"bomb","ash_area")
	check("内置石帽仍能阻断范围直伤",internal.hp==10000 and internal.armor==250)
	var river:=fresh(3)
	var boat=guest(river,"oar-barge",3)
	boat.armor=55
	river.damage_zombie(boat,100,false,true,"needle","",false,"pea")
	check("击沉外置舟的余量不重复灌给本体",boat.hp==9900 and boat.armor==0)
	s=fresh()
	var brew=s.place_free("five-brew",2,2)
	foe=guest(s,"ghost",2)
	var near=guest(s,"ghost",2,990)
	s.v072.update_brew(brew,2.39)
	check("未到2.4秒不挂印",s.v072.brews.is_empty())
	s.v072.update_brew(brew,.011)
	check("基础特殊伤害10，0.8格外不挂",foe.hp==9990 and near.hp==10000 and s.v072.brews.has(foe.uid))
	s.damage_zombie(foe,10,false,false,"shooter","",false,"pea")
	s.damage_zombie(foe,10,false,false,"needle","",false,"pea")
	check("同类射弹不重复计数",foe.hp==9970)
	s.damage_zombie(foe,10,false,false,"lobber","",false,"lob")
	check("两类开酿，95单体",foe.hp==9865 and near.hp==10000)
	s.damage_zombie(foe,10,false,false,"cat","",false,"homing")
	check("三类酿成230及80%一格溅射",foe.hp==9625 and near.hp==9816 and not s.v072.brews.has(foe.uid))
	s=fresh();brew=s.place_free("five-brew",2,2);brew.upgrades={1:3,2:0,3:0}
	foe=guest(s,"ghost",2)
	s.v072.update_brew(brew,2.401)
	for kind in ["pea","lob","homing","area"]:s.damage_zombie(foe,10,false,false,"shooter","",false,kind)
	check("火候满阶四类开酿酿成大成",foe.hp==8140 and not s.v072.brews.has(foe.uid))
	s=fresh();brew=s.place_free("five-brew",2,2);brew.upgrades={1:0,2:3,3:0}
	foe=guest(s,"ghost",2)
	near=guest(s,"ghost",2,990)
	s.v072.update_brew(brew,2.401)
	check("散香满阶标记18秒且自带一层",s.v072.brews[foe.uid].until==18 and s.v072.brews[foe.uid].extra==1)
	for kind in ["pea","lob"]:s.damage_zombie(foe,10,false,false,"shooter","",false,kind)
	check("扩散酿印与40%减速",s.v072.brews.has(near.uid) and is_equal_approx(near.slow_amount,.4) and is_equal_approx(near.slow_t,2.5))
	s=fresh();brew=s.place_free("five-brew",2,2);brew.upgrades={1:0,2:0,3:3}
	foe=guest(s,"ghost",2)
	s.v072.update_brew(brew,2.401)
	s.damage_zombie(foe,10,false,false,"shooter","",false,"pea")
	s.damage_zombie(foe,10,false,false,"lobber","",false,"lob")
	check("调味二层直接酿成",foe.hp==9740)
	s.damage_zombie(foe,10,false,false,"cat","",false,"homing")
	check("三类永久酿印",s.v072.brews[foe.uid].permanent)
	var h: float=foe.hp
	s.damage_zombie(foe,100,false,false,"shooter","",false,"pea")
	s.damage_zombie(foe,100,false,false,"bomb","ash_area")
	check("已记类型易伤75%且其他类型30%",h-foe.hp==305)
	var resumed:=Sim.new()
	resumed.restore(JSON.parse_string(JSON.stringify(s.serialize())))
	check("永久酿印随存档往返",resumed.v072.brews[foe.uid].permanent)
	s=fresh();var plant=s.place_free("blank-orchid",3,2)
	s.refresh_plant_buffs()
	check("初植留白先等稳定",plant.buff_damage==0)
	s.time=.56;s.refresh_plant_buffs()
	check("中间四空位，伤害攻速各60%",is_equal_approx(plant.buff_damage,.6) and is_equal_approx(plant.haste,.6))
	plant.upgrades={1:3,2:0,3:0};s.refresh_plant_buffs();s.time=1.2;s.refresh_plant_buffs()
	check("长叶三阶八个方向每层30%",is_equal_approx(plant.buff_damage,2.4) and is_equal_approx(plant.haste,2.4))
	guest(s,"ghost",2);s.v072.update_orchid(plant,3)
	check("满留白穿透11次，后续100%",s.shots[0].pierce_left==11 and float(s.shots[0].pierce_factors[-1])==1.0)
	plant.upgrades={1:0,2:3,3:0}
	var ally=s.place_free("shooter",4,2);ally.upgrades={1:3,2:0,3:0}
	var remote=s.place_free("shooter",0,4)
	s.refresh_plant_buffs();s.time+=.6;s.refresh_plant_buffs()
	check("四层本地共生送回贡献者",is_equal_approx(plant.buff_damage,.4) and is_equal_approx(ally.buff_damage,.4))
	check("三留白降低升阶价30%",s.upgrade_status(plant,1).cost==70)
	check("兰庭同息全场双倍回馈与70秒冷却",s.activate_skill(plant) and is_equal_approx(remote.buff_damage,.4) and is_equal_approx(ally.haste,.8) and s.active_skill_status(plant).left==70)
	s.time+=8.1;s.refresh_plant_buffs()
	check("全场共生届时消退",remote.buff_damage==0)
	s=fresh();plant=s.place_free("blank-orchid",2,2);plant.upgrades={1:0,2:0,3:3}
	ally=s.place_free("wall",4,2);ally.hp=90
	check("天降甘霖独立图标未借用同息",s.active_skill_status(plant).id=="orchid-rain" and ResourceLoader.exists(s.active_skill_status(plant).icon))
	check("全场送雨露，抵达前无治疗",s.activate_skill(plant) and ally.hp==90 and s.v072.droplets.size()==2)
	s.time=.7;s.v072.tick()
	check("雨露按目标最大耐久治疗，减伤与双加成",ally.hp==90+maxf(200,ally.max_hp*.1) and is_equal_approx(s.plant_guard(ally),.3) and s.v072.blessed(ally))
	check("天降甘霖冷却60秒",is_equal_approx(plant.skill_ready_at,60))
	s=fresh(7);plant=s.place_free("blank-orchid",8,2);s.refresh_plant_buffs();s.time=1;s.refresh_plant_buffs()
	check("不可种通道和边界不算留白",is_equal_approx(plant.buff_damage,.30))
	for type in Content.ZOMBIE_ORDER:
		var home:=int(Content.ZOMBIES[type].get("home_week",0))
		if home==0:continue
		var seen:=false
		for level in Content.LEVELS:
			var present: bool=Content.plants_in_level(level).has(type)
			if present and not level.get("special",false) and level.day==home:seen=true
			check("%s关%d限定周"%[type,level.id],not present or (not level.get("special",false) and level.day==home))
		check(type+"限定周实际进入来客表",seen and Almanac.ZOMBIES.has(type))
	for week in [1,6,7,8]:
		var level:=Content.get_level(Content.level_id_for(week))
		for id in ["cloud_silence","cloud_immediate","troupe_fervor","troupe_encore","lamp_ward","lamp_crowd"]:
			var home: int={"cloud":6,"troupe":7,"lamp":8}[id.get_slice("_",0)]
			check("噩梦因子按地图筛选 "+id+" "+str(week),Nightmare.sanitize({id:1},level).has(id)==(home==week))
	s=fresh(6)
	var lamp=s.place_free("lantern",0,0)
	var cannon=s.place_free("shooter",1,0)
	s.time=73
	check("沉云仅产能正常",s.plant_on_stage(lamp) and not s.plant_on_stage(cannon) and not s.chapter.deck_exposed(lamp))
	lamp.timer=100;s.update_plants(.01)
	check("沉云红灯笼实际产香火",s.orbs.size()==1)
	s=fresh(6,{"cloud_immediate":1,"cloud_silence":1})
	lamp=s.place_free("lantern",0,0)
	check("开局立刻降台",s.chapter.lift_state(0).moving and s.chapter.lift_state(0).direction_a<0)
	s.time=4
	check("因子关停沉云产能",not s.plant_on_stage(lamp))
	s=fresh(7,{"troupe_fervor":1,"troupe_encore":1})
	foe=guest(s,"ghost",0,Geo.BOARD_X+7*Geo.CELL_W)
	s.wave_index=1;s.time=float(s.level.waves[0].t);s.chapter.tick(0)
	check("戏班间隔缩短一半",is_equal_approx(s.chapter.theatre_encore_at-s.time,(float(s.level.waves[3].t)-s.time)*.5))
	s.chapter.event_mode="haste";s.time=s.chapter.event_start+7
	check("催场双倍速度，引路受伤25%",s.chapter.haste_multiplier(foe)==2 and s.chapter.route_damage_multiplier()==.25)
	s=fresh(8,{"lamp_ward":1,"lamp_crowd":1})
	s.chapter.begin_market(1);s.chapter.begin_market(2);s.chapter.begin_market(0)
	s.time=9
	var total_guests:=0
	for i in 8:total_guests+=s.spawn_market_arrivals("ghost",2)
	check("第三次亮灯，8个入场名额变12名并均分六路",total_guests==12 and s.zombies.size()==12 and range(6).all(func(r):return s.zombies.filter(func(z):return z.row==r).size()==2))
	foe=s.zombies.front();var before: float=foe.hp
	s.damage_zombie(foe,100,false,false,"shooter","",false,"pea")
	check("三灯齐明的六路都获20%减伤",before-foe.hp==80 and s.zombies.all(func(z):return s.chapter.market_ward_multiplier(z)==.8))
	var audio_game=preload("res://scripts/game.gd").new()
	audio_game.sim=Sim.new()
	audio_game.sim.setup(Content.get_level(Content.SPECIAL_ID),[],"normal",72)
	for i in 8:
		audio_game.sim.special_bosses_completed=i
		for major in 4:
			audio_game.sim.wave_index=12*i+3*major+1
			check("鬼市深处第%d段第%d波战曲段落"%[i+1,major+1],audio_game.wave_phase()==("battle" if major<2 else "hot"))
	audio_game.free()
	print("V072 TOTAL ",total," FAILURES ",bad)
	quit(1 if bad else 0)
