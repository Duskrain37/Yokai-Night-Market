extends SceneTree
var checks:Array=[]
var failures:=0
func check(label:String,ok:bool):
	checks.append({"name":label,"ok":ok})
	if not ok:failures+=1;printerr("FAIL ",label)
func setup(week:int)->Sim:
	var s:=Sim.new();s.setup(Content.get_level(Content.level_id_for(week,4)),["lantern","shooter","wall","cat"],"normal",7070);s.sun=100000
	for row in 6:
		for col in range(2,9):
			if s.can_place_at("wall",col,row).ok:s.place_free("wall",col,row)
	s.boss=preload("res://scripts/boss_encounter.gd").new();s.boss.begin(s,String(s.level.boss_id));s.time=4
	return s
func _initialize():run.call_deferred()
func run():
	for week in [6,7,8]:
		var s:=setup(week);var b=s.boss
		check("第%d周恶首双行目标" % week,b.body_targets.size()==2 and b.body_targets[1].row==b.body_targets[0].row+1)
		var hp:float=b.hp;s.damage_zombie(b.body_targets[0],100,true);s.damage_zombie(b.body_targets[1],100,true)
		check("两行射弹均可伤恶首%d" % week,is_equal_approx(hp-b.hp,200))
		b._start_small();var first:String=b.action.kind
		check("小招都有足够预警%d" % week,b.action.warning_end-s.time>=2.3)
		s.time=b.action.warning_end;b._resolve_small()
		if week==6:
			check("云拂带攻速减益",s.plants.any(func(p):return not p.penalties.is_empty()))
		elif week==7:check("落幕有独立睡眠",s.plants.any(func(p):return p.sleep_until>s.time))
		else:check("契灯带减伤害",s.plants.any(func(p):return not p.penalties.is_empty()))
		b._start_small();check("两种小招交替%d" % week,b.action.kind!=first)
		s.time=b.action.warning_end;b._resolve_small()
		if week==6:
			check("云结封印可以被击碎",b.props.size()>0)
			if not b.props.is_empty():
				var prop=b.props[0];var host=b.target_plant(prop.boss_meta);b.break_prop(prop)
				check("击碎云结解除封印",host.sealed_until<=s.time)
		if week==8:check("恶首点市仍有八秒预告",not s.chapter.event_active() and s.chapter.market_pair>=0)
		b._start_major();check("阈值大招有实际目标与三秒预警%d" % week,not b.action.targets.is_empty() and b.action.warning_end-s.time==3)
		s.time=b.action.warning_end+3;b._resolve_major()
		check("大招有专属连续特效%d" % week,b.effects.any(func(e):return e.kind in ["cloud","curtain","lamps"]))
		var old:int=b.body_row;b._start_blink();check("施法后随机换行且位置同步%d" % week,b.body_row!=old and b.body_targets[0].row==b.body_row)
		var restored:=Sim.new();restored.restore(JSON.parse_string(JSON.stringify(s.serialize())))
		check("恶首中途读档完整%d" % week,restored.boss.id==b.id and restored.boss.body_row==b.body_row and is_equal_approx(restored.boss.hp,b.hp))
		b.small_casts=4;b._start_small();check("恶首号令生成末波军阵%d" % week,b.action.kind=="summon_wave")
		var before:int=s.spawn_queue.size();b._resolve_small();check("号令确实排入普通出怪队列%d" % week,s.spawn_queue.size()>before)
	var s:=setup(6);s.time=61
	var b=s.boss;var p=s.main_plant_at(2,1);b.action={"targets":[b._target(2,1)]}
	var target:Dictionary=b.action.targets[0]
	s.time=63;s.chapter.sync_platforms()
	check("云台位移后点名跟原株而非旧格",b.target_plant(target)==p and target.c==p.col and b.target_position(target).is_equal_approx(p.pos))
	var saved:=s.serialize();var restored:=Sim.new();restored.restore(JSON.parse_string(JSON.stringify(saved)))
	check("云台点名读档仍跟原株",restored.boss.target_plant(restored.boss.action.targets[0]).uid==p.uid)
	FileAccess.open("res://qa/v070-boss.json",FileAccess.WRITE).store_string(JSON.stringify({"total":checks.size(),"failures":failures,"checks":checks},"  "))
	print("V070 BOSS TOTAL ",checks.size()," FAILURES ",failures);quit(0 if failures==0 else 1)
