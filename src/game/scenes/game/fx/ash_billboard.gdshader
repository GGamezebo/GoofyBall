shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform vec4 ash_tint : source_color = vec4(0.75, 0.82, 1.0, 0.35);
uniform float core_softness : hint_range(1.5, 8.0) = 3.8;
uniform float glow_softness : hint_range(0.8, 4.0) = 1.6;
uniform float twinkle_speed : hint_range(0.0, 4.0) = 1.4;

void vertex() {
	vec3 scale = vec3(
		length(MODEL_MATRIX[0].xyz),
		length(MODEL_MATRIX[1].xyz),
		length(MODEL_MATRIX[2].xyz)
	);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(INV_VIEW_MATRIX[0].xyz * scale.x, 0.0),
		vec4(INV_VIEW_MATRIX[1].xyz * scale.y, 0.0),
		vec4(INV_VIEW_MATRIX[2].xyz * scale.z, 0.0),
		MODEL_MATRIX[3]
	);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float d = length(uv);
	float core = pow(clamp(1.0 - d * 1.35, 0.0, 1.0), core_softness);
	float glow = pow(clamp(1.0 - d, 0.0, 1.0), glow_softness) * 0.45;
	float twinkle = 0.72 + 0.28 * sin(TIME * twinkle_speed + UV.x * 17.0 + UV.y * 11.0);
	float alpha = (core + glow) * COLOR.a * ash_tint.a * twinkle;
	ALBEDO = ash_tint.rgb * COLOR.rgb;
	ALPHA = alpha;
}
