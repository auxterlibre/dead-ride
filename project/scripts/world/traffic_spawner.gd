class_name TrafficSpawner
extends Node3D

@export var car_scenes: Array[PackedScene] = []
@export var interval: Vector2 = Vector2(20.0, 50.0)  # seconds between arrivals
@export var max_active: int = 2
@export var enabled: bool = true
@export var delivery: DeliveryService  # customers wait while its truck drives

var active: Array[Vehicle] = []
var countdown: float = 0.0


func _ready():
	countdown = randf_range(interval.x, interval.y)


func _process(p_delta: float):
	forget_dead_cars()
	if not enabled or car_scenes.is_empty():
		return
	countdown -= p_delta
	if countdown > 0.0:
		return
	countdown = randf_range(interval.x, interval.y)
	# The timer path only: F9 and probes force spawn() directly on purpose.
	if delivery and delivery.truck_on_road():
		return
	if active.size() < max_active:
		spawn()


# Returns the car so the F9 debug button can force one without waiting.
func spawn() -> Vehicle:
	var network: RoadNetwork = Globals.road_network
	var pump: GasPump = open_pump()
	if network == null or pump == null:
		return null
	var ends: Array[Vector3] = network.entry_points()
	if ends.size() < 2:
		return null  # a loop with no way in; nowhere to arrive from
	ends.shuffle()
	var start: int = network.clear_entry(ends, get_tree())
	if start < 0:
		return null  # every way in is occupied; the timer will try again
	var car: Vehicle = car_scenes.pick_random().instantiate()
	var ai: VehicleAI = null
	add_child(car)
	for child in car.get_children():
		if child is VehicleAI:
			ai = child
	if ai == null:
		car.queue_free()
		push_warning("Traffic car has no VehicleAI: %s" % car.name)
		return null
	car.global_transform = network.entry_transform(ends[start]).translated(Vector3.UP * 0.6)
	ai.errand_finished.connect(reclaim)
	ai.begin(pump, network.entry_transform(ends[(start + 1) % ends.size()]).origin)
	active.append(car)
	return car


func open_pump() -> GasPump:
	for node in get_tree().get_nodes_in_group("gas_pump"):
		if node is GasPump and node.available_gas() > 0.0:
			return node
	return null


func reclaim(p_vehicle: Vehicle):
	if is_instance_valid(p_vehicle):
		p_vehicle.queue_free()


# Rammed into a wreck or exploded: the car frees itself, so the slot has to
# come back without waiting for an errand that will never finish.
func forget_dead_cars():
	for i in range(active.size() - 1, -1, -1):
		if not is_instance_valid(active[i]) or active[i].is_queued_for_deletion():
			active.remove_at(i)
