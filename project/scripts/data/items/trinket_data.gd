class_name TrinketData
extends ItemData
# Scavenged junk. It does nothing but carry a price - the whole point is to
# find it out in the desert and sell it to the delivery truck.

func get_category_label() -> String:
	return "Trinket"


func get_stat_lines() -> Array:
	return [["Value", "$%d" % price]]
