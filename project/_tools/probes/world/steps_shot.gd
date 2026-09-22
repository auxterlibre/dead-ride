extends ProbeBase
# WINDOWED look check for footprints: stamps a line of prints on open sand in
# front of the pinned camera, then diffs the same frame with the stamp buffer
# cleared - the difference IS the prints. The wiring lives in footprint_probe;
# this is the proof the sand actually shows them.


func _ready():
	if not windowed("the sand footprints"):
		finish()
		return
	var game: Node = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await settle(10)
	var player: Character = InputManager.player
	var steps: CharacterFootsteps = null
	for child in player.get_children():
		if child is CharacterFootsteps:
			steps = child
	# HOLD THE WHOLE OBSERVATION STILL. The first cut of this shot PASSED on
	# pure drift while the prints never rendered at all (the stamp scene
	# shipped visible=false): the sand rides wind_path, the eased camera
	# never truly stops (a sub-pixel pan touches every edge pixel), and the
	# idling body breathes. Camera onto a dead anchor then frozen, the body
	# parked out of frame, the field's wiring off - what remains between two
	# captures is the instrument's floor, and the claim must beat it by a
	# MARGIN, not a picked bar.
	var anchor: Node3D = Node3D.new()
	game.add_child(anchor)
	anchor.global_position = Vector3(30.0, 0.0, -10.0)
	InputManager.player.aim.process_mode = Node.PROCESS_MODE_DISABLED
	Globals.camera_follow.look_ahead = Vector3.ZERO
	Globals.camera_follow.target = anchor
	# Off frame but ON THE MAP: (70, -40) was past the 120m floor's edge, and
	# the falling body poisoned every print's height for three instrument
	# generations before a position printout caught it at y -131.
	player.global_position = Vector3(55.0, 0.0, -35.0)
	Calendar.set_time(9, 0)  # before the haze
	var field: SandField = game.find_children("*", "SandField", true, false).front()
	field.set_process(false)
	# The grass sways on its OWN wind_path accumulator - the diff map showed
	# tufts flickering inside the first floor while the prints showed nothing.
	var grass: GrassField = game.find_children("*", "GrassField", true, false).front()
	grass.set_process(false)
	await settle(40)  # glide onto the anchor
	Globals.camera_follow.process_mode = Node.PROCESS_MODE_DISABLED
	var floor_delta: float = await idle_floor(10, 16, 0.6)  # central band: no HUD text

	# A walked line of prints across the view, one plant at a time - each
	# print is an emitting PULSE at the teleported stamp, so stamping them
	# all in one frame would leave a single print at the last spot. The gate
	# samples the ground at the spot, not under the parked body, so stamping
	# from off-frame works.
	for i in 14:
		var along: Vector3 = Vector3(26.0 + i * 0.55, 0.0,
				-8.5 + (0.35 if i % 2 == 0 else -0.35))
		steps.stamp_at(along)
		await settle(4)  # let the pulse land before the stamp moves on
	await settle(20)  # the trail camera renders on its own cadence
	var printed: Image = await capture()
	save_shot(printed, "footprints")

	for mark in steps.marks:  # clears every live print
		if is_instance_valid(mark):
			mark.queue_free()
	await settle(10)
	var bare: Image = await capture()
	save_shot(bare, "footprints_bare")
	# A COUNT, not a mean: fourteen quarter-metre dents are point features,
	# and a frame mean waters them down to the noise it took three broken
	# instruments to stop measuring. Hot samples on a stilled frame are
	# unambiguous - prints give dozens, drift and nothing give none.
	var hot: int = 0
	for y in range(int(printed.get_height() * 0.2),
			int(printed.get_height() * 0.8), 16):
		for x in range(0, printed.get_width(), 16):
			var a: Color = printed.get_pixel(x, y)
			var b: Color = bare.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.08:
				hot += 1
	print("DBG PRINTS hot=%d floor=%.4f" % [hot, floor_delta])
	check(hot >= 8 and floor_delta < 0.002,
			"a walked line stands in hot samples over a still floor",
			"%d hot, %.4f floor" % [hot, floor_delta])
	finish()
