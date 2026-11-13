## One geometry for drawing and picking: skill markers → shell → body.
extends RefCounted

static func foot(plant, rows: int) -> Vector2:
	return Geo.to_screen(plant.pos + Vector2(0, Geo.cell_h(rows) * 0.3), rows)

static func height(plant, rows: int) -> float:
	return float(plant.def.get("sprite_h", 92)) * Geo.unit_scale(rows) * Geo.scale_at_flat(plant.pos, rows)

static func skill_rect(plant, rows: int) -> Rect2:
	var h := height(plant, rows)
	return Rect2(foot(plant, rows) + Vector2(0, -h * 0.32) - Vector2(21, 21), Vector2(42, 42))

static func upgrade_rect(plant, rows: int) -> Rect2:
	var h := height(plant, rows)
	return Rect2(foot(plant,rows)+Vector2(h*.34,-h*.94)-Vector2(12,12),Vector2(24,24))

static func body_rect(plant, rows: int) -> Rect2:
	var h := height(plant, rows)
	return Rect2(foot(plant, rows) - Vector2(h * 0.40, h), Vector2(h * 0.8, h + 12))

static func shell_rect(plant, rows: int) -> Rect2:
	var h := height(plant, rows)
	# Fixed enough to protect a small plant, restrained enough to fit a nine-column board.
	var w: float = clampf(h * 1.04, 78, 112) * (1.0 + plant.shell_pulse * 0.018)
	var size := Vector2(w, w * 941.0 / 1672.0)
	return Rect2(foot(plant, rows) - Vector2(w * 0.5, size.y * 0.76), size)

static func shell_front_uv() -> PackedVector2Array:
	# Cut follows the lower edge of the opening, using the unmodified generated art.
	return PackedVector2Array([Vector2(0, .35), Vector2(.12, .40), Vector2(.25, .455),
		Vector2(.38, .482), Vector2(.5, .493), Vector2(.62, .482),
		Vector2(.75, .455), Vector2(.88, .40), Vector2(1, .35), Vector2(1, 1), Vector2(0, 1)])

static func shell_hit(plant, rows: int, at: Vector2) -> bool:
	if plant.shell <= 0: return false
	var r := shell_rect(plant, rows)
	var local: Vector2 = (at - r.position) / r.size
	# The middle/lower shell is a separate target; the upper plant remains reachable.
	return local.x >= .05 and local.x <= .95 and local.y >= .42 and local.y <= .98

static func pick(sim: Sim, at: Vector2) -> Dictionary:
	var ordered := sim.plants.duplicate()
	ordered.reverse()
	for plant in ordered:
		if plant.dead or plant.is_lily: continue
		if bool(sim.active_skill_status(plant).exists) and skill_rect(plant, sim.rows).grow(3).has_point(at):
			return {"plant": plant, "layer": "skill"}
		if not Upgrades.paths_for(plant.type).is_empty() and upgrade_rect(plant, sim.rows).has_point(at):
			return {"plant": plant, "layer": "upgrade"}
	for plant in ordered:
		if not plant.dead and shell_hit(plant, sim.rows, at): return {"plant": plant, "layer": "shell"}
	for plant in ordered:
		if not plant.dead and body_rect(plant, sim.rows).has_point(at): return {"plant": plant, "layer": "body"}
	return {}
