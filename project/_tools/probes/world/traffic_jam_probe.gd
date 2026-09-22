extends ProbeBase
# DBG probe: the forecourt at its worst - the 08:00 truck inbound plus two
# customers forced in on top of it (the exact case that used to wedge). The
# yield sensor has to get all three through: truck parked, both customers
# actually served at the pump, and nobody wrecked on the way.

const BUDGET: float = 150.0  # sec of wall clock for the whole jam to clear
const SPAWN_GAP: float = 4.0  # sec between forced customers, so they never
							  # land stacked on the same entry point

@onready var GAME: PackedScene = load("uid://b56i3a2diovj6")  # scenes/game.tscn

var service: DeliveryService
var delivery: DeliveryAI
var customers: Array = []  # {ai, vehicle, served, done} per forced car
var elapsed: float = 0.0
var reported: float = 0.0
var truck_parked: bool = false
var wrecked: bool = false
var pump_node: GasPump
var pump_ticks: Dictionary = {}  # vehicle name -> physics ticks touching the pump
var closest_pump: float = INF  # any AI vehicle's nearest pass


func _ready():
	set_physics_process(false)
	var game: Node = GAME.instantiate()
	add_child(game)
	for i in 8:  # autoloads, _ready and the deferred first calendar tick
		await get_tree().process_frame

	service = find_first(game, "DeliveryService")
	pump_node = find_first(game, "GasPump")
	check(service.truck != null, "the 08:00 tick sent a truck", str(service.truck))
	if service.truck == null:
		finish()
		return
	for child in service.truck.get_children():
		if child is DeliveryAI:
			delivery = child

	var spawner: TrafficSpawner = game.find_child("TrafficSpawner", true, false)
	check(spawner.delivery != null and spawner.delivery.truck_on_road(),
			"the spawner sees the truck on the road and would hold its timer",
			"wired" if spawner.delivery else "delivery unwired")
	await force_customer(spawner)
	await get_tree().create_timer(SPAWN_GAP).timeout
	await force_customer(spawner)
	check(customers.size() == 2, "two customers forced in on top of the truck",
			"%d on the road" % customers.size())
	set_physics_process(true)


# spawn() refuses while every entry is occupied (the truck just left one), so
# keep knocking until a way in clears.
func force_customer(p_spawner: TrafficSpawner):
	for attempt in 10:
		var car: Vehicle = p_spawner.spawn()
		if car != null:
			for child in car.get_children():
				if child is VehicleAI:
					customers.append({"ai": child, "vehicle": car,
							"served": false, "done": false})
			return
		await get_tree().create_timer(1.0).timeout


func _physics_process(p_delta: float):
	elapsed += p_delta
	watch_the_pump()
	if not truck_parked and delivery != null \
			and delivery.state_machine.current_state_name == DeliveryAI.PARK:
		truck_parked = true
		print("DBG truck parked after %.0fs" % elapsed)
	for entry in customers:
		if entry.done:
			continue
		if not is_instance_valid(entry.ai):
			entry.done = true  # errand finished and the spawner reclaimed it
			continue
		if is_instance_valid(entry.vehicle) and entry.vehicle.is_destroyed:
			wrecked = true
		if entry.ai.state_machine.current_state_name == VehicleAI.REFUEL:
			entry.served = true
	if wrecked:
		verdict("a vehicle was wrecked in the jam")
		return
	var all_done: bool = truck_parked and customers.all(
			func(entry): return entry.done)
	if all_done:
		verdict("jam cleared after %.0fs" % elapsed)
		return
	progress()
	if elapsed > BUDGET:
		verdict("budget spent")


# Chassis-on-pump contact, tracked every tick for every AI vehicle in play.
func watch_the_pump():
	for body in bodies_in_play():
		closest_pump = minf(closest_pump,
				body.global_position.distance_to(pump_node.global_position))
		if body.get_contact_count() == 0:
			continue
		for collider in body.get_colliding_bodies():
			if collider == pump_node:
				pump_ticks[body.name] = pump_ticks.get(body.name, 0) + 1


func bodies_in_play() -> Array:
	var bodies: Array = []
	if service.truck != null and is_instance_valid(service.truck):
		bodies.append(service.truck)
	for entry in customers:
		if is_instance_valid(entry.vehicle):
			bodies.append(entry.vehicle)
	return bodies


func verdict(p_note: String):
	set_physics_process(false)
	var served: int = 0
	for entry in customers:
		if entry.served:
			served += 1
	# State alone is not enough: the give-up fallback also "parks", and once
	# did so in the driving lane 14m out - the bay means the bay.
	var bay_gap: float = INF
	if service.truck != null and is_instance_valid(service.truck):
		bay_gap = service.truck.global_position.distance_to(delivery.bay_position())
	check(truck_parked and bay_gap < 6.0, "the truck reached its bay",
			"%s, %.1fm from the bay centre" % [p_note, bay_gap])
	check(served == customers.size(), "both customers were actually served",
			"%d of %d filled up" % [served, customers.size()])
	check(customers.all(func(entry): return entry.done),
			"and both left the map", p_note)
	check(not wrecked, "nobody got wrecked", p_note)
	check(pump_ticks.is_empty(), "nobody ground against the pump",
			"closest pass %.1fm%s" % [closest_pump,
			"" if pump_ticks.is_empty() else ", contact " + str(pump_ticks)])
	finish()


func progress():
	if elapsed - reported < 10.0:
		return
	reported = elapsed
	var spots: Array = []
	if service.truck != null and is_instance_valid(service.truck):
		spots.append("truck %s v=%.1f" % [service.truck.global_position.round(),
				service.truck.speed])
	for entry in customers:
		if is_instance_valid(entry.vehicle):
			spots.append("%s %s v=%.1f %s" % [entry.vehicle.name,
					entry.vehicle.global_position.round(), entry.vehicle.speed,
					entry.ai.state_machine.current_state_name \
					if is_instance_valid(entry.ai) else "-"])
	print("DBG t=%.0fs %s" % [elapsed, "; ".join(spots)])
