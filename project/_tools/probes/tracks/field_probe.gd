extends ProbeBase
# Is the sand field actually wired in game.tscn? Buffer handed to the material,
# camera framing the ground, every vehicle stamping, and only on sand.

const EXPECTED_CHECKS: int = 8

var game: Node
var car: Vehicle


func _ready():
	game = (load("res://scenes/game.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var field: SandField = game.find_child("SandField", true, false)
	car = game.find_child("Car", true, false)
	# The 08:00 truck rolls in on a nondeterministic entry, and the player now
	# spawns at the station inside the weave square - either one wedges the
	# demo car mid-run. Neither is this probe's subject; both step aside.
	var service: DeliveryService = find_first(game, "DeliveryService")
	if is_instance_valid(service.truck):
		service.truck.queue_free()
	service.queue_free()
	# By group, not path: the scene's node layout is the level designer's to
	# rearrange, and it has moved under them once already.
	get_tree().get_first_node_in_group("player").global_position = \
			Vector3(-30.0, 0.0, -30.0)

	check(field.sand.get_shader_parameter("trail_tex") != null,
			"the material reads the trail buffer", str(field.sand.get_shader_parameter("trail_tex")))
	check(is_equal_approx(field.trail_camera.size,
			field.sand.get_shader_parameter("world_size")),
			"the trail camera frames the shader's square",
			"%.0fm" % field.trail_camera.size)
	var camera: Camera3D = Globals.camera_follow.camera  # the rig registers itself
	check(camera.cull_mask & 2 == 0,
			"the main camera does not draw the raw stamps", str(camera.cull_mask))

	var stamps: Array[Node] = car.find_children("*", "GPUParticles3D", true, false) \
			.filter(func(p): return p.layers == 2)
	check(stamps.size() == 4, "the car grew a stamp per wheel", str(stamps.size()))
	check(stamps.all(func(s): return not s.emitting),
			"parked, nothing stamps", "")

	# Drive it: the same demo controller the tracks probe uses.
	var demo: VehicleSteering = load("uid://5y674hblljn1").new()  # tracks_driver.gd
	demo.demo = true
	car.add_child(demo)
	car.start_engine()
	await seconds(4.0)
	check(car.ground_fx != null and car.ground_fx.ground != null \
			and car.ground_fx.ground.displaced_tracks,
			"the desert reports displaced tracks",
			str(car.ground_fx.ground if car.ground_fx else null))
	check(stamps.all(func(s): return s.emitting),
			"a moving car stamps from every wheel", "speed %.1f" % car.speed)
	check(field.wind_path.length() > 1.0, "and the wind has travelled",
			"%.1fm" % field.wind_path.length())

	print("DBG %d passed, %d failed, %d of %d checks ran" % [
			passed, failed, passed + failed, EXPECTED_CHECKS])
	get_tree().quit()


func seconds(p_span: float):
	var frames: int = int(p_span * 60.0)
	for i in frames:
		await get_tree().physics_frame
