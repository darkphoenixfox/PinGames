// Tilt Breaker brick: 16-bit circuit texture (D-041) projected from the top so
// pixels stay square on the box (sides extrude the edge pixels). A separate
// greyscale glow mask makes LEDs, chip eyes and traces pulse — the swarm is alive.
// Per-brick `phase` (instance uniform) makes the pulse ripple across the rack.
shader_type spatial;
render_mode specular_schlick_ggx;

uniform sampler2D circuit : source_color, filter_nearest, repeat_disable;
uniform sampler2D glow_mask : hint_default_black, filter_nearest, repeat_disable;
uniform vec3 brick_size = vec3(0.73, 0.3, 0.35);
uniform vec4 glow_color : source_color = vec4(0.25, 0.8, 1.0, 1.0);
uniform float glow_strength = 2.2;
uniform float pulse_speed = 2.6;
instance uniform float phase = 0.0;
instance uniform float hit_flash = 0.0;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec2 uv = vec2(local_pos.x / brick_size.x + 0.5, local_pos.z / brick_size.z + 0.5);
	uv = clamp(uv, vec2(0.001), vec2(0.999));
	vec4 t = texture(circuit, uv);
	// Sides darker so the top face reads as the face of the chip.
	float is_top = step(0.5, dot(NORMAL, (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz));
	ALBEDO = t.rgb * mix(0.55, 1.0, is_top);
	float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed + phase);
	float mask = texture(glow_mask, uv).r;
	float led = smoothstep(0.8, 1.0, mask);           // eyes / LEDs
	float trace = smoothstep(0.15, 0.35, mask) - led;  // circuit traces
	vec3 glow = glow_color.rgb * (led * (0.8 + 1.6 * pulse) + trace * 0.35 * pulse);
	EMISSION = glow * glow_strength + vec3(hit_flash);
	ROUGHNESS = 0.55;
	SPECULAR = 0.2;
	METALLIC = 0.1;
}
