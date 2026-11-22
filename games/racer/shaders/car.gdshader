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
uniform vec3 tail_min = vec3(0.2, 0.7, -9.0);
uniform vec3 tail_max = vec3(0.7, 0.9, -1.95);
uniform vec3 head_min = vec3(0.45, 0.55, 1.85);
uniform vec3 head_max = vec3(0.82, 0.8, 9.0);

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
	float tail = in_box(mp, tail_min, tail_max) * clamp(lamps * 0.7 + brake, 0.0, 1.5);
	float head = in_box(mp, head_min, head_max) * lamps;
	EMISSION = tail * vec3(1.0, 0.12, 0.08) * (0.6 + lum * 2.0) * 1.6
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
