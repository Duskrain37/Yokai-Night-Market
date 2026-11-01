## 真鼠标事件联调：把「按下—松开」事件打进视口，验证命中判定、按钮回调与棋盘落子
## 走的是真实的 GUI 分发链路（Viewport → Control._gui_input / Node._unhandled_input），
## 而不是直接调用处理函数。
##
## 运行：Godot --path . --script res://tools/qa_click.gd
extends SceneTree

var game: Node = null
var checks: Array = []
var failures := 0


func _init() -> void:
	await process_frame
	var packed: PackedScene = load("res://scenes/main.tscn")
	game = packed.instantiate()
	root.add_child(game)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	for i in 8:
		await process_frame
	await _run()
	for row in checks:
		print("%s  %s  %s" % ["PASS" if row["ok"] else "FAIL", row["name"], row["detail"]])
	var file: FileAccess = FileAccess.open("res://qa/click-tests.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"total": checks.size(),
			"failures": failures, "checks": checks}, "  "))
		file.close()
	print("TOTAL %d  FAILURES %d" % [checks.size(), failures])
	quit(0 if failures == 0 else 1)


func check(name: String, ok: bool, detail: String = "") -> void:
	checks.append({"name": name, "ok": ok, "detail": detail})
	if not ok:
		failures += 1
		printerr("FAIL ", name, " ", detail)


func click(pos: Vector2) -> void:
	# 先把指针移过去（GUI 的悬停命中要一次 motion 事件），再按下与松开。
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	root.push_input(motion, true)
	await process_frame
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.pressed = true
	press.position = pos
	press.global_position = pos
	root.push_input(press, true)
	await process_frame
	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = pos
	release.global_position = pos
	root.push_input(release, true)
	for i in 3:
		await process_frame


func _button_center(node: Control) -> Vector2:
	return node.get_global_rect().get_center()


## 按树的先后顺序找第一个文字匹配的按钮（用队列，别用栈：栈会把子节点顺序反过来）
func _find_button(root_node: Node, text: String) -> Button:
	if root_node == null:
		return null
	var queue: Array = [root_node]
	var guard = 0
	while not queue.is_empty() and guard < 4000:
		guard += 1
		var node = queue.pop_front()
		if node is Button and String(node.text).contains(text):
			return node
		for child in node.get_children():
			queue.append(child)
	return null


func _run() -> void:
	game.show_menu()
	await process_frame
	var levels_button: Button = _find_button(game.screen_node, "挑选一夜")
	check("封面：找得到「挑选一夜」按钮", levels_button != null)
	if levels_button != null:
		# 诊断：悬停命中到了谁
		var motion: InputEventMouseMotion = InputEventMouseMotion.new()
		motion.position = _button_center(levels_button)
		motion.global_position = motion.position
		root.push_input(motion, true)
		await process_frame
		var hovered = root.gui_get_hovered_control()
		print("  hovered=", hovered, " btn_center=", _button_center(levels_button),
			" btn_rect=", levels_button.get_global_rect(), " visible=",
			levels_button.is_visible_in_tree())
		await click(_button_center(levels_button))
		check("封面：点按钮真的切到选关页", game.screen == "levels", str(game.screen))

	var screen: Node = game.screen_node
	var card: Control = screen._cards[10]
	await click(_button_center(card))
	check("选关：点夜卡选中第十一夜", int(screen.selected) == 11,
		str(screen.selected))

	var prep_button: Button = _find_button(screen, "进入备战")
	check("选关：有「进入备战」按钮", prep_button != null)
	if prep_button != null:
		await click(_button_center(prep_button))
		check("选关：点进备战页", game.screen == "prep", str(game.screen))

	screen = game.screen_node
	# 卡组默认满十张，所以点「已在组里」的卡应当是取下
	var index = 0
	for i in screen._roster_nodes.size():
		if Array(screen._picked).has(String(screen._roster_nodes[i].plant_id)):
			index = i
			break
	var roster: Control = screen._roster_nodes[index]
	var before: int = Array(screen._picked).size()
	await click(_button_center(roster))
	var after: int = Array(screen._picked).size()
	check("备战：点名册卡会改变卡组", after == before - 1, "%d -> %d" % [before, after])
	await click(_button_center(roster))
	check("备战：再点一次恢复原样", Array(screen._picked).size() == before,
		"%d" % Array(screen._picked).size())

	game.show_prep(1)
	await process_frame
	game.screen_node._start()
	await process_frame
	check("开战：进入战场", game.screen == "battle" and game.sim != null)
	var hud: Control = game.hud
	var card_node: Control = hud._card_nodes[0]
	await click(_button_center(card_node))
	check("开战：点卡槽选中该卡", hud.card_selected == 0, str(hud.card_selected))
	var sun_before: int = game.sim.sun
	await click(Geo.cell_center(1, 2, game.sim.rows))
	check("开战：点棋盘真的种下草木", game.sim.main_plant_at(1, 2) != null)
	check("开战：落子扣香火", game.sim.sun < sun_before,
		"%d -> %d" % [sun_before, game.sim.sun])

	await click(Geo.cell_center(1, 2, game.sim.rows))
	check("升阶：点草木弹出升阶面板", hud._fan_panel != null)
	if hud._fan_panel != null:
		var upgrade_button: Button = _find_button(hud._fan_panel, "香火")
		check("升阶：面板里有带费用的升阶按钮", upgrade_button != null)
		if upgrade_button != null:
			var center: Vector2 = _button_center(upgrade_button)
			var motion: InputEventMouseMotion = InputEventMouseMotion.new()
			motion.position = center
			motion.global_position = center
			root.push_input(motion, true)
			await process_frame
			print("  upgrade btn text=", upgrade_button.text, " disabled=",
				upgrade_button.disabled, " rect=", upgrade_button.get_global_rect(),
				" hovered=", root.gui_get_hovered_control(), " sun=", game.sim.sun)
			upgrade_button.pressed.connect(func(): print("  >> pressed signal fired"))
			var tier_before: int = game.sim.main_plant_at(1, 2).tier(1)
			await click(center)
			var pl = game.sim.main_plant_at(1, 2)
			print("  tiers after click=", pl.tier(1), pl.tier(2), pl.tier(3),
				" sun=", game.sim.sun, " path_in_tutorial=", pl.type)
			print("  after click tier=", game.sim.main_plant_at(1, 2).tier(1),
				" fan_alive=", is_instance_valid(hud._fan_panel),
				" same_btn=", is_instance_valid(upgrade_button))
			check("升阶：点按钮真的升了一级",
				game.sim.main_plant_at(1, 2).tier(1) == tier_before + 1,
				"%d -> %d" % [tier_before, game.sim.main_plant_at(1, 2).tier(1)])

	var pause_button: Button = _find_button(hud, "暂停")
	check("暂停：找得到暂停按钮", pause_button != null)
	if pause_button != null:
		await click(_button_center(pause_button))
		check("暂停：点暂停后真的暂停", game.paused)
		var resume_button: Button = _find_button(game.screen_node, "继续守夜")
		check("暂停：面板里有继续按钮", resume_button != null)
		if resume_button != null:
			await click(_button_center(resume_button))
			check("暂停：点继续后恢复", not game.paused)
