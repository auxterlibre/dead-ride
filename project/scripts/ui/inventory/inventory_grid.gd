class_name InventoryGridUI
extends Control
# Draws a StorageData mask and owns hit-testing for the whole grid, since items span cells.

signal selection_changed(entry)
signal entry_activated(entry)  # double click - the screen decides what that means
signal context_requested(entry, at)  # right click - ditto; `at` is a screen position

const CELL: int = 128

@export var cell_scene: PackedScene
@export var item_scene: PackedScene

@onready var cell_root: Control = $Cells
@onready var item_root: Control = $Items

var inventory: Inventory
var cursor: Vector2i = Vector2i.ZERO
var selected: InventoryEntry
var highlighted: Array[InventoryCell] = []
var cell_map: Dictionary = {}  # Vector2i -> InventoryCell; locked cells are never built

# Only one grid washes at a time; _can_drop_data fires on MOUSE MOTION, not every frame.
static var active_grid: InventoryGridUI = null


func _notification(p_what: int):
	if not is_node_ready() or inventory == null:
		return
	if p_what == NOTIFICATION_DRAG_END:
		# The dragged widget was hidden at pickup; rebuild whatever the outcome.
		clear_highlight()
		refresh_items()
	elif p_what == NOTIFICATION_MOUSE_EXIT:
		clear_highlight()
		# Leaving the grid drops the selection, and with it the tooltip. Every
		# grid until now hid its card BY ACCIDENT: sliding off an item lands on
		# a blank cell of the same grid, `entry_at` answers null and the
		# selection clears on the way past. A grid the item FILLS - the
		# planting slot is one cell - has no blank cell to land on, so the
		# pointer leaves without _gui_input ever firing again and the card
		# stays up over nothing.
		select(null)


func setup(p_inventory: Inventory):
	if inventory and inventory.changed.is_connected(refresh_items):
		inventory.changed.disconnect(refresh_items)
	inventory = p_inventory
	inventory.changed.connect(refresh_items)
	build_cells()
	refresh_items()


# Locked cells are not drawn at all - the mask reads through the SHAPE of the
# open ones, with the silhouette's convex corners rounded (both edge
# neighbours across the corner missing) and inner steps left square.
func build_cells():
	for child in cell_root.get_children():
		child.queue_free()
	cell_map.clear()
	var mask: StorageData = inventory.storage
	var grid: Vector2i = mask.size
	custom_minimum_size = Vector2(grid) * CELL
	size = custom_minimum_size
	for y in grid.y:
		for x in grid.x:
			var at: Vector2i = Vector2i(x, y)
			if not mask.is_open(at):
				continue
			var cell: InventoryCell = cell_scene.instantiate()
			cell_root.add_child(cell)
			cell.position = Vector2(at) * CELL
			cell_map[at] = cell
			var up: bool = not mask.is_open(at + Vector2i.UP)
			var down: bool = not mask.is_open(at + Vector2i.DOWN)
			var left: bool = not mask.is_open(at + Vector2i.LEFT)
			var right: bool = not mask.is_open(at + Vector2i.RIGHT)
			cell.shape(right, down,
					[up and left, up and right, down and right, down and left])


func refresh_items():
	for child in item_root.get_children():
		child.queue_free()
	for entry in inventory.entries:
		var widget: InventoryItemUI = item_scene.instantiate()
		item_root.add_child(widget)
		widget.setup(entry, CELL)
		widget.set_selected(entry == selected)
	if selected and not inventory.entries.has(selected):
		select(null)


func _gui_input(p_event: InputEvent):
	if p_event is InputEventMouseMotion or (p_event is InputEventMouseButton
			and p_event.pressed):
		var cell: Vector2i = cell_at(p_event.position)
		cursor = cell
		select(inventory.entry_at(cell))
	if p_event is InputEventMouseButton and p_event.pressed \
			and p_event.button_index == MOUSE_BUTTON_LEFT \
			and p_event.double_click and selected != null:
		entry_activated.emit(selected)
	if p_event is InputEventMouseButton and p_event.pressed \
			and p_event.button_index == MOUSE_BUTTON_RIGHT and selected != null:
		context_requested.emit(selected, get_global_position() + p_event.position)


func _get_drag_data(p_position: Vector2) -> Variant:
	var cell: Vector2i = cell_at(p_position)
	var entry: InventoryEntry = inventory.entry_at(cell)
	if entry == null:
		return null
	var data: Dictionary = InventoryDrag.begin(entry, cell - entry.origin)
	data.source = inventory
	set_drag_preview(InventoryDrag.build_preview(data, item_scene, CELL))
	widget_for(entry).hide()  # it rides the cursor now
	return data


func _can_drop_data(p_position: Vector2, p_data: Variant) -> bool:
	if not InventoryDrag.is_drag(p_data):
		return false
	# Dropping onto a matching stack tops it up rather than demanding the cells.
	var merge: InventoryEntry = merge_target(p_position, p_data)
	if merge:
		InventoryDrag.mark(p_data, true)
		show_footprint(merge.origin, merge.item.size, true)
		return true
	var origin: Vector2i = target_origin(p_position, p_data)
	var ok: bool = inventory.can_place(p_data.entry.item, origin,
			ignored_entry(p_data))
	InventoryDrag.mark(p_data, ok)
	show_footprint(origin, p_data.entry.item.size, ok)
	return ok


# The stack under the CURSOR that the dragged one could pour into. Reads from
# the pointer, not the footprint origin, so aiming at a stack means the stack.
func merge_target(p_position: Vector2, p_data: Dictionary) -> InventoryEntry:
	var under: InventoryEntry = inventory.entry_at(cell_at(p_position))
	if under != null and under != p_data.entry \
			and under.item.stacks_with(p_data.entry.item) \
			and under.free_space() > 0:
		return under
	return null


# Washes the cells the item would land on, so the footprint reads before the
# drop rather than after it.
func show_footprint(p_origin: Vector2i, p_size: Vector2i, p_valid: bool):
	# A drag crossing into another container hands the wash over, so the grid
	# it left never strands one - mouse-exit alone is not dependable mid-drag.
	if active_grid != self and is_instance_valid(active_grid):
		active_grid.clear_highlight()
	clear_highlight()
	active_grid = self  # claim AFTER clearing - clear_highlight releases it
	for y in p_size.y:
		for x in p_size.x:
			# Locked cells were never built, so the map answers for bounds too.
			var widget: InventoryCell = cell_map.get(p_origin + Vector2i(x, y))
			if widget == null:
				continue
			widget.set_highlight(true, p_valid)
			highlighted.append(widget)


func clear_highlight():
	for cell in highlighted:
		if is_instance_valid(cell):
			cell.set_highlight(false)
	highlighted.clear()
	if active_grid == self:
		active_grid = null


func _drop_data(p_position: Vector2, p_data: Variant):
	var merge: InventoryEntry = merge_target(p_position, p_data)
	if merge:
		merge_stacks(merge, p_data)
		return
	var origin: Vector2i = target_origin(p_position, p_data)
	if p_data.source == inventory:
		inventory.move(p_data.entry, origin)
	elif not take_from(p_data, origin):
		return  # nothing landed; the slot must keep what it still holds
	# Landing in a grid means the stack is no longer held in a quick slot.
	if p_data.slot >= 0 and p_data.owner:
		p_data.owner.clear_slot(p_data.slot)
	select(p_data.entry)


# Tops the stack up, hunts free cells for the overflow, and leaves whatever
# still has no room sitting where it came from. The quick slot is only
# released when the whole stack actually left it.
func merge_stacks(p_target: InventoryEntry, p_data: Dictionary):
	var entry: InventoryEntry = p_data.entry
	var from: Inventory = p_data.source
	var moved: int = mini(p_target.free_space(), entry.count)
	p_target.count += moved
	entry.count -= moved
	if entry.count > 0:
		entry.count = inventory.add(entry.item, entry.count)
	if entry.count <= 0:
		if from:
			from.remove(entry)
		if p_data.slot >= 0 and p_data.owner:
			p_data.owner.clear_slot(p_data.slot)
	if from:
		from.changed.emit()
	inventory.changed.emit()
	select(p_target)


# Moves an entry in from another container or off a quick slot, keeping its
# stack count. The caller has already confirmed the cells fit.
func take_from(p_data: Dictionary, p_origin: Vector2i) -> bool:
	var from: Inventory = p_data.source
	var count: int = p_data.entry.count
	if from:
		from.remove(p_data.entry)
	var landed: InventoryEntry = inventory.place(p_data.entry.item, p_origin, count)
	if landed == null:
		if from:
			from.place(p_data.entry.item, p_data.entry.origin, count)  # put it back
		return false
	p_data.entry = landed
	return true


# An entry moving inside its own container may overlap itself; one arriving
# from elsewhere may not.
func ignored_entry(p_data: Dictionary) -> InventoryEntry:
	return p_data.entry if p_data.source == inventory else null


func target_origin(p_position: Vector2, p_data: Dictionary) -> Vector2i:
	return cell_at(p_position) - p_data.grab


func widget_for(p_entry: InventoryEntry) -> InventoryItemUI:
	for widget in item_root.get_children():
		if widget.entry == p_entry:
			return widget
	return null


func cell_at(p_position: Vector2) -> Vector2i:
	return Vector2i((p_position / CELL).floor())


# Arrow keys walk the cursor; the backpack screen forwards them so the pad
# works without a mouse.
func move_cursor(p_step: Vector2i):
	var grid: Vector2i = inventory.storage.size
	cursor = Vector2i(clampi(cursor.x + p_step.x, 0, grid.x - 1),
			clampi(cursor.y + p_step.y, 0, grid.y - 1))
	select(inventory.entry_at(cursor))


func select(p_entry: InventoryEntry):
	if p_entry == selected:
		return
	selected = p_entry
	for widget in item_root.get_children():
		widget.set_selected(widget.entry == selected)
	selection_changed.emit(selected)


# Where a selected item sits on screen, so the tooltip can sit beside it.
func selection_rect() -> Rect2:
	if selected == null:
		return Rect2()
	return Rect2(global_position + Vector2(selected.origin) * CELL,
			Vector2(selected.item.size) * CELL)
