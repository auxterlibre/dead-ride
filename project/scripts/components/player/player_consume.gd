class_name PlayerConsume
extends Node
# The consumable counterpart of PlayerThrow: while one rides the selected
# quick slot, the attack button uses it instead of firing the gun - even at
# full health, so a misclick never turns into a gunshot. Using is not
# instant: the use_item clip owns the whole act, and the restore lands only
# when it FINISHES - damage mid-drink cuts the clip and swallows nothing.

const POSE_USE: String = "use_item"
const USE_RECOVER: float = 0.3  # sec the attack button stays claimed after

@export var carried: CharacterInventory
@export var energy: PlayerEnergy
@export var animator: CharacterAnimator

var pending: ConsumableData
var pending_entry: InventoryEntry
var pending_inventory: Inventory  # set = a grid stack; null = the active slot
var return_slot: int = -1  # the weapon slot the hand goes back to afterwards
var use_timer: float = -1.0
var recover_timer: float = -1.0

@onready var body: CharacterBody3D = get_parent()
@onready var audio_use: AudioStreamPlayer3D = $AudioUse


func _ready():
	var character: Character = body as Character
	if character:
		# Any hit cuts the drink - the user's rule: interrupted is unhydrated.
		character.damaged.connect(func(_p_attack): cancel_use())
		character.died.connect(cancel_use)


func _process(p_delta: float):
	if advance_use(p_delta):
		return  # mid-drink: the clip owns the arms and the attack button
	if recover_timer >= 0.0:
		recover_timer -= p_delta
		return
	var consumable: ConsumableData = selected()
	if consumable == null or get_tree().paused:
		return
	# Polled like firing, gated on the same prompt check, so a click the GUI
	# swallowed cannot also drink a canteen.
	if Input.is_action_just_pressed("attack") and not InputManager.pointer_over_prompt:
		begin_use(consumable)


# PlayerWeapons asks this before firing, exactly like PlayerThrow's claim.
func holds_attack() -> bool:
	return selected() != null or use_timer >= 0.0 or recover_timer >= 0.0


func drinking() -> bool:
	return use_timer >= 0.0


# Starts the act. Refuses when nothing it restores is short: a bandage at full
# health and a bottle at full energy both stay whole. p_entry/p_inventory name
# a grid stack (the context menu's path); left null it drinks the active slot.
func begin_use(p_consumable: ConsumableData, p_entry: InventoryEntry = null,
		p_inventory: Inventory = null):
	if use_timer >= 0.0 or p_consumable == null or not restores(p_consumable):
		return
	# Carrying a barrel: no free hand to drink with, whatever path asked.
	for child in get_parent().get_children():
		if child is PlayerCarry and child.carrying:
			return
	pending = p_consumable
	pending_entry = p_entry
	pending_inventory = p_inventory
	# The hand goes back to whatever the drink DISPLACED, however it ends: the
	# weapon out RIGHT NOW (the grid path), or what the bottle's own selection
	# displaced (prop_return_slot - which remembers empty hands as -1, so a
	# player who drank bare-handed stays bare-handed). Never an older memory:
	# the grid path with nothing drawn returns to nothing.
	return_slot = carried.equipped_slot() if carried else -1
	if return_slot < 0 and carried and p_inventory == null:
		return_slot = carried.prop_return_slot
	# The clip needs the item in hand; the slot path already holds it, the
	# grid path borrows the hand for the drink.
	if carried and carried.weapons and p_consumable.get_held_scene():
		carried.weapons.hold_prop(p_consumable.get_held_scene())
	set_pose(POSE_USE)
	# The ITEM brings the sound (a gulp, a wrap); the act plays it and a cut
	# act silences it - the same rule the restore follows.
	if audio_use and p_consumable.use_audio:
		audio_use.stream = p_consumable.use_audio
		audio_use.play()
	use_timer = animator.get_clip_length(POSE_USE) if animator else 0.0


func advance_use(p_delta: float) -> bool:
	if use_timer < 0.0:
		return false
	use_timer -= p_delta
	if use_timer <= 0.0:
		use_timer = -1.0
		finish_use()
	return true


# The clip completed: NOW the body gets its points and the stack its dent.
func finish_use():
	apply(pending)
	if pending_inventory:
		consume_from_grid()
	else:
		consume_one()
	recover_timer = USE_RECOVER
	settle_hand()


# Cut mid-clip: no restore, no stack dent, no sound - the sip never happened.
func cancel_use():
	if use_timer < 0.0:
		return
	use_timer = -1.0
	if audio_use:
		audio_use.stop()
	settle_hand()


func settle_hand():
	pending = null
	pending_entry = null
	pending_inventory = null
	set_pose("")
	if carried == null or carried.weapons == null:
		return
	# The hand returns to what the drink displaced - the recorded weapon, or
	# RECORDED EMPTINESS: bare hands are an equipped option, so a bottle left
	# on the slot does not climb back into a hand that was empty before.
	var back: int = return_slot
	return_slot = -1
	if back >= 0 and back < carried.quick_slots.size() \
			and carried.quick_slots[back] != null:
		carried.select_slot(back)
	else:
		carried.bare_hands()


# "" releases the upper layer back to whatever the body is doing.
func set_pose(p_clip: String):
	if animator == null:
		return
	if p_clip == "":
		animator.upper_weight = 0.0
		return
	animator.set_upper_animation(p_clip)
	animator.upper_weight = 1.0


# Whatever applies, applies - overshoot clamps.
func apply(p_consumable: ConsumableData):
	var character: Character = body as Character
	if character == null or p_consumable == null:
		return
	character.heal(p_consumable.health)
	if energy:
		energy.restore(p_consumable.energy)


# Used only if SOMETHING it restores is short: a bandage at full health and a
# water flask at full energy both refuse, a ration covering both goes down if
# either is low.
func restores(p_consumable: ConsumableData) -> bool:
	var character: Character = body as Character
	if character == null or character.data == null:
		return false
	var heals: bool = p_consumable.health > 0 \
			and character.current_health < character.data.max_health
	var refills: bool = energy != null and p_consumable.energy > 0 \
			and not energy.is_full()
	return heals or refills


# The same stack bookkeeping a thrown grenade does: the stack lives on the
# slot, so emptying it is emptying the slot. The slot is found by the ITEM,
# never by active_slot - the return may already have drawn a weapon by the
# time the clip ends, and denting the active slot then eats the gun.
func consume_one():
	for i in carried.quick_slots.size():
		var entry: InventoryEntry = carried.quick_slots[i]
		if entry and entry.item == pending:
			entry.count -= 1
			if entry.count <= 0:
				carried.clear_slot(i)
			else:
				carried.notify_slots()
			return


# The context menu's path: the stack sits in a grid, not on the bar.
func consume_from_grid():
	if pending_entry == null or not pending_inventory.entries.has(pending_entry):
		return  # the stack moved or left while the clip played
	pending_entry.count -= 1
	if pending_entry.count <= 0:
		pending_inventory.remove(pending_entry)
	else:
		pending_inventory.changed.emit()


# The consumable on the ACTIVE quick slot, or nothing - selecting the slot is
# what readies it, the same way selecting a weapon slot draws a gun.
func selected() -> ConsumableData:
	if carried == null or carried.active_slot < 0 \
			or carried.active_slot >= carried.quick_slots.size():
		return null
	var entry: InventoryEntry = carried.quick_slots[carried.active_slot]
	return entry.item as ConsumableData if entry else null
