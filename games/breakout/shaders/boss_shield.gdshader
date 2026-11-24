// D-342: the bosses' shield: a red glow where a hit lands, like the ship's and
// the field's shields (D-041) but on a sphere around the boss. `hit_dir` is
// the unit direction (local) of the hit, `strength` fades 1 -> 0, `age` in s.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 shield_color : source_color = vec4(1.0, 0.18, 0.12, 1.0);
uniform vec3 hit_dir = vec3(0.0, 0.0, 1.0);
uniform float strength = 0.0;
uniform float age = 0.0;

varying vec3 dir;

void vertex() {
	dir = normalize(VERTEX);
}

void fragment() {
	float d = acos(clamp(dot(normalize(dir), normalize(hit_dir)), -1.0, 1.0));   // radians from the hit
	float core = exp(-d * d * 9.0);
	float ripple = pow(max(0.0, 1.0 - abs(d - age * 5.0) * 3.0), 2.0) * step(d, 2.2);
	// Hex-ish cells over the sphere
	vec2 g = vec2(atan(dir.z, dir.x) * 6.0, dir.y * 9.0);
	float hex = 0.6 + 0.4 * step(0.5, fract(g.x + step(0.5, fract(g.y)) * 0.5)) * step(0.15, fract(g.y));
	float a = strength * (0.35 * hex * core * 2.0 + 1.3 * core + 0.8 * ripple);
	ALBEDO = shield_color.rgb * 2.5 * a * clamp(a, 0.0, 1.0);
}
