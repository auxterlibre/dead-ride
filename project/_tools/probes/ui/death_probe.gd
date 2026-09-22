extends ProbeBase
# DBG probe: dying fades the world to grayscale over an unpaused corpse beat,
# the scrim lands and pauses, and respawning reloads with the purse intact.

@onready var GAME: PackedScene = load("uid://b56i3a2diovj6")  # scenes/game.tscn


func _ready():
	# Respawn consults the save now; isolate on empty probe paths so this
	# probe keeps testing the NO-SAVE fallback (fresh reload, purse kept).
	SaveManager.save_path = "user://probe_death.json"
	SaveManager.backup_path = "user://probe_death.bak"
	var game: Node = GAME.instantiate()
	# Respawn reloads the CURRENT scene, and set_current_scene only accepts a
	# DIRECT child of root - parent it there, or the reload restarts this
	# probe in a loop (measured: it does, forever).
	get_tree().root.add_child.call_deferred(game)
	await get_tree().process_frame
	get_tree().current_scene = game
	for i in 8:
		await get_tree().process_frame

	var player: Character = InputManager.player
	check(player != null, "the world has a player", str(player))
	var screen: DeathScreen = game.find_children("*", "DeathScreen", true, false).front()
	check(screen != null and not screen.visible, "the death screen waits hidden",
			"visible" if screen and screen.visible else "hidden")

	PlayerData.current_money = 123
	player.take_damage(AttackData.new(9999, player.global_position, 0.0, null))
	check(player.is_dead, "the player dies to lethal damage",
			"dead" if player.is_dead else "alive")
	# The redesigned flow: the screen shows at once but TRANSPARENT - the
	# grayscale ramps over the corpse while the world keeps moving unpaused.
	check(screen.visible and screen.scrim.modulate.a < 0.1 \
			and not get_tree().paused,
			"the death fade starts over a still-running world",
			"scrim %.2f, paused=%s" % [screen.scrim.modulate.a, get_tree().paused])
	await get_tree().create_timer(4.4).timeout  # grayscale 3s + scrim tail
	check(screen.scrim.modulate.a > 0.9 and get_tree().paused,
			"then the scrim lands and the world pauses",
			"scrim %.2f paused=%s" % [screen.scrim.modulate.a, get_tree().paused])

	screen.respawn()
	for i in 10:
		await get_tree().process_frame
	var reloaded: Node = get_tree().current_scene
	check(is_instance_valid(reloaded) and reloaded != game,
			"respawn reloads the world", str(reloaded))
	check(InputManager.player != null and InputManager.player != player \
			and not InputManager.player.is_dead, "a live player stands again",
			str(InputManager.player))
	check(PlayerData.current_money == 123, "and the purse survived death",
			"$%d" % PlayerData.current_money)
	check(not get_tree().paused, "the world runs unpaused",
			"paused" if get_tree().paused else "running")

	finish()
