class_name InteractiveArea
extends Node3D

signal noticed  # the player came within notice range; owners recompute `enabled`

enum Stage { OFF, HINT, PROMPT }

const KEEP_ANGLE_BONUS: float = 30.0  # deg past acquire before a shown prompt drops
const KEEP_RANGE_BONUS: float = 0.6  # m likewise - hysteresis against flicker
const ON_TOP_RANGE: float = 0.2  # standing on the point counts as facing it

static var offers: Array[InteractiveArea] = []  # walked by PlayerInteractions

@export var target_object: Node
@export var callback: String
@export var action_label: String
@export var audio: AudioStreamPlayer3D
@export var input_action: String = "interact"  # one key per offer in range
@export var hold: bool = false  # run every frame the key is down, not once
@export var prompt_range: float = 2.2  # m within which the offer can be TAKEN
@export var prompt_angle: float = 55.0  # deg off the rig's forward to acquire it
# Conditional offers gate on this (the car offers REPAIR only while damaged).
@export var enabled: bool = true : set = set_enabled

var player_near: bool = false : set = set_player_near  # the sweep sets it
var stage: Stage = Stage.OFF
var spent: bool = false  # the offer has already been taken - a searched crate


func _ready():
	# Defaults to the owner; an exported Node needs a node_paths header to deserialise.
	if target_object == null:
		target_object = get_parent()
	offers.append(self)


func _exit_tree():
	offers.erase(self)
	retract()


func set_enabled(p_value: bool):
	if enabled == p_value:
		return
	enabled = p_value
	if is_node_ready():
		update_stage()


func set_player_near(p_value: bool):
	if player_near == p_value:
		return
	player_near = p_value
	if player_near:
		noticed.emit()


# Re-advertise after a label change; a shown prompt is re-pushed either way.
func refresh():
	update_stage(true)


# The dot rides HINT and PROMPT alike, so it is only added and removed at OFF.
func update_stage(p_force: bool = false):
	var next: Stage = eligible_stage()
	if next == stage and not p_force:
		return
	if stage == Stage.PROMPT and next != Stage.PROMPT:
		InputManager.remove_interaction(target_object, callback)
	if next == Stage.PROMPT:
		InputManager.create_interaction(target_object, callback, action_label,
				audio, input_action, hold)
	if next == Stage.OFF and stage != Stage.OFF:
		Signals.interaction_hint_removed.emit(self)
	elif next != Stage.OFF and stage == Stage.OFF:
		Signals.interaction_hint_added.emit(self)
	stage = next


func eligible_stage() -> Stage:
	if not enabled or not player_near:
		return Stage.OFF
	# A held pour must not drop mid-stream because the rig drifted.
	if stage == Stage.PROMPT and hold and Input.is_action_pressed(input_action):
		return Stage.PROMPT
	var player: Character = InputManager.player
	if not is_instance_valid(player):
		return Stage.OFF
	var keeping: bool = stage == Stage.PROMPT
	var reach: float = prompt_range + (KEEP_RANGE_BONUS if keeping else 0.0)
	var cone: float = prompt_angle + (KEEP_ANGLE_BONUS if keeping else 0.0)
	var to_point: Vector3 = global_position - player.global_position
	to_point.y = 0.0
	if to_point.length() > reach:
		return Stage.HINT
	if to_point.length() > ON_TOP_RANGE:
		var forward: Vector3 = player.body_container.global_basis.z
		forward.y = 0.0
		if forward.normalized().dot(to_point.normalized()) \
				< cos(deg_to_rad(cone)):
			return Stage.HINT
	return Stage.PROMPT


func retract():
	if stage == Stage.PROMPT:
		InputManager.remove_interaction(target_object, callback)
	if stage != Stage.OFF:
		Signals.interaction_hint_removed.emit(self)
	stage = Stage.OFF
