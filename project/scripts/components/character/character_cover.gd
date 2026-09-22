class_name CharacterCover
extends Node
# Finds a spot whose bullet line is BLOCKED, paired with a peek that can shoot back.

const OBSTACLE_MASK:int = 4 | 8  # walls + car stop bullets
const FIRE_HEIGHT:float = 1.1  # chest band the shot lines live in

@export var search_radius:float = 14.0
@export var rings:int = 3  # sample distances out to search_radius
@export var directions:int = 12  # samples per ring
@export var peek_offset:float = 1.6  # sidestep from the spot to the peek
@export var advance_penalty:float = 2.0  # score cost per m closer to the threat
# Cover has to survive the arrival slop (nav tolerance + capsule), or the
# body ends up a step wide of the ideal point with the line wide open.
@export var safety_margin:float = 0.7

@onready var body:CharacterBody3D = get_parent()


# Returns {spot, peek} or an empty dictionary when nothing qualifies.
func find(p_threat:Vector3) -> Dictionary:
	var origin:Vector3 = body.global_position
	var threat_distance:float = origin.distance_to(p_threat)
	var best:Dictionary = {}
	var best_score:float = INF
	for ring in rings:
		var radius:float = search_radius * (ring + 1) / float(rings)
		for step in directions:
			var angle:float = TAU * step / float(directions)
			var spot:Vector3 = snap_to_navigation(origin
					+ Vector3(cos(angle), 0.0, sin(angle)) * radius)
			if not blocks_with_margin(p_threat, spot):
				continue  # exposed, or only barely - not cover
			var peek:Variant = find_peek(p_threat, spot)
			if peek == null:
				continue  # cover we could never shoot back from
			# Prefer near spots, and penalize giving ground toward the threat.
			var score:float = origin.distance_to(spot) + advance_penalty \
					* maxf(threat_distance - spot.distance_to(p_threat), 0.0)
			if score < best_score:
				best_score = score
				best = {spot = spot, peek = peek}
	return best


# A sidestep either way from the spot, perpendicular to the threat line:
# the exposed corner the character leans out to and fires from.
func find_peek(p_threat:Vector3, p_spot:Vector3) -> Variant:
	var to_threat:Vector3 = p_threat - p_spot
	to_threat.y = 0.0
	var side:Vector3 = to_threat.normalized().cross(Vector3.UP) * peek_offset
	for candidate in [p_spot + side, p_spot - side]:
		var peek:Vector3 = snap_to_navigation(candidate)
		if has_shot_line(p_threat, peek):
			return peek
	return null


# Blocked at the point AND a stride to either side of it, so standing a
# little wide of the mark still keeps the blocker in the way.
func blocks_with_margin(p_threat:Vector3, p_spot:Vector3) -> bool:
	var to_threat:Vector3 = p_threat - p_spot
	to_threat.y = 0.0
	var side:Vector3 = to_threat.normalized().cross(Vector3.UP) * safety_margin
	for sample in [p_spot, p_spot + side, p_spot - side]:
		if has_shot_line(p_threat, sample):
			return false
	return true


func has_shot_line(p_threat:Vector3, p_position:Vector3) -> bool:
	var from:Vector3 = p_position + Vector3.UP * FIRE_HEIGHT
	var to:Vector3 = Vector3(p_threat.x, p_threat.y + FIRE_HEIGHT, p_threat.z)
	return body.get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(from, to, OBSTACLE_MASK)).is_empty()


# Samples land on walkable ground when a navmesh exists, so cover is never
# picked inside a wall or off a ledge.
func snap_to_navigation(p_position:Vector3) -> Vector3:
	var map:RID = body.get_world_3d().navigation_map
	if not map.is_valid() or NavigationServer3D.map_get_regions(map).is_empty():
		return p_position
	return NavigationServer3D.map_get_closest_point(map, p_position)
