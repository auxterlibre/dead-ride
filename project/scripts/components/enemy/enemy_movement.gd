class_name EnemyMovement
extends CharacterMovement

const ARRIVE_DISTANCE:float = 0.4
const STUCK_TIME:float = 1.0  # navigating without progress this long = give up
const STUCK_DISTANCE:float = 0.2  # net displacement that counts as progress
const REPATH_DISTANCE:float = 1.0  # ignore sub-metre drift of a moving target
const STEER_WEIGHT:float = 0.15  # low-pass on the steering direction

@export var agent:NavigationAgent3D

var destination:Vector3
var navigating:bool = false
var gave_up:bool = false  # last move_to was declared unreachable
var safe_velocity:Vector3 = Vector3.ZERO
var steer_direction:Vector3 = Vector3.ZERO
var pushed_target:Vector3
var stuck_timer:float = 0.0
var stuck_anchor:Vector3


func _ready():
	# RVO avoidance: dynamic obstacles (the car) bend the desired velocity
	# around them - the navmesh alone knows nothing about moveable bodies.
	if agent and agent.avoidance_enabled:
		agent.velocity_computed.connect(func(p_velocity:Vector3):
				safe_velocity = p_velocity)


func move_to(p_position:Vector3):
	# A genuinely new order re-arms the watchdog; chase re-issuing the same
	# spot every tick must not keep resetting it.
	if not navigating or destination.distance_to(p_position) > 1.0:
		gave_up = false
		stuck_timer = 0.0
		stuck_anchor = body.global_position
	# Re-path only for meaningful target drift: per-frame re-paths around an
	# obstacle with two near-equal routes flip the chosen side at frame rate.
	if agent and (not navigating \
			or pushed_target.distance_to(p_position) > REPATH_DISTANCE):
		agent.target_position = p_position
		pushed_target = p_position
	destination = p_position
	navigating = true


func stop():
	navigating = false
	move_direction = Vector3.ZERO
	steer_direction = Vector3.ZERO  # next order turns crisply, no stale blend


func gather_intent():
	if not navigating:
		move_direction = Vector3.ZERO
		request_velocity(Vector3.ZERO)
		return
	if arrived():
		stop()
		request_velocity(Vector3.ZERO)
		return
	# Unreachable destination: RVO and the path cancel out, so give up instead of jittering.
	stuck_timer += get_physics_process_delta_time()
	if stuck_timer >= STUCK_TIME:
		if body.global_position.distance_to(stuck_anchor) < STUCK_DISTANCE:
			gave_up = true
			stop()
			request_velocity(Vector3.ZERO)
			return
		stuck_timer = 0.0
		stuck_anchor = body.global_position
	var next_point:Vector3 = destination
	if navigation_ready() and not agent.is_navigation_finished():
		next_point = agent.get_next_path_position()
	var to_next:Vector3 = next_point - body.global_position
	to_next.y = 0.0
	var direction:Vector3 = to_next.normalized()
	if agent and agent.avoidance_enabled:
		request_velocity(direction * speed)
		# One tick behind (fine at 60Hz); near-zero output means RVO sees no way through.
		if safe_velocity.length() > 0.1:
			direction = safe_velocity.normalized()
	# Low-pass the steering: RVO and path ties flip the preferred side every frame otherwise.
	if steer_direction == Vector3.ZERO or steer_direction.dot(direction) < -0.95:
		steer_direction = direction  # fresh order or hard reversal: take it
	else:
		steer_direction = steer_direction.slerp(direction, STEER_WEIGHT).normalized()
	move_direction = steer_direction


func request_velocity(p_velocity:Vector3):
	if agent and agent.avoidance_enabled:
		agent.velocity = p_velocity


# Without a navmesh the agent "pathfinds" to its own position - only trust
# it when the map actually has regions; otherwise steer straight.
func navigation_ready() -> bool:
	return agent != null \
			and NavigationServer3D.map_get_regions(agent.get_navigation_map()).size() > 0


func arrived() -> bool:
	var flat:Vector3 = destination - body.global_position
	flat.y = 0.0
	return flat.length() < ARRIVE_DISTANCE
