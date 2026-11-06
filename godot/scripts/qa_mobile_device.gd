extends Node
var game
var checks: Array=[]
var failures:=0
var folder:="user://device-qa"
func check(name: String,ok: bool) -> void:
	checks.append({"name":name,"ok":ok})
	if not ok:failures+=1;printerr("DEVICE_FAIL ",name)
func settle(frames:=10) -> void:
	for i in frames:await get_tree().process_frame
func shot(name: String) -> void:
	await settle(20)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder+"/"+name+".png")
func touch(at: Vector2,pressed: bool) -> void:
	var e:=InputEventScreenTouch.new();e.index=0;e.position=at;e.pressed=pressed;get_tree().root.push_input(e,true)
func tap(at: Vector2) -> void:touch(at,true);touch(at,false)
func drag(at: Vector2,to: Vector2) -> void:
	touch(at,true)
	for i in 15:
		var e:=InputEventScreenDrag.new();e.index=0;e.position=at.lerp(to,(i+1)/15.0);get_tree().root.push_input(e,true)
		await get_tree().process_frame
	touch(to,false)
func find(node: Node,name: String) -> Node:
	for child in node.get_children():
		if child.name==name:return child
		var nested:=find(child,name)
		if nested!=null:return nested
	return null
func run(owner_game) -> void:
	game=owner_game
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	await settle(90)
	check("native Android mobile mode",OS.has_feature("android") and game.mobile)
	check("no emulated mouse duplicates",not Input.emulate_mouse_from_touch)
	game.show_menu();await shot("menu")
	game.open_news();await shot("news");game.screen_node.select_page(1);await shot("links")
	game.show_levels();game.screen_node.select_day(5);await shot("levels")
	game.show_prep(26);await settle()
	var plant_scroll=find(game.screen_node,"PlantScroll")
	var foes=find(game.screen_node,"FoeScroll")
	check("prep has independent vertical lists",plant_scroll!=null and foes!=null)
	var at: Vector2=plant_scroll.get_global_rect().get_center()
	await drag(at+Vector2(0,95),at-Vector2(0,95));await settle()
	check("finger drag scrolls plants",plant_scroll.scroll_vertical>0 and foes.scroll_vertical==0)
	await shot("prep-scrolled")
	game.open_almanac("boss",5);await shot("book")
	game.close_overlay();game.start_battle(11,["lantern","lobber","judge","bell","torch","herb-gourd","wish-till","shooter","star","lily"])
	await settle(90);game.paused=true;game.sim.banner={}
	check("safe area transforms board and HUD together",game._mobile_world_transform()==game.ui_root.get_transform()*game.MOBILE_WORLD)
	check("mobile HUD native",game.hud.get_script().resource_path.ends_with("mobile_hud.gd"))
	game.paused=false
	var card: Vector2=game.hud._card_nodes[0].get_global_rect().get_center()
	tap(card);await settle();check("tap card exactly once",game.hud.card_selected==0)
	var aim: Vector2=game._mobile_world_transform()*Geo.to_screen(game.sim.cell_pos(3,2),game.sim.rows)
	tap(aim);await settle();var plant=game.sim.main_plant_at(3,2)
	check("tap places at correct projected cell",plant!=null and plant.type=="lantern")
	tap(card);await settle();touch(aim,true);await get_tree().create_timer(.55).timeout;touch(aim,false);await settle()
	check("hold cancels without planting",game.hud.card_selected==-1 and game.sim.plants.size()==1)
	var boat=game.sim.spawn_zombie("reedboat",1,{"x":980});boat.armor=0;boat.water_entered=true;boat.raft_sink_t=.25
	var shooter=game.sim.place_free("shooter",5,2)
	game.hud.try_open_menu(shooter,shooter.pos);await shot("upgrade")
	check("upgrade reading pauses combat",game.hud.blocks_simulation())
	game.hud.close_fan();await shot("battle")
	game.show_pause();await shot("pause");game.close_pause()
	game._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST);check("system back pauses instead of quitting",game.paused and not get_tree().quit_on_go_back)
	game.close_pause()
	game._notification(Node.NOTIFICATION_APPLICATION_PAUSED);check("background pauses battle",game.paused)
	game._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	game.paused=false
	var start:=Time.get_ticks_msec();var samples: Array=[]
	for i in 360:
		await get_tree().process_frame
		samples.append(Performance.get_monitor(Performance.TIME_PROCESS))
	var stats={"checks":checks,"total":checks.size(),"failures":failures,"render_fps":Engine.get_frames_per_second(),"elapsed_ms":Time.get_ticks_msec()-start,"process_ms_mean":0.0,"static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"renderer":ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile"),"os":OS.get_name(),"screen":DisplayServer.screen_get_size(),"window":DisplayServer.window_get_size(),"safe":DisplayServer.get_display_safe_area(),"ui_scale":game.ui_root.scale,"ui_position":game.ui_root.position,"build":preload("res://data/build_info.gd").BUILD_HASH}
	for value in samples:stats.process_ms_mean+=value*1000.0/samples.size()
	var file:=FileAccess.open(folder+"/report.json",FileAccess.WRITE);file.store_string(JSON.stringify(stats,"  "));file.close()
	print("DEVICE_MOBILE_DONE ",JSON.stringify(stats))
	game.paused=true
