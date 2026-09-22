extends ProbeBase
# DBG shot (windowed): a one-sided tuft keeps its face to the camera.

const SAND: Color = Color(0.902, 0.639, 0.212)
const MESHES: Array = [
	"res://assets/meshes/environment/props/grass/grass_1_a_singlesided_color_5.tres",
	"res://assets/meshes/environment/props/grass/grass_1_c_singlesided_color_5.tres",
	"res://assets/meshes/environment/props/grass/grass_2_b_singlesided_color_5.tres",
	"res://assets/meshes/environment/props/grass/grass_2_d_singlesided_color_5.tres",
]

var camera: Camera3D
var tufts: Array[MeshInstance3D] = []


func _ready():
	if not windowed("the grass lineup"):
		finish()
		return
	build_stage()
	for i in MESHES.size():
		var tuft: MeshInstance3D = MeshInstance3D.new()
		tuft.mesh = load(MESHES[i])
		add_child(tuft)
		tuft.position = Vector3(i * 0.9 - 1.35, 0.0, 0.0)
		tuft.visible = false
		tufts.append(tuft)
	await settle(4)

	var creep: float = await idle_floor()
	var front: float = await silhouette()
	check(front > maxf(creep * 4.0, 0.0005), "the tufts render at all",
			"%.5f over %.5f creep" % [front, creep])

	# A flat single-sided plane seen from 90 degrees round is a hairline - only
	# a billboard still shows the same face, so the two silhouettes must match.
	place_camera(90.0)
	await settle(4)
	var side: float = await silhouette()
	check(side > front * 0.5,
			"and turn to keep it from a quarter turn away",
			"%.5f side against %.5f front" % [side, front])

	# --- the sway rides the air's travel, and nothing else
	place_camera(0.0)
	for tuft in tufts:
		tuft.visible = true
	await settle(4)
	var material: ShaderMaterial = tufts[0].mesh.surface_get_material(0)
	material.set_shader_parameter("wind_strength", 0.0)
	material.set_shader_parameter("wind_path", Vector2.ZERO)
	await settle(2)
	var still: Image = await capture()
	await settle(30)  # TIME passes; a shader keyed on it would ripple here
	var later: Image = await capture()
	var drift: float = frame_diff(still, later, 4)
	check(drift <= maxf(creep * 2.0, 0.0002), "dead air leaves the tufts still",
			"%.5f over %.5f creep" % [drift, creep])
	material.set_shader_parameter("wind_strength", 6.0)
	material.set_shader_parameter("wind_path", Vector2(0.0, -1.4))
	await settle(2)
	var blown: Image = await capture()
	check(frame_diff(still, blown, 4) > maxf(creep * 4.0, 0.0004),
			"and the air moving is what bends them",
			"%.5f against %.5f creep" % [frame_diff(still, blown, 4), creep])
	save_shot(blown, "grass_windy")

	for tuft in tufts:
		tuft.visible = true
	place_camera(90.0)
	await settle(2)
	save_shot(await capture(), "grass_side")
	place_camera(0.0)
	await settle(4)
	save_shot(await capture(), "grass_front")
	finish()


# What the tufts add to the bare floor from wherever the camera stands.
func silhouette() -> float:
	for tuft in tufts:
		tuft.visible = false
	await settle(2)
	var bare: Image = await capture()
	for tuft in tufts:
		tuft.visible = true
	await settle(2)
	var grown: Image = await capture()
	return frame_diff(bare, grown, 4)


func place_camera(p_degrees: float):
	var away: Vector3 = Vector3(0.0, 2.2, 4.0).rotated(Vector3.UP,
			deg_to_rad(p_degrees))
	camera.position = away
	camera.look_at(Vector3(0.0, 0.35, 0.0))


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
	add_child(sun)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	environment.environment.ambient_light_energy = 0.6
	add_child(environment)
	camera = Camera3D.new()
	add_child(camera)
	place_camera(0.0)
