class_name DeliveryDepartState
extends StateInterface

# Long enough to reach the lane: the 180 the route then demands sweeps a ~6m
# arc, and turned down beside the bay that arc would reach the pump.
const BACK_OUT: float = 5.0  # sec of reversing before a route is asked for
const TIMEOUT: float = 60.0  # sec; boxed in by parked cars, it gives up and goes

var waited: float = 0.0
var routed: bool = false


func enter(_msg: Dictionary = {}):
	waited = 0.0
	routed = false
	actor.vehicle.start_engine()
	actor.steering.hold_for()  # crank first; the hold runs before the reverse
	# It parked nose-in; steering out of the bay would be a 180 in five metres.
	actor.steering.back_up(BACK_OUT)


func physics_update(p_delta: float):
	waited += p_delta
	if actor.steering.reversing > 0.0:
		return
	if not routed:
		routed = true
		if not actor.steering.drive_to(actor.exit_position):
			actor.finish()
		return
	# Grinding against a customer keeps the wedge watchdog fed, so it never
	# declares itself stuck - without a deadline the truck could still be here
	# blocking tomorrow's delivery.
	if not actor.steering.driving or waited > TIMEOUT:
		actor.finish()  # arrived, wedged or out of patience; done for the day
