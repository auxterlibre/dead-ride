extends ProbeBase
# Windowed only - headless renders blank. The noon shimmer measured by TOGGLING
# it against itself at the same hour, and the burn's smoke the same way; saves
# user://heat_*.png for the eyeball pass.

@onready var GAME: PackedScene = load("uid://b56i3a2diovj6")  # scenes/game.tscn


func _ready():
	if not windowed("the heat wave"):
		finish()
		return
	var game: Node = GAME.instantiate()
	add_child(game)
	await settle(10)

	# The grass sways off wind_path all day - the same trap the streamers set
	# below, and worse, because it moves in BOTH frames and dilutes the ratio.
	var grass: Node3D = find_first(game, "GrassField")
	if grass:
		grass.visible = false

	Calendar.set_time(12, 0)
	await settle(90)  # the haze level lerps; let it converge
	var hazed_a: Image = await capture()
	await settle(30)
	var hazed_b: Image = await capture()
	save_shot(hazed_a, "heat_noon")

	# The shimmer is toggled at the SAME hour rather than compared against the
	# morning. "The morning holds still" stopped being true when the sand shader
	# grew its wind streamers - they run all day off wind_path - so the old
	# noon-vs-morning ratio was measuring the wind as much as the heat, and the
	# real effect scored 1.77x against a bar of 2x.
	var heat: HeatWave = Globals.heat
	# _process rewrites visible and intensity every frame: the same trap the
	# chill spots and the dust banks each set, and it has to lose its clock
	# before the toggle will hold.
	heat.set_process(false)
	heat.haze.visible = false
	await settle(30)
	var still_a: Image = await capture()
	await settle(30)
	var still_b: Image = await capture()
	heat.haze.visible = true
	heat.set_process(true)
	if grass:
		grass.visible = true

	var shimmer: float = frame_diff(hazed_a, hazed_b, 8, 1.0 / 3.0)
	var without: float = frame_diff(still_a, still_b, 8, 1.0 / 3.0)
	print("DBG MOTION hazed=%.5f still=%.5f" % [shimmer, without])
	check(shimmer > without * 1.4 and shimmer > 0.002,
			"the noon air crawls in a way the same air without the haze does not",
			"%.5f hazed vs %.5f still" % [shimmer, without])

	# A morning frame for the eyeball pass; the claim above no longer rests on it.
	Calendar.set_time(8, 0)
	await settle(90)
	var morning: Image = await capture()
	save_shot(morning, "heat_morning")

	# The burn's own feedback, which the station never shows: the spawn stands
	# in the pump's cool pocket, so the player has to be walked out onto open
	# sand before the sun will touch him at all.
	var player: Character = InputManager.player
	player.global_position = Vector3(0.0, 0.0, -18.0)
	Calendar.set_time(12, 0)
	await settle(200)  # camera glide, then a point or two burnt
	var burning: Image = await capture()
	save_shot(burning, "heat_burning")
	# Wisps around a small character are easy to miss in a still - three of
	# these captures were called "no smoke" by eye while it was rendering the
	# whole time - so the burn's smoke is TOGGLED and measured, not looked at.
	var puff: GPUParticles3D = player.heat.smoke
	var with_smoke: Image = await capture()
	puff.emitting = false
	await settle(130)  # the last puffs live out their lifetime
	var without_smoke: Image = await capture()
	puff.emitting = true
	var smoke_delta: float = frame_diff(with_smoke, without_smoke, 8, 1.0 / 3.0)
	print("DBG SMOKE on/off delta=%.5f" % smoke_delta)
	check(smoke_delta > 0.005, "the burning player visibly smokes",
			"%.5f mean delta" % smoke_delta)
	print("DBG burning capture saved: %d hp" % player.current_health)
	finish()
