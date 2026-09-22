extends ProbeBase
# DBG probe: the survival battery - sprinting drains it hard, walking sips,
# standing is free; empty blocks the sprint and drags the walk until the
# recover threshold; water refills it and refuses at full; the bar signal
# follows every change.

var signal_count: int = 0
var last_signal: Vector2 = Vector2.ZERO


func _ready():
	# Sleeping autosaves now; point the manager at scratch files first.
	SaveManager.save_path = "user://probe_energy.json"
	SaveManager.backup_path = "user://probe_energy.bak"
	var gym: Node = (load("res://_tools/gym/gym.tscn") as PackedScene).instantiate()
	add_child(gym)
	for i in 4:
		await get_tree().process_frame
	# The gym enemy would shoot the walker mid-measurement; clear the range.
	for brain in gym.find_children("*", "EnemyAI", true, false):
		brain.get_parent().queue_free()
	await get_tree().process_frame
	var player: Character = InputManager.player
	var energy: PlayerEnergy = null
	var consume: PlayerConsume = null
	var movement: CharacterMovement = null
	for child in player.get_children():
		if child is PlayerEnergy:
			energy = child
		if child is PlayerConsume:
			consume = child
		if child is CharacterMovement:
			movement = child
	check(energy != null, "the player carries the battery", str(energy))
	Signals.energy_updated.connect(func(p_current, p_max):
			signal_count += 1
			last_signal = Vector2(p_current, p_max))
	check(energy.is_full(), "it rolls out full", "%.0f/%.0f" % [energy.current, energy.max_energy])

	# --- standing still is free
	var before: float = energy.current
	for i in 60:
		await get_tree().physics_frame
	check(is_equal_approx(energy.current, before), "standing still is free",
			"%.2f -> %.2f" % [before, energy.current])

	# --- sprinting drains faster than walking (the walk leg retraces the
	# sprint's path, so both cross ground the sprint already proved clear)
	Input.action_press("move_up")
	Input.action_press("sprint")
	for i in 120:
		await get_tree().physics_frame
	Input.action_release("sprint")
	Input.action_release("move_up")
	var after_sprint: float = energy.current
	var sprint_cost: float = before - after_sprint
	Input.action_press("move_down")
	for i in 120:
		await get_tree().physics_frame
	Input.action_release("move_down")
	var walk_cost: float = after_sprint - energy.current
	check(sprint_cost > walk_cost * 2.0 and walk_cost > 0.05,
			"a sprint gulps what a walk sips",
			"sprint %.2f vs walk %.2f over 2s each" % [sprint_cost, walk_cost])

	# --- empty is exhausted: no sprint, heavy legs
	energy.set_energy(0.0)
	check(not movement.sprint_allowed and movement.fatigue_scale < 1.0,
			"empty blocks the sprint and drags the walk",
			"allowed=%s scale=%.2f" % [movement.sprint_allowed, movement.fatigue_scale])
	Input.action_press("move_up")
	Input.action_press("sprint")
	for i in 10:
		await get_tree().physics_frame
	check(not movement.is_sprinting, "holding the key exhausted stays a walk",
			"sprinting=%s" % movement.is_sprinting)
	Input.action_release("sprint")
	Input.action_release("move_up")

	# --- a sip is not enough; the threshold is
	energy.restore(energy.recover_threshold * 0.5)
	check(not movement.sprint_allowed, "a sip does not bring the sprint back",
			"%.1f in" % energy.current)
	energy.restore(energy.recover_threshold)
	check(movement.sprint_allowed and movement.fatigue_scale == 1.0,
			"the threshold does", "%.1f in" % energy.current)

	# --- water refills through the consume path (clip-gated), refuses at full
	var water: ConsumableData = load("res://data/items/consumables/water_bottle.tres")
	var entry: InventoryEntry = consume.carried.inventory.add_one(water)
	entry.count = 2
	consume.carried.assign_quick_slot(entry, 3)
	consume.carried.select_slot(3)
	var clip: float = consume.animator.get_clip_length(PlayerConsume.POSE_USE)
	energy.set_energy(30.0)
	consume.recover_timer = -1.0
	consume.begin_use(water)
	consume.advance_use(clip + 0.1)
	check(is_equal_approx(energy.current, 70.0) and entry.count == 1,
			"a bottle pours 40 in and burns one", "%.0f energy, %d left"
			% [energy.current, entry.count])
	energy.set_energy(energy.max_energy)
	consume.recover_timer = -1.0
	consume.begin_use(water)
	check(not consume.drinking() and entry.count == 1,
			"full refuses the bottle", "%d left" % entry.count)
	# Full health but thirsty: the bandage refuses, the bottle goes down.
	energy.set_energy(20.0)
	consume.recover_timer = -1.0
	consume.begin_use(water)
	consume.advance_use(clip + 0.1)
	check(entry.count == 0 and consume.carried.quick_slots[3] == null,
			"thirst at full health still drinks, and the stack empties its slot",
			str(consume.carried.quick_slots[3]))

	check(signal_count > 3 and is_equal_approx(last_signal.y, energy.max_energy),
			"the bar signal followed along", "%d emits, last %s" % [signal_count, last_signal])

	# --- sleeping rolls the clock to next morning and refills the battery
	var bedroll: Bedroll = (load("res://scenes/props/bedroll.tscn") \
			as PackedScene).instantiate()
	add_child(bedroll)
	energy.set_energy(15.0)
	var day_before: int = Calendar.time_data.day
	bedroll.sleep(player)
	check(Calendar.time_data.hour == Bedroll.WAKE_HOUR \
			and Calendar.time_data.day != day_before,
			"sleep wakes at %02d:00 on a new day" % Bedroll.WAKE_HOUR,
			"day %d -> %d, %02d:%02d" % [day_before, Calendar.time_data.day,
			Calendar.time_data.hour, Calendar.time_data.minute])
	check(energy.is_full(), "and the battery wakes full",
			"%.0f/%.0f" % [energy.current, energy.max_energy])

	finish()
