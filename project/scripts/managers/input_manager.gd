extends Node3D

const CURSOR_SPEED:float = 2200.0
const AIM_REACH_NEAR:float = 0.10
const AIM_REACH_FAR:float = 1.0
const LOOK_SLEW:float = 900.0
const REACH_SLEW:float = 4.0
const LOOK_JITTER:float = 1.0
const PAD_LABELS:Dictionary = {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "SELECT", JOY_BUTTON_START: "START",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "UP", JOY_BUTTON_DPAD_DOWN: "DOWN",
	JOY_BUTTON_DPAD_LEFT: "LEFT", JOY_BUTTON_DPAD_RIGHT: "RIGHT",
}
const PAD_AXIS_LABELS:Dictionary = {
	JOY_AXIS_TRIGGER_LEFT: "LT", JOY_AXIS_TRIGGER_RIGHT: "RT",
	JOY_AXIS_LEFT_X: "LS", JOY_AXIS_LEFT_Y: "LS",
	JOY_AXIS_RIGHT_X: "RS", JOY_AXIS_RIGHT_Y: "RS",
}
const MOUSE_LABELS:Dictionary = {
	MOUSE_BUTTON_LEFT: "LMB", MOUSE_BUTTON_RIGHT: "RMB",
	MOUSE_BUTTON_MIDDLE: "MMB",
}
# The pad's badge ART, keyed by the LABEL the two tables above already resolve a
# control to - so one table serves both, and a control with no art (SELECT,
# START, the d-pad) simply keeps its text badge. A second pad family is a second
# directory, not a second lookup.
const PAD_ICON_DIR:String = "res://assets/textures/icons/input/xbox"
const PAD_ICONS:Dictionary = {
	"A": "a", "B": "b", "X": "x", "Y": "y",
	"LB": "lb", "RB": "rb", "LT": "lt", "RT": "rt",
	"LS": "ls", "RS": "rs",
	"L3": "left_stick_press", "R3": "right_stick_press",
	"SELECT": "view", "START": "menu",
	"UP": "dpad_up", "DOWN": "dpad_down",
	"LEFT": "dpad_left", "RIGHT": "dpad_right",
}

var player:Character
var camera:Camera3D
var interactions:Array[Dictionary] = []
var shown_prompts:Array[String] = []
# A clickable prompt has the cursor, so the weapon holds fire - clicking the
# offer must not also put a round through it.
var pointer_over_prompt:bool = false
var pad_active:bool = false
var stick_look:bool = false
var look_dir:Vector2 = Vector2.ZERO
var look_reach:float = 0.0
var warp_echo:Vector2 = Vector2.INF


func _input(p_event:InputEvent):
	if p_event is InputEventMouseMotion \
			and p_event.position.distance_to(warp_echo) < 2.0:
		warp_echo = Vector2.INF
		return
	var pad:bool = p_event is InputEventJoypadButton \
			or p_event is InputEventJoypadMotion
	var desk:bool = p_event is InputEventKey or p_event is InputEventMouseButton \
			or p_event is InputEventMouseMotion
	if pad == desk or pad == pad_active:
		return
	pad_active = pad
	Signals.input_device_changed.emit(pad_active)
	refresh_prompts()


func _process(p_delta):
	drive_cursor(p_delta)
	if player == null: return
	for input in active_inputs():
		# A HOLD offer (the fuel nozzle) runs every frame the key is down; the
		# rest fire once on the press.
		var entry:Dictionary = latest_for(input)
		if entry.get("hold", false):
			if Input.is_action_pressed(input):
				try_to_interact(input)
		elif Input.is_action_just_pressed(input):
			try_to_interact(input)

	# Time scale, clock and debug draw now live in the F9 DebugMenu; only the
	# one-key vision-cone toggle stays here.
	if OS.is_debug_build() and Input.is_action_just_pressed("debug_text_toggle"):
		Globals.debug_mode = not Globals.debug_mode
		Globals.debug_labels = Globals.debug_mode


# p_input lets one target carry several offers at once - the car's ENTER, its
# trunk and its repair are all in range together, each on its own key.
func create_interaction(p_target, p_callback, p_action, p_audio = null,
		p_input:String = "interact", p_hold:bool = false,
		p_placement:Enums.PromptPlacement = Enums.PromptPlacement.CHARACTER):
	erase_interaction(p_target, p_callback)
	interactions.append({target = p_target, callback = p_callback,
			action = p_action, audio = p_audio, input = p_input, hold = p_hold,
			placement = p_placement})
	refresh_prompts()


# Target + callback identify an entry - target alone is ambiguous. No arguments clears everything.
func remove_interaction(p_target = null, p_callback:String = ""):
	if p_target == null:
		interactions.clear()
	else:
		erase_interaction(p_target, p_callback)
	refresh_prompts()


func active_inputs() -> Array[String]:
	var result:Array[String] = []
	for entry in interactions:
		if not result.has(entry.input):
			result.append(entry.input)
	# Sorted, so prompts stack in a fixed order instead of whichever area the
	# physics step happened to report first: interact, _secondary, _tertiary.
	result.sort()
	return result


func drive_cursor(p_delta:float):
	var look:Vector2 = Input.get_vector("look_left", "look_right",
			"look_up", "look_down")
	if Settings.invert_look_y:
		look.y = -look.y
	stick_look = look != Vector2.ZERO
	if not pad_active:
		return
	var viewport:Viewport = get_viewport()
	if player == null or camera == null:
		if stick_look:
			warp(viewport, viewport.get_mouse_position()
					+ look * look.length() * CURSOR_SPEED * p_delta)
		return
	if stick_look:
		aim_toward(look, p_delta)
	if look_dir == Vector2.ZERO:
		return
	var body:Vector2 = camera.unproject_position(player.global_position)
	var screen:Vector2 = viewport.get_visible_rect().size
	warp(viewport, body + shortened(body,
			look_dir * look_reach * screen.y, screen))


func aim_toward(p_look:Vector2, p_delta:float):
	var wanted:Vector2 = p_look.normalized()
	var reach:float = lerpf(AIM_REACH_NEAR, AIM_REACH_FAR,
			minf(p_look.length(), 1.0))
	if look_dir == Vector2.ZERO:
		look_dir = wanted
		look_reach = reach
		return
	var turn:float = look_dir.angle_to(wanted)
	if absf(turn) > deg_to_rad(LOOK_JITTER):
		var step:float = deg_to_rad(Settings.look_slew_value()) * p_delta
		look_dir = look_dir.rotated(clampf(turn, -step, step))
	look_reach = move_toward(look_reach, reach, REACH_SLEW * p_delta)


func shortened(p_body:Vector2, p_offset:Vector2, p_screen:Vector2) -> Vector2:
	var fit:float = 1.0
	if not is_zero_approx(p_offset.x):
		fit = minf(fit, (clampf(p_body.x + p_offset.x, 0.0, p_screen.x)
				- p_body.x) / p_offset.x)
	if not is_zero_approx(p_offset.y):
		fit = minf(fit, (clampf(p_body.y + p_offset.y, 0.0, p_screen.y)
				- p_body.y) / p_offset.y)
	return p_offset * maxf(fit, 0.0)


func warp(p_viewport:Viewport, p_to:Vector2):
	warp_echo = p_to.clamp(Vector2.ZERO, p_viewport.get_visible_rect().size)
	p_viewport.warp_mouse(warp_echo)


func key_for(p_input:String) -> String:
	for event in InputMap.action_get_events(p_input):
		if pad_active:
			if event is InputEventJoypadButton:
				return PAD_LABELS.get(event.button_index,
						"PAD %d" % event.button_index)
			if event is InputEventJoypadMotion:
				return PAD_AXIS_LABELS.get(event.axis, "AXIS %d" % event.axis)
			continue
		if event is InputEventKey:
			return event.as_text_physical_keycode() if event.physical_keycode != 0 \
					else event.as_text_keycode()
		if event is InputEventMouseButton:
			return MOUSE_LABELS.get(event.button_index, "MOUSE")
	return p_input


# The art for an action on the LIVE device, or null - which is the answer for
# every keyboard prompt, and for a pad control the kit has no icon for. A null
# is not a failure: the caller keeps the text badge key_for() gives it.
func icon_for(p_input:String) -> Texture2D:
	return icon_for_key(key_for(p_input))


# Gated on the pad being live, because the labels COLLIDE across devices: "A" is
# the pad's bottom face button and also the keyboard key under move_left.
func icon_for_key(p_key:String) -> Texture2D:
	if not pad_active or not PAD_ICONS.has(p_key):
		return null
	var path:String = "%s/%s.svg" % [PAD_ICON_DIR, PAD_ICONS[p_key]]
	return load(path) if ResourceLoader.exists(path) else null


func erase_interaction(p_target, p_callback:String):
	for i in range(interactions.size() - 1, -1, -1):
		if interactions[i].target == p_target and interactions[i].callback == p_callback:
			interactions.remove_at(i)


# Freed targets (e.g. the car exploding inside its own door area, which
# never fires body_exited) are dropped lazily.
func active_interaction() -> Dictionary:
	while not interactions.is_empty() \
			and not is_instance_valid(interactions.back().target):
		interactions.pop_back()
	return {} if interactions.is_empty() else interactions.back()


# One prompt per input action, showing the most recently offered use of that
# key - so the trunk and the driver's door advertise side by side.
func refresh_prompts():
	for key in shown_prompts:
		Signals.input_info_removed.emit([key])
	shown_prompts.clear()
	for input in active_inputs():
		var entry:Dictionary = latest_for(input)
		if entry.is_empty():
			continue
		var key:String = key_for(input)
		Signals.input_info_added.emit([key], entry.action,
				entry.get("placement", Enums.PromptPlacement.CHARACTER), input)
		shown_prompts.append(key)


func latest_for(p_input:String) -> Dictionary:
	for i in range(interactions.size() - 1, -1, -1):
		if interactions[i].input == p_input \
				and is_instance_valid(interactions[i].target):
			return interactions[i]
	return {}


func try_to_interact(p_input:String = "interact"):
	var current:Dictionary = latest_for(p_input)
	if current.is_empty():
		return
	current.target.call(current.callback, player)
	# A held offer calls this every frame, so its sound starts once and runs
	# rather than restarting on top of itself.
	if current.audio and not (current.get("hold", false) and current.audio.playing):
		current.audio.play()


func get_world_mouse_pos() -> Vector3:
	var mouse_coords = get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_coords)
	var to = from + camera.project_ray_normal(mouse_coords) * 1_000
	var space = get_world_3d().direct_space_state

	var params := PhysicsRayQueryParameters3D.create(from, to)
	var intersection = space.intersect_ray(params)
	if intersection:
		return intersection["position"]
	return Vector3()
