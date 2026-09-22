class_name WeaponMelee
extends Weapon

@onready var hit_box:HitBox = $HitBox

var character:CharacterBody3D:
	set(p_value):
		hit_box.character = p_value


func set_layer(p_value):
	super.set_layer(p_value)
	hit_box.collision_layer = p_value


func set_active(p_value:bool):
	hit_box.monitorable = p_value
