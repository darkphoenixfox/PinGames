// Tilt Breaker wormhole (D-052): camera-facing swirling vortex that the
// tetrahedron enemy teleports through. `open` (instance uniform, 0..1) grows and
// collapses the vortex; spiral arms rotate inward, bright violet rim.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 rim_color : source_color = vec4(0.75, 0.35, 1.0, 1.0);
uniform vec4 core_color : source_color = vec4(0.25, 0.6, 1.0, 1.0);
instance uniform float open = 0.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0, 0, 0),
		vec4(0, length(MODEL_MATRIX[1].xyz), 0, 0), vec4(0, 0, 1, 0), vec4(0, 0, 0, 1));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p) / max(open, 0.001);
	float a = atan(p.y, p.x);
	float arms = 0.5 + 0.5 * sin(a * 4.0 + r * 12.0 - TIME * 9.0);
	float disc = 1.0 - smoothstep(0.85, 1.0, r);
	float rim = smoothstep(0.7, 0.92, r) * disc;
	float inner = smoothstep(0.0, 0.5, r);
	vec3 col = mix(core_color.rgb, rim_color.rgb, r) * arms * inner * disc * 1.4 + rim_color.rgb * rim * 2.2;
	float alpha = clamp(disc * (arms * 0.6 + rim), 0.0, 1.0) * step(0.001, open);
	ALBEDO = col * alpha;
	ALPHA = alpha;
}
