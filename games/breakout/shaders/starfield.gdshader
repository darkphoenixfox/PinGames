// Tilt Breaker starfield (D-049): pixel-art stars drawn as the 3D background
// (Environment BG_CANVAS). Three parallax layers of square stars rotate around a
// pivot far below the screen (towards the planet's centre) by `angle`, which the
// game advances with the ship's movement, so moving feels like swinging along
// the orbit. Gentle per-star twinkle.
shader_type canvas_item;

uniform float angle = 0.0;                 // radians, accumulated by the game
uniform vec2 pivot = vec2(0.5, 3.0);       // in screen UV (y down); far below
uniform vec2 base_size = vec2(1080.0, 1920.0);
uniform vec4 space_color : source_color = vec4(0.008, 0.01, 0.025, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash2(vec2 p) {
	return vec2(hash(p), hash(p + vec2(17.3, 51.9)));
}

vec3 star_layer(vec2 px, float rot, float cell, float star_px, float density, vec3 tint, float seed) {
	vec2 pv = pivot * base_size;
	float c = cos(rot);
	float s = sin(rot);
	vec2 d = px - pv;
	vec2 rp = vec2(c * d.x - s * d.y, s * d.x + c * d.y) + pv;
	vec2 g = rp / cell;
	vec2 id = floor(g) + seed;
	if (hash(id) > density) {
		return vec3(0.0);
	}
	vec2 pos = (0.2 + 0.6 * hash2(id)) * cell;          // star position in its cell
	vec2 off = abs(fract(g) * cell - pos);
	float sz = star_px * (hash(id + 3.1) > 0.85 ? 2.0 : 1.0);
	float on = step(max(off.x, off.y), sz * 0.5);        // a square pixel
	float tw = 0.65 + 0.35 * sin(TIME * (1.5 + hash(id + 7.7) * 3.0) + hash(id) * 6.28);
	return tint * on * tw * (0.6 + 0.6 * hash(id + 9.2));
}

void fragment() {
	vec2 px = UV * base_size;
	vec3 col = space_color.rgb;
	col += star_layer(px, angle * 0.35, 48.0, 3.0, 0.28, vec3(0.35, 0.4, 0.55), 0.0);  // far
	col += star_layer(px, angle * 0.6, 90.0, 3.0, 0.22, vec3(0.6, 0.65, 0.8), 31.0);   // mid
	col += star_layer(px, angle, 170.0, 4.0, 0.2, vec3(0.9, 0.88, 0.8), 73.0);         // near
	COLOR = vec4(col, 1.0);
}
