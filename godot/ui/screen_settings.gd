## 设置：分三页，按「战斗与操作 / 显示 / 声音」摆，留白多一点。
##
## 每项都是「左边标题+说明、右边一排药丸」，条目之间加分隔线，
## 一页摆五六项不显空，摆八九项也不挤。
extends Control

const Build = preload("res://data/build_info.gd")

var game = null

const PAGES := ["战斗与操作", "显示", "声音", "键位"]

const ROWS := {
	0: [
		{"key": "difficulty", "label": "难度",
			"note": "初次守夜可选简单，熟悉布防后再挑战困难；开战后本局保持不变",
			"options": [["easy", "简单"], ["normal", "普通"], ["hard", "困难"]],
			"lock_in_run": true},
		{"key": "auto_collect", "label": "自动拾取香火",
			"note": "开启后香火落地一会儿自动收下",
			"options": [[true, "开"], [false, "关"]]},
		{"key": "collect_delay", "label": "拾取延迟",
			"note": "自动拾取开启后，落地到收取的等待",
			"options": [[0.0, "立即"], [3.0, "3 秒"]], "requires": "auto_collect"},
		{"key": "quick_wave", "label": "快速唤波",
			"note": "开启后右侧出现「唤波」按钮，提前放下一波",
			"options": [[true, "开"], [false, "关"]]},
		{"key": "cheats", "label": "作弊菜单",
			"note": "开启后局内出现「作弊」按钮；训练场一直可用",
			"options": [[true, "开"], [false, "关"]]},
	],
	1: [
		{"key": "resolution", "label": "窗口分辨率",
			"note": "F11 切换全屏。开窗后拖动边缘，游戏会记住尺寸",
			"options": [["auto", "全屏"], ["window", "记忆窗口"], ["2560x1600", "2560×1600"],
				["1920x1080", "1920×1080"], ["1280x720", "1280×720"]]},
		{"key": "ui_text_size", "label": "界面字号",
			"note": "放大界面文字，可在战斗中切换",
			"options": [["normal", "标准"], ["medium", "较大"], ["large", "最大"]]},
		{"key": "tier_shapes", "label": "阶别附加形状",
			"note": "低阶圆形、中阶菱形、高阶三角形",
			"options": [[true, "开"], [false, "关"]]},
		{"key": "show_text_hints", "label": "战斗文字提醒",
			"note": "在旗帜下方显示当前局势和恶首提示",
			"options": [[true, "开"], [false, "关"]]},
		{"key": "show_grid", "label": "场内描格子",
			"note": "关掉后棋盘不再画每一格的线，只留台面外框",
			"options": [[true, "描格"], [false, "不描"]]},
		{"key": "health_bars", "label": "战场血条",
			"note": "显示草木和恶客的血量；恶客另有护具，可附带数值",
			"options": [["off", "不显示"], ["bar", "血条"], ["barText", "血条+数值"]]},
	],
	2: [
		{"key": "sound", "label": "声音总开关",
			"note": "关闭后全局静音", "options": [[true, "开"], [false, "关"]]},
		{"key": "music_style", "label": "音乐风格",
			"note": "朴素：三首通用战曲；完整：每周都有自己的战曲",
			"options": [["plain", "朴素"], ["complete", "完整"]]},
		{"key": "music_volume", "label": "音乐音量", "note": "0—100，拖动即时生效",
			"type": "range"},
		{"key": "sfx_volume", "label": "音效音量", "note": "0—100，拖动即时生效",
			"type": "range"},
	],
}

var page := 0
var _capturing := ""
var _panel: PanelContainer = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var texture := load("res://assets/bg/menu.jpg") \
		if ResourceLoader.exists("res://assets/bg/menu.jpg") else null
	if texture != null:
		var rect := TextureRect.new()
		rect.texture = texture
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rect.modulate = Color(0.42, 0.46, 0.52, 1.0)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rect)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.06, 0.84)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	_panel.offset_left = -540.0
	_panel.offset_right = 540.0
	_panel.offset_top = -368.0
	_panel.offset_bottom = 368.0
	add_child(_panel)
	var outer := Ui.vbox(12)
	_panel.add_child(outer)

	var head := Ui.hbox(12)
	outer.add_child(head)
	head.add_child(Ui.seal("设"))
	head.add_child(Ui.title("设置", 40, Ui.GOLD_BRIGHT))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var back := Ui.button("返回 (Esc)", 18, 140, 42)
	back.pressed.connect(func():
		if game.overlay_from == "":
			game.show_menu()
		else:
			game.close_overlay())
	head.add_child(back)
	outer.add_child(Ui.hline(Ui.GOLD_DIM, 1.0))

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 22)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(body)

	var rail := Ui.vbox(10)
	rail.custom_minimum_size = Vector2(168, 0)
	body.add_child(rail)
	for i in PAGES.size():
		var button := Ui.button(PAGES[i], 17, 168, 46)
		if i == page:
			button.add_theme_color_override("font_color", Ui.INK)
			button.add_theme_stylebox_override("normal",
				Ui.flat(Color(0.86, 0.72, 0.42, 0.95), Ui.GOLD_BRIGHT, 10, 2))
			button.add_theme_stylebox_override("hover",
				Ui.flat(Color(0.92, 0.8, 0.5, 1.0), Ui.GOLD_BRIGHT, 10, 2))
		button.pressed.connect(_select_page.bind(i))
		rail.add_child(button)
	var hint := Ui.label("设置会自动保存；想换守夜方式，请在开战前选择。", 13, Ui.TEXT_FAINT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(168, 0)
	rail.add_child(hint)
	var build := Ui.label("妖怪夜市 v%s" % String(Build.VERSION),12,Ui.TEXT_FAINT)
	build.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	build.custom_minimum_size = Vector2(168, 0)
	rail.add_child(build)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var list := Ui.vbox(0)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	if page == 3:
		_build_key_rows(list)
		return
	var rows: Array = ROWS.get(page, [])
	var first := true
	for row in rows:
		if not first:
			list.add_child(Ui.spacer(8))
			list.add_child(Ui.hline(Color(Ui.GOLD_DIM.r, Ui.GOLD_DIM.g,
				Ui.GOLD_DIM.b, 0.35), 1.0))
		first = false
		list.add_child(Ui.spacer(12))
		list.add_child(_row(row))
		list.add_child(Ui.spacer(12))


func _select_page(index: int) -> void:
	_capturing = ""
	page = index
	_build()


func _row(row: Dictionary) -> Control:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 18)
	var label_col := Ui.vbox(3)
	label_col.custom_minimum_size = Vector2(260, 0)
	label_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(label_col)
	label_col.add_child(Ui.strong(String(row["label"]), 19, Ui.TEXT))
	var note := Ui.label(String(row["note"]), 14, Ui.TEXT_FAINT)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(240, 0)
	label_col.add_child(note)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	controls.custom_minimum_size = Vector2(430, 0)
	controls.size_flags_horizontal = Control.SIZE_SHRINK_END
	controls.alignment = BoxContainer.ALIGNMENT_BEGIN
	top.add_child(controls)
	var enabled := _row_enabled(row)
	if String(row.get("type", "options")) == "range":
		controls.add_child(_slider(String(row["key"])))
	else:
		for option in row["options"]:
			var selected: bool = _matches(game.settings.get(String(row["key"])),
				option[0])
			var button := Ui.button(String(option[1]), 16, 80, 40)
			if selected:
				button.add_theme_color_override("font_color", Ui.INK)
				button.add_theme_stylebox_override("normal",
					Ui.flat(Color(0.86, 0.72, 0.42, 0.95), Ui.GOLD_BRIGHT, 10, 2))
				button.add_theme_stylebox_override("hover",
					Ui.flat(Color(0.92, 0.8, 0.5, 1.0), Ui.GOLD_BRIGHT, 10, 2))
			button.disabled = not enabled
			button.pressed.connect(_set_option.bind(String(row["key"]), option[0]))
			controls.add_child(button)
	return top


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
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 5
	slider.value = float(game.settings.get(key, 70))
	slider.custom_minimum_size = Vector2(260, 26)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var value_label := Ui.label("%d" % int(slider.value), 16, Ui.TEXT_DIM)
	value_label.custom_minimum_size = Vector2(38, 0)
	slider.value_changed.connect(func(value: float):
		value_label.text = "%d" % int(value)
		game.set_setting(key, int(value)))
	box.add_child(slider)
	box.add_child(value_label)
	return box

func _build_key_rows(list: VBoxContainer) -> void:
	list.add_child(Ui.label("点击键位后按下新键。与已有键冲突时，两项会互换。", 16, Ui.TEXT_DIM))
	list.add_child(Ui.spacer(12))
	for action in game.DEFAULT_KEYS:
		var row := Ui.hbox(10)
		list.add_child(row)
		var action_name: String = "草木卡槽 " + action.trim_prefix("card_") if action.begins_with("card_") \
			else ("提高倍速" if action == "speed_up" else "降低倍速")
		var label := Ui.label(action_name, 18)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var caption := "按下新键（Esc 取消）" if _capturing == action \
			else _key_name(game.bound_key(action))
		var button := Ui.button(caption, 17, 235, 38)
		row.add_child(button)
		button.pressed.connect(func():
			_capturing = action
			button.text = "按下新键（Esc 取消）")
		list.add_child(Ui.spacer(6))
	var reset := Ui.button("恢复默认键位", 18, 200, 42)
	reset.pressed.connect(func():
		game.set_setting("key_bindings", {})
		_capturing = ""
		_build())
	list.add_child(reset)


func _key_name(physical: int) -> String:
	var code := DisplayServer.keyboard_get_keycode_from_physical(physical)
	return String({KEY_BRACKETLEFT: "[", KEY_BRACKETRIGHT: "]"}.get(code, OS.get_keycode_string(code)))


func _input(event: InputEvent) -> void:
	if _capturing.is_empty() or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	if event.keycode in [KEY_F11, KEY_P, KEY_SPACE, KEY_CTRL, KEY_ALT, KEY_META, KEY_SHIFT]:
		return
	if event.keycode != KEY_ESCAPE:
		game.rebind_key(_capturing, event.physical_keycode if event.physical_keycode != 0 else event.keycode)
	_capturing = ""
	_build()
