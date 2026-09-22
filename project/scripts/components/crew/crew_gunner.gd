class_name CrewGunner
extends Node

const SCAN_INTERVAL: float = 0.15
const FIRE_ANGLE: float = 8.0
const FACING_WEIGHT: float = 0.2
const EYE_HEIGHT: float = 1.5
const TARGET_HEIGHT: float = 1.2
const SIGHT_MASK: int = 4 | 8

@export var weapons: EnemyWeapons
@export var aim: EnemyAim

var vehicle: Vehicle
var target: Character
var scan_timer: float = 0.0
var shielded_model: Weapon

@onready var body: Character = get_parent()


func _ready():
	for child in body.get_children():
		if child is CharacterMovement:
			child.enabled = false
	var node: Node = body.get_parent()
	while node != null and not node is Vehicle:
		node = node.get_parent()
	vehicle = node


func _physics_process(p_delta: float):
	if vehicle == null or body.is_dead or weapons == null:
		return
	shield()
	scan_timer -= p_delta
	if scan_timer <= 0.0:
		scan_timer = SCAN_INTERVAL
		target = pick_target()
	if target == null:
		aim.clear()
		return
	var to_target: Vector3 = target.global_position - body.global_position
	to_target.y = 0.0
	if to_target.length_squared() < 0.01:
		return
	aim.aim_at(target.global_position)
	var visual: Node3D = body.body_container
	visual.global_rotation.y = lerp_angle(visual.global_rotation.y,
			atan2(to_target.x, to_target.z), FACING_WEIGHT)
	if weapons.trigger_aligned(to_target, deg_to_rad(FIRE_ANGLE)):
		var from: Vector3 = Vector3(body.global_position.x,
				target.global_position.y + TARGET_HEIGHT, body.global_position.z)
		weapons.fire_from(from, target)


func shield():
	var model: WeaponRanged = weapons.weapon_model as WeaponRanged
	if model == null or model == shielded_model:
		return
	model.shielded = [vehicle.get_rid(), vehicle.hurt_box.get_rid()]
	shielded_model = model


func pick_target() -> Character:
	var best: Character = null
	var best_distance: float = INF
	var reach: float = body.data.vision_range if body.data else 30.0
	for node in get_tree().get_nodes_in_group("character"):
		var other: Character = node as Character
		if other == null or other.is_dead or not body.is_hostile_to(other):
			continue
		var distance: float = body.global_position.distance_to(other.global_position)
		if distance > reach or distance >= best_distance or not sees(other):
			continue
		best = other
		best_distance = distance
	return best


func sees(p_other: Character) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			body.global_position + Vector3.UP * EYE_HEIGHT,
			p_other.global_position + Vector3.UP * TARGET_HEIGHT, SIGHT_MASK)
	query.exclude = [vehicle.get_rid()]
	var hit: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	return hit.collider == p_other or p_other.is_ancestor_of(hit.collider)
