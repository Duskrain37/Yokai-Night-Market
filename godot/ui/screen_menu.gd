## Dedicated ensemble key art and a compact, accessible front-door navigation.
extends Control
const Art = preload("res://ui/market_art.gd")
var game = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Art.backdrop(self, Art.ROOT + "menu-ensemble.png", 0.02)
	Art.vignette(self, 0.62, 0.0)
	var atmosphere = load("res://ui/market_atmosphere.gd").new()
	add_child(atmosphere)
	_title_block()
	_menu_buttons()
	_information_button()
	_records_card()
	game.play_music_scene("menu")
	Art.enter(self)

func _title_block() -> void:
	var mark = Control.new()
	mark.position = Vector2(84, 104)
	mark.size = Vector2(460, 238)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mark)
	mark.draw.connect(func():
		mark.draw_string(Ui.medium_font(), Vector2(2, 12), "子 时 开 张  ·  旧 物 有 灵", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Ui.TEXT_DIM)
		mark.draw_line(Vector2(0, 30), Vector2(384, 30), Color(Art.BRASS, 0.65), 1, true)
		mark.draw_string(Ui.display_font(), Vector2(-3, 129), "妖怪", HORIZONTAL_ALIGNMENT_LEFT, -1, 108, Ui.GOLD_BRIGHT)
		mark.draw_string(Ui.display_font(), Vector2(97, 229), "夜市", HORIZONTAL_ALIGNMENT_LEFT, -1, 108, Ui.GOLD_BRIGHT)
		mark.draw_arc(Vector2(340, 109), 46, 0.25, TAU - 0.25, 64, Color(Art.BRASS, 0.7), 1, true)
		Art.icon(mark, "lantern", Vector2(340, 104), 31, Ui.GOLD_BRIGHT)
		Art.diamond(mark, Vector2(23, 199), 7, Ui.VERMILION, true)
		mark.draw_line(Vector2(39, 199), Vector2(80, 199), Art.BRASS, 1, true))
	var english = Ui.label("Y O K A I   N I G H T   M A R K E T", 13, Ui.TEXT_DIM)
	english.position = Vector2(88, 365)
	add_child(english)
	var line = Ui.label("香火为钱，草木为兵。守到天亮，摊子才算收。", 17, Ui.TEXT)
	line.position = Vector2(88, 396)
	add_child(line)

func _menu_buttons() -> void:
	var has_save = not game.save_data.is_empty()
	var fresh = not has_save and Array(game.progress.get("cleared", [])).is_empty() and not bool(game.progress.get("taught", false))
	var primary = Ui.button("继续守夜" if has_save else ("先学一夜守夜" if fresh else "开始守夜"), 27, 406, 72, true)
	primary.name = "PrimaryAction"
	primary.position = Vector2(84, 453)
	Ui.pin(primary, .5)
	primary.pressed.connect(func():
		game.play_sfx("click")
		if has_save: game.continue_run()
		elif fresh: game.start_battle(0, ["shooter"], "tutorial")
		else: game.show_levels())
	add_child(primary)
	var note = Ui.label(_save_line(game.save_data) if has_save else ("先跟街坊学会收香火、请草木，再守第一夜。" if fresh else "灯火已备，挑一夜出摊。"), 15, Ui.TEXT_DIM)
	note.position = Vector2(90, 536)
	Ui.pin(note, .5)
	note.size = Vector2(400, 44)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(note)
	var entries = [
		["挑选一夜", "map", func(): game.show_levels()],
		["草木志·恶客录", "book", func(): game.open_almanac("plant", 0)],
		["训练与教程", "training", func(): game.show_training_menu()],
		["设置", "settings", func(): game.open_settings()],
	]
	for i in entries.size():
		var entry = entries[i]
		var button = Ui.button(String(entry[0]), 16 if String(entry[0]).length() > 6 else 18, 197, 50)
		button.position = Vector2(84 + (i % 2) * 209, 602 + (i / 2 as int) * 62)
		Ui.pin(button, .5)
		button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		button.add_theme_constant_override("align_to_largest_stylebox", 1)
		button.pressed.connect(func(): game.play_sfx("click"); entry[2].call())
		add_child(button)
		var emblem = Art.icon_control(String(entry[1]), 26, Ui.GOLD)
		emblem.position = Vector2(14, 12)
		button.add_child(emblem)
	var slot = Ui.button("守夜存档 · %d" % (game.active_slot + 1), 16, 197, 42)
	slot.position = Vector2(84, 744)
	Ui.pin(slot)
	slot.pressed.connect(_show_slots)
	add_child(slot)
	var quit = Ui.button("收摊退出", 16, 197, 42)
	quit.position = Vector2(293, 744)
	Ui.pin(quit)
	quit.pressed.connect(func(): get_tree().quit())
	add_child(quit)
	var hint = Ui.label("F11 全屏   ·   Esc 返回", 13, Ui.TEXT_FAINT)
	hint.position = Vector2(88, 837)
	Ui.pin(hint)
	add_child(hint)

func _information_button() -> void:
	var news = Ui.button("夜市新讯", 16, 132, 42)
	news.position = Vector2(1418, 34)
	news.pressed.connect(game.open_news)
	add_child(news)
	var update = Ui.button("检查更新", 16, 132, 42)
	update.position = Vector2(1274, 34)
	update.name = "CheckUpdate"
	update.pressed.connect(_open_update)
	add_child(update)

func _records_card() -> void:
	var card = Ui.panel()
	card.position = Vector2(626, 802)
	Ui.pin(card)
	card.custom_minimum_size = Vector2(928, 68)
	add_child(card)
	var row = Ui.hbox(18)
	card.add_child(row)
	row.add_child(Art.icon_control("book", 28, Ui.GOLD))
	row.add_child(Ui.strong("守夜手札", 20, Ui.GOLD_BRIGHT))
	var cleared = Array(game.progress.get("cleared", [])).size()
	var summary = Ui.label("已守住 %d / %d 夜" % [cleared, Content.LEVELS.size()], 17)
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(summary)
	var key = String(game.settings.get("difficulty", "easy"))
	var book: Dictionary = Dictionary(game.records.get("by_diff", {})).get(key, {})
	row.add_child(Ui.label("%s · 天亮 %d 次 · 最多击退 %d 波" % [game.DIFFICULTY_LABEL[key], int(book.get("wins", 0)), int(book.get("best_groups", int(book.get("best_wave", 0)) / Content.WAVES_PER_GROUP))], 15, Ui.TEXT_DIM))
	var open = Ui.button("翻阅", 16, 76, 34)
	open.pressed.connect(_show_records)
	row.add_child(open)

func _show_records() -> void:
	var list = _open_save_panel("守夜手札", false)
	list.add_child(Ui.label("已守住 %d / %d 夜" % [Array(game.progress.get("cleared", [])).size(), Content.LEVELS.size()], 21, Ui.GOLD_BRIGHT))
	var books: Dictionary = game.records.get("by_diff", {})
	for key in ["easy", "normal", "hard", "nightmare"]:
		var record: Dictionary = books.get(key, {})
		list.add_child(Ui.strong(String(game.DIFFICULTY_LABEL[key]), 20, Ui.GOLD))
		var seconds = record.get("best_time", null)
		var fastest = "暂无" if seconds == null else "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]
		list.add_child(Ui.label("天亮 %d 次 · 最多击退 %d 波 · 最快天亮 %s" % [int(record.get("wins", 0)), int(record.get("best_groups", int(record.get("best_wave", 0)) / Content.WAVES_PER_GROUP)), fastest], 18))
		list.add_child(Ui.label("最多击退 %d 位恶客" % int(record.get("best_kills", 0)), 16, Ui.TEXT_DIM))
		list.add_child(Ui.hline(Color(Ui.GOLD_DIM, 0.35)))

func _show_slots() -> void:
	var list := _open_save_panel("守夜存档", false)
	list.add_child(Ui.label("每卷单独保留一局。已结束的守夜会留下最近一份结局。", 18, Ui.TEXT_DIM))
	for index in game.SLOT_COUNT:
		var row := Ui.hbox(12)
		list.add_child(row)
		var details := Ui.vbox(4)
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		details.custom_minimum_size.x = 430
		row.add_child(details)
		var saved: Dictionary = game.run_slots[index]
		var last: Dictionary = game.run_snapshots[index]
		var caption := "第 %d 卷%s" % [index + 1, " · 当前" if index == game.active_slot else ""]
		details.add_child(Ui.strong(caption, 20, Ui.GOLD))
		details.add_child(Ui.label("尚无进行中的守夜" if saved.is_empty() else _save_line(saved), 16))
		var choose := Ui.button("切到此卷" if saved.is_empty() else "续守此卷", 16, 110, 44)
		row.add_child(choose)
		choose.pressed.connect(func():
			game.set_run_slot(index)
			if saved.is_empty():
				game.show_menu()
			else:
				_close_save_panel()
				game.continue_run())
		var snapshot := Ui.button("上次结局", 16, 105, 44)
		snapshot.disabled = last.is_empty()
		snapshot.pressed.connect(func(): _show_snapshot(last))
		row.add_child(snapshot)

func _show_snapshot(snapshot: Dictionary) -> void:
	var record: Dictionary = snapshot.get("result", {})
	var details: Dictionary = record.get("summary", {})
	var level := Content.get_level(int(record.get("level_id", 1)))
	var list := _open_save_panel("守夜结局", true)
	list.add_child(Ui.strong("%s · %s · %s" % [level.day_name, level.day_sub, level.name], 22, Ui.GOLD))
	list.add_child(Ui.title("守至天亮" if bool(record.get("won", false)) else "此夜失守", 36))
	var elapsed := int(record.get("time", 0))
	list.add_child(Ui.label("守夜 %d 分 %02d 秒　｜　击退 %d 名恶客" % [
		elapsed / 60, elapsed % 60, int(record.get("kills", 0))], 18))
	list.add_child(Ui.label("守住 %d 大波　｜　剩余香火 %d　｜　门神出手 %d 次" % [
		int(record.get("groups_completed", 0)), int(record.get("sun", 0)),
		int(details.get("mowers_used", 0))], 18))


var _save_overlay: ColorRect
var _snapshot_open := false


func _open_save_panel(heading: String, snapshot: bool) -> VBoxContainer:
	_close_save_panel()
	_snapshot_open = snapshot
	_save_overlay = ColorRect.new()
	_save_overlay.color = Color(0.025, 0.038, 0.048, 0.8)
	_save_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_save_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_save_overlay.z_index = 10
	add_child(_save_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_save_overlay.add_child(center)
	var frame := Ui.panel(0.98, Ui.GOLD_DIM, 18)
	center.add_child(frame)
	var list := Ui.vbox(18)
	list.custom_minimum_size.x = 730
	frame.add_child(list)
	var head := Ui.hbox(12)
	list.add_child(head)
	head.add_child(Ui.seal("录", 42))
	var title := Ui.title(heading, 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var back := Ui.button("返回", 17, 110, 42)
	back.pressed.connect(_back_from_save_panel)
	head.add_child(back)
	list.add_child(Ui.hline(Ui.GOLD_DIM))
	return list


func _back_from_save_panel() -> void:
	if _snapshot_open:
		_show_slots()
	else:
		_close_save_panel()


func _close_save_panel() -> void:
	if is_instance_valid(_save_overlay):
		_save_overlay.hide()
		_save_overlay.queue_free()
	_save_overlay = null
	_snapshot_open = false


func _input(event: InputEvent) -> void:
	if _save_overlay != null and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_back_from_save_panel()


func _save_line(save_data: Dictionary) -> String:
	var level_id = int(save_data.get("level_id", 1))
	var level = Content.get_level(level_id)
	var sim_data: Dictionary = save_data.get("sim", {})
	var wave = int(sim_data.get("wave_index", 0))
	return "上次停在 %s·%s %s %s" % [level["day_name"], level["day_sub"],
		level["name"], Content.wave_text(level, maxi(0,wave-1))]


func _open_update():
	var existing=get_node_or_null("UpdateDialog")
	if existing!=null:existing.grab_focus();return
	var dialog=load("res://ui/update_dialog.gd").new();dialog.game=game;dialog.name="UpdateDialog"
	add_child(dialog);dialog.popup_centered()
