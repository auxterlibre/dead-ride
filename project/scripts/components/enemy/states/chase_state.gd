class_name ChaseState
extends StateInterface
# Sprints after the target firing on the run; Attack in range, Investigate on lost sight.

const STOP_DISTANCE:float = 3.0
const FACING_WEIGHT:float = 0.2
const ADVANCE_FIRE_PAUSE:Vector2 = Vector2(0.7, 1.5)  # sec between running shots
const FIRE_ANGLE:float = 10.0  # deg off-target a running shot still leaves

var return_state:String = "guard"
var last_seen:Vector3
var fire_timer:float = 0.0


func enter(p_msg:Dictionary = {}):
	return_state = p_msg.get("return_state", actor.home_state())
	last_seen = p_msg.get("last_seen", actor.character.global_position)
	actor.movement.is_sprinting = true
	fire_timer = randf_range(ADVANCE_FIRE_PAUSE.x, ADVANCE_FIRE_PAUSE.y)


func exit():
	actor.movement.is_sprinting = false
	actor.movement.face_movement = true
	actor.aim.clear()


func physics_update(p_delta:float):
	var target = actor.vision.target  # character or occupied vehicle
	if target:
		follow(p_delta, target)
		return
	stop_advance_fire()
	# Lost sight: rush the last seen spot, then track from there. An
	# unreachable spot (movement gave up) counts as reached.
	if actor.movement.navigating:
		return
	var to_last:Vector3 = actor.character.global_position - last_seen
	to_last.y = 0.0
	if to_last.length() > STOP_DISTANCE and not actor.movement.gave_up:
		actor.movement.move_to(last_seen)
		return
	change_to("investigate", {return_state = return_state})


# A fresh clue (e.g. shot from a new direction) re-points the pursuit there.
func redirect(p_position:Vector3):
	last_seen = p_position
	actor.movement.move_to(p_position)


func follow(p_delta:float, p_target):
	last_seen = p_target.global_position
	if actor.character.global_position.distance_to(last_seen) <= actor.attack_range():
		change_to("attack", {return_state = return_state})
		return
	actor.movement.move_to(last_seen)
	advance_fire(p_delta, p_target)


# The rig faces the target, not the travel direction, so the chest aim can land the muzzle.
func advance_fire(p_delta:float, p_target):
	var weapons:EnemyWeapons = actor.weapons
	var weapon:WeaponData = weapons.current_weapon if weapons else null
	var to_target:Vector3 = p_target.global_position - actor.character.global_position
	to_target.y = 0.0
	if weapon == null or not weapon.is_ranged \
			or to_target.length() > weapon.effective_range_value:
		stop_advance_fire()
		return
	actor.movement.face_movement = false
	actor.aim.aim_at(p_target.global_position)
	var visual:Node3D = actor.movement.visual
	visual.global_rotation.y = lerp_angle(visual.global_rotation.y,
			atan2(to_target.x, to_target.z), FACING_WEIGHT)
	fire_timer -= p_delta
	if fire_timer > 0.0:
		return
	if absf(weapons.barrel_error(to_target)) > deg_to_rad(FIRE_ANGLE):
		return  # gun hasn't swung onto them yet; try again next tick
	weapons.fire_at(p_target)
	fire_timer = randf_range(ADVANCE_FIRE_PAUSE.x, ADVANCE_FIRE_PAUSE.y)


func stop_advance_fire():
	actor.movement.face_movement = true
	actor.aim.clear()
