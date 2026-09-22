class_name SkidMark
extends MeshInstance3D

const WIDTH:float = 0.3  # tyre contact patch
const POINT_SPACING:float = 0.15  # floor on segment length, not the sampling rate
const MAX_POINTS:int = 16  # chunk size, so the tail fades before the head
const IDLE_TIMEOUT:float = 0.2  # sec without a sample = the wheel gripped again
const LIFETIME:float = 5.0
const FADE_TIME:float = 3.0
const HOVER:float = 0.02  # lift off the ground, or it z-fights
const UV_LENGTH:float = 0.6  # metres of travel per texture repeat
# Soft across the width, tileable down the length.
const TEXTURE:String = "uid://ct1drn4frtwni"  # assets/textures/vfx/smoke/skid_streak.png
const DEFAULT_COLOR:Color = Color(0.08, 0.07, 0.06, 0.64)  # rubber, for untagged ground

# One material per COLOUR, not per mark - there would be thousands.
static var shared_materials:Dictionary = {}

var mark_color:Color = DEFAULT_COLOR
var points:PackedVector3Array = PackedVector3Array()
var seeded:bool = false  # continues an earlier chunk, so its first end is butted
var handed_over:bool = false  # a successor took over, so its last end is butted too
var finished:bool = false
var idle_time:float = 0.0


func _init():
	mesh = ImmediateMesh.new()


func _ready():
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	top_level = true  # the strip is built in world space
	position = Vector3.UP * HOVER


# Ends itself, so nothing has to notice the wheel gripping or the car dying.
func _process(p_delta:float):
	idle_time += p_delta
	if idle_time > IDLE_TIMEOUT:
		finish()


static func material_for(p_color:Color) -> StandardMaterial3D:
	if shared_materials.has(p_color):
		return shared_materials[p_color]
	var material:StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = p_color
	material.albedo_texture = load(TEXTURE)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED  # strip winding alternates
	material.vertex_color_use_as_albedo = true  # the stroke's ends taper by vertex alpha
	shared_materials[p_color] = material
	return material


func setup(p_color:Color = DEFAULT_COLOR) -> SkidMark:
	mark_color = p_color
	return self


# Chunks share their joint vertex, so the seam is butted rather than tapered.
func continue_from(p_previous:SkidMark):
	seeded = true
	p_previous.handed_over = true
	add_point(p_previous.points[p_previous.points.size() - 1])


func add_point(p_point:Vector3):
	idle_time = 0.0
	if finished or is_full():
		return
	if points.size() > 0 \
			and points[points.size() - 1].distance_to(p_point) < POINT_SPACING:
		return
	points.append(p_point)
	rebuild()


func is_full() -> bool:
	return points.size() >= MAX_POINTS


func finish():
	if finished:
		return
	finished = true
	set_process(false)
	rebuild()  # the tail only tapers once the stroke has really stopped
	var tween:Tween = create_tween()
	tween.tween_interval(LIFETIME)
	# Per-instance fade so every stroke of a colour can share one material.
	tween.tween_property(self, "transparency", 1.0, FADE_TIME)
	tween.tween_callback(queue_free)


# Triangle strip two vertices wide, UVs run by distance travelled.
func rebuild():
	var strip:ImmediateMesh = mesh
	strip.clear_surfaces()
	if points.size() < 2:
		return
	strip.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, material_for(mark_color))
	var travelled:float = 0.0
	for i in points.size():
		if i > 0:
			travelled += points[i].distance_to(points[i - 1])
		var side:Vector3 = direction_at(i).cross(Vector3.UP) * (WIDTH * 0.5)
		var v:float = travelled / UV_LENGTH
		strip.surface_set_color(Color(1.0, 1.0, 1.0, end_fade(i)))
		strip.surface_set_uv(Vector2(0.0, v))
		strip.surface_add_vertex(points[i] - side)
		strip.surface_set_uv(Vector2(1.0, v))
		strip.surface_add_vertex(points[i] + side)
	strip.surface_end()


# Central difference: the width stays square to the line THROUGH a corner.
func direction_at(p_index:int) -> Vector3:
	var behind:Vector3 = points[maxi(p_index - 1, 0)]
	var ahead:Vector3 = points[mini(p_index + 1, points.size() - 1)]
	var forward:Vector3 = ahead - behind
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return Vector3.FORWARD
	return forward.normalized()


# Only the two ends of the WHOLE stroke taper; a handed-over chunk is mid-track.
func end_fade(p_index:int) -> float:
	if p_index == 0 and not seeded:
		return 0.0
	if p_index == points.size() - 1 and finished and not handed_over:
		return 0.0
	return 1.0
