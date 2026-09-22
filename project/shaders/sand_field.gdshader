shader_type spatial;

uniform sampler2D trail_tex : hint_default_black;
uniform vec4 sand_color : source_color = vec4(0.902, 0.639, 0.212, 1.0);
uniform vec4 rut_color : source_color = vec4(0.6, 0.4, 0.13, 1.0);
uniform float ditch_depth = 0.14;
// Must match the trail camera's ortho size, or ruts sit where nothing drove.
uniform float world_size = 60.0;
uniform vec2 trail_origin = vec2(0.0);  // world xz the trail camera is centred on
uniform float rim_lift = 0.35;  // share of the depth thrown up as a lip
// Master dial: scales tint, trench and shading together. See CLAUDE.md.
uniform float rut_strength : hint_range(0.0, 1.0) = 1.0;

// WIND INPUTS, written per frame by whoever owns the weather (the probe; the
// game later). All motion keys off wind_path - the air's accumulated travel in
// metres - never TIME: TIME times a varying strength jumps the phase per gust.
uniform vec2 wind_direction = vec2(0.0, -1.0);
// Never sampled here: the material-side store SandField integrates wind_path
// from when follow_wind is off (the probes' authored-wind tuning mode).
uniform float wind_strength = 1.5;  // m/s
uniform float wind_gust : hint_range(0.0, 1.0) = 0.5;  // Wind.gust: 0 lull, 1 peak
uniform vec2 wind_path = vec2(0.0);

// The ripple BED: quasi-static relief. Real ripples migrate over minutes, so
// the drift share is tiny - the wind read comes from the streamers instead.
uniform float ripple_height = 0.02;  // metres of apparent relief; 0 = flat
uniform float ripple_length = 2.8;  // metres between crests, along the wind
uniform float ripple_spread = 6.0;  // metres of crest before it bends; higher = straighter
uniform float ripple_drift : hint_range(0.0, 1.0) = 0.03;  // share of wind travel
uniform vec4 ripple_color : source_color = vec4(0.78, 0.53, 0.18, 1.0);
uniform float ripple_tint : hint_range(0.0, 1.0) = 0.0;  // colour in the troughs
// Both at 0 give back one clean sine everywhere, which is the uniform look.
uniform float ripple_variation : hint_range(0.0, 1.0) = 0.7;  // scoured patches between ripple beds
uniform float ripple_patch = 14.0;  // metres across one of those patches
uniform float ripple_chaos : hint_range(0.0, 2.0) = 0.8;  // local stretch and squeeze

// GRAIN: the sand's own tooth. STATIC in world space - this is the ground
// itself and not weather, so it takes no wind and no time - and it rides on
// top of the ripple relief rather than replacing it.
uniform float grain_size = 0.12;  // metres across one speck
uniform float grain_relief : hint_range(0.0, 1.0) = 0.12;  // how much the sun catches it
uniform float grain_tint : hint_range(0.0, 1.0) = 0.12;  // how much it dapples the colour
// TONE: the slow sweep that stops a hundred metres of flat reading as one
// poured colour. Far bigger than a ripple patch, far weaker than a chill spot.
uniform float tone_size = 18.0;  // metres across one lighter or darker sweep
uniform float tone_depth : hint_range(0.0, 1.0) = 0.1;

// STREAMERS - aeolian "sand snakes": sparse pale streams racing along the wind
// at a third of its speed, forking and merging, flooding in with a gust and
// draining away in the lull. This layer, not the bed, is what reads as WIND.
uniform float streamer_strength : hint_range(0.0, 1.0) = 0.3;  // 0 = off
uniform float streamer_length = 9.0;  // metres a snake stretches along the wind
uniform float streamer_gap = 1.2;  // metres between snakes, across it
uniform float streamer_speed : hint_range(0.0, 1.0) = 0.4;  // share of wind speed
// How fast the snake PATTERN advances, as a share of streamer speed - the sand
// always races at full speed through it. Low = planted lanes the sand runs
// along; high = the shapes themselves sweep downwind. Swapping length and gap
// turns the snakes SIDEWAYS (long across the wind): with a high march that is
// the wave-front look, bands of sand rolling downwind.
uniform float streamer_march : hint_range(0.0, 1.0) = 0.15;
uniform vec4 streamer_color : source_color = vec4(0.97, 0.75, 0.31, 1.0);

// CHILL SPOTS: coolant objects damp the sand around them. Written by
// SandField from the chill_source group. One vec4 carries everything on the
// flat ground: x,z world position, y strength, w pocket radius - no count
// uniform, unused slots sit at strength zero and contribute nothing.
uniform vec4 chill_spots[8];
// Multiplied in, so what matters is which channel is darkened MOST: taking
// BLUE down deepens the sand's own orange the way water does, while taking
// red down (the intuitive "cool it") only greys it into ash. A whisper of
// cool survives in the margin; the cold is the haze and the label's job.
uniform vec4 chill_color : source_color = vec4(0.88, 0.86, 0.84, 1.0);  // the damp margin
uniform vec4 chill_deep : source_color = vec4(0.62, 0.52, 0.44, 1.0);  // the soaked core
uniform float chill_core : hint_range(0.0, 1.0) = 0.35;  // full-tint share of the radius
// The rim WANDERS and the inside is blotchy: moisture wicks through sand, it
// does not stop on a drawn circle. Both share one noise field, so overlapping
// pockets soak into the same blotches instead of each printing its own ring.
uniform float chill_edge : hint_range(0.0, 1.0) = 0.45;  // rim wander, share of the radius
uniform float chill_patch = 5.0;  // metres across one damp blotch
uniform float chill_mottle : hint_range(0.0, 1.0) = 0.4;  // damp-to-damper variation
// NO SHEEN, and it is not a tuning question: Godot builds VIEW from the
// view-space position, so under an ORTHO camera it still radiates from a
// point and parks the specular hotspot at a fixed offset from the CAMERA.
// CameraFollow tracks the player, so a glossy patch grows a bright spot that
// walks with him - visible only on damp ground, since dry sand has none.
// The wet read is colour and blotching; ROUGHNESS/SPECULAR stay constant.
// Damp sand does not drift: moisture cohesion pins the grains flat.
uniform float chill_calm : hint_range(0.0, 1.0) = 0.85;

varying vec2 trail_uv;
varying vec2 world_xz;

float rut_at(vec2 p_uv) {
	return texture(trail_tex, p_uv).r * rut_strength;
}

// Trig-free: this runs several times per pixel over the whole ground, and a
// sin-based hash is both slower and worse distributed at these coordinates.
float hash(vec2 p_cell) {
	vec3 spread = fract(vec3(p_cell.xyx) * 0.1031);
	spread += dot(spread, spread.yzx + 33.33);
	return fract((spread.x + spread.y) * spread.z);
}

// Quintic, not smoothstep: this feeds a NORMAL, and smoothstep's second
// derivative jumps at the cell edges, which prints the lattice as flat blocks.
float value_noise(vec2 p_point) {
	vec2 cell = floor(p_point);
	vec2 f = fract(p_point);
	vec2 blend = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), blend.x),
			mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), blend.x),
			blend.y);
}

// Value AND slope from ONE lattice fetch (x = speck, yz = world-axis gradient):
// three taps would cost 12 hashes a pixel to estimate what the quintic knows.
vec3 speck_at(vec2 p_point, float p_angle) {
	float turn_c = cos(p_angle);
	float turn_s = sin(p_angle);
	vec2 turned = vec2(p_point.x * turn_c - p_point.y * turn_s,
			p_point.x * turn_s + p_point.y * turn_c);
	vec2 cell = floor(turned);
	vec2 f = fract(turned);
	float h00 = hash(cell);
	float h10 = hash(cell + vec2(1.0, 0.0));
	float h01 = hash(cell + vec2(0.0, 1.0));
	float h11 = hash(cell + vec2(1.0, 1.0));
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	vec2 du = 30.0 * f * f * (f - 1.0) * (f - 1.0);
	float corner = h00 - h10 - h01 + h11;
	vec2 slope = vec2(((h10 - h00) + corner * u.y) * du.x,
			((h01 - h00) + corner * u.x) * du.y);
	// The lattice was turned to sample it, so its slope turns back.
	return vec3(h00 + (h10 - h00) * u.x + (h01 - h00) * u.y + corner * u.x * u.y,
			slope.x * turn_c + slope.y * turn_s,
			-slope.x * turn_s + slope.y * turn_c);
}


// Each field gets its own lattice angle, or they line up and the shared grid
// shows through as rectangles however smooth the interpolation is.
float turned_noise(vec2 p_point, float p_angle) {
	float c = cos(p_angle);
	float s = sin(p_angle);
	return value_noise(vec2(p_point.x * c - p_point.y * s,
			p_point.x * s + p_point.y * c));
}

// One octave at patch scale is only two or three cells across the view, which
// reads as blocks no matter how smoothly it interpolates. Octave frequencies
// are non-integer and each is turned again, so no two lattices line up.
float fractal_noise(vec2 p_point, float p_angle) {
	return turned_noise(p_point, p_angle) * 0.6
			+ turned_noise(p_point * 2.3 + 4.7, p_angle + 1.1) * 0.3
			+ turned_noise(p_point * 4.7 + 9.1, p_angle + 2.2) * 0.1;
}

// Crests run ACROSS the wind and creep along it. The wobble bends them so
// they meander like sand instead of ruling straight lines over the whole map.
// Returns xy = ground slope, z = crest height (-1 trough .. 1 crest).
vec3 ripple_at(vec2 p_world, vec2 p_along, vec2 p_across) {
	float wave = TAU / max(ripple_length, 0.05);
	vec2 creep = wind_path * ripple_drift;
	float patch_size = max(ripple_patch, 0.5);
	// TWO fields at different speeds, so the bed evolves as it migrates rather
	// than sliding across the map in one rigid sheet. Their product is skewed
	// low, which is what leaves broad scoured stretches between the beds.
	float bed = fractal_noise((p_world - creep * 0.25) / patch_size, 0.7)
			* turned_noise((p_world - creep * 0.6) / patch_size + 11.3, 2.3);
	// Smooth remap, not a clamp: a clamp flattens whole regions to exactly zero
	// and prints the boundary as a hard edge.
	float amplitude = mix(1.0, smoothstep(0.04, 0.5, bed), ripple_variation);
	// Local stretch and squeeze: this is what makes crests fork and die out
	// instead of running the whole field at one wavelength.
	float jitter = (fractal_noise(p_world / (patch_size * 0.4), 1.4) - 0.5)
			* ripple_chaos * TAU;
	float bend = dot(p_world, p_across) / max(ripple_spread, 0.5);
	float wobble = sin(bend * 1.9) * 1.7 + sin(bend * 0.8 + 2.1) * 2.6;
	float phase = dot(p_world - creep, p_along) * wave + wobble + jitter;
	return vec3(p_along * cos(phase) * ripple_height * wave * amplitude,
			sin(phase) * amplitude);
}

// Long narrow noise cells advected downwind. The product of two stretches
// makes snakes that merge and fork instead of parallel stripes; the gust
// moves the threshold, so saltation is intermittent the way the real thing is.
float streamers_at(vec2 p_world, vec2 p_along, vec2 p_across) {
	// LANES and PULSES at different speeds. One shared speed slides the whole
	// pattern as a printed sheet; splitting them makes sand RUN THROUGH shapes
	// that move at their own pace - which is also how the real thing moves.
	vec2 lane_head = p_world - wind_path * streamer_speed * streamer_march;
	vec2 coord = vec2(dot(lane_head, p_along) / max(streamer_length, 0.5),
			dot(lane_head, p_across) / max(streamer_gap, 0.2));
	// Meander before anything else: the stretched lattice is axis-aligned in
	// wind space, and unwarped filaments jog along it in right angles.
	coord.y += (value_noise(coord * vec2(0.6, 0.25) + 8.2) - 0.5) * 1.6;
	// RIDGE noise, not the noise itself: its peaks are connected meandering
	// filaments that fork and merge - the streamer morphology - where a plain
	// threshold gives smeared patches.
	float ridge = 1.0 - abs(2.0 * value_noise(coord) - 1.0);
	// The sand itself: pulses racing down the lane at full streamer speed, so
	// a snake is born, runs and dies instead of translating rigidly.
	float pulse_u = dot(p_world - wind_path * streamer_speed, p_along)
			/ max(streamer_length, 0.5);
	float flow = value_noise(vec2(pulse_u * 1.7, coord.y * 0.9) + 3.3);
	float snake = ridge * (0.25 + 0.75 * flow);
	// A gust brings more snakes; even the peak leaves most of the ground bare.
	float cut = mix(0.82, 0.68, wind_gust);
	// Each snake at its own brightness, or a still reads as a flat stencil.
	return smoothstep(cut, cut + 0.08, snake) * (0.4 + 0.6 * flow);
}

float chill_at(vec2 p_world) {
	// Cheap rejection first, over the widest the rim could ever wander: this
	// runs on every pixel of a 120m floor and almost none of it is near a
	// pocket, so the six noise octaves below should not be paid for out there.
	float near = 0.0;
	for (int i = 0; i < 8; i++) {
		float bound = max(chill_spots[i].w, 0.1) * (1.0 + chill_edge);
		near = max(near, chill_spots[i].y
				* step(distance(p_world, chill_spots[i].xz), bound));
	}
	if (near <= 0.0) {
		return 0.0;
	}
	// Sampled once for the whole ground: the wander belongs to the SAND, not
	// to any one pocket. Own lattice angles, or the two fields print a grid.
	float grain = fractal_noise(p_world / max(chill_patch, 0.5), 0.35);
	float mottle = fractal_noise(p_world / max(chill_patch * 0.8, 0.5), 1.9);
	float total = 0.0;
	for (int i = 0; i < 8; i++) {
		float reach = max(chill_spots[i].w, 0.1);
		// Pushing the SAMPLED DISTANCE around, not the threshold: the rim
		// fingers in and out and the blotches stay put as a pocket grows.
		float wander = (grain - 0.5) * chill_edge * reach;
		total += chill_spots[i].y * (1.0 - smoothstep(reach * chill_core,
				reach, distance(p_world, chill_spots[i].xz) + wander));
	}
	// Nothing is uniformly soaked. At chill_mottle 0 this is exactly the old
	// flat disc, so the whole look can be dialled back out.
	return clamp(total, 0.0, 1.0)
			* mix(1.0, smoothstep(0.15, 0.85, mottle), chill_mottle);
}

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	trail_uv = (world_xz - trail_origin) / world_size + 0.5;
	VERTEX.y -= rut_at(trail_uv) * ditch_depth;
}

void fragment() {
	// Per PIXEL, not interpolated: the colour is not bound by the subdivision.
	float rut = rut_at(trail_uv);
	// Normals off the gradient; flat-shaded, a rut reads as a stain not a hollow.
	// Here rather than in vertex(), so the shading is not stepped by the mesh.
	float texel = 1.0 / float(textureSize(trail_tex, 0).x);
	float left = rut_at(trail_uv - vec2(texel, 0.0));
	float right = rut_at(trail_uv + vec2(texel, 0.0));
	float back = rut_at(trail_uv - vec2(0.0, texel));
	float front = rut_at(trail_uv + vec2(0.0, texel));
	float metres = world_size * texel;
	vec3 normal = normalize(vec3((left - right) * ditch_depth, 2.0 * metres,
			(back - front) * ditch_depth));
	vec2 along = normalize(wind_direction);
	vec2 across = vec2(-along.y, along.x);
	float chill = chill_at(world_xz);
	// Flattened inside a rut (a wheel has just turned that sand over) and
	// stilled by damp ground, which the wind cannot lift into ripples.
	vec3 ripple = ripple_at(world_xz, along, across) * (1.0 - rut)
			* (1.0 - chill * chill_calm);
	normal = normalize(vec3(normal.x - ripple.x, normal.y, normal.z - ripple.y));
	// The tooth. The speck carries its own SLOPE so the sun catches it - a
	// colour dapple alone reads as dirt on a flat plane - and it fades out
	// once a pixel covers more than a speck, or the far sand boils.
	// Two lattices, turned differently: one alone still reads as a weave.
	vec3 speck = speck_at(world_xz / grain_size, 0.9) * 0.65
			+ speck_at(world_xz / (grain_size * 0.47) + 5.3, 2.4) * 0.35;
	float legible = clamp(1.0 - fwidth(world_xz.x) / grain_size, 0.0, 1.0);
	float bite = grain_relief * legible;
	normal.x -= speck.y * bite;
	normal.z -= speck.z * bite;
	normal = normalize(normal);
	NORMAL = normalize((VIEW_MATRIX * vec4(normal, 0.0)).xyz);

	// The paler lip; without it the track is a flat smear painted on the sand.
	float lip = clamp(fwidth(rut) * 6.0, 0.0, 1.0) * rim_lift;
	vec3 base = mix(sand_color.rgb, rut_color.rgb, rut);
	// Troughs only, so the sand keeps its own colour at the crests. Independent
	// of the relief: either can be zeroed on its own.
	base = mix(base, ripple_color.rgb,
			ripple_tint * clamp(-ripple.z, 0.0, 1.0));
	// Two tints: the margin is barely damp, the core is soaked dark and
	// richer - one colour scaled by intensity cannot say both.
	base *= mix(vec3(1.0), mix(chill_color.rgb, chill_deep.rgb, chill), chill);
	// Streamers run OVER the ruts, but damp ground pins the snakes: saltation
	// dies where the sand is cold.
	base = mix(base, streamer_color.rgb,
			streamers_at(world_xz, along, across) * streamer_strength
			* (1.0 - chill * 0.8));
	// Both multiply the finished colour, so ruts, damp and snakes keep theirs
	// and only the flat between them stops being flat.
	base *= 1.0 + (speck.x - 0.5) * grain_tint * legible;
	base *= 1.0 + (fractal_noise(world_xz / tone_size, 2.9) - 0.5) * tone_depth;
	ALBEDO = mix(base, sand_color.rgb * 1.15, lip);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
