extends Node

const ExtractLib = preload("res://_tools/asset_extractor/extract_lib.gd")

const BASE: String = "res://scenes/characters/humanoid_base.tscn"
const LIBRARY: String = "res://assets/animations/zombie/zombie_library.tres"
const BIND_SOURCE: String = "res://assets/meshes/humanoid/parts/body_a_1_skin.tres"
const OUT: String = "res://assets/animations/zombie/horde_animation_set.res"
const FPS: float = 30.0
const CLIPS: PackedStringArray = ["idle", "shuffling", "crouch_walk_forward", "run_forward",
		"attack_bite", "attack_hand", "zombie_attack", "hit_reaction", "death_backward", "fall",
		"get_up", "crawl_forward", "eating", "convulsing", "gangnam_style"]


func _ready():
	var body: Node3D = (load(BASE) as PackedScene).instantiate()
	add_child(body)
	var tree: AnimationTree = body.get_node("BodyContainer/AnimationTree")
	tree.active = false
	var player: AnimationPlayer = body.get_node("BodyContainer/AnimationPlayer")
	player.add_animation_library("zombie", load(LIBRARY))
	var skeleton: Skeleton3D = body.get_node("%GeneralSkeleton")
	var binds: Array[Transform3D] = []
	var skin: Skin = load(BIND_SOURCE)
	for i in skeleton.get_bone_count():
		var found: bool = false
		for b in skin.get_bind_count():
			if skin.get_bind_name(b) == skeleton.get_bone_name(i):
				binds.append(skin.get_bind_pose(b))
				found = true
				break
		if not found:
			binds.append(Transform3D.IDENTITY)
	await get_tree().process_frame

	var set: HordeAnimationSet = HordeAnimationSet.new()
	set.fps = FPS
	set.bone_count = skeleton.get_bone_count()
	var matrices: PackedFloat32Array = PackedFloat32Array()
	var frame_index: int = 0
	for clip_name in CLIPS:
		var clip: Animation = player.get_animation("zombie/" + clip_name)
		var frames: int = maxi(1, ceili(clip.length * FPS))
		set.clips[clip_name] = {"start": frame_index, "frames": frames,
				"loop": clip.loop_mode != Animation.LOOP_NONE}
		player.play("zombie/" + clip_name)
		for f in frames:
			player.seek(minf(f / FPS, clip.length), true)
			skeleton.force_update_all_bone_transforms()
			for bone in skeleton.get_bone_count():
				var matrix: Transform3D = skeleton.get_bone_global_pose(bone) * binds[bone]
				var basis: Basis = matrix.basis
				var origin: Vector3 = matrix.origin
				for row in 3:
					matrices.append(basis[0][row])
					matrices.append(basis[1][row])
					matrices.append(basis[2][row])
					matrices.append(origin[row])
			frame_index += 1
	set.frame_count = frame_index
	set.matrices = matrices
	var error: Error = ResourceSaver.save(set, OUT)
	if error != OK:
		push_error("horde animation set: save failed with %d" % error)
	print("DBG horde animation set: %d clips, %d frames, %d bones, %.1f MB -> %s" % [
			set.clips.size(), set.frame_count, set.bone_count, matrices.size() * 4 / 1048576.0, OUT])
	for clip_name in CLIPS:
		print("DBG   %-20s start %5d frames %4d loop %s" % [clip_name, set.clips[clip_name].start,
				set.clips[clip_name].frames, set.clips[clip_name].loop])
	get_tree().quit()
