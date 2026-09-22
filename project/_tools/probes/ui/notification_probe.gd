extends ProbeBase
# DBG probe: the notification panel shows what the bus hands it; thresholds
# and copy live with the emitters.

var note: QuickNotification


func _ready():
	SaveManager.save_path = "user://probe_notification.json"
	SaveManager.backup_path = "user://probe_notification.bak"
	var gym: Node = (load("res://_tools/gym/gym.tscn") as PackedScene).instantiate()
	add_child(gym)
	await settle(6)
	var brain: Node = find_first(gym, "EnemyAI")
	if brain:
		brain.process_mode = Node.PROCESS_MODE_DISABLED
	note = find_first(gym, "QuickNotification") as QuickNotification
	if not check(note != null, "the HUD carries the notification panel", str(note)):
		finish()
		return

	Signals.notification_requested.emit("ANY COPY AT ALL", Enums.MessageType.NEUTRAL)
	await settle(2)
	check(note.visible and note.label.text == "ANY COPY AT ALL",
			"the panel shows whatever the bus hands it", note.label.text)
	await settle(20)
	var scale_before: Vector2 = note.scale
	Signals.notification_requested.emit("ANY COPY AT ALL", Enums.MessageType.NEUTRAL)
	await settle(2)
	check(note.scale.is_equal_approx(scale_before),
			"the same message again does not restart the pop",
			"scale %s" % note.scale)

	var player: Character = InputManager.player
	var revolver: WeaponData = (load("res://data/items/weapons/ranged/revolver.tres")
			as WeaponData).duplicate()
	revolver.current_ammo = 0
	player.weapons.set_weapons([revolver] as Array[WeaponData], 0)
	await settle(2)
	var reserve: int = player.carried.ammo_count(revolver.ammo_type)
	Input.action_press("attack")
	await settle(3)
	Input.action_release("attack")
	check(note.visible and note.label.text == "RELOAD", "an empty click asks for a reload",
			"%s with %d in reserve" % [note.label.text, reserve])
	player.carried.spend_ammo(revolver.ammo_type, reserve)
	note.hide_message()
	await settle(2)
	player.weapons.fire_cooldown = 0.0
	Input.action_press("attack")
	await settle(3)
	Input.action_release("attack")
	check(note.label.text == "RELOAD",
			"and a dry reserve still only asks for a reload - rounds are free", note.label.text)

	player.heat.burning = true
	await settle(2)
	check(note.label.text == "SCORCHING SUN", "the burn starting announces the sun",
			note.label.text)
	player.heat.burning = false
	await settle(2)
	check(note.label.text == "SCORCHING SUN",
			"and shade says nothing - relief needs no banner", note.label.text)

	var energy: PlayerEnergy = find_first(player, "PlayerEnergy")
	energy.set_energy(energy.max_energy)
	await settle(2)
	energy.set_energy(energy.max_energy * 0.15)
	await settle(2)
	check(note.label.text == "STAMINA LOW", "a draining battery warns at the line",
			note.label.text)
	player.heat.burning = true
	await settle(2)
	energy.set_energy(energy.max_energy * 0.12)
	await settle(2)
	check(note.label.text == "SCORCHING SUN",
			"but hovering under it stays quiet - one warning per dip",
			note.label.text)
	player.heat.burning = false
	energy.set_energy(energy.max_energy)
	await settle(2)
	energy.set_energy(energy.max_energy * 0.15)
	await settle(2)
	check(note.label.text == "STAMINA LOW",
			"recovering past the re-arm loads it again", note.label.text)
	finish()
