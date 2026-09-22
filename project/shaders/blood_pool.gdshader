shader_type spatial;
// Adapted from "Bloody Pool!" by dip (godotshaders.com/shader/bloody-pool-smooth-blood-trail, MIT):
// stripped to a transparent overlay (the original replaces the floor material),
// and the per-drop threshold loop folded into one check.

// Must match BloodPool.MAX_DROPS.
const int MAX_DROPS = 32;

uniform sampler2D drop_texture: repeat_disable, filter_linear;
uniform vec3 blood_color: source_color = vec3(0.36, 0.03, 0.03);
uniform float blood_alpha: hint_range(0.0, 1.0) = 0.9;
// The product of drop samples below this is blood; the band under it is where
// neighbouring drops bridge (coalescence), so it sets size AND merge reach.
uniform float merge_factor: hint_range(0.0, 1.0) = 0.35;
uniform float edge_softness: hint_range(0.0, 0.2) = 0.03;
// Darkens where drops stack, so a pool's heart reads thicker than its rim.
uniform float depth_shade: hint_range(0.0, 1.0) = 0.45;
uniform vec2 positions[MAX_DROPS];
uniform float scales[MAX_DROPS];


vec2 scale_from_center(vec2 p_uv, float p_scale) {
	return (p_uv - 0.5) / p_scale + 0.5;
}


void fragment() {
	float blended = 1.0;
	for (int i = 0; i < MAX_DROPS; i++) {
		if (scales[i] <= 0.01) {
			continue;
		}
		vec2 drop_uv = scale_from_center(UV - positions[i] + 0.5, scales[i]);
		blended *= texture(drop_texture, drop_uv).r;
	}
	float blood = 1.0 - smoothstep(merge_factor - edge_softness, merge_factor, blended);
	float thickness = 1.0 - smoothstep(0.0, merge_factor, blended);
	ALBEDO = blood_color * (1.0 - depth_shade * thickness);
	ROUGHNESS = 0.08;
	ALPHA = blood * blood_alpha;
}
