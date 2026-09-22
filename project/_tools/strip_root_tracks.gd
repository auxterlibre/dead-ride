extends SceneTree
# Strips baked root-motion tracks that fight the controller's facing; args after -- are clip names.

const ANIM_DIR:String = "res://assets/animations/character"
const EXTRACT_LIB:String = "res://_tools/asset_extractor/extract_lib.gd"


func _init() -> void:
	run()
	quit()


func run() -> void:
	var clips:PackedStringArray = OS.get_cmdline_user_args()
	if clips.is_empty():
		print("usage: strip_root_tracks.gd -- <clip_name> [clip_name...]")
		return
	var save_lib:GDScript = load(EXTRACT_LIB)
	for clip_name in clips:
		var path:String = "%s/%s.tres" % [ANIM_DIR, clip_name]
		var anim:Animation = load(path) as Animation
		if anim == null:
			print("- %s: NOT FOUND" % clip_name)
			continue
		var removed:int = 0
		for i in range(anim.get_track_count() - 1, -1, -1):
			if anim.track_get_path(i).get_subname_count() == 0:
				anim.remove_track(i)
				removed += 1
		if removed > 0:
			save_lib.save_keeping_uid(anim, path)
		print("- %s: removed %d root tracks, %d bone tracks kept" % [
				clip_name, removed, anim.get_track_count()])
