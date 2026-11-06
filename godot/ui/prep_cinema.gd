## 备战镜头：按 v0.2.4 的五段节奏还原「推镜 → 报幕 → 恶客列队 → 淡出」。
##
## 旧版是 5.8 秒：0—1.5 慢推、1.5—2.25 快推、2.25 起报恶客、5.05 起淡出。
## 旧版还有一个毛病：报幕阶段上下两条黑边压住了标题，直到 2.25 秒才消失；
## 这里让黑边在推镜结束前（2.05 秒）就淡到 0，报幕时不遮字。
##
## 点任意处或按 Esc 可跳过。
class_name PrepCinema
extends Control

signal finished

const TOTAL := 5.8
const PAN_START := 1.5
const REVEAL_START := 2.25
const FADE_START := 5.05
const BAR_H := 46.0
const BAR_FADE_END := 2.05

var level: Dictionary = {}
var zombie_types: Array = []
var bg: Texture2D = null
var t := 0.0
var _done := false
var _fonts_ready := false


func _ready() -> void:
	set_anchors_and_presets_to_full()
	mouse_filter = Control.MOUSE_FILTER_STOP
	# 关卡里的 map 是 street/market/water，底图文件名是 day1/2/3
	var path := Content.map_picture(level, true)
	if ResourceLoader.exists(path):
		bg = load(path)
	# QA：--cinema-t=3.5 直接从第 3.5 秒开始，方便截报幕那一帧
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cinema-t="):
			t = float(arg.trim_prefix("--cinema-t="))
	zombie_types = preview_roster(level, zombie_types)
	_fonts_ready = true


func set_anchors_and_presets_to_full() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	if _done:
		return
	t += delta
	queue_redraw()
	if t >= TOTAL:
		_finish()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		accept_event()
		_finish()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	queue_free()


static func _clamp01(v: float) -> float:
	return clampf(v, 0.0, 1.0)


static func _ease_in_out(v: float) -> float:
	var x := _clamp01(v)
	return x * x * (3.0 - 2.0 * x)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Geo.VIEW), Color(0.02, 0.02, 0.03))
	_draw_background()
	_draw_tints()
	_draw_embers()
	_draw_texts()
	_draw_lineup()
	_draw_bars()
	_draw_skip_hint()


func _draw_background() -> void:
	if bg == null:
		return
	var size := bg.get_size()
	var base := maxf(Geo.VIEW.x / size.x, Geo.VIEW.y / size.y)
	var pan := _ease_in_out((t - PAN_START) / (REVEAL_START - PAN_START))
	var zoom := 0.0
	var focus_y := 0.0
	if t < PAN_START:
		zoom = 1.02 + 0.06 * (t / PAN_START)
		focus_y = 0.545
	else:
		zoom = 1.08 + 0.47 * pan
		if t > REVEAL_START:
			zoom += sin((t - REVEAL_START) * 0.7) * 0.008
		focus_y = 0.545 - 0.115 * pan
	var drawn := size * base * zoom
	var offset := Geo.VIEW * 0.5 - Vector2(0.5 * drawn.x, focus_y * drawn.y)
	draw_texture_rect(bg, Rect2(offset, drawn), false)


func _draw_tints() -> void:
	# 开头一层暖光，压下去时转冷
	var warm := maxf(0.0, 1.0 - t / (PAN_START + 0.35))
	draw_rect(Rect2(Vector2.ZERO, Geo.VIEW), Color(1.0, 0.59, 0.25, 0.08 + warm * 0.09))
	var dark := _clamp01((t - PAN_START * 0.55) / (REVEAL_START - PAN_START * 0.55 + 0.2))
	draw_rect(Rect2(Vector2.ZERO, Geo.VIEW), Color(0.02, 0.03, 0.07, 0.05 + dark * 0.52))
	# 四周压暗，中间留亮
	for i in 5:
		var k := float(i) / 5.0
		var inset := 40.0 + k * 60.0
		var alpha := 0.05 + k * 0.03
		draw_rect(Rect2(0, 0, Geo.VIEW.x, inset + 90.0 * (1.0 - k)),
			Color(0, 0, 0, alpha))
		draw_rect(Rect2(0, Geo.VIEW.y - inset - 90.0 * (1.0 - k), Geo.VIEW.x, 200),
			Color(0, 0, 0, alpha))


func _draw_embers() -> void:
	if t > REVEAL_START + 1.2:
		return
	var dark := _clamp01((t - PAN_START * 0.55) / (REVEAL_START - PAN_START * 0.55 + 0.2))
	for i in 18:
		var seed := float(i) * 93.7
		var x := fmod(seed * 11.3 + t * (7.0 + float(i % 4) * 2.0), 1360.0) - 40.0
		var y := 690.0 - fmod(seed * 7.7 + t * (12.0 + float(i % 5) * 3.0), 760.0)
		var a := (0.18 + float(i % 4) * 0.05) * (1.0 - dark * 0.55)
		var color := Color(1.0, 0.84, 0.51, a) if i % 3 == 0 else Color(1.0, 0.67, 0.38, a)
		draw_circle(Vector2(x, y), 1.2 + float(i % 3) * 0.7, color)


func _draw_texts() -> void:
	var display := Ui.display_font()
	var body := Ui.body_font()
	var cyan := Color(1.0, 0.89, 0.72)
	# 第一段：夜市灯火通明
	var stage1 := minf(1.0, t / 0.45) * (1.0 - _clamp01((t - 1.05) / 0.4))
	if stage1 > 0.01:
		_draw_center(display, "夜市灯火通明", 48, Vector2(800, 200), Color(cyan, stage1))
		_draw_center(body, "摊子刚支起来，香气正热。", 17,
			Vector2(800, 250), Color(0.96, 0.88, 0.71, 0.78 * stage1))
		var info := "%s · %s · %s · 共 %d 大波" % [level.get("day_name", ""),
			level.get("name", ""), level.get("tag", ""),
			Content.wave_groups(level)]
		_draw_center(body, info, 13, Vector2(800, 288),
			Color(0.89, 0.75, 0.48, 0.55 * stage1))
	# 第二段：街尾的灯
	var stage2 := _clamp01((t - 1.12) / 0.32) * (1.0 - _clamp01((t - REVEAL_START + 0.1) / 0.3))
	if stage2 > 0.01:
		_draw_center(display, "街尾的灯，好像被谁挡住了。", 26,
			Vector2(800, 200), Color(0.96, 0.89, 0.75, 0.9 * stage2))
		# 两侧横线：像被风吹斜的灯影
		for i in 4:
			var y := 330.0 + i * 26.0
			var a := 0.22 * stage2
			draw_line(Vector2(140 + i * 30, y), Vector2(360 + i * 18, y + 2),
				Color(0.92, 0.75, 0.47, a), 2.0)
			draw_line(Vector2(1240 - i * 30, y), Vector2(1020 - i * 18, y + 2),
				Color(0.92, 0.75, 0.47, a), 2.0)
	# 第三段：今夜恶客
	var fade := _clamp01((t - FADE_START) / (TOTAL - FADE_START))
	var stage3 := _clamp01((t - REVEAL_START) / 0.35) * (1.0 - fade)
	if stage3 > 0.01:
		_draw_center(display, "今夜恶客", 30, Vector2(800, 104), Color(0.94, 0.84, 0.63, stage3))
		_draw_center(body, "它们已经闻到香火了。", 14,
			Vector2(800, 138), Color(0.91, 0.83, 0.64, 0.68 * stage3))


func _draw_lineup() -> void:
	var fade := _clamp01((t - FADE_START) / (TOTAL - FADE_START))
	var stage := _clamp01((t - REVEAL_START) / 0.35) * (1.0 - fade)
	if stage <= 0.01 or zombie_types.is_empty():
		return
	# 底部压一条暗带，把恶客托起来
	var band := 0.55 * stage
	for i in 6:
		var k := float(i) / 6.0
		draw_rect(Rect2(0, 470.0 + k * 30.0, Geo.VIEW.x, 30.0),
			Color(0.01, 0.02, 0.04, band * (0.1 + k * 0.14)))
	var n := zombie_types.size()
	var gap := minf(196.0, 980.0 / maxf(1.0, float(n - 1))) if n > 1 else 0.0
	var start_x := 800.0 - gap * (n - 1) * 0.5
	for i in n:
		var type := String(zombie_types[i])
		var p := _clamp01((t - REVEAL_START - i * 0.13) / 0.42)
		if p <= 0.0:
			continue
		var e := _ease_in_out(p)
		var x := start_x + gap * i + (1.0 - e) * 42.0
		var y := 556.0 + (1.0 - e) * 30.0
		var a := p * (1.0 - fade)
		# 落影
		draw_set_transform(Vector2(x, y + 6), 0.0, Vector2(1.0, 0.3))
		draw_circle(Vector2.ZERO, 40.0, Color(0, 0, 0, 0.45 * a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var texture := Almanac.boss_portrait(type.trim_prefix("boss-")) if type.begins_with("boss-") else Ui.sprite(type)
		if texture != null:
			var size := texture.get_size()
			var height := 132.0
			var scale := height / size.y
			var drawn := size * scale
			draw_texture_rect(texture, Rect2(
				Vector2(x - drawn.x * 0.5, y - drawn.y), drawn), false,
				Color(1, 1, 1, a))
		if p > 0.55:
			var ta := (p - 0.55) / 0.45
			var def: Dictionary = Content.ZOMBIES.get(type, {})
			_draw_center(Ui.medium_font(), Almanac.boss_name(type.trim_prefix("boss-")) if type.begins_with("boss-") else String(def.get("name", type)), 17,
				Vector2(x, y + 30.0), Color(0.94, 0.86, 0.69, ta * (1.0 - fade)))
			_draw_center(Ui.body_font(), "恶首" if type.begins_with("boss-") else Content.tier_label(String(def.get("tier", "l"))),
				11, Vector2(x, y + 48.0), Color(0.91, 0.83, 0.64, 0.55 * ta * (1.0 - fade)))


func _draw_bars() -> void:
	# 旧版黑边会压住报幕文字；这里在报幕开始前就淡到 0
	var alpha := 1.0 - _clamp01(t / BAR_FADE_END)
	if alpha <= 0.01:
		return
	var ease_alpha := alpha * alpha
	draw_rect(Rect2(0, 0, Geo.VIEW.x, BAR_H), Color(0, 0, 0, 0.92 * ease_alpha))
	draw_rect(Rect2(0, Geo.VIEW.y - BAR_H, Geo.VIEW.x, BAR_H),
		Color(0, 0, 0, 0.92 * ease_alpha))


func _draw_skip_hint() -> void:
	if t > REVEAL_START + 0.6:
		return
	var a := 0.42 * (1.0 - _clamp01((t - REVEAL_START) / 0.6))
	_draw_center(Ui.body_font(), "点任意处跳过", 14,
		Vector2(800, Geo.VIEW.y - 74), Color(0.9, 0.84, 0.7, a))


func _draw_center(font: Font, text: String, size: int, center: Vector2,
		color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := center - Vector2(width * 0.5, 0.0)
	draw_string(font, pos + Vector2(1.5, 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		size, Color(0, 0, 0, color.a * 0.6))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

static func preview_roster(stage: Dictionary, guests: Array) -> Array:
	var result: Array = []
	var bosses: Array = stage.get("boss_checkpoints", []).duplicate()
	for key in ["mid_boss", "boss_id"]:
		var id := String(stage.get(key, ""))
		if not id.is_empty() and not bosses.has(id):
			bosses.append(id)
	for id in bosses:
		result.append("boss-" + String(id))
	for tier in ["l", "m", "h"]:
		var count := 0
		for type in guests:
			if Content.ZOMBIES.get(type, {}).get("tier", "") == tier and count < 3:
				result.append(type)
				count += 1
	return result
