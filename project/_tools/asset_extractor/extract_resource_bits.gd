extends SceneTree
# Extracts picked KayKit Resource Bits gltfs into standalone ArrayMesh .tres
# under assets/meshes/props/resource_bits/. The kit shares the containers'
# material - the loot boxes came out of the same pack, same atlas.

const ExtractLib = preload("res://_tools/asset_extractor/extract_lib.gd")

# All raw item sources live in one staging folder now; the WANTED list is
# what keeps assets/ curated.
const SOURCES: Array = ["res://_not_exported/items"]
const MESH_ROOT: String = "res://assets/meshes/props/resource_bits"
const MATERIAL_PATH: String = "res://assets/materials/props/containers_material.tres"
const WANTED: Array = ["Fuel_A_Jerrycan", "Cog", "Fuel_Barrel", "cash"]

var saved: int = 0


func _init():
	DirAccess.make_dir_recursive_absolute(MESH_ROOT)
	var material: BaseMaterial3D = load(MATERIAL_PATH)
	for source in SOURCES:
		for file in DirAccess.get_files_at(source):
			if not file.ends_with(".gltf") or not file.get_basename() in WANTED:
				continue
			var scene: Node = (load(source + "/" + file) as PackedScene).instantiate()
			var instances: Array[Node] = scene.find_children("*", "MeshInstance3D", true, false)
			if instances.size() != 1 or instances[0].transform != Transform3D.IDENTITY:
				print("DBG SKIPPED %s: not a single identity-transform mesh" % file)
				scene.free()
				continue
			var mesh: ArrayMesh = instances[0].mesh.duplicate()
			for surface in mesh.get_surface_count():
				mesh.surface_set_material(surface, material)
			var name: String = file.get_basename().to_snake_case()
			var out_path: String = "%s/%s.tres" % [MESH_ROOT, name]
			mesh.resource_name = name
			mesh.take_over_path(out_path)
			ExtractLib.save_keeping_uid(mesh, out_path)
			saved += 1
			scene.free()
	print("DBG extracted %d resource bits meshes" % saved)
	quit()
