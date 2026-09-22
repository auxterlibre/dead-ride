class_name CharacterTrail
extends Node
# Breadcrumb memory: recent positions with timestamps, going cold with age.

const MAX_SAMPLES:int = 64

@export var sample_interval:float = 0.5
@export var min_distance:float = 1.0  # no samples while standing still
@export var lifetime:float = 12.0  # sec before a sample goes cold

var samples:Array[Dictionary] = []  # {position:Vector3, time:float}
var timer:float = 0.0

@onready var body:CharacterBody3D = get_parent()


func _physics_process(p_delta):
	timer -= p_delta
	if timer > 0.0:
		return
	timer = sample_interval
	if samples.size() > 0 \
			and samples[-1].position.distance_to(body.global_position) < min_distance:
		return
	samples.append({position = body.global_position, time = now()})
	if samples.size() > MAX_SAMPLES:
		samples.pop_front()


func now() -> float:
	return Time.get_ticks_msec() / 1000.0


func is_fresh(p_sample:Dictionary) -> bool:
	return now() - p_sample.time <= lifetime


# Index of the breadcrumb to walk toward when picking up the trail at
# p_position: the one AFTER the sample nearest to it.
func next_index_from(p_position:Vector3) -> int:
	var nearest:int = -1
	var nearest_distance:float = INF
	for i in samples.size():
		var distance:float = samples[i].position.distance_to(p_position)
		if distance < nearest_distance:
			nearest = i
			nearest_distance = distance
	return nearest + 1
