class_name PlayerPersistence
extends Node
# The player's slice of a save: where they stand, what shape they're in, and
# the whole pack. Sits in the `persistent` group; SaveManager drives it.

@export var carried: CharacterInventory
@export var energy: PlayerEnergy

@onready var character: Character = get_parent()


func _ready():
	add_to_group("persistent")


func save_state() -> Dictionary:
	# Slots are storage of their own, so each saves its stack as a full row -
	# the index-into-the-grid scheme died when the slots stopped being proxies.
	# Spelled out rather than a ternary: a Dictionary and null do not unify, and
	# null is the sentinel load_state gates on (`row is Dictionary`) - an empty
	# {} would pass that gate and then fault on the missing path key.
	var slots: Array = []
	for entry in carried.quick_slots:
		if entry:
			slots.append(Inventory.save_row(entry))
		else:
			slots.append(null)
	return {
		"position": [character.global_position.x, character.global_position.y,
				character.global_position.z],
		"health": character.current_health,
		"energy": energy.current,
		"inventory": carried.inventory.save_entries(),
		"quick_slots": slots,
		"active_slot": carried.active_slot,
		"holstered": character.weapons.is_holstered() if character.weapons else false,
	}


func load_state(p_state: Dictionary):
	character.global_position = Vector3(p_state.position[0], p_state.position[1],
			p_state.position[2])
	character.velocity = Vector3.ZERO
	character.current_health = int(p_state.health)
	Signals.health_updated.emit(character.current_health,
			character.data.max_health if character.data else 0)
	energy.set_energy(float(p_state.energy))
	carried.inventory.load_entries(p_state.inventory)
	# Each slot rebuilds its own stack from its row; nothing points at the grid.
	for i in carried.quick_slots.size():
		var row: Variant = p_state.quick_slots[i] if i < p_state.quick_slots.size() else null
		carried.quick_slots[i] = Inventory.load_row(row) if row is Dictionary else null
	carried.push_weapons()
	var active: int = int(p_state.get("active_slot", -1))
	if active >= 0 and carried.quick_slots[active] != null:
		carried.select_slot(active)
	else:
		carried.active_slot = -1
	if bool(p_state.get("holstered", false)) and character.weapons \
			and not character.weapons.is_holstered():
		carried.holster()
	carried.notify_slots()
