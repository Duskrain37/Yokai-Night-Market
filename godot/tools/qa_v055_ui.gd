extends SceneTree
var game
var checks: Array=[]
var failures:=0
func check(label: String,ok: bool):
	checks.append({"name":label,"ok":ok})
	if not ok:failures+=1;printerr("FAIL ",label)
func _initialize():run.call_deferred()
func settle():
	for i in 8:await process_frame
func capture(label: String):
	if game.hud!=null:game.hud.refresh()
	await settle();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/TempD/PersonalData/神秘创作/nightmarket/godot/qa/v055-"+label+".png")
	print("CAPTURE ",label)
func run():
	root.gui_embed_subwindows=true
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await settle()
	game.settings.difficulty="nightmare";game.settings.nightmare_factors={};game.show_menu();game.open_settings();await settle()
	game.screen_node._nightmare_info();await settle()
	var text: Label=game.screen_node.find_child("NightmareInfoText",true,false)
	check("噩梦说明使用有限宽度并换行",text!=null and text.size.x<900 and text.autowrap_mode!=TextServer.AUTOWRAP_OFF)
	check("噩梦说明底部能够滚动",text!=null and text.get_parent() is ScrollContainer)
	await capture("nightmare-info")
	game.close_overlay();game.show_prep(26);game.screen_node.skip_cinema();game.screen_node._auto_pick();await settle()
	var prep=game.screen_node
	check("推荐填满十二株",prep._picked.size()==12)
	check("十二个备战槽均处于窗口内",prep._slot_nodes.size()==12 and prep._slot_nodes.all(func(c):return c.get_global_rect().end.x<=1600 and c.get_global_rect().end.y<900))
	for i in prep._slot_nodes.size():
		for j in range(i+1,prep._slot_nodes.size()):check("备战槽%d与%d不相交"%[i,j],not prep._slot_nodes[i].get_global_rect().intersects(prep._slot_nodes[j].get_global_rect()))
	await capture("prep-twelve")
	game.settings.nightmare_factors={"light_pack":2};prep._refresh();await settle()
	check("减少携带上限保留所选并提示取下",prep._capacity()==8 and prep._picked.size()==12 and "8" in prep._warning.text)
	prep._start();check("超出因子上限不能开战",game.screen=="prep")
	prep._auto_pick();check("限带因子推荐只装八张",prep._picked.size()==8)
	await capture("prep-eight")
	game.settings.nightmare_factors={};game.start_battle(1,Content.PLANT_ORDER.slice(0,12));game.paused=true;await settle()
	check("局内十二张独立卡槽",game.hud._card_nodes.size()==12)
	for i in game.hud._card_nodes.size():
		var rect: Rect2=game.hud._card_nodes[i].get_global_rect()
		check("战斗槽%d避开左右工具栏"%i,rect.position.x>285 and rect.end.x<1290 and rect.end.y<150)
	await capture("battle-twelve")
	game.start_battle(1,["year-banyan","sky-mortar","shooter","wall","reed-chime","soul-casket","lantern","bell","needle","cat","lobber","torch"]);game.paused=true;var s=game.sim;s.banner={};s.time=120
	for i in 4:
		var p=s.place_free("year-banyan",i+1,1)
		if i>0:p.upgrades[i]=3
		p.growth_steps=i;p.growth_at=0;s.apply_hp_scale(p)
		var q=s.place_free("sky-mortar",i+1,3)
		if i>0:q.upgrades[i]=3
	var cannon=s.main_plant_at(1,3);s.spawn_zombie("bucket",3,{"x":1100})
	s._mortar_launch(cannon,Vector2(1100,s.row_y(3)));s._update_mortar_shot(s.shots[0],1.2)
	s.refresh_plant_buffs();await capture("new-forms")
	s._mortar_impact(s.shots[0]);s.update_particles(.2);await capture("mortar-blast")
	for t in ["year-banyan","sky-mortar"]:
		game.open_almanac("plant",Content.PLANT_ORDER.find(t));await capture("almanac-"+t);game.close_overlay()
	game.start_battle(1,["firework","lantern"]);game.paused=true;s=game.sim;s.banner={}
	for i in 4:
		var plant=s.place_free("firework",i+2,2)
		if i>0:plant.upgrades[i]=3
	await capture("firework-forms")
	check("烟花童三路满阶均有独立动画",[1,2,3].all(func(i):return game.units._actor_frames.motion.has("firework-e%d"%i)))
	game.show_menu();game.open_news();await capture("news")
	var f=FileAccess.open("res://qa/v055-ui-tests.json",FileAccess.WRITE);f.store_string(JSON.stringify({"total":checks.size(),"failures":failures,"checks":checks},"  "));f.close()
	game.show_menu();game.free();await process_frame
	print("V055 VISUAL TOTAL ",checks.size()," FAILURES ",failures);quit(0 if failures==0 else 1)
