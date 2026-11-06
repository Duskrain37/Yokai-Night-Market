extends SceneTree

var failures := 0
var checks: Array = []


func check(name: String, ok: bool) -> void:
	checks.append({"name": name, "ok": ok})
	if not ok:
		failures += 1
		printerr("FAIL ", name)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for week in range(1, 6):
		var level := Content.get_level(Content.level_id_for(week))
		Geo.set_stage(Content.map_key(level))
		var rows := int(level.rows)
		var all_centers := true
		for row in rows:
			for col in 9:
				all_centers = all_centers and Geo.screen_cell_at(Geo.screen_cell_center(col, row, rows), rows) == Vector2i(col, row)
			var area := Geo.screen_cell_polygon(0, row, rows)
			var beside := (area[0] + area[3]) * .5 - Vector2(12, 0)
			all_centers = all_centers and Geo.screen_cell_at(beside, rows) == Vector2i(-1, -1)
			area = Geo.screen_cell_polygon(8, row, rows)
			beside = (area[1] + area[2]) * .5 + Vector2(12, 0)
			all_centers = all_centers and Geo.screen_cell_at(beside, rows) == Vector2i(-1, -1)
		check("第%d周中心落点正确，左右外缘不落子" % week, all_centers)
	var island := Sim.new()
	island.setup(Content.get_level(Content.level_id_for(4)), ["shooter"], "normal")
	var edge_counts: Array = []
	var obstacles := 0
	var interior := true
	for row in 6:
		var size := 0
		for col in 9:
			var kind := String(island.tile_at(col, row).kind)
			if kind != "edge": size += 1
			if kind == "obstacle":
				obstacles += 1
				interior = interior and row in range(1, 5) and col in range(1, 8)
			if kind in ["edge", "obstacle"]:
				check("岛上禁种格 %d,%d" % [row, col], not island.can_place_at("shooter", col, row).ok)
		edge_counts.append(size)
	check("岛上六行地表宽度", edge_counts == [5, 7, 9, 9, 7, 5])
	check("岛上五块随机障碍位于内格", obstacles == 5 and interior)
	check("岛上门神同一列", island.mowers.all(func(m): return m.x == Geo.MOWER_X))
	var restored := Sim.new()
	restored.restore(JSON.parse_string(JSON.stringify(island.serialize())))
	check("岛上障碍读档位置不变", restored.tiles == island.tiles)
	assert_weights(island, [10, 16, 24, 24, 16, 10])
	var cave := Sim.new()
	cave.setup(Content.get_level(Content.level_id_for(5)), ["lily", "shooter"], "normal")
	assert_weights(cave, [10, 20, 20, 20, 15, 15])
	var water := [[1], [1, 2], [1, 2, 3], [2, 3], [0, 2, 3, 4, 5, 6, 7, 8], [0, 2, 3, 4, 5, 6, 7, 8]]
	var pits := [[4, 6, 7], [6, 7], [6], [], [], []]
	for row in 6:
		for col in 9:
			var expected := "water" if col in water[row] else ("pit" if col in pits[row] else "land")
			check("冥判窟表格格位 %d,%d" % [row, col], cave.tile_at(col, row).kind == expected)
	for i in 300:
		check("高阶与蒲舟客遵循出生路限制", cave.choose_spawn_row("mountain") < 4 and cave.choose_spawn_row("reedboat") >= 4)
	var ghost := cave.spawn_zombie("ghost", 0, {"x": cave.cell_pos(1, 0).x})
	cave.update_zombies(0.016)
	check("从陆路横穿河段播放入水", ghost.water_entered and ghost.water_entry_t > 0)
	ghost.pos.x = cave.cell_pos(0, 0).x
	cave.update_zombies(0.016)
	check("从河段回陆播放上岸", not ghost.water_entered and ghost.water_exit_t > 0)
	ghost.pos.x = cave.cell_pos(7, 0).x
	cave.update_zombies(0.016)
	check("连通坑洞整段跨越", ghost.terrain_hop_to < cave.cell_pos(6, 0).x and ghost.object_hop > 0)
	var boat := cave.spawn_zombie("reedboat", 4, {"x": cave.cell_pos(8, 4).x})
	cave.update_zombies(0.016)
	cave.damage_zombie(boat, boat.armor)
	check("蒲舟沉船使用独立动画时钟", boat.armor <= 0 and boat.water_entered and boat.raft_sink_t > 0)
	check("地形难度折入总目标", is_equal_approx(cave.hp_mul * cave.count_mul * Content.terrain_factor(cave.level), float(cave.level.threat))
		and is_equal_approx(island.hp_mul * island.count_mul * Content.terrain_factor(island.level), float(island.level.threat)))
	for level in Content.LEVELS:
		check("全地图前两波按阶段倍率和六成叠算", is_equal_approx(Content.wave_mass_ratio(level, 0), .336) and Content.wave_low_only(level, 1) and not Content.wave_low_only(level, 2))
		check("全地图末段倍率", is_equal_approx(Content.wave_mass_ratio(level, level.waves.size() - 1), 1.26))
	var finale := Sim.new()
	var chapter := Content.get_level(Content.level_id_for(5, 4))
	finale.setup(chapter, ["lantern"], "normal")
	finale.queue_wave(chapter.waves[11], 11)
	check("鬼官限制形态出现在第四大波", finale.boss != null and finale.boss.id == "magistrate-bound" and finale.wave_index == 12)
	if finale.boss != null:
		var bound_hp: float = finale.boss.max_hp
		check("限制形态禁用强力技能和号令", finale.boss.config.major_thresholds.is_empty() and not finale.boss.config.summon_final)
		finale.boss.damage(null, bound_hp * 2)
		finale.time += 2.1
		finale.update_waves()
		check("击退限制形态继续第五波", finale.boss == null and not finale.is_cleared() and finale.wave_index == 12)
		finale.queue_wave(chapter.waves[23], 23)
		check("第八大波完整形态入场", finale.boss != null and finale.boss.id == "magistrate-full" and finale.boss.max_hp > bound_hp and finale.wave_index == 24)
	for id in Almanac.BOSS_ORDER:
		check("%s 有恶首图鉴头像和技能数据" % id, Almanac.boss_portrait(id) != null and Almanac.boss_skills(id).size() >= 5)
	var f := FileAccess.open("res://qa/v050-tests.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"total": checks.size(), "failures": failures, "checks": checks}, "  "))
	print("V050 ", checks.size(), " FAILURES ", failures)
	quit(0 if failures == 0 else 1)


func assert_weights(sim: Sim, expected: Array) -> void:
	var counts := [0, 0, 0, 0, 0, 0]
	for i in 12000:
		counts[sim.choose_spawn_row("ghost")] += 1
	for row in 6:
		check("%s 第%d行权重" % [sim.level.map, row + 1], absf(counts[row] / 120.0 - expected[row]) < 1.4)
