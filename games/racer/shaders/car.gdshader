// TURBO RUN cars (D-089, D-091): the car's 256 px texture sampled nearest (16-bit
// look); traffic cars recolour the paint with a per-instance hue rotation.
// Cel shading: the sun light falls in 3 flat bands with one hard highlight
// (toon = false restores smooth lighting for comparison, --rc-no-toon).
shader_type spatial;

uniform sampler2D tex : source_color, filter_nearest;
uniform bool toon = true;
instance uniform float hue = 0.0;
instance uniform float bright = 1.0;
// D-120: the model's own lamps light up (no billboards). lamps = night lights
// 0..1, brake = brake lights 0..1. Lamp areas are boxes in model space (the red
// car: nose +Z, rear -Z, origin on the ground); only bright-ish texels glow so
// the bodywork around the lenses stays dark.
instance uniform float lamps = 0.0;
instance uniform float brake = 0.0;
// D-143: turning wheels. The wheels are part of the body mesh, so their rims
// get animated spoke streaks around each axle that blur into a solid disc as
// the car speeds up. spin = 0 turns the effect off (traffic models differ).
// D-153: tunnel lamp passing overhead, 0..1 (fakes the orange sodium light).
instance uniform float overhead = 0.0;
instance uniform float spin = 0.0;       // 1 = hero car
instance uniform float wheel_phase = 0.0;
instance uniform float wheel_blur = 0.0; // 0 still .. 1 fast
uniform vec2 axle_yz = vec2(0.33, 1.2);  // axle height, |z| of front/rear axle
uniform float wheel_r = 0.32;
uniform vec3 tail_min = vec3(0.2, 0.7, -9.0);
uniform vec3 tail_max = vec3(0.7, 0.9, -1.95);
uniform vec3 head_min = vec3(0.45, 0.55, 1.85);
uniform vec3 head_max = vec3(0.82, 0.8, 9.0);
// D-144: per model. Non-red cars light only the red texels in the tail box.
uniform bool tail_red_only = false;

varying vec3 mp;

void vertex() {
	mp = VERTEX;
}

float in_box(vec3 p, vec3 lo, vec3 hi) {
	vec3 q = vec3(abs(p.x), p.y, p.z);
	return step(lo.x, q.x) * step(q.x, hi.x) * step(lo.y, q.y) * step(q.y, hi.y) * step(lo.z, q.z) * step(q.z, hi.z);
}

vec3 hue_rotate(vec3 c, float a) {
	const vec3 k = vec3(0.57735);
	float ca = cos(a);
	return c * ca + cross(k, c) * sin(a) + k * dot(k, c) * (1.0 - ca);
}

void fragment() {
	vec3 c = texture(tex, UV).rgb;
	ALBEDO = hue_rotate(c, hue * 6.2831853) * bright;
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	if (spin > 0.5 && abs(mp.x) > 0.7) {
		vec2 d = vec2(mp.z - sign(mp.z) * axle_yz.y, mp.y - axle_yz.x);
		float r = length(d);
		bool not_paint = c.r < c.g * 1.6 + 0.05;   // rims + tyre, not red bodywork
		if (r < wheel_r && not_paint) {
			float a = atan(d.y, d.x);
			float rim = 1.0 - smoothstep(wheel_r * 0.62, wheel_r * 0.78, r);
			float spokes = step(0.0, sin(a * 5.0 + wheel_phase));
			vec3 dark = vec3(0.12);
			vec3 streak = mix(dark, vec3(0.75), spokes);
			vec3 disc = vec3(0.42);
			vec3 w = mix(streak, disc, wheel_blur);
			ALBEDO = mix(ALBEDO, w, rim * 0.85);
		}
	}
	float redness = (c.r > 0.3 && c.r > c.g * 1.8 && c.r > c.b * 1.8) ? 1.0 : 0.0;
	float tail = in_box(mp, tail_min, tail_max) * clamp(lamps * 0.7 + brake, 0.0, 1.5)
		* (tail_red_only ? redness : 1.0);
	float head = in_box(mp, head_min, head_max) * lamps;
	float top_k = clamp((mp.y - 0.3) / 0.9, 0.0, 1.0);   // the roof catches it most
	EMISSION = ALBEDO * vec3(1.0, 0.62, 0.25) * overhead * (0.35 + 0.9 * top_k)
		+ tail * vec3(1.0, 0.12, 0.08) * (0.6 + lum * 2.0) * 1.6
		+ head * vec3(1.0, 0.95, 0.8) * (0.3 + lum * 1.6) * 1.4;
	ROUGHNESS = toon ? 0.8 : 0.35;
	METALLIC = toon ? 0.0 : 0.25;
	SPECULAR = toon ? 0.25 : 0.7;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	if (toon) {
		float band = ndl > 0.45 ? 1.0 : (ndl > 0.0 ? 0.62 : 0.3);
		DIFFUSE_LIGHT += band * ATTENUATION * LIGHT_COLOR / PI;
		vec3 h = normalize(VIEW + LIGHT);
		float hl = step(0.965, dot(NORMAL, h)) * step(0.0, ndl);
		SPECULAR_LIGHT += hl * 0.6 * ATTENUATION * LIGHT_COLOR / PI;
	} else {
		DIFFUSE_LIGHT += clamp(ndl, 0.0, 1.0) * ATTENUATION * LIGHT_COLOR / PI;
		vec3 h = normalize(VIEW + LIGHT);
		SPECULAR_LIGHT += pow(clamp(dot(NORMAL, h), 0.0, 1.0), 40.0) * 0.5 * ATTENUATION * LIGHT_COLOR / PI;
	}
}
