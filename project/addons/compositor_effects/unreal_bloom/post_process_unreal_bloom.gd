@tool
extends CompositorEffect
class_name PostProcessUnrealBloom

## Real-time physically based "Unreal" engine-style Dual Kawase Bloom.
##
## Processes highlights cleanly across multi-pass intermediate texture hierarchies,
## producing zero-artifact, incredibly smooth glowing lens responses seen in AAA modern games.
## This safely replaces single-pass single-buffer techniques meaning NO visual tearing or "lines occurring".

# ─── Normal Settings ─────────────────────────────────────────────────────────

@export_group("Settings")

## Master blend intensity for the completed bloom pass scaling onto the image.
@export_range(0.0, 5.0, 0.01) var intensity: float = 1.0:
	set(v):
		mutex.lock()
		intensity = v
		mutex.unlock()

## Luminance threshold pixel floor required to extract bright spots for blooming.
@export_range(0.0, 10.0, 0.01) var threshold: float = 1.0:
	set(v):
		mutex.lock()
		threshold = v
		mutex.unlock()

## Soft knee algorithm protecting harsh edge bounds off extremely bright objects.
## A higher value makes highlights transition beautifully into glowing streaks.
@export_range(0.0, 5.0, 0.01) var knee: float = 0.5:
	set(v):
		mutex.lock()
		knee = v
		mutex.unlock()

# ─── Advanced Settings ───────────────────────────────────────────────────────

@export_group("Advanced Settings")

## Depth of the downsampled buffers hierarchy. E.g. 5 Mips reaches down to ~1/32 scale.
## Lower means less spread; higher gives massive global volume glow states.
@export_range(2, 7, 1) var mip_count: int = 5:
	set(v):
		mutex.lock()
		mip_count = v
		mutex.unlock()

## Multiplier scaling the Up pass convolution blur ranges, widening the final glow's "fatness".
@export_range(0.5, 3.0, 0.1) var filter_radius: float = 1.0:
	set(v):
		mutex.lock()
		filter_radius = v
		mutex.unlock()

# ─── GPU State ───────────────────────────────────────────────────────────────

var rd: RenderingDevice
var mutex: Mutex = Mutex.new()

var _shader_extract: RID
var _pipe_extract: RID
var _shader_down: RID
var _pipe_down: RID
var _shader_up: RID
var _pipe_up: RID
var _shader_apply: RID
var _pipe_apply: RID

# Multi-texture arrays solving all single-pass line artifacts
var _mips: Array[RID] = []
var _mip_sizes: Array[Vector2i] = []
var _sampler: RID

var _last_size: Vector2i = Vector2i()
var _last_mip_count: int = 0

func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	rd = RenderingServer.get_rendering_device()
	if rd == null:
		push_error("[PostProcessUnrealBloom] RenderingDevice is null.")
		return

	# Build the shared sampling matrix (Bilinear continuous layout for fluid reading)
	var sampler_state = RDSamplerState.new()
	sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler_state.mip_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler_state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	sampler_state.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	_sampler = rd.sampler_create(sampler_state)

	_create_pipelines()

func _create_pipelines() -> void:
	# Load 4 structural compute segments:
	_shader_extract = _compile("bloom_extract.glsl")
	if _shader_extract.is_valid(): _pipe_extract = rd.compute_pipeline_create(_shader_extract)

	_shader_down = _compile("bloom_down.glsl")
	if _shader_down.is_valid(): _pipe_down = rd.compute_pipeline_create(_shader_down)

	_shader_up = _compile("bloom_up.glsl")
	if _shader_up.is_valid(): _pipe_up = rd.compute_pipeline_create(_shader_up)

	_shader_apply = _compile("bloom_apply.glsl")
	if _shader_apply.is_valid(): _pipe_apply = rd.compute_pipeline_create(_shader_apply)

func _compile(filename: String) -> RID:
	var path = "res://addons/compositor_effects/unreal_bloom/" + filename
	var r = load(path)
	if r == null: return RID()
	return rd.shader_create_from_spirv(r.get_spirv())

func _get_image_set(image_rid: RID, shader: RID, set_idx: int) -> RID:
	var u = RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u.binding = 0
	u.add_id(image_rid)
	return UniformSetCacheRD.get_cache(shader, set_idx, [u])

func _get_sampler_set(image_rid: RID, shader: RID, set_idx: int) -> RID:
	var u = RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u.binding = 0
	u.add_id(_sampler)
	u.add_id(image_rid)
	return UniformSetCacheRD.get_cache(shader, set_idx, [u])

func _free_mips() -> void:
	for m in _mips:
		if m.is_valid() and rd.texture_is_valid(m):
			rd.free_rid(m)
	_mips.clear()
	_mip_sizes.clear()

func _reallocate_mips(p_size: Vector2i, p_count: int) -> void:
	_free_mips()
	var current_size = p_size

	for i in range(p_count):
		# Each layer mathematically reduces screen density space dividing by 2 (downscaling architecture)
		current_size = Vector2i(max(current_size.x / 2, 1), max(current_size.y / 2, 1))
		_mip_sizes.push_back(current_size)

		var fmt := RDTextureFormat.new()
		fmt.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
		fmt.width  = current_size.x
		fmt.height = current_size.y
		fmt.usage_bits = (
			RenderingDevice.TEXTURE_USAGE_STORAGE_BIT |
			RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT |
			RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT |
			RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
		)
		_mips.push_back(rd.texture_create(fmt, RDTextureView.new()))

func _render_callback(
	p_effect_callback_type: EffectCallbackType,
	p_render_data: RenderData
) -> void:
	if rd == null or not _pipe_extract.is_valid():
		return
	if p_effect_callback_type != EFFECT_CALLBACK_TYPE_POST_TRANSPARENT:
		return

	var rsb: RenderSceneBuffersRD = p_render_data.get_render_scene_buffers()
	if rsb == null: return

	var size: Vector2i = rsb.get_internal_size()
	if size.x == 0 or size.y == 0: return

	mutex.lock()
	var t_intensity = intensity
	var t_threshold = threshold
	var t_knee = knee
	var t_mip_count = mip_count
	var t_radius = filter_radius
	mutex.unlock()

	# Handle memory bounds — dynamically shift persistent buffers if views resize
	if size != _last_size or t_mip_count != _last_mip_count:
		_reallocate_mips(size, t_mip_count)
		_last_size = size
		_last_mip_count = t_mip_count

	if _mips.size() == 0: return

	for view in rsb.get_view_count():
		var color_layer = rsb.get_color_layer(view)

		# ── 1. EXTRACT ────────────────────────────────────────────────────────
		var cl = rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(cl, _pipe_extract)
		rd.compute_list_bind_uniform_set(cl, _get_image_set(color_layer, _shader_extract, 0), 0)
		rd.compute_list_bind_uniform_set(cl, _get_image_set(_mips[0], _shader_extract, 1), 1)
		# Passing soft limits params
		var ext_pc = PackedFloat32Array([t_threshold, t_knee, 0,0, 0,0,0,0])
		rd.compute_list_set_push_constant(cl, ext_pc.to_byte_array(), 32)
		var ms0 = _mip_sizes[0]
		rd.compute_list_dispatch(cl, (ms0.x+7)/8, (ms0.y+7)/8, 1)
		rd.compute_list_end()

		# ── 2. DOWNSAMPLE (N-Taps 13) ─────────────────────────────────────────
		for i in range(t_mip_count - 1):
			cl = rd.compute_list_begin()
			rd.compute_list_bind_compute_pipeline(cl, _pipe_down)
			rd.compute_list_bind_uniform_set(cl, _get_sampler_set(_mips[i], _shader_down, 0), 0)
			rd.compute_list_bind_uniform_set(cl, _get_image_set(_mips[i+1], _shader_down, 1), 1)

			var src_sz = _mip_sizes[i]
			var dp_pc = PackedFloat32Array([1.0/src_sz.x, 1.0/src_sz.y, 0,0, 0,0,0,0])
			rd.compute_list_set_push_constant(cl, dp_pc.to_byte_array(), 32)

			var target_sz = _mip_sizes[i+1]
			rd.compute_list_dispatch(cl, (target_sz.x+7)/8, (target_sz.y+7)/8, 1)
			rd.compute_list_end()

		# ── 3. UPSAMPLE (N-Taps 9) ────────────────────────────────────────────
		# Step backwards blending heavily diffused lower limits back up chains
		for i in range(t_mip_count - 1, 0, -1):
			cl = rd.compute_list_begin()
			rd.compute_list_bind_compute_pipeline(cl, _pipe_up)
			rd.compute_list_bind_uniform_set(cl, _get_sampler_set(_mips[i], _shader_up, 0), 0)
			rd.compute_list_bind_uniform_set(cl, _get_image_set(_mips[i-1], _shader_up, 1), 1)

			var src_sz = _mip_sizes[i]
			var up_pc = PackedFloat32Array([1.0/src_sz.x, 1.0/src_sz.y, t_radius, 0, 0,0,0,0])
			rd.compute_list_set_push_constant(cl, up_pc.to_byte_array(), 32)

			var target_sz = _mip_sizes[i-1]
			rd.compute_list_dispatch(cl, (target_sz.x+7)/8, (target_sz.y+7)/8, 1)
			rd.compute_list_end()

		# ── 4. RESIDUAL APPLY ──────────────────────────────────────────────────
		cl = rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(cl, _pipe_apply)
		rd.compute_list_bind_uniform_set(cl, _get_sampler_set(_mips[0], _shader_apply, 0), 0)
		rd.compute_list_bind_uniform_set(cl, _get_image_set(color_layer, _shader_apply, 1), 1)

		var fin_pc = PackedFloat32Array([t_intensity, 0,0,0, 0,0,0,0])
		rd.compute_list_set_push_constant(cl, fin_pc.to_byte_array(), 32)
		rd.compute_list_dispatch(cl, (size.x+7)/8, (size.y+7)/8, 1)
		rd.compute_list_end()

func _notification(what: int) -> void:
	# Cleanup is inlined (including _free_mips): during PREDELETE the script
	# instance is already being destructed, so dispatching to another method
	# fails ("null instance").
	if what != NOTIFICATION_PREDELETE or rd == null:
		return
	for m in _mips:
		if m.is_valid() and rd.texture_is_valid(m):
			rd.free_rid(m)
	if _sampler.is_valid():
		rd.free_rid(_sampler)
	var rids_to_clean = [_pipe_extract, _shader_extract, _pipe_down, _shader_down, _pipe_up, _shader_up, _pipe_apply, _shader_apply]
	for idx_rid in rids_to_clean:
		if idx_rid.is_valid():
			rd.free_rid(idx_rid)
