extends ProbeBase
# DBG probe: the pause key reaches a menu AT ALL. The settings panel used to
# own it and open itself; handing the key to PauseMenu without putting
# PauseMenu in game.tscn left Escape doing nothing, and nothing caught it -
# every existing probe called open() directly and so never pressed the key.


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS  # the menu pauses the tree
	var game: Node = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await settle(10)
	var menu: PauseMenu = find_first(game, "PauseMenu")
	var settings: SettingsScreen = find_first(game, "SettingsScreen")
	if not check(menu != null and settings != null,
			"game.tscn carries both the pause menu and the settings panel",
			"%s / %s" % [menu, settings]):
		finish()
		return
	check(menu.settings == settings, "and the menu knows where settings is",
			str(menu.settings))
	check(menu.process_mode == Node.PROCESS_MODE_ALWAYS,
			"the menu runs while the tree it pauses is paused",
			str(menu.process_mode))
	check(not menu.visible and not settings.visible, "both start hidden", "hidden")

	# --- the key, pressed the way a player presses it
	await press("pause_game")
	check(menu.visible and get_tree().paused,
			"the pause key opens the menu and stops the world",
			"visible=%s paused=%s" % [menu.visible, get_tree().paused])
	await press("pause_game")
	check(not menu.visible and not get_tree().paused,
			"and pressing it again hands the world back",
			"visible=%s paused=%s" % [menu.visible, get_tree().paused])

	# --- settings is a destination now, not the pause key's owner
	await press("pause_game")
	menu.open_settings()
	await settle(2)
	check(settings.visible and not menu.visible,
			"Settings swaps the menu out for the panel",
			"menu=%s panel=%s" % [menu.visible, settings.visible])
	check(get_tree().paused, "with the world still stopped across the handover",
			"paused")
	# Escape inside settings must back OUT to the menu, not into the game.
	await press("pause_game")
	check(menu.visible and not settings.visible,
			"and the key backs out of settings to the menu, not to the game",
			"menu=%s panel=%s" % [menu.visible, settings.visible])
	check(get_tree().paused, "the world still stopped behind it", "paused")
	finish()


# _unhandled_input is what both menus listen on, so the probe has to send a
# real event rather than flip the action's pressed state.
func press(p_action: String):
	var event: InputEventAction = InputEventAction.new()
	event.action = p_action
	event.pressed = true
	Input.parse_input_event(event)
	await settle(3)
