class_name ConsumableData
extends ItemData
# Restores the body: health, energy, or both. Buffs once that system lands.

@export var health: int = 0  # real hit points, the scale max_health uses
@export var energy: int = 0  # real energy points, on PlayerEnergy's 0-100 scale
@export_range(1, 9) var max_stack: int = 5  # real count: how many ride one cell
@export var use_audio: AudioStream  # the act's sound (a gulp, a wrap); null is silent


func get_max_stack() -> int:
	return max_stack


# A consumable with a body rides the hand while selected (the water bottle),
# so the use_item clip has something to drink from; one without (the bandage)
# leaves the hands as they were, like any carried item.
func get_held_scene() -> PackedScene:
	return model


func get_category_label() -> String:
	return "Consumable"


func get_stat_lines() -> Array:
	var lines: Array = []
	if health > 0:
		lines.append(["Restores", "%d HP" % health])
	if energy > 0:
		lines.append(["Energy", "+%d" % energy])
	return lines
