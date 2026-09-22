class_name ContextMenu
extends Control
# The grid's right-click menu: a cursor-anchored list of what the stack under
# the cursor can do right now. Rows are the same numbered InputKeyButtons the
# interaction menu builds, so 1..N pick as well as clicks. The screen behind
# is already paused - this adds no pause juggling of its own.

@export var button_scene: PackedScene

@onready var panel: PanelContainer = %Panel
@onready var options_box: VBoxContainer = %Options

var actions: Array = []  # {label, callback: Callable} rows currently shown


func _ready():
	hide()  # designed visible in the editor; never trust the saved flag


func _gui_input(p_event: InputEvent):
	# The full-rect self is the click-away catcher.
	if p_event is InputEventMouseButton and p_event.pressed:
		accept_event()
		close()


func _unhandled_input(p_event: InputEvent):
	if not visible:
		return
	if p_event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif p_event is InputEventKey and p_event.pressed and not p_event.echo:
		var index: int = p_event.physical_keycode - KEY_1
		if index >= 0 and index < actions.size():
			get_viewport().set_input_as_handled()
			pick(index)


func open(p_at: Vector2, p_actions: Array):
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
	if InputManager.pad_active and first:
		first.grab_focus.call_deferred()
	show()
	# Sized after the layout pass, then clamped so the panel never leaves the
	# screen - a click near the right edge opens leftward, not offscreen.
	await get_tree().process_frame
	panel.position = Vector2(
			minf(p_at.x, size.x - panel.size.x - 16.0),
			minf(p_at.y, size.y - panel.size.y - 16.0))


func close():
	hide()
	actions = []


# Close BEFORE the action, the interaction menu's rule: an action that closes
# the whole screen (Consume) must not find the menu still up.
func pick(p_index: int):
	var action: Dictionary = actions[p_index]
	close()
	action.callback.call()
