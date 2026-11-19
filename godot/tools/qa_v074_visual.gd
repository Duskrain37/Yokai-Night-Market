extends SceneTree
class IsolatedGame extends "res://scripts/game.gd":
	func _data_path(path: String) -> String:
		var out := "res://qa/v074-isolated"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
		return out.path_join(path.get_file())
var g
var dims:=Vector2i(1600,900)
var out:="res://qa/v074-visual"
var count:=0
var failures:=0
func _initialize(): run.call_deferred()
func settle(n:=5) -> void:
	for i in n: await process_frame
func check(text: String,ok: bool) -> void:
	if not ok: failures+=1;printerr("FAIL ",text)
	else:print("PASS ",text)
func shot(name: String) -> void:
	for v in [g.hud,g.board,g.units]:
		if is_instance_valid(v): v.queue_redraw()
	await settle();await RenderingServer.frame_post_draw
	var im:=root.get_texture().get_image()
	check("capture dims "+name,im.get_size()==dims)
	check("capture write "+name,im.save_png(ProjectSettings.globalize_path(out.path_join("%s-%d.png"%[name,dims.x])))==OK)
	count+=1
func right(at: Vector2) -> void:
	var ev:=InputEventMouseButton.new();ev.button_index=MOUSE_BUTTON_RIGHT;ev.pressed=true
	ev.position=root.get_stretch_transform()*at;ev.global_position=ev.position
	Input.parse_input_event(ev)
	var up:=ev.duplicate() as InputEventMouseButton;up.pressed=false;Input.parse_input_event(up)
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.is_valid_int(): dims=Vector2i(int(arg),int(arg)*9/16)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	g=IsolatedGame.new();root.add_child(g);await settle()
	g.set_process(false);root.mode=Window.MODE_WINDOWED;root.size=dims;await settle()
	g.show_levels()
	for week in range(1,6):
		g.screen_node.switch_to_level(Content.level_id_for(week,0))
		check("week %d uses a bundled JPG"%week,ResourceLoader.exists("res://assets/bg/map-day%d.jpg"%week))
		await shot("levels-%d"%week)
	var items: Array[String]=[]
	for target in ["menu","night"]:
		var loc:="res://assets/bg/loading-%s.png"%target
		await g._load_transition(items,"守夜将启",loc,true)
		check("loading has the requested illustration",g._loading_screen.backdrop!=null and g._loading_screen.backdrop.resource_path==loc)
		await shot("loading-"+target);await g._reveal_loaded()
	var cards=["blank-orchid","wall","shooter","lantern"]
	g._start_battle_now(Content.level_id_for(4,2),cards,"normal",false);g.paused=false
	await settle()
	var s:Sim=g.sim
	s.place_free("blank-orchid",3,2);s.place_free("wall",4,2)
	s.tick(.02)
	s.shore.on_batch(0)
	s.shore.on_batch(4)
	var z:Sim.Zombie=s.spawn_zombie("reedboat",2,{"x":Geo.BOARD_X+Geo.CELL_W*8.9})
	await shot("island-warning")
	s.time=6.8;s.shore.tick();s._update_water_pose(z,.016);await shot("island-turn")
	s.time=8.25;s.shore.tick();s._update_water_pose(z,.016);await shot("island-ebb")
	z.slow_t=5;z.slow_amount=.35;z.burn_t=3
	right(g.units.guest_anchor(z)-Vector2(0,26));await settle()
	check("real right click opens the guest status",g._guest_status.guest==z)
	await shot("guest-status")
	right(Vector2(38,170));await settle()
	check("right clicking clear space closes the panel",g._guest_status.guest==null)
	g._start_battle_now(Content.level_id_for(5,2),cards,"normal",false);g.paused=false
	await settle();s=g.sim
	var gate_x:float=Geo.BOARD_X+8*Geo.CELL_W+9
	var foot:=Geo.to_screen(Vector2(gate_x,s.row_y(2)),s.rows)
	await shot("cavern-gates-up")
	check("cavern gate clicks on the same x as the painted track",s.shore.click(Vector2i(8,2),foot))
	z=s.spawn_zombie("timber-bearer",2,{"x":gate_x+42})
	s.time=1.0
	check("vertical gate stops the right-side guest on that line",is_equal_approx(s.shore.stop_position(z,gate_x-12),gate_x))
	await shot("cavern-gate-down")
	print("V074 VISUAL ",count," captured ",dims," FAILURES ",failures)
	g.free();quit(failures)
