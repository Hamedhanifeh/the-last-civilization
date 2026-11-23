shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform float opacity : hint_range(0.0, 1.0) = 0.2;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX[0].xyz *= length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX[1].xyz *= length(MODEL_MATRIX[1].xyz);
}

void fragment() {
	vec2 p = UV - vec2(0.5);
	float lobe = length(p + vec2(-0.05 * sin(p.y * 9.0), 0.0));
	ALBEDO = mix(vec3(0.48, 0.52, 0.54), vec3(0.92, 0.91, 0.82), 1.0 - UV.y);
	ALPHA = (1.0 - smoothstep(0.12, 0.49, lobe)) * opacity;
}
