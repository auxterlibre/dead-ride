class_name InteractionMenu
extends Control

@export var button_scene: PackedScene

@onready var title_label: Label = %Title
@onready var options_box: VBoxContainer = %Options
@onready var scrim: ColorRect = %Scrim

var actions: Array = []  # {label, target, callback} rows currently shown


func _ready():
	hide()  # designed visible in the editor; never trust the saved flag
	Signals.interaction_menu_requested.connect(open)
	scrim.gui_input.connect(on_scrim_input)


func _unhandled_input(p_event: InputEvent):
	if not visible:
		return
	if p_event.is_action_pressed("pause_game") or p_event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif p_event is InputEventKey and p_event.pressed and not p_event.echo:
		var index: int = p_event.physical_keycode - KEY_1
		if index >= 0 and index < actions.size():
			get_viewport().set_input_as_handled()
			pick(index)


func open(p_title: String, p_actions: Array):
	title_label.text = p_title
	actions = p_actions
	for child in options_box.get_children():
		child.queue_free()
	var first: InputKeyButton = null
	for i in actions.size():
		var button: InputKeyButton = button_scene.instantiate()
		options_box.add_child(button)
		button.key_text = str(i + 1)
		button.action_text = actions[i].label
		button.pressed.connect(pick.bind(i))
		if first == null:
			first = button
	show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# A pad has no cursor to point: the first row starts focused, the dpad
	# walks, A picks. Deferred - a fresh button cannot take focus mid-add.
	if InputManager.pad_active and first:
		first.grab_focus.call_deferred()


func close():
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


# Close BEFORE the action: one that opens another screen (the sell counter)
# pauses again itself, and no frame passes in between.
func pick(p_index: int):
	var action: Dictionary = actions[p_index]
	close()
	# Rows may carry an argument; without one the callback gets the null that
	# every interaction callback already expects in the player's place.
	if is_instance_valid(action.target):
		action.target.call(action.callback, action.get("argument", null))


func on_scrim_input(p_event: InputEvent):
	if p_event is InputEventMouseButton and p_event.pressed:
		close()
