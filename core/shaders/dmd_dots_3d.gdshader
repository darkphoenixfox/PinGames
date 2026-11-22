// DMD dot matrix on a 3D panel (VR cabinet, D-164): the same look as
// dmd_dots.gdshader (D-026) but as an unshaded spatial material.
shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D frame : source_color, filter_nearest;
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
	float mask = 1.0 - smoothstep(dot_radius - 0.06, dot_radius, length(f));
	ALBEDO = col * mask;
}
