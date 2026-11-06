extends "res://ui/screen_hud.gd"

var _mobile_info: Label
var _speed_button: Button
var _info_key := ""

func _build_hud() -> void:
	var left:=Ui.panel(0.88,Ui.GOLD_DIM,18,1)
	left.position=Vector2(12,16);left.size=Vector2(252,230)
	add_child(left)
	var status:=Ui.vbox(6);left.add_child(status)
	_sun_label=Ui.strong("",42,Ui.GOLD_BRIGHT);status.add_child(_sun_label)
	_wave_label=Ui.label("",25,Ui.TEXT);_wave_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;status.add_child(_wave_label)
	_wave_pips=Control.new();_wave_pips.custom_minimum_size=Vector2(236,53);_wave_pips.draw.connect(_draw_wave_pips);status.add_child(_wave_pips)
	var cards:=GridContainer.new();cards.columns=2;cards.position=Vector2(12,260)
	cards.add_theme_constant_override("h_separation",12);cards.add_theme_constant_override("v_separation",10)
	add_child(cards)
	for i in game.sim.cards.size():
		var card=CardButton.new();card.index=i;card.card_id=String(game.sim.cards[i].id);card.hud=self;card.custom_minimum_size=Vector2(120,116)
		cards.add_child(card);_card_nodes.append(card)
	var info:=Ui.panel(0.86,Ui.GOLD_DIM,16,1);info.position=Vector2(290,14);info.size=Vector2(1140,116);info.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(info)
	_mobile_info=Ui.label("轻点选草木，长按取消。\n点「图鉴」可阅读完整本事。",32,Ui.TEXT)
	_mobile_info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_mobile_info.mouse_filter=Control.MOUSE_FILTER_IGNORE;info.add_child(_mobile_info)
	var tools:=Ui.vbox(12);tools.position=Vector2(1450,16);add_child(tools)
	tools.add_child(_large_tool("暂停",func():game.toggle_pause(),true))
	_tool_shovel=_large_tool("",_on_shovel);_tool_shovel.icon=load("res://assets/sprites/lotus-trowel.png");_tool_shovel.expand_icon=true;_tool_shovel.icon_alignment=HORIZONTAL_ALIGNMENT_CENTER;_tool_shovel.add_theme_constant_override("icon_max_width",72);tools.add_child(_tool_shovel)
	_tool_wave=_large_tool("唤波",_on_quick_wave);tools.add_child(_tool_wave)
	_speed_button=_large_tool("1×",func():
		var at:=SPEEDS.find(game.speed)
		_set_speed(SPEEDS[(at+1)%SPEEDS.size()]))
	tools.add_child(_speed_button)
	tools.add_child(_large_tool("图鉴",func():
		var id: String=game.sim.cards[card_selected].id if card_selected>=0 else Content.PLANT_ORDER[0]
		game.open_almanac("plant",Content.PLANT_ORDER.find(id))))
	_tool_cheat=_large_tool("作弊",_toggle_cheat);_tool_cheat.visible=bool(game.settings.cheats) or game.sim.training;tools.add_child(_tool_cheat)
	var hint:=Ui.panel(0.8,Ui.GOLD_DIM,12,1);hint.position=Vector2(290,806);hint.size=Vector2(1140,76);add_child(hint)
	_hint_label=Ui.label("",28,Ui.TEXT);_hint_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;hint.add_child(_hint_label)
	_banner_band=ColorRect.new();_banner_band.color=Color(0.02,0.03,0.04,0.8);_banner_band.position=Vector2(280,140);_banner_band.size=Vector2(1150,140);_banner_band.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(_banner_band)
	_banner_label=Ui.title("",46);_banner_label.position=Vector2(300,145);_banner_label.size=Vector2(1100,70);_banner_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;_banner_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(_banner_label)
	_banner_sub=Ui.label("",30,Ui.GOLD);_banner_sub.position=Vector2(300,225);_banner_sub.size=Vector2(1100,70);_banner_sub.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;_banner_sub.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(_banner_sub)
	if game.tutorial_active:
		_build_tutorial()
		_tutorial_panel.offset_left=-530;_tutorial_panel.offset_right=530
		Ui.scale_font(_tutorial_label,"font_size",30)

func _large_tool(text: String, action: Callable, main:=false) -> Button:
	var button:=Ui.button(text,34,132,106,main)
	button.pressed.connect(action)
	return button

func refresh() -> void:
	super.refresh()
	if _wave_label!=null:_wave_label.text=_wave_label.text.replace(" · ","\n").replace(" / ","/")
	if _speed_button!=null:_speed_button.text="%s×" % _speed_text(game.speed)
	for card in _card_nodes:card.tooltip_text=""
	if _mobile_info!=null:
		var key: String=game.sim.cards[card_selected].id if card_selected>=0 else ""
		if key!=_info_key:
			_info_key=key
			if key.is_empty():_mobile_info.text="轻点选草木，长按取消。\n点「图鉴」可阅读完整本事。"
			else:
				var stats: Array=[]
				for row in Almanac.plant_rows(key):
					if "伤害" in String(row.label) or String(row.label) in ["攻击间隔","耐久"]:stats.append("%s %s" % [row.label,row.value])
				_mobile_info.text="%s · %d香火\n%s" % [Content.PLANTS[key].name,Content.PLANTS[key].cost," · ".join(stats.slice(0,3))]

func _refresh_tutorial() -> void:
	super._refresh_tutorial()
	if _tutorial_label!=null:_tutorial_label.text=_tutorial_label.text.replace("最上面那一排、正发着光的","左侧发着光的")

func blocks_simulation() -> bool:
	return cheat_open or (_fan!=null and is_instance_valid(_fan))

func _build_fan(plant, _at: Vector2) -> void:
	close_fan();focus_plant=plant
	_fan=load("res://ui/mobile_upgrade.gd").new();_fan.plant=plant;_fan.sim=game.sim
	_fan.picked.connect(_on_fan_pick);_fan.dismissed.connect(close_fan);add_child(_fan);_sync_fan()

func _build_pause() -> void:
	var screen=load("res://ui/mobile_screen.gd").new();screen.game=game;screen.kind="pause";add_child(screen)
func _build_result() -> void:
	var screen=load("res://ui/mobile_screen.gd").new();screen.game=game;screen.kind="result";add_child(screen)

func _build_cheat() -> void:
	if _cheat_panel!=null and is_instance_valid(_cheat_panel):remove_child(_cheat_panel);_cheat_panel.queue_free()
	_cheat_panel=Ui.panel(0.98,Ui.GOLD,20,2);_cheat_panel.position=Vector2(270,35);_cheat_panel.size=Vector2(1160,825);add_child(_cheat_panel)
	var outer:=Ui.vbox(12);_cheat_panel.add_child(outer)
	var head:=Ui.hbox(12);outer.add_child(head)
	head.add_child(Ui.title("临时调整",40))
	for item in [["misc","调整"],["spawn","召唤"]]:
		var button:=Ui.button(item[1],32,190,90);button.pressed.connect(func():cheat_tab=item[0];_build_cheat());head.add_child(button)
	var close:=Ui.button("收起",32,180,90);close.pressed.connect(_toggle_cheat);head.add_child(close)
	var scroll:=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;outer.add_child(scroll)
	var list:=Ui.vbox(12);list.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(list)
	if cheat_tab=="spawn":
		var grid:=GridContainer.new();grid.columns=3;grid.add_theme_constant_override("h_separation",10);grid.add_theme_constant_override("v_separation",10);list.add_child(grid)
		for type in Content.ZOMBIE_ORDER:
			if bool(Content.ZOMBIES[type].get("sedan_only",false)):continue
			var button:=Ui.button(Content.ZOMBIES[type].name,32,330,92)
			Ui.set_button_active(button,type==spawn_type)
			button.pressed.connect(func():spawn_type=type;_build_cheat());grid.add_child(button)
		var row:=Ui.hbox(12);list.add_child(row)
		for count in [1,3,5,10]:
			var button:=Ui.button("%d位" % count,32,210,90);Ui.set_button_active(button,spawn_count==count);button.pressed.connect(func():spawn_count=count;_build_cheat());row.add_child(button)
		var lanes:=Ui.hbox(8);list.add_child(lanes)
		for lane in range(-1,game.sim.rows):
			var button:=Ui.button("随机" if lane<0 else "%d路" % (lane+1),30,140,88);button.pressed.connect(func():spawn_lane=lane;_build_cheat());Ui.set_button_active(button,lane==spawn_lane);lanes.add_child(button)
		var summon:=Ui.button("召来",36,1000,106,true);summon.pressed.connect(_cheat(func():game.sim.summon_training(spawn_type,spawn_count,spawn_lane)));list.add_child(summon)
	else:
		var actions: Array=[["香火增加500",func():game.sim.sun+=500],["击退所有恶客",func():game.sim.kill_all_zombies()],["门神归位",func():game.sim.restore_mowers()]]
		if game.tutorial_active:actions.resize(1)
		elif game.sim.training:
			actions.append_array([["切换无冷却",func():game.sim.no_cooldown=not game.sim.no_cooldown],["清空草木",func():game.sim.clear_plants()],["切换地图",func():
				var day: int=int(game.training.get("day",1))%Content.DAYS.size()+1
				game.training.day=day;game.start_battle(Content.level_id_for(day),game.loadout,"training")],["退回选草",func():game.show_prep(Content.level_id_for(int(game.training.day)),true,int(game.training.day))]])
		else:actions.append(["直接守住这一夜",func():game.finish_run(true)])
		for item in actions:
			var button:=Ui.button(item[0],34,1000,100);button.pressed.connect(_cheat(item[1]));list.add_child(button)
