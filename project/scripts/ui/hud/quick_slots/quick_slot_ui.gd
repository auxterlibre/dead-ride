class_name QuickSlotUI
extends VBoxContainer

@export var empty_style: StyleBox
@export var filled_style: StyleBox
@export var active_slot: StyleBox
@export var key_idle_style: StyleBox
@export var key_active_style: StyleBox
@export var item_scene: PackedScene  # for the drag preview
@export var pip_scene: PackedScene 
@export var show_magazine: bool = true

const SPENT_ALPHA: float = 0.3
const HOP_PEAK_SCALE: float = 1.14
const HOP_RISE_SCALE: float = 0.07
const HOP_UP_TIME: float = 0.06
const HOP_DOWN_TIME: float = 0.16

var entry: InventoryEntry
var slot_index: int = -1
var carried: CharacterInventory
var was_active: bool = false
var hop_tween: Tween

@onready var box: Panel = $Box
@onready var icon: TextureRect = $Box/Icon
@onready var count_label: Label = $Box/Count
@onready var key_label: Label = $Key
@onready var magazine: HBoxContainer = $Box/Magazine


func setup(p_entry: InventoryEntry, p_key: String, p_width: int, p_slot: int = -1):
	entry = p_entry
	slot_index = p_slot if p_slot >= 0 else get_index()
	box.custom_minimum_size = Vector2(p_width, 128)
	key_label.text = p_key
	key_label.visible = p_key != ""  # the pack panel's slots carry no key cap
	icon.texture = p_entry.item.icon if p_entry else null
	box.add_theme_stylebox_override("panel", filled_style if p_entry else empty_style)
	build_magazine()
	refresh_count()


func build_magazine():
	var rounds: int = magazine_size()
	magazine.visible = show_magazine and rounds > 0
	if magazine.get_child_count() == rounds:
		return
	for pip in magazine.get_children():
		magazine.remove_child(pip)  # queue_free alone would leave it laid out
		pip.queue_free()
	for i in rounds:
		magazine.add_child(pip_scene.instantiate())


# The counter is the RESERVE alone - what is loaded reads off the pips above
# it, and those rounds have already left the pack. Stackables read their size.
func refresh_count():
	if entry == null:
		count_label.hide()
		return
	var weapon: WeaponData = entry.item as WeaponData
	if weapon and weapon.is_ranged:
		count_label.text = str(carried.ammo_count(weapon.ammo_type) if carried else 0)
		var loaded: int = maxi(weapon.current_ammo, 0)
		for i in magazine.get_child_count():
			magazine.get_child(i).modulate.a = 1.0 if i < loaded else SPENT_ALPHA
	elif entry.count > 1:
		count_label.text = str(entry.count)
	else:
		count_label.hide()
		return
	count_label.show()


func magazine_size() -> int:
	var weapon: WeaponData = entry.item as WeaponData if entry else null
	return weapon.max_ammo if weapon and weapon.is_ranged else 0


func set_active(p_active: bool):
	key_label.modulate.a = 0.3 if p_active else 1.0
	box.add_theme_stylebox_override("panel", active_slot if p_active else filled_style)
	# Only on the CHANGE: the whole bar re-runs set_active on every quick-slot
	# announcement, so hopping on each one would twitch every time an item moved.
	if p_active and not was_active:
		hop()
	was_active = p_active


# SCALE from a bottom-centre pivot, not position - a container would snap an animated position back.
func hop():
	box.pivot_offset = Vector2(box.size.x * 0.5, box.size.y)
	if hop_tween and hop_tween.is_valid():
		hop_tween.kill()
	hop_tween = create_tween()
	hop_tween.tween_property(box, "scale",
			Vector2(HOP_PEAK_SCALE, HOP_PEAK_SCALE + HOP_RISE_SCALE),
			HOP_UP_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hop_tween.tween_property(box, "scale", Vector2.ONE, HOP_DOWN_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# Right-click stows the stack back into the pack without needing to drag it -
# the slots are real storage, so "off the bar" means "into the grid", and a
# full pack refuses rather than letting the stack vanish.
func _gui_input(p_event: InputEvent):
	if entry == null or carried == null:
		return
	if p_event is InputEventMouseButton and p_event.pressed \
			and p_event.button_index == MOUSE_BUTTON_RIGHT:
		accept_event()
		carried.stow_slot(slot_index)


func _get_drag_data(_p_position: Vector2) -> Variant:
	if entry == null or carried == null:
		return null
	var data: Dictionary = InventoryDrag.begin(entry, Vector2i.ZERO)
	data.slot = slot_index
	data.owner = carried
	set_drag_preview(InventoryDrag.build_preview(data, item_scene, 128))
	return data


func _can_drop_data(_p_position: Vector2, p_data: Variant) -> bool:
	if not InventoryDrag.is_drag(p_data) or carried == null:
		return false
	var ok: bool = carried.slot_accepts(p_data.entry.item, slot_index)
	InventoryDrag.mark(p_data, ok)
	return ok


func _drop_data(_p_position: Vector2, p_data: Variant):
	# The payload's source rides along: an arrival from an open container has
	# to leave THAT inventory, and a displaced occupant swaps back into it.
	carried.assign_quick_slot(p_data.entry, slot_index, p_data.source)
