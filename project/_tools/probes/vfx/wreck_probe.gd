extends Node3D
# DBG probe: the car wreck's debris - hidden meshes (the stowed RoofRack)
# never spawn as scorched chunks, and exactly one burning cog rides the blast
# out faster than every body panel, trailing fire.

var passed: int = 0
var failed: int = 0


func _ready():
	ProbeBase.silence()  # Node3D, so it cannot inherit the mute
	var car: Vehicle = (load("res://scenes/vehicles/car.tscn") as PackedScene).instantiate()
	add_child(car)
	car.global_position = Vector3(0.0, 0.5, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var hidden: Array = []
	var visible_meshes: int = 0
	for instance in car.find_children("*", "MeshInstance3D", true, false):
		if not instance.mesh is ArrayMesh:
			continue
		if instance.is_visible_in_tree():
			visible_meshes += 1
		else:
			hidden.append(instance.mesh)
	check(hidden.size() > 0, "the car carries hidden meshes to guard against",
			"%d hidden (RoofRack), %d visible" % [hidden.size(), visible_meshes])

	car.damage.explode()
	await get_tree().process_frame

	var chunks: Array = []
	var cogs: Array = []
	for child in get_children():
		var piece: Debris = child as Debris
		if piece == null:
			continue
		if piece.flaming:
			cogs.append(piece)
		else:
			chunks.append(piece)
	check(chunks.size() == visible_meshes,
			"every visible piece and no other became debris",
			"%d chunks from %d visible meshes" % [chunks.size(), visible_meshes])
	var leaked: int = 0
	for piece in chunks:
		if piece.source_mesh in hidden:
			leaked += 1
	check(leaked == 0, "the hidden RoofRack stays out of the wreckage",
			"%d hidden meshes leaked" % leaked)

	check(cogs.size() >= 4 and cogs.size() <= 5,
			"a handful of burning cogs joins the blast", "%d cogs" % cogs.size())
	if cogs.size() >= 1:
		var slowest_lift: float = INF
		for cog in cogs:
			slowest_lift = minf(slowest_lift, cog.linear_velocity.y)
		var highest_chunk: float = 0.0
		for piece in chunks:
			highest_chunk = maxf(highest_chunk, piece.linear_velocity.y)
		check(slowest_lift > highest_chunk,
				"every cog climbs harder than any body panel",
				"%.1f m/s up vs the panels' %.1f" % [slowest_lift, highest_chunk])
		var cog: Debris = cogs[0]
		check(cog.trail != null and cog.trail.emitting
				and not cog.trail.local_coords,
				"and drags a world-space fire trail", "trail emitting")
		var cold: int = 0
		var shiny: int = 0
		for piece in chunks + cogs:
			var visual: MeshInstance3D = piece_visual(piece)
			if visual == null or visual.material_overlay == null \
					or visual.material_overlay.albedo_color.a < 0.5:
				cold += 1
			if visual == null or visual.material_override != Debris.char_material:
				shiny += 1
		check(cold == 0, "every piece leaves the blast glowing hot",
				"%d of %d spawned cold" % [cold, chunks.size() + cogs.size()])
		check(shiny == 0, "and every piece wears the char under the glow",
				"%d unblackened" % shiny)
		check(cog.source_mesh == load("res://assets/meshes/props/resource_bits/cog.tres"),
				"wearing the extracted cog mesh", str(cog.source_mesh.resource_path))

	print("DBG %d passed, %d failed" % [passed, failed])
	get_tree().quit()


func piece_visual(p_piece: Debris) -> MeshInstance3D:
	for child in p_piece.get_children():
		if child is MeshInstance3D:
			return child
	return null


func check(p_ok: bool, p_label: String, p_detail: String):
	if p_ok:
		passed += 1
	else:
		failed += 1
	print("DBG %s %s: %s" % ["PASS" if p_ok else "FAIL", p_label, p_detail])
