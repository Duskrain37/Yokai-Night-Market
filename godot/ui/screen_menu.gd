## 封面：门楼灯火、标题、入口按钮与战绩。
extends Control

var game = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop()
	_title_block()
	_menu_buttons()
	_records()
	_decor()
	game.play_music_scene("menu")


func _backdrop() -> void:
	var texture = load("res://assets/bg/menu.jpg") if ResourceLoader.exists(
		"res://assets/bg/menu.jpg") else null
	if texture != null:
		var rect = TextureRect.new()
		rect.texture = texture
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rect)
	else:
		var fill = ColorRect.new()
		fill.color = Ui.INK
		fill.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(fill)
	var scrim = ColorRect.new()
	scrim.color = Color(0.02, 0.05, 0.07, 0.42)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	# 左侧压暗，标题与按钮读得清
	var shade = ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.06, 0.0)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient = Gradient.new()
	gradient.set_color(0, Color(0.02, 0.04, 0.06, 0.8))
	gradient.set_color(1, Color(0.02, 0.04, 0.06, 0.0))
	var texture_rect = TextureRect.new()
	var gradient_texture = GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 512
	gradient_texture.height = 8
	gradient_texture.fill_from = Vector2(0, 0)
	gradient_texture.fill_to = Vector2(1, 0)
	texture_rect.texture = gradient_texture
	texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(texture_rect)


func _title_block() -> void:
	var box = VBoxContainer.new()
	box.position = Vector2(96, 120)
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var top = HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(top)
	var title = Ui.title("妖怪夜市", 96, Ui.GOLD_BRIGHT)
	top.add_child(title)
	top.add_child(Ui.seal("夜", 84.0))
	var sub = Ui.label("三天十五夜 · 中式夜市车道塔防", 22, Ui.TEXT)
	box.add_child(sub)
	var rule = ColorRect.new()
	rule.color = Color(Ui.GOLD_DIM.r, Ui.GOLD_DIM.g, Ui.GOLD_DIM.b, 0.8)
	rule.custom_minimum_size = Vector2(320, 2)
	box.add_child(rule)
	box.add_child(Ui.label("香火为钱，草木为兵。守到天亮，摊子才算收。", 18, Ui.TEXT_DIM))


func _menu_buttons() -> void:
	var box = VBoxContainer.new()
	box.position = Vector2(96, 356)
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	var save_data: Dictionary = game.save_data
	var has_save = not save_data.is_empty()
	var primary_text = "继续守夜" if has_save else "开始守夜"
	var primary = Ui.button(primary_text, 24, 340, 62)
	primary.pressed.connect(func():
		game.play_sfx("click")
		if has_save:
			game.continue_run()
		else:
			game.show_levels())
	box.add_child(primary)
	if has_save:
		var meta = _save_line(save_data)
		var meta_label = Ui.label(meta, 16, Ui.TEXT_DIM)
		meta_label.custom_minimum_size = Vector2(340, 0)
		box.add_child(meta_label)
	var entries = [
		["挑选一夜", func(): game.show_levels()],
		["训练与教程", func(): game.show_training_menu()],
		["草木志 · 恶客录", func(): game.open_almanac("plant", 0)],
		["设置", func(): game.open_settings()],
	]
	for entry in entries:
		var button = Ui.button(String(entry[0]), 20, 340, 48)
		button.pressed.connect(func():
			game.play_sfx("click")
			entry[1].call())
		box.add_child(button)
	var quit = Ui.button("收摊退出", 18, 340, 42)
	quit.pressed.connect(func(): get_tree().quit())
	box.add_child(quit)


func _save_line(save_data: Dictionary) -> String:
	var level_id = int(save_data.get("level_id", 1))
	var level = Content.get_level(level_id)
	var sim_data: Dictionary = save_data.get("sim", {})
	var wave = int(sim_data.get("wave_index", 0))
	return "上次停在 %s·%s %s 第 %d 波" % [level["day_name"], level["day_sub"],
		level["name"], mini(wave + 1, 12)]


func _records() -> void:
	var panel = Ui.panel(0.78)
	panel.position = Vector2(96, 760)
	panel.custom_minimum_size = Vector2(380, 114)
	add_child(panel)
	var box = Ui.vbox(4)
	panel.add_child(box)
	box.add_child(Ui.strong("守夜记录", 18, Ui.GOLD))
	var cleared: Array = game.progress.get("cleared", [])
	var lines = [
		"通关 %d / %d 夜" % [cleared.size(), Content.LEVELS.size()],
		"最多击退 %d · 最多守到第 %d 波" % [int(game.records.get("best_kills", 0)),
			int(game.records.get("best_wave", 0))],
	]
	if int(game.records.get("wins", 0)) > 0:
		lines.append("胜利 %d 次" % int(game.records.get("wins", 0)))
	for line in lines:
		box.add_child(Ui.label(String(line), 16, Ui.TEXT_DIM))


func _decor() -> void:
	var holder = Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	holder.offset_left = -700.0
	holder.offset_right = -60.0
	holder.offset_top = -420.0
	holder.offset_bottom = -20.0
	add_child(holder)
	var ids = ["lantern", "shooter", "wall", "cat"]
	var positions = [Vector2(80, 400), Vector2(250, 420), Vector2(430, 405),
		Vector2(590, 424)]
	var heights = [170.0, 185.0, 175.0, 170.0]
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
		rect.modulate = Color(1, 1, 1, 0.28)
		holder.add_child(rect)
	var hint = Ui.label("F11 全屏 · Esc 返回", 15, Color(1, 1, 1, 0.35))
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -220.0
	hint.offset_top = -34.0
	hint.offset_right = -24.0
	add_child(hint)
