extends ProbeBase
# DBG probe: the pack panel's quick slots are REAL storage - an item on the
# bar is not in the grid - and the mask renders as a SHAPE: locked cells never
# built, the silhouette's convex corners rounded, seams single-drawn.

@onready var GAME: PackedScene = load("uid://b56i3a2diovj6")  # scenes/game.tscn


func _ready():
	var game: Node = GAME.instantiate()
	add_child(game)
	await settle(8)
	var screen: BackpackScreen = game.find_children("*", "BackpackScreen", true, false).front()
	screen.open()
	await settle(2)
	var panel: BackpackPanelUI = screen.backpack_panel
	var carried: CharacterInventory = screen.source

	# --- the mockup's slot sections stand in the panel
	check(panel.slots.size() == 6, "the panel carries six slot widgets",
			"%d widgets" % panel.slots.size())
	check(panel.slots[0].box.custom_minimum_size.x == 256.0 \
			and panel.slots[2].box.custom_minimum_size.x == 128.0,
			"weapon slots span two cells, item slots one",
			"%.0f / %.0f" % [panel.slots[0].box.custom_minimum_size.x,
			panel.slots[2].box.custom_minimum_size.x])

	# --- locked cells are simply not built
	var grid_ui: InventoryGridUI = screen.grid
	var mask: StorageData = carried.inventory.storage
	check(grid_ui.cell_map.size() == mask.open_cell_count(),
			"only the mask's open cells are built",
			"%d of %d" % [grid_ui.cell_map.size(), mask.open_cell_count()])
	check(mask.open_cell_count() == 20 and mask.size == Vector2i(6, 4),
			"the hiker mask is the mockup's 6x4 with cut corners",
			"%s, %d open" % [mask.size, mask.open_cell_count()])

	# --- the silhouette's convex corners round; inner steps stay square
	var corner: StyleBoxFlat = grid_ui.cell_map[Vector2i(1, 0)].get_theme_stylebox("panel")
	check(corner.corner_radius_top_left == InventoryCell.CORNER_RADIUS \
			and corner.corner_radius_top_right == 0 \
			and corner.corner_radius_bottom_left == 0,
			"a corner cell rounds outward only", "TL %d" % corner.corner_radius_top_left)
	var rounded: int = 0
	for cell in grid_ui.cell_map.values():
		var style: StyleBoxFlat = cell.get_theme_stylebox("panel")
		for radius in [style.corner_radius_top_left, style.corner_radius_top_right,
				style.corner_radius_bottom_right, style.corner_radius_bottom_left]:
			if radius > 0:
				rounded += 1
	check(rounded == 8, "exactly the eight convex corners round",
			"%d rounded" % rounded)

	# --- seams are single-drawn: interiors own left/top, the rim closes edges
	var interior: StyleBoxFlat = grid_ui.cell_map[Vector2i(2, 1)].get_theme_stylebox("panel")
	check(interior.border_width_left == 2 and interior.border_width_top == 2 \
			and interior.border_width_right == 0 and interior.border_width_bottom == 0,
			"an interior cell draws only its left and top seam",
			"L%d T%d R%d B%d" % [interior.border_width_left, interior.border_width_top,
			interior.border_width_right, interior.border_width_bottom])
	var rim: StyleBoxFlat = grid_ui.cell_map[Vector2i(5, 1)].get_theme_stylebox("panel")
	check(rim.border_width_right == 2, "the outer rim closes its own edge",
			"R%d" % rim.border_width_right)

	# --- equipping from the pack MOVES the weapon; the displaced one falls back
	var looted: InventoryEntry = carried.inventory.add_one(
			(load("res://data/items/weapons/ranged/shotgun.tres") as WeaponData).duplicate())
	var displaced: InventoryEntry = carried.quick_slots[0]
	carried.equip(looted)
	check(carried.quick_slots[0] == looted \
			and not carried.inventory.entries.has(looted) \
			and looted.origin == InventoryEntry.NO_CELL,
			"equipping moves the weapon out of the grid onto the slot",
			"slot 1 holds %s" % looted.item.name)
	check(displaced != null and carried.inventory.entry_of(displaced.item) != null,
			"the displaced weapon fell back into the grid",
			displaced.item.name if displaced else "<none>")

	# --- a weapon refuses an item slot; the weapon slots swap between themselves
	var third: InventoryEntry = carried.quick_slots[3]
	carried.assign_quick_slot(carried.quick_slots[0], 3)
	check(carried.quick_slots[3] == third and carried.quick_slots[0] == looted,
			"a weapon refuses an item slot", "slot 4 unchanged")
	var zero: InventoryEntry = carried.quick_slots[0]
	var one: InventoryEntry = carried.quick_slots[1]
	carried.assign_quick_slot(zero, 1)
	check(carried.quick_slots[1] == zero and carried.quick_slots[0] == one,
			"the weapon slots swap", "%s <-> %s" % [zero.item.name,
			one.item.name if one else "<empty>"])

	# --- ammo parked on the bar still counts as reserve
	var ammo: InventoryEntry = null
	for entry in carried.inventory.entries:
		if entry.item is AmmoData:
			ammo = entry
	if ammo:
		var reserve: int = carried.ammo_count(ammo.item.ammo_type)
		carried.assign_quick_slot(ammo, 3)
		check(carried.quick_slots[3] == ammo \
				and carried.ammo_count(ammo.item.ammo_type) == reserve,
				"ammo parked on the bar still counts as reserve",
				"%d rounds either way" % reserve)

	# --- the HUD bar yields to the panel and returns with gameplay
	var bar: QuickSlotsUI = game.find_children("*", "QuickSlotsUI", true, false).front()
	check(not bar.visible, "the HUD bar stands down while the pack is open",
			"hidden")
	screen.close()
	await settle(2)
	check(bar.visible, "and returns with gameplay", "shown")

	check(InputMap.has_action("weapon_slot_5"), "key 6 drives the sixth slot",
			"action exists")

	finish()
