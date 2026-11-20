// Tilt Breaker ball: plasma attack (D-041). Camera-facing quad with a white-hot
// core, a swirling energy halo and crackling arcs. Additive, unshaded, HDR so
// the glow post-effect blooms it.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 core_color : source_color = vec4(0.9, 0.97, 1.0, 1.0);
uniform vec4 halo_color : source_color = vec4(0.35, 0.55, 1.0, 1.0);
uniform vec4 arc_color : source_color = vec4(0.75, 0.45, 1.0, 1.0);
uniform float intensity = 3.0;

void vertex() {
	// Billboard (keep position, face the camera).
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float halo = pow(clamp(1.0 - r, 0.0, 1.0), 2.2);
	float swirl = 0.5 + 0.5 * sin(a * 5.0 + TIME * 11.0 - r * 9.0) * sin(a * 3.0 - TIME * 7.0 + r * 4.0);
	float arcs = pow(max(0.0, sin(a * 7.0 + TIME * 17.0 + sin(r * 18.0 - TIME * 9.0) * 1.5)), 24.0)
		* smoothstep(0.85, 0.35, r) * smoothstep(0.15, 0.3, r);
	float core = smoothstep(0.42, 0.0, r);
	vec3 col = halo_color.rgb * halo * (0.6 + 0.6 * swirl)
		+ arc_color.rgb * arcs * 1.5
		+ core_color.rgb * core * 2.5;
	ALBEDO = col * intensity;
	ALPHA = clamp(halo + core, 0.0, 1.0);
}
