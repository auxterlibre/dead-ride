extends SceneTree
# Extracts the staged LootBox container gltfs into standalone ArrayMesh .tres
# under assets/meshes/props/containers/, all sharing one material .tres.

const ExtractLib = preload("res://_tools/asset_extractor/extract_lib.gd")

const SOURCE: String = "res://_not_exported/containers"
const MESH_ROOT: String = "res://assets/meshes/props/containers"
const MATERIAL_PATH: String = "res://assets/materials/props/containers_material.tres"
const TEXTURE_PATH: String = "res://assets/textures/props/resource_bits_texture.png"

var material: BaseMaterial3D = null
var saved: int = 0


func _init():
	DirAccess.make_dir_recursive_absolute(MESH_ROOT)
	for file in DirAccess.get_files_at(SOURCE):
		if not file.ends_with(".gltf"):
			continue
		var scene: Node = (load(SOURCE + "/" + file) as PackedScene).instantiate()
		var instances: Array[Node] = scene.find_children("*", "MeshInstance3D", true, false)
		if instances.size() != 1 or instances[0].transform != Transform3D.IDENTITY:
			print("DBG SKIPPED %s: not a single identity-transform mesh" % file)
			scene.free()
			continue
		var instance: MeshInstance3D = instances[0]
		if material == null:
			material = shared_material(instance.mesh.surface_get_material(0))
		var mesh: ArrayMesh = instance.mesh.duplicate()
		for surface in mesh.get_surface_count():
			mesh.surface_set_material(surface, material)
		var name: String = file.get_basename().to_snake_case()
		var out_path: String = "%s/%s.tres" % [MESH_ROOT, name]
		mesh.resource_name = name
		mesh.take_over_path(out_path)
		ExtractLib.save_keeping_uid(mesh, out_path)
		saved += 1
		scene.free()
	print("DBG extracted %d container meshes, material at %s" % [saved, MATERIAL_PATH])
	quit()


# The one material every container references: the gltf's material with its
# albedo swapped to the export-safe imported texture copy.
func shared_material(p_source: Material) -> BaseMaterial3D:
	if FileAccess.file_exists(ProjectSettings.globalize_path(MATERIAL_PATH)):
		return load(MATERIAL_PATH)
	var result: BaseMaterial3D = (p_source as BaseMaterial3D).duplicate()
	result.albedo_texture = load(TEXTURE_PATH)
	result.resource_name = "containers_material"
	DirAccess.make_dir_recursive_absolute(MATERIAL_PATH.get_base_dir())
	result.take_over_path(MATERIAL_PATH)
	ExtractLib.save_keeping_uid(result, MATERIAL_PATH)
	return result
