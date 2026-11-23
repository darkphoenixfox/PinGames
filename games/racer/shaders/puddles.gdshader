// TURBO RUN rain puddles (D-217; screen-space reflections D-225): a second
// pass over the road strip (the road material's next_pass). Where the
// world-space puddle mask is on, the view ray is reflected off the water and
// marched through the scene in view space against the depth buffer, so cars
// driving over, street lamps, signs and buildings show in the right place;
// where it finds nothing it falls back to the sky (the screen mirrored about
// the horizon). Raindrop rings ripple it. UV.x = metres right of the centre
// line, UV.y = metres along the track (as road.gdshader).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform float wet = 0.0;          // 0..1 rain weight
uniform float road_half = 7.5;
uniform float reach = 15.0;       // m from the centre line puddles can lie (road + sidewalk)
uniform bool hd = false;
uniform vec3 tint : source_color = vec3(0.62, 0.66, 0.74);
uniform int steps = 24;

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

// View-space point -> screen UV, oriented like SCREEN_UV (`flip` found per
// pixel, so it holds whatever the renderer's clip-space convention).
vec2 to_screen(vec3 p, mat4 proj, bool flip) {
	vec4 c = proj * vec4(p, 1.0);
	vec2 uv = c.xy / c.w * 0.5 + 0.5;
	return flip ? vec2(uv.x, 1.0 - uv.y) : uv;
}

// View-space depth (negative z) of the scene at a screen UV.
float scene_z(vec2 uv, mat4 inv_proj, bool flip) {
	float d = textureLod(depth_tex, uv, 0.0).r;
	vec2 ndc_xy = (flip ? vec2(uv.x, 1.0 - uv.y) : uv) * 2.0 - 1.0;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec4 v = inv_proj * vec4(ndc_xy, d * 2.0 - 1.0, 1.0);
#else
	vec4 v = inv_proj * vec4(ndc_xy, d, 1.0);
#endif
	return v.z / v.w;
}

void fragment() {
	if (wet <= 0.001 || abs(UV.x) > reach) {
		discard;
	}
	vec2 m = hd ? UV : floor(UV * 4.0) / 4.0;
	// Puddles: blobs of a few metres, more of them as the rain sets in.
	float n = vnoise(m * vec2(0.35, 0.22)) * 0.65 + vnoise(m * vec2(1.1, 0.8)) * 0.35;
	float mask = smoothstep(0.6 - 0.14 * wet, 0.66 - 0.14 * wet, n);
	if (mask <= 0.01) {
		discard;
	}
	// Which way up the screen is: compare this pixel's own projection.
	vec2 self_uv = (PROJECTION_MATRIX * vec4(VERTEX, 1.0)).xy / (PROJECTION_MATRIX * vec4(VERTEX, 1.0)).w * 0.5 + 0.5;
	bool flip = abs(self_uv.y - SCREEN_UV.y) > abs(1.0 - self_uv.y - SCREEN_UV.y);
	// Raindrop rings tilt the water's normal a little.
	vec2 cell = floor(m * 1.5);
	float t = fract(TIME * 1.3 + hash(cell) * 7.0);
	vec2 rc = fract(m * 1.5) - 0.5;
	float ring = sin((length(rc) - t * 0.5) * 60.0) * (1.0 - t);
	vec3 n_world = normalize(vec3(rc.x * ring * 0.025, 1.0, rc.y * ring * 0.025));
	vec3 nv = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
	vec3 p0 = VERTEX;
	vec3 rd = normalize(reflect(normalize(p0), nv));
	// March out from the water, longer steps further away; then refine.
	vec3 hit_col = vec3(0.0);
	float found = 0.0;
	float dist = 0.25;
	vec3 prev = p0;
	for (int i = 0; i < steps; i++) {
		vec3 q = p0 + rd * dist;
		vec2 uv = to_screen(q, PROJECTION_MATRIX, flip);
		if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0 || q.z > -0.05) {
			break;
		}
		float sz = scene_z(uv, INV_PROJECTION_MATRIX, flip);
		float behind = sz - q.z;   // > 0: q is behind what the screen shows
		if (behind > 0.0 && behind < 0.6 + dist * 0.08) {
			// Refine between the last two points.
			vec3 a = prev;
			vec3 b = q;
			for (int k = 0; k < 5; k++) {
				vec3 mid = (a + b) * 0.5;
				vec2 muv = to_screen(mid, PROJECTION_MATRIX, flip);
				if (scene_z(muv, INV_PROJECTION_MATRIX, flip) - mid.z > 0.0) {
					b = mid;
				} else {
					a = mid;
				}
			}
			vec2 huv = to_screen(b, PROJECTION_MATRIX, flip);
			// Fade out towards the screen's edges, where the data runs out.
			vec2 e = smoothstep(vec2(0.0), vec2(0.08), huv) * smoothstep(vec2(0.0), vec2(0.08), 1.0 - huv);
			found = e.x * e.y;
			hit_col = textureLod(screen_tex, huv, 0.0).rgb;
			break;
		}
		prev = q;
		dist *= 1.32;
	}
	// Nothing hit: the sky, mirrored about the horizon.
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 fwd = -INV_VIEW_MATRIX[2].xyz;
	fwd.y = 0.0;
	fwd = normalize(fwd + vec3(0.0001));
	vec2 hs = to_screen((VIEW_MATRIX * vec4(cam + fwd * 5000.0, 1.0)).xyz, PROJECTION_MATRIX, flip);
	vec2 suv = clamp(vec2(SCREEN_UV.x + ring * 0.002, 2.0 * hs.y - SCREEN_UV.y), vec2(0.001), vec2(0.999));
	vec3 sky = textureLod(screen_tex, suv, 0.0).rgb;
	ALBEDO = mix(sky, hit_col, found) * tint;
	ALPHA = mask * wet * 0.88;
}
