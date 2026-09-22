class_name CharacterMovement
extends Node
# Shared locomotion; subclasses supply the intent through gather_intent().

# Delta-scaled gravity; GROUND_STICK is the small pull that keeps a grounded body snapped.
const GRAVITY: float = 60.0
const GROUND_STICK: float = 0.1
# A shove is authored as a DISTANCE, so the speed to launch at is derived from
# how far it should carry against the drag that will stop it, not guessed.
const KNOCKBACK_DRAG: float = 10.0  # m/s^2 bleeding a shove off
const KNOCKBACK_LIFT: float = 1.1  # m/s of hop per unit, so a blast lifts
const STAGGER_PER_UNIT: float = 0.09  # sec of ignored intent per unit
const WEDGE_TIME: float = 2.0  # sec of pushing without moving before the tripwire fires

@export var speed:float = 5.0  # top (sprint) speed
@export var walk_multiplier:float = 0.5
@export var sneak_multiplier:float = 0.3
@export var acceleration:float = 25.0
@export var deceleration:float = 30.0
@export var rotation_weight:float = 0.1
@export var face_movement:bool = true  # off when an aim component owns facing
@export var visual:Node3D

var move_direction:Vector3  # normalized intent, set by gather_intent() or AI
var is_sneaking:bool
var is_sprinting:bool
var sprint_allowed:bool = true  # PlayerEnergy pulls this while exhausted
var fatigue_scale:float = 1.0  # exhaustion's drag on every pace
var corpse:bool = false  # momentum-only: no intent, settles then sleeps
var stagger:float = 0.0  # sec of ignored intent left after a shove
var dash_left:float = 0.0  # sec of committed hop left (a dodge)
var dash_time:float = 0.0  # what it started as, so the launch can bleed off it
var dash_velocity:Vector3
var enabled:bool = true : set = set_enabled
var wedge_timer:float = 0.0
var wedge_anchor:Vector3

@onready var body:CharacterBody3D = get_parent()


func _physics_process(delta):
	if corpse:
		# A fresh corpse keeps its momentum (car hits, explosions): physics
		# only, no intent, dormant once it settles.
		body.velocity.x = move_toward(body.velocity.x, 0.0, deceleration * 0.5 * delta)
		body.velocity.z = move_toward(body.velocity.z, 0.0, deceleration * 0.5 * delta)
		body.velocity.y -= GRAVITY * delta
		body.move_and_slide()
		if body.is_on_floor() and Vector2(body.velocity.x, body.velocity.z).length() < 0.3:
			set_physics_process(false)
		return
	gather_intent()
	# Staggered: the shove owns the body for a moment, or it would be walked
	# off on the very next frame and never travel anywhere.
	if stagger > 0.0:
		stagger -= delta
		move_direction = Vector3.ZERO
	var multiplier:float = walk_multiplier
	if is_sneaking:
		multiplier = sneak_multiplier
	elif is_sprinting:
		multiplier = 1.0
	var target:Vector3 = move_direction * speed * multiplier * fatigue_scale
	var rate:float = acceleration if move_direction else deceleration
	if stagger > 0.0:
		rate = KNOCKBACK_DRAG
	if dash_left > 0.0:
		# A dodge is COMMITTED: the hop owns the velocity outright and steering
		# it would turn the roll into a walk with a costume on.
		dash_left = maxf(dash_left - delta, 0.0)
		move_direction = Vector3.ZERO
		body.velocity.x = dash_velocity.x * (dash_left / dash_time)
		body.velocity.z = dash_velocity.z * (dash_left / dash_time)
	else:
		body.velocity.x = move_toward(body.velocity.x, target.x, rate * delta)
		body.velocity.z = move_toward(body.velocity.z, target.z, rate * delta)
	# Facing follows intent only while actually moving - a body pressed
	# against an obstacle must not head-shake with every steering flip.
	if move_direction and visual and face_movement \
			and Vector2(body.velocity.x, body.velocity.z).length() > 0.3:
		# GLOBAL yaw: atan2 is a world-space angle, and the character root
		# may be rotated in the editor (local yaw would face 180 deg off).
		visual.global_rotation.y = lerp_angle(visual.global_rotation.y,
				atan2(move_direction.x, move_direction.z), rotation_weight)
	if body.is_on_floor():
		body.velocity.y = -GROUND_STICK
	else:
		body.velocity.y -= GRAVITY * delta
	body.move_and_slide()
	watch_for_wedge(delta)


# A tripwire, not a fix: a live body pushing somewhere and going nowhere for
# WEDGE_TIME gets its whole state printed, so a report of "I got stuck" comes
# with the mechanism attached. (A player wedged at the loot boxes could not be
# reproduced from geometry alone - 50 swept spots all walk free - so whatever
# does it next time should name itself here.)
func watch_for_wedge(p_delta:float):
	if move_direction == Vector3.ZERO or not body.is_on_floor():
		wedge_timer = 0.0
		wedge_anchor = body.global_position
		return
	if body.global_position.distance_to(wedge_anchor) > 0.05:
		wedge_timer = 0.0
		wedge_anchor = body.global_position
		return
	wedge_timer += p_delta
	if wedge_timer < WEDGE_TIME:
		return
	wedge_timer = 0.0
	var contacts:Array = []
	for i in body.get_slide_collision_count():
		var collision:KinematicCollision3D = body.get_slide_collision(i)
		contacts.append("%s n=%s" % [collision.get_collider().name,
				collision.get_normal().snappedf(0.01)])
	print("DBG WEDGED %s at %s intent=%s vel=%s stagger=%.2f contacts=%s" % [
			body.name, body.global_position.snappedf(0.01),
			move_direction.snappedf(0.01), body.velocity.snappedf(0.01),
			stagger, str(contacts)])


# A blast throws a body away from it. p_distance is the authored DISTANCE in
# world units, so the launch speed is solved from it against the drag that will
# stop it (v = sqrt(2*a*d)) rather than being a magic multiplier - retuning the
# drag keeps a 4-unit shove carrying 4 units.
func apply_knockback(p_origin: Vector3, p_distance: float):
	if p_distance <= 0.0 or corpse or not enabled:
		return
	var away: Vector3 = body.global_position - p_origin
	away.y = 0.0
	# Standing exactly on it: any direction beats none.
	if away.length_squared() < 0.0001:
		away = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	var speed_out: float = sqrt(2.0 * KNOCKBACK_DRAG * p_distance)
	body.velocity += away.normalized() * speed_out
	body.velocity.y = maxf(body.velocity.y, p_distance * KNOCKBACK_LIFT)
	stagger = maxf(stagger, p_distance * STAGGER_PER_UNIT)


# A dodge's hop. DISTANCE and DURATION are the authored pair, so the launch is
# solved from them (d = v * t / 2, bled linearly to nothing) instead of being a
# speed multiplier nobody can picture - and it travels through the same
# move_and_slide as a walk, so a wall stops a roll dead like everything else.
func dash(p_direction:Vector3, p_distance:float, p_duration:float):
	var flat:Vector3 = Vector3(p_direction.x, 0.0, p_direction.z)
	if corpse or not enabled or p_distance <= 0.0 or p_duration <= 0.0 \
			or flat.length_squared() < 0.0001:
		return
	dash_time = p_duration
	dash_left = p_duration
	dash_velocity = flat.normalized() * (2.0 * p_distance / p_duration)


# Overridden per character kind; the base stands still until something sets
# move_direction directly.
func gather_intent():
	pass


func current_pace() -> float:
	return clampf(Vector2(body.velocity.x, body.velocity.z).length() / speed, 0.0, 1.0)


func become_corpse():
	corpse = true
	move_direction = Vector3.ZERO
	set_physics_process(true)


func set_enabled(p_value:bool):
	enabled = p_value
	set_physics_process(p_value)
	if not p_value and body:
		body.velocity = Vector3()
		move_direction = Vector3()
		dash_left = 0.0  # a hop interrupted mid-air must not resume on re-entry
