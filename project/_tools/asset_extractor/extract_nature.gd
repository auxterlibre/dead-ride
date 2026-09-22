extends SceneTree
# Extracts every staged KayKit Nature Pack gltf into a standalone ArrayMesh
# .tres under assets/meshes/environment/, all sharing one material .tres.

const ExtractLib = preload("res://_tools/asset_extractor/extract_lib.gd")

const SOURCE:String = "res://_not_exported/environment"
const MESH_ROOT:String = "res://assets/meshes/environment"
const MATERIAL_PATH:String = "res://assets/materials/environment/nature_material_a.tres"
const ATLAS_PATH:String = "res://assets/textures/environment/nature_texture.png"
const PROP_FAMILIES:Dictionary = {
	"Tree": "trees", "Rock": "rocks", "Bush": "bushes", "Grass": "grass"}

var material:BaseMaterial3D = null
var saved:int = 0


func _init():
	extract_folder(SOURCE + "/hills", MESH_ROOT + "/terrain")
	extract_folder(SOURCE + "/props", MESH_ROOT + "/props")
	print("DBG extracted %d meshes, material at %s" % [saved, MATERIAL_PATH])
	quit()


func extract_folder(p_dir:String, p_out_root:String):
	for file in DirAccess.get_files_at(p_dir):
		if not file.ends_with(".gltf"):
			continue
		var scene:Node = (load(p_dir + "/" + file) as PackedScene).instantiate()
		var instances:Array[Node] = scene.find_children("*", "MeshInstance3D", true, false)
		if instances.size() != 1:
			print("DBG SKIPPED %s: %d mesh instances" % [file, instances.size()])
			scene.free()
			continue
		var instance:MeshInstance3D = instances[0]
		if instance.transform != Transform3D.IDENTITY:
			print("DBG SKIPPED %s: non-identity transform" % file)
			scene.free()
			continue

		if material == null:
			material = shared_material(instance.mesh.surface_get_material(0))

		var mesh:ArrayMesh = instance.mesh.duplicate()
		for surface in mesh.get_surface_count():
			mesh.surface_set_material(surface, material)
		var name:String = file.get_basename().to_snake_case()
		var out_dir:String = p_out_root
		for prefix in PROP_FAMILIES:
			if file.begins_with(prefix + "_"):
				out_dir = p_out_root + "/" + PROP_FAMILIES[prefix]
		DirAccess.make_dir_recursive_absolute(out_dir)
		var out_path:String = "%s/%s.tres" % [out_dir, name]
		mesh.resource_name = name
		mesh.take_over_path(out_path)
		ExtractLib.save_keeping_uid(mesh, out_path)
		saved += 1
		scene.free()


# The one material every extracted mesh references: the gltf's material with
# its albedo swapped to the export-safe imported atlas copy.
func shared_material(p_source:Material) -> BaseMaterial3D:
	if FileAccess.file_exists(ProjectSettings.globalize_path(MATERIAL_PATH)):
		return load(MATERIAL_PATH)
	var result:BaseMaterial3D = (p_source as BaseMaterial3D).duplicate()
	result.albedo_texture = load(ATLAS_PATH)
	result.resource_name = "nature_material_a"
	DirAccess.make_dir_recursive_absolute(MATERIAL_PATH.get_base_dir())
	result.take_over_path(MATERIAL_PATH)
	ExtractLib.save_keeping_uid(result, MATERIAL_PATH)
	return result
