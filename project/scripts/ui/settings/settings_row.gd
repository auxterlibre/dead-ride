class_name SettingsRow
extends Control

enum Kind {LIST, SLIDER, HEADER}

signal value_changed(value)

@onready var wash: TextureRect = %Wash
@onready var label: Label = %Label
@onready var header_label: Label = %HeaderLabel
@onready var list_control: Control = %ListControl
@onready var slider_control: Control = %SliderControl
@onready var prev_button: Button = %PrevButton
@onready var next_button: Button = %NextButton
@onready var value_label: Label = %ValueLabel
@onready var slider: HSlider = %Slider
@onready var slider_value: Label = %SliderValue
@onready var divider: ColorRect = %Divider

var kind: Kind = Kind.LIST
var labels: Array = []
var index: int = 0
var enabled: bool = true
var hovered: bool = false
var focused: bool = false  # the pad's hover; the screen assigns it


func _ready():
	prev_button.pressed.connect(func(): step(-1))
	next_button.pressed.connect(func(): step(1))
	slider.value_changed.connect(on_slider_moved)
	# The row is the focus unit - its own widgets joining the chain would let
	# the dpad land on an arrow and strand the up/down walk.
	prev_button.focus_mode = FOCUS_NONE
	next_button.focus_mode = FOCUS_NONE
	slider.focus_mode = FOCUS_NONE


# Rect test, not mouse_entered/exited: a child that takes the mouse becomes the
# hovered Control and the row would get mouse_exited onto its own arrows.
func _process(_delta: float):
	var hot: bool = visible and get_global_rect().has_point(get_global_mouse_position())
	if hot != hovered:
		hovered = hot
		refresh_state()


func setup_header(p_title: String):
	kind = Kind.HEADER
	header_label.text = p_title.to_upper()
	apply_kind()


func setup_list(p_title: String, p_labels: Array, p_index: int):
	kind = Kind.LIST
	label.text = p_title
	labels = p_labels
	index = clampi(p_index, 0, maxi(p_labels.size() - 1, 0))
	value_label.text = str(labels[index]) if not labels.is_empty() else ""
	apply_kind()


func setup_slider(p_title: String, p_value: float):
	kind = Kind.SLIDER
	label.text = p_title
	slider.set_value_no_signal(p_value * 100.0)
	slider_value.text = "%d%%" % roundi(p_value * 100.0)
	apply_kind()


func apply_kind():
	header_label.visible = kind == Kind.HEADER
	label.visible = kind != Kind.HEADER
	list_control.visible = kind == Kind.LIST
	slider_control.visible = kind == Kind.SLIDER
	divider.visible = kind != Kind.HEADER
	mouse_filter = MOUSE_FILTER_IGNORE if kind == Kind.HEADER else MOUSE_FILTER_PASS
	refresh_state()


func set_enabled(p_value: bool):
	enabled = p_value
	prev_button.disabled = not p_value
	next_button.disabled = not p_value
	slider.editable = p_value
	refresh_state()


func set_focused(p_value: bool):
	focused = p_value
	refresh_state()


# One step of the row's own control, whichever kind it is - what the pad's
# left/right means while the row is focused. Sliders move in 5% notches.
func nudge(p_delta: int):
	if kind == Kind.LIST:
		step(p_delta)
	elif kind == Kind.SLIDER:
		slider.value = clampf(slider.value + p_delta * 5.0, 0.0, 100.0)


func refresh_state():
	var hot: bool = enabled and kind != Kind.HEADER and (hovered or focused)
	wash.visible = hot
	prev_button.visible = hot
	next_button.visible = hot
	slider.visible = hot
	var dim: float = 1.0 if enabled else 0.4
	label.modulate.a = dim
	value_label.modulate.a = dim
	slider_control.modulate.a = dim


func step(p_delta: int):
	if labels.is_empty():
		return
	index = wrapi(index + p_delta, 0, labels.size())
	value_label.text = str(labels[index])
	value_changed.emit(index)


func on_slider_moved(p_value: float):
	slider_value.text = "%d%%" % roundi(p_value)
	value_changed.emit(p_value / 100.0)
