## 视觉基座：配色、字体、控件样式与常用控件工厂。
##
## 全作统一走这一套，界面里不再出现零散色值：夜色底、宣纸面、金线边、朱砂点睛。
## 字体三档：LXGW 文楷正文、文楷中等字重做小标题、马善政毛笔字做标题与印章。
class_name Ui
extends RefCounted

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
const TEXT_DIM = Color("#b3a486")
const TEXT_FAINT = Color("#8a7d64")
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
	return _display


static func flat(color: Color, border: Color = Color(0, 0, 0, 0), radius: int = 10,
		border_width: int = 0) -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.bg_color = color
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
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
		radius: int = 12, border_width: int = 2) -> StyleBoxFlat:
	var box = flat(Color(INK.r, INK.g, INK.b, alpha), border, radius, border_width)
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = 10
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 14
	box.content_margin_bottom = 14
	return box


static func paper_style(alpha: float = 0.94, border: Color = GOLD_DIM,
		radius: int = 10) -> StyleBoxFlat:
	var box = flat(Color(PAPER.r, PAPER.g, PAPER.b, alpha), border, radius, 2)
	box.shadow_color = Color(0, 0, 0, 0.5)
	box.shadow_size = 12
	return box


static func make_theme() -> Theme:
	if _theme != null:
		return _theme
	var theme = Theme.new()
	theme.default_font = body_font()
	theme.default_font_size = 20

	theme.set_stylebox("normal", "Button",
		flat(Color(0.09, 0.13, 0.16, 0.92), GOLD_DIM, 10, 2))
	theme.set_stylebox("hover", "Button",
		flat(Color(0.15, 0.21, 0.25, 0.96), GOLD, 10, 2))
	theme.set_stylebox("pressed", "Button",
		flat(Color(0.32, 0.14, 0.11, 0.97), VERMILION_LIGHT, 10, 2))
	theme.set_stylebox("disabled", "Button",
		flat(Color(0.09, 0.11, 0.13, 0.7), Color(0.36, 0.32, 0.26, 0.8), 10, 1))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", GOLD_BRIGHT)
	theme.set_color("font_pressed_color", "Button", Color("#ffe9cf"))
	theme.set_color("font_disabled_color", "Button", Color(0.55, 0.5, 0.42, 0.9))
	theme.set_font("font", "Button", medium_font())
	theme.set_font_size("font_size", "Button", 20)

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
	theme.set_color("font_color", "PopupMenu", INK)
	_theme = theme
	return theme


# ── 控件工厂 ────────────────────────────────────────────────────────────────
static func label(text: String, size: int = 20, color: Color = TEXT) -> Label:
	var node = Label.new()
	node.text = text
	node.add_theme_font_override("font", body_font())
	node.add_theme_font_size_override("font_size", size)
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
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	node.add_theme_constant_override("outline_size", 0)
	node.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	node.add_theme_constant_override("shadow_offset_x", 2)
	node.add_theme_constant_override("shadow_offset_y", 3)
	return node


## 按钮样式直接挂在控件上，不依赖主题继承：即使某个界面没接到主题，
## 也不会退化成一排只有文字的透明块。
static func apply_button_style(node: Button, font_size: int = 20) -> void:
	node.add_theme_stylebox_override("normal",
		flat(Color(0.08, 0.12, 0.15, 0.94), GOLD_DIM, 10, 2))
	node.add_theme_stylebox_override("hover",
		flat(Color(0.16, 0.22, 0.26, 0.97), GOLD, 10, 2))
	node.add_theme_stylebox_override("pressed",
		flat(Color(0.34, 0.15, 0.11, 0.98), VERMILION_LIGHT, 10, 2))
	node.add_theme_stylebox_override("disabled",
		flat(Color(0.07, 0.09, 0.11, 0.72), Color(0.34, 0.3, 0.24, 0.8), 10, 1))
	node.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	node.add_theme_color_override("font_color", TEXT)
	node.add_theme_color_override("font_hover_color", GOLD_BRIGHT)
	node.add_theme_color_override("font_pressed_color", Color("#ffe9cf"))
	node.add_theme_color_override("font_disabled_color", Color(0.52, 0.47, 0.39, 0.9))
	node.add_theme_font_override("font", medium_font())
	node.add_theme_font_size_override("font_size", font_size)


static func button(text: String, size: int = 20, min_width: float = 0,
		min_height: float = 0) -> Button:
	var node = Button.new()
	node.text = text
	apply_button_style(node, size)
	if min_width > 0.0 or min_height > 0.0:
		node.custom_minimum_size = Vector2(min_width, min_height)
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


static func sprite(name: String) -> Texture2D:
	if _sprite_cache.has(name):
		return _sprite_cache[name]
	var path = "res://assets/sprites/%s.png" % name
	var texture: Texture2D = null
	if ResourceLoader.exists(path):
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
	if plant_id == "shell":
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
	node.add_theme_font_size_override("normal_font_size", size)
	node.add_theme_font_size_override("bold_font_size", size)
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
