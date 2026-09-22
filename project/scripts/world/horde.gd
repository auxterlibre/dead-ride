class_name Horde
extends Node3D

signal zombie_killed(position: Vector3)

enum State {FREE, IDLE, CHASE, ATTACK, FLUNG, DYING, DEAD}

const CELL: float = 2.0
const SEPARATION: float = 0.9
const SEPARATION_PUSH: float = 2.5
const NEIGHBOURS_MAX: int = 10
const AGGRO_RANGE: float = 45.0
const REACH_VEHICLE: float = 3.2
const REACH_CHARACTER: float = 1.3
const REACH_SLACK: float = 0.6
const RAM_MIN_SPEED: float = 3.0
const RAM_LIFT: float = 4.5
const RAM_SHOVE: float = 0.6
const CORPSE_TIME: float = 12.0
const VIEW_RADIUS: float = 42.0
const TURN_RATE: float = 6.0
const GRAVITY: float = 14.0
const BODY_RADIUS: float = 0.45
const BODY_HEIGHT: float = 1.7
const FLASH_FADE: float = 4.0
const HIT_SHOVE: float = 0.25
const FLOATS_PER_INSTANCE: int = 16
const WALK_CLIP: String = "shuffling"
const RUN_CLIP: String = "run_forward"
const IDLE_CLIP: String = "idle"
const ATTACK_CLIP: String = "attack_hand"
const DEATH_CLIP: String = "death_backward"
const ATTACK_HIT_SHARE: float = 0.45

static var instances: Array[Horde] = []

@export var animation_set: HordeAnimationSet
@export var variants: Array[Mesh] = []
@export var capacity: int = 600
@export var walk_speed: Vector2 = Vector2(1.1, 1.7)
@export var run_speed: Vector2 = Vector2(3.4, 4.6)
@export var runner_share: float = 0.3
@export var health_max: int = 30
@export var bite_damage: int = 5
@export var hull_half_extents: Vector3 = Vector3(1.3, 1.6, 2.7)
@export var ground_y: float = 0.0
@export var target_node: Node3D

var positions: PackedVector3Array = PackedVector3Array()
var yaws: PackedFloat32Array = PackedFloat32Array()
var speeds: PackedFloat32Array = PackedFloat32Array()
var healths: PackedInt32Array = PackedInt32Array()
var states: PackedInt32Array = PackedInt32Array()
var clip_starts: PackedInt32Array = PackedInt32Array()
var clip_lengths: PackedInt32Array = PackedInt32Array()
var clip_loops: PackedByteArray = PackedByteArray()
var phases: PackedFloat32Array = PackedFloat32Array()
var variant_of: PackedInt32Array = PackedInt32Array()
var timers: PackedFloat32Array = PackedFloat32Array()
var flashes: PackedFloat32Array = PackedFloat32Array()
var flings: PackedVector3Array = PackedVector3Array()
var generations: PackedInt32Array = PackedInt32Array()
var struck: PackedByteArray = PackedByteArray()
var free_slots: PackedInt32Array = PackedInt32Array()
var alive_count: int = 0
var kills: int = 0
var last_tick_usec: int = 0
var grid: Dictionary = {}
var meshes: Array[MultiMeshInstance3D] = []
var buffers: Array[PackedFloat32Array] = []
var counts: PackedInt32Array = PackedInt32Array()
var separation_scratch: PackedInt32Array = PackedInt32Array()


func _ready():
	instances.append(self)
	positions.resize(capacity)
	yaws.resize(capacity)
	speeds.resize(capacity)
	healths.resize(capacity)
	states.resize(capacity)
	clip_starts.resize(capacity)
	clip_lengths.resize(capacity)
	clip_loops.resize(capacity)
	phases.resize(capacity)
	variant_of.resize(capacity)
	timers.resize(capacity)
	flashes.resize(capacity)
	flings.resize(capacity)
	generations.resize(capacity)
	struck.resize(capacity)
	for i in range(capacity - 1, -1, -1):
		free_slots.append(i)
	counts.resize(variants.size())
	var bones: ImageTexture = animation_set.texture() if animation_set else null
	for v in variants.size():
		var multimesh: MultiMesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_custom_data = true
		multimesh.mesh = variants[v]
		multimesh.instance_count = capacity
		multimesh.visible_instance_count = 0
		multimesh.custom_aabb = AABB(Vector3(-2000.0, -20.0, -2000.0), Vector3(4000.0, 60.0, 4000.0))
		var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
		instance.name = "Variant%d" % v
		instance.multimesh = multimesh
		instance.top_level = true
		add_child(instance)
		meshes.append(instance)
		var buffer: PackedFloat32Array = PackedFloat32Array()
		buffer.resize(capacity * FLOATS_PER_INSTANCE)
		buffers.append(buffer)
		var material: ShaderMaterial = variants[v].surface_get_material(0) as ShaderMaterial
		if material and bones:
			material.set_shader_parameter("bones", bones)


func _exit_tree():
	instances.erase(self)


func _physics_process(p_delta: float):
	var started: int = Time.get_ticks_usec()
	var target: Node3D = hunt_target()
	rebuild_grid()
	for i in capacity:
		if states[i] != State.FREE:
			step(i, p_delta, target)
	render()
	last_tick_usec = Time.get_ticks_usec() - started


func hunt_target() -> Node3D:
	if target_node != null and is_instance_valid(target_node):
		return target_node
	var player: Node = InputManager.player
	if player == null or not is_instance_valid(player):
		return null
	var seat: Node = player.get_parent()
	return seat if seat is Vehicle else player


func spawn(p_position: Vector3) -> int:
	if free_slots.is_empty():
		return -1
	var i: int = free_slots[free_slots.size() - 1]
	free_slots.resize(free_slots.size() - 1)
	positions[i] = Vector3(p_position.x, ground_y, p_position.z)
	yaws[i] = randf_range(0.0, TAU)
	var runner: bool = randf() < runner_share
	speeds[i] = randf_range(run_speed.x, run_speed.y) if runner \
			else randf_range(walk_speed.x, walk_speed.y)
	healths[i] = health_max
	variant_of[i] = randi() % maxi(variants.size(), 1)
	flashes[i] = 0.0
	timers[i] = 0.0
	struck[i] = 0
	states[i] = State.IDLE
	play(i, IDLE_CLIP, randf())
	alive_count += 1
	return i


func spawn_pack(p_centre: Vector3, p_count: int, p_radius: float) -> int:
	var spawned: int = 0
	for n in p_count:
		var offset: Vector3 = Vector3(randf_range(-p_radius, p_radius), 0.0, randf_range(-p_radius, p_radius))
		if spawn(p_centre + offset) >= 0:
			spawned += 1
	return spawned


func play(p_index: int, p_clip: String, p_phase_share: float = 0.0):
	var frames: int = animation_set.clip_frames(p_clip) if animation_set else 1
	clip_starts[p_index] = animation_set.clip_start(p_clip) if animation_set else 0
	clip_lengths[p_index] = frames
	clip_loops[p_index] = 1 if (animation_set == null or animation_set.clip_loops(p_clip)) else 0
	phases[p_index] = p_phase_share * clip_seconds(p_index)


func clip_seconds(p_index: int) -> float:
	var fps: float = animation_set.fps if animation_set else 30.0
	return clip_lengths[p_index] / fps


func step(p_index: int, p_delta: float, p_target: Node3D):
	flashes[p_index] = maxf(flashes[p_index] - p_delta * FLASH_FADE, 0.0)
	phases[p_index] += p_delta
	match states[p_index]:
		State.DYING:
			if phases[p_index] >= clip_seconds(p_index):
				states[p_index] = State.DEAD
				timers[p_index] = CORPSE_TIME
		State.DEAD:
			timers[p_index] -= p_delta
			if timers[p_index] <= 0.0:
				release(p_index)
		State.FLUNG:
			var velocity: Vector3 = flings[p_index]
			velocity.y -= GRAVITY * p_delta
			flings[p_index] = velocity
			positions[p_index] += velocity * p_delta
			yaws[p_index] += p_delta * 5.0
			if positions[p_index].y <= ground_y:
				positions[p_index].y = ground_y
				die(p_index)
		_:
			hunt(p_index, p_delta, p_target)


func hunt(p_index: int, p_delta: float, p_target: Node3D):
	if p_target == null:
		settle(p_index, State.IDLE, IDLE_CLIP)
		return
	var position: Vector3 = positions[p_index]
	var to_target: Vector3 = p_target.global_position - position
	to_target.y = 0.0
	var distance: float = to_target.length()
	if distance > AGGRO_RANGE:
		settle(p_index, State.IDLE, IDLE_CLIP)
		return
	if rammed(p_index, p_target):
		return
	var reach: float = REACH_VEHICLE if p_target is Vehicle else REACH_CHARACTER
	var slack: float = REACH_SLACK if states[p_index] == State.ATTACK else 0.0
	if distance <= reach + slack:
		attack(p_index, p_delta, p_target, to_target)
		return
	var runner: bool = speeds[p_index] > walk_speed.y
	settle(p_index, State.CHASE, RUN_CLIP if runner else WALK_CLIP)
	var desired: Vector3 = to_target / maxf(distance, 0.001) + separation(p_index)
	desired.y = 0.0
	if desired.length_squared() < 0.0001:
		return
	var wanted_yaw: float = atan2(desired.x, desired.z)
	yaws[p_index] = lerp_angle(yaws[p_index], wanted_yaw, minf(TURN_RATE * p_delta, 1.0))
	var heading: Vector3 = Vector3(sin(yaws[p_index]), 0.0, cos(yaws[p_index]))
	positions[p_index] = position + heading * speeds[p_index] * p_delta


func settle(p_index: int, p_state: int, p_clip: String):
	if states[p_index] == p_state:
		return
	states[p_index] = p_state
	play(p_index, p_clip, randf() if p_state != State.ATTACK else 0.0)


func attack(p_index: int, p_delta: float, p_target: Node3D, p_to_target: Vector3):
	if states[p_index] != State.ATTACK:
		states[p_index] = State.ATTACK
		play(p_index, ATTACK_CLIP, randf() * 0.3)
		struck[p_index] = 0
	yaws[p_index] = lerp_angle(yaws[p_index], atan2(p_to_target.x, p_to_target.z),
			minf(TURN_RATE * p_delta, 1.0))
	var length: float = clip_seconds(p_index)
	if phases[p_index] >= length:
		phases[p_index] -= length
		struck[p_index] = 0
	if struck[p_index] == 0 and phases[p_index] >= length * ATTACK_HIT_SHARE:
		struck[p_index] = 1
		bite(p_index, p_target)


func bite(p_index: int, p_target: Node3D):
	var attack_data: AttackData = AttackData.new(bite_damage, positions[p_index], 0.0, self)
	var hurt_box = p_target.get("hurt_box")
	if hurt_box != null:
		hurt_box.hit(attack_data)
	elif p_target.has_method("take_damage"):
		p_target.take_damage(attack_data)


func rammed(p_index: int, p_target: Node3D) -> bool:
	if not p_target is Vehicle or p_target.speed < RAM_MIN_SPEED:
		return false
	var local: Vector3 = p_target.to_local(positions[p_index])
	if absf(local.x) > hull_half_extents.x or absf(local.z) > hull_half_extents.z \
			or absf(local.y) > hull_half_extents.y:
		return false
	var away: Vector3 = positions[p_index] - p_target.global_position
	away.y = 0.0
	var velocity: Vector3 = p_target.linear_velocity * RAM_SHOVE + away.normalized() * 2.0
	velocity.y = RAM_LIFT
	flings[p_index] = velocity
	states[p_index] = State.FLUNG
	healths[p_index] = 0
	flashes[p_index] = 1.0
	kills += 1
	zombie_killed.emit(positions[p_index])
	return true


func separation(p_index: int) -> Vector3:
	var push: Vector3 = Vector3.ZERO
	var position: Vector3 = positions[p_index]
	var cell: Vector2i = cell_of(position)
	var checked: int = 0
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var bucket: PackedInt32Array = grid.get(Vector2i(cell.x + dx, cell.y + dz), PackedInt32Array())
			for j in bucket:
				if j == p_index:
					continue
				var gap: Vector3 = position - positions[j]
				gap.y = 0.0
				var length: float = gap.length()
				if length < SEPARATION and length > 0.001:
					push += gap / length * (1.0 - length / SEPARATION) * SEPARATION_PUSH
				checked += 1
				if checked >= NEIGHBOURS_MAX:
					return push
	return push


func rebuild_grid():
	grid.clear()
	for i in capacity:
		var state: int = states[i]
		if state == State.FREE or state == State.DEAD or state == State.FLUNG:
			continue
		var cell: Vector2i = cell_of(positions[i])
		if not grid.has(cell):
			grid[cell] = PackedInt32Array()
		grid[cell].append(i)


func cell_of(p_position: Vector3) -> Vector2i:
	return Vector2i(floori(p_position.x / CELL), floori(p_position.z / CELL))


func damage(p_index: int, p_attack: AttackData, p_direction: Vector3 = Vector3.ZERO):
	if not is_alive(p_index):
		return
	healths[p_index] -= p_attack.damage
	flashes[p_index] = 1.0
	if p_direction.length_squared() > 0.0:
		var shove: Vector3 = p_direction.normalized() * HIT_SHOVE
		shove.y = 0.0
		positions[p_index] += shove
	if healths[p_index] <= 0:
		kills += 1
		zombie_killed.emit(positions[p_index])
		die(p_index)


func die(p_index: int):
	states[p_index] = State.DYING
	play(p_index, DEATH_CLIP)


func release(p_index: int):
	states[p_index] = State.FREE
	generations[p_index] += 1
	alive_count -= 1
	free_slots.append(p_index)


func is_alive(p_index: int) -> bool:
	if p_index < 0 or p_index >= capacity:
		return false
	var state: int = states[p_index]
	return state != State.FREE and state != State.DYING and state != State.DEAD and state != State.FLUNG


func position_of(p_index: int) -> Vector3:
	return positions[p_index]


func generation_of(p_index: int) -> int:
	return generations[p_index]


func nearest(p_from: Vector3, p_reach: float) -> HordeTarget:
	var best: int = -1
	var best_distance: float = p_reach
	for i in capacity:
		if not is_alive(i):
			continue
		var distance: float = p_from.distance_to(positions[i])
		if distance < best_distance:
			best = i
			best_distance = distance
	return HordeTarget.new(self, best) if best >= 0 else null


func intersect_ray(p_from: Vector3, p_to: Vector3) -> Dictionary:
	var line: Vector3 = p_to - p_from
	line.y = 0.0
	var length: float = line.length()
	if length < 0.001:
		return {}
	var direction: Vector3 = line / length
	var best: int = -1
	var best_t: float = INF
	for i in capacity:
		if not is_alive(i):
			continue
		var position: Vector3 = positions[i]
		if p_from.y < position.y or p_from.y > position.y + BODY_HEIGHT:
			continue
		var offset: Vector3 = position - p_from
		offset.y = 0.0
		var t: float = offset.dot(direction)
		if t < 0.0 or t > length or t >= best_t:
			continue
		var side: float = (offset - direction * t).length()
		if side <= BODY_RADIUS:
			best = i
			best_t = t
	if best < 0:
		return {}
	return {"index": best, "distance": best_t,
			"position": Vector3(p_from.x, p_from.y, p_from.z) + direction * best_t,
			"floor_y": positions[best].y}


static func hit_test(p_from: Vector3, p_to: Vector3) -> Dictionary:
	var best: Dictionary = {}
	for horde in instances:
		var hit: Dictionary = horde.intersect_ray(p_from, p_to)
		if hit.is_empty():
			continue
		if best.is_empty() or hit.distance < best.distance:
			hit["horde"] = horde
			best = hit
	return best


static func nearest_any(p_from: Vector3, p_reach: float) -> HordeTarget:
	var best: HordeTarget = null
	var best_distance: float = p_reach
	for horde in instances:
		var found: HordeTarget = horde.nearest(p_from, best_distance)
		if found != null:
			best = found
			best_distance = p_from.distance_to(found.global_position)
	return best


func render():
	var centre: Vector3 = global_position
	if Globals.camera_follow != null:
		centre = Globals.camera_follow.global_position
	elif target_node != null:
		centre = target_node.global_position
	for v in counts.size():
		counts[v] = 0
	var fps: float = animation_set.fps if animation_set else 30.0
	var radius_squared: float = VIEW_RADIUS * VIEW_RADIUS
	for i in capacity:
		if states[i] == State.FREE:
			continue
		var position: Vector3 = positions[i]
		var flat: Vector3 = position - centre
		flat.y = 0.0
		if flat.length_squared() > radius_squared:
			continue
		var v: int = variant_of[i]
		var slot: int = counts[v]
		counts[v] = slot + 1
		var basis: Basis = Basis(Vector3.UP, yaws[i])
		if states[i] == State.FLUNG:
			basis = basis * Basis(Vector3.RIGHT, phases[i] * 4.0)
		var frame: int = frame_of(i, fps)
		var buffer: PackedFloat32Array = buffers[v]
		var at: int = slot * FLOATS_PER_INSTANCE
		buffer[at] = basis.x.x
		buffer[at + 1] = basis.y.x
		buffer[at + 2] = basis.z.x
		buffer[at + 3] = position.x
		buffer[at + 4] = basis.x.y
		buffer[at + 5] = basis.y.y
		buffer[at + 6] = basis.z.y
		buffer[at + 7] = position.y
		buffer[at + 8] = basis.x.z
		buffer[at + 9] = basis.y.z
		buffer[at + 10] = basis.z.z
		buffer[at + 11] = position.z
		buffer[at + 12] = float(frame)
		buffer[at + 13] = flashes[i]
		buffer[at + 14] = 0.0
		buffer[at + 15] = 0.0
	for v in meshes.size():
		var multimesh: MultiMesh = meshes[v].multimesh
		multimesh.visible_instance_count = counts[v]
		if counts[v] > 0:
			multimesh.buffer = buffers[v]


func frame_of(p_index: int, p_fps: float) -> int:
	var frames: int = maxi(clip_lengths[p_index], 1)
	var frame: int = int(phases[p_index] * p_fps)
	if states[p_index] == State.DEAD:
		frame = frames - 1
	elif clip_loops[p_index] == 1:
		frame = frame % frames
	else:
		frame = mini(frame, frames - 1)
	return clip_starts[p_index] + frame
