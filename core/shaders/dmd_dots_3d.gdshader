// DMD dot matrix on a 3D panel (VR cabinet, D-164): the same look as
// dmd_dots.gdshader (D-026) but as an unshaded spatial material.
shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D frame : source_color, filter_nearest;   // nearest: one colour per dot
uniform vec2 dots = vec2(128.0, 32.0);
uniform float dot_radius = 0.42;
uniform vec3 off_color : source_color = vec3(0.06, 0.06, 0.06);

void fragment() {
	vec2 cell = UV * dots;
	vec2 f = fract(cell) - 0.5;
	vec2 center_uv = (floor(cell) + 0.5) / dots;
	vec3 src = texture(frame, center_uv).rgb;
	float lum = max(src.r, max(src.g, src.b));
	vec3 col = lum < 0.02 ? off_color : max(src, off_color);
	// Anti-aliased dots (D-172): the edge softens by the screen-space size of a
	// dot, and once dots are too small to resolve (far away / headset pixels)
	// they blend into their average brightness instead of a shimmering grid.
	float px = max(fwidth(cell.x), fwidth(cell.y));          // dots per pixel
	float d = length(f);
	float edge = max(0.06, px * 0.75);
	float mask = 1.0 - smoothstep(dot_radius - edge, dot_radius + edge * 0.5, d);
	float coverage = 3.14159 * dot_radius * dot_radius;
	mask = mix(mask, coverage, smoothstep(0.25, 0.6, px));
	ALBEDO = col * mask;
}
