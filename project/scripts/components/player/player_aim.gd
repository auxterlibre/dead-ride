class_name PlayerAim
extends Node

const PICK_MASK:int = 2 | 4 | 8  # shootables: enemy hurt boxes, walls, car
const PICK_RAY_LENGTH:float = 200.0

@export var rotation_weight:float = 0.25
@export var influence_weight:float = 0.15  # how fast the chest look-at fades in/out
@export var camera_lead:float = 0.3  # lead per unit of reticle distance past the deadzone
@export var camera_lead_deadzone:float = 8.0  # no camera shift while aiming closer than this
@export var camera_lead_max:float = 0.75  # resting peek toward the cursor
@export var camera_lead_max_aimed:float = 2.5  # extended peek while aiming
@export var aim_height:float = 1.0
@export var weapon_yaw_offset:float = 43.7  # deg; compensates gun-vs-chest-forward
@export var yaw_offset_weight:float = 0.15  # smoothing toward a new weapon's offset

@export var visual:Node3D

var aim_position:Vector3
var aim_direction:Vector3
var mouse_position:Vector2
var stance_weight:float = 0.0  # 0..1, driven by aim state (see mannequin.gd)
var yaw_offset_current:float = 0.0  # eased toward weapon_yaw_offset

var look_modifier:SkeletonModifier3D
var aim_target:Marker3D
var skeleton:Skeleton3D
var chest_idx:int = -1

@onready var body:CharacterBody3D = get_parent()


func _ready():
	mouse_position = get_viewport().get_mouse_position()
	if visual:
		look_modifier = visual.find_child("AimLook", true, false)
		skeleton = visual.find_child("Skeleton3D", true, false)
	aim_target = Utils.resolve_aim_target(body, look_modifier)
	if skeleton:
		chest_idx = skeleton.find_bone("chest")


func _input(event):
	if event is InputEventMouseMotion:
		mouse_position = event.position


func _physics_process(_delta):
	var camera:Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var plane_height:float = body.global_position.y + aim_height
	var origin:Vector3 = camera.project_ray_origin(mouse_position)
	var direction:Vector3 = camera.project_ray_normal(mouse_position)
	# Aim through the column under the cursor; the bare plane point behind it is parallax-shifted.
	var query:PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			origin, origin + direction * PICK_RAY_LENGTH, PICK_MASK)
	query.collide_with_areas = true
	var picked:Dictionary = body.get_world_3d().direct_space_state.intersect_ray(query)
	if picked and not is_ground_hit(picked, plane_height):
		aim_position = Vector3(picked.position.x, plane_height, picked.position.z)
	else:
		var hit = Plane(Vector3.UP, plane_height).intersects_ray(origin, direction)
		if hit == null:
			return
		aim_position = hit
	var flat:Vector3 = aim_position - body.global_position
	flat.y = 0.0
	if flat.length_squared() < 0.01:
		return
	aim_direction = flat.normalized()
	if Globals.camera_follow:
		var lead_distance:float = maxf(flat.length() - camera_lead_deadzone, 0.0)
		var max_lead:float = lerpf(camera_lead_max, camera_lead_max_aimed, stance_weight)
		Globals.camera_follow.look_ahead = (aim_direction * lead_distance
				* camera_lead).limit_length(max_lead)
	if visual == null:
		return
	visual.global_rotation.y = lerp_angle(visual.global_rotation.y,
			atan2(aim_direction.x, aim_direction.z), rotation_weight)
	if look_modifier == null or aim_target == null:
		return
	# Eased, not snapped: an instant jump on weapon swap would teleport the chest look-at.
	yaw_offset_current = lerpf(yaw_offset_current, weapon_yaw_offset, yaw_offset_weight)
	aim_target.global_position = body.global_position \
			+ flat.rotated(Vector3.UP, deg_to_rad(yaw_offset_current))
	look_modifier.influence = lerpf(look_modifier.influence, stance_weight, influence_weight)


# The terrain shares the walls layer, so ground picks are constant - raising one to fire height throws the aim metres past the reticle.
func is_ground_hit(p_hit:Dictionary, p_plane_height:float) -> bool:
	if p_hit.collider is HurtBox:
		return false  # a body is a target column whatever angle we clipped it at
	return p_hit.normal.y > 0.7 and p_hit.position.y < p_plane_height
