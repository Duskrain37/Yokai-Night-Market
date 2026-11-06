## Flow tests use an explicit enemy-clearing harness, not a claim of player solvability.
extends SceneTree
var rows: Array=[]
var failures=0
func check(name: String,ok: bool) -> void:
	rows.append({"name":name,"ok":ok})
	if not ok:failures+=1;printerr("FAIL ",name)
func tick_clear(s: Sim,seconds: float) -> void:
	for i in int(seconds*60):
		for z in s.zombies:
			if z.boss_role=="":z.dead=true
		s.tick(1.0/60.0);s.sounds.clear();s.sound_detail.clear()
func _init() -> void:
	var level=Content.get_level(16)
	check("独立特殊关二十大波",level.special and level.waves.size()==60 and Content.wave_groups(level)==20)
	for i in 60:check("小拨%d威胁" % (i+1),is_equal_approx(float(level.waves[i].threat),Content.SPECIAL_THREATS[int(i/12)]))
	for pair in [[0,[0,1,2,3]],[12,[0,1,2,3]],[13,[4,5,6,7]],[24,[4,5,6,7]],[25,[8,9,10,11]],[36,[8,9,10,11]]]:
		check("四波翻页边界%d" % pair[0],Content.visible_wave_groups(level,pair[0])==pair[1])
	check("六波末页不显示不存在的波",Content.visible_wave_groups(Content.get_level(3),13)==[4,5])
	check("特殊关不暗加水路威胁",Sim.effective_threat(level)==Content.SPECIAL_THREATS[0])
	var s=Sim.new();s.setup(level,["lantern","lily","shooter"],"normal")
	var wins=[0];s.on_win=func():wins[0]+=1
	var p=s.place_free("shooter",2,0);p.paid_incense=225
	for section in 5:
		for i in int(360*60):
			if s.boss!=null:break
			tick_clear(s,1.0/60.0)
		check("段%d四波完整释放后进入恶首" % section,s.boss!=null and s.wave_index==(section+1)*12)
		if s.boss==null:break
		check("段%d恶首顺序" % section,s.boss.id==level.boss_checkpoints[section])
		check("段%d缩放符合指定系数" % section,is_equal_approx(s.hp_mul*s.hp_mul*Content.terrain_factor(level),Content.SPECIAL_THREATS[section]))
		check("恶首战不能催出下一段",not s.summon_next_wave())
		var snapshot: Dictionary=JSON.parse_string(JSON.stringify(s.serialize()))
		var restored=Sim.new();restored.restore(snapshot)
		check("段%d恶首存档不丢阶段" % section,restored.special_bosses_completed==section and restored.wave_index==s.wave_index and restored.boss.id==s.boss.id)
		s.boss.damage_token="";s.boss.damage(null,s.boss.max_hp*2)
		tick_clear(s,2.1)
		check("段%d击败后只推进一个检查点" % section,s.special_bosses_completed==section+1 and s.boss==null)
		if section<4:
			check("中途恶首不能结算全关",wins[0]==0 and not s.is_cleared())
			check("深入鬼市不重置阵容",s.main_plant_at(2,0)==p and p.paid_incense==225)
			var expected := (section + 1) * Content.WAVES_PER_GROUP * 4 + 1
			check("击败恶首后直接放出下一段第一拨", s.wave_index == expected and not s.special_opening())
			var next_index: int = s.wave_index
			tick_clear(s, 12.0)
			check("下一拨仍按正常节奏接续", s.wave_index == next_index)
			var resumed=Sim.new();resumed.restore(JSON.parse_string(JSON.stringify(s.serialize())))
			check("下一段存档保留时钟偏移",is_equal_approx(resumed.wave_time_offset,s.wave_time_offset) and resumed.special_bosses_completed==section+1 and resumed.boss==null)
		else:check("第五恶首之后才通关",s.is_cleared() and wins[0]>0 and s.boss_history.size()==5)
	var f=FileAccess.open("res://qa/special-tests.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"total":rows.size(),"failures":failures,"checks":rows},"  "))
	print("SPECIAL ",rows.size()," FAILURES ",failures)
	quit(0 if failures==0 else 1)
