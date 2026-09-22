// Darkness becomes alpha and the cracks glow. Lit path - unshaded would discard EMISSION.
shader_type spatial;
render_mode cull_disabled, shadows_disabled, depth_draw_never;

uniform sampler2D marks:source_color;
uniform vec2 uv_offset = vec2(0.0);
uniform float opacity:hint_range(0.0, 1.0) = 1.0;
uniform float glow:hint_range(0.0, 1.0) = 1.0;
uniform vec3 glow_color:source_color = vec3(3.0, 0.9, 0.2);

void fragment() {
	float mask = 1.0 - texture(marks, UV * 0.25 + uv_offset).r;
	ALBEDO = vec3(0.02);
	SPECULAR = 0.0;
	ROUGHNESS = 1.0;
	EMISSION = glow_color * pow(mask, 2.0) * glow;
	ALPHA = mask * opacity;
}
