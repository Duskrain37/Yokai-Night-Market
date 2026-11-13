extends SceneTree
class TestGame extends "res://scripts/game.gd":
	func _data_path(path:String)->String:
		var dir:="res://qa/v061-ui-runtime";DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir));return dir.path_join(path.get_file())
var game
var checks:Array=[]
var failures:=0
func check(label:String,ok:bool):
	checks.append({"name":label,"ok":ok})
	if not ok:failures+=1;printerr("FAIL ",label)
func settle(n:int=5):
	for i in n:await process_frame
func click(at:Vector2,button:int=MOUSE_BUTTON_LEFT):
	var event:=InputEventMouseButton.new();event.position=at;event.global_position=at;event.button_index=button;event.pressed=true;root.push_input(event,true)
	await process_frame
	event=InputEventMouseButton.new();event.position=at;event.global_position=at;event.button_index=button;event.pressed=false;root.push_input(event,true)
	await settle()
func _initialize():run.call_deferred()
func run():
	root.gui_embed_subwindows=true
	game=TestGame.new();root.add_child(game);await settle();game.set_process(false)
	game.start_battle(1,["shooter","judge","sky-mortar"]);game.paused=false;await settle()
	var s:Sim=game.sim;s.zombies.clear();s.plants.clear();s.sun=100000
	var p=s.place_free("shooter",2,2);p.upgrades={1:0,2:0,3:3};s.spawn_zombie("ghost",2,{"x":1200})
	var geometry=preload("res://scripts/plant_regions.gd")
	var point:Vector2=geometry.skill_rect(p,s.rows).get_center()
	check("技能图标位于模型中下部",point.y>geometry.body_rect(p,s.rows).position.y+geometry.height(p,s.rows)*.5)
	game.settings.active_skill_mode="both"
	await click(point)
	check("左键图标打开进化面板且不直接施放",game.hud._fan!=null and p.skill_ready_at==0)
	var fan=game.hud._fan
	await click(point,MOUSE_BUTTON_RIGHT)
	check("右键关闭面板时消费点击不施放",game.hud._fan==null and p.skill_ready_at==0)
	await click(point);fan=game.hud._fan
	check("拥有技能的第三阶适配图标",fan.entries[2].has_skill and fan.skill_rect(2).size==Vector2(40,40))
	await click(fan.skill_rect(2).get_center())
	check("再次点击三阶图标实际施放",p.skill_ready_at==45 and p.skill_shots_left==129)
	game.hud.close_fan();await settle();p.skill_ready_at=0;p.skill_shots_left=0
	await click(point,MOUSE_BUTTON_RIGHT)
	check("右键模型图标快速施放",p.skill_ready_at==45)
	p.skill_ready_at=0;p.skill_shots_left=0;game.settings.active_skill_mode="panel"
	await click(point,MOUSE_BUTTON_RIGHT)
	check("只开面板时右键不施放",p.skill_ready_at==0)
	game.settings.active_skill_mode="right";await click(point)
	check("只开右键仍可查看进化",game.hud._fan!=null)
	fan=game.hud._fan;await click(fan.skill_rect(2).get_center())
	check("只开右键时面板不施放",p.skill_ready_at==0)
	await click(Vector2(1540,700));check("面板外点击关闭",game.hud._fan==null)
	await click(point,MOUSE_BUTTON_RIGHT);check("右键唯一启用方式能施放",p.skill_ready_at==45)
	game.show_menu();game.open_settings();await settle()
	check("设置提供一种或两种释放模式",game.screen_node.ROWS[0][0].key=="active_skill_mode" and game.screen_node.ROWS[0][0].options.size()==3)
	game.open_almanac("plant",Content.PLANT_ORDER.find("judge"));await settle()
	var info=game.screen_node.find_child("AttributeInfo",true,false)
	check("图鉴角落属性计算入口",info!=null)
	info.pressed.emit();await settle()
	var dialog=game.screen_node.find_child("AttributeCalculation",true,false)
	check("属性计算包含公式与两个例子",dialog!=null and dialog.dialog_text.contains("= 18") and dialog.dialog_text.contains("= 90") and dialog.dialog_text.contains("同来源"))
	dialog.hide();dialog.queue_free()
	game.show_menu();game.free();await settle()
	var f=FileAccess.open("res://qa/v061-ui-tests.json",FileAccess.WRITE);f.store_string(JSON.stringify({"total":checks.size(),"failures":failures,"checks":checks},"  "));f.close()
	print("V061 UI TOTAL ",checks.size()," FAILURES ",failures);quit(0 if failures==0 else 1)
