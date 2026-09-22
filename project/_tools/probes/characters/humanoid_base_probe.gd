extends ProbeBase
# DBG probe: the humanoid base - the Zombies-kit rig under the humanoid profile
# names, an outfit dressed from the modular parts, the retargeted KayKit clips
# driving it through the same blend tree, and the hand and aim attachments on
# the bones the components expect.

const ROOT_LIFT: float = 0.05


func _ready():
	var body: Character = (load("res://scenes/characters/humanoid_base.tscn") as PackedScene).instantiate()
	body.data = load("res://data/characters/humanoid_test.tres")
	var movement: CharacterMovement = CharacterMovement.new()
	movement.name = "CharacterMovement"
	movement.visual = body.get_node("BodyContainer")
	body.add_child(movement)
	var animator: CharacterAnimator = body.get_node("CharacterAnimator")
	animator.movement = movement
	add_child(body)
	await settle(10)

	var skeleton: Skeleton3D = body.get_node("%GeneralSkeleton")
	check(skeleton != null and skeleton.get_bone_count() == 47, "the rig is the 47-bone kit skeleton",
			str(skeleton.get_bone_count() if skeleton else -1))
	for bone in ["Hips", "Chest", "Head", "LeftHand", "RightHandProp", "LeftFoot"]:
		check(skeleton.find_bone(bone) >= 0, "bone %s is there under its profile name" % bone, "")
	var hand: BoneAttachment3D = body.get_node("%HandSlotRight")
	check(hand.bone_name == "RightHandProp", "the right hand slot rides the prop bone", hand.bone_name)
	var aim: LookAtModifier3D = skeleton.get_node("AimLook")
	check(aim.bone_name == "Chest" and aim.get_node_or_null(aim.target_node) != null,
			"the aim look-at points at the chest and finds its target", aim.bone_name)

	# --- the outfit is dressed from parts
	var worn: Array[Node] = skeleton.find_children("*", "MeshInstance3D", false, false)
	check(worn.size() == 8, "eight outfit parts were dressed", str(worn.map(func(p): return p.name)))
	var skinned: int = 0
	for part in worn:
		if part.skin != null and part.skin.get_bind_count() == 47:
			skinned += 1
	check(skinned == worn.size(), "every part carries a 47-bone skin", "%d of %d" % [skinned, worn.size()])

	# --- the retargeted clips move the rig
	var tree: AnimationTree = body.get_node("BodyContainer/AnimationTree")
	animator.set_physics_process(false)
	check(tree.has_animation("gen/idle_a") and tree.has_animation("gen/running_a")
			and tree.has_animation("gen/ranged_1h_aiming") and tree.has_animation("gen/throw_arm_back"),
			"the humanoid library carries the clips the tree names", "")
	var leg: int = skeleton.find_bone("LeftUpperLeg")
	tree.set(CharacterAnimator.PACE_PARAM, 1.0)
	tree.set(CharacterAnimator.TORSO_PACE_PARAM, 1.0)
	var poses: Array = []
	for i in 40:
		await get_tree().process_frame
		if i % 10 == 9:
			poses.append(skeleton.get_bone_global_pose(leg).basis.get_euler())
	var moved: float = 0.0
	for i in poses.size() - 1:
		moved = maxf(moved, poses[i].distance_to(poses[i + 1]))
	check(moved > 0.05, "the running blend swings the leg", "%.3f rad between samples" % moved)
	var head_height: float = skeleton.get_bone_global_pose(skeleton.find_bone("Head")).origin.y
	check(head_height > 1.3 and head_height < 1.8, "the head sits at human height",
			"%.2f m" % head_height)

	# --- the raw player path plays a death clip
	var player: AnimationPlayer = body.get_node("BodyContainer/AnimationPlayer")
	check(player.has_animation("character_library/death_a"), "the player carries the death clips", "")

	# --- the kit's own zombie clips drive the same rig
	player.add_animation_library("zombie", load("res://assets/animations/zombie/zombie_library.tres"))
	check(player.has_animation("zombie/run_forward") and player.has_animation("zombie/attack_bite")
			and player.has_animation("zombie/death_backward"), "the zombie library carries run, bite and death", "")
	tree.active = false
	player.play("zombie/run_forward")
	poses.clear()
	for i in 40:
		await get_tree().process_frame
		if i % 10 == 9:
			poses.append(skeleton.get_bone_global_pose(leg).basis.get_euler())
	moved = 0.0
	for i in poses.size() - 1:
		moved = maxf(moved, poses[i].distance_to(poses[i + 1]))
	check(moved > 0.05, "the zombie run swings the leg", "%.3f rad between samples" % moved)
	finish()
