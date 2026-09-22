shader_type canvas_item;
// Grayscale AND blur in one pass: two stacked screen-reading rects fight -
// the upper one repaints from a pre-blur snapshot and erases the lower.
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;
uniform float blur_amount : hint_range(0.0, 5.0) = 0.0;

void fragment() {
	vec4 original = textureLod(SCREEN_TEXTURE, SCREEN_UV, blur_amount);
	float gray = (original.r + original.g + original.b) / 3.0;
	COLOR = original;
	COLOR.rgb = mix(original.rgb, vec3(gray), intensity);
}
