// TURBO RUN cel outline (D-091): inverted hull. Front faces are culled so only
// the shell behind the model shows, as a dark rim. The push grows with distance
// so the line stays about the same thickness on screen (clamped, so far props
// don't turn into blobs).
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

uniform float width = 0.055;      // metres of push at 10 m from the camera
uniform vec3 ink : source_color = vec3(0.06, 0.03, 0.1);

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float d = length(wp - CAMERA_POSITION_WORLD);
	float scale = length(MODEL_MATRIX[0].xyz);
	VERTEX += NORMAL * width * clamp(d / 10.0, 0.7, 3.0) / max(scale, 0.01);
}

void fragment() {
	ALBEDO = ink;
}
