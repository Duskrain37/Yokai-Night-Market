extends "res://ui/screen_levels.gd"

func _node_scale(_index: int) -> float: return 1.7
func _build_week_tabs() -> void:
	_week_scroll=ScrollContainer.new();_week_scroll.position=Vector2(30,145);_week_scroll.size=Vector2(290,586)
	_week_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_week_scroll)
	var list:=Ui.vbox(12);list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;_week_scroll.add_child(list)
	for i in Content.DAYS.size():
		var def: Dictionary=Content.DAYS[i]
		var button:=Ui.button("%s\n%s" % [def.name,def.sub],32,270,144)
		button.pressed.connect(select_day.bind(i+1));list.add_child(button);_week_buttons.append(button)
func _build_actions() -> void:
	var back:=Ui.button("回封面",34,260,96);back.position=Vector2(30,28);back.pressed.connect(game.show_menu);add_child(back)
	_enter=Ui.button("进入备战",38,460,112,true);_enter.position=Vector2(1100,770);_enter.pressed.connect(func():game.show_prep(selected));add_child(_enter)
	_special=Ui.button("鬼市深处",34,280,110);_special.position=Vector2(30,754);_special.pressed.connect(func():switch_to_level(16));add_child(_special)
	_almanac=Ui.button("图鉴",34,170,96);_almanac.position=Vector2(1400,28);_almanac.pressed.connect(func():game.open_almanac("zombie",0));add_child(_almanac)
	_danger=preload("res://ui/threat_meter.gd").new();_danger.position=Vector2(360,845);_danger.size=Vector2(270,22);add_child(_danger)
func _draw_header() -> void:
	var level: Dictionary=Content.get_level(selected)
	draw_string(Ui.display_font(),Vector2(430,82),"%s · %s" % [level.day_name,level.day_sub],HORIZONTAL_ALIGNMENT_LEFT,-1,42,Ui.GOLD_BRIGHT)
func _draw_footer() -> void:
	var level: Dictionary=Content.get_level(selected)
	Ui.draw_plate(self,Rect2(340,765,730,117),Color(0.03,0.06,0.08,0.9),Ui.GOLD_DIM,18,1)
	draw_string(Ui.body_font(),Vector2(360,815),String(level.name)+" · %d大波" % Content.wave_groups(level),HORIZONTAL_ALIGNMENT_LEFT,-1,32,Ui.TEXT)
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_RIGHT:game.show_menu();accept_event();return
		if event.button_index==MOUSE_BUTTON_LEFT:
			for i in 5:
				if event.position.distance_to(_node_pos(i))<=64:select_night(i);accept_event();return
