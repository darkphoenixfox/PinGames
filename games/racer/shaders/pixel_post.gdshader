// TURBO RUN pixel renderer (D-107): the 3D world is drawn at a low resolution
// and shown upscaled with nearest filtering. This pass reduces each colour
// channel to `levels` steps with a 4x4 ordered (Bayer) dither, computed in the
// low-res pixel grid, and gives the image a little extra saturation, for a
// 16-bit pixel-art palette look.
// D-207 8-BIT mode (`nes`): instead, each pixel is dithered and snapped to the
// nearest of a fixed 54-colour palette in the style of the 8-bit consoles
// (12 hues x 4 brightness rows + 6 greys; our own, generated from HSL
// rows, see D-207).
shader_type canvas_item;

uniform vec2 low_res = vec2(360.0, 640.0);
uniform float levels = 24.0;
uniform float dither = 0.6;          // 0 = plain posterise, 1 = full dither
uniform float saturation = 1.12;
uniform bool keep_alpha = false;     // D-122: let a backdrop show through (showroom)
uniform bool nes = false;            // D-207: 8-bit palette
uniform float nes_dither = 0.09;

const vec3 NES_PAL[54] = vec3[54](
	vec3(0.060, 0.180, 0.540),
	vec3(0.180, 0.060, 0.540),
	vec3(0.420, 0.060, 0.540),
	vec3(0.540, 0.060, 0.420),
	vec3(0.540, 0.060, 0.180),
	vec3(0.540, 0.180, 0.060),
	vec3(0.540, 0.420, 0.060),
	vec3(0.420, 0.540, 0.060),
	vec3(0.180, 0.540, 0.060),
	vec3(0.060, 0.540, 0.180),
	vec3(0.060, 0.540, 0.420),
	vec3(0.060, 0.420, 0.540),
	vec3(0.075, 0.287, 0.925),
	vec3(0.288, 0.075, 0.925),
	vec3(0.713, 0.075, 0.925),
	vec3(0.925, 0.075, 0.712),
	vec3(0.925, 0.075, 0.287),
	vec3(0.925, 0.287, 0.075),
	vec3(0.925, 0.713, 0.075),
	vec3(0.713, 0.925, 0.075),
	vec3(0.287, 0.925, 0.075),
	vec3(0.075, 0.925, 0.288),
	vec3(0.075, 0.925, 0.713),
	vec3(0.075, 0.713, 0.925),
	vec3(0.510, 0.615, 0.930),
	vec3(0.615, 0.510, 0.930),
	vec3(0.825, 0.510, 0.930),
	vec3(0.930, 0.510, 0.825),
	vec3(0.930, 0.510, 0.615),
	vec3(0.930, 0.615, 0.510),
	vec3(0.930, 0.825, 0.510),
	vec3(0.825, 0.930, 0.510),
	vec3(0.615, 0.930, 0.510),
	vec3(0.510, 0.930, 0.615),
	vec3(0.510, 0.930, 0.825),
	vec3(0.510, 0.825, 0.930),
	vec3(0.832, 0.856, 0.928),
	vec3(0.856, 0.832, 0.928),
	vec3(0.904, 0.832, 0.928),
	vec3(0.928, 0.832, 0.904),
	vec3(0.928, 0.832, 0.856),
	vec3(0.928, 0.856, 0.832),
	vec3(0.928, 0.904, 0.832),
	vec3(0.904, 0.928, 0.832),
	vec3(0.856, 0.928, 0.832),
	vec3(0.832, 0.928, 0.856),
	vec3(0.832, 0.928, 0.904),
	vec3(0.832, 0.904, 0.928),
	vec3(0.000, 0.000, 0.000),
	vec3(0.180, 0.180, 0.180),
	vec3(0.420, 0.420, 0.420),
	vec3(0.660, 0.660, 0.660),
	vec3(0.860, 0.860, 0.860),
	vec3(1.000, 1.000, 1.000));


float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	const float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return m[i] / 16.0 - 0.5;
}

void fragment() {
	vec2 px = floor(UV * low_res);
	vec4 src = texture(TEXTURE, (px + 0.5) / low_res);
	vec3 c = src.rgb;
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(g), c, saturation);
	if (nes) {
		c = clamp(c + bayer4(px) * nes_dither, 0.0, 1.0);
		vec3 best = NES_PAL[0];
		float bd = 1e9;
		for (int i = 0; i < 54; i++) {
			vec3 d = NES_PAL[i] - c;
			// "Redmean"-style weights: closer to how the eye judges colours.
			float e = dot(d * d, vec3(2.0, 4.0, 3.0));
			if (e < bd) {
				bd = e;
				best = NES_PAL[i];
			}
		}
		c = best;
	} else {
		c += bayer4(px) * dither / levels;
		c = floor(c * levels + 0.5) / levels;
	}
	COLOR = vec4(clamp(c, 0.0, 1.0), keep_alpha ? step(0.5, src.a) : 1.0);
}
