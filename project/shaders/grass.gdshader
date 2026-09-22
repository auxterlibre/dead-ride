shader_type spatial;
render_mode cull_disabled;

const float TURN = 6.2831853;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
// Fed by GrassField off Globals.wind, named as the sand shader names them.
uniform vec2 wind_direction = vec2(0.0, -1.0);
uniform float wind_strength = 1.5;  // m/s
uniform vec2 wind_path = vec2(0.0);  // metres the air has travelled
uniform float sway_length = 3.5;  // metres between crests, along the wind
uniform float sway_lean = 0.035;  // m the tip leans per m/s of wind
uniform float sway_flutter : hint_range(0.0, 1.0) = 0.55;  // share of the lean that breathes
uniform float tuft_height = 0.8;  // m of blade the bend is measured against


void vertex() {
	// Y-billboard, scale kept: a one-sided plane has to face the camera, and
	// the instance scale IS the tuft's growth.
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), MAIN_CAM_INV_VIEW_MATRIX[2].xyz));
	vec3 ahead = normalize(cross(MAIN_CAM_INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0)));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right, 0.0), vec4(0.0, 1.0, 0.0, 0.0),
			vec4(ahead, 0.0), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);

	vec2 flow = normalize(wind_direction);
	// The crest marches with the air's TRAVEL, never TIME: a gust changes how
	// fast wind_path grows, where TIME would jump the phase instead.
	float crest = (dot(wind_path, flow) - dot(MODEL_MATRIX[3].xz, flow)) / sway_length;
	float breath = mix(1.0, sin(crest * TURN) * 0.5 + 0.5, sway_flutter);
	// Rooted: the base holds and the tip carries the bend.
	float blade = clamp(VERTEX.y / tuft_height, 0.0, 1.0);
	blade *= blade;
	// Leaning happens in world space, but the quad only has screen-right to
	// lean along - so a wind blowing across the view bends them most.
	float lean = sway_lean * wind_strength * breath * blade;
	VERTEX.x += lean * dot(right.xz, flow);
	VERTEX.y -= abs(lean) * 0.25;
}


void fragment() {
	ALBEDO = texture(albedo_texture, UV).rgb;
	SPECULAR = 0.0;
	ROUGHNESS = 1.0;
}
