shader_type fog;

uniform sampler2D noise_tex : repeat_enable;
uniform sampler2D grad_tex;  // sampled by wave strength
uniform vec3 emission_color : source_color;
uniform vec2 wind_dir = vec2(0.0, -1.0);
uniform float drift = 0.0;  // metres travelled, accumulated by the script
uniform float stretch = 0.02;  // cycles/m ALONG the wind - low, so waves run long
uniform float across = 0.14;  // cycles/m across it: how far apart the waves sit
uniform float warp = 0.5;  // how much a wave snakes instead of running straight
uniform float coverage : hint_range(0.0, 1.0) = 0.35;  // share of ground under sand
uniform float softness : hint_range(0.01, 1.0) = 0.3;  // wave edge feather
uniform float flatness : hint_range(0.1, 20.0) = 2.0;  // higher = shallower layer
uniform float density : hint_range(0.0, 6.0, 0.0001) = 1.0;


void fog() {
	// Into wind space, then sampled with DIFFERENT scales along and across it.
	// An isotropic sample gives round blobs - a bank of smoke, not waves.
	vec2 p = WORLD_POSITION.xz;
	vec2 side = vec2(-wind_dir.y, wind_dir.x);
	vec2 uv = vec2(dot(p, wind_dir) - drift, dot(p, side));
	// The coarse sample bends the fine one, so waves snake rather than stripe.
	float bend = texture(noise_tex, vec2(uv.x * stretch * 0.5,
			uv.y * across * 0.5)).r - 0.5;
	float band = texture(noise_tex, vec2(uv.x * stretch,
			uv.y * across + bend * warp)).r;
	// Thresholded, so waves are separated by clear air instead of an even wash.
	float wave = smoothstep(1.0 - coverage, 1.0 - coverage + softness, band);
	// Full at the volume's floor, gone by UVW.y = 1/flatness. Not mix() with an
	// unclamped factor - that extrapolates negative and deletes the layer.
	DENSITY = wave * (1.0 - clamp(UVW.y * flatness, 0.0, 1.0));
	DENSITY *= step(0.0, -SDF) * density;
	ALBEDO = texture(grad_tex, vec2(wave, 0.5)).rgb;
	EMISSION = emission_color;
}
