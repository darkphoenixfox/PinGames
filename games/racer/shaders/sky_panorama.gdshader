// TURBO RUN sky backdrop (D-107): the Qwen-Image pixel-art sunset panorama
// (sun, clouds, stars, purple mountains) wrapped around a tall ring that follows
// the camera. The image covers half the ring and is mirrored for the other half
// (no seam); its centre (the sun) faces the road's start direction (-Z), so the
// sun swings left/right as the road turns, like a classic racer backdrop.
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D sky : source_color, filter_nearest, repeat_disable;
uniform float height = 2356.0;     // ring height (m): keeps the image's aspect
uniform float night = 0.0;         // D-113: 0 day .. 1 night (the sun becomes a pale moon)
// D-190: the lid over the ring. It takes the image's top row at each angle (the
// same colour the ring's top edge shows) and the same night grade, so the
// ring's opening never shows as a lighter circle when the camera looks up.
uniform bool cap = false;
// D-191: 0 = the painting as it is (sunset) .. 1 = clear daylight (stages 1-3).
uniform float day = 0.0;

float lum(vec3 c) {
	return dot(c, vec3(0.3, 0.59, 0.11));
}

// The painting as a clear day: a blue sky graded by height, the clouds (pixels
// that stand out from their row) white, the sun a warm white disc, and the
// mountains blue-grey with their own shading.
vec3 daylight(vec3 c, float u, float v) {
	float l = lum(c);
	vec3 sky_col = mix(vec3(0.12, 0.33, 0.82), vec3(0.6, 0.8, 0.97), smoothstep(0.0, 0.74, v));
	if (v > 0.66 && l < 0.45) {   // mountains: the dark band along the bottom
		return mix(vec3(0.2, 0.3, 0.42), vec3(0.42, 0.52, 0.62), clamp(l * 2.2, 0.0, 1.0));
	}
	if (l > 0.82) {               // the sun
		return vec3(1.0, 0.97, 0.86);
	}
	// The row's average brightness from 8 samples across the image.
	float mean = 0.0;
	for (int i = 0; i < 8; i++) {
		mean += lum(texture(sky, vec2((float(i) + 0.5) / 8.0, v)).rgb);
	}
	mean /= 8.0;
	// A cloud is 2+ pixels wide: single-pixel stars don't count.
	float px = 1.0 / float(textureSize(sky, 0).x);
	float l2 = lum(texture(sky, vec2(clamp(u + px, 0.0, 1.0), v)).rgb);
	float stand = min(abs(l - mean), abs(l2 - mean));
	float cloud = smoothstep(0.06, 0.16, stand) * (1.0 - smoothstep(0.62, 0.74, v));
	vec3 cloud_col = mix(vec3(0.8, 0.86, 0.96), vec3(1.0), clamp((l - mean) * 3.0 + 0.6, 0.0, 1.0));
	// The sun's glow stays a little warm around it.
	float glow = smoothstep(0.66, 0.82, l) * (1.0 - cloud);
	vec3 d = mix(sky_col, cloud_col, cloud);
	return mix(d, vec3(1.0, 0.93, 0.75), glow * 0.6);
}

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float ang = atan(lp.x, lp.z);
	float t = fract((ang - PI) / TAU + 0.25) * 2.0;
	float u = t < 1.0 ? t : 2.0 - t;
	float v = cap ? 0.0 : clamp(1.0 - (lp.y + height * 0.5) / height, 0.0, 1.0);
	vec3 c = texture(sky, vec2(u, v)).rgb;
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	// Night: keep the clouds' shapes as deep blues; the brightest pixels (the
	// sun and its glow) turn into a pale moon.
	vec3 n = vec3(0.06, 0.07, 0.2) + vec3(0.1, 0.12, 0.3) * l;
	if (l > 0.82) {
		n = vec3(0.85, 0.88, 1.0) * (l * 0.95);
	}
	vec3 base = c;
	if (day > 0.001) {
		base = mix(c, daylight(c, u, v), day);
	}
	ALBEDO = mix(base, n, night);
}
