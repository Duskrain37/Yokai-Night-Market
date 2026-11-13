extends SceneTree
var checks=[]
var failures=0
func check(label: String,ok: bool):
	checks.append({"name":label,"ok":ok})
	if not ok:failures+=1;printerr("FAIL ",label)
func same(a,b) -> bool:
	return JSON.parse_string(JSON.stringify(a))==JSON.parse_string(JSON.stringify(b))
func _init():run.call_deferred()
func run():
	var old=JSON.parse_string(FileAccess.get_file_as_string("res://tools/fixtures/v055-balance.json"))
	var rewritten={"shooter":[0,2],"lion":[1,2],"torch":[0,1,2],"judge":[0,1,2],"year-banyan":[1],"soul-casket":[1]}
	var roles={"shooter":"射弹","censer":"群攻","umbrella":"近战","cat":"射弹","shell":"防御","lobber":"射弹","torch":"辅助","star":"射弹","needle":"射弹","judge":"辅助","lily":"辅助","firework":"群攻","dragon":"群攻","sky-kite":"射弹","ember-cicada":"群攻","herb-gourd":"辅助","reed-chime":"群攻","soul-casket":"辅助"}
	var approved=["year-banyan","dragon","sky-kite","star","soul-casket","reed-chime","censer"]
	for type in Content.PLANT_ORDER:
		if type == "sky-mortar": continue # reworked and covered by qa_v060
		var now=Content.PLANTS[type].duplicate(true);var before=old.plants[type].duplicate(true)
		match type:
			"year-banyan":before.cost=125
			"dragon":before.cost=350;before.hp=450
			"sky-kite":before.cost=225
			"star":before.star.damage=28.0;before.star.interval=1.4
			"censer":before.censer.damage=50.0;before.censer.radius=156.0
		if roles.has(type):before.role=roles[type]
		check(type+"本体仅改变获批数字与类型",same(now,before))
		var paths=Upgrades.paths_for(type);var previous=old.trees.get(type,[])
		check(type+"进化路数保持",paths.size()==previous.size())
		for i in paths.size():
			if i in rewritten.get(type,[]):continue # 数值与实际机制由qa_v061逐项覆盖
			var a=paths[i].duplicate(true);var b=previous[i].duplicate(true)
			for tier in 3:
				if type in approved:a.tiers[tier].desc=b.tiers[tier].desc
				a.tiers[tier].desc=String(a.tiers[tier].desc).replace("3×3范围","周围九格")
				b.tiers[tier].desc=String(b.tiers[tier].desc).replace("3×3范围","周围九格")
			check(type+"路线%d费用与机制保持"%i,same(a,b))
		var effects=Upgrades.EFFECTS.get(type,{}).duplicate(true);var prev=old.effects.get(type,{}).duplicate(true)
		if type in ["star","censer"]:
			for key in (["damage","interval"] if type=="star" else ["radius","interval"]):prev[key]=effects[key]
		elif type in ["reed-chime","soul-casket"]:prev=effects
		if type not in ["shooter","lion","torch","judge","soul-casket"]:
			check(type+"效果表无越权变更",same(effects,prev))
	check("恶客、关卡、推荐表未改",Content.ZOMBIES.keys().all(func(id):return id in ["incense-thief","sky-ferry"] or same(Content.ZOMBIES[id],old.zombies[id])) and same(Content.DAYS,old.days) and same(Content.LOADOUT_TIPS,old.recommendations))
	var s=Sim.new();s.setup(Content.get_level(1),Content.PLANT_ORDER.duplicate(),"easy",560)
	var reed=s.place_free("reed-chime",2,2);reed.timer=10
	for offset in [60,100,140]:
		var z=s.spawn_zombie("ghost",2,{"x":reed.pos.x+offset});z.hp=10000;z.max_hp=10000
	s._update_reed_chime(reed,0)
	check("篁音仍穿过束内全部三客",s.zombies.all(func(z):return z.hp==9958))
	check("篁音三阶数值",Upgrades.EFFECTS["reed-chime"]=={"damage":[42,49,56,70],"interval":[1.6,1.5,1.35,1.2],"slow":[0,.15,.25,.45]})
	check("灵枢增伤与复制率",Upgrades.EFFECTS["soul-casket"]=={"bonus":[.2,.35,.5,.5],"copy_chance":1.0})
	check("禁止非法双毕业搭配",not Upgrades.path_status("star",{1:3,2:2,3:0},2).ok)
	check("图鉴与实际基础一致",Almanac.plant_rows("reed-chime").any(func(row):return row.value=="42"))
	var news=JSON.parse_string(FileAccess.get_file_as_string("res://data/news_v056.json"))
	check("公告版本与获批七株齐备",news.version=="0.5.6" and news.sections[2].items.size()==7)
	var f=FileAccess.open("res://qa/v056-balance-tests.json",FileAccess.WRITE);f.store_string(JSON.stringify({"total":checks.size(),"failures":failures,"checks":checks},"  "));f.close()
	print("V056 TOTAL ",checks.size()," FAILURES ",failures);quit(0 if failures==0 else 1)
