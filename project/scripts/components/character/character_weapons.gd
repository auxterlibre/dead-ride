class_name CharacterWeapons
extends Node
# Inventory, hold pose and the fire/reload cycle; trigger decisions live in the variants.

const UPPER_ANIMATIONS:Dictionary = {
	Enums.WeaponType.MELEE_1H: {"idle": "melee_2h_idle", "aim": "melee_2h_idle"},
	Enums.WeaponType.MELEE_2H: {"idle": "melee_2h_idle", "aim": "melee_2h_idle"},
	Enums.WeaponType.RANGED_1H: {"idle": "ranged_1h_aiming", "aim": "ranged_1h_aiming",
			"reload": "ranged_1h_reload", "shoot": "ranged_1h_shoot"},
	Enums.WeaponType.RANGED_2H: {"idle": "ranged_2h_aiming", "aim": "ranged_2h_aiming",
			"reload": "ranged_2h_reload", "shoot": "ranged_2h_shoot"},
	# The kick clip is wired in the blend tree but not dealt: the upper layer
	# filters to arm/chest/head bones, and a leg-less kick reads as a spasm.
	Enums.WeaponType.MELEE_UNARMED: {"idle": "melee_unarmed_idle",
			"aim": "melee_unarmed_idle",
			"attacks": ["melee_unarmed_attack_punch_a"]},
}

const EJECT_SHARE:float = 0.4  # of the cock, the beat before the case flies
const FISTS_PATH:String = "res://data/items/weapons/melee/fists.tres"
const STRIKE_CONNECT:float = 0.45  # of the swing clip, when the blow lands
const STRIKE_REACH:float = 2.2  # m; a hair past the AI's melee ring, so a
								# swing started in range still lands

@export var weapon_layer:int = 2  # hurt-box layer this character's shots hit
@export var bloom_recovery_time:float = 0.8  # sec for shot bloom to drain
@export var bloom_recovery_delay:float = 0.2  # firing pause before recovery
@export var animator:CharacterAnimator
@export var hand_slot:HandSlot

var inventory:Array[WeaponData] = []
var current_index:int = -1
var current_weapon:WeaponData
var weapon_model:Weapon
var held_prop:Node3D  # a throwable in the hand instead of a weapon
var fire_cooldown:float = 0.0
var shot_anim_timer:float = 0.0
var is_reloading:bool = false
var reload_timer:float = 0.0
var needs_cocking:bool = false  # MANUAL: the action must cycle before the next shot
var cock_timer:float = 0.0
var eject_played:bool = false
var bloom:float = 0.0  # accuracy lost to recent shots (0..1)
var since_shot:float = 0.0
var pending_strike:Node3D  # the body a started swing will test at the connect beat
var strike_timer:float = 0.0
# The pack reloads are drawn from, wired up by CharacterInventory when the
# character carries one. Without it (enemies today) rounds are free.
var carried: CharacterInventory

@onready var body:CharacterBody3D = get_parent()


func _process(p_delta):
	if inventory.size() == 0:
		return
	fire_cooldown = maxf(fire_cooldown - p_delta, 0.0)
	since_shot += p_delta
	if since_shot > bloom_recovery_delay:
		bloom = maxf(bloom - p_delta / bloom_recovery_time, 0.0)
	if is_reloading:
		reload_timer -= p_delta
		if reload_timer <= 0.0:
			finish_reload()
	if needs_cocking and not is_reloading:
		cock_timer -= p_delta
		if not eject_played \
				and cock_timer <= current_weapon.cock_time * (1.0 - EJECT_SHARE):
			eject_played = true
			(weapon_model as WeaponRanged).play_eject()
		if cock_timer <= 0.0:
			finish_cock()
	if pending_strike != null:
		strike_timer -= p_delta
		if strike_timer <= 0.0:
			land_strike()
	if shot_anim_timer > 0.0:
		shot_anim_timer -= p_delta
		if shot_anim_timer <= 0.0 and not is_reloading:
			if needs_cocking:
				play_cock_animation()  # recoil done: work the action visibly
			else:
				apply_pose()  # shot clip finished, back to the hold pose


func setup(p_inventory:Array[WeaponData], p_start_index:int):
	# Runtime copies: WeaponData carries live state (current_ammo), and two
	# characters whose data references the same .tres would share a magazine.
	var copies:Array[WeaponData] = []
	for weapon in p_inventory:
		copies.append(weapon.duplicate())
	if copies.is_empty():
		# Bare hands are still a weapon: an empty loadout otherwise chases
		# into melee range and stands there staring, with nothing to swing.
		copies.append((load(FISTS_PATH) as WeaponData).duplicate())
	set_weapons(copies, p_start_index)


# Arms with instances the CALLER owns - duplicating here would refill magazines on equip.
func set_weapons(p_weapons:Array[WeaponData], p_start_index:int = -1):
	inventory = p_weapons
	if inventory.is_empty():
		current_index = -1
		return
	var held:int = inventory.find(current_weapon)
	var target:int = p_start_index if p_start_index >= 0 else maxi(held, 0)
	if current_weapon != null and held == target:
		current_index = target
		return
	current_index = -1
	equip(clampi(target, 0, inventory.size() - 1))


func equip(p_index:int):
	# Explicitly no negative wrap: equip(-1) would silently draw the LAST weapon.
	if p_index == current_index or p_index < 0 or p_index >= inventory.size():
		return
	clear_prop()  # a drawn gun takes the hand back off a throwable
	cancel_cock()  # hand state, not weapon state; the swap works the action
	current_index = p_index
	current_weapon = inventory[p_index]
	weapon_model = current_weapon.model.instantiate()
	var ranged:WeaponRanged = weapon_model as WeaponRanged
	if ranged:
		ranged.effective_range = current_weapon.effective_range_value
		ranged.projectiles_per_shot = current_weapon.projectiles_per_shot
		ranged.projectiles_spread = current_weapon.projectiles_spread_value
	hand_slot.set_weapon(weapon_model, body, weapon_layer,
			current_weapon.type in [Enums.WeaponType.RANGED_1H, Enums.WeaponType.MELEE_1H])
	if current_weapon.current_ammo == -1:
		current_weapon.current_ammo = draw_rounds(current_weapon.max_ammo)
	apply_pose()


# The equipped weapon is always visibly carried; variants refine the pose.
func apply_pose():
	if current_weapon == null:
		return  # holstered: the upper layer is released, not posed
	animator.set_upper_animation(UPPER_ANIMATIONS[current_weapon.type].idle)
	animator.upper_weight = 1.0


# Puts the held weapon away: hands empty, upper animation layer released. The
# inventory keeps it - drawing again is equip().
func holster():
	if weapon_model == null:
		return
	cancel_reload()
	# Left armed, the next _process would read cock_time off a null weapon.
	cancel_cock()
	hand_slot.remove_old_weapon(weapon_model)
	hand_slot.weapon = null
	weapon_model = null
	current_weapon = null
	current_index = -1
	animator.upper_weight = 0.0


func is_holstered() -> bool:
	return current_weapon == null


# A non-weapon in the hand - a grenade. COSMETIC only: what actually gets
# thrown is a separate scene the thrower spawns, so this carries no physics and
# no script and there is nothing to keep in sync. A SCENE rather than a mesh so
# the grip is posed in the editor, the same way each weapon poses its own. A
# null scene only clears, without holstering, so selecting ammo or a tool
# leaves the gun where it was.
func hold_prop(p_scene: PackedScene):
	clear_prop()
	if p_scene == null or hand_slot == null:
		return
	holster()
	held_prop = p_scene.instantiate()
	hand_slot.add_child(held_prop)


func clear_prop():
	if held_prop and is_instance_valid(held_prop):
		held_prop.queue_free()
	held_prop = null


func can_fire() -> bool:
	return current_weapon != null and current_weapon.is_ranged \
			and fire_cooldown == 0.0 and not is_reloading and not needs_cocking


func can_strike() -> bool:
	return current_weapon != null and not current_weapon.is_ranged \
			and fire_cooldown == 0.0 and not is_reloading


# One melee swing at a body: the clip plays now, the blow lands at the
# CONNECT beat - and only if the target is still in reach then, so stepping
# back out of a punch dodges it.
func strike(p_target:Node3D):
	var clips:Array = UPPER_ANIMATIONS[current_weapon.type].get("attacks", [])
	if clips.is_empty():
		return
	fire_cooldown = current_weapon.fire_interval
	since_shot = 0.0
	var clip:String = clips.pick_random()
	animator.set_upper_animation(clip)
	var length:float = animator.get_clip_length(clip)
	shot_anim_timer = length  # rides the shot clip's return-to-pose path
	pending_strike = p_target
	strike_timer = maxf(length * STRIKE_CONNECT, 0.05)


func land_strike():
	var target:Node3D = pending_strike
	pending_strike = null
	if target == null or not is_instance_valid(target) or current_weapon == null:
		return
	var to_target:Vector3 = target.global_position - body.global_position
	to_target.y = 0.0
	if to_target.length() > STRIKE_REACH:
		return  # they stepped out of it
	var attack:AttackData = AttackData.new(current_weapon.damage_value,
			body.global_position, current_weapon.knockback_value, body)
	var hurt_box = target.get("hurt_box")
	if hurt_box != null:
		hurt_box.hit(attack)
	elif target.has_method("take_damage"):
		target.take_damage(attack)


# One mechanical shot toward p_aim_point (deviation already applied by the
# caller): ammo, cooldown, damage packet, and the weapon-type shot clip.
func fire_shot(p_from:Vector3, p_aim_point:Vector3):
	current_weapon.current_ammo -= 1
	fire_cooldown = current_weapon.fire_interval
	since_shot = 0.0
	var attack:AttackData = AttackData.new(current_weapon.damage_value,
			body.global_position, current_weapon.knockback_value, body)
	(weapon_model as WeaponRanged).fire(attack, p_from, p_aim_point)
	Signals.noise_emitted.emit(body.global_position,
			current_weapon.noise_range_value, body)
	var shoot_clip:String = UPPER_ANIMATIONS[current_weapon.type].get("shoot", "")
	if shoot_clip != "":
		animator.set_upper_animation(shoot_clip)
		shot_anim_timer = animator.get_clip_length(shoot_clip)
	# A MANUAL action must cycle before the next shot - unless the magazine
	# just emptied: there is nothing to chamber, and the reload works the bolt.
	if current_weapon.fire_mode == Enums.FireMode.MANUAL \
			and current_weapon.current_ammo > 0:
		needs_cocking = true
		eject_played = false
		cock_timer = current_weapon.cock_time


# The visible bolt work: the reload clip, time-scaled to fill what is left of
# the cock once the shot clip has had its recoil frames.
func play_cock_animation():
	if cock_timer <= 0.05:
		return
	var clip:String = UPPER_ANIMATIONS[current_weapon.type].reload
	animator.set_upper_speed(animator.get_clip_length(clip) / cock_timer)
	animator.set_upper_animation(clip)


func finish_cock():
	needs_cocking = false
	animator.set_upper_speed(1.0)
	if shot_anim_timer <= 0.0 and not is_reloading:
		apply_pose()


# Abandons the cycle without reposing - equip and holster set their own pose.
func cancel_cock():
	if not needs_cocking:
		return
	needs_cocking = false
	animator.set_upper_speed(1.0)


# Throttled so holding an automatic trigger doesn't click every frame.
func fire_empty():
	(weapon_model as WeaponRanged).play_empty()
	fire_cooldown = maxf(current_weapon.fire_interval, 0.2)


# Duration comes from WeaponData.reload_time; the clip is time-scaled to fit it.
func reload():
	if is_reloading or not current_weapon.is_ranged \
			or current_weapon.current_ammo == current_weapon.max_ammo \
			or not can_reload():
		return
	is_reloading = true
	cancel_cock()  # the reload works the action; no separate eject
	var clip:String = UPPER_ANIMATIONS[current_weapon.type].reload
	var duration:float = current_weapon.reload_time_value
	if duration <= 0.0:
		duration = animator.get_clip_length(clip)  # 0 = authored length
	reload_timer = duration
	animator.set_upper_speed(animator.get_clip_length(clip) / duration)
	animator.set_upper_animation(clip)
	(weapon_model as WeaponRanged).play_reload()


func cancel_reload():
	if not is_reloading:
		return
	is_reloading = false
	animator.set_upper_speed(1.0)


func finish_reload():
	is_reloading = false
	animator.set_upper_speed(1.0)
	current_weapon.current_ammo += reload_amount()
	apply_pose()


# How many rounds a completed reload adds - as much of the missing magazine
# as the pack can actually supply, so a short reserve tops off partially.
func reload_amount() -> int:
	return draw_rounds(current_weapon.max_ammo - current_weapon.current_ammo)


# Reloading on an empty reserve would only play the animation for nothing.
func can_reload() -> bool:
	return carried == null \
			or carried.ammo_count(current_weapon.ammo_type) > 0


# Takes rounds OUT of the pack; a character without one just fills for free.
func draw_rounds(p_amount: int) -> int:
	if carried == null:
		return p_amount
	return carried.spend_ammo(current_weapon.ammo_type, p_amount)
