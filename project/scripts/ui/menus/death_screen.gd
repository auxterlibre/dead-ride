class_name DeathScreen
extends Control

const CORPSE_BEAT: float = 3.0

@onready var respawn_button: Button = %RespawnButton
@onready var quit_button: Button = %QuitButton

@onready var grayscale_effect: ColorRect = %GrayscaleEffect

@onready var scrim: ColorRect = %Scrim
@onready var title: Label = %Title

var grayscale_itensity: float : set = set_grayscale_intensity
var blur_intensity: float : set = set_blur_intensity

func _ready():
	hide() 
	respawn_button.pressed.connect(respawn)
	quit_button.pressed.connect(quit)
	Signals.player_died.connect(on_player_died)


func _unhandled_input(p_event: InputEvent):
	if visible and p_event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		respawn()


func on_player_died():
	grayscale_itensity = 0.0
	blur_intensity = 0.0  # the material may carry a value baked in the editor
	title.modulate.a = 0
	respawn_button.modulate.a = 0
	quit_button.modulate.a = 0
	scrim.modulate.a = 0
	show()
	
	var t := create_tween()
	t.tween_property(self, "grayscale_itensity", 1.0, 3.0)
	t.parallel().tween_property(scrim, "modulate:a", 1.0, 3.0).set_delay(1.0)
	t.parallel().tween_property(self, "blur_intensity", 2.0, 3.0).set_delay(1.0)
	t.tween_callback(func(): get_tree().paused = true)
	t.tween_property(title, "modulate:a", 1.0, 1.0)
	t.tween_property(respawn_button, "modulate:a", 1.0, 0.5)
	t.parallel().tween_property(quit_button, "modulate:a", 1.0, 0.5).set_delay(0.2)
	t.tween_callback(func(): Input.mouse_mode = Input.MOUSE_MODE_VISIBLE)


func respawn():
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	if not SaveManager.load_game():
		get_tree().reload_current_scene.call_deferred()


func quit() -> void:
	get_tree().quit()


# Both knobs drive the ONE combined shader; storing the value keeps reads
# (and tween start points) truthful.
func set_grayscale_intensity(p_value: float) -> void:
	grayscale_itensity = p_value
	grayscale_effect.material.set_shader_parameter("intensity", p_value)


func set_blur_intensity(p_value: float) -> void:
	blur_intensity = p_value
	grayscale_effect.material.set_shader_parameter("blur_amount", p_value)
