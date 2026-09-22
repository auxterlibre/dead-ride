class_name EnemyWeapons
extends CharacterWeapons
# AI trigger over CharacterWeapons: accuracy cone, auto-reload, first-shot miss, bursts.

const AWARE_ANGLE:float = 120.0  # full cone: target roughly facing us = they saw us
const MISS_MARGIN:float = 1.0  # m off-body a guaranteed miss passes by
const FIRE_HEIGHT:Vector2 = Vector2(0.8, 1.6)  # chest band over the body origin

@export var spread_factor:float = 0.4  # fraction of the accuracy cone AI shots use
@export var move_penalty:float = 0.5  # extra spread at full pace - shooting on the run
@export var fire_pause:float = 0.6  # min seconds between non-automatic AI shots
@export var recoil_factor:float = 0.25  # fraction of weapon recoil the AI accumulates
@export var burst_release:float = 0.6  # accuracy lost that releases an automatic trigger
@export var burst_resume:float = 0.15  # recovered enough to squeeze again

var miss_pending:bool = false
var bursting:bool = false

@onready var character:Character = get_parent()


# Armed by EnemyAI when an engagement starts from a non-combat state.
func begin_engagement():
	miss_pending = true


# Getting hit rattles the aim: bloom spikes (wider spread, burst released)
# and the trigger holds a beat.
func stagger():
	bloom = minf(bloom + 0.5, 1.0)
	bursting = false
	fire_cooldown = maxf(fire_cooldown, 0.35)


const MELEE_FACING:float = 40.0  # deg off-target a swing still starts


func fire_at(p_target):
	if current_weapon != null and not current_weapon.is_ranged:
		# Swings only start in reach: chase's advancing fire calls this on a
		# timer too, and fists have no suppressive range to make noise at.
		var gap:Vector3 = p_target.global_position - body.global_position
		gap.y = 0.0
		if can_strike() and gap.length() <= STRIKE_REACH:
			strike(p_target)
		return
	if not can_fire():
		return
	if current_weapon.current_ammo <= 0:
		bursting = false
		reload()
		return
	var automatic:bool = current_weapon.fire_mode == Enums.FireMode.AUTOMATIC
	if automatic and not burst_ready():
		return
	var warning:bool = miss_pending
	miss_pending = false  # spent even vs an aware target - no free miss later
	warning = warning and not is_aware_of_us(p_target)
	var ranged:WeaponRanged = weapon_model as WeaponRanged
	var from:Vector3 = body.global_position
	from.y += clampf(ranged.projectile_spawn.global_position.y \
			- body.global_position.y, FIRE_HEIGHT.x, FIRE_HEIGHT.y)
	var to_target:Vector3 = p_target.global_position - from
	to_target.y = 0.0
	var deviation:float = miss_deviation(to_target.length()) if warning \
			else spread_deviation()
	fire_shot(from, from + to_target.rotated(Vector3.UP, deviation))
	bloom = minf(bloom + current_weapon.recoil_value / 100.0 * recoil_factor, 1.0)
	if warning or not automatic:
		# The warning shot ends any burst - the target gets their beat.
		bursting = false
		fire_cooldown = maxf(fire_cooldown, fire_pause)


func burst_ready() -> bool:
	if bursting and bloom >= burst_release:
		bursting = false
	elif not bursting and bloom <= burst_resume:
		bursting = true
	return bursting


func miss_deviation(p_distance:float) -> float:
	var degrees:float = rad_to_deg(atan2(MISS_MARGIN, p_distance)) \
			+ current_weapon.projectiles_spread_value * 0.5
	return deg_to_rad(degrees) * (1.0 if randf() < 0.5 else -1.0)



# Base spread plus recoil bloom plus a movement penalty - shots taken on
# the run walk off target, the same way the player's pace opens their cone.
func spread_deviation() -> float:
	var pace:float = character.movement.current_pace() if character.movement else 0.0
	return deg_to_rad(randf_range(-0.5, 0.5) * current_weapon.accuracy_cone_value
			* clampf(spread_factor + bloom + pace * move_penalty, 0.0, 1.5))



# The attack state's fire gate: a ranged weapon waits for the LIVE barrel to
# arrive on target, a melee one only needs the body roughly squared up -
# fists have no barrel to measure.
func trigger_aligned(p_to_target:Vector3, p_max_barrel:float) -> bool:
	if current_weapon != null and not current_weapon.is_ranged:
		var facing:Vector3 = character.body_container.global_basis.z
		facing.y = 0.0
		return facing.angle_to(p_to_target) <= deg_to_rad(MELEE_FACING)
	return absf(barrel_error(p_to_target)) <= p_max_barrel


func barrel_error(p_to_target:Vector3) -> float:
	if weapon_model == null:
		return 0.0
	var barrel:Vector3 = weapon_model.global_basis.x
	barrel.y = 0.0
	if barrel.length_squared() < 0.01:
		return PI  # barrel pointing vertically mid-pose: hold fire
	return angle_difference(atan2(barrel.x, barrel.z),
			atan2(p_to_target.x, p_to_target.z))


func is_aware_of_us(p_target) -> bool:
	if not (p_target is Character):
		return true  # vehicles get no courtesy miss
	var to_us:Vector3 = body.global_position - p_target.global_position
	to_us.y = 0.0
	var facing:Vector3 = p_target.body_container.global_basis.z
	facing.y = 0.0
	return rad_to_deg(facing.angle_to(to_us)) <= AWARE_ANGLE * 0.5
