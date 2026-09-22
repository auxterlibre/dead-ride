extends ProbeBase
# DBG probe: the gamepad map - every action the game actually polls carries a
# pad event AND art, the deliberate shared buttons are the only shared ones,
# the badges follow the last device TOUCHED rather than the one plugged in,
# and the pad's own verbs (Y's tap/hold, the dpad slots, the car's triggers)
# run end-to-end through a real seat and a self-dealt loadout.

# What the game polls, minus what is deliberately keyboard-only. The order
# matters to SHARED below: a clashing button's holders list in THIS order.
const NEEDS_PAD: Array[String] = ["move_up", "move_down", "move_left",
	"move_right", "dodge", "attack", "aim", "sprint", "crouch", "reload",
	"interact", "item_equip", "item_drop", "toggle_weapon", "weapon_slot_2",
	"weapon_slot_3", "weapon_slot_4", "weapon_slot_5", "car_accelerate",
	"car_reverse", "car_brake", "toggle_backpack", "toggle_build",
	"build_rotate", "pause_game"]
# The weapon slots proper ride Y's toggle, holster is Y HELD, and the pad
# cycles nothing - the dpad selects items directly, so next/prev stay keys.
const NO_PAD: Array[String] = ["weapon_slot_0", "weapon_slot_1", "holster",
	"next_item", "prev_item", "debug_text_toggle"]
# Buttons two actions may share, because the two can never be live together:
# the pack screen pauses the world (X equips while interact sleeps, Y drops
# while toggle_weapon sleeps) and a seated driver is PROCESS_MODE_DISABLED
# (B brakes while reload sleeps, the triggers drive while attack/aim sleep).
const FRAME: float = 1.0 / 60.0  # the delta the aim slew is judged in
const SHARED: Dictionary = {
	"X": ["interact", "item_equip"],
	"Y": ["item_drop", "toggle_weapon"],
	"B": ["reload", "car_brake"],
	"RT": ["attack", "car_accelerate"],
	"LT": ["aim", "car_reverse"],
}


func _ready():
	# --- every polled action reaches the pad
	var missing: Array[String] = []
	for action in NEEDS_PAD:
		if pad_events(action).is_empty():
			missing.append(action)
	check(missing.is_empty(), "every polled action carries a pad event",
			"%d/%d bound%s" % [NEEDS_PAD.size() - missing.size(), NEEDS_PAD.size(),
			"" if missing.is_empty() else ", missing " + ", ".join(missing)])
	var stray: Array[String] = []
	for action in NO_PAD:
		if not pad_events(action).is_empty():
			stray.append(action)
	check(stray.is_empty(), "and the keyboard-only actions stayed that way",
			"none bound" if stray.is_empty() else ", ".join(stray))

	# --- one button, one job, bar the declared context-exclusive pairs
	var by_label: Dictionary = {}
	for action in NEEDS_PAD:
		for event in pad_events(action):
			var label: String = control_key(event)
			by_label[label] = by_label.get(label, [] as Array) + [action]
	var clashes: Array[String] = []
	for label in by_label:
		var holders: Array = by_label[label]
		if holders.size() > 1 and SHARED.get(label, []) != holders:
			clashes.append("%s <- %s" % [label, ", ".join(holders)])
	check(clashes.is_empty(), "no two live actions want the same button",
			"%d buttons mapped" % by_label.size() if clashes.is_empty() \
			else "; ".join(clashes))
	# The shares are meant, not merely tolerated - a typo'd SHARED table would
	# otherwise pass the clash test by describing whatever it found.
	for label in SHARED:
		check(by_label.get(label, []) == SHARED[label],
				"%s is shared by exactly its declared pair" % label,
				str(by_label.get(label, [])))

	# --- the badge follows the device in hand
	InputManager.pad_active = false
	check(InputManager.key_for("reload") == "R"
			and InputManager.key_for("aim") == "RMB",
			"on keys a badge names the key",
			"%s / %s" % [InputManager.key_for("reload"), InputManager.key_for("aim")])
	InputManager.pad_active = true
	check(InputManager.key_for("reload") == "B"
			and InputManager.key_for("aim") == "LT",
			"and on a pad the same actions name the pad",
			"%s / %s" % [InputManager.key_for("reload"), InputManager.key_for("aim")])
	# An action with NO event for the live device falls back to its own name
	# rather than borrowing the other device's badge.
	check(InputManager.key_for("weapon_slot_0") == "weapon_slot_0",
			"an unbound-on-pad action borrows no key badge",
			InputManager.key_for("weapon_slot_0"))

	# --- the pad's badges are ART, and only the pad's
	var art: Texture2D = InputManager.icon_for("reload")
	check(art != null and art.resource_path.get_file() == "b.svg",
			"on a pad an action's badge is its own icon",
			art.resource_path.get_file() if art else "none")
	# The kit covers every control the map uses, so a polled action must never
	# fall back to lettering on a pad - that fallback is for an action with no
	# pad event AT ALL, which is the next claim.
	var artless: Array[String] = []
	for action in NEEDS_PAD:
		if InputManager.icon_for(action) == null:
			artless.append(action)
	check(artless.is_empty(), "and every polled action wears art, not lettering",
			"%d/%d iconned%s" % [NEEDS_PAD.size() - artless.size(),
			NEEDS_PAD.size(),
			"" if artless.is_empty() else ", lettered " + ", ".join(artless)])
	check(InputManager.icon_for("weapon_slot_0") == null,
			"an action with no pad event at all gets no art either",
			str(InputManager.icon_for("weapon_slot_0")))
	InputManager.pad_active = false
	# The labels COLLIDE across devices - "A" is a face button and also the key
	# under move_left - so the gate is the live device, not the string.
	check(InputManager.icon_for("reload") == null
			and InputManager.icon_for_key("A") == null,
			"and on keys there is no art at all, whatever the label says",
			str(InputManager.icon_for_key("A")))
	# The table cannot drift from the folder: every name in it must be on disk.
	var absent: Array[String] = []
	for label in InputManager.PAD_ICONS:
		var path: String = "%s/%s.svg" % [InputManager.PAD_ICON_DIR,
				InputManager.PAD_ICONS[label]]
		if not ResourceLoader.exists(path):
			absent.append(InputManager.PAD_ICONS[label])
	check(absent.is_empty(), "every icon the table names is on disk",
			"%d mapped%s" % [InputManager.PAD_ICONS.size(),
			"" if absent.is_empty() else ", missing " + ", ".join(absent)])

	# --- with nothing to aim from, the cursor TRAVELS: menus want a pointer
	InputManager.pad_active = true
	check(not InputManager.stick_look, "a resting stick moves nothing", "idle")
	InputManager.warp_echo = Vector2.INF
	press_stick("look_right")
	InputManager.drive_cursor(0.1)
	check(InputManager.stick_look and InputManager.warp_echo != Vector2.INF,
			"with no body to aim from the cursor travels instead",
			str(InputManager.warp_echo))
	release_stick("look_right")
	InputManager.drive_cursor(0.1)
	check(not InputManager.stick_look, "and rests when the stick does", "idle")

	# --- pointing, not travelling: a turnaround costs ONE frame at any angle
	var game: Node = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	await settle(10)
	InputManager.pad_active = true
	if not check(InputManager.player != null and InputManager.camera != null,
			"the map hands the cursor a body and a camera to aim from",
			"%s / %s" % [InputManager.player, InputManager.camera]):
		finish()
		return
	var body: Vector2 = InputManager.camera.unproject_position(
			InputManager.player.global_position)
	press_stick("look_right")
	for i in 40:
		InputManager.drive_cursor(FRAME)  # settle the heading fully right
	var right: Vector2 = InputManager.warp_echo
	release_stick("look_right")
	check(right.x > body.x and is_equal_approx(right.y, body.y),
			"a held stick puts the aim on its own side, level",
			"%.0f vs body %.0f" % [right.x, body.x])

	# The turnaround, which is what a rate-driven cursor was fatally bad at.
	# It must NOT teleport - a snapped heading reads as a twitch - but it must
	# cross in a fraction of a second whatever the reticle's distance.
	press_stick("look_left")
	InputManager.drive_cursor(FRAME)
	check(InputManager.warp_echo.x > body.x,
			"one frame does not teleport the aim across", "still right of body")
	var frames: int = 1
	while InputManager.warp_echo.x > body.x and frames < 120:
		InputManager.drive_cursor(FRAME)
		frames += 1
	release_stick("look_left")
	# 180 degrees at LOOK_SLEW, and nothing to do with how far out it sits.
	check(frames * FRAME < 0.3, "and crosses the body in a fraction of a second",
			"%d frames, %.2fs to turn round" % [frames, frames * FRAME])
	# Pixels mean nothing against a weapon's range, so the reach is reported in
	# the units the guns are tuned in. One metre ACROSS, matching the left/right
	# reach measured here - the camera is tilted, so a metre up-screen covers
	# fewer pixels and would flatter the number.
	var one_metre: Vector2 = InputManager.camera.unproject_position(
			InputManager.player.global_position + Vector3(1.0, 0.0, 0.0))
	var per_metre: float = one_metre.distance_to(body)

	# Deflection is the RANGE: the same stick picks near and far, read once the
	# eased reach has settled.
	press_stick("look_right", 0.35)
	for i in 60:
		InputManager.drive_cursor(FRAME)
	var near: float = InputManager.warp_echo.distance_to(body)
	# The step the easing exists to hide: widening the push must EASE outward,
	# not fling the reticle the whole way in a single frame.
	press_stick("look_right", 1.0)
	InputManager.drive_cursor(FRAME)
	var first: float = InputManager.warp_echo.distance_to(body)
	for i in 60:
		InputManager.drive_cursor(FRAME)
	var far: float = InputManager.warp_echo.distance_to(body)
	release_stick("look_right")
	check(far > near * 1.5, "a fuller push reaches further out",
			"%.1fm light vs %.1fm full" % [near / per_metre, far / per_metre])
	check(first < near + (far - near) * 0.25,
			"and widening it eases out rather than bumping",
			"%.1fm -> %.1fm in one frame, settling at %.1fm"
			% [near / per_metre, first / per_metre, far / per_metre])

	# A diagonal must survive the screen-edge cut: shortening along the ray
	# keeps the angle, clamping x and y apart would bend it.
	press_stick("look_right", 1.0)
	press_stick("look_up", 1.0)
	for i in 60:
		InputManager.drive_cursor(FRAME)  # the heading turns; let it arrive
	var diagonal: Vector2 = InputManager.warp_echo - body
	release_stick("look_right")
	release_stick("look_up")
	check(absf(diagonal.angle() - Vector2(1.0, -1.0).normalized().angle()) < 0.02,
			"and a cut-short diagonal keeps its heading",
			"%.1f deg off" % rad_to_deg(absf(diagonal.angle()
					- Vector2(1.0, -1.0).normalized().angle())))
	# Released, the aim HOLDS and rides the body rather than staying on the
	# sand. Its HEADING is the claim, not its pixel reach: walking toward the
	# screen edge legitimately shortens a clamped ray without turning it.
	InputManager.player.global_position += Vector3(3.0, 0.0, 0.0)
	await settle(2)
	var moved_body: Vector2 = InputManager.camera.unproject_position(
			InputManager.player.global_position)
	InputManager.drive_cursor(0.016)
	var carried: float = absf((InputManager.warp_echo - moved_body).angle()
			- InputManager.look_dir.angle())
	check(carried < 0.02,
			"and a released stick carries the heading along with the body",
			"%.1f deg off the held heading" % rad_to_deg(carried))

	# --- a live prompt re-badges itself, through the real device switch
	await test_the_prompt(game)
	finish()


# The whole path, not the lookup: an offer is registered, the HUD builds its
# button, and the DEVICE - a real event through _input, the way a hand on the
# pad reaches it - decides whether that button wears art or a letter.
func test_the_prompt(p_game: Node):
	InputManager.create_interaction(self, "noop", "Test offer")
	await settle(4)
	var prompts: Node = find_first(p_game, "CharacterPromptsUI")
	var button: InputKeyButton = find_first(prompts, "InputKeyButton")
	if not check(button != null, "an offer raises a real prompt button", str(button)):
		InputManager.remove_interaction()
		return
	await touch_pad()
	check(button.key_icon.visible and button.key_icon.texture != null
			and not button.key_label.visible,
			"a hand on the pad puts art on the live prompt",
			button.key_icon.texture.resource_path.get_file() \
					if button.key_icon.texture else "none")
	await touch_keys()
	# A prompt is identified by the KEY it shows, so the switch withdraws the
	# pad's prompt and raises the keyboard's - the button is a new one.
	button = find_first(prompts, "InputKeyButton")
	check(button != null and button.key_label.visible
			and not button.key_icon.visible and button.key_label.text == "F",
			"and a hand back on the keys puts the letter back",
			button.key_label.text if button else "no prompt")
	InputManager.remove_interaction()
	await test_the_slots(p_game)
	await test_the_drive(p_game)


# The pad's one weapon button and the dpad's four item slots, on a loadout the
# probe deals itself - the kit is the designer's, and this is not about the kit.
func test_the_slots(_p_game: Node):
	var player: Character = InputManager.player
	var carried: CharacterInventory = player.carried
	var smg: WeaponData = (load("res://data/items/weapons/ranged/smg.tres")
			as WeaponData).duplicate()
	var revolver: WeaponData = (load("res://data/items/weapons/ranged/revolver.tres")
			as WeaponData).duplicate()
	var ammo: ItemData = load("res://data/items/ammo/ammo_light.tres")
	carried.assign_quick_slot(carried.inventory.add_one(smg), 0)
	carried.assign_quick_slot(carried.inventory.add_one(revolver), 1)
	carried.assign_quick_slot(carried.inventory.add_one(ammo), 2)
	carried.select_slot(0)
	await settle(2)

	Input.action_press("toggle_weapon")
	await settle(2)
	Input.action_release("toggle_weapon")
	await settle(2)
	check(carried.active_slot == 1, "a tap of Y flips to the other weapon",
			"slot %d" % carried.active_slot)
	Input.action_press("toggle_weapon")
	await settle_physics(30)  # 0.5s: past the hold threshold
	Input.action_release("toggle_weapon")
	await settle(2)
	check(carried.active_slot == -1 and player.weapons.is_holstered(),
			"held, the same button puts it away", "slot %d" % carried.active_slot)

	Input.action_press("weapon_slot_2")
	await settle(2)
	Input.action_release("weapon_slot_2")
	check(carried.active_slot == 2, "a dpad direction picks its item slot",
			"slot %d" % carried.active_slot)
	carried.bare_hands()


# RT/LT/B through the vehicle's own polling, seated for real - and the quick
# slot bar leaves with the hands.
func test_the_drive(p_game: Node):
	var player: Character = InputManager.player
	var car: Vehicle = find_first(p_game, "Vehicle") as Vehicle
	var bar: Control = find_first(p_game, "QuickSlotsUI") as Control
	if not check(car != null and bar != null, "the map lends a car and the HUD a bar",
			"%s / %s" % [car, bar]):
		return
	InputManager.pad_active = true
	car.add_driver(player)
	await settle_physics(40)  # add_driver's own 0.5s seating beat
	check(not bar.visible, "the quick slots leave with the hands on the wheel",
			"visible %s" % bar.visible)
	check(car.drive_prompts.has(["RT"]) and car.drive_prompts.has(["B"])
			and car.drive_prompts.has(["LS"]),
			"the corner prompts name the pad's own controls",
			str(car.drive_prompts))
	Input.action_press("car_accelerate")
	await settle_physics(3)
	check(is_equal_approx(car.control_throttle, 1.0),
			"RT is the throttle", "%.2f" % car.control_throttle)
	Input.action_release("car_accelerate")
	Input.action_press("car_brake")
	await settle_physics(3)
	check(car.control_brake, "and B is the brake", str(car.control_brake))
	Input.action_release("car_brake")
	await settle_physics(3)
	car.remove_driver(player)
	await settle(4)
	check(bar.visible, "stepping out hands the bar back", "visible %s" % bar.visible)
	InputManager.pad_active = false


func settle_physics(p_frames: int):
	for i in p_frames:
		await get_tree().physics_frame


# A real InputEventJoypadButton through the input stack, so _input's own device
# detection is what flips - not a probe writing pad_active by hand.
func touch_pad():
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A
	event.pressed = true
	Input.parse_input_event(event)
	await settle(4)


func touch_keys():
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = KEY_W
	event.pressed = true
	Input.parse_input_event(event)
	await settle(4)


func noop(_p_player = null):
	pass


# get_vector reads the analog strength, so a probe must press WITH one.
func press_stick(p_action: String, p_strength: float = 1.0):
	Input.action_press(p_action, p_strength)


func release_stick(p_action: String):
	Input.action_release(p_action)


# The physical control an event names. A trigger is one control and a button
# is one, but a STICK AXIS IS TWO - without the sign, move_left and move_right
# read as one button wanted by two actions. The two triggers are named here
# rather than read off PAD_AXIS_LABELS, which is a DISPLAY table and carries the
# sticks under one label each precisely because a badge wants "LS", not a sign.
const TRIGGERS: Array = [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]


func control_key(p_event: InputEvent) -> String:
	if p_event is InputEventJoypadButton:
		return InputManager.PAD_LABELS.get(p_event.button_index,
				"PAD %d" % p_event.button_index)
	if TRIGGERS.has(p_event.axis):
		return InputManager.PAD_AXIS_LABELS[p_event.axis]
	return "AXIS%d%s" % [p_event.axis, "+" if p_event.axis_value > 0.0 else "-"]


func pad_events(p_action: String) -> Array:
	var found: Array = []
	if not InputMap.has_action(p_action):
		return found
	for event in InputMap.action_get_events(p_action):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			found.append(event)
	return found
