extends SceneTree
var checks: Array=[]
var failures:=0
func check(name: String,ok: bool) -> void:
 checks.append({"name":name,"ok":ok})
 if not ok:failures+=1;printerr("FAIL ",name)
func sim_for(id:=1) -> Sim:
 var s:=Sim.new();s.setup(Content.get_level(id),Content.PLANT_ORDER.duplicate(),"easy",540)
 return s
func target(s: Sim,row: int,x: float,type:="ghost"):
 var z=s.spawn_zombie(type,row,{"x":x});z.hp=10000;z.max_hp=10000
 return z
func packet() -> Sim.Shot:
 var shot:=Sim.Shot.new();shot.kind="pea";shot.src="needle";shot.look="frost-sign";shot.damage=60;shot.base_damage=20;shot.lantern_buff=.5;shot.torch_buff=1.5
 shot.speed=600;shot.burn=12;shot.slow=.3;shot.vuln=.2;shot.pierce_left=2;shot.pierce_armor=true;shot.torch_splash_ratio=.2;shot.torch_splash_radius=36
 return shot
func _init():call_deferred("run")
func run():
 for map in ["street","market","water","island","cavern"]:
  var tips:=Content.loadout_tips(map)
  check(map+"推荐覆盖全部新旧草木",tips.size()==Content.PLANT_ORDER.size() and Content.PLANT_ORDER.all(func(p):return tips.has(p)))
 for type in ["reed-chime","soul-casket"]:
  check(type+"完整三路九阶",Upgrades.paths_for(type).size()==3 and Upgrades.paths_for(type).all(func(path):return path.tiers.size()==3))
  check(type+"图鉴有来历和数值",Almanac.PLANTS.has(type) and Almanac.plant_rows(type).size()>=5 and Almanac.plant_ability(type).length()>45)
 var s:=sim_for();var p=s.place_free("reed-chime",2,2);p.timer=10
 var z=target(s,2,p.pos.x+180);var behind=target(s,2,p.pos.x-80);var far=target(s,2,p.pos.x+400)
 s._update_reed_chime(p,0)
 check("竹声基础42且不打身后超距",z.hp==9958 and behind.hp==10000 and far.hp==10000)
 p.upgrades={1:1,2:3,3:0};p.timer=10
 var up=target(s,1,p.pos.x);var down=target(s,3,p.pos.x)
 s._update_reed_chime(p,0)
 check("竹声上下两束",up.hp==9958 and down.hp==9958 and is_equal_approx(up.slow_amount,.45))
 p.upgrades={1:3,2:0,3:0};p.timer=10;s.particles=[];s._update_reed_chime(p,0)
 check("半圆七向只向有客方向出手",s.particles.filter(func(fx):return fx.kind=="reed_beam").size()==3)
 s=sim_for();p=s.place_free("reed-chime",2,2);p.upgrades={1:0,2:0,3:3};p.timer=10
 for i in 5:target(s,2,p.pos.x+60+i*40)
 s._update_reed_chime(p,0)
 check("前束五命中获得速击",p.reed_quick and s.zombies.all(func(g):return g.hp==9930))
 p.timer=0;s._update_reed_chime(p,.69);check("强化后下次未过0.7秒不打",s.zombies[0].hp==9930)
 s._update_reed_chime(p,.02);check("五命中下次0.7秒后出手",s.zombies[0].hp==9860)
 s=sim_for();p=s.place_free("soul-casket",2,2);target(s,2,p.pos.x+240)
 for i in 4:s._relay_capture(p,packet())
 check("未满五发只收不放",p.collector_store.size()==4 and s.shots.is_empty())
 s._relay_capture(p,packet())
 check("五发按0.09秒节奏放出",s.shots.size()==5 and is_equal_approx(s.shots[4].delay,.36) and is_equal_approx(p.collector_ready_at,3.5))
 var shot: Sim.Shot=s.shots[0]
 check("收弹保留特殊与增幅",shot.kind=="homing" and shot.relay_original=="pea" and shot.src=="needle" and shot.look=="frost-sign" and is_equal_approx(shot.damage,72) and shot.pierce_left==2 and shot.pierce_armor and shot.burn==12 and shot.vuln==.2 and shot.torch_splash_ratio==.2)
 check("冷却期不挡弹",not s._collector_open(p))
 s.time=3.5;check("三点五秒恢复收弹",s._collector_open(p))
 var collision:=packet();collision.pos=p.pos+Vector2(-25,-25);collision.row=p.row
 check("沿路射弹确实可撞灵枢",s._collect_incoming(collision,.1) and collision.dead and p.collector_store.size()==1)
 var loop:=packet();loop.pos=p.pos+Vector2(-25,-25);loop.relay_visits=[p.uid]
 check("不重复收同株放出的子弹",not s._collect_incoming(loop,.1))
 p.upgrades={1:0,2:0,3:0};var lob:=packet();lob.kind="lob";lob.pos=p.pos+Vector2(0,-25)
 check("白板不收抛物弹",not s._collect_incoming(lob,.03))
 p.upgrades={1:0,2:0,3:2};check("承天可收抛物弹",s._collect_incoming(lob,.03))
 var saved:=Sim.new();saved.restore(JSON.parse_string(JSON.stringify(s.serialize())))
 var restored=saved.main_plant_at(2,2)
 check("储弹与收集历史读档不丢失",restored.collector_store.size()==p.collector_store.size() and restored.collector_total==p.collector_total and restored.max_hp==p.max_hp)
 for tier in [1,2,3]:
  s=sim_for();p=s.place_free("soul-casket",2,2);p.upgrades={1:tier,2:0,3:0}
  var capacity: int=[5,7,10,10][tier]
  for i in capacity:s._relay_capture(p,packet())
  check("开窍档%d容量冷却"%tier,s.shots.size()==capacity and is_equal_approx(p.collector_ready_at,[3.5,3.0,2.5,0.0][tier]))
 s=sim_for();p=s.place_free("soul-casket",2,2);p.upgrades={1:3,2:2,3:0}
 for i in 10:s._relay_capture(p,packet())
 check("借威二阶独立增伤50%",is_equal_approx(s.shots[0].damage,90.0))
 s=sim_for();p=s.place_free("soul-casket",2,2);p.upgrades={1:0,2:0,3:3}
 for i in 161:s._relay_capture(p,packet())
 check("累计收弹耐久上限2000",p.max_hp==2000)
 p.hp=1900;s._relay_capture(p,packet());check("满上限每收一次治疗50",p.hp==1950)
 var emitter=s.place_free("reed-chime",1,2)
 s.time=4
 var previous: int=p.collector_total;s._collect_area_beam(emitter,Vector2.RIGHT,Geo.CELL_W*3,36,{"slow":.4})
 check("范围攻击记录一发且不损血",p.collector_total==previous+1 and p.hp==2000)
 s._collect_area_beam(emitter,Vector2.RIGHT,Geo.CELL_W*3,36,{"slow":.4});check("同次范围不重复记弹",p.collector_total==previous+1)
 var cargo: Dictionary=p.collector_store.back();check("范围转弹拥有独立模型和伤害",cargo.look=="range-echo" and cargo.damage==36 and cargo.slow==.4)
 s=sim_for();var one=target(s,2,850);var two=target(s,2,700)
 var inherited:=packet();inherited.src="sky-kite";inherited.relay_bonus=.2;inherited.relay_visits=["p-saved"];inherited.payload={"bounces":1,"bounce_full_first":true}
 s._kite_bounce(inherited,one)
 check("灵枢额外增幅与防循环标记沿弹射保留",not s.shots.is_empty() and s.shots[0].relay_bonus==.2 and s.shots[0].relay_visits==["p-saved"])
 # Flying tool: untargeted ground attacks pass underneath; homing and lob can hit the tool.
 s=sim_for(6);z=s.spawn_zombie("sky-wick",0,{"x":1000});var armor: float=z.armor
 check("飞行免普通射弹",s.damage_zombie(z,100,false,false,"shooter","",false,"pea")==0 and z.armor==armor)
 check("飞行免范围伤害",s.damage_zombie(z,100,false,false,"censer")==0 and z.armor==armor)
 check("追魂可破飞行道具",s.damage_zombie(z,100,false,false,"cat","",false,"homing")>0 and z.armor<armor)
 var x: float=z.pos.x;s._step_sky_wick(z,1)
 check("飞行与完整护具加速相加",is_equal_approx(x-z.pos.x,20*(1+.5+float(z.def.get("armor_speed",1.0))-1)))
 z.pos=s.cell_pos(2,0);s._step_sky_wick(z,.01)
 check("门神前四格自动陆地降落",z.flight_landing_at>=0 and z.armor==0 and not z.flight_water)
 s=sim_for(11);z=s.spawn_zombie("sky-wick",1,{"x":s.cell_pos(1,1).x});s._step_sky_wick(z,.01)
 check("水路独立落水状态",z.flight_landing_at>=0 and z.flight_water)
 s=sim_for(6);z=s.spawn_zombie("sky-wick",0,{"x":s.cell_pos(6,0).x});s.tiles[0][6]={"kind":"obstacle","obj":1,"water":""}
 s.damage_zombie(z,z.armor,false,false,"cat","",false,"homing")
 check("障碍格上破翅坠亡",not z.alive())
 s=sim_for();z=s.spawn_zombie("shield-envoy",2,{"x":800});var low=s.spawn_zombie("ghost",2,{"x":760});var mid=s.spawn_zombie("paper",2,{"x":740});var out=s.spawn_zombie("ghost",2,{"x":400})
 s.time=4.99;s._tick_guest_special(z);check("授牌首次尚未到五秒",low.armor==0)
 s.time=5;s._tick_guest_special(z);check("授牌给附近低阶同款盾",low.armor>0 and low.armor_type=="shield" and mid.armor_type=="paper" and out.armor==0)
 check("授牌十一秒再放",z.guest_special_at==16)
 low.armor=0;z.silence_until=20;s.time=16;s._tick_guest_special(z);check("沉默阻止授牌",low.armor==0)
 s=sim_for(11);z=s.spawn_zombie("oar-barge",0,{"x":1000})
 check("高阶舟仅水路且其他高阶不下水",z!=null and z.row in [1,3] and s.choose_spawn_row("mountain") not in [1,3])
 var pos=s.cell_pos(4,1);z.pos=pos+Vector2(38,0);p=s.place_free("lily",4,1);var wall=s.place_free("wall",4,1);var hp: float=wall.hp
 s._step_barge(z,.1);s._step_barge(z,.1)
 check("同步划桨每轮撞击一次300",wall.hp==hp-300)
 s.damage_zombie(z,z.armor,false,false,"shooter","",false,"pea")
 check("沉舟恰好五名小鬼",not z.alive() and s.pending_spawns.size()==5 and s.pending_spawns.all(func(e):return e.type=="ghost"))
 s.flush_pending_spawns();s.update_zombies(.01)
 check("沉舟后使用游泳而非倒置走路",s.zombies.filter(func(g):return g.type=="ghost").all(func(g):return g.water_entered))
 var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/actor_motion.json"))
 for actor in ["reed-chime","reed-chime-e1","reed-chime-e2","reed-chime-e3","soul-casket","soul-casket-e1","soul-casket-e2","soul-casket-e3","sky-wick","shield-envoy","oar-barge","v054-relay-fx"]:
  check(actor+"注册32帧",manifest.has(actor) and manifest[actor].clips.values().all(func(c):return c.size()==32))
 var file=FileAccess.open("res://qa/v054-new-content-tests.json",FileAccess.WRITE);file.store_string(JSON.stringify({"total":checks.size(),"failures":failures,"checks":checks},"  "));file.close()
 print("NEW CONTENT TOTAL ",checks.size()," FAILURES ",failures);quit(0 if failures==0 else 1)
