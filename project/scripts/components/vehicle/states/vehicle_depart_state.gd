class_name VehicleDepartState
extends StateInterface


func enter(_msg: Dictionary = {}):
	if not actor.steering.drive_to(actor.exit_position):
		actor.finish()


func physics_update(_delta: float):
	if not actor.steering.driving:
		actor.finish()  # arrived or wedged; either way it is done with the stop
