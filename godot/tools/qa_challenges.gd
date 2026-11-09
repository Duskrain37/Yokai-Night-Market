extends SceneTree
func _initialize():
	var rows=[]
	for entry in preload("res://data/challenges.gd").ENTRIES:
		var previous=""
		for attempt in 2:
			var run=QaBot.play(int(entry.level),int(entry.seed),"normal",{"cards":entry.cards})
			var row={"id":entry.id,"attempt":attempt,"won":run.won,"outcome":run.outcome,"trace":run.spawn_trace,"time":run.sim.time,"sun":run.sim.sun,"same_trace":attempt==0 or previous==run.spawn_trace}
			previous=run.spawn_trace;rows.append(row);print(JSON.stringify(row))
	var out=FileAccess.open("res://qa/challenge-validation.json",FileAccess.WRITE);out.store_string(JSON.stringify(rows,"  "));out.close()
	quit(0 if rows.all(func(r):return r.won and r.same_trace) else 1)
