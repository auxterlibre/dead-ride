extends ProbeBase
# DBG probe: the delivery truck's day - sent at 08:00, drives to the bay,
# trades, restocks the pump, and leaves when the clock reaches its hour.

const DRIVE_BUDGET: float = 90.0  # sec of wall clock to reach the bay
const LEAVE_BUDGET: float = 90.0  # ...and to get back off the map

@onready var GAME: PackedScene = load("uid://b56i3a2diovj6")  # scenes/game.tscn

var service: DeliveryService
var ai: DeliveryAI
var watching: String = ""  # which leg the physics tick is timing
var elapsed: float = 0.0
var reported: float = 0.0
var pump_node: GasPump
var pump_ticks: int = 0  # physics ticks the chassis spent touching the pump
var closest_pump: float = INF
var scraped: Dictionary = {}  # collider name -> ticks in contact, this leg


func _ready():
	set_physics_process(false)  # nothing to watch until the truck resolves
	var game: Node = GAME.instantiate()
	add_child(game)
	for i in 8:  # autoloads, _ready and the deferred first calendar tick
		await get_tree().process_frame

	# The probe's player stands exposed through the whole scorch window; his
	# death would pause the tree under the departing truck and freeze the run.
	InputManager.player.heat.burn_per_second = 0.0
	service = find_first(game, "DeliveryService")
	pump_node = find_first(game, "GasPump")
	check(service.truck != null, "the 08:00 tick sent a truck", str(service.truck))
	if service.truck == null:
		finish()
		return
	for child in service.truck.get_children():
		if child is DeliveryAI:
			ai = child
	check(ai != null and ai.state_machine.current_state_name == DeliveryAI.ARRIVE,
			"it starts out driving in", ai.state_machine.current_state_name)
	print("DBG start %.1fm from the bay"
			% service.truck.global_position.distance_to(ai.bay_position()))
	watch("arrive")


func _physics_process(p_delta: float):
	elapsed += p_delta
	watch_the_pump()
	if watching == "arrive":
		watch_arrival()
	else:
		watch_departure()


# Every tick, not the 10s progress prints - a grind can live between them.
func watch_the_pump():
	if service.truck == null:
		return
	closest_pump = minf(closest_pump,
			service.truck.global_position.distance_to(pump_node.global_position))
	if service.truck.get_contact_count() == 0:
		return
	for body in service.truck.get_colliding_bodies():
		scraped[body.name] = scraped.get(body.name, 0) + 1
		if body == pump_node:
			pump_ticks += 1


func clearance_report() -> String:
	return "closest %.1fm, %d ticks on the pump%s" % [closest_pump, pump_ticks,
			"" if scraped.is_empty() else ", scraped " + str(scraped)]


func watch_arrival():
	if ai.state_machine.current_state_name == DeliveryAI.PARK:
		set_physics_process(false)
		check(true, "it parked", "after %.0fs, %.1fm from the bay centre"
				% [elapsed, service.truck.global_position.distance_to(ai.bay_position())])
		check(pump_ticks == 0, "the drive in never grinds the pump", clearance_report())
		test_shop()
		return
	progress("driving in")
	if elapsed > DRIVE_BUDGET:
		set_physics_process(false)
		check(false, "it reached the bay inside the budget", "gave up %.1fm short"
				% service.truck.global_position.distance_to(ai.bay_position()))
		finish()


func watch_departure():
	if service.truck == null:
		set_physics_process(false)
		check(true, "it drove off the map and was reclaimed", "after %.0fs" % elapsed)
		check(pump_ticks == 0, "the drive out never grinds the pump either",
				clearance_report())
		test_the_window()
		return
	progress("driving out")
	if elapsed > LEAVE_BUDGET:
		check(false, "it left inside the budget",
				"still at %s" % service.truck.global_position.round())
		finish()


func test_shop():
	check(ai.trade_area.enabled, "the trade point is open", ai.trade_area.action_label)
	var areas: Array[Node] = service.truck.find_children("*", "InteractiveArea", true, false)
	check(areas.size() == 1 and areas[0].callback == "open_menu",
			"one point carries the whole shop", "%d areas" % areas.size())

	# Sell: goods STAY on the counter, so a wrong item can be dragged back out.
	var revolver: ItemData = load("res://data/items/weapons/ranged/revolver.tres")
	PlayerData.current_money = 0
	ai.goods.add(revolver, 1)
	await get_tree().process_frame
	check(PlayerData.current_money == 0 and ai.goods.entries.size() == 1,
			"goods dropped on the counter stay put",
			"$%d, %d left" % [PlayerData.current_money, ai.goods.entries.size()])

	# And taking it back before closing time costs nothing.
	ai.goods.remove(ai.goods.entries[0])
	ai.goods.add(revolver, 1)
	await get_tree().process_frame
	check(PlayerData.current_money == 0 and ai.goods.entries.size() == 1,
			"reclaiming and re-dropping still pays nothing yet",
			"$%d, %d left" % [PlayerData.current_money, ai.goods.entries.size()])

	# Restock: whole liters, never more than the purse covers.
	var pump: GasPump = ai.nearest_pump()
	pump.data.current_stock = 0.0
	PlayerData.current_money = 501
	check(ai.restock_label().begins_with("Buy "), "the menu quotes the fuel deal",
			ai.restock_label())
	var expected: float = ai.affordable_liters(pump)
	ai.restock_pump()
	check(is_equal_approx(pump.data.current_stock, expected)
			and PlayerData.current_money >= 0,
			"it sells fuel to the pump", "%.0fL for $%d left"
			% [pump.data.current_stock, PlayerData.current_money])

	# Closing time: the clock, not a timer, is what sends it home - and it is
	# JUMPED here, not landed on, because a scrub straight over 15:00 is what
	# left the truck standing at the bay for the rest of the day.
	var purse: int = PlayerData.current_money
	Calendar.set_time(service.leave_hour + 1, 0)
	await get_tree().process_frame
	await get_tree().process_frame
	check(ai.state_machine.current_state_name == DeliveryAI.DEPART
			and not ai.trade_area.enabled, "a clock jumped PAST 15:00 still sends it off",
			"%02d:00 -> %s" % [Calendar.time_data.hour,
			ai.state_machine.current_state_name])
	check(PlayerData.current_money == purse + revolver.price
			and ai.goods.entries.is_empty(), "and pays for the counter on its way out",
			"$%d -> $%d, %d left" % [purse, PlayerData.current_money,
			ai.goods.entries.size()])
	watch("leave")


# The service's half of the same trap, on a clock now past closing time: an
# `hour ==` gate silently skips a whole day's delivery when the clock jumps.
func test_the_window():
	await settle(4)  # the reclaimed truck leaves the vehicle group deferred
	service.last_delivery = Vector3i(-1, -1, -1)
	service.on_calendar_updated(Calendar.time_data)
	check(service.truck == null
			and service.last_delivery == Calendar.get_current_date(),
			"a day whose whole window was jumped banks itself and sends nothing",
			"%02d:00, truck %s, served %s" % [Calendar.time_data.hour,
			service.truck, service.last_delivery])

	Calendar.set_time(service.arrive_hour + 1, 0)  # rewind rolls to tomorrow
	await settle(2)
	check(service.truck != null, "but a jump past 08:00 INSIDE it still sends one",
			"%02d:00 -> %s" % [Calendar.time_data.hour, service.truck])
	if service.truck == null:
		finish()
		return

	# Sleeping at the counter is the other way past closing time: the hour comes
	# back round tomorrow, so only the DATE can tell an open visit from a stale one.
	var second: DeliveryAI = find_first(service.truck, "DeliveryAI")
	var visit: Vector3i = second.leave_date
	Calendar.set_time(service.arrive_hour, 0)  # a rewind: tomorrow, 08:00, a day late
	check(second.time_to_leave(), "a visit whose date rolled over is overdue, not open",
			"visit %s, now %02d:00 %s" % [visit, Calendar.time_data.hour,
			Calendar.get_current_date()])
	service.reclaim(service.truck)
	finish()


func watch(p_leg: String):
	watching = p_leg
	elapsed = 0.0
	reported = 0.0
	pump_ticks = 0
	closest_pump = INF
	scraped = {}
	set_physics_process(true)


func progress(p_label: String):
	if elapsed - reported < 10.0:
		return
	reported = elapsed
	var contact: int = 0
	for wheel in service.truck.wheels:
		contact += 1 if wheel.is_in_contact() else 0
	# A chassis contact is what a wedged vehicle looks like, so name what it hit.
	if service.truck.get_contact_count() > 0:
		print("DBG touching %s" % str(service.truck.get_colliding_bodies()
				.map(func(b): return b.name)))
	print("DBG %s t=%.0fs at %s v=%.1f throttle=%.2f wheels=%d/%d wp=%d/%d"
			% [p_label, elapsed, service.truck.global_position.round(),
			service.truck.speed, service.truck.control_throttle, contact,
			service.truck.wheels.size(), ai.steering.index,
			ai.steering.waypoints.size()])
