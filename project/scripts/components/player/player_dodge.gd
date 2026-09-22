class_name PlayerDodge
extends CharacterDodge
# Input layer over CharacterDodge: SPACE, and the two things only a player can
# be in the middle of. Everything about the roll itself lives in the base.


func _process(p_delta:float):
	super(p_delta)
	if not get_tree().paused and Input.is_action_just_pressed("dodge"):
		dodge()


func can_dodge() -> bool:
	if not super():
		return false
	# A barrel in the arms is both hands: the same refusal drinking makes.
	for child in get_parent().get_children():
		if child is PlayerCarry and child.carrying:
			return false
	return true


func dodge() -> bool:
	# A roll spills the drink, exactly like taking a hit does.
	if can_dodge():
		for child in get_parent().get_children():
			if child is PlayerConsume:
				child.cancel_use()
	return super()
