class_name Bedroll
extends StaticBody3D

const WAKE_HOUR: int = 8


# The only save in the game: a day cannot be banked without spending it.
# The press starts the night: with the overlay in the scene the clock SWEEPS
# to morning there and wake() lands at its end; a scene without one (probes,
# the gym) wakes on the spot, exactly the old jump.
func sleep(p_player = null):
	if p_player == null:
		return
	for child in p_player.get_children():
		# A carried barrel is nowhere the save can see it - set it down first.
		if child is PlayerCarry:
			child.force_drop()
	if Globals.sleep_transition:
		Globals.sleep_transition.begin(self, p_player)
	else:
		wake(p_player)


# Morning itself: the clock lands, the battery fills, the save writes. The
# sweep arrives already standing on the wake minute, so set_time is its
# exactly-equal no-op there - one wake() serves both paths.
func wake(p_player = null):
	Calendar.set_time(WAKE_HOUR, 0)
	if p_player:
		for child in p_player.get_children():
			if child is PlayerEnergy:
				child.set_energy(child.max_energy)
	SaveManager.save_game()
