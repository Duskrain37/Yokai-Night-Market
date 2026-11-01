## 设置：战斗 / 显示 / 经济 / 声音 四组。
##
## 本轮新增「场内描格子」——关掉后棋盘只保留外框，不再画每一格的边线，
## 想看清楚画面的玩家可以关；默认保持开启，方便新手判断落点。
##
## 难度只在开战前可改（对局中锁定），其余设置立即生效并写盘。
extends Control

var game = null

const GROUPS = [
	{
		"title": "战斗",
		"rows": [
			{"key": "speed", "label": "战斗速度", "note": "整局的时间流速，局内暂停菜单里也能切",
				"options": [[1.0, "1×"], [1.5, "1.5×"], [2.0, "2×"], [3.0, "3×"]]},
			{"key": "difficulty", "label": "难度", "note": "出怪与血量 ×1 / ×1.25 / ×1.5；进入对局后锁定",
				"options": [["easy", "简单"], ["normal", "普通"], ["hard", "困难"]],
				"lock_in_run": true},
			{"key": "quick_wave", "label": "快速唤波", "note": "开启后右侧出现「唤波」按钮，提前放下一波",
				"options": [[true, "开"], [false, "关"]]},
			{"key": "cheats", "label": "作弊菜单", "note": "开启后局内出现「作弊」按钮；训练场一直可用",
				"options": [[true, "开"], [false, "关"]]},
		],
	},
	{
		"title": "显示",
		"rows": [
			{"key": "show_grid", "label": "场内描格子", "note": "关掉后棋盘不再画每一格的线，只留外框",
				"options": [[true, "描格"], [false, "不描"]]},
			{"key": "health_bars", "label": "恶客血条", "note": "血条为护具+本体双段，可选是否附带数字",
				"options": [["off", "不显示"], ["bar", "血条"], ["barText", "血条+数值"]]},
		],
	},
	{
		"title": "香火",
		"rows": [
			{"key": "auto_collect", "label": "自动拾取", "note": "开启后香火落地一会儿自动收下",
				"options": [[true, "开"], [false, "关"]]},
			{"key": "collect_delay", "label": "拾取延迟", "note": "自动拾取开启后，落地到收取的等待",
				"options": [[0.0, "立即"], [3.0, "3 秒"]], "requires": "auto_collect"},
		],
	},
	{
		"title": "声音",
		"rows": [
			{"key": "sound", "label": "总开关", "note": "关闭后全局静音",
				"options": [[true, "开"], [false, "关"]]},
			{"key": "music_volume", "label": "音乐音量", "note": "0—100，拖动即时生效",
				"type": "range"},
			{"key": "sfx_volume", "label": "音效音量", "note": "0—100，拖动即时生效",
				"type": "range"},
		],
	},
]

var _panel: PanelContainer = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var texture = load("res://assets/bg/menu.jpg") if ResourceLoader.exists(
		"res://assets/bg/menu.jpg") else null
	if texture != null:
		var rect = TextureRect.new()
		rect.texture = texture
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rect.modulate = Color(0.45, 0.5, 0.55, 1.0)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rect)
	var shade = ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.06, 0.82)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	_build()


func _build() -> void:
	if _panel != null and is_instance_valid(_panel):
		_panel.queue_free()
	_panel = Ui.panel(0.96)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.offset_left = -420.0
	_panel.offset_right = 420.0
	_panel.offset_top = -382.0
	_panel.offset_bottom = 382.0
	add_child(_panel)
	var outer = Ui.vbox(8)
	_panel.add_child(outer)
	var head = Ui.hbox(12)
	outer.add_child(head)
	head.add_child(Ui.seal("设"))
	head.add_child(Ui.title("设置", 40, Ui.GOLD_BRIGHT))
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var back = Ui.button("返回 (Esc)", 18, 140, 42)
	back.pressed.connect(func():
		if game.overlay_from == "":
			game.show_menu()
		else:
			game.close_overlay())
	head.add_child(back)
	outer.add_child(Ui.hline(Ui.GOLD_DIM, 1.0))

	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var list = Ui.vbox(6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	for group in GROUPS:
		var title = Ui.strong(String(group["title"]), 18, Ui.GOLD)
		list.add_child(title)
		for row in group["rows"]:
			list.add_child(_row(row))
		list.add_child(Ui.spacer(4))
	list.add_child(Ui.label("设置会立即写盘；难度请在对局开始前调整。", 15, Ui.TEXT_FAINT))


func _row(row: Dictionary) -> Control:
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var top = HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	box.add_child(top)
	var label_col = Ui.vbox(0)
	label_col.custom_minimum_size = Vector2(300, 0)
	top.add_child(label_col)
	label_col.add_child(Ui.strong(String(row["label"]), 18, Ui.TEXT))
	var note = Ui.label(String(row["note"]), 14, Ui.TEXT_FAINT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(300, 0)
	label_col.add_child(note)
	var controls = HBoxContainer.new()
	controls.add_theme_constant_override("separation", 6)
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.alignment = BoxContainer.ALIGNMENT_END
	top.add_child(controls)
	var enabled = _row_enabled(row)
	if String(row.get("type", "options")) == "range":
		controls.add_child(_slider(String(row["key"])))
	else:
		var options: Array = row["options"]
		for option in options:
			var selected = _matches(game.settings.get(String(row["key"])), option[0])
			var button = Ui.button(String(option[1]), 16, 88, 36)
			if selected:
				button.add_theme_color_override("font_color", Ui.INK)
				button.add_theme_stylebox_override("normal",
					Ui.flat(Color(0.86, 0.72, 0.42, 0.95), Ui.GOLD_BRIGHT, 10, 2))
				button.add_theme_stylebox_override("hover",
					Ui.flat(Color(0.92, 0.8, 0.5, 1.0), Ui.GOLD_BRIGHT, 10, 2))
			button.disabled = not enabled
			button.pressed.connect(_set_option.bind(String(row["key"]), option[0]))
			controls.add_child(button)
	return box


func _set_option(key: String, value) -> void:
	game.set_setting(key, value)
	_build()


func _matches(current, option) -> bool:
	if current is float and option is float:
		return is_equal_approx(current, option)
	if current is float and option is int:
		return is_equal_approx(current, float(option))
	if option is float and current is int:
		return is_equal_approx(float(current), option)
	return current == option


func _row_enabled(row: Dictionary) -> bool:
	if bool(row.get("lock_in_run", false)) and game.screen == "battle":
		return false
	if row.has("requires") and not bool(game.settings.get(String(row["requires"]))):
		return false
	return true


func _slider(key: String) -> Control:
	var box = HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var slider = HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = float(game.settings.get(key, 70))
	slider.custom_minimum_size = Vector2(240, 24)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var value_label = Ui.label("%d" % int(slider.value), 16, Ui.TEXT_DIM)
	value_label.custom_minimum_size = Vector2(38, 0)
	slider.value_changed.connect(func(value: float):
		value_label.text = "%d" % int(value)
		game.set_setting(key, int(value)))
	box.add_child(slider)
	box.add_child(value_label)
	return box
