class_name PatrolRoute
extends Node3D
# A patrol drawn as a node: each Marker3D child is a stop, walked in tree
# order and looped. A marker's +Z is the facing held while dwelling there -
# the same forward the character rigs use.

@export var dwell: Vector2 = Vector2(2.0, 5.0)  # sec spent at each stop

var stops: Array[Marker3D] = []


func _ready():
	for child in get_children():
		if child is Marker3D:
			stops.append(child)


func stop_count() -> int:
	return stops.size()


func stop_position(p_index: int) -> Vector3:
	return stops[p_index % stops.size()].global_position


func stop_facing(p_index: int) -> Vector3:
	var facing: Vector3 = stops[p_index % stops.size()].global_basis.z
	facing.y = 0.0
	return facing.normalized() if facing.length() > 0.01 else Vector3.FORWARD


func nearest_stop(p_position: Vector3) -> int:
	var best: int = 0
	for i in stops.size():
		if stop_position(i).distance_to(p_position) \
				< stop_position(best).distance_to(p_position):
			best = i
	return best


func roll_dwell() -> float:
	return randf_range(dwell.x, maxf(dwell.x, dwell.y))
