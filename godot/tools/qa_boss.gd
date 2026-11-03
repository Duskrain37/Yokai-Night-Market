extends SceneTree
var checks: Array=[]
var failed=0

func check(name: String,value: bool,detail: String="") -> void:
	checks.append({"name":name,"ok":value,"detail":detail})
	if not value:failed+=1;printerr("FAIL ",name," ",detail)

func _init() -> void:
	call_deferred("run")

func create(id: int) -> Sim:
	var s=Sim.new()
	s.setup(Content.get_level(id),["lantern","shooter","wall","lily","cat","lobber","star","umbrella"],"normal")
	s.time=500
	s.wave_index=Array(s.level.waves).size()-Content.WAVES_PER_GROUP
	s.queue_wave(s.level.waves[s.wave_index],s.wave_index)
	return s

func same(a,b) -> bool:
	# JSON numeric types are floats; compare through one identical decoding boundary.
	return JSON.stringify(JSON.parse_string(JSON.stringify(a)))==JSON.stringify(b)

func tree_rules(paths: Array) -> Array:
	var copy=paths.duplicate(true)
	for path in copy:
		for tier in path.tiers:tier.erase("desc")
	return copy

func tick_clean(s: Sim,seconds: float) -> void:
	for i in int(seconds*60):
		for z in s.zombies:
			if z.boss_role=="":z.dead=true
		s.tick(1.0/60.0);s.sounds.clear();s.sound_detail.clear()

func run() -> void:
	var fixtures: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tools/fixtures/v032_baseline.json"))
	for level in Content.LEVELS.slice(0,15):
		var expected=[4,4,6,6,8][(int(level.id)-1)%5]
		check("关%d 大波数" % int(level.id),Content.wave_groups(level)==expected)
		check("关%d 威胁按用户新值" % int(level.id),is_equal_approx(float(level.threat),float([.8,1.,1.2,1.4,1.6,1.,1.25,1.5,1.75,2.,1.2,1.53,1.85,2.18,2.5][int(level.id)-1])))
		check("关%d 前四大波保持" % int(level.id),same(Array(level.waves).slice(0,12),fixtures.levels[int(level.id)-1].waves))
	check("狐尾灯用户进化数值保持",same(Upgrades.EFFECTS.cat,fixtures.cat_effects))
	check("狐尾灯用户三路保持",same(tree_rules(Upgrades.TREES.cat),tree_rules(fixtures.cat_tree)))
	for id in ["lantern","shooter","wall"]:
		check(id+" 原型数值保持",same(Upgrades.EFFECTS[id],fixtures.prototype_effects[id]))
	for level in Content.LEVELS.slice(0,15):
		if int(level.id)%5==0:continue
		var s=create(int(level.id))
		check("关%d 没有首领" % int(level.id),s.boss==null)
	for id in [5,10,15]:
		var s=create(id)
		var b=s.boss
		check("首领%d 替换整组队列" % id,b!=null and s.wave_index==s.level.waves.size() and s.spawn_queue.is_empty())
		check("首领%d 命门覆盖每行" % id,b.weakpoints.size()==s.rows)
		check("首领%d 不计入普通兵上限" % id,s.active_zombies()==0)
		var health=b.hp
		s.kill_zombie(b.weakpoints[0])
		check("首领%d 不被收妖或门神直接处决" % id,b.hp==health and b.alive())
		b.damage_token="shot:unit-test"
		s.damage_zombie(b.weakpoints[0],100,false,false,"shooter")
		s.damage_zombie(b.weakpoints[1],100,false,false,"shooter")
		check("首领%d 同弹多命门只结算一次" % id,is_equal_approx(b.hp,health-100))
		b.damage_token=""
		var normal_hp=b.max_hp
		b.damage(null,normal_hp*.81,"shooter")
		check("首领%d 跨全部阈值按序入队" % id,b.fired.size()==b.config.major_thresholds.size() and b.major_queue.size()==b.fired.size())
		tick_clean(s,36)
		check("首领%d 阈值各只释放一次" % id,b.major_count==b.config.major_thresholds.size())
		check("首领%d 援兵受上限约束" % id,b.peak_adds<=int(b.config.adds.live_cap))
		var snapshot: Dictionary=JSON.parse_string(JSON.stringify(s.serialize()))
		var r=Sim.new();r.restore(snapshot)
		check("首领%d 快照共享生命与阈值" % id,is_equal_approx(r.boss.hp,b.hp) and r.boss.fired==b.fired)
		check("首领%d 快照保留随机状态" % id,str(r.rng.state)==str(s.rng.state))
		check("首领%d 快照重建命门" % id,r.boss.weakpoints.size()==r.rows and r.active_zombies()==s.active_zombies())
		# Interrupt an already telegraphed lethal strike by killing the boss first.
		var p=s.place_free("shooter",7,0)
		if p!=null:p.hp=1
		b._start_major()
		b.damage_token="";b.damage(null,b.max_hp*2,"shooter")
		var old_lost=s.plants_lost
		tick_clean(s,4)
		check("首领%d 死后无延迟拆卡" % id,s.plants_lost==old_lost)
		check("首领%d 死亡清空预警与出兵" % id,b.action.is_empty() and b.major_queue.is_empty() and s.active_zombies()==0)
		check("首领%d 退散后结算" % id,s.is_cleared())
	var s=create(15);var b=s.boss
	var lily=s.place_free("lily",3,1)
	var host=s.place_free("shooter",3,1)
	host.hp=10;host.paid_incense=375
	b.action={"kind":"major","kills":0}
	var sun=s.sun
	b._hurt_cell({"c":3,"r":1},360)
	check("水路只拆宿主不拆底座",host.dead and not lily.dead and s.lily_at(3,1)==lily)
	check("回收累计实付80%",s.sun-sun==300)
	var economy=s.place_free("lantern",0,0);economy.hp=1
	b._hurt_cell({"c":0,"r":0},100000)
	check("后两列经济受保护",not economy.dead and economy.hp==1)
	var p=s.place_free("wall",4,0);p.hp=1
	b.destruction_used=int(b.config.destruction_budget)
	b._hurt_cell({"c":4,"r":0},10000)
	check("拆卡预算耗尽伤害非致命",not p.dead and p.hp>=1)
	var seal_host=s.place_free("shooter",5,0)
	seal_host.sealed_until=s.time+5
	b._add_prop("paper_seal",{"c":5,"r":0},120,5)
	var seal=b.props.back()
	s.damage_zombie(seal,121,false,false,"shooter")
	check("纸封可攻击拆除且立即复工",seal.dead and seal_host.sealed_until==0)
	check("纸封拆除有碎裂事件",not b.effects.filter(func(f):return f.kind=="break").is_empty())
	var shield=create(5)
	var before=shield.boss.max_hp
	for z in shield.boss.weakpoints:z.bomb_t=.01;z.bomb_damage=before*.08
	shield.tick(.02)
	check("百分比伤害不随命门数翻倍",shield.boss.hp>=before*.99-.001)
	var paper=Sim.new();paper.setup(Content.get_level(1),["umbrella"],"normal")
	var umbrella=paper.place_free("umbrella",4,0)
	umbrella.upgrades={1:0,2:0,3:1};umbrella.secondary={"busy":true,"t":10.0,"max":15.0};umbrella.timer=100
	var prey=paper.spawn_zombie("ghost",0,{"x":umbrella.pos.x+30})
	paper._update_umbrella(umbrella,.02)
	check("纸伞副槽忙时主槽仍可收妖",not prey.alive() and umbrella.chew_t>0, str([prey.dead,umbrella.chew_t,umbrella.timer,prey.pos,umbrella.pos,prey.is_large(),prey.boss_role]))
	umbrella.secondary={}
	var large=paper.spawn_zombie("sedan",0,{"x":umbrella.pos.x+30})
	paper._try_umbrella_secondary(umbrella,Upgrades.EFFECTS.umbrella)
	check("纸伞副槽不能瞬收大型敌人",large.alive() and umbrella.secondary.is_empty())
	var resume=create(5)
	var shot=Sim.Shot.new();shot.uid="saved-shot";shot.target=resume.boss.weakpoints[0]
	shot.hit_ids=[resume.boss.weakpoints[1]];shot.pos=Vector2(1000,300);shot.damage=20;shot.speed=100
	resume.shots.append(shot);resume.natural_timer=1.234
	resume.boss.damage_token="shot:saved-shot";resume.boss.damage(shot.target,20)
	var restored=Sim.new();restored.restore(JSON.parse_string(JSON.stringify(resume.serialize())))
	check("存档保留飞行子弹和命门引用",restored.shots.size()==1 and restored.shots[0].target==restored.boss.weakpoints[0] and restored.shots[0].hit_ids[0]==restored.boss.weakpoints[1])
	var old_hp=restored.boss.hp
	restored.boss.damage_token="shot:saved-shot";restored.boss.damage(restored.shots[0].target,20)
	check("存档续局同弹不重复结算",restored.boss.hp==old_hp and is_equal_approx(restored.natural_timer,1.234))
	var legacy=resume.serialize();legacy.erase("boss");legacy.erase("level_snapshot");legacy.erase("format")
	var old=Sim.new();old.restore(legacy)
	check("旧版续局保留四大波不插入首领",old.boss==null and old.level.waves.size()==12 and String(old.level.boss_id)=="")
	var capped=create(5)
	for i in 15:capped.spawn_zombie("ghost",i%capped.rows)
	check("拆甲增援也遵守首领场上上限",capped.active_zombies()==int(capped.boss.config.adds.live_cap))
	var portal=create(5)
	portal.boss._add_prop("tunnel",{"c":6,"r":0},160,9)
	var tunnel=portal.boss.props[0]
	portal.boss._spawn_add("light",tunnel)
	var traveller=portal.zombies.filter(func(z):return z.boss_role=="")[0]
	check("地洞先在边界出兵",traveller.pos.x>=Geo.SPAWN_X and traveller.boss_meta.has("portal_at"))
	portal.time+=.5;portal.boss.tick(.5)
	check("地洞延迟借道且不偷袭经济区",is_equal_approx(traveller.pos.x,tunnel.pos.x+Geo.CELL_W*.48) and traveller.pos.x>portal.cell_pos(5,0).x)
	var marks=create(5);var target=marks.boss.weakpoints[0]
	marks.add_mark(target,"fox",1,.1)
	marks.boss.tick(.2)
	check("首领身上记号正常到期",marks.mark_stacks(target,"fox")==0)
	var burst_before=marks.boss.hp
	marks.boss.damage_token="shot:compound"
	marks.damage_zombie(target,24,false,false,"cat")
	marks.damage_zombie(target,40,false,false,"cat","fox_ignite")
	marks.damage_zombie(marks.boss.weakpoints[1],40,false,false,"cat","fox_ignite")
	check("固定爆发保留且跨命门不翻倍",is_equal_approx(burst_before-marks.boss.hp,64))
	marks.boss.damage_token="plant:brace"
	var lion=marks.place_free("lion",8,0);lion.upgrades={1:0,2:3,3:0};lion.brace_t=.01
	var brace_before=marks.boss.hp
	marks._lion_brace(lion,Upgrades.EFFECTS.lion,.02)
	check("最前列醒狮蹲桩能触及命门",is_equal_approx(brace_before-marks.boss.hp,60))
	var sealed=create(5);var original=sealed.place_free("shooter",5,0)
	sealed.boss._add_prop("paper_seal",{"c":5,"r":0},120,5)
	var old_seal=sealed.boss.props[0]
	sealed.kill_plant(original,true)
	var replacement=sealed.place_free("censer",5,0);replacement.sealed_until=550
	sealed.boss._update_props(.02,false)
	check("拆宿主后旧纸封不缠住新草木",old_seal.dead and replacement.sealed_until==550)
	var river=create(15)
	var crab=river.make_boss_proxy("crab",0,Geo.SPAWN_X,180,{"kind":"crab","until":river.time+10,"c":8,"r":0})
	river.boss.props.append(crab);crab.burn_t=1;crab.burn_dps=20
	river.boss._update_props(.5,false)
	check("河螯接受灼烧伤害",is_equal_approx(crab.hp,170))
	crab.stun_t=.4;var crab_x=crab.pos.x
	river.boss._update_props(.1,false)
	check("河螯可被控场暂缓冲撞",crab.pos.x==crab_x)
	var keyed={target:true}
	var decoded=marks._unpack_value(marks._pack_value(keyed))
	check("存档保留已命中目标集合",decoded.has(target) and decoded[target])
	var file=FileAccess.open("res://qa/boss-tests.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"total":checks.size(),"failures":failed,"checks":checks},"  "))
	print("BOSS TESTS ",checks.size()," FAILURES ",failed)
	quit(0 if failed==0 else 1)
