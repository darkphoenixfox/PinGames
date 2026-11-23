// TURBO RUN cars (D-089, D-091): the car's 256 px texture sampled nearest (16-bit
// look); traffic cars recolour the paint with a per-instance hue rotation.
// Cel shading: the sun light falls in 3 flat bands with one hard highlight
// (toon = false restores smooth lighting for comparison, --rc-no-toon).
shader_type spatial;
// Per-object values: instance uniforms, or plain uniforms (one material per
// object) in the Compatibility renderer, where instance uniforms don't arrive
// in WebGL (D-175, core/util/inst_param.gd).
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
#define INST
#else
#define INST instance
#endif

uniform sampler2D tex : source_color, filter_nearest;
// D-195 HD graphics: the model's original high-res texture, smoothly filtered.
uniform sampler2D tex_hd : source_color, filter_linear_mipmap_anisotropic;
uniform bool hd = false;
uniform bool toon = true;
INST uniform float hue = 0.0;
INST uniform float bright = 1.0;
// D-120: the model's own lamps light up (no billboards). lamps = night lights
// 0..1, brake = brake lights 0..1. Lamp areas are boxes in model space (the red
// car: nose +Z, rear -Z, origin on the ground); only bright-ish texels glow so
// the bodywork around the lenses stays dark.
INST uniform float lamps = 0.0;
INST uniform float brake = 0.0;
// D-143: turning wheels. The wheels are part of the body mesh, so their rims
// get animated spoke streaks around each axle that blur into a solid disc as
// the car speeds up. spin = 0 turns the effect off (traffic models differ).
// D-153: tunnel lamp passing overhead, 0..1 (fakes the orange sodium light).
INST uniform float overhead = 0.0;
INST uniform float spin = 0.0;       // 1 = hero car
INST uniform float wheel_phase = 0.0;
INST uniform float wheel_blur = 0.0; // 0 still .. 1 fast
uniform vec3 tail_min = vec3(0.2, 0.7, -9.0);
uniform vec3 tail_max = vec3(0.7, 0.9, -1.95);
uniform vec3 head_min = vec3(0.45, 0.55, 1.85);
uniform vec3 head_max = vec3(0.82, 0.8, 9.0);
// D-144: per model. Non-red cars light only the red texels in the tail box.
uniform bool tail_red_only = false;

varying vec3 mp;

// D-250: turning wheels. Each wheel's rim (centre z, y and radius, model
// space, measured per axle) gets a rim picture drawn over it, turned by
// wheel_phase; the model's own tyre stays. Only outward-facing surfaces at the
// sides take it.
uniform vec3 wheels[6];
uniform int wheel_n = 0;
uniform sampler2D rim_tex : source_color, filter_linear_mipmap;
varying vec3 mn;

void vertex() {
	mp = VERTEX;
	mn = NORMAL;
}

// D-198: a box with soft edges (fading over `f` metres), so lamp light has
// no hard rectangle round it.
float soft_box(vec3 p, vec3 lo, vec3 hi, float f) {
	vec3 q = vec3(abs(p.x), p.y, p.z);
	vec3 a = smoothstep(lo - f, lo + f, q);
	vec3 b = 1.0 - smoothstep(hi - f, hi + f, q);
	return a.x * a.y * a.z * b.x * b.y * b.z;
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
	vec3 c = hd ? texture(tex_hd, UV).rgb : texture(tex, UV).rgb;
	ALBEDO = hue_rotate(c, hue * 6.2831853) * bright;
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	if (spin > 0.5 && wheel_n > 0 && abs(mp.x) > 0.5 && mn.x * sign(mp.x) > 0.3) {
		for (int i = 0; i < 6; i++) {
			if (i >= wheel_n) {
				break;
			}
			vec2 d = vec2(mp.z - wheels[i].x, mp.y - wheels[i].y);
			float rr = wheels[i].z;
			if (dot(d, d) < rr * rr) {
				// Seen from its own side; rolling forward turns the top to +Z.
				float ca = cos(wheel_phase);
				float sa = sin(wheel_phase);
				vec2 q = vec2(d.x * ca - d.y * sa, d.x * sa + d.y * ca);
				vec2 uv = vec2(-q.x * sign(mp.x), -q.y) / (2.0 * rr) + 0.5;
				vec4 rim = texture(rim_tex, uv);
				ALBEDO = mix(ALBEDO, rim.rgb, rim.a);
				break;
			}
		}
	}
	float redness = (c.r > 0.3 && c.r > c.g * 1.8 && c.r > c.b * 1.8) ? 1.0 : 0.0;
	// Tail lamps (D-198): a dim running glow at night, full brightness braking
	// (with a hot core), instead of one flat level.
	float tail_mask = soft_box(mp, tail_min, tail_max, 0.06) * (tail_red_only ? redness : 1.0);
	float tail = tail_mask * max(lamps * 0.3, brake);
	float head = soft_box(mp, head_min, head_max, 0.05) * lamps;
	float top_k = clamp((mp.y - 0.3) / 0.9, 0.0, 1.0);   // the roof catches it most
	EMISSION = ALBEDO * vec3(1.0, 0.62, 0.25) * overhead * (0.35 + 0.9 * top_k)
		+ tail * vec3(1.0, 0.1, 0.06) * (0.4 + lum * 2.2) * 1.8
		+ tail_mask * brake * vec3(1.0, 0.5, 0.4) * lum * 0.9
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
