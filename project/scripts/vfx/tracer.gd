class_name Tracer
extends MeshInstance3D
# Bullet streak: a short gradient ribbon (transparent tail -> hot head) that
# races from the muzzle along the shot line and is absorbed at the impact.

const WIDTH:float = 0.15
const STREAK_LENGTH:float = 5.0
const SPEED:float = 100.0
const MAX_LENGTH:float = 40.0  # visual cap; misses fly off-screen, not to max_range
const COLOR_HEAD:Color = Color(1.0, 0.95, 0.7)
const COLOR_MID:Color = Color(0.839, 0.429, 0.181, 0.882)

var start:Vector3
var direction:Vector3
var length:float
var fade_start:float
var head:float = 0.0
var streak:ImmediateMesh
var material:StandardMaterial3D


# p_overshoot: extra travel past the real end over which the streak fades out
# smoothly (used for misses - the bullet "loses steam" instead of vanishing).
func setup(p_start:Vector3, p_end:Vector3, p_overshoot:float = 0.0):
	start = p_start
	var distance:float = p_start.distance_to(p_end)
	direction = (p_end - p_start) / maxf(distance, 0.001)
	fade_start = minf(distance, MAX_LENGTH)
	length = minf(distance + p_overshoot, MAX_LENGTH)


func _ready():
	streak = ImmediateMesh.new()
	mesh = streak
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.vertex_color_use_as_albedo = true


func _process(p_delta):
	head += SPEED * p_delta
	var tail:float = head - STREAK_LENGTH
	if tail >= length:
		queue_free()
		return
	var camera:Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var head_pos:Vector3 = start + direction * minf(head, length)
	var tail_pos:Vector3 = start + direction * maxf(tail, 0.0)
	var mid_pos:Vector3 = tail_pos.lerp(head_pos, 0.7)
	var fade:float = 1.0
	if head > fade_start and length > fade_start:
		fade = clampf(1.0 - (head - fade_start) / (length - fade_start), 0.0, 1.0)
	var side:Vector3 = direction.cross(
			(camera.global_position - head_pos).normalized()).normalized()
	if side == Vector3.ZERO:
		side = camera.global_transform.basis.x
	side *= WIDTH * 0.5
	streak.clear_surfaces()
	streak.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, material)
	for point in [[tail_pos, Color(COLOR_MID, 0.0)], [mid_pos, COLOR_MID],
			[head_pos, COLOR_HEAD]]:
		var color:Color = point[1]
		color.a *= fade
		streak.surface_set_color(color)
		streak.surface_add_vertex(point[0] - side)
		streak.surface_set_color(color)
		streak.surface_add_vertex(point[0] + side)
	streak.surface_end()
