class_name CharacterVision
extends Area3D
# Sees hostile characters AND vehicles; hostility is re-checked per frame, not at entry.

signal spotted(target)
signal lost(target)

const OBSTACLE_MASK:int = 4 | 8  # walls + car block sight
const EYE_HEIGHT:float = 1.5
const TARGET_HEIGHT:float = 1.2
const SPOT_TIME_NEAR:float = 0.3  # sec of cone sight to acquire, point blank...
const SPOT_TIME_FAR:float = 1.6  # ...and at the vision range edge
const SNEAK_SPOT_MULTIPLIER:float = 2.0  # sneaking suspects take longer to make out
const SUSPICION_DECAY_TIME:float = 1.5  # sec for a full gauge to drain
const ALERT_FADE_TIME:float = 45.0  # sec to calm down after losing every target
const ALERT_RATE_BOOST:float = 4.0  # spotting speed multiplier at full alert

@export var vision_angle:float = 140.0  # full cone, deg
@export var visual:Node3D  # facing source (the rig container)

var candidates:Array = []  # characters and vehicles in the sphere
var target = null
var suspect = null  # who the gauge is filling on (the "?" tell)
var suspicion:float = 0.0  # 0..1; full = spotted
var alertness:float = 0.0  # 0..1; combat sets 1, fades slowly - a spooked guard
var can_see:bool :
	get: return target != null

@onready var character:Character = get_parent()
@onready var shape:CollisionShape3D = $CollisionShape3D


func _ready():
	body_entered.connect(on_body_entered)
	body_exited.connect(on_body_exited)
	if character.data:
		shape.shape.radius = character.data.vision_range


func _physics_process(p_delta):
	if character.is_dead:
		drop_target()
		return
	if target:
		alertness = 1.0  # a live fight keeps the senses sharp
	else:
		alertness = maxf(alertness - p_delta / ALERT_FADE_TIME, 0.0)
	# Sticky: no switching while the current target stays visible. Retention
	# has its own (larger) range - the area sphere only bounds ACQUISITION.
	if target and is_valid_target(target) and retains(target):
		return
	var next_target = find_nearest_visible()
	if next_target == null:
		if target:
			drop_target()
		suspicion = maxf(suspicion - p_delta / SUSPICION_DECAY_TIME, 0.0)
		if suspicion == 0.0:
			suspect = null
		return
	if next_target == target:
		return
	# Sighting: instant inside the detection ring, otherwise the suspicion
	# gauge fills first - the target gets a readable beat to react in.
	suspect = next_target
	if not instant_acquire(next_target):
		suspicion = minf(suspicion + p_delta * suspicion_rate(next_target), 1.0)
		if suspicion < 1.0:
			return
	suspicion = 1.0
	drop_target()
	target = next_target
	spotted.emit(target)


func on_body_entered(p_body:Node3D):
	# Entry only filters to things that CAN be targets; hostility is
	# per-frame (a vehicle's allegiance changes with its driver).
	if p_body == character or candidates.has(p_body):
		return
	if p_body is Character or p_body is Vehicle:
		candidates.append(p_body)


func on_body_exited(p_body:Node3D):
	candidates.erase(p_body)


func drop_target():
	var previous = target
	target = null
	if is_instance_valid(previous):
		lost.emit(previous)


func find_nearest_visible():
	var nearest = null
	var nearest_distance:float = INF
	for candidate in candidates:
		if not is_valid_target(candidate):
			continue
		var distance:float = character.global_position.distance_to(candidate.global_position)
		if distance < nearest_distance and sees(candidate):
			nearest = candidate
			nearest_distance = distance
	return nearest


func is_valid_target(p_target) -> bool:
	return is_instance_valid(p_target) and not p_target.is_dead \
			and character.is_hostile_to(p_target)


# The cone gates ACQUISITION only - a held target is tracked peripherally.
func retains(p_target) -> bool:
	var combat_range:float = character.data.combat_range if character.data else 30.0
	return character.global_position.distance_to(p_target.global_position) <= combat_range \
			and has_line_of_sight(p_target)


# Cone (skipped inside the detection radius, unless sneaking) plus line of sight.
func sees(p_target) -> bool:
	var to_target:Vector3 = p_target.global_position - character.global_position
	to_target.y = 0.0
	if to_target.length() > effective_detection_range() or is_sneaking(p_target):
		var facing:Vector3 = visual.global_basis.z
		facing.y = 0.0
		if rad_to_deg(facing.angle_to(to_target)) > vision_angle * 0.5:
			return false
	return has_line_of_sight(p_target)


# Point blank and unmistakable: inside the detection ring, not sneaking.
func instant_acquire(p_target) -> bool:
	return character.global_position.distance_to(p_target.global_position) \
			<= effective_detection_range() and not is_sneaking(p_target)


# Gauge fill per second: fast up close, slow at the cone's edge, slower
# against a sneaking suspect, much faster while alerted.
func suspicion_rate(p_target) -> float:
	var vision_range:float = character.data.vision_range if character.data else 15.0
	var distance:float = character.global_position.distance_to(p_target.global_position)
	var spot_time:float = lerpf(SPOT_TIME_NEAR, SPOT_TIME_FAR,
			clampf(distance / vision_range, 0.0, 1.0))
	if is_sneaking(p_target):
		spot_time *= SNEAK_SPOT_MULTIPLIER
	return (1.0 + ALERT_RATE_BOOST * alertness) / spot_time


# The peripheral ring, widened while alerted - a spooked guard is harder
# to close on until it calms down.
func effective_detection_range() -> float:
	var base:float = character.data.detection_range if character.data else 5.0
	return base * (1.0 + alertness)


func is_sneaking(p_target) -> bool:
	var movement = p_target.get("movement")  # vehicles have none
	return movement != null and movement.is_sneaking


func has_line_of_sight(p_target) -> bool:
	var query:PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			character.global_position + Vector3.UP * EYE_HEIGHT,
			p_target.global_position + Vector3.UP * TARGET_HEIGHT, OBSTACLE_MASK)
	var hit:Dictionary = character.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	# A target's own colliders (a vehicle's hull) don't block sight OF it.
	return hit.collider == p_target or p_target.is_ancestor_of(hit.collider)
