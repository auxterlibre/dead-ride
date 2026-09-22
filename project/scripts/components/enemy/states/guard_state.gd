class_name GuardState
extends StateInterface
# Holds the post, sweeps its look around, and turns toward whatever fills the suspicion gauge.

const FACING_WEIGHT:float = 0.05
const RETURN_DISTANCE:float = 0.6  # drift past this and it walks back
const SCAN_INTERVAL:Vector2 = Vector2(3.0, 6.0)  # sec between sweeps
const SCAN_ANGLE:Vector2 = Vector2(30.0, 60.0)  # deg off the post facing
const SCAN_HOLD:float = 1.5  # sec looking sideways before swinging back

var scan_timer:float = 0.0
var scan_offset:float = 0.0


func enter(_msg:Dictionary = {}):
	actor.movement.is_sprinting = false
	scan_timer = randf_range(SCAN_INTERVAL.x, SCAN_INTERVAL.y)
	scan_offset = 0.0


func physics_update(p_delta:float):
	if actor.movement.navigating:
		return
	# Checked every tick, not just on entry, so a late post or a shoved body still returns.
	var to_post:Vector3 = actor.guard_position - actor.character.global_position
	to_post.y = 0.0
	if to_post.length() > RETURN_DISTANCE and not actor.movement.gave_up:
		actor.movement.move_to(actor.guard_position)
		return
	var facing_yaw:float = atan2(actor.guard_facing.x, actor.guard_facing.z)
	if actor.vision.suspicion > 0.2 and actor.vision.suspect:
		# Turning also centers the suspect in the cone, so a noticed glimpse
		# naturally escalates into a real look.
		var to_suspect:Vector3 = actor.vision.suspect.global_position \
				- actor.character.global_position
		facing_yaw = atan2(to_suspect.x, to_suspect.z)
	else:
		scan_timer -= p_delta
		if scan_timer <= 0.0:
			if scan_offset == 0.0:
				scan_offset = deg_to_rad(randf_range(SCAN_ANGLE.x, SCAN_ANGLE.y)) \
						* (1.0 if randf() < 0.5 else -1.0)
				scan_timer = SCAN_HOLD
			else:
				scan_offset = 0.0
				scan_timer = randf_range(SCAN_INTERVAL.x, SCAN_INTERVAL.y)
		facing_yaw += scan_offset
	var visual:Node3D = actor.movement.visual
	visual.global_rotation.y = lerp_angle(visual.global_rotation.y,
			facing_yaw, FACING_WEIGHT)
