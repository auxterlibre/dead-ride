extends ProbeBase
# WINDOWED look check for the carried barrel's area-of-effect ring (headless
# renders blank): hoists the barrel, parks the ghost on clear sand with the
# ring drawn, then diffs the SAME frame with the ring hidden - the camera,
# the sun and the ghost itself cancel out, so the difference IS the circle.

@onready var GAME: PackedScene = load("uid://b56i3a2diovj6")  # scenes/game.tscn


func _ready():
	if not windowed("the carry range ring"):
		finish()
		return
	var game: Node = GAME.instantiate()
	add_child(game)
	await settle(10)
	var player: Character = InputManager.player
	var grid: BuildGrid = Globals.build_grid  # it registers itself; never a path
	var barrel: FuelBarrel = find_first(game, "FuelBarrel")
	var carry: PlayerCarry = null
	for child in player.get_children():
		if child is PlayerCarry:
			carry = child
	if not check(grid != null and barrel != null and carry != null,
			"the map carries grid, barrel and the carry component",
			"%s / %s / %s" % [grid, barrel, carry]):
		finish()
		return
	player.aim.process_mode = Node.PROCESS_MODE_DISABLED
	Globals.camera_follow.look_ahead = Vector3.ZERO
	Calendar.set_time(9, 0)  # out of the scorch, so no haze over the shot
	# build_shot's lesson: pick the CELL first and stand the player beside it,
	# rather than deriving one from wherever the player turned out to be.
	var target: Vector2i = grid.cell_of(Vector3(0.0, 0.0, -20.0))
	player.global_position = grid.world_of(target, Vector2i.ONE) \
			+ Vector3(-2.5, 0.0, 0.0)
	await settle(60)

	carry.pickup(barrel)
	# The component re-reads the real cursor every frame, so the shot has to own
	# the staging or the chosen cell is gone by the next tick.
	carry.set_process(false)
	stage(carry, grid, target, true)
	await settle(30)
	check(carry.chill_reach > 0.0, "the ghost carries a cool reach to draw",
			"%.1fm" % carry.chill_reach)
	var shown: Image = await capture()
	save_shot(shown, "carry_ring_shown")

	# The toggle: same frame, same ghost, ring alone withdrawn.
	var floor_noise: float = await idle_floor()
	stage(carry, grid, target, false)
	await settle(30)
	var hidden: Image = await capture()
	save_shot(hidden, "carry_ring_hidden")
	var delta: float = frame_diff(shown, hidden)
	check(delta > floor_noise * 3.0,
			"the ring is really on the ground, not merely flagged visible",
			"%.4f delta vs %.4f idle" % [delta, floor_noise])
	finish()


# track_cursor() would re-read the mouse; this keeps the staged cell while
# driving the ghost and ring through the same two calls it makes.
func stage(p_carry: PlayerCarry, p_grid: BuildGrid, p_cell: Vector2i,
		p_placeable: bool):
	p_carry.cell = p_cell
	p_carry.placeable = p_placeable
	p_carry.ghost.global_position = p_grid.world_of(p_cell,
			p_carry.barrel_data.footprint)
	p_carry.ghost_tint.albedo_color = PlayerCarry.VALID_TINT if p_placeable \
			else PlayerCarry.BLOCKED_TINT
	p_carry.ring.draw_circle(p_carry.ghost.global_position,
			p_carry.chill_reach if p_placeable else 0.0, PlayerCarry.RING_COLOR)
