extends SceneTree
var checks:Array=[]
var failures:=0
func check(label:String,ok:bool):
	checks.append({"name":label,"ok":ok})
	if not ok:failures+=1;printerr("FAIL ",label)
func setup(week:int=1)->Sim:
	var s:=Sim.new();s.setup(Content.get_level(Content.level_id_for(week)),Content.PLANT_ORDER.duplicate(),"easy",7070)
	s.cards.clear()
	for type in Content.PLANT_ORDER:s.cards.append({"id":type,"def":Content.PLANTS[type],"cd":0.0})
	s.sun=100000;return s
func card(s:Sim,type:String)->Dictionary:
	return s.cards.filter(func(c):return c.id==type)[0]
func index(s:Sim,type:String)->int:
	for i in s.cards.size():
		if s.cards[i].id==type:return i
	return -1
func guest(s:Sim,row:int,type:String="ghost"):
	var z=s.spawn_zombie(type,row,{"x":1100.0,"sedan_split":true});z.hp=10000;z.max_hp=10000;return z
func _initialize():run.call_deferred()
func run():
	for type in ["root-palanquin","watch-bloom","vow-toad"]:
		check(type+"图鉴完整",Almanac.PLANTS.has(type) and Almanac.plant_rows(type).size()>3 and not Almanac.plant_ability(type).is_empty())
		check(type+"肖像存在",ResourceLoader.exists("res://assets/sprites/"+type+".png"))
	for id in ["wind-warden","mask-master","market-lamplord"]:
		check(id+"恶首录完整",id in Almanac.BOSS_ORDER and Almanac.boss_skills(id).size()>=6 and Almanac.boss_portrait(id)!=null)
	var s:=setup();var p=s.place_free("watch-bloom",1,1)
	card(s,"shooter").cd=20;card(s,"bomb").cd=40;card(s,"watch-bloom").cd=20
	s.additions.tick(14.99)
	check("更筹未满15秒不触发",card(s,"shooter").cd==20)
	s.additions.tick(.01)
	check("基础只照料普通卡且排除自己灰烬",card(s,"shooter").cd==17 and card(s,"bomb").cd==40 and card(s,"watch-bloom").cd==20)
	var q=s.place_free("watch-bloom",2,1);s.additions.tick(15)
	check("同名不叠周期",card(s,"shooter").cd==14)
	p.upgrades={1:3,2:2,3:0};card(s,"shooter").cd=100;card(s,"wall").cd=90
	s.additions.bloom_trigger(p)
	check("1-3加2-2两卡各减3秒并折价25",card(s,"shooter").cd==97 and card(s,"wall").cd==87 and card(s,"shooter").discount==25)
	for i in 4:s.additions.bloom_trigger(p)
	check("2-2折价最多50",card(s,"shooter").discount==50)
	p.upgrades={1:0,2:3,3:2};p.seed_priority="bomb";card(s,"cat").cd=80
	var skill=s.place_free("shooter",3,1);skill.upgrades={1:0,2:0,3:3};skill.skill_ready_at=40
	s.additions.bloom_trigger(p)
	check("指定优先灰烬也能减秒",card(s,"bomb").cd==38)
	check("3-2同时减主动冷却",skill.skill_ready_at==38)
	check("2-3照料三卡",card(s,"cat").cd==78)
	for i in 5:s.additions.bloom_trigger(p)
	check("2-3折价最多100且费用最低0",card(s,"shooter").discount==100 and s.card_cost(index(s,"shooter"))==0)
	card(s,"shooter").cd=0;var old_sun:int=s.sun
	check("折价只在种下时消费",s.try_place_card(index(s,"shooter"),4,1,Vector2.ZERO) and s.sun==old_sun and card(s,"shooter").discount==0)
	p.upgrades={1:0,2:0,3:3};q.upgrades={1:0,2:0,3:3};p.skill_order=1;q.skill_order=2
	skill.skill_ready_at=30
	check("唯一主动只有一个持有",s.active_skill_status(p).exists and not s.active_skill_status(q).exists)
	check("全场回筹可用",s.activate_skill(p))
	s.time=.79;s.additions.tick(.79);check("回筹动画完成前不提前归零",card(s,"watch-bloom").cd>0)
	s.time=.8;s.additions.tick(.01)
	check("回筹全卡归零且主动减十秒自身90秒",s.cards.all(func(c):return c.cd==0) and skill.skill_ready_at==20 and p.skill_ready_at==90 and s.additions.bloom_skill_ready_at==90)
	var restored:=Sim.new();restored.restore(JSON.parse_string(JSON.stringify(s.serialize())))
	check("回筹全局冷却存档保留",restored.additions.bloom_skill_ready_at==90)
	s=setup();p=s.place_free("vow-toad",2,2);guest(s,2)
	s.additions.update_toad(p,10)
	check("默认蓄香不攻击",s.shots.is_empty() and p.toad_mode=="hoard")
	check("基础可切换开火",s.activate_skill(p) and p.toad_mode=="fire" and s.active_skill_status(p).left==10)
	s.sun=174;s.additions.update_toad(p,3)
	check("留150不足不扣费不射击",s.sun==174 and s.shots.is_empty())
	s.sun=175;s.additions.update_toad(p,.01)
	check("基础25付费175直射",s.sun==150 and s.shots.size()==1 and s.shots[0].damage==175 and s.shots[0].kind=="pea")
	p.upgrades={1:0,2:3,3:0};p.toad_shots=0;s.shots.clear();s.sun=1000
	for i in 3:s.additions.update_toad(p,1.6)
	check("2-3三发只付一次25",s.sun==975 and s.shots.size()==3)
	p.upgrades={1:3,2:0,3:1};s.shots.clear();p.timer=0;s.additions.update_toad(p,2.5)
	check("抛币与大型翻倍标签",s.shots.size()==1 and s.shots[0].kind=="lob" and s.shots[0].payload.toad_large and is_equal_approx(s.shots[0].damage,350))
	p.upgrades={1:0,2:0,3:2};s.shots.clear();p.timer=0;s.sun=1000;p.toad_shots=0;s.additions.update_toad(p,2.5)
	check("3-2每次50且增伤70",s.sun==950 and is_equal_approx(s.shots[0].damage,297.5))
	p.toad_mode="hoard";p.production_haste=1;p.production_bonus=.2;s.orbs.clear();s.additions.update_toad(p,3.25)
	check("蓄香生产接受生产加成",s.orbs.size()==1 and s.orbs[0].value==60)
	p.upgrades={1:0,2:0,3:3};s.time=10;p.skill_ready_at=0
	s.activate_skill(p);s.activate_skill(p)
	check("3-3无切换冷却进入超频12秒60秒周期",p.toad_mode=="overclock" and p.toad_overclock_until==22 and p.toad_overclock_ready_at==70 and s.active_skill_status(p).ready)
	s.shots.clear();p.timer=0;s.additions.update_toad(p,1.9)
	check("超频间隔1.9增伤120溅射全额",s.shots.size()==1 and is_equal_approx(s.shots[0].damage,385) and s.shots[0].payload.coin_splash==1)
	s.time=22;s.additions.update_toad(p,0)
	check("超频到时回蓄香",p.toad_mode=="hoard")
	s.activate_skill(p);s.activate_skill(p)
	check("超频冷却只能切换原两态",p.toad_mode=="hoard")
	s=setup();p=s.place_free("ember-cicada",2,2);p.upgrades={1:0,2:0,3:3}
	var z=guest(s,2);var large=guest(s,3,"mountain")
	check("照明弹可施放",s.activate_skill(p))
	s.time=.99;s.additions.tick(.99);check("照明弹未到1秒不提前结算",z.stun_t==0)
	s.time=1;s.additions.tick(.01);check("照明弹1秒结算全场及大型减半",is_equal_approx(z.stun_t,1.8) and is_equal_approx(large.stun_t,.9) and z.flare_reveal_until==7)
	s.time=7;check("照明看破准时结束",not s._guest_exposed(z))
	s=setup();p=s.place_free("year-banyan",1,1);p.hp=87;p.growth_steps=2;p.upgrades={1:2,2:0,3:3};p.skill_ready_at=20;p.sleep_until=9;p.shell=123
	var uid:String=p.uid;old_sun=s.sun
	check("迁根不能重复同格",not s.additions.transplant(index(s,"root-palanquin"),p,1,1,Vector2.ZERO) and s.sun==old_sun)
	check("迁根成功只扣75",s.additions.transplant(index(s,"root-palanquin"),p,4,2,Vector2.ZERO) and s.sun==old_sun-75)
	check("迁根保留同一对象全部状态",p.uid==uid and p.hp==87 and p.growth_steps==2 and p.tier(3)==3 and p.skill_ready_at==20 and p.sleep_until==9 and p.shell==123 and s.plants_lost==0)
	check("迁根有连续搬运轨迹",p.transplant_progress==0 and p.transplant_until==.9)
	s.time=.45;s.additions.tick(.45);check("迁根轨迹中点",is_equal_approx(p.transplant_progress,.5))
	restored=Sim.new();restored.restore(JSON.parse_string(JSON.stringify(s.serialize())))
	check("迁根中读档保留轨迹",is_equal_approx(restored.main_plant_at(4,2).transplant_progress,.5))
	s=setup();p=s.place_free("umbrella",2,2);p.secondary={"t":10};check("收妖第二槽不能搬",not s.additions.transplant_reason(p).is_empty())
	s=setup(3);p=s.place_free("shooter",1,0);s.place_free("lily",4,1)
	check("无承载水面不能搬",not s.additions.transplant(index(s,"root-palanquin"),p,3,1,Vector2.ZERO))
	check("已有夜莲水格可搬",s.additions.transplant(index(s,"root-palanquin"),p,4,1,Vector2.ZERO) and p.on_lily)
	card(s,"root-palanquin").cd=0;s.time=1
	check("搬离水面夜莲留下",s.additions.transplant(index(s,"root-palanquin"),p,2,0,Vector2.ZERO) and s.lily_at(4,1)!=null and not p.on_lily)
	var result={"total":checks.size(),"failures":failures,"checks":checks}
	FileAccess.open("res://qa/v070-plants.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("V070 PLANTS TOTAL ",checks.size()," FAILURES ",failures);quit(0 if failures==0 else 1)
