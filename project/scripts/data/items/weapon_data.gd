class_name WeaponData
extends ItemData
# Exports are player-facing 0-100 knobs; *_SPAN maps each to real units via the *_value getters.

const DAMAGE_SPAN:Vector2 = Vector2(1.0, 21.0)
const EFFECTIVE_RANGE_SPAN:Vector2 = Vector2(2.0, 42.0)  # m; tracer caps at 40
# Descending: accuracy 100 = laser, 0 = the full 30 deg deviation cone.
const ACCURACY_SPAN:Vector2 = Vector2(30.0, 0.0)
const RECOIL_SPAN:Vector2 = Vector2(0.0, 100.0)  # % of full bloom added per shot
const KNOCKBACK_SPAN:Vector2 = Vector2(0.0, 5.0)  # world units
const FIRE_RATE_SPAN:Vector2 = Vector2(1.0, 21.0)  # shots/sec
const RELOAD_TIME_SPAN:Vector2 = Vector2(0.5, 5.5)  # sec
const CAMERA_KICK_SPAN:Vector2 = Vector2(0.0, 1.0)  # view punch, world units
const PROJECTILES_SPREAD_SPAN:Vector2 = Vector2(0.0, 60.0)  # full cone deg
const NOISE_SPAN:Vector2 = Vector2(0.0, 60.0)  # m a shot is heard from

# Display names for the tooltip's category line - spelled out rather than
# derived, so SMG doesn't come back as "Smg".
const CLASS_LABELS: Dictionary = {
	Enums.WeaponClass.PISTOL: "Pistol",
	Enums.WeaponClass.REVOLVER: "Revolver",
	Enums.WeaponClass.SHOTGUN: "Shotgun",
	Enums.WeaponClass.ASSAULT_RIFLE: "Assault rifle",
	Enums.WeaponClass.SMG: "SMG",
	Enums.WeaponClass.RIFLE: "Rifle",
	Enums.WeaponClass.MELEE: "Melee",
}

@export var type: Enums.WeaponType
@export var weapon_class: Enums.WeaponClass = Enums.WeaponClass.PISTOL
@export var ammo_type: Enums.AmmoType = Enums.AmmoType.MEDIUM
@export_range(0, 100) var damage: int = 0
@export_range(0, 100) var effective_range: int = 45
@export_range(0, 100) var accuracy: int = 60
@export_range(0, 100) var recoil: int = 0
@export_range(0, 100) var knockback_distance: int = 0
@export_range(0, 100, 1, "or_greater") var max_ammo: int = 0  # real count; 0 = no ammo (melee)
@export var fire_mode: Enums.FireMode = Enums.FireMode.SEMI_AUTO
@export_range(0, 100) var fire_rate: int = 15
@export var cock_time: float = 1.0
@export_range(0, 100) var reload_time: int = 10
@export_range(0, 100) var camera_kick: int = 20
@export_range(1, 12, 1, "or_greater") var projectiles_per_shot: int = 1  # real count
@export_range(0, 100) var projectiles_spread: int = 0
@export_range(0, 100) var noise: int = 70  # 0 would be a silenced weapon
# Deg; PlayerAim chest-target swing calibrated per hold pose (barrel axis).
@export_range(-90.0, 90.0, 0.1) var aim_yaw_offset: float = 0.0

var current_ammo:int = -1

var is_ranged:bool : get = get_is_ranged
var damage_value:int :
	get: return roundi(from_knob(damage, DAMAGE_SPAN))
var effective_range_value:float :
	get: return from_knob(effective_range, EFFECTIVE_RANGE_SPAN)
var accuracy_cone_value:float :  # deg of full deviation cone
	get: return from_knob(accuracy, ACCURACY_SPAN)
var recoil_value:float :
	get: return from_knob(recoil, RECOIL_SPAN)
var knockback_value:float :
	get: return from_knob(knockback_distance, KNOCKBACK_SPAN)
var fire_rate_value:float :
	get: return from_knob(fire_rate, FIRE_RATE_SPAN)
var fire_interval:float :  # seconds between shots, for cooldowns
	get: return 1.0 / fire_rate_value
var reload_time_value:float :
	get: return from_knob(reload_time, RELOAD_TIME_SPAN)
var camera_kick_value:float :
	get: return from_knob(camera_kick, CAMERA_KICK_SPAN)
var projectiles_spread_value:float :
	get: return from_knob(projectiles_spread, PROJECTILES_SPREAD_SPAN)
var noise_range_value:float :
	get: return from_knob(noise, NOISE_SPAN)


func get_is_ranged():
	return Enums.WeaponType.keys()[type].left(6) == "RANGED"


# The magazine is live state - a shared .tres would share one between owners.
func has_own_state() -> bool:
	return true


func get_category_label() -> String:
	return CLASS_LABELS[weapon_class]


func get_stat_lines() -> Array:
	var lines: Array = [["Damage", damage], ["Recoil", recoil],
			["Reload time", "%ss" % reload_time_value]]
	if is_ranged:
		lines.append(["Magazine size", max_ammo])
		lines.append(["Ammo type", Enums.AmmoType.keys()[ammo_type].capitalize()])
	return lines


func from_knob(p_knob:int, p_span:Vector2) -> float:
	return remap(p_knob, 0.0, 100.0, p_span.x, p_span.y)
