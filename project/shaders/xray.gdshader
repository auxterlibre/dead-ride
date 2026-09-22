// Drawn only where the depth test fails; vertices pull forward so the body never occludes itself.
shader_type spatial;
render_mode unshaded, depth_test_inverted, cull_back;

uniform vec4 color : source_color = vec4(0.35, 0.8, 1.0, 1.0);
uniform float glow_strength : hint_range(0.0, 8.0) = 2.5;
uniform float fresnel_power : hint_range(0.5, 8.0) = 2.5;
// Above the character's own view-axis thickness, below a wall's.
uniform float occlusion_bias : hint_range(0.0, 3.0) = 1.2;  // meters

void vertex() {
	vec3 toward_camera = normalize(inverse(mat3(MODELVIEW_MATRIX)) * vec3(0.0, 0.0, 1.0));
	VERTEX += toward_camera * occlusion_bias;
}

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);
	// Solid, not translucent: overlapping bone meshes would stack alpha and bloom where they cross.
	ALBEDO = color.rgb * glow_strength * (0.35 + 0.65 * fresnel);
	ALPHA = color.a;
}
