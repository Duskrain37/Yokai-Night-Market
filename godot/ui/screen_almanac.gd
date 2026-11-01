## 图鉴：草木志十八篇、恶客录十二篇。左侧名录，右侧书页。
##
## 书页里的数值全部来自 data/ 下的数据表（底细=基础数值，本事=按升阶表推导），
## 所以改了数值，图鉴不会继续说谎——v0.2.4 的图鉴与代码是两份手抄稿，曾因此不符。
extends Control

var game = null
var tab = "plant"
var index = 0

var _list_box: VBoxContainer = null
var _page: VBoxContainer = null
var _scroll: ScrollContainer = null
var _tab_buttons: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop()
	_build_book()


func _backdrop() -> void:
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
	var fill = ColorRect.new()
	fill.color = Color(0.02, 0.04, 0.06, 0.86)
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fill)
	var paper = ColorRect.new()
	paper.color = Color(0.09, 0.07, 0.05, 0.5)
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(paper)


func _build_book() -> void:
	var book = Ui.panel(0.95, Ui.GOLD, 14, 2)
	book.set_anchors_preset(Control.PRESET_CENTER)
	book.anchor_left = 0.5
	book.anchor_right = 0.5
	book.offset_left = -700.0
	book.offset_right = 700.0
	book.offset_top = -400.0
	book.offset_bottom = 400.0
	add_child(book)
	var outer = Ui.vbox(10)
	book.add_child(outer)

	var head = Ui.hbox(14)
	outer.add_child(head)
	head.add_child(Ui.title("妖怪夜市图鉴", 36, Ui.GOLD_BRIGHT))
	var tabs = Ui.hbox(6)
	head.add_child(tabs)
	for pair in [["plant", "草木志"], ["zombie", "恶客录"]]:
		var button = Ui.button(String(pair[1]), 18, 110, 40)
		button.pressed.connect(func():
			tab = String(pair[0])
			index = 0
			_refresh())
		tabs.add_child(button)
		_tab_buttons[String(pair[0])] = button
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var close = Ui.button("合上 (Esc)", 17, 140, 40)
	close.pressed.connect(func():
		if game.overlay_from == "":
			game.show_menu()
		else:
			game.close_overlay())
	head.add_child(close)

	var body = HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(body)

	var list_panel = Ui.panel(0.55, Ui.GOLD_DIM, 10)
	list_panel.custom_minimum_size = Vector2(300, 0)
	body.add_child(list_panel)
	var list_scroll = ScrollContainer.new()
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_panel.add_child(list_scroll)
	_list_box = Ui.vbox(4)
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(_list_box)

	var page_panel = Ui.panel(0.55, Ui.GOLD_DIM, 10)
	page_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(page_panel)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page_panel.add_child(_scroll)
	_page = Ui.vbox(10)
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_page)

	_refresh()


func _refresh() -> void:
	for key in _tab_buttons:
		var button: Button = _tab_buttons[key]
		button.add_theme_color_override("font_color",
			Ui.GOLD_BRIGHT if key == tab else Ui.TEXT_DIM)
	for child in _list_box.get_children():
		child.queue_free()
	var entries: Array = Almanac.plant_entries() if tab == "plant" \
		else Almanac.zombie_entries()
	for i in entries.size():
		var type = String(entries[i])
		var button = Ui.button(_entry_name(type), 17, 264, 38)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if i == index:
			button.add_theme_color_override("font_color", Ui.GOLD_BRIGHT)
		button.pressed.connect(func():
			index = i
			_refresh()
			_scroll.scroll_vertical = 0)
		_list_box.add_child(button)
	_render_page(entries)


func _entry_name(type: String) -> String:
	if tab == "plant":
		var def: Dictionary = Content.PLANTS[type]
		return "　%s · %s" % [String(def["name"]), String(def["role"])]
	var def: Dictionary = Content.ZOMBIES[type]
	return "　%s · %s" % [String(def["name"]), Content.tier_label(String(def["tier"]))]


func _render_page(entries: Array) -> void:
	for child in _page.get_children():
		child.queue_free()
	if index < 0 or index >= entries.size():
		index = 0
	var type = String(entries[index])
	if tab == "plant":
		_render_plant(type)
	else:
		_render_zombie(type)


func _render_plant(type: String) -> void:
	var def: Dictionary = Content.PLANTS[type]
	var text: Dictionary = Almanac.PLANTS[type]
	var head = HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	_page.add_child(head)
	head.add_child(_icon_node(type, Vector2(132, 168)))
	var title_col = Ui.vbox(4)
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_col)
	title_col.add_child(Ui.title(String(def["name"]), 44, Ui.GOLD_BRIGHT))
	title_col.add_child(Ui.label("「%s」" % String(text["epithet"]), 18, Ui.TEXT_DIM))
	var tags = Ui.hbox(10)
	title_col.add_child(tags)
	tags.add_child(_chip(String(def["role"]), Ui.JADE_LIGHT))
	tags.add_child(_chip("香火 %d" % int(def["cost"]), Ui.tone_color("cost")))
	tags.add_child(_chip("冷却 %d 秒" % int(def["cooldown"]), Ui.tone_color("time")))
	_page.add_child(Ui.hline(Ui.GOLD_DIM, 1.0))
	_page.add_child(Ui.strong("底细", 20, Ui.GOLD))
	_page.add_child(_stat_grid(Almanac.plant_rows(type)))
	_page.add_child(Ui.strong("本事", 20, Ui.GOLD))
	_page.add_child(_paragraph(Almanac.plant_ability(type)))
	var paths = Upgrades.paths_for(type)
	if not paths.is_empty():
		_page.add_child(Ui.strong("进化 · 三路三级，只能走两条，只有一条能到三级", 20, Ui.GOLD))
		for path in paths:
			_page.add_child(_path_block(type, path))
	_page.add_child(Ui.strong("来历", 20, Ui.GOLD))
	_page.add_child(_paragraph(String(text["story"])))
	var quote = Ui.label("「%s」" % String(text["quote"]), 19, Ui.GOLD_BRIGHT)
	quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page.add_child(quote)


func _render_zombie(type: String) -> void:
	var def: Dictionary = Content.ZOMBIES[type]
	var text: Dictionary = Almanac.ZOMBIES[type]
	var head = HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	_page.add_child(head)
	head.add_child(_icon_node(type, Vector2(132, 168)))
	var title_col = Ui.vbox(4)
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_col)
	title_col.add_child(Ui.title(String(def["name"]), 44, Ui.GOLD_BRIGHT))
	title_col.add_child(Ui.label("「%s」" % String(text["epithet"]), 18, Ui.TEXT_DIM))
	var tags = Ui.hbox(10)
	title_col.add_child(tags)
	var tier = String(def["tier"])
	var tier_tone = "atk" if tier == "h" else ("gold" if tier == "m" else "time")
	tags.add_child(_chip(Content.tier_label(tier), Ui.tone_color(tier_tone)))
	tags.add_child(_chip(String(def["kind"]), Ui.JADE_LIGHT))
	if bool(def.get("large", false)):
		tags.add_child(_chip("大型", Ui.tone_color("atk")))
	_page.add_child(Ui.hline(Ui.GOLD_DIM, 1.0))
	_page.add_child(Ui.strong("底细", 20, Ui.GOLD))
	_page.add_child(_stat_grid(Almanac.zombie_rows(type)))
	_page.add_child(Ui.strong("本事", 20, Ui.GOLD))
	_page.add_child(_paragraph(Almanac.zombie_ability(type)))
	_page.add_child(Ui.strong("来历", 20, Ui.GOLD))
	_page.add_child(_paragraph(String(text["story"])))
	_page.add_child(Ui.strong("对策", 20, Ui.GOLD))
	_page.add_child(_paragraph(String(text["counter"])))
	var quote = Ui.label("「%s」" % String(text["quote"]), 19, Ui.GOLD_BRIGHT)
	quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page.add_child(quote)


func _icon_node(type: String, box: Vector2) -> Control:
	var holder = Control.new()
	holder.custom_minimum_size = box
	holder.size = box
	holder.draw.connect(func():
		Ui.draw_plant_icon(holder, type, Rect2(Vector2.ZERO, box)))
	return holder


func _chip(text: String, color: Color) -> Control:
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel",
		Ui.flat(Color(color.r, color.g, color.b, 0.14), Color(color.r, color.g, color.b,
			0.5), 6, 1))
	var label = Ui.label(text, 15, color)
	label.add_theme_constant_override("outline_size", 0)
	panel.add_child(label)
	return panel


func _stat_grid(rows: Array) -> Control:
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 6)
	for row in rows:
		var key = Ui.label(String(row["label"]), 16, Ui.TEXT_DIM)
		key.custom_minimum_size = Vector2(96, 0)
		grid.add_child(key)
		var value = Ui.label(String(row["value"]), 17, Ui.tone_color(
			String(row["tone"])))
		value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		value.custom_minimum_size = Vector2(420, 0)
		grid.add_child(value)
	return grid


func _paragraph(text: String) -> Control:
	var label = Ui.label(text, 18, Ui.TEXT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(880, 0)
	label.add_theme_constant_override("line_spacing", 8)
	return label


func _path_block(type: String, path: Dictionary) -> Control:
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)
	var dot = ColorRect.new()
	dot.color = Color(String(path["color"]))
	dot.custom_minimum_size = Vector2(10, 10)
	header.add_child(dot)
	header.add_child(Ui.strong("%s 路" % String(path["name"]), 17, Ui.TEXT))
	var tiers: Array = path["tiers"]
	var line = ""
	for i in tiers.size():
		var cost = Upgrades.tier_cost(type, int(path["id"]), i + 1)
		line += "%d. %s（%d）　" % [i + 1, String(tiers[i]["name"]), cost]
	var desc = ""
	for i in tiers.size():
		desc += String(tiers[i]["desc"])
		if i < tiers.size() - 1:
			desc += "／"
	var label = Ui.label(line.strip_edges(), 15, Ui.TEXT_DIM)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(880, 0)
	box.add_child(label)
	var desc_label = Ui.label(desc, 15, Ui.TEXT_FAINT)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.custom_minimum_size = Vector2(880, 0)
	box.add_child(desc_label)
	return box
