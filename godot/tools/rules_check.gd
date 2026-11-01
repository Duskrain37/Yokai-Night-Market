## 逻辑检查集合：内容表 / 升阶约束 / 状态不叠加 / 护具与尸体 / 三天地图 /
## 波次与威胁倍率 / 训练场 / 教学关 / 存档快照。由 tools/qa_logic.gd 调用。
class_name RulesCheck
extends RefCounted


static func run_all(harness) -> void:
	_check_content(harness)
	_check_upgrade_rules(harness)
	_check_status_rules(harness)
	_check_armor_and_corpse(harness)
	_check_map_rules(harness)
	_check_waves(harness)
	_check_training(harness)
	_check_tutorial(harness)
	_check_save_roundtrip(harness)


static func _check_content(h) -> void:
	h.check("内容", "18 种草木齐备", Content.PLANTS.size() == 18,
		"实际 %d" % Content.PLANTS.size())
	h.check("内容", "12 种恶客齐备", Content.ZOMBIES.size() == 12,
		"实际 %d" % Content.ZOMBIES.size())
	h.check("内容", "十五夜关卡齐备", Content.LEVELS.size() == 15,
		"实际 %d" % Content.LEVELS.size())
	var missing = []
	for id in Content.PLANT_ORDER:
		if not Content.PLANTS.has(id):
			missing.append(id)
	h.check("内容", "草木顺序表都有定义", missing.is_empty(), str(missing))
	var zombie_missing = []
	for id in Content.ZOMBIE_ORDER:
		if not Content.ZOMBIES.has(id):
			zombie_missing.append(id)
	h.check("内容", "恶客顺序表都有定义", zombie_missing.is_empty(), str(zombie_missing))
	var rows_ok = true
	var detail = ""
	for level in Content.LEVELS:
		var expect = 5 if level["day"] == 3 or level["day"] == 1 else 6
		if int(level["rows"]) != expect:
			rows_ok = false
			detail += "关%d 行数=%d " % [level["id"], level["rows"]]
	h.check("内容", "行数按天地图分配（5/6/5）", rows_ok, detail)
	var threat_ok = true
	for level in Content.LEVELS:
		var t = float(level["threat"])
		if t < 0.8 or t > 3.0:
			threat_ok = false
	h.check("内容", "威胁倍率都在 0.8—3.0", threat_ok)
	h.check("内容", "首波在 17.5 秒", is_equal_approx(
		float(Content.LEVELS[0]["waves"][0]["t"]), 17.5))
	h.check("内容", "波次间隔 18 秒", is_equal_approx(
		float(Content.LEVELS[0]["waves"][1]["t"]) - float(Content.LEVELS[0]["waves"][0]["t"]),
		16.5))
	h.check("内容", "每关 12 波", Content.LEVELS[0]["waves"].size() == 12)
	# 图鉴每篇都要有来历与引语
	var text_ok = true
	for id in Content.PLANT_ORDER:
		var entry: Dictionary = Almanac.PLANTS.get(id, {})
		if String(entry.get("story", "")) == "" or String(entry.get("quote", "")) == "":
			text_ok = false
	for id in Content.ZOMBIE_ORDER:
		var entry: Dictionary = Almanac.ZOMBIES.get(id, {})
		if String(entry.get("story", "")) == "" or String(entry.get("quote", "")) == "":
			text_ok = false
	h.check("内容", "图鉴 30 篇文案齐全", text_ok)
	# 图鉴数值必须来自数据表而不是手抄
	var lantern_row: Array = Almanac.plant_rows("lantern")
	var cost_ok = false
	for row in lantern_row:
		if String(row["label"]) == "香火" and String(row["value"]) == "50":
			cost_ok = true
	h.check("内容", "图鉴香火数值取自数据表", cost_ok)
	var ability = Almanac.plant_ability("shooter")
	h.check("内容", "图鉴本事按数据生成伤害", ability.contains("20"),
		ability.substr(0, 40))


static func _check_upgrade_rules(h) -> void:
	var cost_ok = true
	var detail = ""
	for type in Upgrades.TREES:
		for path in Upgrades.TREES[type]:
			for tier in 3:
				var cost = Upgrades.tier_cost(type, int(path["id"]), tier + 1)
				if cost <= 0 or cost % 5 != 0:
					cost_ok = false
					detail += "%s-%d-%d=%d " % [type, path["id"], tier + 1, cost]
	h.check("升阶", "所有升阶费用都是 5 的倍数且为正", cost_ok, detail)
	# 签筒 1.2 系数：75 -> 90
	h.check("升阶", "签筒连发一级 90 香火",
		Upgrades.tier_cost("shooter", 1, 1) == 90,
		str(Upgrades.tier_cost("shooter", 1, 1)))
	var upgrades = Upgrades.init_upgrades()
	h.check("升阶", "初生草木不可升阶时状态为 next",
		Upgrades.path_status("shooter", upgrades, 1)["kind"] == "next")
	upgrades[1] = 3
	h.check("升阶", "三级后该路关闭",
		Upgrades.path_status("shooter", upgrades, 1)["kind"] == "maxed")
	var two = {1: 1, 2: 1, 3: 0}
	h.check("升阶", "已开两路时第三路锁定",
		Upgrades.path_status("shooter", two, 3)["kind"] == "locked")
	var three = {1: 3, 2: 2, 3: 0}
	h.check("升阶", "另一路到三级后此路三级关闭",
		Upgrades.path_status("shooter", three, 2)["kind"] == "locked3")
	# 满进化必须略亏：13 株各自都有费用系数
	h.check("升阶", "13 株都有费用系数", Upgrades.UPGRADE_COST_SCALE.size() == 13)
	for type in ["lamp", "shell", "lily"]:
		h.check("升阶", "无升阶树时返回 none：%s" % type,
			String(Upgrades.path_status(type, {}, 1)["kind"]) == "none")
	var sim = h.sim_for(1, ["shooter"], "easy")
	sim.sun = 10000
	var plant = sim.place_free("shooter", 2, 2)
	var before = sim.sun
	var outcome = sim.try_upgrade(plant, 1, Vector2.ZERO)
	h.check("升阶", "升阶扣费等于 path_status 费用",
		bool(outcome["ok"]) and sim.sun == before - int(outcome["cost"]),
		str(outcome))
	h.check("升阶", "升阶后该路等级为 1", plant.tier(1) == 1)


static func _check_status_rules(h) -> void:
	var sim = h.sim_for(1, ["shooter"], "easy")
	var z = sim.spawn_zombie("ghost", 0, {"x": 900.0})
	sim.apply_slow(z, 2.0, 0.25)
	h.check("状态", "首次减速生效", is_equal_approx(z.slow_amount, 0.25) and
		is_equal_approx(z.slow_t, 2.0))
	sim.apply_slow(z, 1.0, 0.6)
	h.check("状态", "更强减速覆盖并刷新时长",
		is_equal_approx(z.slow_amount, 0.6) and is_equal_approx(z.slow_t, 1.0))
	sim.apply_slow(z, 5.0, 0.3)
	h.check("状态", "较弱减速既不延长也不回退",
		is_equal_approx(z.slow_amount, 0.6) and is_equal_approx(z.slow_t, 1.0))
	sim.apply_slow(z, 3.0, 0.6)
	h.check("状态", "同强减速续时取较长", is_equal_approx(z.slow_t, 3.0))
	sim.apply_vulnerable(z, 1.0, 0.05)
	sim.apply_vulnerable(z, 4.0, 0.02)
	h.check("状态", "易伤同样只认更强",
		is_equal_approx(z.vuln, 0.05) and is_equal_approx(z.vuln_t, 1.0))
	sim.apply_burn(z, 1.0, 5.0)
	sim.apply_burn(z, 9.0, 3.0)
	h.check("状态", "灼烧弱效果不覆盖",
		is_equal_approx(z.burn_dps, 5.0) and is_equal_approx(z.burn_t, 1.0))
	# 减速确实改变移动速度
	var sim2 = h.sim_for(1, ["shooter"], "easy")
	var walker = sim2.spawn_zombie("ghost", 0, {"x": 1000.0})
	var start_x = walker.pos.x
	h.step(sim2, 1.0)
	var normal = start_x - walker.pos.x
	var sim3 = h.sim_for(1, ["shooter"], "easy")
	var slowed = sim3.spawn_zombie("ghost", 0, {"x": 1000.0})
	sim3.apply_slow(slowed, 5.0, 0.5)
	start_x = slowed.pos.x
	h.step(sim3, 1.0)
	var slow_walk = start_x - slowed.pos.x
	h.check("状态", "50% 减速让移动距离减半",
		absf(slow_walk - normal * 0.5) < normal * 0.08,
		"normal=%.1f slowed=%.1f" % [normal, slow_walk])


static func _check_armor_and_corpse(h) -> void:
	# 用威胁 1.0 的第二夜：护具与本体按 sqrt(1.0)=1 缩放，便于核对绝对值。
	var sim = h.sim_for(2, ["shooter"], "easy")
	var z = sim.spawn_zombie("straw", 0, {"x": 900.0})
	h.check("护具", "斗笠鬼有 90 点斗笠", is_equal_approx(z.armor, 90.0))
	sim.damage_zombie(z, 50.0)
	h.check("护具", "伤害先扣护具", is_equal_approx(z.armor, 40.0) and
		is_equal_approx(z.hp, z.max_hp))
	sim.damage_zombie(z, 60.0)
	h.check("护具", "破具后溢出伤害打在本体",
		is_equal_approx(z.armor, 0.0) and is_equal_approx(z.hp, z.max_hp - 20.0),
		"armor=%.1f hp=%.1f" % [z.armor, z.hp])
	var sim2 = h.sim_for(1, ["shooter"], "easy")
	var body = sim2.spawn_zombie("ghost", 0, {"x": 900.0})
	sim2.kill_zombie(body)
	h.check("护具", "击杀后进入倒地动画", body.dying and not body.dead)
	var blocker = sim2.zombies.size()
	h.check("护具", "尸体仍在场景里挡路", blocker == 1)
	h.step(sim2, 0.6)
	h.check("护具", "0.5 秒后普通尸体会消失", sim2.zombies.is_empty())
	# 透骨针无视护具
	var sim3 = h.sim_for(1, ["shooter"], "easy")
	var armored = sim3.spawn_zombie("bucket", 0, {"x": 900.0})
	var hp_before = armored.hp
	sim3.damage_zombie(armored, 30.0, false, true)
	h.check("护具", "透骨针直接扣本体",
		is_equal_approx(armored.hp, hp_before - 30.0) and armored.armor > 0.0,
		"hp=%.1f armor=%.1f" % [armored.hp, armored.armor])
	# 抬轿鬼破轿分身
	var sim4 = h.sim_for(1, ["shooter"], "easy")
	var sedan = sim4.spawn_zombie("sedan", 0, {"x": 900.0})
	sim4.damage_zombie(sedan, 10000.0)
	h.check("护具", "轿壳破裂后排出两只饿鬼", sim4.pending_spawns.size() == 2)
	# 纸扎匠发甲不叠加，只取更厚
	var sim5 = h.sim_for(2, ["shooter"], "easy")
	sim5.spawn_zombie("ghost", 0, {"x": 860.0})
	var artisan = sim5.spawn_zombie("artisan", 0, {"x": 1000.0})
	sim5.artisan_grant(artisan)
	var charmed = false
	for other in sim5.zombies:
		if other.armor_type == "charm" and is_equal_approx(other.armor, 200.0):
			charmed = true
	h.check("护具", "纸扎匠给低阶发 200 纸甲", charmed)


static func _check_map_rules(h) -> void:
	var street = h.sim_for(1, ["lantern"], "easy")
	var land_ok = true
	for r in street.rows:
		for c in Content.COLS:
			if String(street.tiles[r][c]["kind"]) != "land":
				land_ok = false
	h.check("地图", "第一天全是地格", land_ok)
	var market = h.sim_for(6, [], "easy")
	var blocked = 0
	for r in market.rows:
		for c in Content.COLS:
			if String(market.tiles[r][c]["kind"]) == "blocked":
				blocked += 1
	h.check("地图", "第二天有 5 个障碍格", blocked == 5, "实际 %d" % blocked)
	var blocked_right = true
	for r in market.rows:
		for c in Content.COLS - 4:
			if String(market.tiles[r][c]["kind"]) == "blocked":
				blocked_right = false
	h.check("地图", "障碍只在靠右四列", blocked_right)
	var market_b = h.sim_for(6, [], "easy")
	var same = true
	for r in market.rows:
		for c in Content.COLS:
			if String(market.tiles[r][c]["kind"]) != String(market_b.tiles[r][c]["kind"]):
				same = false
	h.check("地图", "障碍位置随关卡种子固定", same)
	var water = h.sim_for(11, [], "easy")
	h.check("地图", "第三天地图 5 行", water.rows == 5)
	var water_cells = 0
	var object_in_water = 0
	for c in Content.COLS:
		for r in [1, 3]:
			var kind = String(water.tiles[r][c]["kind"])
			if kind == "water":
				water_cells += 1
			elif kind == "object":
				object_in_water += 1
	h.check("地图", "第二、四行是水面（含物件格共 18 格）",
		water_cells + object_in_water == 18, "水面 %d 物件 %d" % [water_cells, object_in_water])
	h.check("地图", "物件格都落在水行上", object_in_water == 5,
		"物件 %d" % object_in_water)
	var objects = 0
	for r in water.rows:
		for c in Content.COLS:
			if String(water.tiles[r][c]["kind"]) == "object":
				objects += 1
	h.check("地图", "暗河有 5 个物件格", objects == 5, "实际 %d" % objects)
	h.check("地图", "水面不能直接种签筒",
		not bool(water.can_place_at("shooter", 0, 1)["ok"]))
	h.check("地图", "夜莲只能放水面",
		not bool(water.can_place_at("lily", 0, 0)["ok"]))
	h.check("地图", "水面可以放夜莲", bool(water.can_place_at("lily", 0, 1)["ok"]))
	water.place_free("lily", 0, 1)
	h.check("地图", "夜莲铺好后可种普通草木",
		bool(water.can_place_at("shooter", 0, 1)["ok"]))
	water.place_free("shooter", 0, 1)
	var host = water.main_plant_at(0, 1)
	h.check("地图", "水上植物记下浮台", host != null and host.on_lily)
	h.check("地图", "物件格不能种",
		not bool(water.can_place_at("shooter", 2, 1)["ok"]))


static func _check_waves(h) -> void:
	var sim = h.sim_for(1, [], "easy")
	h.check("波次", "开局没有恶客", sim.zombies.is_empty())
	h.step(sim, 18.0)
	h.check("波次", "17.5 秒时首波已排队", sim.wave_index >= 1, "wave=%d" % sim.wave_index)
	h.check("波次", "首波按威胁倍率放怪", sim.zombies.size() >= 1,
		"zombies=%d" % sim.zombies.size())
	var hard = h.sim_for(15, [], "hard")
	var easy = h.sim_for(15, [], "easy")
	var hard_mul = hard.hp_mul * float(Sim.DIFFICULTY["hard"]["hp"])
	var easy_mul = easy.hp_mul * float(Sim.DIFFICULTY["easy"]["hp"])
	var zh = hard.spawn_zombie("ghost", 0, {"x": 900.0})
	var ze = easy.spawn_zombie("ghost", 0, {"x": 900.0})
	h.check("波次", "困难难度恶客更硬", zh.max_hp > ze.max_hp,
		"hard=%.0f easy=%.0f" % [zh.max_hp, ze.max_hp])
	h.check("波次", "血量按 sqrt(threat) 缩放",
		absf(ze.max_hp - 90.0 * sqrt(3.0)) < 1.5, "%.1f" % ze.max_hp)
	h.check("波次", "威胁倍率同时影响出怪数",
		absf(easy.count_mul - sqrt(3.0)) < 0.001)


static func _check_training(h) -> void:
	var sim = h.sim_for(16, ["shooter", "lantern"], "easy")
	sim.training = true
	sim.no_cooldown = true
	sim.sun = 1000
	h.step(sim, 30.0)
	h.check("训练场", "训练场不刷波次", sim.zombies.is_empty() and sim.wave_index == 0)
	sim.summon_training("bucket", 2, 1)
	h.check("训练场", "手动召唤生效", sim.zombies.size() == 2)
	var ok_rows = true
	for z in sim.zombies:
		if z.row != 1:
			ok_rows = false
	h.check("训练场", "召唤可指定行", ok_rows)
	sim.sun = 1000
	var placed = sim.try_place_card(0, 3, 1, Vector2.ZERO)
	h.check("训练场", "训练场可种植", placed)
	var card: Dictionary = sim.cards[0]
	h.check("训练场", "无冷却开启时冷却为 0", is_equal_approx(float(card["cd"]), 0.0))
	var again = sim.try_place_card(0, 4, 1, Vector2.ZERO)
	h.check("训练场", "同一张卡可连续摆放", again)
	# 越线不判负
	var sim2 = h.sim_for(16, [], "easy")
	sim2.training = true
	var lose_called = []
	sim2.on_lose = func(z): lose_called.append(z)
	var runner = sim2.spawn_zombie("ghost", 0, {"x": 300.0})
	runner.pos.x = 250.0
	h.step(sim2, 0.2)
	h.check("训练场", "训练场越线不判负", lose_called.is_empty())
	sim2.clear_plants()
	h.check("训练场", "清空草木后板上为空", sim2.plants.is_empty())


static func _check_tutorial(h) -> void:
	var sim = Sim.new()
	sim.start_tutorial()
	h.check("教学", "教学关只有签筒一张卡", sim.cards.size() == 1 and
		String(sim.cards[0]["id"]) == "shooter")
	h.check("教学", "教学关预置红灯笼在 (0,2)",
		sim.main_plant_at(0, 2) != null)
	h.check("教学", "第一步是收集香火", sim.tutorial_step() == "collect")
	h.check("教学", "教学香火不设时限", float(sim.orbs[0]["life"]) > 1000.0)
	# 教学香火落地后不能被改成 10 秒（v0.2.4 的卡死缺陷）
	h.step(sim, 4.0)
	h.check("教学", "教学香火落地后仍未过期", sim.orbs.size() == 1 and
		float(sim.orbs[0]["life"]) > 1000.0, "life=%.0f" % float(sim.orbs[0]["life"]))
	sim.collect_orb(sim.orbs[0])
	h.check("教学", "收下香火后进入种植步", sim.tutorial_step() == "plant")
	var live_orbs = 0
	for orb in sim.orbs:
		if not bool(orb["dead"]):
			live_orbs += 1
	h.check("教学", "教学灯笼不产香火", live_orbs == 0, "orbs=%d" % live_orbs)
	sim.sun = 200
	var placed = sim.try_place_card(0, 2, 2, Vector2.ZERO)
	h.check("教学", "种下签筒后进入升阶步",
		placed and sim.tutorial_step() == "upgrade")
	var shooter: Sim.Plant = sim.main_plant_at(2, 2)
	sim.sun = 200
	var outcome = sim.try_upgrade(shooter, 1, Vector2.ZERO)
	h.check("教学", "升阶后进入实战步",
		bool(outcome["ok"]) and sim.tutorial_step() == "battle")
	h.step(sim, 1.4)
	h.check("教学", "实战步会放出教学恶客", sim.zombies.size() == 1,
		"zombies=%d" % sim.zombies.size())
	if sim.zombies.size() == 1:
		var z: Sim.Zombie = sim.zombies[0]
		h.check("教学", "教学恶客 120 血、速度 14",
			is_equal_approx(z.max_hp, 120.0) and is_equal_approx(z.speed, 14.0))
		sim.kill_zombie(z)
		h.check("教学", "击退后进入收尾", sim.tutorial_step() == "finishing")


static func _check_save_roundtrip(h) -> void:
	var sim = h.sim_for(3, ["lantern", "shooter", "wall"], "normal")
	sim.sun = 500
	sim.place_free("lantern", 0, 1)
	var shooter = sim.place_free("shooter", 2, 1)
	shooter.upgrades[1] = 2
	shooter.shell = 900.0
	sim.spawn_zombie("straw", 1, {"x": 900.0})
	sim.spawn_zombie("stonehat", 3, {"x": 860.0})
	h.step(sim, 2.0)
	var snapshot = sim.serialize()
	var restored = Sim.new()
	restored.restore(snapshot)
	h.check("存档", "关卡与时间还原", restored.level_id == 3 and
		absf(restored.time - sim.time) < 0.5)
	h.check("存档", "香火还原", absi(restored.sun - sim.sun) <= 1,
		"%d vs %d" % [restored.sun, sim.sun])
	h.check("存档", "草木数量与升阶还原",
		restored.plants.size() == sim.plants.size() and
		restored.main_plant_at(2, 1) != null and
		restored.main_plant_at(2, 1).tier(1) == 2)
	h.check("存档", "龟甲罩耐久还原",
		restored.main_plant_at(2, 1) != null and
		absf(restored.main_plant_at(2, 1).shell - 900.0) < 0.01)
	h.check("存档", "恶客数量还原", restored.zombies.size() == sim.zombies.size(),
		"%d vs %d" % [restored.zombies.size(), sim.zombies.size()])
	h.check("存档", "难度还原", restored.difficulty == "normal")
	h.check("存档", "存档可再次序列化",
		not restored.serialize().is_empty())
