class_name HeatWave
extends Node

const SCORCH_START: float = 10.0  # clock hours - the GDD's window
const SCORCH_END: float = 16.0
const SHOULDER: float = 0.5  # hours of visual ramp outside the window
const POCKET_HAZE: float = 0.12  # haze share left inside a cold pocket

@export var haze: ColorRect  # the screen shimmer; unwired (the gym) = no visuals

var haze_level: float = 0.0


func _ready():
	Globals.heat = self


func _process(p_delta: float):
	if haze == null:
		return
	var target: float = intensity()
	if target > 0.0 and player_sheltered():
		target *= POCKET_HAZE  # the cold pocket stills the air on screen
	haze_level = lerpf(haze_level, target, minf(p_delta * 3.0, 1.0))
	haze.visible = haze_level > 0.01
	haze.material.set_shader_parameter("intensity", haze_level)


func player_sheltered() -> bool:
	return is_instance_valid(InputManager.player) \
			and InputManager.player.heat != null \
			and InputManager.player.heat.sheltered()


# Shouldered outside the window, so the shimmer leads the burn in and out.
func intensity() -> float:
	var hour: float = clock_hour()
	if hour < SCORCH_START:
		return clampf(remap(hour, SCORCH_START - SHOULDER, SCORCH_START, 0.0, 1.0),
				0.0, 1.0)
	if hour < SCORCH_END:
		return 1.0
	return clampf(remap(hour, SCORCH_END, SCORCH_END + SHOULDER, 1.0, 0.0), 0.0, 1.0)


func is_scorching() -> bool:
	var hour: float = clock_hour()
	return hour >= SCORCH_START and hour < SCORCH_END


func clock_hour() -> float:
	return Calendar.get_day_fraction() * 24.0
