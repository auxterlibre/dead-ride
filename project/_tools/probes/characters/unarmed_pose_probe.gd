extends ProbeBase
# DBG probe: the upper layer's wiring. A transition input that carries a NAME
# but no connected node does not fall back to a rest pose - it writes nothing,
# the filtered arm bones keep their last values, and the hands FREEZE on
# whatever state was connected before. The fists shipped that way: named on
# inputs 11-13, connected to nothing, so a bare-handed character wore the pose
# of whatever it had holstered. Route-independence is how that is measured -
# a real pose lands in the same place whichever state it came from.

const UPPER: StringName = &"upper_state"
const CONTROL: String = "use_item"  # a wired input, for the noise floor
const DEPARTURES: Array[String] = ["melee_2h_idle", "ranged_2h_aiming"]

var player: Character
var skeleton: Skeleton3D
var animator: CharacterAnimator
var tree: AnimationNodeBlendTree
var hand: int = -1


func _ready():
	build_floor()
	player = (load("res://scenes/characters/player.tscn") as PackedScene).instantiate()
	add_child(player)
	await settle(20)
	animator = player.animator
	skeleton = player.find_child("Skeleton3D", true, false) as Skeleton3D
	tree = animator.animation_tree.tree_root as AnimationNodeBlendTree
	hand = skeleton.find_bone("hand.r") if skeleton else -1
	if not check(tree != null and hand >= 0, "the rig carries the blend tree",
			"tree %s, hand.r bone %d" % [tree, hand]):
		finish()
		return
	test_the_wiring()
	await test_the_pose()
	finish()


# --- every name the weapons table asks for, across every weapon type
func test_the_wiring():
	var asked: Array[String] = []
	var unwired: Array[String] = []
	for type in CharacterWeapons.UPPER_ANIMATIONS:
		var table: Dictionary = CharacterWeapons.UPPER_ANIMATIONS[type]
		for key in table:
			var value = table[key]
			for clip in (value if value is Array else [value]):
				if asked.has(clip):
					continue
				asked.append(clip)
				if input_of(clip) < 0 or not connected(clip):
					unwired.append(clip)
	check(unwired.is_empty(),
			"every clip the weapons table asks for reaches a connected input",
			"%d names, unwired: %s" % [asked.size(),
			"none" if unwired.is_empty() else ", ".join(unwired)])
	# Named but never requested: the kick is DEALT by nothing (a leg-less kick on
	# the arm/chest filter reads as a spasm), yet it must stay wired or the input
	# is a trap for whoever deals it next.
	var kick: String = "melee_unarmed_attack_kick"
	check(connected(kick), "the kick stays wired though nothing deals it yet",
			"input %d" % input_of(kick))


# --- the wiring's actual consequence, at the skeleton
func test_the_pose():
	animator.upper_weight = 1.0
	await settle(40)
	var fists: Dictionary = CharacterWeapons.UPPER_ANIMATIONS[Enums.WeaponType.MELEE_UNARMED]
	var punch: String = (fists.attacks as Array)[0]
	# What "the same pose twice" costs on a KNOWN-wired input. Every bar below is
	# measured against this rather than a number picked by hand.
	var floor_spread: float = await spread(CONTROL)
	var idle_spread: float = await spread(fists.idle)
	check(idle_spread < maxf(floor_spread, 0.005) * 3.0,
			"the fists' idle is a pose, not the last state's leftovers",
			"%.4fm apart by route, against a wired %.4fm" % [idle_spread, floor_spread])
	var punch_spread: float = await spread(punch)
	check(punch_spread < maxf(floor_spread, 0.005) * 3.0,
			"and so is the punch", "%.4fm apart by route" % punch_spread)
	# Both are poses - but the same pose twice would be no swing at all.
	var at_rest: Vector3 = await route(DEPARTURES[0], fists.idle)
	var at_punch: Vector3 = await route(DEPARTURES[0], punch)
	var travel: float = at_rest.distance_to(at_punch)
	check(travel > maxf(floor_spread, 0.005) * 10.0,
			"and the punch throws the hand clear of the idle",
			"%.3fm of pose, against a %.4fm floor" % [travel, floor_spread])


# How far apart one destination lands when reached from two different states.
func spread(p_to: String) -> float:
	var a: Vector3 = await route(DEPARTURES[0], p_to)
	var b: Vector3 = await route(DEPARTURES[1], p_to)
	return a.distance_to(b)


func route(p_from: String, p_to: String) -> Vector3:
	animator.set_upper_animation(p_from)
	await settle(60)
	animator.set_upper_animation(p_to)
	await settle(60)
	return skeleton.get_bone_global_pose(hand).origin


func input_of(p_name: String) -> int:
	var state: AnimationNodeTransition = tree.get_node(UPPER) as AnimationNodeTransition
	for i in state.get_input_count():
		if state.get_input_name(i) == p_name:
			return i
	return -1


func connected(p_name: String) -> bool:
	var index: int = input_of(p_name)
	if index < 0:
		return false
	var links: Array = tree.get("node_connections")
	for i in range(0, links.size(), 3):
		if StringName(links[i]) == UPPER and int(links[i + 1]) == index:
			return true
	return false


# The hips are OUTSIDE the upper layer's filter, so hand.r's skeleton-space pose
# rides them; a character left falling would smear every measurement.
func build_floor():
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 20  # walls|ground, what characters stand on
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(40.0, 1.0, 40.0)
	shape.shape = box
	shape.position.y = -0.5
	body.add_child(shape)
	add_child(body)
