extends ProbeBase
# DBG probe: a humanoid crew gunner aboard a vehicle lands every kit gun's barrel
# on a target straight ahead - the hand slot's grip turns the kit model onto the
# hand, and each weapon's aim_yaw_offset absorbs what its hold pose leaves.

const WEAPONS: PackedStringArray = ["pistol", "revolver", "smg", "shotgun", "assault_rifle", "sniper_rifle"]
const TOLERANCE: float = 3.0


func _ready():
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.collision_layer = 20
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	floor_shape.shape = BoxShape3D.new()
	floor_shape.shape.size = Vector3(200.0, 2.0, 200.0)
	floor_shape.position.y = -1.0
	floor_body.add_child(floor_shape)
	add_child(floor_body)
	var truck: Vehicle = (load("res://scenes/vehicles/vehicle_base.tscn") as PackedScene).instantiate()
	add_child(truck)
	truck.global_position = Vector3(0.0, 0.5, 0.0)
	var crew: Character = (load("res://scenes/characters/crew.tscn") as PackedScene).instantiate()
	truck.add_child(crew)
	crew.position = Vector3(0.0, 1.0, 0.0)
	var raider: Character = (load("res://scenes/characters/enemy.tscn") as PackedScene).instantiate()
	add_child(raider)
	raider.global_position = Vector3(0.0, 0.0, 15.0)
	await settle(20)
	var gunner: CrewGunner = crew.get_node("CrewGunner")
	check(gunner.vehicle == truck, "the gunner found the vehicle above it", str(gunner.vehicle))
	check(gunner.target == raider, "and picked the raider ahead as its target",
			gunner.target.name if gunner.target else "none")
	var weapons: EnemyWeapons = crew.weapons
	for name in WEAPONS:
		var data: WeaponData = (load("res://data/items/weapons/ranged/%s.tres" % name) as WeaponData).duplicate()
		weapons.set_weapons([data], 0)
		await settle(60)
		var to_target: Vector3 = raider.global_position - crew.global_position
		to_target.y = 0.0
		var error: float = rad_to_deg(weapons.barrel_error(to_target))
		check(absf(error) <= TOLERANCE, "%s lands its barrel on the target" % name, "%.1f deg off" % error)
	finish()
