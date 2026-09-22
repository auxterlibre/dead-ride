extends ProbeBase
# Cover is the one state that CANNOT be resumed: it needs a spot in its message,
# and nothing that resumes a state has one. So nothing may record it to go back to.

const EXPECTED_CHECKS: int = 4


func _ready():
	var gym: Node = (load("res://_tools/gym/gym.tscn") as PackedScene).instantiate()
	add_child(gym)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var ai: EnemyAI = gym.find_children("*", "EnemyAI", true, false).front()
	check(ai != null, "the gym has an enemy brain", str(ai))
	var machine: StateMachine = ai.state_machine
	var here: Vector3 = ai.character.global_position

	# In cover legitimately, then a shot goes off somewhere: the search that
	# follows must not write "cover" down as the task it interrupted.
	machine.change_state_to("cover", {return_state = "guard",
			spot = here, peek = here + Vector3.RIGHT})
	check(machine.current_state_name == "cover", "the enemy takes cover",
			machine.current_state_name)
	ai.on_noise(here + Vector3.FORWARD * 3.0, 40.0, null)
	var resumed: String = machine.states["investigate"].return_state
	check(resumed != "cover", "the search does not plan to resume cover", resumed)

	# And the belt: entering cover with nothing in the message must not throw.
	# Only try_cover() should ever get here, but a crash is a poor way to say so.
	machine.change_state_to("guard")
	machine.change_state_to("cover")
	await get_tree().physics_frame
	check(true, "a spotless cover entry survives a physics frame",
			machine.current_state_name)

	print("DBG %d passed, %d failed, %d of %d checks ran" % [
			passed, failed, passed + failed, EXPECTED_CHECKS])
	get_tree().quit()
