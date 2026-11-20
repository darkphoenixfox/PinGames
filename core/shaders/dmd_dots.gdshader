// Renders a low-res DMD frame as round glowing dots (simulated dot matrix).
shader_type canvas_item;

uniform vec2 dots = vec2(128.0, 32.0);
uniform vec4 tint : source_color = vec4(1.0, 0.45, 0.1, 1.0);
uniform float dot_radius = 0.42;
uniform float off_level = 0.07;

void fragment() {
	vec2 cell = UV * dots;
	vec2 f = fract(cell) - 0.5;
	vec2 center_uv = (floor(cell) + 0.5) / dots;
	vec4 src = texture(TEXTURE, center_uv);
	float lum = max(src.r, max(src.g, src.b));
	float d = length(f);
	float mask = 1.0 - smoothstep(dot_radius - 0.06, dot_radius, d);
	vec3 col = tint.rgb * max(lum, off_level);
	COLOR = vec4(col * mask, 1.0);
}
