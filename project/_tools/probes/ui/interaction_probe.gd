extends Node
# DBG probe: the two-stage reveal, the reach knob, the car's points, the menu.

var passed: int = 0
var failed: int = 0
var hints_on: int = 0
var hints_off: int = 0
var pokes: int = 0


func _ready():
	ProbeBase.silence()  # not on ProbeBase yet, so it mutes for itself
	var gym: Node = (load("res://_tools/gym/gym.tscn") as PackedScene).instantiate()
	add_child(gym)
	for i in 4:
		await get_tree().process_frame
	var player: Character = InputManager.player
	player.aim.process_mode = Node.PROCESS_MODE_DISABLED  # the probe owns the rig
	var area: InteractiveArea = InteractiveArea.new()
	area.callback = "poke"
	area.action_label = "Poke"
	area.target_object = self
	add_child(area)
	area.global_position = Vector3(25.0, 1.0, 25.0)
	# This offer alone: the gym parks a car right by the spawn.
	Signals.interaction_hint_added.connect(func(p_source):
		if p_source == area:
			hints_on += 1)
	Signals.interaction_hint_removed.connect(func(p_source):
		if p_source == area:
			hints_off += 1)

	# --- past any shape it could have had, and still noticed
	stand(player, area, 5.0, 0.0)
	await settle()
	check(area.stage == InteractiveArea.Stage.HINT and area.player_near,
			"an offer beyond its reach still advertises",
			"stage %d, near %s, %.1fm reach"
			% [area.stage, area.player_near, area.prompt_range])

	# --- still outside the reach: a quiet hint, no prompt
	stand(player, area, 3.5, 180.0)
	await settle()
	check(area.stage == InteractiveArea.Stage.HINT and hints_on == 1,
			"still out of reach is a quiet hint",
			"stage %d, %d hints" % [area.stage, hints_on])
	check(InputManager.latest_for("interact").is_empty(), "and no key prompt yet",
			"clear")

	# --- close but facing away still hints
	stand(player, area, 1.8, 180.0)
	await settle()
	check(area.stage == InteractiveArea.Stage.HINT,
			"close but facing away still only hints", "stage %d" % area.stage)

	# --- turning to face it promotes to the prompt
	stand(player, area, 1.8, 0.0)
	await settle()
	check(area.stage == InteractiveArea.Stage.PROMPT,
			"facing it up close shows the prompt", "stage %d" % area.stage)
	check(InputManager.latest_for("interact").get("target") == self,
			"and the offer is registered", "registered")
	check(hints_on == 1 and hints_off == 0,
			"and the hint dot rides along instead of being retracted",
			"%d on, %d off" % [hints_on, hints_off])

	# --- hysteresis: a small drift keeps it, a real turn drops it
	stand(player, area, 1.8, 70.0)
	await settle()
	check(area.stage == InteractiveArea.Stage.PROMPT,
			"a shown prompt survives a small drift", "stage %d" % area.stage)
	stand(player, area, 1.8, 130.0)
	await settle()
	check(area.stage == InteractiveArea.Stage.HINT,
			"a real turn-away drops it back to the hint", "stage %d" % area.stage)

	# --- the held pour never drops mid-stream
	area.hold = true
	stand(player, area, 1.8, 0.0)
	await settle()
	Input.action_press("interact")
	await settle()
	stand(player, area, 1.8, 130.0)
	await settle()
	check(area.stage == InteractiveArea.Stage.PROMPT and pokes > 0,
			"a held pour survives the rig drifting",
			"stage %d, %d pokes" % [area.stage, pokes])
	Input.action_release("interact")
	await settle()
	check(area.stage == InteractiveArea.Stage.HINT,
			"and lets go when the key does", "stage %d" % area.stage)
	area.hold = false

	# --- disabling retracts everything
	stand(player, area, 1.8, 0.0)
	await settle()
	area.enabled = false
	await settle()
	check(area.stage == InteractiveArea.Stage.OFF \
			and InputManager.latest_for("interact").is_empty(),
			"disabling retracts hint and prompt alike", "off")
	area.enabled = true

	# --- walking out of notice range goes fully dark
	player.global_position = Vector3(-25.0, 0.0, 25.0)
	await settle()
	check(area.stage == InteractiveArea.Stage.OFF and hints_on == hints_off,
			"walking away goes dark", "%d on, %d off" % [hints_on, hints_off])

	# --- the reach is a NUMBER: widen it and the same spot becomes the prompt
	stand(player, area, 3.5, 0.0)
	await settle()
	check(area.stage == InteractiveArea.Stage.HINT, "3.5m is out of reach at 2.2",
			"stage %d" % area.stage)
	area.prompt_range = 4.0
	await settle()
	check(area.stage == InteractiveArea.Stage.PROMPT,
			"and in reach at 4.0 without a shape being touched",
			"stage %d" % area.stage)
	area.prompt_range = 2.2

	# --- the dot's three looks
	var dot: InteractionHintDot = (load("res://scenes/ui/input/interaction_hint_dot.tscn") \
			as PackedScene).instantiate()
	add_child(dot)
	dot.show_state(false, false)
	check(dot.solid.visible and not dot.hollow.visible and not dot.ring.visible,
			"an offer seen from a distance is a plain dot", "solid alone")
	dot.show_state(true, false)
	check(dot.ring.visible and dot.solid.visible and not dot.hollow.visible,
			"in position it gains the outer stroke", "ring and solid")
	dot.show_state(true, true)
	check(dot.hollow.visible and not dot.solid.visible and dot.ring.visible,
			"an offer already taken goes hollow, stroke and all", "ring and hollow")

	# --- and the looks ARRIVE. Not one frame has passed since the dot was
	# built, so both animations are still sitting on their first frame - which
	# is also what proves the flags above are set instantly and only the scale
	# and the fade are animated.
	# COLLAPSED IS A THRESHOLD, NOT A ZERO: Godot clamps a Control's scale to
	# CMP_EPSILON (1e-5) so it can never be zero, and is_zero_approx' strict <
	# lands exactly on that boundary and reads false.
	check(dot.scale.x < 0.01 and dot.modulate.a == 0.0,
			"a new dot starts collapsed and clear",
			"scale %.5f, alpha %.2f" % [dot.scale.x, dot.modulate.a])
	check(dot.ring.scale.x > 1.0 and dot.ring.modulate.a == 0.0,
			"and its ring starts wide, to close onto it",
			"ring scale %.2f, alpha %.2f" % [dot.ring.scale.x, dot.ring.modulate.a])
	# Polled on the tweens themselves: headless frames are not 1/60 of a second,
	# so a frame count would race a real-time animation.
	while dot.pop.is_valid() or dot.ring_pop.is_valid():
		await get_tree().process_frame
	check(dot.scale.is_equal_approx(Vector2.ONE) and dot.modulate.a == 1.0,
			"the dot lands exactly on its resting size",
			"scale %.2f, alpha %.2f" % [dot.scale.x, dot.modulate.a])
	check(dot.ring.scale.is_equal_approx(Vector2.ONE) and dot.ring.modulate.a == 1.0,
			"and the ring closes exactly onto it",
			"ring scale %.2f, alpha %.2f" % [dot.ring.scale.x, dot.ring.modulate.a])
	dot.queue_free()

	# --- a dot OUTLIVES its offer by exactly its exit animation
	stand(player, area, 1.8, 0.0)
	await settle()
	var hints: Node = gym.find_child("InteractionHints", true, false)
	check(hints != null and hints.dots.has(area),
			"the layer carries a dot for a noticed offer", str(hints))
	var live: InteractionHintDot = hints.dots[area]
	hints.remove_hint(area)
	check(is_instance_valid(live) and not hints.dots.has(area) \
			and hints.leaving.has(live),
			"a removed offer hands its dot over rather than freeing it",
			"%d leaving" % hints.leaving.size())
	await get_tree().process_frame
	# The claim rests on `dots` being EMPTY: the layer is up on the leaving dot
	# alone, which is the case that would otherwise cut its own exit short.
	check(hints.dots.is_empty() and hints.visible,
			"and the layer stays up on a leaving dot alone",
			"%d live, %d leaving" % [hints.dots.size(), hints.leaving.size()])
	while hints.leaving.has(live):
		await get_tree().process_frame
	check(not is_instance_valid(live), "which frees itself once it has gone",
			"freed")

	# --- the car's three precise points
	var car: Vehicle = (load("res://scenes/vehicles/car.tscn") \
			as PackedScene).instantiate()
	add_child(car)
	car.global_position = Vector3(-25.0, 0.5, -25.0)
	await get_tree().physics_frame
	var door: InteractiveArea = car.get_node("DoorInteractionArea")
	var trunk: InteractiveArea = car.get_node("TrunkInteractionArea")
	var repair: InteractiveArea = car.get_node("RepairInteractionArea")
	check(door.input_action == "interact" and trunk.input_action == "interact" \
			and repair.input_action == "interact",
			"every car point rides the one interact key", "all F")
	check(trunk.position.z < -1.5 and repair.position.z > 1.5,
			"trunk at the rear, repair at the nose",
			"trunk z %.1f, repair z %.1f" % [trunk.position.z, repair.position.z])
	check(not repair.enabled, "repair only advertises damage", "disabled")
	car.queue_free()

	# --- the popup menu serves, picks and closes
	var menu: InteractionMenu = (load("res://scenes/ui/menus/interaction_menu.tscn") \
			as PackedScene).instantiate()
	add_child(menu)
	await get_tree().process_frame
	Signals.interaction_menu_requested.emit("Test", [
		{"label": "One", "target": self, "callback": "poke"},
		{"label": "Two", "target": self, "callback": "poke"},
	])
	await get_tree().process_frame
	check(menu.visible and menu.options_box.get_child_count() == 2 \
			and get_tree().paused, "the menu opens paused with its options",
			"%d options" % menu.options_box.get_child_count())
	var before: int = pokes
	menu.pick(1)
	check(pokes == before + 1 and not menu.visible and not get_tree().paused,
			"picking runs the action and closes", "%d pokes" % pokes)

	print("DBG %d passed, %d failed" % [passed, failed])
	get_tree().quit()


func poke(_p_player = null):
	pokes += 1


# Stands the player p_distance south of the point, rig turned p_off_angle
# away from facing it square.
func stand(p_player: Character, p_area: Node3D, p_distance: float,
		p_off_angle: float):
	p_player.global_position = p_area.global_position \
			- Vector3(0.0, 0.0, 1.0) * p_distance
	p_player.global_position.y = 0.0
	var to_point: Vector3 = p_area.global_position - p_player.global_position
	p_player.body_container.global_rotation = Vector3(0.0,
			atan2(to_point.x, to_point.z) + deg_to_rad(p_off_angle), 0.0)


func settle():
	for i in 6:
		await get_tree().physics_frame
	await get_tree().process_frame


func check(p_ok: bool, p_label: String, p_detail: String):
	if p_ok:
		passed += 1
	else:
		failed += 1
	print("DBG %s %s: %s" % ["PASS" if p_ok else "FAIL", p_label, p_detail])
