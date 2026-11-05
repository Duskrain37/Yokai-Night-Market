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
	s.wave_index=Array(s.level.waves).size()-1
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

func same_wave_slots(actual: Array, expected: Array) -> bool:
	if actual.size() != expected.size():
		return false
	var group_actual := {}
	var group_expected := {}
	for i in actual.size():
		var current: Dictionary = actual[i]
		var previous: Dictionary = expected[i]
		if bool(current.flag) != bool(previous.flag) or not is_equal_approx(float(current.t), float(previous.t)):
			return false
		var current_tiers := _tier_counts(current.get("budget_groups", current.groups))
		var previous_tiers := _tier_counts(previous.groups)
		for tier in ["l", "m", "h"]:
			group_actual[tier] = int(group_actual.get(tier, 0)) + int(current_tiers.get(tier, 0))
			group_expected[tier] = int(group_expected.get(tier, 0)) + int(previous_tiers.get(tier, 0))
		if Content.is_flag_batch(i):
			if group_actual != group_expected:
				return false
			group_actual.clear()
			group_expected.clear()
	return true


func _tier_counts(groups: Array) -> Dictionary:
	var counts := {}
	for group in groups:
		var tier = String(Content.ZOMBIES[String(group[0])]["tier"])
		counts[tier] = int(counts.get(tier, 0)) + int(group[1])
	return counts


func _queued_mass(sim: Sim) -> float:
	var total = 0.0
	for entry in sim.spawn_queue:
		total += sim._enemy_mass(String(entry.type)) * float(entry.get("mass_scale", 1.0))
	return total


func run() -> void:
	var fixtures: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tools/fixtures/v032_baseline.json"))
	for level in Content.LEVELS.slice(0,15):
		var expected=[4,4,6,6,8][(int(level.id)-1)%5]
		check("关%d 大波数" % int(level.id),Content.wave_groups(level)==expected)
		check("关%d 威胁按用户新值" % int(level.id),is_equal_approx(float(level.threat),float([.4,.6,.8,1.,1.2,.6,.85,1.1,1.35,1.6,.8,1.13,1.45,1.78,2.1][int(level.id)-1])))
		check("关%d 前四大波保留拨次时间与整组各阶数量" % int(level.id), same_wave_slots(
			Array(level.waves).slice(0, 12), fixtures.levels[int(level.id)-1].waves))
	check("狐尾灯新疾焰与十焰数值",same(Upgrades.EFFECTS.cat.interval_reduction,
		[0.0,0.2,0.4,0.6]) and is_equal_approx(float(Upgrades.EFFECTS.cat.ten_flames_chance[3]),0.1)
		and is_equal_approx(float(Upgrades.EFFECTS.cat.ten_flames_cooldown),6.0))
	check("狐尾灯回魂四团、狐火路保持",int(Upgrades.EFFECTS.cat.count[3])==4
		and int(Upgrades.EFFECTS.cat.hits[3])==2
		and is_equal_approx(float(Upgrades.EFFECTS.cat.mark_vuln[2]), 0.10))
	for id in ["lantern","wall"]:
		check(id+" 原型数值保持",same(Upgrades.EFFECTS[id],fixtures.prototype_effects[id]))
	var shooter_expected: Dictionary = fixtures.prototype_effects.shooter.duplicate(true)
	shooter_expected.erase("crit_slow")
	shooter_expected.crit_chance = [0.0, 0.1, 0.2, 0.33]
	check("签筒旧连射数值保留，双倍伤害与减速概率按新版", same(Upgrades.EFFECTS.shooter, shooter_expected))
	for level in Content.LEVELS.slice(0,15):
		if int(level.id)%5==0:continue
		var s=create(int(level.id))
		check("关%d 没有首领" % int(level.id),s.boss==null)
	for id in [5,10,15]:
		var s=create(id)
		var b=s.boss
		check("首领%d 在末拨与执幡客登场" % id, b != null and s.wave_index == s.level.waves.size()
			and s.spawn_queue.size() == 1 and s.spawn_queue[0].type == "wave-herald")
		check("首领%d 只占相邻两行" % id,b.body_targets.size()==2 and b.body_targets[1].row==b.body_targets[0].row+1)
		check("首领%d 不计入普通兵上限" % id,s.active_zombies()==0)
		var health=b.hp
		s.kill_zombie(b.body_targets[0])
		check("首领%d 不被收妖或门神直接处决" % id,b.hp==health and b.alive())
		b.damage_token="shot:unit-test"
		s.damage_zombie(b.body_targets[0],100,false,false,"shooter")
		s.damage_zombie(b.body_targets[1],100,false,false,"shooter")
		check("首领%d 同弹多本体只结算一次" % id,is_equal_approx(b.hp,health-100))
		b.damage_token=""
		var normal_hp=b.max_hp
		b.damage(null,normal_hp*.81,"shooter")
		check("首领%d 跨全部阈值按序入队" % id,b.fired.size()==b.config.major_thresholds.size() and b.major_queue.size()==b.fired.size())
		tick_clean(s,36)
		check("首领%d 阈值各只释放一次" % id,b.major_count==b.config.major_thresholds.size())
		check("首领%d 在大招期间仍有常驻增援" % id, b.reinforcement_index >= 2 and b.add_count > 0)
		check("首领%d 普通耐久比简单高10%%" % id, is_equal_approx(b.max_hp, float(b.config.max_hp) * 1.5 * 0.85 * 1.1))
		var snapshot: Dictionary=JSON.parse_string(JSON.stringify(s.serialize()))
		var r=Sim.new();r.restore(snapshot)
		check("首领%d 快照共享生命与阈值" % id,is_equal_approx(r.boss.hp,b.hp) and r.boss.fired==b.fired)
		check("首领%d 快照保留随机状态" % id,str(r.rng.state)==str(s.rng.state))
		check("首领%d 快照重建本体" % id,r.boss.body_targets.size()==2 and r.active_zombies()==s.active_zombies())
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
	for id in [5, 10, 15]:
		var summon = create(id)
		var boss = summon.boss
		summon.spawn_queue.clear()
		var basis = Sim.new()
		basis.setup(Content.get_level(id), ["shooter"], "normal")
		basis.rng.seed = 732
		summon.rng.seed = 732
		basis.queue_roster(basis.level.waves[0], -1)
		boss._send_reinforcements()
		check("首领%d 常驻出怪耐久为标准的四分之三" % id,
			is_equal_approx(_queued_mass(summon) / _queued_mass(basis), 0.75 * Content.wave_mass_ratio(basis.level, 0)))
		summon.spawn_queue.clear()
		basis.spawn_queue.clear()
		summon.rng.seed = 883
		basis.rng.seed = 883
		for wave in boss._final_wave():
			basis.queue_roster(wave, -1)
		boss.small_casts = boss.FINAL_WAVE_FIRST_CAST - 1
		boss._start_small()
		boss._resolve_small()
		check("首领%d 号令额外召唤一整组标准最终大波" % id, boss.action.kind == "summon_wave"
			and is_equal_approx(_queued_mass(summon), _queued_mass(basis)) and not summon.spawn_queue.is_empty())
		var restored = Sim.new()
		restored.restore(summon.serialize())
		check("首领%d 读档保留召怪队列" % id, restored.spawn_queue == summon.spawn_queue)
	var moving = create(5)
	var moving_boss = moving.boss
	var old_row = moving_boss.body_row
	moving_boss.state = "small_recovery"
	moving_boss.state_end = moving.time
	moving_boss.smalls_to_blink = 2
	moving_boss.tick(0.01)
	check("第二次小技能前保留原行", moving_boss.body_row == old_row and moving_boss.state == "idle")
	moving_boss.state = "small_recovery"
	moving_boss.state_end = moving.time
	moving_boss.tick(0.01)
	check("小技能后闪影切换至另一组相邻行",
		moving_boss.state == "blink" and moving_boss.body_row != old_row
		and moving_boss.body_targets[0].row == moving_boss.body_row
		and moving_boss.body_targets[1].row == moving_boss.body_row + 1)
	var outside = 0 if moving_boss.body_row > 0 else moving.rows - 1
	for lane in [outside, moving_boss.body_row, moving_boss.body_row + 1]:
		var shot = Sim.Shot.new()
		shot.pos = Vector2(moving_boss.body_x() - 30.0, moving.row_y(lane) - 16.0)
		shot.row = lane
		shot.speed = 400.0
		shot.base_damage = 20.0
		shot.damage = 20.0
		var before = moving_boss.hp
		moving._update_straight(shot, 0.1)
		check("首领本体命中按行%d" % lane, before - moving_boss.hp == (0.0 if lane == outside else 20.0))
	var s=create(15);var b=s.boss
	var lily=s.place_free("lily",3,1)
	var host=s.place_free("shooter",3,1)
	host.hp=10;host.paid_incense=375
	b.action={"kind":"major","kills":0}
	var sun=s.sun
	b._hurt_cell({"c":3,"r":1},360)
	check("水路只拆宿主不拆底座",host.dead and not lily.dead and s.lily_at(3,1)==lily)
	check("首领毁卡不返香火",s.sun==sun)
	var economy=s.place_free("lantern",0,0);economy.hp=1
	b._hurt_cell({"c":0,"r":0},100000)
	check("后两列经济受保护",not economy.dead and economy.hp==1)
	var p=s.place_free("wall",4,0);p.hp=1
	b.destruction_used=int(b.config.destruction_budget)
	b._hurt_cell({"c":4,"r":0},10000)
	check("拆卡预算耗尽伤害非致命",not p.dead and p.hp>0.0)
	var seal_host=s.place_free("shooter",5,0)
	seal_host.sealed_until=s.time+5
	b._add_prop("paper_seal",{"c":5,"r":0},120,5)
	var seal=b.props.back()
	s.damage_zombie(seal,seal.max_hp + 1.0,false,false,"shooter")
	check("纸封可攻击拆除且立即复工",seal.dead and seal_host.sealed_until==0)
	check("纸封拆除有碎裂事件",not b.effects.filter(func(f):return f.kind=="break").is_empty())
	var shield=create(5)
	var before=shield.boss.max_hp
	for z in shield.boss.body_targets:z.bomb_t=.01;z.bomb_damage=before*.08
	shield.tick(.02)
	check("百分比伤害不随本体数翻倍",shield.boss.hp>=before*.99-.001)
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
	var shot=Sim.Shot.new();shot.uid="saved-shot";shot.target=resume.boss.body_targets[0]
	shot.hit_ids=[resume.boss.body_targets[1]];shot.pos=Vector2(1000,300);shot.damage=20;shot.speed=100
	resume.shots.append(shot);resume.natural_timer=1.234
	resume.boss.damage_token="shot:saved-shot";resume.boss.damage(shot.target,20)
	var restored=Sim.new();restored.restore(JSON.parse_string(JSON.stringify(resume.serialize())))
	check("存档保留飞行子弹和本体引用",restored.shots.size()==1 and restored.shots[0].target==restored.boss.body_targets[0] and restored.shots[0].hit_ids[0]==restored.boss.body_targets[1])
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
	var marks=create(5);var target=marks.boss.body_targets[0]
	marks.add_mark(target,"fox",1,.1)
	marks.boss.tick(.2)
	check("首领身上记号正常到期",marks.mark_stacks(target,"fox")==0)
	var burst_before=marks.boss.hp
	marks.boss.damage_token="shot:compound"
	marks.damage_zombie(target,24,false,false,"cat")
	marks.damage_zombie(target,40,false,false,"cat","fox_ignite")
	marks.damage_zombie(marks.boss.body_targets[1],40,false,false,"cat","fox_ignite")
	check("固定爆发保留且跨本体不翻倍",is_equal_approx(burst_before-marks.boss.hp,64))
	marks.boss.damage_token="plant:brace"
	var lion=marks.place_free("lion",8,marks.boss.body_row);lion.upgrades={1:0,2:3,3:0};lion.brace_t=.01
	var brace_before=marks.boss.hp
	marks._lion_brace(lion,Upgrades.EFFECTS.lion,.02)
	check("最前列醒狮蹲桩能触及本体",is_equal_approx(brace_before-marks.boss.hp,60))
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
