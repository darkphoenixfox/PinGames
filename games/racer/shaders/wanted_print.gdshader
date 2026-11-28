// TURBO RUN WANTED poster photo (D-527): the car as if printed by a black and
// white printer on the poster's paper: grey levels as a slanted screen of ink
// dots (big dots where it is dark, none where it is light), ink on paper.
shader_type canvas_item;

uniform vec4 ink : source_color = vec4(0.2, 0.12, 0.07, 1.0);
uniform vec4 paper : source_color = vec4(0.78, 0.7, 0.54, 1.0);
uniform vec2 cells = vec2(320.0, 180.0);   // ink dots across the whole picture
uniform float contrast = 1.35;
uniform float lift = 0.0;                // lighter overall, so the car's shape reads

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	// Mostly the strongest channel, so a deep blue or red car prints as a
	// mid grey with its shading, not as a black shape.
	float light = mix(dot(c.rgb, vec3(0.299, 0.587, 0.114)), max(c.r, max(c.g, c.b)), 0.4);
	light = clamp((light - 0.5) * contrast + 0.5 + lift, 0.0, 1.0);
	vec2 p = mat2(vec2(0.7071, 0.7071), vec2(-0.7071, 0.7071)) * (UV * cells);
	float r = length(fract(p) - 0.5) * 1.4142;   // 0 at a dot's middle, 1 at the cell's corner
	float dark = sqrt(1.0 - light) * 1.08;       // the dot's radius for this grey
	float inked = smoothstep(r - 0.1, r + 0.1, dark);
	COLOR = vec4(mix(paper.rgb, ink.rgb, inked), c.a);
}
