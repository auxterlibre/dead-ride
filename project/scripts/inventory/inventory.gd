class_name Inventory
extends RefCounted
# Rectangular grid placement over a StorageData mask. Pure logic, no nodes -
# characters and vehicles both own one, and it is probe-testable headless.

signal changed

var storage: StorageData
var entries: Array[InventoryEntry] = []

var occupancy: Dictionary = {}  # Vector2i -> InventoryEntry


func setup(p_storage: StorageData):
	storage = p_storage
	entries.clear()
	occupancy.clear()
	changed.emit()


# Every covered cell must exist, be unlocked, and be free - or already belong
# to p_ignore, which is what lets an entry move onto its own footprint.
func can_place(p_item: ItemData, p_origin: Vector2i,
		p_ignore: InventoryEntry = null) -> bool:
	if storage == null or p_item == null:
		return false
	for y in p_item.size.y:
		for x in p_item.size.x:
			var cell: Vector2i = p_origin + Vector2i(x, y)
			if not storage.is_open(cell):
				return false
			var holder: InventoryEntry = occupancy.get(cell)
			if holder != null and holder != p_ignore:
				return false
	return true


func place(p_item: ItemData, p_origin: Vector2i,
		p_count: int = 1) -> InventoryEntry:
	if not can_place(p_item, p_origin):
		return null
	var entry: InventoryEntry = InventoryEntry.new(p_item, p_origin, p_count)
	entries.append(entry)
	for cell in entry.cells():
		occupancy[cell] = entry
	changed.emit()
	return entry


# Tops up matching stacks first, then opens new ones. Returns what wouldn't
# fit - 0 means the whole lot went in.
func add(p_item: ItemData, p_count: int = 1) -> int:
	var left: int = p_count
	if p_item.get_max_stack() > 1:
		for entry in entries:
			if left <= 0:
				break
			if not entry.item.stacks_with(p_item):
				continue
			var moved: int = mini(entry.free_space(), left)
			entry.count += moved
			left -= moved
		if left > 0:
			changed.emit()  # existing stacks grew even if the rest won't fit
	while left > 0:
		var spot: Vector2i = find_free_spot(p_item)
		if spot.x < 0:
			return left
		# Stacks of one kind share the ItemData; per-stack state is the count,
		# which lives on the entry.
		var taken: int = mini(p_item.get_max_stack(), left)
		place(p_item, spot, taken)
		left -= taken
	changed.emit()
	return 0


# Single-item convenience: places one and hands back the entry (null = no room).
func add_one(p_item: ItemData) -> InventoryEntry:
	var spot: Vector2i = find_free_spot(p_item)
	if spot.x < 0:
		return null
	return place(p_item, spot)


func move(p_entry: InventoryEntry, p_origin: Vector2i) -> bool:
	if not can_place(p_entry.item, p_origin, p_entry):
		return false
	for cell in p_entry.cells():
		occupancy.erase(cell)
	p_entry.origin = p_origin
	for cell in p_entry.cells():
		occupancy[cell] = p_entry
	changed.emit()
	return true


func remove(p_entry: InventoryEntry):
	if not entries.has(p_entry):
		return
	for cell in p_entry.cells():
		occupancy.erase(cell)
	entries.erase(p_entry)
	changed.emit()


# Row-major scan, so items settle top-left. (-1, -1) = no room.
func find_free_spot(p_item: ItemData) -> Vector2i:
	if storage == null or p_item == null:
		return Vector2i(-1, -1)
	var size: Vector2i = storage.size
	for y in size.y:
		for x in size.x:
			if can_place(p_item, Vector2i(x, y)):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func entry_at(p_cell: Vector2i) -> InventoryEntry:
	return occupancy.get(p_cell)


# The entry holding this exact item, or null. add() reports leftovers rather
# than where they went, so this is how a caller finds the stack it just made.
func entry_of(p_item: ItemData) -> InventoryEntry:
	for entry in entries:
		if entry.item == p_item:
			return entry
	return null


func count_of(p_item: ItemData) -> int:
	var total: int = 0
	for entry in entries:
		if entry.item.same_kind(p_item):
			total += entry.count
	return total


# Returns what was actually taken - short stock takes what there is.
func take(p_item: ItemData, p_count: int) -> int:
	var left: int = p_count
	for entry in entries.duplicate():
		if left <= 0:
			break
		if not entry.item.same_kind(p_item):
			continue
		var taken: int = mini(entry.count, left)
		entry.count -= taken
		left -= taken
		if entry.count <= 0:
			remove(entry)
	if left < p_count:
		changed.emit()
	return p_count - left


func total_weight() -> float:
	var total: float = 0.0
	for entry in entries:
		total += entry.item.weight
	return total


# One stack as a save row: item identity by path (SaveManager resolves runtime
# copies by name), count, and a weapon's live magazine or a can's fill. Static
# so the quick slots - storage without a grid - save through the same shape.
static func save_row(p_entry: InventoryEntry) -> Dictionary:
	var row: Dictionary = {"path": SaveManager.item_path(p_entry.item),
			"count": p_entry.count}
	var weapon: WeaponData = p_entry.item as WeaponData
	if weapon:
		row["ammo"] = weapon.current_ammo
	var can: FuelCanData = p_entry.item as FuelCanData
	if can:
		row["fuel"] = can.current_fuel
	return row


# A row back into a loose entry (origin NO_CELL until someone places it).
# Stateful items come back as fresh duplicates carrying their saved state.
static func load_row(p_row: Dictionary) -> InventoryEntry:
	var item: ItemData = load(str(p_row.path)) as ItemData
	if item == null:
		return null
	if item.has_own_state():
		item = item.duplicate()
	if item is WeaponData:
		item.current_ammo = int(p_row.get("ammo", -1))
	elif item is FuelCanData:
		item.current_fuel = float(p_row.get("fuel", 0.0))
	return InventoryEntry.new(item, InventoryEntry.NO_CELL, int(p_row.get("count", 1)))


# The grid as save rows: each stack's row plus its exact origin.
func save_entries() -> Array:
	var rows: Array = []
	for entry in entries:
		var row: Dictionary = save_row(entry)
		row["origin"] = [entry.origin.x, entry.origin.y]
		rows.append(row)
	return rows


# Wipes the grid and lays the rows back at their exact cells.
func load_entries(p_rows: Array):
	setup(storage)
	for row in p_rows:
		var entry: InventoryEntry = load_row(row)
		if entry == null:
			continue
		place(entry.item, Vector2i(int(row.origin[0]), int(row.origin[1])), entry.count)
	changed.emit()
