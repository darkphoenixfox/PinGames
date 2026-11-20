// Renders a low-res DMD frame as round dots (simulated LED matrix). D-026:
// full-colour RGB DMD — every dot shows exactly one colour, the colour of its source
// pixel. `mono` switches to a classic single-colour plasma look (tint * brightness).
shader_type canvas_item;

uniform vec2 dots = vec2(128.0, 32.0);
uniform bool mono = false;
uniform vec4 tint : source_color = vec4(1.0, 0.45, 0.1, 1.0);
uniform float dot_radius = 0.42;
uniform vec4 off_color : source_color = vec4(0.06, 0.06, 0.06, 1.0);

void fragment() {
	vec2 cell = UV * dots;
	vec2 f = fract(cell) - 0.5;
	vec2 center_uv = (floor(cell) + 0.5) / dots;
	vec3 src = texture(TEXTURE, center_uv).rgb;
	float lum = max(src.r, max(src.g, src.b));
	vec3 lit = mono ? tint.rgb * lum : src;
	// Unlit LEDs stay faintly visible, like a real panel.
	vec3 col = lum < 0.02 ? off_color.rgb : max(lit, off_color.rgb);
	float mask = 1.0 - smoothstep(dot_radius - 0.06, dot_radius, length(f));
	COLOR = vec4(col * mask, 1.0);
}
