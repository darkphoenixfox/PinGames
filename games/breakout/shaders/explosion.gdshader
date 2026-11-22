// Tilt Breaker explosion (D-083, revised D-087): a smooth camera-facing fireball
// in the brick's own colour. Normal (not additive) blending so it reads as a
// solid burst over the bricks: white-hot core -> bright `tint` -> deep `tint`,
// a billowing noisy edge, and a dissolve only at the end. `age` runs 0..1.
shader_type spatial;
// Per-object values: instance uniforms, or plain uniforms (one material per
// object) in the Compatibility renderer, where instance uniforms don't arrive
// in WebGL (D-175, core/util/inst_param.gd).
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
#define INST
#else
#define INST instance
#endif
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.3, 0.8, 1.0, 1.0);
INST uniform float age = 0.0;      // 0 = just exploded, 1 = gone
INST uniform float seed = 0.0;

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
	float radius = mix(0.2, 0.8, grow);
	float n = fbm(p * 3.2 - normalize(p + 1e-4) * age * 2.0 + seed);
	float shape = d / radius + (n - 0.5) * 0.5;
	float body = smoothstep(1.0, 0.8, shape);           // fairly crisp edge
	// Heat: hottest in the middle early on, cooling outward and over time.
	float heat = clamp((1.0 - shape) * 1.6 * (1.0 - age * 0.9) + (n - 0.5) * 0.3, 0.0, 1.0);
	vec3 bright = mix(tint.rgb, vec3(1.0), 0.35);
	vec3 deep = tint.rgb * 0.45;
	vec3 col = mix(deep, bright, smoothstep(0.05, 0.45, heat));
	col = mix(col, vec3(1.0, 0.98, 0.92), smoothstep(0.6, 0.95, heat));
	// Solid most of its life; holes open up from the noise as it dies.
	float dissolve = smoothstep(age * 1.25 - 0.15, age * 1.25 + 0.05, n + 0.25 * (1.0 - shape));
	float a = body * mix(1.0, dissolve, smoothstep(0.35, 0.75, age)) * (1.0 - smoothstep(0.85, 1.0, age));
	ALBEDO = col * 1.25;
	ALPHA = clamp(a, 0.0, 1.0);
}
