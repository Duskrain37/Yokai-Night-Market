extends Control

const Settings = preload("res://ui/screen_settings.gd")
var game = null
var kind := "menu"
var tab := "plant"
var index := 0
var selected: Array = []
var _body: VBoxContainer
var _footer: VBoxContainer
var _confirm_missing := false
var _filter := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_render()

func _render() -> void:
	for child in get_children():remove_child(child);child.queue_free()
	var bg:=TextureRect.new();bg.texture=load("res://assets/bg/menu.jpg");bg.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);bg.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(bg)
	var dim:=ColorRect.new();dim.color=Color(0.015,0.03,0.04,0.35 if kind=="menu" else 0.82);dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);dim.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(dim)
	var frame:=Ui.panel(0.55 if kind=="menu" else 0.9,Ui.GOLD_DIM,22,2);frame.position=Vector2(52,32);frame.size=Vector2(1496,836);add_child(frame)
	var outer:=Ui.vbox(14);frame.add_child(outer)
	var header:=Ui.hbox(18);outer.add_child(header)
	var title:=Ui.title({"menu":"妖怪夜市","prep":"请草木出摊","almanac":"灯下图鉴","settings":"设置","training":"训练与教程","pause":"歇一歇","result":"守住了" if game.result.get("won",false) else "夜市失守"}.get(kind,"夜市"),76 if kind=="menu" else 48)
	title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(title)
	var back:=Ui.button("公告" if kind=="menu" else "返回",34,240,96)
	back.pressed.connect(_back);header.add_child(back)
	var scroll:=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;outer.add_child(scroll)
	_body=Ui.vbox(16);_body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(_body)
	_footer=Ui.vbox(10);outer.add_child(_footer)
	match kind:
		"menu":_menu()
		"prep":_prep()
		"almanac":_book()
		"settings":_settings()
		"training":_training()
		"pause":_pause()
		"result":_result()

func _back() -> void:
	match kind:
		"menu":game.open_news()
		"pause":game.close_pause()
		"settings","almanac":game.close_overlay()
		"prep":game.show_training_menu() if game.prep.get("training",false) else game.show_levels()
		_:game.show_menu()

func _text(value: String, tone: Color=Ui.TEXT) -> void:
	var label:=Ui.label(value,36,tone);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_body.add_child(label)
func _button(title: String, action: Callable, main:=false) -> Button:
	var button:=Ui.button(title,38 if main else 34,1280,128 if main else 100,main);button.pressed.connect(action);_body.add_child(button);return button
func _menu() -> void:
	_text("灯火将明，请草木出摊，守住这条夜市。",Ui.GOLD)
	if game.has_save():_button("继续守夜",game.continue_run,true)
	_button("开始守夜 · 选择今夜",game.show_levels,not game.has_save())
	var row:=Ui.hbox(14);_body.add_child(row)
	for pair in [["图鉴",func():game.open_almanac()],["训练与教程",game.show_training_menu],["设置",game.open_settings]]:
		var button:=Ui.button(pair[0],36,430,106);button.pressed.connect(pair[1]);row.add_child(button)
	if not game.run_snapshots[game.active_slot].is_empty():
		_button("回看上次守夜",func():
			game.result=game.run_snapshots[game.active_slot].get("result",{}).duplicate(true)
			game._show_result(bool(game.result.get("won",false))))
	_text("守夜簿",Ui.GOLD)
	var slots:=Ui.hbox(14);_body.add_child(slots)
	for slot in 3:
		var button:=Ui.button("第%d卷%s" % [slot+1," · 当前" if slot==game.active_slot else ""],34,430,104)
		Ui.set_button_active(button,slot==game.active_slot);button.pressed.connect(func():game.set_run_slot(slot);_render());slots.add_child(button)
	_text("轻点选择与放置，长按取消。卡牌与进化说明都能点开查看。")

func _training() -> void:
	_text("先跟着教程认识香火、布阵和进化，再去训练场试一试自己的搭配。")
	_button("开始新手教程",func():game.loadout=["shooter"];game.start_battle(0,["shooter"],"tutorial"),true)
	_text("自由训练 · 自选草木、手动召来恶客，不计守夜战绩。",Ui.GOLD)
	var grid:=GridContainer.new();grid.columns=3;grid.add_theme_constant_override("h_separation",16);grid.add_theme_constant_override("v_separation",16);_body.add_child(grid)
	for i in Content.DAYS.size():
		var def: Dictionary=Content.DAYS[i];var button:=Ui.button("%s\n%s" % [def.name,def.sub],36,430,140)
		button.pressed.connect(func():game.show_prep(Content.level_id_for(i+1),true,i+1));grid.add_child(button)

func _prep() -> void:
	var level: Dictionary=game.prep.level
	if selected.is_empty():selected=game.prep.selected.duplicate()
	var theme:=Ui.label("%s · %s\n%s" % [level.day_name,level.name,String(level.get("theme",""))],30,Ui.GOLD);theme.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_body.add_child(theme)
	var head:=Ui.hbox(14);_body.add_child(head)
	var count:=Ui.label("已选%d/10" % selected.size(),36);head.add_child(count)
	var auto:=Ui.button("推荐阵容",34,300,96);auto.pressed.connect(func():selected=Content.night_loadout_tips(level).slice(0,10);game.prep.selected=selected.duplicate();_render());head.add_child(auto)
	var book:=Ui.button("查看草木图鉴",34,400,96);book.pressed.connect(func():game.open_almanac("plant",0));head.add_child(book)
	var columns:=Ui.hbox(20);_body.add_child(columns)
	var plant_scroll:=ScrollContainer.new();plant_scroll.name="PlantScroll";plant_scroll.custom_minimum_size=Vector2(960,292);plant_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;columns.add_child(plant_scroll)
	var foe_scroll:=ScrollContainer.new();foe_scroll.name="FoeScroll";foe_scroll.custom_minimum_size=Vector2(370,292);foe_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;columns.add_child(foe_scroll)
	var grid:=GridContainer.new();grid.columns=3 if Ui.text_scale>1.15 else 4;grid.add_theme_constant_override("h_separation",12);grid.add_theme_constant_override("v_separation",12);plant_scroll.add_child(grid)
	for type in Content.PLANT_ORDER:
		var def: Dictionary=Content.PLANTS[type]
		var button:=Ui.button("%s\n%d香火" % [def.name,def.cost],30,230,136)
		button.icon=Ui.sprite(type);button.expand_icon=true;button.add_theme_constant_override("icon_max_width",64)
		Ui.set_button_active(button,type in selected)
		button.pressed.connect(func():
			if type in selected:selected.erase(type)
			elif selected.size()<10:selected.append(type)
			game.prep.selected=selected.duplicate();_confirm_missing=false;_render())
		grid.add_child(button)
	var foes:=Ui.vbox(14);foes.custom_minimum_size.x=360;foe_scroll.add_child(foes);foes.add_child(Ui.title("今夜来客",36))
	var roster: Array=Content.plants_in_level(level).duplicate()
	for id in [level.get("mid_boss",""),level.get("boss_id","")]:
		if not String(id).is_empty():roster.append("boss-"+String(id))
	for type in roster:
		var boss:=String(type).begins_with("boss-")
		var name: String=Almanac.boss_name(String(type).trim_prefix("boss-")) if boss else Content.ZOMBIES[type].name
		var button:=Ui.button(name,30,360,112)
		button.icon=Almanac.boss_portrait(String(type).trim_prefix("boss-")) if boss else Ui.sprite(type);button.expand_icon=true;button.add_theme_constant_override("icon_max_width",64)
		button.pressed.connect(func():game.open_almanac("boss" if boss else "zombie",Almanac.BOSS_ORDER.find(String(type).trim_prefix("boss-")) if boss else Content.ZOMBIE_ORDER.find(type)))
		foes.add_child(button)
	var names: Array=[]
	for type in selected:names.append(Content.PLANTS[type].name)

	if not level.get("water_rows",[]).is_empty() and not "lily" in selected:
		_text("水面需要先放夜莲，这套草木还没有带上。",Ui.WARN)
		_button("带上夜莲",func():
			if selected.size()>=10:selected.pop_back()
			selected.push_front("lily");game.prep.selected=selected.duplicate();_render())
	if _confirm_missing:_text("没有携带能产香火的草木，开局后只能等天上掉落。仍要出发吗？",Ui.WARN)
	var launch:=Ui.button("仍要出发" if _confirm_missing else "开始守夜",38,1300,118,true)
	launch.disabled=selected.is_empty();launch.pressed.connect(_launch);_footer.add_child(launch)

func _launch() -> void:
	var producer:=false
	for type in selected:
		if Content.PLANTS[type].get("role","")=="产能":producer=true
	if not producer and not _confirm_missing:_confirm_missing=true;_render();return
	game.loadout=selected.duplicate();game.save_progress()
	if bool(game.prep.get("training",false)):
		game.training={"day":int(game.prep.training_day),"cooldown_locked":false}
		game.start_battle(int(game.prep.level.id),selected,"training")
	else:game.start_battle(int(game.prep.level.id),selected,"normal")
func skip_cinema() -> void: pass

func _entries() -> Array:
	return Almanac.BOSS_ORDER if tab=="boss" else (Content.PLANT_ORDER if tab=="plant" else Content.ZOMBIE_ORDER)
func _book() -> void:
	var nav:=Ui.hbox(12);_body.add_child(nav)
	for pair in [["plant","草木志"],["zombie","恶客录"],["boss","恶首录"]]:
		var button:=Ui.button(pair[1],34,300,96);Ui.set_button_active(button,tab==pair[0]);button.pressed.connect(func():tab=pair[0];index=0;_render());nav.add_child(button)
	if tab!="boss":
		var key: String="almanac_plant_order" if tab=="plant" else "almanac_guest_order"
		var category: bool=String(game.settings.get(key,"release"))=="category"
		var button:=Ui.button("按类型排列" if tab=="plant" and category else ("低—中—高排列" if category else "按发布顺序"),30,400,96)
		button.pressed.connect(func():game.set_setting(key,"release" if category else "category");_render());nav.add_child(button)
	var columns:=Ui.hbox(24);_body.add_child(columns)
	var list_scroll:=ScrollContainer.new();list_scroll.custom_minimum_size=Vector2(330,520);list_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;columns.add_child(list_scroll)
	var detail_scroll:=ScrollContainer.new();detail_scroll.custom_minimum_size=Vector2(1010,520);detail_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;columns.add_child(detail_scroll)
	var list:=Ui.vbox(10);list.custom_minimum_size.x=310;list_scroll.add_child(list)
	var ids: Array=_entries().duplicate();var category: bool=tab!="boss" and String(game.settings.get("almanac_plant_order" if tab=="plant" else "almanac_guest_order","release"))=="category"
	if category:
		ids.sort_custom(func(a,b):
			var ra: String=Content.PLANTS[a].role if tab=="plant" else Content.ZOMBIES[a].tier
			var rb: String=Content.PLANTS[b].role if tab=="plant" else Content.ZOMBIES[b].tier
			if tab=="zombie":return ["l","m","h"].find(ra)<["l","m","h"].find(rb) if ra!=rb else _entries().find(a)<_entries().find(b)
			return ra<rb if ra!=rb else _entries().find(a)<_entries().find(b))
	for id in ids:
		var name: String=Almanac.boss_name(id) if tab=="boss" else (Content.PLANTS[id].name if tab=="plant" else Content.ZOMBIES[id].name)
		var button:=Ui.button(name,32,310,104);Ui.set_button_active(button,_entries().find(id)==index);button.pressed.connect(func():index=_entries().find(id);_render());list.add_child(button)
	var detail:=Ui.vbox(18);detail.custom_minimum_size.x=980;detail.size_flags_horizontal=Control.SIZE_EXPAND_FILL;detail_scroll.add_child(detail)
	index=clampi(index,0,_entries().size()-1)
	var id: String=_entries()[index]
	var portrait:=TextureRect.new();portrait.texture=Almanac.boss_portrait(id) if tab=="boss" else Ui.sprite(id);portrait.custom_minimum_size=Vector2(220,240);portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;detail.add_child(portrait)
	if tab=="boss":
		for skill in Almanac.boss_skills(id):_detail_text(detail,"%s\n%s" % [skill[0],skill[1]])
		return
	_detail_text(detail,Almanac.plant_ability(id) if tab=="plant" else Almanac.zombie_ability(id))
	var stats: Array=Almanac.plant_rows(id) if tab=="plant" else Almanac.zombie_rows(id)
	for stat in stats:_detail_text(detail,"%s：%s" % [stat.label,stat.value])
	if tab=="plant":
		for path in Upgrades.paths_for(id):
			_detail_text(detail,"%s" % path.name,Ui.GOLD)
			for i in path.tiers.size():_detail_text(detail,"%d阶 · %d香火\n%s" % [i+1,path.tiers[i].cost,path.tiers[i].desc])
	else:_detail_text(detail,String(Almanac.ZOMBIES[id].get("story","")))
func _detail_text(parent: Control, text: String, tone:=Ui.TEXT) -> void:
	var label:=Ui.label(text,36,tone);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;parent.add_child(label)

func _settings() -> void:
	_text("画面帧率",Ui.GOLD)
	var fps_row:=Ui.hbox(14);_body.add_child(fps_row)
	for fps in [30,60]:
		var button:=Ui.button("%d帧 · %s" % [fps,"省电" if fps==30 else "流畅"],34,560,100)
		Ui.set_button_active(button,int(game.settings.get("mobile_target_fps",60))==fps)
		button.pressed.connect(func():game.set_setting("mobile_target_fps",fps);_render());fps_row.add_child(button)
	for section in [0,1,2]:
		for row in Settings.ROWS[section]:
			if row.key=="resolution":continue
			_text(row.label,Ui.GOLD);_text(row.note)
			if row.get("type","")=="range":
				var controls:=Ui.hbox(18);_body.add_child(controls)
				for step in [-10,10]:
					var button:=Ui.button("−10" if step<0 else "+10",36,300,96);button.pressed.connect(func():game.set_setting(row.key,clampi(int(game.settings[row.key])+step,0,100));_render());controls.add_child(button)
				controls.add_child(Ui.strong(str(game.settings[row.key]),40));continue
			var choices:=Ui.hbox(12);_body.add_child(choices)
			for option in row.options:
				var button:=Ui.button(option[1],32,250,94);Ui.set_button_active(button,game.settings[row.key]==option[0]);button.disabled=bool(row.get("lock_in_run",false)) and game.sim!=null
				button.pressed.connect(func():game.set_setting(row.key,option[0]);_render());choices.add_child(button)
	_text("横屏画面自动适配屏幕；轻点操作，长按取消，拖动列表翻阅。")

func _pause() -> void:
	_text("这一夜还长，喘口气再守。")
	_button("重返游戏",game.close_pause,true)
	_button("查看图鉴",func():game.open_almanac())
	_button("设置",game.open_settings)
	_button("重新开始这一夜",game.restart_run)
	_button("回到封面",game.back_to_menu)
func _result() -> void:
	var result: Dictionary=game.result
	_text("天亮了，摊子守住了。" if result.get("won",false) else "整理一下草木，换个布阵再来。")
	_text("守住%d大波，击退%d位恶客，剩余%d香火。" % [int(result.get("groups_completed",0)),int(result.get("kills",0)),int(result.get("sun",0))])
	if result.get("won",false) and Content.next_story_level(int(result.get("level_id",1)))>0:_button("下一夜",func():game.show_prep(Content.next_story_level(int(result.get("level_id",1)))),true)
	_button("再守一次",game.restart_run,not result.get("won",false))
	_button("选择其他夜晚",game.show_levels)
	_button("回到封面",game.show_menu)
