extends ProbeBase
# DBG probe: moving goods between two open containers - F and double click
# ferry the hovered stack across, stacks top up their kind before opening new
# cells, overflow past a full grid stays where it was, and a quick slot only
# lets go once the whole stack has actually left.

@onready var GAME: PackedScene = load("uid://b56i3a2diovj6")  # scenes/game.tscn

var screen: BackpackScreen
var box: Inventory = Inventory.new()


func _ready():
	var game: Node = GAME.instantiate()
	add_child(game)
	for i in 8:
		await get_tree().process_frame
	screen = game.find_children("*", "BackpackScreen", true, false).front()
	box.setup(load("res://data/storage/crate_layout.tres"))
	screen.open()
	Signals.container_opened.emit("Test Crate", box)
	await get_tree().process_frame
	check(screen.container_panel.visible, "two containers stand open", "open")
	var pack: Inventory = screen.source.inventory

	# --- F on a pack item carries it across whole
	var tool_entry: InventoryEntry = entry_named(pack, "Screwdriver")
	screen.grid.select(tool_entry)
	screen.transfer(screen.grid)
	check(entry_named(box, "Screwdriver") != null and entry_named(pack, "Screwdriver") == null,
			"the screwdriver crosses to the crate whole", "crossed")

	# --- stacks top up their kind first, overflow opens a new cell
	var ammo: InventoryEntry = first_ammo(pack)  # hardcoding a calibre died with the pistol loadout
	var kind: String = ammo.item.name
	var cap: int = ammo.item.get_max_stack()
	ammo.count = 30
	box.add(ammo.item, cap - 10)  # a nearly full stack waiting over there
	screen.grid.select(ammo)
	screen.transfer(screen.grid)
	var box_total: int = count_named(box, kind)
	check(box_total == cap + 20 and entry_named(pack, kind) == null,
			"a stack tops its kind up then opens a new cell",
			"%d over there, cap %d" % [box_total, cap])

	# --- double click ferries the other way
	var back: InventoryEntry = entry_named(box, "Screwdriver")
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.double_click = true
	press.position = (Vector2(back.origin) + Vector2(0.5, 0.5)) * InventoryGridUI.CELL
	screen.container_panel.grid._gui_input(press)
	check(entry_named(pack, "Screwdriver") != null and entry_named(box, "Screwdriver") == null,
			"a double click ferries it back", "returned")

	# --- a full crate refuses: everything stays put
	while box.find_free_spot(load("res://data/items/trinkets/rusty_gear.tres")).x >= 0:
		box.add(load("res://data/items/trinkets/rusty_gear.tres"), 1)
	var bandage: InventoryEntry = entry_named(pack, "Field Bandage")
	var had: int = bandage.count
	screen.grid.select(bandage)
	screen.transfer(screen.grid)
	check(entry_named(pack, "Field Bandage") != null \
			and count_named(pack, "Field Bandage") == had,
			"a full crate moves nothing", "%d still in the pack" % had)

	# --- drag-drop onto a matching stack merges, cap-aware, remainder stays
	var grid_ui: InventoryGridUI = screen.container_panel.grid
	var target: InventoryEntry = entry_named(box, kind)
	target.count = cap - 5
	prune_extra_stacks(box, kind, target)
	# Pruning freed cells; plug them so the only room left is the stack's headroom.
	while box.find_free_spot(load("res://data/items/trinkets/rusty_gear.tres")).x >= 0:
		box.add(load("res://data/items/trinkets/rusty_gear.tres"), 1)
	var carried_ammo: InventoryEntry = pack.add_one(target.item.duplicate())
	carried_ammo.count = 12
	var payload: Dictionary = InventoryDrag.begin(carried_ammo, Vector2i.ZERO)
	payload.source = pack
	var over: Vector2 = (Vector2(target.origin) + Vector2(0.5, 0.5)) * InventoryGridUI.CELL
	check(grid_ui._can_drop_data(over, payload), "a stack drop onto its kind reads valid", "valid")
	grid_ui._drop_data(over, payload)
	check(target.count == cap and carried_ammo.count == 7 \
			and pack.entries.has(carried_ammo),
			"the drop pours in what fits and keeps the rest",
			"%d/%d over there, %d kept" % [target.count, cap, carried_ammo.count])

	# --- slots are real storage: assigning moves the stack out of the grid
	var slotted: InventoryEntry = pack.add_one(load("res://data/items/consumables/field_bandage.tres"))
	slotted.count = 3
	screen.source.assign_quick_slot(slotted, 3)
	check(screen.source.quick_slots[3] == slotted and not pack.entries.has(slotted) \
			and slotted.origin == InventoryEntry.NO_CELL,
			"assigning a slot moves the stack out of the grid",
			"origin %s" % slotted.origin)

	# --- a slot drag pours into its kind and KEEPS the slot while any remain
	box.remove(entry_named(box, "Rusty Gear"))  # one cell of room
	box.add(slotted.item, slotted.item.get_max_stack() - 2)  # headroom of 2
	var pour_target: InventoryEntry = entry_named(box, "Field Bandage")
	var payload_slot: Dictionary = InventoryDrag.begin(slotted, Vector2i.ZERO)
	payload_slot.slot = 3
	payload_slot.owner = screen.source
	var over_stack: Vector2 = (Vector2(pour_target.origin) + Vector2(0.5, 0.5)) \
			* InventoryGridUI.CELL
	check(grid_ui._can_drop_data(over_stack, payload_slot),
			"a slot stack reads valid over its kind", "valid")
	grid_ui._drop_data(over_stack, payload_slot)
	check(screen.source.quick_slots[3] == slotted and slotted.count == 1 \
			and pour_target.count == pour_target.item.get_max_stack(),
			"a partial pour keeps the remainder on the slot",
			"%d left on the slot" % slotted.count)

	# --- and the slot only lets go once the whole stack has actually left
	var gear: InventoryEntry = entry_named(box, "Rusty Gear")
	var hole: Vector2i = gear.origin
	box.remove(gear)
	var payload_rest: Dictionary = InventoryDrag.begin(slotted, Vector2i.ZERO)
	payload_rest.slot = 3
	payload_rest.owner = screen.source
	var over_hole: Vector2 = (Vector2(hole) + Vector2(0.5, 0.5)) * InventoryGridUI.CELL
	grid_ui._drop_data(over_hole, payload_rest)
	check(screen.source.quick_slots[3] == null and count_named(box, "Field Bandage") \
			== slotted.item.get_max_stack() + 1,
			"a fully departed stack releases its quick slot",
			str(screen.source.quick_slots[3]))

	# --- stowing brings a slotted stack home to the grid. Counted, not chased
	# by identity: pouring back into stacks may retire the entry object.
	var stowed: InventoryEntry = pack.add_one(load("res://data/items/consumables/field_bandage.tres"))
	screen.source.assign_quick_slot(stowed, 2)
	var before_stow: int = count_named(pack, "Field Bandage")
	screen.source.stow_slot(2)
	check(screen.source.quick_slots[2] == null \
			and count_named(pack, "Field Bandage") == before_stow + 1,
			"stowing returns the stack to the grid",
			"%d -> %d in the pack" % [before_stow, count_named(pack, "Field Bandage")])

	finish()


# Biggest cap carried - the stack math needs headroom.
func first_ammo(p_inventory: Inventory) -> InventoryEntry:
	var best: InventoryEntry = null
	for entry in p_inventory.entries:
		if entry.item is AmmoData and (best == null
				or entry.item.get_max_stack() > best.item.get_max_stack()):
			best = entry
	return best


func entry_named(p_inventory: Inventory, p_name: String) -> InventoryEntry:
	for entry in p_inventory.entries:
		if entry.item.name == p_name:
			return entry
	return null


func count_named(p_inventory: Inventory, p_name: String) -> int:
	var total: int = 0
	for entry in p_inventory.entries:
		if entry.item.name == p_name:
			total += entry.count
	return total


# Leaves only the one stack of a kind, so a merge test knows its target.
func prune_extra_stacks(p_inventory: Inventory, p_name: String, p_keep: InventoryEntry):
	for entry in p_inventory.entries.duplicate():
		if entry.item.name == p_name and entry != p_keep:
			p_inventory.remove(entry)
