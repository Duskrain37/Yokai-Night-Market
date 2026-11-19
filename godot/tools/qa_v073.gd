extends SceneTree
const Geo = preload("res://scripts/geo.gd")
var good := 0
var bad := 0
func _initialize() -> void: run.call_deferred()
func expect(label: String, ok: bool) -> void:
	if ok: good+=1; print("PASS ",label)
	else: bad+=1; printerr("FAIL ",label)
func setup(week: int, night: int=2) -> Sim:
	var s := Sim.new()
	s.setup(Content.get_level(Content.level_id_for(week,night)),["shooter","wall","lantern","blank-orchid","lily"],"normal",73)
	return s
func run() -> void:
	var s := setup(2)
	var d: Dictionary = s.shore.state
	expect("river port starts with seven cargo stacks",d.cargo.size()==7)
	s.shore.on_batch(0)
	var b: Dictionary = d.boats[0]
	expect("incense first, chooses one of two docks",not b.cargo and b.row in [1,4])
	var foe := s.spawn_zombie("ghost",int(b.row),{"x":Geo.BOARD_X+Geo.BOARD_W-20})
	s.time=3.01;s.shore.tick();s.time=10.8;s.shore.tick()
	expect("will not dock while the last two tiles are occupied",b.phase=="wait")
	s.kill_zombie(foe);s.time=11.0;s.shore.tick()
	var sun: int = s.sun
	s.time=12.1;s.shore.tick()
	expect("clearing an occupied dock grants 300",s.sun==sun+300 and b.phase=="unload")
	s.time=19;s.shore.tick();s.shore.on_batch(3)
	b=d.boats.back()
	expect("next boat carries freight",b.cargo)
	for t in [22.1,22.2,23.3,24.6]:s.time=t;s.shore.tick()
	expect("a winch clears one tile permanently",d.cargo.filter(func(c):return c.removed).size()==1)
	var cp: Dictionary=s.serialize()
	var reload := Sim.new()
	reload.restore(cp)
	expect("cargo remains clear across save/load",reload.shore.state.cargo.filter(func(c):return c.removed).size()==1)
	s=setup(2,4);s.shore.on_batch(21)
	expect("final boss wave has no ship",s.shore.state.boats.is_empty())
	s=setup(3);d=s.shore.state
	expect("one floating mat for each water course",d.mats.size()==2)
	var m: Dictionary=d.mats[0]
	var row := int(m.row)
	var p:=s.place_free("wall",int(m.ends[0]),row)
	expect("ordinary plants can use the mat without a lily",p!=null)
	if p != null:
		p.hp-=23;p.upgrades={1:2,2:0,3:0}
		expect("mat can move to the empty mooring",s.shore.click(Vector2i(int(m.ends[1]),row)))
		expect("mat pauses action in transit",s.shore.transit(p))
		s.time=1.6;s.shore.tick()
		expect("same plant and upgrade after moving",s.main_plant_at(int(m.ends[1]),row)==p and p.tier(1)==2)
	s.queue_wave(s.level.waves[4],4)
	var course: Array = s.spawn_queue.filter(func(x): return x.row in [1,3] and float(x.t)>=float(d.flow_at))
	expect("first current demonstrates both directions within one second", course.size()>=2 and course.any(func(x): return x.row==1 and course.any(func(y): return y.row==3 and absf(float(x.t)-float(y.t))<1.0)))
	expect("two-channel advance notice lasts 6 game seconds",is_equal_approx(float(d.flow_at)-s.time,6))
	s.time=7.61;s.shore.tick()
	var up:=s.spawn_zombie("ghost",1);var down:=s.spawn_zombie("ghost",3)
	up.water_entered=true;down.water_entered=true
	expect("opposite currents at +20 and -30 percent",s.shore.speed(up)==1.2 and s.shore.speed(down)==.7)
	s.shore.on_batch(8);s.time=13.62;s.shore.tick()
	expect("second current event reverses both",s.shore.speed(up)==.7 and s.shore.speed(down)==1.2)
	s=setup(4);d=s.shore.state
	expect("island opens at high tide",d.wet)
	s.shore.on_batch(1)
	expect("first island mid-wave does not change tide",d.tide_at<0)
	s.shore.on_batch(4)
	expect("second island mid-wave forecasts the falling tide",d.tide_at==8 and not d.tide_next)
	s.time=8.1;s.shore.tick()
	var wet_row:=int(d.tide_lane)
	var arrival: Array=s.shore.island_arrival("ghost",wet_row,5,[])
	expect("only scheduled arrivals from chosen outer lane take the shortcut",arrival==["ghost",wet_row,true])
	foe=s.spawn_zombie("ghost",wet_row,{"shore_short":true})
	expect("shortcut grants +50 percent only on the outer stretch",s.shore.speed(foe)==1.5)
	foe.pos.x=Geo.BOARD_X+Geo.CELL_W*6
	expect("shore speed is normal after rejoining",s.shore.speed(foe)==1)
	s.shore.on_batch(3);s.time=13.2;s.shore.tick()
	foe.pos.x=Geo.BOARD_X+Geo.CELL_W*7.5
	expect("fog lasts 25 seconds, and obscures the covered shore",is_equal_approx(float(d.fog_until)-float(d.fog_at),25) and s.shore.fogged(foe))
	expect("true sight bypasses the fog",not s.shore.evade(foe,"homing",true))
	var hits := 0
	for i in 700:
		if s.shore.evade(foe,"pea",false):hits+=1
	expect("shot evasion is approximately half",hits>280 and hits<420)
	s=setup(5);d=s.shore.state
	expect("five non-plantable bridges span the old pits",d.bridges.size()==5 and not s.can_place_at("wall",6,0).ok)
	expect("gate can be lowered and can't be used twice",s.shore.click(Vector2i(8,1)) and d.gate_ready==30 and d.gate_until==5)
	foe=s.spawn_zombie("ghost",1,{"x":Geo.BOARD_X+Geo.CELL_W*8.8})
	expect("still targetable, cannot cross closed gate",s.shore.stop_position(foe,0)>1000 and foe.alive())
	s.time=5.01
	expect("gate rises and stops holding",s.shore.stop_position(foe,0)==0)
	s.shore.on_batch(6)
	var missing: Array=d.bridges.filter(func(x):return not x.intact)
	expect("wave three breaks exactly one bridge",missing.size()==1)
	s.shore.on_batch(11)
	expect("flag wave schedules timber bearer",s.spawn_queue.any(func(x):return x.type=="timber-bearer" and x.shore_timber))
	foe=s.spawn_zombie("timber-bearer",0,{"shore_timber":true,"wave_no":11});s.kill_zombie(foe)
	expect("flag timber bearer yields wood on defeat",d.wood==1)
	if not missing.is_empty():
		var damaged: Dictionary=missing[0]
		s.shore.click(Vector2i(int(damaged.col),int(damaged.row)))
		expect("wood is consumed to restore a bridge",d.wood==0 and damaged.intact)
	s=setup(1)
	var orchid:=s.place_free("blank-orchid",1,1)
	var near:=s.place_free("wall",2,1)
	var far:=s.place_free("wall",4,1)
	orchid.upgrades={1:0,2:0,3:2}
	var dew: Dictionary=s.v072._orchid(orchid)
	dew.dew=3;s.v072._auto_rain(orchid,dew)
	expect("nearest fresh recipient gets surplus dew",s.v072.droplets[0].uid in [near.uid,orchid.uid])
	far.hp=1;dew.dew=3;s.v072._auto_rain(orchid,dew)
	expect("injured plant still has priority",s.v072.droplets.back().uid==far.uid)
	s.time=1;s.v072.tick()
	expect("dew marks nourishment and heals",s.v072.nourished(far) and far.hp>1)
	for lvl in Content.LEVELS:
		var actual: Array=Content.plants_in_level(lvl)
		var cap: int=15 if String(lvl.get("boss_id",""))!="" or bool(lvl.get("special",false)) else 12
		expect("%s %s has %d possible guests (cap %d)" % [lvl.day_name,lvl.name,actual.size(),cap],actual.size()<=cap)
	print("TOTAL %d FAILURES %d" % [good+bad,bad])
	quit(1 if bad else 0)
