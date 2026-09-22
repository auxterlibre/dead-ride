class_name StateMachine
extends Node
# Code-driven state machine (Melee Arena pattern). Created by the actor in
# _ready(); states are registered with add_state() and hold no scene nodes.

signal state_changed(state_name)

var states:Dictionary = {}
var actor:Variant
var current_state:StateInterface
var current_state_name:String


func _process(p_delta):
	if not current_state: return
	current_state.update(p_delta)


func _physics_process(p_delta):
	if not current_state: return
	current_state.physics_update(p_delta)


func change_state_to(p_target_state_name:String, p_msg:Dictionary = {}):
	if not states.has(p_target_state_name):
		push_warning("State does not exist: %s" % p_target_state_name)
		return
	if current_state_name == p_target_state_name:
		return

	if current_state: current_state.exit()
	current_state = states[p_target_state_name]
	current_state_name = p_target_state_name
	current_state.enter(p_msg)
	state_changed.emit(current_state_name)


func add_state(p_name:String, p_state:StateInterface) -> void:
	states[p_name] = p_state
	p_state.state_machine = self
	p_state.actor = actor
