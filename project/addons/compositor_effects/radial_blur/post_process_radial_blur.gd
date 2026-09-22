@tool
extends CompositorEffect
class_name PostProcessRadialBlur

## Cinematic Radial / Action Zoom Blur.
## Blurs the image outwards or inwards along vectors pointing to a focal center.
## Vital for simulating high-speed action, tunnel vision, or impact shockwaves.

@export_group("Settings")

## Relative X coordinate of the focal point (0.0 = Left, 1.0 = Right).
@export_range(0.0, 1.0, 0.01) var center_x: float = 0.5:
	set(v): mutex.lock(); center_x = v; mutex.unlock()

## Relative Y coordinate of the focal point (0.0 = Top, 1.0 = Bottom).
@export_range(0.0, 1.0, 0.01) var center_y: float = 0.5:
	set(v): mutex.lock(); center_y = v; mutex.unlock()

## Intensity of the zoom blur stretch.
@export_range(0.0, 2.0, 0.01) var blur_strength: float = 0.2:
	set(v): mutex.lock(); blur_strength = v; mutex.unlock()

@export_group("Advanced Settings")

## The number of texture fetches evaluated along the radial vector.
## Higher looks smoother but costs significantly more GPU time.
@export_range(4, 64, 1) var sample_count: int = 16:
	set(v): mutex.lock(); sample_count = v; mutex.unlock()

## Math exponent calculating how aggressively the blur scales by distance.
## 1.0 = linear from center. >1.0 = keeps center sharper and blurs edges exponentially.
@export_range(0.5, 3.0, 0.01) var blur_power: float = 1.0:
	set(v): mutex.lock(); blur_power = v; mutex.unlock()


var rd: RenderingDevice
var shader: RID
var pipeline: RID
var _shader_copy: RID
var _pipe_copy: RID

var mutex: Mutex = Mutex.new()
var _intermediate: RID
var _last_size: Vector2i = Vector2i()


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	rd = RenderingServer.get_rendering_device()
	if rd == null:
		return
	_create_pipeline()


func _create_pipeline() -> void:
	var shader_file: RDShaderFile = load("res://addons/compositor_effects/radial_blur/radial_blur.glsl")
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
	var _cx: float = center_x
	var _cy: float = center_y
	var _bs: float = blur_strength
	var _sc: float = float(sample_count)
	var _bp: float = blur_power
	mutex.unlock()

	var push_constant: PackedFloat32Array = PackedFloat32Array([
		_cx, _cy, _bs, _sc,
		_bp, float(size.x), float(size.y), 0.0,
		0.0, 0.0, 0.0, 0.0,
		0.0, 0.0, 0.0, 0.0
	])

	var x_groups: int = (size.x + 15) / 16
	var y_groups: int = (size.y + 15) / 16

	for view: int in render_scene_buffers.get_view_count():
		var color_img: RID = render_scene_buffers.get_color_layer(view)
		if not color_img.is_valid() or not _intermediate.is_valid():
			continue

		if _pipe_copy.is_valid():
			var u_cp_src: RDUniform = RDUniform.new()
			u_cp_src.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
			u_cp_src.binding = 0
			u_cp_src.add_id(color_img)
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
		u_dst.add_id(color_img)
		var set_dst: RID = UniformSetCacheRD.get_cache(shader, 1, [u_dst])

		var cl: int = rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(cl, pipeline)
		rd.compute_list_bind_uniform_set(cl, set_src, 0)
		rd.compute_list_bind_uniform_set(cl, set_dst, 1)
		rd.compute_list_set_push_constant(cl, push_constant.to_byte_array(), 64)
		rd.compute_list_dispatch(cl, x_groups, y_groups, 1)
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
