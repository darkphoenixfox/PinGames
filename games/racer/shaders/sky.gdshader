// TURBO RUN sky (D-193): procedural and world-fixed, one sun. The script
// (games/racer/sky.gd) moves the sun and moon with the race's time of day and
// sets the palette from the sun's elevation; this draws the gradient, the glow
// towards the sun, the sun and moon discs, stars, clouds lit by the sun's
// colour, two mountain ridges and, below the horizon, haze in the fog colour
// (so hill crests never show an edge). The race's pixel pass (D-107) turns it
// into 16-bit pixels.
shader_type sky;

uniform vec3 sun_dir = vec3(0.0, 0.3, -0.95);   // towards the sun
uniform vec3 moon_dir = vec3(0.0, 0.5, 0.86);   // towards the moon
uniform vec3 zenith : source_color = vec3(0.12, 0.33, 0.8);
uniform vec3 horizon : source_color = vec3(0.62, 0.8, 0.96);
uniform vec3 glow : source_color = vec3(0.85, 0.9, 1.0);   // horizon glow towards the sun
uniform float glow_strength = 0.3;
uniform vec3 sun_col : source_color = vec3(1.0, 0.98, 0.9);
uniform float sun_size = 0.045;                            // disc radius (rad)
uniform vec3 cloud_lit : source_color = vec3(1.0);
uniform vec3 cloud_shade : source_color = vec3(0.72, 0.78, 0.88);
uniform float cloud_cover = 0.56;                          // higher = fewer clouds
uniform vec3 ridge_far : source_color = vec3(0.52, 0.62, 0.74);
uniform vec3 ridge_near : source_color = vec3(0.32, 0.42, 0.48);
uniform vec3 ground : source_color = vec3(0.66, 0.78, 0.92);  // = the fog colour
uniform float stars = 0.0;                                 // 0..1 visibility
uniform float moon = 0.0;                                  // 0..1 visibility

// Sine-free hash: sin() of large numbers loses precision on GPUs and showed
// as blocky square cloud edges.
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

// A mountain ridge's height (as a sine of elevation) at an azimuth: noise on a
// circle, so it joins up all the way round with no seam.
float ridge(float az, float seed, float scale, float lo, float hi) {
	vec2 p = vec2(cos(az), sin(az)) * scale + vec2(seed, seed * 1.7);
	return lo + (hi - lo) * fbm(p);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float el = d.y;
	float az = atan(d.x, -d.z);
	// Gradient: horizon colour low down, zenith colour overhead.
	vec3 col = mix(horizon, zenith, pow(clamp(el, 0.0, 1.0), 0.45));
	// Glow towards the sun, strongest at the horizon.
	vec2 flat_d = normalize(vec2(d.x, d.z) + vec2(1e-5));
	vec2 flat_s = normalize(vec2(sun_dir.x, sun_dir.z) + vec2(1e-5));
	float toward = max(dot(flat_d, flat_s), 0.0);
	col = mix(col, glow, pow(toward, 4.0) * exp(-max(el, 0.0) * 5.0) * glow_strength);
	// Stars (night): a sparse grid of points that twinkle.
	if (stars > 0.0 && el > 0.02) {
		vec2 cell = floor(vec2(az * 160.0, el * 160.0));
		float h = hash(cell);
		if (h > 0.994) {
			col += vec3(0.9, 0.92, 1.0) * stars * (0.55 + 0.45 * sin(TIME * 2.5 + h * 60.0));
		}
	}
	// Moon: a pale disc with a darker sea on it.
	float cm = dot(d, moon_dir);
	if (moon > 0.0 && cm > cos(0.035)) {
		float sea = step(0.6, fbm(d.xz * 220.0));
		col = mix(col, mix(vec3(0.9, 0.92, 1.0), vec3(0.7, 0.74, 0.85), sea), moon);
	}
	// Sun: a hard disc (pixel art) with a soft halo.
	float cs = dot(d, sun_dir);
	col += sun_col * pow(max(cs, 0.0), 300.0) * 0.6;
	if (cs > cos(sun_size)) {
		col = sun_col;
	}
	// Clouds on a flat layer overhead, drifting; thinning towards the horizon.
	if (el > 0.0) {
		// A flatter projection (less stretching at the horizon) and puffier noise.
		vec2 p = d.xz / (el + 0.3) * 0.9 + vec2(TIME * 0.004, TIME * 0.0015);
		float c = fbm(p * 3.2);
		float cover = smoothstep(cloud_cover, cloud_cover + 0.07, c) * smoothstep(0.02, 0.14, el);
		float lit = clamp(0.5 + 0.5 * dot(d, sun_dir), 0.0, 1.0);
		vec3 cc = mix(cloud_shade, cloud_lit, clamp((c - cloud_cover) * 4.0 + lit * 0.4, 0.0, 1.0));
		col = mix(col, cc, cover * 0.92);
	}
	// Mountains: a hazy far range and a darker near one along the horizon.
	float far_h = ridge(az, 3.1, 2.2, 0.012, 0.075);
	float near_h = ridge(az, 7.7, 3.6, 0.004, 0.045);
	if (el < far_h) {
		col = mix(ridge_far, horizon, 0.25 * clamp(1.0 - (far_h - el) / 0.05, 0.0, 1.0));
	}
	if (el < near_h) {
		col = ridge_near;
	}
	// Below the horizon: haze in the fog colour (hill crests look over it).
	if (el < 0.0) {
		col = mix(ridge_near, ground, smoothstep(0.0, 0.04, -el));
	}
	COLOR = col;
}
