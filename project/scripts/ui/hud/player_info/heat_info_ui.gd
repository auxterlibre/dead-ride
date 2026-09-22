extends Label


func _ready() -> void:
	Signals.heat_burning_changed.connect(on_burning_changed)
	Signals.player_died.connect(fade_out)
	visible = false


func on_burning_changed(p_burning: bool) -> void:
	if p_burning: fade_in()
	else: fade_out()


func fade_out() -> void:
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	t.tween_callback(hide)


func fade_in() -> void:
	self.modulate.a = 0
	show()
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.3)
