extends SceneTree
func _initialize():run.call_deferred()
func run():
	var runs:Array=[];var failures:=0
	for difficulty in ["easy","normal","hard","nightmare"]:
		for week in [6,7,8]:
			var result:=QaBot.play(Content.level_id_for(week,4),7,difficulty)
			var row={"difficulty":difficulty,"week":week,"outcome":result.outcome,"t":result.sim.time,"bad":result.bad,"bot_stalemate":result.bot_stalemate,"pace_ok":result.pace_ok}
			if result.bad!="" or result.outcome in ["timeout","bot_stalemate"] or result.bot_stalemate>0 or not result.pace_ok:failures+=1
			runs.append(row);print("FINAL_CAMPAIGN ",JSON.stringify(row))
	FileAccess.open("res://qa/v070-final-campaign.json",FileAccess.WRITE).store_string(JSON.stringify({"scope":"Final three chapter fifth nights; four difficulties; seeded normal-cost recommendation bot, not human playtest or proof of impossibility","runs":runs,"failures":failures},"  "))
	print("V070 FINAL CAMPAIGN ",runs.size()," FAILURES ",failures);quit(0 if failures==0 else 1)
