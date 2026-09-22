class_name PlayerWeapons
extends CharacterWeapons
# Input layer over CharacterWeapons: slot switching, aiming, firing, reload
# and the accuracy/spread model - everything the HUD signals report.

@export var unaimed_spread:float = 0.4  # accuracy penalty while not aiming
# Deviation floor, so a low-accuracy weapon is never laser-precise with the spread closed.
@export var min_spread_factor:float = 0.25
@export var aim:PlayerAim
@export var movement:CharacterMovement
@export var throwing:PlayerThrow
@export var consuming:PlayerConsume
@export var building:PlayerBuild
@export var carrying:PlayerCarry
@export var dodging:CharacterDodge

var is_aiming:bool = false

@onready var audio_weapon_swap: AudioStreamPlayer3D = $AudioWeaponSwap


func _process(p_delta):
	if inventory.size() == 0:
		return
	super(p_delta)  # cooldown / reload / bloom / shot-clip mechanics
	# The cursor's rangefinder outlives the weapon - empty hands still aim it,
	# they just have no effective range to run out of.
	var aim_dist: float = aim_distance()
	Signals.aim_distance_updated.emit(aim_dist, current_weapon != null
			and aim_dist > current_weapon.effective_range_value)
	if current_weapon == null:
		return  # holstered: nothing to fire, spread or pose
	Signals.spread_updated.emit(display_spread())
	set_aiming(Input.is_action_pressed("aim"))
	update_aim_height()
	# A readied throwable owns the attack button: firing as well would put a
	# bullet and a grenade out on the same click.
	if throwing and throwing.holds_attack():
		return
	# A selected consumable claims it the same way - the click drinks, not shoots.
	if consuming and consuming.holds_attack():
		return
	# And a ghost on the cursor: the click builds rather than firing into it.
	if building and building.holds_attack():
		return
	# A barrel in the arms: the click places it, and there is no gun anyway.
	if carrying and carrying.holds_attack():
		return
	# Mid-roll the body owns itself: no shot, no swing, no reload until it lands.
	if dodging and dodging.dodging():
		return
	# Firing is polled, so a click the GUI swallowed still reaches here - an
	# interaction prompt under the cursor would otherwise be shot as it is used.
	if not InputManager.pointer_over_prompt \
			and (Input.is_action_just_pressed("attack") \
			or (current_weapon.fire_mode == Enums.FireMode.AUTOMATIC
					and Input.is_action_pressed("attack"))):
		try_fire()
	if Input.is_action_just_pressed("reload"):
		reload()


# Follows the equipped weapon's muzzle height, so the tracer lies in the aim plane.
func update_aim_height():
	var target_height:float = 1.0
	var ranged:WeaponRanged = weapon_model as WeaponRanged
	if ranged:
		target_height = ranged.projectile_spawn.global_position.y \
				- body.global_position.y
	aim.aim_height = lerpf(aim.aim_height, target_height, 0.1)


func equip(p_index:int):
	if p_index == current_index:
		return
	cancel_reload()  # switching away abandons the reload, no refill
	super(p_index)
	aim.weapon_yaw_offset = current_weapon.aim_yaw_offset
	Signals.weapon_setup.emit(current_weapon)
	audio_weapon_swap.pitch_scale = randf_range(0.9, 1.1)
	audio_weapon_swap.play()


func set_aiming(p_value:bool):
	if p_value == is_aiming:
		return
	is_aiming = p_value
	Signals.aim_state_changed.emit(is_aiming)
	if is_reloading:
		return  # keep the reload pose; apply_pose() runs when it finishes
	apply_pose()


# The look-at follows the ANIMATION, not the aim button - hip-fire shows the same pose.
func apply_pose():
	if current_weapon == null:
		return
	var poses:Dictionary = UPPER_ANIMATIONS[current_weapon.type]
	var pose:String = poses.aim if is_aiming else poses.idle
	animator.set_upper_animation(pose)
	animator.upper_weight = 1.0
	aim.stance_weight = 1.0 if pose == poses.aim else 0.0


# The ranged hold poses ARE the aiming clips, so holstering must close the look-at too.
func holster():
	super()
	aim.stance_weight = 0.0
	Signals.weapon_setup.emit(null)  # the reticle drops its weapon shape


# Not aiming hip-fires: current_spread() carries the penalty and the shot clip plays upper-layer.
func try_fire():
	if not can_fire():
		return
	if current_weapon.current_ammo <= 0:
		fire_empty()
		announce_empty()
		return
	# Fire from the aim plane so the shot line and the reticle share a height.
	var from:Vector3 = body.global_position
	from.y = aim.aim_position.y
	var to_aim:Vector3 = (aim.aim_position - from).rotated(Vector3.UP, shot_deviation())
	fire_shot(from, from + to_aim)
	if current_weapon.current_ammo == 0:
		announce_empty()
	# recoil is authored as percent of full bloom per shot.
	bloom = minf(bloom + current_weapon.recoil_value / 100.0, 1.0)
	if Globals.camera_follow:
		Globals.camera_follow.kick(-aim.aim_direction * current_weapon.camera_kick_value)
	Signals.weapon_fired.emit()
	Signals.ammo_updated.emit()


func announce_empty():
	if can_reload():
		Signals.notification_requested.emit("RELOAD", Enums.MessageType.NEUTRAL)
	else:
		Signals.notification_requested.emit("OUT OF AMMO", Enums.MessageType.NEGATIVE)


# The chest look-at stays OPEN through the reload: it is what holds the torso
# twisted by aim_yaw_offset, and fading it out un-twists the whole upper body
# (~27 deg on the rifle) into the clip, then back - a visible turn both ways.
func reload():
	super()


func finish_reload():
	super()
	Signals.ammo_updated.emit()


# Distance from the gun muzzle to the reticle's world point (body center for
# weapons without a muzzle) - shown on the HUD.
func aim_distance() -> float:
	var origin:Vector3 = body.global_position
	var ranged:WeaponRanged = weapon_model as WeaponRanged
	if ranged:
		origin = ranged.projectile_spawn.global_position
	return origin.distance_to(aim.aim_position)


# Recoil cone scaled by the current spread, floored at min_spread_factor.
func shot_deviation() -> float:
	return deg_to_rad(randf_range(-0.5, 0.5)
			* current_weapon.accuracy_cone_value
			* maxf(current_spread(), min_spread_factor))


# Proportional to the ACTUAL cone, plus the pellet spread, which fans out whatever the stance.
func display_spread() -> float:
	if current_weapon == null:
		return 0.0
	var cone:float = current_weapon.accuracy_cone_value \
			* maxf(current_spread(), min_spread_factor) \
			+ current_weapon.projectiles_spread_value
	return cone / WeaponData.ACCURACY_SPAN.x


# Total accuracy spread (0..1.5): movement + shot bloom + not-aiming penalty.
func current_spread() -> float:
	var pace:float = movement.current_pace() if movement else 0.0
	var open:float = 0.0 if is_aiming else unaimed_spread
	return clampf(pace + bloom + open, 0.0, 1.5)
