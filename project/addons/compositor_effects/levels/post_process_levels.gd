@tool
extends CompositorEffect
class_name PostProcessLevels

## Levels post-processing effect.
## Input/output black and white point remapping with midtone gamma,
## per-channel offsets, per-channel gamma, and output clamping.

@export_group("Settings")

@export_subgroup("Input")

## Input black point. Values below this become 0.
@export_range(0.0, 1.0, 0.01) var input_black: float = 0.0:
	set(v):
		mutex.lock()
		input_black = v
		mutex.unlock()

## Input white point. Values above this become 1.
@export_range(0.0, 1.0, 0.01) var input_white: float = 1.0:
	set(v):
		mutex.lock()
		input_white = v
		mutex.unlock()

## Midtone gamma correction. <1 = darken midtones, >1 = brighten midtones.
@export_range(0.1, 5.0, 0.01) var midtone_gamma: float = 1.0:
	set(v):
		mutex.lock()
		midtone_gamma = v
		mutex.unlock()

@export_subgroup("Output")

## Output black point. Remapped minimum brightness.
@export_range(0.0, 1.0, 0.01) var output_black: float = 0.0:
	set(v):
		mutex.lock()
		output_black = v
		mutex.unlock()

## Output white point. Remapped maximum brightness.
@export_range(0.0, 1.0, 0.01) var output_white: float = 1.0:
	set(v):
		mutex.lock()
		output_white = v
		mutex.unlock()

## Blend between original and levels-adjusted result. 0 = bypass, 1 = full.
@export_range(0.0, 1.0, 0.01) var strength: float = 1.0:
	set(v):
		mutex.lock()
		strength = v
		mutex.unlock()

@export_group("Advanced Settings")

@export_subgroup("Per-Channel Input")

## Red channel input black offset. Added to the master input_black for red only.
@export_range(-0.5, 0.5, 0.01) var input_black_r: float = 0.0:
	set(v):
		mutex.lock()
		input_black_r = v
		mutex.unlock()

## Red channel input white offset. Added to the master input_white for red only.
@export_range(-0.5, 0.5, 0.01) var input_white_r: float = 0.0:
	set(v):
		mutex.lock()
		input_white_r = v
		mutex.unlock()

## Green channel input black offset.
@export_range(-0.5, 0.5, 0.01) var input_black_g: float = 0.0:
	set(v):
		mutex.lock()
		input_black_g = v
		mutex.unlock()

## Green channel input white offset.
@export_range(-0.5, 0.5, 0.01) var input_white_g: float = 0.0:
	set(v):
		mutex.lock()
		input_white_g = v
		mutex.unlock()

## Blue channel input black offset.
@export_range(-0.5, 0.5, 0.01) var input_black_b: float = 0.0:
	set(v):
		mutex.lock()
		input_black_b = v
		mutex.unlock()

## Blue channel input white offset.
@export_range(-0.5, 0.5, 0.01) var input_white_b: float = 0.0:
	set(v):
		mutex.lock()
		input_white_b = v
		mutex.unlock()

@export_subgroup("Per-Channel Gamma")

## Red gamma multiplier. Multiplied with the master midtone_gamma.
@export_range(0.1, 4.0, 0.01) var gamma_r: float = 1.0:
	set(v):
		mutex.lock()
		gamma_r = v
		mutex.unlock()

## Green gamma multiplier.
@export_range(0.1, 4.0, 0.01) var gamma_g: float = 1.0:
	set(v):
		mutex.lock()
		gamma_g = v
		mutex.unlock()

## Blue gamma multiplier.
@export_range(0.1, 4.0, 0.01) var gamma_b: float = 1.0:
	set(v):
		mutex.lock()
		gamma_b = v
		mutex.unlock()

@export_subgroup("Output")

## When enabled, clamps final output to 0-1 LDR range.
@export var clamp_output: bool = false:
	set(v):
		mutex.lock()
		clamp_output = v
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
	var shader_file: RDShaderFile = load("res://addons/compositor_effects/levels/levels.glsl")
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
	var _ib: float = input_black
	var _iw: float = input_white
	var _ig: float = midtone_gamma
	var _ob: float = output_black
	var _ow: float = output_white
	var _str: float = strength
	var _ibr: float = input_black_r
	var _iwr: float = input_white_r
	var _ibg: float = input_black_g
	var _iwg: float = input_white_g
	var _ibb: float = input_black_b
	var _iwb: float = input_white_b
	var _gr: float = gamma_r
	var _gg: float = gamma_g
	var _gb: float = gamma_b
	var _clamp: float = 1.0 if clamp_output else 0.0
	mutex.unlock()

	var push_constant: PackedFloat32Array = PackedFloat32Array([
		_ib, _iw, _ig, _ob,
		_ow, _str, _ibr, _iwr,
		_ibg, _iwg, _ibb, _iwb,
		_gr, _gg, _gb, _clamp,
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
