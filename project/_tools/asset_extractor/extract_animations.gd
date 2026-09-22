extends SceneTree

const ExtractLib = preload("res://_tools/asset_extractor/extract_lib.gd")

const SOURCES: PackedStringArray = ["General", "MovementBasic", "MovementAdvanced",
		"CombatRanged", "CombatMelee", "Simulation"]
const SOURCE_DIR: String = "res://_not_exported/animations"
const OUT_DIR: String = "res://assets/animations/humanoid"
const LIBRARY_PATH: String = OUT_DIR + "/humanoid_library.tres"
const SKIPPED: PackedStringArray = ["T-Pose"]
const RENAMES: Dictionary = {
	"pickup": "pick_up",
	"running_holdingbow": "running_holding_bow",
	"running_holdingrifle": "running_holding_rifle",
	"lie_standup": "lie_stand_up",
	"sit_chair_standup": "sit_chair_stand_up",
	"sit_floor_standup": "sit_floor_stand_up",
}
const TRIMS: Dictionary = {"ranged_1h_shoot": 0.4, "ranged_2h_shoot": 0.4}
const ALIASES: Dictionary = {"throw_arm_back": "throw", "throw_arm_forward": "throw"}


func _init():
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var saved: Dictionary = {}
	for source in SOURCES:
		var scene: Node = (load("%s/Rig_Medium_%s.glb" % [SOURCE_DIR, source]) as PackedScene).instantiate()
		var player: AnimationPlayer = scene.find_child("AnimationPlayer", true, false)
		for clip_name in player.get_animation_list():
			if clip_name in SKIPPED:
				continue
			var name: String = snake(clip_name)
			var clip: Animation = player.get_animation(clip_name).duplicate()
			if TRIMS.has(name):
				clip.length = TRIMS[name]
			var path: String = "%s/%s.tres" % [OUT_DIR, name]
			clip.resource_name = name
			clip.take_over_path(path)
			ExtractLib.save_keeping_uid(clip, path)
			saved[name] = clip
		scene.free()
	for alias in ALIASES:
		saved[alias] = saved[ALIASES[alias]]
	var library: AnimationLibrary = AnimationLibrary.new()
	var names: Array = saved.keys()
	names.sort()
	for name in names:
		library.add_animation(name, saved[name])
	library.take_over_path(LIBRARY_PATH)
	ExtractLib.save_keeping_uid(library, LIBRARY_PATH)
	print("DBG humanoid animations: %d clips, %d aliases -> %s" % [
			saved.size() - ALIASES.size(), ALIASES.size(), LIBRARY_PATH])
	quit()


func snake(p_name: String) -> String:
	var name: String = p_name.to_lower()
	for bit in [" ", "-"]:
		name = name.replace(bit, "_")
	for bit in ["(", ")"]:
		name = name.replace(bit, "")
	return RENAMES.get(name, name)
