extends Node3D

const ARENA_HALF: float = 180.0
const ROCKS: int = 40
const TREES: int = 25
const CLEAR_RADIUS: float = 15.0
const RESTART_DELAY: float = 3.0

@export var rock_scene: PackedScene
@export var tree_scene: PackedScene
@export var scatter_seed: int = 7

var over: bool = false

@onready var truck: Vehicle = %Truck
@onready var player: Character = %Player
@onready var spawner: RaiderSpawner = %RaiderSpawner
@onready var status: Label = %Status
@onready var scenery: Node3D = $Scenery


func _ready():
	scatter()
	truck.add_to_group("loot_magnet")
	Signals.player_died.connect(on_player_died)
	await get_tree().physics_frame
	await get_tree().physics_frame
	truck.add_driver(player)


func _process(_p_delta: float):
	if over:
		return
	status.text = "KILLS %d     LOOT %d stacks     TRUCK %d / %d     H restarts" % [
			spawner.kills, truck.storage.entries.size(), truck.health,
			truck.data.health_max_value if truck.data else 0]


func scatter():
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = scatter_seed
	for i in ROCKS:
		place(rock_scene, rng)
	for i in TREES:
		place(tree_scene, rng)


func place(p_scene: PackedScene, p_rng: RandomNumberGenerator):
	if p_scene == null:
		return
	var spot: Vector3 = Vector3(p_rng.randf_range(-ARENA_HALF, ARENA_HALF), 0.0,
			p_rng.randf_range(-ARENA_HALF, ARENA_HALF))
	if Vector2(spot.x, spot.z).length() < CLEAR_RADIUS:
		return
	var prop: Node3D = p_scene.instantiate()
	scenery.add_child(prop)
	prop.global_position = spot
	prop.rotation.y = p_rng.randf_range(0.0, TAU)


func on_player_died():
	over = true
	status.text = "THE RIDE IS OVER     restarting"
	await get_tree().create_timer(RESTART_DELAY).timeout
	get_tree().reload_current_scene()


func _input(p_event: InputEvent):
	if p_event is InputEventKey and p_event.pressed and p_event.keycode == KEY_H:
		get_tree().reload_current_scene()
