extends SceneTree
# Extracts item props (tools) out of the imported gltf sources into game-ready
# ArrayMesh .tres, all sharing one material on an export-safe atlas copy.

const ExtractLib = preload("res://_tools/asset_extractor/extract_lib.gd")

const SOURCE:String = "res://_not_exported/items"
const OUT_DIR:String = "res://assets/meshes/items"
const MATERIAL_PATH:String = "res://assets/materials/items/tools_material.tres"
const ATLAS_SOURCE:String = "res://_not_exported/items/tools_bits_texture.png"
const ATLAS_PATH:String = "res://assets/textures/items/tools_bits_texture.png"

# Source file -> output name.
const PIECES:Dictionary = {
	"screwdriver_A_short": "screwdriver",
}

var material:Material = null


func _init():
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(ATLAS_PATH.get_base_dir()))
	DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(MATERIAL_PATH.get_base_dir()))
	# The source tree is export-excluded, so the atlas needs a copy under
	# assets/ before anything shipped may reference it.
	if not FileAccess.file_exists(ProjectSettings.globalize_path(ATLAS_PATH)):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(ATLAS_SOURCE),
				ProjectSettings.globalize_path(ATLAS_PATH))
		print("DBG copied atlas -> %s (run verify.sh import next)" % ATLAS_PATH)
	for source in PIECES:
		var scene:Node = (load("%s/%s.gltf" % [SOURCE, source]) as PackedScene).instantiate()
		var found:Array = scene.find_children("*", "MeshInstance3D", true, false)
		if found.is_empty():
			print("DBG %s has no mesh" % source)
			scene.free()
			continue
		var mesh:ArrayMesh = (found[0] as MeshInstance3D).mesh
		save_mesh(PIECES[source], mesh)
		scene.free()
	quit()


func save_mesh(p_name:String, p_mesh:ArrayMesh):
	var out:ArrayMesh = ArrayMesh.new()
	for surface in p_mesh.get_surface_count():
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,
				p_mesh.surface_get_arrays(surface))
		if material == null:
			material = shared_material(p_mesh.surface_get_material(surface))
		out.surface_set_material(out.get_surface_count() - 1, material)
	out.resource_name = p_name
	var path:String = "%s/%s.tres" % [OUT_DIR, p_name]
	out.take_over_path(path)
	ExtractLib.save_keeping_uid(out, path)
	print("DBG %-14s %d surfaces  aabb %s -> %s" % [p_name,
			out.get_surface_count(), out.get_aabb().size, path])


# One material for every tool: the source's, albedo swapped to the
# export-safe atlas copy.
func shared_material(p_source:Material) -> BaseMaterial3D:
	var existing:BaseMaterial3D = null
	if FileAccess.file_exists(ProjectSettings.globalize_path(MATERIAL_PATH)):
		existing = load(MATERIAL_PATH)
		# The first pass runs before the copied atlas has been imported, so a
		# material written then has no albedo yet - fill it in on a re-run.
		if existing.albedo_texture != null or not ResourceLoader.exists(ATLAS_PATH):
			return existing
	var result:BaseMaterial3D = existing if existing else \
			(p_source as BaseMaterial3D).duplicate()
	if ResourceLoader.exists(ATLAS_PATH):
		result.albedo_texture = load(ATLAS_PATH)
	result.metallic_specular = 0.0
	result.resource_name = "tools_material"
	result.take_over_path(MATERIAL_PATH)
	ExtractLib.save_keeping_uid(result, MATERIAL_PATH)
	return result
