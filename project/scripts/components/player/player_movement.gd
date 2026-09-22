class_name PlayerMovement
extends CharacterMovement
# Input layer over CharacterMovement: WASD direction, sneak toggle,
# sprint hold. All the actual locomotion lives in the base.


func gather_intent():
	var input:Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if Input.is_action_just_pressed("crouch"):
		is_sneaking = not is_sneaking
	is_sprinting = Input.is_action_pressed("sprint") and not is_sneaking \
			and sprint_allowed
	move_direction = Vector3(input.x, 0.0, input.y) * shaped(input.length())


func shaped(p_strength:float) -> float:
	if p_strength <= 0.0:
		return 0.0
	return pow(p_strength, Settings.move_curve_value()) / p_strength
