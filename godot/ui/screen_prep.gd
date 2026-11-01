## 备战：左边是十八种草木名册，右边是上场卡组、今夜恶客与开战。
##
## 与 v0.2.4 的差异：名册与卡组分栏，不再与提示文字共用一块区域（旧版训练备战
## 的文字交叠正是这么来的）；卡组上限十张，超出时给出明确提示。
extends Control

var game = null
var _picked: Array = []
var _roster_nodes: Array = []
var _slot_nodes: Array = []
var _warning: Label = null
var _count_label: Label = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_picked = Array(game.prep.get("selected", [])).duplicate()
	if _picked.is_empty():
		_picked = game.loadout.duplicate()
	_backdrop()
	_header()
	_roster()
	_slots()
	game.play_music_scene("menu")


func _level() -> Dictionary:
	return game.prep.get("level", Content.get_level(1))


func _backdrop() -> void:
	var fill = ColorRect.new()
	fill.color = Ui.INK
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fill)
	var map = String(_level()["map"])
	var file = "res://assets/bg/map-day1.jpg"
	match map:
		"market":
			file = "res://assets/bg/map-day2.jpg"
		"water":
			file = "res://assets/bg/map-day3.jpg"
	if ResourceLoader.exists(file):
		var rect = TextureRect.new()
		rect.texture = load(file)
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.modulate = Color(0.55, 0.6, 0.65, 1.0)
		add_child(rect)
	var scrim = ColorRect.new()
	scrim.color = Color(0.02, 0.05, 0.07, 0.8)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)


func _header() -> void:
	var level = _level()
	var training = bool(game.prep.get("training", false))
	var back = Ui.button("← 返回", 18, 120, 40)
	back.position = Vector2(56, 34)
	back.pressed.connect(func():
		if training:
			game.show_training_menu()
		else:
			game.show_levels())
	add_child(back)
	var title = Ui.title("备战 · %s" % String(level["name"]), 44, Ui.GOLD_BRIGHT)
	title.position = Vector2(96, 84)
	add_child(title)
	var detail = "%s·%s · %s · 威胁 %s · %d 波" % [level["day_name"], level["day_sub"],
		level["tag"], String.num(float(level["threat"]), 2), int(level["waves"].size())]
	if training:
		detail = "训练场 · %s·%s · 不刷波次、不判负、起手 1000 香火" % [
			level["day_name"], level["day_sub"]]
	var sub = Ui.label(detail, 18, Ui.TEXT_DIM)
	sub.position = Vector2(100, 148)
	add_child(sub)
	var rule = ColorRect.new()
	rule.color = Color(Ui.GOLD_DIM.r, Ui.GOLD_DIM.g, Ui.GOLD_DIM.b, 0.6)
	rule.position = Vector2(100, 182)
	rule.size = Vector2(1400, 1)
	add_child(rule)


func _roster() -> void:
	var panel = Ui.panel(0.88)
	panel.position = Vector2(56, 200)
	panel.custom_minimum_size = Vector2(1010, 660)
	add_child(panel)
	var box = Ui.vbox(8)
	panel.add_child(box)
	var head = Ui.hbox(12)
	box.add_child(head)
	head.add_child(Ui.strong("草木名册", 22, Ui.GOLD))
	head.add_child(Ui.label("点一下入卡组，再点一下取下来；一局最多十张。", 15, Ui.TEXT_DIM))
	var grid = GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	_roster_nodes.clear()
	for type in Content.PLANT_ORDER:
		var card = PlantPickCard.new()
		card.plant_id = String(type)
		card.screen = self
		card.custom_minimum_size = Vector2(156, 176)
		grid.add_child(card)
		_roster_nodes.append(card)


func _slots() -> void:
	var panel = Ui.panel(0.9)
	panel.position = Vector2(1090, 200)
	panel.custom_minimum_size = Vector2(452, 660)
	add_child(panel)
	var box = Ui.vbox(8)
	panel.add_child(box)
	var head = Ui.hbox(10)
	box.add_child(head)
	head.add_child(Ui.strong("上场卡组", 22, Ui.GOLD))
	_count_label = Ui.label("", 16, Ui.TEXT_DIM)
	head.add_child(_count_label)
	var grid = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	_slot_nodes.clear()
	for i in 10:
		var slot = SlotCard.new()
		slot.index = i
		slot.screen = self
		slot.custom_minimum_size = Vector2(80, 96)
		grid.add_child(slot)
		_slot_nodes.append(slot)
	_warning = Ui.label("", 16, Ui.WARN)
	_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warning.custom_minimum_size = Vector2(410, 40)
	box.add_child(_warning)
	box.add_child(Ui.hline(Ui.GOLD_DIM, 1.0))
	box.add_child(Ui.label("今夜恶客", 17, Ui.GOLD))
	var enemies = Ui.vbox(2)
	box.add_child(enemies)
	var seen = Content.plants_in_level(_level())
	var line = ""
	for type in seen:
		line += "%s  " % String(Content.ZOMBIES[type]["name"])
	var enemy_label = Ui.label(line.strip_edges(), 15, Ui.TEXT_DIM)
	enemy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	enemy_label.custom_minimum_size = Vector2(410, 0)
	enemies.add_child(enemy_label)
	box.add_child(Ui.spacer(4))
	var actions = Ui.hbox(8)
	box.add_child(actions)
	var auto = Ui.button("自动配卡", 16, 130, 40)
	auto.pressed.connect(func(): _auto_pick())
	actions.add_child(auto)
	var clear = Ui.button("清空", 16, 90, 40)
	clear.pressed.connect(func():
		_picked.clear()
		_refresh())
	actions.add_child(clear)
	var almanac = Ui.button("图鉴", 16, 90, 40)
	almanac.pressed.connect(func(): game.open_almanac("plant", 0))
	actions.add_child(almanac)
	var start = Ui.button("开战" if not bool(game.prep.get("training", false)) else "进训练场",
		22, 420, 56)
	start.pressed.connect(func(): _start())
	box.add_child(start)
	_refresh()


func _auto_pick() -> void:
	var priority = ["lantern", "shooter", "wall", "sun_lamp", "bell", "censer",
		"torch", "umbrella", "lion", "needle", "judge", "cat", "lobber", "star",
		"mushroom", "bomb", "shell"]
	_picked.clear()
	for type in priority:
		if Content.PLANTS.has(type) and _picked.size() < 10:
			_picked.append(type)
	for type in Content.PLANT_ORDER:
		if _picked.size() >= 10:
			break
		if not _picked.has(type):
			_picked.append(type)
	_refresh()
	game.play_sfx("click")


func toggle_plant(type: String) -> void:
	if _picked.has(type):
		_picked.erase(type)
	elif _picked.size() >= 10:
		_warning.text = "卡组已满十张，先取下一张再选。"
		game.play_sfx("deny")
		_refresh()
		return
	else:
		_picked.append(type)
	game.play_sfx("click")
	_refresh()


func _refresh() -> void:
	game.prep["selected"] = _picked.duplicate()
	for card in _roster_nodes:
		card.chosen = _picked.has(card.plant_id)
		card.queue_redraw()
	for slot in _slot_nodes:
		slot.set_plant(String(_picked[slot.index]) if slot.index < _picked.size() else "")
	if _count_label != null:
		_count_label.text = "%d / 10" % _picked.size()
	if _warning != null:
		if _picked.is_empty():
			_warning.text = "空手上阵会被恶客直接推平；至少带一株能产香火的草木。"
		elif not _has_producer():
			_warning.text = "没有产能草木，香火只靠天上掉的，会很难撑住。"
		elif _picked.size() > 10:
			_warning.text = "卡组超出十张。"
		else:
			_warning.text = ""


func _has_producer() -> bool:
	for type in _picked:
		if Content.PLANTS[type].has("produce"):
			return true
	return false


func _start() -> void:
	if _picked.is_empty():
		_warning.text = "先选至少一株草木。"
		game.play_sfx("deny")
		return
	game.loadout = _picked.duplicate()
	game.save_progress()
	var level_id = int(_level()["id"])
	if bool(game.prep.get("training", false)):
		game.training = {
			"day": int(game.prep.get("training_day", 1)),
			"cooldown_locked": false,
		}
		game.start_battle(level_id, _picked, "training")
	else:
		game.start_battle(level_id, _picked, "normal")


# ── 控件 ────────────────────────────────────────────────────────────────────
class PlantPickCard extends Control:
	var plant_id = ""
	var screen = null
	var chosen = false
	var hovered = false
	var icon: Texture2D = null

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		icon = Ui.sprite(plant_id)  # 贴图只在 _draw 之外取一次
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
			screen.toggle_plant(plant_id)
		elif event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_RIGHT:
			accept_event()
			var index = Content.PLANT_ORDER.find(plant_id)
			screen.game.open_almanac("plant", index)

	func _draw() -> void:
		var def: Dictionary = Content.PLANTS[plant_id]
		var rect = Rect2(Vector2.ZERO, size)
		var base = Color(0.07, 0.11, 0.14, 0.9)
		if chosen:
			base = Color(0.24, 0.19, 0.09, 0.96)
		elif hovered:
			base = Color(0.13, 0.2, 0.23, 0.94)
		draw_rect(rect, base)
		draw_rect(rect, Ui.GOLD if chosen else Color(0.32, 0.29, 0.24, 0.9),
			false, 2.0 if chosen else 1.0)
		Ui.draw_plant_icon(self, plant_id, Rect2(8, 6, rect.size.x - 16,
			rect.size.y - 62))
		var font = Ui.body_font()
		var strong = Ui.medium_font()
		var name_text = String(def["name"])
		var width = strong.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			19).x
		draw_string(strong, Vector2((rect.size.x - width) * 0.5, rect.size.y - 38),
			name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Ui.TEXT)
		var role = String(def["role"])
		var role_width = font.get_string_size(role, HORIZONTAL_ALIGNMENT_LEFT, -1,
			14).x
		draw_string(font, Vector2((rect.size.x - role_width) * 0.5, rect.size.y - 18),
			role, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Ui.TEXT_DIM)
		var cost = "%d 香火 · 冷却 %d 秒" % [int(def["cost"]), int(def["cooldown"])]
		var cost_width = font.get_string_size(cost, HORIZONTAL_ALIGNMENT_LEFT, -1,
			13).x
		draw_string(font, Vector2((rect.size.x - cost_width) * 0.5, rect.size.y - 4),
			cost, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Ui.GOLD_DIM)


class SlotCard extends Control:
	var index = 0
	var plant_id = ""
	var screen = null
	var icon: Texture2D = null

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func set_plant(id: String) -> void:
		plant_id = id
		icon = Ui.sprite(id) if id != "" else null
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT and plant_id != "":
			accept_event()
			screen.toggle_plant(plant_id)

	func _draw() -> void:
		var rect = Rect2(Vector2.ZERO, size)
		if plant_id == "":
			draw_rect(rect, Color(1, 1, 1, 0.04))
			draw_rect(rect, Color(0.3, 0.28, 0.23, 0.6), false, 1.0)
			return
		draw_rect(rect, Color(0.1, 0.15, 0.18, 0.95))
		draw_rect(rect, Ui.GOLD_DIM, false, 1.0)
		Ui.draw_plant_icon(self, plant_id, Rect2(5, 5, rect.size.x - 10,
			rect.size.y - 24))
		var def: Dictionary = Content.PLANTS[plant_id]
		var font = Ui.body_font()
		var text = String(def["name"])
		var width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(font, Vector2((rect.size.x - width) * 0.5, rect.size.y - 8), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Ui.TEXT)
