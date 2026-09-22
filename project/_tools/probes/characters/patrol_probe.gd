extends ProbeBase
# DBG probe: the two new idles - a patrol route's stops walked in order and
# resumed after an investigation, and a scavenger drifting crate to crate.

const STOP_REACH: float = 0.9  # m that counts as standing on a stop
const CRATE_REACH: float = 2.4  # STAND_OFF + arrive slack


func _ready():
	var gym: Node = (load("res://_tools/gym/gym.tscn") as PackedScene).instantiate()
	add_child(gym)
	await get_tree().physics_frame
	await get_tree().physics_frame
	# The gym player would get spotted and hijack the idle under test.
	if InputManager.player:
		InputManager.player.global_position = Vector3(500.0, 0.0, 500.0)
	var ai: EnemyAI = gym.find_children("*", "EnemyAI", true, false).front()
	var enemy: Character = ai.character
	var here: Vector3 = enemy.global_position

	# --- the route is walked stop by stop, in order, and loops
	var route: PatrolRoute = PatrolRoute.new()
	route.dwell = Vector2(0.4, 0.4)
	for offset in [Vector3(4.0, 0.0, 0.0), Vector3(4.0, 0.0, 6.0), Vector3(-3.0, 0.0, 5.0)]:
		var stop: Marker3D = Marker3D.new()
		stop.position = here + offset
		route.add_child(stop)
	add_child(route)
	ai.patrol_route = route
	ai.state_machine.change_state_to("patrol")
	check(ai.state_machine.current_state_name == "patrol",
			"the brain takes the route", ai.state_machine.current_state_name)
	var visits: Array = await watch_stops(enemy, route, 4, 45.0)
	check(visits == [0, 1, 2, 0], "stops are walked in order and looped",
			str(visits))

	# --- a noise pulls it away, and the patrol resumes after the look-around
	ai.on_noise(here + Vector3(0.0, 0.0, -8.0), 40.0, null)
	check(ai.state_machine.current_state_name == "investigate",
			"a noise interrupts the walk", ai.state_machine.current_state_name)
	var resumed: bool = await wait_for_state(ai, "patrol", 25.0)
	check(resumed, "the patrol resumes once the scent is cold",
			ai.state_machine.current_state_name)
	if resumed:
		var back: Array = await watch_stops(enemy, route, 1, 20.0)
		check(back.size() == 1, "and the next stop is reached again",
				str(back))

	# --- the scavenger drifts between loot containers
	var crates: Array = []
	for offset in [Vector3(10.0, 0.0, -6.0), Vector3(15.0, 0.0, 2.0)]:
		var crate: Node3D = (load("res://scenes/props/loot_boxes/cardboard_box_small.tscn") \
				as PackedScene).instantiate()
		add_child(crate)
		crate.global_position = here + offset
		crates.append(crate)
	ai.roam = true
	ai.state_machine.change_state_to("roam")
	var rummaged: int = await watch_crates(enemy, 2, 50.0)
	check(rummaged >= 2, "the scavenger visits crate after crate",
			"%d rummaged" % rummaged)

	finish()


# Collects the order stops are reached in, until p_count visits or timeout.
func watch_stops(p_enemy: Character, p_route: PatrolRoute, p_count: int,
		p_budget: float) -> Array:
	var visits: Array = []
	var elapsed: float = 0.0
	while visits.size() < p_count and elapsed < p_budget:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		for i in p_route.stop_count():
			var flat: Vector3 = p_route.stop_position(i) - p_enemy.global_position
			flat.y = 0.0
			if flat.length() < STOP_REACH \
					and (visits.is_empty() or visits.back() != i):
				visits.append(i)
	return visits


func wait_for_state(p_ai: EnemyAI, p_state: String, p_budget: float) -> bool:
	var elapsed: float = 0.0
	while elapsed < p_budget:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		if p_ai.state_machine.current_state_name == p_state:
			return true
	return false


# Counts DISTINCT loot containers the enemy stands rummaging-close to.
func watch_crates(p_enemy: Character, p_count: int, p_budget: float) -> int:
	var seen: Array = []
	var elapsed: float = 0.0
	while seen.size() < p_count and elapsed < p_budget:
		await get_tree().physics_frame
		elapsed += get_physics_process_delta_time()
		for crate in get_tree().get_nodes_in_group("loot_container"):
			var flat: Vector3 = crate.global_position - p_enemy.global_position
			flat.y = 0.0
			if flat.length() < CRATE_REACH and not seen.has(crate):
				seen.append(crate)
	return seen.size()
