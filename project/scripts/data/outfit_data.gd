class_name OutfitData
extends Resource

@export var parts: PackedStringArray = []


static func slot_of(p_part: String) -> String:
	var tokens: PackedStringArray = p_part.split("_")
	var slot: String = tokens[0]
	for token in tokens:
		if token.length() > 1 and not token.is_valid_int():
			slot = token
	return slot
