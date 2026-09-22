class_name PlayerInventory
extends CharacterInventory
# Input over CharacterInventory; the backpack SCREEN owns TAB, equip and drop.

const HOLSTER_HOLD: float = 0.4  # sec of held toggle_weapon that means "put it away"

var consume: PlayerConsume
var carry: PlayerCarry
var toggle_held: float = -1.0  # sec the pad's weapon button has been down; -1 = up


func _ready():
	for child in get_parent().get_children():
		if child is PlayerConsume:
			consume = child
		elif child is PlayerCarry:
			carry = child


# Carrying refuses the draw and the equip at the ONE gate every UI path funnels
# through, so a pack-panel click can no more arm the carrying hands than a key.
func select_slot(p_slot: int):
	if carry and carry.carrying:
		return
	super(p_slot)


func equip(p_entry: InventoryEntry):
	if carry and carry.carrying:
		return
	super(p_entry)


func _process(p_delta):
	if carry and carry.carrying:
		return  # the barrel owns the hands: no slots, no cycling, no holster
	if quick_slots.is_empty():
		return
	for slot in quick_slots.size():
		if Input.is_action_just_pressed("weapon_slot_%d" % slot):
			# Any slot press cuts a drink in progress; the hand is moving on.
			if consume:
				consume.cancel_use()
			select_slot(slot)
			# A consumable's shortcut IS the use: one press drinks it.
			var entry: InventoryEntry = quick_slots[slot]
			if consume and entry and entry.item is ConsumableData:
				consume.begin_use(entry.item)
	if Input.is_action_just_pressed("next_item"):
		cycle_weapon(1)
	elif Input.is_action_just_pressed("prev_item"):
		cycle_weapon(-1)
	if Input.is_action_just_pressed("holster"):
		if consume:
			consume.cancel_use()
		holster()
	poll_weapon_toggle(p_delta)


# The pad's one weapon button: a TAP flips between the two weapon slots, a HOLD
# is the holster. The tap fires on RELEASE, not press - firing it on press
# would draw a gun on the way into every holster.
func poll_weapon_toggle(p_delta: float):
	if Input.is_action_just_pressed("toggle_weapon"):
		toggle_held = 0.0
	if toggle_held < 0.0:
		return
	toggle_held += p_delta
	if toggle_held >= HOLSTER_HOLD:
		toggle_held = -1.0
		if consume:
			consume.cancel_use()
		holster()
	elif Input.is_action_just_released("toggle_weapon"):
		toggle_held = -1.0
		if consume:
			consume.cancel_use()
		cycle_weapon(1)


# Q/E flip between the FILLED weapon slots - holstered (or a hole in slot 0)
# lands on the first one rather than doing nothing.
func cycle_weapon(p_step: int):
	var filled: Array[int] = []
	for i in mini(WEAPON_SLOTS, quick_slots.size()):
		if quick_slots[i] != null:
			filled.append(i)
	if filled.is_empty():
		return
	select_slot(filled[wrapi(filled.find(active_slot) + p_step, 0, filled.size())])
