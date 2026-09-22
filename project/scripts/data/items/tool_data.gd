class_name ToolData
extends ItemData
# A carried tool; `repair_amount` is the share of a vehicle's hull one use restores.

@export_range(0, 100) var repair_amount: int = 0  # % of max hull per use


func get_category_label() -> String:
	return "Tool"


func get_stat_lines() -> Array:
	if repair_amount <= 0:
		return []
	return [["Repairs", "%d%%" % repair_amount]]
