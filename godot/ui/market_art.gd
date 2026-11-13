## PC visual language: tactile materials, restrained brass joinery and legible typography.
## Geometry stays native and resolution independent; painted materials are in one atlas.
class_name MarketArt
extends RefCounted

const ROOT = "res://assets/ui/nightmarket/"
const BRASS = Color("#b99458")
const LIGHT = Color("#f5dca5")
const TEAL = Color("#72aaa3")
static var _atlas: Texture2D
static var _tiles: Dictionary = {}
static var _styles: Dictionary = {}
static var reduced_motion = false

static func surface(kind: String = "panel", state: String = "normal", padding: Vector2 = Vector2(20, 16)) -> StyleBox:
	var key = "%s|%s|%s" % [kind, state, str(padding)]
	if _styles.has(key): return _styles[key]
	if _atlas == null and ResourceLoader.exists(ROOT + "materials.png"):
		_atlas = load(ROOT + "materials.png")
	var box: StyleBox
	if _atlas != null:
		if not _tiles.has(kind):
			var cell = _atlas.get_size() / 2.0
			var position = Vector2.ZERO
			if kind == "primary": position = Vector2(1, 0)
			elif kind == "paper": position = Vector2(0, 1)
			elif kind == "card": position = Vector2(1, 1)
			# Material atlas is mechanically sampled once at native UI scale.
			# Its painted border must fit inside the nine-slice corner area.
			var source = _atlas.get_image()
			if source.is_compressed(): source.decompress()
			var tile = source.get_region(Rect2i(position * cell, cell))
			tile.resize(128, 128, Image.INTERPOLATE_LANCZOS)
			_tiles[kind] = ImageTexture.create_from_image(tile)
		var textured = StyleBoxTexture.new()
		textured.texture = _tiles[kind]
		textured.set_texture_margin_all(12)
		textured.modulate_color = Color(1.13, 1.13, 1.08) if state == "hover" else Color.WHITE
		if state == "pressed": textured.modulate_color = Color(0.76, 0.76, 0.70)
		if state == "disabled": textured.modulate_color = Color(0.42, 0.46, 0.46, 0.8)
		box = textured
	else:
		var flat = StyleBoxFlat.new()
		flat.bg_color = Color("#10262b") if kind != "primary" else Color("#753729")
		flat.border_color = BRASS
		flat.set_border_width_all(1)
		flat.set_corner_radius_all(4)
		box = flat
	box.content_margin_left = padding.x
	box.content_margin_right = padding.x
	box.content_margin_top = padding.y
	box.content_margin_bottom = padding.y
	_styles[key] = box
	return box

static func focus_style() -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = Color.TRANSPARENT
	box.border_color = LIGHT
	box.set_border_width_all(2)
	box.set_corner_radius_all(4)
	box.set_expand_margin_all(3)
	return box

static func backdrop(parent: Control, path: String, darkness: float = 0.2) -> TextureRect:
	var picture = TextureRect.new()
	picture.texture = load(path) if ResourceLoader.exists(path) else load("res://assets/bg/menu.jpg")
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(picture)
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var veil = ColorRect.new()
	veil.color = Color(0.015, 0.045, 0.055, darkness)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return picture

static func vignette(parent: Control, left: float = 0.86, right: float = 0.0) -> void:
	var gradient = Gradient.new()
	gradient.set_color(0, Color(0.018, 0.047, 0.057, left))
	gradient.set_color(1, Color(0.018, 0.047, 0.057, right))
	gradient.add_point(0.4, Color(0.018, 0.047, 0.057, left * 0.5))
	var texture = GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 4
	texture.fill_from = Vector2.ZERO
	texture.fill_to = Vector2(1, 0)
	var shade = TextureRect.new()
	shade.texture = texture
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

static func corners(canvas: CanvasItem, rect: Rect2, color: Color = BRASS, length: float = 18.0) -> void:
	for direction in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var p = Vector2(rect.position.x if direction.x > 0 else rect.end.x, rect.position.y if direction.y > 0 else rect.end.y)
		canvas.draw_line(p, p + Vector2(direction.x * length, 0), color, 1.5, true)
		canvas.draw_line(p, p + Vector2(0, direction.y * length), color, 1.5, true)
		var inset = p + direction * 5
		canvas.draw_line(inset, inset + Vector2(direction.x * 6, 0), Color(color, color.a * 0.5), 1, true)

static func diamond(canvas: CanvasItem, center: Vector2, radius: float, color: Color, filled: bool = false) -> void:
	var points = PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0), center + Vector2(0, -radius)])
	if filled: canvas.draw_colored_polygon(points, color)
	else: canvas.draw_polyline(points, color, 1.4, true)

static func icon(canvas: CanvasItem, kind: String, center: Vector2, radius: float = 12.0, color: Color = LIGHT) -> void:
	var r = radius
	match kind:
		"lantern", "sun":
			canvas.draw_arc(center, r * 0.72, 0, TAU, 32, color, 1.7, true)
			canvas.draw_line(center + Vector2(-r * 0.3, -r * 0.83), center + Vector2(r * 0.3, -r * 0.83), color, 2, true)
			canvas.draw_line(center + Vector2(-r * 0.3, r * 0.83), center + Vector2(r * 0.3, r * 0.83), color, 2, true)
			canvas.draw_line(center + Vector2(0, -r * 0.6), center + Vector2(0, r * 0.6), Color(color, 0.6), 1, true)
			canvas.draw_line(center + Vector2(0, r * 0.9), center + Vector2(0, r * 1.24), color, 1.6, true)
		"map":
			var points = PackedVector2Array([center + Vector2(-r, r * 0.65), center + Vector2(-r, -r * 0.8), center + Vector2(-r * 0.3, -r * 0.55), center + Vector2(r * 0.3, -r * 0.9), center + Vector2(r, -r * 0.6), center + Vector2(r, r * 0.9), center + Vector2(r * 0.3, r * 0.6), center + Vector2(-r * 0.3, r * 0.9), center + Vector2(-r, r * 0.65)])
			canvas.draw_polyline(points, color, 1.6, true)
			canvas.draw_line(center + Vector2(-r * 0.3, -r * 0.55), center + Vector2(-r * 0.3, r * 0.9), Color(color, 0.6), 1, true)
			canvas.draw_line(center + Vector2(r * 0.3, -r * 0.9), center + Vector2(r * 0.3, r * 0.6), Color(color, 0.6), 1, true)
		"book":
			for side in [-1, 1]:
				var p = center + Vector2(side * r * 0.15, r * 0.7)
				canvas.draw_polyline(PackedVector2Array([p, center + Vector2(side * r, r * 0.45), center + Vector2(side * r, -r * 0.8), center + Vector2(side * r * 0.15, -r * 0.55), p]), color, 1.6, true)
		"settings":
			canvas.draw_arc(center, r * 0.55, 0, TAU, 20, color, 1.6, true)
			for i in 8:
				var angle = i * TAU / 8
				canvas.draw_line(center + Vector2.from_angle(angle) * r * 0.7, center + Vector2.from_angle(angle) * r, color, 2.2, true)
		"training":
			canvas.draw_arc(center, r, 0, TAU, 32, color, 1.4, true)
			canvas.draw_arc(center, r * 0.5, 0, TAU, 24, color, 1.4, true)
			canvas.draw_circle(center, r * 0.13, color)
		"arrow":
			canvas.draw_line(center - Vector2(r, 0), center + Vector2(r, 0), color, 1.7, true)
			canvas.draw_polyline(PackedVector2Array([center + Vector2(r * 0.3, -r * 0.55), center + Vector2(r, 0), center + Vector2(r * 0.3, r * 0.55)]), color, 1.7, true)
		"star":
			var points = PackedVector2Array()
			for i in 10: points.append(center + Vector2.from_angle(-PI / 2 + i * PI / 5) * r * (1.0 if i % 2 == 0 else 0.44))
			canvas.draw_colored_polygon(points, color)
		"boss":
			diamond(canvas, center, r * 1.15, color)
			canvas.draw_polyline(PackedVector2Array([center + Vector2(-r * 0.55, -r * 0.2), center + Vector2(-r * 0.3, r * 0.42), center + Vector2(r * 0.3, r * 0.42), center + Vector2(r * 0.55, -r * 0.2)]), color, 1.8, true)
			canvas.draw_line(center + Vector2(-r * 0.55, -r * 0.2), center + Vector2(-r * 0.15, 0), color, 2, true)
			canvas.draw_line(center + Vector2(r * 0.55, -r * 0.2), center + Vector2(r * 0.15, 0), color, 2, true)
		_:
			diamond(canvas, center, r, color)

static func icon_control(kind: String, size: float = 28.0, color: Color = LIGHT) -> Control:
	var control = Control.new()
	control.custom_minimum_size = Vector2.ONE * size
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.draw.connect(func(): icon(control, kind, control.size / 2, size * 0.34, color))
	return control

static func enter(control: Control, duration: float = 0.24) -> void:
	if DisplayServer.get_name() == "headless" or reduced_motion: return
	control.modulate.a = 0.0
	control.create_tween().tween_property(control, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
