## 二十五夜平衡扫描：环比同长前四大波，另列普通波总量。
## 打成一张表 + qa/curve.csv。改波次或威胁数值后跑这个，别靠手感。
##
## 运行：Godot --headless --path . --script res://tools/qa_sweep.gd
extends SceneTree

const MAX_RISE := 130.0          # 单夜需求 DPS 环比涨幅上限（超过就是断崖）
const CLEAR_WINDOW := 238.0      # 固定前四大波比较窗口；扩展总量另列，Boss 不算普通波


func _init() -> void:
	var record="--record-baseline" in OS.get_cmdline_user_args()
	var subset: String=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--verify-difficulty="):subset=arg.trim_prefix("--verify-difficulty=")
	var baseline_path="res://data/qa_campaign_baseline.json"
	var baseline: Dictionary={}
	var strategy_sha=FileAccess.get_sha256("res://tools/qa_bot.gd")
	if FileAccess.file_exists(baseline_path):baseline=JSON.parse_string(FileAccess.get_file_as_string(baseline_path))
	var rows: Array=[];var all_runs: Array=[];var problems: Array=[];var expected: Dictionary={}
	for difficulty in ["easy","normal","hard","nightmare"]:
		if subset!="" and difficulty!=subset:continue
		var previous=0.0
		for level in Content.LEVELS:
			if bool(level.get("special",false)):continue
			var id=int(level.id)
			var run=QaBot.play(id,7,difficulty)
			var sim=run.sim
			var key="%s:%d" % [difficulty,id]
			var current={"id":id,"difficulty":difficulty,"outcome":run.outcome,"won":run.won,"lost":run.lost,"bot_stalemate":run.bot_stalemate,"pace_ok":run.pace_ok,"t":snappedf(sim.time,.1),"cards":run.cards,"spawn_trace":run.spawn_trace,"bad":run.bad}
			all_runs.append(current)
			expected[key]={"outcome":run.outcome,"won":run.won,"max_seconds":minf(QaBot.MAX_SECONDS,maxf(600,ceil(sim.time/60)*60+60)),"spawn_trace":run.spawn_trace}
			if not String(run.bad).is_empty():problems.append(key+" simulation error: "+run.bad)
			if run.outcome in ["timeout","bot_stalemate"]:problems.append(key+" unresolved "+run.outcome)
			if run.bot_stalemate>0:problems.append(key+" required bot stalemate recovery")
			if run.won and not run.pace_ok:problems.append(key+" exceeds independent 1200s pacing ceiling")
			if not record:
				problems.append_array(compare_run(baseline,key,current,strategy_sha))
			print("CAMPAIGN ",JSON.stringify(current))
			if difficulty!="easy":continue
			var prefix=level.duplicate(true);prefix.waves=Array(level.waves).slice(0,12)
			var regular=level.duplicate(true)
			if String(level.get("boss_id",""))!="":regular.waves=Array(level.waves).slice(0,-3)
			var pressure=night_pressure(prefix);var dps=pressure/CLEAR_WINDOW
			var rise=0.0 if previous<=0 else (dps/previous-1)*100;previous=dps
			if rise>MAX_RISE:problems.append(key+" pressure rise exceeds 130%")
			rows.append({"id":id,"night":_night_name(level),"band":level.band,"map":level.map,"threat":level.threat,"eff":Sim.effective_threat(level),"pressure":roundi(pressure),"regular_pressure":roundi(night_pressure(regular)),"major_waves":Content.wave_groups(level),"regular_window_s":float(regular.waves[-1].t)-float(regular.waves[0].t)+40,"dps":snappedf(dps,.1),"rise":snappedf(rise,.1),"won":run.won,"outcome":run.outcome,"t":snappedf(sim.time,.1),"kills":sim.kills,"waves":sim.wave_index,"sun":sim.sun,"plants":sim.plants.size(),"mowers":sim.mowers.filter(func(m):return m.ready).size()})
	if not rows.is_empty():_check_week_opener(rows,problems)
	if subset=="":write_csv(rows)
	var payload={"comparison":"first four major waves, equal 238s; boss HP excluded; 100 seeded full runs, outcomes are bot-specific","strategy":QaBot.STRATEGY_VERSION,"rows":rows,"runs":all_runs,"problems":problems}
	var output=FileAccess.open("res://qa/curve-v040.json" if subset=="" else "res://qa/curve-verify-%s.json" % subset,FileAccess.WRITE);output.store_string(JSON.stringify(payload,"  "));output.close()
	if record and problems.is_empty() and not "--report-only" in OS.get_cmdline_user_args():
		var file=FileAccess.open(baseline_path,FileAccess.WRITE);file.store_string(JSON.stringify({"strategy":QaBot.STRATEGY_VERSION,"strategy_sha256":strategy_sha,"content_sha256":FileAccess.get_sha256("res://data/content.gd"),"seed":7,"dt":1.0/30.0,"scope":"Recommended-loadout bot baseline. Defeats are not proof a night is impossible for players.","runs":expected},"  "));file.close()
	for problem in problems:printerr("FAIL ",problem)
	print("SWEEP ",all_runs.size()," runs FAILURES ",problems.size())
	quit(0 if problems.is_empty() else 1)


## 用户定的「开局喘口气」：新一周第一夜的压力要略低于上一周最后一夜，
## 新区间由用户重新指定，前四波配方不变；旧的第3–4夜上下界不再强制，仍检查新周开局低于旧周关底。
static func _check_week_opener(rows: Array, problems: Array) -> void:
	for first in [5, 10, 15, 20]:
		var opener = float(rows[first]["dps"])
		var third = float(rows[first - 3]["dps"])
		var fourth = float(rows[first - 2]["dps"])
		var last = float(rows[first - 1]["dps"])
		# Compare the actual normal waves as well as the common four-wave window.
		# Allow negligible rounding variation in the common window across spawn tables.
		var previous_night: Dictionary = rows[first - 1]
		var opening_night: Dictionary = rows[first]
		var full_before := float(previous_night.regular_pressure) / float(previous_night.regular_window_s)
		var full_after := float(opening_night.regular_pressure) / float(opening_night.regular_window_s)
		var ok = opener <= last * 1.02 and full_after < full_before
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
	var scale = sqrt(maxf(0.1, Sim.effective_threat(level) / Content.terrain_factor(level)))
	var total = 0.0
	for wave_no in level["waves"].size():
		var wave: Dictionary = level["waves"][wave_no]
		var mass_ratio = Content.wave_mass_ratio(level, wave_no)
		for group in wave.get("budget_groups", wave["groups"]):
			var def: Dictionary = Content.ZOMBIES[String(group[0])]
			total += maxf(1.0, float(group[1]) * scale) \
				* (float(def["hp"]) + float(def.get("armor", 0.0))) * scale * mass_ratio
	return total * Content.terrain_factor(level)


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


static func compare_run(baseline: Dictionary,key: String,current: Dictionary,strategy_sha: String) -> Array:
	var issues=[]
	var old:Dictionary=baseline.get("runs",{}).get(key,{})
	if baseline.get("strategy","")!=QaBot.STRATEGY_VERSION or baseline.get("strategy_sha256","")!=strategy_sha or old.is_empty():
		issues.append(key+" missing matching strategy baseline")
		return issues
	if bool(old.won) and not current.won:issues.append(key+" win regression")
	if float(current.t)>float(old.max_seconds):issues.append(key+" pacing regression")
	if old.spawn_trace!=current.spawn_trace:issues.append(key+" deterministic spawn trace changed; review baseline explicitly")
	return issues
