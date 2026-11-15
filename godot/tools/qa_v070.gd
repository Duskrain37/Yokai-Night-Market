extends SceneTree
var checks: Array = []
var failures := 0
func check(label: String, ok: bool) -> void:
	checks.append({"name":label,"ok":ok})
	if not ok: failures+=1; printerr("FAIL ",label)
func setup(week: int) -> Sim:
	var s := Sim.new()
	s.setup(Content.get_level(Content.level_id_for(week)),Content.PLANT_ORDER.duplicate(),"easy",7070)
	s.sun=100000
	return s
func _initialize() -> void: run.call_deferred()
func run() -> void:
	check("八周四十夜与原特殊关编号保持",Content.DAYS.size()==8 and Content.LEVELS.size()==41 and Content.get_level(16).special)
	for week in range(1,9):
		for night in 5:
			var level := Content.get_level(Content.level_id_for(week,night))
			check("%d-%d稳定编号与波数" % [week,night+1],level.day==week and Content.wave_groups(level)==[4,4,6,6,8][night])
		var picks := Content.loadout_tips(Content.DAYS[week-1].map)
		check("第%d周推荐覆盖全部在役草木" % week,picks.size()==Content.PLANT_ORDER.size() and Content.PLANT_ORDER.all(func(type):return type in picks))
	for week in range(6,9):
		for night in 5:
			var level := Content.get_level(Content.level_id_for(week,night))
			var old := Content.get_level(Content.level_id_for(5,night))
			var s := setup(week)
			s.setup(level,[],"easy",7070)
			check("%d-%d地形计入与第五周等总系数" % [week,night+1],is_equal_approx(level.threat,old.threat) and is_equal_approx(s.count_mul*s.hp_mul*Content.terrain_factor(level),old.threat))
	var s := setup(6)
	var groups := [0,0,0]
	for row in 6:
		for col in 9:
			var group: int = s.chapter.platform_group(col,row)
			if group>=0:groups[group]+=1
			elif col>=6:groups[2]+=1
	check("A十二格B十二格常驻十八格",groups==[12,12,18])
	for clock in [0.0,61.9,62.0,70.0,71.2,72.4,109.9,110.0,112.4,150.0,152.4]:
		s.time=clock
		var state: Dictionary=s.chapter.lift_state(clock)
		var count:=0
		for row in 6:
			for col in 9:
				if s.can_place_at("shooter",col,row).ok: count+=1
		check("云台时刻%.1f两台含云下均可种植" % clock,count==42)
	check("八秒预警起点",not s.chapter.lift_state(61.99).warning and s.chapter.lift_state(62).warning)
	check("起始两台皆上70秒落一台随后40秒轮换",s.chapter.lift_state(0).a==1 and s.chapter.lift_state(0).b==1 and s.chapter.lift_state(73).a==0 and s.chapter.lift_state(73).b==1 and s.chapter.lift_state(113).a==1 and s.chapter.lift_state(113).b==0)
	check("每30秒前后交换两格且中途连续",s.chapter.platform_start(0,0)==Vector2(0,0) and s.chapter.platform_start(0,33)==Vector2(2,0) and s.chapter.platform_start(1,33)==Vector2(0,3) and is_equal_approx(s.chapter.platform_start(0,31.5).x,1.0))
	s.time=0
	var p=s.place_free("shooter",0,0)
	var lantern=s.place_free("lantern",1,0);lantern.upgrades={1:0,2:0,3:3}
	var ally=s.place_free("shooter",7,0)
	s.refresh_plant_buffs()
	check("升起时正常给予增益",ally.buff_damage>0)
	s.time=71.2
	var old_timer: float=p.timer
	var old_hp: float=p.hp
	s.update_plants(.1);s.damage_plant(p,99999)
	check("移动中不出手不受伤",p.timer==old_timer and p.hp==old_hp)
	check("离场光环立即退出",ally.buff_damage==0)
	var saved: Dictionary=JSON.parse_string(JSON.stringify(s.serialize()))
	var restored:=Sim.new();restored.restore(saved)
	check("升降中读档保留草木及准确高度",restored.plants.size()==3 and is_equal_approx(restored.chapter.elevation(0,0),s.chapter.elevation(0,0)))
	s.time=73;s.update_plants(.1)
	var visitor=s.spawn_zombie("ghost",0,{"x":p.pos.x+20})
	check("降下后不能啃食但仍能升阶",s.eat_target(visitor)==null and s.upgrade_status(p,1).ok)
	var low_plant=s.place_free("wall",2,1)
	check("云下种植成功且保留可见深度",low_plant!=null and low_plant.cloud_drop>0 and low_plant.cloud_group==0)
	check("云下可以铲除",s.shovel_at(2,1).ok)
	s.time=113;s.chapter.sync_platforms();visitor.pos.x=1200;s.update_plants(.1)
	check("回台立即恢复就绪攻击且没有额外地形增伤",p.action_at==s.time and not s.shots.is_empty() and s.plant_on_stage(p) and is_equal_approx(p.buff_damage,float(Upgrades.EFFECTS.lantern.buff_damage[3])))
	check("草木跟台前移两格且格位归属同步",p.col==2 and is_equal_approx(p.pos.x,s.cell_pos(2,0).x) and s.main_plant_at(2,0)==p and s.main_plant_at(0,0)==null)
	s.time=121.5;s.chapter.sync_platforms()
	restored=Sim.new();restored.restore(JSON.parse_string(JSON.stringify(s.serialize())))
	check("升降与滑移同模型读档无跳变",restored.plants[0].pos.is_equal_approx(p.pos) and restored.plants[0].cloud_drop==p.cloud_drop)
	Geo.set_stage("day6")
	for plant in s.plants:
		if plant.dead:continue
		var polygon: PackedVector2Array = s.chapter.cell_polygon(plant.col,plant.row)
		var point: Vector2 = (polygon[0]+polygon[1]+polygon[2]+polygon[3])*.25
		check("移动/云下投影反选对应格位",s.cell_at_screen(point)==Vector2i(plant.col,plant.row))
	s=setup(7);s.time=12;s.chapter.event_start=6;s.chapter.event_mode="guide";s.chapter.event_pair=0
	var z=s.spawn_zombie("ghost",0,{"x":Geo.BOARD_X+7*Geo.CELL_W})
	s.chapter.try_route(z)
	check("借道真正进入斜巷",z.scene_route_active and z.scene_route_from==0 and z.scene_route_to==1)
	var before: float=z.hp
	s.damage_zombie(z,20,true)
	check("借道只承受半伤",is_equal_approx(before-z.hp,10))
	z.pos.x-=Geo.CELL_W*.25;s.chapter.step_route(z)
	check("斜巷四分之一连续坐标",is_equal_approx(z.pos.y,lerpf(s.row_y(0),s.row_y(1),.25)))
	restored=Sim.new();restored.restore(JSON.parse_string(JSON.stringify(s.serialize())))
	check("斜巷中途存档保持实际位置与减伤",restored.zombies[0].scene_route_active and restored.zombies[0].pos.is_equal_approx(z.pos))
	z.pos.x=Geo.BOARD_X+6*Geo.CELL_W;s.chapter.step_route(z)
	check("走完整条斜巷才完成换行",not z.scene_route_active and z.row==1 and z.pos.y==s.row_y(1))
	s=setup(8);s.time=10;s.chapter.event_start=0;s.chapter.market_pair=1
	var counts: Array=[0,0,0]
	for i in 10000: counts[int(s.choose_spawn_row("ghost")/2)]+=1
	check("开市客流约25/50/25且没有额外总量",counts[0] in range(2300,2700) and counts[1] in range(4800,5200) and counts[2] in range(2300,2700))
	var file:=FileAccess.open("res://qa/v070-mechanics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"total":checks.size(),"failures":failures,"checks":checks},"  "))
	print("V070 TOTAL ",checks.size()," FAILURES ",failures)
	quit(0 if failures==0 else 1)
