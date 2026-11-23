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
	// D-225: darker facades; the lit rooms carry the night.
	vec3 wall;
	vec3 glass;
	vec2 win = vec2(0.64, 0.55);   // window size as a fraction of its cell (w, h)
	float bay = 2.8;               // m between windows
	bool office = false;           // whole floors lit in bands (glass towers)
	if (style == 0) { wall = vec3(0.26, 0.31, 0.38); glass = vec3(0.08, 0.13, 0.2); win = vec2(0.92, 0.8); office = true; }
	else if (style == 1) { wall = vec3(0.42, 0.38, 0.32); glass = vec3(0.08, 0.1, 0.13); }
	else if (style == 2) { wall = vec3(0.34, 0.17, 0.14); glass = vec3(0.07, 0.08, 0.11); win = vec2(0.5, 0.55); }
	else if (style == 3) { wall = vec3(0.33, 0.34, 0.36); glass = vec3(0.09, 0.12, 0.16); win = vec2(0.8, 0.4); bay = 3.6; }
	else if (style == 4) { wall = vec3(0.48, 0.48, 0.47); glass = vec3(0.1, 0.13, 0.18); }
	else { wall = vec3(0.12, 0.13, 0.16); glass = vec3(0.05, 0.08, 0.13); win = vec2(0.9, 0.78); office = true; }
	float y = lp.y + bsize.y * 0.5;   // metres up from the ground
	vec3 col;
	float lit = 0.0;
	vec3 room = vec3(1.0, 0.8, 0.48);
	if (abs(ln.y) > 0.5) {
		// Flat roof: dark, with a few plant boxes.
		col = vec3(0.14, 0.14, 0.16) * (0.85 + 0.15 * hash(floor(lp.xz / 3.0) + seed));
	} else {
		float u = abs(ln.x) > 0.5 ? lp.z : lp.x;
		float fh = 3.4;
		vec2 cellid = vec2(floor(u / bay), floor(y / fh));
		vec2 f = vec2(fract(u / bay), fract(y / fh));
		bool in_win = abs(f.x - 0.5) < win.x * 0.5 && abs(f.y - 0.55) < win.y * 0.5;
		col = wall * (0.9 + 0.1 * hash(cellid * 0.37 + seed));
		// Rooms: offices lit in runs along a floor, flats window by window.
		vec2 roomid = office ? vec2(floor(u / (bay * 4.0)), cellid.y) : cellid;
		float on = hash(roomid + seed);
		// Each room's light: warm tungsten, cool office white or a TV blue.
		float tone = hash(roomid * 1.7 + seed + 5.0);
		room = tone < 0.55 ? vec3(1.0, 0.78, 0.45) : (tone < 0.9 ? vec3(0.82, 0.92, 1.0) : vec3(0.45, 0.6, 1.0));
		if (y < 4.2) {
			// Ground floor: shop windows under a dark band, nearly all lit.
			bool shop = abs(fract(u / 6.0) - 0.5) < 0.42 && y > 0.4 && y < 3.6;
			col = y > 3.6 ? wall * 0.4 : (shop ? vec3(0.06, 0.08, 0.1) : wall * 0.6);
			if (shop) {
				lit = step(0.15, hash(vec2(floor(u / 6.0), seed))) * 1.2;
				room = vec3(1.0, 0.9, 0.7);
			}
		} else if (y > bsize.y - 1.0) {
			col = wall * 0.7;   // parapet
		} else if (in_win) {
			// Glass: a little sky reflection up each pane by day.
			col = mix(glass, glass + vec3(0.1, 0.12, 0.14), f.y);
			lit = step(0.38, on);
			// Inside: brighter towards the ceiling lights; some have blinds.
			float wy = (f.y - (0.55 - win.y * 0.5)) / win.y;
			lit *= 0.65 + 0.55 * wy;
			if (hash(roomid + seed + 9.0) > 0.7) {
				lit *= 0.55 + 0.45 * step(0.5, fract(wy * 7.0));
			}
		}
	}
	// A dim scattering of lights by day; the city lights up at night.
	float lv = mix(0.12, 1.0, night);
	// At night the walls fall into shadow (D-225): only the rooms glow.
	ALBEDO = col * (1.0 - 0.7 * min(lit, 1.0) * night) * (1.0 - 0.6 * night);
	EMISSION = room * lit * lv * 2.4;
	ROUGHNESS = 0.6;
	SPECULAR = 0.4;
}
