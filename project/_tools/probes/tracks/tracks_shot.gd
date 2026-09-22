extends ProbeBase
# Windowed only - headless renders blank. Drives the demo weave and proves the
# car actually cut ruts, measured in the trail height field rather than off the
# picture: the buffer is what a rut IS before the shader gets a say.


func _ready():
	if not windowed("the sand tracks"):
		finish()
		return
	var probe: Node3D = load("res://_tools/probes/tracks/tracks_probe.tscn").instantiate()
	# Before add_child: the probe hands these on in its own _ready.
	probe.demo_drive = true
	probe.show_dust = false  # the shot is of the ruts, and the plume sits over them
	add_child(probe)
	await settle(4)

	var clean: int = probe.trail_marks()
	check(clean >= 0, "the trail buffer is readable before the drive",
			"%d marked texels" % clean)

	await settle(600)
	var driven: int = probe.trail_marks()
	check(driven > clean + 20, "the weave cuts ruts into the height field",
			"%d marked texels, up from %d" % [driven, clean])

	# Pull off the car and onto the field: the whole point of the shot is the
	# pattern left behind, and the car is usually out at the rim by now.
	probe.camera_follow.target = probe
	probe.get_node("CameraFollow/Camera").size = 48.0
	await settle(90)

	# The ruts have to survive the car leaving them - they are a stamped field,
	# not something drawn under the wheels each frame.
	var settled: int = probe.trail_marks()
	check(settled > clean + 20, "and they are still there once the car has gone",
			"%d marked texels with the car out at the rim" % settled)
	await probe.shoot("smooth")
	finish()
