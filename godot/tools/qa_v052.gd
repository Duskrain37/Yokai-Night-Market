extends SceneTree

const GameScript = preload("res://scripts/game.gd")
const Boss = preload("res://scripts/boss_encounter.gd")

var checks: Array = []
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(name: String, ok: bool) -> void:
	checks.append({"name": name, "ok": ok})
	if not ok:
		failures += 1
		printerr("FAIL ", name)

func battle(id := 1, cards: Array = ["lantern", "shooter", "herb-gourd"]) -> Sim:
	var sim := Sim.new()
	sim.setup(Content.get_level(id), cards, "easy")
	return sim

func run() -> void:
	var s := battle()
	var healer := s.place_free("herb-gourd", 2, 2)
	var near := s.place_free("wall", 4, 2)
	var behind := s.place_free("wall", 0, 2)
	var elsewhere := s.place_free("wall", 2, 0)
	healer.hp = 120
	near.hp = 90
	behind.hp = 20
	elsewhere.hp = 10
	s._update_healer(healer, 1.6)
	check("基础治疗只照料前方三格和自身，挑生命最低的一株", near.hp == 140 and healer.hp == 120 and behind.hp == 20 and elsewhere.hp == 10)
	healer.upgrades[1] = 1
	healer.timer = 99
	s._update_healer(healer, 0.01)
	check("行医一阶可治疗同行后方", behind.hp == 70)
	healer.upgrades[1] = 2
	healer.timer = 99
	s._update_healer(healer, 0.01)
	check("行医二阶覆盖本列", elsewhere.hp == 60)
	healer.upgrades[1] = 2
	healer.upgrades[2] = 3
	healer.timer = 99
	s._update_healer(healer, 0.01)
	check("十字范围的最高良方每次同时恢复两株96", elsewhere.hp == 156 and behind.hp == 166)
	healer.upgrades = {1: 0, 2: 0, 3: 3}
	for plant in s.plants:
		plant.hp = plant.max_hp
	var cat := s.place_free("cat", 3, 2)
	var attack := s.place_free("shooter",5,2)
	healer.timer = 99
	s._update_healer(healer, 0.01)
	s.refresh_plant_buffs()
	check("满血鼓舞追魂40%、普通攻击20%、无攻击石磨不受益", is_equal_approx(cat.haste, 0.4) and is_equal_approx(attack.haste, 0.2) and near.haste==0)
	s.time += 3.6
	s.refresh_plant_buffs()
	check("鼓舞在3.5秒后结束", cat.haste == 0.0)

	s = battle()
	var cicada := s.place_free("ember-cicada", 0, 0)
	cicada.upgrades = {1: 0, 2: 3, 3: 2}
	cicada.ember_ammo = 2
	cicada.timer = 0.0
	var dummy := s.spawn_zombie("ghost", 0)
	dummy.hp = 10
	s.damage_zombie(dummy, 30.0, false, false, "ember-cicada", "", false, "homing", cicada.uid)
	check("烬翼蝉击杀按射手返还一发并提前0.4秒", cicada.ember_ammo == 3 and is_equal_approx(cicada.timer, 0.4))
	cicada.upgrades = {1: 0, 2: 2, 3: 3}
	var armored := s.spawn_zombie("straw", 0)
	armored.hp = 1000
	armored.armor = 1000
	armored.max_armor = 1000
	var dealt := s.damage_zombie(armored, 100, false, false, "ember-cicada", "", false, "homing", cicada.uid)
	check("满阶看破同源护甲易伤取最高50%", dealt == 150 and armored.armor == 850 and armored.revealed_tier == 3)
	armored.armor = 0
	dealt = s.damage_zombie(armored, 100, false, false, "shooter")
	check("满阶看破本体承受125", dealt == 125)
	var mud := s.spawn_zombie("formless", 0)
	mud.revealed_tier = 1
	var hits := 0
	for i in 50:
		hits += int(s.damage_zombie(mud, 1.0) > 0)
	check("看破永久阻止泥影闪避", hits == 50)
	var bride := s.spawn_zombie("bride", 0, {"sedan_split": true})
	var before: float = bride.hp
	s.damage_zombie(bride, 20, false, false, "bomb")
	check("未被看破的鬼新娘闪避灰烬", bride.hp == before)
	bride.revealed_tier = 1
	s.damage_zombie(bride, 20, false, false, "bomb")
	check("看破后灰烬可击中鬼新娘", bride.hp == before - 20)

	s = battle()
	var target := s.spawn_zombie("ghost", 0)
	target.hp = 10000
	check("单次小数伤害四舍五入", s.damage_zombie(target, 37.5) == 38)
	var continuous := 0.0
	for i in 60:
		continuous += s.damage_zombie(target, 40.0 / 60.0, true, true, "test-dot")
	check("持续伤害按累计余数准确结算", continuous == 40)

	s = battle()
	var kite := s.place_free("sky-kite", 0, 0)
	kite.upgrades = {1: 0, 2: 3, 3: 0}
	var guests: Array[Sim.Zombie] = []
	for i in 5:
		var guest := s.spawn_zombie("ghost", 0, {"x": 500.0 + i * 100})
		guest.hp = 10000
		guests.append(guest)
	var shot := Sim.Shot.new()
	shot.src = "sky-kite"
	shot.owner_uid = kite.uid
	shot.base_damage = 100
	shot.damage = 100
	shot.payload = {"bounces": 4, "bounce_full_first": true}
	var expected := [100.0, 50.0, 25.0, 12.5]
	for i in 4:
		s._kite_bounce(shot, guests[4 - i])
		shot = s.shots.back()
		check("回翎第%d次弹射选左侧最近目标并正确衰减" % (i + 1),
			shot.target == guests[3 - i] and is_equal_approx(shot.damage, expected[i]))
	var old_shots := s.shots.size()
	s._kite_bounce(shot, guests[0])
	check("没有第五次弹射", s.shots.size() == old_shots)

	s = battle()
	var till := s.place_free("wish-till", 3, 2)
	till.upgrades[3] = 3
	var close := s.spawn_zombie("ghost", 1, {"x": till.pos.x})
	var companion := s.spawn_zombie("ghost", 1, {"x": till.pos.x + 0.4 * Geo.CELL_W})
	var outside := s.spawn_zombie("ghost", 1, {"x": till.pos.x + 0.6 * Geo.CELL_W})
	s._update_wish_till(till, 0.01)
	check("满阶招客同时牵引半格内同伴", close.pull_row == 2 and companion.pull_row == 2 and outside.pull_row == -1)
	check("招客冷却保持五秒", is_equal_approx(till.lane_pull_at - s.time, 5.0))

	s = battle()
	s._create_crater(3, 2)
	check("陆地劫痕禁止种植", s.tile_at(3, 2).kind == "pit" and not s.can_place_at("shooter", 3, 2).ok)
	var restored := Sim.new()
	restored.restore(JSON.parse_string(JSON.stringify(s.serialize())))
	check("禁种坑洞跟随存档", restored.ruin_craters.size() == 1 and restored.tile_at(3, 2).kind == "pit")
	restored.time = 60.0
	restored._update_craters()
	check("坑洞60秒后恢复原地表", restored.ruin_craters.is_empty() and restored.can_place_at("shooter", 3, 2).ok)
	s = battle(11)
	s._create_crater(3, 1)
	check("水面劫痕保留水体区别", not String(s.ruin_craters[0].base.water).is_empty())

	check("恶首生命、伤害、频率和援军倍率按新要求", is_equal_approx(Boss.HEALTH_SCALE, 2.1)
		and is_equal_approx(Boss.SKILL_FORCE, 2.0) and is_equal_approx(Boss.SKILL_RATE, 5.0 / 3.0)
		and Boss.REINFORCEMENT_MASS == 1.0)
	s = battle(26)
	s.queue_wave(s.level.waves[11], 11)
	var incense: int = s.sun
	s.time = s.boss.combat_at
	s.boss.tick(0.01)
	check("恶首入场不额外补香火", s.sun == incense)
	s.boss._die()
	s.update_waves()
	check("限制恶首败后下一波没有准备缓冲", s.boss == null and is_equal_approx(
		s.wave_time_offset + float(s.level.waves[s.wave_index].t), s.time))
	var roster: Array = PrepCinema.preview_roster(Content.get_level(26), Content.ZOMBIE_ORDER)
	check("备战镜头包含两种鬼官形态", roster.has("boss-magistrate-bound") and roster.has("boss-magistrate-full"))
	for tier in ["l", "m", "h"]:
		check("镜头每阶最多三名 " + tier, roster.filter(func(type): return Content.ZOMBIES.get(type, {}).get("tier", "") == tier).size() <= 3)

	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.settings.speed = 3.0
	game.start_battle(1, ["shooter", "herb-gourd"])
	check("开战固定一倍速", game.speed == 1.0)
	game.hud._set_speed(0.1)
	check("所有正式战斗直接切到0.1倍速", game.speed == 0.1 and not game.sim.cheated)
	game.hud._toggle_cheat()
	check("打开作弊菜单保持原速度", game.speed == 0.1)
	game.hud._toggle_cheat()
	game.sim.wave_index = 5
	check("半程之前是开张曲", game.wave_phase() == "battle")
	game.sim.wave_index = 6
	check("达到一半转白热化", game.wave_phase() == "hot")
	game._music_for_wave()
	check("半程提示与战曲同步", game.sim.battle_hot and "白热化" in String(game.sim.banner.get("subtitle", "")))
	var plant: Sim.Plant = game.sim.place_free("shooter", 2, 2)
	plant.upgrades[1] = 3
	game.hud.try_open_menu(plant, plant.pos)
	var fan = game.hud._fan
	check("已满阶路线悬停有三阶效果", fan != null and String(fan.entries[0].next_desc) == Upgrades.TREES.shooter[0].tiers[2].desc)
	game.open_almanac("zombie", 5)
	var book = game.screen_node
	var current: String = book._current_type()
	book._change_sort(1)
	check("图鉴排序保留当前条目", book._current_type() == current)
	var ranks: Array = book._sorted_indices().map(func(i): return ["l","m","h"].find(Content.ZOMBIES[Content.ZOMBIE_ORDER[i]].tier))
	var sorted := ranks.duplicate()
	sorted.sort()
	check("恶客按低中高排列", ranks == sorted)
	game.open_almanac("plant", Content.PLANT_ORDER.find("herb-gourd"))
	book = game.screen_node
	current = book._current_type()
	book._change_sort(1)
	var roles_seen: Array = []
	var previous_role := ""
	var contiguous := true
	for i in book._sorted_indices():
		var role: String = Content.PLANTS[Content.PLANT_ORDER[i]].role
		if role != previous_role:
			if role in roles_seen: contiguous = false
			roles_seen.append(role)
			previous_role = role
	check("草木类型排序保持同类连续且保留当前条目", contiguous and book._current_type() == current)
	book._change_sort(0)
	check("切回发布顺序恢复完整原序", book._sorted_indices() == range(Content.PLANT_ORDER.size()))
	game.show_levels()
	await process_frame
	check("选关五周题签同排完整展示", is_equal_approx(game.screen_node._week_scroll.size.y, 66) and game.screen_node._week_buttons.size() == 5)
	game.show_menu()
	game.open_news()
	check("封面可以打开自然语言更新公告", game.screen == "news")
	var data := {"total": checks.size(), "failures": failures, "checks": checks}
	var file := FileAccess.open("res://qa/v052-tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	print("V052 TOTAL ", checks.size(), " FAILURES ", failures)
	quit(0 if failures == 0 else 1)
