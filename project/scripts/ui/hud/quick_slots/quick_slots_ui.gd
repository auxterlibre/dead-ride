class_name QuickSlotsUI
extends HBoxContainer

const WEAPON_WIDTH: int = 192  # a weapon icon's 3:2 box
const UTILITY_WIDTH: int = 128

@onready var slot_scene: PackedScene = load("uid://ccg3kodv7x3iy")

@onready var slot_root: HBoxContainer = %SlotRoot

var slots: Array[QuickSlotUI] = []
var was_paused: bool = false
var dead: bool = false
var carrying: bool = false  # a carried barrel owns the hands; no bar to offer
var driving: bool = false  # seated, the hands are on the wheel; same rule


func _ready():
	Signals.quick_slots_updated.connect(refresh)
	Signals.ammo_updated.connect(refresh_ammo)
	Signals.inventory_changed.connect(func(_p_inventory): refresh_ammo())
	Signals.player_died.connect(fade_out)
	Signals.carry_state_changed.connect(func(p_carrying: bool):
		carrying = p_carrying
		apply_visibility())
	Signals.drive_state_changed.connect(func(p_driving: bool):
		driving = p_driving
		apply_visibility())


func _process(_delta: float):
	if get_tree().paused == was_paused:
		return
	was_paused = get_tree().paused
	apply_visibility()


func refresh(p_entries: Array, p_active: int):
	if slots.size() != p_entries.size():
		build(p_entries.size())
	for i in slots.size():
		slots[i].carried = resolve_carried()
		slots[i].setup(p_entries[i], str(i + 1), width_for(i), i)
		slots[i].set_active(i == p_active)
	apply_visibility()


func build(p_count: int):
	for slot in slots:
		slot.queue_free()
	slots.clear()
	for i in p_count:
		var slot: QuickSlotUI = slot_scene.instantiate()
		slot_root.add_child(slot)
		slots.append(slot)


func refresh_ammo():
	for slot in slots:
		slot.refresh_count()


func apply_visibility():
	visible = not get_tree().paused and not dead and not carrying and not driving
	for slot in slots:
		slot.visible = slot.entry != null


func resolve_carried() -> CharacterInventory:
	if InputManager.player == null:
		return null
	for child in InputManager.player.get_children():
		if child is CharacterInventory:
			return child
	return null


func width_for(p_index: int) -> int:
	return WEAPON_WIDTH if p_index < CharacterInventory.WEAPON_SLOTS else UTILITY_WIDTH


func fade_out() -> void:
	var t: Tween = create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	t.tween_callback(func(): dead = true)


func fade_in() -> void:
	dead = false
	modulate.a = 0.0
	show()
	var t: Tween = create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.3)
