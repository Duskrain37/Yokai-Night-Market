extends AcceptDialog
const Rules=preload("res://data/nightmare.gd")
var game
var level: Dictionary={}
var on_changed:=Callable()
var _summary: Label
var _lines: Dictionary={}
func _ready() -> void:
	Ui.style_dialog(self)
	title="噩梦因子 · 自择险途"
	get_ok_button().text="记下这些因子"
	get_ok_button().custom_minimum_size=Vector2(210,42)
	min_size=Vector2i(1060,760)
	var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.offset_left=22;margin.offset_top=18;margin.offset_right=-22;margin.offset_bottom=-65
	add_child(margin)
	var box:=Ui.vbox(12);margin.add_child(box)
	_summary=Ui.strong("",22,Ui.GOLD_BRIGHT);box.add_child(_summary)
	var note:=Ui.label("添加／减少可逐档调整。因子在开战时锁定，通关后留下朱印与挑战徽章。",16,Ui.TEXT_DIM)
	box.add_child(note)
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;box.add_child(scroll)
	var list:=Ui.vbox(9);list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(list)
	for factor in Rules.FACTORS:
		if factor.get("boss_only",false) and not Rules.has_boss(level):continue
		var panel:=Ui.panel(.95);list.add_child(panel)
		var row:=Ui.hbox(14);panel.add_child(row)
		var text:=Ui.vbox(4);text.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(text)
		var heading:=Ui.strong("",19,Ui.GOLD);text.add_child(heading)
		var desc:=Ui.label("",15,Ui.TEXT_DIM);desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size.x=620;text.add_child(desc)
		var minus:=Ui.button("减少",16,80,42);row.add_child(minus)
		var plus:=Ui.button("添加",16,80,42);row.add_child(plus)
		_lines[factor.id]=[heading,desc,minus,plus]
		minus.pressed.connect(_change.bind(factor,-1));plus.pressed.connect(_change.bind(factor,1))
	_refresh()
func _change(factor: Dictionary,delta: int) -> void:
	var raw:=Rules.sanitize(Dictionary(game.settings.get("nightmare_factors",{})),level)
	var tier:=clampi(int(raw.get(factor.id,0))+delta,0,factor.points.size())
	if tier==0:raw.erase(factor.id)
	else:raw[factor.id]=tier
	game.set_setting("nightmare_factors",raw)
	_refresh()
	if on_changed.is_valid():on_changed.call()
func _refresh() -> void:
	var raw:=Rules.sanitize(Dictionary(game.settings.get("nightmare_factors",{})),level)
	_summary.text="今夜因子数：%d  ·  噩梦通关后铭记最佳纪录" % Rules.points(raw)
	for factor in Rules.FACTORS:
		if not _lines.has(factor.id):continue
		var tier:=int(raw.get(factor.id,0));var widgets: Array=_lines[factor.id]
		widgets[0].text="%s  ·  %s" % [factor.name,"未添加" if tier==0 else "第 %d 档 · 因子 %d" % [tier,factor.points[tier-1]]]
		widgets[1].text=factor.descriptions[maxi(0,tier-1)]+("（可分 %d 档）" % factor.points.size() if tier==0 and factor.points.size()>1 else "")
		widgets[2].disabled=tier==0;widgets[3].disabled=tier==factor.points.size()
