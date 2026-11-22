// TURBO RUN pixel renderer (D-107): the 3D world is drawn at a low resolution
// and shown upscaled with nearest filtering. This pass reduces each colour
// channel to `levels` steps with a 4x4 ordered (Bayer) dither, computed in the
// low-res pixel grid, and gives the image a little extra saturation, for a
// 16-bit pixel-art palette look.
shader_type canvas_item;

uniform vec2 low_res = vec2(360.0, 640.0);
uniform float levels = 24.0;
uniform float dither = 0.6;          // 0 = plain posterise, 1 = full dither
uniform float saturation = 1.12;

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
	vec3 c = texture(TEXTURE, (px + 0.5) / low_res).rgb;
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(g), c, saturation);
	c += bayer4(px) * dither / levels;
	c = floor(c * levels + 0.5) / levels;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
