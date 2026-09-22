shader_type spatial;
render_mode cull_disabled;

uniform sampler2D asphalt : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 road_color : source_color = vec4(0.42, 0.37, 0.31, 1.0);
uniform float asphalt_size = 2.5;  // metres one tile of the grain covers
// The tile is nearly black end to end, so it MODULATES the road colour rather
// than multiplying it into tar. Measured, not eyeballed: source_color decodes
// the png from sRGB, so the average the shader sees is 0.015 - the 0.13 the
// pixels look like would darken the road to a quarter of its colour.
uniform float grain_mid : hint_range(0.001, 1.0) = 0.015;  // the tile's own average
uniform float grain_bite : hint_range(0.0, 1.0) = 0.35;  // share of its contrast taken

// The sand does not stop at the tarmac: it eats in from both shoulders and
// drifts across in patches. Both dissolve the road to nothing, so what shows
// is the REAL ground beneath - ripples, damp, tyre tracks and all - never a
// second guess at what colour the sand is.
uniform float sand_creep : hint_range(0.0, 1.0) = 0.22;  // share of the half width
uniform float sand_ragged : hint_range(0.0, 1.0) = 0.6;  // how much noise bends that
uniform float sand_edge : hint_range(0.01, 0.4) = 0.2;  // how sharp the sand line is
uniform float sand_patch : hint_range(0.0, 1.0) = 0.74;  // higher = fewer drifts across
uniform float drift_size = 3.0;  // metres across one tongue of sand
// The band is DITHERED into grains rather than faded: a soft alpha ramp reads
// as fog over the tarmac, where a stipple reads as sand scattering out over
// it. Each speck is all sand or all tarmac; the coverage decides how many.
uniform float dither : hint_range(0.0, 1.0) = 1.0;  // 0 = the old soft fade
uniform float speck_size = 0.04;  // metres across one grain of the scatter


// Mirrors sand_field.gdshader's noise: trig-free hash, quintic interpolation,
// each octave turned so no two lattices line up.
float hash(vec2 p_cell) {
	vec3 spread = fract(vec3(p_cell.xyx) * 0.1031);
	spread += dot(spread, spread.yzx + 33.33);
	return fract((spread.x + spread.y) * spread.z);
}


float value_noise(vec2 p_point) {
	vec2 cell = floor(p_point);
	vec2 f = fract(p_point);
	vec2 blend = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), blend.x),
			mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), blend.x),
			blend.y);
}


float turned_noise(vec2 p_point, float p_angle) {
	float c = cos(p_angle);
	float s = sin(p_angle);
	return value_noise(vec2(p_point.x * c - p_point.y * s,
			p_point.x * s + p_point.y * c));
}


float fractal_noise(vec2 p_point, float p_angle) {
	return turned_noise(p_point, p_angle) * 0.6
			+ turned_noise(p_point * 2.3 + 4.7, p_angle + 1.1) * 0.3
			+ turned_noise(p_point * 4.7 + 9.1, p_angle + 2.2) * 0.1;
}


void fragment() {
	vec2 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
	float grain = dot(texture(asphalt, world / asphalt_size).rgb, vec3(0.3333));
	ALBEDO = road_color.rgb * mix(1.0, grain / grain_mid, grain_bite);
	SPECULAR = 0.0;
	ROUGHNESS = 0.9;

	// UV.x runs across the ribbon whatever the road is doing, so the shoulders
	// are 0 and 1 however the curve pinches - which a world-space measure of
	// "how far from the middle" could never be.
	float shoulder = abs(UV.x - 0.5) * 2.0;
	float tide = fractal_noise(world / drift_size, 0.4);
	float bite = sand_creep * (1.0 - sand_ragged + tide * sand_ragged * 2.0);
	// A narrow band, not a proportional one: sand lies with an EDGE, and a
	// gradient the width of the bite reads as the tarmac fading out instead.
	float buried = smoothstep(1.0 - bite - sand_edge, 1.0 - bite + sand_edge,
			shoulder);
	// Tongues that make it right across, well inside the shoulders.
	float drift = fractal_noise(world / (drift_size * 0.55) + 31.7, 1.9);
	buried = max(buried, smoothstep(sand_patch, sand_patch + 0.05, drift));

	// Two speck sizes, or the scatter is one grade of gravel. Held back where
	// a pixel can no longer resolve a speck: past that the stipple is just
	// noise, and the soft fade it came from is the better answer.
	float speck = value_noise(world / speck_size) * 0.6
			+ value_noise(world / (speck_size * 0.45) + 17.3) * 0.4;
	float crisp = clamp(1.0 - fwidth(world.x) / speck_size, 0.0, 1.0);
	ALPHA = 1.0 - mix(buried, step(speck, buried), dither * crisp);
}
