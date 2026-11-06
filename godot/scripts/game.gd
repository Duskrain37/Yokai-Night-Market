## 根节点：屏幕状态机、输入路由、音频、存档与设置。
##
## 流程：封面 → 选关 → 备战 → 对局 → 结算。图鉴与设置是覆盖层，可从封面、暂停、
## 备战进入，返回时回到来处。训练场与教学关走单独入口，都不写对局存档。
extends Node2D

const SettingsScreen = preload("res://ui/screen_settings.gd")
const MenuScreen = preload("res://ui/screen_menu.gd")
const LevelsScreen = preload("res://ui/screen_levels.gd")
const PrepScreen = preload("res://ui/screen_prep.gd")
const HudScreen = preload("res://ui/screen_hud.gd")
const AlmanacScreen = preload("res://ui/screen_almanac.gd")
const TrainingScreen = preload("res://ui/screen_training.gd")
const Build = preload("res://data/build_info.gd")
const LoadingScreen = preload("res://ui/screen_loading.gd")
var _loading_screen: Control
var _loading_hold: Dictionary = {}
var _loading_busy := false

const VERSION = "0.5.3"
const MOBILE_WORLD = Transform2D(0.0,Vector2(0.92,0.92),0.0,Vector2(120,40))
var touch_router: Node
const SAVE_PATH = "user://run.json"
const SLOTS_PATH = "user://run-slots.json"
const SLOT_COUNT = 3
const DEFAULT_KEYS := {
	"card_1": KEY_1, "card_2": KEY_2, "card_3": KEY_3,
	"card_4": KEY_4, "card_5": KEY_5, "card_6": KEY_6,
	"card_7": KEY_7, "card_8": KEY_8, "card_9": KEY_9,
	"speed_down": KEY_BRACKETLEFT, "speed_up": KEY_BRACKETRIGHT,
}
const SETTINGS_PATH = "user://settings.json"
const PROGRESS_PATH = "user://progress.json"
const RECORDS_PATH = "user://records.json"

const DEFAULT_SETTINGS = {
	"mobile_target_fps": 60,
	"news_seen_version": "",
	"speed": 1.0,
	"auto_collect": true,
	"collect_delay": 0.0,
	"quick_wave": true,
	"health_bars": "bar",
	"difficulty": "easy",
	"cheats": false,
	"sound": true,
	"resolution": "auto",
	"music_style": "complete",
	"music_volume": 70,
	"sfx_volume": 80,
	"show_grid": false,
	"show_text_hints": true,
	"tier_shapes": false,
	"ui_text_size": "normal",
	"key_bindings": {},
	"active_slot": 0,
	"almanac_plant_order": "release",
	"almanac_guest_order": "release",
	"window_width": 1280,
	"window_height": 720,
}

const DIFFICULTY_LABEL = {"easy": "简单", "normal": "普通", "hard": "困难"}

## 首次进游戏时的默认十张卡：能产香火、有本行输出、有肉盾、有控制。
const DEFAULT_LOADOUT = [
	"lantern", "shooter", "wall", "bell", "censer",
	"umbrella", "lion", "torch", "needle", "cat",
]

var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
var records: Dictionary = {}
var progress: Dictionary = {"cleared": [], "selected": 1, "loadout": []}
var save_data: Dictionary = {}
var run_slots: Array[Dictionary] = [{}, {}, {}]
var run_snapshots: Array[Dictionary] = [{}, {}, {}]
var active_slot := 0
var _window_save_delay := -1.0
var _window_changing := false
var _visual_hold_left := 0.0
var _visual_hold_gate := 0.0

var screen = "menu"
var screen_node: Control = null
var overlay_from = ""

var sim: Sim = null
var _battle_stage: Node2D
var board: BoardView = null
var units: UnitView = null
var boss_view: Node2D = null
var hud: Control = null
var ui_layer: CanvasLayer = null
var ui_root: Control = null
var _autosave_t = 0.0
var _finished = false

var selected_level = 1
var loadout: Array = []
var prep = {}
var training = {}
var paused = false
var speed = 1.0
var run_mode = "normal"
var result = {}
var tutorial_active = false

var _music_players: Dictionary = {}
var _music_current = "menu"
var _sfx_players: Array = []
var _sfx_cache: Dictionary = {}
var _sfx_cursor = 0
var _sfx_gates: Dictionary = {}
var mobile := OS.has_feature("android") or "--mobile" in OS.get_cmdline_user_args()
var _qa = false
var _pending_capture = ""
var _qa_sim_seconds = 0.0
var _qa_prep_level = 1

const MUSIC_SCENES = ["menu", "battle", "hot", "final"]


func _ready() -> void:
	if mobile:
		get_tree().quit_on_go_back=false
		Ui.mobile_font_factor=1.1
		Engine.max_fps=60
		get_window().min_size=Vector2i.ZERO
	get_tree().root.theme = Ui.make_theme()
	_qa = "--qa" in OS.get_cmdline_user_args() or DisplayServer.get_name()=="headless"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-size="):
			var parts = arg.trim_prefix("--qa-size=").split("x")
			if parts.size() == 2 and DisplayServer.get_name() != "headless":
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				DisplayServer.window_set_size(Vector2i(int(parts[0]), int(parts[1])))
	if DisplayServer.get_name() != "headless" and not mobile:
		DisplayServer.set_icon(Ui.sprite("lantern").get_image())
		get_window().title = "妖怪夜市 v%s" % VERSION
	# 所有界面控件挂在 CanvasLayer 下的全屏 Control 上：这样锚点以视口为基准，
	# 缩放窗口时各屏都会跟着重排（直接挂在 Node2D 下会以空矩形为基准）。
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 2
	add_child(ui_layer)
	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(ui_root)
	_load_state()
	if mobile:Engine.max_fps=int(settings.get("mobile_target_fps",60))
	_apply_resolution()
	if mobile:
		touch_router=load("res://scripts/mobile_input.gd").new()
		touch_router.game=self
		add_child(touch_router)
		_apply_mobile_safe_area()
	get_window().size_changed.connect(_on_window_size_changed)
	if not _qa:
		var paths: Array[String] = []
		for track in (["menu"] if mobile else MUSIC_BASE + MUSIC_DAY_TRACKS):
			paths.append(_music_path(track))
		for actor in Content.PLANT_ORDER + Content.ZOMBIE_ORDER + ["guardian"]:
			paths.append("res://assets/sprites/%s.png" % actor)
		await _load_transition(paths, "灯火将明", "res://assets/bg/loading-night.png", true)
	Ui.warm_sprites(Content.PLANT_ORDER + Content.ZOMBIE_ORDER + ["guardian"])
	_setup_audio()
	loadout = _clean_loadout(Array(progress.get("loadout", [])))
	if loadout.is_empty():
		loadout = DEFAULT_LOADOUT.duplicate()
	selected_level = clampi(int(progress.get("selected", 1)), 1, Content.LEVELS.size())
	show_menu()
	if _loading_screen != null:
		await _reveal_loaded()
	_handle_cli()
	if mobile and _qa and "--mobile-smoke" in OS.get_cmdline_user_args():
		var runner=load("res://scripts/qa_mobile_device.gd").new()
		add_child(runner)
		runner.run(self)
	if not _qa and String(settings.get("news_seen_version", "")) != VERSION:
		open_news()
		settings.news_seen_version = VERSION
		save_settings()


func _exit_tree() -> void:
	if sim!=null:
		sim.on_win=Callable();sim.on_lose=Callable();sim.on_banner=Callable()


func _process(delta: float) -> void:
	_update_music(delta)
	if _window_save_delay >= 0.0:
		_window_save_delay -= delta
		if _window_save_delay <= 0.0:
			_window_save_delay = -1.0
			save_settings()
	_visual_hold_left = maxf(0.0, _visual_hold_left - delta)
	_visual_hold_gate = maxf(0.0, _visual_hold_gate - delta)
	if sim != null:
		sim.visual_hold = _visual_hold_left > 0.0
	if screen == "battle" and sim != null and not paused:
		var blocked = hud != null and hud.has_method("blocks_simulation") \
			and hud.blocks_simulation()
		if not blocked:
			_tick_battle(delta)
	_update_hover()


# ── 屏幕切换 ────────────────────────────────────────────────────────────────
func _clear_screen() -> void:
	if screen_node != null and is_instance_valid(screen_node):
		screen_node.queue_free()
	screen_node = null


func _set_screen(node: Control, name: String) -> void:
	if mobile and node!=null and name in ["menu","levels","prep","training"]:
		node.free()
		node=load("res://ui/mobile_levels.gd").new() if name=="levels" else load("res://ui/mobile_screen.gd").new()
		node.game=self
		if name!="levels":node.kind=name
	_clear_screen()
	screen = name
	screen_node = node
	if node != null:
		ui_root.add_child(node)
		node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _clear_battle() -> void:
	if sim!=null:
		sim.on_win=Callable();sim.on_lose=Callable();sim.on_banner=Callable()
	if _battle_stage!=null and is_instance_valid(_battle_stage):_battle_stage.queue_free()
	_battle_stage=null
	if boss_view!=null and is_instance_valid(boss_view):boss_view.queue_free()
	boss_view=null
	if hud != null and is_instance_valid(hud):
		hud.queue_free()
	hud = null
	if board != null and is_instance_valid(board):
		board.queue_free()
	board = null
	if units != null and is_instance_valid(units):
		units.queue_free()
	units = null
	sim = null


func show_menu() -> void:
	paused = false
	_clear_battle()
	var node = MenuScreen.new()
	node.game = self
	_set_screen(node, "menu")
	play_music_scene("menu")


func show_levels() -> void:
	paused = false
	_clear_battle()
	var node = LevelsScreen.new()
	node.game = self
	_set_screen(node, "levels")
	play_music_scene("menu")


func show_prep(level_id: int, training_mode: bool = false, training_day: int = 1) -> void:
	paused = false
	_clear_battle()
	selected_level = clampi(level_id, 1, Content.LEVELS.size())
	var level = Content.get_level(selected_level)
	prep = {
		"level": level,
		"training": training_mode,
		"training_day": training_day,
		"selected": loadout.duplicate(),
		"warning": "",
	}
	var node = PrepScreen.new()
	node.game = self
	_set_screen(node, "prep")
	play_music_scene("menu")


func open_almanac(tab: String = "plant", index: int = 0) -> void:
	overlay_from = screen
	_clear_screen()
	var node = load("res://ui/mobile_screen.gd").new() if mobile else AlmanacScreen.new()
	if mobile:node.kind="almanac"
	node.game = self
	node.tab = tab
	node.index = index
	ui_root.add_child(node)
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_node = node
	screen = "almanac"


func open_news() -> void:
	overlay_from = screen
	_clear_screen()
	var node = load("res://ui/screen_news.gd").new()
	node.game = self
	ui_root.add_child(node)
	screen_node = node
	screen = "news"


func open_settings() -> void:
	overlay_from = screen
	_clear_screen()
	var node = load("res://ui/mobile_screen.gd").new() if mobile else SettingsScreen.new()
	if mobile:node.kind="settings"
	node.game = self
	ui_root.add_child(node)
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_node = node
	screen = "settings"


func close_overlay() -> void:
	var target = overlay_from
	overlay_from = ""
	match target:
		"menu":
			show_menu()
		"levels":
			show_levels()
		"prep":
			show_prep(int(prep.get("level", {}).get("id", selected_level)),
				bool(prep.get("training", false)),
				int(prep.get("training_day", 1)))
		"battle", "paused":
			var tutorial_book = screen == "almanac" and tutorial_active and sim != null
			screen = "battle"
			_clear_screen()
			if tutorial_book and sim.tutorial_step() == "almanac":
				sim.finish_tutorial_almanac()
				return
			if paused:
				show_pause()
		"result":
			screen = "result"
			_clear_screen()
			_show_result(result.get("won", false))
		"almanac":
			open_almanac()
		_:
			show_menu()


func show_training_menu() -> void:
	var node = TrainingScreen.new()
	node.game = self
	_set_screen(node, "training")


# ── 对局 ────────────────────────────────────────────────────────────────────
func start_battle(level_id: int, cards: Array, mode = "normal", restore_data: Dictionary = {}) -> void:
	if _loading_busy:
		return
	if not _qa:
		var map = _battle_map(level_id, mode)
		var background = "res://assets/bg/map-%s.png" % map
		if not ResourceLoader.exists(background):
			background = "res://assets/bg/map-%s.jpg" % map
		await _load_transition(_battle_resources(level_id, cards, background, map), "守夜将启", "res://assets/bg/loading-night.png")
	_start_battle_now(level_id, cards, mode, restore_data.is_empty())
	if not restore_data.is_empty():
		sim.restore(restore_data)
		board.set_map(Content.map_key(sim.level))
		settings["difficulty"] = sim.difficulty
		hud.refresh()
	if _loading_screen != null:
		paused = true
		await _reveal_loaded()
		paused = false


func _start_battle_now(level_id: int, cards: Array, mode: String, save_initial := true) -> void:
	_clear_screen()
	_clear_battle()
	_finished = false
	paused = false
	selected_level = level_id
	run_mode = String(mode)
	sim = Sim.new()
	sim.auto_collect = bool(settings["auto_collect"])
	sim.collect_delay = float(settings["collect_delay"])
	sim.on_win = func(): finish_run(true)
	sim.on_lose = func(z): finish_run(false, z)
	sim.on_banner = func(text): pass
	if mode == "tutorial":
		tutorial_active = true
		sim.start_tutorial()
	else:
		tutorial_active = false
		var level = Content.get_level(level_id)
		sim.setup(level, cards, String(settings["difficulty"]))
		if mode == "training":
			sim.training = true
			sim.no_cooldown = not bool(training.get("cooldown_locked", true))
			sim.sun = 1000
			sim.count_mul = 1.0
			sim.hp_mul = 1.0
	if mobile:
		_battle_stage=Node2D.new()
		_battle_stage.transform=ui_root.get_transform()*MOBILE_WORLD
		add_child(_battle_stage)
	board = BoardView.new()
	board.sim = sim
	board.show_grid = bool(settings["show_grid"])
	board.set_map(_battle_map(level_id, mode))
	_battle_parent().add_child(board)
	units = UnitView.new()
	units.sim = sim
	units.health_bars = String(settings["health_bars"])
	units.tier_shapes = bool(settings["tier_shapes"])
	_visual_hold_left = 0.0
	_visual_hold_gate = 0.0
	_battle_parent().add_child(units)
	boss_view=preload("res://scripts/boss_view.gd").new()
	boss_view.sim=sim
	_battle_parent().add_child(boss_view)
	hud = load("res://ui/mobile_hud.gd").new() if mobile else HudScreen.new()
	hud.game = self
	ui_root.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var boss_ui=preload("res://ui/boss_hud.gd").new()
	boss_ui.game=self
	hud.add_child(boss_ui)
	boss_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen = "battle"
	screen_node = null
	# 0.1× 慢放是训练场的观察档；教程一律 1×，免得旁白跟不上画面
	apply_speed(1.0)
	if save_initial and mode != "tutorial" and mode != "training":
		save_run()
	_music_for_wave()


func _battle_map(level_id: int, mode: String) -> String:
	if mode == "tutorial":
		return "day1"
	return Content.map_key(Content.get_level(level_id))


func _battle_resources(level_id: int, cards: Array, background: String, map: String) -> Array[String]:
	var paths: Array[String] = [background]
	if mobile:
		var day: int=int(Content.get_level(level_id).get("day",1))
		for phase in ["battle","hot","final"]:paths.append(_music_path("day%d-%s" % [day,phase]))
	for material in ["straw", "stonehat", "paper", "sedan", "urn", "mask"]:
		paths.append("res://assets/sprites/armor-%s-atlas.png" % material)
	for index in [1, 2, 3]:
		paths.append("res://assets/sprites/mushroom-growth-%d.png" % index)
		for kind in ["market", "water", "island"]:
			paths.append("res://assets/sprites/obstacle-%s-%d.png" % [kind, index])
	paths.append("res://assets/sprites/mower-%s.png" % {"day4": "day2", "day5": "day3"}.get(map, map))
	paths.append("res://assets/sprites/guest-gear-v042.png")
	paths.append("res://assets/sprites/armor-profile-v052.png")
	for role in ["sedan-unarmored", "paper-unarmored-v2"]:
		paths.append("res://assets/sprites/%s.png" % role)
	var allies = cards.duplicate()
	allies.append("lantern")
	var foes = Content.plants_in_level(Content.get_level(level_id)) if level_id > 0 else ["ghost"]
	if "sedan" in foes or "matchmaker" in foes:
		foes.append_array(["sedan", "sedan-empty", "sedan-loaded", "bride", "ghost"])
	if "phaseguard" in foes or "tamer" in foes:
		foes.append_array(["phase-veil", "phase-kite"])
	var motion = JSON.parse_string(FileAccess.get_file_as_string("res://data/actor_motion_mobile.json" if mobile and FileAccess.file_exists("res://data/actor_motion_mobile.json") else "res://data/actor_motion.json"))
	if motion is Dictionary:
		for actor in allies + foes + ["v052-boss-fx", "v052-plant-fx", "v052-projectiles", "v052-craters", "v053-buff-fx"]:
			if motion.has(actor):
				for file in motion[actor].get("clip_files",{"default":motion[actor].file}).values():paths.append("res://"+String(file))
		var level := Content.get_level(level_id)
		var bosses: Array = level.get("boss_checkpoints", []).duplicate()
		bosses.append_array([level.get("mid_boss", ""), level.get("boss_id", "")])
		for id in bosses:
			var actor := "boss-%s" % id
			if motion.has(actor):
				for file in motion[actor].get("clip_files",{"default":motion[actor].file}).values():paths.append("res://"+String(file))
	var forms = JSON.parse_string(FileAccess.get_file_as_string("res://data/evolution_art_v040.json"))
	if forms is Dictionary and not mobile:
		for actor in forms:
			paths.append("res://" + String(forms[actor]["file"]))
	for atlas in ["boss_earth_atlas", "boss_paper_atlas", "boss_river_atlas", "props_atlas", "fx_atlas"]:
		paths.append("res://assets/boss/%s.png" % atlas)
	return paths


func _load_transition(paths: Array[String], caption: String, backdrop: String, cold: bool = false) -> void:
	_loading_busy = true
	_loading_hold.clear()
	_loading_screen = LoadingScreen.new()
	_loading_screen.caption = caption
	_loading_screen.backdrop = load(backdrop)
	_loading_screen.modulate.a = 1.0 if cold else 0.0
	var layer := CanvasLayer.new()
	layer.layer = 7
	add_child(layer)
	layer.add_child(_loading_screen)
	if not cold:
		paused = true
		var enter = create_tween()
		enter.tween_property(_loading_screen, "modulate:a", 1.0, 0.28).set_trans(Tween.TRANS_SINE)
		await enter.finished
	await get_tree().process_frame

	var waiting: Array[String] = []
	for path in paths:
		if ResourceLoader.exists(path) and not waiting.has(path):
			waiting.append(path)
	var total = waiting.size()
	var running: Array[String] = []
	var finished := 0
	while finished < total:
		while not waiting.is_empty() and running.size() < 6:
			var path: String = waiting.pop_front()
			if ResourceLoader.load_threaded_request(path) == OK:
				running.append(path)
			else:
				finished += 1
		var partial := 0.0
		for path in running.duplicate():
			var detail: Array = []
			var status = ResourceLoader.load_threaded_get_status(path, detail)
			if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				if not detail.is_empty():
					partial += float(detail[0])
				continue
			if status == ResourceLoader.THREAD_LOAD_LOADED:
				_loading_hold[path] = ResourceLoader.load_threaded_get(path)
			running.erase(path)
			finished += 1
		_loading_screen.fraction = (finished + partial) / maxf(1.0, total)
		await get_tree().process_frame
	_loading_screen.fraction = 1.0
	while _loading_screen.displayed < 1.0:
		await get_tree().process_frame


func _reveal_loaded() -> void:
	await get_tree().process_frame
	var layer = _loading_screen.get_parent()
	var leave = create_tween()
	leave.tween_property(_loading_screen, "modulate:a", 0.0, 0.38).set_trans(Tween.TRANS_SINE)
	await leave.finished
	layer.queue_free()
	_loading_screen = null
	_loading_hold.clear()
	_loading_busy = false


func _tick_battle(delta: float) -> void:
	if sim == null:
		return
	var step = 1.0 / 60.0
	var scaled = delta * speed
	var budget = 0.25
	if paused or delta <= 0.0:
		return
	var guard = 0
	while scaled > 0.0 and guard < 12:
		var use = minf(step, scaled)
		sim.tick(use)
		scaled -= use
		guard += 1
		if sim.tutorial != null and String(sim.tutorial["step"]) == "done":
			break
	if not sim.visual_hold and board != null:
		var amount: float = sim.shake
		board.position = Vector2(sin(sim.time * 61.0) * amount * 0.5,
			cos(sim.time * 53.0) * amount * 0.4)
	if sim.hit_stop_requested > 0.0:
		if _visual_hold_gate <= 0.0:
			_visual_hold_left = sim.hit_stop_requested
			_visual_hold_gate = _visual_hold_left + 0.12
			sim.visual_hold = true
			for view in [board, units, boss_view]:
				if view != null:
					view.queue_redraw()
		sim.hit_stop_requested = 0.0
	_drain_sounds()
	if String(sim.tutorial_step()) == "done" and tutorial_active:
		finish_run(true)
		return
	if sim.is_cleared():
		finish_run(true)
		return
	if hud != null and hud.has_method("refresh"):
		hud.refresh()
	_music_for_wave()
	if sim.tutorial == null and not sim.training:
		_autosave_t += delta
		if _autosave_t >= 8.0:
			_autosave_t = 0.0
			save_run()


func _drain_sounds() -> void:
	if sim == null:
		return
	for i in sim.sounds.size():
		var name = String(sim.sounds[i])
		var detail: Dictionary = sim.sound_detail[i] if i < sim.sound_detail.size() else {}
		play_sfx(name, detail)
	sim.sounds.clear()
	sim.sound_detail.clear()


func finish_run(won: bool, z = null) -> void:
	if sim == null or _finished:
		return
	if screen != "battle" and screen != "result":
		return
	_finished = true
	if paused:
		return
	result = {
		"won": won,
		"time": sim.time,
		"kills": sim.kills,
		"sun": sim.sun,
		"level_id": sim.level_id,
		"training": sim.training,
		"tutorial": sim.tutorial != null,
		"summary": sim.battle_summary(),
		"groups_completed": sim.completed_major_waves(),
	}
	_update_records(won)
	if sim.tutorial != null:
		# 教过一遍就记一笔：封面主按钮只带没学过的人进教程
		if won and not bool(progress.get("taught", false)):
			progress["taught"] = true
			save_progress()
	if not sim.training and sim.tutorial == null:
		run_snapshots[active_slot] = {"result": result.duplicate(true),
			"sim": sim.serialize(), "saved_at": int(Time.get_unix_time_from_system())}
		clear_run()
		if won:
			var cleared: Array = _night_ids(progress.get("cleared", []))
			cleared.append(int(sim.level_id))
			progress["cleared"] = cleared
			progress["selected"] = Content.next_story_level(sim.level_id) if Content.next_story_level(sim.level_id)>0 else sim.level_id
			# 星级只记最好的一次，重打是为了刷星不是为了掉星
			var stars: Dictionary = progress.get("stars", {})
			var got = int(result["summary"].get("stars", 0))
			if int(stars.get(str(sim.level_id), 0)) < got:
				stars[str(sim.level_id)] = got
			progress["stars"] = stars
			save_progress()
	paused = false
	screen = "result"
	_clear_screen()
	_show_result(won)
	play_sfx("win" if won else "lose")
	play_music_scene("menu")


func _show_result(won: bool) -> void:
	if hud != null and is_instance_valid(hud):
		hud.visible = false
	var node = load("res://ui/mobile_hud.gd").new() if mobile else HudScreen.new()
	node.game = self
	node.result_mode = true
	node.won = won
	node.result = result
	screen_node = node
	ui_root.add_child(node)
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen = "result"


func show_pause() -> void:
	if sim == null or screen != "battle":
		return
	hud.cancel_selection()
	paused = true
	_music_duck = 1.0
	var node = load("res://ui/mobile_hud.gd").new() if mobile else HudScreen.new()
	node.game = self
	node.pause_mode_ui = true
	screen_node = node
	ui_root.add_child(node)
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func close_pause() -> void:
	paused = false
	_music_duck = 0.0
	if screen_node != null and is_instance_valid(screen_node) and screen_node.has_method("resume"):
		screen_node.queue_free()
		screen_node = null


func restart_run() -> void:
	var level_id = sim.level_id if sim != null else selected_level
	var mode = "normal"
	if sim != null and sim.training:
		mode = "training"
	elif tutorial_active:
		mode = "tutorial"
	paused = false
	if mode == "tutorial":
		start_battle(level_id, ["shooter"], "tutorial")
	elif mode == "training":
		show_prep(level_id, true, int(training.get("day", 1)))
	else:
		show_prep(level_id)


func back_to_menu() -> void:
	if sim != null and not paused and screen == "battle" and not tutorial_active:
		save_run()
	paused = false
	tutorial_active = false
	show_menu()


# ── 输入 ────────────────────────────────────────────────────────────────────
func _update_hover() -> void:
	if sim == null or board == null or units == null:
		return
	var pos = _mouse_world()
	# 舞台是透视的：屏幕点要先换算回平面格
	var cell = Geo.screen_cell_at(pos, sim.rows)
	board.hover_cell = cell if screen == "battle" and not paused else Vector2i(-1, -1)
	units.hover_target = null


func _mouse_world() -> Vector2:
	return _mobile_world_transform().affine_inverse()*get_viewport().get_mouse_position() if mobile else get_viewport().get_mouse_position()


func _unhandled_input(event: InputEvent) -> void:
	if _loading_busy:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F11:
				_toggle_fullscreen()
			KEY_ESCAPE:
				_on_escape()
			KEY_SPACE:
				if screen == "battle" and not tutorial_active:
					toggle_pause()
			KEY_P:
				if screen == "battle" and not tutorial_active:
					toggle_pause()
			_:
				if screen == "battle" and not paused and hud != null and not hud.blocks_simulation():
					var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
					for action in DEFAULT_KEYS:
						if key != bound_key(action):
							continue
						if action.begins_with("card_"):
							var index := int(action.trim_prefix("card_")) - 1
							if index < sim.cards.size():
								hud._on_card(index)
						elif not tutorial_active:
							hud.step_speed(1 if action == "speed_up" else -1)
						break
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if screen == "battle" and hud != null:
				hud.cancel_selection()
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if screen == "battle" and not paused:
			# 用事件自带的坐标，别去轮询鼠标：这样点击判定只依赖这一次事件本身
			_handle_battle_click(event.position)


func _on_escape() -> void:
	match screen:
		"settings", "almanac", "training", "news":
			if screen == "training":
				show_menu()
			else:
				close_overlay()
		"levels":
			show_menu()
		"prep":
			show_levels() if not bool(prep.get("training", false)) else show_training_menu()
		"battle":
			if not paused:
				toggle_pause()
		"result":
			show_menu()
		"menu":
			pass


func toggle_pause() -> void:
	if paused:
		close_pause()
	else:
		show_pause()


func _handle_battle_click(pos: Vector2) -> void:
	if mobile:pos=_mobile_world_transform().affine_inverse()*pos
	if sim == null or hud == null:
		return
	if hud.has_method("blocks_simulation") and hud.blocks_simulation():
		return
	var cell = Geo.screen_cell_at(pos, sim.rows)
	if hud.shovel_mode:
		if cell.x >= 0:
			var outcome = sim.shovel_at(cell.x, cell.y)
			if not bool(outcome["ok"]):
				sim.deny(String(outcome["text"]), pos)
			hud.set_shovel_mode(false)
			hud.refresh()
		return
	var orb = sim.pick_orb(pos)
	if not orb.is_empty():
		sim.collect_orb(orb)
		return
	if hud.card_selected >= 0:
		if cell.x >= 0:
			var ok = sim.try_place_card(hud.card_selected, cell.x, cell.y, pos)
			if ok:
				hud.card_selected = -1
				hud.refresh()
		return
	if cell.x < 0:
		hud.close_fan()
		return
	# 之前开着别人的升阶面板就收起，再按这次的命中重新判定
	if hud.focus_plant != null:
		hud.close_fan()
	var plant = sim.main_plant_at(cell.x, cell.y)
	if plant == null:
		plant = sim.lily_at(cell.x, cell.y)
	if plant != null:
		hud.try_open_menu(plant, pos)
	else:
		hud.focus_plant = null


# ── 设置与进度 ──────────────────────────────────────────────────────────────
func set_setting(key: String, value) -> void:
	settings[key] = value
	if key == "mobile_target_fps" and mobile:
		Engine.max_fps=int(value)
	elif key == "sound":
		_apply_volume()
	elif key == "music_volume" or key == "sfx_volume":
		_apply_volume()
	elif key == "show_grid" and board != null:
		board.show_grid = bool(value)
	elif key == "health_bars" and units != null:
		units.health_bars = String(value)
	elif key == "auto_collect" and sim != null:
		sim.auto_collect = bool(value)
	elif key == "collect_delay" and sim != null:
		sim.collect_delay = float(value)
	elif key == "cheats" and hud != null and is_instance_valid(hud):
		hud.set_cheats_enabled(bool(value))
	elif key == "speed" and screen == "battle" and not tutorial_active:
		apply_speed(float(value))
	elif key == "ui_text_size":
		_apply_ui_text_size()
	elif key == "tier_shapes" and units != null:
		units.tier_shapes = bool(value)
	elif key == "resolution":
		_apply_resolution()
	elif key == "music_style":
		if screen == "battle":
			_music_for_wave()
			play_music_scene(_music_current, true)
		else:
			play_music_scene("menu", true)
	save_settings()


## 0.1× 是训练场的观察档：正式对局一律抬到 1× 以上，
## 局内切速度也走这里，免得从设置面板绕过下限。
func speed_floor() -> float:
	return 0.1


func apply_speed(value: float) -> void:
	speed = maxf(speed_floor(), value)


func bound_key(action: String) -> int:
	var bindings: Dictionary = settings.get("key_bindings", {})
	return int(bindings.get(action, DEFAULT_KEYS.get(action, 0)))


func rebind_key(action: String, key: int) -> void:
	if not DEFAULT_KEYS.has(action):
		return
	var bindings: Dictionary = settings["key_bindings"].duplicate()
	for other in DEFAULT_KEYS:
		if other != action and bound_key(other) == key:
			bindings[other] = bound_key(action)
			break
	bindings[action] = key
	set_setting("key_bindings", bindings)


func _apply_ui_text_size() -> void:
	Ui.text_scale = float({"normal": 1.0, "medium": 1.1, "large": 1.2}.get(settings["ui_text_size"], 1.0))
	var theme := Ui.make_theme()
	theme.default_font_size = Ui.font_size(20)
	if ui_root != null:
		Ui.refresh_text_sizes(ui_root)


func _remember_window_size() -> void:
	var actual := DisplayServer.window_get_size()
	if actual.x >= 480 and actual.y >= 270:
		settings["window_width"] = actual.x
		settings["window_height"] = actual.y


func _on_window_size_changed() -> void:
	if mobile:
		_apply_mobile_safe_area()
		return
	if _qa or _window_changing or DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	_remember_window_size()
	settings["resolution"] = "window"
	_window_save_delay = 0.4


func _toggle_fullscreen() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		set_setting("resolution", "window")
	else:
		_remember_window_size()
		set_setting("resolution", "auto")


## 分辨率：自适应全屏按显示器走；固定档开窗并按所选像素、居中摆放。
## 画面本身是 16:9 设计（stretch aspect=keep），非 16:9 窗口会有细窄留边。
func _apply_resolution() -> void:
	if mobile:
		if OS.has_feature("android"):DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
		return
	if DisplayServer.get_name() == "headless":
		return
	# QA 截图时用 --qa-size 固定窗口，别被「自适应全屏」抢走
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-size="):
			return
	var value = String(settings.get("resolution", "auto"))
	if value == "auto":
		_window_changing = true
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_release_window_change.call_deferred()
		return
	var target := Vector2i(int(settings["window_width"]), int(settings["window_height"]))
	if value != "window":
		var parts = value.split("x")
		if parts.size() != 2:
			return
		target = Vector2i(int(parts[0]), int(parts[1]))
	var usable := DisplayServer.screen_get_usable_rect()
	target = target.clamp(Vector2i(480, 270), usable.size)
	settings["window_width"] = target.x
	settings["window_height"] = target.y
	_window_changing = true
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(target)
	DisplayServer.window_set_position(usable.position + (usable.size - target) / 2)
	_release_window_change.call_deferred()


func _release_window_change() -> void:
	await get_tree().process_frame
	_window_changing = false


func save_settings() -> void:
	_write_json(SETTINGS_PATH, settings)


func save_progress() -> void:
	progress["selected"] = selected_level
	progress["loadout"] = loadout.duplicate()
	_write_json(PROGRESS_PATH, progress)


func save_records() -> void:
	_write_json(RECORDS_PATH, records)


## 通关名单只留真实存在的夜号，并且一律收成整数、去重。
static func _night_ids(raw) -> Array:
	var out: Array = []
	for value in raw:
		var id = int(value)
		if id >= 1 and id <= Content.LEVELS.size() and not out.has(id):
			out.append(id)
	return out


func _update_records(won: bool) -> void:
	if sim == null or sim.training or sim.tutorial != null:
		return
	if bool(sim.cheated):
		# 动过调整面板的那一夜另册存放，不污染难度最好成绩
		var book: Dictionary = _record_book("cheated", "")
		book["runs"] = int(book.get("runs", 0)) + 1
		_record_tally(book, won)
	else:
		_record_tally(_record_book("by_diff", String(sim.difficulty)), won)
	save_records()


func _record_tally(book: Dictionary, won: bool) -> void:
	book["best_kills"] = maxi(int(book.get("best_kills", 0)), sim.kills)
	var previous = int(book.get("best_groups", int(book.get("best_wave", 0)) / Content.WAVES_PER_GROUP))
	var completed = Content.wave_groups(sim.level) if won else sim.completed_major_waves()
	book["best_groups"] = maxi(previous, completed)
	book["best_wave"] = maxi(int(book.get("best_wave", 0)), sim.wave_index)
	if not won:
		return
	book["wins"] = int(book.get("wins", 0)) + 1
	var best = book.get("best_time")
	if best == null or float(best) > sim.time:
		book["best_time"] = sim.time


func _record_book(group: String, name: String) -> Dictionary:
	var books: Dictionary = records.get(group, {})
	var book: Dictionary = books.get(name, {})
	books[name] = book
	records[group] = books
	return book


## v0.3.1 及更早只有一本不分难度的总账。旧数字不丢，整册挪进「旧版累计」一栏。
func _records_v2() -> void:
	var legacy = {}
	for key in ["wins", "best_kills", "best_wave", "best_time"]:
		if records.has(key):
			legacy[key] = records[key]
			records.erase(key)
	if not legacy.is_empty() and not records.has("legacy"):
		records["legacy"] = legacy


func save_run() -> void:
	if sim == null or sim.training or sim.tutorial != null:
		return
	var payload = {
		"version": 1,
		"level_id": sim.level_id,
		"loadout": loadout.duplicate(),
		"difficulty": sim.difficulty,
		"sim": sim.serialize(),
		"saved_at": int(Time.get_unix_time_from_system()),
	}
	save_data = payload
	run_slots[active_slot] = payload
	_write_slots()


func clear_run() -> void:
	save_data = {}
	run_slots[active_slot] = {}
	_write_slots()


func set_run_slot(index: int) -> void:
	if index < 0 or index >= SLOT_COUNT:
		return
	active_slot = index
	save_data = run_slots[index]
	set_setting("active_slot", index)


func _write_slots() -> void:
	var path := _data_path(SLOTS_PATH)
	var temporary := path + ".pending"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		push_warning("无法写入守夜存档")
		return
	file.store_string(JSON.stringify({"runs": run_slots, "snapshots": run_snapshots}))
	file.close()
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),
			ProjectSettings.globalize_path(path)) != OK:
		push_warning("无法替换守夜存档")


func _load_slots() -> void:
	var saved := _read_json(SLOTS_PATH)
	var runs: Array = saved.get("runs", [])
	var snapshots: Array = saved.get("snapshots", [])
	for index in SLOT_COUNT:
		run_slots[index] = runs[index] if index < runs.size() and runs[index] is Dictionary and runs[index].has("sim") else {}
		run_snapshots[index] = snapshots[index] if index < snapshots.size() and snapshots[index] is Dictionary else {}
	if not saved.has("runs"):
		var legacy := _read_json(SAVE_PATH)
		if legacy.has("sim"):
			run_slots[0] = legacy
			_write_slots()
	active_slot = clampi(int(settings["active_slot"]), 0, SLOT_COUNT - 1)
	save_data = run_slots[active_slot]


func has_save() -> bool:
	return not save_data.is_empty()


func continue_run() -> void:
	if save_data.is_empty():
		return
	var payload: Dictionary = save_data.get("sim", {})
	if payload.is_empty():
		clear_run()
		show_levels()
		return
	loadout = _clean_loadout(Array(save_data.get("loadout", [])))
	start_battle(int(save_data.get("level_id", 1)), loadout, "normal", payload)


func _load_state() -> void:
	var loaded = _read_json(SETTINGS_PATH)
	for key in DEFAULT_SETTINGS:
		if loaded.has(key):
			var default = DEFAULT_SETTINGS[key]
			var value = loaded[key]
			if default is bool:
				settings[key] = bool(value)
			elif default is int:
				settings[key] = int(value)
			elif default is float:
				settings[key] = float(value)
			else:
				settings[key] = value
	progress = _read_json(PROGRESS_PATH, {"cleared": [], "selected": 1, "loadout": []})
	# JSON 读回来的整数全是浮点，而 Array.has(1) 认不出 1.0——不收敛的话
	# 每次读档后通关的那一夜都会被再追加一遍，守夜记录就凭空多出一夜。
	progress["cleared"] = _night_ids(progress.get("cleared", []))
	progress["selected"] = clampi(int(progress.get("selected", 1)), 1, Content.LEVELS.size())
	records = _read_json(RECORDS_PATH, {})
	_records_v2()
	if not settings["key_bindings"] is Dictionary:
		settings["key_bindings"] = {}
	_apply_ui_text_size()
	_load_slots()


func _data_path(path: String) -> String:
	if not _qa:return path
	var directory="user://qa-v040"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	return directory+"/"+path.get_file()


func _write_json(path: String, data: Dictionary) -> void:
	path=_data_path(path)
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("无法写入 %s" % path)
		return
	file.store_string(JSON.stringify(data, "  "))
	file.close()


func _read_json(path: String, fallback: Dictionary = {}) -> Dictionary:
	path=_data_path(path)
	if not FileAccess.file_exists(path):
		return fallback.duplicate(true)
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return fallback.duplicate(true)
	var text = file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return fallback.duplicate(true)


func _clean_loadout(ids: Array) -> Array:
	var out: Array = []
	for id in ids:
		var key = String(id)
		if not Content.PLANTS.has(key) or out.has(key):
			continue
		out.append(key)
		if out.size() >= Sim.MAX_LOADOUT:
			break
	return out


# ── 音频 ────────────────────────────────────────────────────────────────────
## 两条音乐风格：
##   朴素：所有关卡都用 v0.2.4 那三套通用配乐（先锋/白热化/最终）；
##   完整：每周各有先锋、白热化、最终三首。
## 两种风格共用同一首菜单曲。
const MUSIC_BASE = ["menu", "battle", "hot", "final"]
const MUSIC_DAY_TRACKS = [
	"day1-battle", "day1-hot", "day1-final",
	"day2-battle", "day2-hot", "day2-final",
	"day3-battle", "day3-hot", "day3-final",
	"day4-battle", "day4-hot", "day4-final",
	"day5-battle", "day5-hot", "day5-final",
]
const MUSIC_STYLE_LABEL = {"plain": "朴素", "complete": "完整"}


func _music_path(name: String) -> String:
	if name.begins_with("day"):
		return "res://assets/music/complete/%s.ogg" % name
	return "res://assets/music/%s.ogg" % name


func _setup_audio() -> void:
	for name in MUSIC_BASE + MUSIC_DAY_TRACKS:
		var player = AudioStreamPlayer.new()
		var path = _music_path(name)
		if ResourceLoader.exists(path) and (not mobile or name=="menu"):
			var stream: AudioStream = load(path)
			if stream != null:
				if stream is AudioStreamOggVorbis:
					stream.loop = true
				elif stream.has_method("set_loop"):
					stream.set("loop", true)
			player.stream = stream
		player.volume_db = -60.0
		add_child(player)
		_music_players[name] = player
	for i in 10:
		var player = AudioStreamPlayer.new()
		player.volume_db = -8.0
		add_child(player)
		_sfx_players.append(player)
	_apply_volume()


func music_style() -> String:
	var style = String(settings.get("music_style", "complete"))
	return style if MUSIC_STYLE_LABEL.has(style) else "complete"


## 波次 → 段落：前六波「先锋」，第七波起「白热化」，最后两波「最终」。
func wave_phase() -> String:
	var total = int(sim.level.get("waves", []).size())
	var index = sim.wave_index
	if sim.boss != null and sim.boss.alive():
		return "final"
	if total > 0 and index >= ceili(total * 0.5):
		return "hot"
	return "battle"


func _has_track(name: String) -> bool:
	var player = _music_players.get(name)
	if mobile and player!=null and player.stream==null and ResourceLoader.exists(_music_path(name)):
		player.stream=load(_music_path(name))
		if player.stream is AudioStreamOggVorbis:player.stream.loop=true
	return player != null and player.stream != null


## 解析当前该放哪一首：朴素=通用三套；完整=当天那一套。
func resolve_battle_track(day: int, phase: String) -> String:
	if music_style() == "plain":
		return phase
	var lane = clampi(day, 1, Content.DAYS.size())
	var name = "day%d-%s" % [lane, phase]
	if _has_track(name):
		return name
	return phase


func play_music_scene(scene: String, force: bool = false) -> void:
	if mobile:_has_track(scene)
	if _music_current == scene and not force:
		return
	_music_current = scene
	if _qa or DisplayServer.get_name() == "headless":
		return
	var player: AudioStreamPlayer = _music_players.get(scene)
	if player != null and player.stream != null and not player.playing:
		player.play()


func _update_music(delta: float) -> void:
	if _music_players.is_empty():
		return
	var on = bool(settings.get("sound", true)) and not _qa
	for name in _music_players:
		var player: AudioStreamPlayer = _music_players[name]
		if not player.playing:
			if name == _music_current and on and player.stream != null \
					and DisplayServer.get_name() != "headless":
				player.play()
			continue
		var goal = -60.0
		if on and name == _music_current:
			goal = -7.0 - (_music_duck * 6.0)
		player.volume_db = lerpf(player.volume_db, goal, clampf(delta * 1.8, 0.0, 1.0))
		if player.volume_db < -55.0 and goal < -55.0:
			player.stop()
			if mobile and name!="menu":player.stream=null


func _music_for_wave() -> void:
	if sim == null or screen != "battle":
		return
	var day = 1
	if sim.training:
		day = int(training.get("day", 1))
	elif sim.level.has("day"):
		day = int(sim.level["day"])
	var phase := wave_phase()
	if phase == "hot" and not sim.battle_hot and not sim.training and sim.tutorial == null:
		sim.battle_hot = true
		if sim.banner.is_empty():
			sim.banner = {"text": "夜半已至 · 来客渐急", "t": 3.4, "max": 3.4, "ceremony": true}
		sim.banner["subtitle"] = "夜市进入白热化"
	play_music_scene(resolve_battle_track(day, phase))


func _apply_volume() -> void:
	_sfx_volume = float(settings.get("sfx_volume", 80)) / 100.0


var _sfx_volume = 0.8
var _music_duck = 0.0


func play_sfx(name: String, detail: Dictionary = {}) -> void:
	if not bool(settings["sound"]) or _sfx_volume<=0.0001 or _qa or DisplayServer.get_name() == "headless":
		return
	var now=Time.get_ticks_msec()/1000.0
	var gate=0.08
	if name in ["collect","produce"]:gate=0.20
	elif name == "splash":gate=0.24
	elif name in ["hit","eat","shoot","needle_shot","star_shot","cat_shot"]:gate=0.10
	elif name.begins_with("boss"):gate=0.18
	if now<float(_sfx_gates.get(name,-100.0))+gate:return
	_sfx_gates[name]=now
	var stream = _sfx_for(name, detail)
	if stream == null:
		return
	var player: AudioStreamPlayer = _sfx_players[_sfx_cursor % _sfx_players.size()]
	_sfx_cursor += 1
	player.stream = stream
	player.volume_db = linear_to_db(_sfx_volume)-2.0
	if name == "produce":
		player.volume_db -= 4.0
	player.pitch_scale = 1.0
	if name in ["hit","armor_break","eat"]:player.volume_db-=3.0
	player.play()


## 命中音的材质：斗笠是草/纸，石帽是石，陶瓮是陶，铁面是铁，其余按纸算
func _hit_material(armor_type: String, detail: Dictionary) -> String:
	match armor_type:
		"straw":
			return "straw"
		"stonehat":
			return "stone"
		"urn":
			return "urn"
		"mask":
			return "iron"
		"paper", "sedan", "charm":
			return "paper"
		_:
			return "body"


## 一击的声音：低频为主、几乎没有高频嘶声，打在本体与打在护具上各有材质感。
## 每条都是"噪声瞬态 + 几个衰减正弦"手工叠出来的，不走原来的单音合成器。
## 中式怪谈的四条基本音：木牌的叩、铜铃的响、烟气散、远处的鼓。
## 都是"几个衰减正弦 + 一撮带通噪声"，没有电子味的上滑与颤音。
func _synth_mood(key: String) -> AudioStreamWAV:
	var rate = 22050
	var dur = 0.3
	var layers: Array = []          # [freq, amp, decay_ms]
	var noise_amp = 0.0
	var noise_lp = 1200.0
	var noise_hp = 200.0
	var noise_decay = 30.0
	var attack = 0.004
	match key:
		"click":
			# 木牌被指节轻叩一下：很干、很低
			dur = 0.14
			layers = [[196.0, 0.5, 42.0], [294.0, 0.22, 26.0]]
			noise_amp = 0.35
			noise_lp = 1500.0
			noise_hp = 300.0
			noise_decay = 8.0
		"collect":
			# 收香火：一声小铜铃，尾巴带一点烟气
			dur = 0.55
			layers = [[1046.0, 0.34, 300.0], [1568.0, 0.17, 210.0],
				[2350.0, 0.08, 150.0]]
			noise_amp = 0.10
			noise_lp = 5200.0
			noise_hp = 2400.0
			noise_decay = 220.0
			attack = 0.010
		"kill":
			# 恶客散了：一记闷响，随后气声往下沉
			dur = 0.48
			layers = [[72.0, 0.55, 90.0], [118.0, 0.25, 60.0]]
			noise_amp = 0.5
			noise_lp = 900.0
			noise_hp = 120.0
			noise_decay = 260.0
		"alert":
			# 一大波要来：远处的闷鼓 + 一记低锣
			dur = 0.9
			layers = [[58.0, 0.7, 220.0], [174.0, 0.3, 420.0], [261.0, 0.14, 320.0]]
			noise_amp = 0.28
			noise_lp = 700.0
			noise_hp = 60.0
			noise_decay = 160.0
			attack = 0.012
		"capstone":
			dur = 0.76
			layers = [[147.0, 0.24, 110.0], [294.0, 0.37, 220.0], [441.0, 0.29, 270.0], [662.0, 0.16, 310.0], [895.0, 0.07, 180.0]]
			attack = 0.025
		"shovel":
			dur = 0.28
			layers = [[135.0, 0.38, 70.0], [281.0, 0.12, 35.0]]
			noise_amp = 0.32
			noise_lp = 760.0
			noise_decay = 70.0
		"splash":
			dur = 0.32
			layers = [[118.0, 0.12, 64.0], [261.0, 0.06, 90.0]]
			noise_amp = 0.32
			noise_lp = 1190.0
			noise_hp = 280.0
			noise_decay = 95.0
			attack = 0.012
		_:
			dur = 0.2
			layers = [[220.0, 0.4, 60.0]]
	var count = int(rate * dur)
	var rng = RandomNumberGenerator.new()
	rng.seed = 4000 + key.hash()
	var lp_state = 0.0
	var hp_state = 0.0
	var lp_a = clampf(1.0 - exp(-TAU * noise_lp / float(rate)), 0.001, 1.0)
	var hp_a = clampf(1.0 - exp(-TAU * noise_hp / float(rate)), 0.001, 1.0)
	var data = PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t = float(i) / float(rate)
		var v = 0.0
		for layer in layers:
			# 一点点失谐，听起来才像实物
			var detune = 1.0 + 0.0025 * sin(t * 9.0)
			v += sin(TAU * float(layer[0]) * detune * t) * float(layer[1]) \
				* exp(-t / (float(layer[2]) / 1000.0))
		if noise_amp > 0.0:
			var white = rng.randf_range(-1.0, 1.0)
			lp_state += (white - lp_state) * lp_a
			hp_state += (lp_state - hp_state) * hp_a
			v += (lp_state - hp_state) * noise_amp \
				* exp(-t / (noise_decay / 1000.0)) * 2.2
		v *= minf(1.0, t / maxf(0.001, attack))
		v *= minf(1.0, (dur - t) / 0.012)
		data.encode_s16(i * 2, int(clampf(v * 0.6, -1.0, 1.0) * 30000.0))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream


func _synth_hit(key: String) -> AudioStreamWAV:
	var rate = 22050
	var breaking = key.begins_with("break_")
	var kind = key.substr(key.find("_") + 1)
	var rng = RandomNumberGenerator.new()
	rng.seed = 9001 + kind.hash()
	var dur = 0.16
	match kind:
		"straw", "paper":
			dur = 0.12
		"urn":
			dur = 0.22
		"iron":
			dur = 0.26
		"stone":
			dur = 0.2
		_:
			dur = 0.17
	if breaking:
		dur = 0.42
	var count = int(rate * dur)
	var samples = PackedFloat32Array()
	samples.resize(count)
	# 层定义：{freq, amp, decay, hp, lp}
	var layers: Array = []
	var noise_amp = 0.0
	var noise_lp = 900.0
	var noise_hp = 60.0
	var noise_decay = 40.0
	match kind:
		"body":
			layers = [[92.0, 0.9, 26.0], [148.0, 0.35, 18.0]]
			noise_amp = 0.35
			noise_lp = 520.0
			noise_hp = 50.0
			noise_decay = 34.0
		"straw", "paper":
			layers = []
			noise_amp = 0.5
			noise_lp = 2400.0
			noise_hp = 700.0
			noise_decay = 22.0
		"stone":
			layers = [[610.0, 0.5, 42.0], [121.0, 0.7, 58.0], [1540.0, 0.16, 22.0]]
			noise_amp = 0.55
			noise_lp = 5200.0
			noise_hp = 900.0
			noise_decay = 12.0
		"urn":
			layers = [[372.0, 0.55, 78.0], [742.0, 0.22, 52.0], [118.0, 0.5, 70.0]]
			noise_amp = 0.4
			noise_lp = 3400.0
			noise_hp = 500.0
			noise_decay = 16.0
		"iron":
			layers = [[1184.0, 0.32, 110.0], [1786.0, 0.2, 82.0], [2610.0, 0.10, 58.0],
				[96.0, 0.45, 60.0]]
			noise_amp = 0.45
			noise_lp = 7000.0
			noise_hp = 1500.0
			noise_decay = 9.0
	if breaking:
		noise_amp = maxf(noise_amp, 0.6)
		noise_lp = 3200.0
		noise_hp = 200.0
		noise_decay = 120.0
		layers = [[78.0, 0.6, 140.0], [132.0, 0.4, 110.0]]
		if kind == "iron":
			layers.append([1184.0, 0.3, 90.0])
		elif kind == "urn":
			layers.append([372.0, 0.35, 100.0])
	# 简单一阶滤波器的状态
	var lp_state = 0.0
	var hp_state = 0.0
	var last_noise = 0.0
	var lp_a = clampf(1.0 - exp(-TAU * noise_lp / float(rate)), 0.001, 1.0)
	var hp_a = clampf(1.0 - exp(-TAU * noise_hp / float(rate)), 0.001, 1.0)
	for i in count:
		var t = float(i) / float(rate)
		var v = 0.0
		for layer in layers:
			var env = exp(-t / (float(layer[2]) / 1000.0))
			v += sin(TAU * float(layer[0]) * t) * float(layer[1]) * env
		if noise_amp > 0.0:
			var white = rng.randf_range(-1.0, 1.0)
			lp_state += (white - lp_state) * lp_a        # 低通，削掉嘶声
			hp_state += (lp_state - hp_state) * hp_a      # 再抬掉最低的嗡
			var band = lp_state - hp_state
			v += band * noise_amp * exp(-t / (noise_decay / 1000.0)) * 2.4
		# 起音 2ms 淡入，避免咔哒
		v *= minf(1.0, t / 0.002)
		# 收尾 8ms 淡出
		v *= minf(1.0, (dur - t) / 0.008)
		samples[i] = clampf(v * 0.62, -1.0, 1.0)
	var data = PackedByteArray()
	data.resize(count * 2)
	for i in count:
		data.encode_s16(i * 2, int(samples[i] * 30000.0))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	return stream


func _sfx_for(name: String, detail: Dictionary = {}) -> AudioStream:
	var key = name
	if name == "hit":
		key = "hit_" + _hit_material(String(detail.get("armor", "")), detail)
	elif name == "armor_break":
		key = "break_" + _hit_material(String(detail.get("armor", "")), detail)
	if _sfx_cache.has(key):
		return _sfx_cache[key]
	var mastered="res://assets/sfx/v040/%s.wav" % key
	if ResourceLoader.exists(mastered):
		var sound: AudioStream=load(mastered)
		_sfx_cache[key]=sound
		return sound
	if key in ["click", "collect", "kill", "alert", "capstone", "shovel", "splash"]:
		var mood_stream = _synth_mood(key)
		_sfx_cache[key] = mood_stream
		return mood_stream
	if key.begins_with("hit_") or key.begins_with("break_"):
		var made = _synth_hit(key)
		_sfx_cache[key] = made
		return made
	var recipe = _sfx_recipe(name)
	var stream = _synth(recipe["freq"], recipe["duration"], recipe["wave"],
		recipe["decay"], recipe.get("sweep", 0.0), recipe.get("noise", 0.0),
		recipe.get("attack", 0.004), recipe.get("soft", 0.0))
	_sfx_cache[name] = stream
	return stream


func _sfx_recipe(name: String) -> Dictionary:
	match name:
		"place":
			return {"freq": 320.0, "duration": 0.22, "wave": "sine", "decay": 3.0}
		"place_bad", "deny":
			return {"freq": 180.0, "duration": 0.16, "wave": "square", "decay": 4.0}
		"collect":
			return {"freq": 720.0, "duration": 0.16, "wave": "sine", "decay": 2.4}
		"produce":
			# 旧版 520Hz 短促上滑，听起来"脆"；改成低频、慢起音、长衰减的暖调
			return {"freq": 296.0, "duration": 0.42, "wave": "sine", "decay": 1.5,
				"sweep": 54.0, "attack": 0.055, "soft": 0.34}
		"shoot", "gravel_shot":
			return {"freq": 880.0, "duration": 0.09, "wave": "triangle", "decay": 5.0,
				"sweep": -260.0}
		"needle_shot":
			return {"freq": 1240.0, "duration": 0.07, "wave": "triangle", "decay": 6.0}
		"cat_shot", "star_shot":
			return {"freq": 660.0, "duration": 0.12, "wave": "sine", "decay": 3.4,
				"sweep": 220.0}
		"lob_shot":
			return {"freq": 420.0, "duration": 0.12, "wave": "sine", "decay": 3.0,
				"sweep": 180.0}
		"hit":
			return {"freq": 190.0, "duration": 0.1, "wave": "noise", "decay": 5.0,
				"noise": 0.7}
		"eat":
			return {"freq": 130.0, "duration": 0.14, "wave": "noise", "decay": 4.0,
				"noise": 0.6}
		"bell":
			return {"freq": 1320.0, "duration": 0.42, "wave": "sine", "decay": 2.0}
		"censer":
			return {"freq": 240.0, "duration": 0.35, "wave": "sine", "decay": 1.6,
				"noise": 0.2}
		"umbrella":
			return {"freq": 300.0, "duration": 0.2, "wave": "sine", "decay": 3.0,
				"sweep": -120.0}
		"lion":
			return {"freq": 150.0, "duration": 0.24, "wave": "square", "decay": 2.6,
				"noise": 0.25}
		"judge":
			return {"freq": 220.0, "duration": 0.3, "wave": "triangle", "decay": 2.2}
		"upgrade":
			return {"freq": 560.0, "duration": 0.3, "wave": "sine", "decay": 1.8,
				"sweep": 280.0}
		"shell":
			return {"freq": 420.0, "duration": 0.2, "wave": "noise", "decay": 3.4,
				"noise": 0.45}
		"explode", "mine":
			return {"freq": 90.0, "duration": 0.4, "wave": "noise", "decay": 2.6,
				"noise": 0.9}
		"zombie_die":
			return {"freq": 160.0, "duration": 0.24, "wave": "triangle", "decay": 3.0,
				"sweep": -90.0}
		"plant_down":
			return {"freq": 210.0, "duration": 0.26, "wave": "sine", "decay": 2.6,
				"sweep": -140.0}
		"wave":
			return {"freq": 300.0, "duration": 0.5, "wave": "sine", "decay": 1.4,
				"sweep": 120.0}
		"alert":
			return {"freq": 200.0, "duration": 0.7, "wave": "triangle", "decay": 1.2,
				"sweep": 90.0}
		"mower":
			return {"freq": 120.0, "duration": 0.5, "wave": "square", "decay": 1.6}
		"wail":
			return {"freq": 560.0, "duration": 0.6, "wave": "sine", "decay": 1.5,
				"sweep": -180.0}
		"grant":
			return {"freq": 480.0, "duration": 0.3, "wave": "sine", "decay": 2.0}
		"win":
			return {"freq": 523.0, "duration": 0.9, "wave": "sine", "decay": 1.2,
				"sweep": 180.0}
		"lose":
			return {"freq": 220.0, "duration": 1.0, "wave": "sine", "decay": 1.0,
				"sweep": -120.0}
		"click":
			return {"freq": 640.0, "duration": 0.06, "wave": "sine", "decay": 6.0}
	return {"freq": 440.0, "duration": 0.1, "wave": "sine", "decay": 4.0}


func _synth(freq: float, duration: float, wave: String, decay: float,
		sweep: float = 0.0, noise: float = 0.0, attack: float = 0.004,
		soft: float = 0.0) -> AudioStreamWAV:
	var rate = 22050
	var count = int(rate * duration)
	var bytes = PackedByteArray()
	bytes.resize(count * 2)
	var rng = RandomNumberGenerator.new()
	rng.seed = int(freq * 31.0 + duration * 977.0)
	var phase = 0.0
	for i in count:
		var t = float(i) / float(rate)
		var k = float(i) / float(count)
		var f = freq + sweep * k
		phase += TAU * f / float(rate)
		var sample = 0.0
		match wave:
			"square":
				sample = 1.0 if sin(phase) >= 0.0 else -1.0
			"triangle":
				sample = 2.0 * absf(2.0 * (phase / TAU - floor(phase / TAU + 0.5))) - 1.0
			"noise":
				sample = rng.randf_range(-1.0, 1.0)
			_:
				sample = sin(phase)
		if soft > 0.0:
			# 叠一层低幅二倍泛音，把纯正弦的"尖"磨掉
			sample = sample * (1.0 - soft) + sin(phase * 2.0) * soft * 0.5
		if noise > 0.0:
			sample = sample * (1.0 - noise) + rng.randf_range(-1.0, 1.0) * noise
		var envelope = pow(1.0 - k, decay)
		# 起音淡入：默认 4ms 防爆音，柔和音色可以放长
		var attack_k = minf(1.0, t / maxf(0.001, attack))
		bytes.encode_s16(i * 2, int(clampf(sample * envelope * attack_k * 0.5,
			-1.0, 1.0) * 32000.0))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = bytes
	return stream


# ── 命令行（自动截图与自检用）────────────────────────────────────────────────
func _handle_cli() -> void:
	var args = OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--capture="):
			_pending_capture = arg.trim_prefix("--capture=")
		if arg.begins_with("--sim-seconds="):
			_qa_sim_seconds = float(arg.trim_prefix("--sim-seconds="))
		if arg.begins_with("--prep="):
			_qa_prep_level = clampi(int(arg.trim_prefix("--prep=")), 1,
				Content.LEVELS.size())
	for arg in args:
		if arg.begins_with("--screen="):
			var target = arg.trim_prefix("--screen=")
			match target:
				"menu":
					show_menu()
				"levels":
					show_levels()
					if _qa and _qa_prep_level>1:screen_node.switch_to_level(_qa_prep_level)
				"prep":
					show_prep(_qa_prep_level)
					if screen_node != null and screen_node.has_method("skip_cinema"):
						screen_node.skip_cinema()
				"almanac":
					open_almanac("plant", 0)
				"almanac-zombie":
					open_almanac("zombie", 6)
				"almanac-boss":
					open_almanac("boss", Almanac.BOSS_ORDER.size() - 1)
				"settings":
					open_settings()
				"training":
					show_training_menu()
				"selftest":
					_run_selftest()
				"result":
					# 真跑一夜再判胜，用来截图看结算页的复盘与星级
					start_battle(1, loadout)
					_qa_battle_seed()
					for i in int(300.0 * 60.0):
						sim.tick(1.0 / 60.0)
					finish_run(true)
				"battle":
					start_battle(1, loadout)
					_qa_battle_seed()
				"fan":
					# 升阶扇形验收台：三片叶子全开 + 一张悬停纸条，
					# 配 --qa-size=1280x720 看低分辨率下小字够不够读
					start_battle(1, loadout)
					_qa_battle_seed()
					var shooter = sim.place_free("shooter", 2, 2)
					shooter.upgrades = {1: 1, 2: 0, 3: 0}
					sim.refresh_plant_buffs()
					for i in 2:
						await get_tree().process_frame
					hud.try_open_menu(shooter, Geo.to_screen(shooter.pos))
					if hud._fan != null:
						hud._fan._hover = 1
				"battle2":
					start_battle(6, loadout)
					_qa_battle_seed()
				"battle3":
					start_battle(11, loadout)
					_qa_battle_seed()
				"island", "cavern":
					start_battle(Content.level_id_for(4 if target == "island" else 5), ["lantern", "shooter", "lily", "wall"])
					for row in sim.rows:
						var column := 2
						if sim.tile_at(column, row).kind == "water":
							sim.place_free("lily", column, row)
						sim.place_free("lantern", column, row)
				"evolve":
					_qa_show_evolve()
				"boss1", "boss2", "boss3":
					_qa_show_boss(int(target.right(1))*5)
				"boss4", "boss5", "boss-bound":
					_qa_show_boss(Content.level_id_for(4 if target == "boss4" else 5, 4), 0, target == "boss-bound")
				"gauntlet":
					_qa_show_boss(16,clampi(_qa_prep_level-1,0,Content.SPECIAL_THREATS.size()-1))
				"armor":
					start_battle(6, loadout)
					for row in 6:
						var id = ["stonehat", "paper", "sedan", "straw", "bucket", "ironjudge"][row]
						var enemy = sim.spawn_zombie(id, row, {"x": 1150.0})
						enemy.armor *= [1.0, 0.5, 0.2, 1.0, 0.5, 0.2][row]
				"armor-break":
					start_battle(6, loadout)
					for row in 6:
						var id = ["stonehat", "paper", "sedan", "straw", "bucket", "ironjudge"][row]
						sim.spawn_zombie(id, row, {"x": 1150.0})
					for frame in 4:
						await get_tree().process_frame
					for enemy in sim.zombies:
						enemy.armor = 0.0
				"result":
					start_battle(1, loadout)
					_qa_battle_seed()
					finish_run(true)
				"defeat":
					start_battle(3, loadout)
					_qa_battle_seed()
					finish_run(false)
				"pause":
					start_battle(1, loadout)
					_qa_battle_seed()
					show_pause()
				"tutorial":
					loadout = ["shooter"]
					start_battle(0, ["shooter"], "tutorial")
				"gridoff":
					settings["show_grid"] = false
					start_battle(1, loadout)
					_qa_battle_seed()
	if not _pending_capture.is_empty():
		if _qa_sim_seconds > 0.0 and sim != null:
			var steps = int(_qa_sim_seconds * 60.0)
			for i in steps:
				sim.tick(1.0 / 60.0)
			sim.sounds.clear()
			sim.sound_detail.clear()
			if hud != null and hud.has_method("refresh"):
				hud.refresh()
		for i in 12:
			await get_tree().process_frame
		await get_tree().create_timer(0.35).timeout
		await _capture(_pending_capture)


func _run_selftest() -> void:
	var Selftest = load("res://tools/ui_selftest.gd")
	var runner = Selftest.new()
	runner.game = self
	await runner.run()
	get_tree().quit(0 if runner.failures == 0 else 1)


func _qa_battle_seed() -> void:
	if sim == null:
		return
	sim.sun = 4000
	var setups = [
		["lantern", 0, 0], ["lantern", 0, 1], ["lantern", 0, 2],
		["shooter", 2, 0], ["shooter", 2, 1], ["shooter", 2, 3],
		["wall", 4, 1], ["censer", 3, 2], ["torch", 1, 1], ["bell", 1, 3],
		["star", 5, 2], ["cat", 6, 1], ["lion", 5, 3], ["lobber", 1, 2],
	]
	for item in setups:
		if sim.can_place_at(String(item[0]), int(item[1]), int(item[2]))["ok"]:
			sim.place_free(String(item[0]), int(item[1]), int(item[2]))
	# 本轮新机制摆满合法的最高状态，截图与自动对局才真的走得到它们
	var maxed = {
		"star": {1: 0, 2: 2, 3: 3}, "cat": {1: 3, 2: 2, 3: 0},
		"lion": {1: 3, 2: 0, 3: 3}, "lobber": {1: 3, 2: 0, 3: 2},
	}
	for plant in sim.plants:
		if maxed.has(plant.type):
			plant.upgrades = maxed[plant.type].duplicate()
			sim.apply_hp_scale(plant)
	var mid = sim.main_plant_at(2, 1)
	if mid != null:
		sim.sun = 4000
		sim.try_upgrade(mid, 1, Vector2.ZERO)
		sim.try_upgrade(mid, 1, Vector2.ZERO)
	sim.spawn_zombie("straw", 0, {"x": 1180.0})
	sim.spawn_zombie("ghost", 1, {"x": 1080.0})
	sim.spawn_zombie("mourner", 3, {"x": 1220.0})
	sim.spawn_zombie("bucket", 3, {"x": 1060.0})
	sim.spawn_zombie("ironjudge", 2, {"x": 1240.0})
	sim.sun = 275
	sim.time = 96.0
	sim.wave_index = 4
	sim.kills = 12
	if sim.cards.size() > 0:
		sim.cards[0]["cd"] = 0.0
	if hud != null:
		hud.card_selected = 0
		hud.refresh()


## 三阶换建模的验收台：凡是做了毕业立绘的草木，各摆一排（原画 + 三条毕业路），
## 配 --capture 出图，逐张核对新模与老画是不是同一批、脚有没有沾地。
func _qa_show_evolve() -> void:
	start_battle(1, loadout)
	if sim == null:
		return
	sim.sun = 4000
	var row = 0
	var ids: Array=[]
	for id in Content.PLANT_ORDER:
		if ResourceLoader.exists("res://assets/sprites/%s-e1.png" % id):ids.append(id)
	for type in ids.slice((_qa_prep_level-1)*5,_qa_prep_level*5):
		var paths: Array = []
		for path_id in [1, 2, 3]:
			if ResourceLoader.exists("res://assets/sprites/%s-e%d.png" % [type, path_id]):
				paths.append(path_id)
		if paths.is_empty() or row >= sim.rows:
			continue
		sim.place_free(String(type), 1, row)
		var col = 3
		for path_id in paths:
			var plant = sim.place_free(String(type), col, row)
			if plant != null:
				plant.upgrades[int(path_id)] = 3
				sim.apply_hp_scale(plant)
			col += 2
		sim.refresh_plant_buffs()
		row += 1
	paused=true
	if hud != null:
		hud.refresh()


func _qa_show_boss(id: int,checkpoint: int=0, bound := false) -> void:
	start_battle(id,loadout)
	sim.time=500;sim.sun=500
	for col in 7:
		for row in sim.rows:
			if String(sim.tile_at(col,row).kind) in ["blocked","object"]:continue
			if String(sim.tile_at(col,row).kind)=="water":sim.place_free("lily",col,row)
			var p=sim.place_free(["lantern","lantern","shooter","shooter","wall","censer","umbrella"][col],col,row)
			if p!=null and col==2:p.upgrades={1:2,2:0,3:0}
	sim.refresh_plant_buffs()
	if id==16:
		sim.special_bosses_completed=checkpoint
		sim.count_mul=sqrt(Content.checkpoint_threat(sim.level, checkpoint) / Content.terrain_factor(sim.level));sim.hp_mul=sim.count_mul
		sim.boss=preload("res://scripts/boss_encounter.gd").new()
		sim.boss.begin(sim,String(sim.level.boss_checkpoints[checkpoint]))
	else:
		sim.wave_index=9 if bound else sim.level.waves.size()-3
		sim.queue_wave(sim.level.waves[sim.wave_index],sim.wave_index)
	sim.time+=3.1
	sim.boss.state="idle"
	if bound:
		sim.boss._start_small()
	else:
		sim.boss._start_major()
	for i in 45:sim.tick(1.0/60.0)
	sim.sounds.clear();sim.sound_detail.clear()
	boss_view._pose=sim.boss.pose();boss_view._previous=boss_view._pose;boss_view._pose_at=sim.time-1.0
	paused=true;hud.refresh()


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image = get_viewport().get_texture().get_image()
	var target = ProjectSettings.globalize_path(path)
	var error = image.save_png(target)
	print("CAPTURE %s code=%d size=%s" % [path, error, str(image.get_size())])
	var args = OS.get_cmdline_user_args()
	if "--quit-after-capture" in args:
		get_tree().call_deferred("quit",0)


func _notification(what: int) -> void:
	if not mobile or ui_root==null:return
	if what==NOTIFICATION_APPLICATION_PAUSED:
		if sim!=null:
			save_run()
			if screen=="battle" and not paused:show_pause()
		AudioServer.set_bus_mute(0,true)
	elif what==NOTIFICATION_APPLICATION_RESUMED:
		AudioServer.set_bus_mute(0,not bool(settings.get("sound",true)))
		_apply_mobile_safe_area()
	elif what==NOTIFICATION_WM_GO_BACK_REQUEST:
		if screen=="battle" and paused:close_pause()
		else:_on_escape()

func _apply_mobile_safe_area() -> void:
	if not OS.has_feature("android"):return
	var physical:=Vector2(DisplayServer.window_get_size())
	var safe:=Rect2(DisplayServer.get_display_safe_area())
	var scale:=minf(physical.x/Geo.VIEW.x,physical.y/Geo.VIEW.y)
	if scale<=0:return
	var origin:Vector2=(physical-Geo.VIEW*scale)*0.5
	var start:Vector2=((safe.position-origin)/scale).max(Vector2.ZERO)
	var end:Vector2=((safe.end-origin)/scale).min(Geo.VIEW)
	var fit:=minf((end.x-start.x)/1600.0,(end.y-start.y)/900.0)
	ui_root.scale=Vector2.ONE*fit
	ui_root.position=start+(end-start-Geo.VIEW*fit)*0.5
	ui_root.size=Geo.VIEW
	if _battle_stage!=null and is_instance_valid(_battle_stage):_battle_stage.transform=ui_root.get_transform()*MOBILE_WORLD


func _battle_parent() -> Node:
	return _battle_stage if _battle_stage!=null else self


func _mobile_world_transform() -> Transform2D:
	return _battle_stage.transform if _battle_stage!=null and is_instance_valid(_battle_stage) else MOBILE_WORLD
