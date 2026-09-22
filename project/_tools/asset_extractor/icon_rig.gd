extends RefCounted
# The one place the item-icon look lives: camera angle, light, framing, and
# the item's authored pose knobs. render_item_icons batches over it and
# icon_studio drives it by hand - sharing this file is what keeps the tool's
# preview and the shipped png from drifting apart.

const SOURCE_ROOT: String = "res://data/items"  # every item lists; model-less ones just can't render
const OUT_ROOT: String = "res://assets/textures/thumbnails"
const CELL: int = 128  # px per grid cell, matching the inventory UI

# Barrel reads to the left with a 3/4 turn from above, as in the mockup.
const CAMERA_YAW: float = 205.0
const CAMERA_PITCH: float = -22.0
const FIT_MARGIN: float = 1.14  # breathing room around the mesh bounds
const KEY_LIGHT: Vector3 = Vector3(-35.0, 235.0, 0.0)
const AMBIENT_ENERGY: float = 0.55


# Recursive, and the icon lands in the folder named after the item's TOP
# folder under data/items: weapons are filed under ranged/ and melee/, but
# their thumbnails stay together in thumbnails/weapons rather than sprouting
# the same split.
static func items_under(p_dir: String) -> Array:
	var found: Array = []
	if not DirAccess.dir_exists_absolute(p_dir):
		return found
	for file in DirAccess.get_files_at(p_dir):
		if file.ends_with(".tres"):
			found.append("%s/%s" % [p_dir, file])
	for sub in DirAccess.get_directories_at(p_dir):
		found.append_array(items_under("%s/%s" % [p_dir, sub]))
	return found


static func icon_path(p_item_path: String) -> String:
	return "%s/%s/%s.png" % [OUT_ROOT, bucket_of(p_item_path),
			p_item_path.get_file().get_basename()]


# The item's top folder under data/items - the thumbnail bucket, and the
# category the studio's list dividers group by.
static func bucket_of(p_item_path: String) -> String:
	return p_item_path.trim_prefix(SOURCE_ROOT + "/").get_slice("/", 0)


# The renderable model under a pivot carrying the item's authored yaw/pitch,
# so the knobs compose with the tool laydown instead of fighting its euler.
# The model is RE-CENTERED on the pivot by its visual bounds: scene origins
# are authored for gameplay (a weapon's is its grip, the grenade's its base),
# and rotating around one swings the mesh in an arc instead of spinning it.
# Null = nothing to render (icon-only items).
# Every item's 3D body is ItemData.model now - a scene, so poses (the laid-down
# screwdriver) are authored in the .tscn rather than special-cased here.
static func subject_for(p_data: ItemData) -> Node3D:
	if p_data.model == null:
		return null
	var inner: Node3D = p_data.model.instantiate()
	var pivot: Node3D = Node3D.new()
	pivot.add_child(inner)
	inner.position -= offline_bounds(pivot).get_center()
	pose(pivot, p_data)
	return pivot


# mesh_bounds for a branch NOT yet in the tree, where global_transform is an
# error: accumulates the transforms by hand instead.
static func offline_bounds(p_node: Node,
		p_parent: Transform3D = Transform3D.IDENTITY) -> AABB:
	var accumulated: Transform3D = p_parent
	if p_node is Node3D:
		accumulated = p_parent * p_node.transform
	var bounds: AABB = AABB()
	if p_node is MeshInstance3D and p_node.visible and p_node.mesh != null:
		bounds = accumulated * p_node.get_aabb()
	for child in p_node.get_children():
		var merged: AABB = offline_bounds(child, accumulated)
		if merged.size == Vector3.ZERO:
			continue
		bounds = merged if bounds.size == Vector3.ZERO else bounds.merge(merged)
	return bounds


static func pose(p_pivot: Node3D, p_data: ItemData):
	p_pivot.rotation_degrees = Vector3(p_data.icon_pitch, p_data.icon_yaw,
			p_data.icon_roll)


# The subject is a MANNEQUIN: drawn, never simulated. Muzzle flashes, lights,
# particles and audio are firing dressing, not the silhouette - and a
# throwable's RigidBody must not obey gravity while it poses (the grenade
# fell out of the studio frame, and had been rendering a few pixels low even
# in the two-frame batch pass).
static func strip_effects(p_root: Node):
	p_root.process_mode = Node.PROCESS_MODE_DISABLED
	for node in p_root.find_children("*", "", true, false):
		if node is RigidBody3D:
			node.freeze = true
		if node is Light3D or node is GPUParticles3D or node is AudioStreamPlayer3D:
			node.queue_free()
		elif node is MeshInstance3D and node.name.contains("Flash"):
			node.queue_free()


static func add_environment(p_viewport: SubViewport):
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.85, 0.88, 0.95)
	environment.environment.ambient_light_energy = AMBIENT_ENERGY
	p_viewport.add_child(environment)


static func add_light(p_viewport: SubViewport):
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = KEY_LIGHT
	p_viewport.add_child(light)


static func add_camera(p_viewport: SubViewport) -> Camera3D:
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	p_viewport.add_child(camera)
	return camera


static func mesh_bounds(p_root: Node) -> AABB:
	var bounds: AABB = AABB()
	var first: bool = true
	# find_children only walks DESCENDANTS, so a bare mesh subject (a tool) is
	# its own root and would otherwise measure as empty.
	var nodes: Array = p_root.find_children("*", "MeshInstance3D", true, false)
	if p_root is MeshInstance3D:
		nodes.append(p_root)
	for node in nodes:
		if not node.visible or node.mesh == null:
			continue
		var box: AABB = node.global_transform * node.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


# The one true export: a fresh subject, a throwaway viewport, the png on
# disk. The batch renderer, the studio's save AND its preset batches all call
# this, so every path ships bit-identical pixels. p_host only hosts the
# temporary viewport for the two frames the render takes.
static func render_png(p_host: Node, p_data: ItemData, p_out_path: String) -> int:
	var subject: Node3D = subject_for(p_data)
	if subject == null:
		return ERR_INVALID_DATA
	# A model with nothing to see - the fists are a deliberately invisible
	# scene - has no bounds to frame: the camera would be set to size zero
	# and the engine refuses with an error per export. A named skip instead.
	# OFFLINE bounds: this guard runs before the subject is in the tree, and
	# mesh_bounds' global_transform errors out there (returning identity, so
	# the measurement was wrong as well as loud).
	if offline_bounds(subject).get_longest_axis_size() < 0.001:
		subject.free()
		return ERR_UNAVAILABLE
	var viewport: SubViewport = SubViewport.new()
	viewport.size = p_data.size * CELL
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	p_host.add_child(viewport)
	add_environment(viewport)
	add_light(viewport)
	viewport.add_child(subject)
	strip_effects(subject)
	var camera: Camera3D = add_camera(viewport)
	frame_subject(camera, viewport.size, mesh_bounds(subject), p_data.icon_zoom)
	# Two frames: the first lets the freshly added nodes reach the server.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(p_out_path.get_base_dir()))
	var error: int = viewport.get_texture().get_image().save_png(
			ProjectSettings.globalize_path(p_out_path))
	viewport.queue_free()
	return error


# Fits the bounds to the view in CAMERA space, so the framing holds at any
# angle and the icon's aspect never stretches the mesh. Resets the camera to
# the house angle first, which makes it IDEMPOTENT - the studio re-frames on
# every tweak. p_zoom > 1 dollies in over the auto-fit.
static func frame_subject(p_camera: Camera3D, p_view_size: Vector2i,
		p_bounds: AABB, p_zoom: float = 1.0):
	p_camera.global_transform = Transform3D(Basis.from_euler(Vector3(
			deg_to_rad(CAMERA_PITCH), deg_to_rad(CAMERA_YAW), 0.0)), Vector3.ZERO)
	var to_camera: Transform3D = p_camera.global_transform.affine_inverse()
	var low: Vector3 = Vector3.INF
	var high: Vector3 = -Vector3.INF
	for i in 8:
		var corner: Vector3 = to_camera * p_bounds.get_endpoint(i)
		low = low.min(corner)
		high = high.max(corner)
	var extent: Vector3 = high - low
	var aspect: float = float(p_view_size.x) / float(p_view_size.y)
	# Floored: a degenerate subject must never hand the camera a zero size,
	# whatever future path reaches here without the render guard.
	p_camera.size = maxf(maxf(extent.y, extent.x / aspect) * FIT_MARGIN
			/ maxf(p_zoom, 0.05), 0.01)
	var center: Vector3 = (low + high) * 0.5
	var basis: Basis = p_camera.global_transform.basis
	# Slide the camera so the bounds centre lands on the lens axis, then back
	# off far enough that nothing crosses the near plane.
	p_camera.global_position += basis * Vector3(center.x, center.y, 0.0)
	p_camera.global_position += basis.z * (extent.z * 0.5 + 1.0)
	p_camera.near = 0.05
	p_camera.far = extent.z + 10.0
