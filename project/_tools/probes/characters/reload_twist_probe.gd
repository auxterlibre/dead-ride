extends ProbeBase
# Reloading must not swing the body: the chest look-at holds aim_yaw_offset,
# and dropping it mid-reload un-twists the torso (~52 deg measured on the
# rifle) into the clip and back. Measured POST-modifier via a BoneAttachment -
# get_bone_global_pose reads the raw clips and cannot see the look-at at all.

const EXPECTED_CHECKS: int = 4
const TWIST_LIMIT: float = 5.0  # deg of chest yaw a reload may move

var weapons: CharacterWeapons
var probe_bone: BoneAttachment3D


func _ready():
	var gym: Node = (load("res://_tools/gym/gym.tscn") as PackedScene).instantiate()
	add_child(gym)
	var player: Character = gym.get_node("Player")
	for child in player.get_children():
		if child is CharacterWeapons:
			weapons = child
	var skeleton: Skeleton3D = player.find_child("Skeleton3D", true, false)
	probe_bone = BoneAttachment3D.new()
	skeleton.add_child(probe_bone)
	probe_bone.bone_name = "chest"
	var patience: int = 120
	while weapons.inventory.is_empty() and patience > 0:
		await get_tree().physics_frame
		patience -= 1
	weapons.equip(1)
	check(weapons.current_weapon.aim_yaw_offset != 0.0,
			"the test weapon carries a yaw offset",
			"%s at %.0f deg" % [weapons.current_weapon.name,
			weapons.current_weapon.aim_yaw_offset])
	weapons.current_weapon.reload_time = 10  # ~1s, so the probe is quick
	await seconds(2.0)

	var aim: PlayerAim = weapons.aim
	check(aim.look_modifier.influence > 0.9, "the look-at is open while armed",
			"%.2f" % aim.look_modifier.influence)
	weapons.current_weapon.current_ammo = 2
	var baseline: float = probe_bone.global_rotation.y
	weapons.reload()
	var worst: float = 0.0
	var least_influence: float = 1.0
	for i in int(2.0 * 60.0):
		await get_tree().physics_frame
		worst = maxf(worst, absf(rad_to_deg(angle_difference(
				baseline, probe_bone.global_rotation.y))))
		least_influence = minf(least_influence, aim.look_modifier.influence)
	check(worst < TWIST_LIMIT, "the chest holds through the reload",
			"%.1f deg (limit %.0f)" % [worst, TWIST_LIMIT])
	check(least_influence > 0.9, "because the look-at never dropped",
			"%.2f" % least_influence)

	print("DBG %d passed, %d failed, %d of %d checks ran" % [
			passed, failed, passed + failed, EXPECTED_CHECKS])
	get_tree().quit()


func seconds(p_span: float):
	for i in int(p_span * 60.0):
		await get_tree().physics_frame
