class_name EnemyLoot
extends Node
# The corpse as a storage, the card's rule: killed, the body builds a small
# inventory - the weapons that were in its hands (live magazines and all), a
# very small pinch of their calibre, and whatever the optional table throws
# in - and its Search offer opens through the same container panel every box
# uses. Corpses are deliberately not persisted, so neither is this.

const AMMO_ITEMS: Dictionary = {
	Enums.AmmoType.LIGHT: "res://data/items/ammo/ammo_light.tres",
	Enums.AmmoType.MEDIUM: "res://data/items/ammo/ammo_medium.tres",
	Enums.AmmoType.HEAVY: "res://data/items/ammo/ammo_heavy.tres",
	Enums.AmmoType.SHOTGUN: "res://data/items/ammo/ammo_shotgun.tres",
}
const AMMO_PINCH: Vector2i = Vector2i(2, 6)  # rounds per carried calibre - a pinch

@export var offer: InteractiveArea  # authored disabled; death is what arms it
@export var pockets: StorageData  # the body's little grid
@export var loot: LootTableData  # optional extras ("other items drop randomly")
@export var extra_rolls: Vector2i = Vector2i(0, 2)  # draws off that table

var storage: Inventory
var opened: bool = false

@onready var body: Character = get_parent()


func _ready():
	offer.enabled = false
	body.died.connect(on_died)


func on_died():
	build()
	# Conditional advertising: a body with empty pockets offers nothing.
	offer.enabled = storage != null and not storage.entries.is_empty()


func build():
	storage = Inventory.new()
	storage.setup(pockets)
	var weapons: CharacterWeapons = body.weapons
	if weapons == null:
		return
	# The hands' own instances move in whole - the magazine rides, nothing is
	# conjured - except the fists, which are a stance, not an item.
	var fists_name: String = (load(CharacterWeapons.FISTS_PATH) as WeaponData).name
	for weapon in weapons.inventory:
		if weapon.name == fists_name:
			continue
		storage.add(weapon, 1)
		# The pinch follows the CALIBRE, so a machete seeds no rounds.
		var pinch: String = AMMO_ITEMS.get(weapon.ammo_type, "")
		if weapon.max_ammo > 0 and pinch != "":
			storage.add(load(pinch) as ItemData,
					randi_range(AMMO_PINCH.x, AMMO_PINCH.y))
	if loot == null:
		return
	# LootContainer.fill's stateful-instance rule, in miniature.
	for i in randi_range(extra_rolls.x, maxi(extra_rolls.x, extra_rolls.y)):
		var entry: LootEntryData = loot.draw()
		if entry == null:
			continue
		var count: int = entry.roll_count()
		if entry.item.has_own_state():
			for j in count:
				storage.add(entry.item.duplicate(), 1)
		else:
			storage.add(entry.item, count)


# The offer's callback: the pack opens with the body's pockets beside it.
func open(_p_player = null):
	if storage == null:
		return
	if not opened:
		opened = true
		offer.spent = true  # searched bodies read hollow, the crate's rule
	Signals.container_opened.emit(body.data.first_name if body.data else "Body",
			storage)
