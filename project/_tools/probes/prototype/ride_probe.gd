extends ProbeBase
# DBG probe: the Dead Ride prototype - the player opens seated at the wheel, the
# roof crew is armed with movement off and their rays shielded from the truck,
# raiders spawn and die to crew fire while the truck drives, and a loot drop
# beside the truck empties itself into the trunk.

const RUN_FRAMES: int = 2700
const DRIVE_FRAMES: int = 420

var crew_shots: int = 0


func _ready():
	var ride: Node = (load("res://scenes/prototype/dead_ride.tscn") as PackedScene).instantiate()
	add_child(ride)
	await settle(30)

	var truck: Vehicle = find_first(ride, "Vehicle")
	var spawner: RaiderSpawner = find_first(ride, "RaiderSpawner")
	var gunners: Array[Node] = ride.find_children("*", "CrewGunner", true, false)
	if not check(truck != null and spawner != null and gunners.size() == 2,
			"the scene carries a truck, a spawner and two gunners",
			"%s %s %d" % [truck != null, spawner != null, gunners.size()]):
		finish()
		return

	check(truck.driver != null and truck.driver == InputManager.player,
			"the player opens seated at the wheel", str(truck.driver))
	check(Globals.camera_follow.target == truck, "the camera follows the truck",
			str(Globals.camera_follow.target))
	for gunner in gunners:
		var body: Character = gunner.get_parent()
		var weapon: WeaponData = body.weapons.current_weapon if body.weapons else null
		check(weapon != null and weapon.is_ranged, "%s is armed" % body.name,
				weapon.name if weapon else "none")
		check(body.movement != null and not body.movement.enabled,
				"%s has locomotion off" % body.name, str(body.movement.enabled))
		check(body.global_position.y > truck.global_position.y + 1.5,
				"%s rides on top of the truck" % body.name, "%.2f" % body.global_position.y)
	await settle(5)
	for gunner in gunners:
		var model: WeaponRanged = gunner.weapons.weapon_model as WeaponRanged
		check(model != null and model.shielded.has(truck.get_rid()),
				"%s's rays skip the truck" % gunner.get_parent().name,
				str(model.shielded.size() if model else -1))

	# --- a drop beside the truck empties into the trunk
	var drop: LootDrop = (load("res://scenes/prototype/loot_drop.tscn") as PackedScene).instantiate()
	drop.storage = Inventory.new()
	drop.storage.setup(load("res://data/storage/body_pockets.tres"))
	var ammo: ItemData = load("res://data/items/ammo/ammo_light.tres")
	drop.storage.add(ammo, 5)
	ride.add_child(drop)
	drop.global_position = truck.global_position + Vector3(3.0, 0.0, 0.0)
	var before: int = truck.storage.count_of(ammo)
	await settle(150)
	check(truck.storage.count_of(ammo) == before + 5, "a nearby drop is pulled into the trunk",
			"%d -> %d rounds" % [before, truck.storage.count_of(ammo)])
	check(not is_instance_valid(drop), "and the emptied drop is gone", str(is_instance_valid(drop)))

	# --- drive into the raiders and let the crew work
	var crew: Array = gunners.map(func(g): return g.get_parent())
	Signals.noise_emitted.connect(func(_p, _r, p_source): if crew.has(p_source): crew_shots += 1)
	Input.action_press("car_accelerate")
	var spawned: int = 0
	for i in RUN_FRAMES:
		await get_tree().process_frame
		if i == DRIVE_FRAMES:
			Input.action_release("car_accelerate")
		spawned = maxi(spawned, spawner.alive.size())
		if i % 600 == 599:
			print("DBG t=%ds alive=%d kills=%d shots=%d truck_hp=%d speed=%.1f" % [
					(i + 1) / 60, spawner.alive.size(), spawner.kills, crew_shots,
					truck.health, truck.speed])
	Input.action_release("car_accelerate")
	check(spawned > 0, "raiders spawn around the truck", "%d alive at peak" % spawned)
	check(crew_shots > 0, "the crew fires on its own", "%d shots" % crew_shots)
	check(spawner.kills > 0, "raiders die", "%d kills" % spawner.kills)
	var drops: int = 0
	for child in spawner.get_children():
		if child is LootDrop:
			drops += 1
	check(drops > 0 or truck.storage.entries.size() > 1, "kills leave loot",
			"%d drops on the ground, %d stacks in the trunk" % [drops, truck.storage.entries.size()])
	check(not truck.is_destroyed, "the truck survives the first minute", "%d hp" % truck.health)
	finish()
