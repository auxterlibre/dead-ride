extends SceneTree
# CLI wrapper; args after -- are an optional GLB path then character name.

const DEFAULT_GLB:String = "res://_not_exported/character/Mannequin_Medium.glb"
const DEFAULT_NAME:String = "mannequin"

var _lib:GDScript


func _init() -> void:
	# Script-relative path: survives folder moves.
	_lib = load((get_script() as Script).resource_path.get_base_dir().path_join("extract_lib.gd"))
	var args:PackedStringArray = OS.get_cmdline_user_args()
	var glb_path:String = args[0] if args.size() > 0 else DEFAULT_GLB
	var char_name:String = args[1] if args.size() > 1 else DEFAULT_NAME
	var saved:PackedStringArray = _lib.extract_character_body(glb_path, char_name)
	for mesh_path in saved:
		print("- %s -> %s" % [glb_path, mesh_path])
	print("Extracted %d meshes for '%s'" % [saved.size(), char_name])
	quit()
