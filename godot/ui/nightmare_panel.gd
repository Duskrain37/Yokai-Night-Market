extends AcceptDialog
const Rules=preload("res://data/nightmare.gd")
const Danger=preload("res://ui/danger_art.gd")
var game
var level: Dictionary={}
var on_changed:=Callable()
var _summary: Label
var _lines: Dictionary={}
var _total_plate: PanelContainer
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
	_total_plate=Danger.new();_total_plate.name="FactorTotalPlate";box.add_child(_total_plate)
	var total_row:=Ui.hbox(18);_total_plate.add_child(total_row)
	var seal:=Danger.emblem("boss_power",62);seal.modulate=Color("#f6b78b");total_row.add_child(seal)
	var total_text:=Ui.vbox(3);total_text.size_flags_horizontal=Control.SIZE_EXPAND_FILL;total_row.add_child(total_text)
	total_text.add_child(Ui.label("夜契已立 · 百鬼叩门",16,Color("#dfa88a")))
	_summary=Ui.strong("",30,Color("#ffdbad"));total_text.add_child(_summary)
	var note:=Ui.label("添加／减少可逐档调整。因子在开战时锁定，通关后留下朱印与挑战徽章。",16,Ui.TEXT_DIM)
	box.add_child(note)
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;box.add_child(scroll)
	var list:=Ui.vbox(9);list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(list)
	for factor in Rules.FACTORS:
		if not Rules.eligible(factor,level):continue
		var panel:=Danger.new();panel.name="Factor_"+String(factor.id);list.add_child(panel)
		var row:=Ui.hbox(14);panel.add_child(row)
		var icon:=Danger.emblem(factor.id);row.add_child(icon)
		var text:=Ui.vbox(4);text.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(text)
		var heading:=Ui.strong("",19,Ui.GOLD);text.add_child(heading)
		var desc:=Ui.label("",15,Ui.TEXT_DIM);desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size.x=500;text.add_child(desc)
		var levels:=Ui.vbox(6);row.add_child(levels)
		var badge:=Ui.label("",14,Ui.TEXT);badge.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;levels.add_child(badge)
		var bar:=Danger.level_bar(0,factor.points.size());levels.add_child(bar)
		var minus:=Ui.button("减少",16,80,42);row.add_child(minus)
		var plus:=Ui.button("添加",16,80,42);row.add_child(plus)
		_lines[factor.id]=[heading,desc,minus,plus,panel,icon,badge,bar]
		minus.pressed.connect(_change.bind(factor,-1));plus.pressed.connect(_change.bind(factor,1))
	_refresh()
func _change(factor: Dictionary,delta: int) -> void:
	var raw:=Dictionary(game.settings.get("nightmare_factors",{})).duplicate()
	var tier:=clampi(int(raw.get(factor.id,0))+delta,0,factor.points.size())
	if tier==0:raw.erase(factor.id)
	else:raw[factor.id]=tier
	game.set_setting("nightmare_factors",raw)
	_refresh()
	if on_changed.is_valid():on_changed.call()
func _refresh() -> void:
	var raw:=Rules.sanitize(Dictionary(game.settings.get("nightmare_factors",{})),level)
	var total:=Rules.points(raw);_total_plate.set_risk(Rules.danger_band(total),3,true)
	_summary.text="今夜因子总数  %d  ·  %s" % [total,["险途初启","凶兆渐盛","百鬼环伺","长夜绝境"][Rules.danger_band(total)]]
	for factor in Rules.FACTORS:
		if not _lines.has(factor.id):continue
		var tier:=int(raw.get(factor.id,0));var widgets: Array=_lines[factor.id]
		widgets[0].text="%s  ·  %s" % [factor.name,"未选择" if tier==0 else "等级%d · 因子%d" % [tier,factor.points[tier-1]]]
		widgets[1].text=factor.descriptions[maxi(0,tier-1)]
		widgets[2].disabled=tier==0;widgets[3].disabled=tier==factor.points.size()
		widgets[4].set_risk(tier,factor.points.size());widgets[5].modulate=Danger.tone(tier,factor.points.size())
		widgets[0].add_theme_color_override("font_color",Danger.tone(tier,factor.points.size()))
		widgets[6].text="等级%d / %d" % [tier,factor.points.size()]
		widgets[7].set_meta("tier",tier);widgets[7].queue_redraw()
