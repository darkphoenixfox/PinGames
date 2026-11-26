// Stereo preview (D-418): a red/cyan anaglyph from the side-by-side pair
// (left eye in the left half). Dubois-style mixing is overkill for a dev check;
// this keeps the left eye's red and the right eye's green and blue.
shader_type canvas_item;

void fragment() {
	vec3 l = texture(TEXTURE, vec2(UV.x * 0.5, UV.y)).rgb;
	vec3 r = texture(TEXTURE, vec2(0.5 + UV.x * 0.5, UV.y)).rgb;
	COLOR = vec4(dot(l, vec3(0.3, 0.59, 0.11)), r.g, r.b, 1.0);
}
