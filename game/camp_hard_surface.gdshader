shader_type spatial;

uniform sampler2D terrain_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec2 quadrant = vec2(0.5, 0.5);
uniform float tile_size = 4.5;
uniform float blend_amount = 0.74;
varying vec3 position_world;
varying vec3 normal_world;

void vertex() {
	position_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normal_world = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

vec2 tile_coord(vec2 p) {
	return quadrant + 0.007 + (1.0 - abs(fract(p / (2.0 * tile_size)) * 2.0 - 1.0)) * 0.486;
}

void fragment() {
	vec3 weight = pow(abs(normalize(normal_world)), vec3(4.0));
	weight /= max(weight.x + weight.y + weight.z, 0.01);
	vec3 tint = texture(terrain_atlas, tile_coord(position_world.yz)).rgb * weight.x;
	tint += texture(terrain_atlas, tile_coord(position_world.xz)).rgb * weight.y;
	tint += texture(terrain_atlas, tile_coord(position_world.xy)).rgb * weight.z;
	ALBEDO = mix(COLOR.rgb, tint * mix(vec3(1.0), COLOR.rgb, 0.27), blend_amount);
	ROUGHNESS = 0.95;
	SPECULAR = 0.18;
}
