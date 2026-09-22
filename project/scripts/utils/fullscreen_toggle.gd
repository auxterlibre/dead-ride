class_name FullscreenToggle
extends Node
# F11 over the persisted Settings.fullscreen, so key and menu can't disagree.

@export var input_action: String = "fullscreen_toggle"


func _input(_event):
	if Input.is_action_just_pressed(input_action):
		Settings.fullscreen = not Settings.fullscreen
