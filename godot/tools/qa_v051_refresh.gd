extends SceneTree

class IsolatedGame extends "res://scripts/game.gd":
	var test_directory := ""

	func _data_path(path: String) -> String:
		return test_directory.path_join(path.get_file())

var total := 0
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func check(name: String, passed: bool) -> void:
	total += 1
	if not passed:
		failures += 1
		printerr("FAIL ", name)


func key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event


func run() -> void:
	var game := IsolatedGame.new()
	game.test_directory = "res://qa/refresh-%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(game.test_directory))
	var level := Content.get_level(1)
	var legacy := Sim.new()
	legacy.setup(level, ["lantern", "shooter"], "easy")
	legacy.time = 39.0
	game._write_json(game.SAVE_PATH, {"level_id": 1, "loadout": ["lantern", "shooter"], "sim": legacy.serialize()})
	root.add_child(game)
	await process_frame
	check("旧单槽原样迁到第一卷", float(game.run_slots[0].sim.time) == 39.0 and game.run_slots[1].is_empty())
	game.continue_run()
	check("续守在恢复完成前不会覆盖磁盘存档", float(game._read_json(game.SLOTS_PATH).runs[0].sim.time) == 39.0)
	game.show_menu()
	game.set_run_slot(1)
	game.start_battle(1, ["shooter", "lily", "shell"])
	var sim: Sim = game.sim
	check("第二卷可以开独立一局", game.run_slots[1].has("sim") and float(game.run_slots[0].sim.time) == 39.0)
	game.hud.refresh()
	check("旱地夜莲、没有宿主的龟甲罩显示暂无落点", game.hud._placement_warnings.has("lily")
		and game.hud._placement_warnings.has("shell"))
	var host := sim.place_free("shooter", 2, 0)
	game.hud.refresh()
	check("出现宿主后龟甲罩即时恢复提示", not game.hud._placement_warnings.has("shell"))
	sim.attach_shell(host)
	game.hud.refresh()
	check("全部宿主罩甲后重新显示提醒", game.hud._placement_warnings.has("shell"))
	for tile_row in sim.tiles:
		for tile in tile_row:
			tile.kind = "blocked"
	sim.wave_index += 1
	game.hud.refresh()
	check("波次和可种地形变化重新计算卡槽", game.hud._placement_warnings.has("shooter"))

	var values := Sim.new()
	values.setup(level, ["lantern", "shooter", "judge"], "easy")
	var target := values.place_free("shooter", 3, 0)
	var lamp := values.place_free("lantern", 0, 0)
	var second := values.place_free("lantern", 1, 0)
	var judge := values.place_free("judge", 3, 1)
	lamp.upgrades[3] = 3
	second.upgrades[3] = 2
	judge.upgrades[3] = 3
	values.refresh_plant_buffs()
	var damage_bonus: float = Upgrades.EFFECTS.lantern.buff_damage[3] + Upgrades.EFFECTS.judge.damage_buff[3]
	var haste_bonus: float = Upgrades.EFFECTS.judge.haste[3]
	check("同源取最高且异源相加", is_equal_approx(target.buff_damage, damage_bonus)
		and values.plant_bonus_sources[target.uid].size() == 2)
	values.apply_plant_penalty(target, "damage", 0.2, 3.0, "弱火")
	values.apply_plant_penalty(target, "damage", 0.1, 20.0, "微寒")
	values.apply_plant_penalty(target, "haste", 0.25, 4.0, "凝滞")
	check("攻速与伤害减益分别在加成后相乘", is_equal_approx(target.damage_multiplier(), (1.0 + damage_bonus) * 0.8)
		and is_equal_approx(target.attack_rate(), (1.0 + haste_bonus) * 0.75))
	target.sleep_until = 6.0
	check("状态列来源和沉睡", "弱火" in " ".join(values.plant_effect_lines(target))
		and "沉睡" in " ".join(values.plant_effect_lines(target)))
	var round_trip := Sim.new()
	round_trip.restore(JSON.parse_string(JSON.stringify(values.serialize())))
	check("减益随存档往返", is_equal_approx(round_trip.main_plant_at(3, 0).damage_penalty, 0.2))
	values.time = 4.1
	values.refresh_plant_buffs()
	check("到期减益归零", target.damage_penalty == 0.0 and target.haste_penalty == 0.0)
	var armored := values.spawn_zombie("straw", 0)
	values.damage_zombie(armored, armored.max_armor * 0.36)
	check("护具缺口触发 60 到 100 毫秒顿帧", values.hit_stop_requested >= 0.06 and values.hit_stop_requested <= 0.10)
	sim.request_hit_stop(0.09)
	var before := float(sim.time)
	game._tick_battle(0.016)
	game._tick_battle(0.016)
	check("画面顿帧时模拟时钟继续前进", sim.visual_hold and float(sim.time) > before + 0.02)

	game._unhandled_input(key(KEY_1))
	check("默认数字键选卡", game.hud.card_selected == 0)
	game.rebind_key("card_1", KEY_2)
	check("重复键位安全交换", game.bound_key("card_2") == KEY_1)
	game._unhandled_input(key(KEY_2))
	check("新键位即时应用", game.hud.card_selected == -1)
	game._unhandled_input(key(KEY_BRACKETRIGHT))
	check("倍速键即时应用", game.speed > 1.0)
	game.set_setting("ui_text_size", "large")
	check("大字号生效", Ui.font_size(20) == 24)
	game.finish_run(false)
	check("结束只清当前卷并保留局末快照", game.run_slots[1].is_empty() and game.run_snapshots[1].has("sim")
		and not game.run_slots[0].is_empty())
	game._load_slots()
	check("三卷与快照真实写盘", game.run_snapshots[1].has("result") and float(game.run_slots[0].sim.time) == 39.0)
	game.set_run_slot(0)
	game.clear_run()
	game._load_slots()
	check("清档后旧单槽不会再次迁移", game.run_slots[0].is_empty() and game.run_snapshots[1].has("result"))
	for path in ["run.json", "run-slots.json", "settings.json", "records.json"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(game.test_directory.path_join(path)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.test_directory))
	var report := {"total": total, "failures": failures}
	var out := FileAccess.open("res://qa/v051-refresh-tests.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(report))
	out.close()
	print("TOTAL ", total, " FAILURES ", failures)
	quit(0 if failures == 0 else 1)
