## 训练与教程：新手教程（独立教学关）与自由训练场（选一张地图练手）。
extends Control

var game = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop()
	_build()


func _backdrop() -> void:
	var fill = ColorRect.new()
	fill.color = Color(0.03, 0.06, 0.08, 0.94)
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(fill)


func _build() -> void:
	var back = Ui.button("← 回封面", 18, 130, 42)
	back.position = Vector2(56, 40)
	back.pressed.connect(func(): game.show_menu())
	add_child(back)
	var title = Ui.title("训练与教程", 48, Ui.GOLD_BRIGHT)
	title.position = Vector2(96, 100)
	add_child(title)
	var sub = Ui.label("教程只教一盏灯、一筒签、一座磨；训练场没有波次，也不写存档。",
		18, Ui.TEXT_DIM)
	sub.position = Vector2(100, 164)
	add_child(sub)

	var row = HBoxContainer.new()
	row.position = Vector2(96, 232)
	row.add_theme_constant_override("separation", 28)
	add_child(row)

	# 教程
	var tutorial = Ui.panel(0.92)
	tutorial.custom_minimum_size = Vector2(660, 480)
	row.add_child(tutorial)
	var box = Ui.vbox(10)
	tutorial.add_child(box)
	var head = Ui.hbox(12)
	box.add_child(head)
	head.add_child(Ui.seal("教"))
	head.add_child(Ui.title("新手教程", 34, Ui.GOLD_BRIGHT))
	box.add_child(Ui.hline(Ui.GOLD_DIM, 1.0))
	var steps = [
		"收下一团不会消失的香火",
		"请一株签筒出摊，并给它升一次「连发」",
		"看它自己打退一只 120 血的饿鬼",
		"灯、签、磨三样都上手，正式开张",
	]
	for i in steps.size():
		var line = Ui.hbox(8)
		box.add_child(line)
		line.add_child(Ui.label("%d." % (i + 1), 16, Ui.GOLD_DIM))
		var text = Ui.label(String(steps[i]), 17, Ui.TEXT)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size = Vector2(560, 0)
		line.add_child(text)
	box.add_child(Ui.spacer(6))
	box.add_child(Ui.label("约三分钟；教程里的一倍速不会变，慢慢看。", 15, Ui.TEXT_FAINT))
	var start_tutorial = Ui.button("开始教程", 22, 600, 56)
	start_tutorial.pressed.connect(func():
		game.loadout = ["shooter"]
		game.start_battle(0, ["shooter"], "tutorial"))
	box.add_child(start_tutorial)

	# 训练场
	var sandbox = Ui.panel(0.92)
	sandbox.custom_minimum_size = Vector2(660, 480)
	row.add_child(sandbox)
	var box2 = Ui.vbox(10)
	sandbox.add_child(box2)
	var head2 = Ui.hbox(12)
	box2.add_child(head2)
	head2.add_child(Ui.seal("练"))
	head2.add_child(Ui.title("自由训练场", 34, Ui.GOLD_BRIGHT))
	box2.add_child(Ui.hline(Ui.GOLD_DIM, 1.0))
	var notes = [
		"起手 1000 香火，卡组自选，冷却默认关闭",
		"不刷波次：恶客由「作弊 → 召唤」手动放",
		"不判负、不写存档，越线的恶客直接消失",
		"可以随时换地图、清空草木、退回选草",
	]
	for note in notes:
		var text = Ui.label("· " + String(note), 17, Ui.TEXT)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size = Vector2(600, 0)
		box2.add_child(text)
	box2.add_child(Ui.spacer(6))
	box2.add_child(Ui.label("选一张地图开始：", 16, Ui.TEXT_DIM))
	var days = Ui.hbox(10)
	box2.add_child(days)
	for day_index in 3:
		var day: Dictionary = Content.DAYS[day_index]
		var button = Ui.button("%s·%s" % [day["name"], day["sub"]], 17, 190, 48)
		button.pressed.connect(func():
			var level_id: int = day_index * 5 + 1
			game.prep = {"training_day": day_index + 1}
			game.show_prep(level_id, true, day_index + 1))
		days.add_child(button)
