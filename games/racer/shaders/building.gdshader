// TURBO RUN city buildings (D-216): one unit box per building, scaled by its
// MultiMesh instance transform. The facade is drawn procedurally in metres:
// floors of windows (lit at random at night), a shopfront band on the ground
// floor, a parapet line and a flat roof. INSTANCE_CUSTOM: r = style (0..1 over
// 6 styles), g = a per-building seed.
shader_type spatial;

uniform float night = 0.0;     // 0 day .. 1 night (Night.level)
uniform bool hd = false;

varying vec3 lp;      // metres from the box centre
varying vec3 ln;      // local normal
varying vec3 bsize;   // building size (m)
varying vec4 cust;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	bsize = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	lp = VERTEX * bsize;
	ln = NORMAL;
	cust = INSTANCE_CUSTOM;
}

void fragment() {
	int style = int(cust.r * 6.0 + 0.5) % 6;
	float seed = cust.g * 97.0;
	// Facade colour, window glass and window layout per style.
	vec3 wall;
	vec3 glass;
	vec2 win = vec2(0.64, 0.55);   // window size as a fraction of its cell (w, h)
	float bay = 2.8;               // m between windows
	if (style == 0) { wall = vec3(0.55, 0.62, 0.7); glass = vec3(0.18, 0.32, 0.45); win = vec2(0.9, 0.82); }   // glass tower
	else if (style == 1) { wall = vec3(0.78, 0.72, 0.6); glass = vec3(0.2, 0.24, 0.3); }                   // sandstone
	else if (style == 2) { wall = vec3(0.6, 0.3, 0.24); glass = vec3(0.16, 0.2, 0.26); win = vec2(0.5, 0.55); } // brick
	else if (style == 3) { wall = vec3(0.62, 0.63, 0.66); glass = vec3(0.22, 0.28, 0.36); win = vec2(0.8, 0.4); bay = 3.6; } // grey concrete, strip windows
	else if (style == 4) { wall = vec3(0.86, 0.86, 0.84); glass = vec3(0.24, 0.32, 0.42); }                // white
	else { wall = vec3(0.25, 0.26, 0.3); glass = vec3(0.14, 0.2, 0.3); win = vec2(0.86, 0.75); }           // dark glass
	float y = lp.y + bsize.y * 0.5;   // metres up from the ground
	vec3 col;
	float lit = 0.0;
	vec3 warm = mix(vec3(1.0, 0.82, 0.5), vec3(0.75, 0.88, 1.0), step(0.75, hash(vec2(seed, 3.0))));
	if (abs(ln.y) > 0.5) {
		// Flat roof: dark with a few plant boxes.
		col = vec3(0.3, 0.3, 0.32) * (0.85 + 0.15 * hash(floor(lp.xz / 3.0) + seed));
	} else {
		float u = abs(ln.x) > 0.5 ? lp.z : lp.x;
		float fh = 3.4;
		vec2 cellid = vec2(floor(u / bay), floor(y / fh));
		vec2 f = vec2(fract(u / bay), fract(y / fh));
		bool in_win = abs(f.x - 0.5) < win.x * 0.5 && abs(f.y - 0.55) < win.y * 0.5;
		col = wall * (0.93 + 0.07 * hash(cellid * 0.37 + seed));
		if (y < 4.2) {
			// Ground floor: shop windows under a dark band.
			col = y > 3.6 ? wall * 0.45 : (abs(fract(u / 6.0) - 0.5) < 0.42 && y > 0.4 ? vec3(0.12, 0.16, 0.2) : wall * 0.7);
			if (y > 0.4 && y < 3.6 && abs(fract(u / 6.0) - 0.5) < 0.42) {
				lit = step(0.3, hash(vec2(floor(u / 6.0), seed)));
			}
		} else if (y > bsize.y - 1.0) {
			col = wall * 0.75;   // parapet
		} else if (in_win) {
			// Glass: a little sky reflection up each pane by day.
			col = mix(glass, glass + vec3(0.18, 0.2, 0.22), f.y);
			lit = step(0.52, hash(cellid + seed));
		}
	}
	ALBEDO = col * (1.0 - 0.6 * lit * night);
	EMISSION = warm * lit * night * 1.4;
	ROUGHNESS = 0.8;
	SPECULAR = 0.3;
}
