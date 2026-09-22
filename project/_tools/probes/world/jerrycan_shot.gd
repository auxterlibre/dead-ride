extends ProbeBase
# Windowed only - headless renders blank. Stands the extracted jerrycan over the
# sand colour and proves it renders wearing its kit material rather than Godot's
# white fallback. Points into assets/, NEVER _not_exported/: the raw sources are
# staging and get cleared out, which had already left this shot asserting three
# models that no longer existed.

const SAND: Color = Color(0.902, 0.639, 0.212)
const FALLBACK: float = 0.90  # a channel mean above this on all three is the white stand-in
const MESH: String = "res://assets/meshes/props/resource_bits/fuel_a_jerrycan.tres"


func _ready():
	if not windowed("the jerrycan"):
		finish()
		return
	build_stage()
	var mesh: Mesh = load(MESH) as Mesh
	if not check(mesh != null, "the extracted jerrycan mesh loads", MESH.get_file()):
		finish()
		return
	var prop: MeshInstance3D = MeshInstance3D.new()
	prop.mesh = mesh
	prop.rotation_degrees.y = 25.0  # quarter turn so the spout and handle read
	prop.visible = false
	add_child(prop)
	await settle(4)

	var bare: Image = await capture()
	var creep: float = await idle_floor()

	prop.visible = true
	await settle(2)
	var lit: Image = await capture()
	var delta: float = frame_diff(bare, lit, 4)
	var mean: Color = changed_mean(bare, lit)
	check(delta > maxf(creep * 4.0, 0.0005), "the jerrycan renders over the sand",
			"%.5f over %.5f creep" % [delta, creep])
	# The kit material has to actually be on it: Godot's stand-in is flat white,
	# renders perfectly well, and proves nothing about the atlas being wired.
	check(not (mean.r > FALLBACK and mean.g > FALLBACK and mean.b > FALLBACK),
			"and wears its kit material rather than the white fallback",
			"mean rgb(%.2f, %.2f, %.2f)" % [mean.r, mean.g, mean.b])
	save_shot(lit, "jerrycan")
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
	# Aimed so the 0.78m can sits centred and whole: pitched -25 degrees from
	# z=3, the eye has to stand at 0.39 + 3 * tan(25) to put the middle of the
	# can on the centre ray. Eyeballed framing cropped its top clean off.
	camera.size = 1.2
	camera.rotation_degrees = Vector3(-25.0, 0.0, 0.0)
	camera.position = Vector3(0.0, 1.78, 3.0)
	add_child(camera)
