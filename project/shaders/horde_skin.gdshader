shader_type spatial;
render_mode cull_disabled;

uniform sampler2D albedo : source_color, filter_linear_mipmap;
uniform sampler2D bones : filter_nearest, repeat_disable;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.72;
uniform vec3 hit_color : source_color = vec3(1.0, 0.25, 0.1);

varying float hit_flash;

mat4 bone_matrix(int bone, int frame) {
	vec4 r0 = texelFetch(bones, ivec2(bone * 3, frame), 0);
	vec4 r1 = texelFetch(bones, ivec2(bone * 3 + 1, frame), 0);
	vec4 r2 = texelFetch(bones, ivec2(bone * 3 + 2, frame), 0);
	return mat4(
		vec4(r0.x, r1.x, r2.x, 0.0),
		vec4(r0.y, r1.y, r2.y, 0.0),
		vec4(r0.z, r1.z, r2.z, 0.0),
		vec4(r0.w, r1.w, r2.w, 1.0));
}

void vertex() {
	int frame = int(INSTANCE_CUSTOM.x + 0.5);
	hit_flash = INSTANCE_CUSTOM.y;
	mat4 skin = bone_matrix(int(BONE_INDICES.x), frame) * BONE_WEIGHTS.x
			+ bone_matrix(int(BONE_INDICES.y), frame) * BONE_WEIGHTS.y
			+ bone_matrix(int(BONE_INDICES.z), frame) * BONE_WEIGHTS.z
			+ bone_matrix(int(BONE_INDICES.w), frame) * BONE_WEIGHTS.w;
	VERTEX = (skin * vec4(VERTEX, 1.0)).xyz;
	NORMAL = normalize(mat3(skin) * NORMAL);
}

void fragment() {
	vec3 base = texture(albedo, UV).rgb;
	ALBEDO = mix(base, hit_color, clamp(hit_flash, 0.0, 1.0));
	ROUGHNESS = roughness_value;
}
