## 局内界面：香火、卡槽、唤波/铲子/作弊/暂停、升阶面板、教学引导、暂停与结算。
##
## 与 v0.2.4 的布局差异（本轮的美术与排版优化）：
##  * 香火与波次放在左侧竖栏，工具按钮放在右侧竖栏，棋盘居中不遮不挡；
##  * 升阶从扇形菜单改为贴着草木的信息卡，三路状态、费用、锁定原因一屏读完；
##  * 所有数值（含教学文案里的升阶费用）都从数据表取，不再写死。
extends Control

var game = null
var result_mode = false
var pause_mode_ui = false
var won = false
var result: Dictionary = {}

var card_selected = -1
var shovel_mode = false
var focus_plant = null
var cheat_open = false
var slow_battle = false
var _opened_cheat_once = false
var cheat_tab = "misc"
var spawn_type = "ghost"
var spawn_count = 1
var spawn_lane = -1
var _hover_card = -1

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
var _speed_label: Label = null
var _fan: UpgradeFan = null
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

const SPEEDS = [1.0, 1.5, 2.0, 3.0]
# 0.1× 是训练场的观察档，正式对局不给，免得误点后以为游戏卡住
const SPEEDS_TRAINING = [0.1, 1.0, 1.5, 2.0, 3.0]


static func _speed_text(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return str(int(round(value)))
	return String.num(value, 1)


## 局内直接切速度：写回设置，下次开局沿用
func _set_speed(value: float) -> void:
	if game == null:
		return
	if game.tutorial_active:
		return
	game.apply_speed(value)
	game.set_setting("speed", value)
	game.play_sfx("click")
	refresh()


func _refresh_speed_pills() -> void:
	for pill in _speed_pills:
		var value: float = float(pill.get_meta("speed_value"))
		var active: bool = is_equal_approx(game.speed, value)
		if active:
			pill.add_theme_color_override("font_color", Ui.INK)
			pill.add_theme_stylebox_override("normal",
				Ui.flat(Color(0.86, 0.72, 0.42, 0.95), Ui.GOLD_BRIGHT, 8, 2))
			pill.add_theme_stylebox_override("hover",
				Ui.flat(Color(0.92, 0.8, 0.5, 1.0), Ui.GOLD_BRIGHT, 8, 2))
		else:
			pill.add_theme_color_override("font_color", Ui.TEXT_DIM)
			pill.add_theme_stylebox_override("normal",
				Ui.flat(Color(0.06, 0.09, 0.11, 0.9), Color(0.34, 0.31, 0.25, 0.9),
					8, 1))
			pill.add_theme_stylebox_override("hover",
				Ui.flat(Color(0.14, 0.19, 0.23, 0.95), Ui.GOLD_DIM, 8, 1))
		pill.disabled = game.tutorial_active


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

	# 卡槽
	var cards = HBoxContainer.new()
	cards.add_theme_constant_override("separation", 8)
	cards.set_anchors_preset(Control.PRESET_TOP_WIDE)
	cards.anchor_left = 0.0
	cards.anchor_right = 1.0
	cards.offset_left = 300.0
	cards.offset_right = -300.0
	cards.offset_top = 18.0
	cards.offset_bottom = 130.0
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cards)
	_card_nodes.clear()
	for i in sim.cards.size():
		var card = CardButton.new()
		card.index = i
		card.card_id = String(sim.cards[i]["id"])
		card.hud = self
		card.custom_minimum_size = Vector2(78, 108)
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
	for value in (SPEEDS_TRAINING if sim.training else SPEEDS):
		var pill := Ui.button(_speed_text(value), 14, 36, 34)
		pill.set_meta("speed_value", value)
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
	_speed_label = Ui.label("×1", 17, Ui.TEXT_DIM)
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tools.add_child(_speed_label)

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
		var boss_span = float(Content.WAVES_PER_GROUP) if not bool(sim.level.get("special", false)) else 1.0
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
	if _sun_label != null:
		_sun_label.text = str(sim.sun)
	var total = int(sim.level.get("waves", []).size())
	if _wave_label != null:
		if sim.boss!=null:
			_wave_label.text="第 %d 大波 · 首领战" % Content.current_major_wave(sim.level,sim.displayed_wave_count())
		elif bool(sim.level.get("special",false)):
			_wave_label.text = "第 %d / 12 大波" % Content.current_major_wave(sim.level, sim.displayed_wave_count())
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
	if _danger!=null:
		_danger.values=[float([2.0,2.5,3.5][mini(2,sim.special_bosses_completed)])] if bool(sim.level.get("special",false)) else [float(sim.level.get("threat",0))]
		_danger.queue_redraw()
	if _wave_pips != null:
		_wave_pips.queue_redraw()
	if _speed_label != null:
		_speed_label.text = "×%s" % _format_speed(game.speed)
	_refresh_speed_pills()
	for card in _card_nodes:
		card.state = _card_state(card.index)
		card.queue_redraw()
	if _tool_shovel != null:
		Ui.set_button_active(_tool_shovel, shovel_mode)
	if _hint_label != null:
		_hint_label.text = "" if game.tutorial_active else _hint_text()
	if _banner_label != null:
		if not sim.banner.is_empty():
			var big = String(sim.banner["text"]) == "一大波恶客正在靠近"
			_banner_label.text = String(sim.banner["text"])
			_banner_label.add_theme_font_size_override("font_size", 64 if big else 46)
			var span = 0.9 if big else 0.8
			var a = clampf(float(sim.banner["t"]) / span, 0.0, 1.0)
			_banner_label.modulate.a = a
			_banner_sub.text = "第 %d 大波 / 共 %d 大波" % [int(sim.banner.get("group", 1)),
				int(sim.banner.get("groups", 4))] if big else ""
			_banner_sub.modulate.a = a
			_banner_band.visible = big
			_banner_band.modulate.a = a * 0.85
		else:
			_banner_label.modulate.a = 0.0
			_banner_sub.modulate.a = 0.0
			_banner_band.visible = false
	if sim.boss!=null:
		_banner_label.modulate.a=0.0;_banner_sub.modulate.a=0.0;_banner_band.visible=false
	if game.tutorial_active:
		_refresh_tutorial()
	if focus_plant != null and (focus_plant.dead or not sim.plants.has(focus_plant)):
		close_fan()
	elif _fan != null:
		# 只有面板内容真的变了才重建：每帧重建会让按钮在按下与松开之间被释放，点不动。
		var signature = _fan_signature()
		if signature != _fan_sig:
			_sync_fan()


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
		return "留意落点预警。首领换行后，把火力转向它所在的两行。"
	if sim.training:
		return "训练场：不刷波次、不判负、不写存档。"
	if not sim.banner.is_empty() or _banner_t > 0.0:
		return ""
	if sim.wave_index <= 1:
		return "先铺产能，再补输出，每行都留一份火力。"
	if sim.wave_index <= 4:
		return "斗笠先扣护具：石磨挡住，再交给破甲的。"
	if sim.wave_index <= 7:
		return "哭声会催快恶客——青色波纹一起就补缺路。"
	return "最后几波：门神只有一次，别让它白费。"


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
			"每周第一夜熟悉地形，第二到第四夜每天学一种应对法。第五夜恶客齐来，还要迎战首领。备战页能查今夜来客。\n实在守不住时，从暂停进设置开启「作弊菜单」，回战场点「作弊」，可慢放到 0.1× 或补香火。右侧可以先试，再翻图鉴看签筒的进化。"],
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
	focus_plant = null
	if _fan != null and is_instance_valid(_fan):
		_fan.queue_free()
	_fan = null
	_fan_rows.clear()


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
		var status = Upgrades.path_status(String(plant.type), plant.upgrades,
			int(path["id"]))
		var cost = int(status["cost"]) if bool(status["ok"]) else 0
		var tiers: Array = path["tiers"]
		var tier_now = int(status["tier"])
		var next_desc = ""
		var next_name = ""
		if bool(status["ok"]) and tier_now < tiers.size():
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
		var status = Upgrades.path_status(String(plant.type), plant.upgrades,
			int(path["id"]))
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
	if not enabled and slow_battle:
		_set_slow_battle(false)


func _toggle_cheat() -> void:
	cheat_open = not cheat_open
	if cheat_open:
		if not _opened_cheat_once and not game.sim.training and not game.tutorial_active:
			_set_slow_battle(true)
		_opened_cheat_once = true
		_build_cheat()
	elif _cheat_panel != null:
		_cheat_panel.queue_free()
		_cheat_panel = null
	refresh()


func _set_slow_battle(enabled: bool) -> void:
	slow_battle = enabled
	if enabled:
		game.sim.cheated = true
	game.apply_speed(0.1 if enabled else float(game.settings["speed"]))


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
			var day = (int(game.training.get("day", 1)) % 3) + 1
			game.training["day"] = day
			var level_id = (day - 1) * 5 + 1
			game.start_battle(level_id, game.loadout, "training")
			])
		rows.append(["退回选草", func():
			game.show_prep((int(game.training.get("day", 1)) - 1) * 5 + 1, true,
				int(game.training.get("day", 1)))])
	elif not game.tutorial_active:
		rows.push_front(["常规战斗 0.1× · %s" % ("已开" if slow_battle else "已关"), func():
			_set_slow_battle(not slow_battle)
			_build_cheat()])
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
	panel.offset_left = -230.0
	panel.offset_right = 230.0
	panel.offset_top = -188.0
	panel.offset_bottom = 188.0
	add_child(panel)
	var box = Ui.vbox(12)
	panel.add_child(box)
	var head = Ui.hbox(10)
	box.add_child(head)
	head.add_child(Ui.seal("停"))
	head.add_child(Ui.title("暂停", 40, Ui.GOLD_BRIGHT))
	box.add_child(Ui.label("这一夜还长，喘口气再守。", 17, Ui.TEXT_DIM))
	box.add_child(Ui.hline(Ui.GOLD_DIM, 1.0))
	var resume_button = Ui.button("重返游戏", 28, 380, 72, true)
	resume_button.pressed.connect(resume)
	box.add_child(resume_button)
	var tools = Ui.hbox(12)
	box.add_child(tools)
	var almanac = Ui.button("查看图鉴", 19, 180, 49)
	almanac.pressed.connect(func(): game.open_almanac("plant", 0))
	tools.add_child(almanac)
	var settings = Ui.button("设置", 19, 180, 49)
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
	panel.offset_left = -320.0
	panel.offset_right = 320.0
	panel.offset_top = -230.0
	panel.offset_bottom = 230.0
	add_child(panel)
	var box = Ui.vbox(10)
	panel.add_child(box)
	var head = Ui.hbox(14)
	box.add_child(head)
	head.add_child(Ui.seal("胜" if won else "败"))
	var titles = Ui.vbox(0)
	head.add_child(titles)
	titles.add_child(Ui.title("守住了" if won else "失守", 44,
		Ui.GOLD_BRIGHT if won else Ui.BAD))
	var level = Content.get_level(int(result.get("level_id", 1)))
	var subtitle = "%s·%s · %s" % [level["day_name"], level["day_sub"], level["name"]]
	if bool(result.get("tutorial", false)):
		subtitle = "新手教程"
	elif bool(result.get("training", false)):
		subtitle = "训练场"
	titles.add_child(Ui.label(subtitle, 18, Ui.TEXT_DIM))
	box.add_child(Ui.hline(Ui.GOLD_DIM, 1.0))

	var stats = GridContainer.new()
	stats.columns = 2
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.add_theme_constant_override("h_separation", 24)
	stats.add_theme_constant_override("v_separation", 10)
	box.add_child(stats)
	var seconds = float(result.get("time", 0.0))
	var stat_rows = [
		["用时", "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]],
		["击退", str(int(result.get("kills", 0)))],
		["余香", str(int(result.get("sun", 0)))],
	]
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
		var value = Ui.strong(String(row[1]), 24, Ui.GOLD_BRIGHT)
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats.add_child(value)
	box.add_child(Ui.spacer(6))
	var comment = ""
	if bool(result.get("tutorial", false)):
		comment = "灯、签、磨都齐了。十五夜还长，慢慢守。"
	elif won:
		comment = "灯还亮着，今夜收摊。"
	else:
		comment = _loss_advice(summary, breached_rows)
	var comment_label = Ui.label(comment, 18, Ui.TEXT)
	comment_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(comment_label)
	box.add_child(Ui.spacer(8))

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
			var next_level = mini(int(result.get("level_id", 1)) + 1,
				Content.LEVELS.size())
			var next = Ui.button("下一夜", 23, 224, 56, true)
			next.disabled = int(result.get("level_id", 1)) >= Content.LEVELS.size()
			next.pressed.connect(func(): game.show_prep(next_level))
			row1.add_child(next)
		var select = Ui.button("换一夜", 17, 132, 44)
		select.pressed.connect(func(): game.show_levels())
		row1.add_child(select)
	var row2 = Ui.hbox(12)
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
	var icon: Texture2D = null

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		# 贴图在 _ready 里取一次；在 _draw() 里临时 load 会画出白块。
		icon = Ui.sprite(card_id)
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
			hud._on_card(index)

	func _draw() -> void:
		var rect = Rect2(Vector2.ZERO, size)
		var sim: Sim = hud.game.sim
		var def: Dictionary = Content.PLANTS[card_id]
		var base = Color(0.06, 0.10, 0.12, 0.92)
		if bool(state.get("selected", false)):
			base = Color(0.22, 0.16, 0.08, 0.96)
		elif hovered:
			base = Color(0.12, 0.18, 0.21, 0.95)
		var border = Ui.GOLD if bool(state.get("selected", false)) else (
			Ui.GOLD_DIM if hovered else Color(0.32, 0.29, 0.23, 0.9))
		Ui.draw_plate(self, rect, base, border, 14, 2)
		if bool(state.get("taught", false)):
			# 这一步该点哪张牌：金框呼吸 + 牌底一个向上的箭头
			var beat = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 260.0)
			Ui.draw_plate(self, rect.grow(2.0), Color.TRANSPARENT,
				Color(1.0, 0.85, 0.42, 0.45 + beat * 0.5), 16, 3)
			var cx = rect.size.x * 0.5
			var lift = 6.0 + beat * 5.0
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx, rect.size.y + 4.0 - lift),
				Vector2(cx - 8.0, rect.size.y + 16.0 - lift),
				Vector2(cx + 8.0, rect.size.y + 16.0 - lift)]),
				Color(1.0, 0.85, 0.42, 0.55 + beat * 0.45))
		# 立绘
		var tint = Color(1, 1, 1, 1.0 if bool(state.get("affordable", true)) else 0.45)
		Ui.draw_plant_icon(self, card_id, Rect2(6, 8, rect.size.x - 12,
			rect.size.y - 40), tint)
		# 名称与费用
		var font = Ui.body_font()
		var name_text = String(def["name"])
		var width = font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string(font, Vector2((rect.size.x - width) * 0.5, rect.size.y - 22),
			name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Ui.TEXT)
		var cost_text = str(int(def["cost"]))
		var cost_width = font.get_string_size(cost_text, HORIZONTAL_ALIGNMENT_LEFT,
			-1, 16).x
		var cost_color = Ui.GOLD_BRIGHT if bool(state.get("affordable", true)) \
			else Ui.BAD
		draw_string(font, Vector2((rect.size.x - cost_width) * 0.5, rect.size.y - 6),
			cost_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, cost_color)
		# 冷却遮罩
		var cd = float(state.get("cooldown", 0.0))
		if cd > 0.05:
			var ratio = clampf(cd / float(state.get("cooldown_max", 1.0)), 0.0, 1.0)
			Ui.draw_plate(self, Rect2(0, 0, rect.size.x, rect.size.y * ratio),
				Color(0.02, 0.03, 0.05, 0.68), Color.TRANSPARENT, 14, 0)
		if not bool(state.get("affordable", true)):
			Ui.draw_plate(self, rect, Color(0.02, 0.03, 0.05, 0.22), Color.TRANSPARENT, 14, 0)
