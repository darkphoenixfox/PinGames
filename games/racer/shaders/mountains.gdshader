// TURBO RUN distant mountains (D-089): a ring around the camera with a
// banded pixel silhouette, like a parallax backdrop layer.
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

uniform vec3 far_col : source_color = vec3(0.55, 0.42, 0.7);
uniform vec3 near_col : source_color = vec3(0.32, 0.25, 0.5);
uniform vec3 snow_col : source_color = vec3(0.95, 0.8, 0.85);

float ridge(float u, float f, float seed) {
	float h = 0.0;
	h += sin(u * f + seed) * 0.5;
	h += sin(u * f * 2.3 + seed * 1.7) * 0.25;
	h += sin(u * f * 5.1 + seed * 2.9) * 0.12;
	return h;
}

void fragment() {
	float u = floor(UV.x * 1536.0) / 1536.0 * 6.2831853;
	float y = floor((1.0 - UV.y) * 192.0) / 192.0;
	float back = 0.45 + 0.25 * ridge(u, 7.0, 1.3);
	float front = 0.28 + 0.18 * ridge(u, 13.0, 4.1);
	if (y < front) {
		ALBEDO = mix(near_col * 0.8, near_col, y / max(front, 0.01));
	} else if (y < back) {
		ALBEDO = (back - y < 0.05) ? snow_col : mix(far_col * 0.85, far_col, y / back);
	} else {
		discard;
	}
}
