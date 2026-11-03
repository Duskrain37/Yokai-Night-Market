## 封面：按 v0.2.4 的样子重排——左侧一枚朱印压着标题，下面是题记与一列签条，
## 主操作做成朱漆匾，战绩卡片挪到右侧像挂在墙上的纸牌。
extends Control

var game = null
var _petals: Array = []
var _petal_layer: Control = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop()
	_title_block()
	_menu_buttons()
	_records_card()
	_decor()
	_petals_setup()
	Ui.grain(self, Rect2(), 0.5)
	game.play_music_scene("menu")


func _process(delta: float) -> void:
	for petal in _petals:
		petal["t"] += delta
	if _petal_layer != null:
		_petal_layer.queue_redraw()


func _backdrop() -> void:
	var texture = load("res://assets/bg/menu.jpg") if ResourceLoader.exists(
		"res://assets/bg/menu.jpg") else null
	if texture != null:
		var rect = TextureRect.new()
		rect.texture = texture
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rect)
	else:
		var fill = ColorRect.new()
		fill.color = Ui.INK
		fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(fill)
	var scrim = ColorRect.new()
	scrim.color = Color(0.02, 0.05, 0.07, 0.40)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	# 左侧压暗，标题与签条读得清
	var gradient = Gradient.new()
	gradient.set_color(0, Color(0.02, 0.04, 0.06, 0.86))
	gradient.set_color(1, Color(0.02, 0.04, 0.06, 0.0))
	var gradient_texture = GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 512
	gradient_texture.height = 8
	gradient_texture.fill_from = Vector2(0, 0)
	gradient_texture.fill_to = Vector2(1, 0)
	var shade = TextureRect.new()
	shade.texture = gradient_texture
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)


func _title_block() -> void:
	var box = VBoxContainer.new()
	box.position = Vector2(92, 104)
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var top = HBoxContainer.new()
	top.add_theme_constant_override("separation", 18)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(top)
	top.add_child(Ui.title("妖怪夜市", 92, Ui.GOLD_BRIGHT))
	var seal = Ui.seal("夜", 80.0)
	seal.pivot_offset = Vector2(40, 40)
	seal.rotation = -0.06
	top.add_child(seal)
	box.add_child(Ui.label("YOKAI NIGHT MARKET · 子时开张", 15, Color(Ui.TEXT_DIM, 0.85)))
	var rule = ColorRect.new()
	rule.color = Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.55)
	rule.custom_minimum_size = Vector2(360, 1)
	box.add_child(rule)
	box.add_child(Ui.label("香火为钱，草木为兵。守到天亮，摊子才算收。", 19, Ui.TEXT))


func _menu_buttons() -> void:
	var box = VBoxContainer.new()
	box.position = Vector2(92, 336)
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	var save_data: Dictionary = game.save_data
	var has_save = not save_data.is_empty()
	# 一夜未守、也没学过教程：主按钮先带人去第一课，而不是把他丢进选关页
	var fresh = not has_save and Array(game.progress.get("cleared", [])).is_empty() \
		and not bool(game.progress.get("taught", false))

	# 主操作：朱漆匾
	var primary_text = "继续守夜" if has_save else ("先学一夜守夜" if fresh else "开始守夜")
	var primary = Ui.button(primary_text, 26, 348, 68, true)
	primary.pressed.connect(func():
		game.play_sfx("click")
		if has_save:
			game.continue_run()
		elif fresh:
			game.start_battle(0, ["shooter"], "tutorial")
		else:
			game.show_levels())
	box.add_child(primary)
	if has_save:
		box.add_child(Ui.label(_save_line(save_data), 15, Color(Ui.TEXT_DIM, 0.9)))
	elif fresh:
		box.add_child(Ui.label("第一课约两分钟：收香火、种签筒、升一阶、请石磨挡一次。",
			15, Color(Ui.TEXT_DIM, 0.9)))

	# 次操作：一列宣纸签条
	var entries = [
		["挑选一夜", func(): game.show_levels()],
		["草木志 · 恶客录", func(): game.open_almanac("plant", 0)],
		["训练与教程", func(): game.show_training_menu()],
		["设置", func(): game.open_settings()],
	]
	for entry in entries:
		var button = Ui.button(String(entry[0]), 20, 348, 50)
		button.pressed.connect(func():
			game.play_sfx("click")
			entry[1].call())
		box.add_child(button)
	var quit = Ui.button("收摊退出", 17, 160, 40)
	quit.pressed.connect(func(): get_tree().quit())
	box.add_child(quit)


func _save_line(save_data: Dictionary) -> String:
	var level_id = int(save_data.get("level_id", 1))
	var level = Content.get_level(level_id)
	var sim_data: Dictionary = save_data.get("sim", {})
	var wave = int(sim_data.get("wave_index", 0))
	return "上次停在 %s·%s %s %s" % [level["day_name"], level["day_sub"],
		level["name"], Content.wave_text(level, maxi(0,wave-1))]


## 右侧的「守夜记录」纸牌：一张斜挂的宣纸，用金线压边
func _records_card() -> void:
	var card = PanelContainer.new()
	card.position = Vector2(1132, 486)
	card.custom_minimum_size = Vector2(404, 248)
	card.add_theme_stylebox_override("panel",
		Ui.flat(Color(Ui.PAPER.r, Ui.PAPER.g, Ui.PAPER.b, 0.94),
			Color(Ui.VERMILION.r, Ui.VERMILION.g, Ui.VERMILION.b, 0.55), 4, 2))
	card.rotation = -0.012
	add_child(card)
	var box = Ui.vbox(6)
	card.add_child(box)
	var head = Ui.hbox(8)
	box.add_child(head)
	var record_title = Ui.label("守夜记录", 30, Color("#3a2418"))
	record_title.add_theme_font_override("font", Ui.display_font())
	head.add_child(record_title)
	var stamp = Ui.seal("录", 34.0)
	stamp.pivot_offset = Vector2(17, 17)
	stamp.rotation = 0.08
	head.add_child(stamp)
	var cleared: Array = game.progress.get("cleared", [])
	var stars_got = 0
	for level in Content.LEVELS:
		stars_got += int(Dictionary(game.progress.get("stars", {}))
			.get(str(int(level["id"])), 0))
	var lines = [
		"通关 %d / %d 夜" % [cleared.size(), Content.LEVELS.size()],
		"守夜评级 %d / %d ★" % [stars_got, Content.LEVELS.size() * 3],
	]
	var books: Dictionary = Dictionary(game.records.get("by_diff", {}))
	for key in ["easy", "normal", "hard"]:
		var book: Dictionary = Dictionary(books.get(key, {}))
		if book.is_empty():
			continue
		lines.append("%s：天亮 %d · 退 %d · 第 %d 大波" % [
			String(game.DIFFICULTY_LABEL[key]), int(book.get("wins", 0)),
			int(book.get("best_kills", 0)),
			int(ceil(float(book.get("best_wave", 0)) / Content.WAVES_PER_GROUP))])
	var legacy: Dictionary = Dictionary(game.records.get("legacy", {}))
	if books.is_empty() and not legacy.is_empty():
		# v0.3.1 及更早不分难度，旧数字整册摆在这一行，等正经分档的账记上就退场
		lines.append("旧版累计：天亮 %d · 退 %d · 第 %d 大波" % [
			int(legacy.get("wins", 0)), int(legacy.get("best_kills", 0)),
			int(ceil(float(legacy.get("best_wave", 0)) / Content.WAVES_PER_GROUP))])
	var cheat: Dictionary = Dictionary(game.records.get("cheated", {}))
	if int(cheat.get("runs", 0)) > 0:
		lines.append("开过局内调整 %d 夜：另册，不并入上面" % int(cheat.get("runs", 0)))
	if lines.size() == 2:
		lines.append("还没守过夜：从第壹夜开始")
	for line in lines:
		box.add_child(Ui.label(String(line), 17, Color("#4a3520")))


func _decor() -> void:
	var holder = Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	holder.offset_left = -700.0
	holder.offset_right = -60.0
	holder.offset_top = -400.0
	holder.offset_bottom = -20.0
	add_child(holder)
	var ids = ["lantern", "shooter", "wall", "cat"]
	var positions = [Vector2(80, 380), Vector2(250, 400), Vector2(430, 385),
		Vector2(590, 404)]
	var heights = [160.0, 172.0, 164.0, 158.0]
	for i in ids.size():
		var texture = Ui.sprite(String(ids[i]))
		if texture == null:
			continue
		var rect = TextureRect.new()
		rect.texture = texture
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.size = Vector2(heights[i] * 0.7, heights[i])
		rect.position = positions[i] - Vector2(rect.size.x * 0.5, rect.size.y)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.modulate = Color(1, 1, 1, 0.22)
		holder.add_child(rect)
	var hint = Ui.label("F11 全屏 · Esc 返回", 15, Color(1, 1, 1, 0.35))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -220.0
	hint.offset_top = -34.0
	hint.offset_right = -24.0
	add_child(hint)


## 飘落的花瓣：v0.2.4 封面的那点活气
func _petals_setup() -> void:
	_petal_layer = Control.new()
	_petal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_petal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_petal_layer.draw.connect(_draw_petals)
	add_child(_petal_layer)
	var rng = RandomNumberGenerator.new()
	rng.seed = 20261101
	for i in 22:
		_petals.append({
			"x": rng.randf() * 1600.0, "y": rng.randf() * 900.0,
			"t": rng.randf() * 10.0, "speed": 26.0 + rng.randf() * 34.0,
			"size": 3.0 + rng.randf() * 2.6, "spin": rng.randf() * TAU,
		})


func _draw_petals() -> void:
	for petal in _petals:
		var t = float(petal["t"])
		var x = fmod(float(petal["x"]) + t * 18.0 + sin(t * 0.7) * 26.0, 1640.0) - 20.0
		var y = fmod(float(petal["y"]) + t * float(petal["speed"]), 960.0) - 20.0
		var s = float(petal["size"])
		_petal_layer.draw_set_transform(Vector2(x, y),
			float(petal["spin"]) + t * 0.9, Vector2(1.0, 0.55))
		_petal_layer.draw_circle(Vector2.ZERO, s,
			Color(1.0, 0.72, 0.78, 0.34))
		_petal_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
