class_name GrassField
extends Node3D

const GROUND_MASK: int = 20  # walls|ground - the terrain carries both
const SOLID_MASK: int = 4  # walls alone - what STANDS UP out of the ground
const NO_GRASS: StringName = &"no_grass"  # props with no collider to be found by
const SCAN_STEP: float = 1.0  # s between looks for new or demolished pockets
const REBUILD_STEP: float = 0.1  # s between writes while a patch is moving
const SETTLED: float = 0.01  # growth delta below which a patch is done
const RIM_SCALE: float = 0.7  # tufts at the edge of the pocket, against the middle

@export var density: float = 0.45  # tufts per m2 of pocket at full chill
@export var max_tufts: int = 300  # per pocket
@export var inner_radius: float = 1.0  # m kept clear of the prop itself
@export var clearance: float = 0.8  # m of room a tuft needs from anything solid
@export var falloff: float = 1.4  # >0.5 crowds the damp middle; 0.5 spreads even
@export var growth_rate: float = 0.25  # scale per second toward the chill
@export var tuft_scale: Vector2 = Vector2(0.7, 1.4)
@export var surfaces: Array[String] = ["sand"]  # what a tuft will root in
@export var sway: ShaderMaterial  # the tufts' shared material, fed the weather

var patches: Array[Dictionary] = []  # {source, points, scales, growth}
var meshes: Array[MultiMeshInstance3D] = []
var ball: SphereShape3D = SphereShape3D.new()
var wind_path: Vector2 = Vector2.ZERO  # metres the air has travelled, as the sand counts it
var pending: Array[Dictionary] = []  # {position, frame} - drained a frame later
var scan_timer: float = 0.0
var rebuild_timer: float = 0.0


func _ready():
	ball.radius = clearance
	Signals.structure_changed.connect(on_structure_changed)
	for child in get_children():
		if child is MultiMeshInstance3D:
			meshes.append(child)


func on_structure_changed(p_position: Vector3):
	pending.append({"position": p_position, "frame": Engine.get_process_frames()})


# A FRAME must pass first, not merely a call: a demolished building keeps its
# collider until the free lands at the end of the frame, and draining early
# fences off the ground it just left.
func drain_pending():
	var due: Array[Vector3] = []
	for i in range(pending.size() - 1, -1, -1):
		if pending[i].frame < Engine.get_process_frames():
			due.append(pending[i].position)
			pending.remove_at(i)
	if not due.is_empty():
		refresh_around(due)


func _process(p_delta: float):
	blow(p_delta)
	if not pending.is_empty():
		drain_pending()
	scan_timer -= p_delta
	if scan_timer <= 0.0:
		scan_timer = SCAN_STEP
		claim_pockets()
	var moving: bool = false
	for patch in patches:
		# Validity checked HERE, not in chill_of: its typed Node parameter
		# rejects a freed source at the call boundary with a script error,
		# before any is_instance_valid inside could answer. A faded barrel
		# frees itself mid-second; the patch reads 0 until the next scan prunes it.
		var pocket: float = chill_of(patch.source) \
				if is_instance_valid(patch.source) else 0.0
		# EVERY TUFT EASES ALONE: a blocked one heads for zero while its
		# neighbours stand, so a barrel set down mid-patch fades the grass
		# under it instead of re-rolling the patch - the pop the per-patch
		# growth could never avoid.
		for i in patch.grown.size():
			var target: float = pocket if patch.alive[i] else 0.0
			if absf(patch.grown[i] - target) > SETTLED:
				patch.grown[i] = move_toward(patch.grown[i], target,
						growth_rate * p_delta)
				moving = true
	if not moving:
		return
	rebuild_timer -= p_delta
	if rebuild_timer <= 0.0:
		rebuild_timer = REBUILD_STEP
		rebuild()


# The tufts lean on the air's TRAVEL, never on TIME - the same accumulation
# the sand ripples ride, so a gust speeds the sway instead of jumping its phase.
func blow(p_delta: float):
	if sway == null or Globals.wind == null:
		return
	var direction: Vector2 = Vector2(Globals.wind.direction.x, Globals.wind.direction.z)
	if direction.length() > 0.01:
		wind_path += direction.normalized() * Globals.wind.strength * p_delta
	sway.set_shader_parameter("wind_direction", direction)
	sway.set_shader_parameter("wind_strength", Globals.wind.strength)
	sway.set_shader_parameter("wind_path", wind_path)


# Scanned rather than registered: a barrel can be BUILT mid-game, and a
# demolished one has to take its patch with it.
func claim_pockets():
	var changed: bool = false
	for i in range(patches.size() - 1, -1, -1):
		if not is_instance_valid(patches[i].source):
			patches.remove_at(i)
			changed = true
	for source in get_tree().get_nodes_in_group("chill_source"):
		if not source.has_method("chill_radius"):
			continue
		var index: int = patch_index(source)
		if index == -1:
			patches.append(sow(source))
			changed = true
		elif patches[index].origin.distance_to(source.global_position) > 0.5:
			# Sown around where the pocket STOOD: one that moves leaves its
			# grass behind unless it is sown again. A moved source's layout is
			# a different roll, so its grown starts over - gameplay never
			# moves a source any more (the carry fades one node and places
			# another); only probes drag them about.
			patches[index] = sow(source)
			changed = true
	if changed:
		rebuild()


# Any pocket the change stands in re-judges its CLEARANCE, nothing more: the
# layout never re-rolls (it is deterministic anyway), each tuft's alive flag
# flips, and the easing carries every flip to the eye slowly - a new building
# FADES the grass under it out, and pulling it down grows the same tufts back.
func refresh_around(p_positions: Array):
	for patch in patches:
		if not is_instance_valid(patch.source):
			continue
		var reach: float = patch.source.chill_radius() + clearance
		for pos in p_positions:
			if Vector2(pos.x - patch.origin.x,
					pos.z - patch.origin.z).length() > reach:
				continue
			refresh_alive(patch)
			break


func refresh_alive(p_patch: Dictionary):
	for i in p_patch.points.size():
		p_patch.alive[i] = clear_of_props(p_patch.points[i])


func patch_index(p_source: Node) -> int:
	for i in patches.size():
		if patches[i].source == p_source:
			return i
	return -1


# Rolled ONCE from a seed made of the pocket's own position, so a patch never
# reshuffles under the player as it thickens.
func sow(p_source: Node3D) -> Dictionary:
	var radius: float = p_source.chill_radius()
	var count: int = mini(int(PI * radius * radius * density), max_tufts)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(roundi(p_source.global_position.x * 10.0),
			roundi(p_source.global_position.z * 10.0)))
	var points: PackedVector3Array = PackedVector3Array()
	var scales: PackedFloat32Array = PackedFloat32Array()
	var alive: Array = []
	var grown: Array = []
	var variant: Array = []
	var kinds: int = maxi(meshes.size(), 1)
	for i in count:
		# The wet is deepest at the source, so the tufts crowd it and thin out
		# toward the rim. Every candidate draws ALL its randomness up front so
		# the sequence never depends on what stands nearby; ground that will
		# never take grass (tarmac, the void) is dropped for good, but a spot
		# merely CROWDED right now is kept as a dead tuft - clearance is a
		# fade target that flips with the furniture, not a fact of the land.
		var reach: float = pow(rng.randf(), falloff)
		var angle: float = rng.randf() * TAU
		var size: float = rng.randf_range(tuft_scale.x, tuft_scale.y) \
				* lerpf(1.0, RIM_SCALE, reach)
		var spot: Vector3 = p_source.global_position \
				+ Vector3(cos(angle), 0.0, sin(angle)) \
				* lerpf(inner_radius, radius, reach)
		var ground: Vector3 = ground_under(spot)
		if ground == Vector3.INF:
			continue
		points.append(ground)
		scales.append(size)
		alive.append(clear_of_props(ground))
		grown.append(0.0)
		# The variant is the TUFT'S OWN, fixed at sow - dealt at render time it
		# followed the draw order, and one tuft crossing the cull re-dealt
		# every tuft after it into a different mesh: a field-wide reshuffle
		# from a single blade fading.
		variant.append(i % kinds)
	return {"source": p_source, "origin": p_source.global_position,
			"points": points, "scales": scales, "alive": alive, "grown": grown,
			"variant": variant}


# Grass roots in listed ground only, so the tarmac (its own body, `cement`,
# laid proud of the sand) and anything a ray lands on top of - a crate, a
# building, the barrel itself - grow nothing. Untagged means no.
func ground_under(p_spot: Vector3) -> Vector3:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			p_spot + Vector3.UP * 4.0, p_spot + Vector3.DOWN * 8.0, GROUND_MASK)
	var hit: Dictionary = space.intersect_ray(query)
	if not hit or not hit.collider.has_meta("surface"):
		return Vector3.INF
	if not surfaces.has(String(hit.collider.get_meta("surface"))):
		return Vector3.INF
	return hit.position


func clear_of_props(p_ground: Vector3) -> bool:
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = ball
	query.collision_mask = SOLID_MASK
	query.transform = Transform3D(Basis.IDENTITY,
			p_ground + Vector3.UP * (clearance + 0.05))
	if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
		return false
	for node in get_tree().get_nodes_in_group(NO_GRASS):
		if Vector2(node.global_position.x - p_ground.x,
				node.global_position.z - p_ground.z).length() < clearance:
			return false
	return true


func chill_of(p_source: Node) -> float:
	if not is_instance_valid(p_source) or not p_source.has_method("chill_strength"):
		return 0.0
	return clampf(p_source.chill_strength(), 0.0, 1.0)


# Tufts go round robin into the authored variant multimeshes, so a patch is a
# mix rather than a field of clones.
func rebuild():
	if meshes.is_empty():
		return
	var buckets: Array[Array] = []
	for i in meshes.size():
		buckets.append([])
	for patch in patches:
		for i in patch.points.size():
			var current_scale: float = patch.scales[i] * patch.grown[i]
			if current_scale <= 0.01:
				continue
			# current_scale, NOT the node's own scale - the instance scale IS
			# the growth the shader reads, and the bare `scale` here silently
			# rendered every tuft full-size since the field first grew.
			buckets[patch.variant[i] % meshes.size()].append(Transform3D(
					Basis.IDENTITY.scaled(Vector3.ONE * current_scale),
					patch.points[i]))
	for i in meshes.size():
		var multi: MultiMesh = meshes[i].multimesh
		multi.instance_count = buckets[i].size()
		for j in buckets[i].size():
			multi.set_instance_transform(j, buckets[i][j])
