extends SceneTree
const G = preload("res://scripts/geo.gd")
var good:=0
var bad:=0
func _initialize() -> void: run.call_deferred()
func check(label: String, value: bool) -> void:
	if value: good+=1; print("PASS ",label)
	else: bad+=1; printerr("FAIL ",label)
func make(week: int, night:=2) -> Sim:
	var s:=Sim.new()
	s.setup(Content.get_level(Content.level_id_for(week,night)),["wall","blank-orchid","shooter","lantern"],"normal",74)
	return s
func run() -> void:
	var s:=make(4)
	var state:Dictionary=s.shore.state
	for r in 6:
		check("high shoreline row %d"%r,s.shore.flooded(7,r) and s.shore.flooded(8,r) and not s.shore.flooded(6,r))
	var rider:=s.spawn_zombie("reedboat",2,{"x":G.BOARD_X+G.CELL_W*9.2})
	check("boat survives water approach",rider!=null and rider.armor>0 and rider.water_entered and rider.row==2)
	s.shore.on_batch(4)
	s.time=6.95;s.shore.tick()
	var mid:=s.spawn_zombie("ghost",2,{"x":G.BOARD_X+G.CELL_W*7.4})
	var end:=s.spawn_zombie("ghost",2,{"x":G.BOARD_X+G.CELL_W*8.65})
	check("animated ebb leaves water only beyond moving shoreline",not s._zombie_over_water(mid) and s._zombie_over_water(end))
	s.time=8.01;s.shore.tick();s._update_water_pose(rider,.016)
	check("reedboat abandons boat on dry land",not rider.water_entered and rider.armor==0 and rider.raft_sink_t==0)
	for r in 6:
		var first: int=[7,8,9,9,8,7][r]
		check("ebb tiles and spawn shore row %d"%r,s.shore.flooded(7,r)==(first==7) and s.shore.flooded(8,r)==(first<=8) and s.shore.flooded(9,r)==(first<=8))
	check("dry planting in previously submerged middle tier",s.can_place_at("wall",7,2).ok)
	var plant:=s.place_free("wall",7,2)
	state.wet=true
	check("rising tide pauses plant without destroying it",plant!=null and not s.plant_on_stage(plant) and not plant.dead and not s.can_place_at("wall",8,3).ok)
	s=make(3)
	rider=s.spawn_zombie("reedboat",1,{"x":G.BOARD_X+G.CELL_W*9.15})
	s._update_water_pose(rider,.016)
	check("original dark-river entry still keeps the boat",rider.armor>0 and rider.water_entered)
	s=make(1,3);s.wave_index=3*Content.WAVES_PER_GROUP
	s.update_waves()
	check("no acceleration before fourth flag group starts",s.wave_index==9)
	s.wave_index=10
	for i in 3: s.spawn_zombie("ghost",i)
	s.update_waves();check("three enemies are too many",s.wave_index==10)
	s.zombies.pop_back()
	s.spawn_queue.append({"t":5000.0,"type":"ghost","row":0})
	s.update_waves();check("already queued enemies block skip",s.wave_index==10)
	s.spawn_queue.clear();s.update_waves()
	check("two remaining call the next batch immediately",s.wave_index==11 and s.wave_time_offset<0)
	var p:=s.place_free("blank-orchid",2,2)
	s.place_free("wall",3,2)
	var layout:Dictionary=s.v072._neighbors(p)
	check("orchid has an empty planted-neighbor visual target at base",layout.values().any(func(e):return e.uid=="" and e.row==2 and e.col==1))
	var foe:Sim.Zombie=s.zombies[0]
	foe.slow_t=3;foe.slow_amount=.35;foe.burn_t=4
	var stats:=s.guest_status_lines(foe)
	check("guest plate reports live slow and burn",stats.any(func(e):return e.text.begins_with("移速 -35")) and stats.any(func(e):return e.text.begins_with("灼烧")))
	print("TOTAL %d FAILURES %d" % [good+bad,bad]);quit(bad)
