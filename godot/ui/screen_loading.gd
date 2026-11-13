extends Control
var fraction = 0.0
var displayed = 0.0
var elapsed = 0.0
var caption = "灯火将明"
var backdrop: Texture2D
var _status: Label
var _panel: Control
var _gauge: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var picture = TextureRect.new()
	picture.texture = backdrop
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var veil = ColorRect.new()
	veil.color = Color(0.02, 0.05, 0.06, 0.24)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var brand = Ui.title("妖怪夜市", 52)
	brand.position = Vector2(72, 64)
	add_child(brand)
	var signature = Ui.label("子 时 开 张  ·  旧 物 有 灵", 16, Ui.TEXT_DIM)
	signature.position = Vector2(78, 132)
	add_child(signature)
	_panel = Ui.panel()
	add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 48
	_panel.offset_right = -48
	_panel.offset_top = -155
	_panel.offset_bottom = -48
	var row = Ui.hbox(30)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(row)
	row.add_child(MarketArt.icon_control("lantern", 48, Ui.GOLD_BRIGHT))
	var titles = Ui.vbox(3)
	titles.custom_minimum_size.x = 340
	row.add_child(titles)
	titles.add_child(Ui.title("灯火将明", 30))
	var subtitle = Ui.label(caption, 16, Ui.TEXT_DIM)
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.custom_minimum_size.x = 340
	titles.add_child(subtitle)
	_gauge = Control.new()
	_gauge.custom_minimum_size = Vector2(640, 32)
	_gauge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_gauge.draw.connect(func(): _draw_gauge(_gauge))
	row.add_child(_gauge)
	_status = Ui.strong("0%", 24, Ui.GOLD_BRIGHT)
	_status.custom_minimum_size.x = 80
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_status)

func _process(delta: float) -> void:
	elapsed += delta
	displayed = move_toward(displayed, fraction, delta * 2.8)
	if _status != null:
		_status.text = "%d%%" % mini(100, floori(displayed * 100 + 0.01))
		_gauge.queue_redraw()

func _draw_gauge(canvas: Control) -> void:
	var bar = Rect2(0, 11, canvas.size.x, 10)
	Ui.draw_gauge(canvas, bar, displayed, Ui.JADE)
	var x = displayed * bar.size.x
	var glow = 0.7 if MarketArt.reduced_motion else 0.62 + 0.22 * sin(elapsed * 5)
	canvas.draw_circle(Vector2(x, 16), 9, Color(1, 0.68, 0.3, glow * 0.13))
	MarketArt.diamond(canvas, Vector2(x, 16), 4, Ui.GOLD_BRIGHT, true)
