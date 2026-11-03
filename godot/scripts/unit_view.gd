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
var _armor_atlas: Dictionary = {}
var _evolve_textures: Dictionary = {}


func _ready() -> void:
	z_index = 10
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# Import once before drawing. Loading textures inside _draw can produce white rectangles.
	for art in ["straw", "stonehat", "paper", "sedan", "urn", "mask"]:
		var path = "res://assets/sprites/armor-%s-atlas.png" % art
		if ResourceLoader.exists(path):
			var sheet: Texture2D = load(path)
			var cell_width = sheet.get_width() / 3.0
			for tier in [1, 2, 3]:
				var frame = AtlasTexture.new()
				frame.atlas = sheet
				frame.region = Rect2((tier - 1) * cell_width, 0, cell_width, sheet.get_height())
				_armor_atlas["%s-%d" % [art, tier]] = frame
	for id in ["sedan", "paper"]:
		var revealed = "res://assets/sprites/%s-unarmored%s.png" % [id,
			"-v2" if id == "paper" else ""]
		if ResourceLoader.exists(revealed):
			_textures[id] = load(revealed)
	# 三阶换建模：进化到顶的那条路决定这株草木的最终形态（<id>-e<路径>.png）。
	for type in Content.PLANTS:
		for path_id in [1, 2, 3]:
			var evolve_path = "res://assets/sprites/%s-e%d.png" % [type, path_id]
			if ResourceLoader.exists(evolve_path):
				_evolve_textures["%s-e%d" % [type, path_id]] = load(evolve_path)
	# v0.4 hand-painted capstones: use measured regions, never divide generated art blindly.
	if FileAccess.file_exists("res://data/evolution_art_v040.json"):
		var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/evolution_art_v040.json"))
		for type in catalog:
			var info: Dictionary=catalog[type]
			var sheet: Texture2D=load("res://"+String(info.file))
			for f in info.frames:
				var r: Array=f.region
				var atlas=AtlasTexture.new()
				atlas.atlas=sheet
				atlas.region=Rect2(r[0],r[1],r[2],r[3])
				atlas.filter_clip=true
				_evolve_textures["%s-e%d" % [type,int(f.path)]]=atlas


func _process(delta: float) -> void:
	_time += delta
	_update_armor_falls(delta)
	queue_redraw()


func texture_for(name: String) -> Texture2D:
	if _textures.has(name):
		return _textures[name]
	var texture = Ui.sprite(name)
	_textures[name] = texture
	return texture


## 三阶换建模：点到顶的那条路给出毕业立绘，还没做新模时退回原画。
func plant_texture(plant: Sim.Plant) -> Texture2D:
	var path_id = Upgrades.capstone(plant.upgrades)
	if path_id > 0:
		var evolve: Texture2D = _evolve_textures.get("%s-e%d" % [plant.type, path_id])
		if evolve != null:
			return evolve
	return texture_for(plant.type)


## 毕业路的光色直接取数据表里那条路的颜色，不另开一张表。
func capstone_color(plant: Sim.Plant) -> Color:
	var path_id = Upgrades.capstone(plant.upgrades)
	if path_id == 0:
		return Color(0, 0, 0, 0)
	for path in Upgrades.paths_for(String(plant.type)):
		if int(path["id"]) == path_id:
			return Color(String(path["color"]))
	return Color(0, 0, 0, 0)


## 毕业脚下的阵：一条路的颜色 + 缓转的三道弧，隔着一屏也认得出这株修的是哪条道。
func _draw_capstone_ring(foot: Vector2, height: float, color: Color) -> void:
	draw_set_transform(foot, 0.0, Vector2(1.0, 0.34))
	var spin = _time * 0.5
	for i in 3:
		var r = height * (0.30 + float(i) * 0.07)
		draw_arc(Vector2.ZERO, r, spin + float(i) * 1.2, spin + float(i) * 1.2 + 2.1,
			18, Color(color.r, color.g, color.b, 0.34 - float(i) * 0.07), 1.8)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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
		if z.boss_role=="":_draw_zombie(z, cell_h)
	_draw_armor_falls()
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
		if z.dead or z.boss_role!="":
			continue
		var height = _zombie_height(z, cell_h)
		draw_set_transform(_zombie_foot(z, cell_h), 0.0, Vector2(1.0, 0.3))
		draw_circle(Vector2.ZERO, 18.0 + height * 0.16, Color(0, 0, 0, 0.3))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 平面坐标 → 屏幕坐标：单位站在台面上，位置与大小都随深度变。
func _plant_foot(plant: Sim.Plant, cell_h: float) -> Vector2:
	return Geo.to_screen(plant.pos + Vector2(0.0, cell_h * 0.3), sim.rows)


func _zombie_foot(z: Sim.Zombie, cell_h: float) -> Vector2:
	return Geo.to_screen(z.pos + Vector2(0.0, cell_h * 0.26), sim.rows)


func _zombie_height(z: Sim.Zombie, cell_h: float) -> float:
	var base = float(z.def.get("sprite_h", 104))
	return base * Geo.unit_scale(sim.rows) * Geo.scale_at_flat(z.pos, sim.rows)


# ── 草木 ────────────────────────────────────────────────────────────────────
func _draw_plant(plant: Sim.Plant, cell_h: float) -> void:
	if plant.dead:
		return
	var texture = plant_texture(plant)
	var foot = _plant_foot(plant, cell_h)
	var height = float(plant.def.get("sprite_h", 92)) * Geo.unit_scale(sim.rows) \
		* Geo.scale_at_flat(plant.pos, sim.rows)
	var idle: Vector2 = PLANT_IDLE.get(plant.type, Vector2(1.6, 1.4))
	var phase = plant.phase
	var bob = sin(_time * idle.y + phase) * idle.x
	var sway = sin(_time * idle.y * 0.7 + phase) * 0.012
	if plant.type == "torch" or plant.type == "bomb":
		bob += sin(_time * 8.0 + phase) * 1.2
	if plant.bite_t > 0.0:
		bob += sin(_time * 40.0) * plant.bite_t * 6.0
	var squash = Vector2.ONE
	var recoil = -plant.recoil * 6.0
	# 出手：整株往回收一下，再弹回来（蓄力时反过来鼓一下）
	if plant.pulse > 0.01:
		recoil -= plant.pulse * 5.0
		squash = Vector2(1.0 + plant.pulse * 0.06, 1.0 - plant.pulse * 0.05)
	if plant.charge > 0.01:
		squash = Vector2(1.0 - plant.charge * 0.05, 1.0 + plant.charge * 0.07)
	# 特殊一击（例如签筒的双倍签）：一圈金色冲击 + 短暂透亮
	var special = plant.recoil > 0.55 or plant.pulse > 0.85
	if special:
		var k = clampf(maxf(plant.recoil, plant.pulse), 0.0, 1.0)
		_draw_burst(foot + Vector2(0, -height * 0.55), height * (0.5 + k * 0.5), k)
	# 残血：打蔫、偏暗、身上开裂
	var hp_ratio = clampf(plant.hp / maxf(1.0, plant.max_hp), 0.0, 1.0)
	var tint = Color(1, 1, 1, 1)
	if hp_ratio < 0.4:
		var k = 1.0 - hp_ratio / 0.4
		sway += k * 0.06
		bob += k * 3.0
		tint = Color(1.0 - k * 0.18, 1.0 - k * 0.22, 1.0 - k * 0.24, 1)
	var chosen = plant == focus_plant
	if chosen:
		_draw_halo(foot, height, Color(Ui.GOLD_BRIGHT.r, Ui.GOLD_BRIGHT.g,
			Ui.GOLD_BRIGHT.b, 0.28), 1.0)
	var glow: Color = PLANT_GLOW.get(plant.type, Color(0, 0, 0, 0))
	var cap: Color = capstone_color(plant)
	if cap.a > 0.0:
		glow = cap if glow.a <= 0.0 else glow.lerp(cap, 0.7)
	if glow.a > 0.0:
		var strength = 0.18 + plant.pulse * 0.5
		if cap.a > 0.0:
			strength += 0.10
		if plant.type == "lantern" or plant.type == "torch" or plant.type == "star":
			strength += 0.08 + sin(_time * 2.2 + phase) * 0.04
		_draw_glow(foot + Vector2(0, -height * 0.55), height * 0.85,
			Color(glow.r, glow.g, glow.b, strength))
	if cap.a > 0.0:
		_draw_capstone_ring(foot, height, cap)
	if texture != null:
		_sprite(texture, foot + Vector2(recoil, bob), height, false, tint, sway, squash)
	if hp_ratio < 0.4:
		_draw_wounds(foot + Vector2(recoil, bob), height, 1.0 - hp_ratio / 0.4)
	_draw_shell(plant, foot, height)
	_draw_upgrade_pips(plant, foot, height)
	_draw_upgrade_dot(plant, foot, height)


## 特殊一击的冲击：三圈扩散的金环 + 四散的碎光
func _draw_burst(center: Vector2, radius: float, strength: float) -> void:
	for i in 3:
		var k = clampf(strength - float(i) * 0.22, 0.0, 1.0)
		if k <= 0.0:
			continue
		draw_arc(center, radius * (0.55 + float(i) * 0.3) * (0.7 + k * 0.5),
			0.0, TAU, 26, Color(1.0, 0.86, 0.5, 0.30 * k), 2.2)
	for i in 6:
		var a = float(i) / 6.0 * TAU + _time * 2.2
		var d = radius * (0.6 + strength * 0.7)
		var p = center + Vector2(cos(a), sin(a) * 0.7) * d
		draw_circle(p, 2.2 + strength * 1.6, Color(1.0, 0.9, 0.6, 0.5 * strength))


## 能升阶又付得起的时候，头上点一颗呼吸的红点（v0.2.4 的做法）
func _draw_upgrade_dot(plant: Sim.Plant, foot: Vector2, height: float) -> void:
	if sim == null or plant.dead:
		return
	var economy = sim.sun
	var any = false
	for path in Upgrades.paths_for(String(plant.type)):
		var status = Upgrades.path_status(String(plant.type), plant.upgrades,
			int(path["id"]))
		if bool(status["ok"]) and economy >= int(status["cost"]):
			any = true
			break
	if not any:
		return
	var beat = 0.5 + 0.5 * sin(_time * 3.6 + plant.phase)
	var at = foot + Vector2(height * 0.34, -height * 0.94)
	draw_circle(at, 6.0 + beat * 1.6, Color(0.85, 0.22, 0.16, 0.28 + beat * 0.2))
	draw_circle(at, 3.4, Color(0.92, 0.24, 0.18, 0.95))
	draw_circle(at + Vector2(-1.0, -1.0), 1.2, Color(1.0, 0.72, 0.6, 0.9))


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
	var shell_texture=texture_for("shell")
	if shell_texture!=null:
		_sprite(shell_texture,foot+Vector2(height*.32,2),height*.49,false,
			Color(.78+.22*ratio,.78+.22*ratio,.78+.22*ratio,.88),.06)
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
	var squash = Vector2.ONE
	# 步态：一个周期两步，落地时压缩、抬脚时拉长，配合前后摇摆与前倾
	var step = z.anim * 7.4 + z.phase
	var sway = 0.0
	var bob = 0.0
	var lean = 0.0
	var rock = 0.0
	var hp_ratio = clampf(z.hp / maxf(1.0, z.max_hp), 0.0, 1.0)
	if z.eating:
		# 啃食：一小口一小口地点头
		var bite = sin(_time * 11.0 + z.phase)
		lean = 0.10 + bite * 0.03
		rotation = 0.05 + bite * 0.02
		squash = Vector2(1.03, 0.97)
	elif z.stun_t <= 0.0 and z.vault_arc <= 0.0:
		var prev = sin(step - 0.35)
		var cur = sin(step)
		bob = -absf(cur) * 4.4
		sway = sin(step * 0.5) * 1.6
		lean = 0.035 + absf(cos(step)) * 0.02
		rock = sin(step * 0.5) * 0.028
		# 触地瞬间压一下（prev 与 cur 变号即落地）
		if prev * cur < 0.0 and absf(cur) < 0.28:
			squash = Vector2(1.05, 0.95)
		else:
			squash = Vector2(1.0 - absf(cur) * 0.02, 1.0 + absf(cur) * 0.03)
		# 脚底的尘土：落地那一下
		if prev * cur < 0.0 and absf(cur) < 0.2:
			var puff = (1.0 - absf(cur) / 0.2) * 0.5
			_puff(foot + Vector2(-6.0, 0.0), 4.0 + puff * 4.0, puff)
	if z.stun_t > 0.0:
		rotation = sin(_time * 2.0 + z.phase) * 0.07
		lean = 0.0
	if z.vault_arc > 0.0:
		lift = -z.vault_arc * 58.0
		rotation = z.vault_arc * 0.2
	if z.object_hop > 0.0:
		lift -= z.object_hop * 16.0
	if z.dying:
		var k = clampf(z.death_t / maxf(0.01, z.death_dur), 0.0, 1.0)
		alpha = 1.0 - k * k
		rotation += k * (0.55 if bool(z.def.get("large", false)) else 0.9)
		lift += k * 14.0
		squash = Vector2(1.0 + k * 0.12, 1.0 - k * 0.18)
	# 受伤闪白；减速偏青、冻结偏蓝白
	var tint = Color(1, 1, 1, alpha)
	if z.hurt > 0.0:
		tint = Color(1.7, 1.5, 1.4, alpha)
	elif z.slow_t > 0.0 and z.slow_amount >= 0.5:
		# 冻得厉害：整只偏蓝白，像结了霜
		tint = Color(0.70, 0.88, 1.14, alpha)
	elif z.slow_t > 0.0:
		tint = Color(0.84, 0.96, 1.06, alpha)
	var glow: Color = ZOMBIE_GLOW.get(z.type, Color(0, 0, 0, 0))
	if glow.a > 0.0 and not z.dying:
		_draw_glow(foot + Vector2(0, -height * 0.5), height * 0.6,
			Color(glow.r, glow.g, glow.b, 0.12))
	if texture != null:
		_sprite(texture, foot + Vector2(sway, bob + lift), height, true, tint,
			rotation + lean * 0.35, squash)
	else:
		# 没有立绘时的保底：画一个会走的影子
		draw_circle(foot + Vector2(0, -height * 0.3 + bob), height * 0.2,
			Color(0.6, 0.62, 0.6, 0.8))
	# 残血：身上开裂、脚下渗影
	if hp_ratio < 0.36 and not z.dying:
		_draw_wounds(foot + Vector2(sway, bob + lift), height, 1.0 - hp_ratio / 0.36)
	_draw_armor(z, foot + Vector2(sway, bob + lift), height, texture,
		rotation + lean * 0.35, squash)
	if not z.dying:
		_draw_status(z, foot, height, lift)
	if health_bars != "off" and not z.dying:
		_draw_health_bar(z, foot, height)


## 脚底扬尘
func _puff(at: Vector2, radius: float, strength: float) -> void:
	var a = 0.16 + strength * 0.22
	draw_set_transform(at, 0.0, Vector2(1.0, 0.36))
	draw_circle(Vector2.ZERO, radius * 1.8, Color(0.78, 0.72, 0.6, a * 0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 残血的伤口：几道深色裂口 + 边缘发暗，代替"只是一个圈"
func _draw_wounds(at: Vector2, height: float, severity: float) -> void:
	var k = clampf(severity, 0.0, 1.0)
	var ink = Color(0.10, 0.05, 0.05, 0.35 + k * 0.4)
	for i in 3:
		var base = Vector2((float(i) - 1.0) * height * 0.16, -height * (0.34 + float(i) * 0.14))
		var tip = base + Vector2(height * (0.06 + 0.04 * float(i)), -height * 0.1)
		draw_line(at + base, at + tip, ink, 1.6 + k * 1.2)
		if k > 0.5:
			draw_line(at + tip, at + tip + Vector2(-height * 0.05, height * 0.07),
				ink, 1.2)


func _sprite(texture: Texture2D, foot: Vector2, height: float, flip: bool,
		tint: Color, rotation: float = 0.0, squash: Vector2 = Vector2.ONE) -> void:
	var size = texture.get_size()
	var scale = height / size.y
	var sx = -scale if flip else scale
	draw_set_transform(foot, rotation, Vector2(sx, scale) * squash)
	draw_texture_rect(texture, Rect2(-size.x * 0.5, -size.y, size.x, size.y), false, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 护具不再用一圈光弧表示：按"斗笠/石帽/陶瓮/铁面"画成有形状的实物，
## 血量掉到 2/3、1/3 时出现缺口与裂纹，归零时整块掉落。
var _armor_memory: Dictionary = {}     # zid -> {ratio, falling, fall_t}
var _falling: Array = []               # 正在掉落的护具碎片


## 护具用三档破损的小图（tools/paint_armor.py 画的），按血量换档：
## 完好 → 有缺口 → 残破；打碎时整块掉下去。

const ARMOR_ART = {
	"straw": "straw", "stonehat": "stonehat", "paper": "paper", "charm": "paper",
	"sedan": "sedan", "urn": "urn", "mask": "mask",
}
## 生成图已经带了各自的材质色，这里只做很轻的偏色，别把人家的画压平
const ARMOR_TINT = {
	"stonehat": Color(1.0, 1.0, 1.0, 1.0),
	"sedan": Color(1.0, 0.97, 0.94, 1.0),
	"paper": Color(1.0, 1.0, 0.98, 1.0),
}


func _armor_art_key(armor_type: String) -> String:
	return String(ARMOR_ART.get(armor_type, "straw"))


func _armor_tier(ratio: float) -> int:
	if ratio > 0.66:
		return 1
	if ratio > 0.33:
		return 2
	return 3


## 立绘本身也有留白：先量出它真正的像素范围，护具才压得准头顶
var _sprite_content_cache: Dictionary = {}


func _sprite_content(key: String, texture: Texture2D) -> Rect2:
	if _sprite_content_cache.has(key):
		return _sprite_content_cache[key]
	var rect = Rect2(Vector2.ZERO, texture.get_size())
	var image = texture.get_image()
	if image != null:
		var used = image.get_used_rect()
		if used.size.y > 0:
			rect = Rect2(used)
	_sprite_content_cache[key] = rect
	return rect


func _armor_texture(art: String, tier: int) -> Texture2D:
	var key = "%s-%d" % [art, tier]
	if _armor_atlas.has(key):
		return _armor_atlas[key]
	return Ui.sprite("armor-%s" % key)


func _draw_armor(z: Sim.Zombie, animated_foot: Vector2, height: float,
		body: Texture2D, rotation: float, squash: Vector2) -> void:
	var key = z.get_instance_id()
	var ratio = clampf(z.armor / maxf(1.0, z.max_armor), 0.0, 1.0)
	var prev = float(_armor_memory.get(key, ratio))
	# Every armor material breaks into independently moving pieces, even on a lethal hit.
	if prev > 0.01 and z.armor <= 0.0:
		for i in 5:
			_falling.append({"at": animated_foot + Vector2(0, -height * 0.7),
				"t": 0.0, "type": String(z.armor_type), "w": height * _armor_width(z),
				"part": i, "vx": (float(i) - 2.0) * 46.0,
				"vy": -60.0 - float((i * 7) % 3) * 25.0,
				"spin": (float(i) - 2.0) * 3.2})
	_armor_memory[key] = ratio
	if z.armor <= 0.0 or z.dying:
		return
	var art = _armor_art_key(String(z.armor_type))
	var tier = _armor_tier(ratio)
	var texture = _armor_texture(art, tier)
	if texture == null:
		return
	# Work in the body's local coordinates and reuse its flip, stride, lean and squash.
	var art_name = "armor-%s-%d" % [art, tier]
	var content = _armor_content(art_name, texture)
	var body_size = body.get_size() if body != null else Vector2(height, height)
	var width = body_size.y * _armor_width(z)
	var scale = width / maxf(1.0, content.size.x)
	var drawn = content.size * scale
	var top_of_body = -body_size.y
	if body != null:
		var body_box = _sprite_content(String(z.type), body)
		top_of_body += body_box.position.y
	var head_y = top_of_body + body_size.y * _armor_head_ratio(z)
	var tint: Color = ARMOR_TINT.get(String(z.armor_type), Color(1, 1, 1, 1))
	if z.armor_pulse > 0.01:
		tint = Color(tint.r + 0.4 * z.armor_pulse, tint.g + 0.35 * z.armor_pulse,
			tint.b + 0.25 * z.armor_pulse, tint.a)
	var body_scale = height / maxf(1.0, body_size.y)
	draw_set_transform(animated_foot, rotation, Vector2(-body_scale, body_scale) * squash)
	draw_texture_rect_region(texture, Rect2(Vector2(-drawn.x * 0.5,
		head_y - drawn.y), drawn), content, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 算出小图里真正有像素的区域，缓存起来（只在第一次用到时扫一遍）
var _armor_content_cache: Dictionary = {}


func _armor_content(key: String, texture: Texture2D) -> Rect2:
	if _armor_content_cache.has(key):
		return _armor_content_cache[key]
	var rect = Rect2(Vector2.ZERO, texture.get_size())
	var image = texture.get_image()
	if image != null:
		var used = image.get_used_rect()
		if used.size.x > 0 and used.size.y > 0:
			rect = Rect2(used)
	_armor_content_cache[key] = rect
	return rect


## 头顶大概在身高的什么位置（立绘有留白，按实测压到 0.75 左右）
func _armor_head_ratio(z: Sim.Zombie) -> float:
	match _armor_art_key(String(z.armor_type)):
		"sedan": return 0.54
		"paper": return 0.49
		"urn": return 0.46
		"mask": return 0.47
		"stonehat": return 0.39
		_: return 0.42


## 护具该画多宽（相对身高）：帽子宽、瓮窄一点、面具更窄
func _armor_width(z: Sim.Zombie) -> float:
	match _armor_art_key(String(z.armor_type)):
		"urn":
			return 0.46
		"mask":
			return 0.44
		"stonehat":
			return 0.62
		"paper":
			return 0.56
		"sedan":
			return 1.08
		_:
			return 0.66


## 掉落中的护具：用同一张图旋转着落下去、淡出
func _update_armor_falls(delta: float) -> void:
	for i in range(_falling.size() - 1, -1, -1):
		_falling[i]["t"] += delta
		if float(_falling[i]["t"]) > 0.8:
			_falling.remove_at(i)


func _draw_armor_falls() -> void:
	for piece in _falling:
		var t = clampf(float(piece["t"]) / 0.8, 0.0, 1.0)
		var art = _armor_art_key(String(piece["type"]))
		var texture = _armor_texture(art, 3)
		if texture == null:
			continue
		var width = float(piece["w"])
		var content = _armor_content("armor-%s-3" % art, texture)
		var part = int(piece["part"])
		var source = Rect2(content.position + Vector2(content.size.x * part / 5.0, 0),
			Vector2(content.size.x / 5.0, content.size.y))
		var drawn = source.size * (width / maxf(1.0, content.size.x))
		var at: Vector2 = piece["at"] + Vector2(float(piece["vx"]) * t,
			float(piece["vy"]) * t + 180.0 * t * t)
		var alpha = 1.0 - t
		draw_set_transform(at, t * float(piece["spin"]), Vector2(1.0, 0.9))
		draw_texture_rect_region(texture, Rect2(-drawn * 0.5, drawn), source,
			Color(1, 1, 1, alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_status(z: Sim.Zombie, foot: Vector2, height: float, lift: float) -> void:
	var head = foot + Vector2(0, -height * 0.98 + lift)
	# 减速：脚踝结霜 + 飘落的霜屑（冻得狠时还会有一层薄冰边）
	if z.slow_t > 0.0:
		var strength = clampf(z.slow_amount, 0.0, 1.0)
		draw_set_transform(foot + Vector2(0, -4), 0.0, Vector2(1.0, 0.34))
		draw_circle(Vector2.ZERO, 20.0 + strength * 10.0,
			Color(0.62, 0.86, 0.95, 0.10 + strength * 0.12))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for i in 3:
			var t = _time * 1.8 + i * 2.4 + z.phase
			var flake = foot + Vector2(sin(t) * 15.0,
				-height * (0.18 + float(i) * 0.22) - fmod(_time * 22.0 + i * 9.0, 26.0))
			draw_line(flake, flake + Vector2(0, 5.0),
				Color(0.78, 0.94, 1.0, 0.5 * strength + 0.2), 1.2)
			draw_line(flake + Vector2(-3, 1.5), flake + Vector2(3, 1.5),
				Color(0.78, 0.94, 1.0, 0.42 * strength + 0.16), 1.0)
		if strength >= 0.5:
			# 冻住的时候身上挂一层冰壳
			draw_rect(Rect2(foot + Vector2(-height * 0.26, -height * 0.86),
				Vector2(height * 0.52, height * 0.84)),
				Color(0.62, 0.86, 1.0, 0.10 + strength * 0.06))
	# 燃烧：火舌从脚下往上卷
	if z.burn_t > 0.0:
		for i in 4:
			var t = _time * 5.6 + i * 1.7 + z.phase
			var h = 0.2 + float(i) * 0.2
			var wobble = sin(t * 1.7) * 5.0
			var base = foot + Vector2(wobble, -height * h)
			var tip = base + Vector2(sin(t) * 4.0, -height * 0.16)
			draw_line(base, tip, Color(1.0, 0.52, 0.18, 0.55), 3.0 - float(i) * 0.4)
			draw_circle(tip, 2.6, Color(1.0, 0.82, 0.4, 0.5))
	# 眩晕：头顶转圈的星
	if z.stun_t > 0.0:
		for i in 3:
			var a = _time * 5.0 + i * TAU / 3.0
			var pos = head + Vector2(cos(a) * 16.0, -height * 0.12 + sin(a) * 5.0)
			_draw_star(pos, 3.2, Color(1, 0.9, 0.6, 0.9))
	# 易伤：身上浮起几道朱砂符纹，而不是一圈光环
	if z.vuln_t > 0.0:
		var k = clampf(z.vuln, 0.0, 1.0)
		var ink = Color(0.92, 0.28, 0.2, 0.45 + k * 0.4)
		for i in 3:
			var a = _time * 1.6 + float(i) * 2.1
			var r = height * (0.30 + 0.05 * float(i))
			var center = foot + Vector2(0, -height * 0.5)
			var glyph = center + Vector2(cos(a) * r * 0.8, sin(a) * r * 0.45)
			draw_line(glyph + Vector2(-3, -4), glyph + Vector2(3, 4), ink, 1.6)
			draw_line(glyph + Vector2(3, -4), glyph + Vector2(-3, 4), ink, 1.6)
	# 狂暴：红色的气
	if z.rage_t > 0.0:
		for i in 2:
			var t = _time * 3.2 + i * 2.0
			var pos = foot + Vector2(sin(t) * 14.0, -height * (0.3 + 0.1 * i))
			draw_circle(pos, 5.0, Color(0.85, 0.3, 0.22, 0.16))
	if z.aura_pulse > 0.0:
		draw_arc(foot + Vector2(0, -height * 0.3), height * 0.5 + z.aura_pulse * 24.0,
			0, TAU, 30, Color(0.78, 0.5, 0.4, z.aura_pulse * 0.4), 2.0)


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
		var at = Geo.to_screen(shot.pos)
		var look = String(shot.look)
		match look if look != "" else String(shot.kind):
			"homing":
				_draw_flame(at, 9.0 if not shot.fire else 11.0, Color("#ffb45e"))
			"lob":
				draw_circle(at, 6.0, Color(0.95, 0.92, 0.82, 0.95))
				draw_circle(at, 3.4, Color(1, 0.98, 0.9, 0.95))
			"star":
				_draw_glow(at, 16.0, Color(1, 0.85, 0.45, 0.4))
				_draw_star(at, 8.0, Color("#ffe9a8"))
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
	var at = Geo.to_screen(shot.pos)
	var prev = Geo.to_screen(shot.pos - Vector2(length, 0.0))
	var dir = (at - prev).normalized()
	draw_line(at - dir * length, at, color, thickness)
	draw_circle(at, thickness * 0.9, Color(1, 0.96, 0.86, 0.95))
	if shot.fire:
		_draw_glow(at, 14.0, Color(1, 0.62, 0.26, 0.35))


func _draw_flame(pos: Vector2, radius: float, color: Color) -> void:
	_draw_glow(pos, radius * 2.4, Color(color.r, color.g, color.b, 0.3))
	draw_circle(pos, radius, color)
	draw_circle(pos, radius * 0.55, Color(1, 0.95, 0.8, 0.95))


# ── 香火 ────────────────────────────────────────────────────────────────────
func _draw_orbs() -> void:
	var tutorial_collect = sim.tutorial != null \
		and String(sim.tutorial["step"]) == "collect"
	for orb in sim.orbs:
		if bool(orb["dead"]):
			continue
		var pos = Geo.to_screen(Vector2(float(orb["x"]), float(orb["y"])))
		if tutorial_collect and bool(orb.get("tutorial", false)):
			# 教学第一步的香火：呼吸光环 + 指引，避免"不知道该点哪儿"
			var beat = 0.5 + 0.5 * sin(_time * 3.4)
			draw_arc(pos, 26.0 + beat * 10.0, 0.0, TAU, 36,
				Color(1.0, 0.86, 0.5, 0.35 + beat * 0.45), 2.6)
			draw_arc(pos, 40.0 + beat * 14.0, 0.0, TAU, 36,
				Color(1.0, 0.8, 0.42, 0.12 + beat * 0.18), 1.6)
			var font = Ui.medium_font()
			var label = "点这里"
			var width = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
			draw_string(font, pos + Vector2(-width * 0.5, -40.0 - beat * 4.0), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1, 0.9, 0.62, 0.75 + beat * 0.25))
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
		var pos = Geo.to_screen(Vector2(float(p["x"]), float(p["y"])))
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
		var pos = Geo.to_screen(Vector2(float(f["x"]), float(f["y"])))
		var text = String(f["text"])
		var width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_string(font, pos - Vector2(width * 0.5, 0.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size,
			Color(0, 0, 0, 0.55 * k))
		draw_string(font, pos - Vector2(width * 0.5, 1.5), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size,
			Color(color.r, color.g, color.b, color.a * k))
