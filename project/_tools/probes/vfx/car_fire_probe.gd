extends ProbeBase
# DBG probe: the damage fire and its audio loop are ONE state. Under 30% hull the
# flame lights and the loop runs; a repair back over the tier puts BOTH out, and
# the car can catch fire again afterwards.

const FIRE_TIER: float = 0.3  # the fraction VehicleDamage lights the flame under


func _ready():
	var game: Node = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await settle(8)

	var player: Node = InputManager.player
	var kit: ItemData = load("res://data/items/tools/screwdriver.tres")
	var stowed: int = player.carried.inventory.add(kit)
	check(stowed == 0, "the player carries a repair kit", "%s left over" % stowed)

	# Its own car, off where the station and the delivery run can't touch it, and
	# frozen so nothing but the health writes moves the situation.
	var car: Vehicle = load("res://scenes/vehicles/car.tscn").instantiate()
	add_child(car)
	car.global_position = Vector3(0.0, 0.5, 300.0)
	car.freeze = true
	await settle(2)
	var flame: Flame = car.damage_fire
	var hull: int = car.data.health_max_value

	# --- burning: under the tier the flame lights and the loop starts
	car.take_damage(AttackData.new(hull - int(hull * 0.2), car.global_position, 0.0, car))
	check(float(car.health) / hull < FIRE_TIER, "the hull is under the fire tier",
			"%d of %d hp" % [car.health, hull])
	check(flame.burning and flame.visible, "the car catches fire",
			"burning %s, visible %s" % [flame.burning, flame.visible])
	check(flame.audio_loop.playing, "and the fire loop is running",
			"playing %s" % flame.audio_loop.playing)

	# --- repaired: the loop must stop with the flame, not outlive it
	car.repair(player)
	check(float(car.health) / hull > FIRE_TIER, "the repair lifts the hull over the tier",
			"%d of %d hp" % [car.health, hull])
	check(not flame.burning, "the fire is out", "burning %s" % flame.burning)
	check(not flame.audio_loop.playing, "and the loop stopped with it",
			"playing %s" % flame.audio_loop.playing)
	await settle(90)  # the flame fades over a second before it hides
	check(not flame.visible, "the flame finishes fading away",
			"visible %s, fade %.2f" % [flame.visible, flame.fade])

	# --- re-lit: `visible` lags the state by a fade, so a flag that reads it
	# would leave a burning car dark for good.
	car.take_damage(AttackData.new(car.health - int(hull * 0.2), car.global_position, 0.0, car))
	check(flame.burning and flame.audio_loop.playing, "a repaired car can burn again",
			"burning %s, playing %s" % [flame.burning, flame.audio_loop.playing])

	finish()
