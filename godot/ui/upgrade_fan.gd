## 升阶扇形菜单：贴着草木画三片扇叶，不挡住战场，也不抢视野。
##
## 三片扇叶朝上张开（左上、正上、右上），每片写着这一路的名字、当前级数与下一级费用；
## 锁定或满级的那片会变暗并写原因。点扇叶升阶，点别处关掉。
class_name UpgradeFan
extends Control

signal picked(path_id: int)
signal dismissed

const INNER := 52.0
const OUTER := 126.0
const SPREAD := 26.0          # 每片扇叶的半角（度）
const GAP := 30.0             # 扇叶之间的角度间隔（度）

var plant = null
var entries: Array = []       # [{id, name, color, tier, ok, cost, desc, reason}]
var _hover := -1
var _time := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func center() -> Vector2:
	if plant == null:
		return Vector2.ZERO
	return Geo.to_screen(plant.pos)


func _petal_angle(index: int) -> float:
	var count := maxi(1, entries.size())
	return -90.0 + (float(index) - (count - 1) * 0.5) * (SPREAD * 2.0 + GAP)


func _point(radius: float, degrees: float) -> Vector2:
	var a := deg_to_rad(degrees)
	return center() + Vector2(cos(a), sin(a)) * radius


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		accept_event()
		dismissed.emit()
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var hit := hit_test(event.position)
	if hit >= 0:
		accept_event()
		picked.emit(int(entries[hit]["id"]))
		return
	accept_event()
	dismissed.emit()


func hit_test(pos: Vector2) -> int:
	var offset := pos - center()
	var dist := offset.length()
	if dist < INNER * 0.8 or dist > OUTER + 18.0:
		return -1
	var angle := rad_to_deg(atan2(offset.y, offset.x))
	for i in entries.size():
		var mid := _petal_angle(i)
		var delta := wrapf(angle - mid, -180.0, 180.0)
		if absf(delta) <= SPREAD + 2.0:
			return i
	return -1


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hit := -1
		if visible:
			hit = hit_test(event.position)
		if hit != _hover:
			_hover = hit
			queue_redraw()


func _draw() -> void:
	if plant == null or entries.is_empty():
		return
	var origin := center()
	# 起点小环：告诉玩家"这是这株草木的菜单"
	draw_arc(origin, INNER - 8.0, 0.0, TAU, 28,
		Color(1.0, 0.86, 0.55, 0.25 + 0.05 * sin(_time * 3.0)), 1.6)
	draw_circle(origin, 4.0, Color(1.0, 0.86, 0.55, 0.5))
	for i in entries.size():
		_draw_petal(i)
	_draw_legend()
	_draw_tooltip()


func _draw_petal(index: int) -> void:
	var entry: Dictionary = entries[index]
	var mid := _petal_angle(index)
	var color: Color = entry["color"]
	var ok: bool = bool(entry["ok"])
	var hovered := index == _hover
	var segments := 10
	var outer := OUTER + (8.0 if hovered else 0.0)
	var points := PackedVector2Array()
	for s in segments + 1:
		var a := mid - SPREAD + (SPREAD * 2.0) * float(s) / segments
		points.append(_point(outer, a))
	for s in segments + 1:
		var a := mid + SPREAD - (SPREAD * 2.0) * float(s) / segments
		points.append(_point(INNER, a))
	var alpha := (0.34 if ok else 0.16) + (0.08 if hovered else 0.0)
	draw_colored_polygon(points, Color(0.03, 0.05, 0.06, 0.88))
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Color(color.r, color.g, color.b, 0.9 if ok else 0.4),
		2.2 if hovered else 1.6)
	# 填充一层颜色，越靠外越淡
	for s in segments:
		var a0 := mid - SPREAD + (SPREAD * 2.0) * float(s) / segments
		var a1 := mid - SPREAD + (SPREAD * 2.0) * float(s + 1) / segments
		var quad := PackedVector2Array([
			_point(INNER, a0), _point(outer, a0), _point(outer, a1), _point(INNER, a1),
		])
		draw_colored_polygon(quad, Color(color.r, color.g, color.b, alpha * 0.55))
	# 名字与费用都压在这一片的质心上、上下错开两行：左右两片也不会互相压字
	var font := Ui.medium_font()
	var body := Ui.body_font()
	var anchor := _point((INNER + outer) * 0.56, mid)
	var name_text := String(entry["name"])
	var name_w := font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		15).x
	draw_string(font, anchor + Vector2(-name_w * 0.5, -2.0), name_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
		Color(1, 0.96, 0.86, 0.95) if ok else Color(0.8, 0.76, 0.66, 0.8))
	var sub := ""
	var sub_color := Color(0.95, 0.85, 0.66, 0.95)
	if ok:
		sub = "%d 香火" % int(entry["cost"])
		if not bool(entry.get("affordable", true)):
			sub_color = Color(0.9, 0.5, 0.42, 0.95)
	else:
		sub = String(entry["reason"])
		sub_color = Color(0.72, 0.68, 0.58, 0.8)
	var sub_w := body.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(body, anchor + Vector2(-sub_w * 0.5, 13.0), sub,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, sub_color)
	# 级数点：贴在内缘
	var dots_pos := _point(INNER + 12.0, mid)
	for t in 3:
		var filled := t < int(entry["tier"])
		var p := dots_pos + Vector2((t - 1) * 8.0, 0.0)
		if filled:
			draw_circle(p, 2.6, color)
		else:
			draw_arc(p, 2.6, 0.0, TAU, 10, Color(color.r, color.g, color.b, 0.5), 1.0)


## 悬停某片扇叶时，在上方浮一张纸条，写下一级叫什么、做什么
func _draw_tooltip() -> void:
	if _hover < 0 or _hover >= entries.size():
		return
	var entry: Dictionary = entries[_hover]
	var text = String(entry.get("next_desc", ""))
	if text == "":
		return
	var title = "%s · %s" % [String(entry["name"]),
		String(entry.get("next_name", "")) if String(entry.get("next_name", "")) != "" \
		else "已满"]
	var font := Ui.medium_font()
	var body := Ui.body_font()
	var max_w := 300.0
	var lines := _wrap(body, text, 15, max_w)
	var h := 26.0 + float(lines.size()) * 20.0 + 10.0
	var w := max_w + 20.0
	var anchor := _point(OUTER + 26.0, _petal_angle(_hover))
	var rect := Rect2(anchor - Vector2(w * 0.5, h), Vector2(w, h))
	draw_rect(rect, Color(0.96, 0.92, 0.82, 0.97))
	draw_rect(rect, Color(Ui.VERMILION.r, Ui.VERMILION.g, Ui.VERMILION.b, 0.8),
		false, 2.0)
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(font, rect.position + Vector2(w * 0.5 - tw * 0.5, 20.0), title,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.22, 0.13, 0.09))
	for i in lines.size():
		draw_string(body, rect.position + Vector2(10.0, 40.0 + float(i) * 20.0),
			lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.30, 0.21, 0.14))


## 按像素宽度折行（中文按字切）
func _wrap(font: Font, text: String, size: int, max_w: float) -> Array:
	var lines: Array = []
	var line := ""
	for ch in text:
		var probe = line + ch
		if font.get_string_size(probe, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_w:
			lines.append(line)
			line = ch
		else:
			line = probe
	if line != "":
		lines.append(line)
	return lines


func _draw_legend() -> void:
	# 菜单下端一行说明，贴着草木，不铺满屏
	var origin := center()
	var text := "点扇叶升阶 · 点别处关掉"
	var font := Ui.body_font()
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(font, origin + Vector2(-width * 0.5, INNER + 40.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.86, 0.82, 0.7, 0.55))
