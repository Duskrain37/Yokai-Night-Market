extends Control

var fraction := 0.0
var displayed := 0.0
var elapsed := 0.0
var caption := "灯火将明"
var backdrop: Texture2D
var _status: Label
var _panel: Control
var _gauge: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var picture := TextureRect.new()
	picture.texture = backdrop
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var veil := ColorRect.new()
	veil.color = Color(0.03, 0.07, 0.09, 0.18)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_panel = Ui.panel(0.67, Ui.GOLD_DIM, 26, 1)
	add_child(_panel)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -292
	_panel.offset_right = 292
	_panel.offset_top = 78
	_panel.offset_bottom = 312
	var box = Ui.vbox(10)
	_panel.add_child(box)
	var title = Ui.title("加载中", 62, Ui.GOLD_BRIGHT)
	title.add_theme_color_override("font_outline_color", Color("#402519"))
	title.add_theme_constant_override("outline_size", 5)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var subtitle = Ui.label(caption, 21, Ui.TEXT_DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)
	box.add_child(Ui.spacer(12))
	var gauge := Control.new()
	_gauge = gauge
	gauge.custom_minimum_size = Vector2(520, 29)
	gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gauge.draw.connect(func(): _draw_gauge(gauge))
	box.add_child(gauge)
	_status = Ui.label("0%", 18, Ui.GOLD_BRIGHT)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)


func _process(delta: float) -> void:
	elapsed += delta
	displayed = move_toward(displayed, fraction, delta * 2.8)
	if _status != null:
		_status.text = "%d%%" % mini(100, floori(displayed * 100.0 + 0.01))
	_gauge.queue_redraw()


func _draw_gauge(canvas: Control) -> void:
	var bar := Rect2(12.0, 10.0, canvas.size.x - 24.0, 11.0)
	Ui.draw_gauge(canvas, bar, displayed, Color("#a85537"))
	var x = bar.position.x + displayed * bar.size.x
	var glow = 0.62 + 0.22 * sin(elapsed * 5.0)
	canvas.draw_circle(Vector2(x, 15.5), 11, Color(1, 0.58, 0.26, glow * 0.19))
	canvas.draw_circle(Vector2(x, 15.5), 4, Color("#ffe1a2"))
	for i in 3:
		var drift = fposmod(elapsed * (13.0 + i * 3.0) + i * 4.0, 25.0)
		canvas.draw_circle(Vector2(x - drift, 12.5 - drift * 0.45), 1.4,
			Color(1, 0.69, 0.34, 0.8 * (1.0 - drift / 25.0)))
