extends ProbeBase
# DBG probe: the save roundtrip - money, clock, player body and pack, crate
# contents, pump stock and the car all survive a save, a wreck of mutations,
# and a load; an unsearched crate stays a fresh roll; death rolls back to the
# save. Runs on SaveManager's path override so the real save is never touched.

@onready var GAME: PackedScene = load("uid://b56i3a2diovj6")  # scenes/game.tscn


func _ready():
	SaveManager.save_path = "user://probe_save.json"
	SaveManager.backup_path = "user://probe_save.bak"
	clean_probe_saves()
	var game: Node = GAME.instantiate()
	get_tree().root.add_child.call_deferred(game)
	await get_tree().process_frame
	get_tree().current_scene = game
	for i in 8:
		await get_tree().process_frame

	# --- sculpt a distinctive world state
	var player: Character = InputManager.player
	var energy: PlayerEnergy = player.find_children("*", "PlayerEnergy", false, false).front()
	PlayerData.current_money = 777
	Calendar.set_time(10, 30)
	player.global_position = Vector3(5.0, 0.1, 5.0)
	player.take_damage(AttackData.new(4, player.global_position, 0.0, null))
	energy.set_energy(42.0)
	# By name and by type, never by path: which parent holds the crates, the car
	# and the station is the designer's to change, and it has changed twice.
	var crate: LootContainer = game.find_child("RidgeArmyMedium", true, false)
	crate.searched = true
	crate.fill()
	var rolled: Array = crate.storage.entries.map(
			func(entry): return "%s x%d" % [entry.item.name, entry.count])
	var car: Vehicle = game.find_child("Car", true, false)
	car.data.current_fuel = 9.9
	car.health = 55
	var pump: GasPump = find_first(game, "GasPump")
	pump.data.current_stock = 123.0
	var saved_hp: int = player.current_health

	SaveManager.save_game()
	check(FileAccess.file_exists(SaveManager.save_path), "the save hits disk", "save.json")

	# --- wreck everything the save should undo
	PlayerData.current_money = 1
	player.global_position = Vector3(-30.0, 0.1, -30.0)
	energy.set_energy(99.0)
	var other: LootContainer = game.find_child("SouthEdgeCardboardLarge", true, false)
	other.searched = true
	other.fill()
	pump.data.current_stock = 5.0

	# --- load lays the saved world back down
	SaveManager.load_game()
	for i in 6:
		await get_tree().process_frame
	var scene: Node = get_tree().current_scene
	player = InputManager.player
	energy = player.find_children("*", "PlayerEnergy", false, false).front()
	check(PlayerData.current_money == 777, "the purse reloads", "$%d" % PlayerData.current_money)
	check(Calendar.time_data.hour == 10 and Calendar.time_data.minute == 30,
			"the clock reloads", "%02d:%02d" % [Calendar.time_data.hour,
			Calendar.time_data.minute])
	check(player.global_position.distance_to(Vector3(5.0, 0.1, 5.0)) < 0.5,
			"the body stands where it saved", str(player.global_position.snappedf(0.1)))
	check(player.current_health == saved_hp and is_equal_approx(energy.current, 42.0),
			"health and energy reload", "%d hp, %.0f en" % [player.current_health,
			energy.current])
	crate = scene.find_child("RidgeArmyMedium", true, false)
	var reloaded: Array = crate.storage.entries.map(
			func(entry): return "%s x%d" % [entry.item.name, entry.count])
	check(crate.searched and str(reloaded) == str(rolled),
			"a searched crate keeps its exact haul", str(reloaded))
	other = scene.find_child("SouthEdgeCardboardLarge", true, false)
	check(not other.searched and other.storage.entries.is_empty(),
			"a crate searched after the save is fresh again",
			"searched=%s %d entries" % [other.searched, other.storage.entries.size()])
	car = scene.find_child("Car", true, false)
	check(is_equal_approx(car.data.current_fuel, 9.9) and car.health == 55,
			"the car's tank and hull reload", "%.1fL %dhp" % [car.data.current_fuel,
			car.health])
	pump = find_first(scene, "GasPump")
	check(is_equal_approx(pump.data.current_stock, 123.0), "the pump stock reloads",
			"%.0fL" % pump.data.current_stock)
	var slots: Array = []
	for child in player.get_children():
		if child is CharacterInventory:
			slots = child.quick_slots
	# Slot 2 = the first utility slot; the bar DISPLAYS it as key "3".
	check(slots.size() > 2 and slots[2] != null and slots[2].item.name == "Frag Grenade",
			"the quick bar reloads its grenades",
			str(slots[2].item.name if slots.size() > 2 and slots[2] else "-"))

	# --- dying rolls back to the save
	PlayerData.current_money = 1
	player.take_damage(AttackData.new(9999, player.global_position, 0.0, null))
	var screen: DeathScreen = scene.find_children("*", "DeathScreen", true, false).front()
	await get_tree().create_timer(screen.CORPSE_BEAT + 0.4).timeout
	screen.respawn()
	for i in 8:
		await get_tree().process_frame
	player = InputManager.player
	check(not player.is_dead and PlayerData.current_money == 777 \
			and player.global_position.distance_to(Vector3(5.0, 0.1, 5.0)) < 0.5,
			"death rolls back to the last save", "$%d at %s" % [
			PlayerData.current_money, player.global_position.snappedf(0.1)])

	# --- a second save rotates the backup
	SaveManager.save_game()
	check(FileAccess.file_exists(SaveManager.backup_path),
			"a second save leaves a backup", "save.bak")

	clean_probe_saves()
	finish()


func clean_probe_saves():
	for path in [SaveManager.save_path, SaveManager.backup_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
