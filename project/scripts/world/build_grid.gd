class_name BuildGrid
extends Node3D

const CELL: float = 1.5  # m per cell; half a terrain cell, so the two align
const GROUND_MASK: int = 16  # the map floor
const BLOCK_MASK: int = 108  # walls | car | player body | enemy body
const LEVEL_TOLERANCE: float = 0.25  # m of slope a cell may have and still build
const CLEARANCE: float = 1.0  # m of air the obstruction test looks through

@export var catalogue: Array[BuildableData] = []

var occupancy: Dictionary = {}  # Vector2i -> the placed node standing on it
var placements: Array = []  # {data, cell, yaw, node}, in placement order


func _ready():
	add_to_group("persistent")
	Globals.build_grid = self
	adopt_children()


# Authored buildables live in the editor as ordinary children - the designer
# drags a barrel where it should stand - and the grid ADOPTS them at load into
# the same books a runtime placement gets, snapped to the cell they nearly
# stand on. From there pickup, demolition and the save treat them exactly like
# anything built. An adopted child LEAVES the persistent group: the grid's
# ledger saves it now, and a row in both would spawn twins on load.
func adopt_children():
	for child in get_children():
		if not child is Node3D:
			continue
		var data: BuildableData = data_for(child)
		if data == null:
			continue
		var yaw: int = wrapi(roundi(rad_to_deg(child.rotation.y) / 90.0) * 90, 0, 360)
		var size: Vector2i = rotated_size(data, yaw)
		var cell: Vector2i = Vector2i(
				roundi(child.global_position.x / CELL - size.x * 0.5),
				roundi(child.global_position.z / CELL - size.y * 0.5))
		child.global_position = world_of(cell, size)
		child.rotation.y = deg_to_rad(yaw)
		child.remove_from_group("persistent")
		for taken in cells_for(data, cell, yaw):
			occupancy[taken] = child
		placements.append({"data": data, "cell": cell, "yaw": yaw, "node": child})


# The catalogue entry whose scene authored this node, or null for strangers.
func data_for(p_node: Node) -> BuildableData:
	for entry in catalogue:
		if entry.scene and p_node.scene_file_path == entry.scene.resource_path:
			return entry
	return null


# A preview is MESHES, nothing else. Disabling and zeroing colliders is not
# enough: scripts still run _ready on add_child, and the self-registering
# pieces (InteractiveArea into the offers registry, CoolArea into the heat
# pockets, a barrel into chill_source) would give a ghost a working "Pick up"
# prompt and a cool shadow. Stripping every script BEFORE the tree sees it is
# what makes a ghost inert by construction.
static func make_ghost(p_scene: PackedScene) -> Node3D:
	var ghost: Node3D = p_scene.instantiate()
	ghost.set_script(null)
	for node in ghost.find_children("*", "", true, false):
		node.set_script(null)
	for body in ([ghost] if ghost is CollisionObject3D else []) \
			+ ghost.find_children("*", "CollisionObject3D", true, false):
		body.collision_layer = 0
		body.collision_mask = 0
	ghost.process_mode = Node.PROCESS_MODE_DISABLED
	return ghost


# The green/red wash both ghost owners tint with.
static func tint_ghost(p_ghost: Node3D) -> StandardMaterial3D:
	var tint: StandardMaterial3D = StandardMaterial3D.new()
	tint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for mesh in p_ghost.find_children("*", "MeshInstance3D", true, false):
		mesh.material_overlay = tint
	return tint


func cell_of(p_world: Vector3) -> Vector2i:
	return Vector2i(floori(p_world.x / CELL), floori(p_world.z / CELL))


# The centre of a FOOTPRINT rooted at p_cell, which is what the placed node
# sits on - a 2x1 shed straddles its two cells rather than perching on one.
func world_of(p_cell: Vector2i, p_size: Vector2i) -> Vector3:
	return Vector3((float(p_cell.x) + p_size.x * 0.5) * CELL, 0.0,
			(float(p_cell.y) + p_size.y * 0.5) * CELL)


# Quarter turns swap the footprint; everything else reads the rotated size
# rather than re-deriving the turn.
func rotated_size(p_data: BuildableData, p_yaw: int) -> Vector2i:
	var size: Vector2i = p_data.footprint
	return Vector2i(size.y, size.x) if p_yaw % 180 != 0 else size


func cells_for(p_data: BuildableData, p_cell: Vector2i, p_yaw: int) -> Array:
	var size: Vector2i = rotated_size(p_data, p_yaw)
	var result: Array = []
	for x in size.x:
		for y in size.y:
			result.append(p_cell + Vector2i(x, y))
	return result


func can_place(p_data: BuildableData, p_cell: Vector2i, p_yaw: int) -> bool:
	if p_data == null or p_data.scene == null:
		return false
	for cell in cells_for(p_data, p_cell, p_yaw):
		if occupancy.has(cell) or not level_ground(cell):
			return false
	return not obstructed(p_data, p_cell, p_yaw) \
			and not marked_ground(p_data, p_cell, p_yaw)


# The FOURTH refusal: props with no collider to be found by - a crop spot is
# a bare marker - already announce themselves through the no_grass group for
# the grass clearance, and the same declaration makes their cell no building
# site. The obstruction box cannot see them, which is how a barrel got set
# down on top of a planted crop.
func marked_ground(p_data: BuildableData, p_cell: Vector2i, p_yaw: int) -> bool:
	var cells: Array = cells_for(p_data, p_cell, p_yaw)
	for prop in get_tree().get_nodes_in_group(GrassField.NO_GRASS):
		# A demolished plot's SPOT stays in the group until the free lands at
		# frame's end - and it is the plot ROOT that is queued, so the whole
		# ancestry answers for whether this claim is dying.
		if dying(prop) or not prop is Node3D:
			continue
		if cells.has(cell_of(prop.global_position)):
			return true
	return false


func dying(p_node: Node) -> bool:
	var walk: Node = p_node
	while walk:
		if walk.is_queued_for_deletion():
			return true
		walk = walk.get_parent()
	return false


# Flat map floor only: a cell over a terrace, a cliff or the void is not a
# building site, and the height test is what says so.
func level_ground(p_cell: Vector2i) -> bool:
	var centre: Vector3 = world_of(p_cell, Vector2i.ONE)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			centre + Vector3.UP * 4.0, centre + Vector3.DOWN * 4.0, GROUND_MASK)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and absf(hit.position.y) < LEVEL_TOLERANCE


# A box of air over the footprint. It starts ABOVE the floor on purpose: the
# ground carries the walls layer too, so a box touching it reads as a wall.
func obstructed(p_data: BuildableData, p_cell: Vector2i, p_yaw: int) -> bool:
	var size: Vector2i = rotated_size(p_data, p_yaw)
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(size.x * CELL * 0.9, CLEARANCE, size.y * CELL * 0.9)
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.collision_mask = BLOCK_MASK
	query.transform = Transform3D(Basis(), world_of(p_cell, size)
			+ Vector3.UP * (CLEARANCE * 0.5 + 0.05))
	return not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func place(p_data: BuildableData, p_cell: Vector2i, p_yaw: int) -> Node3D:
	if not can_place(p_data, p_cell, p_yaw):
		return null
	var node: Node3D = p_data.scene.instantiate()
	add_child(node)
	node.global_position = world_of(p_cell, rotated_size(p_data, p_yaw))
	node.rotation.y = deg_to_rad(p_yaw)
	for cell in cells_for(p_data, p_cell, p_yaw):
		occupancy[cell] = node
	placements.append({"data": p_data, "cell": p_cell, "yaw": p_yaw, "node": node})
	Signals.structure_changed.emit(node.global_position)
	return node


func demolish(p_cell: Vector2i) -> bool:
	var node: Node3D = occupancy.get(p_cell)
	if node == null:
		return false
	forget(node)
	var stood: Vector3 = node.global_position
	node.queue_free()
	Signals.structure_changed.emit(stood)
	return true


# Pickup's half of a demolition: the books drop the node but the node lives
# on - carried away, or lingering as its own fading chill.
func forget(p_node: Node3D):
	for i in range(placements.size() - 1, -1, -1):
		if placements[i].node == p_node:
			placements.remove_at(i)
	for cell in occupancy.keys():
		if occupancy[cell] == p_node:
			occupancy.erase(cell)


func placed_at(p_cell: Vector2i) -> Node3D:
	return occupancy.get(p_cell)


# Placed buildings are RUNTIME children, which the save's authored-nodes rule
# cannot see - so the grid serialises them, nesting whatever state each one
# keeps for itself (a barrel's fuel, a plot's crops) the way CropPlot does.
func save_state() -> Dictionary:
	var rows: Array = []
	for entry in placements:
		if not is_instance_valid(entry.node):
			continue
		var row: Dictionary = {"id": entry.data.resource_path,
				"cell": [entry.cell.x, entry.cell.y], "yaw": entry.yaw}
		if entry.node.has_method("save_state"):
			row["state"] = entry.node.save_state()
		rows.append(row)
	return {"placed": rows}


func load_state(p_state: Dictionary):
	for entry in placements:
		if is_instance_valid(entry.node):
			entry.node.queue_free()
	placements.clear()
	occupancy.clear()
	for row in p_state.placed:
		var data: BuildableData = load(str(row.id)) as BuildableData
		if data == null:
			continue
		var node: Node3D = place(data,
				Vector2i(int(row.cell[0]), int(row.cell[1])), int(row.yaw))
		if node and row.has("state") and node.has_method("load_state"):
			node.load_state(row.state)
