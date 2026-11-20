// Tilt Breaker backdrop planet (D-043, D-049): earth-like surface with procedural oceans,
// continents and clouds, a glowing atmospheric rim, and impact flashes where lost
// plasma shots strike (impact_point in world space, impact_age seconds since hit).
// "Out of focus" is faked here (few noise octaves, wide soft edges) instead of
// camera DOF, which would also blur the starfield.
shader_type spatial;
render_mode specular_schlick_ggx;

uniform float detail_scale = 0.22;     // noise frequency per world unit on the surface
uniform float sea_level = 0.5;
uniform float softness = 0.12;   // width of coast/cloud edges: bigger = blurrier
uniform vec4 deep_sea : source_color = vec4(0.02, 0.08, 0.25, 1.0);
uniform vec4 shallow_sea : source_color = vec4(0.05, 0.35, 0.55, 1.0);
uniform vec4 lowland : source_color = vec4(0.16, 0.42, 0.14, 1.0);
uniform vec4 highland : source_color = vec4(0.45, 0.36, 0.2, 1.0);
uniform vec4 atmosphere : source_color = vec4(0.35, 0.65, 1.0, 1.0);
uniform float atmosphere_glow = 4.5;
uniform vec3 impact_point = vec3(0.0, -9999.0, 0.0);
uniform float impact_age = 99.0;

varying vec3 local_pos;
varying vec3 world_pos;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x),
				   mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			   mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
				   mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {  // few octaves = no fine detail (defocused)
		v += a * noise(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	local_pos = VERTEX;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 p = local_pos * detail_scale;
	float h = fbm(p);
	float land = smoothstep(sea_level - softness * 0.5, sea_level + softness * 0.5, h);
	float coast = smoothstep(sea_level - softness * 1.5, sea_level, h) * (1.0 - land);
	vec3 sea = mix(deep_sea.rgb, shallow_sea.rgb, coast);
	vec3 ground = mix(lowland.rgb, highland.rgb, smoothstep(sea_level + 0.05, sea_level + 0.2, h));
	vec3 col = mix(sea, ground, land);
	// Drifting clouds
	float c = fbm(p * 1.6 + vec3(TIME * 0.015, 0.0, TIME * 0.01));
	float cloud = smoothstep(0.5, 0.5 + softness * 2.5, c);
	col = mix(col, vec3(0.95), cloud * 0.85);
	ALBEDO = col;
	ROUGHNESS = mix(0.35, 0.95, max(land, cloud));
	SPECULAR = mix(0.5, 0.1, max(land, cloud));
	// Atmospheric rim (orthographic: VIEW is the camera direction)
	// We only ever see a thin slice near the silhouette, so the rim term must be
	// very sharp (high power) or the whole visible surface glows.
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 14.0);
	vec3 emit = atmosphere.rgb * rim * atmosphere_glow;
	// Impact: a fiery flash plus an expanding shockwave ring on the surface.
	// (Seen at a grazing angle, so the lit area is wide to read on screen.)
	float fade = clamp(1.0 - impact_age / 2.0, 0.0, 1.0);
	float d = distance(world_pos, impact_point);
	float flash = exp(-d * d * 0.08) * fade * fade;
	float ring = exp(-pow(d - impact_age * 7.0, 2.0) * 0.6) * fade;
	emit += vec3(1.0, 0.5, 0.15) * flash * 10.0 + vec3(1.0, 0.75, 0.45) * ring * 4.0;
	EMISSION = emit;
}
