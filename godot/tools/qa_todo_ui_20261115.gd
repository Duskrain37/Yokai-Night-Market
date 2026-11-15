extends SceneTree
const Rules=preload("res://data/nightmare.gd")
class PreviewGame extends "res://scripts/game.gd":
	func _data_path(path:String) -> String:
		var folder:="res://qa/todo-20261115-runtime";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder));return folder.path_join(path.get_file())
var game
var checks:Array=[]
var failures:=0
var dimensions:=Vector2i(1600,1000)
var capture_enabled:=false
func check(label:String,ok:bool):
	checks.append({"name":label,"ok":ok})
	if not ok:failures+=1;printerr("FAIL ",label)
func settle(count:int=6):
	for i in count:await process_frame
func buttons(node:Node,text:String="") -> Array:
	var out:Array=[]
	if node is Button and (text.is_empty() or node.text==text):out.append(node)
	for child in node.get_children():out.append_array(buttons(child,text))
	return out
func click(button:Control):
	var at:=button.get_global_rect().get_center()
	if button.get_viewport()!=root and button.get_viewport() is Window:at+=Vector2(button.get_viewport().position)
	var move:=InputEventMouseMotion.new();move.position=at;move.global_position=at
	root.push_input(move,true);await process_frame
	for down in [true,false]:
		var event:=InputEventMouseButton.new();event.position=at;event.global_position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true);await process_frame
	await settle()
func capture(label:String):
	if not capture_enabled:return
	await settle();await RenderingServer.frame_post_draw
	var folder:="res://qa/todo-20261115-gallery";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var image:=root.get_texture().get_image();check(label+"截图尺寸",image.get_size()==dimensions)
	image.save_png(ProjectSettings.globalize_path(folder.path_join("%s-%dx%d.png"%[label,dimensions.x,dimensions.y])))
func _initialize():run.call_deferred()
func run():
	for arg in OS.get_cmdline_user_args():
		if arg=="--capture-gallery":capture_enabled=true
		if arg.begins_with("--qa-size="):
			var parts=arg.trim_prefix("--qa-size=").split("x");dimensions=Vector2i(int(parts[0]),int(parts[1]))
	root.content_scale_size=Vector2i(1600,900);root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
	root.gui_embed_subwindows=true;root.mode=Window.MODE_WINDOWED;root.size=dimensions
	game=PreviewGame.new();root.add_child(game);await settle();game.set_process(false)
	game.settings.reduced_motion=true;MarketArt.reduced_motion=true;game.settings.active_skill_mode="both"
	if "--qa-large" in OS.get_cmdline_user_args():game.settings.ui_text_size="large";game._apply_ui_text_size()
	game.settings.difficulty="nightmare";game.settings.nightmare_factors={};game.show_prep(5);game.screen_node.skip_cinema();await settle()
	var factor_button=game.screen_node.find_child("NightmareFactors",true,false)
	check("噩梦入口醒目红色主样式",factor_button.get_meta("primary",false) and factor_button.custom_minimum_size.y>=50)
	await click(factor_button)
	var dialog=game.screen_node.get_child(game.screen_node.get_child_count()-1)
	check("因子对话框使用独立总数牌",dialog._total_plate.name=="FactorTotalPlate" and dialog._summary.text.contains("今夜因子总数"))
	check("窗口标题背景覆盖整个标题栏",float(dialog.theme.get_stylebox("embedded_border","Window").get("expand_margin_top"))>=dialog.theme.get_constant("title_height","Window"))
	check("每项因子含图标和等级条",dialog._lines.size()==15 and dialog._lines.values().all(func(row):return row.size()==8 and row[7].has_meta("maximum")))
	await capture("nightmare-unselected")
	await click(dialog._lines.light_pack[3]);check("等级1黄色状态",dialog._lines.light_pack[4].risk==1 and dialog._lines.light_pack[6].text=="等级1 / 2")
	await click(dialog._lines.light_pack[3]);check("两级因子的最高级暗红",dialog._lines.light_pack[4].risk==3 and dialog._lines.light_pack[6].text=="等级2 / 2")
	game.settings.nightmare_factors={"swarm":2,"price":1,"dim":1,"no_capstone":1};dialog._refresh();await settle()
	check("三级因子等级2为红色",dialog._lines.swarm[4].risk==2)
	check("一级因子选中为红色",dialog._lines.no_capstone[4].risk==2)
	await capture("nightmare-tier-colors")
	var all:Dictionary={}
	for f in Rules.FACTORS:all[f.id]=f.points.size()
	game.settings.nightmare_factors=all;dialog._refresh();await settle()
	check("总因子15以上进入最高危险样式",dialog._total_plate.risk==3 and Rules.points(all)>=15)
	await capture("nightmare-total-high")
	dialog.hide();dialog.queue_free();await settle()
	game.settings.nightmare_factors={"no_ash":1};game.show_prep(1);game.screen_node.skip_cinema();await settle()
	var prep=game.screen_node
	check("名册只保留全部产能输出功能",prep._filter_buttons.keys()==["全部","产能","输出","功能"])
	check("铜钱荚归产能，劫火芝归输出",prep._category("cash-pod")=="产能" and prep._category("ruin-cap")=="输出")
	prep._picked=["shooter"];prep._refresh();prep.toggle_plant("bomb")
	check("备战不能添加被禁灰烬草木",not prep._picked.has("bomb"))
	prep._picked=["shooter","bomb"];prep._refresh();prep._start()
	check("带入灰烬旧卡组时阻止开战",game.screen=="prep" and prep._warning.text.contains("灰契封炉"))
	await capture("preparation-functional-categories")
	game.settings.difficulty="easy";game.settings.nightmare_factors={}
	game.open_almanac("plant",Content.PLANT_ORDER.find("cat"));await settle()
	var book=game.screen_node;book._jump_to_section("进化");await settle()
	var second=book.find_child("EvolutionNode_2_2",true,false);await click(second)
	check("点击二阶节点显示二阶展示卡",book.find_child("EvolutionCard_2_2",true,false)!=null and book._tier_selection["cat:2"]==2)
	await capture("almanac-evolution-two")
	var third=book.find_child("EvolutionNode_2_3",true,false);await click(third)
	check("点击三阶节点显示三阶展示卡",book.find_child("EvolutionCard_2_3",true,false)!=null and book._tier_selection["cat:2"]==3)
	check("未展开全表仅呈现所选等级",book.find_child("EvolutionCard_2_1",true,false)==null and book.find_child("EvolutionCard_2_2",true,false)==null)
	await capture("almanac-evolution-three")
	var confirm:=ConfirmationDialog.new();confirm.dialog_text="请核对当前选择，再继续守夜。";Ui.style_dialog(confirm)
	confirm.get_ok_button().text="继续";confirm.get_cancel_button().text="返回选择";confirm.min_size=Vector2i(780,300);game.screen_node.add_child(confirm);confirm.popup_centered(Vector2i(780,300));await settle()
	check("通用确认窗口双按钮均匀排满",absf(confirm.get_ok_button().size.x-confirm.get_cancel_button().size.x)<1 and confirm.get_ok_button().size.x>250)
	await capture("confirmation-balanced-actions");confirm.hide();confirm.queue_free();await settle()
	game.start_battle(1,["shooter","judge","sky-mortar","wall","herb-gourd","shell"],"training");game.paused=false;await settle()
	var s:Sim=game.sim;s.plants.clear();s.zombies.clear();s.orbs.clear();s.time=10
	check("训练作弊按钮放大标红并位于倍速下",game.hud._tool_cheat.get_meta("primary",false) and game.hud._tool_cheat.position.y>=90 and game.hud._tool_cheat.custom_minimum_size.x>=180)
	await click(game.hud._tool_cheat)
	check("作弊杂项改为功能",not buttons(game.hud._cheat_panel,"功能").is_empty() and buttons(game.hud._cheat_panel,"杂项").is_empty())
	var incense:int=s.sun;await click(buttons(game.hud._cheat_panel,"香火 +2000")[0]);check("真实点击一次增加2000香火",s.sun==incense+2000)
	await click(buttons(game.hud._cheat_panel,"主动技能无冷却 已关")[0]);check("真实点击开启主动技能无冷却",s.no_skill_cooldown)
	await capture("training-functions")
	await click(buttons(game.hud._cheat_panel,"召唤")[0]);check("召唤按低中高分组",["低阶","中阶","高阶"].all(func(t):return not buttons(game.hud._cheat_panel,t).is_empty()))
	await click(buttons(game.hud._cheat_panel,"高阶")[0]);var candidates=buttons(game.hud._cheat_panel).filter(func(b):return b.has_meta("guest_id"))
	check("高阶分组只显示高阶恶客",not candidates.is_empty() and candidates.all(func(b):return Content.ZOMBIES[b.get_meta("guest_id")].tier=="h"))
	await capture("training-summon-tiers")
	await click(buttons(game.hud._cheat_panel,"功能")[0]);await click(buttons(game.hud._cheat_panel,"切换地图")[0])
	check("切换地图回到训练地图选择",game.screen=="training")
	game.start_battle(1,["shooter","wall","herb-gourd"],"training");game.paused=false;await settle();s=game.sim
	s.plants.clear();s.zombies.clear();s.orbs.clear();s.time=20
	var plant=s.place_free("shooter",2,2);plant.upgrades={1:2,2:0,3:3};var tank=s.spawn_zombie("mountain",2,{"x":1050});tank.hp=50000;tank.max_hp=50000;s.activate_skill(plant)
	for age in [.05,.3,.7,1.4]:
		while s.time<plant.skill_cast_at+age-.0001:
			var dt:float=minf(.01,plant.skill_cast_at+age-s.time)
			s.time+=dt;s._update_shooter(plant,dt);s.update_shots(dt);s.update_particles(dt);s.vital_numbers.update(dt)
		game.hud.refresh();await capture("sign-rain-%02d"%int(age*100))
	s.vital_numbers.clear();var hurt=s.place_free("wall",3,1);hurt.hp=100;s.damage_plant(hurt,25);s.heal_plant(hurt,20)
	var guest=s.zombies[0];s.damage_zombie(guest,125);game.hud.refresh();await capture("combat-numbers-medium")
	game.set_setting("combat_numbers","large");await capture("combat-numbers-large")
	check("战斗数字在恶首模型上层绘制",game.units.get_node("CombatNumbers").z_index+game.units.z_index>game.boss_view.z_index)
	game.set_setting("combat_numbers","off");check("关闭数字立即生效",s.vital_numbers.mode=="off" and s.vital_numbers.entries.is_empty())
	game.set_setting("combat_numbers","medium");game.show_pause();await settle()
	var pause=game.screen_node;var mute=buttons(pause,"静音切换")[0];var back=buttons(pause,"回到封面")[0]
	check("暂停末行两按钮均匀占满且返回标红",absf(mute.size.x-back.size.x)<1 and bool(back.get_meta("primary",false)) and mute.size.x>200)
	await capture("pause-balanced-actions")
	game.close_pause();game.show_menu();game.open_settings();await settle();game.screen_node._select_page(1);await settle()
	var setting=game.screen_node.ROWS[1][0]
	check("数字选项关闭小中大且默认中",setting.key=="combat_numbers" and setting.options.map(func(o):return o[1])==["关闭","小","中","大"] and game.DEFAULT_SETTINGS.combat_numbers=="medium")
	await capture("damage-number-settings")
	game.show_menu();game.free();await settle()
	var path:="res://qa/todo-20261115-ui-%dx%d.json"%[dimensions.x,dimensions.y]
	var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify({"total":checks.size(),"failures":failures,"checks":checks},"  "));file.close()
	print("TODO UI ",checks.size()," FAILURES ",failures);quit(0 if failures==0 else 1)
