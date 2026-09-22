class_name ItemTooltip
extends PanelContainer
# The selected item's card. Every line comes from ItemData virtuals, so a new
# item kind needs no change here.

@export var stat_row_scene: PackedScene

@onready var name_label: Label = %NameLabel
@onready var rarity_label: Label = %RarityLabel
@onready var category_label: Label = %CategoryLabel
@onready var stat_list: VBoxContainer = %StatList


func show_item(p_item: ItemData):
	hide()
	reset_size()
	if p_item == null: return
	name_label.text = p_item.name.to_upper()
	rarity_label.visible = false
	category_label.text = p_item.get_category_label()
	for child in stat_list.get_children():
		child.queue_free()
	for line in p_item.get_stat_lines():
		var row: Control = stat_row_scene.instantiate()
		stat_list.add_child(row)
		row.get_node("Label").text = str(line[0])
		row.get_node("Value").text = str(line[1])
	await get_tree().process_frame
	show()


# Sits to the right of the item it describes, nudged back on screen if the
# card would run off the bottom.
func place_beside(p_rect: Rect2):
	var target: Vector2 = Vector2(p_rect.end.x + 16.0, p_rect.position.y)
	var limit: Vector2 = get_viewport_rect().size - size
	global_position = target.clamp(Vector2.ZERO, limit)
