extends ProbeBase
# WINDOWED look check for the barrel chill tint: parks the player in the
# garden pocket at noon, saves user://barrel_pocket.png, then diffs the SAME
# frame region with the tint toggled off - shadows, GI and props cancel out,
# so the difference IS the tint. Sun shadows, the drum's red bounce and the
# roaming camera defeated every direct near-vs-far sand comparison.

@onready var GAME: PackedScene = load("uid://b56i3a2diovj6")  # scenes/game.tscn


func _ready():
	if not windowed("the barrel chill tint"):
		finish()
		return
	var game: Node = GAME.instantiate()
	add_child(game)
	await settle(10)
	# Its own barrel on open sand, clear of the station's overlapping discs.
	# Parented to the game ROOT rather than a named branch: chill sources are
	# found by group, so the level is free to be rearranged under this shot.
	var barrel: FuelBarrel = (load("res://scenes/props/fuel_barrel.tscn") \
			as PackedScene).instantiate()
	game.add_child(barrel)
	barrel.global_position = Vector3(30.0, 0.0, -10.0)
	barrel.warmth = 1.0  # the shot measures the tint, not the slow cold-in
	InputManager.player.global_position = barrel.global_position + Vector3(0.0, 0.0, 3.0)
	# Pin the camera dead on the player - the aim-lead follows wherever the
	# OS left the cursor and reframes every run.
	InputManager.player.aim.process_mode = Node.PROCESS_MODE_DISABLED
	Globals.camera_follow.look_ahead = Vector3.ZERO
	Calendar.set_time(12, 0)
	await settle(90)  # camera glide, chill push, haze settle
	var tinted: Image = await capture()
	save_shot(tinted, "barrel_pocket")

	var field: SandField = game.find_children("*", "SandField", true, false).front()
	field.set_process(false)  # or the next chill push turns it back on
	var zeros: PackedVector4Array = PackedVector4Array()
	zeros.resize(SandField.MAX_CHILL)
	field.sand.set_shader_parameter("chill_spots", zeros)
	# A generous settle: capturing one frame after the toggle reads the
	# IN-FLIGHT frame and diffs tint against tint - a whole debugging spiral
	# once concluded "the tint never renders" off exactly that.
	await settle(10)
	var bare: Image = await capture()

	# Whole-frame diff, no projection: a 14m blob of tinted ground dominates
	# streamer creep and haze wobble (~0.002-0.004) by an order. Screen-space
	# box placement lost to the zoom-anchored camera every way it was tried.
	var delta: float = frame_diff(tinted, bare, 16)
	print("DBG TINT frame delta=%.4f" % delta)
	check(delta > 0.015, "toggling the chill visibly changes the ground",
			"%.4f mean delta" % delta)
	finish()
