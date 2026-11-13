## Local art acceptance: real viewport events, all chapter/prep bounds and accessibility.
extends SceneTree
class IsolatedGame extends "res://scripts/game.gd":
	func _data_path(path: String) -> String:
		var directory = "res://qa/art-overhaul-runtime"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		return directory.path_join(path.get_file())

var game
var checks: Array = []
var failures = 0

func _initialize() -> void: run.call_deferred()

func check(label: String, ok: bool, detail: String = "") -> void:
	checks.append({"name": label, "ok": ok, "detail": detail})
	if not ok:
		failures += 1
		printerr("FAIL ", label, " ", detail)

func settle(frames: int = 4) -> void:
	for i in frames: await process_frame

func buttons(node: Node) -> Array:
	var result: Array = []
	if node is Button: result.append(node)
	for child in node.get_children(): result.append_array(buttons(child))
	return result

func find_button(node: Node, caption: String):
	for button in buttons(node):
		if button.text == caption: return button
	return null

func click(at: Vector2) -> void:
	var motion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	root.push_input(motion, true)
	await process_frame
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		root.push_input(event, true)
		await process_frame
	await settle()

func visible_bounds(node: Node, label: String) -> void:
	for button in buttons(node):
		if not button.is_visible_in_tree(): continue
		var ancestor = button.get_parent()
		var scrollable = false
		while ancestor != null and ancestor != node:
			if ancestor is ScrollContainer: scrollable = true
			ancestor = ancestor.get_parent()
		if scrollable: continue
		var rect: Rect2 = button.get_global_rect()
		check(label + " · " + button.text, rect.position.x >= -1 and rect.position.y >= -1 and rect.end.x <= 1601 and rect.end.y <= 901, str(rect))

func run() -> void:
	root.size = Vector2i(1600, 900)
	root.content_scale_size = Vector2i(1600, 900)
	root.gui_embed_subwindows = true
	game = IsolatedGame.new()
	root.add_child(game)
	await settle(8)
	game.settings.difficulty = "easy"
	game.settings.reduced_motion = true
	MarketArt.reduced_motion = true
	for scale in [1.0, 1.2]:
		Ui.text_scale = scale
		game.show_menu()
		await settle()
		visible_bounds(game.screen_node, "首页 %.1f" % scale)
		game.show_levels()
		await settle()
		var map = game.screen_node
		for i in 5:
			var tab: Control = map._week_buttons[i]
			check("五章完整展示 %.1f/%d" % [scale, i], tab.get_global_rect().end.x <= 1553 and tab.get_global_rect().end.y < 190)
			await click(tab.get_global_rect().get_center())
			check("章节真实点击 %.1f/%d" % [scale, i], map.day == i + 1)
			await click(map._caption_rects()[0].get_center())
			check("题签真实点击 %.1f/%d" % [scale, i], map.selected == Content.level_id_for(i + 1, 0))
			await click(map._node_pos(4))
			check("关底节点真实点击 %.1f/%d" % [scale, i], map.selected == Content.level_id_for(i + 1, 4))
			var captions: Dictionary = map._caption_rects()
			for index in 5:
				var caption = Rect2(captions[index].position, Vector2(146, 74))
				for other in 5:
					var medallion = Rect2(map._node_pos(other) - Vector2(50, 50), Vector2(100, 100))
					check("地图题签不压节点 %.1f/%d/%d/%d" % [scale, i, index, other], not caption.intersects(medallion))
					if other > index:
						check("地图题签彼此不相交 %.1f/%d/%d/%d" % [scale, i, index, other], not caption.intersects(Rect2(captions[other].position, Vector2(146, 74))))
		visible_bounds(map, "选关 %.1f" % scale)
		for id in range(1, Content.LEVELS.size() + 1):
			game.show_prep(id)
			game.screen_node.skip_cinema()
			await settle(2)
			var start = find_button(game.screen_node, "开战")
			check("全部备战主操作 %.1f/%d" % [scale, id], start != null and start.get_global_rect().end.y <= 880 and start.get_global_rect().end.x <= 1553)
			for slot in game.screen_node._slot_nodes:
				check("备战槽完整 %.1f/%d/%d" % [scale, id, slot.index], slot.get_global_rect().end.x <= 1553 and slot.get_global_rect().end.y < 880)
		game.show_prep(1)
		game.screen_node.skip_cinema()
		await settle()
		var prep = game.screen_node
		var search: LineEdit = prep.find_child("RosterSearch", true, false)
		search.text = "红灯笼"
		search.text_changed.emit(search.text)
		await settle()
		var visible = prep._roster_nodes.filter(func(card): return card.visible)
		check("搜索能筛出唯一角色 %.1f" % scale, visible.size() == 1 and visible[0].plant_id == "lantern")
		search.text = "不存在的草木"
		search.text_changed.emit(search.text)
		check("无结果不会留下无关牌 %.1f" % scale, prep._roster_nodes.all(func(card): return not card.visible))
		search.text = ""
		search.text_changed.emit("")
		await click(prep._filter_buttons["守护"].get_global_rect().get_center())
		check("职能筛选真实点击 %.1f" % scale, prep._roster_nodes.filter(func(card): return card.visible).all(func(card): return prep._category(card.plant_id) == "守护"))
		await click(prep._filter_buttons["全部"].get_global_rect().get_center())
		var card = prep._roster_nodes[0]
		var chosen = prep._picked.has(card.plant_id)
		await click(card.get_global_rect().get_center())
		check("卡牌真实点击改变卡组 %.1f" % scale, prep._picked.has(card.plant_id) != chosen)
		card.grab_focus()
		var enter = InputEventKey.new()
		enter.keycode = KEY_ENTER
		enter.physical_keycode = KEY_ENTER
		enter.pressed = true
		root.push_input(enter, true)
		await settle()
		check("键盘焦点可以选卡 %.1f" % scale, prep._picked.has(card.plant_id) == chosen)
		for tab in ["plant", "zombie", "boss"]:
			game.open_almanac(tab, 0)
			await settle()
			var book = game.screen_node
			check("图鉴书页宽度 %.1f/%s" % [scale, tab], book._page.get_global_rect().end.x <= book._scroll.get_global_rect().end.x + 1)
			book._jump_to_section("来历")
			await settle()
			var lore: Control = book._section_anchors["来历"]
			check("图鉴书签能定位来历 %.1f/%s" % [scale, tab], book._scroll.scroll_vertical > 0 or lore.get_global_rect().end.y <= book._scroll.get_global_rect().end.y)
			if tab == "plant":
				book._expanded = true
				book._render_page()
				await settle()
				check("展开进化仍不横向溢出 %.1f" % scale, book._page.size.x <= book._scroll.size.x + 1)
		game.open_settings()
		await settle()
		var settings = game.screen_node
		for page in 4:
			settings._select_page(page)
			await settle()
			for button in buttons(settings):
				check("设置不横向溢出 %.1f/%d/%s" % [scale, page, button.text], button.get_global_rect().end.x <= settings._panel.get_global_rect().end.x - 12, str(button.get_global_rect()))
		settings._set_option("reduced_motion", true)
		check("减少动态设置即时生效 %.1f" % scale, MarketArt.reduced_motion and game.settings.reduced_motion)
		game.start_battle(1, Content.PLANT_ORDER.slice(0, 12))
		game.paused = true
		await settle()
		check("十二张战斗卡完整 %.1f" % scale, game.hud._card_nodes.size() == 12 and game.hud._card_nodes.all(func(item): return item.get_global_rect().position.x > 290 and item.get_global_rect().end.x < 1290 and item.get_global_rect().end.y < 145))
		var previous_key = game.bound_key("card_1")
		game.rebind_key("card_1", KEY_Q)
		check("卡面快捷键跟随改键 %.1f" % scale, game.hud._card_nodes[0]._key_caption() == "Q")
		game.rebind_key("card_1", previous_key)
		for pill in game.hud._speed_pills:
			check("速度键避开工具 %.1f/%s" % [scale, pill.text], pill.get_global_rect().end.x < 1500)
		game.show_pause()
		await settle()
		visible_bounds(game.screen_node, "暂停 %.1f" % scale)
		game.close_pause()
		game.finish_run(true)
		await settle()
		visible_bounds(game.screen_node, "结算 %.1f" % scale)
	game.show_training_menu()
	await settle()
	visible_bounds(game.screen_node, "训练")
	check("训练场五张地图可选", buttons(game.screen_node).size() >= 7)
	game.free()
	await settle()
	var file = FileAccess.open("res://qa/art-overhaul-tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"total": checks.size(), "failures": failures, "checks": checks}, "  "))
	print("ART ACCEPTANCE TOTAL ", checks.size(), " FAILURES ", failures)
	quit(0 if failures == 0 else 1)
