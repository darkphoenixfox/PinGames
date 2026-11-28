// TURBO RUN car shards (D-510): a flat piece of bodywork showing a patch of
// the car's own texture, repainted as the car is (the hue rules of
// car.gdshader, D-312), lit by the scene on both faces.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D tex : source_color, filter_linear;
uniform float hue = 0.0;

vec3 hue_rotate(vec3 c, float a) {
	const vec3 k = vec3(0.57735);
	float ca = cos(a);
	return c * ca + cross(k, c) * sin(a) + k * dot(k, c) * (1.0 - ca);
}

void fragment() {
	vec3 c = texture(tex, UV).rgb;
	float hi = max(c.r, max(c.g, c.b));
	float lo = min(c.r, min(c.g, c.b));
	float sat = hi > 0.001 ? (hi - lo) / hi : 0.0;
	vec3 painted;
	if (hue >= 9.5) {
		vec3 r = hue_rotate(c, (hue - 10.0) * 6.2831853);
		float l = dot(r, vec3(0.3, 0.59, 0.11));
		float k = smoothstep(0.15, 0.3, sat);
		painted = mix(r, clamp(mix(vec3(l), r, 2.6) * 0.85, 0.0, 1.0), k);
	} else if (hue >= 1.5) {
		vec3 col = hue < 2.5 ? vec3(0.015 + hi * 0.07) : vec3(0.16 + hi * 0.3);
		painted = mix(c, col, smoothstep(0.22, 0.4, sat));
	} else {
		painted = hue_rotate(c, hue * 6.2831853);
	}
	ALBEDO = clamp(painted, 0.0, 1.0);
	ROUGHNESS = 0.6;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
