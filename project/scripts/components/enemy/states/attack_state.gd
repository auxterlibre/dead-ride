class_name AttackState
extends StateInterface
# Fights inside weapon range; owns the facing, falls back to Chase on lost range or sight.

const FACING_WEIGHT:float = 0.15
const FIRE_ANGLE:float = 8.0  # deg off-target the shot still leaves
const RANGE_SLACK:float = 1.1  # hysteresis before chasing again
const AIM_TIME:float = 0.4  # settle-in before the first shot
const LOST_GRACE:float = 0.6  # sec holding the aim before chasing a lost target
const RETREAT_FACTOR:float = 0.3  # closer than this share of attack range = back up
const RETREAT_STEP:float = 3.0  # m per backpedal order
const STRAFE_INTERVAL:Vector2 = Vector2(1.2, 2.8)  # sec between sidesteps
const STRAFE_STEP:Vector2 = Vector2(1.5, 2.5)  # m per sidestep

var return_state:String = "guard"
var last_seen:Vector3
var aim_timer:float = 0.0
var strafe_timer:float = 0.0
var lost_timer:float = 0.0
var was_reloading:bool = false


func enter(p_msg:Dictionary = {}):
	return_state = p_msg.get("return_state", actor.home_state())
	last_seen = actor.character.global_position
	aim_timer = AIM_TIME
	strafe_timer = randf_range(STRAFE_INTERVAL.x, STRAFE_INTERVAL.y)
	lost_timer = 0.0
	was_reloading = false
	actor.movement.stop()
	actor.movement.is_sprinting = false
	actor.movement.face_movement = false  # this state owns the facing


func exit():
	actor.movement.face_movement = true
	actor.aim.clear()


func physics_update(p_delta:float):
	aim_timer = maxf(aim_timer - p_delta, 0.0)
	var target = actor.vision.target  # character or occupied vehicle
	if target == null:
		# Brief grace: a target flickering behind a pillar shouldn't whip the
		# brain in and out of chase - hold the aim on their last position.
		lost_timer += p_delta
		if lost_timer >= LOST_GRACE:
			change_to("chase", {return_state = return_state, last_seen = last_seen})
		return
	lost_timer = 0.0
	last_seen = target.global_position
	actor.aim.aim_at(last_seen)  # chest look-at swings the gun onto them
	var to_target:Vector3 = last_seen - actor.character.global_position
	to_target.y = 0.0
	if to_target.length() > actor.attack_range() * RANGE_SLACK:
		change_to("chase", {return_state = return_state})
		return
	# Break for cover on a reload or a hit - here, never in enter(), so the machine stays non-reentrant.
	var reloading:bool = actor.weapons != null and actor.weapons.is_reloading
	if actor.consume_cover_request() or (reloading and not was_reloading):
		was_reloading = reloading
		if actor.try_cover(return_state, last_seen):
			return
	was_reloading = reloading
	reposition(p_delta, to_target)
	var visual:Node3D = actor.movement.visual
	visual.global_rotation.y = lerp_angle(visual.global_rotation.y,
			atan2(to_target.x, to_target.z), FACING_WEIGHT)
	# Shots leave only once the LIVE barrel has actually arrived on target;
	# a melee swing gates on the body's facing instead - fists have no barrel.
	if actor.weapons and aim_timer == 0.0 \
			and actor.weapons.trigger_aligned(to_target, deg_to_rad(FIRE_ANGLE)):
		actor.weapons.fire_at(target)


# Footwork while facing the target: backpedal when reloading or crowded, otherwise sidestep.
func reposition(p_delta:float, p_to_target:Vector3):
	strafe_timer -= p_delta
	if actor.movement.navigating:
		return
	var away:Vector3 = -p_to_target.normalized()
	var reloading:bool = actor.weapons and actor.weapons.is_reloading
	if reloading or p_to_target.length() < actor.attack_range() * RETREAT_FACTOR:
		actor.movement.move_to(actor.character.global_position + away * RETREAT_STEP)
		return
	if strafe_timer <= 0.0:
		strafe_timer = randf_range(STRAFE_INTERVAL.x, STRAFE_INTERVAL.y)
		var side:Vector3 = away.cross(Vector3.UP) * (1.0 if randf() < 0.5 else -1.0)
		actor.movement.move_to(actor.character.global_position
				+ side * randf_range(STRAFE_STEP.x, STRAFE_STEP.y))
