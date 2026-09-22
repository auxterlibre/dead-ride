class_name AmmoData
extends ItemData
# A stack of rounds. One grid cell whatever the calibre; how MANY fit in that
# cell is what differs - heavy rounds are bulky, light ones are not.

const MAX_STACK: Dictionary = {
	Enums.AmmoType.LIGHT: 80,
	Enums.AmmoType.MEDIUM: 60,
	Enums.AmmoType.HEAVY: 20,
	Enums.AmmoType.SHOTGUN: 30,
}

@export var ammo_type: Enums.AmmoType = Enums.AmmoType.LIGHT


func get_max_stack() -> int:
	return MAX_STACK[ammo_type]


func get_category_label() -> String:
	return "%s ammo" % Enums.AmmoType.keys()[ammo_type].capitalize()


func get_stat_lines() -> Array:
	return [["Calibre", Enums.AmmoType.keys()[ammo_type].capitalize()],
			["Rounds per slot", get_max_stack()]]
