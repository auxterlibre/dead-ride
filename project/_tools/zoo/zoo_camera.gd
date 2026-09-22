extends Camera3D
# Free look over the zoo: the same WASD pan / QE zoom the debug menu's free camera uses.

const PAN_SPEED: float = 22.0  # m/s across the ground
const FAST: float = 3.0  # sprint multiplier
const ZOOM_SPEED: float = 18.0  # ortho size per second
const ZOOM_MIN: float = 2.0  # closer than the debug camera: this is for inspecting
const ZOOM_MAX: float = 90.0
const ORBIT_SPEED: float = 0.006  # radians per pixel dragged
const PITCH_LIMIT: float = 1.4

# Where you are put down, not a frame fitted to the contents - it never moves
# again on its own. Roughly over the middle of the front row.
@export var start_position: Vector3 = Vector3(-10.0, 14.0, -14.0)

var yaw: float = PI  # the rows run off toward +Z, so start turned to face them
var pitch: float = -PI / 4.0  # the game's own 45 degrees to start
var orbiting: bool = false


func _ready():
	position = start_position
	apply_look()


func _process(p_delta: float):
	var forward: Vector3 = -global_basis.z
	var right: Vector3 = global_basis.x
	forward.y = 0.0
	right.y = 0.0
	var pan: Vector3 = forward.normalized() * Input.get_axis("move_down", "move_up") \
			+ right.normalized() * Input.get_axis("move_left", "move_right")
	var speed: float = PAN_SPEED * (FAST if Input.is_action_pressed("sprint") else 1.0)
	global_position += pan * speed * p_delta
	size = clampf(size + Input.get_axis("next_item", "prev_item")
			* ZOOM_SPEED * p_delta, ZOOM_MIN, ZOOM_MAX)


# Right-drag orbits. A zoo needs the far side of a model, which pan and zoom
# alone can never reach - the debug camera has no rotation because the game
# never turns either.
func _unhandled_input(p_event: InputEvent):
	if p_event is InputEventMouseButton \
			and p_event.button_index == MOUSE_BUTTON_RIGHT:
		orbiting = p_event.pressed
	elif p_event is InputEventMouseMotion and orbiting:
		yaw -= p_event.relative.x * ORBIT_SPEED
		pitch = clampf(pitch - p_event.relative.y * ORBIT_SPEED,
				-PITCH_LIMIT, PITCH_LIMIT)
		apply_look()


func apply_look():
	basis = Basis.from_euler(Vector3(pitch, yaw, 0.0))
