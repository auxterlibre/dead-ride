class_name VehicleInfoUI
extends VBoxContainer

@onready var speed_label: Label = %SpeedLabel
@onready var fuel_bar: ProgressBar = %FuelBar
@onready var car_health_bar: ProgressBar = %CarHealthBar


func _ready() -> void:
	Signals.drive_state_changed.connect(on_drive_state_changed)
	Signals.vehicle_speed_updated.connect(update_speed)
	Signals.vehicle_fuel_updated.connect(update_fuel)
	Signals.vehicle_health_updated.connect(update_health)
	Signals.player_died.connect(fade_out)
	visible = false


func update_speed(p_speed: float) -> void:
	speed_label.text = Settings.format_speed(p_speed)


func update_fuel(p_current: float, p_max: float) -> void:
	fuel_bar.max_value = p_max
	fuel_bar.value = p_current


func update_health(p_current: float, p_max: float) -> void:
	car_health_bar.max_value = p_max
	car_health_bar.value = p_current


func on_drive_state_changed(p_driving) -> void:
	if p_driving: fade_in()
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
