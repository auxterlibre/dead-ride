class_name BloodPool
extends MeshInstance3D
# Coalescing blood overlay on a fixed world grid of planes: drops land as
# shader uniforms that grow, sit, then dry away; a tile frees once every drop
# has. Tiles abut exactly - a drop whose texture skirt crosses a border is fed
# to BOTH tiles so the blob continues across the seam instead of double-drawing
# (overlapping planes stack their alpha into a dark sliver).

const MAX_DROPS: int = 32  # must match the shader constant
const TILE_SIZE: float = 6.0  # must match the PlaneMesh in blood_pool.tscn
# Drop diameter as a share of the tile's width.
const DROP_SIZE_MIN: float = 0.17
const DROP_SIZE_MAX: float = 0.25

@export var grow_time: float = 0.3
@export var hold_time: float = 3.0
@export var dry_time: float = 6.0

# One scene and one tile registry per liquid; probes reach into `tiles`
# (blood) by Vector3i, so the kinds keep separate dicts rather than one
# compound key.
const SCENES: Dictionary = {
	"blood": "uid://bq3j7w2r8v5xk",
	"fuel": "res://scenes/vfx/fuel_pool.tscn",
}

static var tiles: Dictionary = {}
static var fuel_tiles: Dictionary = {}

var kind: String = "blood"
var tile_key: Vector3i
var blood: ShaderMaterial
var positions: PackedVector2Array
var scales: PackedFloat32Array
var busy: Array[bool]
var half_size: float


func _ready():
	blood = material_override
	half_size = mesh.size.x * 0.5
	positions.resize(MAX_DROPS)
	scales.resize(MAX_DROPS)
	busy.resize(MAX_DROPS)
	push_scales()
	blood.set_shader_parameter("positions", positions)


func _exit_tree():
	var registry: Dictionary = registry_for(kind)
	if registry.get(tile_key) == self:
		registry.erase(tile_key)


static func registry_for(p_kind: String) -> Dictionary:
	return fuel_tiles if p_kind == "fuel" else tiles


static func drop(p_parent: Node, p_position: Vector3, p_kind: String = "blood"):
	var registry: Dictionary = registry_for(p_kind)
	var target: float = randf_range(DROP_SIZE_MIN, DROP_SIZE_MAX)
	var reach: float = DROP_SIZE_MAX * TILE_SIZE * 0.5
	for tile_x in range(tile_index(p_position.x - reach), tile_index(p_position.x + reach) + 1):
		for tile_z in range(tile_index(p_position.z - reach), tile_index(p_position.z + reach) + 1):
			var key: Vector3i = Vector3i(tile_x, roundi(p_position.y), tile_z)
			var pool: BloodPool = registry.get(key)
			if pool == null:
				pool = (load(SCENES[p_kind]) as PackedScene).instantiate()
				pool.kind = p_kind
				pool.tile_key = key
				registry[key] = pool
				p_parent.add_child(pool)
				pool.global_position = Vector3(tile_x * TILE_SIZE,
						p_position.y + 0.03, tile_z * TILE_SIZE)
			pool.add_drop(p_position, target)


static func tile_index(p_coord: float) -> int:
	return floori((p_coord + TILE_SIZE * 0.5) / TILE_SIZE)


func add_drop(p_position: Vector3, p_target: float):
	var slot: int = busy.find(false)
	if slot < 0:
		return  # flooded - the drops already down carry the look
	busy[slot] = true
	var local: Vector3 = to_local(p_position)
	positions[slot] = Vector2(local.x, local.z) / (half_size * 2.0) + Vector2(0.5, 0.5)
	blood.set_shader_parameter("positions", positions)
	var tween: Tween = create_tween()
	tween.tween_method(set_slot_scale.bind(slot), 0.0, p_target, grow_time) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(hold_time)
	tween.tween_method(set_slot_scale.bind(slot), p_target, 0.0, dry_time)
	tween.tween_callback(release_slot.bind(slot))


func set_slot_scale(p_value: float, p_slot: int):
	scales[p_slot] = p_value
	push_scales()


func release_slot(p_slot: int):
	busy[p_slot] = false
	if not busy.has(true):
		var registry: Dictionary = registry_for(kind)
		if registry.get(tile_key) == self:
			registry.erase(tile_key)
		queue_free()


func push_scales():
	blood.set_shader_parameter("scales", scales)
