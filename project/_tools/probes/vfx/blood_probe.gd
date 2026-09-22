extends ProbeBase
# The gridded blood tiles: near drops coalesce in one tile, a border drop feeds
# both sides of the seam, distance or a terrace founds another tile, uniforms
# are per-tile, slots recycle, and empty tiles free themselves.


func _ready():
	# --- one drop founds the tile under it
	BloodPool.drop(self, Vector3.ZERO)
	check(BloodPool.tiles.size() == 1, "first drop founds a tile",
			"%d tiles" % BloodPool.tiles.size())
	var pool: BloodPool = BloodPool.tiles.get(Vector3i.ZERO)
	check(pool != null and pool.global_position.distance_to(Vector3(0.0, 0.03, 0.0)) < 0.01,
			"the plane sits on the tile centre", str(pool.global_position) if pool else "-")
	check(pool.positions[0].distance_to(Vector2(0.5, 0.5)) < 0.01,
			"a centre drop lands mid-plane", str(pool.positions[0]))

	# --- a second drop nearby joins it, offset in UV
	BloodPool.drop(self, Vector3(1.5, 0.0, 0.0))
	check(BloodPool.tiles.size() == 1, "a near drop joins the same tile",
			"%d tiles" % BloodPool.tiles.size())
	check(pool.positions[1].distance_to(Vector2(0.75, 0.5)) < 0.01,
			"offset drop maps to plane UV", str(pool.positions[1]))

	# --- a drop whose skirt crosses the border feeds both tiles
	BloodPool.drop(self, Vector3(2.9, 0.0, 20.0))
	var left: BloodPool = BloodPool.tiles.get(Vector3i(0, 0, 3))
	var right: BloodPool = BloodPool.tiles.get(Vector3i(1, 0, 3))
	check(left != null and right != null, "a border drop lands in both tiles",
			"%d tiles" % BloodPool.tiles.size())
	check(left != null and right != null \
			and left.busy.count(true) == 1 and right.busy.count(true) == 1,
			"one slot each side of the seam", "%d + %d" % [
			left.busy.count(true) if left else -1, right.busy.count(true) if right else -1])

	# --- distance founds its own tile; per-instance uniforms stay apart
	BloodPool.drop(self, Vector3(10.0, 0.0, 0.0))
	var far: BloodPool = BloodPool.tiles.get(Vector3i(2, 0, 0))
	check(far != null, "a far drop founds its own tile",
			"%d tiles" % BloodPool.tiles.size())
	check(far.blood != pool.blood, "each tile owns its material",
			"shared" if far.blood == pool.blood else "separate")

	# --- a terrace two metres up must not stain the ground tile below
	BloodPool.drop(self, Vector3(0.0, 2.0, 0.0))
	check(BloodPool.tiles.has(Vector3i(0, 2, 0)),
			"a drop on a terrace founds its own tile",
			"%d tiles" % BloodPool.tiles.size())

	# --- tween ticks must reach the GPU-bound array, not a copy
	await get_tree().create_timer(0.4).timeout
	var pushed: PackedFloat32Array = pool.blood.get_shader_parameter("scales")
	check(pushed[0] > 0.05, "a grown drop shows in the material uniform",
			"scales[0] = %.3f" % pushed[0])
	var far_pushed: PackedFloat32Array = far.blood.get_shader_parameter("scales")
	check(far_pushed[1] <= 0.01, "the far tile never saw the near tile's drops",
			"scales[1] = %.3f" % far_pushed[1])

	# --- flooding past the slot count is silently absorbed
	for i in 40:
		BloodPool.drop(self, Vector3(60.0, 0.0, 60.0))
	var flooded: BloodPool = BloodPool.tiles.get(Vector3i(10, 0, 10))
	check(flooded != null and flooded.busy.count(true) == BloodPool.MAX_DROPS,
			"drops past the slot count are dropped",
			"%d busy" % (flooded.busy.count(true) if flooded else -1))

	# --- a dried-out tile frees itself and releases its registry entry
	var quick: BloodPool = load("res://scenes/vfx/blood_pool.tscn").instantiate()
	quick.grow_time = 0.05
	quick.hold_time = 0.1
	quick.dry_time = 0.05
	quick.tile_key = Vector3i(13, 0, 13)
	BloodPool.tiles[quick.tile_key] = quick
	add_child(quick)
	quick.global_position = Vector3(78.0, 0.03, 78.0)
	quick.add_drop(Vector3(78.0, 0.0, 78.0), 0.2)
	await get_tree().create_timer(0.6).timeout
	check(not is_instance_valid(quick), "a dried-out tile frees itself",
			"still alive" if is_instance_valid(quick) else "freed")
	check(not BloodPool.tiles.has(Vector3i(13, 0, 13)),
			"and leaves the registry", "%d tiles" % BloodPool.tiles.size())

	# --- the FleshImpact route: the spray node drops blood where droplets land
	# (landings sit on tile centres so the satellite scatter stays one-tile and
	# the busy deltas below are exact)
	var before: int = total_busy()
	var impact: FleshImpact = FleshImpact.new()
	impact.setup(Vector3(34.0, 1.1, 30.0), Vector3(1.0, 0.0, 0.0), 0.0, 2)
	add_child(impact)
	await get_tree().create_timer(0.7).timeout
	check(BloodPool.tiles.has(Vector3i(6, 0, 5)),
			"a flesh hit pools where the droplets land",
			"%d tiles" % BloodPool.tiles.size())
	check(total_busy() - before == 2, "a graze splashes two droplets",
			"%d new" % (total_busy() - before))

	# --- and damage nudges the droplet count up
	before = total_busy()
	var heavy: FleshImpact = FleshImpact.new()
	heavy.setup(Vector3(34.0, 1.1, 42.0), Vector3(1.0, 0.0, 0.0), 0.0, 17)
	add_child(heavy)
	await get_tree().create_timer(0.7).timeout
	check(total_busy() - before == 5, "a heavy hit splashes five",
			"%d new" % (total_busy() - before))

	finish()


func total_busy() -> int:
	var count: int = 0
	for pool in BloodPool.tiles.values():
		count += pool.busy.count(true)
	return count
