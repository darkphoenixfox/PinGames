// TURBO RUN contact sparks (D-510): each particle is a thin streak along its
// own velocity (the particle's Y axis, CPUParticles3D "align Y"), turned to
// face the camera, white-hot and additive so the scene's glow blooms on it.
// The streak's length follows the particle's scale. It never gets thinner
// than about a pixel, so it survives the 8-BIT / 16-BIT resolutions.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform;

uniform float width = 0.022;    // m
uniform float streak = 0.36;    // m, at scale 1
uniform float energy = 2.6;    // over white (D-513: was 1.6): the glow's threshold is 1
// 8-BIT / 16-BIT (D-512): above 0, a spark is a hard square this many of the
// low-resolution pixels across, on the pixel grid, in three flat colours and
// with no glow.
uniform float pixels = 0.0;

void vertex() {
	vec3 centre = MODEL_MATRIX[3].xyz;
	vec3 axis = MODEL_MATRIX[1].xyz;
	float k = max(length(axis), 0.0001);
	vec3 dir = axis / k;
	vec3 to_cam = CAMERA_POSITION_WORLD - centre;
	float dist = max(length(to_cam), 0.001);
	to_cam /= dist;
	vec3 side = cross(dir, to_cam);
	side = length(side) > 0.001 ? normalize(side) : vec3(1.0, 0.0, 0.0);
	float px = 2.0 * dist / (abs(PROJECTION_MATRIX[1][1]) * VIEWPORT_SIZE.y);   // one pixel, in metres, at that depth
	float w = max(width * k, px * 1.2);
	vec3 world = centre + dir * VERTEX.y * streak * k + side * VERTEX.x * w;
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	NORMAL = (VIEW_MATRIX * vec4(to_cam, 0.0)).xyz;
	// POSITION is always written: once a shader sets it anywhere, the engine
	// no longer fills it in, and a path that left it alone drew nothing.
	POSITION = PROJECTION_MATRIX * vec4(VERTEX, 1.0);
	if (pixels > 0.0) {
		vec4 clip = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(centre, 1.0));
		if (clip.w > 0.0) {
			vec2 at = floor((clip.xy / clip.w * 0.5 + 0.5) * VIEWPORT_SIZE);   // the pixel it is in
			vec2 corner = at + (UV * pixels);
			POSITION = vec4((corner / VIEWPORT_SIZE * 2.0 - 1.0) * clip.w, clip.z, clip.w);
		}
	}
}

void fragment() {
	// Clamped: pow() of a hair below zero is not a number, and the glow
	// smears one such pixel into a white disc.
	float across = clamp(1.0 - abs(UV.x - 0.5) * 2.0, 0.0, 1.0);
	float head = clamp(1.0 - UV.y, 0.0, 1.0);   // 1 at the leading end, 0 at the tail
	ALBEDO = COLOR.rgb * energy;
	ALPHA = COLOR.a * smoothstep(0.0, 0.6, across) * pow(head, 0.8);
	if (pixels > 0.0) {
		ALBEDO = floor(COLOR.rgb * 4.0 + 0.5) / 4.0;   // flat steps of the heat ramp
		ALPHA = step(0.3, COLOR.a);
	}
}
