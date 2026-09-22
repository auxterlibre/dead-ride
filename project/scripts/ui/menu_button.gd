class_name MenuActionButton
extends Button

@export var primary: bool = false: set = set_primary


func _ready():
	apply_fill()


func set_primary(p_value: bool):
	primary = p_value
	if is_node_ready():
		apply_fill()


func apply_fill():
	var box: StyleBoxFlat = get_theme_stylebox("normal").duplicate()
	box.bg_color = Palette.CYAN if primary else Palette.KHAKI
	add_theme_stylebox_override("normal", box)
	var lit: StyleBoxFlat = box.duplicate()
	lit.bg_color = box.bg_color.lightened(0.12)
	add_theme_stylebox_override("hover", lit)
	# Pad focus reads as the hover it replaces - one lit look, either device.
	add_theme_stylebox_override("focus", lit)
	var pushed: StyleBoxFlat = box.duplicate()
	pushed.bg_color = box.bg_color.darkened(0.12)
	add_theme_stylebox_override("pressed", pushed)
	var off: StyleBoxFlat = box.duplicate()
	off.bg_color = Color(box.bg_color, 0.45)
	add_theme_stylebox_override("disabled", off)
