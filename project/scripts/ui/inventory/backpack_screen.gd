class_name BackpackScreen
extends Control

const PANEL_GAP: int = 128
const PANEL_PADDING: int = 128
const BACKPACK_LEFT: int = 128

@onready var column: Control = %Column
@onready var backpack_panel: BackpackPanelUI = %BackpackPanel
@onready var container_panel: ContainerPanelUI = %ContainerPanel
@onready var tooltip: ItemTooltip = %ItemTooltip
@onready var close_button: InputKeyButton = %CloseButton
@onready var context_menu: ContextMenu = %ContextMenu
@onready var planting_panel: PlantingPanelUI = %PlantingPanel

var source: CharacterInventory
var grid: InventoryGridUI
var dragging: bool = false


func _ready():
	hide()
	grid = backpack_panel.grid
	grid.selection_changed.connect(on_selection_changed)
	container_panel.grid.selection_changed.connect(on_selection_changed)
	grid.entry_activated.connect(func(_p_entry): transfer(grid))
	container_panel.grid.entry_activated.connect(
			func(_p_entry): transfer(container_panel.grid))
	planting_panel.grid.entry_activated.connect(
			func(_p_entry): transfer(planting_panel.grid))
	grid.context_requested.connect(open_context.bind(grid))
	container_panel.grid.context_requested.connect(
			open_context.bind(container_panel.grid))
	backpack_panel.slot_hovered.connect(on_slot_hovered)
	close_button.pressed.connect(close)
	planting_panel.grid.selection_changed.connect(on_selection_changed)
	planting_panel.grid.context_requested.connect(
			open_context.bind(planting_panel.grid))
	planting_panel.planted.connect(close)
	Signals.container_opened.connect(open_container)
	Signals.planting_opened.connect(open_planting)


func _notification(p_what: int):
	if not is_node_ready():
		return
	if p_what == NOTIFICATION_DRAG_BEGIN:
		dragging = true
		tooltip.hide()
	elif p_what == NOTIFICATION_DRAG_END:
		dragging = false
		on_selection_changed(focused_grid().selected)


func _unhandled_input(p_event: InputEvent):
	if p_event.is_action_pressed("toggle_backpack"):
		get_viewport().set_input_as_handled()
		if visible:
			close()
		else:
			open()
		return
	if not visible:
		return
	if p_event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif p_event.is_action_pressed("item_equip") \
			or p_event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		if beside():
			transfer(focused_grid())
		else:
			act(true)
	elif p_event.is_action_pressed("item_drop"):
		get_viewport().set_input_as_handled()
		act(false)
	elif p_event.is_action_pressed("ui_left"):
		focused_grid().move_cursor(Vector2i.LEFT)
	elif p_event.is_action_pressed("ui_right"):
		focused_grid().move_cursor(Vector2i.RIGHT)
	elif p_event.is_action_pressed("ui_up"):
		focused_grid().move_cursor(Vector2i.UP)
	elif p_event.is_action_pressed("ui_down"):
		focused_grid().move_cursor(Vector2i.DOWN)


func open():
	source = resolve_inventory()
	if source == null:
		return  # no player yet (the gym, or before spawn)
	backpack_panel.setup(source.backpack.name, source.inventory)
	backpack_panel.setup_slots(source)
	tooltip.hide()
	show()
	layout_panels()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	push_state()


# A world container (the car trunk) opens beside the pack.
func open_container(p_title: String, p_inventory: Inventory):
	if not visible:
		open()
	if source == null:
		return
	# The planting slot gives its contents back before losing its place.
	planting_panel.release(source.inventory)
	planting_panel.hide()
	container_panel.setup(p_title, p_inventory)
	container_panel.show()
	layout_panels()
	push_state()


# A bare crop spot opens its planting slot where a container would sit; the two
# are never up together, which is what lets the planting slot borrow the pack's
# free cells for the round trip its `release` makes.
func open_planting(p_plot: CropPlot, p_spot: int):
	if not visible:
		open()
	if source == null:
		return
	container_panel.hide()
	planting_panel.open_for(p_plot, p_spot)
	planting_panel.show()
	layout_panels()
	push_state()


func close():
	hide()
	context_menu.close()
	container_panel.hide()
	# Before the panel goes: whatever is in the slot is out of the pack, and
	# nothing else in the game would ever hand it back.
	planting_panel.release(source.inventory if source else null)
	planting_panel.hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	push_state()


# Authority on which view is up; container_opened arrives in scene order, not view order.
func push_state():
	Signals.backpack_state_changed.emit(visible, beside() != null)


# Solo, the pack hugs the left margin so the tooltip has room. With a second
# container the pair is centred, as the trunk mockup has it.
func layout_panels():
	var width: int = panel_width(backpack_panel)
	var side: ContainerPanelUI = beside()
	if side:
		width += PANEL_GAP + panel_width(side)
		column.anchor_left = 0.5
		column.anchor_right = 0.5
		column.offset_left = -width / 2.0
		column.offset_right = width / 2.0
	else:
		column.anchor_left = 0.0
		column.anchor_right = 0.0
		column.offset_left = BACKPACK_LEFT
		column.offset_right = BACKPACK_LEFT + width


# Whichever panel stands beside the pack, or null when it stands alone. Only
# ever one: a container and a planting slot would both claim the same place.
func beside() -> ContainerPanelUI:
	if container_panel.visible:
		return container_panel
	return planting_panel if planting_panel.visible else null


# A panel may declare a floor: the planting slot is one cell wide and its
# button is not, so its own minimum wins over what the grid asks for.
func panel_width(p_panel: ContainerPanelUI) -> int:
	if p_panel.grid.inventory == null:
		return 0
	return maxi(p_panel.grid.inventory.storage.size.x * InventoryGridUI.CELL \
			+ PANEL_PADDING, int(p_panel.custom_minimum_size.x))


func act(p_equip: bool):
	var focused: InventoryGridUI = focused_grid()
	if focused.selected == null:
		return
	if p_equip:
		source.equip(focused.selected)  # PlayerInventory refuses this while carrying
	else:
		source.drop(focused.selected)


# A carried barrel owns the hands; Consume and Equip rows stop advertising.
func hands_full() -> bool:
	if InputManager.player == null:
		return false
	for child in InputManager.player.get_children():
		if child is PlayerCarry:
			return child.carrying
	return false


# The hovered stack crosses to the other container: stacks of its kind top up
# first, overflow opens new cells, and whatever finds no room stays put.
func transfer(p_from: InventoryGridUI):
	var side: ContainerPanelUI = beside()
	if side == null or p_from.selected == null:
		return
	var entry: InventoryEntry = p_from.selected
	var target: Inventory = side.grid.inventory \
			if p_from == grid else source.inventory
	var leftover: int = target.add(entry.item, entry.count)
	if leftover == entry.count:
		return  # no room at all over there; nothing moved
	if leftover > 0:
		entry.count = leftover
		p_from.inventory.changed.emit()
		return
	# The whole stack crossed. Leaving the PACK runs the drop's slot cleanup
	# (quick slots, equipped weapon); a container entry just goes.
	if p_from == grid:
		source.drop(entry)
	else:
		p_from.inventory.remove(entry)


# Right-click: what can this stack do right now? The rows are computed, not
# authored - an action only lists while it is actually possible, the same
# conditional-advertising rule the world's offers follow.
func open_context(p_entry: InventoryEntry, p_at: Vector2, p_from: InventoryGridUI):
	tooltip.hide()
	var actions: Array = []
	if p_from == grid and p_entry.item is ConsumableData and not hands_full():
		actions.append({"label": "Consume",
				"callback": consume_entry.bind(p_entry)})
	if p_from == grid and p_entry.item is WeaponData and not hands_full():
		actions.append({"label": "Equip",
				"callback": func(): source.equip(p_entry)})
	if beside():
		actions.append({"label": "Transfer",
				"callback": func(): transfer(p_from)})
	if p_from == grid:
		actions.append({"label": "Drop",
				"callback": func(): source.drop(p_entry)})
	if actions.is_empty():
		return
	context_menu.open(p_at, actions)


# The drink needs the world running and the clip finishing - close first, then
# hand the stack to PlayerConsume, which owns the completion and the interrupt.
func consume_entry(p_entry: InventoryEntry):
	var consume: PlayerConsume = null
	if InputManager.player:
		for child in InputManager.player.get_children():
			if child is PlayerConsume:
				consume = child
	if consume == null:
		return
	close()
	consume.begin_use(p_entry.item, p_entry, source.inventory)


# Whichever grid holds the current selection; the backpack by default.
func focused_grid() -> InventoryGridUI:
	var side: ContainerPanelUI = beside()
	if side and side.grid.selected != null:
		return side.grid
	return grid


func on_selection_changed(p_entry: InventoryEntry):
	# A dragged item is already under the cursor saying what it is; a card
	# trailing it would only cover the cells you are aiming at.
	if p_entry == null or dragging:
		tooltip.hide()
		return
	tooltip.show_item(p_entry.item)
	# The card sizes itself from its rows, so place it after the layout pass.
	await get_tree().process_frame
	tooltip.place_beside(focused_grid().selection_rect())


# The panel's slot widgets carry the same card the grid items do.
func on_slot_hovered(p_entry: InventoryEntry, p_rect: Rect2):
	if p_entry == null or dragging:
		tooltip.hide()
		return
	tooltip.show_item(p_entry.item)
	await get_tree().process_frame
	tooltip.place_beside(p_rect)


func resolve_inventory() -> CharacterInventory:
	if InputManager.player == null:
		return null
	for child in InputManager.player.get_children():
		if child is CharacterInventory:
			return child
	return null
