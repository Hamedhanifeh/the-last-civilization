shader_type spatial;
render_mode cull_disabled;

varying vec3 canvas_pos;
uniform sampler2D surface_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;

void vertex() {
	canvas_pos = VERTEX;
	float ridge = 1.0 - smoothstep(0.03, 0.48, abs(VERTEX.x));
	float span = 1.0 - min(1.0, abs(VERTEX.z) * 2.0);
	VERTEX.y -= sin(span * 1.57) * ridge * 0.026;
}

void fragment() {
	float fold = 0.91 + 0.09 * cos(canvas_pos.z * 15.0 + sin(canvas_pos.y * 13.0) * 0.69);
	float fibers = sin(canvas_pos.z * 397.0) * sin(canvas_pos.y * 327.0) * 0.024;
	vec2 pos = fract(vec2(canvas_pos.y + canvas_pos.x * 0.74, canvas_pos.z) * 0.82 + vec2(0.54));
	vec3 cloth = texture(surface_atlas, vec2(0.508, 0.008) + pos * 0.484).rgb;
	float strength = dot(cloth, vec3(0.23, 0.65, 0.12));
	ALBEDO = COLOR.rgb * (fold + fibers) * (0.77 + strength * 0.30);
	ROUGHNESS = 0.95;
	SPECULAR = 0.17;
}
