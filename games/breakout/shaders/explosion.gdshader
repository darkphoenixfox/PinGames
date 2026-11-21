// Tilt Breaker explosion (D-083, replaces the pixel blast of D-046): a smooth
// camera-facing fireball. A noisy soft-edged core expands with an ease-out,
// its heat runs white -> yellow -> orange -> `tint` -> out, and a faint
// shockwave ring travels just ahead of it. `age` (instance uniform) runs 0..1.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.3, 0.8, 1.0, 1.0);
instance uniform float age = 0.0;      // 0 = just exploded, 1 = gone
instance uniform float seed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.0) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.1 + 3.7) * 0.3 + vnoise(p * 4.3 + 7.1) * 0.15;
}

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0, 0, 0),
		vec4(0, length(MODEL_MATRIX[1].xyz), 0, 0), vec4(0, 0, 1, 0), vec4(0, 0, 0, 1));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float grow = 1.0 - pow(1.0 - age, 3.0);            // fast burst, slow finish
	float radius = mix(0.18, 0.85, grow);
	// Billowing edge: noise drifts outwards as it grows.
	float n = fbm(p * 3.2 - normalize(p + 1e-4) * age * 2.0 + seed);
	float shape = d / radius + (n - 0.5) * 0.55;
	float body = smoothstep(1.0, 0.55, shape);
	// Heat falls off towards the edge and over time; the core cools first.
	float heat = clamp((1.0 - shape) * 1.4 * (1.0 - age) + (n - 0.5) * 0.25, 0.0, 1.0);
	vec3 col = mix(tint.rgb * 0.8, vec3(1.0, 0.45, 0.12), smoothstep(0.1, 0.4, heat));
	col = mix(col, vec3(1.0, 0.85, 0.35), smoothstep(0.4, 0.7, heat));
	col = mix(col, vec3(1.0, 0.98, 0.9), smoothstep(0.7, 0.95, heat));
	float fade = pow(1.0 - age, 1.6);
	// Shockwave ring ahead of the fireball
	float ring_r = mix(0.25, 1.0, grow);
	float ring = exp(-pow((d - ring_r) / 0.05, 2.0)) * pow(1.0 - age, 2.0) * 0.5;
	vec3 c = col * body * fade * 1.3 + mix(vec3(1.0), tint.rgb, 0.5) * ring;
	c *= smoothstep(1.0, 0.9, d);                        // never touch the quad edge
	ALBEDO = c;
	ALPHA = clamp(max(body * fade, ring), 0.0, 1.0);
}
