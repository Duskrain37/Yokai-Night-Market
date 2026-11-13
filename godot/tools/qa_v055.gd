extends SceneTree
var checks: Array=[]
var failures:=0
func check(name: String,ok: bool) -> void:
	checks.append({"name":name,"ok":ok})
	if not ok:failures+=1;printerr("FAIL ",name)
func setup() -> Sim:
	var s:=Sim.new();s.setup(Content.get_level(1),Content.PLANT_ORDER.duplicate(),"easy",555)
	return s
func guest(s: Sim,row: int,x: float,type:="ghost") -> Sim.Zombie:
	var z=s.spawn_zombie(type,row,{"x":x,"sedan_split":true});z.hp=10000;z.max_hp=10000
	return z
func _init():run.call_deferred()
func run():
	var Rules=preload("res://data/nightmare.gd")
	check("常规携带12株",Sim.MAX_LOADOUT==12 and Rules.loadout_limit({})==12)
	for tier in [1,2]:
		var level:=Content.get_level(1).duplicate(true);level.nightmare_factors={"light_pack":tier}
		var s:=Sim.new();s.setup(level,Content.PLANT_ORDER.duplicate(),"nightmare",55)
		check("限带因子档%d"%tier,s.cards.size()==[12,10,8][tier] and s.factor_points()==[0,1,3][tier])
	for id in ["year-banyan","sky-mortar"]:
		check(id+"名册图鉴三路完整",Content.PLANT_ORDER.has(id) and Almanac.PLANTS.has(id) and Almanac.plant_rows(id).size()>=6 and Upgrades.paths_for(id).size()==3)
		for path in Upgrades.paths_for(id):
			var last:=0
			for tier in path.tiers:
				check(id+"阶费用递增整25·"+tier.name,tier.cost%25==0 and tier.cost>last);last=tier.cost
	for map in ["street","market","water","island","cavern"]:
		check(map+"推荐覆盖32株",Content.loadout_tips(map).size()==Content.PLANT_ORDER.size())
	var s:=setup();var p=s.place_free("year-banyan",2,2)
	s._update_banyan(p,2.99);check("首次3秒前无产出",s.orbs.is_empty())
	s.time=3;s._update_banyan(p,.01);check("首次3秒产50",s.orbs.size()==1 and s.orbs[-1].value==50)
	s.time=12.99;s._update_banyan(p,9.99);check("后续10秒未到不产出",s.orbs.size()==1)
	s.time=13;s._update_banyan(p,.01);check("后续10秒产出",s.orbs.size()==2)
	s.time=30;s._update_banyan(p,0);check("30秒首长产65",p.growth_steps==1 and s.banyan_value(p)==65)
	s.time=60;s._update_banyan(p,0);check("60秒二长产80",p.growth_steps==2 and s.banyan_value(p)==80)
	s.time=90;s._update_banyan(p,0);check("白板最多两次成长",p.growth_steps==2)
	p.upgrades={1:3,2:0,3:0};s.apply_hp_scale(p);s._update_banyan(p,0)
	check("满阶延长成长且耐久按年轮增加",p.growth_steps==3 and p.max_hp==750)
	var income:=s.orbs.size();s.time=91;s._update_banyan(p,0)
	check("成长后1秒额外产出不改主计时",s.orbs.size()==income+1 and p.timer<1)
	s.time=120;s._update_banyan(p,0);check("最多四长110香火900耐久",p.growth_steps==4 and s.banyan_value(p)==110 and p.max_hp==900)
	s.time=121;s._update_banyan(p,0);income=s.orbs.size()
	s.time=150;s._update_banyan(p,0);check("成长上限后30秒额外生产",s.orbs.size()==income+1 and p.growth_steps==4)
	var restored:=Sim.new();restored.restore(JSON.parse_string(JSON.stringify(s.serialize())))
	var grown=restored.plants.filter(func(x):return x.type=="year-banyan")[0]
	check("成长计时与额外产出读档不丢失",grown.growth_steps==4 and grown.growth_next==p.growth_next and grown.tree_bonus_next==p.tree_bonus_next)
	s=setup();p=s.place_free("year-banyan",2,2);p.upgrades={1:0,2:3,3:0};p.growth_steps=4
	guest(s,2,p.pos.x+220);s._update_banyan(p,2)
	check("四长2-3发六枚34伤籽弹",s.shots.size()==6 and s.shots.all(func(a):return a.damage==34 and a.look=="banyan-seed") and is_equal_approx(s.shots[-1].delay,.45))
	s=setup();p=s.place_free("year-banyan",3,2);p.upgrades={1:0,2:0,3:3};p.growth_steps=4
	var shooter=s.place_free("shooter",1,2);var lamp=s.place_free("lantern",3,1);var relay=s.place_free("soul-casket",4,2);var wall=s.place_free("wall",5,2)
	s.refresh_plant_buffs()
	check("四长同心5x5伤速各16",is_equal_approx(shooter.buff_damage,.16) and is_equal_approx(shooter.haste,.16))
	check("非攻击草木不吃攻速增伤",lamp.haste==0 and lamp.buff_damage==0 and wall.haste==0 and wall.buff_damage==0)
	check("专门生产间隔加成精确缩短16%",is_equal_approx(s.lantern_interval(lamp),8*.84))
	check("灵枢可加伤但不能加攻速",is_equal_approx(relay.buff_damage,.16) and relay.haste==0)
	check("庇佑覆盖自身与友方25%",is_equal_approx(s.plant_guard(p),.25) and is_equal_approx(s.plant_guard(shooter),.25))
	var rear=guest(s,2,shooter.pos.x-60);check("明视使射弹能索敌身后",s.lane_target(shooter)==rear)
	s._update_shooter(shooter,2);check("明视射弹真正向左飞",s.shots.size()>0 and s.shots[0].dir==Vector2.LEFT)
	var flying=guest(s,2,shooter.pos.x+120,"sky-wick");s.zombies.erase(rear)
	var shot:=Sim.Shot.new();shot.row=2;shot.pos=flying.pos-Vector2(1,0);shot.speed=100;shot.base_damage=20;shot.damage=20;shot.src="shooter";shot.owner_uid=shooter.uid
	var armor: float=flying.armor;s._update_straight(shot,.01)
	check("明视普通射弹能打到飞行护具",flying.armor<armor)
	p.growth_steps=1;s.refresh_plant_buffs();armor=flying.armor;shot.dead=false;shot.hit_ids=[];shot.pos=flying.pos-Vector2(1,0);s._update_straight(shot,.01)
	check("不足二长不能对空",flying.armor==armor)
	p.growth_steps=4;s.refresh_plant_buffs();var bride=guest(s,2,p.pos.x+30,"bride");s.damage_zombie(bride,50,false,false,"bomb")
	check("明视范围内移除灰烬免疫",bride.hp==9950)
	p.sleep_until=s.time+10;s.refresh_plant_buffs();s.damage_zombie(bride,50,false,false,"bomb")
	check("辅助源沉睡立即失效",bride.hp==9950 and not shooter.sees_air and not shooter.sees_rear)
	s=setup();p=s.place_free("soul-casket",2,2);p.buff_damage=.5;p.haste=10
	shot=Sim.Shot.new();shot.kind="pea";shot.src="shooter";shot.base_damage=20;shot.damage=30;shot.lantern_buff=.5
	var packet:=s.pack_unit(shot);s._relay_release(p,packet,0)
	check("原弹增伤与灵枢增伤独立乘算49.5",is_equal_approx(s.shots[0].damage,49.5))
	s._relay_capture(p,shot);check("灵枢攻速不改变收弹门槛",p.collector_store.size()==1 and s.shots.size()==1)
	s=setup();p=s.place_free("sky-mortar",2,2);var a=guest(s,0,1000);var b=guest(s,3,1100);var c=guest(s,3,1140)
	check("炮弹选择最密集位置",s._mortar_aim() in [b,c])
	p.timer=10;s._update_mortar(p,0);shot=s.shots[0];check("炮弹锁定落点且1.5秒飞行",shot.tx==b.pos.x and shot.flight==1.5)
	s._update_mortar_shot(shot,1.49);check("1.49秒不结算",not shot.dead and b.hp==10000)
	s._update_mortar_shot(shot,.011);check("炮弹1.5秒范围全额215",shot.dead and b.hp==9785 and c.hp==9785 and a.hp==10000)
	s=setup();p=s.place_free("sky-mortar",2,2);p.upgrades={1:3,2:0,3:0};p.timer=10;a=guest(s,2,1100)
	s._update_mortar(p,0);check("连炮每发降伤25%",is_equal_approx(s.shots[0].damage,161.25))
	s.time=.79;s._update_mortar(p,.79);check("0.8秒前不补炮",s.shots.size()==1)
	s.time=.8;s._update_mortar(p,.01);check("0.8秒补炮后开始冷却",s.shots.size()==2 and p.timer==0 and p.mortar_followup_at<0)
	s=setup();p=s.place_free("sky-mortar",2,2);p.upgrades={1:0,2:3,3:2};a=guest(s,2,1050,"bucket");a.armor=1000;a.max_armor=1000
	s._mortar_launch(p,a.pos);s._mortar_impact(s.shots[0]);check("灰烬炮同时伤本体护甲525",a.hp==9475 and a.armor==475)
	a.hp=1;s._mortar_launch(p,a.pos);s._mortar_impact(s.shots[-1]);check("灰烬击退不留尸且旧返香已移除",a.dead and not a.dying and s.sun==100)
	s=setup();a=guest(s,2,1000);s.damage_zombie(a,20000,false,false,"shooter");check("普通击退仍有尸体",a.dying and not a.dead)
	a=guest(s,2,1000,"returner");s.damage_zombie(a,20000,false,false,"bomb");check("灰烬不留下可复生尸体",a.dead and a.revive_at<0)
	# v0.6.0 replaces the former income/homing route; its skill, shards and immunity
	# precedence are covered by qa_v060.gd. No legacy reward is retained.

	s=setup();p=s.place_free("star",2,2);p.upgrades={1:0,2:1,3:0};a=guest(s,2,300)
	s.breach(a);check("巡灯2-1已获得门神激励",p.star_guardian_until==10)
	p.upgrades={1:0,2:3,3:0};s.time=11
	for i in 6:
		a=guest(s,2,1000);a.hp=1;shot=Sim.Shot.new();shot.kind="star";shot.damage=20;shot.owner_uid=p.uid;shot.src="star";s._star_impact(shot,a)
	check("巡灯2-3亲手击退叠五层攻速",p.star_speed_stacks==5 and p.star_speed_until==16)
	s.time=16.01;s._update_star(p,0);check("巡灯攻速激励到时清空",p.star_speed_stacks==0)
	s=setup();p=s.place_free("needle",2,2);p.upgrades={1:3,2:3,3:0};p.needle_shots=3;p.timer=2;guest(s,2,1000);s._update_needle(p,0)
	check("透骨针42伤0.6秒定住大型减半",s.shots[0].damage==42 and s.shots[0].pin==.6 and s.shots[0].pin_large==.3)
	p.upgrades={1:0,2:0,3:3};p.timer=3;s._update_needle(p,0);check("透骨针解甲30/60",s.shots[-1].mark==.3 and s.shots[-1].armor_vulnerability==.6)
	s=setup();p=s.place_free("bell",2,2);p.upgrades={1:0,2:0,3:2};var attack=s.place_free("shooter",3,2);var producer=s.place_free("lantern",1,2);s.refresh_plant_buffs()
	check("铜铃同排加速仅攻击草木",is_equal_approx(attack.haste,.15) and producer.haste==0)
	check("汤圆增幅12/20/30",Upgrades.EFFECTS.lobber.warm_bonus==[0,.12,.2,.3])
	s=setup()
	for i in 7:
		p=s.place_free("shooter",i,2);p.upgrades={1:3,2:0,3:0}
	check("签筒1-3全队叠加封顶五支",s._shooter_team_bonus()==5)
	var level:=Content.get_level(5).duplicate(true);level.nightmare_factors={"twins":1}
	s=Sim.new();s.setup(level,["sky-mortar"],"nightmare",55);p=s.place_free("sky-mortar",2,2);p.upgrades={1:0,2:0,3:1};s.begin_boss("earth")
	var members:=s.active_bosses();var chief=members[0];var peer=members[1]
	var before: float=chief.hp;var peer_hp: float=peer.hp
	var center: Vector2=(chief.body_targets[0].pos+chief.body_targets[1].pos)*.5
	s._mortar_launch(p,center);s.shots[0].t=1.5;s.update_shots(.01)
	check("炮弹覆盖双行同一恶首只结算一次",is_equal_approx(before-chief.hp,215) and peer.hp==peer_hp)
	chief.hp=1;chief._sync_hp();s._mortar_launch(p,center);s.shots[-1].t=1.5;var incense: int=s.sun;s.update_shots(.01)
	check("炮弹击退恶首不再返香且另一位独立存活",not chief.alive() and peer.alive() and s.sun==incense)
	var f=FileAccess.open("res://qa/v055-tests.json",FileAccess.WRITE);f.store_string(JSON.stringify({"total":checks.size(),"failures":failures,"checks":checks},"  "));f.close()
	print("V055 TOTAL ",checks.size()," FAILURES ",failures);quit(0 if failures==0 else 1)



