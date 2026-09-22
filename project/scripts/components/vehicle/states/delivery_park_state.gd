class_name DeliveryParkState
extends StateInterface


func enter(_msg: Dictionary = {}):
	actor.steering.stop()
	actor.open_shop()


func update(_delta: float):
	if actor.time_to_leave():
		change_to(DeliveryAI.DEPART)


func exit():
	actor.close_shop()
	actor.settle_sale()  # nothing left on the counter drives away unpaid
