@tool
extends CompositorEffect
class_name PostProcessVignette

## Cinematic Vignette post-processing effect.
## Darkens or tints the extreme edges of the screen with configurable shapes,
## offsets, blend modes, and color options.

enum Shape { CIRCLE, OVAL, SQUARE }
enum BlendMode { MULTIPLY, MIX, ADDITIVE }

@export_group("Settings")

## Intensity of the vignette. 0 = invisible, 1 = maximum opacity at edges.
@export_range(0.0, 1.0, 0.01) var intensity: float = 1.0:
	set(v):
		mutex.lock()
		intensity = v
		mutex.unlock()

## Core radius of the unaffected center. Smaller values pull darkness inwards.
@export_range(0.0, 2.0, 0.01) var radius: float = 1.2:
	set(v):
		mutex.lock()
		radius = v
		mutex.unlock()

## Softness of the transition gradient. Keep high for smooth fade.
@export_range(0.0, 2.0, 0.01) var softness: float = 0.8:
	set(v):
		mutex.lock()
		softness = v
		mutex.unlock()

@export_group("Advanced Settings")

@export_subgroup("Shape & Position")

## Shape of the vignette. Circle corrects for aspect ratio, Oval scales to screen.
@export var shape: Shape = Shape.CIRCLE:
	set(v):
		mutex.lock()
		shape = v
		mutex.unlock()

## Horizontal center offset of the vignette mask.
@export_range(-1.0, 1.0, 0.01) var offset_x: float = 0.0:
	set(v):
		mutex.lock()
		offset_x = v
		mutex.unlock()

## Vertical center offset of the vignette mask.
@export_range(-1.0, 1.0, 0.01) var offset_y: float = 0.0:
	set(v):
		mutex.lock()
		offset_y = v
		mutex.unlock()

@export_subgroup("Color")

## Base color applied as the vignette.
@export var vignette_color: Color = Color.BLACK:
	set(v):
		mutex.lock()
		vignette_color = v
		mutex.unlock()

## Blend method used to apply the vignette color onto the screen.
@export var blend_mode: BlendMode = BlendMode.MULTIPLY:
	set(v):
		mutex.lock()
		blend_mode = v
		mutex.unlock()

## Overall master blend strength.
@export_range(0.0, 1.0, 0.01) var strength: float = 1.0:
	set(v):
		mutex.lock()
		strength = v
		mutex.unlock()

var rd: RenderingDevice
var shader: RID
var pipeline: RID
var mutex: Mutex = Mutex.new()


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	rd = RenderingServer.get_rendering_device()
	if rd == null:
		return
	_create_pipeline()


func _create_pipeline() -> void:
	var shader_file: RDShaderFile = load("res://addons/compositor_effects/vignette/vignette.glsl")
	if shader_file == null:
		return

	var spirv: RDShaderSPIRV = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(spirv)
	if not shader.is_valid():
		return

	pipeline = rd.compute_pipeline_create(shader)


func _render_callback(
	p_effect_callback_type: EffectCallbackType,
	p_render_data: RenderData
) -> void:
	if rd == null:
		return
	if not shader.is_valid() or not pipeline.is_valid():
		return

	var render_scene_buffers: RenderSceneBuffersRD = p_render_data.get_render_scene_buffers()
	if render_scene_buffers == null:
		return

	var size: Vector2i = render_scene_buffers.get_internal_size()
	if size.x == 0 or size.y == 0:
		return

	mutex.lock()
	var _intensity: float = intensity
	var _radius: float = radius
	var _softness: float = softness
	var _strength: float = strength
	var _cr: float = vignette_color.r
	var _cg: float = vignette_color.g
	var _cb: float = vignette_color.b
	var _sh: float = float(shape)
	var _ox: float = offset_x
	var _oy: float = offset_y
	var _bm: float = float(blend_mode)
	mutex.unlock()

	var push_constant: PackedFloat32Array = PackedFloat32Array([
		_intensity, _radius, _softness, _strength,
		_cr, _cg, _cb, _sh,
		_ox, _oy, _bm, 0.0,
		0.0, 0.0, 0.0, 0.0,
	])

	var x_groups: int = (size.x + 15) / 16
	var y_groups: int = (size.y + 15) / 16

	for view: int in render_scene_buffers.get_view_count():
		var color_image: RID = render_scene_buffers.get_color_layer(view)
		if not color_image.is_valid():
			continue

		var color_uniform: RDUniform = RDUniform.new()
		color_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		color_uniform.binding = 0
		color_uniform.add_id(color_image)

		var uniform_set: RID = UniformSetCacheRD.get_cache(shader, 0, [color_uniform])

		var compute_list: int = rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
		rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
		rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), 64)
		rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
		rd.compute_list_end()


func _notification(what: int) -> void:
	# Cleanup is inlined: during PREDELETE the script instance is already being
	# destructed, so dispatching to another method fails ("null instance").
	if what != NOTIFICATION_PREDELETE or rd == null:
		return
	if pipeline.is_valid():
		rd.free_rid(pipeline)
		pipeline = RID()
	if shader.is_valid():
		rd.free_rid(shader)
		shader = RID()
