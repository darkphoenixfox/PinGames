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
uniform float wet = 0.0;   // D-217 rain
// D-216 areas: UV2.y = city, COLOR.rgb = (desert, forest, snow) weights.
varying float city;
varying vec3 area3;
uniform float sidewalk = 5.0;
uniform vec3 concrete : source_color = vec3(0.66, 0.65, 0.62);
uniform vec3 plaza : source_color = vec3(0.4, 0.4, 0.43);
uniform vec3 desert_a : source_color = vec3(0.89, 0.67, 0.42);
uniform vec3 desert_b : source_color = vec3(0.8, 0.56, 0.34);
uniform vec3 forest_a : source_color = vec3(0.17, 0.38, 0.15);
uniform vec3 forest_b : source_color = vec3(0.36, 0.27, 0.16);
uniform vec3 snow_a : source_color = vec3(0.92, 0.95, 0.99);
uniform vec3 snow_b : source_color = vec3(0.76, 0.83, 0.93);

void vertex() {
	beach = UV2.x;
	city = UV2.y;
	area3 = COLOR.rgb;
}
uniform float rumble = 1.2;
uniform vec3 asphalt_a : source_color = vec3(0.36, 0.36, 0.4);
uniform vec3 asphalt_b : source_color = vec3(0.32, 0.32, 0.36);
uniform vec3 line_col : source_color = vec3(0.95, 0.95, 0.9);
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
	if (x < road_half + rumble) {
		// D-528: no racing kerbs: the asphalt runs on as a paved shoulder
		// outside the edge line (`rumble` is that strip's width).
		col = mix(asphalt_a, asphalt_b, band);
		bool dash = mod(sv, 12.0) < 6.0;
		if (dash && (x < 0.13 || abs(x - 3.75) < 0.13)) col = line_col;
		if (abs(x - (road_half - 0.35)) < 0.13) col = line_col;
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
	vec2 cell = floor(m * 0.5);
	if (city > 0.001 && x >= road_half) {
		// Grey kerb, paved sidewalk (slab joints every 1.5 m), then darker plazas.
		vec3 c;
		if (x < road_half + rumble) {
			c = concrete * 0.85;
		} else if (x < road_half + rumble + sidewalk) {
			bool joint = mod(sv, 1.5) < 0.12 || mod(x - road_half - rumble, 1.5) < 0.12;
			c = concrete * (joint ? 0.82 : 0.97 + 0.05 * hash(floor(m / 1.5)));
		} else {
			c = plaza * (0.94 + 0.06 * hash(cell));
		}
		col = mix(col, c, city);
	}
	if (area3.r > 0.001 && x >= road_half + rumble) {
		// Desert: sand with wind ripples.
		float rip = 0.5 + 0.5 * sin(sv * 0.9 + x * 0.35 + sin(x * 0.07) * 4.0);
		vec3 c = mix(desert_a, desert_b, rip * 0.6 + 0.2 * hash(cell));
		col = mix(col, c, area3.r);
	}
	if (area3.g > 0.001 && x >= road_half + rumble + 1.0) {
		// Forest floor: dark grass with patches of brown needles.
		float patchy = step(0.62, hash(floor(m / 3.0)));
		vec3 c = mix(forest_a * (0.9 + 0.2 * hash(cell)), forest_b, patchy * 0.8);
		col = mix(col, c, area3.g);
	}
	if (area3.b > 0.001) {
		// Snow: white off the road, blue in the hollows; dusted road edges.
		float shade = 0.5 + 0.5 * sin(sv * 0.05 + x * 0.12);
		vec3 c = mix(snow_a, snow_b, shade * 0.6 + 0.15 * hash(cell));
		if (x >= road_half + rumble) {
			col = mix(col, c, area3.b);
		} else if (x >= road_half - 1.2) {
			col = mix(col, snow_a, area3.b * 0.55 * smoothstep(road_half - 1.2, road_half + rumble, x));
		}
	}
	// D-217: rain darkens the road and gives it a sheen.
	col *= 1.0 - 0.32 * wet;
	ALBEDO = col;
	ROUGHNESS = mix(0.92, 0.35, wet);
	SPECULAR = mix(0.2, 0.55, wet);
}
