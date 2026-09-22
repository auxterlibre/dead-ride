extends ProbeBase
# DBG probe: the horde - hundreds of zombies as packed data over a multimesh:
# they close on a vehicle, bite its hull, a hitscan test finds and kills one,
# a moving hull flings the ones in its path, and a tick of 500 stays cheap.

const COUNT: int = 500
const TICK_BUDGET_USEC: int = 3000


func _ready():
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.collision_layer = 20
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	floor_shape.shape = BoxShape3D.new()
	floor_shape.shape.size = Vector3(400.0, 2.0, 400.0)
	floor_shape.position.y = -1.0
	floor_body.add_child(floor_shape)
	add_child(floor_body)
	var truck: Vehicle = (load("res://scenes/vehicles/vehicle_base.tscn") as PackedScene).instantiate()
	var hull: CollisionShape3D = CollisionShape3D.new()
	hull.shape = BoxShape3D.new()
	hull.shape.size = Vector3(2.4, 1.6, 5.0)
	hull.position.y = 0.9
	truck.add_child(hull)
	add_child(truck)
	truck.global_position = Vector3(0.0, 0.6, 0.0)
	var horde: Horde = (load("res://scenes/world/horde.tscn") as PackedScene).instantiate()
	horde.target_node = truck
	add_child(horde)
	await settle(5)
	check(horde.variants.size() >= 2 and horde.animation_set != null,
			"the horde scene carries variants and a baked animation set",
			"%d variants" % horde.variants.size())

	for n in COUNT:
		var angle: float = randf_range(0.0, TAU)
		var radius: float = randf_range(22.0, 38.0)
		horde.spawn(Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))
	check(horde.alive_count == COUNT, "five hundred zombies spawn", str(horde.alive_count))
	var before: float = mean_distance(horde, truck)
	var ticks: int = 0
	var total_usec: int = 0
	var worst_usec: int = 0
	for i in 300:
		await get_tree().physics_frame
		ticks += 1
		total_usec += horde.last_tick_usec
		worst_usec = maxi(worst_usec, horde.last_tick_usec)
	var after: float = mean_distance(horde, truck)
	check(after < before - 4.0, "the horde closes on the truck",
			"mean distance %.1f -> %.1f m over five seconds" % [before, after])
	check(total_usec / ticks < TICK_BUDGET_USEC, "a tick of %d zombies stays under budget" % COUNT,
			"%d us average, %d us worst" % [total_usec / ticks, worst_usec])
	var drawn: int = 0
	for mesh in horde.meshes:
		drawn += mesh.multimesh.visible_instance_count
	check(drawn > 0 and drawn <= COUNT, "the visible ones are drawn through the multimeshes",
			"%d instances across %d draw calls" % [drawn, horde.meshes.size()])

	# --- biting the hull
	var health_before: int = truck.health
	for i in 600:
		await get_tree().physics_frame
		if truck.health < health_before:
			break
	check(truck.health < health_before, "zombies at the hull bite the truck",
			"%d -> %d hp" % [health_before, truck.health])

	# --- a shot finds a zombie
	var from: Vector3 = truck.global_position + Vector3(0.0, 0.6, 0.0)
	var hit: Dictionary = Horde.hit_test(from, from + Vector3(0.0, 0.0, 30.0))
	if hit.is_empty():
		hit = Horde.hit_test(from, from + Vector3(30.0, 0.0, 0.0))
	check(not hit.is_empty(), "a hitscan along the ground finds a zombie", str(hit.get("distance", -1.0)))
	if not hit.is_empty():
		var alive_before: int = horde.alive_count
		var kills_before: int = horde.kills
		horde.damage(hit.index, AttackData.new(999, from, 0.0, truck), Vector3.FORWARD)
		check(horde.kills == kills_before + 1 and not horde.is_alive(hit.index),
				"enough damage kills it and counts the kill", "%d kills" % horde.kills)
		check(horde.alive_count == alive_before, "the corpse keeps its slot until it fades",
				str(horde.alive_count))

	# --- the moving hull flings what it hits
	var kills_before_ram: int = horde.kills
	truck.linear_velocity = Vector3(0.0, 0.0, 9.0)
	for i in 30:
		truck.linear_velocity = Vector3(0.0, 0.0, 9.0)
		await get_tree().physics_frame
	check(horde.kills > kills_before_ram, "the moving hull flings the zombies in its path",
			"%d flung" % (horde.kills - kills_before_ram))
	finish()


func mean_distance(p_horde: Horde, p_truck: Node3D) -> float:
	var total: float = 0.0
	var count: int = 0
	for i in p_horde.capacity:
		if p_horde.is_alive(i):
			total += p_horde.positions[i].distance_to(p_truck.global_position)
			count += 1
	return total / maxf(count, 1.0)
