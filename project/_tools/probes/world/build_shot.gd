extends ProbeBase
# WINDOWED look check for the build ghost (headless renders blank): drives
# PlayerBuild into placement, parks the ghost on free sand and then over an
# occupied cell, and saves both for the eyeball pass.

@onready var GAME: PackedScene = load("uid://b56i3a2diovj6")  # scenes/game.tscn


func _ready():
	if not windowed("the build ghost"):
		finish()
		return
	var game: Node = GAME.instantiate()
	add_child(game)
	await settle(10)
	var player: Character = InputManager.player
	var grid: BuildGrid = Globals.build_grid  # it registers itself; never a path
	var build: PlayerBuild = null
	for child in player.get_children():
		if child is PlayerBuild:
			build = child
	player.aim.process_mode = Node.PROCESS_MODE_DISABLED
	Globals.camera_follow.look_ahead = Vector3.ZERO
	# The CELL is chosen first and the player stood beside it, so the ghost is
	# certain to be in frame - deriving the cell from the player put it forty
	# metres away when he turned out not to be where he was put.
	var target: Vector2i = grid.cell_of(Vector3(0.0, 0.0, -20.0))
	player.global_position = grid.world_of(target, Vector2i.ONE) \
			+ Vector3(-2.5, 0.0, 0.0)
	PlayerData.add_money(500)  # through the API, so the HUD purse hears it
	Calendar.set_time(9, 0)  # out of the scorch, so no haze over the shot
	await settle(60)

	build.start(load("res://data/buildables/crop_plot.tres"))
	# The component re-reads the real cursor every frame, so the shot has to
	# own it or the staged cell is gone by the next tick.
	build.set_process(false)
	build.cell = target
	place_ghost(build, grid)
	await settle(30)
	check(build.placeable, "the ghost reads placeable on open sand",
			"cell %s" % build.cell)
	var valid: Image = await capture()
	save_shot(valid, "build_ghost_valid")

	# Stand something there, and the same cell must read blocked.
	grid.place(load("res://data/buildables/fuel_barrel.tres"), build.cell, 0)
	place_ghost(build, grid)
	await settle(30)
	check(not build.placeable, "and blocked once that cell is taken",
			"cell %s" % build.cell)
	var blocked: Image = await capture()
	save_shot(blocked, "build_ghost_blocked")
	finish()


# track_cursor() would re-read the mouse; this keeps the staged cell.
func place_ghost(p_build: PlayerBuild, p_grid: BuildGrid):
	p_build.placeable = p_grid.can_place(p_build.active, p_build.cell, p_build.yaw) \
			and PlayerData.current_money >= p_build.active.price
	p_build.ghost.global_position = p_grid.world_of(p_build.cell,
			p_grid.rotated_size(p_build.active, p_build.yaw))
	p_build.ghost_tint.albedo_color = PlayerBuild.VALID_TINT if p_build.placeable \
			else PlayerBuild.BLOCKED_TINT
