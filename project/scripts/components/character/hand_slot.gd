class_name HandSlot
extends BoneAttachment3D

@export var grip: Transform3D = Transform3D.IDENTITY
@export var grip_one_handed: Transform3D = Transform3D.IDENTITY

var weapon:Weapon = null


# Characters are authored holding a weapon for the editor pose; nothing owns it at runtime.
func _ready():
	for child in get_children():
		remove_child(child)
		child.queue_free()


func activate():
	if weapon:
		if weapon.has_method("set_active"):
			weapon.set_active(true)
		elif weapon.has_method("shoot"):
			weapon.shoot()


func deactivate():
	if weapon and weapon.has_method("set_active"):
		weapon.set_active(false)


func set_weapon(p_weapon:Weapon, p_character:CharacterBody3D, p_layer:int,
		p_one_handed: bool = false):
	if weapon != null:
		remove_old_weapon(weapon)
	weapon = p_weapon
	add_child(weapon)
	weapon.transform = grip_one_handed if p_one_handed else grip
	weapon.character = p_character
	weapon.layer = p_layer


func remove_old_weapon(p_weapon:Weapon):
	p_weapon.visible = false
	await get_tree().create_timer(1.0).timeout
	p_weapon.queue_free()
