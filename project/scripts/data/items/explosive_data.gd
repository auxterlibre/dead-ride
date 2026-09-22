class_name ExplosiveData
extends ItemData
# Exports are player-facing 0-100 knobs; *_SPAN maps each to real units via the *_value getters.

const DAMAGE_SPAN: Vector2 = Vector2(10.0, 160.0)  # at the core, before any falloff
const BLAST_RADIUS_SPAN: Vector2 = Vector2(1.0, 12.0)  # m to the outer edge
const CORE_SHARE_SPAN: Vector2 = Vector2(0.0, 1.0)  # of the radius, at full damage
const FUSE_SPAN: Vector2 = Vector2(0.0, 8.0)  # sec from arming to the bang
const KNOCKBACK_SPAN: Vector2 = Vector2(0.0, 8.0)  # world units, at the core

@export_range(0, 100) var damage: int = 60
@export_range(0, 100) var blast_radius: int = 40
@export_range(0, 100) var core_size: int = 30  # share of the blast taking it all
@export_range(0, 100) var fuse_time: int = 35
@export_range(0, 100) var knockback_distance: int = 55
@export_range(1, 9) var max_stack: int = 3  # real count: how many ride one cell
@export var thrown_scene: PackedScene  # the body that gets thrown, physics and all
@export var held_scene: PackedScene  # the same thing posed for the hand

var damage_value: int:
	get: return roundi(from_knob(damage, DAMAGE_SPAN))
var blast_radius_value: float:
	get: return from_knob(blast_radius, BLAST_RADIUS_SPAN)
# A SHARE of the blast, not a length of its own: retuning the radius keeps the
# shape of the falloff instead of silently swallowing the core or exposing it.
var core_radius_value: float:
	get: return blast_radius_value * from_knob(core_size, CORE_SHARE_SPAN)
var fuse_value: float:
	get: return from_knob(fuse_time, FUSE_SPAN)
var knockback_value: float:
	get: return from_knob(knockback_distance, KNOCKBACK_SPAN)


# Everything inside the core takes it in full; past that it falls away to
# nothing at the edge. Anything beyond the blast takes none, so a caller can
# hand over any distance without checking the range first.
func damage_at(p_distance: float) -> int:
	var outer: float = blast_radius_value
	if p_distance >= outer:
		return 0
	var core: float = core_radius_value
	# A core as wide as the blast is a hard-edged charge, not a division by zero.
	if p_distance <= core or outer - core < 0.001:
		return damage_value
	return roundi(damage_value * (1.0 - (p_distance - core) / (outer - core)))


# The shove rides the same curve as the hurt, so being flung always matches
# how badly you were caught.
func knockback_at(p_distance: float) -> float:
	if damage_value <= 0:
		return 0.0
	return knockback_value * damage_at(p_distance) / float(damage_value)


func get_max_stack() -> int:
	return max_stack


# A throwable is HELD: selecting it takes the hand off the gun.
func get_held_scene() -> PackedScene:
	return held_scene


func get_category_label() -> String:
	return "Explosive"


# The player-facing knobs, not the remapped units - 0-100 is the scale these
# stats are authored and compared on, the same as a weapon's.
func get_stat_lines() -> Array:
	return [["Damage", damage], ["Blast radius", blast_radius],
			["Core", core_size], ["Fuse", fuse_time]]


func from_knob(p_knob: int, p_span: Vector2) -> float:
	return remap(p_knob, 0.0, 100.0, p_span.x, p_span.y)
