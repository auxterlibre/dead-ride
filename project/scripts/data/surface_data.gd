class_name SurfaceData
extends Resource

const DIRECTORY: String = "res://data/surfaces"

@export var atlas: Texture2D  # 4x4 bullet-hole sheet, dark-on-white (multiply)
@export var burst: PackedScene  # particle burst spawned at the hit
@export var audio: AudioStream  # impact sound, played with pitch variation
@export var step_audio: AudioStream  # footstep on this surface
@export var ricochet: bool = false  # deflect bullets: no hole, streak bounces off
# What a vehicle kicks up off this ground. 0 throws nothing at all, which is
# what a metal deck or a rooftop wants.
@export var dust_color: Color = Color(0.8784314, 0.70980394, 0.45882353)
@export_range(0.0, 1.0) var dust_amount: float = 1.0
# What a sliding tyre leaves behind. Rubber-black is right on tarmac; on sand
# a skid is churned GROUND, so it wants a darker version of the ground itself.
@export var skid_color: Color = Color(0.08, 0.07, 0.06, 0.5)
@export var skid_marks: bool = true  # off where the ground records wheels itself
# The other half of that: this ground is a height field that takes displaced
# tracks (SandTrail stamps into the trail buffer). Sand on, tarmac off.
@export var displaced_tracks: bool = false


# A body's "surface" metadata tag, resolved to its resource. Null when the tag
# has no file, so callers pick their own fallback.
static func of(p_tag: String) -> SurfaceData:
	var path: String = "%s/%s.tres" % [DIRECTORY, p_tag]
	return load(path) if ResourceLoader.exists(path) else null


# What p_node is standing on. The terrain GridMaps report the MAP as collider
# and carry one tag map-wide, so a single ray is the whole answer.
static func under(p_node: Node3D, p_mask: int, p_reach: float = 1.0) -> SurfaceData:
	return at(p_node.get_world_3d(), p_node.global_position, p_mask, p_reach)


# The same lookup at a bare world point, for callers with nothing standing there.
static func at(p_world: World3D, p_position: Vector3, p_mask: int,
		p_reach: float = 1.0) -> SurfaceData:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			p_position + Vector3.UP * 0.3,
			p_position + Vector3.DOWN * p_reach, p_mask)
	var hit: Dictionary = p_world.direct_space_state.intersect_ray(query)
	if hit and hit.collider.has_meta("surface"):
		return of(hit.collider.get_meta("surface"))
	return null
