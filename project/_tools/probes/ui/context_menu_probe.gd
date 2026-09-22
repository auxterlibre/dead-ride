extends ProbeBase
# DBG probe: the grid's right-click menu - rows are computed per stack (a
# consumable offers Consume, a weapon Equip, everything droppable Drop, and
# Transfer only beside an open container), and picking Consume closes the
# screen and starts the clip-gated drink.


func _ready():
	var game: Node = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await settle(8)
	var player: Node = InputManager.player
	var screen: BackpackScreen = find_first(game, "BackpackScreen")
	check(screen != null, "the screen exists", str(screen))
	var consume: PlayerConsume = null
	for child in player.get_children():
		if child is PlayerConsume:
			consume = child

	# A thirsty player, a bottle and a gun in the pack.
	consume.energy.set_energy(20.0)
	var bottle: ConsumableData = load("res://data/items/consumables/water_bottle.tres")
	var pistol: WeaponData = load("res://data/items/weapons/ranged/pistol.tres")
	var bottle_entry: InventoryEntry = player.carried.inventory.add_one(bottle)
	var pistol_entry: InventoryEntry = player.carried.inventory.add_one(pistol)
	screen.open()
	check(screen.visible and get_tree().paused, "the pack opens paused", "open")

	# --- a consumable offers Consume and Drop; no container, no Transfer
	screen.open_context(bottle_entry, Vector2(600, 600), screen.grid)
	var labels: Array = screen.context_menu.actions.map(
			func(action): return action.label)
	check(screen.context_menu.visible, "right-click raises the menu", "open")
	check("Consume" in labels and "Drop" in labels and not "Transfer" in labels,
			"a bottle offers Consume and Drop, and Transfer only with a container",
			str(labels))

	# --- a weapon offers Equip, never Consume
	screen.open_context(pistol_entry, Vector2(600, 600), screen.grid)
	labels = screen.context_menu.actions.map(func(action): return action.label)
	check("Equip" in labels and not "Consume" in labels,
			"a pistol offers Equip, never Consume", str(labels))

	# --- picking Consume closes the whole screen and starts the drink
	screen.open_context(bottle_entry, Vector2(600, 600), screen.grid)
	labels = screen.context_menu.actions.map(func(action): return action.label)
	screen.context_menu.pick(labels.find("Consume"))
	check(not screen.visible and not get_tree().paused,
			"Consume closes the pack and unpauses", "closed")
	check(consume.drinking(), "and the drink is running", "in progress")
	var count_before: int = bottle_entry.count
	consume.advance_use(consume.animator.get_clip_length(PlayerConsume.POSE_USE) + 0.1)
	check(bottle_entry.count == count_before - 1 or \
			not player.carried.inventory.entries.has(bottle_entry),
			"the finished drink dents the grid stack", "dented")

	# --- the menu dies with the screen
	screen.open()
	screen.open_context(pistol_entry, Vector2(600, 600), screen.grid)
	screen.close()
	check(not screen.context_menu.visible, "closing the pack closes the menu",
			"closed")

	finish()
