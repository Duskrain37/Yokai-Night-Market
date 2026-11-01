## 战场底图：三天地图的绘制底、棋盘线框、格子状态（水/物件/障碍）、
## 悬停与射程提示、门神。
##
## 「场内地图是否描格子」是设置项（Ui/settings.show_grid）：关掉线框后棋盘仍然
## 存在，只是不再画出每一格的边，方便想看清画面的玩家。
class_name BoardView
extends Node2D

var sim: Sim = null
var show_grid = true
var hover_cell = Vector2i(-1, -1)
var focus_cell = Vector2i(-1, -1)
var range_hint = 0.0
var range_cells = 0.0
var map_key = "street"
var dim = 0.32
var _textures: Dictionary = {}
var _time = 0.0
var _guardian: Texture2D = null


func _ready() -> void:
	z_index = 0
	_guardian = Ui.sprite("guardian")


func set_map(key: String) -> void:
	map_key = key
	if not _textures.has(key):
		var path = "res://assets/bg/map-%s.jpg" % key
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
	_draw_board_floor()
	_draw_tiles()
	if show_grid:
		_draw_grid()
	_draw_hover()
	_draw_range_hint()
	_draw_mowers()


func _draw_background() -> void:
	var key = map_key
	if not _textures.has(key):
		set_map(key)
	var texture: Texture2D = _textures.get(key)
	if texture == null:
		draw_rect(Rect2(Vector2.ZERO, Geo.VIEW), Ui.INK)
		return
	var size = texture.get_size()
	var scale = maxf(Geo.VIEW.x / size.x, Geo.VIEW.y / size.y)
	var drawn = size * scale
	var offset = (Geo.VIEW - drawn) * 0.5
	draw_texture_rect(texture, Rect2(offset, drawn), false)
	# 夜色压暗：底图偏亮，压一层让单位与金线读得清。
	draw_rect(Rect2(Vector2.ZERO, Geo.VIEW), Color(0.02, 0.05, 0.07, dim))


func _draw_board_floor() -> void:
	var rect = Geo.board_rect(sim.rows)
	# 棋盘压在画出来的空地上：先铺一层半透明夜色，再压四边渐隐。
	draw_rect(rect, Color(0.02, 0.05, 0.07, 0.18))
	var edge = 26.0
	var top = rect.position
	draw_rect(Rect2(top, Vector2(rect.size.x, edge)),
		Color(0.01, 0.03, 0.05, 0.16))
	draw_rect(Rect2(Vector2(rect.position.x, rect.end.y - edge),
		Vector2(rect.size.x, edge)), Color(0.01, 0.03, 0.05, 0.16))


func _draw_tiles() -> void:
	var cell_h = Geo.cell_h(sim.rows)
	for row in sim.rows:
		for col in Geo.COLS:
			var tile: Dictionary = sim.tiles[row][col]
			var pos = Vector2(Geo.BOARD_X + col * Geo.CELL_W, Geo.BOARD_Y + row * cell_h)
			var rect = Rect2(pos, Vector2(Geo.CELL_W, cell_h))
			match String(tile["kind"]):
				"water":
					_draw_water(rect, String(tile["water"]))
				"object":
					_draw_water(rect, String(tile["water"]))
					_draw_object(rect, int(tile["obj"]))
				"blocked":
					_draw_blocked(rect, int(tile["obj"]))


func _draw_water(rect: Rect2, kind: String) -> void:
	var tint = Color(0.09, 0.24, 0.29, 0.5) if kind == "river" \
		else Color(0.10, 0.22, 0.20, 0.55)
	draw_rect(rect, tint)
	var wave = Color(0.45, 0.72, 0.72, 0.10)
	for i in 3:
		var y = rect.position.y + rect.size.y * (0.28 + i * 0.22)
		var wobble = sin(_time * 1.3 + i * 1.7 + rect.position.x * 0.02) * 3.0
		draw_line(Vector2(rect.position.x + 8.0, y + wobble),
			Vector2(rect.end.x - 8.0, y - wobble), wave, 1.6)


func _draw_object(rect: Rect2, variant: int) -> void:
	var center = rect.get_center() + Vector2(0, 6)
	var dark = Color(0.16, 0.19, 0.19, 0.9)
	match variant % 3:
		0:  # 系船石桩
			draw_rect(Rect2(center + Vector2(-9, -22), Vector2(18, 40)), dark)
			draw_rect(Rect2(center + Vector2(-13, -26), Vector2(26, 7)),
				Color(0.24, 0.27, 0.26, 0.95))
		1:  # 旧木桶
			draw_circle(center + Vector2(0, -4), 15.0, dark)
			draw_rect(Rect2(center + Vector2(-15, -12), Vector2(30, 5)),
				Color(0.30, 0.24, 0.18, 0.9))
		2:  # 破渔网架
			draw_line(center + Vector2(-16, 14), center + Vector2(16, -18),
				Color(0.30, 0.29, 0.24, 0.9), 3.0)
			draw_line(center + Vector2(-16, 14), center + Vector2(10, 16),
				Color(0.30, 0.29, 0.24, 0.9), 2.0)
			for i in 3:
				draw_line(center + Vector2(-10 + i * 7, 10),
					center + Vector2(-2 + i * 5, -8),
					Color(0.42, 0.40, 0.32, 0.45), 1.0)


func _draw_blocked(rect: Rect2, variant: int) -> void:
	var center = rect.get_center() + Vector2(0, 8)
	var body = Color(0.22, 0.18, 0.14, 0.95)
	draw_rect(Rect2(center + Vector2(-20, -24), Vector2(40, 38)), body)
	draw_rect(Rect2(center + Vector2(-22, -28), Vector2(44, 8)),
		Color(0.30, 0.25, 0.19, 0.95))
	draw_line(center + Vector2(-20, -6), center + Vector2(20, -6),
		Color(0.14, 0.11, 0.09, 0.9), 2.0)
	if variant % 2 == 1:
		draw_rect(Rect2(center + Vector2(-14, -18), Vector2(12, 10)),
			Color(0.36, 0.30, 0.22, 0.9))


func _draw_grid() -> void:
	var cell_h = Geo.cell_h(sim.rows)
	var line = Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.16)
	var strong = Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.42)
	# 交替格微亮，让九列不至于糊成一片；关掉网格时这层也一起消失。
	for row in sim.rows:
		for col in Geo.COLS:
			if (row + col) % 2 == 0:
				continue
			draw_rect(Rect2(Geo.BOARD_X + col * Geo.CELL_W,
				Geo.BOARD_Y + row * cell_h, Geo.CELL_W, cell_h),
				Color(1, 0.92, 0.78, 0.022))
	for col in Geo.COLS + 1:
		var x = Geo.BOARD_X + col * Geo.CELL_W
		draw_line(Vector2(x, Geo.BOARD_Y), Vector2(x, Geo.BOARD_Y + Geo.BOARD_H),
			line, 1.0)
	for row in sim.rows + 1:
		var y = Geo.BOARD_Y + row * cell_h
		draw_line(Vector2(Geo.BOARD_X, y), Vector2(Geo.BOARD_X + Geo.BOARD_W, y),
			line, 1.0)
	# 外框：金线双层，把棋盘从底图上框出来。
	var rect = Geo.board_rect(sim.rows)
	draw_rect(rect, strong, false, 2.0)
	draw_rect(rect.grow(4.0), Color(Ui.GOLD_DIM.r, Ui.GOLD_DIM.g, Ui.GOLD_DIM.b, 0.5),
		false, 1.0)


func _draw_hover() -> void:
	if hover_cell.x < 0:
		return
	var cell_h = Geo.cell_h(sim.rows)
	var rect = Rect2(Vector2(Geo.BOARD_X + hover_cell.x * Geo.CELL_W,
		Geo.BOARD_Y + hover_cell.y * cell_h), Vector2(Geo.CELL_W, cell_h))
	draw_rect(rect, Color(1, 0.9, 0.62, 0.09))
	draw_rect(rect, Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.55), false, 2.0)
	# 四角小折角，像纸上的记号
	var c = rect.position
	var e = rect.end
	var arm = 12.0
	for corner in [[c, 1, 1], [Vector2(e.x, c.y), -1, 1],
			[Vector2(c.x, e.y), 1, -1], [e, -1, -1]]:
		var p: Vector2 = corner[0]
		var sx: float = corner[1]
		var sy: float = corner[2]
		draw_line(p, p + Vector2(arm * sx, 0), Ui.GOLD_BRIGHT, 2.0)
		draw_line(p, p + Vector2(0, arm * sy), Ui.GOLD_BRIGHT, 2.0)


func _draw_range_hint() -> void:
	if focus_cell.x < 0:
		return
	var center = Geo.cell_center(focus_cell.x, focus_cell.y, sim.rows)
	var cell_h = Geo.cell_h(sim.rows)
	if range_hint > 0.0:
		var ring = Color(Ui.GOLD_BRIGHT.r, Ui.GOLD_BRIGHT.g, Ui.GOLD_BRIGHT.b, 0.32)
		draw_arc(center, range_hint, 0.0, TAU, 64, ring, 2.0)
		draw_circle(center, range_hint, Color(1, 0.86, 0.55, 0.05))
	if range_cells > 0.0:
		var width = range_cells * Geo.CELL_W
		var rect = Rect2(center.x, center.y - cell_h * 0.5, width, cell_h)
		draw_rect(rect, Color(1, 0.85, 0.5, 0.06))
		draw_line(Vector2(center.x, rect.position.y), Vector2(center.x + width,
			rect.position.y), Color(1, 0.85, 0.5, 0.25), 1.5)
		draw_line(Vector2(center.x, rect.end.y), Vector2(center.x + width, rect.end.y),
			Color(1, 0.85, 0.5, 0.25), 1.5)


func _draw_mowers() -> void:
	if _guardian == null:
		return
	var cell_h = Geo.cell_h(sim.rows)
	for mower in sim.mowers:
		var row = int(mower["row"])
		var x = float(mower["x"])
		var y = Geo.BOARD_Y + row * cell_h + cell_h * 0.5
		var height = cell_h * 0.8
		var alpha = 1.0 if bool(mower["ready"]) else 0.28
		var size = _guardian.get_size()
		var scale = height / size.y
		var draw_size = size * scale
		var rect = Rect2(Vector2(x - draw_size.x * 0.5, y + cell_h * 0.35 - draw_size.y),
			draw_size)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_texture_rect(_guardian, rect, false, Color(1, 1, 1, alpha))
