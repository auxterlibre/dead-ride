class_name RangeRing
extends MeshInstance3D

const SEGMENTS: int = 48
const HEIGHT: float = 0.08
const FILL_ALPHA: float = 0.06
const LINE_ALPHA: float = 0.9

var draw_mesh: ImmediateMesh
var fill_material: StandardMaterial3D
var line_material: StandardMaterial3D


func _ready():
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	draw_mesh = ImmediateMesh.new()
	mesh = draw_mesh
	fill_material = StandardMaterial3D.new()
	fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	line_material = fill_material.duplicate()
	visible = false


func draw_circle(p_centre: Vector3, p_radius: float, p_color: Color):
	draw_mesh.clear_surfaces()
	visible = p_radius > 0.0
	if not visible:
		return
	fill_material.albedo_color = Color(p_color, FILL_ALPHA)
	line_material.albedo_color = Color(p_color, LINE_ALPHA)
	var centre: Vector3 = Vector3(p_centre.x, HEIGHT, p_centre.z)
	var rim: PackedVector3Array = []
	for i in SEGMENTS + 1:
		rim.append(centre + Vector3.FORWARD.rotated(Vector3.UP,
				TAU * i / float(SEGMENTS)) * p_radius)
	draw_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, fill_material)
	for i in SEGMENTS:
		draw_mesh.surface_add_vertex(centre)
		draw_mesh.surface_add_vertex(rim[i])
		draw_mesh.surface_add_vertex(rim[i + 1])
	draw_mesh.surface_end()
	draw_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, line_material)
	for point in rim:
		draw_mesh.surface_add_vertex(point)
	draw_mesh.surface_end()
