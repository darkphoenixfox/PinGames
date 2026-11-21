// Tilt Breaker backglass (D-058): the director's art with independently lit
// areas. TEXTURE = lights-off art; on_tex = lights-on art; mask_tex RGB = light
// groups (R engines, G shots, B impacts, soft-edged). `levels` (0..1 per group)
// is driven by game events; lit areas also get a little extra boost/bloom.
shader_type canvas_item;

uniform sampler2D on_tex : source_color, filter_linear;
uniform sampler2D mask_tex : filter_linear;
uniform sampler2D logo_mask_tex : filter_linear;  // 4th group: title logo (D-064)
uniform vec4 levels = vec4(0.0);  // engines, shots, impacts, logo
uniform float boost = 1.35;

void fragment() {
	vec3 off_c = texture(TEXTURE, UV).rgb;
	vec3 on_c = texture(on_tex, UV).rgb;
	vec3 m = texture(mask_tex, UV).rgb;
	float lm = texture(logo_mask_tex, UV).r;
	float k = clamp(dot(m, levels.xyz) + lm * levels.w, 0.0, 1.0);
	vec3 col = mix(off_c, on_c, k);
	col += max(on_c - off_c, vec3(0.0)) * k * (boost - 1.0);
	COLOR = vec4(col, 1.0);
}
