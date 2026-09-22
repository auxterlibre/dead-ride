@tool
extends CompositorEffect
class_name PostProcessASCIIArt

## Procedural Matrix/ASCII Terminal Screen.
## Radically quantizes the screen into macro blocks and evaluates mathematically
## accurate typographic symbols based on physical luminance, requiring no font atlases.

enum CharacterSet { STANDARD_ASCII, BINARY_CODE, MATRIX_KATAKANA }
enum ColorMode { ORIGINAL_COLORS, DUAL_TONE_TERMINAL }

@export_group("Settings")

## Scaler representing how large the macro font grid cells are in pixels.
## Low = 4 (almost unreadable micro text), High = 16+ (huge terminal dots).
@export_range(4.0, 32.0, 1.0) var character_scale: float = 8.0:
	set(v): mutex.lock(); character_scale = v; mutex.unlock()

## Math evaluation shape set. ASCII relies on gradients, Binary requires heavy contrast.
@export var character_set: CharacterSet = CharacterSet.STANDARD_ASCII:
	set(v): mutex.lock(); character_set = v; mutex.unlock()

## Determines whether the typed pixels retain their original RGB render values
## or if they are overridden by the dual-tone terminal colors below.
@export var color_mode: ColorMode = ColorMode.ORIGINAL_COLORS:
	set(v): mutex.lock(); color_mode = v; mutex.unlock()

@export_group("Terminal Colors")

## The active "bright" phosphor text color. (Defaults to Matrix Green).
@export var terminal_foreground: Color = Color(0.0, 1.0, 0.4, 1.0):
	set(v): mutex.lock(); terminal_foreground = v; mutex.unlock()

## The void space terminal color mapping to total blackness.
@export var terminal_background: Color = Color(0.01, 0.03, 0.01, 1.0):
	set(v): mutex.lock(); terminal_background = v; mutex.unlock()

@export_group("Blend")

## Global crossfade back into the normal 3D rendering view.
@export_range(0.0, 1.0, 0.01) var strength: float = 1.0:
	set(v): mutex.lock(); strength = v; mutex.unlock()


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
	var shader_file: RDShaderFile = load("res://addons/compositor_effects/ascii_art/ascii_art.glsl")
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
	var _cs: float = character_scale
	var _cset: float = float(character_set)
	var _cm: float = float(color_mode)
	var _st: float = strength
	var _bgr: float = terminal_background.r
	var _bgg: float = terminal_background.g
	var _bgb: float = terminal_background.b
	var _fgr: float = terminal_foreground.r
	var _fgg: float = terminal_foreground.g
	var _fgb: float = terminal_foreground.b
	mutex.unlock()

	var push_constant: PackedFloat32Array = PackedFloat32Array([
		_cs, _cset, _cm, _st,
		_bgr, _bgg, _bgb, _fgr,
		_fgg, _fgb, float(size.x), float(size.y),
		0.0, 0.0, 0.0, 0.0
	])

	var x_groups: int = (size.x + 15) / 16
	var y_groups: int = (size.y + 15) / 16

	for view: int in render_scene_buffers.get_view_count():
		var color_img: RID = render_scene_buffers.get_color_layer(view)
		if not color_img.is_valid():
			continue

		var u_color: RDUniform = RDUniform.new()
		u_color.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		u_color.binding = 0
		u_color.add_id(color_img)
		var set_color: RID = UniformSetCacheRD.get_cache(shader, 0, [u_color])

		var compute_list: int = rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
		rd.compute_list_bind_uniform_set(compute_list, set_color, 0)
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
