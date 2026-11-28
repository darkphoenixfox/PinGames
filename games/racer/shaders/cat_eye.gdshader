// TURBO RUN cat's eyes (D-521): reflective studs along the road's edges. Each
// is a small disc that always faces the camera and never gets smaller than
// `min_px` pixels, so a row of them reads as points of light far down the
// road. A stud only shines in the light of a car: `cars` are the lit spots on
// the road (xyz, world space) and their reach (w, metres; 0 = unused).
// `level` is how dark it is (0 by day: nothing shows).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

const int CARS = 12;
uniform vec4 cars[CARS];
// D-533: a car's lights shine forwards only: `fronts` is each car's bonnet
// (xy = its x and z in the world) and the way it faces (zw). A stud behind
// that line is not lit by that car.
uniform vec4 fronts[CARS];
uniform float level = 0.0;
uniform float size = 0.085;    // m, the disc's radius
uniform float min_px = 1.2;    // its radius on screen, at least
uniform float energy = 2.4;    // over white: the glow's threshold is 1
uniform float pixels = 0.0;    // 8-BIT / 16-BIT: above 0, a hard square with no glow
varying float lit;
varying vec3 tint;   // D-528: red on the edges, white on the centre line

void vertex() {
	vec3 centre = MODEL_MATRIX[3].xyz;
	float g = 0.0;
	for (int i = 0; i < CARS; i++) {
		if (cars[i].w > 0.0) {
			float d = distance(centre, cars[i].xyz);
			float ahead = dot(centre.xz - fronts[i].xy, fronts[i].zw);
			g = max(g, (1.0 - smoothstep(cars[i].w * 0.4, cars[i].w, d)) * step(0.0, ahead));
		}
	}
	lit = g * level;
	tint = COLOR.rgb;
	vec4 clip = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(centre, 1.0));
	if (lit <= 0.01 || clip.w <= 0.0) {
		POSITION = vec4(2.0, 2.0, 2.0, 1.0);   // off screen
	} else {
		vec2 half_size = abs(vec2(PROJECTION_MATRIX[0][0], PROJECTION_MATRIX[1][1])) * size / clip.w;
		half_size = max(half_size, vec2(min_px) / VIEWPORT_SIZE);
		POSITION = vec4(clip.xy + VERTEX.xy * 2.0 * half_size * clip.w, clip.z, clip.w);
	}
}

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	vec3 colour = tint;
	if (pixels > 0.0) {
		ALBEDO = colour * step(0.35, lit);
		ALPHA = 1.0;
	} else {
		ALBEDO = colour * energy * lit;
		ALPHA = 1.0 - smoothstep(0.45, 1.0, r);
	}
}
