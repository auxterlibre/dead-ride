extends ProbeBase
# DBG probe: the scorch window, the burn and its cover, and the game wiring.

var burn_flips: Array[bool] = []


func _ready():
	var wave: HeatWave = HeatWave.new()
	add_child(wave)

	# --- the window: sharp for damage, shouldered for the haze
	Calendar.set_time(8, 0)
	check(wave.intensity() == 0.0 and not wave.is_scorching(),
			"8:00 is cool and clear", "intensity %.2f" % wave.intensity())
	Calendar.set_time(9, 45)
	check(wave.intensity() > 0.3 and wave.intensity() < 0.7 and not wave.is_scorching(),
			"9:45 shimmers as a warning but does not burn yet",
			"intensity %.2f" % wave.intensity())
	Calendar.set_time(10, 30)
	check(wave.intensity() == 1.0 and wave.is_scorching(),
			"10:30 is full scorch", "intensity %.2f" % wave.intensity())
	Calendar.set_time(15, 59)
	check(wave.is_scorching(), "15:59 still burns", "scorching")
	Calendar.set_time(16, 10)
	check(not wave.is_scorching() and wave.intensity() > 0.0 and wave.intensity() < 1.0,
			"16:10 has stopped burning while the haze drains",
			"intensity %.2f" % wave.intensity())
	Calendar.set_time(17, 0)
	check(wave.intensity() == 0.0, "17:00 is clear again",
			"intensity %.2f" % wave.intensity())

	# --- the burn, on a real player in the gym
	var gym: Node = (load("res://_tools/gym/gym.tscn") as PackedScene).instantiate()
	add_child(gym)
	for i in 4:
		await get_tree().process_frame
	var player: Character = InputManager.player
	var heat: PlayerHeat = null  # the scene's own component, not a second one
	for child in player.get_children():
		if child is PlayerHeat:
			heat = child
	check(heat != null, "the player carries the heat component", str(heat))
	Signals.heat_burning_changed.connect(func(p_burning: bool): burn_flips.append(p_burning))

	Calendar.set_time(13, 0)  # rolls to next day's high noon
	var before: int = player.current_health
	for i in 100:
		await get_tree().physics_frame
	check(player.current_health < before,
			"a minute and a half of noon sun costs real health",
			"%d -> %d hp" % [before, player.current_health])
	check(burn_flips.size() >= 1 and burn_flips[0] == true,
			"the burning warning was raised", str(burn_flips))

	# --- a roof is shade: same sun, no cost
	var roof: StaticBody3D = StaticBody3D.new()
	roof.collision_layer = 4  # walls - what the sky ray treats as cover
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(6.0, 0.3, 6.0)
	shape.shape = box
	roof.add_child(shape)
	add_child(roof)
	roof.global_position = player.global_position + Vector3.UP * 3.0
	for i in 40:
		await get_tree().physics_frame
	var shaded: int = player.current_health
	for i in 100:
		await get_tree().physics_frame
	check(player.current_health == shaded, "a roof overhead stops the burn",
			"%d hp held" % shaded)
	check(not burn_flips.is_empty() and burn_flips.back() == false,
			"and the warning stood down", str(burn_flips))

	# --- off-hours are safe in the open
	roof.queue_free()
	Calendar.set_time(8, 30)  # next morning, exposed again
	for i in 40:
		await get_tree().physics_frame
	var morning: int = player.current_health
	for i in 100:
		await get_tree().physics_frame
	check(player.current_health == morning, "the morning sun is harmless",
			"%d hp held" % morning)

	# --- the game scene carries the wired system
	gym.queue_free()
	await get_tree().process_frame
	var game: Node = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	for i in 4:
		await get_tree().process_frame
	var world_wave: HeatWave = find_first(game, "HeatWave")
	check(world_wave != null and world_wave.haze != null,
			"game.tscn carries the heat wave with its haze wired",
			str(world_wave))
	check(world_wave != null and world_wave.haze is ColorRect \
			and world_wave.haze.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"the haze rect never eats a click", "mouse_filter ignore")

	# --- and the whole chain fires in the real world: burn, warning label.
	# The spawn now stands inside the station's cool pocket (by design), so
	# the exposure is staged on open sand.
	InputManager.player.global_position = Vector3(0.0, 0.0, -15.0)
	Calendar.set_time(12, 0)
	var world_before: int = InputManager.player.current_health
	for i in 120:
		await get_tree().physics_frame
	check(InputManager.player.current_health < world_before,
			"the noon sun burns at the station too",
			"%d -> %d hp" % [world_before, InputManager.player.current_health])

	# --- and it says so: smoke off the body, the flash overlay, a number
	var world_heat: PlayerHeat = null
	for child in InputManager.player.get_children():
		if child is PlayerHeat:
			world_heat = child
	check(world_heat.smoke != null and world_heat.smoke.emitting,
			"the burning player smokes", str(world_heat.smoke))
	var flashed: bool = false
	for mesh in InputManager.player.find_children("*", "MeshInstance3D", true, false):
		if mesh.material_overlay != null:
			flashed = true
	check(flashed, "the hurt flash overlay is on the body", "overlaid")
	# The number is TRANSIENT and this claim used to sample one instant: the
	# label rises and fades over 0.8s while the burn deals a tick every 1.0s, so
	# a fifth of every second has none alive at all and the check failed at
	# random. Watched across a whole burn period instead. The search starts at
	# current_scene because spawn_damage_label parents there - the PROBE's root,
	# not the game node, so searching `game` would find nothing at any instant.
	var numbers: int = 0
	for i in 90:  # 1.5s at 60Hz, comfortably past one 1.0s burn tick
		for node in get_tree().current_scene.find_children("*", "Label3D", true, false):
			if node.text.is_valid_int():
				numbers += 1
		if numbers > 0:
			break
		await get_tree().physics_frame
	check(numbers > 0, "and the damage reads out in numbers",
			"%d within a burn tick" % numbers)
	var hud_label: Label = game.find_child("HeatInfo", true, false)
	check(hud_label != null and hud_label.visible,
			"the scorching warning stands on the HUD", str(hud_label))

	finish()
