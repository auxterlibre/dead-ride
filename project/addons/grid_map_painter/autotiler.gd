extends RefCounted
# Turns a per-column height field into KayKit Hill kit pieces across TWO
# GridMaps: FLOORS (walkable surfaces above the ground mesh - terrace shelves
# and each column's top) and WALLS (cliffs and the void-edge skirt). Splitting
# them lets any floor shape sit under any wall, with no baked combo items.
# Columns absent from the field are VOID; rims face them. The flat map floor
# is ONE mesh now (scripts/world/ground.gd), so its columns arrive as a
# Rect2i rather than as tiles to read back.

const VOID:int = -100
const NORTH:Vector2i = Vector2i(0, -1)
const SOUTH:Vector2i = Vector2i(0, 1)
const WEST:Vector2i = Vector2i(-1, 0)
const EAST:Vector2i = Vector2i(1, 0)

# Exposed-edge bitmask -> top/cliff letter position. Edges: 1=N 2=E 4=S 8=W.
# The strip/end/bend entries are carved ridge pieces from extract_ridges.gd.
const EDGE_PIECES:Dictionary = {
	1: "b_side", 2: "f_side", 4: "h_side", 8: "d_side",
	1 | 8: "a_outer_corner", 1 | 2: "c_outer_corner",
	4 | 8: "g_outer_corner", 4 | 2: "i_outer_corner",
	2 | 8: "strip_ns", 1 | 4: "strip_ew",
	1 | 2 | 8: "end_n", 2 | 4 | 8: "end_s", 1 | 4 | 8: "end_w", 1 | 2 | 4: "end_e",
}
# Diagonal bitmask (only when no edge is exposed) -> inner corner letter.
const DIAGONAL_PIECES:Dictionary = {
	1: "a_inner_corner", 2: "c_inner_corner", 4: "g_inner_corner", 8: "i_inner_corner",
}
# Outer corner -> the diagonal BEHIND its two connected arms. When that cell
# drops away too, the corner is a 1-wide L-bend and uses the elbow piece.
const BEND_DIAGONALS:Dictionary = {
	"a_outer_corner": Vector2i(1, 1), "c_outer_corner": Vector2i(-1, 1),
	"g_outer_corner": Vector2i(1, -1), "i_outer_corner": Vector2i(-1, -1),
}


# Height field from the floors map: Vector2i column -> level. Every column's
# highest floor is its top, so the max hill_top cell per column is the level.
# p_ground is the single ground mesh's footprint: those columns are level 0
# and carry no tile of their own, so nothing in the map can report them.
static func derive(p_floors:GridMap, p_ground:Rect2i = Rect2i()) -> Dictionary:
	var heights:Dictionary = {}
	for x in range(p_ground.position.x, p_ground.end.x):
		for z in range(p_ground.position.y, p_ground.end.y):
			heights[Vector2i(x, z)] = 0
	var library:MeshLibrary = p_floors.mesh_library
	for cell in p_floors.get_used_cells():
		var name:String = library.get_item_name(p_floors.get_cell_item(cell))
		var column:Vector2i = Vector2i(cell.x, cell.z)
		if name.begins_with("hill_top"):
			heights[column] = maxi(heights.get(column, cell.y), cell.y)
	return heights


static func level_of(p_heights:Dictionary, p_column:Vector2i) -> int:
	return p_heights.get(p_column, VOID)


# The columns whose pieces can change when p_dirty columns change height.
# Ring 2, not 1: a shelf floor's shape reads whether NEIGHBOR columns carry
# shelves, which their own neighbors decide - two cells out.
static func affected_columns(p_dirty:Array) -> Array:
	var seen:Dictionary = {}
	for column in p_dirty:
		for dx in range(-2, 3):
			for dz in range(-2, 3):
				seen[column + Vector2i(dx, dz)] = true
	return seen.keys()


# Cell names for every slot of p_columns, per map: {"floors": {cell: name},
# "walls": {cell: name}}, "" to clear. Scrubs [p_scrub_min, p_scrub_max].
static func retile(p_heights:Dictionary, p_columns:Array, p_scrub_min:int,
		p_scrub_max:int, p_ground:Rect2i = Rect2i()) -> Dictionary:
	# Skirts live at y -1 below any level range - always scrub them, or a
	# filled void neighbor leaves its old skirt behind.
	p_scrub_min = mini(p_scrub_min, -1)
	var floors:Dictionary = {}
	var walls:Dictionary = {}
	for column in p_columns:
		var parts:Dictionary = column_pieces(p_heights, column, p_ground)
		var slots:Array = parts.floors.keys() + parts.walls.keys()
		var bottom:int = slots.min() if not slots.is_empty() else p_scrub_min
		var top:int = slots.max() if not slots.is_empty() else p_scrub_max
		for y in range(mini(p_scrub_min, bottom), maxi(p_scrub_max, top) + 1):
			var cell:Vector3i = Vector3i(column.x, y, column.y)
			floors[cell] = parts.floors.get(y, "")
			walls[cell] = parts.walls.get(y, "")
	return {"floors": floors, "walls": walls}


# The y0 ground tile's shape: rims face VOID only - any land neighbor connects.
static func ground_shape(p_heights:Dictionary, p_column:Vector2i) -> String:
	return shape_for(p_column, func(p_neighbor:Vector2i) -> bool:
		return level_of(p_heights, p_neighbor) == VOID)


# One column's pieces: {"floors": {slot: name}, "walls": {slot: name}}. Land
# always keeps its y0 floor, terraces get shelf floors inside wall columns,
# and land bordering VOID grows a skirt wall below its ground tile.
static func column_pieces(p_heights:Dictionary, p_column:Vector2i,
		p_ground:Rect2i = Rect2i()) -> Dictionary:
	var level:int = level_of(p_heights, p_column)
	if level == VOID:
		return {"floors": {}, "walls": {}}
	var floors:Dictionary = {}
	var walls:Dictionary = {}
	var top_shape:String = ""
	if level >= 1:
		top_shape = slot_shape(p_heights, p_column, level - 1, true)
		floors[level] = "hill_top_" + top_shape
	# A stadium top's narrow walls sit inset from the cell boundary, so raised
	# neighbors can't seal its faces - the silhouette extends down instead.
	var stadium:bool = top_shape.begins_with("strip_") \
			or top_shape.begins_with("end_") or top_shape.begins_with("bend_")

	var wall_bottom:int = level
	var void_side:bool = false
	for side in [NORTH, EAST, SOUTH, WEST]:
		var neighbor:int = level_of(p_heights, p_column + side)
		if neighbor == VOID:
			void_side = true
			# A void side drops all the way: raised land at a map edge still
			# walls down to its y0 floor (the skirt only covers below y0).
			wall_bottom = 0
		else:
			wall_bottom = mini(wall_bottom, neighbor)
	var slot:int = maxi(wall_bottom, 0)
	while slot < level:
		var shape:String = top_shape if stadium \
				else slot_shape(p_heights, p_column, slot, false)
		var tall:bool = slot + 1 < level and (stadium \
				or slot_shape(p_heights, p_column, slot + 1, false) == shape)
		walls[slot] = cliff_name(shape, tall)
		slot += 2 if tall else 1
	# A neighbor terrace AT a slot's level runs visually under this column's
	# rim overhang - a shelf floor continues its surface in. Separate pass:
	# tall-merged walls skip slots, and shelves must not be skipped with them.
	for shelf_slot in range(maxi(wall_bottom, 1), level):
		if terrace_at(p_heights, p_column, shelf_slot):
			floors[shelf_slot] = "hill_top_" + floor_shape(p_heights, p_column, shelf_slot)

	# Land the ground mesh already covers needs no y0 tile - that IS the mesh.
	if not floors.has(0) and not p_ground.has_point(p_column):
		floors[0] = "hill_top_" + ground_shape(p_heights, p_column)
	if void_side:
		walls[-1] = cliff_name(ground_shape(p_heights, p_column), false)
	return {"floors": floors, "walls": walls}


static func terrace_at(p_heights:Dictionary, p_column:Vector2i, p_level:int) -> bool:
	for side in [NORTH, EAST, SOUTH, WEST]:
		if level_of(p_heights, p_column + side) == p_level:
			return true
	return false


# Whether the level-p_level floor surface continues at p_column: the terrace
# itself, any land at y0, or a wall column carrying a shelf at that level.
static func floor_at(p_heights:Dictionary, p_column:Vector2i, p_level:int) -> bool:
	var level:int = level_of(p_heights, p_column)
	if level == VOID:
		return false
	if p_level == 0 or level == p_level:
		return true
	return level > p_level and terrace_at(p_heights, p_column, p_level)


# A shelf floor's shape: rims wherever the surface it continues stops - over a
# drop OR against a wall whose column carries no shelf. Narrow terraces keep
# their strip/end/bend profiles this way.
static func floor_shape(p_heights:Dictionary, p_column:Vector2i, p_level:int) -> String:
	return shape_for(p_column, func(p_neighbor:Vector2i) -> bool:
		return not floor_at(p_heights, p_neighbor, p_level))


static func cliff_name(p_shape:String, p_tall:bool) -> String:
	var prefix:String = "hill_cliff_tall_" if p_tall else "hill_cliff_"
	return prefix + ("e" if p_shape == "e_cap" else p_shape)


# The A-I shape at a wall/rim slot: which sides drop below it there.
static func slot_shape(p_heights:Dictionary, p_column:Vector2i, p_slot:int,
		p_top:bool) -> String:
	var shape:String = shape_for(p_column, func(p_neighbor:Vector2i) -> bool:
		return level_of(p_heights, p_neighbor) <= p_slot)
	if shape == "e_center" and not p_top:
		return "e_cap"
	return shape


# Shared A-I table lookup: p_exposed tells whether a neighbor drops away.
static func shape_for(p_column:Vector2i, p_exposed:Callable) -> String:
	var edges:int = 0
	if p_exposed.call(p_column + NORTH):
		edges |= 1
	if p_exposed.call(p_column + EAST):
		edges |= 2
	if p_exposed.call(p_column + SOUTH):
		edges |= 4
	if p_exposed.call(p_column + WEST):
		edges |= 8

	if edges == 0:
		var diagonals:int = 0
		if p_exposed.call(p_column + NORTH + WEST):
			diagonals |= 1
		if p_exposed.call(p_column + NORTH + EAST):
			diagonals |= 2
		if p_exposed.call(p_column + SOUTH + WEST):
			diagonals |= 4
		if p_exposed.call(p_column + SOUTH + EAST):
			diagonals |= 8
		if diagonals == 0:
			return "e_center"
		if DIAGONAL_PIECES.has(diagonals):
			return DIAGONAL_PIECES[diagonals]
		# Several nicked corners at once - no kit piece; the least-wrong seal.
		return DIAGONAL_PIECES[1 << (int(log(diagonals) / log(2)))]
	if EDGE_PIECES.has(edges):
		var shape:String = EDGE_PIECES[edges]
		if BEND_DIAGONALS.has(shape) and p_exposed.call(p_column + BEND_DIAGONALS[shape]):
			return "bend_" + shape[0]
		return shape
	# Peninsulas and lone columns rim every side - the cap seals them.
	return "e_cap"


# Writes one map's retile output into its GridMap. Returns the previous cell
# items so the caller can register an undo step.
static func apply(p_gridmap:GridMap, p_cells:Dictionary) -> Dictionary:
	var library:MeshLibrary = p_gridmap.mesh_library
	var previous:Dictionary = {}
	for cell in p_cells:
		previous[cell] = p_gridmap.get_cell_item(cell)
		var name:String = p_cells[cell]
		if name == "":
			p_gridmap.set_cell_item(cell, GridMap.INVALID_CELL_ITEM)
			continue
		var item:int = library.find_item_by_name(name)
		if item == -1:
			push_warning("hill_painter: library has no piece named %s" % name)
			p_gridmap.set_cell_item(cell, GridMap.INVALID_CELL_ITEM)
		else:
			p_gridmap.set_cell_item(cell, item)
	return previous
