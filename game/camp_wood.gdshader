shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

varying vec3 board_pos;
uniform sampler2D surface_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;

float hash_cell(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 blend = fract(p);
	blend = blend * blend * (3.0 - 2.0 * blend);
	return mix(mix(hash_cell(cell), hash_cell(cell + vec2(1.0, 0.0)), blend.x),
		mix(hash_cell(cell + vec2(0.0, 1.0)), hash_cell(cell + 1.0), blend.x), blend.y);
}

void vertex() {
	board_pos = VERTEX;
}

void fragment() {
	float warp = value_noise(board_pos.xy * vec2(2.0, 2.6)) * 1.26;
	float stroke = value_noise(vec2((board_pos.x + board_pos.z * 0.81) * 69.0 + warp, board_pos.y * 2.9));
	float broad = value_noise(vec2((board_pos.x + board_pos.z) * 8.0, board_pos.y * 3.0));
	vec2 xy = fract(vec2((board_pos.x + board_pos.z * 0.92) * 0.61, board_pos.y * 0.82) + vec2(0.5));
	vec3 paint = texture(surface_atlas, vec2(0.008) + xy * 0.484).rgb;
	ALBEDO = mix(COLOR.rgb, paint, 0.34) * (0.80 + broad * 0.20 + stroke * 0.13);
	ROUGHNESS = 0.84;
	SPECULAR = 0.24;
}
