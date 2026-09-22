@tool
class_name RoadNetwork
extends StaticBody3D
# Splines, not tiles: every Path3D child is a road. One AStar graph sampled off
# the curves carries the traffic, and the same samples extrude the ribbon that
# is drawn and driven on - so the graph can never disagree with what you see.

const SAMPLE_STEP: float = 3.0  # m between graph points along a curve
const JOIN_RADIUS: float = 3.0  # samples this close on DIFFERENT runs are one junction
const ENTRY_INSET: float = 6.0  # m in from an end, so a car sits wholly on tarmac

@export var road_width: float = 7.0
@export var lane_offset: float = 1.5  # metres right of the centreline; 0 = down the middle
@export var surface_height: float = 0.02  # proud of the ground, so rays tag the road
@export_tool_button("Rebuild road") var rebuild_action: Callable = build

@onready var surface: MeshInstance3D = $Surface
@onready var collision: CollisionShape3D = $CollisionShape3D

var astar: AStar3D = AStar3D.new()


func _ready():
	build()
	# Dragging a curve point in the editor re-lays the tarmac under it.
	for path in paths():
		if path.curve and not path.curve.changed.is_connected(build):
			path.curve.changed.connect(build)
	if not Engine.is_editor_hint():
		Globals.road_network = self


func build():
	if not is_node_ready():
		return
	var runs: Array = []
	for path in paths():
		var run: PackedVector3Array = sample(path)
		if run.size() >= 2:
			runs.append(run)
	build_graph(runs)
	build_surface(runs)


func paths() -> Array[Path3D]:
	var found: Array[Path3D] = []
	for child in get_children():
		if child is Path3D:
			found.append(child)
	return found


# Evenly spaced points down one curve, in this node's space. Their y is the
# curve's own - the surface the wheels ride, which is what a driver wants.
func sample(p_path: Path3D) -> PackedVector3Array:
	var points: PackedVector3Array = PackedVector3Array()
	if p_path.curve == null or p_path.curve.point_count < 2:
		return points
	var length: float = p_path.curve.get_baked_length()
	var steps: int = maxi(1, roundi(length / SAMPLE_STEP))
	for i in steps + 1:
		points.append(to_local(p_path.to_global(
				p_path.curve.sample_baked(length * i / float(steps)))))
	return points


func build_graph(p_runs: Array):
	astar.clear()
	var runs_ids: Array = []
	for run in p_runs:
		var ids: PackedInt64Array = PackedInt64Array()
		for point in run:
			var id: int = astar.get_available_point_id()
			astar.add_point(id, to_global(point))
			ids.append(id)
		for i in range(ids.size() - 1):
			astar.connect_points(ids[i], ids[i + 1])
		runs_ids.append(ids)
	# Junctions are wherever two runs land on top of each other - a spur that
	# starts and ends on the highway needs no markers of its own. Same-run
	# pairs are skipped: a radius as wide as the sampling would let a route hop
	# over its own waypoints and cut the bend they were sampled to follow.
	for a in range(runs_ids.size()):
		for b in range(a + 1, runs_ids.size()):
			for first in runs_ids[a]:
				for second in runs_ids[b]:
					if astar.get_point_position(first).distance_to(
							astar.get_point_position(second)) <= JOIN_RADIUS:
						astar.connect_points(first, second)


func build_surface(p_runs: Array):
	var faces: PackedVector3Array = PackedVector3Array()
	var builder: SurfaceTool = SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for run in p_runs:
		ribbon(builder, faces, run)
	surface.mesh = builder.commit()
	var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	collision.shape = shape


# One run extruded to road_width. The width is squared to the line THROUGH each
# sample (central difference), not to the segment arriving at it, so a bend
# keeps an even width instead of pinching on the inside - same trick SkidMark
# uses for tyre ribbons.
func ribbon(p_builder: SurfaceTool, p_faces: PackedVector3Array,
		p_run: PackedVector3Array):
	var half: float = road_width * 0.5
	var left: PackedVector3Array = PackedVector3Array()
	var right: PackedVector3Array = PackedVector3Array()
	var travelled: PackedFloat32Array = PackedFloat32Array()
	var distance: float = 0.0
	for i in p_run.size():
		var forward: Vector3 = p_run[mini(i + 1, p_run.size() - 1)] \
				- p_run[maxi(i - 1, 0)]
		forward.y = 0.0
		if forward.length_squared() < 0.0001:
			forward = Vector3.FORWARD
		var side: Vector3 = forward.normalized().cross(Vector3.UP) * half
		var centre: Vector3 = p_run[i] + Vector3.UP * surface_height
		left.append(centre - side)
		right.append(centre + side)
		if i > 0:
			distance += p_run[i].distance_to(p_run[i - 1])
		travelled.append(distance)
	# Wound so the TOP face is the front one. Godot flips the normal on a back
	# face, so getting this backwards lights the road as if it faced the dirt -
	# ambient only, which reads as black tarmac beside sunlit sand.
	for i in range(p_run.size() - 1):
		var near: float = travelled[i] / road_width
		var far: float = travelled[i + 1] / road_width
		add_face(p_builder, p_faces, [left[i + 1], right[i], left[i]],
				[Vector2(0.0, far), Vector2(1.0, near), Vector2(0.0, near)])
		add_face(p_builder, p_faces, [left[i + 1], right[i + 1], right[i]],
				[Vector2(0.0, far), Vector2(1.0, far), Vector2(1.0, near)])


func add_face(p_builder: SurfaceTool, p_faces: PackedVector3Array,
		p_points: Array, p_uvs: Array):
	for i in 3:
		p_builder.set_normal(Vector3.UP)
		p_builder.set_uv(p_uvs[i])
		p_builder.add_vertex(p_points[i])
		p_faces.append(p_points[i])


func route(p_from: Vector3, p_to: Vector3) -> PackedVector3Array:
	if astar.get_point_count() == 0:
		return PackedVector3Array()
	return keep_right(astar.get_point_path(astar.get_closest_point(p_from),
			astar.get_closest_point(p_to)))


# The graph runs down the centreline, so shifting right of the local heading
# keeps opposing traffic passing rather than meeting head-on.
func keep_right(p_path: PackedVector3Array) -> PackedVector3Array:
	if is_zero_approx(lane_offset) or p_path.size() < 2:
		return p_path
	var lane: PackedVector3Array = PackedVector3Array()
	for i in p_path.size():
		var forward: Vector3 = p_path[mini(i + 1, p_path.size() - 1)] \
				- p_path[maxi(i - 1, 0)]
		forward.y = 0.0
		if forward.length_squared() < 0.0001:
			lane.append(p_path[i])
			continue
		lane.append(p_path[i] + forward.normalized().cross(Vector3.UP) * lane_offset)
	return lane


# Snaps anything to the road - what a pump beside the kerb parks its customers
# on, so moving the pump moves the parking spot with it.
func nearest_center(p_position: Vector3) -> Vector3:
	if astar.get_point_count() == 0:
		return p_position
	return astar.get_point_position(astar.get_closest_point(p_position))


# Graph points with a single neighbour: where the network runs off the map, so
# where traffic can enter and leave. A spur that rejoins the road it left has
# no dead end and so never gets mistaken for an exit.
func entry_points() -> Array[Vector3]:
	var ends: Array[Vector3] = []
	for id in astar.get_point_ids():
		if astar.get_point_connections(id).size() == 1:
			ends.append(astar.get_point_position(id))
	return ends


const ENTRY_CLEAR: float = 8.0  # m of empty road a spawn needs at an entry


# The first of p_ends whose spawn spot has no vehicle standing on it, as an
# index into p_ends (-1 = every way in is blocked, try again later). A vehicle
# spawned onto an occupied entry lands stacked on top of the occupant.
func clear_entry(p_ends: Array[Vector3], p_tree: SceneTree) -> int:
	for i in p_ends.size():
		var spot: Vector3 = entry_transform(p_ends[i]).origin
		var blocked: bool = false
		for node in p_tree.get_nodes_in_group("vehicle"):
			if node is Vehicle and node.global_position.distance_to(spot) < ENTRY_CLEAR:
				blocked = true
				break
		if not blocked:
			return i
	return -1


# Where a car entering at an end belongs: a length INSIDE it, facing down the
# road. Parked on the end itself, half the wheelbase hangs off the tarmac onto
# the map's rim tiles, and the chassis grounds out before it can pull away.
# The models face +Z, so the basis is built from the heading directly -
# look_at() would point the boot down the road.
func entry_transform(p_position: Vector3) -> Transform3D:
	var heading: Vector3 = heading_at(p_position)
	return Transform3D(Basis.looking_at(-heading), p_position + heading * ENTRY_INSET)


# Which way a car arriving at an entry point should face: toward its only neighbour.
func heading_at(p_position: Vector3) -> Vector3:
	if astar.get_point_count() == 0:
		return Vector3.FORWARD
	var id: int = astar.get_closest_point(p_position)
	var connections: PackedInt64Array = astar.get_point_connections(id)
	if connections.is_empty():
		return Vector3.FORWARD
	var to_next: Vector3 = astar.get_point_position(connections[0]) \
			- astar.get_point_position(id)
	to_next.y = 0.0
	return to_next.normalized()
