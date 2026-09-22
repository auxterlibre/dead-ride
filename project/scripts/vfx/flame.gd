class_name Flame
extends MeshInstance3D

@export var flicker_amount:float = 0.25  # light energy wobble around base
@export var flicker_speed:float = 1.0

var burning: bool = false  # the state owners ask about; `visible` lags it by a fade
var fade:float = 1.0 : set = set_fade
var lights:Array[OmniLight3D] = []
var base_energies:Array[float] = []
var time:float = 0.0
var fade_tween:Tween

@onready var audio_ignite: AudioStreamPlayer3D = $AudioIgnite
@onready var audio_loop: AudioStreamPlayer3D = $AudioLoop



func _ready():
	for child in find_children("*", "OmniLight3D", true, false):
		lights.append(child)
		base_energies.append(child.light_energy)


func _process(delta):
	time += delta * flicker_speed
	for i in lights.size():
		var phase:float = time + i * 2.1
		var flicker:float = 1.0 + flicker_amount * (sin(phase * 9.3) * 0.5
				+ sin(phase * 23.7) * 0.3 + sin(phase * 5.1) * 0.2)
		lights[i].light_energy = base_energies[i] * fade * flicker


# Scales the flame VALUE through the shader, not its alpha.
func set_fade(p_value:float):
	fade = p_value
	set_instance_shader_parameter("fade", fade)


func fade_in(p_duration:float = 2.0):
	burning = true
	visible = true
	if fade_tween:
		fade_tween.kill()
	fade = 0.0
	fade_tween = create_tween()
	fade_tween.tween_property(self, "fade", 1.0, p_duration)
	audio_ignite.play()
	audio_loop.play()


func fade_out(p_duration:float = 1.0):
	burning = false
	if fade_tween:
		fade_tween.kill()
	fade_tween = create_tween()
	fade_tween.tween_property(self, "fade", 0.0, p_duration)
	fade_tween.tween_callback(func(): visible = false)
	audio_loop.stop()
