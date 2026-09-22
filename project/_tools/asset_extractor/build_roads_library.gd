extends SceneTree
# Ids are alphabetical over road_*.tres - a contract with painted maps: only append, never renumber.

const ExtractLib = preload("res://_tools/asset_extractor/extract_lib.gd")

const ROADS_DIR:String = "res://assets/meshes/environment/roads"
const LIBRARY_PATH:String = ROADS_DIR + "/roads_library.tres"


func _init():
	var library:MeshLibrary = MeshLibrary.new()
	var id:int = 0
	for file in DirAccess.get_files_at(ROADS_DIR):
		if not file.begins_with("road_") or not file.ends_with(".tres"):
			continue
		var mesh:ArrayMesh = load(ROADS_DIR + "/" + file)
		library.create_item(id)
		library.set_item_name(id, file.get_basename())
		library.set_item_mesh(id, mesh)
		var shape:ConcavePolygonShape3D = mesh.create_trimesh_shape()
		# Insurance: the material renders cull-disabled, so a flipped face in
		# the kit would be invisible - keep collision two-sided to match.
		shape.backface_collision = true
		library.set_item_shapes(id, [shape, Transform3D.IDENTITY])
		print("DBG %2d %s" % [id, file.get_basename()])
		id += 1
	library.take_over_path(LIBRARY_PATH)
	ExtractLib.save_keeping_uid(library, LIBRARY_PATH)
	print("DBG roads library saved: %d items" % id)
	quit()
