// TURBO RUN gate banners (D-415): the painted gate sprite (games/racer/gate_art.gd)
// on a finely divided quad facing the road. The cloth and rope sag between the
// poles, and the cloth ripples in the wind: still at the rope, freest at the
// bottom hem, pinned at its ends. The gate is unshaded like the other sprites,
// so the ripple also shades the folds. RETRO pixelates and bands colours like
// sprite.gdshader, and the wave moves in stepped frames (`step_fps`, D-098).
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D tex : source_color, filter_linear, repeat_disable;
uniform bool retro = true;
uniform vec2 retro_size = vec2(280.0, 140.0);
uniform float levels = 12.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float step_fps = 0.0;          // 0: smooth (HD)
// Layout in UV (v = 0 at the top), from GateArt.uv_layout().
uniform vec2 poles = vec2(0.03, 0.97);  // pole centres in u
uniform vec2 cloth_u = vec2(0.06, 0.94);
uniform vec2 cloth_v = vec2(0.1, 0.36); // rope, bottom hem
uniform float sag = 0.35;               // metres the middle of the rope drops
uniform float amp = 0.32;               // metres of ripple at the hem
// D-434: stepped sizes in 8-BIT/16-BIT, as for the traffic (D-433): the
// sprite's size on screen snaps to a ladder of sizes (rungs `size_step` apart
// in log size; 0 = smooth, HD), scaled about its base. Nearer than
// `step_from` m it stays smooth.
uniform float size_step = 0.0;
uniform float step_from = 8.0;

// D-434: the factor that snaps the size on screen to the ladder of sizes.
float step_scale(mat4 modelview, mat4 projection) {
	if (size_step <= 0.0) {
		return 1.0;
	}
	float d = -(modelview * vec4(0.0, 0.0, 0.0, 1.0)).z;   // depth of the sprite's base
	if (d < step_from) {
		return 1.0;
	}
	// D-448: with the camera's zoom (it widens with speed), not the depth alone.
	float size = log(projection[0][0]) - log(d);
	return exp(round(size / size_step) * size_step - size);
}

varying float shade;

void vertex() {
	float t = TIME;
	if (step_fps > 0.0) {
		t = floor(t * step_fps) / step_fps;
	}
	// Each gate waves out of step with the others.
	t += MODEL_MATRIX[3].x * 0.37 + MODEL_MATRIX[3].z * 0.21;
	float along = clamp((UV.x - poles.x) / (poles.y - poles.x), 0.0, 1.0);
	float cu = clamp((UV.x - cloth_u.x) / (cloth_u.y - cloth_u.x), 0.0, 1.0);
	float down = clamp((UV.y - cloth_v.x) / (cloth_v.y - cloth_v.x), 0.0, 1.0);
	// The rope and everything hung from it droop in the middle. Below the hem
	// only the poles are drawn, and they don't move (along is 0 or 1 there).
	VERTEX.y -= sag * sin(3.14159 * along);
	// Below the hem only the still poles are drawn (cu is 0 there), so the
	// weight can carry on without a hard edge that would stretch triangles.
	float free = sin(3.14159 * cu) * (0.15 + 0.85 * down);
	float gust = 0.75 + 0.25 * sin(t * 0.9) * sin(t * 0.37 + 1.3);
	float phase = UV.x * 26.0 - t * 4.2 + UV.y * 9.0;
	float wave = sin(phase) + 0.35 * sin(phase * 2.3 + t * 1.7);
	VERTEX.z += amp * gust * free * wave;
	VERTEX.y += amp * 0.25 * gust * free * cos(phase);
	// Folds: lighter where the cloth faces the light, darker in the troughs.
	shade = 1.0 + 0.28 * gust * free * cos(phase);
	VERTEX *= step_scale(MODELVIEW_MATRIX, PROJECTION_MATRIX);   // D-434: about the gate's base
}

void fragment() {
	vec4 c;
	if (retro) {
		vec2 cell = (floor(UV * retro_size) + 0.5) / retro_size;
		c = textureLod(tex, cell, 0.0);
	} else {
		c = texture(tex, UV);
	}
	c.rgb *= shade;
	if (retro) {
		c.rgb = floor(c.rgb * levels + 0.5) / levels;
	}
	ALBEDO = c.rgb * tint.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
