class_name FuelCanData
extends ItemData
# A jerry can: carries liters out of the pump and onto the crops - the GDD's
# land drinks fuel, not water. The fill is live per-instance state, so a can
# follows the weapon rule: always duplicated, never stacked.

@export var capacity: float = 10.0  # liters

var current_fuel: float = 0.0


func space() -> float:
	return maxf(capacity - current_fuel, 0.0)


# Returns what was actually accepted, so the pump only drains what fits.
func add_fuel(p_liters: float) -> float:
	var accepted: float = clampf(p_liters, 0.0, space())
	current_fuel += accepted
	return accepted


# Returns what was actually granted, so a watering never overdraws the can.
func drain(p_liters: float) -> float:
	var granted: float = clampf(p_liters, 0.0, current_fuel)
	current_fuel -= granted
	return granted


func has_own_state() -> bool:
	return true


func get_category_label() -> String:
	return "Tool"


func get_stat_lines() -> Array:
	return [["Fuel", "%.1f / %.0f L" % [current_fuel, capacity]]]
