class_name CoverState
extends StateInterface
# Sprints to a spot, reloads behind it, leans out to burst. Held only while it still WORKS.

const FACING_WEIGHT:float = 0.15
const FIRE_ANGLE:float = 8.0  # deg off-target the shot still leaves
const DUCK_MIN_TIME:float = 0.8  # sec tucked in even with a settled aim
const PEEK_MAX_TIME:float = 2.5  # sec exposed before tucking back regardless
const BLOWN_DISTANCE:float = 4.0  # threat this close = cover is pointless
const MAX_TIME:float = 12.0  # sec before rejoining the fight regardless

var return_state:String = "guard"
var spot:Vector3
var peek:Vector3
var arrived:bool = false
var ducked:bool = false
var duck_timer:float = 0.0
var peek_timer:float = 0.0
var total_timer:float = 0.0
var peek_shots:int = 0
var blind_peeks:int = 0


func enter(p_msg:Dictionary = {}):
	return_state = p_msg.get("return_state", actor.home_state())
	# Only try_cover() has a spot to give. Anything else standing here is a bug,
	# but holding still beats throwing: physics_update bails on the first frame,
	# since an open position has a clear shot line.
	spot = p_msg.get("spot", actor.character.global_position)
	peek = p_msg.get("peek", spot)
	arrived = false
	ducked = false
	blind_peeks = 0
	total_timer = 0.0
	actor.movement.is_sprinting = true
	actor.movement.move_to(spot)


func exit():
	actor.movement.is_sprinting = false
	actor.movement.is_sneaking = false
	actor.movement.face_movement = true
	actor.aim.clear()


func physics_update(p_delta:float):
	var threat:Variant = tracked_position()
	if threat == null:
		change_to("chase", {return_state = return_state})
		return
	var to_threat:Vector3 = threat - actor.character.global_position
	to_threat.y = 0.0
	total_timer += p_delta
	# Rushed, or holding cover too long: rejoin the fight on foot.
	if to_threat.length() < BLOWN_DISTANCE or total_timer >= MAX_TIME:
		leave("attack")
		return
	if not arrived:
		if actor.movement.gave_up:
			leave("attack")
			return
		if actor.movement.navigating:
			return
		arrived = true
		actor.movement.is_sprinting = false
		actor.movement.face_movement = false  # installed: face the threat
		duck()
	var visual:Node3D = actor.movement.visual
	visual.global_rotation.y = lerp_angle(visual.global_rotation.y,
			atan2(to_threat.x, to_threat.z), FACING_WEIGHT)
	# Shot at while leaning out: get back behind the wall immediately.
	if actor.consume_cover_request() and not ducked:
		tuck_back()
		return
	if ducked:
		hold_cover(p_delta, threat)
	else:
		hold_peek(p_delta, threat)


# Behind the wall: crouch, top up the magazine, let the bloom drain.
func hold_cover(p_delta:float, p_threat:Vector3):
	var settling:bool = not actor.movement.navigating
	actor.movement.is_sneaking = settling  # crouch once actually tucked in
	if not settling:
		return
	# The threat moved: if this spot no longer breaks their line it is not
	# cover any more, and hiding behind nothing loses the fight.
	if exposed_at(actor.character.global_position, p_threat):
		leave("attack")
		return
	duck_timer += p_delta
	var weapons:EnemyWeapons = actor.weapons
	if weapons and not weapons.is_reloading \
			and weapons.current_weapon.current_ammo < weapons.current_weapon.max_ammo:
		weapons.reload()
	var ready_again:bool = weapons == null or (not weapons.is_reloading \
			and weapons.bloom <= weapons.burst_resume)
	if duck_timer >= DUCK_MIN_TIME and ready_again:
		ducked = false
		peek_timer = 0.0
		peek_shots = 0
		actor.movement.is_sneaking = false
		actor.movement.move_to(peek)


# A peek that produced no shot counts as blind; two of those and the spot is not worth holding.
func hold_peek(p_delta:float, p_threat:Vector3):
	peek_timer += p_delta
	var weapons:EnemyWeapons = actor.weapons
	var target = actor.vision.target  # character or occupied vehicle
	if target and exposed_at(actor.character.global_position, p_threat):
		actor.aim.aim_at(target.global_position)
		var to_target:Vector3 = target.global_position - actor.character.global_position
		to_target.y = 0.0
		if weapons and absf(weapons.barrel_error(to_target)) <= deg_to_rad(FIRE_ANGLE):
			weapons.fire_at(target)
			peek_shots += 1
	var burst_done:bool = weapons != null and (weapons.is_reloading \
			or weapons.bloom >= weapons.burst_release)
	if not burst_done and peek_timer < PEEK_MAX_TIME:
		return
	if peek_shots > 0:
		blind_peeks = 0
	else:
		blind_peeks += 1
		if blind_peeks >= 2:
			# This position produces nothing - go fight for a better one.
			leave("attack")
			return
	tuck_back()


func tuck_back():
	actor.aim.clear()
	actor.movement.move_to(spot)
	duck()


func duck():
	ducked = true
	duck_timer = 0.0


func leave(p_state:String):
	actor.block_cover()
	change_to(p_state, {return_state = return_state})


# True when a shot line runs clean between here and the threat - meaning
# this position offers no protection (and can shoot back).
func exposed_at(p_position:Vector3, p_threat:Vector3) -> bool:
	if actor.cover == null:
		return true
	return actor.cover.has_shot_line(p_threat, p_position)


# The fight's position: seen live, or the quarry's own position as
# short-term memory while tucked in (they were in sight moments ago).
func tracked_position() -> Variant:
	if actor.vision.target:
		return actor.vision.target.global_position
	if actor.quarry and is_instance_valid(actor.quarry) and not actor.quarry.is_dead:
		return actor.quarry.global_position
	return null
