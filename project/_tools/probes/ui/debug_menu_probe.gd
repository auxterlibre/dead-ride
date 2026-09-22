extends ProbeBase
# A silent null in the lookups would make every F9 button a no-op, so check they resolve.

func _ready():
	var game: Node = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	var menu: DebugMenu = find_first(game, "DebugMenu")

	check(menu.find_first("GasPump") != null, "the menu finds the pump",
			str(menu.find_first("GasPump")))
	check(menu.find_first("StorageLocker") != null, "and the locker",
			str(menu.find_first("StorageLocker")))
	check(menu.find_first("DeliveryService") != null, "and the delivery service",
			str(menu.find_first("DeliveryService")))
	check(menu.find_first("TrafficSpawner") != null, "and the traffic spawner",
			str(menu.find_first("TrafficSpawner")))
	check(menu.find_first("NoSuchThing") == null,
			"a missing class is null, not an error", "")

	# Each button has to actually shift money, not just find a node.
	var pump: GasPump = menu.find_first("GasPump") as GasPump
	pump.data.current_stock = 0.0
	PlayerData.current_money = 1000
	menu.deliver_fuel(200.0)
	check(is_equal_approx(pump.data.current_stock, 200.0)
			and PlayerData.current_money == 1000 - 200 * pump.data.wholesale_price,
			"the delivery button buys stock",
			"%.0fL, $%d" % [pump.data.current_stock, PlayerData.current_money])

	var before: int = PlayerData.current_money
	pump.sell_gas(50.0)
	check(PlayerData.current_money == before + 50 * pump.data.pump_price,
			"and a sale pays in", "$%d" % PlayerData.current_money)

	# --- the state labels are their OWN knob now, not a rider on debug draw
	var brain: Node = find_first(game, "EnemyAI")
	if not check(brain != null and brain.character.debug_label != null,
			"the map carries an enemy with a state label to judge", str(brain)):
		finish()
		return
	var enemy: Character = brain.character
	menu.apply_row(DebugMenu.Row.DEBUG_DRAW, true)
	menu.apply_row(DebugMenu.Row.STATE_LABELS, false)
	await settle(2)
	check(Globals.debug_mode and not Globals.debug_labels
			and not enemy.debug_label.visible,
			"the cones can be drawn with no caption over every head",
			"draw=%s labels=%s" % [Globals.debug_mode, Globals.debug_labels])
	menu.apply_row(DebugMenu.Row.STATE_LABELS, true)
	await settle(2)
	check(enemy.debug_label.visible, "and the row alone brings them back",
			"visible")
	# The one-key sweep still moves BOTH, which is what it has always meant.
	Globals.debug_mode = false
	Globals.debug_labels = false
	Input.action_press("debug_text_toggle")
	await settle(2)
	Input.action_release("debug_text_toggle")
	# Both TRUE, not merely equal: from a false/false start, "in step" is what
	# a key that did nothing at all would also report.
	check(Globals.debug_mode and Globals.debug_labels,
			"key 9 still sweeps both flags up together", "draw=%s labels=%s"
			% [Globals.debug_mode, Globals.debug_labels])

	# --- the HUD's perf readout is a row too, and OFF means not drawn
	var stats: DebugLabel = find_first(game, "DebugLabel")
	if not check(stats != null, "the HUD carries the perf readout", str(stats)):
		finish()
		return
	check(Globals.debug_stats and stats.visible,
			"which is on by default, as it always was", "shown")
	menu.apply_row(DebugMenu.Row.PERF_STATS, false)
	await settle(2)
	check(not stats.visible and stats.text.is_empty(),
			"switched off it stops drawing AND stops formatting",
			"visible=%s text=%d chars" % [stats.visible, stats.text.length()])
	menu.apply_row(DebugMenu.Row.PERF_STATS, true)
	await settle(2)
	check(stats.visible and not stats.text.is_empty(),
			"and comes back counting", "%d chars" % stats.text.length())
	finish()
