extends ProbeBase
# DBG probe: grass grows in the cool pockets and dies back with them.

@onready var GAME: PackedScene = load("uid://b56i3a2diovj6")  # scenes/game.tscn


func _ready():
	var game: Node = GAME.instantiate()
	add_child(game)
	await settle(8)
	var field: GrassField = find_first(game, "GrassField")
	var barrel: FuelBarrel = find_first(game, "FuelBarrel")
	if not check(field != null and barrel != null, "the map carries a field and a pocket",
			"%s / %s" % [field, barrel]):
		finish()
		return
	barrel.warmth = 1.0  # the slow cold-in is carry_probe's subject, not ours

	check(field.patches.size() >= 2, "every cool pocket got a patch",
			"%d patches for %d sources" % [field.patches.size(),
			get_tree().get_nodes_in_group("chill_source").size()])

	var home: Vector3 = barrel.global_position  # the map's own spot, moved about below
	var patch: Dictionary = patch_for(field, barrel)
	if not check(not patch.is_empty() and patch.points.size() > 0,
			"the barrel's pocket was sown", "%d tufts" % patch.points.size()):
		finish()
		return

	# Nothing may grow outside the pocket it belongs to.
	var radius: float = barrel.chill_radius()
	var strays: int = 0
	var floating: int = 0
	for spot in patch.points:
		var flat: Vector2 = Vector2(spot.x - barrel.global_position.x,
				spot.z - barrel.global_position.z)
		if flat.length() > radius + 0.01:
			strays += 1
		if absf(spot.y - barrel.global_position.y) > 2.0:
			floating += 1
	check(strays == 0, "no tuft grows outside the pocket", "%d strays" % strays)
	check(floating == 0, "and every tuft sits on the ground it was rayed onto",
			"%d floating" % floating)

	# Thicker where the wet is: the inner half of the disc has to beat the
	# outer ring per square metre, which an even scatter would not.
	var inner: int = 0
	for spot in patch.points:
		if Vector2(spot.x - barrel.global_position.x,
				spot.z - barrel.global_position.z).length() < radius * 0.5:
			inner += 1
	var outer: int = patch.points.size() - inner
	var inner_area: float = PI * pow(radius * 0.5, 2.0)
	check(inner / inner_area > outer / (PI * radius * radius - inner_area) * 1.5,
			"the pocket is thicker at its middle",
			"%.2f against %.2f tufts/m2" % [inner / inner_area,
			outer / (PI * radius * radius - inner_area)])

	# --- solid things keep their footing, collider or not
	var pump: GasPump = find_first(game, "GasPump")
	var plot_spot: CropSpot = find_first(game, "CropSpot")
	if check(pump != null and plot_spot != null,
			"the map carries a pump and a crop spot", "%s / %s" % [pump, plot_spot]):
		barrel.global_position = pump.global_position + Vector3(3.0, 0.0, 0.0)
		field.claim_pockets()
		# Crowded candidates are KEPT as dead tufts now - what must never
		# happen is one of them being ALIVE against the pump or the plot.
		var near: Dictionary = patch_for(field, barrel)
		var crowded: int = 0
		for i in near.points.size():
			if near.alive[i] and (flat(near.points[i], pump.global_position) \
					< field.clearance
					or flat(near.points[i], plot_spot.global_position) \
					< field.clearance):
				crowded += 1
		check(crowded == 0, "nothing grows up against a pump or through a plot",
				"%d live tufts inside the clearance" % crowded)

	# --- building on a pocket clears the grass it stands on, and back again
	var grid: BuildGrid = Globals.build_grid
	if check(grid != null and not grid.catalogue.is_empty(),
			"the grid carries something to build", str(grid)):
		barrel.global_position = home  # back where the map put it: known good sand
		field.claim_pockets()
		var before: int = alive_count(patch_for(field, barrel))
		# Build a BARREL on a LIVE tuft that hugs its cell's centre, hunted
		# from the patch: fixed offsets once landed on bare sand when the
		# grid-snap moved the patch seed 8cm, and a crop plot's clearance
		# point can land a whole diagonal from the tuft that chose the cell -
		# the hull at the centre within reach of its tuft makes the kill CERTAIN.
		var pocket: Dictionary = patch_for(field, barrel)
		var cell: Vector2i = Vector2i.ZERO
		var built: Node3D = null
		for i in pocket.points.size():
			if not pocket.alive[i]:
				continue
			cell = grid.cell_of(pocket.points[i])
			if flat(pocket.points[i], grid.world_of(cell, Vector2i.ONE)) \
					< field.clearance * 0.7 \
					and grid.can_place(grid.catalogue[1], cell, 0):
				built = grid.place(grid.catalogue[1], cell, 0)
				break
		await settle(2)
		var after: int = alive_count(patch_for(field, barrel))
		var under: int = 0
		for i in pocket.points.size():
			if built and pocket.alive[i] \
					and flat(pocket.points[i], built.global_position) < field.clearance:
				under += 1
		check(built != null and before > 0 and after < before and under == 0,
				"a building placed in a pocket marks the grass under it to die",
				"%d live, was %d, %d live under it" % [after, before, under])
		# The POINTS never re-roll - the same tufts fade, not new ones popping.
		check(patch_for(field, barrel).points.size() == pocket.points.size(),
				"without the layout re-rolling under it",
				"%d candidates held" % pocket.points.size())
		grid.demolish(cell)
		await settle(2)
		check(alive_count(patch_for(field, barrel)) == before,
				"and pulling it down lets the same grass back",
				"%d live against the %d before" % [
				alive_count(patch_for(field, barrel)), before])

	# --- the tarmac grows nothing
	var road: Node3D = Globals.road_network
	if check(road != null, "the map carries a road to refuse", str(road)):
		var open: int = patch.points.size()
		barrel.global_position = road.nearest_center(barrel.global_position) \
				+ Vector3(0.0, 0.0, 0.5)
		field.claim_pockets()
		patch = patch_for(field, barrel)
		var paved: int = 0
		for spot in patch.points:
			if surface_at(spot) != "sand":
				paved += 1
		check(paved == 0, "no tuft roots in anything but sand",
				"%d on other ground" % paved)
		check(patch.points.size() < open,
				"and a pocket straddling the road grows less for it",
				"%d tufts against %d in the open" % [patch.points.size(), open])

	# Growth is a climb, not a snap: the barrel is full, so it thickens.
	await grow(field, 4.0)
	var climbed: float = grown_mean(patch)
	check(climbed > 0.1 and climbed <= 1.0,
			"a full barrel grows its patch in", "growth %.2f" % climbed)
	check(drawn(field) > 0, "and the tufts are actually drawn",
			"%d instances" % drawn(field))

	# One blade crossing the cull must re-deal NOBODY else: the variant is the
	# tuft's own, fixed at sow. Dealt by draw order it shuffled the whole
	# field every time a single tuft faded past the threshold.
	var counts_before: Array = bucket_counts(field)
	for i in patch.points.size():
		if patch.alive[i] and patch.grown[i] > 0.5:
			patch.grown[i] = 0.0
			field.rebuild()
			var killed: int = patch.variant[i] % field.meshes.size()
			var counts_after: Array = bucket_counts(field)
			var held: bool = true
			for m in counts_before.size():
				var expect: int = counts_before[m] - (1 if m == killed else 0)
				held = held and counts_after[m] == expect
			check(held, "one blade fading re-deals nobody else",
					"%s -> %s, variant %d" % [counts_before, counts_after, killed])
			patch.grown[i] = 1.0
			field.rebuild()
			break

	# Run it dry and the patch goes with it - the ground drying out is the tell.
	var thick: int = drawn(field)
	barrel.current_fuel = 0.0
	check(barrel.chill_strength() == 0.0, "an empty barrel stops venting",
			"chill %.2f" % barrel.chill_strength())
	await grow(field, 8.0)
	check(grown_mean(patch) < 0.05 and drawn(field) < thick,
			"and its grass dies back with it",
			"growth %.2f, %d of %d left" % [grown_mean(patch), drawn(field), thick])
	finish()


func bucket_counts(p_field: GrassField) -> Array:
	var counts: Array = []
	for mesh in p_field.meshes:
		counts.append(mesh.multimesh.instance_count)
	return counts


func alive_count(p_patch: Dictionary) -> int:
	var total: int = 0
	for flag in p_patch.alive:
		if flag:
			total += 1
	return total


# Mean growth of the LIVE tufts - the dead ones head for zero by design.
func grown_mean(p_patch: Dictionary) -> float:
	var total: float = 0.0
	var live: int = 0
	for i in p_patch.grown.size():
		if p_patch.alive[i]:
			total += p_patch.grown[i]
			live += 1
	return total / live if live > 0 else 0.0


func flat(p_a: Vector3, p_b: Vector3) -> float:
	return Vector2(p_a.x - p_b.x, p_a.z - p_b.z).length()


func surface_at(p_spot: Vector3) -> String:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			p_spot + Vector3.UP * 1.0, p_spot + Vector3.DOWN * 1.0,
			GrassField.GROUND_MASK)
	var hit: Dictionary = get_viewport().world_3d.direct_space_state.intersect_ray(query)
	if not hit or not hit.collider.has_meta("surface"):
		return ""
	return String(hit.collider.get_meta("surface"))


func patch_for(p_field: GrassField, p_source: Node) -> Dictionary:
	for patch in p_field.patches:
		if patch.source == p_source:
			return patch
	return {}


func drawn(p_field: GrassField) -> int:
	var total: int = 0
	for mesh in p_field.meshes:
		total += mesh.multimesh.instance_count
	return total


# Steps the field's own easing without waiting the seconds out.
func grow(p_field: GrassField, p_seconds: float):
	for i in int(p_seconds / 0.1):
		p_field._process(0.1)
	await settle(2)
