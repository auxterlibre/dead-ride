class_name SandField
extends Node
# Owns the ground-weather wiring: hands the trail buffer to the sand material,
# frames the trail camera on the ground, and feeds the live wind. One per scene
# with a displaced-sand floor; unwired knobs stay whatever the material says.

@export var surface: MeshInstance3D
@export var trail_viewport: SubViewport
@export var trail_camera: Camera3D
# Off holds the authored wind values steady for tuning - but the air still
# travels, or turning it off freezes every grain on the ground.
@export var follow_wind: bool = true

const MAX_CHILL: int = 8  # must match the shader array
const CHILL_REFRESH: float = 0.5  # barrels drain slowly; the tint follows lazily

var sand: ShaderMaterial
var wind_path: Vector2 = Vector2.ZERO  # metres the air has travelled
var chill_timer: float = 0.0


func _ready():
	sand = surface.get_active_material(0)
	# The camera must frame exactly the square the shader maps, or the ruts
	# land somewhere other than where the wheels went.
	trail_camera.size = sand.get_shader_parameter("world_size")
	trail_camera.global_position.x = surface.global_position.x
	trail_camera.global_position.z = surface.global_position.z
	sand.set_shader_parameter("trail_origin",
			Vector2(surface.global_position.x, surface.global_position.z))
	# Wired here rather than authored: a ViewportTexture sub-resource in the
	# .tscn names the viewport by path and silently yields nothing off-path.
	sand.set_shader_parameter("trail_tex", trail_viewport.get_texture())


func _process(p_delta: float):
	var direction: Vector2
	var strength: float
	if follow_wind and Globals.wind:
		direction = Vector2(Globals.wind.direction.x, Globals.wind.direction.z)
		strength = Globals.wind.strength
		sand.set_shader_parameter("wind_direction", direction)
		sand.set_shader_parameter("wind_strength", strength)
		sand.set_shader_parameter("wind_gust", Globals.wind.gust)
	else:
		direction = sand.get_shader_parameter("wind_direction")
		strength = sand.get_shader_parameter("wind_strength")
	if direction.length() > 0.01:
		wind_path += direction.normalized() * strength * p_delta
	sand.set_shader_parameter("wind_path", wind_path)
	chill_timer -= p_delta
	if chill_timer <= 0.0:
		chill_timer = CHILL_REFRESH
		push_chill()


# Coolant objects (group chill_source) damp-darken the sand around them; the
# strength (packed into y - the ground is flat) fades with their fuel, so the
# ground drying out is the warning. A PackedVector4Array, never a
# PackedColorArray: Colors risk colour-space conversion on the way to the
# GPU, and these are world coordinates.
func push_chill():
	var spots: PackedVector4Array = PackedVector4Array()
	for source in get_tree().get_nodes_in_group("chill_source"):
		if spots.size() >= MAX_CHILL:
			break
		spots.append(Vector4(source.global_position.x, source.chill_strength(),
				source.global_position.z, source.chill_radius()))
	while spots.size() < MAX_CHILL:  # fixed-size array; zero strength is inert
		spots.append(Vector4.ZERO)
	sand.set_shader_parameter("chill_spots", spots)
