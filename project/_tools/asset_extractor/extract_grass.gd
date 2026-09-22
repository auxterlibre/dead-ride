extends SceneTree
# Extracts the staged single-sided grass tufts, re-textured onto the nature
# atlas and sharing ONE billboard material - the kit's own would billboard
# every tree and rock with them.

const ExtractLib = preload("res://_tools/asset_extractor/extract_lib.gd")

const SOURCE: String = "res://_not_exported/items/grass"
const OUT_DIR: String = "res://assets/meshes/environment/props/grass"
const MATERIAL_PATH: String = "res://assets/materials/environment/grass_material.tres"
# Repaints every tuft at once: the atlas is 8 columns of 0.125 and Color5 lands
# on the dry orange one. -0.5 would walk them to the greens.
const PALETTE_SHIFT: float = 0.0

var material: Material = null
var saved: int = 0


func _init():
	for file in DirAccess.get_files_at(SOURCE):
		if not file.ends_with(".gltf"):
			continue
		extract(file)
	print("DBG extracted %d grass meshes, material at %s" % [saved, MATERIAL_PATH])
	quit()


func extract(p_file: String):
	var scene: Node = (load(SOURCE + "/" + p_file) as PackedScene).instantiate()
	var instances: Array[Node] = scene.find_children("*", "MeshInstance3D", true, false)
	if instances.size() != 1:
		print("DBG SKIPPED %s: %d mesh instances" % [p_file, instances.size()])
		scene.free()
		return
	var mesh: ArrayMesh = repaint(instances[0].mesh)
	var name: String = p_file.get_basename().to_snake_case()
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var out_path: String = "%s/%s.tres" % [OUT_DIR, name]
	mesh.resource_name = name
	mesh.take_over_path(out_path)
	ExtractLib.save_keeping_uid(mesh, out_path)
	saved += 1
	scene.free()


# Slides every UV sideways onto another palette column and hangs the shared
# material on the result.
func repaint(p_source: ArrayMesh) -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	for surface in p_source.get_surface_count():
		var arrays: Array = p_source.surface_get_arrays(surface)
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		for i in uvs.size():
			uvs[i] = Vector2(uvs[i].x + PALETTE_SHIFT, uvs[i].y)
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(surface, grass_material())
	return mesh


# Authored, not built here: the billboard and the wind sway are art, and a
# tool that rebuilt the material would flatten them on the next extract.
func grass_material() -> Material:
	if material == null:
		material = load(MATERIAL_PATH)
	return material
