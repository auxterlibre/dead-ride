class_name LootDrop
extends Node3D

const MAGNET_RANGE: float = 8.0
const PICKUP_RANGE: float = 2.0
const PULL_SPEED: float = 16.0
const BOB: float = 0.12
const SPIN: float = 2.0
const RETRY_TIME: float = 2.0

var storage: Inventory
var age: float = 0.0
var retry: float = 0.0

@onready var mesh: Node3D = $Mesh


func _physics_process(p_delta: float):
	age += p_delta
	mesh.position.y = 0.4 + sin(age * 3.0) * BOB
	mesh.rotation.y += SPIN * p_delta
	retry = maxf(retry - p_delta, 0.0)
	var truck: Node3D = nearest_magnet()
	if truck == null or storage == null:
		return
	var gap: Vector3 = truck.global_position - global_position
	gap.y = 0.0
	var distance: float = gap.length()
	if distance > MAGNET_RANGE:
		return
	if distance > PICKUP_RANGE:
		global_position += gap.normalized() * minf(PULL_SPEED * p_delta, distance)
		return
	if retry == 0.0:
		deposit(truck)


func nearest_magnet() -> Node3D:
	var best: Node3D = null
	var best_distance: float = INF
	for node in get_tree().get_nodes_in_group("loot_magnet"):
		var distance: float = global_position.distance_to(node.global_position)
		if distance < best_distance:
			best = node
			best_distance = distance
	return best


func deposit(p_truck: Node3D):
	var trunk: Inventory = p_truck.get("storage")
	if trunk == null:
		return
	var taken: PackedStringArray = []
	for entry in storage.entries.duplicate():
		var left: int = trunk.add(entry.item, entry.count)
		var moved: int = entry.count - left
		if moved > 0:
			taken.append(label(entry.item, moved))
		if left == 0:
			storage.remove(entry)
		else:
			entry.count = left
	if not taken.is_empty():
		Signals.notification_requested.emit("LOOTED %s" % ", ".join(taken),
				Enums.MessageType.POSITIVE)
	if storage.entries.is_empty():
		queue_free()
	else:
		retry = RETRY_TIME


func label(p_item: ItemData, p_count: int) -> String:
	var name: String = p_item.name.to_upper()
	return "%d %s" % [p_count, name] if p_count > 1 else name
