extends SceneTree

const ExtractLib = preload("res://_tools/asset_extractor/extract_lib.gd")

const SOURCE: String = "res://_not_exported/Zombies.blend"
const OUT_DIR: String = "res://data/outfits/presets"
const PARTS_DIR: String = "res://assets/meshes/humanoid/parts"

var suffix: RegEx = RegEx.create_from_string("_[0-9]{3}$")


func _init():
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var level: Node = (load(SOURCE) as PackedScene).instantiate()
	var count: int = 0
	var missing: int = 0
	for child in level.get_children():
		if not String(child.name).begins_with("Skeleton_"):
			continue
		var skeleton: Skeleton3D = child.find_children("*", "Skeleton3D", true, false)[0]
		var outfit: OutfitData = OutfitData.new()
		var parts: PackedStringArray = []
		for part in skeleton.find_children("*", "MeshInstance3D", false, false):
			var name: String = suffix.sub(String(part.name), "").to_snake_case()
			if not ResourceLoader.exists("%s/%s.tres" % [PARTS_DIR, name]):
				missing += 1
				continue
			parts.append(name)
		outfit.parts = parts
		var number: String = String(child.name).trim_prefix("Skeleton_")
		var path: String = "%s/preset_%s.tres" % [OUT_DIR, number]
		outfit.take_over_path(path)
		ExtractLib.save_keeping_uid(outfit, path)
		count += 1
	level.free()
	print("DBG outfits: %d presets written to %s, %d parts unmatched" % [count, OUT_DIR, missing])
	quit()
