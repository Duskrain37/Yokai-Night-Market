## PC todo acceptance, isolated saves, real viewport clicks, no packaging/network writes.
extends SceneTree
const Regions = preload("res://scripts/plant_regions.gd")
const Update = preload("res://ui/update_dialog.gd")
class LocalGame extends "res://scripts/game.gd":
	func _data_path(path: String) -> String:
		var dir := "res://qa/pc-todo-runtime"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		return dir.path_join(path.get_file())
class RestartProbe extends "res://ui/update_dialog.gd":
	var commits := 0
	var install_ok := true
	func _install_and_quit() -> bool:
		commits += 1
		if not install_ok:
			updater.state("failed", "测试：启动更新助手失败，旧版保留。")
			return false
		return true

var game
var checks: Array = []
var failures := 0
func _initialize(): run.call_deferred()
func check(label: String, ok: bool, detail: String = ""):
	checks.append({"name": label, "ok": ok, "detail": detail})
	if not ok: failures += 1; printerr("FAIL ", label, " ", detail)
func settle(n: int = 5):
	for i in n: await process_frame
func click(at: Vector2,button: int=MOUSE_BUTTON_LEFT):
	var move := InputEventMouseMotion.new(); move.position = at; move.global_position = at
	root.push_input(move, true)
	for down in [true, false]:
		var e := InputEventMouseButton.new(); e.button_index = button
		e.pressed = down; e.position = at; e.global_position = at; root.push_input(e, true)
		await process_frame
	await settle()
func buttons(node: Node) -> Array:
	var out: Array = []
	if node is Button: out.append(node)
	for child in node.get_children(): out.append_array(buttons(child))
	return out
func bounds(node: Node, label: String):
	for button in buttons(node):
		if not button.is_visible_in_tree(): continue
		var parent = button.get_parent(); var clipped := false
		while parent != node and parent != null:
			if parent is ScrollContainer: clipped = true
			parent = parent.get_parent()
		if clipped: continue
		check(label + "/" + button.text, Rect2(Vector2.ZERO, Ui.canvas_size).grow(1).encloses(button.get_global_rect()), str(button.get_global_rect()))

func run():
	root.size = Vector2i(1600, 1000)
	root.content_scale_size = Vector2i(1600, 900)
	root.gui_embed_subwindows = true
	game = LocalGame.new(); root.add_child(game); await settle(10)
	game.settings.reduced_motion = true; MarketArt.reduced_motion = true
	game.settings.difficulty = "normal"
	game.progress = {"selected": 1, "cleared": [], "loadout": []}
	game.save_data = {}
	for entry in [["easy", .8, "初月"], ["normal", 1., "常夜"], ["hard", 1.1, "沉夜"], ["nightmare", 1.2, "噩梦"]]:
		var s := Sim.new(); s.setup(Content.get_level(1), ["shooter"], entry[0], 42)
		check("四档名称与乘数/" + entry[0], game.DIFFICULTY_LABEL[entry[0]] == entry[2] and is_equal_approx(s.difficulty_mult().hp, entry[1]) and is_equal_approx(s.difficulty_mult().count, entry[1]))
		s.hp_mul = 1
		var z = s.spawn_zombie("straw", 0, {"x": 1100})
		check("实际血量及护具/" + entry[0], is_equal_approx(z.max_hp, float(z.def.hp) * entry[1]) and is_equal_approx(z.max_armor, 90 * entry[1]))
		var sum_count := 0
		for seed_value in 500:
			s.rng.seed = 2200 + seed_value; s.count_mul = 1; s.spawn_queue.clear()
			s.queue_roster({"groups": [["ghost", 10]]}, 0); sum_count += s.spawn_queue.size()
		check("实际出怪数量/" + entry[0], absf(sum_count / 500.0 - entry[1] * 10) < .15, str(sum_count))
	var font := Ui.body_font()
	for text in ["459+1458", "123456+123456", "99999999+99999999"]:
		var size := Ui.fit_font(font, text, 60)
		check("完整血量适配/" + text, font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= 60 and size <= 13, str(size))
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://data/actor_motion.json"))
	for type in Content.PLANT_ORDER:
		for path in Upgrades.paths_for(type):
			var texture := Ui.capstone_sprite(type, int(path.id))
			check("三阶立绘存在/%s/%d" % [type, path.id], texture != null)
			var actor := "%s-e%d" % [type, path.id]
			if manifest.has(actor):
				check("三阶使用战斗动画资源/" + actor, texture is AtlasTexture and texture.atlas.resource_path == "res://" + String(manifest[actor].file))
	for row in preload("res://ui/screen_settings.gd").ROWS[2]: check("设置移除音乐风格/" + row.key, row.key != "music_style")
	game.set_setting("music_style", "plain")
	check("旧音乐设置强制迁移", game.music_style() == "complete" and game.settings.music_style == "complete" and game._music_players.size() == 16)
	for day in range(1, 6):
		for phase in ["battle", "hot", "final"]:
			check("完整曲目/%d/%s" % [day, phase], game.resolve_battle_track(day, phase) == "day%d-%s" % [day, phase] and game._has_track("day%d-%s" % [day, phase]))
	for phase in ["battle", "hot", "final"]: check("旧通用曲移除/" + phase, not FileAccess.file_exists("res://assets/music/" + phase + ".ogg"))
	var art := Ui.sprite("shell").get_image()
	check("龟甲开口真实透明", art.get_pixel(art.get_width() / 2, int(art.get_height() * .34)).a < .05 and art.get_pixel(art.get_width() / 2, int(art.get_height() * .75)).a > .95)
	var news = JSON.parse_string(FileAccess.get_file_as_string("res://data/news_v060.json"))
	check("公告分类与顺序", news.sections[0].title == "本版本游戏外更新内容" and news.sections[1].title == "草木新增与平衡性调整" and news.sections[2].title == "恶客新增与平衡性调整")
	for item in news.sections[1].items:
		check("草木公告前后对照/" + item[0], (item[0].begins_with("增强") or item[0].begins_with("削弱") or item[0].begins_with("调整")) and item[1].contains("】->【"))
	check("说明不含十二株冗文", not preload("res://data/nightmare.gd").INFO.contains("十二株"))
	for scale in [1., 1.2]:
		Ui.text_scale = scale
		game.show_menu(); await settle(); bounds(game.screen_node, "16:10首页")
		check("16:10扩展画布", Ui.canvas_size.is_equal_approx(Vector2(1600, 1000)) and root.get_visible_rect().size.is_equal_approx(Vector2(1600, 1000)), str(root.get_visible_rect()))
		game.show_levels(); await settle()
		for day in range(1, 6):
			game.screen_node.select_day(day); await settle()
			var map = game.screen_node; var captions = map._caption_rects()
			await click(captions[0].get_center())
			check("16:10章节点击/%d/%.1f" % [day, scale], map.selected == Content.level_id_for(day, 0))
			for index in 5:
				var caption := Rect2(captions[index].position, Vector2(146, 74))
				check("16:10题签在屏内", Rect2(Vector2.ZERO, Ui.canvas_size).encloses(caption))
				for other in 5:
					check("16:10题签不压节点", not caption.intersects(Rect2(map._node_pos(other) - Vector2(50, 50), Vector2(100, 100))))
		bounds(game.screen_node, "16:10选关")
		for level_id in range(1, 27):
			game.show_prep(level_id); game.screen_node.skip_cinema(); await settle(2)
			bounds(game.screen_node, "16:10备战" + str(level_id))
		game.open_almanac("plant", 0); await settle(); bounds(game.screen_node, "16:10图鉴")
		for tab in ["plant", "zombie", "boss"]:
			game.screen_node._select_tab(tab); await settle()
			var grid: GridContainer = game.screen_node.find_child("AlmanacEntryGrid",true,false)
			var indices: Array = game.screen_node._sorted_indices()
			check("图鉴按行排列/"+tab,grid.columns==2 and grid.get_child_count()==indices.size())
			for i in indices.size():
				var entry: Control = grid.get_child(i)
				check("图鉴发布序元数据/"+tab,entry.get_meta("entry_index")==indices[i])
				if i%2==1: check("图鉴同排先左后右/"+tab,entry.position.x>grid.get_child(i-1).position.x and is_equal_approx(entry.position.y,grid.get_child(i-1).position.y))
				elif i>=2: check("图鉴换排向下/"+tab,entry.position.y>grid.get_child(i-2).position.y)
		game.open_settings(); await settle(); bounds(game.screen_node, "16:10设置")
		game.screen_node._nightmare_info(); await settle()
		var info = game.screen_node.get_child(game.screen_node.get_child_count() - 1)
		check("难度说明弹窗在屏内", info is AcceptDialog and info.title.begins_with("难度说明") and info.position.y + info.size.y <= 1000)
		info.hide(); info.queue_free(); await settle()
		game.show_training_menu(); await settle(); bounds(game.screen_node, "16:10训练")
		game.open_news(); await settle(); bounds(game.screen_node, "16:10公告")
	Ui.text_scale = 1
	game.start_battle(1, ["lantern", "shooter", "shell"]); game.paused = true
	game.paused = false; game.set_process(false)
	game.sim.plants.clear(); game.sim.orbs.clear(); game.sim.zombies.clear(); game.sim.sun = 99999
	game.hud.refresh()
	check("五位香火数字不溢出印章",Ui.medium_font().get_string_size("99999",HORIZONTAL_ALIGNMENT_LEFT,-1,game.hud._sun_label.get_theme_font_size("font_size")).x<=68)
	var host = game.sim.place_free("shooter", 3, 2); game.sim.attach_shell(host)
	await settle()
	await click(Regions.skill_rect(host, game.sim.rows).get_center())
	check("真实点击技能区域优先", game.hud.focus_plant == host and game.hud._fan != null)
	var fan = game.hud._fan
	var tier_before: int = host.tier(1)
	await click(fan._point(95, fan._petal_angle(0)))
	check("真实扇叶点击优先于草木和罩", host.tier(1) == tier_before + 1)
	game.hud.close_fan(); await settle()
	var rect := Regions.shell_rect(host, game.sim.rows)
	await click(rect.position + rect.size * Vector2(.5, .72))
	check("真实点击罩体打开独立面板", game.hud._shell_host == host and game.hud._shell_panel != null and game.hud._fan == null)
	await click(Regions.foot(host, game.sim.rows) - Vector2(Regions.height(host, game.sim.rows) * .2, Regions.height(host, game.sim.rows) * .75))
	check("点击罩窗口外只关闭并消费点击", game.hud._shell_panel == null and game.hud._fan == null)
	await click(Regions.foot(host, game.sim.rows) - Vector2(Regions.height(host, game.sim.rows) * .2, Regions.height(host, game.sim.rows) * .75))
	check("真实点击上部本体打开进化", game.hud.focus_plant == host and game.hud._fan != null and game.hud._shell_panel == null)
	for row in game.sim.rows:
		for col in Geo.COLS:
			var point := Geo.to_screen(Geo.cell_center(col, row, game.sim.rows), game.sim.rows)
			check("16:10棋盘投影点选一致", Geo.screen_cell_at(point, game.sim.rows) == Vector2i(col, row))
	game.hud.close_fan(); await settle()
	var cannon=game.sim.place_free("sky-mortar",5,3)
	cannon.upgrades={1:0,2:0,3:3};game.sim.attach_shell(cannon)
	game.sim.spawn_zombie("ghost",3,{"x":1100})
	var stamp:=Regions.skill_rect(cannon,game.sim.rows).get_center()
	check("主动技能区域优先于罩和本体",Regions.pick(game.sim,stamp).layer=="skill")
	await click(stamp,MOUSE_BUTTON_RIGHT)
	check("真实点击主动施放首枚重炮",cannon.mortar_burst_left==6 and game.sim.shots.size()==1 and game.sim.active_skill_status(cannon).left>54)
	await click(stamp,MOUSE_BUTTON_RIGHT)
	check("真实点击冷却中技能不重复发炮",game.sim.shots.size()==1 and cannon.mortar_burst_left==6)
	game.hud.try_open_menu(cannon,Regions.foot(cannon,game.sim.rows));await settle()
	var before_shots:int=game.sim.shots.size()
	await click(Vector2(20,700))
	check("点扇形窗口外关闭且不点穿",game.hud._fan==null and game.sim.shots.size()==before_shots)
	game.hud._toggle_cheat();await settle();await click(Vector2(20,700))
	check("点调整窗口外关闭且不点穿",not game.hud.cheat_open and game.sim.shots.size()==before_shots)
	game.show_pause();await settle();await click(Vector2(20,700))
	check("点暂停窗口外恢复战斗",not game.paused and game.screen_node==null)
	game.open_settings();await settle();await click(Vector2(10,700))
	check("点战斗设置窗外关闭",game.screen=="battle" and game.screen_node==null and game.sim.shots.size()==before_shots)
	game.open_almanac("plant",0);await settle();await click(Vector2(10,700))
	check("点战斗图鉴窗外关闭",game.screen=="battle" and game.screen_node==null and game.sim.shots.size()==before_shots)
	game.show_pause(); await settle(); bounds(game.screen_node, "16:10暂停"); game.close_pause()
	game.finish_run(true); await settle(); bounds(game.screen_node, "16:10结算")
	game.show_menu(); await settle()
	game.show_prep(26);game.screen_node.skip_cinema();await settle()
	var picked:Array=game.screen_node._picked.duplicate()
	root.mode=Window.MODE_WINDOWED;root.size=Vector2i(1600,900);await settle(8);game._sync_canvas()
	check("现有备战页随16:9缩回并保留卡组",game.screen_node._picked==picked and Ui.canvas_size.y==900)
	bounds(game.screen_node,"动态缩回16:9")
	root.size=Vector2i(1600,1000);await settle(8);game._sync_canvas()
	check("现有备战页扩为16:10并保留卡组",game.screen_node._picked==picked and Ui.canvas_size.y==1000)
	bounds(game.screen_node,"动态扩至16:10")
	game.show_menu();await settle()
	await updater_checks()
	var file := FileAccess.open("res://qa/pc-todo-tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"total": checks.size(), "failures": failures, "checks": checks}, "  ")); file.close()
	game.free(); await settle()
	print("PC TODO TOTAL ", checks.size(), " FAILURES ", failures)
	quit(0 if failures == 0 else 1)

func updater_checks():
	var dialog := RestartProbe.new(); dialog.game = game; dialog.auto_start = false
	game.screen_node.add_child(dialog); dialog.popup_centered(); await settle()
	for phase in ["checking", "scanning", "downloading", "assembling"]:
		dialog.updater.state(phase, "正在处理")
		dialog.updater.progress = .42; dialog.updater.checked_bytes = 420; dialog.updater.total_bytes = 1000
		dialog.updater.download_part = 2; dialog.updater.download_parts = 5
		dialog.updater.required = 1000; dialog.updater.received = 420; dialog._refresh()
		check("进度阶段可见/" + phase, dialog._bar.visible and dialog._bar.show_percentage and is_equal_approx(dialog._bar.value, 42) and dialog._detail.text.contains("42%"))
		if phase == "downloading": check("下载标明文件与分组", dialog._detail.text.contains("YokaiNightMarket-win64.exe") and dialog._detail.text.contains("2 / 5"))
	dialog.updater.latest_version = "0.5.7"; dialog.updater.state("ready", "完成"); await settle()
	check("完成后强制重启提示", dialog.restart_required and dialog._close.disabled and dialog._text.text.contains("自动重启") and is_equal_approx(dialog._bar.value, 100))
	dialog._leave(); await settle(); check("返回不能绕过重启", dialog.visible and dialog.restart_required)
	dialog.hide(); await settle(); check("关闭窗口不能绕过重启", dialog.visible)
	var escape := InputEventKey.new(); escape.pressed = true; escape.keycode = KEY_ESCAPE
	dialog.push_input(escape, true); await settle(); check("Esc不能绕过重启", dialog.visible and dialog.restart_required)
	dialog._process(6); dialog._process(6)
	check("倒计时自动重启且只执行一次", dialog.commits == 1 and dialog._restarting)
	dialog.restart_required = false; auto_accept_quit = true; dialog.hide(); dialog.queue_free(); await settle()
	dialog = RestartProbe.new(); dialog.game = game; dialog.auto_start = false; dialog.install_ok = false
	game.screen_node.add_child(dialog); dialog.popup_centered(); await settle()
	dialog.updater.state("ready", "完成"); dialog._act(); await settle()
	check("重启助手启动失败可恢复", dialog.commits == 1 and not dialog.restart_required and dialog.updater.phase == "failed" and not dialog._close.disabled and auto_accept_quit)
	dialog.updater.phase = "failed"; dialog._leave(); await settle()
