// TURBO RUN roadside sprites (D-196): one high-res painted cut-out per kind,
// drawn unshaded and alpha-scissored, turned to the camera around the vertical
// axis (billboard, keeping the node's scale). HD shows the art as it is,
// smoothly filtered. RETRO is this shader's job: the art is snapped to a coarse
// texel grid (`retro_size`, the old pixel sprites' resolution), each block
// taking the art's average colour from a lower mip level, then banded to a few
// colour levels with a hard alpha edge, for the 16-bit look.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool retro = true;
uniform vec2 retro_size = vec2(64.0, 128.0);   // texels across x up in RETRO
uniform float levels = 12.0;                   // colour steps per channel in RETRO
uniform vec4 tint : source_color = vec4(1.0);  // night tint (Sprites.set_night)
uniform bool flip = false;                     // mirrored (left-turn curve sign)
uniform bool billboard = true;

void vertex() {
	if (billboard) {
		// Face the camera around Y (like BILLBOARD_FIXED_Y with keep scale).
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
			vec4(0.0, 1.0, 0.0, 0.0),
			vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
			MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

void fragment() {
	vec2 uv = UV;
	if (flip) {
		uv.x = 1.0 - uv.x;
	}
	vec4 c;
	if (retro) {
		vec2 cell = (floor(uv * retro_size) + 0.5) / retro_size;
		float lod = log2(max(1.0, float(textureSize(tex, 0).y) / retro_size.y));
		c = textureLod(tex, cell, lod);
		c.rgb = floor(c.rgb * levels + 0.5) / levels;
	} else {
		c = texture(tex, uv);
	}
	ALBEDO = c.rgb * tint.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
