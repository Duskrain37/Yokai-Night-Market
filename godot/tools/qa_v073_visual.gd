extends SceneTree

class IsolatedGame extends "res://scripts/game.gd":
	func _data_path(path: String) -> String:
		var out := "res://qa/v073-isolated"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
		return out.path_join(path.get_file())

var game
var dims:=Vector2i(1600,900)
var out:="res://qa/v073-visual"
var captures:=0

func _initialize():
	run.call_deferred()

func settle(frames: int=6) -> void:
	for i in frames:await process_frame

func capture(stem: String) -> void:
	for view in [game.hud,game.board,game.units]:
		if is_instance_valid(view):
			if view.has_method("refresh"):view.refresh()
			view.queue_redraw()
	await settle()
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.get_size()!=dims:
		printerr("size ",image.get_size()," expected ",dims)
		quit(1);return
	var path := out.path_join("%s-%s.png"%[stem,str(dims.x)])
	if image.save_png(ProjectSettings.globalize_path(path))!=OK:
		printerr("Cannot save ",path)
		quit(1);return
	captures+=1

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.is_valid_int():dims=Vector2i(int(arg),int(arg)*9/16)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	root.size=dims
	game=IsolatedGame.new();root.add_child(game);await settle()
	game.set_process(false);root.mode=Window.MODE_WINDOWED;root.size=dims;await settle()
	for week in range(2,6):
		game._start_battle_now(Content.level_id_for(week,2),["blank-orchid","shooter","wall","lantern","lily"],"normal",false)
		game.paused=true
		await settle()
		var s:Sim=game.sim
		s.place_free("wall",3,0)
		s.place_free("shooter",4,3)
		var orchid:=s.place_free("blank-orchid",5,2)
		if orchid!=null:
			orchid.upgrades={1:0,2:0,3:2}
			s.v072.rain_wet[orchid.uid]=19
		var d:Dictionary=s.shore.state
		s.shore.on_batch(0)
		match week:
			2:
				s.time=3.2;s.shore.tick();s.time=3.4;s.shore.tick();s.time=3.85
				s.spawn_zombie("freight-yokel",4,{"x":1100.0})
			3:
				s.shore.on_batch(4);s.time=5.5
				var m:Dictionary=d.mats[0]
				s.place_free("wall",int(m.ends[0]),int(m.row))
				s.shore.click(Vector2i(int(m.ends[1]),int(m.row)))
				s.time=6.1;s.shore.tick()
				var z:=s.spawn_zombie("river-fisher",3,{"x":1050.0});z.water_entered=true
			4:
				s.shore.on_batch(1);s.shore.on_batch(4)
				s.time=6;s.shore.tick()
				s.time=7.9
				s.place_free("wall",6,3)
				var z:=s.spawn_zombie("reedboat",0,{"x":1220.0});z.water_entered=true
				await capture("island-high")
				s.time=8.1;s.shore.tick();s.time=9.1
				await capture("island-tide-midframe")
				s.time=12.2
			5:
				s.shore.click(Vector2i(8,2));s.time=2.0
				s.shore.on_batch(6);d.wood=1
				s.time=4.0
				s.spawn_zombie("timber-bearer",1,{"x":1210.0})
		await capture("week-%d" % week)
	print("V073 VISUAL ",captures," captured ",dims)
	game.free()
	quit(0 if captures==6 else 1)
