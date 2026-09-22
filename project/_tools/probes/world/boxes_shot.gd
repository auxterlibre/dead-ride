extends ProbeBase
# Windowed only - headless renders blank. Lines up the six loot boxes over the
# sand colour: each one has to render, and none of them may come up as Godot's
# white fallback, which is what a broken material looks like.

const SAND: Color = Color(0.902, 0.639, 0.212)
const FALLBACK: float = 0.90  # a channel mean above this on all three is the white stand-in
const BOXES: Array = [
	["res://scenes/props/loot_boxes/army_crate_large.tscn", -6.4],
	["res://scenes/props/loot_boxes/army_crate_medium.tscn", -4.2],
	["res://scenes/props/loot_boxes/army_crate_small.tscn", -2.6],
	["res://scenes/props/loot_boxes/cardboard_box_large.tscn", -0.9],
	["res://scenes/props/loot_boxes/cardboard_box_medium.tscn", 0.9],
	["res://scenes/props/loot_boxes/cardboard_box_small.tscn", 2.4],
]


func _ready():
	if not windowed("the box lineup"):
		finish()
		return
	build_stage()
	var props: Array[Node3D] = []
	for box in BOXES:
		var prop: Node3D = (load(box[0]) as PackedScene).instantiate()
		add_child(prop)
		prop.position = Vector3(box[1], 0.0, 0.0)
		prop.visible = false
		props.append(prop)
	await settle(4)

	var floor_only: Image = await capture()
	var creep: float = await idle_floor()

	# One at a time against the bare floor: a box that fails to load, sinks or
	# renders inside-out contributes nothing, and says so on its own line.
	for i in props.size():
		props[i].visible = true
		await settle(2)
		var lit: Image = await capture()
		var delta: float = frame_diff(floor_only, lit, 4)
		var mean: Color = changed_mean(floor_only, lit)
		var label: String = String(BOXES[i][0]).get_file().get_basename()
		check(delta > maxf(creep * 4.0, 0.0005) \
				and not (mean.r > FALLBACK and mean.g > FALLBACK and mean.b > FALLBACK),
				"%s renders in its own colours" % label,
				"delta %.5f over %.5f creep, mean rgb(%.2f, %.2f, %.2f)"
				% [delta, creep, mean.r, mean.g, mean.b])
		props[i].visible = false
		await settle(2)

	for prop in props:
		prop.visible = true
	await settle(4)
	var lineup: Image = await capture()
	check(frame_diff(floor_only, lineup, 4) > creep * 4.0,
			"and the six of them together fill the frame",
			"%.5f over %.5f creep" % [frame_diff(floor_only, lineup, 4), creep])
	save_shot(lineup, "boxes_lineup")
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
	camera.size = 6.0
	camera.rotation_degrees = Vector3(-35.0, 0.0, 0.0)
	camera.position = Vector3(-2.0, 5.0, 7.0)
	add_child(camera)
