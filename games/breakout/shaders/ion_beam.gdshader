// Tilt Breaker ion cannon beam (D-072): a flat vertical beam on the playfield
// plane (UV.x across, UV.y along). White-hot core, purple body, crackling
// edges; `fade` (instance uniform, 1 -> 0) dims and narrows it out.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 core_color : source_color = vec4(1.0, 0.95, 1.0, 1.0);
uniform vec4 body_color : source_color = vec4(0.7, 0.3, 1.0, 1.0);
instance uniform float fade = 1.0;

void fragment() {
	float x = abs(UV.x * 2.0 - 1.0);
	float width = mix(0.15, 1.0, fade);
	float d = x / width;
	float wobble = 0.85 + 0.15 * sin(UV.y * 80.0 - TIME * 60.0);
	float core = smoothstep(0.35, 0.0, d);
	float body = smoothstep(1.0, 0.2, d) * wobble;
	float crackle = step(0.97, fract(sin(floor(UV.y * 60.0) * 91.7 + floor(TIME * 30.0)) * 4375.5)) * smoothstep(1.2, 0.6, d);
	vec3 col = core_color.rgb * core * 2.5 + body_color.rgb * body * 1.8 + body_color.rgb * crackle * 2.0;
	float a = clamp(core + body, 0.0, 1.0) * fade;
	ALBEDO = col * a * 1.6;
	ALPHA = a;
}
