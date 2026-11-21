// TURBO RUN road + verge (D-089). UV.x = metres right of the centre line,
// UV.y = metres along the track. Drawn in 25 cm "texels" with a little noise
// for a 16-bit look: alternating light/dark bands every 8 m give the classic
// super-scaler sense of speed.
shader_type spatial;
render_mode cull_disabled;

uniform float road_half = 7.5;
uniform float rumble = 1.2;
uniform vec3 asphalt_a : source_color = vec3(0.36, 0.36, 0.4);
uniform vec3 asphalt_b : source_color = vec3(0.32, 0.32, 0.36);
uniform vec3 line_col : source_color = vec3(0.95, 0.95, 0.9);
uniform vec3 kerb_a : source_color = vec3(0.9, 0.12, 0.12);
uniform vec3 kerb_b : source_color = vec3(0.95, 0.95, 0.95);
uniform vec3 sand_a : source_color = vec3(0.93, 0.8, 0.55);
uniform vec3 sand_b : source_color = vec3(0.86, 0.72, 0.48);
uniform vec3 grass_a : source_color = vec3(0.28, 0.62, 0.2);
uniform vec3 grass_b : source_color = vec3(0.22, 0.52, 0.16);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 m = floor(UV * 4.0) / 4.0;
	float x = abs(m.x);
	float sv = m.y;
	float band = mod(floor(sv / 8.0), 2.0);
	vec3 col;
	if (x < road_half) {
		col = mix(asphalt_a, asphalt_b, band);
		bool dash = mod(sv, 12.0) < 6.0;
		if (dash && (x < 0.13 || abs(x - 3.75) < 0.13)) col = line_col;
		if (abs(x - (road_half - 0.35)) < 0.13) col = line_col;
	} else if (x < road_half + rumble) {
		col = mod(floor(sv / 4.0), 2.0) < 1.0 ? kerb_a : kerb_b;
	} else if (x < road_half + rumble + 3.0) {
		col = mix(sand_a, sand_b, band);
	} else {
		col = mix(grass_a, grass_b, band);
	}
	col *= 0.92 + 0.08 * hash(m);
	ALBEDO = col;
	ROUGHNESS = 0.92;
	SPECULAR = 0.2;
}
