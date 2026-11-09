extends AcceptDialog
const Rules=preload("res://data/nightmare.gd")
var entry: Dictionary={}
var earned: Array=[false,false,false,true]
func _ready() -> void:
	Ui.style_dialog(self);title="噩梦徽章 · 每一条险途都有印记";min_size=Vector2i(920,650)
	get_ok_button().text="收好徽章";get_ok_button().custom_minimum_size=Vector2(180,42)
	var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.offset_left=24;margin.offset_right=-24;margin.offset_top=24;margin.offset_bottom=-65;add_child(margin)
	var box:=Ui.vbox(12);margin.add_child(box)
	var row:=Ui.hbox(16);box.add_child(row)
	var rating=load("res://ui/star_rating.gd").new();rating.flags=earned;rating.factor_count=int(entry.get("best",0));row.add_child(rating)
	row.add_child(Ui.strong("最佳纪录 · %d 因子" % int(entry.get("best",0)),24,Ui.GOLD_BRIGHT))
	box.add_child(Ui.label("以下每枚朱印，都来自一次守到天亮的因子组合。",17,Ui.TEXT_DIM))
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;box.add_child(scroll)
	var list:=Ui.vbox(12);list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(list)
	var builds: Array=entry.get("builds",[]).duplicate();builds.sort_custom(func(a,b):return Rules.points(JSON.parse_string(a))>Rules.points(JSON.parse_string(b)))
	for signature in builds:
		var raw: Dictionary=JSON.parse_string(signature)
		var plate:=Ui.panel(.95);list.add_child(plate);var contents:=Ui.vbox(6);plate.add_child(contents)
		contents.add_child(Ui.strong("朱印 · %d 因子" % Rules.points(raw),20,Ui.GOLD))
		var descriptions: Array[String]=[]
		for factor in Rules.FACTORS:
			var tier:=int(raw.get(factor.id,0))
			if tier>0:descriptions.append(factor.name+"："+String(factor.descriptions[tier-1]))
		var text:=Ui.label("\n".join(descriptions),16,Ui.TEXT);text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;contents.add_child(text)
