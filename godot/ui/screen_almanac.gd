## 图鉴：左侧一整块立绘 + 名录，右侧是宽松的书页。
##
## 与上一版的区别：立绘从书页里挪到左栏独占，书页不再被图标挤成窄条，
## 正文可以用满整行；名录改成两列小按钮，十八篇也不占地方。
## 书页里的数值仍全部来自数据表（底细=基础值，本事=按升阶表推导）。
extends Control
const Art = preload("res://ui/market_art.gd")

const TIER_WORDS = ["一阶", "二阶", "三阶"]

var game = null
var tab = "plant"
var index = 0
var _expanded = false           # 进化全表是否展开：默认只给「白板 → 下一级」

var _page: VBoxContainer = null
var _scroll: ScrollContainer = null
var _list_box: VBoxContainer = null
var _portrait: Control = null
var _name_label: Label = null
var _epithet_label: Label = null
var _tag_row: HBoxContainer = null
var _sort_picker: OptionButton
var _section_anchors: Dictionary = {}
var _bookmark_row: HBoxContainer
var _tabs: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop()
	_build_book()


func _backdrop() -> void:
	Art.backdrop(self, Art.ROOT + "menu-ensemble.png", 0.78)


func _build_book() -> void:
	var book := Ui.panel(0.95, Ui.GOLD, 14, 2)
	book.set_anchors_preset(Control.PRESET_CENTER)
	book.anchor_left = 0.5
	book.anchor_right = 0.5
	book.offset_left = -752.0
	book.offset_right = 752.0
	book.anchor_top = 0
	book.anchor_bottom = 1
	book.offset_top = 32
	book.offset_bottom = -32
	add_child(book)
	if game.overlay_from in ["battle", "paused"]:
		preload("res://ui/click_away.gd").attach(self, book, game.close_overlay)
	var outer := Ui.vbox(10)
	book.add_child(outer)

	var head := Ui.hbox(14)
	outer.add_child(head)
	head.add_child(Ui.title("妖怪夜市图鉴", 34, Ui.GOLD_BRIGHT))
	var tabs := Ui.hbox(6)
	head.add_child(tabs)
	for pair in [["plant", "草木志"], ["zombie", "恶客录"], ["boss", "恶首录"]]:
		var button := Ui.button(String(pair[1]), 17, 104, 38)
		button.pressed.connect(_select_tab.bind(String(pair[0])))
		tabs.add_child(button)
		_tabs[String(pair[0])] = button
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var close := Ui.button("合上 (Esc)", 17, 140, 38)
	close.pressed.connect(func():
		if game.overlay_from == "":
			game.show_menu()
		else:
			game.close_overlay())
	var calc_label:=Ui.label("属性计算",15,Ui.TEXT_DIM)
	head.add_child(calc_label)
	var calc:=Ui.button("i",18,36,36)
	calc.name="AttributeInfo";calc.tooltip_text="属性计算方式与举例"
	calc.pressed.connect(_attribute_info);head.add_child(calc)
	head.add_child(close)
	outer.add_child(Ui.hline(Ui.GOLD_DIM, 1.0))

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(body)

	# ── 左栏：立绘 + 名字 + 名录 ──
	var left := Ui.vbox(6)
	left.custom_minimum_size = Vector2(344, 0)
	body.add_child(left)

	var portrait_panel := PanelContainer.new()
	portrait_panel.add_theme_stylebox_override("panel", Art.surface("card", "normal", Vector2(8, 8)))
	left.add_child(portrait_panel)
	_portrait = Control.new()
	_portrait.custom_minimum_size = Vector2(320, 270)
	_portrait.draw.connect(_draw_portrait)
	portrait_panel.add_child(_portrait)

	_name_label = Ui.title("", 32, Ui.GOLD_BRIGHT)
	left.add_child(_name_label)
	_epithet_label = Ui.label("", 15, Ui.TEXT_DIM)
	left.add_child(_epithet_label)
	_tag_row = Ui.hbox(8)
	left.add_child(_tag_row)

	left.add_child(Ui.hline(Color(Ui.GOLD_DIM.r, Ui.GOLD_DIM.g, Ui.GOLD_DIM.b, 0.4),
		1.0))
	_sort_picker = OptionButton.new()
	Ui.apply_button_style(_sort_picker, 16)
	_sort_picker.custom_minimum_size.y = 36
	_sort_picker.item_selected.connect(_change_sort)
	left.add_child(_sort_picker)
	var list_scroll := ScrollContainer.new()
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(list_scroll)
	_list_box = Ui.vbox(3)
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(_list_box)

	# Reading paper and persistent section bookmarks keep the full text accessible.
	var right = Ui.vbox(10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	_bookmark_row = Ui.hbox(8)
	right.add_child(_bookmark_row)
	var page_panel = PanelContainer.new()
	page_panel.add_theme_stylebox_override("panel", Art.surface("paper", "normal", Vector2(24, 22)))
	page_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(page_panel)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE
	page_panel.add_child(_scroll)
	_page = Ui.vbox(14)
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_page)

	_refresh()
	Art.enter(self)


# ── 数据 ────────────────────────────────────────────────────────────────────
func _entries() -> Array:
	if tab == "boss":
		return Almanac.BOSS_ORDER
	return Almanac.plant_entries() if tab == "plant" else Almanac.zombie_entries()


func _current_type() -> String:
	var entries := _entries()
	index = clampi(index, 0, entries.size() - 1)
	return String(entries[index])


func _refresh() -> void:
	for child in _list_box.get_children():
		_list_box.remove_child(child)
		child.queue_free()
	var entries := _entries()
	index = clampi(index, 0, entries.size() - 1)
	var grid := GridContainer.new()
	grid.name = "AlmanacEntryGrid"
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",4)
	grid.add_theme_constant_override("v_separation",2)
	_list_box.add_child(grid)
	_sync_sort_picker()
	for original in _sorted_indices():
		var type := String(entries[original])
		var entry := _entry_row(type, original, original == index)
		entry.set_meta("entry_index",original)
		grid.add_child(entry)
	_update_header()
	_render_page()


## 名录的一行：左边一小张立绘，右边名字与职能——和 v0.2.4 的图鉴一致
func _entry_row(type: String, entry_index: int, active: bool) -> Control:
	var row := Button.new()
	row.custom_minimum_size = Vector2(0, 52)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.toggle_mode = false
	Ui.apply_button_style(row, 16)
	Ui.set_button_active(row, active)
	row.pressed.connect(_select_entry.bind(entry_index))
	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 8.0
	inner.offset_right = -6.0
	row.add_child(inner)
	var thumb := Control.new()
	thumb.custom_minimum_size = Vector2(38, 44)
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb.draw.connect(func():
		_draw_entry_icon(thumb, type, Rect2(Vector2.ZERO, thumb.size)))
	inner.add_child(thumb)
	var texts := Ui.vbox(0)
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_child(texts)
	var name_label := Ui.strong(_entry_short(type), 17,
		Ui.GOLD_BRIGHT if active else Ui.TEXT)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(name_label)
	var role_label := Ui.label(_entry_role(type), 12,
		Ui.TEXT_DIM if active else Ui.TEXT_FAINT)
	role_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(role_label)
	return row


func _entry_short(type: String) -> String:
	if tab == "boss":
		return Almanac.boss_name(type)
	if tab == "plant":
		return String(Content.PLANTS[type]["name"])
	return String(Content.ZOMBIES[type]["name"])


func _entry_role(type: String) -> String:
	if tab == "boss":
		return "关底恶首"
	if tab == "plant":
		return String(Content.PLANTS[type]["role"])
	return Content.tier_label(String(Content.ZOMBIES[type]["tier"]))


func _entry_name(type: String) -> String:
	if tab == "plant":
		return "%s · %s" % [String(Content.PLANTS[type]["name"]),
			String(Content.PLANTS[type]["role"])]
	return "%s · %s" % [String(Content.ZOMBIES[type]["name"]),
		Content.tier_label(String(Content.ZOMBIES[type]["tier"]))]


func _update_header() -> void:
	var type := _current_type()
	for child in _tag_row.get_children():
		child.queue_free()
	if tab == "boss":
		_name_label.text = Almanac.boss_name(type)
		_epithet_label.text = "「%s」" % Almanac.BOSS_PAGES[type][0]
		_tag_row.add_child(_chip("关底恶首", Ui.VERMILION))
		_portrait.queue_redraw()
		return
	var def: Dictionary = Content.PLANTS[type] if tab == "plant" \
		else Content.ZOMBIES[type]
	var text: Dictionary = Almanac.PLANTS[type] if tab == "plant" \
		else Almanac.ZOMBIES[type]
	_name_label.text = String(def["name"])
	_epithet_label.text = "「%s」" % String(text.get("epithet", ""))
	if tab == "plant":
		_tag_row.add_child(_chip(String(def["role"]), Ui.JADE_LIGHT))
		_tag_row.add_child(_chip("香火 %d" % int(def["cost"]), Ui.tone_color("cost")))
		_tag_row.add_child(_chip("冷却 %d 秒" % int(def["cooldown"]),
			Ui.tone_color("time")))
	else:
		var tier := String(def["tier"])
		var tone := "atk" if tier == "h" else ("gold" if tier == "m" else "time")
		_tag_row.add_child(_chip((Ui.tier_symbol(tier) + " " if bool(game.settings.get("tier_shapes", false)) else "") + Content.tier_label(tier), Ui.tone_color(tone)))
		_tag_row.add_child(_chip(String(def["kind"]), Ui.JADE_LIGHT))
		if float(def.get("armor", 0.0)) > 0.0:
			_tag_row.add_child(_chip(String(def["armor_name"]),
				Ui.tone_color("hp")))
	_portrait.queue_redraw()


func _draw_portrait() -> void:
	var type := _current_type()
	var box := Rect2(Vector2(16, 8), _portrait.size - Vector2(32, 20))
	var ring_center = box.get_center() + Vector2(0, 4)
	_portrait.draw_arc(ring_center, 110, 0.3, TAU - 0.3, 80, Color(Art.BRASS, 0.22), 1, true)
	_portrait.draw_arc(ring_center, 104, 0.5, TAU - 0.5, 80, Color(Art.BRASS, 0.12), 1, true)
	Art.corners(_portrait, Rect2(Vector2(7, 7), _portrait.size - Vector2(14, 14)), Color(Art.BRASS, 0.5), 16)
	var center := box.get_center() + Vector2(0, box.size.y * 0.12)
	for i in 4:
		var k := 1.0 - i * 0.22
		_portrait.draw_set_transform(center, 0.0, Vector2(1.0, 0.9))
		_portrait.draw_circle(Vector2.ZERO, box.size.x * 0.42 * k,
			Color(1.0, 0.72, 0.38, 0.035))
		_portrait.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_entry_icon(_portrait, type, box)


func _draw_entry_icon(canvas: Control, type: String, box: Rect2) -> void:
	if tab != "boss":
		Ui.draw_plant_icon(canvas, type, box)
		return
	var portrait := Almanac.boss_portrait(type)
	if portrait != null:
		var size := portrait.get_size()
		size *= minf(box.size.x / size.x, box.size.y / size.y)
		canvas.draw_texture_rect(portrait, Rect2(box.get_center() - size / 2.0, size), false)


# ── 书页 ────────────────────────────────────────────────────────────────────
func _select_tab(key: String) -> void:
	tab = key
	index = 0
	_refresh()


func _select_entry(entry_index: int) -> void:
	index = entry_index
	_refresh()
	if _scroll != null:
		_scroll.scroll_vertical = 0


func _render_page() -> void:
	for child in _page.get_children():
		child.queue_free()
	_section_anchors.clear()
	for key in _tabs: Ui.set_button_active(_tabs[key], key == tab)
	for child in _bookmark_row.get_children():
		_bookmark_row.remove_child(child)
		child.queue_free()
	var bookmarks = ["本事", "进化", "来历"] if tab == "plant" else ["本事", "对策", "来历"]
	for key in bookmarks:
		var button = Ui.button(key, 16, 120, 36)
		button.pressed.connect(_jump_to_section.bind(key))
		_bookmark_row.add_child(button)
	var guide = Ui.label("点题签翻到对应书页", 14, Ui.TEXT_DIM)
	guide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guide.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_bookmark_row.add_child(guide)
	var type := _current_type()
	if tab == "plant":
		_render_plant(type)
	elif tab == "boss":
		var page: Array = Almanac.BOSS_PAGES[type]
		_page.add_child(_section(Almanac.boss_name(type), "本事"))
		_page.add_child(_paragraph("初遇 · %s" % page[1]))
		_page.add_child(_section("迎敌之策", "对策"))
		_page.add_child(_paragraph(String(page[2])))
		_page.add_child(_paragraph("恶首占据相邻两行，两行的射弹都能打中它。留意出招前的红纹和号令，后者会唤来一整大波援军。"))
		_page.add_child(_section("来历", "来历"))
		_page.add_child(_paragraph(Almanac.BOSS_LORE[type] if game.boss_lore_unlocked(type) else "击退这位恶首后，街坊才会向你讲起它的往事。"))
		for skill in Almanac.boss_skills(type):
			_page.add_child(Ui.hline(Ui.GOLD_DIM, 1.0))
			_page.add_child(Ui.strong(String(skill[0]), 22, Ui.GOLD_BRIGHT))
			_page.add_child(_paragraph(String(skill[1])))
	else:
		_render_zombie(type)
	_ink_page(_page)


func _render_plant(type: String) -> void:
	var text: Dictionary = Almanac.PLANTS[type]
	var pitch := Ui.strong(Almanac.plant_pitch(type), 18, Ui.TEXT)
	pitch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pitch.custom_minimum_size = Vector2(940, 0)
	_page.add_child(pitch)
	_page.add_child(_section("底细", "本事"))
	_page.add_child(_stat_grid(Almanac.plant_rows(type)))
	_page.add_child(Ui.strong("本事", 19, Ui.GOLD))
	_page.add_child(_paragraph(Almanac.plant_ability(type)))
	var paths := Upgrades.paths_for(type)
	if not paths.is_empty():
		_page.add_child(_evolve_head())
		for path in paths:
			_page.add_child(_path_block(type, path))
	_page.add_child(_section("来历", "来历"))
	_page.add_child(_paragraph(String(text["story"])))
	var quote := Ui.label("「%s」" % String(text["quote"]), 18, Ui.GOLD_BRIGHT)
	quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page.add_child(quote)


## 进化区标题：默认只给「白板 → 下一级」，全表收起来按需展开
func _evolve_head() -> Control:
	var row := Ui.hbox(10)
	row.add_child(_section("进化 · 三路三级，开启两路，一路至三阶", "进化"))
	var toggle := Ui.button("展开全表" if not _expanded else "收起全表", 15, 112, 32)
	toggle.pressed.connect(func():
		_expanded = not _expanded
		_render_page()
		game.play_sfx("click"))
	row.add_child(toggle)
	return row


func _render_zombie(type: String) -> void:
	var text: Dictionary = Almanac.ZOMBIES[type]
	_page.add_child(_section("底细", "本事"))
	_page.add_child(_stat_grid(Almanac.zombie_rows(type)))
	_page.add_child(Ui.strong("本事", 19, Ui.GOLD))
	_page.add_child(_paragraph(Almanac.zombie_ability(type)))
	_page.add_child(_section("来历", "来历"))
	_page.add_child(_paragraph(String(text["story"])))
	_page.add_child(_section("对策", "对策"))
	_page.add_child(_paragraph(String(text["counter"])))
	_page.add_child(_paragraph("若有恶客绕到攻击草木身后，可用追魂或范围攻击解围；也可铲开它面前的草木，让尚未出手的门神收住这一路。"))
	var quote := Ui.label("「%s」" % String(text["quote"]), 18, Ui.GOLD_BRIGHT)
	quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_page.add_child(quote)


func _chip(text: String, color: Color) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",
		Ui.flat(Color(color.r, color.g, color.b, 0.14), Color(color.r, color.g,
			color.b, 0.5), 6, 1))
	panel.add_child(Ui.label(text, 14, color))
	return panel


func _stat_grid(rows: Array) -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 7)
	for row in rows:
		var key := Ui.label(String(row["label"]), 16, Ui.TEXT_DIM)
		key.custom_minimum_size = Vector2(104, 0)
		grid.add_child(key)
		var value := Ui.label(String(row["value"]), 17,
			Ui.tone_color(String(row["tone"])))
		value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		value.custom_minimum_size = Vector2(700, 0)
		grid.add_child(value)
	return grid


func _paragraph(text: String) -> Control:
	var label := Ui.label(text, 17, Ui.TEXT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(940, 0)
	label.add_theme_constant_override("line_spacing", 9)
	return label


func _path_block(type: String, path: Dictionary) -> Control:
	var panel = PanelContainer.new()
	panel.set_meta("paper_dark", true)
	panel.add_theme_stylebox_override("panel", Art.surface("card", "normal", Vector2(18, 14)))
	var box = Ui.vbox(9)
	panel.add_child(box)
	var header = Ui.hbox(14)
	box.add_child(header)
	var route = Ui.vbox(4)
	route.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(route)
	route.add_child(Ui.strong(String(path.name), 22, Ui.GOLD_BRIGHT))
	var progress = Control.new()
	progress.custom_minimum_size = Vector2(200, 22)
	progress.draw.connect(func():
		progress.draw_line(Vector2(12, 11), Vector2(156, 11), Color(Ui.GOLD_DIM, 0.6), 1, true)
		for i in 3:
			Art.diamond(progress, Vector2(12 + i * 72, 11), 5, Ui.GOLD, i == 0)
			progress.draw_string(Ui.body_font(), Vector2(24 + i * 72, 16), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Ui.TEXT_DIM))
	route.add_child(progress)
	var portrait = TextureRect.new()
	portrait.texture = Ui.capstone_sprite(type, int(path.id))
	portrait.set_meta("capstone_actor", "%s-e%d" % [type, int(path.id)])
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(110, 100)
	portrait.tooltip_text = "三阶形态"
	header.add_child(portrait)
	var skill:Dictionary=preload("res://data/active_skills.gd").definition(type)
	if not skill.is_empty() and int(skill.path)==int(path.id):
		var icon:=TextureRect.new();icon.texture=load(skill.icon);icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;icon.custom_minimum_size=Vector2(60,60)
		icon.tooltip_text=("唯一 · " if skill.unique else "主动 · ")+String(skill.name);header.add_child(icon)
	var tiers: Array = path.tiers
	var shown = tiers.size() if _expanded else mini(1, tiers.size())
	for i in shown:
		var row = Ui.hbox(12)
		box.add_child(row)
		var step = Ui.strong("%s · %s" % [TIER_WORDS[i], String(tiers[i].name)], 17, Ui.TEXT)
		step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(step)
		row.add_child(Ui.label("%d 香火" % Upgrades.tier_cost(type, int(path.id), i + 1), 17, Ui.GOLD_BRIGHT))
		var desc = Ui.label(String(tiers[i].desc), 16, Ui.TEXT_DIM)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(desc)
	if not _expanded and tiers.size() > 1:
		var names = PackedStringArray()
		for i in range(1, tiers.size()): names.append(String(tiers[i].name))
		box.add_child(Ui.label("后续：" + " → ".join(names), 14, Ui.TEXT_FAINT))
	return panel

func _section(caption: String, key: String) -> Label:
	var label = Ui.strong(caption, 21, Ui.GOLD)
	if not _section_anchors.has(key): _section_anchors[key] = label
	return label

func _jump_to_section(key: String) -> void:
	if not _section_anchors.has(key): return
	var target: Control = _section_anchors[key]
	var y = target.get_global_rect().position.y - _page.get_global_rect().position.y
	if Art.reduced_motion: _scroll.scroll_vertical = maxi(0, int(y) - 6)
	else: create_tween().tween_property(_scroll, "scroll_vertical", maxi(0, int(y) - 6), 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	game.play_sfx("click")

func _ink_page(node: Node) -> void:
	if node.has_meta("paper_dark"): return
	if node is Label:
		var color = Color("#3e3024")
		if node.get_theme_font_size("font_size") >= 20: color = Color("#713d28")
		elif node.get_theme_font_size("font_size") <= 15: color = Color("#6e5a40")
		node.add_theme_color_override("font_color", color)
	for child in node.get_children(): _ink_page(child)

func _sort_key() -> String:
	return "almanac_plant_order" if tab == "plant" else "almanac_guest_order"


func _sync_sort_picker() -> void:
	_sort_picker.clear()
	_sort_picker.add_item("按发布顺序")
	_sort_picker.add_item("按草木类型" if tab == "plant" else "按阶级 · 低—中—高")
	_sort_picker.visible = tab != "boss"
	_sort_picker.select(1 if String(game.settings.get(_sort_key(), "release")) == "category" else 0)


func _change_sort(choice: int) -> void:
	game.set_setting(_sort_key(), "category" if choice == 1 else "release")
	_refresh()


func _sorted_indices() -> Array:
	var entries := _entries()
	var result: Array = range(entries.size())
	if tab == "boss" or String(game.settings.get(_sort_key(), "release")) == "release":
		return result
	var roles := ["产能","射弹","群攻","近战","防御","辅助","灰烬"]
	result.sort_custom(func(a, b):
		var left := 0
		var right := 0
		if tab == "zombie":
			left = ["l", "m", "h"].find(Content.ZOMBIES[entries[a]].tier)
			right = ["l", "m", "h"].find(Content.ZOMBIES[entries[b]].tier)
		else:
			left = roles.find(String(Content.PLANTS[entries[a]].role))
			right = roles.find(String(Content.PLANTS[entries[b]].role))
			if left < 0: left = roles.size()
			if right < 0: right = roles.size()
		return int(a) < int(b) if left == right else left < right)
	return result

func _attribute_info() -> void:
	var dialog:=AcceptDialog.new();dialog.name="AttributeCalculation";dialog.title="属性计算";Ui.style_dialog(dialog)
	dialog.dialog_text=preload("res://data/attribute_rules.gd").explanation()
	dialog.min_size=Vector2i(840,600);dialog.get_label().autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	dialog.get_label().add_theme_font_size_override("font_size",20)
	dialog.get_ok_button().text="明白了";add_child(dialog);dialog.popup_centered(Vector2i(880,640))
	dialog.confirmed.connect(dialog.queue_free);dialog.canceled.connect(dialog.queue_free)
