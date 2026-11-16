extends SceneTree
const Numbers=preload("res://scripts/combat_numbers.gd")
var checks:Array=[]
var failures:=0
func check(label:String,ok:bool):
	checks.append({"name":label,"ok":ok})
	if not ok:failures+=1;printerr("FAIL ",label)
func fresh(week:int)->Sim:
	var s:=Sim.new();s.setup(Content.get_level(Content.level_id_for(week)),Content.PLANT_ORDER.duplicate(),"easy",7070);s.sun=99999;return s
func _initialize():run.call_deferred()
func run():
	var s:=fresh(7)
	for row in 6:
		check("第%d行7/8禁种9可种" % row,not s.can_place_at("shooter",6,row).ok and not s.can_place_at("shooter",7,row).ok and s.can_place_at("shooter",8,row).ok)
	for up in [true,false]:
		s=fresh(7);s.time=10;s.chapter.event_start=4;s.chapter.event_mode="guide";s.chapter.guide_up=up
		for row in 6:
			var z=s.spawn_zombie("ghost",row,{"x":Geo.BOARD_X+8*Geo.CELL_W})
			s.chapter.try_route(z)
			check("三组同时借道%s路%d" % [up,row],z.scene_route_active==((row%2==1)==up))
			if not z.scene_route_active:continue
			var from:int=z.row;var hp:float=z.hp;s.damage_zombie(z,20,true)
			check("借道半伤",is_equal_approx(hp-z.hp,10))
			z.pos.x-=Geo.CELL_W;s.chapter.step_route(z)
			check("两列中点连续且与绘制路径同坐标",is_equal_approx(z.pos.y,(s.row_y(from)+s.row_y(from^1))*.5))
			var saved:=Sim.new();saved.restore(JSON.parse_string(JSON.stringify(s.serialize())))
			var copy=saved.guest_uid(z.uid)
			check("中途保存不跳帧且方向不变",copy.pos.is_equal_approx(z.pos) and copy.scene_route_left==z.scene_route_left and saved.chapter.guide_up==up)
			z.pos.x=Geo.BOARD_X+6*Geo.CELL_W;s.chapter.step_route(z)
			check("走完两列才换行结束",not z.scene_route_active and z.row==(from^1))
	# More than the former cap of 4/6 must be affected.
	s=fresh(7);s.time=10;s.chapter.event_start=4;s.chapter.event_mode="guide";s.chapter.guide_up=true
	for i in 18:
		var z=s.spawn_zombie("ghost",1+(i%3)*2,{"x":Geo.BOARD_X+8*Geo.CELL_W});s.chapter.try_route(z)
	check("十八名恶客均引路，无四人上限",s.zombies.all(func(z):return z.scene_route_active))
	s=fresh(7);s.time=10;s.chapter.event_start=4;s.chapter.event_mode="haste"
	for i in 18:
		var z=s.spawn_zombie("ghost",i%6,{"x":Geo.BOARD_X+7.5*Geo.CELL_W});var x:float=z.pos.x
		s.update_zombies(.1)
		check("通道内第%d名全员加速" % i,is_equal_approx(x-z.pos.x,z.speed*.1*1.5))
		z.pos.x=Geo.BOARD_X+5.9*Geo.CELL_W
		check("离开通道不再加速",not s.chapter.haste_applies(z))
	var flier=s.spawn_zombie("sky-wick",4,{"x":Geo.BOARD_X+7.8*Geo.CELL_W})
	s.chapter.event_mode="guide";var flight_base:float=s.guest_attribute_factor(flier,"speed");s.chapter.event_mode="haste"
	check("飞行恶客属性移动也加速",is_equal_approx(s.guest_attribute_factor(flier,"speed"),flight_base*1.5))
	var large=s.spawn_zombie("mountain",2,{"x":Geo.BOARD_X+7*Geo.CELL_W})
	check("大型恶客也受催场影响",s.chapter.haste_applies(large))
	var old=s.spawn_zombie("ghost",1,{"x":Geo.BOARD_X+6.5*Geo.CELL_W});old.scene_route_active=true;old.scene_route_from=1;old.scene_route_to=0
	s.chapter.step_route(old);check("旧版单列中途存档仍沿原路径",is_equal_approx(old.pos.y,(s.row_y(0)+s.row_y(1))*.5))
	s=fresh(8);s.chapter.market_pair=1;s.chapter.event_start=10
	for item in [[10.0,"warning"],[17.3,"ignite"],[18.0,"lit"],[30.1,"extinguish"],[31.0,"dark"]]:
		s.time=item[0];check("市灯连续阶段"+item[1],s.chapter.lamp_pose(1).clip==item[1] and s.chapter.lamp_pose(0).clip=="dark")
	s.time=22;s.chapter.begin_market(2)
	check("新灯报信时旧灯独立熄灭",s.chapter.lamp_pose(1).clip=="extinguish" and s.chapter.lamp_pose(2).clip=="warning")
	var restored:=Sim.new();restored.restore(JSON.parse_string(JSON.stringify(s.serialize())))
	check("市灯熄灭中途读档连续",restored.chapter.lamp_pose(1).clip==s.chapter.lamp_pose(1).clip and is_equal_approx(restored.chapter.lamp_pose(1).key,s.chapter.lamp_pose(1).key) and is_equal_approx(restored.chapter.lamp_pose(1).light,s.chapter.lamp_pose(1).light))
	s.time=32;s.chapter.begin_market(2)
	check("同一盏重新报信也先自然熄灭",s.chapter.lamp_pose(2).clip=="extinguish")
	s.time=33;check("同灯熄灭后接续报信",s.chapter.lamp_pose(2).clip=="warning")
	var n:=Numbers.new()
	check("伤害治疗皆无正负号",Numbers.text(140,false)=="140" and Numbers.text(140,true)=="140" and Numbers.text(.5,false)=="0.5")
	check("伤害与字号严格递增且有上限",Numbers.point_size(10,23,false)<Numbers.point_size(140,23,false) and Numbers.point_size(140,23,false)<Numbers.point_size(1000,23,false) and Numbers.point_size(999999,30,false)<=62)
	n.record("z1",Vector2(800,400),75,false,true);n.record("z1",Vector2(800,400),75,false,true);n.update(.21)
	check("连续伤害按实际累计，数值未变",n.entries.size()==1 and n.entries[0].amount==150)
	for i in 10:n.defeated(Vector2(800+i*2,400))
	n.update(.01);check("十名同时击退只有一个强反馈",n.finishes.size()==1 and n.finishes[0].count==10 and n.finishes[0].tier==3)
	n.mode="off";n.update(.01);check("关闭数字清理全部额外反馈",n.entries.is_empty() and n.finishes.is_empty() and not n.punch_requested)
	var off:=fresh(7);var on:=fresh(7);off.vital_numbers.mode="off";on.vital_numbers.mode="large"
	for battle in [off,on]:
		for row in 6:
			var plant=battle.place_free("shooter",4,row);plant.uid="p-replay-%d" % row
			var guest=battle.spawn_zombie("ghost",row,{"x":Geo.BOARD_X+7*Geo.CELL_W});guest.uid="z-replay-%d" % row
	for frame in 300:
		off.tick(.05);on.tick(.05)
	check("数字与群体反馈不改变战斗存档或随机数",JSON.stringify(off.serialize())==JSON.stringify(on.serialize()))
	var catalog:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/actor_motion.json"))
	for key in ["troupe","cloud-lamp","pact-lamp","lotus-lamp","impact-ink"]:
		var actor:Dictionary=catalog["scenery-"+key]
		for clip in actor.clips:check(key+"/"+clip+"独立32帧",actor.clips[clip].size()==32)
	var out:=FileAccess.open("res://qa/v070-scenery-mechanics.json",FileAccess.WRITE);out.store_string(JSON.stringify({"total":checks.size(),"failures":failures,"checks":checks},"  "))
	print("SCENERY TOTAL ",checks.size()," FAILURES ",failures);quit(0 if failures==0 else 1)
