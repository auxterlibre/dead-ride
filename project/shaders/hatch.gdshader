shader_type canvas_item;
// Diagonal stripes for locked cells, screen-space so the hatching runs across a whole region.

uniform vec4 stripe_color : source_color = vec4(0.878, 0.863, 0.706, 1.0);
uniform float stripe_width : hint_range(1.0, 64.0) = 10.0;
uniform float stripe_gap : hint_range(1.0, 64.0) = 22.0;

void fragment() {
	float band = mod(FRAGCOORD.x + FRAGCOORD.y, stripe_width + stripe_gap);
	COLOR = band < stripe_width ? stripe_color : COLOR;
}
