## 视觉基座：配色、字体、控件样式与常用控件工厂。
##
## 全作统一走这一套，界面里不再出现零散色值：夜色底、宣纸面、金线边、朱砂点睛。
## 字体三档：LXGW 文楷正文、文楷中等字重做小标题、马善政毛笔字做标题与印章。
class_name Ui
extends RefCounted

const Art = preload("res://ui/market_art.gd")

# ── 配色 ────────────────────────────────────────────────────────────────────
const INK = Color("#0a1218")
const INK_SOFT = Color("#111c24")
const NIGHT = Color("#16242e")
const NIGHT_LIGHT = Color("#1f3240")
const PAPER = Color("#f2e7d0")
const PAPER_DIM = Color("#dccbaa")
const PAPER_SHADE = Color("#c9b691")
const GOLD = Color("#d8b463")
const GOLD_DIM = Color("#9a7b3e")
const GOLD_BRIGHT = Color("#f0d493")
const VERMILION = Color("#c8402f")
const VERMILION_LIGHT = Color("#e8664a")
const JADE = Color("#5d9c93")
const JADE_LIGHT = Color("#8fc2b7")
const TEXT = Color("#efe3c8")
const TEXT_DIM = Color("#c3b69b")
const TEXT_FAINT = Color("#aa9d83")
const GOOD = Color("#8fc48a")
const WARN = Color("#e9a24c")
const BAD = Color("#e2664c")

const FONT_BODY_PATH = "res://assets/fonts/LXGWWenKai-Regular.ttf"
const FONT_MEDIUM_PATH = "res://assets/fonts/LXGWWenKai-Medium.ttf"
const FONT_DISPLAY_PATH = "res://assets/fonts/MaShanZheng-Regular.ttf"

static var _body: Font = null
static var _medium: Font = null
static var _display: Font = null
static var _theme: Theme = null


static func body_font() -> Font:
	if _body == null:
		_body = load(FONT_BODY_PATH)
	return _body


static func medium_font() -> Font:
	if _medium == null:
		_medium = load(FONT_MEDIUM_PATH)
	return _medium


static func display_font() -> Font:
	if _display == null:
		_display = load(FONT_DISPLAY_PATH)
		_display.fallbacks = [body_font()]
	return _display


## 一张粗糙的宣纸纹：程序生成，避免再加图片资源。
static var _grain: ImageTexture = null


static func grain_texture(size: int = 128, strength: float = 0.05) -> ImageTexture:
	if _grain != null:
		return _grain
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var rng = RandomNumberGenerator.new()
	rng.seed = 20261101
	for y in size:
		for x in size:
			var n = rng.randf() * strength
			var fibre = 0.0
			if y % 7 == 0:
				fibre = 0.02
			img.set_pixel(x, y, Color(1, 1, 1, n + fibre))
	_grain = ImageTexture.create_from_image(img)
	return _grain


## 铺一张纸纹/尘点，盖在面板或整屏上（不挡点击）
static func grain(parent: Node, rect: Rect2 = Rect2(), alpha: float = 1.0) -> TextureRect:
	var node = TextureRect.new()
	node.texture = grain_texture()
	node.stretch_mode = TextureRect.STRETCH_TILE
	node.modulate = Color(1, 1, 1, 0.35 * alpha)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if rect.size == Vector2.ZERO:
		node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		node.position = rect.position
		node.size = rect.size
	parent.add_child(node)
	return node


static func flat(color: Color, border: Color = Color(0, 0, 0, 0), radius: int = 10,
		border_width: int = 0) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(maxi(0, radius))
	if border_width > 0:
		box.border_color = border
		box.border_width_left = border_width
		box.border_width_top = border_width
		box.border_width_right = border_width
		box.border_width_bottom = border_width
	box.anti_aliasing = true
	return box


## 半透明夜色面板：界面的通用底。
static func panel_style(alpha: float = 0.86, border: Color = GOLD_DIM,
		radius: int = 16, border_width: int = 2) -> StyleBox:
	if not OS.has_feature("mobile"):
		return Art.surface("panel", "normal", Vector2(22, 18))
	var box = flat(Color(INK.r, INK.g, INK.b, alpha), border, radius, border_width)
	box.shadow_color = Color(0, 0, 0, 0.55)
	box.shadow_size = 14
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 14
	box.content_margin_bottom = 14
	return box


## 木牌 / 匾额：暗红漆底、圆角和旧金线。
static func plaque_style(primary: bool = false, hover: bool = false) -> StyleBox:
	if not OS.has_feature("mobile"):
		return Art.surface("primary" if primary else "card", "hover" if hover else "normal", Vector2(18, 8))
	var base = Color("#5b2017") if primary else Color("#1b2530")
	if hover:
		base = base.lightened(0.10)
	var box = flat(Color(base.r, base.g, base.b, 0.97),
		GOLD_BRIGHT if hover else GOLD, 5, 2)
	box.shadow_color = Color(0, 0, 0, 0.55)
	box.shadow_size = 12
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box


static func draw_plate(canvas: CanvasItem, rect: Rect2, base: Color, rim: Color,
		radius: int = 14, border_width: int = 2) -> void:
	canvas.draw_style_box(flat(base, rim, radius, border_width), rect)


static func draw_gauge(canvas: CanvasItem, rect: Rect2, fraction: float, lacquer: Color) -> void:
	draw_plate(canvas, rect, Color("#141b21"), Color("#92724b"), 12, 1)
	var inset := 2.0 if rect.size.y >= 10.0 else 1.0
	var fill := rect.grow(-inset)
	fill.size.x *= clampf(fraction, 0.0, 1.0)
	if fill.size.x < 0.7:
		return
	draw_plate(canvas, fill, lacquer, Color.TRANSPARENT, 12, 0)
	if fill.size.y >= 6.0 and fill.size.x >= 7.0:
		var start := fill.position + Vector2(3.0, 2.0)
		var end := Vector2(fill.end.x - 3.0, start.y)
		canvas.draw_line(start, end, Color(1.0, 0.83, 0.58, 0.31), 1.0, true)


static func paper_style(alpha: float = 0.94, border: Color = GOLD_DIM,
		radius: int = 10) -> StyleBoxFlat:
	var box = flat(Color(PAPER.r, PAPER.g, PAPER.b, alpha), border, radius, 2)
	box.shadow_color = Color(0, 0, 0, 0.5)
	box.shadow_size = 12
	return box


static var text_scale := 1.0
static var mobile_font_factor := 1.0

static func font_size(base: int) -> int:
	return roundi(base * text_scale * mobile_font_factor)


static func scale_font(node: Control, property: String, base: int) -> void:
	node.set_meta("unscaled_" + property, base)
	node.add_theme_font_size_override(property, font_size(base))


static func refresh_text_sizes(root: Node) -> void:
	if root is Control:
		for property in ["font_size", "normal_font_size", "bold_font_size"]:
			var tag: String = "unscaled_" + property
			if root.has_meta(tag):
				root.add_theme_font_size_override(property, font_size(int(root.get_meta(tag))))
	for child in root.get_children():
		refresh_text_sizes(child)


static func tier_symbol(tier: String) -> String:
	return {"l": "●", "m": "◆", "h": "▲"}.get(tier, "◇")


static func draw_tier_shape(canvas: CanvasItem, tier: String, at: Vector2, color: Color,
		radius := 5.0) -> void:
	if tier == "l":
		canvas.draw_circle(at, radius, color)
		return
	var points := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)] if tier == "m" \
		else [Vector2(0, -1), Vector2(1, 0.84), Vector2(-1, 0.84)]
	var polygon := PackedVector2Array()
	for point in points:
		polygon.append(at + point * radius)
	canvas.draw_colored_polygon(polygon, color)


static func make_theme() -> Theme:
	if _theme != null:
		return _theme
	var theme = Theme.new()
	theme.default_font = body_font()
	theme.default_font_size = 20

	# 按钮是一张宣纸签条：纸底、墨字、金边；按下像被朱砂按了一下
	theme.set_stylebox("normal", "Button",
		flat(Color(PAPER.r, PAPER.g, PAPER.b, 0.93), GOLD_DIM, 3, 2))
	theme.set_stylebox("hover", "Button",
		flat(Color(0.99, 0.95, 0.85, 0.98), GOLD_BRIGHT, 3, 2))
	theme.set_stylebox("pressed", "Button",
		flat(Color(VERMILION.r, VERMILION.g, VERMILION.b, 0.95), GOLD_BRIGHT, 3, 2))
	theme.set_stylebox("disabled", "Button",
		flat(Color(0.30, 0.28, 0.24, 0.55), Color(0.46, 0.42, 0.34, 0.7), 3, 1))
	theme.set_stylebox("focus", "Button", Art.focus_style())
	theme.set_color("font_color", "Button", INK)
	theme.set_color("font_hover_color", "Button", Color("#2b1a12"))
	theme.set_color("font_pressed_color", "Button", Color("#fff3dc"))
	theme.set_color("font_disabled_color", "Button", Color(0.72, 0.68, 0.6, 0.75))
	theme.set_font("font", "Button", medium_font())
	theme.set_font_size("font_size", "Button", 22)

	theme.set_stylebox("panel", "PanelContainer", panel_style(0.9))
	theme.set_stylebox("panel", "Panel", panel_style(0.9))

	theme.set_color("font_color", "Label", TEXT)
	theme.set_font("font", "Label", body_font())
	theme.set_font_size("font_size", "Label", 20)

	theme.set_color("default_color", "RichTextLabel", TEXT)
	theme.set_font("normal_font", "RichTextLabel", body_font())
	theme.set_font("bold_font", "RichTextLabel", medium_font())
	theme.set_font_size("normal_font_size", "RichTextLabel", 20)
	theme.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	theme.set_constant("line_separation", "RichTextLabel", 6)

	theme.set_stylebox("scroll", "VScrollBar",
		flat(Color(0, 0, 0, 0.25), Color(0, 0, 0, 0), 5))
	theme.set_stylebox("grabber", "VScrollBar",
		flat(Color(GOLD_DIM.r, GOLD_DIM.g, GOLD_DIM.b, 0.85), Color(0, 0, 0, 0), 5))
	theme.set_stylebox("grabber_highlight", "VScrollBar",
		flat(GOLD, Color(0, 0, 0, 0), 5))
	theme.set_stylebox("grabber_pressed", "VScrollBar",
		flat(GOLD_BRIGHT, Color(0, 0, 0, 0), 5))

	theme.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	theme.set_stylebox("panel", "PopupMenu", paper_style(0.98))
	theme.set_stylebox("panel", "AcceptDialog", panel_style(0.97, GOLD_DIM, 18))
	theme.set_stylebox("embedded_border", "Window", panel_style(0.97, GOLD_DIM, 18))
	for input_type in ["LineEdit", "TextEdit"]:
		theme.set_stylebox("normal", input_type, panel_style(0.94, GOLD_DIM, 12, 1))
		theme.set_stylebox("focus", input_type, flat(Color.TRANSPARENT, GOLD_BRIGHT, 12, 2))
		theme.set_color("font_color", input_type, TEXT)
	theme.set_stylebox("panel", "TooltipPanel", panel_style(0.97, GOLD_DIM, 12, 1))
	theme.set_color("font_color", "TooltipLabel", TEXT)
	theme.set_color("font_color", "PopupMenu", INK)
	if not OS.has_feature("mobile"):
		for state in ["normal", "hover", "pressed", "disabled"]:
			theme.set_stylebox(state, "Button", Art.surface("card", state, Vector2(16, 8)))
		theme.set_color("font_color", "Button", TEXT)
		theme.set_color("font_hover_color", "Button", GOLD_BRIGHT)
		theme.set_color("font_pressed_color", "Button", Color("#fff4d5"))
		theme.set_stylebox("slider", "HSlider", flat(Color("#273d3c"), Color("#59706a"), 2, 1))
		theme.set_stylebox("grabber_area", "HSlider", flat(JADE, Color.TRANSPARENT, 2))
		theme.set_stylebox("grabber_area_highlight", "HSlider", flat(GOLD, Color.TRANSPARENT, 2))
	_theme = theme
	return theme


# ── 控件工厂 ────────────────────────────────────────────────────────────────
static func label(text: String, size: int = 20, color: Color = TEXT) -> Label:
	var node = Label.new()
	node.text = text
	node.add_theme_font_override("font", body_font())
	scale_font(node, "font_size", size)
	node.add_theme_color_override("font_color", color)
	return node


static func strong(text: String, size: int = 20, color: Color = TEXT) -> Label:
	var node = label(text, size, color)
	node.add_theme_font_override("font", medium_font())
	return node


static func title(text: String, size: int = 44, color: Color = GOLD_BRIGHT) -> Label:
	var node = Label.new()
	node.text = text
	node.add_theme_font_override("font", display_font())
	scale_font(node, "font_size", size)
	node.add_theme_color_override("font_color", color)
	node.add_theme_constant_override("outline_size", 0)
	node.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	node.add_theme_constant_override("shadow_offset_x", 2)
	node.add_theme_constant_override("shadow_offset_y", 3)
	return node


## 按钮样式直接挂在控件上，不依赖主题继承：即使某个界面没接到主题，
## 也不会退化成一排只有文字的透明块。
static func apply_button_style(node: Button, base_size: int = 20,
		plaque: bool = false) -> void:
	if not OS.has_feature("mobile"):
		var kind = "primary" if plaque else "card"
		for state in ["normal", "hover", "pressed", "disabled"]:
			node.add_theme_stylebox_override(state, Art.surface(kind, state, Vector2(16, 8)))
		node.add_theme_stylebox_override("focus", Art.focus_style())
		node.add_theme_color_override("font_color", GOLD_BRIGHT if plaque else TEXT)
		node.add_theme_color_override("font_hover_color", Color("#fff0c9"))
		node.add_theme_color_override("font_pressed_color", Color("#fff6e3"))
		node.add_theme_color_override("font_disabled_color", Color("#929082"))
		node.add_theme_font_override("font", medium_font())
		scale_font(node, "font_size", base_size)
		node.add_theme_constant_override("outline_size", 0)
		node.focus_mode = Control.FOCUS_ALL
		return
	if plaque:
		# 朱漆匾：主操作才用
		node.add_theme_stylebox_override("normal", plaque_style(true, false))
		node.add_theme_stylebox_override("hover", plaque_style(true, true))
		node.add_theme_stylebox_override("pressed",
			flat(Color(VERMILION.r, VERMILION.g, VERMILION.b, 0.98), GOLD_BRIGHT, 5, 2))
		node.add_theme_stylebox_override("disabled",
			flat(Color(0.18, 0.16, 0.14, 0.7), Color(0.4, 0.36, 0.28, 0.8), 5, 1))
		node.add_theme_color_override("font_color", GOLD_BRIGHT)
		node.add_theme_color_override("font_hover_color", Color("#fff3d6"))
		node.add_theme_color_override("font_pressed_color", Color("#fff8e8"))
		node.add_theme_color_override("font_disabled_color",
			Color(0.62, 0.57, 0.47, 0.85))
		node.add_theme_font_override("font", display_font())
		scale_font(node, "font_size", base_size + 2)
		node.add_theme_constant_override("outline_size", 2)
		node.add_theme_color_override("font_outline_color", Color(0.16, 0.05, 0.03, 0.6))
		return
	# 宣纸签条：纸底墨字，边上一道金线，像贴在木牌上的纸条
	node.add_theme_stylebox_override("normal",
		flat(Color(PAPER.r, PAPER.g, PAPER.b, 0.93), GOLD_DIM, 3, 2))
	node.add_theme_stylebox_override("hover",
		flat(Color(0.99, 0.95, 0.85, 0.98), GOLD_BRIGHT, 3, 2))
	node.add_theme_stylebox_override("pressed",
		flat(Color(VERMILION.r, VERMILION.g, VERMILION.b, 0.95), GOLD_BRIGHT, 3, 2))
	node.add_theme_stylebox_override("disabled",
		flat(Color(0.30, 0.28, 0.24, 0.55), Color(0.46, 0.42, 0.34, 0.7), 3, 1))
	node.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	node.add_theme_color_override("font_color", INK)
	node.add_theme_color_override("font_hover_color", Color("#2b1a12"))
	node.add_theme_color_override("font_pressed_color", Color("#fff3dc"))
	node.add_theme_color_override("font_disabled_color", Color(0.72, 0.68, 0.6, 0.75))
	node.add_theme_font_override("font", display_font())
	scale_font(node, "font_size", base_size + 1)


## 把纸签条按钮标成"已选中/已开启"：朱砂底、纸色字。
## 注意：纸签条的常态是浅底墨字，所以不能只把字改成浅色——那样在纸上就看不见了。
static func set_button_active(node: Button, active: bool) -> void:
	if node == null:
		return
	if not OS.has_feature("mobile"):
		var padding = Vector2(8, 6) if node.custom_minimum_size.x > 0 and node.custom_minimum_size.x <= 96 else Vector2(16, 8)
		padding = node.get_meta("style_padding", padding)
		for state in ["normal", "hover", "pressed", "disabled"]:
			node.add_theme_stylebox_override(state, Art.surface("primary" if active else "card", state, padding))
		node.add_theme_color_override("font_color", GOLD_BRIGHT if active else TEXT)
		node.add_theme_color_override("font_hover_color", Color("#fff0c9"))
		node.set_meta("active", active)
		return
	if active:
		node.add_theme_stylebox_override("normal",
			flat(Color(VERMILION.r, VERMILION.g, VERMILION.b, 0.92), GOLD_BRIGHT, 3, 2))
		node.add_theme_stylebox_override("hover",
			flat(Color(VERMILION_LIGHT.r, VERMILION_LIGHT.g, VERMILION_LIGHT.b, 0.95),
				GOLD_BRIGHT, 3, 2))
		node.add_theme_color_override("font_color", Color("#fff3d6"))
		node.add_theme_color_override("font_hover_color", Color("#fff8e8"))
	else:
		node.add_theme_stylebox_override("normal",
			flat(Color(PAPER.r, PAPER.g, PAPER.b, 0.93), GOLD_DIM, 3, 2))
		node.add_theme_stylebox_override("hover",
			flat(Color(0.99, 0.95, 0.85, 0.98), GOLD_BRIGHT, 3, 2))
		node.add_theme_color_override("font_color", INK)
		node.add_theme_color_override("font_hover_color", Color("#2b1a12"))


static func button(text: String, size: int = 20, min_width: float = 0,
		min_height: float = 0, plaque: bool = false) -> Button:
	var node = Button.new()
	node.text = text
	node.set_meta("primary", plaque)
	apply_button_style(node, size, plaque)
	if min_width > 0.0 or min_height > 0.0:
		node.custom_minimum_size = Vector2(min_width, min_height)
	if not OS.has_feature("mobile") and min_width > 0 and min_width <= 96:
		for state in ["normal", "hover", "pressed", "disabled"]:
			node.add_theme_stylebox_override(state, Art.surface("primary" if plaque else "card", state, Vector2(8, 6)))
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return node


static func panel(alpha: float = 0.9, border: Color = GOLD_DIM, radius: int = 12,
		border_width: int = 2) -> PanelContainer:
	var node = PanelContainer.new()
	node.add_theme_stylebox_override("panel",
		panel_style(alpha, border, radius, border_width))
	return node


static func vbox(separation: int = 8) -> VBoxContainer:
	var node = VBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	return node


static func hbox(separation: int = 8) -> HBoxContainer:
	var node = HBoxContainer.new()
	node.add_theme_constant_override("separation", separation)
	return node


static func spacer(height: float = 8.0) -> Control:
	var node = Control.new()
	node.custom_minimum_size = Vector2(0, height)
	return node


static func hline(color: Color = GOLD_DIM, thickness: float = 1.0) -> ColorRect:
	var node = ColorRect.new()
	node.color = Color(color.r, color.g, color.b, color.a * 0.7)
	node.custom_minimum_size = Vector2(0, thickness)
	return node


## 立绘统一从这里取，并且缓存住：不要在 _draw() 里临时 load 资源，
## 那会让贴图在绘制回调里才建立 GPU 资源，画面会先闪出一块白。
static var _sprite_cache: Dictionary = {}
static var canvas_size := Vector2(1600, 900)
static var _capstone_cache: Dictionary = {}
static var _portrait_frames: Dictionary = {}
static var _portrait_motion: Dictionary = {}
static var _portrait_legacy: Dictionary = {}

## Anchor an existing 1600×900 placement without stretching controls or type.
static func pin(control: Control, vertical: float = 1.0) -> void:
	control.anchor_top = vertical
	control.anchor_bottom = vertical
	control.offset_top -= 900.0 * vertical
	control.offset_bottom -= 900.0 * vertical

static func extend_to_bottom(control: Control, margin: float = 40) -> void:
	control.anchor_bottom = 1.0
	control.offset_bottom = -margin

static func fit_font(font: Font, text: String, width: float, preferred: int = 13) -> int:
	var result := preferred
	while result > 1 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, result).x > width:
		result -= 1
	return result

## Use the same actor/clip priority as UnitView. Standalone PNGs can be older designs.
static func capstone_sprite(type: String, path_id: int) -> Texture2D:
	var actor := "%s-e%d" % [type, path_id]
	if _capstone_cache.has(actor): return _capstone_cache[actor]
	if _portrait_frames.is_empty():
		_portrait_frames = JSON.parse_string(FileAccess.get_file_as_string("res://data/actor_frames.json"))
		_portrait_motion = JSON.parse_string(FileAccess.get_file_as_string("res://data/actor_motion.json"))
		_portrait_legacy = JSON.parse_string(FileAccess.get_file_as_string("res://data/evolution_art_v040.json"))
	var portrait: Texture2D
	if type == "dragon":
		var info: Dictionary = _portrait_motion.get("dragon", _portrait_frames["dragon"])
		var clip: String = ["idle", "far_idle", "dual"][clampi(path_id - 1, 0, 2)]
		var r: Array = info.clips[clip][0].rect
		var atlas := AtlasTexture.new()
		atlas.atlas = load("res://" + String(info.file))
		atlas.region = Rect2(r[0], r[1], r[2], r[3])
		atlas.filter_clip = true
		_capstone_cache[actor] = atlas
		return atlas
	if _portrait_frames.has(actor):
		var info: Dictionary = _portrait_motion.get(actor, _portrait_frames[actor])
		var sequence: Array = info.clips.get("idle", info.clips.get("action", []))
		if not sequence.is_empty():
			var r: Array = sequence[0].rect
			var atlas := AtlasTexture.new()
			atlas.atlas = load("res://" + String(info.file))
			atlas.region = Rect2(r[0], r[1], r[2], r[3])
			atlas.filter_clip = true
			portrait = atlas
	elif _portrait_legacy.has(type):
		var info: Dictionary = _portrait_legacy[type]
		for frame in info.frames:
			if int(frame.path) != path_id: continue
			var r: Array = frame.region
			var atlas := AtlasTexture.new()
			atlas.atlas = load("res://" + String(info.file))
			atlas.region = Rect2(r[0], r[1], r[2], r[3])
			atlas.filter_clip = true
			portrait = atlas
	if portrait == null:
		var file := "res://assets/sprites/" + actor + ".png"
		if ResourceLoader.exists(file): portrait = load(file)
	_capstone_cache[actor] = portrait
	return portrait


static func sprite(name: String) -> Texture2D:
	if _sprite_cache.has(name):
		return _sprite_cache[name]
	var path = "res://assets/sprites/%s.png" % ("shell-open" if name=="shell" else name)
	if name == "sedan" and ResourceLoader.exists("res://assets/sprites/sedan-v041.png"):
		path = "res://assets/sprites/sedan-v041.png"
	var texture: Texture2D = null
	var portrait_actor = "phase-veil" if name == "phaseguard" else name
	var atlas_path = "res://assets/sprites/animation/%s.png" % portrait_actor
	var animated_portraits = ["bride", "gust", "firework", "squash", "dragon", "returner",
		"incense-thief", "sky-ferry",
		"matchmaker", "phaseguard", "tamer", "shieldguard", "reedboat", "dreambell",
		"ruin-cap", "sky-kite", "wish-till", "cash-pod", "ember-cicada",
		"flinch", "wave-herald", "formless", "reed-shot"]
	if name in animated_portraits and ResourceLoader.exists(atlas_path):
		var sheet: Texture2D = load(atlas_path)
		var rows = {"incense-thief": 4, "sky-ferry": 5, "dragon": 6, "returner": 5, "phaseguard": 4, "shieldguard": 4, "reedboat": 4,
			"ember-cicada": 5, "flinch": 4, "wave-herald": 4, "formless": 4, "reed-shot": 4, "tamer": 4}
		var portrait := AtlasTexture.new()
		portrait.atlas = sheet
		portrait.region = Rect2(Vector2.ZERO, sheet.get_size() / Vector2(4.0, float(rows.get(name, 2))))
		portrait.filter_clip = true
		texture = portrait
	elif ResourceLoader.exists(path):
		texture = load(path)
	_sprite_cache[name] = texture
	return texture


## 开局把所有立绘先读进缓存，避免第一帧临时加载。
static func warm_sprites(names: Array) -> void:
	for name in names:
		sprite(String(name))


## 在矩形内等比画一株草木的图标。龟甲罩在 v0.2.4 里就是程序化绘制的，
## 没有立绘文件，这里同样手绘一个壳，保证卡面不空。
static func draw_plant_icon(canvas: CanvasItem, plant_id: String, rect: Rect2,
		modulate: Color = Color(1, 1, 1, 1)) -> void:
	if plant_id == "shell" and sprite("shell")==null:
		_draw_shell_icon(canvas, rect, modulate)
		return
	var texture := sprite(plant_id)
	if texture == null:
		return
	var tex_size := texture.get_size()
	var scale := minf(rect.size.x / tex_size.x, rect.size.y / tex_size.y)
	var drawn := tex_size * scale
	var pos := rect.position + (rect.size - drawn) * 0.5
	canvas.draw_texture_rect(texture, Rect2(pos, drawn), false, modulate)


static func _draw_shell_icon(canvas: CanvasItem, rect: Rect2, modulate: Color) -> void:
	var center := rect.get_center() + Vector2(0, rect.size.y * 0.16)
	var radius := minf(rect.size.x, rect.size.y * 1.35) * 0.42
	var dome := Color(0.55, 0.64, 0.48, modulate.a)
	var edge := Color(0.34, 0.41, 0.31, modulate.a)
	canvas.draw_arc(center, radius, PI, TAU, 28, dome, 5.0)
	canvas.draw_arc(center, radius * 0.62, PI, TAU, 22, edge, 3.0)
	for i in 5:
		var a := PI + (float(i) + 0.5) / 5.0 * PI
		canvas.draw_line(center + Vector2(cos(a), sin(a)) * radius * 0.24,
			center + Vector2(cos(a), sin(a)) * radius, edge, 2.0)
	canvas.draw_line(center + Vector2(-radius, 0), center + Vector2(radius, 0), edge,
		3.0)


## 朱砂印章：标题旁的小方块，写两三个字。
static func seal(text: String, size: float = 44.0, color: Color = VERMILION) -> Control:
	var holder = Control.new()
	holder.custom_minimum_size = Vector2(size, size)
	var box = Panel.new()
	box.add_theme_stylebox_override("panel", flat(color, Color(0.98, 0.85, 0.7, 0.55),
		6, 2))
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(box)
	var text_node = Label.new()
	text_node.text = text
	text_node.add_theme_font_override("font", display_font())
	text_node.add_theme_font_size_override("font_size", int(size * 0.5))
	text_node.add_theme_color_override("font_color", Color(1, 0.95, 0.88))
	text_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	text_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	holder.add_child(text_node)
	return holder


static func rich(size: int = 20, color: Color = TEXT) -> RichTextLabel:
	var node = RichTextLabel.new()
	node.bbcode_enabled = true
	node.fit_content = false
	node.scroll_active = false
	node.add_theme_font_override("normal_font", body_font())
	node.add_theme_font_override("bold_font", medium_font())
	scale_font(node, "normal_font_size", size)
	scale_font(node, "bold_font_size", size)
	node.add_theme_color_override("default_color", color)
	node.add_theme_constant_override("line_separation", 7)
	return node


static func tone_color(tone: String) -> Color:
	match tone:
		"cost":
			return Color("#e08a4a")
		"hp":
			return Color("#8fc48a")
		"atk":
			return Color("#e2664c")
		"time":
			return Color("#79b6bf")
		"gold":
			return GOLD_BRIGHT
		"desc":
			return TEXT_DIM
	return TEXT

## Built-in dialog buttons reset their minimum size; style margins remain authoritative.
static func style_dialog(dialog: AcceptDialog) -> void:
	dialog.theme=make_theme()
	var button:=dialog.get_ok_button()
	apply_button_style(button,18)
	button.add_theme_color_override("font_focus_color", INK if OS.has_feature("mobile") else TEXT)
	for state in ["normal","hover","pressed","disabled"]:
		var style: StyleBox=button.get_theme_stylebox(state).duplicate()
		style.content_margin_left=28;style.content_margin_right=28
		style.content_margin_top=10;style.content_margin_bottom=10
		button.add_theme_stylebox_override(state,style)
