// D-332: draws only the part of a model between keep_min and keep_max along
// its own X axis (the Sidekicks are the ship's end thirds, cut from the ship
// model itself). Textured like the model's own material.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform float keep_min = -100.0;
uniform float keep_max = 100.0;
uniform float roughness_v = 0.8;
uniform float metallic_v = 0.0;

varying float model_x;

void vertex() {
	model_x = VERTEX.x;
}

void fragment() {
	if (model_x < keep_min || model_x > keep_max) {
		discard;
	}
	ALBEDO = texture(albedo_tex, UV).rgb;
	ROUGHNESS = roughness_v;
	METALLIC = metallic_v;
}
