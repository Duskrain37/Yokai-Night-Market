## 十五夜平衡扫描（环比比较同长前四大波，另列新增普通波总量）：把每一夜的压力（总有效血）、需求 DPS、机器人胜负与单夜环比
## 打成一张表 + qa/curve.csv。改波次或威胁数值后跑这个，别靠手感。
##
## 运行：Godot --headless --path . --script res://tools/qa_sweep.gd
extends SceneTree

const MAX_RISE := 130.0          # 单夜需求 DPS 环比涨幅上限（超过就是断崖）
const CLEAR_WINDOW := 238.0      # 固定前四大波比较窗口；扩展总量另列，Boss 不算普通波


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa"))
	var rows: Array = []
	var prev = 0.0
	var worst_rise = 0.0
	var problems: Array = []
	for level_id in range(1,16):
		var level: Dictionary = Content.LEVELS[level_id - 1]
		var prefix=level.duplicate(true)
		prefix.waves=Array(level.waves).slice(0,12)
		var pressure = night_pressure(prefix)
		var regular=level.duplicate(true)
		if String(level.get("boss_id",""))!="":regular.waves=Array(level.waves).slice(0,-3)
		var all_pressure=night_pressure(regular)
		var dps = pressure / CLEAR_WINDOW
		var rise = 0.0 if prev <= 0.0 else (dps / prev - 1.0) * 100.0
		prev = dps
		var run = QaBot.play(level_id, 7)
		var sim = run["sim"]
		var mowers_left = 0
		for mower in sim.mowers:
			if bool(mower["ready"]):
				mowers_left += 1
		if String(run["bad"]) != "":
			problems.append("第 %d 夜模拟出错：%s" % [level_id, run["bad"]])
		if rise > MAX_RISE:
			problems.append("%s 需求 DPS 环比 +%.0f%%，超过 %.0f%% 上限" % [
				_night_name(level), rise, MAX_RISE])
		worst_rise = maxf(worst_rise, rise)
		rows.append({
			"id": level_id, "night": _night_name(level), "band": String(level["band"]),
			"map": String(level["map"]), "threat": float(level["threat"]),
			"eff": Sim.effective_threat(level), "pressure": roundi(pressure),
			"regular_pressure":roundi(all_pressure),"major_waves":Content.wave_groups(level),
			"regular_window_s":float(regular.waves[-1].t)-float(regular.waves[0].t)+40.0,
			"dps": snappedf(dps, 0.1), "rise": snappedf(rise, 0.1),
			"won": bool(run["won"]), "t": snappedf(float(sim.time), 0.1),
			"kills": sim.kills, "waves": sim.wave_index, "sun": int(sim.sun),
			"plants": sim.plants.size(), "mowers": mowers_left,
		})
	print("%-12s %-10s %5s %5s %9s %7s %7s  %-4s %6s %5s %5s %5s" % [
		"夜", "波次档", "显示", "等效", "前四波血", "基准DPS", "环比", "胜负",
		"用时", "击退", "草木", "门神"])
	for row in rows:
		print("%-12s %-10s %5.2f %5.2f %9d %7.1f %6.0f%%  %-4s %6.1f %5d %5d %5d" % [
			row["night"], row["band"], row["threat"], row["eff"], row["pressure"],
			row["dps"], row["rise"], "胜" if row["won"] else "负",
			row["t"], row["kills"], row["plants"], row["mowers"]])
	print("\n最大单夜环比 +%.0f%%（上限 +%.0f%%）" % [worst_rise, MAX_RISE])
	_check_week_opener(rows, problems)
	write_csv(rows)
	var f=FileAccess.open("res://qa/curve-v040.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"comparison":"first four major waves, equal 238s window; boss HP excluded","rows":rows,"problems":problems},"  "))
	for problem in problems:
		printerr("FAIL " + problem)
	print("SWEEP %d 夜  问题 %d" % [rows.size(), problems.size()])
	quit(0 if problems.is_empty() else 1)


## 用户定的「开局喘口气」：新一周第一夜的压力要略低于上一周最后一夜，
## 新区间由用户重新指定，前四波配方不变；旧的第3–4夜上下界不再强制，仍检查新周开局低于旧周关底。
static func _check_week_opener(rows: Array, problems: Array) -> void:
	for first in [5, 10]:
		var opener = float(rows[first]["dps"])
		var third = float(rows[first - 3]["dps"])
		var fourth = float(rows[first - 2]["dps"])
		var last = float(rows[first - 1]["dps"])
		var ok = opener < last
		print("  %s：%.0f（上周第3夜 %.0f / 第4夜 %.0f / 第5夜 %.0f）%s" % [
			String(rows[first]["night"]), opener, third, fourth, last,
			"OK" if ok else "不符"])
		if not ok:
			problems.append("%s 没有低于上一周关底压力（%.0f vs %.0f—%.0f，上周末 %.0f）" % [
				String(rows[first]["night"]), opener, third, fourth, last])


static func _night_name(level: Dictionary) -> String:
	return "%s·%s" % [String(level["day_name"]).replace("第一周", "一")
		.replace("第二周", "二").replace("第三周", "三"), String(level["name"])]


## 这一夜要吞掉多少有效血：与 Sim.queue_wave 同一套缩放。
## 出怪数用期望值（随机取整的期望就是 x 本身），不要用中位取整——那会把
## √威胁跨过 1.5 时「整组翻倍」的台阶重新造出来，测出来的曲线是假的。
static func night_pressure(level: Dictionary) -> float:
	var scale = sqrt(maxf(0.1, Sim.effective_threat(level)))
	var total = 0.0
	for wave in level["waves"]:
		for group in wave["groups"]:
			var def: Dictionary = Content.ZOMBIES[String(group[0])]
			total += maxf(1.0, float(group[1]) * scale) \
				* (float(def["hp"]) + float(def.get("armor", 0.0))) * scale
	return total


static func write_csv(rows: Array) -> void:
	var lines: Array[String] = ["night,band,map,threat,eff_threat,pressure,dps,rise_pct,"
		+ "won,time,kills,waves,sun,plants,mowers"]
	for row in rows:
		lines.append(",".join([str(row["night"]), str(row["band"]), str(row["map"]),
			str(row["threat"]), str(row["eff"]), str(row["pressure"]), str(row["dps"]),
			str(row["rise"]), "1" if row["won"] else "0", str(row["t"]), str(row["kills"]),
			str(row["waves"]), str(row["sun"]), str(row["plants"]), str(row["mowers"])]))
	var file = FileAccess.open("res://qa/curve.csv", FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
