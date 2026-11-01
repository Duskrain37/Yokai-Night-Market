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
var cheat_tab = "misc"
var spawn_type = "ghost"
var spawn_count = 1
var spawn_lane = -1
var _hover_card = -1

var _sun_label: Label = null
var _wave_label: Label = null
var _hint_label: Label = null
var _banner_label: Label = null
var _banner_t = 0.0
var _card_nodes: Array = []
var _tool_wave: Button = null
var _tool_shovel: Button = null
var _tool_cheat: Button = null
var _speed_label: Label = null
var _fan_panel: PanelContainer = null
var _fan_rows: Array = []
var _cheat_panel: PanelContainer = null
var _tutorial_panel: PanelContainer = null
var _tutorial_label: Label = null
var _tutorial_dots: Control = null
var _wave_pips: Control = null
var _tooltip: Label = null


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
	_wave_label = Ui.label("第 1 / 12 波", 17, Ui.TEXT)
	sun_text.add_child(_wave_label)

	_wave_pips = Control.new()
	_wave_pips.custom_minimum_size = Vector2(120, 150)
	_wave_pips.draw.connect(_draw_wave_pips)
	left.add_child(_wave_pips)

	_hint_label = Ui.label("", 17, Ui.TEXT_DIM)
	_hint_label.custom_minimum_size = Vector2(270, 0)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_hint_label)

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
	_tool_shovel = _tool_button("铲子", "铲除草木；龟甲可单独拆", func(): _on_shovel())
	tools.add_child(_tool_shovel)
	if bool(game.settings.get("cheats", false)) or sim.training:
		_tool_cheat = _tool_button("作弊", "杂项与召唤", func(): _toggle_cheat())
		tools.add_child(_tool_cheat)
	var pause_button = _tool_button("暂停", "Esc 暂停", func(): game.toggle_pause())
	tools.add_child(pause_button)
	_speed_label = Ui.label("×1", 17, Ui.TEXT_DIM)
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tools.add_child(_speed_label)

	# 横幅
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
	_tutorial_panel.offset_top = -118.0
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
	var quit = Ui.button("退出教程", 16, 110, 40)
	quit.pressed.connect(func(): game.back_to_menu())
	row.add_child(quit)


func _draw_tutorial_dots() -> void:
	var sim: Sim = game.sim
	if sim == null or sim.tutorial == null:
		return
	var step = String(sim.tutorial["step"])
	var order = ["collect", "plant", "upgrade", "battle", "finishing", "done"]
	var index = order.find(step)
	for i in order.size():
		var color = Ui.GOLD if i <= index else Color(1, 1, 1, 0.25)
		_tutorial_dots.draw_circle(Vector2(8 + i * 22, 6), 5.0, color)


func _draw_wave_pips() -> void:
	var sim: Sim = game.sim
	if sim == null:
		return
	var total = int(sim.level.get("waves", []).size())
	if total == 0:
		return
	for i in total:
		var y = 4.0 + i * 12.0
		var flag = bool(sim.level["waves"][i].get("flag", false))
		var done = i < sim.wave_index
		var color = Color(1, 1, 1, 0.16)
		if done:
			color = Color(Ui.GOLD_DIM.r, Ui.GOLD_DIM.g, Ui.GOLD_DIM.b, 0.9)
		elif i == sim.wave_index:
			color = Ui.GOLD_BRIGHT
		var width = 22.0 if flag else 14.0
		_wave_pips.draw_rect(Rect2(4, y, width, 5.0), color)


# ── 刷新 ────────────────────────────────────────────────────────────────────
func refresh() -> void:
	var sim: Sim = game.sim
	if sim == null or result_mode:
		return
	if _sun_label != null:
		_sun_label.text = str(sim.sun)
	var total = int(sim.level.get("waves", []).size())
	if _wave_label != null:
		if sim.training:
			_wave_label.text = "训练场 · 手动召唤"
		elif total == 0:
			_wave_label.text = "教学关"
		else:
			_wave_label.text = "第 %d / %d 波" % [mini(sim.wave_index + 1, total), total]
	if _wave_pips != null:
		_wave_pips.queue_redraw()
	if _speed_label != null:
		_speed_label.text = "×%s" % _format_speed(game.speed)
	for card in _card_nodes:
		card.state = _card_state(card.index)
		card.queue_redraw()
	if _tool_shovel != null:
		_tool_shovel.add_theme_color_override("font_color",
			Ui.GOLD_BRIGHT if shovel_mode else Ui.TEXT)
	if _hint_label != null:
		_hint_label.text = _hint_text()
	if _banner_label != null:
		if not sim.banner.is_empty():
			_banner_label.text = String(sim.banner["text"])
			_banner_label.modulate.a = clampf(float(sim.banner["t"]) / 0.8, 0.0, 1.0)
		else:
			_banner_label.modulate.a = 0.0
	if game.tutorial_active:
		_refresh_tutorial()
	if focus_plant != null and (focus_plant.dead or not sim.plants.has(focus_plant)):
		close_fan()
	elif _fan_panel != null:
		_rebuild_fan()


func _format_speed(value: float) -> String:
	if is_equal_approx(value, round(value)):
		return str(int(round(value)))
	return "%s" % String.num(value, 1)


func _hint_text() -> String:
	var sim: Sim = game.sim
	if sim.training:
		return "训练场：不刷波次、不判负、不写存档。"
	if not sim.banner.is_empty() or _banner_t > 0.0:
		return ""
	if sim.wave_index <= 1:
		return "先铺产能，再补输出；每条路都留一份火力。"
	if sim.wave_index <= 4:
		return "护甲要磨：斗笠鬼先扣护具，用石磨挡住再破甲。"
	if sim.wave_index <= 7:
		return "哭声会催快恶客，青色波纹一起，就该补缺路。"
	return "守住最后几波：门神只有一次，别让它白费。"


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
	}


func _refresh_tutorial() -> void:
	var sim: Sim = game.sim
	if sim.tutorial == null:
		return
	var step = String(sim.tutorial["step"])
	var cost = Upgrades.tier_cost("shooter", 1, 1)
	var copy = {
		"collect": ["第一步 · 收下这团香火",
			"街上那团金色的是香火，点一下收下。教学里的这团不会自己消失。"],
		"plant": ["第二步 · 请一株签筒出摊",
			"点右下角的「签筒」牌，再点后排空格放下它。签筒只打本行前方。"],
		"upgrade": ["第三步 · 给签筒升阶",
			"点已种下的签筒，在「连发」一行按「%d 香火」升到一级。" % cost],
		"battle": ["第四步 · 看它自己出手",
			"恶客从右边过来，签筒会自动瞄准开火；等这一只被击退。"],
		"finishing": ["成了", "这一夜的第一课，你已经学会了。"],
		"done": ["这一课成了", "灯、签、磨三样都在手上了。"],
	}
	var entry: Array = copy.get(step, ["", ""])
	if _tutorial_label != null:
		_tutorial_label.text = "%s\n%s" % [entry[0], entry[1]]
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
		if step == "plant" and String(sim.cards[index]["id"]) != "shooter":
			sim.deny("先种下签筒", _mouse())
			return
	card_selected = -1 if card_selected == index else index
	shovel_mode = false
	game.play_sfx("click")
	refresh()


func _on_shovel() -> void:
	shovel_mode = not shovel_mode
	card_selected = -1
	close_fan()
	game.play_sfx("click")
	refresh()


func _on_quick_wave() -> void:
	var sim: Sim = game.sim
	if sim == null:
		return
	if not sim.summon_next_wave():
		sim.deny("已无后续波次", _mouse())
	refresh()


func cancel_selection() -> void:
	card_selected = -1
	shovel_mode = false
	close_fan()
	refresh()


func try_open_menu(plant, at: Vector2) -> void:
	var sim: Sim = game.sim
	if plant == null:
		return
	if game.tutorial_active:
		var step = sim.tutorial_step()
		if step == "plant":
			sim.deny("先种下签筒", at)
			return
		if step == "upgrade" and plant != sim.tutorial["shooter"]:
			sim.deny("先给签筒升阶", at)
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
	if _fan_panel != null and is_instance_valid(_fan_panel):
		_fan_panel.queue_free()
	_fan_panel = null
	_fan_rows.clear()


func _build_fan(plant, at: Vector2) -> void:
	close_fan()
	focus_plant = plant
	_fan_panel = Ui.panel(0.94)
	_fan_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_fan_panel)
	_fan_panel.add_child(Ui.vbox(6))
	_rebuild_fan()
	_layout_fan(at)


func _rebuild_fan() -> void:
	if _fan_panel == null or not is_instance_valid(_fan_panel):
		return
	var plant = focus_plant
	if plant == null:
		return
	var sim: Sim = game.sim
	var box: VBoxContainer = _fan_panel.get_child(0)
	for child in box.get_children():
		child.queue_free()
	var header = Ui.hbox(10)
	box.add_child(header)
	header.add_child(Ui.strong(String(plant.def["name"]), 22, Ui.GOLD_BRIGHT))
	header.add_child(Ui.label("%d / %d" % [int(ceil(plant.hp)), int(plant.max_hp)], 16,
		Ui.GOOD))
	if plant.shell > 0.0:
		header.add_child(Ui.label("龟甲 %d" % int(ceil(plant.shell)), 16, Ui.JADE_LIGHT))
	box.add_child(Ui.hline(Ui.GOLD_DIM, 1.0))
	var paths = Upgrades.paths_for(String(plant.type))
	if paths.is_empty():
		box.add_child(Ui.label("此物无法升阶", 17, Ui.TEXT_DIM))
		return
	for path in paths:
		var path_id = int(path["id"])
		var status = Upgrades.path_status(String(plant.type), plant.upgrades, path_id)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		box.add_child(row)
		var dot = Control.new()
		dot.custom_minimum_size = Vector2(12, 12)
		dot.size = Vector2(12, 12)
		var color = Color(String(path["color"]))
		dot.draw.connect(func(): dot.draw_circle(Vector2(6, 9), 5.0, color))
		row.add_child(dot)
		var info = Ui.vbox(0)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var title = "%s · %d 级" % [String(path["name"]), int(status["tier"])]
		info.add_child(Ui.strong(title, 17, Ui.TEXT))
		var line = ""
		if bool(status["ok"]):
			line = "%s：%s" % [String(status["name"]), String(status["desc"])]
		else:
			line = String(status["reason"])
		var body = Ui.label(line, 15, Ui.TEXT_DIM)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size = Vector2(300, 0)
		info.add_child(body)
		if bool(status["ok"]):
			var cost = int(status["cost"])
			var affordable = sim.sun >= cost
			var button = Ui.button("%d 香火" % cost, 16, 96, 34)
			button.disabled = not affordable
			if not affordable:
				button.tooltip_text = "香火不足"
			button.pressed.connect(func(): _on_upgrade(plant, path_id))
			row.add_child(button)
		else:
			var locked = Ui.label("已锁", 16, Ui.TEXT_FAINT)
			row.add_child(locked)


func _layout_fan(at: Vector2) -> void:
	if _fan_panel == null:
		return
	_fan_panel.reset_size()
	await get_tree().process_frame
	if _fan_panel == null or not is_instance_valid(_fan_panel):
		return
	var size = _fan_panel.get_combined_minimum_size()
	var pos = at + Vector2(40, -size.y * 0.5)
	if pos.x + size.x > 1600.0 - 20.0:
		pos.x = at.x - size.x - 40.0
	pos.y = clampf(pos.y, 120.0, 900.0 - size.y - 20.0)
	pos.x = clampf(pos.x, 20.0, 1600.0 - size.x - 20.0)
	_fan_panel.position = pos


func _on_upgrade(plant, path_id: int) -> void:
	var sim: Sim = game.sim
	if sim == null:
		return
	var outcome = sim.try_upgrade(plant, path_id, _mouse())
	if bool(outcome["ok"]):
		if game.tutorial_active and sim.tutorial_step() == "battle":
			close_fan()
		_rebuild_fan()
		_layout_fan(Vector2(plant.pos.x, plant.pos.y))
	refresh()


func _mouse() -> Vector2:
	return get_viewport().get_mouse_position()


# ── 作弊 ────────────────────────────────────────────────────────────────────
func blocks_simulation() -> bool:
	return cheat_open


func _toggle_cheat() -> void:
	cheat_open = not cheat_open
	if cheat_open:
		_build_cheat()
	elif _cheat_panel != null:
		_cheat_panel.queue_free()
		_cheat_panel = null


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
				tab.add_theme_color_override("font_color", Ui.GOLD_BRIGHT)
			tabs.add_child(tab)
	if sim.training and cheat_tab == "spawn":
		_build_spawn_tab(box)
	else:
		_build_misc_tab(box)


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
	else:
		rows.append(["直接结算为胜", func():
			game.finish_run(true)])
	for row in rows:
		var button = Ui.button(String(row[0]), 18, 360, 40)
		button.pressed.connect(row[1])
		box.add_child(button)
	var close = Ui.button("关闭", 17, 360, 36)
	close.pressed.connect(_toggle_cheat)
	box.add_child(close)


func _build_spawn_tab(box: VBoxContainer) -> void:
	var sim: Sim = game.sim
	box.add_child(Ui.label("选恶客", 16, Ui.TEXT_DIM))
	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	for type in Content.ZOMBIE_ORDER:
		var button = Ui.button(String(Content.ZOMBIES[type]["name"]), 15, 84, 34)
		if type == spawn_type:
			button.add_theme_color_override("font_color", Ui.GOLD_BRIGHT)
		button.pressed.connect(func():
			spawn_type = type
			_build_cheat())
		grid.add_child(button)
	box.add_child(Ui.label("数量", 16, Ui.TEXT_DIM))
	var counts = Ui.hbox(6)
	box.add_child(counts)
	for value in [1, 3, 5, 10]:
		var button = Ui.button(str(value), 16, 60, 32)
		if spawn_count == value:
			button.add_theme_color_override("font_color", Ui.GOLD_BRIGHT)
		button.pressed.connect(func():
			spawn_count = value
			_build_cheat())
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
			button.add_theme_color_override("font_color", Ui.GOLD_BRIGHT)
		button.pressed.connect(func():
			spawn_lane = lane
			_build_cheat())
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
	panel.offset_top = -230.0
	panel.offset_bottom = 230.0
	add_child(panel)
	var box = Ui.vbox(12)
	panel.add_child(box)
	var head = Ui.hbox(10)
	box.add_child(head)
	head.add_child(Ui.seal("停"))
	head.add_child(Ui.title("暂停", 40, Ui.GOLD_BRIGHT))
	box.add_child(Ui.label("这一夜还长，喘口气再守。", 17, Ui.TEXT_DIM))
	box.add_child(Ui.hline(Ui.GOLD_DIM, 1.0))
	var buttons = [
		["继续守夜", func(): resume()],
		["重新开始这一夜", func(): game.restart_run()],
		["查看图鉴", func(): game.open_almanac("plant", 0)],
		["设置", func(): game.open_settings()],
		["回到封面", func(): game.back_to_menu()],
	]
	for row in buttons:
		var button = Ui.button(String(row[0]), 19, 380, 46)
		button.pressed.connect(row[1])
		box.add_child(button)
	var footer = Ui.hbox(10)
	box.add_child(footer)
	var mute = Ui.button("静音切换", 16, 180, 36)
	mute.pressed.connect(func():
		game.set_setting("sound", not bool(game.settings["sound"])))
	footer.add_child(mute)
	var speed_button = Ui.button("战斗速度 ×%s" % _format_speed(game.speed), 16, 190, 36)
	speed_button.pressed.connect(func():
		var options = [1.0, 1.5, 2.0, 3.0]
		var index = options.find(game.speed)
		game.speed = options[(index + 1) % options.size()]
		speed_button.text = "战斗速度 ×%s" % _format_speed(game.speed))
	footer.add_child(speed_button)


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
	stats.columns = 3
	stats.add_theme_constant_override("h_separation", 40)
	stats.add_theme_constant_override("v_separation", 10)
	box.add_child(stats)
	var seconds = float(result.get("time", 0.0))
	var stat_rows = [
		["用时", "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]],
		["击退", str(int(result.get("kills", 0)))],
		["余香", str(int(result.get("sun", 0)))],
	]
	for row in stat_rows:
		stats.add_child(Ui.label(String(row[0]), 17, Ui.TEXT_DIM))
		stats.add_child(Ui.strong(String(row[1]), 24, Ui.GOLD_BRIGHT))
		stats.add_child(Ui.label("", 10))
	box.add_child(Ui.spacer(6))
	var comment = ""
	if bool(result.get("tutorial", false)):
		comment = "灯、签、磨都齐了。十五夜还长，慢慢守。"
	elif won:
		comment = "灯还亮着，今夜收摊。"
	else:
		comment = "门神用完了，这一路被穿了过去。补一株石磨再试。"
	var comment_label = Ui.label(comment, 18, Ui.TEXT)
	comment_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(comment_label)
	box.add_child(Ui.spacer(8))

	var row1 = Ui.hbox(12)
	box.add_child(row1)
	if bool(result.get("tutorial", false)):
		var again = Ui.button("再练一次", 19, 200, 46)
		again.pressed.connect(func(): game.start_battle(0, ["shooter"], "tutorial"))
		row1.add_child(again)
		var done = Ui.button("回到封面", 19, 200, 46)
		done.pressed.connect(func(): game.back_to_menu())
		row1.add_child(done)
	else:
		var retry = Ui.button("再来一次", 19, 190, 46)
		retry.pressed.connect(func(): game.restart_run())
		row1.add_child(retry)
		if won:
			var next_level = mini(int(result.get("level_id", 1)) + 1,
				Content.LEVELS.size())
			var next = Ui.button("下一夜", 19, 190, 46)
			next.disabled = int(result.get("level_id", 1)) >= Content.LEVELS.size()
			next.pressed.connect(func(): game.show_prep(next_level))
			row1.add_child(next)
		var select = Ui.button("换一夜", 19, 190, 46)
		select.pressed.connect(func(): game.show_levels())
		row1.add_child(select)
	var row2 = Ui.hbox(12)
	box.add_child(row2)
	var almanac = Ui.button("图鉴", 17, 140, 38)
	almanac.pressed.connect(func(): game.open_almanac("plant", 0))
	row2.add_child(almanac)
	var menu = Ui.button("回到封面", 17, 180, 38)
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
		draw_rect(rect, base)
		draw_rect(rect, border, false, 2.0)
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
			draw_rect(Rect2(0, 0, rect.size.x, rect.size.y * ratio),
				Color(0.02, 0.03, 0.05, 0.68))
		if not bool(state.get("affordable", true)):
			draw_rect(rect, Color(0.02, 0.03, 0.05, 0.35))
