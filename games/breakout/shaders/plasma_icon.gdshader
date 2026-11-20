// Tilt Breaker HUD life icon (D-047): the plasma shot drawn in 2D (same look as
// plasma.gdshader) — white-hot core, swirling blue halo, violet arcs.
// `spent` = 1 draws a dim, empty socket for a used charge.
shader_type canvas_item;

uniform vec4 core_color : source_color = vec4(0.9, 0.97, 1.0, 1.0);
uniform vec4 halo_color : source_color = vec4(0.35, 0.55, 1.0, 1.0);
uniform vec4 arc_color : source_color = vec4(0.75, 0.45, 1.0, 1.0);
uniform float spent = 0.0;
uniform float time_offset = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float t = TIME + time_offset;
	float halo = pow(clamp(1.0 - r, 0.0, 1.0), 1.8);
	float swirl = 0.5 + 0.5 * sin(a * 5.0 + t * 9.0 - r * 9.0) * sin(a * 3.0 - t * 6.0 + r * 4.0);
	float arcs = pow(max(0.0, sin(a * 7.0 + t * 14.0 + sin(r * 18.0 - t * 8.0) * 1.5)), 20.0)
		* smoothstep(0.9, 0.4, r) * smoothstep(0.15, 0.3, r);
	float core = smoothstep(0.45, 0.2, r);
	vec3 col = halo_color.rgb * halo * (0.6 + 0.6 * swirl) + arc_color.rgb * arcs * 1.4 + core_color.rgb * core * 1.6;
	float alpha = clamp(halo * 1.3 + core, 0.0, 1.0);
	// Spent charge: faint ring only
	float ring = smoothstep(0.08, 0.0, abs(r - 0.42)) * 0.35;
	COLOR = mix(vec4(col, alpha), vec4(halo_color.rgb * 0.6, ring), spent);
}
