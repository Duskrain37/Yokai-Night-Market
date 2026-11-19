shader_type canvas_item;
render_mode unshaded;
uniform sampler2D clearance : filter_linear, repeat_disable;
uniform sampler2D brush : filter_linear, repeat_enable;
uniform float now;
uniform float edge;
uniform float previous_edge;
uniform float current_mass;
uniform float previous_mass;

void fragment() {
	vec2 uv = UV;
	vec2 roll = vec2(uv.x * 2.7 + now * .023, uv.y * 3.4 - now * .013);
	float n = texture(brush, roll).a;
	float m = texture(brush, roll * 1.42 + vec2(.21, .13)).a;
	float fringe = .022 * (n - .35) + sin(uv.y * 38.0 + now * .62) * .005;
	float bank = smoothstep(edge - .043, edge + .011, uv.x + fringe) * current_mass;
	float old_bank = smoothstep(previous_edge - .043, previous_edge + .011, uv.x + fringe) * previous_mass;
	float passing = 1.0 - texture(clearance, uv).a;
	float y_mask = smoothstep(.15, .21, uv.y) * (1.0 - smoothstep(.82, .89, uv.y));
	float density = max(bank, old_bank) * y_mask * passing;
	vec3 ink = mix(vec3(.29,.43,.44), vec3(.59,.66,.65), n * .6 + m * .25);
	COLOR = vec4(ink, density * (.15 + .38 * n * m));
}
