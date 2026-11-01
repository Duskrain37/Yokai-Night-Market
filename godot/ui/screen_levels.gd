## 选关「大岛航线」：三天各一列，每列五夜；右侧是选中那一夜的底细。
extends Control

var game = null
var selected = 1
var _cards: Array = []
var _detail: VBoxContainer = null
var _detail_panel: PanelContainer = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	selected = clampi(int(game.progress.get("selected", 1)), 1, Content.LEVELS.size())
	_backdrop()
	_header()
	_build_days()
	_build_detail()
	game.play_music_scene("menu")


func _backdrop() -> void:
	var fill = ColorRect.new()
	fill.color = Ui.INK
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fill)
	var texture = load("res://assets/bg/map-day3.jpg") if ResourceLoader.exists(
		"res://assets/bg/map-day3.jpg") else null
	if texture != null:
		var rect = TextureRect.new()
		rect.texture = texture
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.modulate = Color(0.5, 0.55, 0.6, 1.0)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rect)
	var scrim = ColorRect.new()
	scrim.color = Color(0.02, 0.05, 0.07, 0.72)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)


func _header() -> void:
	var back = Ui.button("← 回封面", 18, 130, 42)
	back.position = Vector2(56, 40)
	back.pressed.connect(func(): game.show_menu())
	add_child(back)
	var title = Ui.title("挑选一夜", 48, Ui.GOLD_BRIGHT)
	title.position = Vector2(96, 96)
	add_child(title)
	var sub = Ui.label("三天十五夜，越往后恶客越多、越硬。选中的那一夜会先进入备战。",
		18, Ui.TEXT_DIM)
	sub.position = Vector2(100, 158)
	add_child(sub)


func _build_days() -> void:
	var start_x = 92.0
	for day_index in 3:
		var day: Dictionary = Content.DAYS[day_index]
		var column = VBoxContainer.new()
		column.position = Vector2(start_x + day_index * 372.0, 208)
		column.add_theme_constant_override("separation", 8)
		column.custom_minimum_size = Vector2(348, 0)
		add_child(column)
		var head = Ui.panel(0.72)
		column.add_child(head)
		var head_box = Ui.vbox(2)
		head.add_child(head_box)
		var line = Ui.hbox(8)
		head_box.add_child(line)
		line.add_child(Ui.strong(day["name"], 22, Ui.GOLD))
		line.add_child(Ui.label(String(day["sub"]), 18, Ui.TEXT))
		var blurb = Ui.label(String(day["blurb"]), 15, Ui.TEXT_DIM)
		blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		blurb.custom_minimum_size = Vector2(310, 0)
		head_box.add_child(blurb)
		for night in 5:
			var level_id: int = day_index * 5 + night + 1
			var card = NightCard.new()
			card.level_id = level_id
			card.screen = self
			card.custom_minimum_size = Vector2(348, 84)
			column.add_child(card)
			_cards.append(card)


func select_level(level_id: int) -> void:
	selected = level_id
	for card in _cards:
		card.queue_redraw()
	_build_detail()
	game.play_sfx("click")


func _build_detail() -> void:
	if _detail_panel != null and is_instance_valid(_detail_panel):
		_detail_panel.queue_free()
	var level = Content.get_level(selected)
	_detail_panel = Ui.panel(0.92)
	_detail_panel.position = Vector2(1216, 208)
	_detail_panel.custom_minimum_size = Vector2(324, 520)
	add_child(_detail_panel)
	var box = Ui.vbox(8)
	_detail_panel.add_child(box)
	var title_row = Ui.hbox(10)
	box.add_child(title_row)
	title_row.add_child(Ui.seal(String(level["tag"]).substr(0, 1)))
	var title_col = Ui.vbox(0)
	title_row.add_child(title_col)
	title_col.add_child(Ui.strong(String(level["name"]), 24, Ui.GOLD_BRIGHT))
	title_col.add_child(Ui.label("%s·%s · %s" % [level["day_name"], level["day_sub"],
		level["tag"]], 16, Ui.TEXT_DIM))
	box.add_child(Ui.hline(Ui.GOLD_DIM, 1.0))
	var rows = [
		["威胁", "%s" % String.num(float(level["threat"]), 2)],
		["棋盘", "%d 行 × 9 列" % int(level["rows"])],
		["波次", "%d 波" % int(level["waves"].size())],
		["起手香火", str(int(level["start_sun"]))],
	]
	for row in rows:
		var line = Ui.hbox(10)
		box.add_child(line)
		var key = Ui.label(String(row[0]), 16, Ui.TEXT_DIM)
		key.custom_minimum_size = Vector2(84, 0)
		line.add_child(key)
		line.add_child(Ui.label(String(row[1]), 17, Ui.TEXT))
	var threat_bar = ThreatBar.new()
	threat_bar.value = float(level["threat"])
	threat_bar.custom_minimum_size = Vector2(280, 12)
	box.add_child(threat_bar)
	box.add_child(Ui.hline(Ui.GOLD_DIM, 1.0))
	box.add_child(Ui.label("今夜恶客", 17, Ui.GOLD))
	var seen = Content.plants_in_level(level)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)
	for type in seen:
		var tag = Ui.label("· " + String(Content.ZOMBIES[type]["name"]), 15, Ui.TEXT_DIM)
		grid.add_child(tag)
	box.add_child(Ui.spacer(6))
	var cleared: Array = game.progress.get("cleared", [])
	if cleared.has(selected):
		box.add_child(Ui.label("已守住这一夜", 16, Ui.GOOD))
	var enter = Ui.button("进入备战", 20, 288, 52)
	enter.pressed.connect(func(): game.show_prep(selected))
	box.add_child(enter)
	var almanac = Ui.button("看恶客图鉴", 16, 288, 38)
	almanac.pressed.connect(func(): game.open_almanac("zombie", 0))
	box.add_child(almanac)


# ── 控件 ────────────────────────────────────────────────────────────────────
class NightCard extends Control:
	var level_id = 1
	var screen = null
	var hovered = false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func():
			hovered = true
			queue_redraw())
		mouse_exited.connect(func():
			hovered = false
			queue_redraw())

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			screen.select_level(level_id)
		elif event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_RIGHT:
			accept_event()
			screen.game.show_prep(level_id)

	func _draw() -> void:
		var level = Content.get_level(level_id)
		var chosen: bool = screen.selected == level_id
		var cleared: bool = Array(screen.game.progress.get("cleared", [])).has(level_id)
		var base = Color(0.07, 0.11, 0.14, 0.86)
		if chosen:
			base = Color(0.22, 0.17, 0.08, 0.95)
		elif hovered:
			base = Color(0.13, 0.19, 0.22, 0.92)
		var rect = Rect2(Vector2.ZERO, size)
		draw_rect(rect, base)
		draw_rect(rect, Ui.GOLD if chosen else Color(0.34, 0.31, 0.25, 0.9), false,
			2.0 if chosen else 1.0)
		var font = Ui.body_font()
		var strong = Ui.medium_font()
		draw_string(strong, Vector2(18, 34), String(level["name"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Ui.TEXT if not chosen else Ui.GOLD_BRIGHT)
		draw_string(font, Vector2(18, 60), String(level["tag"]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Ui.TEXT_DIM)
		# 威胁条
		var threat = float(level["threat"])
		var segments = 5
		var filled = clampi(int(round((threat - 0.8) / (3.0 - 0.8) * segments)), 1, segments)
		for i in segments:
			var x = 116.0 + i * 20.0
			var color = Ui.BAD if i < filled else Color(1, 1, 1, 0.14)
			draw_rect(Rect2(x, 48, 14, 7), color)
		draw_string(font, Vector2(232, 56), "威胁 %s" % String.num(threat, 2),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Ui.TEXT_DIM)
		if cleared:
			draw_string(font, Vector2(size.x - 74, 34), "已守", HORIZONTAL_ALIGNMENT_LEFT,
				-1, 16, Ui.GOOD)


class ThreatBar extends Control:
	var value = 1.0

	func _draw() -> void:
		var ratio = clampf((value - 0.8) / (3.0 - 0.8), 0.0, 1.0)
		draw_rect(Rect2(0, 0, size.x, 10), Color(1, 1, 1, 0.1))
		draw_rect(Rect2(0, 0, size.x * ratio, 10), Ui.WARN.lerp(Ui.BAD, ratio))
