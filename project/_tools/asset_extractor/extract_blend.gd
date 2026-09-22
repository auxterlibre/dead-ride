extends SceneTree
# Run twice per kit: the first pass dumps the textures and stops so --import can see them.

const ExtractLib = preload("res://_tools/asset_extractor/extract_lib.gd")

const BLOOD_MASK: String = "res://_not_exported/textures/blood_mask.png"
const BLOOD: Dictionary = {"name": "blood", "mask": BLOOD_MASK,
		"color": Color(0.2846, 0.014, 0.0211), "ramp": Vector2(0.192, 1.0)}
const FABRIC_BLOOD: Dictionary = {"name": "fabric_blood", "mask": BLOOD_MASK,
		"color": Color(0.1873, 0.0088, 0.0149), "ramp": Vector2(0.069, 1.0)}
const DIRT: Dictionary = {"name": "dirt", "mask": BLOOD_MASK,
		"color": Color(0.0397, 0.0058, 0.0), "ramp": Vector2(0.192, 0.728)}
const DUST: Dictionary = {"name": "dust", "mask": BLOOD_MASK,
		"color": Color(0.5071, 0.3823, 0.1848), "ramp": Vector2(0.215, 0.171)}

const KITS: Array = [
	{"name": "junkyard", "source": "res://_not_exported/Junkyard.blend",
			"family": "stem", "skip": []},
	{"name": "apocalypse", "source": "res://_not_exported/Apocalypse_Free.blend",
			"family": "prefix", "skip": ["Plane", "Text"],
			"albedo": {
				"Car_Color_Blood": "res://_not_exported/textures/Color2.png",
				"Color_Blood": "res://_not_exported/textures/Color2.png",
				"Color_Body_Blood": "res://_not_exported/textures/Color2.png",
				"Color_Dirt": "res://_not_exported/textures/Color2.png",
				"Color_Dust": "res://_not_exported/textures/Color2.png",
				"Fabric_14_Blood": "res://_not_exported/textures/Fabric_14.png",
				"RoadSigns": "res://_not_exported/textures/RoadSigns.png",
			},
			"overlay": {
				"Car_Color_Blood": BLOOD, "Color_Blood": BLOOD, "Color_Body_Blood": BLOOD,
				"RoadSigns": BLOOD, "Fabric_14_Blood": FABRIC_BLOOD,
				"Color_Dirt": DIRT, "Color_Dust": DUST,
			}},
	{"name": "apocalypse_weapons", "source": "res://_not_exported/Apocalypse_Weapons.blend",
			"family": "prefix", "skip": []},
]
const MESH_ROOT: String = "res://assets/meshes"
const MATERIAL_ROOT: String = "res://assets/materials"
const TEXTURE_ROOT: String = "res://assets/textures"

var suffix: RegEx = RegEx.create_from_string("_[0-9]{3}$")
var digits: RegEx = RegEx.create_from_string("[0-9]+$")
var kit: Dictionary = {}
var materials: Dictionary = {}
var meshes: Dictionary = {}
var exhibits: Dictionary = {}
var taken: Dictionary = {}
var saved_meshes: int = 0
var saved_scenes: int = 0


func _init():
	var wanted: PackedStringArray = OS.get_cmdline_user_args()
	for entry in KITS:
		if wanted.is_empty() or entry.name in wanted:
			extract_kit(entry)
	quit()


func extract_kit(p_kit: Dictionary) -> void:
	kit = p_kit
	materials = {}
	meshes = {}
	exhibits = {}
	taken = {}
	saved_meshes = 0
	saved_scenes = 0
	var level: Node = (load(kit.source) as PackedScene).instantiate()
	if not textures_ready(level):
		level.free()
		return
	var children: Array = level.get_children()
	children.sort_custom(func(a, b): return String(a.name) < String(b.name))
	for child in children:
		if child is Node3D and not skipped(child.name):
			extract_exhibit(child)
	level.free()
	print("DBG %s: extracted %d meshes, %d assemblies, %d materials" % [
			kit.name, saved_meshes, saved_scenes, materials.size()])


func skipped(p_name: String) -> bool:
	for prefix in kit.skip:
		if p_name.begins_with(prefix):
			return true
	return false


func textures_ready(p_root: Node) -> bool:
	var pending: int = 0
	var seen: Dictionary = {}
	DirAccess.make_dir_recursive_absolute(TEXTURE_ROOT.path_join(kit.name))
	for instance in p_root.find_children("*", "MeshInstance3D", true, false):
		for i in instance.mesh.get_surface_count():
			var source: BaseMaterial3D = instance.mesh.surface_get_material(i) as BaseMaterial3D
			if source == null or source.albedo_texture == null or seen.has(source.resource_name):
				continue
			seen[source.resource_name] = true
			var path: String = texture_path(source)
			if not FileAccess.file_exists(path):
				var origin: String = texture_origin(source)
				if "::" in origin:
					source.albedo_texture.get_image().save_png(path)
				elif DirAccess.copy_absolute(ProjectSettings.globalize_path(origin),
						ProjectSettings.globalize_path(path)) != OK:
					print("DBG MISSING %s for material %s" % [origin, source.resource_name])
					continue
				print("DBG wrote %s" % path)
			if not FileAccess.file_exists(path + ".import"):
				pending += 1
	for spec in kit.get("overlay", {}).values():
		var path: String = overlay_path(spec)
		if not FileAccess.file_exists(path):
			bake_overlay(spec, path)
			print("DBG wrote %s" % path)
		if not FileAccess.file_exists(path + ".import"):
			pending += 1
	if pending > 0:
		print("DBG %s: %d textures await import - run verify.sh import, then this script again" % [
				kit.name, pending])
	return pending == 0


# Blender mixes a constant colour over the base by a ramp of the mask: the ramp
# runs 0 -> ramp.y over mask 0 -> ramp.x in LINEAR light, and that becomes alpha.
func bake_overlay(p_spec: Dictionary, p_path: String) -> void:
	var mask: Image = Image.load_from_file(ProjectSettings.globalize_path(p_spec.mask))
	var out: Image = Image.create_empty(mask.get_width(), mask.get_height(), false, Image.FORMAT_RGBA8)
	var tint: Color = p_spec.color.linear_to_srgb()
	var ramp: Vector2 = p_spec.ramp
	for y in mask.get_height():
		for x in mask.get_width():
			var value: float = mask.get_pixel(x, y).srgb_to_linear().r
			tint.a = clampf(value / ramp.x, 0.0, 1.0) * ramp.y
			out.set_pixel(x, y, tint)
	out.save_png(p_path)


func overlay_path(p_spec: Dictionary) -> String:
	return "%s/%s/%s_overlay_%s.png" % [TEXTURE_ROOT, kit.name, kit.name, p_spec.name]


func extract_exhibit(p_node: Node) -> void:
	var parts: Array[Node] = p_node.find_children("*", "MeshInstance3D", true, false)
	if p_node is MeshInstance3D:
		parts.push_front(p_node)
	if parts.is_empty():
		print("DBG SKIPPED %s: no mesh" % p_node.name)
		return
	var keys: Array = parts.map(func(part): return mesh_key(part.mesh))
	keys.sort()
	var key: String = "|".join(keys)
	if exhibits.has(key):
		return
	exhibits[key] = true
	var family: String = family_of(p_node.name)
	if parts.size() == 1 and p_node.find_child("Skeleton3D", true, false) == null:
		save_mesh(parts[0].mesh, String(p_node.name), mesh_dir(family))
	else:
		save_assembly(p_node, family)


func mesh_dir(p_family: String) -> String:
	return MESH_ROOT.path_join(kit.name).path_join(p_family)


func save_mesh(p_source: Mesh, p_name: String, p_dir: String) -> ArrayMesh:
	var key: String = mesh_key(p_source)
	if meshes.has(key):
		return meshes[key]
	var mesh: ArrayMesh = restore_uvs(p_source)
	for i in mesh.get_surface_count():
		mesh.surface_set_material(i, shared_material(p_source.surface_get_material(i)))
	var name: String = free_name(p_dir, p_name.to_snake_case())
	var path: String = "%s/%s.tres" % [p_dir, name]
	DirAccess.make_dir_recursive_absolute(p_dir)
	mesh.resource_name = name
	mesh.take_over_path(path)
	ExtractLib.save_keeping_uid(mesh, path)
	meshes[key] = mesh
	saved_meshes += 1
	return mesh


# The importer moves the exporter's chosen texture coordinate into UV1, so a
# surface re-pointed by the albedo table wants its UV sets swapped back.
func restore_uvs(p_source: Mesh) -> ArrayMesh:
	var swap: Array = []
	for i in p_source.get_surface_count():
		swap.append(overridden(p_source.surface_get_material(i)))
	if not swap.has(true):
		return p_source.duplicate()
	var mesh: ArrayMesh = ArrayMesh.new()
	for i in p_source.get_surface_count():
		var arrays: Array = p_source.surface_get_arrays(i)
		if swap[i]:
			var uv: Variant = arrays[Mesh.ARRAY_TEX_UV]
			arrays[Mesh.ARRAY_TEX_UV] = arrays[Mesh.ARRAY_TEX_UV2]
			arrays[Mesh.ARRAY_TEX_UV2] = uv
		mesh.add_surface_from_arrays(p_source.surface_get_primitive_type(i), arrays)
	return mesh


func overridden(p_material: Material) -> bool:
	return p_material != null and kit.get("albedo", {}).has(p_material.resource_name) \
			and p_material.get_meta("_gltf_primary_texture_coord", 0) == 1


func save_assembly(p_node: Node, p_family: String) -> void:
	var dir: String = mesh_dir(p_family)
	var parts_dir: String = dir.path_join("parts")
	var copy: Node3D = p_node.duplicate()
	copy.transform = Transform3D.IDENTITY
	var name: String = free_name(dir, String(p_node.name).to_snake_case())
	copy.name = name.to_pascal_case()
	if copy is MeshInstance3D:
		copy.mesh = save_mesh(copy.mesh, String(p_node.name), parts_dir)
	rebuild(copy, copy, parts_dir)
	var packed: PackedScene = PackedScene.new()
	packed.pack(copy)
	var path: String = "%s/%s.tscn" % [dir, name]
	DirAccess.make_dir_recursive_absolute(dir)
	packed.take_over_path(path)
	ExtractLib.save_keeping_uid(packed, path)
	copy.free()
	saved_scenes += 1


func rebuild(p_node: Node, p_root: Node, p_parts_dir: String) -> void:
	for child in p_node.get_children():
		if child is VehicleWheel3D:
			var pivot: Node3D = Node3D.new()
			pivot.name = child.name
			pivot.transform = child.transform
			for grandchild in child.get_children():
				child.remove_child(grandchild)
				pivot.add_child(grandchild)
			p_node.add_child(pivot)
			p_node.move_child(pivot, child.get_index())
			p_node.remove_child(child)
			child.free()
			child = pivot
		if child is MeshInstance3D:
			child.mesh = save_mesh(child.mesh, String(child.name), p_parts_dir)
		child.owner = p_root
		rebuild(child, p_root, p_parts_dir)


func shared_material(p_source: Material) -> BaseMaterial3D:
	var source: BaseMaterial3D = p_source as BaseMaterial3D
	if source == null:
		return null
	var name: String = source.resource_name.to_snake_case()
	if materials.has(name):
		return materials[name]
	var path: String = "%s/%s/%s_material_%s.tres" % [MATERIAL_ROOT, kit.name, kit.name, name]
	var material: BaseMaterial3D
	if FileAccess.file_exists(path):
		material = load(path)
	else:
		material = source.duplicate()
		if source.albedo_texture != null:
			material.albedo_texture = load(texture_path(source))
		if overridden(source):
			material.set_meta("_gltf_primary_texture_coord", 0)
		var overlay: Dictionary = kit.get("overlay", {}).get(source.resource_name, {})
		if not overlay.is_empty():
			material.detail_enabled = true
			material.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
			material.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MIX
			material.detail_albedo = load(overlay_path(overlay))
		material.resource_name = "%s_material_%s" % [kit.name, name]
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		material.take_over_path(path)
		ExtractLib.save_keeping_uid(material, path)
	materials[name] = material
	return material


# The glTF exporter flattens a Blender mix to ONE image and may pick the mask; the
# kit's albedo table names the real base per material.
func texture_origin(p_source: BaseMaterial3D) -> String:
	return kit.get("albedo", {}).get(p_source.resource_name, p_source.albedo_texture.resource_path)


func texture_path(p_source: BaseMaterial3D) -> String:
	var origin: String = texture_origin(p_source)
	var stem: String = p_source.resource_name if "::" in origin else origin.get_file().get_basename()
	return "%s/%s/%s_%s.png" % [TEXTURE_ROOT, kit.name, kit.name, stem.to_snake_case()]


func mesh_key(p_mesh: Mesh) -> String:
	var bits: Array = []
	for i in p_mesh.get_surface_count():
		var arrays: Array = p_mesh.surface_get_arrays(i)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] else PackedInt32Array()
		var material: BaseMaterial3D = p_mesh.surface_get_material(i) as BaseMaterial3D
		bits.append("%d/%d/%s" % [arrays[Mesh.ARRAY_VERTEX].size(), indices.size(),
				material.resource_name if material else "none"])
	var aabb: AABB = p_mesh.get_aabb()
	return "%s#%s" % [",".join(bits), rounded(aabb.position) + rounded(aabb.end)]


func rounded(p_v: Vector3) -> String:
	return "%.2f,%.2f,%.2f;" % [p_v.x, p_v.y, p_v.z]


func family_of(p_name: String) -> String:
	if kit.family == "prefix":
		return digits.sub(p_name.get_slice("_", 0), "").to_snake_case()
	var name: String = p_name.to_snake_case()
	while suffix.search(name) != null:
		name = suffix.sub(name, "")
	return name


func free_name(p_dir: String, p_name: String) -> String:
	var candidates: Array = [p_name]
	var trimmed: String = p_name
	while suffix.search(trimmed) != null:
		trimmed = suffix.sub(trimmed, "")
		candidates.push_front(trimmed)
	for candidate in candidates:
		if claim(p_dir, candidate):
			return candidate
	var n: int = 2
	while not claim(p_dir, "%s_%d" % [p_name, n]):
		n += 1
	return "%s_%d" % [p_name, n]


func claim(p_dir: String, p_name: String) -> bool:
	var slot: String = p_dir.path_join(p_name)
	if taken.has(slot):
		return false
	taken[slot] = true
	return true
