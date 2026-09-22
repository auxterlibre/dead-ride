class_name RoamState
extends StateInterface
# The scavenger idle: drift to the nearest loot container not yet picked over,
# rummage a while, move on - and start over when they have all been seen.
# Purely window-shopping; actually searching a crate stays the player's.

const SEARCH_TIME: Vector2 = Vector2(3.0, 7.0)  # sec spent rummaging
const STAND_OFF: float = 1.3  # m short of the crate, which is solid
const FACING_WEIGHT: float = 0.05

var target: Node3D = null
var visited: Array = []
var walking: bool = false
var search_timer: float = 0.0


func enter(_msg: Dictionary = {}):
	actor.movement.is_sprinting = false
	pick_target()


func pick_target():
	var crates: Array = actor.character.get_tree().get_nodes_in_group("loot_container")
	var fresh: Array = crates.filter(func(c): return not visited.has(c))
	if fresh.is_empty():
		visited.clear()
		fresh = crates
	if fresh.is_empty():
		change_to("guard")  # nothing to scavenge anywhere
		return
	var here: Vector3 = actor.character.global_position
	fresh.sort_custom(func(a, b): return a.global_position.distance_to(here) \
			< b.global_position.distance_to(here))
	target = fresh[0]
	walking = true
	actor.movement.move_to(target.global_position \
			+ (here - target.global_position).normalized() * STAND_OFF)


func physics_update(p_delta: float):
	if target == null or not is_instance_valid(target):
		pick_target()
		return
	if walking:
		if actor.movement.navigating:
			return
		walking = false  # arrived, or gave up close enough to rummage from
		search_timer = randf_range(SEARCH_TIME.x, SEARCH_TIME.y)
		return
	var to_crate: Vector3 = target.global_position - actor.character.global_position
	to_crate.y = 0.0
	if to_crate.length() > 0.1:
		var visual: Node3D = actor.movement.visual
		visual.global_rotation.y = lerp_angle(visual.global_rotation.y,
				atan2(to_crate.x, to_crate.z), FACING_WEIGHT)
	search_timer -= p_delta
	if search_timer <= 0.0:
		visited.append(target)
		pick_target()
