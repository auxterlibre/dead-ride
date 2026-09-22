extends ProbeBase
# Windowed only - headless renders blank. Kills the player and measures the
# hand-over: the death screen has to arrive after the corpse beat, and the world
# behind it has to lose its colour, which is the one claim a still cannot settle.

@onready var GAME: PackedScene = load("uid://b56i3a2diovj6")  # scenes/game.tscn


func _ready():
	if not windowed("the death screen"):
		finish()
		return
	var game: Node = GAME.instantiate()
	add_child(game)
	await settle(8)

	var alive: Image = await capture()
	var creep: float = await idle_floor()

	var player: Character = InputManager.player
	player.take_damage(AttackData.new(9999, player.global_position, 0.0, null))
	var screen: DeathScreen = game.find_children("*", "DeathScreen", true, false).front()
	var wait: float = screen.CORPSE_BEAT + 0.5
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--wait="):
			wait = float(arg.get_slice("=", 1))
	await get_tree().create_timer(wait).timeout
	var dead: Image = await capture()

	check(screen.visible, "the death screen takes over after the corpse beat",
			"visible %s, %.1fs after the hit" % [screen.visible, wait])
	var delta: float = frame_diff(alive, dead, 8)
	check(delta > maxf(creep * 6.0, 0.004), "and the frame it hands over is not the one before it",
			"%.5f over %.5f creep" % [delta, creep])
	# "Death drains the colour" is NOT a saturation claim. The screen does not
	# wash the world out, it replaces every hue with one blue - and a flat blue
	# is highly saturated, so mean saturation scored the effect working properly
	# (0.72 -> 0.66) as a failure. What collapses is the SPREAD of hues.
	var before: float = hue_spread(alive)
	var after: float = hue_spread(dead)
	check(after < before * 0.5, "and the colour drains out of the world behind it",
			"hue spread %.3f -> %.3f" % [before, after])
	save_shot(dead, "death_screen")
	get_tree().paused = false
	finish()


# How widely the frame's hues are spread around the colour wheel: 0 is every
# pixel the same hue, 1 is hues scattered evenly. Circular, so the wrap from
# 1.0 back to 0.0 reads as the neighbouring reds it actually is, and weighted by
# saturation because a grey pixel's hue is arbitrary and would drown the rest.
func hue_spread(p_image: Image, p_step: int = 8) -> float:
	var across: float = 0.0
	var up: float = 0.0
	var weight: float = 0.0
	for y in range(0, p_image.get_height(), p_step):
		for x in range(0, p_image.get_width(), p_step):
			var pixel: Color = p_image.get_pixel(x, y)
			var angle: float = pixel.h * TAU
			across += cos(angle) * pixel.s
			up += sin(angle) * pixel.s
			weight += pixel.s
	if weight <= 0.0:
		return 0.0
	return 1.0 - Vector2(across, up).length() / weight
