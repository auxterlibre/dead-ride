class_name InventoryEntry
extends RefCounted
# One stack: what it is, how many, and where its top-left cell sits. An entry
# lives in a grid OR on a quick slot - slot entries carry NO_CELL, because the
# slots are storage of their own, not references into the grid.

const NO_CELL: Vector2i = Vector2i(-1, -1)  # not placed in any grid

var item: ItemData
var origin: Vector2i
var count: int = 1  # rounds in this stack; always 1 for non-stackables


func _init(p_item: ItemData = null, p_origin: Vector2i = Vector2i.ZERO,
		p_count: int = 1):
	item = p_item
	origin = p_origin
	count = p_count


func free_space() -> int:
	return item.get_max_stack() - count


# Every cell this entry covers, row-major from its origin.
func cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in item.size.y:
		for x in item.size.x:
			result.append(origin + Vector2i(x, y))
	return result
