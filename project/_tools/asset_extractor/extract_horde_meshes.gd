extends SceneTree

const ExtractLib = preload("res://_tools/asset_extractor/extract_lib.gd")

const RIG_SOURCE: String = "res://_not_exported/Zombies_parts.blend"
const OUTFIT_DIR: String = "res://data/outfits/presets"
const PARTS_DIR: String = "res://assets/meshes/humanoid/parts"
const OUT_DIR: String = "res://assets/meshes/horde"
const MATERIAL: String = "res://assets/materials/horde/horde_material.tres"
const VARIANTS: int = 16
const WEIGHTS_KEPT: int = 4

var bone_index: Dictionary = {}


func _init():
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var level: Node = (load(RIG_SOURCE) as PackedScene).instantiate()
	var rig: Skeleton3D = level.get_node("Skeleton").find_children("*", "Skeleton3D", true, false)[0]
	for i in rig.get_bone_count():
		bone_index[rig.get_bone_name(i)] = i
	level.free()
	var material: Material = load(MATERIAL)
	var outfits: Array = Array(DirAccess.get_files_at(OUTFIT_DIR))
	outfits.sort()
	var built: int = 0
	var triangles: int = 0
	for file in outfits:
		if built >= VARIANTS or not file.ends_with(".tres"):
			continue
		var outfit: OutfitData = load(OUTFIT_DIR.path_join(file))
		var mesh: ArrayMesh = merge(outfit)
		if mesh == null:
			continue
		mesh.surface_set_material(0, material)
		var path: String = "%s/%s.tres" % [OUT_DIR, file.get_basename()]
		mesh.resource_name = file.get_basename()
		mesh.take_over_path(path)
		ExtractLib.save_keeping_uid(mesh, path)
		triangles += mesh.surface_get_array_index_len(0) / 3
		built += 1
	print("DBG horde meshes: %d variants, %d triangles each on average -> %s" % [built,
			triangles / maxi(built, 1), OUT_DIR])
	quit()


func merge(p_outfit: OutfitData) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var bones: PackedInt32Array = PackedInt32Array()
	var weights: PackedFloat32Array = PackedFloat32Array()
	var indices: PackedInt32Array = PackedInt32Array()
	for part in p_outfit.parts:
		var source: ArrayMesh = load("%s/%s.tres" % [PARTS_DIR, part])
		var skin: Skin = load("%s/%s_skin.tres" % [PARTS_DIR, part])
		if source == null or skin == null:
			push_warning("horde merge: %s has no mesh or skin" % part)
			continue
		var remap: PackedInt32Array = PackedInt32Array()
		for b in skin.get_bind_count():
			remap.append(bone_index.get(skin.get_bind_name(b), 0))
		for surface in source.get_surface_count():
			var per_vertex: int = 8 if source.surface_get_format(surface) \
					& Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS else 4
			var arrays: Array = source.surface_get_arrays(surface)
			var base: int = vertices.size()
			vertices.append_array(arrays[Mesh.ARRAY_VERTEX])
			normals.append_array(arrays[Mesh.ARRAY_NORMAL])
			uvs.append_array(arrays[Mesh.ARRAY_TEX_UV])
			append_influences(arrays[Mesh.ARRAY_BONES], arrays[Mesh.ARRAY_WEIGHTS], per_vertex,
					remap, bones, weights)
			var part_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for i in part_indices.size():
				indices.append(part_indices[i] + base)
	if vertices.is_empty():
		return null
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func append_influences(p_bones: PackedInt32Array, p_weights: PackedFloat32Array, p_per_vertex: int,
		p_remap: PackedInt32Array, p_out_bones: PackedInt32Array, p_out_weights: PackedFloat32Array):
	var count: int = p_bones.size() / p_per_vertex
	for v in count:
		var pairs: Array = []
		for k in p_per_vertex:
			pairs.append([p_weights[v * p_per_vertex + k], p_bones[v * p_per_vertex + k]])
		pairs.sort_custom(func(a, b): return a[0] > b[0])
		var total: float = 0.0
		for k in WEIGHTS_KEPT:
			total += pairs[k][0]
		for k in WEIGHTS_KEPT:
			p_out_bones.append(p_remap[pairs[k][1]])
			p_out_weights.append(pairs[k][0] / total if total > 0.0 else 0.0)
