// Tilt Breaker brick explosion (D-046): a camera-facing quad drawn as a chunky
// pixel-art blast. UVs are quantised to a `pixels` grid; a stepped palette
// (white core -> yellow -> orange -> brick colour) expands as a ragged ring and
// dissolves with ordered dithering as `age` (0..1) runs out.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform float pixels = 14.0;
uniform vec4 tint : source_color = vec4(0.3, 0.8, 1.0, 1.0);
instance uniform float age = 0.0;      // 0 = just exploded, 1 = gone
instance uniform float seed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.0) * 43758.5453);
}

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0, 0, 0),
		vec4(0, length(MODEL_MATRIX[1].xyz), 0, 0), vec4(0, 0, 1, 0), vec4(0, 0, 0, 1));
}

void fragment() {
	vec2 cell = floor(UV * pixels);
	vec2 p = (cell + 0.5) / pixels * 2.0 - 1.0;
	float r = length(p) + (hash(cell) - 0.5) * 0.25;   // ragged edge
	float radius = mix(0.25, 1.0, sqrt(age));
	float inner = radius * mix(0.0, 0.85, age);          // hollows out over time
	float body = step(r, radius) * step(inner, r);
	// Stepped palette by distance through the blast
	float k = clamp((r - inner) / max(radius - inner, 0.001), 0.0, 1.0);
	vec3 col = k < 0.25 ? vec3(1.0) : (k < 0.5 ? vec3(1.0, 0.9, 0.4) : (k < 0.75 ? vec3(1.0, 0.5, 0.15) : tint.rgb));
	// Ordered-dither dissolve
	float bayer = mod(cell.x + cell.y * 2.0, 4.0) / 4.0 + mod(cell.x * 2.0 + cell.y, 2.0) * 0.125;
	float alive = step(bayer, 1.0 - age * 1.1);
	float a = body * alive;
	ALBEDO = col * a * 1.15;  // modest HDR: enough glow, pixels stay crisp
	ALPHA = a;
}
