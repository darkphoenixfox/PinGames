// Tilt Breaker ship shield (D-041): flat energy band in front of the ship that
// flashes when it deflects the plasma. A hex-ish ripple spreads from the hit
// point (hit_x in -1..1 across the shield). `strength` fades 1 -> 0 per hit.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 shield_color : source_color = vec4(0.3, 0.75, 1.0, 1.0);
uniform float strength = 0.0;
uniform float hit_x = 0.0;
uniform float age = 0.0;  // seconds since the hit

void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, UV.y);           // x across, y 0 (front) .. 1 (ship)
	float band = smoothstep(0.0, 0.35, UV.y) * smoothstep(1.0, 0.55, UV.y);
	float edge = smoothstep(1.0, 0.85, abs(p.x));
	float d = abs(p.x - hit_x);
	float ripple = pow(max(0.0, 1.0 - abs(d - age * 6.0) * 4.0), 2.0);
	float core = exp(-d * d * 18.0);
	// Cheap hex/scanline texture
	float hex = 0.6 + 0.4 * step(0.5, fract(UV.x * 26.0 + step(0.5, fract(UV.y * 6.0)) * 0.5)) * step(0.15, fract(UV.y * 6.0));
	float a = band * edge * strength * (0.35 * hex + 1.2 * core + 0.9 * ripple);
	ALBEDO = shield_color.rgb * a * 2.5;
	ALPHA = clamp(a, 0.0, 1.0);
}
