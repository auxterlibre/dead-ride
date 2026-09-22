class_name SettingsRowList
extends HBoxContainer

signal value_changed(index: int)

@onready var label: Label = %Label
@onready var prev_button: Button = %PrevButton
@onready var value_label: Label = %ValueLabel
@onready var next_button: Button = %NextButton

var options: Array = []
var index: int = 0


func _ready():
	prev_button.pressed.connect(cycle.bind(-1))
	next_button.pressed.connect(cycle.bind(1))


func setup(p_title: String, p_options: Array, p_index: int = 0):
	label.text = p_title
	options = p_options
	select(p_index)


func select(p_index: int):
	index = clampi(p_index, 0, maxi(options.size() - 1, 0))
	value_label.text = str(options[index]) if index < options.size() else ""


func cycle(p_step: int):
	if options.size() < 2:
		return
	select(posmod(index + p_step, options.size()))
	value_changed.emit(index)


func set_enabled(p_value: bool):
	prev_button.disabled = not p_value
	next_button.disabled = not p_value
	modulate.a = 1.0 if p_value else 0.4
