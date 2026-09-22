class_name HordeTarget
extends RefCounted

var horde: Horde
var index: int = -1
var generation: int = -1

var global_position: Vector3:
	get:
		return horde.position_of(index) if alive() else Vector3.ZERO
var is_dead: bool:
	get:
		return not alive()


func _init(p_horde: Horde, p_index: int):
	horde = p_horde
	index = p_index
	generation = p_horde.generation_of(p_index)


func alive() -> bool:
	return horde != null and is_instance_valid(horde) and horde.is_alive(index) \
			and horde.generation_of(index) == generation
