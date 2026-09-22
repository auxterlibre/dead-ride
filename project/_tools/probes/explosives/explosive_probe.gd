extends ProbeBase
# Does an explosive take full damage across its core and fall away outside it?

const EXPECTED_CHECKS: int = 18  # including the tally check itself

var landed: Dictionary = {}  # victim -> damage the blast actually dealt


func _ready():
	var data: ExplosiveData = load("res://data/items/explosives/grenade.tres")
	print("DBG damage=%d core=%.2fm blast=%.2fm fuse=%.1fs knock=%.1f" % [
			data.damage_value, data.core_radius_value, data.blast_radius_value,
			data.fuse_value, data.knockback_value])

	check(data.damage_at(0.0) == data.damage_value, "dead centre takes it all",
			str(data.damage_at(0.0)))
	check(data.damage_at(data.core_radius_value) == data.damage_value,
			"the whole core takes it all", str(data.damage_at(data.core_radius_value)))
	check(data.damage_at(data.blast_radius_value) == 0, "the edge takes nothing",
			str(data.damage_at(data.blast_radius_value)))
	check(data.damage_at(data.blast_radius_value + 5.0) == 0,
			"and beyond it stays nothing", str(data.damage_at(99.0)))

	# Never rises with distance, never goes negative.
	var previous: int = data.damage_value + 1
	var monotonic: bool = true
	var curve: Array = []
	for i in 11:
		var distance: float = data.blast_radius_value * i / 10.0
		var hurt: int = data.damage_at(distance)
		curve.append("%.1fm:%d" % [distance, hurt])
		if hurt > previous or hurt < 0:
			monotonic = false
		previous = hurt
	check(monotonic, "damage never rises with distance", ", ".join(curve))

	var mid: float = (data.core_radius_value + data.blast_radius_value) * 0.5
	check(data.damage_at(mid) > 0 and data.damage_at(mid) < data.damage_value,
			"halfway out is partial", str(data.damage_at(mid)))
	check(is_equal_approx(data.knockback_at(0.0), data.knockback_value),
			"knockback is full at the core", "%.2f" % data.knockback_at(0.0))
	check(is_zero_approx(data.knockback_at(data.blast_radius_value)),
			"and gone at the edge", "%.2f" % data.knockback_at(data.blast_radius_value))

	# A core as wide as the blast must be hard-edged, not a division by zero.
	var hard: ExplosiveData = data.duplicate()
	hard.core_size = 100
	check(hard.damage_at(hard.blast_radius_value - 0.01) == hard.damage_value,
			"a full-width core is hard-edged, not a crash",
			str(hard.damage_at(hard.blast_radius_value - 0.01)))

	check(data.get_category_label() == "Explosive", "the tooltip names its kind",
			data.get_category_label())
	check(data.model != null and data.model.can_instantiate(),
			"the data carries a scene the icon renderer can draw", str(data.model))

	await live_blast(data)
	await cover_blast(data)
	# A hardcoded scene path once moved and six checks stopped RUNNING rather
	# than failing - the tally read clean because it was counting fewer things.
	check(passed + failed == EXPECTED_CHECKS - 1, "every check actually ran",
			"%d of %d" % [passed + failed + 1, EXPECTED_CHECKS])
	finish()


# The live half: a blast in a real world has to FIND hurt boxes and land damage
# through them. Read the damage off the damaged signal rather than off health,
# which clamps at zero - a 15 HP enemy cannot tell 100 damage from 63.
func live_blast(p_data: ExplosiveData):
	var victims: Array = []
	for distance in [0.0, 3.0, 8.0]:
		var enemy: Character = load("res://scenes/characters/enemy.tscn").instantiate()
		add_child(enemy)
		enemy.global_position = Vector3(distance, 0.0, 0.0)
		enemy.damaged.connect(func(attack): landed[enemy] = attack.damage)
		victims.append({"node": enemy, "distance": distance})
	# Character.apply_data() awaits a PROCESS frame before health exists, so
	# physics frames alone leave every victim on zero and the test reads clean.
	for i in 4:
		await get_tree().process_frame

	for victim in victims:
		victim["spot"] = victim.node.global_position

	var grenade: Grenade = p_data.thrown_scene.instantiate()
	add_child(grenade)
	grenade.global_position = Vector3.ZERO
	grenade.arm(p_data)
	grenade.explode()
	await get_tree().physics_frame

	# Against where each victim ACTUALLY stood at the bang: a character settles
	# under gravity between spawn and blast, and the point of the test is the
	# distance-to-damage relationship, not that nobody moved.
	for victim in victims:
		var dealt: int = landed.get(victim.node, 0)
		var reach: float = Vector3.ZERO.distance_to(victim.spot)
		var want: int = p_data.damage_at(reach)
		check(dealt == want, "at %.2fm the blast deals %d" % [reach, want],
				"dealt %d (placed at %.0fm)" % [dealt, victim.distance])


# Cover: a wall between the blast and a target spares them, open ground does
# not, and a vehicle's own hull never spares the vehicle.
func cover_blast(p_data: ExplosiveData):
	var exposed: Character = spawn_victim(Vector3(3.0, 0.0, 0.0))
	var sheltered: Character = spawn_victim(Vector3(-3.0, 0.0, 0.0))
	var wall: StaticBody3D = build_wall(Vector3(-1.5, 1.0, 0.0))
	for i in 4:
		await get_tree().process_frame

	var grenade: Grenade = p_data.thrown_scene.instantiate()
	add_child(grenade)
	grenade.global_position = Vector3.ZERO
	grenade.arm(p_data)
	grenade.explode()
	await get_tree().physics_frame

	check(landed.get(exposed, 0) > 0, "a target in the open is caught",
			"took %d" % landed.get(exposed, 0))
	check(landed.get(sheltered, 0) == 0, "and one behind a wall is spared",
			"took %d" % landed.get(sheltered, 0))
	wall.queue_free()

	# A vehicle is ON the car layer, so without the self-exclusion its own hull
	# stops the ray to itself and it takes nothing.
	var car: Vehicle = load("res://scenes/vehicles/car.tscn").instantiate()
	add_child(car)
	car.global_position = Vector3(0.0, 0.0, 3.0)
	# Into the member dictionary, not a local: a GDScript lambda captures locals
	# by VALUE, so writing to one from inside the closure changes only a copy.
	car.damaged.connect(func(attack): landed[car] = attack.damage)
	for i in 4:
		await get_tree().process_frame
	var second: Grenade = p_data.thrown_scene.instantiate()
	add_child(second)
	second.global_position = car.global_position + Vector3(0.0, 0.0, -1.2)
	second.arm(p_data)
	second.explode()
	await get_tree().physics_frame
	check(landed.get(car, 0) > 0, "a car in the blast is damaged, not shielded by itself",
			"took %d" % landed.get(car, 0))


func spawn_victim(p_at: Vector3) -> Character:
	var enemy: Character = load("res://scenes/characters/enemy.tscn").instantiate()
	add_child(enemy)
	enemy.global_position = p_at
	enemy.damaged.connect(func(attack): landed[enemy] = attack.damage)
	return enemy


func build_wall(p_at: Vector3) -> StaticBody3D:
	var wall: StaticBody3D = StaticBody3D.new()
	wall.collision_layer = 4  # walls
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.5, 4.0, 8.0)
	shape.shape = box
	wall.add_child(shape)
	add_child(wall)
	wall.global_position = p_at
	return wall
