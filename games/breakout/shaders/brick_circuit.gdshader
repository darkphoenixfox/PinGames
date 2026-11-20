// Tilt Breaker brick (D-045): each brick shows its own rectangle cut from the
// director's 16-bit circuit texture (512 px, nearest filtering = chunky pixels).
// crop_offset (per brick, instance uniform) picks where the rectangle is cut;
// crop_size is the brick's footprint in texture UV. Projected from the top so
// texels stay square (sides extrude the edge texels, darker).
// The glow mask is derived from the texture itself: bright, saturated pixels
// (LEDs, lit traces) pulse — the nanomachine swarm is alive.
shader_type spatial;
render_mode specular_schlick_ggx;

uniform sampler2D circuit : source_color, filter_nearest, repeat_enable;
uniform vec3 brick_size = vec3(0.73, 0.3, 0.35);
uniform vec2 crop_size = vec2(0.125, 0.06);
uniform vec2 brick_texels = vec2(64.0, 31.0);  // texels across the brick face
uniform vec4 glow_color : source_color = vec4(0.25, 0.8, 1.0, 1.0);
uniform float glow_strength = 1.8;
uniform float pulse_speed = 2.6;
instance uniform vec2 crop_offset = vec2(0.0);
instance uniform float phase = 0.0;
instance uniform float hit_flash = 0.0;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec2 uv = vec2(local_pos.x / brick_size.x + 0.5, local_pos.z / brick_size.z + 0.5);
	uv = clamp(uv, vec2(0.001), vec2(0.999));
	vec3 t = texture(circuit, crop_offset + uv * crop_size).rgb;
	// Sides darker so the top face reads as the face of the chip.
	float is_top = step(0.5, dot(NORMAL, (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz));
	// 16-bit bevel, 1 texel wide: light top/left, dark bottom/right, so every
	// brick reads as its own chip even though the art is continuous.
	vec2 tx = floor(uv * brick_texels);
	float light = max(step(tx.x, 0.0), step(tx.y, 0.0));
	float dark = max(step(brick_texels.x - 1.0, tx.x), step(brick_texels.y - 1.0, tx.y));
	vec3 face = mix(t, t * 0.35, dark);
	face = mix(face, mix(t, glow_color.rgb, 0.35) * 1.4, light * (1.0 - dark));
	ALBEDO = face * mix(0.5, 1.0, is_top);
	// Glow mask from the texture: lit LEDs/traces are bright AND saturated.
	float hi = max(t.r, max(t.g, t.b));
	float lo = min(t.r, min(t.g, t.b));
	float mask = smoothstep(0.45, 0.8, hi) * smoothstep(0.2, 0.45, hi - lo);
	float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed + phase);
	EMISSION = (t * 0.5 + glow_color.rgb * 0.5) * mask * (0.5 + 1.3 * pulse) * glow_strength * is_top
		+ vec3(hit_flash);
	ROUGHNESS = 0.6;
	SPECULAR = 0.2;
	METALLIC = 0.1;
}
