// D-387: CRT scanlines over the whole picture in the 8-BIT and 16-BIT modes.
// One bright line per low-resolution row with a darker gap between rows. As on
// a real tube (and in the way MAME's scanline pass models it), bright pixels
// spread into the gap and dark ones leave it wider. Written for this game.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float rows = 270.0;        // low-resolution rows down the TABLE
uniform float strength = 0.45;     // 0 = off, 1 = gaps go fully dark
uniform float thin = 0.9;          // higher = thinner bright lines
uniform float vary = 0.9;          // how much a dark pixel thins its line
uniform float boost = 1.14;        // makes up for the light the gaps take

void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	float s = sin(PI * UV.y * rows);
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	float line = pow(s * s, thin * (1.0 + vary * (1.0 - luma)));
	// Under about two screen pixels per row the lines can't be drawn evenly
	// (they shimmer), so the effect fades out on small windows.
	float px_per_row = 1.0 / max(rows * fwidth(UV.y), 0.0001);
	float k = strength * smoothstep(1.6, 2.4, px_per_row);
	COLOR = vec4(c * mix(1.0, line * boost, k), 1.0);
}
