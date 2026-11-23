// Side-panel frame (D-276): the frame texture tiled at its own pixel size,
// with a raised bezel: the outer edges lit top-left and shaded bottom-right,
// the inner lip the other way round (as if the screen sits recessed), and a
// dark seam where the frame meets the screen.
shader_type canvas_item;

uniform vec2 rect_size = vec2(100.0);   // the frame's size in pixels
uniform float thickness = 12.0;         // frame band width in pixels
uniform float tile_px = 64.0;           // on-screen size of one texture tile

void fragment() {
	vec2 px = UV * rect_size;
	float l = px.x;
	float t = px.y;
	float r = rect_size.x - px.x;
	float b = rect_size.y - px.y;
	float d = min(min(l, r), min(t, b));   // distance from the outer edge
	if (d > thickness) {
		discard;   // the screen is drawn there
	}
	vec3 c = texture(TEXTURE, px / tile_px).rgb * 0.85;
	float bev = max(thickness * 0.32, 2.0);
	// Outer bevel: which edge is nearest decides lit or shaded.
	if (d < bev) {
		float k = 1.0 - d / bev;
		float lit = (min(l, t) <= min(r, b)) ? 1.0 : -1.0;
		c = lit > 0.0 ? mix(c, vec3(1.0), 0.55 * k) : c * (1.0 - 0.6 * k);
	}
	// Inner lip: the opposite light, dark at the seam.
	float di = thickness - d;
	if (di < bev) {
		float k = 1.0 - di / bev;
		// The inner edge nearest: top or left inner edges are shaded.
		float il = t - thickness;
		float it = l - thickness;
		float ir = r - thickness;
		float ib = b - thickness;
		bool shade = min(abs(il), abs(it)) <= min(abs(ir), abs(ib));
		c = shade ? c * (1.0 - 0.55 * k) : mix(c, vec3(1.0), 0.35 * k);
		if (di < 1.5) {
			c *= 0.25;   // the seam
		}
	}
	COLOR = vec4(c, 1.0);
}
