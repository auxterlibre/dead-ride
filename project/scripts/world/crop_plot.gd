class_name CropPlot
extends Node3D

@export var crop_scene: PackedScene  # scenes/props/crop.tscn
@export var species: Array[CropData] = []  # what this plot grows, in offer order
@export var water_liters: float = 1.0  # fuel one watering drinks - the GDD's cost

var spots: Array[Marker3D] = []
var crops: Dictionary = {}  # spot index -> Crop


func _ready():
	add_to_group("persistent")
	for child in get_children():
		if child is Marker3D:
			spots.append(child)
			if child is CropSpot:
				child.plot = self
				child.index = spots.size() - 1
	# A bound method, not a lambda - the bus outlives scene reloads.
	Signals.inventory_changed.connect(on_inventory_changed)
	refresh_spots()


func on_inventory_changed(_p_inventory):
	refresh_spots()


func refresh_spots():
	for spot in spots:
		if spot is CropSpot:
			spot.refresh_offers()


# Planting claims an empty spot; a dead plant is cleared and replaced.
func plant(p_data: CropData, p_spot: int) -> Crop:
	if p_data == null or p_spot < 0 or p_spot >= spots.size():
		return null
	var standing: Crop = crops.get(p_spot)
	if is_instance_valid(standing):
		if not standing.dead:
			return null  # the spot is taken by a living plant
		standing.queue_free()
	var crop: Crop = crop_scene.instantiate()
	add_child(crop)
	crop.global_position = spots[p_spot].global_position
	crop.setup(p_data)
	crops[p_spot] = crop
	if spots[p_spot] is CropSpot:
		crop.changed.connect(spots[p_spot].refresh_offers)
		spots[p_spot].refresh_offers()
	return crop


# `species` is now the plot's OFFER, not its ranking: the planting panel walks
# it to name what the rounds in its slot would grow, and hands back the one the
# player picked. The plot used to choose for them, taking the first kind the
# pack could afford in authored order - which is precisely what this card
# replaced, so nothing reaches for that from anywhere any more.
func water(p_spot: int, _p_player = null) -> bool:
	var crop: Crop = crop_at(p_spot)
	if crop == null or crop.dead or crop.watered_today:
		return false
	var can: FuelCanData = watering_can()
	if can == null:
		return false
	can.drain(water_liters)
	crop.water()
	player_pack().changed.emit()  # a can's fill is state the grid can't see
	return true


func harvest(p_spot: int, _p_player = null) -> int:
	var crop: Crop = crop_at(p_spot)
	var pack: Inventory = player_pack()
	if crop == null or pack == null:
		return 0
	return crop.harvest(pack)


func watering_can() -> FuelCanData:
	var carried: CharacterInventory = player_carried()
	if carried == null:
		return null
	# In hand, not merely packed - the hand is what picks the spot's job.
	var can: FuelCanData = carried.held_item() as FuelCanData
	return can if can and can.current_fuel >= water_liters else null


# Valid-checked: a reload leaves a freed player registered for a frame.
func player_carried() -> CharacterInventory:
	if not is_instance_valid(InputManager.player):
		return null
	return InputManager.player.carried


func player_pack() -> Inventory:
	var carried: CharacterInventory = player_carried()
	return carried.inventory if carried else null


func crop_at(p_spot: int) -> Crop:
	var crop: Crop = crops.get(p_spot)
	return crop if is_instance_valid(crop) else null


func free_spots() -> int:
	var free: int = spots.size()
	for spot in crops:
		if is_instance_valid(crops[spot]) and not crops[spot].dead:
			free -= 1
	return free


func save_state() -> Dictionary:
	var rows: Array = []
	for spot in crops:
		var crop: Crop = crops[spot]
		if not is_instance_valid(crop):
			continue
		rows.append({"spot": spot, "data": crop.data.resource_path,
				"days": crop.days_until_fruit, "ready": crop.fruit_ready,
				"pending": crop.pending_produce, "watered": crop.watered_today,
				"dry": crop.dry_days, "dead": crop.dead})
	return {"crops": rows}


func load_state(p_state: Dictionary):
	for spot in crops:
		if is_instance_valid(crops[spot]):
			crops[spot].queue_free()
	crops.clear()
	for row in p_state.crops:
		var crop: Crop = plant(load(str(row.data)) as CropData, int(row.spot))
		if crop == null:
			continue
		crop.days_until_fruit = int(row.days)
		crop.fruit_ready = bool(row.ready)
		crop.pending_produce = int(row.pending)
		crop.watered_today = bool(row.watered)
		crop.dry_days = int(row.dry)
		crop.dead = bool(row.dead)
		# The save's clock was applied before the nodes, so today is truth.
		crop.last_absolute_day = crop.absolute_day(Calendar.time_data)
		crop.changed.emit()
