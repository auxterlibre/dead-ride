class_name Enums

enum WeaponType {MELEE_1H, MELEE_2H, RANGED_1H, RANGED_2H, MELEE_UNARMED}

enum FireMode {SEMI_AUTO, AUTOMATIC, MANUAL}

enum AmmoType {LIGHT, MEDIUM, HEAVY, SHOTGUN}

enum WeaponClass {PISTOL, REVOLVER, SHOTGUN, ASSAULT_RIFLE, SMG, RIFLE, MELEE}

enum Rarity {COMMON, UNCOMMON, RARE, EPIC}  # one Palette colour each

enum Faction {PLAYER, ENEMY, NEUTRAL}

enum TimeFormat {HOUR_24, HOUR_12}

enum UnitSystem {METRIC, IMPERIAL}

# Where an input prompt is drawn: beside the player, or the quieter corner list
# used for standing help like the driving controls.
enum PromptPlacement {CHARACTER, CORNER}

enum MessageType {NEUTRAL, POSITIVE, NEGATIVE}
