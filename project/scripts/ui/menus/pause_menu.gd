class_name PauseMenu
extends Control


@onready var resume_button: MenuActionButton = %ResumeButton
@onready var settings_button: MenuActionButton = %SettingsButton
@onready var menu_button: MenuActionButton = %MainMenuButton
@onready var quit_button: MenuActionButton = %QuitButton

@export var settings: SettingsScreen


func _ready():
	hide()
	resume_button.pressed.connect(close)
	settings_button.pressed.connect(open_settings)
	quit_button.pressed.connect(get_tree().quit)
	menu_button.disabled = true
	menu_button.tooltip_text = "No main menu yet"


func _unhandled_input(p_event: InputEvent):
	if InputManager.player and InputManager.player.is_dead:
		return
	if settings and settings.visible:
		return
	# ui_cancel is ESC and the pad's B in one action; pause_game is ESC and
	# START - together the pad closes with either shoulder of habit.
	if visible and p_event.is_action_pressed("ui_cancel") \
			and not p_event.is_action_pressed("pause_game"):
		get_viewport().set_input_as_handled()
		close()
		return
	if not p_event.is_action_pressed("pause_game"):
		return
	get_viewport().set_input_as_handled()
	if visible:
		close()
	else:
		open()


func open():
	show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if InputManager.pad_active:
		resume_button.grab_focus.call_deferred()


func close():
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func open_settings():
	if settings == null:
		return
	hide()
	settings.open()
	await settings.closed
	show()
	if InputManager.pad_active:
		settings_button.grab_focus.call_deferred()
