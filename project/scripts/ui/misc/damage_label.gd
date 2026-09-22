extends Label3D


func animate(p_final_y:float):
	var tween:Tween = create_tween()
	tween.tween_property(self, "position:y", p_final_y, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "transparency", 1.0, 0.5)
	tween.tween_callback(queue_free)
