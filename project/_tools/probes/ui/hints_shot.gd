extends ProbeBase
# DBG shot (windowed): the dot's three looks over a real crate.

const FAR: float = 5.0  # m - noticed, out of reach
const NEAR: float = 1.5  # m - in reach, and clear of the hull that shoves a body out

@onready var GAME: PackedScene = load("uid://b56i3a2diovj6")  # scenes/game.tscn


func _ready():
	if not windowed("the interaction dots"):
		finish()
		return
	var game: Node = GAME.instantiate()
	add_child(game)
	await settle(8)
	var player: Character = InputManager.player
	player.aim.process_mode = Node.PROCESS_MODE_DISABLED  # the shot owns the rig
	var crates: Array = get_tree().get_nodes_in_group("loot_container")
	if not check(not crates.is_empty(), "the map carries a crate to advertise",
			"%d crates" % crates.size()):
		finish()
		return
	var crate: LootContainer = crates.front()
	var offer: InteractiveArea = find_first(crate, "InteractiveArea")
	var hints: Node = game.find_child("InteractionHints", true, false)

	await look(player, offer, hints, FAR, "hint_far",
			InteractiveArea.Stage.HINT, false, false)
	await look(player, offer, hints, NEAR, "hint_in_reach",
			InteractiveArea.Stage.PROMPT, true, false)

	# The real path: searching opens the pack, which pauses and hides the layer.
	crate.open()
	await settle(4)
	var screen: BackpackScreen = find_first(game, "BackpackScreen")
	screen.close()
	check(offer.spent, "a searched crate marks its own offer spent", "spent")
	await look(player, offer, hints, NEAR, "hint_searched",
			InteractiveArea.Stage.PROMPT, true, true)
	finish()


# Read AFTER the draw, and re-stand first: a parked body drifts on the slope.
func look(p_player: Character, p_offer: InteractiveArea, p_hints: Node,
		p_distance: float, p_name: String, p_stage: int, p_ring: bool,
		p_hollow: bool):
	stand(p_player, p_offer, p_distance)
	await settle(40)
	stand(p_player, p_offer, p_distance)
	await settle(6)
	var frame: Image = await capture()
	check(p_offer.stage == p_stage, "%s: the offer is at stage %d" % [p_name, p_stage],
			"stage %d at %.1fm" % [p_offer.stage, p_distance])
	var dot: InteractionHintDot = p_hints.dots.get(p_offer)
	if not check(dot != null and dot.visible, "%s: the dot is up" % p_name,
			"drawn" if dot else "no dot"):
		return
	check(get_viewport().get_visible_rect().has_point(dot.position + dot.size / 2.0),
			"%s: and inside the frame" % p_name, str(dot.position))
	check(dot.ring.visible == p_ring and dot.hollow.visible == p_hollow \
			and dot.solid.visible != p_hollow,
			"%s: ring %s, %s core" % [p_name, "on" if p_ring else "off",
			"hollow" if p_hollow else "solid"],
			"ring %s, solid %s, hollow %s"
			% [dot.ring.visible, dot.solid.visible, dot.hollow.visible])
	save_shot(frame, p_name)


# Stands the player p_distance south of the point, rig turned to face it.
func stand(p_player: Character, p_area: Node3D, p_distance: float):
	p_player.global_position = p_area.global_position \
			- Vector3(0.0, 0.0, 1.0) * p_distance
	p_player.global_position.y = 0.0
	var to_point: Vector3 = p_area.global_position - p_player.global_position
	p_player.body_container.global_rotation = Vector3(0.0,
			atan2(to_point.x, to_point.z), 0.0)
