extends Node

const HOLD_SECONDS := 0.45
const DRAG_DISTANCE := 20.0
var game = null
var finger := -1
var origin := Vector2.ZERO
var current := Vector2.ZERO
var held := 0.0
var moved := false
var long_fired := false
var scroll: ScrollContainer = null
var velocity := 0.0
var last_drag_at := 0

func _ready() -> void:
	Input.emulate_mouse_from_touch = false
	Input.emulate_touch_from_mouse = false

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if finger >= 0: return
			finger=event.index;origin=event.position;current=origin;held=0;long_fired=false;moved=false;velocity=0
			scroll=_scroll_at(get_tree().root,origin)
			_motion(origin)
		else:
			if event.index != finger: return
			current=event.position
			if not long_fired:
				var aiming: bool = game.screen=="battle" and game.hud!=null and game.hud.card_selected>=0 and scroll==null
				if not moved or aiming: _click(current,MOUSE_BUTTON_LEFT)
			finger=-1
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index==finger:
		var previous := current
		current=event.position
		if current.distance_to(origin)>DRAG_DISTANCE: moved=true
		if moved and scroll!=null and is_instance_valid(scroll):
			var dy := current.y-previous.y
			var divisor := maxf(0.1,scroll.get_global_transform_with_canvas().get_scale().y)
			scroll.scroll_vertical -= roundi(dy/divisor)
			var now := Time.get_ticks_msec()
			velocity = -dy / maxf(0.012,float(now-last_drag_at)/1000.0) / divisor
			last_drag_at=now
		_motion(current)
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if finger>=0:
		held += delta
		if not moved and not long_fired and held>=HOLD_SECONDS:
			long_fired=true
			_click(current,MOUSE_BUTTON_RIGHT)
			if OS.has_feature("android"): Input.vibrate_handheld(20)
	elif scroll!=null and is_instance_valid(scroll) and absf(velocity)>20:
		scroll.scroll_vertical += roundi(velocity*delta)
		velocity=move_toward(velocity,0,2400*delta)

func _click(at: Vector2, button: int) -> void:
	for pressed in [true,false]:
		var mouse := InputEventMouseButton.new()
		mouse.position=at;mouse.global_position=at;mouse.button_index=button;mouse.pressed=pressed
		get_tree().root.push_input(mouse,true)

func _motion(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position=at;event.global_position=at
	get_tree().root.push_input(event,true)

func _scroll_at(node: Node, at: Vector2) -> ScrollContainer:
	var children := node.get_children()
	children.reverse()
	for child in children:
		if child is CanvasItem and not child.is_visible_in_tree(): continue
		var result := _scroll_at(child,at)
		if result!=null: return result
	if node is ScrollContainer and node.get_global_rect().has_point(at): return node
	return null
