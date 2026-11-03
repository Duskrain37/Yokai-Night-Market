## 选关「大岛航线」：一天一张图，图上一条夜路，五夜沿着路点过去。
##
## 复原 v0.2.4 的意境：左下是当天的题签与底细，右侧是画里的五个夜点。
## 夜里用繁体数字（第壹夜…第伍夜），比阿拉伯数字更有味道。
extends Control

const DAY_KEYS = ["day1", "day2", "day3"]
const NUMERALS = ["壹", "贰", "叁", "肆", "伍"]
## 五个夜点在画面里的相对位置（0—1），从近处往远处的门楼走
## 每晚在画里的落点：三天各沿着自己那张图的路走，从近处一路走到画深处。
const ROUTES = {
	# 落点照着手标注的街心量出来（截图 1.6 倍、上下各 82/80 黑边换算回 1600×900）：
	# 壹在街面最近处，比画框还低一截，所以 fy 超过 1；一路踩着石板往门楼收到伍
	"day1": [Vector2(0.416, 1.175), Vector2(0.408, 0.842), Vector2(0.373, 0.640),
		Vector2(0.412, 0.382), Vector2(0.351, 0.179)],
	"day2": [Vector2(0.150, 0.92), Vector2(0.330, 0.745), Vector2(0.520, 0.570),
		Vector2(0.690, 0.395), Vector2(0.810, 0.205)],
	"day3": [Vector2(0.240, 0.92), Vector2(0.400, 0.740), Vector2(0.545, 0.560),
		Vector2(0.635, 0.380), Vector2(0.575, 0.195)],
}
const PICTURE = Rect2(380, 118, 1130, 556)
const NODE_RADIUS = 34.0

var game = null
var selected = 1
var day = 1
var _cards: Array = []          # 夜卡（供自检统计）
var _textures: Dictionary = {}
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
	for i in 3:
		var path = "res://assets/bg/map-%s.jpg" % DAY_KEYS[i]
		if ResourceLoader.exists(path):
			_textures[DAY_KEYS[i]] = load(path)
	_build_actions()
	_refresh_actions()
	game.play_music_scene("menu")


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


# ── 夜点位置 ────────────────────────────────────────────────────────────────
func _route() -> Array:
	return ROUTES.get(DAY_KEYS[day - 1], ROUTES["day1"])


func _node_pos(index: int) -> Vector2:
	var route: Array = _route()
	return PICTURE.position + Vector2(PICTURE.size.x * route[index].x,
		PICTURE.size.y * route[index].y)


## 越往里（y 越小）越远，点也就越小：看着像往画里走
func _node_scale(index: int) -> float:
	var route: Array = _route()
	return lerpf(0.72, 1.12, clampf((float(route[index].y) - 0.24) / 0.64, 0.0, 1.0))


func _level_of(index: int) -> Dictionary:
	return Content.get_level((day - 1) * 5 + index + 1)


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
	for i in 3:
		var rect = Rect2(56, 150 + i * 104, 214, 88)
		var active = (i + 1) == day and selected!=16
		var cleared = _cleared_count(i + 1)
		var base = Color(0.06, 0.09, 0.11, 0.88) if not active \
			else Color(0.22, 0.17, 0.08, 0.95)
		Ui.draw_plate(self, rect, base, Ui.GOLD if active else Color(0.34, 0.31, 0.25, 0.85),
			16, 2 if active else 1)
		var info: Dictionary = Content.DAYS[i]
		draw_string(Ui.medium_font(), rect.position + Vector2(16, 30),
			String(info["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 21,
			Ui.GOLD_BRIGHT if active else Ui.TEXT)
		draw_string(Ui.body_font(), rect.position + Vector2(16, 54),
			String(info["sub"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Ui.TEXT_DIM)
		draw_string(Ui.body_font(), rect.position + Vector2(16, 76),
			"守住 %d / 5 夜" % cleared, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
			Ui.GOOD if cleared >= 5 else Ui.TEXT_FAINT)
		if active:
			draw_circle(rect.position + Vector2(rect.size.x - 22, 22), 5.0,
				Ui.GOLD_BRIGHT)


func _draw_route() -> void:
	var path = PackedVector2Array()
	for i in 5:
		path.append(_node_pos(i))
	for i in 4:
		var a = path[i]
		var b = path[i + 1]
		var done = selected >= (day - 1) * 5 + i + 2
		var color = Color(Ui.GOLD.r, Ui.GOLD.g, Ui.GOLD.b, 0.62 if done else 0.32)
		# 虚线：一段一段画，像夜路上的石磴
		var steps = 22
		for s in steps:
			if s % 2 == 1:
				continue
			var p0 = a.lerp(b, float(s) / steps) + Vector2(0, sin(float(s) / steps * PI) * -18.0)
			var p1 = a.lerp(b, float(s + 1) / steps) + Vector2(0,
				sin(float(s + 1) / steps * PI) * -18.0)
			draw_line(p0, p1, color, 2.0)


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
		var font = Ui.display_font()
		var width = font.get_string_size(numeral, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		draw_string(font, pos + Vector2(-width * 0.5, 11 * depth),
			numeral, HORIZONTAL_ALIGNMENT_LEFT, -1, int(30 * depth),
			Ui.GOLD_BRIGHT if is_selected else Ui.PAPER_DIM)
		# 名字
		var label = "第%s夜" % numeral
		var body = Ui.medium_font()
		var lw = body.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(body, pos + Vector2(-lw * 0.5, radius + 24 * depth), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, int(18 * maxf(0.8, depth)),
			Ui.TEXT if is_selected else Ui.TEXT_DIM)
		var tag = String(level["tag"])
		var tw = Ui.body_font().get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(Ui.body_font(), pos + Vector2(-tw * 0.5, radius + 42), tag,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Ui.TEXT_FAINT)
		if cleared:
			draw_circle(pos + Vector2(radius * 0.72, -radius * 0.72), 8.0,
				Color(0.36, 0.62, 0.4, 0.95))
			draw_string(Ui.body_font(), pos + Vector2(radius * 0.72 - 4.0,
				-radius * 0.72 + 5.0), "✓", HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
				Color(0.95, 0.99, 0.93))
			# 星级挂在夜名下：重打一局是为了把 ☆ 刷成 ★
			var stars = clampi(int(Dictionary(game.progress.get("stars", {}))
				.get(str(int(level["id"])), 0)), 0, 3)
			var mark = "★★★".substr(0, stars) + "☆☆☆".substr(0, 3 - stars)
			var mw = Ui.body_font().get_string_size(mark,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			draw_string(Ui.body_font(), pos + Vector2(-mw * 0.5, radius + 58), mark,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
				Ui.GOLD_BRIGHT if stars >= 3 else Ui.GOLD_DIM)


func _draw_footer() -> void:
	var panel = Rect2(56, 596, 610, 268)
	Ui.draw_plate(self, panel, Color(0.03, 0.05, 0.07, 0.9),
		Color(Ui.GOLD_DIM.r, Ui.GOLD_DIM.g, Ui.GOLD_DIM.b, 0.75), 20, 2)
	var level = Content.get_level(selected)
	var x = panel.position.x + 24
	var y = panel.position.y + 40
	draw_string(Ui.display_font(), Vector2(x, y),
		("鬼市深处 · 终极挑战" if selected==16 else "第%s夜 · %s" % [NUMERALS[int(level["id"]) - (day - 1) * 5 - 1],level["tag"]]), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Ui.GOLD_BRIGHT)
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
	# 简单换行
	var line = ""
	var line_y = y
	for name in names:
		if line.length() + name.length() > 16:
			draw_string(Ui.body_font(), Vector2(x + 84, line_y), line,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Ui.TEXT)
			line_y += 22
			line = ""
		line += name + " "
	if line != "":
		draw_string(Ui.body_font(), Vector2(x + 84, line_y), line,
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
	for i in 3:
		if Rect2(56, 150 + i * 104, 214, 88).has_point(pos):
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
	day = clampi(value, 1, 3)
	# 换日时默认选回这一天的第一夜
	selected = (day - 1) * 5 + 1
	_refresh_actions()
	queue_redraw()
	game.play_sfx("click")


func select_night(index: int) -> void:
	selected = (day - 1) * 5 + index + 1
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

	_special=Ui.button("特殊关 · 鬼市深处",18,214,60)
	_special.position=Vector2(56,474)
	_special.pressed.connect(func(): switch_to_level(16);game.play_sfx("click"))
	add_child(_special)

	_almanac = Ui.button("看恶客图鉴", 16, 180, 38)
	_almanac.position = Vector2(352, 804)
	_almanac.pressed.connect(func(): game.open_almanac("zombie", 0))
	add_child(_almanac)


func _refresh_actions() -> void:
	if _danger!=null:
		_danger.values=[2.0,2.5,3.5] if selected==16 else [float(Content.get_level(selected).threat)]
		_danger.queue_redraw()
	if _enter != null:
		var level = Content.get_level(selected)
		_enter.text = "进入鬼市深处" if selected==16 else "进入第%s夜" % NUMERALS[int(level["id"]) - (day - 1) * 5 - 1]
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
		if cleared.has((day_index - 1) * 5 + i + 1):
			count += 1
	return count
