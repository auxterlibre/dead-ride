shader_type spatial;
render_mode cull_disabled, shadows_disabled, depth_draw_never;
// Stylized fire: scrolling noise erodes a flame silhouette. NOT unshaded - that discards EMISSION.

uniform sampler2D noise_texture;  // seamless NoiseTexture2D
uniform float scroll_speed : hint_range(0.2, 4.0) = 1.4;
uniform float noise_scale : hint_range(0.5, 4.0) = 1.0;
uniform float erosion : hint_range(0.0, 1.0) = 0.5;  // how hard noise eats the flame
uniform float wobble : hint_range(0.0, 0.3) = 0.14;  // sideways licking sway
uniform float base_width : hint_range(0.2, 1.0) = 0.6;
uniform float softness : hint_range(0.01, 0.3) = 0.12;  // gradient/edge blur
uniform vec4 color_core : source_color = vec4(1.0, 0.97, 0.75, 1.0);
uniform vec4 color_mid : source_color = vec4(1.0, 0.62, 0.12, 1.0);
uniform vec4 color_outer : source_color = vec4(1.0, 0.28, 0.06, 1.0);
uniform float emission_strength : hint_range(0.0, 8.0) = 3.5;
// Ignition dial, per mesh instance: scaling the flame VALUE (not alpha)
// makes a low fade read as faint red wisps that grow into the full fire.
instance uniform float fade : hint_range(0.0, 1.0) = 1.0;


void vertex() {
	// Billboard toward the camera, preserving the node's scale.
	mat4 modelview = VIEW_MATRIX * mat4(
			INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2],
			MODEL_MATRIX[3]);
	modelview = modelview * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = modelview;
}


void fragment() {
	float height = 1.0 - UV.y;  // 0 at the flame base, 1 at the quad top
	// Two noise reads at different speeds; +TIME moves the pattern up, as quad UV.y grows downward.
	vec2 flow_uv = UV * noise_scale * vec2(1.0, 0.55);
	float noise_a = texture(noise_texture,
			flow_uv + vec2(0.0, TIME * scroll_speed * 0.55)).r;
	float noise_b = texture(noise_texture,
			flow_uv * 0.6 + vec2(0.37, TIME * scroll_speed * 0.34)).r;
	float noise = mix(noise_a, noise_b, 0.5);
	// The axis sways: a slow sine plus noise, growing toward the tip, so the
	// whole flame dances instead of standing like a cone.
	float sway = sin(TIME * 2.7 + height * 4.0) * 0.5 + (noise - 0.5);
	float x = UV.x + sway * wobble * height;
	float centered = abs(x - 0.5) * 2.0;
	// The flame body lives in the lower ~62%; the top of the quad belongs to the detached blobs.
	float body_h = clamp(height / 0.62, 0.0, 1.0);
	float bulge = mix(0.25, 1.05, body_h);
	float width = base_width * clamp(4.0 * bulge * (1.0 - bulge), 0.0, 1.0);
	// Radial falloff, deliberately NOT saturated, so the gradient nests.
	float body = clamp(1.0 - centered / max(width, 0.001), 0.0, 1.0);
	// Smoothstep turns the noise into coherent blobs, so erosion takes big
	// bites (licking tongues) instead of sanding the rim into speckle.
	float bite = smoothstep(0.35, 0.75, noise);
	// The base fades in over the first ~10% of height (noise-wobbled), so
	// the flame emerges from the surface instead of ending in a hard line.
	float base_fade = smoothstep(0.0, 0.1 + noise * 0.08, height);
	// Erosion weighted away from the axis, fading upward so the tip breaks into a ragged point.
	float flame = body * (1.0 - body_h * 0.55) * base_fade
			- bite * erosion * (0.4 + body_h * 1.1)
			* (1.0 - body * 0.32 * (1.0 - body_h * 0.8));
	// Detached blobs: a NARROW sparse column right off the tip, overlapping
	// the body top so there is no gap, fading before the quad edge.
	float blob_zone = smoothstep(0.42, 0.6, height)
			* (1.0 - smoothstep(0.8, 0.97, height));
	float blobs = smoothstep(0.65, 0.75, noise)
			* clamp(1.0 - centered * 3.0, 0.0, 1.0) * blob_zone;
	flame = max(flame, blobs * 0.3);
	flame *= fade;
	// Smooth gradient: outer -> mid -> core, soft-edged like the reference
	// (the old hard toon bands read as a flat cutout).
	vec3 color = mix(color_outer.rgb, color_mid.rgb,
			smoothstep(0.16, 0.16 + softness * 2.0, flame));
	color = mix(color, color_core.rgb,
			smoothstep(0.42, 0.42 + softness * 2.0, flame - body_h * 0.2));
	// Bright rims around the eroded pockets and silhouette, like the
	// reference's glowing cell edges.
	float rim = smoothstep(0.02, 0.1, flame) * (1.0 - smoothstep(0.12, 0.3, flame));
	color += color_mid.rgb * rim * 0.5;
	ALBEDO = vec3(0.0);
	SPECULAR = 0.0;
	ROUGHNESS = 1.0;
	EMISSION = color * emission_strength;
	// Soft translucent edge instead of a hard cutout - the glow halo comes
	// from emission + WorldEnvironment glow.
	ALPHA = smoothstep(0.0, softness, flame);
}
