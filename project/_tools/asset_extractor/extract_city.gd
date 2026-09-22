extends SceneTree
# Scales the 2m tiles to a 6m road cell, every orientation baked. SCALE touches X/Z only.

const ExtractLib = preload("res://_tools/asset_extractor/extract_lib.gd")

const SOURCE:String = "res://_not_exported/environment/city"
const OUT_DIR:String = "res://assets/meshes/environment/roads"
const MATERIAL_PATH:String = "res://assets/materials/environment/city_material_a.tres"
const ATLAS_PATH:String = "res://assets/textures/environment/city_texture.png"
# A 3m road was as wide as the car, with a 1.5m corner radius against a 5.7m turning circle.
const SCALE:float = 3.0
# So the asphalt bed sits 5mm proud of the ground - wheels ride it and rays tag "cement".
const SINK:float = 0.065
# Compressed into CURB_KEEP rather than flattened; flattening z-fought with the base quad.
const CURB_DROP:float = 0.03
const CURB_KEEP:float = 0.002

# Source piece -> [connection bitmask in the source mesh (1=N 2=E 4=S 8=W),
# {variant name: its bitmask}].
const PIECES:Dictionary = {
	"road_straight": [1 | 4, {"road_ns": 1 | 4, "road_ew": 2 | 8}],
	"road_straight_crossing": [1 | 4,
			{"road_crossing_ns": 1 | 4, "road_crossing_ew": 2 | 8}],
	"road_corner_curved": [4 | 2, {"road_corner_se": 4 | 2, "road_corner_ne": 1 | 2,
			"road_corner_nw": 1 | 8, "road_corner_sw": 4 | 8}],
	"road_tsplit": [1 | 2 | 4, {"road_t_e": 1 | 2 | 4, "road_t_n": 1 | 2 | 8,
			"road_t_w": 1 | 4 | 8, "road_t_s": 2 | 4 | 8}],
	"road_junction": [15, {"road_cross": 15}],
}

var material:Material = null
var saved:int = 0


func _init():
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	for source in PIECES:
		var scene:Node = (load("%s/%s.gltf" % [SOURCE, source]) as PackedScene).instantiate()
		var mesh:ArrayMesh = (scene.find_children("*", "MeshInstance3D", true, false)[0]
				as MeshInstance3D).mesh
		if material == null:
			material = shared_material(mesh.surface_get_material(0))
		var source_mask:int = PIECES[source][0]
		var variants:Dictionary = PIECES[source][1]
		for name in variants:
			var quarter:int = 0
			var mask:int = source_mask
			while mask != variants[name] and quarter < 4:
				mask = rotated_mask(mask)
				quarter += 1
			save_variant(name, mesh, quarter)
		scene.free()
	print("DBG extracted %d road pieces into %s" % [saved, OUT_DIR])
	quit()


# Connections rotate with the mesh: +90 deg about Y sends E->N, N->W, W->S, S->E.
func rotated_mask(p_mask:int) -> int:
	var result:int = 0
	if p_mask & 2:
		result |= 1
	if p_mask & 1:
		result |= 8
	if p_mask & 8:
		result |= 4
	if p_mask & 4:
		result |= 2
	return result


func save_variant(p_name:String, p_mesh:ArrayMesh, p_quarter:int):
	var transform:Transform3D = Transform3D(Basis(Vector3.UP, p_quarter * PI / 2.0) \
			* Basis.from_scale(Vector3(SCALE, 1, SCALE)), Vector3(0, -SINK, 0))
	var normal_basis:Basis = transform.basis.inverse().transposed()
	var flat_top:float = p_mesh.get_aabb().end.y - CURB_DROP
	var out:ArrayMesh = ArrayMesh.new()
	for surface in p_mesh.get_surface_count():
		var arrays:Array = p_mesh.surface_get_arrays(surface)
		var positions:PackedVector3Array = arrays[Mesh.ARRAY_VERTEX].duplicate()
		for i in positions.size():
			var point:Vector3 = positions[i]
			positions[i] = transform * Vector3(point.x, curbed(point.y, flat_top),
					point.z)
		arrays[Mesh.ARRAY_VERTEX] = positions
		if arrays[Mesh.ARRAY_NORMAL] != null:
			var normals:PackedVector3Array = arrays[Mesh.ARRAY_NORMAL].duplicate()
			for i in normals.size():
				normals[i] = (normal_basis * normals[i]).normalized()
			arrays[Mesh.ARRAY_NORMAL] = normals
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(out.get_surface_count() - 1, material)
	out.resource_name = p_name
	var path:String = "%s/%s.tres" % [OUT_DIR, p_name]
	out.take_over_path(path)
	ExtractLib.save_keeping_uid(out, path)
	saved += 1
	var aabb:AABB = out.get_aabb()
	print("DBG %-18s rot %d  x[%+.2f..%+.2f] z[%+.2f..%+.2f] top %+.3f (was %+.3f)" % [
			p_name, p_quarter * 90, aabb.position.x, aabb.end.x,
			aabb.position.z, aabb.end.z, aabb.end.y,
			p_mesh.get_aabb().end.y - SINK])


func curbed(p_y:float, p_bed:float) -> float:
	if p_y <= p_bed:
		return p_y
	return p_bed + (p_y - p_bed) / CURB_DROP * CURB_KEEP


# One material for every road piece: the source's, albedo swapped to the
# export-safe atlas copy.
func shared_material(p_source:Material) -> BaseMaterial3D:
	if FileAccess.file_exists(ProjectSettings.globalize_path(MATERIAL_PATH)):
		return load(MATERIAL_PATH)
	var result:BaseMaterial3D = (p_source as BaseMaterial3D).duplicate()
	result.albedo_texture = load(ATLAS_PATH)
	result.metallic_specular = 0.0
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	result.resource_name = "city_material_a"
	result.take_over_path(MATERIAL_PATH)
	ExtractLib.save_keeping_uid(result, MATERIAL_PATH)
	return result
