class_name LootEntryData
extends Resource
# One line of a LootTableData: what can come out, how likely, and how much.

@export var item: ItemData
@export var weight: float = 1.0  # relative to the table's other entries
@export var count: Vector2i = Vector2i(1, 1)  # inclusive draw range


func roll_count() -> int:
	return randi_range(count.x, maxi(count.x, count.y))
