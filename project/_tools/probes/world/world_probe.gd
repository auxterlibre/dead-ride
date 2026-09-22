extends Node
# DBG probe: the ground mesh and the road ribbon - what the world reports
# underfoot, and one wide shot of the station to look at (windowed runs only).

@onready var GAME: PackedScene = load("uid://b56i3a2diovj6")  # scenes/game.tscn

var passed: int = 0
var failed: int = 0


func _ready():
	ProbeBase.silence()  # not on ProbeBase yet, so it mutes for itself
	var game: Node = GAME.instantiate()
	add_child(game)
	for i in 12:  # let the player and the parked car settle onto the floor
		await get_tree().process_frame

	var world: World3D = get_viewport().world_3d
	surface_at(world, Vector3(-40, 0, -40), "sand", "open desert")
	surface_at(world, Vector3(0, 0, 21), "cement", "the forecourt lane")
	surface_at(world, Vector3(-50, 0, 30), "cement", "the highway")
	surface_at(world, Vector3(5, 0, 12), "sand", "the delivery bay")

	# By group, not path: the scene's layout is the designer's to rearrange.
	var player: Node3D = get_tree().get_first_node_in_group("player")
	check(absf(player.global_position.y) < 0.5, "the player stands on the floor",
			"y=%.3f" % player.global_position.y)
	var car: Vehicle = game.find_child("Car", true, false)
	check(absf(car.global_position.y) < 0.5, "and the car rests on it",
			"y=%.3f" % car.global_position.y)

	# By name, not path: the terrain nodes have moved under a Map parent once
	# already, and the painter plugin resolves them by name for the same reason.
	var floors: GridMap = game.find_child("TerrainFloors", true, false)
	var ground: Ground = game.find_child("Ground", true, false)
	check(floors.get_used_cells().size() < 100, "the floors map keeps only the hills",
			"%d cells left, ground covers %s" % [floors.get_used_cells().size(),
			ground.columns()])
	# The hill still has to be standing on top of the new floor.
	var hill: Dictionary = raycast(world, Vector3(-16, 0, -12))
	print("DBG hill sample: %s at y=%.2f" % [
			hill.collider.name if hill.has("collider") else "nothing",
			hill.position.y if hill.has("position") else 0.0])

	# Crates dropped into the desert must sit on flat sand, not inside a cliff.
	for crate in get_tree().get_nodes_in_group("loot_container"):
		var under: Dictionary = raycast(world, crate.global_position)
		check(under.has("collider") and under.collider.name == "Ground"
				and absf(under.position.y) < 0.05, "%s stands on flat sand" % crate.name,
				"%s at y=%.2f" % [under.collider.name if under.has("collider")
				else "nothing", under.position.y if under.has("position") else 0.0])

	await capture()
	print("DBG %d passed, %d failed" % [passed, failed])
	get_tree().quit()


# One wide orthographic shot over the station, with the camera rig parked.
func capture():
	if DisplayServer.get_name() == "headless":
		return  # the dummy rasteriser never resolves frame_post_draw
	# The rig registers itself, so the shot never has to know where it hangs.
	var rig: CameraFollow = Globals.camera_follow
	var camera: Camera3D = rig.camera
	rig.set_process(false)
	rig.set_physics_process(false)
	rig.global_position = Vector3(0, 0, 14)
	camera.size = 90.0
	camera.far = 300.0
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://world_probe.png")
	print("DBG capture saved")


func surface_at(p_world: World3D, p_position: Vector3, p_expected: String,
		p_label: String):
	var hit: Dictionary = raycast(p_world, p_position)
	var tag: String = ""
	if hit.has("collider"):
		tag = str(hit.collider.get_meta("surface", ""))
	check(tag == p_expected, "%s reports %s" % [p_label, p_expected],
			"got \"%s\" off %s at y=%.3f" % [tag,
			hit.collider.name if hit.has("collider") else "nothing",
			hit.position.y if hit.has("position") else 0.0])


func raycast(p_world: World3D, p_position: Vector3) -> Dictionary:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			p_position + Vector3.UP * 5.0, p_position + Vector3.DOWN * 5.0, 16)
	return p_world.direct_space_state.intersect_ray(query)


func check(p_ok: bool, p_label: String, p_detail: String):
	if p_ok:
		passed += 1
	else:
		failed += 1
	print("DBG %s %s: %s" % ["PASS" if p_ok else "FAIL", p_label, p_detail])
