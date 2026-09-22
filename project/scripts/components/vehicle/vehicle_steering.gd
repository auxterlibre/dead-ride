class_name VehicleSteering
extends Node

const ARRIVE_DISTANCE: float = 2.5  # a waypoint this close counts as reached
const PASS_DISTANCE: float = 5.0  # ...or this close and already behind us
const GOAL_DISTANCE: float = 2.0  # ...and the last one ends the drive
const SLOW_DISTANCE: float = 8.0  # start easing off this far from the goal
const BRAKE_DISTANCE: float = 12.0  # how far ahead bends are braked for
const STEER_GAIN: float = 1.6  # steering per radian of heading error
const CORNER_ANGLE: float = 0.6  # heading error that costs the full slowdown
const OVERSPEED: float = 1.15  # fraction of target speed that starts braking
const CREEP_THROTTLE: float = 0.25  # floor, so a light touch still rolls
const STUCK_TIME: float = 2.5  # driving without progress this long = wedged
const STUCK_DISTANCE: float = 0.6  # net displacement that counts as progress
const UNSTICK_TIME: float = 1.2  # seconds of reverse before trying again
const UNSTICK_ATTEMPTS: int = 4  # then give up and let the brain move on
const YIELD_RANGE: float = 12.0  # how far ahead another vehicle matters
const YIELD_LANE: float = 2.6  # half-width of the corridor watched ahead
const BUMPER_ROOM: float = 4.0  # centre distance held to a blocker at rest
const DODGE_RANGE: float = 8.0  # blockers closer than this bend the steering
const DODGE_GAIN: float = 0.45  # how hard a blocker pushes the wheel
const PROP_LANE: float = 3.2  # half-width watched for steer-around props
const GOAL_EXEMPT: float = 6.0  # a prop this close to the goal IS the destination
const TURN_CIRCLE: float = 7.0  # a target behind and inside this cannot be steered to

@export var cruise_speed: float = 7.0  # m/s down a straight
@export var corner_speed: float = 3.0  # m/s through the sharpest turn

const IGNITION_HOLD: float = 1.2  # sec of cranking before the wheels turn

var vehicle: Vehicle
var waypoints: PackedVector3Array = PackedVector3Array()
var index: int = 0
var driving: bool = false
var gave_up: bool = false  # the last drive_to was declared unreachable
var holding: float = 0.0  # seconds to sit before driving (the ignition beat)
var reversing: float = 0.0  # seconds of deliberate backing left to run
var stuck_timer: float = 0.0
var stuck_anchor: Vector3
var unstick_timer: float = 0.0
var unstick_attempts: int = 0


func _ready():
	vehicle = get_parent() as Vehicle
	if vehicle:
		vehicle.controller = self


# p_exact appends the destination itself, for somewhere off the road entirely
# (the delivery bay); without it the route ends at the nearest tarmac. p_via
# threads exact lead-in points before it, so a caller can shape the final
# leg's DIRECTION - the truck approaches its bay straight-on instead of
# cutting the corner past the pump.
func drive_to(p_target: Vector3, p_exact: bool = false,
		p_via: PackedVector3Array = PackedVector3Array()) -> bool:
	if vehicle == null or Globals.road_network == null:
		return false
	# With vias, the ROAD leg aims at the first of them - routing to the final
	# target instead would march the lane right past the turn-off and demand a
	# backward hook to recover.
	var road_goal: Vector3 = p_via[0] if p_exact and not p_via.is_empty() else p_target
	waypoints = Globals.road_network.route(vehicle.global_position, road_goal)
	if waypoints.is_empty():
		return false
	if p_exact:
		for point in p_via:
			if flat_distance(waypoints[waypoints.size() - 1], point) > GOAL_DISTANCE:
				waypoints.append(point)
	if p_exact and flat_distance(waypoints[waypoints.size() - 1], p_target) > GOAL_DISTANCE:
		waypoints.append(p_target)
	# The route opens on the cell the car already sits in; advance_waypoint()
	# drops it on the first tick rather than steering back to it.
	index = 0
	driving = true
	gave_up = false
	unstick_attempts = 0
	unstick_timer = 0.0
	reset_progress()
	return true


# Straight back for a while, before any route is asked for: a vehicle that
# parked nose-in cannot turn round inside its own bay, and steering out of one
# is a 180 it has no room for.
func back_up(p_seconds: float):
	waypoints = PackedVector3Array()
	index = 0
	driving = false
	gave_up = false
	reversing = p_seconds


# A beat of sitting still while the starter sound runs its course - a spawn
# that pulls away the same tick it cranks reads as a car popping in mid-drive.
func hold_for(p_seconds: float = IGNITION_HOLD):
	holding = p_seconds


func stop():
	driving = false
	reversing = 0.0
	hold()


# Called by Vehicle._physics_process, the same pull that CharacterMovement
# makes on its subclasses - no node ordering to get right.
func gather_intent():
	if vehicle == null:
		return
	if holding > 0.0:
		holding -= vehicle.get_physics_process_delta_time()
		hold()
		return
	if reversing > 0.0:
		reversing -= vehicle.get_physics_process_delta_time()
		vehicle.control_throttle = -0.6
		vehicle.control_steer = 0.0
		vehicle.control_brake = false
		return
	if not driving:
		hold()
		return
	if unstick_timer > 0.0:
		reverse_out()
		return
	var delta: float = vehicle.get_physics_process_delta_time()
	advance_waypoint()
	if arrived():
		stop()
		return
	watch_for_wedging(delta)
	var to_target: Vector3 = waypoints[index] - vehicle.global_position
	to_target.y = 0.0
	var forward: Vector3 = vehicle.global_basis.z
	forward.y = 0.0
	if to_target.length() < 0.01 or forward.length() < 0.01:
		return
	# + error means the target lies to the car's left, and + steering IS a left
	# turn, so the sign carries straight through with no flip.
	var error: float = forward.normalized().signed_angle_to(
			to_target.normalized(), Vector3.UP)
	var traffic: Dictionary = traffic_check(forward.normalized())
	vehicle.control_steer = clampf(error * STEER_GAIN + traffic.dodge, -1.0, 1.0)
	if traffic.queueing:
		reset_progress()  # waiting on moving traffic is patience, not wedging
	var target_speed: float = minf(speed_for(error), traffic.cap)
	if target_speed <= 0.05:
		hold()
		return
	if vehicle.speed > target_speed * OVERSPEED:
		vehicle.control_throttle = 0.0
		vehicle.control_brake = true
		return
	vehicle.control_brake = false
	vehicle.control_throttle = clampf(
			(target_speed - vehicle.speed) / maxf(target_speed, 0.1),
			CREEP_THROTTLE, 1.0)


# Watches a corridor ahead for other vehicles: matches their pace down to a
# standstill (queueing), bends the wheel around anything at rest, and breaks a
# nose-to-nose standoff by instance id - the senior vehicle creeps past while
# the junior holds. Stationary blockers deliberately leave the wedge watchdog
# running: reverse-and-retry is the escalation when creeping past isn't enough.
func traffic_check(p_forward: Vector3) -> Dictionary:
	var result: Dictionary = {"cap": INF, "dodge": 0.0, "queueing": false}
	var side: Vector3 = p_forward.cross(Vector3.UP)  # the car's right
	for node in vehicle.get_tree().get_nodes_in_group("vehicle"):
		var other: Vehicle = node
		if other == vehicle or not is_instance_valid(other):
			continue
		var to_other: Vector3 = other.global_position - vehicle.global_position
		if absf(to_other.y) > 3.0:
			continue  # a terrace apart is not in the road
		to_other.y = 0.0
		var ahead: float = to_other.dot(p_forward)
		if ahead < 0.0 or ahead > YIELD_RANGE:
			continue
		var lateral: float = to_other.dot(side)
		if absf(lateral) > YIELD_LANE:
			continue
		var allowed: float = cruise_speed * clampf(
				(ahead - BUMPER_ROOM) / (YIELD_RANGE - BUMPER_ROOM), 0.0, 1.0)
		if other.speed > 1.0:
			# Moving traffic is followed at its own pace, not parked behind.
			allowed = maxf(allowed, other.speed * 0.9)
			result.queueing = true
		elif facing_off(other) and vehicle.get_instance_id() < other.get_instance_id():
			allowed = maxf(allowed, corner_speed * 0.5)
		if allowed < result.cap:
			result.cap = allowed
		if ahead < DODGE_RANGE and other.speed < 1.0:
			# Steer away from the blocker's side; dead ahead defaults to a left
			# pass, which puts two facing dodgers on opposite sides.
			var away: float = signf(lateral) if absf(lateral) > 0.2 else 1.0
			result.dodge += away * DODGE_GAIN * (1.0 - ahead / DODGE_RANGE)
	# Curated static props (group "steer_around": the gas pump) are treated
	# like a vehicle at rest - dodged around AND stopped short of, because a
	# dodge alone can never outvote a big heading error and the truck's 180
	# used to press its nose into the pump mid-turn; the stop feeds the wedge
	# watchdog, whose reverse is what actually re-aims the turn. Anything
	# close to the route's GOAL is the destination's own furniture and is
	# exempt: a customer's whole errand is driving AT the pump.
	var goal: Vector3 = waypoints[waypoints.size() - 1]
	for node in vehicle.get_tree().get_nodes_in_group("steer_around"):
		var prop: Node3D = node
		if flat_distance(prop.global_position, goal) < GOAL_EXEMPT:
			continue
		var to_prop: Vector3 = prop.global_position - vehicle.global_position
		if absf(to_prop.y) > 3.0:
			continue
		to_prop.y = 0.0
		var ahead: float = to_prop.dot(p_forward)
		if ahead < 0.0 or ahead > YIELD_RANGE:
			continue
		var lateral: float = to_prop.dot(side)
		if absf(lateral) > PROP_LANE:
			continue
		var allowed: float = cruise_speed * clampf(
				(ahead - BUMPER_ROOM) / (YIELD_RANGE - BUMPER_ROOM), 0.0, 1.0)
		if allowed < result.cap:
			result.cap = allowed
		if ahead < DODGE_RANGE:
			var away: float = signf(lateral) if absf(lateral) > 0.2 else 1.0
			result.dodge += away * DODGE_GAIN * (1.0 - ahead / DODGE_RANGE)
	return result


# Both pointed at each other and neither getting anywhere: without a tiebreak
# the pair mirror-reverses forever.
func facing_off(p_other: Vehicle) -> bool:
	if p_other.controller == null or vehicle.speed > 1.0:
		return false
	var other_forward: Vector3 = p_other.global_basis.z
	return vehicle.global_basis.z.dot(other_forward) < -0.3


# Cruise, corner speed, then a ramp down so it settles on the spot instead of sailing past.
func speed_for(p_error: float) -> float:
	var target: float = minf(corner_limit(), lerpf(cruise_speed, corner_speed,
			clampf(absf(p_error) / CORNER_ANGLE, 0.0, 1.0)))
	var remaining: float = distance_to_goal()
	if remaining < SLOW_DISTANCE:
		target = minf(target, lerpf(corner_speed * 0.35, target,
				remaining / SLOW_DISTANCE))
	return target


# The bend you are already in is too late to brake for - scan ahead and arrive slow.
func corner_limit() -> float:
	var limit: float = cruise_speed
	var scan: float = flat_distance(vehicle.global_position, waypoints[index])
	for i in range(index, waypoints.size() - 1):
		if scan > BRAKE_DISTANCE:
			break
		var turn: float = turn_angle(i)
		if turn > 0.0:
			var through: float = lerpf(cruise_speed, corner_speed,
					clampf(turn / CORNER_ANGLE, 0.0, 1.0))
			# A bend right here bites in full; one at the edge of the scan
			# barely touches the speed yet.
			limit = minf(limit, lerpf(through, cruise_speed,
					clampf(scan / BRAKE_DISTANCE, 0.0, 1.0)))
		scan += flat_distance(waypoints[i], waypoints[i + 1])
	return limit


# How hard the route bends at a waypoint, in radians.
func turn_angle(p_index: int) -> float:
	if p_index >= waypoints.size() - 1:
		return 0.0
	var incoming: Vector3 = waypoints[p_index] - (vehicle.global_position \
			if p_index == 0 else waypoints[p_index - 1])
	var outgoing: Vector3 = waypoints[p_index + 1] - waypoints[p_index]
	incoming.y = 0.0
	outgoing.y = 0.0
	if incoming.length() < 0.01 or outgoing.length() < 0.01:
		return 0.0
	return absf(incoming.normalized().angle_to(outgoing.normalized()))


# Along the route, not as the crow flies: on a loop the exit can be metres
# away in a straight line and most of a lap away on tarmac.
func distance_to_goal() -> float:
	if waypoints.is_empty():
		return 0.0
	var total: float = flat_distance(vehicle.global_position, waypoints[index])
	for i in range(index, waypoints.size() - 1):
		total += flat_distance(waypoints[i], waypoints[i + 1])
	return total


func advance_waypoint():
	while index < waypoints.size() - 1 and (passed(index) \
			or flat_distance(vehicle.global_position, waypoints[index]) < ARRIVE_DISTANCE \
			or inside_turn_circle(index)):
		index += 1


# A waypoint BEHIND the vehicle and inside its turning circle cannot be
# steered to - chasing it is the departure orbit (the truck circled its first
# route point for 50s after reversing out of the bay). Aim past it: the next
# point out gives the turn somewhere to go.
func inside_turn_circle(p_index: int) -> bool:
	var to_target: Vector3 = waypoints[p_index] - vehicle.global_position
	to_target.y = 0.0
	var forward: Vector3 = vehicle.global_basis.z
	forward.y = 0.0
	if to_target.length() > TURN_CIRCLE or forward.length() < 0.01:
		return false
	return to_target.normalized().dot(forward.normalized()) < 0.0


# A car cannot turn tighter than ~6m, so chasing the inside waypoint by distance orbits forever.
func passed(p_index: int) -> bool:
	if flat_distance(vehicle.global_position, waypoints[p_index]) > PASS_DISTANCE:
		return false
	var along: Vector3 = waypoints[p_index + 1] - waypoints[p_index]
	var from_waypoint: Vector3 = vehicle.global_position - waypoints[p_index]
	return Vector2(along.x, along.z).dot(
			Vector2(from_waypoint.x, from_waypoint.z)) > 0.0


# On the run into the final waypoint, so callers can accept a looser idea of
# "there" than the exact spot without a car merely driving past qualifying.
func on_final_leg() -> bool:
	return driving and index >= waypoints.size() - 1


func arrived() -> bool:
	return waypoints.is_empty() or (index == waypoints.size() - 1 \
			and flat_distance(vehicle.global_position, waypoints[index]) < GOAL_DISTANCE)


func hold():
	if vehicle == null:
		return
	vehicle.control_throttle = 0.0
	vehicle.control_steer = 0.0
	vehicle.control_brake = true


# Jammed against something the road graph knows nothing about, most likely the player's car.
func watch_for_wedging(p_delta: float):
	stuck_timer += p_delta
	if stuck_timer < STUCK_TIME:
		return
	if vehicle.global_position.distance_to(stuck_anchor) < STUCK_DISTANCE:
		unstick_timer = UNSTICK_TIME
	reset_progress()


# Twice is enough; past that the brain is told the destination is unreachable.
func reverse_out():
	unstick_timer -= vehicle.get_physics_process_delta_time()
	vehicle.control_throttle = -0.6
	vehicle.control_steer = 0.0
	vehicle.control_brake = false
	if unstick_timer > 0.0:
		return
	unstick_attempts += 1
	reset_progress()
	if unstick_attempts >= UNSTICK_ATTEMPTS:
		gave_up = true
		stop()


func reset_progress():
	stuck_timer = 0.0
	stuck_anchor = vehicle.global_position


func flat_distance(p_from: Vector3, p_to: Vector3) -> float:
	return Vector2(p_from.x - p_to.x, p_from.z - p_to.z).length()
