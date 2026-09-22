class_name CameraFollow
extends Node3D

@export var aim_zoom:float = 0.88  # fraction of the base ortho size while aiming
@export var zoom_speed:float = 4.0  # per-second pull toward the target zoom

var target:Node : set = _set_target
var kick_offset:Vector3 = Vector3.ZERO
var look_ahead:Vector3 = Vector3.ZERO  # aim-direction lead, fed by PlayerAim
var target_zoom:float = 1.0
var radial_blur:CompositorEffect
var radial_blur_max:float = 0.0

@onready var camera:Camera3D = $Camera
@onready var camera_base:Vector3 = camera.position
@onready var base_size:float = camera.size


func _ready():
	camera.near = -100
	InputManager.camera = camera
	Globals.camera_follow = self
	# Subtle lean-in while aiming: the ortho size shrinks a touch, and the
	# existing aim look_ahead biases the framing toward the reticle.
	Signals.aim_state_changed.connect(
			func(p_aiming): target_zoom = aim_zoom if p_aiming else 1.0)
	Signals.drive_state_changed.connect(func(_p_driving): target_zoom = 1.0)
	find_radial_blur.call_deferred()


func _process(delta):
	kick_offset = kick_offset.lerp(Vector3.ZERO, minf(12.0 * delta, 1.0))
	camera.position = camera_base + kick_offset
	camera.size = lerpf(camera.size, base_size * target_zoom,
			minf(zoom_speed * delta, 1.0))
	apply_zoom_anchor()
	#update_radial_blur()
	if target:
		global_position = lerp(global_position,
				target.global_position + look_ahead, 5.0 * delta)


# The scene's radial blur rides the aim zoom; effect setters are render-thread safe.
func find_radial_blur():
	var compositors:Array = []
	if camera.compositor:
		compositors.append(camera.compositor)
	for environment in get_tree().current_scene.find_children(
			"*", "WorldEnvironment", true, false):
		if environment.compositor:
			compositors.append(environment.compositor)
	for compositor in compositors:
		for effect in compositor.compositor_effects:
			var script:Script = effect.get_script()
			if script and script.get_global_name() == &"PostProcessRadialBlur":
				radial_blur = effect
				radial_blur_max = effect.blur_strength
				return


func update_radial_blur():
	if radial_blur == null:
		return
	var progress:float = clampf(inverse_lerp(base_size,
			base_size * aim_zoom, camera.size), 0.0, 1.0)
	radial_blur.enabled = progress > 0.01  # skip the pass entirely when idle
	radial_blur.blur_strength = radial_blur_max * progress
	var cursor:Vector2 = get_viewport().get_mouse_position() \
			/ get_viewport().get_visible_rect().size
	radial_blur.center_x = cursor.x
	radial_blur.center_y = cursor.y


func apply_zoom_anchor():
	var viewport_size:Vector2 = get_viewport().get_visible_rect().size
	var cursor:Vector2 = get_viewport().get_mouse_position() / viewport_size \
			- Vector2(0.5, 0.5)
	var zoom_pull:float = base_size - camera.size
	var aspect:float = viewport_size.x / viewport_size.y
	camera.global_position += camera.global_basis.x * cursor.x * aspect * zoom_pull \
			- camera.global_basis.y * cursor.y * zoom_pull


# Instant view punch (e.g. weapon recoil, opposite the shot) that springs back.
func kick(p_impulse:Vector3):
	kick_offset += p_impulse


func _set_target(p_value):
	if "camera_spot" in p_value:
		target = p_value.camera_spot
	else:
		target = p_value
