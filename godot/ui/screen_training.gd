extends Control
const Art = preload("res://ui/market_art.gd")
var game = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Art.backdrop(self, Art.ROOT + "menu-ensemble.png", 0.78)
	_build()
	Art.enter(self)

func _start_training_day(day: int) -> void:
	game.prep = {"training_day": day}
	game.show_prep(Content.level_id_for(day), true, day)

func _build() -> void:
	var back = Ui.button("← 回封面", 17, 142, 42)
	back.position = Vector2(48, 36)
	back.pressed.connect(game.show_menu)
	add_child(back)
	var title = Ui.title("训练与教程", 46)
	title.position = Vector2(78, 104)
	add_child(title)
	var note = Ui.label("先跟街坊学会守夜，再到训练场试一试自己的搭配。", 18, Ui.TEXT_DIM)
	note.position = Vector2(84, 169)
	add_child(note)
	var tutorial = Ui.panel()
	tutorial.position = Vector2(48, 226)
	tutorial.size = Vector2(520, 628)
	Ui.extend_to_bottom(tutorial,46)
	add_child(tutorial)
	var box = Ui.vbox(12)
	tutorial.add_child(box)
	box.add_child(Ui.title("初来夜市", 34))
	box.add_child(Ui.label("新手教程 · 跟着提示学会第一夜", 17, Ui.TEXT_DIM))
	var scene = Control.new()
	scene.custom_minimum_size = Vector2(450, 146)
	scene.draw.connect(func():
		for i in 3:
			Ui.draw_plant_icon(scene, ["lantern", "shooter", "wall"][i], Rect2(16 + i * 145, 5, 125, 136)))
	box.add_child(scene)
	box.add_child(Ui.hline(Color(Ui.GOLD_DIM, 0.5)))
	var steps = ["收下香火，请草木出摊", "给签筒升一阶，看它打退恶客", "请石磨守住一条街，正式开张"]
	for i in steps.size():
		var text = Ui.label("%02d  %s" % [i + 1, steps[i]], 18)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size.x = 450
		box.add_child(text)
	var space = Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(space)
	var hint = Ui.label("约三分钟。可随时暂停，也可以放慢战斗速度。", 15, Ui.TEXT_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	var start = Ui.button("开始教程", 23, 0, 60, true)
	start.pressed.connect(func(): game.loadout = ["shooter"]; game.start_battle(0, ["shooter"], "tutorial"))
	box.add_child(start)
	var sandbox = Ui.panel()
	sandbox.position = Vector2(588, 226)
	sandbox.size = Vector2(964, 628)
	Ui.extend_to_bottom(sandbox,46)
	add_child(sandbox)
	var content = Ui.vbox(14)
	sandbox.add_child(content)
	content.add_child(Ui.title("自由训练场", 34))
	var info = Ui.label("起手 1000 香火，自选卡组；手动召唤恶客，不判负、不记录战绩。", 17, Ui.TEXT_DIM)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(info)
	var grid = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 16)
	content.add_child(grid)
	for i in Content.DAYS.size():
		var card = Ui.vbox(0)
		card.custom_minimum_size = Vector2(294, 202)
		grid.add_child(card)
		var picture = TextureRect.new()
		picture.texture = load(Content.map_picture(Content.DAYS[i], true))
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.custom_minimum_size = Vector2(294, 148)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(picture)
		var button = Ui.button("%s·%s" % [Content.DAYS[i].name, Content.DAYS[i].sub], 17, 294, 48)
		button.pressed.connect(_start_training_day.bind(i + 1))
		card.add_child(button)
