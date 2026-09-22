class_name InventoryItemUI
extends Panel

var entry: InventoryEntry
var selected: bool = false
var invalid: bool = false  # dragged over a spot it can't go

var icon: TextureRect
var hover: Panel
var count_label: Label
var placeholder: Label


func _ready():
	resolve_nodes()


# The drag preview is built and filled in BEFORE it enters the tree, so @onready
# would still be null here; get_node works the moment instantiate() returns.
func resolve_nodes():
	if icon != null:
		return
	icon = $Icon
	hover = $Hover
	count_label = $Count
	placeholder = $Placeholder


func setup(p_entry: InventoryEntry, p_cell: int):
	resolve_nodes()
	entry = p_entry
	icon.texture = p_entry.item.icon
	size = Vector2(p_entry.item.size) * p_cell
	position = Vector2(p_entry.origin) * p_cell
	# Items without art yet read as a named block rather than an empty one.
	placeholder.visible = p_entry.item.icon == null
	placeholder.text = p_entry.item.name
	refresh_count()
	set_selected(false)


func refresh_count():
	count_label.visible = entry.count > 1
	count_label.text = str(entry.count)


func set_selected(p_selected: bool):
	selected = p_selected
	refresh_border()


func set_invalid(p_invalid: bool):
	invalid = p_invalid
	refresh_border()


# An item carries NO frame of its own - the border is the hover state and the
# only refusal channel left, now that there is no backing to turn red. The
# StyleBox is authored white so self_modulate alone picks the colour.
func refresh_border():
	hover.visible = selected or invalid
	hover.self_modulate = LivePalette.RED if invalid else LivePalette.LIGHT_BLUE
