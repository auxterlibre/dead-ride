class_name PlayerEnergy
extends Node
# The survival battery: walking sips it, sprinting gulps it, standing still
# spends nothing. Empty is EXHAUSTED - no sprint and heavy-legged walking,
# never damage; the desert's heat will do that job, not tiredness.

const EXHAUSTED_PACE: float = 0.7  # fatigue_scale while running on empty
const LOW_SHARE: float = 0.2
const LOW_REARM_SHARE: float = 0.3

@export var movement: CharacterMovement
@export var max_energy: float = 100.0
@export var walk_drain: float = 0.35  # per second at a full walk
@export var sprint_drain: float = 2.2  # per second at a full sprint
# Sprint comes back at this level, not at the first sip - a hysteresis, so the
# sprint key doesn't flutter on and off around the empty mark.
@export var recover_threshold: float = 10.0

var current: float
var low_warned: bool = false

@onready var body: CharacterBody3D = get_parent()


func _ready():
	current = max_energy
	push_state.call_deferred()  # after the HUD's _ready has hooked the signal


func _physics_process(p_delta: float):
	if movement == null or movement.corpse:
		return
	var pace: float = movement.current_pace()
	if pace < 0.05:
		return  # standing still is free
	var drain: float = sprint_drain if movement.is_sprinting else walk_drain
	spend(drain * pace * p_delta)


func spend(p_amount: float):
	if p_amount > 0.0:
		set_energy(current - p_amount)


func restore(p_amount: float):
	if p_amount > 0.0:
		set_energy(current + p_amount)


func set_energy(p_value: float):
	var before: float = current
	current = clampf(p_value, 0.0, max_energy)
	if not is_equal_approx(before, current):
		push_state()
		warn_if_low()
	if movement == null:
		return
	if current <= 0.0:
		movement.sprint_allowed = false
		movement.fatigue_scale = EXHAUSTED_PACE
	elif current >= recover_threshold:
		movement.sprint_allowed = true
		movement.fatigue_scale = 1.0


func warn_if_low():
	if body == null or not body.is_in_group("player"):
		return
	var share: float = current / max_energy if max_energy > 0.0 else 0.0
	if not low_warned and share <= LOW_SHARE:
		low_warned = true
		Signals.notification_requested.emit("STAMINA LOW", Enums.MessageType.NEGATIVE)
	elif low_warned and share >= LOW_REARM_SHARE:
		low_warned = false


func is_full() -> bool:
	return current >= max_energy


func push_state():
	if body and body.is_in_group("player"):
		Signals.energy_updated.emit(current, max_energy)
