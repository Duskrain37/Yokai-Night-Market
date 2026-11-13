## 局内界面：香火、卡槽、唤波/铲子/作弊/暂停、升阶面板、教学引导、暂停与结算。
##
## 与 v0.2.4 的布局差异（本轮的美术与排版优化）：
##  * 香火与波次放在左侧竖栏，工具按钮放在右侧竖栏，棋盘居中不遮不挡；
##  * 升阶从扇形菜单改为贴着草木的信息卡，三路状态、费用、锁定原因一屏读完；
##  * 所有数值（含教学文案里的升阶费用）都从数据表取，不再写死。
extends Control
const Art = preload("res://ui/market_art.gd")

var game = null
var result_mode = false
var pause_mode_ui = false
var won = false
var result: Dictionary = {}

var card_selected = -1
var shovel_mode = false
var focus_plant = null
var cheat_open = false
var cheat_tab = "misc"
var spawn_type = "ghost"
var spawn_count = 1
var spawn_lane = -1
var _hover_card = -1

var _factor_label: Label = null
var _sun_label: Label = null
var _wave_label: Label = null
var _hint_label: Label = null
var _banner_label: Label = null
var _banner_sub: Label = null
var _banner_band: ColorRect = null
var _banner_t = 0.0
var _card_nodes: Array = []
var _tool_wave: Button = null
var _tool_shovel: Button = null
var _shovel_cursor: Image = null
var _tool_cheat: Button = null
var _fan: UpgradeFan = null
var _shell_panel: PanelContainer
var _shell_host = null
var _shell_value: Label
var _fan_sig = ""
var _fan_rows: Array = []
var _cheat_panel: PanelContainer = null
var _tutorial_panel: PanelContainer = null
var _tutorial_label: Label = null
var _tutorial_dots: Control = null
var _tutorial_almanac: Button = null
var _tutorial_help: Button = null
var _wave_pips: Control = null
var _danger: Control = null
var _tooltip: Label = null
var _speed_pills: Array = []
var _placement_signature := Vector4i(-1, -1, -1, -1)
var _placement_warnings: Dictionary = {}

const SPEEDS = [0.1, 1.0, 1.5, 2.0, 3.0]
# 所有模式常驻慢放档，正式局不记作作弊。
const SPEEDS_TRAINING = SPEEDS


static func _speed_text(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return str(int(round(value)))
	return String.num(value, 1)


## 局内直接切速度：写回设置，下次开局沿用
func _set_speed(value: float) -> void:
	if game == null:
		return
	game.apply_speed(value)
	game.set_setting("speed", value)
	game.play_sfx("click")
	refresh()


func step_speed(direction: int) -> void:
	var choices: Array = SPEEDS_TRAINING if game.speed_floor() < 1.0 else SPEEDS
	var current := choices.find(game.speed)
	_set_speed(float(choices[clampi(current + direction, 0, choices.size() - 1)]))


func _refresh_speed_pills() -> void:
	for pill in _speed_pills:
		Ui.set_button_active(pill, is_equal_approx(game.speed, float(pill.get_meta("speed_value"))))
		pill.disabled = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if result_mode:
		_build_result()
		return
	if pause_mode_ui:
		_build_pause()
		return
	_build_hud()
	refresh()


# ── 主 HUD ──────────────────────────────────────────────────────────────────
func _build_hud() -> void:
	var sim: Sim = game.sim
	if not game.mobile:
		var furniture = Control.new()
		furniture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		furniture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		furniture.draw.connect(func():
			furniture.draw_style_box(Art.surface("panel", "normal", Vector2.ZERO), Rect2(14, 12, 270, 190))
			var tray_width = minf(986, sim.cards.size() * 79 + 15)
			furniture.draw_style_box(Art.surface("panel", "normal", Vector2.ZERO), Rect2(294 + (986 - tray_width) / 2, 12, tray_width, 132))
			furniture.draw_style_box(Art.surface("panel", "normal", Vector2.ZERO), Rect2(1290, 12, 196, 78)))
		add_child(furniture)
	# 左侧经济栏
	var left = VBoxContainer.new()
	left.position = Vector2(26, 22)
	left.add_theme_constant_override("separation", 10)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(left)

	var sun_row = HBoxContainer.new()
	sun_row.add_theme_constant_override("separation", 10)
	left.add_child(sun_row)
	var sun_seal = Control.new()
	sun_seal.custom_minimum_size = Vector2(76, 76)
	sun_seal.size = Vector2(76, 76)
	sun_row.add_child(sun_seal)
	var seal_panel = Panel.new()
	seal_panel.add_theme_stylebox_override("panel",
		Ui.flat(Color(0.05, 0.09, 0.11, 0.86), Ui.GOLD_DIM, 38, 2))
	seal_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	sun_seal.add_child(seal_panel)
	_sun_label = Ui.strong("225", 26, Ui.GOLD_BRIGHT)
	_sun_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sun_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sun_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	sun_seal.add_child(_sun_label)

	var sun_text = Ui.vbox(0)
	sun_row.add_child(sun_text)
	sun_text.add_child(Ui.label("香火", 18, Ui.TEXT_DIM))
	_wave_label = Ui.label("第 1 / 4 大波", 17, Ui.TEXT)
	sun_text.add_child(_wave_label)

	_danger=preload("res://ui/threat_meter.gd").new()
	_danger.custom_minimum_size=Vector2(112,16)
	left.add_child(_danger)

	_wave_pips = Control.new()
	_wave_pips.custom_minimum_size = Vector2(258, 53)
	_wave_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave_pips.draw.connect(_draw_wave_pips)
	left.add_child(_wave_pips)

	# 建议压在灯笼与屋檐上会看不清：给一块窄暗底，字用亮色
	var hint_plate = PanelContainer.new()
	hint_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_plate.add_theme_stylebox_override("panel", Ui.flat(
		Color(0.05, 0.06, 0.08, 0.62), Color(Ui.GOLD_DIM.r, Ui.GOLD_DIM.g,
			Ui.GOLD_DIM.b, 0.28), 6, 1))
	left.add_child(hint_plate)
	_hint_label = Ui.label("", 17, Color(0.94, 0.90, 0.82))
	_hint_label.custom_minimum_size = Vector2(258, 0)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_plate.add_child(_hint_label)

	if sim.difficulty=="nightmare" and sim.factor_points()>0:
		var factor_plate:=Ui.panel(.88)
		factor_plate.position=Vector2(18,340);factor_plate.custom_minimum_size=Vector2(175,0)
		factor_plate.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(factor_plate)
		_factor_label=Ui.label("",14,Ui.GOLD_BRIGHT)
		_factor_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		_factor_label.custom_minimum_size=Vector2(148,0)
		factor_plate.add_child(_factor_label)
	# 卡槽
	var cards = HBoxContainer.new()
	cards.add_theme_constant_override("separation", 5)
	cards.set_anchors_preset(Control.PRESET_TOP_WIDE)
	cards.anchor_left = 0.0
	cards.anchor_right = 1.0
	cards.offset_left = 292.0
	cards.offset_right = -300.0
	cards.offset_top = 18.0
	cards.offset_bottom = 138.0
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cards)
	_card_nodes.clear()
	for i in sim.cards.size():
		var card = CardButton.new()
		card.index = i
		card.card_id = String(sim.cards[i]["id"])
		card.hud = self
		card.custom_minimum_size = Vector2(74, 116)
		cards.add_child(card)
		_card_nodes.append(card)

	# 卡槽右边的战斗速度：随时切，含 0.1x 救场档
	var speed_box := VBoxContainer.new()
	speed_box.add_theme_constant_override("separation", 4)
	speed_box.position = Vector2(1292, 16)
	speed_box.custom_minimum_size = Vector2(200, 0)
	speed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(speed_box)
	var speed_title := Ui.label("战斗速度", 13, Ui.TEXT_DIM)
	speed_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speed_box.add_child(speed_title)
	var speed_row := HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", 4)
	speed_box.add_child(speed_row)
	for value in SPEEDS:
		var pill := Ui.button(_speed_text(value), 14, 36, 34)
		pill.set_meta("speed_value", value)
		pill.set_meta("style_padding", Vector2(5, 6))
		pill.pressed.connect(func(): _set_speed(value))
		speed_row.add_child(pill)
		_speed_pills.append(pill)

	# 右侧工具
	var tools = VBoxContainer.new()
	tools.add_theme_constant_override("separation", 10)
	tools.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tools.offset_left = -96.0
	tools.offset_right = -26.0
	tools.offset_top = 22.0
	add_child(tools)
	_tool_wave = _tool_button("唤波", "提前放下一波恶客", func(): _on_quick_wave())
	tools.add_child(_tool_wave)
	_tool_shovel = _tool_button("", "起土铲 · 移除草木，先拆外面的龟甲罩", func(): _on_shovel())
	var tool_art: Texture2D = load("res://assets/sprites/lotus-trowel.png")
	_tool_shovel.icon = tool_art
	_tool_shovel.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tool_shovel.expand_icon = true
	_tool_shovel.add_theme_constant_override("icon_max_width", 42)
	if tool_art != null and DisplayServer.get_name() != "headless":
		_shovel_cursor = tool_art.get_image()
		_shovel_cursor.resize(48, 48, Image.INTERPOLATE_LANCZOS)
	tools.add_child(_tool_shovel)
	_tool_cheat = _tool_button("作弊", "杂项与召唤", func(): _toggle_cheat())
	_tool_cheat.visible = bool(game.settings.get("cheats", false)) or sim.training
	tools.add_child(_tool_cheat)
	var pause_button = _tool_button("暂停", "Esc 暂停", func(): game.toggle_pause())
	tools.add_child(pause_button)

	# 横幅
	_banner_band = ColorRect.new()
	_banner_band.color = Color(0.02, 0.02, 0.03, 0.78)
	_banner_band.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner_band.anchor_left = 0.5
	_banner_band.anchor_right = 0.5
	_banner_band.offset_left = -560.0
	_banner_band.offset_right = 560.0
	_banner_band.offset_top = 128.0
	_banner_band.offset_bottom = 268.0
	_banner_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_band.visible = false
	add_child(_banner_band)
	_banner_sub = Ui.label("", 20, Ui.GOLD)
	_banner_sub.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner_sub.anchor_left = 0.5
	_banner_sub.anchor_right = 0.5
	_banner_sub.offset_left = -420.0
	_banner_sub.offset_right = 420.0
	_banner_sub.offset_top = 226.0
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_sub.modulate.a = 0.0
	add_child(_banner_sub)
	_banner_label = Ui.title("", 46, Ui.GOLD_BRIGHT)
	_banner_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner_label.anchor_left = 0.5
	_banner_label.anchor_right = 0.5
	_banner_label.offset_left = -420.0
	_banner_label.offset_right = 420.0
	_banner_label.offset_top = 140.0
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_label.modulate.a = 0.0
	add_child(_banner_label)
	move_child(_banner_band, 0)

	_tooltip = Ui.label("", 17, Ui.GOLD_BRIGHT)
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.visible = false
	add_child(_tooltip)

	if game.tutorial_active:
		_build_tutorial()


func _tool_button(text: String, tip: String, action: Callable) -> Button:
	var node = Ui.button(text, 17, 70, 56)
	node.tooltip_text = tip
	node.pressed.connect(action)
	return node


func _build_tutorial() -> void:
	_tutorial_panel = Ui.panel(0.92)
	_tutorial_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_tutorial_panel.anchor_left = 0.5
	_tutorial_panel.anchor_right = 0.5
	_tutorial_panel.offset_left = -430.0
	_tutorial_panel.offset_right = 430.0
	_tutorial_panel.offset_top = -149.0
	_tutorial_panel.offset_bottom = -22.0
	add_child(_tutorial_panel)
	var row = Ui.hbox(14)
	_tutorial_panel.add_child(row)
	var column = Ui.vbox(4)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	_tutorial_label = Ui.strong("", 20, Ui.GOLD_BRIGHT)
	_tutorial_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_tutorial_label)
	_tutorial_dots = Control.new()
	_tutorial_dots.custom_minimum_size = Vector2(180, 12)
	_tutorial_dots.draw.connect(_draw_tutorial_dots)
	column.add_child(_tutorial_dots)
	_tutorial_almanac = Ui.button("打开图鉴", 20, 138, 48, true)
	_tutorial_almanac.pressed.connect(func(): game.open_almanac("plant", 1))
	_tutorial_almanac.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tutorial_almanac.hide()
	var lesson_actions := Ui.vbox(6)
	row.add_child(lesson_actions)
	lesson_actions.add_child(_tutorial_almanac)
	_tutorial_help = Ui.button("试用救急菜单", 17, 138, 36)
	_tutorial_help.pressed.connect(_toggle_cheat)
	_tutorial_help.hide()
	lesson_actions.add_child(_tutorial_help)
	var quit = Ui.button("退出教程", 16, 110, 40)
	quit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	quit.pressed.connect(func(): game.back_to_menu())
	row.add_child(quit)


func _draw_tutorial_dots() -> void:
	var sim: Sim = game.sim
	if sim == null or sim.tutorial == null:
		return
	var step = String(sim.tutorial["step"])
	var order = ["collect", "plant", "upgrade", "wall", "battle", "almanac"]
	var index = order.find(step)
	for i in order.size():
		var color = Ui.GOLD if i <= index else Color(1, 1, 1, 0.25)
		_tutorial_dots.draw_circle(Vector2(8 + i * 22, 6), 5.0, color)


## One horizontal page of up to four major waves, each ending at a banner.
func _draw_wave_pips() -> void:
	var sim: Sim = game.sim
	if sim == null or sim.training or sim.tutorial != null:
		return
	var groups = Content.visible_wave_groups(sim.level, sim.displayed_wave_count())
	if groups.is_empty():
		return
	var start = int(groups.front()) * Content.WAVES_PER_GROUP
	var steps = groups.size() * Content.WAVES_PER_GROUP
	var progress = clampf(float(sim.wave_index - start), 0.0, float(steps))
	if sim.boss != null and sim.boss.alive():
		var boss_share = 1.0 - sim.boss.hp / maxf(1.0, sim.boss.max_hp)
		var boss_span = 1.0
		progress = steps - boss_span * (1.0 - boss_share)
	elif progress > 0.0 and progress < steps and sim.wave_index < sim.level.waves.size():
		var released_at = float(sim.level.waves[sim.wave_index - 1]["t"]) + sim.wave_time_offset
		var next_at = float(sim.level.waves[sim.wave_index]["t"]) + sim.wave_time_offset
		var fraction = (sim.time - released_at) / maxf(0.001, next_at - released_at)
		progress += clampf(fraction, 0.0, 0.99)
	var bar := Rect2(8, 27, 242, 10)
	Ui.draw_gauge(_wave_pips, bar, progress / steps, Color("#b65a3c"))
	var tip = Vector2(bar.position.x + bar.size.x * (progress / steps), bar.get_center().y)
	_wave_pips.draw_circle(tip, 4.0, Color("#eac478"))
	var font = Ui.body_font()
	for i in groups.size():
		var end_step = (i + 1) * Content.WAVES_PER_GROUP
		var x = bar.position.x + bar.size.x * float(end_step) / steps
		var active = progress > i * Content.WAVES_PER_GROUP
		var raised = progress >= end_step
		_draw_wave_flag(Vector2(x, bar.get_center().y), active, raised)
		var number = str(int(groups[i]) + 1)
		var width = font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		_wave_pips.draw_string(font, Vector2(x - width * 0.5, 50), number,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Ui.GOLD_BRIGHT if active else Ui.TEXT_DIM)


func _draw_wave_flag(at: Vector2, active: bool, raised: bool) -> void:
	var gold = Color("#efd18c") if active else Color("#897653")
	var silk = Color("#c9593c") if raised else (Color("#8c4431") if active else Color("#443832"))
	var top = at + Vector2(0, -27)
	_wave_pips.draw_line(at + Vector2(0, 3), top, gold, 2, true)
	_wave_pips.draw_circle(top, 2.5, gold)
	var points := PackedVector2Array([
		top + Vector2(-1, 4), top + Vector2(-19, 3), top + Vector2(-16, 9),
		top + Vector2(-19, 15), top + Vector2(-1, 16)
	])
	_wave_pips.draw_colored_polygon(points, silk)
	points.append(points[0])
	_wave_pips.draw_polyline(points, gold, 1.0, true)
	_wave_pips.draw_line(top + Vector2(-13, 7), top + Vector2(-6, 8), gold, 1, true)
	_wave_pips.draw_line(top + Vector2(-13, 11), top + Vector2(-6, 12), gold, 1, true)


# ── 刷新 ────────────────────────────────────────────────────────────────────
func refresh() -> void:
	var sim: Sim = game.sim
	if sim == null or result_mode:
		return
	if _factor_label!=null:
		var info: Array[String]=["噩梦 · 因子 %d" % sim.factor_points()]
		if sim.factor("dim")>0:info.append("十秒香火\n%d / %d" % [sim.incense_received(),[0,750,500][sim.factor("dim")]])
		if sim.factor("loss")>0:info.append("草木损失 %d / %d" % [sim.nightmare_losses,[0,20,10][sim.factor("loss")]])
		if sim.factor("seeds")>0:info.append("场上草木 %d / %d" % [sim.plant_population(),[0,25,15][sim.factor("seeds")]])
		if sim.time<sim.curfew_until:info.append("宵禁还剩 %d 秒" % ceili(sim.curfew_until-sim.time))
		_factor_label.text="\n".join(info)
	if _sun_label != null:
		_sun_label.text = str(sim.sun)
		_sun_label.add_theme_font_size_override("font_size", Ui.fit_font(Ui.medium_font(), _sun_label.text, 68, Ui.font_size(26)))
	var total = int(sim.level.get("waves", []).size())
	if _wave_label != null:
		if sim.boss!=null:
			_wave_label.text="第 %d 大波 · 恶首战" % Content.current_major_wave(sim.level,sim.displayed_wave_count())
		elif bool(sim.level.get("special",false)):
			_wave_label.text = "第 %d / %d 大波" % [Content.current_major_wave(sim.level, sim.displayed_wave_count()), Content.wave_groups(sim.level)]
			if sim.special_opening():
				_wave_label.text += " · 布阵"
		elif sim.training:
			_wave_label.text = "训练场 · 手动召唤"
		elif total == 0:
			_wave_label.text = "教学关"
		else:
			var groups = Content.wave_groups(sim.level)
			var group_now = Content.current_major_wave(sim.level,sim.displayed_wave_count())
			_wave_label.text = "第 %d / %d 大波 · 第 %d 拨" % [group_now, groups,
				Content.wave_sub(maxi(0,sim.wave_index-1))]
		if not game.mobile:
			_wave_label.text = _wave_label.text.replace(" · ", "\n")
	if _danger!=null:
		_danger.values=[Content.checkpoint_threat(sim.level, sim.special_bosses_completed)] if bool(sim.level.get("special",false)) else [float(sim.level.get("threat",0))]
		_danger.queue_redraw()
	if _wave_pips != null:
		_wave_pips.queue_redraw()
	_refresh_speed_pills()
	var placement := Vector4i(sim.wave_index, sim.plants.size(), sim.tiles.hash(), int(_has_shell_target(sim)))
	if placement != _placement_signature:
		_placement_signature = placement
		_refresh_card_placement(sim)
	for card in _card_nodes:
		card.tooltip_text = String(_placement_warnings.get(card.card_id, Almanac.plant_pitch(card.card_id)))
		if not game.mobile: card.tooltip_text = "快捷键 %s\n%s" % [card._key_caption(), card.tooltip_text]
		card.state = _card_state(card.index)
		card.queue_redraw()
	if _tool_shovel != null:
		Ui.set_button_active(_tool_shovel, shovel_mode)
	if _hint_label != null:
		_hint_label.text = "" if game.tutorial_active or not bool(game.settings.get("show_text_hints", true)) else _hint_text()
		_hint_label.get_parent().visible = not _hint_label.text.is_empty()
	if _banner_label != null:
		var banner_shift := 70.0 if sim.boss != null else 0.0
		_banner_band.offset_top = 128.0 + banner_shift
		_banner_band.offset_bottom = 268.0 + banner_shift
		_banner_sub.offset_top = 226.0 + banner_shift
		_banner_label.offset_top = 145.0 + banner_shift
		if not sim.banner.is_empty():
			var big = String(sim.banner["text"]) == "一大波恶客正在靠近"
			var ceremony := bool(sim.banner.get("ceremony", false))
			_banner_label.text = String(sim.banner["text"])
			_banner_label.add_theme_font_size_override("font_size", Ui.font_size(64 if big else 46))
			var span = 0.9 if big else 0.8
			var a = clampf(float(sim.banner["t"]) / span, 0.0, 1.0)
			_banner_label.modulate.a = a
			_banner_sub.text = "第 %d 大波 / 共 %d 大波" % [int(sim.banner.get("group", 1)),
				int(sim.banner.get("groups", 4))] if big else ""
			if not String(sim.banner.get("subtitle", "")).is_empty():
				_banner_sub.text = String(sim.banner.subtitle)
			_banner_sub.modulate.a = a
			_banner_band.visible = big or ceremony
			_banner_band.modulate.a = a * 0.85
		else:
			_banner_label.modulate.a = 0.0
			_banner_sub.modulate.a = 0.0
			_banner_band.visible = false
	if game.tutorial_active:
		_refresh_tutorial()
	if focus_plant != null and (focus_plant.dead or not sim.plants.has(focus_plant)):
		close_fan()
	elif _fan != null:
		# 只有面板内容真的变了才重建：每帧重建会让按钮在按下与松开之间被释放，点不动。
		var signature = _fan_signature()
		if signature != _fan_sig:
			_sync_fan()
	if _shell_panel != null and is_instance_valid(_shell_panel):
		if _shell_host == null or _shell_host.dead or _shell_host.shell <= 0:
			close_fan()
		else:
			_shell_value.text = "耐久 %d / %d" % [ceili(_shell_host.shell), ceili(_shell_host.shell_max)]


## 失败建议要对着这一夜真实发生过的事说。按"最该先改的那一件"排：
## 整夜没人守的行 → 香火花不完 → 前排一直倒 → 已被突口 → 兜底一句。
func _loss_advice(summary: Dictionary, breached_rows: Array) -> String:
	var empty_rows: Array = summary.get("empty_rows", [])
	if not empty_rows.is_empty():
		return "第 %s 行整夜没人守。先把每一行都铺上一个，再谈升阶。" % [
			"、".join(empty_rows.map(func(x): return str(int(x))))]
	if int(summary.get("left_sun", 0)) >= 300:
		return "手里还剩 %d 香火。攒钱守不住摊子，差哪行就补哪行。" % int(summary.get("left_sun", 0))
	if int(summary.get("plants_lost", 0)) >= 4:
		return "这一夜倒了 %d 株。前排补不上时，先种石磨挡一口，别硬堆输出。" % int(
			summary.get("plants_lost", 0))
	if not breached_rows.is_empty():
		return "门神用完了，第 %s 行被穿了过去。给那一行补一株石磨，或把肉盾往前挪一格。" % [
			"、".join(breached_rows.map(func(x): return str(int(x))))]
	return "门神用完了，这一路被穿了过去。补一株石磨再试。"


func _format_speed(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return str(int(round(value)))
	return "%s" % String.num(value, 1)


func _hint_text() -> String:
	var sim: Sim = game.sim
	if sim.boss!=null:
		if sim.boss.id == "magistrate-bound":
			return "守住恶首所在的两行。鬼官受限时只会点名，无法发动重判或号令。"
		return "守住恶首所在的两行。施法槽快满时，留意地上的落点预警。"
	if sim.training:
		return "训练场里可以随时召来恶客，试试不同的布阵。"
	if not sim.banner.is_empty() or _banner_t > 0.0:
		return ""
	if sim.wave_index <= 1:
		return "先铺产能，再补输出，每行都留一份火力。"
	if sim.wave_index <= 4:
		return "斗笠先扣护具：石磨挡住，再交给破甲的。"
	if sim.wave_index <= 7:
		return "哭声会催快恶客——青色波纹一起就补缺路。"
	return "最后几波：门神只有一次，别让它白费。"


func _has_shell_target(sim: Sim) -> bool:
	return sim.plants.any(func(plant): return not plant.dead and not plant.is_lily and plant.shell <= 0.0)


func _refresh_card_placement(sim: Sim) -> void:
	_placement_warnings.clear()
	for card in sim.cards:
		var type := String(card.id)
		var def: Dictionary = card.def
		if bool(def.get("attach", false)):
			if not _has_shell_target(sim):
				_placement_warnings[type] = "需要一株还没罩龟甲的草木"
			continue
		var available := false
		for row in sim.rows:
			for col in Geo.COLS:
				if bool(sim.can_place_at(type, col, row).ok):
					available = true
					break
			if available:
				break
		if not available:
			var aquatic := bool(def.get("lily", false)) or bool(def.get("water_only", false))
			_placement_warnings[type] = "暂时没有空水格可放" if aquatic else "暂时没有可种植的空位"


func _card_state(index: int) -> Dictionary:
	var sim: Sim = game.sim
	var card: Dictionary = sim.cards[index]
	var def: Dictionary = card["def"]
	var cooldown = float(card["cd"])
	var affordable = sim.sun >= int(def["cost"])
	return {
		"cooldown": cooldown,
		"cooldown_max": maxf(0.1, float(def["cooldown"])),
		"affordable": affordable,
		"selected": card_selected == index,
		"ready": cooldown <= 0.001 or sim.no_cooldown,
		"taught": _card_is_taught(String(card["id"])),
		"no_placement": _placement_warnings.has(card.id),
	}


## 教程当前这一步要点哪张牌。牌在顶部卡栏，别再对玩家说"右下角"。
func _card_is_taught(card_id: String) -> bool:
	if not game.tutorial_active or game.sim == null:
		return false
	match game.sim.tutorial_step():
		"plant":
			return card_id == "shooter"
		"wall":
			return card_id == "wall"
	return false


func _refresh_tutorial() -> void:
	var sim: Sim = game.sim
	if sim.tutorial == null:
		return
	var step = String(sim.tutorial["step"])
	var cost = Upgrades.tier_cost("shooter", 1, 1)
	var wall_cost = int(Content.PLANTS["wall"]["cost"])
	var copy = {
		"collect": ["第一步 · 收下这团香火",
			"街上那团金色的是香火，点一下收下。教学里的这团不会自己消失。"],
		"plant": ["第二步 · 请一株签筒出摊",
			"点最上面那一排、正发着光的「签筒」牌，再点靠后的空格放下它。签筒只打本行前方。"],
		"upgrade": ["第三步 · 给签筒升阶",
			"点签筒，在「连发」扇叶花 %d 香火。升阶能让一株草木多做事。每株最多学两路，只有一路能练到三阶，落子前先想它要守哪一行。" % cost],
		"wall": ["第四步 · 请石磨挡在前面",
			"光在闪的「石磨」牌点一下，种在签筒前面那一格（%d 香火）。它不打人，它负责挨咬。" % wall_cost],
		"battle": ["第五步 · 看它们自己出手",
			"恶客从右边过来。石磨挡住它，签筒自动瞄准开火。"],
		"finishing": ["守住了", "接下来看看草木还有哪些本事。"],
		"almanac": ["第六步 · 出摊前再看一眼",
			"每周初夜较为平和，适合熟悉新的摊面。第二至第四夜，各有不同的来客和难题；到了第五夜，老面孔会一起上门，恶首也将现身。开张前，先看看今夜会遇到谁。\n实在守不住时，从暂停进设置开启「作弊菜单」，回战场点「作弊」，可以补些香火，慢慢试出适合自己的布阵。右侧可以先试，再翻图鉴看签筒的进化。"],
		"done": ["这一课成了", "收香火、出输出、挡怪、升阶——四样都在手上了。"],
	}
	var entry: Array = copy.get(step, ["", ""])
	if _tutorial_label != null:
		_tutorial_label.text = "%s\n%s" % [entry[0], entry[1]]
	if _tutorial_almanac != null:
		_tutorial_almanac.visible = step == "almanac"
		_tutorial_help.visible = step == "almanac"
		_tutorial_panel.offset_top = -235.0 if step == "almanac" else -149.0
	if _tutorial_dots != null:
		_tutorial_dots.queue_redraw()


# ── 点击与选择 ──────────────────────────────────────────────────────────────
func _on_card(index: int) -> void:
	var sim: Sim = game.sim
	if sim == null:
		return
	if game.tutorial_active:
		var step = sim.tutorial_step()
		if step == "collect":
			sim.deny("先收下那团香火", _mouse())
			return
		var picked = String(sim.cards[index]["id"])
		if step == "plant" and picked != "shooter":
			sim.deny("先种下签筒", _mouse())
			return
		if step == "upgrade":
			sim.deny("先点那株签筒，给它升一级", _mouse())
			return
		if step == "wall" and picked != "wall":
			sim.deny("这一步请石磨出摊", _mouse())
			return
	card_selected = -1 if card_selected == index else index
	set_shovel_mode(false)
	close_fan()
	game.play_sfx("click")
	refresh()


func _on_shovel() -> void:
	set_shovel_mode(not shovel_mode)
	card_selected = -1
	close_fan()
	game.play_sfx("click")
	refresh()


func set_shovel_mode(enabled: bool) -> void:
	if shovel_mode == enabled:
		return
	shovel_mode = enabled
	if _shovel_cursor != null:
		Input.set_custom_mouse_cursor(_shovel_cursor if enabled else null, Input.CURSOR_ARROW, Vector2(2, 2) if enabled else Vector2.ZERO)


func _exit_tree() -> void:
	set_shovel_mode(false)


func _on_quick_wave() -> void:
	var sim: Sim = game.sim
	if sim == null:
		return
	if not sim.summon_next_wave():
		sim.deny("已无后续波次", _mouse())
	refresh()


func cancel_selection() -> void:
	card_selected = -1
	set_shovel_mode(false)
	close_fan()
	refresh()


func try_open_menu(plant, at: Vector2) -> void:
	var sim: Sim = game.sim
	if plant == null:
		return
	if game.tutorial_active:
		var step = sim.tutorial_step()
		# 教学的香火只够这一课的份，花在别处会把课卡死，所以只放开该点的那一处
		if step == "upgrade":
			if plant != sim.tutorial["shooter"]:
				sim.deny("先给签筒升阶", at)
				return
		elif step in ["collect", "plant", "wall"]:
			sim.deny("这一课先跟着走，升阶等出了教程再试", at)
			return
	if plant.is_lily and sim.main_plant_at(plant.col, plant.row) != null:
		plant = sim.main_plant_at(plant.col, plant.row)
	if plant.is_lily:
		sim.deny("夜莲只是浮台，不能升阶；点上面的草木", at)
		return
	if String(plant.type) == "bomb":
		sim.deny("爆竹是一次性的，无法升阶", at)
		return
	if String(plant.type) == "kelp":
		sim.deny("缠魂藻一次即沉，无法升阶", at)
		return
	if Upgrades.paths_for(String(plant.type)).is_empty():
		sim.deny("此物无法升阶", at)
		focus_plant = plant
		_build_fan(plant, at)
		return
	focus_plant = plant
	_build_fan(plant, at)
	game.play_sfx("click")


func close_fan() -> void:
	if _shell_panel != null and is_instance_valid(_shell_panel):
		_shell_panel.hide()
		_shell_panel.queue_free()
	_shell_panel = null
	_shell_host = null
	focus_plant = null
	if _fan != null and is_instance_valid(_fan):
		_fan.hide()
		_fan.queue_free()
	_fan = null
	_fan_rows.clear()

func show_shell(plant) -> void:
	close_fan()
	_shell_host = plant
	_shell_panel = Ui.panel()
	_shell_panel.name = "ShellDetails"
	_shell_panel.z_index = 2
	_shell_panel.size = Vector2(270, 180)
	var at: Vector2 = preload("res://scripts/plant_regions.gd").shell_rect(plant, game.sim.rows).end
	_shell_panel.position = Vector2(clampf(at.x + 12, 12, size.x - 282), clampf(at.y - 180, 160, size.y - 192))
	add_child(_shell_panel)
	preload("res://ui/click_away.gd").attach(self, _shell_panel, close_fan)
	var box := Ui.vbox(8)
	_shell_panel.add_child(box)
	box.add_child(Ui.strong("龟甲罩", 23, Ui.GOLD_BRIGHT))
	_shell_value = Ui.label("耐久 %d / %d" % [ceili(plant.shell), ceili(plant.shell_max)], 17)
	box.add_child(_shell_value)
	box.add_child(Ui.label("点草木上部可查看本体进化", 14, Ui.TEXT_DIM))
	var row := Ui.hbox(8)
	box.add_child(row)
	var remove := Ui.button("拆下龟甲罩", 16, 150, 36)
	remove.pressed.connect(func(): game.sim.remove_shell(plant); close_fan(); refresh())
	row.add_child(remove)
	var close := Ui.button("收起", 15, 70, 36)
	close.pressed.connect(close_fan)
	row.add_child(close)


func _build_fan(plant, at: Vector2) -> void:
	close_fan()
	focus_plant = plant
	_fan = UpgradeFan.new()
	_fan.plant = plant
	_fan.sim = game.sim
	_fan.picked.connect(_on_fan_pick)
	_fan.dismissed.connect(close_fan)
	add_child(_fan)
	_sync_fan()


## 把三路的当前状态喂给扇形菜单（级数、费用、能不能点）
func _sync_fan() -> void:
	if _fan == null or not is_instance_valid(_fan):
		return
	var plant = focus_plant
	if plant == null:
		return
	var sim: Sim = game.sim
	var entries: Array = []
	for path in Upgrades.paths_for(String(plant.type)):
		var status = sim.upgrade_status(plant,int(path["id"]))
		var cost = int(status["cost"]) if bool(status["ok"]) else 0
		var tiers: Array = path["tiers"]
		var tier_now = int(status["tier"])
		var next_desc = ""
		var next_name = ""
		if tier_now >= tiers.size():
			next_name = String(tiers.back()["name"])
			next_desc = String(tiers.back()["desc"])
		elif tier_now < tiers.size():
			next_name = String(tiers[tier_now]["name"])
			next_desc = String(tiers[tier_now]["desc"])
		entries.append({
			"id": int(path["id"]),
			"name": String(path["name"]),
			"color": Color(String(path["color"])),
			"tier": tier_now,
			"ok": bool(status["ok"]),
			"cost": cost,
			"reason": String(status["reason"]),
			"affordable": sim.sun >= cost,
			"next_name": next_name,
			"next_desc": next_desc,
		})
	_fan.entries = entries
	_fan.queue_redraw()
	_fan_sig = _fan_signature()


func _fan_signature() -> String:
	var sim: Sim = game.sim
	var plant = focus_plant
	if sim == null or plant == null:
		return ""
	var parts: Array = []
	for path in Upgrades.paths_for(String(plant.type)):
		var status = sim.upgrade_status(plant,int(path["id"]))
		var cost = int(status["cost"]) if bool(status["ok"]) else -1
		var affordable = sim.sun >= cost if cost >= 0 else false
		parts.append("%d:%d:%s:%d:%s" % [int(path["id"]), int(status["tier"]),
			str(bool(status["ok"])), cost, str(affordable)])
	parts.append(str(int(ceil(plant.hp))))
	parts.append(str(plant.shell > 0.0))
	return "|".join(parts)


func _on_fan_pick(path_id: int) -> void:
	_on_upgrade(focus_plant, path_id)


func _on_upgrade(plant, path_id: int) -> void:
	var sim: Sim = game.sim
	if sim == null:
		return
	var outcome = sim.try_upgrade(plant, path_id, _mouse())
	if bool(outcome["ok"]):
		if game.tutorial_active and sim.tutorial_step() == "battle":
			close_fan()
		_sync_fan()
	refresh()


func _mouse() -> Vector2:
	return get_viewport().get_mouse_position()


# ── 作弊 ────────────────────────────────────────────────────────────────────
func blocks_simulation() -> bool:
	return cheat_open


func set_cheats_enabled(enabled: bool) -> void:
	if _tool_cheat != null:
		_tool_cheat.visible = enabled or (game.sim != null and game.sim.training)
	if not enabled and cheat_open and (game.sim == null or not game.sim.training):
		_toggle_cheat()


func _toggle_cheat() -> void:
	cheat_open = not cheat_open
	if cheat_open:
		close_fan()
		_build_cheat()
	elif _cheat_panel != null:
		_cheat_panel.queue_free()
		_cheat_panel = null
	refresh()


func _build_cheat() -> void:
	if _cheat_panel != null and is_instance_valid(_cheat_panel):
		_cheat_panel.queue_free()
	_cheat_panel = Ui.panel(0.96)
	_cheat_panel.set_anchors_preset(Control.PRESET_CENTER)
	_cheat_panel.anchor_left = 0.5
	_cheat_panel.anchor_right = 0.5
	_cheat_panel.offset_left = -220.0
	_cheat_panel.offset_right = 220.0
	_cheat_panel.offset_top = -250.0
	_cheat_panel.offset_bottom = 250.0
	_cheat_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_cheat_panel.z_index = 100
	add_child(_cheat_panel)
	preload("res://ui/click_away.gd").attach(self, _cheat_panel, _toggle_cheat)
	var box = Ui.vbox(8)
	_cheat_panel.add_child(box)
	var head = Ui.hbox(8)
	box.add_child(head)
	head.add_child(Ui.title("局内调整", 30, Ui.GOLD_BRIGHT))
	var sim: Sim = game.sim
	if sim.training:
		var tabs = Ui.hbox(6)
		box.add_child(tabs)
		for pair in [["misc", "杂项"], ["spawn", "召唤"]]:
			var tab = Ui.button(String(pair[1]), 17, 90, 34)
			tab.pressed.connect(func():
				cheat_tab = String(pair[0])
				_build_cheat())
			if cheat_tab == String(pair[0]):
				Ui.set_button_active(tab, true)
			tabs.add_child(tab)
	if sim.training and cheat_tab == "spawn":
		_build_spawn_tab(box)
	else:
		_build_misc_tab(box)


func _set_spawn_type(type: String) -> void:
	spawn_type = type
	_build_cheat()


func _set_spawn_count(value: int) -> void:
	spawn_count = value
	_build_cheat()


func _set_spawn_lane(lane: int) -> void:
	spawn_lane = lane
	_build_cheat()


func _build_misc_tab(box: VBoxContainer) -> void:
	var sim: Sim = game.sim
	var rows = [
		["香火 +500", func():
			sim.sun += 500
			sim.float_text(Vector2(800, 300), "+500 香火", Ui.GOLD_BRIGHT, 20)],
		["秒杀全场恶客", func():
			sim.kill_all_zombies()
			sim.shake = 8.0],
		["门神归位", func():
			sim.restore_mowers()
			sim.float_text(Vector2(800, 300), "门神归位", Ui.GOLD_BRIGHT, 18)],
	]
	if game.tutorial_active:
		rows.resize(1)
		var tip := Ui.label("试着补一次香火，再关闭菜单。正式守夜时，建议卡关再打开。", 17, Ui.TEXT_DIM)
		tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(tip)
	if sim.training:
		rows.append(["无冷却 %s" % ("已开" if sim.no_cooldown else "已关"), func():
			sim.no_cooldown = not sim.no_cooldown
			game.training["cooldown_locked"] = not sim.no_cooldown
			_build_cheat()])
		rows.append(["清空草木", func():
			sim.clear_plants()
			_toggle_cheat()])
		rows.append(["切换地图", func():
			var day = (int(game.training.get("day", 1)) % Content.DAYS.size()) + 1
			game.training["day"] = day
			var level_id = Content.level_id_for(day)
			game.start_battle(level_id, game.loadout, "training")
			])
		rows.append(["退回选草", func():
			game.show_prep(Content.level_id_for(int(game.training.get("day", 1))), true,
				int(game.training.get("day", 1)))])
	elif not game.tutorial_active:
		rows.append(["直接结算为胜", func():
			game.finish_run(true)])
	for row in rows:
		var button = Ui.button(String(row[0]), 18, 360, 40)
		button.pressed.connect(_cheat(row[1]))
		box.add_child(button)
	var close = Ui.button("关闭", 17, 360, 36)
	close.pressed.connect(_toggle_cheat)
	box.add_child(close)


## 正式局里动一次调整面板，这一夜就另册记录；训练场本来不写纪录，不必标。
func _cheat(action: Callable) -> Callable:
	return func():
		if game.sim != null and not game.sim.training:
			game.sim.cheated = true
		action.call()
		if game.sim != null and is_instance_valid(self):
			refresh()


func _build_spawn_tab(box: VBoxContainer) -> void:
	var sim: Sim = game.sim
	box.add_child(Ui.label("选恶客", 16, Ui.TEXT_DIM))
	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	for type in Content.ZOMBIE_ORDER:
		if bool(Content.ZOMBIES[type].get("sedan_only", false)):
			continue
		if bool(Content.ZOMBIES[type].get("water_only", false)) and sim.level.get("water_rows", []).is_empty():
			continue
		var button = Ui.button(String(Content.ZOMBIES[type]["name"]), 15, 84, 34)
		if type == spawn_type:
			Ui.set_button_active(button, true)
		button.pressed.connect(_set_spawn_type.bind(type))
		grid.add_child(button)
	box.add_child(Ui.label("数量", 16, Ui.TEXT_DIM))
	var counts = Ui.hbox(6)
	box.add_child(counts)
	for value in [1, 3, 5, 10]:
		var button = Ui.button(str(value), 16, 60, 32)
		if spawn_count == value:
			Ui.set_button_active(button, true)
		button.pressed.connect(_set_spawn_count.bind(value))
		counts.add_child(button)
	box.add_child(Ui.label("分路", 16, Ui.TEXT_DIM))
	var lanes = Ui.hbox(4)
	box.add_child(lanes)
	var labels = ["随机"]
	for row in sim.rows:
		labels.append("第 %d 行" % (row + 1))
	for i in labels.size():
		var lane = i - 1
		var button = Ui.button(String(labels[i]), 15, 66, 32)
		if spawn_lane == lane:
			Ui.set_button_active(button, true)
		button.pressed.connect(_set_spawn_lane.bind(lane))
		lanes.add_child(button)
	var summon = Ui.button("召来", 18, 360, 42)
	summon.pressed.connect(func():
		sim.summon_training(spawn_type, spawn_count, spawn_lane)
		_toggle_cheat())
	box.add_child(summon)
	var close = Ui.button("关闭", 17, 360, 34)
	close.pressed.connect(_toggle_cheat)
	box.add_child(close)


# ── 暂停 ────────────────────────────────────────────────────────────────────
func _build_pause() -> void:
	var shade = ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.06, 0.72)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var panel = Ui.panel(0.96)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -300.0
	panel.offset_right = 300.0
	panel.offset_top = -215.0
	panel.offset_bottom = 215.0
	add_child(panel)
	preload("res://ui/click_away.gd").attach(self, panel, resume)
	var box = Ui.vbox(12)
	panel.add_child(box)
	var head = Ui.hbox(10)
	box.add_child(head)
	head.add_child(Ui.seal("停"))
	head.add_child(Ui.title("暂停", 40, Ui.GOLD_BRIGHT))
	box.add_child(Ui.label("这一夜还长，喘口气再守。", 17, Ui.TEXT_DIM))
	box.add_child(Ui.hline(Ui.GOLD_DIM, 1.0))
	var resume_button = Ui.button("重返游戏", 28, 536, 72, true)
	resume_button.pressed.connect(resume)
	box.add_child(resume_button)
	var tools = Ui.hbox(12)
	box.add_child(tools)
	var almanac = Ui.button("查看图鉴", 19, 262, 49)
	almanac.pressed.connect(func(): game.open_almanac("plant", 0))
	tools.add_child(almanac)
	var settings = Ui.button("设置", 19, 262, 49)
	settings.pressed.connect(func(): game.open_settings())
	tools.add_child(settings)
	var restart = Ui.button("重新开始这一夜", 17, 300, 42)
	restart.pressed.connect(func(): game.restart_run())
	box.add_child(restart)
	var footer = Ui.hbox(10)
	box.add_child(footer)
	var mute = Ui.button("静音切换", 15, 120, 34)
	mute.pressed.connect(func():
		game.set_setting("sound", not bool(game.settings["sound"])))
	footer.add_child(mute)
	var back = Ui.button("回到封面", 15, 110, 34)
	back.pressed.connect(func(): game.back_to_menu())
	footer.add_child(back)


func resume() -> void:
	game.close_pause()


# ── 结算 ────────────────────────────────────────────────────────────────────
func _build_result() -> void:
	var shade = ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.06, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var panel = Ui.panel(0.96)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -410.0
	panel.offset_right = 410.0
	panel.offset_top = -325.0
	panel.offset_bottom = 325.0
	add_child(panel)
	var box = Ui.vbox(10)
	panel.add_child(box)
	Art.enter(panel, 0.32)
	var head = Ui.hbox(14)
	box.add_child(head)
	var emblem = Control.new()
	emblem.custom_minimum_size = Vector2(88, 88)
	emblem.draw.connect(func():
		var color = Ui.GOLD_BRIGHT if won else Ui.BAD
		Art.diamond(emblem, Vector2(44, 44), 39, color)
		Art.diamond(emblem, Vector2(44, 44), 32, Color(color, 0.35))
		Art.icon(emblem, "lantern" if won else "boss", Vector2(44, 44), 23, color))
	head.add_child(emblem)
	var titles = Ui.vbox(0)
	head.add_child(titles)
	titles.add_child(Ui.title("守至天亮" if won else "此夜失守", 48,
		Ui.GOLD_BRIGHT if won else Ui.BAD))
	var level = Content.get_level(int(result.get("level_id", 1)))
	var subtitle = "%s·%s · %s" % [level["day_name"], level["day_sub"], level["name"]]
	if bool(result.get("tutorial", false)):
		subtitle = "新手教程"
	elif bool(result.get("training", false)):
		subtitle = "训练场"
	titles.add_child(Ui.label(subtitle, 18, Ui.TEXT_DIM))
	box.add_child(Ui.hline(Ui.GOLD_DIM, 1.0))

	var detail_scroll = ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(detail_scroll)
	var detail_box = Ui.vbox(10)
	detail_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(detail_box)
	var stats = GridContainer.new()
	stats.columns = 2
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.add_theme_constant_override("h_separation", 24)
	stats.add_theme_constant_override("v_separation", 10)
	detail_box.add_child(stats)
	var seconds = float(result.get("time", 0.0))
	var main_stats = [
		["用时", "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]],
		["击退", str(int(result.get("kills", 0)))],
		["余香", str(int(result.get("sun", 0)))],
	]
	var highlights = Ui.hbox(14)
	detail_box.add_child(highlights)
	detail_box.move_child(highlights, 0)
	for metric in main_stats:
		var tile = PanelContainer.new()
		tile.add_theme_stylebox_override("panel", Art.surface("card", "normal", Vector2(18, 12)))
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.custom_minimum_size = Vector2(224, 94)
		highlights.add_child(tile)
		var value_box = Ui.vbox(2)
		tile.add_child(value_box)
		var caption = Ui.label(String(metric[0]), 15, Ui.TEXT_DIM)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_box.add_child(caption)
		var value = Ui.strong(String(metric[1]), 31, Ui.GOLD_BRIGHT)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_box.add_child(value)
	var stat_rows: Array = []
	var summary: Dictionary = result.get("summary", {})
	var breached_rows: Array = summary.get("breached_rows", [])
	var mowers_used = int(summary.get("mowers_used", 0))
	var plain = bool(result.get("tutorial", false)) or bool(result.get("training", false))
	var played: Dictionary = Content.get_level(int(result.get("level_id", 1)))
	if not summary.is_empty():
		var stars = clampi(int(summary.get("stars", 0)), 0, 3)
		if not plain:
			# 失败不发通关星：星只属于守住天亮的那一夜，失败改说门神用了几次
			if won:
				stat_rows.append(["守夜评级",
					"★★★".substr(0, stars) + "☆☆☆".substr(0, 3 - stars)])
				if stars < 3:
					stat_rows.append(["三星条件", "一夜不动用门神"])
			else:
				stat_rows.append(["这一夜", "没守住 · 门神用了 %d 次" % mowers_used])
		var top_type = String(summary.get("top_type", ""))
		if top_type != "" and Content.PLANTS.has(top_type):
			stat_rows.append(["主力输出", "%s 合计 %d 伤害" % [
				String(Content.PLANTS[top_type]["name"]), int(summary.get("top_damage", 0))]])
		if summary.has("riskiest_wave"):
			stat_rows.append(["最险时刻", "%s · 场上 %d 只" % [
				Content.wave_text(played, maxi(0,int(summary.get("riskiest_wave",0))-1)),
				int(summary.get("risk_peak", 0))]])
		stat_rows.append(["被突破", "没有" if breached_rows.is_empty() else "%d 处 · 第 %s 行" % [
			mowers_used, "、".join(breached_rows.map(func(x): return str(int(x))))]])
	for row in stat_rows:
		var key = Ui.label(String(row[0]), 17, Ui.TEXT_DIM)
		key.custom_minimum_size = Vector2(96, 0)
		stats.add_child(key)
		if String(row[0])=="守夜评级" and summary.has("star_flags"):
			var rating=load("res://ui/star_rating.gd").new()
			rating.flags=Array(summary.star_flags);rating.factor_count=int(summary.get("factor_points",0)) if not game.sim.cheated else 0
			stats.add_child(rating)
			continue
		var value = Ui.strong(String(row[1]), 21, Ui.GOLD_BRIGHT)
		value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		value.custom_minimum_size.x = 480
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats.add_child(value)
	detail_box.add_child(Ui.spacer(6))
	var comment = ""
	if bool(result.get("tutorial", false)):
		comment = "灯、签、磨都齐了。夜市的路还长，慢慢守。"
	elif won:
		comment = "灯还亮着，今夜收摊。"
		if game.sim.difficulty=="nightmare":
			comment="本夜使用了调整，红星与因子徽章未记入。" if game.sim.cheated else ("噩梦已破 · 收下红星与 %d 因子朱印。" % game.sim.factor_points() if game.sim.factor_points()>0 else "噩梦已破 · 第四颗红星已点亮。")
	else:
		comment = _loss_advice(summary, breached_rows)
	var comment_label = Ui.label(comment, 18, Ui.TEXT)
	comment_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_box.add_child(comment_label)
	detail_box.add_child(Ui.spacer(8))

	var row1 = Ui.hbox(12)
	row1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(row1)
	if bool(result.get("tutorial", false)):
		var again = Ui.button("再练一次", 17, 164, 44)
		again.pressed.connect(func(): game.start_battle(0, ["shooter"], "tutorial"))
		row1.add_child(again)
		# 教程结束后直接把人带进正式第一夜，而不是又扔回封面（另一个"回到封面"在下一行）
		var first = Ui.button("开始第一夜", 23, 242, 56, true)
		first.pressed.connect(func(): game.show_prep(1))
		row1.add_child(first)
	else:
		var retry = Ui.button("再来一次", 18 if won else 23, 152 if won else 230, 44 if won else 56, not won)
		retry.pressed.connect(func(): game.restart_run())
		row1.add_child(retry)
		if won:
			var next_level = Content.next_story_level(int(result.get("level_id",1)))
			var next = Ui.button("下一夜", 23, 224, 56, true)
			next.disabled = next_level<=0
			next.pressed.connect(func(): game.show_prep(next_level))
			row1.add_child(next)
		var select = Ui.button("换一夜", 17, 132, 44)
		select.pressed.connect(func(): game.show_levels())
		row1.add_child(select)
	var row2 = Ui.hbox(12)
	for action in row1.get_children():
		action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action.size_flags_stretch_ratio = 1.3 if action.get_meta("primary", false) else 1.0
	row2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(row2)
	var almanac = Ui.button("图鉴", 17, 0, 38)
	almanac.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	almanac.pressed.connect(func(): game.open_almanac("plant", 0))
	row2.add_child(almanac)
	var menu = Ui.button("回到封面", 17, 0, 38)
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.pressed.connect(func(): game.back_to_menu())
	row2.add_child(menu)


# ── 卡槽控件 ────────────────────────────────────────────────────────────────
class CardButton extends Control:
	var hud = null
	var index = 0
	var card_id = ""
	var state: Dictionary = {}
	var hovered = false
	var icon: Texture2D
	var _binding_physical = -1
	var _binding_caption = ""

	func _key_caption() -> String:
		var physical = hud.game.bound_key("card_%d" % (index + 1))
		if physical != _binding_physical:
			_binding_physical = physical
			var code = physical if DisplayServer.get_name() == "headless" else DisplayServer.keyboard_get_keycode_from_physical(physical)
			_binding_caption = String({KEY_BRACKETLEFT: "[", KEY_BRACKETRIGHT: "]", KEY_MINUS: "-", KEY_EQUAL: "="}.get(code, OS.get_keycode_string(code)))
		return _binding_caption

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		icon = Ui.sprite(card_id)
		tooltip_text = Almanac.plant_pitch(card_id)
		mouse_entered.connect(func(): hovered = true; queue_redraw())
		mouse_exited.connect(func(): hovered = false; queue_redraw())
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)

	func _gui_input(event: InputEvent) -> void:
		if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			accept_event()
			hud._on_card(index)

	func _draw() -> void:
		var rect = Rect2(Vector2.ZERO, size)
		var def: Dictionary = Content.PLANTS[card_id]
		if hud.game.mobile:
			Ui.draw_plate(self, rect, Color("#11222b"), Ui.GOLD if state.get("selected", false) else Ui.GOLD_DIM, 14, 2)
			Ui.draw_plant_icon(self, card_id, Rect2(6, 4, size.x - 12, 78), Color.WHITE if state.get("affordable", true) else Color(0.55, 0.55, 0.55))
			draw_string(Ui.body_font(), Vector2(0, size.y - 9), str(int(def.cost)), HORIZONTAL_ALIGNMENT_CENTER, size.x, 34, Ui.GOLD_BRIGHT)
			var cooldown = float(state.get("cooldown", 0.0))
			if cooldown > 0:
				Ui.draw_plate(self, Rect2(0, 0, size.x, size.y * clampf(cooldown / float(state.get("cooldown_max", 1.0)), 0, 1)), Color(0, 0, 0, 0.6), Color.TRANSPARENT, 14, 0)
			if state.get("no_placement", false): draw_string(Ui.body_font(), Vector2(0, 32), "无落点", HORIZONTAL_ALIGNMENT_CENTER, size.x, 26, Ui.WARN)
			return
		draw_style_box(MarketArt.surface("card", "hover" if hovered else "normal", Vector2.ZERO), rect)
		var selected = bool(state.get("selected", false))
		if selected:
			Ui.draw_plate(self, rect.grow(-2), Color(Ui.JADE, 0.13), Ui.JADE_LIGHT, 2, 2)
		if has_focus(): MarketArt.corners(self, rect.grow(-2), Ui.GOLD_BRIGHT, 10)
		if bool(state.get("taught", false)):
			var beat = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 260.0)
			Ui.draw_plate(self, rect.grow(2), Color.TRANSPARENT, Color(1, 0.85, 0.42, 0.45 + beat * 0.5), 3, 3)
		var affordable = bool(state.get("affordable", true))
		Ui.draw_plant_icon(self, card_id, Rect2(7, 13, size.x - 14, size.y - 53), Color.WHITE if affordable else Color(1, 1, 1, 0.44))
		var name_text = String(def.name)
		var name_size = mini(Ui.font_size(14), int((size.x - 8) / maxi(1, name_text.length())))
		draw_string(Ui.body_font(), Vector2(0, size.y - 27), name_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, name_size, Ui.TEXT)
		draw_line(Vector2(10, size.y - 21), Vector2(size.x - 10, size.y - 21), Color(Ui.GOLD_DIM, 0.35), 1, true)
		draw_string(Ui.medium_font(), Vector2(0, size.y - 7), str(int(def.cost)), HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, Ui.GOLD_BRIGHT if affordable else Ui.BAD)
		var key_text = _key_caption()
		var key_width = Ui.body_font().get_string_size(key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		var key_size = mini(10, floori(10 * minf(1.0, (size.x - 14) / maxf(1, key_width))))
		draw_string(Ui.body_font(), Vector2(7, 14), key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, key_size, Ui.TEXT_DIM)
		var cooldown = float(state.get("cooldown", 0.0))
		if cooldown > 0.05:
			var ratio = clampf(cooldown / float(state.get("cooldown_max", 1.0)), 0, 1)
			draw_rect(Rect2(4, 4, size.x - 8, (size.y - 26) * ratio), Color(0.015, 0.035, 0.04, 0.7))
			draw_string(Ui.medium_font(), Vector2(0, size.y * 0.5), str(ceili(cooldown)), HORIZONTAL_ALIGNMENT_CENTER, size.x, 19, Ui.GOLD_BRIGHT)
		if bool(state.get("no_placement", false)):
			Ui.draw_plate(self, Rect2(4, 4, size.x - 8, 20), Color("#3c251c"), Ui.GOLD_DIM, 2, 1)
			draw_string(Ui.body_font(), Vector2(0, 19), "暂无落点", HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, Ui.WARN)
