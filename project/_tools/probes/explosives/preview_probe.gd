extends ProbeBase
# The three read-out behaviours: a wall turns the arc, a blast throws bodies,
# and the rings arrive staggered rather than all at once.


func _ready():
	var game: Node = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	for i in 8:
		await get_tree().process_frame
	var player: Character = InputManager.player
	var carried: CharacterInventory = player.carried
	var data: ExplosiveData = load("res://data/items/explosives/grenade.tres")
	var throwing: PlayerThrow = null
	for child in player.get_children():
		if child is PlayerThrow:
			throwing = child
	throwing.set_process(false)
	throwing.aim.set_physics_process(false)

	# --- a wall turns the arc instead of the ring landing behind it
	var wall: StaticBody3D = StaticBody3D.new()
	wall.collision_layer = 4
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.6, 4.0, 12.0)
	shape.shape = box
	wall.add_child(shape)
	add_child(wall)
	wall.global_position = player.global_position + Vector3(4.0, 2.0, 0.0)
	await get_tree().physics_frame
	var beyond: Vector3 = player.global_position + Vector3(9.0, 0.0, 0.0)
	throwing.solve(beyond)
	throwing.preview.trace()
	var landed: Vector3 = throwing.preview.landing
	check(landed.x < wall.global_position.x + 0.5,
			"a wall stops the arc short of the ground behind it",
			"landed x=%.2f, wall x=%.2f, aimed x=%.2f" % [landed.x,
			wall.global_position.x, beyond.x])
	# It should still travel somewhere, not die at the hand.
	check(landed.distance_to(throwing.throw_origin()) > 1.0,
			"and the bounce carries it clear of the thrower",
			"%.2fm from the hand" % landed.distance_to(throwing.throw_origin()))
	wall.queue_free()
	await get_tree().physics_frame

	# --- a blast throws a body away from it
	var victim: Character = load("res://scenes/characters/enemy.tscn").instantiate()
	add_child(victim)
	victim.global_position = player.global_position + Vector3(14.0, 0.0, 0.0)
	for i in 4:
		await get_tree().process_frame
	var before: Vector3 = victim.global_position
	var blast: Vector3 = before - Vector3(2.0, 0.0, 0.0)
	victim.take_damage(AttackData.new(1, blast, data.knockback_value, null))
	var moved: float = 0.0
	for i in 90:
		await get_tree().physics_frame
		moved = Vector3(victim.global_position.x - before.x, 0.0,
				victim.global_position.z - before.z).length()
	check(moved > 1.0, "a blast throws a character clear of where it stood",
			"%.2fm from a %.1f-unit shove" % [moved, data.knockback_value])
	check(victim.global_position.x > before.x,
			"and away from the blast, not toward it",
			"x %.2f -> %.2f" % [before.x, victim.global_position.x])

	# --- the rings arrive staggered, and inside the wind-up
	# Sampled DURING the ramp: past the end both have saturated to 1 and any
	# ordering test passes vacuously, which is how the first draft of this
	# check went green while proving nothing.
	var windup: float = throwing.preview.windup_time()
	var ring_time: float = windup * throwing.preview.ring_grow_fraction
	var lag: float = windup * throwing.preview.core_lag_fraction
	var at: float = ring_time * 0.5
	var outer: float = throwing.preview.pop(at / ring_time)
	var core: float = throwing.preview.pop((at - lag) / ring_time)
	check(outer > core, "the blast ring leads the core in",
			"at %.3fs: outer %.2f vs core %.2f" % [at, outer, core])
	check(throwing.preview.pop(windup / ring_time) == 1.0
			and throwing.preview.pop((windup - lag) / ring_time) == 1.0,
			"and both have arrived by the end of the wind-up",
			"wind-up %.2fs, ring over %.2fs, core lags %.2fs" % [windup, ring_time, lag])
	# Early, not half-way: the curve OVERSHOOTS past 1 - that is the pop - so it
	# is already saturated by the midpoint and only the opening is partial.
	check(throwing.preview.pop(0.15) < 1.0 and throwing.preview.pop(1.0) == 1.0,
			"the arc is still running out at the start",
			"at 15%% %.2f, at 100%% %.2f" % [throwing.preview.pop(0.15), throwing.preview.pop(1.0)])
	check(throwing.preview.pop(0.5) < 1.25, "and the overshoot stays a pop, not a balloon",
			"peaks around %.2f" % throwing.preview.pop(0.5))
	check(throwing.preview.pop(-1.0) == 0.0 and throwing.preview.pop(2.0) == 1.0,
			"the ramp is bounded at both ends",
			"%.2f .. %.2f" % [throwing.preview.pop(-1.0), throwing.preview.pop(2.0)])

	finish()
