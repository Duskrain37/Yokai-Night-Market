extends SceneTree
class IsolatedGame extends "res://scripts/game.gd":
	func _data_path(path: String) -> String:
		var directory := "res://qa/v070-runtime"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		return directory.path_join(path.get_file())
var game
func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for i in 5: await process_frame
func capture(label: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	var path := "res://qa/v070-%s.png" % label
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("CAPTURE ",label)
func run() -> void:
	root.content_scale_size=Vector2i(1600,900)
	game=IsolatedGame.new()
	root.add_child(game)
	await settle()
	game._start_battle_now(Content.level_id_for(6),["lantern","shooter","cat","wall","year-banyan","firework","dragon","bell","cash-pod","gust"],"normal",false)
	game.paused=true
	game.sim.sun=10000
	for row in 6:
		for col in [0,1,2,3,4,5,7]:
			if game.sim.can_place_at("shooter",col,row).ok:
				var types: Array=["lantern","shooter","cat","wall","bell","firework"]
				if col in [0,3,5,7]:game.sim.place_free(types[(row+col)%types.size()],col,row)
		var z=game.sim.spawn_zombie("straw" if row%2==0 else "ghost",row,{"x":1100.0-row*75.0})
		z.scene_walk_distance=12+row*3
	game.units.health_bars="both"
	for clock in [0.0,31.5,33.0,71.2,73.0,111.2,113.0,121.5]:
		game.sim.time=clock
		game.sim.chapter.sync_platforms()
		game.sim.refresh_plant_buffs()
		game.hud.refresh()
		await capture("sky-%.1f" % clock)
	game.sim.time=73
	game.sim.chapter.sync_platforms()
	game.sim.place_free("year-banyan",1,1)
	game.hud.show_fan(game.sim.main_plant_at(1,1)) if game.hud.has_method("show_fan") else game.hud.try_open_menu(game.sim.main_plant_at(1,1),Vector2(450,430))
	await capture("sky-submerged-upgrade")
	quit()
