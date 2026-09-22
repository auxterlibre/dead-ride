extends ProbeBase
# Windowed only - headless renders blank. Three hundred zombies on a stage seen
# from the game's angle, to look at the multimesh skinning and the outfits.

const COUNT: int = 300


func _ready():
	if not windowed("the horde lineup"):
		finish()
		return
	var stage: Node3D = Node3D.new()
	add_child(stage)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.16, 0.17, 0.19)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	environment.environment.ambient_light_energy = 0.7
	stage.add_child(environment)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 35.0, 0.0)
	sun.shadow_enabled = true
	stage.add_child(sun)
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	floor_mesh.mesh.size = Vector2(120.0, 120.0)
	stage.add_child(floor_mesh)
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 30.0
	stage.add_child(camera)
	camera.look_at_from_position(Vector3(0.0, 24.0, 24.0), Vector3(0.0, 0.0, 0.0))
	camera.current = true
	var lure: Node3D = Node3D.new()
	lure.position = Vector3(0.0, 0.0, 0.0)
	stage.add_child(lure)
	var horde: Horde = (load("res://scenes/world/horde.tscn") as PackedScene).instantiate()
	horde.target_node = lure
	stage.add_child(horde)
	await settle(3)
	for n in COUNT:
		var angle: float = randf_range(0.0, TAU)
		var radius: float = randf_range(6.0, 18.0)
		horde.spawn(Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))
	await settle(50)
	save_shot(await capture(), "horde_closing")
	await settle(120)
	save_shot(await capture(), "horde_crowding")
	var drawn: int = 0
	for mesh in horde.meshes:
		drawn += mesh.multimesh.visible_instance_count
	check(drawn == COUNT, "every zombie on the stage is drawn", "%d of %d" % [drawn, COUNT])
	finish()
