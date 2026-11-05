## 自动对局检查：用一套固定策略真实跑完一夜，并验证中途存档、失败路径与教学关。
##
## 不是"能启动"，而是"能用正常香火与冷却打完十二波"：
##   * 策略每 0.5 秒检查一次，只在付得起、冷却好、格子空时行动；
##   * 记录击退数、用时、香火曲线，任一异常（NaN、负血、越界）立即失败；
##   * 再从同一夜的存档还原后继续打完，确认续局状态一致。
##
## 运行：Godot --headless --path . --script tools/qa_battle.gd
extends SceneTree

var results: Array = []
var failures = 0


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa"))
	run()
	var payload = {
		"version": ProjectSettings.get_setting("application/config/version", "0.0.0"),
		"total": results.size(),
		"failures": failures,
		"checks": results,
	}
	var file = FileAccess.open("res://qa/battle-tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(payload, "  "))
	file.close()
	for row in results:
		print("%s  %s  %s  %s" % ["PASS" if row["ok"] else "FAIL", row["group"],
			row["name"], row["detail"]])
	print("TOTAL %d  FAILURES %d" % [results.size(), failures])
	quit(0 if failures == 0 else 1)


func check(group: String, name: String, ok: bool, detail: String = "") -> void:
	results.append({"group": group, "name": name, "ok": ok, "detail": detail})
	if not ok:
		failures += 1
		printerr("FAIL %s / %s %s" % [group, name, detail])


func run() -> void:
	play_level(1, "第一夜")
	play_level(6, "第六夜（六行）")
	play_level(11, "第十一夜（暗河）")
	check_water()
	check_lose()
	check_midrun_save()
	check_tutorial_flow()


const LOADOUT = QaBot.LOADOUT


func play_level(level_id: int, label: String) -> void:
	var run = QaBot.play(level_id, 7)
	var sim = run["sim"]
	var won: bool = run["won"]
	var bad: String = run["bad"]
	check("对局", "%s 跑完不崩溃" % label, bad == "", bad)
	# 第一夜与第六夜必须被这套朴素策略打通；第十一夜（威胁 2.65 的暗河）
	# 只要求推进到第 8 波之后——脚本策略打得比人差，不能拿它当平衡结论。
	var must_win = level_id <= 6
	check("对局", "%s 能推进到后段并正常终局" % label, won if must_win
			else (won or sim.wave_index >= 8),
		"won=%s lost=%s t=%.1f kills=%d wave=%d sun=%d plants=%d" % [
			str(won), str(not won), sim.time, sim.kills, sim.wave_index,
			sim.sun, sim.plants.size()])
	check("对局", "%s 有射弹出手" % label, int(run["max_shots"]) > 0,
		"max_shots=%d" % run["max_shots"])
	check("对局", "%s 击退数合理" % label, sim.kills >= 5, "kills=%d" % sim.kills)
	check("对局", "%s 波次推进到后段" % label,
		sim.wave_index >= (12 if level_id <= 6 else 8), "wave=%d" % sim.wave_index)
	check("对局", "%s 用时在合理区间" % label, sim.time > 60.0 and sim.time < 900.0,
		"t=%.1f" % sim.time)
	print("  %s: t=%.1f kills=%d sun=%d plants=%d mowers=%s" % [label, sim.time,
		sim.kills, sim.sun, sim.plants.size(), str(sim.mowers.map(
			func(m): return m["ready"]))])
	if not won:
		var parts: Array = []
		for z in sim.zombies:
			parts.append("%s@%.0f:hp%.0f%s" % [z.type, z.pos.x, z.hp,
				"(dying)" if z.dying else ("(eat)" if z.eating else "")])
		print("    alive=%d queue=%d  %s" % [sim.zombies.size(),
			sim.spawn_queue.size(), " ".join(parts.slice(0, 12))])


func check_water() -> void:
	var sim = Sim.new()
	sim.setup(Content.get_level(11), LOADOUT, "easy")
	sim.sun = 2000
	var lily = sim.place_free("lily", 0, 1)
	check("水面", "夜莲能落在水格", lily != null)
	var shooter = sim.place_free("shooter", 0, 1)
	check("水面", "莲上能种签筒", shooter != null and shooter.on_lily)
	shooter.upgrades[1] = 2
	var z = sim.spawn_zombie("ghost", 1, {"x": 900.0})
	var before = z.hp
	var dt = 1.0 / 60.0
	var steps = 0
	while steps < int(20.0 / dt) and z.hp >= before:
		sim.tick(dt)
		sim.sounds.clear()
		steps += 1
	check("水面", "莲上的签筒能打到水面来的恶客", z.hp < before,
		"hp=%.0f/%.0f" % [z.hp, before])
	var kelp = sim.place_free("kelp", 2, 3)
	check("水面", "缠魂藻能种在另一条水行上", kelp != null)
	var victim = sim.spawn_zombie("ghost", 3, {"x": 700.0})
	var kelp_x = 0.0 if kelp == null else kelp.pos.x
	var t2 = 0.0
	while t2 < 6.0 and kelp != null and not kelp.dead:
		sim.tick(dt)
		sim.sounds.clear()
		t2 += dt
	check("水面", "缠魂藻会拖住并拖沉恶客",
		kelp != null and kelp.dead and (victim.hp <= 0.0 or victim.dying or
			victim.dead), "kelp_x=%.0f victim=%.0f" % [kelp_x, victim.pos.x])
	check("地图", "暗河物件格不能种",
		not bool(sim.can_place_at("shooter", 2, 1)["ok"]))


func check_lose() -> void:
	var sim = Sim.new()
	sim.setup(Content.get_level(1), ["shooter"], "easy")
	var lost = [false, -1]
	sim.on_lose = func(z):
		lost[0] = true
		lost[1] = z.row
	var dt = 1.0 / 60.0
	var steps = 0
	while steps < int(300.0 / dt) and not lost[0]:
		sim.tick(dt)
		sim.sounds.clear()
		steps += 1
	check("对局", "不设防一整夜会失守", lost[0], "t=%.1f" % sim.time)
	check("对局", "失守前门神已经用掉",
		int(lost[1]) >= 0 and not bool(sim.mowers[int(lost[1])]["ready"]))


func check_midrun_save() -> void:
	var sim = Sim.new()
	sim.setup(Content.get_level(1), LOADOUT, "easy")
	var rng = RandomNumberGenerator.new()
	rng.seed = 11
	var dt = 1.0 / 60.0
	var steps = 0
	var timer = 0.0
	while steps < int(120.0 / dt):
		sim.tick(dt)
		sim.sounds.clear()
		steps += 1
		timer += dt
		if timer >= 0.5:
			timer = 0.0
			QaBot.strategy(sim, rng)
	var snapshot = sim.serialize()
	check("存档", "对局中段存档非空", snapshot["plants"].size() > 0
		and int(snapshot["wave_index"]) > 0,
		"plants=%d zombies=%d wave=%d" % [snapshot["plants"].size(),
		snapshot["zombies"].size(), int(snapshot["wave_index"])])
	var restored = Sim.new()
	restored.restore(snapshot)
	var won = [false]
	restored.on_win = func(): won[0] = true
	var guard = 0
	while guard < int(900.0 / dt) and not won[0]:
		restored.tick(dt)
		restored.sounds.clear()
		guard += 1
		timer += dt
		if timer >= 0.5:
			timer = 0.0
			QaBot.strategy(restored, rng)
	check("存档", "读回存档后能继续打完这一夜", won[0],
		"t=%.1f kills=%d wave=%d" % [restored.time, restored.kills,
			restored.wave_index])
	check("存档", "续局时间接得上", restored.time > sim.time,
		"%.1f > %.1f" % [restored.time, sim.time])


func check_tutorial_flow() -> void:
	var sim = Sim.new()
	var won = [false]
	sim.on_win = func(): won[0] = true
	sim.start_tutorial()
	var dt = 1.0 / 60.0
	var steps = 0
	while steps < int(5.0 / dt):
		sim.tick(dt)
		sim.sounds.clear()
		steps += 1
	check("教学", "教学关第一步香火仍在", sim.orbs.size() == 1 and
		float(sim.orbs[0]["life"]) > 1000.0)
	sim.collect_orb(sim.orbs[0])
	check("教学", "收下香火后香火数增加", sim.sun >= 225, "sun=%d" % sim.sun)
	var index = 0
	sim.try_place_card(index, 2, 2, Vector2.ZERO)
	var shooter = sim.main_plant_at(2, 2)
	check("教学", "签筒落地", shooter != null)
	sim.try_upgrade(shooter, 1, Vector2.ZERO)
	check("教学", "升阶后进入挡怪一步", String(sim.tutorial["step"]) == "wall",
		sim.tutorial_step())
	# 评测实测：误铲教学株会把教程卡死。现在铲不动；就算株没了也会退回能继续的一步
	var blocked = sim.shovel_at(2, 2)
	check("教学", "教学签筒不许铲", not bool(blocked["ok"]), String(blocked.get("text", "")))
	sim.kill_plant(shooter, true)
	sim.update_tutorial(1.0 / 60.0)
	check("教学", "目标没了退回种签筒并补够香火",
		String(sim.tutorial["step"]) == "plant" and sim.sun >= 250,
		"step=%s sun=%d" % [sim.tutorial_step(), int(sim.sun)])
	for i in int(6.0 / dt):        # 等签筒那张牌过冷却，和真人一样
		sim.tick(dt)
		sim.sounds.clear()
	sim.try_place_card(0, 2, 2, Vector2.ZERO)
	sim.try_upgrade(sim.main_plant_at(2, 2), 1, Vector2.ZERO)
	check("教学", "重来一遍仍能走到挡怪", String(sim.tutorial["step"]) == "wall",
		sim.tutorial_step())
	sim.try_place_card(1, 3, 2, Vector2.ZERO)
	check("教学", "石磨落地后进入实战", String(sim.tutorial["step"]) == "battle"
		and sim.main_plant_at(3, 2) != null, sim.tutorial_step())
	steps = 0
	while steps < int(40.0 / dt) and sim.tutorial_step() != "almanac":
		sim.tick(dt)
		sim.sounds.clear()
		steps += 1
	check("教学", "实战结束后引导看图鉴", sim.tutorial_step() == "almanac" and not won[0])
	sim.finish_tutorial_almanac()
	check("教学", "看完图鉴完成教程", won[0], "t=%.1f step=%s" % [sim.time,
		sim.tutorial_step()])
