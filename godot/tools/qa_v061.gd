extends SceneTree
var checks:Array=[]
var failures:=0
func check(label:String,ok:bool):
	checks.append({"name":label,"ok":ok})
	if not ok:failures+=1;printerr("FAIL ",label)
func setup()->Sim:
	var s:=Sim.new();s.setup(Content.get_level(1),Content.PLANT_ORDER.duplicate(),"normal",611);s.sun=100000;return s
func guest(s:Sim,row:int,x:float,type:String="ghost"):
	var z=s.spawn_zombie(type,row,{"x":x,"sedan_split":true});z.hp=10000;z.max_hp=10000;return z
func _initialize():run.call_deferred()
func run():
	var s:=setup();var p=s.place_free("judge",3,2);p.upgrades={1:0,2:0,3:0}
	var ally=s.place_free("shooter",2,1)
	check("钟馗基础3x3含对角且30%",s._judge_covers(p,ally) and is_equal_approx(s.plant_guard(ally),.3))
	p.upgrades={1:3,2:0,3:0};check("钟馗1-3扩大5x5",s._judge_covers(p,s.place_free("lantern",1,0)))
	s.damage_plant(ally,100000);check("钟馗续命保留1血并独立60秒冷却",ally.hp==1 and ally.ward_ready_at==60)
	s.time=4;s.damage_plant(ally,100000);check("续命冷却内不能重触发",ally.dead)
	s=setup();p=s.place_free("judge",2,2);p.upgrades={1:0,2:3,3:0}
	var q=s.place_free("judge",3,3);q.upgrades={1:0,2:3,3:0}
	check("唯一技能仅最先在场解锁者持有",s.active_skill_status(p).exists and not s.active_skill_status(q).exists)
	ally=s.place_free("shooter",7,0);ally.sleep_until=9;ally.sealed_until=8;s.apply_plant_penalty(ally,"damage",.5,10,"test")
	var z=guest(s,0,1100,"incense-thief")
	check("钟馗技能可施放",s.activate_skill(p))
	check("神威清除草木所有负面状态",ally.sleep_until==0 and ally.sealed_until==0 and ally.penalties.is_empty())
	check("神威全场覆盖与40攻速",s._judge_covers(p,ally) and is_equal_approx(ally.haste,.4))
	check("神威沉默八秒与50秒冷却",z.silence_until==8 and s.active_skill_status(p).left==50)
	s._refresh_guest_attributes(z);check("神威全屏40减速",is_equal_approx(z.slow_amount,.4))
	var restored:=Sim.new();restored.restore(JSON.parse_string(JSON.stringify(s.serialize())))
	check("唯一技能全局冷却读档保持",restored.unique_skill_ready_at==50 and restored.global_silence_until==8)
	s=setup();p=s.place_free("shooter",2,2);p.upgrades={1:0,2:0,3:3};guest(s,2,1000)
	check("签筒主动可施放",s.activate_skill(p))
	for i in 260:s.time+=.01;s._update_shooter(p,.01)
	check("签筒主动严格130枚",s.shots.size()==130 and p.skill_shots_left==0)
	check("签筒45秒冷却",is_equal_approx(p.skill_ready_at,45))
	check("三种技能图标独立且加载",preload("res://data/active_skills.gd").DEFINITIONS.values().all(func(d):return ResourceLoader.exists(d.icon)))
	s=setup();p=s.place_free("year-banyan",2,2);p.growth_steps=4;p.upgrades={1:0,2:2,3:0};guest(s,2,1000)
	s._update_banyan(p,2);check("榕2-2单枚46伤",s.shots.size()==1 and s.shots[0].damage==46)
	p.upgrades[2]=3;s._update_banyan(p,2);check("榕2-3恢复六连发",s.shots.size()==7)
	s=setup();p=s.place_free("torch",2,2);p.upgrades={1:2,2:1,3:0};s.apply_hp_scale(p)
	check("火盆最高阶每阶加500耐久",p.max_hp==1300)
	var shot:=Sim.Shot.new();shot.base_damage=100;shot.damage=100;s._torch_give_pierce(shot,3)
	check("火盆穿透2次100/100/50",shot.pierce_left==2 and shot.pierce_factors==[1.,1.,.5])
	var natural:=Sim.Shot.new();natural.pierce_left=1;s._torch_give_pierce(natural,3)
	check("火盆不修改原有穿透",natural.pierce_left==1 and natural.torch_pierce_tier==0)
	s=setup();p=s.place_free("shooter",2,2)
	s.apply_plant_penalty(p,"damage",.2,10,"A");s.apply_plant_penalty(p,"damage",.25,10,"B");p.buff_damage=.5
	check("草木异源减益乘算并与增益相乘",is_equal_approx(p.damage_multiplier(),.9))
	s.apply_plant_penalty(p,"damage",.1,20,"A");check("同源较弱不延长或覆盖",is_equal_approx(p.damage_multiplier(),.9))
	z=guest(s,2,1000);s.apply_slow(z,10,.2,"A");s.apply_slow(z,10,.25,"B");z.rage_mult=1.5;z.rage_t=10
	check("恶客不同减速相乘再乘加速",is_equal_approx(s.guest_attribute_factor(z,"speed"),.9))
	s.apply_vulnerable(z,10,.2,"A");s.apply_vulnerable(z,10,.3,"B");check("不同来源易伤乘算",is_equal_approx(s.guest_vulnerability(z),1.56))
	s=setup();p=s.place_free("sky-mortar",2,2);var a=guest(s,1,900);var b=guest(s,1,930)
	s._mortar_launch(p,a.pos);shot=s.shots[0];a.row=4;b.row=4;a.pos=Vector2(650,s.row_y(4));b.pos=Vector2(680,s.row_y(4))
	s._update_mortar_shot(shot,1.24);check("炮弹起飞时不锁定",not shot.payload.get("locked",false))
	s._update_mortar_shot(shot,.01);check("落地前0.25秒锁定新密集位置",shot.payload.locked and shot.tx==650 and shot.row==4)
	s._update_mortar_shot(shot,.25);check("新落点真正造成伤害",a.hp==9785 and b.hp==9785)
	check("龙首铳基础450耐久",Content.PLANTS.dragon.hp==450)
	check("类型标签统一",Content.PLANTS.needle.role=="射弹" and Content.PLANTS.star.role=="射弹" and Content.PLANTS.dragon.role=="群攻" and Content.PLANTS.judge.role=="辅助" and Content.PLANTS.shell.role=="防御")
	# Expiry, migration and independent source semantics.
	s=setup();p=s.place_free("shooter",2,2)
	p.penalties={"damage":{"amount":.3,"until":10.,"source":"old"}}
	s.apply_plant_penalty(p,"damage",.2,30,"old")
	check("旧版草木减益迁移仍按同源最高",p.penalties.size()==1 and is_equal_approx(p.damage_multiplier(),.7))
	s.time=11;s._refresh_plant_penalties(p);check("较弱不能延长旧强减益",p.penalties.is_empty() and p.damage_multiplier()==1)
	z=guest(s,2,1000);s.apply_slow(z,2,.3,"bell");s.apply_slow(z,5,.2,"bell")
	s.time=14;s._refresh_guest_attributes(z);check("恶客减速到期无残留",z.slow_t==0 and z.slow_amount==0 and s.guest_attribute_factor(z,"speed")==1)
	s.apply_guest_penalty(z,"damage",.2,10,"A");s.apply_guest_penalty(z,"damage",.25,10,"B")
	check("恶客伤害减益同样乘算",is_equal_approx(s.guest_attribute_factor(z,"damage"),.6))
	s.apply_guest_penalty(z,"haste",.2,10,"A");s.apply_guest_penalty(z,"haste",.25,10,"B")
	check("恶客攻速减益同样乘算",is_equal_approx(s.guest_attribute_factor(z,"haste"),.6))
	restored=Sim.new();restored.restore(JSON.parse_string(JSON.stringify(s.serialize())))
	check("异源减益读档保持",is_equal_approx(restored.guest_attribute_factor(restored.zombies[0],"damage"),.6))
	# Ward excludes ash plants, works again after sixty seconds and is per target.
	s=setup();p=s.place_free("judge",3,2);p.upgrades={1:3,2:0,3:0}
	ally=s.place_free("shooter",2,2);var second=s.place_free("shooter",4,2);var ash=s.place_free("ruin-cap",3,1)
	s.damage_plant(ally,999999);s.damage_plant(second,999999);s.damage_plant(ash,999999)
	check("续命每株独立且灰烬无效",ally.hp==1 and second.hp==1 and ash.dead)
	s.time=60;s.damage_plant(ally,999999);check("60秒后续命可再次触发",not ally.dead and ally.ward_ready_at==120)
	# Highest investment cheer targets have no distance restriction.
	s=setup();p=s.place_free("lion",0,0);p.upgrades={1:0,2:0,3:2};var candidates:Array=[]
	for i in 6:
		var item=s.place_free("shooter",i+1,4);item.paid_incense=(i+1)*100;candidates.append(item)
	s._lion_cheer(p,Upgrades.EFFECTS.lion)
	check("醒狮3-2选全场造价最高三株",candidates.slice(0,3).all(func(x):return x.cheer==0) and candidates.slice(3).all(func(x):return x.cheer==1))
	p.upgrades[3]=3;s._lion_cheer(p,Upgrades.EFFECTS.lion)
	check("醒狮3-3选五株并包含自己",p.cheer==1 and is_equal_approx(p.cheer_value,.1) and candidates[0].cheer==0 and candidates.slice(1).all(func(x):return x.cheer>0 and is_equal_approx(x.cheer_value,.1)))
	check("两条降价路线总价与25倍数",Upgrades.tier_cost("lion",2,1)+Upgrades.tier_cost("lion",2,2)+Upgrades.tier_cost("lion",2,3)==675 and Upgrades.tier_cost("year-banyan",2,1)+Upgrades.tier_cost("year-banyan",2,2)+Upgrades.tier_cost("year-banyan",2,3)==675)
	# Copy is deterministic, not a chance roll; relay and original bonuses multiply.
	for tier in 3:
		s=setup();p=s.place_free("soul-casket",2,2);p.upgrades={1:0,2:tier,3:0};p.buff_damage=.5
		shot=Sim.Shot.new();shot.base_damage=20;shot.damage=30;shot.lantern_buff=.5
		s._relay_release(p,s.pack_unit(shot),0)
		check("灵枢第%d档独立增伤"%tier,is_equal_approx(s.shots[0].damage,30*(1+float([.2,.35,.5][tier]))*1.5))
	s=setup();p=s.place_free("soul-casket",2,2);p.upgrades={1:0,2:3,3:0}
	for i in 5:
		shot=Sim.Shot.new();shot.src="shooter";shot.base_damage=20;shot.damage=20;s._relay_capture(p,shot)
	check("灵枢2-3每发必定复制",s.shots.size()==10)
	# True physical piercing through multiple victims and saving midflight.
	for tier in [1,2,3]:
		s=setup();p=s.place_free("shooter",1,2);shot=Sim.Shot.new();s._prepare_shot(shot,p,100);s._torch_give_pierce(shot,tier)
		var targets:Array=[]
		for i in (3 if tier==3 else 2):targets.append(guest(s,2,700+i*80))
		for target in targets:s._strike_straight(shot,target)
		var expected:Array=[100.,40.] if tier==1 else [100.,80.] if tier==2 else [100.,100.,50.]
		for i in expected.size():check("穿薪%d第%d个目标实际伤害"%[tier,i],is_equal_approx(10000-targets[i].hp,expected[i]))
		check("穿薪预算命中后耗尽%d"%tier,shot.dead)
	s=setup();p=s.place_free("shooter",2,2);p.upgrades={1:0,2:0,3:3};guest(s,2,1000);s.activate_skill(p)
	s.time=1.0;s._update_shooter(p,1.0);restored=Sim.new();restored.restore(JSON.parse_string(JSON.stringify(s.serialize())))
	var rp=restored.plants[0]
	for i in 160:restored.time+=.01;restored._update_shooter(rp,.01)
	check("签筒连发中途读档不重发不丢弹",restored.shots.size()==130 and rp.skill_shots_left==0 and rp.skill_ready_at==45)
	s=setup();p=s.place_free("judge",2,2);p.upgrades={1:0,2:3,3:0};q=s.place_free("judge",3,2);q.upgrades={1:0,2:3,3:0};s.activate_skill(p)
	p.dead=true;check("唯一所有权转交不重置全场冷却",s.active_skill_status(q).exists and s.active_skill_status(q).left==50 and not s.activate_skill(q))
	# Enemy aura leaves the moment its source no longer covers the victim.
	s=setup();p=s.place_free("judge",2,2);p.upgrades={1:0,2:2,3:0};z=guest(s,2,1000);s._refresh_guest_attributes(z);z.row=0;s._refresh_guest_attributes(z)
	check("钟馗威慑离开范围立即失效",z.slow_t==0 and s.guest_attribute_factor(z,"speed")==1)
	s=setup();p=s.place_free("torch",2,2);p.upgrades={1:0,2:0,3:3};var dragon=s.place_free("dragon",3,2)
	var old_save:Dictionary=JSON.parse_string(JSON.stringify(s.serialize()));old_save.erase("plant_rule_revision")
	for row in old_save.plants:
		row.state_v040.max_hp=1500 if row.type=="torch" else 300
		row.state_v040.hp=1000 if row.type=="torch" else 200
	restored=Sim.new();restored.restore(old_save)
	check("老存档火盆按新上限迁移且保留已损失耐久",restored.plants[0].max_hp==1800 and restored.plants[0].hp==1300)
	check("老存档龙首铳补齐450上限",restored.plants[1].max_hp==450 and restored.plants[1].hp==350)
	var again:=Sim.new();again.restore(JSON.parse_string(JSON.stringify(restored.serialize())))
	check("反复读档不重复补血",again.plants[0].hp==1300 and again.plants[1].hp==350)
	s=setup();z=guest(s,2,1100);z.def=z.def.duplicate(true);z.def.armor_speed=2.;z.armor=100;z.rage_mult=1.5;z.rage_t=10
	s.apply_slow(z,10,.2,"A");s.apply_slow(z,10,.25,"B")
	check("护具与外部加速异源相加",is_equal_approx(s.guest_attribute_factor(z,"speed"),1.5))
	s=setup();s.begin_boss("earth");var chief=s.active_bosses()[0];z=chief.body_targets[0]
	s.apply_vulnerable(z,20,.2,"A");s.apply_vulnerable(z,20,.3,"B");var before:float=chief.hp;s.damage_zombie(z,100,false,false,"shooter")
	check("恶首易伤只乘算一次156",is_equal_approx(before-chief.hp,156))
	chief.state="idle";chief.small_at=0;s.global_silence_until=8
	for i in range(1,8):s.time=i;chief.tick(1)
	check("神威沉默期间恶首不发动施法",chief.small_casts==0 and chief.state=="idle")
	s.time=8.1;chief.tick(.1);check("沉默结束正常恢复施法",chief.small_casts==1 and chief.state=="small_warning")
	s=setup();var carrier=guest(s,2,1000,"sky-ferry");z=guest(s,2,980);carrier.silence_until=8;s._try_pickup(carrier)
	check("沉默阻止浮灯轿夫搭载特殊能力",carrier.passenger_uid.is_empty())
	s.time=8;s._try_pickup(carrier);check("沉默结束搭载恢复",carrier.passenger_uid==z.uid)
	s=setup();p=s.place_free("shooter",2,2);p.upgrades={1:0,2:0,3:3};guest(s,2,1000);s.activate_skill(p);p.sleep_until=3
	for i in range(1,300):s.time=i*.01;s.update_plants(.01)
	s.time=3.02;s.update_plants(.01)
	check("沉睡后连发不一次补发大量子弹",s.shots.size()<=3)
	for i in 260:s.time+=.01;s.update_plants(.01)
	check("沉睡恢复后仍精确130发",s.shots.size()==130)
	# Exercise homing -> forward drift and star collisions, not only straight darts.
	for kind in ["homing","star","drift"]:
		s=setup();p=s.place_free("shooter",1,2);shot=Sim.Shot.new();s._prepare_shot(shot,p,100)
		shot.kind=kind;shot.look="star" if kind=="star" else "pea";shot.dir=Vector2.RIGHT
		s._torch_give_pierce(shot,3)
		var victims:Array=[]
		for i in 3:victims.append(guest(s,2,700+i*90))
		shot.target=victims[0]
		for i in 3:
			shot.pos=victims[i].pos+Vector2(-1,-24)
			if shot.kind=="homing":s._update_homing(shot,0)
			elif shot.kind=="star":s._update_star_shot(shot,0)
			else:s._update_drifting(shot,0)
		check(kind+"穿薪实际100/100/50且耗尽",victims[0].hp==9900 and victims[1].hp==9900 and victims[2].hp==9950 and shot.dead)
	for tier in [1,2]:
		s=setup();p=s.place_free("shooter",2,2);p.upgrades[3]=tier;guest(s,2,1000)
		var probe:=RandomNumberGenerator.new();var seed_value:=0
		while true:
			probe.seed=seed_value
			if probe.randf()<float([0,.1,.15][tier]):break
			seed_value+=1
		s.rng.seed=seed_value;s.start_volley(p)
		var deadline:float=p.shooter_quick_at
		check("签筒3-%d触发缩短下次1秒"%tier,p.timer==1 and deadline==float([0,7,6][tier]))
		s.time=deadline-.01;s.rng.seed=seed_value;s.start_volley(p)
		check("签筒3-%d内置冷却不能提前触发"%tier,p.shooter_quick_at==deadline and p.timer==0)
		s.time=deadline;s.rng.seed=seed_value;s.start_volley(p)
		check("签筒3-%d内置冷却到点恢复"%tier,p.shooter_quick_at==deadline*2 and p.timer==1)
	s=setup();s.setup(Content.get_level(11),Content.PLANT_ORDER.duplicate(),"normal",611)
	p=s.place_free("judge",2,2);p.upgrades={1:3,2:0,3:0};ally=s.place_free("lily",3,1)
	s.damage_plant(ally,100000);restored=Sim.new();restored.restore(JSON.parse_string(JSON.stringify(s.serialize())))
	check("夜莲续命冷却也随读档保留",restored.lily_at(3,1).ward_ready_at==60 and restored.lily_at(3,1).hp==1)
	s=setup();p=s.place_free("torch",2,2);p.upgrades={1:0,2:0,3:3};p.hp=100;p.eaten_until=5;z=guest(s,2,p.pos.x+40)
	s.update_plants(.1);check("火盆第三路重做彻底取消旧啃食火墙",z.hp==10000 and p.hp==100)
	s=setup();z=guest(s,2,1000,"incense-thief");s.time=5;s._step_incense_thief(z);s.update_particles(.1)
	check("盗烬动作特效使用定点寿命更新",s.particles.any(func(fx):return fx.kind=="theft" and is_equal_approx(fx.life,.75)))
	var f=FileAccess.open("res://qa/v061-tests.json",FileAccess.WRITE);f.store_string(JSON.stringify({"total":checks.size(),"failures":failures,"checks":checks},"  "));f.close()
	print("V061 TOTAL ",checks.size()," FAILURES ",failures);quit(0 if failures==0 else 1)
