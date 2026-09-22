class_name CharacterFootsteps
extends AudioStreamPlayer3D

const GROUND_MASK:int = 16

@export var default_audio:AudioStream
@export var print_scene: PackedScene  # the layer-2 stamp; null leaves no prints
# Calibrated on the shared rig: plants bottom out at y 0.07-0.13, the idle
# rest pose sits at 0.145, and swing peaks reach 0.28.
@export var foot_down_height:float = 0.135  # skeleton-space Y that counts as planted
@export var foot_up_height:float = 0.19  # foot must rise past this to re-arm
@export var min_speed:float = 0.5

@onready var character:CharacterBody3D = get_parent()
@onready var skeleton:Skeleton3D = character.find_children("*", "Skeleton3D", true, false)[0]
@onready var foot_bones:Array[int] = [Utils.rig_bone(skeleton, "LeftFoot", "foot.l"),
		Utils.rig_bone(skeleton, "RightFoot", "foot.r")]

# Feet start planted (idle pose is below the threshold), so both begin
# disarmed - the first sound needs an actual lift and come-down.
var foot_ready:Array[bool] = [false, false]
var marks: Array[GPUParticles3D] = []  # live prints; each frees itself when done
var prints_stamped: int = 0  # what the probe counts; pixels are the shot's job


func _physics_process(_delta):
	var moving:bool = Vector2(character.velocity.x, character.velocity.z) \
			.length() > min_speed
	for i in foot_bones.size():
		var height:float = skeleton.get_bone_global_pose(foot_bones[i]).origin.y
		if height > foot_up_height:
			foot_ready[i] = true
		elif foot_ready[i] and height < foot_down_height:
			foot_ready[i] = false
			if moving and character.is_on_floor():
				play_step()
				stamp_at(skeleton.global_transform \
						* skeleton.get_bone_global_pose(foot_bones[i]).origin)


func stamp_at(p_spot: Vector3):
	if print_scene == null:
		return
	var data: SurfaceData = SurfaceData.at(character.get_world_3d(), p_spot,
			GROUND_MASK)
	if data == null or not data.displaced_tracks:
		return
	prints_stamped += 1
	var mark: GPUParticles3D = print_scene.instantiate()
	# On the CHARACTER, but the particles are world-space: the six spawn at
	# the mark's position this frame and never follow the walker after.
	character.add_child(mark)
	# The SPOT's own height, never the body's: a probe once parked the body
	# off the map edge and every print spawned 131m down the void with it.
	mark.global_position = Vector3(p_spot.x, p_spot.y + 0.03, p_spot.z)
	mark.emitting = true
	mark.finished.connect(mark.queue_free)
	marks.append(mark)
	marks = marks.filter(is_instance_valid)


func play_step():
	stream = surface_step_audio()
	if stream == null:
		return
	pitch_scale = randf_range(0.9, 1.1)
	play()


func surface_step_audio() -> AudioStream:
	var data:SurfaceData = SurfaceData.under(character, GROUND_MASK, 0.7)
	if data and data.step_audio:
		return data.step_audio
	return default_audio
