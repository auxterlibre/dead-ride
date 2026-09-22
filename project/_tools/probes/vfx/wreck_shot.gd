extends ProbeBase
# Windowed only - headless renders blank. Blows the car up over the sand colour
# and measures the blast against the intact frame, so "the explosion fired" is
# a number rather than a png somebody meant to look at.

const SAND: Color = Color(0.902, 0.639, 0.212)
const FLIGHT_FRAMES: int = 26  # ~0.43s after the blast; -- --frames=N overrides


func _ready():
	if not windowed("the wreck"):
		finish()
		return
	build_stage()
	var car: Vehicle = (load("res://scenes/vehicles/car.tscn") as PackedScene).instantiate()
	add_child(car)
	car.global_position = Vector3(0.0, 0.5, 0.0)
	# Long enough for the suspension to stop bouncing. Six frames left the car
	# still dropping onto its springs, which put the idle floor at 0.011 - and
	# a floor that high set a bar (creep x8) no localised blast could clear.
	await settle(90)

	var intact: Image = await capture()
	var creep: float = await idle_floor()

	car.damage.explode()
	var frames: int = FLIGHT_FRAMES
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--frames="):
			frames = int(arg.get_slice("=", 1))
	await settle(frames)

	var blast: Image = await capture()
	var delta: float = frame_diff(intact, blast, 4)
	check(delta > maxf(creep * 8.0, 0.004),
			"the blast visibly rearranges the frame the intact car filled",
			"%.5f over %.5f creep, %d frames after" % [delta, creep, frames])
	# Debris and fire are the bright half of the event: a blast that leaves the
	# frame darker overall is smoke with nothing thrown.
	var thrown: Color = changed_mean(intact, blast)
	check(thrown.r + thrown.g + thrown.b > 0.15,
			"and throws lit debris rather than only darkening",
			"changed rgb(%.2f, %.2f, %.2f)" % [thrown.r, thrown.g, thrown.b])
	save_shot(blast, "wreck_shot")
	finish()


func build_stage():
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(80.0, 80.0)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = SAND
	plane.material = material
	floor_mesh.mesh = plane
	add_child(floor_mesh)
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 16
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(80.0, 1.0, 80.0)
	shape.shape = box
	shape.position.y = -0.5
	body.add_child(shape)
	add_child(body)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	environment.environment.ambient_light_energy = 0.6
	add_child(environment)
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 24.0
	camera.rotation_degrees = Vector3(-35.0, 0.0, 0.0)
	camera.position = Vector3(0.0, 12.0, 16.0)
	add_child(camera)
