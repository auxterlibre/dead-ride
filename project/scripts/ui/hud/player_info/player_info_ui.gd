class_name PlayerInfoUI
extends HBoxContainer

@onready var progress_bar:ProgressBar = $ProgressBar
@onready var hp_label:Label = $ProgressBar/HPLabel


var _target_hp

func _ready():
	Signals.health_updated.connect(_on_health_updated)
	Signals.player_died.connect(fade_out)
	visible = true


func _on_health_updated(p_current, p_max):
	progress_bar.max_value = p_max
	_target_hp = float(p_current)
	var tween:Tween = create_tween()
	tween.tween_property(progress_bar, "value", p_current, 0.1 * (progress_bar.value - p_current))


func _process(_delta):
	hp_label.text = "%s/%s" % [int(progress_bar.value), int(progress_bar.max_value)]


func fade_out() -> void:
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	t.tween_callback(hide)


func fade_in() -> void:
	self.modulate.a = 0
	show()
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.3)
