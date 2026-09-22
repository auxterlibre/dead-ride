class_name DeliveryAI
extends Node

signal errand_finished(vehicle)  # the service reclaims the truck on this

const ARRIVE: String = "arrive"
const PARK: String = "park"
const DEPART: String = "depart"

@export var cargo: StorageData  # the sell counter's grid
@export var trade_area: InteractiveArea  # the ONE point; its press opens the menu

var vehicle: Vehicle
var steering: VehicleSteering
var state_machine: StateMachine
var bay: Area3D  # where the truck stands while it trades
var exit_position: Vector3
var leave_hour: int = 15
var leave_date: Vector3i  # the day this visit belongs to; a rolled date is overdue
var goods: Inventory = Inventory.new()


func _ready():
	vehicle = get_parent() as Vehicle
	for sibling in vehicle.get_children():
		if sibling is VehicleSteering:
			steering = sibling
	state_machine = StateMachine.new()
	state_machine.actor = self
	add_child(state_machine)
	state_machine.add_state(ARRIVE, DeliveryArriveState.new())
	state_machine.add_state(PARK, DeliveryParkState.new())
	state_machine.add_state(DEPART, DeliveryDepartState.new())
	if cargo:
		goods.setup(cargo)
	close_shop()


# Called by the service once the truck is placed.
func begin(p_bay: Area3D, p_exit: Vector3, p_leave_hour: int):
	bay = p_bay
	exit_position = p_exit
	leave_hour = p_leave_hour
	leave_date = Calendar.get_current_date()
	vehicle.start_engine(false)  # spawned rolling: no crank at the map edge
	state_machine.change_state_to(ARRIVE)


# The counter is only open while the truck is standing at the bay.
func open_shop():
	vehicle.stop_engine()
	trade_area.enabled = true


func close_shop():
	trade_area.enabled = false


# The single point's press: every action on one popup. Prices are computed at
# open - the menu pauses the tree, so nothing can move under a stale label.
func open_menu(_p_player = null):
	Signals.interaction_menu_requested.emit("Delivery Truck", [
		{"label": "Sell goods", "target": self, "callback": "open_trade"},
		{"label": restock_label(), "target": self, "callback": "restock_pump"},
	])


func restock_label() -> String:
	var pump: GasPump = nearest_pump()
	if pump == null:
		return "No pump to fill"
	if pump.data.current_stock >= pump.data.tank_size:
		return "Pump is full"
	var liters: float = affordable_liters(pump)
	if liters <= 0.0:
		return "Fuel: $%d/L - can't afford any" % pump.data.wholesale_price
	return "Buy %dL ($%d)" % [liters, roundi(liters * pump.data.wholesale_price)]


func open_trade(_p_player = null):
	if cargo == null:
		return
	Signals.container_opened.emit("Sell to the trucker", goods)



func settle_sale():
	var earned: int = 0
	for entry in goods.entries.duplicate():
		earned += entry.item.price * entry.count
		goods.remove(entry)
	if earned > 0:
		PlayerData.add_money(earned)


func restock_pump(_p_player = null):
	var pump: GasPump = nearest_pump()
	var liters: float = affordable_liters(pump)
	if liters > 0.0:
		pump.buy_stock(liters)


# Whole liters, and never a rounded cost the purse can't cover: buy_stock is
# all-or-nothing, so one cent over would buy nothing at all.
func affordable_liters(p_pump: GasPump) -> float:
	if p_pump == null or p_pump.data == null or p_pump.data.wholesale_price <= 0:
		return 0.0
	var liters: float = minf(p_pump.data.tank_size - p_pump.data.current_stock,
			floorf(float(PlayerData.current_money) / p_pump.data.wholesale_price))
	if roundi(liters * p_pump.data.wholesale_price) > PlayerData.current_money:
		liters -= 1.0
	return maxf(liters, 0.0)


func nearest_pump() -> GasPump:
	var closest: GasPump = null
	for node in get_tree().get_nodes_in_group("gas_pump"):
		if node is GasPump and (closest == null
				or node.global_position.distance_to(vehicle.global_position)
				< closest.global_position.distance_to(vehicle.global_position)):
			closest = node
	return closest


const BAY_RANGE: float = 1.5


func at_bay() -> bool:
	return bay != null and vehicle in bay.get_overlapping_bodies() \
			and vehicle.global_position.distance_to(bay.global_position) <= BAY_RANGE


func bay_position() -> Vector3:
	return bay.global_position if bay else vehicle.global_position


const APPROACH_DISTANCE: float = 4.0  # m of straight lead-in before the bay


func approach_points() -> PackedVector3Array:
	if bay == null:
		return PackedVector3Array()
	return PackedVector3Array([
		bay.global_position + bay.global_basis.z * APPROACH_DISTANCE])


# Past the hour, or simply a day late: sleeping at the counter rolls the date,
# and an hour test alone would hold the truck here into tomorrow.
func time_to_leave() -> bool:
	return Calendar.get_current_date() != leave_date or Calendar.past_hour(leave_hour)


func finish():
	errand_finished.emit(vehicle)
