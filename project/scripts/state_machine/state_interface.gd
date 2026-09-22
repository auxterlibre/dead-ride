@abstract
class_name StateInterface
# Non-node state base (Melee Arena pattern): states are plain objects registered
# on a StateMachine via add_state(), not scene children.

var state_machine:StateMachine = null
var actor:Variant


func enter(_msg:Dictionary = {}):
	pass


func update(_delta:float):
	pass


func physics_update(_delta:float):
	pass


func exit():
	pass


func change_to(p_target_state_name:String, p_msg:Dictionary = {}):
	state_machine.change_state_to(p_target_state_name, p_msg)
