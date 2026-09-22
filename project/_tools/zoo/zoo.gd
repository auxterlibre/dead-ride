@tool
extends Node3D

const MESH_ROOT: String = "res://assets/meshes"
const KITS: Dictionary = {
	"junkyard": PI,
	"apocalypse": PI,
	"apocalypse_weapons": PI / 2.0,
	"zombies": PI,
}
const ISLANDS: Array = ["characters", "weapons", "vehicles", "vegetation", "buildings",
		"terrain", "machines", "props"]
const DEFAULT_ISLAND: String = "props"
const KIT_ISLAND: Dictionary = {"apocalypse_weapons": "weapons", "zombies": "weapons"}
const FAMILY_ISLAND: Dictionary = {
	"zombies/skeleton": "characters",
	"apocalypse/adult": "characters",
	"apocalypse/doberman": "characters",
	"apocalypse/katana": "weapons",
	"apocalypse/pistol": "weapons",
	"apocalypse/apocalypse": "vehicles",
	"junkyard/car": "vehicles",
	"junkyard/wreck_car": "vehicles",
	"junkyard/school_bus": "vehicles",
	"junkyard/forklift": "vehicles",
	"junkyard/cart": "vehicles",
	"junkyard/bonnet": "vehicles",
	"junkyard/car_door": "vehicles",
	"junkyard/car_number": "vehicles",
	"junkyard/car_seat": "vehicles",
	"junkyard/wheels": "vehicles",
	"junkyard/tire": "vehicles",
	"junkyard/tires": "vehicles",
	"junkyard/acacia": "vegetation",
	"junkyard/bush": "vegetation",
	"junkyard/cactus": "vegetation",
	"junkyard/deadwood": "vegetation",
	"junkyard/grass": "vegetation",
	"apocalypse/pine": "vegetation",
	"junkyard/building": "buildings",
	"junkyard/cabin": "buildings",
	"junkyard/factory": "buildings",
	"junkyard/entry": "buildings",
	"junkyard/wall": "buildings",
	"junkyard/pillar": "buildings",
	"junkyard/water_tower": "buildings",
	"junkyard/toilet": "buildings",
	"junkyard/container": "buildings",
	"junkyard/billboard": "buildings",
	"junkyard/fence": "buildings",
	"junkyard/barrier": "buildings",
	"junkyard/ground": "terrain",
	"junkyard/mountain": "terrain",
	"junkyard/rock": "terrain",
	"junkyard/sand": "terrain",
	"junkyard/stone": "terrain",
	"junkyard/road": "terrain",
	"apocalypse/road": "terrain",
	"apocalypse/concrete": "terrain",
	"junkyard/claw_crane": "machines",
	"junkyard/magnet_crane": "machines",
	"junkyard/car_press": "machines",
	"junkyard/shredder": "machines",
}
const LABEL_SIZE: float = 0.18
const LABEL_FRONT: float = 1.0
const LABEL_LIFT: float = 0.02
const MIN_CELL: float = 2.5
const ROW_GAP: float = 3.0
const FAMILY_GAP: float = 6.0
const ISLAND_GAP: float = 24.0
const ISLAND_COLUMNS: int = 3
const GROUND_MARGIN: float = 20.0
const TITLE_FRONT: float = 3.0

@export var row_width: float = 80.0
@export var gap: float = 1.5
@export_tool_button("Rebuild zoo") var rebuild_action: Callable = build


func _ready():
	build()


func build():
	if not is_node_ready():
		return
	var old: Node = get_node_or_null("Exhibits")
	if old:
		remove_child(old)
		old.queue_free()
	var exhibits: Node3D = Node3D.new()
	exhibits.name = "Exhibits"
	add_child(exhibits)
	var groups: Dictionary = {}
	for kit in KITS:
		collect(kit, groups)
	var column: int = 0
	var x: float = 0.0
	var z: float = 0.0
	var row_depth: float = 0.0
	var far: Vector2 = Vector2.ZERO
	for island in ISLANDS:
		if not groups.has(island):
			continue
		var depth: float = add_island(exhibits, island, groups[island], Vector3(-x, 0.0, z))
		row_depth = maxf(row_depth, depth)
		far = Vector2(maxf(far.x, x + row_width), z + row_depth)
		column += 1
		x += row_width + ISLAND_GAP
		if column == ISLAND_COLUMNS:
			column = 0
			x = 0.0
			z += row_depth + ISLAND_GAP
			row_depth = 0.0
	fit_ground(far)


func collect(p_kit: String, p_groups: Dictionary) -> void:
	var dir: String = MESH_ROOT.path_join(p_kit)
	if not DirAccess.dir_exists_absolute(dir):
		return
	for family in DirAccess.get_directories_at(dir):
		var entries: Array = exhibits_in(dir.path_join(family), KITS[p_kit])
		if entries.is_empty():
			continue
		var island: String = FAMILY_ISLAND.get("%s/%s" % [p_kit, family],
				KIT_ISLAND.get(p_kit, DEFAULT_ISLAND))
		var families: Dictionary = p_groups.get_or_add(island, {})
		families.get_or_add(family, []).append_array(entries)


func add_island(p_parent: Node3D, p_name: String, p_families: Dictionary,
		p_position: Vector3) -> float:
	var island: Node3D = Node3D.new()
	island.name = p_name
	island.position = p_position
	p_parent.add_child(island)
	island.add_child(label(p_name.capitalize(),
			Vector3(2.0, LABEL_LIFT, -TITLE_FRONT * 2.0), LABEL_SIZE * 4.0))
	var names: Array = p_families.keys()
	names.sort()
	var depth: float = 0.0
	for family in names:
		depth = add_family(island, family, p_families[family], depth)
	return depth


func add_family(p_parent: Node3D, p_family: String, p_entries: Array, p_depth: float) -> float:
	var group: Node3D = Node3D.new()
	group.name = p_family
	group.position = Vector3(0.0, 0.0, p_depth)
	p_parent.add_child(group)
	group.add_child(label(p_family.capitalize(),
			Vector3(2.0, LABEL_LIFT, -TITLE_FRONT), LABEL_SIZE * 2.0))
	var x: float = 0.0
	var z: float = 0.0
	var row_depth: float = 0.0
	for entry in p_entries:
		var bounds: AABB = entry.bounds
		var width: float = maxf(bounds.size.x, MIN_CELL) + gap
		if x > 0.0 and x + width > row_width:
			x = 0.0
			z += row_depth + ROW_GAP
			row_depth = 0.0
		add_stand(group, entry, Vector3(-(x + width * 0.5), 0.0, z))
		x += width
		row_depth = maxf(row_depth, bounds.size.z)
	return p_depth + z + row_depth + FAMILY_GAP


func add_stand(p_group: Node3D, p_entry: Dictionary, p_position: Vector3):
	var stand: Node3D = Node3D.new()
	stand.name = p_entry.name
	stand.position = p_position
	p_group.add_child(stand)
	var bounds: AABB = p_entry.bounds
	var model: Node3D = p_entry.node
	model.name = "Model"
	model.basis = Basis(Vector3.UP, p_entry.turn)
	model.position = Vector3(-(bounds.position.x + bounds.size.x * 0.5),
			maxf(0.0, -bounds.position.y), -bounds.position.z)
	stand.add_child(model)
	stand.add_child(label(String(p_entry.name).capitalize(),
			Vector3(0.0, LABEL_LIFT, -LABEL_FRONT), LABEL_SIZE))


func exhibits_in(p_dir: String, p_turn: float) -> Array:
	var found: Array = []
	var turned: Transform3D = Transform3D(Basis(Vector3.UP, p_turn), Vector3.ZERO)
	var files: Array = Array(DirAccess.get_files_at(p_dir))
	files.sort()
	for file in files:
		var node: Node3D = null
		if file.ends_with(".tres"):
			var mesh: Mesh = load(p_dir.path_join(file))
			if mesh == null:
				continue
			node = MeshInstance3D.new()
			node.mesh = mesh
		elif file.ends_with(".tscn"):
			var packed: PackedScene = load(p_dir.path_join(file))
			if packed == null:
				continue
			node = packed.instantiate()
		else:
			continue
		found.append({"name": file.get_basename(), "node": node, "turn": p_turn,
				"bounds": bounds_of(node, turned)})
	return found


func bounds_of(p_node: Node, p_xform: Transform3D) -> AABB:
	var local: Transform3D = p_xform * p_node.transform if p_node is Node3D else p_xform
	var result: AABB = AABB()
	if p_node is MeshInstance3D and p_node.mesh and p_node.skin == null:
		result = local * p_node.mesh.get_aabb()
	elif p_node is Skeleton3D:
		result = bone_bounds(p_node, local)
	for child in p_node.get_children():
		var sub: AABB = bounds_of(child, local)
		if sub.size == Vector3.ZERO:
			continue
		result = sub if result.size == Vector3.ZERO else result.merge(sub)
	return result


# Skinned vertices are stored wherever Blender left them; the bind pulls them onto the bones.
func bone_bounds(p_skeleton: Skeleton3D, p_xform: Transform3D) -> AABB:
	var box: AABB = AABB()
	for i in p_skeleton.get_bone_count():
		var point: Vector3 = p_xform * p_skeleton.get_bone_global_rest(i).origin
		box = AABB(point, Vector3.ZERO) if i == 0 else box.expand(point)
	return box


func fit_ground(p_far: Vector2) -> void:
	var ground: MeshInstance3D = get_node_or_null("Ground")
	if ground == null or not ground.mesh is PlaneMesh:
		return
	ground.mesh.size = p_far + Vector2.ONE * GROUND_MARGIN * 2.0
	ground.position = Vector3(-p_far.x * 0.5, 0.0, p_far.y * 0.5)


func label(p_text: String, p_position: Vector3, p_size: float) -> Label3D:
	var text: Label3D = Label3D.new()
	text.text = p_text
	text.position = p_position
	text.basis = Basis(Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0))
	text.font_size = 64
	text.pixel_size = p_size / 64.0
	text.fixed_size = false
	return text
