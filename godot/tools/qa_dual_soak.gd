extends SceneTree
var checks: Array=[]
var failures:=0
func check(name: String,ok: bool):
 checks.append({"name":name,"ok":ok})
 if not ok:failures+=1;printerr("FAIL ",name)
func _init():call_deferred("run")
func run():
 for id in [5,10,15,21,26,16]:
  var level: Dictionary=Content.get_level(id).duplicate(true);level.nightmare_factors={"twins":1,"boss_power":2,"rush":1}
  var s:=Sim.new();s.setup(level,["lantern","wall","shooter","lily","reed-chime","soul-casket"],"nightmare",540)
  s.time=500
  for row in s.rows:
   for col in range(0,7):
    if String(s.tile_at(col,row).kind) in ["object","blocked","obstacle","edge","pit"]:continue
    if String(s.tile_at(col,row).kind)=="water":s.place_free("lily",col,row)
    var p=s.place_free("lantern" if col<2 else "wall",col,row)
    if p!=null:p.hp=50000;p.max_hp=50000
  var boss_id:=String(level.get("boss_id","")) if id!=16 else "paper"
  s.begin_boss(boss_id)
  var members:=s.active_bosses();var timer:=0.0;var wounded:=false
  while timer<90:
   # Isolate two fully active encounters while preventing fixture losses.
   for p in s.plants:p.hp=50000;p.max_hp=50000
   if timer>5 and not wounded:
    wounded=true
    for b in members:b.damage_token="";b.damage(b.body_targets[0],b.max_hp*.7)
   s.tick(1.0/30.0);s.sounds.clear();s.sound_detail.clear();timer+=1.0/30.0
   if fposmod(timer,3.0)<.034:
    for guest in s.zombies:
     if guest.boss_role=="":guest.dead=true
   if timer>35 and timer<35.04:
    var restored:=Sim.new();restored.restore(JSON.parse_string(JSON.stringify(s.serialize())))
    s=restored;members=s.active_bosses()
  check("双恶首%d各自完成实战技能与读档"%id,members.size()==2 and members.all(func(b):return b.small_casts>0 and b.major_count>0))
  check("双恶首%d动作移位不重合"%id,members[0].body_row+1<members[1].body_row or members[1].body_row+1<members[0].body_row)
  var before: int=s.wave_index;s.boss.damage_token="";s.boss.damage(null,s.boss.max_hp*3)
  s.update_waves()
  check("双恶首%d全倒后正确接续"%id,s.boss==null if id==16 else s.is_cleared())
  s.on_win=Callable();s.on_lose=Callable()
 var file=FileAccess.open("res://qa/v054-dual-soak.json",FileAccess.WRITE);file.store_string(JSON.stringify({"total":checks.size(),"failures":failures,"checks":checks},"  "));file.close()
 print("DUAL SOAK ",checks.size()," FAILURES ",failures);quit(0 if failures==0 else 1)
