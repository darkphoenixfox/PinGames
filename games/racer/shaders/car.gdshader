// TURBO RUN cars (D-089): the car's 256 px texture sampled nearest (16-bit
// look); traffic cars recolour the paint with a per-instance hue rotation.
shader_type spatial;

uniform sampler2D tex : source_color, filter_nearest;
instance uniform float hue = 0.0;
instance uniform float bright = 1.0;

vec3 hue_rotate(vec3 c, float a) {
	const vec3 k = vec3(0.57735);
	float ca = cos(a);
	return c * ca + cross(k, c) * sin(a) + k * dot(k, c) * (1.0 - ca);
}

void fragment() {
	vec3 c = texture(tex, UV).rgb;
	ALBEDO = hue_rotate(c, hue * 6.2831853) * bright;
	ROUGHNESS = 0.35;
	METALLIC = 0.25;
	SPECULAR = 0.7;
}
