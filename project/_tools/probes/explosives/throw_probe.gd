extends ProbeBase
# Does the arc the preview draws match where the grenade actually lands, and
# does the stack draw down as they are thrown?


func _ready():
	var game: Node = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	for i in 8:
		await get_tree().process_frame
	var player: Character = InputManager.player
	var carried: CharacterInventory = player.carried
	var grenade: ExplosiveData = load("res://data/items/explosives/grenade.tres")
	var throwing: PlayerThrow = null
	for child in player.get_children():
		if child is PlayerThrow:
			throwing = child
	check(throwing != null, "the player carries a PlayerThrow", str(throwing))
	if throwing == null:
		get_tree().quit()
		return

	# Stacking: three into one cell, one entry.
	check(grenade.get_max_stack() == 3, "a grenade stacks three deep",
			str(grenade.get_max_stack()))
	var before: int = carried.inventory.entries.size()
	var left: int = carried.inventory.add(grenade, 3)
	var entry: InventoryEntry = null
	for candidate in carried.inventory.entries:
		if candidate.item is ExplosiveData:
			entry = candidate
	check(left == 0 and entry != null and entry.count == 3,
			"three land as ONE stack, not three entries",
			"%d left over, %d entries added, count %d" % [left,
			carried.inventory.entries.size() - before,
			entry.count if entry else -1])

	# Ready it on the first utility slot.
	var slot: int = CharacterInventory.WEAPON_SLOTS
	carried.assign_quick_slot(entry, slot)
	carried.select_slot(slot)
	check(throwing.selected() == grenade, "selecting the slot readies the throwable",
			str(throwing.selected()))
	var weapons: CharacterWeapons = player.weapons
	check(weapons.is_holstered() and weapons.held_prop != null,
			"and swaps the gun out for the grenade in hand",
			"holstered=%s prop=%s" % [weapons.is_holstered(), weapons.held_prop])
	# Back to a weapon slot: the grenade leaves the hand and the gun comes out.
	carried.select_slot(0)
	check(not weapons.is_holstered() and weapons.held_prop == null,
			"drawing a weapon takes the grenade back out of the hand",
			"holstered=%s prop=%s" % [weapons.is_holstered(), weapons.held_prop])
	carried.select_slot(slot)

	# Aim somewhere ahead and solve.
	# Through the CURSOR, the way the game does it: the throw picks what the
	# reticle is over, so setting aim_position no longer steers it.
	var spot: Vector3 = player.global_position + Vector3(6.0, 0.0, 0.0)
	throwing.aim.mouse_position = get_viewport().get_camera_3d().unproject_position(spot)
	throwing.solve(throwing.aim_point())
	var arc: PackedVector3Array = throwing.preview.trace()
	var predicted: Vector3 = throwing.preview.landing
	check(arc.size() > 2, "the preview traces an arc", "%d points" % arc.size())

	# Now throw with the SAME solved velocity and let physics run.
	# The SWING, not a bare release: wind-up pose, then the marker times the
	# hand opening. Origin is taken from the placeholder actually in the hand.
	var count_before: int = entry.count
	throwing.aim.set_physics_process(false)
	throwing.begin_swing(grenade)
	check(throwing.holds_attack(), "the swing owns the attack button",
			str(throwing.holds_attack()))
	# The clips being in the LIBRARY is not enough - set_upper_animation switches
	# a transition node, and a name it has no input for errors every frame while
	# silently animating nothing. This is the half that was missed.
	var tree: AnimationTree = player.find_child("AnimationTree", true, false)
	var transition: AnimationNodeTransition = tree.tree_root.get_node("upper_state")
	var inputs: Array = []
	for i in transition.input_count:
		inputs.append(transition.get_input_name(i))
	for pose in [PlayerThrow.POSE_READY, PlayerThrow.POSE_THROW]:
		check(pose in inputs and tree.tree_root.has_node("anim_" + pose),
				"%s is a wired upper_state input" % pose,
				"input=%s node=%s" % [pose in inputs,
				tree.tree_root.has_node("anim_" + pose)])

	var marker: float = throwing.animator.get_marker_time(
			PlayerThrow.POSE_THROW, PlayerThrow.RELEASE_MARKER)
	check(marker > 0.0, "the throw clip carries a release marker", "%.3fs" % marker)
	var hand: Vector3 = throwing.throw_origin()
	check(hand.distance_to(player.global_position + Vector3.UP * 1.25) > 0.05,
			"the origin comes off the placeholder, not the chest",
			"hand %s vs chest-ish %s" % [hand.snappedf(0.01),
			(player.global_position + Vector3.UP * 1.25).snappedf(0.01)])
	# Nothing thrown until the marker lands.
	check(count_before == entry.count and live_grenade() == null,
			"nothing leaves the hand before the marker", "%d left" % entry.count)
	var waited: float = 0.0
	while live_grenade() == null and waited < 2.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	check(absf(waited - marker) < 0.12, "and it lets go ON the marker",
			"released at %.3fs, marker %.3fs" % [waited, marker])
	check(entry.count == count_before - 1, "throwing takes one off the stack",
			"%d -> %d" % [count_before, entry.count])
	var live: Grenade = live_grenade()
	check(live != null, "a grenade is in the world", str(live))
	if live == null:
		report()
		return
	# FIRST contact is what the ring promises; where it rolls to afterwards is a
	# separate question, so measure both.
	var first: Vector3 = live.global_position
	var resting: Vector3 = first
	var touched: bool = false
	var falling: float = 0.0
	for i in 200:
		await get_tree().physics_frame
		if not is_instance_valid(live):
			break
		resting = live.global_position
		if not touched and falling < -0.5 and live.linear_velocity.y > -0.2:
			first = resting
			touched = true
		falling = live.linear_velocity.y
	var impact: float = Vector3(predicted.x - first.x, 0.0,
			predicted.z - first.z).length()
	var roll: float = Vector3(first.x - resting.x, 0.0,
			first.z - resting.z).length()
	check(impact < 1.5, "it FIRST lands where the preview said, within 1.5m",
			"predicted %s, hit %s, off by %.2fm" % [predicted.round(),
			first.round(), impact])
	# 2m against a 5.4m blast: a grenade that lands dead is what a ton of lead
	# does, so it is allowed to hop and settle a little short of where it hit.
	check(roll < 2.0, "and does not roll far past the ring",
			"rolled %.2fm to %s" % [roll, resting.round()])
	report()


func report():
	finish()


func live_grenade() -> Grenade:
	for node in get_tree().current_scene.get_children():
		if node is Grenade:
			return node
	return null
