// TURBO RUN city junction (D-216): a cross street over the ground strip.
// UV.x = metres right of the main road's centre line, UV.y = metres along the
// main road from the junction's centre line. Inside the cross street: asphalt
// (plain where it crosses the main road, a dashed centre line beyond it);
// either side of it, zebra crossings over the main road; elsewhere nothing.
shader_type spatial;
render_mode cull_disabled;

uniform float road_half = 7.5;
uniform float jhalf = 7.0;
uniform bool hd = false;
uniform vec3 asphalt : source_color = vec3(0.33, 0.33, 0.37);
uniform vec3 paint : source_color = vec3(0.95, 0.95, 0.9);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 m = hd ? UV : floor(UV * 4.0) / 4.0;
	float x = abs(m.x);
	float z = abs(m.y);
	vec3 col = asphalt;
	if (z < jhalf) {
		if (x > road_half + 1.5 && z < 0.13 && mod(x, 6.0) < 3.0) {
			col = paint;   // the cross street's centre line
		}
	} else if (z < jhalf + 3.2 && x < road_half) {
		if (mod(m.x + 40.0, 1.2) >= 0.6) {
			discard;       // gaps between the zebra stripes show the road
		}
		col = paint;
	} else {
		discard;
	}
	ALBEDO = col * (0.93 + 0.07 * hash(floor(m * 2.0)));
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
}
