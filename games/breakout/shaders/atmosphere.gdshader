// Tilt Breaker backdrop planet haze (D-043): a slightly larger additive shell that
// glows only at its silhouette, giving the planet a soft atmospheric halo above
// the horizon line.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 haze_color : source_color = vec4(0.3, 0.6, 1.0, 1.0);
uniform float intensity = 1.6;

void fragment() {
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float a = pow(rim, 9.0);
	ALBEDO = haze_color.rgb * a * intensity;
	ALPHA = a;
}
