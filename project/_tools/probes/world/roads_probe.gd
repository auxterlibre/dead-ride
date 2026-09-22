extends ProbeBase
# DBG probe: the spline road network - graph, junctions, routing and the
# forecourt spots the pump and the delivery bay resolve to.

const ERRAND_BUDGET: float = 120.0  # sec of wall clock for one customer errand

@onready var GAME: PackedScene = load("uid://b56i3a2diovj6")  # scenes/game.tscn

var customer_ai: VehicleAI
var pump_node: GasPump
var elapsed: float = 0.0
var served: bool = false
var last_state: String = ""


func _ready():
	set_physics_process(false)
	var game: Node = GAME.instantiate()
	add_child(game)
	for i in 4:
		await get_tree().process_frame

	var roads: RoadNetwork = game.find_child("Roads", true, false)
	check(Globals.road_network == roads, "the network registered itself",
			str(Globals.road_network))
	print("DBG %d graph points over %d paths, %d mesh surfaces"
			% [roads.astar.get_point_count(), roads.paths().size(),
			roads.surface.mesh.get_surface_count() if roads.surface.mesh else 0])

	var ends: Array[Vector3] = roads.entry_points()
	check(ends.size() == 2, "exactly two ways on and off the map",
			str(ends.map(func(p): return p.round())))
	if ends.size() < 2:
		finish()
		return

	# One route end to end proves the spur really welded onto the highway.
	var path: PackedVector3Array = roads.route(ends[0], ends[1])
	var length: float = 0.0
	for i in range(path.size() - 1):
		length += path[i].distance_to(path[i + 1])
	check(path.size() > 2, "a route crosses the whole network",
			"%d waypoints, %.0fm" % [path.size(), length])

	var pump: GasPump = find_first(game, "GasPump")
	var lane: Vector3 = roads.nearest_center(pump.global_position)
	check(lane.distance_to(pump.global_position) < 12.0,
			"the forecourt lane runs past the pump",
			"nearest tarmac %.1fm away at %s" % [
			lane.distance_to(pump.global_position), lane.round()])

	var bay: Area3D = game.find_child("DeliveryArea", true, false)
	check(roads.nearest_center(bay.global_position).distance_to(
			bay.global_position) < 15.0, "and past the delivery bay",
			"%.1fm off the tarmac" % roads.nearest_center(
			bay.global_position).distance_to(bay.global_position))

	# Where a customer will actually stop, and whether the pump can serve it there.
	var car: Vehicle = game.find_child("Car", true, false)
	var ai: VehicleAI = null
	var spawner: TrafficSpawner = game.find_child("TrafficSpawner", true, false)
	var customer: Vehicle = spawner.spawn()
	if customer:
		for child in customer.get_children():
			if child is VehicleAI:
				ai = child
	if ai:
		var stop: Vector3 = ai.pump_stop()
		print("DBG customer stop %s, %.1fm from the pump" % [stop.round(),
				stop.distance_to(pump.global_position)])
		check(stop.distance_to(pump.global_position) <= GasPump.SERVICE_RANGE,
				"the parking spot is inside the pump's service range",
				"%.1fm vs %.1fm" % [stop.distance_to(pump.global_position),
				GasPump.SERVICE_RANGE])
	check(car != null, "the player's car is off the tarmac",
			"%.1fm from the nearest lane"
			% roads.nearest_center(car.global_position).distance_to(car.global_position))

	# The delivery truck rolls in at 08:00 too; clear it so this measures the
	# customer errand alone rather than a two-car forecourt.
	var service: DeliveryService = find_first(game, "DeliveryService")
	service.truck_scene = null
	if service.truck:
		service.truck.queue_free()
		service.truck = null

	# The errand end to end: pull in, fill up, pay, leave.
	customer_ai = ai
	pump_node = pump
	PlayerData.current_money = 0
	set_physics_process(true)


func _physics_process(p_delta: float):
	elapsed += p_delta
	# The AI node is freed WITH its vehicle, so validity comes before any read.
	if not is_instance_valid(customer_ai) or not is_instance_valid(customer_ai.vehicle) \
			or customer_ai.vehicle.is_queued_for_deletion():
		check(served, "a customer completed the errand",
				"reached the pump: %s, paid $%d, %.0fs" % [served,
				PlayerData.current_money, elapsed])
		finish()
		return
	var state: String = customer_ai.state_machine.current_state_name
	if state != last_state:
		print("DBG customer %s -> %s at %s (t=%.0fs)" % [last_state, state,
				customer_ai.vehicle.global_position.round(), elapsed])
		last_state = state
	if state == VehicleAI.REFUEL and not served:
		served = true
		check(true, "a customer reached the pump", "after %.0fs, %.1fm away"
				% [elapsed, customer_ai.vehicle.global_position.distance_to(
				pump_node.global_position)])
	if elapsed > ERRAND_BUDGET:
		check(false, "the errand finished inside the budget",
				"stuck in %s at %s" % [state,
				customer_ai.vehicle.global_position.round()])
		finish()
