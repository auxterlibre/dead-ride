extends ProbeBase
# DBG probe: the fuel can - fill/drain math, the pump scan picking the first
# can with room, loot handing out OWN instances (never the canonical .tres,
# never one instance across two entries), and the fill surviving save rows.


func _ready():
	var canonical: FuelCanData = load("res://data/items/tools/fuel_can.tres")

	# --- fill and drain clamp, and report what actually moved
	var can: FuelCanData = canonical.duplicate()
	var took: float = can.add_fuel(4.0)
	check(took == 4.0 and can.current_fuel == 4.0,
			"a pour goes in whole while there is room", "%.1fL in" % can.current_fuel)
	took = can.add_fuel(100.0)
	check(took == 6.0 and can.current_fuel == can.capacity and can.space() == 0.0,
			"overfilling stops at the brim and reports the accepted part",
			"+%.1fL to %.1fL" % [took, can.current_fuel])
	var got: float = can.drain(3.5)
	check(got == 3.5 and can.current_fuel == 6.5,
			"a watering draws exactly what it asked", "%.1fL left" % can.current_fuel)
	got = can.drain(100.0)
	check(got == 6.5 and can.current_fuel == 0.0 and can.drain(1.0) == 0.0,
			"overdrawing empties the can and a dry can grants nothing",
			"drained to %.1fL" % can.current_fuel)

	# --- the pump scan takes the first can with room, skipping full ones
	var grid: Inventory = Inventory.new()
	grid.setup(load("res://data/storage/box_medium_layout.tres"))
	var full: FuelCanData = canonical.duplicate()
	full.add_fuel(full.capacity)
	var part: FuelCanData = canonical.duplicate()
	part.add_fuel(2.0)
	grid.add_one(full)
	grid.add_one(part)
	var pump: GasPump = load("res://scenes/props/gas_pump.tscn").instantiate()
	add_child(pump)
	check(pump.first_can_with_room(grid) == part,
			"the nozzle skips a full can for the one with room", "picked the 2L can")
	check(pump.first_can_with_room(Inventory.new()) == null,
			"no can in the pack means no fill target", "null")

	# --- loot hands out own instances: never the canonical, never shared
	var entry: LootEntryData = LootEntryData.new()
	entry.item = canonical
	entry.weight = 1.0
	entry.count = Vector2i(2, 2)
	var table: LootTableData = LootTableData.new()
	table.entries.append(entry)
	table.draws = Vector2i(1, 1)
	var box: LootContainer = LootContainer.new()
	box.layout = load("res://data/storage/box_small_layout.tres")
	box.loot = table
	add_child(box)
	box.open()
	var items: Array = []
	for e in box.storage.entries:
		items.append(e.item)
	check(items.size() == 2 and items[0] != items[1] and not canonical in items,
			"a double roll is two separate cans, neither the canonical",
			"%d entries, all distinct" % items.size())
	items[0].add_fuel(9.0)
	check(canonical.current_fuel == 0.0 and items[1].current_fuel == 0.0,
			"filling a looted can leaks into no other", "the others still 0L")

	# --- the fill level survives the save rows
	var save_can: FuelCanData = canonical.duplicate()
	save_can.add_fuel(6.5)
	var stash: Inventory = Inventory.new()
	stash.setup(load("res://data/storage/box_small_layout.tres"))
	stash.place(save_can, Vector2i(0, 0))
	stash.load_entries(stash.save_entries())
	var back: FuelCanData = stash.entries[0].item
	check(back != save_can and back.current_fuel == 6.5 and canonical.current_fuel == 0.0,
			"a saved can comes back a fresh copy at the same fill",
			"%.1fL after the round trip" % back.current_fuel)

	finish()
