@tool
extends CompositorEffect
class_name PostProcessDepthOfField

## Depth of field post-processing effect.
## Physically-based or manual CoC blur with auto-focus, shaped bokeh kernels,
## chromatic fringing, and highlight bloom on bright out-of-focus areas.

enum FocusMode  { PHYSICAL, MANUAL }
enum BokehShape { CIRCLE, HEXAGON, OCTAGON, PENTAGON, TRIANGLE }
enum LensPreset { CUSTOM, F1_4, F2_0, F2_8, F4_0, F5_6, F8_0, F11, F16, F22 }

const FSTOP_VALUES: Array[float] = [0.0, 1.4, 2.0, 2.8, 4.0, 5.6, 8.0, 11.0, 16.0, 22.0]
const BOKEH_SIDES: Array[int] = [0, 6, 8, 5, 3]

@export_group("Settings")

## Focus mode. Physical uses aperture/focal-length to compute CoC.
## Manual uses explicit near/far ramps.
@export var focus_mode: FocusMode = FocusMode.PHYSICAL:
	set(v):
		mutex.lock()
		focus_mode = v
		mutex.unlock()

## Distance in world units to the focal plane. Ignored when auto-focus is enabled.
@export_range(0.0, 500.0, 0.1) var focus_distance: float = 5.0:
	set(v):
		mutex.lock()
		focus_distance = v
		mutex.unlock()

## Maximum blur radius in pixels. Caps the CoC to prevent extreme blurring.
@export_range(0.0, 64.0, 0.5) var max_blur: float = 16.0:
	set(v):
		mutex.lock()
		max_blur = v
		mutex.unlock()

## Overall blur intensity multiplier.
@export_range(0.0, 2.0, 0.01) var strength: float = 1.0:
	set(v):
		mutex.lock()
		strength = v
		mutex.unlock()

## Number of samples per bokeh ring. Higher = rounder, heavier.
@export_range(4, 32, 1) var samples: int = 12:
	set(v):
		mutex.lock()
		samples = v
		mutex.unlock()

@export_group("Advanced Settings")

@export_subgroup("Lens")

## Aperture preset. Overrides the custom aperture value.
@export var lens_preset: LensPreset = LensPreset.CUSTOM:
	set(v):
		mutex.lock()
		lens_preset = v
		if int(v) > 0 and int(v) < FSTOP_VALUES.size():
			aperture = FSTOP_VALUES[int(v)]
		mutex.unlock()

## f-stop number. Lower = wider aperture = shallower DOF. Used in Physical mode.
@export_range(0.5, 64.0, 0.1) var aperture: float = 2.8:
	set(v):
		mutex.lock()
		aperture = v
		lens_preset = LensPreset.CUSTOM
		mutex.unlock()

## Focal length in millimeters. Longer = narrower field of view = more DOF falloff.
@export_range(10.0, 300.0, 1.0) var focal_length: float = 50.0:
	set(v):
		mutex.lock()
		focal_length = v
		mutex.unlock()

@export_subgroup("Near / Far (Manual)")

## Distance before focus where blur begins ramping.
@export_range(0.0, 100.0, 0.1) var near_start: float = 0.0:
	set(v):
		mutex.lock()
		near_start = v
		mutex.unlock()

## Distance before focus where blur reaches maximum.
@export_range(0.0, 100.0, 0.1) var near_end: float = 2.0:
	set(v):
		mutex.lock()
		near_end = v
		mutex.unlock()

## Distance past focus where blur begins ramping.
@export_range(0.0, 200.0, 0.1) var far_start: float = 0.0:
	set(v):
		mutex.lock()
		far_start = v
		mutex.unlock()

## Distance past focus where blur reaches maximum.
@export_range(0.0, 500.0, 0.1) var far_end: float = 10.0:
	set(v):
		mutex.lock()
		far_end = v
		mutex.unlock()

@export_subgroup("Auto-Focus")

## When enabled, focus distance is read from the depth buffer at the focus point.
@export var autofocus_enabled: bool = false:
	set(v):
		mutex.lock()
		autofocus_enabled = v
		mutex.unlock()

## Horizontal position of the auto-focus sample point. 0.5 = screen center.
@export_range(0.0, 1.0, 0.01) var autofocus_x: float = 0.5:
	set(v):
		mutex.lock()
		autofocus_x = v
		mutex.unlock()

## Vertical position of the auto-focus sample point. 0.5 = screen center.
@export_range(0.0, 1.0, 0.01) var autofocus_y: float = 0.5:
	set(v):
		mutex.lock()
		autofocus_y = v
		mutex.unlock()

@export_subgroup("Bokeh")

## Shape of the blur kernel. Circle = smooth disc, others = polygon shapes.
@export var bokeh_shape: BokehShape = BokehShape.CIRCLE:
	set(v):
		mutex.lock()
		bokeh_shape = v
		mutex.unlock()

## Rotation angle of the bokeh polygon pattern.
@export_range(0.0, 360.0, 1.0) var bokeh_rotation: float = 0.0:
	set(v):
		mutex.lock()
		bokeh_rotation = v
		mutex.unlock()

@export_subgroup("Highlight")

## Boosts bright out-of-focus areas to simulate optical highlight bloom.
@export_range(0.0, 5.0, 0.1) var highlight_boost: float = 0.0:
	set(v):
		mutex.lock()
		highlight_boost = v
		mutex.unlock()

## Luminance above which highlights are boosted.
@export_range(0.0, 5.0, 0.1) var highlight_threshold: float = 1.0:
	set(v):
		mutex.lock()
		highlight_threshold = v
		mutex.unlock()

@export_subgroup("Chromatic")

## Separates R/B channels at bokeh edges for prismatic fringing.
@export_range(0.0, 2.0, 0.01) var chroma_amount: float = 0.0:
	set(v):
		mutex.lock()
		chroma_amount = v
		mutex.unlock()

@export_subgroup("Camera")

## Camera near plane distance. Must match your Godot camera settings.
@export_range(0.01, 10.0, 0.01) var near_plane: float = 0.05:
	set(v):
		mutex.lock()
		near_plane = v
		mutex.unlock()

## Camera far plane distance. Must match your Godot camera settings.
@export_range(10.0, 10000.0, 10.0) var far_plane: float = 4000.0:
	set(v):
		mutex.lock()
		far_plane = v
		mutex.unlock()

var rd: RenderingDevice
var shader: RID
var pipeline: RID
var _shader_copy: RID
var _pipe_copy: RID
var _nearest_sampler: RID

var mutex: Mutex = Mutex.new()
var _intermediate: RID
var _last_size: Vector2i = Vector2i()


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	access_resolved_depth = true
	rd = RenderingServer.get_rendering_device()
	if rd == null:
		return
	_create_pipeline()


func _create_pipeline() -> void:
	var shader_file: RDShaderFile = load("res://addons/compositor_effects/depth_of_field/depth_of_field.glsl")
	if shader_file == null:
		return

	var spirv: RDShaderSPIRV = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(spirv)
	if not shader.is_valid():
		return

	pipeline = rd.compute_pipeline_create(shader)

	var copy_file: RDShaderFile = load("res://addons/compositor_effects/shared/copy.glsl")
	if copy_file != null:
		_shader_copy = rd.shader_create_from_spirv(copy_file.get_spirv())
		if _shader_copy.is_valid():
			_pipe_copy = rd.compute_pipeline_create(_shader_copy)

	var sampler_state := RDSamplerState.new()
	sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	sampler_state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	sampler_state.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	_nearest_sampler = rd.sampler_create(sampler_state)


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

	if size != _last_size or not _intermediate.is_valid():
		if _intermediate.is_valid():
			rd.free_rid(_intermediate)
		var fmt := RDTextureFormat.new()
		fmt.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
		fmt.width = size.x
		fmt.height = size.y
		fmt.usage_bits = (
			RenderingDevice.TEXTURE_USAGE_STORAGE_BIT |
			RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT |
			RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT |
			RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
		)
		_intermediate = rd.texture_create(fmt, RDTextureView.new())
		_last_size = size

	mutex.lock()
	var _fd: float = focus_distance
	var _ap: float = aperture
	var _fl: float = focal_length
	var _mb: float = max_blur
	var _ns: float = near_start
	var _ne: float = near_end
	var _fs: float = far_start
	var _fe: float = far_end
	var _shape: float = float(BOKEH_SIDES[int(bokeh_shape)])
	var _rot: float = bokeh_rotation
	var _samples: float = float(samples)
	var _str: float = strength
	var _np: float = near_plane
	var _fp: float = far_plane
	var _afx: float = autofocus_x
	var _afy: float = autofocus_y
	var _afe: float = 1.0 if autofocus_enabled else 0.0
	var _chroma: float = chroma_amount
	var _hb: float = highlight_boost
	var _ht: float = highlight_threshold
	var _manual: float = 1.0 if focus_mode == FocusMode.MANUAL else 0.0
	mutex.unlock()

	var push_constant: PackedFloat32Array = PackedFloat32Array([
		_fd, _ap, _fl, _mb,
		_ns, _ne, _fs, _fe,
		_shape, _rot, _samples, _str,
		_np, _fp, _afx, _afy,
		_afe, _chroma, _hb, _ht,
		_manual, 0.0, 0.0, 0.0,
	])

	var x_groups: int = (size.x + 15) / 16
	var y_groups: int = (size.y + 15) / 16

	for view: int in render_scene_buffers.get_view_count():
		var color_image: RID = render_scene_buffers.get_color_layer(view)
		var depth_image: RID = render_scene_buffers.get_depth_layer(view)

		if not color_image.is_valid() or not depth_image.is_valid():
			continue
		if not _intermediate.is_valid():
			continue
		if not _nearest_sampler.is_valid():
			continue

		if _pipe_copy.is_valid():
			var u_cp_src: RDUniform = RDUniform.new()
			u_cp_src.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
			u_cp_src.binding = 0
			u_cp_src.add_id(color_image)
			var set_cp_src: RID = UniformSetCacheRD.get_cache(_shader_copy, 0, [u_cp_src])

			var u_cp_dst: RDUniform = RDUniform.new()
			u_cp_dst.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
			u_cp_dst.binding = 0
			u_cp_dst.add_id(_intermediate)
			var set_cp_dst: RID = UniformSetCacheRD.get_cache(_shader_copy, 1, [u_cp_dst])

			var cl_copy: int = rd.compute_list_begin()
			rd.compute_list_bind_compute_pipeline(cl_copy, _pipe_copy)
			rd.compute_list_bind_uniform_set(cl_copy, set_cp_src, 0)
			rd.compute_list_bind_uniform_set(cl_copy, set_cp_dst, 1)
			rd.compute_list_dispatch(cl_copy, x_groups, y_groups, 1)
			rd.compute_list_end()

		var u_src: RDUniform = RDUniform.new()
		u_src.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		u_src.binding = 0
		u_src.add_id(_intermediate)
		var set_src: RID = UniformSetCacheRD.get_cache(shader, 0, [u_src])

		var u_dst: RDUniform = RDUniform.new()
		u_dst.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		u_dst.binding = 0
		u_dst.add_id(color_image)
		var set_dst: RID = UniformSetCacheRD.get_cache(shader, 1, [u_dst])

		var u_depth: RDUniform = RDUniform.new()
		u_depth.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		u_depth.binding = 0
		u_depth.add_id(_nearest_sampler)
		u_depth.add_id(depth_image)
		var set_depth: RID = UniformSetCacheRD.get_cache(shader, 2, [u_depth])

		var compute_list: int = rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
		rd.compute_list_bind_uniform_set(compute_list, set_src, 0)
		rd.compute_list_bind_uniform_set(compute_list, set_dst, 1)
		rd.compute_list_bind_uniform_set(compute_list, set_depth, 2)
		rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), 96)
		rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
		rd.compute_list_end()


func _notification(what: int) -> void:
	# Cleanup is inlined: during PREDELETE the script instance is already being
	# destructed, so dispatching to another method fails ("null instance").
	if what != NOTIFICATION_PREDELETE or rd == null:
		return
	if _pipe_copy.is_valid():
		rd.free_rid(_pipe_copy)
		_pipe_copy = RID()
	if _shader_copy.is_valid():
		rd.free_rid(_shader_copy)
		_shader_copy = RID()
	if pipeline.is_valid():
		rd.free_rid(pipeline)
		pipeline = RID()
	if shader.is_valid():
		rd.free_rid(shader)
		shader = RID()
	if _intermediate.is_valid():
		rd.free_rid(_intermediate)
		_intermediate = RID()
	if _nearest_sampler.is_valid():
		rd.free_rid(_nearest_sampler)
		_nearest_sampler = RID()
