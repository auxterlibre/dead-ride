class_name VehicleAI
extends Node

signal errand_finished(vehicle)  # the spawner reclaims the car on this

const ARRIVE: String = "arrive"
const REFUEL: String = "refuel"
const DEPART: String = "depart"
const PARK_DISTANCE: float = 3.5  # m from the pump a customer draws up at

@export var fill_seconds: float = 5.0  # time spent standing at the nozzle
@export var arrival_fuel: Vector2 = Vector2(0.1, 0.45)  # tank fraction on entry
@export var flee_cruise_speed: float = 13.0  # m/s down a straight, running
@export var flee_corner_speed: float = 5.5  # ...and through the sharpest turn

var vehicle: Vehicle
var steering: VehicleSteering
var state_machine: StateMachine
var pump: GasPump
var exit_position: Vector3
var fleeing: bool = false


func _ready():
	vehicle = get_parent() as Vehicle
	for sibling in vehicle.get_children():
		if sibling is VehicleSteering:
			steering = sibling
	state_machine = StateMachine.new()
	state_machine.actor = self
	add_child(state_machine)
	state_machine.add_state(ARRIVE, VehicleArriveState.new())
	state_machine.add_state(REFUEL, VehicleRefuelState.new())
	state_machine.add_state(DEPART, VehicleDepartState.new())
	vehicle.damaged.connect(on_damaged)


# Called by the spawner once the car is placed. Customers turn up with a tank
# worth filling, otherwise there is nothing to sell them.
func begin(p_pump: GasPump, p_exit: Vector3):
	pump = p_pump
	exit_position = p_exit
	vehicle.start_engine(false)  # spawned rolling: no crank at the map edge
	if vehicle.data:
		vehicle.data.current_fuel = vehicle.data.fuel_tank_size_value \
				* randf_range(arrival_fuel.x, arrival_fuel.y)
	state_machine.change_state_to(ARRIVE)


# Attacked: abandon the errand and run for the exit. Never pays, since
# buy_fuel() only runs when a fill runs out.
func on_damaged(p_attack: AttackData):
	# Its own crashes name itself as attacker; the spawn landing alone would
	# otherwise send every customer home before it parked.
	if p_attack != null and p_attack.attacker == vehicle:
		return
	if fleeing or vehicle.is_destroyed or state_machine.current_state == null:
		return
	fleeing = true
	steering.cruise_speed = flee_cruise_speed
	steering.corner_speed = flee_corner_speed
	state_machine.change_state_to(DEPART)


# The pump's own car sensor decides, final leg only; insisting on the cell centre grinds the nose in.
func at_pump() -> bool:
	return pump != null and steering.on_final_leg() and pump.can_serve(vehicle)


# Pulls OFF the lane toward the pump, the way a car actually parks at one.
# Stopping on the centreline would leave the far lane's cars out of the pump's
# reach once keep_right shifted them, and this is what a forecourt looks like.
func pump_stop() -> Vector3:
	if pump == null or Globals.road_network == null:
		return vehicle.global_position
	var lane: Vector3 = Globals.road_network.nearest_center(pump.global_position)
	var offset: Vector3 = lane - pump.global_position
	offset.y = 0.0
	if offset.length() < PARK_DISTANCE:
		return lane
	return pump.global_position + offset.normalized() * PARK_DISTANCE


# One transaction, not a per-frame trickle: the pump rounds each sale to whole
# dollars, so a tenth of a litre at a time would round the takings to nothing.
func buy_fuel():
	if pump == null or vehicle.data == null:
		return
	var liters: float = minf(
			vehicle.data.fuel_tank_size_value - vehicle.data.current_fuel,
			pump.available_gas())
	if liters <= 0.0:
		return  # closed or dry: a lost sale, and the car leaves as it came
	pump.sell_gas(liters)
	vehicle.refuel(liters)


func finish():
	errand_finished.emit(vehicle)
