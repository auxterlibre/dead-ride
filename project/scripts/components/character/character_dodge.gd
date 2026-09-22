class_name CharacterDodge
extends Node
# The evade every character can learn: a committed hop along the body's own
# intent, i-frames for as long as the clip runs, paid for in energy. Shared on
# purpose - the variants only decide WHEN (a key for the player, a brain for an
# enemy), never how far or how safe.

const CLIP_FORWARD:String = "dodge_forward"
const CLIP_BACKWARD:String = "dodge_backward"
const CLIP_LEFT:String = "dodge_left"
const CLIP_RIGHT:String = "dodge_right"

@export var movement:CharacterMovement
@export var animator:CharacterAnimator
@export var weapons:CharacterWeapons
# Null (an enemy today) makes dodging free, the same way a character without a
# pack reloads for free.
@export var energy:PlayerEnergy
@export var distance:float = 3.0  # m of travel, the clip's whole length
@export var cooldown:float = 1.2  # sec before the next one is offered
@export var energy_cost:float = 12.0

var window:float = -1.0  # sec of roll left; -1 = not dodging
var ready_in:float = 0.0  # sec of cooldown left

@onready var character:Character = get_parent() as Character


func _ready():
	if character:
		character.died.connect(finish)


func _process(p_delta:float):
	ready_in = maxf(ready_in - p_delta, 0.0)
	if window < 0.0:
		return
	window -= p_delta
	if window <= 0.0:
		finish()


func dodging() -> bool:
	return window >= 0.0


func can_dodge() -> bool:
	return not dodging() and ready_in <= 0.0 and movement != null \
			and movement.enabled and not movement.corpse \
			and (energy == null or energy.current >= energy_cost)


# The whole act. Returns whether it started, so a caller can keep its input.
func dodge() -> bool:
	if not can_dodge():
		return false
	var direction:Vector3 = dodge_direction()
	window = duration()
	ready_in = cooldown
	if energy:
		energy.spend(energy_cost)
	if weapons:
		weapons.cancel_reload()  # both hands are busy landing the roll
	movement.dash(direction, distance, window)
	if animator:
		animator.play_dodge(clip_for(direction))
		animator.upper_weight = 0.0  # the roll is the whole body; drop the aim pose
	if character and character.hurt_box:
		character.hurt_box.immune = true
	return true


# The clip is the authority on how long a dodge lasts - retiming the animation
# retimes the i-frames with it, and the travel is solved from the same number.
func duration() -> float:
	var length:float = animator.get_clip_length(CLIP_FORWARD) if animator else 0.0
	return length if length > 0.0 else 0.4


# Where the body already wanted to go. Standing still it hops BACKWARD off its
# own facing, which for a player aiming at something is away from the threat.
func dodge_direction() -> Vector3:
	var intent:Vector3 = movement.move_direction
	intent.y = 0.0
	if intent.length_squared() > 0.0001:
		return intent.normalized()
	return -facing().z


# Rig_Medium faces +Z and its right is -X, the same frame the animator blends
# locomotion in, so the four clips read the same way round as the walk cycles.
func clip_for(p_direction:Vector3) -> String:
	var basis:Basis = facing()
	var forward:float = p_direction.dot(basis.z)
	var right:float = p_direction.dot(-basis.x)
	if absf(forward) >= absf(right):
		return CLIP_FORWARD if forward > 0.0 else CLIP_BACKWARD
	return CLIP_RIGHT if right > 0.0 else CLIP_LEFT


func facing() -> Basis:
	if movement and movement.visual:
		return movement.visual.global_transform.basis
	return character.global_transform.basis if character else Basis.IDENTITY


# The roll is over (or death cut it short): the i-frames close and the hands go
# back to whatever they were holding. A corpse keeps neither.
func finish():
	window = -1.0
	if character == null:
		return
	if character.hurt_box:
		character.hurt_box.immune = false
	if character.is_dead:
		return
	# Only if the layer is still the roll's: a drink or a throw begun mid-roll
	# has claimed the arms for its own clip, and re-posing would cut it off.
	if weapons and animator and animator.upper_weight <= 0.0:
		weapons.apply_pose()
