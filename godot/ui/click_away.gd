## Consume the dismissing click so it cannot also place, shovel, upgrade or fire.
extends Node
var panel: Control
var closed: Callable
func _input(event: InputEvent) -> void:
	if not is_instance_valid(panel) or not panel.is_visible_in_tree(): return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not panel.get_global_rect().has_point(event.position):
			get_viewport().set_input_as_handled()
			closed.call()

static func attach(owner: Node, target: Control, callback: Callable) -> Node:
	var watcher = load("res://ui/click_away.gd").new()
	watcher.panel = target; watcher.closed = callback
	owner.add_child(watcher)
	target.tree_exited.connect(watcher.queue_free)
	return watcher
