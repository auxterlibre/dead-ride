extends ProbeBase
# DBG shot (windowed): the sand's grain and its slow tone, toggled off the
# same frame they were measured on.

@onready var GAME: PackedScene = load("uid://b56i3a2diovj6")  # scenes/game.tscn


func _ready():
	if not windowed("the sand surface"):
		finish()
		return
	var game: Node = GAME.instantiate()
	add_child(game)
	await settle(30)  # the camera glides in behind the player
	var field: Node = find_first(game, "SandField")
	if not check(field != null and field.sand != null,
			"the map lays sand to look at", str(field)):
		finish()
		return
	var sand: ShaderMaterial = field.sand

	# Held still: the ripples and streamers ride wind_path, and traffic drives
	# through - none of it belongs in a measurement of the ground's tooth.
	get_tree().paused = true
	await settle(4)
	var creep: float = await idle_floor()
	var grained: Image = await capture()
	save_shot(grained, "sand_grained")

	sand.set_shader_parameter("grain_relief", 0.0)
	sand.set_shader_parameter("grain_tint", 0.0)
	await settle(4)
	var smooth: Image = await capture()
	check(frame_diff(grained, smooth, 4) > maxf(creep * 4.0, 0.0002),
			"the grain gives the sand a tooth",
			"%.5f over %.5f creep" % [frame_diff(grained, smooth, 4), creep])

	sand.set_shader_parameter("tone_depth", 0.0)
	await settle(4)
	var flat: Image = await capture()
	check(frame_diff(smooth, flat, 4) > maxf(creep * 2.0, 0.0001),
			"and the slow tone stops the flats pouring one colour",
			"%.5f over %.5f creep" % [frame_diff(smooth, flat, 4), creep])
	save_shot(flat, "sand_flat")

	# The ground fills the screen at 4K, so the tooth owes an answer about the
	# frame too. ALTERNATED and measured last: a capture reads the framebuffer
	# back and stalls the frames after it, which is enough on its own to make
	# whichever setting was measured first look the expensive one.
	sand.set_shader_parameter("tone_depth", 0.1)
	var view: RID = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(view, true)
	await settle(30)  # let the readback stall drain out before anything counts
	var bare: PackedFloat32Array = PackedFloat32Array()
	var toothed: PackedFloat32Array = PackedFloat32Array()
	for round in 2:
		sand.set_shader_parameter("grain_relief", 0.0)
		sand.set_shader_parameter("grain_tint", 0.0)
		bare.append(await gpu_ms(view, 30))
		sand.set_shader_parameter("grain_relief", 0.12)
		sand.set_shader_parameter("grain_tint", 0.12)
		toothed.append(await gpu_ms(view, 30))
	# Against the instrument's OWN spread, not a number picked by hand: the
	# same setting measured twice drifts by tenths of a ms on this GPU, so a
	# fixed bar would be reporting the weather.
	var cost: float = (toothed[0] + toothed[1] - bare[0] - bare[1]) * 0.5
	var spread: float = absf(bare[0] - bare[1]) + absf(toothed[0] - toothed[1])
	check(cost <= maxf(spread, 0.2), "and the tooth costs no more than the noise",
			"%.2fms against a %.2fms spread (bare %.2f/%.2f, toothed %.2f/%.2f)"
			% [cost, spread, bare[0], bare[1], toothed[0], toothed[1]])
	get_tree().paused = false
	finish()


func gpu_ms(p_view: RID, p_frames: int) -> float:
	var total: float = 0.0
	for i in p_frames:
		await settle(1)
		total += RenderingServer.viewport_get_measured_render_time_gpu(p_view)
	return total / float(p_frames)
