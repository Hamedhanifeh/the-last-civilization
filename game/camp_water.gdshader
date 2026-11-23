shader_type spatial;
render_mode cull_disabled;

uniform vec3 deep : source_color = vec3(0.06, 0.35, 0.51);
uniform vec3 foam : source_color = vec3(0.30, 0.79, 0.85);
uniform float speed = 1.0;

void fragment() {
	float flow = sin(UV.y * 37.0 - TIME * speed * 3.6 + sin(UV.x * 14.0 + TIME));
	float ripple = cos(UV.x * 27.0 + UV.y * 18.0 - TIME * speed * 2.5);
	float crest = smoothstep(0.56, 0.98, flow * 0.56 + ripple * 0.44);
	ALBEDO = mix(deep, foam, 0.16 + crest * 0.71);
	EMISSION = foam * crest * 0.13;
	ROUGHNESS = 0.29;
	SPECULAR = 0.74;
}
