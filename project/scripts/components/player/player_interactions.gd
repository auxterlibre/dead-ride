class_name PlayerInteractions
extends Node

@export var notice_range: float = 6.0  # m - how far off an offer is worth a dot

@onready var player: Character = get_parent()


func _ready():
	Signals.drive_state_changed.connect(on_drive_state_changed)


func _process(_delta: float):
	sweep(notice_range)


# Driving disables the player, freezing the sweep mid-advert.
func on_drive_state_changed(p_is_driving: bool):
	if p_is_driving:
		sweep(0.0)


func sweep(p_range: float):
	var here: Vector3 = player.global_position
	# Backwards: a static registry outlives the scene that filled it.
	for i in range(InteractiveArea.offers.size() - 1, -1, -1):
		var offer: InteractiveArea = InteractiveArea.offers[i]
		if not is_instance_valid(offer):
			InteractiveArea.offers.remove_at(i)
			continue
		var to_offer: Vector3 = offer.global_position - here
		to_offer.y = 0.0
		var near: bool = to_offer.length() <= p_range
		if not near and not offer.player_near:
			continue
		offer.player_near = near
		offer.update_stage()
