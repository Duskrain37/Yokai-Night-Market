## 战场底图：三天地图的绘制底 + 一块有透视的「舞台台面」。
##
## 台面是按深度收窄的梯形：远处窄、近处宽，行线水平、列线向远处汇聚；
## 格子、水面、障碍物、射程提示、门神都按同一套投影画，单位也随深度缩放，
## 所以战场是摆进布景里的，而不是贴上去的一张平面网格。
##
## 「场内地图是否描格子」是设置项：关掉后不画格线，台面与外框仍在。
class_name BoardView
extends Node2D

var sim: Sim = null
var show_grid = true
var hover_cell = Vector2i(-1, -1)
var focus_cell = Vector2i(-1, -1)
var range_hint = 0.0
var range_cells = 0.0
var map_key = "street"
var dim = 0.16
var _textures: Dictionary = {}
var _time = 0.0
var _guardian: Texture2D = null
var mower_art: Dictionary = {}
var obstacle_art: Dictionary = {}


func _ready() -> void:
	z_index = 0
	_guardian = Ui.sprite("guardian")
	for kind in ["market", "water"]:
		for variant in [1, 2, 3]:
			var key = "%s-%d" % [kind, variant]
			obstacle_art[key] = load("res://assets/sprites/obstacle-%s.png" % key)


func set_map(key: String) -> void:
	map_key = key
	# 切底图同时切舞台：每天的台面在画里的位置不一样
	Geo.set_stage(key)
	if not _textures.has(key):
		var path := "res://assets/bg/map-%s.png" % key
		if not ResourceLoader.exists(path):
			path = "res://assets/bg/map-%s.jpg" % key
		if not ResourceLoader.exists(path):
			path = "res://assets/bg/map-day1.png"
		if not ResourceLoader.exists(path):
			path = "res://assets/bg/map-day1.jpg"
		_textures[key] = load(path)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	_draw_background()
	_draw_stage()
	_draw_tiles()
	if show_grid:
		_draw_grid()
	else:
		_draw_row_lines()
	_draw_hover()
	_draw_range_hint()
	_draw_mowers()


# ── 投影小工具 ──────────────────────────────────────────────────────────────
static func _p(u: float, t: float) -> Vector2:
	var rows = 0
	if Geo.BANDS.size() >= 2:
		rows = Geo.BANDS.size() - 1
	if rows > 0:
		var f = clampf(t, 0.0, 1.0) * float(rows)
		var idx = mini(int(f), rows - 1)
		var k = f - float(idx)
		var y = lerpf(float(Geo.BANDS[idx]), float(Geo.BANDS[idx + 1]), k)
		var half = lerpf(float(Geo.HALVES[idx]), float(Geo.HALVES[idx + 1]), k) \
			if Geo.HALVES.size() == rows + 1 else Geo.half_width_at_depth(t)
		return Vector2(Geo.STAGE_CX + (u * 2.0 - 1.0) * half, y)
	return Vector2(Geo.STAGE_CX + (u * 2.0 - 1.0) * Geo.half_width_at_depth(t),
		Geo.y_at_depth(t))


func _cell_quad(col: int, row: int) -> PackedVector2Array:
	var u0 := float(col) / Geo.COLS
	var u1 := float(col + 1) / Geo.COLS
	var t0 := float(row) / float(sim.rows)
	var t1 := float(row + 1) / float(sim.rows)
	return PackedVector2Array([_p(u0, t0), _p(u1, t0), _p(u1, t1), _p(u0, t1)])


# ── 背景 ────────────────────────────────────────────────────────────────────
func _draw_background() -> void:
	if not _textures.has(map_key):
		set_map(map_key)
	var texture: Texture2D = _textures.get(map_key)
	if texture == null:
		draw_rect(Rect2(Vector2.ZERO, Geo.VIEW), Ui.INK)
		return
	var size := texture.get_size()
	var scale := maxf(Geo.VIEW.x / size.x, Geo.VIEW.y / size.y)
	var drawn := size * scale
	var offset := (Geo.VIEW - drawn) * 0.5
	draw_texture_rect(texture, Rect2(offset, drawn), false)
	draw_rect(Rect2(Vector2.ZERO, Geo.VIEW), Color(0.02, 0.05, 0.07, dim))


# ── 台面 ────────────────────────────────────────────────────────────────────
func _draw_stage() -> void:
	# 不再画台面的黑边、护栏和台唇：关掉描格子时，草木与恶客就是直接在背景图里打。
	# 只保留一层几乎看不见的暖光与轻压暗，让单位有"落地"的感觉。
	var bands := 14
	for i in bands:
		var t0 := float(i) / bands
		var t1 := float(i + 1) / bands
		var quad := PackedVector2Array([
			_p(0.0, t0), _p(1.0, t0), _p(1.0, t1), _p(0.0, t1),
		])
		var tint := Color(0.06, 0.10, 0.12, 0.012)
		if map_key == "day2":
			tint = Color(0.10, 0.08, 0.06, 0.016)
		elif map_key == "day3":
			tint = Color(0.04, 0.10, 0.10, 0.014)
		draw_colored_polygon(quad, tint)
	# 灯下的一滩暖光：靠中前，像摊前的灯笼照下来
	var pool := _p(0.5, 0.66)
	for i in 4:
		var k := 1.0 - i * 0.22
		draw_set_transform(pool, 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, 340.0 * k, Color(1.0, 0.72, 0.36, 0.014))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_grid() -> void:
	# 只要格线，不要外框：外框会在背景上切出一条生硬的边
	var line := Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.13)
	for col in Geo.COLS + 1:
		var u := float(col) / Geo.COLS
		draw_line(_p(u, 0.0), _p(u, 1.0), line, 1.0)
	for row in sim.rows + 1:
		var t := float(row) / float(sim.rows)
		draw_line(_p(0.0, t), _p(1.0, t), line, 1.0)


## 关掉描格子也要留一道淡行界：五条行是这游戏的骨架，
## 全抹掉就只能凭感觉判断"这株到底罩不罩得住那一行"。
func _draw_row_lines() -> void:
	var line := Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.055)
	for row in sim.rows + 1:
		var t := float(row) / float(sim.rows)
		draw_line(_p(0.0, t), _p(1.0, t), line, 1.0)


# ── 格子内容：水面 / 物件 / 障碍 ────────────────────────────────────────────
func _draw_tiles() -> void:
	for row in sim.rows:
		for col in Geo.COLS:
			var tile: Dictionary = sim.tiles[row][col]
			match String(tile["kind"]):
				"water":
					_draw_water(_cell_quad(col, row), String(tile["water"]))
				"object":
					_draw_water(_cell_quad(col, row), String(tile["water"]))
					_draw_object(col, row, int(tile["obj"]))
				"blocked":
					_draw_blocked(col, row, int(tile["obj"]))


func _draw_water(quad: PackedVector2Array, kind: String) -> void:
	# 底图自己画了水道，这里只压一层极淡的提示色，避免"又刷了一遍水"
	var tint := Color(0.07, 0.20, 0.24, 0.10) if kind == "river" \
		else Color(0.08, 0.18, 0.16, 0.12)
	draw_colored_polygon(quad, tint)
	for i in 2:
		var k := 0.32 + i * 0.34
		var y := quad[0].y + (quad[3].y - quad[0].y) * k
		var wobble := sin(_time * 1.6 + quad[0].x * 0.03 + i * 1.7) * 2.0
		draw_line(Vector2(quad[0].x + 6, y + wobble),
			Vector2(quad[1].x - 6, y - wobble),
			Color(0.55, 0.86, 0.84, 0.10), 1.4)


## 两周障碍使用与底图同笔触的透明立绘，脚底随行投影。
func _obstacle_texture(kind: String, variant: int) -> Texture2D:
	var key = "%s-%d" % [kind, posmod(variant, 3) + 1]
	return obstacle_art[key]


func _paint_obstacle(kind: String, col: int, row: int, variant: int) -> void:
	var flat = Geo.cell_center(col, row, sim.rows)
	var center = Geo.to_screen(flat, sim.rows)
	var scale = Geo.scale_at_flat(flat, sim.rows) * Geo.unit_scale(sim.rows)
	var art = _obstacle_texture(kind, variant)
	var size = Vector2(68.0, 68.0) * scale
	var foot = center + Vector2(0.0, 20.0 * scale)
	draw_texture_rect(art, Rect2(foot - Vector2(size.x * 0.5, size.y), size), false)


func _draw_object(col: int, row: int, variant: int) -> void:
	_paint_obstacle("water", col, row, variant)


func _draw_blocked(col: int, row: int, variant: int) -> void:
	_paint_obstacle("market", col, row, variant)


# ── 悬停、射程、门神 ────────────────────────────────────────────────────────
func _draw_hover() -> void:
	if hover_cell.x < 0 or hover_cell.x >= Geo.COLS or hover_cell.y < 0 \
			or hover_cell.y >= sim.rows:
		return
	var quad := _cell_quad(hover_cell.x, hover_cell.y)
	draw_colored_polygon(quad, Color(1, 0.9, 0.62, 0.10))
	draw_polyline(PackedVector2Array([quad[0], quad[1], quad[2], quad[3], quad[0]]),
		Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.6), 2.0)
	var arm := 9.0
	for i in 4:
		var p := quad[i]
		var q := quad[(i + 1) % 4]
		draw_line(p, p + (q - p).normalized() * arm,
			Color(Ui.GOLD_BRIGHT.r, Ui.GOLD_BRIGHT.g, Ui.GOLD_BRIGHT.b, 0.75), 1.6)


func _draw_range_hint() -> void:
	if focus_cell.x < 0:
		return
	var flat := Geo.cell_center(focus_cell.x, focus_cell.y, sim.rows)
	var center := Geo.to_screen(flat)
	if range_hint > 0.0:
		var r := Geo.range_ellipse(flat, range_hint)
		draw_set_transform(center, 0.0, Vector2(1.0, r.y / maxf(1.0, r.x)))
		draw_arc(Vector2.ZERO, r.x, 0.0, TAU, 56,
			Color(Ui.GOLD_BRIGHT.r, Ui.GOLD_BRIGHT.g, Ui.GOLD_BRIGHT.b, 0.3), 2.0)
		draw_circle(Vector2.ZERO, r.x, Color(1, 0.86, 0.55, 0.05))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if range_cells > 0.0:
		var t := Geo.row_depth(focus_cell.y, sim.rows)
		var u0 := (float(focus_cell.x) + 0.5) / Geo.COLS
		var u1 := minf(1.0, u0 + range_cells / Geo.COLS)
		var quad := PackedVector2Array([
			_p(u0, t - 0.5 / float(sim.rows)), _p(u1, t - 0.5 / float(sim.rows)),
			_p(u1, t + 0.5 / float(sim.rows)), _p(u0, t + 0.5 / float(sim.rows)),
		])
		draw_colored_polygon(quad, Color(1, 0.85, 0.5, 0.07))
		draw_polyline(PackedVector2Array([quad[0], quad[1], quad[2], quad[3], quad[0]]),
			Color(1, 0.85, 0.5, 0.25), 1.4)


## 门神：站在本行左侧的"门"上，脚底线与该行草木一致；
## 样貌随地图换——街上是石狮，河埠口是铜锣架，暗河是石灯笼。
func _draw_mowers() -> void:
	for mower in sim.mowers:
		var row = int(mower["row"])
		var flat = Vector2(float(mower["x"]), Geo.row_y(row, sim.rows) + Geo.cell_h(sim.rows) * 0.3)
		var foot = Geo.to_screen(flat)
		var s = Geo.scale_at_flat(flat)
		var cell_h = Geo.cell_h(sim.rows)
		var alpha = 1.0 if bool(mower["ready"]) else 0.3
		var moving = bool(mower["active"])
		# 脚下的一块石台，让门神"站"在画的地面上
		draw_set_transform(foot, 0.0, Vector2(1.0, 0.34))
		draw_circle(Vector2.ZERO, 26.0 * s, Color(0, 0, 0, 0.30 * alpha))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_colored_polygon(PackedVector2Array([
			foot + Vector2(-22 * s, 0), foot + Vector2(0, -8 * s),
			foot + Vector2(22 * s, 0), foot + Vector2(0, 8 * s),
		]), Color(0.24, 0.22, 0.19, 0.9 * alpha))
		draw_colored_polygon(PackedVector2Array([
			foot + Vector2(-22 * s, 0), foot + Vector2(0, 8 * s),
			foot + Vector2(22 * s, 0), foot + Vector2(0, 26 * s),
		]), Color(0.15, 0.14, 0.12, 0.95 * alpha))
		var height = cell_h * 0.86 * s
		# 美术交付后用 mower-dayN.png；没有就退回程序画的临时样子
		var art = _mower_art()
		if art != null:
			var size = art.get_size()
			var scale = height / size.y
			var draw_size = size * scale
			draw_texture_rect(art, Rect2(
				Vector2(foot.x - draw_size.x * 0.5, foot.y + 2.0 - draw_size.y),
				draw_size), false, Color(1, 1, 1, alpha))
		else:
			match map_key:
				"day2":
					_draw_drum_gate(foot, height, alpha, moving)
				"day3":
					_draw_stone_lantern(foot, height, alpha, moving)
				_:
					if _guardian != null:
						var size = _guardian.get_size()
						var scale = height / size.y
						var draw_size = size * scale
						draw_texture_rect(_guardian, Rect2(
							Vector2(foot.x - draw_size.x * 0.5,
								foot.y + 2.0 - draw_size.y),
							draw_size), false, Color(1, 1, 1, alpha))


## 门神立绘：assets/sprites/mower-dayN.png（美术交付后放这里）
func _mower_art() -> Texture2D:
	var key = "mower-%s" % map_key
	if mower_art.has(key):
		return mower_art[key]
	var path = "res://assets/sprites/%s-v2.png" % key
	if not ResourceLoader.exists(path):
		path = "res://assets/sprites/%s.png" % key
	var texture = load(path) if ResourceLoader.exists(path) else null
	mower_art[key] = texture
	return texture


## 河埠口：一副铜锣架
func _draw_drum_gate(foot: Vector2, height: float, alpha: float, moving: bool) -> void:
	var h = height * 0.92
	var w = height * 0.5
	var wood = Color(0.26, 0.19, 0.13, alpha)
	var gold = Color(0.72, 0.55, 0.28, alpha)
	draw_rect(Rect2(foot + Vector2(-w * 0.5, -h), Vector2(w * 0.16, h)), wood)
	draw_rect(Rect2(foot + Vector2(w * 0.34, -h), Vector2(w * 0.16, h)), wood)
	draw_rect(Rect2(foot + Vector2(-w * 0.56, -h), Vector2(w * 1.12, h * 0.1)), wood)
	var gong_c = foot + Vector2(0, -h * 0.62)
	var gong_r = w * 0.46
	draw_circle(gong_c, gong_r, gold)
	draw_arc(gong_c, gong_r, 0.0, TAU, 24, Color(0.35, 0.24, 0.12, alpha), 1.6)
	draw_circle(gong_c, gong_r * 0.16, Color(0.92, 0.78, 0.45, alpha))
	if moving:
		draw_arc(gong_c, gong_r * (1.2 + 0.2 * sin(_time * 20.0)), 0.0, TAU, 20,
			Color(0.95, 0.82, 0.5, 0.4 * alpha), 2.0)


## 暗河：一盏石灯笼
func _draw_stone_lantern(foot: Vector2, height: float, alpha: float, moving: bool) -> void:
	var h = height * 0.9
	var w = height * 0.42
	var stone = Color(0.30, 0.32, 0.31, alpha)
	var stone_hi = Color(0.42, 0.44, 0.42, alpha)
	draw_rect(Rect2(foot + Vector2(-w * 0.5, -h * 0.18), Vector2(w, h * 0.18)), stone)
	draw_rect(Rect2(foot + Vector2(-w * 0.22, -h * 0.72), Vector2(w * 0.44, h * 0.56)), stone)
	var lamp = foot + Vector2(0, -h * 0.8)
	draw_circle(lamp, w * 0.5, Color(1.0, 0.78, 0.42, 0.5 * alpha + (0.25 if moving else 0.0)))
	draw_rect(Rect2(lamp + Vector2(-w * 0.42, -w * 0.42), Vector2(w * 0.84, w * 0.84)),
		Color(0.9, 0.72, 0.4, 0.55 * alpha))
	draw_colored_polygon(PackedVector2Array([
		lamp + Vector2(-w * 0.62, -w * 0.42), lamp + Vector2(w * 0.62, -w * 0.42),
		lamp + Vector2(0, -w * 1.05),
	]), stone_hi)


