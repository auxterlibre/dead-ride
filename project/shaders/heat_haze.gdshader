shader_type canvas_item;
// Incommensurate sines so the wobble never beats; vertical dominant
// because hot air rises. Lives on a full-screen rect below the HUD layer.
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float wobble_scale = 26.0;  // ripple bands across the screen height
uniform float wobble_speed = 1.2;
uniform float wobble_amount = 0.0022;  // max UV displacement at intensity 1

void fragment() {
	float t = TIME * wobble_speed;
	vec2 uv = SCREEN_UV;
	float rise = sin(uv.y * wobble_scale * 6.283 + t * 1.7)
			+ sin(uv.y * wobble_scale * 2.718 + uv.x * 9.0 - t * 1.1);
	float sway = sin(uv.x * wobble_scale * 5.21 + t * 1.3)
			+ sin((uv.x + uv.y) * wobble_scale * 1.618 + t * 0.7);
	uv += vec2(sway * 0.35, rise) * wobble_amount * intensity;
	COLOR = texture(SCREEN_TEXTURE, uv);
}
