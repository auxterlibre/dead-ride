class_name PlayerXray
extends Node
# Overlay on only while something really blocks the camera, so the player can't x-ray itself.

const OBSTACLE_MASK:int = 4 | 8  # walls + car
const CHEST_HEIGHT:float = 1.2
const RAY_BACK:float = 50.0  # toward the camera (ortho: direction, not position)

var overlays:Array[MeshInstance3D] = []

@onready var body:CharacterBody3D = get_parent()


func _ready():
	for child in body.find_child("Skeleton3D", true, false).get_children():
		if child.name.begins_with("Xray"):
			overlays.append(child)
	set_overlay(false)


func _physics_process(_delta):
	var camera:Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var chest:Vector3 = body.global_position + Vector3.UP * CHEST_HEIGHT
	var origin:Vector3 = chest + camera.global_basis.z * RAY_BACK
	var query:PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			origin, chest, OBSTACLE_MASK)
	var hit:Dictionary = body.get_world_3d().direct_space_state.intersect_ray(query)
	set_overlay(not hit.is_empty())


func set_overlay(p_visible:bool):
	for overlay in overlays:
		overlay.visible = p_visible
