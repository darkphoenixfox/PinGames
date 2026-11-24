// D-335: the boss's eye, a HAL-style lens seen from the front: a white-hot
// pinpoint, a red glow, a dark lens and a silver rim. `glow` brightens it
// (charging, being hit).
shader_type spatial;
render_mode unshaded;

uniform float glow = 0.0;

void fragment() {
	float r = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);   // 0 at the centre, 1 at the edge
	vec3 c = mix(vec3(1.0, 0.95, 0.65), vec3(1.0, 0.08, 0.04), smoothstep(0.01, 0.09, r));
	c = mix(c, vec3(0.45, 0.0, 0.0), smoothstep(0.09, 0.3, r));
	c = mix(c, vec3(0.03, 0.0, 0.0), smoothstep(0.3, 0.55, r));
	c = mix(c, vec3(0.6, 0.62, 0.68), smoothstep(0.82, 0.96, r));
	ALBEDO = c * (1.0 + glow * (1.0 - smoothstep(0.0, 0.5, r)) * 1.5);
}
