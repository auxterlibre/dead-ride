extends ProbeBase
# DBG probe: the menus under a pad - B (ui_cancel) backs out of every screen,
# the dpad walks what can be walked, and A confirms. The pad's ui_accept and
# ui_cancel are PROJECT OVERRIDES: Godot 4.7's defaults carry dpad and stick
# on the directions but NO pad buttons on accept/cancel, so a regression here
# is one lost project.godot block, not a code path.

var game: Node
var picked: String = ""


func _ready():
	var packed: PackedScene = load("res://scenes/game.tscn")
	game = packed.instantiate()
	add_child(game)
	await settle(8)
	InputManager.player.heat.burn_per_second = 0.0
	InputManager.pad_active = true

	check_the_overrides()
	await test_the_pause()
	await test_the_settings()
	await test_the_backpack()
	await test_the_picker()
	finish()


# The one thing everything below leans on: A and B exist ON THE PAD at all.
func check_the_overrides():
	var accept: bool = false
	var cancel: bool = false
	for event in InputMap.action_get_events("ui_accept"):
		accept = accept or (event is InputEventJoypadButton
				and event.button_index == JOY_BUTTON_A)
	for event in InputMap.action_get_events("ui_cancel"):
		cancel = cancel or (event is InputEventJoypadButton
				and event.button_index == JOY_BUTTON_B)
	check(accept and cancel, "A and B are bound to ui_accept/ui_cancel",
			"accept %s, cancel %s" % [accept, cancel])


func test_the_pause():
	var pause: PauseMenu = find_first(game, "PauseMenu") as PauseMenu
	if not check(pause != null, "the map carries the pause menu", str(pause)):
		return
	pause.open()
	await settle(3)
	check(pause.visible and get_tree().paused, "the pause menu opens and pauses",
			"visible %s" % pause.visible)
	check(pause.resume_button.has_focus(),
			"and a pad hand lands on Resume", str(get_viewport().gui_get_focus_owner()))
	press_pad(JOY_BUTTON_B)
	await settle(3)
	check(not pause.visible and not get_tree().paused,
			"B closes it and resumes", "visible %s, paused %s"
			% [pause.visible, get_tree().paused])


func test_the_settings():
	var settings: SettingsScreen = find_first(game, "SettingsScreen") as SettingsScreen
	if not check(settings != null, "and the settings screen", str(settings)):
		return
	settings.open()
	await settle(3)
	var eligible: Array = settings.eligible_rows()
	check(settings.visible and not eligible.is_empty()
			and settings.focused_row == 0 and eligible[0].focused,
			"opened by a pad, the first row is already lit",
			"row %d of %d" % [settings.focused_row, eligible.size()])
	press_action("ui_down")
	await settle(2)
	check(settings.focused_row == 1 and eligible[1].focused
			and not eligible[0].focused, "the dpad walks the rows",
			"row %d" % settings.focused_row)
	# Cycle the focused row and read the STAGED value - left must undo right.
	var before = settings.pending[SettingsScreen.Row.UNIT_SYSTEM]
	settings.clear_focus()
	settings.move_focus(1)  # back to row 0: unit system
	press_action("ui_right")
	await settle(2)
	var stepped = settings.pending[SettingsScreen.Row.UNIT_SYSTEM]
	press_action("ui_left")
	await settle(2)
	check(stepped != before
			and settings.pending[SettingsScreen.Row.UNIT_SYSTEM] == before,
			"left and right cycle the focused value and back",
			"%s -> %s -> %s" % [before, stepped,
			settings.pending[SettingsScreen.Row.UNIT_SYSTEM]])
	press_pad(JOY_BUTTON_RIGHT_SHOULDER)
	await settle(2)
	check(settings.current_tab != SettingsScreen.Tab.GAMEPLAY,
			"a shoulder pages the tabs", "tab %d" % settings.current_tab)
	press_pad(JOY_BUTTON_B)
	await settle(3)
	check(not settings.visible, "and B closes the screen unapplied",
			"visible %s" % settings.visible)
	get_tree().paused = false  # settings leaves the pause to its opener


func test_the_backpack():
	var pack: BackpackScreen = find_first(game, "BackpackScreen") as BackpackScreen
	if not check(pack != null, "and the backpack", str(pack)):
		return
	pack.open()
	await settle(3)
	check(pack.visible and get_tree().paused, "the pack opens and pauses",
			"visible %s" % pack.visible)
	press_pad(JOY_BUTTON_B)
	await settle(3)
	check(not pack.visible and not get_tree().paused, "B closes it too",
			"visible %s, paused %s" % [pack.visible, get_tree().paused])


# The truck-counter popup: focus lands on row one, A picks it.
func test_the_picker():
	var menu: InteractionMenu = find_first(game, "InteractionMenu") as InteractionMenu
	if not check(menu != null, "and the interaction menu", str(menu)):
		return
	picked = ""
	Signals.interaction_menu_requested.emit("Probe", [
		{"label": "First", "target": self, "callback": "pick_first"},
		{"label": "Second", "target": self, "callback": "pick_second"},
	])
	await settle(3)
	var focused: Control = get_viewport().gui_get_focus_owner()
	check(menu.visible and focused is InputKeyButton,
			"a popup's first row takes the pad's focus", str(focused))
	press_action("ui_down")
	await settle(2)
	press_pad(JOY_BUTTON_A)
	await settle(3)
	check(picked == "second" and not menu.visible,
			"the dpad walks a row down and A picks it", "picked '%s'" % picked)


func pick_first(_p = null):
	picked = "first"


func pick_second(_p = null):
	picked = "second"


# Through the real input stack: focus, Button.ui_accept handling and the
# _unhandled_input closes all want EVENTS, not action flags.
func press_pad(p_button: int):
	var down: InputEventJoypadButton = InputEventJoypadButton.new()
	down.button_index = p_button
	down.pressed = true
	Input.parse_input_event(down)
	var up: InputEventJoypadButton = down.duplicate()
	up.pressed = false
	Input.parse_input_event(up)


func press_action(p_action: String):
	var down: InputEventAction = InputEventAction.new()
	down.action = p_action
	down.pressed = true
	Input.parse_input_event(down)
	var up: InputEventAction = InputEventAction.new()
	up.action = p_action
	Input.parse_input_event(up)
