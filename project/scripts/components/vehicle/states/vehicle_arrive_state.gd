class_name VehicleArriveState
extends StateInterface

const RETRY_WAIT: float = 4.0  # sec parked before asking for the route again
const RETRIES: int = 2  # a jammed forecourt usually clears; a wall never does

var retries_left: int = 0
var retry_timer: float = 0.0


func enter(_msg: Dictionary = {}):
	retries_left = RETRIES
	retry_timer = 0.0
	# Exact: the parking spot sits off the lane, beside the pump.
	if not actor.steering.drive_to(actor.pump_stop(), true):
		actor.finish()  # no road to drive: nothing this car can do here


func physics_update(p_delta: float):
	if actor.at_pump():
		change_to(VehicleAI.REFUEL)
		return
	if actor.steering.driving:
		return
	# Stopped short. A give-up with retries left sits out the jam and asks
	# again - the blocker is usually another customer mid-fill or the parked
	# truck, and both of those move. Only a give-up with none left departs,
	# so a car wedged on something permanent still leaves the forecourt free.
	if actor.steering.gave_up and retries_left > 0:
		retry_timer += p_delta
		if retry_timer >= RETRY_WAIT:
			retry_timer = 0.0
			retries_left -= 1
			actor.steering.drive_to(actor.pump_stop(), true)
		return
	change_to(VehicleAI.DEPART if actor.steering.gave_up else VehicleAI.REFUEL)
