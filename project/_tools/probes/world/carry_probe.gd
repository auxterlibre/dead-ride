extends ProbeBase
# DBG probe: the barrel carry - the grid adopts the authored barrel, the point
# offers pickup to an empty hand and the pour to a held can, carrying empties
# the hands and hides the bar while every draw and drink refuses, the left
# barrel fades its chill out slowly, placement is grid-ruled with the fuel
# riding across, and the involuntary drops (bedroll, nowhere to stand) land it.


func _ready():
	var game: Node = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await settle(8)
	var player: Character = InputManager.player
	var grid: BuildGrid = Globals.build_grid
	var barrel: FuelBarrel = find_first(game, "FuelBarrel")
	var carry: PlayerCarry = null
	for child in player.get_children():
		if child is PlayerCarry:
			carry = child
	if not check(grid != null and barrel != null and carry != null,
			"the map carries grid, barrel and the carry component",
			"%s / %s / %s" % [grid, barrel, carry]):
		finish()
		return

	# --- the authored barrel is the GRID'S now
	var home: Vector2i = grid.cell_of(barrel.global_position)
	check(grid.placed_at(home) == barrel, "the grid adopted the authored barrel",
			str(home))
	check(not barrel.is_in_group("persistent"),
			"which left the persistent group - one ledger, not two", "grid-owned")

	# --- the carry pose is a wired upper_state input, the throw's lesson
	var tree: AnimationTree = player.find_child("AnimationTree", true, false)
	var transition: AnimationNodeTransition = tree.tree_root.get_node("upper_state")
	var inputs: Array = []
	for i in transition.input_count:
		inputs.append(transition.get_input_name(i))
	check(PlayerCarry.POSE_CARRY in inputs \
			and tree.tree_root.has_node("anim_" + PlayerCarry.POSE_CARRY),
			"the carry pose is a wired upper_state input", str(inputs.size()))

	# --- the point picks its job by the hand
	barrel.refresh_offers()
	check(barrel.refill_area.enabled and barrel.refill_area.action_label == "Pick up",
			"an empty hand is offered the pickup", barrel.refill_area.action_label)
	var can: FuelCanData = (load("res://data/items/tools/fuel_can.tres") \
			as FuelCanData).duplicate()
	can.current_fuel = 5.0
	barrel.current_fuel = 23.5
	var can_entry: InventoryEntry = player.carried.inventory.add_one(can)
	var slot: int = player.carried.free_item_slot()
	player.carried.assign_quick_slot(can_entry, slot)
	player.carried.select_slot(slot)
	barrel.refresh_offers()
	check(barrel.refill_area.action_label.begins_with("Refill"),
			"a fuelled can in hand turns it into the pour",
			barrel.refill_area.action_label)
	player.carried.holster()

	# --- pickup: bare hands, hidden bar, refused draws
	var bar: Control = find_first(game, "QuickSlotsUI")
	var weapons: CharacterWeapons = player.carried.weapons
	barrel.warmth = 1.0
	var offers_before: int = InteractiveArea.offers.size()
	carry.pickup(barrel)
	check(carry.carrying and is_equal_approx(carry.fuel, 23.5),
			"the pickup takes the barrel and its liters", "%.1fL" % carry.fuel)
	# The ghost is meshes alone: a preview with a live InteractiveArea once
	# advertised "Pick up" on itself from inside the player's own arms.
	check(InteractiveArea.offers.size() == offers_before,
			"the ghost registers no offer of its own",
			"%d offers held" % InteractiveArea.offers.size())
	check(carry.ghost.get_script() == null,
			"a preview carries no behaviour at all", "stripped")
	# --- the area of effect rides the preview
	# Read off the ghost's own CoolArea rather than a constant, so a designer
	# widening the sphere in the scene moves the drawn circle with it.
	check(is_equal_approx(carry.chill_reach, barrel.chill_radius()),
			"the ghost hands the ring the barrel's own cool reach",
			"%.1fm vs %.1fm" % [carry.chill_reach, barrel.chill_radius()])
	check(carry.ring != null and carry.ring.is_inside_tree(),
			"and a ring rides the carry", str(carry.ring))
	carry.ring.draw_circle(Vector3.ZERO, carry.chill_reach, PlayerCarry.RING_COLOR)
	check(carry.ring.visible and carry.ring.mesh.get_surface_count() == 2,
			"drawn as a filled disc under a rim", "%d surfaces"
			% carry.ring.mesh.get_surface_count())
	# A refused cell passes 0 through, which is the ring's own hide.
	carry.ring.draw_circle(Vector3.ZERO, 0.0, PlayerCarry.RING_COLOR)
	check(not carry.ring.visible, "and gone where nothing may stand", "hidden")
	check(weapons.current_weapon == null and player.carried.active_slot == -1,
			"into EMPTY hands - nothing drawn, no slot lit", "bare")
	check(carry.visual.visible, "the drum rides the arms", "shown")
	check(bar != null and not bar.visible, "and the quick bar hides", str(bar))
	player.carried.select_slot(0)
	check(player.carried.active_slot == -1 and weapons.current_weapon == null,
			"a slot press draws nothing while carrying", "refused")

	# --- the carry pose is a run cycle: it HOLDS on still feet
	carry.drive_pose(1.0)
	check(is_zero_approx(float(tree.get(CharacterAnimator.UPPER_SPEED_PARAM))),
			"standing still holds the carry pose",
			"speed %.2f" % float(tree.get(CharacterAnimator.UPPER_SPEED_PARAM)))
	player.velocity = Vector3(4.0, 0.0, 0.0)
	carry.drive_pose(1.0)
	check(is_equal_approx(float(tree.get(CharacterAnimator.UPPER_SPEED_PARAM)), 1.0),
			"and swings once the feet move",
			"speed %.2f" % float(tree.get(CharacterAnimator.UPPER_SPEED_PARAM)))
	player.velocity = Vector3.ZERO

	# --- the left barrel is going, slowly: cold lingers, everything else stops
	check(barrel.fading and barrel.collision_layer == 0 \
			and not barrel.refill_area.enabled,
			"the stood barrel is intangible and offerless", "fading")
	check(grid.placed_at(home) == null, "its cell is free to build on", "freed")
	Calendar.set_time(13, 0)
	check(not barrel.venting(), "no coolant effect on the move", "sealed")
	barrel.fade_step(1.0)
	var lingering: float = barrel.chill_strength()
	check(lingering > 0.2 and lingering < 0.9,
			"while the ground cold fades rather than popping",
			"%.2f strength" % lingering)
	barrel.fade_step(5.0)
	await get_tree().process_frame
	await get_tree().process_frame
	check(not is_instance_valid(barrel), "and the faded barrel frees itself",
			"gone")

	# --- placement: grid-ruled, the fuel rides, the cold arrives slowly
	var spot: Vector2i = free_cell_near(grid, carry, player.global_position)
	if not check(spot != Vector2i(9999, 9999), "a clear cell stands nearby",
			str(spot)):
		finish()
		return
	# Arm's length is a rule of its own: a cell across the map refuses even
	# with the books clear.
	check(not carry.in_reach(grid.cell_of(player.global_position)
			+ Vector2i(6, 6)), "six cells off is past arm's reach", "refused")
	carry.cell = spot
	carry.placeable = true
	carry.place_down()
	var placed: FuelBarrel = grid.placed_at(spot) as FuelBarrel
	check(placed != null and is_equal_approx(placed.current_fuel, 23.5),
			"placing sets the barrel down with its liters",
			"%.1fL" % (placed.current_fuel if placed else -1.0))
	check(not carry.carrying and not carry.visual.visible and bar.visible,
			"the hands and the bar come back", "released")
	check(carry.ring == null, "and the ring goes with the ghost", "freed")
	check(is_equal_approx(float(tree.get(CharacterAnimator.UPPER_SPEED_PARAM)), 1.0),
			"and the upper layer's clock is the weapons' again",
			"speed %.2f" % float(tree.get(CharacterAnimator.UPPER_SPEED_PARAM)))
	check(placed.chill_strength() < 0.3, "the fresh ground is not yet cold",
			"%.2f strength" % placed.chill_strength())
	placed.warm_step(10.0)
	check(placed.chill_strength() > 0.9, "and cools in over seconds",
			"%.2f strength" % placed.chill_strength())

	# --- the involuntary drop hunts standing room off the player's feet
	carry.pickup(placed)
	check(carry.carrying, "picked back up", "carried")
	carry.force_drop()
	check(not carry.carrying, "force_drop set it down", "dropped")
	var found: FuelBarrel = null
	for entry in grid.placements:
		if entry.node is FuelBarrel and is_instance_valid(entry.node) \
				and not entry.node.fading:
			found = entry.node
	check(found != null and found.global_position.distance_to(
			player.global_position) < BuildGrid.CELL * (carry.DROP_SEARCH + 1) * 1.5,
			"within reach of where the player stood",
			str(found.global_position) if found else "nowhere")

	# --- sleeping sets the barrel down before the save looks
	SaveManager.save_path = "user://carry_probe_save.json"
	SaveManager.backup_path = "user://carry_probe_save.bak"
	carry.pickup(found)
	var bedroll: Node = game.find_child("Bedroll", true, false)
	if check(bedroll is Bedroll, "the map carries the bedroll", str(bedroll)):
		bedroll.sleep(player)
		check(not carry.carrying,
				"sleeping drops the barrel where the save can see it", "grounded")

	finish()


# The spiral force_drop runs, reused to find this probe's own test cell -
# within arm's reach, since place_down now re-checks it.
func free_cell_near(p_grid: BuildGrid, p_carry: PlayerCarry,
		p_around: Vector3) -> Vector2i:
	var centre: Vector2i = p_grid.cell_of(p_around)
	for radius in range(1, 5):
		for x in range(-radius, radius + 1):
			for y in range(-radius, radius + 1):
				if maxi(absi(x), absi(y)) != radius:
					continue
				var at: Vector2i = centre + Vector2i(x, y)
				if p_grid.can_place(p_carry.barrel_data, at, 0) \
						and p_carry.in_reach(at):
					return at
	return Vector2i(9999, 9999)
