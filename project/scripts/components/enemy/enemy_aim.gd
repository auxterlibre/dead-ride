class_name EnemyAim
extends Node
# Drives the chest AimLook like PlayerAim; aim_yaw_offset puts the MUZZLE on the target.

const FORWARD_DISTANCE:float = 6.0  # idle gaze point ahead of the rig

@export var influence_weight:float = 0.15  # chest look-at fade speed
@export var yaw_offset_weight:float = 0.15  # smoothing toward a new weapon's offset
@export var visual:Node3D

var focus:Vector3
var has_focus:bool = false
var yaw_offset_current:float = 0.0

var look_modifier:SkeletonModifier3D
var aim_target:Marker3D

@onready var body:Character = get_parent()


func _ready():
	if visual:
		look_modifier = visual.find_child("AimLook", true, false)
	aim_target = Utils.resolve_aim_target(body, look_modifier)
	body.died.connect(func():
			set_physics_process(false)
			if look_modifier:
				look_modifier.influence = 0.0)


func _physics_process(_delta):
	if look_modifier == null or aim_target == null:
		return
	var direction:Vector3 = focus - body.global_position if has_focus \
			else visual.global_basis.z * FORWARD_DISTANCE
	direction.y = 0.0
	if direction.length_squared() < 0.01:
		return
	var weapon:WeaponData = body.weapons.current_weapon if body.weapons else null
	yaw_offset_current = lerpf(yaw_offset_current,
			weapon.aim_yaw_offset if weapon else 0.0, yaw_offset_weight)
	aim_target.global_position = body.global_position \
			+ direction.rotated(Vector3.UP, deg_to_rad(yaw_offset_current))
	look_modifier.influence = lerpf(look_modifier.influence,
			1.0 if weapon else 0.0, influence_weight)


func aim_at(p_position:Vector3):
	focus = p_position
	has_focus = true


func clear():
	has_focus = false
