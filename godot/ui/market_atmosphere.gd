## Ambient motion is deliberately slow and stays behind interactive controls.
extends Control
var elapsed = 0.0
var strength = 1.0
var _particles: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var random = RandomNumberGenerator.new()
	random.seed = 561113
	for i in 26:
		_particles.append(Vector4(random.randf_range(580, 1570), random.randf_range(130, 870), random.randf_range(0, TAU), random.randf_range(1, 2.8)))
	if MarketArt.reduced_motion:
		strength = 0.5
		set_process(false)

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	for particle in _particles:
		var x = particle.x + sin(elapsed * 0.28 + particle.z) * 18
		var y = fposmod(particle.y - elapsed * (5 + particle.w), 900)
		var alpha = (0.15 + 0.25 * (0.5 + 0.5 * sin(elapsed * 0.8 + particle.z))) * strength
		draw_circle(Vector2(x, y), particle.w * 4, Color(1, 0.63, 0.23, alpha * 0.06))
		draw_circle(Vector2(x, y), particle.w * 0.7, Color(1, 0.78, 0.42, alpha))
