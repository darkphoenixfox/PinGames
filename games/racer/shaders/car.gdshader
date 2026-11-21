// TURBO RUN cars (D-089, D-091): the car's 256 px texture sampled nearest (16-bit
// look); traffic cars recolour the paint with a per-instance hue rotation.
// Cel shading: the sun light falls in 3 flat bands with one hard highlight
// (toon = false restores smooth lighting for comparison, --rc-no-toon).
shader_type spatial;

uniform sampler2D tex : source_color, filter_nearest;
uniform bool toon = true;
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
	ROUGHNESS = toon ? 0.8 : 0.35;
	METALLIC = toon ? 0.0 : 0.25;
	SPECULAR = toon ? 0.25 : 0.7;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	if (toon) {
		float band = ndl > 0.45 ? 1.0 : (ndl > 0.0 ? 0.62 : 0.3);
		DIFFUSE_LIGHT += band * ATTENUATION * LIGHT_COLOR / PI;
		vec3 h = normalize(VIEW + LIGHT);
		float hl = step(0.965, dot(NORMAL, h)) * step(0.0, ndl);
		SPECULAR_LIGHT += hl * 0.6 * ATTENUATION * LIGHT_COLOR / PI;
	} else {
		DIFFUSE_LIGHT += clamp(ndl, 0.0, 1.0) * ATTENUATION * LIGHT_COLOR / PI;
		vec3 h = normalize(VIEW + LIGHT);
		SPECULAR_LIGHT += pow(clamp(dot(NORMAL, h), 0.0, 1.0), 40.0) * 0.5 * ATTENUATION * LIGHT_COLOR / PI;
	}
}
