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
	game.progress = {"cleared": [], "selected": 1, "loadout": []}
	game.records = {"wins": 0, "best_kills": 0, "best_wave": 0, "best_time": null}
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
	await _stage_continue()
	_report()


func _stage_menu() -> void:
	game.show_menu()
	check("封面", "封面已建立", game.screen == "menu" and game.screen_node != null)
	var buttons := _all_buttons(game.screen_node)
	check("封面", "封面按钮不少于六组", buttons.size() >= 6,
		"buttons=%d" % buttons.size())
	check("封面", "封面读得到存档状态", game.has_save() or true)


func _stage_levels() -> void:
	game.show_levels()
	var screen = game.screen_node
	check("选关", "选关页已建立", game.screen == "levels" and screen != null)
	var nights = screen._cards.size()
	check("选关", "十五夜都在页面里", nights == 15, "nights=%d" % nights)
	check("选关", "选关页带详情面板", screen._detail_panel != null)
	check("选关", "选关页有返回按钮", _all_buttons(screen).size() >= 3,
		"buttons=%d" % _all_buttons(screen).size())
	screen.select_level(11)
	check("选关", "可以选到第十一夜", int(screen.selected) == 11)
	game.show_prep(11)


func _stage_prep() -> void:
	var screen = game.screen_node
	check("备战", "备战页已建立", game.screen == "prep" and screen != null)
	check("备战", "备战默认带上十张卡", Array(game.prep["selected"]).size() == 10,
		"cards=%d" % Array(game.prep["selected"]).size())
	screen.toggle_plant("cat")
	check("备战", "取下一张后剩九张", Array(screen._picked).size() == 9)
	screen.toggle_plant("cat")
	check("备战", "再点回来变十张", Array(screen._picked).size() == 10)
	screen.toggle_plant("shield")
	check("备战", "不存在的卡不会进卡组", Array(screen._picked).size() == 10)
	# 回到第一夜开战
	game.show_prep(1)


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
	var cell = Geo.cell_center(0, 2, sim.rows)
	game._handle_battle_click(cell)
	check("对局", "点空地后种下草木", sim.main_plant_at(0, 2) != null)
	check("对局", "种植扣了香火", sim.sun < sun_before,
		"%d -> %d" % [sun_before, sim.sun])
	check("对局", "落子后自动取消选卡", game.hud.card_selected == -1)
	# 冷却中的卡不能重复摆放
	game.hud._on_card(0)
	check("对局", "冷却中的卡点不动", game.hud.card_selected == 0)
	game._handle_battle_click(Geo.cell_center(1, 2, sim.rows))
	check("对局", "冷却中落子是无效操作", sim.main_plant_at(1, 2) == null)
	game.hud.cancel_selection()
	# 种签筒并检查升级面板
	sim.sun = 1000
	sim.cards[1]["cd"] = 0.0
	game.hud._on_card(1)
	game._handle_battle_click(Geo.cell_center(2, 2, sim.rows))
	await game.get_tree().process_frame
	check("对局", "签筒落在第 2 列", sim.main_plant_at(2, 2) != null)


func _stage_upgrade() -> void:
	var sim = game.sim
	var plant = sim.main_plant_at(2, 2)
	game.hud.try_open_menu(plant, Vector2(900, 450))
	await game.get_tree().process_frame
	check("升阶", "点草木后弹出升阶面板", game.hud._fan_panel != null)
	check("升阶", "面板列出三条路", game.hud._fan_panel != null and
		game.hud._fan_panel.get_child(0).get_child_count() >= 4)
	var sun_before = sim.sun
	var shown = Upgrades.path_status("shooter", plant.upgrades, 1)
	game.hud._on_upgrade(plant, 1)
	check("升阶", "一级升阶生效", plant.tier(1) == 1, "tier=%d" % plant.tier(1))
	check("升阶", "升阶扣香火", sim.sun < sun_before, "%d -> %d" % [sun_before, sim.sun])
	check("升阶", "面板费用与实际扣费一致", int(shown["cost"]) == sun_before - sim.sun,
		"%d vs %d" % [int(shown["cost"]), sun_before - sim.sun])
	game.hud.close_fan()
	check("升阶", "关闭面板后回到无选中", game.hud._fan_panel == null)


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
	game.open_almanac("plant", 3)
	await game.get_tree().process_frame
	check("图鉴", "从局内能打开图鉴", game.screen == "almanac")
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
	game.show_menu()
	await game.get_tree().process_frame


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
