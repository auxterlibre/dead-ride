class_name CoolArea
extends Area3D

func _ready():
	body_entered.connect(on_body_entered)
	body_exited.connect(on_body_exited)


func on_body_entered(p_body):
	if p_body is Character and p_body.heat:
		p_body.heat.enter_pocket(self)


func on_body_exited(p_body):
	if p_body is Character and p_body.heat:
		p_body.heat.leave_pocket(self)


# The pocket holds while its owner still vents; an owner with no opinion
# (a plain shade structure) vents whenever the heat is on.
func venting() -> bool:
	var holder: Node = get_parent()
	if holder and holder.has_method("venting"):
		return holder.venting()
	return is_instance_valid(Globals.heat) and Globals.heat.is_scorching()
