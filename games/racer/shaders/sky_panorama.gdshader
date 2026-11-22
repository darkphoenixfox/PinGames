// TURBO RUN sky backdrop (D-107): the Qwen-Image pixel-art sunset panorama
// (sun, clouds, stars, purple mountains) wrapped around a tall ring that follows
// the camera. The image covers half the ring and is mirrored for the other half
// (no seam); its centre (the sun) faces the road's start direction (-Z), so the
// sun swings left/right as the road turns, like a classic racer backdrop.
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D sky : source_color, filter_nearest, repeat_disable;
uniform float height = 2356.0;     // ring height (m): keeps the image's aspect

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float ang = atan(lp.x, lp.z);
	float t = fract((ang - PI) / TAU + 0.25) * 2.0;
	float u = t < 1.0 ? t : 2.0 - t;
	float v = clamp(1.0 - (lp.y + height * 0.5) / height, 0.0, 1.0);
	ALBEDO = texture(sky, vec2(u, v)).rgb;
}
