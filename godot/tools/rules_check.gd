## 逻辑检查集合：内容表 / 升阶约束 / 状态不叠加 / 护具与尸体 / 三天地图 /
## 波次与威胁倍率 / 训练场 / 教学关 / 存档快照。由 tools/qa_logic.gd 调用。
class_name RulesCheck
extends RefCounted


static func run_all(harness) -> void:
	_check_content(harness)
	_check_upgrade_rules(harness)
	_check_new_mechanics(harness)
	_check_status_rules(harness)
	_check_armor_and_corpse(harness)
	_check_map_rules(harness)
	_check_music(harness)
	_check_waves(harness)
	_check_wave_rounding(harness)
	_check_training(harness)
	_check_bell(harness)
	_check_censer(harness)
	_check_umbrella(harness)
	_check_lion(harness)
	_check_cat(harness)
	_check_torch(harness)
	_check_needle(harness)
	_check_judge(harness)
	_check_new_cards(harness)
	_check_lobber(harness)
	_check_star(harness)
	_check_control_ledger(harness)
	_check_tutorial(harness)
	_check_save_roundtrip(harness)
	_check_ledger(harness)


static func _check_content(h) -> void:
	h.check("内容", "20 种草木齐备", Content.PLANTS.size() == 20,
		"实际 %d" % Content.PLANTS.size())
	h.check("内容", "13 种恶客齐备", Content.ZOMBIES.size() == 13,
		"实际 %d" % Content.ZOMBIES.size())
	h.check("内容", "十五夜与特殊关齐备", Content.LEVELS.size() == 16 and Content.get_level(16).get("special",false),
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
	# 每天各自的威胁区间：0.8—2.0 / 1.0—2.5 / 1.2—3.0，五夜等距
	var ranges = [[0.8, 1.6], [1.0, 2.0], [1.2, 2.5]]
	var range_ok = true
	var range_detail = ""
	for day in 3:
		var levels = []
		for level in Content.LEVELS:
			if int(level["day"]) == day + 1 and not bool(level.get("special",false)):
				levels.append(float(level["threat"]))
		levels.sort()
		if levels.size() != 5:
			range_ok = false
			range_detail += "day%d 夜数=%d " % [day + 1, levels.size()]
			continue
		if not is_equal_approx(levels[0], ranges[day][0]) \
				or not is_equal_approx(levels[4], ranges[day][1]):
			range_ok = false
			range_detail += "day%d %.2f-%.2f " % [day + 1, levels[0], levels[4]]
		for i in range(1, 5):
			if levels[i] <= levels[i - 1]:
				range_ok = false
				range_detail += "day%d 非递增 " % [day + 1]
	h.check("内容", "威胁按天落在 0.8-1.6 / 1.0-2.0 / 1.2-2.5", range_ok, range_detail)
	h.check("内容", "十五夜威胁都单调递增",
		Content.LEVELS[0]["threat"] < Content.LEVELS[4]["threat"]
		and Content.LEVELS[5]["threat"] < Content.LEVELS[9]["threat"]
		and Content.LEVELS[10]["threat"] < Content.LEVELS[14]["threat"])
	h.check("内容", "首波在 17.5 秒", is_equal_approx(
		float(Content.LEVELS[0]["waves"][0]["t"]), 17.5))
	h.check("内容", "波次间隔 18 秒", is_equal_approx(
		float(Content.LEVELS[0]["waves"][1]["t"]) - float(Content.LEVELS[0]["waves"][0]["t"]),
		16.5))
	h.check("内容", "每关 12 小波", Content.LEVELS[0]["waves"].size() == 12)
	h.check("内容", "12 小波归成 4 大波", Content.wave_groups(Content.LEVELS[0]) == 4,
		str(Content.wave_groups(Content.LEVELS[0])))
	h.check("内容", "第 4 小波属于第 1 大波",
		Content.wave_group_of(Content.LEVELS[0], 3) == 1)
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
	h.check("内容", "图鉴 31 篇文案齐全", text_ok)
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
	# 本轮大改数值与路名后，图鉴必须每株都还能生成（缺键会在日志里留下 SCRIPT ERROR）
	var almanac_bad = ""
	for id in Content.PLANT_ORDER:
		if String(Almanac.plant_ability(id)).length() < 24:
			almanac_bad += "%s 本事空 " % id
		if Almanac.plant_rows(id).is_empty():
			almanac_bad += "%s 数值行空 " % id
		if Almanac.plant_pitch(id).length() < 12:
			almanac_bad += "%s 定位一句空 " % id
	h.check("内容", "18 株图鉴都能按新数据生成", almanac_bad == "", almanac_bad)
	# 图鉴开头的定位句：也是从白板行现取，不另抄一份数字
	h.check("内容", "定位一句抄的是白板数",
		Almanac.plant_pitch("cat").contains("尾火伤害 24"), Almanac.plant_pitch("cat"))
	# 推荐配卡表：三张表都要排满 18 株，否则「最不该带的」判不出来
	var tips_bad = ""
	for map in ["street", "market", "water"]:
		var tips: Array = Content.loadout_tips(map)
		var seen := {}
		if tips.size() != Content.PLANT_ORDER.size():
			tips_bad += "%s 张数 %d " % [map, tips.size()]
		for type in tips:
			if not Content.PLANTS.has(type):
				tips_bad += "%s 有不存在的 %s " % [map, type]
			if seen.has(type):
				tips_bad += "%s 重复 %s " % [map, type]
			seen[type] = true
	h.check("内容", "三张推荐表都排满 18 株", tips_bad == "", tips_bad)
	h.check("内容", "暗河的推荐先带夜莲",
		String(Content.loadout_tips("water")[0]) == "lily"
		and Content.tip_rank("water", "nope") == 999,
		str(Content.loadout_tips("water")[0]))


static func _check_upgrade_rules(h) -> void:
	var cost_ok = true
	var detail = ""
	var tree_ok = true
	for type in Upgrades.TREES:
		var paths: Array = Upgrades.TREES[type]
		if paths.size() != 3:
			tree_ok = false
			detail += "%s 不是三路 " % type
		for path in paths:
			var last = 0
			for tier in 3:
				var cost = Upgrades.tier_cost(type, int(path["id"]), tier + 1)
				# 费用一律 25 的整数倍，且同一条路严格递增（修订 v2 定下的规矩）
				if cost <= 0 or cost % 25 != 0 or cost <= last:
					cost_ok = false
					detail += "%s-%d-%d=%d " % [type, path["id"], tier + 1, cost]
				last = cost
	h.check("升阶", "所有升阶费用都是 25 的倍数且逐阶递增", cost_ok, detail)
	h.check("升阶", "14 株都是三路三阶", tree_ok and Upgrades.TREES.size() == 14, detail)
	h.check("升阶", "签筒连发一级 100 香火",
		Upgrades.tier_cost("shooter", 1, 1) == 100,
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
	# 白板数值只写一处。批复后的新树里 EFFECTS 的第 0 档可以是 0，意思是「这一档不改白板」，
	# 那种键不进这张对照表；仍然两处都写了数值的，必须对得上。
	var drift = ""
	var white = [
		["lantern", "value", 25.0, "produce", "value"],
		["lantern", "interval", 8.0, "produce", "interval"],
		["needle", "interval", 1.7, "needle", "interval"],
	]
	for row in white:
		var values: Variant = Upgrades.EFFECTS[row[0]][row[1]]
		var got = float(values[0]) if values is Array else float(values)
		var want = float(Content.PLANTS[row[0]][row[3]][row[4]])
		if not is_equal_approx(got, want):
			drift += "%s.%s=%s!=%s " % [row[0], row[1], got, want]

	if not is_equal_approx(float(Content.PLANTS["shooter"]["shot"]["interval"]), 1.4) \
			or int(Content.PLANTS["shooter"]["shot"]["damage"]) != 20:
		drift += "shooter.whiteboard "
	h.check("升阶", "白板数值在 content 与 upgrades 两处一致", drift == "", drift)
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
	# 用威胁正好 1.0 的第六夜（第二天第一夜）：护具与本体按 sqrt(1.0)=1 缩放。
	var sim = h.sim_for(6, ["shooter"], "easy")
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
	var sedan = sim4.spawn_zombie("sedan", 0, {"x": 900.0, "sedan_bride": false})
	sim4.damage_zombie(sedan, 10000.0)
	h.check("护具", "轿壳破裂后排出两只饿鬼", sim4.pending_spawns.size() == 2)
	# 纸扎匠发甲不叠加，只取更厚
	var sim5 = h.sim_for(6, ["shooter"], "easy")
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


static func _check_music(h) -> void:
	# 两份风格：朴素=通用三套；完整=按天取 dayN 三套（缺曲目退回通用）
	h.check("音乐", "朴素风格始终用通用配乐",
		h.resolve_track("plain", 1, "battle") == "battle"
		and h.resolve_track("plain", 3, "final") == "final")
	h.check("音乐", "完整风格第一天用 day1",
		h.resolve_track("complete", 1, "battle") == "day1-battle"
		and h.resolve_track("complete", 1, "final") == "day1-final")
	h.check("音乐", "完整风格第三天用 day3",
		h.resolve_track("complete", 3, "hot") == "day3-hot")
	h.check("音乐", "没有当天曲目时退回通用",
		h.resolve_track("complete", 1, "battle", false) == "battle")
	h.check("音乐", "菜单曲两种风格共用",
		h.music_menu_track() == "menu")
	h.check("音乐", "十六首配乐都在资源里",
		h.music_assets_present() == 16, str(h.music_assets_present()))
	h.check("音乐", "白热化默认用新篇",
		h.resolve_track("complete", 2, "hot", true, "new") == "day2-hot")
	h.check("音乐", "选延续时用当天 hot-alt",
		h.resolve_track("complete", 2, "hot", true, "continue") == "day2-hot-alt")
	h.check("音乐", "延续缺曲时退回新篇",
		h.resolve_track("complete", 3, "hot", true, "continue", false)
		== "day3-hot")
	h.check("音乐", "朴素风格不受新篇/延续影响",
		h.resolve_track("plain", 1, "hot", true, "continue") == "hot")


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
	# 暗河按 +0.15 等效威胁出怪（显示值不变），所以缩放基准取等效威胁
	var eff = Sim.effective_threat(Content.get_level(15))
	h.check("波次", "血量按 sqrt(等效威胁) 缩放",
		absf(ze.max_hp - 90.0 * sqrt(eff)) < 1.5, "%.1f" % ze.max_hp)
	h.check("波次", "威胁倍率同时影响出怪数",
		absf(easy.count_mul - sqrt(eff)) < 0.001)
	h.check("波次", "新难度区间为实际系数，暗河不另加码",
		is_equal_approx(eff, 2.5) and is_equal_approx(
			Sim.effective_threat(Content.get_level(1)), 0.8),
		"water=%.2f street=%.2f" % [eff, Sim.effective_threat(Content.get_level(1))])
	# 三夜样板：题签点了哪种恶客，这一夜就得真的会出那种恶客
	var theme_bad = ""
	var themed = 0
	for level in Content.LEVELS.slice(0,15):
		var type := String(level.get("theme_zombie", ""))
		var text := String(level.get("theme", ""))
		if text == "":
			if type != "":
				theme_bad += "夜%d 有怪没题 " % int(level["id"])
			continue
		themed += 1
		if type == "":
			if String(level["map"]) != "water":
				theme_bad += "夜%d 题没怪又不是水路 " % int(level["id"])
			continue
		var found = false
		for wave in level["waves"]:
			for group in wave["groups"]:
				if String(group[0]) == type:
					found = true
		if not found:
			theme_bad += "夜%d 题签写了 %s 但这夜不出 " % [int(level["id"]), type]
	h.check("波次", "三夜样板各只突出一个问题", themed == 3 and theme_bad == "",
		"nights=%d %s" % [themed, theme_bad])


## 出怪的随机取整：√威胁跨过 1.5 时，旧的逐组 round 会让每一组单只都整组翻倍，
## 难度曲线因此出现台阶。现在按期望值随机取整，同一组应当一半 1 只、一半 2 只。
static func _check_wave_rounding(h) -> void:
	var sim = h.sim_for(13, [], "easy")
	var one = 0
	var two = 0
	for i in 200:
		sim.rng.seed = 1000 + i
		sim.spawn_queue.clear()
		sim.queue_wave({"groups": [["ghost", 1]], "flag": false}, 0)
		if sim.spawn_queue.size() == 1:
			one += 1
		elif sim.spawn_queue.size() == 2:
			two += 1
	h.check("波次", "出怪数随机取整，1 只的组不整组翻倍",
		one + two == 200 and one > 60 and two > 60, "one=%d two=%d" % [one, two])


static func _check_training(h) -> void:
	var sim = h.sim_for(1, ["shooter", "lantern"], "easy")
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
	var sim2 = h.sim_for(1, [], "easy")
	sim2.training = true
	var lose_called = []
	sim2.on_lose = func(z): lose_called.append(z)
	var runner = sim2.spawn_zombie("ghost", 0, {"x": 300.0})
	runner.pos.x = 250.0
	h.step(sim2, 0.2)
	h.check("训练场", "训练场越线不判负", lose_called.is_empty())
	sim2.clear_plants()
	h.check("训练场", "清空草木后板上为空", sim2.plants.is_empty())



## 批复 §3 的两本账：共享控制与位移。这两本是后面十株所有新控制的前提，
## 先单独测清楚，不等各株机制把它们带出来再补。
## 醒狮（批复版）：嘴里存什么／撞完站在哪／倒下前还能为别人做什么。
static func _check_lion(h) -> void:
	var sim = h.sim_for(6, ["lion"], "easy")
	var lion = sim.place_free("lion", 4, 2)
	lion.upgrades = {1: 1, 2: 0, 3: 0}
	var victim = sim.spawn_zombie("stonehat", 2, {"x": lion.pos.x + 60.0})
	victim.max_hp = 4000.0
	victim.hp = 4000.0
	for i in 40:
		lion.timer = 1.49
		sim._update_lion(lion, 0.02)
		if victim.pos.x > lion.pos.x + 61.0:
			break
	h.check("醒狮", "叼：把非大型多摔回一格", victim.pos.x > lion.pos.x + 60.0,
		"dx=%.0f" % (victim.pos.x - lion.pos.x))
	h.check("醒狮", "同一名四秒内不重复被摔", victim.throw_until > sim.time)
	var sim2 = h.sim_for(6, ["lion"], "easy")
	var brute = sim2.place_free("lion", 4, 2)
	brute.upgrades = {1: 2, 2: 0, 3: 0}
	var bite = float(Content.PLANTS["lion"]["melee"]["damage"])
	var surely = 0
	for i in 12:
		var clad = sim2.spawn_zombie("bucket", 2, {"x": brute.pos.x + 60.0})
		clad.max_hp = 8000.0
		clad.hp = 8000.0
		var armor_before = clad.armor
		var hp_before = clad.hp
		var x_before = clad.pos.x
		brute.timer = 1.49
		sim2._update_lion(brute, 0.02)
		var strip = armor_before - clad.armor - bite
		if absf(strip - 100.0) < 0.001 and hp_before - clad.hp <= 0.001 \
				and clad.pos.x > x_before + 30.0:
			surely += 1
		clad.dying = true
	h.check("醒狮", "砸甲：对带护具的非大型十二次全部必摔、剥 100 护具且不溢出本体",
		surely == 12, "命中 %d/12" % surely)
	var sim3 = h.sim_for(6, ["lion"], "easy")
	var charger = sim3.place_free("lion", 4, 2)
	charger.upgrades = {1: 3, 2: 0, 3: 0}
	var snack = sim3.spawn_zombie("ghost", 2, {"x": charger.pos.x + 60.0})
	snack.hp = 20.0
	charger.timer = 1.49
	sim3._update_lion(charger, 0.02)
	h.check("醒狮", "吞煞：直接击杀才把本体伤害存进狮头",
		charger.lion_charge > 0.0, "charge=%.0f" % charger.lion_charge)
	var next = sim3.spawn_zombie("ghost", 2, {"x": charger.pos.x + 60.0})
	next.max_hp = 4000.0
	next.hp = 4000.0
	charger.timer = 1.49
	sim3._update_lion(charger, 0.02)
	h.check("醒狮", "吞煞：下一次撞头把存下的煞一并放出并清空",
		4000.0 - next.hp >= 70.0 and 4000.0 - next.hp < 95.0 and charger.lion_charge <= 0.0,
		"掉血=%.0f charge=%.0f" % [4000.0 - next.hp, charger.lion_charge])
	var sim4 = h.sim_for(6, ["lion"], "easy")
	var runner = sim4.place_free("lion", 1, 2)
	var at_three = sim4.spawn_zombie("ghost", 2, {"x": runner.pos.x + 2.8 * Geo.CELL_W})
	at_three.hp = 4000.0
	var beyond = sim4.spawn_zombie("ghost", 2, {"x": runner.pos.x + 6.0 * Geo.CELL_W})
	beyond.hp = 4000.0
	runner.upgrades = {1: 0, 2: 1, 3: 0}
	runner.timer = 1.49
	sim4._update_lion(runner, 0.02)
	h.check("醒狮", "远跃：本行三格可攻击，远程冲击动画已触发",
		at_three.hp < 4000.0 and beyond.hp == 4000.0 and runner.lion_wave_t > 0.0)
	runner.upgrades = {1: 0, 2: 2, 3: 0}
	at_three.dying = true
	runner.timer = 1.49
	sim4._update_lion(runner, 0.02)
	h.check("醒狮", "通街：本行远处恶客进入射程", beyond.hp < 4000.0)
	at_three.dying = false
	var cross = sim4.spawn_zombie("ghost", 1, {"x": runner.pos.x + 70.0})
	cross.hp = 4000.0
	runner.upgrades = {1: 0, 2: 3, 3: 0}
	runner.timer = 1.86
	var near_before = at_three.hp
	var far_before = beyond.hp
	sim4._update_lion(runner, 0.02)
	h.check("醒狮", "满街狮吼：本行所有恶客同时受击，隔行不受击",
		at_three.hp < near_before and beyond.hp < far_before and cross.hp == 4000.0)
	runner.timer = 1.5
	var unchanged = at_three.hp
	sim4._update_lion(runner, 0.02)
	h.check("醒狮", "满街狮吼：攻速降低20%", at_three.hp == unchanged)
	var sim5 = h.sim_for(6, ["lion"], "easy")
	var healer = sim5.place_free("lion", 4, 2)
	healer.upgrades = {1: 0, 2: 0, 3: 1}
	healer.hp = 400.0
	var food = sim5.spawn_zombie("ghost", 2, {"x": healer.pos.x + 60.0})
	food.max_hp = 4000.0
	food.hp = 4000.0
	healer.timer = 1.49
	sim5._update_lion(healer, 0.02)
	h.check("醒狮", "衔青：命中才回 25 耐久", healer.hp > 400.0 and healer.hp <= 425.001,
		"hp=%.0f" % healer.hp)
	var ally = sim5.place_free("wall", 3, 2)
	var other = sim5.place_free("wall", 3, 1)
	sim5.refresh_plant_buffs()
	var plain_haste = ally.haste
	healer.upgrades = {1: 2, 2: 2, 3: 2}
	food.armor = 100.0
	food.max_armor = 100.0
	healer.timer = 1.49
	sim5._update_lion(healer, 0.02)
	sim5.refresh_plant_buffs()
	h.check("醒狮", "喝彩：把撞退换成同行左右友军的攻速",
		ally.cheer >= 1 and ally.haste > plain_haste,
		"cheer=%d haste=%.2f" % [ally.cheer, ally.haste])
	h.check("醒狮", "喝彩：不传给别行的友军", other != null and int(other.cheer) == 0,
		"cheer=%d" % (0 if other == null else int(other.cheer)))
	var sim6 = h.sim_for(6, ["lion"], "easy")
	var dancer = sim6.place_free("lion", 4, 2)
	dancer.upgrades = {1: 0, 2: 0, 3: 3}
	dancer.hp = 5.0
	sim6.damage_plant(dancer, 500.0)
	h.check("醒狮", "最后一舞：致命一击没让它当场倒下",
		not dancer.dead and dancer.dance_t > 0.0, "dance=%.2f" % dancer.dance_t)
	for i in 220:
		sim6.update_plants(1.0 / 60.0)
	h.check("醒狮", "最后一舞：三秒到就强制退场", dancer.dance_t <= 0.0,
		"dance=%.2f" % dancer.dance_t)


## 把一只狐尾灯的整轮尾火放到落地为止，中间的弹全部清空，方便按「轮」断言。
## forced 不为空时直接对这一个人开火，免得挑目标的规则搅浑绕圈与记号的账。
static func _cat_land(sim, cat, volleys: int, forced = null) -> void:
	for v in volleys:
		cat.timer = 1.59
		if forced == null:
			sim._update_cat(cat, 0.02)
		else:
			sim.fire_cat(cat, forced)
		var guard = 0
		while guard < 600:
			sim.update_shots(1.0 / 60.0)
			guard += 1
			var remaining = 0
			for s in sim.shots:
				if not s.dead:
					remaining += 1
			if remaining == 0:
				break
		sim.shots.clear()


## 在同一行摆出绕圈路线会扫到的位置：圆心左右各一个半径、外加圆心本身。
static func _cat_ring(sim, center_x: float, radius: float) -> Array:
	var out: Array = []
	for dx in [-radius, radius, 0.0]:
		var z = sim.spawn_zombie("ghost", 2, {"x": center_x + dx})
		z.max_hp = 9000.0
		z.hp = 9000.0
		out.append(z)
	return out


static func _cat_grazed(sim, main) -> int:
	var n = 0
	for z in sim.zombies:
		if z != main and z.hp < 8999.0:
			n += 1
	return n


## 狐尾灯（批复版）：绕不绕／挑谁打／留下什么记号。白板 24 伤 1.6 秒只写在 content 一处。
static func _check_cat(h) -> void:
	var home: Dictionary = Content.PLANTS["cat"]["homing"]
	h.check("狐尾灯", "白板 24 伤 / 1.6 秒只留在 content，EFFECTS 不再抄一份",
		is_equal_approx(float(home["damage"]), 24.0)
		and is_equal_approx(float(home["interval"]), 1.6)
		and not Upgrades.EFFECTS["cat"].has("damage")
		and not Upgrades.EFFECTS["cat"].has("interval"), str(home))

	var fx: Dictionary = Upgrades.EFFECTS["cat"]
	for tier in [1, 2, 3]:
		var sim = h.sim_for(6, ["cat"], "easy")
		var cat = sim.place_free("cat", 2, 2)
		cat.upgrades = {1: tier, 2: 0, 3: 0}
		var prey = sim.spawn_zombie("ghost", 2, {"x": 640.0})
		prey.hp = 9000.0
		cat.timer = float(home["interval"]) - float(fx["interval_reduction"][tier]) - 0.01
		sim._update_cat(cat, 0.02)
		h.check("狐尾灯", "疾焰第 %d 阶：间隔缩短 %.1f 秒" % [tier,
			float(fx["interval_reduction"][tier])], sim.shots.size() >= 1)
	var burst_sim = h.sim_for(6, ["cat"], "easy")
	var burst_cat = burst_sim.place_free("cat", 2, 2)
	burst_cat.upgrades = {1: 3, 2: 0, 3: 0}
	var burst_target = burst_sim.spawn_zombie("ghost", 2, {"x": 640.0})
	var proc = false
	for attempt in 1000:
		burst_sim.shots.clear()
		burst_sim.fire_cat(burst_cat, burst_target)
		if burst_sim.shots.size() == 10:
			proc = true
			break
	h.check("狐尾灯", "十焰：触发时连续放出10团", proc)
	burst_sim.shots.clear()
	burst_sim.fire_cat(burst_cat, burst_target)
	h.check("狐尾灯", "十焰：同六秒窗口不可再次触发",
		burst_sim.shots.size() == 1 and burst_cat.ten_flames_ready_at > burst_sim.time)

	# 尾数（2-1／2-2）：一轮放几团、每团多重，各追一个目标
	var sim4 = h.sim_for(6, ["cat"], "easy")
	var hunter = sim4.place_free("cat", 2, 2)
	for i in 4:
		var z = sim4.spawn_zombie("ghost", 2, {"x": hunter.pos.x + 140.0 + i * 90.0})
		z.max_hp = 9000.0
		z.hp = 9000.0
	hunter.timer = 1.59
	sim4._update_cat(hunter, 0.02)
	h.check("狐尾灯", "白板：一次只放一团 24 伤",
		sim4.shots.size() == 1 and is_equal_approx(float(sim4.shots[0].damage), 24.0),
		"%d 团 dmg=%.1f" % [sim4.shots.size(), sim4.shots[0].damage])
	sim4.shots.clear()
	hunter.upgrades = {1: 0, 2: 1, 3: 0}
	hunter.timer = 1.59
	sim4._update_cat(hunter, 0.02)
	h.check("狐尾灯", "双尾：一次两团、各追一个、每团仍是白板 24",
		sim4.shots.size() == 2 and sim4.shots[0].target != sim4.shots[1].target
		and is_equal_approx(float(sim4.shots[0].damage), 24.0),
		"%d 团" % sim4.shots.size())
	sim4.shots.clear()
	hunter.upgrades = {1: 0, 2: 2, 3: 0}
	hunter.timer = 1.59
	sim4._update_cat(hunter, 0.02)
	var three = sim4.shots.size() == 3
	for s2 in sim4.shots:
		if not is_equal_approx(float(s2.damage), 30.0):
			three = false
	h.check("狐尾灯", "三尾：三团各吃 30", three, "%d 团" % sim4.shots.size())

	# 回魂命中仍活着的目标后继续追另一名，且升级后初发四团。
	var sim5 = h.sim_for(6, ["cat"], "easy")
	var reaver = sim5.place_free("cat", 2, 2)
	reaver.upgrades = {1: 0, 2: 3, 3: 0}
	var first = sim5.spawn_zombie("ghost", 2, {"x": 520.0})
	first.max_hp = 5000.0
	first.hp = 5000.0
	var second = sim5.spawn_zombie("ghost", 2, {"x": 900.0})
	second.max_hp = 5000.0
	second.hp = 5000.0
	reaver.timer = 1.59
	sim5._update_cat(reaver, 0.02)
	h.check("狐尾灯", "回魂：升到2-3时一轮放出四团",
		sim5.shots.size() == 4 and int(sim5.shots[0].hits_left) == 2)
	for i in 420:
		sim5.update_shots(1.0 / 60.0)
	h.check("狐尾灯", "回魂：无需击杀首名即可追击另一名",
		first.alive() and first.hp < 5000.0 and second.hp < 5000.0)

	# 狐记（3-1）：主尾火命中留一层，友军打它 +5%、3.2 秒
	var sim8 = h.sim_for(6, ["cat"], "easy")
	var marker = sim8.place_free("cat", 2, 2)
	marker.upgrades = {1: 0, 2: 0, 3: 1}
	var marked = sim8.spawn_zombie("ghost", 2, {"x": 560.0})
	marked.max_hp = 9000.0
	marked.hp = 9000.0
	_cat_land(sim8, marker, 1, marked)
	h.check("狐尾灯", "狐记：命中留一层记号，易伤 5%、3.2 秒",
		sim8.mark_stacks(marked, "fox") == 1 and is_equal_approx(marked.vuln, 0.05)
		and marked.vuln_t > 3.0, "层=%d vuln=%.2f t=%.2f" % [
			sim8.mark_stacks(marked, "fox"), marked.vuln, marked.vuln_t])
	marker.upgrades = {1: 0, 2: 0, 3: 2}
	var near = sim8.spawn_zombie("ghost", 2, {"x": 600.0})
	near.max_hp = 9000.0
	near.hp = 9000.0
	_cat_land(sim8, marker, 1, marked)
	h.check("狐尾灯", "点火：第二层当场炸 40，身边一名一起吃，爆炸不留记号",
		9000.0 - near.hp == 40.0 and sim8.mark_stacks(near, "fox") == 0
		and 9000.0 - marked.hp >= 64.0, "near 掉 %.0f 层=%d" % [
			9000.0 - near.hp, sim8.mark_stacks(near, "fox")])
	var hp_after = marked.hp
	_cat_land(sim8, marker, 1, marked)
	h.check("狐尾灯", "点火：同一目标 3.2 秒内只炸一次",
		9000.0 - near.hp == 40.0 and hp_after - marked.hp < 30.0,
		"near 掉 %.0f / marked 又多掉 %.1f" % [9000.0 - near.hp, hp_after - marked.hp])

	# 锁魂（3-3）：三层消耗记号，定身 0.6 秒、2 秒内全队易伤 20%；大型只吃 0.2 秒
	var sim9 = h.sim_for(6, ["cat"], "easy")
	var locker = sim9.place_free("cat", 2, 2)
	locker.upgrades = {1: 0, 2: 0, 3: 3}
	var pinned = sim9.spawn_zombie("ghost", 2, {"x": 560.0})
	pinned.max_hp = 9000.0
	pinned.hp = 9000.0
	locker.timer = 1.59
	sim9._update_cat(locker, 0.02)
	var bolt = sim9.shots[0]
	sim9.shots.clear()
	_cat_land(sim9, locker, 2, pinned)
	h.check("狐尾灯", "锁魂：两层时只叠层、还不定身",
		sim9.mark_stacks(pinned, "fox") == 2 and pinned.stun_t <= 0.0,
		"层=%d stun=%.2f" % [sim9.mark_stacks(pinned, "fox"), pinned.stun_t])
	_cat_land(sim9, locker, 1, pinned)
	h.check("狐尾灯", "锁魂：三层把人定住 0.6 秒、易伤顶到 20%、记号消耗",
		pinned.stun_t > 0.5 and is_equal_approx(pinned.vuln, 0.2)
		and sim9.mark_stacks(pinned, "fox") == 0, "stun=%.2f vuln=%.2f 层=%d" % [
			pinned.stun_t, pinned.vuln, sim9.mark_stacks(pinned, "fox")])
	var big = sim9.spawn_zombie("mountain", 2, {"x": 660.0})
	big.max_hp = 9000.0
	big.hp = 9000.0
	sim9.add_mark(big, "fox", 2, 3.2, true, 0.05)
	sim9._cat_mark(big, bolt)
	h.check("狐尾灯", "锁魂：大型只吃 0.2 秒这一档",
		big.stun_t > 0.0 and big.stun_t <= 0.2 + 0.001, "stun=%.2f" % big.stun_t)
	sim9._cat_mark(big, bolt)
	h.check("狐尾灯", "锁魂：同一名 6.4 秒内只结算一次，第二次只重新叠层",
		sim9.mark_stacks(big, "fox") == 1 and big.lock_until > sim9.time,
		"层=%d until=%.1f t=%.1f" % [sim9.mark_stacks(big, "fox"), big.lock_until, sim9.time])

## 打一发签筒的过火弹：开火后一路推进，直到它穿过火盆为止。
static func _torch_pea(sim, gun, frames: int = 240):
	sim.shots.clear()
	sim.grounds.clear()
	gun.timer = 1.45
	sim._update_shooter(gun, 0.02)
	if sim.shots.is_empty():
		return null
	var bolt = sim.shots[0]
	for i in frames:
		sim.update_shots(1.0 / 60.0)
		if bolt.dead or bolt.torch_buff > 0.0:
			return bolt
	return bolt


## 炭火盆（批复版）：火色管弹（灼烧／掉星／穿甲），余烬那条路保持原样，火胎管盆自己。
static func _check_torch(h) -> void:
	var base: Dictionary = Content.PLANTS["torch"]["torch"]
	var fx: Dictionary = Upgrades.EFFECTS["torch"]
	h.check("炭火盆", "白板增幅 50% 在 content 与 upgrades 两处一致",
		is_equal_approx(float(base["buff"]), float(fx["buff"][0])),
		"%s vs %s" % [str(base["buff"]), str(fx["buff"][0])])
	var sim = h.sim_for(6, ["torch", "shooter"], "easy")
	var pot = sim.place_free("torch", 3, 2)
	var gun = sim.place_free("shooter", 1, 2)
	var away = sim.spawn_zombie("ghost", 2, {"x": 980.0})
	away.max_hp = 9000.0
	away.hp = 9000.0
	var plain = _torch_pea(sim, gun)
	h.check("炭火盆", "白板：穿盆只吃 50% 增幅，不带灼烧不掉星",
		plain != null and is_equal_approx(plain.torch_buff, 0.5) and plain.burn <= 0.0
		and is_equal_approx(plain.damage, 30.0) and sim.grounds.is_empty(),
		"buff=%.2f burn=%.1f dmg=%.1f 地效=%d" % [
			plain.torch_buff, plain.burn, plain.damage, sim.grounds.size()])
	var white_speed = plain.speed
	# 火箭（1-1）：灼烧挂在弹上，增幅仍是白板的 50%
	pot.upgrades = {1: 1, 2: 0, 3: 0}
	var rocket = _torch_pea(sim, gun)
	h.check("炭火盆", "火箭：穿盆的弹附带灼烧，伤害增幅80%",
		is_equal_approx(rocket.burn, 5.0) and is_equal_approx(rocket.burn_duration, 2.0)
		and is_equal_approx(rocket.torch_buff, 0.8),
		"burn=%.1f/%.1f buff=%.2f" % [rocket.burn, rocket.burn_duration, rocket.torch_buff])
	# 余烬那条路（待采纳）保持原样：二阶把灼烧提到 9/秒，取最强的一份
	pot.upgrades = {1: 0, 2: 2, 3: 0}
	var ember = _torch_pea(sim, gun)
	h.check("炭火盆", "余烬（未启用的替代案之外）：二阶灼烧 9/秒仍是这一份",
		is_equal_approx(ember.burn, 9.0), "burn=%.1f" % ember.burn)
	pot.upgrades = {1: 1, 2: 1, 3: 0}
	var both = _torch_pea(sim, gun)
	h.check("炭火盆", "两路都有灼烧时只取最强，不相加",
		is_equal_approx(both.burn, 5.0), "burn=%.1f" % both.burn)
	# 掉星（1-2）：一颗弹最多掉两颗，每盆一秒也只攒两颗
	pot.upgrades = {1: 2, 2: 0, 3: 0}
	pot.spark_window = 2.0
	var star = _torch_pea(sim, gun)
	var sparks = 0
	for g in sim.grounds:
		if String(g["kind"]) == "spark":
			sparks += 1
	h.check("炭火盆", "掉星：一颗过盆的弹落两颗火星",
		sparks == 2, "火星=%d 弹=%s" % [sparks, String(star.kind)])
	sim.grounds.clear()
	pot.spark_window = 0.0
	_torch_pea(sim, gun)
	sparks = 0
	for g in sim.grounds:
		if String(g["kind"]) == "spark":
			sparks += 1
	h.check("炭火盆", "掉星：一秒的预算用完就不再掉", sparks == 0, "火星=%d" % sparks)
	sim.grounds.clear()
	for i in 60:
		sim.update_plants(1.0 / 60.0)
	h.check("炭火盆", "掉星：预算每秒攒回两颗",
		pot.spark_window >= 1.999 and pot.spark_window <= 2.001,
		"window=%.2f" % pot.spark_window)
	# 火星是地火，扣的是护具，不跟着满阶穿甲
	var clad = sim.spawn_zombie("bucket", 2, {"x": pot.pos.x + 90.0})
	clad.max_hp = 9000.0
	clad.hp = 9000.0
	pot.spark_window = 4.0
	_torch_pea(sim, gun)
	var cinder: Variant = null
	for g in sim.grounds:
		if String(g["kind"]) == "spark":
			cinder = g
			break
	if cinder != null:
		clad.pos.x = float(cinder["pos"].x)
	var armor_before = clad.armor
	sim.update_grounds(1.0 / 60.0)
	h.check("炭火盆", "火星只烧 10/秒，走护具不穿本体",
		cinder != null and clad.hp == 9000.0 and armor_before - clad.armor >= 9.999
		and armor_before - clad.armor <= 10.001,
		"扣甲=%.1f hp=%.0f 火星=%s" % [armor_before - clad.armor, clad.hp, str(cinder)])
	# 把这名挪回盆后 3 格，免得下一发弹在半路就撞死在它身上
	clad.pos.x = pot.pos.x + 320.0
	# 不熄（1-3）：+130% 增幅、弹速 +50%，命中周围溅射20%
	pot.upgrades = {1: 3, 2: 0, 3: 0}
	var pierce = _torch_pea(sim, gun)
	h.check("炭火盆", "不熄：增幅 130%%、弹速 +50%%，溅射20%%",
		is_equal_approx(pierce.torch_buff, 1.3) and not pierce.pierce_armor
		and is_equal_approx(pierce.torch_splash_ratio, 0.2)
		and is_equal_approx(pierce.torch_splash_radius, 0.3 * Geo.CELL_W)
		and is_equal_approx(pierce.damage, 46.0) and pierce.speed > white_speed,
		"buff=%.2f dmg=%.1f spd=%.1f/%.1f" % [
			pierce.torch_buff, pierce.damage, pierce.speed, white_speed])
	var shell = sim.spawn_zombie("stonehat", 2, {"x": 900.0})
	shell.max_hp = 9000.0
	shell.hp = 9000.0
	var shell_armor = shell.armor
	sim.damage_zombie(shell, pierce.damage, true, pierce.pierce_armor, "shooter")
	h.check("炭火盆", "不熄主弹全额结算护具，不穿甲",
		is_equal_approx(shell_armor - shell.armor, 46.0) and shell.hp == 9000.0,
		"扣血=%.0f 甲=%.0f" % [9000.0 - shell.hp, shell.armor])

	# 火胎（3 路）：厚胎抬上限并按差值一次补齐，泼油与火墙各自成一摊地火
	var sim2 = h.sim_for(6, ["torch"], "easy")
	var jar = sim2.place_free("torch", 3, 2)
	sim2.apply_hp_scale(jar)
	h.check("炭火盆", "厚胎之前：白板耐久 250",
		is_equal_approx(jar.max_hp, float(Content.PLANTS["torch"]["hp"])),
		"max_hp=%.0f" % jar.max_hp)
	jar.hp = 30.0
	jar.upgrades = {1: 0, 2: 0, 3: 1}
	sim2.apply_hp_scale(jar)
	h.check("炭火盆", "厚胎：上限变 750，升阶只补 450 的差值，不满血复活",
		is_equal_approx(jar.max_hp, 750.0) and is_equal_approx(jar.hp, 480.0),
		"max=%.0f hp=%.0f" % [jar.max_hp, jar.hp])
	jar.upgrades = {1: 0, 2: 0, 3: 2}
	var biter = sim2.spawn_zombie("ghost", 2, {"x": jar.pos.x + 40.0})
	biter.max_hp = 9000.0
	biter.hp = 9000.0
	sim2.grounds.clear()
	sim2.damage_plant(jar, 20.0, biter)
	var oily = 0
	for g in sim2.grounds:
		if String(g["kind"]) == "oil":
			oily += 1
	h.check("炭火盆", "泼油：被啃到就在啃它的敌人脚下一摊油",
		oily == 1 and absf(float(sim2.grounds[0]["pos"].x) - biter.pos.x) < 1.0,
		"油=%d" % oily)
	sim2.grounds.clear()
	sim2.damage_plant(jar, 20.0, biter)
	h.check("炭火盆", "泼油：同一盆 2 秒内只泼一摊", sim2.grounds.is_empty(),
		"%d" % sim2.grounds.size())
	# 反伤与自养：25/秒是合计，脱离啃食 3 秒才开始回
	jar.upgrades = {1: 0, 2: 0, 3: 3}
	sim2.apply_hp_scale(jar)
	h.check("炭火盆", "火胎满阶：反伤仍是每秒 25",
		is_equal_approx(sim2.plant_reflect(jar), 25.0),
		"reflect=%.1f" % sim2.plant_reflect(jar))
	jar.hp = 100.0
	jar.no_bite_t = 0.0
	jar.bite_t = 0.5
	sim2.update_plants(0.1)
	h.check("炭火盆", "火墙：刚被啃过的 3 秒里不回填", jar.hp <= 100.0, "hp=%.1f" % jar.hp)
	jar.bite_t = 0.0
	for i in 200:
		sim2.update_plants(1.0 / 60.0)
	h.check("炭火盆", "火墙：脱离啃食 3 秒后每秒回 40", jar.hp > 100.0, "hp=%.0f" % jar.hp)
	sim2.grounds.clear()
	sim2.kill_plant(jar)
	var walls = 0
	for g in sim2.grounds:
		if String(g["kind"]) == "wall":
			walls += 1
	h.check("炭火盆", "火墙：被啃塌时炸开 1.5 格、每秒 60、烧 3 秒",
		walls == 1 and is_equal_approx(float(sim2.grounds[0]["radius"]),
			1.5 * Geo.CELL_W) and is_equal_approx(float(sim2.grounds[0]["damage"]), 60.0)
		and is_equal_approx(float(sim2.grounds[0]["life"]), 3.0),
		"墙=%d %s" % [walls, str(sim2.grounds)])
	var jar2 = sim2.place_free("torch", 2, 2)
	jar2.upgrades = {1: 0, 2: 0, 3: 3}
	sim2.grounds.clear()
	sim2.shovel_at(2, 2)
	h.check("炭火盆", "铲走的盆不欠这一圈火", sim2.grounds.is_empty(), str(sim2.grounds))

## 放一轮透骨针并让它飞到穿无可穿，返回这一轮的针。
static func _check_needle(h) -> void:
	var sim = h.sim_for(1, ["needle"], "easy")
	var plant = sim.place_free("needle", 0, 2)
	var enemies: Array = []
	for i in 5:
		enemies.append(sim.spawn_zombie("bucket", 2, {"x": plant.pos.x + 80.0 + i * 85.0}))
	for tier in range(4):
		plant.upgrades[1] = tier
		plant.timer = 1.7
		sim._update_needle(plant, 0.0)
		var shot = sim.shots.pop_back()
		var expected = [1, 2, 3, 5][tier]
		for i in expected:
			var z = enemies[i]
			var hp = z.hp
			var armor = z.armor
			sim._strike_straight(shot, z)
			h.check("透骨针", "第%d阶第%d针足额穿甲直伤" % [tier, i + 1],
				is_equal_approx(z.hp, hp - 18.0) and is_equal_approx(z.armor, armor))
		h.check("透骨针", "第%d阶穿透数正确" % tier, shot.dead == (tier < 3))
	plant.upgrades[2] = 3
	plant.needle_shots = 3
	plant.timer = 0.0
	sim._update_needle(plant, 1.09)
	h.check("透骨针", "1.1秒前不射击", sim.shots.is_empty())
	sim._update_needle(plant, 0.02)
	var pin = sim.shots.pop_back()
	var large = sim.spawn_zombie("mountain", 2, {"x": 1250.0})
	sim._strike_straight(pin, large)
	sim._strike_straight(pin, enemies[4])
	h.check("透骨针", "第四针只钉第一名；大型0.15秒",
		is_equal_approx(large.stun_t, 0.15) and is_zero_approx(enemies[4].stun_t))
	plant.upgrades[3] = 3
	plant.timer = 1.1
	sim._update_needle(plant, 0.0)
	var mark = sim.shots.pop_back()
	var target = enemies[0]
	sim._strike_straight(mark, target)
	var hp = target.hp
	target.armor = 70.0
	sim.damage_zombie(target, 100.0, true)
	h.check("透骨针", "40%护具易伤与20%本体易伤分开结算",
		is_equal_approx(target.armor, 0.0) and is_equal_approx(target.hp, hp - 60.0))
	h.check("透骨针", "易伤持续2.5秒",
		is_equal_approx(target.vuln_t, 2.5) and is_equal_approx(target.armor_vuln_until - sim.time, 2.5))


static func _check_judge(h) -> void:
	var sim = h.sim_for(1, ["judge", "shooter"], "easy")
	var idol = sim.place_free("judge", 3, 2)
	var near = sim.place_free("shooter", 4, 2)
	var diagonal = sim.place_free("shooter", 4, 3)
	var corner = sim.place_free("shooter", 5, 4)
	sim.spawn_zombie("ghost", 2, {"x": idol.pos.x + 300.0})
	sim._update_judge(idol, 10.0)
	h.check("钟馗像", "白板不攻击，自身与相邻格受庇护", sim.shots.is_empty()
		and is_equal_approx(sim.plant_guard(idol), 0.20)
		and is_equal_approx(sim.plant_guard(near), 0.20)
		and is_zero_approx(sim.plant_guard(diagonal)))
	idol.upgrades[2] = 2
	h.check("钟馗像", "守坊扩至3×3", sim.plant_guard(diagonal) > 0.0 and sim.plant_guard(corner) == 0.0)
	idol.upgrades[2] = 3
	sim._update_judge(idol, 1.59)
	h.check("钟馗像", "朱砂弹未满间隔不发", sim.shots.is_empty())
	sim._update_judge(idol, 0.02)
	h.check("钟馗像", "镇市扩至5×5，朱砂弹38伤", sim.plant_guard(corner) > 0.0
		and sim.shots.size() == 1 and is_equal_approx(sim.shots[0].damage, 38.0))
	idol.upgrades[2] = 0
	idol.upgrades[1] = 3
	sim.damage_plant(near, 100.0)
	h.check("钟馗像", "50%减伤对非啃食伤害同样生效", is_equal_approx(near.hp, near.max_hp - 50.0))
	sim.damage_plant(near, 5000.0)
	sim.damage_plant(idol, 5000.0)
	sim.damage_plant(near, 5000.0)
	h.check("钟馗像", "免死按株结算，并保留1血免伤", near.hp == 1.0 and idol.hp == 1.0 and not near.dead)
	var resumed = h.sim_for(1, ["judge", "shooter"], "easy")
	resumed.restore(sim.serialize())
	var saved_plant = resumed.main_plant_at(4, 2)
	resumed.damage_plant(saved_plant, 1000.0)
	h.check("钟馗像", "存档保留免伤", saved_plant.hp == 1.0)
	resumed.time += 3.01
	resumed.damage_plant(saved_plant, 1000.0)
	h.check("钟馗像", "免伤满3秒后再受致命伤即退场", saved_plant.dead)
	idol.upgrades[1] = 0
	idol.upgrades[3] = 3
	sim.refresh_plant_buffs()
	h.check("钟馗像", "赐福仅庇护范围内加伤与攻速", near.buff_damage == 0.25 and near.haste == 0.10
		and diagonal.buff_damage == 0.0)


static func _check_new_cards(h) -> void:
	var sim = h.sim_for(1, ["gust", "firework"], "easy")
	var fan = sim.place_free("gust", 0, 1)
	var fire = sim.place_free("firework", 0, 2)
	var x = Geo.cell_center(3, 1, sim.rows).x
	var normal = sim.spawn_zombie("ghost", 0, {"x": x})
	var large = sim.spawn_zombie("mountain", 1, {"x": x})
	var blocked = sim.spawn_zombie("ghost", 2, {"x": x})
	sim.tiles[2][4]["kind"] = "object"
	sim._update_gust(fan, 0.61)
	sim._step_gust(normal, 0.4)
	h.check("归风扇", "0.4秒推进普通恶客一格", is_equal_approx(normal.pos.x, x + Geo.CELL_W))
	sim._step_gust(normal, 0.41)
	sim._step_gust(large, 0.81)
	sim._step_gust(blocked, 0.81)
	h.check("归风扇", "灰烬一次用完，普通两格、大型一格、遇障即止", fan.dead
		and is_equal_approx(normal.pos.x, x + Geo.CELL_W * 2.0)
		and is_equal_approx(large.pos.x, x + Geo.CELL_W)
		and is_equal_approx(blocked.pos.x, Geo.BOARD_X + Geo.CELL_W * 4.0 - 0.1))
	var impact = sim.spawn_zombie("ghost", 2, {"x": blocked.pos.x + 38.0})
	var distant = sim.spawn_zombie("ghost", 2, {"x": blocked.pos.x + Geo.CELL_W})
	blocked.hp = 400.0
	blocked.max_hp = 400.0
	var direct_hp = blocked.hp
	var splash_hp = impact.hp
	sim._update_firework(fire, 3.5)
	var lob = sim.shots.pop_back()
	sim._update_lob_shot(lob, 2.0)
	h.check("烟花童", "抛射落点100伤，0.8格内30%溅射", blocked.hp == direct_hp - 100.0
		and impact.hp == splash_hp - 30.0 and distant.hp == distant.max_hp)
	fire.upgrades[1] = 3
	fire.firework_extra_at = sim.time + 0.6
	sim._update_firework(fire, 0.5)
	h.check("烟花童", "小烟花尚未到0.6秒不补射", sim.shots.is_empty())
	sim.time += 0.6
	sim._update_firework(fire, 0.1)
	h.check("烟花童", "补射半伤并从补射重算攻击间隔",
		sim.shots.size() == 1 and sim.shots[0].damage == 50.0 and fire.timer == 0.0)
	sim.shots.clear()
	fire.upgrades[1] = 0
	fire.upgrades[2] = 2
	fire.upgrades[3] = 3
	sim._update_firework(fire, 1.6)
	h.check("烟花童", "寻星独立计时，三级追踪继承普通伤害与溅射",
		sim.shots.size() == 1 and sim.shots[0].kind == "homing" and sim.shots[0].target == sim.nearest_any(fire)
		and sim.shots[0].damage == 160.0 and is_equal_approx(sim.shots[0].firework_radius, 0.8 * Geo.CELL_W))


	# Scheduled second shot remains visible even if the initial target has died.
	for z in sim.zombies:
		if z.row == fire.row:
			z.dead = true
	fire.upgrades[3] = 0
	fire.firework_extra_at = sim.time
	fire.firework_extra_aim = Vector2(1020.0, fire.pos.y)
	sim.shots.clear()
	sim._update_firework(fire, 0.02)
	h.check("烟花童", "原目标消失也会按时补射至原落点并重计",
		sim.shots.size() == 1 and sim.shots[0].target == null
		and is_equal_approx(sim.shots[0].tx, 1020.0) and fire.timer == 0.0)


## 抛一颗汤圆直到落地，中间只推进射弹与地效，不动波次也不推进 sim.time。
static func _lob_land(sim, plant, frames: int = 140) -> void:
	sim.shots.clear()
	plant.timer = 2.59
	sim._update_lobber(plant, 0.02)
	for i in frames:
		sim.update_shots(1.0 / 60.0)
	sim.update_grounds(1.0 / 60.0)


static func _lob_grow(sim, frames: int) -> void:
	for i in frames:
		sim.update_shots(1.0 / 60.0)
		sim.update_grounds(1.0 / 60.0)


static func _lob_ground(sim, kind: String) -> Dictionary:
	for g in sim.grounds:
		if String(g["kind"]) == kind:
			return g
	return {}


## 汤圆仔（批复版）：馅有多重／落在哪／落地留什么。白板 40 伤 2.6 秒只在 content 一处。
static func _check_lobber(h) -> void:
	var def: Dictionary = Content.PLANTS["lobber"]["lob"]
	var fx: Dictionary = Upgrades.EFFECTS["lobber"]
	h.check("汤圆仔", "白板 40 伤 / 2.6 秒只在 content，EFFECTS 不再抄一份",
		is_equal_approx(float(def["damage"]), 40.0) and is_equal_approx(float(def["interval"]), 2.6)
		and not fx.has("damage") and not fx.has("interval"), str(def))

	# 白板：抛本行最靠里（队尾）那名
	var sim = h.sim_for(6, ["lobber"], "easy")
	var pot = sim.place_free("lobber", 1, 2)
	var near = sim.spawn_zombie("ghost", 2, {"x": pot.pos.x + 120.0})
	near.max_hp = 90000.0
	near.hp = 90000.0
	var deep = sim.spawn_zombie("ghost", 2, {"x": pot.pos.x + 400.0})
	deep.max_hp = 90000.0
	deep.hp = 90000.0
	_lob_land(sim, pot)
	h.check("汤圆仔", "白板：抛的是本行最靠里那名，落地 40",
		90000.0 - deep.hp >= 39.999 and near.hp == 90000.0,
		"队尾掉 %.0f 队头掉 %.0f" % [90000.0 - deep.hp, 90000.0 - near.hp])

	# 数馅（1-1）：每 4 名存活敌人 +8%，只涨砸中的那一笔
	var sim2 = h.sim_for(6, ["lobber"], "easy")
	var scale = sim2.place_free("lobber", 1, 2)
	scale.upgrades = {1: 1, 2: 0, 3: 0}
	for i in 4:
		var mob = sim2.spawn_zombie("ghost", 2, {"x": scale.pos.x + 300.0 + i * 26.0})
		mob.max_hp = 90000.0
		mob.hp = 90000.0
	_lob_land(sim2, scale, 200)
	var crowd_loss = 0.0
	for z in sim2.zombies:
		crowd_loss = maxf(crowd_loss, 90000.0 - z.hp)
	h.check("汤圆仔", "数馅：四名存活就多 8%，只涨直接命中",
		crowd_loss >= 43.199 and crowd_loss <= 43.201, "最重一口 %.2f" % crowd_loss)

	# 砸飞（1-2）：带甲的另削 40，一击剥不掉整件；见了底才掉残片
	var sim3 = h.sim_for(6, ["lobber"], "easy")
	var chipper = sim3.place_free("lobber", 1, 2)
	chipper.upgrades = {1: 2, 2: 0, 3: 0}
	var thick = sim3.spawn_zombie("bucket", 2, {"x": chipper.pos.x + 300.0})
	thick.max_hp = 90000.0
	thick.hp = 90000.0
	thick.armor = 500.0
	_lob_land(sim3, chipper, 200)
	h.check("汤圆仔", "砸飞：这一下最多削 40，剥不穿就不掉残片",
		500.0 - thick.armor <= 80.01 and thick.armor > 0.0
		and _lob_ground(sim3, "debris").is_empty() and thick.hp == 90000.0,
		"甲=%.0f 血=%.0f" % [thick.armor, thick.hp])
	sim3.grounds.clear()
	thick.armor = 60.0
	_lob_land(sim3, chipper, 200)
	var debris = _lob_ground(sim3, "debris")
	h.check("汤圆仔", "砸飞：护具见了底就掉一地残片",
		not debris.is_empty() and thick.armor == 0.0, str(debris))
	var triped = sim3.spawn_zombie("ghost", 2, {"x": float(debris["pos"].x)})
	triped.max_hp = 90000.0
	triped.hp = 90000.0
	var ox = sim3.spawn_zombie("mountain", 2, {"x": float(debris["pos"].x)})
	ox.max_hp = 90000.0
	ox.hp = 90000.0
	sim3.update_grounds(1.0 / 60.0)
	h.check("汤圆仔", "残片：普通绊 0.2 秒，大型只吃 10% 减速",
		triped.stun_t > 0.0 and triped.stun_t <= 0.201 and ox.stun_t <= 0.0
		and ox.slow_t > 0.0, "绊=%.2f 大型钉=%.2f 减速=%.2f" % [
			triped.stun_t, ox.stun_t, ox.slow_amount])

	# 贴馅（1-3）：大型身上挂一颗两秒后炸的，同一名一次只挂一颗
	var sim4 = h.sim_for(6, ["lobber"], "easy")
	var stuffer = sim4.place_free("lobber", 1, 2)
	stuffer.upgrades = {1: 3, 2: 0, 3: 0}
	var big = sim4.spawn_zombie("mountain", 2, {"x": stuffer.pos.x + 300.0})
	big.max_hp = 90000.0
	big.hp = 90000.0
	_lob_land(sim4, stuffer, 200)
	h.check("汤圆仔", "贴馅：大型身上挂一颗 2 秒的，伤害封顶 160",
		absf(big.bomb_t - 2.0) < 0.011 and big.bomb_damage == 160.0,
		"t=%.2f dmg=%.0f" % [big.bomb_t, big.bomb_damage])
	var after_attach = big.hp
	sim4.grounds.clear()
	_lob_land(sim4, stuffer, 200)
	h.check("汤圆仔", "贴馅：身上还挂着一颗时不再贴第二颗",
		big.bomb_damage == 160.0 and absf(after_attach - big.hp) < 40.01,
		"又掉 %.0f" % (after_attach - big.hp))
	for i in 140:
		sim4.update_zombies(1.0 / 60.0)
	h.check("汤圆仔", "贴馅：两秒到就炸开，扣的是本体",
		big.bomb_t <= 0.0 and big.bomb_damage <= 0.0, "t=%.2f" % big.bomb_t)
	var runt = sim4.spawn_zombie("ghost", 2, {"x": stuffer.pos.x + 300.0})
	runt.max_hp = 90000.0
	runt.hp = 90000.0
	stuffer.timer = 2.59
	sim4._update_lobber(stuffer, 0.02)
	_lob_grow(sim4, 140)
	h.check("汤圆仔", "贴馅：非大型不挂这颗，只吃本体那一口",
		runt.bomb_t <= 0.0, "t=%.2f" % runt.bomb_t)

	# 拣密（2-1）：抛本行射程内身边最挤那名，平局取离防线近的
	var sim5 = h.sim_for(6, ["lobber"], "easy")
	var denser = sim5.place_free("lobber", 1, 2)
	denser.upgrades = {1: 0, 2: 1, 3: 0}
	var lone = sim5.spawn_zombie("ghost", 2, {"x": denser.pos.x + 480.0})
	lone.max_hp = 90000.0
	lone.hp = 90000.0
	var cluster: Array = []
	for i in 3:
		var c = sim5.spawn_zombie("ghost", 2, {"x": denser.pos.x + 200.0 + i * 30.0})
		c.max_hp = 90000.0
		c.hp = 90000.0
		cluster.append(c)
	_lob_land(sim5, denser, 220)
	var in_cluster = 0.0
	for c in cluster:
		in_cluster = maxf(in_cluster, 90000.0 - float(c.hp))
	h.check("汤圆仔", "拣密：抛的是身边最挤那一伙，不是最散那名",
		90000.0 - lone.hp <= 0.001 and in_cluster >= 39.999,
		"散的那名掉 %.0f / 那一伙最重一口 %.0f" % [90000.0 - lone.hp, in_cluster])

	# 连抛（2-2）：一次两颗、隔 0.15 秒，两颗都还是 40
	var sim6 = h.sim_for(6, ["lobber"], "easy")
	var double = sim6.place_free("lobber", 1, 2)
	double.upgrades = {1: 0, 2: 2, 3: 0}
	var six = sim6.spawn_zombie("ghost", 2, {"x": double.pos.x + 300.0})
	six.max_hp = 900000.0
	six.hp = 900000.0
	double.timer = 2.59
	sim6._update_lobber(double, 0.02)
	var gaps = 0.0
	var both_base = true
	for s in sim6.shots:
		gaps = maxf(gaps, float(s.delay))
		if not is_equal_approx(float(s.base_damage), 40.0):
			both_base = false
	h.check("汤圆仔", "连抛：一次两颗、第二颗隔 0.15 秒、两颗都还是白板 40",
		sim6.shots.size() == 2 and gaps > 0.14 and gaps < 0.16 and both_base,
		"%d 颗 gap=%.2f" % [sim6.shots.size(), gaps])
	_lob_grow(sim6, 200)
	h.check("汤圆仔", "连抛：两颗各 40，攻击周期仍是 2.6 秒",
		absf((900000.0 - six.hp) - 80.0) < 0.01, "合计掉 %.0f" % (900000.0 - six.hp))

	# 三更（2-3）：每四轮第一颗换成大汤
	var sim7 = h.sim_for(6, ["lobber"], "easy")
	var third = sim7.place_free("lobber", 1, 2)
	third.upgrades = {1: 0, 2: 3, 3: 0}
	var crowd7: Array = []
	for i in 4:
		var z = sim7.spawn_zombie("ghost", 2, {"x": third.pos.x + 260.0 + i * 40.0})
		z.max_hp = 900000.0
		z.hp = 900000.0
		crowd7.append(z)
	for i in 3:
		sim7.shots.clear()
		third.timer = 2.59
		sim7._update_lobber(third, 0.02)
		_lob_grow(sim7, 200)
	sim7.shots.clear()
	third.timer = 2.59
	sim7._update_lobber(third, 0.02)
	h.check("汤圆仔", "三更：第四轮第一颗是大汤 100，第二颗不跟着升",
		sim7.shots.size() == 2 and bool(sim7.shots[0].big_soup)
		and is_equal_approx(float(sim7.shots[0].base_damage), 100.0)
		and not bool(sim7.shots[1].big_soup),
		"第一颗 base=%.0f" % float(sim7.shots[0].base_damage))
	var splash_before = 900000.0 - float(crowd7[0].hp)
	_lob_grow(sim7, 200)
	var splashed = 0
	for z in crowd7:
		if 900000.0 - float(z.hp) - splash_before >= 39.999 and 900000.0 - float(z.hp) - splash_before <= 40.01:
			splashed += 1
	h.check("汤圆仔", "三更：大汤溅开的额外目标各吃四成，至多 3 名",
		splashed <= 3 and splashed >= 1, "溅到 %d 名" % splashed)

	# 一摊（3-1）／合流（3-2）／封口（3-3）
	var sim8 = h.sim_for(6, ["lobber"], "easy")
	var souper = sim8.place_free("lobber", 1, 2)
	souper.upgrades = {1: 0, 2: 0, 3: 1}
	var soup_target = sim8.spawn_zombie("ghost", 2, {"x": souper.pos.x + 300.0})
	soup_target.max_hp = 900000.0
	soup_target.hp = 900000.0
	_lob_land(sim8, souper, 200)
	var pool = _lob_ground(sim8, "soup")
	h.check("汤圆仔", "一摊：落点留 0.4 格汤，减速 20%、10/秒",
		not pool.is_empty() and is_equal_approx(float(pool["radius"]), 0.4 * Geo.CELL_W)
		and is_equal_approx(float(pool["damage"]), 10.0)
		and float(pool["slow"]) > 0.19 and float(pool["life"]) > 2.9,
		str(pool))
	sim8.grounds.clear()
	souper.upgrades = {1: 0, 2: 0, 3: 2}
	_lob_land(sim8, souper, 200)
	# 再补一摊在旁边，两摊相交就该熬成一锅浓汤
	var second_soup = sim8.spawn_zombie("ghost", 2, {"x": soup_target.pos.x + 40.0})
	second_soup.max_hp = 900000.0
	second_soup.hp = 900000.0
	_lob_land(sim8, souper, 200)
	var broth = _lob_ground(sim8, "broth")
	h.check("汤圆仔", "合流：两摊相交熬成 0.6 格浓汤，18/秒、减速 25%",
		not broth.is_empty() and is_equal_approx(float(broth["radius"]), 0.6 * Geo.CELL_W)
		and is_equal_approx(float(broth["damage"]), 18.0), str(broth))
	var soups = 0
	for g in sim8.grounds:
		if String(g["kind"]) == "soup":
			soups += 1
	h.check("汤圆仔", "合流：摊不再多了，浓汤只有一锅", soups == 0, "还留 %d 摊" % soups)
	var before_life = float(broth["life"])
	_lob_land(sim8, souper, 200)
	h.check("汤圆仔", "合流：新摊只续火，不再加大加烫",
		is_equal_approx(float(broth["radius"]), 0.6 * Geo.CELL_W)
		and float(broth["life"]) > before_life, "life %.2f → %.2f" % [
			before_life, float(broth["life"])])
	sim8.grounds.clear()
	souper.upgrades = {1: 0, 2: 0, 3: 3}
	_lob_land(sim8, souper, 200)
	_lob_land(sim8, souper, 200)
	var seal = _lob_ground(sim8, "broth")
	h.check("汤圆仔", "封口：浓汤减速提到 35%、不定身",
		not seal.is_empty() and is_equal_approx(float(seal["slow"]), 0.35), str(seal))
	var muncher = sim8.spawn_zombie("ghost", 2, {"x": float(seal["pos"].x)})
	muncher.max_hp = 900000.0
	muncher.hp = 900000.0
	muncher.eating = true
	var stander = sim8.spawn_zombie("ghost", 2, {"x": float(seal["pos"].x) + 20.0})
	stander.max_hp = 900000.0
	stander.hp = 900000.0
	sim8.update_grounds(1.0 / 60.0)
	h.check("汤圆仔", "封口：站在汤里啃草的另受 12/秒",
		900000.0 - muncher.hp >= 29.999 and 900000.0 - stander.hp <= 18.001,
		"啃的掉 %.0f 站的掉 %.0f" % [900000.0 - muncher.hp, 900000.0 - stander.hp])
	# 每摊同时只烫三名，优先离防线近的
	var sim9 = h.sim_for(6, ["lobber"], "easy")
	var capped = sim9.place_free("lobber", 1, 2)
	capped.upgrades = {1: 0, 2: 0, 3: 3}
	var many: Array = []
	for i in 5:
		var m = sim9.spawn_zombie("ghost", 2, {"x": capped.pos.x + 240.0 + i * 24.0})
		m.max_hp = 900000.0
		m.hp = 900000.0
		many.append(m)
	_lob_land(sim9, capped, 200)
	_lob_land(sim9, capped, 200)
	var pot9 = _lob_ground(sim9, "broth")
	var burned: Array = []
	for i in range(many.size()):
		if 900000.0 - float(many[i].hp) > 0.001:
			burned.append(i)
	h.check("汤圆仔", "每摊同时最多烫 3 名，先烫离防线近的",
		burned.size() <= 3 and (burned.is_empty() or int(burned[0]) < int(burned[burned.size() - 1])),
		"烫了第 %s 名" % str(burned))

## 从一轮五束里按方向找出那一束。
static func _star_beam(sim, dir: Vector2):
	for s in sim.shots:
		if s.dir.distance_to(dir) < 0.01:
			return s
	return null


## 五路巡灯（批复版）：照法管这一道多亮、旋法管转多快、巡天保持原稿。
## 白板 20 伤 / 1.6 秒 / 五向只写在 content 一处。
static func _check_star(h) -> void:
	var fx: Dictionary = Upgrades.EFFECTS["star"]
	var def: Dictionary = Content.PLANTS["star"]["star"]
	for tier in 4:
		var want = 1.6 / (1.0 + float(fx["speed_bonus"][tier]))
		var sim = h.sim_for(6, ["star"], "easy")
		h.check("五路寻灯", "第%d档攻速独立结算" % tier,
			is_equal_approx(sim._star_interval(fx, def, tier), want))
	var sim = h.sim_for(6, ["star"], "easy")
	var lamp = sim.place_free("star", 4, 2)
	lamp.upgrades = {1: 3, 2: 0, 3: 0}
	var victim = sim.spawn_zombie("ghost", 0, {"x": lamp.pos.x + 100.0})
	victim.armor = 0.0
	victim.hp = 1.0
	lamp.timer = 2.0
	sim._update_star(lamp, 0.02)
	var first = sim.shots[0]
	h.check("五路寻灯", "伤害路线三级全弹增加75%", is_equal_approx(first.damage, 35.0),
		"%.1f" % first.damage)
	sim._star_impact(first, victim)
	h.check("五路寻灯", "击杀得一层激励5秒", lamp.star_morale_stacks == 1
		and lamp.star_morale_until >= sim.time + 4.99)
	lamp.timer = 2.0
	sim.shots.clear()
	var next = sim.spawn_zombie("ghost", 0, {"x": lamp.pos.x + 110.0})
	next.hp = 90000.0
	sim._update_star(lamp, 0.02)
	h.check("五路寻灯", "一层激励追加10%伤害",
		is_equal_approx(sim.shots[0].damage, 37.0))
	lamp.star_morale_stacks = 3
	lamp.star_morale_until = sim.time - 0.01
	sim._update_star(lamp, 0.02)
	h.check("五路寻灯", "激励到期归零", lamp.star_morale_stacks == 0)
	var sim2 = h.sim_for(6, ["star"], "easy")
	var urgent = sim2.place_free("star", 4, 2)
	urgent.upgrades = {1: 0, 2: 3, 3: 0}
	sim2.spawn_zombie("ghost", 0, {"x": urgent.pos.x + 100.0})
	var intruder = sim2.spawn_zombie("ghost", 2, {"x": Geo.BREACH_X - 1.0})
	sim2.breach(intruder)
	sim2._update_star(urgent, 0.02)
	h.check("五路寻灯", "门神惊动后攻速提高300%持续10秒",
		urgent.star_guardian_until >= sim2.time + 9.99)
	urgent.timer = 0.19
	sim2.shots.clear()
	sim2._update_star(urgent, 0.02)
	h.check("五路寻灯", "急巡间隔为0.2秒", not sim2.shots.is_empty())

static func _check_control_ledger(h) -> void:
	var sim = h.sim_for(6, ["bell"], "easy")
	var small: Sim.Zombie = sim.spawn_zombie("straw", 2, {"x": 900.0})
	h.check("控制账本", "首次硬控照常给", sim.try_hard_cc(small, 0.6))
	h.check("控制账本", "控制期间不刷新已有时长", not sim.try_hard_cc(small, 0.4))
	h.step(sim, 0.6)
	h.check("控制账本", "刚控完进入再控免疫", not sim.try_hard_cc(small, 0.3))
	h.step(sim, 0.3)
	h.check("控制账本", "免疫期过后还能控，但只给剩余额度",
		sim.try_hard_cc(small, 0.5) and is_equal_approx(small.stun_t, 0.4),
		"stun=%.2f" % small.stun_t)
	h.step(sim, 1.0)
	h.check("控制账本", "4 秒窗口内累计满 1 秒后直接拒绝",
		not sim.try_hard_cc(small, 0.5), "stun=%.2f" % small.stun_t)
	h.step(sim, 4.5)
	h.check("控制账本", "窗口滑走后额度回来", sim.try_hard_cc(small, 0.5))
	var tiny: Sim.Zombie = sim.spawn_zombie("ghost", 1, {"x": 900.0})
	h.check("控制账本", "不足 0.1 秒的事件被拒", not sim.try_hard_cc(tiny, 0.04))
	var big: Sim.Zombie = sim.spawn_zombie("mountain", 0, {"x": 900.0})
	h.check("控制账本", "大型也能被新机制定身", sim.try_hard_cc(big, 0.9))
	h.step(sim, 1.2)
	h.check("控制账本", "大型 4 秒窗口只有 0.5 秒", not sim.try_hard_cc(big, 0.4))
	# 位移：滚动 6 秒普通 0.6 格；受保护的旧石磨只记消耗、不截短
	var mover: Sim.Zombie = sim.spawn_zombie("bucket", 3, {"x": 900.0})
	h.check("位移账本", "首次击退照给", is_equal_approx(sim.move_zombie(mover, 0.5), 0.5))
	h.check("位移账本", "超出 0.6 格的部分被截短",
		is_equal_approx(sim.move_zombie(mover, 0.5), 0.1))
	var legacy: Sim.Zombie = sim.spawn_zombie("bucket", 4, {"x": 900.0})
	h.check("位移账本", "受保护的旧石磨击退不截短",
		is_equal_approx(sim.move_zombie(legacy, 0.9, false), 0.9))
	h.check("位移账本", "截短后确实还在动", mover.pos.x > 900.0 - 0.001,
		"x=%.1f" % mover.pos.x)


static func _check_tutorial(h) -> void:
	var sim = Sim.new()
	sim.start_tutorial()
	h.check("教学", "教学关卡是签筒与石磨两张", sim.cards.size() == 2 and
		String(sim.cards[0]["id"]) == "shooter" and String(sim.cards[1]["id"]) == "wall")
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
	sim.sun = 300
	var placed = sim.try_place_card(0, 2, 2, Vector2.ZERO)
	h.check("教学", "种下签筒后进入升阶步",
		placed and sim.tutorial_step() == "upgrade")
	var shooter: Sim.Plant = sim.main_plant_at(2, 2)
	# 评测实测的卡死点：误铲教学株。现在铲不动；就算株没了也能退回还能继续的那一步
	var blocked = sim.shovel_at(2, 2)
	h.check("教学", "教学签筒铲不掉", not bool(blocked["ok"]), String(blocked.get("text", "")))
	var outcome = sim.try_upgrade(shooter, 1, Vector2.ZERO)
	h.check("教学", "升阶后进入挡怪步",
		bool(outcome["ok"]) and sim.tutorial_step() == "wall")
	sim.kill_plant(shooter, true)
	h.step(sim, 0.1)
	h.check("教学", "签筒没了退回种植步并补够香火",
		sim.tutorial_step() == "plant" and sim.sun >= 250,
		"step=%s sun=%d" % [sim.tutorial_step(), int(sim.sun)])
	sim.cards[0]["cd"] = 0.0
	sim.try_place_card(0, 2, 2, Vector2.ZERO)
	sim.try_upgrade(sim.main_plant_at(2, 2), 1, Vector2.ZERO)
	h.check("教学", "重走一遍能再回到挡怪步", sim.tutorial_step() == "wall")
	sim.try_place_card(1, 3, 2, Vector2.ZERO)
	h.check("教学", "石磨落地后进入实战步", sim.tutorial_step() == "battle"
		and sim.main_plant_at(3, 2) != null)
	h.step(sim, 1.9)
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
	# 动过调整面板的这一夜要能一路带到结算，否则纪录会错记到正经册上
	sim.cheated = true
	var reloaded = Sim.new()
	reloaded.restore(sim.serialize())
	h.check("存档", "作弊标记随存档往返", bool(reloaded.cheated))
	h.check("存档", "存档可再次序列化",
		not restored.serialize().is_empty())
	# 通关名单要经得起 JSON 往返：读回来的整数全是浮点，不收口的话
	# Array.has(1) 认不出 1.0，同一夜会被反复追加，守夜记录凭空多一夜
	var Game = load("res://scripts/game.gd")
	var round_trip = JSON.parse_string(JSON.stringify({"cleared": [1, 2, 99, 0, 1.5]}))
	var ids: Array = Game._night_ids(round_trip["cleared"] + [1.0, 2])
	h.check("存档", "通关名单收成整数、去重、丢掉不存在的夜号",
		str(ids) == "[1, 2]", str(ids))


## 守夜记录分册、速度下限与构建戳记：都是 game.gd 的账目规则，只碰内存不写盘。
static func _check_ledger(h) -> void:
	var Game = load("res://scripts/game.gd")
	var Build = load("res://data/build_info.gd")
	var sim = h.sim_for(1, ["shooter"], "easy")
	sim.kills = 41
	sim.wave_index = 6
	sim.time = 120.0
	var ledger = Game.new()
	ledger.sim = sim
	ledger.records = {}
	var easy: Dictionary = ledger._record_book("by_diff", "easy")
	ledger._record_tally(easy, true)
	var cheat: Dictionary = ledger._record_book("cheated", "")
	ledger._record_tally(cheat, false)
	cheat["runs"] = int(cheat.get("runs", 0)) + 1
	h.check("纪录", "正经局按难度分册", int(easy.get("wins", 0)) == 1
		and int(easy.get("best_kills", 0)) == 41 and int(easy.get("best_wave", 0)) == 6,
		str(ledger.records))
	h.check("纪录", "开过调整的另册不并进难度册", int(cheat.get("runs", 0)) == 1
		and not cheat.has("wins") and int(easy.get("wins", 0)) == 1, str(cheat))
	# 旧版只有一本不分难度的总账：读档时整册挪进 legacy，别算到某个难度头上
	ledger.records = {"wins": 3, "best_kills": 88, "best_wave": 9, "best_time": 100.0}
	ledger._records_v2()
	h.check("纪录", "旧版总账挪进 legacy，不分给任何难度",
		int(Dictionary(ledger.records.get("legacy", {})).get("best_kills", 0)) == 88
		and not ledger.records.has("wins") and not ledger.records.has("by_diff"),
		str(ledger.records))
	ledger.free()
	var shifter = Game.new()
	shifter.run_mode = "normal"
	shifter.apply_speed(0.1)
	h.check("设置", "正式局把 0.1× 抬到 1×", is_equal_approx(shifter.speed, 1.0),
		str(shifter.speed))
	shifter.run_mode = "training"
	shifter.apply_speed(0.1)
	h.check("设置", "训练场保留 0.1× 观察档", is_equal_approx(shifter.speed, 0.1),
		str(shifter.speed))
	shifter.apply_speed(2.0)
	h.check("设置", "训练场照样能快进", is_equal_approx(shifter.speed, 2.0),
		str(shifter.speed))
	shifter.free()
	h.check("构建", "戳记版本与 game.gd 一致", String(Build.VERSION) == String(Game.VERSION),
		"%s vs %s" % [Build.VERSION, Game.VERSION])
	h.check("构建", "构建时间与短哈希已写入",
		String(Build.BUILD_TIME).length() >= 16 and String(Build.BUILD_HASH).length() >= 7,
		"%s %s" % [Build.BUILD_TIME, Build.BUILD_HASH])


## 修订 v2 新增/改写的机制，逐条点名验证（威胁 1.0 的第六夜，伤害不缩放）。
static func _check_bell(h) -> void:
	"""铜铃（批复版）：余音只补减速、摄心走共享账本、引客叫回头、满街铃只在被啃毁时响。"""
	var sim = h.sim_for(6, ["bell"], "easy")
	var bell = sim.place_free("bell", 3, 2)
	var own = sim.spawn_zombie("straw", 2, {"x": bell.pos.x + 120.0})
	var cross = sim.spawn_zombie("straw", 3, {"x": bell.pos.x + 30.0})
	bell.upgrades = {1: 1, 2: 0, 3: 0}
	sim._update_bell(bell, 2.6)
	h.check("铜铃", "主铃减速本行恶客", own.slow_t > 0.0)
	h.check("铜铃", "一阶只排下一声余音", bell.echoes.size() == 1, str(bell.echoes.size()))
	cross.slow_t = 0.0
	h.step(sim, 0.7)
	h.check("铜铃", "余音到点自己清空", bell.echoes.is_empty())
	h.check("铜铃", "一阶余音不跨行", cross.slow_t <= 0.0)
	bell.upgrades = {1: 2, 2: 0, 3: 0}
	sim._update_bell(bell, 2.6)
	cross.slow_t = 0.0
	h.step(sim, 0.7)
	h.check("铜铃", "二阶主铃间隔1.5秒", is_equal_approx(float(Upgrades.EFFECTS["bell"]["main_interval"][2]), 1.5))
	bell.upgrades = {1: 3, 2: 0, 3: 0}
	sim._update_bell(bell, 2.6)
	h.check("铜铃", "三阶主铃间隔1.2秒", is_equal_approx(float(Upgrades.EFFECTS["bell"]["main_interval"][3]), 1.2))
	h.check("铜铃", "反复命中的恶客减速40%", own.slow_amount >= 0.399,
		"%.2f" % own.slow_amount)
	bell.echoes = []
	bell.upgrades = {1: 0, 2: 1, 3: 0}
	var eater: Sim.Zombie = sim.spawn_zombie("ghost", 2, {"x": bell.pos.x + 24.0})
	eater.eating = true
	eater.cc_log = []
	eater.cc_immune = 0.0
	sim._update_bell(bell, 2.6)
	h.check("铜铃", "一阶概率定身走的是同一条账本", eater.stun_t >= 0.0)
	bell.upgrades = {1: 0, 2: 2, 3: 0}
	eater.eating = true
	eater.stun_t = 0.0
	eater.cc_log = []
	eater.cc_immune = 0.0
	sim._update_bell(bell, 2.6)
	h.check("铜铃", "夺魄必定钉住正在啃草的那一个", eater.stun_t > 0.0,
		"stun=%.2f" % eater.stun_t)
	bell.upgrades = {1: 0, 2: 0, 3: 1}
	var far = sim.spawn_zombie("tongue", 2, {"x": bell.pos.x + 150.0})
	var near = sim.spawn_zombie("tongue", 2, {"x": bell.pos.x + 40.0})
	sim._update_bell(bell, 2.6)
	h.check("铜铃", "回头只叫前方最远那名", far.reverse_t > 0.0 and near.reverse_t <= 0.0,
		"far=%.2f near=%.2f" % [far.reverse_t, near.reverse_t])
	far.reverse_t = 0.0
	sim._update_bell(bell, 2.6)
	h.check("铜铃", "四秒内同一名不被重复叫回头", far.reverse_t <= 0.0
		and near.reverse_t <= 0.0, "far=%.2f" % far.reverse_t)
	bell.upgrades = {1: 0, 2: 0, 3: 2}
	var mate = sim.spawn_zombie("tongue", 2, {"x": far.pos.x + 20.0})
	far.reverse_icd = 0.0
	mate.slow_t = 0.0
	sim._update_bell(bell, 2.6)
	h.check("铜铃", "成群把回头者身边的同伴一起减速", mate.slow_t > 0.0)
	bell.upgrades = {1: 0, 2: 3, 3: 0}
	var big = sim.spawn_zombie("mountain", 2, {"x": bell.pos.x + 30.0})
	var hp_before = big.hp
	for i in 60:
		sim.update_zombies(1.0 / 60.0)
	h.check("铜铃", "魂断：大型啃铃会自己流血", big.bleed_t > 0.0 and big.hp < hp_before,
		"bleed=%.2f hp=%.1f" % [big.bleed_t, big.hp])
	bell.upgrades = {1: 0, 2: 0, 3: 3}
	sim.spawn_zombie("ghost", 4, {"x": 1100.0})
	sim.kill_plant(bell)
	var rooted = 0
	for z in sim.zombies:
		if z.stun_t > 0.0:
			rooted += 1
	h.check("铜铃", "满街铃：被啃毁时全图定身", rooted >= 2, "rooted=%d" % rooted)
	h.check("铜铃", "满街铃记下共享冷却", sim.bell_death_until > sim.time)
	var second = sim.place_free("bell", 4, 2)
	second.upgrades = {1: 0, 2: 0, 3: 3}
	for z in sim.zombies:
		z.stun_t = 0.0
		z.cc_immune = 0.0
		z.cc_log = []
	sim.kill_plant(second)
	var again = 0
	for z in sim.zombies:
		if z.stun_t > 0.0:
			again += 1
	h.check("铜铃", "冷却之内的第二声不响", again == 0, "again=%d" % again)



## 香炉（批复版）：烟形／香印／炉温三条路。伤害永远是白板 45，
## 涨只涨在"旺客"与"众口"上，两者取较高的一份。

## 纸伞（批复版）：收放／愿力／伞骨。收妖本身仍是白板 6 秒，
## 三条路分别改"怎么吃"、"吃完留下什么"、"吃的时候在挨打"。
static func _check_umbrella(h) -> void:
	var fx: Dictionary = Upgrades.EFFECTS["umbrella"]
	for tier in 4:
		var sim = h.sim_for(6, ["umbrella"], "easy")
		var shade = sim.place_free("umbrella", 4, 2)
		shade.upgrades = {1: tier, 2: 0, 3: 0}
		var prey = sim.spawn_zombie("ghost", 2, {"x": shade.pos.x + 30.0})
		sim.flytrap_bite(shade, prey, fx)
		var want = 6.0 * (1.0 - float(fx["chew_reduction"][tier]))
		h.check("纸伞", "收妖冷却第%d档" % tier, is_equal_approx(shade.chew_t, want),
			"%.2f / %.2f" % [shade.chew_t, want])
		if tier == 3:
			sim.shots.clear()
			sim._umbrella_finish(shade, fx, false)
			h.check("纸伞", "完成收妖发射140伤害伞骨",
				sim.shots.size() == 1 and is_equal_approx(sim.shots[0].damage, 140.0))
	for tier in [1, 2, 3]:
		var sim = h.sim_for(6, ["umbrella"], "easy")
		var shade = sim.place_free("umbrella", 4, 2)
		shade.upgrades = {1: 0, 2: tier, 3: 0}
		var prey = sim.spawn_zombie("ghost", 2, {"x": shade.pos.x + 30.0})
		sim.flytrap_bite(shade, prey, fx)
		h.check("纸伞", "收妖开始时自身护盾第%d档" % tier,
			is_equal_approx(shade.wish, float(fx["wish_hp"][tier])))
		if tier == 3:
			shade.wish = 100.0
			shade.bite_t = 0.0
			sim._update_umbrella(shade, 0.5)
			h.check("纸伞", "未被啃食时每秒恢复50盾",
				is_equal_approx(shade.wish, 125.0))
			sim.orbs.clear()
			sim._umbrella_finish(shade, fx, false)
			h.check("纸伞", "完成收妖产出100灯火",
				not sim.orbs.is_empty() and int(sim.orbs[0]["value"]) == 100)
	var sim = h.sim_for(6, ["umbrella"], "easy")
	var shade = sim.place_free("umbrella", 4, 2)
	shade.upgrades = {1: 0, 2: 0, 3: 3}
	shade.chew_t = 5.0
	shade.chew_max = 6.0
	sim.spawn_zombie("ghost", 2, {"x": shade.pos.x + 30.0})
	sim.spawn_zombie("ghost", 2, {"x": shade.pos.x + 40.0})
	sim._try_umbrella_secondary(shade, fx)
	sim._try_umbrella_secondary(shade, fx)
	h.check("纸伞", "三级开放两个15秒副收妖位",
		not shade.secondary.is_empty() and not shade.tertiary.is_empty()
		and is_equal_approx(float(shade.secondary["t"]), 15.0)
		and is_equal_approx(float(shade.tertiary["t"]), 15.0))
	var total = 0.0
	for i in 3:
		total += sim.umbrella_thorns(shade, 100.0)
	h.check("纸伞", "刺手不设合计反伤上限", is_equal_approx(total, 90.0))

static func _check_censer(h) -> void:
	var sim = h.sim_for(6, ["censer"], "easy")
	var censer = sim.place_free("censer", 4, 2)
	var front = sim.spawn_zombie("stonehat", 2, {"x": censer.pos.x + 168.0})
	var rear = sim.spawn_zombie("stonehat", 2, {"x": censer.pos.x - 128.0})
	front.hp = 4000.0
	rear.hp = 4000.0
	front.max_hp = 4000.0
	rear.max_hp = 4000.0
	front.armor = 0.0
	rear.armor = 0.0
	censer.timer = 2.99
	sim._update_censer(censer, 0.02)
	h.check("香炉", "白板圈熏到身后 128、熏不到身前 168",
		rear.hp < 4000.0 and front.hp >= 4000.0,
		"rear=%.0f front=%.0f" % [rear.hp, front.hp])
	var plain_hit = 4000.0 - rear.hp
	censer.upgrades = {1: 1, 2: 0, 3: 0}
	front.hp = 4000.0
	rear.hp = 4000.0
	censer.timer = 2.99
	sim._update_censer(censer, 0.02)
	h.check("香炉", "顺风把前向拉长半格、后向收掉 0.2 格",
		front.hp < 4000.0 and rear.hp >= 4000.0,
		"front=%.0f rear=%.0f" % [front.hp, rear.hp])
	censer.upgrades = {1: 2, 2: 0, 3: 0}
	front.hp = 4000.0
	censer.timer = 2.99
	sim._update_censer(censer, 0.02)
	h.check("香炉", "回风排进 0.8 秒后", censer.echoes.size() == 1, str(censer.echoes))
	front.hp = 4000.0
	h.step(sim, 0.9)
	h.check("香炉", "回风到点再扫一次（18 伤）",
		is_equal_approx(4000.0 - front.hp, 18.0), "掉 %.0f" % (4000.0 - front.hp))
	censer.upgrades = {1: 3, 2: 0, 3: 0}
	sim.grounds.clear()
	censer.timer = 2.99
	sim._update_censer(censer, 0.02)
	h.check("香炉", "烟径留下一片地效", sim.grounds.size() >= 1, str(sim.grounds.size()))
	censer.upgrades = {1: 0, 2: 1, 3: 0}
	var marked = sim.spawn_zombie("straw", 2, {"x": censer.pos.x + 30.0})
	marked.max_hp = 4000.0
	marked.hp = 4000.0
	marked.armor = 0.0
	censer.timer = 2.99
	sim._update_censer(censer, 0.02)
	h.check("香炉", "盖印：一层香印、受伤害 +8%",
		sim.mark_stacks(marked, "incense") == 1 and marked.vuln > 0.07,
		"stacks=%d vuln=%.2f" % [sim.mark_stacks(marked, "incense"), marked.vuln])
	# 三印合一：按已损失生命 20% 结算、单次上限 200、每敌 9 秒冷却
	censer.upgrades = {1: 0, 2: 3, 3: 0}
	marked.hp = 2000.0
	censer.timer = 2.99
	sim._update_censer(censer, 0.02)
	var before = marked.hp
	censer.timer = 2.99
	sim._update_censer(censer, 0.02)
	# 已损失 2000 → 20% 是 400，但单次上限 200；再加主雾 45，合计应落在 200 与 300 之间
	h.check("香炉", "三印合一爆开、按已损失生命 20% 结算并受单次上限约束",
		before - marked.hp > 200.0 and before - marked.hp < 300.0
		and sim.mark_stacks(marked, "incense") == 0,
		"掉 %.0f 层数 %d" % [before - marked.hp, sim.mark_stacks(marked, "incense")])
	var icd = marked.punish_until
	marked.hp = 1000.0
	for i in 3:
		censer.timer = 2.99
		sim._update_censer(censer, 0.02)
	h.check("香炉", "同一名的处决有 9 秒冷却", is_equal_approx(marked.punish_until, icd),
		"%.1f vs %.1f" % [marked.punish_until, icd])
	# 传印：带印者倒下，印传给身边的同伴
	var sim2 = h.sim_for(6, ["censer"], "easy")
	var urn2 = sim2.place_free("censer", 4, 2)
	urn2.upgrades = {1: 0, 2: 2, 3: 0}
	var host = sim2.spawn_zombie("straw", 2, {"x": urn2.pos.x + 30.0})
	var pal = sim2.spawn_zombie("straw", 2, {"x": urn2.pos.x + 60.0})
	sim2.add_mark(host, "incense", 1, 3.2)
	sim2.kill_zombie(host)
	h.check("香炉", "传印把印带给身边的同伴", sim2.mark_stacks(pal, "incense") >= 1)
	# 旺客与众口：都只取较高的一份
	var sim3 = h.sim_for(6, ["censer"], "easy")
	var brazier = sim3.place_free("censer", 4, 2)
	brazier.upgrades = {1: 0, 2: 0, 3: 1}
	var crowd: Array = []
	for i in 5:
		var w = sim3.spawn_zombie("stonehat", 2, {"x": brazier.pos.x + 30.0 + i * 8.0})
		w.max_hp = 4000.0
		w.hp = 4000.0
		w.armor = 0.0
		crowd.append(w)
	brazier.timer = 2.99
	sim3._update_censer(brazier, 0.02)
	h.check("香炉", "旺客：每 5 名敌人主雾 +6%",
		is_equal_approx(4000.0 - float(crowd[0].hp), 45.0 * 1.06),
		"掉 %.1f" % (4000.0 - float(crowd[0].hp)))
	brazier.upgrades = {1: 0, 2: 0, 3: 2}
	for w in crowd:
		w.hp = 4000.0
	brazier.timer = 2.99
	sim3._update_censer(brazier, 0.02)
	h.check("香炉", "众口：单圈熏到 3 名以上 +25%，与旺客取较高",
		is_equal_approx(4000.0 - float(crowd[0].hp), 45.0 * 1.25),
		"掉 %.1f" % (4000.0 - float(crowd[0].hp)))
	# 冷炉：塌成香灰仍占格，再铲一次才腾格
	var sim4 = h.sim_for(6, ["censer"], "easy")
	var urn = sim4.place_free("censer", 4, 2)
	urn.upgrades = {1: 0, 2: 0, 3: 3}
	sim4.kill_plant(urn)
	h.check("香炉", "冷炉：被摧毁后塌成香灰、仍占着这一格",
		not urn.dead and urn.ash and sim4.main_plant_at(4, 2) == urn,
		"dead=%s ash=%s" % [urn.dead, urn.ash])
	var ash_hp = urn.hp
	var passer = sim4.spawn_zombie("straw", 2, {"x": urn.pos.x + 30.0})
	passer.max_hp = 4000.0
	passer.hp = 4000.0
	passer.armor = 0.0
	urn.timer = 5.9
	h.step(sim4, 0.2)
	h.check("香炉", "香灰仍放灰雾（白板四成 = 18）",
		is_equal_approx(4000.0 - passer.hp, 18.0), "掉 %.0f" % (4000.0 - passer.hp))
	var dug = sim4.shovel_at(4, 2)
	h.check("香炉", "再铲一次才腾格", bool(dug["ok"]) and urn.dead, str(dug))


static func _check_new_mechanics(h) -> void:
	# 签筒：邻行补射改为「总数 = 主行 −1，两侧分摊」，且不再半伤
	var sim = h.sim_for(6, ["shooter"], "easy")
	var shooter = sim.place_free("shooter", 3, 2)
	shooter.upgrades = {1: 2, 2: 3, 3: 0}
	sim.spawn_zombie("ghost", 2, {"x": 900.0})
	sim.start_volley(shooter)
	while int(shooter.burst.get("left", 0)) > 0:
		sim.fire_volley_shot(shooter)
	var main = 0
	var side = 0
	for shot in sim.shots:
		if shot.row == 2:
			main += 1
		else:
			side += 1
	h.check("新机制", "四发 + 全力 = 主行 4 发、邻行共 3 发",
		main == 4 and side == 3, "main=%d side=%d" % [main, side])
	# 六发满阶：10% 概率一次倾出十二支
	var top = 0
	shooter.upgrades = {1: 3, 2: 0, 3: 0}
	for i in 200:
		sim.shots.clear()
		sim.start_volley(shooter)
		while int(shooter.burst.get("left", 0)) > 0:
			sim.fire_volley_shot(shooter)
		top = maxi(top, sim.shots.size())
	h.check("新机制", "六发满阶会偶发十二支", top == 12, "最多 %d 支" % top)

	# 石磨：被啃毁时炸开 900 灰烬，只覆盖 1 格
	var sim2 = h.sim_for(6, ["wall"], "easy")
	var wall = sim2.place_free("wall", 4, 2)
	wall.upgrades = {1: 0, 2: 3, 3: 0}
	var near = sim2.spawn_zombie("mountain", 2, {"x": wall.pos.x + 30.0})
	var far = sim2.spawn_zombie("mountain", 2, {"x": wall.pos.x + 420.0})
	sim2.damage_plant(wall, 999999.0)
	h.check("新机制", "碾磨自爆对 1 格内造成 900",
		is_equal_approx(near.hp, near.max_hp - 900.0), "hp=%.1f" % near.hp)
	h.check("新机制", "自爆炸不到一格开外", is_equal_approx(far.hp, far.max_hp))

	# 红灯笼：火树每次产出附带一枚 110 伤灯焰
	var sim3 = h.sim_for(6, ["lantern"], "easy")
	var lantern = sim3.place_free("lantern", 2, 2)
	lantern.upgrades = {1: 0, 2: 3, 3: 0}
	lantern.timer = 4.96
	h.step(sim3, 0.08)
	h.check("新机制", "火树产出时甩出 110 伤灯焰",
		sim3.shots.size() == 1 and is_equal_approx(float(sim3.shots[0].damage), 110.0),
		"shots=%d" % sim3.shots.size())

	# 钟馗像：判死命中后有机会钉住
