extends SceneTree
# Id layout is a contract with painted maps - only append, never renumber.

const ExtractLib = preload("res://_tools/asset_extractor/extract_lib.gd")

const TERRAIN_DIR:String = "res://assets/meshes/environment/terrain"
const LIBRARY_PATH:String = TERRAIN_DIR + "/hills_library.tres"


func _init():
	var library:MeshLibrary = MeshLibrary.new()
	var id:int = 0
	for file in DirAccess.get_files_at(TERRAIN_DIR):
		if not (file.begins_with("hill_top") or file.begins_with("hill_cliff")):
			continue
		if "_strip_" in file or "_end_" in file or "_bend_" in file:
			continue
		id = add_item(library, id, file.get_basename())
	for name in ["hill_top_strip_ns", "hill_top_strip_ew", "hill_cliff_strip_ns",
			"hill_cliff_strip_ew", "hill_cliff_tall_strip_ns", "hill_cliff_tall_strip_ew"]:
		id = add_item(library, id, name)
	for end in ["n", "s", "w", "e"]:
		for prefix in ["hill_top_end_", "hill_cliff_end_", "hill_cliff_tall_end_"]:
			id = add_item(library, id, prefix + end)
	for letter in ["a", "c", "g", "i"]:
		for prefix in ["hill_top_bend_", "hill_cliff_bend_", "hill_cliff_tall_bend_"]:
			id = add_item(library, id, prefix + letter)

	library.take_over_path(LIBRARY_PATH)
	ExtractLib.save_keeping_uid(library, LIBRARY_PATH)
	print("DBG library saved: %d items" % id)
	quit()


func add_item(p_library:MeshLibrary, p_id:int, p_name:String) -> int:
	var mesh:ArrayMesh = load("%s/%s.tres" % [TERRAIN_DIR, p_name])
	p_library.create_item(p_id)
	p_library.set_item_name(p_id, p_name)
	p_library.set_item_mesh(p_id, mesh)
	p_library.set_item_shapes(p_id, [mesh.create_trimesh_shape(), Transform3D.IDENTITY])
	print("DBG %2d %s" % [p_id, p_name])
	return p_id + 1
