extends ProbeBase
# DBG probe: cool pockets - barrel venting gates on clock and fuel, the seal
# leaks stains round the clock, the pocket shelters the burn, cans refill; the
# station's own pocket is the stocked pump's, garden-and-bedroll wide, drain-free.


func _ready():
	var gym: Node = (load("res://_tools/gym/gym.tscn") as PackedScene).instantiate()
	add_child(gym)
	for i in 4:
		await get_tree().process_frame
	var player: Character = InputManager.player
	var wave: HeatWave = HeatWave.new()
	add_child(wave)
	var barrel: FuelBarrel = (load("res://scenes/props/fuel_barrel.tscn") \
			as PackedScene).instantiate()
	add_child(barrel)
	barrel.global_position = Vector3(30.0, 0.0, 30.0)
	barrel.warmth = 1.0  # the slow cold-in is carry_probe's subject, not ours
	await get_tree().physics_frame

	# --- venting gates on the clock and the fuel
	Calendar.set_time(8, 0)
	check(not barrel.venting(), "a cool morning vents nothing", "idle")

	# --- but the seal leaks regardless: black stains, not blood, 24/7
	for i in 12:
		barrel.leak(1.0)
	check(not BloodPool.fuel_tiles.is_empty(),
			"the barrel drips black stains before the heat arrives",
			"%d fuel tiles" % BloodPool.fuel_tiles.size())
	check(BloodPool.tiles.is_empty(), "and none of them think they are blood",
			"%d blood tiles" % BloodPool.tiles.size())

	Calendar.set_time(13, 0)
	check(barrel.venting(), "high noon opens the vent", "venting")

	# --- the pocket holds the burn off while the sun cooks
	player.global_position = barrel.global_position + Vector3(2.5, 0.0, 0.0)
	for i in 40:
		await get_tree().physics_frame
	check(player.heat.sheltered(), "standing by the barrel is sheltered", "inside")
	var before: int = player.current_health
	for i in 100:
		await get_tree().physics_frame
	check(player.current_health == before, "the pocket holds the noon burn off",
			"%d hp held" % before)

	# --- a scorch hour drinks its liters
	var fuel_before: float = barrel.current_fuel
	barrel.advance(Calendar.HOUR_DURATION)
	check(is_equal_approx(barrel.current_fuel, fuel_before - barrel.drain_per_hour),
			"a scorch hour drinks its liters",
			"%.1f -> %.1fL" % [fuel_before, barrel.current_fuel])

	# --- a dry barrel is a dead pocket
	barrel.current_fuel = 0.0
	var hurt: int = player.current_health
	for i in 100:
		await get_tree().physics_frame
	check(player.current_health < hurt, "a dry barrel lets the sun back in",
			"%d -> %d hp" % [hurt, player.current_health])
	var timer_before: float = barrel.drip_timer
	for i in 12:
		barrel.leak(1.0)
	check(is_equal_approx(barrel.drip_timer, timer_before),
			"and has nothing left to drip", "timer held at %.2f" % barrel.drip_timer)

	# --- the jerry can refills it
	for entry in player.carried.inventory.entries.duplicate():
		if not entry.item is WeaponData:
			player.carried.inventory.remove(entry)  # the loadout packs the grid tight
	var can: FuelCanData = (load("res://data/items/tools/fuel_can.tres") \
			as FuelCanData).duplicate()
	can.current_fuel = 5.0
	check(player.carried.inventory.add_one(can) != null,
			"the test can found grid room", "placed")
	for i in 90:
		barrel.refill()
	check(is_equal_approx(barrel.current_fuel + can.current_fuel, 5.0) \
			and barrel.current_fuel > 0.0,
			"the can's liters moved into the barrel",
			"%.1fL in, %.1fL left in the can" % [barrel.current_fuel, can.current_fuel])
	check(barrel.venting(), "and the pocket is back", "venting")

	# --- the fill level survives a save
	barrel.current_fuel = 17.0
	var row: Dictionary = barrel.save_state()
	barrel.current_fuel = 3.0
	barrel.load_state(row)
	check(is_equal_approx(barrel.current_fuel, 17.0),
			"the fill level survives a save", "%.1fL" % barrel.current_fuel)

	# --- the station's pocket is the pump's: stocked, drain-free, forecourt-wide
	gym.queue_free()
	barrel.queue_free()
	wave.queue_free()
	await get_tree().process_frame
	var game: Node = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	for i in 4:
		await get_tree().process_frame
	Calendar.set_time(12, 0)
	var pump: GasPump = find_first(game, "GasPump")
	var pocket: CoolArea = pump.get_node_or_null("CoolArea")
	check(pocket is CoolArea and pump.venting(),
			"a stocked pump vents the forecourt cool",
			"%.0fL venting" % pump.data.current_stock)
	var stocked: float = pump.data.current_stock
	for i in 30:
		await get_tree().process_frame
	check(is_equal_approx(pump.data.current_stock, stocked),
			"and the venting drinks nothing", "%.1fL held" % pump.data.current_stock)
	var reach: float = pocket.get_node("CollisionShape3D").shape.radius
	var garden: CropPlot = game.find_child("Garden", true, false)
	var covered: bool = true
	for spot in garden.spots:
		if spot.global_position.distance_to(pocket.global_position) > reach:
			covered = false
	check(covered, "every garden spot sits in the pump's pocket", "r %.0fm" % reach)
	var bedroll: Node3D = game.find_child("Bedroll", true, false)
	check(bedroll.global_position.distance_to(pocket.global_position) <= reach,
			"the bedroll sleeps in it too", "covered")

	# --- a placed barrel still tells the ground where it stands
	var placed: FuelBarrel = (load("res://scenes/props/fuel_barrel.tscn") \
			as PackedScene).instantiate()
	game.add_child(placed)  # the chill group is tree-wide; the parent is nobody's business
	placed.global_position = Vector3(30.0, 0.0, 0.0)
	placed.warmth = 1.0  # full strength NOW; the slow cold-in is carry_probe's subject
	var field: SandField = game.find_children("*", "SandField", true, false).front()
	for i in 40:
		await get_tree().process_frame  # past the field's next chill push
	var spots: PackedVector4Array = field.sand.get_shader_parameter("chill_spots")
	check(painted(spots, Vector2(30.0, 0.0), placed.chill_radius()),
			"a placed barrel rides the chill array at full strength", "%s" % spots)
	check(painted(spots, Vector2(pump.global_position.x, pump.global_position.z),
			pump.chill_radius()),
			"and the stocked pump damps its own forecourt", "%s" % spots)
	check(spots.size() == 8 and padded(spots),
			"with the live spots packed first and the rest inert", "%d slots" % spots.size())

	# --- a dry pump is a dead pocket
	pump.data.current_stock = 0.0
	check(not pump.venting(), "a dry pump is a dead pocket", "0L")

	finish()


# SandField's contract is fill-then-pad, so a live entry after a zero is a
# hole - and the shader would stop reading at it.
func padded(p_spots: PackedVector4Array) -> bool:
	var ended: bool = false
	for spot in p_spots:
		if spot.y <= 0.0:
			ended = true
		elif ended:
			return false
	return true


# By position, not slot: the array order follows the group's, which is the
# scene tree's and not something a probe should pin.
func painted(p_spots: PackedVector4Array, p_flat: Vector2, p_radius: float) -> bool:
	for spot in p_spots:
		if Vector2(spot.x, spot.z).distance_to(p_flat) < 0.1 \
				and is_equal_approx(spot.w, p_radius) and spot.y > 0.99:
			return true
	return false
