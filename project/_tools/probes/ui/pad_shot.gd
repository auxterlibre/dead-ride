extends ProbeBase
# DBG shot (windowed): the prompt badge with a pad in hand. Every other shot
# runs on the keyboard, so the pad's art is a look nothing else can catch -
# and a whole-frame diff cannot see a 64px badge in a 3840px frame, so the
# measurement is cropped to the button itself.

@onready var GAME: PackedScene = load("uid://b56i3a2diovj6")  # scenes/game.tscn

var button: InputKeyButton
var region: Rect2i  # the badge's box, fixed on the KEYBOARD look: the icon is
					# the narrower of the two, so this frame holds both


func _ready():
	if not windowed("the pad badge"):
		finish()
		return
	var game: Node = GAME.instantiate()
	add_child(game)
	await settle(8)
	InputManager.create_interaction(self, "noop", "Search")
	await settle(6)
	var prompts: Node = find_first(game, "CharacterPromptsUI")
	button = find_first(prompts, "InputKeyButton")
	if not check(button != null, "an offer raises a prompt to photograph",
			str(button)):
		finish()
		return

	# The BADGE SLOT, not the whole button: the rest of the button is a 55%
	# fill over moving sand, which drowns the very change being measured (the
	# first go read 0.0168 of badge change against a 0.0177 idle floor).
	# The column is re-anchored to the player EVERY frame, so the badge slides a
	# pixel or two under a drifting camera - and a moving high-contrast edge
	# swamps a 28px crop (0.0177 of "idle" change, as much as the swap itself).
	# Freezing the layer pins the badge; signals still reach a disabled node, so
	# the device switch still rebuilds the prompt.
	prompts.process_mode = Node.PROCESS_MODE_DISABLED
	region = box(button.key_label, await capture())
	# What the badge costs while nothing changes: the world keeps moving behind
	# a 55%-alpha fill, so the bar is measured, not picked.
	var first: Image = await badge()
	await settle(6)
	var idle: float = frame_diff(first, await badge(), 2)
	var keys: Image = await badge()
	save_shot(keys, "pad_badge_keys")
	save_shot(await capture(), "pad_frame_keys")

	await touch_pad()
	# The switch withdraws the keyboard's prompt and raises the pad's, so the
	# button is a NEW one - the box it is photographed in stays put.
	button = find_first(prompts, "InputKeyButton")
	if not check(button != null, "the switch leaves a prompt standing", str(button)):
		finish()
		return
	check(button.key_icon.visible and not button.key_label.visible,
			"the pad swaps the letter for art",
			button.key_icon.texture.resource_path.get_file() \
					if button.key_icon.texture else "none")
	# The badge slot is 64px in the mockup; art drawn at half that would pass
	# every wiring check and still look wrong.
	check(absf(button.key_icon.size.y - 64.0) < 1.0,
			"and fills the badge's own 64px slot",
			"%.0fx%.0f" % [button.key_icon.size.x, button.key_icon.size.y])
	var pad: Image = await badge()
	save_shot(pad, "pad_badge_pad")
	save_shot(await capture(), "pad_frame_pad")
	check(frame_diff(keys, pad, 2) > maxf(idle, 0.001) * 4.0,
			"and the badge really redraws on screen",
			"%.4f of change against a %.4f idle floor"
			% [frame_diff(keys, pad, 2), idle])
	InputManager.remove_interaction()
	finish()


func badge() -> Image:
	var frame: Image = await capture()
	return frame.get_region(region.intersection(
			Rect2i(0, 0, frame.get_width(), frame.get_height())))


# A control's rectangle in the FRAME's pixels: the 3840x2160 design is stretched
# into the window, so a Control's own coordinates are not the image's. THE SCALE
# COMES OFF THE CAPTURED IMAGE - `get_viewport().get_texture().get_size()` is
# NOT what capture() hands back (it reported 1707x960 for a 2560x1440 frame),
# and cropping with it lands the badge box out on the open sand.
func box(p_control: Control, p_frame: Image) -> Rect2i:
	var scale: Vector2 = Vector2(p_frame.get_width(), p_frame.get_height()) \
			/ get_viewport().get_visible_rect().size
	var rect: Rect2 = p_control.get_global_rect()
	return Rect2i(rect.position * scale, rect.size * scale)


func touch_pad():
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A
	event.pressed = true
	Input.parse_input_event(event)
	await settle(6)


func noop(_p_player = null):
	pass
