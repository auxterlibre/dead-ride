class_name BuildableData
extends Resource

@export var name: String
@export var scene: PackedScene  # what gets placed
@export var footprint: Vector2i = Vector2i.ONE  # cells, before rotation
@export var price: int = 0
@export var icon: Texture2D
