extends SceneTree
const Rules=preload("res://data/nightmare.gd")
const Installer=preload("res://scripts/update_installer.gd")
var checks:Array=[]
var failures:=0
func check(label:String,ok:bool):
	checks.append({"name":label,"ok":ok})
	if not ok:failures+=1;printerr("FAIL ",label)
func fresh(factors:Dictionary={}) -> Sim:
	var s:=Sim.new();var level:Dictionary=Content.get_level(1).duplicate(true);level.nightmare_factors=factors
	s.setup(level,Content.PLANT_ORDER.duplicate(),"nightmare",115);return s
func unique_count(items: Array) -> int:
	var seen:Dictionary={}
	for item in items:seen[item]=true
	return seen.size()
func canonical_state(s:Sim) -> String:
	# Instance IDs differ between identical worlds. Normalize identities, retaining references.
	var source:=JSON.stringify(s.serialize());var ids:Dictionary={};var out:="";var offset:=0
	var pattern:=RegEx.new();pattern.compile("(?<![A-Za-z0-9])[pzs]-?[0-9]+(?![A-Za-z0-9])")
	for match_id in pattern.search_all(source):
		var id:String=match_id.get_string()
		if not ids.has(id):ids[id]=id.left(1)+str(ids.size())
		out+=source.substr(offset,match_id.get_start()-offset)+ids[id];offset=match_id.get_end()
	return out+source.substr(offset)
func _initialize():run.call_deferred()
func run():
	var own:="C:/游戏 测试/夜市.exe"
	check("回执兼容Windows反斜杠",Installer.acknowledgement_path(own,"--update-ack=C:\\游戏 测试\\夜市.exe.update-ack")==own+".update-ack")
	check("回执兼容斜杠与盘符大小写",Installer.acknowledgement_path(own,"--update-ack=c:/游戏 测试/夜市.exe.update-ack")==own+".update-ack")
	check("回执拒绝其他文件路径",Installer.acknowledgement_path(own,"--update-ack=C:/其他/夜市.exe.update-ack").is_empty())
	check("回执拒绝其他参数",Installer.acknowledgement_path(own,"--other="+own).is_empty())
	check("新助手使用规范路径并保留90秒验证",Installer.script(own,own+".update-"+"a".repeat(12)+".part",{"sha256":"a".repeat(64),"build":"f7bd605","version":"0.6.1","size":100},1,"C:/game/result.json").contains("Replace([char]92,[char]47)") and Installer.script(own,"x",{"sha256":"a".repeat(64),"build":"f7bd605","version":"0.6.1","size":100},1,"x").contains("AddSeconds(90)"))
	check("原有15项通用与新增6项地图因子名称均唯一",Rules.FACTORS.size()==21 and unique_count(Rules.FACTORS.map(func(f):return f.name))==21)
	check("因子规定等级与点数",Rules.FACTORS.filter(func(f):return f.id=="no_capstone")[0].points==[3] and Rules.FACTORS.filter(func(f):return f.id=="seeds")[0].points.size()==3 and Rules.FACTORS.filter(func(f):return f.id=="early")[0].points.size()==2)
	for spec in [[4,0],[5,1],[9,1],[10,2],[14,2],[15,3]]:check("总因子数危险层次%d"%spec[0],Rules.danger_band(spec[0])==spec[1])
	for tier in [1,2]:
		var s:=fresh({"dim":tier});var cap:int=[0,1000,750][tier]
		check("连续十秒上限%d"%tier,s.gain_incense(cap+1)==cap and s.gain_incense(1)==0)
		s.time=10;check("十秒窗口滑动恢复%d"%tier,s.gain_incense(50)==50)
		var restored:=Sim.new();restored.restore(JSON.parse_string(JSON.stringify(s.serialize())))
		check("香火窗口读档不重置%d"%tier,restored.incense_received()==50)
	for tier in [1,2,3]:
		var s:=fresh({"seeds":tier});var cap:int=[0,30,25,20][tier]
		for i in cap:s.place_free("wall",i%9,i/9)
		check("场上草木上限%d"%cap,s.plant_population()==cap and s.place_free("wall",8,4)==null)
		s.sun=99999
		check("龟甲罩计入同一场上上限%d"%cap,not s.try_place_card(s.cards.find(s.cards.filter(func(c):return c.id=="shell")[0]),s.plants[0].col,s.plants[0].row,s.plants[0].pos))
	var s:=fresh({"unguarded":1});check("门神等级1开局仍有门神",s.mowers.all(func(m):return m.ready))
	var z=s.spawn_zombie("ghost",2,{"x":Geo.BREACH_X-1});s.breach(z)
	check("第一尊显灵清除撞门恶客后全部退场",not z.alive() and s.mowers.all(func(m):return not m.ready and not m.active and m.absent))
	check("撤去其他门神不抹掉已显灵记录",s.battle_summary().mowers_used==1 and not s.battle_summary().star_flags[2])
	s=fresh({"unguarded":2});check("门神等级2开局全部缺席",s.mowers.all(func(m):return not m.ready and m.absent))
	var data:Dictionary=JSON.parse_string(JSON.stringify(s.serialize()));data.erase("nightmare_rules_revision");data.level_snapshot.nightmare_factors={"unguarded":1}
	var old:=Sim.new();old.restore(data);var again:=Sim.new();again.restore(JSON.parse_string(JSON.stringify(old.serialize())))
	check("旧无门神存档迁移后反复读档仍无门神",old.factor("unguarded")==2 and again.factor("unguarded")==2 and old.mowers.all(func(m):return not m.ready))
	for tier in [1,2]:
		s=fresh({"loss":tier});var lost:=[false];s.on_lose=func(_z):lost[0]=true
		var cap:int=[0,30,20][tier];s._nightmare_loss(cap-1);check("草木损失阈值之前%d"%cap,not lost[0]);s._nightmare_loss();check("草木损失达到阈值%d"%cap,lost[0])
	s=fresh({"no_ash":1});s.setup(s.level,["bomb","cash-pod","ruin-cap","shooter"],"nightmare",115)
	check("灰契封炉禁带灰烬但允许产能铜钱荚",not s.cards.any(func(c):return Content.PLANTS[c.id].role=="灰烬") and s.cards.any(func(c):return c.id=="cash-pod"))
	check("灰契封炉也阻止直接种植绕过",not s.can_place_at("bomb",1,1).ok and s.can_place_at("cash-pod",1,1).ok)
	for type in ["lobber","firework","sky-kite"]:check(type+"基础标签抛弹",Content.PLANTS[type].role=="抛弹")
	for type in ["cat","ember-cicada"]:check(type+"基础标签追魂",Content.PLANTS[type].role=="追魂")
	for tier in [1,2]:
		s=fresh({"early":tier})
		for i in s.level.waves.size():s.level.waves[i]={"groups":[["mountain" if i==9 or i==3 else "paper",1]],"t":float(i),"duration":1.0}
		s.queue_roster(s.level.waves[3],3)
		check("阵容分别提前%d大波"%tier,not s.spawn_queue.is_empty() and s.spawn_queue.all(func(e):return e.type==("paper" if tier==1 else "mountain")))
	s=fresh();var p=s.place_free("shooter",2,2);z=s.spawn_zombie("ghost",2,{"x":1000});z.hp=100;z.max_hp=100
	s.damage_zombie(z,30);check("直接伤害数字记录实际30",s.vital_numbers.entries.size()==1 and s.vital_numbers.entries[0].amount==30)
	s.vital_numbers.clear();s.damage_zombie(z,500);check("伤害数字不把溢出伤害算进来",s.vital_numbers.entries.size()==1 and s.vital_numbers.entries[0].amount==70)
	s.vital_numbers.clear();p.hp=50;var healed:=s.heal_plant(p,10000)
	check("草木治疗数字只计实际回复",healed==p.max_hp-50 and s.vital_numbers.entries[0].healing and s.vital_numbers.entries[0].amount==healed)
	z=s.spawn_zombie("ghost",3,{"x":1000});z.hp=20;var before:float=z.max_hp;s.vital_numbers.clear();s.heal_zombie(z,10000)
	check("恶客治疗也记录实际回复",s.vital_numbers.entries[0].healing and s.vital_numbers.entries[0].amount==before-20)
	s.vital_numbers.clear();p.hp=10
	for i in 60:s.heal_plant(p,.1,true);s.vital_numbers.update(1.0/60)
	check("持续治疗周期汇总且持续显示",not s.vital_numbers.entries.is_empty() and s.vital_numbers.pending.size()<=1)
	s.vital_numbers.mode="off";s.vital_numbers.update(.1);s.damage_plant(p,2);s.heal_plant(p,1)
	check("关闭数字后无伤害治疗浮字",s.vital_numbers.entries.is_empty() and s.vital_numbers.pending.is_empty())
	s=fresh();p=s.place_free("shooter",2,2);p.upgrades={1:0,2:0,3:3};s.spawn_zombie("ghost",2,{"x":1000});s.training=true;s.no_skill_cooldown=true;s.activate_skill(p)
	check("训练主动无冷却仍保持连发互斥",s.active_skill_status(p).left==0 and not s.active_skill_status(p).ready)
	for i in 260:s.time+=.01;s._update_shooter(p,.01)
	check("训练主动无冷却可在完成后再释放",s.shots.size()==130 and s.active_skill_status(p).ready and s.activate_skill(p))
	s.training=false;check("正式守夜不启用训练无冷却",not s.active_skill_status(p).ready)
	var frames:Array=[]
	for i in 32:frames.append(int(floor(UnitView.shooter_cast_frame(p,p.skill_cast_at+i/60.0)*8)))
	check("签筒连发动作不再被每枚弹重置",unique_count(frames)>20)
	var worlds:Array=[]
	for mode in ["off","large"]:
		var world:=fresh();world.vital_numbers.mode=mode;world.time=1
		world.place_free("shooter",1,2);world.place_free("herb-gourd",2,1)
		var wall=world.place_free("wall",2,2);wall.hp=100
		var enemy=world.spawn_zombie("mountain",2,{"x":800});enemy.burn_dps=6;enemy.burn_t=10;enemy.burn_src="torch"
		world.spawn_zombie("ghost",1,{"x":920});worlds.append(world)
	var parity:=true
	for i in 600:
		for world in worlds:world.tick(1.0/60.0)
		if i%60==59 and parity and canonical_state(worlds[0])!=canonical_state(worlds[1]):
			parity=false
			for n in 2:
				var diagnostic=FileAccess.open("res://qa/todo-parity-%d.json"%n,FileAccess.WRITE);diagnostic.store_string(canonical_state(worlds[n]));diagnostic.close()
	check("浮字开关不改变十秒完整战斗状态或随机序列",parity)
	s=fresh();s.begin_boss("earth");var encounter=s.active_bosses()[0];var target=encounter.body_targets[0]
	s.vital_numbers.clear();s.boss.damage_token="shot:one";s.damage_zombie(target,100);s.damage_zombie(encounter.body_targets[1],100)
	check("恶首多行同次伤害浮字不重复",s.vital_numbers.entries.size()==1 and s.vital_numbers.entries[0].amount==100)
	s.vital_numbers.clear();s.boss.damage_token=""
	for i in 30:encounter.damage(null,1,"torch",true);s.vital_numbers.update(1.0/60.0)
	check("恶首独立持续伤害也持续显示",not s.vital_numbers.entries.is_empty() and s.vital_numbers.entries[0].amount>0)
	check("图鉴灵枢基础数值同步20/35/50",Almanac.plant_rows("soul-casket").any(func(r):return String(r.value).contains("20%") and String(r.value).contains("35%") and String(r.value).contains("50%")))
	for type in ["incense-thief","sky-ferry","sky-wick","shield-envoy","oar-barge"]:check(type+"本事包含完整特殊能力",Almanac.zombie_ability(type).length()>100)
	for type in Content.PLANT_ORDER:
		for path in Upgrades.paths_for(type):
			for entry in path.tiers:check(type+" "+entry.name+"描述无旧缩写",not String(entry.desc).contains("增伤") and not String(entry.desc).contains("易伤") and not String(entry.desc).contains("各吃全额") and not String(entry.desc).contains("友军打它"))
	var f=FileAccess.open("res://qa/todo-20261115-mechanics.json",FileAccess.WRITE);f.store_string(JSON.stringify({"total":checks.size(),"failures":failures,"checks":checks},"  "));f.close()
	print("TODO MECHANICS ",checks.size()," FAILURES ",failures);quit(0 if failures==0 else 1)
