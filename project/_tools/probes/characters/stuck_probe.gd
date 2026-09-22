extends ProbeBase
# DBG probe: the reported wedge - a player standing in the gap of a loot box
# pair (or shoved into a box) must be able to walk OUT in some direction.

const DRIVE_TIME: float = 1.2  # sec of held input per direction
const ESCAPE: float = 1.0  # m of net displacement that counts as free
const SWEEP: int = 4  # grid steps per axis when sweeping a gap for pinches
const SWEEP_SPAN: float = 1.2  # m either side of the gap centre swept

const DIRECTIONS: Dictionary = {
	"move_up": Vector3(0, 0, -1), "move_down": Vector3(0, 0, 1),
	"move_left": Vector3(-1, 0, 0), "move_right": Vector3(1, 0, 0),
}

@onready var GAME: PackedScene = load("uid://b56i3a2diovj6")  # scenes/game.tscn

var player: Character


func _ready():
	var game: Node = GAME.instantiate()
	add_child(game)
	for i in 8:
		await get_tree().process_frame
	player = InputManager.player
	# The scavenger works these exact crates: it shot the first run's player
	# dead mid-sweep and every later spot measured a corpse. Clear the guns out.
	for brain in game.find_children("*", "EnemyAI", true, false):
		brain.get_parent().queue_free()
	await get_tree().process_frame

	# The two box pairs as placed in game.tscn, and a spot overlapping a hull.
	await try_spot("the WestFlats pair gap", Vector3(-44.8, 0.1, 8.6))
	await try_spot("the SouthEdge pair gap", Vector3(12.8, 0.1, -47.5))
	await try_spot("half inside the small box", Vector3(-45.4, 0.1, 9.0))
	# Standing ON each low box, where a knockback hop can land a body.
	await try_spot("on top of the small box", Vector3(-45.6, 0.62, 9.2))
	await try_spot("on top of the large crate", Vector3(-44.0, 1.2, 8.0))
	# And a dense sweep of both gaps for any pinch the hand-picked spots missed.
	await sweep_gap("WestFlats", Vector3(-44.8, 0.1, 8.6))
	await sweep_gap("SouthEdge", Vector3(12.8, 0.1, -47.5))

	finish()


# Tries a lattice of start spots around the gap centre; any spot that cannot
# reach ESCAPE in ANY direction is a pinch worth naming.
func sweep_gap(p_label: String, p_center: Vector3):
	var pinched: Array = []
	for ix in SWEEP + 1:
		for iz in SWEEP + 1:
			var offset: Vector3 = Vector3(
					lerpf(-SWEEP_SPAN, SWEEP_SPAN, ix / float(SWEEP)), 0.0,
					lerpf(-SWEEP_SPAN, SWEEP_SPAN, iz / float(SWEEP)))
			var spot: Vector3 = p_center + offset
			var best: float = 0.0
			for action in DIRECTIONS:
				player.global_position = spot
				player.velocity = Vector3.ZERO
				await get_tree().physics_frame
				Input.action_press(action)
				for i in int(DRIVE_TIME * 30.0):  # shorter drives; 100 spots
					await get_tree().physics_frame
				Input.action_release(action)
				best = maxf(best, flat_distance(player.global_position, spot))
				if best >= ESCAPE:
					break  # this spot is free; no need to try the rest
			if best < ESCAPE:
				pinched.append("%s->%.2fm" % [spot.snappedf(0.1), best])
	check(pinched.is_empty(), "no pinch points in the %s sweep" % p_label,
			"%d pinched: %s" % [pinched.size(), str(pinched)] \
			if not pinched.is_empty() else "all %d spots free" % ((SWEEP + 1) * (SWEEP + 1)))


# Parks the player at the spot and tries to walk out in each direction,
# teleporting back between tries so every direction starts from the pinch.
func try_spot(p_label: String, p_spot: Vector3):
	var best: float = 0.0
	var best_direction: String = "-"
	for action in DIRECTIONS:
		player.global_position = p_spot
		player.velocity = Vector3.ZERO
		await get_tree().physics_frame
		Input.action_press(action)
		var frames: int = int(DRIVE_TIME * 60.0)
		for i in frames:
			await get_tree().physics_frame
		Input.action_release(action)
		var moved: float = flat_distance(player.global_position, p_spot)
		if moved > best:
			best = moved
			best_direction = action
		print("DBG   %s %s: %.2fm" % [p_label, action, moved])
	check(best >= ESCAPE, "%s can be walked out of" % p_label,
			"best %.2fm via %s" % [best, best_direction])


func flat_distance(p_from: Vector3, p_to: Vector3) -> float:
	return Vector2(p_from.x - p_to.x, p_from.z - p_to.z).length()
