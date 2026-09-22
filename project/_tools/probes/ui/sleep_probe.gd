extends ProbeBase
# DBG probe: the sleep time-lapse - the bedroll hands the jump to the overlay,
# the world pauses while the clock visibly sweeps, morning lands with the
# battery full and the save written, and the world comes back. The direct
# no-overlay path stays energy_probe's subject.


func _ready():
	# The sleep SAVES; the real file must never be the one it writes.
	SaveManager.save_path = "user://sleep_probe_save.json"
	SaveManager.backup_path = "user://sleep_probe_save.bak"
	var game: Node = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await settle(8)
	var player: Character = InputManager.player
	var transition: SleepTransition = Globals.sleep_transition
	var bedroll: Node = game.find_child("Bedroll", true, false)
	if not check(transition != null and bedroll is Bedroll,
			"the overlay registered and the map carries the bedroll",
			"%s / %s" % [transition, bedroll]):
		finish()
		return

	var energy: PlayerEnergy = null
	for child in player.get_children():
		if child is PlayerEnergy:
			energy = child
	Calendar.set_time(22, 0)
	energy.set_energy(30.0)
	var day_before: int = Calendar.time_data.day

	# --- the press starts the night instead of finishing it
	bedroll.sleep(player)
	check(transition.running and transition.visible and get_tree().paused,
			"sleeping pauses the world under the overlay", "night falls")
	check(is_equal_approx(energy.current, 30.0),
			"and nothing has landed at the press", "%.0f energy" % energy.current)

	# --- the clock is genuinely sweeping, not jumping
	await paused_seconds(1.5)
	var minutes: int = Calendar.time_data.hour * 60 + Calendar.time_data.minute
	check(transition.running and (minutes > 22 * 60 or Calendar.time_data.day != day_before),
			"mid-lapse the clock has moved and the night still plays",
			"%02d:%02d" % [Calendar.time_data.hour, Calendar.time_data.minute])
	check(clock_shown(transition), "the readout shows the passing time",
			transition.clock_label.text)

	# --- morning lands whole
	await transition.finished
	check(Calendar.time_data.hour == Bedroll.WAKE_HOUR \
			and Calendar.time_data.minute == 0 \
			and Calendar.time_data.day != day_before,
			"the sweep lands exactly on tomorrow %02d:00" % Bedroll.WAKE_HOUR,
			"day %d, %02d:%02d" % [Calendar.time_data.day,
			Calendar.time_data.hour, Calendar.time_data.minute])
	check(is_equal_approx(energy.current, energy.max_energy),
			"the battery refills at the END of the night", "%.0f" % energy.current)
	check(FileAccess.file_exists(SaveManager.save_path),
			"and the morning is saved", SaveManager.save_path)
	check(not get_tree().paused and not transition.visible \
			and not transition.running,
			"the world comes back", "released")

	finish()


func clock_shown(p_transition: SleepTransition) -> bool:
	return not p_transition.clock_label.text.is_empty() \
			and p_transition.clock_label.modulate.a > 0.5


# A paused tree still runs SceneTreeTimers built process_always.
func paused_seconds(p_span: float):
	await get_tree().create_timer(p_span, true).timeout
