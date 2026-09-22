extends ProbeBase
# DBG probe: footprints - every character's footsteps component carries a
# print stamp into the rut buffer, a plant on sand records one, and ground
# that records no displacement (tarmac) records no feet either. The pixels
# themselves are steps_shot's claim.


func _ready():
	var game: Node = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await settle(8)
	var player: Character = InputManager.player
	var steps: CharacterFootsteps = null
	for child in player.get_children():
		if child is CharacterFootsteps:
			steps = child
	if not check(steps != null, "the player walks on footsteps", str(steps)):
		finish()
		return

	# --- the stamp scene is authored onto every character
	check(steps.print_scene != null,
			"the footsteps carry a print stamp", str(steps.print_scene))

	# --- sand records a plant
	player.global_position = Vector3(30.0, 0.0, -20.0)  # open sand
	await get_tree().physics_frame
	var before: int = steps.prints_stamped
	steps.stamp_at(player.global_position)
	check(steps.prints_stamped == before + 1 and steps.marks.size() > 0 			and is_instance_valid(steps.marks.back()) 			and steps.marks.back().emitting,
			"a plant on sand births a live burst", "%d stamped" % steps.prints_stamped)

	# --- ground that records no wheels records no feet
	var road: Node = game.find_child("Roads", true, false)
	if check(road != null, "the map carries roads to refuse", str(road)):
		var ribbon: Node3D = null
		for child in road.get_children():
			if child is Path3D:
				ribbon = child
				break
		# Stand ON the tarmac: the ribbon's own first curve point.
		var spot: Vector3 = ribbon.global_transform \
				* ribbon.curve.get_point_position(0)
		player.global_position = spot + Vector3.UP * 0.1
		await get_tree().physics_frame
		before = steps.prints_stamped
		steps.stamp_at(player.global_position)
		check(steps.prints_stamped == before,
				"tarmac takes no print", "%d stamped" % steps.prints_stamped)

	# --- the enemy walks on the same component, prints included
	var enemy: Character = (load("res://scenes/characters/enemy.tscn") \
			as PackedScene).instantiate()
	add_child(enemy)
	enemy.global_position = Vector3(34.0, 0.0, -20.0)
	await settle(4)
	var enemy_steps: CharacterFootsteps = null
	for child in enemy.get_children():
		if child is CharacterFootsteps:
			enemy_steps = child
	check(enemy_steps != null and enemy_steps.print_scene != null,
			"an enemy's steps stamp the same buffer", str(enemy_steps))

	finish()
