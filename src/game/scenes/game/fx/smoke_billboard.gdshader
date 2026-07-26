shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform vec4 smoke_tint : source_color = vec4(0.22, 0.32, 0.55, 0.11);
uniform float softness : hint_range(1.0, 4.0) = 2.4;
uniform float noise_strength : hint_range(0.0, 1.0) = 0.35;
uniform float drift_speed : hint_range(0.0, 1.0) = 0.08;

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
	float radial = clamp(1.0 - length(uv), 0.0, 1.0);
	float mask = pow(radial, softness);

	vec2 drift = UV + vec2(TIME * drift_speed * 0.35, -TIME * drift_speed);
	float n = sin(drift.x * 9.0 + drift.y * 5.0) * cos(drift.y * 7.0 - TIME * 0.11);
	n = n * 0.5 + 0.5;
	mask *= mix(1.0 - noise_strength, 1.0, n);

	float alpha = mask * COLOR.a * smoke_tint.a;
	ALBEDO = smoke_tint.rgb * COLOR.rgb;
	ALPHA = alpha;
}
