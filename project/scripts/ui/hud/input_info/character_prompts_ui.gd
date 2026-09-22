class_name CharacterPromptsUI
extends Control

const ANCHOR_HEIGHT: float = 1.2  # m up the player's body the prompts point at
const SCREEN_OFFSET: Vector2 = Vector2(112, -48)  # px right of, and up from, them
const EDGE_MARGIN: float = 32.0

@export var button_scene: PackedScene

@onready var column: VBoxContainer = %Column

var buttons: Dictionary = {}  # keys Array -> InputKeyButton


func _ready():
	Signals.input_info_added.connect(add_prompt)
	Signals.input_info_removed.connect(remove_prompt)


func _process(_delta: float):
	var camera: Camera3D = get_viewport().get_camera_3d()
	var player: Character = InputManager.player
	# Every screen pauses, so paused means a menu is up and the world's offers
	# have no business floating behind it. Needs PROCESS_MODE_ALWAYS to see it.
	visible = not get_tree().paused and not buttons.is_empty() \
			and camera != null and player != null
	if not visible:
		return
	# unproject rather than a Sprite3D: these are the same Control-based buttons
	# the screens use, and they stay crisp at any camera distance.
	var anchor: Vector3 = player.global_position + Vector3.UP * ANCHOR_HEIGHT
	if camera.is_position_behind(anchor):
		visible = false
		return
	column.position = clamped(camera.unproject_position(anchor) + SCREEN_OFFSET)


func add_prompt(p_keys: Array, p_label: String, p_placement: int,
		p_input_action: String):
	if p_placement != Enums.PromptPlacement.CHARACTER or button_scene == null:
		return
	var button: InputKeyButton = buttons.get(p_keys)
	if button == null:
		button = button_scene.instantiate()
		# A world prompt is clicked or keyed, never dpad-walked: joining the
		# focus chain would let a menu's navigation wander out into the HUD.
		button.focus_mode = Control.FOCUS_NONE
		column.add_child(button)
		buttons[p_keys] = button
		button.pressed.connect(func(): InputManager.try_to_interact(p_input_action))
		# The weapon polls its trigger, so the GUI swallowing the click is not
		# enough on its own - the player has to be told to hold fire.
		button.mouse_entered.connect(func(): InputManager.pointer_over_prompt = true)
		button.mouse_exited.connect(func(): InputManager.pointer_over_prompt = false)
	button.key_text = p_keys[0] if not p_keys.is_empty() else ""
	# The ACTION as well as the resolved key: a prompt that knows which control
	# it names can re-badge itself when the pad comes and goes, art and all.
	button.input_action = p_input_action
	button.action_text = p_label


func remove_prompt(p_keys: Array):
	if not buttons.has(p_keys):
		return
	var button: InputKeyButton = buttons[p_keys]
	# The cursor never gets an exit once the button is gone under it.
	if button.is_hovered():
		InputManager.pointer_over_prompt = false
	button.queue_free()
	buttons.erase(p_keys)


func clamped(p_position: Vector2) -> Vector2:
	var span: Vector2 = size - column.size - Vector2.ONE * EDGE_MARGIN
	return p_position.clamp(Vector2.ONE * EDGE_MARGIN, span.max(Vector2.ONE * EDGE_MARGIN))
