class_name CharacterData
extends Resource

@export var first_name: String
@export var last_name: String
@export var faction: Enums.Faction = Enums.Faction.PLAYER
@export_range(1, 100, 1, "or_greater") var max_health:int = 10
@export_range(1.0, 10.0, 0.1) var speed: float = 5.0
@export_range(0.0, 50.0, 0.5) var vision_range: float = 15.0
@export_range(0.0, 20.0, 0.5) var detection_range: float = 5.0  # keep <= vision_range
@export_range(0.0, 60.0, 0.5) var combat_range: float = 30.0  # engaged retention (~a screenful)
# -1 = start HOLSTERED: weapons ride the bar, hands stay empty until drawn.
# Only the pack path honors it - an enemy has no draw step in its brain yet,
# so characters without a CharacterInventory always open armed.
@export_range(-1, 2, 1) var current_weapon_idx: int = 0  # 3 weapon slots
@export var backpack: BackpackData
@export var body_path: String
@export var dead_animation: String = "death_a"  # library clip (death_a/death_b)
@export var ai_script: Script

@export var weapon_inventory:Array[WeaponData] = []
@export var starting_items: Array[ItemData] = []  # non-weapons carried at spawn

# Joined "First Last" for display. Inline getter: a get_name() method would
# clash with the native Object one.
var name:String :
	get: return ("%s %s" % [first_name, last_name]).strip_edges()
