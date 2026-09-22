class_name LootTableData
extends Resource
# A weighted bag of items a container fills itself from. Weights are relative,
# so adding an entry never means re-tuning the rest.

@export var entries: Array[LootEntryData] = []
@export var draws: Vector2i = Vector2i(2, 4)  # how many entries one container rolls


func roll_draws() -> int:
	return randi_range(draws.x, maxi(draws.x, draws.y))


# Weighted pick. Entries with no item or no weight can never come up.
func draw() -> LootEntryData:
	var total: float = 0.0
	for entry in entries:
		if entry and entry.item:
			total += maxf(entry.weight, 0.0)
	if total <= 0.0:
		return null
	var target: float = randf() * total
	for entry in entries:
		if entry == null or entry.item == null:
			continue
		target -= maxf(entry.weight, 0.0)
		if target <= 0.0:
			return entry
	return null
