## 选关：一周一张图，五夜沿着画中的地标前进。
##
## 复原 v0.2.4 的意境：左下是当天的题签与底细，右侧是画里的五个夜点。
## 夜里用繁体数字（第壹夜…第伍夜），比阿拉伯数字更有味道。
extends Control

const DAY_KEYS = ["day1", "day2", "day3", "day4", "day5"]
const NUMERALS = ["壹", "贰", "叁", "肆", "伍"]
## 五个夜点在画面里的相对位置（0—1），从近处往远处的门楼走
## 每晚在画里的落点：三天各沿着自己那张图的路走，从近处一路走到画深处。
const ROUTES = {
	# 落点照着手标注的街心量出来（截图 1.6 倍、上下各 82/80 黑边换算回 1600×900）：
	# 壹在街面最近处，比画框还低一截，所以 fy 超过 1；一路踩着石板往门楼收到伍
	"day1": [Vector2(0.416, 1.175), Vector2(0.408, 0.842), Vector2(0.373, 0.640),
		Vector2(0.412, 0.382), Vector2(0.351, 0.179)],
	"day2": [Vector2(0.300, 1.03), Vector2(0.330, 0.745), Vector2(0.520, 0.570),
		Vector2(0.690, 0.395), Vector2(0.810, 0.205)],
	"day3": [Vector2(0.310, 1.09), Vector2(0.400, 0.740), Vector2(0.545, 0.560),
		Vector2(0.635, 0.380), Vector2(0.575, 0.195)],
}
const PICTURE = Rect2(380, 118, 1130, 556)
const NEW_OVERVIEW_SIZE = Vector2(1672, 941)
const NEW_ROUTES = {
	# 孤灯屿：渡口、摊集、松下石拱、潮祠、山门。
	"day4": [Vector2(878, 706), Vector2(1243, 568), Vector2(1490, 410),
		Vector2(1159, 360), Vector2(824, 224)],
	# 冥判窟：洞口、吊桥、石龛、钟廊、判官门。
	"day5": [Vector2(1475, 686), Vector2(985, 611), Vector2(747, 439),
		Vector2(1039, 315), Vector2(1458, 221)],
}
const ROUTE_BENDS = {
	"day4": [[Vector2(1095, 790), Vector2(1315, 757), Vector2(1427, 669)],
		[Vector2(1431, 606), Vector2(1593, 534), Vector2(1549, 463)],
		[Vector2(1352, 427), Vector2(1207, 409)],
		[Vector2(1001, 372), Vector2(934, 344), Vector2(965, 317), Vector2(888, 276)]],
	"day5": [[Vector2(1348, 730), Vector2(1194, 627), Vector2(1095, 632)],
		[Vector2(875, 578), Vector2(809, 531), Vector2(740, 492)],
		[Vector2(836, 472), Vector2(949, 431), Vector2(1032, 390)],
		[Vector2(1141, 350), Vector2(1275, 316), Vector2(1400, 281)]],
}
const NODE_RADIUS = 34.0
const TAB_SIZE = Vector2(214, 78)

var game = null
var selected = 1
var day = 1
var _cards: Array = []          # 夜卡（供自检统计）
var _textures: Dictionary = {}
var _route_segments: Dictionary = {}
var _hover = -1
var _time = 0.0
var _enter: Button = null
var _almanac: Button = null
var _special: Button = null
var _danger: Control = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	selected = clampi(int(game.progress.get("selected", 1)), 1, Content.LEVELS.size())
	day = int(Content.get_level(selected).get("day", 1))
	for i in Content.DAYS.size():
		var path = Content.map_picture(Content.DAYS[i], true)
		if ResourceLoader.exists(path):
			_textures[DAY_KEYS[i]] = load(path)
	_build_actions()
	_refresh_actions()
	game.play_music_scene("menu")


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


# ── 夜点位置 ────────────────────────────────────────────────────────────────
func _overview_point(point: Vector2) -> Vector2:
	return point / NEW_OVERVIEW_SIZE * Geo.VIEW


func _node_pos(index: int) -> Vector2:
	var key = DAY_KEYS[day - 1]
	if NEW_ROUTES.has(key):
		return _overview_point(NEW_ROUTES[key][index])
	return PICTURE.position + PICTURE.size * ROUTES[key][index]


## 越往里（y 越小）越远，点也就越小：看着像往画里走
func _node_scale(index: int) -> float:
	var y = (_node_pos(index).y - PICTURE.position.y) / PICTURE.size.y
	return lerpf(0.72, 1.12, clampf((y - 0.24) / 0.64, 0.0, 1.0))


func _level_of(index: int) -> Dictionary:
	return Content.get_level(Content.level_id_for(day, index))


# ── 绘制 ────────────────────────────────────────────────────────────────────
func _draw() -> void:
	_draw_picture()
	_draw_tabs()
	_draw_route()
	_draw_nodes()
	_draw_footer()
	_draw_header()


func _draw_picture() -> void:
	draw_rect(Rect2(Vector2.ZERO, Geo.VIEW), Ui.INK)
	var texture: Texture2D = _textures.get(DAY_KEYS[day - 1])
	if texture != null:
		var size = texture.get_size()
		var scale = maxf(Geo.VIEW.x / size.x, Geo.VIEW.y / size.y)
		var drawn = size * scale
		var offset = (Geo.VIEW - drawn) * 0.5
		draw_texture_rect(texture, Rect2(offset, drawn), false)
	# 整体压暗，再让左侧更暗一点好放题签
	draw_rect(Rect2(Vector2.ZERO, Geo.VIEW), Color(0.02, 0.04, 0.06, 0.42))
	for i in 8:
		var k = float(i) / 8.0
		draw_rect(Rect2(0, 0, 360.0 * (1.0 - k) + 120.0, Geo.VIEW.y),
			Color(0.02, 0.03, 0.05, 0.06))
	# 画面下缘压一条暗带，给人物的字留干净底
	draw_rect(Rect2(0, Geo.VIEW.y - 150, Geo.VIEW.x, 150),
		Color(0.02, 0.03, 0.05, 0.5))


func _draw_header() -> void:
	var level = Content.get_level(selected)
	draw_string(Ui.display_font(), Vector2(760, 76),
		"%s · %s" % [level["day_name"], level["day_sub"]],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.96, 0.88, 0.7, 0.92))


func _draw_tabs() -> void:
	for i in Content.DAYS.size():
		var rect = _tab_rect(i)
		var active = (i + 1) == day and selected!=16
		var cleared = _cleared_count(i + 1)
		var base = Color(0.06, 0.09, 0.11, 0.88) if not active \
			else Color(0.22, 0.17, 0.08, 0.95)
		Ui.draw_plate(self, rect, base, Ui.GOLD if active else Color(0.34, 0.31, 0.25, 0.85),
			16, 2 if active else 1)
		var info: Dictionary = Content.DAYS[i]
		draw_string(Ui.medium_font(), rect.position + Vector2(16, 27),
			String(info["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 21,
			Ui.GOLD_BRIGHT if active else Ui.TEXT)
		draw_string(Ui.body_font(), rect.position + Vector2(16, 49),
			String(info["sub"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Ui.TEXT_DIM)
		draw_string(Ui.body_font(), rect.position + Vector2(16, 69),
			"守住 %d / 5 夜" % cleared, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
			Ui.GOOD if cleared >= 5 else Ui.TEXT_FAINT)
		if active:
			draw_circle(rect.position + Vector2(rect.size.x - 22, 22), 5.0,
				Ui.GOLD_BRIGHT)


func _tab_rect(index: int) -> Rect2:
	return Rect2(Vector2(56, 150 + index * 86), TAB_SIZE)


func _draw_route() -> void:
	var key = DAY_KEYS[day - 1]
	if not _route_segments.has(key):
		_route_segments[key] = _build_route_segments(key)
	for i in 4:
		var done = selected >= Content.level_id_for(day, i + 1)
		var color = Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.73 if done else 0.50)
		draw_multiline(_route_segments[key][i], color, 2.0, true)


func _build_route_segments(key: String) -> Array[PackedVector2Array]:
	var segments: Array[PackedVector2Array] = []
	var bends: Array = ROUTE_BENDS.get(key, [])
	for i in 4:
		var a = _node_pos(i)
		var b = _node_pos(i + 1)
		var path = Curve2D.new()
		path.add_point(a)
		if bends.is_empty():
			path.add_point(a.lerp(b, 0.5) + Vector2(0, -18), (a - b) * 0.17, (b - a) * 0.17)
		else:
			var points = PackedVector2Array([a])
			for point in bends[i]:
				points.append(_overview_point(point))
			points.append(b)
			for j in range(1, points.size() - 1):
				var tangent = (points[j + 1] - points[j - 1]) * 0.13
				path.add_point(points[j], -tangent, tangent)
		path.add_point(b)
		var length = path.get_baked_length()
		var dashes = PackedVector2Array()
		for start in range(0, ceili(length), 18):
			dashes.append(path.sample_baked(start))
			dashes.append(path.sample_baked(minf(start + 8.0, length)))
		segments.append(dashes)
	return segments


func _draw_centered_line(font: Font, value: String, center_x: float, baseline: float,
		font_size: int, color: Color) -> void:
	var width = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(center_x - width * 0.5, baseline), value,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_centered_glyph(font: Font, value: String, center: Vector2,
		font_size: int, color: Color) -> void:
	var rid = font.get_rids()[0]
	var server = TextServerManager.get_primary_interface()
	var glyph = font.get_glyph_index(font_size, value.unicode_at(0), 0)
	var offset = server.font_get_glyph_offset(rid, Vector2i(font_size, 0), glyph)
	var ink_size = server.font_get_glyph_size(rid, Vector2i(font_size, 0), glyph)
	draw_char(font, center - offset - ink_size * 0.5, value, font_size, color)


func _draw_nodes() -> void:
	for i in 5:
		var level = _level_of(i)
		var pos = _node_pos(i)
		var is_selected = int(level["id"]) == selected
		var is_hover = _hover == i
		var cleared: bool = Array(game.progress.get("cleared", [])).has(
			int(level["id"]))
		var depth = _node_scale(i)
		var radius = NODE_RADIUS * depth * (1.16 if is_selected else (1.06 if is_hover else 1.0))
		# 光晕
		if is_selected:
			var beat = 0.5 + 0.5 * sin(_time * 2.4)
			draw_circle(pos, radius + 16.0 + beat * 5.0,
				Color(1.0, 0.78, 0.42, 0.10 + beat * 0.07))
		draw_circle(pos, radius, Color(0.05, 0.07, 0.09, 0.9))
		draw_arc(pos, radius, 0.0, TAU, 40,
			Ui.GOLD_BRIGHT if is_selected else Color(0.72, 0.58, 0.32, 0.75),
			2.6 if is_selected else 1.8)
		draw_arc(pos, radius - 5.0, 0.0, TAU, 36,
			Color(0.9, 0.75, 0.45, 0.25), 1.0)
		# 夜里的繁体数字
		var numeral = NUMERALS[i]
		_draw_centered_glyph(Ui.display_font(), numeral, pos, roundi(30 * depth),
			Ui.GOLD_BRIGHT if is_selected else Ui.PAPER_DIM)
		# 名字
		var label = "第%s夜" % numeral
		_draw_centered_line(Ui.medium_font(), label, pos.x, pos.y + radius + 24 * depth,
			roundi(18 * maxf(0.8, depth)),
			Ui.TEXT if is_selected else Ui.TEXT_DIM)
		var tag = String(level["tag"])
		_draw_centered_line(Ui.body_font(), tag, pos.x, pos.y + radius + 42, 13, Ui.TEXT_FAINT)
		if cleared:
			var tick = pos + Vector2(radius * 0.72, -radius * 0.72)
			draw_circle(tick, 8.0, Color(0.36, 0.62, 0.4, 0.95))
			_draw_centered_line(Ui.body_font(), "✓", tick.x, tick.y + 4.0, 12,
				Color(0.95, 0.99, 0.93))
			# 星级挂在夜名下：重打一局是为了把 ☆ 刷成 ★
			var stars = clampi(int(Dictionary(game.progress.get("stars", {}))
				.get(str(int(level["id"])), 0)), 0, 3)
			var mark = "★★★".substr(0, stars) + "☆☆☆".substr(0, 3 - stars)
			_draw_centered_line(Ui.body_font(), mark, pos.x, pos.y + radius + 58, 14,
				Ui.GOLD_BRIGHT if stars >= 3 else Ui.GOLD_DIM)


func _draw_footer() -> void:
	var panel = Rect2(56, 596, 610, 268)
	Ui.draw_plate(self, panel, Color(0.03, 0.05, 0.07, 0.9),
		Color(Ui.GOLD_DIM.r, Ui.GOLD_DIM.g, Ui.GOLD_DIM.b, 0.75), 20, 2)
	var level = Content.get_level(selected)
	var x = panel.position.x + 24
	var y = panel.position.y + 40
	draw_string(Ui.display_font(), Vector2(x, y),
		("鬼市深处 · 终极挑战" if selected==16 else "第%s夜 · %s" % [NUMERALS[int(level.get("night", 0))],level["tag"]]), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Ui.GOLD_BRIGHT)
	y += 34
	var rows = [
		["凶险", ""],
		["棋盘", "%d 行 × 9 列 · %d 大波" % [int(level["rows"]),
			Content.wave_groups(level)]],
		["起手香火", str(int(level["start_sun"]))],
	]
	for row in rows:
		draw_string(Ui.body_font(), Vector2(x, y), String(row[0]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Ui.TEXT_DIM)
		draw_string(Ui.body_font(), Vector2(x + 84, y), String(row[1]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Ui.TEXT)

		y += 26
	var seen = Content.plants_in_level(level)
	var names = PackedStringArray()
	for type in seen:
		names.append(String(Content.ZOMBIES[type]["name"]))
	draw_string(Ui.body_font(), Vector2(x, y), "今夜恶客", HORIZONTAL_ALIGNMENT_LEFT,
		-1, 15, Ui.TEXT_DIM)
	# 按实际宽度换行，来客较多的关底也能读完。
	var font = Ui.body_font()
	var max_width = panel.end.x - x - 108.0
	var line = ""
	var line_y = y
	for name in names:
		if font.get_string_size(line + name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x > max_width:
			draw_string(font, Vector2(x + 84, line_y), line,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Ui.TEXT)
			line_y += 20
			line = ""
		line += name + " "
	if line != "":
		draw_string(font, Vector2(x + 84, line_y), line,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Ui.TEXT)


# ── 交互 ────────────────────────────────────────────────────────────────────
func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		game.show_menu()
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	var pos: Vector2 = event.position
	# 夜点
	for i in 5:
		if pos.distance_to(_node_pos(i)) <= NODE_RADIUS + 12.0:
			select_night(i)
			accept_event()
			return
	# 三天的题签
	for i in Content.DAYS.size():
		if _tab_rect(i).has_point(pos):
			select_day(i + 1)
			accept_event()
			return


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hover = -1
		for i in 5:
			if event.position.distance_to(_node_pos(i)) <= NODE_RADIUS + 12.0:
				hover = i
		if hover != _hover:
			_hover = hover
			queue_redraw()


func select_day(value: int) -> void:
	if value == day and selected!=16:
		return
	day = clampi(value, 1, Content.DAYS.size())
	# 换日时默认选回这一天的第一夜
	selected = Content.level_id_for(day)
	_refresh_actions()
	queue_redraw()
	game.play_sfx("click")


func select_night(index: int) -> void:
	selected = Content.level_id_for(day, index)
	_refresh_actions()
	queue_redraw()
	game.play_sfx("click")


func _build_actions() -> void:
	var back = Ui.button("← 回封面", 18, 130, 42)
	back.position = Vector2(56, 40)
	back.pressed.connect(func(): game.show_menu())
	add_child(back)

	_danger=preload("res://ui/threat_meter.gd").new()
	_danger.position=Vector2(164,658);_danger.size=Vector2(270,16)
	add_child(_danger)

	_enter = Ui.button("进入备战", 20, 240, 52)
	_enter.position = Vector2(92, 796)
	_enter.pressed.connect(func(): game.show_prep(selected))
	add_child(_enter)

	_special=Ui.button("特殊关 · 鬼市深处",16,214,46)
	_special.position=Vector2(56,88)
	_special.pressed.connect(func(): switch_to_level(16);game.play_sfx("click"))
	add_child(_special)

	_almanac = Ui.button("看恶客图鉴", 16, 180, 38)
	_almanac.position = Vector2(352, 804)
	_almanac.pressed.connect(func(): game.open_almanac("zombie", 0))
	add_child(_almanac)


func _refresh_actions() -> void:
	if _danger!=null:
		_danger.values=Content.SPECIAL_THREATS if selected==Content.SPECIAL_ID else [float(Content.get_level(selected).threat)]
		_danger.queue_redraw()
	if _enter != null:
		var level = Content.get_level(selected)
		_enter.text = "进入鬼市深处" if selected==16 else "进入第%s夜" % NUMERALS[int(level.get("night", 0))]
	if _special!=null:Ui.set_button_active(_special,selected==16)


## 对外：十五夜总数与直接跳到某一夜（自检与继续游戏用）
func night_total() -> int:
	return Content.LEVELS.size()


func switch_to_level(level_id: int) -> void:
	selected = clampi(level_id, 1, Content.LEVELS.size())
	day = int(Content.get_level(selected).get("day", 1))
	_refresh_actions()
	queue_redraw()


func _cleared_count(day_index: int) -> int:
	var cleared: Array = game.progress.get("cleared", [])
	var count = 0
	for i in 5:
		if cleared.has(Content.level_id_for(day_index, i)):
			count += 1
	return count
