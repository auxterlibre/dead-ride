extends SceneTree
# Wraps the mesh-only items' ArrayMesh .tres into one-node model scenes, for
# ItemData.model going universal: a scene can carry a pose, a bare mesh cannot.

const ExtractLib = preload("res://_tools/asset_extractor/extract_lib.gd")

# mesh resource -> [scene path, baked rotation degrees]. The screwdriver keeps
# the 90-degree lay-down subject_for used to compute from its wide icon box.
const MODELS: Dictionary = {
	"res://assets/meshes/items/screwdriver.tres":
		["res://scenes/items/tools/screwdriver.tscn", Vector3(0.0, 0.0, 90.0)],
	"res://assets/meshes/props/resource_bits/cog.tres":
		["res://scenes/items/trinkets/cog.tscn", Vector3.ZERO],
	"res://assets/meshes/props/resource_bits/fuel_a_jerrycan.tres":
		["res://scenes/items/tools/fuel_can.tscn", Vector3.ZERO],
}


func _init():
	for mesh_path in MODELS:
		var scene_path: String = MODELS[mesh_path][0]
		DirAccess.make_dir_recursive_absolute(
				ProjectSettings.globalize_path(scene_path.get_base_dir()))
		var holder: MeshInstance3D = MeshInstance3D.new()
		holder.name = scene_path.get_file().get_basename().to_pascal_case()
		holder.mesh = load(mesh_path)
		holder.rotation_degrees = MODELS[mesh_path][1]
		var packed: PackedScene = PackedScene.new()
		packed.pack(holder)
		packed.take_over_path(scene_path)
		ExtractLib.save_keeping_uid(packed, scene_path)
		print("DBG %-20s rot %s -> %s" % [holder.name,
				holder.rotation_degrees, scene_path])
		holder.free()
	quit()
