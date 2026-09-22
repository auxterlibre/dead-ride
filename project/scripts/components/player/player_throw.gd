class_name PlayerThrow
extends Node
# Hold aim with a throwable selected to line the arc up; attack lets it go.

const WORLD_MASK: int = 28  # walls | car | ground; ThrowPreview shares it
const BODY_RADIUS: float = 0.22  # the grenade's own collision radius; ditto
const PICK_LENGTH: float = 200.0  # camera ray, matching PlayerAim
const POSE_READY: String = "throw_arm_back"  # held while lining the throw up
const POSE_THROW: String = "throw_arm_forward"
const RELEASE_MARKER: String = "throw"  # the frame the hand opens

@export var carried: CharacterInventory
@export var aim: PlayerAim
@export var animator: CharacterAnimator
@export var preview: ThrowPreview
@export var hand_height: float = 1.25  # fallback origin when nothing is held
@export var flight_per_metre: float = 0.085  # a longer throw hangs longer
@export var flight_span: Vector2 = Vector2(0.45, 1.4)

var revealed: float = -1.0  # sec since the wind-up began; below zero = hidden
var is_ready: bool = false
var launch: Vector3  # the velocity both the preview and the throw use
var flight: float  # seconds solve() shaped the arc around
var pending: ExplosiveData  # the one mid-swing
var locked_target: Vector3  # where the ring promised, held across the wind-up
var release_timer: float = -1.0
var recover_timer: float = -1.0

@onready var body: CharacterBody3D = get_parent()
@onready var gravity: float = ProjectSettings.get_setting(
		"physics/3d/default_gravity", 9.8)
@onready var reach_shape: SphereShape3D = make_reach_shape()


func _process(p_delta: float):
	if advance_swing(p_delta):
		return  # mid-throw: the clip owns the arms and the attack button
	var explosive: ExplosiveData = selected()
	var wants: bool = explosive != null and not get_tree().paused \
			and Input.is_action_pressed("aim")
	if wants != is_ready:
		is_ready = wants
		revealed = 0.0 if wants else -1.0
		if preview:
			preview.visible = wants
		set_pose(POSE_READY if wants else "")
	if not is_ready:
		return
	revealed += p_delta
	solve(aim_point())
	if preview:
		preview.draw(explosive)
	# Polled like firing is, and gated on the same prompt check, so a click the
	# GUI swallowed cannot also throw a grenade.
	if Input.is_action_just_pressed("attack") and not InputManager.pointer_over_prompt:
		begin_swing(explosive)


# PlayerWeapons asks this before firing: the attack button belongs to the throw
# from the moment it is lined up until the arm has finished coming through.
func holds_attack() -> bool:
	return is_ready or recover_timer >= 0.0


# The clip decides WHEN, this only counts down to it. Target is locked at the
# click, not re-read at the marker: the ring made a promise 0.2s ago and the
# cursor drifting since then must not move where it lands.
func begin_swing(p_explosive: ExplosiveData):
	pending = p_explosive
	locked_target = aim_point()
	is_ready = false
	if preview:
		preview.visible = false
	set_pose(POSE_THROW)
	var marker: float = animator.get_marker_time(POSE_THROW, RELEASE_MARKER) \
			if animator else -1.0
	release_timer = marker if marker >= 0.0 else 0.0
	recover_timer = maxf(animator.get_clip_length(POSE_THROW) if animator else 0.0,
			release_timer)


func advance_swing(p_delta: float) -> bool:
	if recover_timer < 0.0:
		return false
	if release_timer >= 0.0:
		release_timer -= p_delta
		if release_timer <= 0.0:
			release_timer = -1.0
			release(pending)
	recover_timer -= p_delta
	if recover_timer <= 0.0:
		recover_timer = -1.0
		pending = null
		set_pose("")
		# Still carrying some? Put the next one back in the hand.
		var left: ExplosiveData = selected()
		if left and carried.weapons:
			carried.weapons.hold_prop(left.get_held_scene())
	return true


# "" releases the upper layer back to whatever the body is doing.
func set_pose(p_clip: String):
	if animator == null:
		return
	if p_clip == "":
		animator.upper_weight = 0.0
		return
	animator.set_upper_animation(p_clip)
	animator.upper_weight = 1.0


# The explosive on the ACTIVE quick slot, or nothing. Selecting the slot is
# what readies a throwable, the same way selecting a weapon slot draws a gun.
func selected() -> ExplosiveData:
	if carried == null or carried.active_slot < 0 \
			or carried.active_slot >= carried.quick_slots.size():
		return null
	var entry: InventoryEntry = carried.quick_slots[carried.active_slot]
	return entry.item as ExplosiveData if entry else null


# Fixed FLIGHT TIME rather than a fixed speed or angle: solving for time always
# has an answer, where solving for an angle has none once the target is out of
# range and needs a failure case the player would have to be told about.
func solve(p_target: Vector3):
	var from: Vector3 = throw_origin()
	var flat: Vector3 = p_target - from
	flat.y = 0.0
	flight = clampf(flat.length() * flight_per_metre,
			flight_span.x, flight_span.y)
	launch = flat / flight
	launch.y = (p_target.y - from.y) / flight + 0.5 * gravity * flight


# The hand, PULLED BACK to somewhere the grenade can actually be. The arm swings
# through whatever the player is standing against - throw beside the pump and the
# release frame puts the hand inside it - and a RigidBody born inside a static
# collider is not thrown at all: the solver ejects it at a speed of its own
# choosing, differently every run, and while it is jammed it gets extruded
# downward until it drops out of the underside of the ground box and falls
# forever. The preview traces from this same clamped point, so the arc drawn and
# the arc flown cannot start in different places.
func throw_origin() -> Vector3:
	return clear_reach(hand_point())


# The placeholder in the hand, so the real one leaves from where the player can
# see it rather than out of the chest. The prop's ROOT sits on the hand bone and
# its mesh child carries the grip offset, so the mesh is the honest position.
# Falls back to a chest-height point when the hand is empty (an AI throw, or a
# stack that emptied mid-swing).
func hand_point() -> Vector3:
	var prop: Node3D = carried.weapons.held_prop if carried and carried.weapons else null
	if prop and is_instance_valid(prop):
		var posed: Node3D = prop.get_child(0) as Node3D if prop.get_child_count() else null
		return (posed if posed else prop).global_position
	return body.global_position + Vector3.UP * hand_height


# Swept straight out from the body axis at the hand's OWN height: it is the
# reach that can be blocked, never the shoulder, so the cast starts somewhere
# the grenade is free by construction - it does not mask the body layers, and
# wherever the player is standing is by definition clear of walls.
func clear_reach(p_hand: Vector3) -> Vector3:
	var from: Vector3 = Vector3(body.global_position.x, p_hand.y,
			body.global_position.z)
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = reach_shape
	query.collision_mask = WORLD_MASK
	query.transform = Transform3D(Basis.IDENTITY, from)
	query.motion = p_hand - from
	var fractions: PackedFloat32Array = body.get_world_3d() \
			.direct_space_state.cast_motion(query)
	if fractions.is_empty():
		return p_hand
	return from + query.motion * fractions[0]


func make_reach_shape() -> SphereShape3D:
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = BODY_RADIUS
	return shape


# WHAT THE RETICLE IS OVER - the first surface under the cursor, wall face
# included. PlayerAim flattens its own pick onto the weapon's aim PLANE, which
# is right for a bullet and wrong for a lob: with the cursor on a wall the plane
# point sits past it, so the throw got solved to clear the very thing the player
# was pointing at, and the arc sailed over instead of smacking into it.
func aim_point() -> Vector3:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return body.global_position
	var from: Vector3 = camera.project_ray_origin(aim.mouse_position)
	var direction: Vector3 = camera.project_ray_normal(aim.mouse_position)
	var hit: Dictionary = cast(from, from + direction * PICK_LENGTH)
	if hit:
		return hit.position
	# Nothing under the cursor at all: the ground plane the player stands on.
	var flat = Plane(Vector3.UP, body.global_position.y).intersects_ray(from, direction)
	return flat if flat != null else body.global_position


func cast(p_from: Vector3, p_to: Vector3) -> Dictionary:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			p_from, p_to, WORLD_MASK)
	return body.get_world_3d().direct_space_state.intersect_ray(query)


# Re-solved from where the hand is NOW to the target the ring promised. The arm
# has swung since the click, so the arc's start has moved - aiming it at the
# same ground point is what keeps the landing true rather than the shape.
func release(p_explosive: ExplosiveData):
	if p_explosive == null or p_explosive.thrown_scene == null:
		return
	solve(locked_target)
	var origin: Vector3 = throw_origin()
	# Out of the hand before the grenade appears, or both are on screen at once.
	if carried.weapons:
		carried.weapons.clear_prop()
	var grenade: Grenade = p_explosive.thrown_scene.instantiate()
	get_tree().current_scene.add_child(grenade)
	grenade.throw(origin, launch, p_explosive)
	take_one()


# One off the stack. The stack LIVES on the slot now, so the last one leaving
# just empties the slot - the grid never knew about it.
func take_one():
	var slot: int = carried.active_slot
	var entry: InventoryEntry = carried.quick_slots[slot]
	entry.count -= 1
	if entry.count <= 0:
		carried.clear_slot(slot)
	else:
		carried.notify_slots()
