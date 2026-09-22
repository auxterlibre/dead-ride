class_name GasPump
extends StaticBody3D

const SERVICE_RANGE: float = 4.0  # m from the pump a car can be filled at
const DRY_SHARE: float = 0.1  # tank share the ground tint fades out over

@export var data: GasPumpData

@onready var cool_shape: CollisionShape3D = $CoolArea/CollisionShape3D
@onready var refuel_area: InteractiveArea = $RefuelArea
@onready var can_area: InteractiveArea = $CanArea
@onready var service_area: InteractiveArea = $ServiceArea
@onready var car_area: Area3D = $CarArea
@onready var proximity_area: Area3D = $ProximityArea
@onready var gauge_label: Label3D = %AmountLabel



func _ready():
	add_to_group("persistent")
	if data == null:
		return
	add_to_group("chill_source")  # a tank of coolant damps the forecourt
	# Runtime copy: current_stock lives on the resource, and two pumps sharing
	# one .tres would otherwise share a tank (Vehicle does this for fuel).
	data = data.duplicate()
	data.current_stock = data.tank_size
	car_area.body_entered.connect(func(_p_body): refresh_offers())
	car_area.body_exited.connect(func(_p_body): refresh_offers())
	# `noticed` lands before the stage is judged, so the pack read is in time.
	can_area.noticed.connect(refresh_offers)
	proximity_area.body_entered.connect(on_proximity_changed)
	proximity_area.body_exited.connect(on_proximity_changed)
	refresh_offers()
	push_stock()


# The nozzle is only offered while a car is actually parked at the pump, and
# the can fill only while the pack holds a can with room and the tank stock -
# InteractiveArea.enabled exists for exactly this conditional advertising.
func refresh_offers():
	refuel_area.enabled = parked_car() != null
	can_area.enabled = data.current_stock > 0.0 and player_fuel_can() != null
	service_area.action_label = "Stop selling" if data.selling else "Start selling"
	service_area.refresh()


func on_proximity_changed(p_body):
	if not p_body.is_in_group("player"):
		return
	refresh_gauge()


# HELD callback: runs every frame the key is down, moving flow_rate liters per
# second out of the tank and into the car. The player's own fuel, so free.
func refuel_car(_p_player = null):
	var car: Vehicle = parked_car()
	if car == null or car.data == null:
		return
	var space: float = car.data.fuel_tank_size_value - car.data.current_fuel
	var liters: float = minf(data.flow_rate * get_process_delta_time(),
			minf(space, data.current_stock))
	if liters <= 0.0:
		return
	car.refuel(liters)
	data.current_stock -= liters
	push_stock()


# HELD twin of refuel_car for the jerry can in the pack: the player's own
# stock, so free. Tops off the first can with room; held longer, the scan
# simply moves on to the next one.
func fill_can(_p_player = null):
	var can: FuelCanData = player_fuel_can()
	if can == null:
		return
	var liters: float = minf(data.flow_rate * get_process_delta_time(),
			minf(can.space(), data.current_stock))
	if liters <= 0.0:
		return
	can.add_fuel(liters)
	data.current_stock -= liters
	push_stock()
	if can.space() <= 0.0 or data.current_stock <= 0.0:
		refresh_offers()  # topped off or ran the tank dry - re-aim or drop the offer


func player_fuel_can() -> FuelCanData:
	if InputManager.player == null or InputManager.player.carried == null:
		return null
	return first_can_with_room(InputManager.player.carried.inventory)


# Row-major like the grid itself: the top-left can with room is the one the
# nozzle fills.
func first_can_with_room(p_inventory: Inventory) -> FuelCanData:
	for entry in p_inventory.entries:
		var can: FuelCanData = entry.item as FuelCanData
		if can and can.space() > 0.0:
			return can
	return null


func toggle_selling(_p_player = null):
	data.selling = not data.selling
	refresh_offers()
	refresh_gauge()


# The CoolArea's delegate: a stocked tank vents the forecourt cool for free.
# No drain of its own - selling the fuel is the drain.
func venting() -> bool:
	return data != null and data.current_stock > 0.0 \
			and is_instance_valid(Globals.heat) and Globals.heat.is_scorching()


# The pocket's own reach, so the damp ground draws exactly where the cool is.
func chill_radius() -> float:
	return cool_shape.shape.radius


# Fades over the last of the tank: a forecourt drying out is the warning that
# a good day's selling has left nowhere safe to stand.
func chill_strength() -> float:
	return clampf(data.current_stock / maxf(data.tank_size * DRY_SHARE, 0.01),
			0.0, 1.0)


# What a customer could buy right now - they size their fill against this, so
# a closed or dry forecourt turns them away before they ever pull in.
func available_gas() -> float:
	return data.current_stock if data.selling else 0.0


# Customer-car seam. Returns what was earned; nothing while selling is off, so
# the toggle really does close the forecourt.
func sell_gas(p_liters: float) -> int:
	if not data.selling:
		return 0
	var sold: float = minf(p_liters, data.current_stock)
	if sold <= 0.0:
		return 0
	data.current_stock -= sold
	var earned: int = roundi(sold * data.pump_price)
	PlayerData.add_money(earned)
	push_stock()
	return earned


# Delivery-truck seam. All or nothing: a part-paid delivery would be worse to
# reason about than a refused one. Returns what it cost.
func buy_stock(p_liters: float) -> int:
	var bought: float = minf(p_liters, data.tank_size - data.current_stock)
	if bought <= 0.0:
		return 0
	var cost: int = roundi(bought * data.wholesale_price)
	if not PlayerData.spend_money(cost):
		return 0
	data.current_stock += bought
	push_stock()
	return cost


func has_car(p_vehicle: Vehicle) -> bool:
	return p_vehicle in car_area.get_overlapping_bodies()


# The CarArea says a car is there; the range stops one settling half a forecourt short.
func can_serve(p_vehicle: Vehicle) -> bool:
	return has_car(p_vehicle) \
			and p_vehicle.global_position.distance_to(global_position) <= SERVICE_RANGE


func parked_car() -> Vehicle:
	for body in car_area.get_overlapping_bodies():
		if body is Vehicle and not body.is_destroyed:
			return body
	return null


func has_player_near() -> bool:
	for body in proximity_area.get_overlapping_bodies():
		if body.is_in_group("player"):
			return true
	return false


func push_stock():
	Signals.pump_stock_changed.emit(data.current_stock, data.tank_size)
	refresh_gauge()


func refresh_gauge():
	if not is_node_ready():
		return
	if data.selling:
		gauge_label.text = "%0.2f" % data.current_stock
	else:
		gauge_label.text = "CLOSED"



func save_state() -> Dictionary:
	return {"stock": data.current_stock, "selling": data.selling}


func load_state(p_state: Dictionary):
	data.current_stock = float(p_state.stock)
	data.selling = bool(p_state.selling)
	push_stock()
