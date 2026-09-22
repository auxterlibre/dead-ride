class_name VisionConeVisual
extends MeshInstance3D
# Debug draw of the parent CharacterVision, toggled with debug_text_toggle.

const CONE_STEP_DEG:float = 4.0
const RING_SEGMENTS:int = 32
const HEIGHT:float = 0.08  # draw plane over the ground
const COLOR_SCAN:Color = Color(0.35, 0.9, 1.0, 0.3)
const COLOR_ALERT:Color = Color(1.0, 0.3, 0.2, 0.35)

var mesh_draw:ImmediateMesh
var fill_material:StandardMaterial3D
var line_material:StandardMaterial3D

@onready var vision:CharacterVision = get_parent()


func _ready():
	# Geometry is built in WORLD space every frame - the node opts out of the
	# (rotating) parent transform.
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_draw = ImmediateMesh.new()
	mesh = mesh_draw
	fill_material = StandardMaterial3D.new()
	fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	line_material = fill_material.duplicate()
	visible = false


func _process(_delta):
	visible = Globals.debug_mode


func _physics_process(_delta):
	if not visible:
		return
	mesh_draw.clear_surfaces()
	if vision.character.is_dead:
		return
	# Heat: suspicion warms the cone toward alert red; a held target pins it.
	var heat:float = 1.0 if vision.target else vision.suspicion
	var color:Color = COLOR_SCAN.lerp(COLOR_ALERT, heat)
	fill_material.albedo_color = color
	line_material.albedo_color = Color(color, 0.6)
	var origin:Vector3 = vision.character.global_position + Vector3.UP * HEIGHT
	var facing:Vector3 = vision.visual.global_basis.z
	facing.y = 0.0
	facing = facing.normalized()
	var data:CharacterData = vision.character.data
	draw_cone(origin, facing, data.vision_range if data else 15.0)
	draw_ring(origin, vision.effective_detection_range())


# Filled fan across the vision angle; each edge stops where a wall stops
# the matching LOS ray, so the drawn shape IS what the enemy can see.
func draw_cone(p_origin:Vector3, p_facing:Vector3, p_range:float):
	var half:float = vision.vision_angle * 0.5
	var steps:int = ceili(vision.vision_angle / CONE_STEP_DEG)
	var edge:PackedVector3Array = [p_origin]
	mesh_draw.surface_begin(Mesh.PRIMITIVE_TRIANGLES, fill_material)
	var previous:Vector3
	for i in steps + 1:
		var angle:float = deg_to_rad(lerpf(-half, half, i / float(steps)))
		var direction:Vector3 = p_facing.rotated(Vector3.UP, angle)
		var point:Vector3 = p_origin + direction * clipped_distance(direction, p_range)
		edge.append(point)
		if i > 0:
			mesh_draw.surface_add_vertex(p_origin)
			mesh_draw.surface_add_vertex(previous)
			mesh_draw.surface_add_vertex(point)
		previous = point
	mesh_draw.surface_end()
	# Crisp perimeter over the faint fill.
	edge.append(p_origin)
	mesh_draw.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, line_material)
	for point in edge:
		mesh_draw.surface_add_vertex(point)
	mesh_draw.surface_end()


# Detection is omnidirectional - drawn as an outline so it reads under the
# cone fill instead of stacking alpha with it.
func draw_ring(p_origin:Vector3, p_range:float):
	mesh_draw.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, line_material)
	for i in RING_SEGMENTS + 1:
		var direction:Vector3 = Vector3.FORWARD.rotated(Vector3.UP,
				TAU * i / float(RING_SEGMENTS))
		mesh_draw.surface_add_vertex(
				p_origin + direction * clipped_distance(direction, p_range))
	mesh_draw.surface_end()


func clipped_distance(p_direction:Vector3, p_range:float) -> float:
	var from:Vector3 = vision.character.global_position \
			+ Vector3.UP * CharacterVision.EYE_HEIGHT
	var hit:Dictionary = vision.character.get_world_3d().direct_space_state \
			.intersect_ray(PhysicsRayQueryParameters3D.create(from,
					from + p_direction * p_range, CharacterVision.OBSTACLE_MASK))
	return from.distance_to(hit.position) if hit else p_range
