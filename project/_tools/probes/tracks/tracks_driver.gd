extends VehicleSteering

const WEAVE_PERIOD: float = 5.0  # sec per full left-right swing
const FIELD_EDGE: float = 18.0  # m from centre; beyond it the weave turns home
const STALL_SPEED: float = 0.5  # m/s under full throttle that counts as wedged
const STALL_TIME: float = 1.0  # sec of that before backing out
const BACK_OUT_TIME: float = 1.2  # sec of reverse to get free

@export var demo: bool = false  # unattended weave, for the screenshot run

var elapsed: float = 0.0
var stall_timer: float = 0.0


func gather_intent():
	if vehicle == null:
		return
	if demo:
		weave()
		return
	vehicle.gather_player_control()


# Full throttle plus a steering swing, so the run lays crossing ruts.
func weave():
	var delta: float = vehicle.get_physics_process_delta_time()
	elapsed += delta
	vehicle.control_brake = false
	if reversing > 0.0:
		reversing -= delta
		vehicle.control_throttle = -0.8
		vehicle.control_steer = 0.0
		return
	watch_for_stalling(delta)
	vehicle.control_throttle = 1.0
	# Home well before the rim; nose-first into a wall at full throttle wedges.
	var flat: Vector2 = Vector2(vehicle.global_position.x, vehicle.global_position.z)
	if maxf(absf(flat.x), absf(flat.y)) > FIELD_EDGE:
		vehicle.control_steer = steer_toward(Vector3.ZERO)
	else:
		vehicle.control_steer = sin(elapsed * TAU / WEAVE_PERIOD)


# Not the base watchdog: no route to measure progress along, just a dead speed.
func watch_for_stalling(p_delta: float):
	if vehicle.speed > STALL_SPEED:
		stall_timer = 0.0
		return
	stall_timer += p_delta
	if stall_timer >= STALL_TIME:
		stall_timer = 0.0
		reversing = BACK_OUT_TIME


# + error means the target is to the left, and + steering IS left: no flip.
func steer_toward(p_target: Vector3) -> float:
	var to_target: Vector3 = p_target - vehicle.global_position
	to_target.y = 0.0
	var forward: Vector3 = vehicle.global_basis.z
	forward.y = 0.0
	if to_target.length() < 0.01 or forward.length() < 0.01:
		return 0.0
	return clampf(forward.normalized().signed_angle_to(
			to_target.normalized(), Vector3.UP) * STEER_GAIN, -1.0, 1.0)
