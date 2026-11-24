// D-335: the boss's eye, a HAL-style lens seen from the front: a white-hot
// pinpoint, a coloured glow (D-338: blue at full health to red near death), a dark lens and a silver rim. `glow` brightens it
// (charging, being hit).
shader_type spatial;
render_mode unshaded;

uniform float glow = 0.0;
uniform vec3 iris : source_color = vec3(1.0, 0.08, 0.04);   // D-338: its colour shows the boss's health

void fragment() {
	float r = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);   // 0 at the centre, 1 at the edge
	vec3 c = mix(vec3(1.0, 0.95, 0.8), iris, smoothstep(0.01, 0.09, r));
	c = mix(c, iris * 0.42, smoothstep(0.09, 0.3, r));
	c = mix(c, iris * 0.03, smoothstep(0.3, 0.55, r));
	c = mix(c, vec3(0.6, 0.62, 0.68), smoothstep(0.82, 0.96, r));
	ALBEDO = c * (1.0 + glow * (1.0 - smoothstep(0.0, 0.5, r)) * 1.5);
}
