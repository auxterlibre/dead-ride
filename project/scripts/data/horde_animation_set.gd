class_name HordeAnimationSet
extends Resource

const TEXELS_PER_BONE: int = 3
const FLOATS_PER_BONE: int = 12

@export var fps: float = 30.0
@export var bone_count: int = 0
@export var frame_count: int = 0
@export var clips: Dictionary = {}
@export var matrices: PackedFloat32Array = PackedFloat32Array()


func texture() -> ImageTexture:
	var image: Image = Image.create_from_data(bone_count * TEXELS_PER_BONE, frame_count, false,
			Image.FORMAT_RGBAF, matrices.to_byte_array())
	return ImageTexture.create_from_image(image)


func clip_start(p_name: String) -> int:
	return clips[p_name].start if clips.has(p_name) else 0


func clip_frames(p_name: String) -> int:
	return clips[p_name].frames if clips.has(p_name) else 1


func clip_loops(p_name: String) -> bool:
	return clips[p_name].loop if clips.has(p_name) else true
