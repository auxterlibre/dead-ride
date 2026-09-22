class_name PlayerHeat
extends Node

const CHECK_INTERVAL: float = 0.25  # the sky ray, on the dust-sample cadence
const COVER_MASK: int = 28  # walls | car | ground - whatever casts shade
const RAY_HEIGHT: float = 40.0  # how far up "the sky" starts

@export var burn_per_second: float = 1.0
@export var smoke: GPUParticles3D  # cooking off the player while the sun bites

var burning: bool = false : set = set_burning
var owed_damage: float = 0.0
var check_timer: float = 0.0
var pockets: Array = []  # cool zones stood in, broadphase-maintained

@onready var body: Character = get_parent()


func _physics_process(p_delta: float):
	check_timer -= p_delta
	if check_timer <= 0.0:
		check_timer = CHECK_INTERVAL
		burning = is_instance_valid(Globals.heat) and Globals.heat.is_scorching() \
				and not body.is_dead and not sheltered() and exposed()
	if not burning:
		owed_damage = 0.0
		return
	owed_damage += burn_per_second * p_delta
	if owed_damage >= 1.0:
		var dealt: int = floori(owed_damage)
		owed_damage -= dealt
		scorch(dealt)
		body.take_damage(AttackData.new(dealt, body.global_position, 0.0, null))


# The sun is nobody's hit box, so the burn raises the feedback a HurtBox hit
# would have given it - the number and the flash, but no spark or blood: the
# sky is not hitting anything, the smoke says where it hurts.
func scorch(p_damage: int):
	if body.hurt_box == null:
		return
	body.hurt_box.spawn_damage_label(p_damage)
	body.hurt_box.flash()


func enter_pocket(p_source):
	if not pockets.has(p_source):
		pockets.append(p_source)


func leave_pocket(p_source):
	pockets.erase(p_source)


# Re-checked live, not on entry - a barrel can run dry underfoot.
func sheltered() -> bool:
	for pocket in pockets:
		if is_instance_valid(pocket) and pocket.venting():
			return true
	return false


# Vertical on purpose: the scorch sun rides too high for angles to matter.
func exposed() -> bool:
	var from: Vector3 = body.global_position + Vector3.UP * 1.7
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			from, from + Vector3.UP * RAY_HEIGHT, COVER_MASK)
	return body.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func set_burning(p_value: bool):
	if burning == p_value:
		return
	burning = p_value
	if smoke:
		smoke.emitting = burning
	if body.is_in_group("player"):
		Signals.heat_burning_changed.emit(burning)
		if burning:
			Signals.notification_requested.emit("SCORCHING SUN",
					Enums.MessageType.NEGATIVE)
