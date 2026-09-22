extends ProbeBase
# DBG probe: the GDD's farming rules - watered days grow, a dry day staggers,
# two dry days kill; ripe fruit holds until picked and the pack's overflow
# stays on the plant; the medium plant fruits daily after its long grow; a
# plot's save rows replant its garden exactly.

var plot: CropPlot


func _ready():
	plot = CropPlot.new()
	plot.crop_scene = load("res://scenes/props/crop.tscn")
	for i in 3:
		var spot: Marker3D = Marker3D.new()
		spot.position = Vector3(i * 1.5, 0.0, 0.0)
		plot.add_child(spot)
	add_child(plot)

	# --- watered days grow it to fruit on schedule
	var bush: CropData = load("res://data/crops/light_ammo_bush.tres")
	var crop: Crop = plot.plant(bush, 0)
	check(crop != null and crop.days_until_fruit == 3, "a seed goes in at 3 days out",
			"%d days" % crop.days_until_fruit)
	for day in 3:
		crop.water()
		advance_day()
	check(crop.fruit_ready and crop.pending_produce >= 15 and crop.pending_produce <= 30,
			"three watered days ripen the bush inside its range",
			"%d rounds waiting" % crop.pending_produce)

	# --- a ripe plant holds; harvest hands over and restarts the clock
	crop.water()
	advance_day()
	check(crop.fruit_ready, "ripe fruit holds until picked", "still ready")
	var pack: Inventory = Inventory.new()
	pack.setup(load("res://data/storage/box_large_layout.tres"))
	var rolled: int = crop.pending_produce
	var taken: int = crop.harvest(pack)
	check(taken == rolled and not crop.fruit_ready and crop.days_until_fruit == 3,
			"harvest empties the plant and restarts its cycle",
			"%d rounds, %d days to next" % [taken, crop.days_until_fruit])

	# --- a cramped pack takes a partial and the plant keeps the rest
	var tiny: Inventory = Inventory.new()
	tiny.setup(load("res://data/storage/box_small_layout.tres"))
	tiny.add(load("res://data/items/trinkets/rusty_gear.tres"), 8)  # brick 8 of 9 cells
	var heavy: ItemData = load("res://data/items/ammo/ammo_heavy.tres")
	tiny.add(heavy, heavy.get_max_stack() - 4)  # last cell: a stack with room for 4
	var vines: Crop = plot.plant(load("res://data/crops/heavy_ammo_vines.tres"), 1)
	for day in 5:
		vines.water()
		advance_day()
	var vine_roll: int = vines.pending_produce  # rolled 5-10, so 4 always fits short
	var first_take: int = vines.harvest(tiny)
	check(first_take == 4 and vines.pending_produce == vine_roll - 4 and vines.fruit_ready,
			"a cramped pack takes what fits and the plant keeps the rest",
			"%d of %d taken, %d still hanging" % [first_take, vine_roll, vines.pending_produce])
	check(crop.dead and crop.dry_days >= 2,
			"the bush nobody watered meanwhile died of drought",
			"dead after %d dry days" % crop.dry_days)

	# --- one dry day staggers, the second kills
	var plant: Crop = plot.plant(load("res://data/crops/medium_ammo_plant.tres"), 2)
	plant.water()
	advance_day()
	var before: int = plant.days_until_fruit
	advance_day()  # dry
	check(plant.days_until_fruit == before and plant.dry_days == 1 and not plant.dead,
			"one dry day staggers, not kills", "%d days out, %d dry" % [
			plant.days_until_fruit, plant.dry_days])
	plant.water()
	advance_day()
	check(plant.dry_days == 0 and plant.days_until_fruit == before - 1,
			"watering again clears the dry streak", "%d dry" % plant.dry_days)
	advance_day()
	advance_day()
	check(plant.dead, "two dry days in a row are fatal", "dead=%s" % plant.dead)
	check(plot.plant(load("res://data/crops/medium_ammo_plant.tres"), 2) != null,
			"a dead plant clears for replanting", "replanted")

	# --- the medium plant fruits DAILY once grown
	var medium: Crop = plot.crop_at(2)
	for day in 6:
		medium.water()
		advance_day()
	check(medium.fruit_ready, "six watered days mature the medium plant", "ready")
	medium.harvest(pack)
	medium.water()
	advance_day()
	check(medium.fruit_ready, "then it fruits again the very next day",
			"%d rounds" % medium.pending_produce)

	# --- the plot's save rows replant the garden exactly
	var snapshot: Dictionary = plot.save_state()
	plot.plant(load("res://data/crops/light_ammo_bush.tres"), 0)  # over the dead bush
	advance_day()  # and the ripe medium goes a day dry
	check(plot.save_state() != snapshot, "mangling the garden changes its rows",
			"replanted spot 0, dried spot 2")
	plot.load_state(snapshot)
	check(plot.save_state() == snapshot, "the saved garden replants exactly",
			"%d rows re-saved identical" % snapshot.crops.size())

	finish()


# Midnight, deterministically: no set_time semantics, just the rollover.
func advance_day():
	Calendar.time_data.add_day()
	Signals.calendar_updated.emit(Calendar.time_data)
