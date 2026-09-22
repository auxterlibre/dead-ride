class_name DeliveryArriveState
extends StateInterface

const RETRY_WAIT: float = 4.0  # sec standing before asking for the route again
const RETRIES: int = 3  # the truck has all day, and forecourt jams clear

var retries_left: int = 0
var retry_timer: float = 0.0


func enter(_msg: Dictionary = {}):
	retries_left = RETRIES
	retry_timer = 0.0
	if not actor.steering.drive_to(actor.bay_position(), true, approach()):
		actor.finish()  # no road to drive: nothing this truck can do here


func physics_update(p_delta: float):
	if actor.at_bay():
		change_to(DeliveryAI.PARK)
		return
	if actor.steering.driving:
		return
	if actor.steering.gave_up and retries_left > 0:
		retry_timer += p_delta
		if retry_timer >= RETRY_WAIT:
			retry_timer = 0.0
			retries_left -= 1
			actor.steering.drive_to(actor.bay_position(), true, approach())
		return
	# Out of patience: trade from wherever it stopped rather than turn round -
	# the player can still walk to it.
	change_to(DeliveryAI.PARK)


func approach() -> PackedVector3Array:
	return actor.approach_points()
