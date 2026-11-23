// TURBO RUN rain puddles (D-217): a second pass over the road strip (the
// road material's next_pass). Where the world-space puddle mask is on, it
// shows a fake reflection: the screen sampled mirrored about the horizon line,
// rippled by raindrops. UV.x = metres right of the centre line, UV.y = metres
// along the track (same as road.gdshader).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float wet = 0.0;          // 0..1 rain weight
uniform float road_half = 7.5;
uniform float reach = 15.0;       // m from the centre line puddles can lie (road + sidewalk)
uniform bool hd = false;
uniform vec3 tint : source_color = vec3(0.55, 0.6, 0.68);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	VERTEX.y += 0.02;   // just over the road surface
}

void fragment() {
	if (wet <= 0.001 || abs(UV.x) > reach) {
		discard;
	}
	vec2 m = hd ? UV : floor(UV * 4.0) / 4.0;
	// Puddles: blobs of a few metres, more of them as the rain sets in.
	float n = vnoise(m * vec2(0.35, 0.22)) * 0.65 + vnoise(m * vec2(1.1, 0.8)) * 0.35;
	float mask = smoothstep(0.62 - 0.12 * wet, 0.68 - 0.12 * wet, n);
	if (mask <= 0.01) {
		discard;
	}
	// The horizon's height on screen: a far point straight ahead, level.
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 fwd = -INV_VIEW_MATRIX[2].xyz;
	fwd.y = 0.0;
	fwd = normalize(fwd + vec3(0.0001));
	vec4 hp = PROJECTION_MATRIX * VIEW_MATRIX * vec4(cam + fwd * 5000.0, 1.0);
	vec2 hs = hp.xy / hp.w * 0.5 + 0.5;
	float hy = 1.0 - hs.y;   // screen space runs top to bottom
	// Raindrop rings ripple the reflection.
	vec2 cell = floor(m * 1.5);
	float t = fract(TIME * 1.3 + hash(cell) * 7.0);
	float ring = sin((length(fract(m * 1.5) - 0.5) - t * 0.5) * 60.0) * (1.0 - t);
	vec2 ruv = vec2(SCREEN_UV.x + ring * 0.0025, 2.0 * hy - SCREEN_UV.y + ring * 0.003);
	ruv = clamp(ruv, vec2(0.001), vec2(0.999));
	vec3 refl = textureLod(screen_tex, ruv, 0.0).rgb;
	ALBEDO = refl * tint;
	ALPHA = mask * wet * 0.85;
}
