class_name ThrowPreview
extends MeshInstance3D
# The throw's read-out, split off PlayerThrow: walks the arc the grenade will
# ACTUALLY take (swept as the ball it is, bouncing where it bounces), then
# draws it with the blast and core zones into this node's ImmediateMesh. Pulls
# the live launch/flight/reveal state from `throw`; never drives the throw.

const TRACE_STEPS: int = 32
const TRACE_OVERSHOOT: float = 1.8  # of the nominal flight, so the arc reaches ground
const TRACE_BOUNCES: int = 2  # walls it may glance off before the arc gives up
# FITTED against a measured throw at a wall, not copied off the physics
# material: the real rebound also loses speed to the ground bite that follows,
# so the material's 0.55 sent the predicted arc back twice as far as it goes.
const TRACE_BOUNCE_KEEP: float = 0.22  # normal speed kept off a wall
const TRACE_SLIDE_KEEP: float = 0.7  # tangential speed left after friction
const RING_SEGMENTS: int = 40
const ARC_COLOR: Color = Color(1.0, 0.96, 0.85, 1.0)
const BLAST_COLOR: Color = Color(0.95, 0.25, 0.08, 1.0)
const CORE_COLOR: Color = Color(1.0, 0.78, 0.15, 1.0)
const FILL_ALPHA: float = 0.22  # the zone reads as a wash; its rim draws the line
const GROUND_LIFT: float = 0.05

@export var throw: PlayerThrow
# The wind-up is not instant, so neither is the read-out: the arc runs out to
# the landing spot while the blast ring pops and the core follows it in. Timed
# as FRACTIONS of the wind-up clip, so retiming the animation retimes the
# read-out with it - the same reason the release reads its marker.
@export var arc_grow_fraction: float = 0.55
@export var ring_grow_fraction: float = 0.45
@export var core_lag_fraction: float = 0.22  # how far the core trails the blast

var landing: Vector3

@onready var trace_shape: SphereShape3D = make_trace_shape()


# One mesh for the lot: the arc as a strip, then a ring at the blast edge and
# another at the core, so what the throw will cover is drawn the same way the
# damage is worked out.
func draw(p_explosive: ExplosiveData):
	var arc_mesh: ImmediateMesh = mesh as ImmediateMesh
	if arc_mesh == null:
		return
	arc_mesh.clear_surfaces()
	var arc: PackedVector3Array = trace()
	# The line RUNS OUT from the hand rather than appearing whole, so the
	# read-out arrives with the wind-up instead of ahead of it.
	var windup: float = windup_time()
	var reach: int = maxi(2, ceili(arc.size()
			* pop(throw.revealed / (windup * arc_grow_fraction))))
	arc_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in mini(reach, arc.size()):
		arc_mesh.surface_set_color(ARC_COLOR)
		arc_mesh.surface_add_vertex(arc[i])
	arc_mesh.surface_end()
	# Outer first, core trailing it in - two circles arriving together read as
	# one blob, and the lag is what makes the pair legible.
	var ring_time: float = windup * ring_grow_fraction
	zone(arc_mesh, p_explosive.blast_radius_value, BLAST_COLOR,
			pop(throw.revealed / ring_time))
	zone(arc_mesh, p_explosive.core_radius_value, CORE_COLOR,
			pop((throw.revealed - windup * core_lag_fraction) / ring_time))


# Walks the arc the throw will ACTUALLY take and stops at the first thing it
# meets, so the rings land where the grenade lands rather than under the
# cursor - throw at a wall and the preview falls short, as it should.
# Stepped rather than sampled off the closed-form parabola, because a bounce
# needs a live velocity to reflect. A WALL turns the throw and the arc carries
# on; only a floor-ish face ends it. Without this the ring sat on the ground
# BEHIND a wall the grenade could never reach.
func trace() -> PackedVector3Array:
	var points: PackedVector3Array = PackedVector3Array()
	var at: Vector3 = throw.throw_origin()
	var velocity: Vector3 = throw.launch
	var step: float = throw.flight * TRACE_OVERSHOOT / TRACE_STEPS
	var bounces: int = 0
	points.append(at)
	for i in TRACE_STEPS * 2:
		var next: Vector3 = at + velocity * step
		velocity.y -= throw.gravity * step
		var hit: Dictionary = sweep(at, next)
		if hit.is_empty():
			at = next
			points.append(at)
			continue
		points.append(hit.position)
		landing = hit.position
		# Floor-ish, or out of bounces: this is where it comes to rest.
		if hit.normal.y > 0.7 or bounces >= TRACE_BOUNCES:
			return points
		# Split the way the solver does: restitution acts on the NORMAL
		# component and friction on the tangent. Scaling the whole reflected
		# vector by one factor threw the arc back at the player far harder
		# than the grenade actually comes off a wall.
		var into: Vector3 = hit.normal * velocity.dot(hit.normal)
		velocity = (velocity - into) * TRACE_SLIDE_KEEP - into * TRACE_BOUNCE_KEEP
		# Off the surface, or the next cast starts inside it and hits instantly.
		at = hit.position + hit.normal * 0.06
		bounces += 1
	landing = at
	return points


func cast(p_from: Vector3, p_to: Vector3) -> Dictionary:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			p_from, p_to, PlayerThrow.WORLD_MASK)
	return get_world_3d().direct_space_state.intersect_ray(query)


# The arc is swept as the BALL it is, not as a point. A ray slips over the lip
# of a wall the 0.22m grenade clips, which is exactly how the preview came to
# promise a throw that cleared a crate the real one bounced off.
func sweep(p_from: Vector3, p_to: Vector3) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = trace_shape
	query.collision_mask = PlayerThrow.WORLD_MASK
	query.transform = Transform3D(Basis.IDENTITY, p_from)
	query.motion = p_to - p_from
	var fractions: PackedFloat32Array = space.cast_motion(query)
	if fractions.size() < 2 or fractions[0] >= 1.0:
		return {}
	var hit: Dictionary = {"position": p_from + query.motion * fractions[0]}
	# Rest info at the UNSAFE fraction, where the shape is actually touching -
	# at the safe one it is a hair clear and reports nothing to take a normal from.
	query.transform = Transform3D(Basis.IDENTITY, p_from + query.motion * fractions[1])
	query.motion = Vector3.ZERO
	var rest: Dictionary = space.get_rest_info(query)
	hit["normal"] = rest.normal if rest.has("normal") else Vector3.UP
	return hit


# The wind-up clip's length, or a sane default before the tree can say.
func windup_time() -> float:
	var length: float = throw.animator.get_clip_length(PlayerThrow.POSE_READY) \
			if throw.animator else 0.0
	return length if length > 0.01 else 0.5


func make_trace_shape() -> SphereShape3D:
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = PlayerThrow.BODY_RADIUS
	return shape


# Snappy: most of the travel in the first third, then a small overshoot that
# settles. Below zero is "not started", so a lagging ring simply is not drawn.
func pop(p_t: float) -> float:
	if p_t <= 0.0:
		return 0.0
	if p_t >= 1.0:
		return 1.0
	var back: float = 1.7
	var inverted: float = p_t - 1.0
	return 1.0 + (back + 1.0) * pow(inverted, 3) + back * pow(inverted, 2)


# A filled wash with a solid rim, not a hairline: a one-pixel circle disappears
# against bright sand, and what is being asked is "how much ground does this
# cover", which an area answers and an outline only implies.
func zone(p_mesh: ImmediateMesh, p_radius: float, p_color: Color,
		p_grow: float = 1.0):
	if p_radius <= 0.01 or p_grow <= 0.001:
		return
	var rim: PackedVector3Array = rim_points(p_radius * p_grow)
	var fill: Color = Color(p_color.r, p_color.g, p_color.b, FILL_ALPHA * p_grow)
	p_color.a *= p_grow
	# No TRIANGLE_FAN in Godot 4, so the disc is spokes of triangles.
	p_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var centre: Vector3 = landing + Vector3.UP * GROUND_LIFT
	for i in RING_SEGMENTS:
		for point in [centre, rim[i], rim[i + 1]]:
			p_mesh.surface_set_color(fill)
			p_mesh.surface_add_vertex(point)
	p_mesh.surface_end()
	p_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for point in rim:
		p_mesh.surface_set_color(p_color)
		p_mesh.surface_add_vertex(point)
	p_mesh.surface_end()


# Dropped onto whatever is under each segment, so a zone over a kerb follows it
# instead of sinking into it.
func rim_points(p_radius: float) -> PackedVector3Array:
	var points: PackedVector3Array = PackedVector3Array()
	for i in RING_SEGMENTS + 1:
		var angle: float = TAU * i / RING_SEGMENTS
		var spot: Vector3 = landing + Vector3(cos(angle), 0.0, sin(angle)) * p_radius
		var grounded: Dictionary = cast(spot + Vector3.UP * 3.0, spot + Vector3.DOWN * 3.0)
		points.append((grounded.position if grounded else spot)
				+ Vector3.UP * GROUND_LIFT)
	return points
