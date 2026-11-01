## 无窗口逻辑检查：直接驱动 Sim，覆盖内容表、升阶约束、状态不叠加、护具、
## 三天地图规则、波次、训练场与教学关。
##
## 运行：Godot --headless --path . --script tools/qa_logic.gd
## 输出：qa/logic-tests.json 与 qa/logic-tests.log
extends SceneTree

const RULES = preload("res://tools/rules_check.gd")

var results: Array = []
var failures = 0


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa"))
	_run()
	var payload = {
		"version": ProjectSettings.get_setting("application/config/version", "0.0.0"),
		"total": results.size(),
		"failures": failures,
		"checks": results,
	}
	var file = FileAccess.open("res://qa/logic-tests.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(payload, "  "))
	file.close()
	for row in results:
		print("%s  %s  %s" % ["PASS" if row["ok"] else "FAIL", row["group"], row["name"]])
	print("TOTAL %d  FAILURES %d" % [results.size(), failures])
	quit(0 if failures == 0 else 1)


func check(group: String, name: String, ok: bool, detail: String = "") -> void:
	results.append({"group": group, "name": name, "ok": ok, "detail": detail})
	if not ok:
		failures += 1
		printerr("FAIL %s / %s %s" % [group, name, detail])


func _run() -> void:
	RULES.run_all(self)


func sim_for(level_id: int, loadout: Array = [], difficulty: String = "easy") -> Sim:
	var sim = Sim.new()
	var ids = loadout
	if ids.is_empty():
		ids = Content.PLANT_ORDER.slice(0, 10)
	sim.setup(Content.get_level(level_id), ids, difficulty)
	return sim


func step(sim: Sim, seconds: float, dt: float = 1.0 / 60.0) -> void:
	var count = int(round(seconds / dt))
	for i in count:
		sim.tick(dt)
		sim.sounds.clear()
		sim.sound_detail.clear()
