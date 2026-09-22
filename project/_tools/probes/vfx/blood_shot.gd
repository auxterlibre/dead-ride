extends ProbeBase
# Windowed only - headless renders blank. Lays a burst cluster, a walking trail
# and a lone drip over the sand colour, then proves they are actually ON the
# sand and that they go on changing as they dry, rather than trusting the png.

const SAND: Color = Color(0.902, 0.639, 0.212)

var camera: Camera3D


func _ready():
	if not windowed("the blood pools"):
		finish()
		return
	build_stage()
	await settle(4)
	var bare: Image = await capture()
	var creep: float = await idle_floor()

	# a burst of hits around one spot: should merge into a single pool
	for offset in [Vector2.ZERO, Vector2(0.5, 0.2), Vector2(-0.4, 0.35),
			Vector2(0.2, -0.5), Vector2(-0.2, -0.3)]:
		BloodPool.drop(self, Vector3(-2.0 + offset.x, 0.0, -1.5 + offset.y))
	# a walking bleeder: a drop every 0.4m along a curve, crossing plane seams
	for i in 16:
		var t: float = i / 15.0
		BloodPool.drop(self, Vector3(-3.0 + t * 6.0, 0.0,
				1.5 + sin(t * TAU * 0.75) * 0.8))
	# one lone drip
	BloodPool.drop(self, Vector3(2.5, 0.0, -2.0))
	# and a full flesh hit at sniper damage: five droplets splashed along the exit
	var impact: FleshImpact = FleshImpact.new()
	impact.setup(Vector3(2.0, 1.1, -3.5), Vector3(0.6, 0.0, -0.4).normalized(), 0.0, 17)
	add_child(impact)
	await get_tree().create_timer(1.0).timeout

	var grown: Image = await capture()
	var laid: float = frame_diff(bare, grown, 4)
	var mean: Color = changed_mean(bare, grown)
	check(laid > maxf(creep * 6.0, 0.001), "the pools land visibly on the sand",
			"%.5f over %.5f creep" % [laid, creep])
	# Blood on orange sand is the darker, redder half of the frame: a pool that
	# reads lighter than the ground it soaked into is not a pool.
	check(mean.r + mean.g + mean.b < SAND.r + SAND.g + SAND.b,
			"and they read darker than the sand under them",
			"pool rgb(%.2f, %.2f, %.2f) vs sand rgb(%.2f, %.2f, %.2f)"
			% [mean.r, mean.g, mean.b, SAND.r, SAND.g, SAND.b])
	save_shot(grown, "blood_grown")

	camera.rotation_degrees = Vector3(-60.0, 0.0, 0.0)
	camera.position = Vector3(0.0, 10.0, 6.0)
	var angled: Image = await capture()
	save_shot(angled, "blood_angled")

	# Back to the overhead framing the grown shot used, so the drying delta is
	# the pools changing and not the camera moving.
	camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	camera.position = Vector3(0.0, 15.0, 0.0)
	await get_tree().create_timer(5.0).timeout
	var drying: Image = await capture()
	var dried: float = frame_diff(grown, drying, 4)
	check(dried > creep * 2.0, "and they keep drying after they stop spreading",
			"%.5f over %.5f creep" % [dried, creep])
	save_shot(drying, "blood_drying")
	finish()


func build_stage():
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(30.0, 30.0)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = SAND
	plane.material = material
	floor_mesh.mesh = plane
	add_child(floor_mesh)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	sun.light_energy = 1.3
	add_child(sun)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	environment.environment.ambient_light_energy = 0.6
	add_child(environment)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12.0
	camera.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	camera.position = Vector3(0.0, 15.0, 0.0)
	add_child(camera)
