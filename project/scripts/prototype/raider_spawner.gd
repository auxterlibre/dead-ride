class_name RaiderSpawner
extends Node3D

signal killed(character)

const ARENA_HALF: float = 175.0
const SPREAD: float = 4.0
const HEADING_CONE: float = 70.0

@export var enemy_scene: PackedScene
@export var loot_scene: PackedScene
@export var raider_data: Array[CharacterData] = []
@export var truck: Vehicle
@export var max_alive: int = 8
@export var group_size: Vector2i = Vector2i(2, 4)
@export var spawn_distance: Vector2 = Vector2(35.0, 50.0)
@export var spawn_interval: float = 4.0
@export var corpse_time: float = 25.0
@export var horde: Horde
@export var zombie_pack: Vector2i = Vector2i(18, 30)
@export var zombies_max: int = 350
@export var zombie_distance: Vector2 = Vector2(38.0, 58.0)
@export var zombie_interval: float = 5.0

var alive: Array[Character] = []
var timer: float = 1.0
var kills: int = 0
var zombie_timer: float = 2.0


func _physics_process(p_delta: float):
	alive = alive.filter(func(p_raider): return is_instance_valid(p_raider) and not p_raider.is_dead)
	spawn_zombies(p_delta)
	timer -= p_delta
	if timer > 0.0 or alive.size() >= max_alive or truck == null:
		return
	herd()
	timer = spawn_interval
	spawn_group()


func spawn_zombies(p_delta: float):
	if horde == null or truck == null:
		return
	zombie_timer -= p_delta
	if zombie_timer > 0.0 or horde.alive_count >= zombies_max:
		return
	zombie_timer = zombie_interval
	var centre: Vector3 = truck.global_position + heading().rotated(Vector3.UP,
			deg_to_rad(randf_range(-HEADING_CONE, HEADING_CONE))) \
			* randf_range(zombie_distance.x, zombie_distance.y)
	horde.spawn_pack(clamped(centre), randi_range(zombie_pack.x, zombie_pack.y), 6.0)


func heading() -> Vector3:
	var forward: Vector3 = truck.global_basis.z
	forward.y = 0.0
	return forward.normalized() if forward.length_squared() > 0.01 else Vector3.FORWARD


func spawn_group():
	var heading: Vector3 = truck.global_basis.z
	heading.y = 0.0
	if heading.length_squared() < 0.01:
		heading = Vector3.FORWARD
	var direction: Vector3 = heading.normalized().rotated(Vector3.UP,
			deg_to_rad(randf_range(-HEADING_CONE, HEADING_CONE)))
	var centre: Vector3 = truck.global_position \
			+ direction * randf_range(spawn_distance.x, spawn_distance.y)
	var count: int = randi_range(group_size.x, group_size.y)
	for i in count:
		if alive.size() >= max_alive:
			return
		var offset: Vector3 = Vector3(randf_range(-SPREAD, SPREAD), 0.0,
				randf_range(-SPREAD, SPREAD))
		spawn_raider(clamped(centre + offset))


func clamped(p_spot: Vector3) -> Vector3:
	return Vector3(clampf(p_spot.x, -ARENA_HALF, ARENA_HALF), 0.0,
			clampf(p_spot.z, -ARENA_HALF, ARENA_HALF))


func spawn_raider(p_spot: Vector3):
	var raider: Character = enemy_scene.instantiate()
	if not raider_data.is_empty():
		raider.data = raider_data.pick_random()
	raider.position = to_local(p_spot)
	raider.rotation.y = randf_range(0.0, TAU)
	add_child(raider)
	for child in raider.get_children():
		if child is CharacterVision:
			child.alertness = 1.0
		elif child is EnemyAI:
			hunt(child)
	raider.died.connect(on_died.bind(raider))
	alive.append(raider)


func herd():
	for raider in alive:
		for child in raider.get_children():
			if child is EnemyAI:
				hunt(child)


func hunt(p_brain: EnemyAI):
	if p_brain.vision.target != null:
		return
	var machine: StateMachine = p_brain.state_machine
	if machine.current_state_name == "chase":
		machine.states["chase"].redirect(truck.global_position)
	elif machine.current_state_name != "attack" and machine.current_state_name != "cover":
		machine.change_state_to("chase", {return_state = "guard", last_seen = truck.global_position})


func on_died(p_raider: Character):
	kills += 1
	killed.emit(p_raider)
	drop_loot(p_raider)
	get_tree().create_timer(corpse_time).timeout.connect(reap.bind(p_raider))


func drop_loot(p_raider: Character):
	if loot_scene == null:
		return
	for child in p_raider.get_children():
		if not child is EnemyLoot:
			continue
		var loot: EnemyLoot = child
		if loot.storage == null or loot.storage.entries.is_empty():
			return
		var drop: LootDrop = loot_scene.instantiate()
		drop.storage = loot.storage
		loot.offer.enabled = false
		add_child(drop)
		drop.global_position = p_raider.global_position
		return


func reap(p_raider: Character):
	if is_instance_valid(p_raider):
		p_raider.queue_free()
