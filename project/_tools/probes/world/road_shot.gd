extends ProbeBase
# DBG shot (windowed): the tarmac's grain, and the sand eating its shoulders.

@onready var GAME: PackedScene = load("uid://b56i3a2diovj6")  # scenes/game.tscn


func _ready():
	if not windowed("the road surface"):
		finish()
		return
	var game: Node = GAME.instantiate()
	add_child(game)
	await settle(8)
	var roads: RoadNetwork = game.find_child("Roads", true, false)
	if not check(roads != null and roads.surface.mesh != null,
			"the map lays a road to look at", str(roads)):
		finish()
		return

	# Stand the player on the tarmac so the camera frames it.
	var player: Character = InputManager.player
	player.aim.process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = roads.nearest_center(player.global_position)
	await settle(40)
	var material: ShaderMaterial = roads.surface.material_override
	if not check(material != null and material.shader != null,
			"and it wears the road shader", str(material)):
		finish()
		return

	# Held still first: nothing about this shader moves, so traffic driving
	# through the frame is pure noise against a toggle worth 0.005 - and it
	# swamped the grain check at a creep of 0.013 before the pause went in.
	get_tree().paused = true
	await settle(4)
	var creep: float = await idle_floor()
	var invaded: Image = await capture()
	save_shot(invaded, "road_invaded")

	# "Less blurry" is countable: a dithered edge is grains that are either sand
	# or tarmac, so it leaves far fewer pixels stranded half way between the two
	# than a soft alpha ramp does.
	material.set_shader_parameter("dither", 0.0)
	await settle(4)
	var faded: Image = await capture()
	save_shot(faded, "road_faded")
	check(grit(invaded, faded) > grit(faded, invaded) * 1.5,
			"the sand scatters as grains, not as a blur",
			"%.4f jitter along the edge, against %.4f faded"
			% [grit(invaded, faded), grit(faded, invaded)])
	material.set_shader_parameter("dither", 1.0)
	await settle(4)

	# Pull the sand back and the same tarmac has to change: hard shoulders,
	# no drifts. A road that looked identical either way would not be blending.
	material.set_shader_parameter("sand_creep", 0.0)
	material.set_shader_parameter("sand_patch", 1.1)
	await settle(4)
	var bare: Image = await capture()
	check(frame_diff(invaded, bare, 4) > maxf(creep * 4.0, 0.0004),
			"the sand takes a real bite out of the tarmac",
			"%.5f over %.5f creep" % [frame_diff(invaded, bare, 4), creep])
	save_shot(bare, "road_bare")

	# The grain is the texture, not the flat colour it used to be.
	material.set_shader_parameter("grain_bite", 0.0)
	await settle(4)
	var flat: Image = await capture()
	check(frame_diff(bare, flat, 4) > maxf(creep * 2.0, 0.0002),
			"and the asphalt grain is really being sampled",
			"%.5f over %.5f creep" % [frame_diff(bare, flat, 4), creep])
	get_tree().paused = false
	finish()


# How much p_frame jitters pixel-to-pixel WHERE THE TWO FRAMES DISAGREE - which
# is the transition zone and nothing else, so no colour threshold has to be
# guessed at. Grains alternate against their neighbours; a ramp slides past
# them. Both frames are measured over the same mask, so the ground's own grain
# is charged to each equally.
func grit(p_frame: Image, p_other: Image) -> float:
	var total: float = 0.0
	var hits: int = 0
	for y in range(1, p_frame.get_height() - 1, 2):
		for x in range(1, p_frame.get_width() - 1, 2):
			var here: Color = p_frame.get_pixel(x, y)
			if apart(here, p_other.get_pixel(x, y)) < 0.02:
				continue
			total += apart(here, p_frame.get_pixel(x + 1, y)) \
					+ apart(here, p_frame.get_pixel(x, y + 1))
			hits += 1
	return total / float(maxi(hits, 1))


func apart(p_a: Color, p_b: Color) -> float:
	return absf(p_a.r - p_b.r) + absf(p_a.g - p_b.g) + absf(p_a.b - p_b.b)
