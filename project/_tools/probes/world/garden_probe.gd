extends ProbeBase
# DBG probe: the crop interaction layer - planting from ordinary items,
# fuel-can watering, state-driven offers, and the game scene's wiring.

var plot: CropPlot


func _ready():
	var gym: Node = (load("res://_tools/gym/gym.tscn") as PackedScene).instantiate()
	add_child(gym)
	for i in 4:
		await get_tree().process_frame
	var pack: Inventory = InputManager.player.carried.inventory
	var light: CropData = load("res://data/crops/light_ammo_bush.tres")
	var medium: CropData = load("res://data/crops/medium_ammo_plant.tres")

	# A plot of real CropSpot scenes, light before medium in the offer order.
	plot = CropPlot.new()
	plot.crop_scene = load("res://scenes/props/crop.tscn")
	var kinds: Array[CropData] = [light, medium]
	plot.species = kinds
	var spot_scene: PackedScene = load("res://scenes/props/crop_spot.tscn")
	for i in 2:
		var spot: CropSpot = spot_scene.instantiate()
		spot.position = Vector3(i * 1.8, 0.0, 10.0)
		plot.add_child(spot)
	add_child(plot)

	# Keep the guns, empty the rest - exact counts on a known grid.
	var can_item: FuelCanData = load("res://data/items/tools/fuel_can.tres")
	for entry in pack.entries.duplicate():
		if not entry.item is WeaponData:
			pack.remove(entry)

	# --- the spot takes the species it is HANDED; choosing it is the planting
	# panel's job now, and ui/planting_probe owns that half.
	var crop: Crop = plot.plant(light, 0)
	check(crop != null and crop.data == light, "the bush goes in", str(crop))
	check(plot.plant(medium, 0) == null,
			"and an occupied spot refuses the next one", "refused")

	# --- one offer, and the HAND says what it does
	var spot: CropSpot = plot.spots[0]
	var carried: CharacterInventory = InputManager.player.carried
	spot.refresh_offers()
	check(not spot.offer.enabled, "a growing plant with nothing in hand offers nothing",
			"disabled")
	var can: FuelCanData = can_item.duplicate()
	can.current_fuel = 0.5
	var can_entry: InventoryEntry = pack.add_one(can)
	check(can_entry != null, "the test can found grid room", "placed")
	spot.refresh_offers()
	check(not spot.offer.enabled, "a can in the PACK is not a can in hand",
			"disabled while stowed")
	# Onto the bar and selected: this is what "holding it" means to the spot.
	var slot: int = carried.free_item_slot()
	carried.assign_quick_slot(can_entry, slot)
	carried.select_slot(slot)
	spot.refresh_offers()
	check(not spot.offer.enabled, "a can below the drink refuses",
			"%.1fL held" % can.current_fuel)
	can.add_fuel(2.5)
	spot.refresh_offers()
	check(spot.offer.enabled and spot.offer.action_label.begins_with("Water"),
			"a filled can in hand turns the offer into the pour",
			spot.offer.action_label)
	carried.holster()
	spot.refresh_offers()
	check(not spot.offer.enabled, "and putting it away hands the point back",
			"nothing to offer a growing plant empty-handed")
	carried.select_slot(slot)

	# --- watering drinks the can, once a day
	check(plot.water(0), "the plant takes its daily drink", "watered")
	check(is_equal_approx(can.current_fuel, 2.0),
			"one watering drank one liter", "%.1fL left" % can.current_fuel)
	check(not plot.water(0), "a second watering the same day refuses",
			"refused")
	check(spot.wet_soil.visible and not spot.dry_soil.visible,
			"the soil reads watered", "wet disc shown")

	# --- midnight resets the thirst and the offer returns
	advance_day()
	spot.refresh_offers()
	check(spot.offer.enabled and spot.offer.action_label.begins_with("Water") \
			and not crop.watered_today,
			"midnight makes it thirsty again", spot.offer.action_label)

	# --- ripeness flips the primary offer to harvest, and harvest banks rounds
	crop.water()
	advance_day()
	crop.water()
	advance_day()
	check(crop.fruit_ready, "three watered days ripen the bush", "ripe")
	carried.holster()  # can in hand would take the thirsty plant's pour first
	spot.refresh_offers()
	check(spot.offer.enabled
			and spot.offer.action_label.begins_with("Harvest"),
			"a ripe plant advertises the harvest to an empty hand",
			spot.offer.action_label)
	var rounds_before: int = pack.count_of(light.seed_item)
	var hanging: int = crop.pending_produce
	spot.tend()
	check(pack.count_of(light.seed_item) == rounds_before + hanging,
			"harvest banks the fruit in the pack",
			"+%d rounds" % hanging)
	check(not crop.fruit_ready and crop.days_until_fruit == light.regrow_days,
			"and the cycle restarts", "%d days out" % crop.days_until_fruit)

	# --- a drought death reopens the spot for planting
	advance_day()
	advance_day()
	check(crop.dead, "two dry days kill it", "dead")
	spot.refresh_offers()
	check(spot.offer.enabled
			and spot.offer.action_label.begins_with("Plant"),
			"a dead plant's spot offers planting again", spot.offer.action_label)

	# --- the game scene carries the wired garden and the bedroll
	gym.queue_free()
	plot.queue_free()
	await get_tree().process_frame
	var game: Node = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	for i in 4:
		await get_tree().process_frame
	var garden: CropPlot = game.find_child("Garden", true, false)
	check(garden != null and garden.spots.size() == 6 and garden.species.size() == 3,
			"game.tscn carries a six-spot garden growing all three species",
			"%d spots" % (0 if garden == null else garden.spots.size()))
	check(garden != null and garden.crop_scene != null,
			"the garden knows what a crop looks like", "crop scene wired")
	var bedroll: Node = game.find_child("Bedroll", true, false)
	check(bedroll is Bedroll, "the bedroll stands at the station to sleep the days by",
			str(bedroll))

	finish()


# Midnight, deterministically: no set_time semantics, just the rollover.
func advance_day():
	Calendar.time_data.add_day()
	Signals.calendar_updated.emit(Calendar.time_data)
