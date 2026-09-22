class_name AttackData
extends Resource

var damage:int
var knockback_origin:Vector3
var knockback_distance:float
var attacker:Node3D  # a character, or the vehicle that rammed

func _init(p_damage:int, p_knockback_origin:Vector3, p_knockback_distance:float, p_attacker:Node3D):
	damage = p_damage
	knockback_origin = p_knockback_origin
	knockback_distance = p_knockback_distance
	attacker = p_attacker
