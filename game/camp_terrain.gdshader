shader_type spatial;
render_mode cull_disabled;

varying vec2 terrain_pos;
uniform sampler2D terrain_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;

float hash_position(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise_at(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash_position(i), hash_position(i + vec2(1.0, 0.0)), u.x),
		mix(hash_position(i + vec2(0.0, 1.0)), hash_position(i + 1.0), u.x), u.y);
}

float segment_distance(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	return length(p - a - ab * clamp(dot(p - a, ab) / dot(ab, ab), 0.0, 1.0));
}

vec3 painted_tile(vec2 p, float size, vec2 quadrant) {
	vec2 uv = 1.0 - abs(fract(p / (2.0 * size)) * 2.0 - 1.0);
	return texture(terrain_atlas, quadrant + 0.007 + uv * 0.486).rgb;
}

void vertex() {
	terrain_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 p = terrain_pos;
	float patch = 0.47 * noise_at(p * 1.38) + 0.53 * noise_at(p * 0.28);
	float clearing = length((p - vec2(0.1, 0.1)) * vec2(0.71, 0.93)) - 2.45;
	float path = min(segment_distance(p, vec2(0.2, 0.8), vec2(6.4, 6.2)) - 1.0,
		segment_distance(p, vec2(0.3, 0.6), vec2(-8.0, 4.0)) - 0.84);
	path = min(path, segment_distance(p, vec2(0.2, -0.1), vec2(-4.2, -5.9)) - 0.85);
	path = min(path, segment_distance(p, vec2(0.8, 0.3), vec2(8.0, -1.8)) - 0.8);
	float bare = 1.0 - smoothstep(-0.22, 0.78, min(path, clearing) + (patch - 0.5) * 1.5);
	vec3 grass = painted_tile(p, 4.4, vec2(0.0)) * vec3(0.72, 0.87, 1.04) * (0.89 + patch * 0.14);
	vec3 dirt = painted_tile(p + vec2(1.7, 2.9), 5.5, vec2(0.5, 0.0)) * vec3(0.91, 0.89, 0.94) * (0.96 + patch * 0.10);
	ALBEDO = mix(grass, dirt, bare);
	ROUGHNESS = 1.0;
}
