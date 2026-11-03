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
	# 先点到第三天的题签，再点画上的第一个夜点
	await click(Vector2(56 + 107, 150 + 2 * 104 + 44))
	check("选关：点题签切到第三天", int(screen.day) == 3, str(screen.day))
	await click(screen._node_pos(0))
	check("选关：点夜点选中第十一夜", int(screen.selected) == 11,
		str(screen.selected))

	var prep_button: Button = _find_button(screen, "进入第")
	check("选关：有「进入第X夜」按钮", prep_button != null)
	if prep_button != null:
		await click(_button_center(prep_button))
		check("选关：点进备战页", game.screen == "prep", str(game.screen))

	# 备战页先放镜头：点一下跳过，再等界面淡入
	await click(Vector2(800, 420))
	for i in 20:
		await process_frame
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
	# 本轮新增缺少产香草木警告；点击回归仍验证正常带产香草木的开战流程。
	game.screen_node._picked = ["lantern", "shooter"]
	game.screen_node._start()
	await process_frame
	check("开战：进入战场", game.screen == "battle" and game.sim != null)
	var hud: Control = game.hud
	var card_node: Control = hud._card_nodes[0]
	await click(_button_center(card_node))
	check("开战：点卡槽选中该卡", hud.card_selected == 0, str(hud.card_selected))
	var sun_before: int = game.sim.sun
	await click(Geo.screen_cell_center(1, 2, game.sim.rows))
	check("开战：点棋盘真的种下草木", game.sim.main_plant_at(1, 2) != null)
	check("开战：落子扣香火", game.sim.sun < sun_before,
		"%d -> %d" % [sun_before, game.sim.sun])

	await click(Geo.screen_cell_center(1, 2, game.sim.rows))
	check("升阶：点草木弹出扇形菜单", hud._fan != null)
	if hud._fan != null:
		var petal: Vector2 = hud._fan._point(104.0, hud._fan._petal_angle(0))
		check("升阶：第一片扇叶在可点范围内", hud._fan.hit_test(petal) == 0,
			str(hud._fan.hit_test(petal)))
		var tier_before: int = game.sim.main_plant_at(1, 2).tier(1)
		await click(petal)
		check("升阶：点扇叶真的升了一级",
			game.sim.main_plant_at(1, 2).tier(1) == tier_before + 1,
			"%d -> %d" % [tier_before, game.sim.main_plant_at(1, 2).tier(1)])
		# 点空地应关掉扇形
		await click(Vector2(200, 760))
		check("升阶：点别处关掉扇形", hud._fan == null)

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
