## Full normal-economy route. No free plants, bonus damage, HP scaling or invulnerability.
extends SceneTree
func _init() -> void:
	var results: Array=[]
	for id in [5,10,15]:
		var run=QaBot.play(id,7,"normal")
		var s: Sim=run.sim
		var row: Dictionary={"id":id,"won":run.won,"lost":run.lost,"time":s.time,"wave":s.wave_index,"kills":s.kills,"sun":s.sun,"plants":s.plants.size(),"bad":run.bad}
		if s.boss!=null:
			row.merge({"boss_hp":s.boss.hp,"boss_max":s.boss.max_hp,"boss_combat_at":s.boss.combat_at,
			"boss_alive_s":(s.boss.died_at if s.boss.died_at>=0 else s.time)-s.boss.combat_at,
			"direct_losses":s.boss.destruction_used,"major_count":s.boss.major_count,"adds":s.boss.add_count,"army":s.plants.map(func(p):return {"type":p.type,"c":p.col,"r":p.row,"up":p.upgrades}),"damage":s.damage_by_type})
		print(JSON.stringify(row))
		results.append(row)
	var f=FileAccess.open("res://qa/boss-full-runs.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"scope":"fixed normal-economy bot; not human playtest","runs":results},"  "))
	quit()
