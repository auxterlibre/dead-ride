class_name BackpackPanelUI
extends ContainerPanelUI
# The pack's own panel: the shared titled grid plus the six REAL quick slots,
# laid out as the mockup's weapon and item trays. The bar in the HUD mirrors
# the same slots during gameplay; in here they are the interactive ones.

signal slot_hovered(entry, rect)

const WEAPON_WIDTH: int = 256  # two grid cells wide, per the mockup
const ITEM_WIDTH: int = 128

var carried: CharacterInventory
var slots: Array[QuickSlotUI] = []

@onready var weapon_row: HBoxContainer = %WeaponRow
@onready var item_row: HBoxContainer = %ItemRow


func _ready():
	for widget in weapon_row.get_children():
		slots.append(widget)
	for widget in item_row.get_children():
		slots.append(widget)
	for widget in slots:
		widget.mouse_entered.connect(hover.bind(widget))
		widget.mouse_exited.connect(func(): slot_hovered.emit(null, Rect2()))
	Signals.quick_slots_updated.connect(refresh)
	Signals.ammo_updated.connect(refresh_counts)
	# Spending or picking up rounds changes the reserve the weapon slots report.
	Signals.inventory_changed.connect(func(_p_inventory): refresh_counts())


func setup_slots(p_carried: CharacterInventory):
	carried = p_carried
	refresh(carried.quick_slots, carried.active_slot)


func refresh(p_entries: Array, _active: int):
	if carried == null:
		return
	for i in slots.size():
		var widget: QuickSlotUI = slots[i]
		widget.carried = carried
		widget.setup(p_entries[i] if i < p_entries.size() else null, "",
				WEAPON_WIDTH if i < CharacterInventory.WEAPON_SLOTS else ITEM_WIDTH, i)
		widget.set_active(false)


func refresh_counts():
	for widget in slots:
		widget.refresh_count()


func hover(p_widget: QuickSlotUI):
	slot_hovered.emit(p_widget.entry, Rect2(p_widget.global_position, p_widget.size))
