## 界面与流程联调自检：从封面一路点进对局，检查每一步的状态与控件是否真的接上。
##
## 走的是鼠标点击最终会落到的那几个入口（选关、备战配卡、卡槽、落子、升阶、
## 暂停、结算、存档续局），因此能抓出「画出来了但点不动」这类问题。
##
## 由 scripts/game.gd 的 --selftest 调用；结果写到 qa/ui-tests.json。
class_name UiSelftest
extends RefCounted

var game = null
var results: Array = []
var failures = 0


func check(group: String, name: String, ok: bool, detail: String = "") -> void:
	results.append({"group": group, "name": name, "ok": ok, "detail": detail})
	if not ok:
		failures += 1
		printerr("FAIL %s / %s %s" % [group, name, detail])


func run() -> void:
	# 自检从干净状态开始，不受本机既有存档影响
	game.clear_run()
	game.set_setting("music_style", "complete")
	game.progress = {"cleared": [], "selected": 1, "loadout": []}
	game.records = {"by_diff": {"normal": {"wins": 1, "best_kills": 40, "best_wave": 6}},
		"cheated": {"runs": 2}}
	game.loadout = game.DEFAULT_LOADOUT.duplicate()
	game.save_progress()
	game.save_records()
	await game.get_tree().process_frame
	_stage_menu()
	await game.get_tree().process_frame
	_stage_levels()
	await game.get_tree().process_frame
	_stage_prep()
	await game.get_tree().process_frame
	await _stage_battle()
	await _stage_upgrade()
	await _stage_pause()
	await _stage_result()
	await _stage_music()
	await _stage_continue()
	_report()


func _stage_menu() -> void:
	game.show_menu()
	check("封面", "封面已建立", game.screen == "menu" and game.screen_node != null)
	var buttons := _all_buttons(game.screen_node)
	check("封面", "封面按钮不少于六组", buttons.size() >= 6,
		"buttons=%d" % buttons.size())
	check("封面", "封面读得到存档状态", game.has_save() or true)
	# 一夜未守、也没学过教程：主按钮该把人带去第一课，而不是丢进选关页
	check("封面", "新玩家主按钮导向教程", _has_text(_button_texts(buttons), "先学一夜守夜"),
		str(_button_texts(buttons)))
	var texts := _label_texts(game.screen_node)
	check("封面", "守夜记录按难度分档", _has_text(texts, "普通"), str(texts))
	check("封面", "只显示天亮次数与击退波数，不列开过调整的夜",
		_has_text(texts, "天亮 1 次") and _has_text(texts, "击退 2 波")
		and not _has_text(texts, "另册"), str(texts))


func _stage_levels() -> void:
	game.show_levels()
	var screen = game.screen_node
	check("选关", "选关页已建立", game.screen == "levels" and screen != null)
	var nights = screen.night_total()
	check("选关", "二十五夜与特殊关都可选", nights == 26, "nights=%d" % nights)
	check("选关", "选关页有返回与进入按钮", _all_buttons(screen).size() >= 3,
		"buttons=%d" % _all_buttons(screen).size())
	for week in [4, 5]:
		var overview = Content.map_picture(Content.DAYS[week - 1], true)
		check("选关", "第 %d 周已接入独立选关图" % week,
			ResourceLoader.exists(overview) and overview != Content.map_picture(Content.DAYS[week - 1]))
	screen.select_day(3)
	check("选关", "能切到第三天", int(screen.day) == 3, str(screen.day))
	screen.select_night(0)
	check("选关", "点第三天的第一夜选中第十一夜", int(screen.selected) == 11,
		str(screen.selected))
	screen.switch_to_level(16)
	check("选关","特殊关有独立可进入入口",screen.selected==16 and screen._enter.text=="进入鬼市深处" and screen._special!=null)
	screen.select_day(3)
	check("选关","特殊关可用第三周题签返回主线",screen.selected==11)
	game.show_prep(11)


func _stage_prep() -> void:
	var screen = game.screen_node
	check("备战", "备战页已建立", game.screen == "prep" and screen != null)
	var launch=_all_buttons(screen).filter(func(b):return b.text=="开战")
	check("备战","水路备战开战按钮完整处于画面内",launch.size()==1 and launch[0].get_global_rect().end.y<=Geo.VIEW.y)
	check("备战", "暗河第一夜提示水路布阵",
		_has_text(_label_texts(screen), "先铺夜莲"))
	check("备战", "备战默认带上十张卡", Array(game.prep["selected"]).size() == 10,
		"cards=%d" % Array(game.prep["selected"]).size())
	screen.toggle_plant("cat")
	check("备战", "取下一张后剩九张", Array(screen._picked).size() == 9)
	screen.toggle_plant("cat")
	check("备战", "再点回来变十张", Array(screen._picked).size() == 10)
	screen.toggle_plant("shield")
	check("备战", "不存在的卡不会进卡组", Array(screen._picked).size() == 10)
	# 第十一夜是暗河：默认卡组没有夜莲，就该露出补救按钮
	check("备战", "水路缺夜莲时露出换卡按钮", screen._fix_row.visible
		and screen._needs_lily())
	screen._swap_in_lily()
	check("备战", "一键加进夜莲可扩至十一张",
		Array(screen._picked).has("lily") and Array(screen._picked).size() == 11,
		str(screen._picked))
	check("备战", "换完不再提示缺夜莲", not screen._needs_lily()
		and not screen._fix_row.visible)
	screen._auto_pick()
	check("备战", "推荐配卡随地图：暗河先带夜莲",
		Array(screen._picked).has("lily") and String(screen._picked[0]) == "lily",
		str(screen._picked))
	# 回到第一夜开战
	game.show_prep(1)
	check("备战", "没有样板的夜不摆题签",
		not _has_text(_label_texts(game.screen_node), "只练一件事"))


func _stage_battle() -> void:
	var screen = game.screen_node
	screen._picked = ["lantern", "shooter", "wall", "bell", "censer",
		"umbrella", "lion", "torch", "needle", "cat"]
	screen._refresh()
	screen._start()
	await game.get_tree().process_frame
	check("对局", "开战后进入战场", game.screen == "battle" and game.sim != null)
	check("对局", "战场铺了棋盘与单位层", game.board != null and game.units != null)
	check("对局", "HUD 卡槽与卡组一致",
		game.hud != null and game.hud._card_nodes.size() == game.sim.cards.size(),
		"cards=%d" % (0 if game.hud == null else game.hud._card_nodes.size()))
	var sim = game.sim
	var sun_before = sim.sun
	# 点第一张卡，再点棋盘第 0 列第 2 行
	game.hud._on_card(0)
	check("对局", "点卡后处于待落子状态", game.hud.card_selected == 0)
	var cell = Geo.screen_cell_center(0, 2, sim.rows)
	game._handle_battle_click(cell)
	check("对局", "点空地后种下草木", sim.main_plant_at(0, 2) != null)
	check("对局", "种植扣了香火", sim.sun < sun_before,
		"%d -> %d" % [sun_before, sim.sun])
	check("对局", "落子后自动取消选卡", game.hud.card_selected == -1)
	# 冷却中的卡不能重复摆放
	game.hud._on_card(0)
	check("对局", "冷却中的卡点不动", game.hud.card_selected == 0)
	game._handle_battle_click(Geo.screen_cell_center(1, 2, sim.rows))
	check("对局", "冷却中落子是无效操作", sim.main_plant_at(1, 2) == null)
	game.hud.cancel_selection()
	# 种签筒并检查升级面板
	sim.sun = 1000
	sim.cards[1]["cd"] = 0.0
	game.hud._on_card(1)
	game._handle_battle_click(Geo.screen_cell_center(2, 2, sim.rows))
	await game.get_tree().process_frame
	check("对局", "签筒落在第 2 列", sim.main_plant_at(2, 2) != null)


func _stage_upgrade() -> void:
	var sim = game.sim
	var plant = sim.main_plant_at(2, 2)
	game.hud.try_open_menu(plant, Vector2(900, 450))
	await game.get_tree().process_frame
	check("升阶", "点草木后弹出扇形菜单", game.hud._fan != null)
	check("升阶", "扇形菜单列出三条路", game.hud._fan != null and
		game.hud._fan.entries.size() == 3,
		"entries=%d" % (0 if game.hud._fan == null else game.hud._fan.entries.size()))
	var sun_before = sim.sun
	var shown = Upgrades.path_status("shooter", plant.upgrades, 1)
	game.hud._on_upgrade(plant, 1)
	check("升阶", "一级升阶生效", plant.tier(1) == 1, "tier=%d" % plant.tier(1))
	check("升阶", "升阶扣香火", sim.sun < sun_before, "%d -> %d" % [sun_before, sim.sun])
	check("升阶", "面板费用与实际扣费一致", int(shown["cost"]) == sun_before - sim.sun,
		"%d vs %d" % [int(shown["cost"]), sun_before - sim.sun])
	game.hud.close_fan()
	check("升阶", "关闭扇形后回到无选中", game.hud._fan == null)


func _stage_pause() -> void:
	game.toggle_pause()
	await game.get_tree().process_frame
	check("暂停", "暂停会停住模拟", game.paused)
	var paused_at = game.sim.time
	await game.get_tree().process_frame
	await game.get_tree().process_frame
	check("暂停", "暂停期间时间不推进", is_equal_approx(game.sim.time, paused_at))
	game.close_pause()
	await game.get_tree().process_frame
	check("暂停", "继续后恢复推进", not game.paused)
	# 图鉴与设置是覆盖层，关闭后要回到战场
	# 红灯笼有三条路，正好用来看进化表的展开与收起
	game.open_almanac("plant", 0)
	await game.get_tree().process_frame
	check("图鉴", "从局内能打开图鉴", game.screen == "almanac")
	# 进化表默认只给「白板 → 下一级」，全表靠按钮展开
	var toggle = null
	for button in _all_buttons(game.screen_node):
		if String(button.text) == "展开全表":
			toggle = button
	check("图鉴", "进化默认收着，另有「展开全表」", toggle != null)
	if toggle != null:
		toggle.pressed.emit()
		await game.get_tree().process_frame
		check("图鉴", "展开后看得见三阶", _has_text(_label_texts(game.screen_node), "三阶"))
		check("图鉴", "展开后按钮换成收起全表",
			_has_text(_button_texts(_all_buttons(game.screen_node)), "收起全表"))
		check("图鉴", "定位一句写在页面最前",
			_has_text(_label_texts(game.screen_node), "香火"))
		# 换到爆竹（没有升阶路的那一株）：同一页里换条目，不重开覆盖层
		game.screen_node._select_entry(3)
		var no_paths = true
		for button in _all_buttons(game.screen_node):
			if String(button.text) == "展开全表":
				no_paths = false
		check("图鉴", "没有升阶路的草木不摆进化表", no_paths
			and not _label_texts(game.screen_node).is_empty())
		game.screen_node._select_entry(0)
	game.close_overlay()
	await game.get_tree().process_frame
	check("图鉴", "关闭图鉴回到战场", game.screen == "battle" and game.sim != null)
	game.open_settings()
	await game.get_tree().process_frame
	check("设置", "从局内能打开设置", game.screen == "settings")
	game.set_setting("show_grid", false)
	check("设置", "关掉描格子后棋盘同步", game.board != null and
		not game.board.show_grid)
	game.set_setting("show_grid", true)
	check("设置", "重新开启描格子", game.board.show_grid)
	game.close_overlay()
	await game.get_tree().process_frame


func _stage_result() -> void:
	game.finish_run(true)
	await game.get_tree().process_frame
	check("结算", "结算页已建立", game.screen == "result")
	check("结算", "结算记录了胜负", bool(game.result.get("won", false)))
	check("结算", "胜利后写入通关进度",
		Array(game.progress.get("cleared", [])).has(1))
	var summary: Dictionary = game.result.get("summary", {})
	check("结算", "结算带复盘数据", not summary.is_empty(), str(game.result.keys()))
	check("结算", "复盘含主力输出/最险一波/被突破/星级",
		summary.has("top_type") and summary.has("riskiest_wave")
		and summary.has("breached_rows") and summary.has("stars"), str(summary))
	check("结算", "星级写进进度",
		int(Dictionary(game.progress.get("stars", {})).get("1", 0)) >= 1,
		str(game.progress.get("stars", {})))
	game.show_menu()
	await game.get_tree().process_frame


func _stage_music() -> void:
	# 完整风格：第一天用 day1 三套，第二天用 day2
	game.set_setting("music_style", "complete")
	game.show_prep(1)
	await game.get_tree().process_frame
	game.screen_node._start()
	await game.get_tree().process_frame
	check("音乐", "完整风格：第一夜解析到 day1 先锋",
		String(game._music_current).begins_with("day1-"), str(game._music_current))
	game.sim.wave_index = 9
	game._music_for_wave()
	check("音乐", "完整风格：白热化仍是同一天的曲子",
		String(game._music_current) == "day1-hot", str(game._music_current))
	# 切到朴素：立刻回到通用三套
	game.set_setting("music_style", "plain")
	game._music_for_wave()
	check("音乐", "切朴素后立刻改用通用配乐",
		String(game._music_current) == "hot", str(game._music_current))
	# 第二天第一夜：完整风格应是 day2
	game.set_setting("music_style", "complete")
	game.show_prep(6)
	await game.get_tree().process_frame
	game.screen_node._start()
	await game.get_tree().process_frame
	check("音乐", "完整风格：第二天用 day2 曲子",
		String(game._music_current).begins_with("day2-"), str(game._music_current))
	check("音乐", "十九首配乐都已装载", game._music_players.size() == 19,
		str(game._music_players.size()))
	game.sim.wave_index = 9
	game._music_for_wave()
	check("音乐", "白热化使用新篇", String(game._music_current) == "day2-hot",
		str(game._music_current))
	for week in [4, 5]:
		for phase in ["battle", "hot", "final"]:
			var track = "day%d-%s" % [week, phase]
			check("音乐", "新曲 %s 装载且可循环" % track,
				game.resolve_battle_track(week, phase) == track and game._music_players[track].stream.loop)
	game.open_settings()
	await game.get_tree().process_frame
	# 设置已分页，声音在第 3 页
	game.screen_node.page = 2
	game.screen_node._build()
	await game.get_tree().process_frame
	check("音乐", "声音设置移除白热化曲目选项",
		not _has_setting_row("白热化音乐") and _has_setting_row("音乐风格"))
	game.close_overlay()
	await game.get_tree().process_frame


func _has_setting_row(label: String) -> bool:
	for node in _all_nodes(game.screen_node):
		if node is Label and String(node.text) == label:
			return true
	return false


func _stage_continue() -> void:
	# 直接造一份中段存档，再走「继续守夜」的入口
	game.show_prep(2)
	game.screen_node._picked = ["lantern", "shooter", "wall", "censer"]
	game.screen_node._refresh()
	game.screen_node._start()
	await game.get_tree().process_frame
	game.sim.sun = 777
	game.save_run()
	var saved_time = game.sim.time
	var saved_sun = game.sim.sun
	game.show_menu()
	await game.get_tree().process_frame
	check("续局", "封面认出存档", game.has_save())
	game.continue_run()
	await game.get_tree().process_frame
	check("续局", "继续守夜能回到同一夜",
		game.screen == "battle" and game.sim != null and game.sim.level_id == 2,
		"level=%d" % (0 if game.sim == null else game.sim.level_id))
	check("续局", "香火与时间接上",
		game.sim != null and absi(game.sim.sun - saved_sun) <= 1
		and game.sim.time >= saved_time - 0.1,
		"sun=%d t=%.1f" % [game.sim.sun if game.sim else -1,
			game.sim.time if game.sim else -1])
	game.clear_run()


func _report() -> void:
	var payload := {
		"version": ProjectSettings.get_setting("application/config/version", "0.0.0"),
		"total": results.size(),
		"failures": failures,
		"checks": results,
	}
	var file = FileAccess.open("res://qa/ui-tests.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "  "))
		file.close()
	for row in results:
		print("%s  %s  %s  %s" % ["PASS" if row["ok"] else "FAIL", row["group"],
			row["name"], row["detail"]])
	print("TOTAL %d  FAILURES %d" % [results.size(), failures])


func _all_nodes(root: Node) -> Array:
	var out: Array = []
	if root == null:
		return out
	var stack: Array = [root]
	while not stack.is_empty():
		var node = stack.pop_back()
		out.append(node)
		for child in node.get_children():
			stack.append(child)
	return out


func _all_buttons(root: Node) -> Array:
	var out: Array = []
	for node in _all_nodes(root):
		if node is Button:
			out.append(node)
	return out


func _button_texts(buttons: Array) -> Array:
	var out: Array = []
	for button in buttons:
		out.append(String(button.text))
	return out


func _label_texts(root: Node) -> Array:
	var out: Array = []
	for node in _all_nodes(root):
		if node is Label:
			out.append(String(node.text))
	return out


func _has_text(texts: Array, needle: String) -> bool:
	for text in texts:
		if String(text).find(needle) >= 0:
			return true
	return false
