extends SceneTree

const ExtractLib = preload("res://_tools/asset_extractor/extract_lib.gd")

const SOURCE: String = "res://_not_exported/Zombies_parts.blend"
const PARTS_DIR: String = "res://assets/meshes/humanoid/parts"
const MATERIAL_DIR: String = "res://assets/materials/zombies"

var materials: Dictionary = {}


func _init():
	DirAccess.make_dir_recursive_absolute(PARTS_DIR)
	var level: Node = (load(SOURCE) as PackedScene).instantiate()
	var skeleton: Skeleton3D = level.get_node("Skeleton").find_children("*", "Skeleton3D", true, false)[0]
	var slots: Dictionary = {}
	var count: int = 0
	for part in skeleton.find_children("*", "MeshInstance3D", false, false):
		var name: String = String(part.name).to_snake_case()
		var mesh: ArrayMesh = part.mesh.duplicate()
		for i in mesh.get_surface_count():
			var source: BaseMaterial3D = part.mesh.surface_get_material(i) as BaseMaterial3D
			if source != null:
				mesh.surface_set_material(i, shared_material(source))
		var mesh_path: String = "%s/%s.tres" % [PARTS_DIR, name]
		mesh.resource_name = name
		mesh.take_over_path(mesh_path)
		ExtractLib.save_keeping_uid(mesh, mesh_path)
		if part.skin != null:
			var skin: Skin = part.skin.duplicate()
			var skin_path: String = "%s/%s_skin.tres" % [PARTS_DIR, name]
			skin.take_over_path(skin_path)
			ExtractLib.save_keeping_uid(skin, skin_path)
		var slot: String = OutfitData.slot_of(name)
		slots[slot] = slots.get(slot, 0) + 1
		count += 1
	print("DBG humanoid parts: %d saved from %s" % [count, skeleton.name])
	print("DBG slots: %s" % [slots])
	level.free()
	quit()


func shared_material(p_source: BaseMaterial3D) -> BaseMaterial3D:
	var name: String = p_source.resource_name.to_snake_case()
	if materials.has(name):
		return materials[name]
	var path: String = "%s/zombies_material_%s.tres" % [MATERIAL_DIR, name]
	if not FileAccess.file_exists(path):
		push_warning("no shared material for %s, keeping the import's" % name)
		materials[name] = p_source
		return p_source
	materials[name] = load(path)
	return materials[name]
