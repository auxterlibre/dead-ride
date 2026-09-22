class_name VehicleRefuelState
extends StateInterface

var remaining: float = 0.0


func enter(_msg: Dictionary = {}):
	actor.steering.stop()
	remaining = actor.fill_seconds


func physics_update(p_delta: float):
	remaining -= p_delta
	if remaining > 0.0:
		return
	actor.buy_fuel()
	change_to(VehicleAI.DEPART)
