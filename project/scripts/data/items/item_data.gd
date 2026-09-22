class_name ItemData
extends Resource

const RARITY_COLORS: Dictionary = {
	Enums.Rarity.COMMON: Palette.COMMON,
	Enums.Rarity.UNCOMMON: Palette.UNCOMMON,
	Enums.Rarity.RARE: Palette.RARE,
	Enums.Rarity.EPIC: Palette.EPIC,
}

@export var name: String
@export var weight: float
@export var size: Vector2i = Vector2i(1, 1)
@export var icon: Texture2D
# The item's 3D body - what the icon studio renders and a world drop will show.
# A SCENE, not a mesh, for the same reason as get_held_scene: a bare mesh has
# no pose. Distinct from held_scene (posed for the hand) and the grenade's
# thrown_scene (a live RigidBody).
@export var model: PackedScene
@export var rarity: Enums.Rarity = Enums.Rarity.COMMON
@export var price: int = 0

# Authored in the icon studio (_tools/asset_extractor/icon_studio.tscn); the
# batch renderer honors them too, so a re-render never loses a tuned angle.
# @export is what makes them SAVE, and dropping it is silent both ways: a
# plain var still LOADS from a .tres, so posed items keep looking right until
# something re-saves one and the pose is gone.
@export_group("Icon Render")
@export var icon_yaw: float = 0.0  # extra model turn under the house camera
@export var icon_pitch: float = 0.0
@export var icon_roll: float = 0.0
@export var icon_zoom: float = 1.0  # over the auto-fit; >1 reads closer


func cell_count() -> int:
	return size.x * size.y


# 1 = one item fills the cell. Stackables (ammo) override it.
func get_max_stack() -> int:
	return 1


# Kind is the name - runtime duplicates break identity.
func same_kind(p_other: ItemData) -> bool:
	return p_other != null and p_other.get_script() == get_script() \
			and p_other.name == name


func stacks_with(p_other: ItemData) -> bool:
	return get_max_stack() > 1 and same_kind(p_other)


# Carries live per-instance state (a magazine, a fill level): never hand out
# the canonical .tres, and never let two grid entries share one instance.
func has_own_state() -> bool:
	return false


func get_rarity_label() -> String:
	return Enums.Rarity.keys()[rarity].capitalize()


func get_rarity_color() -> Color:
	return RARITY_COLORS[rarity]


# Tooltip line 2, beside the rarity. Subclasses name their own kind so the UI
# never switches on type.
func get_category_label() -> String:
	return "Item"


# Tooltip stat rows as [label, value] pairs; empty means a description-only item.
func get_stat_lines() -> Array:
	return []


func get_held_scene() -> PackedScene:
	return null
