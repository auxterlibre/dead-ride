class_name SettingsTab
extends Button

var selected: bool = false: set = set_selected
var tween: Tween

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func set_selected(p_value: bool):
	selected = p_value
	disabled = selected
	if selected:
		poke_anim(144.0, 0.0)


func _on_mouse_entered() -> void:
	if selected: return
	poke_anim(180.0, -36.0)


func _on_mouse_exited() -> void:
	if selected: return
	poke_anim(144.0, 0.0)


func poke_anim(p_size: float, p_position: float) -> void:
	if tween: tween.kill()
	tween = create_tween().set_parallel().set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "size:y", p_size, 0.15)
	tween.tween_property(self, "offset_transform_position:y", p_position, 0.15)
