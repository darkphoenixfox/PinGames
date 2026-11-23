// The body of an on-screen touch button (D-279): a glass disc with a bevelled
// rim in the button's colour, a gloss highlight, a soft drop shadow and a glow
// that flares when pressed. Drawn on a rect larger than the button by `grow`
// (a share of its diameter on each side), so the shadow and glow have room.
shader_type canvas_item;

uniform vec4 tint : source_color = vec4(0.2, 0.55, 1.0, 1.0);
uniform float press = 0.0;   // 0 at rest .. 1 held
uniform float grow = 0.3;
uniform float see_through = 0.45;   // how much of the game shows through at rest

vec4 over(vec4 under, vec4 top) {
	float a = top.a + under.a * (1.0 - top.a);
	vec3 c = (top.rgb * top.a + under.rgb * under.a * (1.0 - top.a)) / max(a, 0.0001);
	return vec4(c, a);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0 * (1.0 + 2.0 * grow);   // the disc's edge is |p| = 1
	float d = length(p);
	float aa = fwidth(d) * 1.25;
	float v = clamp(p.y * 0.5 + 0.5, 0.0, 1.0);        // 0 top .. 1 bottom

	// Drop shadow, below the button; it tucks in when the button is pressed.
	float sd = length(p - vec2(0.0, 0.12 * (1.0 - press)));
	vec4 col = vec4(0.0, 0.0, 0.0, (1.0 - smoothstep(0.82, 1.32, sd)) * 0.5);

	// Glow in the button's colour, round the rim.
	float glow = exp(-abs(d - 1.0) * 6.5) * (0.22 + 0.78 * press);
	col = over(col, vec4(mix(tint.rgb, vec3(1.0), 0.25 * press), glow * 0.85));

	// Glass body: lighter at the top, deep at the bottom; fills with colour when held.
	float body = 1.0 - smoothstep(1.0 - aa, 1.0, d);
	vec3 base = mix(tint.rgb * 0.82, tint.rgb * 0.24, smoothstep(0.1, 0.95, v));
	base = mix(base, mix(tint.rgb * 1.15, tint.rgb * 0.6, v), press * 0.85);
	float base_a = mix(1.0 - see_through, 0.92, press);

	// Rim: a bevel, bright at the top edge and deeper below.
	float rim_w = 0.1;
	float rim = smoothstep(1.0 - rim_w - aa, 1.0 - rim_w, d);
	vec3 rim_c = mix(mix(tint.rgb, vec3(1.0), 0.6), tint.rgb * 0.55, smoothstep(0.15, 0.9, v));
	// A thin bright line on the rim's outer edge and a dark groove inside it.
	rim_c += vec3(0.25) * smoothstep(1.0 - 0.035 - aa, 1.0 - 0.035, d) * (1.0 - v);
	float groove = smoothstep(1.0 - rim_w - 0.09, 1.0 - rim_w, d) * (1.0 - rim);
	base *= 1.0 - groove * 0.45;

	// Gloss: a soft highlight across the upper half of the glass.
	vec2 g = (p - vec2(0.0, -0.42)) / vec2(0.78, 0.4);
	float gloss = (1.0 - smoothstep(0.55, 1.0, length(g))) * 0.26 * (1.0 - press * 0.5);
	// A faint bounce light at the bottom.
	vec2 b = (p - vec2(0.0, 0.62)) / vec2(0.6, 0.22);
	gloss += (1.0 - smoothstep(0.3, 1.0, length(b))) * 0.1;
	base = mix(base, vec3(1.0), gloss);

	vec3 c = mix(base, rim_c, rim);
	float a = mix(max(base_a, gloss), 0.97, rim) * body;
	COLOR = over(col, vec4(c, a));
}
