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

const VERSION = "0.3.0"
const SAVE_PATH = "user://run.json"
const SETTINGS_PATH = "user://settings.json"
const PROGRESS_PATH = "user://progress.json"
const RECORDS_PATH = "user://records.json"

const DEFAULT_SETTINGS = {
	"speed": 1.0,
	"auto_collect": true,
	"collect_delay": 0.0,
	"quick_wave": true,
	"health_bars": "bar",
	"difficulty": "easy",
	"cheats": false,
	"sound": true,
	"music_volume": 70,
	"sfx_volume": 80,
	"show_grid": true,
}

const DIFFICULTY_LABEL = {"easy": "简单", "normal": "普通", "hard": "困难"}

## 首次进游戏时的默认十张卡：能产香火、有本行输出、有肉盾、有控制。
const DEFAULT_LOADOUT = [
	"lantern", "shooter", "wall", "bell", "censer",
	"umbrella", "lion", "torch", "needle", "cat",
]

var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
var records: Dictionary = {"wins": 0, "best_kills": 0, "best_wave": 0, "best_time": null}
var progress: Dictionary = {"cleared": [], "selected": 1, "loadout": []}
var save_data: Dictionary = {}

var screen = "menu"
var screen_node: Control = null
var overlay_from = ""

var sim: Sim = null
var board: BoardView = null
var units: UnitView = null
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
var result = {}
var tutorial_active = false

var _music_players: Dictionary = {}
var _music_current = "menu"
var _sfx_players: Array = []
var _sfx_cache: Dictionary = {}
var _sfx_cursor = 0
var _qa = false
var _pending_capture = ""
var _qa_sim_seconds = 0.0

const MUSIC_SCENES = ["menu", "battle", "hot", "final"]


func _ready() -> void:
	get_tree().root.theme = Ui.make_theme()
	_qa = "--qa" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-size="):
			var parts = arg.trim_prefix("--qa-size=").split("x")
			if parts.size() == 2 and DisplayServer.get_name() != "headless":
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				DisplayServer.window_set_size(Vector2i(int(parts[0]), int(parts[1])))
	if DisplayServer.get_name() != "headless":
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
	Ui.warm_sprites(Content.PLANT_ORDER + Content.ZOMBIE_ORDER + ["guardian"])
	_load_state()
	_setup_audio()
	loadout = _clean_loadout(Array(progress.get("loadout", [])))
	if loadout.is_empty():
		loadout = DEFAULT_LOADOUT.duplicate()
	selected_level = clampi(int(progress.get("selected", 1)), 1, Content.LEVELS.size())
	show_menu()
	_handle_cli()


func _process(delta: float) -> void:
	_update_music(delta)
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
	_clear_screen()
	screen = name
	screen_node = node
	if node != null:
		ui_root.add_child(node)
		node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _clear_battle() -> void:
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
	var node = AlmanacScreen.new()
	node.game = self
	node.tab = tab
	node.index = index
	ui_root.add_child(node)
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_node = node
	screen = "almanac"


func open_settings() -> void:
	overlay_from = screen
	_clear_screen()
	var node = SettingsScreen.new()
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
			screen = "battle"
			_clear_screen()
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
func start_battle(level_id: int, cards: Array, mode = "normal") -> void:
	_clear_screen()
	_clear_battle()
	_finished = false
	paused = false
	selected_level = level_id
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
	board = BoardView.new()
	board.sim = sim
	board.show_grid = bool(settings["show_grid"])
	var map = "day1"
	if mode != "tutorial":
		match String(Content.get_level(level_id)["map"]):
			"market":
				map = "day2"
			"water":
				map = "day3"
	board.set_map(map)
	add_child(board)
	units = UnitView.new()
	units.sim = sim
	units.health_bars = String(settings["health_bars"])
	add_child(units)
	hud = HudScreen.new()
	hud.game = self
	ui_root.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen = "battle"
	screen_node = null
	speed = 1.0 if mode == "tutorial" else float(settings["speed"])
	if mode != "tutorial" and mode != "training":
		save_run()
	play_music_scene("battle")


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
	if sim.shake > 0.0 and board != null:
		var amount = sim.shake
		board.position = Vector2(sin(sim.time * 61.0) * amount * 0.5,
			cos(sim.time * 53.0) * amount * 0.4)
	else:
		if board != null:
			board.position = Vector2.ZERO
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
	}
	_update_records(won)
	if not sim.training and sim.tutorial == null:
		clear_run()
		if won:
			var cleared: Array = progress.get("cleared", [])
			if not cleared.has(sim.level_id):
				cleared.append(sim.level_id)
			progress["cleared"] = cleared
			progress["selected"] = mini(sim.level_id + 1, Content.LEVELS.size())
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
	var node = HudScreen.new()
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
	paused = true
	_music_duck = 1.0
	var node = HudScreen.new()
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
	var cell = Geo.cell_at(pos, sim.rows)
	board.hover_cell = cell if screen == "battle" and not paused else Vector2i(-1, -1)
	units.hover_target = null


func _mouse_world() -> Vector2:
	return get_viewport().get_mouse_position()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F11:
				var mode = DisplayServer.window_get_mode()
				DisplayServer.window_set_mode(
					DisplayServer.WINDOW_MODE_WINDOWED if mode ==
					DisplayServer.WINDOW_MODE_FULLSCREEN
					else DisplayServer.WINDOW_MODE_FULLSCREEN)
			KEY_ESCAPE:
				_on_escape()
			KEY_SPACE:
				if screen == "battle" and not tutorial_active:
					toggle_pause()
			KEY_P:
				if screen == "battle" and not tutorial_active:
					toggle_pause()
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if screen == "battle" and hud != null:
				hud.cancel_selection()
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if screen == "battle" and not paused:
			_handle_battle_click(_mouse_world())


func _on_escape() -> void:
	match screen:
		"settings", "almanac", "training":
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
	if sim == null or hud == null:
		return
	if hud.has_method("blocks_simulation") and hud.blocks_simulation():
		return
	var orb = sim.pick_orb(pos)
	if not orb.is_empty():
		sim.collect_orb(orb)
		return
	var cell = Geo.cell_at(pos, sim.rows)
	if hud.card_selected >= 0:
		if cell.x >= 0:
			var ok = sim.try_place_card(hud.card_selected, cell.x, cell.y, pos)
			if ok:
				hud.card_selected = -1
				hud.refresh()
		return
	if hud.shovel_mode:
		if cell.x >= 0:
			var outcome = sim.shovel_at(cell.x, cell.y)
			if not bool(outcome["ok"]):
				sim.deny(String(outcome["text"]), pos)
			hud.shovel_mode = false
		return
	if cell.x < 0:
		hud.focus_plant = null
		return
	if hud.menu_plant != null:
		hud.menu_plant = null
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
	if key == "sound":
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
	elif key == "speed" and screen == "battle" and not tutorial_active:
		speed = float(value)
	save_settings()


func save_settings() -> void:
	_write_json(SETTINGS_PATH, settings)


func save_progress() -> void:
	progress["selected"] = selected_level
	progress["loadout"] = loadout.duplicate()
	_write_json(PROGRESS_PATH, progress)


func save_records() -> void:
	_write_json(RECORDS_PATH, records)


func _update_records(won: bool) -> void:
	if sim == null or sim.training or sim.tutorial != null:
		return
	if won:
		records["wins"] = int(records.get("wins", 0)) + 1
		var best = records.get("best_time")
		if best == null or float(best) > sim.time:
			records["best_time"] = sim.time
	records["best_kills"] = maxi(int(records.get("best_kills", 0)), sim.kills)
	records["best_wave"] = maxi(int(records.get("best_wave", 0)), sim.wave_index)
	save_records()


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
	_write_json(SAVE_PATH, payload)


func clear_run() -> void:
	save_data = {}
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


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
	start_battle(int(save_data.get("level_id", 1)), loadout)
	sim.restore(payload)
	settings["difficulty"] = sim.difficulty
	hud.refresh()


func _load_state() -> void:
	var loaded = _read_json(SETTINGS_PATH)
	for key in DEFAULT_SETTINGS:
		if loaded.has(key):
			var default = DEFAULT_SETTINGS[key]
			var value = loaded[key]
			if default is bool:
				settings[key] = bool(value)
			elif default is int and not (value is float):
				settings[key] = int(value)
			elif default is float:
				settings[key] = float(value)
			else:
				settings[key] = value
	progress = _read_json(PROGRESS_PATH, {"cleared": [], "selected": 1, "loadout": []})
	records = _read_json(RECORDS_PATH, {"wins": 0, "best_kills": 0, "best_wave": 0,
		"best_time": null})
	save_data = _read_json(SAVE_PATH, {})
	if not save_data.is_empty() and not save_data.has("sim"):
		save_data = {}


func _write_json(path: String, data: Dictionary) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("无法写入 %s" % path)
		return
	file.store_string(JSON.stringify(data, "  "))
	file.close()


func _read_json(path: String, fallback: Dictionary = {}) -> Dictionary:
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
func _setup_audio() -> void:
	for name in MUSIC_SCENES:
		var player = AudioStreamPlayer.new()
		var path = "res://assets/music/%s.ogg" % name
		if ResourceLoader.exists(path):
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


func play_music_scene(scene: String) -> void:
	if _music_current == scene:
		return
	_music_current = scene
	if DisplayServer.get_name() == "headless":
		return
	var player: AudioStreamPlayer = _music_players.get(scene)
	if player != null and player.stream != null and not player.playing:
		player.play()


func _update_music(delta: float) -> void:
	if _music_players.is_empty():
		return
	var on = bool(settings.get("sound", true))
	for name in _music_players:
		var player: AudioStreamPlayer = _music_players[name]
		if not player.playing:
			if name == _music_current and on and player.stream != null \
					and not DisplayServer.get_name() == "headless":
				player.play()
			continue
		var goal = -60.0
		if on and name == _music_current:
			goal = -7.0 - (_music_duck * 6.0)
		player.volume_db = lerpf(player.volume_db, goal, clampf(delta * 1.8, 0.0, 1.0))
		if player.volume_db < -55.0 and goal < -55.0:
			player.stop()


func _music_for_wave() -> void:
	if sim == null or sim.training or sim.tutorial != null:
		return
	if screen != "battle":
		return
	var total = int(sim.level.get("waves", []).size())
	var index = sim.wave_index
	var scene = "battle"
	if total > 0 and index >= total - 2:
		scene = "final"
	elif index >= 7:
		scene = "hot"
	play_music_scene(scene)


func _apply_volume() -> void:
	_sfx_volume = float(settings.get("sfx_volume", 80)) / 100.0


var _sfx_volume = 0.8
var _music_duck = 0.0


func play_sfx(name: String, detail: Dictionary = {}) -> void:
	if not bool(settings["sound"]) or _qa or DisplayServer.get_name() == "headless":
		return
	var stream = _sfx_for(name)
	if stream == null:
		return
	var player: AudioStreamPlayer = _sfx_players[_sfx_cursor % _sfx_players.size()]
	_sfx_cursor += 1
	player.stream = stream
	player.volume_db = lerpf(-26.0, -4.0, _sfx_volume)
	player.pitch_scale = 1.0
	match name:
		"hit":
			player.pitch_scale = 0.94 + float(_sfx_cursor % 5) * 0.03
		"shoot", "needle_shot", "gravel_shot":
			player.pitch_scale = 0.95 + float(_sfx_cursor % 4) * 0.04
	player.play()


func _sfx_for(name: String) -> AudioStream:
	if _sfx_cache.has(name):
		return _sfx_cache[name]
	var recipe = _sfx_recipe(name)
	var stream = _synth(recipe["freq"], recipe["duration"], recipe["wave"],
		recipe["decay"], recipe.get("sweep", 0.0), recipe.get("noise", 0.0))
	_sfx_cache[name] = stream
	return stream


func _sfx_recipe(name: String) -> Dictionary:
	match name:
		"place":
			return {"freq": 320.0, "duration": 0.22, "wave": "sine", "decay": 3.0}
		"place_bad", "deny":
			return {"freq": 180.0, "duration": 0.16, "wave": "square", "decay": 4.0}
		"collect":
			return {"freq": 720.0, "duration": 0.16, "wave": "sine", "decay": 2.4,
				"sweep": 340.0}
		"produce":
			return {"freq": 520.0, "duration": 0.24, "wave": "sine", "decay": 2.0,
				"sweep": 160.0}
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
		sweep: float = 0.0, noise: float = 0.0) -> AudioStreamWAV:
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
		if noise > 0.0:
			sample = sample * (1.0 - noise) + rng.randf_range(-1.0, 1.0) * noise
		var envelope = pow(1.0 - k, decay)
		# 起音留 4ms 淡入，避免爆音
		var attack = minf(1.0, t / 0.004)
		bytes.encode_s16(i * 2, int(clampf(sample * envelope * attack * 0.5, -1.0, 1.0) * 32000.0))
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
	for arg in args:
		if arg.begins_with("--screen="):
			var target = arg.trim_prefix("--screen=")
			match target:
				"menu":
					show_menu()
				"levels":
					show_levels()
				"prep":
					show_prep(1)
				"almanac":
					open_almanac("plant", 0)
				"almanac-zombie":
					open_almanac("zombie", 6)
				"settings":
					open_settings()
				"training":
					show_training_menu()
				"selftest":
					_run_selftest()
				"battle":
					start_battle(1, loadout)
					_qa_battle_seed()
				"battle2":
					start_battle(6, loadout)
					_qa_battle_seed()
				"battle3":
					start_battle(11, loadout)
					_qa_battle_seed()
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
	]
	for item in setups:
		if sim.can_place_at(String(item[0]), int(item[1]), int(item[2]))["ok"]:
			sim.place_free(String(item[0]), int(item[1]), int(item[2]))
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


func _capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var image = get_viewport().get_texture().get_image()
	var target = ProjectSettings.globalize_path(path)
	var error = image.save_png(target)
	print("CAPTURE %s code=%d size=%s" % [path, error, str(image.get_size())])
	var args = OS.get_cmdline_user_args()
	if "--quit-after-capture" in args:
		get_tree().quit(0)
