## 战场单位层：草木、恶客、射弹、香火、粒子与飘字。
##
## 立绘沿用 v0.2.4 成套原画（33 张，同一画风），动作由程序化变换与特效补足：
## 每株草木、每种恶客都有各自的呼吸/摇摆/受击/出手节奏与专属光色，
## 既不换画风，也不会糊成一片。
class_name UnitView
extends Node2D

var sim: Sim = null
var health_bars = "bar"
var focus_plant: Sim.Plant = null
var hover_target = null
var shovel_mode = false
var _textures: Dictionary = {}
var _guardian: Texture2D = null
var _time = 0.0


func _ready() -> void:
	z_index = 10


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func texture_for(name: String) -> Texture2D:
	if _textures.has(name):
		return _textures[name]
	var texture = Ui.sprite(name)
	_textures[name] = texture
	return texture


# 每种草木的待机节奏（幅度, 频率），差异来自这里而不是贴图。
const PLANT_IDLE = {
	"lantern": Vector2(2.6, 1.5), "shooter": Vector2(1.4, 1.8), "wall": Vector2(0.9, 0.9),
	"bomb": Vector2(3.4, 2.2), "bell": Vector2(2.2, 1.2), "censer": Vector2(1.8, 1.1),
	"umbrella": Vector2(1.6, 0.9), "lion": Vector2(2.8, 1.6), "mushroom": Vector2(1.2, 0.8),
	"cat": Vector2(3.0, 1.4), "shell": Vector2(1.0, 1.0), "lobber": Vector2(2.4, 1.7),
	"torch": Vector2(3.2, 2.6), "star": Vector2(2.0, 1.3), "needle": Vector2(1.0, 1.6),
	"judge": Vector2(1.2, 0.8), "lily": Vector2(1.4, 0.7), "kelp": Vector2(3.0, 1.2),
}

const PLANT_GLOW = {
	"lantern": Color(1.0, 0.55, 0.3), "torch": Color(1.0, 0.5, 0.2),
	"star": Color(1.0, 0.82, 0.4), "cat": Color(1.0, 0.68, 0.38),
	"judge": Color(0.92, 0.42, 0.3), "censer": Color(0.85, 0.72, 0.55),
	"bell": Color(0.6, 0.85, 0.9), "lily": Color(0.45, 0.8, 0.75),
	"mushroom": Color(0.7, 0.85, 0.5), "kelp": Color(0.4, 0.7, 0.6),
}

const ZOMBIE_GLOW = {
	"ghost": Color(0.55, 0.75, 0.7), "tongue": Color(0.6, 0.8, 0.55),
	"mourner": Color(0.6, 0.82, 0.9), "paper": Color(0.9, 0.85, 0.72),
	"artisan": Color(0.92, 0.86, 0.7), "mountain": Color(0.7, 0.5, 0.4),
	"ironjudge": Color(0.55, 0.6, 0.65), "sedan": Color(0.85, 0.4, 0.3),
}

const ARMOR_COLORS = {
	"paper": Color("#efe6cf"), "sedan": Color("#c77a55"), "straw": Color("#d7b26a"),
	"stonehat": Color("#a8a69a"), "urn": Color("#b07a4e"), "mask": Color("#7d858a"),
	"charm": Color("#e5d4a2"),
}


func _draw() -> void:
	if sim == null:
		return
	var cell_h = Geo.cell_h(sim.rows)
	_draw_shadows(cell_h)
	for plant in sim.plants:
		_draw_plant(plant, cell_h)
	var ordered = sim.zombies.duplicate()
	ordered.sort_custom(_zombie_sort)
	for z in ordered:
		_draw_zombie(z, cell_h)
	_draw_shots()
	_draw_orbs()
	_draw_particles()
	_draw_floaters()


static func _zombie_sort(a, b) -> bool:
	if a.row != b.row:
		return a.row < b.row
	return a.pos.x < b.pos.x


func _draw_shadows(cell_h: float) -> void:
	for plant in sim.plants:
		if plant.dead:
			continue
		var foot = _plant_foot(plant, cell_h)
		var width = 30.0 if not plant.is_lily else 40.0
		draw_set_transform(foot, 0.0, Vector2(1.0, 0.34))
		draw_circle(Vector2.ZERO, width, Color(0, 0, 0, 0.28))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for z in sim.zombies:
		if z.dead:
			continue
		var height = _zombie_height(z, cell_h)
		draw_set_transform(_zombie_foot(z, cell_h), 0.0, Vector2(1.0, 0.3))
		draw_circle(Vector2.ZERO, 18.0 + height * 0.16, Color(0, 0, 0, 0.3))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _plant_foot(plant: Sim.Plant, cell_h: float) -> Vector2:
	return Vector2(plant.pos.x, plant.pos.y + cell_h * 0.34)


func _zombie_foot(z: Sim.Zombie, cell_h: float) -> Vector2:
	return Vector2(z.pos.x, z.pos.y + cell_h * 0.28)


func _zombie_height(z: Sim.Zombie, cell_h: float) -> float:
	var base = float(z.def.get("sprite_h", 104))
	return base * Geo.unit_scale(sim.rows)


# ── 草木 ────────────────────────────────────────────────────────────────────
func _draw_plant(plant: Sim.Plant, cell_h: float) -> void:
	if plant.dead:
		return
	var texture = texture_for(plant.type)
	var foot = _plant_foot(plant, cell_h)
	var height = float(plant.def.get("sprite_h", 92)) * Geo.unit_scale(sim.rows)
	var idle: Vector2 = PLANT_IDLE.get(plant.type, Vector2(1.6, 1.4))
	var phase = plant.phase
	var bob = sin(_time * idle.y + phase) * idle.x
	var sway = sin(_time * idle.y * 0.7 + phase) * 0.012
	if plant.type == "torch" or plant.type == "bomb":
		bob += sin(_time * 8.0 + phase) * 1.2
	if plant.bite_t > 0.0:
		bob += sin(_time * 40.0) * plant.bite_t * 6.0
	var recoil = -plant.recoil * 6.0
	var chosen = plant == focus_plant
	if chosen:
		_draw_halo(foot, height, Color(Ui.GOLD_BRIGHT.r, Ui.GOLD_BRIGHT.g,
			Ui.GOLD_BRIGHT.b, 0.28), 1.0)
	var glow: Color = PLANT_GLOW.get(plant.type, Color(0, 0, 0, 0))
	if glow.a > 0.0:
		var strength = 0.18 + plant.pulse * 0.5
		if plant.type == "lantern" or plant.type == "torch" or plant.type == "star":
			strength += 0.08 + sin(_time * 2.2 + phase) * 0.04
		_draw_glow(foot + Vector2(0, -height * 0.55), height * 0.85,
			Color(glow.r, glow.g, glow.b, strength))
	if texture != null:
		_sprite(texture, foot + Vector2(recoil, bob), height, false,
			Color(1, 1, 1, 1), sway)
	_draw_shell(plant, foot, height)
	_draw_upgrade_pips(plant, foot, height)


func _draw_halo(foot: Vector2, height: float, color: Color, scale: float) -> void:
	draw_set_transform(foot + Vector2(0, -height * 0.45), 0.0,
		Vector2(1.0, height / 120.0))
	for i in 3:
		draw_arc(Vector2.ZERO, 34.0 + i * 9.0, 0.0, TAU, 40, color, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_glow(center: Vector2, radius: float, color: Color) -> void:
	for i in 4:
		var t = float(i) / 4.0
		draw_circle(center, radius * (1.0 - t * 0.62),
			Color(color.r, color.g, color.b, color.a * (0.14 + t * 0.12)))


func _draw_shell(plant: Sim.Plant, foot: Vector2, height: float) -> void:
	if plant.shell <= 0.0:
		return
	var ratio = clampf(plant.shell / maxf(1.0, plant.shell_max), 0.0, 1.0)
	var pulse = plant.shell_pulse
	var center = foot + Vector2(0, -height * 0.34)
	var radius = height * 0.62 + pulse * 3.0
	var tint = Color(0.62, 0.72, 0.55, 0.34 + 0.2 * ratio)
	draw_set_transform(center, 0.0, Vector2(1.0, 0.92))
	for i in 7:
		var a = PI + (float(i) / 6.0) * PI
		var len_or = radius * (1.0 + (0.06 if i % 2 == 0 else 0.0))
		draw_line(Vector2(cos(a), sin(a)) * radius * 0.92,
			Vector2(cos(a), sin(a)) * len_or,
			Color(tint.r, tint.g, tint.b, tint.a * 0.9), 2.0)
	draw_arc(Vector2.ZERO, radius, PI, TAU, 26, tint, 3.0)
	draw_arc(Vector2.ZERO, radius * 0.86, PI, TAU, 24,
		Color(tint.r, tint.g, tint.b, tint.a * 0.5), 1.4)
	# 裂纹随耐久出现
	if ratio < 0.66:
		var crack = Color(0.1, 0.12, 0.1, 0.45)
		draw_line(Vector2(-radius * 0.5, -radius * 0.3),
			Vector2(-radius * 0.2, -radius * 0.55), crack, 1.6)
		if ratio < 0.33:
			draw_line(Vector2(radius * 0.4, -radius * 0.4),
				Vector2(radius * 0.15, -radius * 0.62), crack, 1.6)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_upgrade_pips(plant: Sim.Plant, foot: Vector2, height: float) -> void:
	var paths = Upgrades.paths_for(plant.type)
	if paths.is_empty():
		return
	var total = 0
	for path in paths:
		total += plant.tier(int(path["id"]))
	if total <= 0:
		return
	var x = foot.x - (paths.size() - 1) * 5.0
	for path in paths:
		var tier = plant.tier(int(path["id"]))
		var color = Color(String(path["color"]))
		for i in 3:
			var pos = Vector2(x + (int(path["id"]) - 1) * 6.0,
				foot.y + 7.0 - i * 6.0)
			if i < tier:
				draw_circle(pos, 2.4, color)
			else:
				draw_arc(pos, 2.4, 0, TAU, 10, Color(color.r, color.g, color.b, 0.28), 1.0)
	if total > 0:
		pass


# ── 恶客 ────────────────────────────────────────────────────────────────────
func _draw_zombie(z: Sim.Zombie, cell_h: float) -> void:
	if z.dead:
		return
	var texture = texture_for(z.type)
	var foot = _zombie_foot(z, cell_h)
	var height = _zombie_height(z, cell_h)
	var lift = 0.0
	var rotation = 0.0
	var alpha = 1.0
	var tint = Color(1, 1, 1, 1)
	var walk = sin(z.anim * 6.4) if not z.eating else 0.0
	var bob = absf(walk) * 2.6
	var lean = 0.0
	if z.eating:
		lean = 0.06 + sin(_time * 12.0) * 0.02 * (1.0 if z.eat_bite > 0.4 else 0.4)
	if z.stun_t > 0.0:
		rotation = sin(_time * 2.0 + z.phase) * 0.06
	if z.vault_arc > 0.0:
		lift = -z.vault_arc * 58.0
		rotation = z.vault_arc * 0.18
	if z.object_hop > 0.0:
		lift -= z.object_hop * 16.0
	if z.dying:
		var k = clampf(z.death_t / maxf(0.01, z.death_dur), 0.0, 1.0)
		alpha = 1.0 - k * k
		rotation += k * (0.55 if bool(z.def.get("large", false)) else 0.9)
		lift += k * 12.0
		if bool(z.def.get("large", false)):
			height *= 1.0 - k * 0.12
	if z.hurt > 0.0:
		tint = Color(1.7, 1.5, 1.4, alpha)
	else:
		tint = Color(1, 1, 1, alpha)
	var glow: Color = ZOMBIE_GLOW.get(z.type, Color(0, 0, 0, 0))
	if glow.a > 0.0 and not z.dying:
		_draw_glow(foot + Vector2(0, -height * 0.5), height * 0.6,
			Color(glow.r, glow.g, glow.b, 0.12))
	if texture != null:
		_sprite(texture, foot + Vector2(0, bob + lift + z.anim * 0.0), height, true,
			tint, rotation + lean * 0.4)
	_draw_armor(z, foot, height, lift)
	if not z.dying:
		_draw_status(z, foot, height, lift)
	if health_bars != "off" and not z.dying:
		_draw_health_bar(z, foot, height)


func _sprite(texture: Texture2D, foot: Vector2, height: float, flip: bool,
		tint: Color, rotation: float = 0.0, squash: Vector2 = Vector2.ONE) -> void:
	var size = texture.get_size()
	var scale = height / size.y
	var sx = -scale if flip else scale
	draw_set_transform(foot, rotation, Vector2(sx, scale) * squash)
	draw_texture_rect(texture, Rect2(-size.x * 0.5, -size.y, size.x, size.y), false, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_armor(z: Sim.Zombie, foot: Vector2, height: float, lift: float) -> void:
	if z.armor <= 0.0 or z.dying:
		return
	# 护具不另画一层帽子盖在立绘上：立绘本身已经有斗笠/石帽/陶瓮/铁面的画法，
	# 再叠一层会糊成一团。这里改画一圈护罩光弧 + 型号色徽记，配合头顶双段血条
	# 表示「护具先于本体」，同时不遮住角色。
	var ratio = clampf(z.armor / maxf(1.0, z.max_armor), 0.0, 1.0)
	var color: Color = ARMOR_COLORS.get(z.armor_type, Color("#d7b26a"))
	var center = foot + Vector2(0, -height * 0.44 + lift)
	var radius = height * 0.52
	var pulse = z.armor_pulse
	var alpha = 0.16 + 0.3 * ratio + pulse * 0.35
	draw_arc(center, radius, PI * 0.78, PI * 2.22, 30,
		Color(color.r, color.g, color.b, alpha), 2.6)
	draw_arc(center, radius * 0.93, PI * 0.92, PI * 2.08, 24,
		Color(color.r, color.g, color.b, alpha * 0.55), 1.4)
	for i in 3:
		var a = PI * (0.95 + i * 0.35)
		draw_line(center + Vector2(cos(a), sin(a)) * radius * 0.86,
			center + Vector2(cos(a), sin(a)) * radius,
			Color(color.r, color.g, color.b, alpha * 0.8), 1.8)
	# 型号徽记：护具颜色的小菱块
	var badge = center + Vector2(radius * 0.72, -radius * 0.62)
	var badge_size = 5.0 + ratio * 2.0
	draw_colored_polygon(PackedVector2Array([
		badge + Vector2(0, -badge_size), badge + Vector2(badge_size, 0),
		badge + Vector2(0, badge_size), badge + Vector2(-badge_size, 0),
	]), Color(color.r, color.g, color.b, 0.75 + pulse * 0.25))
	if ratio < 0.55:
		var crack = Color(0.08, 0.07, 0.06, 0.35 + (0.55 - ratio) * 0.5)
		draw_line(center + Vector2(-radius * 0.5, -radius * 0.55),
			center + Vector2(-radius * 0.16, -radius * 0.86), crack, 1.8)
		if ratio < 0.28:
			draw_line(center + Vector2(radius * 0.44, -radius * 0.5),
				center + Vector2(radius * 0.12, -radius * 0.9), crack, 1.8)


func _draw_status(z: Sim.Zombie, foot: Vector2, height: float, lift: float) -> void:
	var head = foot + Vector2(0, -height * 0.98 + lift)
	if z.slow_t > 0.0:
		var ring_color = Color(0.55, 0.82, 0.9, 0.28 + z.slow_amount * 0.3)
		draw_set_transform(foot, 0.0, Vector2(1.0, 0.34))
		draw_arc(Vector2.ZERO, 22.0, 0, TAU, 20, ring_color, 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if z.burn_t > 0.0:
		for i in 3:
			var t = _time * 6.0 + i * 2.1 + z.phase
			var pos = foot + Vector2(sin(t) * 12.0, -8.0 - absf(cos(t)) * height * 0.5)
			draw_circle(pos, 3.4, Color(1, 0.55 + 0.2 * sin(t), 0.2, 0.5))
	if z.stun_t > 0.0:
		for i in 3:
			var a = _time * 5.0 + i * TAU / 3.0
			var pos = head + Vector2(cos(a) * 16.0, -height * 0.12 + sin(a) * 5.0)
			_draw_star(pos, 3.2, Color(1, 0.9, 0.6, 0.9))
	if z.vuln_t > 0.0:
		draw_arc(head, height * 0.34, 0, TAU, 22,
			Color(0.95, 0.5, 0.35, 0.22 + z.vuln * 0.6), 1.6)
	if z.rage_t > 0.0:
		draw_arc(head, height * 0.42, 0, TAU, 22, Color(0.9, 0.45, 0.35, 0.25), 1.4)
	if z.aura_pulse > 0.0:
		draw_arc(foot + Vector2(0, -height * 0.3), height * 0.5 + z.aura_pulse * 24.0,
			0, TAU, 30, Color(0.78, 0.5, 0.4, z.aura_pulse * 0.5), 2.0)
	if z.support_pulse > 0.0:
		draw_arc(foot + Vector2(0, -height * 0.3), 26.0 + z.support_pulse * 26.0,
			0, TAU, 30, Color(0.9, 0.82, 0.58, z.support_pulse * 0.5), 2.0)


func _draw_star(center: Vector2, radius: float, color: Color) -> void:
	var points = PackedVector2Array()
	for i in 8:
		var a = -PI * 0.5 + i * PI * 0.25
		var r = radius if i % 2 == 0 else radius * 0.42
		points.append(center + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(points, color)


func _draw_health_bar(z: Sim.Zombie, foot: Vector2, height: float) -> void:
	var width = 56.0 if not bool(z.def.get("large", false)) else 72.0
	var x = foot.x - width * 0.5
	var y = foot.y - height - 14.0
	if z.vault_arc > 0.0:
		y -= z.vault_arc * 58.0
	var hp_ratio = clampf(z.hp / maxf(1.0, z.max_hp), 0.0, 1.0)
	var armor_ratio = clampf(z.armor / maxf(1.0, z.max_armor), 0.0, 1.0) \
		if z.max_armor > 0.0 else 0.0
	draw_rect(Rect2(x - 1.0, y - 1.0, width + 2.0, 8.0), Color(0, 0, 0, 0.55))
	var hp_color = Ui.GOOD.lerp(Ui.BAD, 1.0 - hp_ratio)
	draw_rect(Rect2(x, y, width * hp_ratio, 4.0), hp_color)
	if armor_ratio > 0.0:
		draw_rect(Rect2(x, y + 4.0, width * armor_ratio, 3.0),
			ARMOR_COLORS.get(z.armor_type, Ui.GOLD))
	if health_bars == "barText":
		var text = "%d" % int(ceil(z.hp))
		if z.armor > 0.0:
			text += "+%d" % int(ceil(z.armor))
		var font = Ui.body_font()
		draw_string(font, Vector2(x - 2.0, y - 5.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, width + 4.0, 13,
			Color(1, 0.95, 0.85, 0.92))


# ── 射弹 ────────────────────────────────────────────────────────────────────
func _draw_shots() -> void:
	for shot in sim.shots:
		if shot.dead:
			continue
		match shot.kind:
			"homing":
				_draw_flame(shot.pos, 9.0 if not shot.fire else 11.0, Color("#ffb45e"))
			"lob":
				draw_circle(shot.pos, 6.0, Color(0.95, 0.92, 0.82, 0.95))
				draw_circle(shot.pos, 3.4, Color(1, 0.98, 0.9, 0.95))
			"star":
				_draw_glow(shot.pos, 16.0, Color(1, 0.85, 0.45, 0.4))
				_draw_star(shot.pos, 8.0, Color("#ffe9a8"))
			_:
				_draw_pea(shot)


func _draw_pea(shot) -> void:
	var length = 26.0 if shot.big else 18.0
	var thickness = 4.0 if shot.big else 2.6
	var color = Color("#ffe9a8") if shot.big else Color(0.86, 0.78, 0.58, 0.95)
	if shot.pierce_armor:
		color = Color(0.96, 0.95, 0.88, 0.95)
		length = 30.0
		thickness = 1.8
	var tail = shot.pos - Vector2(length, 0)
	draw_line(tail, shot.pos, color, thickness)
	draw_circle(shot.pos, thickness * 0.9, Color(1, 0.96, 0.86, 0.95))
	if shot.fire:
		_draw_glow(shot.pos, 14.0, Color(1, 0.62, 0.26, 0.35))


func _draw_flame(pos: Vector2, radius: float, color: Color) -> void:
	_draw_glow(pos, radius * 2.4, Color(color.r, color.g, color.b, 0.3))
	draw_circle(pos, radius, color)
	draw_circle(pos, radius * 0.55, Color(1, 0.95, 0.8, 0.95))


# ── 香火 ────────────────────────────────────────────────────────────────────
func _draw_orbs() -> void:
	for orb in sim.orbs:
		if bool(orb["dead"]):
			continue
		var pos = Vector2(float(orb["x"]), float(orb["y"]))
		var life = float(orb["life"])
		var alpha = 1.0
		if life < 2.0:
			alpha = clampf(life / 2.0, 0.25, 1.0)
		var pulse = 1.0 + sin(_time * 4.0 + float(orb["phase"])) * 0.08
		_draw_glow(pos, 24.0 * pulse, Color(1, 0.72, 0.32, 0.5 * alpha))
		draw_circle(pos, 9.0 * pulse, Color(1, 0.86, 0.55, 0.95 * alpha))
		draw_circle(pos, 5.0 * pulse, Color(1, 0.97, 0.85, alpha))
		for i in 3:
			var a = _time * 2.0 + i * TAU / 3.0
			draw_circle(pos + Vector2(cos(a), sin(a)) * 14.0 * pulse, 1.6,
				Color(1, 0.9, 0.6, 0.55 * alpha))


# ── 粒子与飘字 ──────────────────────────────────────────────────────────────
func _draw_particles() -> void:
	for p in sim.particles:
		var life = float(p["life"])
		var max_life = maxf(0.01, float(p["max"]))
		var k = clampf(life / max_life, 0.0, 1.0)
		var color: Color = p["color"]
		var pos = Vector2(float(p["x"]), float(p["y"]))
		match String(p["kind"]):
			"ring":
				draw_arc(pos, float(p["size"]), 0.0, TAU, 40,
					Color(color.r, color.g, color.b, color.a * k), 2.4)
			"shard":
				var size = float(p["size"])
				draw_set_transform(pos, _time * 3.0 + size, Vector2(1, 1))
				draw_rect(Rect2(-size * 0.5, -size * 0.5, size, size),
					Color(color.r, color.g, color.b, color.a * k))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			_:
				draw_circle(pos, float(p["size"]), Color(color.r, color.g, color.b,
					color.a * k))


func _draw_floaters() -> void:
	var font = Ui.medium_font()
	for f in sim.floaters:
		var life = float(f["life"])
		var max_life = maxf(0.01, float(f["max"]))
		var k = clampf(life / max_life, 0.0, 1.0)
		var color: Color = f["color"]
		var size = int(f["size"])
		var pos = Vector2(float(f["x"]), float(f["y"]))
		var text = String(f["text"])
		var width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_string(font, pos - Vector2(width * 0.5, 0.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size,
			Color(0, 0, 0, 0.55 * k))
		draw_string(font, pos - Vector2(width * 0.5, 1.5), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size,
			Color(color.r, color.g, color.b, color.a * k))
