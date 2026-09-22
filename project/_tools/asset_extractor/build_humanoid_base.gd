extends Node

const ExtractLib = preload("res://_tools/asset_extractor/extract_lib.gd")

const OLD_BASE: String = "res://scenes/characters/character_base.tscn"
const SOURCE: String = "res://_not_exported/Zombies_parts.blend"
const OUT: String = "res://scenes/characters/humanoid_base.tscn"
const LIBRARY: String = "res://assets/animations/humanoid/humanoid_library.tres"
const TREE: String = "res://assets/animations/humanoid/humanoid_blend_tree.tres"
const OUTFIT_SCRIPT: String = "res://scripts/characters/outfit_manager.gd"
const CAPSULE_RADIUS: float = 0.35
const CAPSULE_HEIGHT: float = 1.75
const GRIP_RIGHT: Transform3D = Transform3D(Basis(Quaternion(0.215749, -0.525686, -0.438703, 0.696165)), Vector3.ZERO)
const GRIP_RIGHT_ONE_HANDED: Transform3D = Transform3D(Basis(Quaternion(0.156357, -0.315088, -0.413013, 0.840055)), Vector3.ZERO)


func _ready():
	var base: Node3D = (load(OLD_BASE) as PackedScene).instantiate()
	base.name = "HumanoidBase"
	base.scene_file_path = ""
	var container: Node3D = base.get_node("BodyContainer")
	var old_rig: Node = container.get_node("Rig_Medium")
	var old_skeleton: Skeleton3D = old_rig.get_node("Skeleton3D")
	var aim_look: LookAtModifier3D = old_skeleton.get_node("AimLook")
	var hand_right: BoneAttachment3D = old_skeleton.get_node("HandSlotRight")
	var hand_left: BoneAttachment3D = old_skeleton.get_node("HandSlotLeft")
	var face_wear: BoneAttachment3D = old_skeleton.get_node("FaceWear")
	for node in [aim_look, hand_right, hand_left, face_wear]:
		disown(node)
		old_skeleton.remove_child(node)
	container.remove_child(old_rig)
	old_rig.free()
	container.set_script(load(OUTFIT_SCRIPT))

	var zombies: Node = (load(SOURCE) as PackedScene).instantiate()
	var master: Skeleton3D = zombies.get_node("Skeleton").find_children("*", "Skeleton3D", true, false)[0]
	var skeleton: Skeleton3D = Skeleton3D.new()
	skeleton.name = "GeneralSkeleton"
	for i in master.get_bone_count():
		skeleton.add_bone(master.get_bone_name(i))
	for i in master.get_bone_count():
		skeleton.set_bone_parent(i, master.get_bone_parent(i))
		skeleton.set_bone_rest(i, master.get_bone_rest(i))
	skeleton.reset_bone_poses()
	skeleton.motion_scale = master.motion_scale
	zombies.free()

	var rig: Node3D = Node3D.new()
	rig.name = "Rig"
	container.add_child(rig)
	container.move_child(rig, 0)
	rig.add_child(skeleton)
	attach(skeleton, hand_right, "RightHandProp")
	hand_right.grip = GRIP_RIGHT
	hand_right.grip_one_handed = GRIP_RIGHT_ONE_HANDED
	attach(skeleton, hand_left, "LeftHandProp")
	attach(skeleton, face_wear, "Head")
	for child in face_wear.get_children():
		child.mesh = null
		child.skin = null
	aim_look.bone_name = "Chest"
	aim_look.bone = skeleton.find_bone("Chest")
	skeleton.add_child(aim_look)

	var tree: AnimationTree = container.get_node("AnimationTree")
	tree.tree_root = load(TREE)
	tree.remove_animation_library("gen")
	tree.add_animation_library("gen", load(LIBRARY))
	var player: AnimationPlayer = container.get_node("AnimationPlayer")
	player.remove_animation_library("character_library")
	player.add_animation_library("character_library", load(LIBRARY))

	var collision: CollisionShape3D = base.get_node("CollisionShape")
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = CAPSULE_RADIUS
	capsule.height = CAPSULE_HEIGHT
	collision.shape = capsule
	collision.position = Vector3(0.0, CAPSULE_HEIGHT * 0.5, 0.0)
	var hurt_shape: CollisionShape3D = base.get_node("HurtBox/CollisionShape3D")
	var hurt_box: BoxShape3D = BoxShape3D.new()
	hurt_box.size = Vector3(0.7, CAPSULE_HEIGHT, 0.5)
	hurt_shape.shape = hurt_box
	hurt_shape.position = Vector3(0.0, CAPSULE_HEIGHT * 0.5, 0.0)

	own(base, base)
	skeleton.unique_name_in_owner = true
	var packed: PackedScene = PackedScene.new()
	packed.pack(base)
	packed.take_over_path(OUT)
	ExtractLib.save_keeping_uid(packed, OUT)
	print("DBG humanoid base: %d bones, %d nodes, root script %s -> %s" % [skeleton.get_bone_count(),
			base.find_children("*", "", true, false).size(),
			base.get_script().resource_path if base.get_script() else "MISSING", OUT])
	base.free()
	get_tree().quit()


func attach(p_skeleton: Skeleton3D, p_attachment: BoneAttachment3D, p_bone: String):
	p_attachment.transform = Transform3D.IDENTITY
	p_attachment.bone_name = p_bone
	p_attachment.bone_idx = p_skeleton.find_bone(p_bone)
	p_skeleton.add_child(p_attachment)


func disown(p_node: Node):
	p_node.owner = null
	for child in p_node.get_children():
		disown(child)


func own(p_node: Node, p_owner: Node):
	for child in p_node.get_children():
		child.owner = p_owner
		own(child, p_owner)
