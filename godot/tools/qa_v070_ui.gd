extends SceneTree
class TestGame extends "res://scripts/game.gd":
	func _data_path(path:String)->String:
		var folder:="res://qa/v070-ui-runtime";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder));return folder.path_join(path.get_file())
var game
var failures:=0
var checks:Array=[]
var dimensions:=Vector2i(1600,900)
var folder:="res://qa/v070-gallery"
func check(label:String,ok:bool):
	checks.append({"name":label,"ok":ok})
	if not ok:failures+=1;printerr("FAIL ",label)
func settle(n:int=8):
	for i in n:await process_frame
func click(at:Vector2,button:int=MOUSE_BUTTON_LEFT):
	var move:=InputEventMouseMotion.new();move.position=at;move.global_position=at;root.push_input(move,true);await process_frame
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.position=at;event.global_position=at;event.button_index=button;event.pressed=pressed;root.push_input(event,true);await process_frame
	await settle()
func capture(label:String):
	print("CAPTURE ",label)
	if DisplayServer.get_name()=="headless":return
	await settle();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(folder.path_join("%s-%dx%d.png" % [label,dimensions.x,dimensions.y])))
func _initialize():run.call_deferred()
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-size="):
			var parts=arg.trim_prefix("--qa-size=").split("x");dimensions=Vector2i(int(parts[0]),int(parts[1]))
	root.content_scale_size=Vector2i(1600,900);root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND;root.gui_embed_subwindows=true;root.size=dimensions
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	game=TestGame.new();root.add_child(game);await settle();game.set_process(false)
	if "--qa-large" in OS.get_cmdline_user_args():game.settings.ui_text_size="large";game._apply_ui_text_size()
	game.settings.reduced_motion=true;MarketArt.reduced_motion=true;game.settings.active_skill_mode="both"
	game.show_levels();await settle()
	for week in [6,7,8]:
		game.screen_node.select_day(week)
		await capture("week%d-route" % week)
	game.show_training_menu();await capture("eight-training-maps")
	for week in [6,7,8]:
		game._start_battle_now(Content.level_id_for(week),["watch-bloom","vow-toad","root-palanquin","lantern","wall","shooter","cat","ember-cicada"],"normal",false);game.paused=false;await settle()
		var s:Sim=game.sim;s.sun=99999;s.time=0
		for row in 6:
			for col in [2,4,7]:
				var type:String=["watch-bloom","vow-toad","lantern"][[2,4,7].find(col)]
				if s.can_place_at(type,col,row).ok:
					var p=s.place_free(type,col,row);p.upgrades={1:0,2:0,3:0}
					if row>0:p.upgrades[(row-1)%3+1]=3
			var z=s.spawn_zombie("ghost",row,{"x":1150.0-row*22});z.scene_walk_distance=row*9
		game.hud.refresh();await capture("week%d-base" % week)
		if week==6:
			var bloom=s.main_plant_at(2,0);bloom.upgrades={1:0,2:0,3:1}
			game.hud.try_open_menu(bloom,Vector2.ZERO);await settle()
			check("更筹花优先卡入口显示",game.hud._fan._priority.visible)
			var select=game.hud._fan._priority
			await click(select.get_global_rect().get_center())
			check("优先卡下拉真实点击打开",select.get_popup().visible)
			select.get_popup().hide();select.select(2);select.item_selected.emit(2)
			check("优先卡选择保存到本株",bloom.seed_priority=="vow-toad")
			await capture("bloom-priority");game.hud.close_fan()
			var toad=s.main_plant_at(4,0)
			# row 0 has no cloud deck at col 5: use the permanent stone terrace.
			if toad==null:toad=s.place_free("vow-toad",8,0)
			game.hud.try_open_menu(toad,Vector2.ZERO);await settle()
			check("基础金蟾无进化也有模式按钮",game.hud._fan._mode.visible)
			await click(game.hud._fan._mode.get_global_rect().get_center())
			check("模式按钮真实点击立即生效",toad.toad_mode=="fire")
			await capture("toad-mode");game.hud.close_fan()
			var plant=s.main_plant_at(7,0);var cost:int=s.sun
			game.hud._on_card(2);await click(preload("res://scripts/plant_regions.gd").body_rect(plant,s.rows).get_center())
			check("迁根真实选中源草木",game.hud.transplant_source==plant)
			await click(Vector2(800,500),MOUSE_BUTTON_RIGHT)
			check("迁根右键取消不扣费",game.hud.card_selected==-1 and game.hud.transplant_source==null and s.sun==cost)
			for clock in [31.5,71.2,73.0,111.2,150.7]:
				s.time=clock;s.chapter.sync_platforms();await capture("sky-%.1f" % clock)
		elif week==7:
			s.time=80;s.chapter.event_start=74;s.chapter.event_mode="guide";s.chapter.event_pair=0
			var z=s.zombies[0];z.pos.x=Geo.BOARD_X+6.5*Geo.CELL_W;s.chapter.try_route(z);s.chapter.step_route(z)
			await capture("theatre-diagonal")
		else:
			s.time=80;s.chapter.event_start=70;s.chapter.market_pair=1;await capture("market-open")
		var encounter=preload("res://scripts/boss_encounter.gd").new();s.boss=encounter
		encounter.begin(s,["wind-warden","mask-master","market-lamplord"][week-6]);s.time+=4
		encounter._start_small();await capture("week%d-evil-warning" % week)
		encounter._resolve_small();s.time+=.25;await capture("week%d-evil-impact" % week)
		game.open_almanac("boss",Almanac.BOSS_ORDER.find(encounter.id));await capture("week%d-evil-almanac" % week)
	game._start_battle_now(1,["ember-cicada","watch-bloom","vow-toad","root-palanquin","lantern"],"normal",false);game.paused=false
	var sim:Sim=game.sim;sim.sun=99999
	var flare=sim.place_free("ember-cicada",3,2);flare.upgrades={1:0,2:2,3:3}
	var flower=sim.place_free("watch-bloom",2,1);flower.upgrades={1:2,2:0,3:3}
	var toad=sim.place_free("vow-toad",2,3);toad.upgrades={1:0,2:2,3:3}
	for row in sim.rows:sim.spawn_zombie("ghost",row,{"x":1050.0})
	sim.activate_skill(flare);sim.activate_skill(flower);sim.activate_skill(toad);sim.activate_skill(toad)
	for clock in [.2,.55,1.1,1.45]:
		var dt:float=clock-sim.time;sim.time=clock;sim.additions.tick(dt);sim.update_particles(dt);sim.update_plants(dt)
		await capture("new-actives-%.2f" % clock)
	game.progress["chapter_guides"]=[]
	for week in range(1,9):
		game._start_battle_now(Content.level_id_for(week),["lantern","shooter"],"normal",false);game.paused=false
		game._show_chapter_guide();await settle()
		var guide=game.hud.find_child("ChapterGuide",true,false)
		check("第%d周初到提示暂停战斗" % week,guide!=null and game.paused)
		if week in [6,7,8]:await capture("week%d-first-guide" % week)
		var buttons=guide.find_children("*","Button",true,false)
		await click(buttons[0].get_global_rect().get_center())
		check("第%d周确认后恢复并持久记下" % week,not game.paused and week in game.progress.chapter_guides)
		game._show_chapter_guide();check("第%d周重复进入不再弹出" % week,game.hud.find_child("ChapterGuide",true,false)==null)
	game.show_menu();game.free();await settle()
	FileAccess.open("res://qa/v070-ui-%dx%d.json" % [dimensions.x,dimensions.y],FileAccess.WRITE).store_string(JSON.stringify({"total":checks.size(),"failures":failures,"checks":checks},"  "))
	print("V070 UI TOTAL ",checks.size()," FAILURES ",failures);quit(0 if failures==0 else 1)
