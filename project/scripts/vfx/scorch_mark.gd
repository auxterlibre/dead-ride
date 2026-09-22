class_name ScorchMark
extends MeshInstance3D
# A random cell of the marks sheet; the ember glow cools first, the black mark lingers.

const SIZE:float = 6.0
const GLOW_TIME:float = 1.5
const HOLD_TIME:float = 20.0
const FADE_TIME:float = 5.0

@onready var SHADER:Shader = load("uid://bxt3g03w8dl2t")
@onready var MARKS:Texture2D = load("uid://ch325nt5q3rb")

var hit_position:Vector3
var hit_normal:Vector3


func _ready():
	var material:ShaderMaterial = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("marks", MARKS)
	material.set_shader_parameter("uv_offset",
			Vector2(randi_range(0, 3), randi_range(0, 3)) * 0.25)
	var quad:QuadMesh = QuadMesh.new()
	quad.size = Vector2(SIZE, SIZE)
	quad.orientation = PlaneMesh.FACE_Y
	quad.material = material
	mesh = quad
	cast_shadow = SHADOW_CASTING_SETTING_OFF
	global_position = hit_position + hit_normal * 0.03
	quaternion = Quaternion(Vector3.UP, hit_normal)
	rotate_object_local(Vector3.UP, randf() * TAU)
	# tween_method, not tween_property: shader params aren't listed as
	# properties until the shader compiles, so the path form can fail.
	var tween:Tween = create_tween()
	tween.tween_method(func(p_value):
			material.set_shader_parameter("glow", p_value), 1.0, 0.0, GLOW_TIME)
	tween.tween_interval(HOLD_TIME)
	tween.tween_method(func(p_value):
			material.set_shader_parameter("opacity", p_value), 1.0, 0.0, FADE_TIME)
	tween.tween_callback(queue_free)


func setup(p_position:Vector3, p_normal:Vector3) -> ScorchMark:
	hit_position = p_position
	hit_normal = p_normal
	return self
