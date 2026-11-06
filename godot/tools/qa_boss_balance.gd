## Isolated, disclosed mature-army fixture, not a full-route or human playtest.
extends SceneTree

const TACTICAL_LOADOUT = ["lantern", "needle", "firework", "wall", "shooter", "torch",
	"squash", "bomb", "gust", "lily"]

static func army(id: int,seed_value: int,profile: String="reference") -> Sim:
	var s=Sim.new()
	var tactical := profile == "reference"
	var late := id > 16 and tactical
	var loadout: Array = (TACTICAL_LOADOUT if tactical else QaBot.LOADOUT).duplicate()
	if late:
		loadout[loadout.find("squash")] = "dragon"
	s.setup(Content.get_level(id), loadout.duplicate(), "normal")
	if String(s.level.map) == "island":
		s.island_seed = seed_value
		s.tiles = s._make_tiles()
	s.rng.seed=seed_value
	s.time=500
	for col in (9 if late else 7):
		for row in s.rows:
			if String(s.tile_at(col,row).kind) in ["blocked","object"]:continue
			if String(s.tile_at(col,row).kind)=="water":s.place_free("lily",col,row)
			var type: String
			if tactical:
				type = ["lantern", "lantern", "needle", "firework", "torch", "shooter", "wall", "dragon", "wall"][col]
			else:
				type = ["lantern", "lantern", "shooter", "shooter", "wall", "censer", "umbrella"][col]
			var p=s.place_free(type,col,row)
			if p==null:continue
			if tactical:
				match col:
					0, 1, 4: p.upgrades[1] = 2
					2, 5: p.upgrades[1] = 3
					3: p.upgrades[2] = 3
					7:
						p.upgrades[2] = 2
						p.upgrades[3] = 3
			else:
				if col == 2: p.upgrades[1] = 1 if profile == "low" else 3
				if col == 3: p.upgrades[1] = 0 if profile == "low" else 2
			s.apply_hp_scale(p)
			for path in Upgrades.paths_for(type):
				for i in p.tier(int(path.id)):p.paid_incense+=int(path.tiers[i].cost)
	s.sun=500
	s.refresh_plant_buffs()
	s.wave_index=s.level.waves.size()-1
	s.queue_wave(s.level.waves[s.wave_index],s.wave_index)
	return s
## Uses the ordinary card entry point, including costs, terrain and cooldowns.
static func defend_burst(sim: Sim) -> void:
	var boss_row: int = sim.boss.body_row
	var target_rows := range(sim.rows)
	target_rows.sort_custom(func(a, b):
		return absf(float(a) - boss_row - 0.5) < absf(float(b) - boss_row - 0.5))
	var weapon = QaBot._card_index(sim, "shooter")
	var wall = QaBot._card_index(sim, "wall")
	for row in target_rows:
		if sim.main_plant_at(5, row) == null and float(sim.cards[weapon]["cd"]) <= 0.0:
			sim.try_place_card(weapon, 5, row, Vector2.ZERO)
		if sim.main_plant_at(6, row) == null and float(sim.cards[wall]["cd"]) <= 0.0:
			sim.try_place_card(wall, 6, row, Vector2.ZERO)
	# Buy a one-use counter only when it will hit an approaching crowd.
	var threatened := 0
	for z in sim.zombies:
		if z.alive() and z.boss_role == "" and z.pos.x < Geo.BOARD_X + Geo.CELL_W * 4.0:
			threatened += 1
	var fan = QaBot._card_index(sim, "gust")
	if threatened >= 9 and float(sim.cards[fan]["cd"]) <= 0.0 and sim.sun >= 325:
		for col in range(5, 9):
			for row in target_rows:
				if sim.try_place_card(fan, col, row, Vector2.ZERO):
					return
	var choices = [
		{"type": "bomb", "range": float(Content.PLANTS["bomb"]["bomb"]["radius"]), "minimum": 5},
		{"type": "squash", "range": Geo.CELL_W, "minimum": 3},
	]
	for choice in choices:
		var card = QaBot._card_index(sim, choice.type)
		if card < 0:
			continue
		if float(sim.cards[card]["cd"]) > 0.0:
			continue
		var best := Vector2i(-1, -1)
		var best_score := 0.0
		for col in range(2, Geo.COLS):
			for row in sim.rows:
				if not bool(sim.can_place_at(choice.type, col, row)["ok"]):
					continue
				var center = sim.cell_pos(col, row)
				var count := 0
				var score := 0.0
				var wake := false
				for z in sim.zombies:
					if not z.alive() or z.boss_role != "" or bool(z.def.get("ash_immune", false)):
						continue
					if center.distance_to(z.pos) > float(choice.range):
						continue
					count += 1
					score += minf(z.hp + z.armor, 1800.0) * (1.0 + (8 - col) * 0.07)
					wake = wake or z.row == row
				if count >= int(choice.minimum) and score > best_score and (choice.type != "squash" or wake):
					best_score = score
					best = Vector2i(col, row)
		if best.x >= 0 and sim.try_place_card(card, best.x, best.y, Vector2.ZERO):
			return


func _init() -> void:
	var results: Array=[]
	var failures=0
	var stages := [5, 10, 15, Content.level_id_for(4, 4), Content.level_id_for(5, 4)]
	if "--new-only" in OS.get_cmdline_user_args():
		stages = stages.slice(3)
	for id in stages:
		for profile in (["low", "reference", "high"] if id <= 15 else ["reference"]):
			for seed_value in [7,19,41]:
				var s=army(id,seed_value,profile)
				var rng=RandomNumberGenerator.new();rng.seed=seed_value
				var won=[false];var lost=[false]
				s.on_win=func():won[0]=true
				s.on_lose=func(_z):lost[0]=true
				var initial_cost=0
				for p in s.plants:initial_cost+=p.paid_incense
				for i in int(240*60):
					s.tick(1.0/60.0);s.sounds.clear();s.sound_detail.clear()
					if i % 30 == 0:
						if profile == "reference":
							defend_burst(s)
						else:
							QaBot.strategy(s, rng)
					if won[0] or lost[0]:break
				var b=s.boss
				var row={"stage":id,"profile":profile,"seed":seed_value,"fixture_cost":initial_cost,"won":won[0],"lost":lost[0],
					"combat_s":snappedf((b.died_at if b.died_at>=0 else s.time)-b.combat_at,.1),"hp":b.hp,"max_hp":b.max_hp,
					"direct_losses":b.destruction_used,"majors":b.major_count,"adds":b.add_count,"peak_adds":b.peak_adds}
				print(JSON.stringify(row));results.append(row)
				if b.destruction_used > int(b.config.destruction_budget):
					failures += 1
				# Keep legacy armies as visible comparison fixtures. The current encounter
				# is gated on the formation with tools for the new dense reinforcement wave.
				if profile == "reference" and not won[0]:
					failures += 1
	var f=FileAccess.open("res://qa/boss-balance.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"scope":"isolated normal difficulty; reference uses piercing, splash and paid reactive bombs; low/high are legacy control formations; not a full-route playtest","runs":results,"failures":failures},"  "))
	quit(0 if failures==0 else 1)
