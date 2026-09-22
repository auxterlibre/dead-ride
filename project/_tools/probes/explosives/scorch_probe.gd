extends ProbeBase
# Does a blast beside a wall mark the WALL, not just the floor under it?


func _ready():
	var game: Node = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	for i in 8:
		await get_tree().process_frame
	# Clear of the floor: a blast spawned exactly ON y=0 starts INSIDE the
	# ground collision box and its down-ray returns a degenerate normal. A
	# grenade at rest sits about this high.
	var here: Vector3 = InputManager.player.global_position + Vector3(0.0, 0.25, 12.0)

	# --- open ground: the floor alone
	await blast_at(here)
	var open: Array = marks()
	check(open.size() == 1, "in the open a blast marks only the ground",
			"%d marks" % open.size())
	check(open.size() > 0 and open[0].hit_normal.y > 0.7,
			"lying flat on it", str(open[0].hit_normal.snappedf(0.01)) if open else "-")
	clear_marks()

	# --- beside a wall: the wall too
	var wall: StaticBody3D = StaticBody3D.new()
	wall.collision_layer = 4
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.6, 4.0, 10.0)
	shape.shape = box
	wall.add_child(shape)
	add_child(wall)
	wall.global_position = here + Vector3(1.6, 2.0, 0.0)
	await get_tree().physics_frame
	await blast_at(here)
	var beside: Array = marks()
	var upright: int = 0
	for mark in beside:
		if absf(mark.hit_normal.y) < 0.5:
			upright += 1
	check(upright > 0, "beside a wall the wall gets marked too",
			"%d of %d marks stand upright" % [upright, beside.size()])
	check(beside.size() <= 4, "and one flat wall does not stack a pile of them",
			"%d marks total" % beside.size())

	clear_marks()

	# --- a blast beside a car marks the GROUND, never the car. A marked car is
	# usually one about to explode and free itself, which leaves its scorch
	# hanging in the air at a panel angle, cutting across the flat ones below.
	var car: Vehicle = null
	for node in get_tree().current_scene.find_children("*", "Vehicle", true, false):
		car = node
		break
	await blast_at(car.global_position + Vector3(1.4, 0.25, 0.0))
	var steep: int = 0
	for mark in marks():
		if mark.hit_normal.y < 0.5:
			steep += 1
	check(steep == 0, "a blast by a car leaves nothing stuck to the car",
			"%d of %d marks face oddly" % [steep, marks().size()])

	# --- and the car going up too does not stack a second set over the first
	var before: int = marks().size()
	car.take_damage(AttackData.new(9999, car.global_position, 0.0, null))
	for i in 6:
		await get_tree().process_frame
	check(marks().size() <= before + 1,
			"a second blast on top of the first does not pile marks up",
			"%d -> %d" % [before, marks().size()])

	finish()


func blast_at(p_at: Vector3):
	var explosion: Node3D = load("uid://bhrwrwde4dcj3").instantiate()
	get_tree().current_scene.add_child(explosion)
	explosion.global_position = p_at
	for i in 4:
		await get_tree().process_frame


func marks() -> Array:
	var found: Array = []
	for node in get_tree().current_scene.get_children():
		if node is ScorchMark:
			found.append(node)
	return found


func clear_marks():
	for mark in marks():
		mark.queue_free()
