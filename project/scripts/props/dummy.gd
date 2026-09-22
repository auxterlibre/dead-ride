class_name Dummy
extends Node3D

const IMPULSE_PER_KNOCKBACK:float = 1.2  # rad/s of tilt per knockback unit
const STIFFNESS:float = 80.0
const DAMPING:float = 5.0
const MAX_ANGLE:float = 0.45  # rad, hard cap on the lean

var wobble:Vector3 = Vector3.ZERO
var wobble_velocity:Vector3 = Vector3.ZERO

@onready var base:Node3D = $Base


func take_damage(p_attack:AttackData):
	var away:Vector3 = global_position - p_attack.knockback_origin
	away.y = 0.0
	if away.length_squared() < 0.001:
		return
	var axis:Vector3 = Vector3.UP.cross(away.normalized())
	wobble_velocity += axis * p_attack.knockback_distance * IMPULSE_PER_KNOCKBACK


func _physics_process(p_delta):
	if wobble.is_zero_approx() and wobble_velocity.is_zero_approx():
		return
	wobble_velocity += (-STIFFNESS * wobble - DAMPING * wobble_velocity) * p_delta
	wobble += wobble_velocity * p_delta
	wobble = wobble.limit_length(MAX_ANGLE)
	base.rotation = wobble
