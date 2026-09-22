extends ProbeBase
# DBG probe: consumables - the use_item clip owns the act. A selected
# consumable claims the attack button; the restore lands only when the clip
# FINISHES; damage mid-drink cuts it and swallows nothing; the stack dents on
# completion alone; the bottle rides the hand; the grid path (the context
# menu's) dents its own stack.


func _ready():
	var gym: Node = (load("res://_tools/gym/gym.tscn") as PackedScene).instantiate()
	add_child(gym)
	for i in 4:
		await get_tree().process_frame
	var player: Character = InputManager.player
	var carried: CharacterInventory = null
	var consume: PlayerConsume = null
	for child in player.get_children():
		if child is CharacterInventory:
			carried = child
		if child is PlayerConsume:
			consume = child
	check(consume != null, "the player carries the consume component", str(consume))

	# The throw probe's lesson: the clip being in the LIBRARY is not enough -
	# the upper_state transition needs the input or it animates nothing.
	var tree: AnimationTree = player.find_child("AnimationTree", true, false)
	var transition: AnimationNodeTransition = tree.tree_root.get_node("upper_state")
	var inputs: Array = []
	for i in transition.input_count:
		inputs.append(transition.get_input_name(i))
	check(PlayerConsume.POSE_USE in inputs \
			and tree.tree_root.has_node("anim_" + PlayerConsume.POSE_USE),
			"use_item is a wired upper_state input",
			"input=%s node=%s" % [PlayerConsume.POSE_USE in inputs,
			tree.tree_root.has_node("anim_" + PlayerConsume.POSE_USE)])
	var clip: float = consume.animator.get_clip_length(PlayerConsume.POSE_USE)
	check(clip > 0.0, "and the clip has real length", "%.2fs" % clip)

	# Two bandages into a utility slot, selected.
	var bandage: ConsumableData = load("res://data/items/consumables/field_bandage.tres")
	var entry: InventoryEntry = carried.inventory.add_one(bandage)
	entry.count = 2
	var slot: int = 2  # first utility slot, after the two weapon slots
	carried.assign_quick_slot(entry, slot)
	carried.select_slot(slot)
	check(consume.selected() == bandage, "a selected bandage is the ready item",
			str(consume.selected()))
	check(consume.holds_attack(), "and it claims the attack button", "claimed")

	# Full health: using it must refuse rather than waste one.
	consume.begin_use(bandage)
	check(not consume.drinking() and entry.count == 2,
			"full health refuses the bandage", "%d left at %d hp"
			% [entry.count, player.current_health])

	# Hurt, then use: nothing lands until the clip has run its whole length.
	player.take_damage(AttackData.new(9, player.global_position, 0.0, null))
	var hurt: int = player.current_health
	consume.begin_use(bandage)
	check(consume.drinking(), "the drink starts on the hurt body", "in progress")
	check(player.current_health == hurt and entry.count == 2,
			"mid-clip nothing has landed yet",
			"%d hp, %d in the stack" % [player.current_health, entry.count])
	consume.advance_use(clip + 0.1)
	check(player.current_health == hurt + bandage.health,
			"the finished clip restores its stated points",
			"%d -> %d" % [hurt, player.current_health])
	check(entry.count == 1, "and burns one from the stack", "%d left" % entry.count)
	check(consume.holds_attack(), "the recover beat keeps the claim", "claimed")

	# Interrupted: a hit mid-drink cuts the clip, and the sip never happened.
	consume.recover_timer = -1.0
	player.take_damage(AttackData.new(4, player.global_position, 0.0, null))
	var shot: int = player.current_health
	consume.begin_use(bandage)
	check(consume.drinking(), "a second drink starts", "in progress")
	player.take_damage(AttackData.new(1, player.global_position, 0.0, null))
	check(not consume.drinking(), "getting shot cuts the drink", "cut")
	consume.advance_use(clip + 0.1)
	check(player.current_health == shot - 1 and entry.count == 1,
			"no points land and no bandage burns",
			"%d hp, %d in the stack" % [player.current_health, entry.count])

	# The last one empties and clears the slot.
	player.take_damage(AttackData.new(2, player.global_position, 0.0, null))
	consume.begin_use(bandage)
	consume.advance_use(clip + 0.1)
	check(carried.quick_slots[slot] == null and consume.selected() == null,
			"an emptied stack clears its quick slot", str(carried.quick_slots[slot]))

	# The bottle: a consumable WITH a body rides the hand while selected.
	var bottle: ConsumableData = load("res://data/items/consumables/water_bottle.tres")
	check(bottle.get_held_scene() != null, "the bottle offers its model to the hand",
			str(bottle.get_held_scene()))
	var bottle_entry: InventoryEntry = carried.inventory.add_one(bottle)
	bottle_entry.count = 2
	carried.assign_quick_slot(bottle_entry, slot)
	carried.select_slot(slot)
	check(carried.weapons.held_prop != null, "selecting the bottle slot holds it",
			"in hand")

	# --- hands EMPTY before the drink return to empty - even with a bottle
	# LEFT on the slot, which must not climb back into the hand
	consume.energy.set_energy(20.0)
	consume.begin_use(bottle)
	consume.advance_use(clip + 0.1)
	check(carried.weapons.is_holstered() and carried.weapons.held_prop == null \
			and carried.active_slot == -1,
			"empty hands before the drink return to empty", "still bare")
	check(bottle_entry.count == 1 and carried.quick_slots[slot] == bottle_entry,
			"while the spare bottle stays on the slot, not in the hand",
			"%d slotted" % bottle_entry.count)

	# --- the drink over, the last DRAWN weapon comes back out
	carried.select_slot(0)
	check(carried.weapons.current_weapon != null, "a weapon is drawn to return to",
			carried.weapons.current_weapon.name)
	carried.select_slot(slot)  # swaps the gun away for the bottle
	consume.energy.set_energy(20.0)
	consume.begin_use(bottle)
	consume.advance_use(clip + 0.1)
	check(carried.weapons.current_weapon != null \
			and carried.weapons.held_prop == null and carried.active_slot == 0,
			"the finished drink re-draws it and drops the bottle",
			"%s out, active %d" % [carried.weapons.current_weapon.name
			if carried.weapons.current_weapon else "<none>", carried.active_slot])

	# --- a CUT drink hands the weapon back too, and goes silent
	var second: InventoryEntry = carried.inventory.add_one(bottle)
	carried.assign_quick_slot(second, slot)
	carried.select_slot(slot)
	consume.energy.set_energy(20.0)
	consume.begin_use(bottle)
	check(consume.audio_use.playing \
			and consume.audio_use.stream == bottle.use_audio,
			"the drink plays the bottle's own sound", "gulping")
	player.take_damage(AttackData.new(1, player.global_position, 0.0, null))
	check(not consume.audio_use.playing, "a cut drink goes silent", "stopped")
	check(not consume.drinking() and carried.weapons.current_weapon != null \
			and second.count == 1,
			"a cut drink still hands the weapon back, bottle unspent",
			"%s out, %d bottled" % [carried.weapons.current_weapon.name
			if carried.weapons.current_weapon else "<none>", second.count])

	# The grid path (what the context menu calls): its own stack dents.
	var grid_entry: InventoryEntry = carried.inventory.add_one(bottle)
	grid_entry.count = 2
	consume.energy.set_energy(20.0)
	consume.begin_use(bottle, grid_entry, carried.inventory)
	check(consume.drinking(), "a grid stack drinks too", "in progress")
	var energy_before: float = consume.energy.current
	consume.advance_use(clip + 0.1)
	check(consume.energy.current > energy_before, "the finished bottle hydrates",
			"%.0f -> %.0f" % [energy_before, consume.energy.current])
	check(grid_entry.count == 1, "and dents the GRID stack, not the slot",
			"%d left in the grid, %d on the bar" % [grid_entry.count,
			carried.quick_slots[slot].count if carried.quick_slots[slot] else -1])

	finish()
