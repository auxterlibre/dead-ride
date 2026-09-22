extends ProbeBase

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
	for i in 1500:
		await get_tree().process_frame
		if i == 300:
			Input.action_release("car_accelerate")
		if i % 300 == 299:
			var near: int = 0
			var attacking: int = 0
			for z in horde.capacity:
				if horde.is_alive(z):
					if horde.positions[z].distance_to(truck.global_position) < 8.0:
						near += 1
					if horde.states[z] == Horde.State.ATTACK:
						attacking += 1
			var gunners: Array[Node] = ride.find_children("*", "CrewGunner", true, false)
			print("DBG t=%ds zombies=%d near=%d attacking=%d kills=%d truck_hp=%d truck=%s targets=%s" % [(i + 1) / 60, horde.alive_count, near, attacking, horde.kills, truck.health, str(truck.global_position.snapped(Vector3.ONE * 0.1)), str(gunners.map(func(g): return "zombie" if g.target is HordeTarget else (g.target.name if g.target else "none")))])
			save_shot(await capture(), "ride_%d" % ((i + 1) / 60))
	finish()
