class_name CropData
extends Resource

@export var name: String
@export var grow_days: int = 3  # watered days from planting to the first fruit
@export var regrow_days: int = 3  # watered days between harvests
@export var produce: ItemData  # the ammo it fruits
@export var produce_count: Vector2i = Vector2i(15, 30)  # inclusive roll per harvest
@export var seed_item: ItemData  # the ordinary object this species grows from
@export var seed_count: int = 1  # units one planting consumes


func roll_produce() -> int:
	return randi_range(produce_count.x, maxi(produce_count.x, produce_count.y))
