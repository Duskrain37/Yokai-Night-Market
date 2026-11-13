## Render the actual game at a chosen viewport and text scale, without touching player saves.
extends SceneTree
class GalleryGame extends "res://scripts/game.gd":
	func _data_path(path: String) -> String:
		var directory = "res://qa/art-gallery-runtime"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		return directory.path_join(path.get_file())

var game
var target_size = Vector2i(1600, 900)
var large_text = false
var compact = false
var folder = "res://qa/art-overhaul"
var captures: Array = []

func _initialize() -> void: run.call_deferred()

func settle() -> void:
	for i in 12: await process_frame

func capture(label: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	var file = "%s/%s-%dx%d-%s.png" % [folder, label, target_size.x, target_size.y, "large" if large_text else "normal"]
	var screenshot = root.get_texture().get_image()
	assert(root.size == target_size, "Unexpected window dimensions")
	var error = screenshot.save_png(ProjectSettings.globalize_path(file))
	assert(error == OK, "Failed to save " + file)
	captures.append({"path": file, "window_size": str(root.size), "render_size": str(screenshot.get_size())})
	print("ART CAPTURE ", file)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--art-size="):
			var parts = arg.trim_prefix("--art-size=").split("x")
			target_size = Vector2i(int(parts[0]), int(parts[1]))
		if arg == "--art-large": large_text = true
		if arg == "--art-compact": compact = true
	root.content_scale_size = Vector2i(1600, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.gui_embed_subwindows = true
	root.mode = Window.MODE_WINDOWED
	root.size = target_size
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	game = GalleryGame.new()
	root.add_child(game)
	await settle()
	game.settings.ui_text_size = "large" if large_text else "normal"
	game.settings.reduced_motion = true
	game._apply_ui_text_size()
	game.settings.difficulty = "easy"
	game.progress = {"selected": 1, "cleared": [1, 2, 3], "stars": {"1": 3, "2": 2, "3": 1}}
	game.save_data = {}
	game.loadout = game.DEFAULT_LOADOUT.duplicate()
	game.show_menu()
	await capture("menu")
	game.show_levels()
	game.screen_node.switch_to_level(3)
	await capture("map-street")
	for level in ([26] if compact else [6, 11, 17, 26]):
		game.screen_node.switch_to_level(level)
		await capture("map-" + str(level))
	game.show_prep(26)
	game.screen_node.skip_cinema()
	game.screen_node._auto_pick()
	await capture("prep-twelve")
	if not compact:
		var search: LineEdit = game.screen_node.find_child("RosterSearch", true, false)
		search.text = "灯"
		search.text_changed.emit("灯")
		await capture("prep-search")
	game.open_almanac("plant", Content.PLANT_ORDER.find("sky-mortar"))
	await capture("almanac")
	if not compact:
		game.screen_node._jump_to_section("进化")
		await capture("almanac-evolution")
	game.open_settings()
	game.screen_node._select_page(1)
	await capture("settings-display")
	if not compact:
		game.screen_node._select_page(2)
		await capture("settings-sound")
	game.start_battle(1, Content.PLANT_ORDER.slice(0, 12))
	game._qa_battle_seed()
	game.paused = true
	game.sim.banner = {}
	await capture("battle-twelve")
	if not compact:
		game.show_pause()
		await capture("pause")
		game.close_pause()
	game.finish_run(true)
	await capture("victory")
	if not compact:
		game.start_battle(1, game.DEFAULT_LOADOUT.duplicate())
		game._qa_battle_seed()
		game.finish_run(false)
		await capture("defeat")
		game._qa_show_boss(26)
		game.paused = true
		await capture("boss-five")
	game.show_training_menu()
	await capture("training")
	if not compact:
		game.open_news()
		await capture("news")
		game.show_menu()
		var loading = load("res://ui/screen_loading.gd").new()
		loading.backdrop = load(MarketArt.ROOT + "menu-ensemble.png")
		loading.caption = "准备今夜的灯火与草木"
		loading.fraction = 0.72
		game.ui_root.add_child(loading)
		await create_timer(0.3).timeout
		await capture("loading")
	game.free()
	await process_frame
	var audit = FileAccess.open("%s/gallery-%dx%d-%s.json" % [folder, target_size.x, target_size.y, "large" if large_text else "normal"], FileAccess.WRITE)
	audit.store_string(JSON.stringify({"captures": captures, "aspect": "expand; responsive 16:10 canvas without letterboxing"}, "  "))
	print("ART GALLERY ", captures.size(), " complete")
	quit()
