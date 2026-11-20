// Tilt Breaker energy blast (D-051): a flat, upward-flying energy bolt lying on
// the playfield plane. White-hot spine, cyan body, violet edges, crackling
// flicker, tapering tail (UV.y: 0 = nose, 1 = tail). Additive HDR for bloom.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 core_color : source_color = vec4(0.95, 0.98, 1.0, 1.0);
uniform vec4 body_color : source_color = vec4(0.3, 0.85, 1.0, 1.0);
uniform vec4 edge_color : source_color = vec4(0.7, 0.4, 1.0, 1.0);
uniform float intensity = 2.6;

void fragment() {
	float x = UV.x * 2.0 - 1.0;   // across
	float y = UV.y;               // 0 nose .. 1 tail
	// Lozenge silhouette: round nose, long tapering tail.
	float width = mix(smoothstep(0.0, 0.18, y), 1.0 - smoothstep(0.25, 1.0, y), step(0.18, y)) * 0.9 + 0.1 * (1.0 - y);
	float d = abs(x) / max(width, 0.001);
	float flicker = 0.8 + 0.2 * sin(TIME * 60.0 + y * 40.0);
	float wobble = sin(y * 30.0 - TIME * 45.0) * 0.12;
	float spine = smoothstep(0.35, 0.0, abs(x - wobble * 0.3) / max(width, 0.001));
	float body = smoothstep(1.0, 0.3, d);
	float edge = smoothstep(1.0, 0.75, d) - smoothstep(0.75, 0.4, d);
	vec3 col = core_color.rgb * spine * 1.5 + body_color.rgb * body + edge_color.rgb * edge * 0.8;
	float a = clamp(body + spine, 0.0, 1.0) * (1.0 - smoothstep(0.85, 1.0, y));
	ALBEDO = col * a * intensity * flicker;
	ALPHA = a;
}
