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
var _fix_row: HBoxContainer = null
var _producer_warning: ConfirmationDialog = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_picked = Array(game.prep.get("selected", [])).duplicate()
	if _picked.is_empty():
		_picked = game.loadout.duplicate()
	_backdrop()
	_header()
	_roster()
	_slots()
	game.play_music_scene("menu")
	# 进入备战先放镜头：镜头期间整页隐形、不抢点击
	_play_cinema()


## v0.2.4 的备战镜头：推镜 → 报幕 → 恶客列队 → 淡入备战页。
func _play_cinema() -> void:
	var level: Dictionary = _level()
	var cinema := PrepCinema.new()
	cinema.level = level
	cinema.zombie_types = Content.plants_in_level(level)
	for child in get_children():
		if child == cinema:
			continue
		child.visible = false
	add_child(cinema)
	cinema.finished.connect(func(): _reveal_after_cinema())


## QA 截图不等开场镜头
func skip_cinema() -> void:
	for child in get_children():
		if child is PrepCinema:
			child.queue_free()
	_reveal_after_cinema()


func _reveal_after_cinema() -> void:
	for child in get_children():
		if child is PrepCinema:
			continue
		child.visible = true
		child.modulate.a = 0.0
		create_tween().tween_property(child, "modulate:a", 1.0, 0.45)


func _level() -> Dictionary:
	return game.prep.get("level", Content.get_level(1))


func _backdrop() -> void:
	var fill = ColorRect.new()
	fill.color = Ui.INK
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fill)
	var file := Content.map_picture(_level(), true)
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
	var detail = "%s·%s · %s · %d 大波 · 三星：一夜不动用门神" % [
		level["day_name"],level["day_sub"],level["tag"],Content.wave_groups(level)]
	if bool(level.get("special",false)):
		detail="二十大波 · 每四波后迎战一位恶首 · 阵容与香火保留，越往里越凶险"
	var danger_label=Ui.label("今夜凶险",16,Ui.TEXT_DIM)
	danger_label.position=Vector2(1070,103);add_child(danger_label)
	var danger=preload("res://ui/threat_meter.gd").new()
	danger.position=Vector2(1180,108);danger.size=Vector2(330,16)
	danger.values=Content.SPECIAL_THREATS if bool(level.get("special",false)) else [float(level.threat)]
	add_child(danger)
	if training:
		detail = "训练场 · %s·%s · 不刷波次、不判负、起手 1000 香火" % [
			level["day_name"], level["day_sub"]]
	var sub = Ui.label(detail, 18, Ui.TEXT_DIM)
	sub.position = Vector2(100, 148)
	add_child(sub)
	# 三夜样板：这一夜只练一件事，写在右上角的暗底题签上
	var theme := String(level.get("theme", ""))
	if theme != "":
		var plate := PanelContainer.new()
		plate.position = Vector2(742, 20)
		plate.custom_minimum_size = Vector2(800, 0)
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.add_theme_stylebox_override("panel", Ui.flat(
			Color(0.05, 0.06, 0.08, 0.8), Color(Ui.VERMILION.r, Ui.VERMILION.g,
				Ui.VERMILION.b, 0.55), 8, 1))
		var row := Ui.hbox(10)
		plate.add_child(row)
		row.add_child(Ui.seal("题", 30.0))
		var line := Ui.strong(theme, 17, Color(0.96, 0.9, 0.78))
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size = Vector2(720, 0)
		row.add_child(line)
		add_child(plate)
	var rule = ColorRect.new()
	rule.color = Color(Ui.GOLD_DIM.r, Ui.GOLD_DIM.g, Ui.GOLD_DIM.b, 0.6)
	rule.position = Vector2(100, 182)
	rule.size = Vector2(1400, 1)
	add_child(rule)


func _roster() -> void:
	var panel = Ui.panel(0.88)
	panel.position = Vector2(56, 200)
	panel.size = Vector2(1010, 660)
	add_child(panel)
	var box = Ui.vbox(8)
	panel.add_child(box)
	var head = Ui.hbox(12)
	box.add_child(head)
	head.add_child(Ui.strong("草木名册", 22, Ui.GOLD))
	head.add_child(Ui.label("滚动翻阅，点选或取下，一局最多十张。", 15, Ui.TEXT_DIM))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var grid = GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	_roster_nodes.clear()
	for type in Content.PLANT_ORDER:
		var card = PlantPickCard.new()
		card.plant_id = String(type)
		card.screen = self
		card.custom_minimum_size = Vector2(151, 174)
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
	# Keep the launch controls inside the viewport even with all enemy types + water warning.
	var scroll=ScrollContainer.new()
	scroll.custom_minimum_size=Vector2(0,140)
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_RESERVE
	box.add_child(scroll)
	var details=Ui.vbox(6)
	details.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	scroll.add_child(details)
	_warning = Ui.label("", 16, Ui.WARN)
	_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warning.custom_minimum_size = Vector2(0, 40)
	details.add_child(_warning)
	# 水路忘带夜莲时的补救：一行按钮，只在真的缺的时候露出来
	_fix_row = Ui.hbox(8)
	details.add_child(_fix_row)
	var fix = Ui.button("把夜莲换进来", 16, 0, 38)
	fix.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fix.pressed.connect(_swap_in_lily)
	_fix_row.add_child(fix)
	details.add_child(Ui.hline(Ui.GOLD_DIM, 1.0))
	details.add_child(Ui.label("今夜恶客 · 滚动翻阅", 17, Ui.GOLD))
	var enemies = Ui.vbox(2)
	details.add_child(enemies)
	var seen = Content.plants_in_level(_level())
	var level = _level()
	var bosses: Array = level.get("boss_checkpoints", [])
	if String(level.get("boss_id", "")) != "":
		bosses = [level["boss_id"]]
		if String(level.get("mid_boss", "")) != "":
			bosses.push_front(level["mid_boss"])
	seen = bosses.map(func(id): return "boss-" + String(id)) + seen
	var debut_prefix = "%s·%s" % [String(level["day_name"]), String(level["name"])]
	var strip = FlowContainer.new()
	strip.add_theme_constant_override("h_separation", 6)
	strip.add_theme_constant_override("v_separation", 6)
	strip.custom_minimum_size = Vector2(0, 0)
	strip.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	enemies.add_child(strip)
	for type in seen:
		var chip = EnemyChip.new()
		chip.zombie_id = String(type)
		chip.fresh = String(Content.first_appearance(String(type))) \
			.begins_with(debut_prefix)
		chip.screen = self
		strip.add_child(chip)
	if seen.is_empty():
		enemies.add_child(Ui.label("今夜没有新客", 15, Ui.TEXT_DIM))
	details.add_child(Ui.spacer(4))
	# 三枚小键等宽铺满一行；开战钉在面板底部，中间留白由弹性空隙吃掉
	var actions = Ui.hbox(10)
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(actions)
	var auto = Ui.button("按今夜推荐配卡", 16, 0, 40)
	auto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	auto.pressed.connect(func(): _auto_pick())
	actions.add_child(auto)
	var clear = Ui.button("清空", 16, 0, 40)
	clear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear.pressed.connect(func():
		_picked.clear()
		_refresh())
	actions.add_child(clear)
	var almanac = Ui.button("图鉴", 16, 0, 40)
	almanac.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	almanac.pressed.connect(func(): game.open_almanac("plant", 0))
	actions.add_child(almanac)
	if String(game.settings.difficulty)=="nightmare" and not bool(game.prep.get("training",false)):
		var factors:=Ui.button("",18,0,42)
		factors.name="NightmareFactors"
		factors.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		var update:=func():
			var rules=preload("res://data/nightmare.gd")
			factors.text="噩梦因子 · %d  ›" % rules.points(rules.sanitize(Dictionary(game.settings.get("nightmare_factors",{})),_level()))
		update.call()
		factors.pressed.connect(func():
			var dialog=load("res://ui/nightmare_panel.gd").new()
			dialog.game=game;dialog.level=_level();dialog.on_changed=update
			add_child(dialog);dialog.popup_centered()
			dialog.confirmed.connect(dialog.queue_free);dialog.canceled.connect(dialog.queue_free))
		box.add_child(factors)
	var start = Ui.button("开战" if not bool(game.prep.get("training", false)) else "进训练场",
		22, 0, 58, true)
	start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start.pressed.connect(func(): _start())
	box.add_child(start)
	_refresh()


func _auto_pick() -> void:
	# 推荐顺序随地图：水路自带夜莲，河埠口多带抛物线与跨行
	var tips: Array = Content.night_loadout_tips(_level())
	_picked.clear()
	for type in tips:
		if Content.PLANTS.has(type) and _picked.size() < 10:
			_picked.append(type)
	for type in Content.PLANT_ORDER:
		if _picked.size() >= 10:
			break
		if not _picked.has(type):
			_picked.append(type)
	_refresh()
	game.play_sfx("click")


## 水路没带夜莲：把它换进来，满了就顶掉这张地图最不该带的那张
func _swap_in_lily() -> void:
	if _picked.has("lily"):
		return
	var map := String(_level()["map"])
	if _picked.size() >= 10:
		var worst := 0
		for i in _picked.size():
			if String(_picked[i]) == "lily":
				continue
			if Content.tip_rank(map, String(_picked[i])) \
					> Content.tip_rank(map, String(_picked[worst])):
				worst = i
		_picked.remove_at(worst)
	_picked.insert(0, "lily")
	_refresh()
	game.play_sfx("click")


## 备战页点恶客头像 → 直接翻到它那一页图鉴。
func open_zombie_almanac(id: String) -> void:
	var boss_index := Almanac.BOSS_ORDER.find(id.trim_prefix("boss-")) if id.begins_with("boss-") else -1
	if boss_index >= 0:
		game.open_almanac("boss", boss_index)
		return
	var index = Content.ZOMBIE_ORDER.find(id)
	if index >= 0 and game != null:
		game.open_almanac("zombie", index)


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
		elif _needs_lily():
			_warning.text = "水面要先放夜莲。\n当前卡组没有夜莲，可用下方按钮换入。"
		elif _picked.size() > 10:
			_warning.text = "卡组超出十张。"
		else:
			_warning.text = ""
		if _level().get("water_rows", []).is_empty():
			var dry := PackedStringArray()
			for type in _picked:
				var def: Dictionary = Content.PLANTS[type]
				if bool(def.get("lily", false)) or bool(def.get("water_only", false)):
					dry.append(String(def.name))
			if not dry.is_empty():
				_warning.text = (_warning.text + "\n" if not _warning.text.is_empty() else "") \
					+ "今夜没有水格，%s无处可种。" % "、".join(dry)
		if _level().get("map", "") == "cavern":
			_warning.text = (_warning.text + "\n" if not _warning.text.is_empty() else "") \
				+ "断台上的坑洞留不住草木。开战后可在卡槽查看哪些牌暂无落点。"
	if _fix_row != null:
		_fix_row.visible = _needs_lily()


func _needs_lily() -> bool:
	return not _level().get("water_rows", []).is_empty() and not _picked.has("lily")


func _has_producer() -> bool:
	for type in _picked:
		if Content.PLANTS[type].has("produce") or Content.PLANTS[type].has("till"):
			return true
	return false


func _start() -> void:
	if _picked.is_empty():
		_warning.text = "先选至少一株草木。"
		game.play_sfx("deny")
		return
	if not _has_producer():
		if _producer_warning == null:
			_producer_warning = ConfirmationDialog.new()
			_producer_warning.title = "缺少香火草木"
			_producer_warning.dialog_text = "这套草木没有能产香火的，开战后只能等天上掉落。确定仍要开战吗？"
			_producer_warning.ok_button_text = "仍要开战"
			_producer_warning.cancel_button_text = "回去选草"
			_producer_warning.confirmed.connect(_launch)
			add_child(_producer_warning)
		_producer_warning.popup_centered(Vector2i(480, 180))
		game.play_sfx("deny")
		return
	_launch()


func _launch() -> void:
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
		Ui.draw_plate(self, rect, base, Ui.GOLD if chosen else Color(0.32, 0.29, 0.24, 0.9),
			14, 2 if chosen else 1)
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
			Ui.draw_plate(self, rect, Color(1, 1, 1, 0.04), Color(0.3, 0.28, 0.23, 0.6), 12, 1)
			return
		Ui.draw_plate(self, rect, Color(0.1, 0.15, 0.18, 0.95), Ui.GOLD_DIM, 12, 1)
		Ui.draw_plant_icon(self, plant_id, Rect2(5, 5, rect.size.x - 10,
			rect.size.y - 24))
		var def: Dictionary = Content.PLANTS[plant_id]
		var font = Ui.body_font()
		var text = String(def["name"])
		var width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string(font, Vector2((rect.size.x - width) * 0.5, rect.size.y - 8), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Ui.TEXT)


## 今夜恶客的一枚头像牌：立绘、名字、阶级色点；首遇的挂「新」，点开进图鉴。
class EnemyChip:
	extends Control
	var zombie_id := ""
	var fresh := false
	var screen = null
	var _hovered := false

	func _ready() -> void:
		custom_minimum_size = Vector2(126 if zombie_id.begins_with("boss-magistrate-") else 62, 54)
		size = custom_minimum_size
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			var now_hovered := get_rect().has_point(event.position)
			if now_hovered != _hovered:
				_hovered = now_hovered
				queue_redraw()
		elif event is InputEventMouseButton and event.pressed 				and event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			if screen != null:
				screen.open_zombie_almanac(zombie_id)

	func _draw() -> void:
		var boss := zombie_id.begins_with("boss-")
		var boss_id := zombie_id.trim_prefix("boss-")
		var def: Dictionary = Content.ZOMBIES.get(zombie_id, {})
		var rect := Rect2(Vector2.ZERO, size)
		var fill := Color(0.23, 0.12, 0.09, 0.92) if boss else Color(0.09, 0.11, 0.13, 0.86)
		var edge := Ui.GOLD if boss else Color(0.34, 0.30, 0.22, 0.9)
		Ui.draw_plate(self, rect, fill, Ui.GOLD_BRIGHT if _hovered else edge, 12, 1)
		var icon := Rect2((size.x - 44) * 0.5, 3, 44, 32)
		var texture := Almanac.boss_portrait(boss_id) if boss else Ui.sprite(zombie_id)
		if texture != null:
			var tex_size := texture.get_size()
			var scale := minf(icon.size.x / tex_size.x, icon.size.y / tex_size.y)
			var drawn := tex_size * scale
			draw_texture_rect(texture, Rect2(icon.position + (icon.size - drawn) * 0.5,
				drawn), false)
		var font = Ui.body_font()
		var label = Almanac.boss_name(boss_id) if boss else String(def["name"])
		var width = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(font, Vector2((size.x - width) * 0.5, size.y - 6.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Ui.TEXT if _hovered else Ui.TEXT_DIM)
		var tier: Dictionary = Content.TIERS.get(String(def.get("tier", "l")), {})
		var color := Ui.VERMILION if boss else Color(String(tier.get("color", "#7f9d7a")))
		if not boss and screen != null and bool(screen.game.settings.get("tier_shapes", false)):
			Ui.draw_tier_shape(self, String(def.get("tier", "l")), Vector2(size.x - 9.0, 9.0), color)
		else:
			draw_circle(Vector2(size.x - 9.0, 9.0), 4.0, color)
		if fresh:
			Ui.draw_plate(self, Rect2(2, 2, 17, 14), Color(0.72, 0.24, 0.18, 0.95), Color.TRANSPARENT, 7, 0)
			draw_string(font, Vector2(4.5, 13.5), "新", HORIZONTAL_ALIGNMENT_LEFT, -1,
				11, Color(1, 0.96, 0.88))
