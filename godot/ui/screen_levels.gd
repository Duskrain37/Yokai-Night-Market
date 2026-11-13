## Five visible chapter tabs, diegetic route tokens and a concise night dossier.
extends Control
const Art = preload("res://ui/market_art.gd")

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
var _badge: Button = null
var _almanac: Button = null
var _special: Button = null
var _danger: Control = null
var _week_scroll: ScrollContainer
var _week_buttons: Array[Button] = []
var _old_picture: Texture2D
var _map_tween: Tween
var _caption_cache: Dictionary = {}
var _last_canvas := Vector2.ZERO
var _map_blend = 0.0:
	set(value):
		_map_blend = value
		queue_redraw()


func _overview_point(point: Vector2) -> Vector2:
	var scale := maxf(Ui.canvas_size.x / NEW_OVERVIEW_SIZE.x, Ui.canvas_size.y / NEW_OVERVIEW_SIZE.y)
	return (point - NEW_OVERVIEW_SIZE * .5) * scale + Ui.canvas_size * .5


func _node_pos(index: int) -> Vector2:
	var key = DAY_KEYS[day - 1]
	var point: Vector2
	if NEW_ROUTES.has(key):
		point = _overview_point(NEW_ROUTES[key][index])
	else:
		point = PICTURE.position + PICTURE.size * ROUTES[key][index]
	if not NEW_ROUTES.has(key): point.y *= Ui.canvas_size.y / 900.0
	point.y = clampf(point.y, 242, Ui.canvas_size.y - 110)
	return point


## 越往里（y 越小）越远，点也就越小：看着像往画里走
func _node_scale(index: int) -> float:
	var y = (_node_pos(index).y - PICTURE.position.y) / PICTURE.size.y
	return lerpf(0.72, 1.12, clampf((y - 0.24) / 0.64, 0.0, 1.0))


func _level_of(index: int) -> Dictionary:
	return Content.get_level(Content.level_id_for(day, index))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	focus_mode = Control.FOCUS_ALL
	selected = clampi(int(game.progress.get("selected", 1)), 1, Content.LEVELS.size())
	day = int(Content.get_level(selected).get("day", 1))
	for i in Content.DAYS.size():
		var path = Content.map_picture(Content.DAYS[i], true)
		if ResourceLoader.exists(path): _textures[DAY_KEYS[i]] = load(path)
	_build_actions()
	_build_week_tabs()
	_refresh_actions()
	game.play_music_scene("menu")
	Art.enter(self)
	grab_focus()

func _process(delta: float) -> void:
	if _last_canvas != Ui.canvas_size:
		_last_canvas = Ui.canvas_size
		_caption_cache.clear()
		_route_segments.clear()
	_time += delta
	queue_redraw()

func _draw() -> void:
	_draw_picture()
	_draw_route()
	_draw_nodes()
	_draw_footer()
	_draw_header()

func _draw_picture() -> void:
	draw_rect(Rect2(Vector2.ZERO, Ui.canvas_size), Ui.INK)
	var texture: Texture2D = _textures.get(DAY_KEYS[day - 1])
	if texture != null:
		var drawn = texture.get_size() * maxf(Ui.canvas_size.x / texture.get_width(), Ui.canvas_size.y / texture.get_height())
		draw_texture_rect(texture, Rect2((Ui.canvas_size - drawn) / 2, drawn), false)
	if _old_picture != null and _map_blend > 0.001:
		var drawn = _old_picture.get_size() * maxf(Ui.canvas_size.x / _old_picture.get_width(), Ui.canvas_size.y / _old_picture.get_height())
		draw_texture_rect(_old_picture, Rect2((Ui.canvas_size - drawn) / 2, drawn), false, Color(1, 1, 1, _map_blend))
	draw_rect(Rect2(Vector2.ZERO, Ui.canvas_size), Color(0.02, 0.045, 0.06, 0.20))
	for i in 12:
		var width = 410.0 - i * 26
		draw_rect(Rect2(0, 190, width, Ui.canvas_size.y - 190), Color(0.015, 0.04, 0.05, 0.055))
	draw_rect(Rect2(0, 0, Ui.canvas_size.x, 190), Color(0.018, 0.045, 0.055, 0.88))
	draw_line(Vector2(48, 190), Vector2(1552, 190), Color(Art.BRASS, 0.45), 1, true)

func _draw_header() -> void:
	draw_string(Ui.display_font(), Vector2(230, 74), "守夜舆图", HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.font_size(34), Ui.GOLD_BRIGHT)
	Art.diamond(self, Vector2(429, 62), 4, Ui.VERMILION, true)
	var info: Dictionary = Content.DAYS[day - 1]
	draw_string(Ui.medium_font(), Vector2(451, 69), "%s · %s" % [info.name, info.sub], HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.font_size(20), Ui.TEXT_DIM)
	draw_string(Ui.body_font(), Vector2(820, 68), "← → 选夜 · Enter 入场", HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.font_size(14), Ui.TEXT_FAINT)

func _build_week_tabs() -> void:
	_week_scroll = ScrollContainer.new()
	_week_scroll.position = Vector2(48, 110)
	_week_scroll.size = Vector2(1504, 66)
	_week_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_week_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_week_scroll)
	var row = Ui.hbox(12)
	_week_scroll.add_child(row)
	for i in Content.DAYS.size():
		var button = Ui.button("", 18, 291, 66)
		button.pressed.connect(select_day.bind(i + 1))
		row.add_child(button)
		_week_buttons.append(button)

func _tab_rect(index: int) -> Rect2:
	return Rect2() if index < 0 or index >= _week_buttons.size() else _week_buttons[index].get_global_rect()

func _refresh_week_tabs() -> void:
	for i in _week_buttons.size():
		var info: Dictionary = Content.DAYS[i]
		_week_buttons[i].text = "%s · %s    %d/5 夜" % [info.name, info.sub, _cleared_count(i + 1)]
		Ui.set_button_active(_week_buttons[i], i + 1 == day and selected != Content.SPECIAL_ID)

func _draw_route() -> void:
	var key = DAY_KEYS[day - 1]
	if not _route_segments.has(key): _route_segments[key] = _build_route_segments(key)
	var cleared: Array = game.progress.get("cleared", [])
	for i in 4:
		var done = cleared.has(Content.level_id_for(day, i))
		var color = Color(Ui.JADE if done else Ui.GOLD, 0.9 if done else 0.65)
		draw_multiline(_route_segments[key][i], Color(0, 0, 0, 0.6), 5.5, true)
		draw_multiline(_route_segments[key][i], color, 2.0, true)

func _draw_nodes() -> void:
	var captions = _caption_rects()
	for i in 5:
		var level = _level_of(i)
		var pos = _node_pos(i)
		var active = int(level.id) == selected
		var cleared = Array(game.progress.get("cleared", [])).has(int(level.id))
		var radius = NODE_RADIUS * _node_scale(i) * (1.13 if active else 1.0)
		var edge = Ui.GOLD_BRIGHT if active else (Ui.JADE_LIGHT if cleared else Art.BRASS)
		draw_circle(pos + Vector2(0, 5), radius + 7, Color(0, 0, 0, 0.42))
		if active or _hover == i:
			var breath = 0.5 + 0.5 * sin(_time * 2)
			draw_circle(pos, radius + 13 + breath * 3, Color(edge, 0.11))
			for j in 4: Art.diamond(self, pos + Vector2.from_angle(j * PI / 2) * (radius + 9), 3, edge, true)
		if i == 4:
			Art.diamond(self, pos, radius + 7, Color("#172e31"), true)
			Art.diamond(self, pos, radius + 7, edge)
			Art.diamond(self, pos, radius + 2, Color(edge, 0.42))
			Art.icon(self, "boss", pos, radius * 0.57, edge)
		else:
			draw_circle(pos, radius, Color("#10232a"))
			draw_arc(pos, radius, 0, TAU, 56, edge, 2 if active else 1.3, true)
			draw_arc(pos, radius - 5, 0, TAU, 48, Color(edge, 0.35), 1, true)
			_draw_centered_glyph(Ui.display_font(), NUMERALS[i], pos, Ui.font_size(31), edge)
		var label_rect: Rect2 = captions[i]
		Ui.draw_plate(self, label_rect, Color(0.018, 0.04, 0.05, 0.83), Color(edge, 0.35), 3, 1)
		_draw_centered_line(Ui.medium_font(), ("恶首 · 第伍夜" if i == 4 else "第%s夜" % NUMERALS[i]), label_rect.get_center().x, label_rect.position.y + 23, Ui.font_size(17), Ui.TEXT)
		_draw_centered_line(Ui.body_font(), String(level.tag), label_rect.get_center().x, label_rect.position.y + 46, Ui.font_size(14), Ui.TEXT_DIM)
		if cleared:
			draw_circle(pos + Vector2(radius * 0.7, -radius * 0.7), 8, Ui.JADE)
			_draw_centered_line(Ui.medium_font(), "✓", pos.x + radius * 0.7, pos.y - radius * 0.7 + 5, 12, Ui.INK)
			var flags: Array = preload("res://data/nightmare.gd").flags(game.progress, int(level.id))
			var badge = int(Dictionary(Dictionary(game.progress.get("nightmare_badges", {})).get(str(int(level.id)), {})).get("best", 0))
			preload("res://ui/star_rating.gd").paint(self, Vector2(label_rect.get_center().x - 30, label_rect.end.y + 8), flags, badge, 7)

## Captions reserve room for stars and the largest selected medallion.
## The result is fixed for each chapter, so selecting a night never moves its label.
func _caption_rects() -> Dictionary:
	if _caption_cache.has(day): return _caption_cache[day]
	var placed: Dictionary = {}
	var blockers: Array[Rect2] = []
	for i in 5: blockers.append(Rect2(_node_pos(i) - Vector2(50, 50), Vector2(100, 100)))
	for i in [4, 3, 2, 1, 0]:
		var point = _node_pos(i)
		var right = point + Vector2(60, -28)
		var left = point + Vector2(-206, -28)
		var candidates = [right, left, point + Vector2(-73, 60), point + Vector2(-73, -134), right + Vector2(0, 42), left + Vector2(0, 42)]
		for position in candidates:
			var full = Rect2(position, Vector2(146, 74))
			if not Rect2(440, 198, 1112, Ui.canvas_size.y - 210).encloses(full): continue
			if blockers.any(func(rect): return rect.intersects(full)): continue
			var overlaps = false
			for previous in placed.values():
				if Rect2(previous.position, Vector2(146, 74)).grow(8).intersects(full): overlaps = true
			if overlaps: continue
			placed[i] = Rect2(position, Vector2(146, 56))
			break
		if not placed.has(i): placed[i] = Rect2(Vector2(clampf(right.x, 440, 1406), clampf(right.y, 198, Ui.canvas_size.y - 86)), Vector2(146, 56))
	_caption_cache[day] = placed
	return placed

func _draw_footer() -> void:
	draw_set_transform(Vector2(0, Ui.canvas_size.y - 900))
	var panel = Rect2(48, 536, 382, 326)
	draw_style_box(Art.surface("panel"), panel)
	var level = Content.get_level(selected)
	var heading = "鬼市深处" if selected == Content.SPECIAL_ID else "第%s夜 · %s" % [NUMERALS[int(level.get("night", 0))], level.tag]
	draw_string(Ui.display_font(), Vector2(72, 578), heading, HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.font_size(27), Ui.GOLD_BRIGHT)
	draw_line(Vector2(72, 594), Vector2(406, 594), Color(Art.BRASS, 0.4), 1, true)
	draw_string(Ui.body_font(), Vector2(72, 626), "凶险", HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.font_size(16), Ui.TEXT_DIM)
	draw_string(Ui.medium_font(), Vector2(72, 658), "%d 行 × 9 列 · %d 大波" % [int(level.rows), Content.wave_groups(level)], HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.font_size(17), Ui.TEXT)
	Art.icon(self, "lantern", Vector2(319, 650), 10, Ui.GOLD)
	draw_string(Ui.medium_font(), Vector2(338, 658), str(int(level.start_sun)), HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.font_size(18), Ui.GOLD_BRIGHT)
	draw_string(Ui.body_font(), Vector2(72, 688), "今夜来客", HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.font_size(15), Ui.TEXT_DIM)
	var seen = Content.plants_in_level(level)
	for i in mini(5, seen.size()):
		var rect = Rect2(72 + i * 64, 699, 54, 46)
		draw_style_box(Art.surface("card", "normal", Vector2.ZERO), rect)
		Ui.draw_plant_icon(self, String(seen[i]), rect.grow(-4))
	if seen.size() > 5:
		draw_string(Ui.body_font(), Vector2(393, 730), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, Ui.font_size(18), Ui.TEXT_DIM)

	draw_set_transform(Vector2.ZERO)

func _build_actions() -> void:
	var back = Ui.button("← 回封面", 17, 142, 42)
	back.position = Vector2(48, 36)
	back.pressed.connect(game.show_menu)
	add_child(back)
	_special = Ui.button("特殊关 · 鬼市深处", 17, 242, 42)
	_special.position = Vector2(1310, 36)
	_special.pressed.connect(func(): switch_to_level(Content.SPECIAL_ID); game.play_sfx("click"))
	add_child(_special)
	_danger = preload("res://ui/threat_meter.gd").new()
	_danger.position = Vector2(136, 614)
	Ui.pin(_danger)
	_danger.size = Vector2(266, 14)
	add_child(_danger)
	_enter = Ui.button("进入备战", 23, 338, 54, true)
	_enter.position = Vector2(70, 788)
	Ui.pin(_enter)
	_enter.pressed.connect(func(): game.play_sfx("click"); game.show_prep(selected))
	add_child(_enter)
	_almanac = Ui.button("看恶客图鉴", 14, 166, 30)
	_almanac.position = Vector2(72, 751)
	Ui.pin(_almanac)
	_almanac.pressed.connect(func(): game.open_almanac("zombie", 0))
	add_child(_almanac)
	_badge = Ui.button("噩梦徽章", 14, 158, 30)
	_badge.position = Vector2(248, 751)
	Ui.pin(_badge)
	_badge.pressed.connect(func():
		var dialog = load("res://ui/nightmare_badges.gd").new()
		dialog.entry = Dictionary(Dictionary(game.progress.get("nightmare_badges", {})).get(str(selected), {}))
		dialog.earned = preload("res://data/nightmare.gd").flags(game.progress, selected)
		add_child(dialog)
		dialog.popup_centered()
		dialog.confirmed.connect(dialog.queue_free)
		dialog.canceled.connect(dialog.queue_free))
	add_child(_badge)

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


func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_HOME, KEY_END]:
			var night = int(Content.get_level(selected).get("night", 0))
			var next = 0 if event.keycode == KEY_HOME else (4 if event.keycode == KEY_END else clampi(night + (-1 if event.keycode == KEY_LEFT else 1), 0, 4))
			select_night(next)
			accept_event()
			return
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
			accept_event()
			game.play_sfx("click")
			game.show_prep(selected)
			return
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
		var caption = Rect2(_caption_rects()[i].position, Vector2(146, 74))
		if pos.distance_to(_node_pos(i)) <= NODE_RADIUS + 12.0 or caption.has_point(pos):
			select_night(i)
			grab_focus()
			accept_event()
			return


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hover = -1
		for i in 5:
			var caption = Rect2(_caption_rects()[i].position, Vector2(146, 74))
			if event.position.distance_to(_node_pos(i)) <= NODE_RADIUS + 12.0 or caption.has_point(event.position):
				hover = i
		if hover != _hover:
			_hover = hover
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hover >= 0 else Control.CURSOR_ARROW
			queue_redraw()


func select_day(value: int) -> void:
	if value == day and selected!=16:
		return
	if not Art.reduced_motion:
		_old_picture = _textures.get(DAY_KEYS[day - 1])
		_map_blend = 1.0
		if _map_tween != null: _map_tween.kill()
		_map_tween = create_tween()
		_map_tween.tween_property(self, "_map_blend", 0.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
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


func _refresh_actions() -> void:
	if _badge!=null:_badge.visible=Dictionary(game.progress.get("nightmare_badges",{})).has(str(selected))
	_refresh_week_tabs()
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
