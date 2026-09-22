class_name DeliveryService
extends Node3D

@export var truck_scene: PackedScene
@export var bay: Area3D  # where it parks; move the node to move the delivery
@export var arrive_hour: int = 8
@export var leave_hour: int = 15

var truck: Vehicle
var last_delivery: Vector3i = Vector3i(-1, -1, -1)  # the date already served


func _ready():
	add_to_group("persistent")
	Signals.calendar_updated.connect(on_calendar_updated)


# The window is a SPAN, not two instants: a clock that jumps (scrub, sleep,
# load) over arrive_hour still owes the day its truck, and one that jumps the
# whole span owes nothing - but must bank the day, or it retries every minute.
func on_calendar_updated(_p_time: TimeData):
	if not Calendar.past_hour(arrive_hour) or last_delivery == Calendar.get_current_date():
		return
	if Calendar.past_hour(leave_hour):
		last_delivery = Calendar.get_current_date()
		return
	send_truck()


# Returns the truck so the F9 debug button can report what happened.
func send_truck() -> Vehicle:
	var network: RoadNetwork = Globals.road_network
	if truck_scene == null or bay == null or network == null or truck != null:
		return truck
	var ends: Array[Vector3] = network.entry_points()
	if ends.size() < 2:
		return null  # a loop with no way in; nowhere to arrive from
	ends.shuffle()
	var start: int = network.clear_entry(ends, get_tree())
	if start < 0:
		return null  # both ways in are occupied; the next minute retries,
					 # since last_delivery is only stamped on success
	truck = truck_scene.instantiate()
	var ai: DeliveryAI = null
	add_child(truck)
	for child in truck.get_children():
		if child is DeliveryAI:
			ai = child
	if ai == null:
		truck.queue_free()
		truck = null
		push_warning("Delivery truck has no DeliveryAI: %s" % truck_scene.resource_path)
		return null
	truck.global_transform = network.entry_transform(ends[start]).translated(Vector3.UP * 0.6)
	ai.errand_finished.connect(reclaim)
	ai.begin(bay, network.entry_transform(ends[(start + 1) % ends.size()]).origin, leave_hour)
	last_delivery = Calendar.get_current_date()
	return truck


func reclaim(p_vehicle: Vehicle):
	truck = null
	if is_instance_valid(p_vehicle):
		p_vehicle.queue_free()


# Only the date already served: a mid-visit truck is NOT saved - loading lands
# on a day that counts as delivered, with the truck itself gone.
func save_state() -> Dictionary:
	return {"last_delivery": [last_delivery.x, last_delivery.y, last_delivery.z]}


func load_state(p_state: Dictionary):
	last_delivery = Vector3i(int(p_state.last_delivery[0]),
			int(p_state.last_delivery[1]), int(p_state.last_delivery[2]))


# Somewhere between the map edge and the bay, or on the way out - parked and
# trading doesn't count. What the traffic spawner waits on.
func truck_on_road() -> bool:
	if truck == null or not is_instance_valid(truck):
		return false
	for child in truck.get_children():
		if child is DeliveryAI:
			return child.state_machine.current_state_name != DeliveryAI.PARK
	return false
