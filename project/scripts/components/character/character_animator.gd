class_name CharacterAnimator
extends Node
# Writes AnimationTree parameters; the tree lives in character_blend_tree.tres.

const PACE_PARAM:String = "parameters/locomotion/blend_position"
const TORSO_PACE_PARAM:String = "parameters/torso_locomotion/blend_position"
const TORSO_BLEND_PARAM:String = "parameters/torso_blend/blend_amount"
const SNEAK_BLEND_PARAM:String = "parameters/sneak_blend/blend_amount"
const SNEAK_SPEED_PARAM:String = "parameters/sneak_speed/scale"
const UPPER_BLEND_PARAM:String = "parameters/upper_blend/blend_amount"
const UPPER_STATE_PARAM:String = "parameters/upper_state/transition_request"
const UPPER_SPEED_PARAM:String = "parameters/upper_speed/scale"
const DODGE_STATE_PARAM:String = "parameters/dodge_state/transition_request"
const DODGE_SHOT_PARAM:String = "parameters/dodge_shot/request"
const DODGE_ACTIVE_PARAM:String = "parameters/dodge_shot/active"

@export var movement:CharacterMovement
@export var animation_tree:AnimationTree
@export var default_upper_animation:String = "ranged_1h_aiming"

var upper_weight:float = 0.0
var pace:float = 0.0
var blend_pos:Vector2 = Vector2.ZERO


func _ready():
	# Explicit initial state: an editor save can bake an empty transition
	# state into the scene, which would otherwise T-pose the upper layer.
	set_upper_animation(default_upper_animation)
	# Movement is wired by the variant scenes; a bare base has none and
	# only plays the idle blend.
	set_physics_process(movement != null)


func _physics_process(_delta):
	# Blend position is velocity in facing space (x strafe, y forward), scaled by speed.
	pace = movement.current_pace()
	var facing:Basis = movement.visual.global_transform.basis
	var forward:Vector3 = facing.z    # Rig_Medium faces +Z
	var right:Vector3 = -facing.x
	var vel:Vector3 = movement.body.velocity
	# Smoothed: at movement onset the raw velocity direction is noisy and a
	# jumpy path through the blend space kicks the hips for a few frames.
	blend_pos = blend_pos.lerp(
			Vector2(vel.dot(right), vel.dot(forward)) / movement.speed, 0.2)
	animation_tree.set(PACE_PARAM, blend_pos)
	# Upper body always plays the clean forward cycles at matching pace -
	# strafe/backpedal torso content is filtered out (torso_blend held at 1).
	animation_tree.set(TORSO_PACE_PARAM, pace)
	animation_tree.set(TORSO_BLEND_PARAM, 1.0)
	# Crouch replaces locomotion; cycle speed follows the sneak fraction (no crouch-idle clip).
	var sneak_target:float = 1.0 if movement.is_sneaking else 0.0
	animation_tree.set(SNEAK_BLEND_PARAM,
			lerpf(animation_tree.get(SNEAK_BLEND_PARAM), sneak_target, 0.15))
	animation_tree.set(SNEAK_SPEED_PARAM,
			clampf(pace / movement.sneak_multiplier, 0.0, 1.0))
	animation_tree.set(UPPER_BLEND_PARAM,
			lerpf(animation_tree.get(UPPER_BLEND_PARAM), upper_weight, 0.2))


# p_name must match an upper_state transition input (e.g. "ranged_1h_aiming",
# "melee_2h_idle") - add inputs in the blend tree resource, not here.
func set_upper_animation(p_name:String):
	animation_tree.set(UPPER_STATE_PARAM, p_name)


# A dodge is FULL-BODY, so it fires a one-shot layered over the whole tree
# rather than an upper_state input: on the arm/chest layer the legs would keep
# walking through the roll. p_name is a dodge_state input, not a clip name.
func play_dodge(p_name:String):
	animation_tree.set(DODGE_STATE_PARAM, p_name)
	animation_tree.set(DODGE_SHOT_PARAM, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func dodge_playing() -> bool:
	return animation_tree.get(DODGE_ACTIVE_PARAM)


# Duration of a library clip - lets gameplay time actions (reload, attacks)
# to the animation instead of hardcoding seconds.
func get_clip_length(p_name:String) -> float:
	var anim:Animation = animation_tree.get_animation("gen/" + p_name)
	return anim.length if anim else 0.0


# When a named marker falls in a clip, or -1 if it has none. Lets an action fire
# on the frame the ANIMATOR chose - a grenade leaves the hand where the throw
# clip says it does, not on a hardcoded delay that drifts when the clip is
# retimed.
func get_marker_time(p_name:String, p_marker:String) -> float:
	var anim:Animation = animation_tree.get_animation("gen/" + p_name)
	if anim == null or not anim.has_marker(p_marker):
		return -1.0
	return anim.get_marker_time(p_marker)


# Playback speed of the upper layer (1.0 = authored speed) - used to fit an
# action clip into a stat-driven duration (e.g. reload_time).
func set_upper_speed(p_scale:float):
	animation_tree.set(UPPER_SPEED_PARAM, p_scale)


# The raw clip plays on the sibling AnimationPlayer and holds its last frame as the corpse.
func play_death(p_name:String):
	animation_tree.active = false
	set_physics_process(false)
	var player:AnimationPlayer = \
			animation_tree.get_parent().get_node_or_null("AnimationPlayer")
	var clip:String = "character_library/" + p_name
	if player and player.has_animation(clip):
		player.play(clip)
	else:
		push_warning("Death animation not found: %s" % clip)
