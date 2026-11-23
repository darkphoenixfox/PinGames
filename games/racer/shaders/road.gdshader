// TURBO RUN road + verge (D-089). UV.x = metres right of the centre line,
// UV.y = metres along the track. Drawn in 25 cm "texels" with a little noise
// for a 16-bit look: alternating light/dark bands every 8 m give the classic
// super-scaler sense of speed.
shader_type spatial;
render_mode cull_disabled;

uniform float road_half = 7.5;
uniform bool hd = false;   // D-195: HD graphics: no 25 cm texels, finer grain
// D-204 beach stage (UV2.x = its weight, from the track): sand down to the
// sea on the left (SHORE m from the centre), then water with rolling foam
// lines and a moving waterline; light sandy grass on the right.
uniform float shore = 30.7;
uniform vec3 wet_sand : source_color = vec3(0.72, 0.6, 0.42);
uniform vec3 shallow : source_color = vec3(0.25, 0.78, 0.8);
uniform vec3 deep : source_color = vec3(0.05, 0.3, 0.62);
uniform vec3 foam : source_color = vec3(0.95, 0.98, 1.0);
uniform vec3 dune_grass : source_color = vec3(0.62, 0.66, 0.35);
varying float beach;

void vertex() {
	beach = UV2.x;
}
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
	vec2 m = hd ? UV : floor(UV * 4.0) / 4.0;
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
	col *= 0.92 + 0.08 * hash(hd ? floor(UV * 24.0) : m);
	if (beach > 0.001 && x >= road_half + rumble) {
		vec3 b;
		if (m.x < 0.0) {
			// Left: sand, wet sand, then the sea (dist = metres out to sea).
			float wl = shore + 0.9 * sin(TIME * 1.3 + sv * 0.04);   // the waterline washes in and out
			float dist = x - wl;
			if (dist < -2.0) {
				b = mix(sand_a, sand_b, band) * (0.92 + 0.08 * hash(m));
			} else if (dist < 0.0) {
				b = wet_sand;
			} else {
				b = mix(shallow, deep, smoothstep(0.0, 60.0, dist));
				// Foam lines rolling in towards the beach, broken up along the shore.
				float wave = fract(dist * 0.06 + TIME * 0.22 + 0.15 * sin(sv * 0.03));
				float broken = step(0.35, hash(floor(vec2(dist * 0.06 + TIME * 0.22, sv / 6.0))));
				if (wave < 0.07 && dist < 45.0 && broken > 0.5) {
					b = mix(b, foam, 0.85);
				}
				if (dist < 1.4) {
					b = foam;   // surf at the waterline
				}
				// Glints on the water.
				if (hash(floor(vec2(x * 2.0, sv * 2.0)) + floor(TIME * 3.0)) > 0.985) {
					b = mix(b, foam, 0.6);
				}
			}
		} else {
			b = x < road_half + rumble + 3.0 ? mix(sand_a, sand_b, band) : mix(dune_grass, grass_b, 0.25 + 0.2 * band);
		}
		col = mix(col, b, beach);
	}
	ALBEDO = col;
	ROUGHNESS = 0.92;
	SPECULAR = 0.2;
}
