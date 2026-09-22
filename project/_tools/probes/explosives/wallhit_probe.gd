extends ProbeBase
# The screenshot case: aim at a wall, and check the grenade ends up where the
# preview said rather than dead at the foot of what it struck.


func _ready():
	var game: Node = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	for i in 8:
		await get_tree().process_frame
	var player: Character = InputManager.player
	var throwing: PlayerThrow = null
	for child in player.get_children():
		if child is PlayerThrow:
			throwing = child
	throwing.set_process(false)
	throwing.aim.set_physics_process(false)

	var wall: StaticBody3D = StaticBody3D.new()
	wall.collision_layer = 4
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(1.0, 2.4, 8.0)
	shape.shape = box
	wall.add_child(shape)
	add_child(wall)
	wall.global_position = player.global_position + Vector3(5.0, 1.2, 0.0)
	await get_tree().physics_frame

	var camera: Camera3D = get_viewport().get_camera_3d()
	var face: Vector3 = wall.global_position + Vector3(-0.5, 0.3, 0.0)
	throwing.aim.mouse_position = camera.unproject_position(face)
	var target: Vector3 = throwing.aim_point()
	print("DBG face=%s aim_point=%s player=%s wall=%s" % [face.snappedf(0.01),
			target.snappedf(0.01), player.global_position.snappedf(0.01),
			wall.global_position.snappedf(0.01)])
	throwing.solve(target)
	var arc: PackedVector3Array = throwing.preview.trace()
	print("DBG arc %d pts, first=%s last=%s" % [arc.size(),
			arc[0].snappedf(0.01), arc[arc.size()-1].snappedf(0.01)])
	var predicted: Vector3 = throwing.preview.landing
	var launch: Vector3 = throwing.launch
	var origin: Vector3 = throwing.throw_origin()

	var data: ExplosiveData = load("res://data/items/explosives/grenade.tres")
	var g: Grenade = data.thrown_scene.instantiate()
	add_child(g)
	g.throw(origin, launch, data)
	var rest: Vector3 = origin
	for i in 200:
		await get_tree().physics_frame
		if not is_instance_valid(g):
			break
		rest = g.global_position
	var drift: float = Vector3(predicted.x - rest.x, 0.0, predicted.z - rest.z).length()
	print("DBG predicted %s  actual %s" % [predicted.snappedf(0.01), rest.snappedf(0.01)])
	check(drift < 2.0, "a throw at a wall ends near where the preview said",
			"off by %.2fm" % drift)
	# It must come BACK off the wall, not sit against it.
	check(rest.x < wall.global_position.x - 0.6,
			"and bounces back rather than dropping at the wall's foot",
			"rest x=%.2f, wall face x=%.2f" % [rest.x, wall.global_position.x - 0.5])
	finish()
