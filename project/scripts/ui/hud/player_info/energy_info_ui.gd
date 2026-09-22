class_name EnergyInfoUI
extends HBoxContainer
# The energy bar under the health bar, fed by Signals.energy_updated.

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var value_label: Label = $ProgressBar/ValueLabel


func _ready():
	Signals.energy_updated.connect(on_energy_updated)
	Signals.player_died.connect(fade_out)
	visible = true  # designed hidden so the editor mock doesn't ship a stale bar


func on_energy_updated(p_current: float, p_max: float):
	progress_bar.max_value = p_max
	var tween: Tween = create_tween()
	tween.tween_property(progress_bar, "value", p_current, 0.1)
	value_label.text = "%d/%d" % [roundi(p_current), roundi(p_max)]


func fade_out() -> void:
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	t.tween_callback(hide)


func fade_in() -> void:
	self.modulate.a = 0
	show()
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.3)
