extends Control

var game = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.04, 0.05, 0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var frame := Ui.panel(0.98, Ui.GOLD, 18, 2)
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.offset_left = -540
	frame.offset_right = 540
	frame.offset_top = -390
	frame.offset_bottom = 390
	add_child(frame)
	var outer := Ui.vbox(12)
	frame.add_child(outer)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/news_v052.json"))
	var head := Ui.hbox(12)
	outer.add_child(head)
	head.add_child(Ui.seal("新"))
	var heading := Ui.title("%s · v%s" % [data.title, data.version], 34)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(heading)
	var back := Ui.button("合上 (Esc)", 18, 150, 42)
	back.pressed.connect(game.close_overlay)
	head.add_child(back)
	outer.add_child(Ui.hline(Ui.GOLD_DIM))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var pages := Ui.vbox(16)
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(pages)
	for section in data.sections:
		pages.add_child(Ui.title(String(section.title), 27))
		for item in section.items:
			var card := Ui.panel(0.64, Color(Ui.GOLD_DIM, 0.45), 12, 1)
			pages.add_child(card)
			var lines := Ui.vbox(5)
			card.add_child(lines)
			lines.add_child(Ui.strong(String(item[0]), 20, Ui.GOLD))
			var body := Ui.label(String(item[1]), 18, Ui.TEXT)
			body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			body.custom_minimum_size.x = 920
			lines.add_child(body)
		pages.add_child(Ui.spacer(6))
