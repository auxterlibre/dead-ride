class_name InputKeyButton
extends Button

const PRESS_SCALE: float = 0.9  # the Pressed variant is Hover at 0.9
const BADGE_DIM: float = 0.30  # disabled badge and action text
const KEY_DIM: float = 0.60
const KEY_ALIASES: Dictionary = {"ESCAPE": "ESC"}

# An input_action wins over key_text, so a rebind moves the badge with it.
@export var input_action: String = "": set = set_input_action
@export var key_text: String = "TAB": set = set_key_text
@export var action_text: String = "Close": set = set_action_text

@onready var content: MarginContainer = %Content
@onready var key_icon: TextureRect = %KeyIcon
@onready var key_label: Label = %KeyLabel
@onready var action_label: Label = %ActionLabel
@onready var badge_lit: StyleBox = key_label.get_theme_stylebox("normal")
@onready var badge_dim: StyleBox = dimmed_badge()

var was_disabled: bool = false


func _ready():
	# A Button sizes itself from its own text, never from child controls, so the
	# content's minimum has to be pushed back onto it.
	content.minimum_size_changed.connect(fit_to_content)
	resized.connect(centre_pivot)
	button_down.connect(func(): scale = Vector2.ONE * PRESS_SCALE)
	button_up.connect(func(): scale = Vector2.ONE)
	Signals.input_device_changed.connect(func(_p_pad: bool): refresh())
	refresh()
	fit_to_content()
	centre_pivot()


# Button has no signal for `disabled`, and callers set it as a plain property -
# polling one bool keeps the badge honest without anyone remembering to ask.
func _process(_delta: float):
	if disabled != was_disabled:
		was_disabled = disabled
		apply_state()


func set_input_action(p_value: String):
	input_action = p_value
	refresh()


func set_key_text(p_value: String):
	key_text = p_value
	refresh()


func set_action_text(p_value: String):
	action_text = p_value
	refresh()


# The pad's own art when the kit has it, the lettered badge otherwise - one or
# the other, never both: the icons ARE badges, cream disc and all.
func refresh():
	if not is_node_ready():
		return
	key_icon.texture = resolved_icon()
	key_icon.visible = key_icon.texture != null
	key_label.visible = key_icon.texture == null
	key_label.text = resolved_key()
	action_label.text = action_text
	apply_state()


# The badge and the labels are child controls, so the Button's own state
# styleboxes never reach them - the disabled look is applied by hand.
func apply_state():
	key_label.add_theme_stylebox_override("normal", badge_dim if disabled else badge_lit)
	key_label.add_theme_color_override("font_color",
			Color(Palette.BLUE, KEY_DIM) if disabled else Palette.BLUE)
	# The icon carries its own colours, so it dims by going see-through.
	key_icon.modulate.a = BADGE_DIM if disabled else 1.0
	action_label.add_theme_color_override("font_color",
			Color(Palette.WHITE, BADGE_DIM) if disabled else Palette.WHITE)


func dimmed_badge() -> StyleBox:
	var box: StyleBoxFlat = badge_lit.duplicate()
	box.bg_color = Color(Palette.WHITE, BADGE_DIM)
	return box


func fit_to_content():
	custom_minimum_size = content.get_combined_minimum_size()


func centre_pivot():
	pivot_offset = size / 2.0


func resolved_key() -> String:
	if input_action.is_empty():
		return alias(key_text)
	return alias(InputManager.key_for(input_action))


# key_text is the badge a caller set by hand; it still names a control, so it
# earns the pad's art the same way a bound action does.
func resolved_icon() -> Texture2D:
	if input_action.is_empty():
		return InputManager.icon_for_key(alias(key_text))
	return InputManager.icon_for(input_action)


func alias(p_key: String) -> String:
	var upper: String = p_key.to_upper()
	return KEY_ALIASES.get(upper, upper)
