extends SceneTree

class IsolatedGame extends "res://scripts/game.gd":
	func _data_path(path: String) -> String:
		var out := "res://qa/v072-isolated"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
		return out.path_join(path.get_file())

var game
var dims:=Vector2i(1600,900)
var out:="res://qa/v072-visual"
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
	MarketArt.reduced_motion=false
	game.progress.selected=Content.SPECIAL_ID
	game.show_levels()
	await capture("deep-map")
	game.settings.difficulty="nightmare"
	for week in [6,7,8]:
		game.settings.nightmare_factors={ "dim":1,"seeds":1,"loss":1}
		var level_id:=Content.level_id_for(week)
		game._start_battle_now(level_id,["five-brew","blank-orchid","shooter","wall","herb-gourd"],"normal",false)
		game.paused=true
		await settle()
		var s:Sim=game.sim
		var orchid=s.place_free("blank-orchid",7 if week==6 else 3,2)
		orchid.upgrades={1:3,2:0,3:1}
		var rain=s.place_free("blank-orchid",6 if week==6 else 2,3)
		rain.upgrades={1:0,2:0,3:3}
		var brew=s.place_free("five-brew",6 if week==6 else 2,2)
		brew.upgrades={1:3,2:1,3:0}
		var wall=s.place_free("wall",8 if week==6 else 5,3)
		wall.hp=50
		var kinds: Array=[["mist-hat","cloud-porter"],["gong-imp","curtain-effigy"],["wick-pilgrim","lantern-judge"]][week-6]
		for i in 4:
			var z=s.spawn_zombie(kinds[i%2],i,{"x":1060.0+i%2*105})
			z.anim=.2*i;z.scene_walk_distance=6.0+float(i)*8
		s.refresh_plant_buffs()
		if week==6:
			s.time=65;s.chapter.sync_platforms()
			s.incense_window=[[64.5, 850]]
		elif week==7:
			s.time=8;s.chapter.event_start=0;s.chapter.event_mode="guide";s.chapter.guide_up=true
		else:
			s.time=9;s.chapter.market_pair=1;s.chapter.event_start=0
		s.v072.update_brew(brew,3)
		s.activate_skill(rain)
		s.time+=.34
		s.refresh_plant_buffs()
		await capture("week-%d"%week)
		if week==8:
			s.chapter.market_all=true
			await capture("three-lamps")
	print("V072 VISUAL ",captures," captured ",dims)
	game.free()
	quit(0 if captures==5 else 1)
