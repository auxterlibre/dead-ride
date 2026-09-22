extends ProbeBase
# Windowed only - headless renders blank. The prototype as the player sees it:
# the armored truck under way with the crew firing, saved at three moments.

const DRIVE_FRAMES: int = 300
const MOMENTS: PackedInt32Array = [300, 900, 1500]


func _ready():
	if not windowed("the ride"):
		finish()
		return
	var ride: Node = (load("res://scenes/prototype/dead_ride.tscn") as PackedScene).instantiate()
	add_child(ride)
	await settle(30)
	var horde: Horde = find_first(ride, "Horde")
	var truck: Vehicle = find_first(ride, "Vehicle")
	Input.action_press("car_accelerate")
	var last: int = MOMENTS[MOMENTS.size() - 1]
	for i in last + 1:
		await get_tree().process_frame
		if i == DRIVE_FRAMES:
			Input.action_release("car_accelerate")
		if i in MOMENTS:
			save_shot(await capture(), "ride_%ds" % (i / 60))
	check(truck != null and not truck.is_destroyed, "the truck is still standing at the last shot",
			"%d hp, %d zombies about" % [truck.health if truck else -1, horde.alive_count if horde else -1])
	finish()
