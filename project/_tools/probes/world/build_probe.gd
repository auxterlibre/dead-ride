extends ProbeBase
# DBG probe: the placement grid - cell/world round trips, rotated footprints,
# occupancy and ground and obstruction refusals, the purse, and the save rows
# that carry each placed building's own state back.


func _ready():
	var game: Node = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	for i in 6:
		await get_tree().process_frame
	# From the SCENE, by type - not Globals.build_grid, which would make the
	# registration check below compare the singleton to itself.
	var grid: BuildGrid = find_first(game, "BuildGrid")
	var plot: BuildableData = load("res://data/buildables/crop_plot.tres")
	var barrel: BuildableData = load("res://data/buildables/fuel_barrel.tres")
	check(grid != null and grid.catalogue.size() >= 2,
			"the game scene carries a stocked build grid",
			"%d buildables" % (0 if grid == null else grid.catalogue.size()))
	check(Globals.build_grid == grid, "and it registers itself", "registered")

	# --- a cell owns the ground under its own centre, both ways
	var cell: Vector2i = Vector2i(-8, 12)
	var centre: Vector3 = grid.world_of(cell, Vector2i.ONE)
	check(grid.cell_of(centre) == cell, "a cell centre lands back in its cell",
			"%s -> %s" % [centre, grid.cell_of(centre)])
	check(is_equal_approx(centre.x, -11.25) and is_equal_approx(centre.z, 18.75),
			"cells are 1.5m and centred", str(centre))

	# --- a quarter turn swaps the footprint, a half turn does not
	var shed: BuildableData = BuildableData.new()
	shed.footprint = Vector2i(2, 1)
	check(grid.rotated_size(shed, 90) == Vector2i(1, 2) \
			and grid.rotated_size(shed, 180) == Vector2i(2, 1),
			"a quarter turn swaps the footprint, a half turn does not",
			"%s / %s" % [grid.rotated_size(shed, 90), grid.rotated_size(shed, 180)])
	check(grid.cells_for(shed, Vector2i.ZERO, 0).size() == 2,
			"a 2x1 covers two cells", str(grid.cells_for(shed, Vector2i.ZERO, 0)))

	# --- open flat sand takes a building; the same cell then refuses
	var spot: Vector2i = Vector2i(14, -14)  # open desert, clear of the station
	PlayerData.current_money = 1000
	check(grid.can_place(plot, spot, 0), "open flat sand is buildable", str(spot))
	var built: Node3D = grid.place(plot, spot, 0)
	check(built is CropPlot and built.spots.size() == 1,
			"the plot goes down with its spot ready", str(built))
	check(not grid.can_place(barrel, spot, 0),
			"and the cell it stands on is taken", "occupied")
	check(grid.placed_at(spot) == built, "the grid knows what stands there",
			str(grid.placed_at(spot)))

	# --- off the map there is no ground to build on
	check(not grid.can_place(plot, Vector2i(400, 400), 0),
			"the void refuses a foundation", "no ground")

	# --- a body in the way blocks it
	var player: Character = InputManager.player
	var occupied: Vector2i = Vector2i(20, -20)
	player.global_position = grid.world_of(occupied, Vector2i.ONE)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(not grid.can_place(plot, occupied, 0),
			"a body standing there blocks it", "blocked")
	player.global_position = Vector3(0.0, 0.0, 40.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(grid.can_place(plot, occupied, 0),
			"and it clears once they walk away", "clear")

	# --- the FOURTH refusal: a bare marker's ground is claimed too. A crop
	# spot has no collider for the obstruction box to see, which is how a
	# barrel got set down on a planted crop.
	var marker: CropSpot = find_first(get_tree().current_scene, "CropSpot")
	if check(marker != null, "the map carries a crop spot to refuse", str(marker)):
		check(not grid.can_place(plot, grid.cell_of(marker.global_position), 0),
				"colliderless claimed ground refuses a building", "refused")

	# --- demolition frees the cell again
	check(grid.demolish(spot) and grid.placed_at(spot) == null,
			"demolishing frees the cell", "cleared")
	check(grid.can_place(plot, spot, 0), "which is buildable once more", "free")

	# --- the save carries the building AND its own state back
	var barrel_cell: Vector2i = Vector2i(16, -16)
	var placed: FuelBarrel = grid.place(barrel, barrel_cell, 90)
	placed.current_fuel = 23.0
	var rows: Dictionary = grid.save_state()
	# By CELL, not by count: the grid's ledger also carries the map's adopted
	# barrel now, so this probe's row is the one at its own cell.
	var mine: Array = rows.placed.filter(
			func(p_row): return p_row.cell == [barrel_cell.x, barrel_cell.y])
	check(mine.size() == 1 and mine[0].has("state"),
			"a placed building saves with its own state nested",
			str(mine))
	grid.demolish(barrel_cell)
	await get_tree().process_frame
	grid.load_state(rows)
	var reloaded: FuelBarrel = grid.placed_at(barrel_cell)
	check(reloaded != null and is_equal_approx(reloaded.current_fuel, 23.0),
			"and comes back standing where it was, still part full",
			"%.1fL" % (0.0 if reloaded == null else reloaded.current_fuel))

	finish()
