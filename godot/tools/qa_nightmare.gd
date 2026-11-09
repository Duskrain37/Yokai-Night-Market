extends SceneTree
const Rules=preload("res://data/nightmare.gd")
var total:=0
var failures:=0
var checks: Array=[]
func check(title: String,ok: bool) -> void:
 total+=1;checks.append({"name":title,"ok":ok})
 if not ok:failures+=1;printerr("FAIL ",title)
func fresh(factors: Dictionary={},id:=5,diff:="nightmare") -> Sim:
 var level: Dictionary=Content.get_level(id).duplicate(true)
 level.nightmare_factors=factors
 var s:=Sim.new();s.setup(level,["lantern","shooter","mine","shell","censer","bomb"],diff,541)
 return s
func texts(node: Node) -> String:
 var result:=String(node.text)+"\n" if node is Label or node is Button else ""
 for child in node.get_children():result+=texts(child)
 return result
func buttons(node: Node,text: String) -> Array:
 var result: Array=[]
 if node is Button and node.text==text:result.append(node)
 for child in node.get_children():result.append_array(buttons(child,text))
 return result
func settle():
 for i in 4:await process_frame
func _initialize():run.call_deferred()
func run():
 for tier in 4:
  var s:=fresh({"swarm":tier});var expected: float=1.35*[1.0,1.1,1.2,1.4][tier]
  check("噩梦数量血量乘区档%d"%tier,is_equal_approx(s.difficulty_mult().hp,expected) and is_equal_approx(s.difficulty_mult().count,expected))
 check("普通难度忽略因子",fresh({"swarm":3},5,"normal").factor_points()==0)
 check("非恶首关过滤专属因子",Rules.sanitize({"twins":1,"boss_power":2,"rush":1},Content.get_level(1))=={"rush":1})
 check("因子分数不是档位之和",Rules.points({"loss":2,"one_path":1,"price":2})==7)
 for tier in [1,2]:
  var s:=fresh({"dim":tier});var cap: int=[0,750,500][tier];var before: int=s.sun
  check("十秒限额首笔%d"%tier,s.gain_incense(cap-20)==cap-20)
  s.time=4;check("十秒限额截断%d"%tier,s.gain_incense(90)==20 and s.sun-before==cap)
  s.time=9.99;check("窗口内无额度%d"%tier,s.gain_incense(90)==0)
  s.time=10;check("滚动过期恢复%d"%tier,s.gain_incense(90)==90 and s.incense_received()==110)
  var restored:=Sim.new();restored.restore(JSON.parse_string(JSON.stringify(s.serialize())))
  check("灯火窗口读档不重置%d"%tier,restored.incense_received()==110 and restored.gain_incense(cap)==cap-110)
 for tier in [1,2]:
  var s:=fresh({"seeds":tier});var cap: int=[0,25,15][tier]
  for i in cap:s.place_free("shooter",i%9,i/9)
  check("场上数量封顶%d"%tier,s.plant_population()==cap and not s.can_place_at("shooter",8,4).ok)
  s.kill_plant(s.plants[0],true);check("移除后恢复名额%d"%tier,s.can_place_at("shooter",8,4).ok)
 var s:=fresh({"loss":2});var failed: Array=[false];s.on_lose=func(_z):failed[0]=true
 for i in 9:
  var p=s.place_free("bomb",1,1);s.explode(p)
 check("灰烬消耗也计损失",s.nightmare_losses==9 and not failed[0])
 var last=s.place_free("shooter",1,1);s.shovel_at(1,1)
 check("铲除触发第十株失败",s.nightmare_losses==10 and failed[0] and s.nightmare_failed)
 s.kill_plant(last,true);check("同株不重复扣损失",s.nightmare_losses==10)
 s=fresh({"unguarded":1});check("无门神因子无可触发门神",s.mowers.all(func(m):return not m.ready and m.absent))
 check("无门神不算惊动",s.battle_summary().star_flags==[true,true,true,true])
 failed=[false];s.on_lose=func(_z):failed[0]=true
 var intruder=s.spawn_zombie("ghost",0,{"x":Geo.BREACH_X-100});s.breach(intruder)
 check("无门神走到底判负",failed[0])
 s=fresh({"no_capstone":1,"one_path":1});s.sun=99999
 var plant=s.place_free("shooter",2,2)
 check("第一路可开",s.try_upgrade(plant,1,plant.pos).ok)
 check("独修阻止第二路",not s.try_upgrade(plant,2,plant.pos).ok)
 s.try_upgrade(plant,1,plant.pos)
 check("禁三级阻止升阶",not s.try_upgrade(plant,1,plant.pos).ok)
 for tier in [1,2]:
  s=fresh({"price":tier});plant=s.place_free("shooter",2,2)
  var original:=int(Upgrades.path_status(plant.type,plant.upgrades,1).cost)
  check("进化涨价档%d"%tier,s.upgrade_status(plant,1).cost==ceili(original*[1.0,1.5,2.0][tier]))
 s=fresh({"curfew":1});s.sun=99999;plant=s.place_free("shooter",2,2);s.time=60;s._flag_banner(2)
 check("宵禁立刻限制种植",not s.try_place_card(0,0,0,Vector2.ZERO) and not s.can_place_at("lantern",0,0).ok)
 check("宵禁限制升阶",not s.try_upgrade(plant,1,plant.pos).ok)
 var saved:=Sim.new();saved.restore(JSON.parse_string(JSON.stringify(s.serialize())))
 check("宵禁存档保留剩余时间",saved.curfew_until-saved.time==5.0)
 s.time=65;check("宵禁五秒后恢复",s.can_place_at("lantern",0,0).ok and s.upgrade_status(plant,1).ok)
 s=fresh({"rush":1});var original: Array=Content.get_level(5).waves
 check("攻势间隔压缩而开局布阵不变",is_equal_approx(s.level.waves[0].t,original[0].t) and is_equal_approx(s.level.waves[1].t-s.level.waves[0].t,(original[1].t-original[0].t)*.75))
 saved=Sim.new();saved.restore(JSON.parse_string(JSON.stringify(s.serialize())))
 check("读档不重复压缩波次",is_equal_approx(saved.level.waves[1].t,s.level.waves[1].t))
 s=fresh({"early":1},15);s.queue_roster(s.level.waves[6],6,1,false)
 check("提前一波允许高阶阵容",s.spawn_queue.any(func(e):return Content.ZOMBIES[e.type].tier=="h"))
 s=fresh({"seeds":2,"loss":2});s.sun=99999;plant=s.place_free("shooter",2,2);s.attach_shell(plant)
 check("龟甲罩独立占种子名额",s.plant_population()==2)
 s.remove_shell(plant);check("拆罩也计草木损失",s.nightmare_losses==1 and s.plant_population()==1)
 s.attach_shell(plant);s.kill_plant(plant,true)
 check("带罩草木退场各计一株",s.nightmare_losses==3 and s.plant_population()==0)
 # Every evil chief, special checkpoint and the bound intermission use real independent encounters.
 for id in [5,10,15,21,26,16]:
  s=fresh({"twins":1,"boss_power":2},id)
  var boss_id:=String(s.level.get("boss_id",""))
  if bool(s.level.get("special",false)):boss_id=String(s.level.boss_checkpoints[0])
  s.begin_boss(boss_id)
  var group=s.boss;var members:=s.active_bosses();var a=members[0];var b=members[1]
  check("关卡%d双恶首两行互不重叠"%id,members.size()==2 and a.body_row+1<b.body_row)
  check("关卡%d代理归属独立"%id,a.body_targets.all(func(z):return z.boss_meta.encounter_slot==0) and b.body_targets.all(func(z):return z.boss_meta.encounter_slot==1))
  var b_hp: float=b.hp;group.damage_token="shot:independent";group.damage(a.body_targets[0],100,"shooter");group.damage(a.body_targets[1],100,"shooter")
  check("关卡%d双行同弹不重复、同伴不扣血"%id,a.max_hp-a.hp==100 and b.hp==b_hp)
  group.damage(b.body_targets[0],100,"shooter");check("关卡%d同弹可独立命中另一恶首"%id,b.max_hp-b.hp==100)
  var roundtrip:=Sim.new();roundtrip.restore(JSON.parse_string(JSON.stringify(s.serialize())))
  check("关卡%d双恶首存档恢复独立状态"%id,roundtrip.active_bosses().size()==2 and is_equal_approx(roundtrip.active_bosses()[0].hp,a.hp) and roundtrip.active_bosses()[1].rate_scale==2.0)
  for iteration in 8:
   a._start_blink();b._start_blink()
   check("关卡%d双影移位%d不叠行"%[id,iteration],a.body_row+1<b.body_row or b.body_row+1<a.body_row)
  group.damage_token="";group.damage(a.body_targets[0],a.max_hp*3)
  check("关卡%d一位倒地另一位仍能受击"%id,group.alive() and not b.body_targets[0].dead and b.alive())
  group.damage(b.body_targets[0],b.max_hp*3);check("关卡%d两位倒地才完成"%id,group.finished())
 s=fresh({"twins":1},26);s.begin_boss("magistrate-bound",12,true,false)
 check("第五周中场限制形态不复制",s.active_bosses().size()==1)
 var progress: Dictionary={"stars":{"5":2}}
 check("旧星级迁移",Rules.flags(progress,5)==[true,true,false,false])
 Rules.record(progress,5,[true,true,false,true],{"loss":2})
 check("红星不依赖门神星",Rules.flags(progress,5)==[true,true,false,true] and progress.nightmare_badges["5"].best==3)
 Rules.record(progress,5,[true,true,true,false],{})
 check("跨局每颗独立保留",Rules.flags(progress,5)==[true,true,true,true])
 Rules.record(progress,5,[true,true,true,true],{"price":1})
 check("徽章保留最高点与不同组合",progress.nightmare_badges["5"].best==3 and progress.nightmare_badges["5"].builds.size()==2)
 var game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await settle()
 game.show_menu();game.open_settings();await settle()
 check("局外包含噩梦选项",buttons(game.screen_node,"噩梦").size()==1)
 game.settings.nightmare_info_seen=false;game.screen_node._set_option("difficulty","nightmare");await settle()
 check("首次选择噩梦自动说明",game.settings.nightmare_info_seen and game.screen_node.get_children().any(func(n):return n is AcceptDialog))
 game.settings.nightmare_factors={"twins":1,"dim":2};game.show_prep(5);await settle();game.screen_node.skip_cinema();await settle()
 check("噩梦备战显示因子入口",texts(game.screen_node).contains("噩梦因子 · 4"))
 var picker=load("res://ui/nightmare_panel.gd").new();picker.game=game;picker.level=Content.get_level(1);game.screen_node.add_child(picker);await settle()
 check("非恶首备战没有专属词条",not texts(picker).contains("恶首逞威") and not texts(picker).contains("呼朋引伴"))
 picker.queue_free();game.start_battle(5,["lantern","shooter"]);await settle()
 check("因子随开战传入",game.sim.factor("twins")==1 and game.sim.factor("dim")==2)
 game.open_settings();await settle()
 check("局内难度行彻底不可见",not texts(game.screen_node).contains("难度") and buttons(game.screen_node,"噩梦").is_empty())
 game.set_setting("difficulty","easy");check("直接调用也不能局内改难度",game.settings.difficulty=="nightmare")
 game.close_overlay();await settle();game.sim.begin_boss("earth");await settle()
 check("双恶首创建两套动画视图",game.boss_view.member_views.size()==1)
 var hud=load("res://ui/boss_hud.gd").new()
 check("双血条矩形不相交",not hud.member_rect(0,2).intersects(hud.member_rect(1,2)))
 hud.free()
 game.paused=false;game.sim.mowers[0].ready=false;game.finish_run(true);await settle()
 check("实战噩梦惊动门神仍得红星",Rules.flags(game.progress,5)[3] and game.result.summary.star_flags==[true,true,false,true])
 game.show_menu();game.set_setting("difficulty","easy");game.set_setting("nightmare_factors",{});await settle();game.queue_free();await settle()
 var file=FileAccess.open("res://qa/v054-nightmare-tests.json",FileAccess.WRITE);file.store_string(JSON.stringify({"total":total,"failures":failures,"checks":checks},"  "));file.close()
 print("NIGHTMARE TOTAL ",total," FAILURES ",failures)
 quit(0 if failures==0 else 1)

