class_name PatrolState
extends StateInterface
# Walks the route's markers in order, dwells at each with the guard's sweep,
# and picks up from the nearest stop when an interruption drops it back here.

const FACING_WEIGHT: float = 0.05
const SCAN_HOLD: float = 1.5
const SCAN_ANGLE: Vector2 = Vector2(30.0, 60.0)  # deg off the marker facing

var stop_index: int = 0
var walking: bool = false
var dwell_timer: float = 0.0
var scan_timer: float = 0.0
var scan_offset: float = 0.0


func enter(_msg: Dictionary = {}):
	actor.movement.is_sprinting = false
	if actor.patrol_route == null or actor.patrol_route.stop_count() == 0:
		change_to("guard")
		return
	stop_index = actor.patrol_route.nearest_stop(actor.character.global_position)
	walk_out()


func walk_out():
	walking = true
	actor.movement.move_to(actor.patrol_route.stop_position(stop_index))


func next_stop():
	stop_index = (stop_index + 1) % actor.patrol_route.stop_count()
	walk_out()


func physics_update(p_delta: float):
	if walking:
		if actor.movement.navigating:
			return
		if actor.movement.gave_up:
			next_stop()  # a blocked stop is skipped, not shoved through
			return
		walking = false
		dwell_timer = actor.patrol_route.roll_dwell()
		scan_timer = SCAN_HOLD
		scan_offset = 0.0
		return
	dwell_timer -= p_delta
	if dwell_timer <= 0.0:
		next_stop()
		return
	face_the_watch(p_delta)


# The guard's sweep, anchored on the stop marker's facing.
func face_the_watch(p_delta: float):
	var facing: Vector3 = actor.patrol_route.stop_facing(stop_index)
	var facing_yaw: float = atan2(facing.x, facing.z)
	if actor.vision.suspicion > 0.2 and actor.vision.suspect:
		var to_suspect: Vector3 = actor.vision.suspect.global_position \
				- actor.character.global_position
		facing_yaw = atan2(to_suspect.x, to_suspect.z)
	else:
		scan_timer -= p_delta
		if scan_timer <= 0.0:
			if scan_offset == 0.0:
				scan_offset = deg_to_rad(randf_range(SCAN_ANGLE.x, SCAN_ANGLE.y)) \
						* (1.0 if randf() < 0.5 else -1.0)
			else:
				scan_offset = 0.0
			scan_timer = SCAN_HOLD
		facing_yaw += scan_offset
	var visual: Node3D = actor.movement.visual
	visual.global_rotation.y = lerp_angle(visual.global_rotation.y,
			facing_yaw, FACING_WEIGHT)
