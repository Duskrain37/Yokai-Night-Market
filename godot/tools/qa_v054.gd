extends SceneTree
var total=0
var failures=0
var checks=[]
func check(name: String,ok: bool) -> void:
	total+=1;checks.append({"name":name,"ok":ok})
	if not ok:failures+=1;printerr("FAIL ",name)
func scene_text(node: Node) -> String:
	var result=String(node.text)+"\n" if node is Label or node is Button else ""
	for child in node.get_children():result+=scene_text(child)
	return result
func settle():
	for i in 3:await process_frame
func buttons(node: Node,caption: String) -> Array:
	var found=[]
	if node is Button and node.text==caption:found.append(node)
	for child in node.get_children():found.append_array(buttons(child,caption))
	return found
func click(at: Vector2):
	var motion=InputEventMouseMotion.new();motion.position=at;motion.global_position=at;root.push_input(motion,true);await process_frame
	for pressed in [true,false]:
		var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=at;event.global_position=at;event.pressed=pressed;root.push_input(event,true);await process_frame
	await settle()
func _initialize():run.call_deferred()
func run():
	for id in [1,6]:
		for row in [0,Content.get_level(id).rows-1,2]:
			for tier in [0,1,2]:
				var s=Sim.new();s.setup(Content.get_level(id),["shooter"],"easy",54)
				var p=s.place_free("shooter",3,row);p.upgrades={1:tier,2:3,3:0}
				var volley=[1,2,4][tier];s.start_volley(p)
				check("%d行棋盘·行%d·连发%d的首拍没有重叠补弹" % [s.rows,row,tier],s.shots.size()==(2 if row in [0,s.rows-1] else 3))
				while int(p.burst.get("left",0))>0:s.fire_volley_shot(p)
				var main=s.shots.filter(func(x):return x.row==row).size()
				var other=s.shots.size()-main
				check("%d行棋盘·行%d·连发%d总发数正确" % [s.rows,row,tier],main==volley and other==maxi(1 if row in [0,s.rows-1] else 2,volley-1))
	var old=Sim.new();old.setup(Content.get_level(1),["shooter"],"easy",54)
	var saved_gun=old.place_free("shooter",3,0);saved_gun.upgrades={1:2,2:3,3:0};old.start_volley(saved_gun)
	saved_gun.burst.erase("side_schedule")
	var legacy=Sim.new();legacy.restore(JSON.parse_string(JSON.stringify(old.serialize())))
	var before=legacy.shots.filter(func(x):return x.row==1).size()
	var pending=legacy.main_plant_at(3,0)
	while int(pending.burst.get("left",0))>0:legacy.fire_volley_shot(pending)
	check("旧版连发中途存档不会重复补射",legacy.shots.filter(func(x):return x.row==1).size()==before)
	var s=Sim.new();s.setup(Content.get_level(1),["shooter"],"easy",54)
	var gun=s.place_free("shooter",3,0);gun.upgrades={1:2,2:3,3:0}
	var front=s.spawn_zombie("ghost",0,{"x":1050});front.hp=10000;front.speed=0
	var side=s.spawn_zombie("ghost",1,{"x":1050});side.hp=10000;side.speed=0
	s.start_volley(gun)
	for i in 96:s.time+=1.0/60;s.update_plants(1.0/60);s.update_shots(1.0/60)
	check("边行四主弹与三补弹都真实命中",front.hp==9920 and side.hp==9940)
	s=Sim.new();s.setup(Content.get_level(1),["lantern","shooter","cat"],"easy",54);s.training=true
	s.place_free("lantern",0,2);s.place_free("shooter",3,2)
	var guest=s.spawn_zombie("ghost",2,{"x":Geo.BOARD_X+80})
	check("绕到单向火力后识别正确",s.guest_behind_defenders(guest))
	s.time=61;s.update_rear_notices();check("六十秒僵持有提示",String(s.banner.get("text","")).contains("摊后"))
	var cat=s.place_free("cat",5,0)
	check("追魂跨行支援存在时不误报",not s.guest_behind_defenders(guest))
	cat.dead=true;s.time=100;s.damage_zombie(guest,1);check("实际掉血更新僵持时钟",s.last_guest_damage_at==100)
	var restored=Sim.new();restored.restore(JSON.parse_string(JSON.stringify(s.serialize())))
	check("读档保留僵持掉血时刻",restored.last_guest_damage_at==100)
	var a=Sim.new();a.setup(Content.get_level(17),["lantern","shooter","wall"],"normal",54017)
	var b=Sim.new();b.setup(Content.get_level(17),["lantern","shooter","wall"],"normal",54017)
	check("孤岛固定种子地形一致",a.tiles==b.tiles)
	for i in 15:a.queue_wave(a.level.waves[0],0);b.queue_wave(b.level.waves[0],0)
	check("固定种子拨次序列可复现",JSON.stringify(a.spawn_queue)==JSON.stringify(b.spawn_queue))
	var baseline:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/qa_campaign_baseline.json"))
	var hash=FileAccess.get_sha256("res://tools/qa_bot.gd")
	var first=baseline.runs["easy:1"]
	var good={"won":true,"t":220,"spawn_trace":first.spawn_trace}
	var sweep=load("res://tools/qa_sweep.gd")
	check("基线绑定实际策略文件",baseline.strategy_sha256==hash and sweep.compare_run(baseline,"easy:1",good,hash).is_empty())
	good.won=false;check("基线胜局退步会失败",not sweep.compare_run(baseline,"easy:1",good,hash).is_empty())
	good.won=true;good.t=1801;check("节奏退步独立于胜负检查",not sweep.compare_run(baseline,"easy:1",good,hash).is_empty())
	good.t=220;check("更换策略不能跨基线比较",not sweep.compare_run(baseline,"easy:1",good,"other-strategy").is_empty())
	var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await settle()
	game.progress={"cleared":[],"stars":{}};game.records={"by_diff":{"easy":{"wins":2,"best_time":125.2,"best_kills":123,"best_groups":4}}};game.settings.difficulty="easy"
	game.show_menu();await settle();game.screen_node._show_records();await settle();var text=scene_text(game.screen_node)
	check("封面显示存档最快时间与击退",text.contains("最快天亮 2:05") and text.contains("123 位"))
	game.records={};game.show_menu();await settle();game.screen_node._show_records();await settle();check("旧档缺成绩正常显示暂无",scene_text(game.screen_node).contains("最快天亮 暂无"))
	game.open_almanac("boss",0);await settle();text=scene_text(game.screen_node)
	check("未击退仍可看全部技能数值对策",text.contains("双穴裂街") and text.contains("恶首底细") and text.contains("留意出招"))
	check("未击退只遮独立来历",text.contains("击退这位恶首后") and not text.contains("旧街铺石"))
	game.progress.cleared=[5];game.screen_node._render_page();await settle();check("旧通关档兼容来历解锁",scene_text(game.screen_node).contains("旧街铺石"))
	game.start_battle(1,["lantern","shooter"]);await settle()
	var book={};game.sim.time=200;game.sim.kills=30;game._record_tally(book,true)
	game.sim.time=400;game.sim.kills=80;game._record_tally(book,true)
	check("最快天亮取较小值、击退取较大值",book.best_time==200 and book.best_kills==80)
	game.sim.time=100;game._record_tally(book,false)
	check("失守用时不会冒充最快天亮",book.best_time==200)
	game.show_menu();await settle()
	check("已移除重签入口",buttons(game.screen_node,"一夜重签").is_empty())
	check("已移除重签方法与专用关卡",not game.has_method("start_challenge") and not FileAccess.file_exists("res://data/challenges.gd"))
	var sound_sim=Sim.new();sound_sim.setup(Content.get_level(1),Content.PLANT_ORDER.duplicate(),"easy",54)
	var ruin=sound_sim.place_free("ruin-cap",5,2);sound_sim.sounds.clear();sound_sim._update_ruin_cap(ruin,2)
	check("劫火芝触发专属爆燃事件",sound_sim.sounds.has("ruin_bloom"))
	var kite=sound_sim.place_free("sky-kite",2,1);sound_sim.spawn_zombie("ghost",1,{"x":1000});sound_sim.sounds.clear();sound_sim._update_sky_kite(kite,2)
	check("逐云鸢触发竹纸出手事件",sound_sim.sounds.has("kite_shot"))
	var till=sound_sim.place_free("wish-till",1,0);sound_sim.sounds.clear();sound_sim._on_guest_defeated(0)
	check("清账匣收香使用算盘事件",sound_sim.sounds.has("till_income"))
	var pod=sound_sim.place_free("cash-pod",3,0);sound_sim.sounds.clear();sound_sim.damage_plant(pod,100)
	check("铜钱荚受击收香使用铜钱事件",sound_sim.sounds.has("pod_income"))
	var ember=sound_sim.place_free("ember-cicada",3,1);sound_sim.sounds.clear();sound_sim._update_ember(ember,2)
	check("烬翼蝉出手使用烬壳事件",sound_sim.sounds.has("cicada_shot"))
	var herb=sound_sim.place_free("herb-gourd",0,1);herb.hp=100;sound_sim.sounds.clear();sound_sim._update_healer(herb,2)
	check("回春葫治疗使用药叶事件",sound_sim.sounds.has("herb_heal"))
	for name in ["ruin_bloom","kite_shot","till_income","till_shot","till_call","pod_income","cicada_shot","cicada_reload","herb_heal"]:
		check("专属音效走采样 "+name,game._sfx_for(name).resource_path=="res://assets/sfx/v040/%s.wav" % name)
	for day in [4,5]:
		game.start_battle(Content.level_id_for(day),["lantern","shooter","wall"]);await settle()
		check("地图%d读独立门神" % day,game.board._mower_art().resource_path=="res://assets/sprites/mower-day%d.png" % day)
	var f=FileAccess.open("res://qa/v054-tests.json",FileAccess.WRITE);f.store_string(JSON.stringify({"total":total,"failures":failures,"checks":checks},"  "));f.close()
	game.show_menu();await settle();game.queue_free();await settle()
	print("V054 TOTAL ",total," FAILURES ",failures);quit(0 if failures==0 else 1)
