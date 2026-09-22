extends SceneTree

const ExtractLib = preload("res://_tools/asset_extractor/extract_lib.gd")

const SOURCE: String = "res://_not_exported/Zombies_parts.blend"
const OUT_DIR: String = "res://assets/animations/zombie"
const LIBRARY_PATH: String = OUT_DIR + "/zombie_library.tres"
const SKIPPED: PackedStringArray = ["Action"]
const ONE_SHOTS: PackedStringArray = ["attack_bite", "attack_hand", "zombie_attack", "death_backward",
		"fall", "get_up", "hit_reaction", "run_to_flip", "running_forward_flip", "climb_ladder",
		"head_spin", "breakdance_ready", "button_pushing"]


func _init():
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var scene: Node = (load(SOURCE) as PackedScene).instantiate()
	var player: AnimationPlayer = scene.find_child("AnimationPlayer", true, false)
	var library: AnimationLibrary = AnimationLibrary.new()
	var loops: int = 0
	var count: int = 0
	for clip_name in player.get_animation_list():
		if clip_name in SKIPPED:
			continue
		var name: String = snake(clip_name)
		var clip: Animation = player.get_animation(clip_name).duplicate()
		clip.loop_mode = Animation.LOOP_NONE if name in ONE_SHOTS else Animation.LOOP_LINEAR
		if clip.loop_mode == Animation.LOOP_LINEAR:
			loops += 1
		var path: String = "%s/%s.tres" % [OUT_DIR, name]
		clip.resource_name = name
		clip.take_over_path(path)
		ExtractLib.save_keeping_uid(clip, path)
		library.add_animation(name, clip)
		count += 1
	scene.free()
	library.take_over_path(LIBRARY_PATH)
	ExtractLib.save_keeping_uid(library, LIBRARY_PATH)
	print("DBG zombie animations: %d clips (%d looping) -> %s" % [count, loops, LIBRARY_PATH])
	quit()


func snake(p_name: String) -> String:
	var name: String = p_name.replace(" ", "")
	return name.to_snake_case().replace("__", "_")
