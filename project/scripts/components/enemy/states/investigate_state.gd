class_name InvestigateState
extends StateInterface
# Follows the quarry's trail breadcrumb by breadcrumb until it goes cold, then resumes.

const LOOK_TIME:float = 2.0
const REACT_TIME:float = 0.4  # face the clue before moving - "it heard that"
const FACING_WEIGHT:float = 0.1

var return_state:String = "guard"
var pickup:Vector3
var picked_up:bool = false
var index:int = -1
var look_timer:float = 0.0
var react_timer:float = 0.0


func enter(p_msg:Dictionary = {}):
	return_state = p_msg.get("return_state", actor.home_state())
	actor.movement.is_sprinting = false
	look_timer = 0.0
	index = -1
	picked_up = false
	react_timer = REACT_TIME
	# Where to sniff for the trail: a sound's origin, or right here (chase
	# already rushed us to the last seen spot).
	pickup = p_msg.get("origin", actor.character.global_position)


# A fresh clue (another shot heard) re-points the investigation there.
func redirect(p_position:Vector3):
	look_timer = 0.0
	picked_up = false
	pickup = p_position
	react_timer = REACT_TIME


func physics_update(p_delta:float):
	if actor.vision.target:
		change_to("chase", {return_state = return_state})
		return
	if react_timer > 0.0:
		# The startle beat: turn toward the clue, hold, THEN walk out.
		react_timer -= p_delta
		var to_pickup:Vector3 = pickup - actor.character.global_position
		to_pickup.y = 0.0
		if to_pickup.length() > 0.5:
			var visual:Node3D = actor.movement.visual
			visual.global_rotation.y = lerp_angle(visual.global_rotation.y,
					atan2(to_pickup.x, to_pickup.z), FACING_WEIGHT)
		if react_timer <= 0.0:
			actor.movement.move_to(pickup)
		return
	if actor.movement.navigating:
		return
	var trail:CharacterTrail = quarry_trail()
	if not picked_up:
		picked_up = true
		index = trail.next_index_from(pickup) if trail else -1
	if trail and index >= 0:
		# Skip cold breadcrumbs; the trail keeps growing while the quarry
		# flees, so fresh ones can appear ahead of us.
		while index < trail.samples.size() and not trail.is_fresh(trail.samples[index]):
			index += 1
		if index < trail.samples.size():
			actor.movement.move_to(trail.samples[index].position)
			index += 1
			return
	# Scent gone: one last look around, then back to the interrupted task.
	look_timer += p_delta
	if look_timer >= LOOK_TIME:
		change_to(return_state)


func quarry_trail() -> CharacterTrail:
	if actor.quarry and is_instance_valid(actor.quarry) and not actor.quarry.is_dead:
		return actor.quarry.trail
	return null
