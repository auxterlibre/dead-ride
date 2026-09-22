extends ProbeBase
# Does the starting loadout reach the quick bar the way the data describes it?

var slotted_held: int = 0


func _ready():
	var game: Node = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	for i in 8:
		await get_tree().process_frame
	var carried: CharacterInventory = InputManager.player.carried
	var data: CharacterData = InputManager.player.data

	var bar: Array = []
	for i in carried.quick_slots.size():
		var entry: InventoryEntry = carried.quick_slots[i]
		bar.append("%d:%s" % [i + 1, "%s x%d" % [entry.item.name, entry.count]
				if entry else "-"])
	print("DBG bar  %s" % " | ".join(bar))

	for i in mini(data.weapon_inventory.size(), CharacterInventory.WEAPON_SLOTS):
		var slot: InventoryEntry = carried.quick_slots[i]
		check(slot != null and slot.item.name == data.weapon_inventory[i].name,
				"weapon %d opens on key %d" % [i, i + 1],
				slot.item.name if slot else "<empty>")

	# Held items take a utility slot; carried ones stay in the pack.
	for item in data.starting_items:
		var slot: int = -1
		for i in carried.quick_slots.size():
			var entry: InventoryEntry = carried.quick_slots[i]
			if entry and entry.item.name == item.name:
				slot = i
		var held: bool = item.get_held_scene() != null
		if held:
			slotted_held += 1
		check((slot >= CharacterInventory.WEAPON_SLOTS) == held,
				"%s %s a utility slot" % [item.name, "takes" if held else "does not take"],
				"slot %d" % (slot + 1) if slot >= 0 else "in the pack only")

	# The per-item check above is SYMMETRIC - it agrees just as well when
	# nothing is held at all, which is exactly how a dropped held_scene once
	# slipped past it. Something must actually be on the bar.
	check(slotted_held > 0, "the loadout puts at least one held item on the bar",
			"%d held" % slotted_held)

	# The mockup's bar: two weapon slots and four item slots.
	check(carried.quick_slots.size() == 6, "the pack opens six quick slots",
			"%d slots" % carried.quick_slots.size())

	# Slots are STORAGE, not references - nothing slotted may also sit in the
	# grid, which is exactly what the old proxy model did.
	for i in carried.quick_slots.size():
		var entry: InventoryEntry = carried.quick_slots[i]
		if entry:
			check(not carried.inventory.entries.has(entry)
					and entry.origin == InventoryEntry.NO_CELL,
					"slot %d's %s lives on the slot alone" % [i + 1, entry.item.name],
					"origin %s" % entry.origin)

	# And a full stack, not one loose grenade - counted on its slot.
	var grenade: InventoryEntry = null
	for i in range(CharacterInventory.WEAPON_SLOTS, carried.quick_slots.size()):
		var entry: InventoryEntry = carried.quick_slots[i]
		if entry and entry.item is ExplosiveData:
			grenade = entry
	check(grenade != null and grenade.count == grenade.item.get_max_stack(),
			"the grenade starts as a full stack on its slot",
			"%d of %d" % [grenade.count if grenade else 0,
			grenade.item.get_max_stack() if grenade else 0])

	finish()
