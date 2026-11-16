extends SceneTree
class PreviewGame extends "res://scripts/game.gd":
	func _data_path(path:String)->String:
		var folder:="res://qa/scenery-isolated";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder));return folder.path_join(path.get_file())
var game
var folder:="res://qa/scenery-gallery"
var dimensions:=Vector2i(1600,900)
var checks:Array=[]
var failures:=0
func check(label:String,ok:bool):
	checks.append({"name":label,"ok":ok})
	if not ok:failures+=1;printerr("FAIL ",label)
func click(at:Vector2):
	for pressed in [true,false]:
		var ev:=InputEventMouseButton.new();ev.position=at;ev.global_position=at;ev.button_index=MOUSE_BUTTON_LEFT;ev.pressed=pressed;root.push_input(ev,true);await process_frame
	await settle()
func _initialize():run.call_deferred()
func settle(n:int=6):
	for i in n:await process_frame
func capture(label:String):
	game.hud.refresh();game.board.queue_redraw();game.units.queue_redraw()
	await settle();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(folder.path_join("%s-%dx%d.png" % [label,dimensions.x,dimensions.y])))
	print("CAPTURE ",label)
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-size="):
			var parts=arg.trim_prefix("--qa-size=").split("x");dimensions=Vector2i(int(parts[0]),int(parts[1]))
	root.content_scale_size=Vector2i(1600,900);root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND;root.size=dimensions
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	game=PreviewGame.new();root.add_child(game);await settle();game.set_process(false)
	root.mode=Window.MODE_WINDOWED;root.size=dimensions;await settle()
	game.settings.reduced_motion=false;MarketArt.reduced_motion=false
	for week in [7,8]:
		game._start_battle_now(Content.level_id_for(week),["lantern","shooter","wall","cat","bell","firework"],"normal",false)
		game.paused=true;await settle()
		var s:Sim=game.sim;s.sun=99999
		for row in 6:
			for col in [0,2,4]:
				if s.can_place_at("shooter",col,row).ok:s.place_free(["lantern","shooter","cat","wall"][col%4],col,row)
			var z=s.spawn_zombie("straw" if row%2==0 else "ghost",row,{"x":Geo.BOARD_X+8.8*Geo.CELL_W});z.scene_walk_distance=18
		if week==7:
			s.time=0;await capture("theatre-idle")
			game.paused=false
			for col in [6,7,8]:
				game.hud.card_selected=1
				await click(Geo.to_screen(s.cell_pos(col,0),s.rows))
				check("鼠标点第%d列与可种边界一致" % (col+1),(s.main_plant_at(col,0)!=null)==(col==8))
			game.paused=true
			s.chapter.event_start=0;s.chapter.event_mode="guide";s.chapter.guide_up=true
			for clock in [2.0,6.1,6.5,7.0,7.5]:
				s.time=clock;await capture("theatre-guide-%.1f" % clock)
			s.time=8
			for row in [1,3,5]:
				var z=s.spawn_zombie("ghost",row,{"x":Geo.BOARD_X+8*Geo.CELL_W});s.chapter.try_route(z);z.pos.x-=Geo.CELL_W;s.chapter.step_route(z)
			await capture("theatre-mid-route")
			s.chapter.event_mode="haste";s.time=9;await capture("theatre-haste")
		else:
			s.chapter.market_pair=1;s.chapter.event_start=0
			for clock in [0.0,7.3,7.6,8.0,9.0,20.2,20.6,21.1]:s.time=clock;await capture("market-%.1f" % clock)
			for pair in [0,2]:
				s.chapter.market_pair=pair;s.time=10;await capture("market-lamp-%d" % pair)
			s.vital_numbers.clear()
			for i in 6:
				s.vital_numbers.record("z-demo%d"%i,Vector2(Geo.BOARD_X+(3+i*.7)*Geo.CELL_W,Geo.row_y(3,6)),[20,80,140,500,1500,5000][i],false,false,100)
			s.vital_numbers.record("p-demo",Vector2(Geo.BOARD_X+2*Geo.CELL_W,Geo.row_y(4,6)),350,true,false,100)
			s.vital_numbers.update(.12);await capture("feedback-impact")
			for i in 12:s.vital_numbers.defeated(Vector2(800+i*10,Geo.row_y(2,6)))
			s.vital_numbers.update(.02);await capture("feedback-crowd")
			MarketArt.reduced_motion=true;await capture("feedback-reduced-motion")
	print("VIEWPORT ",root.get_texture().get_size()," EXPECTED ",dimensions)
	check("画面实际分辨率匹配",Vector2i(root.get_texture().get_image().get_size())==dimensions)
	game.show_menu();game.free();await settle()
	FileAccess.open("res://qa/scenery-ui-%dx%d.json" % [dimensions.x,dimensions.y],FileAccess.WRITE).store_string(JSON.stringify({"total":checks.size(),"failures":failures,"checks":checks},"  "))
	print("SCENERY UI TOTAL ",checks.size()," FAILURES ",failures);quit(0 if failures==0 else 1)
