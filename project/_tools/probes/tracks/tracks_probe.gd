extends Node3D

const SHOT: String = "user://tracks_%s.png"

@export var demo_drive: bool = false  # unattended weave, set before the scene runs
@export var show_dust: bool = true  # off only to inspect ruts the plume sits over

@onready var ground: MeshInstance3D = $Ground/Surface
@onready var trail_viewport: SubViewport = $TrailViewport
@onready var field: SandField = $SandField
@onready var car: Vehicle = $Car
@onready var driver: VehicleSteering = $Car/TracksDriver
@onready var camera_follow: CameraFollow = $CameraFollow

var sand: ShaderMaterial


func _ready():
	ProbeBase.silence()  # Node3D, so it cannot inherit the mute
	sand = field.sand  # the field wired it before us; keep the old handle alive
	driver.demo = demo_drive
	camera_follow.target = car
	car.start_engine()  # nobody is seated, so nothing turned the key
	car.hurt_box.monitorable = false  # invulnerable hull; the rim would wreck it
	# Hidden, not silenced: VehicleGroundFX rewrites `emitting` every frame.
	for bank in car.ground_fx.dust_banks:
		for dust in bank:
			dust.visible = show_dust
	report()
	# This scene is a STAGE - tracks_shot instantiates it and drives it. Run on
	# its own it would idle to the suite's frame budget, so standing alone it
	# checks that the field is wired up and hands back a tally like any probe.
	if get_parent() == get_tree().root:
		await standalone()


# The trail buffer itself, so "no ruts" can be told apart from "no particles".
func dump_trail(p_tag: String):
	var marks: int = trail_marks()
	var image: Image = trail_viewport.get_texture().get_image()
	image.save_png(SHOT % ("buffer_" + p_tag))
	print("DBG trail buffer: %d of %d sampled texels carry a mark" % [
			marks, (image.get_width() / 8.0) * (image.get_height() / 8.0)])


# Marked texels in the height field. This is what a rut IS, before any camera
# or shader gets a say, which makes it the honest thing for a shot to assert.
# The threshold has to clear the buffer's REST BED, which is not zero: measured
# min 0.161, mean 0.187, with real ruts reaching 1.0. A threshold of 0.1 sat
# UNDER that bed, so every texel counted as a rut and the measure was pinned at
# 16384 of 16384 sampled - a ceiling no drive could move, which read as "the
# ruts never cut" for as long as it went unmeasured. They were cutting fine.
func trail_marks(p_threshold: float = 0.5) -> int:
	var texture: Texture2D = trail_viewport.get_texture()
	if texture == null:
		return -1  # nothing has rendered into the buffer yet
	var image: Image = texture.get_image()
	if image == null:
		return -1
	var lit: int = 0
	for y in range(0, image.get_height(), 8):
		for x in range(0, image.get_width(), 8):
			if image.get_pixel(x, y).r > p_threshold:
				lit += 1
	return lit


func report():
	var mesh: PlaneMesh = ground.mesh
	print("DBG plane %s subdiv %dx%d verts~%d" % [mesh.size, mesh.subdivide_width,
			mesh.subdivide_depth, (mesh.subdivide_width + 2) * (mesh.subdivide_depth + 2)])
	print("DBG world_size %.1f  trail viewport %s  ditch %.2fm" % [
			sand.get_shader_parameter("world_size"),
			trail_viewport.size,
			sand.get_shader_parameter("ditch_depth")])
	print("DBG metres per trail texel: %.3f" % [
			float(sand.get_shader_parameter("world_size")) / trail_viewport.size.x])
	print("DBG car %s controller=%s demo=%s" % [car.name, car.controller, demo_drive])
	print("DBG rut_strength %.2f" % sand.get_shader_parameter("rut_strength"))


func shoot(p_tag: String):
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(SHOT % p_tag)
	print("DBG saved %s" % p_tag)


# Standing alone this scene is a cheap wiring probe: it cannot make ruts with
# nobody driving, so it asserts the field is ready to take them and quits. The
# counters are local because ProbeBase is a Node and this stage is a Node3D.
func standalone() -> void:
	for i in 4:
		await get_tree().process_frame
	var claims: Array = [
		[sand != null, "the field wired its sand material", str(sand)],
		[float(sand.get_shader_parameter("world_size")) > 0.0,
				"the shader knows how wide its world is",
				str(sand.get_shader_parameter("world_size"))],
		[trail_viewport.size.x > 0 and trail_viewport.size.y > 0,
				"the trail viewport has a buffer to draw into", str(trail_viewport.size)],
	]
	# Headless never draws into the buffer, so the read hands back -1 rather than
	# a count: the claim is SKIPPED here instead of answered with a number
	# nothing produced, and tracks_shot makes it windowed where it means something.
	if DisplayServer.get_name() == "headless":
		print("DBG SKIP nothing has driven on it yet: headless draws no buffer to read")
	else:
		var marks: int = trail_marks()
		claims.append([marks == 0, "and nothing has driven on it yet",
				"%d marked texels" % marks])
	var failed: int = 0
	for claim in claims:
		if not claim[0]:
			failed += 1
		print("DBG %s %s: %s" % ["PASS" if claim[0] else "FAIL", claim[1], claim[2]])
	print("DBG %d passed, %d failed" % [claims.size() - failed, failed])
	get_tree().quit()
